# frozen_string_literal: true

require "strscan"

module Tally
  # LuaConfig reads the config file upstream writes.
  #
  # Upstream's $XDG_CONFIG_HOME/tally/tally is Lua source: writecfg prints a
  # `return { ... }` table and readcfg calls load() on it. This port writes
  # JSON instead — running load() on a file in a user's home directory is
  # arbitrary code execution, which upstream only gets away with because the
  # file lives inside a Flatpak sandbox. But an existing Tally user's counters
  # are in that Lua file, so something has to read it, and that something must
  # not be an evaluator.
  #
  # Hence a parser for the grammar upstream actually emits, which is narrow and
  # fixed because exactly two format strings produce it:
  #
  #   writecfg:             "width = %d,\n", "height = %d,\n",
  #                         "maximized = %q,\n", and the table literal
  #                         "return {\n\t%s\n}\n" around the lot;
  #   counter:serialize:    "{\n%s},\n" around "\t[%q] = %q,\n" per field.
  #
  # Three consequences of %q are worth naming, because they are what a
  # hand-written reader gets wrong:
  #
  # * %q on a float emits a C99 hexadecimal float — a counter's value comes
  #   off a Gtk.SpinButton, so it is a double, and 3 is written `0x1.8p+1`.
  #   Integers are written plainly, so both forms occur in the same file.
  # * %q on a boolean emits a bare `true` / `false`, not a quoted string,
  #   despite writecfg's "maximized = %q" reading as though it were a string.
  # * %q escapes a literal newline as a backslash followed by an actual
  #   newline, and other control characters as `\9` or `\009`. Counter names
  #   are user text, so both happen.
  #
  # Anything outside that grammar raises Error rather than being guessed at,
  # which is what lets Store tell "there is no config" apart from "there is a
  # config I could not read" and refuse to overwrite the second.
  #
  # The parser accepts a little more than upstream emits — decimal floats,
  # single-quoted strings, long strings, comments, unquoted keys, nested
  # tables — because a config file a user has edited by hand is still a config
  # file whose counters should not be lost.
  class LuaConfig
    Error = Class.new(StandardError)

    # A parsed Lua table, split the way Lua itself splits one: the positional
    # entries in order, and the keyed entries.
    Table = Struct.new(:array, :hash) do
      def to_h = hash
    end

    SPACE = /\s+/
    LINE_COMMENT = /--(?!\[=*\[)[^\n]*/
    NAME = /[A-Za-z_][A-Za-z0-9_]*/
    # Hexadecimal first, so "0x10" is not read as the integer 0 followed by a
    # name. Both an exponent-bearing hex float and a plain hex integer appear.
    HEX = /-?0[xX][0-9a-fA-F]*(?:\.[0-9a-fA-F]*)?(?:[pP][-+]?\d+)?/
    DECIMAL = /-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?/

    # The counter fields upstream's readcfg hands to the counter constructor.
    # serialize() dumps every scalar field it finds, including the transient
    # `checked` and `checkmode` flags, and upstream ignores those on the way
    # back in; so does this.
    COUNTER_FIELDS = %w[name value color].freeze

    class << self
      # The document Store works in, read out of Lua source. Raises Error on
      # anything it cannot account for.
      def parse(text) = new(text).document

    end

    def initialize(text)
      @scanner = StringScanner.new(text.to_s)
    end

    # The whole file as a Store document: geometry plus counters.
    def document
      root.then do |table|
        {
          "width"     => integer_or_nil(table.hash["width"]),
          "height"    => integer_or_nil(table.hash["height"]),
          "maximized" => boolean(table.hash["maximized"]),
          "counters"  => counters(table),
        }.compact
      end
    end

    # The top-level table, with the optional `return` in front of it.
    def root
      @root ||= begin
        skip_filler
        @scanner.scan(/return\b/)
        skip_filler
        value.tap do |table|
          unless table.is_a?(Table)
            raise Error, "config is not a table"
          end
          skip_filler
          @scanner.scan(/;/)
          skip_filler
          unless @scanner.eos?
            raise Error, "unexpected #{@scanner.rest[0, 20].inspect} after the config table"
          end
        end
      end
    end

    private

      # The positional entries of the root table, each of which upstream wrote
      # with counter:serialize.
      def counters(table)
        table.array.filter_map do |entry|
          if entry.is_a?(Table)
            counter_from(entry)
          end
        end
      end

      def counter_from(entry)
        COUNTER_FIELDS.to_h { |field| [field, entry.hash[field]] }
          .tap { |fields| fields["value"] = integer_or_nil(fields["value"]) }
          .compact
      end

      def value
        case
        when @scanner.scan(/\{/) then table
        when @scanner.scan(/true\b/) then true
        when @scanner.scan(/false\b/) then false
        when @scanner.scan(/nil\b/) then nil
        when (literal = @scanner.scan(HEX)) then number(literal)
        when (literal = @scanner.scan(DECIMAL)) then number(literal)
        when @scanner.check(/["']/) then quoted_string
        when @scanner.check(/\[=*\[/) then long_string
        else raise Error, "unexpected #{@scanner.rest[0, 20].inspect}"
        end
      end

      # The body of a table, with the opening brace already consumed.
      def table
        Table.new([], {}).tap do |result|
          loop do
            skip_filler
            if @scanner.scan(/\}/)
              break
            end

            entry(result)
            skip_filler
            unless @scanner.scan(/[,;]/)
              unless @scanner.scan(/\}/)
                raise Error, "unterminated table at #{@scanner.rest[0, 20].inspect}"
              end
              break
            end
          end
        end
      end

      # One `[k] = v`, `name = v` or positional entry.
      def entry(result)
        case
        when @scanner.scan(/\[/) then bracketed_entry(result)
        when (name = bare_key) then result.hash[name] = assigned_value
        else result.array.push(value)
        end
      end

      def bracketed_entry(result)
        skip_filler
        value.then do |key|
          skip_filler
          unless @scanner.scan(/\]/)
            raise Error, "unclosed [ in table key"
          end
          result.hash[key.to_s] = assigned_value
        end
      end

      # A `name =` key, matched only when an `=` that is not `==` follows, so
      # a positional entry starting with a name is not mistaken for one.
      def bare_key
        @scanner.check(/#{NAME}\s*=(?!=)/o).then do |matched|
          if matched
            @scanner.scan(NAME)
          end
        end
      end

      def assigned_value
        skip_filler
        unless @scanner.scan(/=/)
          raise Error, "expected = in table entry"
        end
        skip_filler
        value
      end

      def number(literal)
        if literal.match?(/[.pPeE]/) || literal.match?(/\A-?0[xX]/)
          Float(literal)
        else
          Integer(literal, 10)
        end
      rescue ArgumentError
        raise Error, "bad number #{literal.inspect}"
      end

      def quoted_string
        @scanner.scan(/["']/).then do |quote|
          String.new.tap do |out|
            until @scanner.scan(/#{Regexp.escape(quote)}/o)
              if @scanner.eos? || @scanner.check(/\n/)
                raise Error, "unterminated string"
              end
              out << string_piece
            end
          end
        end
      end

      def string_piece
        if @scanner.scan(/\\/)
          escape
        else
          @scanner.scan(/[^\\"'\n]+/) || @scanner.getch
        end
      end

      # Lua's escape set. The `\<newline>` form is the one %q emits for a
      # literal newline, and `\ddd` the one it emits for other control
      # characters; `\z` skips following whitespace.
      def escape
        case
        when @scanner.scan(/\n/) then "\n"
        when (digits = @scanner.scan(/\d{1,3}/)) then digits.to_i.chr
        when (hex = @scanner.scan(/x([0-9a-fA-F]{2})/)) then hex[1, 2].to_i(16).chr
        when (point = @scanner.scan(/u\{([0-9a-fA-F]+)\}/)) then point[/\{(.+)\}/, 1].to_i(16).chr(Encoding::UTF_8)
        when @scanner.scan(/z/) then skip_filler.then { "" }
        when (char = @scanner.getch) then SIMPLE_ESCAPES.fetch(char, char)
        else raise Error, "trailing backslash in string"
        end
      end

      SIMPLE_ESCAPES = {
        "a" => "\a",
        "b" => "\b",
        "f" => "\f",
        "n" => "\n",
        "r" => "\r",
        "t" => "\t",
        "v" => "\v",
      }.freeze

      # `[[ ... ]]` and `[==[ ... ]==]`. Lua drops a newline immediately after
      # the opening bracket.
      def long_string
        @scanner.scan(/\[(=*)\[/).then do |opening|
          opening[/\[(=*)\[/, 1].then do |level|
            @scanner.scan(/\n/)
            @scanner.scan_until(/\]#{level}\]/o).then do |body|
              unless body
                raise Error, "unterminated long string"
              end
              body.sub(/\]#{Regexp.escape(level)}\]\z/, "")
            end
          end
        end
      end

      # Whitespace and comments, both of which can appear anywhere a token can.
      def skip_filler
        loop do
          if @scanner.scan(SPACE)
            next
          end
          if long_comment
            next
          end
          if @scanner.scan(LINE_COMMENT)
            next
          end

          break
        end
        self
      end

      def long_comment
        if @scanner.check(/--\[=*\[/)
          @scanner.scan(/--/)
          long_string
        end
      end

      # Upstream writes width and height with %d but reads them back into
      # window properties, and a value comes off a spin button as a double;
      # everything this port stores is an integer.
      def integer_or_nil(number)
        if number.is_a?(Numeric)
          number.to_i
        end
      end

      # writecfg's "maximized = %q" of a boolean emits a bare true/false, but
      # a hand-edited file may well have the string.
      def boolean(flag)
        case flag
        when true, "true" then true
        when false, "false", nil then false
        end
      end
  end
end

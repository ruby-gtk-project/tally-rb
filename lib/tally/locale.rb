# frozen_string_literal: true

module Tally
  # Locale is the port of main.c's `lua_gettext` and of the po/ catalogues.
  #
  # Upstream links against libintl: main.c calls setlocale(LC_ALL, ""),
  # bindtextdomain("messages", "/app/share/locale") and textdomain("messages"),
  # then exposes gettext(3) to Lua as lib.gettext, which both main.lua and
  # counter.lua alias to `_`. There is no C stub here and the gettext gem is
  # not a dependency, so the three catalogues upstream ships (fr, id, it) are
  # read straight out of po/ at startup: the messages domain, the same msgids,
  # and the same fall-back-to-msgid behaviour gettext itself has.
  #
  # Catalogue lookup follows the usual environment precedence —
  # LANGUAGE, LC_ALL, LC_MESSAGES, LANG — and tries the full locale name
  # ("fr_CA") before the bare language ("fr").
  module Locale
    DOMAIN = "messages"
    PO_DIR = File.expand_path("../../po", __dir__)
    ENV_VARS = %w[LANGUAGE LC_ALL LC_MESSAGES LANG].freeze

    class << self
      # The one call site style the rest of the port uses: Locale.gettext("x"),
      # or `_("x")` through the Gettext mixin below.
      def gettext(msgid)
        catalogue.fetch(msgid, msgid)
      end

      # Maps the environment to the po file actually loaded, or nil when the
      # session is in English (or in a language nobody has translated).
      def language
        @language ||= candidates.find { |name| File.file?(po_path(name)) }
      end

      def catalogue
        @catalogue ||= load_catalogue(language)
      end

      # Drops the memoized catalogue so a changed environment is picked up.
      # Nothing in the app calls this; it exists for the specs.
      def reset
        @language = nil
        @catalogue = nil
      end

      def po_path(name) = File.join(PO_DIR, "#{name}.po")

      # "fr_CA.UTF-8@euro" contributes both "fr_CA" and "fr", in that order.
      def candidates
        ENV_VARS.filter_map { |var| ENV.fetch(var, nil) }
          .reject { |value| value.strip.empty? }
          .flat_map { |value| value.split(":") }
          .flat_map { |value| expand(value) }
          .uniq
          .reject { |name| ["C", "POSIX", ""].include?(name) }
      end

      def expand(value)
        value.split(".").first.to_s.split("@").first.to_s.then do |name|
          [name, name.split("_").first].compact.uniq
        end
      end

      private

        def load_catalogue(name)
          if name.nil?
            {}
          else
            parse(File.read(po_path(name), encoding: "UTF-8"))
          end
        end

        # A small po reader: enough for the catalogues upstream ships, which
        # use only msgid/msgstr pairs with continuation lines. The header entry
        # (an empty msgid) and untranslated entries are dropped, so a missing
        # translation falls back to the msgid exactly as gettext would.
        def parse(text)
          {}.tap do |entries|
            state = {msgid: nil, msgstr: nil, field: nil}
            text.each_line do |line|
              consume(entries, state, line.strip)
            end
            commit(entries, state)
          end
        end

        def consume(entries, state, line)
          case line
          when /\Amsgid\s+"(.*)"\z/
            commit(entries, state)
            state[:msgid] = unescape(Regexp.last_match(1))
            state[:msgstr] = nil
            state[:field] = :msgid
          when /\Amsgstr\s+"(.*)"\z/
            state[:msgstr] = unescape(Regexp.last_match(1))
            state[:field] = :msgstr
          when /\A"(.*)"\z/
            append(state, unescape(Regexp.last_match(1)))
          when /\A#/, ""
            state[:field] = nil
          end
        end

        def append(state, fragment)
          state[:field].then do |field|
            if field
              state[field] = "#{state[field]}#{fragment}"
            end
          end
        end

        def commit(entries, state)
          if usable?(state)
            entries[state[:msgid]] = state[:msgstr]
          end
          state[:msgid] = nil
          state[:msgstr] = nil
          state[:field] = nil
        end

        def usable?(state)
          !state[:msgid].to_s.empty? && !state[:msgstr].to_s.empty?
        end

        def unescape(fragment)
          fragment.gsub(/\\(.)/) do
            case Regexp.last_match(1)
            when "n" then "\n"
            when "t" then "\t"
            when "r" then "\r"
            else Regexp.last_match(1)
            end
          end
        end
    end
  end

  # Gettext gives widget classes the same short `_` upstream's Lua files use.
  module Gettext
    private

      def _(msgid) = Locale.gettext(msgid)
  end
end

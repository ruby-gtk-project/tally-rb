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
        #
        # Entries flagged `#, fuzzy` are dropped too, and that is not a detail.
        # A fuzzy entry is msgmerge's guess: when a msgid changes, msgmerge
        # pairs it with the nearest old one and carries that translation over
        # marked as unreviewed. The guesses are frequently wrong — merging
        # upstream's stale catalogues against this port's strings paired
        # "Support this app!" with the *Translate* link's French — and gettext
        # itself never uses a fuzzy translation. Honouring the flag is what
        # keeps a wrong translation from being shown as a right one.
        #
        # Obsolete entries (`#~ msgid`) are ignored by the same rule that
        # ignores every other comment line: the msgid pattern is anchored, so
        # `#~ msgid "x"` is a comment, not a msgid.
        def parse(text)
          {}.tap do |entries|
            state = {msgid: nil, msgstr: nil, field: nil, fuzzy: false, pending_fuzzy: false}
            text.each_line do |line|
              consume(entries, state, line.strip)
            end
            commit(entries, state)
          end
        end

        # The flag comment precedes the msgid it applies to, so it is latched
        # in :pending_fuzzy and only becomes :fuzzy once that msgid arrives —
        # committing the previous entry in between would otherwise clear it.
        def consume(entries, state, line)
          case line
          when /\Amsgid\s+"(.*)"\z/
            commit(entries, state)
            state[:fuzzy] = state[:pending_fuzzy]
            state[:pending_fuzzy] = false
            state[:msgid] = unescape(Regexp.last_match(1))
            state[:msgstr] = nil
            state[:field] = :msgid
          when /\Amsgstr\s+"(.*)"\z/
            state[:msgstr] = unescape(Regexp.last_match(1))
            state[:field] = :msgstr
          when /\A"(.*)"\z/
            append(state, unescape(Regexp.last_match(1)))
          when /\A#,/
            state[:pending_fuzzy] ||= line.include?("fuzzy")
            state[:field] = nil
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
          state[:fuzzy] = false
        end

        def usable?(state)
          !state[:fuzzy] &&
            !state[:msgid].to_s.empty? &&
            !state[:msgstr].to_s.empty?
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

  # Gettext gives widget classes the same short `_` upstream's Lua files use,
  # and the `N_` mark for the msgids that cannot be written inside a `_()`.
  #
  # `N_` is gettext's long-standing no-op: it returns its argument unchanged
  # and exists purely so the extractor can see the string. Several classes here
  # hold their user-visible strings in a frozen table and translate them at the
  # point of use — ShortcutsDialog::SECTIONS, MainMenu::ITEMS,
  # AboutDialog::LINKS, Colors::NAMES — which is the right shape for the code
  # but means the literal is nowhere near a `_(`. Without the mark, `rake pot`
  # extracts nothing for any of them and the strings silently become
  # untranslatable. Including the module also extends the including class with
  # `N_`, because those tables are built in the class body.
  module Gettext
    # The no-op mark, available to the class body.
    module Marks
      def N_(msgid) = msgid
    end

    def self.included(base)
      base.extend(Marks)
    end

    private

      def _(msgid) = Locale.gettext(msgid)
  end
end

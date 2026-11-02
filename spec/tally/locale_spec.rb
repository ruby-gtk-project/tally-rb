# frozen_string_literal: true

RSpec.describe Tally::Locale do
  around do |example|
    ["LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG"].to_h { |key| [key, ENV.fetch(key, nil)] }
      .then do |saved|
        described_class::ENV_VARS.each { |key| ENV.delete(key) }
        described_class.reset
        example.run
      ensure
        saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
        described_class.reset
      end
  end

  describe ".candidates" do
    # Upstream gets this from libintl via setlocale(LC_ALL, ""); the port has
    # no C stub, so the precedence is implemented and therefore has to be
    # pinned: LANGUAGE first, then LC_ALL, LC_MESSAGES and LANG.
    it "puts LANGUAGE ahead of every other variable" do
      ENV["LANG"] = "it_IT.UTF-8"
      ENV["LC_MESSAGES"] = "id_ID.UTF-8"
      ENV["LC_ALL"] = "de_DE.UTF-8"
      ENV["LANGUAGE"] = "fr"

      expect(described_class.candidates.first).to eq("fr")
    end

    it "falls through the remaining variables in order" do
      ENV["LANG"] = "it_IT.UTF-8"
      ENV["LC_MESSAGES"] = "id_ID.UTF-8"

      expect(described_class.candidates.first).to eq("id_ID")
    end

    it "offers the full locale name before the bare language" do
      ENV["LANG"] = "fr_CA.UTF-8@euro"

      expect(described_class.candidates.first(2)).to eq(["fr_CA", "fr"])
    end

    it "splits LANGUAGE's colon-separated list" do
      ENV["LANGUAGE"] = "nl:fr:it"

      expect(described_class.candidates.first(3)).to eq(["nl", "fr", "it"])
    end

    it "ignores the C and POSIX locales and empty values" do
      ENV["LC_ALL"] = "C"
      ENV["LANG"] = "POSIX"

      expect(described_class.candidates).to be_empty
    end

    it "picks the first candidate that has a catalogue on disk" do
      ENV["LANGUAGE"] = "nl:it"

      expect(described_class.language).to eq("it")
    end
  end

  describe ".catalogue" do
    # All three catalogues upstream ships, read by the port's own po reader.
    # The msgid is the fallback, exactly as gettext's is.
    {
      "fr" => ["Tally", "Compteur"],
      "id" => ["Tally", "Penghitung"],
      "it" => ["Tally", "Contatore"],
    }.each do |language, (msgid, msgstr)|
      it "translates through po/#{language}.po" do
        ENV["LANGUAGE"] = language
        described_class.reset

        expect(described_class.language).to eq(language)
        expect(described_class.gettext(msgid)).to eq(msgstr)
      end

      # Every colour name has to be *in* the catalogue; it need not differ
      # from the msgid, because some of them legitimately do not ("Orange" is
      # "Orange" in French). Asking the catalogue directly is the check that
      # means what it says.
      it "carries every colour name in po/#{language}.po" do
        ENV["LANGUAGE"] = language
        described_class.reset

        Tally::Colors::NAMES.each_value do |name|
          expect(described_class.catalogue).to have_key(name)
        end
      end
    end

    it "falls back to the msgid for a language nobody has translated" do
      ENV["LANGUAGE"] = "nl"
      described_class.reset

      expect(described_class.language).to be_nil
      expect(described_class.gettext("Tally")).to eq("Tally")
    end

    it "falls back to the msgid for a string the catalogue does not carry" do
      ENV["LANGUAGE"] = "fr"
      described_class.reset

      expect(described_class.gettext("not a msgid")).to eq("not a msgid")
    end

    it "skips entries msgmerge flagged fuzzy, as gettext does" do
      # A fuzzy entry is msgmerge's unreviewed guess, and merging upstream's
      # stale catalogues against this port's strings produced some wrong ones.
      # Using them would show a wrong translation as a right one.
      described_class.send(
        :parse,
        <<~PO,
          #, fuzzy
          msgid "guessed"
          msgstr "deviné"

          msgid "known"
          msgstr "connu"
        PO
      ).then do |entries|
        expect(entries).to eq({"known" => "connu"})
      end
    end

    it "ignores obsolete entries" do
      described_class.send(
        :parse,
        <<~PO,
          msgid "live"
          msgstr "vivant"

          #~ msgid "dead"
          #~ msgstr "mort"
        PO
      ).then do |entries|
        expect(entries).to eq({"live" => "vivant"})
      end
    end

    it "joins continuation lines and unescapes them" do
      described_class.send(
        :parse,
        <<~PO,
          msgid ""
          "two "
          "parts"
          msgstr ""
          "deux\\n"
          "parties"
        PO
      ).then do |entries|
        expect(entries).to eq({"two parts" => "deux\nparties"})
      end
    end
  end
end

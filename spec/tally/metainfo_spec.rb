# frozen_string_literal: true

RSpec.describe Tally::Metainfo do
  subject(:metainfo) { described_class.new }

  # The About dialog reads its release notes from here precisely so there is
  # one copy; these examples are what makes "one copy" checkable.
  it "reads upstream's whole release history" do
    expect(metainfo.releases.map(&:version)).to eq(
      ["0.7.3", "0.7.2", "0.7.1", "0.7", "0.6.3", "0.6.2", "0.6.1", "0.6",
       "0.5", "0.4.2", "0.4.1", "0.4", "0.3", "0.2", "0.1"
],
    )
  end

  it "reads each release's date" do
    expect(metainfo.latest.date).to eq("2025-12-18")
  end

  it "names the newest release as the version" do
    expect(metainfo.version).to eq("0.7.3")
  end

  it "hands back the latest release's notes as the markup Adwaita wants" do
    expect(metainfo.release_notes).to eq(
      "<p>In-app icons are now supplied by Tally, fixing a bug where icons " \
      "would not be shown if not provided by the user's operating system.</p>\n",
    )
  end

  it "hands back a list-shaped release's notes with the list intact" do
    expect(metainfo.release_notes("0.7.1")).to start_with("<ul>\n<li>Standalone counter windows")
  end

  it "has no notes for a version it does not list" do
    expect(metainfo.release_notes("9.9")).to be_nil
  end

  it "has nothing to say about a file that is not there" do
    described_class.new(path: "does/not/exist.xml").then do |missing|
      expect(missing.releases).to eq([])
      expect(missing.version).to be_nil
      expect(missing.release_notes).to be_nil
    end
  end

  describe "the shipped AppStream files" do
    it "declares the port's own application id, not upstream's" do
      expect(File.read(metainfo.path)).to include("<id>#{described_class::APP_ID}</id>")
    end

    it "has a .Devel twin pointing at the .Devel desktop entry" do
      File.join(described_class::DIR, "#{described_class::APP_ID}.Devel.metainfo.xml").then do |path|
        expect(File.read(path)).to include("<id>#{described_class::APP_ID}.Devel</id>")
        expect(File.read(path)).to include("#{described_class::APP_ID}.Devel.desktop")
      end
    end

    it "keeps upstream's four url entries and its OARS rating" do
      File.read(metainfo.path).then do |xml|
        expect(xml.scan(/<url type="(\w+)">/).flatten)
          .to contain_exactly(
            "bugtracker",
            "contact",
            "homepage",
            "donation",
          )
        expect(xml).to include('<content_rating type="oars-1.1" />')
      end
    end
  end

  describe "the shipped desktop entries" do
    # These are the only strings a user sees before the app starts, so a
    # missing Name[fr] means a French user searching "compteur" finds nothing.
    {
      "Name"     => {"fr" => "Compteur", "id" => "Penghitung", "it" => "Contatore"},
      "Comment"  => {"fr" => "Compter tout", "id" => "Hitung apapun", "it" => "Conta qualsiasi cosa"},
      "Keywords" => {
        "fr" => "tally;compteur;compteur manuel;",
        "id" => "tally;penghitung;hitung;",
        "it" => "tally;contatore;conteggio;contatore manuale;",
      },
    }.each do |key, translations|
      translations.each do |language, value|
        it "carries #{key}[#{language}] byte for byte" do
          expect(desktop_entry).to include("#{key}[#{language}]=#{value}\n")
        end
      end
    end

    it "points at the application icon of the same name" do
      expect(desktop_entry).to include("Icon=#{described_class::APP_ID}\n")
      expect(devel_desktop_entry).to include("Icon=#{described_class::APP_ID}.Devel\n")
    end

    it "keeps upstream's Categories, Exec, Terminal and StartupNotify" do
      expect(desktop_entry).to include("Categories=Utility;\n", "Exec=tally\n")
      expect(desktop_entry).to include("Terminal=false\n", "StartupNotify=false\n")
    end

    def desktop_entry
      File.read(File.join(described_class::DIR, "#{described_class::APP_ID}.desktop"))
    end

    def devel_desktop_entry
      File.read(File.join(described_class::DIR, "#{described_class::APP_ID}.Devel.desktop"))
    end
  end
end

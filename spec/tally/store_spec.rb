# frozen_string_literal: true

require "json"
require "tmpdir"

# Upstream has no tests at all — an empty census, no test directory and no test
# target — so test parity is 0/0 and met by writing nothing. These examples are
# therefore outside the parity count: they pin behaviour this port invented or
# reimplemented, where upstream had a Lua file and a Flatpak sandbox instead.
RSpec.describe Tally::Store do
  around do |example|
    Dir.mktmpdir("tally-store") do |dir|
      @dir = File.join(dir, "tally")
      example.run
    end
  end

  let(:store) { described_class.new(dir: @dir) }

  def write_config(contents, name: described_class::FILE_NAME)
    FileUtils.mkdir_p(@dir)
    File.write(File.join(@dir, name), contents)
  end

  # Upstream's writecfg emits this; counter:serialize writes a float value as a
  # C99 hex float and escapes a newline as a backslash plus a real newline, so
  # both appear here deliberately.
  let(:upstream_config) do
    <<~LUA
      return {
      \twidth = 742,
      height = 913,
      maximized = true,
      {
      \t["name"] = "Coffee",
      \t["value"] = 0x1.8p+1,
      \t["color"] = "red",
      },
      {
      \t["name"] = "He said \\"hi\\"\\
      \\9and left",
      \t["value"] = 0,
      \t["checked"] = false,
      },

      }
    LUA
  end

  describe "a round trip" do
    it "reads back the counters it wrote, in order" do
      Tally::Counter.clear
      ["Tea", "Coffee", "Water"].each_with_index do |name, index|
        Tally::Counter.register(Tally::Counter.new(name: name, value: index, color: "blue"))
      end

      expect(store.write).to be(true)

      described_class.new(dir: @dir).saved_counters.then do |reloaded|
        expect(reloaded.map(&:name)).to eq(["Tea", "Coffee", "Water"])
        expect(reloaded.map(&:value)).to eq([0, 1, 2])
        expect(reloaded.map(&:color)).to eq(["blue", "blue", "blue"])
      end
    end

    it "writes through the temp file and leaves none behind" do
      Tally::Counter.clear
      store.write
      expect(File.exist?(store.temp_path)).to be(false)
      expect(JSON.parse(File.read(store.path))).to include("counters" => [])
    end
  end

  describe "a config it cannot parse" do
    it "does not report it as an empty config" do
      write_config("\x00\x01 this is not a config {{{")

      expect(store.unreadable).to eq(store.path)
      expect(store.saved_counters).to eq([])
    end

    it "refuses to write over it" do
      write_config("\x00\x01 this is not a config {{{")
      before = File.binread(store.path)

      expect(store.write).to be(false)
      expect(File.binread(store.path)).to eq(before)
    end

    it "arms no debounced write either" do
      write_config("\x00\x01 this is not a config {{{")

      expect(store.queue_write).to eq(0)
    end

    it "prefers a readable main file to an unreadable temp one, as readcfg does" do
      write_config("half-writ", name: described_class::TEMP_NAME)
      write_config(JSON.generate({"width" => 321, "counters" => [{"name" => "a", "value" => 7}]}))

      expect(store.unreadable).to be_nil
      expect(store.saved_counters.map(&:name)).to eq(["a"])
      expect(store.width).to eq(321)
      expect(store.write).to be(true)
    end
  end

  describe "a first launch" do
    it "has no unreadable file and writes freely" do
      expect(store.unreadable).to be_nil
      expect(store.imported?).to be(false)
      expect(store.width).to eq(described_class::DEFAULT_WIDTH)
      expect(store.write).to be(true)
    end
  end

  describe "importing upstream's Lua config" do
    it "reads the counters and the geometry out of it" do
      write_config(upstream_config)

      expect(store.imported?).to be(true)
      expect(store.width).to eq(742)
      expect(store.height).to eq(913)
      expect(store.maximized?).to be(true)
      expect(store.saved_counters.map(&:name)).to eq(["Coffee", "He said \"hi\"\n\tand left"])
      expect(store.saved_counters.map(&:value)).to eq([3, 0])
      expect(store.saved_counters.map(&:color)).to eq(["red", nil])
    end

    it "rewrites the file as JSON and keeps the Lua as a backup" do
      write_config(upstream_config)
      store.document

      expect(JSON.parse(File.read(store.path))).to include("width" => 742)
      expect(File.read(store.backup_path)).to eq(upstream_config)
    end

    it "imports once, so the next launch simply reads JSON" do
      write_config(upstream_config)
      store.document

      described_class.new(dir: @dir).then do |second|
        expect(second.imported?).to be(false)
        expect(second.saved_counters.map(&:name)).to eq(store.saved_counters.map(&:name))
      end
    end
  end

  describe "#queue_write" do
    # Upstream's lib.queuewrite counts pending writes and only the last one
    # standing writes; the timeouts need a main loop, so what is checked here
    # is the counter, which is the part that decides.
    it "counts the pending writes rather than writing once each" do
      expect(store.queue_write).to eq(1)
      expect(store.queue_write).to eq(2)
      expect(store.queue_write).to eq(3)
    end

    it "is cancelled by an immediate write" do
      store.queue_write
      store.queue_write
      Tally::Counter.clear
      store.write

      expect(store.queue_write).to eq(1)
    end
  end

  describe "#prepare" do
    it "removes a non-directory sitting where the config directory belongs" do
      FileUtils.mkdir_p(File.dirname(@dir))
      File.write(@dir, "not a directory")

      store.prepare

      expect(File.directory?(@dir)).to be(true)
    end
  end
end

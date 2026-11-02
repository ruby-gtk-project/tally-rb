# frozen_string_literal: true

RSpec.describe Tally::LuaConfig do
  describe "upstream's own output" do
    # Generated with Lua 5.4 against upstream's writecfg format strings, so the
    # oddities here are real and not invented: %q writes a float as a C99 hex
    # float, a boolean bare, a literal newline as a backslash plus a newline,
    # and a tab as the decimal escape \9.
    let(:config) do
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
        \\9and left\\\\",
        \t["value"] = 0,
        \t["checked"] = false,
        },
        {
        \t["name"] = "Étoile — ünïcode",
        \t["value"] = 0x1.e848p+19,
        \t["color"] = "purple",
        \t["checkmode"] = true,
        },
        {
        \t["name"] = "plain",
        \t["value"] = 12,
        },

        }
      LUA
    end

    subject(:document) { described_class.parse(config) }

    it "reads the geometry" do
      expect(document).to include("width" => 742, "height" => 913, "maximized" => true)
    end

    it "reads a hex float value back as the integer it was" do
      expect(document["counters"].map { |counter| counter["value"] }).to eq([3, 0, 1_000_000, 12])
    end

    it "unescapes a name with quotes, a newline, a tab and a backslash" do
      expect(document["counters"][1]["name"]).to eq("He said \"hi\"\n\tand left\\")
    end

    it "keeps a UTF-8 name intact" do
      expect(document["counters"][2]["name"]).to eq("Étoile — ünïcode")
    end

    it "drops the transient flags, as upstream's readcfg does" do
      expect(document["counters"].map(&:keys).flatten.uniq).to contain_exactly("name", "value", "color")
    end
  end

  describe "the file upstream seeds a fresh install with" do
    it "reads as an empty document" do
      expect(described_class.parse("return {}\n")).to eq({"maximized" => false, "counters" => []})
    end
  end

  describe "things that are not upstream's config" do
    # Refusing is the whole point: Store tells "no config" from "a config I
    # could not read" by whether this raises, and only refuses to write in the
    # second case.
    [
      ["an unterminated table", "return { oops"],
      ["JSON", '{"width": 1}'],
      ["a function call", 'os.execute("rm -rf /")'],
      ["a bare value", "return 7"],
      ["an unterminated string", 'return { ["name"] = "x }'],
      ["nothing at all", ""],
    ].each do |label, text|
      it "raises Error for #{label}" do
        expect { described_class.parse(text) }.to raise_error(described_class::Error)
      end
    end

    it "never evaluates what it reads" do
      expect { described_class.parse('return { os.exit(1) }') }.to raise_error(described_class::Error)
    end
  end

  describe "a hand-edited config" do
    it "accepts comments, decimal numbers and unquoted keys" do
      described_class.parse(<<~LUA).then do |document|
        -- my counters
        return {
          width = 400, --[[ wide enough ]] height = 500,
          { name = "Tea", value = 7.0, color = "green" };
        }
      LUA
        expect(document).to include("width" => 400, "height" => 500)
        expect(document["counters"]).to eq([{"name" => "Tea", "value" => 7, "color" => "green"}])
      end
    end

    it "accepts a quoted maximized flag" do
      expect(described_class.parse('return { maximized = "true" }')).to include("maximized" => true)
    end
  end
end

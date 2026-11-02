# frozen_string_literal: true

RSpec.describe Tally::Colors do
  # Upstream keeps the same distinction and never writes it down: a counter's
  # `color` field is nil for "no colour", while counter:getcolor() and the CSS
  # class for it are the string "system". Everything that reads a colour has to
  # pick the right one of the two.
  describe "the nil / \"system\" round trip" do
    it "maps nil to \"system\" and back" do
      expect(described_class.key(nil)).to eq(described_class::SYSTEM)
      expect(described_class.value(described_class::SYSTEM)).to be_nil
      expect(described_class.value(described_class.key(nil))).to be_nil
    end

    it "leaves a real colour untouched in both directions" do
      described_class::ACCENTS.each do |color|
        expect(described_class.key(color)).to eq(color)
        expect(described_class.value(color)).to eq(color)
      end
    end

    it "treats an empty string as no colour" do
      expect(described_class.key("")).to eq(described_class::SYSTEM)
      expect(described_class.value("")).to eq("")
    end

    it "answers upstream's getcolorname for nil and \"system\" alike" do
      expect(described_class.name(nil)).to eq(described_class.name(described_class::SYSTEM))
    end

    it "counts only the six real colours as accents" do
      expect(described_class.accent?(nil)).to be(false)
      expect(described_class.accent?(described_class::SYSTEM)).to be(false)
      expect(described_class::ACCENTS.all? { |color| described_class.accent?(color) }).to be(true)
    end
  end
end

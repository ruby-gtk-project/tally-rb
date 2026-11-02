# frozen_string_literal: true

RSpec.describe Tally::Counter do
  before { described_class.clear }

  describe "#value=" do
    # Upstream's spin button is created with
    # Gtk.SpinButton.new_with_range(0, 1000000, 1), so the clamping lives in
    # the widget and the field simply records whatever the widget allowed. This
    # port moved the range onto the model, which means the model has to clamp.
    # An assignment expression in Ruby evaluates to the right-hand side
    # whatever the writer returns, so these read the attribute back rather than
    # the assignment.
    it "clamps to the spin button's range" do
      counter = described_class.new(name: "x")

      counter.value = -5
      expect(counter.value).to eq(described_class::MIN_VALUE)

      counter.value = 1_000_001
      expect(counter.value).to eq(described_class::MAX_VALUE)

      counter.value = 42
      expect(counter.value).to eq(42)
    end

    it "clamps at construction too" do
      expect(described_class.new(name: "x", value: -1).value).to eq(described_class::MIN_VALUE)
      expect(described_class.new(name: "x", value: 2_000_000).value).to eq(described_class::MAX_VALUE)
    end

    it "notifies subscribers once per actual change" do
      counter = described_class.new(name: "x", value: 3)
      changes = []
      counter.on_change { |_counter, what| changes.push(what) }

      counter.value = 4
      counter.value = 4
      counter.value = 5

      expect(changes).to eq([:value, :value])
    end

    it "stays silent when a clamped value is the one already held" do
      counter = described_class.new(name: "x", value: described_class::MAX_VALUE)
      changes = []
      counter.on_change { |_counter, what| changes.push(what) }

      counter.value = 9_999_999

      expect(changes).to be_empty
    end
  end

  describe ".move" do
    # Upstream's four reorder handlers each do their own
    # table.remove/table.insert pair against the module-level `counters` table;
    # all four are this one method here, so it carries all four cases.
    let(:counters) { ["a", "b", "c", "d"].map { |name| described_class.new(name: name) } }

    before { counters.each { |counter| described_class.register(counter) } }

    def order = described_class.counters.map(&:name)

    it "moves a counter to the top, as topbtn does" do
      described_class.move(counters[2], 0)
      expect(order).to eq(["c", "a", "b", "d"])
    end

    it "moves a counter to the bottom, as bottombtn does" do
      described_class.move(counters[0], described_class.counters.length)
      expect(order).to eq(["b", "c", "d", "a"])
    end

    it "moves a counter up one place, as upbtn does" do
      described_class.move(counters[2], 1)
      expect(order).to eq(["a", "c", "b", "d"])
    end

    it "moves a counter down one place, as downbtn does" do
      described_class.move(counters[1], 2)
      expect(order).to eq(["a", "c", "b", "d"])
    end

    it "clamps a target past either end rather than dropping the counter" do
      described_class.move(counters[0], 99)
      expect(order).to eq(["b", "c", "d", "a"])

      described_class.move(counters[0], -3)
      expect(order).to eq(["a", "b", "c", "d"])
    end

    it "leaves the list alone for a counter it does not hold" do
      described_class.move(described_class.new(name: "stranger"), 0)
      expect(order).to eq(["a", "b", "c", "d"])
    end
  end

  describe "#name=" do
    it "refuses a blank name, as upstream's entry handler does" do
      counter = described_class.new(name: "Coffee")

      counter.name = "   "
      expect(counter.name).to eq("Coffee")

      counter.name = "Tea"
      expect(counter.name).to eq("Tea")
    end
  end

  describe "serialization" do
    it "round-trips through .from_h with either key style" do
      counter = described_class.new(name: "Coffee", value: 3, color: "red")

      expect(described_class.from_h(counter.serialize).serialize).to eq(counter.serialize)
      expect(described_class.from_h({name: "Tea", value: 2, color: "blue"}).serialize)
        .to eq({"name" => "Tea", "value" => 2, "color" => "blue"})
    end
  end
end

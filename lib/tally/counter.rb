# frozen_string_literal: true

require_relative "colors"

module Tally
  # Counter is the data half of counter.lua's counter class.
  #
  # Upstream's class is one object holding both the fields and every widget
  # that shows them; here the widgets live in CounterRow, CounterMenu and
  # CounterWindow, and this class keeps only what gets written to disk plus the
  # two transient selection flags. Interested widgets subscribe with
  # #on_change, #on_color_change and #on_delete rather than being reached into.
  #
  # The two registries upstream keeps as module-level Lua tables (`counters`
  # and `counterrows`) are class-level here, with the same jobs: `counters` is
  # the ordered list the config file is written from, and `rows` maps a
  # Gtk::ListBoxRow back to its counter for the list's filter and
  # row-activated handlers.
  class Counter
    DEFAULT_NAME = "unnamed"
    MIN_VALUE = 0
    MAX_VALUE = 1_000_000

    class << self
      # Ordered, and the order is what gets serialized: reordering a row has to
      # reorder this list too, which is what #move is for.
      def counters = @counters ||= []

      def rows = @rows ||= {}

      def register(counter, row: nil)
        counters.push(counter)
        bind_row(counter, row)
        counter
      end

      # Inserts at a position instead of appending — used when a config file is
      # read back, where the stored order has to be preserved.
      def insert(counter, index, row: nil)
        counters.insert(index, counter)
        bind_row(counter, row)
        counter
      end

      def bind_row(counter, row)
        if row
          rows[row] = counter
        end
        counter
      end

      def for_row(row) = rows[row]

      def index_of(counter) = counters.index(counter)

      # Lifts the counter out of the list and puts it back at `to`, which is
      # what upstream's table.remove/table.insert pairs do around every
      # reorder.
      def move(counter, to)
        index_of(counter).then do |from|
          if from
            counters.delete_at(from)
            counters.insert(to.clamp(0, counters.length), counter)
          end
        end
        counters
      end

      def forget(counter)
        counters.delete(counter)
        rows.delete_if { |_row, value| value == counter }
        counter
      end

      def empty? = counters.empty?

      # Drops both registries. Used when a window is torn down and rebuilt,
      # which only the specs do.
      def clear
        counters.clear
        rows.clear
      end
    end

    attr_reader :name, :value, :color

    # checkmode is "the list is in select-and-delete mode", checked is "this
    # counter's box is ticked". Neither survives a restart: upstream writes
    # them out because serialize() dumps every scalar field it finds, but
    # readcfg only ever hands name, value and color to the constructor.
    attr_accessor :checked, :checkmode

    def initialize(name: DEFAULT_NAME, value: 0, color: nil)
      @name = presence(name) || DEFAULT_NAME
      @value = clamp(value)
      @color = Colors.value(color)
      @checked = false
      @checkmode = false
      @change_callbacks = []
      @color_callbacks = []
      @delete_callbacks = []
    end

    # Builds a counter from a deserialized entry, tolerating string or symbol
    # keys so a hand-edited config file still loads.
    def self.from_h(hash)
      new(
        name:  fetch_field(hash, :name),
        value: fetch_field(hash, :value),
        color: fetch_field(hash, :color),
      )
    end

    def self.fetch_field(hash, key)
      hash[key] || hash[key.to_s]
    end

    def name=(new_name)
      presence(new_name).then do |stripped|
        if stripped
          @name = stripped
          notify(:name)
        end
      end
      @name
    end

    def value=(new_value)
      clamp(new_value).then do |clamped|
        unless clamped == @value
          @value = clamped
          notify(:value)
        end
      end
      @value
    end

    # Upstream's counter:getcolor() — the CSS class and filter key, where a
    # colourless counter answers "system" rather than nil.
    def color_key = Colors.key(@color)

    # Upstream's counter:setcolor(). Subscribers are handed the previous key as
    # well, because swapping the CSS class means removing the old one first.
    def color=(new_color)
      Colors.value(new_color).then do |stored|
        unless stored == @color
          color_key.then do |previous|
            @color = stored
            @color_callbacks.each { |callback| callback.call(self, previous) }
            notify(:color)
          end
        end
      end
      @color
    end

    def on_change(&block) = @change_callbacks.push(block)
    def on_color_change(&block) = @color_callbacks.push(block)
    def on_delete(&block) = @delete_callbacks.push(block)

    # Upstream's counter:delete() also pulls the row out of the list box and
    # closes the pop-out window; both are the subscribers' business now, and
    # they run before the counter leaves the registry so they can still find
    # its index.
    def delete
      @delete_callbacks.each { |callback| callback.call(self) }
      self.class.forget(self)
      self
    end

    # The on-disk form. Upstream's serialize() emits a Lua table literal
    # because the config file is Lua source; this port writes JSON, so the
    # method hands back the hash and Store does the encoding.
    def serialize
      {
        "name"  => @name,
        "value" => @value,
        "color" => @color,
      }
    end

    def to_h = serialize

    private

      def notify(what)
        @change_callbacks.each { |callback| callback.call(self, what) }
      end

      def clamp(number) = number.to_i.clamp(MIN_VALUE, MAX_VALUE)

      def presence(string)
        string.to_s.strip.then do |stripped|
          if stripped.empty?
            nil
          else
            stripped
          end
        end
      end
  end
end

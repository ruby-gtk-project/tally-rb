# frozen_string_literal: true

require "adwaita"
require_relative "colors"
require_relative "color_selector"
require_relative "counter"
require_relative "locale"

module Tally
  # CounterMenu is the port of counter.lua's counter:createmenu.
  #
  # An Adw.ExpanderRow's disclosure holds four rows, added here rather than in
  # CounterRow because they get added twice: once to the real row, and once to
  # the throwaway CounterDragRow used as a drag preview. That second call is
  # what `duplicate:` is for — upstream detects it by noticing self.entry is
  # already set, desensitises every control, and skips wiring the handlers
  # entirely, so the preview cannot edit the counter it is a picture of.
  #
  # The four rows are the name EntryRow, a Color row carrying a radio
  # ColorSelector, a Reorder row with move-to-top / up / down / move-to-bottom
  # buttons, and a Pop-out row.
  #
  # Reordering keeps two orders in step: the list box's child order and
  # Counter.counters, which is what gets serialized. The up and down buttons
  # skip rows the filter has hidden, since moving a counter above something
  # invisible would look like nothing happened.
  class CounterMenu
    include Gettext

    def initialize(counter:, row:, store: nil, list: nil, duplicate: false, &on_popout)
      @counter = counter
      @row = row
      @store = store
      @list = list
      @duplicate = duplicate
      @on_popout = on_popout
    end

    attr_reader :counter, :row

    def duplicate? = @duplicate

    def attach
      tap do
        row.add_row(name_row)
        row.add_row(color_row)
        row.add_row(order_row)
        row.add_row(popout_row)

        unless duplicate?
          connect
        end
      end
    end

    def name_row
      @name_row ||= Adwaita::EntryRow.new.tap do |entry|
        entry.title = _("Name")
        entry.text = counter.name
        entry.sensitive = !duplicate?
      end
    end

    def color_row
      @color_row ||= Adwaita::ActionRow.new.tap do |action_row|
        action_row.title = _("Color")
        action_row.sensitive = !duplicate?
        action_row.add_suffix(color_selector.build)
      end
    end

    def color_selector
      @color_selector ||= ColorSelector.new(mode: :radio, selected: counter.color_key) do |selector|
        recolor(selector.selected_color)
      end
    end

    def order_row
      @order_row ||= Adwaita::ActionRow.new.tap do |action_row|
        action_row.title = _("Reorder in List")
        action_row.add_suffix(order_box)
      end
    end

    # valign on the box rather than on each button: in a horizontal box the
    # buttons stretch to the box's height, so centring the box centres them.
    def order_box
      @order_box ||= Gtk::Box.new(:horizontal, 6).tap do |box|
        box.halign = :end
        box.valign = :center
        box.append(top_button)
        box.append(up_button)
        box.append(down_button)
        box.append(bottom_button)
      end
    end

    def top_button
      @top_button ||= order_button(
        "move-top-symbolic",
        _("Move counter to the top of the current list"),
      )
    end

    def up_button
      @up_button ||= order_button(
        "move-up-symbolic",
        _("Move counter to just above the previous row"),
      )
    end

    def down_button
      @down_button ||= order_button(
        "move-down-symbolic",
        _("Move counter to just below the next row"),
      )
    end

    def bottom_button
      @bottom_button ||= order_button(
        "move-bottom-symbolic",
        _("Move counter to the bottom of the current list"),
      )
    end

    def popout_row
      @popout_row ||= Adwaita::ActionRow.new.tap do |action_row|
        action_row.title = _("Show in a Separate Window")
        action_row.add_suffix(popout_button)
      end
    end

    def popout_button
      @popout_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = "pop-out-symbolic"
        button.tooltip_text = _("Create a new window for this counter")
        button.halign = :end
        button.hexpand = true
        button.valign = :center
        button.sensitive = !duplicate?
      end
    end

    # Keeps the entry in step when the name changes somewhere else — the
    # pop-out window's title is bound to this entry, so it has to be the one
    # source of the name.
    def refresh
      tap do
        unless name_row.text == counter.name
          name_row.text = counter.name
        end
      end
    end

    private

      def order_button(icon_name, tooltip)
        Gtk::Button.new.tap do |button|
          button.icon_name = icon_name
          button.tooltip_text = tooltip
          button.sensitive = !duplicate?
        end
      end

      def connect
        name_row.signal_connect("changed") { rename(name_row.text.to_s) }
        top_button.signal_connect("clicked") { move_to(0) }
        bottom_button.signal_connect("clicked") { move_to(-1) }
        up_button.signal_connect("clicked") { move_up }
        down_button.signal_connect("clicked") { move_down }
        popout_button.signal_connect("clicked") { @on_popout&.call(counter) }
      end

      # An empty name is refused rather than stored: the row grows the "error"
      # class and keeps the name it had.
      def rename(text)
        if text.strip.empty?
          row.add_css_class("error")
        else
          row.remove_css_class("error")
          counter.name = text
          @store&.queue_write
        end
      end

      def recolor(color)
        counter.color = color
        @store&.queue_write
      end

      def list_box = row.parent

      def move_up
        previous_visible_index.then do |index|
          if index
            move_to(index)
          end
        end
      end

      def move_down
        next_visible_index.then do |index|
          if index
            move_to(index)
          end
        end
      end

      def previous_visible_index
        (0...row.index).reverse_each.find { |index| visible_at?(index) }
      end

      def next_visible_index
        ((row.index + 1)...Counter.counters.length).find { |index| visible_at?(index) }
      end

      def visible_at?(index)
        list_box&.get_row_at_index(index)&.mapped?
      end

      # -1 means "append", which is how the bottom button is expressed.
      def move_to(index)
        list_box.then do |box|
          if box
            reindex(box, index)
          end
        end
      end

      def reindex(box, index)
        Counter.move(counter, normalize(index))
        box.remove(row)
        box.insert(row, index)
        @store&.queue_write
        scroll_later
      end

      def normalize(index)
        if index.negative?
          Counter.counters.length - 1
        else
          index
        end
      end

      # Upstream waits 50ms before scrolling, so the list has relaid out and
      # the row's new allocation is the one being scrolled to.
      def scroll_later
        GLib::Timeout.add(50) do
          @list&.scroll_into_view(row)
          false
        end
      end
  end
end

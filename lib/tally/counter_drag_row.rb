# frozen_string_literal: true

require "adwaita"
require_relative "counter"
require_relative "counter_menu"
require_relative "colors"

module Tally
  # CounterDragRow is the port of counter.lua's counter:duplicate.
  #
  # Dragging a row cannot show the row itself — it is still in the list, being
  # dragged out of it — so upstream builds a throwaway ExpanderRow that looks
  # like it: same title, same colour class, same drag handle, a plain spin
  # button showing the same number, and the same expanded state, so a row
  # picked up while open is previewed open.
  #
  # CounterMenu is attached in duplicate mode, which desensitises every control
  # on it: the preview is a picture, and nothing on it may edit the counter.
  # The row is thrown away when the drag ends.
  class CounterDragRow < Adwaita::ExpanderRow
    def initialize(counter, expanded: false)
      super()
      @counter = counter
      self.title = counter.name
      self.expanded = expanded
      if Colors.accent?(counter.color)
        add_css_class(counter.color_key)
      end
    end

    def build
      tap do |row|
        row.add_prefix(drag_handle)
        row.add_suffix(spin_button)
        menu.attach
      end
    end

    def menu = @menu ||= CounterMenu.new(counter: @counter, row: self, duplicate: true)

    def drag_handle
      @drag_handle ||= Gtk::Image.new(icon_name: "drag-handle-symbolic").tap do |image|
        image.add_css_class("drag-handle")
      end
    end

    def spin_button
      @spin_button ||= Gtk::SpinButton.new(adjustment, 1.0, 0).tap do |spin|
        spin.valign = :center
      end
    end

    def adjustment
      @adjustment ||= Gtk::Adjustment.new(
        @counter.value.to_f,
        Counter::MIN_VALUE.to_f,
        Counter::MAX_VALUE.to_f,
        1.0,
        10.0,
        0.0,
      )
    end
  end
end

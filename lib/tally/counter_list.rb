# frozen_string_literal: true

require "adwaita"
require_relative "counter"

module Tally
  # CounterList is the port of main.lua's lbox / clamp / multi section, of its
  # enlarge and shrink helpers, and of the two scrolling actions —
  # counter:scroll and window:scrollbottom.
  #
  # The list is a Gtk.ListBox with the "tally-list" class, which is what the
  # stylesheet hangs the per-colour row tints off. It lives in an
  # Adw.MultiLayoutView with two layouts over one slot: the wide layout wraps
  # the slot in an Adw.Clamp with margins, and the narrow one uses the slot
  # bare, so the breakpoint can move the same list between them without
  # rebuilding it. The class swap that goes with it is upstream's: "boxed-list"
  # when clamped, "separators" when edge to edge.
  #
  # Scrolling is done against the vertical adjustment rather than
  # Gtk::Viewport#scroll_to: the row's offset inside the scrolled window is the
  # sum of the allocations between them, which needs no API newer than the rest
  # of the port.
  class CounterList < Gtk::ScrolledWindow
    LIST_SLOT = "list"
    CLAMP_MAX = 600
    BOTTOM_DELAY_MS = 20

    # filter: a callable taking a Counter and answering whether its row shows.
    # The block, when given, is told :wide or :narrow on every layout change,
    # which is how the window keeps its top-bar style in step.
    def initialize(filter: nil, &on_layout)
      super()
      @filter = filter
      @on_layout = on_layout
      self.hscrollbar_policy = :never
    end

    def build
      tap do |scrolled|
        scrolled.child = multi_layout_view

        multi_layout_view.tap do |multi|
          multi.set_child(LIST_SLOT, list_box)
          multi.add_layout(wide_layout)
          multi.add_layout(narrow_layout)
        end

        list_box.tap do |box|
          box.set_filter_func { |row| visible_row?(row) }
          box.signal_connect("row-activated") { |_box, row| activate(row) }
        end

        enlarge
      end
    end

    def multi_layout_view = @multi_layout_view ||= Adwaita::MultiLayoutView.new

    # Hidden until it has a row: an empty boxed list draws an empty frame, and
    # the status page is what should be seen instead.
    def list_box
      @list_box ||= Gtk::ListBox.new.tap do |box|
        box.selection_mode = :none
        box.valign = :start
        box.visible = false
        box.add_css_class("tally-list")
      end
    end

    def wide_layout = @wide_layout ||= Adwaita::Layout.new(clamp)
    def narrow_layout = @narrow_layout ||= Adwaita::Layout.new(Adwaita::LayoutSlot.new(LIST_SLOT))

    def clamp
      @clamp ||= Adwaita::Clamp.new.tap do |widget|
        widget.child = Adwaita::LayoutSlot.new(LIST_SLOT)
        widget.maximum_size = CLAMP_MAX
        widget.margin_start = 24
        widget.margin_end = 24
        widget.margin_top = 12
        widget.margin_bottom = 12
      end
    end

    def append(row)
      tap do
        list_box.append(row)
        refresh_visibility
      end
    end

    def empty? = list_box.get_row_at_index(0).nil?

    # Upstream hides and shows the list box in four different places; it is one
    # method here, called after every append and every delete.
    def refresh_visibility
      tap do
        list_box.visible = !empty?
      end
    end

    def invalidate_filter
      tap do
        list_box.invalidate_filter
      end
    end

    # Upstream's enlarge(): clamped, boxed, no separators.
    def enlarge
      tap do
        multi_layout_view.layout = wide_layout
        list_box.remove_css_class("separators")
        list_box.add_css_class("boxed-list")
        @on_layout&.call(:wide)
      end
    end

    # Upstream's shrink(): edge to edge, separators instead of a frame.
    def shrink
      tap do
        multi_layout_view.layout = narrow_layout
        list_box.remove_css_class("boxed-list")
        list_box.add_css_class("separators")
        @on_layout&.call(:narrow)
      end
    end

    # Upstream's counter:scroll — bring an expanded or just-moved row fully
    # into view, without moving if it already is.
    def scroll_into_view(row)
      adjustment = vadjustment
      top = offset_in_view(row)
      bottom = top + row.allocation.height
      if top < adjustment.value
        adjustment.value = top
      elsif bottom > adjustment.value + adjustment.page_size
        adjustment.value = bottom - adjustment.page_size
      end
      self
    end

    # Upstream's window:scrollbottom — used after a counter is created, with
    # the same short delay, so the new row has been allocated before the
    # adjustment is read.
    def scroll_to_bottom
      tap do
        GLib::Timeout.add(BOTTOM_DELAY_MS) do
          vadjustment.value = vadjustment.upper
          false
        end
      end
    end

    private

      # The filter is handed the counter, not the row, so the search bar never
      # has to know about the registry.
      def visible_row?(row)
        Counter.for_row(row).then do |counter|
          if counter && @filter
            @filter.call(counter)
          else
            true
          end
        end
      end

      # Activating a row only means something in select mode, where it ticks
      # the row's check button.
      def activate(row)
        if row.respond_to?(:toggle_check)
          row.toggle_check
        end
      end

      # Sums the allocations from the row up to this scrolled window, which is
      # the row's y position in scrolled coordinates.
      def offset_in_view(widget)
        if widget.nil? || widget == self
          0
        else
          widget.allocation.y + offset_in_view(widget.parent)
        end
      end
  end
end

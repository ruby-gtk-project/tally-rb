# frozen_string_literal: true

require "adwaita"
require_relative "colors"

module Tally
  # ColorSelector is the port of counter.lua's counter:colorrow and
  # counter:gencolorcheck, and of the two copies of the same widget main.lua
  # open-codes in the search bar and in the new-counter dialog.
  #
  # It is a horizontal Box carrying the "colorselector" CSS class and one
  # CheckButton per colour, each with the colour's own class so the stylesheet
  # can paint it. The three call sites differ in exactly two ways, both of
  # which are the `mode:` argument here:
  #
  # * :radio (counter:colorrow, the new-counter dialog) groups the six accent
  #   buttons onto the "no colour" button, so exactly one is ever active, and
  #   leaves that first button unclassed — the base stylesheet paints it as a
  #   black/white diagonal.
  # * :multi (the search bar) leaves the buttons ungrouped so any number can be
  #   ticked, and gives the first one the "system" class, which the light and
  #   dark sheets paint solid white and solid black respectively.
  #
  # Vertical alignment is the third per-site difference, and it is an argument
  # rather than something this class decides. Only counter:colorrow
  # (counter.lua:201-207) sets valign = "CENTER"; searchcolorbox
  # (main.lua:317-321) and tallycolorbox (main.lua:567-571) set no alignment at
  # all, so upstream's search bar and new-counter dialog lay the 28x28px checks
  # out at GTK's default FILL. DEFAULT_VALIGN is that default, written down so
  # the two sites that want it can be seen to have asked for nothing.
  #
  # Upstream's notify::active handlers fire on deactivation too, so switching
  # from red to blue runs setcolor("red") before setcolor("blue") and only
  # lands on the right answer because GTK deactivates the outgoing button
  # first. This port ignores the deactivation half instead.
  class ColorSelector < Gtk::Box
    SPACING = 6

    # Gtk::Widget's own default, which is what upstream's two unaligned copies
    # of this box get.
    DEFAULT_VALIGN = :fill

    attr_reader :mode, :checks

    def initialize(mode: :radio, selected: nil, valign: DEFAULT_VALIGN, &on_change)
      super(:horizontal, SPACING)
      @mode = mode
      @selected = Colors.key(selected)
      @on_change = on_change
      @checks = {}
      add_css_class("colorselector")
      self.valign = valign
    end

    def build
      tap do |box|
        Colors::ALL.each { |key| box.append(check(key)) }
      end
    end

    def radio? = @mode == :radio
    def multi? = @mode == :multi

    # The stored colour the radio group currently names: nil for "no colour".
    def selected_color = Colors.value(@selected)

    # The keys ticked in :multi mode, in the stylesheet's order.
    def active_colors
      Colors::ALL.select { |key| @checks[key]&.active? }
    end

    # Upstream's filtcolors.active: true once at least one colour is ticked,
    # which is what turns colour filtering on at all.
    def filtering? = active_colors.any?

    # With nothing ticked every colour passes, matching upstream's filter.
    def matches?(color_key)
      if filtering?
        active_colors.include?(Colors.key(color_key))
      else
        true
      end
    end

    # Clears every tick. The search bar calls this whenever search mode is
    # toggled, so a hidden search bar never keeps filtering the list.
    def reset
      tap do
        @checks.each_value do |button|
          button.active = false
        end
      end
    end

    def check(key)
      @checks[key] ||= Gtk::CheckButton.new.tap do |button|
        button.tooltip_text = Colors.name(key)
        if classed?(key)
          button.add_css_class(key)
        end
        if grouped?(key)
          button.group = check(Colors::SYSTEM)
        end
        button.active = radio? && key == @selected
        button.signal_connect("notify::active") { changed(key, button) }
      end
    end

    private

      def classed?(key) = multi? || key != Colors::SYSTEM
      def grouped?(key) = radio? && key != Colors::SYSTEM

      def changed(key, button)
        if report?(button)
          @selected = key
          @on_change&.call(self)
        end
      end

      # In :radio mode only the button being switched on has anything to say;
      # in :multi mode both edges change the filter.
      def report?(button) = multi? || button.active?
  end
end

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
  # Upstream's notify::active handlers fire on deactivation too, so switching
  # from red to blue runs setcolor("red") before setcolor("blue") and only
  # lands on the right answer because GTK deactivates the outgoing button
  # first. This port ignores the deactivation half instead.
  class ColorSelector < Gtk::Box
    SPACING = 6

    attr_reader :mode, :checks

    def initialize(mode: :radio, selected: nil, &on_change)
      super(:horizontal, SPACING)
      @mode = mode
      @selected = Colors.key(selected)
      @on_change = on_change
      @checks = {}
      add_css_class("colorselector")
      self.valign = :center
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

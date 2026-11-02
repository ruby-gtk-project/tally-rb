# frozen_string_literal: true

require_relative "locale"

module Tally
  # Colors is the port of main.lua's lib.getcolorname and of the colour
  # vocabulary the rest of the app repeats by hand.
  #
  # Upstream spells the list out in four places — the search bar's check
  # buttons, the new-counter dialog's radio group, counter:colorrow, and the
  # stylesheet — and distinguishes "no colour" two ways: a counter's `color`
  # field is nil, while getcolor() and the CSS class name for it are "system".
  # Both spellings live here: ACCENTS is the six real colours, ALL prepends
  # SYSTEM, and `key`/`value` convert between the two.
  module Colors
    SYSTEM = "system"
    ACCENTS = %w[red orange yellow green blue purple].freeze
    ALL = [SYSTEM, *ACCENTS].freeze

    # Translated labels, used as the check buttons' tooltips. Upstream's
    # getcolorname() answers "No color" for both nil and "system".
    NAMES = {
      SYSTEM   => "No color",
      "red"    => "Red",
      "orange" => "Orange",
      "yellow" => "Yellow",
      "green"  => "Green",
      "blue"   => "Blue",
      "purple" => "Purple",
    }.freeze

    class << self
      def name(color) = Locale.gettext(NAMES.fetch(key(color), NAMES.fetch(SYSTEM)))

      # The CSS class / filter key for a stored colour: nil becomes "system".
      def key(color)
        color.to_s.then do |value|
          if value.empty?
            SYSTEM
          else
            value
          end
        end
      end

      # The stored value for a key: "system" becomes nil, which is what
      # counter:setcolor treats as "no colour".
      def value(key)
        if key.nil? || key.to_s == SYSTEM
          nil
        else
          key.to_s
        end
      end

      def accent?(color) = ACCENTS.include?(key(color))
    end
  end
end

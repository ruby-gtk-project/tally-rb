# frozen_string_literal: true

require "adwaita"
require_relative "color_selector"
require_relative "locale"

module Tally
  # SearchBar is the port of main.lua's searchbar section.
  #
  # A Gtk.SearchBar holding a SearchEntry and a multi-select ColorSelector, and
  # the predicate the list's filter function asks. Upstream's rule, kept
  # exactly: a closed search bar filters nothing; an open one with an empty
  # query and no colour ticked filters nothing either; otherwise a row shows
  # when its colour is ticked (or no colour is) and its name contains the
  # query, matched case-insensitively as a plain substring rather than a
  # pattern.
  #
  # Toggling search mode clears the colour ticks, so reopening the bar starts
  # from "everything shows" rather than from whatever was ticked last time.
  class SearchBar < Gtk::SearchBar
    include Gettext

    SPACING = 6

    # The block is called whenever the query or the colour ticks change; the
    # window hands it the list's invalidate_filter.
    def initialize(&on_change)
      super()
      @on_change = on_change
    end

    def build
      tap do |bar|
        bar.child = content_box

        content_box.tap do |box|
          box.append(search_entry)
          box.append(color_selector.build)
        end

        bar.connect_entry(search_entry)
        search_entry.signal_connect("search-changed") { changed }
        bar.signal_connect("notify::search-mode-enabled") { search_mode_changed }
      end
    end

    def content_box
      @content_box ||= Gtk::Box.new(:vertical, SPACING).tap do |box|
        box.margin_top = 6
        box.margin_bottom = 6
      end
    end

    def search_entry
      @search_entry ||= Gtk::SearchEntry.new.tap do |entry|
        entry.placeholder_text = _("Filter by name…")
      end
    end

    def color_selector
      @color_selector ||= ColorSelector.new(mode: :multi) { changed }
    end

    # The list's filter predicate.
    def matches?(counter)
      if filtering?
        color_selector.matches?(counter.color_key) && name_matches?(counter)
      else
        true
      end
    end

    # True only when the bar is open and something has actually been asked for.
    def filtering?
      search_mode_enabled? && !(query.empty? && !color_selector.filtering?)
    end

    def query = search_entry.text.to_s.downcase

    private

      def name_matches?(counter) = counter.name.downcase.include?(query)

      def changed
        @on_change&.call
      end

      def search_mode_changed
        color_selector.reset
        changed
      end
  end
end

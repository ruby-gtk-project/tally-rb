# frozen_string_literal: true

require "adwaita"

module Tally
  # Icons is the port of data/tally.gresource.xml.
  #
  # Upstream bundles sixteen symbolic action icons into a GResource, registers
  # it from main.lua and points the application at the resource base path
  # /ca/vlacroix/Tally, so the icon theme finds them under
  # <base>/icons/scalable/actions. It exists because several of these names
  # (plus-large-symbolic, move-top-symbolic, drag-handle-symbolic…) are too new
  # to rely on the host's icon theme having them.
  #
  # Compiling a GResource would mean a glib-compile-resources build step, so
  # this port ships the same SVGs as plain files under data/icons and adds that
  # directory to the icon theme's search path instead. Same icon names, same
  # precedence over the host theme's copies.
  class Icons
    DIR = File.expand_path("../../data/icons", __dir__)

    # The gresource manifest's file list, by icon name.
    NAMES = %w[
      check-mark-symbolic
      check-round-outline-symbolic
      cross-large-circle-outline-symbolic
      delete-symbolic
      drag-handle-symbolic
      loupe-large-symbolic
      menu-large-symbolic
      minus-symbolic
      move-bottom-symbolic
      move-down-symbolic
      move-top-symbolic
      move-up-symbolic
      plus-large-symbolic
      plus-symbolic
      pop-out-symbolic
      tally-symbolic
    ].freeze

    def self.install = new.install

    def install
      icon_theme.add_search_path(DIR)
      self
    end

    # True when every icon the manifest lists is actually on disk — the check
    # the GResource build step performs for upstream.
    def complete?
      NAMES.all? { |name| File.file?(
        File.join(
          DIR,
          "scalable",
          "actions",
          "#{name}.svg",
        ),
      ) }
    end

    # gtk_icon_theme_get_for_display is bound as `for_display` in recent
    # ruby-gnome and as `get_for_display` in older releases.
    def icon_theme
      @icon_theme ||= theme_for(Gdk::Display.default)
    end

    private

      def theme_for(display)
        if Gtk::IconTheme.respond_to?(:for_display)
          Gtk::IconTheme.for_display(display)
        else
          Gtk::IconTheme.get_for_display(display)
        end
      end
  end
end

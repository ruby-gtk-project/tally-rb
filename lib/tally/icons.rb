# frozen_string_literal: true

require "adwaita"

module Tally
  # Icons is the port of data/tally.gresource.xml and of the Makefile's two
  # icon install rules.
  #
  # Upstream bundles sixteen symbolic action icons into a GResource, registers
  # it from main.lua and points the application at the resource base path
  # /ca/vlacroix/Tally, so the icon theme finds them under
  # <base>/icons/scalable/actions. It exists because several of these names
  # (plus-large-symbolic, move-top-symbolic, drag-handle-symbolic…) are too new
  # to rely on the host's icon theme having them. Separately, the Makefile
  # installs icons/$(APPID).svg into share/icons/hicolor/scalable/apps and
  # icons/$(APPID)-symbolic.svg into share/icons/hicolor/symbolic/apps — the
  # application icon the window, the launcher and the About dialog all use.
  #
  # Compiling a GResource would mean a glib-compile-resources build step, so
  # this port ships both sets as plain files and adds data/icons to the icon
  # theme's search path instead. The layout is deliberately a hicolor theme
  # tree — data/icons/hicolor/{index.theme,scalable/actions,scalable/apps,
  # symbolic/apps} — because a file search path does not search the
  # "scalable/actions" subdirectory a GResource base path implies: FINDINGS.md
  # B7. It also means the same directory can be copied straight into
  # share/icons by a package, which is what flake.nix does.
  class Icons
    DIR = File.expand_path("../../data/icons", __dir__)
    THEME = "hicolor"

    # The gresource manifest's file list, by icon name. These live under
    # scalable/actions, as they do in the manifest.
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

    # The application icons, by icon name and the theme subdirectory they sit
    # in. Both application ids are shipped, because a devel run asks for the
    # .Devel one.
    APP_NAMES = {
      "org.rubygtkproject.Tally"                => "scalable/apps",
      "org.rubygtkproject.Tally.Devel"          => "scalable/apps",
      "org.rubygtkproject.Tally-symbolic"       => "symbolic/apps",
      "org.rubygtkproject.Tally.Devel-symbolic" => "symbolic/apps",
    }.freeze

    def self.install = new.install

    def install
      icon_theme.add_search_path(DIR)
      self
    end

    # True when every icon the manifest and the Makefile list is on disk — the
    # check the GResource build step performs for upstream.
    def complete?
      missing.empty?
    end

    # The icon names whose file is absent, so a caller can say which.
    def missing
      paths.reject { |_name, path| File.file?(path) }.keys
    end

    # Every shipped icon name mapped to the file that provides it.
    def paths
      NAMES.to_h { |name| [name, path_for(name, "scalable/actions")] }
        .merge(APP_NAMES.to_h { |name, subdir| [name, path_for(name, subdir)] })
    end

    # Either name, depending on the ruby-gnome release. FINDINGS.md B6.
    def icon_theme
      @icon_theme ||= theme_for(Gdk::Display.default)
    end

    private

      def path_for(name, subdir) = File.join(
        DIR,
        THEME,
        subdir,
        "#{name}.svg",
      )

      def theme_for(display)
        if Gtk::IconTheme.respond_to?(:for_display)
          Gtk::IconTheme.for_display(display)
        else
          Gtk::IconTheme.get_for_display(display)
        end
      end
  end
end

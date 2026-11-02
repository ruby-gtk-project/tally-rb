# frozen_string_literal: true

require "adwaita"
require_relative "icons"
require_relative "locale"
require_relative "main_window"
require_relative "store"
require_relative "styles"

module Tally
  # Application is the port of main.lua's app object — its accelerators, its
  # app.quit action, and the on_activate / on_startup / on_shutdown callbacks —
  # together with main.c's lua_get_is_devel.
  #
  # Three behaviours from upstream are worth naming:
  #
  # * One window, ever. Upstream's window constructor opens by returning
  #   app.active_window if there is one, and on_activate only presents the
  #   existing window. Here the window is a memoized accessor, which is the
  #   same guarantee without having to ask the application what it already has
  #   — a pop-out window is also an active window, so that question has the
  #   wrong answer as soon as one is open.
  # * Activating a running instance presents the window rather than opening
  #   anything, which is what makes the second launch of the app raise the
  #   first one.
  # * Shutdown writes the config file outright, so a quit inside the one-second
  #   debounce window still saves.
  #
  # The devel build is upstream's -DDEVEL compile flag, which main.c reports to
  # Lua and main.lua turns into the "devel" CSS class on both window kinds —
  # the striped header bar that says "this is not the app you installed". A
  # compile flag is no use in Ruby, so TALLY_DEVEL in the environment stands in
  # for it, and it also moves the application id onto the .Devel suffix, so a
  # devel run has its own window grouping, its own desktop entry
  # (data/org.rubygtkproject.Tally.Devel.desktop), its own AppStream metainfo
  # and its own icon.
  #
  # What the suffix does *not* match is a Flatpak manifest. Upstream ships
  # ca.vlacroix.Tally.json and ca.vlacroix.Tally.Devel.json, which build Lua
  # 5.4 and LuaGObject from source inside org.gnome.Sdk and then `make
  # DEVEL=true`; none of that describes a Ruby application, and a manifest for
  # this port would have to build the ruby-gnome C extensions against the
  # GNOME SDK. Neither manifest is ported, and the port has no Flatpak build at
  # all — it is packaged as a gem and as the Nix flake in this repository. See
  # .reports/component-identification.md for the ledger entry.
  #
  # Upstream also sets resource_base_path and registers a GResource for its
  # icons; this port ships them as files and Icons adds that directory to the
  # icon theme instead.
  class Application
    APP_ID = "org.rubygtkproject.Tally"
    DEVEL_SUFFIX = ".Devel"
    DEVEL_ENV = "TALLY_DEVEL"
    TRUTHY = %w[1 true yes on].freeze

    ACCELS = {
      "win.shortcuts" => ["<Ctrl><Shift>question"],
      "win.about"     => ["F1"],
      "win.close"     => ["<Ctrl>W"],
      "app.quit"      => ["<Ctrl>Q"],
    }.freeze

    def self.devel? = TRUTHY.include?(ENV.fetch(DEVEL_ENV, "").strip.downcase)

    def initialize(store: Store.default, devel: devel_default)
      @store = store
      @devel = devel
    end

    attr_reader :store

    def devel? = @devel

    def application_id
      if devel?
        "#{APP_ID}#{DEVEL_SUFFIX}"
      else
        APP_ID
      end
    end

    def build
      app.tap do |application|
        ACCELS.each { |action, accels| application.set_accels_for_action(action, accels) }
        application.add_action(quit_action)
        application.signal_connect("startup") { startup }
        application.signal_connect("activate") { activate }
        application.signal_connect("shutdown") { shutdown }
      end
    end

    def run(argv = []) = app.run(argv)

    # Adwaita::Application is unusable from the Ruby bindings; the application
    # object comes from Gtk and only the windows are Adwaita.
    def app = @app ||= Gtk::Application.new(application_id, :default_flags)

    # The single window. Built on first use, which is upstream's uniqueness
    # guarantee.
    def window
      @window ||= MainWindow.new(app, store: store, devel: devel?).build
    end

    def quit_action
      @quit_action ||= Gio::SimpleAction.new("quit", nil).tap do |action|
        action.signal_connect("activate") { app.quit }
        action.enabled = true
      end
    end

    private

      def devel_default = self.class.devel?

      # The icon search path and the stylesheet both need a display, so they
      # cannot be set up before startup.
      def startup
        Icons.install
        Styles.install
        window.present
      end

      def activate
        window.present
      end

      def shutdown
        store.write
      end
  end
end

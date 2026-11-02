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
  # The suffix is also what the two Flatpak manifests are built around.
  # Upstream ships ca.vlacroix.Tally.json and ca.vlacroix.Tally.Devel.json,
  # identical but for the devel app id and the `make DEVEL=true` that sets the
  # -DDEVEL compile flag; data/org.rubygtkproject.Tally.json and its .Devel
  # companion are the same pair, building Ruby and the ruby-gnome gems against
  # org.gnome.Sdk where upstream builds Lua 5.4 and LuaGObject, and the devel
  # manifest's `--env=TALLY_DEVEL=1` stands where upstream's make flag does —
  # which is the whole reason this is an environment variable and not a
  # constant decided at install time.
  #
  # Upstream also sets resource_base_path and registers a GResource for its
  # icons; this port ships them as files and Icons adds that directory to the
  # icon theme instead.
  class Application
    include Gettext

    APP_ID = "org.rubygtkproject.Tally"
    DEVEL_SUFFIX = ".Devel"
    DEVEL_ENV = "TALLY_DEVEL"
    TRUTHY = %w[1 true yes on].freeze

    # main.c's load-failure branch. luaL_loadbuffer either returns LUA_OK, in
    # which case main() calls the chunk and returns 0, or it fails and main()
    # prints this one translated line to stderr and returns the Lua error code.
    # The msgid is upstream's, byte for byte including the trailing newline, so
    # the three catalogues in po/ already carry its translation.
    #
    # `N_` only marks it for extraction; the translation happens at the point
    # of use in .boot, because a constant is frozen long before the locale is
    # known.
    LOAD_FAILURE = N_("An unrecoverable error occurred when loading Tally, preventing the program from starting.\n")

    # Upstream returns lua_result itself, which is one of Lua's own codes
    # (LUA_ERRSYNTAX, LUA_ERRMEM — 3 and 4). Those numbers mean nothing outside
    # Lua, so the exit status here is the conventional 1; what carries over is
    # that a load failure exits non-zero without a window ever appearing.
    LOAD_FAILURE_STATUS = 1

    ACCELS = {
      "win.shortcuts" => ["<Ctrl><Shift>question"],
      "win.about"     => ["F1"],
      "win.close"     => ["<Ctrl>W"],
      "app.quit"      => ["<Ctrl>Q"],
    }.freeze

    def self.devel? = TRUTHY.include?(ENV.fetch(DEVEL_ENV, "").strip.downcase)

    # The whole of upstream's main(): build the application, and run it if it
    # built. Returns the process's exit status, which is what makes the one
    # expression in exe/tally — `exit(Tally::Application.boot(ARGV))` — the
    # same shape as `return lua_result`.
    #
    # What counts as a load failure is upstream's boundary, not a wider one.
    # luaL_loadbuffer turns the program's own bytecode into something callable;
    # it says nothing about the shared libraries the executable is linked
    # against, which the dynamic loader has already resolved or died over
    # before main() runs. The matching line here is building the object graph —
    # the Gtk::Application and the window the store's counters are read into.
    # Failures once the main loop is running are upstream's `lua_call`, which
    # is unprotected, so they are not caught here either and keep their
    # backtrace.
    #
    # The second line is this port's only addition to the branch, and it pays
    # off upstream's own FIXME ("Handle each error case individually"): the
    # translated sentence tells a user the app will not start, and nothing
    # else, so the exception that caused it is named underneath where whoever
    # has to fix it can read it.
    def self.boot(argv = [], err: $stderr, **options)
      build_application(err: err, **options).then do |application|
        if application
          application.run(argv).to_i
        else
          LOAD_FAILURE_STATUS
        end
      end
    end

    # Builds the application, or writes the load failure and answers nil. It is
    # a method of its own so that the rescue covers only the build: wrapping
    # the `run` above in it would make every error inside the main loop look
    # like a program that failed to load.
    def self.build_application(err: $stderr, **options)
      new(**options).build
    rescue ScriptError, StandardError => error
      err.print(Locale.gettext(LOAD_FAILURE))
      err.puts("#{error.class}: #{error.message}")
      nil
    end

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

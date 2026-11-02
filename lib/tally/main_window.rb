# frozen_string_literal: true

require "adwaita"
require_relative "about_dialog"
require_relative "counter"
require_relative "counter_list"
require_relative "counter_row"
require_relative "empty_state"
require_relative "locale"
require_relative "main_menu"
require_relative "new_counter_dialog"
require_relative "search_bar"
require_relative "shortcuts_dialog"
require_relative "store"

module Tally
  # MainWindow is the port of main.lua's window class, of its refreshtoolbar
  # method, and of the select-and-delete mode spread across the checkbtn and
  # delbtn handlers.
  #
  # An Adw.ApplicationWindow whose content is an Adw.ToolbarView with two top
  # bars — the header bar and the search bar — over either the counter list or
  # the "No Counters" status page. A breakpoint at 400px hands the list between
  # its clamped and edge-to-edge layouts.
  #
  # The header bar has two faces, which is what select mode is:
  #
  # * normally: a plus button, the select toggle, then the search toggle and
  #   the menu button;
  # * selecting: the plus button is swapped for a destructive delete button,
  #   and every row swaps its spin button and drag handle for a check button
  #   and a plain count label.
  #
  # refresh_toolbar is the other state swap: with no counters there is nothing
  # to select or to filter, so the select button hides and the status page
  # takes the list's place.
  class MainWindow < Adwaita::ApplicationWindow
    include Gettext

    BREAKPOINT_WIDTH = 400
    MIN_WIDTH = 360
    MIN_HEIGHT = 294

    def initialize(application, store: Store.default, devel: false)
      super(application)
      @application = application
      @store = store
      @devel = devel
      @rows = []
      self.title = _("Tally")
      # Upstream's icon comes from the GResource the application's
      # resource_base_path points at; here Icons has put data/icons on the
      # theme search path, so naming the application id is enough. A devel run
      # asks for the .Devel icon, which is shipped too.
      self.icon_name = application.application_id
      set_default_size(store.width, store.height)
      set_size_request(MIN_WIDTH, MIN_HEIGHT)
      if devel
        add_css_class("devel")
      end
    end

    attr_reader :store, :rows

    def build
      tap do |window|
        store.window = window
        window.content = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.add_top_bar(search_bar)
          view.content = counter_list
        end

        header_bar.tap do |bar|
          bar.pack_start(new_button)
          bar.pack_start(delete_button)
          bar.pack_start(select_button)
          bar.pack_end(menu_button)
          bar.pack_end(search_button)
        end

        search_bar.tap do |bar|
          # The window, not the class table upstream assigns. FINDINGS.md U2.
          bar.key_capture_widget = window
          bar.bind_property(
            "search-mode-enabled",
            search_button,
            "active",
            :bidirectional,
          )
        end

        window.add_breakpoint(breakpoint)
        window.add_action(shortcuts_action)
        window.add_action(about_action)
        window.signal_connect("close-request") { closing }

        connect
        restore
        refresh_toolbar
        menu_button.grab_focus
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.title_widget = Adwaita::WindowTitle.new(_("Tally"), "")
      end
    end

    def new_button
      @new_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = "plus-large-symbolic"
        button.tooltip_text = _("Create a new counter")
      end
    end

    # Hidden until select mode replaces the plus button with it.
    def delete_button
      @delete_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = "delete-symbolic"
        button.tooltip_text = _("Delete selected counters")
        button.visible = false
        button.add_css_class("destructive-action")
      end
    end

    def select_button
      @select_button ||= Gtk::ToggleButton.new.tap do |button|
        button.icon_name = "check-round-outline-symbolic"
        button.tooltip_text = _("Select counters to delete")
      end
    end

    def search_button
      @search_button ||= Gtk::ToggleButton.new.tap do |button|
        button.icon_name = "loupe-large-symbolic"
        button.tooltip_text = _("Filter counters by name and/or color")
      end
    end

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = "menu-large-symbolic"
        button.menu_model = MainMenu.build
        button.tooltip_text = _("Menu")
      end
    end

    def search_bar
      @search_bar ||= SearchBar.new { counter_list.invalidate_filter }.build
    end

    def counter_list
      @counter_list ||= CounterList.new(filter: filter) { |layout| layout_changed(layout) }.build
    end

    def empty_state
      @empty_state ||= EmptyState.new { new_counter }.build
    end

    def new_counter_dialog
      @new_counter_dialog ||= NewCounterDialog.new { |name, color| create(name, color) }.build
    end

    def about_dialog
      @about_dialog ||= AboutDialog.build(application_id: @application.application_id)
    end

    def shortcuts_dialog = @shortcuts_dialog ||= ShortcutsDialog.build

    # 400px, measured on the window: below it the list goes edge to edge.
    def breakpoint
      @breakpoint ||= Adwaita::Breakpoint.new(breakpoint_condition).tap do |point|
        point.signal_connect("apply") { counter_list.shrink }
        point.signal_connect("unapply") { counter_list.enlarge }
      end
    end

    # Upstream calls Adw.BreakpointCondition.new_length("MAX_WIDTH", 400,
    # "PX"), which Ruby does not bind. FINDINGS.md B2.
    def breakpoint_condition
      Adwaita::BreakpointCondition.parse("max-width: #{BREAKPOINT_WIDTH}px")
    end

    def shortcuts_action
      @shortcuts_action ||= Gio::SimpleAction.new("shortcuts", nil).tap do |action|
        action.signal_connect("activate") { shortcuts_dialog.present(self) }
        action.enabled = true
      end
    end

    def about_action
      @about_action ||= Gio::SimpleAction.new("about", nil).tap do |action|
        action.signal_connect("activate") { about_dialog.present(self) }
        action.enabled = true
      end
    end

    # The list's filter predicate, handed straight to the search bar.
    def filter = @filter ||= ->(counter) { search_bar.matches?(counter) }

    def new_counter
      tap do
        new_counter_dialog.open(self)
      end
    end

    # Upstream's refreshtoolbar: swaps the ToolbarView's content between the
    # list and the status page, and hides the select button when there is
    # nothing to select.
    def refresh_toolbar
      tap do
        if Counter.counters.empty?
          select_button.visible = false
          toolbar_view.top_bar_style = :flat
          toolbar_view.content = empty_state
        else
          select_button.visible = true
          toolbar_view.top_bar_style = :raised_border
          toolbar_view.content = counter_list
        end
      end
    end

    # Closes every pop-out window, so none of them keeps the application alive
    # once the main window is gone.
    def close_popouts
      tap do
        rows.each(&:close_popout)
      end
    end

    private

      def connect
        new_button.signal_connect("clicked") { new_counter }
        delete_button.signal_connect("clicked") { delete_selected }
        select_button.signal_connect("notify::active") { select_mode_changed }
      end

      # Upstream reads the geometry back in the window constructor and the
      # maximized flag separately, so a maximized window still remembers the
      # size it had before.
      def restore
        store.saved_counters.each do |counter|
          Counter.register(counter)
          add_row(counter)
        end
        if store.maximized?
          maximize
        end
      end

      def create(name, color)
        Counter.new(name: name, color: color).tap do |counter|
          Counter.register(counter)
          add_row(counter).grab_focus
          store.write
          counter_list.scroll_to_bottom
          refresh_toolbar
        end
      end

      def add_row(counter)
        build_row(counter).tap do |row|
          rows.push(row)
          counter_list.append(row)
          if select_button.active?
            row.check_mode = true
          end
        end
      end

      def build_row(counter)
        CounterRow.new(
          counter,
          store:       store,
          list:        counter_list,
          application: @application,
          devel:       @devel,
        ).build
      end

      # Upstream's checkbtn notify handler: the header bar swaps buttons and
      # every row swaps its own controls.
      def select_mode_changed
        if select_button.active?
          select_button.tooltip_text = _("Stop selecting without deleting anything")
          new_button.visible = false
          delete_button.visible = true
        else
          select_button.tooltip_text = _("Select counters to delete")
          new_button.visible = true
          delete_button.visible = false
        end
        rows.each { |row| row.check_mode = select_button.active? }
      end

      # Upstream's delbtn handler. The write is immediate rather than queued:
      # a deletion is not something to lose to a crash in the next second.
      def delete_selected
        if select_button.active?
          checked_rows.reverse_each { |row| discard(row) }
          store.write
          select_button.active = false
          refresh_toolbar
        end
      end

      def checked_rows = rows.select { |row| row.counter.checked }

      def discard(row)
        row.counter.delete
        rows.delete(row)
      end

      # Upstream's enlarge and shrink set the top-bar style along with the
      # layout; refresh_toolbar then has the last word whenever the list's
      # emptiness changes.
      def layout_changed(layout)
        if layout == :wide
          toolbar_view.top_bar_style = :flat
        else
          toolbar_view.top_bar_style = :raised_border
        end
      end

      def closing
        close_popouts
        false
      end
  end
end

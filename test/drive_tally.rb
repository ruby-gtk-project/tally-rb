# frozen_string_literal: true

# Drives the whole app headlessly: builds the window, creates counters, opens
# every dialog, exercises select mode, search filtering, reordering and the
# pop-out window, and screenshots each state.
#
# Why this file exists: a GTK app that loads is not a GTK app that works.
# `ruby -c` passes on code that builds an empty window, and the Ruby bindings
# differ from the C API in ways that only a run reveals — the first run of this
# script found that Adwaita::BreakpointCondition has no `new_length` in Ruby
# (only `parse`), which meant the port's main window had never been built
# successfully by anyone.
#
# Run it from the repository root:
#
#   nix develop --command xvfb-run ruby test/drive_tally.rb
#
# Despite what the companion skill says, GTK4 here has no offscreen backend —
# gtk_init fails outright with no display — so xvfb-run is not optional on this
# machine.
#
# The specs under spec/ cover the display-free half. What is driven here is
# what needs a widget: the wiring, the state swaps and anything a screenshot
# can show.

require "fileutils"
require "tmpdir"

# A scratch config directory, so a run never reads or writes the real one.
ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir("tally-drive")

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "tally"
require_relative "gtk_driver"

SHOTS = File.expand_path("../tmp/shots", __dir__)
FileUtils.rm_rf(SHOTS)

Tally::Counter.clear

GtkDriver.drive(Tally::Application.new, shots: SHOTS) do |d, app|
  d.window { app.window }

  d.step("the window builds and shows the empty state") do
    d.check("the window is an Adwaita::ApplicationWindow") do
      app.window.is_a?(Adwaita::ApplicationWindow)
    end
    d.check("it is the only toplevel") { Gtk::Window.list_toplevels.length == 1 }
    d.check("its title is Tally") { app.window.title == "Tally" }
    d.check("its icon is the application id") do
      app.window.icon_name == app.application_id
    end
    d.check("the status page is the content") do
      app.window.toolbar_view.content.equal?(app.window.empty_state)
    end
    d.check("the select button is hidden with no counters") do
      !app.window.select_button.visible?
    end
    d.shot("01-empty")
  end

  d.step("every icon the app names is in the theme") do
    Tally::Icons.new.then do |icons|
      d.check("every shipped icon file is on disk") { icons.complete? }
      d.check("nothing is missing") { icons.missing.empty? }
      [
        "plus-large-symbolic", "delete-symbolic", "check-round-outline-symbolic",
        "loupe-large-symbolic", "menu-large-symbolic", "tally-symbolic",
        "drag-handle-symbolic", "pop-out-symbolic", "move-top-symbolic",
        "move-bottom-symbolic", "move-up-symbolic", "move-down-symbolic",
        "minus-symbolic", "plus-symbolic", "check-mark-symbolic",
        "cross-large-circle-outline-symbolic",
      ].each do |name|
        d.check("the icon theme resolves #{name}") { icons.icon_theme.has_icon?(name) }
      end
      d.check("the icon theme resolves the application icon") do
        icons.icon_theme.has_icon?(Tally::Metainfo::APP_ID)
      end
      d.check("the icon theme resolves the symbolic application icon") do
        icons.icon_theme.has_icon?("#{Tally::Metainfo::APP_ID}-symbolic")
      end
    end
  end

  d.step("the new-counter dialog opens from the status page's button") do
    app.window.empty_state.create_button.activate
  end

  d.step("it refuses an empty name and accepts a filled one") do
    app.window.new_counter_dialog.then do |dialog|
      d.check("the dialog is showing") { app.window.visible_dialog.equal?(dialog) }
      d.check("create is insensitive with an empty name") { !dialog.create_button.sensitive? }
      d.shot("02-new-counter-dialog")

      dialog.name_entry.text = "Coffee"
      d.check("create is sensitive once named") { dialog.create_button.sensitive? }
      dialog.create_button.activate
    end
  end

  d.step("the counter is in the list and on disk") do
    d.check("one counter is registered") { Tally::Counter.counters.length == 1 }
    d.check("its name came from the entry") { Tally::Counter.counters.first.name == "Coffee" }
    d.check("the list is the content now") do
      app.window.toolbar_view.content.equal?(app.window.counter_list)
    end
    d.check("the list box is visible") { app.window.counter_list.list_box.visible? }
    d.check("the select button is visible now") { app.window.select_button.visible? }
    d.check("the dialog closed") { app.window.visible_dialog.nil? }
    d.check("the store wrote the counter") do
      Tally::Store.default.then do |store|
        File.read(store.path).include?("Coffee")
      end
    end
    d.shot("03-one-counter")
  end

  # One counter per pair of steps, not a loop: Adw.Dialog needs the main loop
  # back between being presented and being filled in, and driving both halves
  # inside one tick silently creates nothing.
  ["Tea", "Water"].each do |name|
    d.step("the plus button opens the dialog for #{name}") do
      app.window.new_button.activate
    end

    d.step("#{name} is named and created") do
      app.window.new_counter_dialog.tap do |dialog|
        d.check("the dialog is showing again") { app.window.visible_dialog.equal?(dialog) }
        dialog.name_entry.text = name
        d.check("create is sensitive") { dialog.create_button.sensitive? }
        dialog.create_button.activate
      end
    end
  end

  d.step("all three are listed in creation order") do
    d.check("three counters") { Tally::Counter.counters.length == 3 }
    d.check("in order") do
      Tally::Counter.counters.map(&:name) == ["Coffee", "Tea", "Water"]
    end
    d.check("three rows") { app.window.rows.length == 3 }
    d.shot("04-three-counters")
  end

  d.step("the spin button moves the counter and the count label") do
    app.window.rows.first.then do |row|
      row.spin_button.value = 7
      d.check("the counter took the value") { row.counter.value == 7 }
      d.check("the count label followed") { row.count_label.label == "7" }
    end
  end

  d.step("Counter#value= pushes back into the row, which is counter:read") do
    app.window.rows.first.then do |row|
      row.counter.value = 12
      row.read
      d.check("the spin button followed the model") { row.spin_button.value.to_i == 12 }
      d.check("so did the count label") { row.count_label.label == "12" }
    end
  end

  d.step("the pop-out window opens with its own big buttons") do
    app.window.rows.first.then do |row|
      row.show_popout
      d.check("the pop-out is a second toplevel") { Gtk::Window.list_toplevels.length == 2 }
      d.check("its title names the counter") { row.popout.title.start_with?("Coffee") }
      d.check("its icon is the application id") { row.popout.icon_name == app.application_id }
    end
  end

  d.step("the pop-out's buttons move the shared counter") do
    app.window.rows.first.then do |row|
      row.popout.then do |window|
        d.shot("05-popout", window)
        # signal_emit, not activate: gtk_widget_activate declines on a widget
        # that is not mapped, and these buttons are in a window that has only
        # just been presented. Emitting "clicked" runs the same handler the
        # pointer would.
        window.increment_button.signal_emit("clicked")
        d.check("increment moved the counter") { row.counter.value == 13 }
        d.check("the row's spin button followed") { row.spin_button.value.to_i == 13 }
        d.check("the pop-out's label followed") { window.count_label.label == "13" }
        window.decrement_button.signal_emit("clicked")
        window.decrement_button.signal_emit("clicked")
        d.check("decrement moved it back") { row.counter.value == 11 }
      end
      row.close_popout
    end
  end

  d.step("select mode swaps the header bar and every row's controls") do
    app.window.select_button.active = true
  end

  d.step("the swap happened on both") do
    d.check("the plus button is hidden") { !app.window.new_button.visible? }
    d.check("the delete button is showing") { app.window.delete_button.visible? }
    app.window.rows.first.then do |row|
      d.check("the check button is showing") { row.check_button.visible? }
      d.check("the count label is showing") { row.count_label.visible? }
      d.check("the spin button is hidden") { !row.spin_button.visible? }
      d.check("the drag handle is hidden") { !row.drag_handle.visible? }
      d.check("expansion is disabled") { !row.enable_expansion? }
      d.check("the row knows it is in check mode") { row.check_mode? }
    end
    d.shot("06-select-mode")
  end

  d.step("activating a row in select mode ticks it") do
    app.window.rows[1].then do |row|
      app.window.counter_list.list_box.signal_emit("row-activated", row)
      d.check("the row is ticked") { row.counter.checked }
      d.check("and carries the checked class") { row.has_css_class?("checked") }
    end
  end

  d.step("the delete button removes only the ticked counters") do
    app.window.delete_button.activate
  end

  d.step("Tea is gone and the rest survive") do
    d.check("two counters left") { Tally::Counter.counters.length == 2 }
    d.check("Tea went") { Tally::Counter.counters.map(&:name) == ["Coffee", "Water"] }
    d.check("select mode turned itself off") { !app.window.select_button.active? }
    d.check("the plus button is back") { app.window.new_button.visible? }
    app.window.rows.first.then do |row|
      d.check("the row's spin button is back") { row.spin_button.visible? }
      d.check("and it is expandable again") { row.enable_expansion? }
    end
    d.check("the delete reached the disk") { !File.read(Tally::Store.default.path).include?("Tea") }
    d.shot("07-after-delete")
  end

  d.step("the search bar filters by name") do
    app.window.search_button.active = true
    app.window.search_bar.search_entry.text = "wat"
  end

  d.step("only the matching row shows") do
    app.window.search_bar.then do |bar|
      d.check("the bar is in search mode") { bar.search_mode_enabled? }
      d.check("it reports itself as filtering") { bar.filtering? }
      d.check("Water matches") do
        bar.matches?(Tally::Counter.counters.find { |c| c.name == "Water" })
      end
      d.check("Coffee does not") do
        !bar.matches?(Tally::Counter.counters.find { |c| c.name == "Coffee" })
      end
      d.shot("08-search")
    end
  end

  d.step("an open bar with nothing asked for filters nothing") do
    app.window.search_bar.then do |bar|
      bar.search_entry.text = ""
      d.check("it stops reporting itself as filtering") { !bar.filtering? }
      d.check("so everything matches") do
        Tally::Counter.counters.all? { |counter| bar.matches?(counter) }
      end
    end
  end

  d.step("a ticked colour filters on colour alone") do
    app.window.search_bar.then do |bar|
      Tally::Counter.counters.find { |c| c.name == "Water" }.color = "blue"
      bar.color_selector.checks["blue"].active = true
      d.check("it is filtering again") { bar.filtering? }
      d.check("the blue counter matches") do
        bar.matches?(Tally::Counter.counters.find { |c| c.name == "Water" })
      end
      d.check("the colourless one does not") do
        !bar.matches?(Tally::Counter.counters.find { |c| c.name == "Coffee" })
      end
    end
  end

  # The shot waits a tick. A window whose content changed in this tick has not
  # been laid out again yet, and Gtk::WidgetPaintable then produces no render
  # node at all rather than a stale picture.
  d.step("the colour filter renders") { d.shot("09-colour-filter") }

  d.step("closing the bar clears the colour ticks") do
    app.window.search_button.active = false
  end

  d.step("the ticks are cleared and nothing is filtered") do
    app.window.search_bar.then do |bar|
      d.check("the bar is closed") { !bar.search_mode_enabled? }
      d.check("no colour is ticked") { !bar.color_selector.filtering? }
      d.check("nothing is filtered") { !bar.filtering? }
    end
  end

  d.step("the row's disclosure opens onto the menu") do
    app.window.rows.last.expanded = true
  end

  d.step("reordering moves the counter in the list that gets written") do
    app.window.rows.last.then do |row|
      # The order buttons live inside the expander's disclosure, which is not
      # mapped until the row is expanded, and gtk_widget_activate declines on
      # an unmapped widget; "clicked" is the signal the pointer would send.
      row.menu.top_button.signal_emit("clicked")
      d.check("Water is first now") do
        Tally::Counter.counters.map(&:name) == ["Water", "Coffee"]
      end
      row.menu.bottom_button.signal_emit("clicked")
      d.check("and last again") do
        Tally::Counter.counters.map(&:name) == ["Coffee", "Water"]
      end
      row.menu.up_button.signal_emit("clicked")
      d.check("up moves it one place") do
        Tally::Counter.counters.map(&:name) == ["Water", "Coffee"]
      end
      row.menu.down_button.signal_emit("clicked")
      d.check("down moves it back") do
        Tally::Counter.counters.map(&:name) == ["Coffee", "Water"]
      end
    end
  end

  d.step("renaming through the menu's entry row renames everything") do
    app.window.rows.first.then do |row|
      row.menu.name_row.text = "Espresso"
      d.check("the counter took it") { row.counter.name == "Espresso" }
      d.check("so did the row's title") { row.title == "Espresso" }
    end
  end

  d.step("recolouring through the menu swaps the row's CSS class") do
    app.window.rows.first.then do |row|
      row.menu.color_selector.checks["red"].active = true
      d.check("the counter is red") { row.counter.color == "red" }
      d.check("the row carries the red class") { row.has_css_class?("red") }
      d.shot("10-coloured")
    end
  end

  d.step("the shortcuts dialog opens with upstream's five live items") do
    app.window.shortcuts_action.activate(nil)
    app.window.shortcuts_dialog.then do |dialog|
      d.check("it is showing") { app.window.visible_dialog.equal?(dialog) }
      d.check("Ctrl+Q comes from Application::ACCELS") do
        dialog.accelerator_for("app.quit") == Tally::Application::ACCELS["app.quit"].first
      end
      d.check("so does the shortcuts accelerator") do
        dialog.accelerator_for("win.shortcuts") == "<Ctrl><Shift>question"
      end
      d.check("upstream's app.about resolves to the action that exists") do
        dialog.resolve("app.about") == "win.about" && dialog.accelerator_for("app.about") == "F1"
      end
      d.check("win.close is Ctrl+W") { dialog.accelerator_for("win.close") == "<Ctrl>W" }
    end
  end

  d.step("the shortcuts dialog renders") { d.shot("11-shortcuts") }

  d.step("the about dialog reads its release notes from the metainfo file") do
    app.window.visible_dialog&.close
    app.window.about_action.activate(nil)
    app.window.about_dialog.then do |dialog|
      d.check("it is showing") { app.window.visible_dialog.equal?(dialog) }
      d.check("its icon is the application id") { dialog.application_icon == app.application_id }
      d.check("its release notes version is upstream's newest") do
        dialog.release_notes_version == "0.7.3"
      end
      d.check("its notes are the metainfo file's, not a heredoc") do
        dialog.release_notes == Tally::Metainfo.default.release_notes("0.7.3")
      end
      d.check("its version names both numbers") do
        dialog.version == "#{Tally::Rb::Version::VERSION} (tally 0.7.3)"
      end
    end
  end

  d.step("the about dialog renders") { d.shot("12-about") }

  d.step("what was built survives a reload from disk") do
    app.window.visible_dialog&.close
    Tally::Store.default.write
    Tally::Store.new(dir: Tally::Store.default.dir).then do |fresh|
      d.check("the counters come back") do
        fresh.saved_counters.map(&:name) == ["Espresso", "Water"]
      end
      d.check("so do their values") { fresh.saved_counters.first.value == 11 }
      d.check("so do their colours") do
        fresh.saved_counters.map(&:color) == ["red", "blue"]
      end
      d.check("nothing is unreadable") { !fresh.unreadable? }
    end
  end
end

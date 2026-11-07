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
require "stringio"
require "tmpdir"

# A scratch config directory, so a run never reads or writes the real one.
ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir("tally-drive")

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "tally"
require_relative "gtk_driver"

SHOTS = File.expand_path("../tmp/shots", __dir__)
FileUtils.rm_rf(SHOTS)

Tally::Counter.clear

# Turns the main loop over for `ms` milliseconds and comes back.
#
# A step cannot sleep: every step runs inside a GLib timeout, so the clock the
# step is waiting on is dispatched by the very loop a sleep would block. This
# iterates the default context without blocking until the deadline passes,
# which dispatches the timeouts Store#queue_write and
# CounterList#scroll_to_bottom arm.
def pump(ms)
  (Process.clock_gettime(Process::CLOCK_MONOTONIC) + (ms / 1000.0)).then do |deadline|
    while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      GLib::MainContext.default.iteration(false)
    end
  end
end

# Like #pump, but for waiting on something that happens once rather than on
# a fixed-length timer: it stops the moment `condition` is true instead of
# always spending its whole budget, and `timeout_ms` is a ceiling, not an
# estimate.
#
# This exists because #pump's fixed duration was still a race for
# Adw.Dialog's close: that close runs on the frame clock, not a GLib timer,
# so how long it takes to actually finish depends on how fast the renderer
# gets a frame out — which varies with how loaded the machine happens to be.
# A fixed 200ms margin was long enough on an idle box and too short under
# contention (3 consecutive drives, or another process competing for the
# CPU); re-running the drive 8 times clean in two quiet sessions proved
# nothing about a loaded one. Polling the actual condition removes the
# guess: it is as fast as the quick case and as patient as the slow one.
def pump_until(timeout_ms, &condition)
  (Process.clock_gettime(Process::CLOCK_MONOTONIC) + (timeout_ms / 1000.0)).then do |deadline|
    until condition.call
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        break
      end

      GLib::MainContext.default.iteration(false)
    end
  end
end

# Every Gtk::Label text in a widget tree.
#
# The two rows an Adw.AboutDialog's add_link puts on its page are not readable
# as properties — there is no get_links — so the only way to assert the labels
# upstream names are really there is to look at what the dialog built.
def labels(widget, found = [])
  found.tap do
    if widget.is_a?(Gtk::Label)
      found << widget.label
    end
    widget.first_child.then do |first|
      child = first
      while child
        labels(child, found)
        child = child.next_sibling
      end
    end
  end
end

# Runs xdotool against the display the driver is already on, quietly.
def xdotool(*args)
  system("xdotool", *args, out: File::NULL, err: File::NULL)
end

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
      # Adw.Dialog's close is not guaranteed synchronous with the handler that
      # calls it, and it runs on the frame clock rather than a GLib timer —
      # the next step reads the dialog's closed state and the store's write
      # straight off of this, so it has to wait for the close to actually
      # finish, not for a fixed margin that guesses how long that takes.
      # A fixed `pump(200)` here was still a race: PORTING.md and
      # .reports/test-parity.md both record it failing 4 of 5 independent
      # runs with no code change, and it reappeared again after 8 clean runs
      # once three drives ran back to back on a loaded machine — the margin
      # was long enough when idle and too short under contention. Polling
      # the actual condition (see #pump_until, above #pump) removes the
      # guess.
      pump_until(2000) { app.window.visible_dialog.nil? }
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

  # C2. The dialog is still showing from the step above, which is what makes
  # the link labels findable: an Adw.AboutDialog builds its page when it is
  # presented, not when it is constructed. Upstream's aboutwin sets all six of
  # these literals; the driver asserted four properties and neither link, so a
  # dropped copyright or a missing tip jar would have gone green.
  d.step("the about dialog carries upstream's remaining literals") do
    app.window.about_dialog.then do |dialog|
      d.check("its copyright is upstream's") do
        dialog.copyright == Tally::AboutDialog::COPYRIGHT
      end
      d.check("so is its developer name") do
        dialog.developer_name == Tally::AboutDialog::DEVELOPER
      end
      d.check("its licence is GPL-3.0, as COPYING says") do
        dialog.license_type == :gpl_3_0
      end
      d.check("its website is upstream's") do
        dialog.website == Tally::AboutDialog::WEBSITE
      end
      d.check("its translator credits are the translatable msgid") do
        dialog.translator_credits == "translator-credits"
      end
      d.check("the issue tracker is the port's own, not upstream's") do
        dialog.issue_url == Tally::AboutDialog::ISSUE_URL
      end
      labels(dialog).then do |texts|
        d.check("the translation link is on the page") do
          texts.include?("Translate this app!")
        end
        d.check("and so is the tip jar") { texts.include?("Support this app!") }
      end
    end
  end

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

  # main.c's load-failure branch, which is the one path a run of the app never
  # reaches: the window has to fail to build for it to happen at all. The
  # catalogue is the English one here, so the msgid is what comes back; what is
  # being checked is that the sentence printed is upstream's own and that the
  # status is non-zero.
  d.step("a build that fails prints upstream's line and exits non-zero") do
    Class.new(Tally::Application) do
      def build = raise(LoadError, "cannot load such file -- tally/main_window")
    end.then do |broken|
      StringIO.new.then do |err|
        d.check("the status is the load-failure one") do
          broken.boot([], err: err) == Tally::Application::LOAD_FAILURE_STATUS
        end
        d.check("the first line is upstream's message") do
          err.string.start_with?(Tally::Locale.gettext(Tally::Application::LOAD_FAILURE))
        end
        d.check("the exception is named underneath it") do
          err.string.include?("LoadError: cannot load such file -- tally/main_window")
        end
      end
    end
  end

  # --- Components the run above never reached -----------------------------
  #
  # Everything below was added after the first pass to close the gap between
  # "the port has a file for this" and "this was run once". Two of the checks
  # found real bugs: the drag source's content provider was built with a
  # constructor the Ruby bindings do not have (`new_for_value`), so picking a
  # row up aborted the process, and the drop handler type-tested the GLib::Value
  # the bindings hand it rather than the row inside it, so every
  # drag-to-reorder was refused in silence.

  d.step("the header bar's menu button carries upstream's two-item menu") do
    app.window.menu_button.then do |button|
      d.check("it is a Gtk::MenuButton") { button.is_a?(Gtk::MenuButton) }
      d.check("its icon is the hamburger") { button.icon_name == "menu-large-symbolic" }
      d.check("it has a tooltip") { !button.tooltip_text.to_s.empty? }
      button.menu_model.then do |model|
        d.check("the model is a Gio::Menu") { model.is_a?(Gio::Menu) }
        d.check("it carries two items, as upstream's tallymenu does") { model.n_items == 2 }
        d.check("their labels and actions are upstream's, in order") do
          (0...model.n_items).map do |index|
            [
              model.get_item_attribute_value(index, "label", nil),
              model.get_item_attribute_value(index, "action", nil),
            ]
          end == Tally::MainMenu::ITEMS.to_a
        end
        d.check("there is no quit item, as upstream has none") do
          (0...model.n_items).none? do |index|
            model.get_item_attribute_value(index, "action", nil) == "app.quit"
          end
        end
      end
    end
  end

  d.step("the menu's first item's action opens the shortcuts dialog") do
    app.window.visible_dialog&.close
    app.window.activate_action("shortcuts", nil)
    d.check("win.shortcuts presented the shortcuts dialog") do
      app.window.visible_dialog.equal?(app.window.shortcuts_dialog)
    end
  end

  d.step("the menu's second item's action opens the about dialog") do
    app.window.visible_dialog&.close
    app.window.activate_action("about", nil)
    d.check("win.about presented the about dialog") do
      app.window.visible_dialog.equal?(app.window.about_dialog)
    end
    app.window.visible_dialog&.close
  end

  # Compared as parsed key combinations, not as strings: upstream's spelling is
  # "<Ctrl>Q" (main.lua:95-98, copied byte for byte into ACCELS) and GTK hands
  # it back in its own canonical form, "<Control>q". The two parse to the same
  # keyval and modifier mask, which is the thing being asserted — that the
  # combination registered is upstream's.
  d.step("the application registered upstream's four accelerators") do
    Tally::Application::ACCELS.each do |action, accels|
      d.check("#{action} is #{accels.first}") do
        app.app.get_accels_for_action(action).map { |accel| Gtk.accelerator_parse(accel) } ==
          accels.map { |accel| Gtk.accelerator_parse(accel) }
      end
    end
    d.check("app.quit is an action on the application") do
      app.quit_action.is_a?(Gio::SimpleAction) && app.quit_action.name == "quit"
    end
    d.check("and it is enabled") { app.quit_action.enabled? }
  end

  d.step("upstream's stylesheets parse, with no errors swallowed") do
    [
      ["base + light", Tally::Styles::BASE + Tally::Styles::LIGHT],
      ["base + dark", Tally::Styles::BASE + Tally::Styles::DARK],
    ].each do |label, css|
      [].then do |errors|
        Gtk::CssProvider.new.tap do |provider|
          provider.signal_connect("parsing-error") { |_p, _section, error| errors << error.message }
          provider.load_from_string(css)
        end
        d.check("#{label} parses with no complaints") { errors.empty? }
      end
    end
    Tally::Styles.new.then do |styles|
      d.check("the light and dark providers are two different providers") do
        !styles.light_provider.equal?(styles.dark_provider) &&
          styles.light_provider.is_a?(Gtk::CssProvider)
      end
      d.check("the light sheet tints the rows towards black") do
        Tally::Styles::LIGHT.include?("color-mix(in srgb, var(--red-5) 90%, black)")
      end
      d.check("the dark sheet tints them towards white") do
        Tally::Styles::DARK.include?("color: white")
      end
    end
  end

  d.step("the dark scheme swaps the provider the app installed") do
    Adwaita::StyleManager.default.tap do |manager|
      manager.color_scheme = :force_dark
      d.check("the style manager reports dark") { manager.dark? }
    end
  end

  d.step("and the window renders dark") { d.shot("13-dark") }

  d.step("the light scheme swaps it back") do
    Adwaita::StyleManager.default.tap do |manager|
      manager.color_scheme = :force_light
      d.check("the style manager reports light again") { !manager.dark? }
    end
  end

  d.step("the breakpoint narrows the list, as upstream's shrink does") do
    app.window.breakpoint.signal_emit("apply")
    app.window.counter_list.then do |list|
      d.check("the narrow layout is showing") do
        list.multi_layout_view.layout.equal?(list.narrow_layout)
      end
      d.check("the list is separators, not a boxed list") do
        list.list_box.has_css_class?("separators") && !list.list_box.has_css_class?("boxed-list")
      end
      d.check("the header bar took the raised border") do
        app.window.toolbar_view.top_bar_style == :raised_border
      end
    end
  end

  d.step("the narrow layout renders") { d.shot("14-narrow") }

  d.step("unapplying it widens the list again") do
    app.window.breakpoint.signal_emit("unapply")
    app.window.counter_list.then do |list|
      d.check("the wide layout is showing") do
        list.multi_layout_view.layout.equal?(list.wide_layout)
      end
      d.check("the clamp is the wide layout's child") do
        list.wide_layout.content.equal?(list.clamp)
      end
      d.check("the list is a boxed list again") do
        list.list_box.has_css_class?("boxed-list") && !list.list_box.has_css_class?("separators")
      end
      d.check("the header bar went flat") do
        app.window.toolbar_view.top_bar_style == :flat
      end
      d.check("scrolling a row into view answers the list") do
        list.scroll_into_view(app.window.rows.first).equal?(list)
      end
      d.check("so does scrolling to the bottom") { list.scroll_to_bottom.equal?(list) }
    end
  end

  d.step("the drag preview row mirrors the row it stands in for") do
    app.window.rows.first.then do |row|
      Tally::CounterDragRow.new(row.counter, expanded: true).build.then do |preview|
        d.check("it takes the counter's name") { preview.title == row.counter.name }
        d.check("a row picked up open is previewed open") { preview.expanded? }
        d.check("it carries the counter's colour class") do
          preview.has_css_class?(row.counter.color_key)
        end
        d.check("its spin button shows the same number") do
          preview.spin_button.value.to_i == row.counter.value
        end
        d.check("its name row cannot be typed in") { !preview.menu.name_row.sensitive? }
        d.check("its order buttons cannot be pressed") { !preview.menu.top_button.sensitive? }
        d.check("nor its pop-out button") { !preview.menu.popout_button.sensitive? }
        d.check("the preview is in duplicate mode") { preview.menu.duplicate? }
      end
    end
  end

  d.step("the drag handle offers the row in the format the drop target takes") do
    app.window.rows.first.then do |row|
      row.drag_source.signal_emit("prepare", 4.0, 5.0).then do |provider|
        d.check("prepare answers a content provider") { provider.is_a?(Gdk::ContentProvider) }
        d.check("it offers the row as an AdwExpanderRow") do
          provider.formats.to_s.include?("AdwExpanderRow")
        end
      end
      d.check("which is what the drop target accepts") do
        row.drop_target.formats.to_s.include?("AdwExpanderRow")
      end
      d.check("and the source moves rather than copies") { row.drag_source.actions == :move }
    end
  end

  d.step("dropping one row on another reorders the list and the model") do
    app.window.rows.first.then do |espresso|
      app.window.rows.last.then do |water|
        d.check("the drop is accepted") do
          water.drop_target.signal_emit(
            "drop",
            GLib::Value.new(Adwaita::ExpanderRow.gtype, espresso),
            0.0,
            0.0,
          )
        end
        d.check("the model moved") do
          Tally::Counter.counters.map(&:name) == ["Water", "Espresso"]
        end
        d.check("so did the list box's children") do
          app.window.counter_list.list_box.get_row_at_index(0).equal?(water)
        end
      end
    end
  end

  d.step("and dropping it back restores the order") do
    app.window.rows.first.then do |espresso|
      app.window.rows.last.then do |water|
        d.check("the drop is accepted") do
          espresso.drop_target.signal_emit(
            "drop",
            GLib::Value.new(Adwaita::ExpanderRow.gtype, water),
            0.0,
            0.0,
          )
        end
        d.check("the model is back") do
          Tally::Counter.counters.map(&:name) == ["Espresso", "Water"]
        end
        d.check("so is the list box") do
          app.window.counter_list.list_box.get_row_at_index(0).equal?(espresso)
        end
        d.check("a drop on itself is refused") do
          espresso.drop_target.signal_emit(
            "drop",
            GLib::Value.new(Adwaita::ExpanderRow.gtype, espresso),
            0.0,
            0.0,
          ) == false
        end
        d.check("and so is a drop of something that is not a row") do
          espresso.drop_target.signal_emit(
            "drop",
            GLib::Value.new(GLib::Type::INT, 3),
            0.0,
            0.0,
          ) == false
        end
      end
    end
  end

  d.step("the pop-out opens again for the limit checks") do
    app.window.rows.first.show_popout
  end

  d.step("the pop-out's buttons go insensitive at the counter's limits") do
    app.window.rows.first.then do |row|
      row.popout.then do |window|
        row.counter.value = Tally::Counter::MIN_VALUE
        d.check("decrement is insensitive at zero") { !window.decrement_button.sensitive? }
        d.check("increment still works there") { window.increment_button.sensitive? }
        d.check("the label shows the floor") { window.count_label.label == "0" }
        row.counter.value = Tally::Counter::MAX_VALUE
        d.check("increment is insensitive at the ceiling") { !window.increment_button.sensitive? }
        d.check("decrement works there") { window.decrement_button.sensitive? }
        d.check("the counter clamps rather than overflowing") do
          row.counter.value = Tally::Counter::MAX_VALUE + 500
          row.counter.value == Tally::Counter::MAX_VALUE
        end
        row.counter.value = 11
      end
    end
  end

  # C7. Every alignment, margin and spacing upstream writes down, read back
  # off the widget that carries it. Nothing in this driver looked at the
  # geometry axis before, which is how two divergences — a valign on the
  # colour selector at all three call sites where upstream sets it at one, and
  # a valign on the drag preview's spin button where upstream sets none — sat
  # inside a green run for two commits. The numbers below are upstream's
  # literals, cited to the line that sets them.
  d.step("the rows and the row menu carry upstream's geometry") do
    app.window.rows.first.then do |row|
      d.check("the spin button is centred (counter.lua:49)") do
        row.spin_button.valign == :center
      end
      d.check("its text is right-aligned (counter.lua:48)") do
        row.spin_button.first_child.xalign == 1.0
      end
      d.check("the count label is pushed 18px off the title (counter.lua:31)") do
        row.count_label.margin_start == 18
      end
      d.check("and aligned to the end (counter.lua:32)") do
        row.count_label.halign == :end
      end
      d.check("it does not expand (counter.lua:30)") { !row.count_label.hexpand? }

      row.menu.then do |menu|
        d.check("the menu's colour selector is spaced 6 (counter.lua:204)") do
          menu.color_selector.spacing == 6
        end
        d.check("and centred, the one site upstream centres (counter.lua:205)") do
          menu.color_selector.valign == :center
        end
        d.check("the order box is spaced 6 (counter.lua:261)") do
          menu.order_box.spacing == 6
        end
        d.check("aligned to the end (counter.lua:262)") { menu.order_box.halign == :end }
        d.check("and centred (counter.lua:263)") { menu.order_box.valign == :center }
        d.check("the pop-out button is aligned to the end (counter.lua:280)") do
          menu.popout_button.halign == :end
        end
        d.check("expands (counter.lua:281)") { menu.popout_button.hexpand? }
        d.check("and is centred (counter.lua:282)") do
          menu.popout_button.valign == :center
        end
      end
    end
  end

  d.step("the drag preview's spin button is left unaligned, as upstream leaves it") do
    app.window.rows.first.then do |row|
      Tally::CounterDragRow.new(row.counter).build.then do |preview|
        d.check("no valign, which is FILL (counter.lua:471-473)") do
          preview.spin_button.valign == :fill
        end
        d.check("where the real row's is centred (counter.lua:49)") do
          row.spin_button.valign == :center
        end
      end
    end
  end

  d.step("the pop-out window carries upstream's geometry") do
    app.window.rows.first.popout.then do |window|
      d.check("the number is centred (counter.lua:385)") do
        window.count_label.halign == :center
      end
      d.check("the button box is spaced 48 (counter.lua:413)") do
        window.button_box.spacing == 48
      end
      d.check("centred vertically (counter.lua:414)") { window.button_box.valign == :center }
      d.check("and horizontally (counter.lua:415)") { window.button_box.halign == :center }
      d.check("the number box is spaced 24 (counter.lua:421)") do
        window.number_box.spacing == 24
      end
      d.check("and centred vertically (counter.lua:422)") do
        window.number_box.valign == :center
      end
      d.check("the content box is spaced 36 (counter.lua:429)") do
        window.content_box.spacing == 36
      end
      d.check("inset 24 on every side (counter.lua:430-433)") do
        [
          window.content_box.margin_top,
          window.content_box.margin_bottom,
          window.content_box.margin_start,
          window.content_box.margin_end,
        ] == [24, 24, 24, 24]
      end
      d.check("centred vertically (counter.lua:434)") { window.content_box.valign == :center }
      d.check("and horizontally (counter.lua:435)") { window.content_box.halign == :center }
    end
  end

  d.step("the window, the search bar and the new-counter dialog carry theirs") do
    app.window.search_bar.then do |bar|
      d.check("the search box is spaced 6 (main.lua:328)") do
        bar.content_box.spacing == 6
      end
      d.check("with 6 above and below (main.lua:329-330)") do
        [bar.content_box.margin_top, bar.content_box.margin_bottom] == [6, 6]
      end
      d.check("its colour selector is spaced 6 (main.lua:319)") do
        bar.color_selector.spacing == 6
      end
      d.check("and unaligned, as searchcolorbox is (main.lua:317-321)") do
        bar.color_selector.valign == :fill
      end
    end

    app.window.counter_list.then do |list|
      d.check("the list box is top-aligned (main.lua:347)") do
        list.list_box.valign == :start
      end
      d.check("the clamp stops at 600 (main.lua:422)") { list.clamp.maximum_size == 600 }
      d.check("inset 24 at the sides and 12 top and bottom (main.lua:423-426)") do
        [
          list.clamp.margin_start,
          list.clamp.margin_end,
          list.clamp.margin_top,
          list.clamp.margin_bottom,
        ] == [24, 24, 12, 12]
      end
    end

    d.check("the status page's button has 40 either side (main.lua:452-453)") do
      [
        app.window.empty_state.create_button.margin_start,
        app.window.empty_state.create_button.margin_end,
      ] == [40, 40]
    end

    app.window.new_counter_dialog.then do |dialog|
      d.check("its box is spaced 12 (main.lua:595)") { dialog.content_box.spacing == 12 }
      d.check("and inset 12 on every side (main.lua:596-599)") do
        [
          dialog.content_box.margin_top,
          dialog.content_box.margin_bottom,
          dialog.content_box.margin_start,
          dialog.content_box.margin_end,
        ] == [12, 12, 12, 12]
      end
      d.check("the name entry fills (main.lua:556)") { dialog.name_entry.halign == :fill }
      d.check("the create button is centred (main.lua:549)") do
        dialog.create_button.halign == :center
      end
      d.check("its colour selector is spaced 6 (main.lua:569)") do
        dialog.color_selector.spacing == 6
      end
      d.check("and unaligned, as tallycolorbox is (main.lua:567-571)") do
        dialog.color_selector.valign == :fill
      end
    end
  end

  d.step("win.close closes the pop-out and leaves the main window alone") do
    app.window.rows.first.then do |row|
      row.popout.close_action.activate(nil)
      d.check("only the main window is left") { Gtk::Window.list_toplevels.length == 1 }
      d.check("the main window is still there") { app.window.visible? }
    end
  end

  # C4. main.lua:503 reads `searchbar.key_capture_widget = window`, where
  # `window` at that point in the file is the class table and the window is
  # `self.window` — so upstream's type-to-search has never worked. The port
  # assigns the window, and that fix was asserted by nothing. Reading the
  # property back is half of it; the other half is a real key press, which no
  # Ruby call can forge (gtk_event_controller_key_forward asserts on a NULL
  # current event, so emitting "key-pressed" by hand is not a key press), so
  # xdotool types into the Xvfb display this run is already on. Only the main
  # window is up at this point, which is what makes `search --name` unambiguous.
  d.step("the search bar captures keys on the window, not on a class table") do
    d.check("the capture widget is the window itself") do
      app.window.search_bar.key_capture_widget.equal?(app.window)
    end
    d.check("search mode is closed to start with") do
      !app.window.search_bar.search_mode_enabled?
    end
    d.check("the entry is empty to start with") do
      app.window.search_bar.search_entry.text.empty?
    end
    d.check("xdotool is on PATH to type with") { xdotool("--version") }
    xdotool("search", "--name", "^Tally$", "windowfocus")
    xdotool("key", "--clearmodifiers", "a")
  end

  d.step("typing a letter opened the bar and the letter landed in the entry") do
    app.window.search_bar.then do |bar|
      d.check("search mode opened by itself") { bar.search_mode_enabled? }
      d.check("the header bar's toggle followed it") { app.window.search_button.active? }
      d.check("the letter was forwarded to the entry") { bar.search_entry.text == "a" }
      bar.search_entry.text = ""
      bar.search_mode_enabled = false
    end
  end

  # C5. Both scrolling methods were asserted only to answer self, which a
  # method with an empty body also does. Upstream's counter:scroll goes
  # through the GtkViewport the ScrolledWindow interposes (main.lua:441-443),
  # and window:scrollbottom drives the vertical adjustment to its end after a
  # short delay. The adjustment is set to a scrollable range first, because
  # two rows in a 500x600 window do not overflow and an adjustment that cannot
  # move proves nothing.
  d.step("scrolling reaches the real viewport and moves the real adjustment") do
    app.window.counter_list.then do |list|
      d.check("the interposed child is a GtkViewport") do
        list.viewport.is_a?(Gtk::Viewport)
      end
      d.check("and it is the ScrolledWindow's own child") do
        list.viewport.equal?(list.child)
      end
      d.check("scrolling a row into view answers the list") do
        list.scroll_into_view(app.window.rows.first).equal?(list)
      end
      list.vadjustment.tap do |adjustment|
        adjustment.lower = 0.0
        adjustment.upper = 1000.0
        adjustment.page_size = 100.0
        adjustment.value = 0.0
      end
      d.check("the adjustment starts at the top") { list.vadjustment.value.zero? }
      list.scroll_to_bottom
      pump(Tally::CounterList::BOTTOM_DELAY_MS + 200)
      d.check("the queued scroll drove it to the end") do
        list.vadjustment.value == list.vadjustment.upper - list.vadjustment.page_size
      end
      d.check("which is as far down as it goes") do
        list.vadjustment.value + list.vadjustment.page_size >= list.vadjustment.upper
      end
    end
  end

  # C3. Store#queue_write's one-second debounce, upstream's lib.queuewrite
  # (main.lua:143-154). Every other on-disk assertion in this driver calls
  # Store#write outright, and the only queue_write ever observed was the
  # negative one — a store refusing to arm. A queue_write that armed nothing
  # would have left all of this green while losing every edit made with the
  # spin button.
  d.step("spinning a counter arms a write without performing one") do
    Tally::Store.default.then do |store|
      store.write
      app.window.rows.first.then do |row|
        row.spin_button.value = 97
        d.check("the spin button moved the counter") { row.counter.value == 97 }
        d.check("the file still has the number from before") do
          !File.read(store.path).include?("97")
        end
        d.check("nothing called #write in between") do
          JSON.parse(File.read(store.path))["counters"]
            .find { |entry| entry["name"] == "Espresso" }["value"] != 97
        end
      end
    end
  end

  d.step("the debounce writes it a second later with nothing else asked") do
    pump(Tally::Store::DEBOUNCE_MS + 400)
    Tally::Store.default.then do |store|
      d.check("the queued write landed on disk") { File.read(store.path).include?("97") }
      d.check("and it is the counter's own value") do
        JSON.parse(File.read(store.path))["counters"]
          .find { |entry| entry["name"] == "Espresso" }["value"] == 97
      end
    end
  end

  # C1. main.lua:508-514: the main window's close-request closes every
  # pop-out, so none of them keeps the application alive once the window the
  # user closed is gone. Nothing drove this before — the failure it hides is a
  # process that never exits.
  d.step("two pop-outs are opened for the close-request check") do
    app.window.rows.each(&:show_popout)
  end

  d.step("close-request on the main window closes every pop-out") do
    d.check("three toplevels are up") { Gtk::Window.list_toplevels.length == 3 }
    d.check("both rows have one") { app.window.rows.all? { |row| row.popout.visible? } }
    d.check("the handler does not veto the close") do
      app.window.signal_emit("close-request") == false
    end
    d.check("only the closing window is left") { Gtk::Window.list_toplevels.length == 1 }
    d.check("and that one is the main window") do
      Gtk::Window.list_toplevels.first.equal?(app.window)
    end
    d.check("which is still up") { app.window.visible? }
  end

  # C6. main.lua:830-832 — on_shutdown writes the config outright, so a quit
  # inside the one-second debounce still saves. The word shutdown did not
  # appear in this driver at all. A second application object with its own
  # scratch store is used rather than the running one, so emitting the signal
  # cannot tear down the run.
  d.step("shutdown writes the config, so a quit inside the debounce still saves") do
    Dir.mktmpdir("tally-shutdown").then do |dir|
      Tally::Store.new(dir: dir).then do |store|
        Tally::Application.new(store: store, devel: false).build.then do |application|
          d.check("the scratch store has no file yet") { !File.exist?(store.path) }
          application.signal_emit("shutdown")
          d.check("shutdown wrote one") { File.exist?(store.path) }
          d.check("carrying every counter in memory, in order") do
            JSON.parse(File.read(store.path))["counters"].map { |entry| entry["name"] } ==
              Tally::Counter.counters.map(&:name)
          end
          d.check("and their values") do
            JSON.parse(File.read(store.path))["counters"].map { |entry| entry["value"] } ==
              Tally::Counter.counters.map(&:value)
          end
        end
      end
    end
  end

  d.step("the colour catalogue answers upstream's getcolorname") do
    d.check("nil is the system key") { Tally::Colors.key(nil) == Tally::Colors::SYSTEM }
    d.check("and reads as No color") { Tally::Colors.name(nil) == "No color" }
    d.check("so does the system key itself") { Tally::Colors.name("system") == "No color" }
    d.check("green stays green") { Tally::Colors.key("green") == "green" }
    d.check("and reads as Green") { Tally::Colors.name("green") == "Green" }
    d.check("the system key stores as nil") { Tally::Colors.value("system").nil? }
    d.check("an accent stores as itself") { Tally::Colors.value("green") == "green" }
    d.check("the six accents are accents") { Tally::Colors::ACCENTS.all? { |c| Tally::Colors.accent?(c) } }
    d.check("system is not") { !Tally::Colors.accent?(nil) && !Tally::Colors.accent?("system") }
    d.check("the search bar offers all seven") do
      app.window.search_bar.color_selector.checks.keys.sort == Tally::Colors::ALL.sort
    end
    d.check("the new-counter dialog offers all seven too") do
      app.window.new_counter_dialog.color_selector.checks.keys.sort == Tally::Colors::ALL.sort
    end
    d.check("the dialog's group is a radio group, the bar's is not") do
      app.window.new_counter_dialog.color_selector.radio? &&
        app.window.search_bar.color_selector.multi?
    end
  end

  d.step("the French catalogue translates upstream's own msgids") do
    ENV["LANGUAGE"] = "fr"
    Tally::Locale.reset
    d.check("fr is the catalogue in play") { Tally::Locale.language == "fr" }
    d.check("the load-failure sentence comes back translated") do
      Tally::Locale.gettext(Tally::Application::LOAD_FAILURE).then do |translated|
        translated != Tally::Application::LOAD_FAILURE && !translated.strip.empty?
      end
    end
    d.check("so does a colour name") { Tally::Colors.name("red") != "Red" }
  ensure
    ENV.delete("LANGUAGE")
    Tally::Locale.reset
    d.check("English comes back when the environment does") { Tally::Colors.name("red") == "Red" }
  end

  d.step("a config file nothing can read is refused, not clobbered") do
    Dir.mktmpdir("tally-unreadable").then do |dir|
      File.join(dir, "tally").then do |path|
        File.write(path, "this is neither JSON nor a Lua table\n")
        Tally::Store.new(dir: dir).then do |store|
          d.check("the store says so") { store.unreadable? }
          d.check("and names the file") { store.unreadable == path }
          d.check("it shows no counters rather than inventing some") do
            store.saved_counters.empty?
          end
          d.check("write refuses") { store.write == false }
          d.check("queue_write arms nothing") { store.queue_write.zero? }
          d.check("the user's file is untouched") do
            File.read(path) == "this is neither JSON nor a Lua table\n"
          end
        end
      end
    end
  end

  d.step("an upstream Lua config is imported once and backed up") do
    Dir.mktmpdir("tally-lua").then do |dir|
      File.join(dir, "tally").then do |path|
        # Byte for byte the shape upstream's writecfg emits: the geometry as
        # bare `key = value` lines, then one unkeyed table per counter from
        # counter:serialize ("{\n%s},\n" around "\t[%q] = %q,\n"), so the
        # counters are the *positional* entries of the root table and not a
        # "counters" key — that key is this port's JSON spelling. The second
        # counter's value is a C99 hex float, which is what %q gives for the
        # double a Gtk.SpinButton hands over.
        File.write(path, <<~LUA)
          return {
            width = 640,
          height = 480,
          maximized = false,
          {
          	["name"] = "Pushups",
          	["value"] = 42,
          	["color"] = "purple",
          },
          {
          	["name"] = "Books",
          	["value"] = 0x1.8p+1,
          },
          }
        LUA
        Tally::Store.new(dir: dir).then do |store|
          d.check("it reads as a config") { !store.unreadable? }
          d.check("the import is reported") { store.imported? }
          d.check("the geometry came across") { [store.width, store.height] == [640, 480] }
          d.check("so did the counters, in order") do
            store.saved_counters.map(&:name) == ["Pushups", "Books"]
          end
          d.check("so did their values") { store.saved_counters.map(&:value) == [42, 3] }
          d.check("so did their colours") do
            store.saved_counters.map(&:color) == ["purple", nil]
          end
          d.check("the Lua original is kept aside") { File.exist?(store.backup_path) }
          d.check("the file on disk is JSON now") do
            JSON.parse(File.read(path))["counters"].length == 2
          end
        end
        Tally::Store.new(dir: dir).then do |second|
          d.check("a second run reads the JSON and imports nothing") { !second.imported? }
        end
      end
    end
  end

  d.step("the devel build is a different app with a striped window") do
    Tally::Application.new(devel: true).then do |devel|
      d.check("its id is the .Devel one") do
        devel.application_id == "#{Tally::Application::APP_ID}#{Tally::Application::DEVEL_SUFFIX}"
      end
      d.check("it reports itself as devel") { devel.devel? }
    end
    d.check("the release build's id has no suffix") do
      Tally::Application.new(devel: false).application_id == Tally::Application::APP_ID
    end
    Tally::MainWindow.new(app.app, store: app.store, devel: true).then do |window|
      d.check("a devel window carries the devel class") { window.has_css_class?("devel") }
      d.check("a release window does not") { !app.window.has_css_class?("devel") }
      window.destroy
    end
  end

  d.step("ticking every counter for the trip back to the empty state") do
    app.window.select_button.active = true
  end

  d.step("every row is ticked") do
    app.window.counter_list.list_box.then do |box|
      app.window.rows.each { |row| box.signal_emit("row-activated", row) }
    end
    d.check("both counters are ticked") { Tally::Counter.counters.all?(&:checked) }
  end

  d.step("deleting them all brings the status page back") do
    app.window.delete_button.activate
  end

  d.step("the app is empty again, exactly as it started") do
    d.check("no counters are left") { Tally::Counter.counters.empty? }
    d.check("the list reports itself empty") { app.window.counter_list.empty? }
    d.check("the list box is hidden") { !app.window.counter_list.list_box.visible? }
    d.check("the status page is the content again") do
      app.window.toolbar_view.content.equal?(app.window.empty_state)
    end
    d.check("the select button is hidden again") { !app.window.select_button.visible? }
    d.check("the header bar went flat") { app.window.toolbar_view.top_bar_style == :flat }
    d.check("the status page still offers its create button") do
      app.window.empty_state.create_button.sensitive?
    end
    d.check("the disk agrees") { Tally::Store.default.write && Tally::Store.default.saved_counters }
    d.shot("15-empty-again")
  end

  d.step("a reload of the emptied store brings back nothing") do
    Tally::Store.new(dir: Tally::Store.default.dir).then do |fresh|
      d.check("no counters on disk") { fresh.saved_counters.empty? }
      d.check("and the file is still readable") { !fresh.unreadable? }
    end
  end
end

# Findings

Defects found while porting Tally from Lua (LuaGObject) to Ruby (gtk4/adwaita),
written down so the next person does not have to rediscover them.

Two kinds live here:

* **Ruby binding defects** — places where the ruby-gnome bindings do not do
  what the C and Vala documentation says, and what this port does instead.
  Every one of these cost a run to find; two of them made the app unusable and
  were found by accident.
* **Upstream defects** — bugs in `origin/trunk` that this port does not
  reproduce. They are listed with upstream's own file and line, so that
  "the port fixes an upstream bug" can be checked rather than believed.

This file exists so a gap row that is genuinely hard has somewhere to point.
Citing an entry here is allowed; describing a defect only inside the sentence
that excuses a gap is the laundering the porting rules exist to stop.

Everything below was observed on:

| | |
|---|---|
| ruby-gnome (`gtk4`, `adwaita`, `glib2`, `gobject-introspection`) | 4.3.9 |
| GTK | 4.22.4 |
| libadwaita | 1.9.3 |
| Ruby | 3.4.9 |

---

## Binding defects

### B1 — `Adwaita::Application` cannot be used from Ruby

**Symptom.** `Adwaita::Application` does not reach a usable state from the Ruby
bindings, so no window can be added to it and the app never appears. It is the
natural translation of upstream's `Adw.Application` and the first thing a port
reaches for.

**Workaround.** The application object comes from Gtk and only the windows are
Adwaita: `Gtk::Application.new(id, :default_flags)` with
`Adwaita::ApplicationWindow` children. Every other `Adwaita::` widget works
inside it.

**Where.** `lib/tally/application.rb`, `#app`.

### B2 — `Adwaita::BreakpointCondition.new_length` is not bound

**Symptom.** `Adwaita::BreakpointCondition.new_length("MAX_WIDTH", 400, "PX")`,
the call upstream makes at `main.lua:497`, raises: the Ruby bindings expose only
`parse`. This was app-breaking — the main window could not be built at all —
and it was found by the *first* run of `test/drive_tally.rb`, which means that
until that script existed nobody had ever successfully built the port's main
window.

**Workaround.** Spell the same condition in the string syntax libadwaita's own
parser reads: `Adwaita::BreakpointCondition.parse("max-width: 400px")`.

**Where.** `lib/tally/main_window.rb`, `#breakpoint_condition`.

### B3 — `Gtk::CssProvider#load_from_string` vs `#load_from_data`

**Symptom.** GTK 4.12 renamed `load_from_data` to `load_from_string`. Which one
the installed gtk4 gem exposes depends on its vintage, and the old name is
deprecated rather than gone, so neither name can be written unconditionally in
code that has to run against more than one gem release.

**Workaround.** Ask the object — `respond_to?(:load_from_string)` — and call
whichever is there.

**Where.** `lib/tally/styles.rb`, `#provider`.

### B4 — `gdk_content_provider_new_for_value` is not bound under that name

**Symptom.** There is no `Gdk::ContentProvider.new_for_value`; the Ruby
constructor takes the `GLib::Value` directly
(`Gdk::ContentProvider#initialize(value: interface(GLib::Value))`). The value
also has to be typed as the gtype the matching `Gtk::DropTarget` was created
with — type it as anything else and the provider advertises a format the target
never accepts, the drop is refused, and nothing is printed.

**Workaround.**
`Gdk::ContentProvider.new(GLib::Value.new(Adwaita::ExpanderRow.gtype, self))`.

**Where.** `lib/tally/counter_row.rb`, `#prepare_drag`.

### B5 — `GtkDropTarget::drop` hands the handler a `GLib::Value`

**Symptom.** The C signal's `GValue` is passed through to the Ruby handler as a
`GLib::Value` rather than unboxed to the widget inside it, so a handler that
type-tests its argument against the widget class never matches. App-breaking in
the quiet way: every drag-to-reorder was refused and nothing was logged. Found
by driving the drop signal in `test/drive_tally.rb`, not by using the app.

**Workaround.** Take the row out of the value first, and only then check
`is_a?(Gtk::ListBoxRow)`.

**Where.** `lib/tally/counter_row.rb`, `#accept_drop` and `#dropped`.

### B6 — `Gtk::IconTheme.for_display` vs `get_for_display`

**Symptom.** `gtk_icon_theme_get_for_display` is bound as `for_display` in
recent ruby-gnome and as `get_for_display` in older releases.

**Workaround.** `respond_to?(:for_display)` and call whichever is there.

**Where.** `lib/tally/icons.rb`, `#theme_for`.

### B7 — `gtk_icon_theme_add_search_path` does not search subdirectories

**Symptom.** A GTK behaviour rather than a binding one, but a port hits it
precisely because it is replacing a GResource. A GResource base path makes
`scalable/actions/foo.svg` resolve as the icon `foo`; a *file* search path does
not. `add_search_path` finds icons sitting flat in the directory, or inside a
named theme directory below it, and nowhere else — so the obvious
`data/icons/scalable/actions` layout resolved nothing at all, silently, and the
app ran with every icon blank.

**Workaround.** Ship a real hicolor theme tree —
`data/icons/hicolor/{index.theme,scalable/actions,scalable/apps,symbolic/apps}`
— and add `data/icons` to the search path. `test/drive_tally.rb` asserts the
theme resolves all sixteen icon names, which is the check that catches this.

**Where.** `lib/tally/icons.rb`, `DIR`, `THEME` and `#path_for`.

### B8 — `Adwaita::ShortcutsItem.new` takes positional arguments

**Symptom.** A no-argument `Adwaita::ShortcutsItem.new` raises an error whose
text advertises the signature as `title: utf8, accelerator: utf8`, which reads
as keyword arguments. Keyword arguments do not work; the constructor is
positional.

**Workaround.** `Adwaita::ShortcutsItem.new(title, accelerator)`.

**Where.** `lib/tally/shortcuts_dialog.rb`, `#item`.

### B9 — no Gdk event can be forged from Ruby

**Symptom.** GTK4 has no public event constructor, and emitting `"key-pressed"`
on a `Gtk::EventControllerKey` by hand is not a key press:
`gtk_event_controller_key_forward` asserts `controller->current_event != NULL`
and the forward never happens (`Gtk-CRITICAL **:
gtk_event_controller_key_forward: assertion 'controller->current_event != NULL'
failed`). So anything whose only observable behaviour is a response to a key
press cannot be tested in-process — here,
`Gtk::SearchBar#key_capture_widget`, which is also U2 below.

**Workaround.** Let the X server deliver it. The dev shell carries `xdotool`,
and `test/drive_tally.rb` types into the Xvfb display the run is already on,
then asserts on the next tick that search mode opened and the letter reached
the entry.

**Where.** `flake.nix` (`pkgs.xdotool`); `test/drive_tally.rb`, the step
"the search bar captures keys on the window, not on a class table".

---

## Upstream defects

Six claims of the form "the port fixes an upstream bug", each re-checked
against `origin/trunk`. None has been reported upstream. U1, U2 and U4 are the
three with user-visible consequences and are the ones worth filing.

### U1 — opening a pop-out stops the row's spin button from saving

`counter.lua:51-55` installs `self.spinbtn.on_notify.value`, which writes the
new number into `self.value`, updates the count label and calls
`lib.queuewrite()`. `counter.lua:406-410`, inside `counter:zoomwindow`, assigns
`self.spinbtn.on_notify.value` *again*, with a handler that updates the
pop-out's own label and button sensitivities and nothing else. That assignment
replaces the first handler rather than adding to it, so from the moment a
counter's pop-out has been opened once, spinning that counter's row no longer
updates `self.value` and no longer queues a write: the number on screen moves
and nothing is saved.

The port hooks both — `CounterRow` keeps its own `notify::value` handler and
`CounterWindow` adds a second one.

**Port:** `lib/tally/counter_window.rb`, `#connect`. **Driven by:** the step
"the pop-out's buttons move the shared counter".

### U2 — type-to-search has never worked

`main.lua:503` reads `searchbar.key_capture_widget = window`. At that point in
the file `window` is the class table the methods are being defined on; the
window is `self.window`. Assigning a non-widget leaves the search bar with no
capture widget, so typing in the main window never opens the search bar — the
feature that line was written to provide does not exist in any released build.

The port assigns the window. **Port:** `lib/tally/main_window.rb`, `#build`
(`bar.key_capture_widget = window`). **Driven by:** the step "the search bar
captures keys on the window, not on a class table" — the check that tells a
deliberate fix apart from a transcription accident, and the only one here that
needs a real key press (see B9).

### U3 — the shortcuts window's About row is inert

`main.lua:240-244` gives the About shortcut `action_name = "app.about"`. The
action is registered on the *window*, as `win.about` (`main.lua:523-528`), and
never on the application, so that row does nothing when activated.

The port resolves `app.about` to `win.about`. **Port:**
`lib/tally/shortcuts_dialog.rb`, `ALIASES` and `#resolve`. **Driven by:** the
check "upstream's app.about resolves to the action that exists".

### U4 — the pop-out window never gets the devel stripes

`counter.lua:467` reads `if is_devel then self.zoomwin:add_css_class "devel"
end`, but `is_devel` is declared nowhere in `counter.lua` — the file's locals
are at `counter.lua:3-17` and it is not among them. The read is a global
lookup, which is `nil`, so in a devel build the main window is striped and
every pop-out is not. `main.lua` gets this right because it holds the real
local.

The port passes `devel` down to the pop-out. **Port:**
`lib/tally/counter_row.rb`, `#build_popout`, and
`lib/tally/counter_window.rb`, `#initialize`.

### U5 — `tally.doap` has three wrong namespace URIs

`tally.doap:3` declares `xmlns:rdf="http://w3.org/1999/02/22-rdf-syntax-ns#"`
and `tally.doap:4` `xmlns:rdfs="http://w3.org/2000/01/rdf-schema#"` — both are
missing the `www.` the real RDF and RDF Schema namespaces have — and
`tally.doap:7` declares the default namespace as `htp://usefulinc.com/ns/doap#`,
`htp` rather than `http`. A consumer that resolves namespaces, which is the
only reason a DOAP file exists, sees a document containing no DOAP elements at
all.

`data/org.rubygtkproject.Tally.doap` uses the correct URIs.

### U6 — the CI job writes its bundle under another app's name

`.github/workflows/ci.yml` passes `bundle: palette.flatpak` to
`flatpak/flatpak-github-actions/flatpak-builder@v6` while the manifest on the
next line is `ca.vlacroix.Tally.json`. Palette is a different application by
the same author, so the artifact the job uploads is a Tally build under
Palette's file name. Harmless, and a copy-paste left behind.

`.github/workflows/ci.yml` in this repository names the bundle after the app it
builds.

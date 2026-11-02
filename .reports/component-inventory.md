# tally — upstream component inventory

Survey of `origin/trunk` (upstream Tally 0.7.3) against `lib/` on the `ruby`
branch, for the full-parity port. No app code was written in this step.

## What upstream is

Tally is a GNOME tally-counter app: a boxed list of named, colour-coded
counters, each an `Adw.ExpanderRow` with a spin button, an expander holding
rename / recolour / reorder / pop-out controls, drag-and-drop reordering, a
search bar that filters by name and colour, a select-and-delete mode, and a
per-counter stand-alone "pop-out" window with big plus/minus buttons.

**Upstream is not Vala or C UI code.** It is **Lua** against `LuaGObject`,
compiled to bytecode and `#embed`ed into a 134-line C stub that boots a Lua
state, binds gettext and exports five native functions. There are **no `.ui`
or blueprint files and no GSettings schema** — every widget is built
imperatively in Lua, so the whole inventory comes from reading the two Lua
files rather than from a declarative tree.

| Upstream file | Lines | What it holds |
|---|---:|---|
| `main.lua` | 862 | app object, accels, actions, GResource load, config read/write, about dialog, shortcuts window, primary menu, main window, new-counter dialog, all CSS |
| `counter.lua` | 510 | counter model, its `Adw.ExpanderRow`, drag source/drop target, expander menu rows, colour selector, pop-out window, duplicate row, delete, serialise |
| `main.c` | 134 | Lua boot, `gettext`, `get_app_id`/`get_app_ver`/`get_is_devel`, bytecode embed |
| `data/tally.gresource.xml` | — | 16 bundled symbolic action icons |
| `po/MESSAGES.pot` + `fr`, `id`, `it` | — | 43 msgids, three catalogues |
| `ca.vlacroix.Tally{,.Devel}.{desktop,metainfo.xml,json}` | — | packaging, Flatpak manifests, release notes |

Persistence is a hand-rolled Lua source file at
`$XDG_CONFIG_HOME/tally/tally` — literally `return { width = …, height = …,
maximized = …, { ["name"] = …, ["value"] = … }, … }`, written via a
`tallynext` temp file and `os.rename`, with a 1-second debounce
(`lib.queuewrite`) and a final write on `shutdown`.

## What the `ruby` branch has today

Three files, skeleton only:

| File | State |
|---|---|
| `lib/tally.rb` | one `require_relative` |
| `lib/tally/application.rb` | `Gtk::Application` + `Adwaita::ApplicationWindow` + `ToolbarView` + empty `HeaderBar` + a placeholder `StatusPage` reading "The Ruby port has not been written yet." |
| `lib/tally/rb/version.rb` | version constant |

`exe/tally` is `Tally::Application.new.build.run`. Nothing of the app proper
exists: no counter, no list, no persistence, no dialogs, no CSS, no icons, no
translations.

Target paths below use `lib/tally/*.rb`, matching the branch's existing gem
layout (`lib/tally.rb` → `lib/tally/application.rb`), one upstream component
per file as the pilot port does.

---

## Component list

### `main.lua` (app section) — the application object

| Widget / object | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Application` | 1 | — | `activate`, `startup`, `shutdown` | `resource_base_path = "/ca/vlacroix/Tally"`; `Adwaita::Application` is broken in the Ruby bindings, so the port keeps `Gtk::Application` |
| `Gio.SimpleAction "quit"` | 1 | — | `activate` → `app:quit()` | app-scoped |
| accelerators | 4 | — | `win.shortcuts` `<Ctrl><Shift>question`, `win.about` `F1`, `win.close` `<Ctrl>W`, `app.quit` `<Ctrl>Q` | — |
| `Gio.Resource.load` | 1 | — | — | loads the compiled gresource; the port ships icons as files instead |

→ `lib/tally/application.rb` — **present (skeleton only)**

### `main.lua` (styles section) — the stylesheet

Three CSS strings (`cssbase`, `csslight`, `cssdark`), two `Gtk.CssProvider`s
swapped on `Adw.StyleManager::notify::dark`, installed with
`Gtk.StyleContext.add_provider_for_display` at priority 1000000.

Classes defined: `.colorselector` (+ `.red .orange .yellow .green .blue
.purple .system` on its check buttons), `.popout`, `list.tally-list row.{red,
orange, yellow, green, blue, purple}` with `:hover` variants, and matching
`toolbarview.{colour}` rules for the pop-out window. Uses libadwaita 1.8+
`var(--red-3)` palette variables and `color-mix(in srgb, …)`.

→ `lib/tally/styles.rb` — **missing**

### `main.lua` — the main window

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (when `is_devel`) | `close-request` → closes every pop-out | 500×600 default, 360×294 minimum; restores saved width/height/maximized |
| `Adw.ToolbarView` | 1 | — | — | `top_bar_style` flipped `FLAT` ⇄ `RAISED_BORDER` by both the breakpoint and `refreshtoolbar` |
| `Adw.HeaderBar` | 1 | — | — | — |
| `Adw.WindowTitle` | 1 | — | — | `("Tally", "")` — positional in Ruby |
| `Gtk.Button` new-counter | 1 | — | `clicked` → `tallydialog()` | `plus-large-symbolic`; hidden in select mode |
| `Gtk.Button` delete | 1 | `destructive-action` | `clicked` → delete every checked counter, then leave select mode | `delete-symbolic`; `visible = false` initially |
| `Gtk.ToggleButton` select | 1 | — | `notify::active` → toggles select mode on every counter, swaps new/delete buttons, rewrites its own tooltip | `check-round-outline-symbolic`; hidden when the list is empty |
| `Gtk.ToggleButton` search | 1 | — | bound bidirectionally to `searchbar.search-mode-enabled` | `loupe-large-symbolic` |
| `Gtk.MenuButton` | 1 | — | `menu_model = tallymenu` | `menu-large-symbolic`; given focus at startup |
| `Gtk.ScrolledWindow` | 1 | — | — | `hscrollbar_policy = NEVER`; `scrollbottom` animates `vadjustment` on a 20 ms timeout |
| `Adw.Breakpoint` + `Adw.BreakpointCondition` | 1 | — | `apply` → shrink, `unapply` → enlarge | `MAX_WIDTH 400 PX`; swaps layout, swaps `boxed-list` ⇄ `separators`, swaps top-bar style |
| `Gio.SimpleAction "shortcuts"` | 1 | — | `activate` → new shortcuts window | window-scoped |
| `Gio.SimpleAction "about"` | 1 | — | `activate` → presents the about dialog | window-scoped |

→ `lib/tally/main_window.rb` — **missing**

### `main.lua` — the primary menu

`Gio.Menu` with two items: "Keyboard Shortcuts" → `win.shortcuts`, "About
Tally" → `win.about`.

→ `lib/tally/main_menu.rb` — **missing**

### `main.lua` — the counter list and its responsive layout

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ListBox` | 1 | `tally-list`, `boxed-list` ⇄ `separators` | `row-activated` → toggles the row's checkbox in select mode | `selection_mode = NONE`, `valign = START`, `visible = false` until the first counter exists |
| filter func | 1 | — | — | passes everything when search mode is off; otherwise name substring (case-folded) **and** colour filter |
| `Adw.Clamp` | 1 | — | — | `maximum_size = 600`, 24/12 margins — the wide layout |
| `Adw.Layout` | 2 | — | — | big (clamped) and small (bare) |
| `Adw.LayoutSlot` | 2 | — | — | `"list"`; positional constructor |
| `Adw.MultiLayoutView` | 1 | — | — | `set_child("list", lbox)`; libadwaita 1.9 has it |
| counter rows (repeater) | *n* | — | — | one per saved counter, appended at load and on create |

→ `lib/tally/counter_list.rb` — **missing**

### `main.lua` — the search bar

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.SearchBar` | 1 | — | `notify::search-mode-enabled` → clears every colour check | `connect_entry`, bound to the header toggle, `key_capture_widget` set (upstream sets it to the class, not the window — a bug to fix in the port) |
| `Gtk.SearchEntry` | 1 | — | `search-changed` → `invalidate_filter` | placeholder "Filter by name…" |
| `Gtk.Box` | 2 | `colorselector` on the inner one | — | vertical wrapper + horizontal colour box |
| `Gtk.CheckButton` | 7 | one of `system red orange yellow green blue purple` | `notify::active` → recomputes the colour filter set, `invalidate_filter` | **multi-select** (no group), tooltip from the colour name |

→ `lib/tally/search_bar.rb` — **missing**

### `main.lua` — the empty state

`Adw.StatusPage` titled "No Counters", icon `tally-symbolic`, child a
`Gtk.Button` with `suggested-action` + `pill` labelled "Create Counter" →
opens the new-counter dialog. Swapped in and out as `toolbarview.content` by
`refreshtoolbar()`.

→ `lib/tally/empty_state.rb` — **missing** (the skeleton's `StatusPage` is a
"port not written yet" placeholder, not this component)

### `main.lua` — the new-counter dialog

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` | 1 | — | — | title "New Counter", presented on the main window |
| `Adw.ToolbarView` + `Adw.HeaderBar` | 1 each | — | — | — |
| `Gtk.Box` | 2 | `colorselector` on the colour box | — | vertical page box (12 spacing/margins) + horizontal colour box |
| `Gtk.Entry` | 1 | `error` (dynamic, while empty) | `changed` → toggles `error` and the create button's `sensitive` | placeholder "Name" |
| `Gtk.CheckButton` | 7 | `red orange yellow green blue purple` (the "no colour" one bare) | `notify::active` → sets the pending colour | **radio group** on the no-colour button — unlike the search bar's multi-select |
| `Gtk.Button` create | 1 | `suggested-action` | `clicked` → builds the counter, appends it, writes config, scrolls to bottom, focuses the row, refreshes the toolbar, closes | child is an `Adw.ButtonContent` (`plus-large-symbolic`, "Add to List"); starts insensitive |

→ `lib/tally/new_counter_dialog.rb` — **missing**

### `main.lua` — the about dialog

`Adw.AboutDialog`: app icon/name, copyright, developer, issue URL, `GPL_3_0`,
version and release-notes version from the C stub, website, translator
credits, inline `release_notes` HTML, and two `add_link` entries ("Translate
this app!", "Support this app!").

→ `lib/tally/about_dialog.rb` — **missing**

### `main.lua` — the keyboard-shortcuts window

`Gtk.ShortcutsWindow` (modal, transient, `application` set) → one
`Gtk.ShortcutsSection` → two `Gtk.ShortcutsGroup`s:

- **Main Window** — Quit Application `<Ctrl>Q`, Keyboard Shortcuts `<Ctrl><Shift>question`, About Tally `F1`
- **Counter Window** — Quit Application `<Ctrl>Q`, Close Window `<Ctrl>W`

Two upstream inconsistencies to resolve in the port: the section title uses an
undefined `app_title` global, and the About row names `app.about` while the
action is actually installed as `win.about`. `Gtk.Shortcuts*` is deprecated in
GTK 4.18; libadwaita 1.9 offers `Adw.ShortcutsDialog`, which the pilot port
already uses.

→ `lib/tally/shortcuts_dialog.rb` — **missing**

### `main.lua` — persistence

`readcfg`/`writecfg`/`lib.queuewrite`: creates `$XDG_CONFIG_HOME/tally`,
repairs the case where it exists as a file, seeds `return {}`, reads
`tallynext` first and falls back to `tally` when the temp file fails to
`load`, writes window geometry plus every counter's `serialize()`, and
debounces writes 1 s through a `GLib.timeout_add` counter.

→ `lib/tally/store.rb` — **missing** (backend)

### `counter.lua` — the counter model

`name` (default `"unnamed"`), `value` (default 0), `color` (nil = "system"),
`checked`, `checkmode`, plus `read`, `getcolor`, `setcolor`, `serialize`
(reflects over every string/number/boolean field) and `delete`. Module-level
`counters` array and `counterrows` row→counter map are the app's ordering and
lookup.

→ `lib/tally/counter.rb` — **missing** (model)

### `counter.lua` — the counter row

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ExpanderRow` | 1 | `spin`, one colour class (dynamic), `checked`, `error` | `notify::expanded` → scrolls itself into view on a 50 ms timeout | title is the counter name; `enable_expansion` off in select mode |
| `Gtk.SpinButton` | 1 | — | `notify::value` → updates model, count label and queues a write | range 0–1 000 000 step 1; first child `xalign = 1`; hidden in select mode |
| `Gtk.Label` count | 1 | — | — | `visible = false` except in select mode; the read-only stand-in for the spin button |
| `Gtk.CheckButton` | 1 | — | `notify::active` → sets `checked`, toggles `checked` on the row | prefix; hidden except in select mode |
| `Gtk.Image` drag handle | 1 | `drag-handle` | — | `drag-handle-symbolic`; prefix; carries the drag source |
| `Gtk.DragSource` (controller) | 1 | — | `prepare` → `ContentProvider.new_for_value(ExpanderRow)`, `drag-begin` → builds the drag icon | `actions = MOVE`, `propagation_phase = CAPTURE` |
| `Gtk.DropTarget` (controller) | 1 | — | `drop` → reorders the list box and the `counters` array, queues a write | `formats = ContentFormats.new_for_gtype(Adw.ExpanderRow)`, `preload = true` |
| `Gtk.DragIcon` + `Gtk.ListBox` | 1 each | `tally-list`, `boxed-list` | — | the floating drag preview, size-matched to the real row |

Also pokes `row.child:get_last_child()` to set `hexpand` on the suffix box so
suffixes stay right-aligned when the spin button hides.

→ `lib/tally/counter_row.rb` — **missing**

### `counter.lua` — the drag preview row

`counter:duplicate()` builds a throwaway `Adw.ExpanderRow` with a bare spin
button, the colour class, the title and a drag-handle image, then runs the
expander menu over it in insensitive "duplicate" mode.

→ `lib/tally/counter_drag_row.rb` — **missing**

### `counter.lua` — the expander menu (the row's expanded contents)

Four nested rows, every control `sensitive = not duplicate`:

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.EntryRow` | 1 | — | `changed` → renames model, row title and pop-out title; adds `error` to the row while empty; queues a write | title "Name" |
| `Adw.ActionRow` colour | 1 | — | — | title "Color", suffix is the colour selector |
| `Adw.ActionRow` reorder | 1 | — | — | title "Reorder in List" |
| `Gtk.Button` move | 4 | — | `clicked` → move top / up / down / bottom, each reordering both the list box and `counters`, queueing a write and scrolling after 50 ms | `move-top-`, `move-up-`, `move-down-`, `move-bottom-symbolic`; up/down skip unmapped (filtered-out) rows |
| `Adw.ActionRow` pop-out | 1 | — | — | title "Show in a Separate Window" |
| `Gtk.Button` pop-out | 1 | — | `clicked` → presents the counter window | `pop-out-symbolic` |

→ `lib/tally/counter_menu.rb` — **missing**

### `counter.lua` — the colour selector

`Gtk.Box` (`colorselector`, 6 spacing) holding seven `Gtk.CheckButton`s in one
radio group — a bare "no colour" button plus one per colour, each carrying its
colour as a CSS class and the translated colour name as its tooltip, each
`notify::active` setting the counter's colour and queueing a write. The same
control appears three times with different semantics (radio here and in the
new-counter dialog, multi-select in the search bar), so it is one extracted
component with a mode.

→ `lib/tally/color_selector.rb` — **missing**

### `main.lua` — the colour vocabulary

`lib.getcolorname` maps `system|red|orange|yellow|green|blue|purple` to
translated names ("No color", "Red", …). The ordered colour list drives the
selector, the filter and the CSS.

→ `lib/tally/colors.rb` — **missing**

### `counter.lua` — the pop-out counter window

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | one colour class on its content (dynamic), `devel` | `close-request` → destroys and forgets the window | `hide_on_close = true`, 400×300 default, 360×294 minimum, title `"<name> — Tally"` |
| `Adw.ToolbarView` | 1 | colour class | — | `width_request = 300` |
| `Adw.HeaderBar` + `Adw.WindowTitle` | 1 each | — | — | title bound bidirectionally to the counter's `Adw.EntryRow` text |
| `Gtk.WindowHandle` | 1 | — | — | lets the whole window be dragged |
| `Gtk.Box` | 3 | `popout` on the inner one | — | outer (36 spacing, 24 margins), number box (24), button box (48) |
| `Gtk.Label` | 1 | `numeric` | — | `width_request = 240`; 300% font from `.popout` |
| `Gtk.Button` decrement | 1 | `circular` | `clicked` → `value - 1` | `minus-symbolic`; insensitive at 0 |
| `Gtk.Button` increment | 1 | `circular` | `clicked` → `value + 1` | `plus-symbolic`; insensitive at 1 000 000 |
| `Gio.SimpleAction "close"` | 1 | — | `activate` → closes the window | window-scoped, bound to `<Ctrl>W` |

One window per counter, memoised on the counter; closing the main window
closes all of them; deleting a counter destroys its window to avoid keeping
the app alive.

**Note an upstream bug to not reproduce:** `popout` reassigns
`self.spinbtn.on_notify.value`, replacing the handler installed in the
constructor — so once a counter has been popped out, changing its value stops
updating the inline count label and stops queueing a write.

→ `lib/tally/counter_window.rb` — **missing**

### `data/` — bundled icons

16 symbolic SVGs (`check-mark`, `check-round-outline`,
`cross-large-circle-outline`, `delete`, `drag-handle`, `loupe-large`,
`menu-large`, `minus`, `move-bottom`, `move-down`, `move-top`, `move-up`,
`plus-large`, `plus`, `pop-out`, `tally`) registered through GResource so the
app does not depend on the host icon theme. `cross-large-circle-outline` is
bundled but referenced nowhere in the Lua.

→ `lib/tally/icons.rb` + `data/icons/` — **missing** (resources)

### `main.c`, `po/` — locale and app metadata

`gettext` on the `messages` domain, 43 msgids, catalogues for `fr`, `id` and
`it`; `get_app_id`, `get_app_ver`, `get_is_devel` supply the app id, the
version shown in About and the `devel` CSS class.

→ `lib/tally/locale.rb` — **missing**; version already at
`lib/tally/rb/version.rb` — **present**

---

## Totals

26 components. **2 present** (the application object as a bare skeleton, and
the version constant); **24 missing**, including every window, dialog, row,
the list, the search bar, the empty state, persistence, the stylesheet, the
icons and the translations.

## Blockers and things that cannot port straight across

1. **Upstream is Lua + C with no declarative UI.** There is nothing to
   transcribe — no `.ui`, no `.blp`, no GSettings schema. Every component
   above was recovered by reading `main.lua` and `counter.lua`, so the port is
   written from the behaviour, not from a tree.
2. **The C stub and the build do not port at all.** `main.c` exists only to
   embed Lua bytecode (`#embed`), bind `gettext` and pass `-DPACKAGE`/
   `-DVERSION` from the Makefile. Ruby replaces all of it; `exe/tally` is the
   entry point and the version comes from `lib/tally/rb/version.rb`.
3. **The config format cannot be kept.** Upstream's save file is executable
   Lua source, read with `load()`. A Ruby port must not `eval` it; it has to
   pick JSON (or similar), which means **no read-compatibility with an
   existing upstream config file** unless a one-way importer is written.
4. **`Adwaita::Application` is broken in the Ruby bindings** (per the
   `ruby-gtk` skill), so upstream's `Adw.Application` becomes
   `Gtk::Application` with Adwaita widgets inside.
5. **`extra_css_classes`, `top_bars = …`, inline children in the constructor
   table and `on_notify.foo` are all LuaGObject sugar** with no Ruby
   equivalent. Every one becomes `add_css_class`, `add_top_bar`, `append` and
   `signal_connect('notify::foo')` — mechanical, but it is most of the diff.
6. **Drag-and-drop by GObject value is the riskiest piece.**
   `Gdk.ContentProvider.new_for_value(GObject.Value(Adw.ExpanderRow, row))`
   and `Gdk.ContentFormats.new_for_gtype(Adw.ExpanderRow)` depend on wrapping
   a widget in a `GObject::Value` of its own type; the Ruby bindings' handling
   of that needs verifying before the reorder-by-drag component is trusted,
   with button-only reordering as the fallback.
7. **`Gtk.ShortcutsWindow` is deprecated** in GTK 4.18. libadwaita 1.9 is
   present and has `Adw.ShortcutsDialog`, which the pilot port uses; the
   section/group structure maps across but the widget names do not.
8. **The stylesheet needs libadwaita 1.8+** for `var(--red-3)`-style palette
   variables, and `Gtk::CssProvider#load_from_string` needs GTK 4.12+. The
   local libadwaita is 1.9.0, so both are fine here but are hard floors.
9. **Internal-structure poking.** `row.child:get_last_child()` (ExpanderRow
   suffix box) and `spinbtn:get_first_child()` (the entry inside the spin
   button) reach into widget internals that are not API. They work, but they
   are version-fragile and may need a different approach in Ruby.
10. **`Adw.MultiLayoutView`/`Layout`/`LayoutSlot` exist in libadwaita 1.9** and
    are therefore portable — but `Adw.LayoutSlot.new "list"` is positional,
    and the whole responsive mechanism can be replaced by swapping the
    `Adw::Clamp` in the breakpoint handler if the bindings fight back.
11. **Flatpak-only assumptions.** Hardcoded `/app/lib`, `/app/share`,
    `/app/data/tally.gresource`, `resource_base_path` and a `XDG_CONFIG_HOME`
    that is assumed to be set. The port needs real path resolution and a
    fallback to `~/.config`.
12. **Translations are a separate parity axis.** 43 msgids across `fr`, `id`
    and `it`. Ruby has no `xgettext`-over-Lua equivalent here; the port needs
    its own gettext setup, and until then every string is English.

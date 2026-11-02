# Component identification — tally / tally-rb

|  |  |
|---|---|
| Upstream | `origin/trunk` @ `e9986b010c950d2df91b682769b744c412348e0c` |
| Port | `ruby` @ `eb1f26ae78a5584b17c03f2e2a646a9a0051ad54` |
| Scope | whole app (upstream is 1372 lines of Lua + 134 of C; a unit-at-a-time census would be larger than the app) |

## Step 1 — declarative UI

There is none, on either side.

```
$ git ls-tree -r --name-only origin/trunk | grep -E '\.(ui|blp)$'
(nothing)
```

Upstream is LuaGObject building every widget in code (`main.lua`,
`counter.lua`), with `main.c` as an entry stub that embeds Lua bytecode and
binds `gettext`. There is no `.ui`, no `.blp`, no GSettings schema, no
`GtkBuilder` XML. The port has none either, by house-style design. So the
inventory below was recovered by reading both trees; Step 1 contributes nothing
and the scan is the only mechanical input.

## Step 2–3 — the scan

`component-scan.sh` does not read `.lua` (it matches `.ui .blp .vala .c .h .py
.js .ts .rs .rb`), so upstream produces **zero rows** as shipped. The upstream
numbers below come from running the scan over copies of `main.lua` and
`counter.lua` renamed to `.rb` — LuaGObject's `Adw.Foo {}` constructor tables
are close enough to Ruby's `Adwaita::Foo.new` for the regexes to match — and
then corrected by hand. Treat them as a lead, not a verdict; the per-component
tables are the reading.

| Axis | Upstream distinct | Port distinct |
|---|---:|---:|
| Widget types | 33 | 31 |
| Controllers | 2 | 2 |
| CSS classes attached | 20 | 20 |
| Signals connected | 14 | 17 |
| Actions installed | 4 | 4 |

The widget-type counts being this close on a port this young is unusual and it
is real: tally is a small app and the port is structurally complete. The gaps
in this audit are therefore almost all **outside** the widget stream — assets,
packaging, metadata, dependency declaration and verification. See
`component-parity.md`.

## Component list

File mapping, in the order a user meets the components.

| Upstream | Port |
|---|---|
| `main.lua` (app section) + `main.c` | `lib/tally/application.rb`, `exe/tally`, `lib/tally.rb` |
| `main.lua` (styles section) | `lib/tally/styles.rb` |
| `main.lua` (`window` class) | `lib/tally/main_window.rb` |
| `main.lua` (`tallymenu`) | `lib/tally/main_menu.rb` |
| `main.lua` (`lbox`/`clamp`/`multi`, `enlarge`, `shrink`, `scrollbottom`) | `lib/tally/counter_list.rb` |
| `main.lua` (searchbar block) | `lib/tally/search_bar.rb` |
| `main.lua` (`statuspage`) | `lib/tally/empty_state.rb` |
| `main.lua` (`window:tallydialog`) | `lib/tally/new_counter_dialog.rb` |
| `main.lua` (`aboutwin`) | `lib/tally/about_dialog.rb` |
| `main.lua` (`newshortcutwindow`) | `lib/tally/shortcuts_dialog.rb` |
| `main.lua` (`readcfg`/`writecfg`/`queuewrite` + bootstrap do-block) | `lib/tally/store.rb` |
| `main.lua` (`lib.getcolorname`) | `lib/tally/colors.rb` |
| `counter.lua` (`counter` fields, `serialize`, `delete`, registries) | `lib/tally/counter.rb` |
| `counter.lua` (`counter` constructor, `setcheckmode`, drag/drop) | `lib/tally/counter_row.rb` |
| `counter.lua` (`createmenu`) | `lib/tally/counter_menu.rb` |
| `counter.lua` (`colorrow`, `gencolorcheck`) + the two open-coded copies in `main.lua` | `lib/tally/color_selector.rb` |
| `counter.lua` (`duplicate`) | `lib/tally/counter_drag_row.rb` |
| `counter.lua` (`popout`) | `lib/tally/counter_window.rb` |
| `data/tally.gresource.xml` + `data/icons/**` | `lib/tally/icons.rb` + `data/icons/**` |
| `main.c` (`lua_gettext`) + `po/**` | `lib/tally/locale.rb` + `po/**` |
| `icons/ca.vlacroix.Tally{,.Devel}{,-symbolic}.svg` | — |
| `ca.vlacroix.Tally{,.Devel}.desktop` | — |
| `ca.vlacroix.Tally{,.Devel}.metainfo.xml` | — |
| `ca.vlacroix.Tally{,.Devel}.json` (Flatpak) | — |
| `COPYING` | — |
| `Makefile` (bytecode, gresource, `xgettext`/`msgmerge`/`msgfmt`, `install`) | partly `flake.nix`; the message-catalogue half has no counterpart |
| `tally.doap`, `tally.png`, `.github/workflows/ci.yml` | — |

### `main.lua` (app section) + `main.c` — the application object

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Application` | 1 | — | `activate`, `startup`, `shutdown` | `application_id` and `resource_base_path = "/ca/vlacroix/Tally"` |
| — | — | — | accels for `win.shortcuts` `<Ctrl><Shift>question`, `win.about` `F1`, `win.close` `<Ctrl>W`, `app.quit` `<Ctrl>Q` | four `set_accels_for_action` calls |
| — | — | — | action `app.quit` | `Gio.SimpleAction`, `enabled = true` |

`main.c` additionally supplies `get_app_id`, `get_app_ver`, `get_is_devel`
(from the `-DDEVEL` compile flag) and `gettext`, plus a GResource load of
`/app/data/tally.gresource`, and one translatable string of its own: the
unrecoverable-load-error message on stderr.

Repeaters: none. Conditional: `is_devel` switches the app id to the `.Devel`
suffix and adds the `devel` CSS class to every window.

### `main.lua` (styles section) — the stylesheet

Not widgets. Two `Gtk.CssProvider`s (base+light, base+dark) added to the
default `Gdk.Display` at priority 1000000, swapped on
`Adw.StyleManager::notify::dark`. 20 rule blocks in base, 25 in light, 25 in
dark. The classes the sheet defines: `colorselector`, `popout`, `tally-list`,
and `red`/`orange`/`yellow`/`green`/`blue`/`purple`/`system` in both the
`.colorselector checkbutton.<c>` and `list.tally-list row.<c>` /
`toolbarview.<c>` forms, each with a `:hover` variant.

### `main.lua` — the main window

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (when `is_devel`) | `close-request` | title `_"Tally"`, default 500×600, min 360×294; `maximize()` and the saved size applied from the config |
| `Adw.ToolbarView` | 1 | — | — | `top_bar_style` toggled `FLAT` ↔ `RAISED_BORDER` by `refreshtoolbar`, `enlarge` and `shrink` |
| `Adw.HeaderBar` | 1 | — | — | `title_widget = Adw.WindowTitle.new(_"Tally", "")` |
| `Adw.WindowTitle` | 1 | — | — | empty subtitle |
| `Gtk.Button` (new) | 1 | — | `clicked` → `tallydialog` | `plus-large-symbolic`, `_"Create a new counter"` |
| `Gtk.Button` (delete) | 1 | `destructive-action` | `clicked` → delete checked | `delete-symbolic`, `_"Delete selected counters"`, `visible = false` |
| `Gtk.ToggleButton` (select) | 1 | — | `notify::active` | `check-round-outline-symbolic`; tooltip swaps `_"Select counters to delete"` ↔ `_"Stop selecting without deleting anything"` |
| `Gtk.ToggleButton` (search) | 1 | — | — | `loupe-large-symbolic`, `_"Filter counters by name and/or color"`; `active` bound BIDIRECTIONAL to the search bar's `search-mode-enabled` |
| `Gtk.MenuButton` | 1 | — | — | `menu-large-symbolic`, `_"Menu"`, `menu_model = tallymenu`; `grab_focus` at the end of construction |
| `Adw.Breakpoint` | 1 | — | `apply` → `shrink`, `unapply` → `enlarge` | condition `max-width: 400px` |
| — | — | — | actions `win.shortcuts`, `win.about` | both `Gio.SimpleAction`, `enabled = true` |

Pack order: `pack_start` new, delete, select; `pack_end` menu, search.
Conditional: `refreshtoolbar` hides the select button and swaps the content for
the status page when there are no counters. `close-request` closes every
pop-out window.

### `main.lua` — the primary menu

A `Gio.Menu` with two items: `_"Keyboard Shortcuts"` → `win.shortcuts`,
`_"About Tally"` → `win.about`. No quit item, though `<Ctrl>Q` is bound.

### `main.lua` — the counter list and its responsive layout

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ScrolledWindow` | 1 | — | — | `hscrollbar_policy = NEVER` |
| `Adw.MultiLayoutView` | 1 | — | — | one slot, `"list"` |
| `Adw.Layout` | 2 | — | — | wide wraps the slot in the clamp, narrow uses it bare |
| `Adw.LayoutSlot` | 2 | — | — | both named `"list"` |
| `Adw.Clamp` | 1 | — | — | `maximum_size = 600`, margins 24/24/12/12 |
| `Gtk.ListBox` | 1 | `tally-list`, `boxed-list` ↔ `separators` (swapped by `enlarge`/`shrink`) | `row-activated` | `selection_mode = NONE`, `valign = START`, `visible = false` until it has a row; `set_filter_func` |

`window:scrollbottom` nudges the vertical adjustment to `upper` after 20 ms;
`counter:scroll` calls `viewport:scroll_to(row)`.

### `main.lua` — the search bar

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.SearchBar` | 1 | — | `notify::search-mode-enabled` → clear every colour tick | `connect_entry`, `key_capture_widget` |
| `Gtk.Box` (vertical) | 1 | — | — | spacing 6, margins top/bottom 6 |
| `Gtk.SearchEntry` | 1 | — | `search-changed` → `invalidate_filter` | `_"Filter by name…"` |
| `Gtk.Box` (horizontal) | 1 | `colorselector` | — | spacing 6 |
| `Gtk.CheckButton` | **7** (repeater over `system red orange yellow green blue purple`) | one of `system`/`red`/`orange`/`yellow`/`green`/`blue`/`purple` | `notify::active` → recompute `filtcolors` and `invalidate_filter` | ungrouped, so any number can be ticked; tooltip from `getcolorname` |

The filter: a closed bar filters nothing; an open bar with an empty query and
no colour ticked filters nothing; otherwise show when the colour is ticked (or
none is) **and** the lowercased name contains the lowercased query as a plain
substring.

### `main.lua` — the empty state

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.StatusPage` | 1 | — | — | `_"No Counters"`, `icon_name = "tally-symbolic"` |
| `Gtk.Button` | 1 | `suggested-action`, `pill` | `clicked` → `tallydialog` | `_"Create Counter"`, margins start/end 40 |

### `main.lua` — the new-counter dialog

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` | 1 | — | — | `_"New Counter"` |
| `Adw.ToolbarView` | 1 | — | — | `top_bars = { Adw.HeaderBar() }` |
| `Adw.HeaderBar` | 1 | — | — | bare |
| `Gtk.Box` | 1 | — | — | vertical, spacing 12, margins 12 all round |
| `Gtk.Entry` | 1 | `error` (while empty) | `changed` | `_"Name"`, `halign = FILL` |
| `Gtk.Box` | 1 | `colorselector` | — | horizontal, spacing 6 |
| `Gtk.CheckButton` | **7** (repeater) | the first is **unclassed**; the other six carry their colour | `notify::active` | the six are `group`ed on the first, so exactly one is ever active |
| `Gtk.Button` | 1 | `suggested-action` | `clicked` → create | `sensitive = false` while the name is empty; `_"Add this counter to the list"` |
| `Adw.ButtonContent` | 1 | — | — | `plus-large-symbolic`, `_"Add to List"` |

Creating: insert into `tallies` and `tallyrows`, `writecfg`, append the row,
show the list box, `scrollbottom`, `row:grab_focus`, `refreshtoolbar`, close.

### `main.lua` — the about dialog

One `Adw.AboutDialog`, built once at startup and presented repeatedly.
`application_icon = app_id` (the app's **own** icon, not a symbolic action
icon), `application_name = _"Tally"`, copyright, `developer_name`, `issue_url`,
`license_type = GPL_3_0`, `release_notes_version = get_app_ver()` (0.7.3),
`translator_credits = _"translator-credits"`, `version`, `website`. Two
`add_link` calls: `_"Translate this app!"`, `_"Support this app!"`. One
`release_notes` markup paragraph.

### `main.lua` — the keyboard-shortcuts window

| Widget | × | Notes |
|---|---:|---|
| `Gtk.ShortcutsWindow` | 1 | built fresh per activation; `transient_for` the main window, `modal = true`, `application = app` |
| `Gtk.ShortcutsSection` | 1 | `title = app_title` — an **undefined global**, so nil |
| `Gtk.ShortcutsGroup` | 2 | `_"Main Window"`, `_"Counter Window"` |
| `Gtk.ShortcutsShortcut` | 5 | each carries `action_name` **and** `title` **and** `accelerator` |

The five: `app.quit`/`_"Quit Application"`/`<Ctrl>Q`,
`win.shortcuts`/`_"Keyboard Shortcuts"`/`<Ctrl><Shift>question`,
`app.about`/`_"About Tally"`/`F1` (note: the installed action is `win.about`,
so upstream's own reference is wrong), then in the second group
`app.quit`/`_"Quit Application"`/`<Ctrl>Q` and
`win.close`/`_"Close Window"`/`<Ctrl>W`.

### `main.lua` — persistence

Not widgets. `$XDG_CONFIG_HOME/tally/tally` holding **executable Lua source**
(`return { width = …, height = …, maximized = "…", {…}, {…} }`), written via
`tally/tallynext` + `os.rename`, read with `load()` and preferring a leftover
`tallynext` whose syntax parses. `lib.queuewrite` debounces one second deep
with a pending-write counter. The bootstrap do-block deletes a non-directory
sitting at the `tally` path, creates the directory, and seeds the file with
`return {}`.

### `counter.lua` — the counter model

Not widgets. Fields `name` (default `"unnamed"`), `value` (default 0), `color`
(nil = none), transient `checked` and `checkmode`. `serialize()` dumps **every**
scalar field it finds, so `checked`/`checkmode` land on disk; `readcfg` only
ever reads `name`/`value`/`color` back. Two module-level registries: `counters`
(ordered, the serialization order) and `counterrows` (`Gtk.ListBoxRow` →
counter). `getcolor()` answers `"system"` for nil. `counter:read()` exists and
is never called.

### `counter.lua` — the counter row

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ExpanderRow` | 1 | `spin`, the counter's colour (`red`…`purple`, dynamic), `checked` (while ticked), `error` (while the name is empty) | `notify::expanded` → scroll into view after 50 ms | `title = name` |
| `Gtk.Image` (prefix) | 1 | `drag-handle` | — | `drag-handle-symbolic`; hidden in select mode |
| `Gtk.CheckButton` (prefix) | 1 | — | `notify::active` → set `checked`, add/remove `checked` | `visible = false` outside select mode |
| `Gtk.Label` (suffix) | 1 | — | — | `visible = false` outside select mode; `margin_start = 18`, `halign = END` |
| `Gtk.SpinButton` (suffix) | 1 | — | `notify::value` → write back and `queuewrite` | `new_with_range(0, 1000000, 1)`, first child `xalign = 1`, `valign = CENTER` |
| `Gtk.DragSource` (controller, on the handle) | 1 | — | `prepare`, `drag-begin` | `actions = MOVE`, `propagation_phase = CAPTURE` |
| `Gtk.DropTarget` (controller, on the row) | 1 | — | `drop` → reorder both orders | `actions = MOVE`, `formats` for the `Adw.ExpanderRow` gtype, `preload = true` |
| `Gtk.ListBox` (drag icon) | 1 | `tally-list`, `boxed-list` | — | throwaway, sized to the row's allocation, `drag_highlight_row` |
| `Gtk.DragIcon` | 1 | — | — | `get_for_drag`, hotspot at the grab point |

`setcheckmode` is the state swap: handle+spin button out, check button+label
in, row collapsed and `enable_expansion = false`. The suffix box gets
`hexpand = true` so the label stays right-aligned once the spin button hides.

### `counter.lua` — the drag preview row

A throwaway `Adw.ExpanderRow` (no `spin` class) with the same title, the same
colour class, the same expanded state, a `Gtk.Image` `drag-handle` prefix and a
bare `Gtk.SpinButton` suffix carrying the same value. `createmenu` is attached
to it in duplicate mode.

### `counter.lua` — the expander menu

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.EntryRow` | 1 | — | `changed` | `_"Name"`; empty text adds `error` to the row and keeps the old name |
| `Adw.ActionRow` (colour) | 1 | — | — | `_"Color"`, suffix the colour selector |
| `Adw.ActionRow` (order) | 1 | — | — | `_"Reorder in List"`, suffix the order box |
| `Adw.ActionRow` (pop-out) | 1 | — | — | `_"Show in a Separate Window"` |
| `Gtk.Box` | 1 | — | — | horizontal, spacing 6, `halign = END`, `valign = CENTER` |
| `Gtk.Button` | 4 | — | `clicked` | `move-top-symbolic` `_"Move counter to the top of the current list"`, `move-up-symbolic` `_"Move counter to just above the previous row"`, `move-down-symbolic` `_"Move counter to just below the next row"`, `move-bottom-symbolic` `_"Move counter to the bottom of the current list"` |
| `Gtk.Button` (pop-out) | 1 | — | `clicked` | `pop-out-symbolic`, `_"Create a new window for this counter"`, `halign = END`, `hexpand = true` |

Conditional: when attached to a drag preview (`duplicate`), every control is
`sensitive = false` and **no handler is connected at all**. Up/down skip rows
the filter has unmapped. Every reorder moves the list box child **and** the
`counters` array, then `queuewrite`s and scrolls after 50 ms.

### `counter.lua` — the colour selector

One `Gtk.Box` with `colorselector` and **7** `Gtk.CheckButton`s, the six accent
ones `group`ed on the first so exactly one is active, each carrying its colour
class (the first unclassed) and `getcolorname` as its tooltip. The same widget
is open-coded three times upstream: here, in the search bar (ungrouped,
first button classed `system`) and in the new-counter dialog.

### `main.lua` — the colour vocabulary

`lib.getcolorname` returns `_"No color"` for nil and `"system"`, then
`_"Red"`, `_"Orange"`, `_"Yellow"`, `_"Green"`, `_"Blue"`, `_"Purple"`.

### `counter.lua` — the pop-out counter window

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (dead — `is_devel` is not in scope in this file) | `close-request` → destroy and drop the reference | `"<name> — Tally"`, `hide_on_close = true`, 400×300, min 360×294 |
| `Adw.ToolbarView` | 1 | the counter's colour (dynamic) | — | `width_request = 300` |
| `Adw.HeaderBar` | 1 | — | — | `title_widget` the window title |
| `Adw.WindowTitle` | 1 | — | — | `(name, _"Tally")`; `title` bound BIDIRECTIONAL to the menu's entry `text` |
| `Gtk.WindowHandle` | 1 | — | — | the whole face drags the window |
| `Gtk.Box` | 3 | the middle one `popout` | — | outer vertical 36 + margins 24, number box vertical 24, button box horizontal 48 |
| `Gtk.Label` | 1 | `numeric` | — | `width_request = 240`, `halign = CENTER` |
| `Gtk.Button` | 2 | `circular` | `clicked` | `minus-symbolic` `_"Decrement by 1"` (insensitive at 0), `plus-symbolic` `_"Increment by 1"` (insensitive at 1000000) |
| — | — | — | action `win.close` | `Gio.SimpleAction`, `enabled = true` |

`popout` reassigns the counter's `spinbtn.on_notify.value` handler, which
silently unhooks the list row's own handler for as long as the pop-out exists.

### `data/` — the bundled icons

16 symbolic action SVGs in a GResource under `/ca/vlacroix/Tally`:
`check-mark`, `check-round-outline`, `cross-large-circle-outline`, `delete`,
`drag-handle`, `loupe-large`, `menu-large`, `minus`, `move-bottom`,
`move-down`, `move-top`, `move-up`, `plus-large`, `plus`, `pop-out`, `tally`
(all `-symbolic`). `cross-large-circle-outline-symbolic` is bundled and
referenced nowhere in the Lua.

### `main.c`, `po/` — locale

`setlocale(LC_ALL, "")`, `bindtextdomain("messages", "/app/share/locale")`,
`textdomain("messages")`, `gettext` exposed to Lua as `lib.gettext` and aliased
`_` in both Lua files. 43 msgids in `po/MESSAGES.pot`; catalogues for `fr`,
`id`, `it`. See `translation-parity.md`.

### App metadata and packaging — no port counterpart

Four icon SVGs (`ca.vlacroix.Tally.svg`, `-symbolic.svg` and the two `.Devel`
variants), two `.desktop` files carrying translated `Name`/`Comment`/`Keywords`
for `en`/`fr`/`id`/`it`, two AppStream `metainfo.xml` files with the whole
release history, two Flatpak manifests, `COPYING`, `tally.doap`, `tally.png`
and a GitHub Actions workflow. None of this is a widget; all of it is part of
the app as a user installs it. See `component-parity.md` gaps 1–6.

## Totals

26 components. 20 have a port file opposite them and are compared on all four
axes in `component-parity.md`; 6 (the icons, the desktop entries, the AppStream
metadata, the Flatpak manifests, the licence text and the catalogue build
rules) have none.

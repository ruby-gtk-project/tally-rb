# Component identification — tally / tally-rb

> **Reverified 2026-11-06 @ `0be085f`.** Nothing under `lib/`, `exe/`, `data/`
> or `po/` has changed since this census was written (the only intervening
> commits — `898e703`, `0be085f` — touch gem packaging metadata and
> `component-inventory.md` only; `git diff --stat c95adfa HEAD -- lib exe spec
> test po data` is empty). The 22-port-class / 2-upstream-file census below
> still matches the tree. No new upstream commit either: `origin/trunk` is
> still `e9986b010c950d2df91b682769b744c412348e0c`.

|  |  |
|---|---|
| Upstream | `origin/trunk` @ `e9986b010c950d2df91b682769b744c412348e0c` |
| Port | `ruby` @ `2f14cbbebfa83db2cf8c7349b0be9b108744b353` |
| Upstream declarative UI | **none** — no `.ui`, no `.blp`, no GSettings schema |
| Port declarative UI | none, by design (memoized widget methods) |
| Units | 22 port classes against 2 upstream Lua files + 1 C stub |

## Step 1 — there is no declarative UI on either side

```sh
$ find up -name '*.blp' -o -name '*.ui' -o -name '*gschema*'
$ find lib data -name '*.blp' -o -name '*.ui'
```

Both empty. Upstream builds its whole widget tree imperatively in `main.lua`
(862 lines) and `counter.lua` (510 lines), bootstrapped by `main.c` (134 lines)
which embeds the Lua bytecode with `#embed` and exposes five C functions as the
`mainlib` module. There is no template, so there is no free unit list and no
free CSS/signal map; every row below was recovered by reading.

## Step 2 — the scanner cannot see the upstream side

```sh
$ .claude/skills/component-identification/scripts/component-scan.sh up | wc -l
0
$ .claude/skills/component-identification/scripts/component-scan.sh lib | wc -l
129
```

**The scan returns zero rows for upstream and that is a scanner limit, not an
empty app.** `component-scan.sh` knows Vala, C, Python, GJS, Rust, Ruby,
GtkBuilder XML and blueprint. It does not know Lua, and LuaGObject's spelling
(`Gtk.Button { … }` as a table constructor, `extra_css_classes = { "flat" }`,
`function w.on_notify.active()`) matches none of its patterns. Reported to the
skill; until it is fixed, the upstream inventory here is **censused by hand**
and the port's 129 scan rows are a cross-check, not the join key.

The hand census, for reproducibility:

```sh
grep -oE '\b(Gtk|Adw|Gdk|Gio|GObject)\.[A-Z][A-Za-z0-9_]*' main.lua counter.lua | sort | uniq -c
grep -hoE 'extra_css_classes = \{[^}]*\}|add_css_class *[("]+[a-zA-Z0-9_-]*' main.lua counter.lua
grep -hoE 'on_[a-z_]+|on_notify\["[a-z-]+"\]|on_notify\.[a-z_]+' main.lua counter.lua | sort | uniq -c
grep -nEo '(\b_|lib\.gettext) *"[^"]*"' main.lua counter.lua
```

## Step 3 — the file mapping

Many-to-many in both directions. Upstream splits by *object* (one Lua file per
class), the port by *view*, so `main.lua` fans out to fourteen Ruby files and
three Ruby files each pull from both Lua files.

```
main.c          (lua_get_is_devel, lua_get_app_id, lua_get_app_ver, main())
                                              -> lib/tally/application.rb
                                                 lib/tally/rb/version.rb
                                                 exe/tally
main.c          (lua_gettext, bindtextdomain, textdomain)
                                              -> lib/tally/locale.rb
main.lua        app object, accels, quit action, activate/startup/shutdown
                                              -> lib/tally/application.rb
main.lua        window class, refreshtoolbar, checkbtn/delbtn mode
                                              -> lib/tally/main_window.rb
main.lua        lbox, clamp, biglayout, smalllayout, multi, scrolledwin,
                enlarge, shrink, scrollbottom -> lib/tally/counter_list.rb
main.lua        searchbar, searchentry, searchbox, lbox filter_func
                                              -> lib/tally/search_bar.rb
main.lua        searchcolorbox + its check loop
main.lua        tallycolorbox + newsystemcheckbtn + its check loop
counter.lua     counter:colorrow, counter:gencolorcheck
                                              -> lib/tally/color_selector.rb
main.lua        lib.getcolorname               -> lib/tally/colors.rb
main.lua        statuspage                     -> lib/tally/empty_state.rb
main.lua        window:tallydialog             -> lib/tally/new_counter_dialog.rb
main.lua        tallymenu                      -> lib/tally/main_menu.rb
main.lua        aboutwin                       -> lib/tally/about_dialog.rb
                                                 lib/tally/metainfo.rb
main.lua        newshortcutwindow              -> lib/tally/shortcuts_dialog.rb
main.lua        cssbase/csslight/cssdark + provider swap
                                              -> lib/tally/styles.rb
main.lua        readcfg/writecfg/lib.queuewrite/dir bootstrap
                                              -> lib/tally/store.rb
                                                 lib/tally/lua_config.rb
main.lua        Gio.Resource.load + resource_base_path
data/tally.gresource.xml, Makefile icon install
                                              -> lib/tally/icons.rb
                                                 data/icons/hicolor/**
counter.lua     counter fields, counters, counterrows, serialize, delete
                                              -> lib/tally/counter.rb
counter.lua     counter constructor, read, setcheckmode, DragSource, DropTarget
                                              -> lib/tally/counter_row.rb
counter.lua     counter:createmenu             -> lib/tally/counter_menu.rb
counter.lua     counter:popout                 -> lib/tally/counter_window.rb
counter.lua     counter:duplicate              -> lib/tally/counter_drag_row.rb
```

Port files with no upstream file opposite them: none. `lib/tally/colors.rb`,
`lib/tally/color_selector.rb`, `lib/tally/metainfo.rb` and
`lib/tally/lua_config.rb` are factored-out repeats or readers for data upstream
inlines; each is named above against the upstream block it came from.

## Step 4 — the inventory, in the order a user meets it

### `main.lua` app object + `main.c` — the application

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Application` | 1 | — | `activate`, `startup`, `shutdown` | `application_id` from `-DPACKAGE`, `resource_base_path = /ca/vlacroix/Tally` |
| `Gio.SimpleAction` | 1 | — | `activate` → `app:quit()` | installs `app.quit` |

Accelerators, all four set on the application:
`win.shortcuts`→`<Ctrl><Shift>question`, `win.about`→`F1`,
`win.close`→`<Ctrl>W`, `app.quit`→`<Ctrl>Q`.

`main.c` contributes three compile-time facts (`DEVEL`, `PACKAGE`, `VERSION`)
and one behaviour: when `luaL_loadbuffer` fails, `main()` prints
`gettext("An unrecoverable error occurred when loading Tally, preventing the
program from starting.\n")` to stderr and returns the Lua error code.

Port: `lib/tally/application.rb` (`Gtk::Application` — `Adwaita::Application`
is unusable from Ruby), `exe/tally`, `lib/tally/rb/version.rb`.

### `main.lua` window class — the main window

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (conditional on `-DDEVEL`) | `close_request` | 500×600 default, 360×294 minimum, maximized from config |
| `Adw.ToolbarView` | 1 | — | — | `top_bar_style` swung `FLAT` ↔ `RAISED_BORDER` by `refreshtoolbar`, `enlarge`, `shrink` |
| `Adw.HeaderBar` | 1 | — | — | `title_widget = Adw.WindowTitle.new(_"Tally", "")` |
| `Adw.WindowTitle` | 1 | — | — | |
| `Gtk.Button` | 2 | 2nd: `destructive-action` | `clicked` ×2 | new (`plus-large-symbolic`) and delete (`delete-symbolic`, `visible = false`) |
| `Gtk.ToggleButton` | 2 | — | `notify::active` ×2 | select (`check-round-outline-symbolic`), search (`loupe-large-symbolic`) |
| `Gtk.MenuButton` | 1 | — | — | `menu-large-symbolic`, `menu_model = tallymenu`, `grab_focus` at the end of the constructor |
| `Adw.Breakpoint` | 1 | — | `apply` → `shrink`, `unapply` → `enlarge` | condition `max-width: 400px` |
| `Gio.SimpleAction` | 2 | — | `activate` ×2 | installs `win.shortcuts`, `win.about` |

Repeaters: none. Conditional: `devel`; the delete button visible only in select
mode; the select button hidden when there are no counters.

Behaviour that is not a widget: `refreshtoolbar` swaps the ToolbarView's content
between the list and the status page; the select toggle's `notify::active`
swaps the header-bar buttons and calls `setcheckmode` on every counter; the
delete button walks the counter list in reverse deleting the ticked ones, then
writes the config; `close_request` closes every open pop-out window.

Port: `lib/tally/main_window.rb`.

### `main.lua` lbox / clamp / multi — the counter list

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ScrolledWindow` | 1 | — | — | `hscrollbar_policy = NEVER`; its interposed `GtkViewport` is what `counter:scroll` scrolls |
| `Adw.MultiLayoutView` | 1 | — | — | one slot, `"list"` |
| `Adw.Layout` | 2 | — | — | wide (clamped) and narrow (bare slot) |
| `Adw.LayoutSlot` | 2 | — | — | `"list"`, once per layout |
| `Adw.Clamp` | 1 | — | — | `maximum_size = 600`, margins 24/24/12/12 |
| `Gtk.ListBox` | 1 | `tally-list`, `boxed-list` ↔ `separators` | `row_activated` | `selection_mode = NONE`, `valign = START`, `visible = false` until it has a row; `set_filter_func` |

`enlarge` → wide layout, `boxed-list`, `FLAT`. `shrink` → narrow layout,
`separators`, `RAISED_BORDER`. `window:scrollbottom` drives the vadjustment to
its upper bound after a 20 ms timeout.

Port: `lib/tally/counter_list.rb`.

### `main.lua` searchbar — the filter bar

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.SearchBar` | 1 | — | `notify::search-mode-enabled` | `connect_entry`, `bind_property("search-mode-enabled", searchbtn, "active", BIDIRECTIONAL)`, `key_capture_widget` |
| `Gtk.Box` | 1 | — | — | vertical, spacing 6, margins 6 top/bottom |
| `Gtk.SearchEntry` | 1 | — | `search_changed` | placeholder `_"Filter by name…"` |
| `Gtk.Box` | 1 | `colorselector` | — | horizontal, spacing 6, **no valign** |
| `Gtk.CheckButton` | **7** (repeater) | `system`, `red`, `orange`, `yellow`, `green`, `blue`, `purple` — one each | `notify::active` ×7 (one site) | ungrouped, so any number tick; tooltip from `getcolorname` |

The filter rule: a closed bar filters nothing; an open bar with an empty query
and no colour ticked filters nothing; otherwise a row shows when its colour is
ticked (or none is) and its lowercased name contains the lowercased query as a
plain substring. Toggling search mode clears every colour tick.

Port: `lib/tally/search_bar.rb` + `lib/tally/color_selector.rb` (`mode: :multi`).

### `main.lua` statuspage — the empty state

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.StatusPage` | 1 | — | — | `title = _"No Counters"`, `icon_name = "tally-symbolic"` |
| `Gtk.Button` | 1 | `suggested-action`, `pill` | `clicked` | `label = _"Create Counter"`, margins 40 start/end |

Port: `lib/tally/empty_state.rb`.

### `main.lua` window:tallydialog — the new-counter dialog

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` | 1 | — | — | `title = _"New Counter"`; rebuilt per activation upstream |
| `Adw.ToolbarView` | 1 | — | — | `top_bars = { Adw.HeaderBar() }` |
| `Adw.HeaderBar` | 1 | — | — | |
| `Gtk.Box` | 1 | — | — | vertical, spacing 12, margins 12 |
| `Gtk.Entry` | 1 | `error` (dynamic, while empty) | `changed` | placeholder `_"Name"`, `halign = FILL` |
| `Gtk.Box` | 1 | `colorselector` | — | horizontal, spacing 6, **no valign** |
| `Gtk.CheckButton` | **7** (1 + repeater ×6) | first **unclassed**; then `red`…`purple` | `notify::active` ×7 (two sites) | the six accents are `group`ed onto the first, so exactly one is ever active |
| `Gtk.Button` | 1 | `suggested-action` | `clicked` | `sensitive = false` until named, `halign = CENTER` |
| `Adw.ButtonContent` | 1 | — | — | `plus-large-symbolic`, `label = _"Add to List"` |

Port: `lib/tally/new_counter_dialog.rb` + `lib/tally/color_selector.rb`
(`mode: :radio`).

### `main.lua` tallymenu — the primary menu

A `Gio.Menu` with **two** items and no sections: `_"Keyboard Shortcuts"` →
`win.shortcuts`, `_"About Tally"` → `win.about`. No quit item, although
`<Ctrl>Q` is bound.

Port: `lib/tally/main_menu.rb`.

### `main.lua` aboutwin — the About dialog

One `Adw.AboutDialog`, built once at startup and re-presented. Properties:
`application_icon = app_id`, `application_name = _"Tally"`, `copyright`,
`developer_name`, `issue_url`, `license_type = GPL_3_0`,
`release_notes_version = VERSION`, `translator_credits = _"translator-credits"`,
`version = VERSION`, `website`. Two `add_link` calls:
`_"Translate this app!"` and `_"Support this app!"`. `release_notes` is a
hard-coded, **unmarked** HTML heredoc.

Port: `lib/tally/about_dialog.rb` + `lib/tally/metainfo.rb` (the notes are read
from the AppStream file instead of duplicated).

### `main.lua` newshortcutwindow — the shortcuts window

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ShortcutsWindow` | 1 | — | — | modal, transient for the main window, rebuilt per activation |
| `Gtk.ShortcutsSection` | 1 | — | — | `title = app_title`, an **undefined global** upstream, so nil |
| `Gtk.ShortcutsGroup` | 2 | — | — | `_"Main Window"`, `_"Counter Window"` |
| `Gtk.ShortcutsShortcut` | 5 | — | — | see below |

The five items, with upstream's literal `action_name`:
`_"Quit Application"`/`app.quit`/`<Ctrl>Q`,
`_"Keyboard Shortcuts"`/`win.shortcuts`/`<Ctrl><Shift>question`,
`_"About Tally"`/**`app.about`**/`F1` — a name upstream never registers, so
that row is inert — then in the second group
`_"Quit Application"`/`app.quit`/`<Ctrl>Q` and
`_"Close Window"`/`win.close`/`<Ctrl>W`.

Port: `lib/tally/shortcuts_dialog.rb` (`Adwaita::ShortcutsDialog`; the whole
`Gtk.Shortcuts*` family is deprecated as of GTK 4.18 and has no group level, so
upstream's two groups become two sections).

### `main.lua` styles — the stylesheet

Three CSS strings, no `.css` file: `cssbase` (the colour-selector check buttons
and the pop-out's 300% type), `csslight` and `cssdark` (the per-colour row and
toolbar tints). Two `Gtk.CssProvider`s, base+light and base+dark, added to
`Gdk.Display.get_default()` at priority **1000000** and swapped on
`Adw.StyleManager`'s `notify::dark`.

Classes the stylesheet *defines*: `colorselector`, `system`, `red`, `orange`,
`yellow`, `green`, `blue`, `purple`, `popout`, `tally-list`, and the element
selectors `list`, `row`, `toolbarview`, `checkbutton`, `radio`, `check`,
`checkbox`. Platform classes it only *uses*: `circular`, `boxed-list`,
`separators`, `numeric`, `destructive-action`, `suggested-action`, `pill`,
`devel`, `error`, `spin`, `checked`, `drag-handle`.

Port: `lib/tally/styles.rb` (three heredocs, verbatim).

### `counter.lua` counter constructor — one row in the list

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ExpanderRow` | 1 | `spin`, the colour class (dynamic: `red`…`purple`), `checked` (dynamic, while ticked), `error` (dynamic, while the name is empty) | `notify::expanded` | `title = name`; expanding scrolls the row into view after 50 ms |
| `Gtk.Image` | 1 | `drag-handle` | — | `drag-handle-symbolic`, prefix, hidden in select mode |
| `Gtk.CheckButton` | 1 | — | `notify::active` | prefix, `visible = false`, shown in select mode |
| `Gtk.Label` | 1 | — | — | suffix, `visible = false`, `margin_start = 18`, `halign = END`, shown in select mode |
| `Gtk.SpinButton` | 1 | — | `notify::value` | suffix, range 0–1 000 000 step 1, `valign = CENTER`, first child `xalign = 1`; hidden in select mode |
| `Gtk.DragSource` (controller) | 1 | — | `prepare`, `drag_begin` | on the handle, `actions = MOVE`, `propagation_phase = CAPTURE` |
| `Gtk.DropTarget` (controller) | 1 | — | `drop` | on the row, `actions = MOVE`, `formats` for the `Adw.ExpanderRow` gtype, `preload` |

Also, not widgets: `GObject.Value(Adw.ExpanderRow, row)` wrapped in a
`Gdk.ContentProvider`; a throwaway `Gtk.ListBox` (`tally-list`, `boxed-list`)
holding the drag preview, handed to `Gtk.DragIcon.get_for_drag`; and the suffix
box, reached as `row.child:get_last_child()` and given `hexpand = true` so the
count label hugs the right edge once the spin button hides.

`setcheckmode` is the state swap: handle+spin ↔ check+label, and in select mode
the row is collapsed and `enable_expansion` turned off.

Port: `lib/tally/counter_row.rb` + `lib/tally/counter.rb` (the data half).

### `counter.lua` counter:createmenu — the row's disclosure

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.EntryRow` | 1 | — | `changed` | `title = _"Name"`, `sensitive = not duplicate` |
| `Adw.ActionRow` | 3 | — | — | `_"Color"` (`sensitive = not duplicate`), `_"Reorder in List"`, `_"Show in a Separate Window"` |
| `Gtk.Box` | 1 | — | — | the colour row's selector box, `colorselector`, `valign = CENTER` |
| `Gtk.CheckButton` | **7** (1 + repeater ×6) | first unclassed; then `red`…`purple` | `notify::active` ×7 | radio-grouped onto the first |
| `Gtk.Box` | 1 | — | — | order box, horizontal, spacing 6, `halign = END`, `valign = CENTER` |
| `Gtk.Button` | 4 | — | `clicked` ×4 | `move-top-symbolic`, `move-up-symbolic` (`valign = CENTER`), `move-down-symbolic`, `move-bottom-symbolic`; all `sensitive = not duplicate` |
| `Gtk.Button` | 1 | — | `clicked` | `pop-out-symbolic`, `halign = END`, `hexpand`, `valign = CENTER`, `sensitive = not duplicate` |

`duplicate` is the drag-preview mode: `self.entry` already set means every
control is desensitised and no handler is wired at all.

Up and down skip rows the filter has hidden (`other:get_mapped()`); all four
move the row in the list box *and* the `counters` table, queue a write, and
scroll after 50 ms. Renaming to the empty string adds `error` to the row and
keeps the old name; otherwise it retitles the row and the pop-out window.

Port: `lib/tally/counter_menu.rb` + `lib/tally/color_selector.rb`.

### `counter.lua` counter:popout — the stand-alone counter window

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` — guarded by `is_devel`, which is **not in scope in `counter.lua`**, so upstream never applies it here | `close_request` | `title = name .. " — " .. _"Tally"`, `hide_on_close`, 400×300 default, 360×294 minimum |
| `Adw.ToolbarView` | 1 | the colour class (dynamic) | — | `width_request = 300` |
| `Adw.HeaderBar` | 1 | — | — | |
| `Adw.WindowTitle` | 1 | — | — | `bind_property("text", title, "title", BIDIRECTIONAL)` against the menu's EntryRow |
| `Gtk.WindowHandle` | 1 | — | — | the whole face drags the window |
| `Gtk.Box` | 3 | 2nd: `popout` | — | outer (spacing 36, margins 24, centred), number box (spacing 24), button box (spacing 48) |
| `Gtk.Label` | 1 | `numeric` | — | `width_request = 240`, `halign = CENTER` |
| `Gtk.Button` | 2 | `circular` ×2 | `clicked` ×2 | `minus-symbolic` / `plus-symbolic`, each insensitive at its end of the range |
| `Gio.SimpleAction` | 1 | — | `activate` | installs `win.close` |

**Upstream reassigns `self.spinbtn.on_notify.value` here**, which silently
unhooks the list row's own handler: while a pop-out is open the row's count
label stops updating and edits stop being saved.

Port: `lib/tally/counter_window.rb`.

### `counter.lua` counter:duplicate — the drag preview

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ExpanderRow` | 1 | the colour class (dynamic) | — | `title = name`, `expanded` copied from the real row |
| `Gtk.Image` | 1 | `drag-handle` | — | prefix |
| `Gtk.SpinButton` | 1 | — | — | suffix, same range, value copied, **no valign** |

Plus `createmenu(dragrow)` in duplicate mode.

Port: `lib/tally/counter_drag_row.rb`.

### `main.lua` config section — the store

Not widgets, but behaviour the port owes: `$XDG_CONFIG_HOME/tally/tally`,
written by filling `tallynext` and renaming it over the destination; a leftover
`tallynext` read in preference and skipped if it does not parse; a `tally` path
that exists but is not a directory deleted; writes debounced one second deep by
`lib.queuewrite` with a pending-count trick; geometry read off the window at
write time; `app:on_shutdown` writing unconditionally. The file is Lua source,
`load()`ed.

Port: `lib/tally/store.rb` (JSON) + `lib/tally/lua_config.rb` (a non-evaluating
reader for upstream's grammar, including `%q`'s hex floats and bare booleans).

### `main.lua` GResource + `Makefile` — the icons

`data/tally.gresource.xml` bundles **16** symbolic action icons, registered
from `main.lua` and found under the application's `resource_base_path`. The
Makefile separately installs `icons/$(APPID).svg` and
`icons/$(APPID)-symbolic.svg`.

Port: `lib/tally/icons.rb` + `data/icons/hicolor/**` — all 16 action icons are
byte-identical to upstream's, and all four application icons are present under
the renamed id.

## Repeaters, conditionals and dynamics — the rows a flat scan would lose

| Kind | Where | Multiplicity |
|---|---|---|
| Repeater | search-bar colour checks | 7 (`system` + 6 accents), one `notify::active` site |
| Repeater | new-counter dialog colour checks | 7 (unclassed + 6 accents), two sites |
| Repeater | `counter:colorrow` colour checks | 7, per row *and again* per drag preview |
| Repeater | counter rows in the list | N, driven by the `counters` table |
| Repeater | `Gtk.ShortcutsShortcut` | 5 across 2 groups |
| Conditional | `devel` class | `-DDEVEL` at compile time |
| Conditional | delete button | select mode only |
| Conditional | select button | only when counters exist |
| Conditional | list box visibility | only when it has a row |
| Conditional | `duplicate` menu | drag preview only — every control desensitised |
| Dynamic CSS | row / toolbar colour | one of `red`, `orange`, `yellow`, `green`, `blue`, `purple`, or none |
| Dynamic CSS | `checked` | while a row is ticked |
| Dynamic CSS | `error` | on the entry while the new-counter name is empty; on the row while a rename is empty |
| Dynamic CSS | `boxed-list` ↔ `separators` | breakpoint |
| Shared factory | `counter:gencolorcheck` | one definition, 7 call sites per selector, 3 selectors |
| Actions from no literal | none — all four are literal `Gio.SimpleAction.new` names | |

## Totals

| Axis | Upstream (hand census) | Port | Note |
|---|---:|---:|---|
| Distinct widget types | — | — | the same set, type by type, in the tables above, with one substitution: `Gtk.ShortcutsWindow`/`Section`/`Group`/`Shortcut` → `Adwaita::ShortcutsDialog`/`Section`/`Item` (and `Adw.Application` → `Gtk::Application`) |
| Distinct CSS classes attached | 22 | 22 | 15 literals + the 7-member colour family; identical sets |
| Distinct signals | 18 | 18 | identical sets |
| Actions installed | 4 | 4 | `app.quit`, `win.shortcuts`, `win.about`, `win.close` |
| Accelerators | 4 | 4 | identical |
| Distinct msgids | 41 in code, +23 in metadata | 41 + 23 | identical sets, byte for byte |

The four-axis comparison is `.reports/component-parity.md`.

## Reverified 2026-11-07 @ `f3f4911`

Re-checked in this session, not transcribed: `git diff --stat c95adfa HEAD --
lib exe` is empty, so every widget/signal/action/CSS-class table above still
describes the tree at HEAD unchanged. The only commits since `c95adfa`
(`898e703`, `0be085f`, `81e08b3`, `f3f4911`) touch gem-packaging metadata, the
parity reports themselves, and `data/*.desktop`+`data/*.metainfo.xml` plus
`po/`, `rakelib/gettext.rake` and `spec/tally/metainfo_spec.rb` — none of
which this report's 22-port-class / 2-upstream-Lua-file + 1-C-stub census
covers. `origin/trunk` is unchanged (`e9986b0`). No new widget, signal,
action, accelerator or CSS class exists on either side; the totals table is
unchanged. Unit 22 (project metadata) in `component-parity.md` is the table
affected by `f3f4911`, and that report's own reverification note covers it.

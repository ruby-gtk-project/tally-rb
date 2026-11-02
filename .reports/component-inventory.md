# Component inventory — tally → tally-rb

|  |  |
|---|---|
| Upstream | `origin/trunk` @ `e9986b010c950d2df91b682769b744c412348e0c` ("tally: Archive repository") |
| Port | `ruby` @ `7a60af7` |
| Scope | whole app (opening survey): `main.lua` 862 lines, `counter.lua` 510, `main.c` 134; port is 3,762 lines of Ruby across 24 files |
| Verdict | every user-facing component has a port file; the open gaps are non-widget (packaging, project metadata, one `valign`, no run against upstream) |

## Step 1 — declarative UI: there is none

```
$ git ls-tree -r --name-only origin/trunk | grep -E '\.(ui|blp)$'   → nothing
$ git ls-tree -r --name-only origin/trunk | grep -iE 'gschema'      → nothing
```

Upstream is Lua against GTK4/libadwaita through LuaGObject, building every
widget imperatively from constructor tables (`Adw.HeaderBar { title_widget = … }`).
There is no GtkBuilder XML, no blueprint, **no GSettings schema** — window
geometry and the counters themselves are persisted to a hand-written Lua table
at `$XDG_CONFIG_HOME/tally/tally`. The only declarative data files are:

| File | What it contributes |
|---|---|
| `data/tally.gresource.xml` | 16 symbolic action icons, registered at startup under `/ca/vlacroix/Tally` |
| `ca.vlacroix.Tally{,.Devel}.desktop` | desktop entries, translated Name/Comment/Keywords |
| `ca.vlacroix.Tally{,.Devel}.metainfo.xml` | AppStream, 15 releases |
| `po/MESSAGES.pot` + `po/{fr,id,it}.po` | 41 translatable strings, domain `messages` |
| `ca.vlacroix.Tally{,.Devel}.json` | Flatpak manifests — **not ported** |

The port has no `.ui`/`.blp` either, by house-style design (memoized accessors).
So Step 1 contributes no inventory and everything below was read out of the two
Lua files and the port's `lib/`.

## Step 2–3 — the scan, and a scanner defect to report

`component-scan.sh` matches `.ui .blp .vala .c .h .py .js .ts .rs .rb` and
**not `.lua`**, so upstream as shipped scans to zero rows — a reviewer trusting
that result concludes there is no spec. Workaround used here and previously:
copy `main.lua`/`counter.lua` to `.rb` and scan that (57 rows; the Ruby patterns
catch `Adw.Foo {}` tables but not Lua's parenthesis-free `add_css_class "spin"`,
so the upstream CSS stream is empty and every CSS class below was read by hand).
The port side scans to 129 rows and over-reports: type names inside doc comments
(`Adw.AboutDialog` in `metainfo.rb`, `Gtk.SpinButton` in `lua_config.rb`,
`Gtk.ListBoxRow` in `counter.rb`, `Gtk.InitError` in `rb.rb`) are prose, not
widgets. Both numbers are leads only.

## Step 4 — the component list

One row per user-facing component, in the order a user meets it. Upstream splits
by *object*, not by view, so several rows are many-to-one in both directions.

| # | Upstream | → `lib/*.rb` | Kind | Exists |
|---:|---|---|---|---|
| 1 | `main.lua` app object (accels, `app.quit`, `activate`/`startup`/`shutdown`) + `main.c` `lua_get_is_devel`/`_app_id`/`_app_ver` | `lib/tally/application.rb` | application | yes |
| 2 | `main.lua` `window` class, `refreshtoolbar`, check/delete mode, breakpoint, `win.shortcuts`/`win.about` | `lib/tally/main_window.rb` | window | yes |
| 3 | `main.lua` `lbox`/`clamp`/`multi`/`scrolledwin`, `enlarge`, `shrink`, `scrollbottom` | `lib/tally/counter_list.rb` | list view | yes |
| 4 | `counter.lua` `counter` constructor, `read`, `setcheckmode`, drag source/target | `lib/tally/counter_row.rb` | row | yes |
| 5 | `counter.lua` `counter:createmenu` (4 disclosure rows) | `lib/tally/counter_menu.rb` | row group | yes |
| 6 | `counter.lua` `counter:duplicate` | `lib/tally/counter_drag_row.rb` | drag preview row | yes |
| 7 | `counter.lua` `counter:colorrow`/`gencolorcheck` + `main.lua` `searchcolorbox` + `tallycolorbox` | `lib/tally/color_selector.rb` | control | yes (one gap: `valign`) |
| 8 | `main.lua` searchbar block (bar, entry, colour checks, filter predicate) | `lib/tally/search_bar.rb` | search bar | yes |
| 9 | `main.lua` `statuspage` | `lib/tally/empty_state.rb` | empty state | yes |
| 10 | `main.lua` `window:tallydialog` | `lib/tally/new_counter_dialog.rb` | dialog | yes |
| 11 | `counter.lua` `counter:popout` (+ `win.close`) | `lib/tally/counter_window.rb` | window | yes |
| 12 | `main.lua` `tallymenu` | `lib/tally/main_menu.rb` | menu model | yes |
| 13 | `main.lua` `newshortcutwindow` | `lib/tally/shortcuts_dialog.rb` | keyboard shortcuts | yes (re-expressed on `Adw.Shortcuts*`) |
| 14 | `main.lua` `aboutwin` | `lib/tally/about_dialog.rb` | dialog | yes |
| 15 | `main.lua` `cssbase`/`csslight`/`cssdark` + provider swap on `notify::dark` | `lib/tally/styles.rb` | stylesheet | yes |
| 16 | `counter.lua` `counter` fields, `counters`, `counterrows`, `serialize`, `delete` | `lib/tally/counter.rb` | model | yes |
| 17 | `main.lua` `readcfg`/`writecfg`/`lib.queuewrite` + dir bootstrap | `lib/tally/store.rb`, `lib/tally/lua_config.rb` | config backend | yes |
| 18 | `main.lua` `lib.getcolorname` + the colour vocabulary repeated in 4 places | `lib/tally/colors.rb` | catalogue | yes |
| 19 | `main.c` `lua_gettext`, `bindtextdomain`, `textdomain` + `po/` | `lib/tally/locale.rb`, `po/{MESSAGES.pot,fr,id,it}` | i18n | yes |
| 20 | `data/tally.gresource.xml` + GResource load + `Makefile` icon install | `lib/tally/icons.rb`, `data/icons/hicolor/**` | asset bundle | yes |
| 21 | `aboutwin.release_notes` heredoc + `ca.vlacroix.Tally.metainfo.xml` `<releases>` | `lib/tally/metainfo.rb`, `data/org.rubygtkproject.Tally{,.Devel}.metainfo.xml` | AppStream reader | yes |
| 22 | `ca.vlacroix.Tally{,.Devel}.desktop` | `data/org.rubygtkproject.Tally{,.Devel}.desktop` | desktop entry | yes |
| 23 | `main.c` `main()` load-failure branch (`"An unrecoverable error occurred…"`) | — | error state | **no** |
| 24 | `ca.vlacroix.Tally{,.Devel}.json` | — | Flatpak manifest | **no** |
| 25 | `.github/workflows/ci.yml` (flatpak-builder) | — | CI | **no** |
| 26 | `tally.doap` | — | project metadata | **no** |
| 27 | `tally.png` (README screenshot) | — | asset | **no** |

Rows 1–22 are the whole user-facing app, and all 22 have a port file.
Rows 23–27 are what makes upstream an *installed application*; 23 is the only
one that is user-facing, and it is a single translated stderr line.

## Step 5 — the inventory

`×` is live instances, not textual occurrences: a widget from a shared factory
is counted at its call sites.

### 1 · `main.lua` window class → `lib/tally/main_window.rb` — the one main window

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (devel build only) | `close-request` → closes every open pop-out | 500×600 default, 360×294 minimum; geometry restored from the config |
| `Adw.ToolbarView` | 1 | — | — | `top_bar_style` flipped `FLAT` ⇄ `RAISED_BORDER` by both `refreshtoolbar` and the breakpoint; `content` swapped between the list and the empty state |
| `Adw.HeaderBar` | 1 | — | — | holds all five buttons |
| `Adw.WindowTitle` | 1 | — | — | `("Tally", "")` |
| `Gtk.Button` (new) | 1 | — | `clicked` → new-counter dialog | tooltip "Create a new counter"; hidden in select mode |
| `Gtk.Button` (delete) | 1 | `destructive-action` | `clicked` → deletes every ticked counter, writes, leaves select mode | starts `visible = false` |
| `Gtk.ToggleButton` (select) | 1 | — | `notify::active` → swaps header bar + every row into check mode | tooltip changes with state; hidden while the list is empty |
| `Gtk.ToggleButton` (search) | 1 | — | bound `BIDIRECTIONAL` to the search bar's `search-mode-enabled` | — |
| `Gtk.MenuButton` | 1 | — | — | `menu_model` = `tallymenu`; grabs focus at the end of construction |
| `Adw.Breakpoint` | 1 | — | `apply` → shrink, `unapply` → enlarge | `max-width: 400px` |
| `Gio.SimpleAction` `win.shortcuts` | 1 | — | `activate` | `<Ctrl><Shift>question` |
| `Gio.SimpleAction` `win.about` | 1 | — | `activate` | `F1` |

Repeaters: none. Conditional: the `devel` class, the delete button's visibility,
the select button's visibility, the toolbar content.

### 2 · `main.lua` list block → `lib/tally/counter_list.rb` — the scrolling list

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ScrolledWindow` | 1 | — | — | `hscrollbar_policy = NEVER`; the interposed `Gtk.Viewport` is what `scroll_to` is called on |
| `Adw.MultiLayoutView` | 1 | — | — | one slot `list`, two layouts |
| `Adw.Layout` | 2 | — | — | wide (slot inside the clamp) and narrow (bare slot) |
| `Adw.LayoutSlot` | 2 | — | — | both named `list` |
| `Adw.Clamp` | 1 | — | — | `maximum_size = 600`, margins 24/24/12/12 |
| `Gtk.ListBox` | 1 | `tally-list`; `boxed-list` ⇄ `separators` swapped by the breakpoint | `row-activated` → ticks the row while in select mode | `selection_mode = NONE`, `valign = START`, hidden while empty, custom filter func |

Repeaters: one row per counter. Conditional: `boxed-list`/`separators`; the box
hidden at zero rows.

### 3 · `counter.lua` constructor → `lib/tally/counter_row.rb` — one counter

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ExpanderRow` | 1 | `spin`; one of `red`/`orange`/`yellow`/`green`/`blue`/`purple` (dynamic, swapped on recolour); `checked` while ticked; `error` while the name is empty | `notify::expanded` → scroll into view after 50 ms | `enable_expansion = false` in select mode |
| `Gtk.Image` (drag handle) | 1 | `drag-handle` | — | prefix; hidden in select mode |
| `Gtk.CheckButton` | 1 | — | `notify::active` → sets `checked`, toggles the `checked` class | prefix; hidden outside select mode |
| `Gtk.Label` (count) | 1 | — | — | suffix, `margin_start = 18`, `halign = END`; visible only in select mode |
| `Gtk.SpinButton` | 1 | — | `notify::value` → updates the counter, queues a save | suffix; range 0–1,000,000 step 1; its `GtkText` child is `xalign = 1` |
| `Gtk.DragSource` (controller) | 1 | — | `prepare`, `drag-begin` | on the handle, `CAPTURE` phase, `MOVE` |
| `Gtk.DropTarget` (controller) | 1 | — | `drop` → reorders both the list box and the counter order, queues a save | on the row, `MOVE`, `preload`, gtype `Adw.ExpanderRow` |
| `Gtk.DragIcon` | 1 | — | — | hosts the preview |
| `Gtk.ListBox` (preview host) | 1 | `tally-list`, `boxed-list` | — | throwaway, sized to the row's allocation, drag-highlighted |

### 4 · `counter:createmenu` → `lib/tally/counter_menu.rb` — the disclosure

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.EntryRow` (Name) | 1 | — | `changed` → renames row, pop-out title and model, or marks the row `error` when emptied | desensitised in the drag preview |
| `Adw.ActionRow` (Color) | 1 | — | — | suffix is a radio `ColorSelector` |
| `Adw.ActionRow` (Reorder in List) | 1 | — | — | suffix is the order box |
| `Adw.ActionRow` (Show in a Separate Window) | 1 | — | — | suffix is the pop-out button |
| `Gtk.Box` (order box) | 1 | — | — | horizontal, spacing 6, `halign END`, `valign CENTER` |
| `Gtk.Button` (top/up/down/bottom) | 4 | — | `clicked` → moves the counter, skipping filter-hidden rows, then scrolls after 50 ms | one shared factory, four call sites |
| `Gtk.Button` (pop-out) | 1 | — | `clicked` → presents the counter's own window | `halign END`, `hexpand`, `valign CENTER` |

Every control is desensitised when the menu is built onto a drag preview, and
nothing is connected in that case.

### 5 · `counter:duplicate` → `lib/tally/counter_drag_row.rb` — the drag preview

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ExpanderRow` | 1 | the counter's colour class | — | same title, same expanded state |
| `Gtk.Image` | 1 | `drag-handle` | — | prefix |
| `Gtk.SpinButton` | 1 | — | — | suffix, same value, no handler |

### 6 · three upstream sites → `lib/tally/color_selector.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` | 1 per site | `colorselector` | — | horizontal, spacing 6; sites are the search bar, the new-counter dialog, the Color row |
| `Gtk.CheckButton` | 7 per site | `system` (search bar only), `red`/`orange`/`yellow`/`green`/`blue`/`purple` | `notify::active` | tooltip is the translated colour name; grouped onto the first button in radio mode, ungrouped (multi) in the search bar |

Repeater: a loop over `[system, red, orange, yellow, green, blue, purple]`.
**Gap:** the port sets `valign = :center` on the box at all three sites;
upstream sets it only in `counter:colorrow`, leaving the search bar's and the
dialog's boxes at the default `FILL`.

### 7 · `main.lua` searchbar block → `lib/tally/search_bar.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.SearchBar` | 1 | — | `notify::search-mode-enabled` → clears every colour tick | `connect_entry`, `key_capture_widget`, bound to the header's search toggle |
| `Gtk.Box` | 1 | — | — | vertical, spacing 6, 6px top/bottom margins |
| `Gtk.SearchEntry` | 1 | — | `search-changed` → invalidates the list filter | placeholder "Filter by name…" |
| `ColorSelector` (multi) | 1 | `colorselector` | `notify::active` → invalidates the filter | see above |

Filter rule, kept exactly: bar closed → everything; bar open with empty query
and no colour ticked → everything; otherwise a row shows when its colour is
ticked (or nothing is) **and** its lowercased name contains the query.

### 8 · `main.lua` statuspage → `lib/tally/empty_state.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.StatusPage` | 1 | — | — | title "No Counters", icon `tally-symbolic` |
| `Gtk.Button` | 1 | `suggested-action`, `pill` | `clicked` → new-counter dialog | 40px side margins |

### 9 · `window:tallydialog` → `lib/tally/new_counter_dialog.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` | 1 | — | — | title "New Counter" |
| `Adw.ToolbarView` | 1 | — | — | — |
| `Adw.HeaderBar` | 1 | — | — | no title widget |
| `Gtk.Box` | 1 | — | — | vertical, spacing 12, 12px margins |
| `Gtk.Entry` | 1 | `error` while empty (dynamic) | `changed` → validates | placeholder "Name", `halign FILL` |
| `ColorSelector` (radio) | 1 | `colorselector` | — | see above |
| `Gtk.Button` | 1 | `suggested-action` | `clicked` → creates, appends, scrolls to bottom, focuses the row, closes | `halign CENTER`, starts insensitive |
| `Adw.ButtonContent` | 1 | — | — | icon `plus-large-symbolic`, label "Add to List" |

### 10 · `counter:popout` → `lib/tally/counter_window.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (devel build only) | `close-request` → destroys and forgets the window | 400×300 default, 360×294 minimum, `hide_on_close` |
| `Adw.ToolbarView` | 1 | the counter's colour class (dynamic) | — | `width_request = 300` |
| `Adw.HeaderBar` | 1 | — | — | — |
| `Adw.WindowTitle` | 1 | — | — | `title` bound `BIDIRECTIONAL` to the row's Name entry; subtitle "Tally" |
| `Gtk.WindowHandle` | 1 | — | — | the whole face drags the window |
| `Gtk.Box` (outer) | 1 | — | — | vertical, spacing 36, 24px margins, centred |
| `Gtk.Box` (numbers) | 1 | `popout` | — | vertical, spacing 24 — this is what scales the type to 300% |
| `Gtk.Label` | 1 | `numeric` | — | `width_request = 240`, centred |
| `Gtk.Box` (buttons) | 1 | — | — | horizontal, spacing 48, centred |
| `Gtk.Button` (−) | 1 | `circular` | `clicked` → decrements | insensitive at 0 |
| `Gtk.Button` (+) | 1 | `circular` | `clicked` → increments | insensitive at 1,000,000 |
| `Gio.SimpleAction` `win.close` | 1 | — | `activate` | `<Ctrl>W` |

### 11 · `tallymenu` → `lib/tally/main_menu.rb`

Two `Gio.Menu` items: "Keyboard Shortcuts" → `win.shortcuts`, "About Tally" →
`win.about`. No quit item, although `<Ctrl>Q` is bound to `app.quit`.

### 12 · `newshortcutwindow` → `lib/tally/shortcuts_dialog.rb`

Upstream: one `Gtk.ShortcutsWindow`, one `Gtk.ShortcutsSection`, two
`Gtk.ShortcutsGroup`, five `Gtk.ShortcutsShortcut`:

| Group | Title | action_name | Accelerator |
|---|---|---|---|
| Main Window | Quit Application | `app.quit` | `<Ctrl>Q` |
| Main Window | Keyboard Shortcuts | `win.shortcuts` | `<Ctrl><Shift>question` |
| Main Window | About Tally | `app.about` | `F1` |
| Counter Window | Quit Application | `app.quit` | `<Ctrl>Q` |
| Counter Window | Close Window | `win.close` | `<Ctrl>W` |

The `Gtk.Shortcuts*` family was deprecated in GTK 4.18, so the port uses
`Adw.ShortcutsDialog` + two `Adw.ShortcutsSection` (which has no group level) —
the only widget-type divergence in the whole app, and it is a deliberate one.

Two upstream defects, recorded because the port must decide about each:

- `shortsection.title = app_title` reads a **nil global** — upstream's section is untitled.
- `app.about` names **no registered action**; the real action is `win.about`, so upstream's About row is inert.

### 13 · `aboutwin` → `lib/tally/about_dialog.rb`

One `Adw.AboutDialog` built at startup and re-presented; `application_icon`,
`application_name`, copyright, `developer_name`, `issue_url`, `license_type =
GPL_3_0`, `release_notes_version`, `translator_credits`, `version`, `website`,
plus two `add_link` entries ("Translate this app!", "Support this app!") and a
markup `release_notes` paragraph. The port reads the notes out of the AppStream
file rather than duplicating upstream's heredoc.

### 14 · app object + `main.c` → `lib/tally/application.rb`

| Thing | Value |
|---|---|
| Application | `Adw.Application`, `resource_base_path = /ca/vlacroix/Tally` |
| Accelerators | `win.shortcuts` `<Ctrl><Shift>question`; `win.about` `F1`; `win.close` `<Ctrl>W`; `app.quit` `<Ctrl>Q` |
| Actions | `app.quit` |
| Signals | `activate` (present the existing window), `startup` (build and present), `shutdown` (write the config) |
| From `main.c` | `is_devel`, app id, app version |
| **Not ported** | `main()`'s load-failure message on stderr |

### 15 · styles → `lib/tally/styles.rb`

Two `Gtk.CssProvider`s (base+light, base+dark) added to the default display at
priority 1,000,000 and swapped on `Adw.StyleManager::notify::dark`.

App-defined classes: `colorselector`, `system`, `red`, `orange`, `yellow`,
`green`, `blue`, `purple`, `tally-list`, `popout`.

Classes attached but supplied by the platform: `boxed-list`, `separators`,
`spin`, `checked`, `error`, `drag-handle`, `circular`, `numeric`, `pill`,
`suggested-action`, `destructive-action`, `devel`.

### 16 · config backend → `lib/tally/store.rb` + `lib/tally/lua_config.rb`

`readcfg`/`writecfg`/`lib.queuewrite` and the directory bootstrap: width,
height, maximized and one serialised table per counter, written to
`tally/tallynext` then renamed over `tally/tally`, debounced 1 s. The port
writes JSON (running `load()` over a file in `$HOME` is arbitrary code
execution) and keeps `lua_config.rb` as a non-evaluating reader so an existing
user's counters still import.

### Non-widget components

| Component | Upstream | Port |
|---|---|---|
| Icon bundle (16 symbolic action icons) | `data/tally.gresource.xml` + GResource load | `lib/tally/icons.rb` + `data/icons/hicolor/scalable/actions` |
| Application icon, 4 variants | `icons/*.svg` + `Makefile install` | `data/icons/hicolor/{scalable,symbolic}/apps` + `flake.nix` |
| Desktop entry ×2 | `ca.vlacroix.Tally{,.Devel}.desktop` | `data/org.rubygtkproject.Tally{,.Devel}.desktop` |
| AppStream ×2, 15 releases | `ca.vlacroix.Tally{,.Devel}.metainfo.xml` | `data/org.rubygtkproject.Tally{,.Devel}.metainfo.xml` |
| Catalogues (41 msgids, domain `messages`) | `po/{fr,id,it}.po` + `.pot` | the same four |
| Install / build | `Makefile` | `flake.nix`, `rakelib/gettext.rake`, the gemspec |
| **Flatpak manifest ×2** | `ca.vlacroix.Tally{,.Devel}.json` | **absent** |
| **CI that builds it** | `.github/workflows/ci.yml` | **absent** |
| **Project metadata** | `tally.doap` | **absent** |
| **README screenshot** | `tally.png` | **absent** |

## Totals

| Axis | Upstream distinct | Port distinct | In upstream, not in the port |
|---|---:|---:|---:|
| User-facing components | 22 | 22 | 0 |
| Widget types | 30 | 29 | 4 (`Gtk.ShortcutsWindow`/`Section`/`Group`/`Shortcut`, replaced by `Adw.Shortcuts*`) |
| App-defined CSS classes | 10 | 10 | 0 |
| Platform CSS classes attached | 12 | 12 | 0 |
| Signals | 18 | 18 | 0 |
| Actions | 4 | 4 | 0 |
| Non-widget components | 10 | 6 | 4 |

## What is left

No port file has to be created for a widget. What is open:

1. **Flatpak manifests and the CI that builds them** — upstream's only shipping path.
2. **`main.c`'s load-failure message** — the one user-facing component with no port file.
3. **`tally.doap`, `tally.png`** — project metadata and the README screenshot.
4. **`ColorSelector`'s `valign`** — centred at all three sites; upstream centres only the Color row's.
5. **Nothing has been driven side by side with upstream running**, which is blocked on 1.

The unit-by-unit comparison and the verdict live in `.reports/component-parity.md`.

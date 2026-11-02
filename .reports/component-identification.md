# Component identification — tally / tally-rb

|  |  |
|---|---|
| Upstream | `origin/trunk` @ `e9986b010c950d2df91b682769b744c412348e0c` ("tally: Archive repository") |
| Port | `ruby` @ `0dfc40d8db4335c55114b631c8228a60ec804a0f` |
| Scope | whole app — upstream is 862 lines of Lua in `main.lua`, 510 in `counter.lua`, 134 of C in `main.c`; the port is 3,749 lines of Ruby across 24 files |

## Step 1 — declarative UI

There is none, on either side.

```
$ git ls-tree -r --name-only origin/trunk | grep -E '\.(ui|blp)$'
(nothing)
$ find . -name '*.ui' -o -name '*.blp'
(nothing)
```

Upstream is LuaGObject constructing every widget in code through constructor
tables (`Adw.HeaderBar { title_widget = … }`). `main.c` is an entry stub that
embeds Lua bytecode, binds `gettext(3)` and reports the `-DDEVEL` compile flag.
There is no GtkBuilder XML, no blueprint, no GSettings schema. The port has
none either, by house-style design — widgets are memoized accessors.

So Step 1 contributes nothing and the whole inventory below was recovered by
reading both trees, with the scan as a lead.

## Step 2–3 — the scan, and the scanner defect it exposed

`component-scan.sh` matches `.ui .blp .vala .c .h .py .js .ts .rs .rb`. **It
does not read `.lua`**, so the upstream tree as shipped produces zero rows:

```
$ .claude/skills/component-identification/scripts/component-scan.sh <upstream> | wc -l
0
```

Report this to the skill: a Lua/LuaGObject upstream is invisible to the
scanner, and a reviewer who trusts the empty result concludes the port has no
upstream to be measured against. The workaround used here is to copy
`main.lua` → `main.rb` and `counter.lua` → `counter.rb` and scan that; the
Ruby patterns catch LuaGObject's `Adw.Foo {}` tables, which gives 57 rows.
It does **not** catch Lua's parenthesis-free `add_css_class "spin"`, so the
CSS stream is empty on the upstream side and every CSS row below was read by
hand out of the two Lua files.

```
$ scan <upstream-as-rb> | wc -l   57
$ scan <port>           | wc -l  129
```

Both numbers are leads. The port side over-reports, because the scanner
matches type names inside doc comments: `Adw.AboutDialog × 1` in
`lib/tally/metainfo.rb`, `Gtk.SpinButton × 1` in `lib/tally/lua_config.rb` and
`Gtk.ListBoxRow × 1` in `lib/tally/counter.rb` are all prose, not widgets, and
are struck below. `Gtk.InitError × 1` in `lib/tally/rb.rb` is an exception
class named in a comment, and `Gtk.DragIcon × 3` in `lib/tally/counter_row.rb`
is one real call behind a `respond_to?` binding-compatibility branch.

## Step 4 — the file mapping

Upstream splits the app across two Lua files by *object*, not by view, so the
mapping is many-to-many and is the thing to get right before any comparison.

| Upstream | → | Port |
|---|---|---|
| `main.c` (`lua_gettext`, `bindtextdomain`, `textdomain`) | → | `lib/tally/locale.rb` |
| `main.c` (`lua_get_is_devel`, `lua_get_app_id`, `lua_get_app_ver`) | → | `lib/tally/application.rb`, `lib/tally/metainfo.rb` |
| `main.c` (`main()`'s load-failure branch) | → | **nothing** |
| `main.lua` app object, accels, `quit` action, `on_activate`/`on_startup`/`on_shutdown` | → | `lib/tally/application.rb` |
| `main.lua` GResource load + `data/tally.gresource.xml` + `Makefile` icon install | → | `lib/tally/icons.rb`, `data/icons/hicolor/**` |
| `main.lua` `aboutwin` | → | `lib/tally/about_dialog.rb` |
| `main.lua` `newshortcutwindow` | → | `lib/tally/shortcuts_dialog.rb` |
| `main.lua` `tallymenu` | → | `lib/tally/main_menu.rb` |
| `main.lua` `window` class, `refreshtoolbar`, check/delete mode | → | `lib/tally/main_window.rb` |
| `main.lua` `lbox` / `clamp` / `multi` / `scrolledwin`, `enlarge`, `shrink`, `scrollbottom` | → | `lib/tally/counter_list.rb` |
| `main.lua` searchbar block | → | `lib/tally/search_bar.rb` |
| `main.lua` `statuspage` | → | `lib/tally/empty_state.rb` |
| `main.lua` `window:tallydialog` | → | `lib/tally/new_counter_dialog.rb` |
| `main.lua` `readcfg`/`writecfg`/`lib.queuewrite`/dir bootstrap | → | `lib/tally/store.rb`, `lib/tally/lua_config.rb` |
| `main.lua` `lib.getcolorname` + the colour vocabulary repeated in 4 places | → | `lib/tally/colors.rb` |
| `main.lua` searchbar colour box + dialog colour box + `counter:colorrow`/`gencolorcheck` | → | `lib/tally/color_selector.rb` |
| `main.lua` `cssbase`/`csslight`/`cssdark` + provider swap | → | `lib/tally/styles.rb` |
| `counter.lua` `counter` fields, `counters`, `counterrows`, `serialize`, `delete` | → | `lib/tally/counter.rb` |
| `counter.lua` `counter` constructor, `read`, `setcheckmode`, drag source/target | → | `lib/tally/counter_row.rb` |
| `counter.lua` `counter:createmenu` | → | `lib/tally/counter_menu.rb` |
| `counter.lua` `counter:popout` | → | `lib/tally/counter_window.rb` |
| `counter.lua` `counter:duplicate` | → | `lib/tally/counter_drag_row.rb` |
| `ca.vlacroix.Tally.metainfo.xml` (+ `.Devel`) | → | `data/org.rubygtkproject.Tally.metainfo.xml` (+ `.Devel`) |
| `ca.vlacroix.Tally.desktop` (+ `.Devel`) | → | `data/org.rubygtkproject.Tally.desktop` (+ `.Devel`) |
| `icons/ca.vlacroix.Tally{,.Devel}{,-symbolic}.svg` | → | `data/icons/hicolor/{scalable,symbolic}/apps/org.rubygtkproject.Tally*.svg` |
| `po/{fr,id,it}.po`, `po/MESSAGES.pot` | → | `po/{fr,id,it}.po`, `po/MESSAGES.pot` |
| `Makefile` (`install`, `.mo` build, `pot`/`po` rules) | → | `flake.nix` install phase, `rakelib/gettext.rake` |
| `ca.vlacroix.Tally.json`, `ca.vlacroix.Tally.Devel.json` | → | **nothing** |
| `.github/workflows/ci.yml` (flatpak-builder) | → | **nothing** |
| `tally.doap` | → | **nothing** |
| `tally.png` | → | **nothing** |

Four upstream files have nothing opposite them. They are carried into
`component-parity.md` as gaps, not noted here and forgotten.

---

## The inventory

Ordered the way a user meets the app: the window, its list, its rows, then the
dialogs. `×` is the number of live instances, not textual occurrences — a
widget built by a shared factory or in a loop is counted at its call sites.

### `main.lua` window class → `lib/tally/main_window.rb` — the one and only main window

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (only on a devel build) | `close-request` | 500×600 default, 360×294 minimum; geometry restored from the config |
| `Adw.ToolbarView` | 1 | — | — | `top_bar_style` flipped between `FLAT` and `RAISED_BORDER` by `refreshtoolbar` *and* by the breakpoint |
| `Adw.HeaderBar` | 1 | — | — | holds all five buttons |
| `Adw.WindowTitle` | 1 | — | — | `("Tally", "")` |
| `Gtk.Button` (new) | 1 | — | `clicked` → opens the new-counter dialog | hidden in select mode |
| `Gtk.Button` (delete) | 1 | `destructive-action` | `clicked` → deletes every ticked counter, writes, leaves select mode | starts `visible = false` |
| `Gtk.ToggleButton` (select) | 1 | — | `notify::active` → swaps the header bar and every row | tooltip changes with state; hidden when the list is empty |
| `Gtk.ToggleButton` (search) | 1 | — | bound bidirectionally to the search bar's `search-mode-enabled` | — |
| `Gtk.MenuButton` | 1 | — | — | `menu_model` = the two-item `tallymenu`; grabs focus at the end of construction |
| `Adw.Breakpoint` | 1 | — | `apply` → shrink, `unapply` → enlarge | `max-width: 400px` |
| `Gio.SimpleAction` `win.shortcuts` | 1 | — | `activate` | `<Ctrl><Shift>question` |
| `Gio.SimpleAction` `win.about` | 1 | — | `activate` | `F1` |

Repeaters: none. Conditional: the `devel` class; the delete button's
visibility; the select button's visibility.

### `main.lua` list block → `lib/tally/counter_list.rb` — the scrolling counter list

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ScrolledWindow` | 1 | — | — | `hscrollbar_policy = NEVER`; its interposed `Gtk.Viewport` is what `scroll_to` is called on |
| `Adw.MultiLayoutView` | 1 | — | — | one slot named `list`, two layouts |
| `Adw.Layout` (wide) | 1 | — | — | wraps the slot in the clamp |
| `Adw.Layout` (narrow) | 1 | — | — | the bare slot |
| `Adw.LayoutSlot` | 2 | — | — | one per layout, both named `list` |
| `Adw.Clamp` | 1 | — | — | `maximum_size = 600`, margins 24/24/12/12 |
| `Gtk.ListBox` | 1 | `tally-list`, and `boxed-list` ⇄ `separators` swapped by the breakpoint | `row-activated` → ticks the row in select mode | `selection_mode = NONE`, `valign = START`, hidden while empty, custom filter func |

Repeaters: the rows, one `CounterRow` per counter.
Conditional: `boxed-list`/`separators` by layout; the whole box hidden at zero rows.

### `counter.lua` constructor → `lib/tally/counter_row.rb` — one counter in the list

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ExpanderRow` | 1 | `spin`; one of `red`/`orange`/`yellow`/`green`/`blue`/`purple` (dynamic, swapped on recolour); `checked` while ticked; `error` while the name is empty | `notify::expanded` → scroll into view after 50 ms | `enable_expansion = false` in select mode |
| `Gtk.Image` (drag handle) | 1 | `drag-handle` | — | prefix; hidden in select mode |
| `Gtk.CheckButton` | 1 | — | `notify::active` → sets `checked`, toggles the `checked` class | prefix; hidden outside select mode |
| `Gtk.Label` (count) | 1 | — | — | suffix; `margin_start = 18`, `halign = END`; visible only in select mode |
| `Gtk.SpinButton` | 1 | — | `notify::value` → writes the counter and queues a save | suffix; range 0–1,000,000 step 1; its `GtkText` child is `xalign = 1` |
| `Gtk.DragSource` (controller) | 1 | — | `prepare`, `drag-begin` | on the handle, `CAPTURE` phase, `MOVE` |
| `Gtk.DropTarget` (controller) | 1 | — | `drop` → reorders both the list box and the counter order | on the row, `MOVE`, `preload`, gtype `Adw.ExpanderRow` |
| `Gtk.DragIcon` | 1 | — | — | hosts the drag preview |
| `Gtk.ListBox` (drag preview) | 1 | `tally-list`, `boxed-list` | — | throwaway, sized to the row's allocation |

Repeaters: none within the row. Conditional: the colour class exists only when
the counter has a colour; the `checked` and `error` classes are runtime-only.

### `counter.lua:duplicate` → `lib/tally/counter_drag_row.rb` — the drag preview row

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ExpanderRow` | 1 | the counter's colour class | — | same title, same expanded state |
| `Gtk.Image` | 1 | `drag-handle` | — | prefix |
| `Gtk.SpinButton` | 1 | — | — | suffix, same value, no handler |

It also attaches a `CounterMenu` in duplicate mode, which contributes the four
rows below with every control desensitised and nothing connected.

### `counter.lua:createmenu` → `lib/tally/counter_menu.rb` — the disclosure under a row

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.EntryRow` (Name) | 1 | — | `changed` → renames, or marks the row `error` when emptied | desensitised in the drag preview |
| `Adw.ActionRow` (Color) | 1 | — | — | suffix is a radio `ColorSelector` |
| `Adw.ActionRow` (Reorder in List) | 1 | — | — | suffix is the order box |
| `Adw.ActionRow` (Show in a Separate Window) | 1 | — | — | suffix is the pop-out button |
| `Gtk.Box` (order box) | 1 | — | — | horizontal, spacing 6, `halign END`, `valign CENTER` |
| `Gtk.Button` (top / up / down / bottom) | 4 | — | `clicked` → moves the counter, skipping filter-hidden rows, then scrolls after 50 ms | one shared factory, four call sites |
| `Gtk.Button` (pop-out) | 1 | — | `clicked` → presents the counter's own window | `halign END`, `hexpand`, `valign CENTER` |

### `counter.lua:colorrow` + two open-coded copies → `lib/tally/color_selector.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` | 1 per site | `colorselector` | — | horizontal, spacing 6; three sites: search bar, new-counter dialog, counter menu |
| `Gtk.CheckButton` | 7 per site | `system` (search bar only); `red`/`orange`/`yellow`/`green`/`blue`/`purple` | `notify::active` | tooltip is the translated colour name; grouped onto the first button in radio mode, ungrouped in the search bar |

Repeater: the seven buttons are a loop over `["system", red, orange, yellow,
green, blue, purple]`, and the box is instantiated three times — 21 check
buttons on screen with one counter in the list and the search bar open.

### `main.lua` searchbar block → `lib/tally/search_bar.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.SearchBar` | 1 | — | `notify::search-mode-enabled` → clears every colour tick | `key_capture_widget` set; `connect_entry`; bound to the header's search toggle |
| `Gtk.Box` | 1 | — | — | vertical, spacing 6, 6px top/bottom margins |
| `Gtk.SearchEntry` | 1 | — | `search-changed` → invalidates the list filter | placeholder `Filter by name…` |
| `ColorSelector` (multi) | 1 | `colorselector` | — | see above |

### `main.lua` statuspage → `lib/tally/empty_state.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.StatusPage` | 1 | — | — | title `No Counters`, icon `tally-symbolic` |
| `Gtk.Button` | 1 | `suggested-action`, `pill` | `clicked` → opens the new-counter dialog | 40px side margins |

### `main.lua:tallydialog` → `lib/tally/new_counter_dialog.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` | 1 | — | — | title `New Counter` |
| `Adw.ToolbarView` | 1 | — | — | — |
| `Adw.HeaderBar` | 1 | — | — | no title widget |
| `Gtk.Box` | 1 | — | — | vertical, spacing 12, 12px margins all round |
| `Gtk.Entry` | 1 | `error` while empty (dynamic) | `changed` → validates | placeholder `Name`, `halign FILL` |
| `ColorSelector` (radio) | 1 | `colorselector` | — | see above |
| `Gtk.Button` | 1 | `suggested-action` | `clicked` → creates the counter and closes | `halign CENTER`, starts insensitive |
| `Adw.ButtonContent` | 1 | — | — | icon `plus-large-symbolic`, label `Add to List` |

### `counter.lua:popout` → `lib/tally/counter_window.rb` — one counter's own window

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (devel build only) | `close-request` → destroys | 400×300 default, 360×294 minimum, `hide_on_close` |
| `Adw.ToolbarView` | 1 | the counter's colour class (dynamic) | — | `width_request = 300` |
| `Adw.HeaderBar` | 1 | — | — | — |
| `Adw.WindowTitle` | 1 | — | — | `title` bound bidirectionally to the row's Name entry; subtitle `Tally` |
| `Gtk.WindowHandle` | 1 | — | — | lets the whole face drag the window |
| `Gtk.Box` (outer) | 1 | — | — | vertical, spacing 36, 24px margins, centred |
| `Gtk.Box` (numbers) | 1 | `popout` | — | vertical, spacing 24 — this is what scales the type to 300% |
| `Gtk.Label` | 1 | `numeric` | — | `width_request = 240`, centred |
| `Gtk.Box` (buttons) | 1 | — | — | horizontal, spacing 48, centred |
| `Gtk.Button` (−) | 1 | `circular` | `clicked` → decrements | insensitive at 0 |
| `Gtk.Button` (+) | 1 | `circular` | `clicked` → increments | insensitive at 1,000,000 |
| `Gio.SimpleAction` `win.close` | 1 | — | `activate` | `<Ctrl>W` |

### `main.lua:newshortcutwindow` → `lib/tally/shortcuts_dialog.rb`

Upstream: one `Gtk.ShortcutsWindow`, one `Gtk.ShortcutsSection`, two
`Gtk.ShortcutsGroup` (`Main Window`, `Counter Window`), five
`Gtk.ShortcutsShortcut`:

| Group | Title | action_name | Accelerator |
|---|---|---|---|
| Main Window | Quit Application | `app.quit` | `<Ctrl>Q` |
| Main Window | Keyboard Shortcuts | `win.shortcuts` | `<Ctrl><Shift>question` |
| Main Window | About Tally | `app.about` | `F1` |
| Counter Window | Quit Application | `app.quit` | `<Ctrl>Q` |
| Counter Window | Close Window | `win.close` | `<Ctrl>W` |

Two upstream defects recorded here because the port has to decide about both:

- the section's `title = app_title` reads a **nil global** — upstream's section is untitled.
- `app.about` names **no registered action**; upstream registers `win.about` and binds F1 to `win.about`, so upstream's About row is inert.

### `main.lua` app object → `lib/tally/application.rb`

| Thing | Value |
|---|---|
| Application | `Adw.Application`, `resource_base_path = /ca/vlacroix/Tally` |
| Accelerators | `win.shortcuts` `<Ctrl><Shift>question`; `win.about` `F1`; `win.close` `<Ctrl>W`; `app.quit` `<Ctrl>Q` |
| Actions | `app.quit` |
| Signals | `activate` (present the existing window), `startup` (build and present), `shutdown` (write the config) |

### `main.lua` styles → `lib/tally/styles.rb`

Two `Gtk.CssProvider`s (base+light, base+dark) added to the display at priority
1,000,000 and swapped on `Adw.StyleManager::notify::dark`.

CSS classes defined by the app's own stylesheet, read out of the Lua by hand:

`colorselector`, `system`, `red`, `orange`, `yellow`, `green`, `blue`,
`purple`, `tally-list`, `popout`.

Classes attached but supplied by GTK/libadwaita, not by this stylesheet:
`boxed-list`, `separators`, `spin`, `checked`, `error`, `drag-handle`,
`circular`, `numeric`, `pill`, `suggested-action`, `destructive-action`,
`devel`.

### Non-widget components with no widget owner

| Component | Upstream | Port |
|---|---|---|
| Icon bundle (16 symbolic action icons) | `data/tally.gresource.xml` + GResource load | `lib/tally/icons.rb` + `data/icons/hicolor/scalable/actions` |
| Application icon, 4 variants | `icons/*.svg` + `Makefile install` | `data/icons/hicolor/{scalable,symbolic}/apps` + `flake.nix` |
| Desktop entry ×2 | `ca.vlacroix.Tally{,.Devel}.desktop` | `data/org.rubygtkproject.Tally{,.Devel}.desktop` |
| AppStream metainfo ×2, 15 releases | `ca.vlacroix.Tally{,.Devel}.metainfo.xml` | `data/org.rubygtkproject.Tally{,.Devel}.metainfo.xml` |
| Catalogues | `po/{fr,id,it}.po` + `.pot` | same three + `.pot` |
| Install/build | `Makefile` | `flake.nix`, `rakelib/gettext.rake`, the gemspec |
| **Flatpak manifest ×2** | `ca.vlacroix.Tally{,.Devel}.json` | **absent** |
| **CI that builds it** | `.github/workflows/ci.yml` | **absent** |
| **Project metadata** | `tally.doap` | **absent** |
| **README screenshot** | `tally.png` | **absent** |

## Totals

| Axis | Upstream distinct | Port distinct | In upstream, not in the port |
|---|---:|---:|---:|
| Widget types | 30 | 29 | 4 (`Gtk.ShortcutsWindow`, `Gtk.ShortcutsSection`, `Gtk.ShortcutsGroup`, `Gtk.ShortcutsShortcut` — all replaced by the `Adw.Shortcuts*` family) |
| Live widget instances | — | — | 0 |
| App-defined CSS classes | 10 | 10 | 0 |
| Platform CSS classes attached | 12 | 12 | 0 |
| Signals | 18 | 18 | 0 |
| Actions | 4 | 4 | 0 |
| Non-widget components | 10 | 6 | **4** |

Read that last row, not the ones above it. The widget tree is complete; what
is absent is everything that makes the app an *installed application* the way
upstream ships it. The comparison, and the verdict, are in
`component-parity.md`.

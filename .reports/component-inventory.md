# Component inventory — tally → tally-rb

|  |  |
|---|---|
| Upstream | `origin/trunk` @ `e9986b010c950d2df91b682769b744c412348e0c` ("tally: Archive repository") |
| Port | `ruby` @ `9c0a3ba` |
| Scope | whole app. Upstream: `main.lua` 862 lines, `counter.lua` 510, `main.c` 134. Port: 3,836 lines of Ruby across 25 files under `lib/` |
| Verdict | **every user-facing component upstream has a port file, and every port file has an upstream block opposite it.** No component is missing; no port file is an invention |

This is the survey's component list: one row per component, with the upstream
file it comes from, the `lib/*.rb` it becomes, its kind, and whether it exists
on `ruby` today. The per-widget detail behind each row — widget types with
counts, CSS classes, signals and installed actions — is
`.reports/component-identification.md`; the four-axis comparison is
`.reports/component-parity.md`. This file is the index into those two, kept at
HEAD so the component list can be read without reading either.

## Step 1 — declarative UI: there is none, on either side

```sh
$ git ls-tree -r --name-only origin/trunk | grep -E '\.(ui|blp)$'   → nothing
$ git ls-tree -r --name-only origin/trunk | grep -iE 'gschema'      → nothing
$ find lib data -name '*.ui' -o -name '*.blp'                       → nothing
```

Upstream is Lua against GTK4/libadwaita through LuaGObject, building its whole
widget tree imperatively from constructor tables (`Adw.HeaderBar { title_widget
= … }`), bootstrapped by `main.c`, which embeds the Lua bytecode with `#embed`
and exposes five C functions as the `mainlib` module. There is no GtkBuilder
XML, no blueprint and **no GSettings schema** — window geometry and the counters
themselves are persisted to a hand-written Lua table at
`$XDG_CONFIG_HOME/tally/tally`. So Step 1 of the skill contributes no free unit
list, no free CSS map and no free signal map; every row below was recovered by
reading the two Lua files. The port has no `.ui`/`.blp` either, by house-style
design (memoized widget accessors).

The declarative data files that do exist:

| Upstream file | What it contributes | Port |
|---|---|---|
| `data/tally.gresource.xml` | 16 symbolic action icons, registered at startup under `/ca/vlacroix/Tally` | `lib/tally/icons.rb` + `data/icons/hicolor/**` (16 action icons byte-identical, 4 app icons present) |
| `ca.vlacroix.Tally{,.Devel}.desktop` | desktop entries, translated Name/Comment/Keywords | `data/` desktop entries under the renamed id |
| `ca.vlacroix.Tally{,.Devel}.metainfo.xml` | AppStream, 15 releases, 23 translatable strings | `lib/tally/metainfo.rb` reads it for the About dialog |
| `po/MESSAGES.pot`, `po/{fr,id,it}.po` | 41 translatable strings in code, domain `messages` | `po/` carries all four catalogues; `lib/tally/locale.rb` binds the domain |

## Step 2 — the scan, and a scanner defect worth repeating

`component-scan.sh` matches `.ui .blp .vala .c .h .py .js .ts .rs .rb` and
**not `.lua`**, so upstream as shipped scans to **zero rows**. A reviewer who
trusts that result concludes there is no spec. The upstream side of this
inventory is therefore a hand census; the port's 129 scan rows are a
cross-check only, and they over-report — type names inside doc comments
(`Adw.AboutDialog` in `metainfo.rb`, `Gtk.SpinButton` in `lua_config.rb`,
`Gtk.ListBoxRow` in `counter.rb`, `Gtk.InitError` in `rb.rb`) are prose, not
widgets.

## Step 3 — the component list

Upstream splits by *object* (one Lua file per class, with `main.lua` holding
the application, the window and everything the window owns); the port splits by
*view*. So the mapping is many-to-many: `main.lua` fans out to fifteen Ruby
files, and three Ruby files pull from both Lua files. Order is the order a user
meets each component.

| # | Component | Upstream file (block) | Port file | Kind | Exists |
|--:|---|---|---|---|:-:|
| 1 | Application — actions, accels, activate/startup/shutdown | `main.lua` (app object, `quit_action`); `main.c` (`get_app_id`, `get_app_ver`, `get_is_devel`, `main`) | `lib/tally/application.rb` | application | yes |
| 2 | Main window — header bar, select/delete mode, breakpoint | `main.lua` (`window` class, `refreshtoolbar`) | `lib/tally/main_window.rb` | window | yes |
| 3 | Counter list — scroller, multi-layout, clamp, list box | `main.lua` (`lbox`, `clamp`, `biglayout`, `smalllayout`, `multi`, `scrolledwin`, `enlarge`, `shrink`, `scrollbottom`) | `lib/tally/counter_list.rb` | view | yes |
| 4 | Filter bar — search entry plus colour filter | `main.lua` (`searchbar`, `searchentry`, `searchbox`, `lbox:set_filter_func`) | `lib/tally/search_bar.rb` | search bar | yes |
| 5 | Colour selector — the 7-check colour picker, reused 3× | `main.lua` (`searchcolorbox`, `tallycolorbox` + check loops); `counter.lua` (`colorrow`, `gencolorcheck`) | `lib/tally/color_selector.rb` | widget | yes |
| 6 | Colour catalogue — names and the accent list | `main.lua` (`lib.getcolorname`) | `lib/tally/colors.rb` | model | yes |
| 7 | Empty state — "No Counters" status page | `main.lua` (`statuspage`) | `lib/tally/empty_state.rb` | empty state | yes |
| 8 | New-counter dialog — name entry, colour picker, create | `main.lua` (`window:tallydialog`) | `lib/tally/new_counter_dialog.rb` | dialog | yes |
| 9 | Primary menu — 2 items | `main.lua` (`tallymenu`) | `lib/tally/main_menu.rb` | menu | yes |
| 10 | About dialog — 2 extra links, release notes | `main.lua` (`aboutwin`) | `lib/tally/about_dialog.rb` | dialog | yes |
| 11 | AppStream reader — feeds the About dialog | `ca.vlacroix.Tally.metainfo.xml` (read at runtime upstream only via `get_app_ver`) | `lib/tally/metainfo.rb` | model | yes |
| 12 | Keyboard shortcuts — 2 groups, 5 shortcuts | `main.lua` (`newshortcutwindow`) | `lib/tally/shortcuts_dialog.rb` | shortcuts window | yes |
| 13 | Stylesheet — base plus light/dark, swapped on `notify::dark` | `main.lua` (`cssbase`, `csslight`, `cssdark`, provider swap) | `lib/tally/styles.rb` | stylesheet | yes |
| 14 | Counter model — fields, collection, serialize, delete | `counter.lua` (counter fields, `counters`, `counterrows`, `serialize`, `delete`) | `lib/tally/counter.rb` | model | yes |
| 15 | Counter row — expander, spin button, select mode, drag/drop | `counter.lua` (constructor, `read`, `setcheckmode`, `DragSource`, `DropTarget`) | `lib/tally/counter_row.rb` | row | yes |
| 16 | Row disclosure — rename, colour, reorder, pop out | `counter.lua` (`createmenu`) | `lib/tally/counter_menu.rb` | row detail | yes |
| 17 | Counter window — the stand-alone pop-out, `win.close` | `counter.lua` (`popout`) | `lib/tally/counter_window.rb` | window | yes |
| 18 | Drag preview — the desensitised duplicate row | `counter.lua` (`duplicate`) | `lib/tally/counter_drag_row.rb` | row | yes |
| 19 | Store — debounced atomic writes, geometry, dir bootstrap | `main.lua` (`readcfg`, `writecfg`, `lib.queuewrite`, dir bootstrap) | `lib/tally/store.rb` | backend | yes |
| 20 | Legacy config reader — upstream's Lua table, without `load()` | `main.lua` (the `return { … }` grammar `writecfg` emits) | `lib/tally/lua_config.rb` | backend | yes |
| 21 | Icons — 16 bundled symbolic actions | `data/tally.gresource.xml`, `main.lua` (`Gio.Resource.load`), `Makefile` (icon install) | `lib/tally/icons.rb` | assets | yes |
| 22 | Locale — gettext domain binding, `_` | `main.c` (`lua_gettext`, `bindtextdomain`, `textdomain`); `main.lua`/`counter.lua` (`local _ = lib.gettext`) | `lib/tally/locale.rb` | i18n | yes |
| 23 | Entry point | `main.c` (`main`) | `exe/tally` | binary | yes |
| 24 | Library root — require graph, GTK-free half | — (upstream has no equivalent; `package.path` setup is the nearest) | `lib/tally.rb`, `lib/tally/rb.rb`, `lib/tally/rb/version.rb` | plumbing | yes |

**Port files with no upstream file opposite them: none.** `colors.rb`,
`color_selector.rb`, `metainfo.rb` and `lua_config.rb` are factored-out repeats
or readers for data upstream inlines; each is named above against the upstream
block it came from. `tally.rb`, `rb.rb` and `rb/version.rb` are gem plumbing,
not components.

## Repeaters, conditionals and dynamics — what a flat scan loses

| Kind | Where | Multiplicity |
|---|---|---|
| Repeater | filter-bar colour checks | 7 (`system` + 6 accents), ungrouped so any number tick |
| Repeater | new-counter dialog colour checks | 7 (unclassed + 6 accents), radio-grouped |
| Repeater | `counter:colorrow` colour checks | 7, per row *and again* per drag preview |
| Repeater | counter rows in the list | N, driven by the `counters` table |
| Repeater | `Gtk.ShortcutsShortcut` | 5 across 2 groups |
| Conditional | `devel` CSS class | `-DDEVEL` at compile time |
| Conditional | delete button | select mode only |
| Conditional | select button | only when counters exist |
| Conditional | list box visibility | only when it holds a row |
| Conditional | the disclosure in `duplicate` mode | drag preview only — every control desensitised |
| Dynamic CSS | row / toolbar colour | one of `red`, `orange`, `yellow`, `green`, `blue`, `purple`, or none |
| Dynamic CSS | `checked` | while a row is ticked |
| Dynamic CSS | `error` | on the new-counter entry while unnamed; on the row while a rename is empty |
| Dynamic CSS | `boxed-list` ↔ `separators` | swapped by the 400px breakpoint |
| Shared factory | `counter:gencolorcheck` | one definition, 7 call sites per selector, 3 selectors |
| Actions from no literal | none — all four are literal `Gio.SimpleAction.new` names |  |

## Actions and accelerators

| Action | Installed on | Accelerator | Port |
|---|---|---|---|
| `app.quit` | the application | `<Ctrl>Q` | `lib/tally/application.rb` |
| `win.shortcuts` | the main window | `<Ctrl><Shift>question` | `lib/tally/main_window.rb` |
| `win.about` | the main window | `F1` | `lib/tally/main_window.rb` |
| `win.close` | each pop-out window | `<Ctrl>W` | `lib/tally/counter_window.rb` |

## Totals

| Axis | Upstream (hand census) | Port |
|---|---:|---:|
| Component files | 3 (`main.lua`, `counter.lua`, `main.c`) | 25 under `lib/` + `exe/tally` |
| Components | 24 | 24 — all present |
| Distinct CSS classes attached | 22 | 22 |
| Distinct signals | 18 | 18 |
| Actions installed | 4 | 4 |
| Accelerators | 4 | 4 |
| Distinct msgids | 41 in code + 23 in metadata | 41 + 23 |
| Bundled action icons | 16 | 16 |

One substitution of type, not of component: upstream's deprecated
`Gtk.ShortcutsWindow` / `Section` / `Group` / `Shortcut` becomes
`Adwaita::ShortcutsDialog` / `Section` / `Item`, and `Adw.Application` becomes
`Gtk::Application` with the Adwaita style manager initialised directly, because
the Ruby bindings expose it that way.

## What this survey leaves open

Nothing on the component axis. The gaps recorded elsewhere are non-widget and
are tracked in `FINDINGS.md` and `.reports/component-parity.md`: the Flatpak
manifests, the upstream `Makefile`'s build rules, and the fact that upstream
itself has never been run here (it needs LuaGObject and a Flatpak sandbox), so
every row above is read off source rather than off two running apps.

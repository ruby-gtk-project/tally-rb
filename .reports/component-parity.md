# Component parity — tally / tally-rb

|  |  |
|---|---|
| Upstream | `origin/trunk` @ `e9986b010c950d2df91b682769b744c412348e0c` |
| Port | `ruby` @ `0dfc40d8db4335c55114b631c8228a60ec804a0f` |
| Units | 26 |
| Units at parity | **20 / 26** |
| Verdict | **not at parity — 6 gaps** |

Inventory and file mapping: `.reports/component-identification.md`.

## The headline

The widget code is in better shape than any port this young has a right to be.
Every live widget instance upstream builds has a counterpart; the stylesheet is
byte-identical modulo indentation; all 18 signals and all 4 actions are wired;
the app builds, runs headlessly and passes 105 driven checks.

That is exactly the result to be adversarial about, so here is where it is not
true:

1. The app cannot be installed the way upstream is installed. Upstream ships
   on Flathub and nowhere else; the port has no Flatpak manifest and no CI
   that builds one.
2. A failure to start says nothing to the user, in any language.
3. Two project-metadata files and the README screenshot are absent.
4. One widget carries an alignment upstream does not give it at two of its
   three sites.
5. Nothing has been compared against upstream *running*. The port's twelve
   screenshots are of the port; there is no upstream side.

## Units with no port file at all — 4 gaps

### Gap 1 — the app cannot be installed the way upstream is installed

Upstream ships `ca.vlacroix.Tally.json` and `ca.vlacroix.Tally.Devel.json`
(flatpak manifests building Lua 5.4 and LuaGObject inside `org.gnome.Sdk`,
with `make DEVEL=true` for the second), and `.github/workflows/ci.yml` runs
`flatpak/flatpak-github-actions/flatpak-builder@v6` against the first on every
push to `trunk`. Upstream's README offers exactly one install route: a Flathub
badge. `flatpak-builder .build ca.vlacroix.Tally.json --user --install` is the
documented way to run the app.

The port has neither manifest, and `.github/workflows/` holds only
`translations.yml`. A user cannot install this port the way they install the
app it is a port of.

`lib/tally/application.rb:38-45` records this, and that record is the second
half of the gap — see `.reports/accountability-ensurance.md`, Finding 1.

**Owed:** a `.json` manifest (and its `.Devel` variant) that builds the port
inside the GNOME SDK, plus the CI job that proves it still builds.

### Gap 2 — a failed start says nothing to the user

`main.c:125-133`: when `luaL_loadbuffer` fails, upstream prints
`gettext("An unrecoverable error occurred when loading Tally, preventing the
program from starting.\n")` to stderr and exits with the Lua error code. The
message is translated — it is one of the 41 msgids, and `fr`, `id` and `it`
all have it.

`exe/tally` is six lines with no `rescue`. A load failure produces a Ruby
backtrace in English. The msgid is now `#~`-obsolete in all three catalogues,
so the translation is dead as well (see `.reports/translation-parity.md`,
Gap 1).

**Owed:** the executable catches a startup failure, prints that exact
translated sentence to stderr, and exits non-zero.

### Gap 3 — `tally.doap` is not ported

Upstream ships a DOAP project description at the repository root — the file
GNOME infrastructure reads for maintainer, homepage, bug database and
programming language. The port has none.

**Owed:** the same file, retargeted to this port's names and URLs.

### Gap 4 — the README shows no picture of the app

Upstream's `README.md` opens with `![tally](tally.png)` and ships that PNG.
The port's README has no screenshot of the app; the driver writes twelve into
`tmp/shots/`, which `.gitignore`d scratch, and none of them is committed or
referenced.

**Owed:** a committed screenshot of the port, in the README, where upstream
puts one.

## Units with a port file and a named gap — 2 gaps

### Gap 5 — the colour selector is centred where upstream does not centre it

`lib/tally/color_selector.rb:40` sets `self.valign = :center` in the
constructor, so it applies at all three call sites. Upstream sets it at one:

| Site | Upstream | Port |
|---|---|---|
| `counter:colorrow` (the menu's Color row) | `valign = "CENTER"` | `:center` — parity |
| `main.lua` `searchcolorbox` (the search bar) | **no valign** (default `FILL`) | `:center` — **gap** |
| `main.lua` `tallycolorbox` (the new-counter dialog) | **no valign** (default `FILL`) | `:center` — **gap** |

Small, and it is still a style-axis difference on two of three sites, found by
reading rather than by any scan, and exactly the shape of thing the CSS axis
exists to catch.

**Owed:** `valign` becomes a per-site argument, `:center` only where
`counter:colorrow` sets it.

### Gap 6 — nothing has been compared against upstream running

Step 4 and Step 5 of this skill are half-done. The port is driven
(`test/drive_tally.rb`, 105 checks, green under `xvfb-run`) and twelve
screenshots are written. What does not exist is the other side: upstream is a
Flatpak-only Lua app and has not been built or run here, so every "looks the
same" claim in this ledger rests on reading two source trees.

Two of the port's own shots are also not showing what they claim to.
`11-shortcuts.png` and `12-about.png` capture the main window with the dialog
ghosted behind it mid-animation — the dialog's contents are legible only
because they bleed through. A shot that needs squinting is not evidence.

**Owed:** build upstream (the manifest from Gap 1 makes this possible for the
port too), run both side by side, and re-take the dialog shots after the
present animation settles.

---

## Unit-by-unit comparison

`Up ×` and `Port ×` are live instances. `Text` is `✓` when every string the
widget shows is marked and byte-identical to upstream's msgid, `—` when it
shows none.

### Unit 1 — main window · `main.lua` window class → `lib/tally/main_window.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | ✓ `devel` | ✓ `close-request` | ✓ `Tally` | parity |
| `Adw.ToolbarView` | 1 | 1 | — | — | — | parity |
| `Adw.HeaderBar` | 1 | 1 | — | — | — | parity |
| `Adw.WindowTitle` | 1 | 1 | — | — | ✓ `Tally` | parity |
| `Gtk.Button` (new) | 1 | 1 | — | ✓ `clicked` | ✓ `Create a new counter` | parity |
| `Gtk.Button` (delete) | 1 | 1 | ✓ `destructive-action` | ✓ `clicked` | ✓ `Delete selected counters` | parity |
| `Gtk.ToggleButton` (select) | 1 | 1 | — | ✓ `notify::active` | ✓ both tooltips | parity |
| `Gtk.ToggleButton` (search) | 1 | 1 | — | ✓ bidirectional bind | ✓ `Filter counters by name and/or color` | parity |
| `Gtk.MenuButton` | 1 | 1 | — | — | ✓ `Menu` | parity |
| `Adw.Breakpoint` | 1 | 1 | — | ✓ `apply`, `unapply` | — | parity |
| `Gio.SimpleAction` `win.shortcuts` | 1 | 1 | — | ✓ `activate` | — | parity |
| `Gio.SimpleAction` `win.about` | 1 | 1 | — | ✓ `activate` | — | parity |

Geometry: 500×600 default / 360×294 minimum on both; `maximize` and the saved
width/height both restored (`main_window.rb:50-56` and `#restore`).
`refreshtoolbar` → `refresh_toolbar`, same three effects.
Messages: 8 upstream, 8 in the port, all byte-identical.
Driven: empty state ✓, select mode ✓, delete ✓, breakpoint style flip ✓.
Screenshots: `01-empty`, `04-three-counters`, `06-select-mode`, `07-after-delete`.

Two divergences in the port's favour, recorded rather than silently kept:

- `main.lua:503` sets `searchbar.key_capture_widget = window` — `window` there
  is the *class* table, not `self.window`. Type-to-search is dead upstream.
  `main_window.rb:84-85` passes the real window, so it works here.
- `main.lua` does not call `setcheckmode` on a counter created while select
  mode is on; `main_window.rb#add_row` does, so a new row joins in the right
  state.

**Verdict: parity.**

### Unit 2 — counter list · `main.lua` list block → `lib/tally/counter_list.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gtk.ScrolledWindow` | 1 | 1 | — | — | — | parity |
| `Adw.MultiLayoutView` | 1 | 1 | — | — | — | parity |
| `Adw.Layout` | 2 | 2 | — | — | — | parity |
| `Adw.LayoutSlot` | 2 | 2 | — | — | — | parity |
| `Adw.Clamp` | 1 | 1 | — | — | — | parity |
| `Gtk.ListBox` | 1 | 1 | ✓ `tally-list`, `boxed-list` ⇄ `separators` | ✓ `row-activated`, filter func | — | parity |

`enlarge`/`shrink` → `#enlarge`/`#shrink`, same class swap and same top-bar
style. `counter:scroll` → `#scroll_into_view` via the interposed
`Gtk.Viewport`, same object upstream's `scrolledwin:get_child()` returns.
`window:scrollbottom` → `#scroll_to_bottom`, same 20 ms delay.
Messages: 0 / 0. Driven ✓. **Verdict: parity.**

### Unit 3 — counter row · `counter.lua` constructor → `lib/tally/counter_row.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ExpanderRow` | 1 | 1 | ✓ `spin`, 6 colour classes (dynamic), `checked`, `error` | ✓ `notify::expanded` | — | parity |
| `Gtk.Image` | 1 | 1 | ✓ `drag-handle` | — | — | parity |
| `Gtk.CheckButton` | 1 | 1 | — | ✓ `notify::active` | — | parity |
| `Gtk.Label` | 1 | 1 | — | — | — | parity |
| `Gtk.SpinButton` | 1 | 1 | — | ✓ `notify::value` | — | parity |
| `Gtk.DragSource` (controller) | 1 | 1 | — | ✓ `prepare`, `drag-begin` | — | parity |
| `Gtk.DropTarget` (controller) | 1 | 1 | — | ✓ `drop` | — | parity |
| `Gtk.DragIcon` | 1 | 1 | — | — | — | parity |
| `Gtk.ListBox` (preview) | 1 | 1 | ✓ `tally-list`, `boxed-list` | — | — | parity |

`setcheckmode` → `#check_mode=`, all seven property changes in both branches.
`read` → `#read` — upstream defines it and never calls it; the port makes it
live, because this port's edits travel in both directions.
Spin range 0–1,000,000 step 1 on both; the `GtkText` child's `xalign = 1` kept;
the suffix box's `hexpand` fix kept (`#align_suffixes`).
Reorder keeps both orders in step, as `counter.lua:107-129` does.
Messages: 0 / 0. Driven: drag preview ✓, check mode ✓, recolour ✓.
**Verdict: parity.**

### Unit 4 — row menu · `counter:createmenu` → `lib/tally/counter_menu.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.EntryRow` | 1 | 1 | — | ✓ `changed` | ✓ `Name` | parity |
| `Adw.ActionRow` | 3 | 3 | — | — | ✓ `Color`, `Reorder in List`, `Show in a Separate Window` | parity |
| `Gtk.Box` | 1 | 1 | — | — | — | parity |
| `Gtk.Button` (order) | 4 | 4 | — | ✓ `clicked` ×4 | ✓ all four tooltips | parity |
| `Gtk.Button` (pop-out) | 1 | 1 | — | ✓ `clicked` | ✓ `Create a new window for this counter` | parity |

The `duplicate` flag is kept: every control desensitised and nothing connected
in the drag preview, as `counter.lua:218-219` decides by `self.entry ~= nil`.
Up/down skip filter-hidden rows via `mapped?`, as upstream's `get_mapped()`
loops do. Empty name marks the row `error` and keeps the old name, on both.
Messages: 7 upstream, 7 in the port, byte-identical. Driven ✓.
**Verdict: parity.**

### Unit 5 — drag preview · `counter:duplicate` → `lib/tally/counter_drag_row.rb`

`Adw.ExpanderRow` 1/1, `Gtk.Image` 1/1 with `drag-handle`, `Gtk.SpinButton`
1/1, colour class and expanded state both carried. Messages 0/0.
**Verdict: parity.**

### Unit 6 — colour selector · 3 upstream sites → `lib/tally/color_selector.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gtk.Box` | 3 | 3 | ✓ `colorselector` | — | — | **gap** — see Gap 5 (`valign`) |
| `Gtk.CheckButton` | 21 | 21 | ✓ `system` (search bar only), 6 colour classes | ✓ `notify::active` | ✓ 7 colour names | parity |

Radio grouping, the ungrouped search-bar variant, and the `system` class being
attached only in the search bar are all upstream's. The port ignores the
deactivation edge of `notify::active` where upstream handles both and relies on
GTK's deactivate-then-activate order — a narrowing, and strictly safer.
Messages: 7 upstream (`No color`, `Red`, `Orange`, `Yellow`, `Green`, `Blue`,
`Purple`), 7 in the port, byte-identical.
Screenshots: `09-colour-filter`, `10-coloured`.
**Verdict: gap (Gap 5).**

### Unit 7 — search bar · `main.lua` searchbar block → `lib/tally/search_bar.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gtk.SearchBar` | 1 | 1 | — | ✓ `notify::search-mode-enabled` | — | parity |
| `Gtk.Box` | 1 | 1 | — | — | — | parity |
| `Gtk.SearchEntry` | 1 | 1 | — | ✓ `search-changed` | ✓ `Filter by name…` | parity |

Filter predicate matches upstream's three-branch rule exactly: closed bar →
everything; open with empty query and no colour → everything; otherwise colour
AND case-folded plain-substring name.
`connect_entry` ✓, bidirectional bind to the header toggle ✓, ticks cleared on
every search-mode change ✓.
Messages: 1 / 1. Driven: `08-search`, `09-colour-filter`.
**Verdict: parity.**

### Unit 8 — empty state · `main.lua` statuspage → `lib/tally/empty_state.rb`

`Adw.StatusPage` 1/1 (`No Counters`, `tally-symbolic`), `Gtk.Button` 1/1 with
`suggested-action` + `pill` and 40px side margins, `clicked` wired. Messages
2/2 byte-identical. Screenshot `01-empty`. **Verdict: parity.**

### Unit 9 — new-counter dialog · `window:tallydialog` → `lib/tally/new_counter_dialog.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.Dialog` | 1 | 1 | — | — | ✓ `New Counter` | parity |
| `Adw.ToolbarView` | 1 | 1 | — | — | — | parity |
| `Adw.HeaderBar` | 1 | 1 | — | — | — | parity |
| `Gtk.Box` | 1 | 1 | — | — | — | parity |
| `Gtk.Entry` | 1 | 1 | ✓ `error` (dynamic) | ✓ `changed` | ✓ `Name` | parity |
| `Gtk.Button` | 1 | 1 | ✓ `suggested-action` | ✓ `clicked` | ✓ `Add this counter to the list` | parity |
| `Adw.ButtonContent` | 1 | 1 | — | — | ✓ `Add to List` | parity |

Upstream rebuilds the dialog per activation; the port keeps one per window and
`#open` resets name, error class, sensitivity and colour. Same user-visible
state. Messages 4/4. Screenshot `02-new-counter-dialog`.
**Verdict: parity.**

### Unit 10 — pop-out window · `counter:popout` → `lib/tally/counter_window.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | ✓ `devel` | ✓ `close-request` | ✓ `<name> — Tally` | parity |
| `Adw.ToolbarView` | 1 | 1 | ✓ colour class (dynamic) | — | — | parity |
| `Adw.HeaderBar` | 1 | 1 | — | — | — | parity |
| `Adw.WindowTitle` | 1 | 1 | — | ✓ bidirectional bind to the Name entry | ✓ `Tally` | parity |
| `Gtk.WindowHandle` | 1 | 1 | — | — | — | parity |
| `Gtk.Box` | 3 | 3 | ✓ `popout` | — | — | parity |
| `Gtk.Label` | 1 | 1 | ✓ `numeric` | — | — | parity |
| `Gtk.Button` (−) | 1 | 1 | ✓ `circular` | ✓ `clicked` | ✓ `Decrement by 1` | parity |
| `Gtk.Button` (+) | 1 | 1 | ✓ `circular` | ✓ `clicked` | ✓ `Increment by 1` | parity |
| `Gio.SimpleAction` `win.close` | 1 | 1 | — | ✓ `activate` | — | parity |

Geometry 400×300 / 360×294, `width_request = 300` on the toolbar view,
`hide_on_close` then destroy-on-close: all upstream's.
Sensitivity bounds (0 and 1,000,000) kept on both buttons.

One divergence in the port's favour: `counter.lua:406` reassigns
`self.spinbtn.on_notify.value` inside `popout`, which replaces the list row's
own handler — upstream's row count label stops updating and its edits stop
being saved while a pop-out is open. The port routes both windows through
`Counter#value` instead (`counter_window.rb:17-21`, `#step`).
Messages 3/3. Screenshot `05-popout`. **Verdict: parity.**

### Unit 11 — shortcuts · `newshortcutwindow` → `lib/tally/shortcuts_dialog.rb`

| Upstream | Port | Verdict |
|---|---|---|
| `Gtk.ShortcutsWindow` | `Adw.ShortcutsDialog` | correspondence — the `Gtk.Shortcuts*` family is deprecated as of GTK 4.18 |
| `Gtk.ShortcutsSection` × 1 (title = `app_title`, a nil global) | — | correspondence — upstream's section is untitled |
| `Gtk.ShortcutsGroup` × 2 | `Adw.ShortcutsSection` × 2 | correspondence — Adw has no group level; verified from `11-shortcuts.png` that two titled sections render as one scrolling page, which is what upstream's two groups do |
| `Gtk.ShortcutsShortcut` × 5 | `Adw.ShortcutsItem` × 5 | parity |

All five items keep their title, their `action_name` and their accelerator.
Accelerators are read from `Application::ACCELS` rather than retyped, so the
table that binds them is the table that advertises them.

Upstream's `app.about` names no registered action and its row is inert;
`ALIASES` maps it to `win.about`, which is what upstream actually registers
and binds F1 to, so the port's row works and the mismatch stays on the page.
Driven: all four accelerators asserted against `ACCELS`
(`test/drive_tally.rb:344-353`).
Messages: 5 titles + the dialog title, all byte-identical upstream msgids
(`Main Window`, `Counter Window`, `Quit Application`, `Keyboard Shortcuts`,
`About Tally`, `Close Window`).
**Verdict: parity**, with the screenshot caveat in Gap 6.

### Unit 12 — main menu · `tallymenu` → `lib/tally/main_menu.rb`

Two `Gio.Menu` items, `Keyboard Shortcuts` → `win.shortcuts` and
`About Tally` → `win.about`. No quit item on either side. Messages 2/2.
**Verdict: parity.**

### Unit 13 — about dialog · `aboutwin` → `lib/tally/about_dialog.rb`

`Adw.AboutDialog` 1/1. Application name, copyright, developer, licence
(`GPL_3_0`), website, translator credits and both `add_link` entries are
upstream's, with byte-identical msgids. `release_notes_version` is upstream's
`0.7.3` and the notes come from the AppStream file rather than a second
hand-kept heredoc, which is the same text by a shorter route.

`issue_url` points at this port's tracker and `version` reads
`0.1.0 (tally 0.7.3)`. Both are deliberate retargets of a URL and a version
number, not dropped behaviour; upstream's tracker cannot act on a bug in a
reimplementation.
Driven: `test/drive_tally.rb:359-373` asserts the icon, the release-notes version,
the notes text and the version string. Screenshot `12-about` (see Gap 6).
Messages 4/4. **Verdict: parity.**

### Unit 14 — application · `main.lua` app object + `main.c` → `lib/tally/application.rb`

| Thing | Upstream | Port | Verdict |
|---|---|---|---|
| Accelerators ×4 | `set_accels_for_action` | `ACCELS`, same four pairs | parity |
| `app.quit` action | `Gio.SimpleAction` | same | parity |
| `activate` | present the existing window | same | parity |
| `startup` | build and present | same, plus `Icons.install` and `Styles.install` | parity |
| `shutdown` | `writecfg()` | `store.write` | parity |
| Window uniqueness | `if app.active_window then return app.active_window` | memoized `#window` | correspondence — strictly better, since a pop-out is also an active window |
| `Adw.Application` | yes | `Gtk::Application` | correspondence — `Adwaita::Application` is unusable from these bindings; the windows are Adwaita |
| `resource_base_path` + GResource | yes | icon search path (`Icons`) | correspondence — Gap-free: all 16 icons ship |
| `-DDEVEL` | compile flag | `TALLY_DEVEL` env var, `.Devel` app id, `devel` class on both window kinds | correspondence |
| **load-failure message** | `main.c:131` | **nothing** | **gap — Gap 2** |

**Verdict: gap (Gap 2).**

### Unit 15 — styles · `main.lua` style section → `lib/tally/styles.rb`

The three stylesheets diff clean against upstream's `cssbase`, `csslight` and
`cssdark` — every selector, every declaration, in order. The only difference is
indentation (upstream tabs, the port two spaces inside a squiggly heredoc):

```
$ diff <normalised upstream cssbase>  <normalised port BASE>    # only leading whitespace
$ diff <normalised upstream csslight> <normalised port LIGHT>   # only leading whitespace
$ diff <normalised upstream cssdark>  <normalised port DARK>    # only leading whitespace
```

Two providers at priority 1,000,000, swapped on `notify::dark`: same mechanism.

Upstream's dark sheet writes `.colorselector checkbox.system` where every other
rule says `checkbutton` — `checkbox` is not a GTK element name, so the search
bar's "no colour" button is unstyled in dark mode upstream. The port copies the
typo verbatim, which is the right call: parity means the same rendering, and
fixing it here would make the two apps differ.

**Verdict: parity.**

### Unit 16 — config backend · `readcfg`/`writecfg`/`queuewrite` → `lib/tally/store.rb` + `lua_config.rb`

Not a widget unit; compared on behaviour.

| Behaviour | Upstream | Port |
|---|---|---|
| Path | `$XDG_CONFIG_HOME/tally/tally` | same |
| Atomic write | fill `tallynext`, rename over `tally` | same |
| Stale temp preferred on read | yes | same |
| Non-directory at `tally/` deleted | yes | same |
| Debounce | 1 s, counter trick | same, `DEBOUNCE_MS = 1000` |
| Geometry read off the window at write time | yes | same |
| Format | Lua source, `load()`ed | JSON |

The format change is the one place a port can destroy a user's data quietly, so
the port reads upstream's Lua grammar without evaluating it (`LuaConfig`),
copies the original to `tally.lua.bak`, rewrites as JSON once, and refuses to
write at all when neither reader understood the file. Upstream has no such
refusal — it is additive, and it is tested (`spec/tally/store_spec.rb`,
`spec/tally/lua_config_spec.rb`).

**Verdict: parity.**

### Units 17–20 — assets and metadata

| Unit | Upstream | Port | Verdict |
|---|---|---|---|
| 17 · icon bundle | 16 symbolic action icons in a GResource | the same 16 as files under `data/icons/hicolor/scalable/actions`, on the theme search path | parity — all 16 present, verified by name |
| 18 · application icon | 4 SVGs installed by `Makefile` | 4 SVGs under `data/icons/hicolor/{scalable,symbolic}/apps`, installed by `flake.nix` | parity |
| 19 · desktop entries | `.desktop` ×2 with Name/Comment/Keywords in en/fr/id/it | identical but for the `Icon=` id | parity |
| 20 · AppStream metainfo | `.metainfo.xml` ×2, 15 releases | identical but for the bugtracker URL; 15 releases | parity |

### Units 21–24 — the four with nothing opposite them

Gaps 1 (×3: two manifests and the CI), 3 and 4. Covered above.

### Units 25–26 — process

| Unit | Verdict |
|---|---|
| 25 · the colour selector's alignment | **gap — Gap 5** |
| 26 · driven and screenshotted against upstream | **gap — Gap 6** |

## Rules check

- Totals were not used as a verdict; every unit is compared on its own.
- Every extra port file is accounted for: `colors.rb`, `color_selector.rb`,
  `counter_drag_row.rb`, `main_menu.rb`, `empty_state.rb` and `icons.rb` are
  factored-out repeats of upstream blocks, each named in the mapping;
  `lua_config.rb` and `metainfo.rb` exist because the port changed the config
  format and reads release notes from AppStream rather than a heredoc.
- No gap was closed by citing a document. `PORTING.md` does not exist in this
  port, and `lib/tally/application.rb`'s Flatpak paragraph was treated as the
  excuse it is, not as authority — see `.reports/accountability-ensurance.md`.
- Text-axis findings are recorded in both ledgers; see
  `.reports/translation-parity.md`.

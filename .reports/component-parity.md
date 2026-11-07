# Component parity — tally / tally-rb

> **Superseded in part — read this first.** Gaps 1 and 2 of this audit are
> closed on `ruby` since it was written: `ColorSelector` takes `valign:` as a
> per-call-site argument defaulting to GTK's `FILL` and only `CounterMenu`
> passes `:center` (`counter.lua:201-207`), and `CounterDragRow#spin_button`
> sets no alignment at all (`counter.lua:471-473`). Both are now read back off
> the widget by the driver. The figures below — 19/22, 214 checks across 62
> steps — are the figures of *that* audit and have not been re-derived; the run
> in the session that closed the gaps was **289 of 289 checks passed, DRIVE
> OK**, 77 steps. Gap 3, nothing having been compared against upstream
> running, is untouched and is the one open component gap.

> **Reverified 2026-11-06 @ `0be085f`.** Re-ran the driver in this session:
> `nix develop --command xvfb-run -a ruby test/drive_tally.rb` → **289 of 289
> checks passed, DRIVE OK** (77 steps), matching the figure above exactly, not
> transcribed from it. No file under `lib/`, `exe/`, `data/` or `spec/` has
> changed since this ledger or the superseding note were written, so the
> 19/22-plus-fixes verdict and the counts in every per-unit table below still
> describe the tree at HEAD. Gap 3 remains open and unchanged: upstream is
> still a Flatpak-only Lua app that has not been built in this environment, so
> no claim here rests on watching the original run.

|  |  |
|---|---|
| Upstream | `origin/trunk` @ `e9986b010c950d2df91b682769b744c412348e0c` |
| Port | `ruby` @ `2f14cbbebfa83db2cf8c7349b0be9b108744b353` |
| Units | 22 |
| Units at parity | **19 / 22** |
| Verdict | **not at parity — 3 open gaps** |

Inventory and file mapping: `.reports/component-identification.md`.
Runtime gate re-run for this audit: `nix develop --command xvfb-run -a ruby
test/drive_tally.rb` → **214 of 214 checks passed, DRIVE OK**, 62 steps,
15 screenshots under `tmp/shots/`.

## What changed since the last audit

The last ledger was written at `0dfc40d8` and reported 6 gaps. Four have been
closed by `7d042e3` and `2f14cbb` and are verified closed here:

| Was | Now |
|---|---|
| Gap 1 — no Flatpak manifest, no CI | `data/org.rubygtkproject.Tally.json` and `.Devel.json` exist; `.github/workflows/flatpak.yml` builds **both** in Flathub's `gnome-49` image, where upstream's `ci.yml` builds one |
| Gap 2 — a failed start says nothing | `Application.boot` / `.build_application` print upstream's exact translated sentence to stderr and exit non-zero; driven, step 34 |
| Gap 3 — `tally.doap` and the README screenshot absent | `data/org.rubygtkproject.Tally.doap`, `data/screenshot.png`, referenced from `README.md:24` |
| Gap 4 (part) — the two drag-and-drop bugs | `2f14cbb` fixed the `GLib::Value` unwrap and the content-provider gtype; driven, steps 47–49 |

Gaps 5 and 6 of that ledger are still open and are Gaps 1 and 3 below.

## The headline

The four axes come out even nearly everywhere, and the comparison is not a
scan: `component-scan.sh` cannot read Lua and returns **zero rows** for
upstream, so every upstream row in this ledger was censused by hand. On that
census:

- **Count** — every widget instance upstream builds has a counterpart. The
  three colour selectors, which upstream open-codes three times, are one class
  used three times; the 7-check repeater is 7 checks at each site.
- **Style** — the stylesheet is upstream's three heredocs transcribed verbatim
  into `Styles::BASE`, `::LIGHT` and `::DARK`, including upstream's own
  `.colorselector checkbox.system` typo in the dark sheet. The 22 attached
  classes are the same set. Verified rendering: steps 39–42 parse both
  providers with errors unswallowed and swap them on `notify::dark`.
- **Behaviour** — all 18 upstream signals and all 4 actions are wired, and
  each one is *fired* by the driver, not merely connected.
- **Text** — 41 code msgids and 23 metadata msgids, byte-identical, both
  directions empty. See `.reports/translation-parity.md`.

Three things are not true, and two of them are one-line divergences that no
screenshot of the port alone could ever surface.

---

## Gap 1 — the colour selector is centred at two sites upstream does not centre

`lib/tally/color_selector.rb:40` sets `self.valign = :center` in the
constructor, so it applies at all three call sites.

Upstream sets it at exactly one:

- `counter.lua:201-207` — `counter:colorrow`'s box: `valign = "CENTER"`.
- `main.lua:317-321` — `searchcolorbox`: orientation, spacing 6 and
  `extra_css_classes` only. **No valign**, so it defaults to `FILL`.
- `main.lua:567-571` — `tallycolorbox`: the same three properties. **No
  valign.**

Port: `lib/tally/search_bar.rb:61` and
`lib/tally/new_counter_dialog.rb:84` both build `ColorSelector` and both
therefore get `CENTER`. In the search bar the box is one of two children of a
vertical box with 6px spacing and 6px margins, and in the dialog it is the
middle of three children of a vertical box with 12px spacing — in both places
`FILL` and `CENTER` lay out differently once the box has slack, and the
28×28px check buttons do not fill their row.

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gtk.Box` (search colour box) | 1 | 1 | ✓ `colorselector` | — | — | **gap**: `valign = CENTER` upstream does not set |
| `Gtk.Box` (dialog colour box) | 1 | 1 | ✓ `colorselector` | — | — | **gap**: same |
| `Gtk.Box` (`counter:colorrow`) | 1 | 1 | ✓ `colorselector` | — | — | parity |
| `Gtk.CheckButton` ×7, each site | 7 | 7 | ✓ per-colour classes; first unclassed in `:radio`, `system` in `:multi` | ✓ `notify::active` | ✓ tooltips from `Colors.name` | parity |

**Owed:** `valign` becomes a per-site argument, defaulting to the GTK default
and passed as `:center` only from `CounterMenu`.

## Gap 2 — the drag preview's spin button is centred and upstream's is not

`lib/tally/counter_drag_row.rb:49` sets `spin.valign = :center`.

`counter.lua:471-473` — `counter:duplicate` builds
`Gtk.SpinButton.new_with_range(0, 1000000, 1)` and sets nothing else on it. The
row's *real* spin button (`counter.lua:48-50`) does get `valign = "CENTER"`;
the preview's deliberately does not, so upstream's drag icon shows a
full-height spin button and the port's shows a centred one.

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ExpanderRow` (preview) | 1 | 1 | ✓ colour class, `expanded` copied | — | ✓ title | parity |
| `Gtk.Image` (preview handle) | 1 | 1 | ✓ `drag-handle` | — | — | parity |
| `Gtk.SpinButton` (preview) | 1 | 1 | — | — | — | **gap**: `valign = CENTER` upstream does not set |
| `CounterMenu` in duplicate mode | 1 | 1 | — | ✓ nothing wired, every control desensitised | ✓ | parity |

Driven: step 46 asserts the preview's title, colour class, expanded state and
value, and `test/drive_tally.rb:580-587` asserts every control on it is
insensitive. **No check looks
at the preview's alignment**, which is why this survived a green run.

**Owed:** drop the `valign` from `CounterDragRow#spin_button`, or state why
the preview should differ from upstream's.

## Gap 3 — nothing has been compared against upstream running

Every "looks the same" claim in this ledger rests on reading two source trees
and on the port's own 15 screenshots. Upstream is a Flatpak-only Lua app
(`flatpak-builder .build ca.vlacroix.Tally.json --user --install` is its only
documented route; the manifest builds Lua 5.4 and LuaGObject from source inside
`org.gnome.Sdk`) and it has not been built on this machine, so there is no
upstream side to compare against.

`component-parity` Step 4 says so plainly: reading a class name tells you
nothing about colour, spacing or weight. The stylesheet being transcribed
verbatim makes this cheaper than it would otherwise be — the only thing left to
be wrong is attachment, which the `css` axis above covers — but it does not
close the row.

**Owed:** build upstream's Flatpak, run both apps at the same size and compare
the 15 states the driver already shoots.

**2026-11-06:** not attempted this round. `flatpak-builder` here would need
network access to fetch and compile `lua-5.4.7.tar.gz` and clone+build
`LuaGObject` from source inside `org.gnome.Sdk` — a multi-GB download and a
from-source C/Lua build, not something to start inside a task already
budgeted for the gettext/data-file work above. Still the single largest open
item in this ledger.

---

## Units at parity — the full ledger

Every row below says `parity` on all four axes. The `Driven` column names the
driver step that fires the behaviour; a row with no step is noted.

### Unit 1 — the application  ·  `main.lua` app object + `main.c` → `lib/tally/application.rb`, `exe/tally`, `lib/tally/rb/version.rb`

| Component | Up × | Port × | CSS | Signals / actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| application object | 1 | 1 | — | ✓ `startup`, `activate`, `shutdown` | — | parity — `Adw.Application` → `Gtk::Application`, a binding limitation (`Adwaita::Application` is unusable from Ruby), recorded |
| `app.quit` action | 1 | 1 | — | ✓ `activate` → `app.quit` | — | parity |
| accelerators | 4 | 4 | — | ✓ identical table | — | parity (driven, step 38) |
| load-failure branch | 1 | 1 | — | — | ✓ `An unrecoverable error occurred when loading Tally, preventing the program from starting.\n` byte-identical, trailing newline included | parity (driven, step 34) |
| `devel` build | 1 | 1 | ✓ `devel` on both window kinds | — | — | parity (driven, step 57) — `-DDEVEL` → `TALLY_DEVEL`, and the port applies `devel` to the pop-out too, where `is_devel` is out of scope in upstream's `counter.lua` and the class never lands. An **explained divergence**, in the port's favour |

Explained extra: the port sets `icon_name` on both windows, which upstream does
not — upstream leans on the installed `.desktop` entry, which a development run
of the port does not have. Harmless, stated here so it is not an unexplained
extra.

Messages: 1 upstream, 1 in the port. Driven: steps 34, 38, 57.

### Unit 2 — the main window  ·  `main.lua` `window` class → `lib/tally/main_window.rb`

| Component | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | ✓ `devel` | ✓ `close-request` | ✓ `Tally` | parity — 500×600, 360×294, maximized from config |
| `Adw.ToolbarView` | 1 | 1 | — | — | — | parity — `top_bar_style` swung by `refresh_toolbar` and `layout_changed` |
| `Adw.HeaderBar` | 1 | 1 | — | — | — | parity |
| `Adw.WindowTitle` | 1 | 1 | — | — | ✓ `Tally` + `""` | parity |
| `Gtk.Button` new | 1 | 1 | — | ✓ `clicked` | ✓ `Create a new counter` | parity (step 6) |
| `Gtk.Button` delete | 1 | 1 | ✓ `destructive-action` | ✓ `clicked` | ✓ `Delete selected counters` | parity (step 16) |
| `Gtk.ToggleButton` select | 1 | 1 | — | ✓ `notify::active` | ✓ `Select counters to delete` / `Stop selecting without deleting anything` | parity (steps 13-14) |
| `Gtk.ToggleButton` search | 1 | 1 | — | ✓ `notify::active` via `bind_property` | ✓ `Filter counters by name and/or color` | parity (step 18) |
| `Gtk.MenuButton` | 1 | 1 | — | — | ✓ `Menu` | parity (steps 35-37) |
| `Adw.Breakpoint` | 1 | 1 | — | ✓ `apply`, `unapply` | — | parity (steps 43-45) — `new_length` is unbound in Ruby, so `BreakpointCondition.parse("max-width: 400px")` spells the same condition |
| `win.shortcuts`, `win.about` | 2 | 2 | — | ✓ `activate` ×2 | — | parity (steps 29, 31) |
| pack order | start: new, delete, select; end: menu, search | identical | — | — | — | parity |

`refresh_toolbar`: ✓ hides the select button and swaps to the status page when
empty, `FLAT`; list and `RAISED_BORDER` otherwise (steps 1, 60-61).
`close_popouts` on `close-request`: wired at `main_window.rb:97` → `:333`.
**Not driven** — see `.reports/test-parity.md`, coverage gap C1.

Messages: 9 upstream, 9 in the port. Stylesheet: n/a. Driven: 6, 13-18, 29,
31, 35-38, 43-45, 60-61.

### Unit 3 — the counter list  ·  `main.lua` `lbox`/`clamp`/`multi` → `lib/tally/counter_list.rb`

| Component | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gtk.ScrolledWindow` | 1 | 1 | — | — | — | parity — `hscrollbar_policy = NEVER` |
| `Adw.MultiLayoutView` | 1 | 1 | — | — | — | parity |
| `Adw.Layout` | 2 | 2 | — | — | — | parity |
| `Adw.LayoutSlot` | 2 | 2 | — | — | — | parity |
| `Adw.Clamp` | 1 | 1 | — | — | — | parity — 600, margins 24/24/12/12 |
| `Gtk.ListBox` | 1 | 1 | ✓ `tally-list`, `boxed-list` ↔ `separators` | ✓ `row-activated`, `set_filter_func` | — | parity (steps 15, 19, 43-45) |
| `enlarge` / `shrink` | 2 | 2 | ✓ class swap + top-bar style | — | — | parity (steps 43-45) |
| `counter:scroll` → `viewport.scroll_to` | 1 | 1 | — | — | — | parity by construction; the driver asserts only that the call returns, not that the view moved — coverage gap C5 |
| `window:scrollbottom` | 1 | 1 | — | — | — | same, 20 ms delay matched |

Messages: 0. Driven: 1, 15, 19, 43-45, 60-61.

### Unit 4 — the filter bar  ·  `main.lua` searchbar → `lib/tally/search_bar.rb`

| Component | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gtk.SearchBar` | 1 | 1 | — | ✓ `notify::search-mode-enabled`, `connect_entry`, `bind_property` BIDIRECTIONAL, `key_capture_widget` | — | parity — and the port fixes an upstream bug: `main.lua:503` assigns `key_capture_widget = window`, the *class table*, not the window instance, so upstream's type-to-search never works. **Not driven** — coverage gap C4 |
| `Gtk.Box` outer | 1 | 1 | — | — | — | parity — vertical, 6, margins 6/6 |
| `Gtk.SearchEntry` | 1 | 1 | — | ✓ `search-changed` | ✓ `Filter by name…` (with U+2026, not three dots) | parity (step 18) |
| colour box + 7 checks | 1 + 7 | 1 + 7 | ✓ all seven classes incl. `system` | ✓ `notify::active` | ✓ | **Gap 1** on `valign` |
| filter predicate | 1 | 1 | — | — | — | parity — closed bar passes all; empty query + no tick passes all; otherwise colour ∧ substring, case-insensitive, plain not pattern (steps 18-24) |
| tick clearing on toggle | 1 | 1 | — | — | — | parity (steps 23-24) |

Messages: 1 upstream, 1 in the port. Driven: 18-24.

### Unit 5 — the empty state  ·  `main.lua` `statuspage` → `lib/tally/empty_state.rb`

| Component | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.StatusPage` | 1 | 1 | — | — | ✓ `No Counters` | parity — `icon_name = "tally-symbolic"`, resolved from the shipped theme (step 2) |
| `Gtk.Button` | 1 | 1 | ✓ `suggested-action`, `pill` | ✓ `clicked` | ✓ `Create Counter` | parity — margins 40/40 (step 3) |

Messages: 2 upstream, 2 in the port. Driven: 1, 3, 60-61.

### Unit 6 — the new-counter dialog  ·  `main.lua` `window:tallydialog` → `lib/tally/new_counter_dialog.rb`

| Component | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.Dialog` | 1 | 1 | — | — | ✓ `New Counter` | parity — upstream rebuilds per activation, the port keeps one and blanks it in `#open`, which is the same state a user meets |
| `Adw.ToolbarView` + `Adw.HeaderBar` | 1 + 1 | 1 + 1 | — | — | — | parity |
| `Gtk.Box` | 1 | 1 | — | — | — | parity — vertical, 12, margins 12 |
| `Gtk.Entry` | 1 | 1 | ✓ `error` while empty | ✓ `changed` | ✓ `Name` | parity — `halign = FILL` (step 4) |
| colour box + 7 checks | 1 + 7 | 1 + 7 | ✓ first unclassed, six accents classed, radio-grouped | ✓ `notify::active` | ✓ | **Gap 1** on `valign` |
| `Gtk.Button` create | 1 | 1 | ✓ `suggested-action` | ✓ `clicked` | ✓ `Add this counter to the list` | parity — insensitive until named, `halign = CENTER` (step 4) |
| `Adw.ButtonContent` | 1 | 1 | — | — | ✓ `Add to List` | parity |

Create path: ✓ registers the counter, appends the row, writes, scrolls to the
bottom, focuses the new row, refreshes the toolbar, closes the dialog
(steps 4-8).

Messages: 4 upstream, 4 in the port. Driven: 3-8.

### Unit 7 — the primary menu  ·  `main.lua` `tallymenu` → `lib/tally/main_menu.rb`

| Component | Up × | Port × | CSS | Signals / actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gio.Menu` | 1 | 1 | — | — | — | parity — two items, no sections, no quit item |
| item → `win.shortcuts` | 1 | 1 | — | ✓ | ✓ `Keyboard Shortcuts` | parity (step 36) |
| item → `win.about` | 1 | 1 | — | ✓ | ✓ `About Tally` | parity (step 37) |

Messages: 2 upstream, 2 in the port. Driven: 35-37.

### Unit 8 — the About dialog  ·  `main.lua` `aboutwin` → `lib/tally/about_dialog.rb` + `lib/tally/metainfo.rb`

| Component | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.AboutDialog` | 1 | 1 | — | — | ✓ `Tally`, ✓ `translator-credits` | parity — one instance, re-presented |
| `application_icon` | 1 | 1 | — | — | — | parity — the application id (step 31) |
| `license_type` | GPL_3_0 | `:gpl_3_0` | — | — | — | parity |
| `copyright`, `developer_name`, `website` | 3 | 3 | — | — | — | parity — byte-identical to upstream's, including `Copyright © 2024–2025 Victoria Lacroix` and the en-dash. **Not driven** — coverage gap C2 |
| `issue_url` | 1 | 1 | — | — | — | explained divergence: the port's own tracker, because upstream's cannot act on bugs in a reimplementation |
| `add_link` | 2 | 2 | — | — | ✓ `Translate this app!`, ✓ `Support this app!` | parity by reading `about_dialog.rb:36-39, 62`. **Not driven** — coverage gap C2, and these are two translatable msgids no check asserts |
| `release_notes_version` | 1 | 1 | — | — | — | parity — `0.7.3`, from the AppStream file rather than a `-DVERSION` (step 31) |
| `release_notes` | 1 | 1 | — | — | — | parity — the port reads the `0.7.3` `<description>` out of `data/org.rubygtkproject.Tally.metainfo.xml`, which is byte-identical to upstream's, so the string shown is upstream's heredoc exactly. **Better than upstream**, which keeps a second hand-maintained copy; the heredoc is unmarked upstream and remains untranslatable here, which is upstream's debt, not the port's (step 31) |
| `version` | 1 | 1 | — | — | — | explained divergence: `0.1.0 (tally 0.7.3)` names both, where upstream names one |

Messages: 5 upstream, 5 in the port. Driven: 31-32, 37.

### Unit 9 — the shortcuts dialog  ·  `main.lua` `newshortcutwindow` → `lib/tally/shortcuts_dialog.rb`

Substitution, recorded with its reason: the entire `Gtk.Shortcuts*` family was
deprecated in GTK 4.18 in favour of `Adw.ShortcutsDialog`, which has no group
level. Upstream's one section holding two groups becomes two sections.

| Component | Up × | Port × | CSS | Signals / actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| window / dialog | 1 | 1 | — | — | ✓ | parity — upstream rebuilds and makes it modal + transient; `Adw.ShortcutsDialog` is presented against a parent, so one instance |
| section titles | 2 groups | 2 sections | — | — | ✓ `Main Window`, ✓ `Counter Window` | parity |
| items | 5 | 5 | — | ✓ `action_name` on each | ✓ `Quit Application` ×2, `Keyboard Shortcuts`, `About Tally`, `Close Window` | parity (step 29) |
| accelerators shown | 5 | 5 | — | — | — | parity — read from `Application::ACCELS`, so the displayed string cannot drift from the bound one |
| `app.about` → `win.about` | — | 1 | — | ✓ | — | explained divergence: upstream's item names `app.about`, an action it never registers, so that row is inert upstream. `ALIASES` records upstream's literal and resolves it, so the row works and the mismatch stays readable |

Upstream's section `title` is `app_title`, an undefined Lua global, hence nil.
The port titles the dialog `Keyboard Shortcuts` — an existing msgid, not a new
one.

Messages: 5 upstream, 5 in the port (all five already counted above). Driven:
29-30, 36.

### Unit 10 — the stylesheet  ·  `main.lua` `cssbase`/`csslight`/`cssdark` → `lib/tally/styles.rb`

The port has no `.css` file; the three sheets are heredocs.
`Styles::BASE + Styles::LIGHT` and `BASE + DARK` were diffed against
`main.lua`'s `cssbase .. csslight` and `cssbase .. cssdark`: **identical modulo
leading whitespace** (upstream indents with tabs inside its Lua long strings;
`<<~CSS` strips the heredoc indent). Every declaration, every selector, every
`color-mix()` percentage and every `var(--colour-N)` matches, and so does
upstream's own typo — the dark sheet's last rule is
`.colorselector checkbox.system`, not `checkbutton`, in both.

| Component | Up × | Port × | Verdict |
|---|---:|---:|---|
| `Gtk.CssProvider` | 2 | 2 | parity — base+light, base+dark |
| priority | 1000000 | 1000000 | parity |
| `Adw.StyleManager` `notify::dark` swap | 1 | 1 | parity (steps 40-42) |
| variant sheets | 2 | 2 | parity — no high-contrast variant on either side |

Platform classes used but defined by GTK/libadwaita, correctly absent from both
sheets: `circular`, `boxed-list`, `separators`, `numeric`,
`destructive-action`, `suggested-action`, `pill`, `devel`, `error`, `spin`,
`checked`, `drag-handle`.

`load_from_string` vs `load_from_data` is a bindings-vintage branch, not a
divergence. Driven: 39-42, with GTK's CSS parser errors routed to a failure
rather than swallowed.

### Unit 11 — one row in the list  ·  `counter.lua` constructor → `lib/tally/counter_row.rb`

| Component | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ExpanderRow` | 1 | 1 | ✓ `spin`, colour class (dynamic, 6 values), `checked`, `error` | ✓ `notify::expanded` → scroll after 50 ms | ✓ title is the counter's name | parity (steps 9, 25, 28) |
| `Gtk.Image` handle | 1 | 1 | ✓ `drag-handle` | — | — | parity (step 13) |
| `Gtk.CheckButton` | 1 | 1 | — | ✓ `notify::active` → `checked` class | — | parity (steps 13-15) |
| `Gtk.Label` count | 1 | 1 | — | — | — | parity — hidden, `margin_start = 18`, `halign = END`, `hexpand = false` (steps 13-14) |
| `Gtk.SpinButton` | 1 | 1 | — | ✓ `notify::value` | — | parity — 0–1 000 000 step 1 page 10 climb 1 digits 0, which is what `new_with_range` produces; `valign = CENTER`, first child `xalign = 1` (step 9) |
| `Gtk.DragSource` (controller) | 1 | 1 | — | ✓ `prepare`, `drag-begin` | — | parity — `MOVE`, `CAPTURE` (steps 47-48) |
| `Gtk.DropTarget` (controller) | 1 | 1 | — | ✓ `drop` | — | parity — `MOVE`, `preload`, `Adw.ExpanderRow` gtype (steps 48-49) |
| drag preview list box | 1 | 1 | ✓ `tally-list`, `boxed-list` | — | — | parity — sized to the row's allocation, `drag_highlight_row`, hotspot at the grab point (step 46) |
| suffix-box `hexpand` | 1 | 1 | — | — | — | parity — `child.last_child.hexpand = true` |
| `setcheckmode` | 1 | 1 | — | — | — | parity — both branches, including collapsing and `enable_expansion` (steps 13-14) |
| `counter:read` | 1 | 1 | — | — | — | parity — dead upstream, live here because the pop-out pushes values the other way (step 10) |
| `row_activated` → tick | 1 | 1 | — | ✓ | — | parity (step 15) |

Divergence, in the port's favour and recorded: upstream's `counter:popout`
reassigns `self.spinbtn.on_notify.value`, unhooking this row's handler, so with
a pop-out open the count label freezes and edits stop being written. The port
routes both windows through `Counter#value` and `#on_change` instead, so the
signal count reads 2 upstream against 1 here while the behaviour is strictly
better. Verified both ways in steps 10 and 12.

Messages: 0 of its own. Driven: 9-15, 25, 28, 46-49.

### Unit 12 — the counter model  ·  `counter.lua` fields/registries → `lib/tally/counter.rb`

Not a widget unit; compared as data plumbing. Upstream's two module-level Lua
tables (`counters`, `counterrows`) become class-level `Counter.counters` and
`Counter.rows` with the same jobs — ordered serialization source and
row→counter lookup. `counter:getcolor`/`setcolor` → `#color_key`/`#color=`;
`counter:serialize` → `#serialize` (a Hash; `Store` encodes). `counter:delete`
notifies subscribers *before* leaving the registry, so they can still read its
index, which is what upstream's inline `table.remove(counters, row:get_index() + 1)`
relies on.

Upstream's `serialize` dumps every scalar field it finds, so its file also
carries `checked`, `checkmode`, `drag_x` and `drag_y`; `readcfg` reads only
name, value and colour. The port writes the three that are read. Equal
behaviour, smaller file. Specs: `spec/tally/counter_spec.rb`, 17 examples.

### Unit 13 — the row's disclosure  ·  `counter.lua` `counter:createmenu` → `lib/tally/counter_menu.rb`

| Component | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.EntryRow` | 1 | 1 | — | ✓ `changed` | ✓ `Name` | parity — `sensitive = !duplicate` (step 27) |
| `Adw.ActionRow` colour | 1 | 1 | — | — | ✓ `Color` | parity — `sensitive = !duplicate` (step 28) |
| `Adw.ActionRow` reorder | 1 | 1 | — | — | ✓ `Reorder in List` | parity — row itself always sensitive, as upstream |
| `Adw.ActionRow` pop-out | 1 | 1 | — | — | ✓ `Show in a Separate Window` | parity |
| colour box + 7 checks | 1 + 7 | 1 + 7 | ✓ | ✓ `notify::active` | ✓ | parity — this is the one site upstream *does* centre |
| order box | 1 | 1 | — | — | — | parity — horizontal, 6, `halign = END`, `valign = CENTER` |
| `Gtk.Button` ×4 order | 4 | 4 | — | ✓ `clicked` ×4 | ✓ all four tooltips | parity — `sensitive = !duplicate`; up gets `valign = CENTER`, as upstream (step 26) |
| `Gtk.Button` pop-out | 1 | 1 | — | ✓ `clicked` | ✓ `Create a new window for this counter` | parity — `halign = END`, `hexpand`, `valign = CENTER` (step 11) |
| `duplicate` mode | 1 | 1 | — | ✓ nothing wired | ✓ | parity (step 46) |

Reorder semantics: ✓ both orders move together; ✓ up and down skip unmapped
rows; ✓ top/bottom are prepend/append; ✓ every move queues a write and scrolls
after 50 ms. Rename refusing the empty string and adding `error` to the row: ✓
(step 27). Renaming retitles the row *and* the pop-out: ✓ (step 27).

Messages: 9 upstream, 9 in the port. Driven: 11, 25-28, 46.

### Unit 14 — the pop-out window  ·  `counter.lua` `counter:popout` → `lib/tally/counter_window.rb`

| Component | Up × | Port × | CSS | Signals / actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | ✓ `devel` (the port applies it; upstream's `is_devel` is out of scope in `counter.lua`, so upstream's never does) | ✓ `close-request` → destroy | ✓ `<name> — Tally`, with the em dash | parity — 400×300, 360×294, `hide_on_close` (steps 11, 52) |
| `Adw.ToolbarView` | 1 | 1 | ✓ colour class (dynamic) | — | — | parity — `width_request = 300` |
| `Adw.HeaderBar` | 1 | 1 | — | — | — | parity |
| `Adw.WindowTitle` | 1 | 1 | — | ✓ `bind_property("text", …, BIDIRECTIONAL)` against the menu's EntryRow | ✓ `Tally` as subtitle | parity (step 27) |
| `Gtk.WindowHandle` | 1 | 1 | — | — | — | parity |
| `Gtk.Box` ×3 | 3 | 3 | ✓ `popout` on the number box | — | — | parity — spacings 36 / 24 / 48, margins 24, both centred |
| `Gtk.Label` | 1 | 1 | ✓ `numeric` | — | — | parity — `width_request = 240`, `halign = CENTER` (step 12) |
| `Gtk.Button` ×2 | 2 | 2 | ✓ `circular` ×2 | ✓ `clicked` ×2 | ✓ `Decrement by 1`, `Increment by 1` | parity — each insensitive at its end of the range (steps 12, 51) |
| `win.close` action | 1 | 1 | — | ✓ `activate` | — | parity (step 52) |

Messages: 4 upstream, 4 in the port. Driven: 11-12, 27-28, 50-52.

### Unit 15 — the drag preview  ·  `counter.lua` `counter:duplicate` → `lib/tally/counter_drag_row.rb`

See **Gap 2**. Everything else is parity (step 46).

### Unit 16 — the colour vocabulary  ·  `main.lua` `lib.getcolorname` → `lib/tally/colors.rb`

| Component | Up × | Port × | Text | Verdict |
|---|---:|---:|:-:|---|
| `getcolorname` | 1 | 1 | ✓ `No color`, `Red`, `Orange`, `Yellow`, `Green`, `Blue`, `Purple` | parity — nil and `"system"` both answer `No color`, as upstream's first branch does (step 53) |
| `nil` ↔ `"system"` conversion | inline, four places | `Colors.key` / `.value` | — | parity |

Messages: 7 upstream, 7 in the port. Driven: 53. Specs:
`spec/tally/colors_spec.rb`.

### Unit 17 — the colour selector  ·  three upstream sites → `lib/tally/color_selector.rb`

Three upstream copies, one class. `:radio` is `counter:colorrow` and the
dialog; `:multi` is the search bar. The two differences between upstream's
copies are exactly the two the `mode:` argument makes:

- first button classed `system` in `:multi` (`main.lua:316`) and unclassed in
  `:radio` (`main.lua:471-474`) — ✓ `classed?`;
- grouped in `:radio`, ungrouped in `:multi` — ✓ `grouped?`.

Divergence, recorded: upstream's `notify::active` handlers fire on
deactivation as well, so switching red→blue runs `setcolor("red")` before
`setcolor("blue")` and lands correctly only because GTK deactivates first. The
port ignores the deactivation edge in `:radio` mode. Same outcome, one fewer
spurious write. Driven: 21-24, 28.

**Gap 1** is this unit's `valign`.

### Unit 18 — the store  ·  `main.lua` `readcfg`/`writecfg`/`queuewrite` → `lib/tally/store.rb`

| Behaviour | Up | Port | Verdict |
|---|---|---|---|
| path | `$XDG_CONFIG_HOME/tally/tally` | identical | parity |
| atomic write | fill `tallynext`, rename over `tally` | identical | parity (step 5) |
| temp preferred on read | ✓ | ✓ | parity |
| temp skipped if it does not parse | ✓ | ✓ | parity (step 55) |
| non-directory at `tally/` removed | ✓ | ✓ | parity |
| missing file seeded | `return {}` | `{}` as JSON | parity |
| debounce | 1 s, pending-count trick | identical | parity by reading; **not driven** — coverage gap C3 |
| geometry read off the window at write time | ✓ | ✓ | parity |
| shutdown writes outright | `app:on_shutdown` | `Application#shutdown` | parity by reading; **not driven** — coverage gap C6 |
| format | Lua source, `load()`ed | JSON | **explained divergence**: `load()` on a file in a user's home is arbitrary code execution, which upstream only survives because it runs inside a Flatpak sandbox |
| upstream config readable | — | `LuaConfig` parses upstream's grammar without evaluating it, imports once, keeps `tally.lua.bak` | parity restored by a route upstream does not have (step 56) |
| unreadable config refused rather than clobbered | upstream overwrites | the port refuses to write | **better than upstream**, recorded (step 55) |

`LuaConfig` handles all three `%q` traps: C99 hex floats (`0x1.8p+1`), bare
`true`/`false` from `"maximized = %q"`, and `\`+newline escapes. Specs:
`spec/tally/store_spec.rb`, `spec/tally/lua_config_spec.rb`. Driven: 5, 33,
55-56, 62.

### Unit 19 — the icons  ·  `data/tally.gresource.xml` + Makefile → `lib/tally/icons.rb`

| Component | Up × | Port × | Verdict |
|---|---:|---:|---|
| symbolic action icons | 16 | 16 | parity — **byte-identical**, all 16 verified with `cmp` |
| application icons | 4 | 4 | parity — `.svg` and `-symbolic.svg` for both ids, under the renamed id |
| delivery | GResource + `resource_base_path` | a `hicolor` theme tree on the icon search path | explained correspondence: compiling a GResource would need a `glib-compile-resources` step |

Driven: step 2 resolves all 16 action icons plus both application icons out of
the live icon theme, and `Icons#complete?` checks every shipped file is on disk.

### Unit 20 — the catalogue reader  ·  `main.c` `lua_gettext` → `lib/tally/locale.rb`

`setlocale` + `bindtextdomain("messages", …)` + `textdomain("messages")` +
`gettext(3)` become a po reader with `LANGUAGE`/`LC_ALL`/`LC_MESSAGES`/`LANG`
precedence, `fr_CA` before `fr`, fuzzy and obsolete entries dropped, and
fall-back-to-msgid. Driven: step 54 and, for this audit, live under
`LANGUAGE=fr`, `it` and `id`. Specs: `spec/tally/locale_spec.rb`.

The delivery mechanism is a divergence with real costs, and it is an open item
in `.reports/translation-parity.md`, not here.

### Unit 21 — the AppStream reader  ·  `main.lua`'s release-notes heredoc → `lib/tally/metainfo.rb`

One reader for `data/org.rubygtkproject.Tally.metainfo.xml`, supplying the
About dialog's `release_notes_version` and `release_notes` from the file rather
than a second copy. Driven: step 31. Specs: `spec/tally/metainfo_spec.rb`.

### Unit 22 — project metadata  ·  four upstream files → `data/`

| Upstream | Port | Diff |
|---|---|---|
| `ca.vlacroix.Tally.metainfo.xml` | `data/org.rubygtkproject.Tally.metainfo.xml` | 3 lines: `<id>`, `<url type="bugtracker">`, `<launchable>`. Every `<name>`, `<summary>`, `<p>`, `<li>`, `<caption>` and all 14 `<release>` blocks byte-identical |
| `ca.vlacroix.Tally.Devel.metainfo.xml` | `.Devel` counterpart | same shape |
| `ca.vlacroix.Tally.desktop` | `data/org.rubygtkproject.Tally.desktop` | 1 line: `Icon=` |
| `ca.vlacroix.Tally.Devel.desktop` | `.Devel` counterpart | same |
| `ca.vlacroix.Tally.json`, `.Devel.json` | `data/org.rubygtkproject.Tally{,.Devel}.json` | the modules differ by language, as they must; `app-id`, runtime 49, SDK, command and all four `finish-args` identical |
| `.github/workflows/ci.yml` | `.github/workflows/flatpak.yml` | branch `trunk`→`ruby`; builds both manifests where upstream builds one; and the port names its bundle after the app id rather than leaving upstream's `bundle: palette.flatpak`, which is a copy-paste from another project |
| `tally.doap` | `data/org.rubygtkproject.Tally.doap` | re-identified, and the port uses the canonical RDF and DOAP namespace URIs where upstream writes `http://w3.org/…` and `htp://usefulinc.com/…`, both of which put every element outside DOAP |
| `tally.png` | `data/screenshot.png` | the port's own app, shot by `test/shoot_screenshot.rb`, referenced from `README.md:24` |

Messages: 23 metadata msgids, identical sets both directions. Neither side
extracts them into a catalogue — see `.reports/translation-parity.md`.

---

## Rules check

- No row says `n/a`, `not applicable`, `out of scope` or `does not carry over`.
  Three rows are gaps; every other row names where its counterpart lives.
- Every extra in the port is explained in place: the two `icon_name`
  assignments, `Colors`, `ColorSelector`, `Metainfo`, `LuaConfig`, the
  `ShortcutsDialog` aliases, the JSON format, the refusal-to-clobber, and the
  five upstream bugs the port does not reproduce.
- The two binding limitations that shape the port (`Adwaita::Application`,
  `BreakpointCondition.new_length`) are recorded as *reasons a correspondence
  is spelled differently*, never as reasons a row is closed.
- The CSS axis was checked on both halves: which classes are attached, and
  whether the port's sheet defines them. Both hold.
- Gap 3 is the honest statement that Step 4 of the skill — run both and look —
  has not been performed on the upstream side.

## Reverified 2026-11-07 @ `f3f4911`

Independently re-ran the driver this session: `nix develop --command
xvfb-run -a ruby test/drive_tally.rb` → **289 of 289 checks passed, DRIVE OK**
(77 steps), matching the figure the superseding note above already carries,
not transcribed from it. `git diff --stat c95adfa HEAD -- lib exe spec test`
is empty, so no unit's widget/CSS/signal/text table has moved since the
19/22-plus-fixes verdict was written.

What *did* land since then — `f3f4911`, "Port data/*.desktop and
data/*.metainfo.xml onto the po/ gettext pipeline" — touches only Unit 22
(project metadata). `data/*.desktop` and `data/*.metainfo.xml` are now
generated from new `.in` templates through `rake data`, verified byte-for-byte
unchanged against the previously-committed files
(`spec/tally/metainfo_spec.rb`, `rake check`'s `data:check` target, both
re-run this session). Unit 22's row-by-row diff table is unaffected because
the generated output is identical to what it replaced; the only change of
substance is translation delivery, which belongs to
`.reports/translation-parity.md` and is recorded there, not here.

Units remain 19/22 at parity. Gap 3 (nothing compared against upstream
*running*) remains open, unattempted this round for the same reason as last:
building upstream's Flatpak needs network access to fetch and compile Lua 5.4
and LuaGObject from source inside `org.gnome.Sdk`, out of scope for a pass
budgeted for the data-file work and this re-audit. **Still the single largest
open item in this ledger**, and it is not getting smaller by being repeated —
a future round should budget for the Flatpak build specifically rather than
re-stating that it has not happened.

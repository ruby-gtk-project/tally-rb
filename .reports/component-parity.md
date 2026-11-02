# Component parity — tally / tally-rb

|  |  |
|---|---|
| Upstream | `origin/trunk` @ `e9986b010c950d2df91b682769b744c412348e0c` |
| Port | `ruby` @ `eb1f26ae78a5584b17c03f2e2a646a9a0051ad54` |
| Units with parity | **0 / 26** — 14 units are clean on reading but **none** has been driven or screenshotted, which Steps 4–5 require; 6 units have no port file at all; 6 carry a named gap |
| Verdict | **not at parity** |

Inventory and file mapping: `component-identification.md`.

## The headline

The widget, CSS and signal axes are in unusually good shape for a port this
young — 20 of 26 upstream components have a port file, the stylesheet is
byte-identical, and the per-component reading below finds the widget trees,
counts, classes and handlers matching almost everywhere. That is the finding to
be suspicious of, so it is worth saying plainly where the gaps are instead:
**they are not in the widget code.** They are in the assets and metadata the
app needs to exist as an installed application, in the one behaviour axis the
shortcuts dialog dropped, and in the fact that nothing here has been run.

## Units with no port file at all — 6 gaps

### Gap 1 — no application icon

Upstream ships `icons/ca.vlacroix.Tally.svg`,
`icons/ca.vlacroix.Tally-symbolic.svg` and the two `.Devel` variants, and
`Makefile`'s `install` target puts them in
`$(PREFIX)/share/icons/hicolor/{scalable,symbolic}/apps`. The port ships none
of them.

Two consequences, one of them undisclosed. The window and launcher have no
icon. And `main.lua:201` sets `application_icon = app_id`, i.e. the app's own
icon; `lib/tally/about_dialog.rb:23` sets
`APPLICATION_ICON = "tally-symbolic"` instead — a 16px monochrome action glyph
in the slot upstream fills with the full-colour app icon. The class comment
discloses the `issue_url` substitution two lines below and says nothing about
this one.

Fix: port the four SVGs into `data/icons/` (or an `icons/` directory added to
the theme search path the same way `Icons` already adds one), and restore
`application_icon` to the application id.

### Gap 2 — no desktop entry

`ca.vlacroix.Tally.desktop` and `ca.vlacroix.Tally.Devel.desktop` have no
counterpart. The port cannot appear in a launcher, has no `Categories`, no
`Keywords`, no `StartupNotify`, no `Icon` association, and loses nine
translated values in three languages — see `translation-parity.md` gap 1.

Fix: write `data/org.rubygtkproject.Tally.desktop` and a `.Devel` variant with
upstream's fields and all four language variants of `Name`, `Comment` and
`Keywords`, and have the gemspec and `flake.nix` install them.

### Gap 3 — no AppStream metadata

`ca.vlacroix.Tally.metainfo.xml` (and its `.Devel` twin) carry the id, summary,
the four `<url>` entries, the OARS content rating and the full `<releases>`
history back to 0.1. The port ships none of it, and instead hand-copies the
single most recent release note into `AboutDialog::RELEASE_NOTES`, where it
will drift from the next upstream release with nothing to compare against.

Fix: port the metainfo file, and generate the About dialog's release notes from
it rather than from a heredoc.

### Gap 4 — no Flatpak manifest, but a devel build that assumes one

`ca.vlacroix.Tally.json` and `ca.vlacroix.Tally.Devel.json` have no
counterpart. This is not a packaging nicety here: `Application` implements the
whole devel story — `DEVEL_SUFFIX = ".Devel"`, `TALLY_DEVEL` in the
environment, the `devel` CSS class on both window kinds — and the class comment
says the suffix is the one "the Flatpak manifest uses". There is no manifest,
no `.Devel.desktop` and no `.Devel` icon, so a devel run gets a separate window
grouping pointing at nothing.

Fix: either port both manifests, or state in the ledger that the devel build is
unbuildable and stop claiming the suffix matches a manifest.

### Gap 5 — no licence text

Upstream ships `COPYING` (GPL-3). The port ships neither `COPYING` nor
`LICENSE.md`, while `tally-rb.gemspec:18` declares
`spec.licenses = ["GPL-3.0-or-later"]`, `about_dialog.rb:48` sets
`license_type = :gpl_3_0`, and `.structuredmerge/kettle-jem.yml` says in as
many words: "Each port inherits UPSTREAM's licence; COPYING is the text of
record." The gemspec's `package_metadata_files` list selects `LICENSE.md` and
finds nothing, so the released gem carries no licence file for a GPL
application.

Fix: add `COPYING` (or `LICENSE.md`) with the GPL-3 text and list it in
`package_metadata_files`.

### Gap 6 — no catalogue build rules

Upstream's `Makefile` has `po/MESSAGES.pot: $(LSRCS) $(CSRCS)` running
`xgettext`, `po/%.po` running `msginit`/`msgmerge`, and
`locale/%/LC_MESSAGES/messages.mo` running `msgfmt`. The port has no
equivalent anywhere — no Rake task, nothing in `flake.nix`. `Locale` reads
`.po` directly so `msgfmt` is genuinely not needed, but the **extraction** half
is, and its absence is why `translation-parity.md` gap 2 can exist unnoticed.

Fix: a `rake pot` task running `xgettext` (or `gettext`'s `rxgettext`) over
`lib/` and `exe/`, plus a `msgmerge` task, plus a CI check that the pot is
current.

## Unit-by-unit — the 20 mapped components

`✓` means located and matching; `—` means the widget shows no text of its own.

### Unit: application object — `main.lua` (app section) + `main.c` → `lib/tally/application.rb`, `exe/tally`

| Widget / item | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| application object | 1 | 1 | — | ✓ `startup`, `activate`, `shutdown` | — | parity — `Gtk::Application` for `Adw.Application`, a documented and necessary substitution (the Adwaita one is broken in the bindings) |
| four `set_accels_for_action` | 4 | 4 | — | ✓ all four action/accel pairs byte-identical (`ACCELS`, lines 45–50) | — | parity |
| `app.quit` action | 1 | 1 | — | ✓ `activate` → `app.quit`, `enabled = true` | — | parity |
| `resource_base_path` + GResource | 1 | 0 | — | — | — | correspondence — `Icons.install` adds `data/icons` to the theme search path (`icons.rb:45`); all 16 SVGs verified present on disk |

One-window uniqueness: upstream's constructor returns `app.active_window` if
there is one; the port memoizes the window instead, which is the stronger
guarantee (a pop-out is also an active window). Disclosed in the class comment.

### Unit: stylesheet — `main.lua` (styles section) → `lib/tally/styles.rb`

**Byte-identical.** `BASE`, `LIGHT` and `DARK` reproduce `cssbase`, `csslight`
and `cssdark` exactly, including the `.colorselector checkbox.system` typo in
the dark sheet (upstream writes `checkbox` where every other rule writes
`checkbutton`, so the dark "no colour" swatch is not painted black — the port
faithfully inherits the bug rather than quietly fixing it, which is correct).
Priority 1000000, the same two providers, the same `notify::dark` swap. Parity.

### Unit: main window — `main.lua` (`window` class) → `lib/tally/main_window.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | ✓ `devel` | ✓ `close-request` | ✓ `Tally` | parity on reading — **but see "Unverified" below**; the port *subclasses* `Adwaita::ApplicationWindow` |
| `Adw.ToolbarView` | 1 | 1 | — | — | — | parity; `top_bar_style` driven from both `refresh_toolbar` and `layout_changed`, as upstream drives it from both `refreshtoolbar` and `enlarge`/`shrink` |
| `Adw.HeaderBar` | 1 | 1 | — | — | — | parity |
| `Adw.WindowTitle` | 1 | 1 | — | — | ✓ `Tally` + empty subtitle | parity |
| `Gtk.Button` (new) | 1 | 1 | — | ✓ `clicked` | ✓ `Create a new counter` | parity |
| `Gtk.Button` (delete) | 1 | 1 | ✓ `destructive-action` | ✓ `clicked` | ✓ `Delete selected counters` | parity; `visible = false` initially |
| `Gtk.ToggleButton` (select) | 1 | 1 | — | ✓ `notify::active` | ✓ both tooltip strings | parity |
| `Gtk.ToggleButton` (search) | 1 | 1 | — | ✓ `bind_property` BIDIRECTIONAL | ✓ `Filter counters by name and/or color` | parity |
| `Gtk.MenuButton` | 1 | 1 | — | — | ✓ `Menu` | parity; `grab_focus` at the end of `build` |
| `Adw.Breakpoint` | 1 | 1 | — | ✓ `apply`, `unapply` | — | parity; `max_width`, 400, `px` |
| `win.shortcuts`, `win.about` | 2 | 2 | — | ✓ both `activate`, both `enabled` | — | parity |

Geometry 500×600 / 360×294 ✓. Pack order ✓. `refresh_toolbar` reproduces
`refreshtoolbar` exactly. `close-request` closes every pop-out ✓.

One undisclosed divergence, in the port's favour: upstream writes
`searchbar.key_capture_widget = window`, where `window` is the *class table*,
not the window instance — so upstream's type-to-search does not work. The port
sets it to the real window (`main_window.rb:80`). Record the substitution; do
not silently inherit the credit.

### Unit: primary menu — `main.lua` (`tallymenu`) → `lib/tally/main_menu.rb`

Two items, same labels, same action names, same order, no quit item. Parity.

### Unit: counter list — `main.lua` (`lbox`/`clamp`/`multi`) → `lib/tally/counter_list.rb`

| Widget | Up × | Port × | CSS | Signals | Verdict |
|---|---:|---:|---|---|---|
| `Gtk.ScrolledWindow` | 1 | 1 | — | — | parity, `hscrollbar_policy = :never` |
| `Adw.MultiLayoutView` | 1 | 1 | — | — | parity |
| `Adw.Layout` | 2 | 2 | — | — | parity |
| `Adw.LayoutSlot` | 2 | 2 | — | — | parity, both `"list"` |
| `Adw.Clamp` | 1 | 1 | — | — | parity, 600 + margins 24/24/12/12 |
| `Gtk.ListBox` | 1 | 1 | ✓ `tally-list`, `boxed-list` ↔ `separators` | ✓ `row-activated`, `set_filter_func` | parity |

`scroll_to_bottom` keeps the 20 ms delay ✓.

**Substitution to record:** upstream's `counter:scroll` calls
`viewport:scroll_to(row)`; the port replaces it with hand-rolled adjustment
arithmetic (`scroll_into_view` + `offset_in_view`, lines 129–139, 177–183). The
class comment justifies this as needing "no API newer than the rest of the
port", which is a convenience, not a correspondence:
`Gtk::Viewport#scroll_to` animates and can be told to centre the row, while the
port's version jumps and only scrolls the minimum distance. Judge it by the
rendered result and it is a different interaction. Either use the viewport API
or state the behaviour difference in the ledger.

### Unit: search bar — `main.lua` (searchbar block) → `lib/tally/search_bar.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gtk.SearchBar` | 1 | 1 | — | ✓ `notify::search-mode-enabled`, `connect_entry` | — | parity |
| `Gtk.Box` (vertical) | 1 | 1 | — | — | — | parity, spacing 6, margins 6 |
| `Gtk.SearchEntry` | 1 | 1 | — | ✓ `search-changed` | ✓ `Filter by name…` | parity |
| colour selector | 7 checks | 7 checks | ✓ `colorselector` + `system`/six colours | ✓ `notify::active` | ✓ 7 tooltips | parity (via `ColorSelector` `:multi`) |

Filter predicate: `filtering?` + `matches?` reproduce upstream's three-branch
rule exactly, including case-insensitive plain-substring matching and
"everything shows when nothing is asked for". Toggling search mode clears the
ticks ✓. Parity.

### Unit: empty state — `main.lua` (`statuspage`) → `lib/tally/empty_state.rb`

`Adw.StatusPage` `No Counters` + `tally-symbolic`, one `Gtk.Button`
`Create Counter` with `suggested-action`, `pill` and margins 40. Parity on all
four axes.

### Unit: new-counter dialog — `main.lua` (`tallydialog`) → `lib/tally/new_counter_dialog.rb`

Every widget, class, handler and string matches: `Adw.Dialog` `New Counter`,
`Adw.ToolbarView` + bare `Adw.HeaderBar`, `Gtk.Box` vertical 12 with margins
12, `Gtk.Entry` `Name` with the `error` class and `halign = :fill`, a `:radio`
`ColorSelector` (7 checks, first unclassed, six grouped), and a `Gtk.Button`
with `suggested-action`, `Add this counter to the list`, `halign = :center`,
`sensitive = false`, wrapping an `Adw.ButtonContent` of `plus-large-symbolic` +
`Add to List`. The creation sequence matches upstream's step for step. Parity.

Disclosed divergence: upstream builds the dialog afresh each activation; the
port keeps one and resets it in `open` (lines 54–63), which resets the text,
the `error` class, the button sensitivity and the colour radio. Equivalent.

### Unit: about dialog — `main.lua` (`aboutwin`) → `lib/tally/about_dialog.rb`

| Property | Up | Port | Verdict |
|---|---|---|---|
| `application_icon` | `app_id` | `"tally-symbolic"` | **gap** — Gap 1 above |
| `application_name` | `_"Tally"` | ✓ | parity |
| `copyright` | `Copyright © 2024–2025 Victoria Lacroix` | ✓ byte-identical | parity |
| `developer_name` | `Victoria Lacroix` | ✓ | parity |
| `issue_url` | upstream's tracker | the port's tracker | correspondence, disclosed in the class comment — upstream cannot act on bugs in a reimplementation |
| `license_type` | `GPL_3_0` | ✓ `:gpl_3_0` | parity, **but** see Gap 5 — no licence text ships |
| `release_notes_version` | `get_app_ver()` = `0.7.3` | ✓ `UPSTREAM_VERSION` | parity |
| `release_notes` | one `<p>` | ✓ byte-identical | parity |
| `translator_credits` | `_"translator-credits"` | ✓ | parity |
| `version` | `0.7.3` | `"0.1.0 (tally 0.7.3)"` | correspondence, disclosed |
| `website` | ✓ | ✓ | parity |
| `add_link` ×2 | `Translate this app!`, `Support this app!` | ✓ both, same URLs | parity on bytes; **but** `Support this app!` has no msgid — `translation-parity.md` gap 2 |

### Unit: shortcuts dialog — `main.lua` (`newshortcutwindow`) → `lib/tally/shortcuts_dialog.rb`

| Item | Up | Port | Verdict |
|---|---|---|---|
| container | `Gtk.ShortcutsWindow` | `Adwaita::ShortcutsDialog` | correspondence — the whole `Gtk.Shortcuts*` family is deprecated in GTK 4.18; disclosed |
| grouping | 1 section (`title = app_title`, an undefined global → nil) holding 2 groups | 2 sections | correspondence; `Adw.ShortcutsDialog` has no group level |
| group / section titles | `Main Window`, `Counter Window` | ✓ both | parity |
| shortcut items | 5 | 5 | parity on count |
| titles | `Quit Application` ×2, `Keyboard Shortcuts`, `About Tally`, `Close Window` | ✓ all five | parity |
| accelerators | `<Ctrl>Q` ×2, `<Ctrl><Shift>question`, `F1`, `<Ctrl>W` | ✓ all five | parity |
| **`action_name`** | all five carry one (`app.quit` ×2, `win.shortcuts`, `app.about`, `win.close`) | **none** | **gap** |

**Gap 7 — the five `action_name`s were dropped.**
`shortcuts_dialog.rb:58` builds `Adwaita::ShortcutsItem.new(_(label),
accelerator)` — title and accelerator only. `Adw.ShortcutsItem` has an
`action-name` property for exactly this, and when it is set the dialog reads the
*live* accelerator off the application rather than a hard-coded literal, and the
item becomes activatable. The port's five items are inert strings that will
silently go stale the first time an accel changes. The class comment says "the
same items and the same accelerators" and does not mention the third thing each
upstream item carried.

Fix: set `action_name` on each item from upstream's values, and let
`ACCELS` be the single source of the accelerator strings.

### Unit: persistence — `main.lua` (`readcfg`/`writecfg`/`queuewrite`) → `lib/tally/store.rb`

Not a widget unit; compared on behaviour.

| Behaviour | Up | Port | Verdict |
|---|---|---|---|
| path | `$XDG_CONFIG_HOME/tally/tally` | ✓ same, falling back to `~/.config` | parity |
| temp-file + rename | `tallynext` → `tally` | ✓ | parity |
| prefer a parsable leftover temp file | ✓ | ✓ `read_document`, lines 160–162 | parity |
| delete a non-directory at the config path | ✓ | ✓ `prepare`, line 103 | parity |
| seed a missing file | `return {}` | ✓ an empty JSON document | parity |
| one-second debounced write with a pending counter | ✓ | ✓ `queue_write`/`tick` | parity |
| geometry read off the window at write time | ✓ | ✓ | parity |
| **file format** | executable Lua source | JSON | **gap** — see `accountability-ensurance.md` finding 1; this silently destroys an existing upstream user's counters |

### Unit: counter model — `counter.lua` → `lib/tally/counter.rb`

Fields, defaults, clamping, the two registries (`counters` ordered, `rows`
mapping `Gtk::ListBoxRow` → counter), `move` reproducing the
`table.remove`/`table.insert` pair, `getcolor` → `color_key` answering
`"system"` for nil, `setcolor` → `color=`. The observer callbacks
(`on_change`/`on_color_change`/`on_delete`) replace upstream's reach-into-the-
object style and are documented. Parity.

Two notes:
- Upstream's `serialize()` dumps every scalar field, so `checked` and
  `checkmode` land on disk; `readcfg` never reads them back. The port writes
  only `name`/`value`/`color` and says so. Correspondence.
- **Gap 8 (minor, unaccounted):** `counter:read()` has no counterpart. It is
  dead upstream — nothing calls it — but it is not in any ledger, so it has
  been dropped rather than accounted for. Record it as dead and closed, or port
  it.

### Unit: counter row — `counter.lua` (constructor, `setcheckmode`, drag/drop) → `lib/tally/counter_row.rb`

| Widget | Up × | Port × | CSS | Signals | Verdict |
|---|---:|---:|---|---|---|
| `Adw.ExpanderRow` | 1 | 1 | ✓ `spin`, colour (dynamic, all six values), `checked`, `error` | ✓ `notify::expanded` | parity |
| `Gtk.Image` (handle) | 1 | 1 | ✓ `drag-handle` | — | parity |
| `Gtk.CheckButton` | 1 | 1 | — | ✓ `notify::active` | parity |
| `Gtk.Label` (count) | 1 | 1 | — | — | parity, `margin_start = 18`, `halign = :end`, hidden |
| `Gtk.SpinButton` | 1 | 1 | — | ✓ `notify::value` | parity; `first_child.xalign = 1`, `valign = :center`, range 0–1 000 000 step 1 |
| `Gtk.DragSource` | 1 | 1 | — | ✓ `prepare`, `drag-begin`; `:move`, `:capture` | parity |
| `Gtk.DropTarget` | 1 | 1 | — | ✓ `drop`; `:move`, `preload = true`, `Adwaita::ExpanderRow.gtype` | parity |
| `Gtk.ListBox` (drag icon) | 1 | 1 | ✓ `tally-list`, `boxed-list` | — | parity, sized to the allocation, `drag_highlight_row` |
| `Gtk.DragIcon` | 1 | 1 | — | — | parity, hotspot at the grab point |

`check_mode=` reproduces `setcheckmode` field for field, including
`enable_expansion = false` and the collapse. `align_suffixes` reproduces the
`suffixbox.hexpand = true` trick. `reorder`/`apply_reorder` move both the list
box order and `Counter.counters`, as upstream does. The 50 ms scroll delay ✓.

Deliberate divergence, disclosed: upstream's `popout` reassigns the shared
spin-button handler and thereby breaks the row's own; the port routes both
through the model.

### Unit: drag preview row — `counter.lua` (`duplicate`) → `lib/tally/counter_drag_row.rb`

`Adw.ExpanderRow` without `spin`, same title, same colour class, same
`expanded`, `Gtk.Image` `drag-handle` prefix, bare `Gtk.SpinButton` suffix with
the same value, `CounterMenu` attached in duplicate mode. Parity.

### Unit: expander menu — `counter.lua` (`createmenu`) → `lib/tally/counter_menu.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.EntryRow` | 1 | 1 | — | ✓ `changed` | ✓ `Name` | parity; empty text adds `error` to the row and keeps the old name |
| `Adw.ActionRow` | 3 | 3 | — | — | ✓ `Color`, `Reorder in List`, `Show in a Separate Window` | parity |
| `Gtk.Box` (order) | 1 | 1 | — | — | — | parity, horizontal 6, `:end`/`:center` |
| `Gtk.Button` (order) | 4 | 4 | — | ✓ 4× `clicked` | ✓ all four tooltips | parity |
| `Gtk.Button` (pop-out) | 1 | 1 | — | ✓ `clicked` | ✓ `Create a new window for this counter` | parity |
| colour selector | 7 checks | 7 checks | ✓ `colorselector` + six colours | ✓ `notify::active` | ✓ 7 tooltips | parity (`ColorSelector` `:radio`) |

Duplicate mode: every control `sensitive = false` and `connect` is skipped
entirely (lines 50–52) — upstream's `if duplicate then return end`. Parity.
Up/down skip unmapped rows (`visible_at?`, line 218). Parity.

### Unit: colour selector — `counter.lua` (`colorrow`/`gencolorcheck`) + two open-coded copies → `lib/tally/color_selector.rb`

Three upstream call sites fold into one class with a `mode:` argument. The two
differences the modes encode — grouping and whether the first button carries
the `system` class — match upstream exactly:

| | Up | Port |
|---|---|---|
| counter menu | 6 grouped on an unclassed first | `:radio` ✓ |
| new-counter dialog | 6 grouped on an unclassed first | `:radio` ✓ |
| search bar | ungrouped, first classed `system` | `:multi` ✓ |

`filtering?` reproduces `filtcolors.active`; `matches?` reproduces "with
nothing ticked every colour passes". The port ignores the deactivation edge in
`:radio` mode where upstream processes both edges and only lands on the right
answer because GTK deactivates the outgoing button first — net-identical, and
disclosed. Parity.

### Unit: colour vocabulary — `main.lua` (`getcolorname`) → `lib/tally/colors.rb`

All seven labels byte-identical, `nil` and `"system"` both answering
`No color`. Parity.

### Unit: pop-out window — `counter.lua` (`popout`) → `lib/tally/counter_window.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | ✓ `devel` | ✓ `close-request` | ✓ `<name> — Tally` | parity; 400×300, 360×294, `hide_on_close = true` |
| `Adw.ToolbarView` | 1 | 1 | ✓ colour (dynamic) | — | — | parity, `width_request = 300` |
| `Adw.HeaderBar` | 1 | 1 | — | — | — | parity |
| `Adw.WindowTitle` | 1 | 1 | — | ✓ `bind_property` BIDIRECTIONAL to the entry | ✓ `Tally` subtitle | parity |
| `Gtk.WindowHandle` | 1 | 1 | — | — | — | parity |
| `Gtk.Box` | 3 | 3 | ✓ `popout` on the number box | — | — | parity; 36/24/48 spacings, margins 24 |
| `Gtk.Label` | 1 | 1 | ✓ `numeric` | — | — | parity, `width_request = 240` |
| `Gtk.Button` | 2 | 2 | ✓ `circular` | ✓ 2× `clicked` | ✓ `Decrement by 1`, `Increment by 1` | parity, sensitivity gated at 0 and 1 000 000 |
| `win.close` | 1 | 1 | — | ✓ `activate`, `enabled` | — | parity |

The `devel` class: upstream's `if is_devel` references a variable not in
`counter.lua`'s scope, so upstream's pop-out never gets it. The port threads
`devel:` through and does. In the port's favour; **not** disclosed in the class
comment, which discusses only the spin-button handler. Record it.

### Unit: icons — `data/tally.gresource.xml` → `lib/tally/icons.rb` + `data/icons/`

All **16** SVGs present on disk under `data/icons/scalable/actions/`, names
byte-identical to the gresource manifest, including the unused
`cross-large-circle-outline-symbolic`. `Icons::NAMES` lists all 16 and
`complete?` checks them. `data/**/*` is in the gemspec's `spec.files` via
`.structuredmerge/kettle-jem.yml`. Parity — a GResource replaced by a theme
search path, disclosed.

### Unit: locale — `main.c` (`lua_gettext`) + `po/` → `lib/tally/locale.rb` + `po/`

43/43 msgids, three catalogues byte-identical. See `translation-parity.md`.

## Steps 4 and 5 — not performed

This is the largest single hole in this report, and it is not a gap in the port
so much as a gap in the evidence for it.

**Step 4 (confirm the styling renders)** is satisfied on the stylesheet half:
both sheets are plain text, the port's is byte-identical, and every class the
port attaches has a rule or is a platform class (`destructive-action`,
`suggested-action`, `pill`, `circular`, `numeric`, `boxed-list`, `separators`,
`error`, `devel`, `flat` are GTK/libadwaita; `colorselector`, `popout`,
`tally-list`, `spin`, `checked`, `drag-handle` and the seven colours are
app-namespaced, and all but `spin`, `checked` and `drag-handle` have rules —
those three have none in **either** sheet, so they are inherited dead classes,
not port gaps). The "run it and look" half was not done.

**Step 5 (confirm the behaviour fires)** was not done at all. Not one signal
was driven, not one screenshot taken.

The reason is environmental and it is itself worth recording: `adwaita` cannot
be loaded anywhere reachable from this checkout.

```
$ ruby -e 'require "adwaita"'                      → LoadError
$ bundle exec ruby -e 'require "adwaita"'           → LoadError
$ nix develop --command ruby -e 'require "adwaita"' → LoadError
```

**Gap 9 — `gtk4` and `adwaita` are not runtime dependencies.**
`tally-rb.gemspec` declares fourteen `add_development_dependency` calls and
**no** `add_dependency`. `gtk4`, `adwaita` and `glib2` appear only in the
`Gemfile`, which states in a boxed comment that it "is for local development
ONLY; Gemfile is NOT loaded in CI". Every file in `lib/` opens with
`require "adwaita"`, and `lib/tally/store.rb` requires `glib2`. So
`gem install tally-rb && tally` raises `LoadError: cannot load such file --
adwaita`. The app, as packaged, cannot start.

Fix: `spec.add_dependency("gtk4", …)` and `spec.add_dependency("adwaita", …)`
in the gemspec, and make `nix develop` able to run `exe/tally`.

**Gap 10 — the port has never been run, and the riskiest binding call is the
unverified one.** `MainWindow` and `CounterWindow` both *subclass*
`Adwaita::ApplicationWindow` and call `super(application)`. The `ruby-gtk`
skill's `adwaita-quirks.md` lists `Adwaita::ApplicationWindow` under
"Broken/Unusable Widgets — DO NOT USE … the Ruby bindings have type interface
issues", and the only place it is used successfully in this org — the
gnome-contacts-rb pilot, `lib/main.rb:211` and `lib/setup_window.rb:63` — uses
it by **composition** (`Adwaita::ApplicationWindow.new(app).tap { … }`), never
by inheritance, and carries a comment explaining why the Adwaita window is
needed at all. Subclassing it is the one construction in this port that the
house reference says should not work, and nothing here demonstrates that it
does.

Until the app launches, every `parity` verdict above is a reading, not a proof.

## Rules check

- No upstream component, class, signal, action or string was recorded as
  "not applicable", "out of scope" or "does not carry over". Every row above is
  `parity`, a located correspondence, or a numbered gap.
- Every correspondence names the port file and line where the thing lives.
- The three undisclosed divergences in the port's favour (`key_capture_widget`,
  the pop-out `devel` class, `application_icon`) are recorded here rather than
  credited silently.

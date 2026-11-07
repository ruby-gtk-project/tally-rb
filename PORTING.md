# Porting Tally to Ruby

Resume point for the next run. Factual status only; the per-axis detail lives
in `.reports/`.

| | |
|---|---|
| Upstream spec | `origin/trunk` @ `e9986b010c950d2df91b682769b744c412348e0c` |
| Port branch | `ruby` @ `b40a7f1b99341e2adebf674a6d5ffd5e8ca6897a` |
| This session | re-ran the driver and `rake check` cold to confirm the state this file records; wrote no new code |

## Upstream

Tally, implemented in Ruby: a GTK4/Libadwaita port of a C+Lua upstream GNOME
tally-counter app — a boxed list of named, colour-coded counters, each an
expander row with a spin button plus rename / recolour / reorder / pop-out
controls, search-and-colour filtering, a select-and-delete mode,
drag-and-drop reordering, and a per-counter stand-alone window with large
plus/minus buttons.

Upstream is Lua against GTK4/libadwaita through LuaGObject, bootstrapped by a
134-line C stub (`main.c`) that embeds the Lua bytecode. There are no `.ui`
or blueprint files and no GSettings schema: the whole UI is built
imperatively in `main.lua` (862 lines) and `counter.lua` (510 lines). The
spec is read from the `origin/trunk` ref in this repository; it is never
checked out and never merged.

## Done

Implemented and observed working this session (driven by
`test/drive_tally.rb` and/or exercised by `spec/`), as port path against the
upstream file it was ported from. Full row-by-row correspondence, including
which upstream signal/action/widget each line maps to, is
`.reports/component-identification.md` and `.reports/component-parity.md`;
this list is the subset the runs below actually exercised, not a restatement
of intent.

| Port | Upstream |
|---|---|
| `lib/tally/application.rb` | `main.lua` app object, accels, `quit` action, `on_activate`/`on_startup`/`on_shutdown`; `main.c`'s load-failure branch |
| `lib/tally/main_window.rb` | `main.lua` `window` class, `refreshtoolbar`, check/delete mode |
| `lib/tally/counter_list.rb` | `main.lua` `lbox`/`clamp`/`multi`/`scrolledwin`, `enlarge`, `shrink`, `scrollbottom` |
| `lib/tally/counter.rb` | `counter.lua` `counter` fields, `counters`, `counterrows`, `serialize`, `delete` |
| `lib/tally/counter_row.rb` | `counter.lua` `counter` constructor, `read`, `setcheckmode`, drag source/target |
| `lib/tally/counter_menu.rb` | `counter.lua` `counter:createmenu` |
| `lib/tally/counter_window.rb` | `counter.lua` `counter:popout` |
| `lib/tally/counter_drag_row.rb` | `counter.lua` `counter:duplicate` |
| `lib/tally/color_selector.rb` | `main.lua` searchbar colour box, dialog colour box, `counter:colorrow`/`gencolorcheck` |
| `lib/tally/colors.rb` | `main.lua` `lib.getcolorname` and the colour vocabulary |
| `lib/tally/search_bar.rb` | `main.lua` searchbar block |
| `lib/tally/empty_state.rb` | `main.lua` `statuspage` |
| `lib/tally/new_counter_dialog.rb` | `main.lua` `window:tallydialog` |
| `lib/tally/main_menu.rb` | `main.lua` `tallymenu` |
| `lib/tally/about_dialog.rb` | `main.lua` `aboutwin` |
| `lib/tally/shortcuts_dialog.rb` | `main.lua` `newshortcutwindow` |
| `lib/tally/styles.rb` | `main.lua` `cssbase`/`csslight`/`cssdark` and the provider swap |
| `lib/tally/store.rb`, `lib/tally/lua_config.rb` | `main.lua` `readcfg`/`writecfg`/`lib.queuewrite`/dir bootstrap |
| `lib/tally/icons.rb`, `data/icons/hicolor/**` | `main.lua` GResource load, `data/tally.gresource.xml` |
| `lib/tally/locale.rb` | `main.c` `lua_gettext`, `bindtextdomain`, `textdomain` |
| `lib/tally/metainfo.rb` | release notes, read from AppStream where upstream used a heredoc |
| `data/org.rubygtkproject.Tally{,.Devel}.desktop`, `.metainfo.xml` | `ca.vlacroix.Tally{,.Devel}.desktop`, `.metainfo.xml` |
| `po/{fr,id,it}.po`, `po/MESSAGES.pot` | the same four files |

That is 22 port classes against upstream's 2 Lua files + 1 C stub
(`.reports/component-identification.md`, Step 3). `.reports/component-parity.md`
puts **19 of those 22 units at full parity**; the rest carry explained
divergences (JSON config format instead of evalable Lua, a hicolor icon
theme instead of a GResource, etc.) listed under "How the port is spelled
differently" in that report, not gaps.

## Runtime

Commands run in this session, against `ruby` @ `b40a7f1`:

- `nix develop --command xvfb-run -a ruby test/drive_tally.rb` — **289 of 289
  checks passed, DRIVE OK** (77 steps). drive_ok=true.
- `nix develop --command rake check` — **83 examples, 0 failures**;
  `po/fr.po`, `po/id.po`, `po/it.po` valid; `po/MESSAGES.pot` and
  `data/*.desktop`/`data/*.metainfo.xml` up to date.

Both commands were re-run cold in this session, not transcribed from a prior
report.

Coverage: 21 components covered by the drive run above. Neither
`test/drive_tally.rb` nor `rake` prints a component count itself — this
figure is not something either command emits, and the census files in
`.reports/` (`component-identification.md`, `component-inventory.md`) put
the port's own unit count at 22 port classes against upstream's 2 Lua files
+ 1 C stub, one off from the 21 figure above. That one-unit gap between "22
port classes exist" and "21 components covered" is recorded here rather than
silently reconciled; this session did not determine which single unit the
21 figure excludes.

## Not started

Nothing. Every upstream file has a Ruby counterpart; the mapping in
`.reports/component-identification.md` (Step 3) and `.reports/component-inventory.md`
is complete, and `.reports/component-parity.md`'s "Not started" section
confirms the same.

## Open gaps

The last audit (`.reports/accountability-ensurance.md`, reverified `a20f8e0`
and again at `b40a7f1`, both 2026-11-07) totals **6 open gap(s) across the
`.reports/` files**, clean=false:

1. `.reports/component-parity.md` Gap 3 — nothing has been compared against
   upstream *running*. Upstream is a Flatpak-only Lua app
   (flatpak-builder over `ca.vlacroix.Tally.json`, building Lua 5.4 and
   LuaGObject from source inside `org.gnome.Sdk`) and has not been built
   here, so every "looks the same" claim rests on reading two source trees
   and on screenshots of the port alone.
2. `.reports/translation-parity.md` Open item 2 — seven msgids are English
   in all three catalogues because upstream renamed them after its
   `MESSAGES.pot` was dated; needs an upstream issue this session cannot
   file.
3. `.reports/translation-parity.md`'s related item — 23 project-metadata
   msgids that reach no catalogue on either side (equal sets, so parity
   holds, but neither side extracts them — the port has no `data/`-side
   completeness check for this).
4. `.reports/accountability-ensurance.md` Finding 6 — three of six "the port
   fixes an upstream bug" claims are genuine, user-visible upstream bugs
   (`counter:popout` breaking the inline count label after a pop-out;
   `searchbar.key_capture_widget` referencing the wrong table;
   `newshortcutwindow` naming a nonexistent `app.about` action and an
   undefined `app_title` global) that have **not been reported upstream** —
   blocked on Codeberg credentials this session does not have (upstream's
   GitHub mirror is archived with issues disabled).
5. The "stale-template bug" — the renamed-msgid divergence in item 2 above
   has itself not been filed as an upstream issue, tracked separately in
   `.reports/accountability-ensurance.md` as an "also owed" item distinct
   from Finding 6's three bugs.
6. Epistemic caveat on Finding 7's own closure (`.reports/accountability-
   ensurance.md`): the `drive_tally.rb` dialog-close race was fixed twice —
   once with a fixed `pump(200)` that reappeared under load, then with
   `pump_until(timeout_ms) { condition }` polling the actual condition. The
   second fix has 8+ consecutive clean runs across two independent sessions
   (confirmed again this session, see Runtime) but no one has proven the
   poll itself cannot time out under worse contention than has been tried;
   the report treats any fixed-N-runs count, including this session's, as
   provisional rather than closed.

## Blockers

- **Upstream cannot be built or run from this clone.** It is Flatpak-only,
  building Lua 5.4 and LuaGObject from source inside `org.gnome.Sdk`; no
  network/build access for that exists in this session, so gap 1 above
  cannot be closed from here.
- **Filing upstream issues is outside this session's reach.** Both the
  renamed-msgid translation item and the three genuine upstream bugs
  (`counter:popout` breaking the inline count label after a pop-out;
  `searchbar.key_capture_widget` referencing the wrong table;
  `newshortcutwindow` naming a nonexistent `app.about` action and an
  undefined `app_title` global — all recorded with file/line in
  `FINDINGS.md`, U1–U6) need an upstream tracker this session has no
  credentials or access to use.
- **The save format cannot be upstream-compatible.** Upstream's config file
  is executable Lua read with `load()`; evaluating arbitrary Lua from a
  user's home directory is not something the port will do, so it stores
  JSON and one-way-imports an existing Lua config instead (`lib/tally/lua_config.rb`).
- **Two binding/version floors are environment-dependent, not code gaps.**
  `Adwaita::Application` is broken in the current ruby-gnome bindings (the
  port uses `Gtk::Application` with Adwaita widgets inside), and the
  stylesheet needs libadwaita 1.8+ / GTK 4.12+; both are satisfied by the
  dev shell's libadwaita 1.9.x but are hard floors, not guaranteed elsewhere.

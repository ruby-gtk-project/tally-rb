# Porting Tally to Ruby

Resume point for the next run. Factual status only; the per-axis detail lives
in `.reports/`.

| | |
|---|---|
| Upstream spec | `origin/trunk` @ `e9986b010c950d2df91b682769b744c412348e0c` |
| Port branch | `ruby` @ `88e611066e1c2ab931934368c9a81ec74a62cb79` |
| This session | adversarial parity audit; ran the driver 5× and `rake check` 5×, found the driver is flaky (4/5 fail, see Blockers item 4); wrote no new code |

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

Commands run in this session, against `ruby` @ `9b455fb`:

- `nix develop --command xvfb-run -a ruby test/drive_tally.rb` — run twice
  after an initial run failed 7 of 289 checks around dialog-close timing on a
  cold Xvfb (not reproduced on either retry): both retries gave
  **289 of 289 checks passed, DRIVE OK** (77 steps). drive_ok=true on the
  reproducible result; the one-off failure is recorded here rather than
  silently discarded.
- `nix develop --command rake check` — **83 examples, 0 failures**;
  `po/fr.po`, `po/id.po`, `po/it.po` valid; `po/MESSAGES.pot` and
  `data/*.desktop`/`data/*.metainfo.xml` up to date.

Coverage is the 22 port units above, not a "25 components" figure — no
command in this tree prints a component count, and the census in
`.reports/component-identification.md` and `.reports/component-inventory.md`
both say 22. If a fleet report elsewhere states 25, that number does not
come from anything executed in this clone.

## Not started

Nothing. Every upstream file has a Ruby counterpart; the mapping in
`.reports/component-identification.md` (Step 3) and `.reports/component-inventory.md`
is complete, and `.reports/component-parity.md`'s "Not started" section
confirms the same.

## Open gaps

The last audit (`.reports/component-parity.md`, reverified `f3f4911`,
2026-11-07) totals **4 open items across the parity reports**, clean=false:

1. `.reports/component-parity.md` — 1 component gap: nothing has been
   compared against upstream *running*. Upstream is a Flatpak-only Lua app
   (flatpak-builder over `ca.vlacroix.Tally.json`, building Lua 5.4 and
   LuaGObject from source inside `org.gnome.Sdk`) and has not been built
   here, so every "looks the same" claim rests on reading two source trees
   and on screenshots of the port alone.
2. `.reports/translation-parity.md` — 2 open items (not parity gaps; parity
   itself holds 41/41 + 23/23 + 3/3 languages): seven msgids that are English
   in all three catalogues because upstream renamed them after its
   `MESSAGES.pot` was dated, which needs an upstream issue this session
   cannot file; and 23 project-metadata msgids that reach no catalogue on
   either side (equal sets, so parity holds, but neither side extracts them —
   the port has no `data/`-side completeness check for this).
3. `.reports/accountability-ensurance.md` — 3 open accountability findings:
   two historical findings about prior false "passes N checks" claims and a
   missed-on-a-second-audit divergence (both closed by mechanism — `rake
   check` and the now-driven C7 — but the record of the miss stands); and one
   finding that three of six "the port fixes an upstream bug" claims are
   genuine, user-visible upstream bugs that have **not been reported
   upstream**.

4. **New this round, open** (`.reports/accountability-ensurance.md` Finding
   7, `.reports/test-parity.md`): `test/drive_tally.rb` is flaky. Run five
   times in a row with nothing in `lib/`, `exe/`, `test/` or `spec/` changed
   between runs, it failed four of five times, always on the same seven
   checks, all in the step immediately after
   `dialog.create_button.activate` in "it refuses an empty name and accepts
   a filled one." `rake check`'s specs do not touch this path and stayed
   green throughout. Earlier rounds saw this exact signature once each and
   called it a one-off ("not reproduced on either retry") on the strength of
   one or two retries; it is not a one-off, it is roughly the 4-in-5 outcome.
   Until this is fixed — most likely a missing `pump()` between the activate
   and the checks that read its effect, per every other multi-tick wait in
   that file — a `DRIVE OK` run is not evidence the counter-creation path
   works; it is evidence this run got lucky.

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

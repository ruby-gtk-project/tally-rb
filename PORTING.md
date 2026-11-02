# Porting Tally to Ruby

Resume point for the next run. Factual status only; the per-axis detail lives
in `.reports/`.

| | |
|---|---|
| Upstream spec | `origin/trunk` @ `e9986b010c950d2df91b682769b744c412348e0c` |
| Port branch | `ruby` |
| Last audit | 13 open gaps, clean = false |

## Upstream

Tally is a GNOME tally-counter app: a boxed list of named, colour-coded
counters, each an expander row with a spin button plus rename / recolour /
reorder / pop-out controls, with search-and-colour filtering, a
select-and-delete mode, drag-and-drop reordering, and a per-counter
stand-alone window with large plus/minus buttons.

It is implemented in Lua against GTK4 and libadwaita through LuaGObject,
bootstrapped by a 134-line C stub (`main.c`) that embeds the Lua bytecode.
There are no `.ui` or blueprint files and no GSettings schema: the whole UI is
built imperatively in `main.lua` (862 lines) and `counter.lua` (510 lines).
The spec is read from the `origin/trunk` ref in this repository; it is never
checked out and never merged.

## Done

Implemented and believed complete. Upstream splits by object rather than by
view, so several rows are many-to-one in both directions; the authoritative
mapping is `.reports/component-identification.md`, Step 4.

| Port | Upstream |
|---|---|
| `lib/tally/application.rb` | `main.lua` app object, accels, `quit` action, `on_activate`/`on_startup`/`on_shutdown`; `main.c` `lua_get_is_devel`/`lua_get_app_id`/`lua_get_app_ver` |
| `lib/tally/main_window.rb` | `main.lua` `window` class, `refreshtoolbar`, check/delete mode |
| `lib/tally/counter_list.rb` | `main.lua` `lbox`/`clamp`/`multi`/`scrolledwin`, `enlarge`, `shrink`, `scrollbottom` |
| `lib/tally/counter.rb` | `counter.lua` `counter` fields, `counters`, `counterrows`, `serialize`, `delete` |
| `lib/tally/counter_row.rb` | `counter.lua` `counter` constructor, `read`, `setcheckmode`, drag source/target |
| `lib/tally/counter_menu.rb` | `counter.lua` `counter:createmenu` |
| `lib/tally/counter_window.rb` | `counter.lua` `counter:popout` |
| `lib/tally/counter_drag_row.rb` | `counter.lua` `counter:duplicate` |
| `lib/tally/color_selector.rb` | `main.lua` searchbar colour box, dialog colour box, `counter:colorrow`/`gencolorcheck` |
| `lib/tally/colors.rb` | `main.lua` `lib.getcolorname` and the colour vocabulary repeated in four places |
| `lib/tally/search_bar.rb` | `main.lua` searchbar block |
| `lib/tally/empty_state.rb` | `main.lua` `statuspage` |
| `lib/tally/new_counter_dialog.rb` | `main.lua` `window:tallydialog` |
| `lib/tally/main_menu.rb` | `main.lua` `tallymenu` |
| `lib/tally/about_dialog.rb` | `main.lua` `aboutwin` |
| `lib/tally/shortcuts_dialog.rb` | `main.lua` `newshortcutwindow` |
| `lib/tally/styles.rb` | `main.lua` `cssbase`/`csslight`/`cssdark` and the provider swap |
| `lib/tally/store.rb`, `lib/tally/lua_config.rb` | `main.lua` `readcfg`/`writecfg`/`lib.queuewrite`/dir bootstrap |
| `lib/tally/icons.rb`, `data/icons/hicolor/**` | `main.lua` GResource load, `data/tally.gresource.xml`, `Makefile` icon install |
| `lib/tally/locale.rb` | `main.c` `lua_gettext`, `bindtextdomain`, `textdomain` |
| `lib/tally/metainfo.rb` | release notes, read from AppStream where upstream used a heredoc |
| `data/org.rubygtkproject.Tally{,.Devel}.desktop` | `ca.vlacroix.Tally{,.Devel}.desktop` |
| `data/org.rubygtkproject.Tally{,.Devel}.metainfo.xml` | `ca.vlacroix.Tally{,.Devel}.metainfo.xml` |
| `po/{fr,id,it}.po`, `po/MESSAGES.pot` | the same four files |
| `flake.nix` install phase, `rakelib/gettext.rake` | `Makefile` `install`, `.mo` build, `pot`/`po` rules |

The last parity audit put 20 of 26 units at parity. All 18 upstream signals and
all 4 actions are wired; every live widget instance upstream builds has a
counterpart; the stylesheet matches modulo indentation. Nothing here has been
compared against upstream *running* — see Open gaps.

## Not started

Upstream components with no Ruby counterpart at all:

| Upstream | Status |
|---|---|
| `ca.vlacroix.Tally.json` | not ported — no Flatpak manifest in the port |
| `ca.vlacroix.Tally.Devel.json` | not ported |
| `.github/workflows/ci.yml` (flatpak-builder) | not ported — `.github/workflows/` holds only `translations.yml` |
| `tally.doap` | not ported |
| `tally.png` (README screenshot) | not ported |
| `main.c` `main()` load-failure branch | not ported — `exe/tally` has no `rescue` |

## Open gaps

13 gaps across the parity reports in `.reports/`; clean = false.

`.reports/component-parity.md` — 6:

1. The app cannot be installed the way upstream is installed: no Flatpak
   manifest, no `.Devel` manifest, no CI job that builds one. Upstream's only
   documented install route is Flathub.
2. A failed start says nothing to the user. `main.c:125-133` prints a
   translated unrecoverable-error sentence to stderr and exits with the Lua
   error code; `exe/tally` produces a Ruby backtrace in English.
3. `tally.doap` is not ported.
4. The README shows no picture of the app. The driver writes twelve
   screenshots to `tmp/shots/`, which is gitignored; none is committed.
5. `lib/tally/color_selector.rb:40` sets `valign = :center` in the
   constructor, so it applies at all three call sites. Upstream sets it only
   at `counter:colorrow`; the search bar and the new-counter dialog default to
   `FILL`. `valign` needs to become a per-site argument.
6. Nothing has been compared against upstream running. Upstream is a
   Flatpak-only Lua app and has not been built here, so every "looks the same"
   claim rests on reading two source trees. Two of the port's own shots
   (`11-shortcuts.png`, `12-about.png`) catch the dialog mid-animation behind
   the main window and are not evidence.

`.reports/accountability-ensurance.md` — 6:

7. `lib/tally/application.rb:38-45` excuses the missing Flatpak packaging
   rather than recording it as a gap; the paragraph needs replacing in place.
8. The startup-failure gap is recorded nowhere in the port itself.
9. `tally.doap` and `tally.png` are absent and, before this file, no file in
   the port mentioned either.
10. There is no `FINDINGS.md`. Six ruby-gnome binding defects are recorded
    only as inline comments in the files that work around them
    (`application.rb:94-96`, `main_window.rb:182-187`, `styles.rb:234-243`,
    `counter_row.rb:305-311`, `icons.rb:103-109`,
    `shortcuts_dialog.rb:97-99`), where a gap row cannot cite them.
11. The `.reports/` ledgers went stale: they were written against `eb1f26ae`
    and not regenerated when `0dfc40d8` closed four rows. Ledgers must
    regenerate in the same commit as any change that moves a row.
12. Five "the port fixes an upstream bug" claims were audited and all five
    hold; nothing owed, recorded as checked.

`.reports/translation-parity.md` — 1:

13. 41 live upstream msgids against 40 in the port. The missing key is the
    startup-failure message from `main.c:127`; it is now `#~`-obsolete in
    `fr`, `id` and `it`, so three existing translations are dead. A further 18
    translated strings no longer reach the screen, and the catalogues carry
    four fuzzy and three empty entries each.

`.reports/test-parity.md`: upstream has no test suite, so 0 tests are owed and
0 are ported. Extra, not parity: `spec/` runs 83 examples and
`test/drive_tally.rb` 105 driven checks across 34 steps, both green.

## Blockers

Things that cannot be ported as-is, and why.

- **No declarative UI to transcribe.** Upstream has no `.ui`, no `.blp` and no
  GSettings schema. Every component was recovered by reading `main.lua` (862
  lines) and `counter.lua` (510 lines); the port is written from behaviour.
- **`main.c` does not port.** It exists only to boot a Lua state, `#embed` Lua
  bytecode and pass `-DPACKAGE`/`-DVERSION` from the Makefile. Ruby replaces
  all of it (`exe/tally` plus `lib/tally/rb/version.rb`). Its one portable
  behaviour — the load-failure message — is Gap 2.
- **The save format cannot be kept.** Upstream's config file is executable Lua
  source read with `load()`. A Ruby port must not eval it, so the port stores
  JSON. There is no read-compatibility with an existing upstream config beyond
  the one-way importer in `lib/tally/lua_config.rb`.
- **`Adwaita::Application` is broken in the Ruby bindings.** Upstream's
  `Adw.Application` becomes `Gtk::Application` with Adwaita widgets inside.
- **LuaGObject sugar has no Ruby equivalent.** `extra_css_classes`,
  `top_bars = …`, inline children in the constructor table and `on_notify.foo`
  become `add_css_class`, `add_top_bar`, `append` and
  `signal_connect('notify::foo')`. Mechanical, but it is most of the diff.
- **Drag-and-drop by GObject value is the riskiest piece.**
  `Gdk.ContentProvider.new_for_value(GObject.Value(Adw.ExpanderRow, row))` and
  `Gdk.ContentFormats.new_for_gtype(Adw.ExpanderRow)` depend on wrapping a
  widget in a `GObject::Value` of its own type. Implemented in
  `lib/tally/counter_row.rb`; the fallback if the bindings fight back is
  button-only reordering.
- **`Gtk.ShortcutsWindow`/`Group`/`Shortcut` are deprecated in GTK 4.18.** The
  local libadwaita is 1.9.0 and has `Adw.ShortcutsDialog`, so the structure
  maps but the widget names do not.
- **Version floors.** The stylesheet needs libadwaita 1.8+ for
  `var(--red-3)`-style palette variables and GTK 4.12+ for
  `Gtk::CssProvider#load_from_string`. Satisfied locally (libadwaita 1.9.0),
  but hard floors.
- **Two places poke widget internals that are not API.**
  `row.child:get_last_child()` for the ExpanderRow suffix box and
  `spinbtn:get_first_child()` for the entry inside the SpinButton.
  Version-fragile; may need a different approach.
- **Flatpak-only assumptions throughout upstream.** Hardcoded `/app/lib`,
  `/app/share`, `/app/data/tally.gresource`, `resource_base_path
  '/ca/vlacroix/Tally'`, and an `XDG_CONFIG_HOME` assumed to be set. The port
  resolves real paths with a `~/.config` fallback.
- **Translations are a separate parity axis.** 43 msgids upstream with fr / id
  / it catalogues, extracted by `xgettext` over Lua and C. The port has its own
  gettext setup (`rakelib/gettext.rake`); see Gap 13 for where it stands.
- **Three upstream bugs are fixed rather than reproduced.**
  `counter:popout` reassigns `self.spinbtn.on_notify.value` and so breaks the
  inline count label and the queued write once a counter has been popped out;
  `searchbar.key_capture_widget` is set to the `window` class table rather than
  `self.window`; the shortcuts window names `app.about` while the action is
  installed as `win.about`, and its section title uses an undefined
  `app_title` global. All three were verified against the upstream line.
- **One upstream defect is kept deliberately.** `cssdark`'s
  `.colorselector checkbox.system`, where every other rule says `checkbutton`
  — copying it is what makes the two apps render alike.
- **`Adw.MultiLayoutView`/`Layout`/`LayoutSlot` exist in libadwaita 1.9** and
  are portable, but `Adw.LayoutSlot.new` takes positional args; the responsive
  behaviour can otherwise be reproduced by swapping the `Adw::Clamp` in the
  breakpoint handler.
- **Dead upstream resource.**
  `data/icons/.../cross-large-circle-outline-symbolic.svg` is bundled in the
  GResource but referenced nowhere in the Lua. Not carried over.

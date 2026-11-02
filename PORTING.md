# Porting Tally to Ruby

Resume point for the next run. Factual status only; the per-axis detail lives
in `.reports/`.

| | |
|---|---|
| Upstream spec | `origin/trunk` @ `e9986b010c950d2df91b682769b744c412348e0c` |
| Port branch | `ruby` |
| Last audit | `2f14cbb` — **3 open gaps + 7 coverage gaps + 5 accountability findings**, clean = false |

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

The last parity audit (`.reports/`, regenerated at `2f14cbb`) puts **19 of 22
units at parity**. All 18 upstream signals and all 4 actions are wired and
fired; every live widget instance upstream builds has a counterpart; the
stylesheet is upstream's three heredocs transcribed verbatim, identical modulo
indentation; 41 code msgids and 23 metadata msgids are byte-identical in both
directions; all three languages reach the screen.

Runs, all performed for that audit and none transcribed from a previous one:

| Command | Result |
|---|---|
| `nix develop --command xvfb-run -a ruby test/drive_tally.rb` | **214 of 214 checks passed, DRIVE OK** (62 steps, 15 shots) |
| `nix develop --command ruby -e '…RSpec…'` | **83 examples, 0 failures** |
| `nix develop --command rake pot:check` | `po/MESSAGES.pot` is up to date |
| `LANGUAGE=fr` / `it` / `id`, window built headless | `Compteur` / `Contatore` / `Penghitung` |

## Not started

**Nothing.** Every upstream file now has a Ruby counterpart; the mapping above
is complete. The six rows that stood here until `2f14cbb` — both Flatpak
manifests, the CI job, the doap, the README screenshot and `main.c`'s
load-failure branch — were all built by `7d042e3` and `2f14cbb`, and this table
went on listing them as absent for two commits. That is Finding 1 of
`.reports/accountability-ensurance.md`.

## Open gaps

3 component gaps, 7 coverage gaps and 5 accountability findings across the
parity reports in `.reports/`; **clean = false**.

`.reports/component-parity.md` — 3:

1. `lib/tally/color_selector.rb:40` sets `valign = :center` in the
   constructor, so it applies at all three call sites. Upstream sets it only at
   `counter:colorrow` (`counter.lua:201-207`); `searchcolorbox`
   (`main.lua:317-321`) and `tallycolorbox` (`main.lua:567-571`) set none, so
   upstream's are `FILL`. `valign` needs to become a per-site argument.
2. `lib/tally/counter_drag_row.rb:49` sets `valign = :center` on the drag
   preview's spin button; `counter.lua:471-473` sets nothing on it.
3. Nothing has been compared against upstream *running*. Upstream is a
   Flatpak-only Lua app and has not been built here, so every "looks the same"
   claim rests on reading two source trees and on 15 screenshots of the port
   alone.

`.reports/test-parity.md` — parity is **0/0**, met trivially: upstream has no
test suite at all (census empty, no `test/` directory, no test target in the
`Makefile`, no test job in its CI). The port therefore **inherits no safety
net** — not one check in it was written from an upstream test. Seven coverage
gaps against the port's own suites, each a behaviour the port builds and no
check exercises:

4. C1 — the main window's `close-request` closing every pop-out.
5. C2 — the About dialog's two translatable link labels and its `copyright`,
   `developer_name`, `license_type`, `website` and `translator_credits`.
6. C3 — `Store#queue_write`'s one-second debounce ever actually writing; only
   the refusal path is driven.
7. C4 — `search_bar.key_capture_widget`, which is the one thing upstream
   gets wrong (`main.lua:503` assigns the class table, not the window).
8. C5 — `scroll_into_view` and `scroll_to_bottom` are asserted to return,
   not to scroll.
9. C6 — `Application#shutdown` writing the config.
10. C7 — **no check in the driver reads a `valign`, `halign`, `margin_*` or
    `spacing` off any widget**, which is how gaps 1 and 2 above sat inside a
    green run for two commits.

`.reports/translation-parity.md` — parity **holds**: 41/41 messages, 51/51
occurrences, 23/23 metadata messages, 3/3 languages, 0 gaps, 0 extra, verified
on screen in all three. Two open items, neither a parity gap:

11. The port has **no gettext domain and no `.mo`** — `Tally::Locale` reads
    `po/*.po` at runtime. Delivery works; `msgfmt -c` validation, plural forms,
    `msgctxt` and the `LC_MESSAGES` lookup path do not exist.
12. Seven msgids are English in all three languages (`Add to List`,
    `Create Counter`, `New Counter`, `No Counters`, `Reorder in List`,
    `Show in a Separate Window`, `Support this app!`). Upstream shows the same
    seven in English, because its `po/MESSAGES.pot` is dated 2025-06-21 and
    four of the seven were renamed after that. The fix is an upstream issue and
    **it has not been filed**.

`.reports/accountability-ensurance.md` — 5:

13. This file lied in six places about work that exists (above). Fixed in the
    same commit as that report; the rule it broke — ledgers regenerate in the
    commit that moves a row — has now been broken twice.
14. Five ledgers carried "passes 105 driven checks" through two commits of
    behaviour without re-running anything. The number is 214.
15. There is still no `FINDINGS.md`. Six ruby-gnome binding defects are
    recorded only as inline comments (`application.rb:156-157`,
    `main_window.rb:183-187`, `styles.rb:234-243`, `counter_row.rb:281-291`
    and `:320-325`, `icons.rb:21-28` and `:94-100`,
    `shortcuts_dialog.rb:97-99`), where no gap row can cite them.
16. The two alignment divergences above survived a second audit, and the axis
    they live on is unverified (C7).
17. Six "the port fixes an upstream bug" claims were re-audited and **all six
    hold**; three of them are genuine upstream bugs with user-visible
    consequences and **none has been reported upstream**.

## How the port is spelled differently

Not blockers. Every item below is built and driven, and none of it may be
cited to excuse a gap. These are the places where upstream's mechanism has no direct
Ruby spelling and the port reaches the same behaviour another way. Each one is
also a reason some future gap might be *hard*, which is `FINDINGS.md`'s job —
and `FINDINGS.md` does not exist yet, which is Open gap 15.

- **No declarative UI to transcribe.** Upstream has no `.ui`, no `.blp` and no
  GSettings schema. Every component was recovered by reading `main.lua` (862
  lines) and `counter.lua` (510 lines); the port is written from behaviour.
- **`main.c` is a Lua bootstrap, and its behaviour is in Ruby.** It exists only
  to boot a Lua state, `#embed` Lua
  bytecode and pass `-DPACKAGE`/`-DVERSION` from the Makefile. Ruby replaces
  all of it (`exe/tally` plus `lib/tally/rb/version.rb`). Its one portable
  behaviour — the load-failure message — is ported, at
  `lib/tally/application.rb:59-125`.
- **The save format is not kept, and must not be.** Upstream's config file is executable Lua
  source read with `load()`. A Ruby port must not eval it, so the port stores
  JSON. There is no read-compatibility with an existing upstream config beyond
  the one-way importer in `lib/tally/lua_config.rb`.
- **`Adwaita::Application` is broken in the Ruby bindings.** Upstream's
  `Adw.Application` becomes `Gtk::Application` with Adwaita widgets inside.
- **LuaGObject's constructor-table sugar is spelled out here.**
  `extra_css_classes`, `top_bars = …`, inline children in the constructor table
  and `on_notify.foo` become `add_css_class`, `add_top_bar`, `append` and
  `signal_connect('notify::foo')`. Every one is present; it is mechanical, and
  it is most of the diff.
- **Drag-and-drop by GObject value is the riskiest piece.**
  `Gdk.ContentProvider.new_for_value(GObject.Value(Adw.ExpanderRow, row))` and
  `Gdk.ContentFormats.new_for_gtype(Adw.ExpanderRow)` depend on wrapping a
  widget in a `GObject::Value` of its own type. **Implemented and working** —
  `lib/tally/counter_row.rb:287-291, :326-371`, driven in both directions by
  steps 47–49. It took two binding defects to get there (the provider's gtype,
  and `GtkDropTarget::drop` handing the handler a `GLib::Value` rather than the
  widget), both fixed in `2f14cbb`. There is no fallback and none is owed.
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

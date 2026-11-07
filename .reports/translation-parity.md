# Translation parity — tally / tally-rb

> **Superseded in part — read this first.** Open item 1's own closing
> condition ("either adopt the gettext gem … or wire a `msgfmt -c` lint over
> `po/` into the same target that runs the specs") is met on `ruby` since this
> was written: `rake po:lint` validates all three catalogues with
> `msgfmt --check --check-format` and runs inside `rake check` alongside the
> specs and `rake pot:check`. The reader is still a reader — no `.mo`, no
> plural-forms engine, no `msgctxt`, no `LC_MESSAGES` lookup — and that is
> recorded as spelling, not as a gap. Open items 2 (seven English msgids,
> inherited from a stale upstream template, **not filed upstream**) and 3 (all
> 23 metadata msgids reaching no catalogue in either project, with no `data/`
> extraction on the port's side) are untouched and still open.

> **Reverified 2026-11-06 @ `0be085f`.** `po/{fr,id,it}.po` and
> `po/MESSAGES.pot` are unchanged since this ledger was written (no diff under
> `po/` since `c95adfa`), and `rake check`'s `po:lint` + `pot:check` passed
> again in this session (see `.reports/test-parity.md`). The 41/41 code-msgid
> and 23/23 metadata-msgid parity verdict still holds; items 2 and 3 are still
> open and still not filed as upstream issues.

|  |  |
|---|---|
| Upstream | `origin/trunk` @ `e9986b010c950d2df91b682769b744c412348e0c` |
| Port | `ruby` @ `2f14cbbebfa83db2cf8c7349b0be9b108744b353` |
| Domain | `messages` upstream (`bindtextdomain("messages", "/app/share/locale")`, `main.c:110-111`). **The port has no domain** — see Open item 1 |
| Upstream messages, app code | **41** |
| Ported | **41** |
| Gaps | **0** |
| Extra (port keys upstream never had) | **0** |
| Upstream messages, project metadata | 23 |
| Ported | 23 |
| Gaps | 0 |
| Upstream occurrences | 51 across 41 keys (6 reused) |
| Port occurrences | 51 across 41 keys (6 reused) |
| Upstream languages | 3 `.po` files (`fr`, `id`, `it`), 42 entries each |
| Languages shipped by the port | **3 of 3** — the same three files |
| Kind mismatches | 0 (no plurals and no `msgctxt` anywhere on either side) |
| Byte-identical | yes, all 41 + 23, verified by set diff in both directions |
| Verified on screen | **yes** — `fr`, `it` and `id`, live, this audit |
| Template check | `rake pot:check` → `po/MESSAGES.pot` is up to date |
| Verdict | **parity holds. Two open items on delivery, and seven strings that reach no translator in either project.** |

## Census

### The scanner cannot read the upstream side either

```sh
$ .claude/skills/translation-parity/scripts/msgid-census.sh up | grep -v $'\t'po/ | cut -f4 | cut -d: -f1 | sort | uniq -c
      3 ca.vlacroix.Tally.desktop
      3 ca.vlacroix.Tally.Devel.desktop
      7 ca.vlacroix.Tally.Devel.metainfo.xml
     10 ca.vlacroix.Tally.metainfo.xml
      1 main.c
      1 (an !unresolved row from main.c:54)
```

**Not one row from `main.lua` or `counter.lua`.** The census knows Vala, C,
blueprint, GtkBuilder XML, Python, GJS, Rust and the Ruby gettext gem; it does
not know Lua, and upstream's marker is `local _ = lib.gettext` called in Lua's
parenthesis-free form — `_ "Red"`, `_ "No Counters"`. Nothing in the regex set
matches `_ "…"` with a space and no bracket.

That is 40 of upstream's 41 code messages invisible, which would read as a port
with 40 extra keys and upstream with almost none. Reported to the skill. Until
it is fixed, upstream's code census here is **by hand**, reproducibly:

```sh
$ for f in main.lua counter.lua; do grep -nEo '(\b_|lib\.gettext) *"[^"]*"' $f; done | wc -l
50
$ … | sed -E 's/^[0-9]+:(_|lib\.gettext) *"//; s/"$//' | sort -u | wc -l
40
```

50 call sites, 40 distinct keys, plus `main.c:131`'s
`gettext("An unrecoverable error occurred when loading Tally, preventing the
program from starting.\n")` = **41**. The `!unresolved` row is `main.c:54`'s
`gettext(msgid)` inside `lua_gettext` — the C stub that *is* the marker, not a
message. Censused and dismissed, not ignored.

The port side the scanner reads fine: 245 rows, of which 7 are `!unresolved`
(`_(label)`, `_(title)`, `_(msgid)` — every one a lookup over a table whose
literals are marked `N_` in the same file and already counted, in
`ShortcutsDialog::SECTIONS`, `MainMenu::ITEMS`, `AboutDialog::LINKS`,
`Colors::NAMES` and `Application::LOAD_FAILURE`). **`totals.unresolved` is
accounted for; no ledger row rests on an unread marker.**

### The key-set diff

```sh
$ comm -23 up.keys port.keys | wc -l     # gaps
0
$ comm -13 up.keys port.keys | wc -l     # extra
0
$ comm -12 up.keys port.keys | wc -l     # ported
56          # 41 code + 23 metadata, less 8 keys that occur in both groups
```

Both directions empty. Every one of upstream's 41 code msgids and 23 metadata
msgids is produced by the port, byte for byte — including the three that are
easiest to retype wrong and that no English screenshot would show:

| Key | The trap |
|---|---|
| `Filter by name…` | U+2026 HORIZONTAL ELLIPSIS, not three full stops |
| `An unrecoverable error occurred when loading Tally, preventing the program from starting.\n` | the trailing newline is part of the msgid |
| `translator-credits` | the conventional lowercase hyphenated form, not `Translator credits` |

### Cross-check against the `.po` files

Upstream's committed template is **stale** and that is the finding, not a
problem with the census:

```sh
$ grep -m1 POT-Creation-Date up/po/MESSAGES.pot
"POT-Creation-Date: 2025-06-21 14:51-0400\n"
```

June 2025, against an `origin/trunk` whose newest `<release>` is 2025-12-18.
Six months behind, so it is a lead, not ground truth. Every line of the
difference against the hand census is explainable, and all three of the
skill's categories are present:

**Only in the `.pot`** — seven keys upstream's source has since changed or
dropped. Three are renames the source made and the template never saw; four
are strings the source deleted:

| In the stale `.pot` | In `origin/trunk`'s source today |
|---|---|
| `Add to list` | `Add to List` (`main.lua:546`) |
| `Show in a separate window` | `Show in a Separate Window` (`counter.lua:286`) |
| `Send a tip!` | `Support this app!` (`main.lua:223`) |
| `Move to top`, `Move to bottom`, `Move up`, `Move down` | gone — the four order buttons are icon-only now, with only their tooltips marked |

**Only in the source, and in no `.po` at all** — eight code keys that have
never been extracted in any language, ever:

```
Add to List · An unrecoverable error occurred when loading Tally, …\n ·
Create Counter · New Counter · No Counters · Reorder in List ·
Show in a Separate Window · Support this app!
```
plus all 23 metadata keys (below). This is an upstream bug, live today:
`Makefile:52-53` runs `xgettext --from-code utf-8 -o po/MESSAGES.pot $(LSRCS)
$(CSRCS)` and nobody has run it since June, so eight strings a user reads on
screen have never been offered to a translator.

**Only in the source, present in some other language's `.po`** — none.
All three catalogues are at the same revision.

### The metadata strings reach no catalogue, on either side

`Makefile:52-53` extracts from `*.lua` and `*.c` only. The `.desktop` and
`.metainfo.xml` files are not `.in` templates, carry no `xml:lang` entries, and
appear in no `POTFILES`. So all 23 metadata msgids — `Count anything`,
`Keep, categorize, and organize a list of tally counters.`,
`tally;counter;tally counter;`, `Tally Nightly` and the rest — are **English
only in upstream and English only here**, and `appstreamcli`/`desktop-file-validate`
would both pass.

The key sets are equal, so this is parity. It is also a real defect, inherited,
and it belongs in a report upstream.

There is no `POTFILES.in` on either side to check for completeness. The port's
equivalent is `rake pot:check`, which re-extracts from `Dir["lib/**/*.rb"] +
Dir["exe/*"]` and fails on any drift — run for this audit, and it passes. That
covers every file that can hold a Ruby call site. It does **not** cover
`data/`, for the same reason upstream's does not.

## The ledger

Grouped by upstream source file, mapped to the port file that replaced it.
`Uses` is `<upstream call sites> → <port call sites>`.

### `main.c` → `lib/tally/application.rb` (1 message)

| # | msgid | Kind | Uses | Port site | State |
|---|---|---|---:|---|---|
| 1 | `An unrecoverable error occurred when loading Tally, preventing the program from starting.\n` | single | 1 → 1 | `application.rb:68` `N_(…)`, translated at `:122` | ported |

The msgid is carried whole, trailing `\n` included. Upstream's own `.po` files
have no translation for it, because it has never been extracted (above), so
`fr`, `id` and `it` all show the English — identically on both sides.

### `main.lua` window, header bar, search bar, status page → `lib/tally/main_window.rb`, `search_bar.rb`, `empty_state.rb` (10 messages)

| # | msgid | Kind | Uses | Port site | State |
|---|---|---|---:|---|---|
| 2 | `Tally` | single | 6 → 5 | `main_window.rb:50, :110`, `counter_window.rb:100, :215`, `about_dialog.rb:47` | ported ⚠ |
| 3 | `Create a new counter` | single | 1 → 1 | `main_window.rb:117` | ported |
| 4 | `Delete selected counters` | single | 1 → 1 | `main_window.rb:125` | ported |
| 5 | `Select counters to delete` | single | 2 → 2 | `main_window.rb:134, :297` | ported |
| 6 | `Stop selecting without deleting anything` | single | 1 → 1 | `main_window.rb:293` | ported |
| 7 | `Filter counters by name and/or color` | single | 1 → 1 | `main_window.rb:141` | ported |
| 8 | `Menu` | single | 1 → 1 | `main_window.rb:149` | ported |
| 9 | `Filter by name…` | single | 1 → 1 | `search_bar.rb:56` | ported |
| 10 | `No Counters` | single | 1 → 1 | `empty_state.rb:20` | ported — **untranslated in all three**, see Open item 2 |
| 11 | `Create Counter` | single | 1 → 1 | `empty_state.rb:33` | ported — **untranslated in all three** |

Row 2's `6 → 5` is the one `Uses` mismatch in the ledger, and per the skill it
opens an investigation rather than a translation row. Investigated: upstream's
sixth call site is `counter.lua:302`,
`self.zoomwin.title = entry.text .. " — " .. lib.gettext "Tally"` inside the
rename handler, which rebuilds the pop-out's title string a second time. The
port builds that title in one place — `CounterWindow#formatted_title`
(`counter_window.rb:215`) — and calls it from both the constructor and
`#refresh_title`. One helper, two callers, same two titles on screen. Verified
by the driver: step 27 renames through the menu's entry row and asserts the
pop-out's title followed. No component row is owed.

### `main.lua` `lib.getcolorname` → `lib/tally/colors.rb` (7 messages)

| # | msgid | Kind | Uses | Port site | State |
|---|---|---|---:|---|---|
| 12 | `No color` | single | 1 → 1 | `colors.rb:25` `N_`, used at `:35` | ported |
| 13 | `Red` | single | 1 → 1 | `colors.rb:26` | ported |
| 14 | `Orange` | single | 1 → 1 | `colors.rb:27` | ported |
| 15 | `Yellow` | single | 1 → 1 | `colors.rb:28` | ported |
| 16 | `Green` | single | 1 → 1 | `colors.rb:29` | ported |
| 17 | `Blue` | single | 1 → 1 | `colors.rb:30` | ported |
| 18 | `Purple` | single | 1 → 1 | `colors.rb:31` | ported |

Upstream reaches all seven through one `if`-chain in `lib.getcolorname`, called
from four places; the port holds them in a frozen `NAMES` table marked `N_` and
translates at the point of use, which is why `Colors.name` carries a `_(…)`
nowhere near the literal. Same keys out.

### `main.lua` `window:tallydialog` → `lib/tally/new_counter_dialog.rb` (4 messages)

| # | msgid | Kind | Uses | Port site | State |
|---|---|---|---:|---|---|
| 19 | `New Counter` | single | 1 → 1 | `new_counter_dialog.rb:30` | ported — **untranslated in all three** |
| 20 | `Name` | single | 2 → 2 | `new_counter_dialog.rb:79`, `counter_menu.rb:58` | ported |
| 21 | `Add to List` | single | 1 → 1 | `new_counter_dialog.rb:99` | ported — **untranslated in all three** |
| 22 | `Add this counter to the list` | single | 1 → 1 | `new_counter_dialog.rb:89` | ported |

### `main.lua` `tallymenu` and `newshortcutwindow` → `lib/tally/main_menu.rb`, `shortcuts_dialog.rb` (6 messages)

| # | msgid | Kind | Uses | Port site | State |
|---|---|---|---:|---|---|
| 23 | `Keyboard Shortcuts` | single | 2 → 3 | `main_menu.rb:17`, `shortcuts_dialog.rb:46, :69` | ported |
| 24 | `About Tally` | single | 2 → 2 | `main_menu.rb:18`, `shortcuts_dialog.rb:47` | ported |
| 25 | `Main Window` | single | 1 → 1 | `shortcuts_dialog.rb:44` | ported |
| 26 | `Counter Window` | single | 1 → 1 | `shortcuts_dialog.rb:49` | ported |
| 27 | `Quit Application` | single | 2 → 2 | `shortcuts_dialog.rb:45, :50` | ported |
| 28 | `Close Window` | single | 1 → 1 | `shortcuts_dialog.rb:51` | ported |

`Keyboard Shortcuts` gains two call sites: the port also uses it as the
dialog's own title, where upstream's section title is `app_title`, an undefined
Lua global. A `Uses` mismatch upward, not a dropped call site.

### `main.lua` `aboutwin` → `lib/tally/about_dialog.rb` (3 messages)

| # | msgid | Kind | Uses | Port site | State |
|---|---|---|---:|---|---|
| 29 | `Translate this app!` | single | 1 → 1 | `about_dialog.rb:37` `N_`, used at `:62` | ported |
| 30 | `Support this app!` | single | 1 → 1 | `about_dialog.rb:38` | ported — **untranslated in all three** |
| 31 | `translator-credits` | single | 1 → 1 | `about_dialog.rb:52` | ported |

Upstream's `release_notes` heredoc (`main.lua:224-226`) is **unmarked** — a bare
Lua long string with no `_`. The port reads the identical text out of the
AppStream file. Not a message on either side, so not a row; it is in no
catalogue in either project, which is upstream's debt and is why the `fr`,
`id` and `it` files all carry a translated `<p>Various enhancements…</p>` for a
release note that no longer exists.

### `counter.lua` `counter:createmenu` → `lib/tally/counter_menu.rb` (6 messages)

| # | msgid | Kind | Uses | Port site | State |
|---|---|---|---:|---|---|
| 32 | `Color` | single | 1 → 1 | `counter_menu.rb:66` | ported |
| 33 | `Reorder in List` | single | 1 → 1 | `counter_menu.rb:80` | ported — **untranslated in all three** |
| 34 | `Show in a Separate Window` | single | 1 → 1 | `counter_menu.rb:128` | ported — **untranslated in all three** |
| 35 | `Move counter to the top of the current list` | single | 1 → 1 | `counter_menu.rb:101` | ported |
| 36 | `Move counter to just above the previous row` | single | 1 → 1 | `counter_menu.rb:108` | ported |
| 37 | `Move counter to just below the next row` | single | 1 → 1 | `counter_menu.rb:115` | ported |
| 38 | `Move counter to the bottom of the current list` | single | 1 → 1 | `counter_menu.rb:122` | ported |
| 39 | `Create a new window for this counter` | single | 1 → 1 | `counter_menu.rb:136` | ported |

(`Name` is row 20, grouped under the file the census lists first.)

### `counter.lua` `counter:popout` → `lib/tally/counter_window.rb` (2 messages)

| # | msgid | Kind | Uses | Port site | State |
|---|---|---|---:|---|---|
| 40 | `Decrement by 1` | single | 1 → 1 | `counter_window.rb:121` | ported |
| 41 | `Increment by 1` | single | 1 → 1 | `counter_window.rb:127` | ported |

### Project metadata → `data/` (23 messages)

Identical sets both directions, verified file by file: 3 keys each from the two
`.desktop` files, 10 from `org.rubygtkproject.Tally.metainfo.xml` and 7 from
the `.Devel` one. Extracted by neither project (above).

| State | Count |
|---|---:|
| ported | 23 |
| gap | 0 |

## The languages

```sh
$ diff <(ls up/po/*.po | xargs -n1 basename) <(ls po/*.po | xargs -n1 basename)
$ 
```

Identical: `fr.po`, `id.po`, `it.po`. No `LINGUAS` on either side, so there is
no file-list-versus-`LINGUAS` mismatch to find. No CRLF file (`file` reports
all six as plain UTF-8 message catalogues). No obsolete-entry inflation — the
counts below skip `#~` blocks.

**Was any donated translation destroyed by the port?** This is the question the
whole skill exists for, so it was computed rather than asserted: for each
language, the set of keys with a usable (non-empty, non-fuzzy) `msgstr`
upstream, intersected with the keys that are still in upstream's *source*, minus
the keys with a usable `msgstr` in the port.

```
fr: upstream usable 42, port usable 34 — live msgids lost: 0
id: upstream usable 42, port usable 34 — live msgids lost: 0
it: upstream usable 42, port usable 34 — live msgids lost: 0
```

**Zero.** Every translation that still had a live msgid to attach to came
across. The eight-entry drop is upstream's stale template, not the port's
msgmerge: the eight keys whose translations the port cannot use are the four
renames and four never-extracted strings listed above, and upstream's own
binary shows English for exactly the same eight.

| | `fr` | `id` | `it` |
|---|---:|---:|---:|
| Entries | 42 | 42 | 42 |
| Translated and usable | 34 | 34 | 34 |
| Fuzzy — **untranslated at runtime** | 4 | 4 | 4 |
| Empty | 3 | 3 | 3 |
| Obsolete (`#~`, ignored) | 8 | 8 | 8 |

The four fuzzy entries are the same four in all three files — `Add to List`,
`Create Counter`, `Show in a Separate Window`, `Support this app!` — and they
are `msgmerge`'s guesses against the renamed msgids. The three empty ones are
`New Counter`, `No Counters`, `Reorder in List`, which the stale template never
carried at all. Seven strings, three languages, 21 cells of English. See Open
item 2.

## Verified on screen

Not a document check. Run for this audit, headless under `xvfb-run`, building
the real main window:

```
$ LANGUAGE=fr ruby -e '… Tally::Application.new.window …'
language="fr"   title="Compteur"   new_button="Créer un nouveau compteur"
                search placeholder="Filtrer par nom…"
                colours=["Aucun couleur","Rouge","Orange","Jaune","Vert","Bleu","Violet"]
$ LANGUAGE=it …
language="it"   title="Contatore"  new_button="Crea un nuovo contatore"
                search placeholder="Filtra per nome…"
                colours=["Nessun colore","Rosso","Arancione","Giallo","Verde","Blu","Viola"]
$ LANGUAGE=id …
language="id"   title="Penghitung" new_button="Buat penghitung baru"
                search placeholder="Saring dengan nama…"
                colours=["Tak berwarna","Merah","Oranye","Kuning","Hijau","Biru","Ungu"]
```

All three languages reach the user. `No Counters` and `Create Counter` came
back English in all three, which is Open item 2 and not a wiring fault — the
`msgstr` is not there to show.

The driver covers one language as a standing check: step 54, "the French
catalogue translates upstream's own msgids".

## Open items

Neither is a parity gap. Both are real, both have costs, and neither may be
read as closed.

### Open item 1 — there is no gettext domain and no `.mo`

`main.c:110-111` binds the domain `messages` to `/app/share/locale` and
`Makefile:44-46` compiles one `.mo` per `.po` with `msgfmt`. The port does
neither: `Tally::Locale` reads `po/*.po` at startup with a 70-line parser
(`locale.rb:91-159`) and looks messages up out of a Hash.

Delivery is satisfied — the skill's requirement is that every shipped language
reaches the user, and all three provably do, above. `domain_matches` is not
satisfied, because there is no domain to match. Four concrete costs follow, and
they are the item:

1. **No `msgfmt -c` validation.** A malformed `.po` is caught by nothing. GNU
   `msgfmt` would refuse it; this parser skips the entry and carries on.
2. **No plural-forms engine.** `n_()` does not exist here. Upstream has no
   plurals today, so nothing is broken — and the day one is added, the port
   cannot express it.
3. **No `msgctxt` support.** The parser's state machine has `msgid` and
   `msgstr` and no third field. Upstream has no contexts today; same shape of
   exposure.
4. **No `LC_MESSAGES` lookup path**, so a `.mo` a distribution installs is
   ignored; only the `.po` files inside the gem are read.

What the shape buys, and why it is not simply wrong: `flake.nix` needs no
`msgfmt` at build time, the catalogues are readable in the installed gem, and
fuzzy handling is explicit and tested (17 examples). But it is a divergence
from the mechanism upstream uses, and the four costs above are open, not
waived.

### Open item 2 — seven strings are English in all three languages, and nobody has told upstream

`Add to List`, `Create Counter`, `New Counter`, `No Counters`,
`Reorder in List`, `Show in a Separate Window`, `Support this app!`

Four are fuzzy guesses `gettext` would discard and this reader does discard;
three have no entry at all. `No Counters` and `Create Counter` are the entire
text of the screen a user sees on first launch.

**This is upstream's debt and the port inherits it exactly** — upstream's
binary shows the same seven in English, because its `po/MESSAGES.pot` has not
been regenerated since June 2025 and four of the seven were renamed after that.
So the key sets stay equal and parity holds. It is not a reason to leave it
alone:

- the correct fix for the four renames is **not** to carry the old
  translation across under the new msgid — that is retyping a translator's work
  under a key they never saw. The row stays open until a translator supplies
  the new bytes.
- the fix that *is* available: file the stale-template bug upstream, with the
  four renames named, so `xgettext` runs and the next `msgmerge` offers all
  seven to the `fr`, `id` and `it` teams. Upstream is registered where
  translations actually get written; this fork is not and never will be.

Not done. `.reports/accountability-ensurance.md` carries it as a debt with an
owner.

### Also not done, and smaller

- The 23 metadata msgids reach no catalogue in either project (above). The port
  could offer them — add them to the extraction and give `fr`, `id` and `it` a
  translated launcher name and AppStream summary — and that is the one place
  this port can hand translators something upstream never did. It has not.
- There is no `POTFILES`-completeness check for `data/`. `rake pot:check`
  covers `lib/` and `exe/` and is wired to nothing that runs automatically;
  `.github/workflows/translations.yml` exists but was not exercised by this
  audit.

## Round 2 addendum — 2026-11-06

**The "23 metadata msgids" row above is now closed, and closed in a way that
goes beyond parity, not just to match it.** `data/*.desktop` and
`data/*.metainfo.xml` are generated files now: `data/*.desktop.in` and
`data/*.metainfo.xml.in` are the new committed templates, `rake pot` extracts
from them (`xgettext -L Desktop`, `xgettext --its=metainfo.its`) joined onto
the same `po/MESSAGES.pot` the Ruby sources feed, and the new `rake data` /
`rake data:check` pair (wired into `rake check`) builds and verifies the real
files with `msgfmt --desktop` / `msgfmt --xml`. See
`/home/nathan/src/github/ruby-gtk-project/tally-rb/rakelib/gettext.rake`.

Every existing hand-duplicated translation (`Name[fr]=Compteur`, etc.) was
seeded into `po/fr.po`, `po/id.po` and `po/it.po` as real msgid/msgstr pairs
before the switch, verified byte-for-byte unchanged in the regenerated
`data/*.desktop` files (`spec/tally/metainfo_spec.rb` already pins this).
`data/*.metainfo.xml`, which had **zero** translations on either side before
this round, now gets `<name xml:lang="…">`/`<summary xml:lang="…">` for fr,
id and it for free, because its `<name>`/`<summary>` share the identical
English strings the desktop entries already had translated. That is new
behavior the port has and upstream does not — noted here as exactly that, not
folded silently into "parity holds."

Still open, and not attempted this round:

- **Open item 2** (the stale upstream POT / 7 English-everywhere msgids) and
  the three "port fixes an upstream bug" claims in
  `.reports/accountability-ensurance.md` all call for filing an issue against
  upstream. Upstream's own `README.md` (`git show origin/trunk:README.md`)
  says development moved to Codeberg (`codeberg.org/vtrlx/tally`) and asks
  for issues there, but also still names `github.com/vtrlx/tally` further
  down; checking, `github.com/vtrlx/tally` is **archived** (`gh repo view
  vtrlx/tally --json isArchived` → `true`), which disables new issues there,
  and this session has no Codeberg credentials (Gitea API/tea CLI) to file on
  the Codeberg mirror — fetching or probing for any would be credential
  exploration, which this session's permissions correctly refuse. Filing
  those issues stays a named gap, not a silent drop; see
  `.reports/accountability-ensurance.md`'s matching addendum.
- Building upstream's Flatpak manifest, or running its Lua/LuaGObject stack
  headlessly, to compare both apps on screen side by side (component-parity.md
  Gap 3) was not attempted this round — it needs network access for
  `flatpak-builder` to fetch and compile Lua 5.4 and LuaGObject inside
  `org.gnome.Sdk`, which is a multi-GB, long-running build out of scope for
  this pass. Still open.

## Report line

```
41/41 messages · 51/51 occurrences · 23/23 metadata messages · 3/3 languages
· 102 of 126 catalogue entries usable
· fr, it, id verified on screen · 0 gaps · 0 extra · no domain, no .mo
```

## Rules check

- Nothing was reworded. Every one of the 64 keys is byte-identical, in both
  directions, verified by `comm` and not by reading.
- No `#{}` inside a marked string anywhere in `lib/` or `exe/`: the only
  interpolations near a marker are `"#{counter.name} — #{_("Tally")}"`
  (`counter_window.rb:215`) and `"#{Rb::Version::VERSION} (tally #{…})"`
  (`about_dialog.rb:80`), both of which interpolate *around* a marked key, not
  inside one.
- No plural was renumbered — there are none.
- The domain was not invented. There is none, which is Open item 1 rather than
  a new name.
- No row is `ported` from reading the code; every one is from the census.
- `totals.unresolved` was non-zero on both sides and both were censused by hand
  before this ledger was written: 1 upstream (`main.c:54`, the marker itself)
  and 7 in the port (table lookups whose literals are `N_`-marked and counted).
- Two checks that could not be run are named as unrun rather than passed:
  `msgfmt -c` (no domain to compile for — Open item 1) and the comparison
  against upstream *running* (upstream has not been built here —
  `.reports/component-parity.md` Gap 3).
- Both scanner defects found en route — Lua markers in `msgid-census.sh`, Lua
  widgets in `component-scan.sh` — are reported to the skill rather than worked
  around silently.

## Reverified 2026-11-07 @ `f3f4911`

Re-ran this session: `nix develop --command rake check` →
`po/fr.po is valid.` / `po/id.po is valid.` / `po/it.po is valid.` (one
pre-existing header warning on `it.po`'s `Project-Id-Version`, unchanged from
prior rounds and not a validity failure) / `po/MESSAGES.pot is up to date.` /
`data/*.desktop and data/*.metainfo.xml are up to date.` All five green, all
five produced by this session's own run.

The "Round 2 addendum" above, dated 2026-11-06, already describes the
substance of `f3f4911` (it was written for the commit that became `f3f4911`
once pushed) — the 23 metadata msgids now flow through
`data/*.desktop.in` → `rake data` → `data/*.desktop`, joined onto the same
`po/MESSAGES.pot` the Ruby sources feed, with `fr`/`id`/`it` translations for
every `<name>`/`<summary>` that already had one via the `.desktop` files.
Nothing new to add to that account; this note exists so a future reader does
not have to infer that the addendum and this commit are the same event.

**Still open, unchanged, and still outside what this session can do:**

- Open item 1 (no gettext domain, no `.mo`) — unchanged, a spelling choice
  with four named costs, not a parity gap.
- Open item 2 (seven msgids English in all three languages because
  upstream's own `po/MESSAGES.pot` is stale) — unchanged. Re-confirmed this
  round: `grep -c msgid po/fr.po` → still 42 entries, the same four fuzzy +
  three empty keys as last round. Filing this upstream remains blocked by the
  same credential gap `.reports/accountability-ensurance.md` documents
  (archived GitHub mirror, no Codeberg credentials in this session).
- The metadata-extraction gap this round closed was a **real defect**, not a
  cosmetic one: before `f3f4911`, a translator fixing the English in
  `data/org.rubygtkproject.Tally.metainfo.xml` by hand would have had their
  edit silently overwritten the next time anyone touched the `.xml.in`
  template, because the two had no connection. That class of defect is now
  gone for `data/`, not merely documented as present.

Verdict unchanged: **parity holds**, 41/41 code msgids, 23/23 metadata
msgids, 3/3 languages, 0 gaps, 0 extra.

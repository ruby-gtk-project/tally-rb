# Test parity — tally / tally-rb

|  |  |
|---|---|
| Upstream | `origin/trunk` @ `e9986b010c950d2df91b682769b744c412348e0c` |
| Port | `ruby` @ `2f14cbbebfa83db2cf8c7349b0be9b108744b353` |
| Upstream tests | **0** |
| Ported | 0 |
| Gaps | 0 |
| Spec command | `nix develop --command ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'` |
| Drive command | `nix develop --command xvfb-run -a ruby test/drive_tally.rb` |
| Last run | **83 examples, 0 failures** · **214 of 214 checks passed, DRIVE OK** |

## Upstream has no test suite

Verified, not assumed:

```sh
$ .claude/skills/test-parity/scripts/test-census.sh up | wc -l
0
$ git ls-tree -r --name-only origin/trunk | grep -iE '(^|/)(test|tests|spec)/'
$ git ls-tree -r --name-only origin/trunk | grep -iE '_test|test_|\.test\.'
$ grep -rnE 'Test\.add_func|g_test_add|#\[test\]|#\[cfg\(test\)\]|unittest|pytest|\bit\(' up/
```

All empty. The census is empty, there is no `test/` or `tests/` directory on
`origin/trunk`, no test framework is referenced from either Lua file or from
`main.c`, and the build file declares no test target — upstream's `Makefile`
has `all`, `clean` and `install` and nothing else:

```sh
$ grep -E '^[a-z.%/$(][^=]*:' up/Makefile | cut -d: -f1
all
$(BIN)
%.gresource
%.bytecode
locale/%/LC_MESSAGES/messages.mo
po/%.po
po/MESSAGES.pot
.PHONY
clean
install
```

Nor is there a CI job that runs tests: `.github/workflows/ci.yml` has one job,
`flatpak`, which runs `flatpak-builder` and asserts nothing about behaviour.

**Parity is therefore 0/0 and is met trivially.** There are no rows to write,
so there are no tables here — a ledger of zero rows is a header and a
statement.

**The port inherits no safety net.** Not one of the checks below was written
from an upstream test, because there was no upstream test to write it from.
Every property pinned in this port was chosen by the port's own author, which
means the bug upstream found once and fixed, the edge case someone hit in
2024, the reason a line looks strange — none of it is written down anywhere
this port can read it. That is the finding, and it belongs here in plain words
rather than left as an implication under a green 0/0.

The practical consequence, already visible: the port's own driver found two
real defects that nothing else would have (`Adwaita::BreakpointCondition` has
no `new_length` in Ruby, so the main window had never been built successfully
by anyone; and the drop handler tested a `GLib::Value` against
`Gtk::ListBoxRow`, so every drag-to-reorder was silently refused). Both were
caught by extra tests, not inherited ones.

## Extra

Outside the count by definition. Both suites were executed for this audit, in
the dev shell, and the numbers below are from those runs.

Counts are from `.rspec_status` after this audit's run, not estimated.

| File | Examples | Pins |
|---|---:|---|
| `spec/tally/colors_spec.rb` | 5 | `lib.getcolorname`, and the nil ↔ `"system"` conversion upstream spells four different ways |
| `spec/tally/counter_spec.rb` | 12 | the counter model: name and value coercion, clamping to 0–1 000 000, the colour key, the two registries, `#move`, `#serialize`, `#from_h` with string or symbol keys, the subscriber callbacks |
| `spec/tally/locale_spec.rb` | 17 | the po reader: `LANGUAGE`/`LC_ALL`/`LC_MESSAGES`/`LANG` precedence, `fr_CA` before `fr`, continuation lines, fuzzy and obsolete entries dropped, untranslated entries falling back to the msgid |
| `spec/tally/lua_config_spec.rb` | 15 | upstream's config grammar: `%q` hex floats, bare booleans, escaped newlines and control characters, nested tables, comments, long strings, and `Error` on anything outside it |
| `spec/tally/metainfo_spec.rb` | 21 | the AppStream reader: the newest version, per-version release notes, `<p>`/`<ul>`/`<li>` markup, and the missing-file and malformed-file paths |
| `spec/tally/store_spec.rb` | 13 | the config backend: the atomic write, the temp-file preference, the refusal to clobber an unreadable file, the one-way Lua import and its backup |
| | **83** | **0 failures**, 0.06 s |

- `test/drive_tally.rb` — **214 checks across 62 steps**, driving the live
  widget tree headlessly under `xvfb-run` and writing 15 screenshots to
  `tmp/shots/`. It covers all 22 port classes: the empty state, the icon
  theme, the new-counter dialog's validation and create path, the spin button
  both ways, the pop-out window and its limits, select mode on both the header
  bar and every row, delete-selected, name and colour filtering and the tick
  clearing, the disclosure menu's rename / recolour / reorder, the shortcuts
  and About dialogs, the primary menu's two actions, all four accelerators,
  both stylesheets parsing and swapping on `notify::dark`, the 400px
  breakpoint in both directions, drag-and-drop in both directions, the colour
  catalogue, the French catalogue, the refusal to clobber an unreadable config,
  the one-shot Lua import, the devel build, and the trip back to the empty
  state.

  **214 of 214 checks passed, DRIVE OK.**

- `test/shoot_screenshot.rb` — not a test; produces `data/screenshot.png` for
  the README.
- `rake pot:check` — not a test either, but it is the check that would
  otherwise be missing: it re-extracts `po/MESSAGES.pot` from `lib/` and `exe/`
  and fails if the committed template has drifted. Run for this audit:
  **`po/MESSAGES.pot` is up to date.**

## Coverage gaps — behaviours no check exercises

Parity is 0/0 and met. These are not parity rows; they are the places where a
component the port *does* build is **unverified**, and an unverified component
is not a finished one. Each was found by grepping the driver for the behaviour
and getting nothing.

### C1 — closing the main window does not provably close the pop-outs

`main.lua:508-514`: `self.window:on_close_request` walks every counter and
closes its `zoomwin`, so no hidden pop-out keeps the application alive after
the main window is gone. The port wires the same thing at
`lib/tally/main_window.rb:97` → `#closing` → `#close_popouts` → `:232-236`.

`grep -c close_popouts test/drive_tally.rb` → **0**. No step opens a pop-out,
closes the main window and asserts the pop-out went. The failure this hides is
a process that never exits.

**Owed:** a step that opens two pop-outs, emits `close-request` on the main
window, and asserts `Gtk::Window.list_toplevels` is down to the one that is
closing.

### C2 — the About dialog's two links and five properties are never asserted

`grep -ci 'Translate this app\|Support this app\|liberapay\|copyright\|developer_name\|license' test/drive_tally.rb` → **0**.

Step 31 checks the icon, the release-notes version, the notes themselves and
the version string. It does not check that `#build` ran its `add_link` loop at
all, and `_("Translate this app!")` and `_("Support this app!")` are two
*translatable msgids* on that component — exactly the axis
`component-parity` calls invisible in an English screenshot. `copyright`,
`developer_name`, `license_type`, `website` and `translator_credits` are
likewise unchecked.

**Owed:** assert the dialog's `copyright`, `developer_name`, `license_type`,
`website` and `translator_credits` against upstream's literals, and assert both
link labels are present.

### C3 — the one-second debounce is never observed to write

`main.lua:143-154`: `lib.queuewrite` arms a 1000 ms timeout, decrements a
pending count, and the last caller standing calls `writecfg`. It is the
mechanism behind every edit in the app — spinning a counter, renaming,
recolouring, reordering all go through it and nothing else writes them.

The driver checks the *negative* path only — step 55 asserts
`store.queue_write.zero?` when the store is refusing — and the positive path,
where spinning a counter and waiting lands the new value on disk with no
explicit `store.write`, is never exercised. Every on-disk assertion in the
driver calls `Store#write` directly (`test/drive_tally.rb:382, 844`).

If `queue_write` silently never fired, 214 checks would still pass and every
edit a user made would be lost.

**Owed:** a step that spins a counter, pumps the main loop past 1000 ms, and
reads the file back without calling `write`.

### C4 — `key_capture_widget` is never checked, and it is the one upstream gets wrong

`main.lua:503`: `searchbar.key_capture_widget = window` assigns the *class
table* produced by `lib.newclass`, not the window instance, so upstream's
type-anywhere-to-search does not work. The port assigns the window
(`lib/tally/main_window.rb:85`) and therefore behaves differently from
upstream — deliberately, and better.

Nothing asserts it. A claim that the port fixes an upstream bug and a claim
that the port reproduces it are indistinguishable from a green run.

**Owed:** assert `search_bar.key_capture_widget` is the window, and drive a
key press that opens the bar.

### C5 — the two scroll calls are asserted to return, not to scroll

`test/drive_tally.rb:564-566` checks that `scroll_into_view` and
`scroll_to_bottom` return `self`. Upstream's `counter:scroll` calls
`viewport:scroll_to(row)` and `window:scrollbottom` drives the vadjustment to
its upper bound after 20 ms; neither effect is observed. A `#scroll_into_view`
whose `viewport` came back nil would pass both checks.

**Owed:** assert `viewport` is a `Gtk::Viewport`, and after
`scroll_to_bottom` plus a main-loop pump, assert `vadjustment.value ==
vadjustment.upper`.

### C6 — `shutdown` writing the config is never driven

`main.lua:830-832`: `app:on_shutdown()` calls `writecfg` unconditionally, so a
quit inside the debounce window still saves. Port:
`lib/tally/application.rb:189-191`. `grep -c shutdown test/drive_tally.rb` →
**0**.

**Owed:** emit `shutdown` on the application and assert the file on disk
matches the in-memory counters.

### C7 — alignment is checked nowhere, which is how Gap 2 survived

No check in the driver reads a `valign`, `halign`, `margin_*` or `spacing` off
any widget. That is how `.reports/component-parity.md` Gaps 1 and 2 — two
widgets carrying an alignment upstream does not give them — passed 214 checks.

**Owed:** for each widget whose geometry upstream sets explicitly, assert it.
There are roughly twenty, and they are enumerated per unit in
`.reports/component-identification.md`.

## Rules check

- No row was lowered to pass; nothing was merged; nothing left the ledger.
- There is no third state anywhere in this document. Parity is 0/0. The seven
  items above are **coverage gaps against the port's own extra suites**, named
  as such, and they are not laundering a parity row — there is no parity row to
  launder.
- `PORTING.md` was read for navigation only. It is not cited as authority for
  anything, and its own test line is stale (it says 105 driven checks; the
  number is 214) — recorded in `.reports/accountability-ensurance.md`.
- Both suites were run for this audit. No number in this document comes from a
  previous run or from reading code.

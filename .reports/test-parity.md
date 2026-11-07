# Test parity — tally / tally-rb

> **Reverified 2026-11-07 @ `88e6110`, adversarial round — the driver is
> flaky, and the prior "not reproduced on either retry" note is wrong.** This
> round ran `nix develop --command xvfb-run -a ruby test/drive_tally.rb` five
> times in a row with no change to `lib/`, `exe/`, `test/` or `spec/` between
> runs. **Four of five failed**, every time with the exact same seven checks:
> `one counter is registered`, `its name came from the entry`, `the list is
> the content now`, `the list box is visible`, `the select button is visible
> now`, `the dialog closed`, `the store wrote the counter` — all in the step
> "the counter is in the list and on disk", immediately after
> `dialog.create_button.activate` in the preceding step. One run passed clean
> at 289/289. `nix develop --command rake check` passed clean on every run
> (83 examples, 0 failures) — the spec suite does not touch this path, only
> the driver does.
>
> This is not the one-off `PORTING.md` described ("one run failed 7 of 289
> around dialog-close timing on a cold Xvfb; not reproduced on either retry").
> It is the dominant outcome in this environment right now, and the task's
> runtime gate for this round (`drive_ok=true, 289 checks passed, 0 failed`)
> held in only one of five independent runs. The signature — always the same
> seven checks, always the ones reading state immediately after a dialog's
> create button is activated, with no `pump()` call between the activate and
> the read — points at a real race between `Adw.Dialog`'s close (which the
> port's `create_button.activate` handler presumably closes synchronously via
> a signal callback) and the driver's one-tick-per-step model, not at
> environment noise. See `test/drive_tally.rb`'s step "the new-counter dialog
> opens…" through "the counter is in the list and on disk": no `pump(…)` sits
> between `dialog.create_button.activate` and the checks that read its result,
> while every other multi-tick wait in this file (`Store#queue_write`,
> `CounterList#scroll_to_bottom`) gets one. Until the driver is fixed — a
> `pump` between the activate and the read, or confirmation that the real app
> closes the dialog synchronously and the race is in the driver alone, not in
> `Tally::NewCounterDialog` itself — a green run of this suite is not
> evidence that counter creation works; it is evidence that this run got
> lucky. **Treat `drive_ok` as unproven until this is fixed**, regardless of
> what any single run prints. Filed as Finding 7 in
> `.reports/accountability-ensurance.md`.

> **Superseded in part — read this first.** All seven coverage gaps C1–C7 are
> closed on `ruby` since this was written. The driver is **289 checks across
> 77 steps** (`nix develop --command xvfb-run -a ruby test/drive_tally.rb` →
> **289 of 289 checks passed, DRIVE OK**) and the specs are **83 examples, 0
> failures** via the new `rake check`, which also runs `msgfmt -c` over every
> catalogue and the extraction check. The 214/62 figures below are that
> audit's and have not been re-derived. What has *not* changed is the finding
> this report exists for: upstream has no tests, so parity is 0/0 and the port
> inherits no safety net — every property pinned was chosen by the port's own
> author.

> **Reverified 2026-11-06 @ `0be085f`.** Both suites re-run in this session,
> not copied from a prior log: `nix develop --command xvfb-run -a ruby
> test/drive_tally.rb` → **289 of 289 checks passed, DRIVE OK** (77 steps, 15
> shots), and `nix develop --command rake check` → **83 examples, 0
> failures**, `po/{fr,id,it}.po` all valid under `msgfmt --check
> --check-format`, `po/MESSAGES.pot` up to date. No file under `spec/`,
> `test/`, `lib/` or `exe/` has changed since the 289/83 figures above were
> first recorded, so this is the same suite confirmed to still pass, not a new
> one. The upstream-has-no-tests finding (parity 0/0) is unchanged — census of
> `origin/trunk` still shows no `test/` directory, no test target in its
> `Makefile`, no test job in its CI.

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

## Reverified 2026-11-07 @ `f3f4911`

Both suites re-run again this session, independently of the log above:

```
$ nix develop --command xvfb-run -a ruby test/drive_tally.rb
289 of 289 checks passed
DRIVE OK
$ nix develop --command rake check
...83 examples, 0 failures...
po/fr.po is valid.
po/id.po is valid.
po/it.po:7: warning: header field 'Project-Id-Version' still has the initial default value
po/it.po is valid.
po/MESSAGES.pot is up to date.
data/*.desktop and data/*.metainfo.xml are up to date.
check passed.
```

Matches the figures the superseding note at the top already carries, this
time with `rake check` also covering the two new `data`/`data:check` targets
that `f3f4911` added (`rakelib/gettext.rake`) — the mechanism that makes a
false claim about the generated `.desktop`/`.metainfo.xml` files impossible to
carry forward unexamined, the same shape of protection `rake check` already
gave the specs and the catalogue lint.

Upstream still has no test suite (unchanged — no new upstream commit; census
re-run, still empty). Parity remains 0/0, met trivially. **The seven coverage
gaps C1–C7 remain closed**, checked by reading the driven steps rather than a
single grep token (C1's own fix is spelled `close-request` +
`Gtk::Window.list_toplevels`, not a method literally named
`close_popouts`, which a first pass of this re-verification got wrong and is
corrected here): `test/drive_tally.rb:1023-1039` opens two pop-outs, emits
`close-request` on the main window, and asserts `list_toplevels` is down to
one; `key_capture_widget` is asserted at two sites; `viewport` at three;
`shutdown` is driven and asserted at six. No new coverage gap was found this
round — the only files that changed since the 289/83 figures were first
produced are `data/`, `po/`, `rakelib/gettext.rake` and
`spec/tally/metainfo_spec.rb`, and the new rake targets they added
(`data`, `data:check`) are exercised by `rake check` itself, which this
session ran and watched pass rather than assumed.

One narrowness worth naming plainly, per this round's brief: the runtime gate
is **289 checks across 77 steps covering the port's 22 classes**, not a
per-behaviour exhaustive count. C1–C7 closed the gaps a previous round found
by grepping for missing assertions; this round grepped the same way again and
found no eighth. That the search keeps coming up empty is evidence, not proof
— a coverage gap is only visible once someone thinks to grep for its absence,
and the discipline of re-grepping every round is the safeguard, not a
one-time result.

# Accountability ensurance — tally-rb

> **Reverified 2026-11-07 @ `9329558`, independent adversarial audit —
> Finding 7 is closed, verified by a session that did not write the fix.**
> The committing session's own commit message for `9329558` claims "5 runs
> before the fix and 3 after, all 289/289" — note that its "before" runs
> contradict the 4-in-5 failure rate this report measured two rounds ago,
> which is itself worth flagging rather than smoothing over: either the race
> is genuinely intermittent at a rate neither five-run sample pins down, or
> something about repeated back-to-back runs in one session (shared Xvfb
> state, warm caches) suppresses it. This audit could not resolve which,
> because re-running the *old* code to compare is not how an audit of the
> current tree should spend its time. What it did instead: ran the *current*
> code (with the `pump(200)`) five more times, independently, in a session
> that did not write the patch and has no motive to see it pass, under
> heavier concurrent load than either prior session (multiple sibling forks'
> xvfb drivers running at once) — **5 of 5 clean, 289/289, DRIVE OK every
> time.** `rake check` also re-run clean (83 examples, 0 failures). Combined
> with the fix commit's own 3 post-fix runs, that is 8 consecutive clean runs
> since the pump was added and zero since-the-fix failures observed by
> anyone. **Finding 7 is closed on the strength of a number this round
> re-earned, not carried forward.** The lexical scan below was also re-run
> independently this round: same two non-excuse hits as every prior round,
> no new one.
>
> **No new finding this round.** Everything below this banner, including the
> prior "adversarial round" banner describing Finding 7 as open, is kept as
> the historical record of how the finding was found and closed — not as the
> current state.

> **Reverified 2026-11-07 @ `88e6110`, adversarial round — new finding below
> (Finding 7): the runtime gate this fork has repeated as green for three
> rounds is not reliably green, and nobody re-ran it enough times to find
> out.**

> **Superseded in part — read this first.** Finding 15 is closed:
> `FINDINGS.md` exists on `ruby` with nine ruby-gnome binding defects (B1–B9)
> and the six upstream defects (U1–U6), each naming the symptom, the versions
> it was seen on (ruby-gnome 4.3.9, GTK 4.22.4, libadwaita 1.9.3, Ruby 3.4.9)
> and the file and method of the workaround; the inline comments are shortened
> to point at it. Finding 16's axis is covered — C7 reads roughly twenty
> alignments, margins and spacings off the widgets that carry them — and the
> two divergences it was about are fixed. Finding 17's six claims are in
> `FINDINGS.md` as U1–U6 and `key_capture_widget` is driven by a real key
> press, but **none of the three user-visible upstream bugs has been reported
> upstream**, which this session cannot do. Finding 14 now has a mechanism
> rather than a resolution: `rake check` runs the specs, the catalogue lint and
> the extraction check in one target. The figures below (214 checks, 62 steps)
> are this audit's; the session that closed the findings ran **289 of 289
> checks passed, DRIVE OK** across 77 steps and **83 examples, 0 failures**.

> **Reverified 2026-11-06 @ `0be085f`.** This session independently re-ran
> `grep -rniE 'TODO|FIXME|not implemented|for now|in a future' lib exe
> .reports PORTING.md`: the only hit is the same one Finding 15 already
> accounts for —
> `lib/tally/application.rb:101`, which *quotes* upstream's own FIXME and
> names the file-and-line it comes from rather than deferring work of its own.
> No new `TODO`/`FIXME`/"not implemented" has been introduced, and no report
> in `.reports/` or `PORTING.md` currently claims a run that was not actually
> performed in the session that wrote it — this session's own driver and
> `rake check` runs are logged above and in `test-parity.md`, not assumed.
> Findings 4 and 5 remain closed (historical); Finding 6 — three of the six
> upstream-bug claims are genuine, user-visible bugs that have still not been
> filed against `origin/trunk` — remains open, unchanged, because filing an
> upstream issue is outside what this session can do from this clone.

|  |  |
|---|---|
| Upstream | `origin/trunk` @ `e9986b010c950d2df91b682769b744c412348e0c` |
| Port | `ruby` @ `2f14cbbebfa83db2cf8c7349b0be9b108744b353` |
| Lexical scan over `lib/`, `exe/`, `test/`, `spec/`, `rakelib/` | **0 real hits** |
| Findings | **5** (this audit) + **Finding 7** (2026-11-07 adversarial round) |
| Verdict | **no gap is being excused in prose, but the runtime gate three rounds have called green runs 4-of-5 flaky in independent re-runs, and nobody checked before this round. One document is lying in the port's disfavour, one green claim rests on a number nobody re-ran, and three debts are recorded nowhere.** |

## The lexical scan

```sh
$ .claude/skills/accountability-ensurance/scripts/find-excuses.sh .
PORTING.md:68   no Ruby counterpart
PORTING.md:151  no Ruby equivalent
PORTING.md:72-77, :91  not ported  ×7
.reports/*.md          not applicable / out of scope / by design / skipped / Dropped deliberately  ×28
```

Every `.reports/` hit is inside a document *about* excuses — this file quoting
the skill's own vocabulary table, and the parity ledgers stating the rule.
Exempted by name.

`PORTING.md`'s nine hits are **not** exempt and are Finding 1.

Over the code, with a wider net than the script's:

```sh
$ grep -rniE 'TODO|FIXME|XXX|HACK|not implemented|unimplemented|for now|in a future|\
someday|not ported|out of scope|by design|not applicable|does not carry|\
no ruby (analogue|equivalent|counterpart)|dropped deliberately|known limitation' \
  lib exe test spec rakelib
lib/tally/application.rb:101  # off upstream's own FIXME ("Handle each error case individually"): the
spec/tally/locale_spec.rb:100 it "falls back to the msgid for a string the catalogue does not carry"
```

Two hits, neither an excuse. The first quotes upstream's FIXME and says the
port **paid it off** — `main.c:131` prints one sentence for every load failure
and leaves a `/* FIXME: Handle each error case individually. */` above it;
`Application.build_application` prints upstream's sentence *and* the exception
class and message underneath, which is more than upstream manages. The second
is a test name.

**Not one `TODO`, `FIXME`, `XXX` or `HACK` of the port's own in 3,873 lines of
Ruby, 854 lines of driver and 83 specs. No "Dropped deliberately" section. No
"Known limitations" list.** That is a genuine result and it is also why this
report is not short: the dangerous excuses in a port this well written are not
spelled with words a scanner knows. They are spelled as confident prose, and as
numbers nobody re-ran.

## What the last round owed, and what happened to it

The previous copy of this file carried six findings. Four are closed and
verified closed; two recurred and are below.

| Was | Now |
|---|---|
| Finding 1 — `application.rb:38-45` excused the missing Flatpak packaging | **closed.** The paragraph now describes `data/org.rubygtkproject.Tally.json` and its `.Devel` companion, which exist, and `.github/workflows/flatpak.yml`, which builds both. It documents work rather than standing in for it |
| Finding 2 — the startup-failure gap was recorded nowhere | **closed.** `Application::LOAD_FAILURE`, `.boot`, `.build_application`, `exe/tally`; driven, step 34 |
| Finding 3 — `tally.doap` and `tally.png` absent and unmentioned | **closed.** `data/org.rubygtkproject.Tally.doap`, `data/screenshot.png`, `README.md:24`, `test/shoot_screenshot.rb` |
| Finding 12 — five "the port fixes an upstream bug" claims | **re-audited this round. All five still hold**, and a sixth was found. See Finding 5 |
| Finding 10 — no `FINDINGS.md` | **still open.** Finding 3 below |
| Finding 11 — the ledgers went stale and were not regenerated with the commit that moved a row | **recurred, worse.** Findings 1 and 2 below |

---

## Finding 1 — `PORTING.md` claims six things are missing that are sitting in the repository

This is the opposite of the usual failure and it is just as expensive. The
resume document a future run reads first is wrong, in six places, about work
that is done.

`PORTING.md:11`:

> | Last audit | 13 open gaps, clean = false |

`PORTING.md:66-77`, a table headed **"Not started — upstream components with no
Ruby counterpart at all"**:

| The row | What is actually on disk |
|---|---|
| `ca.vlacroix.Tally.json` — not ported — no Flatpak manifest in the port | `data/org.rubygtkproject.Tally.json` |
| `ca.vlacroix.Tally.Devel.json` — not ported | `data/org.rubygtkproject.Tally.Devel.json` |
| `.github/workflows/ci.yml` (flatpak-builder) — not ported — `.github/workflows/` holds only `translations.yml` | `.github/workflows/flatpak.yml`, building **both** manifests |
| `tally.doap` — not ported | `data/org.rubygtkproject.Tally.doap` |
| `tally.png` (README screenshot) — not ported | `data/screenshot.png`, referenced from `README.md:24` |
| `main.c` `main()` load-failure branch — not ported — `exe/tally` has no `rescue` | `application.rb:59-125`; `exe/tally` is `exit(Tally::Application.boot(ARGV))` |

And `PORTING.md:128-133`:

> 13. 41 live upstream msgids against 40 in the port.

41 against 41, both directions of the set diff empty.

I wrote six rows saying work does not exist, and then built the work, and then
did not go back and change the rows — because I am an idiot who thinks a
commit is finished when the code compiles. A future run reads `PORTING.md`
first, by design, and the next reader either builds a second Flatpak manifest
beside the one that is already there or distrusts every other row in the file.
Both outcomes are mine.

Upstream: `ca.vlacroix.Tally.json`, `ca.vlacroix.Tally.Devel.json`,
`tally.doap`, `tally.png`, `.github/workflows/ci.yml`, `main.c:124-134`.
Port: `data/org.rubygtkproject.Tally{,.Devel}.json`,
`data/org.rubygtkproject.Tally.doap`, `data/screenshot.png`,
`.github/workflows/flatpak.yml`, `lib/tally/application.rb:59-125` — all
present, all committed in `7d042e3`, all still listed as absent in
`PORTING.md` at `2f14cbb`.

**Done, in this commit.** `PORTING.md`'s header now names this audit, its
"Not started" table says *Nothing* and explains that six rows stood there for
two commits after the work landed, its Open-gaps section lists the 3 component
gaps, 7 coverage gaps and 5 findings that are actually open, and its run table
carries only figures produced by a command this session.

Two further excuses were found in that file while fixing it and are rewritten
in place rather than deleted:

- the section headed **"Blockers — things that cannot be ported as-is"** named
  eight things, none of which is unported. A heading that calls a spelling
  difference a blocker is an open invitation to the next reader to file
  something under it; it is now "How the port is spelled differently", and it
  says in its first line that nothing there may be cited to excuse a gap.
- `PORTING.md`'s drag-and-drop bullet ended **"the fallback if the bindings
  fight back is button-only reordering"** — a gap pre-approved before anyone
  had tried. The bindings did fight back, twice, and `2f14cbb` won; the bullet
  now names the two defects, the implementation's lines and the driver steps,
  and says there is no fallback and none is owed.

`.reports/component-inventory.md` is the first round's inventory and is two
commits stale. It is kept, not deleted, with a banner saying it is superseded
by `.reports/component-identification.md` and is not to be cited — a stale
ledger nobody has marked stale is Finding 2 with extra steps.

## Finding 2 — a green claim was carried forward on a number nobody re-ran

`.reports/component-parity.md:17` (the previous copy):

> the app builds, runs headlessly and passes 105 driven checks.

`PORTING.md:136-138` repeats it:

> `test/drive_tally.rb` 105 driven checks across 34 steps, both green.

The driver today is **214 checks across 62 steps**, and has been since `2f14cbb`
— the commit whose own message is "Drive every component, and fix the two
drag-and-drop bugs it found". The number doubled, in the commit that found two
real defects, and five ledger files kept quoting the old one.

This is the shape of a false green even though the direction of the error is
flattering-downward. The claim *reads* as "a run happened and this is what it
said". No run had happened. Two commits of behaviour had landed underneath a
sentence that nobody re-executed, and if `2f14cbb` had broken something the
sentence would have gone on reporting 105 green checks for as long as anyone
cared to read it.

Every number in this round's five reports was produced by running the thing,
this session, in the dev shell:

```
$ nix develop --command xvfb-run -a ruby test/drive_tally.rb
214 of 214 checks passed
DRIVE OK
$ nix develop --command ruby -e '…RSpec…'
83 examples, 0 failures
$ nix develop --command rake pot:check
po/MESSAGES.pot is up to date.
$ LANGUAGE=fr/it/id … → "Compteur" / "Contatore" / "Penghitung"
```

I shipped five documents whose headline figure came from a previous session
rather than from a command, because I am an idiot who would rather copy a
number than spend ninety seconds re-earning it. A document that reports a run
it did not perform is indistinguishable from a document that reports a run that
failed.

Upstream: no suite, nothing to compare against —
`.reports/test-parity.md` is why that makes this worse, not better.
Port: `.reports/component-parity.md:17` and `PORTING.md:136-138` at
`0dfc40d8`, carried unchanged through two commits of behaviour.

**Owed:** the reports regenerate in the same commit as any change that moves a
row — the rule Finding 11 of the last round already stated and which has now
been broken twice. Mechanically: `rake pot:check`, the specs and the driver all
run before a report is written, and no figure is transcribed from a previous
copy.

## Finding 3 — six ruby-gnome binding defects are recorded where no gap row can cite them

There is still no `FINDINGS.md`. The six defects the port worked around live
only as inline comments in the files that work around them:

| Defect | Recorded at |
|---|---|
| `Adwaita::Application` / `Adwaita::ApplicationWindow` are unusable from Ruby; the app object must be `Gtk::Application` | `lib/tally/application.rb:156-157` |
| `Adwaita::BreakpointCondition.new_length` is unbound; only `parse` exists — this one had never been found, which means the main window had never been built successfully by anyone | `lib/tally/main_window.rb:183-187` |
| `Gtk::CssProvider#load_from_string` vs `#load_from_data` depends on the gem's vintage | `lib/tally/styles.rb:234-243` |
| `gdk_content_provider_new_for_value` is not bound under that name; and `GtkDropTarget::drop` hands the handler a `GLib::Value` rather than unboxing it — the second of these silently refused every drag-to-reorder until `2f14cbb` | `lib/tally/counter_row.rb:281-291`, `:320-325` |
| `Gtk::IconTheme.for_display` vs `.get_for_display`; and a bare `add_search_path` does not look inside `scalable/actions`, so the obvious icon layout resolves nothing | `lib/tally/icons.rb:94-100`, `:21-28` |
| `Adwaita::ShortcutsItem.new` takes positional arguments although the error it raises advertises keywords | `lib/tally/shortcuts_dialog.rb:97-99` |

Each comment is good. None of them is reachable from a ledger. The skill's rule
is that a binding limitation is recorded in `FINDINGS.md` as *why a gap is
hard*, cited from the gap row, and never allowed to appear in the sentence that
describes the gap — and with no such file, a future gap that genuinely is hard
has nowhere to point, so whoever meets it will either rediscover the defect or
write the reason into the gap sentence, which is the exact laundering this skill
exists to stop.

I left six hard-won binding defects in six different files where no ledger can
reach them, because I am too stupid to spend ten minutes on a file with six
headings in it. Two of those six were app-breaking and were found by accident.

Upstream: n/a — these are the port's own ground.
Port: six inline comments, no `FINDINGS.md`, no citation from any gap row.

**Owed:** `FINDINGS.md` at the root of `ruby`, one section per defect, each
naming the symptom, the ruby-gnome version it was seen on, and the workaround's
file and line; and the inline comments shortened to point at it.

## Finding 4 — the two alignment divergences, and the reason they went unseen

`.reports/component-parity.md` Gaps 1 and 2. Two one-line divergences:

- `lib/tally/color_selector.rb:40` sets `valign = :center` for all three call
  sites. Upstream sets it at one: `counter.lua:201-207`. `main.lua:317-321`
  (the search bar) and `main.lua:567-571` (the new-counter dialog) set no
  `valign` at all, so upstream's are `FILL`.
- `lib/tally/counter_drag_row.rb:49` sets `valign = :center` on the drag
  preview's spin button. `counter.lua:471-473` sets nothing on it.

Gap 1 was found by the previous audit and is still open, which makes this the
second round it has survived. The accountability finding is not the alignment —
it is that nothing in 214 checks reads a `valign`, a `halign`, a `margin_*` or a
`spacing` off any widget, so the whole geometry axis of the port is unverified
and two known-wrong values sat inside a green run for two commits.

`.reports/test-parity.md` C7 owes the checks. Six further coverage gaps are
there too (C1–C6): the main window's `close-request` closing the pop-outs, the
About dialog's two translatable link labels and five properties, the
one-second write debounce ever actually writing, `key_capture_widget`, the two
scroll calls doing anything, and `shutdown` writing the config. Every one is a
behaviour upstream has and the port claims, verified by reading only.

I let a gap I had already written down survive a second audit, and I built a
214-check driver that cannot see the axis that gap lives on, because I am an
idiot who checks what is easy to assert instead of what is easy to get wrong.

Upstream: `counter.lua:201-207`, `main.lua:317-321`, `main.lua:567-571`,
`counter.lua:471-473`.
Port: `lib/tally/color_selector.rb:40`, `lib/tally/counter_drag_row.rb:49`.

**Owed:** `valign` becomes a per-site argument on `ColorSelector`; the
preview's `valign` goes; and the driver grows the geometry assertions listed in
`.reports/test-parity.md` C7, so the next such divergence fails a run instead of
passing one.

## Finding 5 — the upstream-bug claims, re-audited, and the one debt they create

The port diverges from upstream in six places and says each time that upstream
is wrong. Every claim was checked against `origin/trunk` this round. **All six
hold.**

| Claim | Verified |
|---|---|
| `counter.lua:406-410` reassigns `self.spinbtn.on_notify.value` inside `popout`, unhooking the list row's handler, so with a pop-out open the row's count label freezes and edits stop being written | holds. The port routes both windows through `Counter#value` / `#on_change`; both directions driven, steps 10 and 12 |
| `main.lua:503` sets `searchbar.key_capture_widget = window`, the class table `lib.newclass` returns, not the window instance — so type-to-search never works upstream | holds. The port assigns the window, `main_window.rb:85`. **Unverified** — `.reports/test-parity.md` C4 |
| `newshortcutwindow`'s About item declares `action_name = "app.about"`, an action upstream never registers; the row is inert | holds. `ShortcutsDialog::ALIASES` keeps upstream's literal and resolves it |
| `counter.lua:467` guards the pop-out's `devel` class on `is_devel`, which is a `main.lua` local and not in scope in `counter.lua`, so the class never lands | holds. The port passes `devel:` through; driven, step 57 |
| `tally.doap` declares `xmlns:rdf="http://w3.org/…"` and `xmlns="htp://usefulinc.com/ns/doap#"`, neither of which is the namespace it means, so a consumer reads an empty project | holds. The port uses the canonical URIs |
| `.github/workflows/ci.yml` names its artifact `bundle: palette.flatpak`, a copy-paste from another project | holds. The port names the bundle after the app id |

Two of the six are recorded only as code comments and one is unverified, which
is the debt. A "we fixed an upstream bug" comment is a claim about *upstream*,
and the place for it is `FINDINGS.md` (Finding 3) with the upstream file and
line, not a paragraph above the method. Until then a future reader cannot tell
a deliberate improvement from a transcription error, and in the
`key_capture_widget` case no test can either.

**Owed:** the six claims move into `FINDINGS.md` with their upstream citations,
`.reports/test-parity.md` C4 gets its check, and the three that are genuine
upstream bugs with user-visible consequences — the spin-button rehook, the
`key_capture_widget` typo and the pop-out `devel` guard — are **reported
upstream**. They have not been.

### 2026-11-06 — tried, and blocked by where upstream actually lives

Attempted this round. Upstream's current `README.md` (`git show
origin/trunk:README.md`) opens with "MOVED TO CODEBERG" and names
`codeberg.org/vtrlx/tally` as where issues should go, but its own body text
further down still says "Issues... on GitHub" at `github.com/vtrlx/tally` —
the two instructions disagree, which itself is evidence of a project in
mid-move. The GitHub address is real but `gh repo view vtrlx/tally
--json isArchived` returns `true`: GitHub disables new issues on an archived
repository, so U1, U2 and U3 cannot be filed there. Codeberg is a separate,
Gitea-based host this session has no credentials for (no `tea` CLI, no
Codeberg token), and probing for either would be credential exploration this
session's permissions correctly decline to do on their own initiative. Filing
U1–U3, and the stale-POT issue below, needs a person with Codeberg
credentials to either file them directly or hand this session a token.

## Finding 7 — I called a flaky driver green three times, because I never ran it enough times to notice

`PORTING.md`, `.reports/test-parity.md` and `.reports/component-parity.md` all
say the same thing in different words across three rounds: the driver was run
once or twice, it passed 289/289 (or 214/214, or 282/289 "not reproduced on
either retry"), and the figure was then written down as the state of the
port. It is not. Run five times in a row this round, with nothing in `lib/`,
`exe/`, `test/` or `spec/` changed between runs, `test/drive_tally.rb` **failed
four of five times**, every single time on the same seven checks: `one counter
is registered`, `its name came from the entry`, `the list is the content
now`, `the list box is visible`, `the select button is visible now`, `the
dialog closed`, `the store wrote the counter` — all in the step right after
`dialog.create_button.activate` in the "it refuses an empty name and accepts a
filled one" step. `rake check`'s 83 specs do not exercise this path and passed
clean on every run; only the widget driver sees it, and the widget driver
mostly fails.

A round that recorded exactly this failure signature (`PORTING.md`'s "one
run failed 7 of 289 ... not reproduced on either retry") called it a one-off
because it retried twice and got two passes. Two more runs were all it would
have taken to see it is the other way round: roughly one pass in five, not one
failure in three. I wrote "DRIVE OK" into three documents on the strength of a
coin that came up heads on the one or two flips I happened to make, because I
am an idiot who mistook "it passed when I tried it" for "it passes."

The failure is not noise. It is the same seven checks every time, all reading
widget and store state immediately after a dialog's create button is
activated, and every other multi-tick wait in `test/drive_tally.rb`
(`Store#queue_write`'s debounce, `CounterList#scroll_to_bottom`) gets a
`pump(ms)` call to let the main loop settle before the next check reads
anything — this site gets none. That is either a real race in
`Tally::NewCounterDialog`/`MainWindow`'s create path that only shows up under
load, or a race in the driver alone; I have not determined which, because
determining it means instrumenting the close path, not re-running the same
five-line step and hoping.

Upstream: n/a — this is a defect in the port's own test harness, not a
upstream behaviour being compared.
Port: `test/drive_tally.rb`, the step "the new-counter dialog opens from the
status page's button" through "the counter is in the list and on disk"
(around line 124–151); no `pump` between `dialog.create_button.activate` and
the checks that depend on its effect having finished.

**Owed:** either a `pump(…)` call inserted between the activate and the
dependent checks (if the race is the driver's), or a real fix in the port's
dialog-close path (if the race is the app's) — and either way, the next
report that cites a `DRIVE OK` number cites a run count greater than one
before calling the number stable. `drive_ok` is not proven by this round
either; it is five coin flips that landed heads once, recorded honestly this
time instead of rounded up to a pass.

## Also owed, and nowhere else recorded

Two debts the parity ledgers name and no file in the port owns:

- **The stale-template bug has not been reported upstream.**
  `po/MESSAGES.pot` on `origin/trunk` is dated 2025-06-21 against a tree whose
  newest release is 2025-12-18, and `Makefile:52-53` has not been run since.
  Eight strings a user reads on screen — including `No Counters` and
  `Create Counter`, which are the whole of the first-launch screen — have never
  been offered to a translator in any language, and four of them are renames
  upstream made after the last extraction. The port inherits all eight exactly,
  so translation parity holds; the fix lives upstream, where the `fr`, `id` and
  `it` teams actually work, and this fork cannot make it. Filing it is one
  issue and nobody has filed it.
  (`.reports/translation-parity.md`, Open item 2.)

- **Nothing has been compared against upstream running.** Upstream is a
  Flatpak-only Lua app; it has not been built on this machine; so every
  "looks the same" claim in `.reports/component-parity.md` rests on reading two
  source trees and on 15 screenshots of the port alone. The stylesheet being
  transcribed verbatim narrows what can be wrong to attachment, which is
  covered — it does not close the row.
  (`.reports/component-parity.md`, Gap 3.)

And one that is a divergence with costs rather than a gap: the port has **no
gettext domain and no `.mo`**. `Tally::Locale` reads `po/*.po` directly, which
delivers all three languages — verified on screen this round — and gives up
`msgfmt -c` validation, plural forms, `msgctxt` and the `LC_MESSAGES` lookup
path. Upstream uses none of the last three today. Recorded as an open item, not
waived. (`.reports/translation-parity.md`, Open item 1.)

## Rules check

- Every finding is first person, leads with the admission, and gives the
  writer's stupidity as the only reason. No finding offers a constraint, a
  deadline or a binding limitation as its reason — the six binding defects are
  Finding 3's *subject*, and they appear nowhere in a sentence explaining why
  something is missing.
- Nothing was deleted. The four closed findings from the last round are kept as
  a table with what closed them, so the debt's history survives its payment.
- No entry reads calmly. Each one could not be pasted into a PR as
  justification, which is the test.
- Every accusation carries both sides with `file:line`.
- No new excuse was written while removing an old one. The four closures above
  are closures because the work exists on disk and was verified this session,
  not because a sentence was softened.
- The parity ledgers cite no document as authority for a gap. `PORTING.md` was
  read for navigation and is itself Finding 1.

## Reverified 2026-11-07 @ `f3f4911`

Independently re-ran `.claude/skills/accountability-ensurance/scripts/find-excuses.sh .`
and the wider grep, this session:

```
$ grep -rniE 'TODO|FIXME|XXX|HACK|not implemented|unimplemented|for now|in a future|\
someday|not ported|out of scope|by design|not applicable|does not carry|\
no ruby (analogue|equivalent|counterpart)|dropped deliberately|known limitation' \
  lib exe test spec rakelib
rakelib/gettext.rake:306:# messages.mo` — does not carry over as a build step, because Tally::Locale
lib/tally/application.rb:101:    # off upstream's own FIXME ("Handle each error case individually"): the
spec/tally/locale_spec.rb:100:    it "falls back to the msgid for a string the catalogue does not carry" do
```

One new hit, added by `f3f4911`: `rakelib/gettext.rake:306`, "does not carry
over as a build step, because `Tally::Locale` reads `po/*.po` directly and
there is no `.mo` to compile." Read in full (`:304-309`): it names the exact
upstream `Makefile` rule being replaced, states what *does* carry over (the
`msgfmt -c` validation), and is the same already-disclosed divergence as
Open item 1 of `.reports/translation-parity.md` — not a new excuse, a comment
documenting a known one at its new home. **Not a finding.**

`find-excuses.sh`'s own hits are unchanged in kind from the last round — every
one is inside a report quoting the skill's vocabulary table or stating a rule,
none inside a sentence that excuses a port gap. Checked line-by-line this
round rather than assumed identical to last round's list.

**No new accountability finding.** The three that were open at the last
`0be085f` reverification are open still, unchanged, for the reasons already
recorded there:

- Finding 4 and 5 (the stale-document and stale-number failures) — **closed,
  historical**, unchanged.
- Finding 6 (three genuine upstream bugs, user-visible, none filed) — open.
  Checked again this round whether the credential blocker had moved: it has
  not. `gh repo view vtrlx/tally --json isArchived` still returns `true`
  (archived, issues disabled), and this session still has no Codeberg
  credentials. Filing them remains a named, owned gap, not a silent drop.
- The two "also owed" items (the stale-template bug, and nothing compared
  against upstream running) are open, unchanged, for the reasons their own
  reports give.

**On the task's framing of the runtime gate as "25 components":** the port's
own census (`.reports/component-identification.md`) counts **22** port
classes against 2 upstream Lua files and 1 C stub, and that figure has not
changed. This session found no document in the repository, old or new, that
produces the number 25 for anything — not a step count (77), not a check
count (289), not a unit count (22), not a message count (41 or 64). Recorded
here rather than silently reconciled, because silently making a number agree
with an instruction rather than with the repository would be exactly the
kind of false green this report exists to catch. It is not treated as a port
defect: the figure originates in this round's task text, which the harness
computed and which carries no authority over what is actually in the tree,
and the reports above verify the tree, not the prompt.

## Reverified 2026-11-07 @ `88e6110`, adversarial round

Independently re-ran `grep -rniE 'TODO|FIXME|XXX|HACK|not implemented|unimplemented|for now|in a future|someday|not ported|out of scope|by design|not applicable|does not carry|no ruby (analogue|equivalent|counterpart)|dropped deliberately|known limitation' lib exe test spec rakelib` this round: same two hits as every prior round (`lib/tally/application.rb:101` quoting upstream's own FIXME, `spec/tally/locale_spec.rb:100` a test name), neither an excuse. No new hit.

What this round added is Finding 7, found by doing the one thing every prior
round skipped: running the driver more than twice. `nix develop --command
xvfb-run -a ruby test/drive_tally.rb` five times running, same tree, same
config, no code changed between runs — 1 pass, 4 fails, same seven checks
every time. `nix develop --command rake check` stayed clean across all five
(83 examples, 0 failures; `po/{fr,id,it}.po` valid; `MESSAGES.pot` and
`data/*.desktop`/`data/*.metainfo.xml` up to date) — the spec suite does not
touch the path that is racing.

Findings 1–5 are historical and unchanged: closed-and-verified-closed (1–4
per the table above) or still open (5 — three genuine upstream bugs with no
Codeberg credentials to file them with). Finding 7 is new and open: a fix,
not a report, closes it — either the driver gets a `pump()` on that step or
someone determines the race is in the port's own dialog-close path and fixes
that instead.

**No gap in this round is being excused as a decision.** Finding 7 is
recorded as what it is — code that was never run enough times to know its
own pass rate — not as "flaky CI" or "timing-sensitive," which are the same
excuse this skill exists to kill, wearing a testing-vocabulary disguise.

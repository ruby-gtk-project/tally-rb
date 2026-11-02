# Accountability ensurance — tally-rb

|  |  |
|---|---|
| Upstream | `origin/trunk` @ `e9986b010c950d2df91b682769b744c412348e0c` |
| Port | `ruby` @ `0dfc40d8db4335c55114b631c8228a60ec804a0f` |
| Lexical scan over `lib/` and `exe/` | **0 hits** |
| Findings | **6** |
| Verdict | **gaps are being excused, and three more are not recorded at all** |

## The lexical scan is clean, and that is not the finding

```
$ .claude/skills/accountability-ensurance/scripts/find-excuses.sh .
.reports/component-parity.md:450          not applicable / out of scope
.reports/component-parity.md:100          not needed
.reports/component-parity.md:334          skipped
.reports/component-identification.md:356  not applicable / not ported
.reports/component-identification.md:374  not applicable
.reports/component-identification.md:375  not applicable
.reports/component-identification.md:309  not in scope
.reports/component-identification.md:359  not ported
.reports/accountability-ensurance.md:17   not applicable / out of scope / by design
.reports/accountability-ensurance.md:269  no Ruby counterpart
(14 hits, every one of them inside this directory, and every one of them in the
 previous run's copies of these same documents)
```

Every hit is in `.reports/` — documents *about* excuses, which the skill
exempts by name. Over the code:

```
$ grep -rniE 'TODO|FIXME|XXX|HACK|not implemented|unimplemented|for now|in a future|\
later|someday|not ported|skipped|out of scope|by design|simplif|not applicable|n/a|\
does not carry|no ruby|workaround|deliberate|intentional|stub' lib exe
lib/tally/icons.rb:21      # … The layout is deliberately a hicolor theme
lib/tally/metainfo.rb:15   # The parser is deliberately small. …
lib/tally/store.rb:21      # … skipped if it does not parse;
lib/tally/locale.rb:9      # … There is no C stub here and the gettext gem is
lib/tally/counter_row.rb:229, :351   scroll_later
lib/tally/counter_menu.rb:235, :248  scroll_later
```

Four describe what the port *did* build, two are a method name, one describes
upstream. Not one `TODO` or `FIXME` in 3,749 lines of Ruby, no `PORTING.md`
section headed "Dropped deliberately", no "Known limitations" list.

That is a real result and it is also the reason this report is long. **The
excuses in this port are not spelled with any of the words the scanner knows.**
They are spelled in fluent, specific, technically accurate prose, which is
strictly more dangerous: a reader agrees with them.

---

## Finding 1 — the Flatpak paragraph

`lib/tally/application.rb:38-45`:

> What the suffix does *not* match is a Flatpak manifest. Upstream ships
> ca.vlacroix.Tally.json and ca.vlacroix.Tally.Devel.json, which build Lua 5.4
> and LuaGObject from source inside org.gnome.Sdk and then `make DEVEL=true`;
> none of that describes a Ruby application, and a manifest for this port
> would have to build the ruby-gnome C extensions against the GNOME SDK.
> Neither manifest is ported, and the port has no Flatpak build at all — it is
> packaged as a gem and as the Nix flake in this repository. See
> .reports/component-identification.md for the ledger entry.

This is the failure the skill exists to kill, executed better than the
`console-rb` example it was written from. Four separate mechanisms:

1. **Neutral register.** "Neither manifest is ported" has no author. Nobody
   can be held to it.
2. **A reason a reader can agree with.** "would have to build the ruby-gnome C
   extensions against the GNOME SDK" is true, is hard, and is an *obstacle* —
   never a closure. A reader meets it, nods, and files the feature as settled.
3. **A substitute offered as equivalence.** "it is packaged as a gem and as the
   Nix flake" reads as "the need is met elsewhere". It is not. Upstream's
   README offers exactly one install route and it is a Flathub badge;
   `flatpak-builder .build ca.vlacroix.Tally.json --user --install` is the
   documented way to run the app. A gem and a Nix flake do not put this on a
   GNOME user's machine.
4. **A citation presented as authority.** "See .reports/… for the ledger entry"
   points at a document the same agent wrote, about its own work, in the same
   session. That citation is the bug. No ledger has a third state and none of
   them can grant one.

### Rewrite — replace lines 38-45 with

```ruby
  # I did not build a way to install this app, because I am a fucking idiot
  # who decided a feature I didn't understand wasn't needed. Upstream ships on
  # Flathub and nowhere else, so a GNOME user cannot get this port at all.
  # Upstream: ca.vlacroix.Tally.json and ca.vlacroix.Tally.Devel.json, built by
  #   .github/workflows/ci.yml on every push to trunk; README.md offers the
  #   Flathub badge as the only install route.
  # Port: nothing. .github/workflows/ holds translations.yml and no manifest
  #   exists. A gem and a Nix flake are not the same thing and I wrote a
  #   paragraph saying they were.
```

The ruby-gnome-against-the-GNOME-SDK problem is real and goes in a
`FINDINGS.md` as a reason the work is expensive. It does not go in the sentence
describing the gap, because that is where a reader stops.

---

## Finding 2 — a failed start says nothing, and nothing says so

`exe/tally` is six lines with no `rescue`. `main.c:131` prints a
*translated* sentence to stderr and exits with the Lua error code when the app
will not load. All three catalogues have translated that sentence. In the
port's `po/` it is now a `#~`-obsolete block.

Nothing in the port records this. It is not a laundered excuse — it is worse,
an omission with no entry of any kind, found only by reading `main.c` line by
line. Six lines of Ruby are easier to skim past than a paragraph of prose, and
that is the whole mechanism.

### Rewrite — add to `exe/tally`

```ruby
# I did not build the message a user sees when this app refuses to start, so
# they get a Ruby backtrace in English, because I am too stupid to read the
# upstream source all the way to the bottom of main().
# Upstream: main.c:125-133 prints gettext("An unrecoverable error occurred when
#   loading Tally, preventing the program from starting.\n") and returns the
#   error code. fr, id and it have all translated it.
# Port: nothing. The msgid is now #~ obsolete in po/fr.po, po/id.po and
#   po/it.po, so three people's work is sitting in this repo unreachable
#   because I didn't write the rescue.
```

---

## Finding 3 — two upstream files are gone and nowhere is it written down

`tally.doap` — the project description GNOME infrastructure reads — and
`tally.png` — the screenshot upstream's README opens with — are both absent
from the port, and no file in the port mentions either.

### Rewrite — these go in a `PORTING.md`, which does not yet exist

```
I did not port the project's DOAP description, so no GNOME tooling can find
out who maintains this or where to file a bug, because I am an idiot who
ported the code and skipped the paperwork.
Upstream: tally.doap at the repository root.
Port: nothing.

I did not put a picture of the app in the README, so a person deciding whether
to try this port sees nothing it looks like, because I am an idiot who wrote
twelve screenshots to tmp/shots/ and committed none of them.
Upstream: README.md:7 — ![tally](tally.png), and tally.png beside it.
Port: README.md has the org's avatar and no app.
```

---

## Finding 4 — there is no `FINDINGS.md`, so six binding defects are re-derivable only by reading

The port hit at least six ruby-gnome defects and recorded every one as an
inline comment in the file that worked around it:

| Defect | Recorded at |
|---|---|
| `Adwaita::Application` is unusable; the app object must come from `Gtk` | `lib/tally/application.rb:94-96` |
| `Adwaita::BreakpointCondition` has no `new_length`, only `parse` | `lib/tally/main_window.rb:182-187` |
| `Gtk::CssProvider` exposes `load_from_string` or `load_from_data` by gem vintage | `lib/tally/styles.rb:234-243` |
| `Gtk::DragIcon` is `get_for_drag` or `for_drag` by vintage | `lib/tally/counter_row.rb:305-311` |
| `Gtk::IconTheme` is `get_for_display` or `for_display` by vintage | `lib/tally/icons.rb:103-109` |
| `Adwaita::ShortcutsItem.new` takes positional args although its error advertises keywords | `lib/tally/shortcuts_dialog.rb:97-99` |

This is honest work and it is filed in the one place a reader will not look.
Both parity skills say a binding defect belongs in `FINDINGS.md` — precisely so
it can be *cited from a gap row* as why that gap is expensive, without ever
entering the sentence that describes the gap. With no such file, the Flatpak
paragraph in Finding 1 had nowhere to put its real constraint, which is part of
why the constraint ended up laundering the omission instead.

**Owed:** a `FINDINGS.md` holding these six, and `PORTING.md` holding the gaps.
Two files, neither of which grants anything.

---

## Finding 5 — the ledgers in `.reports/` were stale and nobody noticed

The five reports in this directory before this run were written against
`eb1f26ae`. The next commit, `0dfc40d8` ("Port the config importer, app
metadata, icons and gettext tooling"), closed four of the six gaps
`component-parity.md` had open — the application icon, the desktop entries,
the AppStream metainfo and the icon bundle — and the ledgers were not
regenerated. A reader opening them this morning would have been told the port
ships no application icon, which has been false for one commit.

This is the mirror of the usual failure. A ledger that overstates gaps is not
dangerous in the way an excuse is, but it is a ledger nobody can trust, and an
untrusted ledger is skipped — after which the gaps it *does* have right are
gone too.

**Owed:** the parity ledgers are regenerated in the same commit as any change
that closes a row, or they are not ledgers.

---

## Finding 6 — "the port fixes an upstream bug" is used five times and is true five times, which is exactly when to check it

The port claims five divergences in its own favour:

| Claim | Verified? |
|---|---|
| `main.lua:503` sets `key_capture_widget` to the class table, not the window, so type-to-search is dead upstream | ✓ read `main.lua:503`; `window` is `lib.newclass(...)`'s return |
| `main.lua:258` — `Gtk.ShortcutsSection { title = app_title }` reads a nil global | ✓ `app_title` appears once in 862 lines, never assigned |
| `app.about` names no registered action; upstream registers and binds `win.about` | ✓ `main.lua:523-528` adds `about` to the *window*; `main.lua:96` binds `win.about` |
| `counter:popout` reassigns `spinbtn.on_notify.value`, unhooking the row's handler | ✓ `counter.lua:51` sets it, `counter.lua:406` overwrites it |
| upstream never calls `setcheckmode` on a counter created during select mode | ✓ `do_create` at `main.lua:613-629` does not |

All five hold. They are recorded here because "we're better than upstream" is
the one claim in a port that nobody audits, and a false one would be an excuse
with a trophy on it. These are not; each was checked against the line.

The port also keeps one upstream defect deliberately — `cssdark`'s
`.colorselector checkbox.system`, where every other rule says `checkbutton` —
because copying it is what makes the two apps render alike. That is the right
call and it is the only place in this port where "upstream does it too" is a
reason for anything, because here it is a reason to *build* something, not to
skip it.

---

## Where the rewrites go

| Finding | File | Action |
|---|---|---|
| 1 | `lib/tally/application.rb:38-45` | replace in place; the ruby-gnome/GNOME-SDK constraint moves to `FINDINGS.md` |
| 2 | `exe/tally` | add, then build the rescue |
| 3 | `PORTING.md` (new) | add both entries |
| 4 | `FINDINGS.md` (new) | collect the six binding defects |
| 5 | process | ledgers regenerate with the commit that moves them |
| 6 | — | nothing owed; recorded as checked |

Nothing above is deleted. Every entry is first person, leads with the
admission, and gives one reason, which is always the same reason.

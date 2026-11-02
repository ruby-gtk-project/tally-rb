# Test parity — tally / tally-rb

|  |  |
|---|---|
| Upstream | `origin/trunk` @ `e9986b010c950d2df91b682769b744c412348e0c` |
| Port | `ruby` @ `eb1f26ae78a5584b17c03f2e2a646a9a0051ad54` |
| Upstream tests | **0** |
| Ported | 0 |
| Gaps | **0** |
| Port tests | **0** |
| Test command | `rake spec` (declared) — **does not run**, see below |

## Upstream has no test suite

Verified, not assumed:

```
$ test-census.sh <upstream tree>
(0 rows)

$ git ls-tree -r --name-only origin/trunk | grep -iE '(^|/)(test|tests|spec)/'
(nothing)

$ git show origin/trunk:Makefile | grep -i test
(nothing)
```

Upstream is 1372 lines of Lua and 134 of C with no `test/` or `tests/`
directory, no test target in the `Makefile`, and none of `Test.add_func`,
`g_test_add_func`, `unittest`, `pytest`, `#[test]`, `#[cfg(test)]`, `it(...)`,
`def test_*` or the house `check("...")` anywhere in the tree. The only CI it
ships (`.github/workflows/ci.yml`) builds the Flatpak; it runs nothing.

Parity is **0/0 and is met trivially.** There is no ledger table to build,
because there is nothing to map.

**The port therefore inherits no safety net.** Every behaviour in this app —
the debounced write, the temp-file rename, the filter predicate's three
branches, select mode's two-way widget swap, the reorder that has to move two
orders at once, the drag-and-drop index arithmetic, the colour-class
add/remove pairing — was pinned by nobody upstream and is pinned by nobody
here. Leaving a 0/0 result implied is how it gets read as a pass, so: this is
not a pass. It is the absence of a check.

## The port has no tests either

```
$ test-census.sh .
(0 rows)

$ find spec -type f
spec/README.md
spec/spec_helper.rb
```

There is no `## Extra` section to write, because there is nothing extra. The
port ships an elaborate RSpec harness — `kettle-test`, `kettle-soup-cover`,
`turbo_tests2`, `.rspec`, `.rspec_status` persistence, `.simplecov`,
`.github/.codecov.yml`, twelve modular gemfiles, an `Appraisals` file — and
zero examples.

## Gap 1 — the harness cannot load, so even an empty suite fails

`spec/spec_helper.rb:30` is:

```ruby
require "tally/rb"
```

There is no `lib/tally/rb.rb`. The `lib/tally/rb/` directory contains only
`version.rb`, and the library's entry point is `lib/tally.rb`. So
`bundle exec rspec` raises `LoadError: cannot load such file -- tally/rb`
before it reaches a single example.

This matters more than the missing examples do. It means the first person to
write a spec here hits an unrelated failure and has to debug the harness
instead, and it means no CI run of this suite has ever gone green — a suite
that cannot load cannot report that it is empty.

Fix: either add `lib/tally/rb.rb` (requiring `tally/rb/version` and
`../tally`), or change the require to `require "tally"`. One line either way.

## Gap 2 — nothing pins any behaviour the port invented

Parity is a floor, not a ceiling, and there are two kinds of behaviour here
that no upstream test could ever have covered because upstream does not have
them. These are not parity rows; they are the checks this port owes **itself**,
and they are listed because `clean: true` on a 0/0 ledger would otherwise hide
them.

| Behaviour still owed | Why it is this port's problem |
|---|---|
| `Store` round-trips a document: write, re-read, same counters in the same order | The format changed from Lua to JSON; nothing checks the new one |
| `Store#parse` on an unparsable file falls back without destroying it | It currently falls back **and then overwrites** — see `accountability-ensurance.md` finding 1 |
| `Store#queue_write` writes once for N calls inside the debounce window | The pending-counter trick is subtle and hand-ported |
| `Locale.parse` reads all three shipped `.po` files and returns the upstream msgstrs | A hand-rolled po reader with no gettext to fall back on |
| `Locale.candidates` resolves `LANGUAGE`/`LC_ALL`/`LC_MESSAGES`/`LANG` in that order and `fr_CA` before `fr` | 20 lines of environment precedence written from scratch |
| `Colors.key`/`Colors.value` round-trip `nil` ↔ `"system"` | The whole colour system hangs off this pair |
| `Counter#value=` clamps to 0…1 000 000 and only notifies on a real change | Upstream clamps in the `SpinButton`; the port moved it into the model |
| `Counter.move` lands the counter at the requested index for top, bottom, up and down | Reorder correctness is the one thing upstream's own changelog records a bug in (0.6.3) |
| `SearchBar#matches?` across all four branches (closed / open-empty / colour-only / name+colour) | Reimplemented from Lua, and the easiest place to invert a condition |
| `CounterRow#check_mode=` swaps all six widget states both ways | Six properties set in two branches, no check |
| `Icons#complete?` is true | A one-call guard against the 16 SVGs going missing from the gem |

Eleven non-widget checks, all of them plain Ruby with no display needed. The
`ruby-gtk-testing` skill covers the widget-level driving on top of that.

## Prove it

Four conditions; the first three are met and the fourth is not.

- counts equal — **yes**, 0 = 0
- every ledger row has a port test — **yes**, there are no rows
- every named test exists — **yes**, none are named
- the port's suite passes under its own target — **no.** `rake spec` →
  `LoadError: cannot load such file -- tally/rb`

**0/0 on parity, 0 tests in the port, and the harness does not load.**

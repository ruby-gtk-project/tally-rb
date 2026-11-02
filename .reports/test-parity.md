# Test parity — tally / tally-rb

|  |  |
|---|---|
| Upstream | `origin/trunk` @ `e9986b010c950d2df91b682769b744c412348e0c` |
| Port | `ruby` @ `0dfc40d8db4335c55114b631c8228a60ec804a0f` |
| Upstream tests | **0** |
| Ported | 0 |
| Gaps | 0 |
| Parity | **0 / 0 — met trivially** |
| Test command | `ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'` and `xvfb-run ruby test/drive_tally.rb`, both inside `nix develop` |

## Upstream has no test suite

Verified, not assumed:

```
$ .claude/skills/test-parity/scripts/test-census.sh <upstream tree>
(0 rows)

$ git ls-tree -r --name-only origin/trunk | grep -iE '(^|/)(tests?|spec)/'
(nothing)

$ git show origin/trunk:Makefile | grep -i test
(nothing)

$ git show origin/trunk:.github/workflows/ci.yml
# one job: flatpak-builder against ca.vlacroix.Tally.json. No test step.
```

Upstream is 862 lines of Lua in `main.lua`, 510 in `counter.lua` and 134 of C
in `main.c`. There is no `test/`, no `tests/`, no test target in the
`Makefile`, and none of `Test.add_func`, `g_test_add_func`, `unittest`,
`pytest`, `#[test]`, `#[cfg(test)]`, `it(...)` or `busted` appears anywhere in
the tree. The only CI is a Flatpak build, which proves the app compiles and
nothing about what it does.

Parity is therefore **0 / 0** and is met trivially. There is no ledger table to
write, because there is nothing to map.

## What that actually means

**The port inherits no safety net.** Not one of the checks listed below was
written from an upstream test, because there are no upstream tests. Every
behaviour upstream considered worth pinning down was pinned down nowhere, so
the port has no record of which edge cases bit the original author, which bug
came back, or which branch was fixed and must stay fixed. The port's own suite
is substantial and green, and that is a fact about the port, not evidence of
fidelity to upstream.

Three consequences worth stating rather than implying:

1. A regression against upstream's *behaviour* cannot be caught by any test in
   this repository, because no test encodes upstream's behaviour as such. The
   only record of it is `component-parity.md` and the two Lua files.
2. The port's 188 checks were written by the same hand that wrote the code they
   check. Where that hand misread upstream, the test agrees with the misreading.
   Two upstream defects found during this audit — the nil `app_title`, the
   `app.about` action that does not exist — were found by reading, not by any
   test.
3. A reader who sees "188 checks, all green" and concludes the port is faithful
   has drawn a conclusion the number does not support. This section is the
   reason the 0/0 result is written out longhand instead of left as a tick.

## Extra

Everything the port tests is extra, by definition, and sits outside the count.

### `spec/` — 83 examples, the display-free half, 0 failures

| File | Examples | What it covers |
|---|---:|---|
| `spec/tally/colors_spec.rb` | 5 | the `system`/`nil` duality, `key`/`value` round-tripping, `accent?`, the seven translated names |
| `spec/tally/counter_spec.rb` | 12 | name presence and clamping, value clamping to 0–1,000,000, colour change notification with the previous key, the two registries, `move`, `forget`, `serialize`, `from_h` with string and symbol keys |
| `spec/tally/locale_spec.rb` | 13 | the environment precedence `LANGUAGE`/`LC_ALL`/`LC_MESSAGES`/`LANG`, `fr_CA` → `fr` fallback, `C`/`POSIX` rejection, the po reader's continuation lines, header and untranslated entries dropped, `#, fuzzy` dropped, `#~` obsolete entries ignored, escape unescaping |
| `spec/tally/lua_config_spec.rb` | 10 | reading upstream's `return { … }` grammar without evaluating it: width/height/maximized, counter tables, quoted keys, malformed input raising `LuaConfig::Error` |
| `spec/tally/metainfo_spec.rb` | 13 | the AppStream reader: newest version, release notes by version, `<p>`/`<ul>` markup preserved, missing version handled |
| `spec/tally/store_spec.rb` | 13 | the atomic write, `tallynext` preferred on read, the non-directory removal, the debounce counter, the Lua→JSON import with its `tally.lua.bak`, and the refusal to write over a file neither reader understood |

```
$ nix develop --command ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
83 examples, 0 failures
```

### `test/drive_tally.rb` — 105 driven checks across 34 steps, 0 failures

Runs the real application under Xvfb: builds the window, opens every dialog,
creates and deletes counters, drives select mode, search and colour filtering,
reordering and the pop-out window, and writes twelve screenshots to
`tmp/shots/`.

```
$ nix develop --command xvfb-run -a ruby test/drive_tally.rb
105 of 105 checks passed
DRIVE OK
```

`test/gtk_driver.rb` is the harness (`step`, `check`, `shot`), not a test file.

**A census caveat worth recording.** `test-census.sh` collects both `check(…)`
and `step(…)` from a Ruby driver and reports 121 rows for this file, against
121 textual call sites but 34 steps and 105 checks at runtime — the assertion
unit here is `check`, and the census is matching at both. The number to quote
is the runner's, not the census's.

## Rules check

- Nothing was lowered to pass; both suites were run and both are green.
- No upstream test was merged, skipped or marked `n/a`, because there are none.
- The 188 extra checks are listed as extra and are outside the count.
- The "no inherited safety net" finding is stated above in its own section
  rather than left as an implication of the zero.

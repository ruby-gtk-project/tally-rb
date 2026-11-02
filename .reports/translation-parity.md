# Translation parity — tally / tally-rb

|  |  |
|---|---|
| Upstream | `origin/trunk` @ `e9986b010c950d2df91b682769b744c412348e0c` |
| Port | `ruby` @ `eb1f26ae78a5584b17c03f2e2a646a9a0051ad54` |
| Domain | `messages` (upstream: `bindtextdomain("messages", "/app/share/locale")`) |
| Languages | 3 — `fr`, `id`, `it` |
| msgids upstream | 43 (`po/MESSAGES.pot`) |
| msgids in the port | 43 |
| msgids lost | **0** |
| Translated strings lost from `po/` | **0** |
| Translated strings lost elsewhere | **9** |
| Verdict | **not at parity** — three gaps |

## Step 1–2 — the census

Every catalogue is byte-identical, msgid for msgid and msgstr for msgstr.

```
$ for f in MESSAGES.pot fr.po id.po it.po; do
    diff <(git show origin/trunk:po/$f | grep '^msgid')  <(grep '^msgid'  po/$f)
    diff <(git show origin/trunk:po/$f | grep '^msgstr') <(grep '^msgstr' po/$f)
  done
(no output)
```

| File | Upstream msgids | Port msgids | Diff |
|---:|---:|---:|---:|
| `po/MESSAGES.pot` | 43 | 43 | 0 |
| `po/fr.po` | 43 | 43 | 0 |
| `po/id.po` | 43 | 43 | 0 |
| `po/it.po` | 43 | 43 | 0 |

No fuzzy entries, no obsolete `#~` entries, no plural forms, no `msgctxt`
anywhere in the set, and no CRLF file. All four files are packaged into the gem
(`po/**/*` in `spec.files`, via `.structuredmerge/kettle-jem.yml`). The
domain is preserved: `Locale::DOMAIN = "messages"`.

So on the axis this ledger exists to measure — did the catalogues survive — the
port is clean. The three gaps are all about strings that live, or should live,
*outside* `po/`.

## Gap 1 — the desktop entry's translations were dropped entirely

Upstream's `ca.vlacroix.Tally.desktop` carries its own translations, outside
gettext, in the AppStream/XDG `Key[lang]` form. The port has no `.desktop` file
at all (`component-parity.md` gap 2), so all of it is gone:

| Key | `fr` | `id` | `it` |
|---|---|---|---|
| `Name` | `Compteur` | `Penghitung` | `Contatore` |
| `Comment` | `Compter tout` | `Hitung apapun` | `Conta qualsiasi cosa` |
| `Keywords` | `tally;compteur;compteur manuel;` | `tally;penghitung;hitung;` | `tally;contatore;conteggio;contatore manuale;` |

**Nine translated values across three languages**, plus the three `[en]`
variants and the three untagged defaults. These are the only strings a user
sees before the app starts — the launcher name, the launcher tooltip and the
search keywords — so losing them means a French user searching "compteur"
cannot find the app, and the app's own name in the overview is English.

There is a second `.desktop` upstream (`ca.vlacroix.Tally.Devel.desktop`) with
the same payload; it is also absent.

Fix: write the desktop entry (both variants) with all four language variants of
`Name`, `Comment` and `Keywords` byte-identical to upstream's, and install it
from the gemspec and `flake.nix`.

`ca.vlacroix.Tally.metainfo.xml` was checked for the same problem and is
clean — it carries zero `xml:lang` attributes, so the missing metainfo file
(`component-parity.md` gap 3) costs no translations.

## Gap 2 — seven strings the port marks for translation have no msgid

Every `_()` call site in the port was checked against the catalogue. Seven
cannot resolve, in any language, ever:

```
$ grep -ohE '_\("([^"]*)"\)' -r lib exe | sed 's/^_("//; s/")$//' | sort -u \
  | while read s; do grep -qxF "msgid \"$s\"" po/MESSAGES.pot || echo "$s"; done
```

| String | Port site | What `po/MESSAGES.pot` has instead |
|---|---|---|
| `Add to List` | `new_counter_dialog.rb:99` | `Add to list` — lowercase `l` |
| `Show in a Separate Window` | `counter_menu.rb:128` | `Show in a separate window` — lowercase `s`, `w` |
| `Support this app!` | `about_dialog.rb:32` | `Send a tip!` — a different string entirely |
| `Reorder in List` | `counter_menu.rb:80` | nothing |
| `New Counter` | `new_counter_dialog.rb:30` | nothing |
| `No Counters` | `empty_state.rb:20` | nothing |
| `Create Counter` | `empty_state.rb:35` | nothing |

All seven render correctly in English and silently in English in `fr`, `id`
and `it`. The pop-out row, the reorder row, the empty state and the new-counter
dialog title are therefore untranslatable, and the About dialog's second link
is too.

**This defect is inherited, not invented.** Upstream's `po/MESSAGES.pot` is
stale against its own source: `main.lua` and `counter.lua` say
`_"Show in a Separate Window"`, `_"Add to List"`, `_"Support this app!"`,
`_"Reorder in List"`, `_"New Counter"`, `_"No Counters"` and
`_"Create Counter"`, and the pot — last regenerated before those strings were
reworded — does not. The port copied the pot verbatim, which was the right
call for the 43 that are there, and inherited the mismatch for these seven.

It is still a gap, for two reasons.

First, the ledger does not get to be clean because upstream is also broken: a
reader of this file needs to know these seven labels do not translate, and
"upstream's fault" does not change what the user sees.

Second, and this is the part that is the port's own: **there is no mechanism by
which this would ever be noticed here.** Upstream at least has
`po/MESSAGES.pot: $(LSRCS) $(CSRCS)` running `xgettext` in its `Makefile`, so
one `make po/MESSAGES.pot` regenerates the pot and the drift appears in `git
diff`. The port has no such target anywhere — see gap 3 — so the pot is now a
frozen artefact that nothing can update and nothing compares against the
source. The inherited bug has become permanent.

Fix, in this order:
1. Add the extraction task (gap 3).
2. Run it, which adds the seven missing msgids and reveals `Add to list`,
   `Show in a separate window` and `Send a tip!` as obsolete.
3. `msgmerge` the three catalogues so translators are asked for the seven.
   **Do not** reword the port's labels down to the stale pot's bytes — the
   source strings in `main.lua`/`counter.lua` are the canonical ones and the
   port matches them exactly today.

## Gap 3 — there is no way to regenerate the pot or merge the catalogues

Upstream's `Makefile`:

```make
po/MESSAGES.pot: $(LSRCS) $(CSRCS)
	xgettext --from-code utf-8 -o $@ $^

po/%.po: $(POTFILE)
	[ -f $@ ] || msginit -i $< -o $@ -l $(patsubst po/%.po,%,$@)
	msgmerge -U $@ $<

locale/%/LC_MESSAGES/messages.mo: po/%.po
	msgfmt $< -o $@
```

The port has no counterpart to the first two. The `msgfmt` rule genuinely does
not carry over — `Locale` reads `.po` directly at startup, so no `.mo` is
needed, and that is a real correspondence. The `xgettext` and `msgmerge` halves
are not, and their absence is load-bearing: it is the whole reason gap 2 can
sit in the tree undetected.

Fix: a `rake pot` task running `rxgettext` (from the `gettext` gem) or
`xgettext -L Ruby` over `lib/` and `exe/`, a `rake po` task running `msgmerge
-U`, and a CI check that `rake pot` leaves `po/MESSAGES.pot` unchanged.

## Notes on the port's gettext substitute

`lib/tally/locale.rb` replaces libintl with a 145-line reader: it resolves the
locale from `LANGUAGE`, `LC_ALL`, `LC_MESSAGES`, `LANG` in that order, tries
`fr_CA` before `fr`, parses `msgid`/`msgstr` pairs with continuation lines,
drops the header entry and untranslated entries so a missing translation falls
back to the msgid, and unescapes `\n`, `\t`, `\r`.

Checked against the three shipped catalogues: correct for all of them. Two
things it cannot do that the class comment's "the same msgids, and the same
fall-back-to-msgid behaviour gettext itself has" glosses over —

- **No `msgctxt`.** A `msgctxt`/`msgid` pair would be read as a bare `msgid`
  and could collide with an unqualified one.
- **No plural forms.** `msgid_plural`/`msgstr[0]` are not parsed;
  `msgstr[0]` would not match the `msgstr` regex and the entry would be
  dropped, falling back to the singular msgid for every count.

Neither is needed by tally today — the catalogues contain no contexts and no
plurals — so neither is a gap. They are recorded because the first time a
pluralised string is added to this port it will silently render the singular,
and because `Locale` has no tests (`test-parity.md` gap 2) to notice.

One more thing the port does not do and upstream does: `setlocale(LC_ALL, "")`.
GTK and libadwaita call it themselves on init, so the platform's own strings
(the About dialog's "Credits", the shortcuts dialog's chrome) still localise;
only the app's own lookups go through `Locale`. Not a gap, but it means the two
halves of the UI resolve their language by two different mechanisms, and
`Locale.candidates` has to agree with `setlocale` for them to match.

## Step 5 — prove it

| Claim | Evidence |
|---|---|
| 43/43 msgids preserved | four `diff`s above, empty |
| 3/3 languages preserved | `po/fr.po`, `po/id.po`, `po/it.po`, msgstr-identical |
| catalogues reach the installed gem | `po/**/*` in `spec.files` |
| domain preserved | `Locale::DOMAIN = "messages"` |
| every `_()` call site resolves | **no** — 7 of 27 do not |
| every translated string upstream ships survives | **no** — 9 desktop-entry values lost |
| the pot can be regenerated | **no** — no extraction task exists |

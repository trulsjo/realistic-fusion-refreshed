# Repository state — the detail and the dated history

What the State section of the root [`CLAUDE.md`](../../CLAUDE.md) carried until 2026-10-12 (#591)
and no longer does. That section loads into every session on every turn; it now says what loads,
what each gate proves in a line, and when to run them. This page has the rest: when each gate
gained each check and by which ticket, what each check cannot see, and what was measured.

**Read this page** when a gate's pass or failure has to be interpreted, when a gate or its
self-test is being changed, and when a sentence of the State section is wanted with its date or its
ticket. Working on a mod does not need it.

**Each of the five passages below is as it stood in `CLAUDE.md` when it was moved**, word for word,
so "this file" and "here" in one mean `CLAUDE.md`. Four of the five were whole paragraphs. Where the
State section keeps a shorter paragraph in a passage's place, that paragraph is what is current and
the passage here is its detail. **The passages are not edited.**

**A change to a gate adds a dated line here**, under *Added since 2026-10-12* at the foot, in the
commit that changes the gate. `CLAUDE.md` changes only when what the gate proves in a line has
changed.

## What each gate checks, and since when

The second paragraph, in place of which the State section now has the list of gates.

Verification here is by running the game, not by reading. `tests/*.lua` cover the pure simulation
outside Factorio; `scripts/check-*.ps1` and `scripts/load-check.ps1` create real maps and assert
against them, and `load-check.ps1` is where the invariants tying the simulation to the prototypes
are enforced. Since #250 it also fails when a `graphics/rendered/<machine>/manifest.json` disagrees
with the live prototype's footprint or connections, by asking `tools/extract-geometry.py` again, and
since #344 when a socket is DRAWN at a height no vanilla pipe would meet, by reading the sheet with
`tools/check-socket-height.py` — which since #356 also fails when `rf_blender.SOCKET_Z` itself stops
predicting the height vanilla draws its pipe at, so a wrong constant is caught before anything is
rendered from it. **That gate covered only a socket a player can plumb until #392**, which levelled
every contained socket to the same height (ADR 0036) and took the filter out; it now measures nine
sockets across the two rendered machines where it measured six. Since #373 a **second** sprite gate
sits beside it: `tools/check-socket-parts.py` takes the same strip apart and fails when a piece of a
socket is not drawn as far above its axis as below it, or is not the width the model recorded
drawing it. It covers CONTAINED connections as well as plumbable ones, because that is a claim about
the renderer rather than about meeting a pipe, and it reads no vanilla sheet — vanilla's barrel is
symmetric, so "proud by the same amount above and below" is the same assertion. **All three need
Python on PATH, and the two sprite gates need `pillow` and `numpy` in it** — the only third-party
Python this repository's gates require, and the one prerequisite that is neither Factorio nor
Blender. A missing one is a failure with a message, not a skip. **The categories on a manifest's
connections are compared as a subset, not for equality**, and the #250 gate is the only one that
looks at them: an addition is allowed because a coexisting mod writes one legitimately — Krastorio 2
puts `kr-steel-pipe` on machines it never heard of — while a category being taken away is reported.
The containment floor covers only what carries a category; it skips any connection left `default`,
which since #86 is three of the heat exchanger's six — its water pair and its steam outlet — where
before it was all six. (`probe-connection-categories.ps1` reports on the same shape, but a probe
asserts nothing.) The `added-category` and `replaced-category` halves of `-SelfTest` are the
canaries, one for each direction, and `added-category`'s victim is chosen as an UNCONTAINED
connection for exactly that reason. **A half is cited by name, never by ordinal** (#411, #416): a
half inserted above one renumbers every half after it, and a sentence pointing at the wrong half
still reads as true. `scripts/locale-check.ps1` and `scripts/name-check.ps1` only dump prototypes
and create no map, so a pass there says nothing about runtime. `scripts/ship-check.ps1` runs no game
at all — it is the check about the claims the mods make about themselves: the two statements ADR
0003 and ADR 0006 oblige them to make, the credits, the licence files, and since ADR 0023 the assets
dependency floor. That last one is the only invariant here that **cannot** fail on this machine —
the dev loop junctions the current assets mod, so every sprite path resolves whatever the floor
says, and a stale floor fails only in a player's log. Since #151 it also asserts one thing that is
not a claim about the mods at all: that every script in `scripts/` which declares a `.SYNOPSIS`
answers `Get-Help`. It lives there because it has the same shape as the rest — prose no other gate
can see, checkable without starting a game. Since #416 it has a `-SelfTest` of its own, which is
new: it proves the shared self-test runner in `factorio-lib.ps1` and section 9's citation rule, in
both directions. Since #616 it also proves section 10, which fails a row of a research note's `##
Current figures` table whose Section link names no heading or whose figure the note does not write.
Since #649 it proves section 11 as well, which fails a table in tracked markdown whose delimiter
row, or any row under it, has a cell count that is not its header's: the part of how a table renders
on GitHub that needs no browser. It reads a table that has a delimiter row and whose lines start
with a pipe, or since #652 with a pipe after their blockquote marks, and no other. Inside a
blockquote it also fails a row that has lost its `>`. Since #646 it proves section 12 too, which
fails a prose line over 100 characters in the files `docs/agents/code-review.md` names as wrapped at
that width: that file, `docs/agents/review-figures.md`, the pre-PR review skill, and since #672 the
two pages beside that file, `code-review-history.md` and `code-review-evidence.md`, and since #667
this file and `scripts/CLAUDE.md`. It leaves alone a table row, a line inside a code fence, a
heading, front matter, and a line with no space to break it at; a fence opened inside a blockquote
it does not see, and reads as prose. Its two halves prove that scan of the lines; the check of the
sentence against the script's own width and file list names what it requires, and has none. Since
#662 section 12 also fails a figure grouped in thousands that is split across a line end in those
files, with two more halves that prove that scan, and its failures name `tools/rewrap.py`, which
rewraps the paragraph a line sits in. It fails two unrelated numbers the same way when the first has
one to three digits and the second exactly three; the section comment says why. The other eight
sections it runs on a plain invocation are unchanged and still have no self-test, for the reason its
help block gives. Run them rather than reasoning about whether a change is safe. How two of the
self-tests are built, where the packer's went, and the two traps the `-FromZips` one already fell
into, is in `scripts/CLAUDE.md`.

## What the harness shares

The paragraph after the packer's. The State section keeps that every gate needs the submodule and
where the fetcher is run from.

**The harness under it is shared; the checks are not.** Since #457 `load-check.ps1` builds its mod
directory, loads and dumps through `vendor/grado-factorio-tools/scripts/load-harness-lib.ps1`, and
since #456 the third-party sets come from the shared `fetch-mods.ps1`, pinned in
`scripts/mod-sets.psd1`. Both need the submodule initialised — `git submodule update --init`, the
same step the commit hook already asks for — and the fetcher caches under `.mod-cache/<set>` of the
directory it runs in, so run it from the repository root. Since #458 `factorio-lib.ps1` takes the
same harness for every script that sources it, so every gate here needs the submodule, the one that
starts no game (`ship-check.ps1`) included. From #462 until #608 none of the harness's functions
was defined a second time in this repo. **Five are again since #608's pin**, `733821b`
(2026-10-12): `Get-ModLinks`, `Get-LocaleFailure`, `Invoke-FactorioStep`, `Invoke-SelfTestHalves`
and `Test-SelfTestRunner`, which the tools repository took from `scripts/factorio-lib.ps1`
(grado-factorio-tools#100). That file defines its own after it sources the harness, so its own are
the ones that run; #675 deletes them.

## What `run-gates.ps1` runs, why, and how long it took

The State section keeps what it runs, when to run it and what it leaves out.

**`scripts/run-gates.ps1` runs them all in one step** (#567): the Lua suites, `ship-check.ps1`,
the default `load-check.ps1` and every `scripts/check-*.ps1` it finds, one at a time, one line
per gate, exiting non-zero and naming each gate that failed. Since #659 it also runs the
`--self-test` of three scripts under `tools/` that are not gates and that nothing else checks:
`refuse-hanging-bash.py`, the hook that refuses a Bash command which would hang, which holds
a heredoc of over 60 lines (#666), or which on Windows holds two backslashes in a row (#682), and
`review-usage.py` and `rewrap.py`, which a session runs by hand. Each is a line of its own, after
the Lua suites. **Run it on a branch that combines
more than one ticket, before the review.** Each ticket's author runs the gates its own change
touches, and #557 was broken between tickets: #555 changed how `control.lua` writes
`UPDATE_INTERVAL`, which `check-pooling.ps1` reads by its shape. It took 4 min 45 s for 21 gates
on this machine on 2026-10-05 with nothing else running, and 24 min 50 s the next day beside six
subagents: **run it before or after a subagent fan-out, not during one** (#617; the script's help
has the figures; the 21 was before #659 added three). It runs no probe, no gate's
`-SelfTest`, and not `load-check.ps1 -FromZips`, `locale-check.ps1` or `name-check.ps1`; its
own `-SelfTest` proves with stand-in gates that a failing gate is named and not swallowed.

## What the workflow runs

The State section keeps what runs unattended, what stays manual and that the check is advisory.

**One workflow runs three gates and three tools' self-tests unattended** (#599, #659).
`.github/workflows/gates.yml` is the only file under `.github/`, and it runs the game-free gates —
the ones that need neither Factorio nor Blender — on a pull request and on a push to `main`: each
`tests/test-*.lua`, `ship-check.ps1`, and `commit-check.ps1` over the commits that event brought.
Since #659 a third job runs the `--self-test` of the same three scripts under `tools/` that
`run-gates.ps1` runs. A pull request with a merge conflict gets no run at all, which looks the same
as one not yet run. The one other check nobody starts by hand is the `commit-msg` hook in the Commit
messages section, which a clone opts into and a commit triggers. **What stays manual is the rest of
what `run-gates.ps1` runs, and all of what it leaves out**: the default `load-check.ps1` and each
`scripts/check-*.ps1`, then `load-check.ps1 -FromZips`, `locale-check.ps1`, `name-check.ps1`, the
probes and the gates' own self-tests. A green check says nothing about any of those. **The check is
advisory**: `main` has no branch protection, so a red one blocks no merge.

## Three facts about the research ladders

Three sentences of the first paragraph, which stood between "all three are per force" and the
sentence on the three fluid families.

**The heating ladder is the only one that costs a player anything to hold** — it raises the
reactor's draw as well as its output, from a ~56 MW D-D line to ~81 MW. It is also the SECOND of the
three to move a spec field a density curve depends on, which is why `control.lua`'s curve cache is
keyed on confinement time AND heating power; the plant-efficiency ladder is the odd one out there,
reaching `step()` as an argument and never as a spec field (ADR 0020 decision 5). All three resolve
through one rung walk since #424.

## Added since 2026-10-12

One line for each change to a gate, newest last, with its date and its ticket.

- 2026-10-12, #675: `scripts/factorio-lib.ps1` no longer defines `Get-ModLinks`,
  `Get-LocaleFailure`, `Invoke-FactorioStep`, `Invoke-SelfTestHalves` or `Test-SelfTestRunner`.
  Every script that sources it runs the tools submodule's, and `ship-check.ps1 -SelfTest`'s
  `self-test-runner` half runs the canary in the submodule's `scripts/self-test-halves.ps1`.
- 2026-10-12, #658: `ship-check.ps1`'s section 11 is the tools submodule's
  `scripts/markdown-check.ps1 -All` and no longer a table check of its own. It reads every tracked
  `.md` as staged, not as it is on disk. Its three `-SelfTest` halves and its floor of 420 tables
  went with the old section. A row of a quoted table that has lost its `>` is no longer caught. The
  check took 144 s over 114 files on 2026-10-12, inside a `ship-check.ps1` that took 66 to 80 s
  without it by #658's account. A `pre-commit` hook runs the same check on the staged `.md` files.
  Run by hand on 2026-10-12 with a staged page linking to a file git does not track, the hook
  exited 1 and named the page and its line 3. In a scratch repository with the hook and no
  submodule, it said the staged Markdown was NOT checked and the commit went through.
- 2026-10-13, #677: `scripts/locale-check.ps1` is deleted, and the locale check is the tools
  submodule's `scripts/locale-check.ps1`, run by the command in the root `CLAUDE.md` with the three
  mods and `-Prefix rf-`. Run once each on 2026-10-13 against Factorio 2.0.77, before the deletion,
  the two printed the same but for their first line: 135 prototypes on base 2.0 and 165 with
  `-With space-age`. The shared one declares `custom-input` nameless beside `animation`; this
  repository defines no custom input.
- 2026-10-13, #676: the tree viewer, its template and its layout probe are deleted from `scripts/`
  and are the tools submodule's. `ship-check.ps1`'s check of cited `docs/` paths reads `scripts/`
  and `docs/`, so the three research notes those files cite are no longer checked from them:
  `get-history-semantics.md`, `tech-tree-dump-fields.md` and `tree-layout-levers.md`. Nothing
  replaces that. No check was changed, only the section's comments.
- 2026-10-13, #611 and #620: `check-brownout.ps1` asserts what it did. The line its recover check
  prints no longer says "net positive throughout": it says the 300 s are net positive taken
  together, which is what the check measures. One sentence of the report it writes with `-Report`
  no longer places the D-T cells on the clamp. On 2026-10-13 the `recover` cell was net negative
  for its first fifty seconds; `docs/research/d-t-ignition.md` has the reading.

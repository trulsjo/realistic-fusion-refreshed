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

**One workflow runs four checks and four self-tests unattended** (#599, #659, #730).
`.github/workflows/gates.yml` is the only file under `.github/`, and it runs the game-free gates —
the ones that need neither Factorio nor Blender — on a pull request and on a push to `main`: each
`tests/test-*.lua`, `ship-check.ps1`, and `commit-check.ps1` over the commits that event brought.
Since #659 a third job runs the `--self-test` of the same three scripts under `tools/` that
`run-gates.ps1` runs. Since #730 a job runs the shared `pr-body-check.ps1` on a pull request's body,
again when the body is edited, which no other job runs on, and the `pwsh` job, "ship-check and
commit-check", runs that script's `-SelfTest`; `run-gates.ps1` runs neither. A pull request with a
merge conflict gets no run at all, which looks the same as one not yet run. The one other check
nobody starts by hand is the `commit-msg` hook in the Commit messages section, which a clone opts
into and a commit triggers. **What stays manual is the rest of what `run-gates.ps1` runs, and
everything else it leaves out**: the default `load-check.ps1` and each `scripts/check-*.ps1`, then
`load-check.ps1 -FromZips`, `locale-check.ps1`, `name-check.ps1`, the probes and the gates' own
self-tests. A green check says nothing about any of those. **The check is advisory**: `main` has no
branch protection, so a red one blocks no merge.

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
- 2026-10-14, #693: `check-brownout.ps1` asserts what it did and prints one line more. Beside
  its recover check it prints how long the `recover` cell is net negative once the supply returns
  and its worst stretch of the ten-second trace, as a note and not a check, so the
  count of checks is unchanged.
- 2026-10-14, #697: `ship-check.ps1`'s section 6 also fails a `scripts/` or `tools/` path cited in
  prose that does not exist at the root, in one of the three mods or, written from the root, in the
  tools submodule. It reads `scripts/` and the pages under `docs/` that say how things are, and
  leaves out the records: `docs/adr/`, this page, the two review history pages and
  `review-figures.md`. A path with a line number after it is a predecessor's or a third party's,
  and is left alone. Research notes are read, by Truls's choice on #706: they cite 29 probes in
  275 citations. Its pattern run over every file on `main`, records and notes included, found
  sixteen hits. Three were in `ship-check.ps1`'s own comments and five in notes; all eight were
  fixed but one note's predecessor path, cited by line. The other eight are in records. A floor of
  ten citations and the `dangling-script-caught` half hold it.
- 2026-10-14, #703: `ship-check.ps1`'s section 12 holds `docs/agents/plugin-pass.md` to the wrap
  width too, the page that took the plugin pass's half of `code-review.md`'s fourth rule, and the
  sentence it checks in `code-review.md` names the page. No check was changed but the list of files.
- 2026-10-15, #710: the tools pin moved to `94d7c56`, whose Markdown check fails a link whose
  `#fragment` names no heading and reads the links in a table's body rows, which it skipped
  before, so section 11 and the pre-commit hook now fail a `## Current figures` row's dangling
  Section link. Section 10's own anchor code was removed, decided by Truls on 2026-10-15 in the
  session that implemented #710, and recorded on #710's pull request: section 10 still fails a row
  whose Section cell holds no link, and its `figure-anchor-resolves` half became
  `figure-section-linked`, which plants a row with no link beside one with a dangling link.
- 2026-10-20, #730: `.github/workflows/gates.yml` runs the tools submodule's `pr-body-check.ps1`
  on each pull request's body, with `edited` among its triggers and every other job skipping that
  event, and its `-SelfTest` in the `pwsh` job. The pin moves to the commit that gave the
  script its heading check.
- 2026-10-20, #575: `check-pooling.ps1` bounds its three write-shape rows and six writer rows
  below 0.98, as #565 bounded its four bookkeeping rows, and its `all-arrives-refused` half
  requires all thirteen to fail by name under the input-box canary.
- 2026-10-20, #578: `Get-ModTreeFingerprint` and `Test-ModTreeUnchanged` moved from
  `load-check.ps1` to `scripts/factorio-lib.ps1`, and the `-SelfTest`s of `check-pooling.ps1` and
  `check-hc.ps1` now fail when a file under the mod directories changed during the run, as
  `load-check.ps1`'s did. `run-gates.ps1 -SelfTest` gained `exit-code-names-failure` and
  `exit-code-clean`, which run the script as its own process over stand-in gates.
- 2026-10-21, #740: both reactors' plasma box is `input` (ADR 0040), so every gate that builds a
  reactor now runs on that box. `check-breeding.ps1`'s help names the box as `input`; nothing it
  asserts changed.
- 2026-10-21, #741: `check-pooling.ps1` asserts shared feed and unshared heat in 65 checks, where
  it characterised the `input-output` box in 125. It gains a heater-fed `feed` cell and a `full`
  cell built 2H1 that reaches a full line inside the run (#574), and loses the mixing-loss,
  write-shape, writer-count, ramp and probe rows. Its `-SelfTest` gains
  `shared-heat-refused`, which loads a canary putting the `input-output` box back and requires
  the ten rows that say heat is not shared to fail by name; it replaces `all-arrives-refused`.
- 2026-10-22, #751: `load-check.ps1` holds every committed `models/*/geometry.json` against the
  loaded dump, through the comparison its rendered-art check gives a manifest, so a machine with a
  geometry and no render is held too. Three were held by nothing until then: the aneutronic
  reactor, the direct energy converter and the lithium blanket. Its `-SelfTest` gains
  `stale-geometry`, which plants a copy of the first committed geometry with one connection's
  `production_type` flipped and requires a row on that machine's connections and no other. It
  cannot see a geometry nobody committed, nor a model built from a geometry since regenerated:
  `models/render.py` compares that hash.
- 2026-10-22, #756: `ship-check.ps1` section 13 reads each `scripts/*.ps1` that calls
  `Invoke-SelfTestHalves`, takes its half names from the `@{ Name = '...'; Body` entries it hands
  the runner, and fails each half its `.PARAMETER SelfTest` help leaves out when that help names at
  least one; it prints the gates it skipped for naming none, `name-check.ps1` and `ship-check.ps1`
  on that day, and a floor of eight gates holds the scan. `run-gates.ps1`'s help names
  `failing-gate-reported` and `missing-executable-fails`. Its `-SelfTest` gains
  `unnamed-half-caught` and `help-naming-none-skipped`. It cannot see whether what the help says of
  a half it names is true, nor prose that describes kinds of half: that stays the reviewer's.
- 2026-10-23, #762: `ship-check.ps1` section 14 fails a line that diffs or logs against the local
  `main` (`main...HEAD`, `main..HEAD`) or fetches into it (`main:main`) in a fixed list, the two
  review skills, both `CLAUDE.md` and `scripts/run-gates.ps1`, and fails a missing one of those.
  Run over those five files as they were before #758 merged, at 3d04085, its pattern finds nine
  lines: the seven in the two skills that hold one of the three forms, `CLAUDE.md`'s
  markdown-only test and `run-gates.ps1`'s. Its `-SelfTest` gains `local-main-read-caught` and
  `origin-main-read-passes`. It cannot see a base written another way, such as
  `git merge-base main HEAD` or a bare `git diff main`, nor any file it does not list.
- 2026-10-25, #765 and #753: the tools pin moves from `6385486` to `e68c331`. Wherever the body
  check runs, in `gates.yml` and before each `gh pr create` and `gh pr edit`, it now also fails a
  body missing `**Before:**` or `**After:**` under `## Evidence`, or `**Door:**` or
  `**Blast Radius:**` under `## Merge Danger`. The mods the tools scripts write for the game
  declare line 2.1. At `6385486` a 2.1.23 game refused `tree-viewer.ps1`'s exporter,
  `treeview-history`, and the locale check's self-test mod `localecheck-good`, each for declaring
  2.0, and `load-harness.ps1 -SelfTest` failed the four cases that load one, printing no reason
  from the game. `markdown-check.ps1`'s `-All` and no-argument forms and `commit-check.ps1`'s
  forms print the same as before. `load-harness-lib.ps1`, `pack-mods.ps1` and `mod-info.ps1`,
  which both of those dot-source, change in comments only. The locale check's run names no
  bundled mod as "none (base only)", where it said "none (base 2.0 only)".
- 2026-10-25, #768 and #777: `scripts/factorio-lib.ps1`'s rig Lua gains `rf_fluidbox`, 2.0's
  `LuaFluidBox` on 2.1.23's index methods, and `rf_plasma_feed`, which feeds a reactor's box
  through a rig-only `rf-pump` on a void energy source, declared beside the infinity pipe by `Write-PlasmaFeed`.
  On 2.1.23 an infinity pipe in `at-least` or `add` mode resets a segment at another temperature
  to its filter, and the reactor's box shares the segment on its face, so a feed bolted to it
  undoes every step. `check-blanket.ps1` is ported onto both and passes on 2.1.23, 55 checks and
  no failures. `check-aneutronic.ps1`, `check-breeding.ps1`, `check-buffer.ps1`, `check-d-t.ps1`,
  `check-efficiency.ps1` and `check-observability.ps1` feed through `rf_plasma_feed` too, and the
  buffer, efficiency and observability rigs load the rig Lua for it. `check-buffer.ps1` and
  `check-efficiency.ps1` build their pumped feeds on 2.1.23 and then stop on their own
  `fluidbox` reads, `check-buffer` in `on_init` (run 2026-10-25) and `check-efficiency` on its
  first tick (run 2026-10-26). The other four stop before any tick runs: three on a `fluidbox` read in
  `on_init`, and `check-observability.ps1` at load, on a prototype's `.volume`. Those reads are
  #769 to #771's, so none of the six has fed a reactor through it yet.
- 2026-10-25, #767: every mod a gate here writes for the game, each `check-*.ps1` rig and the
  canaries of `load-check.ps1` and `check-hc.ps1` included, declares `factorio_version` 2.1 and
  `base >= 2.1.23` where it declared 2.0 and `base >= 2.0.77`. `load-check.ps1`, `name-check.ps1`,
  `check-brownout.ps1`, `check-d-t.ps1` and `check-pooling.ps1` print "none (base 2.1 only)"
  when no bundled mod is enabled. `name-check.ps1`'s help says a set pinned at a 2.0 release does not load
  beside the mods, so its `-AlsoModDirectory` lanes wait on #772. On 2.1.23 the default
  `load-check.ps1`, its `-FromZips` and `name-check.ps1` pass; no gate's `-SelfTest` has been run
  on 2.1.23. Twelve of the 24 gates `run-gates.ps1` runs fail there, each on its own 2.0 read,
  until #769 to #771.
- 2026-10-26, #787: `run-gates.ps1` and the workflow's tools job run a fourth tool's
  `--self-test`, `tools/review-coverage.py`'s, which builds a repository in a temporary directory.
  It proves that `check` names a commit no review was handed and exits 1, that a recorded reword
  covers the reworded commit, and that a subject recorded under another branch covers nothing.
- 2026-10-26, #769: `check-aneutronic.ps1`, `check-breeding.ps1`, `check-d-t.ps1`,
  `check-confinement.ps1` and `check-heating.ps1` read their boxes through `rf_fluidbox` and a
  box prototype's volume through `get_volume()`, and pass on 2.1.23, with `check-blanket.ps1`,
  which #768 ported. The confinement rig loads the rig Lua for it. What each asserts is unchanged.
- 2026-10-26, #770: `check-brownout.ps1`, `check-buffer.ps1`, `check-containment.ps1`,
  `check-efficiency.ps1` and `check-hc.ps1` are ported the same way, and pass on 2.1.23.
  `check-efficiency.ps1` empties a reactor's energy box by reading it and clearing it, since 2.1's
  `remove_fluid` takes a box index. `check-hc.ps1` reads a generator's fluid usage and power output
  through `get_fluid_usage_per_tick()` and `get_max_power_output()`, and `check-containment.ps1` a
  recipe's category through `categories`. `check-buffer.ps1` holds the two assembling machines to
  16/15 of their declared buffer, like every other non-accumulator, since on 2.1.23 they hold
  10,666,666.67 J where on 2.0.77 they held their usage plus drain times 16/15.
- 2026-10-26, #771: `check-observability.ps1` passes on 2.1.23 as #768 left it. `check-pooling.ps1`
  asserts ADR 0042: on `pair`, `trio`, `five`, `bare`, `piped`, `feed` and `full` every reactor
  reads the westmost's amount and temperature to a relative 1e-6, the unpowered ones included, and
  `mix` reads one temperature as soon as one end is written. The floor rows, `feed`'s unshared-heat
  row and the nine bookkeeping rows are gone: the captured step, and for each of `solo`,
  `solopipe`, `bare` and `piped` its buffer row and its share kept. Its `-SelfTest` half `split-runs-refused` runs the
  rig with `-BreakRuns`, which leaves one pipe out of every bridge, and requires the seven one-pool
  rows to fail by name. It replaces `shared-heat-refused`, whose `input-output` canary stood for a
  box that shares heat, which on 2.1 the shipped box does too. `run-gates.ps1` passes all 25 gates
  on 2.1.23.
- 2026-10-26, #794: every `scripts/check-*.ps1` that dot-sources `scripts/factorio-lib.ps1` leaves
  what it printed in the git-ignored `.rig-reports/`, through `Start-RunReport`, which was
  `Start-ProbeReport` and still keeps a probe's in `.probe-reports/`. Rigs now print under the
  invariant culture, as probes do since #577. `ship-check.ps1` section 15 fails a rig that does not
  dot-source the library, and runs a stand-in rig that prints a line and throws in a scratch
  directory, which must leave a report holding its head, its line and its throw. Its `-SelfTest`
  halves `unsourcing-rig-caught` and `unreported-run-caught` prove each check can fail.
- 2026-10-27, #810: `run-gates.ps1` runs `models/test_rf_blender.py` as a gate of its own, named
  `test_rf_blender`, with `python` from PATH and no argument, after the four tools' self-tests;
  `gates.yml` runs it as a step of the tools job. It is a plain script that exits 0 or raises, so
  neither runner's `--self-test` loop could hold it. It is #800's footprint-edge check's
  self-test since #809, and before that it had no runner.
- 2026-10-27, #812: `ship-check.ps1` section 16 and `run-gates.ps1` take a fingerprint of every
  tracked file and of the index, through `Get-TrackedTreeFingerprint` in
  `scripts/factorio-lib.ps1`, before they read anything and again at the end, and fail the run
  naming each path that differs, whatever the sections or gates found; `run-gates.ps1` also
  compares after each gate and names the first gate after which it differed. Git-ignored files
  are not in it. The `-SelfTest` halves `tree-change-caught` and `unchanged-tree-passes` in
  `ship-check.ps1`, and `tree-change-fails` and `ignored-write-clean` in `run-gates.ps1`, prove
  each in both directions on a scratch repository, and `tree-change-fails-run` runs
  `ship-check.ps1` as its own process watching one it edits before section 1, which must fail on
  that file alone.
- 2026-10-27, #813: `gates.yml` also runs on `workflow_dispatch`, started with
  `gh workflow run gates.yml --ref <branch>`, and runs there what a push to `main` runs less the
  commit check, which has no range on that event. The body job runs on a pull request alone, as
  before. GitHub reads the trigger from the copy of the workflow on the branch handed, so on
  `main` the dispatch answers `HTTP 422` until the trigger is merged.
- 2026-10-28, #817: `ship-check.ps1` section 17 fails a word of 7 to 40 hexadecimal characters,
  in the prose section 9 reads and outside the records section 6's `$RECORDS` names, that names a
  commit here which `origin/main` does not reach, with its file and line. A shallow clone or one
  with no `origin/main` fails the section. It stands above section 16, which runs last. Its first
  run, on 2026-10-27, over `main` at `085cf8a` and the branch's prose, which adds no hash to a live
  page, failed nothing. Planted in a worktree, `a7d82ab`, the pre-reword
  copy #815 found, failed on its line and `d2bcdc3` beside it passed. A fresh clone holds no commit
  that no ref reaches, so the workflow passes such a copy as naming nothing; the halves
  unreachable-hash-caught and record-hash-not-read prove the two directions.
- 2026-10-28, #803: `models/test_rf_blender.py` also pins the kit's first arithmetic: how
  `rf_blender.bundle` lays a loom's cables round its centreline, `rf_blender.loom_spread`, and
  that `rf_blender.CABLE_COLOURS` holds only cable rows. It renders nothing, so it cannot see
  whether a loom reads.
- 2026-10-28, #802: `models/test_rf_blender.py` also pins `rf_blender.panel_grid`, how a face
  is cut into inset plates, and that `rf_blender.check_inset` refuses a seam under the cut floor,
  a seam shallower than it is wide and a plate under the raised floor, naming the part.
- 2026-10-28, #804: `models/test_rf_blender.py` also pins the three placements a repeated
  module takes, `rf_blender.ring`, `row` and `stack`, `rf_blender.casing_arc` and
  `rf_blender.casing_points`, `rf_blender.least_gap`, which measures point to point between
  neighbouring parts as placed, a ring's last against its first included, and that `rf_blender.check_gap` refuses a slot under the
  cut floor or shallower than it is wide.
- 2026-10-29, #803: `models/test_rf_blender.py` also pins that `rf_blender.bundle`'s `phase`
  turns a bundle at its start, so two looms on one curve wind differently (Truls, on the
  exchanger's frame).
- 2026-10-29, #825: `models/test_rf_blender.py` also pins `rf_blender.stream`: on a simulated
  build, a part's draws are the same whatever other part is added before or after it, the
  machine's seed and the part's name both reach its stream, and one draw is pinned to a number
  under the system's Python. It also fails when any file under `models/` but
  `models/rf_blender.py` imports `random`, or when that file uses it for anything but
  `random.Random`. It cannot see what a build script draws from one stream, or in what order.
- 2026-10-29, #827: `models/test_rf_blender.py` also fails when either rendered machine's build
  script gives a part that draws a name built from an `enumerate` or `range` counter, as an
  f-string, a `+` or `%` on a string, or a `.format`. Which calls draw is worked out from `stream`
  and `bevel` through the helpers that reach them, a call passing `bev=0` excepted, so `seam`
  draws nothing. It cannot see a counter that reaches the name through another variable, so it
  cannot tell a part named for where it stands from one named for its rank, nor a loop over
  anything else, such as `zip` with a string of letters.
- 2026-10-30, #805: `scripts/ship-check.ps1` section 18 fails each file git tracks, or would add,
  in a directory under `models/` that is not `build.py`, `geometry.json`, `textures.json`, the
  model's own `.blend` or a `.jpg`, `.jpeg` or `.png` whose record in `textures.json` gives the
  licence `CC0-1.0`, an https source and the file's own sha256; it also fails a record with no
  file. Its `-SelfTest` plants one of each fault (`unproven-texture-caught`) and a directory that
  passes (`proven-texture-passes`). It cannot see whether the source page really offers that file
  under CC0, an image under `models/` outside a model directory, or an image packed into a
  `.blend`, which `models/render.py` refuses. `models/test_rf_blender.py` also holds
  `rf_blender.texture_record`, which the build and the render call, to the same record.

# Realistic Fusion Refreshed — agent notes

Factorio mod project. Long-term goal: finish **Realistic Fusion 2.0**. See `README.md` for what the
mod is and where it came from; this file is how to work in the repo.

## State

**In development.** `realistic-fusion-refreshed-core` and `realistic-fusion-refreshed` load against
Factorio 2.0.77, on top of `realistic-fusion-refreshed-assets`, which holds every sprite the two of
them draw and nothing else (ADR 0023). All four of ADR 0010's reactions are playable: the
water-to-deuterium extraction chain, D-D reactors that breed their own tritium and helium-3, D-T
fusion burning it, lithium blankets breeding more, and an aneutronic tier running D-He3 and He3-He3
in a second reactor through a direct energy converter. **Every prototype ADR 0010 names for Power
now exists** — thirteen entities and seven technologies, high-capacity steam equipment included —
**plus three research ladders that ADR 0010 did not name**: confinement time in three rungs (#53,
ADR 0024), plant efficiency in three (#96, ADR 0020) and plasma heating in five (#425, ADR 0038).
All three are neutronic only and all three are per force. **All three fluid families are contained**
as of 2026-09-07 (#86, #87): plasma and the two reactor energies each carry a `connection_category`
of their own, so no pipe, tank, wagon or pump a player can build touches any of them, and an
exchanger or a converter bolts straight onto a reactor face and chains to its neighbours (ADR 0018,
ADR 0031). **Every balance number is still provisional**, and coverage is not the same as being
finished: nothing here has been played for longer than a rig runs.

**Verification here is by running the game, not by reading.** Run the gates rather than reasoning
about whether a change is safe. What each proves, in a line:

- **`tests/test-*.lua`** cover the pure simulation outside Factorio.
- **`scripts/load-check.ps1`** creates a real map and asserts against it, and is where the
  invariants tying the simulation to the prototypes are enforced. It also fails when a rendered
  machine's `manifest.json` disagrees with the live prototype's footprint or connections, when a
  socket is drawn at a height no vanilla pipe would meet, and when a piece of a socket is not drawn
  as far above its axis as below it or is not the width the model recorded.
- **Each `scripts/check-*.ps1`** creates a real map and asserts against it.
- **`scripts/ship-check.ps1`** runs no game. It checks the claims the mods make about themselves:
  the two statements ADR 0003 and ADR 0006 oblige them to make, the credits, the licence files and
  the assets dependency floor (ADR 0023). It also checks prose no other gate can see: that a script
  with a `.SYNOPSIS` answers `Get-Help`, the two citation rules under Conventions, the rows of a
  research note's `## Current figures` table, what the shared Markdown check reads in every
  tracked `.md` as staged (#658), and the width of the files `docs/agents/code-review.md` names as
  wrapped.
- **The shared locale check and `scripts/name-check.ps1`** only dump prototypes and create no
  map, so a pass there says nothing about runtime.

**The three art gates inside `load-check.ps1` need Python on PATH, and the two that read sprites
need `pillow` and `numpy` in it.** A missing one is a failure with a message, not a skip.

**[`docs/agents/state-detail.md`](docs/agents/state-detail.md) has what this section carried until
#591**: when each gate gained each check and by which ticket, what each check cannot see, how the
self-tests prove them, what the harness shares, the timings of `run-gates.ps1`, and three facts
about the research ladders. Read it when a gate's pass or failure has to be interpreted, when a
gate or its self-test is being changed, and when a sentence here is wanted with its date or its
ticket. A change to a gate adds a dated line at the foot of that page, and changes a line here
only when what the gate proves in a line has changed.

**`load-check.ps1` loads the mods two ways, and the default is not the player's.** Without arguments
it junctions the repository's directories in, so the game reads the working tree; `-FromZips` builds
the distributable zips with the shared packer and loads those instead, resolving every sprite
against the unpacked archive rather than against the repo. A file that resolves through a junction
and never reaches a zip passes the default and breaks a player's game. Use `-FromZips` before
anything that ships.

**Before building the zips or anything that ships: read
[`docs/agents/shipping.md`](docs/agents/shipping.md)**, which has the commands for the packer and
for the locale check. Neither is this repository's, and no gate runner starts the locale check.

**Every gate here needs the submodule initialised**, the one that starts no game (`ship-check.ps1`)
included: `git submodule update --init`, the same step the commit hook asks for. The harness under
`load-check.ps1`, the packer, the fetcher of the third-party sets, the locale check, the Markdown
check and the commit check are `vendor/grado-factorio-tools`'s; the other checks are this
repository's. The sets are pinned in
`scripts/mod-sets.psd1`, and the fetcher caches under `.mod-cache/<set>` of the directory it runs
in, so run it from the repository root.

**`scripts/run-gates.ps1` runs them all in one step** (#567): the Lua suites, the `--self-test` of
three scripts under `tools/` that are not gates and that nothing else checks, `ship-check.ps1`, the
default `load-check.ps1` and every `scripts/check-*.ps1` it finds, one at a time, one line per
gate, exiting non-zero and naming each gate that failed. **Run it on a branch that combines more
than one ticket, before the review**, and **before or after a subagent fan-out, not during one**
(#617). It runs no probe, no gate's `-SelfTest`, and not `load-check.ps1 -FromZips`, the shared
`locale-check.ps1` or `name-check.ps1`.

**A markdown-only branch runs `ship-check.ps1` alone**, however many tickets it combines (decided
by Truls, 2026-10-07, #618). A branch is markdown-only when every path
`git diff --name-only --no-renames main...HEAD` prints ends in `.md`; `--no-renames` is there so
that a file renamed to `.md` prints the path it had. One path that does not end in `.md`, a
`.gitignore` or a comment-only edit to a script included, and the branch is not markdown-only:
the paragraph above applies to it as it would to any other.
The exception rests on one fact: no other gate reads a `.md` file, checked 2026-10-07. A gate
that starts reading one ends it.

**One workflow runs the game-free gates unattended** (#599, #659). `.github/workflows/gates.yml`
is the only file under `.github/`, and it runs on a pull request and on a push to `main`: each
`tests/test-*.lua`, `ship-check.ps1`, `commit-check.ps1` over the commits that event brought, and
the `--self-test` of the same three scripts under `tools/`. A pull request with a merge conflict
gets no run at all, which looks the same as one not yet run. **Everything else `run-gates.ps1`
runs, and all of what it leaves out, stays manual**, and a green check says nothing about any of
it. **The check is advisory**: `main` has no branch protection, so a red one blocks no merge.

`scripts/probe-*` are **not** gates, and `run-gates.ps1` runs none of them. A probe asserts nothing
and answers a question a decision is waiting on — exit 0 means it ran and reported, never that the
answer was the hoped-for one. Its findings belong in `docs/research/`, and it stays committed so the
next engine version can be asked the same question. Since #589 a `probe-*.ps1` that sources
`scripts/factorio-lib.ps1` leaves what it last printed in the git-ignored `.probe-reports/`, in a
file named for the probe and its arguments: a figure in a note is checked against that file.

## The rule that matters most here

**Most of the big decisions are open, and they are Truls's to make.** That includes which upstream
base to build on, whether the four-module split survives, scope, mod compatibility targets, and
whether Space Age ever becomes a first-class target rather than merely a tolerated one.

Three of the decisions this section used to list are settled, and are recorded here so nobody
reopens them by accident:

- **The licence is LGPLv3** — see `LICENSE`, changed from The Unlicense on 2026-08-16, on the
  grounds that the mod is largely Krastorio 2's resources and code and takes only ideas from the
  original.
- **The published name is Realistic Fusion Refreshed** (ADR 0017, superseding ADR 0009). The `rf-`
  prototype prefix is unaffected.
- **The v1 target is the Factorio 2.0 base game, with Space Age tolerated but not integrated**
  (ADR 0003). What stays open is whether that ever becomes first-class support, which is the item
  left in the list above — not the v1 target.

Do not settle any of them as a side effect of doing something else — no "I picked X to get started".
If a task cannot proceed without one, say so and ask. Recording options with trade-offs is welcome;
choosing between them is not.

## Factorio specifics

- Mods are **Lua**. The API has **three stages**: `settings` and `prototype` run at start-up,
  `runtime` runs during gameplay. Know which stage code belongs to before writing it.
- API docs are published **per game version** at <https://lua-api.factorio.com/>. Check claims
  against the version being targeted rather than from memory. Two of the three older predecessors
  are **1.1**-era — the original and the four-module redesign, whose "2.0" is its own version number
  — and only Durikkan's port targets Factorio 2.0. The 1.1→2.0 break therefore runs straight through
  the material this project builds on, which is the whole reason the work exists.
- `/stable/` and `/latest/` move, and `latest` is the **experimental** build. Pin an explicit
  version (e.g. `/2.0.77/`) when recording a fact.

## Upstream material

**Before taking any file, code or art, from a predecessor or from upstream: read
[`docs/agents/upstream-material.md`](docs/agents/upstream-material.md).** Everything is governed
per directory, Lua included, and that page has the rules and how each predecessor marks its
material. Two rules are kept here because they rule material out outright:

- **NonCommercial or NoDerivatives material is never lifted**, whatever its source. That rules out
  the redesign's `RealisticFusionCore/electric-boiler/` and `angels-numerals/` outright.
- **Take no asset from UFP: Ultimate Fusion Power Fixed** (`ufpFixed`, `ultimateCoreLib`,
  `ultimateCore`, `ultimateCore-2`, `ultimateCore-3`), any of the five, including
  `ufp_boiler-*.png`, which is the CC BY-NC-ND `electric-boiler/` art upscaled. Reading its Lua for
  2.0/2.1 prototype patterns is fine. Checked 2026-08-19; see ADR 0001.

## Conventions

- Default branch `main`. Commit email is set per-repo — do not change it.
- `CLAUDE.local.md` is personal and git-ignored. Never commit it, and never move its contents into a
  tracked file.
- **Cite our own code by symbol, never by line number** — the function, field, constant or
  prototype, with a repo-relative path, because there are two `entities.lua`. A comment with no
  symbol is cited by a quoted fragment of its own words. Predecessor, vanilla and third-party
  citations keep their line numbers; we never edit those trees. Since #303 `scripts/ship-check.ps1`
  gates **two** of the three shapes this takes — a path with a line number on it, and a backticked
  `:155` continuation inheriting a path named earlier on the same line — across every tracked `.md`,
  `.lua`, `.ps1`, `.py` and `.js`. It stays blind to "lines 196-197" written out in prose, to a
  continuation whose path is on an earlier line, and to one written without backticks; and a
  **mod**-relative path like `prototypes/entities.lua:119` still names two files, so only a citation
  anchored at the repo root is actually gated. See `docs/adr/0032-prose-cites-code-by-symbol.md` and
  the script's section 7.
- **Cite a `-SelfTest` half by its name, never by its position** (#411, #416). A gate declares its
  halves by name where they run and `Invoke-SelfTestHalves` numbers them as it goes, so inserting
  one moves the number printed for every half after it while the names stay put — and a sentence
  pointing at a position still reads as true once it means a different half. `ship-check.ps1`
  section 9 gates the rule across the same tracked `.md`, `.lua`, `.ps1`, `.py` and `.js` files, and
  its own `-SelfTest` proves it fires and that it leaves a named citation alone. **It reads prose
  only** — a whole markdown file, and in code the lines that are comments, minus a markdown fence,
  where a pasted run lives — so a citation in a printed string, in a fenced block, in a trailing
  comment after code, or written without the word ("the sixth", "the one before the stall detector")
  is not seen. The section comment carries the full list of what it cannot see.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/) with a [gitmoji](https://gitmoji.dev/)
prefix. One format, no exceptions:

```
<emoji> <type>(<scope>): <subject>

<body>

<footer>
```

**The rules live in
[`vendor/grado-factorio-tools/docs/commit-convention.md`](vendor/grado-factorio-tools/docs/commit-convention.md)**
— the type table, the situational emoji, the subject and body limits, and what the check is blind
to. That page is shared with `grado-factorio-modpack` and the tooling repo, so a rule change is one
edit instead of three. If the submodule is not initialised, read it at
<https://github.com/trulsjo/grado-factorio-tools/blob/main/docs/commit-convention.md> — but that
shows `main`, which may be ahead of the commit this repo has pinned.

Three things are this repository's own, because all three are its domain rather than shared
mechanics:

- **Scope vocabulary.** Use the module (`core`, `power`, `weaponry`, `antimatter`) or the area
  (`data`, `runtime`, `settings`, `locale`, `graphics`, `repo`).
- **What counts as a breaking change.** Here it is anything that breaks an existing save or a mod's
  public interface. **Save compatibility is the one that will bite: it breaks silently and players
  find out, not the build.** The `!` and the `BREAKING CHANGE:` footer are the shared mechanism;
  what triggers them is this repo's own.
- **What a body has to name.** Reference the Factorio API version when a change depends on one, and
  when code is lifted from a predecessor mod, name the author and the mod there (see Upstream
  material above).

Example:

```
✨ feat(power): add deuterium extraction from water

Implements the first step of the fuel chain so the reactor
prototypes have an input to consume. Recipe balance is provisional
and not yet checked against the 1.1 original's numbers.
```

**A hook checks all of this, and it is not installed by default.** `.githooks/commit-msg` runs the
shared check on the message before the commit is written. Git tracks neither `.git/hooks` nor a
submodule's contents, so every clone opts in twice:

```
git submodule update --init
git config core.hooksPath .githooks
```

**Skipping either step is loud rather than silent.** The hook says the message was not checked and
lets the commit through, instead of passing everything quietly — the posture [ADR
0001](https://github.com/trulsjo/grado-factorio-tools/blob/main/docs/adr/0001-siblings-consume-this-repo-as-a-submodule.md)
in the tooling repo requires, and what makes the second step safe to ask for.

**A clone that skips both is still checked, later** (#599). The workflow in the State section runs
the same check over a pull request's commits and over each push to `main`, so the convention no
longer depends on every clone opting in. The hook is still the only thing that stops a bad message
before it is written; the workflow reports one after it is pushed.

**A second hook, `.githooks/pre-commit`, reads the staged Markdown** (#658). It runs the tools
submodule's `scripts/markdown-check.ps1` on the staged `.md` files as staged, and refuses the commit
on emphasis or a code span left open, a table row whose column count is not its header's, or a link
to a file git does not track. The same two steps install it, and a clone that set the hooks path and
has no submodule is told the Markdown was not checked. `ship-check.ps1` runs the same check over
every tracked `.md`, so the workflow holds a clone without the hook to it.

**The `commit-msg` hook exists because the wrap rule had rotted.** Measured on 2026-09-06 by
`commit-check.ps1 -Range '-50 main'`: 21 of the last 50 commits fail, on 183 body lines and 5
subject lines over 72, the longest subject being 82. History is left alone; the hook stops it
growing. `-Range origin/main..HEAD` checks a branch before a pull request, and `-SelfTest` proves
the check can still fail.

**The check moved out of this repository on 2026-09-21** and is now resolved from the tooling repo
as a pinned submodule. It was written here, and the copy that was here is deleted rather than left
to drift. Bumping the pin is a deliberate commit, so a change there cannot alter this repo's gate
until this repo opts in.

## Agent skills

### Issue tracker

GitHub Issues on `trulsjo/realistic-fusion-refreshed`, via the `gh` CLI. See
`docs/agents/issue-tracker.md`.

### Triage labels

The five canonical roles, unchanged: `needs-triage`, `needs-info`, `ready-for-agent`,
`ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context — `GLOSSARY.md` and `docs/adr/` at the repo root, created lazily. See
`docs/agents/domain.md`.

### Rendered art

`/render-machine rf-<machine>` renders a machine's sprite set from its Blender model, or
regenerates the model from its look note. See `.claude/skills/render-machine/SKILL.md`; the
vocabulary is `GLOSSARY.md`'s Art section.

### Code review

**`docs/agents/code-review.md` states this repository's four review rules,
`docs/agents/plugin-pass.md` holds the plugin pass's half of the fourth, and this file states none
of them** (#630). Read the section named when its condition holds:

- **A branch is ready for its pull request, or an implement skill says to close out with
  `/code-review`**: *A review before the pull request, and the plugin pass after it*, for the
  pre-PR review. `/pre-pr-review` runs it.
- **Before the first commit on a branch, and each one after**: the same section, for a body that
  says why, from the ticket, and leaves what to the diff (#671).
- **A pull request has been opened**: the same section, for who confirms the plugin pass's fixes,
  and `docs/agents/plugin-pass.md`, which it points at, for the pass and the row it adds to each
  table of `docs/agents/review-figures.md` (#703). `/plugin-pass` runs it (#626).
- **The last fix on a branch has been committed, the plugin pass's included**: *Review the prose,
  not only the code*, for what is read again before the body is last edited (#663). Step 7 of
  `/pre-pr-review` carries it out.
- **A review's findings are about to be reported or posted**: *The verdict sorts the comment, not
  the report*.
- **A change is being reviewed, a fix a review asked for is being written, a ticket is being
  implemented, or a ticket or a retrospective's candidate is about to be published**: *Review the
  prose, not only the code*.
- **A review pass is about to edit the working tree, or a gate fails once and passes on every
  re-run**: *A review that plants takes its own worktree*.
- **A rule there is being changed or revisited**: its head, for the two pages that hold who
  decided each rule and what each was measured on (#672).

Before a review of a branch that combines more than one ticket, run `scripts/run-gates.ps1` on it,
or `scripts/ship-check.ps1` alone when the branch is markdown-only; the State section says what
`run-gates.ps1` runs and defines markdown-only.

## Code indexes

Two optional indexes of this repository exist on a machine that has built them. Both directories
are git-ignored, so a fresh clone has neither, and neither is a required first step (#598).

- **graphify** (`graphify-out/`) answers a question that spans many files:
  `graphify query "<question>"`, `graphify path "<A>" "<B>"`, `graphify explain "<concept>"`.
  Run `graphify update .` before a query; it re-extracts code files only, with no LLM call.
- **graft** (`graft/`) returns ranked nodes with their `file:line`, and who calls a symbol:
  `graft ask "<query>"`, `graft callers <symbol>`. Both check the graph's freshness themselves
  unless given `--no-refresh`.

**Do not re-run graphify's Claude install (`graphify claude install`) in this repository.** It
looks for a heading that is exactly `## graphify`, and finding none it appends its own section
below this one, telling the reader to query first, and installs its hook in
`.claude/settings.json`.

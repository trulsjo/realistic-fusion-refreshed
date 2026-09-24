# Realistic Fusion Refreshed — agent notes

Factorio mod project. Long-term goal: finish **Realistic Fusion 2.0**. See `README.md` for what the mod
is and where it came from; this file is how to work in the repo.

## State

**In development.** `realistic-fusion-refreshed-core` and `realistic-fusion-refreshed` load against
Factorio 2.0.77, on top of `realistic-fusion-refreshed-assets`, which holds every sprite the two of
them draw and nothing else (ADR 0023). All four of ADR 0010's reactions are playable: the
water-to-deuterium extraction chain, D-D reactors that breed their own tritium and helium-3, D-T
fusion burning it, lithium blankets breeding more, and an aneutronic tier running D-He3 and He3-He3
in a second reactor through a direct energy converter.
**Every prototype ADR 0010 names for Power now exists** — thirteen entities and seven technologies,
high-capacity steam equipment included — **plus three research ladders that ADR 0010 did
not name**: confinement time in three rungs (#53, ADR 0024), plant efficiency in three (#96,
ADR 0020) and plasma heating in five (#425, ADR 0038). All three are neutronic only and all three
are per force. **The heating ladder is the only one that costs a player anything to hold** — it
raises the reactor's draw as well as its output, from a ~56 MW D-D line to ~81 MW. It is also the
SECOND of the three to move a spec field a density curve depends on, which is why `control.lua`'s
curve cache is keyed on confinement time AND heating power; the plant-efficiency ladder is the odd
one out there, reaching `step()` as an argument and never as a spec field (ADR 0020 decision 5).
All three resolve through one rung walk since #424. **All three fluid families are contained** as of 2026-09-07
(#86, #87): plasma and the two reactor energies each carry a `connection_category` of their own, so
no pipe, tank, wagon or pump a player can build touches any of them, and an exchanger or a converter
bolts straight onto a reactor face and chains to its neighbours (ADR 0018, ADR 0031).
**Every balance number is still provisional**, and coverage
is not the same as being finished: nothing here has been played for longer than a rig runs.

Verification here is by running the game, not by reading. `tests/*.lua` cover the pure simulation
outside Factorio; `scripts/check-*.ps1` and `scripts/load-check.ps1` create real maps and assert against
them, and `load-check.ps1` is where the invariants tying the simulation to the prototypes are enforced.
Since #250 it also fails when a `graphics/rendered/<machine>/manifest.json` disagrees with the live
prototype's footprint or connections, by asking `tools/extract-geometry.py` again, and since #344
when a socket is DRAWN at a height no vanilla pipe would meet, by reading the
sheet with `tools/check-socket-height.py` — which since #356 also fails when `rf_blender.SOCKET_Z`
itself stops predicting the height vanilla draws its pipe at, so a wrong constant is caught before
anything is rendered from it. **That gate covered only a socket a player can plumb until #392**,
which levelled every contained socket to the same height (ADR 0036) and took the filter out; it now
measures nine sockets across the two rendered machines where it measured six. Since #373 a **second** sprite gate sits beside it:
`tools/check-socket-parts.py` takes the same strip apart and fails when a piece of a socket is not
drawn as far above its axis as below it, or is not the width the model recorded drawing it. It
covers CONTAINED connections as well as plumbable ones, because that is a claim about the renderer
rather than about meeting a pipe, and it reads no vanilla sheet — vanilla's barrel is symmetric, so
"proud by the same amount above and below" is the same assertion. **All three need Python on PATH,
and the two sprite gates need `pillow` and `numpy` in it** — the only third-party Python this repository's gates require, and the one
prerequisite that is neither Factorio nor Blender. A missing one is a failure with a message, not a
skip. **The categories on a manifest's connections are compared as a subset, not for equality**,
and the #250 gate is the only one that looks at them: an addition is allowed because a coexisting mod writes one
legitimately — Krastorio 2 puts `kr-steel-pipe` on machines it never heard of — while a category being
taken away is reported. The containment floor covers only what carries a category; it skips any
connection left `default`, which since #86 is three of the heat exchanger's six — its water pair and
its steam outlet — where before it was all six. (`probe-connection-categories.ps1` reports on
the same shape, but a probe asserts nothing.) The `added-category` and `replaced-category` halves
of `-SelfTest` are the canaries, one for each direction, and `added-category`'s victim is chosen as
an UNCONTAINED connection for exactly that reason. **A half is cited by name, never by ordinal**
(#411, #416): a half inserted above one renumbers every half after it, and a sentence pointing at
the wrong half still reads as true.
`scripts/locale-check.ps1` and `scripts/name-check.ps1` only dump prototypes and create no map, so a
pass there says nothing about runtime. `scripts/ship-check.ps1` runs no game at all — it is the
check about the claims the mods make about themselves: the two statements ADR 0003 and ADR 0006
oblige them to make, the credits, the licence files, and since ADR 0023 the assets dependency floor.
That last one is the only invariant here that **cannot** fail on this machine — the dev loop
junctions the current assets mod, so every sprite path resolves whatever the floor says, and a stale
floor fails only in a player's log.
Since #151 it also asserts one thing that is not a claim about the mods at all: that every
script in `scripts/` which declares a `.SYNOPSIS` answers `Get-Help`. It lives there because it
has the same shape as the rest — prose no other gate can see, checkable without starting a game.
Since #416 it has a `-SelfTest` of its own, which is new: it proves the shared self-test runner in
`factorio-lib.ps1` and section 9's citation rule, in both directions. The other eight sections it
runs on a plain invocation are unchanged and still have no self-test, for the reason its help block
gives.
Run them rather than reasoning about whether a change is safe. How three of the self-tests are
built, and the two traps the `-FromZips` one already fell into, is in `scripts/CLAUDE.md`.

**`load-check.ps1` loads the mods two ways, and the default is not the player's.** Without arguments
it junctions the repository's directories in, so the game reads the working tree; `-FromZips` builds
the distributable zips with `scripts/pack-mods.ps1` and loads those instead, resolving every sprite
against the unpacked archive rather than against the repo. A file that resolves through a junction
and never reaches a zip passes the default and breaks a player's game. Use `-FromZips` before
anything that ships.

**The harness under it is shared; the checks are not.** Since #457 `load-check.ps1` builds its mod
directory, loads and dumps through `vendor/grado-factorio-tools/scripts/load-harness-lib.ps1`, and
since #456 the third-party sets come from the shared `fetch-mods.ps1`, pinned in
`scripts/mod-sets.psd1`. Both need the submodule initialised — `git submodule update --init`, the
same step the commit hook already asks for — and the fetcher caches under `.mod-cache/<set>` of the
directory it runs in, so run it from the repository root. Since #458 `factorio-lib.ps1` takes the
same harness for every script that runs the game, so no gate here that starts Factorio runs without
the submodule, and since #462 none of the harness's functions is defined a second time in this repo.

`scripts/probe-*` are **not** in that list and are not gates. A probe asserts nothing and answers
a question a decision is waiting on — exit 0 means it ran and reported, never that the answer was the
hoped-for one. Its findings belong in `docs/research/`, and it stays committed so the next engine
version can be asked the same question.

## The rule that matters most here

**Most of the big decisions are open, and they are Truls's to make.** That includes which upstream base
to build on, whether the four-module split survives, scope, mod compatibility targets, and whether
Space Age ever becomes a first-class target rather than merely a tolerated one.

Three of the decisions this section used to list are settled, and are recorded here so nobody reopens
them by accident:

- **The licence is LGPLv3** — see `LICENSE`, changed from The Unlicense on 2026-08-16, on the grounds
  that the mod is largely Krastorio 2's resources and code and takes only ideas from the original.
- **The published name is Realistic Fusion Refreshed** (ADR 0017, superseding ADR 0009). The `rf-`
  prototype prefix is unaffected.
- **The v1 target is the Factorio 2.0 base game, with Space Age tolerated but not integrated**
  (ADR 0003). What stays open is whether that ever becomes first-class support, which is the item
  left in the list above — not the v1 target.

Do not settle any of them as a side effect of doing something else — no "I picked X to get started".
If a task cannot proceed without one, say so and ask. Recording options with trade-offs is welcome;
choosing between them is not.

## Factorio specifics

- Mods are **Lua**. The API has **three stages**: `settings` and `prototype` run at start-up, `runtime`
  runs during gameplay. Know which stage code belongs to before writing it.
- API docs are published **per game version** at <https://lua-api.factorio.com/>. Check claims against
  the version being targeted rather than from memory. Two of the three older predecessors are **1.1**-era —
  the original and the four-module redesign, whose "2.0" is its own version number — and only
  Durikkan's port targets Factorio 2.0. The 1.1→2.0 break therefore runs straight through the material
  this project builds on, which is the whole reason the work exists.
- `/stable/` and `/latest/` move, and `latest` is the **experimental** build. Pin an explicit version
  (e.g. `/2.0.77/`) when recording a fact.

## Upstream material

**Everything is governed per directory — Lua included.** There is no blanket permission to lift code:
check for a licence file in the directory a file comes from before taking it. The redesign's
`RealisticFusionCore/electric-boiler/` holds 167 lines of Lua under **CC BY-NC-ND 4.0**, so "the repo
licence is WTFPL" does not settle what a given file is. See `docs/adr/0001-liftable-predecessor-material.md`.

- **NonCommercial or NoDerivatives material is never lifted**, whatever its source. That rules out
  `electric-boiler/` and `angels-numerals/` outright.
- **Permissive material is free** — a directory with neither a `license.txt` nor a `legal-note.txt`,
  subject to the unmarked-graphics exception below, which is a large one.
- **Copyleft (GPL/LGPL) is allowed only in its own directory**, with its licence file alongside and
  modifications stated.
- **Lift only from Realistic Fusion Power 1.8.18 or later.** Earlier releases are CC BY-SA 4.0; 1.8.18
  changed the primary licence to WTFPL.
- **A declared licence is evidence, not proof — read the mod's own credits against it.** A fourth
  predecessor, **UFP: Ultimate Fusion Power Fixed** (`ufpFixed`, `ultimateCoreLib`, `ultimateCore`,
  `ultimateCore-2`, `ultimateCore-3`), declares LGPLv3 across all five zips with no per-directory marking
  at all, while its listings credit Games Workshop, Dreamhaven, Blizzard, Hello Games and Arch666Angel.
  **Take no asset from any of the five**, including `ufp_boiler-*.png`, which is the CC BY-NC-ND
  `electric-boiler/` art upscaled. Reading its Lua for 2.0/2.1 prototype patterns is fine. Checked
  2026-08-19; see ADR 0001.

**Both predecessors already mark their assets this way.** Realistic Fusion Power and Durikkan's 2.0 port
keep graphics derived from **Krastorio 2** in their own directories with the licence text alongside,
while everything else stays permissive. Upstream K2 assets
(<https://codeberg.org/raiguard/Krastorio2Assets>) are **LGPLv3**; the copy inside the four-module
redesign is marked **GPLv3** — read the file next to the sprites rather than assuming either. **The
upstream LGPLv3 is the root, not the whole tree**: `Krastorio2Assets/compatibility/IndustrialRevolution/`
carries a `SUB-LICENSE.txt` putting its five PNGs under **CC BY-NC-ND 4.0**, which is the one clause
above that rules material out outright. Nothing from it is in any of the three mods and nothing from
it is committed, checked 2026-09-12 — the directory is present three times under the git-ignored
`.mod-cache*/`, which is where the gates unpack upstream. This repo uses the same scheme — see
`legal-note.txt`.

**Every item in `C:\src\factorio\_reference\` — what it is, where it came from, when it was obtained
and what terms it states — is inventoried in `docs/research/reference-provenance.md`** (#234). This
section states the rules; that note says which file on disk is which.

Two things to know about how the predecessors mark material:

- **Marking is by `legal-note.txt` as much as by `license.txt`.** The provenance lives in the legal note;
  the licence file is only the licence text. Searching for licence files alone finds the directory and
  misses what it is — which is exactly the mistake that produced a wrong version of this section.
- **A directory is named for what it depicts, not for where the art came from.** The Krastorio 2 material
  in both predecessors is in `particle-accelerator/`. Of the three older predecessors only the redesign has a
  directory actually called `krastorio-2/`, so not finding that name means nothing. (This repo has two of
  its own, which are its own doing and come from upstream — not from the redesign.)

Two rules follow:

- **Lift whole directories, with their license file *and* their legal note.** Never copy loose files out
  of a licensed directory into one governed by `LICENSE`. Free means neither file is present — see the
  unmarked-graphics exception below before concluding that settles it.
- **Modifying a file from a licensed directory yields a derivative under that license.** A recoloured
  or re-composited LGPL sprite is still LGPL, and the change must be stated. Modified sprites belong in
  the licensed directory, not beside your own work.

**The exception to "no licence file means free": the predecessors' unmarked `graphics/`.** It is not one
donor's art — the original's changelog credits at least three outside sources for material that is left
unmarked, and says which files came from where for none of them. ADR 0001 names
the three and the releases that credit them.

So: **do not take unmarked graphics from the predecessors on the assumption they are free.** Ask before
using them, or use art with known provenance — which in practice means upstream Krastorio 2, and is why
every sprite in this repo comes from there. Do not relabel them GPL either; that would be guessing in the
other direction.

- **Attribute Romner_set, Durikkan and PreLeyZero** for anything derived from their work, in the commit
  and in the file. Not a licence obligation — a community norm and simple honesty.
- **Do not try to contact Romner_set.** He deprecated the mod, archived the successor read-only and
  anonymised his GitHub account. That is someone stepping away deliberately; respect it.
- **This repo is a fresh history on purpose.** Bring code across as ordinary commits; do not add the
  archive as a remote, fork it, or graft its history in.

## Conventions

- Default branch `main`. Commit email is set per-repo — do not change it.
- `CLAUDE.local.md` is personal and git-ignored. Never commit it, and never move its contents into a
  tracked file.
- **Cite our own code by symbol, never by line number** — the function, field, constant or prototype,
  with a repo-relative path, because there are two `entities.lua`. A comment with no symbol is cited
  by a quoted fragment of its own words. Predecessor, vanilla and third-party citations keep their
  line numbers; we never edit those trees. Since #303 `scripts/ship-check.ps1` gates **two** of the
  three shapes this takes — a path with a line number on it, and a backticked `:155` continuation
  inheriting a path named earlier on the same line — across every tracked `.md`, `.lua`, `.ps1`,
  `.py` and `.js`. It stays blind to "lines 196-197" written out in prose, to a continuation whose
  path is on an earlier line, and to one written without backticks; and a **mod**-relative path like
  `prototypes/entities.lua:119` still names two files, so only a citation anchored at the repo root
  is actually gated. See `docs/adr/0032-prose-cites-code-by-symbol.md` and the script's section 7.
- **Cite a `-SelfTest` half by its name, never by its position** (#411, #416). A gate declares its
  halves by name where they run and `Invoke-SelfTestHalves` numbers them as it goes, so inserting
  one moves the number printed for every half after it while the names stay put — and a sentence
  pointing at a position still reads as true once it means a different half. `ship-check.ps1`
  section 9 gates the rule across the same tracked `.md`, `.lua`, `.ps1`, `.py` and `.js` files, and its own
  `-SelfTest` proves it fires and that it
  leaves a named citation alone. **It reads prose only** — a whole markdown file, and in code the
  lines that are comments, minus a markdown fence, where a pasted run lives — so a citation in a
  printed string, in a fenced block, in a trailing comment after code, or written without the word
  ("the sixth", "the one before the stall detector") is not seen. The section comment carries the
  full list of what it cannot see.

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
lets the commit through, instead of passing everything quietly — the posture
[ADR 0001](https://github.com/trulsjo/grado-factorio-tools/blob/main/docs/adr/0001-siblings-consume-this-repo-as-a-submodule.md)
in the tooling repo requires, and what makes the second step safe to ask for.

**It exists because the wrap rule had rotted.** Measured on 2026-09-06 by
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

Single-context — `CONTEXT.md` and `docs/adr/` at the repo root, created lazily. See
`docs/agents/domain.md`.

### Rendered art

`/render-machine rf-<machine>` renders a machine's sprite set from its Blender model, or
regenerates the model from its look note. See `.claude/skills/render-machine/SKILL.md`; the
vocabulary is `CONTEXT.md`'s Art section.

### Code review

Two rules, both in `docs/agents/code-review.md`.

**The filter gates the comment, not the report.** `/code-review`'s 80-point threshold governs what
gets posted to the PR. Its rubric only emits 0/25/50/75/100, so the filter admits 100 alone — a
finding can be verified, important and dropped. Report every surviving finding with its score; a
review that posts nothing must still say what it filtered.

**Review the prose, not only the code.** Every gate here checks machinery and none of them reads
English, so a wrong sentence beside a right number survives everything. Check each figure in prose
against a figure in the diff and do the arithmetic; treat "no", "every" and "the only" as
instructions to enumerate; and when a change supersedes a number, grep the repository for the old
one and read every hit in a file that records a measurement, not only the file you edited. Three of
the five defects found across two review rounds on #230 were claims rather than code,
one of them contradicted by a table in the same commit.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

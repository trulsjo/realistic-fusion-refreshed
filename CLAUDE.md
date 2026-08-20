# Realistic Fusion Refreshed — agent notes

Factorio mod project. Long-term goal: finish **Realistic Fusion 2.0**. See `README.md` for what the mod
is and where it came from; this file is how to work in the repo.

## State

**In development.** `realistic-fusion-refreshed-core` and `realistic-fusion-refreshed` load against
Factorio 2.0.77 and all four of ADR 0010's reactions are playable: the water-to-deuterium extraction
chain, D-D reactors that
breed their own tritium and helium-3, D-T fusion burning it, lithium blankets breeding more, and an
aneutronic tier running D-He3 and He3-He3 in a second reactor through a direct energy converter.
**Every prototype ADR 0010 names for Power now exists** — thirteen entities and seven technologies,
high-capacity steam equipment included. **Every balance number is still provisional**, and coverage
is not the same as being finished: nothing here has been played for longer than a rig runs.

Verification here is by running the game, not by reading. `tests/*.lua` cover the pure simulation
outside Factorio; `scripts/check-*.ps1` and `scripts/load-check.ps1` create real maps and assert against
them, and `load-check.ps1` is where the invariants tying the simulation to the prototypes are enforced.
`scripts/locale-check.ps1` and `scripts/name-check.ps1` only dump prototypes and create no map, so a
pass there says nothing about runtime. Run them rather than reasoning about whether a change is safe.

## The rule that matters most here

**Most of the big decisions are open, and they are Truls's to make.** That includes which upstream base
to build on, whether the four-module split survives, scope, the Factorio/Space Age target, mod
compatibility targets, and the published name. (The licence is settled: **LGPLv3**, see `LICENSE` —
changed from The Unlicense on 2026-08-16, on the grounds that the mod is largely Krastorio 2's
resources and code and takes only ideas from the original.)

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
redesign is marked **GPLv3** — read the file next to the sprites rather than assuming either. This repo
uses the same scheme — see `legal-note.txt`.

**Verified 2026-08-17 (#38)** against the zips in `C:\src\factorio\_reference\`, which the survey could
not download and had to leave open. Both the 1.1 original (1.8.18) and Durikkan's port (1.9.0, 1.9.2)
mark exactly two directories, with the same terms:

| Directory | Licence | What its `legal-note.txt` says |
|---|---|---|
| `graphics/particle-accelerator/` | **GPLv3** | *"All textures in this directory are modified from Krastorio 2"* |
| `electric-boiler/` | **CC BY-NC-ND 4.0** | *"All textures and code in this directory are from angels petrochem"* |

Three things to take from that:

- **Marking is by `legal-note.txt` as much as by `license.txt`.** The provenance lives in the legal note;
  the licence file is only the licence text. Searching for licence files alone finds the directory and
  misses what it is — which is exactly the mistake that produced a wrong version of this section.
- **A directory is named for what it depicts, not for where the art came from.** The Krastorio 2 material
  in both predecessors is in `particle-accelerator/`. Of the three older predecessors only the redesign has a
  directory actually called `krastorio-2/`, so not finding that name means nothing. (This repo has two of
  its own, which are its own doing and come from upstream — not from the redesign.)
- **The two root licences differ, and one mod disagrees with itself.** The original's `license.txt` is
  **WTFPL v2** (`Copyright (C) 2024 Romner`); the port's is **The Unlicense**. But the port also ships the
  original's root `legal-note.txt` byte-for-byte, which still says WTFPL — so its two root files name
  different licences. Both are permissive, so nothing downstream turns on it. Both mods state the
  per-directory rule in that same note: *"Any file in a subdirectory of this mod that doesn't have a
  license.txt and/or a legal-note.txt in its directory is licensed under the WTFPL."*

Two rules follow:

- **Lift whole directories, with their license file *and* their legal note.** Never copy loose files out
  of a licensed directory into one governed by `LICENSE`. Free means neither file is present — see the
  unmarked-graphics exception below before concluding that settles it.
- **Modifying a file from a licensed directory yields a derivative under that license.** A recoloured
  or re-composited LGPL sprite is still LGPL, and the change must be stated. Modified sprites belong in
  the licensed directory, not beside your own work.

**The exception to "no licence file means free": the predecessors' unmarked `graphics/`.** It is not one
donor's art — the original's changelog credits at least three outside sources for material that is left
unmarked, and says which files came from where for none of them:

| Release | What the changelog says |
|---|---|
| **0.2.0**, 2020-01-01 | *"Credit to YuokiTani for re-rendering some unused textures with changed colors from https://u.nu/factoriogfx"* — Wube's unused art, re-rendered by a third party |
| **1.2.0**, 2020-09-05 | *"Others are modified from **angel's** discarded/unused thread"* |
| **1.3.13**, 2020-12-06 | *"New antimatter reactor graphics, courtesy of **PreLeyZero**"* |
| **1.8.0**, 2021-09-03 | *"**PreLeyZero** made completely new antimatter reactor graphics, and in turn doubled the mod size"* |

That same 1.2.0 entry opens *"Some of the textures are modified from Krastorio 2 and licensed under GNU
GPL v3"* — and those **are** marked, in `graphics/particle-accelerator/`. So the changelog is not evidence
of GPL material hiding under a permissive root; it is evidence that Romner marked what he knew the terms
for and left the rest bare. The bare remainder is the problem.

A root licence only disposes of what its declarer had the right to license, and no record exists of the
terms any of the three donated under. PreLeyZero's *own* mods generally carry GPL, which is a further
reason not to read silence as a permissive donation.

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

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/) with a [gitmoji](https://gitmoji.dev/)
prefix. One format, no exceptions:

```
<emoji> <type>(<scope>): <subject>

<body>

<footer>
```

**Subject line**

- Imperative mood, lowercase after the colon, no trailing period, whole line ≤ 72 characters.
- `<scope>` is optional but preferred. Use the module (`core`, `power`, `weaponry`, `antimatter`) or the
  area (`data`, `runtime`, `settings`, `locale`, `graphics`, `repo`).
- The emoji is the *rendered* character, not the `:shortcode:`.

**Types, and the emoji that goes with each**

| Type | Emoji | Use for |
|---|---|---|
| `feat` | ✨ | a new capability |
| `fix` | 🐛 | a bug fix |
| `docs` | 📝 | documentation only |
| `refactor` | ♻️ | restructuring with no behaviour change |
| `perf` | ⚡️ | performance |
| `test` | ✅ | tests |
| `build` | 📦 | packaging, mod zip, `info.json`, dependencies |
| `chore` | 🔧 | tooling and config |
| `style` | 🎨 | formatting and code structure only |
| `revert` | ⏪️ | reverting a previous commit |

A few situational ones worth knowing: 🎉 to begin a project, 🚚 to move or rename files, 🔥 to remove
code or files, 🌐 for localisation, 💄 for icons and other visual assets, 🚧 for work in progress.

**Body** — explain *why*, not what the diff already shows. Wrap at 72. Reference the Factorio API
version when a change depends on one. When code is lifted from a predecessor mod, name the author and
the mod there (see Upstream material above).

**Breaking changes** — for anything that breaks an existing save or a mod's public interface, put `!`
before the colon *and* a `BREAKING CHANGE:` footer explaining the migration. Save compatibility is the
one that will bite: it breaks silently and players find out, not the build.

Example:

```
✨ feat(power): add deuterium extraction from water

Implements the first step of the fuel chain so the reactor prototypes have an
input to consume. Recipe balance is provisional and not yet checked against the
1.1 original's numbers.
```

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

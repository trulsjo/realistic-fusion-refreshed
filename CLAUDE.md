# Realistic Fusion Refreshed — agent notes

Factorio mod project. Long-term goal: finish **Realistic Fusion 2.0**. See `README.md` for what the mod
is and where it came from; this file is how to work in the repo.

## State

**Planning stage — the repository has no mod code.** If you are looking for the implementation, it does
not exist yet. Do not infer structure from empty directories.

## The rule that matters most here

**Most of the big decisions are open, and they are Truls's to make.** That includes which upstream base
to build on, whether the four-module split survives, scope, the Factorio/Space Age target, mod
compatibility targets, and the published name. (The licence is settled: The Unlicense, see `LICENSE`.)

Do not settle any of them as a side effect of doing something else — no "I picked X to get started".
If a task cannot proceed without one, say so and ask. Recording options with trade-offs is welcome;
choosing between them is not.

## Factorio specifics

- Mods are **Lua**. The API has **three stages**: `settings` and `prototype` run at start-up, `runtime`
  runs during gameplay. Know which stage code belongs to before writing it.
- API docs are published **per game version** at <https://lua-api.factorio.com/>. Check claims against
  the version being targeted rather than from memory. Two of the three predecessors are **1.1**-era —
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
- **Permissive material is free** — a directory with no licence file, subject to the PreLeyZero
  exception below.
- **Copyleft (GPL/LGPL) is allowed only in its own directory**, with its licence file alongside and
  modifications stated.
- **Lift only from Realistic Fusion Power 1.8.18 or later.** Earlier releases are CC BY-SA 4.0; 1.8.18
  changed the primary licence to WTFPL.

**Both predecessors already mark their assets this way.** Realistic Fusion Power and Durikkan's 2.0 port
keep graphics derived from **Krastorio 2** in their own directories with the licence text alongside,
while everything else stays permissive. Upstream K2 assets
(<https://codeberg.org/raiguard/Krastorio2Assets>) are **LGPLv3**; the copy inside the four-module
redesign is marked **GPLv3** — read the file next to the sprites rather than assuming either. This repo
uses the same scheme — see `legal-note.txt`. Two rules follow:

- **Lift whole directories, with their license file.** Never copy loose files out of a licensed
  directory into one governed by `LICENSE`. A directory with no license file is permissive and free.
- **Modifying a file from a licensed directory yields a derivative under that license.** A recoloured
  or re-composited LGPL sprite is still LGPL, and the change must be stated. Modified sprites belong in
  the licensed directory, not beside your own work.

**One exception to "no licence file means free": PreLeyZero's donated art.** The predecessors credit
them for graphics but mark none of it, so by the convention above it inherits each mod's default. That
default only disposes of what its declarer had the right to license, and no record exists of the terms
the art was donated under — while PreLeyZero's *own* mods generally carry GPL, which is a reason not to
assume a permissive donation. Which files are theirs is not established either.

So: **do not take unmarked graphics from the predecessors on the assumption they are free.** Ask before
using them, or use art with known provenance. Do not relabel them GPL either — that would be guessing in
the other direction.

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

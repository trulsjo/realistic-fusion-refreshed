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
  the version being targeted rather than from memory — this project spans a 1.1-era original and a 2.0
  rewrite, and the 1.1→2.0 break is the whole reason the work exists.
- `/stable/` and `/latest/` move, and `latest` is the **experimental** build. Pin an explicit version
  (e.g. `/2.0.77/`) when recording a fact.

## Upstream material

**Lua source** may be lifted from the three predecessors in `README.md`; their licences (WTFPL, The
Unlicense) permit it without conditions.

**Graphics and other assets are a different question — check before copying any.** The archive's own
README credits graphics to **PreLeyZero** and says graphics were borrowed from **Krastorio 2**, which is
**LGPLv3**. A repo-level WTFPL only disposes of what its author owned, so an asset that came from
Krastorio 2 is still LGPLv3 and cannot simply be absorbed into this Unlicense project. Whether the two
published mods carry the same borrowed assets has not been checked.

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

# 1. Which predecessor material is liftable

Date: 2026-08-13

## Status

Accepted. Resolves
[Which predecessor material is actually safe to lift?](https://github.com/trulsjo/realistic-fusion-refreshed/issues/10).

## Context

`CLAUDE.md` told every agent working here that Lua could be lifted from any of the three predecessors
because their licences (WTFPL, The Unlicense) "permit it without conditions". The predecessor survey
(`docs/research/predecessor-survey.md`) established that this is false for part of the archive.

Four directories in `realistic-fusion-dev` carry their own licence file, and only two are Krastorio 2:

| Directory | Licence | Contents |
|---|---|---|
| `RealisticFusionCore/graphics/icons/krastorio-2/` | GPLv3 | 6 lithium/KCl icons |
| `RealisticFusionAntimatter/graphics/particle-accelerator/` | GPLv3 | 9 sprites, modified from Krastorio 2 |
| `RealisticFusionCore/graphics/icons/angels-numerals/` | CC BY-NC-ND 4.0 | 22 numeral overlays, from Angel's Refining |
| `RealisticFusionCore/electric-boiler/` | CC BY-NC-ND 4.0 | 8 sprites, an icon, **and `electric-boiler.lua` (167 lines)**, from Angel's Petrochem |

Three findings made this a decision rather than a correction:

1. **The NonCommercial-NoDerivatives Lua is wired in, not inert.** `RealisticFusionCore/data.lua:41`
   reads `if not mods["angelspetrochem"] then require("electric-boiler.electric-boiler") end` — Core
   ships its own copy of Angel's electric boiler as a fallback for players without Angel's. Taking Core
   as it stands means shipping that file.
2. **That copy is already modified.** It carries `--*replaced …` and `--*added line` comments
   throughout, rewriting asset paths and prototype ordering. NoDerivatives forbids precisely this. Not
   a legal opinion, but on a plain reading the archive's own copy appears to sit outside the terms it
   ships under.
3. **The Krastorio 2 licence discrepancy is a copy-versus-upstream difference, not a contradiction.**
   Upstream <https://codeberg.org/raiguard/Krastorio2Assets> is **LGPLv3** — verified against its
   `LICENSE` file, whose header reads "GNU LESSER GENERAL PUBLIC LICENSE Version 3". The GPLv3 marking
   applies to Romner's 2022 copy inside the archive. This repo's documents were right about upstream
   and silent about the copy.

Relicensing this project was considered and does not help: NonCommercial and NoDerivatives are
incompatible with every open-source licence, and the per-directory convention already permits copyleft
material inside an Unlicense repo. The project licence remains The Unlicense, unreopened.

> **Superseded in part, 2026-08-16.** The project licence is now **LGPLv3**. It was reopened and
> changed by Truls once the mod actually shipped Krastorio 2 graphics and the sprite definitions that
> place them — the borrowed material is the bulk of what a player sees, and Krastorio 2 is LGPLv3 in
> both its assets and its mod code. The paragraph above is still right about what relicensing does
> *not* buy: it does not make NonCommercial or NoDerivatives material takeable, and everything this
> ADR decides below is unchanged. What it changes is that copyleft material no longer sits inside a
> permissive repository, so the boundary is a record of provenance rather than a rule anyone has to
> find. See `legal-note.txt`.

## Decision

**Material carrying NonCommercial or NoDerivatives terms is never lifted, whatever its source.** In
practice that rules out `electric-boiler/` and `angels-numerals/` entirely. If Core becomes the upstream
base, the guarded `require` at `data.lua:41` is dropped, and the electric boiler is either reimplemented
or left to Angel's Petrochem as an optional dependency.

**Permissive material may be used anywhere.** A directory with no licence file is permissive and free,
subject to the existing PreLeyZero exception for unmarked donated art.

**Copyleft material (GPL or LGPL) may be used, but only in its own directory, with its licence file
alongside, and with modifications stated.** This is the convention `legal-note.txt` already describes
and both predecessors already follow.

**Lift only from Realistic Fusion Power 1.8.18 or later.** Changelog 1.8.18 (2024-10-25) changed the
primary licence from CC BY-SA 4.0 to WTFPL, so every earlier release is share-alike and is not covered
by the permissive reading.

**No blanket permission for Lua.** Check for a licence file in the directory a file comes from before
lifting it — the same rule that already governed assets. Lua is not exempt; the electric boiler is the
proof.

## Consequences

- `CLAUDE.md`'s "Lua source may be lifted … without conditions" is wrong and is corrected alongside
  this ADR. Its Krastorio 2 sentence gains the upstream-versus-copy distinction.
- [Choose the upstream base](https://github.com/trulsjo/realistic-fusion-refreshed/issues/5) is
  unblocked, and now carries a known cost for the redesign branch: dropping one `require` and either
  writing a boiler or making Angel's optional.
- Where Krastorio 2 art is wanted later, upstream Codeberg under LGPLv3 is preferable to inheriting
  Romner's GPLv3-marked copy — it avoids the discrepancy rather than resolving it. Which sprites get
  used at all is out of scope on the map; this ADR only records that the upstream source exists and
  what it is licensed under.
- No claim is made about the port or the 1.1 original's licensed directories. Neither could be
  downloaded during the survey (HTTP 403 behind a login gate), so which directories they mark, and
  under what terms, remains unverified. If either becomes the base, that must be checked first.

## Alternatives considered

**Carry the NC-ND directories isolated per-directory.** Cheapest, and consistent with the existing
convention. Rejected: it inherits an already-modified copy of NoDerivatives material and leaves code in
the repo that nobody — including this project — may legally change.

**Ask Angel's author for relicensing.** Could clear the material properly. Rejected as a blocker: it
depends on a third party replying, and the boiler is not worth stalling the base decision for.

**Permissive only, no copyleft at all.** Would keep the repo uniformly public-domain. Rejected: it
discards inherited art for no gain the per-directory convention doesn't already provide.

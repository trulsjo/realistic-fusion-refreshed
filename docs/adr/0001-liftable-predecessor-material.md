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

> **The deferred check was done on 2026-08-17 (#38).** This ADR's text stands as what was true when it
> was accepted; the answer is recorded in
> [`predecessor-survey.md`](../research/predecessor-survey.md) and `CLAUDE.md`.
>
> Both mods mark two directories, on the same terms as each other: `graphics/particle-accelerator/`
> (GPLv3, *"modified from Krastorio 2"*) and `electric-boiler/` (CC BY-NC-ND 4.0, *"from angels
> petrochem"*). Those are two of the four rows in the table above — so **the redesign inherited them from
> the original** rather than introducing the per-directory scheme, and the original's root
> `legal-note.txt` states the rule in the same words the redesign's does. What the redesign added is the
> other two rows, including the only directory anywhere actually named `krastorio-2/`.
>
> Neither decision above is affected. Both marked directories are excluded regardless —
> `electric-boiler/` as NoDerivatives, `particle-accelerator/` as copyleft that could only ever live in
> its own directory — and no predecessor material has been lifted into this repository at all.
>
> **One clause is widened, though.** "Permissive material may be used anywhere … subject to the existing
> PreLeyZero exception for unmarked donated art" now reads too narrowly: the original's changelog credits
> **three** outside sources for material it leaves unmarked — YuokiTani (0.2.0), angel's discarded thread
> (1.2.0) and PreLeyZero (1.3.13, 1.8.0). Read that clause as covering the unmarked `graphics/` set
> entire, not one donor's part of it. `CLAUDE.md` carries the full statement.

> **A fourth predecessor, checked 2026-08-19 — and it breaks the other half of the rule.** Truls found
> [UFP: Ultimate Fusion Power Fixed](https://mods.factorio.com/mod/ufpFixed) by
> `VVVVVVEmersonFisioVVVVVV`, self-described *"bootleg of Romner_set's Realistic Fusion Power"*, Factorio
> 2.0–2.1, ~7.67K users, still releasing. It ships as five mods: `ufpFixed` (Lua and locale only) plus
> `ultimateCoreLib` (scripts) and the asset packs `ultimateCore`, `ultimateCore-2` and `ultimateCore-3`.
> All five declare **LGPLv3** — this repo's own licence — and were checked as zips in
> `C:\src\factorio\_reference\`, 630 MB in total.
>
> **There is no per-directory marking anywhere in any of the five.** All five root `LICENSE` files are
> byte-identical (7423 bytes, sha256 `c2841e73de1273ef…`, the LGPLv3 text verbatim), and not one
> `license.txt` or `legal-note.txt` exists in any subdirectory. Two root files in `ultimateCore` qualify
> what the root claims, and they cover **8 assets out of 758**: `freesound_org_attribution.txt` (four
> sounds — two CC0, one CC BY 4.0, and **one CC BY-NC 4.0**, shipped as
> `sound/__timbre__artificial-intelligence-goes-nuclear.ogg`) and `vecteezy_attribution.txt` (four PNGs
> under a licence forbidding redistribution, since composited into the black-hole, void-drop, void-armour
> and Void Revenant art under names that no longer identify them).
>
> Meanwhile the mod portal listings credit material the zips never mention: *"markmen494 Warhammer 40k
> Mechanicus graphics"*, art belonging to **Games Workshop**, **Dreamhaven Inc. and Game River**
> (Mechabellum), **Blizzard** (StarCraft) and **Hello Games** (No Man's Sky), plus PreLeyZero, YuokiTani,
> fishbus, Malcolm Riley, Silenteum, Kubius, vlss and OpenGameArt. Two of those credits are checkable and
> both fail: `ultimateCore-3` is **89% Arch666Angel's Mass Transit train art** (128 MB of 145 MB, 162
> sprites; upstream is **CC BY-NC-ND 4.0**), and
> `ultimateCore/graphics/ufp_entity/ufp_boiler-{north,south,east,west}-{on,off}.png` are **this ADR's own
> `electric-boiler/` sprites, upscaled 160×160 → 320×320** — the Angel's Petrochem art that row four of
> the table above rules out, relabelled LGPLv3 with no note. Its `ufp_electric_boiler.lua` is genuine
> fresh 2.0 work; only the art is contaminated.
>
> **What this changes.** The decisions above stand unaltered, but their shape was "no licence file means
> permissive, subject to the unmarked-graphics exception" — a rule about **silence**. This is the
> opposite failure: an **affirmative licence the declarer had no right to grant**, applied uniformly
> across a mixed tree so that nothing looks like an exception. So the rule reads: **a declared licence is
> evidence, not proof.** Where a mod's own credits name third parties it does not have terms from, the
> root file settles nothing, and a permissive or copyleft declaration is worth no more than the bare
> `graphics/` directory the exception above already covers.
>
> **In practice: no assets from `ufpFixed`, `ultimateCore`, `ultimateCore-2`, `ultimateCore-3` or
> `ultimateCoreLib` — not one sprite, not one sound.** Its Lua would be liftable on its own terms
> (LGPLv3 into its own directory, modifications stated, author named), but every prototype references
> `__ultimateCore__/graphics/…`, so lifted Lua arrives needing art that is excluded: read it, do not copy
> it. Its use here is as a second worked example of Factorio 2.0 prototypes — and at
> `factorio_version` 2.1 it is the newest reference available, ahead of Durikkan's port. The full survey
> is in the project brain note, not in this repo.

## Alternatives considered

**Carry the NC-ND directories isolated per-directory.** Cheapest, and consistent with the existing
convention. Rejected: it inherits an already-modified copy of NoDerivatives material and leaves code in
the repo that nobody — including this project — may legally change.

**Ask Angel's author for relicensing.** Could clear the material properly. Rejected as a blocker: it
depends on a third party replying, and the boiler is not worth stalling the base decision for.

**Permissive only, no copyleft at all.** Would keep the repo uniformly public-domain. Rejected: it
discards inherited art for no gain the per-directory convention doesn't already provide.

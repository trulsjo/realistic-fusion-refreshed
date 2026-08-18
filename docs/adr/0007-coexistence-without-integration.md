# 7. Coexistence without integration

Date: 2026-08-14

## Status

Accepted. Resolves
[Which mods are compatibility targets?](https://github.com/trulsjo/realistic-fusion-refreshed/issues/6).

## Context

The 1.1 original supported 17 compatibility targets in a dedicated `compatibility-patches/` tree —
2,595 Lua lines across 36 files, declared through 15 optional dependencies. The cost was extremely
uneven:

| Target | Lines | | Target | Lines |
|---|---:|---|---|---:|
| space-exploration | **1,290** | | Flow Control | 41 |
| Krastorio2 | **375** | | bobpower | 39 |
| RTG | 182 | | IndustrialRevolution | 31 |
| angelsindustries | 132 | | angelspetrochem | 30 |
| Booktorio | 131 | | angelssmelting | 20 |
| bobplates | 93 | | 6 others | ≤11 each |

Space Exploration alone was half the burden. Krastorio 2, the next largest, was under a seventh of it.

**Durikkan deleted all of it.** Port 1.9.2 removed 15 directories, 31 files and 2,369 Lua lines, taking
optional dependencies from 12 to none, and the mod remains published and maintained.

Both expensive targets are alive on Factorio 2.0, so this is a live question rather than a moot one:

- **Krastorio 2** — latest 2.1.2 (June 2026), targeting Factorio 2.1.
- **Space Exploration** — latest 0.7.61, updated within the last week; the mod page states "Version
  0.7.x is for Factorio 2.0".

## Decision

**v1 commits to coexistence, not integration.**

**Coexistence** means the mod loads and runs alongside other mods without crashing, and does not
gratuitously collide with them — no duplicate prototype names, no assumptions that only this mod
modifies a shared prototype.

**Integration** — resource-chain hooks, recipe substitution, replacing another mod's fusion or
antimatter implementation, unlocking through another mod's technology tree — is **not** in v1, for any
mod, including Krastorio 2.

This is deliberately the same line drawn in [ADR 0003](0003-space-age-tolerated-not-targeted.md) for
Space Age. The reasoning transfers directly: reconciling this mod's subject with another
implementation of the same subject is a design commitment, not a compatibility patch, and v1 has no
code yet from which to make it.

## Consequences

- **No optional dependencies for integration purposes.** `info.json` stays minimal. If a dependency is
  declared, it is because the mod genuinely requires it, not to hook into it.
- **Coexistence is a claim that must be tested, not assumed.** It is the same obligation ADR 0003
  created for Space Age, and it is the more important one here because it now covers an open-ended set
  of mods rather than one expansion. At minimum, loading alongside Krastorio 2 should be verified before
  v1 ships, given it implements fusion too.
- **The `rfp-` prefix prohibition from [ADR 0006](0006-clean-break-from-predecessor-saves.md) is part of
  this.** Prototype-name collision is the most likely way coexistence fails, and it fails as a load
  error rather than a degradation.
- **Nothing is inherited to maintain.** Under [ADR 0004](0004-fresh-code-predecessors-as-reference.md)
  v1 is written fresh, so there is no compatibility tree arriving with the code and no third-party mod
  whose changes force maintenance on this project's schedule.
- **The original's patches remain available as reference.** They sit in the main tree under WTFPL with
  no separate licence file, so [ADR 0001](0001-liftable-predecessor-material.md) permits lifting from
  them if a later integration effort wants a worked example — 1,290 lines of Space Exploration
  experience in particular.
- **Integration is deferred, not refused.** Any specific integration can become its own effort once v1
  exists and there is something concrete to integrate.

## Verification

Partly discharged on **2026-08-18** ([#33](https://github.com/trulsjo/realistic-fusion-refreshed/issues/33)).
The half that is done is the half this ADR calls the most likely failure; the half that is not is
blocked by something neither mod controls.

**Name collision: verified, and it is the one that fails as a load error.** `scripts/name-check.ps1`
derives what this repo defines by diffing two `--dump-data` runs — with the mods and without — rather
than by trusting the prefix it is checking, then requires every one of those names to carry `rf-` and
to appear in no reference mod.

The diff is keyed by type *and* name, and carries each prototype's content rather than only its
presence, because the difference alone cannot see the case that matters most: a prototype defined under
a name the game already uses appears in **both** dumps and cancels out. That is the silent-overwrite
case — our definition simply replaces vanilla's and the game loads without a word — so it is caught by
comparing content across what the dumps share. Of 2,840 shared prototypes exactly one differs,
`technology/fluid-handling`, and that one is the game's own barrel generation appending our fluids'
barrel recipes to it; it is declared rather than waived. It passes both ways:

| Run | Names this repo defines | Result |
|---|---:|---|
| base 2.0 | 83 | all carry `rf-`, none used by Krastorio 2 (686 names scanned), Durikkan's port (234) or the 1.1 original (229) |
| `-With space-age` | 113 | as above; the extra 30 are the expansion's generated recycling recipes, which inherit our names |

That also discharges the `rfp-` prohibition this ADR inherits from
[ADR 0006](0006-clean-break-from-predecessor-saves.md): a name starting `rf-` cannot equal one starting
`rfp-`, and all 113 embed it — the 11 `empty-rf-<fluid>-barrel` recipes below carry the prefix without
leading with it, which is equally sufficient, since the predecessor's own barrels would be generated as
`empty-rfp-<fluid>-barrel`. Measured directly: the port defines 299 `rfp-` names and the 1.1 original
293, and **neither defines a single one beginning `rf-`**.

One exception is allowed and counted rather than waived: base Factorio generates
`empty-rf-<fluid>-barrel` for each barrelled fluid of ours, which no naming discipline here can rename.
It still embeds the prefix, so it still cannot collide.

**Loading alongside Krastorio 2: verified.** `scripts/load-check.ps1 -AlsoModDirectory <dir>` junctions
a directory of third-party mods in and enables them. With Krastorio 2 and its four hard dependencies
present, it passes: prototypes valid, every referenced asset present, **a map created with the whole set
loaded**, and the simulation's nine load-time invariants still holding.

**Which release, and why it is not the current one.** K2's current release is 2.1.3
(`factorio_version 2.1`, `base >= 2.1.7`). This project declares `2.0` and the game here is 2.0.77, and
Factorio treats 2.0 and 2.1 as different major versions a mod cannot span — so 2.1.3 cannot be enabled
beside this mod at all, whatever the mod list says. The **2.0 line** is what loads, and 2.0.19 is its
last release. Its dependency set differs from 2.1.2's, which matters to anyone repeating this:
`ChangeInserterDropLane` is a *hard* dependency at 2.0.19 and only a recommendation by 2.1.2.

| Mod | Version | `factorio_version` | Source |
|---|---|---|---|
| `Krastorio2` | 2.0.19 | 2.0 | `https://codeberg.org/raiguard/Krastorio2.git` tag `v2.0.19` |
| `Krastorio2Assets` | 2.0.5 | 2.0 | `https://codeberg.org/raiguard/Krastorio2Assets.git` tag `v2.0.5` |
| `Krastorio2MenuSimulations` | 2.0.2 | 2.0 | `https://codeberg.org/raiguard/Krastorio2MenuSimulations.git` tag `v2.0.2` |
| `ChangeInserterDropLane` | 1.2.0 | 2.0 | `https://codeberg.org/raiguard/ChangeInserterDropLane.git` tag `v1.2.0` |
| `flib` | 0.16.2 | 2.0 | `https://github.com/factoriolib/flib.git` tag `v0.16.2` |

All five are **public git, needing no mod-portal account** — worth knowing, because
[#60](https://github.com/trulsjo/realistic-fusion-refreshed/issues/60) was written assuming the portal's
authenticated download is the only way to obtain third-party mods. For raiguard's mods it is not.

**What is still open.** This verifies the 2.0 line, not the release players run today; that is
[#59](https://github.com/trulsjo/realistic-fusion-refreshed/issues/59)'s question. Loading is also not
playing — no save was run for longer than the map creation. The wider mod sets are
[#61](https://github.com/trulsjo/realistic-fusion-refreshed/issues/61), and the inventory behind all
three is `docs/research/mod-set-coexistence-targets.md`.

**So this ADR's minimum — *"at minimum, loading alongside Krastorio 2 should be verified before v1
ships"* — is met**, for the 2.0 line and for name collision both.

## Alternatives considered

**Coexistence plus Krastorio 2 integration.** The most defensible single exception — K2 ships its own
fusion, is actively maintained, and cost the original 375 lines rather than SE's 1,290. Rejected for v1
on consistency and sequencing: the Space Age decision declined to reconcile with a vanilla fusion
implementation for the same reason, and integrating with K2's fusion raises the identical design
question before anything exists to integrate.

**Coexistence plus Krastorio 2 and the Bob's/Angel's family.** Roughly 700 lines in the original across
six mods, and a real audience among overhaul players. Rejected as a v1 commitment: it multiplies the
testing surface against six independently moving mods.

**The full original ambition including Space Exploration.** Rejected — SE alone was half the original's
compatibility burden, and the maintainer who inherited that tree chose to delete it rather than carry it
forward.

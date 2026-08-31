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

**This ADR's minimum is met**, for the 2.0 line and for name collision both — *"at minimum,
loading alongside Krastorio 2 should be verified before v1 ships"*. First run **2026-08-18**
([#33](https://github.com/trulsjo/realistic-fusion-refreshed/issues/33)), and it is the first row of
the table below.

**How the checks work is in the checks.** `scripts/name-check.ps1` derives what this repo defines by
diffing two `--dump-data` runs — with the mods and without — rather than by trusting the prefix it is
verifying, and compares content as well as presence, because the case that matters most cancels out
of a presence diff: a prototype defined under a name the game already uses appears in **both** dumps.
That is the silent overwrite, and it is the failure this ADR calls most likely.
`scripts/load-check.ps1` creates a real map and asserts the invariants that tie the simulation to the
prototypes. Both scripts carry the method and its limits in their own docstrings; it is not restated
here.

**Pins live in `scripts/fetch-mods.ps1`'s `$MOD_SETS` and are never re-derived in prose**
([ADR 0026](0026-third-party-mods-are-pinned-to-their-2-0-line.md)). Krastorio 2's five-mod set is
public git needing no mod-portal account, which is the assumption
[#60](https://github.com/trulsjo/realistic-fusion-refreshed/issues/60) was written under and against.

### The lanes (#61)

One row per lane. **A row is a claim about the pinned release and about nothing else** — ADR 0026
confines it to that family's last `factorio_version` 2.0 release, so no unqualified *"works with X"*
may reach a portal listing, `README.md`, a mod description or a changelog on the strength of one.
None of this reaches the releases players run today.

**A pass means the prototypes are valid, every referenced asset resolves, a map was created with the
whole set loaded, and the load-time invariants hold. It is not a balance claim and it is not a
playthrough.** A red lane is not automatically a defect here — see the second finding below.

| Lane | Set | `load-check` | `name-check` | Cause |
|---|---|---|---|---|
| Krastorio 2 ([#33](https://github.com/trulsjo/realistic-fusion-refreshed/issues/33)) | `krastorio2`, 5 mods | green | green | discharges this ADR's minimum. It also generates 47 recipes from ours and wires them into one technology of its own — two different shapes, both counted; measured on the set re-run in [#130](https://github.com/trulsjo/realistic-fusion-refreshed/issues/130), not in #33 |
| Space Exploration ([#129](https://github.com/trulsjo/realistic-fusion-refreshed/issues/129)) | `spaceex`, 17 mods | **red** | green | upstream's — five `__base__` paths 2.0 removed, named by SE and the two AAI mods, not pinnable away |
| Krastorio 2 + Space Exploration ([#130](https://github.com/trulsjo/realistic-fusion-refreshed/issues/130)) | `k2-spaceex`, 22 mods | **red** | green | the same five paths; K2 names none of them and adds no sixth |
| Angel's ([#131](https://github.com/trulsjo/realistic-fusion-refreshed/issues/131)) | `angels`, 8 mods | green | green | green, and it still edits 41 prototypes of ours neither check can see — two inherited stats of which are ours ([#153](https://github.com/trulsjo/realistic-fusion-refreshed/issues/153)) |
| Angel's + Space Age ([#132](https://github.com/trulsjo/realistic-fusion-refreshed/issues/132)) | `angels`, 8 mods, `-With space-age` | green | green | the silence is compatibility; no prototype touched only in combination, but on `rf-heater` the two compose |
| Bob's ([#133](https://github.com/trulsjo/realistic-fusion-refreshed/issues/133)) | `bobs`, 12 mods | green | **red** | upstream's — `bobplates` moves every `-barrel` unlock off vanilla `fluid-handling` onto its own `bob-fluid-barrel-processing`, unconditionally, so our 22 land there. `effects` is the only field that differs, 22 added and none removed. It is `$ALLOWED_EDITS`' declared shape one hop further, and the classifier misses it because base Factorio generated those recipes rather than the set |

**The run log is the lane's issue**, not this ADR — counts, prototype enumerations, which dumps were
compared, and what was and was not run. Each row links to it.
[ADR 0027](0027-the-lane-issue-is-the-run-log.md) says why it lives there. What this ADR keeps is the
verdict and what the lanes have taught.

### What the lanes have established

Five findings, and they grow when a lane teaches something new rather than once per lane.

**1. The `rf-` prefix has held, and against the predecessors it cannot fail by construction.** No
`collision:` and nothing `unprefixed:` in any lane, at 740 to 3,053 candidate names each. Against the
predecessors it is structural rather than lucky, which discharges
[ADR 0006](0006-clean-break-from-predecessor-saves.md)'s one hard requirement: Durikkan's port
defines **210** distinct `rfp-` names and the 1.1 original **216**, and **neither defines a single
name beginning `rf-`** — measured, not assumed. (The harvest counts 299 and 293 `name =` occurrences
respectively; the same name recurs across an item and its recipe, so the distinct figure is the
smaller one and is what "defines" means here.) Two shapes are counted rather than waived: base
Factorio generates `empty-rf-<fluid>-barrel` for each barrelled fluid of ours, which no discipline
here can rename and which still embeds the prefix; and exactly one shared prototype is edited,
`technology/fluid-handling`, which the game's own barrel generation appends our barrel recipes to.

**2. A red lane is usually upstream's, and there are now two shapes of red rather than one.** Five
sets have run red. **Four are the asset shape** — the two `load-check` reds in the table above, plus
`riteg` and `fluid`, which are ADR 0026's own smoke tests and have no row here — every one on a
1.1-era `__base__` path Factorio 2.0 removed, `sound/car-metal-impact.ogg` and the four
`nuclear-reactor/connection-patch-*.png` that 2.0 replaced with one combined sheet. **Not pin
artefacts:** each mod is pinned at the last `factorio_version` 2.0 release its family has, so there
is no later release to move to and the reference cannot be pinned away. This repo names none of them,
checked rather than assumed. ADR 0026 said to budget for exactly this.

**The fifth is a different shape, and it is the first red on the `name-check` half.** Bob's
`bobplates` re-homes every `-barrel` unlock from vanilla `fluid-handling` onto a technology of its
own, so the unlocks base Factorio generated for our fluids move with everyone else's. Still
upstream's — the pass names nothing of ours and tests for no prefix of ours — but it is a
*replacement* finding rather than a missing asset, and it is the shape finding 3's classifier was
written for while sitting just outside what that classifier will accept. See
[#133](https://github.com/trulsjo/realistic-fusion-refreshed/issues/133); whether the classifier
should learn it is open.

**3. An overhaul that walks `data.raw` generates prototypes from ours, and that is counted, not
failed.** Krastorio 2 makes 47 (`kr-burn-`/`kr-crush-`), Space Exploration 22 delivery-cannon
prototypes from our barrelled fluids, Space Age 30 recycling recipes. All of them embed our names, so
they cannot collide however they grow. `name-check` classifies the shape and still exits 0 — **a jump
in that count is worth reading**, because it means a set started generating something new from this
repo. The rule that does the classifying is the only code in that check which *suppresses* a finding;
its two conditions and its stated ceiling live in `scripts/name-check.ps1`, where they can be tested,
not here.

**4. Neither check can see what a set does to our *own* prototypes.** `name-check` compares content
only for prototypes present in **both** dumps, and a prototype of ours is by construction in only one;
`load-check` diffs nothing at all — it asserts validity, assets and invariants, and an edited stat
fails none of them. So an overhaul that edits our prototypes rather than colliding with their names is
invisible to both, however much it changes: Angel's alters **41 of our 145** prototype objects and
Space Age **9**, including a pollution rate and a tenfold fluid-box volume on machines this repo
ships. Found by #131, confirmed by #132, and the reason
[#153](https://github.com/trulsjo/realistic-fusion-refreshed/issues/153) exists.

**5. Where two sets meet, their effects compose.** Angel's and Space Age touch disjoint sets of our
prototypes but for one, and no object is changed only in combination — yet on `rf-heater` the two
edits compose into an `allowed_module_categories` value neither produces alone. **A clean object-level
union is not value-level independence**, and only the second is what a player experiences.

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

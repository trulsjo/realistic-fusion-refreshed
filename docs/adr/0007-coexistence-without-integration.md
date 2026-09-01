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
| Bob's ([#133](https://github.com/trulsjo/realistic-fusion-refreshed/issues/133)) | `bobs`, 12 mods | green | green | green since [#192](https://github.com/trulsjo/realistic-fusion-refreshed/issues/192) taught the classifier the **re-homed unlock**. `bobplates` moves every `-barrel` unlock off vanilla `fluid-handling` onto its own `bob-fluid-barrel-processing`, unconditionally, so our 22 land there: `effects` is the only field that differs, 22 added and none removed, and the 30 unlocks the technology already carried name `barrelling` recipes of vanilla's — the set's own pass visibly already running before we arrived |
| Bob's + Space Age ([#134](https://github.com/trulsjo/realistic-fusion-refreshed/issues/134)) | `bobs`, 12 mods, `-With space-age` | green | green | the same re-homing on the same technology, classified the same way; Space Age adds no further finding |
| Angel's + Bob's ([#135](https://github.com/trulsjo/realistic-fusion-refreshed/issues/135)) | `angels-bobs`, 20 mods | green | **red** | upstream's, and the re-homed shape one step outside the rule [#191](https://github.com/trulsjo/realistic-fusion-refreshed/issues/191) deliberately drew. `angelspetrochem` recategorises every barrel recipe to `angels-barreling-pump`, so **not one** of the destination technology's 144 baseline unlocks names a `barrelling` recipe — 142 are `angels-barreling-pump`, one is `crafting`, one declares no category. The condition is an *any*-match rather than a majority, so it is the absence of every `barrelling` unlock that declines the lane, not the proportion. `effects` is still the only field that differs, 22 added and none removed. Whether the rule widens is [#194](https://github.com/trulsjo/realistic-fusion-refreshed/issues/194) |
| Angel's + Bob's + Space Age ([#136](https://github.com/trulsjo/realistic-fusion-refreshed/issues/136)) | `angels-bobs`, 20 mods, `-With space-age` | green | **red** | the same single finding, unchanged by Space Age |
| Angel's + Bob's + MadClown's ([#137](https://github.com/trulsjo/realistic-fusion-refreshed/issues/137)) | `angels-bobs-madclowns`, 21 mods | green | **red** | the same single finding; `Clowns-Processing` adds none of its own |
| Angel's + Bob's + MadClown's + Space Age ([#138](https://github.com/trulsjo/realistic-fusion-refreshed/issues/138)) | `angels-bobs-madclowns`, 21 mods, `-With space-age` | green | **red** | the same single finding |
| SeaBlock NG ([#139](https://github.com/trulsjo/realistic-fusion-refreshed/issues/139)) | `seablock`, 46 mods, `-With quality` | **red** | **red** | two reds, both upstream's and neither the same as the other. `load-check` fails on `__base__/sound/car-metal-impact.ogg`, named by `KS_Power` — the asset shape again. `name-check` reports the Angel's re-homing above **and** a second finding of its own: `no-pipe-touching`'s `data-final-fixes` walks `data.raw["infinity-pipe"]` and collects every pipe connection category it has seen onto it, so our `rf-plasma` and the bare name of our pipe prototype `rf-pipe` join Bob's ten. A third evidence shape, nested two levels inside `fluid_box`, **declined on 2026-09-01** under ADR 0028 — the lane stays red with the cause recorded. [#195](https://github.com/trulsjo/realistic-fusion-refreshed/issues/195) |
| RITEG ([#140](https://github.com/trulsjo/realistic-fusion-refreshed/issues/140)) | `riteg`, 1 mod | **red** | green | upstream's — `__base__/sound/car-metal-impact.ogg`, the 1.1-era path 2.0 removed, named by RITEG and not by this repo. ADR 0026 smoke-tested this and predicted it; the lane now has a row |
| Advanced Fluid Handling ([#141](https://github.com/trulsjo/realistic-fusion-refreshed/issues/141)) | `fluid`, 1 mod | green | green | green on both halves — and `underground-pipe-pack` 2.0.6 still names the same `__base__/sound/car-metal-impact.ogg` in an unconditionally required file, without the asset check failing on it. That is a change from what ADR 0026 measured and is [#196](https://github.com/trulsjo/realistic-fusion-refreshed/issues/196) |

**The run log is the lane's issue**, not this ADR — counts, prototype enumerations, which dumps were
compared, and what was and was not run. Each row links to it.
[ADR 0027](0027-the-lane-issue-is-the-run-log.md) says why it lives there. What this ADR keeps is the
verdict and what the lanes have taught.

### What the lanes have established

Five findings, and they grow when a lane teaches something new rather than once per lane.

**1. The `rf-` prefix has held, and against the predecessors it cannot fail by construction.** No
`collision:` and nothing `unprefixed:` in any of the fourteen lanes, at **11 to 7,146** candidate
names each — a range that read 740 to 3,053 while the table held five rows and neither a one-mod lane
nor a 46-mod one was in it. Against the predecessors it is structural rather than lucky, which
discharges [ADR 0006](0006-clean-break-from-predecessor-saves.md)'s one hard requirement:
Durikkan's port defines **210** distinct `rfp-` names and the 1.1 original **216**, and **neither
defines a single name beginning `rf-`** — measured, not assumed. (The harvest counts 299 and 293
`name =` occurrences respectively; the same name recurs across an item and its recipe, so the
distinct figure is the smaller one and is what "defines" means here.) Two shapes are counted
rather than waived: base Factorio generates `empty-rf-<fluid>-barrel` for each barrelled fluid of
ours, which no discipline
here can rename and which still embeds the prefix; and exactly one shared prototype is edited,
`technology/fluid-handling`, which the game's own barrel generation appends our barrel recipes to.

**2. A red lane is usually upstream's, and there are three shapes of red rather than one.** **The
asset shape** is the `load-check` half: `spaceex` and `k2-spaceex` in the table above, plus `riteg`
and `seablock`, every one on a 1.1-era `__base__` path Factorio 2.0 removed —
`sound/car-metal-impact.ogg`, named by RITEG and by `KS_Power`, and the four
`nuclear-reactor/connection-patch-*.png` that 2.0 replaced with one combined sheet. **Not pin
artefacts:** each mod is pinned at the last `factorio_version` 2.0 release its family has, so there
is no later release to move to and the reference cannot be pinned away. This repo names none of them,
checked rather than assumed. ADR 0026 said to budget for exactly this.

**The second shape is on the `name-check` half: a re-homed unlock the classifier declines.**
`bobplates` re-homes every `-barrel` unlock from vanilla `fluid-handling` onto a technology of its
own, so the unlocks base Factorio generated for our fluids move with everyone else's. Still
upstream's — the pass names nothing of ours and tests for no prefix of ours — but it is a
*replacement* finding rather than a missing asset. Since
[#192](https://github.com/trulsjo/realistic-fusion-refreshed/issues/192)
the classifier knows the shape and both Bob's lanes are green. The **five** lanes that load Angel's
beside Bob's are still red, because
`angelspetrochem` recategorises every barrel recipe to `angels-barreling-pump`, so not one of the
destination technology's 144 baseline unlocks names a `barrelling` recipe and the rule counts
`barrelling` only. The condition is an *any*-match rather than a majority, so what declines the lane
is the absence of every `barrelling` unlock and not their proportion. That narrowness is
deliberate — see finding 3 — and whether it widens is
[#194](https://github.com/trulsjo/realistic-fusion-refreshed/issues/194).

**The third shape arrived with SeaBlock, is weaker evidence than either, and was declined.**
`no-pipe-touching`'s `data-final-fixes` walks `data.raw["infinity-pipe"]` and adds every pipe
connection category it has collected. **Two entries of ours land there by two different passes**, and
only one of them is a category we wrote: `rf-plasma`, collected off `rf-pump`'s box, and the bare
**name** of our pipe prototype `rf-pipe`, collected because the mod takes the name of every
`data.raw.pipe` entry that has not opted out of it. Upstream's by its own source comment, but the
classifier cannot see it at all: the difference is nested two levels inside `fluid_box`, where
`$SHAPES` is keyed by the top-level field, and a connection category of ours in their list is equally
consistent with either author. Declined rather than built — see finding 3.
[#195](https://github.com/trulsjo/realistic-fusion-refreshed/issues/195).

**One claim in this finding has been measured false and is left here rather than quietly dropped.**
It used to count `fluid` among the asset-shape reds on ADR 0026's smoke test. Re-run on 2026-08-31
for [#141](https://github.com/trulsjo/realistic-fusion-refreshed/issues/141),
that lane is green on both halves, while `underground-pipe-pack` 2.0.6 still names
`__base__/sound/car-metal-impact.ogg` in a file its `data.lua` requires unconditionally. RITEG names
the same path in the same field and still fails, so the check has not stopped working in general.
Why the two differ is
[#196](https://github.com/trulsjo/realistic-fusion-refreshed/issues/196) and is not settled here.

**3. A set reacts to our prototypes in two different ways, and both are counted rather than failed.**

**It generates prototypes from ours.** Krastorio 2 makes 47 (`kr-burn-`/`kr-crush-`), Space
Exploration 22 delivery-cannon prototypes from our barrelled fluids, Space Age 30 recycling recipes.
All of them embed our names, so they cannot collide however they grow, and a technology of theirs
that gains only the unlocks for them is wiring rather than replacement.

**Or it re-homes an unlock the *game* generated from ours.** Base Factorio makes a fill and an empty
barrel recipe per barrelled fluid and puts their unlocks on `fluid-handling`; `bobplates` sweeps
every one of them onto a technology of its own, ours along with vanilla's. Added by
[#192](https://github.com/trulsjo/realistic-fusion-refreshed/issues/192) on
[#191](https://github.com/trulsjo/realistic-fusion-refreshed/issues/191)'s decision,
after [#133](https://github.com/trulsjo/realistic-fusion-refreshed/issues/133) found it.

**The two are not the same claim and the check does not print them as one.** A set-derived prototype
*could only exist* because the set made it, which is real evidence of authorship. A re-homed unlock
names a prototype of **ours** that the **game** made — and a technology of theirs holding
`unlock-recipe rf-brine-barrel` is equally consistent with the set sweeping it in and with this repo
wiring it into their technology, because a dump records what a prototype ended up as and never who
wrote it. So the re-homed rule tests the set's own visible behaviour instead: the recipe is one base
Factorio constructs from a fluid of ours, and the destination technology already carried
base-generated barrel unlocks before we arrived. `CONTEXT.md` defines both terms against each other.

**A third way was declined rather than added, and the refusal is the finding.** SeaBlock's
`no-pipe-touching` collects connection categories onto vanilla `infinity-pipe`, ours among them
(finding 2 above). Put to Truls on 2026-09-01 and refused: a category of ours in their list is
equally consistent with either author, and the nearest available evidence — the baseline already
holding ten categories of Bob's — shows a collecting pass ran without showing that it swept **ours**
in. That is one step weaker than the re-homed rule's second condition, so it fails the bar below and
the lane stays red with its cause recorded.
[#195](https://github.com/trulsjo/realistic-fusion-refreshed/issues/195), which also closed the
implementation ticket
[#201](https://github.com/trulsjo/realistic-fusion-refreshed/issues/201).

`name-check` classifies both and still exits 0 — **a jump in either count is worth reading**, because
it means a set started doing something new with this repo. The rule that does the classifying is the
only code in that check which *suppresses* a finding; its conditions, its labels and its stated
ceiling live in `scripts/name-check.ps1`, where they can be tested, not here.
[ADR 0028](0028-a-suppression-rule-reports-on-doubt.md) states the bar those conditions have to clear:
where authorship cannot be shown either way, the check reports.

**4. Neither check can see what a set does to our *own* prototypes.** `name-check` compares content
only for prototypes present in **both** dumps, and a prototype of ours is by construction in only one;
`load-check` diffs nothing at all — it asserts validity, assets and invariants, and an edited stat
fails none of them. So an overhaul that edits our prototypes rather than colliding with their names is
invisible to both, however much it changes: Angel's alters **41 of our 145** prototype objects and
Space Age **9**, including a pollution rate and a tenfold fluid-box volume on machines this repo
ships. Found by #131, confirmed by #132, and the reason
[#153](https://github.com/trulsjo/realistic-fusion-refreshed/issues/153) exists.

**The blind spot now has a measured figure for the one case where the consequence is a removed
guarantee rather than a changed stat.** `scripts/probe-connection-categories.ps1` was committed by
[#206](https://github.com/trulsjo/realistic-fusion-refreshed/issues/206) and run on all fourteen lanes
by [#207](https://github.com/trulsjo/realistic-fusion-refreshed/issues/207), on 2026-09-01 against
2.0.77. Every lane sees the same subject — **17 prototypes of ours with pipe connections, 58
connections, 14 of them contained with `rf-plasma`** — and:

- **One lane of fourteen changes a contained connection**, SeaBlock NG (#139), on `rf-pipe-to-ground`
  alone: the underground connection is overwritten with the literal `pipe-to-ground` and the surface
  one keeps `rf-plasma` with twelve categories appended. A category is a whitelist, so both open the
  box. `no-pipe-touching` 1.1.28 is in no other lane's pin.
- **Two lanes add a category to connections we left `default`** and remove nothing — Krastorio 2's
  `kr-steel-pipe` on #33 and #130, and SeaBlock's sweep. Ordinary boxes stay ordinary.
- **Eleven lanes change nothing at all**, Space Age adds nothing on any of the four lanes that enable
  it, and no lane removed a prototype, emptied a fluid box, or took `default` away.

So **reassignment is one mod's behaviour and addition is a pattern** — which is what
[#208](https://github.com/trulsjo/realistic-fusion-refreshed/issues/208) needs in order to decide
whether a mod-specific response is adequate.
[`connection-categories-by-lane.md`](../research/connection-categories-by-lane.md) is the cross-lane
write-up; each lane's own numbers are on its issue, per ADR 0027. **Neither gate sees any of it yet**
— that is [#209](https://github.com/trulsjo/realistic-fusion-refreshed/issues/209), and until it
lands this finding's first sentence still holds.

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

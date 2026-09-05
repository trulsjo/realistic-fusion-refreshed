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
| Bob's ([#133](https://github.com/trulsjo/realistic-fusion-refreshed/issues/133)) | `bobs`, 12 mods | green | green | green since [#192](https://github.com/trulsjo/realistic-fusion-refreshed/issues/192) taught the classifier the **re-homed unlock**. `bobplates` moves every `-barrel` unlock off vanilla `fluid-handling` onto its own `bob-fluid-barrel-processing`, unconditionally, so our 22 land there: `effects` is the only field that differs, 22 added and none removed, and 30 of the 31 unlocks the technology already carried are barrels the game generated from fluids of vanilla's and Bob's — the set's own pass visibly already running before we arrived. Condition 2 became a construction test in [#200](https://github.com/trulsjo/realistic-fusion-refreshed/issues/200) and this lane's verdict and label are unchanged; re-measured 2026-09-02 |
| Bob's + Space Age ([#134](https://github.com/trulsjo/realistic-fusion-refreshed/issues/134)) | `bobs`, 12 mods, `-With space-age` | green | green | the same re-homing on the same technology, classified the same way; Space Age adds no further finding. 32 of 33 baseline unlocks host, re-measured 2026-09-02 |
| Angel's + Bob's ([#135](https://github.com/trulsjo/realistic-fusion-refreshed/issues/135)) | `angels-bobs`, 20 mods | green | green | green since [#200](https://github.com/trulsjo/realistic-fusion-refreshed/issues/200) made condition 2 of the re-homed rule a construction test, on [#194](https://github.com/trulsjo/realistic-fusion-refreshed/issues/194)'s decision. `angelspetrochem` recategorises every barrel recipe to `angels-barreling-pump` — 142 of the 144 baseline unlocks, one `crafting`, one with no category — so a rule counting `barrelling` could never fire here, while the recipes stayed base Factorio's, edited in place rather than generated by the set. Asked instead whether the destination already unlocked barrels built from a fluid in the **baseline** dump, **142 of the 144** answer yes. `effects` is still the only field that differs, 22 added and none removed. Measured 2026-09-02 |
| Angel's + Bob's + Space Age ([#136](https://github.com/trulsjo/realistic-fusion-refreshed/issues/136)) | `angels-bobs`, 20 mods, `-With space-age` | green | green | the same re-homing, classified the same way; 146 of 148 baseline unlocks host. Space Age adds no further finding |
| Angel's + Bob's + MadClown's ([#137](https://github.com/trulsjo/realistic-fusion-refreshed/issues/137)) | `angels-bobs-madclowns`, 21 mods | green | green | the same re-homing; 148 of 150 baseline unlocks host. `Clowns-Processing` adds none of its own |
| Angel's + Bob's + MadClown's + Space Age ([#138](https://github.com/trulsjo/realistic-fusion-refreshed/issues/138)) | `angels-bobs-madclowns`, 21 mods, `-With space-age` | green | green | the same re-homing; 152 of 154 baseline unlocks host |
| SeaBlock NG ([#139](https://github.com/trulsjo/realistic-fusion-refreshed/issues/139)) | `seablock`, 46 mods, `-With quality` | **red** | **red** | two reds, both upstream's and neither the same as the other. `load-check` fails on `__base__/sound/car-metal-impact.ogg`, named by `KS_Power` — the asset shape again. `name-check`'s share of that pair is now **one** finding rather than two: the Angel's re-homing above is classified `rehomed` since [#200](https://github.com/trulsjo/realistic-fusion-refreshed/issues/200) — 136 of 138 baseline unlocks host, 14 added and none removed, measured 2026-09-02 — and what keeps the lane red is only this one, which is its own: `no-pipe-touching`'s `data-final-fixes` walks `data.raw["infinity-pipe"]` and collects every pipe connection category it has seen onto it, so our `rf-plasma` and the bare name of our pipe prototype `rf-pipe` join Bob's ten. A third evidence shape, nested two levels inside `fluid_box`, **declined on 2026-09-01** under ADR 0028 — the lane stays red with the cause recorded. [#195](https://github.com/trulsjo/realistic-fusion-refreshed/issues/195) |
| RITEG ([#140](https://github.com/trulsjo/realistic-fusion-refreshed/issues/140)) | `riteg`, 1 mod | **red** | green | upstream's — `__base__/sound/car-metal-impact.ogg`, the 1.1-era path 2.0 removed, named by RITEG and not by this repo. ADR 0026 smoke-tested this and predicted it; the lane now has a row |
| Advanced Fluid Handling ([#141](https://github.com/trulsjo/realistic-fusion-refreshed/issues/141)) | `fluid`, 1 mod | green | green | green on both halves — and `underground-pipe-pack` 2.0.6 still names the same `__base__/sound/car-metal-impact.ogg` in an unconditionally required file, without the asset check failing on it: 2.0 migrated `vehicle_impact_sound` to `impact_category` for `pump` and not for `electric-energy-interface`, so the string never reaches the dump the check walks. Measured 2026-08-31 against 2.0.77 — ADR 0026's contrary claim is corrected, this verdict stands, see finding 2 and [#196](https://github.com/trulsjo/realistic-fusion-refreshed/issues/196) |

**The run log is the lane's issue**, not this ADR — counts, prototype enumerations, which dumps were
compared, and what was and was not run. Each row links to it.
[ADR 0027](0027-the-lane-issue-is-the-run-log.md) says why it lives there. What this ADR keeps is the
verdict and what the lanes have taught.

### Closed by declaration — the combinations that are not lanes (#61)

Six combinations have no row above and never will. One mod in each declares `!` against another, so
the game refuses the selection outright and a run would produce the refusal and nothing else.
**No lane exists for any of them and none should be opened.**

| Combination | Refused by, at the pinned release |
|---|---|
| SeaBlock NG + Space Age | `SeaBlockWanne` 1.0.5 declares `! space-age` |
| SeaBlock NG + Krastorio 2 | `SeaBlockWanne` 1.0.5 declares `! Krastorio2` |
| Space Exploration + Space Age | `space-exploration` 0.7.57 declares `! space-age` |
| Space Exploration + Angel's or Bob's | `space-exploration` 0.7.57 declares `!` against fourteen Angel's and Bob's mods by name — three of the Angel's core four, and eight of the twelve in the pinned `bobs` set |
| Krastorio 2 + the full Bob's set | `Krastorio2` 2.0.19 declares `! bobequipment` and `! bobvehicleequipment` |
| Krastorio 2 + MadClown's Nuclear | `Krastorio2` 2.0.19 declares `! Clowns-Nuclear` |

**Read at the pins on 2026-09-05, not carried over from the survey.** The list was first derived on
2026-08-18 from the portal's then-current `factorio_version` 2.1 releases, and
[ADR 0026](0026-third-party-mods-are-pinned-to-their-2-0-line.md) later confined this project to the
2.0 line — where `SeaBlockWanne`'s dependency array is already known to differ from its 2.1 one.
All six hold at the pinned releases, read from `info_json.dependencies` on the portal's `/full`
endpoint. `docs/research/mod-set-coexistence-targets.md` carries the derivation and the two textual
corrections the re-read produced.

Two consequences the table above depends on. There is **no `+ Space Age` variant of #129 or #130**,
and one must not be added. And **"K2 + the full Bob's set" is a different set, not a variant** — it
is enableable only with those two mods dropped, so it would have to be pinned and run as a lane of
its own rather than folded into an existing row.

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

**2. A red lane is usually upstream's, and three shapes of red have been seen rather than one — of
which only two are red today, the second having been taught to the classifier.** **The
asset shape** is the `load-check` half: `spaceex` and `k2-spaceex` in the table above, plus `riteg`
and `seablock`, every one on a 1.1-era `__base__` path Factorio 2.0 removed —
`sound/car-metal-impact.ogg`, named by RITEG and by `KS_Power`, and the four
`nuclear-reactor/connection-patch-*.png` that 2.0 replaced with one combined sheet. **Not pin
artefacts:** each mod is pinned at the last `factorio_version` 2.0 release its family has, so there
is no later release to move to and the reference cannot be pinned away. This repo names none of them,
checked rather than assumed. ADR 0026 said to budget for exactly this.

**The second shape was on the `name-check` half: a re-homed unlock the classifier declined. It is
now classified on every lane that shows it, and the past tense is deliberate.** `bobplates` re-homes
every `-barrel` unlock from vanilla `fluid-handling` onto a technology of its own, so the unlocks
base Factorio generated for our fluids move with everyone else's. Still upstream's — the pass names
nothing of ours and tests for no prefix of ours — but it is a *replacement* finding rather than a
missing asset. Since
[#192](https://github.com/trulsjo/realistic-fusion-refreshed/issues/192)
the classifier knows the shape, and since
[#200](https://github.com/trulsjo/realistic-fusion-refreshed/issues/200) it knows it on the five
lanes that load Angel's beside Bob's as well.

**What had to change was the proxy, not the purpose.** The rule used to ask whether a baseline unlock's
recipe declared the `barrelling` **category**, and a category is a label a set can swap wholesale:
`angelspetrochem` recategorises every barrel recipe — vanilla's, Bob's and ours alike — to
`angels-barreling-pump`, so **not one** of the destination technology's 144 baseline unlocks named a
`barrelling` recipe and no measurement on an Angel's lane could ever have satisfied it. The recipes
were still base Factorio's; `angelsrefining` edits them in place rather than generating its own. So
condition 2 now asks the question it was always standing in for — has the destination already unlocked
barrels **the game generated**, built as `<fluid>-barrel` and `empty-<fluid>-barrel` from the fluids in
the **baseline** dump. Measured 2026-09-02: **142 of 144** on `angels-bobs`, 146 of 148 with Space Age,
148 of 150 with MadClown's, 152 of 154 with both, 136 of 138 on SeaBlock, and 30 of 31 and 32 of 33 on
the two Bob's lanes that were already green. Four lanes turned green; **SeaBlock stays red on the third
shape below**, which this did not touch. Our own fluids cannot satisfy the condition by construction
rather than by exclusion — they are not in the baseline — and the `≥1` threshold is unchanged from
#192, deliberately: [#194](https://github.com/trulsjo/realistic-fusion-refreshed/issues/194) held that
moving mechanism and threshold together would make any regression unattributable. That threshold is
the rule's loosest joint, and it is stated as such in the code.

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

**Why the two differ is now settled, and it is the field rather than the check.** Measured on
2026-08-31 against Factorio 2.0.77 by inspecting both dumps: **2.0 migrated
`vehicle_impact_sound` to `impact_category` for the `pump` prototype type and not for
`electric-energy-interface`.** Both mods write the same Lua; the engine keeps it on RITEG's
interface and discards it on the pipe pack's `pump/underground-mini-pump`, so the path occurs once
in the `riteg` dump (on `electric-energy-interface/RITEG-1`) and zero times in the `fluid` one,
where no prototype declares `vehicle_impact_sound` at all and 219 declare `impact_category` —
vanilla's own `pump/pump` among them. `Find-MissingAssets` walks the dump as an object graph, so a
property the engine never records is not a hole in it — **both verdicts are correct.**
[#196](https://github.com/trulsjo/realistic-fusion-refreshed/issues/196).

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

**4. What a set does to our *own* prototypes is mostly still invisible, and exactly one slice of it
is now a gate.** `name-check` compares content only for prototypes present in **both** dumps, and a
prototype of ours is by construction in only one. `load-check` asserts validity, assets, the
simulation's invariants — and, since
[#209](https://github.com/trulsjo/realistic-fusion-refreshed/issues/209) on 2026-09-02, that
containment survived the load. Everything else an overhaul does to our prototypes is still invisible
to both, however much it changes: Angel's alters **41 of our 145** prototype objects and Space Age
**9**, including a pollution rate and a tenfold fluid-box volume on machines this repo ships. Found
by #131, confirmed by #132, and the reason
[#153](https://github.com/trulsjo/realistic-fusion-refreshed/issues/153) exists.

**The containment slice is closed because containment is the one rule enforced by declaration
rather than by code.** `contain()` writes the category and 2.0 refuses to join two connections whose
categories differ, so nothing watches it at runtime — an argument that holds only while the
declaration survives, and a `data-final-fixes` can take it away silently (finding 2's third shape,
#195). So `load-check` now dumps the game twice on every lane: once with our mods alone for what our
data stage declared, once with the set for what survived. A category we wrote that is gone from the
second **fails the run**, naming the prototype, the connection and both values.

Three properties of that gate belong here rather than only in the script:

- **It runs before the asset check, deliberately.** Four lanes — `spaceex`, `k2-spaceex`, `seablock`,
  `riteg` — are permanently red on a 1.1-era `__base__` path their own mods name, and with the asset
  check first the containment gate would never have run on any of them. That includes `seablock`, the
  only lane that has ever reassigned a category of ours. A gate that cannot reach the lane it was
  built for closes nothing.
- **Additions do not fail it.** A category is a whitelist, so an addition does open the box — but that
  is #195's shape, decided on 2026-09-01, and it reports through
  `scripts/probe-connection-categories.ps1` rather than failing a run. The gate counts them into its
  pass line so they are not silent, and does not name the connections: that is the probe's report.
- **It cannot see a bundled mod doing it.** Both dumps enable the same `-With` selection, so Space Age
  cancels out of the comparison exactly as it cancels out of every other `-With` lane's difference.

**Measured across all fourteen lanes on 2026-09-02 against 2.0.77: every one green, 14 contained
connections each**, the four asset-red lanes included — which is the result
[#207](https://github.com/trulsjo/realistic-fusion-refreshed/issues/207)'s sweep predicted and
[#208](https://github.com/trulsjo/realistic-fusion-refreshed/issues/208)'s opt-out earned on
`seablock`. **Green is the claim**: the gate exists to notice the fifteenth lane, and it is what #208
meant by *reassess if a second mod ever reassigns a containment category* — that mod now fails a run
instead of waiting to be read out of somebody's `data-final-fixes`.

**The blind spot now has a measured figure for the one case where the consequence is a removed
guarantee rather than a changed stat.** `scripts/probe-connection-categories.ps1` was committed by
[#206](https://github.com/trulsjo/realistic-fusion-refreshed/issues/206) and run on all fourteen lanes
by [#207](https://github.com/trulsjo/realistic-fusion-refreshed/issues/207), on 2026-09-01 against
2.0.77. Every lane sees the same subject — **17 prototypes of ours with pipe connections, 58
connections, 14 of them contained with `rf-plasma`** — and:

- **One lane of fourteen changed a contained connection**, SeaBlock NG (#139), on
  `rf-pipe-to-ground` alone: the underground connection was overwritten with the literal
  `pipe-to-ground` and the surface one kept `rf-plasma` with twelve categories appended. A category
  is a whitelist, so both opened the box. `no-pipe-touching` 1.1.28 is in no other lane's pin.
  **Closed the same day by #208 — see below; the past tense is deliberate.**
- **Three lanes add a category to connections we left `default`** and none of them removes one
  there — Krastorio 2's `kr-steel-pipe` on #33 and #130, and SeaBlock's own sweep on #139, which is
  therefore in both this bullet and the one above. Two mods, two mechanisms, and `default` survives
  in every case, so ordinary boxes stay ordinary. One, plus three, less the lane counted twice, plus
  eleven, is fourteen.
- **Eleven lanes change nothing at all**, and no lane removed a prototype, emptied a fluid box, or
  took `default` away. The four lanes that enable Space Age report the same as their plain
  counterparts, which means **adding a set on top of Space Age does what adding it alone does** —
  and *not* that Space Age changes nothing. `-With` enables a bundled mod on both sides of the
  comparison, so it cancels out and this instrument cannot see it either way.

So **reassignment is one mod's behaviour and addition is a pattern**.
[`connection-categories-by-lane.md`](../research/connection-categories-by-lane.md) is the cross-lane
write-up; each lane's own numbers are on its issue, per ADR 0027. **One gate now sees the half of it
that is containment** — [#209](https://github.com/trulsjo/realistic-fusion-refreshed/issues/209),
landed 2026-09-02: `load-check` fails when a category we wrote is gone. The additions on connections
we left `default` are outside it by design, so those stay a measurement rather than a verdict, and
this finding's first sentence still holds for everything that is not a connection category.

**And the answer to a set that does it is to take that set's own opt-out — Truls's call on
[#208](https://github.com/trulsjo/realistic-fusion-refreshed/issues/208), 2026-09-01.**
`rf-pipe-to-ground` now carries `npt_compat = { ignore = true }`, which gates the only pass that
reaches it and closes both connections with one field. Three things about that decision belong in
this ADR rather than only in the code:

- **It is a permission, not a defence, and the difference is the whole of what containment is now
  worth under an arbitrary set.** The declaration does not survive a `data-final-fixes` that rewrites
  it and nothing here makes it survive; what holds on that lane is a field naming one mod's hook. A
  second mod doing the same thing reopens #208, and since 2026-09-02 #209's gate is what notices:
  it fails the run rather than leaving the reassignment to be found by reading their Lua.
- **The general alternative was declined on this ADR's own line.** A `data-final-fixes` of ours
  re-asserting the category would run after theirs and would work, but it defends against a problem
  measured on one lane by overriding whatever another mod did — which is integration's posture, not
  coexistence's. Recorded because a future reader will ask why the robust option was not taken.
- **`rf-pipe` deliberately did not get the field.** It needs none: the pass that rewrites
  `data.raw.pipe` entries is guarded on their holding a default category and it holds none. Setting
  it would additionally stop the mod collecting our prototype's bare *name*, which is half of the
  finding [#195](https://github.com/trulsjo/realistic-fusion-refreshed/issues/195) declined to
  suppress on the same day, and it would not clear that lane anyway — `rf-plasma` still reaches the
  `infinity-pipe` through `rf-pump`.

**What this costs the coexistence position is one line of another mod's private vocabulary in our
shipped data**, on one prototype, deleted by that mod as it runs. `underground-pipe-pack` 2.0.6 sets
the same field on its own prototypes with no dependency on the mod that reads it, so the shape is not
unprecedented among mods that have never met.

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

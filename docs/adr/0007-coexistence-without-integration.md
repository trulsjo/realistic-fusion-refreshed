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
loaded**, and the simulation's nine load-time invariants still holding — nine as of that run;
`check_prototypes()` makes twelve calls today, which is the figure the lanes below quote.

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

### The wider lanes (#61)

One row per lane as it runs. **#59 is settled and it settled the scope rather than the question**:
[ADR 0026](0026-third-party-mods-are-pinned-to-their-2-0-line.md) pins every family to its last
`factorio_version` 2.0 release and confines what a lane proves to exactly that, which leaves the
paragraph above still true — none of this reaches the release players run today. So a row here is a
claim about the pinned release and about nothing else — no unqualified *"works with X"* may reach a
portal listing, `README.md`, a mod description or a changelog on the strength of one. The pins live
in `scripts/fetch-mods.ps1`'s `$MOD_SETS`; a row names the version it was proved against because the
manifest can move under it.

| Lane | Set | `load-check` | `name-check` | Cause |
|---|---|---|---|---|
| Space Exploration ([#129](https://github.com/trulsjo/realistic-fusion-refreshed/issues/129)) | `spaceex`, 17 mods | **red** | green | the red is upstream's — below |
| Krastorio 2 + Space Exploration ([#130](https://github.com/trulsjo/realistic-fusion-refreshed/issues/130)) | `k2-spaceex`, 22 mods | **red** | green | the same five paths, still upstream's — below |

**Space Exploration, 2026-08-27 ([#129](https://github.com/trulsjo/realistic-fusion-refreshed/issues/129)).
Red on the assets, green on the names, and this repo causes neither outcome.** The lane this ADR
priced highest — 1,290 lines in the 1.1 original, *"half the burden"* as the Context above puts it —
and the `rf-` prefix had never met it. (#129 words it as more than every other target combined, which
the attributed rows support and the 2,595 total does not; half is the claim both readings agree on,
so it is the one used here.) It ran red on both halves first; the name half went green when the
classifier learned the shape it had found, which is the last subsection below. Both reds are worth reading in full before the next lane runs, because one of them is the shape
ADR 0026 predicted and the other is a shape nobody had seen.

**The game half passed and the gate that follows it did not.** Factorio loaded all twenty mods,
created a 1.4 MB map with SE's universe generated into it and exited 0 — so the prototypes are valid
and the simulation's twelve load-time invariants hold with the whole set present. `load-check.ps1`
then exits 1 at the asset gate on **five `__base__` paths the set names and Factorio 2.0.77 does not
have**:

| Reference | Named by | Why it is gone |
|---|---|---|
| `graphics/entity/nuclear-reactor/connection-patch-{north,east,south,west}.png` | `space-exploration` 0.7.57, for its antimatter reactor and its energy transmitter | 2.0 ships one combined `reactor-connect-patches.png` in place of the four 1.1 sheets |
| `sound/car-metal-impact.ogg` | `aai-industry` 0.6.16 and `aai-signal-transmission` 0.5.3, as `vehicle_impact_sound` | removed in 2.0; the same path that already reddened `riteg` and `fluid` under ADR 0026 |

This repo names none of the five — checked, not assumed. **Nor is it a pin artefact:** both mods are
pinned at the last `factorio_version` 2.0 release their family has, so there is no later 2.0 release
to move to and the reference cannot be pinned away. It is the cost ADR 0026 said to budget for,
arriving a third time.

**The collision half found one thing, and it is theirs generated from ours.** No `collision:` and no
`unprefixed:` — the half ADR 0007 calls the most likely way coexistence fails is clean against SE's
2,313 candidate names. The difference is **108** prototype names, and it accounts for itself
completely: **86** are what the same check reports with no set loaded at all, and **22** are SE's own,
generated from our 11 barrelled fluids — `prototypes/phase-2/delivery-cannon-barrels.lua` registers
every fluid not marked `auto_barrel = false`, and `prototypes/phase-3/delivery-cannon.lua` extends the
prototypes from the barrel ITEM's name. So they are 11 recipes `se-delivery-cannon-pack-rf-<fluid>-barrel`
and 11 items `se-delivery-cannon-package-rf-<fluid>-barrel`, read out of the dump rather than inferred
from the check's `<ours>` placeholder. 86 + 22 = 108, so nothing in the difference is unattributed. Eleven of the seventeen mods put prototypes in the dump; the six that did not are the
pure graphics mods, which is what they are for.

What fails is one `replaces:`, on **`generator/se-fluid-burner-generator`**. Measured across the two
dumps rather than argued from the Lua: the only field that differs is `custom_tooltip_fields`, it
goes from 2 entries to 4, **nothing is removed**, the two SE already had are unchanged and still in
order, and the two added ones name `rf-reactor-energy` and `rf-aneutronic-reactor-energy` — our only
two fluids carrying a `fuel_value`. SE's `prototypes/phase-3/custom-tooltips.lua` walks
`data.raw.fluid` and appends a consumption line per non-hidden fuel fluid, so its generator's tooltip
gained two rows because this repo exists. That is the same mechanism `Get-DerivedUnlock` already
excuses for `unlock-recipe` effects, wired through a different field — and `name-check.ps1`'s own
docstring predicted exactly this: *"A set that wires its derivations in some other way ... will
surface as a plain `replaces:` and want reading."* It has now been read.

**So the lane finds no defect in this repo and no collision.**

**`name-check` now knows the shape — Truls's call, 2026-08-27, on this finding.** The question was
whether to teach it, and it is not a free one: `Get-DerivedWiring` is the only code in that check
that *suppresses* a finding, so an over-broad rule there turns a real collision into a counted line
while the run still exits 0. It was taught narrowly and the narrowness is the whole safety — a
wiring is excused only when the single differing field is that shape's own; the diff is additions
only, counted as a **multiset**, so nothing of theirs was removed, reworded or de-duplicated; and
every added row both **names a prototype this repo defines** and is **of a kind the set already
emits on that same prototype**. It matches against the difference rather than against the `rf-`
prefix deliberately: a prefix test would stop excusing a row about a prototype of ours that was
*misnamed*, and would then report an ADR 0009 breach as somebody else's generator being replaced.

**The second condition is there because this shape cannot prove authorship, and that limit is
recorded rather than papered over.** An added `unlock-recipe` names a prototype of *theirs* that the
set demonstrably generated, which is evidence. A tooltip row names a prototype of *ours* — equally
consistent with the set describing our fluid and with this repo appending a row to their entity, and
the two are byte-identical in a dump, because the dump records what a prototype became and never who
wrote it. Requiring the row to match a kind the set already emits there is the closest available
substitute: it admits another row from an existing generator and keeps out a row invented on their
entity. Its ceiling is stated in the code — a change here that appended a row using the set's *own*
localised key would still be excused, and separating that needs a source-level instrument this repo
does not have.

The self-test's fifth half now carries **thirteen** classifier cases and asserts each exemption is
granted for the *right* shape; the predicate is selected by shape and throws on one it does not know,
so a third shape added without its own test stops the run rather than borrowing another's. An
over-broad version of the rule was written deliberately and half five caught it, naming the case.
The lane's name half is green, the finding is still **counted and named** in the output, and a jump
in that count is still worth reading.

**[#130](https://github.com/trulsjo/realistic-fusion-refreshed/issues/130) meets this twice, and now
it should meet it silently.** That same `custom-tooltips.lua` loops over `se-fluid-burner-generator`
*and* `kr-gas-power-station`, and Krastorio 2 2.0.19 defines the latter
(`prototypes/buildings/gas-power-station.lua`). So the Krastorio 2 + Space Exploration lane gets the
identical rows appended to K2's generator as well, and the expected result is **two** wiring
exemptions rather than two findings. **If either is reported instead, the shape differs from this one
and wants reading** — that is the signal the rule leaves intact rather than the noise it removes. The
red that matters is the asset gate, and it is upstream's.

**Krastorio 2 + Space Exploration, 2026-08-27 ([#130](https://github.com/trulsjo/realistic-fusion-refreshed/issues/130)).
The prediction above held exactly — two **tooltip** exemptions rather than two findings, and not one
new asset.** (Three exemption lines in all; the third is K2's technology, which #33 already records.) This is the lane with the most to say and it is **not the sum of two lanes**: SE declares
`(?) Krastorio2 >= 2.0.10`, a hidden optional dependency, so it ships K2-aware code that loads after
K2 and runs in this lane and in no other. At the data stage that code is **10,916 lines across 96
files** under `prototypes/phase-{1,2,3}/compatibility/krastorio2/`, each phase entered through an
`if mods["Krastorio2"]` guard in its own `krastorio2.lua` — and it is not quite all of it, since
`phase-1/compatibility/recycling.lua` carries a K2 branch outside that tree and
`scripts/compatibility/krastorio2.lua` is another 146 lines at the **control** stage, which this lane
loads but does not exercise. Count the quoted path and you get 96 and 10,916; the wider figure needs
saying which stage it is for. A lane that did not run any of it would be the `spaceex` lane wearing a
bigger set.

**It ran, and the measurement is the difference between the two lanes' baselines** — the dumps
`name-check.ps1 -KeepTemp` leaves as `without-us-data-raw.json`, which are the game with the set and
without this repo. Against `spaceex`'s: **2,715** prototypes present here and absent there, and
**259 of them are SE's own `se-`-named prototypes that exist only because K2 loaded** — 132 recipes,
73 items, 25 technologies, 7 item-subgroups, 6 resources, 6 roboports and the rest, from
`furnace/se-kr-advanced-condenser-turbine` to the 13 `se-kr-*-data` science items. Sixteen run the
other way and vanish when K2 is present, `recipe/se-pulverised-sand` and `technology/sand-processing`
among them, because K2 supplies `kr-sand` in place of SE's. **The difference is not empty and this
lane therefore proves more than the `spaceex` one did**, which is the condition #130 set on being
recorded as a pass at all.

**`load-check` is red on the same five paths and not one more.** Factorio loaded all twenty-five
mods, created a 1.45 MB map with SE's universe generated into it and exited 0 — prototypes valid, the
simulation's twelve load-time invariants holding with K2 and SE both present — and `load-check.ps1`
then exited 1 at the asset gate on the identical set the row above tabulates: SE 0.7.57's four
`connection-patch-*.png` and `car-metal-impact.ogg` from the two AAI mods. **Krastorio 2 names none
of the five** — grepped across the set, and only `space-exploration` and the two AAI mods do — so
adding K2 to the lane added no asset failure of its own, and the cause is unchanged: upstream's, and
not a pin artefact.

**`name-check` is green and its arithmetic is exactly additive.** No `collision:` and no
`unprefixed:` against **3,053** candidate names across the 22 mods; 15 of them put prototypes in the
baseline dump and the 7 that did not are the pure graphics mods and `Krastorio2Assets`. The
difference is **155**, which accounts for itself: **86** ours, and **69** the set's own generated
from ours — 30 `kr-crush-`, 17 `kr-burn-`, 11 `se-delivery-cannon-pack-` and 11
`se-delivery-cannon-package-`. That 69 is K2's 47 plus SE's 22 with **no cross term**: the
`krastorio2` set re-run alone the same day still reports 133 and 47, and #129's `spaceex` run that
morning reported 108 and 22 — so neither mod generates anything new from this repo on account of the
other being present. Three prototypes of theirs gained only wiring, all three
classified and none reported: `generator/kr-gas-power-station` and `generator/se-fluid-burner-generator`
each gained the same two tooltip rows naming `rf-reactor-energy` and `rf-aneutronic-reactor-energy`,
and `technology/kr-fluid-excess-handling` gained only `unlock-recipe` effects — **17** of them,
52 to 69, one per `kr-burn-`. Not 47: the 30 `kr-crush-` recipes are generated enabled and no
technology in K2 or in SE's K2 compat unlocks them, so the check's *"for those"* names the derived
group rather than a per-effect count.

**So the lane that was priced highest finds no defect in this repo, no collision, and no new red.**
The two tooltip exemptions are the second and third data points the classifier rule was decided on,
and they came out the way the rule predicted rather than needing it widened. **Loading is still not
playing** — nothing here has been played, and this says nothing about balance.

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

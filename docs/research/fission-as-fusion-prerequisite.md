# All three predecessors gated fusion on `nuclear-power`. Vanilla's own fusion does not.

Researched 2026-08-19, exploratory. **Nothing here is decided.** Whether `nuclear-power` becomes a
prerequisite of this mod's fusion technologies is a decision about progression and tech-tree shape, and
`CLAUDE.md` reserves those for Truls. This note assembles the evidence and prices the options; it does
not pick one.

Bears directly on two open issues:
[#36](https://github.com/trulsjo/realistic-fusion-refreshed/issues/36) (*does the D-D tier unlock the
vanilla steam turbine?*), whose second option **is** this question, and
[#37](https://github.com/trulsjo/realistic-fusion-refreshed/issues/37) item 4 (the reactor needs ~56 MW
before it produces anything). Builds on [`fission.md`](fission.md), which surveyed fission for this
project and reached the tritium link independently; §5 says where this note agrees with it and where it
narrows it.

Checked against: **Factorio 2.0.77's own prototype data** in the installed game at
`D:\SteamLibrary\steamapps\common\Factorio\data\`, `base/info.json` and `space-age/info.json` both
version 2.0.77 — the technology trees read directly, and the prerequisite closures computed
mechanically from them rather than eyeballed; the **three predecessors' technology files**, two from
`C:\src\factorio\_reference\` and the redesign's from the archive via `gh api`; **Krastorio 2 2.1.3**
source and the **installed Bob's set** (`bobpower` 2.1.0, `bobplates` 2.1.1) for what overhauls do to
`nuclear-power`; and **UKAEA CCFE-PR(17)67** and the **ITER Organisation's** own tritium-breeding page
for the physics. Full list at the bottom, with a section naming what I could not verify.

## What the evidence says, in one paragraph

**The mod's own lineage is unanimously for it, Krastorio 2 is for it, and the game's own fusion is
against it — and they disagree because they are answering different questions.** All three predecessors root their
entire tree in a single effectless technology, `rfp-fusion-theory` / `rf-fusion-theory`, whose only
prerequisite is `nuclear-power` — identical in the 1.1 original, byte-for-byte identical in Durikkan's
2.0 port, and carried across into the four-module redesign. Meanwhile Factorio 2.0.77's own fusion
reactor, shipped in Space Age, does **not** require `nuclear-power`, and not transitively either: its
technology's sole prerequisite is `quantum-processor`, its fuel is lithium, holmium and ammonia, and
uranium appears nowhere in its chain. Vanilla treats fission and fusion as parallel, unrelated
endgames; the predecessors treated fission as the foundation, and so does Krastorio 2, which gates
`kr-fusion-reactor` behind `nuclear-power` *and* Kovarex (§3b). On the physics, the honest finding is
narrower than either: **the real fission-to-fusion dependency is a tritium dependency, it is a
start-up-inventory problem rather than a standing one, and it does not touch D-D at all** — so if it
were followed literally it would attach to `rf-d-t-fusion`, two technologies downstream of the tier a
gate would actually block. And on mechanism there is a hard finding that cuts against the tech
prerequisite specifically: **under Bob's, `nuclear-power` no longer unlocks the steam turbine**
(`bobpower/prototypes/technology/steam-turbines.lua:2`, behind the `bobmods-power-steam` startup
setting -- see §6), so the one concrete problem the gate would
solve — #36's steam gap — it would fail to solve for a large part of the mod's likely audience.

**Underneath all of that sits a structural finding (§2b).** This repo already has a mechanical rule
governing prerequisites — every unlocked recipe's ingredients must be reachable inside the technology's
own closure, and the chain must be usable at its far end — enforced by three `check-*` rigs and, as of
an uncommitted change in the working tree, by `check_steam_sinks()` at `RealisticFusion/control.lua:621`.
**No recipe in either module consumes anything `nuclear-power` unlocks**: the complete set of vanilla
items the mod's recipes touch is ten, and none of `nuclear-power`'s five unlocks is among them. So a
`nuclear-power` edge cannot be justified under the existing rule at all — **it would be the first
prerequisite in this repository chosen for progression rather than closure**, which is exactly the "far
bigger claim" `d-d.lua:17–19` names. Meanwhile `rf-hc-turbine` already proves the mod can ship its own
turbine (`entities.lua:301`), so #36 is a four-way choice rather than a three-way one.

## 1. What vanilla 2.0.77 actually ships

All line numbers are in the installed game at `data/`, `base` and `space-age` both 2.0.77. Closures
below were computed by walking `prerequisites` transitively over both files, not read off the in-game
tree.

### `nuclear-power` and its neighbourhood

| Technology | Prerequisites | Cost | Unlocks | Where |
|---|---|---|---|---|
| `uranium-mining` | `chemical-science-pack`, `concrete` | 100 × (auto + log + chem), 30 s | the `mining-with-fluid` modifier | `base/prototypes/technology.lua:5069` |
| `uranium-processing` | `uranium-mining` | **no science cost at all** — `research_trigger = {type = "mine-entity", entity = "uranium-ore"}` | `centrifuge`, `uranium-processing` | `:5094` |
| **`nuclear-power`** | **`uranium-processing`** | **800 × (auto + log + chem), 30 s** | `nuclear-reactor`, `heat-exchanger`, `heat-pipe`, **`steam-turbine`**, `uranium-fuel-cell` | `:5117` |
| `kovarex-enrichment-process` | `production-science-pack`, `uranium-processing`, `rocket-fuel` | 1500 × four packs | `kovarex-enrichment-process`, `nuclear-fuel` | `:5158` |
| `nuclear-fuel-reprocessing` | **`nuclear-power`**, `production-science-pack` | 50 × four packs | `nuclear-fuel-reprocessing` | `:5188` |

Two structural facts follow, and both matter here.

**`nuclear-power` is not on the enrichment path.** `kovarex-enrichment-process` hangs off
`uranium-processing`, not off `nuclear-power` — so a player can enrich uranium and build atomic bombs
without ever having built a reactor. Only `nuclear-fuel-reprocessing` genuinely sits behind the power
technology.

**Exactly two technologies in the whole game name `nuclear-power` as a prerequisite**, and neither is
on any critical path:

| Technology | Prerequisites | Where |
|---|---|---|
| `nuclear-fuel-reprocessing` | `nuclear-power`, `production-science-pack` | `base/prototypes/technology.lua:5188` |
| `fission-reactor-equipment` | `utility-science-pack`, `power-armor`, `military-science-pack`, **`nuclear-power`** | `base/prototypes/technology.lua:4452` |

Computed closures confirm it is optional in the strongest sense: `nuclear-power` is **not** in the
prerequisite closure of `production-science-pack`, `utility-science-pack`, `space-science-pack`, or
`rocket-silo`. **Vanilla's fission is a side branch a player may skip entirely and still win the
game.** That is worth holding on to, because it is the difference between "this mod asks for a
technology every player has anyway" and "this mod makes an optional branch compulsory".

### Space Age's fusion line — the direct evidence

Space Age **is** installed here (`space-age/info.json` version 2.0.77), so this is checkable rather
than assumed.

| Prototype | Fact | Where |
|---|---|---|
| `fusion-reactor` (technology) | `prerequisites = {"quantum-processor"}` — one prerequisite, and it is a chip | `space-age/prototypes/technology.lua:1832,1850` |
| its cost | 2000 × **all ten science packs**, 60 s | `:1851–1866` |
| `fusion-power-cell` (recipe) | 5 `lithium-plate` + 1 `holmium-plate` + 100 `ammonia`, category `cryogenics` | `space-age/prototypes/recipe.lua:2574` |
| `fusion-reactor` (recipe) | 200 `tungsten-plate` + 200 `superconductor` + 250 `quantum-processor`; `surface_conditions` pressure 100–600, i.e. Aquilo | `:2599` |
| `fusion-reactor-equipment` (technology) | `prerequisites = {"fusion-reactor", "fission-reactor-equipment"}` | `space-age/prototypes/technology.lua:1873,1883` |

**`nuclear-power` is not in `fusion-reactor`'s prerequisite closure, and neither is `uranium-processing`.**
Computed, not inferred. Nor is there an ingredient dependency: no uranium, no fuel cell, no heat pipe
anywhere in the fusion recipes. Space Age gates fusion on *Aquilo* — cryogenics, quantum processors,
a planet with the right pressure — and on nothing fissile.

**There is exactly one place where vanilla does gate a fusion thing behind a fission thing, and it is
instructive that it is the personal equipment.** `fusion-reactor-equipment` requires
`fission-reactor-equipment`, which requires `nuclear-power`. That is an equipment-grid *tier* — the
portable fission reactor is the smaller battery you outgrow — not a claim that fusion physics rests on
fission physics. Read as evidence for a gate it is the weakest possible form of the argument; read as
evidence against, it shows Wube reaching for fission-before-fusion only where the two objects are
competing versions of the same thing, and declining to do it for the power reactor.

### The one number the two systems share

Vanilla's fission is also where the *steam machinery* lives, and this is the whole of #36:

| Entity | Fact | Where |
|---|---|---|
| `nuclear-reactor` | `consumption = "40MW"`, `neighbour_bonus = 1` | `base/prototypes/entity/entities.lua:8570,8578,8579` |
| `steam-engine` | `effectivity = 1`, `fluid_usage_per_tick = 0.5`, `maximum_temperature = 165` → **900 kW** | `:1758,1766–1768` |

`steam-turbine`, `heat-exchanger` and `heat-pipe` are all unlocked by `nuclear-power`
(`base/prototypes/technology.lua:5117`). That is the coupling this repo actually collided with, and it
is a *tech-tree accident* rather than a physical one: the turbine is a generator that happens to have
been filed under fission.

## 2. What this repo ships

Read from `RealisticFusion*/prototypes/technology/` on `main` at commit `e49d923`.

| Technology | Module | Prerequisites | Cost | Where |
|---|---|---|---|---|
| `rf-heavy-water` | Core | `chemical-science-pack`, `fluid-handling` | 100 × three packs | `RealisticFusionCore/prototypes/technology/deuterium.lua:10` |
| `rf-deuterium-extraction` | Core | `rf-heavy-water` | 200 × three | `deuterium.lua:36` |
| `rf-lithium-extraction` | Core | `chemical-science-pack`, `fluid-handling` | 150 × three | `lithium.lua:10` |
| `rf-gas-mixing` | Core | `rf-deuterium-extraction` | 200 × three | `mixing.lua:15` |
| `rf-d-d-fusion` | Power | `rf-deuterium-extraction`, `advanced-circuit`, `concrete` | 500 × three | `RealisticFusion/prototypes/technology/d-d.lua:23` |
| `rf-tritium-breeding` | Power | `rf-d-d-fusion` | 300 × three | `d-t.lua:21` |
| `rf-d-t-fusion` | Power | `rf-tritium-breeding`, `rf-gas-mixing` | 600 × three | `d-t.lua:55` |
| `rf-blanket-breeding` | Power | `rf-d-t-fusion`, `rf-tritium-breeding`, `rf-lithium-extraction` | 900 × three | `blanket.lua:29` |
| `rf-helium-3-breeding` | Power | `rf-tritium-breeding` | 500 × three | `aneutronic.lua:34` |
| `rf-direct-energy-conversion` | Power | `rf-helium-3-breeding`, `processing-unit`, `production-science-pack` | 800 × four | `aneutronic.lua:63` |
| `rf-aneutronic-fusion` | Power | `rf-direct-energy-conversion`, `rf-d-t-fusion`, `rf-gas-mixing` | 1500 × four | `aneutronic.lua:105` |

Three observations.

**The mod has no fission coupling of any kind today.** Grepping both modules for `uranium` and
`nuclear` returns six comment lines in `d-d.lua` and one in `reactor-logic.lua`, and not a single
prototype reference. No recipe consumes uranium, a fuel cell, or a heat pipe. The only entity name
shared with vanilla's fission neighbourhood is `steam-turbine`, and that is an *unlock*, not an
ingredient (`d-d.lua:39`).

**The question is already recorded in the code, framed the way this note finds it.**
`RealisticFusion/prototypes/technology/d-d.lua:9–19`, verbatim:

> That invariant has a second half, which this technology failed on review: the chain has to be
> usable at the far end as well as buildable at the near one. `rf-heat-exchanger` emits 500 C steam
> and vanilla unlocks the only thing that drinks it -- `steam-turbine` -- from `nuclear-power`, behind
> uranium processing. So a player could research fusion, build the whole chain, and have nowhere
> to put the steam. The turbine is therefore unlocked here.
>
> […] Making `nuclear-power` a prerequisite instead would avoid it and gate fusion behind fission,
> which is a far bigger claim about this mod than a recipe unlock is.

So the mod's current position is not an oversight — it is a deliberate deferral, and this note is the
material for closing it.

**ADR 0010 names seven Power technologies and this would not add one.** A prerequisite edge is not a
new prototype, so unlike `rf-hc-turbine`'s home (`d-t.lua:61–71`) or a hypothetical `rf-turbine`, this
change does not extend ADR 0010's declared set. It changes an edge, which is a smaller kind of change
to make and a larger kind of claim to make.

## 2b. The rule that already governs prerequisites here — and `nuclear-power` cannot satisfy it

This is the crux, and it turns the question from a matter of taste into a matter of kind.

`RealisticFusion/prototypes/technology/d-d.lua:1–19`, in full:

```lua
-- Power's technologies may depend on Core's; the reverse never happens (ADR 0010). This one takes
-- rf-deuterium-extraction because a reactor with no deuterium is scenery.
--
-- The vanilla prerequisites are named for their ingredients rather than their flavour: every item
-- the recipes above use has to be unlockable inside this technology's own prerequisite closure,
-- or a player can research fusion and be unable to build it.
--
-- That invariant has a second half, which this technology failed on review: the chain has to be
-- usable at the far end as well as buildable at the near one. rf-heat-exchanger emits 500 C steam
-- and vanilla unlocks the only thing that drinks it -- steam-turbine -- from nuclear-power, behind
-- uranium processing. So a player could research fusion, build the whole chain, and have nowhere
-- to put the steam. The turbine is therefore unlocked here.
--
-- Two consequences, both deliberate. Unlocking a recipe a vanilla technology also unlocks is
-- harmless -- researching nuclear-power later simply unlocks it again. But it does put the turbine
-- in a player's hands before nuclear power, where an ordinary boiler can drive it; that is a
-- change to vanilla progression, small and stated rather than smuggled. Making nuclear-power a
-- prerequisite instead would avoid it and gate fusion behind fission, which is a far bigger claim
-- about this mod than a recipe unlock is.
```

**The rule is not flavour-based, it is mechanical, and it has two halves.** Both are enforced by
running the game, per this repo's standard.

| Half | What it demands | Enforced where |
|---|---|---|
| **Buildable at the near end** | every ingredient of a recipe a technology unlocks is reachable inside that technology's own prerequisite closure | `scripts/check-blanket.ps1:296–304` (for `rf-blanket-breeding`), `scripts/check-hc.ps1:177–185` (for `rf-d-t-fusion`), `scripts/check-aneutronic.ps1:243–257` |
| **Usable at the far end** | every tier of ours that makes steam has something inside its own closure that drinks it for electricity | `RealisticFusion/control.lua:621`, called at `:916`; documented in `scripts/load-check.ps1:67–72` |

**Correction to how that was described to me: the buildable half is enforced per-technology by
individual rigs, not globally.** Three rigs hard-code three roots — `research_closure("rf-blanket-breeding", {})`
at `check-blanket.ps1:304` and `research_closure("rf-d-t-fusion", {})` at `check-hc.ps1:185`. The rule
is stated as general in the comments and is checked for three of the mod's eleven technologies.
`rf-d-d-fusion` — the one a `nuclear-power` edge would most likely land on — is **not** among them.

**Second correction, and this one is new since the brief was written: the far-end half is now
enforced.** `check_steam_sinks()` exists in `RealisticFusion/control.lua:621` and is the tenth
load-time invariant. **It is an uncommitted working-tree change made by another teammate during this
session, not committed code** — I read it as the current state per the repo's own guidance, and flag it
because a reader checking `main` will not find it. Its header comment settles this question's mechanism
half outright:

> This check is deliberately indifferent to WHICH answer holds -- it looks for any reachable sink, so
> the decision could be revisited in favour of an rf-turbine or a nuclear-power prerequisite without
> touching it. What it refuses is having no answer at all, which is the state #23 shipped and review
> caught by reading.

### Could `nuclear-power` ever be justified under that rule? No — and this is checkable

**The buildable half: no.** `nuclear-power` unlocks exactly five recipes — `nuclear-reactor`,
`heat-exchanger`, `heat-pipe`, `steam-turbine`, `uranium-fuel-cell`
(`base/prototypes/technology.lua:5117`). The complete set of non-`rf-` prototypes that any recipe in
either module consumes, extracted from all nine recipe files in `RealisticFusion/prototypes/recipes/`
and `RealisticFusionCore/prototypes/recipes/`, is:

```
advanced-circuit  concrete  copper-plate  electronic-circuit  engine-unit
pipe  processing-unit  steel-plate  sulfur  water
```

**Ten items, and not one of them is unlocked by `nuclear-power`.** There is no ingredient anywhere in
this mod that a fission technology gates. (Six entity prototypes in `RealisticFusion/prototypes/entities.lua`
are `table.deepcopy` of vanilla's `heat-exchanger` and `steam-turbine` templates — lines 100, 192, 242,
301, 459, 548 — but that is a prototype-stage read of a data table, not a recipe ingredient, and it puts
nothing in any closure.)

**The far-end half: it could have been, once, and no longer can.** Before `d-d.lua:39` unlocked
`steam-turbine`, the steam sink was genuinely unreachable and `nuclear-power` would have satisfied the
rule by supplying it. That is exactly why #36's second option exists. But the answer shipped, and
`check_steam_sinks()` accepts *any* reachable sink by construction — so the rule is satisfied today and
would be satisfied by two of #36's three answers.

**So, stated plainly as asked: adding `nuclear-power` would be the first prerequisite in this
repository chosen for progression rather than closure.** Every existing vanilla prerequisite has a
mechanical reason — `advanced-circuit`, `concrete` and `processing-unit` are there because unlocked
recipes consume them, and `chemical-science-pack`, `production-science-pack` and `fluid-handling` are
there because the research itself needs the pack (`aneutronic.lua:66–74` spells that second case out).
A `nuclear-power` edge would be justified by neither. **That is what `d-d.lua:17–19` means by "a far
bigger claim about this mod than a recipe unlock is"** — not that the claim is wrong, but that it is a
different kind of edge from every edge the tree currently has, and would be the precedent for
progression-shaped prerequisites in a tree that has so far only had closure-shaped ones.

### And #32 already shipped the third answer's pattern

`rf-hc-turbine` is not a new kind of prototype — `RealisticFusion/prototypes/entities.lua:301`:

```lua
local hc_turbine = pin(table.deepcopy(data.raw["generator"]["steam-turbine"]), "rf-hc-turbine", {
```

with `fluid_usage_per_tick = 10`, `maximum_temperature = 500`, `max_power_output = "58.2MW"`, and
Krastorio 2's advanced-steam-turbine art rather than a placeholder. Its recipe is 150 steel + 60
advanced circuits + 50 concrete + 50 pipe (`RealisticFusion/prototypes/recipes/hc.lua:38–47`) —
nothing fissile, and every ingredient already inside `rf-d-t-fusion`'s closure.

**So the mod already ships its own steam turbine.** #36's third option — *"Ship an `rf-turbine`"* — is
the same `pin(table.deepcopy(...))` pattern one tier down at vanilla's 1 unit/tick, with the art
question already answered by the same K2 source. That does not make it free (a new entity, item, recipe
and locale entry, and it *would* extend ADR 0010's declared set, which `d-t.lua:63–66` notes is Truls's
call), but it is materially cheaper than the ticket's framing suggests, and it is the only option that
answers #36 without either changing vanilla progression or depending on a fission technology.

## 3. What the three predecessors did — unanimous

| Mod | File | Line | What it says |
|---|---|---|---|
| Realistic Fusion Power 1.8.18 (1.1) | `prototypes/technology/technology.lua` | **143** | `prerequisites = {"nuclear-power"}` on `rfp-fusion-theory` |
| Durikkan's port 1.9.2 (2.0) | `prototypes/technology/technology.lua` | **143** | `prerequisites = {"nuclear-power"}` on `rfp-fusion-theory` |
| The four-module redesign | `RealisticFusionCore/prototypes/technology/technology.lua` | **116** | `prerequisites = {"nuclear-power"}` on `rf-fusion-theory` |

Paths are relative to `C:\src\factorio\_reference\RealisticFusionPower_1.8.18\RealisticFusionPower_1.8.18\`
and `...\RealisticFusionPowerPort_1.9.2\RealisticFusionPowerPort_1.9.2\`; the redesign's file was
fetched with `gh api repos/4881e05257b099383da78c50269d2ceb/realistic-fusion-dev/contents/...`.

Four things about that, each of which changes how much weight the unanimity carries.

**The port did not re-decide it.** `diff` on the two 709-line technology files shows differences in
exactly two kinds of place: the `__RealisticFusionPower__` → `__RealisticFusionPowerPort__` prefix in
27 icon paths, and five research `count` values. The `nuclear-power` line is untouched. Durikkan
carried it rather than confirming it, so this is one decision and two copies of it, not two decisions.

**`rfp-fusion-theory` unlocks nothing.** The whole prototype is a name, an icon, a cost of
`sm * 500` (`sm * 1000` in the port) at three packs, and one prerequisite. It has no `effects` table at
all. It exists solely to be the root of the tree and to attach the fission gate — which is, to be fair
to it, the cleanest possible implementation: one node to move if the decision changes.

**It gated *everything*, including the fuel chain.** In the predecessors, `rfp-deuterium-extraction`
takes `rfp-fusion-theory` as its prerequisite (`technology.lua:118`), so heavy water itself was behind
fission. This repo deliberately inverted that direction — `deuterium.lua:1–4` states it: *"None of them
takes a Power technology as a prerequisite -- that direction is the explicit inversion of the port's
tree."* **A `nuclear-power` prerequisite on this repo's tree therefore has a shape choice inside it
that the predecessors never faced**: does it go on Core's `rf-heavy-water` (the predecessors' shape,
gating water chemistry behind uranium) or on Power's `rf-d-d-fusion` (fission gates *reactors*, not
extraction)?

**The predecessors' gate also solved the steam problem, and they never said so.** They ship an
`rfp-heat-exchanger` (`prototypes/technology/technology.lua:194`) unlocked from `rfp-fusion-reactor`,
and nothing anywhere in either mod unlocks `steam-turbine` — grepping all Lua in 1.8.18 for
`nuclear-power` returns exactly two hits, the gate itself and an unrelated `bob-nuclear-power-3` in the
`bobpower` compatibility patch. So their players got the turbine from `nuclear-power`, because the gate
guaranteed they had it. **#36's problem and the `nuclear-power` gate are the same fact seen from two
ends**, and the predecessors got the fix for free without ever writing it down as one.

**And the predecessors did not revisit the gate for overhauls.** The Space Exploration compatibility
patch (`compatibility-patches/space-exploration/prototypes/technology/technology.lua`) rewrites science
pack ingredients for fourteen technologies and re-parents four of them — but leaves
`rfp-fusion-theory.prerequisites` alone (it touches only `.unit.ingredients` on that node, lines 4–8).
Whatever else SE moved, the fission gate was allowed to stand.

## 3b. And Krastorio 2 does it too — a third-party overhaul on the same side

Found while checking what K2 does *to* `nuclear-power`, and it is the more decision-relevant half.
`kr-fusion-energy` (`prototypes/technologies/utility-science-pack.lua:114`):

```lua
prerequisites = { "kovarex-enrichment-process", "kr-lithium-processing", "nuclear-power", "utility-science-pack" },
effects = {
  { type = "unlock-recipe", recipe = "kr-fusion-reactor" },
  { type = "unlock-recipe", recipe = "kr-advanced-steam-turbine" },
  { type = "unlock-recipe", recipe = "kr-heavy-water" },
```

**K2 gates its fusion reactor behind `nuclear-power` *and* behind `kovarex-enrichment-process`** — a
stricter gate than any of the three predecessors, since Kovarex is one step past nuclear power and is
not in `nuclear-power`'s own closure (§1). K2 also puts `nuclear-power` on the path to
`kr-nuclear-locomotive` (`prototypes/technologies/production-science-pack.lua:79`).

So the tally on precedent is not "three predecessors against vanilla" but **four mods for, and the base
game against.** That is worth stating plainly because it cuts the other way from §6's mechanism
finding: the overhaul most likely to be running alongside this mod is one that already treats fission as
the prerequisite of fusion, so a player arriving from K2 would find a gate unsurprising and its absence
the odd choice. It also means the two mods' fusion tiers would sit at noticeably different depths
without one — K2's at `utility-science-pack` plus Kovarex, this mod's at `chemical-science-pack`.

**What it is not evidence of.** K2 is a full overhaul that rebalances vanilla's reactor to 250 MW and
already ties reprocessing to tritium ([`fission.md`](fission.md) §2); it is arranging its own
progression across a whole tree, which is a different problem from a standalone mod choosing what to
depend on. And [ADR 0007](../adr/0007-coexistence-without-integration.md) is explicit that this mod
does not reconcile with K2's fusion. Matching K2's gate would be coincidence, not integration — but the
coincidence is real and a player would read it as intent.

## 4. The physics, tested against ADR 0014

[ADR 0014](../adr/0014-realistic-means-theoretically-possible.md) fixes the standard, and the standard
is what decides this section rather than my own reading:

> **"Realistic" means the fusion chains are real and the numbers are anchored in what is theoretically
> possible — not in what can be built today.** Reactions, branching ratios, energy releases and
> cross-sections are physics and are not negotiable. Confinement time, density, purity and capture
> efficiency are engineering, and this mod is free to place them anywhere the physics permits,
> including well beyond the present state of the art.

That definition is unusually decisive here, because it draws the line exactly where the
fission-before-fusion argument sits. **A tritium *supply chain* is not physics.** It is procurement,
regulation and plant engineering — the second category, the one ADR 0014 explicitly frees the mod to
place wherever the physics permits.

### The case for: fission is where tritium actually comes from

Primary, from **UKAEA CCFE-PR(17)67** (Kovari, Coleman, Cristescu & Smith, *Tritium resources
available for fusion reactors in the long term*), read from the PDF directly:

> "The tritium required for ITER will be supplied from the CANDU production in Ontario, but while
> Ontario may be able to supply 8 kg for a DEMO fusion reactor in the mid-2050s, it will not be able to
> provide 10 kg at any realistic starting time."

> "In theory, a lack of tritium could be overcome at any time, **since it can be generated in any
> fission reactor**, but the technical, political and economic issues associated with doing so are
> significant."

> "The US has started producing tritium for defence purposes by irradiating tritium-producing burnable
> absorber rods containing lithium in a commercial (government-owned) light water power reactor."

> "The production rate is limited by the tritium permeation into the coolant, not by neutronic
> considerations, and is at present about **450 g/year per reactor** […] The TVA has, however, received
> a license amendment to increase production to about **1.2 kg/year in a single reactor**."

> "The cost for production at light water reactors was estimated to be $40 million - $60 million per kg
> (1999 dollars) - much greater than the **$25,000/g currently charged by Ontario Power Generation**."

So there are two real fission routes and both are in service: the CANDU heavy-water moderator
by-product, which is where ITER's tritium is coming from, and deliberate ⁶Li irradiation in a light
water reactor, which is where the US weapons stockpile's tritium comes from. **Every gram of tritium
that has ever fuelled a fusion experiment came out of a fission reactor.** That is as strong as the
physical argument gets, and it is genuinely strong.

Two weaker supporting arguments, offered as they are rather than dressed up:

- **A thermonuclear weapon does require a fission primary.** True, physically, and not negotiable. But
  it is a statement about weapons, and this repo's Weaponry module is out of ADR 0002's v1 scope
  anyway.
- **Fusion materials qualification is done in fission facilities.** Breeder-blanket and first-wall
  materials are irradiated in fission test reactors because that is where the neutron flux is. I did
  **not** source this primarily and it is offered as context, not evidence — and it is an argument
  about *research programmes*, not about what a working reactor consumes.

### The case against: it is a start-up problem, and it does not touch D-D

Three findings, in increasing order of how much they matter.

**A fusion plant is designed specifically not to depend on fission tritium.** The ITER Organisation's
own tritium-breeding page states it plainly: *"A future fusion plant producing large amounts of power
will be required to 'breed' all of its own tritium."* Breeding is the design intent, not a stretch
goal, and the CANDU supply is what gets the first machine lit.

**Kovari et al. price the dependency and find it a start-up inventory, not a standing input.** Their
Table 2's assumptions, quoted from Figure 1's caption:

> "burn-up = 2%, **tritium breeding ratio for DT reactions = 1.1**, tritium production ratio for DD
> reactions = 0.72, tritium residence time in the breeding system = 3 h […]"

and the conclusion:

> "It is in theory possible to start up a fusion reactor with little or no tritium, but at an estimated
> cost of $2 billion per kilogram of tritium saved, it is not economically sensible."

Two things in there land squarely on this repo. The paper's assumed **TBR of 1.1 is the same 1.1 this
mod's lithium blanket ships** ([`d-t-ignition.md`](d-t-ignition.md), verified in game by
`scripts/check-blanket.ps1` at a measured 1.1000) — so the mod's blanket is already the literature's
self-sufficient reactor, and a reactor with TBR > 1 has no standing fission dependency by construction.
And **"tritium production ratio for DD reactions = 0.72"** is the other route the mod already ships:
D-D breeding, which this repo implements as a by-product of the same reaction count that makes the
power. The paper treats both as the reasons a fusion plant escapes the fission supply, not as
alternatives to it.

**The decisive one: the mod's first tier is D-D, and D-D contains no tritium.** A D-D reactor consumes
deuterium, which comes from water by isotope separation and has nothing to do with a fission reactor at
any point. If the physical argument were applied literally, the `nuclear-power` edge would belong on
**`rf-d-t-fusion`** — the technology that first burns a triton — and not on `rf-d-d-fusion`. And by the
time a player reaches `rf-d-t-fusion` they hold `rf-tritium-breeding` and the isotope collector, i.e.
they are breeding their own, exactly as the ITER page says a plant must. **So the tier a gate on
`rf-d-d-fusion` would actually block is the one tier with no physical fission dependency whatsoever,
and the tier that has one already solves it the way the real design does.**

### What that leaves

Under ADR 0014's standard the physical argument does not survive as a *requirement*. It survives as
**flavour with an unusually good citation** — the tritium a fusion programme starts with really does
come out of fission, and a mod that said so would not be making anything up. Whether that is worth a
compulsory branch is a design question, and it is the design question §6 lays out.

One thing worth naming so it is not mistaken for physics: **there is no defensible physical reading
under which fission gates *deuterium extraction***, which is what the predecessors' tree actually did
(§3). Heavy water is Girdler sulfide chemistry. If a gate is wanted, the predecessors' placement is
the one option this note can say is wrong on the mod's own stated standard.

## 5. Gameplay: does the gate solve #37, or restate it?

### What #37 established

From [#37](https://github.com/trulsjo/realistic-fusion-refreshed/issues/37) item 4, the minimum a
single fusion line draws before any fusion power exists:

| | |
|---|---:|
| `rf-reactor` confinement heating | 50 MW |
| `rf-heater` | 5 MW |
| `rf-electrolyser` × 2 | 400 kW |
| `rf-deuterium-extractor` | 400 kW |
| chemical plant (H₂S) | ~210 kW |
| **total** | **~56 MW** |

and the issue's own comparison: *"At that tier, 56 MW is about **62 vanilla steam engines** standing
idle until the reactor lights. Vanilla nuclear, the comparable tier, needs no startup power at all."*
That 62 checks out against the prototype data — a `steam-engine` at `effectivity = 1`,
`fluid_usage_per_tick = 0.5` and `maximum_temperature = 165` delivers 900 kW
(`base/prototypes/entity/entities.lua:1766–1768`), and 56 ÷ 0.9 = 62.2. Item 4b adds that the draw
peaks at 60 MW, so a plant must be sized ~20 % above the average.

### Does gating on `nuclear-power` fix that?

**It makes the answer available; it does not provide it.** A prerequisite unlocks a recipe. It does not
build a reactor, and nothing stops a player researching `nuclear-power` and then powering their fusion
line with 62 steam engines anyway. So as a *fix* for the 56 MW entry cost, the gate is indirect at
best.

What it does change is the **honesty of the tech tree**, and that is not nothing. Today a player can
reach `rf-d-d-fusion` having never been given a compact power source, and the mod hands them a reactor
that demands 56 MW continuously with no acknowledgement of where it comes from. With the gate, the mod
can point at something: the minimum vanilla nuclear plant that covers the draw is **two adjacent
reactors** — `neighbour_bonus = 1` means each reactor with one neighbour runs at 80 MW, so a pair is
160 MW electrical, comfortably over the 60 MW peak, where a lone 40 MW reactor is not enough
(`base/prototypes/entity/entities.lua:8578,8579`). That is a legible, buildable answer to a problem the
mod currently poses without one.

The counter-argument is equally real and is about how #37 gets settled. #37's own options include
lowering `heating_power_w`, letting the plasma hold heat when unpowered, and a low-power standby. **If
any of those is taken, the 56 MW problem shrinks or disappears and the gate loses the practical half of
its case** — leaving only the flavour argument of §4. So this decision is downstream of #37 in a way
worth noticing: settling #37 first changes what this question is about.

There is also a reading in which the gate makes #37 *worse*. #37's second edge is that the draw never
stops, so a brownout cools the plasma, which cuts output, which deepens the brownout. A player whose
56 MW comes from a fission plant they built specifically to feed fusion has coupled the two systems: a
fuel-cell interruption now takes down the fusion line too. Whether that is drama or a trap is the same
open question #37 already asks.

### What the gate costs a player, quantified

Computed by differencing prerequisite closures: the vanilla technologies a `nuclear-power` prerequisite
would add to `rf-d-d-fusion`'s existing closure are **exactly three**.

| Added technology | Science cost | Note |
|---|---:|---|
| `uranium-mining` | 100 × (auto + log + chem) | grants `mining-with-fluid` |
| `uranium-processing` | **none** | `research_trigger`, `mine-entity` `uranium-ore` — a mining action, not research |
| `nuclear-power` | 800 × (auto + log + chem) | |
| **total** | **900 units at the same three packs** | |

Against that, the mod's own chain to first fusion is 100 + 200 + 500 = **800 units**. **The gate would
slightly more than double the research a player pays to reach their first fusion reactor**, at the same
science tier — no new pack, no tier jump. Sulfuric acid is already inside the existing closure
(`sulfur-processing` is reached via `chemical-science-pack`), so the acid for uranium mining costs
nothing extra.

The cost that does not show up as science:

- **Forced uranium prospecting.** `uranium-ore` has `has_starting_area_placement = false`
  (`base/prototypes/entity/resources.lua:169,173`), and
  `uranium-processing` is a `research_trigger` on mining it — so the player must find a patch off the
  starting area, run acid to it, and mine it, before the technology exists. **This is the real cost of
  the gate**, and it is a map-dependent, exploration-shaped cost rather than a research one. The
  `research_trigger`/`unit` relationship is per the 2.0.77 API docs: *"research_trigger: Mandatory if
  `unit` is not defined"*
  (<https://lua-api.factorio.com/2.0.77/prototypes/TechnologyPrototype.html>, page reports 2.0.77).
- **A second power system the player may not want.** Some players skip vanilla nuclear on purpose. The
  gate makes an optional branch compulsory, and §1 established that vanilla itself treats it as
  optional — `nuclear-power` is in no science pack's closure and not in `rocket-silo`'s.
- **Space Age planet ordering: no effect.** `uranium-ore` autoplaces on Nauvis only
  (`base/prototypes/planet/planet-map-gen.lua:26,113`; Space Age adds no other planet with it), and
  `nuclear-power` sits at the three-pack tier, so it is reachable before any departure. A Space Age
  player would not be blocked by planet order — but a player who has already left Nauvis and wants
  fusion on another planet would have to have done Nauvis uranium first.

## 6. Is a technology prerequisite even the right mechanism?

Three mechanisms are available, and they differ in more than strength.

### A technology prerequisite

**What it does:** blocks research until `nuclear-power` is researched. Cheap — one string in one array.
Reversible. Visible in the tech tree, which is where a player looks.

**Where it breaks, and this is the load-bearing finding of this section.** `nuclear-power` may be
present, renamed, re-parented, or stripped of its unlocks by overhaul mods, and this is not
hypothetical — it is true of both overhauls whose source I read:

| Mod | What it does to `nuclear-power` | Where |
|---|---|---|
| Krastorio 2 2.1.3 | keeps it; **adds `kr-rare-metal-processing` as a prerequisite**; cuts cost 800 → 500; and depends on it from `kr-fusion-energy` and `kr-nuclear-locomotive` (§3b) | `prototypes/updates/base/technologies.lua:29,194`; `prototypes/technologies/{utility,production}-science-pack.lua:128,79` |
| Bob's (`bobpower` 2.1.0) | keeps it; **removes the `steam-turbine` unlock**; removes the `heat-exchanger` and `heat-pipe` unlocks; adds `bob-heat-pipe-2` as a prerequisite | `prototypes/technology/steam-turbines.lua:2`, `heat-exchangers.lua:2`, `nuclear.lua:2–3` |
| Bob's (`bobplates` 2.1.1) | adds `bob-lead-processing` as a prerequisite | `prototypes/technology/technology-nuclear.lua:36` |

Two consequences:

**Under Bob's, the gate would not solve #36.** `bobpower` moves `steam-turbine` to
`bob-steam-turbine-1`, whose prerequisites are `bob-steam-engine-3` and `chemical-science-pack`
(`prototypes/technology/steam-turbines.lua:7–11`), and it does this behind the startup setting
`bobmods-power-steam` — so under Bob's, whether `nuclear-power` unlocks the turbine at all depends on a
player's mod settings. **A `nuclear-power` prerequisite is therefore a fix for #36 that works in vanilla
and Space Age and silently fails under one of the mod families the coexistence survey lists as viable.**
If #36 is the reason for the gate, this is the strongest argument against choosing this mechanism for
that reason.

**Under Krastorio 2, the gate drags in K2's own chain.** `kr-rare-metal-processing` becomes a
transitive prerequisite of fusion. That is not a crash and not a bug — but it is this mod's progression
being reshaped by a mod it does not target, which is the failure mode
[ADR 0007](../adr/0007-coexistence-without-integration.md) is about. ADR 0007's Decision names
*"unlocking through another mod's technology tree"* as integration and puts it out of v1 scope. Vanilla
`base` is not "another mod" in the sense ADR 0007 means — it is always present, and `advanced-circuit`
and `concrete` are already prerequisites of `rf-d-d-fusion` — so a `nuclear-power` edge does not
violate that ADR on its face. But it does hand overhaul mods a lever on this mod's progression that
they do not currently have.

**And it is not verified for the rest of the set.**
[`mod-set-coexistence-targets.md`](mod-set-coexistence-targets.md) is explicit that it **commits to
nothing** — *"None of the project's open decisions are settled here"* — and lists Space Exploration,
Angel's, MadClown's (including `Clowns-Nuclear`, which K2 declares `!` against), SeaBlock NG and RITEG
as viable families. I read the two whose source is local. **What SE, SeaBlock NG and MadClown's Nuclear
do to `nuclear-power` is unverified**, and MadClown's Nuclear is precisely the mod most likely to move
it.

### A recipe-ingredient dependency

**What it would look like:** `rf-reactor`'s recipe consumes something from the fission chain. There is
no physically honest candidate. Uranium is not a fusion reactor component; a heat pipe is the wrong
shape (the mod's reactor emits a fluid, not heat — see
[#44](https://github.com/trulsjo/realistic-fusion-refreshed/issues/44)); and a fuel cell in a fusion
reactor recipe would be exactly the "chemistry standing in for physics" that
[ADR 0005](../adr/0005-real-time-fusion-simulation.md) exists to prevent.

The one candidate that *is* physical is the reverse of a gate: **tritium from a fission source**, which
is [`fission.md`](fission.md)'s Option B and is a whole module rather than an ingredient.

**Where it breaks:** worse than the technology edge, not better. A missing item name is a load crash
rather than a re-parented technology, and it is harder for a player to see. It also fails ADR 0007
harder: an ingredient dependency on a prototype an overhaul removed is the failure the coexistence
survey names — *"an item another mod removed, an icon path that moved"*.

### Nothing — the status quo

**What it costs:** the mod stays silent about where 56 MW comes from, and #36's steam-turbine unlock
stays as the small documented change to vanilla progression that `d-d.lua:14–19` already describes.

**What it buys:** the mod loads and progresses identically under every mod set, because it depends on
nothing fissile. That is a real property and it is the one the mod currently has.

## 7. Where this note stands relative to `fission.md`

**Agreed, and this note strengthens it.** `fission.md` §5 concludes that *"the real world's tritium for
fusion comes from fission"* and that this is *"the finding that bears hardest on this pack"*. Reading
Kovari et al. directly confirms it and adds the second route the earlier note did not have: deliberate
⁶Li irradiation in a light water reactor, at 450 g/year per reactor rising to a licensed 1.2 kg/year,
against OPG's CANDU tritium at $25,000/g. Both routes are in service today.

**Agreed, with a correction of emphasis.** `fission.md` §1 states that Space Age *"adds **no** fission
content"* and is *"a consumer of vanilla's chain"*. True, and this note adds the complementary fact it
did not need at the time: **Space Age's fusion line is not a consumer of vanilla's fission chain
either.** No prerequisite, no ingredient, computed both ways. That is direct evidence on this question
and it was not in the earlier note.

**Narrowed.** `fission.md` establishes the tritium link as a reason a *fission module* could exist in
this pack. This note finds that the same evidence does **not** carry across to a *prerequisite*. The
two are different claims: "fission is where tritium comes from" argues for fission as a **supplier**
downstream of the fusion tree, which is `fission.md`'s Option B; a prerequisite makes fission a
**gate** upstream of it, which the physics does not support at `rf-d-d-fusion` and barely supports at
`rf-d-t-fusion` given the mod already ships two breeding routes at TBR 1.1 and 0.25.

**Extended.** `fission.md` did not read the predecessors' technology trees. Their unanimity is new
here, and so is the observation that their gate silently solved #36 for them.

**Not contradicted anywhere.** I found nothing in `fission.md` that this note's sources undermine.

## 8. Options, with what each would cost

**These are options, not a recommendation.** Tech-tree shape and progression are Truls's under
`CLAUDE.md`, and the two that change an edge would need at minimum a note in `CONTEXT.md` and a
technology-file comment — #36's acceptance criteria already say an ADR if the module's public shape
moves.

### A. No prerequisite. The status quo.

`rf-d-d-fusion` keeps unlocking `steam-turbine` (`d-d.lua:39`) and the mod stays fission-free.

- **For:** the mod depends on nothing fissile, so it progresses identically under every mod set in the
  coexistence survey; matches how Factorio 2.0.77 itself gates fusion; requires no decision and no
  ADR; the small vanilla-progression shift is already documented at `d-d.lua:14–18`.
- **Against:** the mod stays silent about the 56 MW entry cost; the steam-turbine-before-nuclear shift
  remains, which #36 exists because nobody chose; and it declines the best-cited piece of flavour in
  the subject.
- **Cost:** none. Closes #36 as "keep the unlock".

### B. `nuclear-power` on `rf-d-d-fusion`. The predecessors' answer, in this repo's shape.

- **For:** all three predecessors did it and Krastorio 2 does it more strictly still (§3b); solves #36
  completely in vanilla and Space Age, with the turbine unlock deleted rather than kept; gives the 56 MW
  entry cost a legible answer (two adjacent reactors, 160 MW); one string of code.
- **Against:** the physics does not support gating *D-D* on fission (§4) — the tier it blocks is the
  one with no tritium in it; it makes a branch vanilla treats as fully optional compulsory; **it does
  not solve #36 under Bob's**, where `nuclear-power` no longer unlocks the turbine and the behaviour
  depends on a startup setting; it hands K2's `kr-rare-metal-processing` a place in this mod's
  progression; and the 900 extra science units plus off-starting-area uranium prospecting is a real toll
  on the first fusion reactor.
- **Cost:** one line, plus deleting `d-d.lua:39` and its comment, plus a `CONTEXT.md` entry. The
  verification is not free: #36's third acceptance criterion — *a player researching `rf-d-d-fusion` and
  nothing else can still convert the exchanger's steam to electricity, verified through the tech tree* —
  would need re-running, and honestly ought to be re-run under Bob's too, which `scripts/` has no
  harness for.

### C. `nuclear-power` on `rf-d-t-fusion` only. The physically literal placement.

D-D stays fission-free; the gate lands on the first technology that burns a triton.

- **For:** the only placement §4's evidence actually supports — every triton in a real fusion
  experiment came from a fission reactor, and D-D contains none; leaves the entry tier unchanged, so
  #37's 56 MW question is untouched by it; a player reaching D-T has already paid for a factory and 900
  science units is a smaller fraction of it.
- **Against:** it does **not** solve #36, because the steam problem is at the D-D tier — so #36 needs
  answering separately anyway, and the turbine unlock or an `rf-turbine` stays; and it is arguably the
  weakest gate of the three, since the player it blocks is already breeding their own tritium two ways,
  which is exactly what the ITER page says a plant must do.
- **Cost:** one line in `d-t.lua`. Leaves #36 open.

### C2. Ship an `rf-turbine` at the D-D tier. #36's third answer, priced against §2b.

No prerequisite and no vanilla unlock: the mod supplies the thing that drinks its own steam, the way
`rf-hc-turbine` already does one tier up.

- **For:** the only answer that resolves #36 without either shifting vanilla progression or depending
  on a fission technology; keeps every prerequisite closure-shaped (§2b); the pattern, the art source
  and the arithmetic are already proven at `entities.lua:301`; immune to what any overhaul does to
  `nuclear-power`, which neither A nor B is.
- **Against:** it **extends ADR 0010's declared prototype set**, which `d-t.lua:63–66` flags as Truls's
  decision rather than a side effect — the same reason `rf-hc-turbine` went into `rf-d-t-fusion`
  instead of getting its own technology; and it adds an entity, item, recipe and locale entry for a
  machine vanilla already has.
- **Cost:** low-to-medium and lower than #36 implies, because §2b establishes the pattern is already
  in the repo. Needs a decision on ADR 0010's set first.

### D. Flavour without a gate.

No prerequisite. Instead the connection is stated where a player reads it — a technology description or
Factoriopedia line noting that the world's tritium comes from heavy-water fission reactors — and #36 is
closed by one of its own three options.

- **For:** keeps the citation and the flavour without making an optional vanilla branch compulsory;
  costs a player nothing; no mod-compatibility surface at all; and it is the reading ADR 0014's
  definition points at, since a supply chain is engineering rather than physics.
- **Against:** locale text is not progression, so it settles nothing about #36 or #37; and a player who
  wanted the mod to *mean* something by the connection gets a sentence instead of a mechanic.
- **Cost:** one or two locale strings. Leaves #36 and #37 exactly where they are.

### E. Reverse the direction — fission as a tritium *supplier*.

[`fission.md`](fission.md)'s Option B, recorded here because it is the option this question keeps
pointing at. A heavy-water reactor downstream of Core that produces `rf-tritium`, rather than a
technology upstream that gates fusion.

- **For:** the only arrangement in which the tritium evidence is doing what the evidence actually says
  — fission supplies fusion rather than preceding it; consumes Core fluids that already exist.
- **Against:** it is a module, not an edge, and out of [ADR 0002](../adr/0002-v1-scope-and-module-split.md)'s
  v1 scope; it adds a third breeding route where `CONTEXT.md` names two; and it answers neither #36 nor
  #37.
- **Cost:** high — a superseding ADR and a module. See `fission.md` §8 for the full pricing.

### The question underneath

**Is the gate wanted for the physics, for #36, or for #37?** Each answer picks a different option, and
they do not overlap.

- For the **physics**, the placement is C, and C is the weakest gate.
- For **#36**, B and C2 both work and A already does — B has a verified failure under Bob's (§6), and
  C2 is the only one of the three that no mod set can break.
- For **#37**, no gate does the work; #37 is settled by the reactor's own numbers, and a gate only
  makes the answer purchasable.

And §2b adds a constraint that sits underneath all of them: **there is no closure-based justification
for a `nuclear-power` edge, so choosing B or C means deciding that this tree may carry
progression-shaped prerequisites.** That is a precedent, not just an edge.

**That is a decision about what this mod is, and it is Truls's.**

## What is not settled, and what I could not verify

- **Whether the gate belongs on Core or Power, if one is wanted.** §3 shows the predecessors put it
  effectively on the fuel chain, which this repo deliberately inverted. B and C both assume Power.
  Gating Core's `rf-heavy-water` on `nuclear-power` is a fourth placement, not costed above because
  §4 finds no physical reading that supports it — but it is the predecessors' actual shape and a
  reader will otherwise wonder why it is absent.
- **What Space Exploration, SeaBlock NG and MadClown's Nuclear do to `nuclear-power`.** Not installed
  locally and not fetched. `Clowns-Nuclear` is the most likely of the three to move or replace it, and
  K2 declares `!` against it, so the combination is already impossible. The predecessor's SE patch
  leaving `rfp-fusion-theory.prerequisites` alone is evidence that SE keeps the technology, but it is
  evidence from a 1.1-era patch, not from SE's own current source.
- **Whether unlocking `steam-turbine` from `rf-d-d-fusion` actually breaks anything under Bob's
  today.** §6 establishes that `nuclear-power` stops unlocking it there. What the *current* repo does in
  that situation — unlock a recipe Bob's has re-homed — I did not test. `scripts/` has no harness that
  loads third-party mods; [#61](https://github.com/trulsjo/realistic-fusion-refreshed/issues/61) is the
  ticket for that.
- **Fusion materials qualification in fission test reactors.** Named in §4 as a supporting argument and
  **not sourced primarily**. Do not cite it from here.
- **The redesign's Power-side technology file.** I read
  `RealisticFusionCore/prototypes/technology/technology.lua`, which is where its `rf-fusion-theory` gate
  lives, and `heating-efficiency.lua` alongside it. I did not enumerate the redesign's other modules'
  technology files, so "the redesign gated fusion on `nuclear-power`" is verified at the root of its
  tree and not proven exhaustive across its four modules.
- ~~**`check_steam_sinks()` was read, not run.**~~ **Closed 2026-08-19.** It was an uncommitted change
  in `RealisticFusion/control.lua` and `scripts/load-check.ps1` when this note was written, read as the
  working tree's state and quoted from its own comments. It has since been run: `scripts/load-check.ps1`
  passes with it ("ten load-time invariants hold"), and removing `rf-d-d-fusion`'s `steam-turbine`
  unlock makes it fail with *"rf-d-d-fusion: unlocks rf-heat-exchanger, which makes steam at 500 C, and
  nothing reachable inside that technology's own prerequisites drinks it"* -- so the far-end half is
  enforced in fact and not only as written, and the check is known to be capable of failing. If those changes are revised or dropped before landing, §2b's second
  half moves with them — the §2b conclusion does not, because it rests on the ingredient set, which is
  committed code.
- **The buildable half is checked for three technologies, not eleven.** §2b states this, and it means a
  `nuclear-power` edge on `rf-d-d-fusion` would land on a technology no rig currently closure-checks.
  Whether that gap is worth closing is a separate ticket, not this decision.
- **Nothing was loaded in the game for this note.** Every claim above is from prototype source and
  computed closures. No map was created, no `scripts/check-*.ps1` was run, and `CLAUDE.md` is explicit
  that this says nothing about runtime. A prerequisite change would need `scripts/load-check.ps1` and
  #36's tech-tree verification before it could be called done.

## Sources

Primary, read directly:

- **Factorio 2.0.77 base and Space Age prototype data**, installed at
  `D:\SteamLibrary\steamapps\common\Factorio\data\`. `base/info.json` and `space-age/info.json` both
  report version 2.0.77. Files: `base/prototypes/technology.lua`,
  `base/prototypes/entity/entities.lua`, `base/prototypes/planet/planet-map-gen.lua`;
  `space-age/prototypes/technology.lua`, `space-age/prototypes/recipe.lua`. Prerequisite closures
  computed mechanically over both technology files.
- **Factorio API documentation, `TechnologyPrototype`**, pinned:
  <https://lua-api.factorio.com/2.0.77/prototypes/TechnologyPrototype.html> — page reports 2.0.77.
  Cited for `prerequisites` and for the `research_trigger` / `unit` relationship.
- M. Kovari, M. Coleman, I. Cristescu & R. Smith, *Tritium resources available for fusion reactors in
  the long term*, **UKAEA CCFE-PR(17)67**, Culham Centre for Fusion Energy.
  <https://scientific-publications.ukaea.uk/wp-content/uploads/CCFE-PR1767-1.pdf> — PDF fetched and
  text extracted; abstract, §1, §5, §6 and Figure 1/Table 2 captions quoted above.
- **ITER Organisation**, *Tritium breeding*, <https://www.iter.org/machine/supporting-systems/tritium-breeding>
  — quoted for *"A future fusion plant producing large amounts of power will be required to 'breed' all
  of its own tritium."*

Mod source, read directly:

- **Realistic Fusion Power 1.8.18**, `C:\src\factorio\_reference\RealisticFusionPower_1.8.18\` —
  `prototypes/technology/technology.lua`,
  `compatibility-patches/space-exploration/prototypes/technology/technology.lua`,
  `compatibility-patches/bobpower/data.lua`.
- **Realistic Fusion Power Port 1.9.2**, `C:\src\factorio\_reference\RealisticFusionPowerPort_1.9.2\` —
  same file, diffed against the above.
- **The four-module redesign**, `RealisticFusionCore/prototypes/technology/technology.lua`, fetched via
  `gh api repos/4881e05257b099383da78c50269d2ceb/realistic-fusion-dev/contents/...`.
- **Krastorio 2 2.1.3**, `C:\src\factorio\_reference\Krastorio2` (root `LICENSE` is LGPLv3) —
  `prototypes/updates/base/technologies.lua`, `prototypes/technologies/{production,utility}-science-pack.lua`.
- **Bob's mods**, installed at `%APPDATA%\Factorio\mods\` — `bobpower_2.1.0.zip`
  (`prototypes/technology/{steam-turbines,heat-exchangers,nuclear}.lua`) and `bobplates_2.1.1.zip`
  (`prototypes/technology/technology-nuclear.lua`). **`bobplates` carries no licence file**
  ([`fission.md`](fission.md) §2) — read as reference only, nothing liftable.

In this repository:

- `RealisticFusionCore/prototypes/technology/{deuterium,lithium,mixing}.lua`;
  `RealisticFusion/prototypes/technology/{d-d,d-t,blanket,aneutronic}.lua`.
- `RealisticFusion/prototypes/entities.lua` (the six vanilla deepcopies, and `rf-hc-turbine` at :301);
  `RealisticFusion/prototypes/recipes/*.lua` (all nine, for the ingredient set in §2b).
- `scripts/check-blanket.ps1`, `scripts/check-hc.ps1`, `scripts/check-aneutronic.ps1` (the closure
  rigs); `RealisticFusion/control.lua:621` and `scripts/load-check.ps1:67–72` — **uncommitted working
  tree**, see the caveat above.
- `CONTEXT.md`; ADRs [0002](../adr/0002-v1-scope-and-module-split.md),
  [0005](../adr/0005-real-time-fusion-simulation.md),
  [0007](../adr/0007-coexistence-without-integration.md),
  [0010](../adr/0010-v1-module-layout-and-prototype-set.md),
  [0014](../adr/0014-realistic-means-theoretically-possible.md).
- [`fission.md`](fission.md), [`d-t-ignition.md`](d-t-ignition.md),
  [`mod-set-coexistence-targets.md`](mod-set-coexistence-targets.md).
- Issues [#36](https://github.com/trulsjo/realistic-fusion-refreshed/issues/36),
  [#37](https://github.com/trulsjo/realistic-fusion-refreshed/issues/37),
  [#44](https://github.com/trulsjo/realistic-fusion-refreshed/issues/44),
  [#61](https://github.com/trulsjo/realistic-fusion-refreshed/issues/61).

# Quality, and what it does to this mod

Researched 2026-08-21. **Every API claim is pinned to Factorio 2.0.77**, which is the version this
repository loads against; the docs are read at `https://lua-api.factorio.com/2.0.77/` rather than at
`/stable/` or `/latest/`, both of which move.

Three kinds of evidence, kept separate throughout:

- **The prototype and runtime API docs at 2.0.77**, quoted.
- **Wube's own `quality` mod**, read off this machine at
  `D:\SteamLibrary\steamapps\common\Factorio\data\quality\`, version 2.0.77.
- **Measurement.** Which properties the engine actually multiplies is not declared in any prototype
  and cannot be read out of the files, so it was measured: a rig places one of every entity this mod
  ships at each of the five quality levels and reads back what the simulation reads —
  `fluidbox.get_capacity`, `electric_buffer_size`, the prototype getters, container inventory size.
  Run once with the bundled `quality` mod alone and once with `space-age` as well; **every number was
  identical**, so this note quotes one set.

**The rig is checked in as `scripts/probe-quality.ps1`** ([#97](https://github.com/trulsjo/realistic-fusion-refreshed/issues/97)).
Run it to reproduce the numbers below rather than taking them on trust:

    pwsh -File scripts/probe-quality.ps1             # the bundled quality mod alone
    pwsh -File scripts/probe-quality.ps1 -SpaceAge   # and again with space-age

Re-measured that way on 2026-08-27 against Factorio 2.0.77: 261 reported rows per run, **identical
between the two configurations** — which is the claim above, checked rather than remembered.

**Nothing runs it for you.** It is a probe rather than a check: it asserts nothing, exit 0 means it
ran and reported, and no check, bench or gate sweep invokes it — `load-check.ps1` included. So a
later engine version can change any number here and this document goes stale in silence unless
somebody types that command. The rig exists and is not wired; say that plainly rather than claiming a
guarantee the repository does not have.

## The short version

**Quality is not a danger to this mod's energy ledger, and the reason is a measurement rather than an
argument: fluid box capacity does not scale with quality.** Nor does the electric energy source's
buffer. Every quality-scaled generator scales its fluid usage and its power cap by exactly the same
factor — measured out/in = 1.000000 at all five levels — so no conversion anywhere in the chain gets
cheaper. `capture_efficiency` is a Lua constant that no prototype field feeds, so nothing quality
touches can reach it. **No combination of quality levels moves a reactor toward break-even without
fusion**; the arithmetic is in [The perpetual-motion question](#the-perpetual-motion-question).

What quality *does* do here is real but unremarkable, and one item on the list is a near-miss worth
knowing about:

- **`rf-heater` and all five Core machines run 2.5× faster at legendary for the same power.** That is
  vanilla's crafting-machine behaviour and it makes the whole fuel chain 2.5× cheaper in electricity
  per unit of deuterium. The largest real effect quality has on this mod.
- **`rf-heat-exchanger` and `rf-hc-exchanger` burn 2.5× the reactor energy and make 2.5× the steam.**
  Throughput only; the ratio is unchanged, so a legendary exchanger needs 2.5× the turbines.
- **`rf-lithium-blanket` holds 250 slots instead of 100.** Buffer, not rate: breeding is bounded by
  neutrons and by collector headroom, never by inventory.
- **`rf-reactor`'s `input_flow_limit` goes from 60 MW to 150 MW against an unchanged 50 MW spend**, so
  a legendary reactor rides out a brownout down to a third of supply where a normal one starts losing
  heating at five-sixths. This is the one place quality changes reactor *behaviour*, and it is the
  only entry on this list that a balance decision might want to keep.
- **`rf-reactor`'s own `energy_consumption` scales 1 W → 2.5 W.** That is the neutered boiler
  conversion the mod does not use. 2.5× of nothing.

And the near-miss: **had fluid box capacity scaled, a legendary `rf-reactor` would have held 2500
units of plasma in a `volume_m3` that is a Lua constant at 1000.** Density would have gone to
2.5×10²⁰ m⁻³, and because the reaction rate goes as `n²` at fixed volume that is **6.25× the fusion
power** — while `reactor-logic.lua` went on reporting a Q computed from a density it had assumed.
Still not perpetual motion; fusion is a genuine source in the ledger. But it would have made
`volume_m3` a lie and every number in `d-t-ignition.md` wrong for a legendary machine, silently. It
does not happen. It is worth writing down because it is exactly the failure the brief went looking
for, and because nothing in the prototype files says it does not happen.

## What quality is, for a reader who has not met it

Quality is a Space Age mechanic: every item, entity and piece of equipment can exist at one of five
grades, and a higher-grade building is better at its job. **Friday Facts #375**, 8 September 2023:

> Normal: base quality, no bonus. Uncommon: +30% bonus. Rare: +60%. Epic: +90%. Legendary: +150%.

and, on what the bonus means:

> Assembling machines/furnaces/labs are faster […] Nuclear reactors, boilers and steam engines have
> increased production […] Inserters move faster […] Mining drills deplete resources slower […]
> Beacons have lower power consumption

Higher-grade items are produced by chance, by putting **quality modules** in the machine that makes
them; the same FFF calls the feature "completely optional" and notes it is "'invisible' in the game
until quality modules are unlocked".

Two structural facts matter more than the bonus table:

**Quality applies to items, and therefore to entities, and never to fluids.** `FluidPrototype` at
2.0.77 has no quality property of any kind. So no plasma, no reactor energy and no steam is ever
anything but ordinary — which removes a whole class of question this mod would otherwise have to
answer.

**The five levels are `normal`, `uncommon`, `rare`, `epic`, `legendary`, at levels 0, 1, 2, 3 and 5.**
Not 0–4. From `data/quality/prototypes/quality.lua` and `data/base/prototypes/categories/quality.lua`,
read directly: `normal` is level 0, then 1, 2, 3, and legendary jumps to **5**. That is where +150%
comes from rather than +120%, and anyone writing `1 + 0.3 * index` gets legendary wrong.

`core/prototypes/unknown.lua` also declares a sixth, `quality-unknown`, at level 0 and `hidden`. It is
the engine's placeholder for a quality a save refers to and the current mod set does not define; it is
not a level a player can hold, and the rig excludes it.

## How the scaling actually works

### The multiplier lives on `QualityPrototype`, and it is mostly one number

The whole of Wube's own quality data is four prototypes. `data/quality/prototypes/quality.lua`, read
directly, sets **only** `level`, `next`, `next_probability`, `color`, `order`, `icon`, and three
overrides — `beacon_power_usage_multiplier`, `mining_drill_resource_drain_multiplier`,
`science_pack_drain_multiplier`. Everything else comes from a default.

That default is the important field.
[`QualityPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/QualityPrototype.html) at 2.0.77
declares `default_multiplier` with:

> **Default:** `1 + 0.3 × level`

and then a long list of per-mechanic multipliers that each **default to `default_multiplier`** —
`inserter_speed_multiplier`, `fluid_wagon_capacity_multiplier`, `inventory_size_multiplier`,
`lab_research_speed_multiplier`, `crafting_machine_speed_multiplier`,
`logistic_cell_charging_energy_multiplier` — plus a handful with their own defaults, of which
`crafting_machine_energy_usage_multiplier` (default **`1`**) and `accumulator_capacity_multiplier`
(default `1 + level`) are the ones worth remembering. Alongside them sit additive bonuses
(`crafting_machine_module_slots_bonus`, `electric_pole_wire_reach_bonus`, and so on) whose defaults
are `level` or a multiple of it.

So `1`, `1.3`, `1.6`, `1.9`, `2.5` is the number, and it arrives by default rather than by
declaration.

### The list of *affected properties* is engine-side and is not the list above

This is the trap, and it is why this note contains a measurement instead of a table copied out of the
docs. `QualityPrototype`'s named multipliers cover assemblers, labs, inserters, beacons, drills,
accumulators, containers, poles and robots. They say nothing at all about **boilers, generators,
pumps or storage tanks** — and boilers, generators and pumps demonstrably scale anyway, by
`default_multiplier`, with no field naming them.

Neither
[`BoilerPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/BoilerPrototype.html) nor
[`GeneratorPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/GeneratorPrototype.html) has a
single quality-related property at 2.0.77. Their scaling is not declared anywhere; it is behaviour.

**What the docs do give you is a reliable tell, and the repository already found it by accident.**
`realistic-fusion-refreshed/control.lua:795` records that `max_energy_production` had to become
`get_max_energy_production()` because "the quality system made these getters — and reading the field
throws". `scripts/check-buffer.ps1:300` puts the rule in one line: "The flow limits are methods rather
than attributes in 2.0 because quality scales them"; `scripts/check-brownout.ps1:727` says the same,
and adds the trap — "control.lua reads buffer_capacity off the same class as a field, which is what
made the wrong one look right". That is the general rule: **in 2.0 a prototype property that quality scales is exposed as a method
taking an optional `QualityID`, and one it does not scale stays a plain attribute.**
[`LuaEntityPrototype`](https://lua-api.factorio.com/2.0.77/classes/LuaEntityPrototype.html) has
twenty-two such methods, among them `get_fluid_capacity(quality)`, `get_max_energy_usage(quality)`,
`get_max_power_output(quality)`, `get_fluid_usage_per_tick(quality)`, `get_crafting_speed(quality)`,
`get_inventory_size(index, quality)` and `get_pumping_speed(quality)`.

The tell is necessary but not sufficient: **`get_fluid_capacity` takes a quality and returns the same
number at every level**, on every entity this mod ships and on vanilla's `boiler`, `heat-exchanger`,
`steam-turbine` and `storage-tank` besides. A getter that takes a quality is a property the engine
*might* scale, which is why the answer had to be measured rather than inferred.

The same rule, applied to
[`LuaElectricEnergySourcePrototype`](https://lua-api.factorio.com/2.0.77/classes/LuaElectricEnergySourcePrototype.html),
settles the buffer question from the docs alone: `get_input_flow_limit(quality)` and
`get_output_flow_limit(quality)` are methods, while **`buffer_capacity` and `drain` are plain
attributes with no quality form**. Measurement agrees — `electric_buffer_size` on a placed
`rf-reactor` reads 10 666 666.67 J at every level, which is the 16/15 of the declared 10 MJ that
`scripts/check-buffer.ps1` established under [#71](https://github.com/trulsjo/realistic-fusion-refreshed/issues/71).

### The floating point does not come back clean

Measured `crafting_speed` on `rf-heater`: `1`, `1.3`, `1.6`, `1.9`, `2.5` — exact. Measured
`fluid_usage_per_tick` on `steam-turbine`: `1`, `1.2999999523163`, `1.6000000238419`,
`1.8999999761581`, `2.5`. The multiplied values round-trip through float32 and three of the five come
back short. Legendary and normal are exact; uncommon, rare and epic are not.

Anyone asserting against these needs a tolerance. It is the same class of thing as
`check-hc.ps1`'s `near()` and for the same reason.

## What control a mod author has

Four levers, and they are uneven. Only the first two are per-entity.

| Lever | Reaches | Granularity | Cited |
|---|---|---|---|
| `quality_affects_*` booleans and the `*_quality_multiplier` dictionaries on specific prototype types | one property of one prototype | per entity, per property, per quality | below |
| `allow_quality = false` on a recipe | whether a quality version can be *made* at all | per recipe | below |
| Read `entity.quality.level` at runtime and index your own table | anything the mod's own code computes | total | below |
| Redefine `QualityPrototype`'s multipliers, including `default_multiplier` | the whole game | global — every mod's entities too | above |

### Per-property opt-out, where Wube wrote one

[`ContainerPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/ContainerPrototype.html) at
2.0.77:

> `quality_affects_inventory_size` :: boolean, optional. Default: `true`.

[`CraftingMachinePrototype`](https://lua-api.factorio.com/2.0.77/prototypes/CraftingMachinePrototype.html)
at 2.0.77 gives five:

> `quality_affects_energy_usage` :: boolean, optional. Default: `false`. "When set,
> QualityPrototype::crafting_machine_energy_usage_multiplier will be applied to energy_usage."
>
> `quality_affects_module_slots` :: boolean, optional. Default: `false`. "If set,
> QualityPrototype::crafting_machine_module_slots_bonus will be added to module slots count."
>
> `crafting_speed_quality_multiplier` :: dictionary[QualityID → double], optional. "If value is not
> provided for a quality, then QualityPrototype::crafting_machine_speed_multiplier will be used"
>
> `energy_usage_quality_multiplier` :: dictionary[QualityID → double], optional.
>
> `module_slots_quality_bonus` :: dictionary[QualityID → ItemStackIndex], optional.

The dictionaries are the strong form: a mod can write `crafting_speed_quality_multiplier = {normal =
1, uncommon = 1, rare = 1, epic = 1, legendary = 1}` and flatten crafting speed for that one machine
without touching anything else in the game.

**No equivalent exists for boilers, generators, pumps or storage tanks — all four checked.** Read in
full at 2.0.77: `BoilerPrototype`, `GeneratorPrototype`,
[`PumpPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/PumpPrototype.html) and
[`StorageTankPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/StorageTankPrototype.html)
each declare no quality property whatever. (All four inherit `quality_indicator_shift` and
`quality_indicator_scale` from `EntityWithOwnerPrototype`, which place and size the quality badge
sprite — cosmetic, not a lever.) For those four types there is no per-property opt-out at all — which
matters here, because `rf-reactor`, `rf-aneutronic-reactor`, both exchangers, `rf-isotope-collector`,
`rf-hc-turbine` and `rf-direct-energy-converter` are all boilers or generators, and it settles
`rf-pump`: its measured 2.5× pumping-speed scaling ([#97](https://github.com/trulsjo/realistic-fusion-refreshed/issues/97))
is not a choice the prototype can decline. A mod that wants it flat has only the blunter levers —
`allow_quality = false` on the recipe, the global `QualityPrototype` route, or runtime script. The
tank scales nothing, and has nothing it could opt out of.

### Denying the quality version outright

`RecipePrototype.allow_quality` at 2.0.77 is declared with a type and a default of `true` and **no
description sentence at all** — the docs do not say what it does. Two primary sources fill the gap.
Its companion `allow_quality_message` defaults to `{"item-limitation.quality-effect"}`, and that key
is in `data/core/locale/en/core.cfg:5309`:

> `quality-effect=Quality modules cannot be used on this recipe.`

And the base game uses it, with a comment saying why. `base/prototypes/recipe.lua:2558`, on
`kovarex-enrichment-process`:

> `allow_quality = false -- catalyst would be also bumped on quality`

plus every barrel fill and empty recipe (`base/data-updates.lua:156, 190`) and five oil recipes that
the quality mod itself switches off (`quality/prototypes/base-data-updates.lua`).

So `allow_quality = false` on `rf-reactor`'s recipe means no quality module can act on it, therefore
no legitimate route to a non-normal `rf-reactor` item, therefore no non-normal reactor on the map. It
is not an absolute: the rig for this note placed legendary reactors with `create_entity{quality =
...}`, and the console and the editor can do the same. It closes the player-facing route, which is the
one that matters. **This was not tested here** — no recipe in this repository was modified — so it is
a docs-plus-base-game inference rather than a measurement.

Excluding `"quality"` from a machine's `allowed_effects` is a *different* thing and does not do this
job: it stops quality modules going into that machine, not the machine itself being quality. Both of
this mod's machine builders currently include it —
`realistic-fusion-refreshed/prototypes/entities.lua:65` and
`realistic-fusion-refreshed-core/prototypes/entities.lua:31`.

### Defining quality levels

`QualityPrototype.level` at 2.0.77 carries the note:

> Requires Space Age to use level greater than `0`

Read literally that would mean quality does nothing under base + `quality` alone. **Measured, it does
not mean that:** with only the bundled `quality` mod enabled and `space-age` explicitly disabled, the
four levels still report 1, 2, 3, 5 and every multiplier above is unchanged. The bundled `quality`
mod's `info.json` declares `"quality_required": true` and depends only on `base >= 2.0.0`, which is
the likely actual gate — **but that is an inference and the flag is not documented anywhere this pass
could find.** What is safe to say is the measurement: **`quality` alone is enough for the full
effect**, which is what ADR 0003 needs to know, since it tolerates Space Age but does not target it
and a player may well run `quality` on its own.

Whether a mod may add a *sixth* grade was not established. FFF #375 mentions "restrictions on
mod-defined quality tiers outside the standard five levels" without stating them, and no 2.0.77 doc
page found in this pass says what happens if a mod declares another `quality` prototype. **Not
verified. Do not build on it.** [`inverted-quality.md`](inverted-quality.md) narrows this: a shipped
mod defines three extra grades and a mod-portal thread reports 98. That is read evidence rather than
a measurement here, and it says nothing about what this mod's entities do at a sixth grade.

### Reading quality from the simulation

[`LuaEntity.quality`](https://lua-api.factorio.com/2.0.77/classes/LuaEntity.html) is a read-only
`LuaQualityPrototype`, and
[`LuaQualityPrototype.level`](https://lua-api.factorio.com/2.0.77/classes/LuaQualityPrototype.html) is
"the stat-increasing value of this quality level". So `entity.quality.level` is one field read, and
anything `reactor-logic.lua` computes could be made a function of it. That is the only route to
quality affecting `confinement_time_s`, `heating_power_w` or `capture_efficiency`, none of which is a
prototype field. `LuaEntity.electric_buffer_size` is read-**write**, so the buffer could be scaled per
quality by script too.

## What is exposed on this mod's entities

Measured. Factorio 2.0.77, `quality` enabled, identical with and without `space-age`. Every value
read at all five levels; only the two ends are shown, and "flat" means all five agreed.

### Power — `realistic-fusion-refreshed/prototypes/entities.lua`

| Entity | Type | Property | normal | legendary | Does the simulation assume it constant? |
|---|---|---|---|---|---|
| `rf-reactor` | `boiler` | **fluid box 1 (plasma)** | 1000 | **1000** | **Yes — and it holds.** `volume_m3` and `particles_per_unit` are Lua constants; `control.lua` reads `box.get_capacity` |
| | | **fluid box 2 (energy)** | 1000 | **1000** | `control.lua:327` reads `get_capacity(2)` to clamp the sale |
| | | **`buffer_capacity`** | 10 MJ | **10 MJ** | Yes — `control.lua:459-465` checks `heating_power_w × interval` against it at load |
| | | `input_flow_limit` | 60 MW | **150 MW** | No. No shipped code reads it; only `check-brownout.ps1`'s rig does |
| | | `energy_consumption` | 1 W | 2.5 W | No. The neutered boiler conversion |
| `rf-aneutronic-reactor` | `boiler` | fluid boxes | 3000 / 1000 | **3000 / 1000** | Yes — and it holds. 3×10²⁰ m⁻³ stays 3×10²⁰ |
| | | `buffer_capacity` | 40 MJ | **40 MJ** | Yes, same load check |
| | | `input_flow_limit` | 240 MW | **600 MW** | No |
| | | `energy_consumption` | 1 W | 2.5 W | No |
| `rf-lithium-blanket` | `container` | **`inventory_size`** | 100 | **250** | No. Buffer only — `blanket_breed` is bounded by neutrons and collector headroom |
| `rf-heater` | `assembling-machine` | **`crafting_speed`** | 1 | **2.5** | No. Plasma supply, which ADR 0016 makes a player lever anyway |
| | | `energy_usage` | 5 MW | **5 MW** | — (`quality_affects_energy_usage` is `false`) |
| | | fluid boxes | 1000/1000/100/100 | flat | — |
| `rf-heat-exchanger` | `boiler` | **`energy_consumption`** | 40 MW | **100 MW** | No |
| | | fluid boxes | 200 / 200 | flat | — |
| `rf-hc-exchanger` | `boiler` | **`energy_consumption`** | 400 MW | **1000 MW** | No |
| | | fluid boxes | 1000 / 1000 | flat | — |
| `rf-hc-turbine` | `generator` | **`max_power_output`** | 58.2 MW | **145.5 MW** | No |
| | | **`fluid_usage_per_tick`** | 10 | **25** | No — and it is the *same* factor, see below |
| | | fluid box | 2000 | flat | — |
| `rf-direct-energy-converter` | `generator` | **`max_power_output`** | 100 MW | **250 MW** | No |
| | | **`fluid_usage_per_tick`** | 1.6667 | **4.1667** | No — same factor |
| | | fluid box | 1000 | flat | — |
| `rf-isotope-collector` | `boiler` | `energy_consumption` | 1 W | 2.5 W | No. `energy_source` is `void` |
| | | fluid boxes | 500 each | flat | `control.lua:363` reads the tritium box's capacity as headroom |
| `rf-aneutronic-composite-tank` | `storage-tank` | — | 50 000 | **50 000** | Nothing scales |
| `rf-pipe`, `rf-pipe-to-ground` | `pipe` | — | 100 | **100** | Nothing scales |
| `rf-pump` | `pump` | **`pumping_speed`** | 1200 /s | **3000 /s** | No |

### Core — `realistic-fusion-refreshed-core/prototypes/entities.lua`

All five are `assembling-machine` and all five behave identically:

| Entity | `crafting_speed` | `energy_usage` |
|---|---|---|
| `rf-electrolyser` | 1 → **2.5** | 200 kW, **flat** |
| `rf-deuterium-extractor` | 1 → **2.5** | 400 kW, **flat** |
| `rf-brine-concentrator` | 1 → **2.5** | 200 kW, **flat** |
| `rf-gas-mixer` | 1 → **2.5** | 150 kW, **flat** |
| `rf-lithium-extractor` | 1 → **2.5** | 300 kW, **flat** |

That is vanilla's design, not an accident: `crafting_machine_energy_usage_multiplier` defaults to `1`
and `quality_affects_energy_usage` defaults to `false`, so **a legendary crafting machine is 2.5× the
throughput at the same power** — a 60% cut in electricity per unit of product, across the whole
extraction chain. It is the largest effect quality has anywhere in this mod, and it is entirely
upstream of the simulation.

### Two things the table is saying that are easy to miss

**Nothing the simulation assumes constant is scaled.** The three quantities `reactor-logic.lua` holds
as constants and `control.lua` cross-checks against the engine — plasma box volume, energy box volume,
electric buffer capacity — are all flat. The model and the engine cannot silently disagree. This was
the brief's leading suspicion and it is answered in the negative, by measurement.

**Both generator properties scale by the same factor, which is why nothing gets cheaper.** The rig
computed each generator's derived output against its declared cap at every level:

| Entity | quality | fluid/tick | derived input | declared cap | out/in |
|---|---|---|---|---|---|
| `rf-direct-energy-converter` | normal | 1.6667 | 100 MW | 100 MW | **1.000000** |
| | legendary | 4.1667 | 250 MW | 250 MW | **1.000000** |
| `rf-hc-turbine` | normal | 10 | 58.2 MW | 58.2 MW | **1.000000** |
| | legendary | 25 | 145.5 MW | 145.5 MW | **1.000000** |
| `steam-turbine` | normal | 1 | 5.82 MW | 5.82 MW | **1.000000** |
| | legendary | 2.5 | 14.55 MW | 14.55 MW | **1.000000** |

Two things fall out. The ratio is exactly 1 at every level, so **quality on a generator is pure
throughput** — which is what `docs/research/port-and-original-inspection.md` §2.6 could not determine
and left open as "the crux". It is now determined: the caps scale with the throughput, and the answer
is the benign one for both branches that section worried about. And the same table incidentally
re-confirms `check-hc.ps1`'s invariant — `rf-hc-turbine`'s declared 58.2 MW is exactly its derived
output — **at every quality level**, not just at normal.

## The perpetual-motion question

### The ledger, written out

From `reactor-logic.lua:437-469`, per step, with `η = capture_efficiency`:

    captured_j = ((fusion_j - charged_j) + left_j) × η
    left_j     = kept_j + heating_j + charged_j - retained_j

At thermal equilibrium the plasma's energy is unchanged, so `retained_j = kept_j` and the two cancel:

    left_j     = heating_j + charged_j
    captured_j = (fusion_j - charged_j + heating_j + charged_j) × η
               = (fusion_j + heating_j) × η

so, per second, with `Q = P_fus / P_heat`:

    net = η·(P_fus + P_heat) - P_heat = η·P_fus - (1 - η)·P_heat

**A reactor pays for itself exactly when `Q ≥ (1 − η) / η`.**

| η | break-even Q | cold reactor (Q = 0) |
|---|---|---|
| **0.85** (shipped `rf-reactor`) | **0.1765** | 42.5 MW back for 50 MW — **−7.5 MW** |
| 0.9375 (ADR 0020 level 3) | 0.0667 | 46.9 MW back for 50 MW — −3.1 MW |
| **0.95** (shipped aneutronic) | **0.0526** | 190 MW back for 200 MW — **−10 MW** |
| **1.0** | **0** | **free, for ever** |

Two of those cold-reactor figures are already written down elsewhere and are reproduced here from the
step function rather than quoted, which is the check that this derivation is the same ledger the code
implements: `reactor-logic.lua:313-318` states the aneutronic 190 MW for 200 MW, and ADR 0020's
Consequences states 46.9 MW at level 3. The 42.5 MW for 50 MW at η = 0.85 is derived here.

### Which of the four terms can quality reach?

The inequality has exactly four inputs. Taking them one at a time:

| Term | Where it lives | Quality-reachable? |
|---|---|---|
| **η** — `capture_efficiency` | Lua constant in `reactor-logic.lua`, 0.85 / 0.95. After ADR 0020, a per-force research value | **No.** Nothing outside that file assigns it, and no prototype in the chain exposes an efficiency quality could scale even if it did: `BoilerPrototype` and `GeneratorPrototype` have no quality property, and a fluid energy source's `effectivity` is a plain attribute |
| **P_heat** — `heating_power_w` | Lua constant, 50e6 / 200e6. `control.lua:256` debits `entity.energy` by it directly | **No.** The prototype's own `energy_consumption` *does* scale — and is not what is spent |
| **P_fus** | `reactivity.rate(...) × volume_m3`, driven by `density = amount × particles_per_unit / volume_m3` | **No.** `particles_per_unit` and `volume_m3` are Lua constants, and `amount` is bounded by a fluid box capacity **measured flat**. Peak density is 1×10²⁰ m⁻³ at every level, 3×10²⁰ for the aneutronic reactor |
| **The fluid→electricity factor** | `energy_fluid_j_per_unit = 1e6`, then `rf-heat-exchanger` (fluid energy source, `effectivity = 1`, `burns_fluid`) → steam → turbine; or the DEC directly | **No.** Measured out/in = 1.000000 at all five levels on both generators; both boilers' fluid energy source reports `effectivity = 1`, an attribute with no quality form, and `QualityPrototype` has no energy-source multiplier |

**So the answer to the brief's fourth question is no, and it is not a near thing.** Every input to the
break-even condition is either a Lua constant or a measured-flat prototype value. Setting every entity
in the chain to legendary changes the net power of a non-fusing reactor by nothing at all: it is
−7.5 MW at normal and −7.5 MW at legendary.

`capture_efficiency` in particular is unreachable **because** it is a Lua constant and not a prototype
field — which the brief asked to be verified rather than assumed. Checked two ways. It is **defined
and read only in `reactor-logic.lua`**: the only other occurrences of the name anywhere in the repo
are a comment in `prototypes/entities.lua:546` and two mentions in `tests/test-reactor-logic.lua`, and
no prototype file assigns it. And separately, none of `BoilerPrototype`, `GeneratorPrototype`,
`FluidEnergySource`'s `effectivity`, `FluidPrototype` or `QualityPrototype` at 2.0.77 exposes a
quality-scalable efficiency at all, so even a version of the mod that *did* read one off a prototype
would have nothing to read. ADR 0020's asymptote is the only thing that moves the constant, and
research is per force, not per entity.

### The one term quality does move, and what it is worth

`input_flow_limit`. `rf-reactor` declares 60 MW against a 50 MW spend, and every consumer on the
network is `secondary-input`, so in a brownout at supply fraction `f` a reactor receives `f × 60` MW
and spends 50:

| Quality | `input_flow_limit` | full heating holds down to |
|---|---|---|
| normal | 60 MW | **f = 0.833** |
| uncommon | 78 MW | f = 0.641 |
| rare | 96 MW | f = 0.521 |
| epic | 114 MW | f = 0.439 |
| legendary | **150 MW** | **f = 0.333** |

The aneutronic reactor gives the same fractions — 240 MW against a 200 MW spend, so 600 MW at
legendary and the same 0.833 → 0.333. **It is not free energy**: the reactor still never spends more
than `heating_power_w`, so the extra headroom buys resilience rather than power. It is also the only
thing on the whole list that reads like a quality bonus somebody would have designed on purpose.

The table is arithmetic off the measured flow limits, not an observed brownout.
`scripts/check-brownout.ps1` is the rig that measures the real thing, and it reads the same
`get_input_flow_limit()` to calibrate — but it runs at normal quality only, so **a brownout has never
been measured on a legendary reactor.** Adding a quality lane to that rig is the cheap way to check
this table.

### The residual boiler leak, since quality multiplies it

`rf-reactor` is a `boiler` in `output-to-separate-pipe` mode with `energy_consumption = 1 W` and
`target_temperature = 550`. The plasmas declare no `heat_capacity`, so they take
`FluidPrototype.heat_capacity`'s documented default of `"1kJ"` — "Joule needed to heat 1 Unit by
1 °C" — and 15 °C to 550 °C is 535 kJ per unit. At 1 W that is **one unit per 535 000 s ≈ 148.6 h**.
Quality takes `energy_consumption` to 2.5 W, so a legendary reactor's engine-side conversion runs at
one unit per 214 000 s ≈ 59.4 h — **1 MJ per 59.4 h, or 4.7 W**, against 50 MW of heating. One part
in ten million.

**And it only runs while the reactor is idle**, which [#101](https://github.com/trulsjo/realistic-fusion-refreshed/issues/101)
established after this note was written: the conversion is exactly zero whenever the plasma is at or
above the target, so a *fusing* reactor leaks nothing at any quality. The figures above are the cold
case — a plasma parked at `min_temperature_c`.

And it is a *fuel* leak rather than an energy exploit: the boiler consumes a unit of plasma —
10²⁰ nuclei — to make 1 MJ, where fusing the same 10²⁰ D-D nuclei releases about 58 MJ. Quality makes
a bad trade 2.5× more frequent. **Not re-measured at quality**: the rig places entities and reads
prototypes, it does not run a reactor, so this is arithmetic off declared fields plus the repository's
own normal-quality measurement.

## What is not verified

Stated plainly, because this repository treats an unverified claim as a defect.

- **Nothing was measured running.** The rig places entities and reads what the engine reports; it does
  not step the simulation, does not fuse anything and does not watch a power network. So the central
  claim — that a legendary reactor reaches the same equilibrium as a normal one, because every input
  to the equilibrium is quality-flat — is a **deduction from measured prototype values**, not an
  observation of two reactors running side by side. So are the brownout table and the boiler leak. A
  probe that lights a legendary reactor next to a normal one and compares the temperature and Q
  signals is the thing that would close it, and it is the obvious next step.
- **`allow_quality = false` was not tested.** No recipe in this repository was modified. Its effect is
  inferred from the locale string, from four base-game uses, and from the property's presence on
  `RecipePrototype` — the docs themselves give it no description sentence.
- **Whether a mod may add a sixth quality level is unknown.** FFF #375 refers to restrictions without
  stating them and no 2.0.77 doc page found in this pass covers it. Narrowed but not measured by
  [`inverted-quality.md`](inverted-quality.md).
- **`"quality_required": true`** in the bundled mod's `info.json` is very likely what enables level > 0
  without Space Age, since the measurement contradicts the literal reading of
  `QualityPrototype.level`'s note. That is an inference. The flag is not documented anywhere this pass
  reached.
- **Fluid box capacity was checked on the entities this mod ships and four vanilla ones.** It is flat
  on all of them. This note does not claim it is flat for every prototype type in the game — a
  `fluid-wagon` has `fluid_wagon_capacity_multiplier` and certainly is not.

## What quality *should* improve — options, not a choice

Scope and balance are Truls's, and `CLAUDE.md` is explicit that an agent must not settle them as a
side effect. What follows is the option space with its trade-offs, and no recommendation between the
options. Where an option is cheap and another is expensive, that is stated as a fact about the work,
not as an argument.

Note the starting position: **`README.md` and both `info.json` descriptions already say the buildings
are not balanced for quality**, and ADR 0003 names the quality interaction as a known gap "to be
stated plainly rather than fixed". Every option below is compatible with that promise; option A *is*
that promise.

### A — do nothing

Leave every entity as it is. Quality does what vanilla does to a boiler, a generator, a container and
an assembler.

- **For:** already true, already documented, costs nothing, and the measurement above says it is safe
  — no free energy, no model/engine disagreement, nothing the simulation assumes is touched. The
  largest effect (2.5× on the extraction chain) is exactly what quality does to every other mod's
  assemblers, so a player's expectations are met rather than surprised.
- **Against:** three of the scaled properties are *meaningless* rather than balanced — `rf-reactor`'s
  1 W → 2.5 W neutered conversion, `rf-isotope-collector`'s void-powered 1 W, and the `"quality"` entry
  in both machine builders' `allowed_effects` on machines whose only recipes produce fluids, which
  fluids cannot have. A player who spends a legendary reactor gets a bigger `input_flow_limit` and
  three no-ops, and nothing tells them so.
- **Against, harder:** the interesting property of a reactor — how well it confines plasma — is
  untouched, so a legendary fusion reactor is not a better fusion reactor. For a mod whose whole
  premise is that a reactor *is* its constants, that is a thin answer.

### B — tidy the no-ops, keep the rest

Leave the scaling alone and remove what does not mean anything: drop `"quality"` from
`rf-heater.allowed_effects`, and consider it for Core's five, which do produce items and would need
checking recipe by recipe.

The heater case is not a judgement call. **All four `rf-plasma-heating` recipes are fluid in, fluid
out** — `rf-d-d-plasma`, `rf-d-t-plasma`, `rf-d-he3-plasma`, `rf-he3-he3-plasma`, none with an item
result — and fluids cannot carry quality, so the effect a player buys with that module slot cannot
exist.

- **For:** smallest possible diff, no balance consequence at all, and it stops a player wasting a
  module slot on an effect that cannot exist. The kind of thing the `item-limitation.quality-effect`
  message exists for. The precedent is already in this repo: the same recipes set
  `allow_productivity = false` for exactly this class of reason.
- **Against:** `rf-reactor`'s and `rf-isotope-collector`'s 1 W scaling **cannot** be tidied —
  `BoilerPrototype` has no quality property — so the no-op list gets shorter, not empty. And a player
  who has legendary modules and other mods installed may reasonably want the slot to accept the module
  even if it does nothing here.
- **Note:** whether Core's machines' item-producing recipes *should* be quality-able is a separate
  question about the extraction chain, not about reactors.

### C — make quality mean confinement

Read `entity.quality.level` in `control.lua` and let it scale `confinement_time_s` — the field
`reactor-logic.lua` calls "the reactor's defining statistic". A legendary reactor confines its plasma
longer, therefore runs hotter, therefore fuses harder.

- **For:** it is the only option under which a legendary fusion reactor is a better *fusion reactor*.
  It is physically the right knob — better magnets and a better first wall are exactly what a
  higher-grade machine would be — and it is what ADR 0014 sanctions, since τ_E is unbounded and
  improving it is engineering rather than a violation. Mechanically it is one field read; `entity.quality`
  is a read-only `LuaQualityPrototype` and `.level` is a `uint32`.
- **For, secondarily:** it composes with [#53](https://github.com/trulsjo/realistic-fusion-refreshed/issues/53),
  which is already the confinement-time ticket, so the machinery may exist anyway.
- **Against, and this is the large one:** the response is violent and non-linear. `bremsstrahlung.md`'s
  own confinement sweep — the post-[#52](https://github.com/trulsjo/realistic-fusion-refreshed/issues/52)
  one, with bremsstrahlung carried — has D-D at 30 s reaching Q 0.32 and at 100 s reaching Q 3.58: a
  factor of eleven for 3.3× the confinement. A ×2.5 on τ_E is not a +150% bonus, it is a tier change,
  and it would put a legendary D-D reactor past the D-T tier it is meant to precede. Any version of this needs its own
  curve, probably far shallower than the quality multiplier, chosen against the equilibria rather than
  against the multiplier table.
- **Against:** it puts a balance-critical number behind an engine mechanic ADR 0003 declines to
  target, and it makes every equilibrium in `d-t-ignition.md` and `bremsstrahlung.md` a function of
  quality. Those documents currently quote one number each.
- **Against:** it is per-entity state the simulation does not have today. `SPECS[entity.name]` is a
  shared module-level table; ADR 0020 already has to move `capture_efficiency` out of it for research,
  and this would be a second axis on top.

### D — make quality mean something safe and small

Pick a quantity where 2.5× is harmless and let quality have it. Two candidates the measurement
suggests: the blanket's inventory (already scaling, 100 → 250, pure autonomy) and the reactor's
`input_flow_limit` (already scaling, 60 → 150 MW, pure brownout resilience). Declare *those* the
quality story, tidy the rest under B, and say so in `README.md`.

- **For:** costs nothing to implement — both already happen. It converts an accident into a
  documented intent, which is most of what ADR 0003's "state it plainly" asks for. Neither touches
  Q, the equilibria, or any published number.
- **Against:** it is a small story. "Your legendary reactor tolerates brownouts better and your
  legendary blanket holds more lithium" is honest and unexciting. FFF #375 puts the naive cost of a
  legendary item at 56× a normal one, so a player who paid that may reasonably feel short-changed.
- **Against:** it does not address the fuel chain, where the real 2.5× lives.

### E — deny quality on the reactors entirely

`allow_quality = false` on `rf-reactor`, `rf-aneutronic-reactor` and whichever others, so no
non-normal version can be produced.

- **For:** removes the question rather than answering it. Defensible on the same grounds as the base
  game's kovarex exclusion — the machine's behaviour is computed by this mod rather than by the
  engine, so an engine-side multiplier acting on it is meaningless by construction. Consistent with
  ADR 0003's refusal to target Space Age.
- **Against:** it is a visible restriction where the other options are invisible, and quality players
  tend to notice a building they cannot upgrade. It also breaks the *cosmetic* expectation that every
  building has five grades.
- **Against:** untested here, and it would want its own check — an assertion that no quality-module
  route produces an `rf-reactor` — since the guarantee is a load-time property nothing currently
  holds.
- **Note:** it does **not** remove the fuel chain's 2.5×, which is on Core's assemblers and would need
  the same treatment applied to five more recipes to be consistent.

### If a single reading of the evidence is wanted

Not a decision, and stated as one paragraph because the brief asked for a recommendation with
reasoning rather than a survey alone. **The measurement removes the reason to act urgently.** There is
no exploit, no perpetual motion, and no place where the model and the engine disagree, so nothing here
is a defect to be fixed — which makes this a design question about whether quality should mean
anything for a fusion reactor, on the same footing as any other open item in `CLAUDE.md`'s list. If
the answer is "not yet", **A plus the one-line honesty of D** costs nothing and leaves the position
exactly where ADR 0003 put it. If the answer is "yes, eventually", **C is the only option that is
about fusion**, and the thing to do first is not to implement it but to run the confinement sweep
against a candidate curve, because the ×2.5 the mechanic hands you is far too large and the
arithmetic for that already exists in `tests/test-bremsstrahlung.lua`.

## Sources

Primary, read directly at 2.0.77:

- [`QualityPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/QualityPrototype.html) —
  `level`, `default_multiplier` and its dependent multipliers, the additive bonuses.
- [`ContainerPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/ContainerPrototype.html) —
  `quality_affects_inventory_size`.
- [`CraftingMachinePrototype`](https://lua-api.factorio.com/2.0.77/prototypes/CraftingMachinePrototype.html)
  — `quality_affects_energy_usage`, `quality_affects_module_slots`, and the three per-quality
  dictionaries.
- [`BoilerPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/BoilerPrototype.html) and
  [`GeneratorPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/GeneratorPrototype.html) —
  read in full; **no quality property on either**.
- [`PumpPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/PumpPrototype.html) and
  [`StorageTankPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/StorageTankPrototype.html)
  — read in full ([#149](https://github.com/trulsjo/realistic-fusion-refreshed/issues/149), 2026-08-29);
  **no quality property on either**.
- [`EntityWithOwnerPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/EntityWithOwnerPrototype.html)
  — `quality_indicator_shift` and `quality_indicator_scale`, the cosmetic badge placement every
  entity-with-owner inherits.
- [`RecipePrototype`](https://lua-api.factorio.com/2.0.77/prototypes/RecipePrototype.html) —
  `allow_quality`, `allow_quality_message`. Type and default only; no description text.
- [`FluidPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/FluidPrototype.html) —
  `heat_capacity` default `"1kJ"`, `fuel_value`; **no quality property**.
- [`LuaEntityPrototype`](https://lua-api.factorio.com/2.0.77/classes/LuaEntityPrototype.html) — the
  twenty-two quality-taking getters, and the `quality_affects_*` / `*_quality_multiplier` read
  attributes.
- [`LuaElectricEnergySourcePrototype`](https://lua-api.factorio.com/2.0.77/classes/LuaElectricEnergySourcePrototype.html)
  — the flow limits are methods; `buffer_capacity` and `drain` are attributes.
- [`LuaEntity`](https://lua-api.factorio.com/2.0.77/classes/LuaEntity.html) — `quality` (read-only),
  `electric_buffer_size` (read-write).
- [`LuaQualityPrototype`](https://lua-api.factorio.com/2.0.77/classes/LuaQualityPrototype.html) —
  `level`, and every multiplier readable at runtime.

Wube's own data, read off this machine at
`D:\SteamLibrary\steamapps\common\Factorio\data\`, version 2.0.77:

- `quality/prototypes/quality.lua` — the four higher grades, and the three multipliers Wube overrides.
- `quality/prototypes/base-data-updates.lua` — `normal.next = "uncommon"`, and `allow_quality = false`
  on five oil recipes.
- `quality/info.json` — `"quality_required": true`, `dependencies: ["base >= 2.0.0"]`.
- `base/prototypes/categories/quality.lua` — `normal`, level 0.
- `core/prototypes/unknown.lua` — `quality-unknown`, level 0, hidden.
- `base/prototypes/recipe.lua:2558` — `allow_quality = false -- catalyst would be also bumped on
  quality`.
- `base/data-updates.lua:156, 190` — `allow_quality = false` on barrel fill and empty.
- `core/locale/en/core.cfg:5309` — `quality-effect=Quality modules cannot be used on this recipe.`

First-party design statement:

- **Friday Facts #375 — Quality**, 8 September 2023,
  <https://www.factorio.com/blog/post/fff-375>. The five grades and their bonuses; which building
  types improve; quality modules as the production route; "completely optional"; the reference to
  restrictions on mod-defined tiers, which it does not state.

Measured for this note:

- `scripts/probe-quality.ps1`, which reads every entity in
  `realistic-fusion-refreshed/prototypes/entities.lua` and
  `realistic-fusion-refreshed-core/prototypes/entities.lua` off the prototype at all five quality
  levels, plus vanilla `boiler`, `heat-exchanger`, `steam-turbine`, `storage-tank` and `steel-chest`
  as controls — and **places twelve of them** on a surface to ask the same questions of a live
  entity, `steam-turbine` being the only control among the twelve. The two reads are not
  interchangeable and the distinction matters: `control.lua` calls `get_capacity` on a live entity's
  fluid box, not on the prototype, so the placed rows are the ones that speak to what the simulation
  sees. Two runs: bundled `quality` alone, and `space-age` (which pulls in `quality` and
  `elevated-rails`). Identical results. See the head of this note for the commands.

Not sourced primarily, and flagged where used:

- The semantics of `allow_quality`, which the 2.0.77 docs do not describe.
- The meaning of `"quality_required"` in a mod's `info.json`.
- Whether a mod may define a sixth quality level.
- Anything about how quality interacts with a *running* simulation, which was not measured.

The wiki was used only to reach the FFF and is cited for nothing.

# Quality, and what it does to this mod

Researched 2026-08-21. **Every API claim is pinned to Factorio 2.0.77**, which is the version this
repository loads against; the docs are read at `https://lua-api.factorio.com/2.0.77/` rather than at
`/stable/` or `/latest/`, both of which move.

Three kinds of evidence, kept separate throughout:

- **The prototype and runtime API docs at 2.0.77**, quoted.
- **Wube's own `quality` mod**, read off this machine at
  `D:\SteamLibrary\steamapps\common\Factorio\data\quality\`, version 2.0.77.
- **Measurement, standing still.** Which properties the engine actually multiplies is not declared in
  any prototype and cannot be read out of the files, so it was measured: a rig places one of every
  entity this mod ships at each of the five quality levels and reads back what the simulation reads —
  `fluidbox.get_capacity`, `electric_buffer_size`, the prototype getters, container inventory size.
  Run once with the bundled `quality` mod alone and once with `space-age` as well; **every number was
  identical**, so this note quotes one set.
- **Measurement, running.** Four rigs now, each with its own section and its own script. Five
  reactors lit and settled to equilibrium (#145, [here](#the-equilibrium-measured)); five supplied
  down a brownout ladder (#146); ten cold and hot boilers isolated from the simulation (#147); and
  three assembling machines on a flagged recipe and its twin (#148). Between them they close every
  deduction and every piece of arithmetic this note used to rest on.

**The first rig is checked in as `scripts/probe-quality.ps1`** ([#97](https://github.com/trulsjo/realistic-fusion-refreshed/issues/97)).
Run it to reproduce the numbers below rather than taking them on trust:

    pwsh -File scripts/probe-quality.ps1             # the bundled quality mod alone
    pwsh -File scripts/probe-quality.ps1 -SpaceAge   # and again with space-age

Re-measured that way on 2026-08-27 against Factorio 2.0.77: 261 reported rows per run, **identical
between the two configurations** — which is the claim above, checked rather than remembered.

**Nothing runs any of them for you.** All five are probes rather than checks: they assert nothing,
exit 0 means the run reported, and no check, bench or gate sweep invokes them — `load-check.ps1`
included. So a later engine version can change any number here and this document goes stale in
silence unless somebody types those commands. The rigs exist and are not wired; say that plainly
rather than claiming a guarantee the repository does not have.

    pwsh -File scripts/probe-quality-equilibrium.ps1   # #145, the equilibrium
    pwsh -File scripts/probe-quality-brownout.ps1      # #146, the brownout ladder
    pwsh -File scripts/probe-quality-leak.ps1          # #147, the residual boiler leak
    pwsh -File scripts/probe-allow-quality.ps1         # #148, what allow_quality = false does

## The short version

**Quality is not a danger to this mod's energy ledger, and the reason is a measurement rather than an
argument: fluid box capacity does not scale with quality.** Nor does the electric energy source's
buffer. Every quality-scaled generator scales its fluid usage and its power cap by exactly the same
factor — measured out/in = 1.000000 at all five levels — so no conversion anywhere in the chain gets
cheaper. `capture_efficiency` is a Lua constant that no prototype field feeds, so nothing quality
touches can reach it. **No combination of quality levels moves a reactor toward break-even without
fusion**; the arithmetic is in [The perpetual-motion question](#the-perpetual-motion-question).

**And a legendary reactor reaches the same equilibrium as a normal one — measured, since #145, not
deduced.** Five reactors, one per level, each on its own network at the same plasma density, settle at
the same 2.42382e8 °C and the same Q of 32%, with a spread of exactly zero. That was this note's one
remaining deduction; [the section is here](#the-equilibrium-measured).

What quality *does* do here is real but unremarkable, and one item on the list is a near-miss worth
knowing about:

- **`rf-heater` and all five Core machines run 2.5× faster at legendary for the same power.** That is
  vanilla's crafting-machine behaviour and it makes the whole fuel chain 2.5× cheaper in electricity
  per unit of deuterium. The largest real effect quality has on this mod.
- **`rf-heat-exchanger` and `rf-hc-exchanger` burn 2.5× the reactor energy and make 2.5× the steam.**
  Throughput only; the ratio is unchanged, so a legendary exchanger needs 2.5× the turbines.
- **`rf-lithium-blanket` holds 250 slots instead of 100.** Buffer, not rate: breeding is bounded by
  neutrons and by collector headroom, never by inventory.
- **`rf-reactor`'s `input_flow_limit` goes from 90 MW to 225 MW against a spend of 50 to 75 MW**, so a
  legendary reactor rides out a brownout to two ninths of supply where a normal one starts losing
  heating at five-ninths — and at the top of the heating ladder those become a third and five-sixths.
  **Measured since #146 and re-measured on 2026-09-20 against Factorio 2.0.77 (#429)**, not divided:
  five reactors on five networks, supplied down a ladder one hundredth of their own flow limit at a
  time. This is the one place quality changes reactor *behaviour*, and it is the only entry on this
  list that a balance decision might want to keep.

  **Both ends of that sentence moved on 2026-09-19 (#425, ADR 0038), and #429 re-measured them on
  2026-09-20.** `input_flow_limit` is 90 MW now, sized on the top of the heating ladder rather than on
  the shipped 50 MW, and the spend is no longer one number: it is 50 MW for a force that has
  researched nothing and 75 MW at the top of that ladder. So the single fraction this note used to
  publish is a family of them, one per heating rung, and
  [The one term quality does move](#the-one-term-quality-does-move-and-what-it-is-worth) below is
  where the family is measured. The structural conclusion — quality raises the limit, which is the
  safe direction, and `check_input_flow()` refuses to load if it ever stops covering the heating — is
  unaffected, and the re-measurement is what now says so rather than an argument that it must be.
- **`rf-reactor`'s own `energy_consumption` scales 1 W → 2.5 W, and 2.5× of nothing is still
  nothing.** That is the neutered boiler conversion the mod does not use, and **measured since #147
  it is exactly zero at four of the five levels** — the engine moves fluid in whole float32 ULPs per
  tick and the rate law asks for less than one of those at every level below legendary.

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
`realistic-fusion-refreshed/control.lua` records that `max_energy_production` had to become
`get_max_energy_production()` because "the quality system made these getters — and reading the field
throws". `scripts/check-buffer.ps1` puts the rule in one line: "The flow limits are methods rather
than attributes in 2.0 because quality scales them"; `scripts/check-brownout.ps1` says the same,
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

That reading is now **measured**, and it holds. `scripts/probe-allow-quality.ps1` is the rig, added
under [#148](https://github.com/trulsjo/realistic-fusion-refreshed/issues/148): three
`assembling-machine-3`s, one on a rig-declared recipe carrying the flag, one on an otherwise
identical rig recipe without it, and one on an untouched base recipe. **No recipe in either shipped
mod was modified** — applying the flag is option E and Truls's.

| Question | Answer |
|---|---|
| Is the flag readable at runtime? | **No.** `allow_quality`, `allow_quality_message`, `allows_quality` and `quality_allowed` all raise, on `LuaRecipePrototype` and on `LuaRecipe` alike |
| Refused, or accepted and ignored? | **Refused.** `can_insert` is false and `insert` returns 0, for a shipped `quality-module-3` and for the rig's own |
| A machine that already holds one? | `set_recipe` is **accepted** and the modules are **gone**: not in the module inventory, not in the output inventory, and not on the ground anywhere in the rig |
| Does it stop the quality output? | **Yes.** The control machine made rare, epic and legendary chests; the flagged machine made 299 normal ones and nothing else |

So the note's reading was right in substance, and the run adds one thing that matters for writing a
check: the flag is a **data-stage** property with no runtime face at all, so any assertion option E
wants has to be made against `data.raw` at load time rather than against a `LuaRecipePrototype`.

**It is still not an absolute.** The last line of the same run creates a legendary chest with
`create_entity{quality = "legendary"}` and reads it straight back, so the console, the editor and a
rig can each still make one. It closes the player-facing route, which is the one that matters.

**And it eats modules.** A machine holding four quality modules, switched onto a flagged recipe by
script, loses them with no refund and no spill. Worth knowing before the flag goes near a recipe a
player might already be running — **though the switch measured was `LuaEntity.set_recipe`, not a
player changing the recipe in the machine's own GUI**, and whether those two paths agree was not
run.

Excluding `"quality"` from a machine's `allowed_effects` is a *different* thing and does not do this
job: it stops quality modules going into that machine, not the machine itself being quality. Both of
this mod's machine builders currently include it —
`realistic-fusion-refreshed/prototypes/entities.lua` and
`realistic-fusion-refreshed-core/prototypes/entities.lua`.

### Quality promotion is gated behind research, and nothing says so

Found by the rig above rather than looked for, and it cost five runs to reach, so it is written down
where the next person will trip over it first.

**On a force that has researched nothing, a machine promotes nothing, at any module strength.** Four
shipped `quality-module-3`s — the engine's `quality = 1` — turned out 1199 untouched vanilla
`iron-gear-wheel`s and not one of them was above normal. A rig-built module at `quality = 100`, which
is certainty on any reading of that number, turned out 299 and did the same, on the vanilla recipe
and on this rig's own alike; the force's production statistics agreed with the inventories that
nothing else was ever made. It reads exactly like a mechanic that does not work. One call to
`research_all_technologies()` and the same machine promotes almost every craft.

Two things follow. Any check option E might want **must not rest on an unresearched save**, where
quality does nothing whatever the recipes say — a test that inserted a quality module and asserted no
`rf-reactor` came out would pass on a fresh map for the wrong reason. And a rig measuring quality
needs a control that is expected to promote, or a negative result has two explanations and measures
neither.

This is about the crafting mechanic, not about the levels: the five grades and their multipliers are
present and correct on an unresearched force, which is what the section below measured.

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
| | | **fluid box 2 (energy)** | 1000 | **1000** | `apply()` in `control.lua` reads `get_capacity(2)` to clamp the sale |
| | | `buffer_capacity` | 10 MJ | **10 MJ** | No, since #72. Stated reserve; `check_cadence()` used to check `heating_power_w × interval` against it and is gone |
| | | **`input_flow_limit`** | 60 MW | **150 MW** | **Yes, since #72 — and it holds.** `check_input_flow()` in `control.lua` requires it to cover `heating_power_w` at load, and since #425 the TOP of the heating ladder rather than the shipped value. Legendary raises it, which is the safe direction. The 60 MW is what the prototype declared when this was measured; the row was re-read at 90 → 225 MW on 2026-09-20 (#429) |
| | | `energy_consumption` | 1 W | 2.5 W | No. The neutered boiler conversion |
| `rf-aneutronic-reactor` | `boiler` | fluid boxes | 3000 / 1000 | **3000 / 1000** | Yes — and it holds. 3×10²⁰ m⁻³ stays 3×10²⁰ |
| | | `buffer_capacity` | 40 MJ | **40 MJ** | No, since #72. Same reasoning as `rf-reactor`'s |
| | | `input_flow_limit` | 240 MW | **600 MW** | **Yes, since #72** — same load check, over every reactor in `SPECS` |
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
| | | fluid boxes | 500 each | flat | `apply()` in `control.lua` reads the tritium box's capacity as headroom |
| `rf-aneutronic-composite-tank` | `storage-tank` | — | 50 000 | **50 000** | Nothing scales |
| `rf-pipe`, `rf-pipe-to-ground` | `pipe` | — | 100 | **100** | Nothing scales |
| `rf-pump` | `pump` | **`pumping_speed`** | 1200 /s | **3000 /s** | No |

> **`rf-heat-exchanger`'s base moved after this was measured.**
> [#227](https://github.com/trulsjo/realistic-fusion-refreshed/issues/227) took its
> `energy_consumption` from 40 MW to **90 MW** on 2026-09-10, so its legendary figure is now
> **225 MW** rather than the 100 MW in the row above. The row is left at what the rig actually read
> on 2026-08-21 rather than rewritten to a number nobody measured — **what this note establishes is
> the factor, 2.5x, and that is what survives the change.** `rf-hc-exchanger` is untouched at
> 400 MW, so the two exchangers' bases now differ by 4.44x where this table was taken at 10x.

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

From `M.step()` in `reactor-logic.lua`, per step, with `η = capture_efficiency`:

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
implements: `reactor-logic.lua`'s aneutronic spec states 190 MW for 200 MW, and ADR 0020's
Consequences states 46.9 MW at level 3. The 42.5 MW for 50 MW at η = 0.85 is derived here.

### Which of the four terms can quality reach?

The inequality has exactly four inputs. Taking them one at a time:

| Term | Where it lives | Quality-reachable? |
|---|---|---|
| **η** — `capture_efficiency` | Lua constant in `reactor-logic.lua`, 0.85 / 0.95. After ADR 0020, a per-force research value | **No.** Nothing outside that file assigns it, and no prototype in the chain exposes an efficiency quality could scale even if it did: `BoilerPrototype` and `GeneratorPrototype` have no quality property, and a fluid energy source's `effectivity` is a plain attribute |
| **P_heat** — `heating_power_w` | Lua constant, 50e6 / 200e6, and since #425 a per-force research value on the neutronic reactor. `control.lua` debits `entity.energy` by it directly | **No.** The prototype's own `energy_consumption` *does* scale — and is not what is spent. Research moves it, quality still does not |
| **P_fus** | `reactivity.rate(...) × volume_m3`, driven by `density = amount × particles_per_unit / volume_m3` | **No.** `particles_per_unit` and `volume_m3` are Lua constants, and `amount` is bounded by a fluid box capacity **measured flat**. Peak density is 1×10²⁰ m⁻³ at every level, 3×10²⁰ for the aneutronic reactor |
| **The fluid→electricity factor** | `energy_fluid_j_per_unit = 1e6`, then `rf-heat-exchanger` (fluid energy source, `effectivity = 1`, `burns_fluid`) → steam → turbine; or the DEC directly | **No.** Measured out/in = 1.000000 at all five levels on both generators; both boilers' fluid energy source reports `effectivity = 1`, an attribute with no quality form, and `QualityPrototype` has no energy-source multiplier |

**So the answer to the brief's fourth question is no, and it is not a near thing.** Every input to the
break-even condition is either a Lua constant or a measured-flat prototype value. Setting every entity
in the chain to legendary changes the net power of a non-fusing reactor by nothing at all: it is
−7.5 MW at normal and −7.5 MW at legendary.

`capture_efficiency` in particular is unreachable **because** it is a Lua constant and not a prototype
field — which the brief asked to be verified rather than assumed. Checked two ways. It is **defined
and read only in `reactor-logic.lua`**: the only other occurrences of the name anywhere in the repo
are a comment above `realistic-fusion-refreshed/prototypes/entities.lua`'s `converter` — *"where
capture_efficiency stands for everything not recovered"* — and two mentions in
`tests/test-reactor-logic.lua`, and no prototype file assigns it. And separately, none of
`BoilerPrototype`, `GeneratorPrototype`, `FluidEnergySource`'s `effectivity`, `FluidPrototype` or
`QualityPrototype` at 2.0.77 exposes a quality-scalable efficiency at all, so even a version of the
mod that *did* read one off a prototype would have nothing to read. ADR 0020's asymptote is the only
thing that moves the constant, and research is per force, not per entity.

### The one term quality does move, and what it is worth

`input_flow_limit`. `rf-reactor` declares 90 MW, every consumer on the network is `secondary-input`,
so in a brownout at supply fraction `f` a reactor receives `f × 90` MW and spends its heating power:

**The numerator is per force and the denominator is not, which is why this is a grid.** ADR 0038 made
heating power researchable on 2026-09-19, so the spend is 50 MW unresearched and 75 MW at the top of
the five-rung ladder, while `input_flow_limit` is a prototype field and does not move with research
at all. `f = heating_power_w / input_flow_limit`, so every rung of the heating ladder is a different
table.

**Re-measured 2026-09-20 against Factorio 2.0.77 (#429), at three of the six heating states — the
shipped value and five rungs.** The
five-level flow-limit row is read off the placed entities with
`get_input_flow_limit(quality)` in the same run, so the denominators below are the running game's and
not a multiplier applied here:

| Quality | level | `input_flow_limit` |
|---|---|---|
| normal | 0 | 90 MW |
| uncommon | 1 | 117 MW |
| rare | 2 | 144 MW |
| epic | 3 | 171 MW |
| legendary | 5 | **225 MW** |

### The brackets, per heating rung

Three rungs measured, three derived. Each cell is the last supply fraction at which full heating
held, then the first at which it did not — the ladder's step is 0.01, so that pair *is* the
resolution. **Every derived fraction falls inside its own measured bracket, in all fifteen measured
cells**, which is the check that the derivation is the ledger the code implements:

| heating | spend | normal (90) | uncommon (117) | rare (144) | epic (171) | legendary (225) |
|---|---|---|---|---|---|---|
| **none** | 50 MW | 0.56 / 0.55 · **0.5556** ✓ | 0.43 / 0.42 · **0.4274** ✓ | 0.35 / 0.34 · **0.3472** ✓ | 0.30 / 0.29 · **0.2924** ✓ | 0.23 / 0.22 · **0.2222** ✓ |
| rung 1 | 55 MW | *0.611* | *0.470* | *0.382* | *0.322* | *0.244* |
| **rung 2** | 60 MW | 0.67 / 0.66 · **0.6667** ✓ | 0.52 / 0.51 · **0.5128** ✓ | 0.42 / 0.41 · **0.4167** ✓ | 0.36 / 0.35 · **0.3509** ✓ | 0.27 / 0.26 · **0.2667** ✓ |
| rung 3 | 65 MW | *0.722* | *0.556* | *0.451* | *0.380* | *0.289* |
| rung 4 | 70 MW | *0.778* | *0.598* | *0.486* | *0.409* | *0.311* |
| **rung 5** | 75 MW | 0.84 / 0.83 · **0.8333** ✓ | 0.65 / 0.64 · **0.6410** ✓ | 0.53 / 0.52 · **0.5208** ✓ | 0.44 / 0.43 · **0.4386** ✓ | 0.34 / 0.33 · **0.3333** ✓ |

Bold rows are measured — *held / first short · derived* — and italic rows are `spend ÷ limit` and
were not run. Three measured rows spread across the ladder rather than two ends is what makes the
italic rows quotable at all: the derivation is checked at the bottom, the middle and the top and
agrees at every one.

**The 2026-08-31 table is not withdrawn, it has moved up the ladder.** It read 0.833 / 0.641 / 0.521 /
0.439 / 0.333 against brackets of 0.84-0.83 / 0.65-0.64 / 0.53-0.52 / 0.44-0.43 / 0.34-0.33, taken at
60 MW of flow limit against a 50 MW spend — and rung 5 above reproduces every one of them exactly,
both the derived fractions and the brackets around them. That is not a coincidence and it is worth saying why: #425
sized 90 MW at 1.2× the *top* of the heating ladder exactly as 60 MW had been 1.2× of the only spend
there was, so the old table describes today's fully-researched reactor. What #425 actually added is
everything *below* it — a normal reactor whose owner has researched no heating holds full heating
down to 0.556 where the old table says 0.833, which is a third lower.

Where full heating stops holding, as a fraction of full supply — shorter is more resilient. One
character is 0.02, so the whole scale is `f = 1`:

```
                     0                        0.5                       1.0
                     |------------------------|------------------------|
normal     rung 5    ██████████████████████████████████████████          0.833
           rung 2    █████████████████████████████████                   0.667
           none      ████████████████████████████                        0.556
legendary  rung 5    █████████████████                                   0.333
           rung 2    █████████████                                       0.267
           none      ███████████                                         0.222
```

Normal and legendary are the ends of the quality ladder; the three rungs under each are the three
heating states measured. **Quality shortens a bar and heating lengthens it**, and the two sets do
not overlap: a legendary reactor at the top of the heating ladder (0.333) is still more
brownout-resilient than a normal one that has researched nothing (0.556).

**The assumption under the whole table survives the re-measurement**: a shorted reactor asks for its
whole `input_flow_limit` rather than for the heating it spends. Had it asked only for its spend,
every level would have browned out at the same place and quality would have bought nothing here
either. Fifteen cells at three different spends agreeing with `spend ÷ limit` is a stronger statement
of it than the five cells at one spend that it replaces.

**The structural conclusion is unchanged and now rests on more.** Quality raises the limit and never
the spend, which is the safe direction on every rung of the heating ladder; `check_input_flow()` in
`control.lua` refuses to load unless the limit covers the heating, and since #425 it checks the TOP
of the ladder rather than the shipped value, which is the reason 90 MW is 90 and not 60.

**`scripts/probe-quality-brownout.ps1` is the rig**, added under
[#146](https://github.com/trulsjo/realistic-fusion-refreshed/issues/146) and given a
`-HeatingRungs` switch by [#429](https://github.com/trulsjo/realistic-fusion-refreshed/issues/429),
which is what makes a row of the grid above addressable: the rig researches that many rungs of
`rf-plasma-heating-*` before the ladder starts, refuses a technology it cannot find rather than
reporting a silently unresearched force, and prints the rungs it researched beside the rows they
produced. Five `rf-reactor`s, one per
level, each alone on its own electric network, supplied down a fixed ladder from full supply to a
fifth of it one hundredth of the reactor's own flow limit at a time — so the resolution of every
fraction above is 0.01 and the report prints the rung that held and the rung that did not rather than
an exact-looking number. Below the knee each cell draws exactly `f × input_flow_limit`, which is the
note's model reading back off the wire.

It is a **probe, not a lane on `scripts/check-brownout.ps1`**, and that is deliberate. A gate
asserting brownout behaviour at legendary would commit the mod to guaranteeing it, and ADR 0003
tolerates Space Age rather than targeting it. Whether the mod should make that promise is a scope
decision and Truls's; moving these rows into the gate afterwards is small.

Two things the rig had to get right, both recorded because both produced a wrong answer first. The
supply interface delivers out of its own buffer, so that buffer is at once a reserve that hides the
knee and a ceiling on what it can deliver: at 10 MJ the normal, uncommon and rare cells each read a
rung optimistic, since a rung's shortfall is a hundredth of the cell's own flow limit and 10 MJ
covers the smaller ones for most of a rung — while at 1 kJ the interface supplied 60 kW and nothing
browned out at all. The buffer is one tick of full production now, which is the smallest size that
can still deliver what the rig sets. And flow statistics in 2.0 are keyed by name **and
quality** — asked for the bare name, four of the five cells report having drawn nothing ever.

**The aneutronic reactor is measured too, since 2026-10-01 against Factorio 2.0.77 (#438)**, by the
same rig with `-Reactor rf-aneutronic-reactor`, burning D-He3. **It is one row and not a grid, and
nobody should look for a heating family:** all three research ladders are neutronic only (ADR 0020
decision 4, ADR 0038 decision 5), so `rf-aneutronic-reactor` has no researchable spend and its
fraction cannot move. One run is the whole of it:

| | normal (240) | uncommon (312) | rare (384) | epic (456) | legendary (600) |
|---|---|---|---|---|---|
| **aneutronic**, 200 MW | 0.84 / 0.83 · **0.8333** ✓ | 0.65 / 0.64 · **0.6410** ✓ | 0.53 / 0.52 · **0.5208** ✓ | 0.44 / 0.43 · **0.4386** ✓ | 0.34 / 0.33 · **0.3333** ✓ |

Same notation as the table above. The five flow limits were read off the running game — 240, 312,
384, 456 and 600 MW, the middle three to within 1.2e-5 MW of those — and every cell's full-supply draw was 200
MW exactly, so the spend in the fraction is measured rather than assumed. **Every derived fraction
falls inside its own measured bracket.** The row coincides with `rf-reactor`'s TOP heating rung, not
with its shipped one, because 240 ÷ 200 is the same 1.2 that 90 ÷ 75 is. Each box was held at its
own 3 000 units, not at the neutronic 1 000, which would have run the reactor at a third of its
density.
**It is not free energy**: the reactor still never spends more than `heating_power_w`, so the extra
headroom buys resilience rather than power. It is also the only thing on the whole list that reads
like a quality bonus somebody would have designed on purpose.

### Contention: how a short network is split

**Measured 2026-10-01 against Factorio 2.0.77 (#439)** by `scripts/probe-brownout-contention.ps1`,
a rig of its own because the one above isolates every reactor on purpose. Three cells, each one
electric network holding exactly two consumers — the rig errors unless both are on one network and
no two cells share one — supplied down a ladder from 1.2 to 0.2 of what the pair spends, in steps of
0.05, with nothing researched (asserted, rung by rung):

| cell | a | b | what the supply did below full |
|---|---|---|---|
| `pair` | `rf-reactor`, normal — asks 90 MW | `rf-reactor`, **legendary** — asks 225 MW | **a share of what each asks for**, at every rung |
| `secondary` | `rf-reactor`, normal — asks 90 MW | a `secondary-input` load with the reactor's own electric source | an even split, which is the same rule at equal asks |
| `primary` | `rf-reactor`, normal | the same load at **`primary-input`** | **the load first, in full**; the reactor gets what is left |

"A share of what each asks for" is the model the table above assumes: the supply is divided in
proportion to each consumer's `input_flow_limit`, and one handed more than it spends keeps its spend
— its buffer is full and it stops asking — and the rest goes to the other. *(#534, below,
corrects the mechanism and keeps the result: such a member settles with room in its buffer.)* In `pair` that is the
legendary reactor holding a full 50 MW while the normal one alone absorbs the shortfall, down to
70% of supply, and then the two splitting 90 : 225 — at 50% of supply, 14.29 MW against 35.71.
**Both `secondary-input` cells match it to within 2e-6 MW on every one of the 21 rungs.** So the assumption
the table rests on holds with a second reactor on the network, and it says something a player can
use: **a higher-quality reactor on a shared network does not merely brown out later, it takes the
lower-quality one's share** — the normal reactor in `pair` goes short the moment the network supplies
less than the pair spends (45 MW at 95 MW of supply), where alone it holds until its own supply
falls below its 50 MW spend.

**A different priority class is not a share at all.** Against a `primary-input` load the reactor is
served second, from what remains, and at half of the pair's spend and below it draws nothing. So the
brownout fractions describe a reactor among `secondary-input` consumers and say nothing for one
sharing a network with `primary-input` loads, which take their whole ask first.

**Extended 2026-10-02 against Factorio 2.0.77 (#487)**, same rig, same ladder, nothing researched
(asserted again), with two more cells and the prediction generalised. Within a class it is now a
water-fill — share by ask, cap each at its spend, re-share the excess among the rest, repeat — and
between classes it is the reading above, served in order: `primary-input`, `secondary-input`,
`tertiary`. **All five cells match it to within 2e-6 MW on every one of the 21 rungs** (worst
1.833e-6), the three #439 cells included, so the `primary` rows that deviated from a plain share
are now predicted rather than read off.

| cell | members | what the supply did below full |
|---|---|---|
| `four` | `rf-reactor` at normal, uncommon, rare and legendary — asks 90, 117, 144 and 225 MW, 50 MW spend each | the water-fill, **three caps deep** |
| `tertiary` | `rf-reactor`, normal, against the load at **`tertiary`**; supply at `secondary-output` | **the reactor first, in full**; the load gets the surplus |

In `four` the caps land where the arithmetic puts them: legendary is full above 128 MW of supply
(f = 0.64), rare above 171.875 (0.859), uncommon above about 188.5 (0.942), and the measured rungs
fall on the right side of each — uncommon is full at 0.95 and 45.22 MW at 0.90, rare full at 0.90 and
49.23 at 0.85, legendary full at 0.65 and 46.88 at 0.60. Below 128 MW it is a plain 90 : 117 : 144 :
225 share — at 100 MW, 15.63, 20.31, 25 and 39.06. The `pair` finding scales with it: at 95% of
what the four spend, **the normal reactor gets 40 MW of its 50**: the three that ask more are
all still held at their spend there, and it absorbs the whole 10 MW shortfall alone.

The `tertiary` cell's supply is not the rig's usual one: vanilla's `electric-energy-interface` is
itself `tertiary`, and the 2.0.77 docs for
[`ElectricUsagePriority`](https://lua-api.factorio.com/2.0.77/types/ElectricUsagePriority.html)
describe `tertiary` input as collecting "the overproduction", which a `tertiary` supply is not. So
this cell's supply is at `secondary-output`, the class those docs give steam generators. Against it
the reactor holds its 50 MW down to 50 MW of
supply and the load gets exactly what is left over (45 MW at 95, 5 at 55, nothing from 50 down). The
load gave nothing back on any rung. Why was not measured, so this says nothing about an accumulator
discharging into a short network; #492 and #528 below measure one.

**A `tertiary` load on a `tertiary` supply draws nothing at all**
([#490](https://github.com/trulsjo/realistic-fusion-refreshed/issues/490)). Measured 2026-10-03
against Factorio 2.0.77, same rig, same ladder, nothing researched (asserted again), in a sixth cell,
`tert-tert`: the `tertiary` cell's two members on the rig's usual supply, vanilla's
`electric-energy-interface`, alone on a network of its own.

| supply, MW | reactor drew | load drew | class order predicted for the load |
|---|---|---|---|
| 120 to 100, five rungs | 50 | **0** | 50 |
| 95 to 55, nine rungs | 50 | **0** | 45 down to 5 |
| 50 to 20, seven rungs | all of the supply | 0 | 0 |

The reactor is where class order puts it on all 21 rungs, to within 1.25e-6 MW. The load drew
nothing where the prediction gave it the whole surplus: 50 MW on the top five rungs, 45 down to
5 on the next nine. It gave nothing back on any rung. The supply's class is the only thing that
differs from `tertiary`, where the same load drew the whole surplus. So the class-ordered
prediction holds for a `tertiary` load on a `secondary-output` supply and not on a `tertiary`
one. That fits the docs' wording,
if what a `tertiary` supply makes does not count as overproduction, but the probe measured the
draw and not the reason. The other five cells still match to within 2e-6 MW on every rung
(worst 1.833e-6), so the sentence above about all five stands for those five.

**All three input classes on one network are served in class order**
([#491](https://github.com/trulsjo/realistic-fusion-refreshed/issues/491)). Measured 2026-10-04
against Factorio 2.0.77, same rig, same ladder, nothing researched (asserted again), in a seventh
cell, `three`: the load at `primary-input`, a normal `rf-reactor` and the load at `tertiary`, each
asking 90 MW and spending 50, on the `tertiary` cell's `secondary-output` supply, alone on a
network of its own.

| supply, MW | `primary-input` load drew | reactor drew | `tertiary` load drew |
|---|---|---|---|
| 180 to 150, five rungs | 50 | 50 | 50 |
| 142.5 to 105, six rungs | 50 | 50 | supply less 100: 42.5 down to 5 |
| 97.5 to 52.5, seven rungs | 50 | supply less 50: 47.5 down to 2.5 | 0 |
| 45 to 30, three rungs | all of the supply | 0 | 0 |

Each class is served in full from what the one before left, on all 21 rungs, to within 1.25e-6
MW of the prediction. No member gave anything back. The supply is `secondary-output`, so this
says nothing about three classes on a `tertiary` supply, where `tert-tert` above shows the
`tertiary` member is not served.

**An accumulator discharging into a short network gives by ask, like any other supply**
([#492](https://github.com/trulsjo/realistic-fusion-refreshed/issues/492)). Measured 2026-10-04
against Factorio 2.0.77, same rig, nothing researched (asserted again), in an eighth cell,
`discharge`, alone on a network of its own. It is not on the ladder: a draining accumulator is
not a steady state, so the cell is read every second instead. A normal and a legendary
`rf-reactor`, asking 90 and 225 MW and spending 50 each, on a `secondary-output` supply held at
50 MW, half of what the two spend. Beside them stand eighteen vanilla accumulators, 5.4 MW of
output and 90 MJ between them, empty for 1200 ticks and then charged to their full buffer on one
tick. The engine reports their priority as `managed-accumulator`, not `tertiary`.

| seconds after the charge | accumulators gave, MW | normal reactor drew | legendary reactor drew |
|---|---|---|---|
| the three before it | 0 | 14.29 | 35.71 |
| 1 to 16 | 5.4 | 15.83 | 39.57 |
| 17 | 3.6 | 15.31 | 38.29 |
| 18 to 30 | 0 | 14.29 | 35.71 |

The accumulators gave their full 5.4 MW for sixteen seconds and the last 3.6 MJ in the
seventeenth, 90 MJ in all, and took nothing back. What they gave was split 90 : 225, the same
share by ask the supply's own 50 MW is split by: of 5.4 MW, 1.54 to the normal reactor and 3.86
to the legendary one, where an even split would be 2.7 each. Every one of the 33 rows is within
1.8e-6 MW of the water-fill of the supply plus what the accumulators were measured giving.
*(#544, below, predicts it.)* So
the legendary reactor takes the larger part of a discharge as it takes the larger part of the
supply. Neither reactor is capped at this supply. #528's `acc-supply` cell, below, lifts a lone
reactor to its spend, and #538's `discharge-cap`, further below, caps one of two so the
re-share is seen.

**Members that spend differently are split by the same water-fill**
([#493](https://github.com/trulsjo/realistic-fusion-refreshed/issues/493)). Measured 2026-10-04
against Factorio 2.0.77, same rig, same ladder, nothing researched (asserted again), in a ninth
cell, `aneutronic`: a normal `rf-reactor` and a normal `rf-aneutronic-reactor` on the rig's
usual supply, alone on a network of its own. Every reactor in the other cells spends 50 MW.
These ask 90 and 240 MW and spend 50 and 200, read off the prototypes and `reactor-logic`, and
each is kept at its own box's fill of its own plasma, 1000 units of D-D and 3000 of D-He3.

| supply, MW | `rf-reactor` drew | `rf-aneutronic-reactor` drew |
|---|---|---|
| 300 to 250, five rungs | 50 | 200 |
| 237.5 to 187.5, five rungs | 50 | supply less 50: 187.5 down to 137.5 |
| 175 to 50, eleven rungs | 90 parts in 330: 47.73 down to 13.64 | 240 parts in 330: 127.3 down to 36.36 |

A 90 : 240 share hands the D-D reactor its 50 MW while the supply is above 183.3 MW, and the
measured rungs fall on the right side of that: full at 187.5 and 47.73 at 175. So below what
the two spend the aneutronic reactor absorbs the whole shortfall alone, down to 73% of it, the
way the normal reactor does beside a legendary one in `pair`. All 21 rungs are within 7.3e-6 MW
of the prediction. That is wider than the 2e-6 of the cells above, on a member drawing four
times as much. Neither gave anything back.

**The prediction holds at the top heating rung, and it fails in the same one cell**
([#494](https://github.com/trulsjo/realistic-fusion-refreshed/issues/494)). Measured 2026-10-04
against Factorio 2.0.77 by `probe-brownout-contention.ps1 -HeatingRungs 5`: the whole rig, every
cell above, with the rig's force holding `rf-plasma-heating-1` to `-5` and no other rung of any
ladder, asserted rung by rung. Research is per force and the rig has one, so no network here
mixes researched and unresearched reactors. Every `rf-reactor` then spends 75 MW against the
same 90 MW ask at normal, the loads spend 75 with it, and `rf-aneutronic-reactor`, which no
ladder reaches, still spends 200. The ladder is the same 1.2 down to 0.2 of what each cell
spends, so every supply is larger in MW than in the tables above.

| cell | worst deviation from the prediction, MW | what moved |
|---|---|---|
| `pair` | 3.2e-6 | legendary full above 105 MW of supply, where it was 70; 21.43 against 53.57 at 75 MW |
| `secondary` | under 1e-13 | nothing: an even split |
| `primary` | under 1e-13 | nothing: the load first |
| `four` | 1.8e-6 | caps at 192, 257.8 and 282.7 MW, the same fractions of the cell's spend |
| `tertiary` | under 1e-13 | nothing: the reactor first |
| `tert-tert` | **75** | the load drew nothing on any rung, as in #490 |
| `three` | 1.4e-13 | nothing: class order |
| `aneutronic` | 5e-6 | **the D-D reactor is no longer held at its spend below full supply** |
| `discharge` | 1.1e-6, on 33 rows | 5.4 MW split 1.54 : 3.86 again, on 21.43 and 53.57 |

Seven of the eight ladder cells the rig then held match on all 21 rungs, and the discharge cell
on all 33 rows. (#528's six cells came after this run. #538, below, has them at rung 5 as a
table.)
`tert-tert` misses by the load's whole predicted draw, as it does with nothing researched: 75 MW
on the top five rungs, 67.5 down to 7.5 on the next nine.

**Where every member's spend moves together, the caps stay at the same fraction of supply.**
`pair` and `four` cap at 0.70, and at 0.64, 0.859 and 0.942, of what the cell spends, as they do
with nothing researched, because asks did not move and every spend rose by the same half.

**Where one member's spend moves and the other's does not, the cap moves.** In `aneutronic` a
90 : 240 share hands the D-D reactor 75 MW only at 275 MW of supply, which is exactly what the
two spend. So at this rung there is no band where the aneutronic reactor absorbs the shortfall
alone: at 95% of supply the two draw 71.25 and 190, both 5% short. With nothing researched that
band ran from 250 MW down to 183.3.

Only this rung was run under #494. #538, below, runs rungs 1 to 4. A state with the
confinement or plant-efficiency ladder held is not measured; those move no electrical spend.

**The #490 result is the supply's class, not the rig's load: a real accumulator draws nothing
from a `tertiary` supply either, and a `tertiary` load draws nothing from a charged accumulator**
([#528](https://github.com/trulsjo/realistic-fusion-refreshed/issues/528)). Measured 2026-10-04
against Factorio 2.0.77, same rig, nothing researched (asserted again), in six more cells, each
alone on a network of its own. The accumulators are vanilla's, eighteen to a cell under one
name+quality key: 5.4 MW in, 5.4 MW out and 90 MJ between them.

*As the load*, on the ladder, beside a normal `rf-reactor`. The accumulators are emptied every
second, so they ask for their whole 5.4 MW on every rung and never fill.

| cell | supply | reactor drew | accumulators drew | predicted for them |
|---|---|---|---|---|
| `acc-tert` | vanilla's interface, `tertiary` | as predicted, all 21 rungs | **0 on all 21** | 5.4 on the top five rungs, 2.63 on the sixth, 0 on fifteen |
| `acc-sec` | the rig's `secondary-output` | as predicted, all 21 rungs | 5.4 on the top five, 2.63 on the sixth, 0 on fifteen | the same |

`acc-sec` is within 1.25e-6 MW of the prediction on every rung. `acc-tert` is `tert-tert` with a
real accumulator where the rig's copied interface was, and it reads the same way: the reactor
where class order puts it, the `tertiary`-class member with nothing.

*As part of the supply*, off the ladder, read every second like `discharge`: a normal
`rf-reactor` on a `secondary-output` supply, with the accumulators charged on one tick.

| cell | supply | `tertiary` load | reactor drew, MW | accumulators gave | load drew |
|---|---|---|---|---|---|
| `acc-supply` | 45 MW, 0.9 of the reactor's spend | none | 50.4 for 16 s, 48.6 in the 17th, then 45 | 5.4 MW for 16 s, 3.6 MJ in the 17th | |
| `acc-supply-load` | 45 MW | beside them | the same | the same | **0 on all 33 rows** |
| `acc-spare` | 50 MW, the reactor's spend | none | 54.83 in the first second, then 50 | 4.83 MJ in the first second, then nothing; 85.17 MJ left | |
| `acc-spare-load` | 50 MW | beside them | the same | the same | **0 on all 33 rows** |

In `acc-spare-load` the accumulators stood at 85.17 MJ for 29 seconds beside a `tertiary` load
asking 90 MW and getting nothing, and gave it nothing. So charged accumulators serve a
`secondary-input` reactor and do not serve a `tertiary` load. With `tert-tert` and `acc-tert`
that is three pairings of a `tertiary`-class source with a `tertiary`-class sink, and the sink
drew nothing in each: interface to interface, interface to accumulator, accumulator to
interface. #538's `acc-acc`, below, is the fourth, accumulator to accumulator. The engine
reports an accumulator's priority as `managed-accumulator`, not the `tertiary` its prototype
declares, and the three pairings read alike all the same.

**What the 2.0.77 docs say, quoted.** The whole of
[`ElectricUsagePriority`](https://lua-api.factorio.com/2.0.77/types/ElectricUsagePriority.html)
on the class is: `"tertiary"` — "As input/output used for accumulators, to collect the
overproduction or provide energy when neither primary/secondary output can't." "Overproduction"
is not defined there, and the word does not appear on the 2.0.77 pages for `ElectricEnergySource`,
`AccumulatorPrototype`, `ElectricEnergyInterfacePrototype` or
`LuaElectricEnergySourcePrototype`. `managed-accumulator` appears on none of the five. The
measurements fit one reading of that sentence, that overproduction is what primary and
secondary outputs make beyond demand, so nothing a `tertiary` source holds counts. That reading
is this note's and not the docs'.

**The discharge cells also show where the prediction's cap is wrong.** It hands a member no more
than it spends, on the grounds that its buffer is full. A reactor that has been short has an
empty buffer, and it took the accumulators' whole 5.4 MW in `acc-supply`: 50.4 MW against a
50 MW spend, 0.4 MW over the prediction on 16 rows, in both cells at that supply. In `acc-spare`
it took 4.83 MJ over its spend in the first second and then stopped. The ladder cells never
show this, because each rung's first half lets the buffers settle. *(#534, below, replaces the
cap. It also corrects "its buffer is full": a member held at its spend settles with room in
its buffer, and a settled rung shows no over-draw because that room has stopped changing.)*

**A member asks for the room in its buffer, and the water-fill is where that settles**
([#534](https://github.com/trulsjo/realistic-fusion-refreshed/issues/534)). Measured 2026-10-04
against Factorio 2.0.77, same rig, nothing researched (asserted again). The probe now reads
every member's buffer where each measured period starts, and predicts tick by tick. Each tick a
member asks for its `input_flow_limit` or for the room left in its buffer, whichever is less.
Each class's supply is divided in proportion to those asks. The member then spends out of its
buffer. What charged accumulators give is still read and not predicted: it is added to the
supply at their output limit until the second's reading is spent. *(#544, below, predicts it.)*

**Raising the water-fill's cap by the buffer's room was tried first, and it was wrong.** It
matched the four over-draw cells and broke every ladder cell that had matched, by up to
0.56 MW in `four`. A member held at its spend does not have a full buffer. In `pair` at 75 MW
of supply the legendary reactor's 10.67 MJ buffer stood 3 MJ short of full at the start of the
measured half. At that room it asks for 3 MJ a tick against the normal reactor's 1.5, and two
thirds of the 1.25 MJ supplied each tick is the 0.833 MJ it spends. So the engine does not cap
a member at its spend. The buffer settles at the room whose ask draws exactly the spend, and
the water-fill of #487 is that steady state, not the rule.

| cells | worst deviation from the tick-by-tick prediction, MW | under the water-fill |
|---|---|---|
| `pair`, `secondary`, `primary`, `four`, `tertiary`, `three`, `acc-sec`, 21 rungs each | 1.8e-6 | matched |
| `aneutronic`, 21 rungs | 7.3e-6 | matched, 7.3e-6 |
| `discharge`, 33 rows | 1.8e-6 | matched |
| `acc-supply`, `acc-supply-load`, 33 rows each | under 1e-14 | **0.4 MW out on 16 rows** |
| `acc-spare`, `acc-spare-load`, 33 rows each | 1.25e-6 | **4.83 MJ out in the first second** |
| `tert-tert` | 50.92 | 50 |
| `acc-tert` | 5.4 | 5.4 |

**All four over-draw cells are now predicted**, and the eight ladder cells and the discharge
cell that matched before still match. In those four the test is one-sided. A lone reactor's
ask is over the supply and the measured discharge together on every tick, so its prediction
is their sum, and it could only miss if the accumulators had given more than the buffer had
room for. The rule is tested where a supply is split: the ladder cells, and #538's
`discharge-cap` below. *(#544, below, predicts the discharge too, so the four are no longer
one-sided.)* In `acc-spare` the reactor's buffer had 5.667 MJ of room
when the accumulators were charged. It took 4.833 MJ of that in the first second and stood at
0.833 MJ of room on every row after. 0.833 MJ is one tick's spend: `spend` in
`realistic-fusion-refreshed/control.lua` takes it out of the buffer before the rig reads, so
a fully supplied reactor always reads one tick short.

**The two cells that missed still miss, and one by more.** `tert-tert` and `acc-tert` are the
class rule, not the buffer: a `tertiary`-class member draws nothing from a `tertiary` supply.
`tert-tert`'s prediction for the load is 0.92 MW higher on the top four rungs than it was,
because the load's buffer stands empty and the prediction now fills it.

**The prediction holds at every heating rung, and the over-draw shrinks as the spend rises**
([#538](https://github.com/trulsjo/realistic-fusion-refreshed/issues/538)). Measured 2026-10-04
against Factorio 2.0.77 by `probe-brownout-contention.ps1 -HeatingRungs 1` to `-HeatingRungs 5`,
one run a rung: the whole rig, with the force holding that many rungs of the heating ladder
and no other rung of any ladder, asserted rung by rung. Every figure is beside the tick-by-tick
prediction of #534. "Worst" is over every cell but `tert-tert` and `acc-tert`.

| heating rungs held | `rf-reactor` spends, MW | worst deviation, MW | `tert-tert` misses by | `acc-tert` misses by | `acc-supply`: supply + 5.4 | `acc-spare`: over-draw in the first second, MJ |
|---|---|---|---|---|---|---|
| 0 | 50 | 7.3e-6 | 50.92 | 5.4 | 50.4, 0.4 over the spend | 4.833 |
| 1 | 55 | 6.8e-6 | 55.91 | 5.4 | 54.9, under it | 4.25 |
| 2 | 60 | 7.3e-6 | 60.9 | 5.4 | 59.4, under it | 3.667 |
| 3 | 65 | 5.9e-6 | 65.89 | 5.4 | 63.9, under it | 3.083 |
| 4 | 70 | 5.5e-6 | 70.88 | 5.4 | 68.4, under it | 2.5 |
| 5 | 75 | 5.0e-6 | 75.88 | 5.4 | 72.9, under it | 1.917 |

The worst deviation is `aneutronic`'s at every rung. The 0.4 MW over-draw in the two
`acc-supply` cells exists only with nothing researched: from rung 1 the supply and the
discharge together are under the spend. The first-second over-draw in the two `acc-spare`
cells falls by 0.583 MJ a rung. A reactor at exactly its spend holds less room the more it
spends: 5.667 MJ at rung 0 down to 3.167 at rung 5, one tick's spend of which it keeps.

In `aneutronic` a 90 : 240 share hands the D-D reactor its spend only above 201.7, 220,
238.3 and 256.7 MW of supply at rungs 1 to 4, where the two spend 255, 260, 265 and 270. So
the band where the aneutronic reactor absorbs the shortfall alone narrows from the top 21% of
the cell's spend at rung 1 to the top 5% at rung 4, and is gone at rung 5. The measured rungs
fall on the right side each time: at rung 3 the D-D reactor is full at 238.5 MW and draws
61.43 at 225.2, and at rung 4 it draws 69.95 at 256.5.

**#528's six cells at heating rung 5**, from the `-HeatingRungs 5` run above. The reactor
spends 75 MW and asks 90.

| cell | supply | reactor drew, MW | accumulators | `tertiary` load |
|---|---|---|---|---|
| `acc-tert` | `tertiary`, 96.48 down to 16.08 MW | as predicted, all 21 rungs | **drew 0 on all 21**; predicted 5.4 on the top five rungs, 1.38 on the sixth, 0 on fifteen | |
| `acc-sec` | `secondary-output`, the same ladder | as predicted, all 21 rungs | drew 5.4 on the top five, 1.38 on the sixth, 0 on fifteen, as predicted | |
| `acc-supply` | 67.5 MW, 0.9 of the spend | 72.9 for 16 s, 71.1 in the 17th, then 67.5 | gave 5.4 MW for 16 s, 3.6 MJ in the 17th | |
| `acc-supply-load` | 67.5 MW | the same | the same | **0 on all 33 rows** |
| `acc-spare` | 75 MW, the spend | 76.92 in the first second, then 75 | gave 1.917 MJ in the first second, then nothing; 88.08 MJ left | |
| `acc-spare-load` | 75 MW | the same | the same | **0 on all 33 rows** |

The five that are predicted are within 2.6e-8 MW on every row. `acc-tert` misses by the
accumulators' whole predicted draw, as it does unresearched.

**Accumulator to accumulator: nothing, the fourth pairing of four**
([#538](https://github.com/trulsjo/realistic-fusion-refreshed/issues/538)). Same runs, a cell
`acc-acc`, alone on a network of its own: `acc-spare-load` with six legendary accumulators
where the rig's `tertiary` load was. They are legendary because the eighteen charged ones
already hold the normal name+quality key. They ask 4.5 MW between them, hold up to 180 MJ, and
are emptied every second so they never stop asking. The engine reports them
`managed-accumulator` too.

| heating rungs held | supply, MW | charged accumulators gave | they then held | the six empty ones drew |
|---|---|---|---|---|
| 0 | 50 | 4.833 MJ, to the reactor, in the first second | 85.17 MJ for 29 s | **0 on all 33 rows** |
| 5 | 75 | 1.917 MJ, likewise | 88.08 MJ for 29 s | **0 on all 33 rows** |

Rungs 1 to 4 read the same way. The reactor's rows are `acc-spare`'s. So with `tert-tert`,
`acc-tert` and `acc-spare-load` that is all four pairings of a `tertiary`-class source with a
`tertiary`-class sink, and the sink drew nothing in each. The prediction could not miss in this
cell while what the charged accumulators give was read. *(#544, below, predicts it, and the
cell misses.)*

**A discharge that caps one of two reactors re-shares the excess as the prediction says**
([#538](https://github.com/trulsjo/realistic-fusion-refreshed/issues/538)). Same runs, a cell
`discharge-cap`, alone on a network of its own: `discharge` with its supply at 0.68 of what
the two reactors spend. By ask the legendary reactor reaches its spend at 0.70. Unresearched
that is 68 MW of supply, then 73.4 with the accumulators' 5.4.

| seconds after the charge | accumulators gave, MW | normal reactor drew | legendary reactor drew | room in the legendary reactor's buffer at the start, MJ |
|---|---|---|---|---|
| the three before it | 0 | 19.43 | 48.57 | 10.67 |
| 1 and 2 | 5.4 | 20.97 | 52.43 | 10.67, then 8.24 |
| 3 | 5.4 | 21.06 | 52.34 | 5.81 |
| 4 | 5.4 | 23.14 | 50.26 | 3.47 |
| 5 to 16 | 5.4 | 23.40 | 50 | 3.21 |
| 17 | 3.6 | 22.30 | 49.30 | 3.21 |
| 18 to 30 | 0 | 19.43 | 48.57 | 3.91, back to 10.67 by the 23rd |

For two seconds the 73.4 MW is split 90 : 225, which hands the legendary reactor 2.43 MW more
than it spends, and its buffer fills. From the third second the room left is under what its
flow limit asks for, its ask falls, and the normal reactor gets the difference: 23.40 MW from
the fifth second, against 20.97 by ask alone. The legendary reactor's buffer stops 3.21 MJ
short of full. All 33 rows are within 1.5e-6 MW of the prediction unresearched, and within
3.3e-6 at every rung to 5, where the supply is 102 MW and the re-share lifts the normal
reactor from 30.69 to 32.40.

**What a charged accumulator gives is predicted, and it misses only where #490 does**
([#544](https://github.com/trulsjo/realistic-fusion-refreshed/issues/544)). Measured 2026-10-04
against Factorio 2.0.77 by `probe-brownout-contention.ps1` with nothing researched and with
`-HeatingRungs 5`, each asserted rung by rung. The prediction no longer takes the accumulators'
discharge as an input. It carries each store: what it holds where the second starts, its
output limit, and when it gives. It gives when the supply does not cover what the consumers
ask, which is the docs' "provide energy when neither primary/secondary output can", and only
the part not covered. The docs do not say whose asks count. The prediction counts every
class's, as its class order serves every class, so a store is predicted to serve a
`tertiary`-class member. Each store's predicted discharge is printed beside what it gave, with
the deviation. Its room is now read after the rig charges it, so the first second starts from
the charge.

| cell | consumers' worst deviation, MW, rung 0 / rung 5 | stores' worst deviation, MW, rung 0 / rung 5 | |
|---|---|---|---|
| `discharge` | 1.8e-6 / 1.1e-6 | 0 / 0 | matched |
| `acc-supply` | 7.1e-15 / 0 | 0 / 0 | matched |
| `acc-supply-load` | 7.1e-15 / 0 | 0 / 0 | matched |
| `acc-spare` | 1.25e-6 / 2.5e-8 | 1.0e-9 / 3.9e-10 | matched |
| `discharge-cap` | 1.4e-6 / 3.2e-6 | 0 / 0 | matched |
| `acc-spare-load` | **5.4 / 5.4**, the `tertiary` load | **5.4 / 5.4** | the class miss |
| `acc-acc` | **4.5 / 4.5**, the six empty accumulators | **4.5 / 4.5** | the class miss |

All 33 rows of the five that match are within those figures, and those five matched before.

**The ten ladder cells read as they did before #544**
([#554](https://github.com/trulsjo/realistic-fusion-refreshed/issues/554)). Re-run 2026-10-04
against Factorio 2.0.77 by `probe-brownout-contention.ps1` with nothing researched and with
`-HeatingRungs 5`, each asserted rung by rung, every cell reporting all 21 rungs. A rung is 1200
ticks, and the second half of each, 600 ticks, is what is measured. No ladder cell
holds a store, so the store prediction should leave them alone, and it does. No reactor here is
fed by a heater: the rig holds each one's plasma at its box's fill.

| cell | worst deviation from the prediction, MW, rung 0 / rung 5 | |
|---|---|---|
| `pair` | 1.8e-6 / 3.2e-6 | matched |
| `secondary` | 1.25e-6 / 1.4e-14 | matched |
| `primary` | 1.25e-6 / 2.4e-14 | matched |
| `four` | 1.8e-6 / 1.8e-6 | matched |
| `tertiary` | 1.25e-6 / 2.4e-14 | matched |
| `three` | 1.25e-6 / 1.5e-13 | matched |
| `aneutronic` | 7.3e-6 / 5.0e-6 | matched |
| `acc-sec` | 1.25e-6 / 1.4e-14 | matched |
| `tert-tert` | **50.92 / 75.88** | the class miss |
| `acc-tert` | **5.4 / 5.4** | the class miss |

The eight that matched under #534 still match, and the worst of them is `aneutronic`'s at both
rungs, 7.3e-6 and 5.0e-6 MW, the figures #534's and #538's tables give. The two that missed
miss by what they did.
In `acc-supply-load` the `tertiary` load is predicted 0 and draws 0, but that does not test the
class: the supply and the discharge together are under the reactor's ask on every row, so
nothing is left for the load in any reading.

In the two that miss, the reactor still matches on every row, within 1.25e-6 MW unresearched
and 2.5e-8 at rung 5. The miss is the `tertiary`-class sink. From the second second on, the
reactor asks exactly its spend, which the supply covers, and the store is predicted to give
the sink its whole ask: 5.4 MW to the `tertiary` load and 4.5 to the six empty accumulators,
on rows 2 to 30 at both rungs. In the first second the reactor's buffer fills first and the
sink is predicted the rest: 0.567 and 0.477 MW unresearched, and 3.48 and 2.91 at rung 5. The
sink drew nothing on any row, and the store gave nothing past what the reactor took. This is
the class miss #490 found, a `tertiary`-class sink drawing nothing from a `tertiary`-class
source, and not a new one. Excluding `tertiary`-class asks from what a store covers would make
both cells match. It would also model the miss away rather than show it, and why the engine
does this is still read off one sentence of the docs.

Whether the mod should guarantee any of this is the scope decision above and Truls's; the
probe asserts nothing about the answer.

### The residual boiler leak, since quality multiplies it

`rf-reactor` is a `boiler` in `output-to-separate-pipe` mode with `energy_consumption = 1 W` and
`target_temperature = 550`. The plasmas declare no `heat_capacity`, so they take
`FluidPrototype.heat_capacity`'s documented default of `"1kJ"` — "Joule needed to heat 1 Unit by
1 °C" — and 15 °C to 550 °C is 535 kJ per unit. At 1 W that is **one unit per 535 000 s ≈ 148.6 h**.
Quality takes `energy_consumption` to 2.5 W, so a legendary reactor's engine-side conversion runs at
one unit per 214 000 s ≈ 59.4 h — **1 MJ per 59.4 h, or 4.7 W**, against 50 MW of heating, which
would be one part in ten million. That is the derivation this note shipped with; the measurement
below does not agree with it.

**That arithmetic is now measured, and not one of its five rows survives.**
`scripts/probe-quality-leak.ps1` is the rig, added under
[#147](https://github.com/trulsjo/realistic-fusion-refreshed/issues/147): ten copies of `rf-reactor`
under a rig-only name, so `entity-management.lua` never registers them and nothing but the engine
touches their plasma — five cold at `min_temperature_c` and five hot at the shipped D-D equilibrium,
one pair per quality level, run for a thousand game seconds and again for ten thousand.

| Quality | `energy_consumption` | rate law says | **measured** | what the law asks per tick |
|---|---|---|---|---|
| normal | 1 W | 1.87 W | **0** | 0.523 ULP |
| uncommon | 1.3 W | 2.43 W | **0** | 0.679 ULP |
| rare | 1.6 W | 2.99 W | **0** | 0.836 ULP |
| epic | 1.9 W | 3.55 W | **0** | 0.993 ULP |
| legendary | 2.5 W | 4.67 W | **3.576 W** | 1.307 ULP |

**The engine moves fluid in whole float32 ULPs per tick** — 2⁻²⁴ units, 5.96×10⁻⁸ — and the rate law
asks for less than one of those at every level below legendary, so the transfer floors to nothing.
At legendary it asks for 1.307 and gets exactly one: the measured rate is 5.9604644775×10⁻⁸ units a
tick to ten digits, which is the ULP itself and not a number the rate law produces. Epic misses by
0.7%.

So a **normal `rf-reactor` has no residual leak at all**, and the one level that does leaks 24% less
than the arithmetic. This also retires the derived 1.9 W of unaccounted output the comment on
`target_temperature` in `prototypes/entities.lua` quoted: at the shipped normal quality it is zero.

**#101 is re-confirmed at every level.** All five hot cells read exactly zero over both run lengths,
so a *fusing* reactor leaks nothing at any quality — which was measured at normal only before.

**The reading is not the limit; the transfer is.** The rig measures the smallest change a fluid box
will report back rather than assuming one, and it is about 1.1×10⁻¹³ units at a thousand — a double's
precision, not a float's — so every zero above is ten orders clear of the noise and none of it is a
rounding artefact. The resolution worry #147 was written around is answered; the quantisation that
replaced it is a different mechanism.

Two things the rig turned up that are not about quality and are worth knowing. A fluid box seeded to
its own declared `volume` of 1000 **relaxes to 526.3158 over about two seconds** and holds that
figure to the digit, at every quality and in both temperature regimes — so `get_capacity()` and what
a box will actually hold are not the same number. *(#531 found why:
[`exchanger-coverage.md`](exchanger-coverage.md#the-rule-behind-the-split).)* And the input and output readings of the same
conversion **disagree by a factor of 1.887** in the one cell where there is anything to compare —
close to the 1.900 the seeded box relaxes by, and not equal to it. *(#541 found that it is the
same trade, seen from the input box alone: [The 1.887 is the box's share, and a fitted rule reproduces it](#the-1887-is-the-boxs-share-and-a-fitted-rule-reproduces-it).)*

And it is a *fuel* leak rather than an energy exploit: the boiler consumes a unit of plasma —
10²⁰ nuclei — to make 1 MJ, where fusing the same 10²⁰ D-D nuclei releases about 58 MJ. At the one
level where it runs at all, 3.576 W against 50 MW of heating is one part in fourteen million.

#### The 1.887 is the box's share, and a fitted rule reproduces it

([#541](https://github.com/trulsjo/realistic-fusion-refreshed/issues/541).) The rig now reads
each box's segment beside the box. `pwsh -File scripts/probe-quality-leak.ps1` and again with
`-Seconds 10000`, Factorio 2.0.77, 2026-10-04. Only the legendary cold cell moves; the other
nine read box and segment unchanged to ten digits.

| legendary, cold | 1000 s | 10 000 s |
|---|---|---|
| input box, baseline → end | 526.3157905 → 526.313895 | 526.3157905 → 526.2969435 |
| its segment, of 1000 | 473.6841917 → 473.6825109 | 473.6841917 → 473.6672759 |
| input box and segment, taken | 0.003576278687 | 0.03576278687 |
| output box, made | 0.003576278687 | 0.03576278687 |
| output's segment | 0 throughout | 0 throughout |
| made / taken off the box alone | 1.886792453 | 1.897533207 |

**Box plus segment on the input side is what the output gains, to ten digits, at both
lengths.** The output's segment holds nothing, so the output box shows everything made. The
input box shows only its share, and the segment gave the rest. So the 1.887 is the box/segment
split seen from the input box. It is the same split as the 526.3158.

**Where it lands is not a constant, and #531's rule does not give 1.887.** Counted in float32 ULPs
at 1.0, 2⁻²⁴ units, the conversion moved 60 000 of them in 1000 s and the box gave 31 800,
an exact 53%. That is why the factor reads 100/53. Over 10 000 s it moved 600 000 and the box
gave 316 200. The factor climbs toward the 1.900 that the rule's low branch gives a lone 1000-unit
box: segment = 0.9 × box, so the box gives 1/1.9 of anything drained. The rule run as arithmetic
for this note, draining 2⁻²⁴ a tick from the box, computed 2026-10-04:

| variant | the box gives in 1000 s, of 60 000 ULPs | factor |
|---|---|---|
| the game | 31 800 | 1.887 |
| the rule from the seed, 1000 units at tick 0, draining from tick 0 | 31 579 | 1.900 |
| the rule from the game's baseline, in doubles | 31 755 | 1.889 |
| the same, each transfer rounded or floored or ceiled to 2⁻²⁴, nine combinations | 31 752 – 31 762 | 1.889 – 1.890 |
| the same, each transfer rounded to float32 | 32 032 | 1.873 |
| a fixed-point variant, fitted to the game's ticks (below), from the seed | 31 800 | 1.887 |

From the game's baseline over 10 000 s the double-precision rule reads 1.899, against the
game's 1.898. None of the four rule rows above the fitted one reproduces the 31 800: the nearest gives 38 ULPs
less, 2.3×10⁻⁶ units. A box nothing drains settles at 526.3158023 in the game, in every cell
but the legendary cold one, where the rule settles at 1×10⁶ / 1900 = 526.3157895, so
1.28×10⁻⁵ apart.

**The game leaves #531's rule on the first tick**
([#553](https://github.com/trulsjo/realistic-fusion-refreshed/issues/553)). The rig now reads
the normal and the legendary cold cell every tick: the input box, its segment and the output
box, to seventeen digits. It runs the rule beside them from the seed, taking only the output
box's gain each tick from the game. `pwsh -File scripts/probe-quality-leak.ps1 -TraceTicks
60420`, again without the trace, and with `-Seconds 10000 -TraceTicks 0`; Factorio 2.0.77,
2026-10-04, no heater, no pipe, 60 300 ticks or 600 300. The rig sets no research, and its
subjects are unregistered, so no ladder reaches them. In both cells the game's box reads
909.99999642372131 at tick 1, where the rule gives 910: 3.58×10⁻⁶ units apart, sixty units of 2⁻²⁴. In the normal cell the gap
grows to 1.29×10⁻⁵ by tick 167, the lone box's offset above, and stays there. In the legendary
cell the largest is 2.81×10⁻⁵, at tick 59 301.

**A variant that gives 31 800, fitted to those ticks.** Every amount the trace read, box,
segment and output box in both cells on all 60 420 ticks, is a whole number of 2⁻²⁴ units.
What the box and the segment trade in a tick, with the draw added back, is a whole multiple of
100 such units on every tick. This variant reproduces them:

1. the boiler's draw comes off the box first;
2. a fill is the box's or the segment's amount in 2⁻²⁴ units over its volume, floored to a
   whole number;
3. the box pushes 100 × min(box fill, 2²⁴ − segment fill) units, then pulls 100 ×
   min(segment fill, 2²⁴ − box fill) on the fills the push left.

Run from the seed, it misses none of the 60 300 ticks in either cell. It gives the 31 800 of
60 000 and the lone box's 526.3158023 to every digit printed. With `-Seconds 10000`, a run it
was not fitted to, it misses none of 600 300 ticks in either cell and gives 316 200 of
600 000, the game's figure. The legendary rows there put #531's rule 2.81×10⁻⁵ off the game
at most, at tick 598 901. That is not the 1000 s run's maximum at a later tick: read again on
2026-10-05, the 1000 s run's largest is 2.811376862×10⁻⁵ at tick 59 301 and the 10 000 s run's
is 2.811699733×10⁻⁵ at 598 901. The two agree to three figures and differ in the fifth; the
longer run finds a slightly larger gap late.

It is **fitted, not found**. It is what missed no tick out of 27 combinations tried on
this trace in scratch arithmetic: the source fill floored, ceiled or rounded, the
destination's the same, and the draw before, between or after the two transfers. The trace
cannot say how the destination's fill is rounded: all three choices miss nothing, so three of
the 27 fit and the variant above is one of them. The
game's code was not read, and no 2.0.77 doc page found says fluid amounts are fixed point.
The fit itself is on a lone 1000-unit box at normal and legendary quality, with no pipe and
no heater.

**Outside the cells it was fitted to, it still misses no tick, and a fed line settles the
rounding** ([#564](https://github.com/trulsjo/realistic-fusion-refreshed/issues/564)).
`scripts/probe-plasma-segment.ps1 -Fixed` runs the variant beside a fuel line, one tick at a
time: from the game's reading of one tick, the box after the mod's step, the segment and what
the heater has to give, it predicts the next tick's box, segment and heater in whole 2⁻²⁴
units, and counts a miss when any of the three differs at all. That is a weaker test than
running from the seed, and it is the one a line the mod burns from allows. The order is
`M.settle_segment`'s: the box pushes and pulls, then the heater's output box pushes twice. The
0.1-unit floor is taken as 0.1 × 2²⁴ floored, 1 677 721 units. 2026-10-05, Factorio 2.0.77
(build 84539), normal quality, one heater a cell, nothing researched (all 11 rungs asserted
off):

| line | ticks | destination fill floored | ceiled | rounded |
|---|---|---|---|---|
| D-D, 1000-unit box, three pipes, `-Pipes 3,6 -Heater -Fixed -From 12000 -Span 1` | 96 000: 27 113 with the heater feeding, 68 887 without | 0 missed | 4392 missed, first on tick 32 524 | 17 562 missed, first on 32 524 |
| the same run, six pipes | 96 000: 18 101 and 77 899 | 0 missed | 4896 missed, first on 36 723 | 19 705 missed, first on 36 723 |
| D-He3, 3000-unit box, three pipes, `-Plasma rf-d-he3-plasma -Pipes 3 -Fixed -Ticks 200000 -From 12000 -Span 1` | 198 000: 6596 and 191 404 | 0 missed | 0 missed | 0 missed |

- **With every fill floored, the variant predicts every tick of all three lines exactly.** The
  two D-D lines fill inside the run, at 71 295 and 80 539, so the ticks include the heater's
  output box backing up against a full segment, where the 0.1-unit floor acts. No reading on any
  line was off the 2⁻²⁴ grid.
- **The fed D-D line separates the three combinations the lone box could not.** Ceiling or
  rounding the destination's fill misses from tick 32 524 at three pipes and 36 723 at six, by at
  most 1.79×10⁻⁵ units, which is 300 units of 2⁻²⁴. Only flooring fits. The D-He3 line does not
  separate them: its box holds 467 to 470 of 3000 and all three miss nothing there.
- It is still **fitted, not found**. No source for the game's fluid arithmetic was found, so
  what is shown is that one rule, fitted on a lone box, predicts 390 000 further ticks of three
  fed lines without a miss, and not that the game computes it that way. D-T, He3-He3, any
  researched state, more than one reactor on a segment, and quality above normal on a fed line
  were not run.

**The 1.28×10⁻⁵ excess and the factor's gap have one cause on this reading.** The same
variant, with nothing changed between the two cells, gives the normal cell's 526.3158023 and
the legendary cell's 31 800. Without step 2's floor it is #531's rule in doubles, which gives
526.3157895 and 31 579 from the seed.

## The equilibrium, measured

Its own section because it is the deduction the whole note used to rest on, and because it is the rig
the three that followed were built from. Five reactors running.

**The rig is checked in as `scripts/probe-quality-equilibrium.ps1`**
([#145](https://github.com/trulsjo/realistic-fusion-refreshed/issues/145)). Five `rf-reactor`s, one
per quality level, each on **its own electric network**, each holding **1000 units of D-D plasma**
topped back to that same fill every second with the temperature preserved, all five **cold-started at
15 °C** and left to find their own equilibrium. Temperature and Q are read **off the signal wire** —
a constant combinator ten tiles away, wired to the reactor's own signals combinator — so what is
measured is the path a player reads, not a Lua internal.

    pwsh -File scripts/probe-quality-equilibrium.ps1                          # 1200 s, tests' own SETTLE_S
    pwsh -File scripts/probe-quality-equilibrium.ps1 -Seconds 2400            # and again at twice the length
    pwsh -File scripts/probe-quality-equilibrium.ps1 -Seconds 60 -SampleSeconds 15   # the short run quoted below

Measured 2026-08-31 against Factorio 2.0.77. The table quotes the 2400 s run; the `energy_consumption`
row is rounded, and comes back off the engine as 1.299999952 / 1.600000024 / 1.899999976 for the
reason in [The floating point does not come back clean](#the-floating-point-does-not-come-back-clean):

The `input_flow_limit` row is the one #425 moved: the prototype declares 90 MW now. **That row alone
was re-read off the running game on 2026-09-20 against Factorio 2.0.77 (#429)** — by
`probe-quality-brownout.ps1`, which places the same five entities and asks
`get_input_flow_limit(quality)` of each — and it is the *re-read* row below. Every other row is the
2026-08-31 equilibrium run and is untouched: nothing in the physics moved, and re-running that rig to
confirm five identical temperatures again is not what this ticket asked for.

The re-read row is also where the multiplier shows the same float residue as `energy_consumption`
does: the engine answers 116.9999957 / 144.0000021 / 170.9999979 MW, rounded here for the same reason
the `energy_consumption` row is rounded.

| | normal | uncommon | rare | epic | legendary |
|---|---|---|---|---|---|
| level | 0 | 1 | 2 | 3 | 5 |
| `input_flow_limit`, 2026-08-31 | 60 MW | 78 MW | 96 MW | 114 MW | **150 MW** |
| `input_flow_limit`, **re-read 2026-09-20** | **90 MW** | **117 MW** | **144 MW** | **171 MW** | **225 MW** |
| `energy_consumption` | 1 W | 1.3 W | 1.6 W | 1.9 W | **2.5 W** |
| fluid box capacity | 1000 | 1000 | 1000 | 1000 | 1000 |
| electric buffer capacity | 10.67 MJ | 10.67 MJ | 10.67 MJ | 10.67 MJ | 10.67 MJ |
| electric network id | 1 | 2 | 3 | 4 | 5 |
| buffer held at reading | 5.667 MJ | 5.667 MJ | 5.667 MJ | 5.667 MJ | 5.667 MJ |
| plasma held at reading | 999.4515529 u | 999.4515529 u | 999.4515529 u | 999.4515529 u | 999.4515529 u |
| **settled temperature** | **242382 kC** | **242382 kC** | **242382 kC** | **242382 kC** | **242382 kC** |
| **settled Q** | **32%** | **32%** | **32%** | **32%** | **32%** |

**The spread across the five is zero — not "within tolerance", identical to the digit the wire
carries.** So is the Q. The two rows that *do* differ are the point of the table: `input_flow_limit`
and `energy_consumption` really are 2.5× at legendary, so the five entities genuinely were at five
different quality levels, and five equal temperatures are a result rather than a rig that forgot to
set the quality. Five distinct network ids are the other control: no cell could draw at another's
expense, which is exactly what a 2.5× flow limit against an unchanged 50 MW spend would otherwise
allow.

**Two of the rows are there to stop the result being a tautology.** *Plasma held at reading* is taken
**before** the second's top-up, not after — read after it, every cell reports the fill it was just
given and the row is true whatever the reactors did. Read before it, it is what the cell had left
after a second of burning: equal to ten digits, so the five really were at one density. *Buffer held
at reading* is non-zero and equal, which is what says all five cells were **powered** — five unlit
reactors would also print a spread of zero, and nothing but the absolute temperature would separate
that from the real answer.

**The number matches the model.** `tests/test-reactor-logic.lua` pins the shipped D-D reactor at
2.422e8 °C outside Factorio; the wire reads 2.42382e8 °C in it.

**It really had settled**, and the probe reports the evidence rather than asserting it. It prints the
whole approach curve, and at 2400 s the last twelve samples are the same number — flat from tick
104 400 to tick 144 000, which is 39 600 ticks or eleven game minutes. The two run lengths agree to
**0.051%**: 242258 kC at 1200 s, 242382 kC at 2400 s. A shorter run would not have done; at
3600 ticks the same rig reads 195129 kC, which is a point on the way up and looks exactly like an
equilibrium if it is quoted as one.

**Only `rf-reactor`, only D-D, only at full fill, only with nothing researched.** The aneutronic tier,
the D-T tier and the confinement ladder are each another lane and none of them is what #145 asked.

## What is not verified

Stated plainly, because this repository treats an unverified claim as a defect.

- **Contention is measured for small cells, not for a factory.** #439 ran pairs and #487 added four
  reactors on one network and a reactor against a `tertiary` load; #491 put all three input
  classes on one network, on a `secondary-output` supply only; #492 discharged accumulators into
  one short network, and #538 again with one of two reactors capped, at one supply fraction
  each; #493 put the aneutronic
  reactor beside one D-D reactor, both at normal quality; #494 and #538 ran the whole rig at
  every heating rung, and at no state with another ladder held. A network mixing researched and
  unresearched
  reactors needs two forces and has not been built. The class-ordered prediction is a
  prediction, and it is wrong in one measured way. A `tertiary`-class member draws nothing from
  a `tertiary`-class supply, where it is predicted up to 50.92 MW unresearched (#490, #528 and
  #538, with vanilla accumulators on either side and on both). Why the engine does that is read
  off one sentence of the docs and is not documented further. A reactor whose buffer is not
  full draws past its spend, and since #534 the prediction says by how much, to within 1.3e-6
  MW in the four cells that showed it. Since #544 what a charged accumulator gives is
  predicted too, and it misses only where a `tertiary`-class member is the sink.
- **Why the engine floors a fluid transfer to whole float32 ULPs per tick is inferred, not
  documented.** #147 measured the flooring — five levels, two run lengths, the legendary rate landing
  on 2⁻²⁴ units a tick to ten digits — and no 2.0.77 doc page found in this pass says the engine does
  that. The measurement stands on its own; the mechanism named for it is a reading of the numbers.
- **Both oddities #147 turned up are the box/segment trade. A variant of it fitted to the game's
  ticks matches both exactly, and that variant is a fit, not the game's documented rule.** A
  fluid box seeded to its declared `volume` settling at 526.3158 of 1000 is where that trade
  balances with no pipes (#531, see
  [`exchanger-coverage.md`](exchanger-coverage.md#the-rule-behind-the-split)). The 1.887
  between the input and output readings is the input box's share of what it and its segment
  gave, and box plus segment equals what was made, to ten digits (#541,
  [The 1.887 is the box's share, and a fitted rule reproduces it](#the-1887-is-the-boxs-share-and-a-fitted-rule-reproduces-it)).
  #531's rule in doubles leaves the game at tick 1, by 3.58×10⁻⁶ units. #553 fitted a variant
  to the trace: amounts in whole 2⁻²⁴ units, each fill floored, the boiler's draw taken first.
  It misses none of 60 300 ticks in the lone box or the draining one. It gives the lone box's
  526.3158023 and the 1000 s figure of 31 800 of 60 000, which is 1.887. What is not shown is
  that the game computes it that way. The variant was picked from 27 against the trace it
  matches; the 10 000 s run, which it also matches on every tick, was the one check outside it
  until #564. Since then it also predicts, one tick at a time, every one of 390 000 ticks of
  three fed fuel lines, two on a 1000-unit box and one on a 3000-unit one, and the D-D lines
  settle the rounding of the destination's fill: floored. It is still fitted, not found, and
  not run on D-T, He3-He3, a researched state or two reactors on a segment. Factorio 2.0.77,
  2026-10-04 and 2026-10-05.
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
`input_flow_limit` (already scaling, 90 → 225 MW as re-read on 2026-09-20, pure brownout
resilience). Declare *those* the
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
- **For:** the mechanism is **measured** since #148 and it does what the paragraph above says: the
  module is refused outright rather than accepted and ignored, and a machine on a flagged recipe
  makes normal output while an identical one beside it makes legendary.
- **Against:** it would still want its own check — an assertion that no quality-module route produces
  an `rf-reactor` — since the guarantee is a load-time property nothing currently holds. #148 says
  what shape that check has to take: the flag has **no runtime face**, so the assertion is against
  `data.raw` at load time, and it must not be written on an unresearched force, where quality does
  nothing whatever the recipes say.
- **Against:** it **destroys modules already in a machine.** Switching a machine that holds four
  quality modules onto a flagged recipe loses them with no refund and nothing on the ground. Applying
  this to `rf-reactor`'s recipe would not reach existing machines, but applying it to Core's
  assemblers later would.
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

Measured for this note. The four running rigs are described in their own sections; this is the
standing-still one:

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

- The semantics of `allow_quality`, which the 2.0.77 docs do not describe. **Measured here since
  #148** — see [the section](#denying-the-quality-version-outright) — but the measurement is this
  repository's own and no doc page confirms it.
- Why the engine floors a fluid transfer to whole float32 ULPs per tick. Measured under #147 and
  documented nowhere this pass reached.
- The meaning of `"quality_required"` in a mod's `info.json`.
- Whether a mod may define a sixth quality level.

The wiki was used only to reach the FFF and is cited for nothing.

# What `target_temperature` actually does to a boiler's own conversion

Measured 2026-08-21 by `scripts/probe-target-temperature.ps1` against Factorio **2.0.77**, base game
only, no bundled mods. Reproduce with:

```powershell
.\scripts\probe-target-temperature.ps1
```

Opened for [#101](https://github.com/trulsjo/realistic-fusion-refreshed/issues/101), which exists
because [#46](https://github.com/trulsjo/realistic-fusion-refreshed/issues/46)'s third item — whether
`rf-reactor`'s `target_temperature` of 165 °C is the right number — could not be settled by reading.
**Nothing here decides it.** The value is Truls's; this note measures what changing it would cost, and
the trade-offs are laid out at the end.

## The answer in one line

**The conversion runs only while the input fluid is *colder* than the target. At or above it, the
boiler moves nothing at all — not slowly, exactly zero.** While it does run, the rate is exactly the
documented formula.

```
rate (units/s) = energy_consumption / (heat_capacity × (target_temperature − input_temperature))
```

...and `0` when `input_temperature >= target_temperature`.

## Why the docs and this repository both looked wrong, and neither was

The 2.0.77 [`BoilerPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/BoilerPrototype.html)
docs say `target_temperature` is *"the temperature that the input fluid must reach to be moved to the
output fluid box"*, and that in `output-to-separate-pipe` mode *"fluid is transferred from the
`fluid_box` to the `output_fluid_box` when enough energy is available to heat the input fluid to the
`target_temperature`"*. That makes the rate a function of the rise to the target.

`prototypes/entities.lua` recorded the opposite — that a reactor seeded at 100 °C, below the target, and
one at 1e6 °C, far above it, behave identically.

**Both observations are correct and they are about different regimes.** The formula governs the cold
side; the hot side is flat zero. In play, plasma is six to eight orders of magnitude above any
plausible target, so a reactor lives entirely in the flat-zero regime — which is why the repository's
measurement saw the target make no difference, and why it wrongly generalised that to *"whatever the
temperatures are"*.

**The isolation is what made this answerable.** The earlier measurement was taken on a real
`rf-reactor`, where `control.lua` consumes plasma every step, so it could not separate what the engine
moves from what the simulation burns. This probe defines its own boilers — copies of `rf-reactor` under
rig-only names that `entity-management.lua` never registers, so `control.lua`'s `SPECS` never sees them
and nothing but the engine touches their plasma. Their energy source is `void`, so power availability
cannot be a second explanation for a low rate.

## The measurements

`heat_capacity` is **1000 J per unit per °C** for both `rf-d-d-plasma` and `rf-reactor-energy` — neither
declares one, and the
[`FluidPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/FluidPrototype.html) default is
`"1kJ"`, *"Joule needed to heat 1 Unit by 1 °C"*. Every prediction below uses that.

### The hot side: nothing moves, at any target, at any draw

Plasma held at **2.42×10⁸ °C** — the shipped D-D equilibrium — against every target and draw:

| target | 1 W | 1 MW | 50 MW |
|---|---:|---:|---:|
| 15 | 0 | 0 | 0 |
| **165 (shipped)** | **0** | **0** | **0** |
| 500 | 0 | 0 | 0 |
| 5 000 | 0 | 0 | 0 |
| 1 000 000 | 0 | 0 | 0 |

Fifteen combinations, ten seconds each, zero units in every one. A separate ladder at the shipped
target confirms where the edge is: at target 165, an input of **100 °C converts and 200 °C does not**.

### The cold side: the formula, to two parts in a thousand

Plasma written at 14 °C, which the engine **clamped to 15** — the fluid's `default_temperature` is also
its minimum, so the effective input is 15 °C and every ΔT below is measured from there. That clamp is
also why the `target = 15` row converts nothing: ΔT is zero, not small.

| target | ΔT | J per unit | 1 MW predicted | 1 MW measured | 50 MW predicted | 50 MW measured |
|---|---:|---:|---:|---:|---:|---:|
| 15 | 0 | — | — | **0** | — | **0** |
| **165** | 150 | 150 k | 6.667 | **6.656** | 333.3 | **332.8** |
| 500 | 485 | 485 k | 2.062 | **2.058** | 103.1 | **102.9** |
| 5 000 | 4 985 | 4.985 M | 0.2006 | **0.2003** | 10.03 | **10.01** |

Worst fit in the table is 0.2%. The independent point from the input ladder agrees: target 165 against
an input of 100 °C is ΔT 65, so 65 kJ per unit, and 50 MW predicts 769.2 units/s against **767.9
measured**.

### Raising the target past the output fluid's `max_temperature` is *not* refused

`rf-reactor-energy` declares `max_temperature = 165`. The `target = 500` and `target = 5000` variants
converted anyway, and the output fluid came out stamped at **500** and **5000** respectively. The
engine neither clamped it to 165 nor rejected the transfer.

That is the opposite of what `control.lua`'s `check_energy_outlets()` guard — added under #46 — assumes.
See *What this does to the guard* below.

## What this means for the shipped mod

### The engine's conversion is not merely neutered, it is switched off

The 1 W was chosen to make the boiler's own conversion negligible, and it does that. But the real
protection turns out to be the plasma's temperature, not the 1 W: a reactor at any fusing temperature
is in the flat-zero regime and would convert nothing **even at 50 MW**. The comment in
`prototypes/entities.lua` claiming `energy_consumption` is what neuters the conversion is therefore
true but not the load-bearing reason.

**Where it is *not* switched off is the floor.** `reactor-logic.lua` clamps plasma to
`min_temperature_c = 15`, and a sub-fusion plasma reaches that floor in under a second — so an idle
reactor holding plasma sits at exactly 15 °C, which is below the 165 target. There the formula applies
and gives **one unit per 41.7 hours** at 1 W (150 kJ per unit against one joule per second). That
corrects the repository's *"on the order of one unit per fifty hours"* to a measured figure, and it is
the right order.

### A small free-energy path, from the asymmetry between the two writes

This one is **derived, not directly observed** — it is below what the probe can resolve against a
50 MW reactor — but it follows from the measured law plus two lines of `control.lua`:

- `box[1] = { name = plasma.name, amount = remaining, ... }` is an **absolute set**, so any plasma the
  engine converted on its own is discarded and replaced by the simulation's figure.
- `box[2]`'s amount is `result.energy_units + (produced and produced.amount or 0)` — it **accumulates**,
  so any reactor energy the engine produced on its own is kept.

So while a reactor sits at its 15 °C floor, the engine adds reactor energy that no plasma was deducted
for. At 1 W that is 1 MJ per 41.7 hours, or about **6.7 W** of unaccounted output — against a reactor
whose heating draws 50 MW, a factor of 1.3×10⁻⁷. It is not perpetual motion in any practical sense and
nothing in the balance turns on it. It is written down because it is exactly the kind of thing that
stops being negligible if `energy_consumption` is ever raised, and because
[ADR 0018](../adr/0018-energy-is-contained-and-no-pipe-carries-it.md)'s reasoning depends on energy
having exactly one route out of a reactor.

### What this does to the `check_energy_outlets()` guard

#46 added a load-time guard refusing to run when a reactor's `target_temperature` exceeds its energy
fluid's `max_temperature`, on the reasoning that the write would be rejected and the reactor's whole
output lost silently.

**The engine's own conversion tolerates it** — measured above, output stamped at 500 against a declared
maximum of 165. So the guard's stated premise is not what the engine does.

The guard is still defensible, for a reason the probe did **not** test: `apply()` reaches box 2 through
a *Lua* write, `fluidbox[2] = { ..., temperature = target }`, which is a different code path from the
boiler's internal transfer. Whether a Lua write above `max_temperature` clamps, throws, or is silently
dropped is **not measured here**. The guard fails the mod at load rather than risking it, which is the
conservative direction. Its comment should be corrected to say that it guards the Lua write and that
the engine's own path is more permissive — not that the engine refuses.

## The three candidate values, with what each costs

**Not a recommendation between them beyond what the measurements support. The choice is Truls's.**

| | pipe reads | engine conversion at the floor | needs `max_temperature` raised | coherent with the steam route |
|---|---|---|---|---|
| **15** | 15 °C | **exactly zero, always** | no | no |
| **165** (shipped) | 165 °C | 6.7 W | no | no |
| **500** | 500 °C | 2.1 W | **yes, to ≥ 500** | yes |

Three things the numbers say that the ticket could not:

- **`target = 15` is the only value that switches the conversion off completely**, because the plasma's
  floor and the target coincide, so ΔT can never be positive. It is strictly the safest — and it puts
  the pipe back to reading room temperature, which is the complaint #46's second item was filed about.
  The two goals are in direct opposition, and the amount at stake on the safety side is 6.7 W.
- **500 leaks *less* than 165, not more.** A bigger ΔT costs more joules per unit, so the rate falls.
  Higher targets widen the band of input temperatures in which conversion can happen, but plasma is
  either at its floor or fusing, so the band is not where the cost is.
- **Nothing about balance is at stake at any of the three.** At the shipped 1 W the largest effect in
  the table is 6.7 W. This is a display decision, which is what #46 suspected and could not confirm.

### The recommendation asked for, which is not a decision

**If asked: 500 for `rf-reactor`, and treat `rf-aneutronic-reactor` as a separate question.**

The case for 500 on the neutronic side is that it wins on both axes at once rather than trading them
off — it is the only value coherent with the 500 °C steam the tier's own exchangers raise, *and* it
leaks a third of what the shipped 165 does. There is no measurement here that argues against it. Its
cost is entirely the coupling below.

The case for leaving the aneutronic reactor alone is that no measurement here touches it. Its route has
no thermal stage at all, so the question there is not "which temperature" but "should this fluid read as
hot at all", and that is a claim about what the tier is rather than about what the engine does.

**`target = 15` is the option to take if the 6.7 W is ever judged to matter more than the display**,
because it is the only value that closes the converting regime completely. Nothing measured here says
6.7 W matters.

The cost of **500** is not the conversion, it is the coupling: `rf-reactor-energy` and
`rf-aneutronic-reactor-energy` would both need `max_temperature` raised to at least 500, and #46's
guard means the mod refuses to load until they are — so the pair moves together or not at all.

And the aneutronic asymmetry [#101](https://github.com/trulsjo/realistic-fusion-refreshed/issues/101)
raised stands untouched by any of this: `rf-direct-energy-converter` has no thermal stage, so a hot
number on `rf-aneutronic-reactor-energy` is a claim about heat that tier does not make. Nothing
measured here argues for giving both reactors the same target.

## What is not verified

- **The Lua write path above `max_temperature` was not tested.** Only the boiler's internal transfer
  was. That is the gap named under *What this does to the guard*, and it is the one measurement that
  would let #46's guard state its reason accurately rather than conservatively.
- **The 6.7 W free-energy path is derived, not observed.** It follows from the measured conversion law
  and the two `control.lua` writes quoted above, and it is far below what a probe can resolve against a
  50 MW reactor. If it ever matters it should be measured with the simulation stubbed out.
- **Rates below roughly 0.05 units/s did not register in a ten-second window.** `target = 1000000`
  reported zero at 50 MW where the formula predicts 0.05 units/s, and the `target = 165` 1 W cell
  reported 3.57×10⁻⁵ units against a predicted 6.6×10⁻⁵. Read the sub-0.05 rows as *below the probe's
  resolution*, not as zero — the flat-zero result on the hot side is a separate finding and is not
  resolution-limited, since 50 MW there would have moved hundreds of units a second if anything moved
  at all.
- **One plasma, one reaction.** Everything was measured with `rf-d-d-plasma`. The other three plasmas
  declare the same `default_temperature`, `max_temperature` and (absent) `heat_capacity`, so the law
  should carry, but it was not run.
- **Nothing here was measured through a pipe.** The probe writes the input box directly, so fluid
  transport, mixing and segment sharing are all out of scope.
- **No decision was taken and no prototype number was changed** by this work. The only file this ticket
  edits besides the probe and this note is the stale claim in `prototypes/entities.lua`.

## Sources

- **`BoilerPrototype`**, Factorio Lua API 2.0.77 —
  <https://lua-api.factorio.com/2.0.77/prototypes/BoilerPrototype.html>. `target_temperature`'s
  definition and mandatory status under `output-to-separate-pipe`; the transfer condition.
- **`FluidPrototype`**, Factorio Lua API 2.0.77 —
  <https://lua-api.factorio.com/2.0.77/prototypes/FluidPrototype.html>. `heat_capacity`'s default of
  `"1kJ"` and its definition; `default_temperature` as *"also the minimum temperature of the fluid"*,
  which is what clamped the 14 °C fill to 15.
- **`LuaEntityPrototype`**, Factorio Lua API 2.0.77 —
  <https://lua-api.factorio.com/2.0.77/classes/LuaEntityPrototype.html>. `target_temperature` at
  runtime, *"Defaults to 15 if not set"*.
- **`scripts/probe-target-temperature.ps1`** in this repository — every number above.
- **The repository's own code**: `prototypes/entities.lua` at `rf-reactor`, `prototypes/fluids.lua` at
  both energy fluids, `control.lua`'s `apply()` and `check_energy_outlets()`, and
  `scripts/reactor-logic.lua`'s `min_temperature_c`.

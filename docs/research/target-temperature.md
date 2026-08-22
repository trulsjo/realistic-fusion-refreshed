# What `target_temperature` actually does to a boiler's own conversion

Measured 2026-08-21 by `scripts/probe-target-temperature.ps1` against Factorio **2.0.77**, base game
only, no bundled mods. Reproduce with:

```powershell
.\scripts\probe-target-temperature.ps1
```

Opened for [#101](https://github.com/trulsjo/realistic-fusion-refreshed/issues/101), which exists
because [#46](https://github.com/trulsjo/realistic-fusion-refreshed/issues/46)'s third item — whether
`rf-reactor`'s `target_temperature` of 165 °C was the right number — could not be settled by reading.

> **SETTLED, 2026-08-22.** `rf-reactor` goes to **550 °C**, `rf-aneutronic-reactor` stays at **165**,
> and `min_temperature_c` is **left at 15**. The measurements are unchanged; the last two sections
> record the decision and what it turned on, including a larger finding this work uncovered and did
> not fix ([#103](https://github.com/trulsjo/realistic-fusion-refreshed/issues/103)).

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
| 165 (was shipped) | 0 | 0 | 0 |
| 500 | 0 | 0 | 0 |
| **550 (shipped)** | **0** | **0** | **0** |
| 5 000 | 0 | 0 | 0 |
| 1 000 000 | 0 | 0 | 0 |

Eighteen combinations, ten seconds each, zero units in every one. A separate ladder at the shipped
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
| **550 (shipped)** | **535** | **535 k** | **1.869** | **1.866** | **93.46** | **93.30** |
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

These are the options as they were weighed. The one taken is in the next section.

| | pipe reads | engine conversion at the floor | needs `max_temperature` raised | coherent with the steam route |
|---|---|---|---|---|
| 15 | 15 °C | **exactly zero, always** | no | no |
| 165 (was shipped) | 165 °C | 6.7 W | no | no |
| 500 | 500 °C | 2.1 W | yes, to ≥ 500 | marginal — equals its own steam |
| **550 — chosen** | **550 °C** | **1.9 W** | **yes, to ≥ 550** | **yes, with an approach margin** |

Three things the numbers say that the ticket could not:

- **`target = 15` is the only value that switches the conversion off completely**, because the plasma's
  floor and the target coincide, so ΔT can never be positive. It is strictly the safest — and it puts
  the pipe back to reading room temperature, which is the complaint #46's second item was filed about.
  The two goals are in direct opposition, and the amount at stake on the safety side is 6.7 W.
- **500 leaks *less* than 165, not more.** A bigger ΔT costs more joules per unit, so the rate falls.
  Higher targets widen the band of input temperatures in which conversion can happen, but plasma is
  either at its floor or fusing, so the band is not where the cost is.
- **Nothing about balance is at stake at any of them.** At the shipped 1 W the largest effect in the
  table is 6.7 W. This is a display decision, which is what #46 suspected and could not confirm — with
  the sharp caveat that the *floor* is not a display decision at all, and is where the real energy is.
  See #103.

### The decision, and the thing that nearly went wrong

**`rf-reactor` → 550 °C. `rf-aneutronic-reactor` → stays 165. The floor stays 15.** Truls,
2026-08-22.

**550 rather than 500**, which is where the recommendation started. Reactor energy is the primary
coolant in all but name, and a coolant cannot raise steam to its own temperature — both exchangers
make 500 °C steam, so 500 was exactly marginal and 165 was backwards. 550 leaves the approach margin a
real plant has. It also takes the leak from 6.7 W to **1.9 W** for free, since the rate goes as
`1/(target − floor)` — and that is **measured, not inferred**: the probe sweeps 550 directly and
returns 1.866 units/s per megawatt of draw against a predicted 1.869, which at the shipped 1 W is
1.87 W of unaccounted output.

**The aneutronic reactor stays at 165, and the asymmetry is the decision.** That route has no thermal
stage — a direct energy converter decelerates charged particles against collector plates — and the
fluid's own description already tells the player "Not heat". 550 would assert a thermal character
[ADR 0018](../adr/0018-energy-is-contained-and-no-pipe-carries-it.md) separates the two routes
precisely to avoid claiming. Cold was rejected too: 15 °C is the reading #46 was opened about. A player
comparing a 550 °C line against a 165 °C one learns the routes differ, which is more than either
number says alone.

**And the floor was nearly raised, which would have been much worse.** Since conversion is exactly
zero at or above the target, a floor above the target closes the leak *completely*. The boundary
picked for it was **3 eV** — a value chosen inside the range `scripts/reactor-logic.lua`'s own
bremsstrahlung comment names, which says the formula is out of its domain "below a few eV — tens of
thousands of degrees", where hydrogen is only partly ionised. Note that is the *code comment* above
the term, not [`bremsstrahlung.md`](bremsstrahlung.md): that note bounds the model from **above**
(`t < 1`, below 5.93×10⁹ K) and says nothing about a low-temperature floor. Then the cost of holding
a floor was computed:

| floor | conjured to hold it against radiation |
|---|---|
| **15 °C (shipped)** | **27 kW** |
| 165 °C | 33 kW |
| 550 °C | 45 kW |
| 5 000 °C | 114 kW |
| 34 540 °C (3 eV) | **292 kW** |

The clamp puts a cooling plasma back up to `min_temperature_c`, so the floor is held by energy that
comes from nowhere, and bremsstrahlung goes as `n²√T`. **Trading 6.7 W of unaccounted output for
another 266 kW of conjured heat is the wrong direction**, however invisible the conjured half is. So
the floor was left alone and the leak was shrunk by the target instead.

Those figures are derived rather than measured, because measuring the others would mean actually
moving the floor. Two things vouch for them: the same formula and constants predict **351 kW at
5×10⁴ °C** against the "around 350 kW" the bremsstrahlung known-limitation records, and the shipped
row has since been measured directly at **26.6 kW** against the 27 predicted — see below.

### The larger finding: #103, now measured

> **Measured 2026-08-22, then SETTLED the same day.** The figures below were derived when this note
> was written, then measured, and are now **history**: every one of them is zero as shipped.
> [ADR 0021](../adr/0021-the-floor-is-where-the-model-stops.md) settles `min_temperature_c` as the
> edge of the model's domain and caps the drain so a plasma lands on the floor rather than under it,
> which makes conjured energy zero by construction. Kept in full because the measurement is what made
> the decision, and because the sizes are the argument against ever raising the floor.

**A full cold D-D reactor conjures 26.6 kW to hold 15 °C** — close to the 27 kW derived here, and
four thousand times the leak #46 was about. It predates all of this work. It is unsold, because
`left_j` is `inputs − retained_j` floored at zero, so when the clamp lifts the temperature
`retained_j` rises and nothing reaches the player. That invisibility is why it has survived.

**The worst case is not the one the ticket was filed on, and it is not the same effect:**

| reactor, full box | conjured | what sets it |
|---|---:|---|
| `rf-reactor`, D-D, 1000 u | **26.6 kW** | bremsstrahlung plus `E/τ` |
| `rf-aneutronic-reactor`, D-He3, 3000 u | **269 kW** | the whole plasma, every step |
| `rf-aneutronic-reactor`, He3-He3, 3000 u | **322 kW** | the whole plasma, every step |

**On the D-D reactor it is not purely radiation.** The clamp restores whatever took the plasma under
the floor, which is bremsstrahlung *plus* the confinement loss `E/τ`. Brems goes as `n²` and the loss
as `n`, so the density scaling is nearly quadratic and measurably not exactly so — halving the fill
divides the power by 3.994 rather than 4, and a fifth of that fill by 24.71 rather than 25. The two
terms account for all of it: at full fill the plasma holds 1194 J, so `E/τ` is 39.8 W, and
26 610 + 40 = 26 650 against 26 649 measured.

**On the aneutronic tier the joint clamp is saturated, which is a different regime.** Unscaled
bremsstrahlung there is far more than the plasma has to give — 1.92 MW against a full box whose entire
thermal content is worth 322 kW at this step rate, six times over — so `loss_j` and `brems_j` are
scaled down together until they sum to exactly `kept_j`, `new_thermal_j` lands on zero, and the clamp
conjures the whole thermal content back. The figure is a **cap**, `kept_j/dt`, not a radiated power:

- **It scales as `n`, not `n²`.** Halving the fill halves it exactly, where the D-D figure very nearly
  quarters.
- **It bites at any fill worth having.** He3-He3 saturates above **504 units of 3000** (17% full),
  D-He3 above **897** (30%). The D-D reactor never saturates — even a full box drains 37% of what it
  holds.
- **Below saturation the aneutronic tier behaves like the D-D one**: 300 u against 150 u is a ratio of
  3.998, the same nearly-quadratic scaling.

So the 12× between the two full-box figures is not `n²` times an electron count. It is one reactor's
radiated power set against another reactor's entire heat capacity, which are not comparable
quantities — and the derivation this note originally carried, which knew only the radiated term,
could not have told them apart.

**What it does not do**, all pinned by the tests: none of it is sold, on either tier. It is not
laundered into by-products either — a D-D plasma at the floor does breed a trickle of 4659 neutrons a
step, but that comes from residual fusion of 3.3×10⁻⁷ W, which would be there whether or not the floor
existed. The aneutronic tier breeds none at all.

**How long does a reactor sit there?** Indefinitely. It is a state rather than a transient: a
sub-fusion plasma reaches the floor in under a second, and stays until heating returns. A reactor
built before its power, or one caught in a blackout, is in it the whole time. So the effect is
continuous rather than occasional — and still invisible, because nothing is sold.

**What each repair would cost.** Not a recommendation between them —
[#103](https://github.com/trulsjo/realistic-fusion-refreshed/issues/103) reserves the choice, and each
option asks what a plasma below the floor actually *is*, which this simulation has no answer to
today.

| | conjured after | what it costs |
|---|---:|---|
| ~~as shipped~~ | 26.6 kW / 322 kW | nothing; the state of play |
| ~~gate radiation on ionisation~~ | ~40 W / ~90 W | a threshold constant the bremsstrahlung *code comment* explicitly declined to invent — and not zero, since the confinement loss still runs |
| ~~destroy plasma instead of restoring heat~~ | 0 | an idle reactor slowly loses its plasma — a gameplay change, not just a fix |
| ~~accept and record it~~ | 26.6 kW / 322 kW | the known-limitation note must name it, per this ticket |
| **cap the drain at the floor** ← **chosen** | **0** | nothing: no constant, no gameplay change, and it also fixes the crossing step |

**The option that was taken is not on the list this note originally carried.** It arrived from asking
what the floor *is* rather than what to do about the radiation: if `min_temperature_c` is where the
model stops having anything to say, then a plasma there is inert, and the fix is to stop the drain at
the floor rather than to cancel one of its terms. Zero by construction, and no threshold invented —
the floor already is the threshold. See
[ADR 0021](../adr/0021-the-floor-is-where-the-model-stops.md).

Gating the radiation is the high-leverage one: what it leaves behind is the confinement loss alone,
**39.8 W** on a full D-D reactor and **89.5 W** on a full He3-He3 one — reductions of 99.85% and
99.97%. Stated as what would remain rather than as a share of the present figure, because on the
aneutronic tier the clamp scales both terms and their present shares are not what removing one would
leave. But it is also the option the bremsstrahlung comment above `C_B` in
[`reactor-logic.lua`](../../realistic-fusion-refreshed/scripts/reactor-logic.lua) already considered
and turned down, on the grounds that it would mean "inventing a constant to fix a state nothing
reads" — and what has changed since is only that the state is now known to be worth 322 kW at its
worst rather than nothing.

It is the same class as the 34 W loop `reactor-logic.lua`'s comment on `left_j` records closing — that
one closed the *selling*, not the *conjuring*.

The cost of moving the target at all is not the conversion, it is the coupling: a fluid must be able
to hold what is stamped on it, and #46's `check_energy_outlets()` guard refuses to load until it can.
So a reactor's target and its energy fluid's `max_temperature` move together or not at all. **In the
event only one pair moved** — `rf-reactor` and `rf-reactor-energy`, both to 550 —
because `rf-aneutronic-reactor` stayed at 165 and its fluid therefore stayed at 165 too.

That is the aneutronic asymmetry [#101](https://github.com/trulsjo/realistic-fusion-refreshed/issues/101)
raised, and it was decided the way the measurement pointed: `rf-direct-energy-converter` has no
thermal stage, so a hot number on `rf-aneutronic-reactor-energy` is a claim about heat that tier does
not make. Nothing measured here argued for giving both reactors the same target, and they did not get
one.

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
- **A decision WAS taken, after this note was first written.** As filed, #101 changed no prototype
  number and edited only the probe, this note and one stale claim in `prototypes/entities.lua`. #46's
  third item was then settled on the strength of it — see the callout at the head — which moved
  `rf-reactor.target_temperature` to 550 and `rf-reactor-energy.max_temperature` with it, and left
  comments across `control.lua`, `entities.lua`, `fluids.lua` and `reactor-logic.lua`. The
  measurements in this note are untouched by that; only the decision sections are new.

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

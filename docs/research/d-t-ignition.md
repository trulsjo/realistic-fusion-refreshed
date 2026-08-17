# D-T ignites, and what that costs

Measured 2026-08-17 while implementing
[#28](https://github.com/trulsjo/realistic-fusion-refreshed/issues/28). Everything here comes from
`scripts/reactor-logic.lua` driven at the shipped `M.reactor` constants, and from
`scripts/check-d-t.ps1` running the same reactors in Factorio 2.0.77.

The short version: **D-D settles and D-T does not.** That is the difference between the two tiers,
and it is a property of the cross-section data and the reactor's confinement, not a balance number
anyone chose.

## What the data says

Maxwellian-averaged reactivity ⟨σv⟩ in m³/s, from `cross-section-data/reactivities.lua`:

| Plasma temperature | D-D | D-T | ratio |
|---|---|---|---|
| 1×10⁷ K | 8.39×10⁻²⁹ | 2.70×10⁻²⁷ | 32× |
| 5×10⁷ K | 1.15×10⁻²⁵ | 7.87×10⁻²⁴ | 69× |
| 1×10⁸ K | 8.25×10⁻²⁵ | 7.65×10⁻²³ | **93×** |
| 3×10⁸ K | 7.98×10⁻²⁴ | 5.87×10⁻²² | 74× |
| 6×10⁸ K | 2.27×10⁻²³ | 8.73×10⁻²² | 39× |
| 1×10⁹ K | 4.26×10⁻²³ | 8.72×10⁻²² | 20× |
| 2×10⁹ K | 8.64×10⁻²³ | 6.82×10⁻²² | 7.9× |
| 5×10⁹ K | 1.76×10⁻²² | 3.99×10⁻²² | 2.3× |

D-T's advantage is largest *low down* and narrows as both curves approach their peaks. That is why
D-T is the **easier** reaction rather than merely the bigger one: it is what a reactor can still run
on where D-D has fallen off the bottom of its curve. Multiply through by 17.59 MeV against D-D's
mean 3.65 and the energy advantage is another 4.8×.

Two corrections apply before those numbers become a rate, and both are per-fuel rather than per-
reaction:

- **D-D is like-species.** Every nucleus in the box is both reactants, and each pair would otherwise
  be counted twice, so `reactivity.rate` carries a factor of one half. That was already there.
- **D-T is a mixture.** A fluid unit is a count of nuclei, and in an even blend each side sits at
  *half* the plasma's density — so the rate is a quarter of what feeding the whole density twice
  would give. This is what `M.fuels[...].fractions` is, added by #28. Getting it wrong quadruples
  the tier's output and nothing else in the model notices, which is why
  `tests/test-reactor-logic.lua` recomputes one rate straight from the dataset rather than asserting
  a ratio.

## The equilibrium that isn't

Run with the box kept full and unlimited power:

| | settles at | Q | thermal out | burn |
|---|---|---|---|---|
| D-D, 20 min | 8.77×10⁸ °C | 2.14 | 133 MW | 3.7 u/s |
| D-T, 1 min | 2×10⁹ °C — **the clamp** | 96 | 4 127 MW | 34 u/s |

D-D balances: heating plus alpha self-heating against the confinement loss, partway up the curve.
D-T does not. At n = 10²⁰ m⁻³ and τ_E = 30 s this reactor passes the Lawson criterion for D-T by
more than an order of magnitude, so the alpha heating alone outruns the loss term at every
temperature below the peak and the plasma climbs until something stops it.

Raising the ceiling to find out what: the model does have a real equilibrium, out past the peak
where the cross-section is falling.

| ceiling | settles at | Q | thermal out |
|---|---|---|---|
| 2×10⁹ °C (shipped) | 2×10⁹ (pinned) | 96 | 4 127 MW |
| 5×10⁹ °C | 4.63×10⁹ | 58.9 | 2 547 MW |
| 10¹⁰ °C | 4.63×10⁹ | 58.9 | 2 547 MW |
| 10¹¹ °C | 4.63×10⁹ | 58.9 | 2 547 MW |

**The shipped ceiling stays where it is.** One reason holds, and it is the second one below.

> **Corrected 2026-08-17.** This section originally gave two reasons "in order of weight", and led
> with the wrong one. Reason 1 as written — that the clamp is the less wrong physics because
> bremsstrahlung "would bite long before 4.6×10⁹" — was reasoning rather than arithmetic, and it does
> not survive being checked against the NRL Plasma Formulary. See
> [`bremsstrahlung.md`](bremsstrahlung.md), which does the arithmetic at this model's own operating
> point. What actually holds: bremsstrahlung moves the equilibrium to **3.26×10⁹ K**, not down near
> the clamp; the clamp sheds ~640 MW at 2×10⁹ where bremsstrahlung is 169 MW, so it cannot be
> standing in for it; and unreabsorbed cyclotron radiation at these temperatures is two to three
> orders larger, so bremsstrahlung is not even the dominant omission. The struck reason is left
> visible rather than deleted, because it is why the clamp was chosen and a reader will otherwise
> wonder.

1. ~~**The clamp is the less wrong physics, not the more wrong.** A real D-T plasma at this density
   radiates hard through bremsstrahlung — a loss going as n²√T that this zero-dimensional model does
   not carry at all — and it would bite long before 4.6×10⁹ K.~~ **Not supported; see above.** What
   remains true of it: energy is not invented at the clamp, because `step()` sells everything the
   plasma cannot hold. The clamp is a ceiling on the state variable, not on the accounting.
2. **It would cost the temperature circuit signal.** A signal is an int32 and Factorio throws rather
   than wraps; the ceiling stops at 2 147 483 647, so the shipped 2×10⁹ fits with 7% to spare and
   4.6×10⁹ does not (`scripts/circuit-output.lua`). **This is the whole of the case for the clamp.**

What it costs as it stands is that the temperature reading is **pinned at 2×10⁹ for every D-T
reactor**, whatever it is doing. That is a real loss of information and it is the one thing about
this tier worth revisiting.

~~Fixing it properly means a bremsstrahlung term~~ — **it does not.** A bremsstrahlung term lands the
D-T equilibrium at 3.26×10⁹ K, still 52% above the int32 ceiling, so it would not unpin the reading.
The levers that reach it are `confinement_time_s` (10 s puts D-T at 2.02×10⁹) or plasma purity
(`Z_eff ≈ 6`, with `Z_eff = 7` extinguishing the plasma entirely — a knife edge). Both re-tune D-D as
well, so both are balance decisions rather than fixes.

And the finding this section originally missed: **adding bremsstrahlung would break the tier that
works.** D-D falls from Q 2.14 to Q 0.32, 107 MW of fusion power to 16 MW, taking the fuel-chain
arithmetic below with it. That is the physics being right — a D-D plasma at 10²⁰ m⁻³ with 30 s of
confinement is genuinely nowhere near ignition, and the shipped tier only looks net positive because
the dominant radiative loss is absent from the model.

## Ignition is a control change, not a runaway

The pinned temperature is not a stuck reactor. At the ceiling the reactor burns **exactly what it is
fed** and the output follows the fuel line:

| feed | D-T out | D-T burn | | D-D out |
|---|---|---|---|---|
| 2.5 u/s (one heater) | 324 MW | 2.5 u/s | | 86 MW |
| 5 u/s | 606 MW | 5 u/s | | 103 MW |
| 10 u/s | 1 170 MW | 10 u/s | | |
| 20 u/s | 2 297 MW | 20 u/s | | |
| 40 u/s | 3 888 MW | 34 u/s — **fuel-saturated** | | |

So ignition removes temperature as a control input and hands the player a different throttle: the
fuel line. Below saturation the relationship is affine and very nearly proportional — doubling the
feed gives 1.87× the power, the shortfall being the 50 MW of confinement heating that is recovered
either way and does not double.

## Does the fuel chain support it?

Yes, and by a smaller margin than the raw power figures suggest — which is the point of a tier.

- A D-T reactor on one heater burns **2.5 u/s of plasma**, so 2.5 u/s of `rf-d-t-mix`, so
  **1.25 u/s of tritium**.
- A D-D reactor at its settling point burns 3.66 u/s of deuterium and breeds a quarter of that back
  as tritium: **0.92 u/s**.

**About 1.4 D-D reactors feed one D-T reactor.** Together that is 507 MW from 2.4 reactors, 214 MW
each, against 133 MW for a D-D reactor on its own — a 61% step for roughly a doubling of the
plumbing. Not a runaway, and not free.

Balance is provisional here as everywhere in this repository, and this section is the first thing
that should move if it is retuned.

## In the game

`scripts/check-d-t.ps1`, 7 200 ticks, two identical reactors fed the same plasma temperature with
their output boxes drained each tick so the comparison is of throughput rather than of two
saturated buffers:

```
the reactor accepts D-T plasma through the box that used to be filtered to D-D  -- rf-d-t-plasma
and ignites: the plasma runs up to the top of its range and parks there  -- 2e+09 C against a ceiling of 2e+09
the D-D reactor beside it is unchanged  -- rf-d-d-plasma at 7.675e+08 C
both reactors sold energy over the run  -- D-T 4.709e+05 MJ, D-D 1.269e+04 MJ
D-T yields materially more than D-D at the same feed temperature  -- 37.1x  (3924 MW against 105.8 MW)
a D-T reactor breeds nothing, so its collector stays empty  -- 0 units in the collector bolted to it
the plasma heater turns Core's D-T mix into D-T plasma  -- 200 units of rf-d-t-plasma, status full_output
```

The D-D figure is 106 MW rather than the 133 MW above because two minutes is not twenty: that
reactor is at 7.7×10⁸ °C and still climbing. The D-T reactor reached its ceiling inside the first
minute and the run is measuring its steady state.

Negative-tested, each separately, by breaking the thing under test and confirming the rig said so:

- Putting `filter = "rf-d-d-plasma"` back on the reactor's input box → four failures, starting with
  the reactor holding nothing at all. This is the change most likely to be reverted by accident and
  the one that fails most quietly in a player's game.
- Giving D-T a `products` table copied from D-D → the bolted-on collector filled to 500 units.
- Deleting the D-T row from `M.fuels` → the mod refuses to load, naming the fluid
  (`check_every_plasma_burns`, added by #28 because removing the box filter is what made a plasma
  with no fuel row reachable in the first place).

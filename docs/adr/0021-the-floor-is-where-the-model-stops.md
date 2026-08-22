# 21. The floor is where the model stops, and a cold-parked plasma is inert

Date: 2026-08-22

## Status

Accepted. Decided by Truls, 2026-08-22, settling
[#103](https://github.com/trulsjo/realistic-fusion-refreshed/issues/103).

**Narrows the known limitation recorded above `C_B`** in `scripts/reactor-logic.lua` — that
bremsstrahlung is applied at temperatures where the plasma is not fully ionised. This ADR does not
lift that limitation; it closes the bottom end of it, and by a route that comment had considered and
rejected the other version of. See [Consequences](#consequences).

Distinct from [#46](https://github.com/trulsjo/realistic-fusion-refreshed/issues/46), which raised
the same constant for a different reason and deliberately left it alone.

## Context

`min_temperature_c = 15` on both reactor specs, matching every plasma fluid's `default_temperature`.
In Factorio a fluid's `default_temperature` **is** its minimum — the engine cannot hold a fluid
colder — and `check_plasma_bounds()` in `control.lua` refuses to load if a spec's clamp disagrees
with its fluid's range. So a floor is forced in kind by representing plasma as a fluid. Only the
value is this repo's.

Until now the value asserted nothing. It was a bound, and the simulation had no answer to what a
plasma at it *was*. That gap had a price, discovered while settling #46's third item and measured
under #103:

**The clamp put a cooling plasma back up to the floor, and the energy that did it came from nowhere.**
`step()` computed a new temperature, clamped it up to `min_temperature_c`, and then reconstructed the
plasma's energy from the clamped temperature — handing back joules that had already radiated away.

| reactor, full box | conjured, before this ADR |
|---|---:|
| `rf-reactor`, D-D, 1000 u | 26.6 kW |
| `rf-aneutronic-reactor`, D-He3, 3000 u | 269 kW |
| `rf-aneutronic-reactor`, He3-He3, 3000 u | **322 kW** |

**The aneutronic figures are not the same effect as the D-D one, and that is what made the state
expensive rather than merely untidy.** On D-D the conjured amount was bremsstrahlung plus the
confinement loss, scaling as nearly `n²`. On the aneutronic tier the joint clamp was *saturated* at
any fill worth having — unscaled bremsstrahlung is 1.92 MW against a plasma whose entire thermal
content is worth 322 kW at this step rate — so both terms scaled down to sum to exactly what the
plasma held, and the clamp conjured the whole heat content back every step. That figure is a cap,
`kept_j/dt`, and scales as `n`. It is a heat capacity rather than a radiated power, which is why
deriving it from the radiation formula could not have found it.

**None of it ever reached the player.** `left_j` is `inputs − retained_j` floored at zero, so a
plasma held at the floor sells nothing. That invisibility is precisely why it survived unnoticed, and
it is the same class as the 34 W loop the comment on `left_j` records closing — that one closed the
*selling*, not the *conjuring*.

## Decision

**`min_temperature_c` is a model-domain boundary: 15 °C is where this simulation stops having
anything to say.** Below it hydrogen is only partly ionised, the bremsstrahlung term is out of its
domain by its own admission, line radiation would be the channel that actually dominated, and no term
in this model is valid. The engine requires a minimum; this is where we put the edge of the model
inside that constraint.

**A plasma at the floor is therefore *cold-parked*, and cold-parked is inert.** It neither radiates
nor leaks, because the model has nothing valid to say about it.

**Implemented by capping the drain rather than by cancelling a term.** `loss_j` and `brems_j` scale
down together to land the plasma exactly on the floor rather than under it, so the low temperature
clamp never bites and there is nothing to hand back. Conjured energy is zero *by construction*.

### Why the drain cap, and not the three repairs #103 listed

| considered | conjured after | why not |
|---|---:|---|
| **accept and record it** | 26.6 / 322 kW | Defensible while the floor asserted nothing. Once the floor is a domain boundary, the conjuring is a bookkeeping error rather than a physical claim, and accepting a bookkeeping error needs a reason this one does not have. |
| **gate radiation on ionisation** | ~40 / ~90 W | Not zero — the confinement loss still runs, and if the model says nothing below the floor it is hard to say why one of its terms still does. Needs a threshold constant, which the bremsstrahlung comment weighed and declined. Misses the crossing step, where a plasma above the floor still over-drains past it. |
| **destroy the plasma** | 0 | Physically the most honest — a recombined plasma is not plasma. But it is a gameplay change, not a bookkeeping fix: an idle reactor would lose its fuel, which interacts with blackout recovery and with [ADR 0016](0016-plasma-density-is-a-player-lever.md)'s density lever. Bigger than the defect. |
| **cap the drain** (chosen) | **0** | Zero by construction, no new constant, no gameplay change, and it handles the crossing step. |

**No threshold constant was invented, which is the trade the bremsstrahlung comment declined.** The
floor already is the constant.

## Consequences

**Nothing observable changes.** A plasma at the floor sat there before and sits there now. The fix
removes invented energy from the bookkeeping, not behaviour from the game. Verified: `load-check` and
all ten map rigs pass unchanged, `check-brownout`'s blackout recovery and `check-observability`'s idle
case included, and the D-D equilibrium stays at 2.42×10⁸ °C with Q 0.3205.

**The model now declines to describe something, deliberately.** A real plasma at 15 °C keeps
radiating; this one does not. That is a fiction of *omission* where the previous behaviour was a
fiction of *creation*, and omission is the one consistent with a declared domain boundary. It is
recorded rather than hidden: [`CONTEXT.md`](../../CONTEXT.md) names the state and says so.

**`min_temperature_c` is load-bearing in a second way now.** Raising it no longer only shifts the
boiler leak #46 was about — it moves where the model claims its physics stops, and silently widens the
band the simulation refuses to describe.

**The bremsstrahlung known limitation is narrowed, not lifted.** The term still runs out of its domain
between a few eV and the floor. What is closed is the bottom end, where the out-of-domain radiation
was funding itself from nothing.

**`conjured_power_w` stays in `step()`'s return as a regression guard**, asserting zero rather than
reporting a quantity. What it watches is a one-line property of the joint clamp, and this file has
lost a very similar property once already. `tests/test-reactor-logic.lua` asserts zero across both
reactors, all three fuels, full and partial fill, the crossing step and every state above the floor;
reverting the cap fails eight of them.

**#46 is unaffected.** It settled `target_temperature` at 550 and deliberately left the floor at 15;
that reasoning stands, and this ADR is why the floor stays there rather than being raised to close the
boiler leak — a 3 eV floor would have taken the conjuring to 292 kW on D-D alone.

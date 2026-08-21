# 16. Plasma density is a lever the player tunes

Date: 2026-08-19

## Status

Accepted. Settles item **3** of
[#37](https://github.com/trulsjo/realistic-fusion-refreshed/issues/37) — what under-supplying a
reactor should do.

**Depends on [ADR 0015](0015-the-d-d-tier-is-a-breeder.md).** The behaviour this ADR accepts exists
only once the bremsstrahlung term is carried, which it now is (#52, 2026-08-21) -- when this was
written the model was radiation-free and the behaviour was still in the future. Split from ADR 0015 because it has a different blast radius: that one governs the technology
tree, this one governs what tooltips and status text have to say.

Decided by Truls, 2026-08-19.

## Context

#37's item 3 recorded that a fluid box shares its contents with its segment in proportion to
capacity, and that reaction rate goes as the square of density — so *"a half-supplied reactor produces
about a quarter of the power rather than running intermittently at full power. That is arguably the
better behaviour, and it is worth saying out loud because it was discovered, not designed."*

**Measured rather than reasoned about, the quadratic claim is wrong even on today's model**, because
temperature is a state variable and it moves the other way: less plasma is less thermal mass for the
same 50 MW, so a thin plasma runs hotter and partly offsets the lost density. Radiation-free, 50%
fill gives 30.4% of full power against n²'s 25%, and 25% fill gives 12.8% against 6.2% — twice the
prediction.

**Under the radiation term the sign flips.** Fusion power and bremsstrahlung both go as n² while the
transport loss goes as nT, so thinning the plasma buys temperature at no radiative penalty relative
to fusion — and over the range D-D's reactivity is still climbing steeply, the reactivity gain beats
the density loss outright:

| fill | settles at | Q | vs full | n² predicts |
|---|---|---|---|---|
| 100% | 2.42×10⁸ K | 0.320 | 100% | 100% |
| 85% | 3.35×10⁸ K | 0.405 | 127% | 72% |
| **65%** | 5.12×10⁸ K | **0.450** | **140%** | 42% |
| 50% | 7.12×10⁸ K | 0.414 | 129% | 25% |
| 25% | 1.46×10⁹ K | 0.234 | 73% | 6% |

So the shipped full-density point sits at 21 keV, well below D-D's optimum, and a player gets **40%
more fusion power for 35% less fuel**. It is an interior maximum rather than an instruction to run the
reactor empty: below about 35% fill the n² term wins again and a starved reactor is worse off than a
full one.

**The optimum walks up the fill axis as confinement time rises, and leaves the range entirely.** At
τ 50 s it is near 85% fill; by τ 70 s full supply is simply best.

| τ | optimum fill | Q there | Q at full |
|---|---|---|---|
| 30 s (shipped) | ~65% | 0.450 | 0.320 |
| 50 s | ~85% | 1.085 | 0.950 |
| 70 s | ≥ 100% | — | 2.080 |

**D-T is untouched**, and the reason matters: it sits far *past* its optimum rather than below it, so
its temperature barely moves as the plasma thins and it de-rates almost exactly as n² — 45% of full at
65% fill against n²'s 42%. Its equilibrium is above `max_temperature_c` at every fill either way.

Every figure above is asserted in `tests/test-bremsstrahlung.lua`, which already owns the term's
maths; `lua tests/test-bremsstrahlung.lua` prints both tables. It is in that file rather than a second
one on purpose — two copies of one equation is precisely the drift #51 exists because of.

## Decision

**The density optimum is accepted as a deliberate mechanic.** Choosing an operating density is
gameplay. Nothing is retuned to remove it: not the fluid box volume, not `particles_per_unit`, not
`heating_power_w`.

**The lever is heater throughput against total segment fill, not anything per reactor.** A box holds
its share of its fluid segment in proportion to capacity ([#40](https://github.com/trulsjo/realistic-fusion-refreshed/issues/40)),
so every reactor on a run sits at the same fill and tunes together. A player throttles the heater and
holds the whole run near its optimum.

**This is engineering, not physics, and therefore ours to place.** ADR 0014 divides the two: reactions,
branching ratios and cross-sections are fixed; density, confinement, purity and capture efficiency are
ours. Accepting the optimum where the physics puts it is the more conservative of the two available
readings — moving the density to hide it would be the intervention.

**And it is self-limiting.** The reward is largest at the entry tier, where a player has least power,
and #53's ladder closes it. That is the property that makes it a mechanic rather than a permanent tax
on building properly.

## Consequences

- **[#25](https://github.com/trulsjo/realistic-fusion-refreshed/issues/25)'s status text is now wrong
  in a new way.** "Starved of plasma" will fire on a reactor running at its best. #25 is closed, so
  this is tracked as its own ticket under this ADR rather than left as a loose bug.
- **The mechanic is currently undiscoverable except through the circuit signals.** Nothing tells a
  player that density is a lever, and nothing shows them where the optimum is. That is a real gap and
  it belongs with the status-text work above, not to #46.
- **[ADR 0014](0014-realistic-means-theoretically-possible.md)'s confinement ladder is a *full-supply*
  table**, and is annotated as such. Break-even depends on supply: at τ 50 s a tuned reactor is above
  it (Q 1.085) and a full one is not (Q 0.950), so a player who tunes crosses a rung earlier than the
  record read.
- **#53 is not complicated by it.** At the top of the ladder full supply is optimal, so the guard
  against the clamp is still sited at full density and nothing under-supplied can exceed it.
- **`CONTEXT.md` gains the term**, so "under-supplied" stops being usable as a synonym for "starved".
- **Not playtested.** Whether a 40% reward for under-supplying reads as depth or as an exploit is a
  play question, and the honest answer today is that nobody has played it. This ADR accepts the shape;
  reversing it later is a density number and an ADR, not a rewrite.

## Alternatives considered

**Retune density so full supply is the optimum.** Shrink the reactor's plasma density until a full box
sits at the peak, making the de-rate monotonic and the behaviour item 3 assumed true. Base Q would
rise 0.32 → 0.45, still below break-even, and full would stay optimal at every rung. Rejected in
favour of keeping the mechanic. **If it is ever revisited, the lever must be the fluid box volume and
not `particles_per_unit`** — the latter also divides the reaction's products, so moving it would
rescale #27's and #30's tritium and helium-3 economy as a side effect.

**Move `heating_power_w` instead.** Also shifts the optimum toward full supply, and shrinks the entry
cost ADR 0015 accepted. Rejected: it moves base Q off the landing ADR 0015 fixed.

**Defer until #52 has landed.** Every figure here comes from the equilibrium solver rather than from
the shipped `step()`. Rejected because the solver reproduces the shipped radiation-free equilibrium to
four digits and is the same maths #51 pinned — and deferring would ship a tier with a 40% under-supply
reward nobody had decided on.

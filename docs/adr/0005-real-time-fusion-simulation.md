# 5. Reactors run a real-time fusion simulation

Date: 2026-08-13

## Status

Accepted. Resolves
[Recipe-driven reactors or a real-time simulation?](https://github.com/trulsjo/realistic-fusion-refreshed/issues/17).

## Context

Both shipped predecessors are recipe-driven. The 1.1 original and Durikkan's port make reactors crafting
machines; the original's `control.lua` is 160 lines whose only job is killing plasma-carrying vanilla
pipes. Physics is implied through recipe ratios.

The archived four-module redesign is the only predecessor that simulates. Its
`RealisticFusionPower/scripts/reactor-logic.lua` loads tabulated fusion **cross-section reactivity
datasets** and binary-searches them to interpolate reaction rate from plasma temperature — real ⟨σv⟩
data rather than a tuned constant. It runs on `on_tick`, per reactor network, with a GUI updating per
reactor.

Two measurements bear on the choice:

- **The runtime is mostly interface.** Of ~1,736 runtime lines in the redesign's Power module, **929 are
  GUI** (`gui.lua` 580, `gui-events.lua` 349). The simulation proper is ~311 lines of reactor logic plus
  390 of entity management.
- **Its own author was worried about the cost.** `reactor-logic.lua` carries the comment
  `--TODO premultiply reactivities to reduce runtime cost`, left in place. The module was never observed
  running, so no measurement of it exists.

Factorio's heat and fluid systems already simulate temperature and transfer in C++, so temperature-
dependent behaviour is available natively. What the engine cannot express is reactivity as a function of
that temperature — which is precisely the thing that distinguishes this mod from its predecessors.

## Decision

**v1's reactors run a real-time simulation**, computing reaction rate from cross-section data rather
than implying it through recipe ratios.

**Throttling the update cadence is pre-authorised.** If measurement shows the per-tick cost is too high,
moving to `on_nth_tick` — or any coarser cadence — is a sanctioned mitigation within this decision, not
a reversal of it and not grounds for a new ADR. The decision is *that reactors simulate*; how often the
simulation steps is a tuning parameter.

**The rate computation is therefore kept isolated from the tick cadence**, so changing cadence is a
configuration change rather than a rewrite. This follows directly from the point above: a fallback that
requires restructuring is not a fallback.

## Consequences

- **UPS has to be measured, not assumed.** This is the first obligation the decision creates. The
  redesign's author flagged the cost and never resolved it, and nobody has seen the code run — so
  "it is probably fine" is not available as a position. Factorio players are unforgiving about UPS.

  **Discharged 2026-08-18 ([#34](https://github.com/trulsjo/realistic-fusion-refreshed/issues/34)):
  about 3 to 4 µs per reactor per tick with all four reactions running — 3.4% to 4.9% of the 16.67 ms
  budget at 200 reactors, and well under 1% at the 20 to 50 a large ordinary build has.** It is a
  range and not a number because three repeats spanned 2.85 to 4.04 µs, which is this rig's known
  20–42% run-to-run spread rather than anything about the mod. Measured on Factorio
  2.0.77 with `scripts/bench-reactors.ps1 -Mixed`, the same script and counts as the early reading,
  and reproduced. **The verdict is acceptable and the cadence is unchanged**: `UPDATE_INTERVAL`
  stays at 6, the value #24 chose, and the throttling this ADR pre-authorises was not needed a
  second time. The rate computation was not touched, so that fallback remains a one-line change.

  Two things the measurement found that this ADR did not anticipate. **A D-D-only base is the
  expensive case, not the full set** — 6.3 to 6.9 µs per reactor against 2.9 to 4.0 — because D-D is the only
  reaction that breeds, and its by-products are computed every step whether or not a collector
  exists. And **the D-D figure has roughly doubled since it was last taken**, which is a real change
  rather than noise and is not attributed. See
  [`docs/research/reactor-runtime-cost.md`](../research/reactor-runtime-cost.md).

  What is **not** discharged: the measurement is a rig, not a factory. #34 asked for a real base at
  scale and there is no such save in this project. The per-reactor cost is the mod's own contribution
  and stands; how it behaves beside a loaded engine is unmeasured.
- **The premultiplication the redesign left undone is the obvious first optimisation** if measurement
  shows a problem — reactivities multiplied by reaction energies once at load rather than per lookup.
  Recorded here so it is not rediscovered from scratch.
- **Simulation state lives in `storage`**, which enlarges the save and migration surface. This bears on
  [Save migration or clean break?](https://github.com/trulsjo/realistic-fusion-refreshed/issues/7):
  recipe-driven reactors would have had almost no runtime state to migrate; simulated ones do.
- **Expect the interface to dominate the code.** In the only worked example, GUI outweighed simulation
  by roughly three to one. How much of the simulation v1 surfaces is not settled here and remains on the
  map as fog.
- Nothing is inherited — per
  [ADR 0004](0004-fresh-code-predecessors-as-reference.md) this is written fresh. The redesign's
  approach is reference, and `RFP-2.0/RFP-2.0.txt` (WTFPL, 16 academic sources) is the derivation to
  build from.

## Alternatives considered

**Recipe-driven, no runtime simulation.** Cheapest to build, zero Lua per tick, proven twice over.
Rejected: it is what both predecessors already do, and it gives up the one thing that makes this project
more than a port.

**Engine mechanics with a coarse Lua rate step.** Heat and fluid systems carrying temperature in C++,
with reaction rate computed on a throttled cadence. Not rejected on merit — it is essentially this
decision with throttling applied from the start, and it remains reachable at any time under the
pre-authorised fallback above. The choice was to begin from the full-fidelity version and measure,
rather than to pre-emptively coarsen something never measured.

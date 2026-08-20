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
  about 2.5 µs per reactor per tick with all four reactions running — around 3.1% of the 16.67 ms
  budget at 200 reactors, and well under 1% at the 20 to 50 a large ordinary build has.** The figure
  #34 first recorded was 3 to 4 µs; it was re-measured under
  [#39](https://github.com/trulsjo/realistic-fusion-refreshed/issues/39) on a machine checked to be
  quiet, the original runs having been taken beside an unrelated compile. The remaining spread is
  about 1.35× and is why no digit after the first is real. Measured on Factorio
  2.0.77 with `scripts/bench-reactors.ps1 -Mixed`, the same script and counts as the early reading,
  and reproduced. **The verdict is acceptable and the cadence is unchanged**: `UPDATE_INTERVAL`
  stays at 6, the value #24 chose, and the throttling this ADR pre-authorises was not needed a
  second time. The rate computation was not touched, so that fallback remains a one-line change.

  **The expectation this ADR did carry held: per-reactor cost did not grow as reactions were added.**
  Every reaction costs about the same, 2.4 to 3.2 µs, so there is no cheap tier and no expensive one.
  #34 first reported the opposite — that a D-D-only base cost 2.3× the full set, on the strength of
  D-D being the only reaction that breeds — and #39 withdrew it: the mechanism is real code that
  costs too little to measure, and the whole of the apparent effect was a busy machine. See
  [`docs/research/reactor-runtime-cost.md`](../research/reactor-runtime-cost.md).

  **Reproduced 2026-08-20** on the renamed mods, the only change to the tick path since: 2.23 µs per
  reactor at 200 reactors, a ratio of 1.1 against the figure above and so the same number. See
  *Reproduced 2026-08-20* in the research note.

  What is **not** discharged: the measurement is a rig, not a factory. #34 asked for a real base at
  scale and there is no such save in this project. The per-reactor cost is the mod's own contribution
  and stands; how it behaves beside a loaded engine is unmeasured. That residue is
  [#67](https://github.com/trulsjo/realistic-fusion-refreshed/issues/67)'s, behind #64 and #65 —
  #34 carries the rig measurement and nothing more.
- **The premultiplication the redesign left undone is the obvious first optimisation** if measurement
  shows a problem — reactivities multiplied by reaction energies once at load rather than per lookup.
  Recorded here so it is not rediscovered from scratch.

  **#39 measured what it would be aiming at, and the answer is "a real share, but not the largest".**
  Ablating the simulation step rung by rung puts the arithmetic at about a third of it and the Lua↔C++
  crossings at the rest, roughly two to one. That corrects the claim the research note has carried
  since #24 — that crossings outweighed the physics by one to two orders of magnitude — which, had
  it stood, would have made premultiplication pointless. It is not pointless; it is also not the biggest
  lever, and at 2.5 µs a reactor neither lever is worth pulling yet.
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

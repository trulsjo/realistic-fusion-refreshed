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
  budget at 200 reactors, and well under 1% at the 20 to 50 a large ordinary build has.**
  *The number to quote is now about 4.5 µs and 5.4%; this one was measured on reactors with no
  collector attached. See the #62 paragraph below before quoting anything from this bullet.* The figure
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

  **The figure moved to about 4.5 µs — 5.4% of a tick at 200 reactors — on 2026-09-03
  ([#62](https://github.com/trulsjo/realistic-fusion-refreshed/issues/62)), and the discharge still
  stands.** Every reading above was taken on reactors with **no isotope collector bolted to them**,
  which nothing said at the time. `control.lua` computes the by-products either way and only writes
  a collector's fluid boxes when one is attached, so `deposit()` had never executed under
  measurement and neither had `blanket_breed()` — every figure was the cost of a reactor that
  vents, in a configuration a player does not build. Re-measured with collectors, in one sitting on
  a machine quiet at every count: the full reaction set costs 4.48 µs against 3.04 vented, and a
  D-D-only base 4.84 against 3.68. **Nothing about the mod changed; what was measured did.** The
  1.8× move against the 2.5 µs above is well outside the noise floor, which is why this figure is
  restated rather than left as a footnote. **The verdict is unchanged**: `UPDATE_INTERVAL` stays at
  6, and at the ten to fifty reactors an ordinary build has the worst case is 0.3% to 1.6% of a
  tick.

  **No figure here moved on 2026-09-04, and #66 is why that counts as a result.** #66 was opened to
  cut what a D-D step costs and changed no code, so the 4.5 µs stands and so does the 5.44 µs worst
  case. Both were measured on the tree that still ships — nothing has touched either mod since
  `ca385ca` of 2026-09-03 00:40, and both sweeps were recorded after it. See *Nothing to cut* in
  the research note for what was looked at.

  **The expectation this ADR carried still holds, and the correction #39 made to #34 stands.** With
  collectors attached — the configuration that makes breeding cost anything at all — D-D is 4.84
  against the full set's 4.48, a ratio of 1.08. There is no cheap tier and no expensive one; what
  #62 changes is not which reaction is dearest but that every configuration costs about half again
  what was on record. **The worst of the five configurations measured is a blanketed D-D base at
  5.44 µs, 6.5% of a tick** — the build a D-T player has, since the blanket rides on the D-D tier's
  collector.

  Three things that measurement does **not** establish. It does not separate `deposit()` from the
  collector entity's own engine time, because a collector exists only where a reactor does and so
  does not cancel out of the delta the way the rig's power does. It brackets the premium rather than
  pinning it: the six vented-against-collected pairs all land on the same side and four of the six
  clear the 1.35× floor, but they span 1.28 to 1.68 — so the effect is real and no second digit of
  it is. And the blanket is a separate switch, off by default, costing at most the 1.12 between 5.44
  and 4.84 µs — inside the floor, though it more than doubles the tritium a D-D reactor yields. See
  *Collectors attached (#62)* in [`docs/research/reactor-runtime-cost.md`](../research/reactor-runtime-cost.md).

  What is **not** discharged: the measurement is a rig, not a factory. The per-reactor cost is the
  mod's own contribution and stands; how it behaves beside a loaded engine is still unmeasured, and
  that residue is [#67](https://github.com/trulsjo/realistic-fusion-refreshed/issues/67)'s — #34
  carries the rig measurement and nothing more.

  **Both things #67 was waiting on now exist, so the residue is the measurement itself and no longer
  the means of taking it.** This note used to say there was no such save in this project, which was
  true and is the narrower claim now. `bench-reactors.ps1 -Save` benchmarks a save the script did not
  build ([#64](https://github.com/trulsjo/realistic-fusion-refreshed/issues/64), 2026-09-03), and
  `-PlantInto` builds the rig on a surface of its own inside a **borrowed base** —
  [#65](https://github.com/trulsjo/realistic-fusion-refreshed/issues/65), 2026-09-03, TimEv's vanilla
  megabase, which spends about 10.7 ms a tick against a rig's 0.21 ms. **The slope survives that move,
  which is more than #65 was scoped to deliver**: planted reactors were never in the save, so the
  same save swept at count zero is a real baseline and #67 gets a subtraction on a loaded tick rather than an
  absolute figure. What it costs is a reproducibility concession recorded in
  [ADR 0029](0029-the-factory-measurement-rests-on-a-borrowed-base.md) — the input is a third-party
  save this project may use but not ship, so this one figure is re-takeable only by someone holding
  that file. Provenance and method:
  [`docs/research/borrowed-base.md`](../research/borrowed-base.md).
- ~~**The premultiplication the redesign left undone is the obvious first optimisation** if measurement
  shows a problem — reactivities multiplied by reaction energies once at load rather than per lookup.
  Recorded here so it is not rediscovered from scratch.~~

  **Discharged 2026-09-04 ([#66](https://github.com/trulsjo/realistic-fusion-refreshed/issues/66)):
  it is not an optimisation of this code, and there is nothing to rediscover.** It is an optimisation
  of the redesign's shape. That step simulates a network running seven reactions at once and builds
  two sums over all seven — one against charged reaction energies and one against total — so folding
  the energy into the dataset removes seven multiplies of fourteen. This mod simulates one reactor
  burning one plasma (ADR 0011), does one dataset lookup a step, and applies a reaction energy
  **once**, in `M.step()` (`reactor-logic.lua`). Premultiplying would make the lookup return joules where four
  things in the same function need a count — the fuel cap, the fuel burnt, the by-products and the
  neutrons — so it trades one multiply for one divide, which is not the cheaper of the two. It
  would also change what the public `reactivity.reactivity()` returns, which
  `tests/test-further-reactions.lua` weighs against literature ⟨σv⟩ tables for the reactions this
  mod does not ship. **Deferred, not done, is therefore the wrong description: there is nothing
  here to do.** See *Nothing to cut* in
  [`docs/research/reactor-runtime-cost.md`](../research/reactor-runtime-cost.md).

  **#39 measured what it would be aiming at, and the answer is "a real share, but not the largest".**
  Ablating the simulation step rung by rung puts the arithmetic at about a third of it and the Lua↔C++
  crossings at the rest, roughly two to one. That corrects the claim the research note has carried
  since #24 — that crossings outweighed the physics by one to two orders of magnitude — which, had
  it stood, would have made premultiplication pointless. ~~It is not pointless; it is also not the
  biggest lever, and at 2.5 µs a reactor neither lever is worth pulling yet. **At the 4.5 µs #62
  measured with collectors attached, that verdict is unchanged.**~~ The crossings are the biggest
  lever, and premultiplication is not one here at all. The ablation ladder does not reach the part
  #62 found had grown either, since its rungs never run the collector path.

  **#66 struck those two sentences, for a reason #39 could not have measured**: the arithmetic
  really is a third of the step, and premultiplication removes none of it here, so "neither lever
  yet" was never two levers, and there was no second lever for #62's figure to leave unchanged.
  What #39's finding does still license is the *other* one it named — batching or caching the
  fluidbox work, which aims at the larger share and is not worth pulling at 4.5 µs either. #66
  names the specific crossing (`fluidbox.get_capacity`, a prototype constant asked once a step on a
  producing vented reactor and four times on a collected D-D one) and declines to pull it, since it
  is inside the noise floor on its own and there is no cause to pay for it.
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

# 10. v1 module layout and prototype set

Date: 2026-08-14

## Status

Accepted. Resolves
[Specify the v1 module layout and prototype set](https://github.com/trulsjo/realistic-fusion-refreshed/issues/9)
— the closing decision of the map.

## Context

Everything this spec depends on is already settled: two mods named `RealisticFusion` and
`RealisticFusionCore` with prefix `rf-` ([ADR 0009](0009-mod-names-and-prototype-prefix.md)), fusion
power only ([ADR 0002](0002-v1-scope-and-module-split.md)), written fresh
([ADR 0004](0004-fresh-code-predecessors-as-reference.md)), reactors simulated
([ADR 0005](0005-real-time-fusion-simulation.md)), base 2.0.77
([ADR 0008](0008-factorio-version-floor-and-doc-pin.md)), coexistence only
([ADR 0007](0007-coexistence-without-integration.md)), clean break
([ADR 0006](0006-clean-break-from-predecessor-saves.md)).

Four things remained open and are decided here: which reactions v1 models, where tritium and helium-3
come from, where lithium comes from, and how much of the simulation the player sees.

## Decision

### Scope of the chain

**All four reactions**: D-D, D-T, D-He3, He3-He3. Because the simulation is data-driven
(ADR 0005), an additional reaction is largely a cross-section dataset row plus prototypes and recipes
rather than new mechanics, so the full progression through to the aneutronic tier is affordable.

**Both breeding routes.** Tritium and helium-3 arise as **D-D by-products** early — the reactors are
the breeder, as in the 1.1 original — with **lithium blanket breeding** as a later upgrade tier, which
is how real D-T reactors obtain tritium.

**Lithium comes from brine concentrated out of water**, not from a map resource. This is close to how
lithium is really produced, extends the chain's established water-derived pattern (electrolysis, heavy
water, Girdler sulfide), and — decisively — **requires no worldgen**, so the mod behaves identically on
an existing save and a fresh one. A new ore or fluid deposit would only generate in unexplored chunks,
stranding players who add the mod to a running game.

**The simulation surfaces through vanilla means**: entity status text and tooltips, plus plasma
temperature and Q-factor emitted as **circuit signals**. No custom GUI in v1.

### The module seam

This is the point where the port could not be cut: its technology tree crossed both ways and its
reactors were the breeder, making Core and Power a closed loop. Written fresh, the seam is defined
rather than discovered:

- **`RealisticFusionCore` owns every fluid and item prototype**, and the extraction chain that produces
  feedstock.
- **`RealisticFusion` owns the reactors, heat and generation**, and *references* Core's fluids.
- **Dependencies run one way only.** Power depends on Core; Core never references Power. Where a
  reactor produces a Core-owned fluid — D-D yielding tritium and helium-3 — the *prototype* is defined
  in Core and the *recipe* lives in Power. Definition and production are separable; that is what breaks
  the loop.

> **Corrected 2026-08-17 (#27).** There is no recipe, and there cannot be one. The reactor is
> simulated rather than recipe-driven (ADR 0005, ADR 0011), so it has no recipe for by-products to
> be results of — this line was written before the simulation existed in code and describes the 1.1
> original, whose reactors were crafting machines. What is separable is definition from
> **production**, not definition from *recipe*: `control.lua` computes tritium and helium-3 from the
> same reaction count the energy output comes from, and deposits them into `rf-isotope-collector`.
> The seam itself is unchanged and now exercised rather than asserted — a Core machine consuming,
> through an ordinary pipe, a fluid a Power reactor made (`scripts/check-breeding.ps1`).
>
> A second entity is needed because a boiler has exactly two fluid boxes and `rf-reactor` spends
> both: plasma on the input-output box this ADR's fluid coupling rests on, reactor energy on the
> other. `rf-isotope-collector` is therefore a Power entity this list does not name. Truls chose it
> over an extraction recipe on the plasma line — the 1.1 original's answer — because a recipe breeds
> at a fixed ratio while the reaction rate moves by orders of magnitude with temperature, which is
> the "physics implied through recipe ratios" this project exists to not be. Measured: a reactor at
> 7.7×10⁸ °C breeds 83.7 units of each per 7 200 ticks, and the same reactor at 1.8×10⁴ °C breeds
> none.
- **Technologies follow the same direction.** Core technologies unlock extraction and never depend on
  Power technologies.

### Layout on disk

Both mods use the same shape:

```
RealisticFusionCore/                RealisticFusion/
├── info.json                       ├── info.json
├── data.lua                        ├── data.lua
├── data-updates.lua                ├── data-updates.lua
├── settings.lua                    ├── control.lua
├── prototypes/                     ├── prototypes/
│   ├── fluids.lua                  │   ├── fluids.lua        (plasmas)
│   ├── items.lua                   │   ├── entities.lua
│   ├── entities.lua                │   ├── items.lua
│   ├── categories.lua              │   ├── recipes/
│   ├── recipes/                    │   └── technology/
│   └── technology/                 ├── scripts/
├── locale/en/                      │   ├── reactor-logic.lua
└── graphics/                       │   ├── entity-management.lua
                                    │   └── circuit-output.lua
                                    ├── cross-section-data/
                                    ├── locale/en/
                                    └── graphics/
```

`scripts/reactor-logic.lua` computes reaction rate from `cross-section-data/`. Per ADR 0005 it is
**isolated from the tick cadence** — `control.lua` owns the scheduling, so throttling to `on_nth_tick`
is a change in one place.

**Locale exists from the first commit.** Every module of the redesign lacked it, which is why even its
loadable modules would have shown raw names like `rf-m-reactor` in game.

### Prototype set

**Core — fluids**: `rf-hydrogen-sulfide`, `rf-heavy-water`, `rf-depleted-water`, `rf-deuterium`,
`rf-tritium`, `rf-helium-3`, `rf-hydrogen`, `rf-brine`, `rf-lithium-solution`, `rf-d-t-mix`,
`rf-d-he3-mix`.

**Core — items**: `rf-lithium`.

**Core — entities**: `rf-electrolyser`, `rf-deuterium-extractor`, `rf-gas-mixer`,
`rf-brine-concentrator`, `rf-lithium-extractor`.

**Core — technologies**: `rf-heavy-water`, `rf-deuterium-extraction`, `rf-lithium-extraction`.

**Power — fluids**: `rf-d-d-plasma`, `rf-d-t-plasma`, `rf-d-he3-plasma`, `rf-he3-he3-plasma`,
`rf-reactor-energy`, `rf-aneutronic-reactor-energy`.

**Power — entities**: `rf-heater`, `rf-reactor`, `rf-aneutronic-reactor`, `rf-lithium-blanket`,
`rf-heat-exchanger`, `rf-hc-exchanger`, `rf-hc-turbine`, `rf-direct-energy-converter`,
`rf-aneutronic-composite-tank`, `rf-isotope-collector`, and plasma-safe fluid handling: `rf-pipe`,
`rf-pipe-to-ground`, `rf-pump`.

> **Corrected 2026-08-17 (#26).** This list also named `rf-discharge-pump` as plasma-safe fluid
> handling, and it is not. The original's plasma set is its magnetic pipe, pipe-to-ground and pump;
> its `rf-discharge-pump` sits with the electrolyser and the thermal evaporation plant, and its
> recipes are *deuterium-depleted-water discharge and recycling*
> ([`predecessor-survey.md`](../research/predecessor-survey.md)). It is a **Core** water-chain
> machine, not a Power one, and it is nothing to do with plasma. Left unbuilt and moved to its own
> ticket rather than invented here.

**Power — technologies**: `rf-d-d-fusion`, `rf-tritium-breeding`, `rf-d-t-fusion`,
`rf-helium-3-breeding`, `rf-aneutronic-fusion`, `rf-blanket-breeding`, `rf-direct-energy-conversion`.

Vanilla pipes must not carry plasma.

> **Corrected 2026-08-17 (#26).** This said the original enforced that in `control.lua` and that v1
> does the same. **v1 does not, and should not.** 2.0 gives every pipe connection a
> `connection_category`, and two connections join only when theirs match — so the plasma set names a
> category of its own and a vanilla pipe beside a plasma line simply does not connect, the way it
> already refuses to join a heat pipe. The plasma never enters, rather than being noticed and
> cleaned up after it has. The original's 160 lines of `control.lua` were the best answer available
> in 1.1; against 2.0 they would be a per-tick cost, a race with whatever put the plasma there, and
> a pipe destroyed under whoever built it. There is no runtime enforcement in this mod at all.
> Measured by `scripts/check-containment.ps1`, including the negative case: with containment
> removed, an ordinary pipe laid against a plasma line fills with 100 units of plasma.

### The chain, end to end

1. Water → electrolysis and Girdler sulfide → **heavy water** → **deuterium** (`rf-depleted-water` as
   the spent stream, `rf-hydrogen-sulfide` recirculating as catalyst).
2. Water → **brine** → **lithium solution** → **lithium**.
3. Deuterium → heater → **D-D plasma** → reactor → power, plus **tritium** and **helium-3** as
   by-products.
4. Deuterium + tritium → **D-T mix** → **D-T plasma** → reactor → power. Lithium blanket on the reactor
   breeds additional tritium.
5. Deuterium + helium-3 → **D-He3 mix** → aneutronic reactor → power via direct energy conversion.
6. Helium-3 → **He3-He3 plasma** → aneutronic reactor — the end of the progression.

## Consequences

- **The map's destination is reached.** Nothing remains to decide before implementation begins.
- **No balance numbers appear here** — ratios, energy values and crafting times are out of scope on the
  map, to be established by playtesting against a build.
- **No graphics decision is implied.** Asset sourcing is out of scope; whatever ships must respect
  [ADR 0001](0001-liftable-predecessor-material.md).
- **Three obligations carry into implementation**, each recorded where it arose: UPS must be measured
  rather than assumed (ADR 0005); loading safely under Space Age must be verified (ADR 0003);
  coexistence, especially alongside Krastorio 2, must be tested (ADR 0007).
- **The prototype list is a starting specification, not a contract.** Names follow the `rf-` prefix and
  the one-way dependency rule; anything discovered during implementation should be recorded as a
  superseding ADR rather than drifting silently.

## Alternatives considered

**Fewer reactions** — D-D and D-T only, or D-D alone. Rejected: a data-driven simulation makes breadth
cheap, and stopping before the aneutronic tier stops before what the original built toward.

**One breeding route.** D-D by-products alone would have been self-contained and smallest; lithium
blankets alone would have been the most physically canonical. Both were chosen for the progression they
give together.

**Lithium as a map resource** — ore patch or brine deposit. Rejected on worldgen: resources generate
only in unexplored chunks, so either choice would behave differently for players adding the mod to an
existing save.

**A custom reactor GUI, or a network dashboard.** Rejected for v1: in the only worked example the GUI
outweighed the simulation roughly three to one. Circuit signals surface the same values through the
engine's own idiom at a fraction of the cost, and a GUI remains addable once the simulation is proven.

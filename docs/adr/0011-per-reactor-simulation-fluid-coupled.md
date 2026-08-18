# 11. Per-reactor simulation, fluid-coupled

Date: 2026-08-14

## Status

Accepted **for v1**. Resolves
[Does the simulation run per reactor or per network?](https://github.com/trulsjo/realistic-fusion-refreshed/issues/19).

Deliberately scoped: this decides how v1 simulates, not how the mod must simulate forever. See
[Consequences](#consequences) for what would justify revisiting it.

## Context

[ADR 0005](0005-real-time-fusion-simulation.md) decided *that* reactors simulate.
[ADR 0010](0010-v1-module-layout-and-prototype-set.md) specified the prototype set. Neither settled the
unit of simulation, and the v1 spec recorded per-reactor as a flagged inference rather than a decision.

**The redesign simulated per network.** Reactors and heaters joined by `rf-m-` confinement pipe formed
one object holding a single mixed plasma inventory — deuterium, tritium, helium-3 and helium-4 at one
temperature — with all seven reaction channels running against it simultaneously
(`RealisticFusionPower/scripts/reactor-logic.lua:169-181`). D-D bred tritium into the same plasma, which
immediately fed D-T in that same plasma. `plasma_volume` scaled with the number of reactors welded
together, so number density — and therefore reaction rate — was a property of the network, not of any
reactor. That coupling *was* the network.

Three things bear on the choice.

1. **ADR 0010 already replaced the substrate.** It specifies four separate plasma fluids —
   `rf-d-d-plasma`, `rf-d-t-plasma`, `rf-d-he3-plasma`, `rf-he3-he3-plasma` — and `CONTEXT.md` fixes the
   language: *"Each reaction has its own plasma."* One plasma per reaction is mutually exclusive with one
   mixed plasma running seven channels. The redesign's network, as built, was already off the table
   before this decision was taken.

2. **The engine supplies what the network supplied.** Checked against the installed 2.0.77 data
   (`data/base/prototypes/fluid.lua`): `steam` declares `default_temperature = 15`,
   `max_temperature = 5000`, `heat_capacity = "0.2kJ"`. Temperature is a **native fluid property**, and
   mixing across a connected fluidbox system averages it weighted by amount — in engine code, at no Lua
   cost. Generators already declare `maximum_temperature` and fluidboxes `minimum_temperature`. Because
   ADR 0010 carries plasma as a fluid through `rf-pipe`, two reactors on the same plasma line already
   share a pool at a common temperature without a line of connectivity code.

   > **"Averages it weighted by amount" was read off the prototype data and never observed. Measured
   > under #40, it is not what the engine does: mixing loses about a fifth of the temperature
   > difference it flattens.** The sharing this paragraph promises is real and was confirmed; the
   > fidelity it assumes is not. See Consequences.

3. **Removing the GUI removed the network's control surface.** `gui.lua` (672 lines) and
   `gui-events.lua` (370) drove sliders for plasma heating, magnetic field strength, divertor strength
   and per-heater overrides — all *per network*. The network was the object the player controlled. ADR
   0010 replaces the GUI with entity status text, tooltips, and circuit signals, all three of which are
   **entity-bound**. A network has no position, no tooltip and no circuit connection point, so per-network
   under ADR 0010 would force electing a reactor to speak for the network, having every reactor report an
   aggregate that misdescribes the building in front of the player, or adding a network controller entity
   the specified prototype set does not contain.

**What per-network cost the redesign in practice**, from `scripts/entity-management.lua` (440 lines):

- **Merging silently destroys plasma.** Entities are moved into the surviving network and the absorbed
  one is discarded wholesale (`global.networks[network_id] = nil`), taking its deuterium, tritium,
  helium-3 and temperature with it.
- **Splitting resets plasma to nothing.** The split path calls `new_network()`, whose defaults are
  `total_plasma = 0.5` and `plasma_temperature = 0`. There is no conserved-quantity redistribution
  anywhere in the file. Mining one pipe cools both halves.
- **The id allocator is corrupted.** `global.networks_len` serves as both a count and the next id, and
  the destroy path decrements it when an *entity* is removed and again when a network empties. Ids
  collide and new networks overwrite live ones.
- **Connectivity is a recursive graph walk**, carrying the author's own comment: *"it might cause a stack
  overflow for huge pipe networks (with >~16000 pipes according to the internet), but let's hope that
  won't be an issue?"* Destroy runs up to four full traversals per removal to detect a split.

None of that is inherited — v1 is written fresh ([ADR 0004](0004-fresh-code-predecessors-as-reference.md))
— but it is the evidence of what the model costs when actually built, and it was never observed running.

## Decision

**v1 simulates per reactor.** The unit of simulation is a single `rf-reactor` or `rf-aneutronic-reactor`
entity. It reads plasma amount and temperature from its input fluidbox, interpolates the reaction rate
from cross-section data for its one reaction, writes `rf-reactor-energy` or
`rf-aneutronic-reactor-energy` to its output fluidbox, and emits its own plasma temperature and Q-factor
as circuit signals. Per-reactor scratch state lives in `storage`, keyed by `unit_number`.

**Plasma sharing is delegated to the engine's fluid system, not modelled in Lua.** Reactors connected by
`rf-pipe` interact through the shared fluidbox — one pool, one mixed temperature, maintained by the game.
This is what distinguishes the decision from bare per-reactor simulation: the sharing behaviour that
motivated networks is kept, and the code that implemented it is not written.

> **"One mixed temperature" is the intent and not quite the behaviour** — see Consequences. Measured
> under #40: a run does share and an idle one does flatten, but the mixing loses heat, and a box the
> simulation writes every step sits a few percent above the rest of its run for as long as it is
> driven. The decision stands on the sharing; the phrase overstates the fidelity.

**No connectivity tracking exists.** No graph traversal, no network ids, no merge, no split, no orphan
cleanup. Entity lifecycle is an insert on build and a delete on mine.

**No cross-reactor physics in v1.** Effects that are genuinely properties of a shared volume —
aggregate wall loading, network-wide disruption, ash fraction across a whole plasma — are not modelled.
Where scale should matter, it comes from prototype tiers rather than from emergent volume scaling.

This does not disturb [ADR 0005](0005-real-time-fusion-simulation.md): the rate computation stays
isolated from the tick cadence, `control.lua` still owns scheduling, and throttling to `on_nth_tick`
remains pre-authorised.

## Consequences

- **The largest source of complexity in the reference implementation is not ported.** 440 lines of entity
  management, and every defect listed above, are avoided rather than fixed.
- **Cost scales with reactor count rather than machine count.** A player running one enormous
  installation pays per reactor where a network model would have charged once. ADR 0005's pre-authorised
  cadence throttling is the mitigation, and combined with one reaction per reactor — against the
  redesign's seven — the per-update cost is a fraction of the reference. **This is a prediction, and
  ADR 0005's outstanding obligation to measure UPS is unaffected by it.** No measurement is inherited
  from either model; the redesign's code was never observed running.
- **The delegation is not free, and what it costs was not known when this was decided.** Measured
  2026-08-18 under [#40](https://github.com/trulsjo/realistic-fusion-refreshed/issues/40) by
  `scripts/check-pooling.ps1`: **the engine's fluid mixing destroys heat.** Flattening a temperature
  difference across a segment loses about a fifth of that difference — measured on reactors built so
  that no simulation touches them at all, where the plasma amount does not move by a part in a
  hundred thousand, and confirmed against a one-reactor run where nothing else could be to blame:
  95% of what a lone reactor spends reaches its own box, 75% once twenty pipes are plumbed to it.

  **Sharing itself works, and that half of the decision holds.** An unpowered reactor five along a
  run reaches 57 times its seed temperature, and an idle run seeded fifty times apart flattens to
  within 0.0001%. What does not hold is the assumption that delegating the mixing was *equivalent*
  to doing it ourselves.

  **A second effect is this mod's rather than the engine's, and it is larger.** Three reactors
  bridged onto one run keep 58% of what they spend, against the 75% a single reactor keeps on a
  comparable run — so most of the shortfall on a real bank of reactors is not mixing. `update()`
  reads every reactor and then writes every reactor, each write replacing a box from the
  start-of-step pool, and the engine re-splits between those writes; a reactor writing second can
  overwrite the share of its neighbour's rise it has just been handed. Not isolated and not fixed
  under #40.

  **Nothing is decided here.** The options run from accepting it as a plumbing cost a player designs
  around, through fixing the two-pass update, to reopening this delegation — and the last of those is
  a new ADR, not an edit to this one. See
  [`docs/research/reactor-runtime-cost.md`](../research/reactor-runtime-cost.md) for the measurement
  and its controls.
- **Failure is local and visible.** A stuck reactor is one building a player can see and mine, not an
  invisible object spanning half a base.
- **Blueprints, undo, cut-and-paste and robot construction need no special handling.** These are exactly
  the paths that generate build-and-destroy storms and break network bookkeeping.
- **Multiplayer is safe by construction** — no shared mutable object being merged while two players build
  into it from opposite ends.
- **"Build a bigger tokamak" is not available as gameplay in v1.** The redesign's *n* reactors = *n*×
  plasma volume behaviour is the one thing genuinely lost, and per-reactor cannot fake it.
- **Revisiting is a later ADR, not a silent change.** The decision is scoped to v1. Two things would
  justify reopening it: measured UPS that per-reactor cannot carry even throttled, or a deliberate design
  turn toward scale-as-gameplay. Either would need a network controller entity and a conserved-quantity
  redistribution on merge and split — the part the redesign never wrote.

## Alternatives considered

**Per-network, explicit.** Reactors and heaters joined by confinement pipe simulated as one object with
shared plasma state in `storage`. Rejected for v1 on three grounds, in order of weight: ADR 0010's
prototype set contains no entity a network's status text or circuit signals could attach to; ADR 0010's
per-reaction plasma fluids already exclude the mixed-plasma model that gave networks their physical
meaning; and the merge and split paths — where the reference implementation loses plasma outright in both
directions — are real work that buys nothing v1 has asked for. Its genuine advantage, cost scaling with
machine count rather than reactor count, is narrowed by cadence throttling and is not worth the
complexity until measurement says otherwise.

**Per-reactor with no fluid coupling.** Each reactor an island, plasma neither shared nor mixed between
connected reactors. Rejected as strictly worse than the decision above for the same code: it discards
sharing behaviour the engine provides for free, and would make a bank of connected reactors behave less
coherently than the plumbing in front of the player suggests.

# Context

The vocabulary this project uses. When a document, issue, prototype name or commit message names one of
these concepts, it uses the term as defined here rather than a synonym.

Created alongside [ADR 0010](docs/adr/0010-v1-module-layout-and-prototype-set.md), which specified v1.
Decisions live in `docs/adr/`; this file only fixes the language.

## The two mods

**Core** — `RealisticFusionCore`, title "Realistic Fusion Core". Owns every fluid and item prototype,
and the extraction chain that produces feedstock. Never references Power.

**Power** — `RealisticFusion`, title "Realistic Fusion". Owns reactors, heat and generation, and depends
on Core. Referred to as "the main mod" when distinguishing it from the library.

Dependencies run **one way only**: Power → Core. Where a reactor produces a Core-owned fluid, the
prototype is defined in Core and the recipe lives in Power.

## The fuel chain

**Girdler sulfide process** — the deuterium enrichment method, using hydrogen sulfide as a recirculating
catalyst. Not "deuterium separation" or "enrichment" generically.

**Heavy water** — deuterium oxide, the intermediate between water and deuterium.

**Depleted water** — the spent stream leaving enrichment. Not "waste water".

**Brine** — lithium-bearing solution concentrated from water. The lithium route deliberately involves
**no map resource**; brine is produced, never mined.

**Breeding** — producing tritium or helium-3 rather than extracting it. Two routes exist and are named
distinctly:

- **D-D by-products** — tritium and helium-3 arising from the D-D reaction itself. The early route; the
  reactors are the breeder.
- **Blanket breeding** — tritium bred from lithium in a blanket on a reactor. The later upgrade tier,
  and the route real D-T reactors use.

**Breeder tier** — a tier whose product is fuel rather than electricity, and which consumes more power
than it makes. **The D-D tier is one**, by decision and not by shortfall — see
[ADR 0015](docs/adr/0015-the-d-d-tier-is-a-breeder.md). Say "breeder tier" of the tier and "D-D
by-products" of what it makes; do not describe a D-D reactor as a power source, and do not call its
negative balance a deficit, a shortfall or unfinished balance.

## Reactions

Written with hyphens and matching case throughout: **D-D**, **D-T**, **D-He3**, **He3-He3**. Not "DD",
"D+T" or "deuterium-tritium".

**Aneutronic** — the D-He3 and He3-He3 tier, whose reactions release far fewer neutrons and permit
direct energy conversion. The end of v1's progression.

Two things about it are worth having in the glossary rather than only in the code, because both are
easy to state wrongly:

- **In this mod both aneutronic reactions release no neutrons at all**, not merely fewer. That is the
  model rather than the physics: a real D-He3 plasma still contains deuterium and runs D-D on the
  side, which does make neutrons, and the simulation burns one reaction per plasma so the side branch
  is not modelled. Say "aneutronic", never "neutron-free", of the real reactions.
- **Direct energy conversion is a different route, not a better one.** It collects charged fusion
  products as current instead of boiling water with them, which is only possible because nothing
  leaves as a neutron. The gain is that the whole steam stage — heat exchanger, water, turbines —
  disappears, not that the conversion is markedly more efficient.

**Plasma** — the heated, confined state a reaction runs in, carried as a fluid. Each reaction has its
own plasma. Plasma must not travel through vanilla pipes.

## The simulation

**Cross-section data** — tabulated reactivity ⟨σv⟩ as a function of plasma temperature, held in
`cross-section-data/`. The reaction rate is interpolated from it rather than tuned by a constant. This
is what "realistic" means concretely in this project.

**Reaction rate** — the simulation's output, derived from cross-section data. Not "yield" or "output"
when the interpolated quantity is meant.

**Operating density** — how full of plasma a reactor's fluid segment is held, as a lever the player
chooses rather than a supply problem to eliminate. A reaction has a density at which it makes the most
power, and it is not necessarily a full one; see
[ADR 0016](docs/adr/0016-plasma-density-is-a-player-lever.md).

Two words that are **not** synonyms and are easy to swap by accident:

- **Under-supplied** — held below full deliberately. May be the *best* state a reactor can be in.
- **Starved** — held below the density at which the reactor is worth running. A genuine fault.

Reserve "starved" for the fault. A reactor at its operating density is under-supplied and working.

**Q-factor** — the ratio of fusion power produced to heating power supplied. Exposed to the player as a
circuit signal.

**Tick cadence** — how often the simulation steps. Deliberately separate from the rate computation, so
throttling is a configuration change. See ADR 0005.

**Per reactor** — the unit of simulation. One reactor entity is one simulated object, with its own state
in `storage` and its own circuit signals. Not "per network": v1 has no network concept and no
connectivity tracking. See [ADR 0011](docs/adr/0011-per-reactor-simulation-fluid-coupled.md).

**Fluid-coupled** — how connected reactors interact: through the engine's own fluid system, sharing one
plasma pool at one mixed temperature, rather than through anything this mod computes. Reserve the word
for that mechanism; do not call it a network.

**Network** — the *redesign's* model, in which reactors and heaters joined by confinement pipe were one
simulated object sharing a mixed plasma. Named here only so the term is recognised when it appears in
predecessor code or research notes. **v1 has no networks.**

## Generation

**Steam route** — reactor energy to electricity by way of heat: `rf-heat-exchanger` (or `rf-hc-exchanger`)
raises water to 500 °C steam and a turbine drinks it. The counterpart to **direct energy conversion**,
and the only route the neutronic tiers have.

The turbine at the D-D tier is **vanilla's `steam-turbine`, unlocked by `rf-d-d-fusion` itself**
(Truls's call, 2026-08-19, answering #36). Vanilla gates that turbine behind `nuclear-power`, so without the unlock the tier
would make steam nothing in its own prerequisite closure could drink. The consequence is accepted and
deliberate: the steam turbine becomes available before nuclear power, where an ordinary boiler can also
drive it. Fusion is **not** gated behind fission, and there is no `rf-turbine`.
`check_steam_sinks()` in Power's `control.lua` holds the invariant rather than the choice — it requires
some reachable sink, not that particular one.

**No fission dependency is to be introduced unless the physics forces one** (Truls, 2026-08-19, on #36).
Not a prerequisite, not an ingredient. If a physical reason exists it is expected to turn up organically
rather than be reached for; the survey in
[`docs/research/fission-as-fusion-prerequisite.md`](docs/research/fission-as-fusion-prerequisite.md)
looked and found only tritium supply, which is a start-up-inventory problem attaching to `rf-d-t-fusion`
and not to the D-D tier. Note that the mod's own lineage disagrees — all three older predecessors rooted
their tree in `nuclear-power` — and that Factorio's own Space Age fusion does not.

Unlocking vanilla's turbine ourselves is **redundant rather than early** under Bob's, which re-homes
`steam-turbine` to `bob-steam-turbine-1` at the same science tier behind fewer prerequisites. Should
Bob's ever become an integration target rather than a coexistence one (ADR 0007 defers, does not
refuse), the thing to drop would be *our* unlock — Bob's already removes fission's.

## Predecessors

Named precisely, because four exist and conflating them has already caused one factual error in this
repository's own README:

**The original** — Realistic Fusion Power by Romner_set, Factorio 0.17–1.1, WTFPL from release 1.8.18.

**The port** — Realistic Fusion Power Port by Durikkan, Factorio 2.0, The Unlicense.

**The redesign** — `realistic-fusion-dev`, the archived four-module split. Its "2.0" is the *mod's*
version number; it targets **Factorio 1.1**. Never call it a 2.0 mod.

**UFP** — `ufpFixed`, "UFP: Ultimate Fusion Power Fixed" by VVVVVVEmersonFisioVVVVVV, with its
`ultimateCore*` asset packs. A live, divergent bootleg of the original, Factorio 2.0–2.1. Found
2026-08-19 and a reference only: **no asset of its is usable** (see
[ADR 0001](docs/adr/0001-liftable-predecessor-material.md)). Not one of "the three" when that phrase
appears in older notes, which predate it.

None of them is an upstream base — v1 is written fresh with all of them as reference
([ADR 0004](docs/adr/0004-fresh-code-predecessors-as-reference.md)).

## Compatibility words

**Coexistence** — loads and runs alongside another mod without crashing or colliding. What v1 commits
to.

**Integration** — resource-chain hooks, recipe substitution, replacing another mod's implementation.
What v1 does *not* do, for any mod. See [ADR 0007](docs/adr/0007-coexistence-without-integration.md).

The distinction is load-bearing: "compatible with X" is ambiguous between them and should be avoided.

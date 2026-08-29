# Context

The vocabulary this project uses. When a document, issue, prototype name or commit message names one of
these concepts, it uses the term as defined here rather than a synonym.

Created alongside [ADR 0010](docs/adr/0010-v1-module-layout-and-prototype-set.md), which specified v1.
Decisions live in `docs/adr/`; this file only fixes the language.

## The three mods

**Core** — `realistic-fusion-refreshed-core`, title "Realistic Fusion Refreshed Core". Owns every
fluid and item prototype, and the extraction chain that produces feedstock. Never references Power.

**Power** — `realistic-fusion-refreshed`, title "Realistic Fusion Refreshed". Owns reactors, heat and
generation, and depends on Core. Referred to as "the main mod" when distinguishing it from the
library.

**Assets** — `realistic-fusion-refreshed-assets`, title "Realistic Fusion Refreshed Assets". Owns
every sprite the other two draw, and nothing else: no fluid, no item, no entity, no technology. Both
of the others depend on it; it depends on neither. Added 2026-08-24 by
[ADR 0023](docs/adr/0023-art-ships-in-its-own-mod.md). Say "Assets" of the mod and "art" of what it
holds; it is not "the graphics mod", because a mod that held graphics *code* would be a different
thing and Power is where that would go.

Dependencies run **one way only**: Power → Core, and both → Assets. Where a reactor produces a
Core-owned fluid, the prototype is defined in Core and the recipe lives in Power.

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
  and the route real D-T reactors use. It has **two** products, not one: the capture reactions are
  exothermic, so a blanket sells heat as well as breeding tritium, and the heat follows the breeding —
  a blanket with nowhere to put tritium makes neither. See
  [ADR 0019](docs/adr/0019-the-blanket-sells-its-capture-heat.md).

**Breeder tier** — a tier whose product is fuel rather than electricity, and which makes no meaningful
power. **The D-D tier is one**, by decision and not by shortfall — see
[ADR 0015](docs/adr/0015-the-d-d-tier-is-a-breeder.md). Say "breeder tier" of the tier and "D-D
by-products" of what it makes; do not describe a D-D reactor as a power source, and do not call its
thin margin a deficit, a shortfall or unfinished balance.

> **Corrected 2026-08-21 (#52), when the radiation term shipped.** This said a breeder tier "consumes
> more power than it makes", which was written as a prediction and turned out false: measured, a D-D
> reactor sells **56.1 MW against the 50 MW it draws**. It pays for itself by a whisker. What makes it
> a breeder tier is that its *product* is fuel and its power margin is trivial — not that the margin
> is negative. Decided by Truls, 2026-08-21.

**Break-even** — ambiguous on its own, and the two meanings now differ for a tier that ships, so say
which:

- **Scientific break-even** is `Q = 1`: the plasma releases as much fusion power as the heating put in.
  This is what "below break-even" means everywhere in `docs/adr/`, and D-D is below it at Q 0.32.
- **Engineering break-even** is the plant paying for itself, which happens at
  `Q ≥ (1 − capture_efficiency) / capture_efficiency` — **0.1765** at the shipped 0.85. D-D is *above*
  it.

A reactor between the two is fusing at a loss and selling at a profit, which is not a contradiction:
the radiated X-rays heat the first wall and that heat is recovered. **D-D is exactly there.** Never
write "below break-even" of the D-D tier without saying which one is meant.

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
own plasma. Plasma is **contained** and must not travel through vanilla pipes — see
[Plumbing](#plumbing).

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

**Ignited** — a plasma whose own fusion self-heating carries it without external confinement heating.
Confinement heating gets an ignited plasma **to** a fusing temperature; it is not what keeps it at one.
**D-T at this reactor's density and confinement time is ignited and D-D is not**, which is the tiers'
defining difference and not a balance number — see
[`d-t-ignition.md`](docs/research/d-t-ignition.md). Say "ignited" of the state and never of the tier's
output; a reactor can be ignited and still be selling very little, because what it sells follows the
fuel line rather than the temperature.

**Sub-ignition** — holding plasma, but below the density at which the reaction carries itself. A third
state, and not either of the two above: it is not **under-supplied**, because nobody chose it, and not
**starved**, because the plasma is there. It is the only state in which a reactor is a net drain on its
network, and the only one a player has to climb out of.

**Cold-parked** — a plasma sitting at the bottom of its temperature range, where the model's domain
ends. A fourth state, and a *temperature* one where the three above are about density: the plasma is
all there, and it is cold. A reactor reaches it within a second of losing its heating and stays
indefinitely, so it is the state an unpowered reactor is in rather than a moment on the way anywhere.

**A cold-parked plasma is inert.** It neither radiates nor leaks, because the floor is where this
simulation stops having anything valid to say — see
[ADR 0021](docs/adr/0021-the-floor-is-where-the-model-stops.md). That is a deliberate silence rather
than a physical claim: a real plasma that cold has recombined and is not plasma at all, and the mod
does not model that. Do not read "inert" as "stable" in the physical sense; it means the simulation
does nothing to it.

**Pinned** — a plasma held at the top of its temperature range by the ceiling rather than settling at
its own equilibrium. The counterpart to **cold-parked** at the other end, and a *temperature* state in
the same way. A pinned plasma is fusing normally; it is the *reading* that has stopped being a
measurement, which is why several reactions pinned at one ceiling report the identical number and a
wire cannot tell them apart — see
[ADR 0025](docs/adr/0025-a-plasma-temperature-ships-in-kilodegrees.md).

**The ceiling** — the temperature a plasma is clamped to. Placed at where every shipped reaction runs
free beneath it with margin, and deliberately **not** at where the cross-section data ends, which is
higher. **Do not read it as the floor's counterpart**: the floor is where the model stops having
anything valid to say, the ceiling is where the reactions land. A reaction that settles higher obliges
revisiting it; regenerating the dataset does not, by itself.

Not a synonym for **sub-ignition**, and the two are easy to swap. Sub-ignition is a reactor *running*
below where its reaction carries itself, with a player able to climb out by adding density.
Cold-parked is a reactor not running at all, and only heating gets it out.

Two words for losing power that are **not** interchangeable, because at the D-T tier they have
opposite consequences and conflating them is how a wrong premise about this mod got written down:

- **Brownout** — a partial shortfall. Every consumer on the network is `secondary-input` and gets the
  same fraction, so a reactor and its fuel line are throttled together. A lit D-T reactor rides one out
  at reduced output.
- **Blackout** — the supply is gone. A different thing rather than a worse one: the reactor goes on
  generating for many minutes, decaying, and only a very long one takes it towards **sub-ignition**.

Measured, both of them, by `scripts/check-brownout.ps1`.

**Q-factor** — the ratio of fusion power produced to heating power supplied. Exposed to the player as a
circuit signal.

**Q is a plasma statistic and only a plasma statistic.** A blanket's heat is released in a shell
outside the plasma, so it is **excluded** from Q however much of the reactor's output it becomes
(ADR 0019). The consequence is deliberate and worth knowing before reading a Q as a verdict on a
machine: a blanketed reactor is economically better than its Q says. Q is not an economic number.

**Kilodegrees** — the unit a plasma temperature reaches a wire in: thousands of degrees Celsius, so a
5×10⁹ °C plasma reads 5 000 000. Whole degrees cannot carry a fusion temperature in a 32-bit signal,
and this is the same move Q makes in shipping as a percentage rather than a ratio — the output carries
the scale that makes a good condition, not raw SI. **The engine's own fluid tooltip still reads
degrees**, so a pipe and a wire disagree by 1000× on purpose; say which one a quoted figure came from.
See [ADR 0025](docs/adr/0025-a-plasma-temperature-ships-in-kilodegrees.md).

**Blanket share** — the fraction of a reactor's sold energy that came from its blanket rather than its
plasma, exposed as a third circuit signal and expressed as a percentage of the **total**. Not the
*uplift* over a bare reactor, which is a larger number for the same machine — uplift is recoverable as
`share / (1 - share)` and is deliberately not what the signal carries.

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

**Host artefact** — a value the engine displays that belongs to the prototype an entity is *built on*
rather than to the simulation. `rf-reactor` is a boiler ([ADR 0011](docs/adr/0011-per-reactor-simulation-fluid-coupled.md)),
so it reports a consumption figure and a target temperature that its **physics** neither sets nor
reads: no simulated quantity depends on either. Both are host artefacts. Runtime glue may well
read one in order to *display* it, and that does not stop it being a host artefact: what matters is
whether the simulated quantity depends on it.

The rule: **correct a host artefact only where the engine reads it; otherwise say what it is and is
not.** Changing a value the engine acts on in order to fix a display is the wrong trade — it breaks
behaviour to mend a tooltip. Not "bug": a host artefact is a consequence of a deliberate choice about
what to build on, and calling it a bug invites a fix that breaks what it is a consequence of.

## Plumbing

> **Plasma containment is built and gated. The energy half of this section is decided but not yet
> built.** ADR 0018 was accepted on 2026-08-20; no prototype carries an energy category yet, so today
> an ordinary pipe still joins a reactor's energy output and still carries the fluid —
> `scripts/check-containment.ps1` asserts exactly that, and passes. The terms below are fixed now
> because a decision fixes vocabulary, which is all this file does; the behaviour arrives with the
> implementation. Remove this note when the energy categories ship.

**Contained** — of a fluid: its boxes carry a connection category of their own, so nothing joins them
but plumbing that shares it. Three fluids take a category of their own — plasma, and the two reactor
energies — and they are **separate** categories, so being contained is not one club: a plasma line and
an energy line cannot join each other either.

Say it of the fluid or of the box, never of the entity. Containment is declared per box, and the
entities carry a mixture: a reactor's plasma box and its energy box are contained under different
categories, while `rf-heater`'s deuterium intake is not contained at all and a player plumbs it with
ordinary pipes.

**Bolted** — of a connection: made by two machines' faces meeting, with no pipe between them. This is
how reactor energy is *to* travel, because no pipe is to carry it. Reserve the word for a connection
that actually carries fluid: two buildings can be adjacent, or touching, without their boxes facing
each other, and that is neither bolted nor connected.

**Reactor energy** — what a reactor sells, as a fluid whose amount is joules: one unit is one
megajoule throughout the mod, so the tiers' outputs compare without a conversion. Not "output",
"power" or "heat" when the fluid is meant.

There are **two** of them, one per conversion route, and the pair is the tier's mechanic rather than
bookkeeping. Containing them separately is what keeps the routes apart: a heat exchanger is not to be
bolted to an aneutronic reactor nor a direct energy converter to a neutronic one, and the engine is to
refuse the connection rather than let a player build something that would sit dry.

See [ADR 0018](docs/adr/0018-energy-is-contained-and-no-pipe-carries-it.md) for why energy is plumbed
this way rather than piped, and what was rejected.

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

**Confinement ladder** — the three technologies that raise a reactor's energy confinement time, and
the route out of the sub-break-even D-D tier ([ADR 0015](docs/adr/0015-the-d-d-tier-is-a-breeder.md)
makes that tier deliberate;
[ADR 0024](docs/adr/0024-confinement-time-is-the-researchable-lever.md) is what a player does about
it). Say "ladder" of the line and "rung" of a step in it. It moves **a physical parameter and never a
power bonus**, which
[ADR 0014](docs/adr/0014-realistic-means-theoretically-possible.md) requires and
[ADR 0005](docs/adr/0005-real-time-fusion-simulation.md) makes unavoidable: the reaction rate is read
off cross-section data, so there is nowhere for a flat megawatt bonus to live. **It is per force** —
two forces on one map run the same reactor prototype at different confinement times — and
**neutronic only**, like plant efficiency and for a related reason: the aneutronic reactor's balance
was settled at 60 s and a technology named for the machine below it must not reopen that.

**Any figure quoted for a rung has to name its supply**, which is [ADR
0016](docs/adr/0016-plasma-density-is-a-player-lever.md)'s doing rather than pedantry: at the middle
rung a full reactor misses break-even and one held around 85% full clears it. Both are true
and they are different sentences.

**Capture efficiency** — what fraction of everything leaving a plasma is recovered as reactor energy.
Heat *recovery*, not heat-to-work: Factorio's turbine does the conversion and loses nothing, which is
precisely why this term exists. It is **the only thing standing between this mod and perpetual
motion** — at 1.0 a reactor that never fuses would sell back exactly the heating it was given and pay
for itself for ever — and it also stands in for the divertor, cryoplant and magnet power the
simulation does not model. Never describe it as a fudge factor, and never raise one toward 1.0 without
reading [ADR 0020](docs/adr/0020-plant-efficiency-is-researchable.md).

**Plant efficiency** — capture efficiency as a thing a player improves, by research, in finite steps
that each close half the remaining distance to a ceiling below 1.0. Named for both jobs the constant
does, which is why it is not "heat recovery"; the industry's own "balance of plant" means the same and
reads as jargon. **The neutronic route only** — direct energy conversion is not researchable, and the
two routes converging is what makes this file's claim about direct energy conversion literally rather
than approximately true.

> **Both of the terms above ADR 0019 and ADR 0020 introduce are decided and not yet built.** No
> `rf-signal-blanket-share` and no `rf-plant-efficiency` technology exists yet, the blanket sells no
> heat, and capture efficiency is still a constant no research touches. The terms are fixed now
> because a decision fixes vocabulary, which is all this file does. Remove this note when both ship.

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

**Overlap candidate** — two prototypes from *different* mods that likely represent the same concept
(two deuterium fluids) without sharing a prototype name. Heuristic by construction and judged by a
human, never by the engine. Distinct from a **collision**, which is one prototype name defined twice —
the silent replacement `scripts/name-check.ps1` exists to catch. An overlap candidate is a finding to
weigh, not a fault: coexistence tolerates duplicated concepts by design.

**Set** — a pinned list of third-party mods, defined in `scripts/fetch-mods.ps1`'s `$MOD_SETS` and
named there (`krastorio2`, `spaceex`, `angels`). The pins are the definition; prose never re-derives
them.

**Lane** — one set, plus the bundled selection it is loaded with, verified as a unit. `angels` alone
and `angels` with Space Age are two lanes over one set. A lane yields a **verdict**, which is durable
and lives in [ADR 0007](docs/adr/0007-coexistence-without-integration.md), and a run log, which lives
in the lane's issue — see [ADR 0027](docs/adr/0027-the-lane-issue-is-the-run-log.md).

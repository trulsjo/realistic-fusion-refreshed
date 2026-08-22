# 18. Reactor energy is contained, and no pipe carries it

Date: 2026-08-20

## Status

Accepted. Resolves
[#44](https://github.com/trulsjo/realistic-fusion-refreshed/issues/44) — whether the reactor should
deliver heat instead of a fluid.

Amends [ADR 0010](0010-v1-module-layout-and-prototype-set.md), which calls its prototype set "a
starting specification, not a contract" and asks to be amended by a superseding ADR rather than
drifted from. **The set itself does not change** — nothing is added and nothing is removed. What
changes is how two of its fluids are plumbed.

Closes the question [ADR 0012](0012-reactor-signals-need-a-companion-entity.md) and
[ADR 0013](0013-the-reactor-is-fifteen-tiles-square.md) both defer to #44 as open. Neither is
disturbed by the answer; see [Consequences](#consequences).

Decided by Truls, 2026-08-20. Rests on two probes that were taken before the choice rather than
after it: [#43](https://github.com/trulsjo/realistic-fusion-refreshed/issues/43)
([`native-heat-probe.md`](../research/native-heat-probe.md)) ruled out the option this ticket was
named for, and [#82](https://github.com/trulsjo/realistic-fusion-refreshed/issues/82)
([`energy-containment-probe.md`](../research/energy-containment-probe.md)) established that the
option chosen is one the engine will actually build.

## Context

`rf-reactor` sells `rf-reactor-energy`, a fluid whose amount is joules — one unit is one megajoule —
and `rf-heat-exchanger` burns it for its `fuel_value`. It works: a built reactor drives four
exchangers and twenty-four turbines. **But vanilla pipes carry it**, so the reactor-to-exchanger run
uses none of this mod's own fluid handling, which reads wrong for a fusion plant and leaves `rf-pipe`
decorative on that leg.

#44 offered three ways out: adopt native heat, keep the fluid but restrict the pipes, or leave it
alone. All three lost, and a fourth won.

### #43 removed native heat, and most of the case for it

**A `reactor` prototype gets no fluid box at all.** Tried under both `fluid_box` and `fluid_boxes`;
the data stage accepts the field and the engine drops it — the same failure as
[#23](https://github.com/trulsjo/realistic-fusion-refreshed/issues/23)'s crafting machine. So the
heat emitter and the plasma pool **cannot be one entity**, and native heat costs at least one more
entity or a companion arrangement of the kind the reactor already has for collectors and blankets.

Three of #44's four arguments for heat do not survive that:

- *"`control.lua` writes `entity.temperature` instead of a second fluid box — simpler than what it
  does now."* **False.** One `box[2] = {…}` becomes one `temperature` write **plus** a companion
  entity, its pairing in `entity-management.lua`, and its build, mine, blueprint, undo and robot
  lifecycle.
- *"makes `rf-pipe` decorative on that leg."* **Relabels it rather than fixing it.** #43 measured
  stock heat pipes carrying 4.5× to 7.5× the reactor's 133 MW, so no pipe of our own is justified by
  throughput — the leg would go from a vanilla pipe carrying our fluid to a vanilla *heat* pipe
  carrying our heat.
- *"the pipe question disappears by construction."* **Survives.** Heat is not a fluid.
- *"energy as a fluid reads wrong for a fusion plant."* **Survives**, and once the other two fell it
  was the only argument still doing work — an aesthetic one, against a companion entity, a lifecycle,
  a rewrite of the shipped #26 and #32, an unmeasured UPS cost, and re-demonstrating ADR 0011 against
  a different entity.

### The engine's own fusion answers this question, and not with heat

Checked against the installed 2.0.77 Space Age data
(`space-age/prototypes/entity/entities.lua`, `space-age/prototypes/fluid.lua`):

- Every `fusion-plasma` connection on **both** `fusion-reactor` (`:2512-2515`) and
  `fusion-generator` (`:2393-2399`) carries `connection_category = {"fusion-plasma"}`.
- **No pipe a player can build carries that category** — so a reactor and a generator must bolt
  directly face to face, with no pump, no tank and no wagon available either. Reactor-to-reactor
  chaining uses `neighbour_connectable`, not plumbing.

  **Three prototypes carry it, not two**, and the third is worth knowing rather than glossing:
  `space-age/base-data-updates.lua:237-239` patches `infinity-pipe`'s connections to
  `connection_category = {"default", "fusion-plasma"}`. That is the editor's debug pipe, not
  something craftable, so it does not weaken the point — but it does mean Wube categorised their
  infinity pipe for exactly the reason #82's rig categorised one: as an **instrument** for feeding a
  fluid nothing buildable can carry. An earlier version of this ADR said "Space Age ships no pipe
  with that category" and "those two machines are the only prototypes that have it", and both were
  simply false.
- `fusion-plasma` is `auto_barrel = false`, and carries its energy in **temperature**
  (`heat_capacity = "25J"`, default 1 000 000 °C, max 10 000 000) — the exact inverse of
  `rf-reactor-energy`, which is 1 MJ per unit at 15 °C.

So Wube's answer to "should fusion energy travel through ordinary pipes?" is an emphatic no, reached
**without** heat: a categorised fluid with nothing buildable to carry it. That is a fourth option #44
never listed, and it costs no entity at all.

### What leaving it alone would have left open

`auto_barrel = false` closes barrels on both energy fluids (`prototypes/fluids.lua:119`, `:155`), and
the plasma category closes plasma wagons (`entities.lua:706-715`). But the energy fluids carry no
category, so:

| vessel | holds | at 1 MJ a unit |
|---|---|---|
| vanilla storage tank | 25 000 units | **25 GJ** |
| vanilla fluid wagon | 50 000 units | **50 GJ** |
| *vanilla accumulator, for scale* | — | 5 MJ |

One cheap tank is about five thousand accumulators of storage, and a train can haul fusion output
across the map. Vanilla has partial precedent — steam in tanks is standard nuclear buffering — but at
0.2 kJ/°C a steam tank is roughly 2.4 GJ, so this is an order of magnitude denser. **Nobody designed
that capability**; it is what a fluid with a `fuel_value` and no category gets for free.

### And restricting the pipes was either a footgun or expensive

- **Reusing the `rf-plasma` category** on the energy boxes is about three lines, and it opens a jam.
  The reactor's plasma box is deliberately unfiltered
  ([#28](https://github.com/trulsjo/realistic-fusion-refreshed/issues/28)), so a run of `rf-pipe`
  could carry reactor energy *into* it — from the reactor's own north face, even — and the reactor
  would sit there reporting itself starved. `check_every_plasma_burns` is a load-time guard on
  plasma-heating recipes and would not catch it. Today that is impossible by construction.
- **A category of its own plus a pipe family of its own** — pipe, pipe-to-ground, pump, with
  recipes, technologies, locale and art — is three entities beyond ADR 0010's set, bought entirely
  with the aesthetic argument above.

### #82 established that the chosen option is buildable

The load-bearing unknown was narrow: `contain()` sets `connection_category` on `pipe_connections`,
but `rf-heat-exchanger`'s intake is a fluid box **nested inside a fluid energy source**, and nothing
established that the engine reads the field in that position. A negative would have voided this
decision outright — the reactor's output categorised and the exchanger's intake left `default` means
**nothing connects at all**, no pipe and no bolt, and a boiler's fuel cannot arrive any other way.

Measured against 2.0.77: an ordinary pipe is refused, a pipe sharing the category joins and the
exchanger reaches `working`, a categorised exchanger bolts face to face with a reactor's output box
with no pipe between them, and two of them chain with fuel crossing to the second. `rf-hc-exchanger`
answers the same. Bare-string and one-element-list forms behave identically, so `contain()`'s bare
string stands.

## Decision

**The two energy fluids are contained the way plasma is, and nothing carries them but a bolted
face.**

1. **`rf-reactor-energy` and `rf-aneutronic-reactor-energy` each get a `connection_category` of their
   own**, applied to every box that carries them: `rf-reactor`'s output box, `rf-aneutronic-reactor`'s
   output box, `rf-heat-exchanger`'s and `rf-hc-exchanger`'s fluid-energy-source boxes, and
   `rf-direct-energy-converter`'s box.

2. **No pipe entity carries either, and none is added.** Exchangers and converters bolt directly onto
   a reactor face and chain to one another. ADR 0010's prototype set is unchanged.

3. **One category per fluid, not one shared between them.** A converter cannot bolt to a neutronic
   reactor and an exchanger cannot bolt to an aneutronic one: the engine refuses the connection
   outright rather than joining two boxes whose filters disagree and leaving a player to work out why
   nothing flows. `prototypes/fluids.lua:125` calls the separation of the two conversion routes "the
   tier's whole mechanic rather than bookkeeping", and `CONTEXT.md:62` calls direct energy conversion
   "a different route, not a better one". This puts both statements in the geometry.

4. **`rf-heat-exchanger`'s energy box becomes `input-output` on three connections** — south
   `{0, 0.5}` plus west `{-1, -0.5}` and east `{1, -0.5}` — so an exchanger bolts onto a reactor and
   chains along a row. `production_type` stays `"input"`: what the machine *does* with the fluid is
   unchanged, and `flow_direction` is what decides whether a connection will join another machine's.

   **Three connections rather than two is forced, not chosen.** On a 3×2 entity the tile centres are
   x ∈ {−1, 0, 1} and y ∈ {−0.5, 0.5}, and four of those tiles are already taken — water at west
   `{-1, 0.5}` and east `{1, 0.5}`, steam at north `{0, -0.5}`, the intake at south `{0, 0.5}`. Two
   connections on one tile will not load. So west `{-1, -0.5}` and east `{1, -0.5}` are the only free
   tiles facing sideways, and south is still needed to meet a north-facing reactor output.
   `rf-hc-exchanger` has a seven-tile face and more room, but the same reasoning governs it.

5. **`rf-aneutronic-composite-tank` becomes a helium-3 vessel only.** Its energy-buffering role goes,
   because a categorised energy fluid cannot enter it.

6. **Plasma containment is untouched.** `rf-pipe`, `rf-pipe-to-ground` and `rf-pump` keep the
   `rf-plasma` category and the job they already do.

## Consequences

- **The objection that started #44 is closed by construction rather than by a rule.** No vanilla pipe
  can join the energy leg, and there is no pipe of ours to be decorative on it either — the leg has
  no pipe at all.
- **No vanilla tank or wagon can hold either energy fluid.** The 25 GJ and 50 GJ storage above is
  gone. That is the removal of a capability nobody designed rather than a balance change.
- **One class of silent mistake disappears.** `bench-mod-links.ps1:326-330` records it: an exchanger
  sat directly on a shared energy header joins its *water* inlet to that header, which fills with
  water, and "it reads as a reactor that produces nothing rather than as a plumbing mistake". Water
  cannot join a categorised energy run.
- **The high-capacity tier stays a convenience.** Because chaining works, eight exchangers hang off
  one reactor connection in a row. Had it not, they would have had to ring the reactor — five fit per
  face against the eight an ignited D-T reactor needs — and `rf-hc-exchanger` would have become close
  to mandatory at the D-T tier rather than a way to avoid a blueprint chore
  ([#32](https://github.com/trulsjo/realistic-fusion-refreshed/issues/32)).
- **The composite tank's volume needs re-justifying.** 50 000 was sized against the converter's
  hundred units a second — about eight minutes of *energy* supply (`entities.lua:618-620`). Against
  helium-3 that number means something else and has not been examined. The entity's own "composite"
  material story already pointed at helium-3, so its name and its physics are unaffected.
- **The converter's burstiness argument is now unanswered, and this is the loose end.**
  `entities.lua:601-604` argued that an ignited reactor's output follows its fuel line and arrives in
  bursts, against a converter drinking at a fixed rate, and that a buffer between them is what turns
  that into steady output. With no tank in the chain the buffering is whatever the boxes hold: the
  reactor's 1000-unit output box plus 1000 in every chained converter, with `scale_fluid_usage`
  meaning partial fluid gives partial power rather than a stall. **Whether that suffices is not
  measured.** If it does not, the answer is a contained energy vessel — one entity beyond ADR 0010 —
  and that is a later ADR, not a silent addition.
- **Two shipped assertions invert.** `check-containment.ps1:338-342` asserts that an ordinary pipe
  still joins the reactor's energy output and carries reactor energy. Correct today, wrong after this.
- **One shipped gate becomes true but meaningless.** `check-aneutronic.ps1:678` asserts the composite
  tank buffers the tier's energy fluid, but fills it with `insert_fluid` on an unplumbed tank
  (`:463-466`), and Lua insertion ignores connection categories. It would keep passing after the
  capability was gone, which is worse than failing.
- **Rigs that plumb this leg with vanilla pipes need rebuilding:** `check-d-t.ps1`, `check-hc.ps1`,
  `check-brownout.ps1`, `bench-mod-links.ps1`, `bench-reactors.ps1`. And
  [`fluid-link-throughput.md`](../research/fluid-link-throughput.md) and
  [`reactor-runtime-cost.md`](../research/reactor-runtime-cost.md) measure a leg that stops existing.
- **Breaking change.** Existing saves and blueprints break silently: the pipes stay and the
  connections do not. Both mods are at 0.1.0 and unpublished, so no released-save migration is owed
  and [ADR 0006](0006-clean-break-from-predecessor-saves.md)'s clean-break culture covers the rest.
  The commit carries `!` and a `BREAKING CHANGE:` footer.
- **Throughput is unmeasured.** #82 asked whether connections form and whether fuel crosses them, not
  what a bolted joint carries against a run of pipe. A row of eight chained exchangers off one
  reactor connection is the shape this ships and its rate is not known.
- **UPS is unmeasured**, and ADR 0005's outstanding obligation to measure it is unaffected either way.
- **The alignment arithmetic is a trap, and it is written down.** A pipe run aligns a connection's
  `target_position` onto the tile the pipe occupies; a **direct bolt** aligns one machine's connection
  *tile* onto the other's `target_position`. Align target against target and the two machines sit one
  tile clear of each other pointing at the same empty ground, which is indistinguishable from a
  refused connection. #82's rig made exactly that mistake and reported a false negative on the
  question deciding this ADR; only its calibration row caught it. The implementation meets the same
  arithmetic.

### What this settles elsewhere

- **ADR 0012 and ADR 0013 both defer to #44 as an open question** (`0012:97`, `0012:122`, `0013:78`,
  `0013:88-89`), on the grounds that it might stop the reactor being a boiler. **It does not.** The
  reactor keeps its prototype, its `input-output` plasma box and its 15×15 footprint, so ADR 0013's
  size and ADR 0012's companion entity both stand unchanged.
- **[ADR 0011](0011-per-reactor-simulation-fluid-coupled.md) is untouched**, and this is worth stating
  because #44 named it as the main risk. Native heat would have cost the shared plasma pool, since the
  emitter and the pool cannot be one entity. Heat is not adopted; the reactor keeps the box that makes
  a run of `rf-pipe` feed a row of reactors from one pool, and fluid-coupling is exactly as it was.
- **ADR 0010's prototype set is unchanged**, including the fluids and the plasma-safe pipe family it
  lists at `:126-131`. What this amends is its containment rule: `:144` says *"Vanilla pipes must not
  carry plasma"*, and after this the same sentence is true of the two energy fluids as well — which
  ADR 0010 could not have said, because at the time they were meant to travel on ordinary pipes.

## Alternatives considered

**Adopt native heat, as the ticket was named for.** Rejected on #43's evidence: a `reactor`
prototype has no fluid box, so the emitter and the plasma pool cannot be one entity and heat costs a
companion arrangement with everything that implies for ADR 0011 and for what a player builds. Three
of the four arguments for it also failed on inspection, and the one that survived — energy as a fluid
reads wrong — would not even have been closed by it, because the evidence says carry the heat on
*vanilla* heat pipes.

**Keep the fluid and restrict the pipes with the existing plasma category.** About three lines, and
the cheapest thing on the table. Rejected: it lets a run of `rf-pipe` carry reactor energy into a
reactor's deliberately unfiltered plasma box, which no load-time guard catches and which is
impossible today.

**Keep the fluid, own category, own pipe family.** Closes vanilla pipes, tanks and wagons and keeps
distance on the leg. Rejected: three entities beyond ADR 0010's set for a run that needs no distance,
and it makes `rf-pipe` one of two pipes a player has to tell apart.

**Keep it exactly as it is.** Defensible — reactor energy is steam-like, not plasma, and the
rule this repository actually wrote down is that vanilla pipes must not carry *plasma*. Rejected on
the tanks and wagons above, and on diverging from the engine's own fusion on a point a reader will
notice.

**One shared category for both energy fluids.** Cheaper by one string, and the filters already stop
the wrong fluid moving. Rejected: it lets a converter bolt onto a neutronic reactor and then sit dry,
which is the same shape of silent failure as the water-in-the-header footgun this decision closes.

**Keep the composite tank as a contained energy vessel.** *Deferred rather than rejected.* It needs
the category on the tank, and a tank that also takes helium-3 through an uncategorised connection
reopens the leak the category closes — so it means a separate energy-only vessel, one entity beyond
ADR 0010. Not bought until the burstiness in Consequences is measured and shown to need it.

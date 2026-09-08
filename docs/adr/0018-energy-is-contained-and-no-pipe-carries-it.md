# 18. Reactor energy is contained, and no pipe carries it

Date: 2026-08-20

## Status

**Accepted, and implemented in full on 2026-09-07.** Item 1 shipped in
[#86](https://github.com/trulsjo/realistic-fusion-refreshed/issues/86) (the neutronic fluid) and
[#87](https://github.com/trulsjo/realistic-fusion-refreshed/issues/87) (the aneutronic one), which
carry items 2, 3 and 5 with them. Twenty-four connections now declare a category, up from fourteen;
`scripts/check-containment.ps1` asserts that an ordinary pipe, a vanilla storage tank and a vanilla
pump are all refused by a live reactor-energy box, that a fluid wagon has no fluid box for a pump to
be its only route into, and that a converter and a neutronic reactor refuse each other. Item 4's
geometry came first, from [ADR 0031](0031-energy-bolts-along-a-long-face.md); item 6 was never
touched. `rf-hc-exchanger` is contained on the declaration it already had, so
[#276](https://github.com/trulsjo/realistic-fusion-refreshed/issues/276) is about its footprint and
not about this ADR.

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

  **And a third party can do the same without the rationale.** SeaBlock's `no-pipe-touching` collects
  every connection category it finds onto `infinity-pipe`, `rf-plasma` among them, naming nothing of
  ours. So the exception is not one prototype the engine controls: what the guarantee covers is
  plumbing a player can build, and the set of things sharing a category is open. Reported and left
  red on that lane — [#195](https://github.com/trulsjo/realistic-fusion-refreshed/issues/195).

  **A set does also take a category away, and that matters more than collecting one. MEASURED, it
  happened, and it is CLOSED on the one lane where it did** — the fix is the last paragraph of this
  bullet, and everything between here and there is the measurement it was taken on. [#206](https://github.com/trulsjo/realistic-fusion-refreshed/issues/206) dumped the
  lane on 2026-09-01 against 2.0.77 and
  [#207](https://github.com/trulsjo/realistic-fusion-refreshed/issues/207) swept all fourteen; it was
  a reading of somebody else's Lua when this bullet was written and it is a measurement now. That
  mod's last `pipe-to-ground` pass overwrites `rf-pipe-to-ground`'s underground connection with the
  literal `pipe-to-ground`, and appends twelve categories to its surface one — a category is a
  whitelist, so both open a prototype a player builds. **One lane of fourteen does it**, and
  `no-pipe-touching` 1.1.28 is in no other lane's pin; containment holds on the other twelve of the
  fourteen contained connections *as they stood that day* -- containment was plasma-only then, and
  #86 and #87 took the count to twenty-four. The breaching pass is a `pipe-to-ground` pass and
  reaches no energy box, so only the denominator moved. See
  [`connection-category-reassignment.md`](../research/connection-category-reassignment.md) for the
  mechanism and
  [`connection-categories-by-lane.md`](../research/connection-categories-by-lane.md) for the sweep.
  [#208](https://github.com/trulsjo/realistic-fusion-refreshed/issues/208) decides the response and
  is Truls's; [#209](https://github.com/trulsjo/realistic-fusion-refreshed/issues/209) is the gate
  that would catch the class.

  **#208 answered on 2026-09-01: take that mod's own opt-out.** `rf-pipe-to-ground` carries
  `npt_compat = { ignore = true }`, which gates the only pass that reaches it, so both of its
  connections come out of that lane holding `rf-plasma`. **So what is this ADR's claim worth under a
  set that reassigns categories?** Precisely this: **the declaration alone is not worth anything
  against a `data-final-fixes` that rewrites it, and this repo builds nothing that makes it
  survive.** Where it holds against such a mod, it holds because that mod published an opt-out and we
  took it — a permission, not a defence, good for one mod and no others. A general
  re-assertion pass of our own was declined as integration's posture rather than coexistence's; see
  ADR 0007's finding 4. **This ADR therefore claims containment for what it declares, plus one
  named exception, and not for what survives an arbitrary set.** What changed on 2026-09-02 is that
  the repo now *notices*: [#209](https://github.com/trulsjo/realistic-fusion-refreshed/issues/209)
  made `load-check` fail when a category this ADR declares is gone from the loaded dump. That is
  detection and not defence — the second mod #208 said to reassess on now fails a gate instead of
  waiting to be read out of somebody's `data-final-fixes`.
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

**Challenged and re-confirmed, 2026-09-06
([#111](https://github.com/trulsjo/realistic-fusion-refreshed/issues/111)).** A second rig,
`scripts/probe-exchanger-chaining.ps1`, measured five ways that exchangers do *not* chain, and
`docs/research/exchanger-chaining.md` recorded that against this paragraph. Both probes were rebuilt
and re-run on the current tree and they now agree: **exchangers chain.** The "no" was that rig's own
faults — it injected fuel into a box with `fluidbox[i] = {...}`, which never travels, and its one row
that fed through a pipe used a variant declaring one connection `"input"`. #82's probe had in turn
stopped running altogether, because it still built the 3×2 machine (see item 4 below), and its chain
row had no control. Both now have one.

Two conditions came out of it that this ADR did not state, and item 4 depends on the second:
**fuel has to arrive through a connection**, and **every connection on that energy box has to be
`input-output`** — one connection declared `"input"` stops fuel leaving by the others.

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
   tier's whole mechanic rather than bookkeeping", and `CONTEXT.md` calls direct energy conversion
   "a different route, not a better one". This puts both statements in the geometry.

4. **`rf-heat-exchanger`'s energy box becomes `input-output` on three connections** — north
   `{0, -2}` plus west `{-7, -1}` and east `{7, -1}`, on a machine declared fifteen wide by five
   tall — so an exchanger bolts onto a reactor's south face and chains along a row through its short
   ends. `production_type` stays `"input"`: what the machine *does* with the fluid is unchanged, and
   `flow_direction` is what decides whether a connection will join another machine's.

   **Amended by [ADR 0031](0031-energy-bolts-along-a-long-face.md), 2026-09-07, and implemented by
   [#275](https://github.com/trulsjo/realistic-fusion-refreshed/issues/275).** As first written this
   item gave south `{0, 0.5}`, west `{-1, -0.5}` and east `{1, -0.5}`, and argued that three
   connections were *forced* because four of a 3×2's six tiles were already taken. Both were true of
   the 3×2 machine and of nothing since: [ADR 0022](0022-footprints-follow-the-original-mod.md) made
   it 5×15 on 2026-08-24, and
   [#111](https://github.com/trulsjo/realistic-fusion-refreshed/issues/111) recorded on 2026-09-06
   that the item was unimplemented and its coordinates dead. ADR 0031 decided the geometry on the
   shipped footprint — energy bolts along a long face, both reactors sell it north **and south**,
   exchangers chain through their short ends — and the coordinates above are its. Three connections
   is still the count, now by choice rather than by tile arithmetic: one to meet the reactor, and
   one on each short end for the row. `rf-hc-exchanger` follows in
   [#276](https://github.com/trulsjo/realistic-fusion-refreshed/issues/276).

   **Item 2 no longer waits on this, and neither does item 1.** A reactor, an exchanger bolted to
   its south face and a second chained off the first's east end are built and asserted by
   `scripts/check-hc.ps1`'s plant section, with no pipe carrying reactor energy anywhere in it.
   Item 1 shipped on 2026-09-07 in
   [#86](https://github.com/trulsjo/realistic-fusion-refreshed/issues/86) and
   [#87](https://github.com/trulsjo/realistic-fusion-refreshed/issues/87), so every energy box now
   carries a category and that plant is the only way the fluid can travel.

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
- **One class of silent mistake disappears.** `bench-mod-links.ps1` records it, in `assert_segments()`: an exchanger
  sat directly on a shared energy header joins its *water* inlet to that header, which fills with
  water, and "it reads as a reactor that produces nothing rather than as a plumbing mistake". Water
  cannot join a categorised energy run.
- **The high-capacity tier stays a convenience.** Because chaining works, eight exchangers hang off
  one reactor connection in a row. Had it not, they would have had to ring the reactor — five fit per
  face against the eight an ignited D-T reactor needs — and `rf-hc-exchanger` would have become close
  to mandatory at the D-T tier rather than a way to avoid a blueprint chore
  ([#32](https://github.com/trulsjo/realistic-fusion-refreshed/issues/32)).

  **The escape hatch this names is gone, and the conclusion survives anyway (#111).** Ringing was a
  3×2 machine's option. `rf-reactor` declared one energy output, north `{0, -7}` (two since #275,
  north and south), so one machine can bolt to each whatever size it is — if chaining had failed,
  the alternative would have been a pipe carrying reactor energy, which is what
  [#258](https://github.com/trulsjo/realistic-fusion-refreshed/issues/258) asks about. Chaining does
  not fail, so that question stays hypothetical.
- **The composite tank's volume needs re-justifying.** 50 000 was sized against the converter's
  hundred units a second — about eight minutes of *energy* supply (`entities.lua:1034-1037`). Against
  helium-3 that number means something else and has not been examined. The entity's own "composite"
  material story already pointed at helium-3, so its name and its physics are unaffected.
- ~~**The converter's burstiness argument is now unanswered, and this is the loose end.**~~
  **MEASURED 2026-09-07 ([#85](https://github.com/trulsjo/realistic-fusion-refreshed/issues/85)):
  the chain buffers enough, and the argument does not buy a vessel.**
  `entities.lua:1000-1004` argued that an ignited reactor's output follows its fuel line and arrives in
  bursts, against a converter drinking at a fixed rate, and that a buffer between them is what turns
  that into steady output. With no tank in the chain the buffering is whatever the boxes hold: the
  reactor's 1000-unit output box plus 1000 in every chained converter, with `scale_fluid_usage`
  meaning partial fluid gives partial power rather than a stall.

  `scripts/probe-converter-buffer.ps1` built a heater-fed aneutronic reactor driving a chained row of
  converters with no tank anywhere, at two row lengths, and ran it for half an hour and again for an
  hour. **No cell stalled and no cell cycled**, at either length — every stall episode and every
  idle tick is in the first two minutes, before the reactor lights. A sixteen-converter row holds a
  smooth 485 MW and loses **0.00%** of the reactor's output, with its own boxes at 0 or 1 unit of the
  1000 they can take: the row's nominal buffer is never used, and the steadiness comes from
  `scale_fluid_usage` rather than from storage. **A tank adds nothing to what the chain delivers** —
  on the long row it never fills (247 units of 50 000) and both cells deliver the same power; on a
  two-converter row it fills once, to 48 333 units, after which the tanked and untanked cells lose
  the same 58.76%. What it measurably does buy is ripple: it cuts the long row's single-tick band
  from 4.7% peak-to-peak to 1.17%.

  A short row's failure mode is real but is not the predicted one: it **saturates**, the reactor
  reports `full_output`, and the surplus is discarded. That is answered by more converters and not by
  a vessel — a vessel delays it by its own volume and then stops helping.

  **So a contained energy vessel is not bought by this argument.** Whether one should exist on other
  grounds — ride-through of a supply cut is the obvious one, and is deliberately not measured — is
  still a decision, still Truls's, and still one entity beyond ADR 0010 and a later ADR rather than a
  silent addition. [`converter-buffering.md`](../research/converter-buffering.md) carries the
  numbers, including what they do not settle.
- ~~**Two shipped assertions invert.**~~ **DONE (#86).** `check-containment.ps1` asserted that an
  ordinary pipe still joined the reactor's energy output and carried reactor energy. Both rows now
  assert the opposite, with the rigs' categorised feed on the box's other face as the control that
  tells a refusal apart from a mis-aligned pipe.
- ~~**One shipped gate becomes true but meaningless.**~~ **REWRITTEN (#87).**
  `check-aneutronic.ps1` asserted the composite tank buffered the tier's energy fluid, but filled it
  with `insert_fluid` on an unplumbed tank, and Lua insertion ignores connection categories — so it
  would have kept passing after the capability was gone. It now builds the tank twice and plumbs
  both: on a helium-3 line it joins and fills, which is the role item 5 leaves it, and against a
  live categorised energy feed it joins nothing and holds nothing.
- ~~**Rigs that plumb this leg with vanilla pipes need rebuilding**~~ **DONE (#86, #87), and the
  list this bullet named was wrong in both directions.** What actually plumbed the leg with vanilla
  pipe was `bench-mod-links.ps1` (rebuilt: the first exchanger bolts to the reactor's south face and
  the rest chain off its east end, so its `-Pipes` now counts the plasma link only) and
  `check-pooling.ps1`'s `outlets` row (rebuilt: the reactor's energy box gets a bolted exchanger
  instead of twenty pipes and a tank, keeping the `get_capacity` assertion and losing the two that
  compare a box against a run). `check-d-t.ps1` drains through Lua, `check-brownout.ps1` already
  bolted, and `bench-reactors.ps1` never touched the leg. `check-aneutronic.ps1` and
  `probe-converter-buffer.ps1` needed the converter's new footprint rather than its plumbing, and
  the probe's two tanked cells are retired because a tank can no longer join the row at all.
  [`fluid-link-throughput.md`](../research/fluid-link-throughput.md) and
  [`reactor-runtime-cost.md`](../research/reactor-runtime-cost.md) measure a leg that no longer
  exists, and say so at the top.
- **Breaking change.** Existing saves and blueprints break silently: the pipes stay and the
  connections do not. Both mods are at 0.1.0 and unpublished, so no released-save migration is owed
  and [ADR 0006](0006-clean-break-from-predecessor-saves.md)'s clean-break culture covers the rest.
  The commit carries `!` and a `BREAKING CHANGE:` footer.
- **Throughput is unmeasured.** #82 asked whether connections form and whether fuel crosses them, not
  what a bolted joint carries against a run of pipe. A row of eight chained exchangers off one
  reactor connection is the shape this ships and its rate is not known.

  **Still true after #86, and the bench now says so on its face.** `bench-mod-links.ps1` prints its
  energy figure against #47's band of 100 units/tick flush down to a floor of 50 through a long run
  of pipe. A bolted joint is the flush case and there is no long run any more, so the band's lower
  end describes nothing buildable; the range is printed as it stands rather than narrowed, because
  re-deriving a ceiling for a bolt is
  [#227](https://github.com/trulsjo/realistic-fusion-refreshed/issues/227)'s question. What the bench
  did measure on 2026-09-07 is that four 40 MW exchangers bolted to one reactor return the same
  78.3 MW to six digits as the drain cell that removes everything: the row is not demand-limited, so
  the two cells are now one experiment.

  **MEASURED AND CLOSED, 2026-09-08 (#89).**
  [`bolted-joint-throughput.md`](../research/bolted-joint-throughput.md) carries it. One bolted
  connection is **100 units/tick — 6 000 MW** of this fluid; the eight-exchanger row this bullet
  names uses **5.3%** of it, and an unthrottled D-T reactor, which is the most the mod can ask,
  uses **19.9%**. So one connection is enough and the reactor needs no second energy face for
  throughput. The band this bullet describes is confirmed -- 100 flush, 51.3 at twenty pipes, so the
  quoted floor of 50 is the right asymptote. One thing it said does not hold: re-deriving the ceiling
  was never #227's question, #227 being a balance ticket about how much one exchanger should drain.
  What #89 did hand #227 is worse arithmetic -- the same rig puts an ignited D-T reactor at
  **996 MW sustained** against the ~320 MW `entities.lua` and #89's own text both reason from. This
  bullet's "eight chained exchangers" is that figure's consequence and inherits the correction.
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
ADR 0010. ~~Not bought until the burstiness in Consequences is measured and shown to need it.~~
**The burstiness was measured on 2026-09-07 (#85) and does not need it**, so the one condition this
alternative was left open against is discharged and negative. It stays deferred rather than rejected
because ride-through of a supply cut is a separate case for it that nothing has measured either way.

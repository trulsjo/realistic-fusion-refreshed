# Can heat exchangers be chained?

Measured against **Factorio 2.0.77** by [`scripts/probe-exchanger-chaining.ps1`](../../scripts/probe-exchanger-chaining.ps1),
first on 2026-08-23 and re-measured on **2026-09-06** for
[#111](https://github.com/trulsjo/realistic-fusion-refreshed/issues/111), which existed because this
note and [ADR 0018](../adr/0018-energy-is-contained-and-no-pipe-carries-it.md) gave opposite answers.

**Short answer: yes, under two conditions, and the earlier "no" was this probe's own rig.** ADR 0018
is right and [#82](https://github.com/trulsjo/realistic-fusion-refreshed/issues/82) reproduces.
Everything below the first table is why an earlier version of this page said the opposite for two
weeks.

**And eight chain, not merely two** — measured 2026-09-07 for
[#275](https://github.com/trulsjo/realistic-fusion-refreshed/issues/275), along with the water
question that chaining creates. See [A row of eight](#a-row-of-eight).

## The two conditions

1. **The fuel has to ARRIVE through a connection.** Fuel written into a fluid energy source's box
   by `fluidbox[i] = {...}` never leaves it. Every injected row below reads zero, whatever its
   connections say. This is specific to that box: `probe-energy-containment.ps1` writes an
   `rf-reactor`'s ordinary **output** box the same way every tick and the fluid travels out of it
   into two chained exchangers.
2. **Every connection on that box has to be `input-output`.** One connection declared plain `"input"`
   stops fuel leaving by the others, even though the boxes still join and the machine still burns
   what it is given.

Neither condition is about the `connection_category`, and neither is about whether the engine forms
the connection. All but one row below reports the pair joined.

## What was measured

Each variant is `rf-heat-exchanger` deepcopied with only its **energy** box's connections changed, so
nothing else differs. Two of each, one directly north of the other — the machine is 5×15, so fifteen
tiles apart puts their short ends together. Every machine has water in and steam out through infinity
pipes, so it can actually run.

| variant | how the first is fed | joined | reached the 2nd | 2nd status | 1st held |
|---|---|---|---:|---|---:|
| shipped — energy in on the west long face only, `"input"` | injected | no | **0** | `no_input_fluid` | 152 |
| ends — west `"input"`, both short ends `input-output` | injected | yes | **0** | `no_input_fluid` | 152 |
| ends only — no long face | injected | yes | **0** | `no_input_fluid` | 152 |
| all-io — west and both ends `input-output` | injected | yes | **0** | `no_input_fluid` | 152 |
| categorised — all-io plus a `connection_category` | injected | yes | **0** | `no_input_fluid` | 152 |
| **control** — shipped pair, both hung off one run of vanilla pipe | pipe | n/a | **199.3** | `working` | 199.3 |
| **ends, fed by a pipe** | pipe | yes | **0** | `no_input_fluid` | 199.3 |
| **all-io, fed by a pipe** | pipe | yes | **199.3** | **`working`** | 199.3 |

The last two rows are the whole finding and they **differ by one field**: the west connection's
`flow_direction`. Both are fed from the same pipe run on the first machine's west face, both join at
the short ends, and neither carries a category. The one that declares that face `"input"` passes
nothing on; the one that declares it `"input-output"` fills the second machine and runs it.

199.3 is a full 200-unit box being drawn down by a running 40 MW machine, which is the same reading
[`energy-containment-probe.md`](energy-containment-probe.md) gets everywhere fuel arrives.

## A row of eight

Measured 2026-09-07 for [#275](https://github.com/trulsjo/realistic-fusion-refreshed/issues/275).
**Eight chain, and water serves the row from its two ends.**

Everything above and in [`energy-containment-probe.md`](energy-containment-probe.md) measures **two**
machines. Eight is what a lit D-T reactor needs — about 322 MW against 40 MW each — and it is the
shape ADR 0018 describes. The subject is the machine #275 decides on: energy `input-output` on the
long face plus both short-end tiles, and water moved off the short-end centre to `_ e _ w _`.

Energy arrives on the **first** machine's long face through **one** connection, the way a reactor
bolts. Every other machine has to be reached through the short-end joints.

| machine | energy held | water held | status |
|---|---:|---:|---|
| row 1 of 8 | 199.3 | 199.3 | `working` |
| row 2 of 8 | 199.3 | 199.3 | `working` |
| row 3 of 8 | 199.3 | 199.3 | `working` |
| row 4 of 8 | 199.3 | 199.3 | `working` |
| row 5 of 8 | 199.3 | 199.3 | `working` |
| row 6 of 8 | 199.3 | 199.3 | `working` |
| row 7 of 8 | 199.3 | 199.3 | `working` |
| row 8 of 8 | 199.3 | 199.3 | `working` |
| **control**, joined to none | **0** | 200 | `no_input_fluid` |

The control is the same prototype with the same water and steam plumbing, joined to no neighbour and
given no energy feed. It reads zero, which is what makes the eight above worth reading. Its water
sits at a full 200 where the row sits at 199.3, because the row is running and drawing water down
while the control is stopped.

### The water constraint is created by chaining, and the rig counts it rather than claiming it

Once the machines bolt short end to short end, **every interior water connection is consumed by a
joint**, so a row is reachable at its two ends and nowhere else. Off this repo's own figure —
`rf-hc-turbine`'s 600 units/s of 500 °C steam is 58.2 MW, so 40 MW is **412 units/s** — eight
machines want about **3,300 units/s** through those two connections. They get it.

That "two ends" is not arranged by the rig. `unbound()` puts an infinity pipe on every **free**
target tile and skips occupied ones, so calling it on all eight water boxes leaves pipes exactly
where a player could reach one. And the rig now **counts what it left** instead of arguing that the
skipping works:

```
row: pipes the rig left -- water 2 (must be 2, the row's two ends), energy 1 (must be 1), steam 8 (must be 8)
```

### This section was flaky for its first three runs, and the tally is what caught it

Recorded because the table above is only worth reading if the rig that produced it is repeatable,
and for two runs it was not. The row is now identical across three consecutive runs.

**What happened.** The column reaches 105 tiles north, outside the starting area, and a `--benchmark`
map is created with a fresh seed every run. `unbound()` places an infinity pipe on every **free**
target tile and skips an occupied one — which is correct, and it also means **a tree standing on a
machine's steam target silently costs that machine its steam outlet**. It then backs up, reports
`full_output`, and reads as a result about chaining. One run lost row 8; the next lost row 2.

**Two counters separated the two possible causes**, and that is the only reason the fix was not a
guess:

- `create_entity` returns **nil** on ground it cannot build on, and that nil used to be swallowed.
  Now counted: *"pipes the GROUND refused"*.
- An occupied tile is skipped rather than refused, and shows up as the steam tally falling short of
  the machine count.

The reading was **refused 0, steam 7** — so nothing was refused by terrain, and something was
already standing on the tile. Paving alone would not have fixed it: `set_tiles` removes only
entities that *collide* with the new tile, so a lake's fish go and a forest's trees stay.

**The fix is both.** The section paves its footprint and then clears everything standing on it — the
rig's opening sweep covers `{-80,-80}` to `{80,80}` and this section sits outside it — and it still
reports both counters, so a rig that stops being enough says so instead of reporting a puddle as
physics.

**What it did not change.** No energy or water figure moved. Even on the two bad runs the affected
machine held a **full** 200 of each, which is the load-bearing result: energy and water reached the
eighth machine. What the bad runs got wrong was its `status`, and only because its steam had nowhere
to go.

### What the source is, and why it is not a reactor

An infinity pipe, deliberately. A real reactor sells about 322 MW against eight machines wanting
320, so feeding the row from one would confound *"the joints cannot carry it"* with *"the reactor
cannot supply it"*. This section asks the joints. What a real reactor sustains against a real row is
a separate measurement and is not on this page.

## The corroborating rig

[`scripts/probe-energy-containment.ps1`](../../scripts/probe-energy-containment.ps1) builds the same
question a different way — two categorised exchangers in a column, the lower one bolted face to face
with a categorised `rf-reactor`'s output box, no pipe anywhere — and agrees:

```
chain: the second exchanger joins the first: YES
chain: it holds 199.333 units and reports working
chain: against the first one's 199.333 units and working
chain: and their WATER boxes join as well, so one feed serves the row: YES
chain/control: an unjoined third one off to the side joins the second: no, and holds 0
               units -- this row must read no and 0, or the two above mean nothing
```

That last line is a control added by #111, and it is what makes the four above worth reading: the
same prototype with the same plumbing, joined to nothing, holds nothing. So the second machine's
fuel came through the joint and not from the rig filling everything it could reach.

The arithmetic corroborates it independently. The reactor's 1000-unit output box is refilled every
tick and reads **998.667** going into the report tick — a shortfall of **1.333 units**, which at
1 MJ a unit is 80 MW, which is exactly two 40 MW exchangers drawing at once.

## Why this page said "no", and what it cost

Two faults, both in this probe's rig, both of which look like the engine refusing to move fluid.

**Every row injected the fuel.** `first.fluidbox[i] = { name = ENERGY, amount = 200 }` fills the
energy source's box and the machine burns it, so the row looks alive — and nothing ever crosses to
the neighbour. The one
row that fed through a pipe existed to test exactly this, and it drew the wrong variant: it used
`ends`, whose west face is `"input"`, so it tripped over the second condition instead and reported
another zero. Two independent faults producing the same number is why the table looked so consistent.

**Nothing in the rig could run.** Water was filled once by Lua and steam had nowhere to go, so every
machine here stopped within seconds and every row — the control included — reported
`no_input_fluid`. That was read as a chaining failure. It was not measuring chaining at all, and it
also meant the one honest row, the control, was reporting a stopped machine while carrying fluid.
Both probes now plumb water and steam with infinity pipes on every free face.

**And a control that is never disturbed proves nothing.** This rig's control passed throughout, so
it never flagged either fault; the sibling rig had no control on its chain row at all. #111 added
one, and it is why the corroboration above is worth quoting.

**The cost was a live contradiction with the ADR that rests on it.** ADR 0018 decides that no pipe
carries either energy fluid, on the premise that exchangers bolt and chain. This page said they could
not, [ADR 0022](../adr/0022-footprints-follow-the-original-mod.md) recorded the disagreement as open,
and [#258](https://github.com/trulsjo/realistic-fusion-refreshed/issues/258) was raised to ask what a
contained energy pipe should look like — a question that only exists if chaining fails.

## The traps the earlier version already recorded, which still stand

**The data stage said yes, and that was worth nothing.** Setting `flow_direction = "input-output"` on
`energy_source.fluid_box` loads cleanly and `load-check` passes. That is the same false positive
[`probe-native-heat.ps1`](../../scripts/probe-native-heat.ps1) records for the
reactor-as-crafting-machine: it loaded perfectly and then moved no fluid at all.

**A box that runs dry reads as a box that was never fed.** The energy box holds 200 units and the
machine burns 40 MW of 1 MJ units — 0.667 a tick — so a 300-tick run consumes exactly the 200 it
started with. Both probes top their source up every tick.

**The control has to use a pipe that can carry the fluid.** The first control here joined the two
machines with `rf-pipe`, whose connections carry the plasma category (#26), so it could not carry
reactor energy at all and measured the containment rule instead of the question. Reactor energy is an
ordinary fluid today and an ordinary pipe carries it, so the control uses vanilla `pipe`. That is the
interim state rather than the intended one: ADR 0018 decides "No pipe entity carries either, and none
is added", and `CONTEXT.md` records that no prototype carries an energy category yet.

## What this settles, and what it does not

**Settled: two heat exchangers chain, and the mechanism is known.** Both probes agree, each has a
control that fails when it should, and the two conditions above say what a chaining shape has to
declare.

**Settled: eight chain, not merely two, and water reaches all eight.** See the row of eight above.
Both were open when this page was written; #275 measured them.

**Settled, and it was a decision rather than a measurement: what the shipped machine should
declare.** This section used to end *"Closing that gap is Truls's, and #111 only has to point at
it."* Truls closed it on **2026-09-07** — see
[#275](https://github.com/trulsjo/realistic-fusion-refreshed/issues/275) and the ADR it lands.
Reactor energy bolts along a **long face**, both reactors sell it north **and** south, the exchanger's
default orientation flips to fifteen wide by five tall with the energy face north, and water moves
off the short-end centre to `_ e _ w _` so an energy tile has a place there.

For the record of what the gap was: `rf-heat-exchanger`'s energy box has **one** connection in the
tree today — `flow_direction = "input"`, west `{-2, 0}`. By condition 2 that machine cannot chain,
and there is no second energy face for a neighbour to meet in any case.

**Not measured: the rate.** Every figure on this page is a box reading at steady state, not units per
second. What a chained joint carries against a run of pipe is still unknown, and
[`fluid-link-throughput.md`](fluid-link-throughput.md) measured the pipe case only. The row of eight
says the joints carry *enough* for eight machines to run with full boxes; it does not say how much
they could carry.

**Not measured: what a real reactor sustains against a real row.** The row above is fed from an
infinity pipe on purpose, because a reactor's ~322 MW against eight machines' 320 MW would confound
supply with transport.

**Also settled, in [`energy-containment-probe.md`](energy-containment-probe.md) rather than here: a
plain `"input"` connection still accepts a bolt.** So `flow_direction` governs **forwarding**, not
joining. Condition 2 above says what an `"input"` connection stops — fuel leaving by the other
connections on the same box — and it stops nothing about fuel arriving. That is why
`rf-hc-exchanger`, which declares one `"input"` connection on a face that can meet a reactor, can be
contained without changing its geometry at all.

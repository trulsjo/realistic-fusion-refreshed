# Can heat exchangers be chained?

Measured against **Factorio 2.0.77** by [`scripts/probe-exchanger-chaining.ps1`](../../scripts/probe-exchanger-chaining.ps1),
first on 2026-08-23 and re-measured on **2026-09-06** for
[#111](https://github.com/trulsjo/realistic-fusion-refreshed/issues/111), which existed because this
note and [ADR 0018](../adr/0018-energy-is-contained-and-no-pipe-carries-it.md) gave opposite answers.

**Short answer: yes, under two conditions, and the earlier "no" was this probe's own rig.** ADR 0018
is right and [#82](https://github.com/trulsjo/realistic-fusion-refreshed/issues/82) reproduces.
Everything below the first table is why an earlier version of this page said the opposite for two
weeks.

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

**Not settled, and it is a decision rather than a measurement: the shipped machine does not declare
that shape.** `rf-heat-exchanger`'s energy box has **one** connection today —
`flow_direction = "input"`, west `{-2, 0}` (`rf-heat-exchanger`'s `energy_source.fluid_box` in `prototypes/entities.lua`). By condition 2 that
machine cannot chain, and there is no second energy face for a neighbour to meet in any case. ADR
0018's Decision item 4 says it should be `input-output` on three connections and gives 3×2
coordinates that #45 made obsolete. **Closing that gap is Truls's**, and #111 only has to point at
it.

**Not measured: throughput.** Both probes ask whether a connection forms and whether fuel crosses it.
What a chained joint carries against a run of pipe is unknown, and
[`fluid-link-throughput.md`](fluid-link-throughput.md) measured the pipe case only. A column of eight
exchangers off one reactor connection is the shape ADR 0018 describes and its rate is not known.

**Not measured: whether water chains end to end.** Both probes now observe that the two machines'
water boxes join — the containment rig asks it directly and reports `YES` — but neither measures how
much water crosses, and the containment rig's own plumbing depends on it working.

**Not decided here: the layout.** `rf-hc-exchanger` at one-per-reactor sidesteps the eight-machine
question entirely, and it already exists. Whether the ordinary machine should chain, or stay a
manifold machine, is ADR 0018's item 4 and Truls's.

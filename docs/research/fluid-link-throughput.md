# What a fluid link carries in 2.0

How much fluid crosses from one machine to another, against how many connections join them and how
many pipes sit in between
([#47](https://github.com/trulsjo/realistic-fusion-refreshed/issues/47)).

Measured against **Factorio 2.0.77 (build 84539)** by `scripts/bench-fluid-links.ps1`. The script is
committed rather than the numbers alone, because this is a fact about a version of the engine and
the next version is entitled to a different one. Re-run it before quoting any figure here against a
newer build.

## Why the question exists

Realistic Fusion Power's 1.1 geometry butts a 15×15 reactor flush against a 5×15 heat exchanger, so
that two output connections meet two input connections with no pipe between them. The offsets are
identical in both entities down to the fractional part, which is not something anyone types twice by
accident. In 1.1 that arrangement bought throughput: pipe throughput degraded with segment length
and transfer was computed per connection, so a direct two-connection link was the fastest thing
available. The mod's opt-in "high capacity" setting — a 100 MW heat exchanger and a 10-fluid/tick
turbine — says plainly that its author was working against a throughput ceiling.

2.0 rewrote fluid flow into uniform segments. Durikkan's port kept the arrangement but converted the
coordinates mechanically, so its survival is not evidence that it still buys anything.

## The answer

**Both matter, and they are not the same size.**

From `pwsh -File scripts/bench-fluid-links.ps1`, no arguments — this is the default matrix:

| connections | flush | 1 pipe | 5 pipes | 20 pipes |
|---|---|---|---|---|
| 1 | 6 000 | 6 000 | 3 333 | 3 077 |
| 2 | 11 976 | 11 976 | 6 667 | 6 154 |
| 3 | 17 928 | 17 928 | 10 000 | 9 231 |

Units per second, sustained.

**Connection count is very nearly linear, and exactly so once you know why it is not.** Two
connections carry twice what one does less 0.2%, three carry three times less 0.4%. That shortfall
is not noise and not a warm-up artefact — the flush column, which has nothing to fill, shows it
while the 20-pipe column, which has the most, matches its formula to the digit. Each connection is
evaluated in turn against the source box's fill ratio *as the previous connection has just left it*,
and a connection's flow is that ratio times its ceiling. With one connection the source is still
full and the flow is the full 100/tick; with three it is 100 + 99.6 + 99.2 = 298.8.

That is arithmetic rather than a story, and it predicts what happens when the box is bigger:

| box volume | predicted, 3 connections | measured |
|---|---|---|
| 25 000 | 100 + 99.6 + 99.2 = 298.8 | 298.8 |
| 100 000 | 100 + 99.9 + 99.8 = 299.7 | 299.7 |
| 200 000 | 100 + 99.95 + 99.9 = 299.85 | 299.85 |

(`-Connections 1,2,3 -Distances 0 -Volume 100000`; the 200 000 row is that run's `cap2` control.)
So **the ceiling is 100 units/tick per connection at a full source and an empty sink**, and every
figure here is that ceiling scaled by how far from full the source has already been drawn.

**Pipe distance costs at most a factor of two, and one pipe costs nothing at all.** Per connection,
from `-Connections 1 -Distances 0,1,2,3,4,5,10,20,50,100`:

| pipes between | 0 | 1 | 2 | 3 | 4 | 5 | 10 | 20 | 50 | 100 |
|---|---|---|---|---|---|---|---|---|---|---|
| units/tick | 100 | 100 | 66.67 | 60 | 57.14 | 55.56 | 52.63 | 51.28 | 50.51 | 50.25 |

That is exactly **100·d/(2d−1)** for d ≥ 1, and 100 at d = 0 — every measured value matches to the
last digit printed. It falls towards a floor of 50 and never below, which is what two 100-unit
limits in series come to: a hundred-pipe run still carries half what a flush contact does.

So of the two things the predecessor's geometry does, **the second connection doubles the link, and
the flush contact is worth nothing at all against a single pipe and at most a factor of two against
a long run.**

None of that says the 1.1 arrangement is wrong. It says the arrangement is a much smaller
optimisation than 1.1 made it.

## What that means for this mod's own links

**Arithmetic from declared prototype values, not a measurement.** The measurement is
[#48](https://github.com/trulsjo/realistic-fusion-refreshed/issues/48), which puts a running factory
against these ceilings; this section exists because the arithmetic turned out not to be close enough
to need one before the question could be answered. If #48 lands a figure that disagrees with what
follows, #48 is right and this section is wrong.

`rf-reactor-energy` declares `fuel_value = "1MJ"`, so one unit of it *is* a megajoule and the fluid
rates on the power side are tiny. `rf-heater` crafts 5 units of `rf-d-d-plasma` per 2 seconds at
speed 1.

| link | what crosses it | demand | ceiling on one connection | headroom |
|---|---|---|---|---|
| `rf-heater` → `rf-reactor` | plasma, 2.5 units/s | 0.042 units/tick | 100 flush, 51 at 20 pipes | **~1200–2400×** |
| `rf-reactor` → one `rf-heat-exchanger` | reactor energy, 40 units/s at 40 MW | 0.67 units/tick | 100 flush, 51 at 20 pipes | **~75–150×** |
| `rf-reactor` → four exchangers | 160 units/s | 2.67 units/tick | 100 flush, 51 at 20 pipes | **~19–37×** |

One flush connection carries **6 000 units/s, which at 1 MJ a unit is 6 GW of reactor energy**. The
four-exchanger build a player actually runs asks for 160 MW of it. Nothing on the power side is
within two orders of magnitude of a ceiling, and adding connections or removing pipes cannot buy
anything that is not already free.

The plasma side is stronger still, and for a second reason: reactors share plasma through
`input-output` boxes, so by the section below they are one segment and have no transfer limit
between them *at all*. Only the heater's link into that pool is a real boundary, and it runs at
0.04% of it.

**So the 1.1 geometry answers a question this mod does not have.** Whatever case there is for a
15-wide heat exchanger butted flush against the reactor — and there is one, about how the machines
look and how legible the reactor-to-exchanger relationship is — it is not a throughput case, and
#44/#45 should not be argued as though it were.

Two caveats on the numbers above. They are the *current* recipe and consumption figures, which
#44/#45 may move; a hundredfold rebalance would be needed to matter, but the arithmetic is a
division and worth redoing rather than remembering. And the ceiling is the full-source, empty-sink
one, so a real link at a realistic fill level sits lower — in proportion, and from this far away
that changes nothing.

## The finding that is not in the table

**An input-output fluid box at both ends is not a link at all.** Two machines whose facing boxes are
both declared `input-output` end up in *one fluid segment*, confirmed here by
`LuaFluidBox.get_fluid_segment_id` returning the same id for both ends — flush and through pipes
alike. A segment is uniform, so there is no transfer between the ends to rate-limit and none of the
figures above apply. The 100-per-connection ceiling is a property of the boundary between a segment
and a box outside it, and an input-output box is not outside it.

This is the mechanism [ADR 0011](../adr/0011-per-reactor-simulation-fluid-coupled.md) leans on when
it has reactors share a plasma pool with no connectivity code of ours, and it is now measured rather
than assumed. It also says which links can be slow *in general*: a boundary between a segment and a
box outside it can be, and two input-output boxes cannot, because there is no boundary between them.
Which of this mod's links are which is what the section above uses; whether the arithmetic there
survives a running factory is #48's.

## Method

One save, one lane per cell, nothing shared between lanes. A cell is a source machine and a sink
machine joined by N connections through D pipes.

Both ends are unbounded by construction, which is the only honest way to measure a link:

1. **Every tick the source's box is written full from Lua and the sink's is emptied to zero.** A Lua
   write is not rate-limited, so neither end can be what runs out, and the link sees a permanent
   100%-to-0% differential — the largest it will ever face.
2. **What the sink held before being emptied is that tick's transfer.** Summed over the window and
   divided by it, that is a sustained rate rather than an instantaneous one.
3. **The source's loss is accumulated separately over the same window.** In steady state the two
   must agree, and the script fails the cell if they differ by more than 2% — a disagreement means
   the pipes in between were still filling and the window was inside the transient.

The machines are **boilers**, which is neither incidental nor merely convenient. The link this
exists to measure is a reactor's output box feeding a heat exchanger's input box, and both of those
are boilers. The first attempt used storage tanks and Factorio rejected the prototype outright —
*"Pipeline entities do not support directional connections"* — which is the engine saying that a
tank's box joins the segment its pipes belong to. A rig built from tanks would have put both ends of
every link in one segment and measured nothing, exactly as the input-output control does on purpose.

Neither boiler ever runs: both are given an electric energy source and the map has no power network,
so they sit at zero energy and convert nothing. That matters for the sink, whose input box is full of
precisely the water being counted and which would otherwise boil some of it away before the count.

The entities are 3×5 with their connections two tiles apart, so that the pipe runs belonging to
neighbouring connections stay separate segments instead of merging into one and turning a sweep over
parallel links into a sweep over one wide one.

### The rig is not the bottleneck, and the run proves it

**Neither end can run dry or back up by construction**, which is stronger than checking that neither
did: the source is rewritten full and the sink emptied on *every* tick, so one tick's transfer would
have to equal a whole box before either bound. At the top rate measured, a tick moves 299 units
through a 25 000-unit box — about 1.2% of it. The script gates on this anyway (least the source ever
held, most the sink ever held), but that gate is a backstop against some future version where a link
is orders of magnitude faster, not the argument for this one.

The argument is these, of which the first two are gated by the script and throw rather than printing
a caveat:

- **`nolink`** — the same cell with the sink moved three tiles clear and no pipes. Transfers exactly
  zero. If anything crossed it, fluid would be arriving by some path that is not the link and no
  other number in the run would mean anything.
- **`cap2`** — two cells repeated with twice the fluid-box volume. The box is the one ceiling a Lua
  refill cannot lift; doubling it moved the rate by nothing. **This is the demonstration that
  carries the weight**, because it is the only one that could have come out the other way.
- **linearity** — the measured rate is proportional to connection count across the whole range, and
  the 0.4% it falls short is accounted for to the digit by the fill-ratio arithmetic above. An end
  that was saturating would flatten the axis instead, and nothing flattens. Read off the table
  rather than gated, because a Factorio version in which connection count genuinely stopped
  mattering would fail such a gate for the right reason.

The **`io`** control is *not* one of these, despite being easy to mistake for one. It establishes
what an unlimited link looks like, not what a fast one does: a merged pair has no transfer to
rate-limit, so it reports no rate at all and demonstrates no ceiling. It is gated only on merging —
a run where those two ends did not end up in one segment has lost the claim it exists to make.

### What it does not measure

One fluid, `water`, at one temperature, and both ends pinned at the extremes. Nothing here says what
a link carries at a realistic fill level, only what it carries at the maximum — and the fill-ratio
arithmetic above says the realistic figure is strictly lower, in proportion. Nor does it measure any
link of this mod's: the ceilings are engine numbers, and where they are set beside this mod's own
rates above, that is division rather than measurement. #48 is the measurement.

Every rate here is per *fluid box*, measured on boilers. Whether a differently-typed entity's box
carries a different number is untested. So is whether the 100 is a constant: the flush case has no
pipe in it at all and still gives 100, so it is at least not the pipe's volume, but nothing here
pins down what it is.

### Sources

`scripts/bench-fluid-links.ps1`, run 2026-08-16 against Factorio 2.0.77 (build 84539) on Windows.
Three invocations, each named beside the table it produced. The engine behaviour is checked against
[`LuaFluidBox`](https://lua-api.factorio.com/2.0.77/classes/LuaFluidBox.html) at 2.0.77 —
`get_fluid_segment_id` is what makes the merge visible rather than inferred.

The predecessor geometry quoted at the top is read from Realistic Fusion Power's own prototypes; see
[`port-and-original-inspection.md`](port-and-original-inspection.md).

This mod's own rates are read from its prototypes as they stand on 2026-08-17:
`rf-reactor-energy`'s `fuel_value` from `RealisticFusion/prototypes/fluids.lua`, the exchanger's
`energy_consumption` and the reactor's and exchanger's fluid boxes from
`RealisticFusion/prototypes/entities.lua`, and the heater's output from the `rf-plasma-heating`
recipe in `RealisticFusion/prototypes/recipes/`. The four-exchangers-per-reactor case is the build
Truls played on 2026-08-16, not a designed ratio.

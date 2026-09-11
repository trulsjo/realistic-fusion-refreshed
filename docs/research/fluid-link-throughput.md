# What a fluid link carries in 2.0

How much fluid crosses from one machine to another, against how many connections join them and how
many pipes sit in between
([#47](https://github.com/trulsjo/realistic-fusion-refreshed/issues/47)).

Measured against **Factorio 2.0.77 (build 84539)** by `scripts/bench-fluid-links.ps1`. The script is
committed rather than the numbers alone, because this is a fact about a version of the engine and
the next version is entitled to a different one. Re-run it before quoting any figure here against a
newer build.

> **No pipe carries reactor energy** since
> [#86](https://github.com/trulsjo/realistic-fusion-refreshed/issues/86) shipped
> [ADR 0018](../adr/0018-energy-is-contained-and-no-pipe-carries-it.md)'s item 1 on 2026-09-07, so
> read the **flush** column for that leg and the pipe columns for plasma, which is still a pipe run;
> the joint itself is measured in [`bolted-joint-throughput.md`](bolted-joint-throughput.md).

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

Measured, by `scripts/bench-mod-links.ps1`, which builds a heater bank, a reactor and four heat
exchangers bolted in a row off the reactor's south energy face, and reads the fluid out of the
running game ([#48](https://github.com/trulsjo/realistic-fusion-refreshed/issues/48)). Not derived:
the derivation is available from `fuel_value` and the reactor's output, and it rests on the same
equilibrium assumptions #37 is open about. An earlier revision of this section did exactly that and
came out a factor of two optimistic on the energy link.

**Re-measured 2026-09-11 against Factorio 2.0.77 (build 84539)** — 360 000 ticks at 6 000 per
window, D-D, four exchangers, three pipes on the plasma link and none on the energy leg — with the
reactor holding 999.8 of its 1 000 units of plasma at 5.347×10⁸ °C. The run is gated on rate,
temperature *and* plasma inventory having each stopped moving across the last two windows, and on
the meter having counted the ticks the update cadence predicts.

| link | arrangement | carries, while flowing | its ceiling | headroom |
|---|---|---|---|---|
| heater → reactor (plasma) | output into **input-output** | 0.0968 units/tick | 49.9 units/tick | **~516×** |
| reactor → exchangers (energy) | output into input, **bolted** | 1.6768 units/tick | 50–100 units/tick | **30× to 60×** |

Sustained over every tick rather than only the ticks fluid was seen moving, those are 0.0320 and
1.3974 units/tick; the higher "while flowing" figure is quoted above because it yields the *smaller*
headroom. At 1 MJ a unit the energy link is carrying **83.8 MW**, and one connection would pass
between 3 and 6 GW. The plasma ceiling is this note's own measured control below, 49.9 units/tick on
one connection; `bench-mod-links.ps1` prints a wider 465× to 517× because its constant carries a
45-unit band bottom that nothing here measures.

> Measured 2026-08-17 at 81 MW, re-measured 2026-09-11 at **83.8 MW** after
> [#215](https://github.com/trulsjo/realistic-fusion-refreshed/issues/215) — both figures sustained.
> The energy leg was a vanilla pipe run then and is a bolt now, and the plasma settles 22% cooler, at
> 5.347×10⁸ °C against 6.88×10⁸. **Why the rates moved is
> [#225](https://github.com/trulsjo/realistic-fusion-refreshed/issues/225)**, which is open and has
> the series.

**Neither link is within an order of magnitude of anything.** The reactor and the exchangers were
built as a real chain and again with the exchangers replaced by the rigs' categorised energy feed,
which removes reactor energy as fast as it arrives — the most this mod could ever ask of that link,
whatever is plumbed downstream. **Both cells returned the same number to every digit reported**, so
at this tier the exchangers throttle nothing and 83.8 MW is simply what the reactor makes. The row
says why: all four machines worked, their energy boxes holding 0.4, 0.4, 0.3 and 0.3 units of 200 —
four 90 MW exchangers against a reactor selling 83.8 MW, so nothing accumulates anywhere and the
reactor is the constraint rather than the joint.

**At the D-T tier they do bound it**, which is why the sentence above names its cell:
[`bolted-joint-throughput.md`](bolted-joint-throughput.md) runs this same rig on `rf-d-t-plasma` with
eight exchangers and the chained row takes **320.0 MW** where an unthrottled feed on the same reactor
takes **1 195.4 MW** — and the conclusion survives either way, 1 195 MW being a fifth of one
connection's 6 000.

**So the 1.1 geometry answers a question this mod does not have.** Whatever case there is for a
15-wide heat exchanger butted flush against the reactor — and there is one, about how the machines
look and how legible the reactor-to-exchanger relationship is — it is not a throughput case, and
#44/#45 should not be argued as though it were.

### The plasma link is a third arrangement, and it needed measuring separately

The heater's box is output-only and the reactor's is `input-output`, which is neither row the matrix
above sweeps. It is not the merged case either — only one end is in the segment, so a boundary
survives. Measured as its own control:

| arrangement | 1 connection | 3 connections |
|---|---|---|
| output → input | 100 units/tick | 299 units/tick |
| output → **input-output** | **49.9 units/tick** | **75.1 units/tick** |

So it carries about half as much per connection, and — unlike output-into-input — **it does not
scale with connection count**. Both figures reproduce across flush and one pipe to four digits.
Neither is explained here; they are recorded because quoting the plasma link against the 100 would
have been quoting it against a ceiling twice too high.

### One thing that is not about throughput

The reactor settles at **83.8 MW of reactor energy** on a real heater bank. #37 records a larger
figure for *fusion* power with plasma kept full by an infinity pipe, and the two are not the same
quantity — `capture_efficiency` is 0.85 and the fluid output is what leaves the plasma, not what
fuses in it. (**The 133 MW this used to quote is a pre-#52 figure**, from before the radiation term,
and `bench-mod-links.ps1`'s own `-Exchangers` help strikes it for the same reason; re-deriving it is
#37's, so no number is quoted in its place.) But part of the gap is real and worth knowing: a heater
injects plasma at 10⁶ °C, so **refuelling a running reactor cools it**, and a reactor fuelled by
machines settles cooler than the same reactor fuelled by an infinity pipe. That belongs to #37 rather
than here.

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

This mod's own rates are measured by `scripts/bench-mod-links.ps1`, run 2026-09-11 against the same
build, at 360 000 ticks with 6 000 per window — the same length and the same window as the
2026-08-17 run it replaces, whose window was the script's default of the day and is unchanged since.
The prototype values it can be checked against, as they stand that day:
`rf-reactor-energy`'s `fuel_value` from `realistic-fusion-refreshed/prototypes/fluids.lua`, the exchanger's
`energy_consumption` and the reactor's and exchanger's fluid boxes from
`realistic-fusion-refreshed/prototypes/entities.lua`, and the heater's output from the `rf-plasma-heating`
recipe in `realistic-fusion-refreshed/prototypes/recipes/`. The four-exchangers-per-reactor case began
as the build Truls played on 2026-08-16 rather than as a designed ratio, and is now a deliberate
over-provision: four 90 MW machines put 360 MW of demand against a reactor selling 83.8 MW, so the
link is measured against the reactor rather than against the bank. Truls kept it at four on
2026-09-10 when #227 took the exchanger from 40 MW to 90, on the grounds that raising each machine's
demand makes the switch more over-provisioned rather than less; `bench-mod-links.ps1`'s
`-Exchangers` help records that decision.

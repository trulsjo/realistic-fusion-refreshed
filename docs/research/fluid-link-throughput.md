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
| reactor → exchangers (energy) | output into input, **bolted** | 1.6768 units/tick | 100 units/tick | **~60×** |

Sustained over every tick rather than only the ticks fluid was seen moving, those are 0.0320 and
1.3974 units/tick; the higher "while flowing" figure is quoted above because it yields the *smaller*
headroom. At 1 MJ a unit the energy link is carrying **83.8 MW**, and one connection would pass 6 GW.

**Both ceilings are this note's own measured controls rather than the script's bands**, and that is
one argument applied to both rows. The control table below gives 100 units/tick for output into
input and 49.9 for output into input-output, each on one connection — the two arrangements these
links actually are. `bench-mod-links.ps1` prints wider bands, 30× to 60× and 465× to 517×, because
its constants carry floors of 50 and 45: the 50 is the end of a long pipe run, which
[#86](https://github.com/trulsjo/realistic-fusion-refreshed/issues/86) removed from this leg
altogether, and the 45 nothing here measures at all. The 49.9 is also the smaller of the two figures
its control measured — output into input-output does not scale with connection count, 3 connections
carrying 75.1 — so it is the conservative pick by the same rule that quotes the flowing rate above.

> Measured 2026-08-17 at 81 MW, re-measured 2026-09-11 at **83.8 MW** after
> [#215](https://github.com/trulsjo/realistic-fusion-refreshed/issues/215) — both figures sustained.
> The energy leg was a vanilla pipe run then and is a bolt now, which is why its figure could not
> have held. **Why every rate moved is the section below.** Three named commits are the simulation
> changing under a rig that did not — `c794fc5`, `c2cb7e3` and `48c43c0` — and the remaining 11% is
> the rig itself, the bolt and the re-lay being #215's, which is what the sentence above says.

### Every figure here is measured on a fully-researched force

`bench-mod-links.ps1`'s `on_init` calls `force.research_all_technologies()`, and the comment beside
it says why: that is also the state the mod gets played in by the time a player has a reactor worth
benchmarking. So **83.8 MW is a researched reactor's figure, not a base one.** Two ladders reach it:

- **plant efficiency** ([#96](https://github.com/trulsjo/realistic-fusion-refreshed/issues/96),
  [ADR 0020](../adr/0020-plant-efficiency-is-researchable.md)) — `capture_ladder` on `M.reactor` in
  `realistic-fusion-refreshed/scripts/reactor-logic.lua` takes capture from the base 0.85 to
  **0.9375** at rung 3, which is **+10.3%** on everything the reactor sells.
- **confinement time** ([#53](https://github.com/trulsjo/realistic-fusion-refreshed/issues/53),
  [ADR 0024](../adr/0024-confinement-time-is-the-researchable-lever.md)) — `confinement_ladder` on the same
  spec takes tau from 30 s to **60 s**, which moves the equilibrium temperature and therefore
  everything downstream of it.

**The base-capture equivalent of 83.8 MW is about 76.0 MW** — 83.8 ÷ 1.1029412, which is arithmetic
rather than a measurement; no 360 000-tick run has been taken on an unresearched force. The
confinement ladder has no such divisor, because it moves a physical parameter rather than scaling an
output: a base-confinement figure has to be measured, and the one that exists is the 43.7 MW below.

### Why the rates moved, commit by commit

Answered by [#225](https://github.com/trulsjo/realistic-fusion-refreshed/issues/225). The method is
the one that ticket sets: the equilibrium lives in the pure simulation, which runs outside Factorio,
so the window was swept there at seconds per commit and the two steps it found were then bracketed by
rig runs. **Every figure in the table below is a run of this rig, not a reading of a commit message.**

| taken at | date | sustained | delivered | plasma |
|---|---|---:|---:|---:|
| `d9ece9c` | 2026-08-21 | 1.353975 u/tick | **81.2 MW** | 6.87698×10⁸ °C |
| `30e100b` | 2026-08-22 | 0.727653 u/tick | **43.7 MW** | 2.39299×10⁸ °C |
| `4df2591` | 2026-09-01 | 1.140 u/tick | **68.4 MW** | 5.346×10⁸ °C |
| `2381730` | 2026-09-11 | 1.3974 u/tick | **83.8 MW** | 5.347×10⁸ °C |

All four at 360 000 ticks, 6 000 per window, D-D, four exchangers, against Factorio 2.0.77 (build
84539). Four 40 MW exchangers on the first three rows and four 90 MW ones on the last, #227 having
landed between; the rig is supply-limited at both, which the paragraph below this table measures
again, so the bank is not what any of these rows is reading. The first two were re-run on 2026-09-12 out of a detached worktree at those commits; the
2026-08-17 row of the series this note used to carry is the `d9ece9c` row, **reproduced**: 81.2 MW
against 81, 1.353975 units/tick sustained against 1.354, 6.87698×10⁸ °C against 6.88×10⁸, and 0.0891
units/tick of plasma flowing against 0.089. One figure does not land on its old digits — the energy
link's flowing rate reads **1.6248** where 2026-08-17 recorded **1.63** — and that one is derived
rather than measured: it is the sustained rate divided by the 5/6 of ticks the meter counts, and
1.353975 ÷ 0.833333 is 1.62477 exactly. The sustained figure both dates agree on is the measured one.
So nothing about the rig or the method drifted across the window, which is what makes the two steps
below attributable to the simulation.

**`c794fc5` — the radiation loss term ([#52](https://github.com/trulsjo/realistic-fusion-refreshed/issues/52)),
2026-08-21.** 81.2 MW → 43.7 MW, 6.877×10⁸ °C → 2.393×10⁸. Its own commit message says the D-D tier
falls from Q 2.14 to Q 0.32; this is that fall arriving at the fluid box. **Not a defect** — a plasma
that radiates is the physics the mod had been missing.

**`c2cb7e3` — the confinement ladder ([#53](https://github.com/trulsjo/realistic-fusion-refreshed/issues/53)),
2026-08-24.** 43.7 MW → 68.4 MW, back to 5.346×10⁸ °C. It reaches this rig because the rig researches
everything, so the reactor runs on rung 3's 60 s rather than the shipped 30 s. Located in the pure
simulation, which puts the settled temperature at 2.4222×10⁸ °C at every commit from `c794fc5` to
`30e100b` and at 6.4830×10⁸ from `c2cb7e3` to `4df2591` — one step, at that commit, with nothing
moving on either side of it. **Not a defect either**: it is the ladder working as designed on a force
that has climbed it.

**What the sweep covers, exactly.** It settles the simulation, so it sees a change to
`reactor-logic.lua` and is blind to a change to a prototype the rig also reads — a fluid box's volume,
a `fuel_value`, a recipe's output. **Thirty-two commits were swept**: all twenty-one in the window
that touch either mod's `scripts/`, nine anchors before it running back to the commit the 2026-08-17
figures were taken at, and the window's two endpoints, `4df2591` and `2381730`, which touch the rig
rather than the simulation. Eight of the twenty-one were added after review caught the first count
claiming a coverage it did not have; all eight are documentation commits and all eight land on one of
the two plateaus below, so the answer is unchanged and the claim is now true. What closes the gap is that the two rig
runs bracket the window in the real game and the composite they give is the fall that was asked
about: a third mover hiding in the prototypes would have to leave that composite intact.

**Net across THE TWO STEPS: −22.3% on temperature and −15.8% on delivered power** — 81.2 MW to
68.4 and 6.877×10⁸ °C to 5.346×10⁸. They run in opposite directions and the fall is what is left of
them, which is why the movement read as a single unexplained drop rather than as two named ones.

**Across the whole table it is −22.2% and +3.2%**, because the last row is ten days later and two
more things have happened by then. Those two figures are not interchangeable and the sign of the
second one is not the same, so say which span is meant.

**`587f699` is eliminated, and nothing should re-propose it.** It was the only named candidate in
three passes of triage. Its own commit message rules it out: moving the energy sale from 165 °C to
550 takes *the unaccounted output from 6.7 W to 1.9 W*, and *a running reactor converts nothing
whatever this field says*, measured under [#101](https://github.com/trulsjo/realistic-fusion-refreshed/issues/101)
across every target to 10⁶ °C. Watts cannot move 22% of a plasma temperature. The two rig runs above
bracket it directly as well: it sits between them, and the whole step is already accounted for by the
commit one day earlier.

**The plasma rate is the same two commits and reads oddly because they cross.** Flowing, all at
360 000 ticks: 0.0891 u/tick at `d9ece9c`, 0.0536 at `30e100b`, 0.0968 at `4df2591` and again at
`2381730`. The fall and the recovery overshoot, so the published series — 0.089 on 2026-08-17 against
0.0968 since — shows a *rise* where the temperature shows a fall. Sustained goes 0.0408 → 0.00893 →
0.0319 → 0.0320 across the same four and falls on net, which is the bound that tracks what the plasma
actually burns; the flowing bound is sustained divided by the fraction of ticks the meter counted,
and the refuelling cadence moved with the burn.

**Quote the plasma figures at a stated run length or not at all.** Unlike the energy rates, they do
not converge to the same number at 126 000 ticks: today's 126 000-tick run reads 0.0675 flowing and
0.0333 sustained against the 360 000-tick run's 0.0968 and 0.0320. Every plasma figure in this note
is the 360 000-tick one.

**The last leg, 2026-09-01 to 2026-09-11, is +22.5% and is two things, only one of which is here.**
68.4 MW to 83.8. The plant-efficiency ladder below accounts for +10.3% of it, which puts 68.4 at
75.4; the remaining **+11.1%** is the rig changing rather than the simulation — the energy leg
stopped being a vanilla pipe run and became a bolt, and the layout was re-laid, both
[#215](https://github.com/trulsjo/realistic-fusion-refreshed/issues/215)'s and neither ever claimed
to be neutral. This note's own blockquote above says the earlier figure "could not have held" for
exactly that reason. **That residual is not attributed to a commit here** and is not this section's
to attribute: #225 was opened about the 22% temperature fall and the plasma rate step, which are
named above, and #215 owns the leg that changed the rig underneath the measurement.

**`48c43c0` — the plant-efficiency ladder, 2026-09-09 — is the simulation's part of that leg, and it
is +10.3%.**
Measured at 126 000 ticks on 2026-09-11, one run with the ladder researched and one without:
**86.3862 MW against 78.3235 MW**, a ratio of **1.1029410** against the ladder's own arithmetic
0.9375 ÷ 0.85 = **1.1029412** — seven significant figures. The flowing bound gives the same ratio,
which is the check that the two bounds are read consistently. The un-researched run reproduces the
78.3 MW that [`bolted-joint-throughput.md`](bolted-joint-throughput.md) recorded on 2026-09-08, the
day before that commit. **The plasma is untouched by it**: temperature and plasma rate are identical
to the last digit across the two runs, so the ladder moves only what the reactor sells.

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

The reactor settles at **83.8 MW of reactor energy** on a real heater bank. #37 records a figure for
*fusion* power with plasma kept full by an infinity pipe, and the two are not the same quantity —
`capture_efficiency` is 0.85 and the fluid output is what leaves the plasma, not what fuses in it.
(**The 133 MW this used to quote is a pre-#52 figure**, from before the radiation term, and
`bench-mod-links.ps1`'s own `-Exchangers` help strikes it for the same reason. Re-deriving it is
#37's, so no number is quoted in its place — **and with none quoted, this paragraph does not say
which quantity is the larger**, only that they are different ones.) But part of the gap is real and
worth knowing: a heater
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
build, at 360 000 ticks with 6 000 per window — the same length as the 2026-08-17 run it replaces,
and the same window, that being the script's default at both dates (checked at the two commits, not
across every one in between; the 2026-08-17 row never recorded its own).
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

# What a simulated reactor costs — the first measurement

The first UPS reading on v1's reactor simulation, taken as soon as one existed
([#24](https://github.com/trulsjo/realistic-fusion-refreshed/issues/24)).

**This is a smoke test, not the discharge of [ADR 0005](../adr/0005-real-time-fusion-simulation.md)'s
obligation.** That one is the measurement against the full reaction set on a real factory
(#34). The point of taking a reading now is that a disaster found here is found eleven tickets
before it would otherwise surface. Nothing here says the mod is fast on a megabase; it says the
simulation is not the thing that would make it slow.

It also settles, for this project, the only prior number that existed: the redesign author's
**~45 ms per reactor**, examined in [`redesign-runtime-cost.md`](redesign-runtime-cost.md). v1
measures **about 9 µs** per reactor before throttling — five thousand times less — and 1.4 µs
after. That note predicted something like this on the grounds that v1 has no GUI in the per-tick
path; the prediction held.

> **Superseded in part by #25.** Every figure below is the simulation alone, measured before
> reactors reported themselves. Adding the status line and the two circuit signals took the
> throttled figure from **1.39 µs to 1.80 µs** per reactor — 2.16% of a tick at 200 reactors,
> against 1.7% here. The method and every conclusion still stand; only the headline number moved,
> and it moved for a feature rather than for a regression. See *Observability* at the foot of this
> note.

## Method

`scripts/bench-reactors.ps1`, which exists so that #34 can repeat this rather than invent its own.
Run it with no arguments for the throttled table; the unthrottled one needs `UPDATE_INTERVAL` set
back to 1 first, and the pooled figures need `-Pooled`.

It builds a rig of *n* reactors in a headless save and benchmarks it, for several *n*. Three things
make the numbers mean something:

1. **`--benchmark-verbose` reports per-tick timings by category, in nanoseconds.** `scriptUpdate`
   is the control stage — every mod's Lua and nothing else — so our cost is isolated from the
   engine's without needing a baseline at all. `luaGarbageIncremental` is reported beside it
   because collecting the tables the step allocates is charged to its own stage, and would
   otherwise hide. `fluidFlowUpdate` because the reactor is a boiler on a fluid segment, so part
   of what this mod costs is charged to the engine rather than to us.
2. **Every run builds the same map.** The power, the flattened ground and the generated chunks are
   sized for the largest *n* and built identically at every *n*, including *n* = 0. Only the
   reactors differ, so a difference between runs is reactors.
3. **Mean and median are both reported.** The mean is the cost — over thousands of ticks it is
   what UPS spends. The median is what a tick feels like, and is the honest description of
   per-tick work, because a run carries spikes an order of magnitude above the typical tick. They
   separate the moment the mod stops updating every tick, which is why per-reactor cost is taken
   from the mean.

The reactors are held at 6×10⁸ °C and full by an infinity pipe, which is what a reactor whose
heater keeps up looks like. This matters more than it sounds: an **empty** reactor returns early
from the simulation step, and a rig that let its reactors run dry would measure the early return.
They also sit on a real electric network — not for that reason, since an unpowered reactor runs
the whole step with its heating clamped to zero and costs exactly the same, but because a reactor
that cannot hold its temperature is not the thing worth measuring. The save is written the moment the rig is built, so the start of each run is spent filling:
about 11 ticks for an isolated reactor, and around 220 of the 1000 for a pooled row, whose segment
is twenty times larger and fed from one end. Cost is barely affected — the step runs on any plasma
at all, not only on full plasma — but a fifth of each pooled run is below full density, which is
worth knowing before reading anything into pooled-versus-isolated at the margin.

The script refuses to report a number unless the rig's own log says every reactor was present, hot
**and on an electric network** when it last checked. That guard exists because none of the ways this
rig can go wrong — a reactor that never got power, one that ran dry, one the mod never registered —
crashes anything. They just quietly produce a smaller number.

> **The guard earned its keep, and the rig had to be rebuilt around it
> ([#49](https://github.com/trulsjo/realistic-fusion-refreshed/issues/49)).** Every distance in the
> rig — cell pitch, where the feed pipe goes, where the power sits — was written for the 3×2 reactor
> that existed when it was written, and went silently wrong the day the reactor became 15×15
> ([ADR 0013](../adr/0013-the-reactor-is-fifteen-tiles-square.md)). Cells overlapped and the feed
> pipe sat six tiles clear of the connection it was meant to touch. Nothing errored; the reactors
> placed and stayed cold, and the "every reactor hot" gate refused to report — which is the gate
> doing exactly its job, and it is the only reason this was caught at all.
>
> The rig now reads the reactor's footprint from its own prototype at run time and derives every
> position from it, so the next resize moves the rig with it. The power changed shape as a
> consequence: a substation reaches 18 tiles and a cell is now wider than that, so one connected
> grid is no longer available at any spacing that fits the reactor. Each cell gets its own
> substation and interface instead — built for every cell at every *n*, so it still cancels out of
> the deltas. It is a heavier rig than the one below 2026-08-15's figures were taken on:
> `electricNetworkUpdate` roughly doubled, 49.8 µs against 101 µs by median at *n* = 200.

**Machine and versions.** Factorio 2.0.77 (win64, steam), base only — no Space Age, no Quality.
Intel Core i7-9850H (6 cores, 12 threads, 2.6 GHz base), Windows 11. A laptop part from 2019, so
these are not fast-machine numbers.

## Results

1000 ticks × 3 runs per count — 3000 tick samples each — in microseconds of `scriptUpdate` per
tick, **mean, with the baseline (n = 0) subtracted**. Mean throughout: mixing it with the median
manufactures precision, and the two differ by about 10% here.

**Before throttling** — one simulation step per tick:

| reactors | scriptUpdate | per reactor |
|---:|---:|---:|
| 1 | 17.9 | 17.9 |
| 10 | 95.2 | 9.5 |
| 50 | 456.2 | 9.1 |
| 200 | 1796.8 | **9.0** |

Two earlier sweeps of the same rig gave 9.3 and 11.0 µs at n = 200. **Run-to-run variation is
around 20%**, so the working figure is **about 9 to 11 µs per reactor per tick**, and no digit
after that is real.

Scaling is linear from 10 reactors up. The much higher figure at n = 1 is the fixed cost of the
handler itself — one `on_nth_tick` call, one `pairs` loop — divided by one reactor, not something
a reactor costs.

At 200 reactors that is **1.8 ms per tick, about 11% of the 16.67 ms budget**, and 86% of the
entire game update (1.80 ms of 2.09 ms) — a rig has nothing else in it to compete. 200 reactors is
around 18 GW, which is megabase scale; a large but ordinary fusion build of 20 to 50 reactors pays
0.2 to 0.5 ms.

**Where the time goes.** 9 µs is one to two orders of magnitude more than the arithmetic in
`reactor-logic.lua` costs. The step crosses the Lua↔C++ boundary about eight times per reactor —
`fluidbox[1]` (which allocates a table), `energy` read and write, `fluidbox[2]`, `get_capacity`,
the two box writes — and that is what is being measured. **The physics is not the cost; the API is.**
Not investigated further here, and it is where a later optimisation would go.

**After throttling** to one step every six ticks:

| reactors | scriptUpdate | per reactor | share of a tick |
|---:|---:|---:|---:|
| 1 | 3.5 | 3.5 | — |
| 10 | 19.3 | 1.9 | 0.12% |
| 50 | 76.7 | 1.5 | 0.46% |
| 200 | 278.1 | **1.4** | **1.7%** |

9.0 µs against 1.4 is a factor of 6.5, where the arithmetic says it should be exactly 6 — the step
does the same work, six times less often. The excess is inside the 20% run-to-run noise.

### Re-taken 2026-08-17, on a 15×15 reactor

Every figure above was taken on 2026-08-15, when the reactor was 3×2 and before #25 added the status
line and the circuit signals. The reactor is now 15×15 and the rig was rebuilt around it (#49), so
the whole throttled sweep was re-taken. **The pre-throttle table was not**, and stays a 2026-08-15
measurement: the cadence decision it supported is long since made and rests on the Lua test, not on
it.

| reactors | scriptUpdate | per reactor | share of a tick |
|---:|---:|---:|---:|
| 1 | 12.3 | 12.3 | — |
| 10 | 34.0 | 3.4 | 0.20% |
| 50 | 112.1 | 2.2 | 0.67% |
| 200 | 492.3 | **2.5** | **2.9%** |

**The footprint costs nothing.** The simulation step reads a fluid box, an energy buffer and a
capacity; not one of those depends on how many tiles the entity covers, and the measurement agrees.
Four separate runs of the shipped code at *n* = 200 gave **1.73, 2.38, 2.45 and 2.46 µs** per
reactor. The 1.80 µs this note records for the post-#25 reactor sits inside that spread. **A reactor
that got 37 times bigger in area costs the same to simulate.**

**What did move is the confidence interval, and it is worth being honest about.** Those four runs
span 1.73 to 2.46 — a 42% spread on the same binary, same map, same machine, back to back. The 20%
figure quoted above is optimistic for runs taken in quick succession on this laptop; treat the
throttled cost as **about 2 µs per reactor, and treat any comparison finer than a factor of 1.5 as
unmeasured**. A run taken to settle a smaller difference than that needs interleaved repeats, not
one sweep.

One sample was taken with the reactor animation removed to see whether #25's successor had cost
anything, and returned **3.5 µs — higher with the feature gone**, which is not a possible causal
effect. It is quoted here only as the clearest available illustration of the noise floor, and
nothing is claimed from it.

**Sharing a fluid segment is free.** Reactors plumbed together on one run of `rf-pipe` — the way
[ADR 0011](../adr/0011-per-reactor-simulation-fluid-coupled.md) intends them to be built — cost
**8.94 µs each at n = 200 against 8.98 isolated**, measured back to back. That is a 0.4%
difference against a 20% noise floor: the same number.

The engine-side half is small in absolute terms and does not care either. `fluidFlowUpdate` at
n = 200 was 19.1 µs pooled and 18.6 µs isolated — around a tenth of a percent of a tick — and the
pooled rig carries **930 `rf-pipe` entities across 14 shared segments** where the isolated rig has
none. (The two rigs are not the same population: the isolated one needs an infinity pipe per
reactor to stay full, the pooled one needs 14, one per segment. So this is two absolute figures
that are both negligible, not a controlled comparison. The controlled comparison is the
`scriptUpdate` figure above, which infinity pipes cost nothing towards.)

**ADR 0011's central bet, that delegating sharing to the engine's fluid system costs nothing,
holds at 200 reactors on 14 shared segments.** It does not go superlinear.

Re-checked 2026-08-17 on the 15×15 rig: pooled came to **2.11 µs** per reactor at *n* = 200, against
an isolated spread of 1.73 to 2.46 on the same day. Still the same number, and now with 930 pipes
laid across a map fifteen times the area. The claim survives the resize; note only that the noise
floor above is far wider than the 0.4% the 2026-08-15 back-to-back pair resolved, so this is a
weaker confirmation than that one, not a stronger one.

**Garbage collection is not a problem.** The two-pass update allocates three tables per reactor
per tick, which was the obvious suspect. `luaGarbageIncremental` comes to 0.09 µs per reactor by
median and 0.18 by mean — one or two percent of the step.

**The instrument perturbed the measurement, and the first set of numbers was wrong because of it.**
The rig logs what the reactors are doing so the run can be trusted, and that log walked every
reactor. It costs about what the simulation step costs, it is charged to `scriptUpdate` like any
other Lua, it scales with *n*, and the *n* = 0 baseline has no reactors to subtract it against. At
one report every 100 ticks it inflated the throttled figure by 17% — 1.67 µs where the true figure
is 1.39. Reporting is now rare enough to sit under a percent, and the same trap is waiting for
anyone who adds instrumentation to #34's measurement.

## What changed as a result

`control.lua`'s `UPDATE_INTERVAL` went from 1 to **6**, ten steps a second.

**Not because 11% of a tick was unaffordable.** Because five of every six steps bought nothing:
the plasma's energy confinement time is 30 seconds, and stepping a 30-second process every 16 ms
resolves nothing that a tenth of a second misses. **Equilibrium temperature moves 0.10% between
the two cadences**, and 0.60% at one step per thirty ticks.

That figure has to be taken at equilibrium, and equilibrium is much further out than the
confinement time suggests: fusion self-heating is positive feedback, so the model is still
climbing after six confinement times. Measured at a 180-second horizon the divergence looks like
0.07%, which is the coarse steps being flattered by having had less time to accumulate error. The
test now runs to 1200 seconds, where the answer stops moving.

The in-game runs agree — 6.216×10⁸ °C throttled against 6.219×10⁸ unthrottled — but that is
**weak** evidence and is not what the decision rests on. A benchmark run is 16.7 seconds and both
runs are anchored at the temperature the rig's infinity pipe injects at, so they had neither the
time nor the freedom to diverge. The claim rests on the Lua test.

This is the mitigation ADR 0005 pre-authorised, and it is a cadence change only — one constant in
`control.lua`. `reactor-logic.lua` and `reactivity.lua` are untouched, which is what ADR 0005 kept
them isolated for.

`tests/test-reactor-logic.lua` now asserts the property the change rests on: that the settled
temperature and the energy produced per tick are the same at 1, 2, 6, 15 and 30 ticks per step, to
within 1%. It is written against the whole range rather than against the interval currently
chosen, so moving that constant again stays covered. Explicit Euler is only stable while the step
stays well inside the system's time constant, and that is now checked rather than assumed.

**The cost of coarsening** is that every reactor steps on the same tick, so the work arrives as a
spike rather than spread out. Staggering reactors across buckets would fix that and must not be
done: reactors sharing a fluid segment have to step together, or one reads a pool its neighbour
has already moved this tick.

**There is a ceiling on the interval that the physics test cannot see**, because it is a fact
about the prototype rather than about the plasma. A step draws the whole interval's heating out of
the reactor's electric buffer in one go, so 50 MW against a 10 MJ buffer runs out past twelve ticks
and the reactor is starved every step — silently, because being underpowered is a state it is
meant to have.

`control.lua`'s `check_cadence()` enforces it at `on_init`, which is the one place both numbers are
visible. Raising the interval past 12 without raising `buffer_capacity` now fails the load-check
rather than shipping a quietly crippled reactor. Verified in both directions: the check passes at
six ticks and fails at twenty, naming both numbers and the two files that can resolve it.

## A finding about fluid boxes, discovered by getting it wrong

The rig originally seeded each reactor with 1000 units of plasma — exactly its fluid box volume —
and every reactor settled at 526 within a second. It looked like the mod was losing half its fuel.

It was not. An `input-output` fluid box shares its contents with the fluid segment it belongs to,
in proportion to capacity, and a Lua write is clamped to the box before that sharing happens. So
writing the box's full 1000 into a box-plus-segment that holds 1900 leaves everything at 52.6%,
box included. Overfilling does not help; the clamp comes first. A second reactor that no Lua ever
touched split identically, which is what settled it: this is the engine's model, not the mod's.

Two things follow, and both outlive the rig:

- **`LuaFluidBox[i].amount` is the box's share, not the segment's contents.** `get_capacity(i)`
  likewise reports the segment. Anything that reasons about how full a reactor is — the tooltips
  and circuit signals of #25, the containment rules of #26 — has to know which of the two it is
  asking for.
- **A reactor is only at full density when its whole segment is full**, so under-supply shows up
  as reduced density rather than as an empty reactor, and reaction rate goes as the square of
  density. That is arguably the right behaviour, and it is worth stating out loud because nobody
  chose it.

## The full reaction set (#34) — ADR 0005's obligation

Measured **2026-08-18**, on Factorio 2.0.77, with the same script and the same counts as everything
above. This is the measurement [ADR 0005](../adr/0005-real-time-fusion-simulation.md) has been waiting
for since the decision to simulate was taken.

`scripts/bench-reactors.ps1 -Mixed` runs all four of ADR 0010's reactions at once — D-D and D-T in
`rf-reactor`, D-He3 and He3-He3 in `rf-aneutronic-reactor` — one reaction per row of the grid. By row
rather than round-robin, because a pooled row is a single fluid segment and a segment carries one
fluid; cycling by index would build something that cannot exist. The consequence is that counts below
the grid width are **not** mixed: at *n* = 1 and *n* = 10 every reactor is in row 0 and burns D-D. That
turns out to be useful rather than a nuisance — see the cross-check below.

The rig now reports what each reactor is actually burning, and the script refuses to report a mixed
figure unless four distinct plasmas were present. That is not ceremony: two of the four reactions run
in the *same entity*, so counting reactors, or even counting entity types, cannot tell D-D from D-T. At
*n* = 200 it logged `rf-d-d-plasma:60, rf-d-t-plasma:50, rf-d-he3-plasma:45, rf-he3-he3-plasma:45`.

### Results

`scriptUpdate` mean, baseline subtracted, µs per reactor. 1000 ticks × 3 runs per count.

| reactors | all four reactions | D-D alone |
|---:|---:|---:|
| 1 | 10.0 | 23.3 |
| 10 | 4.1 | 4.4 |
| 50 | 2.9 | 6.3 |
| 200 | **2.95** | **6.88** |

Repeated at *n* = 200, same machine, same session. Every mixed run had the identical grid and the
identical split (`d-d:60, d-t:50, d-he3:45, he3-he3:45`), so these are repeats of one measurement:

| run | mixed | D-D alone |
|---|---:|---:|
| full sweep `0,1,10,50,200` | 2.95 | 6.88 |
| `0,200` | 2.85 | 6.30 |
| `0,10,200` | 4.04 | — |

**The third mixed run is 40% above the first two, and that is this page's own 20–42% spread rather
than anything about the mod.** Its *baseline* moved with it — 9.4 µs of `scriptUpdate` at *n* = 0
against 6.4 and 5.0 — and its `wholeUpdate` median went from 403 and 291 µs to 480, which is a
machine doing other work, not a reactor costing more. Recorded rather than dropped, because dropping
the inconvenient repeat is how a 42% spread turns into a false precision.

**At 200 reactors the full reaction set costs about 3 µs per reactor — call it 0.6 to 0.8 ms per tick,
3.4% to 4.9% of the 16.67 ms budget.** A large but ordinary build of 20 to 50 reactors pays well
under 1%.

### The surprise: the full set is CHEAPER per reactor than D-D alone

D-D on its own costs **roughly twice** what the mixed set does — 6.3 to 6.9 µs against 2.9 to 4.0.
That is the opposite of the direction everyone expected: item 2 of *What this does not close* above
predicted the per-reactor cost simply "not to grow" as reactions were added, and instead adding them
lowered the average.

**Taken at its weakest the ratio is 6.30 / 4.04 = 1.56**, which clears this page's "treat anything
finer than 1.5 as noise" bar and not by much. The finding does not rest on that margin, though — it
rests on the mechanism below and on the *n* = 10 cross-check, both of which are independent of how
noisy any single pair of runs was.

The mechanism is in `control.lua`: D-D is the only reaction that breeds by-products, and
`result.products` is computed **every step whether or not a collector exists** — deliberately, so that
bolting a collector on later starts collecting immediately with no backlog. D-T, D-He3 and He3-He3
produce no such table. In a mixed rig only a quarter of the reactors pay for it, so the average falls.
`luaGarbageIncremental` agrees: 0.51 µs per reactor D-D-only against 0.17 µs mixed, a 3× difference in
exactly the stage that collects per-step tables.

**The cross-check that makes this attributable rather than a story.** At *n* = 10 both rigs are D-D
only — the mixed rig has not reached row 1 yet — and they agree: **4.1 µs against 4.4**. The two rigs
are therefore measuring the same thing when they contain the same thing, and the divergence at *n* = 50
and above arrives exactly when the other three reactions do.

So **the worst case is not the full reaction set; it is a player who has only unlocked D-D.** That is
also the earliest game state, on the smallest bases — 6.9 µs per reactor matters far less at the ten
reactors an early D-D base has than it would at two hundred.

### Compared against the early reading

Same script, same counts, same statistic. The D-D figure is the one that is comparable, and it has
moved:

| when | configuration | µs per reactor at *n* = 200 |
|---|---|---:|
| 2026-08-15 | D-D, before throttling | 9.0 |
| 2026-08-17 | D-D, throttled, post-#25 | 1.80 |
| 2026-08-17 | D-D with by-products (#27) | 2.85 |
| **2026-08-18** | **D-D alone** | **6.3 – 6.9** |
| **2026-08-18** | **all four reactions** | **2.9 – 4.0** |

**D-D alone has roughly doubled since #27's 2.85 µs, and this note does not explain it.** Two runs each
way put it well outside the 1.5× this page says to treat as noise, so it is a real change rather than a
reading. What landed in between is #30's lithium blanket, #31's aneutronic tier and the work on
radiation loss; which of them costs what was not isolated here, and attributing it is the kind of thing
[#39](https://github.com/trulsjo/realistic-fusion-refreshed/issues/39) exists for.

### Verdict

**Acceptable at the shipped cadence. No further throttling.**

`UPDATE_INTERVAL` stays at 6 — ten simulation steps a second, the value #24 chose. ADR 0005
pre-authorises moving to a coarser cadence if measurement showed the cost was too high; it does not.
3.4% of a tick at megabase scale, and under 1% at the scale anyone will actually build, is not a
budget worth spending the physics on. Nothing about the rate computation was touched, so the fallback
remains available and remains a one-line change.

The number to quote is **about 3 to 4 µs per reactor per tick with all four reactions, and about 7 µs
for a D-D-only base**, and no digit after that is real. Three mixed runs spanning 2.85 to 4.04 are why
the first figure is a range rather than a number.

## What this does not close

1. ~~**ADR 0005's obligation stands.**~~ **Discharged 2026-08-18** — see *The full reaction set*
   above. **But it is still a rig, and that half of #34 was not done.** No belts, no trains, no
   biters, one surface. The ticket asked for "a real factory at scale"; what was measured is 200
   reactors on flat ground with power and nothing else. A factory's own UPS cost is not this mod's,
   but it competes for the same 16.67 ms, and a reactor's cost could interact with a loaded engine
   in ways a bare rig cannot show. The per-reactor figure is the mod's contribution and is sound;
   "what the game feels like on a real base with this mod" is not answered here and needs a real
   save, which this project does not have.
2. ~~**Only one reaction exists.**~~ **All four now do, and they were measured together.** The
   expectation recorded here — that per-reactor cost would not grow as reactions were added — held,
   and then some: the average *fell*, because only D-D breeds. What is now open is the opposite
   question, why D-D alone costs 2.3× the mix and why it has doubled since #27.
3. **Nothing was measured with a player watching.** Rendering, GUI and the interface #25 will add
   are all absent. The redesign's 45 ms is best explained by exactly that kind of cost, so v1's
   interface work should be measured when it lands rather than assumed free.
4. **The 20% run-to-run variation was not chased down.** Thermal throttling on a laptop part is
   the obvious candidate. It is wide enough that a future comparison should re-run the baseline on
   the same machine in the same session rather than compare against the numbers on this page.
5. **The API cost per crossing was not isolated.** The claim that boundary crossings dominate the
   step follows from the arithmetic being far too cheap to explain 9 µs; it was not measured
   crossing by crossing.

### Sources

- `scripts/bench-reactors.ps1` — the measurement, including the rig it builds.
- `tests/test-reactor-logic.lua` — the cadence-insensitivity check the throttling rests on.
- Decisions this bears on: [ADR 0005](../adr/0005-real-time-fusion-simulation.md),
  [ADR 0011](../adr/0011-per-reactor-simulation-fluid-coupled.md).
- The prior claim it replaces: [`redesign-runtime-cost.md`](redesign-runtime-cost.md).

## Observability (#25)

Reactors now publish a status line and two circuit signals. That is per-reactor work in the tick
path, so it moves the number this note exists to record.

| | per reactor | share of a tick at n = 200 |
|---|---:|---:|
| simulation alone | 1.39 µs | 1.7% |
| reporting on every simulation step | 3.51 µs | 4.2% |
| **reporting every fifth step (shipped)** | **1.80 µs** | **2.16%** |

**Publishing costs about five times what simulating does.** Writing a combinator section and a
status table is expensive next to the arithmetic it reports — 2.1 µs against 0.4 — which is the
same lesson as the rest of this note: the cost is in crossing into the engine, not in the physics.

**Caching unchanged values was tried and abandoned.** The obvious fix is to skip a write when
neither integer has moved. It returned 15%, and the reason it returned so little is worth writing
down: the plasma temperature is a float that moves in its last digits every single step, and at
6e8 degrees even a millionth of a percent is hundreds of degrees, so the emitted integer almost
never repeats. The cache almost never hit. It was reverted rather than kept for 15% and a storage
table per reactor.

**Reporting five times less often returned 80% of the loss**, and costs a player nothing: half a
second of staleness on a gauge no one can read at 10 Hz, and no factory control loop reacts faster
than that. `REPORT_EVERY` in `control.lua` is the one number to change if a later tier wants a
faster gauge, and this table is what it costs.

## D-D by-products (#27)

Measured 2026-08-17, on shipped code with the breeding added: **2.85 µs per reactor**, 3.42% of a
tick at n = 200.

**This is not a claim that breeding is free, and not a claim that it costs anything either.** The
four runs of the preceding shipped code returned 1.73, 2.38, 2.45 and 2.46 µs, and this note has
already recorded a run-to-run spread of 42% — so 2.85 against a previous high of 2.46 is 1.16×, and
the section above says plainly that differences finer than about 1.5× are unmeasurable here without
interleaved repeats. It sits inside the noise. Anyone who needs the real number should take it as
an A/B on one machine in one sitting rather than reading it off this table.

What was added to the tick path is one table of two entries per reactor per step, built in
`reactor-logic.step()` and handed back with the rest of the result. It is worth knowing that the
benchmark's reactors have **no collector bolted to them**, so `deposit()` never runs and the
allocation is the whole of what is being measured — a rig with collectors would pay two fluidbox
writes per reactor on top, and by the lesson above those would cost more than the arithmetic does.

The allocation is avoidable: `step()` could fill a caller-owned table instead of returning a fresh
one. It was left alone, because doing it would put an out-parameter into the one module in this mod
that is pure and testable outside Factorio (ADR 0005), in exchange for a saving that this
measurement is not sharp enough to see.

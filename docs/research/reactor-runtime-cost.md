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

**Which configuration a figure came from, which this note now has to say
([#62](https://github.com/trulsjo/realistic-fusion-refreshed/issues/62)).** The rig builds
reactors, power and a plasma feed; every *fitting* is a switch, and every switch is off by default.
So every figure in this note above *[Collectors attached](#collectors-attached-62)* at the foot of
it was taken on reactors with **no isotope collector and no lithium blanket** — reactors that
compute their by-products and then vent them. `control.lua` computes `result.products` either way
and only writes a collector's fluid boxes when one is attached, so `deposit()` had not executed in
a single measurement this project had taken, and `blanket_breed()` had not either. Three
configurations now exist and figures are labelled by them:

| label | rig | what runs |
|---|---|---|
| **vented** | no arguments | the simulation, the by-product table computed and discarded |
| **collected** | `-Collectors` | the above, plus the collector lookup and `deposit()`'s two fluid-box writes |
| **blanketed** | `-Collectors -Blankets` | the above, plus the headroom read, `blanket_breed()` and its lithium withdrawal |

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

**Where the time goes.** 9 µs is far more than the arithmetic in `reactor-logic.lua` looks like it
should cost, and the step crosses the Lua↔C++ boundary about eight times per reactor — `fluidbox[1]`
(which allocates a table), `energy` read and write, `fluidbox[2]`, `get_capacity`, the two box
writes. On that basis this note used to say *"the physics is not the cost; the API is"*, and put the
arithmetic one to two orders of magnitude below the figure.

> **Measured 2026-08-18 and only half right ([#39](https://github.com/trulsjo/realistic-fusion-refreshed/issues/39)).**
> The arithmetic is about **a third** of the step, not a hundredth of it. Crossings do cost more —
> roughly two to one — but that is a ratio, not the order of magnitude this paragraph asserted, and
> the difference decides what an optimisation would target. See *Where the cost actually goes* below.

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

> **Both figures superseded 2026-08-18 (#39): the floor is about 1.35×, and neither of these runs
> was taken on a machine known to be quiet.** The instinct here was right and the diagnosis was not —
> the spread is not a property of "this laptop" that has to be lived with, it is other work running
> on it, and there is now a `BUSY` warning that says which runs had it. Interleaved repeats are not
> the remedy; a quiet machine is.

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

- **`LuaFluidBox[i].amount` is the box's share, not the segment's contents.** ~~`get_capacity(i)`
  likewise reports the segment.~~ **Half wrong, corrected under #40 below: `get_capacity` reports the
  segment when asked of a pipe and the box's own volume when asked of a machine — whether or not
  that box is plumbed into a run (#68).** Anything that reasons about how full a reactor is — the tooltips
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

> **Every figure in this subsection is superseded — see *Where the cost actually goes, and what the
> spread was (#39)* below.** These runs were taken while an unrelated compile was running on the
> machine, which this rig cannot subtract: the baseline is a separate process minutes away from the
> measurement, so contention lands on the difference rather than cancelling. Re-measured quiet, the
> D-D column falls from 6.3–6.9 to 2.4–3.2 and the mixed column from 2.9–4.0 to 2.4–2.5 — which
> collapses the section's headline finding into "they are the same number". Left standing because the
> reason it was wrong is the finding of #39.

`scriptUpdate` mean, baseline subtracted, µs per reactor. 1000 ticks × 3 runs per count.

| reactors | all four reactions | D-D alone |
|---:|---:|---:|
| 1 | 10.0 | 23.3 |
| 10 | 4.1 | 4.4 |
| 50 | 2.9 | 6.3 |
| 200 | **2.95** | **6.88** |

Repeated at *n* = 200, same machine, same session. Every mixed run had the identical grid and the
identical split (`d-d:60, d-t:50, d-he3:45, he3-he3:45`), so these are repeats of one measurement —
of one measurement taken on a busy machine, which is what the repeats were failing to detect:

| run | mixed | D-D alone |
|---|---:|---:|
| full sweep `0,1,10,50,200` | 2.95 | 6.88 |
| `0,200` | 2.85 | 6.30 |
| `0,10,200` | 4.04 | — |

**The third mixed run is 40% above the first two, and that is this page's own 20–42% spread rather
than anything about the mod.** Its *baseline* moved with it — 9.4 µs of `scriptUpdate` at *n* = 0
against 6.4 and 5.0 — and its `wholeUpdate` median went from 403 and 291 µs to 480, which is a
machine doing other work, not a reactor costing more.

> **This paragraph got the diagnosis right and drew the wrong conclusion from it (#39).** "A machine
> doing other work" was correct, and it was read as reassurance — the baseline moved *with* the
> measurement, so the contamination looked like it would cancel. It does not cancel. The two are
> separate processes and the figure is their difference, so a machine that is busy for part of the
> window lands entirely on that difference. The right response to seeing the baseline move is to
> discard the run, not to keep it as evidence of a wide but honest spread. Recorded rather than dropped, because dropping
the inconvenient repeat is how a 42% spread turns into a false precision.

~~At 200 reactors the full reaction set costs about 3 µs per reactor — call it 0.6 to 0.8 ms per tick,
3.4% to 4.9% of the 16.67 ms budget.~~ **Quiet, it is 2.5 µs per reactor: 0.5 ms per tick, about 3.1%
of the 16.67 ms budget** (#39). A large but ordinary build of 20 to 50 reactors pays well under 1%,
which is the one sentence here that did not need correcting.

> **It needed correcting too, on 2026-09-03
> ([#62](https://github.com/trulsjo/realistic-fusion-refreshed/issues/62)).** Both figures above are
> a reactor with **no collector attached**, which is not what a player builds — see
> *[Collectors attached](#collectors-attached-62)*. Collected, the full set is 4.48 µs and 5.4% of a
> tick, and a D-D base 4.84 µs. That also takes the 20-to-50-reactor claim with it: at 4.84 µs,
> fifty reactors is **1.45%** of a tick, not "well under 1%". Twenty is 0.58%. The shape of the
> conclusion survives — an ordinary build pays low single-digit percentages — but the sentence that
> boasted of needing no correction was the one figure on this page most in need of it.

### The surprise: the full set is CHEAPER per reactor than D-D alone — withdrawn

> **Withdrawn 2026-08-18 (#39).** Re-measured on a quiet machine the two are 2.6 and 2.5 µs — a ratio
> of 1.03, which is one number. The mechanism below is real code, and it costs too little to measure.
> The whole of the effect was contention. The subsection is kept because its cross-check reasoning is
> sound and its conclusion is the cautionary tale.

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

> **Also withdrawn.** There is no worst case: every reaction costs about the same. Note what the
> *n* = 10 cross-check did and did not buy — it correctly established that the two rigs measure the
> same thing when they contain the same thing, and it could not establish that the divergence above
> *n* = 10 was caused by the reactions rather than by the clock, because both changed together.

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

> **Withdrawn 2026-08-18 (#39): nothing doubled.** The quiet figure is 2.4 – 3.2 µs, median 2.6,
> which straddles #27's 2.85. Two runs each way were not enough, because both were contended.

**D-D alone has roughly doubled since #27's 2.85 µs, and this note does not explain it.** Two runs each
way put it well outside the 1.5× this page says to treat as noise, so it is a real change rather than a
reading. What landed in between is #30's lithium blanket, #31's aneutronic tier and the work on
radiation loss; which of them costs what was not isolated here, and attributing it is the kind of thing
[#39](https://github.com/trulsjo/realistic-fusion-refreshed/issues/39) exists for.

> **Closed 2026-09-03 by [#63](https://github.com/trulsjo/realistic-fusion-refreshed/issues/63): the
> cause is measurement, not code, and #39 already held it.** #63 was filed to bisect the doubling —
> three hours before #39 closed and withdrew it. There is nothing to bisect, and what follows is
> measurement rather than argument.
>
> **Re-measured on the shipped tree.** Three invocations of `scripts/bench-reactors.ps1` with no
> arguments — D-D alone, vented, `-Gap 5`, `0,1,10,50,200`, the configuration both #27 and #34's
> D-D column measured — one after another on the same machine, never two at once. They report
> **2.49, 2.49 and 2.78 µs** per reactor at *n* = 200, a spread of 1.12×, and not one of their
> fifteen launches flagged `BUSY`: the part read between 9 and 42% of itself beforehand, against
> the 60% at which the rig warns. (A fourth ran first and its log was not kept, so its `BUSY`
> state cannot be shown and it is not part of this.) All three land just **below** #27's 2.85 and
> inside #39's quiet band of 2.4 – 3.2 — which is #39's median of 2.6 reproduced sixteen days
> later. **Every gap-5 reading of that configuration at *n* = 200 lies between 2.4 and 3.2, except
> the 6.3 – 6.9 pair**: #27's 2.85, both of #39's quiet sets (ten-run 2.39 – 3.20 and six-run
> 2.56 – 2.85), and today's three. #62's 3.68 is excluded because it is a `-Gap 6` figure, which
> this note says elsewhere is not directly comparable to the gap-5 ones.
>
> **And the check that says which of the two readings is the broken one is already below.**
> Per-reactor cost settles as *n* grows; it does not climb, because a linear cost divided by *n*
> cannot. The #34 D-D column climbed — 4.4, then 6.3, then 6.88 at *n* = 10, 50, 200.
> Today's three settle: 3.00, 2.45, 2.49; then 2.86, 2.39, 2.49; then 3.57, 2.96, 2.78. Each drops
> hard from *n* = 10 to 50 and then holds. The step from 50 to 200 is **1.02×, 1.04× and 1.07×** —
> two of them up, one down — against the 1.35× floor. As a ratio, because the floor is one: an
> absolute µs delta cannot be compared to it. See *[What this corrects
> above](#what-this-corrects-above)*.
>
> **So it is accepted, and nothing is handed on for fixing.** Not "accepted because 2.5 µs is cheap
> enough" — accepted because the change #63 asks to have attributed did not happen. #30's blanket,
> #31's aneutronic tier and the radiation-loss work are all in the tree that measures 2.5, so none
> of them is chargeable. That leaves
> [#66](https://github.com/trulsjo/realistic-fusion-refreshed/issues/66) — the fix ticket #63 was
> blocking, opened to cut a D-D step's cost once its cause was known — waiting on a cause that does
> not exist; what becomes of it is not this note's call. What #63 asked for that outlives it is the
> guard, and #39 built it: `-BusyPercent`, and the instruction to grep for `BUSY` before quoting a
> number.

### Verdict

**Acceptable at the shipped cadence. No further throttling.**

`UPDATE_INTERVAL` stays at 6 — ten simulation steps a second, the value #24 chose. ADR 0005
pre-authorises moving to a coarser cadence if measurement showed the cost was too high; it does not.
3.1% of a tick at megabase scale (#39; 3.4% as first measured), and under 1% at the scale anyone will
actually build, is not a budget worth spending the physics on. Nothing about the rate computation was touched, so the fallback
remains available and remains a one-line change.

~~The number to quote is about 3 to 4 µs per reactor per tick with all four reactions, and about 7 µs
for a D-D-only base.~~ **The number to quote is about 2.5 µs per reactor per tick, whichever reactions
are running** — 2.4 to 2.5 for the full set, 2.4 to 3.2 for D-D alone, and no digit after that is
real. See #39 below for why the figures this section originally carried were nearly three times too
high, and why there is no longer a cheap case and an expensive one.

> **Both of those hold for a *vented* reactor, and #62 measured the other configuration.** With a
> collector bolted on the full set costs about 4.5 µs and a D-D base 4.8 — so the second sentence
> survives (there is still no cheap tier and no expensive one) and the first does not: the number to
> quote is about half again what this section says, for a reason that has nothing to do with the
> arithmetic and that every measurement before 2026-09-03 was blind to. See
> *[Collectors attached](#collectors-attached-62)* at the foot of this note.

### Reproduced 2026-08-20, on the renamed mods

The discharge above was measured on 2026-08-18. The only commit to touch the tick path since is
`eafb16c`, which renamed both mods — so nothing about the simulation changed, and the thing actually
at risk was the rig, which hardcodes `__realistic-fusion-refreshed__` for the ablation ladder and names
the mod in its own dependency. Re-run to confirm both still hold.

`scripts/bench-reactors.ps1 -Mixed`, same counts, same statistic. The rig logged the identical split
at *n* = 200 — `rf-d-d-plasma:60, rf-d-t-plasma:50, rf-d-he3-plasma:45, rf-he3-he3-plasma:45` — so
this is the same measurement, not a similar one.

| reactors | µs per reactor | share of a tick |
|---:|---:|---:|
| 10 | 2.45 | 0.15% |
| 50 | 2.05 | 0.61% |
| 200 | **2.23** | **2.68%** |

**2.2 µs against the 2.4 to 2.5 recorded, a ratio of 1.1** — inside the 1.35× floor, which is to say
the same number. It also passes the check #39 leaves behind for future sweeps: per-reactor cost
**settles** above *n* = 10 rather than rising, which a sweep on a machine getting busier cannot do.

**The first attempt at this sweep is discarded rather than quoted.** It flagged `BUSY` at *n* = 0 —
84% of the part already in other hands when the baseline launched — and returned 3.07 µs. Under #39's
rule a contended baseline is worse than none, because the contamination lands on the difference. The
sweep above ran at 21, 9, 8, 8 and 23%, with no warning at any count. Recorded because the discarded
run is the guard working, and because 3.07 would have sat inside the noise floor and read as fine.

**The verdict is unchanged.** `UPDATE_INTERVAL` stays at 6.

## Where the cost actually goes, and what the spread was (#39)

Measured **2026-08-18**, after the section above, on the same machine and the same Factorio 2.0.77.
[#39](https://github.com/trulsjo/realistic-fusion-refreshed/issues/39) asked two questions this note
had left open — item 5 and item 4 of *What this does not close* — and answering the second one
invalidated several of the numbers above. Those corrections are at the foot of this section rather
than quietly applied in place.

### The machine was not quiet, and that is the whole of item 4

**The run-to-run variation is other work on the machine.** Not thermal throttling, which is what this
note guessed at and never tested. The two are distinguishable and the test is cheap:
`% Processor Performance` reports the effective clock as a percentage of the part's base frequency,
and a thermally throttled part sits **below** 100 and stays there. Sampled through a full experiment,
88 samples, this part never once went below base — it ran between **111% and 158%**, on turbo
throughout. Thermal throttling is ruled out.

What it was instead is not a deduction: an unrelated compile was running in another project during
the first set of measurements taken for this ticket, and re-running them once it finished moved every
figure. That is the confound this rig is least able to absorb, for a structural reason worth writing
down:

> **Every per-reactor figure here is a difference between two Factorio processes minutes apart.**
> `n = 0` is measured in its own process, `n = 200` in another. Work that starts on the machine
> between the two does not cancel out of the subtraction the way the rig's own power does — it lands
> entirely on the difference. The method's central strength, *every run builds the same map, so a
> difference between runs is reactors*, holds only for the map. It says nothing about the machine.

`bench-reactors.ps1` now reads the machine's clock and its load immediately **before** launching each
count's Factorio, prints both, and warns `BUSY` above `-BusyPercent` — 60% of the part by default,
calibrated rather than round: the machine idles near 33%, and a multi-core compile takes it past 100%
and holds it there.

**Before the launch, not during it, and the ordering is the whole design.** Measured during the run
the counter is largely measuring *us*: Factorio starts up and loads a save multi-threaded, and an
invocation here is only a few seconds, so that burst is most of what there is to sample. A version
that watched throughout duly warned on every run, including runs on an idle machine — a guard that
always fires hides a contended run exactly as well as one that never fires. Before the launch there
is no Factorio of ours and whatever the counter reports is somebody else's.

What that cannot see is work beginning after the launch and ending before the process exits. Over a
sweep the gap is small and self-closing, since every count takes its own reading and a compile long
enough to matter is caught by the next one; a compile that fits inside one five-second invocation is
not. So read the warning as *this count was launched onto a busy machine*, which is the claim it can
support. It **warns rather than refuses**, because a figure with the caveat attached beats no figure.
And a counter that does not answer — the paths are localised on non-English Windows — warns too,
because a guard that could not run has not passed. Grep for `BUSY` before quoting a number.

### What remains once the machine is quiet

**About 1.35×, and it lives at the level of the individual benchmark run.** Ten invocations of the
shipped D-D step at *n* = 200, none of them carrying a BUSY warning, gave

```
2.39  2.41  2.42  2.50  2.51  2.65  2.83  2.88  2.89  3.20      median 2.58
```

— a 1.34× spread, or 12% by standard deviation. Inside those same invocations the **individual
benchmark runs** span 468 to 873 µs, a **1.86×** spread on the identical map in the identical
process. So the pooling `--benchmark-runs` already does is carrying most of the load: the figure a
whole invocation reports is a good deal steadier than any one run inside it.

Six further invocations taken afterwards, with the finished instrumentation and not one of them
flagged, came in tighter still:

```
2.56  2.58  2.59  2.62  2.80  2.85      median 2.60,  spread 1.12x
```

**Take 2.6 µs as the figure and 1.35× as the floor.** The tighter set is not licence to quote three
digits: it is six invocations inside a few minutes, and the wider one is what a set spread across an
afternoon looks like. The conservative number is the one to plan against.

**Two further controls were tried and neither is worth having.** Taking the per-reactor cost from the
median across benchmark runs rather than the pooled mean does not help — 1.31× against 1.28× on the
same data, because an outlier run is as often low as high. Nor does raising `-Runs` from 3 to 5:
five invocations each way gave 1.21× at three runs and 1.33× at five, which is to say no effect this
rig can see, for a sweep 60% longer. **`-Runs` stays at 3 and the pooled mean stays the statistic.**
What did change is that each run is now printed separately, so an outlier is visible rather than
buried in the mean it moved.

**So: treat 1.35× as the noise floor, and anything finer than about 1.4× as unmeasured.** That
supersedes both the "around 20%" above and the 42% recorded for the 15×15 rig — neither of which was
taken on a machine verified to be quiet, so neither was measuring only the mod.

### Where the cost actually goes

`scripts/bench-reactors.ps1 -Ablate <rung>` runs a cut-down simulation step in place of the shipped
one and measures it the same way — as a slope against the *n* = 0 baseline. The rungs are cumulative,
so the difference between two of them is the cost of what the second adds:

| rung | what it adds |
|---|---|
| `loop` | walk the register, check `.valid`. No API call per reactor. |
| `read` | `entity.fluidbox[1]` and `entity.energy`. Two crossings, one allocating a table. |
| `physics` | `reactor-logic.step()`. The arithmetic. |
| `write` | the pending table, then `entity.energy`, `box[1]`, `get_capacity(2)`, `box[2]`. |

The rig gets to own the step because `raise_built = false` on the reactors it places: realistic-fusion-refreshed
registers a reactor from the build event and rescans only at `on_init`, which runs before the rig's,
so an unraised reactor is one the shipped `update()` never sees. It then walks an empty register
while the rig steps the reactors itself, at the cadence read out of `control.lua` rather than
remembered. **The physics rung requires `reactor-logic` straight out of `__realistic-fusion-refreshed__`**, so
it is the shipped arithmetic and not a copy of it. Rungs below `write` leave no mark on the world, so
the rig counts its own steps and the reactors they touched and the script gates on both — a handler
that silently failed to register would otherwise report a cost of nothing, which reads exactly like
the finding.

Six passes, D-D, *n* = 200, 1000 ticks × 5 runs each. Median over the passes that ran quiet:

| what | µs per reactor | share of the ladder |
|---|---:|---:|
| walk the register, check `.valid` | 0.060 | 3% |
| `fluidbox[1]` and `.energy` — two crossings | 0.270 | 14% |
| **`reactor-logic.step()` — the arithmetic** | **0.876** | **45%** |
| pending table and four write crossings | 0.725 | 38% |
| **ladder total** | **1.932** | |
| shipped step, measured directly | 2.507 | |

**The arithmetic is about a third of the shipped step, not a hundredth of it.** Crossings still cost
more than it does — 1.0 µs against 0.88 within the ladder — and the 0.58 µs by which the shipped step
exceeds the ladder is work the ladder omits, which is the collector lookup and the circuit publish,
and so crossings again. That last part is arithmetic on a difference rather than a measurement: it
was not ablated separately. So the direction of the old claim was right and its magnitude was wrong
by well over an order of magnitude. Call it **two to one**, not a hundred to one.

**That changes what an optimisation would target, which is why #39 asked.** The premultiplied
reactivities [ADR 0005](../adr/0005-real-time-fusion-simulation.md) records as the obvious first
optimisation are **not** worthless: they aim at a real third of the step. They are also not a
solution on their own, since premultiplication removes part of the interpolation rather than the
whole of the arithmetic. Batching or caching the fluidbox work aims at the larger share. Neither is
worth doing at 2.5 µs a reactor — this is recorded so that whoever needs it later starts from a
measurement rather than from this note's old guess.

> **Three of this paragraph's sentences are withdrawn by
> [#66](https://github.com/trulsjo/realistic-fusion-refreshed/issues/66), and the load-bearing one
> is the claim that premultiplication removes *part* of the interpolation. It removes none of it**,
> because the interpolation here has never had an energy term in it, and the word does not occur in
> either of `reactivity.lua`'s two commits. What it aims at is one multiply outside the
> interpolation, and it cannot remove even that without adding a divide.
>
> Two more sentences fall with it. *Not worthless: they aim at a real third of the step* — the third
> is real, and premultiplication is not what would take it. And *Neither is worth doing at 2.5 µs a
> reactor* — there is only one lever left to weigh, and 2.5 µs is not the figure to weigh it at
> either, per *[Collectors attached](#collectors-attached-62)*.
>
> **What stands is the ladder and the other lever** — the arithmetic is a real third, the crossings
> are the larger share, and batching or caching the fluidbox work is still the thing that aims at
> the larger share and is still not worth pulling. See
> *[Nothing to cut](#nothing-to-cut-and-why-the-named-lever-is-not-one-66)* at the foot of this note.

The ladder was re-run once more at the end on the finished script, at three benchmark runs rather
than five, and lands in the same place: `read` 0.315, `physics` 1.404, `write` 2.059 µs. Different
numbers to two digits, the same shape.

Two caveats on the table, both crediting the crossings too generously rather than too little. The
`write` rung bundles the per-reactor `pending` table in with the four write crossings, so its 0.725 µs
is an upper bound on what the writes themselves cost. And the ladder omits what the shipped step does
beyond it, which is why 1.932 does not reach 2.507.

**Garbage collection stays negligible and now has a ladder to sit against.** `luaGarbageIncremental`
per reactor runs 0.00 µs at `loop`, 0.07 at `read` — the table `fluidbox[1]` allocates — 0.04 at
`physics`, 0.14 at `write`, and 0.19 for the shipped step.

### What this corrects above

Every figure below was re-measured on a quiet machine with the same script and the same counts. The
old ones are left standing above rather than deleted, because they are what the record said and
because the reason they were wrong is itself the finding.

| claim above | what it said | measured 2026-08-18, quiet |
|---|---|---|
| D-D alone at *n* = 200 | 6.3 – 6.9 µs | **2.4 – 3.2 µs, median 2.6** |
| all four reactions at *n* = 200 | 2.9 – 4.0 µs | **2.4 – 2.5 µs, median 2.5** |
| D-D alone costs 2.3× the mix | the headline surprise of #34 | **1.03× — the same number** |
| `luaGarbageIncremental`, D-D against mixed | 0.51 against 0.17, a 3× difference | **0.19 against 0.17** |
| D-D has roughly doubled since #27's 2.85 µs | "a real change rather than a reading" | **withdrawn — 2.6 straddles 2.85** |
| share of a 16.67 ms tick at 200 reactors | 3.4% – 4.9% | **about 3.1%** |

**The surprise did not survive.** *The full set is CHEAPER per reactor than D-D alone* rested on
6.3–6.9 against 2.9–4.0; on a quiet machine the two are 2.6 and 2.5, which is one number. The
mechanism it proposed is real code — D-D is the only reaction that breeds, and `result.products` is
built every step whether or not a collector exists — but the table costs too little to see, which the
`luaGarbageIncremental` row now says directly instead of contradicting. **There is no cheap case and
no expensive case: every reaction costs about the same, and a D-D-only base is not the worst one.**

**The old D-D column also fails a check anyone can apply to a future sweep.** Per-reactor cost is flat
above *n* = 10 — this note says so itself, and every clean sweep shows it settling downwards: 3.40 µs
at *n* = 10, 2.54 at 50, 2.42 at 200. The figures it recorded **rose**: 4.4, then 6.3, then 6.88. A
linear cost divided by *n* cannot do that. A machine getting busier as the sweep runs can, and did.

**That check still passes 2026-09-03.** Three fresh unflagged sweeps settle the same way — 3.00,
2.45, 2.49; 2.86, 2.39, 2.49; 3.57, 2.96, 2.78 — dropping hard to *n* = 50 and then holding within
1.07×, against a column that climbed at every step. Which is why #63, opened to bisect the
doubling this section withdrew, closed without a bisect. See the block under *[Compared
against the early reading](#compared-against-the-early-reading)*.

**What does not change is the verdict.** 2.5 µs per reactor is cheaper than the 2.9 to 4.0 the
decision was discharged on, so *acceptable at the shipped cadence, no further throttling* holds with
more room than it was given. `UPDATE_INTERVAL` stays at 6.

## Fluid segments, and what sharing a pool actually costs (#40)

Measured **2026-08-18** on Factorio 2.0.77 by `scripts/check-pooling.ps1`, which exists because
nothing else could ask this question. `bench-reactors.ps1 -Pooled` pins every segment at 100% with an
infinity pipe filter, so the write semantics never come under strain — it measures what sharing
*costs*, not whether it is *right*. The pooling harness uses no infinity pipe anywhere: every run is
seeded once and left to burn down.

The three semantics below are the ones `control.lua`'s `apply()` is written against, and the 2.0 API
documents none of them. Two of the three are not what this note previously said.

### 1. `amount` is the box's share — confirmed

Unchanged from *A finding about fluid boxes, discovered by getting it wrong* above, and now checked
at five different runs rather than inferred from one accident. Every box on a run holds the run's
contents in proportion to its own volume, and a Lua write is clamped to the box before the engine
re-splits.

**With one correction: the split is approximate.** The reactors settle about **two to three percent
fuller** than the pipes on the same run — 44.93% against 43.80% on a three-reactor run at 44.65%
overall. Near enough to reason with, not exact enough to assert equality against, which is why the
harness allows five percent.

That inexactness is also why seeding a run is harder than it looks. **A Lua write replaces a box and
the engine re-splits between writes**, so seeding a row box by box in one pass throws most of it
away: a three-reactor run written full in a single pass settles at 45% of capacity, not 100%. The
harness writes every box every tick for a second before it measures anything.

### 2. `get_capacity` reports the SEGMENT for a pipe and the BOX for a machine — this note had it wrong

> Superseded: this page previously stated, and `control.lua` still commented, that
> *"`get_capacity(i)` likewise reports the segment"*. That is true of a pipe and false of a reactor.

**Whether the box was PLUMBED matters, and the first version of this table did not say.** #40 asked
the question of one shape only: an `input-output` box on a run, and an **output** box with nothing
attached to it. An unconnected box reporting its own volume is not a measurement of the thing in
doubt — it is the case where the box and the segment are the **same object** — so the output-box row
was an extrapolation. #68 re-took it with the box on a run, and added the collector, which is the
output box `deposit()` actually writes into.

| asked of | plumbed into | the run it is on | what it returns |
|---|---|---:|---:|
| `rf-pipe` | it *is* the run | 4000 | **4000** — the whole segment |
| `rf-reactor` box 1 (plasma, `input-output`) | `rf-pipe` and other reactors | 4000 | **1000** — its own declared volume |
| `rf-reactor` box 2 (energy, `output`) | 20 `pipe` and a `storage-tank` | 27000 | **1000** — its own declared volume |
| `rf-isotope-collector` box 1 (tritium, `output`) | 20 `pipe` and a `storage-tank` | 27000 | **500** — its own declared volume |

The first two rows are checked at runs of 2500, 4000, 6000 and 7000 units and the reactor answers
1000 every time. The last two are checked at a run of **27000** — 27 times the reactor's box and 54
times the collector's — so the two candidate answers cannot be confused. **Connecting the box changes
nothing**: an output box on a 27000-unit run reports the same number it reported with nothing on it.

> **The rig defect this found is worth knowing before extending it.** A `storage-tank`'s four
> connections sit at asymmetric offsets from its centre — the first one measured here is (-1,-2) and
> the one the fixed rig ends up using on the reactor's run is (+2,+1) — so aiming an *arbitrary* one
> at the last pipe can place the tank's body **back along the run**, over pipes already laid.
> Factorio accepts that placement and it **splits the segment**: with the tank at (61.5, 875.5) on a
> run laid north from (60.5, 892.5), the first nineteen pipes read 1900 and the last pipe plus the
> tank read 25100. Reading either alone passes for a run. `check-pooling.ps1` now picks the
> connection that puts the tank beyond the end of the run, and asserts that every pipe and the tank
> report one figure.

**Nothing is broken by this and one comment was wrong.** `apply()` clamps its energy write with
`box.get_capacity(2)` and `deposit()` computes collector headroom the same way — both on boxes a
player pipes, which is why #68 measured them piped. Both wanted the box
figure and both get it — the write would be clamped to the box regardless. What was wrong was the
reasoning written beside them, which claimed a segment-wide number and would have justified writing
more than a box can hold if anyone had ever relied on it.

### 3. A run really is one pool, and an idle one flattens

The harness builds rows of two, three and five reactors bridged by `rf-pipe` with **only the westmost
on an electric network**. An unpowered reactor runs its whole step with heating clamped to zero, so
any heat it holds arrived along the pipe.

| row | unpowered reactors reach | spread among them | the powered one sits |
|---|---:|---:|---:|
| pair (2) | 1.36×10⁸ °C, 136× the seed | 0% | 3.6% above |
| trio (3) | 9.23×10⁷ °C, 92× the seed | 0.03% | 5.6% above |
| five (5) | 5.65×10⁷ °C, 57× the seed | 0.04% | 9.6% above |

And a run with **nothing driving it at all**, seeded fifty times apart end to end, flattens from a 98%
spread to **0.015%** within three seconds. That is the engine's mixing on its own, and it is the
clean answer to "do they converge to a single temperature".

**The powered reactor sits persistently above its own run, and that was not expected.** It is not a
transient and it does not close when the sample is taken off the simulation's beat: heat enters at
one box and leaves it no faster than the pipe carries it away, so the gradient is re-created every
step. It grows with the length of the run — 3.6% at two reactors, 9.6% at five. **"One pool at one
mixed temperature" is an idealisation with a source-side gradient in it**, and it is what a player
will see if they read two reactors of six off the same pipe run and expect identical numbers.

### 4. The engine destroys heat when it mixes

**This is the finding, and it was not what the ticket went looking for.**

The harness builds one row of three reactors with `raise_built = false`, so realistic-fusion-refreshed never
registers them and **no simulation ever runs on them**. It seeds the run flat, raises one box
fourfold, and leaves it alone. Nothing consumes plasma, nothing supplies it, no Lua of ours touches
it again.

- the run's plasma **amount** does not move: 1785.8695 units before, 1785.8695 after
- the run flattens to **0.0008%** end to end, so the mixing had finished when it was read
- and **18.2% of the sum of amount × temperature is gone**

Mixing is supposed to be a mass-weighted average, and a mass-weighted average conserves that sum
exactly. Since every box on the run holds the same fluid at the same heat capacity, the sum is
proportional to thermal energy. **Flattening a temperature difference across a fluid segment destroys
a fifth of the excess, in the engine, with no mod code running.**

The control that makes it attributable rather than a story is **the same run, undisturbed**: over
sixty ticks with nothing done to it, its heat moves by 0.0009%. So these entities do not leak heat on
their own — which was the first suspect, and `prototypes/entities.lua`'s "the boiler is neutered"
note would have been the natural place to blame. The loss appears only when a *difference* has to be
flattened.

### 5. So the pool does not gain what the reactors spent — and only part of that is the engine's

The bookkeeping check predicts one simulation step by requiring `reactor-logic` straight out of
`__realistic-fusion-refreshed__` — the shipped arithmetic, not a copy — and compares it against what the run
actually gained over exactly that step. The four rows are built to separate two explanations that
predict the same ordering.

| run | writers | capacity | arrived |
|---|---:|---:|---:|
| `solo` — one reactor, no pipe at all | 1 | 1000 | **94.9%** |
| `solopipe` — the same one reactor, +20 pipe | 1 | 3000 | **75.2%** |
| `bare` — three reactors bridged | 3 | 4000 | **57.6%** |
| `piped` — the same three, +20 pipe | 3 | 6000 | **66.8%** |

**`solo` against `solopipe` is the measurement that matters**, because the only thing that changes
between them is whether there is a run to mix across. One writer both times, so no reactor can
overwrite another. **Mixing alone costs about twenty points**, which is the same finding as §4 arrived
at from the other direction, on a rig where the simulation is running.

**And three reactors lose more than mixing alone accounts for.** 57.6% on three writers against 75.2%
on one. ~~That excess is **in this mod, not the engine**, and the mechanism is visible in `update()`:
it reads every reactor and then writes every reactor, and each write *replaces* its box with an
amount and a temperature computed against the start-of-step pool. The engine re-splits between those
writes — §1 shows it doing exactly that during seeding — so a reactor writing second can overwrite
the share of its neighbour's rise that it had just been given.~~ **This harness establishes that the
excess exists; it does not isolate that mechanism, and no fix is attempted here.**

> **The struck mechanism was measured and does not exist. Corrected 2026-08-19 (#73).**
>
> Three additions to `check-pooling.ps1` settle it, and the negative result rests on a control rather
> than on an absence:
>
> - **The `probe` row asks the premise directly.** One box on an untouched run is raised fourfold and
>   the whole run is read again *in the same tick*: **0 of 12 other boxes moved.** Through the same
>   snapshot code six ticks later, **12 of 12 had moved.** So the instrument can see the run
>   redistribute, and it does not happen between Lua writes — it happens in the engine's own fluid
>   update, after every handler has run. **The share a second writer would overwrite has not arrived
>   yet.**
> - **The three shape rows ask it from the other side.** Identical unregistered geometry, one
>   identical state, one reactor of three heating so the writes differ — 73% apart end to end at the
>   instant they landed. The shipped two-pass shape, a single-pass shape, and a two-pass shape with a
>   *relative* write all keep **72.18%**, the same number to four figures. The engine cannot tell the
>   shapes apart, so there is nothing to choose between them.
> - **§1's seeding evidence was misread, and that is what made the mechanism plausible.** The 45%
>   is real; its cause is not write interaction. `seedonce` is seeded exactly **once** and holds
>   **44.6%** of declared capacity; `mix`, the same geometry seeded **sixty** times, holds **44.6%**.
>   One pass leaves a run as full as sixty do. 44.6% is what a three-reactor bridged run holds against
>   the sum of its boxes' declared volumes — a fact about the segment, not about writes.
>
> **So the excess is real and unexplained.** It is not the write shape, and it is not mixing alone.
> The obvious next suspect is that `bare` and `solopipe` differ in fill (44.6% against 27.6%) and in
> temperature as well as in writer count, so #40's comparison does not hold writer count alone
> constant — which means the "excess" may not be a writer-count effect at all. Isolating it needs a
> pair that differs *only* in how many reactors write.

**So `apply()`'s comment is right about the arithmetic and wrong about the outcome.** It reads *"the
two errors cancel exactly … so the energy the pool gains is the energy the reactor spent whatever
else is on the run"*, and closes with *"measured at 20 pipes against none: same plasma, same heating,
same stored energy to within a tenth"*. The cancellation argument is sound as arithmetic. The outcome
is not: between five and forty percent of the energy never arrives, and the figure moves with both
the plumbing and the number of reactors. 57.6% against 94.9% is not within a tenth of anything.

**What this does and does not mean.** It does *not* mean reactors are producing less energy than the
mod intends — the reactor sells `rf-reactor-energy` out of its own step, and that is unaffected. It
means **the plasma runs cooler than the model says it should**, by a margin that grows with how many
reactors share a run. Since reaction rate goes as the square of density and rises steeply with
temperature, that is a balance effect rather than a rounding one.

**Nothing is settled here about what to do**, and nothing should be. The engine's share may be
something to accept and design around; ~~the mod's share looks more like a defect in the two-pass
update and is worth its own ticket~~ — **it is not the two-pass update, see the correction above; what
the remaining share is has not been identified** — and reopening
[ADR 0011](../adr/0011-per-reactor-simulation-fluid-coupled.md)'s delegation of sharing is an
architectural decision either way. What is settled is the measurement.

### What the harness does not cover

One surface, one plasma, no pumps and no `rf-pipe-to-ground` on any run. Nothing here says anything
about a segment being split or merged while running: ADR 0011 has no code for that because the engine
owns it, and observing it is a different ticket.

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
   expectation recorded here — that per-reactor cost would not grow as reactions were added — held.
   It held plainly, in the end: measured on a quiet machine (#39) every reaction costs about the
   same, 2.5 µs, and the "the average *fell*, because only D-D breeds" this item used to record was
   a contended machine rather than a property of the mod.
3. **Nothing was measured with a player watching.** Rendering, GUI and the interface #25 will add
   are all absent. The redesign's 45 ms is best explained by exactly that kind of cost, so v1's
   interface work should be measured when it lands rather than assumed free.
4. ~~**The 20% run-to-run variation was not chased down.**~~ **Chased down 2026-08-18 (#39): it was
   other work on the machine, not thermal throttling** — the part never dropped below its base clock
   in 88 samples. On a quiet machine what is left is about **1.35×**, and it lives at the level of
   the individual benchmark run. The script now records the machine's load and warns `BUSY`. The
   advice to re-run the baseline in the same session still stands and is now the *weaker* of the two
   rules: **check the run was quiet first**, because a baseline taken beside a compile is worse than
   no baseline at all — the difference is where the contamination lands.
5. ~~**The API cost per crossing was not isolated.**~~ **Ablated 2026-08-18 (#39).** Crossings do cost
   more than the arithmetic, but by about **two to one**, not the order of magnitude this note
   claimed. The arithmetic is roughly a third of the step. What is still not isolated is the cost of
   any *single* crossing: the ladder measures groups of them, and the write rung bundles a table
   allocation in with four writes. Per-call profiling would be needed for finer than that, and
   nothing currently needs it.

### Sources

- `scripts/bench-reactors.ps1` — the measurement, including the rig it builds and the `-Ablate`
  ladder that breaks the step down.
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
already recorded a run-to-run spread of 42% (**1.35× on a quiet machine, #39**) — so 2.85 against a
previous high of 2.46 is 1.16×, and
the section above says plainly that differences finer than about 1.5× are unmeasurable here without
interleaved repeats. It sits inside the noise. Anyone who needs the real number should take it as
an A/B on one machine in one sitting rather than reading it off this table.

What was added to the tick path is one table of two entries per reactor per step, built in
`reactor-logic.step()` and handed back with the rest of the result. It is worth knowing that the
benchmark's reactors have **no collector bolted to them**, so `deposit()` never runs and the
allocation is the whole of what is being measured — a rig with collectors would pay two fluidbox
writes per reactor on top, and by the lesson above those would cost more than the arithmetic does.

> **Measured 2026-09-03 ([#62](https://github.com/trulsjo/realistic-fusion-refreshed/issues/62)),
> and the guess was right.** The rig can bolt collectors on now. D-D with them costs 4.84 µs per
> reactor against 3.68 vented, in one sitting on a quiet machine — and across the six
> vented-against-collected pairs the premium runs 1.28 to 1.68, four of them above the 1.35× floor.
> So the allocation stayed unmeasurable and **the plumbing it feeds is measurable**, which is the
> guess above confirmed: what was too cheap to see was never the table, it was that nothing had
> ever run the writes. See *[Collectors attached](#collectors-attached-62)*.

The allocation is avoidable: `step()` could fill a caller-owned table instead of returning a fresh
one. It was left alone, because doing it would put an out-parameter into the one module in this mod
that is pure and testable outside Factorio (ADR 0005), in exchange for a saving that this
measurement is not sharp enough to see.

## The buffer holds 6.7% more than the prototype declares (#71)

Measured 2026-08-20 by `scripts/check-buffer.ps1`, against **Factorio 2.0.77**.

`rf-reactor` declares `buffer_capacity = "10MJ"` and its buffer peaks at **10,666,666.67 J**. That
figure fell out of #37's trace of the reactor's power draw and nobody could explain it, which put it
in exactly the position ADR 0011's mixing rule was in before #40 measured it: **a declared prototype
number this repo believed and had seen violated.** #72 retunes `check_cadence()` against this
buffer, so it was worth knowing what the buffer really is first.

### The rule

**The engine holds 16/15 of the declared `buffer_capacity` — 6.666667% over, exactly.** Not
approximately, and not a rounding: the same ratio to the ninth decimal at 1 MJ, 7 MJ, 10 MJ and
100 MJ declared.

| probe | declared | held | ratio |
|---|---:|---:|---:|
| `driven` — the shipped reactor, simulated | 10 MJ | 10,666,666.67 J | 16/15 |
| `same` — the same prototype, never registered | 10 MJ | 10,666,666.67 J | 16/15 |
| `flow-6` — `input_flow_limit = "6MW"` | 10 MJ | 10,666,666.67 J | 16/15 |
| `flow-600` — `input_flow_limit = "600MW"` | 10 MJ | 10,666,666.67 J | 16/15 |
| `no-limit` — no `input_flow_limit` at all | 10 MJ | 10,666,666.67 J | 16/15 |
| `tertiary` — `usage_priority = "tertiary"` | 10 MJ | 10,666,666.67 J | 16/15 |
| `buffer-1` | 1 MJ | 1,066,666.67 J | 16/15 |
| `buffer-7` | 7 MJ | 7,466,666.67 J | 16/15 |
| `buffer-100` | 100 MJ | 106,666,666.7 J | 16/15 |

The held figure is taken two independent ways: watching the buffer fill over 900 ticks, and writing
1e15 J at the entity and reading back what stuck. An over-large write is clamped rather than
refused, so the second is the engine stating its own ceiling rather than an inference from a fill.
**Where both readings exist they agree exactly** — which is every row above except `tertiary`, and
both accumulators below. Those three never charge on the rig, because the interface's surplus does
not reach them, so they rest on the clamp alone. It matters most for `tertiary`, which is the only
probe separating usage priority from entity type.

### So `buffer_capacity` is a floor where it is honoured at all, and the API reports the floor

The prototype documentation for 2.0.77 calls it *"How much energy this entity can hold"*
(<https://lua-api.factorio.com/2.0.77/types/ElectricEnergySource.html>). Read as a ceiling that is
wrong by 1/15. Read as a floor it is right for every probe above — and it is not a hint, because the
engine's ceiling is an exact function of it. The qualifier is the assembling machine at the foot of
this section, which does not honour the field at all; for the reactor, and for everything else
measured here, floor is the answer.

The trap for mod code is the second half: **`LuaElectricEnergySourcePrototype.buffer_capacity`
returns the declared figure, not the effective one.** So any check written against the prototype —
`check_cadence()` in `control.lua` is this repo's — is comparing against a figure the entity has 6.7%
more than. That is conservative rather than wrong, and at the shipped numbers it changes
nothing: 10.67 MJ against 50 MW is a ceiling of 12.8 ticks where the declared 10 MJ gives
12, and `UPDATE_INTERVAL` is a whole number of ticks either way. **#37's guess that "the ceiling may
be conservative by a little" is confirmed, and the little is 0.8 of a tick.**

### The four candidates #71 listed, each answered

- **"A floor the engine rounds up from, to a whole number of joules per tick or to satisfy
  `input_flow_limit`."** *Half right.* It is a floor, but the rounding story is wrong: the ratio is
  identical at 6 MW, 60 MW, 600 MW and unlimited inflow, and identical at four declared capacities
  including 7 MJ, which is not a round number of anything. It is a multiplier, not a rounding.
- **"The reading is of something else — a transient between the network update and the entity's own
  drain."** *Ruled out.* A probe nothing drains fills to 10,666,666.67 J and then neither exceeds
  it nor falls below it on any of the 600 ticks measured after the fill, and a deliberate over-write
  is clamped to the same figure.
- **"`input_flow_limit = "60MW"` interacts with it."** *Ruled out*, by the three flow-limit probes
  above.
- **"It is our own write."** *Ruled out.* `same` is the reactor prototype under a name
  `entity-management` does not register, so no Lua of ours ever touches its energy, and it holds the
  identical figure. The reactor the simulation drives peaks at exactly the same value.

### What the ratio does **not** apply to, which is why this note claims a rule and not a law

- **Accumulators get exactly what they declare.** Vanilla's `accumulator` clamps at 5,000,000 J
  against its declared 5 MJ, and the same prototype forced to 10 MJ clamps at 10,000,000 J. Ratio
  1.0, twice. So the 16/15 is not a property of every electric energy source; it does not apply to
  `usage_priority = "managed-accumulator"`.
- **An assembling machine ignores `buffer_capacity` altogether.** `assembling-machine-2` with the
  field forced to `"10MJ"` holds **2,755.56 J** — five orders down. That is `(2500 + 83.33) * 16/15`:
  its energy usage plus its drain, per tick, times the same ratio. **Measured at two usages rather
  than fitted at one** — the same machine at 300 kW instead of 150 kW holds **5,511.11 J**, which is
  `(5000 + 166.67) * 16/15`, exactly double. So for that entity the declared figure is not a floor,
  not a ceiling and not a hint; it is discarded, and the buffer is sized from the machine's own
  consumption instead. The ratio survives; only the thing it multiplies changes.

**Where 16/15 comes from is not established.** It is 64/60, which looks like a per-tick conversion
made against 64 rather than 60, and that is a guess about engine internals with no evidence behind
it — recorded here as a guess so the next reader does not mistake it for a finding. What is
established is the ratio, its exactness, its independence from inflow and declared size, its absence
on accumulators, and that the declared figure is a floor for everything else measured.

### Sources

- `scripts/check-buffer.ps1` — the rig, and the assertions that fail if any of the above moves.
  Thirteen entities on one map: the shipped reactor, eight clones of it, and four prototypes that
  are not ours.
- The trace that raised it: #37 item 4b. What it unblocks: #72.
- The precedent for measuring rather than reading:
  [ADR 0011](../adr/0011-per-reactor-simulation-fluid-coupled.md) and *Fluid segments* above (#40).

## Collectors attached (#62)

Measured **2026-09-03** on Factorio 2.0.77, the same script and the same statistic as everything
above. This closes the hole
[#62](https://github.com/trulsjo/realistic-fusion-refreshed/issues/62) opened: `bench-reactors.ps1`
built reactors, power and a plasma feed and **nothing else**, so it had never built an
`rf-isotope-collector`, and `deposit()` had therefore not executed in a single measurement this
project had taken — not #24's, not #27's, not #34's. `control.lua` computes `result.products`
either way and only writes a collector's fluid boxes when one is attached, so every figure on
record was the cost of a reactor that **vents**. `blanket_breed()` had never run under measurement
either, for the same reason one step further out: it is called only once a collector has been found.

`scripts/bench-reactors.ps1 -Collectors` bolts one to every reactor; `-Blankets` adds a lithium
blanket loaded with 5,000 items. Both go in the clear ground south of the reactor, side by side —
not one north and one south the way `check-blanket.ps1` places them, because a rig is a grid and a
reactor's north band is its neighbour's south band.

**It needs `-Gap 6`, and the reason is worth reading before trusting any rig of this shape.**
`entity-management` pairs by the tiles touching the reactor with a **whole tile** of margin, and a
fitting sits in a band only `-Gap` deep. At the default gap of 5 a flush five-tile fitting reaches
**half a tile** into the next row's pairing area, `attach()` takes the lowest `unit_number`, and
fittings are built in row order — so every reactor from row 1 on paired with the row *above*'s
fitting. Row 0's fittings served two reactors and the last row's served none. Nothing errored and
the cost barely moved: every reactor still had a collector and `deposit()` still ran. What broke was
the claim, and the blanket gate with it — the doubly-drained blanket in row 0 runs dry first, behind
a check that reads the total. The rig now verifies the pairing against the real bounding boxes at
map creation and refuses rather than reasoning about collision insets. **Every figure below is at
`-Gap 6`, including the vented ones, so the five are comparable to each other and not directly to
the gap-5 figures higher up this page.**

**Placed is not attached, and three more gates hold the difference.** They are the collector's and
the blanket's equivalents of the `output=` gate this note already relies on:

- `collected=` and `tritium=` — fluid in the collectors, in total and in the tritium box alone.
  `deposit()` is the only thing in the game that writes those boxes, so a non-zero total is proof
  the reactor found its collector. The tritium box is separated out because the blanket adds
  tritium and nothing else, so it is the only honest way to read the blanket's contribution.
- `full_pct=` — the **fullest** tritium box, not an average. Only that box can saturate and only
  its fill stops anything, so a figure pooled over both boxes of two hundred collectors could never
  reach a threshold set for the box that matters. It never passed **1.8%** below, so nothing here
  is a saturated collector.
- `bred=` and `lithium_min=` — how many blankets actually spent lithium, and the least any of them
  has left. Per blanket, not summed: a total below what was loaded is satisfied by one blanket
  running, and cannot see the one that ran dry. Both are gates.

### Results

**One sitting, one machine, five sweeps, every count reporting a quiet machine** — no `BUSY` at any
count of any run, which after #39 is the precondition for quoting anything at all. `-Counts
0,10,50,200 -Gap 6`, 1000 ticks × 3 runs per count. `scriptUpdate` mean, baseline subtracted, µs per
reactor.

| reactors | D-D vented | D-D collected | D-D blanketed | mixed vented | mixed collected |
|---:|---:|---:|---:|---:|---:|
| 10 | 3.46 | 5.82 | 6.27 | 4.66 | 6.37 |
| 50 | 3.41 | 4.90 | 5.31 | 3.39 | 4.35 |
| 200 | **3.68** | **4.84** | **5.44** | **3.04** | **4.48** |

`wholeUpdate` for the same runs at *n* = 200 — 4.73, 5.41, 5.99, 3.40 and 4.94 µs per reactor —
because part of what a collector costs is charged to the engine and not to us. Unlike the rig's
power, that part does **not** cancel: power is built for every cell at every count including
*n* = 0, and a collector exists only where a reactor does, so its `entityUpdate` and
`fluidFlowUpdate` land on the per-reactor delta. Every figure here is therefore *a reactor with a
collector*, not *`deposit()`* — the two are not separated, and separating them would want an
ablation rung.

**The *n* = 10 row of the two mixed columns is not a mix.** Rows are `GRID` wide and reactions are
assigned by row, so at *n* = 10 on a 15×15 grid every reactor is in row 0 burning D-D — the rig
logs `burning=rf-d-d-plasma:10` and says as much. *n* = 10 is also this note's noisiest count. Read
those two cells as a second, poorer D-D pair.

**The vented column reproduces the record, which is what licenses the rest of the table.** 3.68 µs
against the 2.4 – 3.2 that #39 measured quiet and the 2.23 of the 2026-08-20 reproduction — 1.15×
the top of that range, inside the floor, and on a slightly larger cell than either. Nothing in the
tick path has changed and this says so.

### What the collector costs

**Between a quarter and two thirds again, and the range is the honest answer rather than any one
ratio in it.** `collected` exceeds `vented` in all six pairs measured — D-D by 1.68, 1.44 and 1.32
at *n* = 10, 50 and 200; the mixed rig by 1.37, 1.28 and 1.47. **Four of the six clear this note's
1.35× floor** (1.68, 1.44, 1.37, 1.47) and two fall just under it (1.32 for D-D at *n* = 200, 1.28
for the mixed rig at *n* = 50), so the premium is real rather than noise — but the spread between
counts is as wide as the effect, which is what stops any single figure being *the* number. **Take
it as about 1.4×, bracketed by 1.3 and 1.7, and expect the next sweep to land somewhere else in
that bracket.**

The mechanism is visible in the rig's own counters rather than inferred. **Only D-D breeds.** The
mixed rig at *n* = 200 holds 60 D-D reactors out of 200, and its collectors held 508 units against
the D-D-only rig's 1,694 — a ratio of 0.30, against a D-D population fraction of exactly 0.30. So
seven in ten of a mixed rig's collectors are ornaments. What that predicts is a *smaller* premium
on the mixed rig, and the measurement does not show one: 1.47 against 1.32 at *n* = 200, the wrong
way round and by less than the noise. The dilution argument is sound and the measurement is not
sharp enough to see it, which is the same sentence #39 had to write about the by-product table.

**So the thing #34 claimed and #39 withdrew stays withdrawn, for a better reason.** #34 said a
D-D-only base was the expensive case because D-D is the only reaction that breeds; #39 re-measured
quiet and found every reaction costing the same. With collectors attached — the configuration that
makes breeding cost anything at all — D-D is 4.84 against a mixed 4.48, a ratio of 1.08. **There is
still no cheap tier and no expensive one.** What #62 changes is not which reaction is dearest; it is
that every configuration costs about 1.4× what the same rig costs vented, and about 1.8× the 2.5 µs
[ADR 0005](../adr/0005-real-time-fusion-simulation.md) has been quoting as discharged.

### The blanket, decided rather than omitted

`-Blankets` is a separate switch from `-Collectors`, and it is **off by default**. That is the
decision #62 asked for, and the measurement is the reason: blanketed D-D costs 5.44 against
collected 4.84 µs, a ratio of **1.12** — well inside the floor, and so unmeasurable here. It is
above the collected figure at every count (6.27/5.82, 5.31/4.90, 5.44/4.84), so the direction is
consistent; the size is not available.

It is not idle in those runs, and the gates say so rather than the geometry. **All 200 blankets
bred** (`bred=200`), the emptiest still held 4,995 of its 5,000 items so none ran dry, and the
tritium box tells the rest: **1,779 units against the collector-only rig's 847 — the blanket more
than doubles a D-D reactor's tritium.** (`collected=` rose only 1.55×, because it carries an
unchanged helium-3 half; that is why the tritium box is reported separately.)

**Why it is off by default anyway.** A blanketed reactor is a later tier's build and a collector is
what every D-D player has, so the default should be the configuration the cheapest tier is quoted
from. `-Blankets` also refuses to run without `-Collectors`: a blanket on a reactor with no
collector is idle *by design* — `apply()` never calls `blanket_breed()`, because spending a real
item to produce nothing is a trap rather than a mechanic — so the rig would be measuring the cost
of owning a container.

### Verdict

**Acceptable. `UPDATE_INTERVAL` stays at 6, and the number to quote moves.**

The figure to quote for the full reaction set is now **about 4.5 µs per reactor, 5.4% of a 16.67 ms
tick at 200 reactors**, against the 2.5 µs and 3.1% that
[ADR 0005](../adr/0005-real-time-fusion-simulation.md) recorded as discharged. That is a 1.8× move
— well above the floor, so it is a real change and the ADR is updated to match. It is a change in
what was measured and not in what the mod does: no commit caused it, the rig simply started
building the configuration a player builds.

**The worst of the five configurations is a blanketed D-D base at 5.44 µs, 6.5% of a tick at 200
reactors** — and that is the configuration a D-T player runs, since the blanket rides on the D-D
tier's collector. It is also the case that arrives earliest and on the smallest bases, which is what
keeps it acceptable: at the ten to fifty reactors a real build has, 5.44 µs is 0.3% to 1.6% of a
tick. Nothing here is worth spending the physics on, which is the question ADR 0005 pre-authorised a
coarser cadence for.

### What this does not close

- **`deposit()` is not isolated from the collector entity.** The delta carries both, because the
  fittings exist only where reactors do. An ablation rung for the write path would separate them;
  `-Ablate` deliberately excludes the collector lookup, and the rig now refuses `-Collectors`
  alongside `-Ablate` rather than reporting a number that mixes the two.
- **The premium is established; its size is bracketed, not measured.** Six pairs agree on the
  direction and four of the six clear the 1.35× floor, but they span 1.28 to 1.68 — so the effect
  is real and the second digit is not. Narrowing it wants interleaved repeats — vented and
  collected alternating within one invocation — which this rig cannot do, since each count is its
  own Factorio process.
- **A saturated collector is unmeasured.** Nothing drains these, and a 500-unit box over a
  seventeen-second run never got past 1.8% full. The state a player reaches with a stopped consumer
  — full boxes, clamped writes, a blanket held at zero headroom — costs something different, and
  the rig reports `full_pct=` so the next run can say whether it got there.
- **The report walk does not cancel either.** Reading the fittings back is a few API calls per
  reactor on a report tick, charged to `scriptUpdate` and absent from the *n* = 0 baseline. At the
  defaults it is under a hundredth of a microsecond per reactor; at `-ReportEvery 1` it would be
  the same order as the cost being measured. The same caveat `ReportEvery` already carries.
- **Still a rig and not a factory.** Unchanged, and still
  [#67](https://github.com/trulsjo/realistic-fusion-refreshed/issues/67)'s.

### Sources

- `scripts/bench-reactors.ps1 -Collectors` and `-Blankets`, and the five gates they add — including
  the pairing check, which was written after review found the gap-5 mis-pairing above and which
  fires on it.
- What it corrects: *D-D by-products (#27)* and *The full reaction set (#34)* above, both measured
  on vented reactors without saying so.

## Nothing to cut, and why the named lever is not one (#66)

Answered **2026-09-04** by reading the code and by a measurement already on this page. **No code
changed, so there is no before-and-after timing here** — [#66](https://github.com/trulsjo/realistic-fusion-refreshed/issues/66)
asked for one and that criterion is void rather than met.

#66 existed to cut what a D-D step costs *once [#63](https://github.com/trulsjo/realistic-fusion-refreshed/issues/63)
named the cause of its doubling*. #63 found no cause: the doubling was a contended machine, the
tree measures 2.49 – 2.78 µs vented at `-Gap 5`, and **nothing has touched either mod since
`ca385ca` of 2026-09-03 00:40** — #62's rig landed at 14:05 that day and #63's reading was recorded
at 17:29, both after it, so the collected figures and the vented ones alike were recorded against
the tree that still ships. The runtime code is older still: `control.lua` and `scripts/reactor-logic.lua`
last had a line of code altered by `fa25da9` on 2026-08-26 — `954338d` that day rewrote comments
alone — and `scripts/reactivity.lua`'s contents have not changed since it was written. What has
moved in between is `prototypes/entities.lua`, at load time, in eight commits from `f5487ca` on
2026-09-01 to `ca385ca` itself inclusive — all eight before either sweep.

Two optimisation candidates were on record. Both are answered below and neither survives.

### Candidate 1 — premultiplied reactivities, and the shape it was an optimisation *of*

[ADR 0005](../adr/0005-real-time-fusion-simulation.md) records this as "the obvious first
optimisation", from the redesign's own `--TODO premultiply reactivities to reduce runtime cost`.
Read what that TODO sits in — `RealisticFusionPower/scripts/reactor-logic.lua:11`, commented out
inside the load-time loop over the datasets, with the line it would have run:

```lua
--for i, _v in ipairs(v) do --TODO premultiply reactivities to reduce runtime cost
    --rfp_datasets[k][i][2] = _v[2]*reaction_energies[k]
```

**In the redesign that is worth doing, because its step spends fourteen multiplies on reaction
energies.** It simulates a *network* rather than a reactor and runs seven reactions at once — D-D_T,
D-D_He3, D-T, D-He3, T-T, T-He3, He3-He3 — then builds two sums over all seven, one against
`charged_reaction_energies` and one against `reaction_energies`. Folding the energy into the
dataset removes seven of those fourteen. It would also have broken the bare reaction counts the
same function needs for all four of `deuterium_usage`, `tritium_usage`, `helium_3_usage` and
`helium_4_usage`, which is the likeliest reason it stayed a comment.

**This mod does not have that shape.** A reactor burns one plasma (ADR 0011: per reactor, not per
network), so `M.step` performs exactly one dataset lookup; `reactivity.lua` carries no energy term
at any point, in the interpolation or out of it; and a reaction energy is applied exactly **once**,
at `reactor-logic.lua:742`:

```lua
local fusion_j = reactions * fuel.energy_per_reaction_j
```

`charged_j` is then a *fraction* of `fusion_j`, so the redesign's second sum has no counterpart
here at all.

**So premultiplication trades one multiply for one divide.** An energy-weighted lookup would make
`reactions` a joule figure, and four things in the same function need it as a count: the `burnable`
cap it is compared against, `burnt`, `products`, and `neutrons`. Recovering the count once costs a
divide, which is not the cheaper of the two operations. That is the whole of the saving, and its
sign is not obviously positive.

Two further costs, so that nobody reads the above as "it is merely not worth it":

- `reactivity.reactivity()` is a public function returning ⟨σv⟩ in m³/s, and
  `tests/test-further-reactions.lua` weighs the four shipped reactions against candidates this mod
  does **not** ship, and for two of the three — T-T and T-He3 — the other side of the comparison is
  a literature ⟨σv⟩ table. Energy-weighting the return value makes the two sides different
  quantities.
- The tables are keyed by reaction and generated by `tools/derive-reactivities.py`; an
  energy-weighted table is keyed by *fuel row*, since the energy lives there. The four shipped rows
  happen to be one reaction each, so nothing collides today — but it stops being a table of
  physical data and becomes a table of this mod's balance numbers.

**It is therefore discharged rather than deferred.** Not "not worth it at 2.5 µs" — the lever is an
artefact of a step this project does not have.

### Candidate 2 — `result.products` computed for a reactor that vents

#34 found this and it is real: `products` is built every step whether or not a collector exists.
**It has already been measured on this page, and it is too small to see.** `luaGarbageIncremental`
is 0.19 µs per reactor for the D-D step against a mixed rig's 0.17 — the D-D rig building the table
on every reactor and the mixed rig on its D-D rows alone, 60 of 200 — and #39's withdrawal says so
in words. Gating it would also change behaviour that `control.lua` states in a comment and that #66
forbids changing: a collector bolted on later starts collecting at once and has no backlog. So it
stays, for the reason it was written.

### What is uncosted, and where to start if a cause ever appears

**The crossings, which are the larger share.** #39's ladder puts the arithmetic at 0.876 µs against
about 1.0 µs of crossings, and everything above aims at the arithmetic. The one crossing worth
naming is `fluidbox.get_capacity`, which asks for a box's **declared volume** — a prototype
constant. A vented reactor that is producing makes that call once a step (`control.lua:442`, inside
the `MIN_FLUID` guard); a collected D-D reactor makes it **four** times, adding the blanket headroom
read (`:482`, on every collected reactor whether or not a blanket exists) and one per by-product box
inside `deposit()`. Caching them at load is the shape of the change, and `check_confinement_ladder()`
already reads a box volume out of `prototypes.entity` at load, so the machinery exists.

**It is a candidate and not a plan, for three reasons.** One call is at most about 0.18 µs — a
quarter of a `write` rung that is itself an upper bound — so alone it is well inside the 1.35×
floor. It trades a crossing for the assumption that a box's declared volume never varies per entity
at runtime, and this note has already been wrong once about what `get_capacity` answers (#40).
And there is no cause to pay for it: at the ten to fifty reactors a build has, the worst measured
configuration is 0.3% to 1.6% of a tick.

### Verdict

**Nothing is cut and nothing changed. #66 is closed on its own last criterion** — *if the honest
answer is that the cost is fine and should stay, that is recorded and the ticket closed*.

The figures to quote are unchanged, and the gap each was taken at goes with it: about **4.5 µs**
per reactor for the full set with collectors and **5.44 µs** for the worst configuration measured
(blanketed D-D), both `-Gap 6`, against 3.68 µs for the same rig's vented D-D. #63's 2.49 – 2.78 µs
is the gap-5 vented figure and is not directly comparable to those three — the same caution the
#62 section states in bold. `UPDATE_INTERVAL` stays at 6. `tests/*.lua` pass — 497 checks across
five suites, 0 failures — the baseline #66 asked for, unchanged because the code is.

### Sources

- `realistic-fusion-refreshed/scripts/reactivity.lua`, and `scripts/reactor-logic.lua:737` and
  `:742` — the one lookup and the one energy multiply a step, both inside `M.step` at `:705`.
- `_reference/realistic-fusion-dev/RealisticFusionPower/scripts/reactor-logic.lua:11` and `:170-210`
  — the TODO, and the fourteen multiplies it aimed at.
- *[Where the cost actually goes](#where-the-cost-actually-goes)* (#39) for the ladder and the GC
  figures; *[Collectors attached](#collectors-attached-62)* (#62) for the figures to quote.

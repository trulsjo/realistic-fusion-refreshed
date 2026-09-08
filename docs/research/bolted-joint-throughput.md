# What a bolted joint carries, and whether one is enough

Measured against **Factorio 2.0.77 (build 84539)** on **2026-09-08** for
[#89](https://github.com/trulsjo/realistic-fusion-refreshed/issues/89), which discharges the
throughput [ADR 0018](../adr/0018-energy-is-contained-and-no-pipe-carries-it.md) records as unmeasured
and [ADR 0031](../adr/0031-energy-bolts-along-a-long-face.md) inherits.

Two scripts, both committed, both re-runnable:

- `scripts/bench-fluid-links.ps1`, unchanged, for the engine's own ceiling — a bolted joint against a
  run of pipe on **one rig**, so the only thing that differs between the two columns is the pipe.
- `scripts/bench-mod-links.ps1`, extended by this ticket, for the shape that ships — a row of
  chained `rf-heat-exchanger`s off **one** reactor connection, driven by a D-T reactor.

**One unit of `rf-reactor-energy` is one megajoule** (`fluids.lua`, `fuel_value = "1MJ"`, and
`reactor-logic.lua`'s `energy_fluid_j_per_unit = 1e6`). Every rate below is therefore readable as
megawatts without a conversion, and this note uses both.

## The short answer

**One bolted connection carries 6 000 MW, and the most this mod can ask of one is 1 195 MW.** The
joint is nowhere near being the constraint, the shipped row of eight exchangers uses 5.3% of it, and
**the reactor does not need energy connections on more than one face** — not for throughput, which was
the open question. ADR 0031's item 6 stays deferred on its own merits; #89 removes throughput as a
reason to take it.

**What the measurement did turn up is a balance finding rather than a plumbing one.** An ignited D-T
reactor on this rig sells **996 MW sustained**, not the "on the order of 320 MW" that
`entities.lua:585` states and that #89's own text and ADR 0018's eight-exchanger row both reason
from. Eight ordinary 40 MW exchangers take 320 MW of it and the reactor **discards 68%**. See [the finding for #227](#the-finding-a-d-t-reactor-sells-three-times-what-eight-exchangers-take).

## What a bolted joint carries, against a pipe run

`pwsh -File scripts/bench-fluid-links.ps1`, no arguments, re-taken 2026-09-08. Units per second,
sustained, at a full source and an empty sink:

| connections | **bolted** (0 pipes) | 1 pipe | 5 pipes | 20 pipes | bolted ÷ 20 pipes |
|---|---:|---:|---:|---:|---:|
| 1 | **6 000.0** | 6 000.0 | 3 333.3 | 3 076.9 | **1.95×** |
| 2 | **11 976.0** | 11 976.0 | 6 666.7 | 6 153.8 | **1.95×** |
| 3 | **17 928.1** | 17 928.1 | 10 000.0 | 9 230.8 | **1.94×** |

Every figure reproduces
[`fluid-link-throughput.md`](fluid-link-throughput.md)'s table to the digit, so nothing in the engine
moved; what this run adds is that the flush column now has a name. **A bolted joint IS the flush
case** — the two machines touching, no pipe, which since #86 is the only arrangement reactor energy
can be in.

Three things to take from the row:

- **The joint carries 1.95× what a twenty-pipe run did**, at every connection count. That is the
  answer to "against what a run of pipe carried", and it is a ceiling comparison rather than a load
  one.
- **A bolt buys nothing over a single pipe.** 0 pipes and 1 pipe are identical to the digit. What
  degrades a link is segment *length*, not the presence of pipe: five pipes cost 44% and twenty cost
  49%, approaching a floor of about half. So the honest description of the bolt is *the short end of
  a length curve*, not a special case the engine treats better.
- **The ceiling is 100 units/tick per connection**, and every figure here is that ceiling scaled by
  how full the source is. `fluid-link-throughput.md` derives that and this run does not disturb it.
  In this mod's units, **one connection is 6 000 MW**.

## The shape that ships: eight exchangers off one connection

`bench-mod-links.ps1 -Plasma rf-d-t-plasma -Exchangers 8 -Ticks 252000 -Window 14000`. Two cells, one
reactor each, four `rf-heater`s each making `rf-d-t-plasma`:

- **`chain`** — the shipped shape. The first exchanger bolts to the reactor's south energy face and
  each one after it chains off its neighbour's east short end (ADR 0031 item 2). Water enters at the
  row's two ends only, because every interior water connection is spent on a joint.
- **`drain`** — the same reactor with the row replaced by a categorised energy feed that removes
  reactor energy as fast as it arrives. Nothing throttles the link, so this is **the most this mod
  will ever ask of a bolted joint**, whatever a player builds downstream.

Both cells settled: rate, plasma temperature and plasma inventory each moved less than their
tolerance across the last two windows, at 2.846×10⁹ °C and 597.4 units of plasma.

| | across the joint, per tick | as megawatts | reactor's energy box | joint's ceiling used |
|---|---:|---:|---:|---:|
| `chain`, 8 exchangers | **5.333** | **320.0** | **978.7 of 1 000 — 97.9% FULL** | **5.3%** |
| `drain`, unthrottled | **19.924** | **1 195.4** | 160.5 of 1 000 — 16.1% | **19.9%** |

(Per-tick figures are the script's *flowing* rate — the rate on ticks fluid actually moved, which is
the one a per-tick ceiling is comparable with. Its *sustained* figures, 4.445 and 16.604 units/tick,
are the same totals spread over every tick including the one in six the reactor writes on and the
meter excludes; 4.445 is exactly ⁵⁄₆ of 5.333, which is the excluded cadence and not a loss.)

**The row is demand-limited, and the two full boxes are the proof.** Every one of the eight
exchangers held **199.3 units of its 200-unit energy box** at the last window and every one reported
`working`:

| position | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| energy held, of 200 | 199.3 | 199.3 | 199.3 | 199.3 | 199.3 | 199.3 | 199.3 | 199.3 |
| water held, of 200 | 199 | 199 | 199 | 199 | 199 | 199 | 199 | 199 |
| status | working | working | working | working | working | working | working | working |

There is **no gradient down the row** — not a shallow one, none at all to one decimal place. The
eighth machine, seven joints from the reactor, is as full as the first. A starved far end would show
as an empty box and an idle machine, and neither happens.

**The reactor's own box backing up at 97.9% is the other half of that.** It is full because the row
cannot take what the reactor makes, and `apply()` discards the overflow; a joint that was the
constraint would show the same full box with the row's boxes EMPTY. The joint was passing 5.3
units/tick out of a box that would have let it pass 97.9.

**Water was not the constraint either**, which is worth recording because ADR 0031 measured
eight-machine water reach on a rig and this is the first time it has been asked under load. Every box
sat at 199 of 200 with the row fed at its two ends only.

### The other end of the same rig: D-D, supply-limited

`bench-mod-links.ps1` with no arguments — the D-D default, four exchangers, 126 000 ticks — re-taken
the same day, both as the control that the extended script still does what it did and as the opposite
case to the row above:

| | across the joint, per tick | as megawatts | exchanger boxes, of 200 | joint's ceiling used |
|---|---:|---:|---:|---:|
| `chain`, 4 exchangers on D-D | 1.567 | 94.0 | **0.3 to 0.4 — nearly EMPTY** | 1.6% |

Its sustained figure is **78.3 MW**, which is the number ADR 0018's Consequences records from
2026-09-07 — reproduced to the digit a day later, on a script this ticket edited. That is the
regression check.

All four working, water full at 200, and **a shallow gradient the D-T row does not have**: 0.4 at the
first machine down to 0.3 at the fourth. That is what supply-limited looks like — 94 MW of reactor
against 160 MW of demand, so nothing accumulates anywhere and the boxes stay at a couple of tenths of
a unit. It is the same joint doing the same job at a sixty-fourth of its ceiling.

**The gradient is worth naming because it is the shape a starved row would have, only much steeper.**
A row that had outrun its joint would look like this one with the far end at zero and idle. Having
both cases on one rig is what makes "no gradient at all" on the D-T row a measurement rather than an
absence of evidence.

(94.0 MW is this rig's D-D reactor on four heaters and a shared plasma segment, drifting slowly down
across the run and settled inside the gate's 2%. It is not `reactor-logic.lua`'s 56.1 MW equilibrium,
which is a single reactor held full at its own temperature; nothing here rests on the difference.)

## Is one connection enough?

**Yes, with 5× to 19× to spare, and this is what #89 was opened to settle.**

| what is asking | units/tick | megawatts | against one connection's 100 units/tick |
|---|---:|---:|---:|
| eight ordinary exchangers, the shipped row | 5.333 | 320.0 | **18.8× headroom** |
| an unthrottled D-T reactor, this rig's most | 19.924 | 1 195.4 | **5.0× headroom** |
| one `rf-hc-exchanger` at nameplate | 6.667 | 400.0 | 15.0× headroom |

The second row is the one that answers the question, because it is the ceiling on demand rather than
a build: nothing a player assembles can pull harder on that joint than a feed that empties it every
tick, and that still leaves the joint at a fifth of what it carries.

**So the reactor needs no second energy face for throughput.** ADR 0031 item 6 deferred intake width
partly on "#47 measured throughput as near linear in connection count" — true, and irrelevant here,
because the first connection is not full. If intake width is ever taken it will be for a reason other
than this one.

**The one caveat, stated because it is the mechanism rather than a hedge.** A connection's flow is
its 100 units/tick ceiling **scaled by the source box's fill ratio**, so a reactor does not get 6 000
MW out of a nearly-empty box. It does not need to: the box settles at whatever fill makes outflow
equal production, which is what the drain cell shows at 16.1% fill passing 19.9 units/tick. The
ceiling binds only against a reactor producing more than **6 000 MW**, which is six times what the
hardest-driven reactor measured here produces.

## The finding: a D-T reactor sells three times what eight exchangers take

Not a plumbing result, and #89 asks for it to be stated for a follow-up rather than acted on.

`entities.lua:585` puts an ignited D-T reactor at "on the order of 320 MW", and #89's own text
reasons from it — *"an ignited D-T reactor sells on the order of 320 MW, which is eight ordinary
exchangers"*. ADR 0018's throughput bullet quotes no number, and its "row of eight chained
exchangers" is the same figure's consequence. **Measured, on four heaters, it sells 996 MW sustained and peaks at 1 195 MW.** Eight
exchangers is therefore a third of what it makes, not a match for it, and the `chain` cell throws away
**68%** of the reactor's output — visible as its energy box sitting at 97.9% full for the whole run.

Two qualifications, both load-bearing:

- **This is a four-heater reactor, not "the" D-T reactor.** The plasma settles at 597.4 units of the
  reactor's 3 000, fed by four `rf-heater`s at 2.5 units a second each. More heaters is more plasma
  is more power, and where that stops was not measured. The figure is what THIS build produces, and
  the 320 MW it contradicts is a design intent rather than a measurement of a different build.
- **It belongs to [#227](https://github.com/trulsjo/realistic-fusion-refreshed/issues/227)**, which is
  already open on how much one exchanger should drain, and it makes that ticket's arithmetic worse
  rather than better: #227 reasons from the same 320 MW to conclude one high-capacity exchanger is
  enough for D-T. At 996 MW it is two and a half.

**The high-capacity tier's own justification survives it, and gets stronger.** `entities.lua:585`
argues `rf-hc-exchanger` into existence because 320 MW is "eight exchangers and fifty-five turbines
PER REACTOR ... not a difficulty curve, it is a blueprint chore". At 996 MW it is twenty-five
exchangers and about a hundred and seventy turbines. Nothing about that decision is at risk; only
the number in front of it is wrong, and in the direction that made the case understated.

Nothing here is a decision. No number was changed.

## What the two older notes say now

#89 asks that both notes name the figures that describe a leg that no longer exists, and both have
been amended:

- **`fluid-link-throughput.md`** already carried a banner saying the reactor-to-exchanger figures were
  taken with pipe in between. Its closing claim — *"What a bolted joint carries per second is still
  unmeasured"* — is discharged by this note, and the banner now says so and points here. The engine
  matrix itself is untouched and was re-taken above; it was never the stale part.
- **`reactor-runtime-cost.md`** carries one arrangement that cannot be rebuilt: the reactor's energy
  box on a 27 000-unit run of twenty pipes and a storage tank. The paragraph under its table already
  said the reading "is history and is not retakeable"; the table row itself now says so too, which is
  where a reader looking up a number stops.

## Re-running

    pwsh -File scripts/bench-fluid-links.ps1
    pwsh -Command "& ./scripts/bench-mod-links.ps1 -Plasma rf-d-t-plasma -Exchangers 8 -Ticks 252000 -Window 14000"

The second takes about twenty minutes of wall time. **`-Ticks 126000`, the default, is not enough for
D-T**: at 6 000 ticks the rate was still moving 34% a window, and the equilibrium gate refuses to
quote a number until the last two windows agree — which is the gate doing its job rather than an
inconvenience.

Three things #89 changed in `bench-mod-links.ps1`, all of them re-runnable and none of them altering
what a default D-D run does:

- **`-Plasma`** picks the tier. The heater's own input fluid is read off that recipe rather than
  written down, so D-D eats `rf-deuterium` and D-T eats Core's `rf-d-t-mix` with nothing else to
  change.
- **Every exchanger in the row is metered**, not the first alone. The old line watched the machine
  bolted straight to the reactor — the one machine that cannot starve however the chain behaves.
- **The cell pitch is derived** from the reactor's footprint and the row's length rather than being a
  literal 100. It is still exactly 100 at the four-exchanger default; at eight, the literal put the
  last machine through the drain cell's energy feed.

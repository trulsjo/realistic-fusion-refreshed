# Does the converter chain buffer enough with no tank in it?

Measured against **Factorio 2.0.77** by
[`scripts/probe-converter-buffer.ps1`](../../scripts/probe-converter-buffer.ps1) on **2026-09-07**
for [#85](https://github.com/trulsjo/realistic-fusion-refreshed/issues/85), which exists to close the
loose end [ADR 0018](../adr/0018-energy-is-contained-and-no-pipe-carries-it.md) left open when it
took `rf-aneutronic-composite-tank`'s energy-buffering role away.

**Short answer: yes, it buffers enough. A chained row of converters never stalled and never cycled,
and the tank added nothing to what the chain delivered.** The stall-and-restart the argument
predicted did not happen in any cell at any row length. What a short row does do instead is
saturate and throw the reactor's surplus away — and a tank does not fix that either: it fills once,
to 48 333 of its 50 000 units, and contributes exactly nothing afterwards.

## The claim under test

`prototypes/entities.lua`, beside the composite tank, argued its place this way:

> Both aneutronic reactions ignite, and an ignited reactor's output follows its fuel line rather
> than a set rate — so the tier's flows arrive in bursts as heaters catch up and fall behind,
> against a converter that drinks at a fixed hundred units a second. **A buffer between them is what
> turns that into a steady hundred megawatts instead of a converter that stalls and restarts.**

ADR 0018 removed that role and recorded the consequence: with no tank, the buffering is the reactor's
1000-unit output box plus 1000 in every chained converter, and `scale_fluid_usage` means partial
fluid gives partial power rather than a stall. **Whether that sufficed was never measured.**

## The rig

Five cells, each on its own electric network and its own plasma segment, each with its own
`rf-heater` making `rf-d-he3-plasma` — the fuel line is a heater and not an infinity pipe, because
the burstiness under test *is* the fuel line. `scripts/check-aneutronic.ps1` holds its reactor's
plasma at a fixed fill and temperature, which is right for a gate and would have smoothed away the
whole question here.

| cell | converters | tank | chain buffer |
|---|---:|---|---:|
| `long` | 16 | no | 16 000 u in boxes + 1 000 u in the reactor |
| `longtank` | 16 | yes | the same, plus 50 000 u |
| `tight` | 2 | no | 2 000 u in boxes + 1 000 u in the reactor |
| `tighttank` | 2 | yes | the same, plus 50 000 u |
| `open` | 0 | no | none — its output box is emptied by the rig every tick |

`open` is the denominator. `control.lua`'s `apply()` clamps its energy write to the box capacity and
**discards the overflow in silence**, so nothing inside a cell reports what a full box cost; the loss
figures below are measured against what the same reactor sells when nothing can back it up.

Both row lengths are needed because **the chain's buffer *is* the row**. A boxful per converter means
a sixteen-machine row carries a buffer of the same order as the tank, while a two-machine row carries
a twenty-fifth of it. A probe that measured only the long row would have answered the question with a
buffer no player building for this reactor would ever have.

**The reactor is never below two converters' appetite, and its floor owes nothing to its fuel line.**
`capture_efficiency` is 0.95 against 200 MW of confinement heating, so a **cold** aneutronic reactor
already sells 190 units a second — `reactor-logic.lua` says so beside that constant, as the margin
that keeps the tier off perpetual motion — which is 1.9 converters before it fuses at all. One
`rf-heater`'s 5 units of plasma every 2 seconds is what carries it from there to the 485 units a
second it settles at, or 4.85 converters. So the reactor spans about two converters to about five,
and the two rows sit either side of that: sixteen is demand-rich threefold, two is demand-**poor**
the moment it lights.

## What was measured

Thirty minutes, `-Seconds 1800`, `-Heaters 1`. Row power is joules out of every converter, per tick,
from `LuaEntity::energy_generated_last_tick`; the network's own cumulative figure agreed with the
per-tick total to every printed digit in all four cells, and it is the **output** category of
`LuaFlowStatistics` that holds an electric network's generation.

| cell | last-quarter row power | single-tick range at t=1800 s | every converter `working` | stall episodes | ticks with nothing generating | reactor output box full † | reactor status | output lost |
|---|---:|---|---:|---:|---:|---:|---|---:|
| `long` | **483.1 MW** | 469.15 – 492.34 MW | 99.87% | 1 | 0.12% | 0.00% | `working` | **0.00%** |
| `longtank` | **483.1 MW** | 480.30 – 486.35 MW | 99.87% | 1 | 0.12% | 0.00% | `working` | **0.00%** |
| `tight` | **200.0 MW** | 200.00 – 200.00 MW | 99.88% | 0 | 0.12% | 13.25% | `full_output` | **58.60%** |
| `tighttank` | **200.0 MW** | 200.00 – 200.00 MW | 99.88% | 0 | 0.12% | 10.47% | `full_output` | **58.60%** |

Loss is over the **last quarter alone**, which is the figure that matters and not the whole-run one:
a tank absorbs one tankful once, and a whole-run figure credits that one-off against a
whole run's output. Over the whole run `tight` reads 50.17% and `tighttank` 43.43% — a difference
that is entirely the tank filling and none of it a steady saving.

**† The full-box column has a ceiling of 16.67%, not 100%, and 13.25% is a box that never emptied.**
`control.lua`'s `UPDATE_INTERVAL` is 6, so `apply()` tops the reactor's output box up on one tick in
six and the engine drains it on the other five: a reactor in permanent overflow can only be caught
full on a sixth of the ticks. The sample trace is the other half of the reading — it lands on whole
seconds and therefore always on a step tick, and it shows this box at exactly 1000 of 1000 from
t = 480 s to the end of the run. So the trace says when the overflow started and the percentage says
it never stopped. The probe counts the engine's own `entity_status.full_output` beside its own
comparison for this reason, and the two agreed to the printed digit in every cell of both runs.

The single stall episode and the 0.12% of ticks with nothing generating are **all in the first
sample interval**, before the reactor has lit: the first two minutes report 134 dead ticks and every
interval after them reports zero. Nothing stalled once anything was running.

## The three answers

**1. Stall, cycle or steady? Steady.** No cell stalled and no cell cycled. With the row longer than
the reactor can feed, all sixteen converters ran continuously at partial output — `scale_fluid_usage`
does what ADR 0018 said it would, and the row settles at a smooth 485 MW spread across sixteen
machines rather than five machines flat out and eleven dead. With the row shorter, both converters
ran at exactly 100 MW each, tick after tick, with no variation at all.

**The chain's nominal buffer is never used, and that is the interesting part.** At the end of the
long run every converter box in `long` held **0 or 1 unit** of the 1000 it can hold. The 16 000-unit
buffer is not what makes the row steady; the row is steady because sixteen boxes drinking in
proportion to what arrives absorb a lumpy supply without any of them ever having to be a reservoir.

**2. What is lost to a full box?** Nothing, when the row can take the output: `long` lost 0.00% and
its reactor's output box was **never once full** in either run, sitting at 103.5 units of its 1000.
Everything above the row's ceiling, when it cannot:
`tight`'s two converters cap at 200 MW against a reactor selling 485, so **58.8%** of the reactor's
output went in the bin and the engine reported the reactor `full_output` for it. (The half-hour table
above reads 58.60%, because at half an hour the reactor is still 0.4% short of settled; every settled
figure quoted in prose here is the hour run's.) That is a **row length** problem, not a buffering
one.

**3. What is the tank worth?** In delivered energy, nothing.

- On the long row it never filled — it held **247 units of 50 000** at the end, having reached
  equilibrium along with everything else — and both cells delivered the same power to five figures,
  483.1 MW at half an hour and 484.9 at an hour.
- On the tight row it filled to **48 333 units of its 50 000** and stopped, after which the two
  cells' last-quarter losses are identical to two decimal places — 58.60% each at half an hour,
  58.76% each at an hour.

What it does buy, and the one thing it measurably buys, is **ripple**. On the long row the untanked
chain's single-tick power swings 469.15 – 492.34 MW, a 4.8% peak-to-peak band; with the tank on the
end of the row it swings 480.30 – 486.35 MW, a 1.25% band. A quarter of the ripple, bought with 247
units of stored fluid. On the tight row there is no ripple to remove in either cell — a saturated row
is perfectly flat by construction.

## Convergence

The reactor cold-starts thin and lights slowly, so a short run returns a point on the way up that
reads exactly like an equilibrium. The `open` cell's own sale rate, by quarter of the thirty-minute
run:

| quarter | units a second |
|---|---:|
| 1 | 204.3 |
| 2 | 407.4 |
| 3 | 472.4 |
| 4 | **483.1** |

+2.27% between the last two, and the residual is Q3 still carrying part of the climb rather than Q4
still moving: over the last two sample intervals the plasma holds 467.11 then 467.37 units and the
row makes 483.65 then 484.18 MW.

**At fifteen minutes it is not converged.** The same rig run at `-Seconds 900` reports `long` row
quarters of 149.1, 258.9, 375.9 and 438.8 MW, a drift of +16.75%, and a whole-run mean of 305.7 MW
against the 485 the row actually settles at. That is why the probe's default is 1800 seconds, and why
it prints `solddrift` off the drained cell as well as the row's own drift: **a saturated row reports
+0.00% whatever the reactor behind it is doing**, which is the one way this rig could have reported a
settled answer to a question it had not finished asking.

### The cross-check at double the window

`-Seconds 3600`, everything else the same. **Nothing moved.**

| figure | 1800 s | 3600 s |
|---|---:|---:|
| reactor's settled sale rate | 483.1 u/s | **484.9 u/s** |
| its drift over the last quarter (`solddrift`) | +2.27% | **+0.03%** |
| `long` last-quarter row power | 483.1 MW | **484.9 MW** |
| `longtank` last-quarter row power | 483.1 MW | **484.9 MW** |
| `long` single-tick band, peak to peak | 4.8% | **4.7%** |
| `longtank` single-tick band, peak to peak | 1.25% | **1.17%** |
| `long` output lost, last quarter | 0.00% | **0.00%** |
| `tight` output lost, last quarter | 58.60% | **58.76%** |
| `tighttank` output lost, last quarter | 58.60% | **58.76%** |
| `tight` output box full, of a 16.67% ceiling | 13.25% | **14.96%** |
| stall episodes, every cell | 1, all at startup | **1, all at startup** |

Every answer above moves by less than half a percent between the two lengths, so 1800 seconds is
long enough. Four figures move at all, and three of them are the last of the reactor's climb: the
sale rate 483.1 → 484.9 u/s, both rows' power with it, and `solddrift` +2.27% → +0.03% as the climb
leaves the window. The two rows' ripple bands tighten a shade with it, 4.8% → 4.7% and 1.25% →
1.17%, and the full-box percentage rises 13.25% → 14.96% as a fixed 480-second approach is diluted
by a longer run.

The fourth is the only one that moves for its own reason, and it is the **whole-run** loss on the
tanked tight row: 43.43% at half an hour, 51.90% at an hour, against its untanked twin's 50.17% and
54.92%. A single 48 333-unit absorption spread over twice as long a run is worth half as much of it.
That is the tank's one-off showing up as arithmetic, and it is exactly why the last-quarter figure is
the one quoted everywhere above — that one does not move, 58.60% against 58.76%, and the two cells
agree with each other at both lengths.

## What this does NOT settle

- **Whether a contained energy vessel should exist.** That is a decision, it is Truls's, and it needs
  an ADR — one entity beyond [ADR 0010](../adr/0010-v1-module-layout-and-prototype-set.md)'s set. The
  evidence here is that the burstiness argument does not buy one: the chain does not stall, so the
  thing the vessel was wanted for does not happen. A case could still be made on ride-through, which
  is a different argument and is not measured here.
- **Every balance number in it is provisional**, the reactor's 485 MW included. If the tier is
  rebalanced the row length that saturates moves with it, and the loss figures move with that. The
  row length a player should build is likewise not decided here: five converters is what 485 MW pays
  for, and whether the tier is meant to ask for five is a balance question and not this rig's.
- **One heater.** More heaters is a bigger reactor output against the same box volumes, and the
  answer at eight was not measured. `-Heaters` exists so it can be.
- **Ride-through of a supply cut**, which is the one job a 50 000-unit vessel would plainly do and
  the one this rig does not ask about. Nothing here cuts the fuel line or the power.
- **The tank comparison expires.** [#86](https://github.com/trulsjo/realistic-fusion-refreshed/issues/86)
  gives the energy fluids a `connection_category` each, and on that day no tank can hold either fluid
  and the two tanked cells stop being buildable. The untanked cells are bolted faces and nothing
  else, so they survive it unchanged — what expires is the control, not the answer.
- **UPS**, which sixteen converters and a reactor per cell would be a reasonable place to measure and
  which this does not.

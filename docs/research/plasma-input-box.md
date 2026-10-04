# The reactor's plasma box as `input` instead of `input-output`

[#542](https://github.com/trulsjo/realistic-fusion-refreshed/issues/542), following #531.
**Readings for a decision that is Truls's. This note changes no shipped prototype and does not
choose an option.**

The 2.0.77 docs for [`FluidBox`](https://lua-api.factorio.com/2.0.77/types/FluidBox.html) say of
`production_type`: "input-output should only be used for boilers in fluid heating mode."
`rf-reactor` and `rf-aneutronic-reactor` each have an `input-output` plasma box on a boiler in
`output-to-separate-pipe` mode. #531 found what that box does, in
[The rule behind the split](exchanger-coverage.md#the-rule-behind-the-split): every tick the box
pushes plasma back into the segment and pulls it out again. That is why the fuel line is two
stores, and why it fills in 2.3 times the fed model's time.

## How it was measured

`scripts/probe-plasma-input-box.ps1` runs one rig twice. The first run uses `rf-reactor` as it
ships. The second enables a canary mod. In its `data-final-fixes` the canary sets
`data.raw.boiler["rf-reactor"].fluid_box.production_type` to `"input"` and changes nothing else.
Each pipe connection keeps `flow_direction = "input-output"`. The canary refuses to load if the
box is not `input-output` before the change, so a canary that matched nothing cannot read as
"nothing changed".

**The canary is `rf-reactor` itself and not a copy under another name, because `control.lua`
identifies a reactor by name.** `REACTORS` in
`realistic-fusion-refreshed/scripts/entity-management.lua` decides what is registered, and
`SPECS` in `realistic-fusion-refreshed/control.lua` holds its constants.
`check_reactor_specs()` refuses to load when the two lists disagree. A renamed copy would be
built, but nothing would register or step it. So the two variants are two runs of the same rig,
not two reactors in one map.

**The run.** 2026-10-04, Factorio 2.0.77 (build 84539), run with no arguments: 100 000 ticks
per variant, sampled every 4000, so the last row is tick 96 000. D-D, one `rf-heater` per cell
with an unbounded feed, and reactor energy drained as it arrives. Nothing researched: all 11
rungs were asserted off in both runs. The cells are:

- **solo 3** and **solo 6**: one heater, three or six `rf-pipe`, and one reactor. This is
  `probe-plasma-segment.ps1`'s layout.
- **pair**: one heater and three `rf-pipe` into a reactor, then twelve more `rf-pipe` from its
  east face into a second reactor. Only the first reactor has power, which is asserted. This is
  `check-pooling.ps1`'s discriminator: an unpowered reactor steps with zero heating, so any
  heat it holds arrived through the pipe.

The box is read every tick, before and after `control.lua`'s handler. Two rig mods do this, in
the same arrangement `probe-plasma-segment.ps1` uses.

## Readings

### Does it load, and is it stepped?

**The game loads the canary without complaint.** The map was created with exit 0. The create
and the run printed no line containing "warning" or "error", in either variant. At runtime,
`prototypes.entity["rf-reactor"].fluidbox_prototypes[1].production_type` reads `input`.
`control.lua`'s load-time checks passed, because the map was created.

**`control.lua` still steps the canary and writes its box.** Every powered reactor's box changed
across the mod's handler on 15 978 of the 16 001 step ticks up to tick 96 000. That is the same
count as for the shipped box. No box changed on any other tick; if one had, the run would have
failed. The unpowered canary reactor in the pair changed on 205 of the 16 001; see the pair
below.

### One reactor: solo 3 and solo 6

The first column is what the segment beside the box holds, read through the run's first pipe.
The segment reports a capacity of 1300 at three pipes and 1600 at six in both variants.

| tick | shipped, 3 pipes: box | segment | shipped, 6 pipes: box | segment | canary, 3 pipes: box | segment | canary, 6 pipes: box | segment |
|---|---|---|---|---|---|---|---|---|
| 4 000 | 74.27 | 89.14 | 65.49 | 98.25 | 159.37 | 0 | 159.37 | 0 |
| 12 000 | 212.74 | 255.34 | 188.90 | 283.41 | 430.62 | 0 | 430.63 | 0 |
| 24 000 | 398.31 | 478.08 | 356.13 | 534.32 | 785.82 | 0 | 785.84 | 0 |
| 32 000 | 511.85 | 614.31 | 458.68 | 688.12 | 1000.00 | 31.59 | 1000.00 | 31.60 |
| 48 000 | 711.54 | 883.50 | 647.51 | 973.56 | 999.95 | 553.82 | 999.95 | 553.84 |
| 72 000 | 999.94 | 1300.00 | 902.72 | 1427.25 | 999.95 | 1300.00 | 999.95 | 1341.38 |
| 96 000 | 999.95 | 1300.00 | 999.95 | 1600.00 | 999.95 | 1300.00 | 999.95 | 1600.00 |

| | shipped, 3 pipes | shipped, 6 pipes | canary, 3 pipes | canary, 6 pipes |
|---|---|---|---|---|
| first tick the box reads 99.9% | 71 295 | 80 539 | 30 975 | 30 975 |
| box at tick 96 000 | 999.95 | 999.95 | 999.95 | 999.95 |
| box °C at tick 96 000 | 2.4174×10⁸ | 2.4208×10⁸ | 2.3815×10⁸ | 2.3815×10⁸ |

- **With the shipped box, the segment fills alongside it.** The segment held 1200 units for every
  1000 in the box through tick 32 000 at three pipes, and 1500 at six. That ratio rose to the
  capacity as the line filled. These are the figures #520 and #531 recorded.
- **With the canary box, the segment held 0 until the box was full.** Every sampled row read 0
  before then. After that, the line beside the box filled at 128.6 to 134.6 units per 4000 ticks,
  reaching 1300 by tick 72 000 at three pipes and 1600 by 80 000 at six.
- **The canary box fills 2.30 times faster at three pipes and 2.60 times faster at six**
  (71 295 / 30 975 and 80 539 / 30 975), and **the pipe count no longer matters**: the two canary
  boxes never differ by more than 0.03 units. The fed model, `M.settle_fed`, fills its box at
  31 000 ticks and settles at 2.381×10⁸ °C with nothing researched. Both figures are recorded
  in [Why the box fills slower than the fed model](exchanger-coverage.md#why-the-box-fills-slower-than-the-fed-model).
  The canary reads 30 975 and 2.3815×10⁸.
- **The canary box had settled by tick 44 000** and read 2.3814 or 2.3815×10⁸ °C at every row
  after that. The shipped box was still cooling at tick 96 000: 2.4185×10⁸ at 92 000 and
  2.4174×10⁸ at 96 000, at three pipes. This run says nothing about where it ends.
- A full box reads just under 1000 (999.9453 to 999.9469) at every 12 000th tick and 1000 at
  the samples between, in both variants. Why was not looked into.

### Two reactors bridged by pipe: the pair

The pair has three pipes from the heater to reactor 1, then twelve pipes to reactor 2. Only
reactor 1 has power. At both build and tick 96 000, both boxes, the heater's run and the bridge
report **one segment id in both variants**: 9 = 9 = 9 = 9. The segment reports a capacity of
3500.

| tick | shipped: box 1 | °C | box 2 | °C | canary: box 1 | °C | box 2 | °C | canary segment |
|---|---|---|---|---|---|---|---|---|---|
| 4 000 | 30.45 | 3.2713×10⁹ | 30.45 | 3.2151×10⁹ | 79.86 | 3.7253×10⁹ | 82.92 | 1.8779×10⁵ | 0 |
| 24 000 | 174.89 | 1.0184×10⁹ | 174.89 | 1.0036×10⁹ | 373.54 | 9.3651×10⁸ | 500.05 | 15 | 0 |
| 48 000 | 334.10 | 5.2010×10⁸ | 334.10 | 5.1234×10⁸ | 608.54 | 5.4177×10⁸ | 1000.00 | 15 | 0 |
| 72 000 | 487.51 | 3.2454×10⁸ | 487.51 | 3.1921×10⁸ | 999.95 | 2.3819×10⁸ | 1000.00 | 15 | 354.23 |
| 96 000 | 656.50 | 2.0330×10⁸ | 656.50 | 1.9721×10⁸ | 999.95 | 2.3815×10⁸ | 1000.00 | 15 | 1141.77 |

- **Shipped: one pool.** The two boxes hold the same amount to within 0.002 units at every row except
  76 000, where they read 524.17 and 525.47.
  The unpowered reactor stays within 3.0% of the powered one's temperature (1.9721 against
  2.0330×10⁸ at 96 000), which is heat that came through the pipe. Neither box reached 99.9% in
  100 000 ticks. That holds only while the line fills: see
  [Once the shipped line is full](#once-the-shipped-line-is-full-the-unpowered-reactor-falls-to-the-floor). The segment held 2164.29 of its 3500 at tick 96 000.
- **Canary: one segment, but not one pool of heat.** The plasma still reaches both boxes: until
  tick 48 000, each box takes about half the heater's feed, and the unpowered box fills first at
  47 774. The powered box fills at 61 093. **Heat does not travel.** The unpowered box read
  1.8779×10⁵ °C at 4000 and has read 15 °C at almost every row since. That is the plasma's
  `default_temperature` and the spec's `min_temperature_c` floor, which `check_plasma_bounds()`
  requires to be equal. The two exceptions are 2748 °C at 16 000 and 1.2041×10⁴ at 8000.
  `control.lua` changed that box on only 205 step ticks, against 15 978 for the powered one.
  Once the powered box filled, it settled at 2.3815×10⁸, the same as a solo canary. Between
  48 000 and 61 093 the powered box took all of the feed, and then the segment started to fill.
- At tick 52 000, the canary segment read 0.96 where every other row before 64 000 read 0. That
  single reading is not explained.

### Past tick 96 000, both reactors powered, and a lone box

([#548](https://github.com/trulsjo/realistic-fusion-refreshed/issues/548).) The same probe with
two cells added after the pair, so every cell above is built first and keeps its segment id.
2026-10-04, Factorio 2.0.77 (build 84539), nothing researched (all 11 rungs asserted off in
both runs), sampled every 4000 ticks:

- **both**: the pair again, one heater, three `rf-pipe` and twelve more between the reactors,
  with the second reactor on an electric network of its own (asserted).
- **lone**: no heater, no pipe, no power. An unregistered copy of `rf-reactor`, so
  `control.lua` never steps it, seeded at tick 0 to its box's capacity of 1000 at 15 °C. That
  is the instrument `quality.md`'s 526.3158 was read on: `probe-quality-leak.ps1`'s cold cell.
  The copy is made after the canary, so it carries the variant's box. The runtime prototype
  reads `input-output` in the shipped run and `input` in the canary run.

`pwsh -File scripts/probe-plasma-input-box.ps1` read them to 96 000 ticks, and
`pwsh -File scripts/probe-plasma-input-box.ps1 -Ticks 600000` to 596 000. **The two runs print
the same box, segment and temperature on all 350 rows up to 96 000**, old cells included, so no
reading above moved.

**The settle test** is now the probe's own (`-Settle`, default 10⁻⁴): a temperature has settled
from the first row after which every row reads within 10⁻⁴ of the last row's. The canary solo
boxes pass it from tick 44 000, the figure the readings above give, in both runs.

#### The shipped box settles near the canary's, and is still moving

| 600 000 ticks, 1 heater | first row of the settle test | °C at 596 000 | box at 596 000 |
|---|---|---|---|
| shipped, 3 pipes | 580 000 | 2.382469×10⁸ | 1000.0000 |
| shipped, 6 pipes | 580 000 | 2.383660×10⁸ | 1000.0000 |
| canary, 3 pipes | 44 000 | 2.381386×10⁸ | 1000.0000 |
| canary, 6 pipes | 44 000 | 2.381386×10⁸ | 1000.0000 |

The shipped box passes the test only over its last 16 000 ticks, and has not stopped. At three
pipes it read 2.3986×10⁸ at 200 000, 2.3856×10⁸ at 400 000, 2.3828×10⁸ at 560 000 and
2.3825×10⁸ at 596 000. That is 3×10⁴ °C over the last 36 000 ticks, and the six-pipe box falls
the same 3×10⁴ (2.3840 to 2.3837×10⁸ from 572 000). **So 600 000 ticks give a box that passes
the test 0.05% (three pipes) and 0.10% (six) above the canary's 2.381386×10⁸, still
falling.** Where it ends was not read.

#### Two powered canary boxes on one line settle at the same temperature

| 600 000 ticks, 1 heater, 3 + 12 pipes | box 1 full at | box 2 full at | °C at 96 000, 1 and 2 | first settle row, 1 and 2 | °C at 596 000, both |
|---|---|---|---|---|---|
| canary | 89 651 | 88 694 | 2.3840 and 2.3826×10⁸ | 104 000 and 100 000 | 2.381386×10⁸ |
| shipped | 246 755 | 246 755 | 6.8839 and 6.8839×10⁸ | 592 000 and 584 000 | 2.371960 and 2.396459×10⁸ |

- **Canary: yes.** Both boxes settle at 2.381386×10⁸ at 596 000, the same figure as a solo
  canary box. The segment read 0 at every row until the boxes filled, then 148.45 at 96 000,
  2642.04 at 200 000 and its capacity of 3500 from 236 000. Each reactor is powered and heated by
  its own step here, so this says that each settles at the solo figure. It does not say that heat
  travels between them, which the unpowered pair above says it does not.
- **Shipped, for comparison: no.** The two boxes held the same amount to within 0.0021 units at
  every row except 100 000 (520.65 and 522.40), and the same temperature to the four figures the
  probe prints at every row until they filled at 246 755. From the fill on they draw apart:
  2.4344 and 2.4346×10⁸ at 248 000, 2.4042 and 2.4132×10⁸ at 300 000. At 596 000 they read
  2.3720 and 2.3965×10⁸, 1.0% apart, and both are still falling. Why the full shipped pair
  splits was not looked into.

#### Once the shipped line is full, the unpowered reactor falls to the floor

The 600 000-tick run also read the shipped pair with one reactor powered past 96 000. The two
boxes fill together at 148 946 and 148 939. The unpowered reactor read 3.5294×10⁷ °C at 148 000
and **15 °C at 152 000 and at every row after that**, to 596 000. The powered reactor read
2.3859×10⁸ at 596 000. `control.lua` changed the unpowered box on 24 975 of the 99 334 step ticks.
So the heat this rig reads travelling along the shipped pipe travels only while the line is
filling. Why was not looked into.

#### The lone box

| 600 000 ticks, 0 heaters, 0 pipes | box at 0 | box from 4000 to 596 000 | its segment | °C |
|---|---|---|---|---|
| shipped (`input-output`) | 1000.0000 | 526.3158 | 473.6842 | 15 |
| canary (`input`) | 1000.0000 | 1000.0000 | 0 | 15 |

The shipped copy reproduces `quality.md`'s 526.3158 to the digit, and its segment holds 0.9 of
the box, which is the control row. **The canary box keeps all 1000 it was seeded with**, and its
segment holds nothing at any row. The segment reports a capacity of 1000 in both runs. Neither
box is written by `control.lua`: 0 of 99 334 step ticks.

## The repository's gates under the canary

[#549](https://github.com/trulsjo/realistic-fusion-refreshed/issues/549). 2026-10-04, Factorio
2.0.77, base game only. Each gate was run twice from the same working tree: once as it ships and
once with the canary loaded.

**How the canary was loaded.** It is the mod `probe-plasma-input-box.ps1` writes, copied out by
hand: a directory `rf-input-box-canary/` holding that script's `info.json` fields and its
`data-final-fixes.lua` text, unchanged. Its parent directory was passed to both gates:

```
pwsh -File scripts/check-pooling.ps1 -AlsoModDirectory <dir>
pwsh -File scripts/load-check.ps1    -AlsoModDirectory <dir>
```

`load-check.ps1` already took `-AlsoModDirectory`. `check-pooling.ps1` took no extra mod, so #549
gave it the same parameter, read the same way through `Get-HarnessMods`. It is off by default, and
the run without it is the shipped run. Both gates printed `also loading: rf-input-box-canary`.
The canary refuses to load unless the box is `input-output` before it changes it. Neither gate
reads the plasma box's production type back, so the change itself is the canary's own assertion plus
#542's runtime reading above.

### The pooling check: 23 of 125 checks fail

Defaults: 1801 ticks, a simulation step every 6, a 20-pipe tail on `piped`. Nothing researched:
the rig asserted all 11 rungs off in both runs. The rig has no heater; every cell is seeded and
left to burn down.

**Shipped: `PASS: 125 checks, 0 failures`, exit 0. Canary: `FAIL: 125 checks, 23 failures`,
exit 1.** The rig printed 135 rows, 125 checks and 10 notes. 57 checks and one note read
identically in both runs, including the 11 research rows and every `get_capacity` row: a pipe
still reports the whole run, and a reactor its own box of 1000. 68 checks and 9 notes read
differently. These are the 23 that fail:

| row | shipped | canary |
|---|---|---|
| mix, pair, trio, five, solopipe, bare, piped: every box holds its share of one pool, not its own contents | worst box off its share by 1.89%, 3.23%, 1.89%, 1.02%, 2.22%, 1.88%, 0.839% | 96.7%, 95.2%, 96.8%, 98.1%, 90.9%, 97%, 97%, each worst at an `rf-pipe` |
| mix: and with nothing driving it, the run flattens to one temperature | spread 0.000119% after 180 ticks | 5×10⁷ against 1×10⁶ °C, spread 98% |
| pair, trio, five: and far above the seed, so the pool carried heat to them | 1.18592×10⁸, 7.99052×10⁷, 4.77436×10⁷ °C; 118.6, 79.9, 47.7 times the seed | 15 °C in all three, against a seed of 1×10⁶ |
| pair, trio, five: the powered reactor runs a little above the run, not away from it | 4.1%, 6.5%, 11.4% above | 1.59768×10⁸ against 15 °C in all three |
| idle: and it flattened, so the mixing had finished when the loss was read | 0.000819% apart | 4×10⁶ against 1×10⁶ °C, 75% apart |
| idle: BUT MIXING DOES NOT CONSERVE HEAT | 0.8177 survived, 18.2% destroyed | 1 survived, 0% destroyed |
| over one interval, where the heat enters DOES matter, and monotonically along the run | west 72.19%, middle 71.65%, east 71.10% | 100.00% at all three |
| and the rows had stopped moving before the longest window closed | worst flat to 9.05×10⁻⁷ | worst flat to 0.557 |
| so the gap #40 attributed to writer count is not writer count and not position either | 1.09-point ramp against a 17.8-point gap | -0.00 against -0.0 |
| probe: and the SAME instrument sees the run move once ticks have passed | 12 of 12 other boxes changed 6 ticks later | 0 of 12 |
| solopipe: the SAME single writer loses materially once there is a run to mix across | 75.4% against 94.6% | 100.0% against 100.0% |
| and the three-reactor run loses MORE than mixing alone accounts for | 57.6% against 75.4% | 100.0% against 100.0% |
| and what reaches the pool DEPENDS on what else is plumbed into the run | 57.6% against 67.0% | 100.0% against 100.0% |

These 45 checks still pass, with different figures:

| row | shipped | canary |
|---|---|---|
| solo, solopipe, bare, piped: the run gains most of what its reactors spent, and not all of it | 94.6%, 75.4%, 57.6%, 67.0% arrived | 100.0% in all four; the check's bound is above 0.4 and below 1.02 |
| solo: one reactor with no run to share into keeps nearly all of what it spent | 94.6% | 100.0% |
| pair, trio, five: the pool ran down | 47.33%, 44.64%, 42.68% of capacity left | 80.78%, 75.61%, 71.82% |
| trio, five: every unpowered reactor on the run is at one temperature | 7.99052×10⁷ °C, spread 0.0329%; 4.77436×10⁷, spread 0.059% | 15 °C, spread 0%, in both |
| idle: left flat and alone, the run holds its heat | 0.000898% apart | 0% apart |
| idle: no plasma entered or left the untouched run | 1785.8695 units | 3025 units |
| twopass, onepass, rebased: started from the same state as the other shapes | 1.17974×10⁹ unit-K predicted | 1.08356×10⁹ |
| twopass, onepass, rebased: the three write shapes | 72.2% arrived in each | 100.0% in each |
| onepass, and rebased, against the shipped shape | 72.19% against 72.19% | 100.00% against 100.00% |
| writers1, writers2, writers3, middle, east, reversed: same segment, same fill, same temperature, same total heating | 1785.87 of 4000 units, 44.6% full | 3025 of 4000, 75.6% full |
| the same six: the shipped physics predicts the same gain as every other row | 1.17974×10⁹ unit-K | 1.08356×10⁹ |
| the same six: what arrived | 72.19%, 71.92%, 71.64%, 71.65%, 71.10%, 71.10% | 100.00% in each |
| write order does not matter | 71.10% against 71.10% | 100.00% against 100.00% |
| 2 writers, and 3 writers, keep the MEAN of the positions they occupy | 71.92%, 71.64% | 100.00% in both |
| the shape rows, and the one-writer row, were uneven the instant the writes landed | 3.667×10⁶ against 9.797×10⁵ °C, spread 73.28% | 2.166×10⁶ against 9.588×10⁵, spread 55.73% |
| writer count: and the three-writer row was flat | 1.875×10⁶ °C, spread 0.0000% | 1.361×10⁶, spread 0.0000% |
| seedonce: one seeding pass leaves the run as full as sixty do | 44.6% against 44.6% | 75.6% against 75.6% |

The nine notes are the positional ramp at 6, 12, 30, 60, 120, 240, 480 and 960 ticks, and its
summary. Shipped, the ramp reads +1.089, +0.944, +0.214 and +0.010 points to 60 ticks and -0.000
from 120. Canary, every window reads 100.000% at west, middle and east, a ramp of -0.000.

**What the readings say, and what they do not.** Under the canary the seeded plasma stays in the
reactors' boxes: every row's worst box is a pipe, far off its share, and the seeded runs read
fuller (75.6% where they read 44.6%). Every bookkeeping row reads 100% arrived, because no heat
leaves a box to be lost in mixing. The unpowered reactors read the 15 °C floor, which is #542's
pair reading again, on three row lengths. Whether the seed ever reached the pipes, or the boxes
emptied into them, was not separated: the rig reads totals, not the order things moved in.

### The load check: everything holds

**Shipped and canary both exit 0** and print the same verdict: "prototypes valid, every referenced
asset present, map created, the simulation's fifteen load-time invariants hold". By name, all
fifteen hold under the canary: `check_fuel_rows`, `check_reactor_specs`, `check_plasma_capacity`,
`check_input_flow`, `check_ladder_prototypes`, `check_ladder_clamp`, `check_plant_efficiency`,
`check_plasma_bounds`, `check_signal_ceiling`, `check_every_plasma_burns`,
`check_collector_boxes`, `check_blanket_feed`, `check_energy_outlets`,
`check_reactor_companions` and `check_steam_sinks`. They run in `check_prototypes()` in
`realistic-fusion-refreshed/control.lua`, which refuses to create a map when one fails.

The rest of the gate also read the same in both runs. All 26 contained connections still hold
what the data stage declared, both manifests agree, 9 sockets are at vanilla pipe height,
`check-socket-parts` measured 24 parts and could not measure 6, 4 mockups agree, and no asset is
missing.

**By reading, none of the fifteen looks at the plasma box's production type.** The only
`production_type` test in `control.lua` picks a boiler's steam box by `"output"`.
`check_plasma_capacity` reads box 1's `volume` and nothing else. So the gate holds the prototypes
to the simulation's numbers, and the mixing the simulation relies on is outside what it checks.

### The Lua suites: the canary cannot reach them

**Run:** all six suites under Lua 5.4.6, 962 checks, 0 failures: blanket-energy 49, bremsstrahlung
31, circuit-output 116, further-reactions 44, reactivity 57, reactor-logic 665. The suites load
no prototype, so there is no way to load the canary into them. One run serves both variants.

**Reading:** no module under `realistic-fusion-refreshed/scripts/` names `production_type`.
`M.step` and `M.settle_fed` in `realistic-fusion-refreshed/scripts/reactor-logic.lua` take what a
box holds, not what kind of box it is. One function depends on the shipped box all the same:
`M.settle_segment` hard-codes the `input-output` box's push into the segment and pull back, and
`tests/test-reactor-logic.lua` pins its figures. Under the canary, #542 read a segment at 0 until
the box was full, which `M.settle_segment` does not describe. Nothing the mod runs calls it. So
the pure simulation the mod runs does not depend on the box's production type. The arithmetic the
notes use does, through `M.settle_segment`, and the suites would not notice the change.

## An existing save loaded under the canary

[#550](https://github.com/trulsjo/realistic-fusion-refreshed/issues/550).
`scripts/probe-plasma-box-save.ps1`, run with no arguments on 2026-10-04 against Factorio
2.0.77 (build 84539). It builds two cells on the shipped box: **solo** (one `rf-heater`, three
`rf-pipe`, one `rf-reactor`) and **pair** (the same, then twelve `rf-pipe` to a second,
unpowered `rf-reactor`). That is two heaters, three reactors and eighteen pipes, D-D, with
nothing researched: all 11 rungs were asserted off at build and again at the canary load. The
map is ticked to 80 000 on a headless server, saved with `game.server_save`, and the save is
loaded twice with `--benchmark` for 40 000 ticks each. In the **control** load the canary is
named disabled; in the **canary** load it is named enabled. `--benchmark` never writes a save,
and `game.auto_save` under it wrote nothing, which is why the fill runs as a server.

**The save holds tick 80 001.** `server_save` was called on tick 80 000 and lands a few ticks
later. The server read every tick after it, and its reading on tick 80 001 equals the first
reading of both loads in every figure. `on_tick` runs before the tick's entity update, so a
load's first reading is the state as saved, and its second is the first tick the engine has
moved fluid under the box that run has.

**It loads without complaint.** Both loads exited 0. Neither printed a line naming a warning,
an error, a fluid, the reactor, plasma, a migration or production, so there is no log line about
the box to quote. The canary load's `on_configuration_changed` saw `rf-input-box-canary` added,
and the runtime prototype's `production_type` read `input` there and on its first tick. The
control load read `input-output`.

**The control load reproduces the server's run exactly.** Its first two readings equal the
server's at 80 001 and 80 002 in every figure. Its pair read 656.50 per box and 2164.29 in the
segment at tick 96 000, the figures the pair above recorded at 96 000 from an unsaved run.
Anything that differs in the canary load is the box, not the save.

The segment is read through the first pipe beside each box. Its reading never includes the
box's contents, in either variant: a full solo line reads 1000 in the box and 1300 in the
segment.

| reading | tick | solo box | solo segment | pair box 1 | °C | pair box 2 | °C | pair segment |
|---|---|---|---|---|---|---|---|---|
| saved (server) | 80 001 | 1000 | 1300 | 560.2678 | 2.7088×10⁸ | 560.2678 | 2.6695×10⁸ | 1790.0104 |
| control, next tick | 80 002 | 1000 | 1300 | 560.2699 | 2.7071×10⁸ | 560.2698 | 2.6712×10⁸ | 1790.0063 |
| canary, next tick | 80 002 | 1000 | 1300 | 604.2410 | 2.7074×10⁸ | 604.2411 | 2.6709×10⁸ | 1702.0640 |
| control | 82 000 | 1000 | 1300 | 572.3986 | 2.5899×10⁸ | 572.4000 | 2.5528×10⁸ | 1837.1844 |
| canary | 82 000 | 1000 | 1300 | 1000 | 2.5276×10⁸ | 1000 | 2.5016×10⁷ | 969.1249 |
| canary | 84 000 | 999.9453 | 1300 | 999.9437 | 2.4588×10⁸ | 1000 | 15 | 1029.9657 |
| control | 120 000 | 999.9456 | 1300 | 807.7247 | 1.3966×10⁸ | 807.7276 | 1.2979×10⁸ | 2752.3364 |
| canary | 120 000 | 999.9456 | 1300 | 999.9463 | 2.3962×10⁸ | 1000 | 15 | 2204.7909 |

- **A full solo line is untouched.** All 20 sampled rows from 82 000 to 120 000 read the same in
  both loads, to every printed digit, except the segment id. The solo box at 120 000 reads
  2.4117×10⁸ °C in both, still cooling on the shipped trajectory. A full `input` box and a full
  segment trade nothing, so this says nothing about a line that is not full.
- **The engine rebuilds the segments on load.** The canary load's segment ids are 3 and 7 where
  the save's were 1 and 5. The pair's two boxes and its bridge still share one id.
- **The plasma the pair held in common goes into its boxes, and none is lost.** In the first
  tick under the canary, each box took 43.9732 and the segment gave up 87.9464. The cell's
  total, both boxes and the segment, reads 2910.5460 at 80 001 and 2910.5461 at 80 002 in both
  loads. By tick 82 000 both canary boxes are full and the segment is down to 969.12. After that
  the segment refills behind them, as it does in the fresh canary runs above.
- **The heat the unpowered box held does not survive.** Pair box 2 read 2.6695×10⁸ °C when
  saved, 2.5016×10⁷ at 82 000, and 15 °C, the floor, at every row from 84 000 to 120 000. In
  the control load the same box stays within 7.1% of the powered one's temperature (1.2979
  against 1.3966×10⁸ at 120 000). This is the pooling loss the fresh canary pair showed,
  reached from a running save.
  The pair was saved while its line was still filling. The shipped pair run further, in
  [Once the shipped line is full, the unpowered reactor falls to the floor](#once-the-shipped-line-is-full-the-unpowered-reactor-falls-to-the-floor),
  drops to the same 15 °C when its line fills near tick 149 000, so the control load's warmth
  at 120 000 is that of a line still filling.
- **Settled:** the canary's powered box 1 is still cooling at 120 000, at 2.3962×10⁸ °C, moving
  toward the 2.3815×10⁸ a fresh canary box settles at. It moved 0.0026×10⁸ in the last 8000
  ticks. Box 2 has read 15 °C since 84 000.

**Under this repository's rule, the change would count as breaking.** Root `CLAUDE.md` defines
a breaking change as "anything that breaks an existing save", and warns that this kind "breaks
silently and players find out, not the build". The save loads, no plasma is lost, and a full
solo reactor runs as before. But a reactor that a saved plant heats only through the pipe goes
from 2.6695×10⁸ °C to the 15 °C floor within 4000 ticks of loading, and the game logs nothing.
The reading is of a pair saved with its line still filling. A shipped pair whose line is
already full holds its unpowered reactor at 15 °C before any change (#548), and that case was
not loaded. That is a reading of the rule, not a choice between the options below.

## What was not measured

- `rf-aneutronic-reactor`, D-T, the helium-3 plasmas, and any researched state. The canary
  changes `rf-reactor` alone.

## Options

Each option lists what it changes. None is chosen.

1. **Do nothing; keep `input-output`.** Nothing moves. The fuel line remains two stores trading
   through the box's connection, the box fills in 2.3 to 2.6 times the fed model's time, and
   ADR 0011's pooling works while the line fills: a reactor on the run shares heat with its
   neighbours, as the shipped pair shows to 148 000. Once that pair's line is full, its unpowered
   reactor falls to 15 °C (#548). The prototype stays outside the docs' advice for `input-output`, and that
   advice gives no reason. The modelling work in
   [The rule behind the split](exchanger-coverage.md#the-rule-behind-the-split) remains needed,
   because `M.settle_fed` is not what the game does.
2. **Make both reactors' plasma box `input`.** On the one rig measured, the game then does what
   `M.settle_fed` describes: a fill at 30 975 against 31 000, settling at 2.3815×10⁸ against
   2.381×10⁸, with no dependence on pipe count. The segment becomes a queue in front of the box
   rather than a second store. **It ends ADR 0011's heat pooling, which the shipped box keeps
   only while the line fills (#548).** Reactors on one run share feed plasma but not heat, and a
   reactor without power sits at the 15 °C floor beside a hot one. ADR 0011 would need
   superseding. The pooling rows of `check-pooling.ps1`, 23 of whose 125 checks fail under the
   canary (see
   [The repository's gates under the canary](#the-repositorys-gates-under-the-canary)), and the
   comments in `control.lua` that describe box 1 as "the input-output box ADR 0011's fluid
   coupling rests on", would need rewriting. An existing save loads without complaint and loses
   no plasma, but a reactor heated only through the pipe falls to 15 °C, so the change would be
   breaking; see [An existing save loaded under the canary](#an-existing-save-loaded-under-the-canary).
   The aneutronic reactor is unmeasured, but carries the same box.
3. **Make only one reactor `input`.** This splits the fuel-line behaviour by tier, and it is
   possible because the two reactors are separate prototypes. Only `rf-reactor` was measured.
4. **Keep `input-output` and make the model match the game.** This changes no prototype. It
   moves the fed model onto the two-store rule #531 read, which is the work already open in
   `exchanger-coverage.md`, and it keeps pooling. Like option 1, it relies on behaviour the
   docs advise against.

## Sources

- `scripts/probe-plasma-input-box.ps1`, run as described above.
- `scripts/probe-plasma-box-save.ps1`, for the save section.
- [`exchanger-coverage.md`](exchanger-coverage.md): #516, #520 and #531's readings of the
  shipped box and the fed model's figures.
- `docs/adr/0011-per-reactor-simulation-fluid-coupled.md` and `scripts/check-pooling.ps1`, for
  what pooling means here and how it is read.
- [`FluidBox`](https://lua-api.factorio.com/2.0.77/types/FluidBox.html), 2.0.77, checked
  2026-10-04.

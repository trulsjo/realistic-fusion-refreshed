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
  100 000 ticks. The segment held 2164.29 of its 3500 at tick 96 000.
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

## What was not measured

- `rf-aneutronic-reactor`, D-T, the helium-3 plasmas, and any researched state. The canary
  changes `rf-reactor` alone.
- A pair with both reactors powered under the canary. That would show whether two `input` boxes
  that are each heated still converge.
- `scripts/check-pooling.ps1`, `scripts/load-check.ps1` and the Lua suites under the canary.
  `check-pooling.ps1`'s bookkeeping rows test the mixing semantics that `apply()` in
  `realistic-fusion-refreshed/control.lua` is written against. The pair above suggests those
  rows would read differently, but they were not run.
- An existing save loaded under a changed box. Save compatibility is the one place a change
  here breaks silently.
- Where the shipped box's temperature settles. It was still cooling when the run ended at
  96 000 ticks, so only the canary has a settled temperature here.
- A lone box with no pipes, to see what becomes of the 526.3158 that `quality.md` records.

## Options

Each option lists what it changes. None is chosen.

1. **Do nothing; keep `input-output`.** Nothing moves. The fuel line remains two stores trading
   through the box's connection, the box fills in 2.3 to 2.6 times the fed model's time, and
   ADR 0011's pooling works: a reactor on the run shares heat with its neighbours, as the
   shipped pair shows. The prototype stays outside the docs' advice for `input-output`, and that
   advice gives no reason. The modelling work in
   [The rule behind the split](exchanger-coverage.md#the-rule-behind-the-split) remains needed,
   because `M.settle_fed` is not what the game does.
2. **Make both reactors' plasma box `input`.** On the one rig measured, the game then does what
   `M.settle_fed` describes: a fill at 30 975 against 31 000, settling at 2.3815×10⁸ against
   2.381×10⁸, with no dependence on pipe count. The segment becomes a queue in front of the box
   rather than a second store. **It ends ADR 0011's heat pooling.** Reactors on one run share
   feed plasma but not heat, and a reactor without power sits at the 15 °C floor beside a hot
   one. ADR 0011 would need superseding. The pooling rows of `check-pooling.ps1`, and the
   comments in `control.lua` that describe box 1 as "the input-output box ADR 0011's fluid
   coupling rests on", would need rewriting. Save compatibility is untested. The aneutronic
   reactor is unmeasured, but carries the same box.
3. **Make only one reactor `input`.** This splits the fuel-line behaviour by tier, and it is
   possible because the two reactors are separate prototypes. Only `rf-reactor` was measured.
4. **Keep `input-output` and make the model match the game.** This changes no prototype. It
   moves the fed model onto the two-store rule #531 read, which is the work already open in
   `exchanger-coverage.md`, and it keeps pooling. Like option 1, it relies on behaviour the
   docs advise against.

## Sources

- `scripts/probe-plasma-input-box.ps1`, run as described above.
- [`exchanger-coverage.md`](exchanger-coverage.md): #516, #520 and #531's readings of the
  shipped box and the fed model's figures.
- `docs/adr/0011-per-reactor-simulation-fluid-coupled.md` and `scripts/check-pooling.ps1`, for
  what pooling means here and how it is read.
- [`FluidBox`](https://lua-api.factorio.com/2.0.77/types/FluidBox.html), 2.0.77, checked
  2026-10-04.

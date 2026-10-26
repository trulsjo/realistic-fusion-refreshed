# What reactors sharing a run keep of their heating on Factorio 2.1

## Current figures

Each row is a figure this note currently stands behind, copied from the section named. A change to
a figure below changes its row here in the same commit (docs/agents/code-review.md).

| Figure | Value | Measured | Game version | Research state | Section |
|---|---|---|---|---|---|
| Unregistered reactors, one rig write to the westmost at 50 times the seed: share of the added heat the run holds from the write to 60 ticks on, one reactor with 20 pipes and three bridged | 100.0000% in both | 2026-10-26 | 2.1.23 | unresearched (all 11 rungs asserted off) | [The engine alone](#the-engine-alone) |
| The same three, two rig writes in turn, each worked out before either landed | 87.5000%, as replayed | 2026-10-26 | 2.1.23 | unresearched (all 11 rungs asserted off) | [The engine alone](#the-engine-alone) |
| Three bridged reactors, all powered, one step: share kept with one, two and three registered | 100.00%, 87.50% and 77.08% | 2026-10-26 | 2.1.23 | unresearched (all 11 rungs asserted off) | [The writers](#the-writers) |
| Five bridged reactors, all powered and registered, one step: share kept | 75.23% | 2026-10-26 | 2.1.23 | unresearched (all 11 rungs asserted off) | [More reactors](#more-reactors) |
| Two bridged reactors, the west one powered: share kept with the west one written first and with the east one written first | 53.10% and 111.08% | 2026-10-26 | 2.1.23 | unresearched (all 11 rungs asserted off) | [The write order](#the-write-order) |

## The question

([#792](https://github.com/trulsjo/realistic-fusion-refreshed/issues/792).) #791 measured, on
2.1.23, what share of one simulation step's heat a run of `rf-pipe` keeps. One reactor kept
100.0%, with twenty pipes or none. Three bridged reactors kept 77.1%, and 84.3% with twenty more
pipes. The gain is the sum of amount × absolute temperature over every box on the run, across one
interval. The prediction is `M.step` in `realistic-fusion-refreshed/scripts/reactor-logic.lua`
for each reactor the mod steps. The ticket names three readings:

1. **The writes replace instead of adding.** `update()` in `realistic-fusion-refreshed/control.lua`
   reads every registered reactor's box, steps each, and only then does `apply()` write each
   result with `set_fluid`. Each write is an absolute state worked out from the box as it was
   before any reactor wrote.
2. **The engine loses heat when it mixes**, as the `input-output` box did on 2.0.77.
3. **The sum.** Each box's `get_fluid(1)` reads a share of the segment, and nothing said the shares
   of three reactors add up.

## How it was measured

`pwsh -File scripts/probe-pooling-heat.ps1`, 2026-10-26, Factorio 2.1.23 (build 87750), base game
only, nothing researched (all 11 rungs asserted off), the shipped 6-tick interval. Its report is
`.probe-reports/probe-pooling-heat.txt`. It was run twice that day with the same figures, the
second time with the unit_number replay added.

Every cell is its own run, seeded full at 10⁶ °C for 60 ticks. Every reactor is placed with
`raise_built = false`, and the probe registers the ones a cell steps with
`script.raise_script_built`, in an order it chooses. The stepped cells are read across one interval
from tick 306, a step tick, to tick 312, as #791's bookkeeping rows read them. Each figure is read
twice: as the sum over every box on the run, and as `get_fluid_segment_fluid(1)` on the westmost
reactor, the segment's own reading.

Beside each figure the probe prints what reading 1 predicts. It replays the step's writes in Lua.
Each write replaces its reactor's share of the run, and the run is then shared out by volume at
one temperature. That is how the write cell of
[plasma-input-box.md](plasma-input-box.md#what-a-write-to-the-box-reaches) read a write on 2.1.23.

## Readings

### The engine alone

Unregistered and unpowered reactors, which nothing steps. On tick 306 the probe writes the
westmost reactor at its own amount and 5×10⁷ °C, fifty times the seed. `eng1` is one reactor with
twenty pipes, and `eng3` is three bridged. `eng3x2` is the same three, written twice in turn: the
westmost, then the middle one. Each write is worked out from the run before either landed, as
`update()` works out its writes.

| cell | added, unit-K | replay of reading 1 | kept, from the write to +60 ticks |
|---|---|---|---|
| `eng1` | 4.9×10¹⁰ | 100.0000% | 100.0000%, box sum and segment alike |
| `eng3` | 4.9×10¹⁰ | 100.0000% | 100.0000%, box sum and segment alike |
| `eng3x2` | 9.8×10¹⁰ | 87.5000% | 87.5000%, box sum and segment alike |

Each was read at once and at 1, 2, 5, 10, 30 and 60 ticks, and every reading is the one in the
table.

- **The engine does not lose heat when it mixes.** *Measured*: a write that reached the whole run
  held all of its heat for 60 ticks, on one reactor and on three. Reading 2 is ruled out on these
  runs.
- **The box sum is the segment's own reading.** *Measured*: on `eng3`, `w3` and `five` the sum over
  the boxes and `get_fluid_segment_fluid` agree to the eight digits printed. Each reactor's share is
  its volume's share of the run: 0.2500 on the three-reactor runs, 1000 of 4000 units, and 0.1429 on
  `five`, 1000 of 7000. Each bridge is five `rf-pipe` of 100 units. The confound is ruled out.
- **Two writes in one tick lose what reading 1 says they lose.** *Measured*: `eng3x2` keeps
  87.5000%, the replay's figure. The first write's heat is shared over the run at once, a quarter
  of it in the middle reactor's share, and the second write replaces that share. 1.75 of the 2
  writes' heat is kept.

### The writers

`w1`, `w2` and `w3` are three bridged reactors, all powered, with the westmost one, two and three
registered. `w3` is #791's `bare`.

| cell | registered | predicted, unit-K | gained, box sum and segment | kept | replay of reading 1 |
|---|---|---|---|---|---|
| `solo` | 1 of 1, no pipe | 8.28732×10⁸ | 8.28732×10⁸ | 100.00% | 100.00% |
| `w1` | 1 of 3 | 1.03303×10⁹ | 1.03303×10⁹ | 100.00% | 100.00% |
| `w2` | 2 of 3 | 1.9393×10⁹ | 1.69689×10⁹ | 87.50% | 87.50% |
| `w3` | 3 of 3 | 2.78662×10⁹ | 2.14802×10⁹ | 77.08% | 77.08% |

- **`w3` is #791's figure.** *Measured*: 2.78662×10⁹ predicted and 2.14802×10⁹ gained, the two
  numbers #791 printed for `bare`, so the probe reads what the gate read.
- **The loss grows with the number of writers on a run, and the replay of reading 1 gives every
  figure.** *Measured*. One writer keeps all of it, whatever else is on the run.

### The write order

Two bridged reactors, the west one powered and the east one not, both registered. The west one's
step heats the run and the east one's cools it. `o-ab` registers the west one first and `o-ba`
the east one first. `o-ba-built` is also built east first, so the east reactor has the lower
`unit_number`.

| cell | registered | west, east `unit_number` | kept | replay, registration order | replay, `unit_number` order |
|---|---|---|---|---|---|
| `o-ab` | west, east | 296, 297 | 53.10% | 53.10% | 53.10% |
| `o-ba` | east, west | 305, 306 | 53.10% | 106.90% | 53.10% |
| `o-ba-built` | east, west | 315, 314 | 111.08% | 111.08% | 111.08% |

The `unit_number`s are the second run's. The first run's were 265 and 266, 274 and 275, and 284
and 283, and its kept shares were the same.

- **The kept share depends on the order the mod writes in.** *Measured*: the same two reactors
  keep 53.10% written west first and 111.08% written east first. Written east first, the cooling
  write lands first and the heating one replaces part of it, so the run gains more than the model
  says it should.
- **The mod writes in `unit_number` order, not in the order reactors were registered.** *Measured*
  for these three cells: registering the east reactor first changed nothing, and building it first
  did. *Inferred*: ascending `unit_number`, which is build order. `entities.registry()` in
  `realistic-fusion-refreshed/scripts/entity-management.lua` keys its table by `unit_number`, and
  `update()` walks it with `pairs`. That `pairs` follows the key there is *Inferred* from these
  cells, not read from source.
- `o-ba-built` started its step from a different state, 7.76728×10⁸ predicted against 8.97491×10⁸,
  because its earlier steps ran in the other order too.

### More reactors

`five` is five bridged reactors, all powered and registered, the shape of `check-pooling.ps1`'s
`five`. It kept 75.23%, against 77.08% for three, and the replay of reading 1 gives 75.23%.
*Measured*. Each of the five has a seventh of the run, against a quarter on the three-reactor runs,
so each later write replaces a smaller share of the heat before it. The loss still grows with the
count.

## Which reading the probe supports

**Reading 1, *Measured*.** The engine kept every unit-K a lone write added, for 60 ticks, which
rules out reading 2. The box sum and the segment's reading agree on every run read, which rules
out the sum. A replay of `update()`'s writes, each replacing its reactor's share of a run that is
then shared out by volume, gives every kept share the probe read, to the digits printed: 87.5% and
77.08% for two and three writers, 75.23% for five, and 53.10% or 111.08% by write order.

What follows from it, *Inferred*: a run's kept share is set by how many reactors write to it, the
share of the run each holds, and their order, and so by pipe length. That is #791's 84.3% for
`piped`: the same three reactors with twenty more pipes each hold a smaller share, so less of an
earlier write is replaced. The step can also gain more than it paid for, as `o-ba-built` did, when
a reactor that cools writes before one that heats.

## Options for Truls

**Readings for a decision that is Truls's. This note chooses none of them.** The options are the
ticket's. Each carries what the probe found for it.

- **Accept and document it.** Shared runs lose part of the heating, or gain some, by order. No code
  changes. The probe says the size of the error depends on writer count, each reactor's share of
  the run and build order, so a player's line is off by an amount the tooltip cannot state as one
  figure: from 100% for one reactor to 75.23% for five, and above 100% where a reactor that cools
  writes first.
- **Write a change, not a state.** `apply()` would add the step's change with `add_fluid` and take
  it out with `remove_fluid`, instead of setting the result. *Inferred* from the engine cells: a
  write's heat is kept whole and shared out at once, so changes would add up whatever the order,
  if an added amount at another temperature mixes the way a write does. That was not measured
  here: no cell adds fluid. It is the cell to read before choosing this option. A step burns
  plasma as well as heating it, so the change is two calls, and `remove_fluid` takes an index and
  an amount and no temperature (*Read from source*: the 2.1.23 `runtime-api.json`).
- **Step the run once.** Group the registered reactors by `get_fluid_segment_id(1)`, step each
  segment as one pool with the reactors' payments summed, and write the segment once. The probe
  says one writer per run keeps 100%, on `solo` and `w1`. That is Lua tracking connectivity,
  which ADR 0011 was written to avoid.
- **Bring an assertion back.** Whichever is chosen, `check-pooling.ps1` could assert the kept share
  against a bound again. The probe says what a bound has to allow for under the first option: the
  order of the writes moves the share by about 58 points on a pair.

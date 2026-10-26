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
| Two bridged reactors from one state, the west one powered: share kept with the west one written first and with the east one written first | 58.56% and 101.44% | 2026-10-26 | 2.1.23 | unresearched (all 11 rungs asserted off) | [The write order](#the-write-order) |

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
`.probe-reports/probe-pooling-heat.txt`, the run of 19:11.

Every cell is its own run, seeded full at 10⁶ °C for 60 ticks. Every reactor is placed with
`raise_built = false`, and the probe registers the ones a cell steps with
`script.raise_script_built`, in an order it chooses. The stepped cells are read across the step on
tick 306, from tick 305 to tick 311, so the window holds that step and no other whichever of the
two `on_tick` handlers runs first. Each figure is read twice: as the sum over every box on the run,
and as `get_fluid_segment_fluid(1)` on the westmost reactor, the segment's own reading.

**`realistic-fusion-refreshed`'s `on_tick` runs before the probe's.** *Measured*: `solo`, which
has no pipe and so moves only when the mod steps it, read a different heat on tick 306 from tick
305. #791's bookkeeping rows read on a step tick, after that tick's step, so their window held the
next step. Their three-reactor figure was 77.1%, the share `w3` keeps here.

Beside each figure the probe prints what reading 1 predicts. It replays the step's writes in Lua.
Each write replaces its reactor's share of the run, and the run is then shared out by volume at
one temperature. That is how the write cell of
[plasma-input-box.md](plasma-input-box.md#what-a-write-to-the-box-reaches) read a write on 2.1.23.

## Readings

### The engine alone

Unregistered and unpowered reactors, which nothing steps. On tick 305 the probe writes the
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
| `solo` | 1 of 1, no pipe | 8.33944×10⁸ | 8.33943×10⁸ | 100.00% | 100.00% |
| `w1` | 1 of 3 | 1.03532×10⁹ | 1.03532×10⁹ | 100.00% | 100.00% |
| `w2` | 2 of 3 | 1.94582×10⁹ | 1.70258×10⁹ | 87.50% | 87.50% |
| `w3` | 3 of 3 | 2.79818×10⁹ | 2.15692×10⁹ | 77.08% | 77.08% |

- **`w3` keeps #791's share.** *Measured*: 77.08%, where #791's `bare` kept 77.1% across the next
  step, 2.14802×10⁹ of 2.78662×10⁹ predicted.
- **The loss grows with the number of writers on a run, and the replay of reading 1 gives every
  figure.** *Measured*. One writer keeps all of it, whatever else is on the run.

### The write order

#792 asked for two reactors whose plasma differs before the step. On a 2.1 run both boxes read one
plasma, so the probe makes the two steps differ by what each reactor is paid instead. Two bridged
reactors, the west one powered and the east one not, both registered: the west one's step heats
the run and the east one's cools it. `o-ab` registers the west one first and `o-ba` the east one
first. `o-ba-built` is also built east first, so the east reactor has the lower `unit_number`.

The three are registered on tick 299, one step before the step read. `spend()` in `control.lua`
pays only a reactor `update()` has stepped, so the step on tick 300 pays neither reactor and
leaves all three cells in one state. The step read is their second.

| cell | registered | west, east `unit_number` | predicted, unit-K | kept | replay, registration order | replay, `unit_number` order |
|---|---|---|---|---|---|---|
| `o-ab` | west, east | 265, 266 | 1.12594×10⁹ | 58.56% | 58.56% | 58.56% |
| `o-ba` | east, west | 274, 275 | 1.12594×10⁹ | 58.56% | 101.44% | 58.56% |
| `o-ba-built` | east, west | 284, 283 | 1.12594×10⁹ | 101.44% | 101.44% | 101.44% |

- **The kept share depends on the order the mod writes in.** *Measured*: the same two reactors,
  from one state and with one prediction, keep 58.56% written west first and 101.44% written east
  first. Written east first, the cooling write lands first and the heating one replaces part of
  it, so the run gains more than the model says it should.
- **The mod writes in `unit_number` order, not in the order reactors were registered.** *Measured*
  for these three cells: registering the east reactor first changed nothing, and building it first
  did. *Inferred*: ascending `unit_number`, which is build order. `entities.registry()` in
  `realistic-fusion-refreshed/scripts/entity-management.lua` keys its table by `unit_number`, and
  `update()` walks it with `pairs`. That `pairs` follows the key there is *Inferred* from these
  cells, not read from source. The comment on `update()` in `control.lua` says reading first
  "makes every reactor's step independent of the order entities.registry() happens to iterate
  in". That holds for what each step computes. What the run keeps of the steps does depend on it.

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
77.08% for two and three writers, 75.23% for five, and 58.56% or 101.44% by write order.

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
  figure: 100% for one reactor, 75.23% for five, 58.56% for a pair where one heats and one cools,
  and above 100% where the one that cools writes first.
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
  order of the writes moves the share by about 43 points on a pair that starts from one state.

# 42. On Factorio 2.1, reactors on one run share heat, and the plasma box stays `input`

Date: 2026-10-25

## Status

Accepted. **Decided by Truls, 2026-10-25**, in a grilling on the three options #776 recorded,
and posted as
[his pick on #767](https://github.com/trulsjo/realistic-fusion-refreshed/issues/767#issuecomment-6397680113).

**Amends [ADR 0040](0040-the-plasma-box-is-input.md)** for Factorio 2.1:

- its point 1 stands;
- its point 2's box stands, on a reason of its own, since on 2.1 half of the reason ADR 0040 gave
  is false and the other half has not been read;
- its point 3 is reversed;
- its point 4 stays as the record of #740;
- its point 5's readings were taken on 2.0.77. On 2.1, D-T was read by #776 and build order is
  [#778](https://github.com/trulsjo/realistic-fusion-refreshed/issues/778)'s.

ADR 0040 is not rewritten. It carries a dated note pointing here, and so does
[ADR 0011](0011-per-reactor-simulation-fluid-coupled.md), whose "one pool" clause holds again.

## Context

Every 2.1.23 figure here was measured by `scripts/probe-plasma-input-box.ps1 -NoCanary -Reach`, and
the same with `-Plasma rf-d-t-plasma`, on 2026-10-25, on Factorio 2.1.23 (build 87750), with
nothing researched. The readings, and the three options this ADR chooses between, are in
[`plasma-input-box.md`'s On Factorio 2.1.23](../research/plasma-input-box.md#on-factorio-2123).
The 2.0.77 figures beside them are that note's earlier readings, each with its own day.

- **On 2.1.23 the `input` box is a share of its fluid segment.** A `set_fluid` on it reaches an
  `rf-pipe` or an infinity pipe on its face in the same call. It does not reach a heater bolted to
  the box, whose box has no segment. On 2.0.77 the `input` box's segment held nothing until the
  box was full, so a write stayed in the box.
- **Two reactors on one run are one pool again.** In both pairs and in both runs, the two boxes
  read the same amount and temperature at every row. That includes the reactor with no power:
  198.03 units at 1.695219×10⁹ °C in the D-T pair at tick 96 000. On 2.0.77 under the `input` box
  that reactor read 15 °C.
- **The fill depends on pipe count.** A D-D box alone on its line first reads 99.9% at tick
  40 207 with three pipes and at 49 448 with six. On 2.0.77 under `input` it read 30 975 at both.
  The settled state still matches `M.settle_fed`: 2.3814×10⁸ °C at three pipes and 2.3815×10⁸ °C
  at six, against the model's 2.381×10⁸ °C.

ADR 0040 point 2 gave one reason for `input`: under it "the fill does not depend on pipe count
or on build order". On 2.1.23 the first half is false. The second has not been measured on 2.1.

## Decision

1. **On 2.1, reactors on one run pool.** They share the engine's fluid segment. Heat travels along
   the run, an unpowered reactor reads its neighbours' temperature, and the fill depends on pipe
   count. ADR 0040's point 1 already says that whatever the engine does with the shared fluid is
   the coupling. *Inferred* from the reach cells: keeping each reactor's heat its own on 2.1 means
   taking the box out of the segment, and so working around the engine on every step. ADR 0040
   rejected that for #569's option 3.
2. **The plasma box stays `input`** on `rf-reactor` and on `rf-aneutronic-reactor`, with no
   prototype change. It is what ships and what the 2.1.23 readings were taken on. Whether `input`
   and `input-output` behave differently on 2.1 has not been measured. If they do, this point goes
   back to Truls.
3. **ADR 0040's point 3 is reversed on 2.1.** An unheated reactor on a run beside a heated one is
   not cold. It reads its neighbours' temperature.
4. **`M.settle_fed` is unchanged.** On 2.1 it gives the settled state and not the fill time. That
   is documented, and the fill is not modelled. The tracked `.lua` and `.ps1` files that call it
   are the model's own and `tests/test-reactor-logic.lua`, so no gate reads a fill time against the
   game (searched 2026-10-25).
5. **The move to 2.1 is breaking for a save in two ways this ADR names.** An unpowered reactor on
   a run pools heat, and the fill depends on pipe count. #767's `BREAKING CHANGE:` footer is to
   name both. *Inferred* from the probe's fresh maps: no 2.0 save has been loaded on 2.1.
6. **Before the first portal release,
   [#778](https://github.com/trulsjo/realistic-fusion-refreshed/issues/778) reads five things on
   2.1**: build order, `input` against `input-output`, the D-D pair to a full and settled line, both
   aneutronic reactions, and an unpowered reactor on a full line. The readings change only the
   text, apart from `input` against `input-output`, which point 2 already sends back to Truls if
   the two differ.

## Considered options

The options are `plasma-input-box.md`'s, under "Options for the mod". This ADR takes option 1,
which that note words as superseding ADR 0040. It amends ADR 0040 instead, since point 1 stands.

- **Write the segment rather than the box** (option 2), with `set_fluid_segment_fluid`. Rejected.
  *Inferred*, not measured: the line would take the step's result and not a mix. But two
  reactors on one run would each write the shared segment once a step, so the result would
  depend on the order they are stepped in.
- **A box that joins no segment** (option 3). The plasma box would have no pipe connection, and
  the feed would be moved across by script, through a linked connection or into a box of another
  kind. Rejected. *Inferred* from the heater cell, where the write stayed in the box: it would
  give back ADR 0040's behaviour. But it changes how a player plumbs a reactor and how
  [ADR 0018](0018-energy-is-contained-and-no-pipe-carries-it.md)'s containment is held, to win
  back an outcome point 1 says is not owed.
- **Supersede ADR 0040 entirely.** Rejected: point 1 is the principle this decision rests on, and
  would be restated for nothing.
- **A dated note on ADR 0040 and no ADR.** Rejected: that would reverse a decision without one.

## Consequences

- **#767 carries this ADR and the prose it makes true.** That is:
  - the `rf-reactor` descriptions in `realistic-fusion-refreshed/locale/en/d-d.cfg`;
  - `GLOSSARY.md`'s **Fluid-coupled** and **Cold-parked**;
  - the comments in `realistic-fusion-refreshed/control.lua`, `prototypes/entities.lua` and
    `prototypes/fluids.lua` that say reactors share the feed and not the heat.

  What a player is told states the mechanism and its main effect, and no figure: reactors on one
  run share one plasma line, so heat travels along it, and a reactor without power stays as hot as
  its neighbours.
- **`scripts/check-pooling.ps1` is rewritten in
  [#771](https://github.com/trulsjo/realistic-fusion-refreshed/issues/771)**, the ticket that ports
  it. It will assert shared heat: both boxes on a run read the same amount and temperature
  within a tolerance, the unpowered reactor's included, and no fill time. Until then its help
  describes ADR 0040's box, and the gate does not run on 2.1.
- **The rigs' plasma feed is
  [#777](https://github.com/trulsjo/realistic-fusion-refreshed/issues/777)**, which blocks the rig
  ports. An `at-least` infinity pipe resets a segment at another temperature on 2.1.23, so the
  rigs' feed undoes every step. That holds whatever this ADR decided.
- **Dated records are kept as they are**: ADR 0040's own text, its readings in
  `plasma-input-box.md`, and the comments that say what the `input-output` box did until #740.

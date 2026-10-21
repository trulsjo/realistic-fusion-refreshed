# 40. The plasma box is `input`, and fluid coupling shares feed, not heat

Date: 2026-10-20

## Status

Accepted. Settles [#551](https://github.com/trulsjo/realistic-fusion-refreshed/issues/551), the
plasma box's production type, and
[#569](https://github.com/trulsjo/realistic-fusion-refreshed/issues/569), what ADR 0011 says about
a full line. **Decided by Truls, 2026-10-20**, in one grilling session that took #551 first because
#569's answer depended on it. Built on 2026-10-21: #740 made both boxes `input` and #741 rewrote
the pooling check. Point 5's readings, D-T included, are in `plasma-input-box.md`'s
[Under the shipped `input` box](../research/plasma-input-box.md#under-the-shipped-input-box).

**Amends [ADR 0011](0011-per-reactor-simulation-fluid-coupled.md)**, whose per-reactor decision
stands. What changes is its clause that reactors on one run share "one pool, one mixed temperature";
ADR 0011 carries a dated note pointing here.

## Context

Every game figure in this section was measured on Factorio 2.0.77 with nothing researched, between
2026-10-04 and 2026-10-14, by the probes [`plasma-input-box.md`](../research/plasma-input-box.md)
names; each figure's day is in that note's `## Current figures` table. `M.settle_fed`'s figure is
the model's, run outside the game. "The canary" is the shipped reactor with its plasma box changed
to `input` for those runs, and nothing else changed.

Both reactors carry their plasma box as `input-output` on a boiler in `output-to-separate-pipe`
mode. #531 found that box trades with its segment through its one connection, at most 100 units a
tick each way, so a fuel line is two stores
([`exchanger-coverage.md`](../research/exchanger-coverage.md#the-rule-behind-the-split), measured
2026-10-04). A D-D
reactor alone on its line fills 2.30 times slower than under `input` at three pipes and 2.60 times
at six, and settles at the same 2.381512×10⁸ °C either way. Under `input` the box first reads 99.9%
at tick 30 975 at both pipe counts (#542), against `M.settle_fed`'s 31 000, and two reactors on one
run share a segment but not heat. #558 and #559 found that the shipped box pools heat only while
the line has room. Once the line is full, a full box and a full segment stop trading, and an
unheated reactor beside them reads 15 °C from tick 150 012 in a pair built 1H2. Built 12H or 2H1,
the unheated box stays at 1.083×10³ to 1.303×10⁴ °C on the full line instead (#583), for a reason
not measured.

## Decision

1. **Fluid coupling names the mechanism, not an outcome.** Reactors on one run share whatever the
   engine's fluid system gives them. It does not promise that neighbours keep an unheated reactor
   warm.
2. **Both reactors' plasma box becomes `input`.** The game moves to the model rather than the model
   to the game. *Inferred* from the solo fills above, which match at three and six pipes, and from
   a full line's dependence on build order: under `input` the fill does not depend on pipe count or
   on build order, neither of which a player can reason about. Point 5 measures the build-order
   half. `rf-aneutronic-reactor` changes with `rf-reactor`, so there is one fill model and one
   meaning of fluid-coupled.
3. **An unheated reactor is cold on any line, full or not.** That answers #569 by its option 4,
   letting #551 settle it: once heat does not travel, a full line is not a special case. *Inferred* from the canary pair above, whose
   unpowered box shares no heat, measured on D-D, D-He3 and He3-He3 and not on D-T.
4. **The change is breaking.** A save loads under `input` without complaint and loses no plasma,
   but on a pair whose line is still filling, the reactor heated only through the pipe falls from
   above 10⁸ °C to 15 °C within 6000 ticks of the load (#550 and #561, Factorio 2.0.77, unresearched;
   #550's on 2026-10-04 and #561's on 2026-10-05). The commit carries the `!` and a `BREAKING CHANGE:` footer.
   *Inferred* from those loads, in which the box's type changed under a saved map and nothing
   needed rewriting: no migration is needed.
5. **Before it ships**, D-T is read under `input`, since no canary run reached it, and a D-D pair is
   read built 12H and 2H1, to confirm the build-order effect of #583 goes with the box.

## Considered options

The numbered options of #551 are those of `plasma-input-box.md`'s `## Options`; #569's are its own.

- **Keep `input-output` and document it** (#551's option 1, #569's option 1). Rejected: the fill
  stays unmodelled, and a full line's behaviour stays dependent on build order.
- **Keep `input-output` and move `M.settle_fed` onto the two-store rule** (#551's option 4).
  Rejected: the model would track the game, but the game would still depend on pipe count and build
  order. *Inferred* from point 2: the modelling work open in `exchanger-coverage.md` for that rule
  is no longer needed.
- **`input` on one reactor only** (#551's option 3). Rejected: two fill models and two meanings of
  the coupling, to keep D-He3 heat travelling while a line fills, which point 1 says is not owed.
- **Stop the step cooling an unheated reactor** (#569's option 2). Rejected: a plasma above the
  floor that neither radiates nor leaks contradicts
  [ADR 0021](0021-the-floor-is-where-the-model-stops.md).
- **Keep a full line trading** (#569's option 3). Rejected: engine behaviour worked around every
  step.

The 2.0.77 docs' advice that `input-output` "should only be used for boilers in fluid heating mode"
(*Read from source*: the 2.0.77
[`FluidBox`](https://lua-api.factorio.com/2.0.77/types/FluidBox.html) page, read 2026-10-20) was
weighed as advisory, not decisive: the gates read the behaviour directly.

## Consequences

- The pooling check's rows are rewritten to assert shared feed, unshared heat and an unheated box at
  15 °C, in at least one cell that reaches a full line. That absorbs
  [#574](https://github.com/trulsjo/realistic-fusion-refreshed/issues/574). By
  `plasma-input-box.md`'s account, not re-run here, 27 of its 125 checks fail under the canary since
  #565, and 36 since #575.
- When the box ships, the current statements that reactors on a run share heat are rewritten with
  it; dated records, such as ADR 0010's note, ADR 0018's #44 paragraph and
  `reactor-runtime-cost.md`, are kept as they are. Those found on 2026-10-20 are the help of
  `scripts/check-pooling.ps1` ("really do work from a single pool"), the
  `rf-reactor` descriptions in `realistic-fusion-refreshed/locale/en/d-d.cfg` ("share one pool at
  one temperature"), the comments in `control.lua` (box 1 as "the input-output box ADR 0011's fluid
  coupling rests on", and `update()`'s on writing the plasma back), in
  `realistic-fusion-refreshed/prototypes/entities.lua` and `prototypes/fluids.lua`, the help of
  `scripts/check-breeding.ps1`, and `GLOSSARY.md`'s **Fluid-coupled**, which loses "at one mixed
  temperature".
- A bank where one reactor rides on its neighbours is not available, as ADR 0011 already said of
  scale.

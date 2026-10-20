# 40. The plasma box is `input`, and fluid coupling shares feed, not heat

Date: 2026-10-20

## Status

Accepted. Settles [#551](https://github.com/trulsjo/realistic-fusion-refreshed/issues/551), the
plasma box's production type, and
[#569](https://github.com/trulsjo/realistic-fusion-refreshed/issues/569), what ADR 0011 says about
a full line. **Decided by Truls, 2026-10-20**, in one grilling session that took #551 first because
#569's answer depended on it. Nothing below has been built yet.

**Amends [ADR 0011](0011-per-reactor-simulation-fluid-coupled.md)**, whose per-reactor decision
stands. What changes is its clause that reactors on one run share "one pool, one mixed temperature";
ADR 0011 carries a dated note pointing here.

## Context

Both reactors carry their plasma box as `input-output` on a boiler in `output-to-separate-pipe`
mode. #531 found that box trades with its segment every tick, so a fuel line is two stores and
fills in 2.3 to 2.6 times `M.settle_fed`'s time, though it settles where that model says. #542
measured `input`: the line fills at 30 975 ticks against the model's 31 000, at any pipe count,
and reactors on one run share a segment but not heat. #558 and #559 found that the shipped box
pools heat only while the line has room: a full box and a full segment stop trading, and an unheated
reactor beside them falls to 15 °C — in cells built 1H2, though built 12H or 2H1 it does not
(#583), for a reason not measured. The readings are in
[`plasma-input-box.md`](../research/plasma-input-box.md).

## Decision

1. **Fluid coupling names the mechanism, not an outcome.** Reactors on one run share whatever the
   engine's fluid system gives them. It does not promise that neighbours keep an unheated reactor
   warm, and a reactor without heaters of its own is not a design the mod supports.
2. **Both reactors' plasma box becomes `input`.** The game moves to the model rather than the model
   to the game: the fill no longer depends on pipe count or on build order, neither of which a
   player can reason about. `rf-aneutronic-reactor` changes with `rf-reactor`, so there is one fill
   model and one meaning of fluid-coupled.
3. **An unheated reactor is cold on any line, full or not.** That answers #569: a full line is not
   a special case once heat does not travel.
4. **The change is breaking.** A save loads intact and loses no plasma (#550, #561), but a reactor
   heated only through the pipe falls to 15 °C on load. The commit carries the `!` and a
   `BREAKING CHANGE:` footer. No migration is needed.
5. **Before it ships**, D-T is read under `input`, which no canary run reached, and a D-D pair is
   read built 12H and 2H1, to confirm the build-order effect of #583 goes with the box.

## Considered options

- **Keep `input-output` and document it** (#551's option 1, #569's option 1). Rejected: the fill
  stays unmodelled, and a full line's behaviour stays dependent on build order.
- **Keep `input-output` and move `M.settle_fed` onto the two-store rule** (#551's option 4).
  Rejected: the model would track the game, but the game would still depend on pipe count and build
  order. The modelling work open in `exchanger-coverage.md` for it is no longer needed.
- **`input` on one reactor only** (#551's option 3). Rejected: two fill models and two meanings of
  the coupling, to keep D-He3 heat travelling while a line fills, which point 1 says is not owed.
- **Stop the step cooling an unheated reactor** (#569's option 2). Rejected: a plasma above the
  floor that neither radiates nor leaks contradicts
  [ADR 0021](0021-the-floor-is-where-the-model-stops.md).
- **Keep a full line trading** (#569's option 3). Rejected: engine behaviour worked around every
  step.

The 2.0.77 docs' advice that `input-output` is only for boilers in fluid heating mode was weighed as
advisory, not decisive: the gates read the behaviour directly.

## Consequences

- The pooling check's rows are rewritten to assert shared feed, unshared heat and an unheated box at
  15 °C, in at least one cell that reaches a full line. That absorbs
  [#574](https://github.com/trulsjo/realistic-fusion-refreshed/issues/574). 27 of its 125 checks
  fail under the canary today.
- The comments in `control.lua` that call box 1 "the input-output box ADR 0011's fluid coupling
  rests on" are rewritten, and `GLOSSARY.md`'s **Fluid-coupled** loses "at one mixed temperature"
  when the box ships.
- "Build a bank where one reactor rides on its neighbours" is not available, as ADR 0011 already
  said of scale.

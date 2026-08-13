# 4. Fresh code, with the predecessors as reference

Date: 2026-08-13

## Status

Accepted. Resolves
[Choose the upstream base](https://github.com/trulsjo/realistic-fusion-refreshed/issues/5).

## Context

Three candidates, all three now actually read — the four-module redesign in
`docs/research/predecessor-survey.md`, and Durikkan's port and the 1.1 original in
`docs/research/port-and-original-inspection.md`.

| | Redesign | Port 1.9.2 | Original 1.8.18 |
|---|---|---|---|
| Factorio | 1.1 | 2.0, migration verified clean | 1.1 |
| Lua | ~8.7k, Core+Power already split | 7,077, single mod | 6,820 + 2,595 compat |
| Core/Power split | already done | closed loop, no clean cut | closed loop |
| Real-time simulation | yes | no | no |
| Tech tree | **none** — every technology file commented out with `--TODO` | intact | intact |
| Locale | **none** in any module | intact | intact |
| CC BY-NC-ND boiler | present, guarded | present, **unconditional** | present, guarded |
| Extra licensed directories | +2 (NC-ND numerals, GPLv3 K2 icons) | none | none |

Each inherited option carried a distinct defect:

- **The redesign** has the shape this project decided on and the only real-time simulation, but is an
  unfinished 1.1 prototype: no tech tree, no locale, never observed running, and the most
  licence-contaminated of the three trees.
- **The port** is working, verified-clean 2.0 code in the wrong shape. Its single mod cannot be cut
  along the Core/Power line that
  [ADR 0002](0002-v1-scope-and-module-split.md) requires — the tech tree crosses both ways
  (`rfp-gs-process-1/2/3` require `rfp-d-d-fusion` and the breeding technologies, so Core would depend
  on Power) and the reactors *are* the breeder, D-D fusion returning tritium and He-3 as by-products
  (`recipes.lua:17-21`). It also requires the NoDerivatives boiler unconditionally at `data.lua:36`.
- **The original** is the port minus Durikkan's migration, so choosing it means redoing work already
  done, for the sake of a compatibility-patches tree that can be consulted without being inherited.

## Decision

**v1 is written fresh.** The three predecessors are reference material, not a base.

Material may still be lifted deliberately and selectively, under
[ADR 0001](0001-liftable-predecessor-material.md) — a permissive directory is free, copyleft goes in
its own directory with its licence file, and NonCommercial or NoDerivatives material is never taken.
The distinction is that lifting becomes a per-file choice made with the rule in hand, rather than a
tree inherited wholesale along with whatever it contains.

`RFP-2.0/RFP-2.0.txt` — the physics derivation with 16 numbered academic sources, unit conversions and
the intended progression — is WTFPL and is the single most valuable thing in the archive. It is
reference of exactly the kind this decision keeps.

## Consequences

- **The ADR 0002 tension dissolves.** The closed-loop finding was about cutting existing code along a
  seam that does not exist in it. Writing fresh, the two-mod Core/Power shape is built in from the
  start, so that decision stands unchanged and becomes easier rather than harder.
- **The CC BY-NC-ND boiler stops being a problem to work around.** All three candidates ship it; none is
  inherited, so there is nothing to strip. Any boiler in v1 is this project's own.
- **Nothing inherits the unfinished parts** — no 2,519 commented-out lines, no missing locale, no
  1.1→2.0 migration debt, no dangling `mods["Krastorio2"]` branches left behind by a compatibility
  strip.
- **This is the most work of the four options**, and that cost is accepted rather than discovered later.
  Nothing exists until it is written.
- **The real-time simulation is not inherited.** Whether v1 simulates fusion or drives reactors from
  recipes is now an open design decision rather than a consequence of the base, and graduates to its own
  ticket.
- Attribution to Romner_set, Durikkan and PreLeyZero still applies to anything derived from their work,
  per `CLAUDE.md` — a norm here, not a licence obligation.

## Alternatives considered

**Port as base, redesign as reference.** The strongest inherited option: working 2.0 code, with the
redesign's split as a restructuring guide. Rejected — restructuring a closed loop into two mods is
open-ended work on someone else's design, and it would have put ADR 0002 back in question.

**The redesign as base.** Would have supplied the split and the simulation. Rejected on the shape of what
remains: migrating ~8.7k lines of 1.1 code that was never finished, reviving a tech tree from
commented-out files of unknown quality, and writing locale from scratch — for a codebase nobody has seen
run. Romner's own judgment on the 2.0 situation was that it needed a ground-up rewrite.

**The 1.1 original as base.** Rejected — it is the port minus a migration that already exists.

# 13. The reactor is fifteen tiles square

Date: 2026-08-16

## Status

Accepted. Amends [ADR 0010](0010-v1-module-layout-and-prototype-set.md), which calls its prototype
set "a starting specification, not a contract" and asks to be amended by a superseding ADR rather
than drifted from. Closes the reactor's half of
[#45](https://github.com/trulsjo/realistic-fusion-refreshed/issues/45).

Decided by Truls. Recorded here because it is a decision, not a consequence of one.

## Context

The reactor and the heat exchanger were the same building in two tints — both `table.deepcopy` of
vanilla's heat exchanger, 3x2, distinguishable only by colour. #45 replaced the icons with Krastorio
2 art, so they differ in hand, in map view and in alerts, and left them identical on the ground,
which is where a player actually looks. The in-world sprite was deferred with a note saying it was
not a repoint like the pipes were.

That note was right about the reason. Krastorio 2's `kr-fusion-reactor` is
`collision_box = {{-7.25, -7.25}, {7.25, 7.25}}`, `selection_box = {{-7.5, -7.5}, {7.5, 7.5}}`, and
its `fusion-reactor.png` is 1100x1100 drawn at `scale = 0.5` for exactly that footprint. Krastorio 2
has no building shaped 3x2 to borrow instead. So there were three ways to a reactor that looks like
a fusion reactor, and they are not variations on each other:

1. Grow the footprint to the art's.
2. Crop or rescale the art to the footprint.
3. Find or commission art drawn for a 3x2 building.

## Decision

**The footprint follows the art: `rf-reactor` becomes 15x15, using Krastorio 2's own boxes.** The
sprite then lands where it was drawn to land, with no rescaling and no recompositing.

**The heat exchanger stays 3x2 and stays vanilla-shaped.** It is a heat exchanger; vanilla's is the
right size and shape for one, and the pair is now unmistakable at a glance.

**The pipe connections move to the new edge**: plasma in at west `{-7, 0}` and east `{7, 0}`, reactor
energy out at north `{0, -7}`. Whole tiles rather than the halves a 3x2 needed, because fifteen is
odd. West and east both remaining `input-output` is what ADR 0011's shared fluid segment rests on and
is unchanged.

**The graphics definitions live in `RealisticFusion/graphics/krastorio-2/buildings/`, not in
`prototypes/`.** Krastorio 2's mod is LGPLv3 as well as its assets, and every dimension in that file
is read off its `prototypes/buildings/fusion-reactor.lua`, so the file is a derivative of LGPLv3 code
and has to sit where the licence beside it applies. That is `legal-note.txt`'s per-directory rule
applied to Lua rather than to a PNG, which is what CLAUDE.md means by "everything is governed per
directory — Lua included".

## Consequences

- **This breaks saves.** An existing `rf-reactor` occupies 3x2 and the prototype now claims 15x15;
  Factorio will not reconcile that. There is no migration and there should not be one — the mod is
  pre-1.0, unpublished, and nothing is owed to a save from before it had graphics.
- **A reactor is now a landmark rather than a machine on a bus.** Thirty tiles of pipe between two
  reactors on the same run, where it used to be six. That is a real balance change and it was not
  measured, because there is nothing yet to measure it against: the layouts this mod is meant to
  produce do not exist. Worth revisiting when they do.
- **The reactor animates constantly**, where Krastorio 2's animates only while crafting. A boiler
  has no `working_visualisations`; it has `fire` and `fire_glow`, driven by its own burning state,
  and this boiler's conversion is deliberately neutered to 1 W so the simulation can own the
  physics. Tying the one thing visible from across the map to a number chosen to be meaningless
  would be worse than a reactor that hums when it is cold, and what it is actually doing is on its
  status line and its two signals. Revisit if [#43](https://github.com/trulsjo/realistic-fusion-refreshed/issues/43)
  or [#44](https://github.com/trulsjo/realistic-fusion-refreshed/issues/44) stops it being a boiler.
- **The signals combinator grew with it**, since it copies the reactor's selection box, and its wire
  reach is now computed from that box rather than left at the vanilla combinator's 9 — which is
  short of the corner of a 15x15 building at 10.6 tiles. See
  [ADR 0012](0012-reactor-signals-need-a-companion-entity.md).
- **Two of Krastorio 2's layers are not taken**: the steam plumes, which are
  `working_visualisations` with per-plume shifts and no boiler field to hang them on, and the water
  reflection, which is worth nothing to a building nobody will place on a shoreline.
- **The other six machines are still vanilla shapes**, and #45 stays open for them. They are a
  smaller problem than this one was: most are 3x3 assembling machines, and Krastorio 2 has 3x3
  buildings.
- **This is not a decision about what a reactor is.** #43 and #44 ask whether it should stay a
  boiler at all, and a `reactor`-type prototype would bring its own graphics fields. Nothing here
  forecloses that; it changes two boxes, three pipe positions and a picture set.

## Alternatives considered

**Crop the art to 3x2.** No gameplay change and no save break, and it makes the repository the
author of a derivative LGPLv3 sprite that reads as a cropped nine-tile building — paying a licensing
cost for a worse result.

**Wait for #43 and #44.** Defensible, and it was the standing plan. Rejected because the reactor and
the heat exchanger being the same building on the ground is a real problem now, and #43 and #44 are
not close.

**Art drawn for a 3x2 building.** Clean provenance and the right size, and nothing on disk to build
it from. Not ruled out for a later tier.

# The Figma "Factorio Buildings" reference: who made it, its licence, and what it shows

Examined 2026-10-27 for [#798](https://github.com/trulsjo/realistic-fusion-refreshed/issues/798),
whose hold waited on a session seeing it. Truls chose it as the reference for the second attempt at
denser rendered art. On 2026-10-26 he settled that it is a **style target only**: nothing is traced
or lifted from it.

The file is the Figma prototype
<https://www.figma.com/proto/y1IQG08ZG2jIeJ5sTyF4MP/Factorio-Buildings?node-id=14934-304>, viewed
without signing in to Figma, through Claude in Chrome. No frame was downloaded, and nothing from it
is committed here.

## Who made it, and its licence

- **Licence: CC BY**, from the banner on every frame: *"Free to use under the conditions of CC BY
  license"*. *Measured* 2026-10-27. The banner names no CC BY version, and none was found
  elsewhere in the file.
- **Author: Hurricane046.** The file credits no one: scrolled top to bottom on 2026-10-27, and
  no name or link was found. The name is *read from* mods that reuse the set and attribute it,
  and is not graded by this note: [Unified Chemical
  Plant](https://mods.factorio.com/mod/unified-chem-plant) says *"Graphics assets by Hurricane046,
  used under CC BY license"* (read 2026-10-27). The search that found it also returned a mod-portal
  discussion asking for Hurricane046 to be credited, and a UFO asset pack doing so. Neither of
  those was opened.

CC BY permits reuse with attribution. That is a different question from what the reference is for,
and the second is Truls's (#798).

## What the frames show

Seen 2026-10-27, at the size Figma draws them, which is far larger than 32 screen px per tile.
Each card gives a footprint (4×4 to 9×9) and a frame count (60 to 128), and is grouped under a set,
*Others* or *Deprecated*. *Deprecated* includes a 6×6 Fusion Reactor.

Set against the five gaps the 2026-10-26 baseline found on `rf-isotope-collector` beside
Krastorio 2's reactor (#798), the reference goes further on each:

- **Surface wear** dominates: rust, chipped paint and grime on every face. This is texture rather
  than shape, which is the part ADR 0043's CC0 textures are for.
- **Hoses**: corrugated runs, yellow and dark, wrap most machines and are the largest single
  element on several.
- **Hazard yellow** appears as whole housings, such as a yellow tank on the Fuel Refinery. That is
  more than this house style's marking rule allows.
- **Repeated modules** appear as stacked cylinders, ringed casings and bolt rows.
- **Inset panels** are present but secondary to the above.

That ordering is *inferred* from those frames. It is a reading by eye and was not counted.

## Animation

With *Show animations* on, two frames a second apart differ on the Cybernetics Facility. Its ring
and the blue glow inside it move, and the glow's brightness changes. The Fuel Refinery's frames
differ only in the coloured glow in its nozzles. *Measured* 2026-10-27, by eye on those two
buildings only.

## What this does not settle

- How the frames read at 32 screen px per tile. Nothing was rescaled or measured here: #799 does
  that.
- Which CC BY version applies, and what attribution the author asks for.

## What Truls decided on seeing it

Two decisions, 2026-10-27:

- **It stays a style target only**, though its licence would permit reuse. Its sprites would
  replace the render pipeline (ADR 0030) rather than feed it, and none of the set is a fusion
  machine except the deprecated reactor.
- **Hoses and looms move ahead of inset panels** in #798's order, because the frames lean on them
  more. #803 now goes before #802.

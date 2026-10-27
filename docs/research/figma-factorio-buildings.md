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
  no name or link was found. The name comes from one mod that reuses the set and attributes it,
  and a portal description has no grade: [Unified Chemical
  Plant](https://mods.factorio.com/mod/unified-chem-plant) says *"Graphics assets by Hurricane046,
  used under CC BY license"* (read 2026-10-27, quoted). The search that found it also returned a
  mod-portal discussion asking for Hurricane046 to be credited, and a UFO asset pack doing so.
  Neither was opened.

CC BY permits reuse with attribution. That is a different question from what the reference is for,
and the second is Truls's (#798).

## What the frames show

Seen 2026-10-27, at the size Figma draws them, which is far larger than 32 screen px per tile.
The cards seen gave footprints from 4×4 to 9×9 and frame counts from 60 to 128. Two of the set
banners read *Others* and *Deprecated*, and *Deprecated* includes a 6×6 Fusion Reactor. Not every
card was seen whole: the window showed two and a half columns.

#798 lists five gaps the session read by eye in the 2026-10-26 baseline, on `rf-isotope-collector`
beside Krastorio 2's reactor. Here is the reference set against each, read by eye on 2026-10-27
and not counted:

- **Value range**: dark bodies with bright worn edges, close to Krastorio 2's range.
- **Marking colour**: hazard yellow on whole housings, such as a yellow tank on the Fuel Refinery.
  That is more than this house style's marking rule allows.
- **Repeated modules**: stacked cylinders, ringed casings and bolt rows.
- **Organic runs**: corrugated hoses, yellow and dark, wrap most machines and are the largest
  single element on several.
- **Inset panels**: present, but less prominent than the hoses.

A sixth thing, not among the five: **surface wear** (rust, chipped paint, grime) on every face.
That is texture rather than shape, which is the part ADR 0043's CC0 textures are for.

Which of these weighs most is *inferred* from the frames above and was not counted.

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
  replace the render pipeline (ADR 0030) rather than feed it. Of the cards seen, only the
  deprecated reactor is a fusion machine.
- **Hoses and looms move ahead of inset panels** in #798's order, because the frames lean on them
  more. #803 now goes before #802.

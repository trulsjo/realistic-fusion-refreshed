# House style — DRAFT for #246, react before trusting

The one text every machine's look note is read under. It fixes what the whole set shares; a look
note says only what is particular to its machine. Written for the full machine set, not for the
five mockups, because the Krastorio 2 art is slated to go if this route works (Truls, 2026-09-04).

## What the set is

A fusion plant, not a foundry. Clean, heavy, engineered. Things are big because the physics is
big, not because they are ornate. Nothing rusts, nothing is bolted on as an afterthought.

## Palette

| Role | Colour (linear RGB) | Where |
|---|---|---|
| Body steel | 0.30 0.33 0.38 | painted panels, the bulk of every machine |
| Frame | 0.12 0.13 0.15 | base slab, structural edges, anything that carries weight |
| Bare metal | 0.55 0.55 0.58, metallic 0.8, roughness 0.35 | pipes, flanges, drums, anything a fluid runs through |
| Energy accent | 1.00 0.45 0.10 | every surface that carries **reactor energy** |
| Steam accent | 0.85 0.88 0.90 | every surface that carries **steam** |
| Water accent | 0.25 0.55 1.00 | every surface that carries **water** |
| Plasma accent | 0.55 0.20 1.00 | every surface that carries **plasma** |
| Glow | the accent of the fluid, emission 3.0, only while working | see Glow |

One accent per fluid, used the same way on every machine, so a player reads a machine's plumbing
from its colours before reading its tooltip. An accent is a band or a manifold, never a whole body.

## Materials

Principled BSDF only, procedural, no image textures, nothing imported (the licence rule). Painted
steel is roughness 0.6, metallic 0. Bare metal is roughness 0.35, metallic 0.8. Bevel every visible
edge at 0.03 tiles so the key light catches it; a sharp edge reads as a rendering artefact at 64 px
per tile.

**Nothing is geometrically perfect** (Truls, 2026-09-04). A drum carries rib bands and a weld seam
and is not a plain cylinder; a pipe between two parts sags or bends a little and may be corrugated;
a panel has seams and a rivet line. Detail is added in that order until the surface stops reading
as plastic beside vanilla, and stops before it reads as Krastorio 2's density.

**Walls are optional.** Where a machine has internals worth seeing, the body is an open frame of
beams with the internals visible through it, not a closed box. Closed panels are used where the
machine would have them for real: a manifold, a cabinet, a pressure vessel.

## Proportion and detail

- One Blender unit is one tile. The body sits inside the **collision box**, not the selection box.
- Height: a 5-wide machine stands 1.5 to 2.5 tiles tall. A 15-wide one may reach 4. Nothing is
  taller than it is wide.
- Every machine has a **base slab**: frame colour, 0.25 tiles tall, filling the collision box. It is
  what makes the set read as one plant on mixed ground.
- Detail floor: nothing smaller than 0.125 tiles (8 px). Panels, seams and bolts below that vanish
  or shimmer.
- Symmetry is broken on purpose at least once per machine so the four rotations are told apart.

## Connections

Every pipe connection gets a **socket** baked into the structure: a bare-metal stub of radius 0.3
tiles from the body to the footprint edge on the connection's tile, with one accent band of the
fluid it carries. Vanilla's `pipe_covers` cap the stub when nothing is joined (#240). Boilers and
generators bake sockets into every direction sheet; no separate pipe picture.

## Camera, light, output

Fixed by #239 and #243, not by taste: orthographic, pitched 45°, looking north; one hard sun from
the west at about 42° elevation, shadows east; ambient fill from a grey world at low strength so
the camera-facing wall is not black; render 64 px per tile, shipped at `scale = 0.5`; structure,
shadow (opaque black) and glow as separate sheets; the frame is the footprint plus a 2-tile margin
so the shadow and the height fit; `shift` zero. Vertical factor: **open**. A first look preferred B (no stretch) on a bare cube and A on the
building; the vanilla comparison sheet in #246 is where it is judged, and the game is where it is
settled.

## Glow

A glowing part is emissive in the model and is rendered to its own sheet with everything else
black. The game draws that sheet only while the machine works, on a separate core prototype
(#241). The glow is always the accent colour of the fluid doing the work, and it glows where that
fluid *is*: the reactor-energy manifold and the lines feeding from it, never the steam side.

## Moving parts

Not built yet (#241 research, animation deferred). A look note may still name a part that could
move later, such as a pressure relief valve, so the model puts it where an animation could reach it.

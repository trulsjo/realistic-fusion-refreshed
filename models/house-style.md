# House style

Accepted from the third draft of #246 (Truls, 2026-09-04). The one text every machine's look note is
read under. It fixes what the whole set shares; a look
note says only what is particular to its machine. Written for the full machine set, not for the
five mockups, because the Krastorio 2 art is slated to go if this route works (Truls, 2026-09-04).

## What the set is

A fusion plant, not a foundry. Clean, heavy, engineered. Things are big because the physics is
big, not because they are ornate.

**TOWARDS KRASTORIO 2, NOT AWAY FROM IT** (Truls, 2026-09-13, on seeing rf-isotope-collector stand
beside rf-reactor in a real map for the first time -- `scripts/probe-isotope-collector-art.ps1`).
More colour, more texture, and **more connected machinery even where there is no clear reason for
it**: conduit, trunking, a run that goes somewhere off the machine, kit that reads as part of a
plant rather than as a labelled box. The Krastorio 2 reactor next to it is black, yellow, red-hot
and dense, and our own machine read as pale and flat beside it -- two mods rather than one.

This REVERSES two sentences that stood here, and both are named rather than silently edited:

- *"nothing is bolted on as an afterthought"* is withdrawn. Machinery that exists because a plant
  has machinery is now wanted. What it does not license is a sprite that lies: a socket where no
  connection is declared still misleads a player, and the rule under Palette that an accent belongs
  only to a machine carrying that fluid is untouched.
- *"stops before it reads as Krastorio 2's density"*, under Materials, is withdrawn with it. That
  sentence set the ceiling in the wrong place and this is the new direction of travel.

*"Nothing rusts"* went earlier and not by this decision: rf-heat-exchanger's manifold is corroded
in patches on purpose (#252), because it is hot, wet and outdoors. The line is dropped here because
it was already untrue, not because 2026-09-13 changed it.

**HAZARD YELLOW IS ALLOWED, AND IS NOT A BODY COLOUR** (Truls, 2026-09-13, revising his own answer
of an hour before, which was no yellow at all). The correction is worth keeping because it names the
real rule: *"all yellow machines are not the goal. I don't think k2 uses yellow universally either"*
-- and it does not. Krastorio 2's fusion reactor is yellow-heavy; most of its machines carry a guard,
a lifting point or a warning plate in yellow and are otherwise grey.

So yellow is a MARKING colour here. It goes on guards, lifting points, warning plates, walkway edges
and kerbs -- the things that are yellow on a real plant because somebody has to see them. It is never
a body, never a whole panel, and never more than a few small elements on one machine. It is also not
a fluid accent and must never be used as one: the accents say what a socket carries, and a marking
colour competing with them would cost the set the one thing its colours are for.

HOW FAR IS NOT SETTLED. This is a direction, not a target, and no machine has been rebuilt to it
yet. The detail floors under Materials are unchanged and still bind: more detail is wanted, detail
too fine to read at 64 px per tile still is not.

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
| Tritium accent | 0.50 1.00 0.60 | every surface that carries **tritium** |
| Helium-3 accent | 0.80 0.45 1.00 | every surface that carries **helium-3** |
| Hazard yellow | 0.72 0.55 0.09 | guards, lifting points, warning plates, kerbs -- **markings only**, never a body |
| Glow | the accent of the fluid, emission `rf_blender.GLOW_EMISSION`, only while working | see Glow |

One accent per fluid, used the same way on every machine, so a player reads a machine's plumbing
from its colours before reading its tooltip. An accent is a band or a manifold, never a whole body.

**The last two are the fluids' own icon colours** (Truls, #262), and `scripts/ship-check.ps1`
section 8 holds the three copies of each together (#334) -- this row, the fluid, and every build
script's `PALETTE`. Change one and it names the other two rather than letting them drift. They are
taken straight from `realistic-fusion-refreshed-core/prototypes/fluids.lua` rather than picked: the
by-products have an established colour a player already reads in a pipe, and the socket should agree
with it. The first four were picked for the role instead. Reactor energy, steam and water are roles
before they are fluids; **plasma cannot follow the new rule at all**, because one accent covers
four fluids whose own icon colours are orange, green, blue and magenta -- there is no single pipe
for it to agree with.

**Helium-3's violet is near the plasma accent** -- 0.80 0.45 1.00 against 0.55 0.20 1.00 -- which
the isotope collector does not have to resolve, since it carries no plasma. A machine that carries
both will.

**An accent belongs only to a machine that carries the fluid.** Obvious from the table's own "every
surface that carries X", and stated because it was broken within a week of being written: the
isotope collector's control cabinet took a blue panel from the heat exchanger's, which is right on
a machine with water sockets and a lie on one without. A screen or an indicator that belongs to no
fluid is `dark` or `paint`, not a borrowed accent.

## Materials

Principled BSDF only, procedural, no image textures, nothing imported (the licence rule). Painted
steel is roughness 0.6, metallic 0. Bare metal is roughness 0.35, metallic 0.8. Bevel every visible
edge at 0.03 tiles so the key light catches it; a sharp edge reads as a rendering artefact at 64 px
per tile.

**Nothing is geometrically perfect** (Truls, 2026-09-04). A drum carries rib bands and a weld seam
and is not a plain cylinder; a pipe between two parts sags or bends a little and may be corrugated;
a panel has seams and a rivet line. Detail is added in that order until the surface stops reading
as plastic beside vanilla. It used to stop "before it reads as Krastorio 2's density"; that
ceiling was withdrawn on 2026-09-13 -- see What the set is.

**Walls are optional.** Where a machine has internals worth seeing, the body is an open frame of
**H-beams** with the internals visible through it, not a closed box, and decks are gratings.
Closed panels are used where the machine would have them for real: a manifold, a cabinet, a
pressure vessel, an end wall the camera can see.

**Grime is procedural.** Every painted and bare-metal surface carries a noise-driven darkening
and roughening; accents stay clean so they read.

**A per-surface gradient must be driven by something that survives rotation.** Any effect that
varies over a surface -- grime gathering low, rime gathering high -- needs a term saying which way
the surface faces, and the obvious choice is wrong. Blender's **Generated** texture coordinates are
the object's own bounding box in *local* space and take no notice of its rotation, while the build
scripts here make every cylinder along local Z and turn the object afterwards. Drive a gradient
from Generated and every rotated part gets it along its own axis: on the isotope collector that put
the frost on one *end* of both drums, all three socket stubs and all four dished ends. It survived
three rounds of looking at renders, because a drum with a frosted end is not an obviously
impossible object. **Use the surface normal's world Z** (`ShaderNodeNewGeometry` -> Normal -> Z),
which is the same number whichever way the part was built and turned, and which says what these
effects actually mean: how far the surface faces up. `mat` in
`models/isotope-collector/build.py` carries the worked version.

## Proportion and detail

- One Blender unit is one tile. The body sits inside the **collision box**, not the selection box.
- Height: a 5-wide machine stands 1.5 to 2.5 tiles tall. A 15-wide one may reach 4. Nothing is
  taller than it is wide.
- Every machine has a **base slab**: frame colour, 0.25 tiles tall, filling the collision box. It is
  what makes the set read as one plant on mixed ground.
- **Two detail floors, because a cut feature and a raised one read by different means.** A
  **cut detail** -- a groove, a seam, a weld bead -- reads by the shadow line cut into it, so
  contrast does the work and it survives being very thin. A **raised detail** -- a rivet, a bolt, a
  band, a strut -- reads by its own lit silhouette against what is behind it, and needs enough
  pixels to be a shape rather than a speck.

  | | on the player's screen | tiles | sheet px |
  |---|---:|---:|---:|
  | cut detail | 1.6 px | 0.05 | 3.2 |
  | raised detail | 1.9 px | 0.06 | 3.8 |

  **The unit is the player's screen**, not the sheet: a sheet is 64 px to the tile and ships at
  `scale = 0.5`, so one tile is 32 screen pixels and that is the only resolution anyone looks at.

  **The floor governs the dimension that carries the read**, not the smallest dimension: a rivet's
  diameter, a torus's minor DIAMETER, an H-beam's flange width, a groove's width. Measure the
  smallest instead and the rule condemns the H-beam web, which is edge-on at this camera and never
  the thing anyone sees -- and H-beams are this document's own named element. So that a groove's
  smallest dimension IS its width, **cut every groove at least as deep as it is wide**; a shallow
  wide channel casts a weaker shadow line, which is the whole reason a cut feature reads at all.

  ~~Nothing smaller than 0.125 tiles (8 px). Panels, seams and bolts below that vanish or
  shimmer.~~ **Superseded on measurement, 2026-09-13 (#335).** That figure was four times vanilla's
  median detail and above vanilla's 90th percentile: as written it forbade nearly all of Factorio's
  own art, and 261 of the 369 features on our two machines -- every seam, groove, rib band, bolt and
  rivet among them, and it named bolts. It was also stated in sheet pixels. Both floors above are set AT what two machines already
  ship, with vanilla finer still below them. `docs/research/detail-floor.md` has the numbers, the
  five vanilla sheets they came from, what the method cannot see, and the script to rerun it.
- Symmetry is broken on purpose at least once per machine so the four rotations are told apart.

## Connections

Every pipe connection gets a **socket** baked into the structure: a bare-metal stub from the body
to the footprint edge on the connection's tile, with one accent band of the fluid it carries.

**A SOCKET A PLAYER CAN PLUMB IS DRAWN LIKE THE PIPE THAT PLUGS INTO IT** -- height and thickness
both, and both are measured rather than chosen (Truls, 2026-09-13 and 2026-09-14). It was radius
0.3 at height 0.55 on both machines that had one, and the join was a visible step: the stub stood
0.367 tiles higher on screen than the pipe and drew a quarter thicker.
`scripts/probe-socket-height.ps1` is the rig that showed it and took the numbers below.

The arithmetic, stated because the easy version of it is wrong. This camera maps depth 1:1 and
height by 0.707, so a tube's circular cross-section draws as an ellipse:

- its centre sits `0.707 z` above the ground line, the radius terms cancelling;
- its screen height is `2 r sqrt(1 + 0.707^2)` = `2.449 r`. **Not** `3.414 r`, which is what taking
  the topmost and bottommost points of the tube independently gives -- those two points are not the
  silhouette's extremes.

Vanilla's pipe (`base/graphics/entity/pipe/pipe-straight-horizontal.png`, scale 0.5 and no shift,
so 64 px to the tile and directly comparable with ours) draws its body **0.609 tiles tall, centred
0.023 tiles above the ground line**. Solving the two expressions against those gives **z = 0.033**
and **r = 0.249**, and the collector measures 0.594 tiles against vanilla's 0.609 after both.

**THE SHIPPED z IS STILL 0.044, AND THAT IS A KNOWN DEFECT RATHER THAN THIS PARAGRAPH BEING STALE.**
The centre was read as 0.031 when the rule was written -- the bare row indices `(43 + 81) / 2 = 62`
against an image centre of 64, mixing the index convention with the edge convention the rest of the
measurement uses -- and `z` was solved from that. Since #355 `tools/check-socket-height.py` measures
the reference off vanilla's own sheet rather than carrying a number, so the disagreement is in the
open and the gate reports it. Every plumbable socket is therefore drawn 0.0109 tiles of world height
too high, which is 0.49 px on the sheet and 0.25 px at the game's own zoom.
[#356](https://github.com/trulsjo/realistic-fusion-refreshed/issues/356) is where the models follow
the number, because doing it re-renders both machines and changes art that has been accepted.

**THE SOCKET GOES THROUGH THE FLOOR, AND THE FLOOR GETS A HOLE.** At that height a socket's tube
reaches below the plinth's top, so it enters the structure instead of floating over it. That trade
is deliberate: *"Going below the floor is preferable to this look. If intersecting the floor, the
floor should have a modelled hole for the pipe"* (Truls, 2026-09-14). The opening is modelled and
rimmed, so it reads as a fitting rather than a bite out of the stone, and an internal run that
would otherwise be buried turns down through its own rimmed opening in the deck instead.

**A CONTAINED CONNECTION IS EXEMPT, and the exemption is the point.** ADR 0018's contained fluids
meet a machine FACE, never a pipe -- no pipe, tank, wagon or pump a player can build will join one.
Matching those to a vanilla pipe would match them to something that cannot exist. So the rule binds
a connection left `default` and no other.

rf-heat-exchanger is the machine that shows what that costs, and **it has now been brought over**
(#343): its water pair and its steam outlet moved to 0.044 and 0.249, and its three reactor-energy
connections kept the 0.55 and 0.3 they have always had. So that machine carries a water socket and
an energy socket two tiles apart on the same short end AT DIFFERENT HEIGHTS AND DIFFERENT
THICKNESSES. That is the rule working rather than a slip, and it is written down here because the
obvious next thing anyone will want to do is level them.

**Exempt is not the same as bound by a different rule.** The contained three keep the machine's old
numbers rather than taking new ones: nothing they meet is a pipe, so there is nothing to measure
them against, and a look chosen for them would be a decision nobody has been asked for.

**What it costs, recorded so it is not rediscovered as a surprise.** An accent band on a thinner
stub at pipe height is a thin ring at the machine's edge, not the raised collar it was, and the
accents are what tell a player which socket carries what. If that goes too far, the band can stay
proud while the tube stays thin; they are separate numbers.

Vanilla's `pipe_covers` cap the stub when nothing is joined (#240, decided #247).
Boilers and generators bake sockets into every direction sheet; no separate pipe picture. A socket
on the far side of a tall body may be hidden at this camera; that is accepted, the cover and the
pipe say where it is.

**Exception: plasma.** `rf-pipe` wears Krastorio 2's steel pipe, so a vanilla cover on a plasma
socket would not match the pipe that joins it. Plasma-carrying boxes may need K2's steel covers or
rendered ones; decided when the first plasma machine is rendered (Truls, #247).

**A run ends inside what it joins, and meets it square.** A pipe is a curve with a round profile, so
wherever it stops it shows a disc. There are two ways to leave that disc in the open air, and the
isotope collector's first render managed both in one corner:

- **Landing on the skin instead of inside it.** A run whose last control point sits exactly on a
  drum's surface stops tangent to the shell, and the disc is a pixel above the metal. The Bezier's
  tangent there is whatever the previous control point implied, so the disc is also slanted and
  reads as a cut pipe. Land a quarter of a radius *inside* the vessel, and stack the last two
  control points on one axis so the approach is square rather than glancing.
- **Stopping short of a socket.** A socket's inner face is half a tile in from the tile it stands
  on. A run aimed at a distance *measured against another machine's body* lands in open air on a
  machine that has none there -- the collector inherited a figure from the heat exchanger, where it
  lands inside a fourteen-tile manifold, and left a fifth of a tile of nothing. Overlap the stub;
  do not meet it.

The general form is worth more than either: **a number copied from another machine's build script
is a number measured against another machine's body.** `models/isotope-collector/build.py`'s
`inboard` carries the long version.

## Camera, light, output

Fixed by #239 and #243 and one look (#246), built by `models/rf_blender.py` and `models/render.py`
(#249): orthographic, **pitched 54.7° below the horizontal**, looking north, with the ground
stretched back to square tiles in the camera (a pixel aspect of 1/sin, 1.225), so a wall shows at
0.707 of its height; one hard sun from the west at 42° elevation, shadows east; ambient fill from a
grey world at low strength so the camera-facing wall is not black; render 64 px per tile, shipped
at `scale = 0.5`; structure, shadow (opaque black) and glow as separate sheets; the frame is the
footprint plus a **3-tile margin** on every side so the shadow and the height fit (2 tiles clipped
the heat exchanger's shadow), `shift` zero. The numbers live once, in `rf_blender.py`; the
manifest beside every rendered set records the ones it used. The pitch is Truls's call from the #246 sheets: the
45° camera with square tiles made walls as tall as the ground is deep and the buildings towered
over vanilla's; 54.7° gives the proportion of the unstretched 45° render while the footprint
still fills its tiles. It is close to the 53° the community measured on some vanilla sprites. The
game is where it is confirmed.

## Glow

A glowing part is emissive in the model and is rendered to its own sheet with everything else
black. The glow is always the accent colour of the fluid doing the work, and it glows where that
fluid *is*: the reactor-energy manifold and the lines feeding from it, never the steam side.

**The game draws the sheet, additively, only while the machine works** — through the prototype's
own while-working layer, not through a script. On a boiler that is `fire_glow`, which the engine
holds for `burning_cooldown` ticks after the energy stops (#252; #241 read past it and assumed the
reactor's runtime route). Two fields go with it, both **set explicitly** rather than
inherited, because both decide whether the layer is drawn at all: `burning_cooldown` above 1, or
neither layer appears, and `fire_glow_flicker_enabled = false`, since a fluid energy source emits no
light and the flicker would take the alpha to nothing. Not "pinned" — that word is a plasma
temperature here (`CONTEXT.md`) — and not "like every other stat", either: `rf-heat-exchanger` sets
these two and inherits its `target_temperature` and its water and steam boxes, which is the split
the note at the top of `prototypes/entities.lua` sets out. A machine whose prototype has no such layer — the
reactors — keeps the separate core prototype drawn from `control.lua`.

**Two numbers, because the game ADDS the sheets and adding whitens.** The emission is low
(`rf_blender.GLOW_EMISSION`; 1.5 blew out, #246, and 0.6 came out cream), and the glowing part's
BASE colour is darkened in the structure sheet (`rf_blender.GLOW_BASE_DARKEN`). The second is what
makes a stopped machine look stopped: the structure sheet is all it draws, so a part left at full
accent there reads as lit with the power off. Dark base, accent emission, and the sum is the
accent (Truls, #252).

## Icon

**The whole machine, in the square, with margin** — not a section of it, which is what #246 first
settled and #252 reversed after seeing one in the inventory: a crop reads as a fragment of a
screenshot, with no silhouette and the grating running off all four edges.

A 120×64 mipmap strip (64, 32, 16, 8, top-aligned; #242), rendered at the world camera through the
same rig as the sheets, so the icon is the machine as the map shows it. Two things differ from a
sheet and both are set per machine in `build_rig`:

- **The window is sized on the SCREEN extent**, footprint plus the height showing at 0.707 h, plus
  about half a tile of margin. `icon_centre` rides north by half the height, or the subject sits
  low with all the margin above it.
- **An oblong machine turns to the diagonal** (`icon_yaw`), because square-on it fills a fifth of
  the square and reads as a hairline; on the diagonal the same machine roughly doubles. Zero for
  anything near square, which is then its north sheet seen closer. The sun rides the rig, so the
  icon is lit like every sheet.

**The icon is rendered LIT**, unlike every sheet. A sheet leaves the emission out because the game
adds the glow itself and only while the machine works. Nothing adds anything to an icon, so a cold
one shows a machine with its accent off — which, after `GLOW_BASE_DARKEN`, is a grey rectangle.

## Moving parts

Not built yet (#241 research, animation deferred). A look note may still name a part that could
move later, such as a pressure relief valve, so the model puts it where an animation could reach it.

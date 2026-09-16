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
from its colours before reading its tooltip -- **which is a claim about one machine's sockets told
apart from each other, not about a colour recognised anywhere.** Read the second way it is false;
see "An accent is read against its neighbour" below. An accent is a band or a manifold, never a
whole body.

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

**An accent is read against its neighbour** ([ADR 0034](../docs/adr/0034-an-accent-is-read-against-its-neighbour.md),
Truls, #359). It tells one socket on the machine in front of the player from another, in one frame,
under one light. It is **not** a name for a fluid that a player recognises on sight, and the table's
"every surface that carries X" must not be read as one -- because a single palette row does not
produce a single colour. On `rf-heat-exchanger` water's own two sockets land **32.2 dE00** apart,
further than the **29.5** separating energy from water at their closest: the west socket stands in
the open and the east is shaded by the machine's own body. Ask how far two accents ON ONE MACHINE
land apart. Do not ask what colour an accent is.

**Measured under that standard, nothing here needs changing, and #359 changed nothing.** The
closest pair that can share a machine is **11.7 dE00**, steam against water, off the bench in
`docs/research/accent-separation.md`. The pale pair #359 was raised about reads at roughly **23.6**
on two drums 24.5 screen pixels apart on the collector's own deck — a **hue-cut** figure from
`docs/research/accent-legibility-at-zoom-1.md`, good enough to say the two are visibly different
colours and not good enough to quote as a distance. Bands two screen pixels wide read at zoom 1
because they are 23.5 to 27 tall.

**THOSE FOUR FIGURES WERE RE-MEASURED AFTER ADR 0035** and are a little off the ones ADR 0034 and
`docs/research/accent-separation.md` quote (33.0, 29.2, 11.2, and a band 22 tall). Taking the cut
off a socket's underside gave every plumbable band 1.5 screen pixels more height at zoom 1, and the
extra pixels moved each median a few tenths of a dE00. **The standard's own comparison is unchanged
in direction and narrower in margin**: water against itself still lands further apart than energy
from water at its closest, by 2.7 dE00 where it was 3.8. Re-measured 2026-09-16 with
`tools/measure-accent-separation.py`, which reads the committed sheets and nothing else.
**The standard binds machines not yet rendered**: a pair on a new machine is checked against it
rather than reopening the question. **None of this is gated, deliberately** -- a threshold on
legibility would be a decision wearing a check's clothes.

**A socket whose fluid is set by its recipe carries no accent.** It is bare metal, like any other
unpainted tube. This follows from the table's own "every surface that carries X" -- no fluid, no
accent -- and is stated because one machine has such sockets: `rf-heater`'s input boxes are a
chemical plant's, unfiltered and uncontained, so nothing names what flows in them and
`tools/measure-accent-separation.py` reports them as the one connection it cannot derive. It wears
Krastorio 2's sprites today, so nothing turns on it yet.

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
to the footprint edge on the connection's tile, with one accent band of the fluid it carries, and
-- on a socket a player can plumb -- a flange pair at its mouth (#351, below).

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
0.0234 tiles above the ground line**. Solving the two expressions against those gives **z = 0.033**
and **r = 0.249**, and the collector measures 0.594 tiles against vanilla's 0.609 after both.

**THE SHIPPED z WAS 0.044 UNTIL #356, AND IT IS 0.033 NOW.** The centre was read as 0.031 when the
rule was written -- the bare row indices `(43 + 81) / 2 = 62` against an image centre of 64, mixing
the index convention with the edge convention the rest of the measurement uses -- and `z` was solved
from that, so every plumbable socket was drawn 0.011 tiles of world height too high, which is 0.49
px on the sheet and 0.25 px at the game's own zoom. Since #355 `tools/check-socket-height.py`
measures the reference off vanilla's own sheet rather than carrying a number, and since #356 it
holds `rf_blender.SOCKET_Z` against that measurement to a quarter of a pixel. **The two can no
longer part in silence, which is the part of this that outlives the number.**

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
(#343, at the height #356 corrected): its water pair and its steam outlet are at 0.033 and 0.249,
and its three reactor-energy connections kept the 0.55 and 0.3 they have always had. So that machine carries a water socket and
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

**IT USED TO DRAW MORE PROUD AT THE TOP THAN AT THE BOTTOM, AND SINCE ADR 0035 IT DOES NOT.**
Truls saw the asymmetry on the #353 frames, read it as "flush at the bottom, but not at the top",
and put it down to perspective. The look was real and the cause was not perspective. Every piece of
a socket is coaxial -- on rf-isotope-collector's west socket the stub, the band and the rim all sit
at `y 0.0000, z 0.0330`, and the band is 0.578 tiles across against the stub's 0.498, so it stands
0.04 proud all the way round by construction. The projection is symmetric about that axis too, so
perspective would take the same from both edges. What was asymmetric was how the UNDERSIDES were
drawn, and the cause was the rig's shadow-catching ground plane -- see the mechanism paragraph
below. Measured on the shipped sheets after the re-render, in pixels about the socket's axis:

| part | radius | uncut prediction | measured above | measured below | gains above | gains below |
|---|---|---|---|---|---|---|
| stub | 0.249 | ±19.5 | +20.5 | +20.5 | +1.0 | +1.0 |
| accent band | 0.289 | ±22.7 | +23.5 | +23.5 | +0.8 | +0.8 |
| flange ribs | 0.319 | ±25.0 | +25.5 | +25.5 | +0.5 | +0.5 |
| dark rim | 0.379 | ±29.7 | +30.5 | +30.5 | +0.8 | +0.8 |

Every part stands about a pixel proud of its uncut prediction at BOTH edges -- the bevel and the
anti-aliasing, which spread a drawn edge outward and never inward -- and by the same amount at each,
to the tenth of a pixel the instrument prints. So the band stands 3.0 px proud of the stub at the
top and 3.0 px at the bottom, which is what being 0.04 tiles proud all the way round looks like
when nothing is cut off. `tools/check-socket-parts.py` is the gate that holds this table.

**THE PREVIOUS VERSION OF THAT TABLE READ +18.5, +20.5, +22.5 AND +26.5 BELOW**, losing 1.0 px at
radius 0.249 through 3.2 px at 0.379 -- monotonically with the radius, which is what a plane cutting
at a fixed world height does to cylinders of different widths. It is recorded here because it is the
defect [#373](https://github.com/trulsjo/realistic-fusion-refreshed/issues/373) was opened for and
because the numbers appear in `docs/research/socket-underside-cut.md`, which is left as measured.

**PROUD OF WHAT? THE FIGURE MEANS NOTHING WITHOUT ITS REFERENCE, AND THE TABLE ABOVE NAMES NONE.**
It is every part against the STUB, which is what the geometry does. What a player looks at is every
part against VANILLA'S PIPE, which is what the socket is bolted to -- and that pipe offers two
references of its own, its barrel and its outer flange.

The socket rows below are `tools/measure-socket-parts.py`'s, the same ones as the table above. The
two VANILLA rows are read off `base/graphics/entity/pipe/pipe-straight-horizontal.png` the way
`tools/check-socket-height.py` reads it -- alpha over 8 and colour over its shadow floor, by row
edges -- taking the barrel as the rows running at least 60 px of the sprite's 64 and the flange as
the whole drawn silhouette. Both are about the axis our socket and vanilla's pipe share, which #356
made coincide. Measured 2026-09-16:

| | above | below | vs barrel | vs flange |
|---|---|---|---|---|
| vanilla's barrel | +19.5 | +19.5 | -- | -- |
| vanilla's flange | +25.5 | +25.5 | -- | -- |
| stub | +20.5 | +20.5 | +1.0 / +1.0 | -5.0 / -5.0 |
| accent band | +23.5 | +23.5 | +4.0 / +4.0 | -2.0 / -2.0 |
| flange ribs | +25.5 | +25.5 | +6.0 / +6.0 | +0.0 / +0.0 |
| dark rim | +30.5 | +30.5 | +11.0 / +11.0 | +5.0 / +5.0 |

**Every row is now the same above and below**, which is the whole of what #373 asked for: the band
stands 4.0 px proud of the barrel at each edge and 3.0 px proud of the stub at each, and our flange
ribs meet vanilla's flange exactly, top and bottom. The 1.0 px by which the STUB stands over the
barrel at each edge is the drawn edge -- the bevel and the filter, which spread an edge outward and
never inward -- and not a difference in geometry: radius 0.249 was solved so that a tube of it draws
the barrel's height, and 0.249 / sin(54.7 deg) x 64 is 19.53 px against the barrel's 19.5.

**IT USED TO READ +1.0 / -1.0 ON THE STUB AND +4.0 / +1.0 ON THE BAND**, which is why the band read
flush underneath and proud on top, and why our ribs met vanilla's flange on top and fell 3 px short
beneath. That is the state #373 records.

**WHY THE TWO REFERENCES USED TO DISAGREE ABOUT HOW BAD IT WAS.** While the plane cut, the stub was
itself asymmetric -- 20.5 above and 18.5 below -- so subtracting it cancelled part of the very
asymmetry being measured and reported the band as 1 px out where the pipe reported 3. A symmetric
reference does not do that, which is why the pipe reading was the larger one and the one Truls was
describing. With nothing cut the stub is symmetric too, so the two references now agree about the
asymmetry: there is none. They still differ by a pixel about how PROUD the band is -- 3.0 over the
stub and 4.0 over the barrel -- and that difference is the reason `CONTEXT.md` requires a proudness
figure to name what it is proud of.

**AND THE RULE THAT CAME OUT OF IT** (Truls, 2026-09-16): *"I expect that the pipe inside line up
with vanilla pipe both top and bottom (not including flange)."* A plumbable socket's TUBE draws
vanilla's barrel extent above AND below. This binds what it DRAWS, where the rule further up binds
its radius and its height -- different claims, and it is this one that
[#373](https://github.com/trulsjo/realistic-fusion-refreshed/issues/373) was opened on: the tube was
drawn a pixel PROUD above the barrel and a pixel SHORT beneath it, missing on both edges, by the
same pixel, in opposite directions. **The band was not thickened to hide it**: the tube is what
moved, by ADR 0035 taking the cut away. It now draws +20.5 either side, one pixel of drawn edge
proud of the barrel at each.

The tube's row comes off a flange-free control render. On a shipped sheet no column of a plumbable
socket shows bare tube -- the flange ribs leave 1.15 px between them and no column fits -- which is
why none of this was visible until it was looked for, and why the gate that now holds it reads the
band, the ribs and the rim rather than the tube.

**AN EARLY VERSION OF THIS NOTE PUT THE BAND'S ASYMMETRY AT 4 px AND THEN AT 1 px, AND BOTH WERE
WRONG.** The 4 compared the band's MEASURED edge against the stub's PREDICTED one; the 1 came from a
stub row measured through a column window that leaked the band's first column into it. The figure
that stood was 3 px against vanilla's barrel, and it is now 0.

**WHETHER THE GEOMETRY WAS THE WHOLE OF WHAT TRULS SAW IS STILL NOT ESTABLISHED.** The lower edge
also meets the slab and the ground shadow, where there is less contrast to read an edge against,
and nothing here separates that from the cut -- these are alpha measurements and say nothing about
contrast. The re-rendered frames are what answers it, and the answer is Truls's by eye.

**THE MEASUREMENT IS SENSITIVE TO ITS COLUMN WINDOW, AND THAT IS THE METHOD NOTE #362 NEEDS.** Each
part is read only in the columns where it is the widest thing present; one column too far either way
picks up its neighbour and moves the answer by whole pixels. The stub reads +21.5/+21.5 over columns
198..202 and +20.5/+20.5 over 198..201, because column 202 is the first that draws any of the accent
band -- the band begins 0.88 px into it. Rim and ribs are stable across every window tried; the stub
and the band are not, and the numbers above are the stable ones. The stub is measured on a
flange-free control render, since on the shipped sheet no column shows bare tube.

**Those two windows were written 198..203 and 198..202 until #365**, each one too high at the far
end, because they were taken as Python slice bounds and a slice is half-open. Nothing measured
moved -- both readings reproduce exactly -- only how the window was written down. Both ends are
inclusive above, which is how `tools/measure-socket-parts.py` prints them.

**THE GUARD IS NOW THE INSTRUMENT'S RATHER THAN THE READER'S** (#365). `tools/measure-socket-parts.py`
prints the table above a part at a time, works each part's window out from the same constants the
models are built from rather than from a column range anyone typed, and refuses a number that moves
when that window is narrowed by one column at either end. Three of the four rows come off the
committed sheets -- band, ribs and rim, identical on all six PLUMBABLE sockets the two machines
carry between them -- and on those sheets the stub is reported as having NO WINDOW rather than a
number, which is this note's own last sentence said by a tool. (The other three sockets are
contained: they wear no rim and no ribs, so they report a stub and a band and nothing else.)

**The fourth row is reproduced on the control render, and the leak with it.** The control is the
shipped model with its six `Flange-*` objects deleted and re-rendered to a scratch directory --
nothing in the repository is touched and nothing is committed, so re-deriving that row means
re-rendering. **`scripts/probe-flange-free-render.ps1` is that render, in one command** (#376): it
runs `models/socket-variants.py`'s `unflanged` treatment over the stored model and
`models/render.py` over the result, into a directory the caller names and which it refuses if it is
inside a mod. Before that the method lived only in this paragraph and the row could not be got back
without working it out again.

Measure the result with `--no-flange`, which is the caller telling `tools/measure-socket-parts.py`
that the ribs' span is bare tube -- without it the tool still works its windows out from the
constants the model was built from, labels that span "flange ribs" and measures it at the ribs'
radius. Through columns 198..201 the stub then measures +20.5/+20.5, which is the table's row, and
nothing in the table is reported unstable; re-verified that way 2026-09-16, after the re-render, on
the north socket as well. Widened to 198..202 it
measures +21.5/+21.5, which is the leak that shipped, and the tool reports THAT one unstable rather
than returning it. The same boundary shows on the shipped sheet without any render: the flange rib
ends and the accent band begins at column 202.88, so column 203 starts a tenth of a pixel past it,
and the band read through a window holding that column measures +24.5 above where its own columns
give +23.5.

**THE MECHANISM WAS THE GROUND PLANE, AND ADR 0035 TOOK IT AWAY** (#366, #367, #373, measured
2026-09-16). `rf_blender.build_rig`'s shadow-catching plane hides everything below world z 0,
exactly as `tools/check-socket-height.py`'s header always claimed. Rendering a machine with that
plane deleted put every row above back symmetric to the pixel, and thirty-six bare cylinders across
six radii and six heights agreed with a model of it that fits nothing: below its axis a tube of
radius `r` at height `z` draws `sqrt(r^2 - z^2) + z/tan(pitch)` tiles, until `z` reaches
`r cos(pitch)` and the plane stops reaching it at all.

**SO `models/render.py` STOPPED LETTING IT OCCLUDE.** The structure sheet comes off a view layer
that marks the plane INDIRECT ONLY -- it lights the machine and no longer stands in front of it --
and the shadow sheet off a second layer where it still catches. No single render does both: making
the plane invisible to camera rays, giving it a transparent material and deleting it outright each
empty the Shadow Catcher pass, and the transparent one still occludes. ADR 0035 has the four
measurements and the cost.

**THE TWO THINGS THAT MADE IT LOOK UNFITTABLE WERE BOTH THE COMPARISON RATHER THAN THE CAUSE.** A
plane at one world HEIGHT is not a cut at one screen ROW under a pitched camera: the lowest drawn
point of a tube is the point of its cross-section at z 0, which lands `sqrt(r^2 - z^2)` tiles below
the ground line and therefore on a different row for every radius. And a drawn edge stands about a
pixel proud of the geometry that cast it at BOTH ends, so a shortfall measured against a geometric
prediction has to have the same cylinder's own top-edge gain taken off it before it means anything.
It is the same effect that leaves that gate its +0.031 residual, which the model predicts at 0.0317
tiles without being shown it. `docs/research/socket-underside-cut.md` carries the tables and
`scripts/probe-socket-underside.py` reruns them. Measured 2026-09-15, corrected 2026-09-15, settled
2026-09-16.

**ON A SOCKET, "COLLAR" MEANS THE ACCENT BAND** (#351). The word named two parts of one socket for
a while -- the raised ring in the paragraph above, and a rim moved inboard onto the body face, which
was one of #350's four treatments. The band keeps it; that treatment is `rimmed-inboard` in
`models/socket-variants.py` and `scripts/probe-socket-shapes.ps1`, and a socket's rim is a RING.

**That is narrower than #351 first wrote it, and the first version was false on the day.** It said
"and nothing else", which condemned vocabulary already in correct use elsewhere. **The word has
three referents in this repository and only one of them is a socket's:**

| What | Where | Spelling found there |
|---|---|---|
| a socket's accent band | this document | *collar* -- the one #351 keeps |
| the ring where a pipe turns down through the deck | `models/heat-exchanger/build.py` (three times, one of them capitalised), `models/isotope-collector/build.py`, and the `look: rf-heat-exchanger` note in `realistic-fusion-refreshed/prototypes/entities.lua` | *collar where it goes in*, and once *floor collar* |
| a corrugation ring along a hose run | `models/heat-exchanger/build.py` | *collar* -- renamed *ring* by #361, to agree with `models/rf_parts.py`'s `pipe` |

Neither of the other two sits on a socket, so the narrowed rule reaches none of them and nothing was
renamed for its sake. **Age is not the argument and #351's correction first claimed it was: the
deck-collar wording went in earlier the SAME DAY, not "for weeks".** It is protected because it is
unambiguous where it stands, not because it is old. **The lesson is the one this document keeps
relearning: a rule saying "nothing else" is an instruction to enumerate. #351 wrote one without
doing it, #361 then wrote a correction that miscounted the set and misdated it, and the enumeration
above is what either should have started from.** Note the trap that hid one entry from both: a
case-sensitive `git grep collar` misses `A COLLAR`.

### The mouth wears a flange pair

**A PLUMBABLE SOCKET'S MOUTH WEARS VANILLA'S FLANGE PAIR: two ribs standing proud of the tube, in
the tube's own material, just inboard of the dark rim** (Truls, 2026-09-14, settling #351 from the
frames #350 shot). `rf_parts.socket` has drawn it on every plumbable socket since #353.
`docs/research/socket-shapes.md` has the frames and the full reading of them; ADR 0033 has the
principle. What has to live here is the rule and the two things that will otherwise be undone by
accident.

**The principle it settles, which is wider than this rule.** A socket borrows a vanilla drawing cue
when the cue is also hardware a real pipe has. A flange is; a painted window is not. That is why
`dark-cored` lost on more than its looks: our tube is a cylinder and vanilla's window is the shadow
inside a stylised ribbon, so drawing it would draw a feature the geometry does not have.

**THE FRAMES FOUND SOMETHING NOBODY HAD WRITTEN DOWN, and it is why three of the four treatments
were never really candidates. There is almost no bare tube at a socket's mouth.** With a pipe
joined, what shows outside the slab is vanilla's `pipe_cover`, then the accent band, then the slab
edge. `dark-cored` came out indistinguishable from the control at zoom 8 for exactly that reason --
there was no exposed tube to put a channel on. `rimmed-inboard` was the only visibly different one
and it failed on the accents: moving the rim inboard pushes the band onto the body face, where the
slab edge clips it to a sliver. A shape that costs a player the ability to tell tritium from
helium-3 is a bad trade whatever the seam looks like.

**#350'S ZOOM-1 CRITERION IS OVERRIDDEN HERE, DELIBERATELY, AND THIS PARAGRAPH IS THE ONLY RECORD
OF IT.** #350 said *"a difference nobody can see at 32 px to the tile is not a candidate, and
magnification alone would hide that"*. None of the four treatments is distinguishable at zoom 1 --
not the flange either. The criterion is a good guard against being fooled by magnification, and it
was written before anyone knew the mouth had no visible surface to treat. It is set aside because a
flange is real hardware rather than an artefact of zoom, and players do zoom in. **Do not undo the
flange on the strength of #350's sentence**; that is the shape of the mistake this paragraph
exists to stop.

**THE RIBS ARE FITTED TO THE CLEAR SPAN, NEVER PLACED AT TYPED OFFSETS**, and the first version of
the variant script is the reason. There is very little clear tube to work in: on the isotope
collector the stub is 0.75 tiles long, the dark rim owes the first 0.08 and the accent band starts
at 0.17, leaving 0.09 tiles of metal for a pair of ribs. Typed offsets buried one rib in the rim and
clipped the band with the other -- a fat lump rather than a flange pair. So the span comes from the
rim and the band rather than from a number typed beside them, and the ribs are divided into it. The
two places that do it differ, and the difference is worth knowing: `rf_parts.socket` derives the
span from the constants that place those two, because it draws all three while building, so its
span is the same on every machine and **its floor guards those constants rather than any machine**.
`models/socket-variants.py` measures the span off a stored model, because it draws onto one it did
not build -- **that** is where a machine with no room **fails loudly rather than drawing a lump**. What makes a rib read as a flange is standing
PROUD of the tube, not its thickness: 0.07 tiles, which is **2.24 px on the player's screen** and
not the 4.5 this was once quoted as -- that figure was the same rib measured at 64 px to the sheet,
in a clause about the detail floor, which is the one place this document forbids the sheet as a unit.

**PROUD IS WHAT THE EYE READS; THE FACE IS WHAT THE FLOOR MEASURES, AND THEY ARE NOT THE SAME
NUMBER.** The floor judges whatever `cyl` is handed as `read=`, and a flange hands it the disc's
FACE -- `2 * (radius + FLANGE_PROUD)`, about 0.64 tiles or 20 px on screen for the collector -- so a
rib far thinner than the floor survives it comfortably. **Do not compute a clearance from the proud
amount.** #361 did, reported a margin of a third of a pixel on a rib that in fact clears by
eighteen, and used the invented near-miss as the argument for the unit rule. The unit rule needs no
such argument; it is the rule.

**THE ACCENT BAND IS UNCHANGED** (#351, same decision). The frames show it reading at zoom 8 and
present at zoom 1, so the cost recorded two paragraphs up was paid and is survivable. What the
frames also raised, and what is **not** settled here: at zoom 1 an accent is about six pixels of
pale colour, and tritium and helium-3 are both pale. That is a question about every accent on every
machine rather than about sockets, so it is #359 and not this rule.

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

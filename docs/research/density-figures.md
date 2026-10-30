# Two density figures for rendered art, and the "before" for #798

Measured 2026-10-27 for [#799](https://github.com/trulsjo/realistic-fusion-refreshed/issues/799),
the first child of [#798](https://github.com/trulsjo/realistic-fusion-refreshed/issues/798), the
second attempt at denser rendered art. #799 asks for "more detail" to be measured as well as judged,
and #798 for a figure that grime and noise cannot raise. This note says how the two figures are taken,
what each cannot see, and what they read before any of #798's work. Rerun it with the commands below.

## The two figures

`tools/measure-density.py` takes both. Its docstring has the method, and the self-test proves the
count can fail (`python tools/measure-density.py --self-test`).

- **Pixel figure:** the share of a sheet's opaque interior pixels that are edge. An edge pixel's
  luminance differs from a 9 px box blur of its surround by more than 14 of 255, either sign. The
  blur's radius, the threshold and the opacity cut are
  `docs/research/detail-floor/measure-detail.py`'s constants, imported. The box blur and the
  luminance, the mean of R, G and B, are written again the same way. What is done with them
  differs: [`detail-floor.md`](detail-floor.md) measures the widths of runs along rows, over every
  opaque pixel, and this counts a share of the interior. It reads pixels only, so it runs on any
  sheet.
- **Normal-pass figure:** the same count on a normal pass of our own model, in any of the three
  channels. `models/render-normal.py` renders it with the north sheet's rig, frame and camera. The
  two figures read nearly the same pixels. On `rf-heat-exchanger` the pass and the sheet are both
  1344 × 704. Their interiors hold 319 711 and 319 713 pixels, and 20 pixels are in one and not
  the other, 11 only in the sheet and 9 only in the pass (measured 2026-10-27). Where those 20
  sit was not looked at.

**The outline is left out of both.** Only pixels at least the blur's radius inside the opaque area
count. Otherwise the blur would reach into transparency and count the silhouette, which favours a
small machine, since its outline is a larger share of its area.

## The "before"

Measured 2026-10-27, on the sheets as they stood on `main` at the merge of #807. Vanilla's sheets
are from Factorio 2.1.23 (build 87750, Steam), and the normal passes from Blender 5.2.0 at
16 samples. Every sheet here is 64 px to the tile, drawn at `scale = 0.5`, so the figures compare
directly.

| sheet | pixel figure | normal-pass figure | interior pixels |
|---|---:|---:|---:|
| `rf-heat-exchanger`, north | 0.286 | 0.448 | 319 713 |
| `rf-isotope-collector`, north | 0.379 | 0.497 | 85 012 |
| vanilla heat exchanger, `heatex-N-idle.png` | 0.566 | | 17 984 |
| vanilla boiler, `boiler-N-idle.png` | 0.486 | | 18 145 |
| Krastorio 2's reactor, `reactor.png` | 0.383 | | 886 329 |

The commands, from the repository root:

```
python tools/measure-density.py --machine heat-exchanger
python tools/measure-density.py --machine isotope-collector
python tools/measure-density.py "<Factorio>/data/base/graphics/entity/heat-exchanger/heatex-N-idle.png" "<Factorio>/data/base/graphics/entity/boiler/boiler-N-idle.png" realistic-fusion-refreshed-assets/graphics/krastorio-2/buildings/reactor/reactor.png
```

**No figure for the Figma reference.** No export of it exists: on 2026-10-27 it was viewed in a
browser and nothing was downloaded
([`figma-factorio-buildings.md`](figma-factorio-buildings.md)). An export would first need
rescaling to 64 px to the tile.

**The normal-pass figure does not move with the samples.** On `rf-heat-exchanger` it read 0.453
at 4 samples, 0.448 at 16 and 0.447 at 64, measured the same day. Sixteen is the default.

## After #801: value range and hazard yellow

Measured 2026-10-28 with the same commands, after
[#801](https://github.com/trulsjo/realistic-fusion-refreshed/issues/801) lowered the body, frame
and dark rows of both build scripts and gave `rf-heat-exchanger` three hazard-yellow elements, and
again after it lowered bare metal as well, from 0.55 to 0.30.
Nothing was added to either model's shape, *read from source*: both build scripts' diffs change
colours and materials only. The normal-pass figure below agrees, and the exchanger's north sheet
has the same alpha as before in all but one pixel, which shows its silhouette unchanged but for
that pixel (*measured*).

| sheet | pixel figure, before | dark roles down | and bare metal | normal-pass figure, before | after both |
|---|---:|---:|---:|---:|---:|
| `rf-heat-exchanger`, north | 0.286 | 0.253 | 0.236 | 0.448 | 0.448 |
| `rf-isotope-collector`, north | 0.379 | 0.363 | 0.348 | 0.497 | 0.497 |

**The normal-pass figure did not move, which is what it is for.** No surface changed shape, so
nothing could raise it. That is *inferred* from the build scripts' diff, which changes colours and
materials only.

**The pixel figure fell on both, at each step, and the darker palette is the likely reason.** Grime darkens a
surface by a fixed fraction of its base colour, so on a darker base it makes smaller steps in
luminance, and fewer of them reach the 14 of 255 that counts. That is *inferred* from the material
code in both build scripts and was not isolated. It is a reason to read the pixel figure beside the
change it follows: a wider value range is not less detail, which is *inferred*, since the
normal-pass figure that sees shape alone did not move.

**The luminance percentiles** `models/house-style.md` quotes for #801 are taken with the
same alpha cut, above 200, but over every opaque pixel, the outline included, by the mean of R,
G and B, with no blur.
*Measured* 2026-10-28, with this command from the repository root:

```
python -c "import sys,numpy as n;from PIL import Image as I;[print(n.percentile(n.asarray(I.open(p).convert('RGBA'),float)[...,:3].mean(2)[n.asarray(I.open(p).convert('RGBA'))[...,3]>200],[5,50,95]).round(1),p) for p in sys.argv[1:]]" <sheet>...
```

## The kit on `rf-heat-exchanger`

Measured with the same command, `python tools/measure-density.py --machine heat-exchanger`, after
each of #798's kit tickets rendered the exchanger again, and after the pre-PR review's fixes. Each
"before" is the row above it; the first is #801's last. Blender 5.2.0, 64 samples for the sheet and
16 for the normal pass.

| after | what it added | pixel figure | normal-pass figure |
|---|---|---:|---:|
| #801 | (the starting point) | 0.236 | 0.448 |
| [#803](https://github.com/trulsjo/realistic-fusion-refreshed/issues/803), 2026-10-28 | a vent hose off each relief valve; a red and green loom along the east rail, with a drop to each gauge cluster | 0.2685 | 0.4870 |
| [#802](https://github.com/trulsjo/realistic-fusion-refreshed/issues/802), 2026-10-28 | inset panels on the two closed bays, the cabinet's top and the manifold's inner face | 0.2774 | 0.5011 |
| [#804](https://github.com/trulsjo/realistic-fusion-refreshed/issues/804), 2026-10-28 | a segmented jacket under each drum's cap; a fan stack past the last drum; a bolt row on the slab's open edge; the cap bolts moved onto the kit | 0.2846 | 0.5257 |
| the branch's pre-PR review, 2026-10-28 | parts that passed through each other moved apart: the loom steps round the steam outlet and drops inboard, the bays stand back behind the guard rail, the cabinet's plates keep off the conduit, the vent hoses stand a little further off the drums, and the kerb bolts skip the posts and the socket | 0.2843 | 0.5298 |
| Truls's look, 2026-10-29 | no hose or loom placed as an exact copy; the guard rail in lengths between the posts, starting at the cabinet | 0.2734 | 0.5173 |
| that change's review, 2026-10-29 | the guard rail stops clear of the posts and is cut round the steam outlet; the bay plates stop short of the backing's ends; the vent hoses stand further off the drums | 0.2754 | 0.5199 |

**The normal-pass figure rose at each ticket**, *measured*: 0.448 to 0.5257 after #804. **So the
rise is shape**, which is *inferred* from the method: a material cannot raise that figure. The
pixel figure rose with it, from 0.236 to 0.2846, a little under the 0.286 it stood at before
#801's repaint lowered it, and still below vanilla's heat exchanger (0.566).

**Both fell after Truls's adjustments of 2026-10-29**, to 0.2734 and 0.5173, *measured*, and stood at
0.2754 and 0.5199 at #824's head. Why was
not isolated. The guard rail's six lengths each draw their own jitter where one beam drew one, so
every random draw after them moved, the drums' radius and height among them, and the hoses' rings
moved with their new phases; any of these can move both figures. That is *inferred* from the build
script and was not tested part by part. [The re-roll of #825](#the-re-roll-of-825), below,
measures how much one re-roll moves on its own. The bench prints four
places, and the kit's rows give all four; the first row is #801's, given to three.
Neither figure says the parts read at 32 px a tile; that is Truls's eye, on a frame from
`scripts/probe-heat-exchanger-art.ps1`.

**The loom's sheath colours** are 43.7 dE00 or more from every accent and from hazard yellow, on
the palette rows through `tools/colour_distance.py`, with each linear row put through the sRGB
transfer function first (*measured* 2026-10-28):

| sheath | energy | steam | water | plasma | tritium | helium-3 | hazard yellow |
|---|---:|---:|---:|---:|---:|---:|---:|
| `cable-red` | 46.9 | 56.4 | 58.6 | 45.8 | 72.1 | 51.0 | 55.4 |
| `cable-green` | 50.5 | 52.1 | 54.5 | 54.1 | 47.0 | 56.4 | 43.7 |

On the same palette rows the closest pair of accents is plasma against helium-3, at 14.6, and steam
against water is 21.4 (*measured* 2026-10-28, the same way). `models/house-style.md`'s 11.7 for
steam against water is a different measure: drawn pixels on one machine's sheet, off the bench in
`accent-separation.md`. These are palette rows and not drawn pixels. ADR 0034 compares accents on
one machine with each other, and a sheath is not an accent, so the table says only that no sheath
is near any of them. Rerun it from the repository root:

```
python -c "import sys,itertools;sys.path[:0]=['tools','models'];import numpy as n,colour_distance as c,rf_blender as r;s=lambda l:n.where(n.asarray(l)<=0.0031308,12.92*n.asarray(l),1.055*n.asarray(l)**(1/2.4)-0.055);a={'energy':(1,.45,.1),'steam':(.85,.88,.9),'water':(.25,.55,1),'plasma':(.55,.2,1),'tritium':(.5,1,.6),'helium-3':(.8,.45,1),'hazard':(.72,.55,.09)};d=lambda x,y:round(float(c.ciede2000(c.srgb_to_lab(s(x)),c.srgb_to_lab(s(y)))),1);[print(k,{m:d(v[0],w) for m,w in a.items()}) for k,v in r.CABLE_COLOURS.items()];print(sorted((d(a[x],a[y]),x,y) for x,y in itertools.combinations(list(a)[:6],2))[:2])"
```

## The re-roll of #825

Measured 2026-10-29 with the same two commands, before and after
[#825](https://github.com/trulsjo/realistic-fusion-refreshed/issues/825) gave each part of a model
its own random stream, seeded from its name. That change moves no part on purpose, *read from
source*: its first commit changes where each draw comes from and no part's nominal place. Every
imperfection is drawn again, once, from a different stream, so this is the re-roll alone that the
kit's last two rows could not separate from the change they followed. Blender 5.2.0, 64 samples for
the sheet and 16 for the normal pass.

| sheet | pixel figure, before | after | normal-pass figure, before | after |
|---|---:|---:|---:|---:|
| `rf-heat-exchanger`, north | 0.2754 | 0.2757 | 0.5199 | 0.5231 |
| `rf-isotope-collector`, north | 0.3484 | 0.3475 | 0.4966 | 0.4995 |

**A re-roll moved the normal-pass figure by about 0.003 on each machine, and the pixel figure by
under 0.001**, *measured*. This is one re-roll per machine, so it shows how big one draw's spread
can be, not how wide the spread is. Beside it, the fall after Truls's adjustments of 2026-10-29
was 0.0109 and 0.0125 on the exchanger. The normal-pass fall is three to four times what this
re-roll moved that figure, and the pixel fall over ten times what it moved that one, so most of
it was probably the change itself and not the re-roll. That is *inferred* from one sample of
the re-roll and was not tested further. #827's re-roll, below, moved the exchanger's pixel
figure by 0.0049, so on that figure the fall is only about twice what one re-roll did, and the
claim holds for the normal-pass figure more than for the pixel one. That is *inferred* from three
samples of a re-roll.

**The re-roll also moved the exchanger's accidental contacts.** It took some away and landed
others, as #824's re-roll had, *measured* by a mesh-overlap test on the built model before and
after. The fixes that followed on the same branch moved parts on purpose, so they get a row of
their own. The feeds now cross the mid-line posts beside them, the steam outlet comes down at 1.52
and not 1.80, the loom rests 0.025 higher over the cross rails, and the bays stand back 0.14 and
not 0.12, *read from source*.

| `rf-heat-exchanger`, north | pixel figure | normal-pass figure |
|---|---:|---:|
| the re-roll, from above | 0.2757 | 0.5231 |
| after the fixes | 0.2772 | 0.5206 |

## The re-roll of #827

Measured 2026-10-29 with the same two commands, after
[#827](https://github.com/trulsjo/realistic-fusion-refreshed/issues/827) renamed every part that
draws and was named by its place in a loop. A part draws from the stream of its name, so each
renamed part that draws drew again, and the loom's wander between clamps moved to a stream of each
span's own. No part moved on purpose in the renaming, *read from source*; two contacts it landed
were then fixed, below. The "before" is each machine as #825 left it, from the tables above, on
sheets `main` still carried. Blender 5.2.0, 64 samples for the sheet and 16 for the normal pass.

| sheet | pixel figure, before | after | normal-pass figure, before | after |
|---|---:|---:|---:|---:|
| `rf-heat-exchanger`, north | 0.2772 | 0.2735 | 0.5206 | 0.5180 |
| `rf-isotope-collector`, north | 0.3475 | 0.3465 | 0.4995 | 0.4995 |

The exchanger was measured three times on the way, *measured*:

| `rf-heat-exchanger`, north | pixel figure | normal-pass figure |
|---|---:|---:|
| renamed, the post lines lettered | 0.2723 | 0.5172 |
| the two contacts fixed | 0.2726 | 0.5169 |
| the post lines named for where they stand | 0.2735 | 0.5180 |

**Two re-rolls of the exchanger moved its pixel figure by 0.0049 and 0.0009**, *measured*: the
first renaming, and the second, which renamed the post lines and what is named for them, the
frame, the bays and the loom's spans, with the fixes kept. #825's one re-roll moved it by 0.0003.
So a re-roll can move that figure by about 0.005, *inferred* from three samples, and a difference
of that size between two sheets may be chance.

**The renaming landed two contacts of the kind #824 and #825 fixed**, *measured* by the same
mesh-overlap test: the middle drum's handwheel stood on the plates of the bay beside it, and the
south drum's weld seam stood in the cabinet. Both were fixed on the same branch, *read from
source*: the wheel's plane kept 0.07 from a bay's plates, which leaves its rim 0.02 clear, with its
gauges moved along with it, and the weld stopped 0.03 short of the cabinet. Every other contact the test found new on the exchanger is of four kinds, *inferred* from
its list of pairs: a handwheel against the frame, which #806 is left to settle; a beam meeting a
beam or the slab; the pieces of one drum or one hose meeting each other, and the headers where they
land together on the middle drum's cap; and a part meeting what it is joined to, as a hose its cap,
a vent hose its valve and the deck, a gauge loom the main loom, the loom the cabinet it climbs off,
and a conduit clamp its post. On the collector it found
five new contacts and lost four, *measured*, all of ice: against what it hangs from or sits on,
against other ice, or, for two icicles hung from the tritium drum, their tips against the deck
below, *read from source*.

**The exchanger is textured since #805, and its sheet's figures are 0.2745 and 0.5180**,
*measured* 2026-10-30 with the same command, after
[#805](https://github.com/trulsjo/realistic-fusion-refreshed/issues/805) drew the manifold's broad
rust and the paint's weathering from a CC0 photograph. The texture moved the
pixel figure by 0.0010, a fifth of what #827's first renaming moved it by, and left the normal-pass
figure where it was, as no material can move it. On the manifold alone it moved it by 0.0002.

## The valve of #833

Measured 2026-10-30 with the same command, `python tools/measure-density.py --machine heat-exchanger`,
after [#833](https://github.com/trulsjo/realistic-fusion-refreshed/issues/833) put the kit's
first inline valve on each of the exchanger's two drum-to-drum steam runs, at the run's sag. The
"before" is #805's sheet, taken again from the same command on `main` the same day. Blender 5.2.0,
64 samples for the sheet and 16 for the normal pass.

| `rf-heat-exchanger`, north | pixel figure | normal-pass figure |
|---|---:|---:|
| before, #805 | 0.2745 | 0.5180 |
| after, #833 | 0.2747 | 0.5188 |

**Both rose a little**, *measured*: the pixel figure by 0.0002, well inside what a re-roll moves
it ([The re-roll of #827](#the-re-roll-of-827)), and the normal-pass figure by 0.0008. Two valves
are a small share of a fifteen-tile sheet. The placing re-rolled nothing else, which is *inferred*
from #825's streams, since every part draws from a stream of its own name. The mesh-overlap test
on the built model agrees, *measured*: it found every pair it found on `main`, and no other but
the valves' own pieces and the hoses they sit on.

## The cable tray of #834

Measured 2026-10-30 with the same command, `python tools/measure-density.py --machine heat-exchanger`,
after [#834](https://github.com/trulsjo/realistic-fusion-refreshed/issues/834) put the kit's
cable tray along the top of the exchanger's east rail, the south side once the body is turned, with
the loom from the cabinet laid in it. The "before" is #833's sheet, taken again from the same
command on `main` the same day. Blender 5.2.0, 64 samples for the sheet and 16 for the normal pass.

| `rf-heat-exchanger`, north | pixel figure | normal-pass figure |
|---|---:|---:|
| before, #833 | 0.2747 | 0.5188 |
| after, #834 | 0.2809 | 0.5228 |

**Both rose**, *measured*: the pixel figure by 0.0062 and the normal-pass figure by 0.0040. The
pixel figure's rise is about thirty times the valves'. The tray need not be all of it, which is
*inferred*: the loom no longer wanders across the rail between the posts or steps out round the
steam outlet, and lies higher, in the tray. The placing re-rolled nothing else, which is
*inferred* from #825's streams.
The mesh-overlap test on the built model agrees, *measured*: the only pairs it found that `main`
did not are the tray's rails, rungs and brackets against each other and against the rail they rest
on, the gauge looms against their own ties, and the gauge looms' cables against the main loom's,
where they branch from it, as on `main`.

## The grating deck of #835

Measured 2026-10-30 with the same command, `python tools/measure-density.py --machine heat-exchanger`,
after [#835](https://github.com/trulsjo/realistic-fusion-refreshed/issues/835) rebuilt the
exchanger's deck as the kit's grating deck: a bar at each of the thirty places the hand-placed slats
were spaced at, where `main` had twenty-eight slats and left out the two that crossed the steam
outlet's descent, an opening cut round that descent and the cabinet, and a toe board on each end,
in hazard yellow with the end's marked bar. The "before" is #834's sheet, taken again from the same
command on `main` the same day. Blender 5.2.0, 64 samples for the sheet and 16 for the normal pass.

| `rf-heat-exchanger`, north | pixel figure | normal-pass figure |
|---|---:|---:|
| before, #834 | 0.2809 | 0.5228 |
| after, #835 | 0.2794 | 0.5230 |

**The pixel figure fell by 0.0015 and the normal-pass figure rose by 0.0002**, *measured*. Most of
the deck stands behind the drums from this camera, so little of it reaches the sheet, *inferred*
from crops of the north sheet before and after, at zoom 1 and 4×, which the pull request for #835
describes and which are not in the tree. With dark toe boards first, the pixel figure was 0.2776,
*measured* the same day. The dark board stood on the yellow bar's top face, along its outer edge.
Crops of that render against `main`'s, made in the session and put to Truls before the boards were
made yellow, showed the yellow line thinner; that the board hid part of it is *inferred* from them.
The placing re-rolled nothing else, which is *inferred* from #825's streams. The mesh-overlap test on the built model
agrees, *measured*: every pair a slat made on `main` the bar in its place makes, but the cabinet's
and its seam's, which the cabinet's opening removes, and the only new pairs are each toe board
against its end bar.

## The access ladder of #836

Measured 2026-10-30 with the same command, `python tools/measure-density.py --machine heat-exchanger`,
after [#836](https://github.com/trulsjo/realistic-fusion-refreshed/issues/836) put the kit's access
ladder up the exchanger's middle drum to its cap, its cage in hazard yellow. The "before" is #835's
sheet, taken again from the same command on `main` the same day. Blender 5.2.0, 64 samples for the
sheet and 16 for the normal pass.

| `rf-heat-exchanger`, north | pixel figure | normal-pass figure |
|---|---:|---:|
| before, #835 | 0.2794 | 0.5230 |
| after, #836 | 0.2854 | 0.5302 |

**Both rose**, *measured*: the pixel figure by 0.0060 and the normal-pass figure by 0.0072. The
access ladder stands between the middle drum and its neighbour from this camera, where the frame
behind it is dark, and its yellow cage meets that dark on every hoop and bar; that this is where
the rise comes from is *inferred*. The placing re-rolled nothing else, which is *inferred* from
#825's streams. The mesh-overlap test on the built model agrees, *measured*: it found every pair it
found on `main`, and no other but the access ladder's own pieces against each other and its
brackets against the middle drum and, the top two, its shoulder casing.

## What the "before" says, and how far it goes

Both of our machines are below both vanilla sheets on the pixel figure. The isotope collector is level
with Krastorio 2's reactor, and the heat exchanger is below all three. That is *inferred* from the
table above, which is one sheet each, the north one.

It does not say the session's 2026-10-26 read by eye was wrong. That read was that the collector
still looks like a different mod beside Krastorio 2's reactor. Both readings stand: the collector
is as edge-dense as the reactor and still looks different from it. So density may not be the gap
the eye saw. Value range and marking colour, two of #798's five gaps, are what this figure is
blind to; see below. That is *inferred* and not measured. It cannot see a range as a range, but a
repaint still moves it: see "After #801".

## What each figure cannot see

Each point here is *inferred* from the method in `tools/measure-density.py`, except where a
measurement with its day is given.

**The pixel figure:**

- **It cannot tell detail from grain.** Grime, procedural noise and Cycles noise all count as edge,
  as `detail-floor.md` already says of its sweep. That is the reason the second figure exists.
- **It sees luminance only.** Two colours of one brightness meet with no edge, so an accent band
  or a hazard-yellow block can add nothing.
- **It is blind to value range.** A machine repainted darker, with the same detail, reads the same
  as long as its steps stay above the smallest one that counts: 33 of 255 for a sharp step. Only
  4/9 of a step shows against the 9 px blur, and the blur is rounded to 8 bits, so a step of 32
  differs by 14 and does not count. A straight ramp counts nothing however steep. Measured
  2026-10-27 on synthetic input: 31 and 32 read 0, 33 counted, and a ramp of 3 a pixel read 0.
  **That holds for a step drawn the same way, not for a real repaint.** A darker base shrinks the
  steps grime makes on it, some fall under 33, and the figure drops; #801's repaint took it from
  0.286 to 0.236 with no shape changed. See "After #801".
- **It depends on resolution.** It compares only sheets at the same pixels per tile and the same
  scale, which is why a Figma export would need rescaling first.
- **It reads one sheet.** It takes the north sheet, never the glow, the shadow or another
  direction.

**The normal-pass figure:**

- **It cannot see a material by design.** Texture, grime and paint do not bend a surface. That
  makes it the wrong figure to test whether procedural grain is poor at 64 px to the tile, which
  ADR 0043 says the pixel figure could test.
- **It counts folds and tight curves, not gentle ones.** A surface turning at a steady rate is a
  ramp in the normals and counts nothing. A crease counts when it turns a component by 33 of
  255 or more, which on a channel mapped from −1..1 is about 0.26 of a unit normal's component,
  roughly 15 degrees, *inferred* from the step measured above. A tight curve, such as
  a small pipe's or a corrugated hose's, changes its rate of turning within the blur's width and
  so counts. That too is *inferred*.
- **It exists only for our machines**, since it needs the model. It cannot compare against
  vanilla, Krastorio 2 or Figma.
- **It sees only the visible surface.** It reads the north camera's first hit, so a part hidden
  behind another adds nothing.

**Both:**

- **They are shares, not counts.** A machine that grows a large flat panel reads less dense even
  though nothing was taken away.
- **Neither is a target.** They guide the work, and Truls's eye in a real map accepts it (#798).

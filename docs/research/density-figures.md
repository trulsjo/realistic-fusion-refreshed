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
each of #798's kit tickets rendered the exchanger again. Each "before" is the row above it; the
first is #801's last. Blender 5.2.0, 64 samples for the sheet and 16 for the normal pass.

| after | what it added | pixel figure | normal-pass figure |
|---|---|---:|---:|
| #801 | (the starting point) | 0.236 | 0.448 |
| [#803](https://github.com/trulsjo/realistic-fusion-refreshed/issues/803), 2026-10-28 | a vent hose off each relief valve; a red and green loom along the east rail, with a drop to each gauge cluster | 0.269 | 0.487 |
| [#802](https://github.com/trulsjo/realistic-fusion-refreshed/issues/802), 2026-10-28 | inset panels on the two closed bays, the cabinet's top and the manifold's inner face | 0.277 | 0.501 |
| [#804](https://github.com/trulsjo/realistic-fusion-refreshed/issues/804), 2026-10-28 | a segmented jacket under each drum's cap; a fan stack past the last drum; a bolt row on the slab's open edge; the cap bolts moved onto the kit | 0.285 | 0.526 |

**The normal-pass figure rose at each step, so the rise is shape**, *measured*: 0.448 to 0.526
over the three. The pixel figure rose with it, from 0.236 to 0.285, back to where it stood before
#801's repaint lowered it (0.286), and still below vanilla's heat exchanger (0.566).
Neither says the parts read at 32 px a tile; that is Truls's eye, on a frame from
`scripts/probe-heat-exchanger-art.ps1`.

**The loom's sheath colours** are 43.7 dE00 or more from every accent and from hazard yellow, on
the palette rows through `tools/colour_distance.py`, with each linear row put through the sRGB
transfer function first (*measured* 2026-10-28):

| sheath | energy | steam | water | plasma | tritium | helium-3 | hazard yellow |
|---|---:|---:|---:|---:|---:|---:|---:|
| `cable-red` | 46.9 | 56.4 | 58.6 | 45.8 | 72.1 | 51.0 | 55.4 |
| `cable-green` | 50.5 | 52.1 | 54.5 | 54.1 | 47.0 | 56.4 | 43.7 |

The closest pair of accents is 11.7 (`models/house-style.md`, Palette). These are palette rows and
not drawn pixels. ADR 0034 compares accents on one machine with each other, and a sheath is not an
accent, so the table says only that no sheath is near any of them.

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

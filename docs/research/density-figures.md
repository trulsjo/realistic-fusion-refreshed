# Two density figures for rendered art, and the "before" for #798

Measured 2026-10-27 for [#799](https://github.com/trulsjo/realistic-fusion-refreshed/issues/799),
the first child of [#798](https://github.com/trulsjo/realistic-fusion-refreshed/issues/798), the
second attempt at denser rendered art. #798 asked for "more detail" to be measured as well as judged,
and for a figure that grime and noise cannot raise. This note says how the two figures are taken,
what each cannot see, and what they read before any of #798's work. Rerun it with the commands below.

## The two figures

`tools/measure-density.py` takes both. Its docstring has the method, and the self-test proves the
count can fail (`python tools/measure-density.py --self-test`).

- **Pixel figure:** the share of a sheet's opaque interior pixels that are edge. An edge pixel's
  luminance differs from a 9 px box blur of its surround by more than 14 of 255, either sign. The
  blur, the threshold and the opacity cut are `docs/research/detail-floor/measure-detail.py`'s,
  imported, so this note and [`detail-floor.md`](detail-floor.md) use one procedure. It reads
  pixels only, so it runs on any sheet.
- **Normal-pass figure:** the same count on a normal pass of our own model, in any of the three
  channels. `models/render-normal.py` renders it with the north sheet's rig, frame and camera. The
  two figures read the same pixels: on `rf-heat-exchanger` the pass and the sheet are both
  1344 × 704, and their interiors differ by two pixels in 319 713.

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

## What the "before" says, and how far it goes

Both of our machines are below both vanilla sheets on the pixel figure. The isotope collector is level
with Krastorio 2's reactor, and the heat exchanger is below all three. That is *inferred* from the
table above, which is one sheet each, the north one.

It does not say the session's 2026-10-26 read by eye was wrong. That read was that the collector
still looks like a different mod beside Krastorio 2's reactor. Both readings stand: the collector
is as edge-dense as the reactor and still looks different from it. So density may not be the gap
the eye saw. Value range and marking colour, two of #798's five gaps, are what this figure is
blind to; see below. That is *inferred* and not measured.

## What each figure cannot see

Each point here is *inferred* from the method in `tools/measure-density.py` and is not measured.

**The pixel figure:**

- **It cannot tell detail from grain.** Grime, procedural noise and Cycles noise all count as edge,
  as `detail-floor.md` already says of its sweep. That is the reason the second figure exists.
- **It sees luminance only.** Two colours of one brightness meet with no edge, so an accent band
  or a hazard-yellow block can add nothing.
- **It is blind to value range.** A machine repainted darker, with the same detail, reads the same
  whenever its steps stay above the threshold.
- **It depends on resolution.** It compares only sheets at the same pixels per tile and the same
  scale, which is why a Figma export would need rescaling first.
- **It reads one sheet.** It takes the north sheet, never the glow, the shadow or another
  direction.

**The normal-pass figure:**

- **It cannot see a material by design.** Texture, grime and paint do not bend a surface. That
  makes it the wrong figure to test whether procedural grain is poor at 64 px to the tile, which
  ADR 0043 says the pixel figure could test.
- **It counts curvature as edge.** It does so wherever the surface turns faster than the threshold
  over the blur's width. A threshold of 14 of 255 on a channel mapped from −1..1 is about 0.11 of
  a unit normal's component, roughly 6 degrees, *inferred* from the mapping and not measured. A
  small pipe or a corrugated hose therefore counts heavily, and a large drum lightly.
- **It exists only for our machines**, since it needs the model. It cannot compare against
  vanilla, Krastorio 2 or Figma.
- **It sees only the visible surface.** It reads the north camera's first hit, so a part hidden
  behind another adds nothing.

**Both:**

- **They are shares, not counts.** A machine that grows a large flat panel reads less dense even
  though nothing was taken away.
- **Neither is a target.** They guide the work, and Truls's eye in a real map accepts it (#798).

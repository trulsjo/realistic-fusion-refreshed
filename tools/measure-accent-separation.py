#!/usr/bin/env python3
"""Report how far apart two fluid accents land at zoom 1, on the shipped sheets, and how much of
each one a player actually gets.

    python tools/measure-accent-separation.py
    python tools/measure-accent-separation.py --machine rf-isotope-collector
    python tools/measure-accent-separation.py --de76        # quote dE76 beside dE00, for a note

A BENCH, NOT A CHECK, in this repository's own three words (CONTEXT.md, Measurement words): it
measures a quantity, reports it, and asserts only its own validity. It says nothing about whether
two accents are far enough apart -- that is a decision, it belongs to Truls, and #359 holds it.
scripts/load-check.ps1 and scripts/ship-check.ps1 do not run this and nothing fails because of it.
The shape is tools/measure-socket-parts.py's, one sheet over: that one asks how tall a socket's
pieces are drawn, this one asks what colour they are and how much of it there is.

WHAT IT MEASURES, AND WHERE. An accent is drawn as the BAND around a socket's tube -- one per
connection, in the fluid's own accent colour, models/rf_blender.py's BAND_DEPTH wide and standing
BAND_PROUD past the tube. So "how much colour an accent gets" is how much of that band the sheet
still draws -- which on half the sockets here is less than the band, because the machine's own body
stands in front of the rest -- and "how far two accents land apart" is the distance between two of
them as drawn. Everything comes off the committed sheets under
realistic-fusion-refreshed-assets/graphics/rendered/<machine>/; no game, no Blender, no render.

THREE THINGS IT HAS TO GET RIGHT, AND HOW EACH IS DONE HERE.

1. SAMPLE THE SHEET, NEVER THE PALETTE. The palette rows in models/house-style.md are linear RGB
   fed to Blender, and AgX plus the lighting spend most of the separation before a player sees any
   of it. This file never reads a palette row: every figure below comes out of a PNG.
   docs/research/accent-separation.md quotes both and says how the palette half was worked out.

2. ZOOM 1 IS 32 PX TO THE TILE. The sheets are drawn at 64 and ship at `scale 0.5`, so the sheet is
   HALVED before anything is measured off it, and every figure printed carries its zoom. #371 is
   what a picture quoted without its zoom costs. The halving averages in LINEAR light with the
   colour premultiplied by alpha, which is what a graphics card filtering an sRGB texture does;
   averaging the gamma-encoded bytes instead darkens every edge and moves every reading.

3. A PAIR IS DERIVED, NEVER LISTED. Two connections on one entity whose fluids map to different
   accents are a pair, and the map is models/rf_blender.py's ACCENT_OF_FLUID. The connections come
   from the committed models/<machine>/geometry.json, which tools/extract-geometry.py wrote from
   the game's own dump. A machine gaining a fluid changes the answer with nothing edited here.

THE WINDOW, AND WHY EVERY FIGURE CARRIES ONE. A column that straddles two pieces of a socket draws
both, and one column either way moves a reading -- the leak tools/socket_strip.py's header sets out,
which published two wrong rows into models/house-style.md and shipped them. So every boundary is
pulled in by the width the renderer's filter smears an edge, and where a band ENDS is measured
rather than assumed: `follow_band` walks each column inboard and keeps it only while it is nearer
the accent than the machine's own surface, both read off the same sheet. The first version of this
file took the band's built span on trust and measured the heat exchanger's body on four of its six
sockets; the review of #379 caught it, and that is why `follow_band` exists.

THEN EVERY COLOUR IS TAKEN AGAIN through its window narrowed by one at each end, in both axes. The
largest move any of those four produces is printed beside the colour as its WOBBLE, and a pair whose
two accents are no further apart than their own wobbles is reported unstable rather than returned.
A band is a lit cylinder, so its colour genuinely varies across it and a median is a summary rather
than a value -- which is why the guard is a COMPARISON, wobble against the distance being reported,
and not a tolerance somebody picked. There is no threshold in this file, because a threshold on
legibility would be a decision wearing a check's clothes.

WHAT IT CANNOT REACH. Only machines with a committed models/<machine>/geometry.json are in scope:
that file is where a connection's fluid is recorded without starting the game. Every other entity's
pairs are outside this bench and are not silently dropped -- run tools/extract-geometry.py for one
and it appears here. Of the machines in scope, those with no rendered sheet are listed with their
pairs named as untestable, so the list is there the day a sheet arrives.

TWO SELF-CHECKS, BESIDE IT, AND THEY GRADE DIFFERENT THINGS. tools/test_colour_distance.py grades
the colour maths against Sharma, Wu and Dalal's published test data -- somebody else's answers, so a
mistake shared with this repository cannot pass. tools/test_measure_accent_separation.py pins the
three pieces of arithmetic that would be silently wrong rather than loudly wrong: the halved
window's off-by-one, the filter guard's own off-by-one at a boundary, and the halving being done in
light rather than in gamma-encoded bytes.

Pure Python. Needs pillow and numpy -- the same pair tools/check-socket-height.py needs, and this
repository's only third-party Python. A missing one is a failure with a message, not a skip. Run
from the repository root.
"""
import argparse
import itertools
import json
import math
import os
import sys

try:
    import numpy as np
    from PIL import Image
except ImportError as missing:
    sys.exit(f"measure-accent-separation: {missing}. This reads sprite pixels and needs both pillow "
             f"and numpy in the `python` on PATH -- `python -m pip install pillow numpy`.")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "models"))
import colour_distance as cd  # noqa: E402
import rf_blender as rf  # noqa: E402  (no bpy at module level)
import socket_strip  # noqa: E402

MODELS_DIR = "models"
RENDERED_DIR = os.path.join("realistic-fusion-refreshed-assets", "graphics", "rendered")

# THE ZOOM EVERY FIGURE HERE IS AT. CONTEXT.md's Zoom entry: zoom 1 is 32 px to the tile and is the
# size a player meets a machine at. The sheets are drawn at `manifest.frame.pixels_per_tile` and
# ship at `manifest.frame.scale`; this bench refuses a machine whose product is not 32 rather than
# quietly reporting a magnified figure.
ZOOM_1_PX_PER_TILE = 32


def accent_of(connection):
    """The house-style accent a connection carries, through models/rf_blender.py's map.

    A CONNECTION WITH NO FLUID FALLS BACK TO ITS `connection_category`, and that is not a guess.
    rf-aneutronic-reactor's plasma faces take any of ADR 0010's plasmas, so the dump records
    `fluid: null` -- but they carry `connection_category: rf-plasma`, and `rf_blender.accent`'s
    plasma fallback reads that to the one accent every plasma shares. A connection with NEITHER
    carries no accent this bench can name, and it says so rather than reaching `rf.accent` with
    nothing: rf-heater's input boxes are a chemical plant's, unfiltered and uncontained, so the
    fluid in them is whatever recipe is set. That machine wears Krastorio 2's sprites and has no
    band to measure anyway, but a machine of ours could grow such a connection tomorrow.
    """
    named = connection["fluid"] or connection.get("connection_category")
    if not named:
        raise socket_strip.Unmeasurable(
            f"the {connection['direction']} connection records neither a fluid nor a "
            f"connection_category, so nothing says which accent it carries")
    return rf.accent(named)


def accents_of(geometry):
    """({accent: [connection, ...]}, [(connection, why), ...]) for one machine.

    The second half is the connections whose accent cannot be named at all. They are handed back
    rather than dropped, because a machine with one is a machine whose pair list is INCOMPLETE and
    a reader has to be told so.
    """
    by_accent, unnamed = {}, []
    for c in geometry["connections"]:
        try:
            by_accent.setdefault(accent_of(c), []).append(c)
        except socket_strip.Unmeasurable as why:
            unnamed.append((c, str(why)))
    return by_accent, unnamed


def halve(rgba):
    """A sheet at 64 px to the tile, at zoom 1's 32. Returns (rows, cols, 4) floats, sRGB 0..1.

    AVERAGED IN LINEAR LIGHT, WITH THE COLOUR PREMULTIPLIED BY ALPHA. Both halves matter and both
    go wrong the obvious way round: averaging the gamma-encoded bytes darkens every edge, because
    sRGB is not linear in light; averaging un-premultiplied colour lets the RGB of a fully
    transparent pixel -- which Cycles writes as black -- into the average at every silhouette edge.
    """
    h, w = rgba.shape[0] // 2 * 2, rgba.shape[1] // 2 * 2
    a = rgba[:h, :w, 3:4].astype(float) / 255.0
    lit = cd.srgb_to_linear(rgba[:h, :w, :3].astype(float) / 255.0) * a
    def blocks(v):
        return v.reshape(h // 2, 2, w // 2, 2, v.shape[-1]).mean(axis=(1, 3))
    a_mean, lit_mean = blocks(a), blocks(lit)
    rgb = cd.linear_to_srgb(np.divide(lit_mean, a_mean, out=np.zeros_like(lit_mean),
                                      where=a_mean > 0))
    return np.concatenate([rgb, a_mean], axis=-1)


def inside(lo, hi):
    """The halved indices whose two source indices both lie in `lo`..`hi` inclusive, as (lo, hi)
    inclusive, or None when none do. A halved pixel straddling the end of a window holds a source
    pixel the window excluded, so it belongs to neither."""
    j0, j1 = -(-lo // 2), (hi - 1) // 2
    return (j0, j1) if j1 >= j0 else None


def band_edges(s):
    """(front, back, step) of the accent band along the tube, in fractional sheet columns.

    `front` is the mouth-side edge and `back` the inboard one; `step` is +1 when inboard is towards
    the right of the sheet and -1 when it is towards the left, so a caller can walk the tube without
    knowing which way the socket points. Straight out of models/rf_blender.py's BAND_BACK and
    BAND_DEPTH, measured from the mouth the same way models/rf_parts.py's `socket` draws it.
    """
    step = -s.outward
    front = s.mouth_col + step * (rf.BAND_BACK - rf.BAND_DEPTH / 2) * s.px_per_tile
    back = s.mouth_col + step * (rf.BAND_BACK + rf.BAND_DEPTH / 2) * s.px_per_tile
    return front, back, step


def clear_of(edge, step, inward):
    """The first whole sheet column on one side of a fractional boundary that the renderer's filter
    does not smear across, walking in `step`.

    socket_strip.Strip.columns_of's convention, and it has to be that one rather than a rounding of
    its own: a column j covers [j, j+1), so it is clear of a boundary ahead of it only when its FAR
    side is, which is one column short of where a plain floor lands. `inward` is True for the column
    just past the boundary in the direction of travel, False for the last one before it.
    """
    guard = socket_strip.FILTER_HALF_PX
    if (step > 0) == inward:
        return int(math.ceil(edge + guard))
    return int(math.floor(edge - guard)) - 1


def follow_band(alpha_rgb, rows, s, clean):
    """How far inboard the accent is still what the sheet draws, as ((lo, hi), why it stopped).

    THE BAND'S GEOMETRIC SPAN IS WHERE IT WAS BUILT, NOT WHERE IT IS SEEN, and the difference is a
    whole machine wide. The band starts 0.17 tiles back from the socket's mouth while the outboard
    strip is only 0.25 tiles deep, so most of every band on these machines lies inboard of the
    collision edge -- and what is drawn there is whichever of the band and the machine's own body
    is nearer the camera. On rf-isotope-collector's west socket that is the band, which reads green
    to sheet column 216, a tenth of a pixel from where the geometry puts its back. On
    rf-heat-exchanger's west socket it is the body, from column 210 on. Assuming either answer
    everywhere measures the wrong thing on half the sockets, which is what the first version of
    this bench did.

    So each column is CLASSIFIED rather than assumed, between two colours the sheet itself
    supplies: the band, taken from the filter-clean columns outboard of the footprint where
    tools/socket_strip.py guarantees only the socket is drawn, and the machine, taken from the
    columns just past the band's back edge where the band is guaranteed absent. A column joins the
    run while it is nearer the first than the second. Nearest-of-two between two measured
    references, so there is no threshold here either.
    """
    front, back, step = band_edges(s)
    width = alpha_rgb.shape[1]

    def lab_of(col0, col1):
        block = alpha_rgb[rows[0]:rows[1] + 1, min(col0, col1):max(col0, col1) + 1]
        drawn = block[..., 3] > socket_strip.ALPHA_FLOOR
        if not drawn.any():
            raise socket_strip.Unmeasurable(f"nothing is drawn in columns {col0}..{col1}")
        return cd.srgb_to_lab(np.median(block[..., :3][drawn], axis=0) / 255.0)

    # The machine's own surface, read three columns past the band's back edge. It has to exist: with
    # nothing to compare a column against, an inboard column cannot be told from the body and this
    # bench will not guess which it is.
    off0 = clear_of(back, step, inward=True)
    off1 = off0 + 2 * step
    if not (0 <= off0 < width and 0 <= off1 < width):
        raise socket_strip.Unmeasurable(
            f"the sheet ends {abs(off1 - off0) + 1} columns past the band's back edge, so there is "
            f"nothing to tell an inboard column of band from a column of machine")
    band_lab, body_lab = lab_of(*clean), lab_of(off0, off1)

    last = clear_of(back, step, inward=False)
    lo, hi = clean
    col = (hi if step > 0 else lo) + step
    while (last - col) * step >= 0 and 0 <= col < width:
        here = lab_of(col, col)
        to_band, to_body = cd.ciede2000(here, band_lab), cd.ciede2000(here, body_lab)
        if to_band > to_body:
            return (lo, hi), (f"column {col} is {to_body:.1f} dE00 from the machine's own surface "
                              f"and {to_band:.1f} from the accent, so the band stops before it")
        lo, hi = min(lo, col), max(hi, col)
        col += step
    return (lo, hi), None


def sample(sheet, rows, cols):
    """(median sRGB, pixels counted) of what is drawn in a halved window.

    THE MEDIAN, NOT THE MEAN. A band is a lit cylinder, so its pixels are a spread rather than a
    value; the mean of a spread moves as soon as one contaminated column joins it, while the median
    moves only when the contamination is half the sample. That is what lets the narrowing below
    tell a leak from the light.
    """
    (r0, r1), (c0, c1) = rows, cols
    block = sheet[r0:r1 + 1, c0:c1 + 1]
    drawn = block[..., 3] > socket_strip.ALPHA_FLOOR / 255.0
    if not drawn.any():
        raise socket_strip.Unmeasurable(f"nothing is drawn in rows {r0}..{r1}, columns {c0}..{c1} "
                                        f"of the halved sheet")
    return np.median(block[..., :3][drawn], axis=0), int(drawn.sum())


def wobble_of(sheet, lab, rows, cols):
    """How far the colour moves under the four one-step narrowings, in dE00, and which did it.

    Both axes, one step each way. The column narrowings catch a neighbouring part of the socket
    leaking in along the tube; the row narrowings catch the anti-aliased top and bottom of the
    silhouette, where a band's edge pixel is half band and half whatever is behind it.
    """
    (r0, r1), (c0, c1) = rows, cols
    windows = [((r0, r1), (c0 + 1, c1)), ((r0, r1), (c0, c1 - 1)),
               ((r0 + 1, r1), (c0, c1)), ((r0, r1 - 1), (c0, c1))]
    worst, where = 0.0, None
    for n_rows, n_cols in windows:
        if n_rows[1] < n_rows[0] or n_cols[1] < n_cols[0]:
            raise socket_strip.Unmeasurable(
                f"at zoom 1 its window is {r1 - r0 + 1} by {c1 - c0 + 1} screen px, which cannot be "
                f"narrowed at both ends, so this reading could not be checked")
        moved = cd.ciede2000(lab, cd.srgb_to_lab(sample(sheet, n_rows, n_cols)[0]))
        if moved > worst:
            worst, where = moved, (n_rows, n_cols)
    return worst, where


class Reading:
    """One socket's accent band, as the shipped sheets draw it at zoom 1."""

    def __init__(self, connection, accent, sheet_name, rows, cols, rgb, pixels,
                 height_px, width_px, wobble, wobble_at, stopped):
        self.connection, self.accent, self.sheet_name = connection, accent, sheet_name
        self.rows, self.cols, self.rgb, self.pixels = rows, cols, rgb, pixels
        self.height_px, self.width_px = height_px, width_px
        self.wobble, self.wobble_at, self.stopped = wobble, wobble_at, stopped
        self.lab = cd.srgb_to_lab(rgb)

    @property
    def socket(self):
        return f"{self.connection['direction']} {self.connection['fluid'] or '(any plasma)'}"

    @property
    def area_px(self):
        """How much accent a player gets at zoom 1, in screen pixels, AS A FLOOR.

        A PRODUCT RATHER THAN A COUNT, because no alpha count can separate the band from the
        machine's body once the two overlap -- `follow_band` says why -- while a cylinder's
        silhouette does not change along its length, so the height read outboard is the height
        everywhere the accent survives. It is a floor because the run is trimmed at the mouth end by
        the filter guard: about a pixel of band that is certainly drawn is outside every window here.
        """
        return self.width_px * self.height_px

    def hex(self):
        return "#" + "".join(f"{int(round(v * 255)):02x}" for v in self.rgb)


def read_band(directory, manifest, connection, accent):
    """One connection's accent band off the shipped sheets, as a Reading. Raises Unmeasurable."""
    suffix, _, _ = socket_strip.sheet_frame(manifest, connection)
    sheet_name = f"{manifest['machine']}{suffix}.png"
    path = os.path.join(directory, sheet_name)
    if not os.path.exists(path):
        raise socket_strip.Unmeasurable(f"{sheet_name} is not there")
    full = np.asarray(Image.open(path).convert("RGBA"))
    s = socket_strip.strip(full[..., 3], manifest, connection)

    # The silhouette is read through the filter-clean OUTBOARD window, the one
    # tools/measure-socket-parts.py measures the band's height through, because that is where
    # nothing stands behind the band. The colour is then sampled across the band's whole span.
    clean = s.columns_of(rf.BAND_BACK - rf.BAND_DEPTH / 2, rf.BAND_BACK + rf.BAND_DEPTH / 2)
    if clean is None:
        raise socket_strip.Unmeasurable("no column of this sheet draws the accent band clear of "
                                        "what is either side of it")
    top, bottom = s.extent(*clean)            # row edges, `bottom` exclusive
    span, stopped = follow_band(full, (top, bottom - 1), s, clean)

    rows, cols = inside(top, bottom - 1), inside(*span)
    if rows is None or cols is None:
        raise socket_strip.Unmeasurable(f"at zoom 1 the accent is {(span[1] - span[0] + 1) / 2:.1f} "
                                        f"by {(bottom - top) / 2:.1f} px, which leaves no whole "
                                        f"screen pixel inside its window")
    halved = halve(full)
    rgb, pixels = sample(halved, rows, cols)
    wobble, where = wobble_of(halved, cd.srgb_to_lab(rgb), rows, cols)

    # BOTH SIDES OF THE EXTENT ARE MEASURED, AND THE WIDTH IS A FLOOR RATHER THAN THE BAND'S SIZE.
    # The height is the silhouette read outboard, halved. The width is the run `follow_band`
    # actually got, which is trimmed at the mouth end by the filter guard -- about a pixel of band
    # that is certainly drawn is outside it -- so the figure is at least this much and never more
    # than models/rf_blender.BAND_DEPTH allows.
    return Reading(connection, accent, sheet_name, rows, cols, rgb, pixels,
                   (bottom - top) / 2, (span[1] - span[0] + 1) / 2, wobble, where, stopped)


def machines(models_dir, rendered_dir, only):
    """Every machine with a committed geometry file, as (name, model-dir, geometry, sheets-or-None)."""
    found = []
    for entry in sorted(os.listdir(models_dir)):
        path = os.path.join(models_dir, entry, "geometry.json")
        if not os.path.exists(path):
            continue
        geometry = json.load(open(path, encoding="utf-8"))
        if only and geometry["name"] != only:
            continue
        sheets = os.path.join(rendered_dir, entry)
        found.append((geometry["name"], entry, geometry,
                      sheets if os.path.exists(os.path.join(sheets, "manifest.json")) else None))
    return found


def report_pairs(pairs, readings, failed, de76):
    """Every pair of accents on one machine. Returns (measured, untestable)."""
    measured = untestable = 0
    for a, b in pairs:
        missing = [x for x in (a, b) if x not in readings]
        if missing:
            why = "; ".join(f"{m}: " + ("; ".join(failed[m]) if m in failed
                                        else "no connection of this machine draws it on a sheet")
                            for m in missing)
            print(f"  pair {a} x {b}   UNTESTABLE: {why}")
            untestable += 1
            continue
        # `key=` rather than tuple order: two socket pairs can land exactly the same distance
        # apart, and a Reading has no ordering to fall through to.
        got = sorted(((cd.ciede2000(x.lab, y.lab), x, y)
                      for x in readings[a] for y in readings[b]), key=lambda t: t[0])
        lo, hi = got[0], got[-1]
        # THE ONLY JUDGEMENT IN THIS FILE, AND IT IS ABOUT THE INSTRUMENT. Two colours whose
        # distance is no bigger than the two windows' own wobbles are not measured as different;
        # the number would be the window moving, not the accents parting.
        noise = lo[1].wobble + lo[2].wobble
        verdict = (f"  UNSTABLE: the two windows wobble {noise:.1f} dE00 between them, which is not "
                   f"smaller than the {lo[0]:.1f} they are apart") if noise >= lo[0] else ""
        extra = (f"  (dE76 {cd.de76(lo[1].lab, lo[2].lab):.1f} .. "
                 f"{cd.de76(hi[1].lab, hi[2].lab):.1f})") if de76 else ""
        print(f"  pair {a} x {b}   dE00 {lo[0]:.1f} .. {hi[0]:.1f} over {len(got)} socket "
              f"pair(s){extra}{verdict}")
        print(f"       closest  {lo[0]:>5.1f}  {lo[1].socket} on {lo[1].sheet_name}  vs  "
              f"{lo[2].socket} on {lo[2].sheet_name}")
        if hi is not lo:
            print(f"       furthest {hi[0]:>5.1f}  {hi[1].socket} on {hi[1].sheet_name}  vs  "
                  f"{hi[2].socket} on {hi[2].sheet_name}")
        measured += 1 if not verdict else 0
        untestable += 1 if verdict else 0
    return measured, untestable


def report_machine(name, model_dir, geometry, sheets, de76):
    """One machine. Returns (pairs measured, pairs untestable, readings refused)."""
    by_accent, unnamed = accents_of(geometry)
    pairs = list(itertools.combinations(sorted(by_accent), 2))
    print(f"\n{name}")
    for connection, why in unnamed:
        print(f"  INCOMPLETE: {why}, so any pair it would make is missing from the list below.")
    if not pairs:
        print(f"  no pair: it carries {', '.join(sorted(by_accent)) or 'no fluid at all'}, so no "
              f"two accents can share it.")
        return 0, 0, 0
    if sheets is None:
        print(f"  NOT RENDERED YET -- models/{model_dir}/ has a geometry file and no sheets, so "
              f"every pair below is untestable until it is rendered:")
        for a, b in pairs:
            print(f"    pair {a} x {b}   UNTESTABLE: no rendered sheet")
        return 0, len(pairs), 0

    manifest = json.load(open(os.path.join(sheets, "manifest.json"), encoding="utf-8"))
    frame = manifest["frame"]
    at_zoom_1 = frame["pixels_per_tile"] * frame["scale"]
    if at_zoom_1 != ZOOM_1_PX_PER_TILE:
        print(f"  UNMEASURABLE: these sheets are {frame['pixels_per_tile']} px to the tile at scale "
              f"{frame['scale']}, so a player meets them at {at_zoom_1:g} px to the tile, not "
              f"{ZOOM_1_PX_PER_TILE}. Every figure this bench prints is at zoom 1 and it will not "
              f"print one off a sheet that does not reach it.")
        return 0, len(pairs), 0

    readings, failed, refused = {}, {}, 0
    print(f"  {'accent':<9} {'socket':<25} {'sheet':<26} {'colour':<8} {'L*':>5} {'a*':>6} "
          f"{'b*':>6} {'wobble':>6} {'w x h':>11} {'area':>7}  window at zoom 1")
    for accent in sorted(by_accent):
        for connection in by_accent[accent]:
            socket = f"{connection['direction']} {connection['fluid'] or '(any plasma)'}"
            try:
                r = read_band(sheets, manifest, connection, accent)
            except socket_strip.Unmeasurable as why:
                print(f"  {accent:<9} {socket:<25} UNMEASURABLE: {why}")
                failed.setdefault(accent, []).append(f"{socket} is unmeasurable ({why})")
                refused += 1
                continue
            print(f"  {accent:<9} {r.socket:<25} {r.sheet_name:<26} {r.hex():<8} "
                  f"{r.lab[0]:>5.1f} {r.lab[1]:>+6.1f} {r.lab[2]:>+6.1f} {r.wobble:>6.1f} "
                  f"{r.width_px:>4.1f} x {r.height_px:<4.1f} {r.area_px:>7.1f}  "
                  f"rows {r.rows[0]}..{r.rows[1]}, cols {r.cols[0]}..{r.cols[1]}, "
                  f"{r.pixels} px sampled")
            if r.stopped is not None:
                print(f"  {'':<9} {'':<25} SHORT OF THE BAND'S BACK EDGE: {r.stopped}")
            readings.setdefault(accent, []).append(r)

    print(f"  colour is the median of the window; 'wobble' is how far it moves, in dE00, under the "
          f"worst of four one-step narrowings")
    print(f"  'w x h' is how much accent the sheet actually draws at zoom 1, in screen px, and "
          f"'area' their product; both are floors, trimmed at the mouth by the filter guard")
    for accent, rs in sorted(readings.items()):
        if len(rs) < 2:
            continue
        # THE YARDSTICK, AND IT IS A MEASUREMENT RATHER THAN AN OPINION. One accent on two faces of
        # one machine is the same colour lit two ways, so how far THOSE land apart is the scale any
        # figure above has to be read against.
        apart = sorted(((cd.ciede2000(x.lab, y.lab), x, y)
                        for x, y in itertools.combinations(rs, 2)), key=lambda t: t[0])
        worst = apart[-1]
        print(f"  same accent, two faces: {accent} spans dE00 {apart[0][0]:.1f} .. {worst[0]:.1f} "
              f"across its {len(rs)} sockets ({worst[1].socket} vs {worst[2].socket})")
    measured, untestable = report_pairs(pairs, readings, failed, de76)
    return measured, untestable, refused


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--machine", help="one prototype name, e.g. rf-isotope-collector")
    ap.add_argument("--models", default=MODELS_DIR, help="where the geometry files live")
    ap.add_argument("--rendered", default=RENDERED_DIR, help="where the shipped sheets live")
    ap.add_argument("--de76", action="store_true",
                    help="quote the plain Euclidean distance beside CIEDE2000, for a note that "
                         "has to show the gap between the two formulas")
    a = ap.parse_args(argv)

    found = machines(a.models, a.rendered, a.machine)
    if not found:
        sys.exit(f"measure-accent-separation: no machine with a geometry file under {a.models}"
                 + (f" is called {a.machine}" if a.machine else ""))

    print(f"Accent separation on the shipped sheets, AT ZOOM 1 -- {ZOOM_1_PX_PER_TILE} px to the "
          f"tile, the size a player meets a machine at (CONTEXT.md, Zoom).")
    print("Perceptual distance is CIEDE2000 over CIE L*a*b* under D65, measured off the PNG and "
          "never off a palette row.")
    measured = untestable = refused = 0
    for name, model_dir, geometry, sheets in found:
        m, u, r = report_machine(name, model_dir, geometry, sheets, a.de76)
        measured, untestable, refused = measured + m, untestable + u, refused + r

    print(f"\n{measured} pair(s) measured, {untestable} untestable, off {len(found)} machine(s) "
          f"with a committed geometry file.")
    if refused:
        print(f"{refused} socket reading(s) above carry no number this bench will stand behind. "
              f"Read the reason on each; none of them is a finding about the art.")
    print("Only machines with a models/<machine>/geometry.json are in scope -- that file is where a "
          "connection's fluid is recorded without starting the game. Run tools/extract-geometry.py "
          "for another entity and its pairs appear here.")
    print("Nothing above decides whether an accent reads. That is #359's, and it is Truls's.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

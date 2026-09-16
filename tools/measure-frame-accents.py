#!/usr/bin/env python3
"""Report what an accent band's colour is in a GAME FRAME, through the same window
tools/measure-accent-separation.py reads it through on the shipped sheet.

    python tools/measure-frame-accents.py docs/research/accent-legibility-at-zoom-1/collector-alone.png
    python tools/measure-frame-accents.py docs/research/accent-legibility-at-zoom-1/*.png

A BENCH, NOT A CHECK, in this repository's own three words (CONTEXT.md, Measurement words): it
measures a quantity, reports it, and asserts only its own validity. It says nothing about whether
an accent reads, and it adds no threshold -- that is a decision, it belongs to Truls, and ADR 0034
holds it. scripts/load-check.ps1 and scripts/ship-check.ps1 do not run this and nothing fails
because of it.

WHY IT EXISTS (#387). Two notes measured the same two sockets and disagreed, and nobody knew which
part of the disagreement was real:

    socket                     sheet, accent-separation.md   frame, accent-legibility-at-zoom-1.md
    collector west, tritium    #a5bbaa                       #a3baaa                    0.6 dE00
    exchanger west, water      #92acc3                       #7592ae                    8.4 dE00

The two figures came through DIFFERENT WINDOWS. tools/measure-accent-separation.py picks its columns
from the geometry, through tools/socket_strip.py, with a filter guard and a nearest-of-two
classification against the machine's own body; the game figures came off a hand-placed hue cut. A
difference between two windows is not a measurement of a difference between a sheet and a frame, and
that note says so. Settling it takes the bench's own window applied to a game frame. This is that.

THE WINDOW IS NOT RE-DERIVED HERE, IT IS BORROWED WHOLE. Every column and row below comes out of
`measure_accent_separation.read_band`, which is the same call that produces the sheet figure -- the
same `socket_strip.strip`, the same filter guard, the same `follow_band` classification, the same
halving. This file adds exactly one thing: where that window lands on a frame. So the comparison is
one window over two images, which is the only shape in which the difference means anything.

WHY ONLY ZOOM 1, AND WHY THAT IS THE WHOLE OF THE MAPPING. The sheets are drawn at 64 px to the
tile and ship at `scale 0.5`, so the game draws them at 32 px to the tile at zoom 1 -- and
measure-accent-separation.py halves each sheet to 32 px to the tile before it measures anything.
The halved sheet and a zoom-1 frame are therefore the same scale exactly, and the mapping between
them is a TRANSLATION BY A WHOLE NUMBER OF PIXELS and nothing else. At any other zoom it would be a
resampling, the window would stop being the window, and the figure would stop being comparable. So
a frame at another zoom is refused rather than scaled -- which is CONTEXT.md's Zoom entry applied to
an instrument instead of to prose.

THE TRANSLATION IS THE PART THAT IS WRONG SILENTLY, and `sheet_to_frame` below is all of it. A frame
whose window is off by ten pixels still returns a plausible green, because a socket is surrounded by
a machine that is also greenish; off by fifty it returns grass, which at least looks wrong.
tools/test_measure_frame_accents.py pins it against cases worked out by hand, including the one that
actually bites: a machine's own centre is NOT the camera's. rf-isotope-collector's frame is centred
on x 22 while the machine stands at x 22.5, because an odd footprint snaps to a tile centre and the
rig's spacing arithmetic does not. Nothing said so until #385 put it in a sidecar.

WHAT IT CANNOT REACH, each refused by name rather than dropped:

  - A CONNECTION ON A NORTH OR SOUTH FACE. socket_strip measures such a socket on the `-e` sheet --
    the same machine with the camera a quarter turn on -- because only there does the socket run
    left-to-right on screen. A frame of a north-facing machine draws the `` sheet, so the `-e`
    window names pixels that are not in it. Turn the machine in the rig and its north face becomes
    measurable; nothing here guesses.
  - A MACHINE NOT FACING NORTH, for the same reason from the other end.
  - A SHEET WITH A NON-ZERO `frame.shift`. The margin is symmetric on purpose so that nothing has
    to be re-centred (graphics/rendered/pictures.lua); a shift would move the sprite under the
    window and this does not model one.
  - A MACHINE WITH NO COMMITTED models/<machine>/geometry.json, which is where a connection's fluid
    is recorded without starting the game.

Needs pillow and numpy, like every pixel tool here, and a frame's #385 sidecar beside it. Run from
the repository root.
"""
import argparse
import importlib.util
import json
import os
import sys

try:
    import numpy as np
    from PIL import Image
except ImportError as missing:
    sys.exit(f"measure-frame-accents: {missing}. This reads frame pixels and needs both pillow and "
             f"numpy in the `python` on PATH -- `python -m pip install pillow numpy`.")

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "models"))
import colour_distance as cd  # noqa: E402
import socket_strip  # noqa: E402

# measure-accent-separation.py is hyphenated, so it is loaded by path rather than imported. Loaded
# rather than copied: its `read_band` IS the window this bench is about.
_spec = importlib.util.spec_from_file_location(
    "measure_accent_separation", os.path.join(HERE, "measure-accent-separation.py"))
mas = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(mas)

MODELS_DIR = "models"
RENDERED_DIR = os.path.join("realistic-fusion-refreshed-assets", "graphics", "rendered")

# The one zoom the halved sheet and a frame share. See the header.
ZOOM = 1

# Factorio's `direction` for north, which is the direction every sheet is rendered as declared.
NORTH = 0


def sidecar_of(frame_path):
    """The #385 sidecar beside a frame, as a dict. Raises Unmeasurable when it is not there.

    A frame without one is exactly the state #385 was raised about: a picture a reader can see and
    nothing can measure, because nothing records which world coordinate the centre pixel is.
    """
    path = os.path.splitext(frame_path)[0] + ".json"
    if not os.path.exists(path):
        raise socket_strip.Unmeasurable(
            f"there is no sidecar at {os.path.basename(path)}, so nothing says where this frame's "
            f"camera stood; re-shoot it with an art probe (#385)")
    sidecar = json.load(open(path, encoding="utf-8"))
    # NOT EVERY SIDECAR IS A CAMERA'S. The magnified composites beside these frames carry one of
    # their own shape -- panels cut out of other frames, with no camera and no machines of their
    # own -- and a missing key has to come back as this bench refusing to read the file, not as a
    # KeyError from four calls further in.
    missing = [k for k in ("zoom", "pixels_per_tile", "resolution", "centre", "machines")
               if k not in sidecar]
    if missing:
        raise socket_strip.Unmeasurable(
            f"{os.path.basename(path)} records no {', '.join(missing)}, so it is not a camera's "
            f"sidecar; this bench reads a frame an art probe shot, not one cut out of other frames")
    return sidecar


def sheet_to_frame(sidecar, machine, manifest):
    """(col0, row0, scale), where a HALVED-SHEET coordinate u maps to the frame at col0 + u * scale.

    THE WHOLE OF THE WORLD-TO-SCREEN MAPPING, and the part that is wrong silently. A window ten
    pixels out still returns a plausible green, because a socket is surrounded by a machine that is
    also greenish.

    A screenshot puts the world position the camera was centred on at the middle of the image, and
    draws `pixels_per_tile` pixels to the tile -- 32 at zoom 1, 32 * zoom generally. So the machine's
    own centre lands at

        W / 2 + (machine.x - centre.x) * pixels_per_tile

    pixels from the left. The sprite is drawn centred on that, with no shift (the margin is
    symmetric on purpose), and the halved sheet is `sheet_w / 2` pixels wide at 32 px to the tile --
    so its own left edge is `sheet_w / 4` of ITS pixels further left, each of which the frame draws
    `zoom` pixels wide. That last factor is the whole of `scale`, and it is why the coordinate this
    returns is fractional in general and whole at zoom 1.

    `u` is a coordinate rather than an index: the centre of halved-sheet pixel j is j + 0.5, and a
    fractional sheet position -- a socket's drawn axis, say -- goes in as it stands.
    """
    ppt = sidecar["pixels_per_tile"]
    zoom = sidecar["zoom"]
    shift = manifest["frame"].get("shift", [0, 0])
    if tuple(shift) != (0, 0):
        raise socket_strip.Unmeasurable(
            f"the sheet records frame.shift {shift}; this draws the sprite centred on the machine "
            f"and does not model a shift")
    sheet_w, sheet_h = manifest["frame"]["north"]
    col = sidecar["resolution"]["w"] / 2 \
        + (machine["position"]["x"] - sidecar["centre"]["x"]) * ppt - sheet_w / 4 * zoom
    row = sidecar["resolution"]["h"] / 2 \
        + (machine["position"]["y"] - sidecar["centre"]["y"]) * ppt - sheet_h / 4 * zoom
    return col, row, zoom


def sheet_origin(sidecar, machine, manifest):
    """The frame pixel (col, row) that holds halved-sheet pixel (0, 0), as whole pixels.

    THE ZOOM-1 CASE OF `sheet_to_frame`, which is where the arithmetic lives -- one copy, because
    tools/measure-pipe-cover-miss.py needs the same mapping at zoom 8 and a second copy of a
    world-to-screen mapping is what tools/socket_strip.py's header is about.

    IT MUST LAND ON A WHOLE PIXEL, AND IT IS CHECKED RATHER THAN ROUNDED. At zoom 1 a halved-sheet
    pixel and a frame pixel are the same size, so a window can be read off the frame by translation
    alone -- but only if the two grids line up. Every term is a multiple of a half tile on these
    rigs, so they do; a rig that placed a machine at a third of a tile would make the window a
    resampling, and a resampled window is not this bench's window.
    """
    col, row, scale = sheet_to_frame(sidecar, machine, manifest)
    if scale != 1:
        raise socket_strip.Unmeasurable(
            f"this frame is zoom {scale}; a window is read off the frame by translation only, which "
            f"is true at zoom 1 alone")
    if col != int(col) or row != int(row):
        raise socket_strip.Unmeasurable(
            f"the sheet's own pixel grid lands at ({col}, {row}) in this frame, which is not a "
            f"whole pixel, so its window cannot be read off the frame without resampling it")
    return int(col), int(row)


def frame_as_halved_sheet(path):
    """A frame as the float RGBA array `measure_accent_separation.sample` reads.

    OPAQUE ON PURPOSE. A sheet's alpha says which pixels are the machine; a frame has no such thing,
    because every pixel of it is drawn -- the ground included. So alpha is set to 1 throughout and
    the median is taken over the whole window, which is the right reading exactly because the window
    was chosen on the sheet, where the silhouette IS known.
    """
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(float) / 255.0
    return np.concatenate([rgb, np.ones(rgb.shape[:2] + (1,))], axis=-1)


class FrameReading:
    """One socket's accent band as a frame draws it, beside the sheet reading it was windowed by."""

    def __init__(self, sheet_reading, rows, cols, rgb, pixels, wobble):
        self.sheet = sheet_reading
        self.rows, self.cols, self.rgb, self.pixels, self.wobble = rows, cols, rgb, pixels, wobble
        self.lab = cd.srgb_to_lab(rgb)

    @property
    def moved(self):
        return cd.ciede2000(self.sheet.lab, self.lab)

    def hex(self):
        return "#" + "".join(f"{int(round(v * 255)):02x}" for v in self.rgb)


def read_frame_band(frame, sidecar, machine, manifest, connection, accent, sheets_dir):
    """One connection's band off a frame, through the sheet's own window. Raises Unmeasurable."""
    if connection["direction"] not in ("west", "east"):
        raise socket_strip.Unmeasurable(
            f"a {connection['direction']} socket is measured on the '-e' sheet -- the camera a "
            f"quarter turn on -- and this frame draws the machine as declared, so that window names "
            f"pixels this frame does not hold")

    sheet_reading = mas.read_band(sheets_dir, manifest, connection, accent)
    col0, row0 = sheet_origin(sidecar, machine, manifest)
    (r0, r1), (c0, c1) = sheet_reading.rows, sheet_reading.cols
    rows, cols = (r0 + row0, r1 + row0), (c0 + col0, c1 + col0)

    h, w = frame.shape[:2]
    if not (0 <= rows[0] and rows[1] < h and 0 <= cols[0] and cols[1] < w):
        raise socket_strip.Unmeasurable(
            f"the sheet's window lands at rows {rows[0]}..{rows[1]}, columns {cols[0]}..{cols[1]}, "
            f"which is outside this {w}x{h} frame -- the machine is clipped or not in it")

    rgb, pixels = mas.sample(frame, rows, cols)
    wobble, _ = mas.wobble_of(frame, cd.srgb_to_lab(rgb), rows, cols)
    return FrameReading(sheet_reading, rows, cols, rgb, pixels, wobble)


def report_frame(path, only=None):
    """Measure one frame and print it. Returns (measured, refused) counts."""
    print(f"\n{os.path.basename(path)}")
    sidecar = sidecar_of(path)
    if sidecar["zoom"] != ZOOM:
        raise socket_strip.Unmeasurable(
            f"this frame is zoom {sidecar['zoom']}; the sheet's own window is defined at zoom "
            f"{ZOOM}, where a halved sheet pixel and a frame pixel are the same size, and at any "
            f"other zoom reading it off would be a resampling")
    print(f"  camera centred on {sidecar['centre']['x']:g},{sidecar['centre']['y']:g} at zoom "
          f"{sidecar['zoom']:g} -- {sidecar['pixels_per_tile']:g} px to the tile, "
          f"{sidecar['resolution']['w']}x{sidecar['resolution']['h']} px")
    frame = frame_as_halved_sheet(path)

    measured, refused = 0, 0
    for machine in sidecar["machines"]:
        if only and machine["name"] != only:
            continue
        model = next((d for d in sorted(os.listdir(MODELS_DIR))
                      if os.path.exists(os.path.join(MODELS_DIR, d, "geometry.json"))
                      and json.load(open(os.path.join(MODELS_DIR, d, "geometry.json"),
                                         encoding="utf-8"))["name"] == machine["name"]), None)
        if model is None:
            continue
        geometry = json.load(open(os.path.join(MODELS_DIR, model, "geometry.json"), encoding="utf-8"))
        sheets_dir = os.path.join(RENDERED_DIR, model)
        manifest_path = os.path.join(sheets_dir, "manifest.json")
        if not os.path.exists(manifest_path):
            print(f"  {machine['name']}: no rendered sheet, so there is no window to borrow")
            continue
        manifest = json.load(open(manifest_path, encoding="utf-8"))

        print(f"  {machine['name']} at {machine['position']['x']:g},{machine['position']['y']:g}, "
              f"{machine['footprint']['w']}x{machine['footprint']['h']} tiles, direction "
              f"{machine['direction']}")
        if machine["direction"] != NORTH:
            print(f"    every socket refused: the machine is turned, and every sheet window is "
                  f"the machine as declared")
            refused += len(geometry["connections"])
            continue
        print(f"    {'socket':<24} {'sheet':<9} {'frame':<9} {'moved':>7} {'wobble':>7}  window")
        for connection in geometry["connections"]:
            label = f"{connection['direction']} {connection['fluid'] or '(any plasma)'}"
            try:
                accent = mas.accent_of(connection)
                r = read_frame_band(frame, sidecar, machine, manifest, connection, accent, sheets_dir)
            except socket_strip.Unmeasurable as why:
                print(f"    {label:<24} not measured here: {why}")
                refused += 1
                continue
            measured += 1
            print(f"    {label:<24} {r.sheet.hex():<9} {r.hex():<9} {r.moved:>6.1f}  "
                  f"{r.wobble:>6.1f}  rows {r.rows[0]}..{r.rows[1]}, cols {r.cols[0]}..{r.cols[1]}, "
                  f"{r.pixels} px")
    return measured, refused


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="What an accent band's colour is in a game frame, through the sheet's own window.")
    parser.add_argument("frames", nargs="+", help="frame PNGs, each with its #385 sidecar beside it")
    parser.add_argument("--machine", help="only this entity, e.g. rf-heat-exchanger")
    args = parser.parse_args(argv)

    print(f"Accent bands in a game frame, AT ZOOM {ZOOM} -- 32 px to the tile, the size a player "
          f"meets a machine at (CONTEXT.md, Zoom).")
    print("Each window is tools/measure-accent-separation.py's own, off the shipped sheet, "
          "translated onto the frame; 'moved' is the sheet-to-frame distance in CIEDE2000.")

    measured = refused = 0
    failed = []
    for path in args.frames:
        try:
            m, r = report_frame(path, args.machine)
        except socket_strip.Unmeasurable as why:
            print(f"\n{os.path.basename(path)}\n  not measured: {why}")
            failed.append(os.path.basename(path))
            continue
        measured, refused = measured + m, refused + r

    print(f"\n{measured} socket(s) measured, {refused} refused, "
          f"{len(failed)} frame(s) not read at all"
          + (f": {', '.join(failed)}" if failed else "."))
    print("'moved' is a difference between two images through ONE window, which is the only shape "
          "in which it is a measurement of the game rather than of two methods.")
    print("Nothing above decides whether an accent reads. That is ADR 0034's, and it is Truls's.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

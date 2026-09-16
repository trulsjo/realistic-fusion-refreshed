#!/usr/bin/env python3
"""The checks for measure-frame-accents.py that need no game and no render:
`python tools/test_measure_frame_accents.py` exits 0 or raises.

ONE PIECE OF ARITHMETIC AND ONE WHOLE RUN. The arithmetic is `sheet_origin`, the translation from a
halved sheet's pixel grid onto a frame's, and it is the part of this bench that is WRONG SILENTLY: a
window ten pixels out still returns a plausible green, because a socket is surrounded by a machine
that is also greenish. So it is pinned against origins worked out by hand, and then against the
thing that makes a wrong one detectable -- that a window nudged off the band reads a materially
different colour, which is the only reason the arithmetic is worth pinning at all.

The window itself is NOT pinned here. It is tools/measure-accent-separation.py's, borrowed whole
through `read_band`, and tools/test_measure_accent_separation.py grades it beside the module that
owns it. A second copy of those assertions here would be the mistake tools/socket_strip.py's header
is about.

THE COMMITTED FRAMES THIS RUNS ON PREDATE THE SHEETS IT WINDOWS THEM WITH, so no colour is asserted
by value -- see docs/research/game-reproduces-the-sheet.md. What is asserted is that the reading
happens, that it lands on the socket rather than on grass, and that a frame the bench cannot stand
behind is refused by name rather than guessed at.
"""
import importlib.util
import json
import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SCRIPT = os.path.join(HERE, "measure-frame-accents.py")
spec = importlib.util.spec_from_file_location("measure_frame_accents", SCRIPT)
mfa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mfa)
sys.path.insert(0, HERE)
import colour_distance as cd  # noqa: E402
import socket_strip  # noqa: E402

FRAMES = os.path.join(ROOT, "docs", "research", "accent-legibility-at-zoom-1")


def side(res_w, res_h, cx, cy):
    return {"pixels_per_tile": 32, "resolution": {"w": res_w, "h": res_h}, "centre": {"x": cx, "y": cy}}


def mach(x, y):
    return {"position": {"x": x, "y": y}}


def man(w, h, shift=(0, 0)):
    return {"frame": {"north": [w, h], "shift": list(shift)}}


# ---------------------------------------------------------------- the translation
#
# THE CASE THAT ACTUALLY BITES IS THE FIRST. rf-isotope-collector's zoom-1 frame is centred on x 22
# while the machine stands at x 22.5: the rig's spacing arithmetic puts the camera on a whole tile
# and an odd footprint snaps its own centre to a tile centre, so the two are half a tile apart and
# the sprite is NOT in the middle of its own frame. Nothing in the repository said so until #385 put
# the camera and the machine in one sidecar. Half a tile is 16 px at zoom 1, which is wider than
# every accent band this bench measures.
assert mfa.sheet_origin(side(352, 352, 22, 0.5), mach(22.5, 0.5), man(704, 704)) == (16, 0)

# rf-heat-exchanger, where camera and machine DO coincide, so the two grids share an origin. The
# sheet is 15 + 2 x 3 tiles wide at 64 px, which is 1344, so a quarter of it is exactly the frame's
# own half-width -- the coincidence that makes this the boring case and the one above the real one.
assert mfa.sheet_origin(side(672, 352, 40.5, 0.5), mach(40.5, 0.5), man(1344, 704)) == (0, 0)

# The same machine in the wider pipes frame, which moves BOTH the camera and the machine. The origin
# has to follow the difference between them and not either one alone: +32 on each axis here, where
# the camera moved 48 tiles east and the machine moved with it.
assert mfa.sheet_origin(side(736, 416, 88.5, 0.5), mach(88.5, 0.5), man(1344, 704)) == (32, 32)

# NORTH AND SOUTH ARE NOT SYMMETRIC WITH EAST AND WEST HERE, and getting the sign wrong is the other
# way to be quietly off. Factorio's +y is south, which is DOWN the screen, so a machine south of the
# camera has a larger row index -- the same sense as the sheet's own rows.
assert mfa.sheet_origin(side(352, 352, 22, 0.5), mach(22, 2.5), man(704, 704)) == (0, 64)
assert mfa.sheet_origin(side(352, 352, 22, 0.5), mach(22, -1.5), man(704, 704)) == (0, -64)

# A fractional origin is REFUSED, not rounded. Reading a window off a grid that does not line up
# would be a resampling, and a resampled window is not the window this bench borrows.
for bad in (mach(22.51, 0.5), mach(22.5, 0.51)):
    try:
        mfa.sheet_origin(side(352, 352, 22, 0.5), bad, man(704, 704))
        raise AssertionError(f"a fractional origin from {bad} was not refused")
    except socket_strip.Unmeasurable as why:
        assert "whole pixel" in str(why), why

# So is a sheet that records a shift, because this bench draws the sprite centred on the machine and
# does not model one. graphics/rendered/pictures.lua keeps the margin symmetric so that none exists.
try:
    mfa.sheet_origin(side(352, 352, 22, 0.5), mach(22.5, 0.5), man(704, 704, shift=(4, 0)))
    raise AssertionError("a non-zero frame.shift was not refused")
except socket_strip.Unmeasurable as why:
    assert "shift" in str(why), why

# ---------------------------------------------------------------- and why it is worth pinning
#
# A WINDOW OFF BY TEN PIXELS STILL RETURNS A COLOUR. That is the whole hazard, so it is measured
# rather than described: the west tritium band is read where it is, and again eight pixels along the
# tube, and the two answers have to be far enough apart that a reader would notice -- but they are
# both plausible greens, which is why no eye would catch it on the printed hex alone.
frame = mfa.frame_as_halved_sheet(os.path.join(FRAMES, "collector-alone.png"))
sidecar = mfa.sidecar_of(os.path.join(FRAMES, "collector-alone.png"))
machine = next(m for m in sidecar["machines"] if m["name"] == "rf-isotope-collector")
manifest = json.load(open(os.path.join(
    ROOT, "realistic-fusion-refreshed-assets", "graphics", "rendered", "isotope-collector",
    "manifest.json"), encoding="utf-8"))
geometry = json.load(open(os.path.join(ROOT, "models", "isotope-collector", "geometry.json"),
                          encoding="utf-8"))
west = next(c for c in geometry["connections"] if c["direction"] == "west")
sheets = os.path.join(ROOT, "realistic-fusion-refreshed-assets", "graphics", "rendered",
                      "isotope-collector")
r = mfa.read_frame_band(frame, sidecar, machine, manifest, west, mfa.mas.accent_of(west), sheets)
(r0, r1), (c0, c1) = r.rows, r.cols
nudged, _ = mfa.mas.sample(frame, (r0, r1), (c0 - 8, c1 - 8))
moved = cd.ciede2000(r.lab, cd.srgb_to_lab(nudged))
assert moved > 5, f"eight pixels along the tube moved the colour only {moved:.1f} dE00, so this " \
                  f"bench could not tell a right window from a wrong one"
assert r.moved < 3, f"the band reads {r.moved:.1f} dE00 from the sheet, which is not a band"

# A NORTH SOCKET IS REFUSED BY NAME. Its window is the '-e' sheet -- the machine with the camera a
# quarter turn on -- and a frame of a north-facing machine does not draw that sheet at all.
north = next(c for c in geometry["connections"] if c["direction"] == "north")
try:
    mfa.read_frame_band(frame, sidecar, machine, manifest, north, mfa.mas.accent_of(north), sheets)
    raise AssertionError("a north socket was measured on a frame that does not draw its sheet")
except socket_strip.Unmeasurable as why:
    assert "-e" in str(why), why

# ---------------------------------------------------------------- whole runs
r = subprocess.run([sys.executable, SCRIPT, os.path.join(FRAMES, "collector-alone.png")],
                   capture_output=True, text=True, encoding="utf-8", cwd=ROOT)
assert r.returncode == 0, r.stderr
assert "west rf-tritium" in r.stdout and "east rf-tritium" in r.stdout, r.stdout
assert "2 socket(s) measured, 1 refused" in r.stdout, r.stdout
# Every figure carries its zoom, and nothing in the output is a verdict about the art.
assert "AT ZOOM 1 -- 32 px to the tile" in r.stdout, r.stdout
assert "Nothing above decides whether an accent reads." in r.stdout, r.stdout

# A FRAME WITH NO SIDECAR IS THE STATE #385 WAS RAISED ABOUT, and it is named rather than guessed
# at. The magnified composites carry a sidecar of a different shape -- panels rather than a camera
# -- so one of them is the case to try: it has a JSON beside it and still cannot be measured.
r = subprocess.run([sys.executable, SCRIPT, os.path.join(FRAMES, "pale-pair-x8.png")],
                   capture_output=True, text=True, encoding="utf-8", cwd=ROOT)
assert r.returncode == 0, r.stderr
assert "not measured" in r.stdout and "1 frame(s) not read at all" in r.stdout, r.stdout

print("measure-frame-accents: ok")

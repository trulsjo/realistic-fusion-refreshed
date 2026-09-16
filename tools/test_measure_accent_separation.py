#!/usr/bin/env python3
"""The checks for measure-accent-separation.py that need no game, no Blender and no render:
`python tools/test_measure_accent_separation.py` exits 0 or raises.

Three pieces of arithmetic and two whole runs. The arithmetic is the part that is silently wrong if
it is wrong -- a window off by one still returns a plausible colour, so does a filter guard off by
one, and so does a halving done in the wrong space -- so each is pinned against a case where the
right answer and the likely wrong one differ visibly. The runs are here because the parts can all
be right while the tool reports nothing, or reports it off the wrong pixels.

tools/test_colour_distance.py grades the colour maths separately, against somebody else's table.
"""
import importlib.util
import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "measure-accent-separation.py")
spec = importlib.util.spec_from_file_location("measure_accent_separation", SCRIPT)
mas = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mas)

# ---------------------------------------------------------------- the window, halved
#
# A halved pixel covers two source pixels and belongs to the window only when BOTH are in it. The
# two cases that turn on that rule are the first and second: relaxing it to "either" widens
# `inside(204, 216)` and `inside(205, 216)` to (102, 108), which puts a source column the window
# excluded inside an accent band's sample -- the leak tools/socket_strip.py's header records
# shipping two wrong rows. The rest pin the arithmetic either side of them.
assert mas.inside(204, 216) == (102, 107), mas.inside(204, 216)   # the collector's west band
assert mas.inside(205, 216) == (103, 107), mas.inside(205, 216)   # odd start: 102 holds 204 too
assert mas.inside(204, 215) == (102, 107), mas.inside(204, 215)   # 107 holds 214 and 215, both in
assert mas.inside(204, 214) == (102, 106), mas.inside(204, 214)   # 215 is out, so 107 is too
assert mas.inside(4, 5) == (2, 2), mas.inside(4, 5)               # exactly one whole pixel
assert mas.inside(5, 5) is None, mas.inside(5, 5)                 # one source pixel is never whole
assert mas.inside(5, 6) is None, mas.inside(5, 6)                 # two, but straddling the pair

# ---------------------------------------------------------------- the filter guard, both ways
#
# A column j covers [j, j+1), so it is clear of a boundary AHEAD of it only when its far side is,
# which is one column short of where a plain floor lands. That is
# socket_strip.Strip.columns_of's convention and `clear_of` has to agree with it; the bench's first
# version floored instead, and put the column straddling the smear inside the window.
# The collector's west band: front 202.88, back 216.96, inboard to the right.
assert mas.clear_of(216.96, +1, inward=False) == 215, mas.clear_of(216.96, +1, inward=False)
assert mas.clear_of(216.96, +1, inward=True) == 218, mas.clear_of(216.96, +1, inward=True)
# The same boundary on a socket pointing the other way: inboard is to the LEFT, so the two answers
# swap sides. A sign error here measures the machine instead of the band on half of every sheet.
assert mas.clear_of(216.96, -1, inward=False) == 218, mas.clear_of(216.96, -1, inward=False)
assert mas.clear_of(216.96, -1, inward=True) == 215, mas.clear_of(216.96, -1, inward=True)

# ---------------------------------------------------------------- the halving
#
# HALF BLACK AND HALF WHITE AVERAGES TO sRGB 188, NOT TO 128. Light is what averages, so the mean of
# linear 0 and linear 1 is 0.5, which encodes to 0.735. Averaging the gamma-encoded bytes instead
# gives 0.5 and every edge on every sheet comes out too dark; the two answers are 60 levels apart,
# which is far more than this bench's own wobbles.
checker = np.zeros((2, 2, 4), dtype=np.uint8)
checker[..., 3] = 255
checker[0, 0, :3] = 255
checker[1, 1, :3] = 255
got = mas.halve(checker)
assert got.shape == (1, 1, 4), got.shape
assert abs(got[0, 0, 0] - 0.7354) < 0.002, f"half black half white halved to {got[0, 0, 0]:.4f}"
assert abs(got[0, 0, 3] - 1.0) < 1e-9, got[0, 0, 3]

# ONE OPAQUE WHITE PIXEL AMONG THREE TRANSPARENT ONES IS STILL WHITE. Cycles writes black in the RGB
# of a fully transparent pixel, so a halving that does not premultiply by alpha drags every
# silhouette edge towards black -- here to a quarter of the light, which encodes to 0.54.
edge = np.zeros((2, 2, 4), dtype=np.uint8)
edge[0, 0] = (255, 255, 255, 255)
got = mas.halve(edge)
assert abs(got[0, 0, 0] - 1.0) < 1e-6, f"an edge pixel halved to {got[0, 0, 0]:.4f}, not white"
assert abs(got[0, 0, 3] - 0.25) < 1e-9, got[0, 0, 3]

# ---------------------------------------------------------------- the whole run
#
# Off the shipped sheets, so it fails if a sheet, a manifest or a geometry file stops agreeing with
# the rest. The collector is asserted by name because it is the pair #359 is about.
r = subprocess.run([sys.executable, SCRIPT, "--machine", "rf-isotope-collector"],
                   capture_output=True, text=True, encoding="utf-8", cwd=os.path.dirname(HERE))
assert r.returncode == 0, r.stderr
assert "pair helium-3 x tritium" in r.stdout, r.stdout
assert "1 pair(s) measured, 0 untestable" in r.stdout, r.stdout
# Every figure carries its zoom, and nothing in the output is a verdict about the art.
assert "AT ZOOM 1 -- 32 px to the tile" in r.stdout, r.stdout
assert "Nothing above decides whether an accent reads." in r.stdout, r.stdout
# Its two tritium sockets draw the band its whole built span, so neither stops short; the north
# helium-3 one does. One line, not none and not three.
assert r.stdout.count("SHORT OF THE BAND'S BACK EDGE") == 1, r.stdout

# THE BAND IS FOLLOWED, NOT ASSUMED, AND THE HEAT EXCHANGER IS WHERE THAT MATTERS. Its west energy
# and south steam sockets have the machine's own body in front of the band from a few columns in,
# so a bench that took the built span on trust measured the body -- which is what the bench's first
# version did and the review of #379 caught. Four of its six sockets must report stopping short.
r = subprocess.run([sys.executable, SCRIPT, "--machine", "rf-heat-exchanger"],
                   capture_output=True, text=True, encoding="utf-8", cwd=os.path.dirname(HERE))
assert r.returncode == 0, r.stderr
short = [ln for ln in r.stdout.splitlines() if "SHORT OF THE BAND'S BACK EDGE" in ln]
assert len(short) == 4, f"{len(short)} socket(s) reported stopping short:\n" + r.stdout

# A machine that has no geometry file is a refusal that names it, not an empty report.
r = subprocess.run([sys.executable, SCRIPT, "--machine", "rf-reactor"],
                   capture_output=True, text=True, encoding="utf-8", cwd=os.path.dirname(HERE))
assert r.returncode != 0 and "rf-reactor" in r.stderr, (r.returncode, r.stderr)

print("measure-accent-separation: ok")

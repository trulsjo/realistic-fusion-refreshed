#!/usr/bin/env python3
"""The checks for measure-accent-separation.py that need no game, no Blender and no render:
`python tools/test_measure_accent_separation.py` exits 0 or raises.

Two pieces of arithmetic and one whole run. The arithmetic is the part that is silently wrong if it
is wrong -- a window off by one still returns a plausible colour, and a halving done in the wrong
space still returns a plausible colour -- so each is pinned against a case where the right answer
and the likely wrong one differ visibly. The whole run is here because the parts can all be right
while the tool reports nothing.

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
# A halved pixel covers two source pixels and belongs to the window only when BOTH are in it. Each
# case below is one an off-by-one would pass: dropping the "both" rule turns the second and third
# into (102, 107) and (102, 108), which is a column of the flange rib inside an accent band's
# window -- the leak tools/socket_strip.py's header records shipping two wrong rows.
assert mas.inside(204, 216) == (102, 107), mas.inside(204, 216)   # the collector's west band
assert mas.inside(205, 216) == (103, 107), mas.inside(205, 216)   # odd start: 102 holds 204 too
assert mas.inside(204, 215) == (102, 107), mas.inside(204, 215)   # 107 holds 214 and 215, both in
assert mas.inside(204, 214) == (102, 106), mas.inside(204, 214)   # 215 is out, so 107 is too
assert mas.inside(4, 5) == (2, 2), mas.inside(4, 5)               # exactly one whole pixel
assert mas.inside(5, 5) is None, mas.inside(5, 5)                 # one source pixel is never whole
assert mas.inside(5, 6) is None, mas.inside(5, 6)                 # two, but straddling the pair

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

# A machine that has no geometry file is a refusal that names it, not an empty report.
r = subprocess.run([sys.executable, SCRIPT, "--machine", "rf-reactor"],
                   capture_output=True, text=True, encoding="utf-8", cwd=os.path.dirname(HERE))
assert r.returncode != 0 and "rf-reactor" in r.stderr, (r.returncode, r.stderr)

print("measure-accent-separation: ok")

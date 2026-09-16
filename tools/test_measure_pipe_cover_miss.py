#!/usr/bin/env python3
"""The check for measure-pipe-cover-miss.py that needs no game and no render:
`python tools/test_measure_pipe_cover_miss.py` exits 0 or raises.

ONE PIECE OF ARITHMETIC, AND IT IS THE ONE THAT WAS WRONG. `box_of` bounds a connection's window on
both axes; the first version bounded only the rows, and rf-heat-exchanger's west and east energy
connections share a row fifteen tiles apart -- so one window caught both covers and reported a blob
506 px wide whose centroid sat between them. A figure that looks like a measurement and is the
average of two things is the worst way for a bench to fail, so the case is pinned with two blobs in
one row band and a window that must return only the near one.

The world-to-screen mapping this tool rests on is NOT pinned here: it is
tools/measure-frame-accents.py's `sheet_to_frame`, and tools/test_measure_frame_accents.py grades it
beside the module that owns it -- including the zoom-8 case this tool is the reason for. A second
copy of those assertions would be the mistake tools/socket_strip.py's header is about.

`cover_mask` is not pinned either. It is one subtraction against a floor, and what makes it right is
that the two frames come from runs differing in one declaration -- which is the probe's property,
not this file's.
"""
import importlib.util
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "measure-pipe-cover-miss.py")
spec = importlib.util.spec_from_file_location("measure_pipe_cover_miss", SCRIPT)
mpc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mpc)

# Two covers on one row, far apart on the screen, which is rf-heat-exchanger's west and east energy
# sockets as this bench actually meets them.
mask = np.zeros((64, 512), dtype=bool)
mask[30:40, 10:20] = True          # the west cover
mask[30:40, 480:490] = True        # the east one, 470 px away

near = mpc.box_of(mask, 20, 50, 0, 60)
assert near == (30, 39, 10, 19, 34.5, 14.5, 100), near
far = mpc.box_of(mask, 20, 50, 460, 511)
assert far == (30, 39, 480, 489, 34.5, 484.5, 100), far

# THE FAILURE THE COLUMN BOUND EXISTS FOR, stated as an assertion rather than as a comment: given the
# whole width, the two merge and the centroid lands halfway between them, on nothing at all.
both = mpc.box_of(mask, 20, 50, 0, 511)
assert both[2] == 10 and both[3] == 489, both
assert both[5] == 249.5, both[5]

# A window with nothing in it is None, not a zero-sized box -- the caller prints "NO COVER" for it,
# which is a finding (rf-heat-exchanger's north face) and not an absence of one.
assert mpc.box_of(mask, 0, 10, 0, 511) is None
assert mpc.box_of(mask, 20, 50, 100, 400) is None

# A window off the edge of the frame is clipped rather than raising: the probe centres a six-tile
# frame on a connection, and a connection near the edge of a whole-machine frame has less than a
# tile of room on one side.
assert mpc.box_of(mask, -50, 50, -50, 60) == near
assert mpc.box_of(mask, 20, 5000, 0, 60) == near
# And one entirely outside it is None rather than an exception.
assert mpc.box_of(mask, 200, 300, 0, 60) is None

# The two heights this tool prints for reference come from the model and the build script, so a
# change to either has to be a deliberate one. They are NOT what any measured figure rests on.
assert mpc.CONTAINED_Z == 0.55, mpc.CONTAINED_Z
assert abs(mpc.SCREEN_PER_WORLD - 0.70804) < 1e-5, mpc.SCREEN_PER_WORLD

print("measure-pipe-cover-miss: ok")

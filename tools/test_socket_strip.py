"""The one check for tools/socket_strip.py: `python tools/test_socket_strip.py` exits 0 or raises.

No framework and no sheet. What is checked here is the arithmetic nothing else can check -- which
columns a span along the tube turns into, and the two readings the module refuses -- on a manifest
made up for the purpose, so a wrong sign or an off-by-one shows up as an assertion rather than as a
number in a table someone later has to disbelieve.

WHY A MIRRORED PAIR. A socket points either way along the screen, and `columns_of` has to walk
inboard from the footprint edge in whichever direction that is. The same span measured on a west
connection and on an east one must give mirror-image windows about the sheet's centre; a sign error
gives a window off the sheet or one that walks out over the machine's own body, and either would
still print a plausible-looking row.
"""
import importlib.util
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("socket_strip", os.path.join(HERE, "socket_strip.py"))
strip = importlib.util.module_from_spec(spec)
sys.modules["socket_strip"] = strip
spec.loader.exec_module(strip)

PX = 64
SIDE = (5 + 2 * 3) * PX                       # a 5x5 machine with the standard 3-tile margin
MANIFEST = {
    "machine": "test",
    "directions": ["", "-e"],
    "frame": {"tiles": [5, 5], "pixels_per_tile": PX, "margin_tiles": 3.0},
    "geometry": {
        "name": "rf-test",
        "collision_box": [[-2.25, -2.25], [2.25, 2.25]],
        "selection_box": [[-2.5, -2.5], [2.5, 2.5]],
        "connections": [],
    },
}
WEST = {"direction": "west", "fluid": "water", "position": [-2, 0], "connection_category": None}
EAST = {"direction": "east", "fluid": "water", "position": [2, 0], "connection_category": None}


def sheet(top=None, rows=0):
    """A blank sheet, optionally with `rows` opaque rows from `top` across its whole width."""
    a = np.zeros((SIDE, SIDE), dtype=np.uint8)
    if top is not None:
        a[top:top + rows, :] = 255
    return a


west = strip.strip(sheet(), MANIFEST, WEST)
east = strip.strip(sheet(), MANIFEST, EAST)

# The mouth is the selection edge and the body the collision edge, a quarter tile apart, and the
# socket runs inboard from the mouth: left to right on the west connection, right to left on the
# east one.
assert (west.mouth_col, west.body_col, west.outward) == (192.0, 208.0, -1), vars(west)
assert (east.mouth_col, east.body_col, east.outward) == (512.0, 496.0, 1), vars(east)

# A span from the mouth to the collision edge, on both. Each boundary is pulled in by the filter's
# half width, so the first whole column starts at 192.75 and the last ends by 207.25.
assert west.columns_of(0.0, 0.25) == (193, 206), west.columns_of(0.0, 0.25)
assert east.columns_of(0.0, 0.25) == (497, 510), east.columns_of(0.0, 0.25)
# ... and those are mirror images about the sheet's centre column. `SIDE - 1 - c` is the mirror of
# column c, so the pair reverses as well as reflects.
lo, hi = west.columns_of(0.0, 0.25)
assert east.columns_of(0.0, 0.25) == (SIDE - 1 - hi, SIDE - 1 - lo)

# A span too narrow to hold a whole column once its boundaries are pulled in has NO window, which is
# the honest answer and not an empty one: on the shipped sheets the bare tube between a socket's two
# flange ribs is exactly this case.
assert west.columns_of(0.10, 0.12) is None
assert east.columns_of(0.10, 0.12) is None

# A window may not reach past the collision edge into the machine's own body.
assert west.reach() == (0, 206), west.reach()
assert east.reach() == (497, SIDE - 1), east.reach()

# What is drawn is read by row EDGES: the first drawn row's top edge and the last one's bottom.
drawn = strip.strip(sheet(top=340, rows=10), MANIFEST, WEST)
assert drawn.extent(200, 205) == (340, 350), drawn.extent(200, 205)

# And the axis of a socket built at world height z sits SCREEN_PER_WORLD * z tiles above the ground
# line, which on this manifest is the sheet's own centre row.
assert abs(drawn.axis_row(0.0) - SIDE / 2) < 1e-9
assert abs(drawn.axis_row(1.0) - (SIDE / 2 - strip.SCREEN_PER_WORLD * PX)) < 1e-9


def refuses(why, call):
    try:
        call()
    except strip.Unmeasurable as raised:
        assert why in str(raised), f"expected '{why}' in: {raised}"
        return
    raise AssertionError(f"expected Unmeasurable about '{why}'")


# THE TWO READINGS IT MUST REFUSE. Nothing drawn is not a zero; and a silhouette touching the edge
# of the row window is cut off rather than measured, so its extent is not its extent.
refuses("nothing is drawn", lambda: strip.strip(sheet(), MANIFEST, WEST).extent(200, 205))
refuses("reaches the edge of the search window",
        lambda: strip.strip(sheet(top=0, rows=SIDE), MANIFEST, WEST).extent(200, 205))
# And a window reaching over the body is refused rather than measured, whichever way the socket runs.
refuses("reach outside", lambda: drawn.extent(200, 210))
refuses("reach outside", lambda: strip.strip(sheet(), MANIFEST, EAST).extent(490, 500))

print("socket_strip: ok")

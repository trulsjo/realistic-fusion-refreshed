"""The one check for the render's arithmetic that runs without Blender: `python models/test_rf_blender.py`
exits 0 or raises. What needs Blender -- that the camera really lands a tile on 64 px, that two
renders give the same bytes -- was measured by hand for #249 on the calibration cube and is recorded
in its resolution; this only pins the numbers the sheets are declared from."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rf_blender as rf  # noqa: E402  (no bpy at module level)

# The pixel aspect squares the ground: one tile of depth foreshortened by sin(pitch) and stretched
# by 1/sin(pitch) is one tile again, so a tile is 64 px on both axes in the finished sheet.
assert abs(math.sin(math.radians(rf.CAMERA_PITCH_DEG)) * rf.STRETCH - 1.0) < 1e-12

# A vertical then shows at h / tan(pitch): the 0.707 proportion Truls chose in #246.
assert abs(1 / math.tan(math.radians(rf.CAMERA_PITCH_DEG)) - 0.707) < 0.002

# The frame is the footprint plus the margin on every side; symmetric, so shift stays zero and the
# east sheet is the north sheet's size transposed. Whole pixels, never a fraction of one.
assert rf.frame_px(5, 15) == (704, 1344)
assert rf.frame_px(15, 5) == (1344, 704)
assert rf.frame_px(1, 1, margin=2) == (320, 320)
assert rf.frame_px(15, 15)[0] <= 8192, "a sheet wider than the engine's 8192 px limit (#241)"

# The heat exchanger's tallest point is a relief valve cap, 3.76 tiles up at x = 0.98 (build.py);
# its shadow at the sun's elevation reaches this far past the east footprint edge at x = 2.5, and
# the margin must hold it (the research's open point 6). Measured on the render for #249: 2.83.
shadow_reach = 0.98 + 3.76 / math.tan(math.radians(rf.SUN_ELEVATION_DEG)) - 2.5
assert 2.5 < shadow_reach < rf.MARGIN_TILES, (shadow_reach, rf.MARGIN_TILES)

# Every fluid a mockup machine carries has an accent; an unknown one refuses rather than guesses.
for fluid, want in (("rf-reactor-energy", "energy"), ("rf-aneutronic-reactor-energy", "energy"),
                    ("steam", "steam"), ("water", "water"), ("rf-d-t-plasma", "plasma"),
                    ("rf-tritium", "tritium"), ("rf-helium-3", "helium-3")):
    assert rf.accent(fluid) == want, fluid
try:
    rf.accent("lubricant")
except SystemExit:
    pass
else:
    raise AssertionError("accent() guessed for an unknown fluid")

# ---- the detail floors (#335, #338) ---------------------------------------------------------
#
# The floors are stated in pixels on the player's screen, which is the sheet at scale 0.5.
assert abs(rf.CUT_DETAIL_FLOOR * rf.PX_PER_TILE * 0.5 - 1.6) < 1e-9
assert abs(rf.RAISED_DETAIL_FLOOR * rf.PX_PER_TILE * 0.5 - 1.92) < 1e-9
assert rf.CUT_DETAIL_FLOOR < rf.RAISED_DETAIL_FLOOR, "a cut feature reads thinner than a raised one"

# A feature AT its floor passes -- both floors are set at what two machines already ship, so a
# rule that rejected the boundary would reject the work it was measured from.
assert rf.check_detail("groove", rf.CUT_DETAIL_FLOOR, cut=True) == rf.CUT_DETAIL_FLOOR
assert rf.check_detail("rivet", rf.RAISED_DETAIL_FLOOR) == rf.RAISED_DETAIL_FLOOR


def refuses(*args, **kwargs):
    try:
        rf.check_detail(*args, **kwargs)
    except SystemExit:
        return True
    return False


assert refuses("groove", rf.CUT_DETAIL_FLOOR - 0.001, cut=True)
assert refuses("rivet", rf.RAISED_DETAIL_FLOOR - 0.001)

# THE TWO FLOORS ARE NOT INTERCHANGEABLE: a 0.05 feature is a legal groove and an illegal rivet.
# That is the whole point of splitting them, so it is pinned rather than left to the numbers.
assert not refuses("groove", 0.05, cut=True)
assert refuses("rivet", 0.05)

# The read dimension, on the two primitives where getting it wrong is silent. A torus is judged on
# its minor DIAMETER: the drum rib bands are minor radius 0.035, which passes at 0.07 and fails at
# 0.035. An H-beam is judged on its FLANGE WIDTH, 0.14, not on its 0.03 web -- the web is edge-on
# at this camera and a floor read off it condemns the frame the house style is built around.
# 0.14 is the isotope collector's deck post, which passes its own section; rf_parts.hbeam
# defaults to 0.16 and the assertion holds either way.
assert not refuses("drum rib band (minor diameter)", 2 * 0.035)
assert refuses("drum rib band (minor radius, the wrong read)", 0.035)
assert not refuses("H-beam post (flange width)", 0.14)
assert refuses("H-beam post (web thickness, the wrong read)", 0.03)

# rf_parts.box and rf_parts.cyl take a `read=` for a member whose FACE carries the read -- a panel
# standing proud of a wall, a handwheel disc square to the camera. It is not an opt-out: whatever
# dimension is handed over is still judged, so a face genuinely under the floor still fails.
assert not refuses("handwheel disc, judged across its face", 0.56)
assert refuses("a face that really is too small", 0.04)

# ---- the footprint edge (#800) --------------------------------------------------------------
#
# Nothing pipe-shaped meets a footprint edge except at a declared socket. Held against the heat
# exchanger's real geometry: 15 by 5, collision edge 7.25 east, selection and footprint 7.5, and
# east connections on Factorio tiles (7, -1) and (7, 1) only. Points are Blender's frame, so
# Factorio's y is negated: tile (7, -1) is Blender y = +1.
import json  # noqa: E402

_geo = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "heat-exchanger",
                                   "geometry.json"), encoding="utf-8"))


def edge_refusal(points, radius=0.1):
    """The message check_edge exits with, or None when it passes."""
    try:
        rf.check_edge("Planted", points, radius, _geo)
    except SystemExit as e:
        return str(e)
    return None


# A run planted heading out of the east edge on tile (7, 0), where nothing is declared, is refused,
# and the message names the part and the tile -- the tile in Factorio's coordinates, the ones
# geometry.json and a player's map both use.
_planted = edge_refusal([(5.0, 0.0, 0.5), (7.45, 0.0, 0.5)])
assert _planted is not None, "a run out of an undeclared edge tile passed"
assert "Planted" in _planted and "(7, 0)" in _planted and "east" in _planted, _planted

# The same run on tile (7, -1), where the exchanger declares its east energy connection, passes:
# that is what a socket is. Blender y = +1 is Factorio y = -1.
assert edge_refusal([(5.0, 1.0, 0.5), (7.45, 1.0, 0.5)]) is None

# A corner run leaving north from the east corner is refused on the north edge's tile (7, -2).
assert "(7, -2)" in (edge_refusal([(6.0, 1.0, 0.5), (7.0, 2.45, 0.5)]) or "")

# A declared connection on one edge does not license another. The exchanger has no corner
# connection, so one is added to a copy: east on corner tile (7, -2). Leaving east there passes;
# leaving north from the same tile is still refused, on the north edge.
_corner = dict(_geo, connections=_geo["connections"] + [{"direction": "east", "position": [7, -2]}])


def corner_refusal(points):
    try:
        rf.check_edge("Planted", points, 0.1, _corner)
    except SystemExit as e:
        return str(e)
    return None


assert corner_refusal([(5.0, 2.0, 0.5), (7.45, 2.0, 0.5)]) is None
assert "north" in (corner_refusal([(7.0, 1.0, 0.5), (7.0, 2.45, 0.5)]) or "")

# Running ALONG an edge passes: the whole north edge, corner to corner just inside it, ends
# pointing east and west at x = +-6, short of the east and west edges.
assert edge_refusal([(-6.0, 2.4, 0.5), (6.0, 2.4, 0.5)]) is None

# A run that reaches the edge and turns down into the floor ends pointing down, not out. Neither
# rendered machine's floor drop reaches the edge today -- both pass on reach alone -- so this case
# is the only thing that exercises the allowance.
assert edge_refusal([(5.0, 0.0, 0.5), (7.4, 0.0, 0.5), (7.4, 0.0, 0.0)]) is None

# Stopping inside the body passes: the reach, end plus radius, is short of the collision edge.
assert edge_refusal([(5.0, 0.0, 0.5), (7.1, 0.0, 0.5)], radius=0.1) is None
# ... and the radius counts: the same end with a fat tube stands out of the body face.
assert edge_refusal([(5.0, 0.0, 0.5), (7.1, 0.0, 0.5)], radius=0.2) is not None

# Stacked control points, which the house style asks for so a run meets a surface square, do not
# hide the direction: the last segment of non-zero length is the one read.
assert edge_refusal([(5.0, 0.0, 0.5), (7.45, 0.0, 0.5), (7.45, 0.0, 0.5)]) is not None

# Both ends are read, so a run cannot leave by its first point instead.
assert edge_refusal([(7.45, 0.0, 0.5), (5.0, 0.0, 0.5)]) is not None

# West and south, where the signs flip: tile (-7, 0) declares nothing west, and tile (1, 2) on the
# south edge declares nothing (the steam output is (0, 2)), while (0, 2) passes.
assert "(-7, 0)" in (edge_refusal([(-5.0, 0.0, 0.5), (-7.45, 0.0, 0.5)]) or "")
assert "(1, 2)" in (edge_refusal([(1.0, 0.0, 0.5), (1.0, -2.45, 0.5)]) or "")
assert edge_refusal([(0.0, 0.0, 0.5), (0.0, -2.45, 0.5)]) is None

print("ok")

# The geometry hash is over canonical JSON, so a CRLF checkout of the same file hashes the same
# and render.py does not refuse a model whose geometry has not moved (#251).
import tempfile
_src = os.path.join(os.path.dirname(os.path.abspath(__file__)), "heat-exchanger", "geometry.json")
with tempfile.NamedTemporaryFile("wb", suffix=".json", delete=False) as _t:
    _t.write(open(_src, encoding="utf-8").read().replace("\n", "\r\n").encode())
try:
    assert rf.geometry_sha256(_src) == rf.geometry_sha256(_t.name)
finally:
    os.unlink(_t.name)

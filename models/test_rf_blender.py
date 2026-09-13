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

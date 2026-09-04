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
                    ("steam", "steam"), ("water", "water"), ("rf-d-t-plasma", "plasma")):
    assert rf.accent(fluid) == want, fluid
try:
    rf.accent("lubricant")
except SystemExit:
    pass
else:
    raise AssertionError("accent() guessed for an unknown fluid")

print("ok")

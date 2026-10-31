"""The one check for the render's arithmetic that runs without Blender: `python models/test_rf_blender.py`
exits 0 or raises. What needs Blender -- that the camera really lands a tile on 64 px, that two
renders give the same bytes -- was measured by hand for #249 on the calibration cube and is recorded
in its resolution; this only pins the numbers the sheets are declared from, the detail floors,
the footprint-edge check, since #803 the kit's arithmetic: where a kit part's pieces go and how
its floors are checked, and since #825 the named streams parts draw from and that no file here
but rf_blender.py imports the global `random`, which that one uses only for `random.Random`, and
since #827 that neither rendered machine's build script names a part that draws from a loop's
counter, and since #805 a texture's provenance record. It renders nothing, so it cannot see whether a part reads; it cannot
see what a build script draws from one stream or in what order, nor a draw from anything but
`random`, such as `mathutils.noise`."""
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

# ---- the kit: hoses and looms (#803) --------------------------------------------------------
#
# A loom is several cables laid round one centreline. `bundle` returns one strand per cable, each
# the same number of points as the centreline, every point `spread` off it and square to the run.
_line = [(0.0, 0.0, 1.0), (1.0, 0.0, 1.0), (2.0, 0.5, 1.2), (3.0, 0.5, 1.2)]
_strands = rf.bundle(_line, 3, 0.05)
assert len(_strands) == 3 and all(len(s) == len(_line) for s in _strands)
for _s in _strands:
    for _c, _p in zip(_line, _s):
        assert abs(math.dist(_c, _p) - 0.05) < 1e-9, (_c, _p)
# Square to the run: at a straight stretch, the offset has no component along it.
assert all(abs(s[0][0] - _line[0][0]) < 1e-9 for s in _strands)
# The strands are spread round the centre rather than stacked on one side: their mean is the centre.
for _k, _c in enumerate(_line):
    _mean = [sum(s[_k][j] for s in _strands) / 3 for j in range(3)]
    assert math.dist(_mean, _c) < 1e-9, (_mean, _c)
# A vertical stretch has no horizontal "side" to read off; it still spreads, and still square to it.
_up = rf.bundle([(0.0, 0.0, 0.0), (0.0, 0.0, 1.0)], 2, 0.05)
assert all(abs(s[0][2]) < 1e-9 for s in _up) and math.dist(_up[0][0], _up[1][0]) > 0.09
# Twist turns the bundle along the run, so the cables wind rather than lying parallel; the spread
# from the centre is kept.
_tw = rf.bundle(_line, 3, 0.05, twist=0.5)
assert math.dist(_tw[0][-1], _strands[0][-1]) > 0.01
assert all(abs(math.dist(c, p) - 0.05) < 1e-9 for s in _tw for c, p in zip(_line, s))
# A phase turns the whole bundle at its start, so two looms on the same curve wind differently:
# strand 0 starts where strand 1 of an unturned three-cable bundle does when turned by 2 pi / 3.
_ph = rf.bundle(_line, 3, 0.05, phase=2 * math.pi / 3)
assert all(math.dist(a, b) < 1e-9 for a, b in zip(_ph[0], _strands[1]))
# One cable is the centreline itself.
assert rf.bundle(_line, 1, 0.05) == [list(_line)]

# A loom's spread is the least that keeps neighbouring cables apart: chord between neighbours is
# twice the cable radius plus a gap.
assert abs(2 * rf.loom_spread(3, 0.035, gap=0.0) * math.sin(math.pi / 3) - 0.07) < 1e-9
assert rf.loom_spread(1, 0.035) == 0.0

# Every row is named for a cable, so none is an accent or the marking by name. How far the colours
# stand from the accents is measured in docs/research/density-figures.md, not here.
assert set(rf.CABLE_COLOURS) and all(k.startswith("cable-") for k in rf.CABLE_COLOURS)

# ---- the kit: inset panels (#802) -----------------------------------------------------------
#
# A face u by v is cut into nu by nv plates with a seam between neighbours and round the edge.
# Each cell is (centre u, centre v, size u, size v), in the face's own frame, centred on it.
_cells = rf.panel_grid(2.0, 1.0, 4, 2, 0.05)
assert len(_cells) == 8
assert all(abs(c[2] - (2.0 - 5 * 0.05) / 4) < 1e-9 and abs(c[3] - (1.0 - 3 * 0.05) / 2) < 1e-9
           for c in _cells)
# The plates and the seams fill the face exactly: the outermost plate's edge is one seam inside it.
assert abs(max(c[0] + c[2] / 2 for c in _cells) - (1.0 - 0.05)) < 1e-9
assert abs(min(c[1] - c[3] / 2 for c in _cells) - (-0.5 + 0.05)) < 1e-9
# Neighbours are one seam apart.
_us = sorted({round(c[0], 9) for c in _cells})
assert all(abs((b - a) - (_cells[0][2] + 0.05)) < 1e-9 for a, b in zip(_us, _us[1:]))


def inset_refusal(*args):
    try:
        rf.check_inset(*args)
    except SystemExit as e:
        return str(e)
    return None


# A seam is a cut detail, so it is held to the cut floor on its width, and it is cut at least as
# deep as it is wide (the house style's rule for any groove). Each of the three refusals names the
# part.
assert inset_refusal("Panels", 0.05, 0.05, 0.4) is None
assert "Panels" in (inset_refusal("Panels", 0.05, 0.04, 0.4) or "")
assert "Panels (seam)" in (inset_refusal("Panels", 0.04, 0.06, 0.4) or "")
# A plate reads by its face, so its smaller side is held to the raised floor.
assert "Panels (plate)" in (inset_refusal("Panels", 0.05, 0.05, 0.05) or "")

# ---- the kit: repeated modules (#804) -------------------------------------------------------
#
# Any module is placed as a ring, a row or a stack. Each placement is (location, rotation), the
# rotation being the Euler angles a part built about its own origin is turned by.
_ring = rf.ring((1.0, 2.0, 3.0), 0.5, 4)
assert len(_ring) == 4
assert all(abs(math.dist(loc, (1.0, 2.0, 3.0)) - 0.5) < 1e-9 for loc, _ in _ring)
# A ring's part faces outward: its turn about Z is the angle it stands at.
assert all(abs((math.atan2(loc[1] - 2.0, loc[0] - 1.0) - rot[2]) % (2 * math.pi)) < 1e-9
           for loc, rot in _ring)
assert abs(rf.ring((0, 0, 0), 1.0, 4, phase=0.3)[0][1][2] - 0.3) < 1e-9

# A row is spaced like a rivet line: n parts each in the middle of its own nth of the span.
_row = rf.row((0.0, 0.0, 0.0), (1.0, 0.0, 0.0), 4, rot=(0, 1.0, 0))
assert [round(loc[0], 9) for loc, _ in _row] == [0.125, 0.375, 0.625, 0.875]
assert all(rot == (0, 1.0, 0) for _, rot in _row)

# A stack climbs from its base by a pitch.
_stack = rf.stack((0.0, 0.0, 1.0), 3, 0.2)
assert [round(loc[2], 9) for loc, _ in _stack] == [1.0, 1.2, 1.4]


def gap_refusal(*args):
    try:
        rf.check_gap(*args)
    except SystemExit as e:
        return str(e)
    return None


# The slot between a casing's segments is cut through its shell, so it is held as a groove is: on
# the cut floor by its width, and at least as deep as it is wide. Both refusals name the part.
assert "Casing (gap)" in (gap_refusal("Casing", 0.04, 1.0) or "")
assert gap_refusal("Casing", 0.06, 1.0) is None
assert "Casing" in (gap_refusal("Casing", 0.05, 0.04) or "")

# The gap between neighbouring parts is measured from the parts as placed, whatever the arrangement:
# the least distance between the points of one and the points of the next. A unit cube's corners,
# placed in a row two apart, leave one; stacked one apart they touch.
_cube = [(x, y, z) for x in (-0.5, 0.5) for y in (-0.5, 0.5) for z in (-0.5, 0.5)]
assert abs(rf.least_gap(_cube, rf.row((0, 0, 0), (4, 0, 0), 2)) - 1.0) < 1e-9
assert abs(rf.least_gap(_cube, rf.stack((0, 0, 0), 3, 1.0))) < 1e-9
# A ring is closed: the last part is held against the first. Four points round a unit circle, the
# last a hair short of the first: open, the least gap would be sqrt 2; closed, it is that hair.
_dot = [(0.0, 0.0, 0.0)]
assert abs(rf.least_gap(_dot, [((1, 0, 0), (0, 0, 0)), ((0, 1, 0), (0, 0, 0)), ((-1, 0, 0), (0, 0, 0)),
                               ((0.9, 0.1, 0), (0, 0, 0))]) - math.dist((0.9, 0.1, 0), (1, 0, 0))) < 1e-9
assert rf.least_gap(_cube, rf.stack((0, 0, 0), 1, 1.0)) is None
# The rotation is applied: a bar 2 long along x, turned a quarter about z, lies along y, so two of
# them a row 3 apart along x leave 3 - 0.2 rather than 3 - 2.
_bar = [(x, y, 0) for x in (-1, 1) for y in (-0.1, 0.1)]
assert abs(rf.least_gap(_bar, rf.row((0, 0, 0), (6, 0, 0), 2, rot=(0, 0, math.pi / 2))) - 2.8) < 1e-9
# Blender's XYZ Euler order: turned a quarter about x then a quarter about z, local +z ends on +x.
_m = rf.euler_matrix((math.pi / 2, 0, math.pi / 2))
assert all(abs(a - b) < 1e-9 for a, b in zip(rf.turn(_m, (0, 0, 1)), (1, 0, 0)))

# A segmented casing of n segments round a radius leaves `gap` of arc between neighbours.
_arc = rf.casing_arc(8, 1.0, 0.05)
assert abs(8 * (_arc + 0.05 / 1.0) - 2 * math.pi) < 1e-9
# Placed round the ring it was cut for, the measured gap is that slot, give or take the chord: the
# inner corners of neighbours stand 2 r sin(gap / 2r) apart.
_seg = rf.casing_points(1.0, _arc, 0.34, 0.07)
_slot = rf.least_gap(_seg, rf.ring((0, 0, 0), 1.0, 8))
assert abs(_slot - 2 * math.sin(0.05 / 2)) < 1e-9, _slot
# Up a stack 0.4 apart, segments 0.34 tall leave 0.06 between bands.
assert abs(rf.least_gap(_seg, rf.stack((0, 0, 0), 2, 0.4)) - 0.06) < 1e-9

# ---- the inline valve (#833) ----
#
# A valve sits on a run at a point the caller gives, along the run's direction there, and its
# handwheel stands off the run along a facing the caller gives, made square to the run.


def _close(a, b):
    return all(abs(x - y) < 1e-9 for x, y in zip(a, b))


def valve_refusal(*args):
    try:
        rf.valve_layout(*args)
    except SystemExit as e:
        return str(e)
    return None


_v = rf.valve_layout("V", (1.0, 2.0, 3.0), (2.0, 0.0, 0.0), 0.19, (0.3, 0.0, 1.0))
# The facing loses its component along the run, so the wheel's axis is square to the run.
assert _close(_v["facing"], (0, 0, 1)), _v["facing"]
# The body is on the run, along it, and wider than it.
assert _close(_v["body"]["centre"], (1, 2, 3)) and _close(_v["body"]["axis"], (1, 0, 0))
assert _v["body"]["radius"] > 0.19
# A flange either side of the body, the same distance off, along the run, wider than the body.
(_fa, _fb) = (f["centre"] for f in _v["flanges"])
assert abs(_fa[1] - 2) + abs(_fa[2] - 3) + abs(_fb[1] - 2) + abs(_fb[2] - 3) < 1e-9
assert abs((_fa[0] - 1) + (_fb[0] - 1)) < 1e-9 and abs(_fa[0] - _fb[0]) > _v["body"]["length"]
assert all(f["radius"] > _v["body"]["radius"] for f in _v["flanges"])
# The bonnet, the stem and the wheel stand in that order out along the facing, each past the last,
# and the wheel's plane is square to it, clear of the body.
_out = [(p["centre"][2] - 3) for p in (_v["bonnet"], _v["stem"], _v["wheel"])]
assert _out == sorted(_out) and all(_close(p["centre"][:2], (1, 2)) for p in (_v["bonnet"], _v["stem"], _v["wheel"]))
assert _close(_v["wheel"]["normal"], (0, 0, 1))
assert _out[2] - _v["wheel"]["minor"] > _v["body"]["radius"]
# `reach` is how far the valve stands out along its facing, the far face of the wheel's hub, which
# stands past the rim, and `span` how far the wheel reaches across it, for a caller to keep the
# valve clear of what is near.
assert _close(_v["hub"]["centre"], _v["wheel"]["centre"])
assert abs(_v["reach"] - (_out[2] + _v["hub"]["length"] / 2)) < 1e-9
assert _v["hub"]["length"] / 2 > _v["wheel"]["minor"]
assert abs(_v["span"] - (_v["wheel"]["major"] + _v["wheel"]["minor"])) < 1e-9
# A facing along the run has no square part and is refused, naming the part.
assert "V" in (valve_refusal("V", (0, 0, 0), (1, 0, 0), 0.19, (2, 0, 0)) or "")
# The handwheel's rim and the stem scale with the run but are never drawn under the raised floor
# (Truls, 2026-10-30, while #833 was implemented): on the water header's 0.13 the valve is not
# refused, and its rim and stem stand at the floor while the body is the run's proportion. On the
# steam header's 0.19 the rim is its own proportion, over the floor. The stem leaves its proportion
# at a thinner run than the rim does: at 0.16 the rim is floored and the stem is not.
_t = rf.valve_layout("V", (0, 0, 0), (1, 0, 0), 0.13, (0, 0, 1))
assert abs(2 * _t["wheel"]["minor"] - rf.RAISED_DETAIL_FLOOR) < 1e-9
assert abs(2 * _t["stem"]["radius"] - rf.RAISED_DETAIL_FLOOR) < 1e-9
assert abs(_t["body"]["radius"] - rf.VALVE_BODY[0] * 0.13) < 1e-9
assert abs(_v["wheel"]["minor"] - rf.VALVE_WHEEL[1] * 0.19) < 1e-9
assert 2 * _v["wheel"]["minor"] > rf.RAISED_DETAIL_FLOOR
_m = rf.valve_layout("V", (0, 0, 0), (1, 0, 0), 0.16, (0, 0, 1))
assert abs(2 * _m["wheel"]["minor"] - rf.RAISED_DETAIL_FLOOR) < 1e-9
assert abs(_m["stem"]["radius"] - rf.VALVE_STEM[0] * 0.16) < 1e-9
# A facing within about 11.5 degrees of the run is refused as facing along it.
assert "V" in (valve_refusal("V", (0, 0, 0), (1, 0, 0), 0.19, (1, 0, 0.15)) or "")
assert valve_refusal("V", (0, 0, 0), (1, 0, 0), 0.19, (1, 0, 0.3)) is None

# ---- the cable tray (#834) ----
#
# A ladder tray runs straight between the points it is given: two side rails with rungs between
# them and a bracket under it at each point. The points are its bed, the rungs' top face, where a
# loom lies.


def tray_refusal(*args, **kwargs):
    try:
        rf.tray_layout(*args, **kwargs)
    except SystemExit as e:
        return str(e)
    return None


_tr = rf.tray_layout("T", [(0.0, 0.0, 1.0), (2.0, 0.0, 1.0)], 0.2)
_rt, _rh = rf.TRAY_RAIL_T, rf.TRAY_RAIL_H * 0.2
_bt = rf.TRAY_RUNG[1]
# Each rail is a section at each point, inner bottom, outer bottom, outer top, inner top: the rails
# stand either side of the bed from the rungs' underside up, square to the run.
for _side, _rail in zip((-1, 1), _tr["rails"]):
    assert len(_rail) == 2
    for _p, _sec in zip(((0, 0, 1), (2, 0, 1)), _rail):
        _want = [(_p[0], _side * 0.1, 1 - _bt), (_p[0], _side * (0.1 + _rt), 1 - _bt),
                 (_p[0], _side * (0.1 + _rt), 1 - _bt + _rh), (_p[0], _side * 0.1, 1 - _bt + _rh)]
        assert all(_close(a, b) for a, b in zip(_sec, _want)), (_sec, _want)
# The rungs at the default pitch, the tray's width, are each in the middle of their own share of the
# length, as a row is spaced, under the bed and across the run from one rail's outer face to the
# other's.
assert [round(r["centre"][0], 9) for r in _tr["rungs"]] == [round(0.1 + 0.2 * k, 9) for k in range(10)]
assert all(_close(r["centre"][1:], (0, 1 - _bt / 2)) for r in _tr["rungs"])
assert all(_close(r["across"], (0, 1, 0)) and _close(r["along"], (1, 0, 0)) for r in _tr["rungs"])
assert all(abs(r["size"][1] - (0.2 + 2 * _rt)) < 1e-9 for r in _tr["rungs"])
# The read: the gap between rungs, here the pitch less a rung's width, and the rail's height.
assert abs(_tr["gap"] - (0.2 - rf.TRAY_RUNG[0])) < 1e-9 and abs(_tr["rail_h"] - _rh) < 1e-9
# A bracket under the rungs at each point, the end ones moved in so they stop at the tray's ends.
_bw = rf.TRAY_BRACKET[0]
assert [round(b["centre"][0], 9) for b in _tr["brackets"]] == [_bw / 2, 2 - _bw / 2]
assert all(abs(b["centre"][2] - (1 - _bt - rf.TRAY_BRACKET[1] / 2)) < 1e-9 for b in _tr["brackets"])
# What the footprint-edge check reads: the bed's points, with the tray's half-width to the outer face.
assert _tr["run"] == ([(0.0, 0.0, 1.0), (2.0, 0.0, 1.0)], 0.1 + _rt)
# A bend is mitred: at a quarter turn the rail's inner face meets itself on the bisector, half the
# width out times the square root of two.
_bend = rf.tray_layout("T", [(0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (1.0, 1.0, 0.0)], 0.2)
_corner = _bend["rails"][1][1][0]
assert _close(_corner, (0.9, 0.1, -_bt)), _corner
# The rungs restart on each straight length, so no rung stands across the bend.
assert len(_bend["rungs"]) == 10 and all(r["centre"][0] < 1 - 0.05 or r["centre"][1] > 0.05
                                         for r in _bend["rungs"])
# Rungs closer than the cut floor apart are refused, naming the part, and so is a rail under the
# raised floor, which a tray too narrow for its proportion has.
assert "T" in (tray_refusal("T", [(0, 0, 0), (1, 0, 0)], 0.2, rung_pitch=0.1) or "")
assert tray_refusal("T", [(0, 0, 0), (1, 0, 0)], 0.2, rung_pitch=0.12) is None
assert "rail" in (tray_refusal("T", [(0, 0, 0), (1, 0, 0)], 0.14) or "")
# A length straight up has no side for its rails, and is refused; a sloped one is laid.
assert "T" in (tray_refusal("T", [(0, 0, 0), (0, 0, 1)], 0.2) or "")
assert tray_refusal("T", [(0, 0, 0), (1, 0, 1)], 0.2) is None
# A loom lies in the tray on its bed, its half-width up, and one wider than the tray is refused.
assert _close(rf.tray_lie(_tr, 0.08)[1], (2.0, 0.0, 1.08 + rf.TRAY_CLEAR))
try:
    rf.tray_lie(_tr, 0.11)
    _wide = None
except SystemExit as e:
    _wide = str(e)
assert _wide is not None and "T" in _wide and "wider" in _wide, _wide
# A tray that points out of an undeclared east tile is refused by the edge check on its own run, and
# one along the north edge passes on its direction: at y = 2.2 its outer face, 0.125 off, stands
# past the collision edge at 2.25, so it is not passing on reach.
_out_t = rf.tray_layout("T", [(5.0, 0.0, 1.0), (7.3, 0.0, 1.0)], 0.2)
assert "(7, 0)" in (edge_refusal(*_out_t["run"]) or "")
_along = rf.tray_layout("T", [(-6.0, 2.2, 1.0), (6.0, 2.2, 1.0)], 0.2)
assert _along["run"][0][0][1] + _along["run"][1] > 2.25
assert edge_refusal(*_along["run"]) is None

# ---- the grating deck (#835) ----
#
# A deck over a rectangle, its top face at z: bars at a pitch with the edge bars flush to the edge,
# cut round each opening, a toe board on each open edge and a marking on each walkway edge.


def deck_refusal(*args, **kwargs):
    try:
        rf.deck_layout(*args, **kwargs)
    except SystemExit as e:
        return str(e)
    return None


def _spans(pieces, k):
    return sorted((round(p["centre"][k] - p["size"][k] / 2, 9), round(p["centre"][k] + p["size"][k] / 2, 9))
                  for p in pieces)


_dk = rf.deck_layout("D", (0.0, 0.0), (2.0, 1.0), 1.0, pitch=0.25)
_bw, _bd = rf.DECK_BAR
# Bars along X, the edge ones flush to the edge, the rest shared out between them nearest the
# pitch: five here, 0.235 apart, each the deck's length, under the top face.
assert [round(b["centre"][1], 9) for b in _dk["bars"]] == [-0.47, -0.235, 0.0, 0.235, 0.47]
assert all(_close(b["size"], (2.0, _bw, _bd)) and abs(b["centre"][2] - (1 - _bd / 2)) < 1e-9 for b in _dk["bars"])
assert not any(b["marked"] for b in _dk["bars"]) and _dk["toe_boards"] == []
# The read: the gap between bars and the bar's width.
assert abs(_dk["gap"] - (0.235 - _bw)) < 1e-9
# A walkway edge along the bars marks its edge bar; one across them adds a nosing bar there.
_mk = rf.deck_layout("D", (0.0, 0.0), (2.0, 1.0), 1.0, pitch=0.25, marked_edges=("-Y", "+X"))
assert [b["marked"] for b in _mk["bars"]][:5] == [True, False, False, False, False]
_nose = [b for b in _mk["bars"] if b["marked"] and b["size"][1] > _bw]
assert len(_nose) == 1 and _close(_nose[0]["centre"], (1 - _bw / 2, 0, 1 - _bd / 2)), _nose
assert _close(_nose[0]["size"], (_bw, 1.0, _bd))
# ... and the bars stop at its inner face, so they meet it end to end instead of lying in it.
assert all(abs(b["centre"][0] + b["size"][0] / 2 - (1 - _bw)) < 1e-9 for b in _mk["bars"] if b is not _nose[0])
# A toe board stands on each open edge, on the top face, flush to the edge.
_tb, _tt = rf.DECK_TOE
_toe = rf.deck_layout("D", (0.0, 0.0), (2.0, 1.0), 1.0, pitch=0.25, open_edges=("+X", "-Y"))["toe_boards"]
assert sorted((round(t["centre"][0], 9), round(t["centre"][1], 9)) for t in _toe) == \
    sorted([(round(1 - _tt / 2, 9), 0.0), (0.0, round(-0.5 + _tt / 2, 9))])
assert all(abs(t["centre"][2] - (1 + _tb / 2)) < 1e-9 for t in _toe)
# A toe board on a walkway edge is marked with it, and one on an edge that is only open is not.
_mt = rf.deck_layout("D", (0.0, 0.0), (2.0, 1.0), 1.0, pitch=0.25, open_edges=("+X", "-Y"),
                     marked_edges=("-Y",))["toe_boards"]
assert sorted((round(t["centre"][1], 9), t["marked"]) for t in _mt) == [(round(-0.5 + _tt / 2, 9), True), (0.0, False)]
# An opening cuts every bar it crosses, and only those, and a toe board it crosses.
_op = rf.deck_layout("D", (0.0, 0.0), (2.0, 1.0), 1.0, pitch=0.25, open_edges=("+X",),
                     openings=[((0.5, 0.0), (0.4, 0.3))])
assert _spans([b for b in _op["bars"] if abs(b["centre"][1]) < 1e-9], 0) == [(-1.0, 0.3), (0.7, 1.0)]
assert len(_op["bars"]) == 6 and len(_op["toe_boards"]) == 1
_edge = rf.deck_layout("D", (0.0, 0.0), (2.0, 1.0), 1.0, pitch=0.25, open_edges=("+X",),
                       openings=[((0.9, 0.0), (0.4, 0.3))])
assert _spans(_edge["toe_boards"], 1) == [(-0.5, -0.15), (0.15, 0.5)]
assert _spans([b for b in _edge["bars"] if abs(b["centre"][1]) < 1e-9], 0) == [(-1.0, 0.7)]
# A piece of a cut bar shorter than the bar is wide is left out rather than drawn as a stub.
_stub = rf.deck_layout("D", (0.0, 0.0), (2.0, 1.0), 1.0, pitch=0.25, openings=[((0.48, 0.0), (1.0, 0.3))])
assert _spans([b for b in _stub["bars"] if abs(b["centre"][1]) < 1e-9], 0) == [(-1.0, -0.02)]
# Bars along Y swap the two axes, and the centre moves the whole deck.
_dy = rf.deck_layout("D", (5.0, 7.0), (1.0, 2.0), 1.0, pitch=0.25, along="Y")
assert [round(b["centre"][0], 9) for b in _dy["bars"]] == [4.53, 4.765, 5.0, 5.235, 5.47]
assert all(abs(b["centre"][1] - 7.0) < 1e-9 and _close(b["size"], (_bw, 2.0, _bd)) for b in _dy["bars"])
# Bars closer than the cut floor apart are refused, naming the part, and so is a bar under the
# raised floor.
assert "D" in (deck_refusal("D", (0, 0), (2.0, 1.0), 1.0, pitch=0.1) or "")
assert deck_refusal("D", (0, 0), (2.0, 1.0), 1.0, pitch=0.12) is None
assert "bar" in (deck_refusal("D", (0, 0), (2.0, 1.0), 1.0, pitch=0.25, bar=(0.05, 0.06)) or "")
assert "D" in (deck_refusal("D", (0, 0), (2.0, 1.0), 1.0, open_edges=("+Z",)) or "")
assert "D" in (deck_refusal("D", (0, 0), (2.0, 1.0), 1.0, along="Z") or "")

# ---- the access ladder (#836) ----
#
# An access ladder straight up from a foot to a top height, facing out from what it stands against: two
# stiles, rungs at a pitch, and above a height a cage of hoops and bars on the side it faces.


def ladder_refusal(*args, **kwargs):
    try:
        rf.ladder_layout(*args, **kwargs)
    except SystemExit as e:
        return str(e)
    return None


_ld = rf.ladder_layout("L", (1.0, 2.0, 0.5), 2.0, (2.0, 0.0, 0.7), pitch=0.25, cage_from=0.7)
_hw = rf.LADDER_WIDTH / 2
# The facing loses its rise, and the side is square to it, level: here it faces east, so
# its stiles stand north and south of the foot, from the foot up to the top.
assert _close(_ld["facing"], (1, 0, 0)) and _close(_ld["side"], (0, 1, 0))
assert sorted(round(s["centre"][1], 9) for s in _ld["stiles"]) == [round(2 - _hw, 9), round(2 + _hw, 9)]
assert all(abs(s["centre"][2] - 1.25) < 1e-9 and abs(s["height"] - 1.5) < 1e-9 for s in _ld["stiles"])
# A rung each pitch above the foot, up to the top and no further, from stile to stile.
assert [round(r["centre"][2], 9) for r in _ld["rungs"]] == [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
assert all(_close(r["centre"][:2], (1.0, 2.0)) and abs(r["length"] - rf.LADDER_WIDTH) < 1e-9 for r in _ld["rungs"])
# The read: the gap between rungs, the pitch less a rung's thickness.
assert abs(_ld["gap"] - (0.25 - rf.LADDER_RUNG)) < 1e-9
# The cage: a hoop midway between two rungs, the first such height at or over where the cage
# starts, `cage_from` over the foot, and then every LADDER_CAGE_EVERY rungs up to the top, so no
# hoop stands on a rung. Each hoop runs from one stile, out round the facing side, to the other, so
# its ends are the stiles and its middle the far point. Here: midway heights 0.625 + 0.25k; the
# first at or over 0.5 + 0.7 is 1.375.
_cr = rf.LADDER_CAGE[0]
assert [round(h[0][2], 9) for h in _ld["hoops"]] == [1.375, 1.875]
assert rf.LADDER_CAGE_EVERY == 2
_h = _ld["hoops"][0]
assert _close(_h[0], (1.0, 2 - _hw, 1.375)) and _close(_h[-1], (1.0, 2 + _hw, 1.375)), (_h[0], _h[-1])
_far = max(_h, key=lambda p: p[0])
assert abs(_far[0] - (1.0 + math.sqrt(_cr ** 2 - _hw ** 2) + _cr)) < 1e-3 and abs(_far[1] - 2.0) < 1e-3
# The cage's bars run from its first hoop to its last, on the hoop, so none ends past a hoop.
assert _ld["bars"] and all(abs(b[0][2] - 1.375) < 1e-9 and abs(b[1][2] - 1.875) < 1e-9 for b in _ld["bars"])
assert all(abs(math.dist(b[0][:2], (1.0 + math.sqrt(_cr ** 2 - _hw ** 2), 2.0)) - _cr) < 1e-9 for b in _ld["bars"])
# No cage when it would start above the top; and by default it starts LADDER_CAGE_FROM up.
assert rf.ladder_layout("L", (0, 0, 0.5), 1.5, (1, 0, 0), cage_from=1.5)["hoops"] == []
_first = rf.ladder_layout("L", (0, 0, 0), 3.0, (1, 0, 0))["hoops"][0][0][2]
assert rf.LADDER_CAGE_FROM <= _first < rf.LADDER_CAGE_FROM + rf.LADDER_PITCH
assert abs((_first / rf.LADDER_PITCH) % 1 - 0.5) < 1e-9
# A cage with a single hoop has no bars, since a bar runs between two.
assert rf.ladder_layout("L", (0, 0, 0), 1.2, (1, 0, 0))["bars"] == []
# No brackets unless it stands off something; given a standoff, a bracket runs from each stile back
# against the facing by that much, the first midway between the foot and the first rung, then every
# LADDER_BRACKET_EVERY rungs, midway between two.
assert _ld["brackets"] == []
_br = rf.ladder_layout("L", (1.0, 2.0, 0.5), 2.0, (1, 0, 0), standoff=0.25)["brackets"]
assert rf.LADDER_BRACKET_EVERY == 4
assert sorted({round(b["centre"][2], 9) for b in _br}) == [0.625, 1.625]
assert all(_close(b["centre"][:1], (1.0 - 0.125,)) and abs(b["length"] - 0.25) < 1e-9
           and _close(b["axis"], (-1, 0, 0)) for b in _br)
assert sorted(round(b["centre"][1], 9) for b in _br) == [round(2 - _hw, 9)] * 2 + [round(2 + _hw, 9)] * 2
# Rungs closer than the cut floor apart are refused, naming the part, as is a rung under the raised
# floor, a top not above the foot, and a facing straight up.
assert "L" in (ladder_refusal("L", (0, 0, 0), 2.0, (1, 0, 0), pitch=0.1) or "")
assert ladder_refusal("L", (0, 0, 0), 2.0, (1, 0, 0), pitch=0.12) is None
assert "rung" in (ladder_refusal("L", (0, 0, 0), 2.0, (1, 0, 0), rung=0.05) or "")
assert "L" in (ladder_refusal("L", (0, 0, 1), 1.0, (1, 0, 0)) or "")
assert "L" in (ladder_refusal("L", (0, 0, 0), 2.0, (0, 0, 1)) or "")

# ---- lifting lugs (#837) ----
#
# A lug is a plate standing on its own origin, its face square to its own X, with an eye through it:
# a rectangle below the eye and a half disc round its top, concentric with the eye.


def lug_refusal(*args):
    try:
        rf.lug_layout(*args)
    except SystemExit as e:
        return str(e)
    return None


_lg = rf.lug_layout("G", 0.2, [((0.0, 0.0, 0.0), (0.0, 0.0, 0.0))])
_ew, _et, _ec = rf.LUG_EYE * 0.2, rf.LUG_THICK * 0.2, rf.LUG_CENTRE * 0.2
# The eye, its plate's thickness and its centre's height scale with the lug's width.
assert abs(_lg["eye"] - _ew) < 1e-9 and abs(_lg["thick"] - _et) < 1e-9
# Each inner point is on the eye, about its centre, and each outer point is on the outline: on the
# half disc of half the width above the eye's centre, on a side or on the base below it.
assert all(abs(math.dist(p, (0.0, _ec)) - _ew / 2) < 1e-9 for p in _lg["inner"])
for (u, z) in _lg["outer"]:
    if z >= _ec - 1e-9:
        assert abs(math.dist((u, z), (0.0, _ec)) - 0.1) < 1e-9, (u, z)
    else:
        assert abs(abs(u) - 0.1) < 1e-9 or abs(z) < 1e-9, (u, z)
# Inner and outer pair up along one ray from the eye's centre, the outer always further out.
for (a, b) in zip(_lg["inner"], _lg["outer"]):
    ra, rb = (a[0], a[1] - _ec), (b[0], b[1] - _ec)
    assert abs(ra[0] * rb[1] - ra[1] * rb[0]) < 1e-9 and ra[0] * rb[0] + ra[1] * rb[1] > 0
    assert math.dist(b, (0.0, _ec)) > math.dist(a, (0.0, _ec))
# It stands from its base to the top of the half disc, and reaches the base's corners.
assert abs(_lg["height"] - (_ec + 0.1)) < 1e-9
assert any(_close(p, (0.1, 0.0)) for p in _lg["outer"]) and any(_close(p, (-0.1, 0.0)) for p in _lg["outer"])
# One lug has no neighbour; two on a ring are held apart by the cut floor, as bolts are.
assert _lg["gap"] is None
_two = rf.lug_layout("G", 0.2, rf.ring((0, 0, 0), 0.9, 2))
assert _two["gap"] is not None and _two["gap"] > 1.5
assert "G" in (lug_refusal("G", 0.2, rf.row((0, 0, 0), (0.06, 0, 0), 2)) or "")
# A lug too small for its eye or its plate is refused, naming it: the plate on the raised floor by
# its thickness, the eye on the cut floor by its diameter.
assert "G" in (lug_refusal("G", 0.18, [((0, 0, 0), (0, 0, 0))]) or "")
assert lug_refusal("G", 0.2, [((0, 0, 0), (0, 0, 0))]) is None

# ---- each part's own random stream (#825) ----
#
# A part's imperfections are drawn from a stream seeded from the machine's seed and the part's name,
# so they depend on that name alone. Here a "build" is a list of (name, draws) in build order, each
# drawing from its own stream the way rf_parts.stream hands them out: one per name, kept for the
# build. Adding a part anywhere, early or late, leaves every other part's values as they were.
def _build(parts, seed=7):
    streams, drawn = {}, {}
    for name, n in parts:
        s = streams.setdefault(name, rf.stream(seed, name))
        drawn.setdefault(name, []).extend(s.uniform(0.75, 1.6) for _ in range(n))
    return drawn


_parts = [("Manifold", 2), ("PostE0", 3), ("Drum0", 4), ("Header0", 2), ("Drum0", 1), ("Loom", 1)]
_before = _build(_parts)
for _at in range(len(_parts) + 1):
    _after = _build(_parts[:_at] + [("RailE2-0", 5)] + _parts[_at:])
    assert {k: v for k, v in _after.items() if k != "RailE2-0"} == _before, _at
# Re-ordering the parts leaves each one's values too; a name drawn from twice keeps its own order.
assert _build(list(reversed(_parts[:4])) + _parts[4:]) == _before
# The seed and the name both reach the stream; neither is ignored.
assert rf.stream(7, "Drum0").random() != rf.stream(11, "Drum0").random()
assert rf.stream(7, "Drum0").random() != rf.stream(7, "Drum1").random()
# PINNED TO A NUMBER. A change in how a name becomes a seed would re-roll every model silently,
# and this is where it shows. It runs under the system's Python only; Blender builds under its
# own, and Blender 5.2.0's Python 3.13.13 gave the same number on 2026-10-29, read once by hand.
assert rf.stream(7, "Drum0").random() == 0.10422063600183107, rf.stream(7, "Drum0").random()
# `jitter` stays inside its spread.
_s = rf.stream(7, "jitter")
assert all(abs(_s.jitter(1.0, 0.02) - 1.0) <= 0.02 for _ in range(1000))

# NOTHING ELSE DRAWS. The test above holds only if every draw a model makes comes through
# rf_blender.stream, so no file under models/ but rf_blender.py imports `random`, and that one
# uses it for `random.Random` and nothing else: a draw from the shared global stream is what
# made a part's imperfections depend on everything built before it.
import ast  # noqa: E402
_models = os.path.dirname(os.path.abspath(__file__))
for _dir, _, _files in os.walk(_models):
    for _f in _files:
        if not _f.endswith(".py"):
            continue
        _path = os.path.join(_dir, _f)
        _tree = ast.parse(open(_path, encoding="utf-8").read(), _path)
        _imports = [n for n in ast.walk(_tree)
                    if (isinstance(n, ast.Import) and any(a.name == "random" for a in n.names))
                    or (isinstance(n, ast.ImportFrom) and n.module == "random")]
        if _path == os.path.join(_models, "rf_blender.py"):
            _uses = {n.attr for n in ast.walk(_tree)
                     if isinstance(n, ast.Attribute) and isinstance(n.value, ast.Name) and n.value.id == "random"}
            assert _uses == {"Random"}, (_path, _uses)
        else:
            assert not _imports, (os.path.relpath(_path, _models), "imports random: draw from rf_parts.stream")


# NO PART THAT DRAWS IS NAMED BY ITS PLACE IN A LOOP (#827). A part's stream is its name's, so a
# name formatted from a loop's counter -- `enumerate`'s index, or `range`'s -- is an order again: a
# part inserted early in the loop renumbers every part after it, and each renumbered part draws from
# a stream it did not draw from before. Such a part is named by hand, or by what it stands on.
# A name formatted from a POSITION passes even where the position is worked out from the counter,
# as a groove's is from its pitch, and on purpose: a part added at the end of a row laid at a fixed
# pitch leaves every other part's position, and so its name, as it was. A row whose pitch is a
# length shared out among its members moves every position when one is added. The price is that
# nudging such a part renames it, and so re-rolls it.
#
# IT CANNOT TELL A POSITION FROM A COUNTER UNDER ANOTHER NAME. It sees only the loop's own counter
# written into the name, so `j = k` or `x = k * pitch` and then `f"Groove{x}"` passes whether `x`
# is a place or a rank in disguise; that a name is a place is read from source, not held here.
#
# What draws is worked out rather than listed, so a new helper is held without an edit here: a
# function draws when its body calls `stream`, `bevel`, or a function that draws, in rf_parts.py or
# in the build script itself. A call that passes `bev=0` puts no bevel on and draws nothing, so
# `seam`, which cuts a box with `bev=0`, draws nothing either.
#
# It reads the two rendered machines' build scripts, and only them. rf_parts.py's own helpers
# number the pieces of one part from `enumerate` -- a panel set's plates, a casing's segments, a
# fan stack's discs -- and are not held: a part's pieces are its own grid, fixed by the call.
#
# It reads names written in the call, as an f-string, a `+` or `%` on a string, or a `.format`.
# It cannot see one that reaches the call through a variable (`n = f"Rail{k}"; hbeam(n, ...)`), a
# counter kept by hand (`k += 1`), or a loop over anything but `enumerate` and `range` that numbers
# its parts some other way, such as `zip` with a string of letters.
def _drawing(trees):
    defs = {}
    for tree in trees:
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef):
                defs.setdefault(node.name, []).append(node)
    draws = {"stream", "bevel"}
    while True:
        more = {name for name, nodes in defs.items() if name not in draws
                and any(_callee(c) in draws and not _bevelless(c)
                        for n in nodes for c in ast.walk(n) if isinstance(c, ast.Call))}
        if not more:
            return draws
        draws |= more


def _callee(call):
    f = call.func
    return f.id if isinstance(f, ast.Name) else f.attr if isinstance(f, ast.Attribute) else None


def _bevelless(call):
    """A call that passes `bev` as a constant that is false: it puts no bevel on."""
    return any(k.arg == "bev" and isinstance(k.value, ast.Constant) and not k.value.value
               for k in call.keywords)


def _a_name(node):
    """An expression that builds a string: an f-string, `+` or `%` with a string in it, `.format`."""
    if isinstance(node, ast.JoinedStr):
        return True
    if isinstance(node, ast.BinOp) and isinstance(node.op, (ast.Add, ast.Mod)):
        return any(isinstance(n, (ast.Constant, ast.JoinedStr)) and not isinstance(getattr(n, "value", ""), (int, float))
                   for n in ast.walk(node))
    return (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
            and node.func.attr == "format" and isinstance(node.func.value, ast.Constant))


def _counters(loop):
    """The names a `for` binds to `enumerate`'s index or to `range`'s value, else none."""
    it, target = loop.iter, loop.target
    if not isinstance(it, ast.Call) or not isinstance(it.func, ast.Name):
        return set()
    if it.func.id == "enumerate":
        target = target.elts[0] if isinstance(target, ast.Tuple) else None
    elif it.func.id != "range":
        return set()
    return {n.id for n in ast.walk(target) if isinstance(n, ast.Name)} if target is not None else set()


def loop_named(source, kit=""):
    """Each name a call that draws is given, formatted from a counter of a loop round it."""
    tree, kit_tree = ast.parse(source), ast.parse(kit)
    draws = _drawing([tree, kit_tree])
    found = []

    def visit(node, counters):
        if isinstance(node, ast.For):
            counters = counters | _counters(node)
        if isinstance(node, (ast.ListComp, ast.SetComp, ast.GeneratorExp, ast.DictComp)):
            counters = counters.union(*(_counters(g) for g in node.generators))
        if isinstance(node, ast.Call) and _callee(node) in draws and not _bevelless(node):
            for arg in list(node.args) + [k.value for k in node.keywords]:
                if _a_name(arg) and any(
                        isinstance(n, ast.Name) and n.id in counters for n in ast.walk(arg)):
                    found.append(ast.unparse(arg))
        for child in ast.iter_child_nodes(node):
            visit(child, counters)

    visit(tree, set())
    return found


_kit_src = "def stream(name): pass\ndef bevel(o, w, name): stream(name)\ndef cyl(name): bevel(0, 0, name)\n"
# A name formatted from `enumerate`'s index is found, from `range`'s too, and through a helper that
# draws only by calling one that does.
assert loop_named("for k, t in enumerate(xs):\n    cyl(f'Ice{k}')", _kit_src) == ["f'Ice{k}'"]
assert loop_named("for i in range(3):\n    stream(f'Drum{i}')", _kit_src) == ["f'Drum{i}'"]
assert loop_named("def lump(n): cyl(n)\nfor k, t in enumerate(xs):\n    lump(f'Ice{k}')",
                  _kit_src) == ["f'Ice{k}'"]
# A comprehension's counter is a counter.
assert loop_named("[cyl(f'Tube{k}') for k in range(4)]", _kit_src) == ["f'Tube{k}'"]
# A name given by hand passes, and so does one formatted from the loop's VALUE rather than its index.
assert loop_named("for k, (name, t) in enumerate(xs):\n    cyl(f'Ice{name}')", _kit_src) == []
assert loop_named("for sx in (-1, 1):\n    cyl(f'Post{sx}')", _kit_src) == []
# A part that draws nothing may keep its number: `bev=0`, or a helper that never reaches `stream`.
assert loop_named("for i in range(30):\n    box(f'Slat{i}', bev=0)",
                  _kit_src + "def box(name, bev=0.03): bevel(0, bev, name)\n") == []
assert loop_named("def rivet(n): pass\nfor i in range(3):\n    rivet(f'Rivet{i}')", _kit_src) == []
# Nor does a helper that reaches one only through a call passing `bev=0`, as `seam` reaches `box`.
assert loop_named("def seam(n): box(n, bev=0)\nfor i in range(3):\n    seam(f'Seam{i}')",
                  _kit_src + "def box(name, bev=0.03): bevel(0, bev, name)\n") == []
# A name built by `+`, `%` or `.format` is read as an f-string is; a number worked from the counter
# is not a name.
assert loop_named("for i in range(3):\n    cyl('Drum' + str(i))", _kit_src) == ["'Drum' + str(i)"]
assert loop_named("for i in range(3):\n    cyl('Drum%d' % i)", _kit_src) == ["'Drum%d' % i"]
assert loop_named("for i in range(3):\n    cyl('Drum{}'.format(i))", _kit_src) == ["'Drum{}'.format(i)"]
assert loop_named("for i in range(3):\n    cyl('Drum', i * 0.5 + 1)", _kit_src) == []

_kit = open(os.path.join(_models, "rf_parts.py"), encoding="utf-8").read()
for _machine in ("heat-exchanger", "isotope-collector"):
    _found = loop_named(open(os.path.join(_models, _machine, "build.py"), encoding="utf-8").read(), _kit)
    assert not _found, (_machine, "names a part that draws by its place in a loop", _found)

# ---- CC0 image textures (#805, ADR 0043) ---------------------------------------------------------
#
# A texture loads only with a record beside it in the model's textures.json: an https source, the
# CC0 licence and the file's own sha256. Anything that is not an image is refused whatever its
# record says, which is what keeps a mesh out of this path.
import hashlib  # noqa: E402
import tempfile  # noqa: E402


def texture_refusal(model_dir, filename):
    """The message texture_record exits with, or None when it passes."""
    try:
        rf.texture_record(model_dir, filename)
    except SystemExit as e:
        return str(e.code)
    return None


with tempfile.TemporaryDirectory() as _tex:
    _bytes = b"not really a jpeg, but bytes are bytes"
    _good = {"source": "https://polyhaven.com/a/rust_coarse_01", "licence": "CC0-1.0",
             "sha256": hashlib.sha256(_bytes).hexdigest()}

    def _plant(records, *files):
        for f in files:
            with open(os.path.join(_tex, f), "wb") as out:
                out.write(_bytes)
        with open(os.path.join(_tex, rf.TEXTURE_RECORDS), "w", encoding="utf-8") as out:
            json.dump(records, out)

    assert "no textures.json" in texture_refusal(_tex, "rust.jpg")
    _plant({"rust.jpg": _good}, "rust.jpg", "grime.png", "mesh.obj")
    assert rf.texture_record(_tex, "rust.jpg")["licence"] == "CC0-1.0"
    assert "no record" in texture_refusal(_tex, "grime.png")
    assert "not on disk" in texture_refusal(_tex, "absent.jpg")
    # A mesh is refused with a perfect record, so no record can let one in.
    _plant({"mesh.obj": _good}, "mesh.obj")
    assert "not an image" in texture_refusal(_tex, "mesh.obj")
    for _field, _bad, _said in (("licence", "CC-BY-4.0", "CC0-1.0"), ("source", "http://example.com/x", "https"),
                                ("source", "", "https"), ("sha256", "0" * 64, "sha256")):
        _plant({"rust.jpg": {**_good, _field: _bad}})
        _said_now = texture_refusal(_tex, "rust.jpg")
        assert _said_now and _said in _said_now, (_field, _bad, _said_now)
    _plant({"rust.jpg": {k: v for k, v in _good.items() if k != "licence"}})
    assert "CC0-1.0" in texture_refusal(_tex, "rust.jpg")

# Every texture the models keep passes, so a record that has rotted fails here as well as in
# scripts/ship-check.ps1.
_models = os.path.dirname(os.path.abspath(__file__))
for _machine in sorted(os.listdir(_models)):
    _dir = os.path.join(_models, _machine)
    if not os.path.isdir(_dir):
        continue
    for _f in sorted(os.listdir(_dir)):
        if os.path.splitext(_f)[1].lower() in rf.TEXTURE_EXTENSIONS:
            rf.texture_record(_dir, _f)

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

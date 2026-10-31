"""The shared Factorio rig and frame, imported from inside Blender's Python by every build script
and by render.py. Blender does not put a --python script's directory on sys.path; callers insert
this file's directory themselves. Only `build_rig` and `ground_report` touch bpy, and each
imports it inside its own body, so the constants and the frame arithmetic import under system Python
for models/test_rf_blender.py. (`accent` was named here until #366 and never touched bpy at all; it
returns a string from a dict.)

Camera and light follow docs/research/factorio-render-camera.md as #246 settled them: orthographic,
pitched 54.7 deg below the horizontal, looking north (+Y); one hard sun from the west (-X) at 42 deg
elevation so shadows fall east; a grey world for ambient fill. The ground is stretched back to
square tiles IN THE CAMERA, by a pixel aspect of 1/sin(pitch) on x: the render then lands at the
final sheet size, pixel-exact on both axes, with no resize afterwards. A vertical shows at
h / tan(pitch) = 0.707 h.
"""
import atexit
import hashlib
import json
import math
import os
import random
import sys

PX_PER_TILE = 64
# Camera pitch below the horizontal. 45 deg is Wube's stated angle; with the ground stretched
# back to square tiles a vertical then shows at h/tan(pitch). Truls (2026-09-04, #246) preferred
# verticals at ~0.707 h beside vanilla, which is pitch 54.7 deg: the same picture as "45 deg, no
# stretch" for the walls, but the footprint fills its tiles.
CAMERA_PITCH_DEG = 54.7
STRETCH = 1.0 / math.sin(math.radians(CAMERA_PITCH_DEG))
SUN_ELEVATION_DEG = 42.0
# Room around the footprint for the height above the north edge and the shadow to the east.
# Symmetric, so the sheet stays centred on the footprint and pictures.lua ships shift zero. The
# shadow sets it: measured on the heat exchanger (valve caps 3.8 tiles up, sun at 42 deg) the
# shadow reaches 2.83 tiles past the east footprint edge, so 2 tiles clipped it and 3 hold it.
MARGIN_TILES = 3.0
# Emission strength of a glowing part, applied by render.py to every emissive material. The game
# adds the glow sheet on top of the structure, and adding whitens: 1.5 blew out (#246) and 0.6
# still came out cream, so the sheet is kept dim and saturated for the sum to read as the accent.
GLOW_EMISSION = 0.3
# How far a glowing part's BASE colour is darkened in the structure sheet. A glowing part is the
# accent in both sheets, and the game adds them, so at 1.0 the sum is accent-over-accent and the
# channel washed pale cream in daylight -- and, worse, looked lit when the machine was cold, since
# the structure sheet is all a stopped machine draws. Truls, 2026-09-05 (#252), chose to darken the
# base rather than dim the emission: the night glow was already right. 0.12 keeps the hue, so the
# cold channel reads as a dark warm trough rather than a black slot. Dropped from 0.12 to 0.07
# on 2026-09-05: at 0.12 the fourteen-tile channel came out mid-brown and read as copper.
GLOW_BASE_DARKEN = 0.07

# THE HEIGHT A PLAYER-FACING SOCKET IS DRAWN AT, MEASURED AGAINST A VANILLA PIPE AND NOT CHOSEN
# (Truls, 2026-09-14: the sockets "should appear to connect with vanilla pipes"). It was 0.55 on
# both rendered machines and the join was a visible step -- scripts/probe-socket-height.ps1 is the
# rig that showed it and this is what it measured.
#
# IT IS HERE, BESIDE THE CAMERA, FOR TWO REASONS. It is derived from CAMERA_PITCH_DEG, so it belongs
# with the pitch it is solved against rather than a file away from it; and this module imports no
# bpy, so tools/check-socket-height.py can import the number the models are built at and hold its
# own reference against it (#354). models/rf_parts.py re-exports it, so every build script still
# reads it as `rf_parts.SOCKET_Z` and none of them changed when it moved.
#
# A cylinder of radius r lying along an axis at height z draws its silhouette centred 0.707 z above
# the ground line, the r terms cancelling: the top point (y -r, z + r) lands at -r - 0.707(z + r)
# and the bottom (y +r, z - r) at +r - 0.707(z - r), and the mean of those is -0.707 z. Measured on
# the rendered sheet at z 0.55 the centre sat 0.398 tiles up, against 0.707 x 0.55 = 0.389
# predicted, so the projection is understood rather than curve-fitted.
#
# Vanilla's own pipe draws its body centred 0.0234 tiles above the ground line
# (base/graphics/entity/pipe/pipe-straight-horizontal.png, scale 0.5 and no shift, so 64 px to the
# tile and directly comparable with ours -- its barrel's edge-midpoint is 1.5 px above the image
# centre, and 1.5 / 64 = 0.0234). Setting 0.70804 z = 0.0234 gives 0.0331, which is this to three
# places. tools/check-socket-height.py measures that reference off vanilla's own sheet at run time
# (#355) and holds THIS CONSTANT against it (#356), so the two can no longer part in silence.
#
# IT WAS 0.044 UNTIL #356, AND 0.044 IS WHAT SOLVING AGAINST 0.031 GIVES. The pipe's barrel runs
# rows 43..81 of 128; its midpoint is 62.5 read by row centres and 62.5 read by row edges, which is
# the 1.5 px above. 0.031 is 2.0 px, and comes from averaging the bare row INDICES
# (43 + 81) / 2 = 62 against a centre of 64: one convention on one side of the arithmetic and
# another on the other. Every plumbable socket was therefore drawn 0.011 tiles of world height too
# high -- 0.49 px on the sheet, 0.25 px at the game's own zoom -- for as long as the two numbers
# were typed rather than compared.
SOCKET_Z = 0.033
#
# AND THAT PUTS THE TUBE THROUGH THE PLINTH, which is the trade Truls made explicitly: *"Going below
# the floor is preferable to this look. If intersecting the floor, the floor should have a modelled
# hole for the pipe."* Both machines stand on a slab 0.25 tiles thick, and a socket of any radius
# over 0.217 at this height reaches through it -- so `rf_parts.port` cuts the hole and rims it, and
# every machine with a player-facing socket calls it.
#
# ONLY A PLAYER-FACING SOCKET. A CONTAINED connection (ADR 0018) meets a machine face, never a pipe:
# lowering one would match it to a pipe that cannot exist and break the bolted contact it is for.
# models/heat-exchanger/build.py is the machine that carries both kinds and says so at its socket
# loop.

# WHERE A SOCKET'S PIECES SIT ON ITS TUBE, as distances inboard from the footprint edge the stub
# stops at, and how far past the tube each of them stands. `rf_parts.port` places the rim from the
# first three and `rf_parts.socket` places the rest; they live together because the flange pair is
# FITTED INTO WHAT THE RIM AND THE BAND LEAVE BETWEEN THEM, so a rim or a band written out
# somewhere else would move without the ribs following. Constants rather than arguments because
# these are a socket's proportions rather than a machine's choice: both rendered machines have
# always used exactly these.
#
# THEY ARE HERE RATHER THAN IN models/rf_parts.py FOR SOCKET_Z'S OWN REASON (#365). rf_parts
# imports bpy, so nothing outside Blender can read it, and tools/measure-socket-parts.py has to
# know which columns of a sheet each piece of a socket occupies before it can measure one. Reading
# them here makes the instrument and the model one statement; typing them into the tool would make
# them two, which is the failure #340 recorded and the reason `socket` is one helper at all.
# rf_parts re-exports every one, so every build script still reads them where it always did.
RIM_BACK = 0.03                  # the dark rim's centre
RIM_MINOR = 0.05                 # its tube radius, so the rim owes the first RIM_BACK + RIM_MINOR
RIM_PROUD = 0.02                 # how far its major radius stands past the tube
BAND_BACK = 0.28                 # the accent band's centre
BAND_DEPTH = 0.22                # so the band starts BAND_BACK - BAND_DEPTH / 2 back
BAND_PROUD = 0.04                # how far the band stands out past the tube
PORT_CLEARANCE = 0.06            # and the hole past the band, so it reads as a hole

# THE FLANGE PAIR AT A PLUMBABLE SOCKET'S MOUTH (#351, shipped by #353): two ribs standing proud of
# the tube, in the tube's own material, just inboard of the dark rim. models/house-style.md carries
# the decision and ADR 0033 the principle behind it -- a socket borrows a vanilla drawing cue when
# the cue is also hardware a real pipe has, and a flange is.
#
# THE RIBS ARE FITTED INTO THE CLEAR TUBE, NEVER PLACED AT TYPED OFFSETS. There is very little of
# it: the rim owes 0.08 and the band starts at 0.17, which leaves 0.09 tiles of metal. Typed
# offsets are how models/socket-variants.py first drew this, and they buried one rib in the rim and
# clipped the band with the other -- a fat lump rather than a flange pair. So the span is derived
# from the rim and band constants above and the ribs are divided into it.
#
# WHICH MAKES THE SPAN THE SAME ON EVERY MACHINE, and `rf_parts.socket`'s floor on it is therefore
# a guard on THESE FOUR CONSTANTS rather than on a machine. Nothing a build script passes can move
# it: a caller chooses `z` and `radius`, and the rim and the band sit at the same distances back
# whatever it chooses. models/socket-variants.py is where the same floor is live per machine,
# because there the span is measured off a stored model rather than known while building one.
FLANGE_GAP = 0.2                 # of the clear span, left between the two ribs
FLANGE_MIN_THICK = 0.02          # under this a rib is thinner than a pixel and there is no pair
# What makes a rib read as a flange is standing PROUD of the tube, not its thickness: 0.07 tiles,
# which is 2.24 px ON THE PLAYER'S SCREEN -- never the 4.5 it measures at 64 px to the sheet, the
# one unit this repository refuses to quote a detail in.
#
# PROUD IS NOT WHAT THE FLOOR MEASURES. The floor judges `read=`, and `rf_parts.socket` hands it
# the disc's FACE, 2 * (radius + FLANGE_PROUD) -- about 0.64 tiles, 20 px on screen -- so a rib
# this thin clears the raised-detail floor by eighteen pixels rather than missing it by a third of
# one. #361 published that mistake; do not repeat it.
FLANGE_PROUD = 0.07

# House-style accent per fluid. The geometry file carries the fluid name (#248); the accent is
# ours. An unlisted fluid is an error rather than a guess, because an unaccented socket lies about
# what it carries -- with ONE exception, `accent`'s plasma fallback, which is a substring match and
# therefore is a guess. It is deliberate (every plasma shares one accent, ADR 0010's four of them
# included) and it is the one place a future fluid could be accented by accident: anything with
# "plasma" in its name is taken to be one.
#
# THIS MAP IS NAMES, NOT VALUES, and the values are gated elsewhere. scripts/ship-check.ps1
# section 8 holds a fluid's colour in the Core mod against its palette row in house-style.md and
# against every build script's own PALETTE copy (#334); models/test_rf_blender.py checks only the
# mapping below. An accent named for one of our fluids is in that gate's scope automatically, so a
# third by-product accent needs nothing added to make it hold.
#
# THE TWO BY-PRODUCT ACCENTS ARE THE FLUIDS' OWN ICON COLOURS, not new picks (Truls, #262):
# realistic-fusion-refreshed-core/prototypes/fluids.lua draws rf-tritium green and rf-helium-3
# violet, and a player who has learnt a fluid from its icon should meet the same colour on the
# machine's socket. Helium-3's violet is close to the plasma accent, which is not a clash on the
# isotope collector -- it carries no plasma -- but will want watching on a machine that carries
# both.
ACCENT_OF_FLUID = {
    "rf-reactor-energy": "energy",
    "rf-aneutronic-reactor-energy": "energy",
    "steam": "steam",
    "water": "water",
    "rf-tritium": "tritium",
    "rf-helium-3": "helium-3",
}


def accent(fluid):
    if fluid in ACCENT_OF_FLUID:
        return ACCENT_OF_FLUID[fluid]
    if "plasma" in fluid:
        return "plasma"
    sys.exit(f"no house-style accent for fluid {fluid!r}; add it to rf_blender.ACCENT_OF_FLUID")


# DETAIL FLOORS, in tiles. models/house-style.md states them in pixels on the player's screen and
# says why they are two rather than one; docs/research/detail-floor.md holds the measurement they
# were set from. They live here, beside the camera and the glow, because a floor written into a
# build script is a floor that drifts -- the mesh helpers are already copied per machine.
#
# A CUT DETAIL reads by the shadow line cut into it, so contrast does the work: 0.05 tiles is
# 1.6 px on the player's screen at scale 0.5, and every groove and seam that ships is exactly that.
# A RAISED DETAIL reads by its own lit silhouette against what is behind it and needs more: 0.06,
# which is 1.9 px. Vanilla's own deliberate rivets are finer than both, so there is headroom below.
CUT_DETAIL_FLOOR = 0.05
RAISED_DETAIL_FLOOR = 0.06


def check_detail(name, read, cut=False):
    """Refuse a feature whose read dimension is under its floor. Returns `read` so a caller can
    wrap a value inline.

    `read` IS THE DIMENSION THAT CARRIES THE READ, not the object's smallest: a rivet's diameter, a
    torus's minor DIAMETER, an H-beam's flange width, a groove's width. Passing the smallest instead
    condemns the H-beam web, which is 0.03 tiles, stands edge-on to this camera and is never the
    thing anyone sees -- and the house style names H-beams as the frame every open machine is built
    from. Read a torus as its minor RADIUS and most of them fail too.

    TWO CALLERS DO PASS THE SMALLEST, knowingly. `rf_parts.box` passes `min(size)` and `rf_parts.cyl`
    passes `min(2 * radius, depth)`, because neither helper is told which face this camera will see.
    For a groove that is exactly right: grooves are cut square, so the smallest dimension IS the
    width. For a raised member it is conservative, and sometimes wrong in the H-beam's own direction
    -- a handwheel disc 0.28 across and 0.05 thick shows its FACE to the camera and was judged on its
    edge. Three of those were thickened on the heat exchanger, whose art is accepted, so the cost is
    real and whether to add a `read=` override is Truls's call (raised reviewing #339).

    A BEVEL IS NOT A FEATURE. Bevel widths here are 0.01 to 0.03 and are edge treatment: every
    visible edge carries one so the key light catches it. Checking them would fail every object on
    every machine. `bevel` does not call this and should not.

    Fails the build rather than warning, because a render is what happens next and a sheet that
    shimmers is worse than no sheet.
    """
    floor = CUT_DETAIL_FLOOR if cut else RAISED_DETAIL_FLOOR
    if read < floor - 1e-9:
        kind = "cut" if cut else "raised"
        message = (f"detail floor: {name} reads at {read:.4f} tiles "
                   f"({read * PX_PER_TILE * 0.5:.2f} px on the player's screen), under the "
                   f"{kind}-detail floor of {floor} ({floor * PX_PER_TILE * 0.5:.2f} px). "
                   f"See models/house-style.md.")
        if os.environ.get("RF_DETAIL_AUDIT"):
            _AUDIT.append((name, read, kind, floor))
            return read
        sys.exit(message)
    return read


# AUDIT MODE, because the gate above stops at the first offender and a model has many. With
# RF_DETAIL_AUDIT set, a violation is collected instead of fatal and the whole list prints when the
# build ends -- which is how a machine's full failure list is got in one run rather than in a dozen
# builds, one fix apart. It is a reporting mode and never a way to ship: the build still renders a
# model it has just said is wrong, so nothing should set it but a person asking a question.
_AUDIT = []


def _report_audit():
    if not _AUDIT:
        return
    print("", file=sys.stderr)
    print(f"RF_DETAIL_AUDIT: {len(_AUDIT)} feature(s) under their floor", file=sys.stderr)
    print(f"  {'feature':32} {'tiles':>7} {'screen px':>10} {'kind':>7} {'floor':>7}", file=sys.stderr)
    for name, read, kind, floor in sorted(_AUDIT, key=lambda r: r[1]):
        print(f"  {name:32} {read:7.4f} {read * PX_PER_TILE * 0.5:10.2f} {kind:>7} {floor:7.3f}",
              file=sys.stderr)


atexit.register(_report_audit)


# THE FOOTPRINT EDGE (Truls, 2026-10-26, #800): nothing pipe-shaped meets a footprint edge except
# at a declared socket. A run that comes out of the machine on a tile with no connection looks like
# a pipe mouth, and the player acts on it -- the house style already said a socket where no
# connection is declared misleads; a kit hose ending at the edge is the same lie drawn another way.
#
# AN END COUNTS AS LEAVING when its last segment points out through an edge to within 60 degrees of
# that edge's normal, and the tube, end plus radius, stands past the collision box: out of the body
# and into the band a socket's mouth occupies. Running ALONG an edge is allowed, since a run along
# the north edge points east or west. Turning down into the floor is allowed, since it points down.
EDGE_EXIT_COS = 0.5


def check_edge(name, points, radius, geo):
    """Refuse a pipe-shaped run whose end leaves the footprint on a tile with no declared
    connection on that edge. `points` are its centreline in Blender's frame (+y north), in order;
    both ends are read. `geo` is the machine's geometry.json.

    THE TILE IS NAMED IN FACTORIO'S COORDINATES, the ones geometry.json declares connections in
    and the ones a player's map uses, so Blender's y is negated before it is printed.

    WHAT IT CANNOT SEE: the middle of a run. A tube that bows out past an edge and comes back is not
    read, nor is anything that is not handed over as a run -- a horizontal `cyl` or a `box`. A kit
    part that is pipe-shaped and not built by `rf_parts.pipe` hands its span to `rf_parts`'
    save-time check, as `rf_parts.valve` and `rf_parts.cable_tray` do, or
    calls this itself with its points in the DECLARED frame: rf-heat-exchanger is built in another
    one and turned, which is why `rf_parts` checks its runs at save.
    """
    half = (geo["tiles"][0] / 2, geo["tiles"][1] / 2)
    (cx0, cy0), (cx1, cy1) = geo["collision_box"]
    # The body's edge per Blender axis and sign; Factorio's y flips, so its north is Blender's +y.
    body = {(0, 1): cx1, (0, -1): -cx0, (1, 1): -cy0, (1, -1): cy1}
    names = {(0, 1): "east", (0, -1): "west", (1, 1): "north", (1, -1): "south"}
    declared = {(c["direction"], tuple(c["position"])) for c in geo["connections"]}
    for run in (list(points), list(reversed(points))):
        end = run[-1]
        before = next((p for p in reversed(run[:-1]) if math.dist(p, end) > 1e-9), None)
        if before is None:
            continue
        length = math.dist(before, end)
        out = [(end[k] - before[k]) / length for k in range(3)]
        for (axis, sign), wall in body.items():
            if out[axis] * sign < EDGE_EXIT_COS or end[axis] * sign + radius <= wall + 1e-9:
                continue
            across = 1 - axis
            a = end[across] if across == 0 else -end[across]          # Factorio's coordinate
            centre = math.floor(a + half[across]) - half[across] + 0.5
            edge = half[axis] - 0.5
            tile = [0.0, 0.0]
            tile[axis] = edge * sign if axis == 0 else -edge * sign
            tile[across] = centre
            d = names[(axis, sign)]
            if (d, tuple(tile)) in declared:
                continue
            shown = ", ".join(f"{v:g}" for v in tile)
            sys.exit(f"footprint edge: {name} leaves the {d} edge on tile ({shown}), where "
                     f"{geo['name']} declares no {d} connection. Only a socket meets a footprint "
                     f"edge; run along the edge or turn into the floor instead. "
                     f"See models/house-style.md, Connections.")


# ---- the kit's arithmetic ----------------------------------------------------------------------
#
# WHERE A KIT PART'S PIECES GO, with no bpy, so models/test_rf_blender.py can pin it. models/rf_parts.py
# draws the parts from these; a build script places a part and never computes its pieces itself.

# A LOOM'S CABLES ARE SHEATHED IN COLOURS NO FLUID OWNS (#803). Krastorio 2's reactor runs red and
# green looms. The red is a dark oxide red, well short of the energy accent's orange; the green is a
# dark olive, well short of tritium's pale green and of water's blue. Neither is a marking yellow.
# Measured against every accent in docs/research/density-figures.md. Rows of a machine's palette,
# in its (linear RGB, roughness, metallic) shape: a PVC sheath, matte, not metal.
CABLE_COLOURS = {
    "cable-red":   ((0.30, 0.025, 0.02), 0.6, 0.0),
    "cable-green": ((0.035, 0.12, 0.03), 0.6, 0.0),
}


def _unit(v):
    n = math.sqrt(sum(c * c for c in v))
    return tuple(c / n for c in v) if n > 1e-12 else None


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def bundle(points, n, spread, twist=0.0, phase=0.0):
    """`n` strands laid round the centreline `points`, each point `spread` off it and square to the
    run at that point. Strand k starts at angle `phase` + 2 pi k / n and turns by `twist` radians per
    control point, so a twisted bundle winds instead of lying parallel, and two bundles on one curve
    given different phases wind differently. One strand is the centreline itself.

    THE RUN'S DIRECTION AT A POINT is the chord from the point before it to the point after it, so a
    bend is split between its two legs. The "side" a strand is offset along is that direction
    crossed with up, and a vertical stretch, which has no such side, is crossed with east instead,
    which lays its side north-south; so a loom that climbs straight up a post still spreads, round
    the post's axis."""
    if n == 1:
        return [list(points)]
    strands = [[] for _ in range(n)]
    for i, p in enumerate(points):
        a, b = points[max(i - 1, 0)], points[min(i + 1, len(points) - 1)]
        d = _unit(tuple(b[j] - a[j] for j in range(3)))
        side = _unit(_cross(d, (0.0, 0.0, 1.0))) or _unit(_cross(d, (1.0, 0.0, 0.0)))
        up = _cross(side, d)
        for k in range(n):
            t = phase + 2 * math.pi * k / n + twist * i
            strands[k].append(tuple(p[j] + spread * (math.cos(t) * side[j] + math.sin(t) * up[j])
                                    for j in range(3)))
    return strands


def loom_spread(n, cable_r, gap=0.006):
    """How far off the centreline `n` cables of radius `cable_r` lie so that neighbours sit `gap`
    apart: the chord between neighbours on the circle is a diameter plus the gap. A small gap rather
    than none, so two cables do not share a surface and the shadow line between them reads."""
    if n == 1:
        return 0.0
    return (2 * cable_r + gap) / (2 * math.sin(math.pi / n))


def panel_grid(u, v, nu, nv, seam):
    """Cut a face `u` by `v` into `nu` by `nv` plates, a `seam` between neighbours and round the
    edge. Returns (centre u, centre v, size u, size v) per plate, in the face's own frame centred on
    the face, row by row."""
    su, sv = (u - (nu + 1) * seam) / nu, (v - (nv + 1) * seam) / nv
    return [(-u / 2 + seam + su / 2 + i * (su + seam), -v / 2 + seam + sv / 2 + j * (sv + seam), su, sv)
            for j in range(nv) for i in range(nu)]


def check_inset(name, seam, depth, plate):
    """Refuse an inset panel whose seams would not read. A seam is a CUT detail and reads by the
    shadow line in it, so it is held to the cut floor on its width and is cut at least as deep as
    it is wide (house style, Proportion and detail): a shallow wide channel casts a weak line. A
    plate reads by its face, so `plate`, its smaller side, is held to the raised floor."""
    check_detail(f"{name} (seam)", seam, cut=True)
    check_detail(f"{name} (plate)", plate)
    if depth < seam - 1e-9:
        sys.exit(f"inset panels: {name}'s seams are {seam:g} wide and {depth:g} deep. A seam is cut at "
                 f"least as deep as it is wide, or its shadow line is too weak to read. "
                 f"See models/house-style.md, Proportion and detail.")


# REPEATED MODULES ARE PLACED THREE WAYS (#804): round a ring, along a row, up a stack. Each gives a
# list of (location, rotation); a module is built about its own origin, along its own Z, and is
# turned by the rotation and moved to the location. One shape placed many times is what reads as
# engineered, and one placement rule per arrangement is what keeps it the same shape each time.

def ring(centre, radius, n, phase=0.0):
    """`n` placements round a horizontal ring, each turned about Z to face out from the centre."""
    out = []
    for k in range(n):
        a = phase + 2 * math.pi * k / n
        out.append(((centre[0] + radius * math.cos(a), centre[1] + radius * math.sin(a), centre[2]),
                    (0.0, 0.0, a)))
    return out


def row(start, end, n, rot=(0.0, 0.0, 0.0)):
    """`n` placements along a straight line, each in the middle of its own nth of it, as a rivet
    line is spaced; all turned by `rot`."""
    return [(tuple(start[j] + (end[j] - start[j]) * (k + 0.5) / n for j in range(3)), rot)
            for k in range(n)]


def stack(base, n, pitch, rot=(0.0, 0.0, 0.0)):
    """`n` placements climbing straight up from `base`, `pitch` apart."""
    return [((base[0], base[1], base[2] + k * pitch), rot) for k in range(n)]


def euler_matrix(rot):
    """The 3x3 matrix of Blender's XYZ Euler rotation `rot`: about x, then y, then z."""
    (ca, sa), (cb, sb), (cc, sc) = ((math.cos(a), math.sin(a)) for a in rot)
    return ((cc * cb, cc * sb * sa - sc * ca, cc * sb * ca + sc * sa),
            (sc * cb, sc * sb * sa + cc * ca, sc * sb * ca - cc * sa),
            (-sb, cb * sa, cb * ca))


def turn(m, p):
    return tuple(sum(m[i][j] * p[j] for j in range(3)) for i in range(3))


def least_gap(points, placements):
    """The least distance between the points of neighbouring placed parts, or None for one part.
    `points` are the part's own points about its origin, its vertices or a sample of its outline.
    Each placement's neighbours are the next in the list, which is how ring, row and stack order
    them, and the last is also held against the first, which closes a ring and is far off on a row.

    MEASURED FROM THE PARTS, NOT FROM THE ARRANGEMENT, so one rule serves a ring, a row and a
    stack: two discs stacked meet along their axis and two in a row meet across their rims.

    IT IS AN UPPER BOUND ON THE GAP, not the gap: it measures point to point, and a face or an edge
    can stand closer than any pair of points on it. Where points face each other it is exact -- a
    casing's corners, a stack -- and turned on a ring it can be lenient by up to the spacing of the
    points along an outline. Nor can it see two parts passing through each other, since
    interpenetrating points can stand apart; overlapping neighbours almost always come out under
    the floor, and the checks refuse them."""
    if len(placements) < 2:
        return None
    placed = []
    for loc, rot in placements:
        m = euler_matrix(rot)
        placed.append([tuple(a + b for a, b in zip(turn(m, p), loc)) for p in points])
    pairs = list(zip(placed, placed[1:])) + ([(placed[-1], placed[0])] if len(placed) > 2 else [])
    return min(math.dist(a, b) for p, q in pairs for a in p for b in q)


def check_gap(name, gap, depth):
    """Refuse a slot between repeated parts that would not read, where the slot is cut through
    something `depth` deep, as between a casing's segments. It reads like a cut, by the shadow in
    it, so it is held to the cut floor on its width and must run at least as deep as it is wide,
    the house style's rule for a groove. Parts that merely stand apart, bolts and fan discs, are
    held to the cut floor alone."""
    check_detail(f"{name} (gap)", gap, cut=True)
    if depth < gap - 1e-9:
        sys.exit(f"repeated module: {name}'s gaps are {gap:g} wide and {depth:g} deep. A gap is cut at "
                 f"least as deep as it is wide, or its shadow line is too weak to read. "
                 f"See models/house-style.md, Proportion and detail.")


def casing_points(radius, arc, height, thick, steps=8):
    """A casing segment's vertices about its own origin: `steps` + 1 cross-sections along the arc,
    four corners each -- inner bottom, outer bottom, outer top, inner top -- with the circle's
    centre `radius` behind the origin, so a ring's outward-facing placement wraps it round."""
    out = []
    for s in range(steps + 1):
        t = -arc / 2 + arc * s / steps
        out += [(-radius + R * math.cos(t), R * math.sin(t), z)
                for R, z in ((radius, -height / 2), (radius + thick, -height / 2),
                             (radius + thick, height / 2), (radius, height / 2))]
    return out


def casing_arc(n, radius, gap):
    """The arc, in radians, each of `n` casing segments round `radius` spans when neighbours stand
    `gap` tiles apart along the circumference."""
    return 2 * math.pi / n - gap / radius


# THE INLINE VALVE'S PROPORTIONS, as multiples of the run's radius r (#833). A gate valve's body is
# wider than its pipe and bolted to it between two flanges; its bonnet and stem carry the
# handwheel out along the facing.
#
# THE RIM AND THE STEM ARE NEVER DRAWN UNDER THE RAISED FLOOR (Truls, 2026-10-30, while #833 was
# implemented). In proportion the rim falls under it on a run thinner than VALVE_THIN_RUN, a sixth
# of a tile, and the stem on one thinner than 0.15; the water header's 0.13 is under both. So on a
# thin run the two are drawn at the floor, and the wheel's hub and spokes, sized from the rim, with
# them: the wheel reads chunkier for its size. The alternative was refusing the valve on every run
# thinner than a sixth of a tile.
VALVE_BODY = (1.6, 2.4)          # radius, length along the run
VALVE_FLANGE = (1.9, 0.35)       # radius, thickness
VALVE_BONNET = (0.75, 2.4)       # radius, how far out along the facing its far end stands
VALVE_STEM = (0.2, 1.2)          # radius, length past the bonnet
VALVE_WHEEL = (1.9, 0.18)        # the wheel's major and minor radius; the minor carries the read
VALVE_THIN_RUN = RAISED_DETAIL_FLOOR / (2 * VALVE_WHEEL[1])     # where the rim leaves proportion


def valve_layout(name, at, direction, radius, facing):
    """Where an inline valve's pieces go, on a run of `radius` at the point `at`, running along
    `direction` there, with its handwheel out along `facing`.

    THE FACING IS MADE SQUARE TO THE RUN: its component along the run is taken out, so a caller
    can pass the way the camera looks and get the nearest facing a wheel on that run can have. One
    within about 11.5 degrees of the run, whose square part is under a fifth of it, is refused.

    THE HANDWHEEL'S RIM CARRIES THE READ, on the raised floor by its minor diameter. It and the
    stem are drawn at the floor where the run's proportion would put them under it (VALVE_THIN_RUN,
    above), and the rim is held to the floor here all the same. Returns each piece's centre, axis
    and size, the facing, `reach`, how far the valve stands out along the facing, which is the far
    face of the wheel's hub, and `span`, how far the wheel reaches across it."""
    d = _unit(direction)
    if d is None:
        sys.exit(f"valve: {name} is given no direction along its run.")
    along = sum(a * b for a, b in zip(facing, d))
    f = _unit(tuple(c - along * k for c, k in zip(facing, d)))
    if f is None or abs(along) > 0.98 * math.sqrt(sum(c * c for c in facing)):
        sys.exit(f"valve: {name} faces along its run, {tuple(facing)}, so its handwheel has no side "
                 f"to stand on. Give a facing square to the run, or near it.")
    least = RAISED_DETAIL_FLOOR / 2
    minor = max(VALVE_WHEEL[1] * radius, least)
    check_detail(f"{name} (handwheel rim)", 2 * minor)

    def off(p, v, k):
        return tuple(a + k * b for a, b in zip(p, v))

    body_r, body_len = VALVE_BODY[0] * radius, VALVE_BODY[1] * radius
    fl_r, fl_t = VALVE_FLANGE[0] * radius, VALVE_FLANGE[1] * radius
    bonnet_r, bonnet_out = VALVE_BONNET[0] * radius, VALVE_BONNET[1] * radius
    stem_r, stem_len = max(VALVE_STEM[0] * radius, least), VALVE_STEM[1] * radius
    wheel_out = bonnet_out + stem_len
    return {
        "facing": f,
        "body": {"centre": tuple(at), "axis": d, "radius": body_r, "length": body_len},
        "flanges": [{"centre": off(at, d, s * (body_len + fl_t) / 2), "axis": d, "radius": fl_r,
                     "thickness": fl_t} for s in (-1, 1)],
        # From the run's axis to bonnet_out: it starts inside the body, so the two read as one casting.
        "bonnet": {"centre": off(at, f, bonnet_out / 2), "axis": f, "radius": bonnet_r,
                   "length": bonnet_out},
        "stem": {"centre": off(at, f, bonnet_out + stem_len / 2), "axis": f, "radius": stem_r,
                 "length": stem_len},
        "wheel": {"centre": off(at, f, wheel_out), "normal": f, "major": VALVE_WHEEL[0] * radius,
                  "minor": minor},
        # The hub is sized from the rim, so it is never under the floor either, and stands past it.
        "hub": {"centre": off(at, f, wheel_out), "axis": f, "radius": 2 * minor, "length": 3 * minor},
        "reach": wheel_out + 1.5 * minor,
        "span": VALVE_WHEEL[0] * radius + minor,
    }


# THE CABLE TRAY'S PIECES (#834): a ladder tray, two side rails with rungs between them, resting on
# a bracket at each point it is given. The rail stands TRAY_RAIL_H of the tray's width tall, from
# the rungs' underside, and TRAY_RAIL_T thick; a rung is TRAY_RUNG (width along the run, thickness)
# and a bracket TRAY_BRACKET (width along the run, height). A loom lies TRAY_CLEAR above the bed.
TRAY_RAIL_H = 0.4
TRAY_RAIL_T = 0.025
TRAY_RUNG = (0.06, 0.025)
TRAY_BRACKET = (0.06, 0.06)
TRAY_CLEAR = 0.005


def tray_layout(name, points, width, rung_pitch=None):
    """Where a ladder cable tray's pieces go, running straight between `points`, which are its
    bed: the rungs' top face, where a loom lies, along the middle of the tray. `width` is the
    clear width between the rails.

    STRAIGHT LENGTHS, BENDS MITRED, which is how a ladder tray is put together: a bend is a fitting
    between two straight lengths. Each rail is a section at each point -- inner bottom, outer
    bottom, outer top, inner top -- and at an inner point the section stands on the bisector of the
    two lengths' sides, so the rail's faces meet there. The rungs restart on each length, each in
    the middle of its own share of it as `row` spaces them, at the pitch the length divides into
    nearest `rung_pitch`; the tray's width when it is not given. A length that climbs straight up
    has no side for the rails to stand on and is refused.

    THE READ IS THE GAP BETWEEN RUNGS, on the cut floor, since it is the open run of rungs that tells a
    tray from a trough, and THE RAIL'S HEIGHT, on the raised floor, since the rails are its edges.
    Both are checked here, by name. Returns the rails, the rungs and brackets with their centres,
    their directions along and across and their sizes in those two and up, `bed`, the points, the
    two reads, and `run`, the points and half the tray's outer width, which is what the
    footprint-edge check reads."""
    pitch = width if rung_pitch is None else rung_pitch
    rail_h = TRAY_RAIL_H * width
    check_detail(f"{name} (rail height)", rail_h)
    pts = [tuple(p) for p in points]
    legs = []
    for a, b in zip(pts, pts[1:]):
        d = _unit(tuple(b[j] - a[j] for j in range(3)))
        left = d and _unit(_cross((0.0, 0.0, 1.0), d))
        if left is None:
            sys.exit(f"cable tray: {name} has a length from {a} to {b} that runs straight up, or none, "
                     f"so its rails have no side to stand on.")
        legs.append((a, b, d, left, _cross(d, left)))

    def mitre(i):
        """The side and up at point i: a length's own at an end, the bisector's at a bend, the side
        scaled so each rail face stands its own distance off both lengths."""
        if i == 0 or i == len(pts) - 1:
            _, _, _, left, up = legs[min(i, len(legs) - 1)]
            return left, up
        l1, l2 = legs[i - 1][3], legs[i][3]
        m = _unit(tuple(x + y for x, y in zip(l1, l2)))
        k = sum(x * y for x, y in zip(m, l1))
        up = _unit(tuple(x + y for x, y in zip(legs[i - 1][4], legs[i][4])))
        return tuple(c / k for c in m), up

    def at(p, left, up, s, u):
        return tuple(p[j] + s * left[j] + u * up[j] for j in range(3))

    bot, top = -TRAY_RUNG[1], -TRAY_RUNG[1] + rail_h
    half = width / 2
    rails = [[], []]
    for i, p in enumerate(pts):
        left, up = mitre(i)
        for r, sign in zip(rails, (-1, 1)):
            inner, outer = sign * half, sign * (half + TRAY_RAIL_T)
            r.append([at(p, left, up, inner, bot), at(p, left, up, outer, bot),
                      at(p, left, up, outer, top), at(p, left, up, inner, top)])

    rungs, gaps = [], []
    across = width + 2 * TRAY_RAIL_T
    for a, b, d, left, up in legs:
        length = math.dist(a, b)
        n = max(1, round(length / pitch))
        gaps.append(length / n - TRAY_RUNG[0])
        for k in range(n):
            c = tuple(a[j] + (b[j] - a[j]) * (k + 0.5) / n for j in range(3))
            rungs.append({"centre": at(c, left, up, 0.0, -TRAY_RUNG[1] / 2), "along": d, "across": left,
                          "size": (TRAY_RUNG[0], across, TRAY_RUNG[1])})
    gap = min(gaps)
    check_detail(f"{name} (gap between rungs)", gap, cut=True)

    brackets = []
    for i, p in enumerate(pts):
        a, b, d, left, up = legs[min(i, len(legs) - 1)]
        inset = TRAY_BRACKET[0] / 2 if i == 0 else -TRAY_BRACKET[0] / 2 if i == len(pts) - 1 else 0.0
        c = tuple(p[j] + inset * d[j] for j in range(3))
        brackets.append({"centre": at(c, left, up, 0.0, -TRAY_RUNG[1] - TRAY_BRACKET[1] / 2),
                         "along": d, "across": left, "size": (TRAY_BRACKET[0], across, TRAY_BRACKET[1])})
    return {"name": name, "rails": rails, "rungs": rungs, "brackets": brackets, "bed": pts,
            "gap": gap, "rail_h": rail_h, "width": width, "run": (pts, half + TRAY_RAIL_T)}


def tray_lie(tray, half):
    """The points a loom of half-width `half` follows lying in `tray` from `tray_layout`: its bed
    lifted by the half-width and TRAY_CLEAR, so the cables rest on the rungs without sharing their
    face. A loom wider than the tray is refused, naming the tray."""
    if 2 * half > tray["width"] + 1e-9:
        sys.exit(f"cable tray: a loom {2 * half:g} wide is wider than {tray['name']}, whose rails stand "
                 f"{tray['width']:g} apart.")
    return [(p[0], p[1], p[2] + half + TRAY_CLEAR) for p in tray["bed"]]


# THE GRATING DECK'S PIECES (#835): bars DECK_BAR (width, depth) at a pitch, and a toe board
# DECK_TOE (height above the top face, thickness) standing on an open edge.
DECK_BAR = (0.06, 0.06)
DECK_TOE = (0.08, 0.02)
DECK_EDGES = ("+X", "-X", "+Y", "-Y")


def deck_layout(name, centre, size, z, pitch=0.45, bar=DECK_BAR, along="X", openings=(), open_edges=(),
                marked_edges=()):
    """Where a grating deck's pieces go: a rectangle `size` (x, y) about `centre` (x, y), its top
    face at `z`, of bars running along `along` and spaced across it.

    THE EDGE BARS ARE FLUSH TO THE EDGES and the rest are shared out between them, at the spacing
    nearest `pitch` that divides the width evenly. Each OPENING, a rectangle ((x, y), (sx, sy)),
    cuts every bar and toe board it crosses, and a piece left shorter than a bar is wide is left
    out rather than drawn as a stub. A TOE BOARD stands on the top face along each edge in
    `open_edges`, flush to it. A WALKWAY EDGE in `marked_edges` is marked: along the bars, its
    edge bar is; across them, a nosing bar is laid along it, and the bars stop at its inner face;
    and its toe board, where it has one, is marked too, since a dark board standing on the marked
    bar's top face, along its outer edge, hid part of it from the camera (Truls, 2026-10-30, while
    #835 was implemented, recorded on #835). Edges are "+X", "-X", "+Y" and "-Y", and the bars run
    along "X" or "Y"; anything else is refused.

    THE READ IS THE GAP BETWEEN BARS, on the cut floor, since it is the open grating that tells a
    deck from a plate and keeps what is under it in view, and THE BAR'S WIDTH, on the raised floor.
    A toe board is held to the raised floor on its height. Returns the bars and the toe boards,
    each with its centre, its size in x, y and z and whether it is marked, and the gap."""
    for e in tuple(open_edges) + tuple(marked_edges):
        if e not in DECK_EDGES:
            sys.exit(f"grating deck: {name} names an edge {e!r}; an edge is one of {', '.join(DECK_EDGES)}.")
    if along not in ("X", "Y"):
        sys.exit(f"grating deck: {name}'s bars run along {along!r}; a deck's bars run along \"X\" or \"Y\".")
    bw, bd = bar
    check_detail(f"{name} (bar width)", bw)
    if open_edges:
        check_detail(f"{name} (toe board)", DECK_TOE[0])
    iu = 0 if along == "X" else 1
    iv = 1 - iu
    su, sv = size[iu], size[iv]
    n = max(2, round((sv - bw) / pitch) + 1)
    step = (sv - bw) / (n - 1)
    gap = step - bw
    check_detail(f"{name} (gap between bars)", gap, cut=True)

    def piece(cu, cv, lu, lv, cz, dz, **extra):
        """A box in the deck's own (u, v), turned back into x and y and moved to the centre."""
        c, s = [0.0, 0.0], [0.0, 0.0]
        c[iu], c[iv], s[iu], s[iv] = cu, cv, lu, lv
        return dict({"centre": (centre[0] + c[0], centre[1] + c[1], cz), "size": (s[0], s[1], dz)}, **extra)

    holes = []
    for (ox, oy), (ux, uy) in openings:
        o, h = (ox - centre[0], oy - centre[1]), (ux / 2, uy / 2)
        holes.append(((o[iu] - h[iu], o[iu] + h[iu]), (o[iv] - h[iv], o[iv] + h[iv])))

    def cut(lo, hi, across, width, run):
        """The parts of [lo, hi] along `run` (0 for u, 1 for v) that no opening crosses, for a
        piece `width` wide centred at `across` on the other axis; none shorter than a bar."""
        spans = [(lo, hi)]
        for h in holes:
            a, b = h[run]
            c0, c1 = h[1 - run]
            if across + width / 2 <= c0 or across - width / 2 >= c1:
                continue
            spans = [p for s0, s1 in spans for p in ((s0, min(s1, a)), (max(s0, b), s1)) if p[1] > p[0]]
        return [(a, b) for a, b in spans if b - a >= bw - 1e-9]

    bar_z = z - bd / 2
    bars = []
    # A bar stops at a nosing bar's inner face, so its end meets that face and neither its top nor
    # its bottom face lies in the nosing bar's.
    lo = -su / 2 + (bw if f"-{'XY'[iu]}" in marked_edges else 0.0)
    hi = su / 2 - (bw if f"+{'XY'[iu]}" in marked_edges else 0.0)
    for k in range(n):
        v = -sv / 2 + bw / 2 + k * step
        edge = (k == 0 and f"-{'XY'[iv]}" in marked_edges) or (k == n - 1 and f"+{'XY'[iv]}" in marked_edges)
        for a, b in cut(lo, hi, v, bw, 0):
            bars.append(piece((a + b) / 2, v, b - a, bw, bar_z, bd, marked=bool(edge)))
    for sign in (-1, 1):
        if f"{'+' if sign > 0 else '-'}{'XY'[iu]}" in marked_edges:
            u = sign * (su / 2 - bw / 2)
            for a, b in cut(-sv / 2, sv / 2, u, bw, 1):
                bars.append(piece(u, (a + b) / 2, bw, b - a, bar_z, bd, marked=True))

    th, tt = DECK_TOE
    toes = []
    for e in open_edges:
        sign = 1 if e[0] == "+" else -1
        m = e in marked_edges
        if "XY".index(e[1]) == iu:                # an edge across the bars: the board runs along v
            u = sign * (su / 2 - tt / 2)
            toes += [piece(u, (a + b) / 2, tt, b - a, z + th / 2, th, marked=m)
                     for a, b in cut(-sv / 2, sv / 2, u, tt, 1)]
        else:                                     # along the bars: the board runs along u
            v = sign * (sv / 2 - tt / 2)
            toes += [piece((a + b) / 2, v, b - a, tt, z + th / 2, th, marked=m)
                     for a, b in cut(-su / 2, su / 2, v, tt, 0)]
    return {"bars": bars, "toe_boards": toes, "gap": gap, "pitch": step}


# THE ACCESS LADDER'S PIECES (#836): stiles LADDER_WIDTH apart between centres, each LADDER_STILE
# (width across the access ladder, depth along its facing); rungs LADDER_RUNG thick at a pitch; a cage
# LADDER_CAGE (hoop radius, the diameter of a hoop's and a bar's tube) from LADDER_CAGE_FROM above
# the foot, a hoop every LADDER_CAGE_EVERY rungs, with a bar at each of LADDER_CAGE_BARS, angles
# from the facing; and where it stands off what it is against, a bracket back to it from each stile
# every LADDER_BRACKET_EVERY rungs.
LADDER_WIDTH = 0.4
LADDER_STILE = (0.06, 0.04)
LADDER_RUNG = 0.06
LADDER_PITCH = 0.25
LADDER_CAGE = (0.3, 0.06)
LADDER_CAGE_FROM = 1.0
LADDER_CAGE_EVERY = 2
LADDER_CAGE_BARS = (-math.pi / 2, 0.0, math.pi / 2)
LADDER_HOOP_POINTS = 13
LADDER_BRACKET_EVERY = 4


def ladder_layout(name, foot, top, facing, pitch=LADDER_PITCH, rung=LADDER_RUNG, cage_from=None, standoff=0.0):
    """Where an access ladder's pieces go: straight up from `foot`, the middle of its base between
    the stiles, to the height `top`, facing out along `facing` from what it stands against.

    The facing loses any rise; one straight up is refused, since it leaves no side to face. The
    stiles stand either side, square to it. A rung stands at each `pitch` above the foot up to the
    top, from stile to stile. From `cage_from` over the foot, LADDER_CAGE_FROM unless it is given,
    a hoop stands midway between two rungs, the first such height at or over it and then every
    LADDER_CAGE_EVERY rungs up to the top, so no hoop stands on a rung whatever the pitch: an arc
    from one stile out round the facing side to the other, on a circle through both stiles. Bars on
    that circle run from the first hoop to the last, so none ends in the air; a cage of one hoop
    has none. No hoop stands above the top, so an access ladder shorter than its cage height has
    none. Where it stands `standoff` off what it is against, a bracket runs back that far from each
    stile, the first midway between the foot and the first rung, then every LADDER_BRACKET_EVERY
    rungs, midway between two.

    THE READ IS THE RUNG'S THICKNESS, on the raised floor, and THE GAP BETWEEN RUNGS, on the cut
    floor, since an evenly broken run of bars is what tells an access ladder from a plate; a hoop's
    and a bar's tube is held to the raised floor too. Returns the facing and side, the stiles, the
    rungs, each hoop as its points from the first stile to the second, each bar as its bottom and
    top, the brackets, and the gap."""
    f = _unit((facing[0], facing[1], 0.0))
    if f is None:
        sys.exit(f"access ladder: {name} faces {tuple(facing)}, straight up or nowhere; an access ladder faces out "
                 f"level from what it stands against.")
    if top <= foot[2] + 1e-9:
        sys.exit(f"access ladder: {name}'s top, {top:g}, is not above its foot, {foot[2]:g}.")
    check_detail(f"{name} (rung)", rung)
    check_detail(f"{name} (gap between rungs)", pitch - rung, cut=True)
    radius, tube = LADDER_CAGE
    check_detail(f"{name} (cage)", tube)
    side = (-f[1], f[0], 0.0)
    hw = LADDER_WIDTH / 2

    def at(along, across, z):
        return (foot[0] + along * f[0] + across * side[0], foot[1] + along * f[1] + across * side[1], z)

    height = top - foot[2]
    stiles = [{"centre": at(0.0, s * hw, foot[2] + height / 2), "height": height,
               "size": (LADDER_STILE[1], LADDER_STILE[0]), "yaw": math.atan2(f[1], f[0])} for s in (-1, 1)]
    n = int(height / pitch + 1e-9)
    rungs = [{"centre": at(0.0, 0.0, foot[2] + k * pitch), "length": LADDER_WIDTH, "axis": side}
             for k in range(1, n + 1)]

    base = foot[2] + (LADDER_CAGE_FROM if cage_from is None else cage_from)
    d = math.sqrt(radius ** 2 - hw ** 2)
    end = math.pi - math.atan2(hw, d)
    hoops = []
    z = foot[2] + (math.ceil((base - foot[2]) / pitch - 0.5 - 1e-9) + 0.5) * pitch
    while z <= top + 1e-9:
        hoops.append([at(d + radius * math.cos(t), radius * math.sin(t), z)
                      for t in (-end + 2 * end * k / (LADDER_HOOP_POINTS - 1) for k in range(LADDER_HOOP_POINTS))])
        z += LADDER_CAGE_EVERY * pitch
    bars = []
    if len(hoops) > 1:
        for t in LADDER_CAGE_BARS:
            u, v = d + radius * math.cos(t), radius * math.sin(t)
            bars.append((at(u, v, hoops[0][0][2]), at(u, v, hoops[-1][0][2])))
    brackets = []
    if standoff > 0:
        back = (-f[0], -f[1], 0.0)
        z = foot[2] + pitch / 2
        while z <= top + 1e-9:
            brackets += [{"centre": at(-standoff / 2, s * hw, z), "length": standoff, "axis": back}
                         for s in (-1, 1)]
            z += LADDER_BRACKET_EVERY * pitch
    return {"facing": f, "side": side, "stiles": stiles, "rungs": rungs, "hoops": hoops, "bars": bars,
            "brackets": brackets, "gap": pitch - rung}


# A LIFTING LUG'S PROPORTIONS (#837), as fractions of its width: the eye's diameter LUG_EYE, the
# plate's thickness LUG_THICK and the eye's centre LUG_CENTRE above the base. Its top is a half disc
# of half the width, concentric with the eye. LUG_POINTS rays from the eye's centre trace it.
LUG_EYE = 0.45
LUG_THICK = 0.3
LUG_CENTRE = 0.8
LUG_POINTS = 32


def lug_layout(name, size, placements):
    """A lifting lug's outline and how close neighbouring lugs stand: a plate `size` wide standing
    on its own origin, its face square to its own X, so a ring's outward placements turn each to
    face out, with an eye through it.

    The outline is traced along rays from the eye's centre: `inner` on the eye, `outer` on the
    plate's edge along the same ray, a half disc of half the width above the eye's centre and the
    rectangle's sides and base below it, the base's two corners included. Each pair is in the
    plate's own (across, up).

    THE READ IS THE EYE'S DIAMETER, on the cut floor, since the eye is the hole that tells a lug from
    a tab, and THE PLATE'S THICKNESS, on the raised floor. Both scale with the width, and at these
    proportions the plate's floor is the one that binds: it refuses any lug narrower than 0.2,
    while the eye would hold down to about 0.11. The eye is checked all the same, so a change to
    LUG_EYE or LUG_THICK cannot let it under its floor. Neighbouring lugs, measured from the lugs as
    placed by `least_gap`, stand apart by the cut floor, as bolts do. Returns the outline, the eye,
    the thickness, the height and the gap, None for one lug."""
    half, eye, thick, ec = size / 2, LUG_EYE * size, LUG_THICK * size, LUG_CENTRE * size
    check_detail(f"{name} (eye)", eye, cut=True)
    check_detail(f"{name} (plate thickness)", thick)
    corners = [math.atan2(-ec, half), math.atan2(-ec, -half) % (2 * math.pi)]
    angles = sorted({round(2 * math.pi * k / LUG_POINTS, 12) for k in range(LUG_POINTS)}
                    | {round(a % (2 * math.pi), 12) for a in corners})
    inner, outer = [], []
    for t in angles:
        c, s = math.cos(t), math.sin(t)
        inner.append((eye / 2 * c, ec + eye / 2 * s))
        if s >= -1e-12:
            outer.append((half * c, ec + half * s))
        else:
            reach = min(half / abs(c) if abs(c) > 1e-12 else math.inf, ec / -s)
            outer.append((reach * c, ec + reach * s))
    pts = [(x, u, z) for u, z in outer for x in (-thick / 2, thick / 2)]
    gap = least_gap(pts, placements)
    if gap is not None:
        check_detail(f"{name} (gap)", gap, cut=True)
    return {"inner": inner, "outer": outer, "eye": eye, "thick": thick, "height": ec + half, "gap": gap}


WARNING_PLATE_MAX = 0.8          # the longest side a warning plate may have: a small element
WARNING_PLATE_DEPTH = (-0.02, 0.02)   # its back and its front, off the face it is placed on


def _clip(poly, k, lo):
    """The part of convex `poly` where coordinate u + v, times `k`, is at least `lo` * `k`."""
    out = []
    for a, b in zip(poly, poly[1:] + poly[:1]):
        fa, fb = k * (a[0] + a[1] - lo), k * (b[0] + b[1] - lo)
        if fa >= 0:
            out.append(a)
        if fa * fb < 0:
            t = fa / (fa - fb)
            out.append((a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])))
    return out


def warning_plate_layout(name, size, stripes):
    """A warning plate's bands: the rectangle `size` (u, v) about its own centre, cut along u + v
    into `2 * stripes + 1` bands of one width, the plate's role at each end and a stripe between
    each two, so `stripes` stripes cross it at 45 degrees. Each band is a convex outline in the
    face's (u, v) and whether it is a stripe.

    THE READ IS A STRIPE'S WIDTH, square to the stripe, on the raised floor: the stripes are what
    tell a warning plate from a yellow patch. No side may be longer than WARNING_PLATE_MAX, since a
    marking is a small element and never a panel (`models/house-style.md`, Palette). The plate
    stands from WARNING_PLATE_DEPTH's back to its front off the face, its back set into the face so
    it sits on one that is not quite flat. Returns the bands, the stripe's width and the depth."""
    u, v = size
    if max(u, v) > WARNING_PLATE_MAX + 1e-9:
        sys.exit(f"warning plate: {name} is {u:g} by {v:g}, larger than a small element: no side may "
                 f"be longer than {WARNING_PLATE_MAX:g}. A marking is never a panel. "
                 f"See models/house-style.md, Palette.")
    if stripes < 1:
        sys.exit(f"warning plate: {name} has no stripe, and its stripes are what it reads by.")
    n = 2 * stripes + 1
    step = (u + v) / n
    width = check_detail(f"{name} (stripe width)", step / math.sqrt(2))
    rect = [(-u / 2, -v / 2), (u / 2, -v / 2), (u / 2, v / 2), (-u / 2, v / 2)]
    bands = []
    for k in range(n):
        lo = -(u + v) / 2 + k * step
        bands.append({"outline": _clip(_clip(rect, 1, lo), -1, lo + step), "stripe": k % 2 == 1})
    return {"bands": bands, "stripe_width": width, "depth": WARNING_PLATE_DEPTH}


class Stream(random.Random):
    """One part's own random stream: `random.Random` with the one draw the models make most."""

    def jitter(self, v, s):
        """`v` moved by up to `s` either way."""
        return v + self.uniform(-s, s)


def stream(seed, name):
    """The random stream a part named `name` draws its imperfections from, on a machine built with
    `seed` (#825). rf_parts.stream hands these out, one per name for the whole build.

    A PART'S IMPERFECTIONS DEPEND ON ITS NAME ALONE. They used to come from one global `random`
    seeded once per build, in build order, so a part added early moved every draw after it: on
    #824 a guard rail laid in lengths re-rolled the drums and the handwheels, and a handwheel rim
    landed on a bay's plates. Seeded from the name, a part keeps its values whatever is built
    before it, after it or instead of it.

    THE SEED IS A HASH, NOT `random.Random(str)`. Both are stable, but this one says what it does
    without leaning on how `random` turns a string into a number. models/test_rf_blender.py pins a
    draw from it under the system's Python; Blender 5.2.0's gave the same number when it was read
    by hand, and nothing holds a later Blender to it.
    """
    digest = hashlib.sha256(f"{seed}/{name}".encode("utf-8")).digest()
    return Stream(int.from_bytes(digest, "big"))


def geometry_sha256(path):
    """The hash build scripts stamp on a scene and render.py checks it against. Over the canonical
    JSON text, not the file's bytes: a checkout with autocrlf turns the extractor's LF into CRLF and
    a byte hash then refuses a model whose geometry has not moved at all (#251 hit it)."""
    with open(path, encoding="utf-8") as f:
        return hashlib.sha256(json.dumps(json.load(f), sort_keys=True).encode()).hexdigest()


# A CC0 IMAGE TEXTURE MAY BE IMPORTED, AND NOTHING ELSE MAY (ADR 0043, #805). It lives in the model's
# own directory, so a build reads the same bytes on every machine and needs no network, and it is
# recorded in that directory's textures.json under its file name: the page it came from, its
# licence and the sha256 of the file as it was fetched. `rf_parts.texture` loads one only through
# `texture_record`, render.py holds every image a stored model names to it, and
# scripts/ship-check.ps1 section 18 holds every file in a model directory to the same record, so a
# texture with no provenance fails a gate before it reaches a sheet.
#
# AN IMAGE, BY ITS EXTENSION. A mesh is refused whatever its record says, which is what keeps this
# path from importing one: ADR 0043 allows CC0 textures and still bans meshes, CC0 or not.
TEXTURE_RECORDS = "textures.json"
TEXTURE_EXTENSIONS = (".jpg", ".jpeg", ".png")
TEXTURE_LICENCE = "CC0-1.0"


def texture_record(model_dir, filename):
    """The provenance record of the texture `filename` in `model_dir`, or an exit naming what is
    wrong: not an image, no textures.json, no file, no record, a licence that is not CC0, a source
    that is not an https page, or bytes that are not the ones recorded."""
    where = f"{os.path.basename(os.path.normpath(model_dir))}/{filename}"
    if os.path.splitext(filename)[1].lower() not in TEXTURE_EXTENSIONS:
        sys.exit(f"texture: {where} is not an image ({', '.join(TEXTURE_EXTENSIONS)}). ADR 0043 allows "
                 f"CC0 image textures and no meshes; every shape is built by a script.")
    records_path = os.path.join(model_dir, TEXTURE_RECORDS)
    if not os.path.exists(records_path):
        sys.exit(f"texture: {where} has no {TEXTURE_RECORDS} beside it to record where it came from.")
    path = os.path.join(model_dir, filename)
    if not os.path.exists(path):
        sys.exit(f"texture: {where} is not on disk; a texture is kept in its model's own directory.")
    with open(records_path, encoding="utf-8") as f:
        record = json.load(f).get(filename)
    if not isinstance(record, dict):
        sys.exit(f"texture: {where} has no record in {TEXTURE_RECORDS}.")
    if record.get("licence") != TEXTURE_LICENCE:
        sys.exit(f"texture: {where} is recorded as {record.get('licence')!r}; only {TEXTURE_LICENCE} "
                 f"may be imported (ADR 0043).")
    if not str(record.get("source", "")).startswith("https://"):
        sys.exit(f"texture: {where}'s source is {record.get('source')!r}; record the https page it "
                 f"was fetched from.")
    with open(path, "rb") as f:
        digest = hashlib.sha256(f.read()).hexdigest()
    if record.get("sha256") != digest:
        sys.exit(f"texture: {where}'s sha256 is {digest}, not the {record.get('sha256')!r} recorded; "
                 f"the file is not the one its record describes.")
    return record


def script_args():
    argv = sys.argv
    return argv[argv.index("--") + 1:] if "--" in argv else []


def frame_px(tiles_w, tiles_h, margin=MARGIN_TILES):
    """Sheet size in px: the footprint plus the margin on every side, at 64 px per tile."""
    return (int(round((tiles_w + 2 * margin) * PX_PER_TILE)),
            int(round((tiles_h + 2 * margin) * PX_PER_TILE)))


def png_rgba(image_settings):
    image_settings.media_type = "IMAGE"   # 5.x: before file_format
    image_settings.file_format = "PNG"
    image_settings.color_mode = "RGBA"
    image_settings.color_depth = "8"


def set_frame(scene, width_px, height_px, width_tiles):
    """Aim the frame: `width_px` x `height_px` pixels covering `width_tiles` of ground across.
    The pixel aspect squares the ground; sensor_fit HORIZONTAL makes ortho_scale the frame width
    whatever the aspect, so one tile is always width_px / width_tiles pixels across."""
    scene.render.resolution_x, scene.render.resolution_y = width_px, height_px
    scene.render.resolution_percentage = 100
    scene.render.pixel_aspect_x, scene.render.pixel_aspect_y = STRETCH, 1.0
    scene.camera.data.sensor_fit = "HORIZONTAL"
    scene.camera.data.ortho_scale = width_tiles


def ground_report(ground):
    """What `build_rig`'s Ground plane is configured as, and what the running Blender says each of
    those flags MEANS, as a list of lines for a caller to print one by one.

    THE DESCRIPTIONS ARE THE RUNNING BUILD'S OWN, not a manual page quoted from memory (#366). A
    shadow catcher is documented as rendering transparent, so whether it occludes anything in the
    beauty pass is a question about how the object is configured as much as about where the geometry
    is -- and the answer differs by version. Reading `bl_rna` makes the report and the renderer the
    same statement.

    ONE COPY, because the two callers are a throwaway builder each: models/socket-cylinders.py builds a
    scene from nothing and models/socket-variants.py opens a shipped machine, and both delete this
    plane to measure what it was hiding. It lives here because this is the file that puts the plane
    in the scene.
    """
    import bpy
    # THE NAMES COME OFF bl_rna RATHER THAN OFF dir(), because `dir()` on an object also lists its
    # METHODS -- `visible_get` among them -- and asking bl_rna for one of those is a KeyError rather
    # than an empty description. The first version of this did exactly that.
    rna = bpy.types.Object.bl_rna.properties
    flags = ["is_shadow_catcher", "is_holdout"] + sorted(
        k for k in rna.keys() if k.startswith("visible_"))
    lines = [f"Ground, under blender {bpy.app.version_string}:"]
    for a in flags:
        lines.append(f"    {a} = {getattr(ground, a)!r}  -- {rna[a].description}")
    return lines


def build_rig(scene, tiles_w, tiles_h, icon_centre, icon_tiles, margin=MARGIN_TILES, icon_yaw=0.0):
    """Ground, camera, sun and world, with the camera and sun parented to one empty ("Rig") that
    render.py turns per direction. Records on the scene what render.py needs: the footprint, the
    margin and the icon window (a point the icon camera centres on and the width it frames)."""
    import bpy
    bpy.ops.mesh.primitive_plane_add(size=200)
    ground = bpy.context.object
    ground.name = "Ground"
    ground.is_shadow_catcher = True

    rig = bpy.data.objects.new("Rig", None)
    scene.collection.objects.link(rig)

    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    scene.collection.objects.link(cam)
    cam.parent = rig
    pitch = math.radians(CAMERA_PITCH_DEG)
    d = 56.0
    cam.location = (0, -d * math.cos(pitch), d * math.sin(pitch))
    cam.rotation_euler = (math.pi / 2 - pitch, 0, 0)
    cam.data.type = "ORTHO"
    cam.data.clip_end = 200
    scene.camera = cam

    sun_data = bpy.data.lights.new("Sun", type="SUN")
    sun_data.energy = 4.0
    sun_data.angle = math.radians(0.5)       # sharp shadows (posila)
    sun = bpy.data.objects.new("Sun", sun_data)
    scene.collection.objects.link(sun)
    sun.parent = rig
    sun.location = (0, 0, 20)
    # A sun lights along local -Z. Rotating about Y by -(90-elev) tips that toward +X: light
    # travels east, shadows fall east, no north-south component (the pole measurement).
    sun.rotation_euler = (0, -math.radians(90 - SUN_ELEVATION_DEG), 0)

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.6, 0.65, 0.75, 1.0)
    bg.inputs["Strength"].default_value = 0.35
    scene.world = world

    w, h = frame_px(tiles_w, tiles_h, margin)
    set_frame(scene, w, h, tiles_w + 2 * margin)
    scene["rf_tiles"] = [tiles_w, tiles_h]
    scene["rf_margin_tiles"] = margin
    scene["rf_icon_centre"] = list(icon_centre)
    scene["rf_icon_tiles"] = icon_tiles
    # Degrees the rig turns for the ICON only, so an oblong machine can run corner to corner in a
    # square instead of as a hairline down the middle. Zero for anything roughly square, which is
    # then the same view as its north sheet. The sun is on the rig, so it turns too and the icon
    # stays lit like every sheet.
    scene["rf_icon_yaw"] = float(icon_yaw)
    return rig

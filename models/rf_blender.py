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
    read, nor is anything that is not handed over as a run -- a horizontal `cyl` or a `box`, which is
    what a cable tray is likely to be built from. A kit part that is pipe-shaped and not built by
    `rf_parts.pipe` calls this itself, with its points in the DECLARED frame: rf-heat-exchanger is
    built in another one and turned, which is why `rf_parts` checks its runs at save.
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


def bundle(points, n, spread, twist=0.0):
    """`n` strands laid round the centreline `points`, each point `spread` off it and square to the
    run at that point. Strand k starts at angle 2 pi k / n and turns by `twist` radians per control
    point, so a twisted bundle winds instead of lying parallel. One strand is the centreline itself.

    THE RUN'S DIRECTION AT A POINT is the chord from the point before it to the point after it, so a
    bend is split between its two legs. The "side" a strand is offset along is that direction
    crossed with up, and a vertical stretch, which has no such side, takes east instead; so a loom
    that climbs straight up a post still spreads, round the post's axis."""
    if n == 1:
        return [list(points)]
    strands = [[] for _ in range(n)]
    for i, p in enumerate(points):
        a, b = points[max(i - 1, 0)], points[min(i + 1, len(points) - 1)]
        d = _unit(tuple(b[j] - a[j] for j in range(3)))
        side = _unit(_cross(d, (0.0, 0.0, 1.0))) or _unit(_cross(d, (1.0, 0.0, 0.0)))
        up = _cross(side, d)
        for k in range(n):
            t = 2 * math.pi * k / n + twist * i
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


def check_gap(name, gap, depth):
    """Refuse a gap between repeated parts that would not read. It reads like a cut, by the shadow
    in it, so it is held to the cut floor on its width and must run at least as deep as it is
    wide, the house style's rule for a groove."""
    check_detail(f"{name} (gap)", gap, cut=True)
    if depth < gap - 1e-9:
        sys.exit(f"repeated module: {name}'s gaps are {gap:g} wide and {depth:g} deep. A gap is cut at "
                 f"least as deep as it is wide, or its shadow line is too weak to read. "
                 f"See models/house-style.md, Proportion and detail.")


def casing_arc(n, radius, gap):
    """The arc, in radians, each of `n` casing segments round `radius` spans when neighbours stand
    `gap` tiles apart along the circumference."""
    return 2 * math.pi / n - gap / radius


def geometry_sha256(path):
    """The hash build scripts stamp on a scene and render.py checks it against. Over the canonical
    JSON text, not the file's bytes: a checkout with autocrlf turns the extractor's LF into CRLF and
    a byte hash then refuses a model whose geometry has not moved at all (#251 hit it)."""
    with open(path, encoding="utf-8") as f:
        return hashlib.sha256(json.dumps(json.load(f), sort_keys=True).encode()).hexdigest()


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

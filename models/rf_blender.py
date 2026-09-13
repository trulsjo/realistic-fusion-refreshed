"""The shared Factorio rig and frame, imported from inside Blender's Python by every build script
and by render.py. Blender does not put a --python script's directory on sys.path; callers insert
this file's directory themselves. Only `build_rig` and `accent` touch bpy, so the constants and the
frame arithmetic import under system Python for models/test_rf_blender.py.

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

# House-style accent per fluid. The geometry file carries the fluid name (#248); the accent is
# ours. An unlisted fluid is an error rather than a guess, because an unaccented socket lies about
# what it carries -- with ONE exception, `accent`'s plasma fallback, which is a substring match and
# therefore is a guess. It is deliberate (every plasma shares one accent, ADR 0010's four of them
# included) and it is the one place a future fluid could be accented by accident: anything with
# "plasma" in its name is taken to be one.
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

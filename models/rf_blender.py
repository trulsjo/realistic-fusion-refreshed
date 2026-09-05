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
import hashlib
import json
import math
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
# ours. Anything else is an error rather than a guess: an unaccented socket lies about its fluid.
ACCENT_OF_FLUID = {
    "rf-reactor-energy": "energy",
    "rf-aneutronic-reactor-energy": "energy",
    "steam": "steam",
    "water": "water",
}


def accent(fluid):
    if fluid in ACCENT_OF_FLUID:
        return ACCENT_OF_FLUID[fluid]
    if "plasma" in fluid:
        return "plasma"
    sys.exit(f"no house-style accent for fluid {fluid!r}; add it to rf_blender.ACCENT_OF_FLUID")


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

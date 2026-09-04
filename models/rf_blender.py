"""PROTOTYPE (#246): the shared Factorio rig and frame, imported from inside Blender's Python.

Blender does not put a --python script's directory on sys.path; callers insert this file's
directory themselves. Camera and light follow docs/research/factorio-render-camera.md:
orthographic, pitched 45 deg, looking north (+Y); one hard sun from the west (-X) at about 42 deg
elevation so shadows fall east; a grey world for ambient fill. The vertical factor (construction
A: stretch screen-Y by sqrt 2) is applied AFTER rendering, in post.py, so the render itself stays
pixel-exact on the ground's x axis.
"""
import math
import sys

PX_PER_TILE = 64
MARGIN_TILES = 2.0      # room for the height above the north edge and the shadow to the east
STRETCH = math.sqrt(2)  # construction A


def script_args():
    argv = sys.argv
    return argv[argv.index("--") + 1:] if "--" in argv else []


def png_rgba(image_settings):
    image_settings.media_type = "IMAGE"   # 5.x: before file_format
    image_settings.file_format = "PNG"
    image_settings.color_mode = "RGBA"
    image_settings.color_depth = "8"


def frame_px(tiles_w, tiles_h, margin=MARGIN_TILES):
    """Final sheet size in px after the vertical stretch, and the pre-stretch render size."""
    w = int(round((tiles_w + 2 * margin) * PX_PER_TILE))
    h = int(round((tiles_h + 2 * margin) * PX_PER_TILE))
    return (w, h), (w, int(round(h / STRETCH)))


def build_rig(scene, tiles_w, tiles_h, sun_elevation_deg=42.0):
    import bpy
    # Ground: shadow catcher, transparent otherwise.
    bpy.ops.mesh.primitive_plane_add(size=200)
    ground = bpy.context.object
    ground.name = "Ground"
    ground.is_shadow_catcher = True

    rig = bpy.data.objects.new("Rig", None)
    scene.collection.objects.link(rig)

    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    scene.collection.objects.link(cam)
    cam.parent = rig
    cam.location = (0, -40, 40)
    cam.rotation_euler = (math.radians(45), 0, 0)
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
    sun.rotation_euler = (0, -math.radians(90 - sun_elevation_deg), 0)

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.6, 0.65, 0.75, 1.0)
    bg.inputs["Strength"].default_value = 0.35
    scene.world = world

    (fw, fh), (rw, rh) = frame_px(tiles_w, tiles_h)
    scene.render.resolution_x, scene.render.resolution_y = rw, rh
    scene.render.resolution_percentage = 100
    cam.data.ortho_scale = max(rw, rh) / PX_PER_TILE   # 1 px = 1/64 tile on the ground x axis
    scene["rf_final_px"] = [fw, fh]
    return rig

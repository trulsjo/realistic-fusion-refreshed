"""Render a machine's sprite set, icon and manifest from its stored model, headless.

    blender -b models/<machine>/<machine>.blend --python models/render.py -- [--samples 64]
            [--directions 4] [--out DIR]

One command, one interpreter: everything below runs inside Blender's Python, numpy included, so
there is no second tool to install and no post-processing step to forget. Into
realistic-fusion-refreshed-assets/graphics/rendered/<machine>/ it writes the file set
graphics/mockup/pictures.lua consumes -- <machine>.png, -e, -s, -w for the structure per direction,
each with a -shadow sheet, plus a -glow sheet per direction when the model has an emissive part --
then <machine>-icon.png as the 120x64 mipmap strip (#242) and manifest.json recording the geometry
the render used, so #250 can hold it against the live prototype.

The camera is the .blend's rig (rf_blender.build_rig); this script only turns it. Direction d turns
the rig by +90 d degrees about Z, which is the camera going anticlockwise round a machine the game
turns clockwise: north, east, south, west, the order BoilerPictureSet names them. The sun is
parented to the same rig, so every sheet is lit from screen-left and shadows fall screen-right
(#239). Structure and shadow come from one render with the emissive parts switched off; the glow is
the Emission pass of a second, cheaper render with them on, under the structure's alpha. Shadow is
opaque black under the shadow catcher's alpha, unfaded: the engine blends it at 50 percent.

Deterministic: fixed seed, CPU, no stamp metadata in the PNGs, sorted manifest keys. Same model
and geometry, same bytes -- models/test_rf_blender.py cannot prove that without Blender, so #249
did by hand: two full renders, fourteen identical hashes.

Refuses a model whose geometry.json has changed since the model was built: the sockets in the
.blend came from the old file, and a sheet that lies about a connection is worse than no sheet.
"""
import argparse
import glob
import hashlib
import json
import math
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import numpy as np  # noqa: E402
import rf_blender as rf  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SUFFIX = ["", "-e", "-s", "-w"]          # BoilerPictureSet order; a generator takes the first two
ICON_SIDE, ICON_MARGIN = 64, 3          # subject fills the square to about 3 px a side (#242)
GLOW_SAMPLES_DIVISOR = 8                # emission is direct light only: noise-free at few samples
SHADOW_ALPHA_FLOOR = 0.04               # below this the shadow catcher is reporting sky occlusion

ap = argparse.ArgumentParser()
ap.add_argument("--samples", type=int, default=64)
ap.add_argument("--directions", type=int, default=4, choices=(1, 2, 4))
ap.add_argument("--out", help="output directory; default is the assets mod's graphics/rendered/<machine>/")
args = ap.parse_args(rf.script_args())

model_path = bpy.data.filepath
if not model_path:
    sys.exit("render.py needs a saved model: blender -b models/<machine>/<machine>.blend --python models/render.py")
machine = os.path.splitext(os.path.basename(model_path))[0]
model_dir = os.path.dirname(model_path)
outdir = os.path.abspath(args.out or os.path.join(
    REPO, "realistic-fusion-refreshed-assets", "graphics", "rendered", machine))

scene = bpy.context.scene
geo_path = os.path.join(model_dir, "geometry.json")
geo_sha = rf.geometry_sha256(geo_path)
if geo_sha != scene.get("rf_geometry_sha256"):
    sys.exit(f"{machine}: geometry.json has changed since the model was built "
             f"({geo_sha[:12]} now, {str(scene.get('rf_geometry_sha256'))[:12]} in the model). "
             f"Regenerate the model (blender -b --python {model_dir}/build.py) before rendering.")
geo = json.load(open(geo_path, encoding="utf-8"))
tiles_w, tiles_h = (int(v) for v in scene["rf_tiles"])
margin = float(scene["rf_margin_tiles"])

view_layer = scene.view_layers[0]
rig = bpy.data.objects["Rig"]

# Emissive materials glow only in the glow sheet. Structure and shadow render with them off, and
# the glow renders them at rf_blender.GLOW_EMISSION whatever the model says, so the one number is
# tuned in one place and applies to every machine without a rebuild.
GLOW = [m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"]
        for m in bpy.data.materials if m.use_nodes and "Principled BSDF" in m.node_tree.nodes
        and m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value > 0]


def emission(on):
    for strength in GLOW:
        strength.default_value = rf.GLOW_EMISSION if on else 0.0


scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.seed = 0
scene.cycles.use_animated_seed = False
scene.cycles.use_denoising = True
# Blender writes Date, RenderTime and the .blend's absolute path into every PNG as text chunks
# unless the stamp flags are off. Pixels were identical across runs; those chunks were not.
for flag in [p for p in dir(scene.render) if p.startswith("use_stamp")]:
    setattr(scene.render, flag, False)
scene.render.film_transparent = True
scene.render.use_compositing = True
rf.png_rgba(scene.render.image_settings)

view_layer.use_pass_combined = True
view_layer.use_pass_emit = True
view_layer.cycles.use_pass_shadow_catcher = True

# Compositor: the wiring docs/research/blender-headless-render.md verified. One File Output node
# writes structure (combined), shadow (inverted shadow-catcher as alpha over black) and glow
# (emission under the combined alpha) from every render. The shadow alpha has its lowest few
# percent cut: the machine occludes a little of the world light for every ground point around it,
# which the shadow catcher reports as alpha 1 to 9 over most of the frame. Invisible at the
# engine's 50 percent blend, but it is not shadow and it would touch every frame edge.
work = tempfile.mkdtemp(prefix="rf-render-")
tree = bpy.data.node_groups.new("rf-passes", "CompositorNodeTree")
scene.compositing_node_group = tree
nodes, links = tree.nodes, tree.links
rl = nodes.new("CompositorNodeRLayers")
rl.layer = view_layer.name
inv = nodes.new("CompositorNodeInvert")
inv.inputs["Factor"].default_value = 1.0
links.new(rl.outputs["Shadow Catcher"], inv.inputs["Color"])
floor = nodes.new("ShaderNodeMapRange")       # 5.x: the compositor shares the shader editor's node
floor.clamp = True
floor.inputs["From Min"].default_value = SHADOW_ALPHA_FLOOR
for name, v in (("From Max", 1.0), ("To Min", 0.0), ("To Max", 1.0)):
    floor.inputs[name].default_value = v
links.new(inv.outputs["Color"], floor.inputs["Value"])
black = nodes.new("CompositorNodeSetAlpha")
black.inputs["Type"].default_value = "Replace Alpha"
black.inputs["Image"].default_value = (0, 0, 0, 1)
links.new(floor.outputs["Result"], black.inputs["Alpha"])
glow = nodes.new("CompositorNodeSetAlpha")
glow.inputs["Type"].default_value = "Replace Alpha"
links.new(rl.outputs["Emission"], glow.inputs["Image"])
links.new(rl.outputs["Alpha"], glow.inputs["Alpha"])
fo = nodes.new("CompositorNodeOutputFile")
fo.directory = work
rf.png_rgba(fo.format)
for name in ("structure", "shadow", "glow"):
    fo.file_output_items.new(socket_type="RGBA", name=name)
links.new(rl.outputs["Image"], fo.inputs["structure"])
links.new(black.outputs["Image"], fo.inputs["shadow"])
links.new(glow.outputs["Image"], fo.inputs["glow"])
out = nodes.new("NodeGroupOutput")
tree.interface.new_socket(name="Image", in_out="OUTPUT", socket_type="NodeSocketColor")
links.new(rl.outputs["Image"], out.inputs["Image"])


def render(prefix, samples, lit):
    """One render; returns {pass name: path} of what the File Output node wrote for it."""
    emission(lit)
    scene.cycles.samples = samples
    fo.file_name = prefix
    bpy.ops.render.render(write_still=False)
    found = {}
    for p in glob.glob(os.path.join(work, prefix + "*.png")):
        for name in ("structure", "shadow", "glow"):
            if name in os.path.basename(p)[len(prefix):]:
                found[name] = p
    return found


def take(src, name):
    dst = os.path.join(outdir, name)
    shutil.move(src, dst)
    files.append(name)


os.makedirs(outdir, exist_ok=True)
for stale in glob.glob(os.path.join(outdir, machine + "*.png")) + [os.path.join(outdir, "manifest.json")]:
    if os.path.exists(stale):
        os.remove(stale)
files = []

# ---- the sheets, one direction at a time ---------------------------------------------------
for d in range(args.directions):
    rig.rotation_euler[2] = math.radians(90 * d)
    w_tiles, h_tiles = (tiles_h, tiles_w) if d % 2 else (tiles_w, tiles_h)
    w_px, h_px = rf.frame_px(w_tiles, h_tiles, margin)
    rf.set_frame(scene, w_px, h_px, w_tiles + 2 * margin)
    got = render(f"d{d}-", args.samples, lit=False)
    take(got["structure"], f"{machine}{SUFFIX[d]}.png")
    take(got["shadow"], f"{machine}{SUFFIX[d]}-shadow.png")
    if GLOW:
        got = render(f"d{d}-lit-", max(4, args.samples // GLOW_SAMPLES_DIVISOR), lit=True)
        take(got["glow"], f"{machine}{SUFFIX[d]}-glow.png")

# ---- the icon: a section at the world camera, as a 120x64 mip strip --------------------------
# The rig is moved to the icon centre so the camera looks at it, and the frame narrowed to the
# icon window; the pixel aspect stays, so the icon is the same picture as the sheet, closer.
rig.rotation_euler[2] = math.radians(float(scene.get("rf_icon_yaw", 0.0)))
rig.location = tuple(scene["rf_icon_centre"])
side = ICON_SIDE - 2 * ICON_MARGIN
rf.set_frame(scene, side, side, float(scene["rf_icon_tiles"]))
# LIT, unlike every direction sheet. The sheets keep the emission out of the structure because the
# game adds the glow itself and only while the machine works; an icon is one picture and the game
# adds nothing to it, so a cold icon is a machine with its accent switched off -- which after
# GLOW_BASE_DARKEN means no accent at all, and a grey rectangle in the inventory.
got = render("icon-", args.samples, lit=True)


def pixels_top_down(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    bpy.data.images.remove(img)
    return a.reshape(h, w, 4)[::-1]                           # Blender stores rows bottom-up


def half(a):
    """Box-filter a mip level down by two, averaging premultiplied colour so edges stay clean."""
    pm = a.copy()
    pm[..., :3] *= pm[..., 3:4]
    pm = pm.reshape(a.shape[0] // 2, 2, a.shape[1] // 2, 2, 4).mean(axis=(1, 3))
    alpha = pm[..., 3:4]
    rgb = np.where(alpha > 0, pm[..., :3] / np.maximum(alpha, 1e-9), 0.0)
    return np.concatenate([rgb, alpha], axis=-1)


level = np.zeros((ICON_SIDE, ICON_SIDE, 4), dtype=np.float32)
level[ICON_MARGIN:ICON_MARGIN + side, ICON_MARGIN:ICON_MARGIN + side] = pixels_top_down(got["structure"])
strip = np.zeros((ICON_SIDE, 120, 4), dtype=np.float32)
x = 0
for size in (64, 32, 16, 8):                                    # top-aligned, left to right (#242)
    strip[:size, x:x + size] = level
    x += size
    level = half(level)
icon = bpy.data.images.new("rf-icon", 120, ICON_SIDE, alpha=True)
icon.alpha_mode = "STRAIGHT"
icon.pixels.foreach_set(np.ascontiguousarray(strip[::-1]).ravel())
icon.filepath_raw = os.path.join(outdir, f"{machine}-icon.png")
icon.file_format = "PNG"
icon.save()
files.append(f"{machine}-icon.png")
shutil.rmtree(work, ignore_errors=True)

# ---- the manifest ----------------------------------------------------------------------------
w_px, h_px = rf.frame_px(tiles_w, tiles_h, margin)
manifest = {
    "machine": machine,
    "model": os.path.relpath(model_path, REPO).replace(os.sep, "/"),
    "model_sha256": hashlib.sha256(open(model_path, "rb").read()).hexdigest(),
    "geometry": geo,
    "geometry_sha256": geo_sha,
    "frame": {
        "pixels_per_tile": rf.PX_PER_TILE, "scale": 0.5, "shift": [0, 0],
        "tiles": [tiles_w, tiles_h], "margin_tiles": margin,
        "north": [w_px, h_px], "east": [h_px, w_px],
    },
    "camera": {
        "pitch_deg": rf.CAMERA_PITCH_DEG, "ground_stretch": rf.STRETCH,
        "sun_elevation_deg": rf.SUN_ELEVATION_DEG, "sun_from": "west",
        "view_transform": scene.view_settings.view_transform,
    },
    "render": {
        "blender": bpy.app.version_string, "engine": "CYCLES", "device": "CPU", "seed": 0,
        "samples": args.samples, "glow_samples": max(4, args.samples // GLOW_SAMPLES_DIVISOR),
        "glow_emission": rf.GLOW_EMISSION if GLOW else None,
    },
    "directions": SUFFIX[:args.directions],
    "glow": bool(GLOW),
    "icon": {"file": f"{machine}-icon.png", "size": [120, ICON_SIDE],
             "centre": list(scene["rf_icon_centre"]), "tiles": float(scene["rf_icon_tiles"]),
             "yaw_deg": float(scene.get("rf_icon_yaw", 0.0))},
    "files": sorted(files),
    "source": "written by models/render.py",
}
with open(os.path.join(outdir, "manifest.json"), "w", encoding="utf-8", newline="\n") as f:
    json.dump(manifest, f, indent=2, sort_keys=True)
    f.write("\n")
print("RENDERED", machine, "->", outdir, sorted(files))

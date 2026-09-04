"""Render structure, shadow, glow and icon from one .blend, headless.

    blender -b <scene.blend> --python render_passes.py -- <outdir> [samples] [directions]

Writes into <outdir>:
    dir<N>_structure.png  combined pass, transparent background, no ground, no shadow
    dir<N>_shadow.png     shadow only: black RGB, alpha = shadow density (draw_as_shadow)
    dir<N>_glow.png       emission pass with the combined pass's alpha (additive-ready)
    icon.png              square crop of the north structure via the render region
The three passes come out of ONE render through a File Output node in the compositor;
the icon is a second, smaller render.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import rf_render  # noqa: E402

args = rf_render.script_args()
outdir = os.path.abspath(args[0])
samples = int(args[1]) if len(args) > 1 else 16
directions = int(args[2]) if len(args) > 2 else 1
denoise = (args[3].lower() == "denoise") if len(args) > 3 else False
os.makedirs(outdir, exist_ok=True)

scene = bpy.context.scene
view_layer = scene.view_layers[0]
rig = bpy.data.objects["Rig"]

# --- engine ------------------------------------------------------------------------
scene.render.engine = "CYCLES"              # EEVEE is GPU-only and has no shadow catcher
scene.cycles.device = "CPU"
scene.cycles.samples = samples
scene.cycles.use_denoising = denoise        # OpenImageDenoise on CPU; also denoises the catcher pass
scene.render.film_transparent = True        # world -> alpha 0
scene.render.use_compositing = True
rf_render.png_rgba(scene.render.image_settings)

# --- passes ------------------------------------------------------------------------
view_layer.use_pass_combined = True
view_layer.use_pass_emit = True
view_layer.cycles.use_pass_shadow_catcher = True   # not in the API reference; cycles addon source

# --- compositor (5.x: node group on the scene, no Composite node) -------------------
tree = bpy.data.node_groups.new("rf-passes", "CompositorNodeTree")
scene.compositing_node_group = tree
nodes, links = tree.nodes, tree.links
rl = nodes.new("CompositorNodeRLayers")
rl.layer = view_layer.name
print("RLAYER OUTPUTS:", [s.name for s in rl.outputs if s.enabled])

# shadow: catcher pass is 1 where unshadowed, <1 in shadow. alpha = 1 - value, rgb = black.
inv = nodes.new("CompositorNodeInvert")      # ShaderNodeInvert is refused in a compositor tree
inv.inputs["Factor"].default_value = 1.0     # 5.x sockets: Color, Factor, Invert Color, Invert Alpha
links.new(rl.outputs["Shadow Catcher"], inv.inputs["Color"])
black = nodes.new("CompositorNodeSetAlpha")
black.inputs["Type"].default_value = "Replace Alpha"   # 5.x: 'mode' became a menu socket
black.inputs["Image"].default_value = (0, 0, 0, 1)
links.new(inv.outputs["Color"], black.inputs["Alpha"])

# glow: emission rgb with the combined alpha so it is a transparent PNG too.
glow = nodes.new("CompositorNodeSetAlpha")
glow.inputs["Type"].default_value = "Replace Alpha"
links.new(rl.outputs["Emission"], glow.inputs["Image"])
links.new(rl.outputs["Alpha"], glow.inputs["Alpha"])

fo = nodes.new("CompositorNodeOutputFile")
fo.directory = outdir
rf_render.png_rgba(fo.format)
items = fo.file_output_items                 # 5.x: replaces file_slots; empty when made from Python
for item_name in ("structure", "shadow", "glow"):
    items.new(socket_type="RGBA", name=item_name)
print("FILE OUTPUT ITEMS:", [i.name for i in items], "inputs:", [s.name for s in fo.inputs])
links.new(rl.outputs["Image"], fo.inputs["structure"])
links.new(black.outputs["Image"], fo.inputs["shadow"])
links.new(glow.outputs["Image"], fo.inputs["glow"])

# A group output is required or the tree is invalid; feed it the combined image.
out = nodes.new("NodeGroupOutput")
tree.interface.new_socket(name="Image", in_out="OUTPUT", socket_type="NodeSocketColor")
links.new(rl.outputs["Image"], out.inputs["Image"])

# --- four directions: turn the rig, render, name the File Output results ------------
for d in range(directions):
    rig.rotation_euler[2] = math.radians(90 * d)
    fo.file_name = f"dir{d}_"          # 5.x: single-frame renders append no frame number
    bpy.ops.render.render(write_still=False)
print("OUTDIR LISTING:", sorted(os.listdir(outdir)))

# --- icon: second render, region cropped to the structure ---------------------------
rig.rotation_euler[2] = 0
scene.render.use_compositing = False
r = scene.render
r.use_border = True
r.use_crop_to_border = True
# A 128 px square out of the 320x320 frame, centred a little above the frame centre
# because the cube's top sits above its footprint in a pitched view.
side = 128 / r.resolution_x
r.border_min_x, r.border_max_x = 0.5 - side / 2, 0.5 + side / 2
r.border_min_y, r.border_max_y = 0.55 - side / 2, 0.55 + side / 2
r.filepath = os.path.join(outdir, "icon.png")
bpy.ops.render.render(write_still=True)
print("DONE", sorted(os.listdir(outdir)))

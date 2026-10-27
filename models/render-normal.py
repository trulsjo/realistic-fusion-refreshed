"""Render a model's north sheet as a normal pass, for tools/measure-density.py (#799).

    blender -b models/<machine>/<machine>.blend --python models/render-normal.py -- OUT.png
            [--samples 16]

THE SAME PIXELS AS THE NORTH SHEET. The rig is the .blend's own, turned to north as models/render.py
turns it for its first direction, and the frame is set with the same rf_blender.frame_px and
set_frame, so pixel (x, y) here is pixel (x, y) of <machine>.png. Nothing else of render.py is
needed: no shadow, no glow, no icon, no manifest.

THE GROUND IS HIDDEN, because a normal pass has no shadow catcher to make it transparent and a flat
plane under the machine would make the whole frame opaque. Nothing here is lit, so its bounce light
does not matter.

WRITTEN AS COLOUR: each component of the world-space normal mapped from -1..1 to 0..1, under the
combined alpha, through the Raw view transform so no tone curve bends it. Eight bits give about half
a degree, well under any fold the density figure counts. Writes nothing into the repository.
"""
import argparse
import glob
import math
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import rf_blender as rf  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("out")
ap.add_argument("--samples", type=int, default=16)
args = ap.parse_args(rf.script_args())

scene = bpy.context.scene
tiles_w, tiles_h = (int(v) for v in scene["rf_tiles"])
margin = float(scene["rf_margin_tiles"])
bpy.data.objects["Rig"].rotation_euler[2] = math.radians(0)
w_px, h_px = rf.frame_px(tiles_w, tiles_h, margin)
rf.set_frame(scene, w_px, h_px, tiles_w + 2 * margin)

ground = bpy.data.objects.get("Ground")
if ground is not None:
    ground.hide_render = True

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.seed = 0
scene.cycles.use_animated_seed = False
scene.cycles.use_denoising = False
scene.cycles.samples = args.samples
for flag in [p for p in dir(scene.render) if p.startswith("use_stamp")]:
    setattr(scene.render, flag, False)
scene.render.film_transparent = True
scene.render.use_compositing = True
try:
    scene.view_settings.view_transform = "Raw"
except TypeError as e:
    sys.exit(f"render-normal.py: this Blender has no Raw view transform: {e}")

view_layer = scene.view_layers[0]
view_layer.use_pass_normal = True

work = tempfile.mkdtemp(prefix="rf-normal-")
tree = bpy.data.node_groups.new("rf-normal", "CompositorNodeTree")
scene.compositing_node_group = tree
nodes, links = tree.nodes, tree.links
rl = nodes.new("CompositorNodeRLayers")
rl.layer = view_layer.name
remap = nodes.new("ShaderNodeVectorMath")           # 5.x: the compositor shares the shader editor's
remap.operation = "MULTIPLY_ADD"
remap.inputs[1].default_value = (0.5, 0.5, 0.5)
remap.inputs[2].default_value = (0.5, 0.5, 0.5)
links.new(rl.outputs["Normal"], remap.inputs[0])
alpha = nodes.new("CompositorNodeSetAlpha")
alpha.inputs["Type"].default_value = "Replace Alpha"
links.new(remap.outputs[0], alpha.inputs["Image"])
links.new(rl.outputs["Alpha"], alpha.inputs["Alpha"])
fo = nodes.new("CompositorNodeOutputFile")
fo.directory = work
fo.file_name = "n-"
rf.png_rgba(fo.format)
fo.file_output_items.new(socket_type="RGBA", name="normal")
links.new(alpha.outputs["Image"], fo.inputs["normal"])
out = nodes.new("NodeGroupOutput")
tree.interface.new_socket(name="Image", in_out="OUTPUT", socket_type="NodeSocketColor")
links.new(rl.outputs["Image"], out.inputs["Image"])

bpy.ops.render.render(write_still=False)
written = glob.glob(os.path.join(work, "n-*.png"))
if len(written) != 1:
    sys.exit(f"render-normal.py: expected one normal PNG in {work}, found {written}")
os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
shutil.move(written[0], args.out)
shutil.rmtree(work, ignore_errors=True)
print("NORMAL", os.path.abspath(args.out), f"{w_px}x{h_px}")

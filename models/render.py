"""PROTOTYPE (#246): render structure, shadow and glow for N directions from a built .blend.

    blender -b <model.blend> --python render.py -- <outdir> [samples] [directions] [pitch_deg]

Writes dir<N>_structure.png, dir<N>_shadow.png, dir<N>_glow.png, pre-stretch (see rf_blender).
An optional pitch overrides the camera's 45 deg, for the low-pitch icon candidate. Compositor
wiring is the one verified in docs/research/blender-headless-render.md.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import rf_blender as rf  # noqa: E402

args = rf.script_args()
outdir = os.path.abspath(args[0])
samples = int(args[1]) if len(args) > 1 else 48
directions = int(args[2]) if len(args) > 2 else 1
pitch = float(args[3]) if len(args) > 3 else None
os.makedirs(outdir, exist_ok=True)

scene = bpy.context.scene
view_layer = scene.view_layers[0]
rig = bpy.data.objects["Rig"]
if pitch is not None:
    # Keep the camera aimed at the origin: move it along its own view line.
    cam = bpy.data.objects["Camera"]
    cam.rotation_euler[0] = math.radians(pitch)
    d = 56.0
    cam.location = (0, -d * math.sin(math.radians(pitch)), d * math.cos(math.radians(pitch)))

# Emissive materials glow only in the glow sheet. Structure and shadow render with them off.
GLOW = [(m, m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"])
        for m in bpy.data.materials if m.use_nodes and "Principled BSDF" in m.node_tree.nodes
        and m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value > 0]
GLOW_STRENGTH = {m.name: s.default_value for m, s in GLOW}


def emission(on):
    for m, s in GLOW:
        s.default_value = GLOW_STRENGTH[m.name] if on else 0.0

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = samples
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.use_compositing = True
rf.png_rgba(scene.render.image_settings)

view_layer.use_pass_combined = True
view_layer.use_pass_emit = True
view_layer.cycles.use_pass_shadow_catcher = True

tree = bpy.data.node_groups.new("rf-passes", "CompositorNodeTree")
scene.compositing_node_group = tree
nodes, links = tree.nodes, tree.links
rl = nodes.new("CompositorNodeRLayers")
rl.layer = view_layer.name

inv = nodes.new("CompositorNodeInvert")
inv.inputs["Factor"].default_value = 1.0
links.new(rl.outputs["Shadow Catcher"], inv.inputs["Color"])
black = nodes.new("CompositorNodeSetAlpha")
black.inputs["Type"].default_value = "Replace Alpha"
black.inputs["Image"].default_value = (0, 0, 0, 1)
links.new(inv.outputs["Color"], black.inputs["Alpha"])

glow = nodes.new("CompositorNodeSetAlpha")
glow.inputs["Type"].default_value = "Replace Alpha"
links.new(rl.outputs["Emission"], glow.inputs["Image"])
links.new(rl.outputs["Alpha"], glow.inputs["Alpha"])

fo = nodes.new("CompositorNodeOutputFile")
fo.directory = outdir
rf.png_rgba(fo.format)
for name in ("structure", "shadow", "glow"):
    fo.file_output_items.new(socket_type="RGBA", name=name)
links.new(rl.outputs["Image"], fo.inputs["structure"])
links.new(black.outputs["Image"], fo.inputs["shadow"])
links.new(glow.outputs["Image"], fo.inputs["glow"])

out = nodes.new("NodeGroupOutput")
tree.interface.new_socket(name="Image", in_out="OUTPUT", socket_type="NodeSocketColor")
links.new(rl.outputs["Image"], out.inputs["Image"])

for d in range(directions):
    rig.rotation_euler[2] = math.radians(90 * d)
    emission(False)
    fo.file_name = f"dir{d}_"
    bpy.ops.render.render(write_still=False)        # structure + shadow (glow output is black here)
    if GLOW:
        emission(True)
        fo.file_name = f"dir{d}_lit_"
        bpy.ops.render.render(write_still=False)    # only dir<d>_lit_glow.png is wanted from this one
        for junk in ("structure", "shadow"):
            try:
                os.remove(os.path.join(outdir, f"dir{d}_lit_{junk}.png"))
            except OSError:
                pass
        os.replace(os.path.join(outdir, f"dir{d}_lit_glow.png"), os.path.join(outdir, f"dir{d}_glow.png"))
print("RENDERED", sorted(os.listdir(outdir)), "final_px", list(scene["rf_final_px"]))

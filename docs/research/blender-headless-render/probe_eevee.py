"""Probe: does EEVEE render headless on this machine, and what passes does it offer?

    blender -b <scene.blend> --python probe_eevee.py -- <outdir>

Renders the combined pass only, film transparent, and prints the render-layer sockets
EEVEE exposes with every pass toggle on. Exit 0 means it ran; read the output.
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import rf_render  # noqa: E402

outdir = os.path.abspath(rf_render.script_args()[0])
os.makedirs(outdir, exist_ok=True)
scene = bpy.context.scene
vl = scene.view_layers[0]
scene.render.engine = "BLENDER_EEVEE"
scene.eevee.taa_render_samples = 16
scene.render.film_transparent = True
scene.render.use_compositing = False
rf_render.png_rgba(scene.render.image_settings)

for prop in ("use_pass_emit", "use_pass_shadow", "use_pass_ambient_occlusion", "use_pass_z"):
    if hasattr(vl, prop):
        setattr(vl, prop, True)
tree = bpy.data.node_groups.new("probe", "CompositorNodeTree")
scene.compositing_node_group = tree
rl = tree.nodes.new("CompositorNodeRLayers")
print("EEVEE RLAYER OUTPUTS:", [s.name for s in rl.outputs if s.enabled])
print("PYTHON", sys.version)

scene.render.filepath = os.path.join(outdir, "eevee_structure.png")
t0 = time.perf_counter()
bpy.ops.render.render(write_still=True)
print(f"EEVEE RENDER OK in {time.perf_counter() - t0:.2f}s ->", scene.render.filepath)

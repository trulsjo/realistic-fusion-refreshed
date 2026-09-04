"""Build the test scene and save it as a .blend.

    blender -b --python build_scene.py -- <out.blend>

Cube on a plane, one sun, an orthographic camera. Camera and sun are parented to an
empty called 'Rig' so rotating the empty about Z turns light and view together for the
four Factorio directions. Nothing is imported; every object is a primitive.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import rf_render  # noqa: E402  (proves the outside-written module imports)

out = rf_render.script_args()[0]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = "rf"

# Ground: a shadow catcher. In Cycles it receives shadow and is otherwise transparent.
bpy.ops.mesh.primitive_plane_add(size=20)
plane = bpy.context.object
plane.name = "Ground"
plane.is_shadow_catcher = True   # on bpy.types.Object, not a cycles sub-struct, in 5.x

# Structure: a 2x2-tile cube with an emissive tint so the emission pass has content.
bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, 1))
cube = bpy.context.object
cube.name = "Structure"
mat = bpy.data.materials.new("StructureMat")
mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Base Color"].default_value = (0.35, 0.38, 0.42, 1.0)
bsdf.inputs["Roughness"].default_value = 0.6
cube.data.materials.append(mat)

# A glowing chimney on the north-east corner: tells the four directions apart and is
# the only emissive surface, so the emission pass should contain it and nothing else.
bpy.ops.mesh.primitive_cube_add(size=0.5, location=(0.7, 0.7, 2.25))
marker = bpy.context.object
marker.name = "Marker"
glow_mat = bpy.data.materials.new("GlowMat")
glow_mat.use_nodes = True
gb = glow_mat.node_tree.nodes["Principled BSDF"]
gb.inputs["Base Color"].default_value = (0.0, 0.0, 0.0, 1.0)
gb.inputs["Emission Color"].default_value = (0.1, 0.9, 1.0, 1.0)
gb.inputs["Emission Strength"].default_value = 3.0
marker.data.materials.append(glow_mat)

# Rig: empty at origin; camera and sun are its children.
rig = bpy.data.objects.new("Rig", None)
scene.collection.objects.link(rig)

cam_data = bpy.data.cameras.new("Camera")
cam = bpy.data.objects.new("Camera", cam_data)
scene.collection.objects.link(cam)
cam.parent = rig
# Looking down from the south, pitched 45 deg. Provisional: the exact Factorio pitch is
# the sibling camera ticket's question, not this one's.
cam.location = (0, -20, 20)
cam.rotation_euler = (math.radians(45), 0, 0)
scene.camera = cam

sun_data = bpy.data.lights.new("Sun", type="SUN")
sun_data.energy = 4.0
sun_data.angle = math.radians(2)
sun = bpy.data.objects.new("Sun", sun_data)
scene.collection.objects.link(sun)
sun.parent = rig
sun.location = (0, 0, 10)
# A sun lights along its local -Z. Pitch -50 deg sends the light toward -Y (south, down
# the frame), yaw +35 deg adds +X (east, right): shadows fall down-right as in Factorio.
sun.rotation_euler = (math.radians(-50), 0, math.radians(35))

rf_render.set_frame(scene, cam, tiles_w=2, tiles_h=2, margin_tiles=1.5)

bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(out))
print("BUILT", os.path.abspath(out), scene.render.resolution_x, scene.render.resolution_y)

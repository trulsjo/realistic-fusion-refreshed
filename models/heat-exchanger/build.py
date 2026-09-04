"""PROTOTYPE (#246): build the heat exchanger model from its look note, headless.

    blender -b --python build.py -- <out.blend> [drums|plates|cube]

Reads geometry.json beside this file for the collision box and the connections, so the sockets
land where the prototype declares them. Everything is a primitive with a procedural material:
nothing imported (house style, licence rule). `cube` builds a 1x1x1 calibration cube instead of
the machine, for the vertical-factor check the camera research asked for.

The rig (camera + sun parented to one empty) is built by models/rf_blender.py so every machine
shares it; this file only makes the machine.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import bpy  # noqa: E402
import rf_blender as rf  # noqa: E402

args = rf.script_args()
out = args[0]
variant = args[1] if len(args) > 1 else "drums"

geo = json.load(open(os.path.join(HERE, "geometry.json"), encoding="utf-8"))
(x0, y0), (x1, y1) = geo["collision_box"]
# Factorio +y is south; Blender +Y is north. Flip y once here and nowhere else.
W, L = x1 - x0, y1 - y0            # 4.5 x 14.5
HALF_W, HALF_L = W / 2, L / 2

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = "rf"

# ---- materials (house style palette) -------------------------------------------------------
PALETTE = {
    "body":   ((0.30, 0.33, 0.38), 0.6, 0.0),
    "frame":  ((0.12, 0.13, 0.15), 0.6, 0.0),
    "metal":  ((0.55, 0.55, 0.58), 0.35, 0.8),
    "energy": ((1.00, 0.45, 0.10), 0.5, 0.0),
    "steam":  ((0.85, 0.88, 0.90), 0.5, 0.0),
    "water":  ((0.25, 0.55, 1.00), 0.5, 0.0),
}
MATS = {}


def mat(name, glow=False):
    key = (name, glow)
    if key in MATS:
        return MATS[key]
    rgb, rough, metal = PALETTE[name]
    m = bpy.data.materials.new(f"{name}{'-glow' if glow else ''}")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if glow:
        b.inputs["Emission Color"].default_value = (*rgb, 1.0)
        b.inputs["Emission Strength"].default_value = 3.0
    MATS[key] = m
    return m


def bevel(obj, width=0.03):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = 2


def box(name, size, loc, material, glow=False):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = size
    o.data.materials.append(mat(material, glow))
    bevel(o)
    return o


def cyl(name, radius, depth, loc, material, axis="Z", glow=False):
    rot = {"Z": (0, 0, 0), "X": (0, math.pi / 2, 0), "Y": (math.pi / 2, 0, 0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=loc, rotation=rot, vertices=48)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(mat(material, glow))
    bevel(o, 0.02)
    return o


# ---- the machine --------------------------------------------------------------------------
if variant == "cube":
    box("Cube", (1, 1, 1), (0, 0, 0.5), "body")
else:
    SLAB = 0.25
    box("Slab", (W, L, SLAB), (0, 0, SLAB / 2), "frame")

    if variant == "drums":
        BODY_H = 1.4
        box("Body", (W - 0.6, L - 0.4, BODY_H), (0.2, 0, SLAB + BODY_H / 2), "body")
        # West manifold trough: the reactor contact, full length, energy accent. Glows when working.
        box("Manifold", (0.7, L - 0.2, 1.1), (-HALF_W + 0.35, 0, SLAB + 0.55), "metal")
        box("ManifoldBand", (0.72, L - 0.4, 0.25), (-HALF_W + 0.35, 0, SLAB + 1.0), "energy", glow=True)
        # Three drums down the centreline, the tallest thing on the machine.
        DRUM_R, DRUM_H = 1.15, 2.6
        for i, y in enumerate((-4.6, 0.0, 4.6)):
            cyl(f"Drum{i}", DRUM_R, DRUM_H, (0.2, y, SLAB + DRUM_H / 2), "metal")
            cyl(f"DrumCap{i}", DRUM_R * 0.55, 0.2, (0.2, y, SLAB + DRUM_H + 0.1), "frame")
        # Steam header along the drum tops, then east to the outlet.
        HDR_Z = SLAB + DRUM_H - 0.3
        cyl("Header", 0.22, 9.6, (0.2, 0, HDR_Z), "metal", axis="Y")
        box("HeaderBand", (0.5, 0.5, 0.5), (0.2, 0, HDR_Z), "steam")
        cyl("HeaderDrop", 0.22, HDR_Z - 0.6, (1.6, 0, (HDR_Z + 0.6) / 2), "metal")
        cyl("HeaderEast", 0.22, 1.6, (1.0, 0, HDR_Z), "metal", axis="X")
        # Broken symmetry: a control cabinet at the south-east corner.
        box("Cabinet", (0.8, 1.2, 1.9), (HALF_W - 0.5, -HALF_L + 0.9, SLAB + 0.95), "frame")
        box("CabinetPanel", (0.1, 0.8, 0.6), (HALF_W - 0.08, -HALF_L + 0.9, SLAB + 1.3), "water")
    elif variant == "plates":
        BODY_H = 2.0
        box("Body", (W - 1.2, L - 1.0, BODY_H), (0, 0, SLAB + BODY_H / 2), "frame")
        # Fin stack: thin plates across the width, the whole length, body colour.
        n = 26
        for i in range(n):
            y = -HALF_L + 0.75 + i * (L - 1.5) / (n - 1)
            box(f"Fin{i}", (W - 0.4, 0.14, BODY_H + 0.3), (0, y, SLAB + (BODY_H + 0.3) / 2), "body")
        box("Manifold", (0.6, L - 0.2, 1.4), (-HALF_W + 0.3, 0, SLAB + 0.7), "metal")
        box("ManifoldBand", (0.62, L - 0.4, 0.3), (-HALF_W + 0.3, 0, SLAB + 1.35), "energy", glow=True)
        box("SteamDome", (1.2, 3.0, 0.9), (0.6, 0, SLAB + BODY_H + 0.3 + 0.45), "metal")
        box("SteamBand", (1.22, 0.6, 0.3), (0.6, 0, SLAB + BODY_H + 0.3 + 0.9), "steam")
        box("Cabinet", (0.8, 1.2, 1.5), (HALF_W - 0.5, -HALF_L + 0.9, SLAB + 0.75), "frame")

    # Sockets: one per declared connection, from the body to the footprint edge, accent band.
    (sx0, sy0), (sx1, sy1) = geo["selection_box"]
    for c in geo["connections"]:
        px, py = c["position"]
        py = -py                                   # Factorio south -> Blender -Y
        d = c["direction"]
        z = 0.7
        if d in ("west", "east"):
            edge = sx0 if d == "west" else sx1
            length = abs(edge) - (HALF_W - 0.5)
            cx = (edge + (HALF_W - 0.5) * (1 if d == "east" else -1)) / 2
            cyl(f"Socket-{d}", 0.3, length, (cx, py, z), "metal", axis="X")
            cyl(f"Band-{d}", 0.34, 0.25, (edge - 0.3 * (1 if d == "east" else -1), py, z), c["accent"], axis="X")
        else:
            edge = -sy0 if d == "north" else -sy1  # flipped: north is +Y
            inner = (HALF_L - 0.5) * (1 if d == "north" else -1)
            length = abs(edge - inner)
            cy = (edge + inner) / 2
            cyl(f"Socket-{d}", 0.3, length, (px, cy, z), "metal", axis="Y")
            cyl(f"Band-{d}", 0.34, 0.25, (px, edge - 0.3 * (1 if d == "north" else -1), z), c["accent"], axis="Y")

tiles_w = geo["selection_box"][1][0] - geo["selection_box"][0][0] if variant != "cube" else 1
tiles_h = geo["selection_box"][1][1] - geo["selection_box"][0][1] if variant != "cube" else 1
rf.build_rig(scene, tiles_w, tiles_h)
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(out))
print("BUILT", variant, os.path.abspath(out), scene.render.resolution_x, scene.render.resolution_y)

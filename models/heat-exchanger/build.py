"""Build the heat exchanger model from its look note, headless. This is what "regenerate" reruns.

    blender -b --python build.py -- [out.blend] [machine|cube]

Reads geometry.json beside this file for the collision box and the connections, so the sockets
land where the prototype declares them, and stamps the scene with that file's hash so render.py
can refuse a model whose geometry has moved on. Everything is a primitive or a curve with a
procedural material: nothing imported (house style, licence rule). `cube` builds a 1x1x1
calibration cube for measuring the camera. Written to heat-exchanger.blend beside this file
unless a path is given.

Drafts 2 and 3 follow Truls's reactions of 2026-09-04: imperfect drums (rib bands, weld seam,
relief valve), a corrugated header that is not quite straight, an open H-beam frame over a grating
instead of walls with glowing feed lines visible under it, a south end wall, panel seams and rivet
lines, procedural grime, and the energy channel on top of the manifold where the camera sees it.
"""
import json
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import bpy  # noqa: E402
import rf_blender as rf  # noqa: E402

args = rf.script_args()
out = args[0] if args else os.path.join(HERE, "heat-exchanger.blend")
variant = args[1] if len(args) > 1 else "machine"
random.seed(7)  # imperfections are deterministic: same script, same model

geo_path = os.path.join(HERE, "geometry.json")
geo = json.load(open(geo_path, encoding="utf-8"))
(x0, y0), (x1, y1) = geo["collision_box"]
W, L = x1 - x0, y1 - y0            # 4.5 x 14.5
HALF_W, HALF_L = W / 2, L / 2

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = "rf"

# ---- materials (house style palette) -------------------------------------------------------
PALETTE = {
    "body":   ((0.30, 0.33, 0.38), 0.6, 0.0),
    "frame":  ((0.10, 0.11, 0.13), 0.55, 0.2),
    "metal":  ((0.55, 0.55, 0.58), 0.35, 0.8),
    "dark":   ((0.35, 0.36, 0.38), 0.45, 0.8),
    "energy": ((1.00, 0.45, 0.10), 0.5, 0.0),
    "steam":  ((0.85, 0.88, 0.90), 0.5, 0.0),
    "water":  ((0.25, 0.55, 1.00), 0.5, 0.0),
    "plasma": ((0.55, 0.20, 1.00), 0.5, 0.0),
}
ACCENTS = ("energy", "steam", "water", "plasma")   # stay clean: no grime, so they read
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
    if not glow and name not in ACCENTS:
        # grime: a noise texture darkens patches of the base colour and roughens them
        nt = m.node_tree
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 5.0
        noise.inputs["Detail"].default_value = 4.0
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.42
        ramp.color_ramp.elements[1].position = 0.62
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.inputs["A"].default_value = (*rgb, 1.0)
        mix.inputs["B"].default_value = (rgb[0] * 0.55, rgb[1] * 0.5, rgb[2] * 0.45, 1.0)
        nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], mix.inputs["Factor"])
        nt.links.new(mix.outputs["Result"], b.inputs["Base Color"])
        rmix = nt.nodes.new("ShaderNodeMath")
        rmix.operation = "MULTIPLY_ADD"
        rmix.inputs[1].default_value = 0.35
        rmix.inputs[2].default_value = rough
        nt.links.new(ramp.outputs["Color"], rmix.inputs[0])
        nt.links.new(rmix.outputs["Value"], b.inputs["Roughness"])
    if glow:
        # Dark in the structure sheet, the accent in the glow sheet. The game adds the two, so a
        # glowing part whose base is already the accent both washes pale when working and looks lit
        # when cold -- see rf_blender.GLOW_BASE_DARKEN for the measurement and the decision.
        b.inputs["Base Color"].default_value = (*(c * rf.GLOW_BASE_DARKEN for c in rgb), 1.0)
        b.inputs["Emission Color"].default_value = (*rgb, 1.0)
        b.inputs["Emission Strength"].default_value = rf.GLOW_EMISSION
    MATS[key] = m
    return m


def bevel(obj, width=0.03):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = 2


def box(name, size, loc, material, glow=False, rot=(0, 0, 0), bev=0.03):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = size
    o.data.materials.append(mat(material, glow))
    if bev:
        bevel(o, bev)
    return o


def cyl(name, radius, depth, loc, material, axis="Z", glow=False, rot=None, verts=48):
    rot = rot or {"Z": (0, 0, 0), "X": (0, math.pi / 2, 0), "Y": (math.pi / 2, 0, 0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=loc, rotation=rot, vertices=verts)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(mat(material, glow))
    bevel(o, 0.02)
    return o


def torus(name, major, minor, loc, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=loc, rotation=rot,
                                     major_segments=48, minor_segments=12)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(mat(material))
    return o


def pipe(name, points, radius, material, glow=False, corrugate=0.0):
    """A pipe along a Bezier curve through `points` (slightly wobbly by construction), with
    optional corrugation rings every `corrugate` tiles."""
    cd = bpy.data.curves.new(name, "CURVE")
    cd.dimensions = "3D"
    cd.bevel_depth = radius
    cd.bevel_resolution = 6
    cd.fill_mode = "FULL"
    sp = cd.splines.new("BEZIER")
    sp.bezier_points.add(len(points) - 1)
    for bp, p in zip(sp.bezier_points, points):
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    o = bpy.data.objects.new(name, cd)
    scene.collection.objects.link(o)
    o.data.materials.append(mat(material, glow))
    if corrugate:
        # rings along the polyline between consecutive points
        k = 0
        for a, b in zip(points, points[1:]):
            seg = math.dist(a, b)
            n = max(1, int(seg / corrugate))
            for i in range(n):
                t = (i + 0.5) / n
                c = tuple(a[j] + (b[j] - a[j]) * t for j in range(3))
                d = tuple(b[j] - a[j] for j in range(3))
                yaw = math.atan2(d[1], d[0])
                pitch = math.atan2(d[2], math.hypot(d[0], d[1]))
                torus(f"{name}-ring{k}", radius * 1.15, radius * 0.22, c, material,
                      rot=(0, math.pi / 2 - pitch, yaw))
                k += 1
    return o


def hbeam(name, length, loc, axis="Z", depth=0.2, flange=0.16, web=0.03, material="frame"):
    """An H-profile beam: two flanges and a web, along `axis`."""
    fl = flange / 2
    if axis == "Z":
        box(f"{name}-web", (web, depth - 0.05, length), loc, material, bev=0)
        for sx in (-1, 1):
            box(f"{name}-f{sx}", (flange, web, length), (loc[0] + sx * 0, loc[1] + sx * (depth / 2), loc[2]), material, bev=0.01)
    elif axis == "Y":
        box(f"{name}-web", (web, length, depth - 0.05), loc, material, bev=0)
        for sz in (-1, 1):
            box(f"{name}-f{sz}", (flange, length, web), (loc[0], loc[1], loc[2] + sz * (depth / 2)), material, bev=0.01)
    else:
        box(f"{name}-web", (length, web, depth - 0.05), loc, material, bev=0)
        for sz in (-1, 1):
            box(f"{name}-f{sz}", (length, flange, web), (loc[0], loc[1], loc[2] + sz * (depth / 2)), material, bev=0.01)


def rivets(name, start, end, n, r=0.045, material="dark"):
    for i in range(n):
        t = (i + 0.5) / n
        loc = tuple(start[j] + (end[j] - start[j]) * t for j in range(3))
        bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=12, ring_count=8)
        o = bpy.context.object
        o.name = f"{name}-{i}"
        o.data.materials.append(mat(material))


def seam(name, size, loc, rot=(0, 0, 0)):
    """A dark groove: a thin frame-coloured box sunk into a panel face."""
    box(name, size, loc, "frame", rot=rot, bev=0)


def jitter(v, s):
    return v + random.uniform(-s, s)


# ---- the machine --------------------------------------------------------------------------
if variant == "cube":
    box("Cube", (1, 1, 1), (0, 0, 0.5), "body")
else:
    SLAB = 0.25
    box("Slab", (W, L, SLAB), (0, 0, SLAB / 2), "frame")
    seam("SlabSeam", (W + 0.02, 0.05, 0.03), (0, 0, SLAB))
    seam("SlabSeam2", (0.05, L + 0.02, 0.03), (0.6, 0, SLAB))

    # -- west manifold: the reactor contact. Closed panels, seams, rivet line, energy band. Glows.
    MAN_W, MAN_H = 0.8, 1.25
    MX = -HALF_W + MAN_W / 2
    box("Manifold", (MAN_W, L - 0.2, MAN_H), (MX, 0, SLAB + MAN_H / 2), "body")
    for i in range(6):
        y = -HALF_L + 0.1 + (i + 1) * (L - 0.2) / 7
        seam(f"ManifoldSeam{i}", (MAN_W + 0.02, 0.05, MAN_H - 0.2), (MX, y, SLAB + MAN_H / 2))
    rivets("ManifoldRivetsTop", (MX - MAN_W / 2 + 0.08, -HALF_L + 0.3, SLAB + MAN_H + 0.01),
           (MX - MAN_W / 2 + 0.08, HALF_L - 0.3, SLAB + MAN_H + 0.01), 28)
    # energy channel along the TOP of the manifold, where the camera sees it; glows when working
    box("ManifoldBand", (MAN_W * 0.45, L - 0.6, 0.06), (MX + 0.05, 0, SLAB + MAN_H + 0.01), "energy", glow=True)
    for i in range(14):
        y = -HALF_L + 0.6 + i * (L - 1.2) / 13
        box(f"ManifoldGrille{i}", (MAN_W * 0.5, 0.05, 0.05), (MX + 0.05, y, SLAB + MAN_H + 0.04), "dark", bev=0)

    # -- open frame of H-beams, no walls. Posts on the east edge and the mid-line, rails on top.
    FRAME_H = 2.0
    EX = HALF_W - 0.12
    MXE = MX + MAN_W / 2 + 0.2
    post_ys = [-HALF_L + 0.3 + k * (L - 0.6) / 6 for k in range(7)]
    for i, y in enumerate(post_ys):
        hbeam(f"PostE{i}", FRAME_H, (EX, y, SLAB + FRAME_H / 2), axis="Z")
        hbeam(f"PostM{i}", FRAME_H, (MXE, y, SLAB + FRAME_H / 2), axis="Z")
        hbeam(f"Rail{i}", EX - MXE, ((EX + MXE) / 2, y, SLAB + FRAME_H), axis="X", depth=0.16, flange=0.14)
    hbeam("RailE", L - 0.4, (EX, 0, SLAB + FRAME_H), axis="Y", depth=0.16, flange=0.14)
    hbeam("RailM", L - 0.4, (MXE, 0, SLAB + FRAME_H), axis="Y", depth=0.16, flange=0.14)
    hbeam("RailE2", L - 0.4, (EX, 0, SLAB + 0.9), axis="Y", depth=0.12, flange=0.12)
    # Grating deck under the drums: slats, so the feed lines below stay visible.
    for i in range(30):
        y = -HALF_L + 0.5 + i * (L - 1.0) / 29
        box(f"Slat{i}", (W - MAN_W - 0.7, 0.06, 0.05), (0.35, y, SLAB + 0.5), "dark", bev=0)
    # South end wall: a closed panel the camera can see, between manifold and cabinet.
    box("EndWall", (W - MAN_W - 0.3, 0.16, 1.15), (MXE + (EX - MXE) / 2 - 0.05, -HALF_L + 0.12, SLAB + 0.575), "body")
    seam("EndWallSeam", (0.04, 0.18, 0.95), (MXE + (EX - MXE) / 2 - 0.9, -HALF_L + 0.12, SLAB + 0.575))
    rivets("EndWallRivets", (MXE + 0.2, -HALF_L + 0.03, SLAB + 1.0), (EX - 0.3, -HALF_L + 0.03, SLAB + 1.0), 9, r=0.04)
    box("EndWallVent", (0.9, 0.06, 0.4), (MXE + (EX - MXE) / 2 + 0.3, -HALF_L + 0.03, SLAB + 0.55), "dark", bev=0)

    # -- three drums: rib bands, weld seam, cap, relief valve. Not identical.
    DRUM_H = 2.3
    DX = 0.35
    drum_ys = (-4.6, 0.0, 4.6)
    for i, y in enumerate(drum_ys):
        r = jitter(1.05, 0.04)
        h = jitter(DRUM_H, 0.08)
        z0 = SLAB + 0.5
        d = cyl(f"Drum{i}", r, h, (DX, y, z0 + h / 2), "metal", verts=64)
        d.scale = (1.0, jitter(1.0, 0.03), 1.0)
        for k, frac in enumerate((0.3, 0.7)):
            torus(f"Drum{i}Rib{k}", r + 0.015, 0.035, (DX, y, z0 + h * frac), "dark")
        seam(f"Drum{i}Weld", (0.03, 2 * r + 0.02, 0.04), (DX + r - 0.02, y, z0 + h * 0.4), rot=(0, 0, jitter(0, 0.2)))
        cyl(f"Drum{i}Cap", r * 0.6, 0.18, (DX, y, z0 + h + 0.09), "dark")
        # relief valve: a stub, a body and a little cap, off-centre so rotations differ
        vx, vy = DX + r * 0.45, y - r * 0.3
        cyl(f"Drum{i}ValveStem", 0.09, 0.35, (vx, vy, z0 + h + 0.35), "metal", verts=24)
        cyl(f"Drum{i}ValveBody", 0.16, 0.22, (vx, vy, z0 + h + 0.6), "steam", verts=24)
        cyl(f"Drum{i}ValveCap", 0.07, 0.25, (vx + 0.18, vy, z0 + h + 0.6), "metal", axis="X", verts=16)
        # glowing feed line from the manifold to the foot of the drum, under the deck
        pipe(f"Feed{i}", [(MX + MAN_W / 2, y + jitter(0, 0.3), SLAB + 0.42),
                          (jitter(-0.7, 0.15), y + jitter(0, 0.2), SLAB + jitter(0.4, 0.03)),
                          (DX - r * 0.7, y, SLAB + 0.45)], 0.1, "energy", glow=True)

    # -- corrugated steam header across the drum tops, not quite straight, east to the outlet.
    HZ = SLAB + 0.5 + DRUM_H + 0.05
    header_pts = [(DX + jitter(0, 0.08), drum_ys[0] - 0.3, HZ)]
    for y in drum_ys:
        header_pts.append((DX + jitter(0, 0.1), y, HZ + jitter(0, 0.06)))
    header_pts.append((DX + jitter(0, 0.08), drum_ys[-1] + 0.3, HZ))
    pipe("Header", header_pts, 0.19, "metal", corrugate=0.45)
    box("HeaderBand", (0.5, 0.5, 0.5), (DX, 0, HZ), "steam")
    drop_top = (DX + 0.25, 0.0, HZ)
    pipe("HeaderDrop", [drop_top, (1.2, jitter(0, 0.1), HZ - 0.6), (1.5, 0.0, 1.0), (HALF_W - 0.5, 0.0, 0.7)],
         0.19, "metal", corrugate=0.45)

    # -- cabinet, south-east corner: the one asymmetry. Seams and a blue panel.
    CAB = (0.8, 1.3, 1.7)
    cpos = (HALF_W - 0.55, -HALF_L + 0.95, SLAB + CAB[2] / 2)
    box("Cabinet", CAB, cpos, "body")
    seam("CabinetSeam", (CAB[0] + 0.02, 0.04, CAB[2] - 0.3), cpos)
    box("CabinetPanel", (0.06, 0.7, 0.5), (cpos[0] + CAB[0] / 2, cpos[1], cpos[2] + 0.3), "water", bev=0)
    rivets("CabinetRivets", (cpos[0] + CAB[0] / 2 + 0.01, cpos[1] - 0.5, cpos[2] - CAB[2] / 2 + 0.15),
           (cpos[0] + CAB[0] / 2 + 0.01, cpos[1] + 0.5, cpos[2] - CAB[2] / 2 + 0.15), 6)

    # -- sockets: one per declared connection, body to footprint edge, accent band.
    (sx0, sy0), (sx1, sy1) = geo["selection_box"]
    for c in geo["connections"]:
        px, py = c["position"]
        py = -py                                   # Factorio south -> Blender -Y
        d = c["direction"]
        z = 0.55
        if d in ("west", "east"):
            edge = sx0 if d == "west" else sx1
            inner = (HALF_W - 0.5) * (1 if d == "east" else -1)
            cyl(f"Socket-{d}", 0.3, abs(edge - inner), ((edge + inner) / 2, py, z), "metal", axis="X")
            cyl(f"Band-{d}", 0.34, 0.22, (edge - 0.28 * (1 if d == "east" else -1), py, z), rf.accent(c["fluid"]), axis="X")
        else:
            edge = -sy0 if d == "north" else -sy1  # flipped: north is +Y
            inner = (HALF_L - 0.5) * (1 if d == "north" else -1)
            cyl(f"Socket-{d}", 0.3, abs(edge - inner), (px, (edge + inner) / 2, z), "metal", axis="Y")
            cyl(f"Band-{d}", 0.34, 0.22, (px, edge - 0.28 * (1 if d == "north" else -1), z), rf.accent(c["fluid"]), axis="Y")
    # water header along the base between the two end sockets
    pipe("WaterHeader", [(0, -HALF_L + 0.5, 0.55), (jitter(0, 0.1), 0, 0.5), (0, HALF_L - 0.5, 0.55)], 0.13, "metal")

# THE ICON IS THE WHOLE MACHINE, not a section of it. #246 framed a 4.5-tile crop -- the middle
# drum with the manifold beside it -- and in the inventory beside Krastorio 2's icons that read as a
# fragment of a screenshot: no silhouette, the grating running off all four edges. Truls,
# 2026-09-05 (#252): pull back until the whole machine sits in the square with transparent margin.
#
# AND IT RUNS CORNER TO CORNER. Square-on, five by fifteen fills a fifth of a square icon and reads
# as a hairline -- measured: 829 opaque pixels of 4096. Turned 45 degrees the same machine spans the
# diagonal, so the window shrinks from 18.5 tiles to 15.5 and the subject roughly doubles. The rig
# carries the sun, so the icon is lit like every sheet; only the angle differs, which is what
# vanilla does for its own long machines.
#
# The square is sized on the machine's SCREEN extent, not its footprint: turned, the footprint's
# bounding box is (15 + 5)/sqrt(2) = 14.1 tiles, and the drums' height shows at 0.707 h northward,
# so 15.5 leaves margin all round. The centre rides north by half that height, or the machine sits
# low in the square with the margin all above it.
if variant == "cube":
    tiles_w, tiles_h, icon_centre, icon_tiles, icon_yaw = 1, 1, (0, 0, 0.5), 1.5, 0.0
else:
    tiles_w, tiles_h = geo["tiles"]
    icon_centre, icon_tiles, icon_yaw = (0.0, 1.0, 0.0), 15.5, 45.0
rf.build_rig(scene, tiles_w, tiles_h, icon_centre, icon_tiles, icon_yaw=icon_yaw)
scene["rf_geometry_sha256"] = rf.geometry_sha256(geo_path)
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(out))
print("BUILT", variant, os.path.abspath(out), scene.render.resolution_x, scene.render.resolution_y)

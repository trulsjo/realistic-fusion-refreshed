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
#
# The values dropped on 2026-09-05 (#252). Truls, on the first in-game shots: too pale and flat --
# beside Krastorio 2's reactor the machine was one value of grey with no dark recesses. Painted body
# steel went from 0.30 to 0.24 and rougher, so it reads as PAINT beside bare metal rather than as
# more metal; "frame" to 0.07 and "dark" from 0.35 to 0.26 -- the grating deck, the ribs and the
# vents -- so the frame has shadows in it. Bare metal is unchanged: the house style fixes it, and
# what was wrong with the drums was the grime, not the colour. Taking the whole palette darker was
# tried first and only moved the fault: uniformly muddy is as flat as uniformly pale.
PALETTE = {
    "body":   ((0.24, 0.26, 0.30), 0.72, 0.0),
    "frame":  ((0.07, 0.08, 0.09), 0.6, 0.2),
    "metal":  ((0.55, 0.55, 0.58), 0.35, 0.8),
    "dark":   ((0.26, 0.27, 0.29), 0.5, 0.7),
    "energy": ((1.00, 0.45, 0.10), 0.5, 0.0),
    "steam":  ((0.85, 0.88, 0.90), 0.5, 0.0),
    "water":  ((0.25, 0.55, 1.00), 0.5, 0.0),
    "plasma": ((0.55, 0.20, 1.00), 0.5, 0.0),
    # PAINT, not steel. Truls, #252: the machine needed some painted panels -- steel-on-steel gave
    # it no colour of its own beside Krastorio 2's, which is yellow. A matte industrial off-white
    # is high in value where the frame is low, so a panel reads as a panel rather than as more
    # body. The hue is my pick and easy to change: it is the one colour here that no fluid owns.
    "paint":  ((0.58, 0.55, 0.47), 0.8, 0.0),
}
ACCENTS = ("energy", "steam", "water", "plasma")   # stay clean: no grime, so they read
MATS = {}


# CORROSION IS THREE COLOURS, NOT ONE. A single rust mask over the whole manifold came out even and
# orange, and Truls read it as copper (#252). Real corrosion is patchy and goes several ways at
# once, so three masks at three scales run in sequence: rust where water has run, a much darker
# brown where it has sat and pitted, and a little verdigris. Each has its own noise, because
# sharing a mask is what made the first version uniform.
RUST = (0.27, 0.14, 0.07)
RUST_DARK = (0.09, 0.045, 0.025)
VERDIGRIS = (0.14, 0.28, 0.20)


def mat(name, glow=False, corrode=False):
    key = (name, glow, corrode)
    if key in MATS:
        return MATS[key]
    rgb, rough, metal = PALETTE[name]
    # A GLOWING PART IS DARK IN THE STRUCTURE SHEET AND THE ACCENT IN THE GLOW SHEET. The game adds
    # the two, so a part left at full accent in both washes pale when working and looks lit when
    # cold -- see rf_blender.GLOW_BASE_DARKEN. The darkened value is the base for everything below,
    # grime included, which is the point: the cold channel used to be an ACCENT and accents are
    # excluded from grime, so it came out as fourteen tiles of dead-flat mid-brown and Truls read
    # the manifold as copper (#252). It was never the corrosion. A glowing part takes grime like
    # any other surface now, and only a part that is actually clean stays clean.
    base = tuple(c * rf.GLOW_BASE_DARKEN for c in rgb) if glow else rgb
    m = bpy.data.materials.new(f"{name}{'-glow' if glow else ''}{'-rust' if corrode else ''}")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*base, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if glow or name not in ACCENTS:
        # GRIME, and it does more work than it used to. The first version mixed one soft noise at
        # 0.55 of the base and modulated roughness by 0.35, which at 64 px a tile is invisible: the
        # drums came out as smooth plastic and the whole machine as one value (Truls, #252). Now two
        # noises blend -- a broad one for patches and a fine one for streaks -- and roughness swings
        # by 0.5, which is what stops a big curved bare-metal surface holding one clean highlight.
        # The dark end stays at about half the base: the fault was the mask, not its depth.
        nt = m.node_tree
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 4.0
        noise.inputs["Detail"].default_value = 6.0
        fine = nt.nodes.new("ShaderNodeTexNoise")
        fine.inputs["Scale"].default_value = 22.0
        fine.inputs["Detail"].default_value = 4.0
        # BLENDED, not summed. The first attempt added the fine noise on top of the broad one, which
        # pushed the mask past the top of the ramp nearly everywhere: every surface came out at the
        # dark end, evenly, and the machine went from too pale to uniformly muddy without ever being
        # patchy. A weighted blend keeps the mask centred so the ramp has something to spread.
        combine = nt.nodes.new("ShaderNodeMix")
        combine.data_type = "FLOAT"
        combine.inputs[0].default_value = 0.35         # 0 = broad patches only, 1 = fine streaks only
        nt.links.new(noise.outputs["Fac"], combine.inputs[2])
        nt.links.new(fine.outputs["Fac"], combine.inputs[3])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.40
        ramp.color_ramp.elements[1].position = 0.72
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.inputs["A"].default_value = (*base, 1.0)
        mix.inputs["B"].default_value = (base[0] * 0.5, base[1] * 0.45, base[2] * 0.4, 1.0)
        nt.links.new(combine.outputs["Result"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], mix.inputs["Factor"])
        out = mix.outputs["Result"]
        if corrode:
            # Three passes, each its own noise at its own scale and its own coverage, applied one
            # after another. Separate from the grime ramp on purpose -- grime is everywhere and
            # even, corrosion is in patches -- and separate from each other, which is the fix for
            # the version that read as copper: one mask meant one colour over the whole panel.
            for scale, detail, lo, hi, colour in (
                (9.0, 8.0, 0.62, 0.80, RUST),        # broad rust, where water has run
                (17.0, 6.0, 0.72, 0.80, RUST_DARK),  # small, hard-edged pits inside it
                (5.0, 4.0, 0.78, 0.88, VERDIGRIS),   # a little verdigris, rarest of the three
            ):
                n = nt.nodes.new("ShaderNodeTexNoise")
                n.inputs["Scale"].default_value = scale
                n.inputs["Detail"].default_value = detail
                r = nt.nodes.new("ShaderNodeValToRGB")
                r.color_ramp.elements[0].position = lo
                r.color_ramp.elements[1].position = hi
                mx = nt.nodes.new("ShaderNodeMix")
                mx.data_type = "RGBA"
                mx.inputs["B"].default_value = (*colour, 1.0)
                nt.links.new(n.outputs["Fac"], r.inputs["Fac"])
                nt.links.new(r.outputs["Color"], mx.inputs["Factor"])
                nt.links.new(out, mx.inputs["A"])
                out = mx.outputs["Result"]
        nt.links.new(out, b.inputs["Base Color"])
        rmix = nt.nodes.new("ShaderNodeMath")
        rmix.operation = "MULTIPLY_ADD"
        rmix.inputs[1].default_value = 0.5
        rmix.inputs[2].default_value = rough if not corrode else min(1.0, rough + 0.18)
        nt.links.new(ramp.outputs["Color"], rmix.inputs[0])
        nt.links.new(rmix.outputs["Value"], b.inputs["Roughness"])
    if glow:
        b.inputs["Emission Color"].default_value = (*rgb, 1.0)
        b.inputs["Emission Strength"].default_value = rf.GLOW_EMISSION
    MATS[key] = m
    return m


def bevel(obj, width=0.03):
    """Round every visible edge so the key light catches it (house style).

    THE WIDTH IS UNEVEN ON PURPOSE (Truls, #252). One bevel width across a whole machine is itself
    a kind of perfection: every corner catches the sun with the same highlight and the result reads
    as one extruded object. A spread of 0.75 to 1.6 of the nominal width is invisible as a number
    and enough that no two corners are the same.
    """
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width * random.uniform(0.75, 1.6)
    mod.segments = 2


def box(name, size, loc, material, glow=False, rot=(0, 0, 0), bev=0.03, corrode=False):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = size
    o.data.materials.append(mat(material, glow, corrode))
    if bev:
        bevel(o, bev)
    return o


def cyl(name, radius, depth, loc, material, axis="Z", glow=False, rot=None, verts=48, corrode=False):
    rot = rot or {"Z": (0, 0, 0), "X": (0, math.pi / 2, 0), "Y": (math.pi / 2, 0, 0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=loc, rotation=rot, vertices=verts)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(mat(material, glow, corrode))
    bevel(o, 0.02)
    return o


def dent(obj, centre, radius, depth, cuts=14):
    """Strike a hollow into an object, around a world-space point.

    Truls, #252: one drum should have a significant dent. A primitive cylinder has vertices only at
    its two ends, so there is nothing in the middle to move -- the mesh is subdivided first, and
    the push is toward the object's own vertical axis so the hollow follows the curve instead of
    flattening a facet. Falloff is squared, which reads as struck metal rather than as a bite.
    """
    import bmesh
    from mathutils import Vector

    bpy.context.view_layer.update()                  # obj.scale was set after it was created
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    mw, inv = obj.matrix_world, obj.matrix_world.inverted().to_3x3()
    c = Vector(centre)
    for v in bm.verts:
        world = mw @ v.co
        d = (world - c).length
        if d >= radius:
            continue
        axis = Vector((mw.translation.x, mw.translation.y, world.z))
        outward = world - axis
        if outward.length < 1e-6:
            continue
        v.co -= inv @ (outward.normalized() * depth * (1 - d / radius) ** 2)
    moved = sum(1 for v in bm.verts
                if (mw @ v.co - c).length < radius)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    print(f"DENT {obj.name}: {moved} vertices inside the strike")


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
    """An H-profile beam: two flanges and a web, along `axis`.

    ALMOST STRAIGHT, NOT STRAIGHT (Truls, #252). A rolled beam bolted into a frame is out by a few
    millimetres and a fabricated one is out by more; a grid of perfectly parallel beams is the
    thing that says "computer". The whole beam is shifted by up to 0.02 tiles and tilted by up to
    0.012 rad -- about 1 px of lean over a two-tile post at 64 px a tile, which is under the
    detail floor as a feature and over it as an impression. The three sub-boxes take the same
    rotation about their own centres rather than about the beam's; at this angle the shear between
    web and flange is under two thousandths of a tile, which is nothing.
    """
    loc = (jitter(loc[0], 0.02), jitter(loc[1], 0.02), jitter(loc[2], 0.012))
    rot = (jitter(0, 0.012), jitter(0, 0.012), jitter(0, 0.012))
    if axis == "Z":
        box(f"{name}-web", (web, depth - 0.05, length), loc, material, bev=0, rot=rot)
        for sx in (-1, 1):
            box(f"{name}-f{sx}", (flange, web, length), (loc[0] + sx * 0, loc[1] + sx * (depth / 2), loc[2]), material, bev=0.01, rot=rot)
    elif axis == "Y":
        box(f"{name}-web", (web, length, depth - 0.05), loc, material, bev=0, rot=rot)
        for sz in (-1, 1):
            box(f"{name}-f{sz}", (flange, length, web), (loc[0], loc[1], loc[2] + sz * (depth / 2)), material, bev=0.01, rot=rot)
    else:
        box(f"{name}-web", (length, web, depth - 0.05), loc, material, bev=0, rot=rot)
        for sz in (-1, 1):
            box(f"{name}-f{sz}", (length, flange, web), (loc[0], loc[1], loc[2] + sz * (depth / 2)), material, bev=0.01, rot=rot)


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
    # Corroded, and it is the only part that is: it is the face the reactor's energy arrives
    # through, hot and wet and outdoors, and it was the one surface Truls called too polished (#252).
    #
    # ALMOST STRAIGHT (Truls, #252). Fourteen tiles of dead-straight extrusion is the most
    # machine-made thing on the model. A yaw of MAN_YAW radians walks the ends about 0.04 tiles --
    # two or three pixels of lean over the full length, read as a fabrication that is out rather
    # than as a bend. Everything sitting on the manifold takes the SAME yaw and the x offset that
    # goes with it (-y * yaw), or the channel and its grille would slide off the panel they sit on.
    MAN_YAW = jitter(0, 0.006)

    def on_manifold(y):
        return MX - y * MAN_YAW

    box("Manifold", (MAN_W, L - 0.2, MAN_H), (MX, 0, SLAB + MAN_H / 2), "body", corrode=True,
        rot=(0, 0, MAN_YAW))
    for i in range(6):
        y = -HALF_L + 0.1 + (i + 1) * (L - 0.2) / 7
        seam(f"ManifoldSeam{i}", (MAN_W + 0.02, 0.05, MAN_H - 0.2), (on_manifold(y), y, SLAB + MAN_H / 2),
             rot=(0, 0, MAN_YAW))
    rivets("ManifoldRivetsTop", (on_manifold(-HALF_L + 0.3) - MAN_W / 2 + 0.08, -HALF_L + 0.3, SLAB + MAN_H + 0.01),
           (on_manifold(HALF_L - 0.3) - MAN_W / 2 + 0.08, HALF_L - 0.3, SLAB + MAN_H + 0.01), 28)
    # energy channel along the TOP of the manifold, where the camera sees it; glows when working
    box("ManifoldBand", (MAN_W * 0.45, L - 0.6, 0.06), (MX + 0.05, 0, SLAB + MAN_H + 0.01), "energy",
        glow=True, rot=(0, 0, MAN_YAW))
    for i in range(14):
        y = -HALF_L + 0.6 + i * (L - 1.2) / 13
        box(f"ManifoldGrille{i}", (MAN_W * 0.5, 0.05, 0.05), (on_manifold(y) + 0.05, y, SLAB + MAN_H + 0.04),
            "dark", bev=0, rot=(0, 0, MAN_YAW))

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
    # A conduit run down the east frame with clamps, and diagonal braces in two bays. Both are here
    # because the frame read as an empty crate (Truls, #252): the bays were identical and had
    # nothing in them, so fifteen tiles of machine carried three drums and air.
    pipe("Conduit", [(EX - 0.12, -HALF_L + 0.4, SLAB + FRAME_H - 0.18),
                     (EX - 0.14, 0, SLAB + FRAME_H - 0.22),
                     (EX - 0.12, HALF_L - 0.4, SLAB + FRAME_H - 0.18)], 0.07, "dark")
    for i, y in enumerate(post_ys):
        torus(f"ConduitClamp{i}", 0.1, 0.03, (EX - 0.13, y, SLAB + FRAME_H - 0.2), "metal",
              rot=(math.pi / 2, 0, 0))
    # Two bays closed with a painted panel instead of left open -- the machine had no colour of its
    # own next to Krastorio 2's yellow, and these are where there is area to give it some (#252).
    for i, k in enumerate((2, 5)):
        y0, y1 = post_ys[k], post_ys[k + 1]
        box(f"BayPanel{i}", (0.07, (y1 - y0) * 0.86, 1.05), (EX - 0.05, (y0 + y1) / 2, SLAB + 0.95),
            "paint", rot=(0, 0, jitter(0, 0.008)))
        rivets(f"BayPanelRivets{i}", (EX - 0.1, y0 + 0.25, SLAB + 1.42), (EX - 0.1, y1 - 0.25, SLAB + 1.42),
               5, r=0.035)
    for i, k in enumerate((1, 4)):                    # two bays only: a braced frame, not a lattice
        dy, dz = post_ys[k + 1] - post_ys[k], (FRAME_H - 0.5) * (1 if i == 0 else -1)
        box(f"Brace{i}", (0.06, math.hypot(dy, dz), 0.14),
            (EX, (post_ys[k] + post_ys[k + 1]) / 2, SLAB + FRAME_H / 2), "frame",
            rot=(math.atan2(dz, dy), 0, 0), bev=0.01)

    # South end wall: a closed panel the camera can see, between manifold and cabinet.
    box("EndWall", (W - MAN_W - 0.3, 0.16, 1.15), (MXE + (EX - MXE) / 2 - 0.05, -HALF_L + 0.12, SLAB + 0.575), "paint")
    seam("EndWallSeam", (0.04, 0.18, 0.95), (MXE + (EX - MXE) / 2 - 0.9, -HALF_L + 0.12, SLAB + 0.575))
    rivets("EndWallRivets", (MXE + 0.2, -HALF_L + 0.03, SLAB + 1.0), (EX - 0.3, -HALF_L + 0.03, SLAB + 1.0), 9, r=0.04)
    box("EndWallVent", (0.9, 0.06, 0.4), (MXE + (EX - MXE) / 2 + 0.3, -HALF_L + 0.03, SLAB + 0.55), "dark", bev=0)

    # -- three drums: rib bands, weld seam, cap, relief valve. Not identical.
    DRUM_H = 2.3
    DX = 0.35
    drum_ys = (-4.6, 0.0, 4.6)
    DENTED = 2                      # the north drum, the one the layout shot leads with
    for i, y in enumerate(drum_ys):
        r = jitter(1.05, 0.04)
        h = jitter(DRUM_H, 0.08)
        z0 = SLAB + 0.5
        d = cyl(f"Drum{i}", r, h, (DX, y, z0 + h / 2), "metal", verts=64)
        d.scale = (1.0, jitter(1.0, 0.03), 1.0)
        ribs = [torus(f"Drum{i}Rib{k}", r + 0.015, 0.035, (DX, y, z0 + h * frac), "dark")
                for k, frac in enumerate((0.3, 0.7))]
        if i == DENTED:
            # SOUTH FLANK, because the camera stands south of the machine looking north: a drum
            # shows its cap and its south side, and a hollow struck anywhere else hides behind the
            # drum's own top.
            #
            # AND THE RIBS TAKE THE SAME STRIKE. That is what finally made it read (Truls, #252:
            # "I can see the dent, but it is not very visible"). Denting the shell alone left the
            # two rib bands running dead straight across the hollow -- they are separate objects
            # and do not deform with it -- and a straight band over a curved dent cancels it out,
            # which is why every earlier attempt had to be widened and still went unnoticed. With
            # the bands bending into it the strike can stay compact and still be obvious: 0.62
            # across, 0.42 deep, centred between the two.
            strike = (DX + 0.25, y - r, z0 + h * 0.5)
            dent(d, strike, 0.62, 0.42)
            for rib in ribs:                     # already 48x12; a few cuts is plenty
                dent(rib, strike, 0.62, 0.42, cuts=4)
        seam(f"Drum{i}Weld", (0.03, 2 * r + 0.02, 0.04), (DX + r - 0.02, y, z0 + h * 0.4), rot=(0, 0, jitter(0, 0.2)))
        cyl(f"Drum{i}Cap", r * 0.6, 0.18, (DX, y, z0 + h + 0.09), "metal")
        # A bolted flange where the cap meets the drum, and a ring of bolts on it: the drum tops are
        # what the camera sees most of, and they were bare (#252).
        torus(f"Drum{i}CapFlange", r * 0.62, 0.05, (DX, y, z0 + h + 0.01), "metal")
        for k in range(10):
            a = 2 * math.pi * k / 10
            bpy.ops.mesh.primitive_cylinder_add(
                radius=0.035, depth=0.05, vertices=8,
                location=(DX + r * 0.62 * math.cos(a), y + r * 0.62 * math.sin(a), z0 + h + 0.05))
            bpy.context.object.name = f"Drum{i}CapBolt{k}"
            bpy.context.object.data.materials.append(mat("dark"))
        # relief valve: a stub, a body and a little cap, off-centre so rotations differ.
        # BARE METAL WITH A STEAM BAND, not a steam-coloured body. The accent is near white, and a
        # whole valve in it blew out on the drum tops (Truls, #252); the house style already says an
        # accent is a band and never a body, so this was the model disagreeing with it.
        vx, vy = DX + r * 0.45, y - r * 0.3
        cyl(f"Drum{i}ValveStem", 0.09, 0.35, (vx, vy, z0 + h + 0.35), "metal", verts=24)
        cyl(f"Drum{i}ValveBody", 0.16, 0.22, (vx, vy, z0 + h + 0.6), "dark", verts=24)
        torus(f"Drum{i}ValveBand", 0.17, 0.03, (vx, vy, z0 + h + 0.6), "steam")
        cyl(f"Drum{i}ValveCap", 0.07, 0.25, (vx + 0.18, vy, z0 + h + 0.6), "metal", axis="X", verts=16)
        # A gauge cluster at the drum's foot on the east side, and a short handwheel valve beside
        # it: the deck between the drums read as empty.
        gx, gy = DX + r + 0.32, y + jitter(0.55, 0.15)
        box(f"Drum{i}Gauges", (0.26, 0.58, 0.46), (gx, gy, SLAB + 0.9), "paint")
        for k in range(2):
            cyl(f"Drum{i}Gauge{k}", 0.13, 0.06, (gx + 0.15, gy - 0.17 + k * 0.34, SLAB + 0.95),
                "steam", axis="X", verts=20)
        cyl(f"Drum{i}Wheel", 0.28, 0.05, (gx + 0.02, gy - 0.72, SLAB + 0.85), "dark", axis="Y", verts=24)
        cyl(f"Drum{i}WheelStem", 0.07, 0.36, (gx + 0.02, gy - 0.55, SLAB + 0.85), "metal", axis="Y", verts=12)
        torus(f"Drum{i}WheelRim", 0.28, 0.05, (gx + 0.02, gy - 0.72, SLAB + 0.85), "metal",
              rot=(math.pi / 2, 0, 0))
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
    # A BAND, not the half-tile steam-coloured block this used to be: near-white at that size read
    # as a lamp on the middle drum (Truls, #252).
    torus("HeaderBand", 0.22, 0.05, (DX, 0, HZ), "steam", rot=(math.pi / 2, 0, 0))
    drop_top = (DX + 0.25, 0.0, HZ)
    pipe("HeaderDrop", [drop_top, (1.2, jitter(0, 0.1), HZ - 0.6), (1.5, 0.0, 1.0), (HALF_W - 0.5, 0.0, 0.7)],
         0.19, "metal", corrugate=0.45)

    # -- cabinet, south-east corner: the one asymmetry. Seams and a blue panel.
    CAB = (0.8, 1.3, 1.7)
    cpos = (HALF_W - 0.55, -HALF_L + 0.95, SLAB + CAB[2] / 2)
    box("Cabinet", CAB, cpos, "paint")
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

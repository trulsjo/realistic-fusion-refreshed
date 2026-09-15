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

# ---- shared parts ---------------------------------------------------------------------------
#
# models/rf_parts.py holds every mesh helper both machines use, and `mat` below is the one thing
# that stays here: this machine's palette and its own weathering. `use` installs it, and the
# helpers that build a surface -- `box`, `cyl`, `torus`, `pipe` -- forward whatever keyword
# flags a call gives them straight back to it (#340). `hbeam`, `rivets` and `seam` pick their
# own material and take no flags; rf_parts' own docstring says why.
#
# The names come in bare rather than behind a `parts.` prefix: they are the vocabulary this
# file is written in, and prefixing 72 call sites would be the diff that hides whether
# anything else moved. Named one by one rather than starred, so what this file uses can be
# read off the import line -- and `bevel` is NOT among them: every machine's bevels are put
# on from inside the helpers, so importing it here only made a name nothing calls.
import rf_parts  # noqa: E402
from rf_parts import box, cyl, dent, hbeam, jitter, pipe, rivets, seam, torus  # noqa: E402,F401

args = rf.script_args()
out = args[0] if args else os.path.join(HERE, "heat-exchanger.blend")
variant = args[1] if len(args) > 1 else "machine"
random.seed(7)  # imperfections are deterministic: same script, same model

geo_path = os.path.join(HERE, "geometry.json")
geo = json.load(open(geo_path, encoding="utf-8"))
(x0, y0), (x1, y1) = geo["collision_box"]
# THE BODY IS BUILT LONG AXIS NORTH-SOUTH AND TURNED AFTERWARDS. Every part below is placed in the
# frame the look note was accepted in (#252): five wide along X, fifteen long along Y, the
# manifold on the west face. ADR 0031 (#275) then declared the same machine fifteen wide by five
# tall with the energy face north -- the same object seen along a different axis, and the note is
# left as written. So W and L are the short and long extents whichever way the box is declared,
# and when the declared box is wider than it is tall the finished body is turned a quarter turn so
# the manifold faces north. The sockets are placed AFTER the turn, in the declared frame, so they
# land where the prototype says regardless.
W, L = sorted((x1 - x0, y1 - y0))          # 4.5 x 14.5, the body's own frame
HALF_W, HALF_L = W / 2, L / 2
TURNED = (x1 - x0) > (y1 - y0)

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


rf_parts.use(mat)

# ---- the machine --------------------------------------------------------------------------
if variant == "cube":
    box("Cube", (1, 1, 1), (0, 0, 0.5), "body")
else:
    SLAB = 0.25
    box("Slab", (W, L, SLAB), (0, 0, SLAB / 2), "frame")
    seam("SlabSeam", (W + 0.02, 0.05, 0.05), (0, 0, SLAB))
    seam("SlabSeam2", (0.05, L + 0.02, 0.05), (0.6, 0, SLAB))

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
        box(f"ManifoldGrille{i}", (MAN_W * 0.5, 0.06, 0.06), (on_manifold(y) + 0.05, y, SLAB + MAN_H + 0.04),
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
    #
    # WITH AN OPENING WHERE THE STEAM OUTLET RUN COMES DOWN (Truls, #275). That run has to get from
    # a drum cap to a socket that lives UNDER this deck, so it crosses the deck's plane somewhere.
    # The only descent that clears the frame's own beams -- RailE2 along the east posts, and the
    # cross rails at the post lines -- is at OUTLET_X, which is inside the deck. So the deck gives
    # it a floor opening, which is what a deck has where a pipe drops through it; the alternative
    # was a hose visibly cutting a slat.
    OUTLET_X, OUTLET_Y = 1.80, 1.45
    for i in range(30):
        y = -HALF_L + 0.5 + i * (L - 1.0) / 29
        if abs(y - OUTLET_Y) < 0.30:
            continue
        box(f"Slat{i}", (W - MAN_W - 0.7, 0.06, 0.06), (0.35, y, SLAB + 0.5), "dark", bev=0)
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
    seam("EndWallSeam", (0.05, 0.18, 0.95), (MXE + (EX - MXE) / 2 - 0.9, -HALF_L + 0.12, SLAB + 0.575))
    rivets("EndWallRivets", (MXE + 0.2, -HALF_L + 0.03, SLAB + 1.0), (EX - 0.3, -HALF_L + 0.03, SLAB + 1.0), 9, r=0.04)
    box("EndWallVent", (0.9, 0.06, 0.4), (MXE + (EX - MXE) / 2 + 0.3, -HALF_L + 0.03, SLAB + 0.55),
        "dark", bev=0, read=0.4)

    # -- three drums: rib bands, weld seam, cap, relief valve. Not identical.
    DRUM_H = 2.3
    DX = 0.35
    drum_ys = (-4.6, 0.0, 4.6)
    DENTED = 2                      # the north drum in the body's frame; the east one once turned
    cap_tops = []                   # (y, z) of each drum's cap, for the header to clear and collect
    for i, y in enumerate(drum_ys):
        r = jitter(1.05, 0.04)
        h = jitter(DRUM_H, 0.08)
        z0 = SLAB + 0.5
        cap_tops.append((y, z0 + h + 0.18))
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
            #
            # STRUCK IN THE FRAME THE CAMERA WILL SEE. The body is turned a quarter turn after it
            # is built (TURNED, above), and a hollow on the body's south flank would end up facing
            # west and hide. The turn maps the body's east onto the declared south, so when the body
            # is going to be turned the strike goes on the east flank instead.
            strike = (DX + r, y - 0.25, z0 + h * 0.5) if TURNED else (DX + 0.25, y - r, z0 + h * 0.5)
            dent(d, strike, 0.62, 0.42)
            for rib in ribs:                     # already 48x12; a few cuts is plenty
                dent(rib, strike, 0.62, 0.42, cuts=4)
        seam(f"Drum{i}Weld", (0.05, 2 * r + 0.02, 0.05), (DX + r - 0.02, y, z0 + h * 0.4), rot=(0, 0, jitter(0, 0.2)))
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
                "steam", axis="X", verts=20, read=0.26)
        # BACK TO 0.05, and judged on its face. #339 took this to 0.06 because the floor was
        # reading its edge; with `read` the disc is measured across, so it keeps the thickness it
        # was drawn with.
        cyl(f"Drum{i}Wheel", 0.28, 0.05, (gx + 0.02, gy - 0.72, SLAB + 0.85), "dark", axis="Y",
            verts=24, read=0.56)
        cyl(f"Drum{i}WheelStem", 0.07, 0.36, (gx + 0.02, gy - 0.55, SLAB + 0.85), "metal", axis="Y", verts=12)
        torus(f"Drum{i}WheelRim", 0.28, 0.05, (gx + 0.02, gy - 0.72, SLAB + 0.85), "metal",
              rot=(math.pi / 2, 0, 0))
        # glowing feed line from the manifold to the foot of the drum, under the deck
        pipe(f"Feed{i}", [(MX + MAN_W / 2, y + jitter(0, 0.3), SLAB + 0.42),
                          (jitter(-0.7, 0.15), y + jitter(0, 0.2), SLAB + jitter(0.4, 0.03)),
                          (DX - r * 0.7, y, SLAB + 0.45)], 0.1, "energy", glow=True)

    # -- steam: three corrugated hose runs, each one BENDING DOWN ONTO A DRUM CAP (Truls, #275).
    #
    # THE HEADER USED TO COLLECT NOTHING. It was a single hose that passed over all three drums and
    # carried on to the outlet, touching no drum on the way -- and the outlet leg then went straight
    # through the middle drum and through a cross rail on its way down. A header on three drums is
    # three runs: each end drum sends its steam to the middle drum, and the middle drum sends the
    # lot out. So the middle drum carries THREE cap connections and each end drum one.
    #
    # EVERY RUN LEAVES AND LANDS VERTICALLY. The first two control points of a run are stacked in z,
    # which makes the Bezier's tangent at the cap straight down, so the hose stands on the cap
    # instead of ending in mid-air beside it.
    #
    # A HOSE, BANDED AND BENT LIKE KRASTORIO 2'S. The old one was "not quite straight" with a ring
    # every 0.45 tiles, which at 64 px a tile is a ring every 29 px on a 24 px pipe: read as a
    # smooth tube with a few rings on it. The big hose on K2's reactor sheet -- the one crossing its
    # lower half -- bands at roughly its own radius, stands its ribs well proud, and swings clear of
    # its own line between supports. So 0.26 between rings on a 0.38-tile tube, each rib standing a
    # quarter of the radius proud, and a real sag in the unsupported span. Close enough together to
    # be the pipe's character, far enough apart that the tube shows between them, which is what
    # tells a corrugated hose from a spring. The material is unchanged; bare metal was never the
    # complaint.
    HEADER_R = 0.19
    HEADER_CORRUGATE, HEADER_BAND = 0.26, (1.24, 0.26)
    CAP_ENTRY = 0.34               # how far off a cap's centre a run lands: inside its ring of bolts
    mid_y, mid_cap = cap_tops[1]
    # THE GOOSENECK NEEDS ROOM, and the first attempt did not give it any: a run rose 0.22 off the
    # cap and then had to turn through ninety degrees, so the Bezier's own handles overshot and the
    # hose curled back over itself like a candy cane. Half a tile of straight rise turns the same
    # corner smoothly.
    #
    # The two drum-to-drum runs are kept LOW -- a third of a tile of rise and a shallow hang -- so
    # they read as hoses running between the drums rather than as three loops arching over the
    # machine. The outlet run is the one that needs height: it has to cross the middle drum's own
    # shoulder, so it rises further and keeps its gooseneck.
    RUN_Z = max(z for _, z in cap_tops) + 0.35
    SAG_Z = max(z for _, z in cap_tops) - 0.25     # clears the frame's top rails by about 0.65
    OUT_Z = max(z for _, z in cap_tops) + 0.55

    # The middle drum's cap carries THREE runs, so their landings are spread around it rather than
    # stacked on one line: the two neighbours land west of the cap's centre, north and south of each
    # other, and the outlet leaves due east. Any closer together and the three tangle on the cap.
    for i in (0, 2):
        y, cap = cap_tops[i]
        toward = 1 if y < mid_y else -1
        start = (DX, y + toward * CAP_ENTRY, cap)
        land = (DX - 0.29, mid_y - toward * 0.17)
        # A hose slung between two nozzles hangs below them, and there is nothing under this span
        # but open frame.
        sag = (DX + jitter(0.3 * toward, 0.06), (y + mid_y) / 2 + jitter(0, 0.15), SAG_Z)
        pipe(f"Header{i}", [start, (start[0], start[1], RUN_Z), sag,
                            (land[0], land[1], RUN_Z), (land[0], land[1], mid_cap)],
             HEADER_R, "metal", corrugate=HEADER_CORRUGATE, band=HEADER_BAND)

    # THE OUTLET RUN, AND ITS ROUTE IS THE POINT. In this file's frame, which is the body's own and
    # not the declared one: down off the middle cap, north around the drum, down outside it at
    # OUTLET_X -- which clears RailE2 along the east posts by a tenth of a tile, and sits at a y
    # with no cross rail on it -- then back SOUTH under the deck to the steam socket on the east
    # edge, which lives below the grating. (The quarter turn shows that last leg running west, and
    # RailE2 lying along the declared south edge.) It passes through nothing but the deck opening.
    # NOT `out`: that is this script's output path, and shadowing it made Blender try to save the
    # model to a tuple after the whole machine had been built.
    OUTLET_DROP = HALF_W - 0.95     # 0.45 inboard of the steam socket's inner end; see the run below
    out_top = (DX + CAP_ENTRY, mid_y, mid_cap)
    pipe("HeaderOut", [
        out_top,
        (out_top[0], out_top[1], OUT_Z),                  # straight up off the cap, then over
        (0.95, mid_y + 0.95, OUT_Z - 0.25),               # across the drum's shoulder, above its cap
        (OUTLET_X, OUTLET_Y, SLAB + 2.10),
        (OUTLET_X, OUTLET_Y, SLAB + 0.37),
        (OUTLET_X - 0.05, mid_y + 0.55, SLAB + 0.32),
        # AND DOWN INTO THE SLAB, since #343 dropped the steam socket to pipe height: the socket's
        # inner end is inside the stone now, so a run that stopped where this one used to stop
        # would end in mid-air above it. Stacked in z on the point before it, so the tube turns
        # down and meets the floor square rather than glancing into it.
        #
        # IT GOES DOWN SHORT OF THE SOCKET RATHER THAN ONTO IT. The socket's inner end is at
        # HALF_W - 0.5 in this frame, and a floor rim there -- a ring half a tile across, at the
        # height the socket now lies at -- would pass straight through the tube. OUTLET_DROP is far
        # enough in that the rim clears it and near enough that a player reads the pipe going into
        # the floor and the pipe leaving the wall as one pipe.
        (OUTLET_DROP, mid_y, SLAB + 0.30),
        (OUTLET_DROP, mid_y, SLAB - 0.02),
    ], HEADER_R, "metal", corrugate=HEADER_CORRUGATE, band=HEADER_BAND)
    # A COLLAR WHERE IT GOES IN, AND NO HOLE UNDER IT. Unlike a socket's `port`, nothing is cut
    # here: the run simply stops 0.02 below the slab's top, inside solid stone, and the ring reads
    # as the flange round a penetration. At this camera the difference is invisible -- the pipe
    # covers what a hole would show -- so the geometry a boolean would add buys nothing. Said
    # plainly because "rimmed like the sockets are" is what this comment used to claim, and a
    # reader sent to find the modelled opening would not have found one.
    torus("OutletPortRim", 0.2, 0.05, (OUTLET_DROP, mid_y, SLAB + 0.02), "dark")
    # A BAND, not the half-tile steam-coloured block this used to be: near-white at that size read
    # as a lamp on the middle drum (Truls, #252). On the descent, which is the one stretch of the
    # steam route standing in the open where a band can be seen.
    torus("HeaderBand", 0.22, 0.05, (OUTLET_X, OUTLET_Y, SLAB + 1.45), "steam")

    # -- cabinet, south-east corner: the one asymmetry. Seams and a blue panel.
    CAB = (0.8, 1.3, 1.7)
    cpos = (HALF_W - 0.55, -HALF_L + 0.95, SLAB + CAB[2] / 2)
    box("Cabinet", CAB, cpos, "paint")
    seam("CabinetSeam", (CAB[0] + 0.02, 0.05, CAB[2] - 0.3), cpos)
    box("CabinetPanel", (0.06, 0.7, 0.5), (cpos[0] + CAB[0] / 2, cpos[1], cpos[2] + 0.3), "water",
        bev=0, read=0.5)
    rivets("CabinetRivets", (cpos[0] + CAB[0] / 2 + 0.01, cpos[1] - 0.5, cpos[2] - CAB[2] / 2 + 0.15),
           (cpos[0] + CAB[0] / 2 + 0.01, cpos[1] + 0.5, cpos[2] - CAB[2] / 2 + 0.15), 6)

    # -- the turn (see TURNED, at the top): the whole body so far, about Z, so the body's west --
    # the manifold, the reactor contact -- becomes the declared north. -90 degrees maps (x, y) to
    # (y, -x): west to north, east to south, north to east, south to west. matrix_world rather than
    # location and rotation separately, so a part with its own rotation and scale (the drums, the
    # braces, every torus) turns as one thing. The rig is not built yet, so nothing here turns it.
    if TURNED:
        from mathutils import Matrix
        bpy.context.view_layer.update()            # freshly added objects have no world matrix yet
        turn = Matrix.Rotation(-math.pi / 2, 4, "Z")
        for o in list(scene.collection.objects):
            o.matrix_world = turn @ o.matrix_world
        bpy.context.view_layer.update()

    # -- sockets: one per declared connection, body to footprint edge, accent band. `rf_parts.socket`
    # reads its boxes out of geometry.json, which is the DECLARED frame -- so they land after the
    # turn, where the prototype says, and nothing here is in the body's own HALF_W / HALF_L frame.
    #
    # THIS MACHINE DRAWS ITS SOCKETS TWO WAYS, AND THE PAIR ON EACH SHORT END DIFFER BY HALF A TILE
    # IN HEIGHT ON PURPOSE (#343). Read as a mistake it invites a "fix" that breaks the machine,
    # so: water west, water east and steam south carry no `connection_category`, a player plumbs
    # them with ordinary pipes, and models/house-style.md's rule binds them -- drawn at the height
    # AND the thickness of the pipe that plugs in, both measured rather than chosen (Truls,
    # 2026-09-13 and -14; #345 closed on the thickness). The three reactor-energy connections are
    # CONTAINED (ADR 0018, #86): no pipe, tank, wagon or pump a player can build will ever join
    # them, they bolt face to face against a reactor or the next exchanger in the row, and matching
    # them to a pipe would match them to something that cannot exist. So water at [-7, 1] sits low
    # and thin, and energy at [-7, -1] two tiles away on the same wall does neither -- that is the
    # machine working rather than the machine wrong.
    #
    # The three contained ones keep the 0.55 and the 0.3 this machine has always had: exempt from
    # the rule is not the same as bound by a different one, and a look chosen for them would be a
    # decision nobody has been asked for.
    CONTAINED_Z, CONTAINED_R = 0.55, 0.3

    def plumbable(c):
        """Whether a player can put an ordinary pipe on this connection.

        Read off `connection_category` rather than off a list of fluids, which is the same
        discriminator scripts/load-check.ps1's gate uses -- a connection left `default` is one a
        player can plumb. A fourth energy face added tomorrow is contained without this being
        touched, and a category taken off one makes it plumbable and brings it under the rule.
        """
        return not c["connection_category"]

    def socket_z(c):
        """How high a connection's stub is drawn: the pipe's height, or the contained one."""
        return rf_parts.SOCKET_Z if plumbable(c) else CONTAINED_Z

    def socket_r(c):
        """How thick it is drawn. 0.249 is solved the way the height is, and in the same place:
        this camera draws a tube 2.449 r tall on screen, vanilla's pipe body draws 0.609 tiles, so
        2.449 r = 0.609. models/house-style.md carries the arithmetic and rf-isotope-collector was
        the first machine to wear it."""
        return 0.249 if plumbable(c) else CONTAINED_R

    # ONE HELPER DRAWS THE STUB, THE BAND AND THE PORT (#352), because the collector had a second
    # copy of this loop and five more machines are coming. What stays here is the three functions
    # above: which connections are plumbable, and how high and how thick each kind is drawn. The
    # slab's top is at 0.25 and a lowered socket reaches through it, so a plumbable one gets a
    # modelled, rimmed opening rather than clipping the stone (Truls, 2026-09-14); a contained
    # socket stands clear above the slab and needs none, which is what passing `plumbable` decides.
    for c in geo["connections"]:
        rf_parts.socket(bpy.data.objects["Slab"], c, geo, socket_z(c), socket_r(c),
                        plumbable=plumbable(c))
    # water header along the base between the two end sockets, wherever the prototype puts them:
    # since #275 they sit off the short-end centre (`_ e _ w _`), so the header is read off the
    # geometry rather than drawn down the middle.
    UNIT = {"north": (0, -1), "east": (1, 0), "south": (0, 1), "west": (-1, 0)}   # Factorio frame

    def inboard(c, back=0.5, z=None):
        """`back` tiles inboard of the tile a connection stands on, at that connection's own socket
        height unless `z` says otherwise.

        NOT "the inner end of the socket", which is what this said on both machines that have one
        and is what put a run 0.2 tiles short of the stub it fed. The socket's inner face is half a
        tile inside the collision edge -- `rf_parts.socket`'s own `inner` -- so back=0.5 lands a
        quarter of a tile PAST it, further in, and anything larger stops shorter still. To reach
        INTO a stub, pass a `back` smaller than 0.5.
        """
        ux, uy = UNIT[c["direction"]]
        px, py = c["position"]
        return (px - back * ux, -(py - back * uy), socket_z(c) if z is None else z)

    # SINCE THE WATER SOCKETS DROPPED TO PIPE HEIGHT THIS HEADER ENDS IN THE SLAB, not on a stub
    # (#343), and it is the collector's lesson taken rather than relearnt. A header run at the
    # sockets' own 0.033 would be buried in stone for its whole length and draw nothing; a header
    # left where it was would stop in mid-air, above a socket that is now inside the floor. So it
    # stays under the grating where it reads, and turns DOWN into the slab at each end with a
    # collar where it goes in. A player reads a pipe entering the floor and a pipe leaving the wall
    # as the same pipe, which is what real plant looks like.
    #
    # AND IT STOPS SHORT OF THE SOCKETS RATHER THAN OVER THEM, which is why `back` is 0.9 and not
    # the 0.5 the call used to take. Mind what those mean: `inboard(c, 0.5)` is the inner edge of
    # the TILE the connection stands on, x = 6.5 here, while the socket's inner end is a quarter
    # tile further out at 7.25 - 0.5 = 6.75, the declared half extent less half a tile. So a floor
    # collar at 0.5 -- a ring half a tile across --
    # would reach exactly 6.75 and sit tangent to the tube's end cap. 0.9 puts the drop 0.4 tiles
    # further in, clear of it with room for the tube's own radius.
    HEADER_Z = 0.55
    water = [c for c in geo["connections"] if c["fluid"] == "water"]
    if len(water) == 2:
        a, b = inboard(water[0], back=0.9, z=HEADER_Z), inboard(water[1], back=0.9, z=HEADER_Z)
        mid = ((a[0] + b[0]) / 2 + jitter(0, 0.1), (a[1] + b[1]) / 2 + jitter(0, 0.1), 0.5)
        # Stacked control points in z at both ends, so the tube meets the floor square instead of
        # glancing into it and showing a slanted open mouth.
        pipe("WaterHeader", [(a[0], a[1], SLAB - 0.02), a, mid, b, (b[0], b[1], SLAB - 0.02)],
             0.13, "metal")
        for conn, end in zip(water, (a, b)):
            torus(f"WaterPortRim-{conn['direction']}", 0.2, 0.05, (end[0], end[1], SLAB + 0.02), "dark")

    # -- glowing feeds from the SHORT-END energy sockets into the manifold (Truls, #275).
    #
    # Without them those two sockets read as bare stubs bolted to the ends, carrying nothing: the
    # water pair is visibly joined by the header above, and the reactor-facing socket IS the
    # manifold -- it stands inside it -- so the two chaining sockets were the only connections on
    # the machine with no run behind them. Same material and same glow as the drum feeds, because
    # it is the same fluid arriving the same way, and they run under the grating at the drum feeds'
    # own height so all five read as one system.
    #
    # The manifold's inner face, in whichever frame the body ended up in: it was built along the
    # body's west face, and the quarter turn maps west to declared north (see TURNED).
    MANIFOLD_FACE = "north" if TURNED else "west"
    MANIFOLD_INNER = MX + MAN_W / 2
    FEED_Z = SLAB + 0.42

    def into_manifold(x, y, back=0.6):
        """A point on the manifold's inner face, `back` tiles in from (x, y) along the face."""
        step = math.copysign(back, -x if TURNED else -y)
        if TURNED:
            return (x + step, -MANIFOLD_INNER, FEED_Z)
        return (MANIFOLD_INNER, y + step, FEED_Z)

    for c in geo["connections"]:
        if rf.accent(c["fluid"]) != "energy" or c["direction"] == MANIFOLD_FACE:
            continue
        start = inboard(c, back=0.45)
        end = into_manifold(start[0], start[1])
        mid = ((start[0] + end[0]) / 2 + jitter(0, 0.08),
               (start[1] + end[1]) / 2 + jitter(0, 0.08),
               (start[2] + end[2]) / 2)
        pipe(f"EnergyFeed-{c['direction']}", [start, mid, end], 0.13, "energy", glow=True)

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

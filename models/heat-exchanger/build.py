"""Build the heat exchanger model from its look note, headless. This is what "regenerate" reruns.

    blender -b --python build.py -- [out.blend] [machine|cube]

Reads geometry.json beside this file for the collision box and the connections, so the sockets
land where the prototype declares them, and stamps the scene with that file's hash so render.py
can refuse a model whose geometry has moved on. Every shape is a primitive or a curve: no mesh is
imported (ADR 0030). The materials are procedural but for one CC0 image texture, a rust
photograph under the manifold's broad rust and the paint's weathering (ADR 0043, #805), kept
beside this file with its record in textures.json. `cube` builds a 1x1x1 calibration cube for measuring the camera. Written to heat-exchanger.blend beside this file
unless a path is given.

Drafts 2 and 3 follow Truls's reactions of 2026-09-04: imperfect drums (rib bands, weld seam,
relief valve), a corrugated header that is not quite straight, an open H-beam frame over a grating
instead of walls with glowing feed lines visible under it, a south end wall, panel seams and rivet
lines, procedural grime, and the energy channel on top of the manifold where the camera sees it.
"""
import json
import math
import os
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
from rf_parts import (bolts, box, cable_tray, casing, cyl, dent, fan_discs, grating_deck, hbeam,  # noqa: E402,F401
                      hose, loom, panels, pipe, rivets, seam, stream, torus, valve)
from rf_blender import ring, row, stack  # noqa: E402

args = rf.script_args()
out = args[0] if args else os.path.join(HERE, "heat-exchanger.blend")
variant = args[1] if len(args) > 1 else "machine"

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
# The way to the camera, in the body's frame: it stands south of the declared machine pitched
# rf.CAMERA_PITCH_DEG down, and the turn maps the declared south onto the body's east.
_PITCH = math.radians(rf.CAMERA_PITCH_DEG)
TOWARD_CAMERA = ((math.cos(_PITCH), 0.0, math.sin(_PITCH)) if TURNED
                 else (0.0, -math.cos(_PITCH), math.sin(_PITCH)))

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
#
# AND DOWN AGAIN AT THE DARK END ONLY (#801). Beside Krastorio 2's reactor the sheet's median was
# already close -- 66 of 255 against 51 -- but its darkest twentieth sat at 13 where K2's sits at 1:
# K2 has a near-black base and we had none. So frame, body and dark go down and paint stays where
# it was, which is what makes it a wider range rather than the uniformly muddy palette of
# 2026-09-05. Bare metal went down too, from 0.55 to 0.30 (Truls, #801, on seeing the drums and
# hoses still the pale mass beside K2): its colour only, so it keeps the gloss that gives it a
# bright rim where the key light lands. The highlights are now the paint and those rims.
PALETTE = {
    "body":   ((0.13, 0.14, 0.16), 0.72, 0.0),
    "frame":  ((0.02, 0.022, 0.025), 0.6, 0.2),
    "metal":  ((0.30, 0.30, 0.32), 0.35, 0.8),
    "dark":   ((0.14, 0.145, 0.155), 0.5, 0.7),
    "energy": ((1.00, 0.45, 0.10), 0.5, 0.0),
    "steam":  ((0.85, 0.88, 0.90), 0.5, 0.0),
    "water":  ((0.25, 0.55, 1.00), 0.5, 0.0),
    "plasma": ((0.55, 0.20, 1.00), 0.5, 0.0),
    # PAINT, not steel. Truls, #252: the machine needed some painted panels -- steel-on-steel gave
    # it no colour of its own beside Krastorio 2's, which is yellow. A matte industrial off-white
    # is high in value where the frame is low, so a panel reads as a panel rather than as more
    # body. The hue is my pick and easy to change: no fluid owns it, as none owns
    # the hazard yellow or the cable sheaths below.
    "paint":  ((0.58, 0.55, 0.47), 0.8, 0.0),
    # A MARKING, NOT A BODY (models/house-style.md, Palette; #801). It goes on the deck's two
    # walkway edges and the guard rail along the open side and nowhere else -- three elements, none
    # of them a panel, and never a fluid accent.
    "hazard": ((0.72, 0.55, 0.09), 0.55, 0.0),
    # The kit's cable sheaths (#803), taken whole so the loom's colours live in one place.
    **rf.CABLE_COLOURS,
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
# THE BROAD RUST IS A PHOTOGRAPH OF RUST (ADR 0043, #805): Poly Haven's rust_coarse_01, CC0, kept
# beside this file and recorded in textures.json. Noise at 64 px a tile washes out or turns into
# render noise, and the photograph has grain at every scale. It brings its grain and not its
# colour: scaled channel by channel by RUST over its own mean linear colour, measured off the file
# (2026-10-30), so the rust is the palette's on average and the value range #801 set is unmoved.
RUST_TEXTURE = "rust_coarse_01_diff_1k.jpg"
RUST_TEXTURE_MEAN = (0.129, 0.0436, 0.0152)
RUST_TEXTURE_TILES = 2.0               # one repeat of the image: it is about 2.2 m of steel
# AND THE PAINT IS WEATHERED BY THE SAME PHOTOGRAPH (Truls, #805): on the manifold alone it moved
# about 530 pixels of the north sheet by more than 3 of 255, which is too little to judge a texture
# by. The paint takes the photograph's value and not its hue -- its luminance over its own
# mean, measured off the file (2026-10-30) -- so a panel keeps its colour on average and gains the
# mottling of old paint. PAINT_GRAIN is how much of that it takes: at 1 the photograph's own spread,
# a fourteenth of it under half the mean and a twentieth over 1.8 times it.
RUST_TEXTURE_LUMA = 0.0597
PAINT_GRAIN = 1.0


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
                if colour is RUST:
                    nt.links.new(rf_parts.texture(nt, HERE, RUST_TEXTURE, RUST_TEXTURE_TILES,
                                                  tuple(c / m for c, m in zip(RUST, RUST_TEXTURE_MEAN))),
                                 mx.inputs["B"])
                nt.links.new(n.outputs["Fac"], r.inputs["Fac"])
                nt.links.new(r.outputs["Color"], mx.inputs["Factor"])
                nt.links.new(out, mx.inputs["A"])
                out = mx.outputs["Result"]
        if name == "paint":
            luma = nt.nodes.new("ShaderNodeRGBToBW")
            nt.links.new(rf_parts.texture(nt, HERE, RUST_TEXTURE, RUST_TEXTURE_TILES), luma.inputs[0])
            grain = nt.nodes.new("ShaderNodeMath")
            grain.operation = "MULTIPLY_ADD"            # 1 on average, whatever PAINT_GRAIN is
            grain.inputs[1].default_value = PAINT_GRAIN / RUST_TEXTURE_LUMA
            grain.inputs[2].default_value = 1.0 - PAINT_GRAIN
            nt.links.new(luma.outputs["Val"], grain.inputs[0])
            weathered = nt.nodes.new("ShaderNodeMix")
            weathered.data_type = "RGBA"
            weathered.blend_type = "MULTIPLY"
            weathered.inputs["Factor"].default_value = 1.0
            nt.links.new(out, weathered.inputs["A"])
            nt.links.new(grain.outputs["Value"], weathered.inputs["B"])
            out = weathered.outputs["Result"]
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


rf_parts.use(mat, geo, seed=7)  # each part's imperfections: its name and this, nothing else

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
    MAN_YAW = stream("Manifold").jitter(0, 0.006)

    def on_manifold(y):
        return MX - y * MAN_YAW

    box("Manifold", (MAN_W, L - 0.2, MAN_H), (MX, 0, SLAB + MAN_H / 2), "body", corrode=True,
        rot=(0, 0, MAN_YAW))
    # Each seam is named for where it stands along the manifold, as the frame's parts are (#827).
    # A seam is cut with no bevel and draws nothing, so its name moves no stream.
    for i in range(6):
        y = -HALF_L + 0.1 + (i + 1) * (L - 0.2) / 7
        seam(f"ManifoldSeam{y:+.2f}", (MAN_W + 0.02, 0.05, MAN_H - 0.2), (on_manifold(y), y, SLAB + MAN_H / 2),
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
    #
    # EACH POST LINE IS NAMED FOR WHERE IT STANDS, its y to two places with its sign, and every
    # part that stands on one is named for it (#827). A part draws from the stream of its name, so a
    # name numbered off a loop re-rolled every part after one inserted earlier in it.
    post_ys = [-HALF_L + 0.3 + k * (L - 0.6) / 6 for k in range(7)]
    posts = {f"{y:+.2f}": y for y in post_ys}
    for p, y in posts.items():
        hbeam(f"PostE{p}", FRAME_H, (EX, y, SLAB + FRAME_H / 2), axis="Z")
        hbeam(f"PostM{p}", FRAME_H, (MXE, y, SLAB + FRAME_H / 2), axis="Z")
        hbeam(f"Rail{p}", EX - MXE, ((EX + MXE) / 2, y, SLAB + FRAME_H), axis="X", depth=0.16, flange=0.14)
    hbeam("RailE", L - 0.4, (EX, 0, SLAB + FRAME_H), axis="Y", depth=0.16, flange=0.14)
    hbeam("RailM", L - 0.4, (MXE, 0, SLAB + FRAME_H), axis="Y", depth=0.16, flange=0.14)
    # The low rail along the open side is the guard rail a walkway behind it would have, and is
    # yellow for the reason one is (#801). The handwheel rims were tried first and hid behind it.
    # It is laid below, once OUTLET_Y is known.
    #
    # Grating deck under the drums, the kit's (#835), laid below once the cabinet stands: open
    # bars, so the feed lines below stay visible.
    #
    # WITH AN OPENING WHERE THE STEAM OUTLET RUN COMES DOWN (Truls, #275). That run has to get from
    # a drum cap to a socket that lives UNDER this deck, so it crosses the deck's plane somewhere.
    # The only descent that clears the frame's own beams -- RailE2 along the east posts, and the
    # cross rails at the post lines -- is at OUTLET_X, which is inside the deck. So the deck gives
    # it a floor opening, which is what a deck has where a pipe drops through it; the alternative
    # was a hose visibly cutting a bar.
    #
    # 1.52 AND NOT 1.80, so the descent's rings clear the frame (#825). They stand 0.285 off the
    # hose's axis, and at 1.80 they reached 2.085, past the conduit's inner face at 1.92 and the
    # top rail's inner flange at 2.03: the run passed through one or the other, and which one turned
    # on where its rings fell. The descent also bows about 0.07 east of its control points, so 1.60
    # still put a ring 0.02 into the conduit (measured on the built model).
    OUTLET_X, OUTLET_Y = 1.52, 1.45
    #
    # THE GUARD RAIL, IN LENGTHS BETWEEN THE POSTS, NOT ONE BEAM ALONG THEM (Truls, 2026-10-29). As
    # one beam it ran through every post, and a beam fifteen tiles long tilted by `hbeam`'s jitter
    # drifts across the post line: it stood in front of some posts and inside others, and it ran
    # into the cabinet and across its blue panel. Each length stops RAIL_STOP short of a post's
    # centre, which leaves 0.045 beyond the flange; the post and the length each jitter by up to
    # 0.02, so together they close it by at most 0.04. The first starts at the cabinet's north
    # face, and the length under the steam outlet is cut round its descent, whose rings reached
    # past the rail's inner flange while OUTLET_X was 1.80. They stop short of it since #825 moved
    # the descent in, and the cut is kept as it was. RailE2 is still the rail's name. Each length
    # is named for where it starts, the cabinet or a post line, as RailE2Cab and RailE2-2.32, and
    # the two halves of the cut one end in S and N (#827). It moved here from beside RailE so that
    # OUTLET_Y is known.
    CAB_N = -HALF_L + 1.6            # the cabinet's north face; the cabinet itself is built below
    RAIL_STOP, OUTLET_GAP = 0.16, 0.6
    spans = []
    starts = [("Cab", CAB_N)] + [(p, y + RAIL_STOP) for p, y in list(posts.items())[1:-1]]
    for (p, a), b in zip(starts, post_ys[1:]):
        b -= RAIL_STOP
        spans += ([(p + "S", a, OUTLET_Y - OUTLET_GAP), (p + "N", OUTLET_Y + OUTLET_GAP, b)]
                  if a < OUTLET_Y < b else [(p, a, b)])
    for p, a, b in spans:
        hbeam(f"RailE2{p}", b - a, (EX, (a + b) / 2, SLAB + 0.9), axis="Y",
              depth=0.12, flange=0.12, material="hazard")
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
    #
    # THE BACKING IS DARK AND THE PAINT IS IN INSET PANELS ON IT (#802), so each bay is six plates
    # with dark seams rather than one off-white slab: the seams read against paint where they would
    # vanish into body steel. Placed with the kit below; the yaw is drawn here, from the bay's
    # own stream, and the plates take it.
    #
    # SET BACK BEHIND THE GUARD RAIL (the branch's pre-PR review). The rail runs across both bays
    # at RailE2's height, and with the plates standing proud of a backing on the post line they
    # passed through it; the backing already did. Set back BAY_BACK, the plates' faces stop short
    # of the rail's flange and the rail runs in front of them. The rivets keep their place behind
    # the backing. 0.14 rather than the 0.12 it was set at, which left 0.03 for the bay's yaw and the
    # rail's own jitter to share, and on #825's draws a plate met the rail.
    BAY_BACK = 0.14
    bays = []
    for k in (2, 5):                                  # each bay named for the post line it starts at
        p, y0, y1 = f"{post_ys[k]:+.2f}", post_ys[k], post_ys[k + 1]
        yaw = stream(f"BayPanel{p}").jitter(0, 0.008)
        box(f"BayPanel{p}", (0.07, (y1 - y0) * 0.86, 1.05), (EX - 0.05 - BAY_BACK, (y0 + y1) / 2, SLAB + 0.95),
            "dark", rot=(0, 0, yaw))
        bays.append((p, (EX - 0.015 - BAY_BACK, (y0 + y1) / 2, SLAB + 0.95), ((y1 - y0) * 0.86, 1.05), yaw))
        rivets(f"BayPanelRivets{p}", (EX - 0.1 - BAY_BACK, y0 + 0.25, SLAB + 1.42),
               (EX - 0.1 - BAY_BACK, y1 - 0.25, SLAB + 1.42), 5, r=0.035)
    for k, rise in ((1, 1), (4, -1)):                 # two bays only: a braced frame, not a lattice
        dy, dz = post_ys[k + 1] - post_ys[k], (FRAME_H - 0.5) * rise
        box(f"Brace{post_ys[k]:+.2f}", (0.06, math.hypot(dy, dz), 0.14),
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
    # Named south, middle and north in the body's frame, and every part of a drum takes its name
    # (#827).
    DRUMS = (("S", -4.6), ("Mid", 0.0), ("N", 4.6))
    DENTED = "N"                    # the north drum in the body's frame; the east one once turned
    cap_tops = {}                   # (y, z) of each drum's cap, for the header to clear and collect
    drums = []                      # where each drum's valve and gauges landed, for the kit below
    for n, y in DRUMS:
        s = stream(f"Drum{n}")
        r = s.jitter(1.05, 0.04)
        h = s.jitter(DRUM_H, 0.08)
        z0 = SLAB + 0.5
        cap_tops[n] = (y, z0 + h + 0.18)
        d = cyl(f"Drum{n}", r, h, (DX, y, z0 + h / 2), "metal", verts=64)
        d.scale = (1.0, s.jitter(1.0, 0.03), 1.0)
        ribs = [torus(f"Drum{n}Rib{band}", r + 0.015, 0.035, (DX, y, z0 + h * frac), "dark")
                for band, frac in (("Low", 0.3), ("High", 0.7))]
        if n == DENTED:
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
        # THE WELD STOPS 0.03 SHORT OF THE CABINET'S NORTH FACE (#827). It runs 2r + 0.02 along the
        # drum's east side, so the south drum's reached past CAB_N whenever its radius was drawn
        # over about 1.05, and stood in the cabinet. The north and middle drums are nowhere near.
        weld_half = min(r + 0.01, y - CAB_N - 0.03)
        seam(f"Drum{n}Weld", (0.05, 2 * weld_half, 0.05), (DX + r - 0.02, y, z0 + h * 0.4),
             rot=(0, 0, stream(f"Drum{n}Weld").jitter(0, 0.2)))
        cyl(f"Drum{n}Cap", r * 0.6, 0.18, (DX, y, z0 + h + 0.09), "metal")
        # A bolted flange where the cap meets the drum, and a ring of bolts on it: the drum tops are
        # what the camera sees most of, and they were bare (#252).
        torus(f"Drum{n}CapFlange", r * 0.62, 0.05, (DX, y, z0 + h + 0.01), "metal")
        # The ring of bolts is the kit's (#804), on the spots the hand-placed ones stood.
        bolts(f"Drum{n}CapBolt", ring((DX, y, z0 + h + 0.025), r * 0.62, 10))
        # relief valve: a stub, a body and a little cap, off-centre so rotations differ.
        # BARE METAL WITH A STEAM BAND, not a steam-coloured body. The accent is near white, and a
        # whole valve in it blew out on the drum tops (Truls, #252); the house style already says an
        # accent is a band and never a body, so this was the model disagreeing with it.
        vx, vy = DX + r * 0.45, y - r * 0.3
        cyl(f"Drum{n}ValveStem", 0.09, 0.35, (vx, vy, z0 + h + 0.35), "metal", verts=24)
        cyl(f"Drum{n}ValveBody", 0.16, 0.22, (vx, vy, z0 + h + 0.6), "dark", verts=24)
        torus(f"Drum{n}ValveBand", 0.17, 0.03, (vx, vy, z0 + h + 0.6), "steam")
        cyl(f"Drum{n}ValveCap", 0.07, 0.25, (vx + 0.18, vy, z0 + h + 0.6), "metal", axis="X", verts=16)
        # A gauge cluster at the drum's foot on the east side, and a short handwheel valve beside
        # it: the deck between the drums read as empty.
        gx, gy = DX + r + 0.32, y + stream(f"Drum{n}Gauges").jitter(0.55, 0.15)
        # THE HANDWHEEL STANDS CLEAR OF A BAY'S PLATES (#827), and the cluster moves with it. The
        # wheel stands 0.72 south of the gauges, and the middle drum's, drawn far enough south,
        # landed on the north end of the plates of the bay beside it, as a rim did on #824. Its rim
        # is 0.05 thick either side of its plane, so WHEEL_CLEAR is that and air.
        WHEEL_CLEAR = 0.07
        wy = gy - 0.72
        for _, centre, size, _ in bays:
            half = (size[0] - 0.12) / 2              # the plates, 0.06 inside the backing's ends
            lo, hi = centre[1] - half - WHEEL_CLEAR, centre[1] + half + WHEEL_CLEAR
            if lo < wy < hi:
                wy = hi if wy > centre[1] else lo
        gy = wy + 0.72
        box(f"Drum{n}Gauges", (0.26, 0.58, 0.46), (gx, gy, SLAB + 0.9), "paint")
        for side, dy in (("S", -0.17), ("N", 0.17)):
            cyl(f"Drum{n}Gauge{side}", 0.13, 0.06, (gx + 0.15, gy + dy, SLAB + 0.95),
                "steam", axis="X", verts=20, read=0.26)
        # BACK TO 0.05, and judged on its face. #339 took this to 0.06 because the floor was
        # reading its edge; with `read` the disc is measured across, so it keeps the thickness it
        # was drawn with.
        cyl(f"Drum{n}Wheel", 0.28, 0.05, (gx + 0.02, gy - 0.72, SLAB + 0.85), "dark", axis="Y",
            verts=24, read=0.56)
        drums.append({"name": n, "y": y, "r": r, "h": h, "z0": z0, "vx": vx, "vy": vy, "gx": gx, "gy": gy})
        cyl(f"Drum{n}WheelStem", 0.07, 0.36, (gx + 0.02, gy - 0.55, SLAB + 0.85), "metal", axis="Y", verts=12)
        torus(f"Drum{n}WheelRim", 0.28, 0.05, (gx + 0.02, gy - 0.72, SLAB + 0.85), "metal",
              rot=(math.pi / 2, 0, 0))
        # glowing feed line from the manifold to the foot of the drum, under the deck
        #
        # IT CROSSES THE MID-LINE POSTS BESIDE THE DRUM'S POST, NOT THROUGH IT (#825). Each drum
        # stands within 0.04 of a post line, so a feed leaving the manifold at the drum's own y
        # went through the post or grazed its flange, and which one turned on its jitter. It
        # leaves on the side of the post the drum stands, FEED_CLEAR or a little more off the
        # post's centre: the flange's 0.115 and its jitter, the feed's 0.1, and air.
        FEED_CLEAR = 0.27
        s = stream(f"Feed{n}")
        post = min(post_ys, key=lambda p: abs(p - y))
        fy = post + (1 if y >= post else -1) * (FEED_CLEAR + s.uniform(0, 0.15))
        pipe(f"Feed{n}", [(MX + MAN_W / 2, fy, SLAB + 0.42),
                          (s.jitter(-0.7, 0.15), fy, SLAB + s.jitter(0.4, 0.03)),
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
    # its own line between supports. So 0.26 between rings on a 0.38-tile tube, each rib standing
    # half the radius proud, and a real sag in the unsupported span. (This said "a quarter" until
    # #803: the ring's own tube radius is about a quarter of the pipe's, and its centre circle
    # stands about a quarter out, so together it stands half.) Close enough together to be the
    # pipe's character, far enough apart that the tube shows between them, which is what tells a
    # corrugated hose from a spring. The material is unchanged; bare metal was never the
    # complaint.
    HEADER_R = 0.19
    HEADER_CORRUGATE, HEADER_BAND = 0.26, (1.24, 0.26)
    CAP_ENTRY = 0.34               # how far off a cap's centre a run lands: inside its ring of bolts
    mid_y, mid_cap = cap_tops["Mid"]
    # THE GOOSENECK NEEDS ROOM, and the first attempt did not give it any: a run rose 0.22 off the
    # cap and then had to turn through ninety degrees, so the Bezier's own handles overshot and the
    # hose curled back over itself like a candy cane. Half a tile of straight rise turns the same
    # corner smoothly.
    #
    # The two drum-to-drum runs are kept LOW -- a third of a tile of rise and a shallow hang -- so
    # they read as hoses running between the drums rather than as three loops arching over the
    # machine. The outlet run is the one that needs height: it has to cross the middle drum's own
    # shoulder, so it rises further and keeps its gooseneck.
    RUN_Z = max(z for _, z in cap_tops.values()) + 0.35
    SAG_Z = max(z for _, z in cap_tops.values()) - 0.25     # clears the frame's top rails by about 0.65
    OUT_Z = max(z for _, z in cap_tops.values()) + 0.55

    # The middle drum's cap carries THREE runs, so their landings are spread around it rather than
    # stacked on one line: the two neighbours land west of the cap's centre, north and south of each
    # other, and the outlet leaves due east. Any closer together and the three tangle on the cap.
    for n in ("S", "N"):                    # each named for the drum it leaves (#827)
        y, cap = cap_tops[n]
        toward = 1 if y < mid_y else -1
        start = (DX, y + toward * CAP_ENTRY, cap)
        land = (DX - 0.29, mid_y - toward * 0.17)
        # A hose slung between two nozzles hangs below them, and there is nothing under this span
        # but open frame.
        s = stream(f"Header{n}")             # `hose` carries on along it for the rings
        sag = (DX + s.jitter(0.3 * toward, 0.06), (y + mid_y) / 2 + s.jitter(0, 0.15), SAG_Z)
        hose(f"Header{n}", [start, (start[0], start[1], RUN_Z), sag,
                            (land[0], land[1], RUN_Z), (land[0], land[1], mid_cap)],
             HEADER_R, pitch=HEADER_CORRUGATE, band=HEADER_BAND)
        # A BLOCK VALVE AT THE SAG, the kit's (#833): the low point of the span, where the hose
        # passes through its control point, so the valve sits on the tube. The tube runs there close
        # to the chord between its two tops, which is what the valve is turned along: a Bezier's
        # auto handle lies along it only where the two tops are equally far. Measured on the built
        # model for #840, from each sag's handle: 1.8 degrees off on the south run, whose tops stand
        # 1.99 and 2.37 away, and none on the north, whose stand 2.14 and 2.14. Its wheel turns to
        # the camera, which in the body's frame stands east and above (TURNED; rf_blender's pitch),
        # and with open frame under the span and nothing over it, the wheel has the air it needs.
        valve(f"Header{n}Valve", sag, (land[0] - start[0], land[1] - start[1], 0.0), HEADER_R,
              TOWARD_CAMERA)

    # THE OUTLET RUN, AND ITS ROUTE IS THE POINT. In this file's frame, which is the body's own and
    # not the declared one: down off the middle cap, north around the drum, down outside it at
    # OUTLET_X -- where the guard rail, RailE2, is cut round it, and which sits at a y
    # with no cross rail on it -- then back SOUTH under the deck to the steam socket on the east
    # edge, which lives below the grating. (The quarter turn shows that last leg running west, and
    # RailE2 lying along the declared south edge.) It passes through nothing but the deck opening.
    # NOT `out`: that is this script's output path, and shadowing it made Blender try to save the
    # model to a tuple after the whole machine had been built.
    OUTLET_DROP = HALF_W - 0.95     # 0.45 inboard of the steam socket's inner end; see the run below
    out_top = (DX + CAP_ENTRY, mid_y, mid_cap)
    hose("HeaderOut", [
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
    ], HEADER_R, pitch=HEADER_CORRUGATE, band=HEADER_BAND)
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

    # -- kit parts: the grating deck (#835), in place of the thirty hand-placed slats: the same
    # span, thirty bars where they stood, and its top face where theirs was.
    #
    # ITS TWO ENDS ARE THE WALKWAY'S EDGES AND ARE YELLOW (#801): a deck edge is one of the things
    # a real plant paints so somebody sees it. They are its open edges too, and carry its toe
    # boards, yellow with them. The long east side does not: the gauge clusters and their handwheels stand out over
    # it, and the guard rail closes it.
    #
    # ITS OPENINGS ARE WHERE SOMETHING PASSES THROUGH IT: the steam outlet's descent, its rings
    # 0.285 off its axis and about 0.07 further east with its bow, and the cabinet, which stands on
    # the slab through the deck's south-east corner. The slats used to leave out the whole width of
    # the two that crossed the descent, and run through the cabinet.
    DECK_SPAN = W - MAN_W - 0.7
    grating_deck("Deck", (0.35, 0.0), (DECK_SPAN, L - 1.0 + 0.06), SLAB + 0.53, pitch=(L - 1.0) / 29,
                 openings=[((OUTLET_X + 0.035, OUTLET_Y), (0.8, 0.8)),
                           ((cpos[0], cpos[1]), (CAB[0] + 0.04, CAB[1] + 0.04))],
                 open_edges=("-Y", "+Y"), marked_edges=("-Y", "+Y"))

    # -- kit parts: hoses and looms (#803). Machinery a plant has "even where there is no clear
    # reason for it" (house style); none of it reaches a footprint edge, and `pipe` holds every
    # tube to that at save.
    #
    # A VENT HOSE OFF EACH RELIEF VALVE, down the drum's east flank to the deck. That flank is the
    # one the camera sees once the body is turned, and a valve that vents into the air beside a
    # drum reads as a part missing its pipe. Thin enough to read as a vent rather than a second
    # header, which is why its ring is fuller than the header's: at a 0.075 radius the header's
    # band would put each ring under the floor.
    for d in drums:
        vz = d["z0"] + d["h"] + 0.6
        flank = DX + d["r"] + 0.32                 # off the weld bead, which stands proud of the flank
        hose(f"VentHose{d['name']}", [(d["vx"] + 0.30, d["vy"], vz),
                              (d["vx"] + 0.55, d["vy"], vz - 0.05),
                              (flank + 0.02, d["vy"] - 0.15, d["z0"] + d["h"] - 0.2),
                              (flank, d["vy"] - 0.3, d["z0"] + d["h"] * 0.4),
                              (flank, d["vy"] - 0.3, SLAB + 0.53)],
             0.075, band=(1.3, 0.42), wobble=0.05)
    # A CABLE TRAY ALONG THE TOP OF THE EAST RAIL (#834), the open side the camera looks down on
    # once the body is turned, and the loom from the cabinet lying in it, with a drop from it to
    # each drum's gauges. The loom used to lie on the rail's flange itself; in the tray it is
    # carried the way a plant carries one, and the tray's ladder is a detail of its own.
    #
    # THE TRAY STANDS ON THE RAIL AS THE RAIL WAS BUILT. `hbeam` shifts and tilts every beam a
    # little, so the rail's top is not at one height: `on_rail` reads it off the top flange, and the
    # tray's brackets rest on it there. A bracket stands at each end and between each two post
    # lines, never on one, where a cross rail's own jitter and tilt can lift its top 0.03 over the
    # rail's (#825); the tray's rungs stand a bracket's height, 0.06, over the rail's top, so 0.03
    # clear of a cross rail lifted that far.
    #
    # TRAY_X IS SET ABSOLUTELY rather than off the rail, which is jittered: the tray's outer rail
    # stands 0.015 inside the collision box by the arithmetic. Its inner rail's outer face, at 1.965,
    # stands about 0.09 clear of the steam outlet's rings, which reach 0.285 from the descent's axis
    # at 1.52 and about 0.07 further with its bow (measured on the built model under #825). The loom
    # no longer steps out round the outlet: the tray runs straight past it.
    #
    # EVERY DROP LEAVES THE TRAY INBOARD, at DROP_X, which clears the rail's flange, the conduit and
    # its clamps under it, and the bays' rivets. The main loom leaves by the tray's open north end
    # and goes down at END_Y, between the deck's last two bars and past the north gauges, and comes
    # in by its open south end from the cabinet, climbing off it inboard of the conduit. Each gauge
    # loom climbs over the tray's inner rail on its way out. The main loom carries no ties, since a
    # tie round a loom lying in a tray passes through the rungs. The gauge looms keep theirs, which
    # stand at their points outside the tray.
    LOOM_HALF = rf.loom_spread(3, 0.035) + 0.035         # the bundle's half-width
    GAUGE_HALF = rf.loom_spread(2, 0.035) + 0.035
    TRAY_W, TRAY_X, DROP_X = 0.22, HALF_W - 0.15, EX - 0.43
    END_Y = HALF_L - 0.73
    from mathutils import Vector
    top = bpy.data.objects["RailE-f1"]
    bpy.context.view_layer.update()

    def on_rail(y):
        """The point on the rail's top flange at body y, at TRAY_X."""
        m = top.matrix_world
        ly = (y - m[1][3] - m[1][2] * 0.5) / m[1][1]
        _, _, z = m @ Vector((0.0, ly, 0.5))
        return (TRAY_X, y, z)

    clamps = [(p, y) for p, y in posts.items() if cpos[1] + CAB[1] / 2 < y < HALF_L - 0.5]
    cab_top, cab_n = cpos[2] + CAB[2] / 2, cpos[1] + CAB[1] / 2
    # It runs from just past the cabinet to past the north drum's gauges, so each gauge loom
    # leaves from inside it.
    TRAY_S, TRAY_N = cab_n + 0.5, max(clamps[-1][1] + 0.3, max(d["gy"] for d in drums) + 0.35)
    mids = [(a + b) / 2 for a, b in zip(post_ys, post_ys[1:])]
    held = [TRAY_S] + [y for y in mids if TRAY_S < y < TRAY_N] + [TRAY_N]
    lift = rf.TRAY_BRACKET[1] + rf.TRAY_RUNG[1]
    tray = cable_tray("CableTray", [(x, y, z + lift) for x, y, z in map(on_rail, held)], TRAY_W)
    lie = rf.tray_lie(tray, LOOM_HALF)
    LOOM_Z = lie[0][2]
    RAIL_TOP = tray["bed"][0][2] - rf.TRAY_RUNG[1] + tray["rail_h"]

    def in_tray(y, half):
        """The point a loom of half-width `half` follows lying in the tray at body y."""
        (ax, ay, az), (bx, by, bz) = tray["bed"][0], tray["bed"][-1]
        t = (y - ay) / (by - ay)
        return (TRAY_X, y, az + (bz - az) * t + half + rf.TRAY_CLEAR)

    loom("Loom", [(DROP_X + 0.15, cpos[1], cab_top + 0.02), (DROP_X + 0.1, cpos[1] + 0.3, LOOM_Z),
                  (DROP_X + 0.2, cab_n + 0.05, LOOM_Z + 0.04), (TRAY_X, TRAY_S - 0.25, lie[0][2])]
         + lie + [(TRAY_X, TRAY_N + 0.15, lie[-1][2]), (DROP_X, END_Y - 0.3, LOOM_Z + 0.04),
                  (DROP_X, END_Y, SLAB + 1.2), (DROP_X, END_Y, SLAB + 0.02)], ties=False)
    # -- kit parts: inset panels (#802). Each on a face the camera sees once the body is turned.
    for p, centre, size, yaw in bays:
        # The plates stop 0.06 inside the backing's ends: a handwheel rim beside a bay can stand
        # just past the backing, and plates out to its ends touched one (the branch's pre-PR
        # review).
        panels(f"BayPlates{p}", centre, (size[0] - 0.12, size[1]), "+X", (3, 2), "paint", yaw=yaw)
    # The cabinet's top, the face of it the camera sees most of; paint on paint, so the seams read
    # by their shadow alone. Its outer quarter tile is left bare: the conduit and the corner post's
    # flange pass just over it, and plates there stood into both (the branch's pre-PR review).
    panels("CabinetPlates", (cpos[0] - 0.125, cpos[1], cpos[2] + CAB[2] / 2), (CAB[0] - 0.25, CAB[1]), "+Z",
           (2, 3), "paint")
    # The manifold's inner face, which the feed lines run into. It carries the manifold's
    # corrosion, since it is the same steel, and turns with its yaw.
    panels("ManifoldPlates", (on_manifold(0) + MAN_W / 2, 0, SLAB + MAN_H / 2), (L - 0.2, MAN_H), "+X",
           (12, 2), "body", yaw=MAN_YAW, corrode=True)
    # -- kit parts: repeated modules (#804).
    #
    # A SEGMENTED CASING ROUND EACH DRUM'S SHOULDER: eight dark segments with a slot between each,
    # the insulation jacket a hot vessel wears. Under the cap, where the camera looks down on it;
    # at the foot it hid behind the deck. It stands above the upper rib and clear of the dent
    # struck between the ribs.
    for d in drums:
        jacket_r = d["r"] + 0.02
        at = ring((DX, d["y"], d["z0"] + d["h"] - 0.24), jacket_r, 8, phase=math.pi / 8)
        casing(f"Drum{d['name']}Jacket", at, jacket_r, rf.casing_arc(8, jacket_r, 0.06), 0.34)
    # A FAN STACK at the deck's far end, past the last drum: four discs on a shaft, the cooler a
    # steam plant has beside its drums. The body's north end is the declared east once turned, and
    # the camera sees it from the south.
    FAN = (0.9, HALF_L - 1.05)
    cyl("FanShaft", 0.06, 1.0, (FAN[0], FAN[1], SLAB + 0.5 + 0.5), "metal", verts=16)
    fan_discs("FanStack", stack((FAN[0], FAN[1], SLAB + 0.62), 4, 0.24), 0.42)
    # A BOLT ROW along the slab's open edge, the kerb the camera looks down on. Bolts that would
    # stand in a post's foot or in the steam socket's opening are left out (the branch's pre-PR
    # review).
    kerb = row((HALF_W - 0.07, -HALF_L + 0.2, SLAB), (HALF_W - 0.07, HALF_L - 0.2, SLAB), 36)
    bolts("SlabBolts", [p for p in kerb
                        if abs(p[0][1]) > 0.45 and all(abs(p[0][1] - y) > 0.18 for y in post_ys)])
    for d in drums:
        # Out over the inner rail. The tie at this point stands 0.06 past the bundle, and the
        # loom's wobble moves the point up to 0.03 each way, so it is set 0.05 inboard of the
        # rail, where the bundle's own edge still stands over it. What keeps the tie clear of the
        # rail's top is height: its centre stands the bundle's half-width and 0.12 more over it.
        # What keeps it clear of the main loom is that inboard setting: the tie reaches no further
        # out than about 1.975, and the main loom starts at 2.021.
        over = TRAY_X - TRAY_W / 2 - rf.TRAY_RAIL_T - 0.05
        loom(f"GaugeLoom{d['name']}", [in_tray(d["gy"] + 0.1, GAUGE_HALF),
                               (over, d["gy"] + 0.08, RAIL_TOP + GAUGE_HALF + 0.12),
                               (DROP_X, d["gy"] + 0.05, LOOM_Z + 0.04),
                               (DROP_X, d["gy"], SLAB + 1.4),
                               (d["gx"] + 0.04, d["gy"], SLAB + 1.13)],
             cables=("cable-red", "cable-green"), wobble=0.03)

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
    # THIS MACHINE DRAWS ITS SOCKETS ONE WAY AND DRESSES THEM TWO (ADR 0036, #391). Every socket
    # here is at models/rf_blender.SOCKET_Z and 0.249, water and energy alike; what differs is the
    # HARDWARE. Water west, water east and steam south carry no `connection_category`, a player
    # plumbs them, and they wear the dark rim and the flange pair vanilla puts where a pipe bolts.
    # The three reactor-energy connections are CONTAINED (ADR 0018, #86): no pipe, tank, wagon or
    # pump a player can build will ever join them, they bolt face to face against a reactor or the
    # next exchanger in the row, and they wear NEITHER piece. That absence is the whole of what
    # tells them apart, and it is a decision rather than an inheritance -- ADR 0033 says of itself
    # that it is "vacuous for those sockets", so nothing had chosen it before.
    #
    # THE PAIR ON EACH SHORT END USED TO DIFFER BY HALF A TILE IN HEIGHT (#343), and the comment
    # here said so at length because the difference invited a "fix". It was levelled instead.
    #
    # SINCE ADR 0036 THE THREE CONTAINED ONES ARE DRAWN LIKE THE OTHER THREE, and the pair of
    # constants that used to sit here is gone rather than kept at equal values. They held 0.55 and
    # 0.3 -- what every socket on this machine had before #349, kept when the plumbable ones moved.
    # Keeping them was a choice and was written down as one; ADR 0036 reverses it. A separate name
    # free to part from SOCKET_Z later is the fork #356 was written about, so there is no second
    # name: one constant draws every socket, and `plumbable` now decides only the rim and the ribs.
    def plumbable(c):
        """Whether a player can put an ordinary pipe on this connection.

        Read off `connection_category` rather than off a list of fluids, which is the same
        discriminator scripts/load-check.ps1's gate uses -- a connection left `default` is one a
        player can plumb. A fourth energy face added tomorrow is contained without this being
        touched, and a category taken off one makes it plumbable and brings it under the rule.
        """
        return not c["connection_category"]

    # 0.249 is solved the way the height is, and in the same place: this camera draws a tube 2.449 r
    # tall on screen, vanilla's pipe body draws 0.609 tiles, so 2.449 r = 0.609.
    # models/house-style.md carries the arithmetic and rf-isotope-collector was the first machine to
    # wear it. Both machines now draw every socket at these two numbers.
    SOCKET_R = 0.249

    # ONE HELPER DRAWS THE STUB, THE BAND AND THE PORT (#352), because the collector had a second
    # copy of this loop and five more machines are coming. What stays here is the three functions
    # above: which connections are plumbable, and how high and how thick each kind is drawn. The
    # slab's top is at 0.25 and a lowered socket reaches through it, so a plumbable one gets a
    # modelled, rimmed opening rather than clipping the stone (Truls, 2026-09-14); a contained
    # socket stands clear above the slab and needs none, which is what passing `plumbable` decides.
    for c in geo["connections"]:
        rf_parts.socket(bpy.data.objects["Slab"], c, geo, rf_parts.SOCKET_Z, SOCKET_R,
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
        return (px - back * ux, -(py - back * uy), rf_parts.SOCKET_Z if z is None else z)

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
        s = stream("WaterHeader")
        mid = ((a[0] + b[0]) / 2 + s.jitter(0, 0.1), (a[1] + b[1]) / 2 + s.jitter(0, 0.1), 0.5)
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
        s = stream(f"EnergyFeed-{c['direction']}")
        mid = ((start[0] + end[0]) / 2 + s.jitter(0, 0.08),
               (start[1] + end[1]) / 2 + s.jitter(0, 0.08),
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

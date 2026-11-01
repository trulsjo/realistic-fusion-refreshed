"""Build the heat exchanger model from its look note, headless. This is what "regenerate" reruns.

    blender -b --python build.py -- [out.blend] [machine|cube]

Reads geometry.json beside this file for the collision box and the connections, so the sockets land
where the prototype declares them, and stamps that file's hash on the scene so render.py can refuse
a model whose geometry has moved on. Every shape is a primitive, a curve or a kit part with a
procedural material; the one image is the CC0 rust photograph recorded in textures.json beside this
file (ADR 0043), which the manifold's corrosion and the paint's weathering both read.

BUILT IN THE DECLARED FRAME: fifteen wide along X, five deep along Y, the energy face north (+Y in
Blender, since Factorio's +y is south), the camera south of the machine looking north. Nothing is
turned at the end, so every point below is where it is drawn.

REBUILT FROM THE LOOK NOTE ALONE for #806, so the note's gaps show in the model rather than being
filled from an earlier one. Where the note was silent or met the house style or another part of
itself, the choice made is said where it is made, beside the part.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import bpy  # noqa: E402
import rf_blender as rf  # noqa: E402
import rf_parts  # noqa: E402
from rf_parts import box, cyl, hbeam, hose, pipe, rivets, seam, stream, torus  # noqa: E402

args = rf.script_args()
out_path = args[0] if args else os.path.join(HERE, "heat-exchanger.blend")
variant = args[1] if len(args) > 1 else "machine"

geo_path = os.path.join(HERE, "geometry.json")
geo = json.load(open(geo_path, encoding="utf-8"))
(x0, y0), (x1, y1) = geo["collision_box"]
TX, TY = (x1 - x0) / 2, (y1 - y0) / 2       # declared half extents: 7.25 x 2.25

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = "rf"

# ---- materials (house style palette) -------------------------------------------------------
#
# models/house-style.md's Palette table, row for row; scripts/ship-check.ps1 section 8 holds the
# accents to it. Only the accents of the three fluids this machine carries.
PALETTE = {
    "body":     ((0.13, 0.14, 0.16), 0.72, 0.0),
    "frame":    ((0.02, 0.022, 0.025), 0.6, 0.2),
    "dark":     ((0.14, 0.145, 0.155), 0.5, 0.7),
    "metal":    ((0.30, 0.30, 0.32), 0.35, 0.8),
    "paint":    ((0.58, 0.55, 0.47), 0.8, 0.0),
    "energy":   ((1.00, 0.45, 0.10), 0.5, 0.0),
    "steam":    ((0.85, 0.88, 0.90), 0.5, 0.0),
    "water":    ((0.25, 0.55, 1.00), 0.5, 0.0),
    "hazard":   ((0.72, 0.55, 0.09), 0.55, 0.0),
    **rf.CABLE_COLOURS,
}
# Clean, so they read: the accents, the marking and the cable sheaths.
CLEAN = ("energy", "steam", "water", "hazard", "cable-red", "cable-green")
# Painted, and weathered by the photograph's value rather than by noise.
PAINTED = ("body", "paint")
RUST = "rust_coarse_01_diff_1k.jpg"
# The photograph's mean linear luminance, measured off the file (0.0597), so that dividing by it
# leaves a painted panel its own colour on average, as the note asks.
RUST_MEAN = 0.0597
PIT = (0.045, 0.022, 0.010)                # dark brown, inside the rust
VERDIGRIS = (0.10, 0.24, 0.19)
MATS = {}


def _node(nt, kind, **inputs):
    n = nt.nodes.new(kind)
    for k, v in inputs.items():
        n.inputs[k].default_value = v
    return n


def _world_noise(nt, scale, detail, stretch=(1.0, 1.0, 1.0), offset=(0.0, 0.0, 0.0)):
    """A noise read in world space, so a turned or stretched box gets the same grain as its
    neighbours: Generated coordinates are each object's own bounding box (house style, Materials)."""
    pos = nt.nodes.new("ShaderNodeNewGeometry")
    mapped = nt.nodes.new("ShaderNodeVectorMath")
    mapped.operation = "MULTIPLY_ADD"
    mapped.inputs[1].default_value = stretch
    mapped.inputs[2].default_value = offset
    nt.links.new(pos.outputs["Position"], mapped.inputs[0])
    noise = _node(nt, "ShaderNodeTexNoise", Scale=scale, Detail=detail)
    nt.links.new(mapped.outputs["Vector"], noise.inputs["Vector"])
    return noise.outputs["Fac"]


def _ramp(nt, fac, lo, hi):
    r = nt.nodes.new("ShaderNodeValToRGB")
    r.color_ramp.elements[0].position = lo
    r.color_ramp.elements[1].position = hi
    nt.links.new(fac, r.inputs["Fac"])
    return r.outputs["Color"]


def _mix(nt, factor, a, b):
    """Mix two colours; `a` and `b` are each a socket or a constant."""
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    nt.links.new(factor, m.inputs["Factor"])
    for name, v in (("A", a), ("B", b)):
        if isinstance(v, tuple):
            m.inputs[name].default_value = (*v, 1.0)
        else:
            nt.links.new(v, m.inputs[name])
    return m.outputs["Result"]


def mat(name, glow=False, corrode=False):
    key = (name, glow, corrode)
    if key in MATS:
        return MATS[key]
    rgb, rough, metal = PALETTE[name]
    m = bpy.data.materials.new(name + ("-glow" if glow else "") + ("-corroded" if corrode else ""))
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    MATS[key] = m
    if glow:
        # THE ACCENT AS EMISSION, NOT AS COLOUR (house style, Glow): a dark base, so a stopped
        # machine looks stopped, and the accent in the emission render.py switches on.
        b.inputs["Base Color"].default_value = (*(c * rf.GLOW_BASE_DARKEN for c in rgb), 1.0)
        b.inputs["Emission Color"].default_value = (*rgb, 1.0)
        b.inputs["Emission Strength"].default_value = rf.GLOW_EMISSION
        return m
    if name in CLEAN:
        return m
    rough_out = None
    if name in PAINTED:
        # OLD PAINT: the photograph's value over the palette colour, divided by its mean so the
        # panel keeps its colour on average, at a little over half strength so it mottles rather
        # than stains.
        tex = rf_parts.texture(nt, HERE, RUST, tiles=2.0)
        bw = nt.nodes.new("ShaderNodeRGBToBW")
        nt.links.new(tex, bw.inputs["Color"])
        f = nt.nodes.new("ShaderNodeMath")
        f.operation = "MULTIPLY_ADD"
        f.inputs[1].default_value = 0.55 / RUST_MEAN
        f.inputs[2].default_value = 0.45
        nt.links.new(bw.outputs["Val"], f.inputs[0])
        scaled = nt.nodes.new("ShaderNodeVectorMath")
        scaled.operation = "SCALE"
        scaled.inputs[0].default_value = rgb
        nt.links.new(f.outputs["Value"], scaled.inputs["Scale"])
        colour = scaled.outputs["Vector"]
    else:
        # GRIME on bare metal, dark and frame: a broad noise for patches blended with a fine one,
        # through a ramp, with the roughness swung by the same mask.
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "FLOAT"
        mix.inputs[0].default_value = 0.35
        nt.links.new(_world_noise(nt, 4.0, 6.0), mix.inputs[2])
        nt.links.new(_world_noise(nt, 22.0, 4.0, offset=(3.1, 7.7, 1.3)), mix.inputs[3])
        grime = _ramp(nt, mix.outputs["Result"], 0.40, 0.72)
        colour = _mix(nt, grime, rgb, (rgb[0] * 0.5, rgb[1] * 0.45, rgb[2] * 0.4))
        rmix = nt.nodes.new("ShaderNodeMath")
        rmix.operation = "MULTIPLY_ADD"
        rmix.inputs[1].default_value = 0.5
        rmix.inputs[2].default_value = rough
        nt.links.new(grime, rmix.inputs[0])
        rough_out = rmix.outputs["Value"]
    if corrode:
        # CORROSION, the manifold's alone: rust where water has run, over about a third of the
        # face, so a broad patch noise blended with one stretched tall into runs; small dark pits
        # inside it; and verdigris, rarer than either. The rust takes the photograph's colour.
        patch = _world_noise(nt, 0.9, 3.0)
        runs = _world_noise(nt, 1.6, 4.0, stretch=(1.0, 1.0, 0.18), offset=(5.0, 2.0, 0.0))
        blend = nt.nodes.new("ShaderNodeMix")
        blend.data_type = "FLOAT"
        blend.inputs[0].default_value = 0.45
        nt.links.new(patch, blend.inputs[2])
        nt.links.new(runs, blend.inputs[3])
        rust = _ramp(nt, blend.outputs["Result"], 0.47, 0.53)
        tex = rf_parts.texture(nt, HERE, RUST, tiles=2.0, gain=(1.6, 1.6, 1.6))
        colour = _mix(nt, rust, colour, tex)
        pos = nt.nodes.new("ShaderNodeNewGeometry")
        vor = _node(nt, "ShaderNodeTexVoronoi", Scale=14.0)
        nt.links.new(pos.outputs["Position"], vor.inputs["Vector"])
        pit = nt.nodes.new("ShaderNodeMapRange")
        pit.clamp = True
        for k, v in (("From Min", 0.05), ("From Max", 0.08), ("To Min", 1.0), ("To Max", 0.0)):
            pit.inputs[k].default_value = v
        nt.links.new(vor.outputs["Distance"], pit.inputs["Value"])
        pits = nt.nodes.new("ShaderNodeMath")
        pits.operation = "MULTIPLY"
        nt.links.new(pit.outputs["Result"], pits.inputs[0])
        nt.links.new(rust, pits.inputs[1])
        colour = _mix(nt, pits.outputs["Value"], colour, PIT)
        verd = _ramp(nt, _world_noise(nt, 2.4, 3.0, offset=(11.0, 4.0, 9.0)), 0.68, 0.71)
        colour = _mix(nt, verd, colour, VERDIGRIS)
        r = nt.nodes.new("ShaderNodeMapRange")
        for k, v in (("To Min", rough), ("To Max", 0.92)):
            r.inputs[k].default_value = v
        nt.links.new(rust, r.inputs["Value"])
        rough_out = r.outputs["Result"]
    nt.links.new(colour, b.inputs["Base Color"])
    if rough_out is not None:
        nt.links.new(rough_out, b.inputs["Roughness"])
    return m


rf_parts.use(mat, geo, seed=7)  # each part's imperfections: its name and this, nothing else

# ---- the layout -----------------------------------------------------------------------------
#
# Heights. The note gives the frame's top (1.55), the guard rail and the tray (1.75) and the drums
# (about 1.6 over the frame's top); the lower deck's height it leaves open, and it is set by the
# water header under it, whose pipe supports need 0.21 between the slab and the header's axis.
SLAB = 0.25
DECK = 0.70                    # the lower deck's top face
TOP = 1.55                     # the frame's top rails' top face
BEAM_Z = TOP - 0.1             # their axis, a 0.2 deep H-beam
RAIL_Z = 1.75                  # the guard rail
TRAY_Z = 1.80                  # the tray's bed; why not 1.75 is at `cable_tray` below
PLATFORM = TOP + rf.DECK_BAR[1]  # the service platform's top face, its bars laid on the top rails

POST_Y = -2.05                 # the south posts' line
MAN_IN = 1.45                  # the manifold's inner, south-facing face
MAN_X = 7.2
DRUM_Y = (MAN_IN + POST_Y) / 2  # midway between the manifold and the posts
DRUM_R = 0.9
DRUM_TOP = TOP + 1.55               # "about 1.6": 1.6 put the outlet run's bend over the 4-tile cap
CAP_TOP = DRUM_TOP + 0.08
TRAY_Y = -1.81
HEADER_R = 0.2                 # two fifths of a tile across
VENT_R = 0.08
WATER_R = 0.13
WATER_Y = -1.0                 # the water sockets' line (Factorio y 1)
WATER_Z = 0.47

# Seven places along the south face, the middle one left empty over the steam socket.
PLACES = {"W3": -7.0, "W2": -14 / 3, "W1": -7 / 3, "E1": 7 / 3, "E2": 14 / 3, "E3": 7.0}
DRUMS = {
    # x, the relief valve's angle on the cap, the lugs' angles, the gauge's, the vent hose's and the
    # drain's offsets across the south flank, and the side the energy feed runs up. The middle
    # drum's vent hose runs straight down under its relief valve.
    "West":   dict(x=-3.5, relief=270, lugs=(65, 115), gauge=-0.35, vent=0.30, drain=-0.6, feed=-1),
    "Middle": dict(x=-0.75, relief=225, lugs=(60, 120), gauge=0.35, vent=None, drain=-0.6, feed=-1),
    "East":   dict(x=3.5, relief=270, lugs=(65, 115), gauge=0.35, vent=-0.45, drain=0.6, feed=1),
}
RUN_R = 0.55                   # where a header run leaves or lands a cap, inside its ring of bolts
BOLT_RING = 0.87

# The service platform, between the middle drum and the east drum; its west edge clear of the
# outlet run, its east edge against the east drum.
PLAT_X = (1.0, 2.55)
PLAT_Y = (-1.85, MAN_IN - 0.15)
LADDER = (1.6, -1.72)          # the access ladder's foot, against the hatch's south side
HATCH = ((1.6, -1.525), (0.7, 0.75))


def at_flank(dx, ox, d):
    """The point `d` from drum `dx`'s axis on the radius through its south flank `ox` across, and
    the yaw that turns a part to face out along that radius."""
    phi = math.asin(ox / DRUM_R)
    return (dx + d * math.sin(phi), DRUM_Y - d * math.cos(phi)), phi


def skin_y(ox):
    return DRUM_Y - math.sqrt(DRUM_R ** 2 - ox ** 2)


def on_cap(dx, angle, r=RUN_R):
    a = math.radians(angle)
    return (dx + r * math.cos(a), DRUM_Y + r * math.sin(a))


def turned(p, rot):
    return rf.turn(rf.euler_matrix(rot), p)


if variant == "cube":
    box("Cube", (1, 1, 1), (0, 0, 0.5), "body")
else:
    slab = box("Slab", (2 * TX, 2 * TY, SLAB), (0, 0, SLAB / 2), "frame")
    # A row of BOLTS along the slab's south kerb, either side of the steam socket's opening.
    for side, (a, b) in (("West", (-7.1, -0.45)), ("East", (0.45, 7.1))):
        rf_parts.bolts(f"KerbBolts{side}", rf.row((a, -2.21, SLAB), (b, -2.21, SLAB), 22))

    # -- THE MANIFOLD: the reactor contact, a riveted trough the full length, corroded. Its top is
    # the frame's top, with the energy channel let into it between two lips and a grille over it.
    man_cy = (MAN_IN + TY) / 2
    CH = (1.70, 2.00)                       # the channel's south and north sides
    CH_FLOOR = TOP - 0.15
    box("Manifold", (2 * MAN_X, TY - MAN_IN, CH_FLOOR - SLAB), (0, man_cy, (SLAB + CH_FLOOR) / 2),
        "body", corrode=True)
    box("ManifoldLipSouth", (2 * MAN_X, CH[0] - MAN_IN, TOP - CH_FLOOR),
        (0, (MAN_IN + CH[0]) / 2, (CH_FLOOR + TOP) / 2), "body", corrode=True)
    box("ManifoldLipNorth", (2 * MAN_X, TY - CH[1], TOP - CH_FLOOR),
        (0, (CH[1] + TY) / 2, (CH_FLOOR + TOP) / 2), "body", corrode=True)
    box("EnergyChannel", (2 * MAN_X - 0.1, CH[1] - CH[0] + 0.02, 0.04), (0, sum(CH) / 2, CH_FLOOR),
        "energy", glow=True, read=CH[1] - CH[0])
    for k in range(48):
        gx = -MAN_X + 0.15 + k * (2 * MAN_X - 0.3) / 47
        box(f"Grille{gx:+.2f}", (0.06, CH[1] - CH[0] + 0.06, 0.06), (gx, sum(CH) / 2, TOP - 0.03),
            "dark", bev=0)
    rivets("ManifoldRivets", (-MAN_X + 0.1, MAN_IN - 0.01, TOP - 0.06), (MAN_X - 0.1, MAN_IN - 0.01, TOP - 0.06),
           64, r=0.032)
    rivets("ManifoldRivetsTop", (-MAN_X + 0.1, MAN_IN + 0.12, TOP + 0.005), (MAN_X - 0.1, MAN_IN + 0.12, TOP + 0.005),
           64, r=0.032)
    # Its inner face, twelve by two, in the same corroded steel, from the deck up to the lip.
    PANEL_FACE = (2 * MAN_X - 0.1, CH_FLOOR - 0.05 - DECK)
    panel_c = (0, MAN_IN, DECK + PANEL_FACE[1] / 2)
    rf_parts.panels("ManifoldPanels", panel_c, PANEL_FACE, "-Y", (12, 2), corrode=True)
    cells = rf.panel_grid(PANEL_FACE[0], PANEL_FACE[1], 12, 2, 0.05)
    for side, (cu, cv, su, sv) in (("West", cells[12]), ("East", cells[23])):
        rf_parts.warning_plate(f"ManifoldWarning{side}", (cu, MAN_IN - 0.055, panel_c[2] + cv),
                               (0.6, min(0.24, sv - 0.04)), "-Y", stripes=3)

    # -- THE FRAME: dark H-beams, open, over the grating deck. Six posts on seven places, carried
    # past the top to hold the guard rail; top rails along the south face and cross rails from
    # the manifold's top to each post.
    for name, x in PLACES.items():
        hbeam(f"Post{name}", RAIL_Z + 0.05 - SLAB, (x, POST_Y, (SLAB + RAIL_Z + 0.05) / 2))
        hbeam(f"CrossRail{name}", MAN_IN + 0.15 - POST_Y, (x, (MAN_IN + 0.15 + POST_Y) / 2, BEAM_Z), axis="Y")
    # THE OPEN BAY HAS NO SOUTH TOP RAIL, NOR A BOTTOM ONE. The note puts nothing across it but the
    # guard rail's west length, and the access ladder in it must have nothing in front of it from
    # the deck to its cage's top; a rail at 1.45 across the bay would cross it. The platform's bars
    # span between its two north-south beams, so its south edge needs no rail under it.
    for name, (a, b) in (("W3", (-7.0, -14 / 3)), ("W2", (-14 / 3, -7 / 3)),
                         ("E1", (7 / 3, 14 / 3)), ("E2", (14 / 3, 7.0))):
        hbeam(f"TopRail{name}", b - a, ((a + b) / 2, POST_Y, BEAM_Z), axis="X")
        hbeam(f"BottomRail{name}", b - a, ((a + b) / 2, POST_Y, DECK - 0.16), axis="X")
    # The platform's west beam, from the manifold's top: the open bay's middle place has no post.
    hbeam("PlatformBeam", MAN_IN + 0.15 - PLAT_Y[0], (PLAT_X[0] - 0.05, (MAN_IN + 0.15 + PLAT_Y[0]) / 2, BEAM_Z),
          axis="Y")

    # The two end bays carry a diagonal brace. The west one is a knee from the post at 4.67 to the
    # top rail, not the full diagonal, so it passes behind none of the control cabinet's face.
    for name, (xa, za), (xb, zb) in (("West", (-14 / 3 - 0.1, DECK + 0.02), (-5.95, BEAM_Z - 0.08)),
                                     ("East", (14 / 3 + 0.1, DECK + 0.02), (6.9, BEAM_Z - 0.08))):
        length = math.hypot(xb - xa, zb - za)
        tilt = -math.atan2(zb - za, xb - xa) if xb > xa else math.atan2(zb - za, xa - xb)
        box(f"Brace{name}", (length, 0.1, 0.1), ((xa + xb) / 2, POST_Y, (za + zb) / 2), "frame",
            rot=(0, tilt, 0))

    # The bays either side of the open bay are closed with a dark backing carrying inset panels of
    # paint, three by two, set back behind the guard rail and under the top rail.
    for name, cx in (("West", -3.5), ("East", 3.5)):
        width = 7 / 3 - 0.18
        bz = (DECK + BEAM_Z - 0.1) / 2
        box(f"Backing{name}", (width, 0.04, BEAM_Z - 0.1 - DECK), (cx, POST_Y + 0.1, bz), "dark", read=0.6)
        rf_parts.panels(f"BackingPanels{name}", (cx, POST_Y + 0.08, bz), (width - 0.06, BEAM_Z - 0.16 - DECK),
                        "-Y", (3, 2), material="paint")

    # -- THE LOWER DECK, a grating over the slab, its south edge marked outside the open bay. In the
    # open bay it is closed by an unmarked toe board, and between the middle drum and the platform
    # it is cut back to the drums' feet, so the outlet run and its valve pass down in front of it.
    deck_y = (POST_Y + 0.11, MAN_IN - 0.03)
    for name, (a, b), south, marked, holes in (
            ("West", (-7.08, -7 / 3), deck_y[0], True, ()),
            ("BayWest", (-7 / 3, -0.4), deck_y[0], False, ()),
            ("BayCut", (-0.4, PLAT_X[0] - 0.05), -1.15, False, (((0.5, -0.85), (0.72, 0.8)),)),
            ("BayEast", (PLAT_X[0] - 0.05, 7 / 3), deck_y[0], False, ()),
            ("East", (7 / 3, 7.08), deck_y[0], True, ())):
        rf_parts.grating_deck(f"Deck{name}", ((a + b) / 2, (south + deck_y[1]) / 2), (b - a, deck_y[1] - south),
                              DECK, along="X", openings=holes, open_edges=("-Y",),
                              marked_edges=("-Y",) if marked else ())

    # -- THE DRUMS: bare metal, two rib bands, a weld seam, a bolted cap with its bolts, relief
    # valve and lugs, a segmented casing under the cap, a gauge box on the south flank, a drain.
    CASING = (DRUM_TOP - 0.27, DRUM_TOP - 0.03)
    RIBS = {"Low": 2.55, "High": 2.82}
    BOX = (2.15, 2.45)                       # the gauge box's foot and top
    GLAND = BOX[0] - 0.04
    gauges = {}
    for name, d in DRUMS.items():
        dx = d["x"]
        height = DRUM_TOP - DECK
        shell = cyl(f"Drum{name}", DRUM_R, height, (dx, DRUM_Y, DECK + height / 2), "metal", verts=72)
        ribs = [torus(f"Drum{name}Rib{k}", DRUM_R + 0.015, 0.035, (dx, DRUM_Y, z), "dark")
                for k, z in RIBS.items()]
        weld = stream(f"Drum{name}Weld")
        (wx, wy), wphi = at_flank(dx, -0.62 if d["gauge"] > 0 else 0.62, DRUM_R - 0.012)
        seam(f"Drum{name}Weld", (0.05, 0.05, RIBS["Low"] - DECK - 0.1),
             (wx, wy, (DECK + RIBS["Low"]) / 2), rot=(weld.jitter(0, 0.02), 0, wphi))
        if name == "East":
            # THE DENT, struck on the south flank between the rib bands, west of the gauge box so
            # the box stays on whole skin. The bands are struck with the shell, so they bend into
            # the hollow with it.
            centre = (dx - 0.15, skin_y(-0.15), (RIBS["Low"] + RIBS["High"]) / 2)
            for o in [shell] + ribs:
                rf_parts.dent(o, centre, 0.36, 0.18)
        cyl(f"Drum{name}Cap", DRUM_R + 0.06, CAP_TOP - DRUM_TOP, (dx, DRUM_Y, (DRUM_TOP + CAP_TOP) / 2), "metal",
            verts=72, read=2 * DRUM_R)
        rf_parts.bolts(f"Drum{name}CapBolts", rf.ring((dx, DRUM_Y, CAP_TOP), BOLT_RING, 20, phase=0.08))
        rf_parts.casing(f"Drum{name}Casing", rf.ring((dx, DRUM_Y, sum(CASING) / 2), DRUM_R, 8, phase=0.2),
                        DRUM_R, rf.casing_arc(8, DRUM_R, 0.06), CASING[1] - CASING[0])
        rf_parts.lifting_lugs(f"Drum{name}Lugs", [((*on_cap(dx, a, 0.62), CAP_TOP), (0, 0, math.radians(a)))
                                                  for a in d["lugs"]])
        # The pressure relief valve: dark with a steam band, never a white body, and a nozzle out
        # to the south that its vent hose leaves from.
        vx, vy = on_cap(dx, d["relief"])
        cyl(f"Drum{name}ReliefStem", 0.05, 0.12, (vx, vy, CAP_TOP + 0.06), "metal", verts=16)
        cyl(f"Drum{name}Relief", 0.11, 0.22, (vx, vy, CAP_TOP + 0.23), "dark", verts=24)
        torus(f"Drum{name}ReliefBand", 0.115, 0.035, (vx, vy, CAP_TOP + 0.23), "steam")
        cyl(f"Drum{name}ReliefTop", 0.06, 0.08, (vx, vy, CAP_TOP + 0.38), "dark", verts=16)
        cyl(f"Drum{name}ReliefNozzle", 0.06, 0.2, (vx, vy - 0.12, CAP_TOP + 0.18), "dark", axis="Y", verts=16)
        # The vent hose, down the south flank to the deck, standing off the casing and the bands;
        # each drum's bends its own way, and a wobble keeps any two from matching.
        ox = vx - dx if d["vent"] is None else d["vent"]
        sy = skin_y(ox)
        hx = dx + ox
        flange_y = DRUM_Y - math.sqrt((DRUM_R + 0.06) ** 2 - (vx - dx) ** 2)
        hose(f"Drum{name}Vent",
             [(vx, vy - 0.1, CAP_TOP + 0.18), (vx, vy - 0.3, CAP_TOP + 0.16),
              ((vx + hx) / 2, min(flange_y, sy) - 0.2, CAP_TOP + 0.02),
              (hx, sy - 0.2, CASING[0] + 0.05), (hx, sy - 0.18, RIBS["Low"] - 0.3),
              (hx, sy - 0.15, 1.3), (hx, sy - 0.16, DECK + 0.12), (hx, sy - 0.16, DECK - 0.04)],
             VENT_R, pitch=1.2 * VENT_R, band=(1.0, 0.38), wobble=0.03)
        # THE GAUGE CLUSTER, on the drum's own skin: a painted box bolted to the south flank, its
        # back sunk into the shell so no light shows between them, below the lower rib band.
        (gx, gy), phi = at_flank(dx, d["gauge"], DRUM_R + 0.1 - 0.035)
        gz = sum(BOX) / 2
        box(f"Drum{name}Gauges", (0.38, 0.2, BOX[1] - BOX[0]), (gx, gy, gz), "paint", rot=(0, 0, phi), read=0.3)
        for side, u in (("W", -0.09), ("E", 0.09)):
            lx, ly, _ = turned((u, -0.1, 0), (0, 0, phi))
            dial = (gx + lx, gy + ly, gz + 0.04)
            fx, fy, _ = turned((0, -1, 0), (0, 0, phi))
            cyl(f"Drum{name}Dial{side}", 0.07, 0.03, dial, "dark", rot=(math.pi / 2, 0, phi), verts=20, read=0.14)
            cyl(f"Drum{name}DialFace{side}", 0.05, 0.02, (dial[0] + 0.012 * fx, dial[1] + 0.012 * fy, dial[2]),
                "metal", rot=(math.pi / 2, 0, phi), verts=20, read=0.1)
        corners = [((gx + p[0], gy + p[1], gz + v), (math.pi / 2, 0, phi))
                   for u, v in ((-0.15, 0.11), (0.15, 0.11), (-0.15, -0.11), (0.15, -0.11))
                   for p in [turned((u, -0.1, 0), (0, 0, phi))]]
        rf_parts.bolts(f"Drum{name}GaugeBolts", corners, r=0.032, head=0.03)
        cyl(f"Drum{name}Gland", 0.085, 0.08, (gx, gy, GLAND), "dark", verts=20)
        gauges[name] = (gx, gy)
        # A handwheel valve on a short drain off the drum's foot, down through the grating to the slab.
        (rx, ry), rphi = at_flank(dx, d["drain"], DRUM_R - 0.05)
        fx, fy, _ = turned((0, -1, 0), (0, 0, rphi))
        pipe(f"Drum{name}Drain", [(rx, ry, DECK + 0.2), (rx + 0.3 * fx, ry + 0.3 * fy, DECK + 0.2),
                                  (rx + 0.42 * fx, ry + 0.42 * fy, DECK + 0.1),
                                  (rx + 0.42 * fx, ry + 0.42 * fy, SLAB - 0.03)], 0.05, "metal")
        rf_parts.valve(f"Drum{name}DrainValve", (rx + 0.2 * fx, ry + 0.2 * fy, DECK + 0.2), (fx, fy, 0), 0.05,
                       (0, -0.58, 0.82))

    # -- THE STEAM HEADER: a corrugated hose a ring every radius, each ring a quarter of the radius
    # proud. The west and east runs each rise a third of a tile off their cap and sag between the
    # drums to a valve, its handwheel turned to the camera; the east run keeps north of the access
    # ladder, on the drums' line.
    RISE = 1 / 3
    HEADER = dict(pitch=HEADER_R, band=(1.0, 0.25))
    TO_CAMERA = (0, -0.58, 0.82)
    wx_, mx_, ex_ = (DRUMS[n]["x"] for n in ("West", "Middle", "East"))

    def lift(x, y, rise):
        return [(x, y, DRUM_TOP + 0.02), (x, y, CAP_TOP + rise * 0.5), (x, y, CAP_TOP + rise)]

    def header_run(name, a, b, low):
        """A run from the cap point `a` to the cap point `b`, sagging to `low` between them, with a
        valve at its lowest point."""
        way = (b[0] - a[0]) / abs(b[0] - a[0])
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, low)
        near_a = (a[0] + 0.5 * way, a[1], CAP_TOP + RISE - 0.04)
        near_b = (b[0] - 0.5 * way, b[1], CAP_TOP + RISE - 0.04)
        o = hose(name, lift(*a, RISE) + [near_a, mid, near_b] + lift(*b, RISE)[::-1], HEADER_R, **HEADER)
        line = rf_parts.centreline(o)
        k = min(range(len(line)), key=lambda i: line[i][2])
        p, q = line[max(k - 1, 0)], line[min(k + 1, len(line) - 1)]
        rf_parts.valve(f"{name}Valve", line[k], tuple(q[j] - p[j] for j in range(3)), HEADER_R, TO_CAMERA)

    # The east run leaves and lands a little north of due west and due east, so that on the middle
    # cap it stands clear of the outlet run, which crosses the same shoulder to the south of it.
    header_run("HeaderWest", on_cap(wx_, 0), on_cap(mx_, 180), CAP_TOP - 0.12)
    header_run("HeaderEast", on_cap(ex_, 160), on_cap(mx_, 20), CAP_TOP - 0.55)

    # THE OUTLET RUN: up half a tile off the middle cap's south side, east over the drum's
    # shoulder, down east of it in the open bay, south in front of the cut-back deck through its
    # valve, and straight down onto a bolted flange on the slab over the steam socket's stub,
    # inboard of the socket's accent band.
    OUT_X = 0.55
    FLANGE = (0.0, -1.76, SLAB)
    ox_, oy_ = mx_, DRUM_Y - RUN_R
    outlet = hose("SteamOutlet",
                  lift(ox_, oy_, 0.47) +
                  [(mx_ + 0.55, oy_ - 0.05, CAP_TOP + 0.42), (OUT_X - 0.2, oy_ - 0.05, CAP_TOP + 0.26),
                   (OUT_X, oy_ - 0.05, CAP_TOP - 0.25),
                   (OUT_X, oy_ - 0.05, 1.7), (OUT_X, oy_ - 0.05, 1.25), (OUT_X, -1.0, 1.0), (OUT_X, -1.2, 0.98),
                   (OUT_X - 0.05, -1.45, 0.98), (FLANGE[0] + 0.05, FLANGE[1], 0.92),
                   (FLANGE[0], FLANGE[1], 0.7), (FLANGE[0], FLANGE[1], 0.45), (FLANGE[0], FLANGE[1], SLAB - 0.04)],
                  HEADER_R, **HEADER)
    line = rf_parts.centreline(outlet)
    p, d_ = rf.along(line, 1, -1.2)
    rf_parts.valve("SteamOutletValve", p, d_, HEADER_R, (0, 0, 1))
    p, d_ = rf.along(line, 2, 2.3)
    torus("SteamOutletBand", HEADER_R + 0.04, 0.05, p, "steam", rot=rf_parts._facing(d_))
    cyl("SteamOutletFlange", 0.34, 0.06, (FLANGE[0], FLANGE[1], SLAB + 0.03), "metal", verts=40, read=0.68)
    rf_parts.bolts("SteamOutletBolts", rf.ring((FLANGE[0], FLANGE[1], SLAB + 0.06), 0.295, 8, phase=0.2))

    # -- THE SERVICE PLATFORM: a grating laid on the top rails, its south and west edges marked as
    # walkway edges, its north and east edges unmarked, a toe board on each, and the hatch the
    # access ladder comes up through, the lid standing open beside it.
    # THE HATCH IS CUT THROUGH THE SOUTH EDGE, not "just inside" it as the note has it: a strip of
    # deck south of the hatch puts its marked edge bar and toe board across the ladder, which the
    # note also says nothing may cross. The edge's marking stops either side of the hatch.
    rf_parts.grating_deck("Platform", (sum(PLAT_X) / 2, sum(PLAT_Y) / 2), (PLAT_X[1] - PLAT_X[0], PLAT_Y[1] - PLAT_Y[0]),
                          PLATFORM, along="X", openings=(HATCH,), open_edges=("+X", "-X", "+Y", "-Y"),
                          marked_edges=("-X", "-Y"))
    (hx_, hy_), (hw_, hd_) = HATCH
    box("HatchLid", (0.04, hd_ - 0.02, hw_ - 0.1), (hx_ - hw_ / 2 - 0.04, hy_, PLATFORM + (hw_ - 0.1) / 2), "dark",
        read=0.6)
    # FACING NORTH, so the cage stands over the hatch and round it above the deck, and the stiles and
    # rungs face the camera; the cage starts low enough to come up through the hatch with the climb.
    rf_parts.access_ladder("AccessLadder", (*LADDER, DECK), PLATFORM + 1.0, (0, 1, 0), cage_from=0.45)

    # -- GUARD RAIL: one hazard rail at hand height in lengths between the posts, stopping short of
    # the outlet run at a yellow stanchion and taking up again at the next post east.
    STANCHION = -0.45
    for name, (a, b) in (("W3", (-7.0, -14 / 3)), ("W2", (-14 / 3, -7 / 3)), ("W1", (-7 / 3, STANCHION)),
                         ("E1", (7 / 3, 14 / 3)), ("E2", (14 / 3, 7.0))):
        a_, b_ = a + 0.09, b - (0.04 if b == STANCHION else 0.09)
        cyl(f"GuardRail{name}", 0.035, b_ - a_, ((a_ + b_) / 2, POST_Y, RAIL_Z), "hazard", axis="X", verts=16)
    cyl("Stanchion", 0.04, RAIL_Z + 0.04 - SLAB, (STANCHION, POST_Y, (SLAB + RAIL_Z + 0.04) / 2), "hazard", verts=16)

    # -- THE CONTROL CABINET at the south-west corner, behind the post line in the end bay: taller
    # than the guard rail, its top in inset panels, its blue panel and a warning plate under it on
    # the face toward the camera.
    CAB = (-6.45, -1.625, 0.8, 0.55, 2.5)     # centre x, y, width, depth, top
    cab_face = CAB[1] - CAB[3] / 2
    box("Cabinet", (CAB[2], CAB[3], CAB[4] - DECK), (CAB[0], CAB[1], (DECK + CAB[4]) / 2), "paint")
    seam("CabinetDoor", (0.05, 0.05, CAB[4] - DECK - 0.3), (CAB[0] + 0.12, cab_face, (DECK + CAB[4]) / 2))
    rf_parts.panels("CabinetTop", (CAB[0], CAB[1], CAB[4]), (CAB[2], CAB[3]), "+Z", (2, 2), material="paint")
    box("CabinetPanel", (0.5, 0.04, 0.32), (CAB[0], cab_face - 0.01, 2.22), "water", read=0.32)
    rf_parts.warning_plate("CabinetWarning", (CAB[0], cab_face, 1.93), (0.44, 0.2), "-Y", stripes=3)

    # -- THE CABLE TRAY at the guard rail's height, just inside it on brackets off the posts, and the
    # loom in it from the cabinet's top the whole way east.
    # ITS BED IS AT 1.80, NOT 1.75: where it jogs north across the platform its brackets have to
    # clear the platform's toe boards, which stand to 1.69.
    # AND IT JOGS NORTH ACROSS THE PLATFORM, BEHIND THE ACCESS LADDER'S CAGE, because the note puts
    # the tray along the south face the whole way and nothing in front of the ladder; the note does
    # not say how the one gets past the other.
    tray_pts = [(-5.95, TRAY_Y, TRAY_Z)] + [(x, TRAY_Y, TRAY_Z) for x in (-14 / 3, -7 / 3, STANCHION)] + [
        (0.98, TRAY_Y, TRAY_Z), (1.06, -0.85, TRAY_Z), (2.1, -0.85, TRAY_Z), (2.25, TRAY_Y, TRAY_Z),
        (14 / 3, TRAY_Y, TRAY_Z), (6.6, TRAY_Y, TRAY_Z)]
    tray = rf_parts.cable_tray("CableTray", tray_pts, 0.2)
    spread = rf.loom_spread(3, 0.035) + 0.035
    lie = rf.tray_lie(tray, spread)
    dense = [lie[0]]
    for a, b in zip(lie, lie[1:]):
        n = max(1, round(math.dist(a, b) / 0.35))
        dense += [tuple(a[j] + (b[j] - a[j]) * (k + 1) / n for j in range(3)) for k in range(n)]
    cab_top = (CAB[0] + 0.15, CAB[1] - 0.1)
    loom_pts = [(*cab_top, CAB[4] - 0.05), (*cab_top, CAB[4] + 0.12), (-6.1, TRAY_Y + 0.05, CAB[4] + 0.05),
                (-5.98, TRAY_Y, TRAY_Z + 0.35)] + dense + [
        (6.75, TRAY_Y, lie[-1][2] - 0.05), (6.8, TRAY_Y, 1.3), (6.8, TRAY_Y, DECK + 0.1), (6.8, TRAY_Y, DECK - 0.04)]
    rf_parts.loom("Loom", loom_pts, ties=False)
    # A DROP TO EVERY DRUM, out of the tray, up the drum's flank and into its gauge box's gland.
    for name, (gx, gy) in gauges.items():
        lz = lie[0][2]
        rf_parts.loom(f"LoomDrop{name}",
                      [(gx, TRAY_Y, lz), (gx, TRAY_Y + 0.16, lz + 0.06), (gx, gy - 0.2, GLAND - 0.12),
                       (gx, gy - 0.04, GLAND - 0.1), (gx, gy, GLAND - 0.04), (gx, gy, GLAND + 0.02)],
                      cables=("cable-red", "cable-green"), twist=0.9, ties=False)

    # -- THE CONDUIT on clamps along the outer face of the south top rail, between two junction
    # boxes, from the cabinet's corner to the post at the open bay.
    CON_Y, CON_Z = POST_Y - 0.155, BEAM_Z
    pipe("Conduit", [(-6.62, CON_Y, CON_Z), (-4.6, CON_Y, CON_Z + 0.01), (-2.68, CON_Y, CON_Z)], 0.042, "dark")
    for name, x in (("West", -6.75), ("East", -2.55)):
        box(f"ConduitBox{name}", (0.24, 0.07, 0.24), (x, CON_Y + 0.005, CON_Z), "paint", read=0.24)
    for x in (-6.0, -5.2, -4.2, -3.4):
        box(f"ConduitClamp{x:+.1f}", (0.07, 0.06, 0.12), (x, CON_Y, CON_Z), "dark", bev=0.01)

    # -- THE WEST END WALL: painted, with a vent, stopping above the west sockets' accent bands.
    WALL_X = -7.16
    wall_foot = 0.42
    box("EndWall", (0.07, MAN_IN - deck_y[0] + 0.05, TOP - wall_foot), (WALL_X, (MAN_IN + deck_y[0]) / 2,
        (wall_foot + TOP) / 2), "paint")
    for z in (0.8, 0.92, 1.04, 1.16):
        box(f"EndWallLouvre{z:.2f}", (0.06, 0.9, 0.06), (WALL_X - 0.04, -0.2, z), "dark", bev=0)

    # -- COOLERS past each end drum: the same module at both ends, four fan discs on a shaft.
    for name, x in (("West", -5.65), ("East", 5.65)):
        cyl(f"Cooler{name}Plinth", 0.22, 0.1, (x, DRUM_Y, DECK + 0.05), "dark", verts=24)
        cyl(f"Cooler{name}Shaft", 0.05, 1.1, (x, DRUM_Y, DECK + 0.55), "dark", verts=16)
        cyl(f"Cooler{name}Cap", 0.1, 0.06, (x, DRUM_Y, DECK + 1.13), "dark", verts=16)
        rf_parts.fan_discs(f"Cooler{name}", rf.stack((x, DRUM_Y, DECK + 0.3), 4, 0.24), 0.42)

    # -- SOCKETS, one per declared connection, at pipe height and thickness; the three reactor-energy
    # ones contained, so neither rim nor flanges.
    for c in geo["connections"]:
        rf_parts.socket(slab, c, geo, rf_parts.SOCKET_Z, 0.249, plumbable=c["connection_category"] is None)

    # -- THE ENERGY FEEDS, glowing: from each short end's socket up through the slab into the
    # manifold, and from the manifold south under the grating to the foot of each drum, beside it.
    for name, sx in (("West", -1), ("East", 1)):
        x = sx * 6.5
        pipe(f"EnergyFeed{name}", [(sx * 6.85, 1.0, rf_parts.SOCKET_Z), (sx * 6.62, 1.0, rf_parts.SOCKET_Z),
                                   (x, 1.0, 0.2), (x, 1.0, 0.38), (x, 1.2, WATER_Z), (x, MAN_IN + 0.2, WATER_Z)],
             0.1, "energy", glow=True)
        torus(f"EnergyFeed{name}Collar", 0.16, 0.04, (x, 1.0, SLAB + 0.01), "dark")
    for name, d in DRUMS.items():
        fx = d["x"] + d["feed"] * (DRUM_R + 0.15)
        inx = d["x"] + d["feed"] * (DRUM_R - 0.4)
        pipe(f"EnergyFeed{name}Drum", [(fx, MAN_IN + 0.2, WATER_Z), (fx, MAN_IN - 0.4, WATER_Z),
                                       (fx, DRUM_Y + 0.25, WATER_Z), (fx - d["feed"] * 0.25, DRUM_Y, WATER_Z),
                                       (inx, DRUM_Y, WATER_Z + 0.05), (inx, DRUM_Y, DECK + 0.2)],
             0.08, "energy", glow=True)

    # -- THE WATER HEADER under the grating between its two sockets, on a pipe support either side
    # of the middle drum, turning down into the slab short of each socket through a bolted collar.
    WX = 6.3
    pipe("WaterHeader", [(-WX, WATER_Y, SLAB - 0.12), (-WX, WATER_Y, SLAB + 0.08), (-WX + 0.22, WATER_Y, WATER_Z),
                         (-5.5, WATER_Y, WATER_Z), (5.5, WATER_Y, WATER_Z), (WX - 0.22, WATER_Y, WATER_Z), (WX, WATER_Y, SLAB + 0.08), (WX, WATER_Y, SLAB - 0.12)],
         WATER_R, "metal")
    for name, sx in (("West", -1), ("East", 1)):
        cyl(f"WaterCollar{name}", 0.3, 0.05, (sx * WX, WATER_Y, SLAB + 0.025), "dark", verts=32, read=0.6)
        rf_parts.bolts(f"WaterCollar{name}Bolts", rf.ring((sx * WX, WATER_Y, SLAB + 0.05), 0.24, 6, phase=0.3))
    rf_parts.pipe_supports("WaterSupports", [((-2.1, WATER_Y, WATER_Z), (0, 0, 0)), ((1.45, WATER_Y, WATER_Z), (0, 0, 0))],
                           WATER_R, SLAB)

    top = max((o.matrix_world @ v.co).z for o in scene.objects if o.type == "MESH" for v in o.data.vertices)
    print(f"HEIGHT: tallest mesh vertex {top:.3f}")

# THE ICON IS THE WHOLE MACHINE, ON THE DIAGONAL (house style, Icon). Turned 35 degrees, fifteen by
# five spans about 15.2 tiles across the screen and 15.4 up it with the height showing at 0.707 h,
# so a 14.5-tile window holds it with a little margin, centred on the machine at half its height.
if variant == "cube":
    tiles_w, tiles_h, icon_centre, icon_tiles, icon_yaw = 1, 1, (0, 0, 0.5), 1.5, 0.0
else:
    tiles_w, tiles_h = geo["tiles"]
    icon_centre, icon_tiles, icon_yaw = (0.0, 0.0, 1.9), 14.5, 35.0
rf.build_rig(scene, tiles_w, tiles_h, icon_centre, icon_tiles, icon_yaw=icon_yaw)
scene["rf_geometry_sha256"] = rf.geometry_sha256(geo_path)
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(out_path))
print("BUILT", variant, os.path.abspath(out_path), scene.render.resolution_x, scene.render.resolution_y)

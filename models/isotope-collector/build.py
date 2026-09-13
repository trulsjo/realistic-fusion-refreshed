"""Build the isotope collector model from its look note, headless. This is what "regenerate" reruns.

    blender -b --python build.py -- [out.blend] [machine|cube]

Reads geometry.json beside this file for the collision box and the connections, so the sockets land
where the prototype declares them, and stamps that file's hash on the scene so render.py can refuse
a model whose geometry has moved on. Everything is a primitive or a curve with a procedural
material: nothing imported (house style, licence rule).

THE MACHINE IS SQUARE AND IS BUILT IN THE DECLARED FRAME. There is no turn at the end the way
models/heat-exchanger/build.py has one: five by five has no long axis to disagree about, and the
look note's whole first point is that no face is a contact face.

THE LOOK NOTE NOW DESCRIBES THIS OBJECT, not the draft it started as. The draft was written from
what the machine does, before anyone knew what the footprint would allow, and it was wrong in eight
places -- most of all in putting the tritium drum on the east-west line, in line with the two
sockets it feeds, where the cold box stands. Truls had it rewritten from the shipped model on
2026-09-13 rather than left to rot, which is #275's lesson taken before it bites: that machine's
note went stale, and a model rebuilt from it came back as a different machine.
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
# file is written in, and prefixing 60 call sites would be the diff that hides whether
# anything else moved. Named one by one rather than starred, so what this file uses can be
# read off the import line -- and `bevel` is NOT among them: every machine's bevels are put
# on from inside the helpers, so importing it here only made a name nothing calls.
import rf_parts  # noqa: E402
from rf_parts import box, cyl, hbeam, jitter, pipe, rivets, seam, torus  # noqa: E402,F401

args = rf.script_args()
out_path = args[0] if args else os.path.join(HERE, "isotope-collector.blend")
variant = args[1] if len(args) > 1 else "machine"
random.seed(11)  # imperfections are deterministic: same script, same model

geo_path = os.path.join(HERE, "geometry.json")
geo = json.load(open(geo_path, encoding="utf-8"))
(x0, y0), (x1, y1) = geo["collision_box"]
TX, TY = (x1 - x0) / 2, (y1 - y0) / 2       # declared half extents: 2.25 x 2.25
HALF = min(TX, TY)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = "rf"

# ---- materials (house style palette) -------------------------------------------------------
#
# The same values the heat exchanger settled on for #252, so the two machines read as one plant;
# "tritium" and "helium-3" are new, and are the fluids' own icon colours rather than fresh picks
# (rf_blender.ACCENT_OF_FLUID says why).
PALETTE = {
    "body":     ((0.24, 0.26, 0.30), 0.72, 0.0),
    "frame":    ((0.07, 0.08, 0.09), 0.6, 0.2),
    "metal":    ((0.55, 0.55, 0.58), 0.35, 0.8),
    "dark":     ((0.26, 0.27, 0.29), 0.5, 0.7),
    "paint":    ((0.58, 0.55, 0.47), 0.8, 0.0),
    "tritium":  ((0.50, 1.00, 0.60), 0.5, 0.0),
    "helium-3": ((0.80, 0.45, 1.00), 0.5, 0.0),
}
# NO WATER ENTRY, and that is the point rather than an omission. The heat exchanger's control
# cabinet wears a blue panel and may: it carries water. This machine carries none, and the house
# style gives the water accent to "every surface that carries water" on the grounds that a player
# reads a machine's plumbing from its colours before reading its tooltip -- so a blue panel here
# would tell them about a pipe that does not exist. The cabinet's panel is a dark screen instead.
ACCENTS = ("tritium", "helium-3")            # stay clean: no grime, no frost, so they read
MATS = {}

# FROST IS THIS MACHINE'S CORROSION. The heat exchanger rusts because it is hot and wet; this one
# rimes because it is cold, and the note makes the pair deliberate. Two things in the mask rather
# than one, for the same reason the rust needed three: an even white wash over a whole panel reads
# as a paint colour and not as ice.
#
#   * a noise, so it is patchy;
#   * HOW FAR THE SURFACE FACES UP, so rime gathers on lids, cap flanges and the tops of tubes and
#     thins away down a wall -- which is where it collects for real and, at this camera, the only
#     place it can be seen. Not to nothing: a vertical wall keeps about a quarter of the rime a
#     lid gets, or the box's south and west faces -- the two the camera and the sun reach -- would
#     be the only bare steel on a machine whose whole point is that it is cold.
#
# THE FIRST VERSION OF THAT SECOND TERM WAS THE OBJECT'S OWN HEIGHT, read from Generated texture
# coordinates, and it was wrong on every part that is rotated. Generated coordinates are the
# object's LOCAL bounding box and take no notice of the object's rotation, while `cyl` builds every
# cylinder along local Z and turns the object afterwards -- so on both drums, all three socket
# stubs and all four dished ends the gradient ran along the tube's AXIS and laid the rime on one
# END of each. It looked plausible in a render because a drum with a frosted end is not an obviously
# impossible object. The surface normal's world Z has no such hole: it is the same number whichever
# way the part was built and turned.
# Not on accents and not on the slab: an accent has to read as its fluid's colour, and a frosted
# base slab would put ice on the ground.
FROST = (0.86, 0.90, 0.94)


def mat(name, frost=False):
    key = (name, frost)
    if key in MATS:
        return MATS[key]
    rgb, rough, metal = PALETTE[name]
    m = bpy.data.materials.new(f"{name}{'-frost' if frost else ''}")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if name in ACCENTS:
        MATS[key] = m
        return m
    # GRIME, the heat exchanger's exactly: a broad noise for patches blended with a fine one for
    # streaks, through a ramp, with roughness swinging by 0.5 so a big curved bare-metal surface
    # does not hold one clean highlight. Blended and not summed -- summing pushes the mask past the
    # top of the ramp nearly everywhere and every surface comes out uniformly muddy (#252).
    nt = m.node_tree
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 4.0
    noise.inputs["Detail"].default_value = 6.0
    fine = nt.nodes.new("ShaderNodeTexNoise")
    fine.inputs["Scale"].default_value = 22.0
    fine.inputs["Detail"].default_value = 4.0
    combine = nt.nodes.new("ShaderNodeMix")
    combine.data_type = "FLOAT"
    combine.inputs[0].default_value = 0.35
    nt.links.new(noise.outputs["Fac"], combine.inputs[2])
    nt.links.new(fine.outputs["Fac"], combine.inputs[3])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.40
    ramp.color_ramp.elements[1].position = 0.72
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = (*rgb, 1.0)
    mix.inputs["B"].default_value = (rgb[0] * 0.5, rgb[1] * 0.45, rgb[2] * 0.4, 1.0)
    nt.links.new(combine.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], mix.inputs["Factor"])
    colour_out = mix.outputs["Result"]
    rough_target = rough
    if frost:
        facing = nt.nodes.new("ShaderNodeNewGeometry")
        up = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(facing.outputs["Normal"], up.inputs["Vector"])
        rime = nt.nodes.new("ShaderNodeTexNoise")
        rime.inputs["Scale"].default_value = 13.0
        rime.inputs["Detail"].default_value = 7.0
        # THE FIRST TRY WAS A WHITEWASH and the cold box came out as a block of snow. The ramp
        # opened at 0.45, so more than half of every surface took some rime and the gradient then
        # carried it up the panel unbroken. Opening at 0.62 and closing at 0.78 leaves most of the
        # steel bare and puts ice in the top few patches, which is what the note asks for -- rime,
        # not a paint colour.
        rime_ramp = nt.nodes.new("ShaderNodeValToRGB")
        rime_ramp.color_ramp.elements[0].position = 0.62
        rime_ramp.color_ramp.elements[1].position = 0.78
        nt.links.new(rime.outputs["Fac"], rime_ramp.inputs["Fac"])
        # The facing gradient is a MULTIPLIER on the patchiness, not a second layer over it: added,
        # the two give a solid white cap and a hard line where it stops, which is a snow drift
        # rather than rime.
        #
        # Normal Z is -1 underneath, 0 on a vertical wall and 1 on a lid, so the range below reads
        # as: undersides 0.18, walls about 0.27, lids 0.7. The top never reaches 1 because even in
        # its thickest patch the rime has to let the steel through, or it stops being a film on a
        # surface and becomes the surface.
        gate = nt.nodes.new("ShaderNodeMapRange")
        gate.clamp = True
        for socket, v in (("From Min", -0.2), ("From Max", 0.9), ("To Min", 0.18), ("To Max", 0.7)):
            gate.inputs[socket].default_value = v
        nt.links.new(up.outputs["Z"], gate.inputs["Value"])
        mask = nt.nodes.new("ShaderNodeMath")
        mask.operation = "MULTIPLY"
        nt.links.new(rime_ramp.outputs["Color"], mask.inputs[0])
        nt.links.new(gate.outputs["Result"], mask.inputs[1])
        icy = nt.nodes.new("ShaderNodeMix")
        icy.data_type = "RGBA"
        icy.inputs["B"].default_value = (*FROST, 1.0)
        nt.links.new(mask.outputs["Value"], icy.inputs["Factor"])
        nt.links.new(colour_out, icy.inputs["A"])
        colour_out = icy.outputs["Result"]
        rough_target = min(1.0, rough + 0.2)     # rime is matte whatever it sits on
    nt.links.new(colour_out, b.inputs["Base Color"])
    rmix = nt.nodes.new("ShaderNodeMath")
    rmix.operation = "MULTIPLY_ADD"
    rmix.inputs[1].default_value = 0.5
    rmix.inputs[2].default_value = rough_target
    nt.links.new(ramp.outputs["Color"], rmix.inputs[0])
    nt.links.new(rmix.outputs["Value"], b.inputs["Roughness"])
    MATS[key] = m
    return m


def receiver(name, centre, radius, length, accent, valve_at, gauges=True):
    """A horizontal receiver drum lying along X: ribs, a weld seam, dished ends, a relief valve on
    top (the part that could move later), and -- when `gauges` -- a sight gauge at one end and a
    handwheel at the OTHER, on the drum's south face.

    `valve_at` is the x sign the gauge stands at and the handwheel takes the other, so the two
    drums are not identical copies of each other.

    `gauges=False` for a drum in the NORTH bay, where neither can be seen. The cluster hangs off
    the south face, which for a north drum is the strip between it and the cold box: at this
    camera the box occludes the whole of it, and the handwheel and its stem ran into the box's
    north wall besides. Building detail that is invisible AND intersecting is worse than building
    none, so the north drum goes without and the machine is a little less symmetric for it.
    """
    cx, cy, cz = centre
    d = cyl(f"{name}Shell", radius, length, centre, "metal", axis="X", verts=56, frost=True)
    d.scale = (1.0, jitter(1.0, 0.02), 1.0)
    for k, frac in enumerate((-0.28, 0.30)):
        torus(f"{name}Rib{k}", radius + 0.015, 0.035, (cx + frac * length, cy, cz), "dark",
              rot=(0, math.pi / 2, 0))
    seam(f"{name}Weld", (0.05, 0.05, 2 * radius + 0.02),
         (cx + jitter(0, 0.2), cy - radius + 0.02, cz), rot=(0, jitter(0, 0.15), 0))
    for sx in (-1, 1):                                    # dished ends
        cyl(f"{name}End{sx}", radius * 0.92, 0.1, (cx + sx * (length / 2 + 0.04), cy, cz),
            "metal", axis="X", verts=40, frost=True)
        torus(f"{name}EndFlange{sx}", radius * 0.94, 0.05,
              (cx + sx * (length / 2 + 0.01), cy, cz), "metal", rot=(0, math.pi / 2, 0), frost=True)
    # Relief valve on top: bare metal with an accent band, never a body in the accent -- the house
    # style says an accent is a band, and a whole valve in near-white blew out on the heat
    # exchanger's drum tops (Truls, #252).
    vx = cx + jitter(0.15, 0.1)
    cyl(f"{name}ValveStem", 0.08, 0.3, (vx, cy, cz + radius + 0.15), "metal", verts=24)
    cyl(f"{name}ValveBody", 0.14, 0.2, (vx, cy, cz + radius + 0.38), "dark", verts=24)
    torus(f"{name}ValveBand", 0.15, 0.03, (vx, cy, cz + radius + 0.38), accent)
    cyl(f"{name}ValveCap", 0.06, 0.22, (vx, cy + 0.16, cz + radius + 0.38), "metal", axis="Y",
        verts=16)
    if not gauges:
        return
    # Sight gauge at one end and handwheel at the other, on the south face where the camera sees
    # them. Both hang off the drum, so how far the drum stands from the footprint edge is what
    # decides whether they stay inside the collision box -- see T_DRUM.
    gx = cx + valve_at * (length / 2 - 0.35)
    box(f"{name}Gauges", (0.42, 0.2, 0.34), (gx, cy - radius - 0.08, cz - 0.05), "paint")
    cyl(f"{name}Glass", 0.1, 0.06, (gx, cy - radius - 0.2, cz - 0.05), accent, axis="Y", verts=20,
        read=0.2)
    wx = cx - valve_at * (length / 2 - 0.3)
    cyl(f"{name}WheelStem", 0.055, 0.3, (wx, cy - radius - 0.12, cz + 0.05), "metal", axis="Y",
        verts=12)
    torus(f"{name}Wheel", 0.2, 0.04, (wx, cy - radius - 0.26, cz + 0.05), "dark",
          rot=(math.pi / 2, 0, 0))


def column(name, base, radius, height, accent):
    """A distillation column standing on the cold box: ribs, a weld seam, a bolted cap flange with
    a ring of bolts, and one accent band at the cap -- the whole machine's colour, per the note."""
    cx, cy, z0 = base
    cyl(f"{name}Shell", radius, height, (cx, cy, z0 + height / 2), "metal", verts=48, frost=True)
    for k, frac in enumerate((0.26, 0.58, 0.86)):
        torus(f"{name}Rib{k}", radius + 0.012, 0.03, (cx, cy, z0 + height * frac), "dark")
    seam(f"{name}Weld", (0.05, 2 * radius + 0.02, 0.05),
         (cx + radius - 0.02, cy, z0 + height * 0.42), rot=(0, 0, jitter(0, 0.2)))
    top = z0 + height
    torus(f"{name}CapFlange", radius * 0.98, 0.05, (cx, cy, top), "metal", frost=True)
    cyl(f"{name}Cap", radius * 0.72, 0.16, (cx, cy, top + 0.08), "metal", verts=32, frost=True)
    # THE BAND IS THE TALLEST THING ON THE COLUMN, so it is what the height budget is measured
    # against. At top + 0.13 its 0.045 minor radius reached 2.505 on the taller column -- over the
    # 2.5 the house style allows a five-wide, by a third of a pixel, while this file claimed the
    # cap was met. 0.11 puts it under.
    torus(f"{name}Band", radius * 0.8, 0.045, (cx, cy, top + 0.11), accent)
    for k in range(8):
        a = 2 * math.pi * k / 8
        bpy.ops.mesh.primitive_cylinder_add(
            radius=0.032, depth=0.05, vertices=8,
            location=(cx + radius * 0.98 * math.cos(a), cy + radius * 0.98 * math.sin(a), top + 0.03))
        bpy.context.object.name = f"{name}CapBolt{k}"
        bpy.context.object.data.materials.append(mat("dark"))
    # The cap's top, which with the band dropped to 0.11 is now the column's true maximum: the band
    # reaches top + 0.155 and the cap top + 0.16. It was not before, and that is why this file could
    # claim the height budget was met while the taller column stood 0.005 over it.
    return top + 0.16


rf_parts.use(mat)

# ---- the machine ----------------------------------------------------------------------------
if variant == "cube":
    box("Cube", (1, 1, 1), (0, 0, 0.5), "body")
else:
    # THE HEIGHT BUDGET IS 2.5 TILES and every number below is spent against it. The house style
    # gives a five-wide machine 1.5 to 2.5 tiles, and the first render broke it: a slab, a 1.5-tile
    # cold box and 1.55 tiles of column with its cap stood 3.52, which is 1.4 times the cap. (NOT
    # "taller than the fifteen-wide heat exchanger is allowed", which an earlier draft of this
    # comment claimed -- the house style allows a fifteen-wide FOUR tiles, so 3.52 would have been
    # legal on that machine and is not on this one. The rule is per width.) The box is squat
    # instead and the columns get the height, which is also what makes them read as SLIM: 0.24 of
    # radius over 1.32 of run on the tritium column, 0.19 over 1.00 on the helium-3 one.
    SLAB = 0.25
    BOX_HALF = 1.25                      # the cold box: 2.5 x 2.5, leaving a 1-tile bay all round
    BOX_H = 0.7
    BOX_TOP = SLAB + BOX_H               # 0.95
    DECK_Z = SLAB + 0.2                  # top of the walkway plates in the bays

    box("Slab", (2 * HALF, 2 * HALF, SLAB), (0, 0, SLAB / 2), "frame")
    seam("SlabSeam", (2 * HALF + 0.02, 0.05, 0.05), (0, jitter(0, 0.5), SLAB))
    seam("SlabSeam2", (0.05, 2 * HALF + 0.02, 0.05), (jitter(0, 0.5), 0, SLAB))

    # -- the cold box. Closed panels, not an open frame: a vacuum-jacketed cold box is closed for
    # real, which is the house style's own exception. Frosted, and it is the biggest frosted
    # surface on the machine -- the rime gathers on its upper panels and thins downward.
    box("ColdBox", (2 * BOX_HALF, 2 * BOX_HALF, BOX_H), (0, 0, SLAB + BOX_H / 2), "body", frost=True)
    for i in range(3):                   # a seam grid: verticals on all four walls, one band round
        t = -BOX_HALF + (i + 1) * (2 * BOX_HALF) / 4
        seam(f"BoxSeamX{i}", (0.05, 2 * BOX_HALF + 0.02, BOX_H - 0.24), (t, 0, SLAB + BOX_H / 2))
        seam(f"BoxSeamY{i}", (2 * BOX_HALF + 0.02, 0.05, BOX_H - 0.24), (0, t, SLAB + BOX_H / 2))
    # A BAND ROUND THE BODY, not a groove cut into it, so it is a plate and takes the raised
    # floor -- #335's decision, and the one call that `seam` was doing the wrong kind of work for.
    box("BoxBand", (2 * BOX_HALF + 0.03, 2 * BOX_HALF + 0.03, 0.06), (0, 0, SLAB + BOX_H * 0.62),
        "frame", bev=0)
    for sx, sy in ((0, -1), (-1, 0)):    # rivet lines on the two walls the sun and camera reach
        rivets(f"BoxRivets{sx}{sy}",
               (sx * (BOX_HALF + 0.01) + sy * (-BOX_HALF + 0.25), sy * (BOX_HALF + 0.01) + sx * (-BOX_HALF + 0.25), BOX_TOP - 0.18),
               (sx * (BOX_HALF + 0.01) + sy * (BOX_HALF - 0.25), sy * (BOX_HALF + 0.01) + sx * (BOX_HALF - 0.25), BOX_TOP - 0.18),
               9, r=0.035)
    box("BoxLid", (2 * BOX_HALF - 0.12, 2 * BOX_HALF - 0.12, 0.08), (0, 0, BOX_TOP + 0.02),
        "dark", frost=True)

    # -- the walkway: a deck in all four bays on short H-beam posts, so the machine reads as part
    # of the same plant as the open-framed ones.
    # THE POST SECTION IS PASSED, NOT INHERITED (#340). While these helpers were copied per machine
    # this file's `hbeam` defaulted to 0.18 x 0.14 and the heat exchanger's to 0.2 x 0.16 -- a
    # divergence nobody chose, discovered only when the two were pulled into one module and the
    # collector's deck posts silently thickened. These are its own numbers: a deck post is a lighter
    # member than a fifteen-tile frame's, and it stays that way.
    POST = dict(depth=0.18, flange=0.14)
    for sx in (-1, 1):
        for sy in (-1, 1):
            hbeam(f"Post{sx}{sy}", DECK_Z - SLAB, (sx * (HALF - 0.2), sy * (HALF - 0.2), SLAB + (DECK_Z - SLAB) / 2), **POST)
            hbeam(f"PostMidX{sx}{sy}", DECK_Z - SLAB, (sx * (HALF - 0.2), sy * 0.55, SLAB + (DECK_Z - SLAB) / 2), **POST)
            hbeam(f"PostMidY{sx}{sy}", DECK_Z - SLAB, (sx * 0.55, sy * (HALF - 0.2), SLAB + (DECK_Z - SLAB) / 2), **POST)
    BAY = HALF - BOX_HALF                                  # 1.0 tile of deck on each side
    # THE DECK OPENS WHERE A SOCKET CROSSES IT, which is not a detail but the thing that lets the
    # sockets be seen at all. A socket stands at z 0.55 with a radius of 0.3, so its top is above
    # the grating: an unbroken ring would bury all three stubs and leave a machine whose plumbing
    # cannot be read, which is the one thing the house style's accents exist to prevent. A walkway
    # has an opening where a pipe comes through it, so the slats over a socket lane are left out.
    # A PLATE WITH GROOVES CUT IN IT, not a row of bars with gaps between them. Two rounds of bars
    # both failed the same way: thin at 0.06 they were a comb, wide at 0.2 they were a heatsink,
    # because what the eye reads at 64 px a tile is the DARK between them, and a ring of dark
    # stripes round a box is cooling fins whatever the bars are doing. A deck is mostly floor, so
    # the floor is solid and the grating is a shallow groove every 0.3 -- the same picture, with
    # the light and dark the right way round.
    GROOVE_PITCH = 0.3
    SOCKET_LANE = 0.45
    lanes = {d: [] for d in ("north", "south", "east", "west")}
    for c in geo["connections"]:
        px, py = c["position"]
        lanes[c["direction"]].append(px if c["direction"] in ("north", "south") else -py)

    def segments(lo, hi, holes):
        """`lo`..`hi` with a socket lane cut out around each hole, as (centre, length) pairs. The
        openings are what let a socket be seen: a stub tops out above the deck, so an unbroken plate
        would bury all three and leave a machine whose plumbing cannot be read."""
        edges = [lo]
        for h in sorted(holes):
            edges += [h - SOCKET_LANE, h + SOCKET_LANE]
        edges.append(hi)
        return [((a + b) / 2, b - a) for a, b in zip(edges[::2], edges[1::2]) if b - a > 0.12]

    for sy in (-1, 1):                                     # north and south bays, full width
        d = "north" if sy > 0 else "south"
        cy = sy * (BOX_HALF + BAY / 2)
        for k, (cx, length) in enumerate(segments(-HALF + 0.05, HALF - 0.05, lanes[d])):
            box(f"Deck{d}{k}", (length, BAY - 0.06, 0.06), (cx, cy, DECK_Z), "dark", bev=0.01)
            for i in range(int(length / GROOVE_PITCH)):
                seam(f"Groove{d}{k}-{i}", (0.05, BAY - 0.06, 0.05),
                     (cx - length / 2 + (i + 1) * GROOVE_PITCH, cy, DECK_Z + 0.02))
    for sx in (-1, 1):                                     # east and west bays, between them
        d = "east" if sx > 0 else "west"
        cx = sx * (BOX_HALF + BAY / 2)
        for k, (cy, length) in enumerate(segments(-BOX_HALF + 0.03, BOX_HALF - 0.03, lanes[d])):
            box(f"Deck{d}{k}", (BAY - 0.06, length, 0.06), (cx, cy, DECK_Z), "dark", bev=0.01)
            for i in range(int(length / GROOVE_PITCH)):
                seam(f"Groove{d}{k}-{i}", (BAY - 0.06, 0.05, 0.05),
                     (cx, cy - length / 2 + (i + 1) * GROOVE_PITCH, DECK_Z + 0.02))

    # -- two columns on the lid, side by side and of UNEQUAL height: the one thing on the machine
    # that says separation rather than storage. The taller wears tritium's green at its cap and the
    # shorter helium-3's violet. NOT the only colour on the machine, which an earlier draft of the
    # look note claimed: each accent also rides its drum's relief valve and sight glass and both of
    # its sockets, and the control cabinet carries a blue panel that belongs to no fluid.
    T_COL = (-0.45, 0.02)
    H_COL = (0.44, 0.10)
    t_cap = column("ColT", (*T_COL, BOX_TOP + 0.06), 0.24, 1.32, "tritium")
    h_cap = column("ColHe", (*H_COL, BOX_TOP + 0.06), 0.19, 1.00, "helium-3")
    box("ColTie", (abs(T_COL[0] - H_COL[0]), 0.06, 0.06),
        ((T_COL[0] + H_COL[0]) / 2, (T_COL[1] + H_COL[1]) / 2, BOX_TOP + 0.85), "frame", bev=0.01)

    # -- the two receivers, low against the deck in the bays nearest their sockets. The buffer a
    # player can see: 500 units of each, about an hour of a reactor's breeding (see the prototype).
    # THE TRITIUM DRUM DOES NOT RUN THE FULL WIDTH, and that is what makes room for the cabinet and
    # the vent the note puts on the south face: a drum across the whole south bay left them nowhere
    # to stand but inside it. Two tiles of drum to the west, then the vent, then the cabinet at the
    # corner -- which is also the machine's one asymmetry, so the south bay is where it all is.
    # THE TRITIUM DRUM STANDS 0.37 OFF THE COLD BOX AND NOT 0.58, because its gauge cluster hangs
    # off its south face and the house style puts the body inside the COLLISION box: at 0.58 the
    # handwheel reached 0.18 of a tile past the south face, into a tile a player reads as free.
    # The drum's own shell was never the problem -- what overhangs is always the thing bolted to it.
    T_DRUM = (-0.55, -(BOX_HALF + 0.37), DECK_Z + 0.3)
    T_LEN = 2.0
    H_DRUM = (-0.1, BOX_HALF + 0.5, DECK_Z + 0.26)
    receiver("DrumT", T_DRUM, 0.3, T_LEN, "tritium", valve_at=-1)
    receiver("DrumHe", H_DRUM, 0.26, 2.3, "helium-3", valve_at=1, gauges=False)

    # -- the drops: each column's shoulder down the box's side into its own drum. The tritium run
    # goes out over the WEST wall, which the sun hits, and turns south along the bay; the helium-3
    # run crosses the north wall, which is the shorter way to its drum.
    # EACH DROP LEAVES ITS COLUMN AT THE SHOULDER, not off the cap. A run off the cap has to rise
    # before it can turn, and the cap is already at the top of the 2.5-tile budget: the apex would
    # be the tallest thing on the machine and it would be a pipe. Off the side, every drop only
    # ever descends.
    #
    # A RUN ENDS INSIDE THE VESSEL IT JOINS, NOT ON ITS SKIN, and the two numbers that do it are
    # the last control point's depth and the one stacked above it. Truls, on the first render: the
    # two pipes in the west bay "appear unconnected". They were: each ended with its centreline
    # exactly on the drum's top surface, so a tube of radius 0.1 stopped tangent to the shell and
    # showed its open end cap as a disc in the air a pixel above the drum. Worse, the Bezier's
    # tangent there was still the sweep of the descent, so the cap was slanted and read as a cut
    # pipe. Landing 0.25 INSIDE the shell hides the cap, and stacking the last two control points
    # in z makes the approach vertical so the tube meets the drum square instead of glancing off.
    T_LAND = T_DRUM[0] - T_LEN / 2 + 0.30
    pipe("DropT", [(T_COL[0] - 0.2, T_COL[1], t_cap - 0.3),
                   (-(BOX_HALF + 0.35), T_COL[1] - 0.2, BOX_TOP + 0.45),
                   (-(BOX_HALF + 0.45), T_DRUM[1] + 0.45, DECK_Z + 0.70),
                   (T_LAND, T_DRUM[1], T_DRUM[2] + 0.34),
                   (T_LAND, T_DRUM[1], T_DRUM[2] + 0.05)], 0.1, "metal", frost=True)
    H_LAND = H_DRUM[0] + 0.7
    pipe("DropHe", [(H_COL[0] + 0.16, H_COL[1], h_cap - 0.25),
                    (H_COL[0] + 0.2, BOX_HALF + 0.2, BOX_TOP + 0.35),
                    (H_LAND, H_DRUM[1], H_DRUM[2] + 0.30),
                    (H_LAND, H_DRUM[1], H_DRUM[2] + 0.03)], 0.09, "metal", frost=True)

    # -- the asymmetry, in two pieces and two bays. A control cabinet with a dark screen stands at
    # the south-east corner, in the one bay with no socket in it; the vent stack went to the EAST
    # bay, north of the socket lane, because the south bay could not hold the drum, the run leaving
    # its east end, the cabinet AND a stack without something passing through something else. Two
    # bays marked rather than one is the better accident: the four direction sheets are otherwise
    # near enough the same picture turned, and the engine turns the connections and not the
    # picture, so all four are rendered
    # (realistic-fusion-refreshed-assets/graphics/mockup/pictures.lua sets out why at length).
    CAB = (0.72, 0.5, 0.95)
    cpos = (1.48, -(BOX_HALF + 0.47), DECK_Z + CAB[2] / 2)
    box("Cabinet", CAB, cpos, "paint")
    seam("CabinetSeam", (0.05, CAB[1] + 0.02, CAB[2] - 0.24), cpos)
    box("CabinetPanel", (0.42, 0.06, 0.3), (cpos[0], cpos[1] - CAB[1] / 2, cpos[2] + 0.26), "dark",
        bev=0, read=0.3)
    rivets("CabinetRivets", (cpos[0] - 0.28, cpos[1] - CAB[1] / 2 - 0.01, cpos[2] - 0.42),
           (cpos[0] + 0.28, cpos[1] - CAB[1] / 2 - 0.01, cpos[2] - 0.42), 5, r=0.032)
    VENT = (1.75, 0.75, DECK_Z + 0.35)
    box("VentHood", (0.42, 0.3, 0.7), VENT, "paint")
    for k in range(4):
        box(f"VentLouvre{k}", (0.36, 0.06, 0.06), (VENT[0], VENT[1] - 0.16, VENT[2] - 0.22 + k * 0.14), "dark", bev=0)
    cyl("VentStack", 0.11, 1.1, (VENT[0], VENT[1] + 0.04, VENT[2] + 0.9), "metal", verts=24)
    cyl("VentCowl", 0.16, 0.12, (VENT[0], VENT[1] + 0.04, VENT[2] + 1.5), "dark", verts=24)

    # -- sockets: one per declared connection, body to footprint edge, with its fluid's accent
    # band. Placed in the declared frame from geometry.json, so they land where the prototype says.
    (sx0, sy0), (sx1, sy1) = geo["selection_box"]
    UNIT = {"north": (0, -1), "east": (1, 0), "south": (0, 1), "west": (-1, 0)}   # Factorio frame
    SOCKET_Z = 0.55

    def inboard(c, back):
        """`back` tiles inboard of the tile a connection stands on, at socket height.

        NOT "the inner end of the socket", which is what this said on both machines that have one
        and is what put a run 0.2 tiles short of the stub it fed. The socket's inner face is at
        TX - 0.5 (the same expression the socket loop above uses), so back=0.5 lands a quarter of a
        tile PAST it, further in, and anything larger stops short of it in open air. To reach into
        a stub, pass a `back` smaller than 0.5.
        """
        ux, uy = UNIT[c["direction"]]
        px, py = c["position"]
        return (px - back * ux, -(py - back * uy), SOCKET_Z)

    for c in geo["connections"]:
        px, py = c["position"]
        py = -py                                   # Factorio south -> Blender -Y
        d = c["direction"]
        band = rf.accent(c["fluid"])
        if d in ("west", "east"):
            edge = sx0 if d == "west" else sx1
            inner = (TX - 0.5) * (1 if d == "east" else -1)
            cyl(f"Socket-{d}-{c['fluid']}", 0.3, abs(edge - inner), ((edge + inner) / 2, py, SOCKET_Z),
                "metal", axis="X", frost=True)
            cyl(f"Band-{d}-{c['fluid']}", 0.34, 0.22,
                (edge - 0.28 * (1 if d == "east" else -1), py, SOCKET_Z), band, axis="X")
        else:
            edge = -sy0 if d == "north" else -sy1   # flipped: north is +Y
            inner = (TY - 0.5) * (1 if d == "north" else -1)
            cyl(f"Socket-{d}-{c['fluid']}", 0.3, abs(edge - inner), (px, (edge + inner) / 2, SOCKET_Z),
                "metal", axis="Y", frost=True)
            cyl(f"Band-{d}-{c['fluid']}", 0.34, 0.22,
                (px, edge - 0.28 * (1 if d == "north" else -1), SOCKET_Z), band, axis="Y")

    # -- the runs from the tritium drum's two ends up the west and east bays to the two tritium
    # sockets. This is the departure the docstring names: the drum cannot lie on the socket line,
    # so its ends do the travelling. Every tritium connection has a run behind it, which is what
    # the heat exchanger's #275 round decided a socket needs.
    # BOTH ENDS OF THESE RUNS WERE IN MID-AIR on the first render, and for two different reasons.
    #
    # At the drum, the run started 0.1 tiles PAST the dished end cap, heading off along the Bezier's
    # tangent toward the next control point -- so it left the drum at an angle with a visible open
    # mouth. It starts 0.1 INSIDE the shell now, with a second control point stacked along the
    # drum's own axis so the tangent there is axial and the tube comes straight out of the end.
    #
    # At the socket, `back` was 0.45 -- which on the heat exchanger lands inside a fourteen-tile
    # manifold, and here landed in the open air of the bay. A socket's inner end is half a tile in
    # from its tile, so back=0.5 is exactly that end and anything larger STOPS SHORT: 0.45 left a
    # fifth of a tile of nothing between the run and the stub it was supposed to feed. 0.15 puts the
    # run a tenth of a tile inside the stub, which is an overlap and not a gap.
    #
    # The lesson is one lesson: a number copied from another machine's build script is a number
    # measured against another machine's body.
    tritium = [c for c in geo["connections"] if c["fluid"] == "rf-tritium"]
    for c in tritium:
        end = inboard(c, back=0.15)
        sx = 1 if c["direction"] == "east" else -1
        pipe(f"RunT-{c['direction']}",
             [(T_DRUM[0] + sx * (T_LEN / 2 - 0.1), T_DRUM[1], T_DRUM[2]),
              (T_DRUM[0] + sx * (T_LEN / 2 + 0.3), T_DRUM[1], T_DRUM[2]),
              (sx * (HALF - 0.42), T_DRUM[1] + 0.62, DECK_Z + jitter(0.1, 0.03)),
              (sx * (HALF - 0.4), end[1] - 0.25, SOCKET_Z + 0.08),
              end], 0.12, "metal", frost=True)
    # The helium-3 socket needs no run of its own: it stands in the north bay and its stub goes
    # straight into the drum's side, which is the shortest honest plumbing on the machine.

# THE ICON IS THE WHOLE MACHINE IN THE SQUARE, with margin (#252). No yaw: five by five is square,
# so the icon is the north sheet seen closer and turning it would only make it a diamond. The
# window is sized on the SCREEN extent -- five tiles across, and five plus the machine's height
# showing at 0.707 h up the screen. That height is the TRITIUM COLUMN's accent band at about 2.5,
# not the vent stack, which stops at 2.36: 7.3 is 5 + 0.707 x 2.5 + half a tile of margin, and the
# vent would have given 7.17. The centre rides north by half that height so the machine
# sits low in the square with the margin above it.
if variant == "cube":
    tiles_w, tiles_h, icon_centre, icon_tiles, icon_yaw = 1, 1, (0, 0, 0.5), 1.5, 0.0
else:
    tiles_w, tiles_h = geo["tiles"]
    icon_centre, icon_tiles, icon_yaw = (0.0, 0.88, 0.0), 7.3, 0.0
rf.build_rig(scene, tiles_w, tiles_h, icon_centre, icon_tiles, icon_yaw=icon_yaw)
scene["rf_geometry_sha256"] = rf.geometry_sha256(geo_path)
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(out_path))
print("BUILT", variant, os.path.abspath(out_path), scene.render.resolution_x, scene.render.resolution_y)

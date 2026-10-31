"""The mesh helpers every machine's build script shares, imported from inside Blender's Python.

    import rf_parts as parts
    parts.use(mat, geo, seed)   # the machine's material resolver, geometry and seed, first

ONE COPY, because two drifted in a week. models/isotope-collector/build.py was written by copying
these out of models/heat-exchanger/build.py, and by the time #340 pulled them back together the two
disagreed on `rivets`'s default radius, on how many branches `hbeam` carried, on whether `mat` knew
about frost, and on which accents the palette held -- some of that per-machine and right, some of it
a fix one copy got and the other did not. Five more machines are coming and each would have copied
them again (#334 is the same failure arriving by the same route, in colour tables).

WHAT STAYS PER MACHINE: `mat`. The heat exchanger's takes `glow` and `corrode`, the isotope
collector's takes `frost`, and their palettes differ because the machines carry different fluids.
So the five helpers that BUILD a surface -- `box`, `cyl`, `torus`, `pipe` and the `_plate` the
first two go through -- forward whatever keyword flags they are given straight to the resolver and
never look inside them; the kit's `hose` and `panels` forward them the same way. `hbeam`,
`rivets`, `seam` and `port` do not, and are the four that choose their own material: a beam and a
rivet are `frame` and `dark` by default, a seam is always `frame`, and a port's rim is always
`dark`. The kit's `loom`, `bolts`, `fan_discs`, `casing`, `lifting_lugs`, `valve`, `cable_tray`, `grating_deck` and `access_ladder` take no flags either, and name
their materials by role. Passing `frost=True` to one of those is a TypeError rather than a
silent miss, which is the right failure -- but it is a failure, so if a machine ever wants a frosted
rivet the flag has to be plumbed through `rivets` first. `socket` is the one that does both: it
forwards to the tube and its ribs, and chooses the accent and the rim itself. `texture` builds no
surface: a machine's `mat` calls it for a recorded CC0 image's colour to wire into its own nodes
(ADR 0043, #805).

AND A SOCKET'S NUMBERS ARE RE-EXPORTED RATHER THAN HELD: `SOCKET_Z`, the height a player-facing
socket is drawn at, and since #365 the ten proportions that say where its rim, its band and its
flange ribs sit on the tube. They were here for the same reason the helpers are -- the second
machine to need them would have copied them -- and they now live in models/rf_blender.py, which
imports no bpy, so the tools that measure a socket can read the same numbers the models are built
at (#354, #365). Every caller still reads them here: build scripts say `rf_parts.SOCKET_Z`, and
models/socket-variants.py takes the three flange constants off `rf_parts` as it always did. None of
them changed.

EACH PART DRAWS FROM ITS OWN STREAM, SEEDED FROM ITS NAME (#825). `stream(name)` hands a part the
stream `rf_blender.stream` seeds from the machine's seed, which a build passes to `use`, and that
name; the part keeps it for the build. A bevel draws from the stream of the object it rounds, a
helper that jitters from the stream of the part it draws, and a build script from the stream of
the element it is shaping, named as that element is. So a part's imperfections depend on its name
alone: adding, removing or re-ordering any other part leaves them as they were. Nothing draws from
the global `random`, read from source; models/test_rf_blender.py holds only that no file here but
models/rf_blender.py imports it.

UNTIL #825 THEY CAME FROM ONE GLOBAL STREAM, in build order, and a part added early re-rolled
everything after it: on #824 a guard rail laid in lengths moved the drums and the handwheels, and a
handwheel rim landed on a bay's plates. What still moves a part's values is what moves its stream:
its name, the order of the draws made from that one stream, and the machine's seed. Renaming a part
re-rolls it, and so does a change to the order of the draws inside a helper's body, on every part
that helper draws -- which is verified by re-rendering both machines, never by reading the diff.

SO NO BUILD SCRIPT NAMES A PART THAT DRAWS BY ITS PLACE IN A LOOP (#827). A name numbered off a
loop is an order again: a part inserted early renumbers every part after it, and each draws from a
stream it did not draw from before. A part in a list written out by hand carries a name given by
hand, as the collector's ice does; one whose place is worked out is named for what it stands on, as
the exchanger's guard-rail lengths are for the post line each starts at, or for where it stands, as
a bottle is. A part added at the end of a row laid at a fixed pitch leaves the others' names, and
so their values, as they were, though not one whose pitch is a length shared out among its members;
a part named for where it stands is renamed, and so re-rolled, when it is nudged. And no build
script draws from one stream once per pass of a loop for one thing and then for another: the
exchanger's drums each place their gauges from a stream named for the drum, as `Drum<name>Gauges`,
and none from a stream shared between them. The helpers here still number a part's own pieces -- a panel set's plates, a casing's
segments, a fan stack's discs -- from `enumerate`: those are the part's grid, fixed by the call.

models/test_rf_blender.py holds that one name's stream is independent of the others, that no file
under models/ but models/rf_blender.py imports the global `random`, which that one uses only for
`random.Random`, and that neither rendered machine's build script gives a part that draws a name
formatted from a loop's counter. What a build script draws from one stream, and in what order, it
cannot see, nor a draw from anything else.

Detail floors are checked here rather than in the build scripts, on the reasoning
models/rf_blender.py's `check_detail` sets out: the read dimension, never the smallest.
"""
import json
import math
import sys

import bpy

import rf_blender as rf


# THE HEIGHT A PLAYER-FACING SOCKET IS DRAWN AT lives in models/rf_blender.py, beside the camera it
# is derived from, and is re-exported here because every build script reads it as `rf_parts.SOCKET_Z`
# and because a socket is a thing this module draws. It moved there in #354 so that
# tools/check-socket-height.py -- which cannot import this file, since this one imports bpy -- can
# hold the gate's reference against the number the models are actually built at. Nothing about the
# value changed in that move; rf_blender carries the derivation and the trade behind it.
SOCKET_Z = rf.SOCKET_Z


def MATERIAL(name, **flags):                      # replaced by use(); a clear error if it is not
    sys.exit("rf_parts: no material resolver installed -- call rf_parts.use(mat, geo, seed) before building.")


GEOMETRY = None                                   # replaced by use(); `pipe` refuses without it
SEED = None                                       # replaced by use(); `stream` refuses without it
_RUNS = []                                        # (object, points, radius) of each pipe, valve, tray
_STREAMS = {}                                     # name -> the stream `stream` handed out for it


def use(mat_fn, geo, seed):
    """Install the machine's material resolver, its geometry.json and its seed. Every helper calls
    the resolver as `mat_fn(name, **flags)`; `pipe` and `socket` hold their runs against the
    geometry's footprint edge (`rf_blender.check_edge`, #800); `stream` seeds every part's stream
    from `seed` and the part's name (#825). None of the three is optional, so a build that forgets
    the geometry cannot draw a pipe unchecked, and one that forgets the seed cannot draw at all.

    ONE MACHINE PER PROCESS. The resolver, the geometry, the seed, the streams and the runs `pipe`
    has drawn are module state, so a future batch builder that made two machines in one Blender
    session would paint the second with the first's palette unless it called this again between
    them. Calling it again forgets the runs, whose objects belong to the first machine, and the
    streams, which the second machine's seed would not have made. Every build today is its own
    `blender -b`, so nothing is at risk yet.
    """
    global MATERIAL, GEOMETRY, SEED
    MATERIAL = mat_fn
    GEOMETRY = geo
    SEED = seed
    _RUNS.clear()
    _STREAMS.clear()
    if _check_edges not in bpy.app.handlers.save_pre:
        bpy.app.handlers.save_pre.append(_check_edges)


def stream(name):
    """The random stream the part named `name` draws its imperfections from: the same one every
    time it is asked for in a build, so a part drawn in several steps -- a build script's jitter,
    then the bevel the helper puts on -- carries on along it. See this module's header (#825)."""
    if SEED is None:
        sys.exit("rf_parts: no seed installed -- call rf_parts.use(mat, geo, seed) before building.")
    if name not in _STREAMS:
        _STREAMS[name] = rf.stream(SEED, name)
    return _STREAMS[name]


def _check_edges(*_):
    """Hold every `pipe` run, every `valve`'s span and every `cable_tray`'s bed against the footprint
    edge, where it ENDED UP, before the model is saved. A save_pre handler, so no build script has
    to remember to call it.

    WHY AT SAVE AND NOT WHEN THE RUN IS DRAWN: rf-heat-exchanger is built long axis north-south and
    turned a quarter turn afterwards, so the points `pipe` is handed are in the body's own frame and
    not the declared one. Read then, its east-frame conduit leaves the north edge of a five-tile box
    it is nowhere near. Each run's points are taken through its object's `matrix_world` instead,
    which carries the turn. A socket is placed after the turn in the declared frame, so `socket`
    checks its own stub at once.

    IT FAILS CLOSED. Blender 5.2.0 printed a ReferenceError raised in a save_pre handler and saved
    anyway (measured reviewing #800: a run whose object had been removed raised it, and the
    out-of-edge run after it was written into the .blend); other exceptions are assumed to go the
    same way. So anything this raises -- a refusal or a fault -- is printed and leaves by
    `os._exit(1)`: the .blend is never written and the build fails, which is what
    tools/render-machine.py reads. `os._exit` skips the atexit hooks, so the detail-floor audit is
    reported here first rather than lost.

    SO A `pipe` OBJECT, A `valve`'S BODY OR A `cable_tray`'S FIRST RAIL CANNOT BE REMOVED, OR JOINED
    INTO ANOTHER OBJECT, before the save: its run is still held here, reading it raises
    ReferenceError, and the build stops. Converting one to a
    mesh in place keeps the object, and its run is still checked from the points it was drawn from
    (measured on 5.2.0 reviewing #800). Nothing does either today. A build that needs to remove or
    join one has to take the run out of `_RUNS` first, and a run skipped silently instead would be a
    run never checked.
    """
    import os
    import traceback
    from mathutils import Vector

    try:
        bpy.context.view_layer.update()
        for o, points, radius in _RUNS:
            world = [tuple(o.matrix_world @ Vector(p)) for p in points]
            rf.check_edge(o.name, world, radius, GEOMETRY)
    except SystemExit as refusal:
        print(refusal, file=sys.stderr)
    except Exception:
        print("rf_parts: the footprint-edge check failed, so nothing was saved:", file=sys.stderr)
        traceback.print_exc()
    else:
        return
    rf._report_audit()
    sys.stdout.flush()
    sys.stderr.flush()
    os._exit(1)


def bevel(obj, width=0.03, name=None):
    """Round every visible edge so the key light catches it (house style).

    THE WIDTH IS UNEVEN ON PURPOSE (Truls, #252). One bevel width across a whole machine is itself
    a kind of perfection: every corner catches the sun with the same highlight and the result reads
    as one extruded object. A spread of 0.75 to 1.6 of the nominal width is invisible as a number
    and enough that no two corners are the same.

    It draws from the stream of `name`, the name the object was GIVEN, which the helpers pass:
    Blender renames an object whose name is taken, and a suffix that depends on what was built
    first would make the draw depend on it too. Left out, it is the object's own name.
    """
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width * stream(name or obj.name).uniform(0.75, 1.6)
    mod.segments = 2


def texture(nt, model_dir, filename, tiles=2.0, gain=(1.0, 1.0, 1.0)):
    """A recorded CC0 image texture's colour in the node tree `nt`, as an output socket for a
    machine's `mat` to wire where it likes (ADR 0043, #805). `filename` is in `model_dir`, and
    `rf_blender.texture_record` refuses it there unless textures.json records it as CC0 with these
    bytes. One repeat of the image covers `tiles` tiles, and `gain` scales its linear colour per
    channel, so a palette can keep its colour and take only the grain.

    PROJECTED IN WORLD SPACE FROM ALL THREE AXES, each weighted by the square of the surface normal
    along it. A box here is a unit cube scaled, so its own coordinates would stretch one repeat over
    a fourteen-tile manifold, and its UVs would do the same; Blender's box projection reads the
    normal in the object's frame, which the exchanger's quarter turn takes away from the world's.
    World space keeps one grain size on every part and every face.

    THE PATH IS STORED RELATIVE, `//` and the file name, so the .blend has to be saved beside it:
    that is where every build script saves, and models/render.py refuses an image anywhere else.
    """
    import os
    rf.texture_record(model_dir, filename)
    # Found by its stored path, not by `load`'s check_existing: that matches the absolute path it is
    # handed, which the first call's image no longer carries, so a second call loaded it again.
    img = next((i for i in bpy.data.images if i.filepath == "//" + filename), None)
    if img is None:
        img = bpy.data.images.load(os.path.join(model_dir, filename))
        img.filepath = "//" + filename
    geom = nt.nodes.new("ShaderNodeNewGeometry")
    scaled = nt.nodes.new("ShaderNodeVectorMath")
    scaled.operation = "SCALE"
    scaled.inputs["Scale"].default_value = 1.0 / tiles
    nt.links.new(geom.outputs["Position"], scaled.inputs[0])
    xyz = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(scaled.outputs["Vector"], xyz.inputs[0])
    weight = nt.nodes.new("ShaderNodeVectorMath")
    weight.operation = "MULTIPLY"
    nt.links.new(geom.outputs["Normal"], weight.inputs[0])
    nt.links.new(geom.outputs["Normal"], weight.inputs[1])
    w = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(weight.outputs["Vector"], w.inputs[0])
    total = None
    # Each axis looks along itself, so it reads the other two coordinates.
    for axis, (a, b) in (("X", ("Y", "Z")), ("Y", ("X", "Z")), ("Z", ("X", "Y"))):
        uv = nt.nodes.new("ShaderNodeCombineXYZ")
        nt.links.new(xyz.outputs[a], uv.inputs["X"])
        nt.links.new(xyz.outputs[b], uv.inputs["Y"])
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        nt.links.new(uv.outputs["Vector"], tex.inputs["Vector"])
        part = nt.nodes.new("ShaderNodeVectorMath")
        part.operation = "SCALE"
        nt.links.new(tex.outputs["Color"], part.inputs[0])
        nt.links.new(w.outputs[axis], part.inputs["Scale"])
        if total is None:
            total = part.outputs["Vector"]
        else:
            add = nt.nodes.new("ShaderNodeVectorMath")
            add.operation = "ADD"
            nt.links.new(total, add.inputs[0])
            nt.links.new(part.outputs["Vector"], add.inputs[1])
            total = add.outputs["Vector"]
    # The squared components of a unit normal sum to one, so the three weights need no dividing.
    tint = nt.nodes.new("ShaderNodeVectorMath")
    tint.operation = "MULTIPLY"
    tint.inputs[1].default_value = gain
    nt.links.new(total, tint.inputs[0])
    return tint.outputs["Vector"]


def _plate(name, size, loc, material, rot=(0, 0, 0), bev=0.03, **mat_opts):
    """A box with NO detail-floor check, for a caller that has already made the check on its own
    behalf. `hbeam` is one: a beam is checked once on its flange width, and its web and two flanges
    then go in as the parts of a feature rather than as features. `box` is another, which makes its
    own check first, and the kit's `panels`, `fan_discs`, `valve`, `cable_tray`, `grating_deck` and
    `access_ladder` are the rest."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = size
    o.data.materials.append(MATERIAL(material, **mat_opts))
    if bev:
        bevel(o, bev, name)
    return o


def box(name, size, loc, material, rot=(0, 0, 0), bev=0.03, cut=False, read=None, **mat_opts):
    """A box. `read` is the dimension the detail floor judges it on, when that is not the smallest.

    THE DEFAULT IS THE SMALLEST DIMENSION, which is right for a groove and for a bar. Grooves are
    cut square (house style, #335), so a channel's smallest dimension IS the width that reads rather
    than the sink depth nobody sees; and a grating slat or a grille bar reads by its narrow edge.

    IT IS WRONG FOR A PANEL FACING THE CAMERA, and that is what `read` is for. A cabinet panel 0.42
    by 0.3 standing 0.06 proud of a wall reads by its FACE -- the 0.06 is how far it sticks out.
    Judged on the smallest, it is the H-beam web error in the other direction, and the house style's
    whole point is that the floor governs the dimension that carries the read.
    """
    rf.check_detail(name, min(size) if read is None else read, cut=cut)
    return _plate(name, size, loc, material, rot=rot, bev=bev, **mat_opts)


def cyl(name, radius, depth, loc, material, axis="Z", rot=None, verts=48, read=None, **mat_opts):
    """A cylinder. `read` is the dimension the detail floor judges it on, when that is not the
    smallest -- see `box`, and pass `2 * radius` for a DISC whose face is square to the camera.

    The default judges a cylinder on the smaller of its diameter and its depth, which is right for a
    rod (it reads by its width) and wrong for a disc (it reads by its face). A handwheel 0.28 across
    and 0.05 thick was judged on its 0.05 edge and thickened for it, on art that was already
    accepted -- which is what put `read` here (Truls, reviewing #339).
    """
    rot = rot or {"Z": (0, 0, 0), "X": (0, math.pi / 2, 0), "Y": (math.pi / 2, 0, 0)}[axis]
    rf.check_detail(name, min(2 * radius, depth) if read is None else read)
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=loc, rotation=rot, vertices=verts)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(MATERIAL(material, **mat_opts))
    bevel(o, 0.02, name)
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


def torus(name, major, minor, loc, material, rot=(0, 0, 0), **mat_opts):
    rf.check_detail(name, 2 * minor)                   # a ring reads by its thickness, not its radius
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=loc, rotation=rot,
                                     major_segments=48, minor_segments=12)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(MATERIAL(material, **mat_opts))
    return o


# WHERE A SOCKET'S PIECES SIT ON ITS TUBE, re-exported from models/rf_blender.py the way SOCKET_Z
# above is and for the same reason: that module imports no bpy, so tools/measure-socket-parts.py
# can work out which columns of a sheet each piece occupies from the numbers the models are
# actually built from (#365). Every build script still reads them as `rf_parts.<NAME>` and none of
# them changed when they moved. The derivation and the trade behind each one live there; what is
# here is only the re-export, and `port` and `socket` below are what place them.
RIM_BACK = rf.RIM_BACK
RIM_MINOR = rf.RIM_MINOR
RIM_PROUD = rf.RIM_PROUD
BAND_BACK = rf.BAND_BACK
BAND_DEPTH = rf.BAND_DEPTH
BAND_PROUD = rf.BAND_PROUD
PORT_CLEARANCE = rf.PORT_CLEARANCE
FLANGE_GAP = rf.FLANGE_GAP
FLANGE_MIN_THICK = rf.FLANGE_MIN_THICK
FLANGE_PROUD = rf.FLANGE_PROUD


def port(body, axis, across, edge, sign, radius, z=SOCKET_Z, depth=0.7, rim=True):
    """Cut the hole a socket passes through, in `body`, and -- with `rim` -- ring its mouth.

    `axis` is the socket's own axis, "X" or "Y"; `across` is its position on the other ground axis;
    `edge` is the footprint edge it stops at and `sign` which way that lies (+1 east or north).

    `rim` IS THE HALF THAT IS NOT ALWAYS DRAWN (ADR 0036, #392). Every socket passes through the
    slab now, contained ones included, so every socket needs the hole; but the rim is one of the two
    pieces of vanilla hardware whose ABSENCE is what says a socket cannot be plumbed, so a contained
    one takes the opening and leaves the ring. `socket` passes its own `plumbable` straight through.

    The two used to be one call and could not be had separately, which is what made a contained
    socket at pipe height impossible to draw without either clipping the stone or wearing the rim.

    IT IS A BET THAT AN UNRIMMED OPENING STILL READS AS A FITTING. models/house-style.md says the
    rim is what makes the opening read as a fitting rather than a bite out of the stone, and this is
    the one place that paragraph is knowingly not honoured. If the frames show a bite, the fix is a
    rim in the tube's own metal rather than in `dark` (Truls, 2026-09-17: "Reopen if it looks bad").

    `z` IS THE SOCKET'S HEIGHT AND IS PASSED, not read from the constant. It defaults to SOCKET_Z
    because that is where every socket is drawn since ADR 0036 -- but `socket` hands its own `z`
    over rather than relying on that, since the alternative is a machine that draws at some other
    height getting a hole floating at 0.033 with nothing complaining.

    The cutter is a modifier rather than an applied boolean, the way `bevel` is: Blender evaluates
    BEVEL then BOOLEAN in the order they were added, so the hole is cut into the already-rounded
    body and neither has to be baked. Nothing here is destructive, so a re-render from the same
    script gives the same object.

    `radius` is the socket's own plus clearance -- both machines add 0.06 -- because a hole exactly
    the size of the tube leaves a z-fighting shell where the two surfaces touch, and a hole a little
    proud reads as a hole. It is passed rather than derived from SOCKET_Z's sibling constant,
    because a machine may cut a port for a socket of any width: models/house-style.md binds a
    PLUMBABLE socket to the pipe's 0.249, and says nothing about the rest.

    It draws nothing: the cutter is a raw primitive and `torus` puts on no bevel.
    """
    cutter_loc = [0.0, 0.0, z]
    cutter_loc[0 if axis == "X" else 1] = edge - sign * (depth / 2 - 0.12)
    cutter_loc[1 if axis == "X" else 0] = across
    bpy.ops.mesh.primitive_cylinder_add(
        radius=radius, depth=depth, vertices=32, location=cutter_loc,
        rotation=(0, math.pi / 2, 0) if axis == "X" else (math.pi / 2, 0, 0))
    cutter = bpy.context.object
    cutter.name = f"PortCut-{axis}-{across:g}"
    cutter.display_type = "WIRE"
    cutter.hide_render = True
    m = body.modifiers.new(cutter.name, "BOOLEAN")
    m.object = cutter
    m.operation = "DIFFERENCE"
    m.solver = "EXACT"
    # The rim: a ring at the stub's OUTER MOUTH, on the footprint edge the socket stops at rather
    # than on the body face the hole is cut in -- which on both machines are a quarter tile apart,
    # because the selection box stands that far outside the collision box. So it reads as the flange
    # a pipe bolts to, and it is the thing that says the stub ends deliberately rather than being cut
    # off by the frame. Put on the body face instead it would ring the hole -- #350 drew exactly that
    # as `rimmed-inboard` and #351 REJECTED it, because moving the rim inboard pushes the accent band
    # onto the body face where the slab edge clips it to a sliver. So it stays where the collector
    # put it, and that is now a decision rather than an unasked question.
    # A RING, never a "collar": on a socket #351 gave that word to the accent band. (A FLOOR
    # collar, where a pipe turns down through the deck, is a different object and keeps its name.)
    if not rim:
        return
    rim_loc = [0.0, 0.0, z]
    rim_loc[0 if axis == "X" else 1] = edge - sign * RIM_BACK
    rim_loc[1 if axis == "X" else 0] = across
    torus(f"PortRim-{axis}-{across:g}", radius + RIM_PROUD, RIM_MINOR, tuple(rim_loc), "dark",
          rot=(0, math.pi / 2, 0) if axis == "X" else (math.pi / 2, 0, 0))


def socket(body, connection, geo, z, radius, plumbable=True, **mat_opts):
    """Draw one connection's socket: the bare-metal stub, its accent band, the opening it passes
    through `body`, and -- on a socket a player can plumb -- the dark rim on that opening's mouth
    and the flange pair just inboard of it.

    `connection` is one entry of the machine's geometry.json and `geo` the file it came from. The
    stub runs from half a tile inside the COLLISION edge out to the SELECTION edge, which is where
    both rendered machines put theirs; on both, those are a quarter tile apart, so the mouth stands
    clear of the body and the rim `port` puts on it reads as the flange a pipe bolts to.

    WHAT IS THE CALLER'S BUSINESS AND MUST STAY THERE: `plumbable`. SINCE ADR 0036 IT NO LONGER
    DECIDES `z` OR `radius` -- every socket on every machine is drawn at SOCKET_Z and 0.249, both
    measured against vanilla's pipe (models/house-style.md), whatever a connection's
    `connection_category` says. What `plumbable` decides now is the two pieces of vanilla hardware
    a contained socket does NOT wear: the dark rim on the opening's mouth, and the flange pair. That
    absence is the cue, decided in ADR 0036 rather than inherited from ADR 0018's exemption.

    It is still read off `connection_category` and never off a list of fluids or machines, so a
    face added tomorrow is contained without this being touched. rf-heat-exchanger carries both
    kinds; rf-isotope-collector has none.

    `z` and `radius` stay PARAMETERS rather than becoming constants here, because a machine may
    still draw a socket of some other size for a reason nobody has had yet, and the gates measure
    what was drawn rather than what was meant.

    `mat_opts` reach the STUB AND ITS RIBS -- the collector frosts its tube and the flange is in
    the tube's own material -- and nothing else. An accent band must stay the colour of the fluid it
    names, and a rim is always `dark`.

    Each piece's bevel draws from that piece's own stream, named for its connection's direction
    and fluid, so the pieces can be drawn in any order and a socket added or removed moves no
    other part's imperfections. See this module's header (#825).
    """
    d = connection["direction"]
    fluid = connection["fluid"]
    axis = "X" if d in ("west", "east") else "Y"
    sign = 1 if d in ("east", "north") else -1      # +1 east or north, `port`'s own convention
    i = 0 if axis == "X" else 1                     # the socket's own ground axis
    (cx0, cy0), (cx1, cy1) = geo["collision_box"]
    (sx0, sy0), (sx1, sy1) = geo["selection_box"]
    # Factorio's +y is south and Blender's is north, so a position flips and the Y edges swap.
    px, py = connection["position"]
    across = -py if axis == "X" else px
    edge = (sx1 if sign > 0 else sx0) if axis == "X" else (-sy0 if sign > 0 else -sy1)
    half = (cx1 - cx0) / 2 if axis == "X" else (cy1 - cy0) / 2
    inner = (half - 0.5) * sign                     # half a tile inside the body wall

    def at(along):
        loc = [0.0, 0.0, z]
        loc[i], loc[1 - i] = along, across
        return tuple(loc)

    # A socket is the one thing allowed to meet the edge, and is held to the same check as a run,
    # so a connection the geometry does not declare cannot be drawn either.
    rf.check_edge(f"Socket-{d}-{fluid}", [at(inner), at(edge)], radius, geo)
    cyl(f"Socket-{d}-{fluid}", radius, abs(edge - inner), at((edge + inner) / 2), "metal",
        axis=axis, **mat_opts)
    cyl(f"Band-{d}-{fluid}", radius + BAND_PROUD, BAND_DEPTH, at(edge - BAND_BACK * sign),
        rf.accent(fluid), axis=axis)
    # THE OPENING IS CUT FOR EVERY SOCKET AND THE RIM IS NOT (ADR 0036). At 0.033 with radius 0.249
    # a contained socket's underside reaches -0.216, well below the slab top at 0.25, so it needs
    # the same modelled opening a plumbable one has had since #349. The rim does not come with it:
    # that ring and the flange pair below are the whole of what tells the two apart.
    port(body, axis, across, edge, sign, radius + PORT_CLEARANCE, z=z, rim=plumbable)
    if plumbable:
        # THE FLANGE PAIR, on a plumbable socket and no other. A contained connection meets a
        # machine face rather than a pipe, so a shape chosen to sit against vanilla's `pipe_cover`
        # has nothing to sit against on one -- the same exemption #343 made for the height.
        #
        # The clear tube is what the rim and the band leave: the rim owes RIM_BACK + RIM_MINOR from
        # the mouth and the band starts BAND_BACK - BAND_DEPTH / 2 in. Both are read off the
        # constants above rather than typed here, so a rib cannot drift out of the gap it was
        # fitted to.
        near = RIM_BACK + RIM_MINOR
        far = BAND_BACK - BAND_DEPTH / 2
        thick = (far - near) * (1 - FLANGE_GAP) / 2
        if thick < FLANGE_MIN_THICK:
            sys.exit(f"rf_parts: a socket leaves {far - near:.3f} tiles of bare tube between its "
                     f"rim and its accent band, which is not enough for a flange pair "
                     f"({2 * FLANGE_MIN_THICK:.2f} tiles of rib plus a gap). Nothing was drawn. "
                     f"This is the rim and band constants above disagreeing with the flange ones, "
                     f"not {d} {fluid} being unusual -- every socket here has the same span.")
        for k, back in enumerate((near + thick / 2, far - thick / 2)):
            # A DISC READS BY ITS FACE, not by its thickness, so `read=` is handed the face --
            # without it a rib this thin dies on the raised-detail floor.
            cyl(f"Flange-Socket-{d}-{fluid}-{k}", radius + FLANGE_PROUD, thick,
                at(edge - back * sign), "metal", axis=axis,
                read=2 * (radius + FLANGE_PROUD), **mat_opts)

    # WHAT WAS JUST DRAWN, STAMPED ON THE SCENE for models/render.py to put in the manifest (#373).
    #
    # THE MODEL IS THE ONLY PLACE THAT KNOWS. A manifest's `geometry` block is the PROTOTYPE's,
    # copied by tools/extract-geometry.py, and a Factorio prototype records no radius and no height
    # -- so until this nothing anywhere recorded what a socket was DRAWN at, and
    # tools/check-socket-parts.py could not have been written. Typing the numbers into that gate
    # instead is the failure models/rf_blender.py already names over its socket-piece constants --
    # "makes the instrument and the model one statement; typing them into the tool would make them
    # two".
    #
    # A JSON STRING rather than a list of dicts, because a Blender custom property holds primitives
    # and this has to survive being saved into the .blend and read back by another script. Keyed by
    # POSITION, the one field unique to a connection: a machine can carry two on the same side and
    # rf-heat-exchanger does.
    drawn = json.loads(bpy.context.scene.get("rf_sockets", "[]"))
    drawn.append({"position": list(connection["position"]), "direction": d, "fluid": fluid,
                  "radius": radius, "z": z, "plumbable": plumbable})
    bpy.context.scene["rf_sockets"] = json.dumps(drawn, sort_keys=True)


def _centreline(curve_obj):
    """The evaluated centreline of a curve object, in world space, in order along the curve.

    The bevel is what turns a curve into a tube, so it is switched off for the evaluation and put
    back: with a bevel the mesh is the tube's skin, and its vertices are no use for finding where
    the tube's axis runs.
    """
    depth = curve_obj.data.bevel_depth
    curve_obj.data.bevel_depth = 0.0
    bpy.context.view_layer.update()
    evaluated = curve_obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    points = [tuple(curve_obj.matrix_world @ v.co) for v in mesh.vertices]
    evaluated.to_mesh_clear()
    curve_obj.data.bevel_depth = depth
    if len(points) < 2:
        raise RuntimeError(f"{curve_obj.name}: evaluated centreline has {len(points)} point(s)")
    return points


def pipe(name, points, radius, material, corrugate=0.0, band=(1.15, 0.22), ring_phase=0.5, **mat_opts):
    """A pipe along a Bezier curve through `points` (slightly wobbly by construction), with
    optional corrugation rings every `corrugate` tiles.

    `band` scales a ring against the pipe's radius: (major, minor). The default band is the subtle
    ring every pipe here has always had; the steam header passes a heavier one, because on that
    pipe the corrugation is the thing being drawn rather than a detail on it. `ring_phase` is where
    the first ring falls, as a fraction of the pitch: half a pitch in, unless a caller varies it.

    A RING HAS A HIGHER FLOOR THAN ITS PIPE. At the default band a ring's minor diameter is 0.44 of
    the pipe's radius, so a pipe that clears the raised-detail floor on its own at radius 0.03 dies
    at `<name>-ring0` until radius 0.136. The shipped header clears it at 0.19 with its own heavier
    band. It fails loudly and by name, so this is a thing to know before adding `corrugate=` to a
    thin pipe rather than a thing to work around.
    """
    rf.check_detail(name, 2 * radius)
    if GEOMETRY is None:
        sys.exit("rf_parts: no geometry installed -- call rf_parts.use(mat, geo, seed) before building.")
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
    _RUNS.append((o, [tuple(p) for p in points], radius))  # held to the edge at save, `_check_edges`
    # bpy.context.scene, not a module-global `scene`: this used to live inside a build script
    # where that name was in scope, and lifting it out was the one thing that did not survive
    # the move. Same object either way -- each build script sets `scene = bpy.context.scene`.
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(MATERIAL(material, **mat_opts))
    if corrugate:
        # RINGS ON THE TUBE, NOT ON THE CONTROL POLYLINE, and that is the fix rather than a
        # refinement (Truls, #275). They used to be spaced along the straight lines BETWEEN the
        # control points, while the tube itself is a Bezier that bows away from those lines. On a
        # nearly straight pipe the error is a pixel and nobody saw it; on the steam header, once it
        # was given a real bend, the rings left the tube and the whole thing read as a spring lying
        # beside a thin wire instead of a corrugated hose.
        #
        # So the centreline is asked for rather than assumed: the curve is evaluated with its bevel
        # switched off, which yields the tessellated centreline, and the rings are walked along that
        # by arc length. Deterministic, and it costs one evaluation per corrugated pipe.
        spine = _centreline(o)
        travelled, next_ring, k = 0.0, corrugate * ring_phase, 0
        for a, b in zip(spine, spine[1:]):
            seg = math.dist(a, b)
            if seg < 1e-9:
                continue
            while next_ring <= travelled + seg:
                t = (next_ring - travelled) / seg
                c = tuple(a[j] + (b[j] - a[j]) * t for j in range(3))
                d = tuple(b[j] - a[j] for j in range(3))
                yaw = math.atan2(d[1], d[0])
                pitch = math.atan2(d[2], math.hypot(d[0], d[1]))
                torus(f"{name}-ring{k}", radius * band[0], radius * band[1], c, material,
                      rot=(0, math.pi / 2 - pitch, yaw), **mat_opts)
                k += 1
                next_ring += corrugate
            travelled += seg
        print(f"CORRUGATE {name}: {k} rings over {travelled:.2f} tiles of tube")
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
    # THE READ IS THE FLANGE WIDTH. A beam's web is a third the thickness of anything else here
    # and stands edge-on to this camera: what a post shows is the face of its flange. Judged on the
    # web, the floor would condemn the frame the house style is built around -- so the beam is
    # checked once, here, and its three boxes go in unchecked.
    rf.check_detail(name, flange)
    s = stream(name)
    loc = (s.jitter(loc[0], 0.02), s.jitter(loc[1], 0.02), s.jitter(loc[2], 0.012))
    rot = (s.jitter(0, 0.012), s.jitter(0, 0.012), s.jitter(0, 0.012))
    if axis == "Z":
        _plate(f"{name}-web", (web, depth - 0.05, length), loc, material, bev=0, rot=rot)
        for sx in (-1, 1):
            _plate(f"{name}-f{sx}", (flange, web, length), (loc[0] + sx * 0, loc[1] + sx * (depth / 2), loc[2]), material, bev=0.01, rot=rot)
    elif axis == "Y":
        _plate(f"{name}-web", (web, length, depth - 0.05), loc, material, bev=0, rot=rot)
        for sz in (-1, 1):
            _plate(f"{name}-f{sz}", (flange, length, web), (loc[0], loc[1], loc[2] + sz * (depth / 2)), material, bev=0.01, rot=rot)
    else:
        _plate(f"{name}-web", (length, web, depth - 0.05), loc, material, bev=0, rot=rot)
        for sz in (-1, 1):
            _plate(f"{name}-f{sz}", (length, flange, web), (loc[0], loc[1], loc[2] + sz * (depth / 2)), material, bev=0.01, rot=rot)


def rivets(name, start, end, n, r=0.045, material="dark"):
    rf.check_detail(name, 2 * r)                       # a rivet reads by its diameter
    for i in range(n):
        t = (i + 0.5) / n
        loc = tuple(start[j] + (end[j] - start[j]) * t for j in range(3))
        bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=12, ring_count=8)
        o = bpy.context.object
        o.name = f"{name}-{i}"
        o.data.materials.append(MATERIAL(material))


def seam(name, size, loc, rot=(0, 0, 0)):
    """A dark groove: a thin frame-coloured box sunk into a panel face.

    The one CUT-detail helper on the machine, so the one that takes the lower floor. Every other
    helper builds something that stands proud and reads by its own silhouette.
    """
    box(name, size, loc, "frame", rot=rot, bev=0, cut=True)


# ==== THE KIT ==================================================================================
#
# KIT PARTS (GLOSSARY.md): plant machinery defined once here and placed by any machine's model, so
# the set grows denser as the kit grows rather than one machine at a time (#798). They are not
# sockets and declare nothing.
#
# THE SHAPE EVERY KIT PART FOLLOWS, set by the first two (#803):
#
# - A part is one function here, named for what it is, and a build script places it with one call.
#   The call says WHERE -- a curve, a face, a centre -- and the part decides its pieces. Where the
#   pieces go is arithmetic in models/rf_blender.py, which imports no bpy, so
#   models/test_rf_blender.py pins it without Blender.
# - Its first argument is a name, and every piece it draws is named from it, so a refusal names
#   the part.
# - It is held to the detail floor on the dimension that carries ITS read, checked here by name,
#   whatever the pieces' own checks say.
# - Anything pipe-shaped in it is drawn by `pipe`, so the footprint-edge check holds it at save
#   with no extra call, or is handed to the same check at save by appending its span to `_RUNS`, as
#   `valve` and `cable_tray` do.
# - It takes its material by role name and never by colour. A colour a part brings with it -- a
#   loom's sheaths -- is a row in models/rf_blender.py that the machine's palette takes in whole.
# - Whatever it draws comes from `stream(name)` and the streams of its pieces' names, never from
#   anywhere shared, so placing it moves nothing else's imperfections (#825).


def _facing(d):
    """The rotation that turns a primitive built along Z to lie along direction `d`; `pipe`'s rings
    use the same two angles."""
    yaw = math.atan2(d[1], d[0])
    pitch = math.atan2(d[2], math.hypot(d[0], d[1]))
    return (0, math.pi / 2 - pitch, yaw)


def _wobbled(points, wobble, s):
    """`points` with every inner point moved up to `wobble` tiles on each axis, drawn from stream
    `s`; the ends stay put, since an end is where a run meets the thing it serves."""
    if not wobble:
        return list(points)
    return [points[0]] + [tuple(s.jitter(c, wobble) for c in p) for p in points[1:-1]] + [points[-1]]


def hose(name, points, radius, material="metal", pitch=None, band=(1.24, 0.26), wobble=0.0, **mat_opts):
    """A corrugated hose along a curve through `points`: a tube with a ring every `pitch` tiles.

    THE PITCH CARRIES THE READ, and is checked on the floor here: the gap between rings, with bare
    tube showing in it, is what tells a hose from a smooth pipe and from a spring. The default,
    1.37 radii, is the steam header's 0.26 on 0.19 (#275). A ring's centre circle is `band[0]`
    radii out and its tube's own radius is `band[1]` radii, so it stands `band[0] + band[1] - 1`
    of the radius proud: half the radius at the default. `pipe` holds each ring to the floor on its own
    minor diameter.

    NO TWO HOSES HAVE THEIR RINGS IN THE SAME PLACES (Truls, 2026-10-29: three vent hoses with the
    same bend and their rings in the same places did not look natural). Each starts its rings at a
    random point in the pitch. The bend is the caller's: two hoses on the same points keep the same
    bend unless `wobble` moves their inner control points, by up to that many tiles, so a model
    that places one hose shape several times passes a wobble to get several hoses. The ends never
    move.
    """
    pitch = 1.37 * radius if pitch is None else pitch
    rf.check_detail(f"{name} (corrugation pitch)", pitch)
    s = stream(name)
    return pipe(name, _wobbled(points, wobble, s), radius, material, corrugate=pitch, band=band,
                ring_phase=s.random(), **mat_opts)


def loom(name, points, cables=("cable-red", "cable-green", "cable-red"), cable_r=0.035, twist=0.6,
         ties=True, wobble=0.0):
    """A cable loom: `len(cables)` thin cables bundled round a curve through `points`, each in its
    own sheath colour, with a dark tie round the bundle at every inner control point.

    THE CABLE DIAMETER CARRIES THE READ: a loom reads as several lines lying together, so each
    cable has to be a line at 32 px a tile. The default, 0.07, clears the raised-detail floor of
    0.06. The bundle's own width is no help to a cable under the floor, which is why it is not
    what is checked.

    THE CABLES WIND (`twist`, radians per control point) rather than lying parallel, which is what
    a loom laid by hand does. The colours are `rf_blender.CABLE_COLOURS`' rows, which name no fluid.

    NO TWO LOOMS WIND ALIKE, for the reason `hose` gives: each starts its winding at a random turn.
    The bend is the caller's, as a hose's is, and `wobble` moves its inner control points.
    """
    rf.check_detail(f"{name} (cable diameter)", 2 * cable_r)
    spread = rf.loom_spread(len(cables), cable_r)
    s = stream(name)
    points = _wobbled(points, wobble, s)
    strands = rf.bundle(points, len(cables), spread, twist, phase=s.uniform(0, 2 * math.pi))
    for k, (strand, material) in enumerate(zip(strands, cables)):
        pipe(f"{name}-{k}", strand, cable_r, material)
    if not ties:
        return
    _ties(name, points, spread + cable_r)


# A face's two in-plane axes, by the axis its normal lies along: (u, v). u is horizontal on a wall.
_FACE_AXES = {"X": (1, 2), "Y": (0, 2), "Z": (0, 1)}


def panels(name, centre, size, normal, grid, material="body", seam=0.05, depth=0.06, yaw=0.0,
           **mat_opts):
    """Inset panels: a flat face broken into `grid` = (nu, nv) plates with a seam round each.

    `centre` is the middle of the face and `normal` the way it faces: "+X", "-X", "+Y", "-Y" or
    "+Z". `size` is the face's (u, v): along X or Y and then up for a wall, X then Y for a top.
    `yaw` turns the plates about the face's centre with a face that is itself turned, such as
    rf-heat-exchanger's manifold.

    THE PLATES STAND `depth` PROUD OF THE FACE, so the face shows between them as the floor of a
    seam `depth` deep. That is a recessed seam drawn without a boolean, and it is why `depth` must
    be at least `seam`: a groove is cut at least as deep as it is wide (house style), or its shadow
    line is too weak to read. `rf_blender.check_inset` holds the seam to the cut floor on its width
    and a plate to the raised floor on its smaller side. Each plate's depth varies a little, so a
    raking light catches one edge and not the next, and the face reads as plates fitted by hand.
    """
    axis, sign = normal[1], (1 if normal[0] == "+" else -1)
    n = "XYZ".index(axis)
    iu, iv = _FACE_AXES[axis]
    cells = rf.panel_grid(size[0], size[1], grid[0], grid[1], seam)
    rf.check_inset(name, seam, depth, min(min(c[2], c[3]) for c in cells))
    c, s = math.cos(yaw), math.sin(yaw)
    draw = stream(name)
    out = []
    for k, (cu, cv, su, sv) in enumerate(cells):
        d = max(seam, draw.jitter(depth, 0.01))
        off = [0.0, 0.0, 0.0]
        off[iu], off[iv], off[n] = cu, cv, sign * d / 2
        dims = [0.0, 0.0, 0.0]
        dims[iu], dims[iv], dims[n] = su, sv, d
        loc = (centre[0] + off[0] * c - off[1] * s, centre[1] + off[0] * s + off[1] * c, centre[2] + off[2])
        # Unchecked here: check_inset has judged the plate on its face, which is its read, and the
        # box's smallest side is its depth.
        out.append(_plate(f"{name}-{k}", tuple(dims), loc, material, rot=(0, 0, yaw), bev=0.012, **mat_opts))
    return out


# ---- repeated modules (#804) --------------------------------------------------------------------
#
# ONE SHAPE PLACED MANY TIMES. Each takes `placements`, a list of (location, rotation) from
# `rf_blender.ring`, `row` or `stack`, and builds its shape about its own origin along its own Z
# before turning and moving it there. So any of them goes round a ring, along a row or up a stack.


def _place(objs, placement):
    """Turn and move objects built about the origin to a placement."""
    from mathutils import Euler, Matrix
    loc, rot = placement
    m = Matrix.Translation(loc) @ Euler(rot).to_matrix().to_4x4()
    bpy.context.view_layer.update()
    for o in objs:
        o.matrix_world = m @ o.matrix_world


def _circle(r, z, n):
    return [(r * math.cos(2 * math.pi * k / n), r * math.sin(2 * math.pi * k / n), z) for k in range(n)]


def bolts(name, placements, r=0.035, head=0.05, material="dark"):
    """A hex bolt head at each placement, standing `head` tall along its own Z.

    A BOLT READS BY ITS HEAD'S DIAMETER, which is checked, and neighbouring bolts must stand apart
    by the cut floor or they read as one lump. It carries no bevel and draws nothing."""
    rf.check_detail(f"{name} (head)", 2 * r)
    gap = rf.least_gap(_circle(r, 0, 6) + _circle(r, head, 6), placements)
    if gap is not None:
        rf.check_detail(f"{name} (gap)", gap, cut=True)
    out = []
    for k, p in enumerate(placements):
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=head, vertices=6, location=(0, 0, head / 2))
        o = bpy.context.object
        o.name = f"{name}-{k}"
        o.data.materials.append(MATERIAL(material))
        _place([o], p)
        out.append(o)
    return out


def fan_discs(name, placements, radius, thick=0.07, blades=6, material="metal"):
    """A fan or turbine disc at each placement: a hub, a rim and `blades` pitched blades, square to
    its own Z. Up a stack they read as a turbine; along a row, as a bank of fans.

    THE DISC'S THICKNESS CARRIES THE READ, and is checked. Neighbouring discs must stand apart by
    the cut floor, measured from the discs as placed by `rf_blender.least_gap`: along the axis in a
    stack, where the hub, 1.6 discs thick, meets first, and across the rims in a row or a ring. A
    blade reads by its width, which is fixed at 0.07."""
    rf.check_detail(f"{name} (disc)", thick)
    outline = (_circle(radius, -thick / 2, 24) + _circle(radius, thick / 2, 24)
               + _circle(radius * 0.28, -thick * 0.8, 12) + _circle(radius * 0.28, thick * 0.8, 12))
    gap = rf.least_gap(outline, placements)
    if gap is not None:
        rf.check_detail(f"{name} (gap)", gap, cut=True)
    for k, p in enumerate(placements):
        pieces = [cyl(f"{name}-{k}-hub", radius * 0.28, thick * 1.6, (0, 0, 0), "dark"),
                  torus(f"{name}-{k}-rim", radius - thick / 2, thick / 2, (0, 0, 0), material)]
        for b in range(blades):
            a = 2 * math.pi * b / blades
            pieces.append(_plate(f"{name}-{k}-blade{b}", (radius * 0.72, 0.07, thick * 0.5),
                                 (radius * 0.6 * math.cos(a), radius * 0.6 * math.sin(a), 0), material,
                                 rot=(0.5, 0, a), bev=0.008))
        _place(pieces, p)


def casing(name, placements, radius, arc, height, thick=0.07, material="dark"):
    """One curved segment of a casing at each placement, `arc` radians of a shell `thick` deep
    standing on a circle of `radius`. Placed round `rf_blender.ring` with the same radius and an
    arc from `rf_blender.casing_arc`, the segments close round a drum with a slot between each; up
    a stack they are bands one over another, and along a row a line of curved plates.

    The segment is built with its circle's centre `radius` behind its own origin, so a ring's
    outward-facing placement wraps it round the ring's centre. Its height or its arc, whichever is
    less, carries the read. The gap between neighbours, measured from the segments as placed, is
    held like a slot cut through the shell: on the cut floor and at least as deep, `thick`, as it
    is wide."""
    import bmesh
    rf.check_detail(f"{name} (segment)", min(height, arc * radius))
    steps = 8
    verts = rf.casing_points(radius, arc, height, thick, steps)
    gap = rf.least_gap(verts, placements)
    if gap is not None:
        rf.check_gap(name, gap, thick)
    for k, p in enumerate(placements):
        bm = bmesh.new()
        made = [bm.verts.new(v) for v in verts]
        rings = [made[4 * s:4 * s + 4] for s in range(steps + 1)]
        for a, b in zip(rings, rings[1:]):
            for i in range(4):
                bm.faces.new((a[i], a[(i + 1) % 4], b[(i + 1) % 4], b[i]))
        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        mesh = bpy.data.meshes.new(f"{name}-{k}")
        bm.to_mesh(mesh)
        bm.free()
        o = bpy.data.objects.new(f"{name}-{k}", mesh)
        bpy.context.scene.collection.objects.link(o)
        o.data.materials.append(MATERIAL(material))
        bevel(o, 0.015, f"{name}-{k}")
        _place([o], p)


def lifting_lugs(name, placements, size=0.2, material="hazard"):
    """A lifting lug at each placement: a plate `size` wide standing on the placement, its face
    square to its own X, with an eye through it below a half-disc top (`rf_blender.lug_layout`).
    Round a ring each faces out from the centre, so the lug the camera faces shows its eye.

    THE READ IS THE EYE'S DIAMETER, on the cut floor, and THE PLATE'S THICKNESS, on the raised floor,
    both checked in `rf_blender.lug_layout`, which also holds neighbours apart by the cut floor. At
    the part's proportions the plate binds first, so `size` is 0.2 at the least, and the default.

    A LIFTING POINT IS A MARKING, so lugs are hazard yellow unless `material` names another role
    (`models/house-style.md`, Palette). Nothing in a lug is pipe-shaped."""
    import bmesh
    d = rf.lug_layout(name, size, placements)
    half = d["thick"] / 2
    n = len(d["inner"])
    for k, p in enumerate(placements):
        bm = bmesh.new()
        rings = [[bm.verts.new((x, u, z)) for u, z in ring] for ring in (d["inner"], d["outer"])
                 for x in (-half, half)]
        back_in, front_in, back_out, front_out = rings
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((front_in[i], front_out[i], front_out[j], front_in[j]))
            bm.faces.new((back_in[j], back_out[j], back_out[i], back_in[i]))
            bm.faces.new((back_out[i], back_out[j], front_out[j], front_out[i]))
            bm.faces.new((back_in[i], front_in[i], front_in[j], back_in[j]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        mesh = bpy.data.meshes.new(f"{name}-{k}")
        bm.to_mesh(mesh)
        bm.free()
        o = bpy.data.objects.new(f"{name}-{k}", mesh)
        bpy.context.scene.collection.objects.link(o)
        o.data.materials.append(MATERIAL(material))
        bevel(o, 0.006, f"{name}-{k}")
        _place([o], p)
    return d


# ---- parts that sit on a run (#833) --------------------------------------------------------------

def valve(name, at, direction, radius, facing, material="metal", wheel="dark", spokes=4):
    """An inline gate valve on a run: a body wider than the run between two flanges, a bonnet and a
    stem out along `facing`, and a handwheel on the stem, square to it.

    `at` is a point on the run and `direction` the run's direction there; `radius` is the run's,
    and every piece is sized from it (`rf_blender.valve_layout`). The run is not cut: the body and
    the flanges cover it. `facing` is made square to the run, so passing the way the camera looks
    turns the wheel towards it.

    THE HANDWHEEL'S RIM CARRIES THE READ, by its minor diameter on the raised floor, checked in
    `rf_blender.valve_layout`. On a thin run the rim and the stem are drawn at the floor rather
    than in proportion, the rim under `rf_blender.VALVE_THIN_RUN` and the stem under 0.15, so the
    water header's 0.13 takes one.

    The wheel is `wheel`, dark or metal, and never an accent or a marking. It is a part
    that could move later (`models/house-style.md`, Moving parts), so it stands clear on its stem
    where an animation could turn it.

    ITS BODY AND FLANGES ARE HELD TO THE FOOTPRINT EDGE as a run is, on the flanges' radius: the
    run under them is checked on its own, narrower one, and a valve placed near an edge could
    stand past it where the run does not. The span between the flanges goes into `_RUNS` on the
    body's object, so it is read at save through the turn, as every `pipe` is.

    Returns the layout, whose `reach` and `span` say how much room the valve takes."""
    v = rf.valve_layout(name, at, direction, radius, facing)
    b = v["body"]
    body = cyl(f"{name}-body", b["radius"], b["length"], b["centre"], material, rot=_facing(b["axis"]))
    half = (b["length"] + v["flanges"][0]["thickness"]) / 2     # the flanges' centres, on its own Z
    _RUNS.append((body, [(0.0, 0.0, -half), (0.0, 0.0, half)], v["flanges"][0]["radius"]))
    for k, fl in enumerate(v["flanges"]):
        cyl(f"{name}-flange{k}", fl["radius"], fl["thickness"], fl["centre"], material,
            rot=_facing(fl["axis"]), read=2 * fl["radius"])
    for piece in ("bonnet", "stem"):
        p = v[piece]
        cyl(f"{name}-{piece}", p["radius"], p["length"], p["centre"], material, rot=_facing(p["axis"]),
            verts=24)
    w = v["wheel"]
    rot = _facing(w["normal"])
    torus(f"{name}-wheel", w["major"], w["minor"], w["centre"], wheel, rot=rot)
    h = v["hub"]
    pieces = [cyl(f"{name}-hub", h["radius"], h["length"], (0, 0, 0), wheel, verts=16,
                  read=2 * h["radius"])]
    # Unchecked here: a spoke is the rim's minor diameter wide, and the rim has just been held to
    # the raised floor on that.
    for s in range(spokes):
        a = 2 * math.pi * s / spokes
        pieces.append(_plate(f"{name}-spoke{s}", (w["major"], 2 * w["minor"], w["minor"]),
                             (w["major"] / 2 * math.cos(a), w["major"] / 2 * math.sin(a), 0), wheel,
                             rot=(0, 0, a), bev=0.008))
    _place(pieces, (w["centre"], rot))
    return v


# ---- parts a run lies in (#834) ------------------------------------------------------------------

def cable_tray(name, points, width, rung_pitch=None, material="dark"):
    """A ladder cable tray running straight between `points`, its bed, with a bracket under it at
    each point: two side rails with rungs between them, mitred at a bend (`rf_blender.tray_layout`).
    A loom laid in it follows `rf_blender.tray_lie(tray, half_width)`; the caller passes those
    points to `loom`, with no ties, since a tie round a loom in a tray passes through the rungs.

    THE READ IS THE GAP BETWEEN RUNGS, on the cut floor, and THE RAIL'S HEIGHT, on the raised floor,
    both checked in `rf_blender.tray_layout`. The rungs and brackets go in unchecked: a rung's
    width along the run is the raised floor, and its thickness is edge-on.

    ITS RUN IS HELD TO THE FOOTPRINT EDGE as a pipe's is, on half its outer width: a tray may run
    along an edge but never out of one (`models/house-style.md`, Only a socket meets a footprint
    edge). Each rail is one mesh with its vertices where they stand, so its object's matrix is the
    turn alone, and the bed goes into `_RUNS` on the first rail's object, read at save.

    Returns the layout."""
    import bmesh
    t = rf.tray_layout(name, points, width, rung_pitch)
    rails = []
    for side, sections in zip("RL", t["rails"]):
        bm = bmesh.new()
        rings = [[bm.verts.new(v) for v in sec] for sec in sections]
        for a, b in zip(rings, rings[1:]):
            for i in range(4):
                bm.faces.new((a[i], a[(i + 1) % 4], b[(i + 1) % 4], b[i]))
        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        mesh = bpy.data.meshes.new(f"{name}-rail{side}")
        bm.to_mesh(mesh)
        bm.free()
        o = bpy.data.objects.new(f"{name}-rail{side}", mesh)
        bpy.context.scene.collection.objects.link(o)
        o.data.materials.append(MATERIAL(material))
        bevel(o, 0.008, f"{name}-rail{side}")
        rails.append(o)
    _RUNS.append((rails[0], list(t["run"][0]), t["run"][1]))  # held to the edge at save, `_check_edges`

    def lay(piece, label):
        d = piece["along"]
        rot = (0.0, -math.atan2(d[2], math.hypot(d[0], d[1])), math.atan2(d[1], d[0]))
        _plate(label, piece["size"], piece["centre"], material, rot=rot, bev=0.006)

    for k, r in enumerate(t["rungs"]):
        lay(r, f"{name}-rung{k}")
    for k, b in enumerate(t["brackets"]):
        lay(b, f"{name}-bracket{k}")
    return t


# ---- access (#836) -------------------------------------------------------------------------------

def access_ladder(name, foot, top, facing, pitch=rf.LADDER_PITCH, cage_from=None, standoff=0.0,
                  material="dark", hoops="hazard"):
    """An access ladder straight up from `foot`, the middle of its base, to the height `top`,
    facing out along `facing` from what it stands against: two stiles, a rung each `pitch`, from
    `cage_from` over the foot a cage of hoops and bars on the side it faces, and where it stands
    `standoff` off what it is against, brackets back to it (`rf_blender.ladder_layout`). Not a
    research ladder (GLOSSARY.md, Access ladder).

    THE READ IS THE RUNG'S THICKNESS, on the raised floor, and THE GAP BETWEEN RUNGS, on the cut
    floor, both checked in `rf_blender.ladder_layout`; the cage's tube is held to the raised floor
    there and again by `pipe`. The stiles and brackets go in unchecked: their face is the raised
    floor.

    THE CAGE IS A GUARD, so its hoops and bars are hazard yellow unless `hoops` names another role
    (`models/house-style.md`, Palette); the stiles, rungs and brackets are `material`, dark or bare
    metal. The hoops and bars are drawn by `pipe`, so the footprint-edge check holds them at save.

    Returns the layout."""
    d = rf.ladder_layout(name, foot, top, facing, pitch=pitch, cage_from=cage_from, standoff=standoff)
    for side, s in zip("RL", d["stiles"]):
        _plate(f"{name}-stile{side}", (s["size"][0], s["size"][1], s["height"]), s["centre"], material,
               rot=(0, 0, s["yaw"]), bev=0.008)
    for k, r in enumerate(d["rungs"]):
        cyl(f"{name}-rung{k}", rf.LADDER_RUNG / 2, r["length"], r["centre"], material, rot=_facing(r["axis"]),
            verts=12, read=rf.LADDER_RUNG)
    tube = rf.LADDER_CAGE[1] / 2
    for k, h in enumerate(d["hoops"]):
        pipe(f"{name}-hoop{k}", h, tube, hoops)
    for k, (a, b) in enumerate(d["bars"]):
        pipe(f"{name}-bar{k}", [a, b], tube, hoops)
    for k, b in enumerate(d["brackets"]):
        _plate(f"{name}-bracket{k}", (b["length"], rf.LADDER_STILE[0], rf.LADDER_STILE[1]), b["centre"],
               material, rot=(0, 0, math.atan2(b["axis"][1], b["axis"][0])), bev=0.006)
    return d


# ---- floors (#835) -------------------------------------------------------------------------------

def grating_deck(name, centre, size, z, pitch=0.45, along="X", openings=(), open_edges=(),
                 marked_edges=(), material="dark", marking="hazard"):
    """A grating deck over the rectangle `size` (x, y) about `centre` (x, y), its top face at `z`:
    bars along `along` at the spacing nearest `pitch`, the edge ones flush to the edges, cut round
    each opening ((x, y), (sx, sy)) something passes through, with a toe board on each edge in
    `open_edges` and a marking on each walkway edge in `marked_edges` (`rf_blender.deck_layout`).

    THE READ IS THE GAP BETWEEN BARS, on the cut floor, and THE BAR'S WIDTH, on the raised floor,
    both checked in `rf_blender.deck_layout`, with a toe board's height on the raised floor too.
    The bars and boards go in unchecked after that: a bar's depth and a board's thickness are
    edge-on.

    A WALKWAY EDGE IS A MARKING, hazard yellow unless `marking` says otherwise (`models/house-style.md`,
    Palette): along the bars it is the edge bar, across them a nosing bar laid along it, and the
    edge's toe board where it has one. Nothing in
    a deck is pipe-shaped, so nothing in it goes to the footprint-edge check.

    Returns the layout."""
    d = rf.deck_layout(name, centre, size, z, pitch, along=along, openings=openings,
                       open_edges=open_edges, marked_edges=marked_edges)
    for k, b in enumerate(d["bars"]):
        _plate(f"{name}-bar{k}", b["size"], b["centre"], marking if b["marked"] else material, bev=0)
    for k, t in enumerate(d["toe_boards"]):
        _plate(f"{name}-toe{k}", t["size"], t["centre"], marking if t["marked"] else material, bev=0.006)
    return d


def _ties(name, points, inner):
    """A dark tie round a bundle at every inner control point of `points`, `inner` off the centre."""
    for i in range(1, len(points) - 1):
        a, b = points[i - 1], points[i + 1]
        torus(f"{name}-tie{i}", inner + 0.03, 0.03, tuple(points[i]), "dark",
              rot=_facing(tuple(b[j] - a[j] for j in range(3))))

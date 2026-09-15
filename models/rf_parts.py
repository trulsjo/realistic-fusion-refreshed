"""The mesh helpers every machine's build script shares, imported from inside Blender's Python.

    import rf_parts as parts
    parts.use(mat)              # the machine's own material resolver, before anything is built

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
never look inside them. `hbeam`, `rivets`, `seam` and `port` do not, and are the four that choose
their own material: a beam and a rivet are `frame` and `dark` by default, a seam is always `frame`,
and a port's rim is always `dark`. Passing `frost=True` to one of those is a TypeError rather than a
silent miss, which is the right failure -- but it is a failure, so if a machine ever wants a frosted
rivet the flag has to be plumbed through `rivets` first.

AND ONE NUMBER RE-EXPORTED RATHER THAN HELD: `SOCKET_Z`, the height a player-facing socket is drawn
at. It was here from #342, for the same reason the helpers are -- the second machine to need it
would have copied it -- and it now lives in models/rf_blender.py, which imports no bpy, so the gate
that measures sockets can read the same number the models are built at (#354). Build scripts still
say `rf_parts.SOCKET_Z` and none of them changed.

THE ORDER OF `random` DRAWS IS PART OF THE CONTRACT. `bevel` and `jitter` both draw from the global
`random`, which each build script seeds once; the imperfections are deterministic only as long as
the draws happen in the same order. Anything that re-orders a helper's body changes every
imperfection after it, even when the geometry logic is identical -- so a change here is verified by
re-rendering both machines and comparing sheets, never by reading the diff.

Detail floors are checked here rather than in the build scripts, on the reasoning
models/rf_blender.py's `check_detail` sets out: the read dimension, never the smallest.
"""
import math
import random
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
    sys.exit("rf_parts: no material resolver installed -- call rf_parts.use(mat) before building.")


def use(mat_fn):
    """Install the machine's material resolver. Every helper calls it as `mat_fn(name, **flags)`.

    ONE MACHINE PER PROCESS. The resolver is module state, so a future batch builder that made two
    machines in one Blender session would paint the second with the first's palette unless it called
    this again between them. Every build today is its own `blender -b`, so nothing is at risk yet.
    """
    global MATERIAL
    MATERIAL = mat_fn


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


def _plate(name, size, loc, material, rot=(0, 0, 0), bev=0.03, **mat_opts):
    """A box with NO detail-floor check, for a caller that has already made the check on its own
    behalf. `hbeam` is the only one: a beam is checked once on its flange width, and its web and
    two flanges then go in as the parts of a feature rather than as features."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = size
    o.data.materials.append(MATERIAL(material, **mat_opts))
    if bev:
        bevel(o, bev)
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


def torus(name, major, minor, loc, material, rot=(0, 0, 0), **mat_opts):
    rf.check_detail(name, 2 * minor)                   # a ring reads by its thickness, not its radius
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=loc, rotation=rot,
                                     major_segments=48, minor_segments=12)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(MATERIAL(material, **mat_opts))
    return o


# WHERE A SOCKET'S ACCENT BAND SITS ON ITS TUBE, and how far the hole through the floor stands
# clear of it. Constants rather than arguments because these are a socket's proportions rather than
# a machine's choice: both rendered machines have always used exactly these, in two copies.
BAND_BACK = 0.28                 # the band's centre, inboard of the footprint edge
BAND_DEPTH = 0.22
BAND_PROUD = 0.04                # how far the band stands out past the tube
PORT_CLEARANCE = 0.06            # and the hole past the band, so it reads as a hole


def port(body, axis, across, edge, sign, radius, depth=0.7):
    """Cut the hole a socket passes through, in `body`, and rim its mouth.

    `axis` is the socket's own axis, "X" or "Y"; `across` is its position on the other ground axis;
    `edge` is the footprint edge it stops at and `sign` which way that lies (+1 east or north).

    The cutter is a modifier rather than an applied boolean, the way `bevel` is: Blender evaluates
    BEVEL then BOOLEAN in the order they were added, so the hole is cut into the already-rounded
    body and neither has to be baked. Nothing here is destructive, so a re-render from the same
    script gives the same object.

    `radius` is the socket's own plus clearance -- both machines add 0.06 -- because a hole exactly
    the size of the tube leaves a z-fighting shell where the two surfaces touch, and a hole a little
    proud reads as a hole. It is passed rather than derived from SOCKET_Z's sibling constant,
    because a machine may cut a port for a socket of any width: models/house-style.md binds a
    PLUMBABLE socket to the pipe's 0.249, and says nothing about the rest.

    DRAWS NOTHING FROM `random`, which is why it could be lifted out of a build script without
    moving a single imperfection: the cutter is a raw primitive and `torus` puts on no bevel. See
    this module's own header on why that matters.
    """
    cutter_loc = [0.0, 0.0, SOCKET_Z]
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
    rim_loc = [0.0, 0.0, SOCKET_Z]
    rim_loc[0 if axis == "X" else 1] = edge - sign * 0.03
    rim_loc[1 if axis == "X" else 0] = across
    torus(f"PortRim-{axis}-{across:g}", radius + 0.02, 0.05, tuple(rim_loc), "dark",
          rot=(0, math.pi / 2, 0) if axis == "X" else (math.pi / 2, 0, 0))


def socket(body, connection, geo, z, radius, plumbable=True, **mat_opts):
    """Draw one connection's socket: the bare-metal stub, its accent band and -- on a socket a
    player can plumb -- the port through `body`.

    `connection` is one entry of the machine's geometry.json and `geo` the file it came from. The
    stub runs from half a tile inside the COLLISION edge out to the SELECTION edge, which is where
    both rendered machines put theirs; on both, those are a quarter tile apart, so the mouth stands
    clear of the body and the rim `port` puts on it reads as the flange a pipe bolts to.

    WHAT IS THE CALLER'S BUSINESS AND MUST STAY THERE: `z`, `radius` and `plumbable`. A CONTAINED
    connection (ADR 0018) meets a machine FACE and never a pipe, so it is drawn at the machine's own
    height and thickness and gets no hole through the floor; a connection a player plumbs is drawn
    like the pipe that plugs into it -- SOCKET_Z and 0.249, both measured (models/house-style.md).
    rf-heat-exchanger carries both kinds and reads the difference off `connection_category`;
    rf-isotope-collector has none. A helper that decided containment for its caller would sooner or
    later put a socket at pipe height on a face that meets a reactor.

    `mat_opts` reach the STUB only: the collector frosts its tube, and an accent band is the one
    thing on a socket that must stay the colour of the fluid it names.

    THE ORDER OF THE THREE IS PART OF THE CONTRACT -- stub, band, port -- because `cyl` bevels and
    a bevel draws from `random`. Re-ordering them moves every imperfection after them on every
    machine that calls this, and the only way to see it is to re-render. See this module's header.
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

    cyl(f"Socket-{d}-{fluid}", radius, abs(edge - inner), at((edge + inner) / 2), "metal",
        axis=axis, **mat_opts)
    cyl(f"Band-{d}-{fluid}", radius + BAND_PROUD, BAND_DEPTH, at(edge - BAND_BACK * sign),
        rf.accent(fluid), axis=axis)
    if plumbable:
        port(body, axis, across, edge, sign, radius + PORT_CLEARANCE)


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


def pipe(name, points, radius, material, corrugate=0.0, band=(1.15, 0.22), **mat_opts):
    """A pipe along a Bezier curve through `points` (slightly wobbly by construction), with
    optional corrugation rings every `corrugate` tiles.

    `band` scales a ring against the pipe's radius: (major, minor). The default is the subtle
    ring every pipe here has always had; the steam header passes a heavier one, because on that
    pipe the corrugation is the thing being drawn rather than a detail on it.

    A RING HAS A HIGHER FLOOR THAN ITS PIPE. At the default band a ring's minor diameter is 0.44 of
    the pipe's radius, so a pipe that clears the raised-detail floor on its own at radius 0.03 dies
    at `<name>-ring0` until radius 0.136. The shipped header clears it at 0.19 with its own heavier
    band. It fails loudly and by name, so this is a thing to know before adding `corrugate=` to a
    thin pipe rather than a thing to work around.
    """
    rf.check_detail(name, 2 * radius)
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
        travelled, next_ring, k = 0.0, corrugate / 2, 0
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
    loc = (jitter(loc[0], 0.02), jitter(loc[1], 0.02), jitter(loc[2], 0.012))
    rot = (jitter(0, 0.012), jitter(0, 0.012), jitter(0, 0.012))
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


def jitter(v, s):
    return v + random.uniform(-s, s)

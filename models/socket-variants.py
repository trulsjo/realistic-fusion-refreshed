"""Draw one socket END TREATMENT onto a machine's stored model, into a throwaway .blend. For #350.

    blender -b models/<machine>/<machine>.blend --python models/socket-variants.py \
            -- <treatment> <out.blend>

NOTHING HERE SHIPS, and the one rule this file has is that it must not be able to make anything
that does. It opens a model read-only and writes a DIFFERENT file, and the out path given on the
command line is refused if it lands anywhere a shipped file lives: not the model it opened, not
`models/` at all, and not the Assets mod. Refusing only the opened model is not enough and was the
first version's mistake -- pointing a collector variant at
`models/heat-exchanger/heat-exchanger.blend` would have replaced one machine's model with another
machine wearing a treatment, and the next `/render-machine rf-heat-exchanger` would have rendered
it into the Assets mod with nothing having complained. The sheets rendered off the result belong in
a scratch directory too, which is scripts/probe-socket-shapes.ps1's job (`models/render.py --out`).

WHY IT EDITS THE SHIPPED MODEL RATHER THAN BUILDING A STUB OF ITS OWN. The question #350 asks is
what a socket's mouth should look like NEXT TO THE PIPE A PLAYER PLUGS INTO IT, and the answer
depends on everything around the mouth -- the accent band a fifth of a tile behind it, the dark rim
on it, the slab the tube passes through and the hole cut for it. A purpose-built stub would have to
reproduce all of that to be worth looking at, and would then be a second copy of it, drifting. So
the control ("bare") is the shipped machine with nothing added, which is the only control that is
actually what ships.

THE TREATMENTS, which are the four #350 names and no more:

  bare        nothing added. The control, and the proof that this script's own pipeline draws
              nothing of its own: a `bare` sheet must come out pixel-identical to the shipped one.
  flanged     vanilla's flange pair at the stub's mouth -- two discs standing proud of the tube,
              in the tube's own material, just inboard of the dark rim.
  dark-cored  a shadowed channel along the tube's most camera-facing line, the way vanilla's pipe
              reads. Which line that is depends on the tube's direction and is derived below, not
              guessed.
  collared    the dark rim moved off the footprint edge onto the body face, so it rings the hole in
              the slab instead of the mouth in mid-air. Nothing is added; one object moves.

Every added piece goes through models/rf_parts.py, so it takes the house style's bevel and the
detail floor without this file restating either, and a change to the shipped socket geometry reaches
these variants for free. The material resolver installed below looks materials up in the OPENED
MODEL by name rather than building a palette, so a variant cannot invent a colour the machine does
not already wear.
"""
import json
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import rf_blender as rf  # noqa: E402
import rf_parts  # noqa: E402
from rf_parts import box, cyl  # noqa: E402

TREATMENTS = ("bare", "flanged", "dark-cored", "collared")

# THE FLANGE PAIR IS FITTED TO THE BARE TUBE, NOT PLACED AT TYPED OFFSETS. There is very little
# bare tube at a socket's mouth: on the collector the stub is 0.75 tiles long, the dark rim owes
# the first 0.08 of it and the accent band starts at 0.17, leaving 0.09 tiles of metal for a pair
# of ribs. Two ribs at typed offsets is how the first version did it, and they came out buried in
# the rim at one end and clipping the band at the other -- a fat lump rather than vanilla's flange
# pair, which is a picture of the wrong thing on a ticket whose whole purpose is the picture.
#
# So the span is MEASURED off the rim and the band that are already in the model, and the ribs are
# divided into it. A machine whose numbers differ gets ribs that fit its own tube, and a machine
# with no room at all fails loudly instead of drawing a lump.
FLANGE_GAP = 0.2                 # of the clear span, between the two ribs
FLANGE_MIN_THICK = 0.02          # under this a rib is thinner than a pixel and there is no pair
# What makes a rib read as a flange is standing PROUD of the tube, not its thickness: 0.07 tiles is
# 4.5 px each side at 64 px to the tile, which is why the detail floor is cleared on the disc's
# face and not on its edge (models/rf_parts.py's `cyl` on `read=`).
FLANGE_PROUD = 0.07

# The shadowed channel. It is an added plate, not a boolean subtraction, so it takes the RAISED
# floor -- and it clears it on its WIDTH, which is what `read=` is for. Judged on its smallest
# dimension instead it would die on CORE_THICK, which is the thing nobody sees.
CORE_WIDTH = 0.11
CORE_THICK = 0.03
# The palette's near-black, at (0.07, 0.08, 0.09). `dark` is the wrong pick and not because it is
# too pale to see -- it would read perfectly well against a 0.55 metal tube. It is that (0.26,
# 0.27, 0.29) is within 0.02 a channel of `body`, so a channel in it reads as a painted panel
# rather than as a shadow, which is the one thing this treatment is imitating.
CORE_MATERIAL = "frame"

# How far a moved rim stands OUTBOARD of the body wall, so it reads as a collar round the hole
# rather than a disc buried in it. Not rf_parts.port's own 0.03, which goes the other way: that
# one sets the rim 0.03 INBOARD of the footprint edge, where it rings nothing but air.
RIM_PROUD = 0.03

random.seed(350)                 # rf_parts' bevels draw from `random`; same treatment, same model


def fail(message):
    sys.exit(f"socket-variants: {message}")


args = rf.script_args()
if len(args) != 2:
    fail(f"usage: -- <{'|'.join(TREATMENTS)}> <out.blend>")
treatment, out_path = args[0], os.path.abspath(args[1])
if treatment not in TREATMENTS:
    fail(f"unknown treatment {treatment!r}; known: {', '.join(TREATMENTS)}")

model_path = bpy.data.filepath
if not model_path:
    fail("open a saved model: blender -b models/<machine>/<machine>.blend --python models/socket-variants.py")

REPO = os.path.dirname(HERE)
# Where a shipped file lives. `models/` covers every machine's .blend, geometry.json and build.py,
# including the one opened; the Assets mod covers every sheet a prototype names.
NO_WRITE = (HERE, os.path.join(REPO, "realistic-fusion-refreshed-assets"))


def inside(path, directory):
    path, directory = os.path.normcase(os.path.abspath(path)), os.path.normcase(os.path.abspath(directory))
    return path == directory or path.startswith(directory + os.sep)


for guarded in NO_WRITE:
    if inside(out_path, guarded):
        fail(f"refusing to write {out_path} -- it is inside {guarded}, where shipped files live. "
             f"Variants go to a scratch directory; nothing this script makes may ship.")

geo_path = os.path.join(os.path.dirname(model_path), "geometry.json")
geo = json.load(open(geo_path, encoding="utf-8"))
(cx0, cy0), (cx1, cy1) = geo["collision_box"]


def resolve(name, frost=False):
    """rf_parts' material resolver, reading the OPENED MODEL rather than a palette of its own.

    A build script's `mat` makes materials; this makes none. Every treatment paints itself in a
    colour the machine already wears -- the tube's own material for a flange, the palette's frame
    black for a channel -- so a variant cannot change what the set looks like while answering a
    question about shape.
    """
    key = f"{name}-frost" if frost else name
    m = bpy.data.materials.get(key)
    if m is None:
        fail(f"{os.path.basename(model_path)} has no material {key!r}; it has: "
             + ", ".join(sorted(x.name for x in bpy.data.materials)))
    return m


rf_parts.use(resolve)


def axis_of(obj):
    """('X'|'Y', +1|-1) for a stub or a rim: the ground axis it lies along, and which way it points
    away from the machine's centre. Read off the OBJECT rather than off geometry.json, so it needs
    only the two conventions both rendered machines already follow -- a stub named Socket-*, laid
    along a ground axis with rf_parts.cyl's own `axis=` rotation. It is not an rf_parts guarantee:
    rf_parts.port builds the rims, but each machine's build.py builds and names its own stubs."""
    if abs(obj.rotation_euler.y - math.pi / 2) < 1e-3:
        axis = "X"
    elif abs(obj.rotation_euler.x - math.pi / 2) < 1e-3:
        axis = "Y"
    else:
        fail(f"{obj.name} lies along neither ground axis (rotation {tuple(obj.rotation_euler)})")
    along = obj.location.x if axis == "X" else obj.location.y
    if abs(along) < 1e-6:
        fail(f"{obj.name} sits on the machine's centre line; which way it points cannot be read")
    return axis, (1 if along > 0 else -1)


def world_bounds(obj):
    """(min, max) of an object's bounding box in world space, as two 3-tuples."""
    bpy.context.view_layer.update()
    pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    return (tuple(min(p[k] for p in pts) for k in range(3)),
            tuple(max(p[k] for p in pts) for k in range(3)))


def body_face(axis, sign):
    """Where the machine's body wall is on one side: the COLLISION box edge, which is where the slab
    stops and where rf_parts.port cuts its hole. A quarter tile inside the selection box the socket
    stub runs out to, on both rendered machines. Blender +Y is Factorio north, so the Y edges swap."""
    if axis == "X":
        return cx1 if sign > 0 else cx0
    return -cy0 if sign > 0 else -cy1


sockets = sorted((o for o in bpy.data.objects if o.name.startswith("Socket-")), key=lambda o: o.name)
rims = sorted((o for o in bpy.data.objects if o.name.startswith("PortRim-")), key=lambda o: o.name)
if not sockets:
    fail(f"{os.path.basename(model_path)} has no object named Socket-*")


def bare_span(stub, axis, sign, i, j, across, mouth):
    """How much bare tube a stub shows at its mouth, as (near, far) distances back from the mouth.

    Everything here is distance INBOARD from the mouth, so both numbers grow as you walk into the
    machine. `near` is where the dark rim stops and `far` is where the accent band starts.

    THE TWO NEIGHBOURS ARE FOUND IN THE MODEL, NOT ASSUMED. The band is named for the socket it
    belongs to, so it is looked up by name; the rim is named for its axis and its position across
    that axis, and rf_parts.port gives all three of the collector's rims the same `across` of 0 --
    so Blender uniquifies them and the name cannot be relied on. It is matched on geometry instead:
    same axis, same way out, same line across. A stub missing either neighbour reports the whole
    tube as bare, which is the right answer for a machine that draws neither.
    """
    def back(coord):
        return sign * (mouth - coord)

    near, far = 0.0, back(stub.location[i]) * 2      # the whole stub, if there is nothing on it

    band = bpy.data.objects.get(stub.name.replace("Socket-", "Band-", 1))
    if band:
        lo, hi = world_bounds(band)
        far = min(back(hi[i]), back(lo[i]))
    for rim in rims:
        if axis_of(rim) != (axis, sign) or abs(rim.location[j] - across) > 1e-6:
            continue
        lo, hi = world_bounds(rim)
        near = max(back(hi[i]), back(lo[i]))
    return near, far

print(f"SOCKET-VARIANTS {treatment}: {len(sockets)} socket(s), {len(rims)} rim(s) in "
      f"{os.path.basename(model_path)}")

for stub in sockets:
    axis, sign = axis_of(stub)
    i = 0 if axis == "X" else 1                     # the stub's own ground axis
    j = 1 - i                                       # the other one
    lo, hi = world_bounds(stub)
    mouth = hi[i] if sign > 0 else lo[i]
    radius = (hi[j] - lo[j]) / 2
    across = stub.location[j]
    z = stub.location.z
    material = stub.data.materials[0].name

    if treatment == "flanged":
        near, far = bare_span(stub, axis, sign, i, j, across, mouth)
        thick = (far - near) * (1 - FLANGE_GAP) / 2
        if thick < FLANGE_MIN_THICK:
            fail(f"{stub.name}: only {far - near:.3f} tiles of bare tube between the rim and the "
                 f"accent band, which is not enough for a flange pair ({2 * FLANGE_MIN_THICK:.2f} "
                 f"tiles of rib plus a gap). Nothing was drawn, on purpose.")
        for k, back in enumerate((near + thick / 2, far - thick / 2)):
            loc = [0.0, 0.0, z]
            loc[i] = mouth - sign * back
            loc[j] = across
            # A DISC READS BY ITS FACE, not by its thickness -- rf_parts.cyl's `read=` exists for
            # exactly this, and without it a rib this thin dies on the raised-detail floor.
            cyl(f"Flange-{stub.name}-{k}", radius + FLANGE_PROUD, thick, tuple(loc),
                material, axis=axis, read=2 * (radius + FLANGE_PROUD))
        print(f"SOCKET-VARIANTS   {stub.name}: bare tube {near:.3f}..{far:.3f} back from the mouth, "
              f"two ribs {thick:.3f} thick in it")

    elif treatment == "dark-cored":
        # WHICH LINE OF THE TUBE FACES THE CAMERA depends on the tube's direction, and getting it
        # wrong puts the channel on the tube's flank where it reads as a stripe rather than a core.
        # The camera looks down at rf_blender.CAMERA_PITCH_DEG from the south. For a tube running
        # EAST-WEST the camera-facing surface normal is the camera's own direction reversed, tilted
        # off vertical by (90 - pitch). For a tube running NORTH-SOUTH that direction has a
        # component along the tube itself; strip it and what is left points straight up, so the
        # channel goes on the crown.
        length = (hi[i] - lo[i]) + 0.02
        # SUNK BY ITS EDGES, NOT BY ITS CENTRE. A flat plate touches a cylinder along one line, so
        # dropping it half its thickness leaves its two long edges standing proud -- 0.006 tiles
        # here, which is nothing in game and a visible lip at zoom 8, on a frame whose whole
        # subject is a surface. The cylinder is at sqrt(r^2 - (w/2)^2) under the plate's edges.
        off = math.sqrt(radius ** 2 - (CORE_WIDTH / 2) ** 2) - CORE_THICK / 2
        if axis == "X":
            tilt = math.radians(90 - rf.CAMERA_PITCH_DEG)
            centre = [(lo[0] + hi[0]) / 2, across - math.sin(tilt) * off, z + math.cos(tilt) * off]
            size, rot = (length, CORE_WIDTH, CORE_THICK), (tilt, 0.0, 0.0)
        else:
            centre = [across, (lo[1] + hi[1]) / 2, z + off]
            size, rot = (CORE_WIDTH, length, CORE_THICK), (0.0, 0.0, 0.0)
        box(f"Core-{stub.name}", size, tuple(centre), CORE_MATERIAL, rot=rot, bev=0,
            read=CORE_WIDTH)

if treatment == "collared":
    if not rims:
        fail(f"{os.path.basename(model_path)} has no object named PortRim-*, so there is no rim to move")
    for rim in rims:
        axis, sign = axis_of(rim)
        i = 0 if axis == "X" else 1
        was = rim.location[i]
        rim.location[i] = body_face(axis, sign) + sign * RIM_PROUD
        print(f"SOCKET-VARIANTS   {rim.name}: {was:+.3f} -> {rim.location[i]:+.3f} along {axis}")

os.makedirs(os.path.dirname(out_path), exist_ok=True)     # a scratch path that does not exist yet
bpy.ops.wm.save_as_mainfile(filepath=out_path)
print(f"SOCKET-VARIANTS wrote {out_path}")

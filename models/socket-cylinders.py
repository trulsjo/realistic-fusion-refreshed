"""Build a scene of BARE CYLINDERS at several radii and several heights, for measuring. Throwaway.

    blender -b --python models/socket-cylinders.py -- <out.blend> [--no-ground]

WHAT IT IS FOR. A socket drawn at pipe height loses part of its underside, and what is known about
that loss is four measurements off one machine at one height (models/house-style.md's socket table,
#362). Four points cannot tell a law from a coincidence, and a machine's socket wears a rim, a band
and two flange ribs crowding the very tube being read -- which is the confusion
tools/socket_strip.py's column window exists to keep out. This scene varies ONE thing at a time:
plain cylinders, nothing on them, on the rig the shipped machines are rendered through.

IT OPENS NO MODEL, which is what separates it from models/socket-variants.py. That file takes a
shipped machine and changes one thing about it; this one builds a scene from nothing, so the only
thing in frame is the thing being measured. Both are throwaway builders, both refuse to write into
models/ or the Assets mod, and neither makes anything that can ship.

THE RIG IS THE SHIPPED RIG AND THE CYLINDER IS THE SHIPPED HELPER. models/rf_blender.build_rig
gives the same camera, the same sun, the same world and the same shadow-catching ground plane every
sheet is rendered through, and models/rf_parts.cyl draws the tube -- so the bevel, the vertex count
and the detail floor are a machine's, not this file's. A scene that drew its own cylinder would be
measuring its own cylinder. `--no-ground` deletes the ground plane and is the whole of #366's
question asked on bare tube: if every deficit goes to zero the plane is the cause.

WHY IT IS A MACHINE-SHAPED SCENE AND NOT A ROW OF FLOATING TUBES. tools/socket_strip.py finds a
socket by the two cuts every measurement here is made through -- the columns between a footprint's
collision edge and its selection edge, and the rows a tile either side of a connection's ground
line. So the scene declares a footprint and a connection per cylinder, writes the geometry.json
models/render.py reads, and every number then comes off the same instrument that reads a shipped
sheet. The footprint holds no body: outboard of it there is nothing but the tube, which is the
point.

WHAT IS WRITTEN BESIDE THE MODEL. geometry.json, for models/render.py; and cylinders.json, which
says which connection carries which radius at which height. The second is how
scripts/probe-socket-underside.py knows what it is reading, because a connection's radius and height
are exactly the two numbers tools/measure-socket-parts.py refuses to guess.

IT IS NOT CALLED A BENCH, AND THE NAME IS THE REASON. CONTEXT.md's Measurement words give `bench` to
a script that measures a quantity and asserts its own validity -- tools/measure-socket-parts.py is
one -- and this builds a scene rather than measuring anything. One word, one meaning.

THE GRID IS HERE AND IS COMMITTED, so the next engine version can be asked the same question and
get an answer comparable with this one. Changing it is fine and changes the answer's coverage;
changing it silently makes two runs incomparable.

Deterministic: one seed, and rf_parts' bevels are the only draw.
"""
import json
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402

import rf_blender as rf  # noqa: E402
import rf_parts  # noqa: E402

# THE GRID. Six radii and six heights, 36 cylinders.
#
# THE RADII ARE THE FOUR A MACHINE'S SOCKET ALREADY DRAWS, PLUS ONE EITHER SIDE. 0.249 is the tube,
# 0.289 the accent band, 0.319 the flange ribs and 0.379 the dark rim -- the four rows of
# models/house-style.md's socket table, so the machine's own measurements can be held against the
# curve rather than compared with something near it. 0.15 and 0.45 stand outside that range at both
# ends, because a law fitted only where the data already lies is a law nobody can test.
RADII = (0.15, 0.249, 0.289, 0.319, 0.379, 0.45)
# THE HEIGHTS RUN FROM THE GROUND LINE TO THE OLD SOCKET HEIGHT. 0.033 is rf_blender.SOCKET_Z, what
# a plumbable socket is drawn at today; 0.55 is what both machines drew before the join was measured
# against a vanilla pipe (rf_blender.SOCKET_Z carries that history), and is high enough that the
# widest cylinder here clears the ground entirely -- the plane stops reaching a tube at r cos(pitch),
# which at radius 0.45 is 0.26. 0.0 is the degenerate end, where half of every tube is under it.
HEIGHTS = (0.0, 0.033, 0.10, 0.20, 0.35, 0.55)

# Tiles between one cylinder's ground line and the next. tools/socket_strip.py searches one tile
# either side of a connection's ground line, so two tiles would put a neighbour exactly on the edge
# of that window; three keeps every silhouette well clear of its neighbour's rows.
ROW_PITCH = 3.0
# How far across the footprint is. Three tiles leaves 2.5 tiles between the west outboard strip and
# the east one, and 1.5 tiles between the inboard ends of the two tubes -- both far more than any
# window a measurement opens, which never leaves its own quarter-tile strip.
TILES_W = 3.0
# How far the tube runs inboard from the footprint edge: the isotope collector's stub length, so a
# cylinder here is as long as one on a machine.
STUB_LENGTH = 0.75
# The fluid every connection declares. NOT a real one: nothing here is a prototype, and a scene
# that borrowed a shipped fluid's name would read as a machine in any tool that printed it.
TEST_FLUID = "rf-test"
# And a connection_category, so tools/socket_strip.plumbable calls every cylinder here CONTAINED.
# A test cylinder is drawn at a height this file chooses, which is exactly what that flag means to
# tools/measure-socket-parts.py -- it then demands `--z` instead of defaulting to SOCKET_Z and
# measuring every row about the wrong axis.
TEST_CATEGORY = "rf-test"

random.seed(367)                 # rf_parts' bevels draw from `random`; same grid, same model


def fail(message):
    sys.exit(f"socket-cylinders: {message}")


args = rf.script_args()
no_ground = "--no-ground" in args
positional = [a for a in args if not a.startswith("--")]
unknown = [a for a in args if a.startswith("--") and a != "--no-ground"]
if len(positional) != 1 or unknown:
    fail("usage: -- <out.blend> [--no-ground]")
out_path = os.path.abspath(positional[0])

REPO = os.path.dirname(HERE)
# The same two guarded roots models/socket-variants.py refuses, for the same reason: `models/`
# holds every machine's .blend, geometry.json and build.py, and the Assets mod holds every sheet a
# prototype names. Nothing this file makes may reach either.
NO_WRITE = (HERE, os.path.join(REPO, "realistic-fusion-refreshed-assets"))


def inside(path, directory):
    path, directory = os.path.normcase(os.path.abspath(path)), os.path.normcase(os.path.abspath(directory))
    return path == directory or path.startswith(directory + os.sep)


for guarded in NO_WRITE:
    if inside(out_path, guarded):
        fail(f"refusing to write {out_path} -- it is inside {guarded}, where shipped files live. "
             f"The scene goes to a scratch directory; nothing this script makes may ship.")

out_dir = os.path.dirname(out_path)
os.makedirs(out_dir, exist_ok=True)

# ---- the grid, and the geometry it declares --------------------------------------------------
#
# One cylinder per (radius, height) pair, laid alternately on the west and the east side so the
# scene is half as tall as it would be down one wall. The two sides are measured on the same sheet,
# in column strips 2.5 tiles apart, and neither can reach the other.
grid = [(r, z) for r in RADII for z in HEIGHTS]
rows = (len(grid) + 1) // 2
tiles_h = ROW_PITCH * rows
# A FOOTPRINT IS WHOLE TILES, and geometry.json declares one. An edit to RADII, HEIGHTS or ROW_PITCH
# that lands on a fraction would be truncated there and left the rig built half a tile taller than
# the frame says, which reads as every measurement being off by a row rather than as a bad grid.
if abs(tiles_h - round(tiles_h)) > 1e-9:
    fail(f"{len(grid)} cylinder(s) at a pitch of {ROW_PITCH:g} give a footprint {tiles_h:g} tiles "
         f"deep, which is not whole tiles. Adjust ROW_PITCH or the grid.")
half_w, half_h = TILES_W / 2, tiles_h / 2

connections, cylinders = [], []
for k, (radius, z) in enumerate(grid):
    direction = "west" if k % 2 == 0 else "east"
    sign = -1 if direction == "west" else 1
    py = -half_h + ROW_PITCH / 2 + ROW_PITCH * (k // 2)
    px = sign * (half_w - 0.5)
    connections.append({
        "box": "fluid_box", "production_type": "input", "fluid": TEST_FLUID, "flow": "input",
        "connection_type": "normal", "connection_category": TEST_CATEGORY,
        "direction": direction, "position": [px, py],
    })
    cylinders.append({"direction": direction, "position": [px, py], "radius": radius, "z": z})

geo = {
    "name": "rf-socket-cylinders",
    "type": "test-scene",
    # A quarter tile of outboard strip, which is what both rendered machines leave between their
    # collision edge and their selection edge and therefore how much of a socket a measurement can
    # ever see.
    "collision_box": [[-half_w + 0.25, -half_h + 0.25], [half_w - 0.25, half_h - 0.25]],
    "selection_box": [[-half_w, -half_h], [half_w, half_h]],
    "tiles": [int(TILES_W), int(tiles_h)],
    "connections": connections,
    "source": "written by models/socket-cylinders.py; not a prototype and not extracted from one",
}
geo_path = os.path.join(out_dir, "geometry.json")
with open(geo_path, "w", encoding="utf-8", newline="\n") as f:
    json.dump(geo, f, indent=2, sort_keys=True)
    f.write("\n")

# ---- the scene -------------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = "rf"

_MATERIALS = {}


def mat(name, **flags):
    """One plain material for the whole scene, and flags are a hard error.

    What is measured off this scene is a SILHOUETTE, which is alpha, which the colour cannot move.
    So there is no palette here and nothing to keep in step with models/house-style.md -- but a flag
    arriving from a helper would mean a caller thought there was, and is worth a traceback rather
    than a shrug.
    """
    if flags:
        fail(f"this scene paints everything one colour; {name} was asked for {sorted(flags)}")
    if name not in _MATERIALS:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (0.55, 0.55, 0.58, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.35
        bsdf.inputs["Metallic"].default_value = 0.8
        _MATERIALS[name] = m
    return _MATERIALS[name]


rf_parts.use(mat)

for item in cylinders:
    radius, z = item["radius"], item["z"]
    sign = -1 if item["direction"] == "west" else 1
    mouth = sign * half_w
    x = mouth - sign * STUB_LENGTH / 2
    # FACTORIO'S +Y IS SOUTH AND BLENDER'S IS NORTH, which is the flip every build script makes at
    # its socket loop. The connection above declares a Factorio position; the cylinder below is
    # drawn at the Blender one, so the two are the same place rather than mirrored about the middle
    # of the scene -- which on a symmetric grid would look right and read every row off the wrong
    # cylinder.
    y = -item["position"][1]
    rf_parts.cyl(f"Socket-{item['direction']}-r{radius:g}-z{z:g}", radius, STUB_LENGTH,
                 (x, y, z), "metal", axis="X")

rf.build_rig(scene, TILES_W, tiles_h, icon_centre=(0, 0, 0), icon_tiles=TILES_W)
scene["rf_geometry_sha256"] = rf.geometry_sha256(geo_path)

if no_ground:
    # THE FLAGS ARE READ AND PRINTED, NOT ASSUMED (#366). rf_blender.ground_report reads them off
    # the object and their meanings off the running Blender's own RNA; models/socket-variants.py's
    # `groundless` prints the same report over a shipped machine.
    ground = bpy.data.objects["Ground"]
    for line in rf.ground_report(ground):
        print(f"SOCKET-CYLINDERS   {line}")
    bpy.data.objects.remove(ground, do_unlink=True)
    print("SOCKET-CYLINDERS   Ground removed; the shadow sheet this renders is empty by construction")

with open(os.path.join(out_dir, "cylinders.json"), "w", encoding="utf-8", newline="\n") as f:
    json.dump({
        "radii": list(RADII), "heights": list(HEIGHTS),
        "row_pitch": ROW_PITCH, "stub_length": STUB_LENGTH,
        "ground": not no_ground,
        "blender": bpy.app.version_string,
        # WHAT AN UNCUT CYLINDER OF RADIUS 1 DRAWS EITHER SIDE OF ITS AXIS, recorded so a reader of
        # this file alone knows what the numbers beside it are compared against. It is derived in
        # tools/socket_strip.py from the camera pitch; repeated here as a value rather than a second
        # derivation, and the probe refuses to read a scene whose value disagrees with the one it is
        # measuring through. That is a probe checking its own instrument, not asserting anything
        # about a socket.
        "uncut_per_radius": 1.0 / math.sin(math.radians(rf.CAMERA_PITCH_DEG)),
        "cylinders": cylinders,
        "source": "written by models/socket-cylinders.py",
    }, f, indent=2, sort_keys=True)
    f.write("\n")

bpy.ops.wm.save_as_mainfile(filepath=out_path)
print(f"SOCKET-CYLINDERS wrote {out_path}: {len(cylinders)} cylinder(s), "
      f"{len(RADII)} radii x {len(HEIGHTS)} heights, footprint {TILES_W:g}x{tiles_h:g} tiles, "
      f"ground {'removed' if no_ground else 'present'}")

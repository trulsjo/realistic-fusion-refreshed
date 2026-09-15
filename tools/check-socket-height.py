#!/usr/bin/env python3
"""Fail when a player-facing socket is drawn at a height a vanilla pipe would not meet.

    python tools/check-socket-height.py --vanilla-pipe <pipe-straight-horizontal.png> \
           <manifest.json> [...]                                   # gate: exit 1 on a mismatch
    python tools/check-socket-height.py --vanilla-pipe <...> --self-test <manifest.json> [...]

A GATE, and it reads pixels -- which is the point. rf-heat-exchanger and rf-isotope-collector both
built their sockets at z 0.55 for months, both were drawn about half a tile of world height above
the pipe a player plugs into them, and every check here passed the whole time. scripts/load-check.ps1
holds a manifest's recorded geometry against the live prototype and never opens a sheet;
scripts/ship-check.ps1 reads prose; the art probes photographed the machine alone, bolted to a
reactor, and in four rotations, and never once put a pipe on it. This is a defect only a sprite
shows, so this is the one thing here that looks at one (#344).

NOT EVERY SOCKET, AND THE DIFFERENCE IS THE WHOLE CARE OF IT. A connection carrying a
`connection_category` is CONTAINED (ADR 0018, #86): it meets a machine face, never a pipe, and
matching it to a pipe would be wrong. A connection the manifest records as `default` -- null in the
recorded geometry -- is one a player plumbs, and is the only kind in scope. The discriminator is the
recorded field, never a list of fluids or machines.

HOW THE MEASUREMENT WORKS, and why it needs no second camera model. models/rf_blender.py's rig is
orthographic at CAMERA_PITCH_DEG with the pixel aspect squaring the ground, so on every sheet one
ground tile is PX_PER_TILE pixels in both axes and a world height h draws 1/tan(pitch) = 0.707 h
above the ground line. A socket is a cylinder lying along a ground axis, so its silhouette is
symmetric about that axis and the MIDPOINT of its drawn extent is the axis, wherever the accent
band and the port rim put the extremes.

THAT SYMMETRY HOLDS ONLY WHILE THE WHOLE SILHOUETTE IS ABOVE THE GROUND PLANE, AND AT PIPE HEIGHT
IT IS NOT. `rf_blender.build_rig` puts a shadow-catching ground plane at z 0, and a socket drawn at
SOCKET_Z reaches well below it -- radius 0.249 about its axis at 0.033 -- so its underside is cut
off and the midpoint rides high. At the old z 0.55 the tube cleared the plane and the same
measurement landed within 0.002 of prediction, which is how the derivation came to be trusted
somewhere it does not apply.

SO THIS COMPARES TWO DRAWN CENTRES AND DOES NOT RECOVER A WORLD HEIGHT. It measures where our
socket is drawn, against where a vanilla pipe's body is drawn, and both sides are numbers off a
sheet. That is the right comparison anyway -- vanilla's pipe is a stylised ribbon and not a
projected cylinder, so there is no world z to recover on its side either -- but it means the
residual below is geometric rather than incidental, and that it scales with the socket's RADIUS.
Both machines draw a plumbable socket at 0.249 (models/house-style.md), so both carry the same one;
a machine that drew one thicker would carry more.

AND THE RESIDUAL IS NOT INDEPENDENT OF THE HEIGHT, which #356 assumed it was. Lowering the socket
lowers the axis but also pushes more of the tube under the cut, so the two move against each other.
Measured on both machines either side of that change, with a sub-pixel read of the same strip:
every plumbable socket's residual fell from about 2.28 px to about 2.00 px -- 0.28 px -- where
lowering SOCKET_Z by 0.011 tiles moves the axis alone by 0.494 px. The silhouette's TOP followed
the full 0.52 px and its BOTTOM moved 0.03 px, which is what "the underside is cut" looks like from
outside. The gate itself reported no change at all, and that is the row threshold below rather than
a disagreement: it reads whole rows at alpha 8, so a quarter-pixel move is invisible to it.

Isolating the socket is the other half, and it takes two cuts rather than one. The COLUMNS are the
strip between the collision edge and the selection edge: the slab, the deck and the frame all stop
at the footprint, so the only thing standing out there is a socket stub. That strip is a column
range only when the socket runs left-to-right on screen, so each connection is measured on the
sheet where it does -- direction sheet 0 for an east or west connection, sheet "-e" for a north or
south one, which is the same machine with the camera turned a quarter (models/render.py turns the
rig by +90 degrees per direction). The ROWS are one tile either side of that connection's own
ground line, which is what keeps the two sockets on rf-heat-exchanger's short ends -- two tiles
apart, one plumbable and one not -- out of each other's measurement. Neither cut is redundant: a
part that a jitter walks a few hundredths of a tile past the footprint is caught by the row window
if it is caught at all, and the row window alone would hold most of the machine.

A silhouette touching the edge of that window is reported UNMEASURABLE rather than measured, since
its extent is then cut off and its midpoint is not the axis.

WHAT IT CANNOT SEE. Height, and only height. models/house-style.md binds a plumbable socket's
THICKNESS to the pipe's as well, and this does not check it: a thicker socket moves the reported
centre a little through the clipping above, but only a little, and in the same direction a raised
socket does -- so a verdict here says nothing about which. It also says nothing about whether a
socket is on the right EDGE of the machine; load-check's rendered-art gate holds the recorded
geometry against the live prototype, and that is what covers it.

IT NEEDS THE BASE GAME'S OWN SHEET, and since #355 that is a real dependency rather than a
convenience. The reference this compares against -- where vanilla draws its pipe -- is measured off
`base/graphics/entity/pipe/pipe-straight-horizontal.png` at run time instead of being carried as a
number, because the number it used to carry was half a pixel wrong and nothing could tell. So the
path is a required argument, scripts/load-check.ps1 passes it from the install it already resolved,
and a missing sheet is a failure with a message rather than a fall back to a typed value: there is
no typed value left to fall back to.

Needs pillow and numpy -- the only third-party Python any gate here requires. Run from the
repository root.
"""
import argparse
import json
import math
import os
import sys
import tempfile

try:
    import numpy as np
    from PIL import Image
except ImportError as missing:                    # a gate that cannot run must say why, not traceback
    sys.exit(f"check-socket-height: {missing}. This gate reads sprite pixels and needs both pillow "
             f"and numpy in the `python` on PATH -- `python -m pip install pillow numpy`. It is the "
             f"only third-party Python this repository's gates require.")

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "models"))
import rf_blender as rf  # noqa: E402  (no bpy at module level)

# A world height of 1 tile draws this many tiles up the screen -- 0.70804, taken from the camera the
# sheets were rendered through rather than copied as a number. NOTHING HERE DIVIDES BY IT: the
# header sets out why a drawn centre does not convert back into a world height at this socket
# height, and the one place that used to do it printed a figure 1.75x what the build script holds.
# It is MULTIPLIED by instead, in `constant_matches_reference` below, which is what makes the
# measured reference and rf_blender.SOCKET_Z one statement rather than two numbers that happened to
# agree. Until #356 they did not: 0.70804 x 0.044 is 0.0312 and the reference measures 0.0234, and
# nothing compared them. rf_blender imports no bpy since #354, so this file can import the constant
# the models are built at and hold it against what vanilla's own sheet says it should be.
SCREEN_PER_WORLD = 1.0 / math.tan(math.radians(rf.CAMERA_PITCH_DEG))

# HOW FAR THE CONSTANT AND THE MEASURED REFERENCE MAY PART, in SHEET PIXELS, before the cross-check
# fails. A quarter of a pixel, and both ends of that are deliberate.
#
# It cannot be equality. rf_blender.SOCKET_Z is written to three places -- 0.033 where the exact
# solution is 0.033102 -- so it lands 0.0046 px off the reference by rounding alone, and the
# reference itself is measured by row edges and so quantised to half a pixel.
#
# It has to be tighter than half a pixel, because the defect it exists to catch is exactly half a
# pixel: the old 0.031 reference was 2.0 px where the sheet draws 1.5, which put SOCKET_Z at 0.044
# and every plumbable socket 0.494 px too high. A quarter of a pixel fails that by a factor of two
# and passes today's constant by a factor of fifty.
CONSTANT_TOLERANCE_PX = 0.25

# WHERE A VANILLA PIPE DRAWS ITS BODY IS MEASURED, NOT TYPED (#355), and it used to be typed. The
# number here was 0.031 tiles, carried from a hand reading, and it was wrong by half a pixel in the
# permissive direction. The sheet's barrel runs rows 43..81 of 128; read by row CENTRES its midpoint
# is 62.5 and read by row EDGES it is also 62.5, which is 1.5 px above the image centre -- 0.023
# tiles. 0.031 is 2.0 px, and comes from averaging the bare row INDICES (43 + 81) / 2 = 62 against a
# centre of 64: the index convention on one side of a comparison and the edge convention on the
# other. The old comment disclosed the difference as a convention artefact and kept the number
# because it was what SOCKET_Z had been solved from, which is exactly how a mis-measurement outlives
# the person who made it.
#
# So the gate reads vanilla's own sheet, by `drawn_centre`'s own convention, and no one has to get a
# convention right twice.

# The colour floor that separates the drawn pipe from the shadow baked in underneath it. OURS HAVE
# NO BAKED SHADOW -- models/render.py writes structure and shadow to separate sheets -- so this
# asymmetry exists on vanilla's side only, and alpha cannot do the work: the shadow is opaque for
# most of its depth. Colour can, because the shadow is drawn BLACK. Measured on 2.0.77's
# pipe-straight-horizontal.png the dimmest row of pipe peaks at 40 of 255 and the brightest row of
# shadow at 8, so this sits in a five-fold gap rather than on a knife edge -- and
# `vanilla_pipe_centre` reports the gap it actually found, and refuses a sheet where it has closed.
PIPE_COLOUR_FLOOR = 24
# And the visibility floor the colour is read through. Alpha cannot separate pipe from shadow -- the
# shadow is opaque for most of its depth -- but it is still what says whether a pixel is drawn at
# all, and RGB under a transparent pixel is meaningless. 8 of 255 is the same floor `drawn_centre`
# reads our own silhouettes at, so both sides of the comparison call the same thing visible.
PIPE_ALPHA_FLOOR = 8
# How much clear air the floor must have on each side of it, as a fraction of the floor. Neither the
# dimmest row kept nor the brightest row dropped may come within this much of it. At 0.25 that is 30
# and 18, against a measured 40 and 8 -- so the check has room today and fails loudly on the day a
# sheet closes the gap, rather than quietly re-measuring a different set of rows.
PIPE_COLOUR_MARGIN = 0.25

# The sheets this reference may be measured off. Both are the same pipe seen along the screen's
# horizontal axis, which is the orientation ours are compared in, and both measure +0.023 -- the
# window variant differs only in the lighter panel down the barrel, which changes no extent. Any
# other sprite in that directory is a different object drawn at a different height.
VANILLA_PIPE_SHEETS = frozenset(("pipe-straight-horizontal.png", "pipe-straight-horizontal-window.png"))

# HOW FAR OFF IS TOO FAR. Not equality: both machines measure 0.031 tiles above vanilla's centre
# rather than on it, and that residual is GEOMETRIC -- the header's. The ground plane cuts the
# socket's underside at this height, so the midpoint rides high; it scales with the socket's radius,
# and the lit bevel and the anti-aliasing are worth a fraction of a pixel beside it.
#
# IT USED TO BE TWO THINGS, and #356 removed the second. SOCKET_Z had been solved from a reference
# read as 0.031 rather than the 0.0234 vanilla actually draws at, so every plumbable socket was
# built 0.011 tiles of world height too high. Correcting it moved the sub-pixel residual from 2.28
# px to 2.00 px rather than by the 0.49 px the axis alone moves -- the header says why -- and left
# what this gate reads where it was, because a quarter-pixel move does not cross a row. That is why
# the figure above did not change when the defect was fixed, and `constant_matches_reference` rather
# than this tolerance is now what holds the height honest.
#
# 0.08 tiles is five pixels on a sheet and two and a half at the game's own zoom. It admits the
# residual with room to spare and still catches the defect this exists for by a factor of four: a
# socket at z 0.55 clears the ground plane entirely and MEASURED 0.398 tiles up on the rendered
# sheet, which lands 0.375 from the reference. 0.707 x 0.55 = 0.389 is what the projection PREDICTS
# for it, and the two differ because a real sheet carries a bevel and a wash; the measured one is
# the one that says what this tolerance would have caught.
TOLERANCE = 0.08

# The outboard strip is inset by this many pixels at each end, because the collision edge column
# still holds the anti-aliased edge of the body and the far column the very end of the stub.
INSET_PX = 2

# Rows searched either side of a connection's ground line, in tiles. One tile holds a socket drawn
# anywhere from the floor to z 0.55 whole, and stops short of the next connection on the same wall:
# rf-heat-exchanger puts water and reactor energy two tiles apart on each short end.
WINDOW_TILES = 1.0


class Unmeasurable(Exception):
    """The sheet could not be read where the socket should be. A failure, not a pass: an instrument
    fault reported as a clean run is the shape every gate here is written against."""


def vanilla_pipe_centre(path):
    """How far above the ground line vanilla draws its horizontal pipe's body, in tiles.

    THE REFERENCE EVERY SOCKET HERE IS JUDGED AGAINST, read off the base game's own sheet so that
    both sides of the comparison are measured the same way by construction. `drawn_centre` reads our
    silhouette by row EDGES -- first row's top edge to last row's bottom edge -- and this reads
    vanilla's the same way. Getting a convention right once is the whole point of measuring it here
    rather than typing the answer.

    THE SHEET IS DIRECTLY COMPARABLE WITH OURS: the prototype draws it at scale 0.5 with no shift,
    so it is 64 px to the tile exactly as our sheets are, and its centre row is its ground line.

    WHAT IS EXCLUDED, AND WHY IT HAS TO BE. Vanilla bakes the pipe's shadow into the same sheet;
    ours are separate files. The shadow is opaque for most of its depth, so alpha cannot separate
    them -- but it is drawn black, and the pipe is not, so colour can. See PIPE_COLOUR_FLOOR.

    THE FLANGE TIPS ARE COUNTED AND IT DOES NOT MATTER. On 2.0.77 the drawn silhouette is rows
    37..87, whose midpoint is 62.5; the barrel alone -- the rows running the sprite's full width,
    43..81 -- has a midpoint of 62.5 as well, because the flanges are symmetric about it, six rows
    above and six below. Both readings give the same reference, so this does not rest on where a
    flange is judged to stop. The window variant of the same sprite measures 62.5 too.

    Raises Unmeasurable rather than guessing. A gate that cannot read its own reference must say so:
    reporting a pass it did not earn is the failure this whole file exists against.
    """
    # WHICH SPRITE, NOT JUST WHICH SIZE. Every pipe sprite in that directory is 128 square, and
    # several draw a ribbon this function would happily measure: the VERTICAL pipe measures +0.156
    # and the T-pieces and the cross measure something else again, all without complaint. Nothing in
    # the pixels tells them apart cheaply -- pipe-ending-left has the same row extents as the
    # straight horizontal -- so this checks the name, which is what a path typo gets wrong. It does
    # not defend against a renamed file, and nothing sensible would.
    if os.path.basename(path).lower() not in VANILLA_PIPE_SHEETS:
        raise Unmeasurable(f"{os.path.basename(path)} is not a straight horizontal pipe sheet; this "
                           f"reference is measured off one of: {', '.join(sorted(VANILLA_PIPE_SHEETS))}")
    if not os.path.exists(path):
        raise Unmeasurable(f"vanilla's pipe sheet is not at {path}")
    try:
        a = np.asarray(Image.open(path).convert("RGBA"))
    except OSError as why:
        raise Unmeasurable(f"{os.path.basename(path)} could not be read: {why}")
    height, width = a.shape[:2]
    # Two tiles square at our own pixels-per-tile is what the arithmetic below assumes. A sheet of
    # another size is a sprite this function was not written for, and mis-measuring it silently
    # would move every verdict in the run.
    if (height, width) != (2 * rf.PX_PER_TILE, 2 * rf.PX_PER_TILE):
        raise Unmeasurable(f"{os.path.basename(path)} is {width}x{height} px, where this measurement "
                           f"expects {2 * rf.PX_PER_TILE} square (two tiles at {rf.PX_PER_TILE} px)")

    # COLOUR ONLY WHERE SOMETHING IS DRAWN. A fully transparent pixel still carries RGB in a PNG,
    # and exporters leave whatever was in the buffer there -- vanilla's own pipe-straight-vertical
    # sheet has 255 under alpha 0. Reading the peak off raw RGB would let that padding decide both
    # the rule and the margin below: it reported `kept 255, dropped 255` on that sheet, which is a
    # false diagnosis in one direction and, on a sheet whose bright pixels happen to be invisible,
    # a false pass in the other.
    rgb_peak = np.where(a[..., 3] > PIPE_ALPHA_FLOOR, a[..., :3].max(axis=2), 0)
    drawn = rgb_peak > PIPE_COLOUR_FLOOR
    rows = np.nonzero(drawn.any(axis=1))[0]
    if len(rows) == 0:
        raise Unmeasurable(f"nothing but black is drawn in {os.path.basename(path)}, so the pipe "
                           f"cannot be told from the shadow baked under it")
    low, high = int(rows[0]), int(rows[-1])
    if high - low + 1 != len(rows):
        raise Unmeasurable(f"the pipe's rows in {os.path.basename(path)} are not contiguous "
                           f"({len(rows)} rows spanning {low}..{high}), so the colour floor has "
                           f"split the body instead of separating it from the shadow")

    # THE GAP THE COLOUR FLOOR SITS IN, asserted rather than trusted. If a future sheet darkens the
    # pipe or lightens the shadow until the two meet, the rows above stop being the pipe and the
    # reference moves silently -- which is the same class of defect this function was written to
    # end.
    # AND IT MUST BE SHAPED LIKE A PIPE LYING ACROSS THE SCREEN. The name check above catches a path
    # typo, which is the likely mistake; these catch a file that has been renamed or repacked, which
    # a name cannot. A straight horizontal pipe fills its tile edge to edge, so its widest drawn row
    # is exactly one tile -- and it is a RIBBON, so its whole silhouette is under a tile tall, where
    # anything with a vertical arm is half again as deep (pipe-cross and pipe-straight-vertical both
    # draw 84 rows against this sprite's 51).
    #
    # WHAT THE PAIR STILL DOES NOT CATCH, enumerated over all nineteen sprites in that directory
    # rather than guessed: three pass both shape checks. pipe-ending-left and pipe-ending-right draw
    # rows 37..87 exactly as this one does and measure the same +0.023, so a rename to either is
    # harmless. pipe-t-down is the one that matters -- 64 wide and 59 deep, but rows 37..95, which
    # measures -0.039 -- and only the name refuses it. Said rather than left to be discovered,
    # because a guard's gaps are the part a reader needs.
    widest = int(drawn.sum(axis=1).max())
    if widest != rf.PX_PER_TILE:
        raise Unmeasurable(f"{os.path.basename(path)} draws {widest} px across at its widest, not "
                           f"the {rf.PX_PER_TILE} a pipe running the width of its tile would. This "
                           f"is not the sprite this reference is measured off")
    if high - low + 1 > rf.PX_PER_TILE:
        raise Unmeasurable(f"{os.path.basename(path)} draws {high - low + 1} rows deep, more than "
                           f"the {rf.PX_PER_TILE} a pipe lying across the screen fits in. This "
                           f"sprite has something standing up it, so it is not the reference")

    dimmest_kept = int(rgb_peak[low:high + 1].max(axis=1).min())
    outside = np.concatenate([rgb_peak[:low], rgb_peak[high + 1:]])
    brightest_dropped = int(outside.max()) if outside.size else 0
    if (dimmest_kept < PIPE_COLOUR_FLOOR * (1 + PIPE_COLOUR_MARGIN)
            or brightest_dropped > PIPE_COLOUR_FLOOR * (1 - PIPE_COLOUR_MARGIN)):
        raise Unmeasurable(
            f"the colour floor of {PIPE_COLOUR_FLOOR} no longer separates {os.path.basename(path)}'s "
            f"pipe from its baked shadow: dimmest row kept peaks at {dimmest_kept}, brightest row "
            f"dropped at {brightest_dropped}. Re-measure the sheet before moving the floor")

    centre_row = (low + high + 1) / 2                 # row EDGES, the convention drawn_centre uses
    return (height / 2 - centre_row) / rf.PX_PER_TILE, (low, high, dimmest_kept, brightest_dropped)


def constant_matches_reference(reference, socket_z=None):
    """(ok, predicted, off_px) for rf_blender.SOCKET_Z against the measured reference.

    THE CHECK #354 MADE POSSIBLE AND #356 ADDED, and the one that would have caught the defect at
    its source. Every other measurement here reads a SHEET: it says where a socket was drawn, which
    only reports a wrong constant once a machine has been re-rendered with it. This reads the
    constant itself, so a build script pointed at a height vanilla does not draw at fails on the day
    the number changes rather than on the day someone renders.

    The relation is the projection, in the one direction it is sound: a socket built at world height
    z draws its axis SCREEN_PER_WORLD x z above the ground line, so the constant PREDICTS a drawn
    centre and that prediction must be the reference. The inverse is not sound at this height --
    the header's clipping -- which is why nothing here divides.

    `socket_z` is the constant to judge, defaulting to the one the models are built at. It is an
    argument so the self-test can hand it a wrong one and watch this fail.
    """
    z = rf.SOCKET_Z if socket_z is None else socket_z
    predicted = SCREEN_PER_WORLD * z
    off_px = (predicted - reference) * rf.PX_PER_TILE
    return abs(off_px) <= CONSTANT_TOLERANCE_PX, predicted, off_px


def report_constant(reference, socket_z=None):
    """Print the cross-check's line and return whether it holds."""
    z = rf.SOCKET_Z if socket_z is None else socket_z
    ok, predicted, off_px = constant_matches_reference(reference, z)
    print(f"  SOCKET_Z {z:<16.4f} predicts a centre {predicted:+.4f} tiles up against the pipe's "
          f"{reference:+.4f} ({off_px:+.3f} px out, tolerance {CONSTANT_TOLERANCE_PX} px): "
          f"{'ok' if ok else 'PARTED'}")
    return ok


def plumbable(connection):
    """True for a connection a player can put an ordinary pipe on. See the module header."""
    return not connection.get("connection_category")


def sheet_frame(manifest, connection):
    """(suffix, width_px, height_px) of the sheet this connection is measured on."""
    fr = manifest["frame"]
    tw, th = fr["tiles"]
    px_per_tile, margin = fr["pixels_per_tile"], fr["margin_tiles"]
    # A socket runs left-to-right on screen only on the sheets whose camera looks along its axis.
    # Sheet "" is the machine as declared; "-e" is the camera a quarter turn on, which lays a
    # north-south socket across the screen. Either would do of the two that work; the first is
    # taken so the choice is not a judgement.
    east_west = connection["direction"] in ("west", "east")
    suffix = "" if east_west else "-e"
    if suffix not in manifest["directions"]:
        raise Unmeasurable(f"the manifest records no '{suffix or 'north'}' sheet to measure it on")
    across, along = (tw, th) if east_west else (th, tw)
    return (suffix,
            int(round((across + 2 * margin) * px_per_tile)),
            int(round((along + 2 * margin) * px_per_tile)))


def socket_span(manifest, connection):
    """(low, high, ground) for a connection, in tiles on the sheet it is measured on.

    `low`..`high` is the OUTBOARD strip along the screen's horizontal axis: from the collision edge
    the machine's body stops at to the selection edge the socket stops at. `ground` is where that
    connection's ground line sits on the screen's vertical axis, in tiles above the sheet centre.
    """
    g = manifest["geometry"]
    (cx0, cy0), (cx1, cy1) = g["collision_box"]
    (sx0, sy0), (sx1, sy1) = g["selection_box"]
    px, py = connection["position"]
    d = connection["direction"]
    # Factorio's +y is south and Blender's is north, which is the flip both build scripts make at
    # their socket loop. On sheet "" the screen's horizontal axis is Blender x and its vertical is
    # Blender y; on "-e" the camera has turned a quarter, so horizontal is Blender y and vertical
    # is -Blender x.
    if d == "east":
        edge, collision, ground = sx1, cx1, -py
    elif d == "west":
        edge, collision, ground = sx0, cx0, -py
    elif d == "north":
        edge, collision, ground = -sy0, -cy0, -px
    elif d == "south":
        edge, collision, ground = -sy1, -cy1, -px
    else:
        raise Unmeasurable(f"unknown direction '{d}'")
    return min(edge, collision), max(edge, collision), ground


def drawn_centre(alpha, manifest, connection):
    """How far above its ground line a connection's socket is drawn, in tiles."""
    fr = manifest["frame"]
    px_per_tile = fr["pixels_per_tile"]
    _, w_px, h_px = sheet_frame(manifest, connection)
    if alpha.shape != (h_px, w_px):
        raise Unmeasurable(f"the sheet is {alpha.shape[1]}x{alpha.shape[0]} px where the manifest's "
                           f"frame says {w_px}x{h_px}")
    low, high, ground = socket_span(manifest, connection)
    col0 = int(round(w_px / 2 + low * px_per_tile)) + INSET_PX
    col1 = int(round(w_px / 2 + high * px_per_tile)) - INSET_PX
    if col1 - col0 < 1:
        raise Unmeasurable("the selection box is no wider than the collision box on that side, so "
                           "no part of the socket stands clear of the machine to be measured")
    ground_row = h_px / 2 - ground * px_per_tile
    row0 = int(round(ground_row - WINDOW_TILES * px_per_tile))
    row1 = int(round(ground_row + WINDOW_TILES * px_per_tile))
    if row0 < 0 or row1 > h_px:
        raise Unmeasurable("the search window falls outside the sheet")
    strip = alpha[row0:row1, col0:col1] > 8
    rows = np.nonzero(strip.any(axis=1))[0]
    if len(rows) == 0:
        raise Unmeasurable(f"nothing is drawn in columns {col0}..{col1} within a tile of the "
                           f"connection's ground line, so there is no stub there to measure")
    if rows[0] == 0 or rows[-1] == strip.shape[0] - 1:
        raise Unmeasurable("the stub reaches the edge of the search window, so its extent -- and "
                           "therefore its centre -- is cut off rather than measured")
    top, bottom = row0 + rows[0], row0 + rows[-1] + 1
    return (ground_row - (top + bottom) / 2) / px_per_tile


def check(manifest_path, sheets, rows):
    """Measure every plumbable connection one manifest records, appending a row per connection."""
    manifest = json.load(open(manifest_path, encoding="utf-8"))
    machine, geometry = manifest["machine"], manifest["geometry"]
    for connection in geometry["connections"]:
        if not plumbable(connection):
            continue
        label = f"{connection['direction']} {connection['fluid']}"
        try:
            suffix, _, _ = sheet_frame(manifest, connection)
            centre = drawn_centre(sheets(os.path.dirname(manifest_path), machine, suffix),
                                  manifest, connection)
        except Unmeasurable as why:
            rows.append((geometry["name"], label, None, str(why)))
            continue
        rows.append((geometry["name"], label, centre, None))
    return rows


def load_sheet(directory, machine, suffix):
    path = os.path.join(directory, f"{machine}{suffix}.png")
    if not os.path.exists(path):
        raise Unmeasurable(f"{os.path.basename(path)} is not there")
    return np.asarray(Image.open(path).convert("RGBA"))[..., 3]


def rolled_sheet(shift_px):
    """A sheet loader that lifts every sheet `shift_px` rows up the screen. The self-test's canary:
    the ground line is read off the manifest and does not move with it, so this is exactly a machine
    whose sockets were built too high."""
    def load(directory, machine, suffix):
        return np.roll(load_sheet(directory, machine, suffix), -shift_px, axis=0)
    return load


def report(rows, reference):
    """Print one line per measured connection; return each one's verdict, in the same order.

    `reference` is where vanilla draws its pipe, measured by `vanilla_pipe_centre` rather than
    typed. It is passed rather than read from module state so the self-test can hand it a
    deliberately wrong one and watch every verdict move, which is half one's third case."""
    verdicts = []
    for name, label, centre, why in rows:
        if why is not None:
            print(f"  {name:24s} {label:24s} UNMEASURABLE: {why}")
            verdicts.append("UNMEASURABLE")
            continue
        off = centre - reference
        verdict = "ok" if abs(off) <= TOLERANCE else "TOO HIGH" if off > 0 else "TOO LOW"
        # NO WORLD z IN THIS LINE, and its absence is deliberate. Dividing the drawn centre by
        # SCREEN_PER_WORLD used to be printed here as "world z", which read as the number the build
        # script should carry and is not: the clipping the header sets out puts it about 1.75x
        # rf_parts.SOCKET_Z, so the gate was quoting a height back at a reader who would then find
        # a different one in the source. Drawn tiles are what was measured and are all that is said.
        print(f"  {name:24s} {label:24s} drawn {centre:+.3f} tiles up against the pipe's "
              f"{reference:+.3f} ({off:+.3f} out, tolerance {TOLERANCE}): {verdict}")
        verdicts.append(verdict)
    return verdicts


def synthetic_pipe_sheet(top_row, rows_tall, shadow_rows):
    """A sheet with a coloured band and a black band under it, for the reference half below.

    The point is a sheet whose right answer is arithmetic rather than another measurement: a band
    starting at `top_row`, `rows_tall` deep, with `shadow_rows` of pure black beneath it at about
    the alpha vanilla bakes its own shadow at. Only the coloured band is the pipe, so the answer is
    that band's edge-midpoint and the black must not move it by a pixel.
    """
    side = 2 * rf.PX_PER_TILE
    # ONE TILE WIDE, CENTRED, because that is what a pipe sprite is and `vanilla_pipe_centre` now
    # insists on it. The first version of this helper filled the whole 128 and the shape guard threw
    # it out -- which is the guard working, and the reason to build the case properly rather than to
    # loosen the guard for a test.
    lo, hi = side // 4, side // 4 + rf.PX_PER_TILE
    a = np.zeros((side, side, 4), dtype=np.uint8)
    a[top_row:top_row + rows_tall, lo:hi, :3] = 90        # well clear of PIPE_COLOUR_FLOOR
    a[top_row:top_row + rows_tall, lo:hi, 3] = 255
    a[top_row + rows_tall:top_row + rows_tall + shadow_rows, lo:hi, :3] = 0
    a[top_row + rows_tall:top_row + rows_tall + shadow_rows, lo:hi, 3] = 170
    return a


def measured_from_array(a):
    """`vanilla_pipe_centre` over an array already in hand. It reads a path, not an array, because
    that is what a gate is given; the self-test writes its cases out and hands over the path so it
    exercises the same code the run does rather than a second copy of the arithmetic."""
    with tempfile.TemporaryDirectory(prefix="rf-pipe-") as scratch:
        path = os.path.join(scratch, "pipe-straight-horizontal.png")
        Image.fromarray(a, "RGBA").save(path)
        return vanilla_pipe_centre(path)[0]


def self_test(manifests, pipe_sheet):
    """Prove the check can fail, in every direction it can be wrong in, without a game or a render.

    HALF ONE is the REFERENCE, and it is first because the other two are read against it. Vanilla's
    sheet is rolled a known number of pixels down and then up, and the measured reference must
    follow by exactly that much each way: an instrument that does not move with its input is not
    measuring. Then two synthetic sheets whose answer is arithmetic prove the one judgement the
    measurement makes -- that the black baked underneath is excluded, and excluded whether there is
    none of it or a lot.

    HALF TWO: every plumbable socket on both machines as they stand must pass -- and then the same
    sheets, judged against a reference moved three tolerances each way, must fail every socket and
    fail it the right way round. That second part is not decoration. Measuring a reference correctly
    and JUDGING BY IT are different claims, and the first two attempts at this half proved only the
    first: every verdict here holds under the old wrong 0.031 as well as the measured 0.023, so a
    gate that quietly went on using a typed number would have passed its own self-test.

    HALF THREE: the same sheets lifted a quarter tile up the screen must be reported TOO HIGH on
    every one of them. A gate that only ever passes and a gate that only ever fails look the same
    from outside, so both are here.

    HALF FOUR is the CONSTANT, and it is last because it reads the reference half one measures and
    says nothing about the sheets halves two and three read. rf_blender.SOCKET_Z as it stands must
    agree with that reference, and three constants that do not must all be reported PARTED: the old
    0.044, which is the defect this cross-check exists for and the one thing here that is a real
    number rather than an offset, and the constant moved twice the tolerance each way.

    THE LIFT IS A QUARTER TILE RATHER THAN THE HALF THE REAL DEFECT WAS, and the reason is worth
    keeping: half a tile pushes a socket against the top of the search window, so the check reports
    it UNMEASURABLE -- a failure, and the right one, but it exercises the window guard instead of
    the comparison this gate is for. A quarter tile is three times the tolerance and still well
    inside the window, so the verdict comes from the measurement.
    """
    print("self-test 1/4: the reference must track vanilla's own sheet both ways, and must not be "
          "dragged by the shadow baked under it.")
    try:
        reference, (low, high, kept, dropped) = vanilla_pipe_centre(pipe_sheet)
    except Unmeasurable as why:
        print(f"FAILED - self-test: the reference could not be measured at all: {why}")
        return 1
    print(f"  vanilla pipe              rows {low}..{high} of {2 * rf.PX_PER_TILE}, centre "
          f"{reference:+.4f} tiles up (dimmest row kept peaks {kept}, brightest dropped {dropped}, "
          f"floor {PIPE_COLOUR_FLOOR})")

    original = np.asarray(Image.open(pipe_sheet).convert("RGBA"))
    for shift in (5, -5):
        # Rolling the sheet DOWN the screen by `shift` rows lowers the drawn centre by the same, so
        # the reference must fall by shift / PX_PER_TILE tiles. Both signs, because an instrument
        # that only tracks one way is half an instrument.
        want = reference - shift / rf.PX_PER_TILE
        got = measured_from_array(np.roll(original, shift, axis=0))
        print(f"  rolled {shift:+d} px                measured {got:+.4f}, expected {want:+.4f}")
        if abs(got - want) > 1e-9:
            print(f"FAILED - self-test: rolling vanilla's sheet {shift:+d} px moved the measured "
                  f"reference to {got:+.4f} where it should have been {want:+.4f}.")
            return 1

    # A band of known extent, with and without black under it. The right answer is the band's own
    # edge-midpoint both times; a shadow leaking into the measurement would drag the second down.
    top, tall = 40, 30
    want = (rf.PX_PER_TILE - (top + top + tall) / 2) / rf.PX_PER_TILE
    for shadow in (0, 20):
        got = measured_from_array(synthetic_pipe_sheet(top, tall, shadow))
        print(f"  synthetic, {shadow:2d} shadow rows   measured {got:+.4f}, expected {want:+.4f}")
        if abs(got - want) > 1e-9:
            print(f"FAILED - self-test: a band of {tall} rows from row {top} with {shadow} black "
                  f"rows under it measured {got:+.4f} where the band's own centre is {want:+.4f}, "
                  f"so the baked shadow is not being excluded.")
            return 1

    print("self-test 2/4: every plumbable socket on the shipped sheets must pass.")
    rows = []
    for path in manifests:
        check(path, load_sheet, rows)
    if not rows:
        print("FAILED - self-test: no plumbable connection was measured at all, so the halves "
              "after this one prove nothing.")
        return 1
    bad = [v for v in report(rows, reference) if v != "ok"]
    if bad:
        print(f"FAILED - self-test: {len(bad)} socket(s) failed on the sheets as they stand, so "
              "half three cannot tell a working check from a broken one.")
        return 1

    # AND THE REFERENCE MUST REACH THE VERDICTS, which measuring it correctly does not prove. This
    # gate spent months comparing against a number that was wrong, and a self-test that measures a
    # reference and then judges by something else would let exactly that happen again: the two
    # halves above and below pass under either 0.023 or the old 0.031, because 0.055 is within
    # tolerance of both and a lifted socket is TOO HIGH against both. So the same sheets are judged
    # against a reference moved three tolerances each way, and every verdict must follow it.
    print(f"self-test 2/4 (cont.): the same sheets judged against a reference {3 * TOLERANCE:+.2f} "
          f"and {-3 * TOLERANCE:+.2f} out must fail every socket, and fail it the right way.")
    for moved, expected in ((reference - 3 * TOLERANCE, "TOO HIGH"), (reference + 3 * TOLERANCE, "TOO LOW")):
        wrong = [(row, verdict) for row, verdict in zip(rows, report(rows, moved))
                 if verdict != expected]
        if wrong:
            print(f"FAILED - self-test: with the reference moved to {moved:+.3f}, "
                  f"{len(wrong)} socket(s) were not reported {expected}, so the number this gate "
                  f"measures is not the number it judges by:")
            for (name, label, _, _), verdict in wrong:
                print(f"           {name}  {label}: {verdict}")
            return 1

    shift = int(round(0.25 * rf.PX_PER_TILE))
    print(f"self-test 3/4: the same sheets lifted {shift} px must be reported TOO HIGH on every one.")
    lifted = []
    for path in manifests:
        check(path, rolled_sheet(shift), lifted)
    missed = [(row, verdict) for row, verdict in zip(lifted, report(lifted, reference))
              if verdict != "TOO HIGH"]
    if missed:
        print(f"FAILED - self-test: {len(missed)} socket(s) were lifted a quarter tile and this "
              "check did not report them as drawn too high:")
        for (name, label, _, _), verdict in missed:
            print(f"           {name}  {label}: {verdict}")
        return 1

    print("self-test 4/4: SOCKET_Z must agree with the measured reference, and must be reported "
          "PARTED when it does not.")
    if not report_constant(reference):
        print(f"FAILED - self-test: models/rf_blender.SOCKET_Z is {rf.SOCKET_Z}, which does not "
              f"predict the reference this run measured. The cross-check is working; the constant "
              f"is not.")
        return 1
    # 0.044 is the defect itself: SOCKET_Z solved against a reference read as 2.0 px where the
    # sheet draws 1.5. The two offsets either side of it prove the check is a comparison rather
    # than a hard-coded refusal of that one number -- THREE tolerances rather than two, because two
    # lands on 0.044 again and a case that prints the same constant twice proves half as much as it
    # appears to.
    off = (CONSTANT_TOLERANCE_PX * 3) / (rf.PX_PER_TILE * SCREEN_PER_WORLD)
    for wrong in (0.044, rf.SOCKET_Z + off, rf.SOCKET_Z - off):
        if report_constant(reference, wrong):
            print(f"FAILED - self-test: SOCKET_Z {wrong:.4f} was accepted against a reference of "
                  f"{reference:+.4f}, so this cross-check would not have caught the height being "
                  f"solved from the wrong number.")
            return 1
    print("self-test: all four halves pass.")
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("manifest", nargs="+", help="graphics/rendered/<machine>/manifest.json")
    ap.add_argument("--vanilla-pipe", required=True, metavar="PATH",
                    help="base/graphics/entity/pipe/pipe-straight-horizontal.png in the Factorio "
                         "install; the reference every socket is measured against")
    ap.add_argument("--self-test", action="store_true",
                    help="prove the check can fail, on the sheets as they stand")
    a = ap.parse_args(argv)

    if a.self_test:
        return self_test(a.manifest, a.vanilla_pipe)

    # THE REFERENCE IS MEASURED BEFORE ANYTHING IS JUDGED, and a reference that cannot be read is a
    # failure rather than a fallback. There is no typed number to fall back TO any more, which is
    # the point of #355 -- and a gate that quietly reverted to one would be reporting a pass it did
    # not earn, which is the shape this whole file is written against.
    try:
        reference, (low, high, kept, dropped) = vanilla_pipe_centre(a.vanilla_pipe)
    except Unmeasurable as why:
        print(f"FAILED - socket height: {why}.")
        print("         Nothing was judged. This gate measures our sockets against the height "
              "vanilla draws its own pipe at, and it reads that off the base game's sheet rather "
              "than carrying a number, so without the sheet there is no comparison to make.")
        return 1
    print(f"  vanilla pipe             drawn {reference:+.3f} tiles up, measured from "
          f"{os.path.basename(a.vanilla_pipe)} rows {low}..{high} "
          f"(dimmest row kept peaks {kept}, brightest dropped {dropped})")

    # THE CONSTANT FIRST, THE ART AFTER. They are two different failures with two different
    # remedies: a parted constant means every machine built from it is wrong and the fix is the
    # number, while a misdrawn socket on a sound constant means one machine's model is stale and the
    # fix is a render. Judging the sheets would answer neither question on its own.
    constant_ok = report_constant(reference)

    rows = []
    for path in a.manifest:
        check(path, load_sheet, rows)
    if not rows:
        print("FAILED - socket height: none of the manifests given records a connection a player "
              "can plumb, so this check found nothing to measure rather than finding nothing wrong.")
        return 1
    # TWO KINDS OF FAILURE AND TWO REMEDIES, the way load-check's rendered-art gate separates a moved
    # socket from a lost category. A measured socket in the wrong place is fixed by building it
    # somewhere else; a socket that could not be measured at all is an instrument fault, and telling
    # its reader to re-render would send them to change art that may be perfectly good.
    verdicts = report(rows, reference)
    misdrawn = [v for v in verdicts if v in ("TOO HIGH", "TOO LOW")]
    unreadable = [v for v in verdicts if v == "UNMEASURABLE"]
    if misdrawn:
        print(f"FAILED - socket height: {len(misdrawn)} socket(s) a player plumbs are not drawn "
              "where a vanilla pipe is.")
        print("         A pipe run into one of these meets the machine at a step. Build the socket "
              "at models/rf_blender.SOCKET_Z and re-render; a CONTAINED connection belongs at the "
              "machine's own height and should carry a connection_category instead.")
    if unreadable:
        print(f"FAILED - socket height: {len(unreadable)} socket(s) could not be measured at all, "
              "which is an instrument fault and not a finding about the art.")
        print("         The line above each says what was wrong. Nothing here says those sockets "
              "are drawn badly, and re-rendering is not the remedy until they can be read.")
    if not constant_ok:
        print(f"FAILED - socket height: models/rf_blender.SOCKET_Z predicts a drawn centre more "
              f"than {CONSTANT_TOLERANCE_PX} px from where vanilla draws its own pipe.")
        print("         Every machine built from it is drawn at the wrong height, whether or not "
              "the sheets above passed -- a sheet rendered before the constant moved still shows "
              "the old one. Solve SOCKET_Z against the measured reference on the line above, then "
              "re-render every machine with a plumbable socket.")
    if misdrawn or unreadable or not constant_ok:
        return 1
    print(f"socket height: all {len(rows)} player-facing socket(s) meet a vanilla pipe "
          f"(within {TOLERANCE} tiles of its measured {reference:+.3f}), and SOCKET_Z "
          f"{rf.SOCKET_Z} is solved from that same measurement.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

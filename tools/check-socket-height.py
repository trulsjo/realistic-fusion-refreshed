#!/usr/bin/env python3
"""Fail when a socket is drawn at a height a vanilla pipe would not meet.

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

EVERY SOCKET SINCE ADR 0036, AND THE REASON IS WEAKER THAN THE ONE IT REPLACED. This gate used
to skip a connection carrying a `connection_category` -- CONTAINED (ADR 0018, #86) -- on the
reasoning that it meets a machine FACE and never a pipe, so matching it to a pipe would be wrong.
That is still true of what a contained socket MEETS. It is no longer true of how one is DRAWN.

So the reason here is now a convention rather than an argument: EVERY socket is drawn to ONE
reference and that reference is vanilla's pipe. Nothing will ever plug into a contained one. What
the measurement buys is that a socket cannot drift -- `tools/check-socket-parts.py` pins each part
against the radius the MODEL recorded, which is internal consistency, so a contained socket left out
of this check could sit at any height with both gates passing. That is the hole #356 was written
about, one machine over.

`plumbable()` IS NO LONGER USED HERE AT ALL, and the import went with the filter. It remains the
discriminator for the rim and the flange pair -- but that is decided in models/rf_parts.py, which
DRAWS them. This file only measures pixels in a sheet somebody else rendered.

HOW THE MEASUREMENT WORKS, and why it needs no second camera model. models/rf_blender.py's rig is
orthographic at CAMERA_PITCH_DEG with the pixel aspect squaring the ground, so on every sheet one
ground tile is PX_PER_TILE pixels in both axes and a world height h draws 1/tan(pitch) = 0.707 h
above the ground line. A socket is a cylinder lying along a ground axis, so its silhouette is
symmetric about that axis and the MIDPOINT of its drawn extent is the axis, wherever the accent
band and the port rim put the extremes.

THAT SYMMETRY HELD ONLY WHILE THE WHOLE SILHOUETTE WAS ABOVE THE GROUND PLANE, AND AT PIPE HEIGHT
IT WAS NOT. `rf_blender.build_rig` puts a shadow-catching ground plane at z 0, and a socket drawn at
SOCKET_Z reaches well below it -- radius 0.249 about its axis at 0.033 -- so its underside was cut
off and the midpoint rode high. That was an assertion here until 2026-09-16, when #366 and #367
measured it: a machine rendered with the plane deleted puts every part's underside back to the
pixel, and thirty-six bare cylinders across six radii and six heights agree with a model of the
plane that has no fitted parameter in it. A shadow catcher is transparent in the beauty pass but NOT
to what is behind it, which was the half of the claim nobody had checked.

SINCE ADR 0035 NOTHING IS CUT, and this gate's residual went with it. models/render.py renders the
structure on a view layer that marks the ground plane INDIRECT ONLY, so the plane lights a machine
and no longer stands in front of it; the shadow comes off a second layer where it still catches.
Every plumbable socket on both machines now reads +0.000 against vanilla's pipe where it read +0.031
before, which is what docs/research/socket-underside-cut.md predicted from the geometry without
being shown it -- 0.70804 x 0.033 = +0.02337 tiles against the +0.02337 this gate measures off
vanilla's own sheet.

THE CLIPPING PARAGRAPHS BELOW ARE KEPT BECAUSE THE ARITHMETIC IS STILL THE REASON THIS GATE IS
SHAPED AS IT IS, and because a socket could be put back under a plane by a rig change. What is no
longer true is that it bites: a drawn centre and a world height now agree to a thousandth.
tools/check-socket-parts.py is the gate that would catch it coming back, part by part, where this
one measures only the envelope and moved by a quarter of its tolerance when the cut was at its worst.

SO THIS COMPARES TWO DRAWN CENTRES AND DOES NOT RECOVER A WORLD HEIGHT. It measures where our
socket is drawn, against where a vanilla pipe's body is drawn, and both sides are numbers off a
sheet. That is the right comparison anyway -- vanilla's pipe is a stylised ribbon and not a
projected cylinder, so there is no world z to recover on its side either -- but it means the
residual below is geometric rather than incidental, and that it scales with the socket's RADIUS.
Both machines draw a plumbable socket at 0.249 (models/house-style.md), so both carry the same one;
a machine that drew one thicker would carry more.

AND THE RESIDUAL WAS NOT INDEPENDENT OF THE HEIGHT, which #356 assumed it was. While the plane cut,
lowering the socket lowered the axis but also pushed more of the tube under the cut, so the two
moved against each other. Measured on both machines either side of that change, with a sub-pixel
read of the same strip: every plumbable socket's residual fell from about 2.28 px to about 2.00 px
-- 0.28 px -- where lowering SOCKET_Z by 0.011 tiles moves the axis alone by 0.494 px. The
silhouette's TOP followed the full 0.52 px and its BOTTOM moved 0.03 px, which is what "the
underside is cut" looked like from outside. The gate itself reported no change at all, and that is
the row threshold below rather than a disagreement: it reads whole rows at alpha 8, so a
quarter-pixel move is invisible to it. With the cut gone the two are independent again, and both
residuals are zero.

Isolating the socket is the other half, and since #365 it is tools/socket_strip.py's rather than
this file's: two cuts, one in columns and one in rows, shared with tools/measure-socket-parts.py so
that the gate and the instrument cannot come to disagree about where a socket is drawn. That
module's header says what each cut is for and why neither is redundant. What is left here is the
ENVELOPE question it is asked -- the midpoint of everything standing clear of the body, since a
pipe meets the whole silhouette and not one piece of it.

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

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "models"))
import rf_blender as rf  # noqa: E402  (no bpy at module level)
import socket_strip  # noqa: E402

# WHERE THE STRIP ARITHMETIC LIVES, and it is no longer here. Which columns hold a socket, which
# rows belong to its connection, what counts as drawn and when a silhouette is cut off by its own
# window are all tools/socket_strip.py's, shared with tools/measure-socket-parts.py (#365). That
# tool asks a different question -- one piece of a socket at a time rather than the envelope this
# gate measures -- off the same two cuts, and two copies of them would drift the way
# models/rf_parts.py's header records two copies of the mesh helpers drifting inside a week.
Unmeasurable = socket_strip.Unmeasurable

# A world height of 1 tile draws this many tiles up the screen -- 0.70804, taken from the camera the
# sheets were rendered through rather than copied as a number. NOTHING HERE DIVIDES BY IT: the
# header sets out why a drawn centre does not convert back into a world height at this socket
# height, and the one place that used to do it printed a figure 1.75x what the build script holds.
# It is MULTIPLIED by instead, in `constant_matches_reference` below, which is what makes the
# measured reference and rf_blender.SOCKET_Z one statement rather than two numbers that happened to
# agree. Until #356 they did not: 0.70804 x 0.044 is 0.0312 and the reference measures 0.0234, and
# nothing compared them. rf_blender imports no bpy since #354, so this file can import the constant
# the models are built at and hold it against what vanilla's own sheet says it should be.
SCREEN_PER_WORLD = socket_strip.SCREEN_PER_WORLD

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
# all, and RGB under a transparent pixel is meaningless. It is socket_strip.ALPHA_FLOOR itself,
# which is the floor our own silhouettes are read at, so both sides of the comparison call the same
# thing visible by construction rather than by two numbers agreeing.
PIPE_ALPHA_FLOOR = socket_strip.ALPHA_FLOOR
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

# HOW FAR OFF IS TOO FAR. Both machines now measure 0.000 tiles off vanilla's centre, so the
# tolerance is no longer admitting a residual -- it is headroom against the row threshold and the
# bevel, and nothing else.
#
# IT WAS 0.031 TILES UNTIL ADR 0035, AND THAT RESIDUAL WAS GEOMETRIC. The ground plane cut a
# socket's underside at this height, so the envelope's midpoint rode high by an amount that scaled
# with the socket's radius. #366 and #367 showed it was exactly what the geometry predicts -- the
# widest part is the dark rim at radius 0.379, drawn centre +0.05509 tiles against vanilla's
# +0.02337, a residual of 0.0317 tiles or 2.030 px, with nothing fitted -- and #373 then took the
# cut away rather than living with it. THE PREDICTION WAS TESTED BY THE FIX: with nothing cut the
# model says the centre is 0.70804 x 0.033 = +0.02337, and re-rendering both machines measured
# +0.023 on every plumbable socket. docs/research/socket-underside-cut.md carries the arithmetic.
#
# IT USED TO BE TWO THINGS, and #356 removed the second. SOCKET_Z had been solved from a reference
# read as 0.031 rather than the 0.0234 vanilla actually draws at, so every plumbable socket was
# built 0.011 tiles of world height too high. Correcting it moved the sub-pixel residual from 2.28
# px to 2.00 px rather than by the 0.49 px the axis alone moves -- the header says why -- and left
# what this gate reads where it was, because a quarter-pixel move does not cross a row. That is why
# the figure above did not change when the defect was fixed, and `constant_matches_reference` rather
# than this tolerance is what holds the height honest. ADR 0035 then removed the first, so the
# residual this paragraph is about is now zero; the paragraph stays because the reason a quarter-
# pixel move is invisible here has not changed.
#
# 0.08 tiles is five pixels on a sheet and two and a half at the game's own zoom. It admits the
# residual with room to spare and still catches the defect this exists for by a factor of four: a
# socket at z 0.55 clears the ground plane entirely and MEASURED 0.398 tiles up on the rendered
# sheet, which lands 0.375 from the reference. 0.707 x 0.55 = 0.389 is what the projection PREDICTS
# for it, and the two differ because a real sheet carries a bevel and a wash; the measured one is
# the one that says what this tolerance would have caught.
TOLERANCE = 0.08


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


def drawn_centre(alpha, manifest, connection):
    """How far above its ground line a connection's socket is drawn, in tiles.

    THE ENVELOPE, not one piece of the socket: the midpoint of everything standing clear of the
    body, because a pipe meets the whole silhouette. tools/measure-socket-parts.py is the tool that
    takes the same strip apart rim by rib; the two share tools/socket_strip.py and differ only in
    what they ask it.
    """
    s = socket_strip.strip(alpha, manifest, connection)
    top, bottom = s.extent()
    return (s.ground_row - (top + bottom) / 2) / s.px_per_tile


def check(manifest_path, sheets, rows):
    """Measure EVERY connection one manifest records, appending a row per connection.

    Contained ones included, since ADR 0036. The filter that used to stand here skipped them on the
    reasoning that a contained connection meets a machine face and matching it to a pipe would be
    wrong -- true of what it MEETS, and no longer true of how it is DRAWN. One reference draws every
    socket now, and that reference is vanilla's pipe, so a socket left out of this measurement is a
    socket that can drift to any height with nothing complaining.
    """
    manifest = json.load(open(manifest_path, encoding="utf-8"))
    machine, geometry = manifest["machine"], manifest["geometry"]
    for connection in geometry["connections"]:
        label = f"{connection['direction']} {connection['fluid']}"
        try:
            suffix, _, _ = socket_strip.sheet_frame(manifest, connection)
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
    deliberately wrong one and watch every verdict move, which the judged-by-the-reference half
    does."""
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


class SelfTestFailed(Exception):
    """Why a half failed, in that half's own words.

    Raised rather than returned so a half reads as a straight line of checks instead of a chain of
    `return 1`s that every caller has to remember to propagate."""


def run_halves(halves):
    """Run declared halves in order, numbering them from the list itself.

    The total is `len(halves)`, so it is written once instead of once per label. That is the whole
    point: this file printed "1/4" through "4/4" across five lines, one of them a "(cont.)"
    continuation, so adding a fifth check edited all of them.

    A half returns what it proved, and returning nothing is a failure rather than a pass -- "the
    body never ran" and "the body ran and proved nothing" are the same silence from outside.

    The PowerShell gates run their halves through Invoke-SelfTestHalves in scripts/factorio-lib.ps1,
    which is the same idea and shares no code with this. Two files in a second language is not
    enough to justify a library between them.
    """
    total = len(halves)
    for ordinal, (name, body) in enumerate(halves, 1):
        try:
            proved = body()
        except SelfTestFailed as why:
            print(f"FAILED - self-test half '{name}': {why}")
            return 1
        if not proved:
            print(f"FAILED - self-test half '{name}': it returned nothing, so there is no evidence "
                  "it ran. A half returns one line saying what it proved.")
            return 1
        print(f"self-test {ordinal}/{total}: {proved}")
    return 0


def self_test(manifests, pipe_sheet):
    """Prove the check can fail, in every direction it can be wrong in, without a game or a render.

    THE REFERENCE half is first because every half after it is read against it. Vanilla's sheet is
    rolled a known number of pixels down and then up, and the measured reference must follow by
    exactly that much each way: an instrument that does not move with its input is not measuring.
    Then two synthetic sheets whose answer is arithmetic prove the one judgement the measurement
    makes -- that the black baked underneath is excluded, and excluded whether there is none of it
    or a lot.

    THE SHIPPED SHEETS half: every socket on both machines as they stand must pass -- contained
    ones included since ADR 0036, because this half runs the same `check` the gate does and that one
    stopped filtering.

    THE JUDGED-BY-THE-REFERENCE half is not decoration, and it was a "(cont.)" line under the half
    above until the halves were named. Measuring a reference correctly and JUDGING BY IT are
    different claims, and the first two attempts proved only the first: every verdict in the halves
    either side holds under the old wrong 0.031 as well as the measured 0.023, so a gate that
    quietly went on using a typed number would have passed its own self-test. So the same sheets are
    judged against a reference moved three tolerances each way, and every verdict must follow it.

    THE LIFTED SHEETS half: the same sheets lifted a quarter tile up the screen must be reported
    TOO HIGH on every one of them. A gate that only ever passes and a gate that only ever fails look
    the same from outside, so both are here.

    THE SOCKET_Z half is the CONSTANT, and it is last because it reads the reference the first half
    measures and says nothing about the sheets the two before it read. rf_blender.SOCKET_Z as it
    stands must agree with that reference, and three constants that do not must all be reported
    PARTED: the old 0.044, which is the defect this cross-check exists for and the one thing here
    that is a real number rather than an offset, and the constant moved three tolerances each way --
    three rather than two because two lands back on 0.044; the code below says so where it computes
    the offset.

    THE LIFT IS A QUARTER TILE RATHER THAN THE HALF THE REAL DEFECT WAS, and the reason is worth
    keeping: half a tile pushes a socket against the top of the search window, so the check reports
    it UNMEASURABLE -- a failure, and the right one, but it exercises the window guard instead of
    the comparison this gate is for. A quarter tile is three times the tolerance and still well
    inside the window, so the verdict comes from the measurement.
    """
    # What the reference half measures and the halves below judge by. They are filled by the halves
    # that produce them rather than declared with values, so a half that did not run leaves its
    # successors with nothing to read instead of with a stale number.
    measured = {}
    rows = []

    def reference_half():
        try:
            reference, (low, high, kept, dropped) = vanilla_pipe_centre(pipe_sheet)
        except Unmeasurable as why:
            raise SelfTestFailed(f"the reference could not be measured at all: {why}")
        measured["reference"] = reference
        print(f"  vanilla pipe              rows {low}..{high} of {2 * rf.PX_PER_TILE}, centre "
              f"{reference:+.4f} tiles up (dimmest row kept peaks {kept}, brightest dropped "
              f"{dropped}, floor {PIPE_COLOUR_FLOOR})")

        original = np.asarray(Image.open(pipe_sheet).convert("RGBA"))
        for shift in (5, -5):
            # Rolling the sheet DOWN the screen by `shift` rows lowers the drawn centre by the same,
            # so the reference must fall by shift / PX_PER_TILE tiles. Both signs, because an
            # instrument that only tracks one way is half an instrument.
            want = reference - shift / rf.PX_PER_TILE
            got = measured_from_array(np.roll(original, shift, axis=0))
            print(f"  rolled {shift:+d} px                measured {got:+.4f}, expected {want:+.4f}")
            if abs(got - want) > 1e-9:
                raise SelfTestFailed(f"rolling vanilla's sheet {shift:+d} px moved the measured "
                                     f"reference to {got:+.4f} where it should have been "
                                     f"{want:+.4f}.")

        # A band of known extent, with and without black under it. The right answer is the band's own
        # edge-midpoint both times; a shadow leaking into the measurement would drag the second down.
        top, tall = 40, 30
        want = (rf.PX_PER_TILE - (top + top + tall) / 2) / rf.PX_PER_TILE
        for shadow in (0, 20):
            got = measured_from_array(synthetic_pipe_sheet(top, tall, shadow))
            print(f"  synthetic, {shadow:2d} shadow rows   measured {got:+.4f}, expected {want:+.4f}")
            if abs(got - want) > 1e-9:
                raise SelfTestFailed(f"a band of {tall} rows from row {top} with {shadow} black rows "
                                     f"under it measured {got:+.4f} where the band's own centre is "
                                     f"{want:+.4f}, so the baked shadow is not being excluded.")
        return ("the reference tracks vanilla's own sheet both ways, and is not dragged by the "
                "shadow baked under it.")

    def shipped_sheets_half():
        for path in manifests:
            check(path, load_sheet, rows)
        if not rows:
            raise SelfTestFailed("no connection was measured at all, so the halves after this one "
                                 "prove nothing.")
        bad = [v for v in report(rows, measured["reference"]) if v != "ok"]
        if bad:
            raise SelfTestFailed(f"{len(bad)} socket(s) failed on the sheets as they stand, so the "
                                 "lifted-sheets half cannot tell a working check from a broken one.")
        return "every socket on the shipped sheets passes, contained ones included."

    def judged_by_the_reference_half():
        # `rows` is what the shipped-sheets half left behind, and a zip over an empty list produces
        # an empty list of wrong verdicts -- which reads exactly like every verdict following the
        # reference. Reordering the declaration list at the bottom would otherwise leave this half
        # reporting that the gate judges by the number it measured, having judged nothing.
        if not rows:
            raise SelfTestFailed("no socket was measured before this half ran, so it would judge an "
                                 "empty report and pass. It reads what the shipped-sheets half "
                                 "leaves behind, and that half has to run first.")
        reference = measured["reference"]
        for moved, expected in ((reference - 3 * TOLERANCE, "TOO HIGH"),
                                (reference + 3 * TOLERANCE, "TOO LOW")):
            wrong = [(row, verdict) for row, verdict in zip(rows, report(rows, moved))
                     if verdict != expected]
            if wrong:
                for (name, label, _, _), verdict in wrong:
                    print(f"           {name}  {label}: {verdict}")
                raise SelfTestFailed(f"with the reference moved to {moved:+.3f}, {len(wrong)} "
                                     f"socket(s) were not reported {expected}, so the number this "
                                     "gate measures is not the number it judges by.")
        return (f"the same sheets judged against a reference {3 * TOLERANCE:+.2f} and "
                f"{-3 * TOLERANCE:+.2f} out fail every socket, and fail it the right way.")

    def lifted_sheets_half():
        shift = int(round(0.25 * rf.PX_PER_TILE))
        lifted = []
        for path in manifests:
            check(path, rolled_sheet(shift), lifted)
        if not lifted:
            raise SelfTestFailed(f"lifting the sheets {shift} px measured no socket at all, so "
                                 "reporting none of them too high proves nothing.")
        missed = [(row, verdict) for row, verdict in zip(lifted, report(lifted, measured["reference"]))
                  if verdict != "TOO HIGH"]
        if missed:
            for (name, label, _, _), verdict in missed:
                print(f"           {name}  {label}: {verdict}")
            raise SelfTestFailed(f"{len(missed)} socket(s) were lifted a quarter tile and this check "
                                 "did not report them as drawn too high.")
        return f"the same sheets lifted {shift} px are reported TOO HIGH on every one."

    def socket_z_half():
        reference = measured["reference"]
        if not report_constant(reference):
            raise SelfTestFailed(f"models/rf_blender.SOCKET_Z is {rf.SOCKET_Z}, which does not "
                                 "predict the reference this run measured. The cross-check is "
                                 "working; the constant is not.")
        # 0.044 is the defect itself: SOCKET_Z solved against a reference read as 2.0 px where the
        # sheet draws 1.5. The two offsets either side of it prove the check is a comparison rather
        # than a hard-coded refusal of that one number -- THREE tolerances rather than two, because
        # two lands on 0.044 again and a case that prints the same constant twice proves half as
        # much as it appears to.
        off = (CONSTANT_TOLERANCE_PX * 3) / (rf.PX_PER_TILE * SCREEN_PER_WORLD)
        for wrong in (0.044, rf.SOCKET_Z + off, rf.SOCKET_Z - off):
            if report_constant(reference, wrong):
                raise SelfTestFailed(f"SOCKET_Z {wrong:.4f} was accepted against a reference of "
                                     f"{reference:+.4f}, so this cross-check would not have caught "
                                     "the height being solved from the wrong number.")
        return ("SOCKET_Z agrees with the measured reference, and three constants that do not are "
                "reported PARTED.")

    return run_halves([
        ("reference", reference_half),
        ("shipped-sheets", shipped_sheets_half),
        ("judged-by-the-reference", judged_by_the_reference_half),
        ("lifted-sheets", lifted_sheets_half),
        ("socket-z", socket_z_half),
    ])


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
        print("FAILED - socket height: none of the manifests given records a connection at all, "
              "so this check found nothing to measure rather than finding nothing wrong.")
        return 1
    # TWO KINDS OF FAILURE AND TWO REMEDIES, the way load-check's rendered-art gate separates a moved
    # socket from a lost category. A measured socket in the wrong place is fixed by building it
    # somewhere else; a socket that could not be measured at all is an instrument fault, and telling
    # its reader to re-render would send them to change art that may be perfectly good.
    verdicts = report(rows, reference)
    misdrawn = [v for v in verdicts if v in ("TOO HIGH", "TOO LOW")]
    unreadable = [v for v in verdicts if v == "UNMEASURABLE"]
    if misdrawn:
        print(f"FAILED - socket height: {len(misdrawn)} socket(s) are not drawn where a vanilla "
              "pipe is.")
        print("         Build the socket at models/rf_blender.SOCKET_Z and re-render. On a socket a "
              "player plumbs, a pipe run into it meets the machine at a step; on a CONTAINED one "
              "nothing will ever meet it, and since ADR 0036 it is held to the same height anyway, "
              "because one reference for every socket is what stops any of them drifting.")
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
              "re-render every machine that has a socket.")
    if misdrawn or unreadable or not constant_ok:
        return 1
    print(f"socket height: all {len(rows)} socket(s), contained ones included, are drawn where a "
          f"vanilla pipe is (within {TOLERANCE} tiles of its measured {reference:+.3f}), and "
          f"SOCKET_Z {rf.SOCKET_Z} is solved from that same measurement.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

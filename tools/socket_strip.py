"""The strip of sheet a socket is drawn in: which columns, which rows, and what is drawn there.

    import socket_strip as strip
    s = strip.strip(alpha, manifest, connection)      # raises strip.Unmeasurable, never guesses
    top, bottom = s.extent()                          # row EDGES, the whole outboard silhouette
    top, bottom = s.extent(198, 201)                  # or through a narrower column window
    above, below, why = s.measure(axis, 198, 201)     # about an axis, with the window guarded

ONE COPY, SHARED BY A GATE, AN INSTRUMENT AND A PROBE, and the sharing is the point (#365, #367).
tools/check-socket-height.py asks the ENVELOPE question -- where is the midpoint of everything
standing clear of the body -- because a pipe meets a socket's whole silhouette and not one piece of
it. tools/measure-socket-parts.py asks a narrower one, a piece at a time through a window it has
worked out. scripts/probe-socket-underside.py asks the same narrow one of a bare cylinder on a scene
built to be measured. Those are different questions off the same arithmetic: the same two cuts
isolate the socket, the same alpha floor says what is drawn, and the same guard refuses a silhouette
that touches the edge of its window. A second copy of that would disagree with the first, which is
what models/rf_parts.py's own header records happening inside a week (#340).

THE TWO CUTS, and why neither is redundant. The COLUMNS are the outboard strip between the
collision edge and the selection edge: the slab, the deck and the frame all stop at the footprint,
so the only thing standing out there is a socket stub. That strip is a column range only when the
socket runs left-to-right on screen, so each connection is measured on the sheet where it does --
direction sheet "" for an east or west connection, "-e" for a north or south one, which is the same
machine with the camera turned a quarter (models/render.py turns the rig by +90 degrees per
direction). The ROWS are one tile either side of that connection's own ground line, which keeps two
sockets on the same wall out of each other's measurement: rf-heat-exchanger puts water and reactor
energy two tiles apart on each short end. A part that a jitter walks a few hundredths of a tile
past the footprint is caught by the row window if it is caught at all, and the row window alone
would hold most of the machine.

THE TWO CALLERS TRIM THE ENDS DIFFERENTLY, AND THEY HAVE TO. The envelope measurement insets both
ends by INSET_PX, a round two pixels: the collision edge column still holds the anti-aliased edge
of the body, and the column at the far end holds the very end of the stub seen edge-on. A per-part
window cannot use that, on either end. A socket's DARK RIM stands 0.02 tiles OUTBOARD of the
footprint edge, so the far inset cuts into the rim itself -- two of its four columns on the shipped
sheets -- and two pixels at the body end drop a column of accent band that is drawn cleanly. Each
leaves a window too short for the narrowing check to say anything, so a part drawn correctly would
be reported unstable. So `columns_of` works from the one thing that actually smears an edge -- the
renderer's reconstruction filter, FILTER_HALF_PX below -- and applies it at every boundary rather
than at the two ends alone.

THE TWO ARE NOT INDEPENDENT, AND SAYING SO IS THE POINT OF THIS SENTENCE. `extent` refuses any
window that reaches within FILTER_HALF_PX of the collision edge, the envelope's included, so the
envelope survives only because INSET_PX is at least FILTER_HALF_PX + 1 -- two against 1.75. Drop
INSET_PX to one and every socket the gate measures becomes UNMEASURABLE. That is a loud failure
rather than a quiet wrong answer, which is the right way round, but it is a coupling and not a
coincidence: the two numbers are trims at the same edge and the wider one has to be the envelope's.

WHAT IS NOT HERE: the reference a gate judges against, the parts an instrument names, and the model
a probe holds a reading against. Each caller keeps its own, because all three are judgements about
what a measurement MEANS rather than arithmetic about where it is read. `measure`'s window guard is
here rather than with them because it is the second kind: it says whether a reading can be believed,
not what it implies.

Needs numpy, which every caller already does. Run from the repository root.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "models"))
import rf_blender as rf  # noqa: E402  (no bpy at module level)

# A world height of 1 tile draws this many tiles up the screen -- 0.70804, taken from the camera the
# sheets were rendered through rather than copied as a number. NOTHING HERE DIVIDES BY IT:
# tools/check-socket-height.py's header sets out why a drawn centre does not convert back into a
# world height at this socket height.
SCREEN_PER_WORLD = 1.0 / math.tan(math.radians(rf.CAMERA_PITCH_DEG))

# WHAT AN UNCUT CYLINDER OF RADIUS 1 WOULD DRAW EITHER SIDE OF ITS OWN AXIS, in tiles. A cylinder
# lying along a ground axis has a circular cross-section in the plane across it, and this camera
# draws a point (y, z) of that plane at y + SCREEN_PER_WORLD * z up the screen; the largest that
# gets on y^2 + z^2 = r^2 is r * sqrt(1 + cot^2 pitch) = r / sin(pitch). So the silhouette is
# 2.451 r tall and symmetric about the axis -- WHILE THE WHOLE OF IT IS DRAWN, which at SOCKET_Z it
# is not, and the difference is the measurement tools/measure-socket-parts.py exists to take.
#
# 2.451 AND models/house-style.md's 2.449 ARE THE SAME QUANTITY, a rounding apart, and neither is
# wrong. CAMERA_PITCH_DEG is 54.7; the angle it is rounded from is arctan(sqrt 2) = 54.7356, where
# 2 / sin is exactly sqrt 6 = 2.4495. This takes the constant the sheets were actually rendered
# through, so it says 2.451. The two factors part by 0.0011, which over the dark rim's radius of
# 0.379 is 0.026 px of drawn height -- a fortieth of a pixel, and why the difference has never
# reached a decision either way.
#
# It is numerically rf_blender.STRETCH, the camera's pixel aspect, and it comes out of the same
# projection -- but it answers a different question, so it is derived here rather than borrowed
# from a constant that means "how the ground is squared up".
UNCUT_PER_RADIUS = 1.0 / math.sin(math.radians(rf.CAMERA_PITCH_DEG))

# The alpha a pixel counts as drawn at, out of 255. Both callers read our silhouettes through it,
# and tools/check-socket-height.py reads vanilla's sheet through the same number so that both sides
# of its comparison call the same thing visible.
ALPHA_FLOOR = 8

# The outboard strip is inset by this many pixels at each end for the envelope measurement. See the
# header on why a per-part window uses FILTER_HALF_PX instead.
INSET_PX = 2

# HOW FAR A DRAWN EDGE SPREADS PAST THE GEOMETRY THAT CAST IT, in sheet pixels either way. Cycles
# reconstructs each pixel through a filter 1.5 px wide by default and models/render.py sets no other
# one, so an edge at x reaches the pixels covering x +/- 0.75. A column touched by that spread draws
# both of the parts the edge divides, so it belongs to neither window.
#
# IT IS CONFIRMED BY THE SHEETS RATHER THAN TAKEN ON TRUST, on two boundaries of the same socket.
# On rf-isotope-collector's west socket the flange rib ends and the accent band begins at column
# 202.88, so column 203 starts 0.12 px past that boundary -- and column 203 reads a whole pixel
# taller than the rest of the band, which is the rib leaking into it. The dark rim ends and the ribs
# begin at column 197.12, so column 198 starts 0.88 px past THAT boundary -- and column 198 reads
# exactly what the rest of the ribs do, with the much wider rim right beside it. 0.75 falls between
# 0.12 and 0.88, which is the sheets saying how far the smear reaches rather than the default being
# taken on trust.
FILTER_HALF_PX = 0.75

# Rows searched either side of a connection's ground line, in tiles. One tile holds a socket drawn
# anywhere from the floor to z 0.55 whole, and stops short of the next connection on the same wall.
WINDOW_TILES = 1.0


class Unmeasurable(Exception):
    """The sheet could not be read where the socket should be. A failure, not a pass: an instrument
    fault reported as a clean run is the shape every gate here is written against."""


def clear_of(edge, step, inward):
    """The first whole sheet column on one side of a fractional boundary that the renderer's filter
    does not smear across, walking in `step` -- +1 towards the right of the sheet, -1 towards the
    left. `inward` is True for the column just past the boundary in the direction of travel, False
    for the last one before it.

    THE ONE COPY OF THE ARITHMETIC THREE CALLERS NEED. `Strip.reach` and `Strip.columns_of` below
    are both written on it, and so is tools/measure-accent-separation.py, which has to clear a
    boundary neither of them exposes -- the accent band's own back edge, inboard of the collision
    edge where `reach` refuses to go. That bench kept a fourth copy until the review of #379, and
    the copy had already drifted: it floored the far end where the two here subtract one, so the
    column straddling the smear fell inside its window. This module's header is about exactly that,
    and #340 is where the same thing last cost something.

    WHY THE FAR SIDE SUBTRACTS ONE AND THE NEAR SIDE DOES NOT. A column j covers [j, j+1). Walking
    forwards, it is past a boundary at p once j >= p, which is ceil(p); it is short of one once
    j + 1 <= p, which is floor(p) - 1 and not floor(p). The asymmetry is the half-open interval
    rather than a fudge, and it is the whole of what the drifted copy got wrong.
    """
    if (step > 0) == inward:
        return int(math.ceil(edge + FILTER_HALF_PX))
    return int(math.floor(edge - FILTER_HALF_PX)) - 1


def plumbable(connection):
    """True for a connection a player can put an ordinary pipe on.

    A connection carrying a `connection_category` is CONTAINED (ADR 0018, #86): it meets a machine
    face, never a pipe. The discriminator is the recorded field, never a list of fluids or machines
    -- and it is the same field models/heat-exchanger/build.py decides a socket's height, thickness
    and flange pair from, so a tool reading it here reads the build script's own choice.
    """
    return not connection.get("connection_category")


# WHERE A SOCKET'S PIECES ARE, moved here from tools/measure-socket-parts.py by #373 for this
# module's own stated reason: tools/check-socket-parts.py came to need the same arrangement, and a
# second copy of it is an arrangement that stops describing one of the two. The gate and the bench
# now take the pieces and the window they are read through from one place.
def parts_of(radius, plumbable, flanged=True):
    """Every piece of a socket of this radius, as (name, radius, back_near, back_far).

    `back_near`..`back_far` is the span the piece occupies along the tube, in tiles inboard from the
    footprint edge the stub stops at. All of it is models/rf_blender.py's constants arranged the way
    models/rf_parts.py's `port` and `socket` arrange them when they draw one -- the rim from the
    first three, the band from its own pair, the ribs fitted into what those two leave between them.

    THE STUB IS WHAT THE OTHERS DO NOT COVER, which on a plumbable socket is the gap between the two
    flange ribs and nothing else. That gap is 1.15 px wide on the shipped sheets, so no column of
    them falls inside it clear of both ribs and the stub has no window there -- reported as such
    rather than read through a window that also holds a rib. A CONTAINED socket wears neither rim
    nor ribs, so its bare tube runs from the mouth to the band and reads easily.

    `flanged=False` is the FLANGE-FREE CONTROL RENDER, and it is the caller's claim about the sheet
    rather than anything read off it: with the ribs deleted their span is bare tube, so the ribs
    row goes and the stub takes the whole span from the rim's inner edge to the band. Left on a
    shipped sheet it would measure the ribs and call them the stub, which is why it is not the
    default and why scripts/probe-flange-free-render.ps1 is what produces a sheet to pass it.
    """
    rim = radius + rf.PORT_CLEARANCE + rf.RIM_PROUD + rf.RIM_MINOR
    band_near = rf.BAND_BACK - rf.BAND_DEPTH / 2
    if not plumbable:
        return [("stub", radius, 0.0, band_near),
                ("accent band", radius + rf.BAND_PROUD, band_near, rf.BAND_BACK + rf.BAND_DEPTH / 2)]
    near = rf.RIM_BACK + rf.RIM_MINOR
    if not flanged:
        return [("stub", radius, near, band_near),
                ("accent band", radius + rf.BAND_PROUD, band_near,
                 rf.BAND_BACK + rf.BAND_DEPTH / 2),
                ("dark rim", rim, rf.RIM_BACK - rf.RIM_MINOR, rf.RIM_BACK + rf.RIM_MINOR)]
    thick = (band_near - near) * (1 - rf.FLANGE_GAP) / 2
    return [("stub", radius, near + thick, band_near - thick),
            ("accent band", radius + rf.BAND_PROUD, band_near, rf.BAND_BACK + rf.BAND_DEPTH / 2),
            ("flange ribs", radius + rf.FLANGE_PROUD, near, band_near),
            ("dark rim", rim, rf.RIM_BACK - rf.RIM_MINOR, rf.RIM_BACK + rf.RIM_MINOR)]


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


def socket_edges(manifest, connection):
    """(mouth, body, ground) for a connection, in tiles on the sheet it is measured on.

    `mouth` is the SELECTION edge the stub stops at and `body` the COLLISION edge the machine's own
    shape stops at, both on the screen's horizontal axis; the outboard strip is what lies between
    them. `ground` is where that connection's ground line sits on the screen's vertical axis, in
    tiles above the sheet centre. Which of the two edges is the greater is the direction's business
    and is not sorted here, because a caller measuring one piece of a socket needs to know which
    way the tube runs.
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
        return sx1, cx1, -py
    if d == "west":
        return sx0, cx0, -py
    if d == "north":
        return -sy0, -cy0, -px
    if d == "south":
        return -sy1, -cy1, -px
    raise Unmeasurable(f"unknown direction '{d}'")


class Strip:
    """One connection's outboard strip, and what is drawn in it.

    `col0`..`col1` are the sheet columns the envelope measurement covers, `col1` exclusive and both
    ends inset. `row0`..`row1` are the rows searched, `row1` exclusive. `ground_row` is that
    connection's ground line as a fractional sheet row; `mouth_col` and `body_col` are the
    selection edge the stub stops at and the collision edge the machine's own shape stops at, as
    fractional sheet columns; and `outward` is -1 when the socket points at the left of the screen
    and +1 when it points at the right. A caller that knows where a piece of the socket sits along
    the tube turns that into columns with `columns_of`.
    """

    def __init__(self, alpha, col0, col1, row0, row1, ground_row, mouth_col, body_col, px_per_tile):
        self.alpha, self.px_per_tile = alpha, px_per_tile
        self.col0, self.col1, self.row0, self.row1 = col0, col1, row0, row1
        self.ground_row, self.mouth_col, self.body_col = ground_row, mouth_col, body_col
        self.outward = -1 if mouth_col < body_col else 1

    def reach(self):
        """(first, last) sheet columns a window may use, both inclusive: everything from the sheet's
        own edge on the mouth side up to the last column the machine's body does not smear into.
        Outboard of the footprint edge there is nothing to leak from -- the rim itself stands out
        there -- and inboard of the collision edge there is the whole machine."""
        # Inboard is whichever way the socket does not point, and the last usable column is the one
        # short of the collision edge on the mouth's side of it -- `clear_of` with inward False.
        last = clear_of(self.body_col, -self.outward, inward=False)
        if self.outward < 0:                       # mouth at screen left, body to the right
            return 0, last
        return last, self.alpha.shape[1] - 1

    def axis_row(self, z):
        """The socket's own axis as a fractional sheet row, for a socket built at world height `z`.
        A cylinder's silhouette is symmetric about this row while the whole of it is drawn."""
        return self.ground_row - z * SCREEN_PER_WORLD * self.px_per_tile

    def extent(self, col0=None, col1=None):
        """(top, bottom) of what is drawn, as sheet row EDGES: the first drawn row's top edge and
        the last drawn row's bottom edge. `col0`..`col1` narrows the column window, `col1`
        INCLUSIVE, because a caller that talks about columns means the ones it names rather than
        one past them.

        Raises Unmeasurable when nothing is drawn there, and when the silhouette touches the edge
        of the row window -- at that point its extent is cut off rather than measured, so its
        midpoint is not the axis and its underside is not its underside.
        """
        lo = self.col0 if col0 is None else col0
        hi = (self.col1 - 1 if col1 is None else col1) + 1
        first, last = self.reach()
        if hi - lo < 1:
            raise Unmeasurable(f"columns {lo}..{hi - 1} is not a column window")
        if lo < first or hi - 1 > last:
            raise Unmeasurable(f"columns {lo}..{hi - 1} reach outside {first}..{last}, which is as "
                               f"far as this sheet goes without holding the machine's own body")
        seen = self.alpha[self.row0:self.row1, lo:hi] > ALPHA_FLOOR
        rows = np.nonzero(seen.any(axis=1))[0]
        if len(rows) == 0:
            raise Unmeasurable(f"nothing is drawn in columns {lo}..{hi - 1} within "
                               f"{WINDOW_TILES:g} tile of the connection's ground line")
        if rows[0] == 0 or rows[-1] == seen.shape[0] - 1:
            raise Unmeasurable(f"what is drawn in columns {lo}..{hi - 1} reaches the edge of the "
                               f"search window, so its extent is cut off rather than measured")
        return self.row0 + int(rows[0]), self.row0 + int(rows[-1]) + 1

    def measure(self, axis, col0, col1):
        """(above, below, unstable) about `axis` through columns `col0`..`col1` inclusive, both in
        pixels, `unstable` being why the reading may not be trusted or None when it may.

        NARROWED BY ONE COLUMN AT EACH END, SEPARATELY, and both must give the same answer. A window
        that has picked up a neighbour loses it when the end it came in at is dropped, and the
        reading moves by whole pixels -- which is the defect this guard exists for. A window under
        three columns cannot be narrowed both ways at all, so it is reported unstable too: a number
        that cannot be checked is not a number this returns as sound.

        IT IS HERE RATHER THAN IN ITS FIRST CALLER FOR THE HEADER'S OWN REASON (#367). It was
        tools/measure-socket-parts.py's until a second instrument needed it, and a second copy of a
        guard is a guard that stops guarding one of them. `extent` says what is drawn; this says
        whether the window it was read through can be believed, which is the same question about
        the same two cuts.

        Raises Unmeasurable when the full window cannot be read at all. A narrowing that cannot be
        read comes back as an unstable reason rather than as a raise: the number itself was got.
        """
        def read(lo, hi):
            top, bottom = self.extent(lo, hi)
            return axis - top, bottom - axis

        full = read(col0, col1)
        if col1 - col0 + 1 < 3:
            return full + (f"a window of {col1 - col0 + 1} column(s) cannot be narrowed at both "
                           f"ends, so this reading could not be checked",)
        for lo, hi in ((col0 + 1, col1), (col0, col1 - 1)):
            try:
                narrowed = read(lo, hi)
            except Unmeasurable as why:
                return full + (f"narrowed to columns {lo}..{hi} it could not be read at all: {why}",)
            if narrowed != full:
                return full + (f"narrowed to columns {lo}..{hi} it reads "
                               f"{narrowed[0]:+.1f}/{narrowed[1]:+.1f}, not "
                               f"{full[0]:+.1f}/{full[1]:+.1f}",)
        return full + (None,)

    def columns_of(self, back_near, back_far):
        """The columns that draw only what lies between `back_near` and `back_far` tiles inboard of
        the footprint edge, as (col0, col1) inclusive, or None when no column does.

        WHOLE WIDTH, NOT CENTRE, AND THE BOUNDARIES PULLED IN BY FILTER_HALF_PX. A column that
        straddles the boundary between two pieces of a socket draws both, and the wider one takes
        the extent; so does a column the filter smears that boundary into. That is exactly the leak
        that put two wrong rows into models/house-style.md -- the stub read a pixel and a half too
        tall because the column where the accent band begins was inside its window.
        """
        near = self.mouth_col - self.outward * back_near * self.px_per_tile
        far = self.mouth_col - self.outward * back_far * self.px_per_tile
        # Sorted into sheet order first, so both ends are cleared walking rightwards whichever way
        # the socket points. `clear_of` is the same primitive `reach` above is written on.
        first, last = self.reach()
        col0 = max(clear_of(min(near, far), +1, inward=True), first)
        col1 = min(clear_of(max(near, far), +1, inward=False), last)
        return (col0, col1) if col1 >= col0 else None


def strip(alpha, manifest, connection):
    """The outboard strip a connection's socket is drawn in, off one sheet's alpha channel."""
    px_per_tile = manifest["frame"]["pixels_per_tile"]
    _, w_px, h_px = sheet_frame(manifest, connection)
    if alpha.shape != (h_px, w_px):
        raise Unmeasurable(f"the sheet is {alpha.shape[1]}x{alpha.shape[0]} px where the manifest's "
                           f"frame says {w_px}x{h_px}")
    mouth, body, ground = socket_edges(manifest, connection)
    col0 = int(round(w_px / 2 + min(mouth, body) * px_per_tile)) + INSET_PX
    col1 = int(round(w_px / 2 + max(mouth, body) * px_per_tile)) - INSET_PX
    if col1 - col0 < 1:
        raise Unmeasurable("the selection box is no wider than the collision box on that side, so "
                           "no part of the socket stands clear of the machine to be measured")
    ground_row = h_px / 2 - ground * px_per_tile
    row0 = int(round(ground_row - WINDOW_TILES * px_per_tile))
    row1 = int(round(ground_row + WINDOW_TILES * px_per_tile))
    if row0 < 0 or row1 > h_px:
        raise Unmeasurable("the search window falls outside the sheet")
    return Strip(alpha, col0, col1, row0, row1, ground_row,
                 w_px / 2 + mouth * px_per_tile, w_px / 2 + body * px_per_tile, px_per_tile)

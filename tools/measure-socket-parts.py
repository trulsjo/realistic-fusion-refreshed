#!/usr/bin/env python3
"""Report what one socket's pieces are drawn as, a piece at a time, through a guarded window.

    python tools/measure-socket-parts.py <manifest.json> --direction west --radius 0.249
    python tools/measure-socket-parts.py <...> --direction west --fluid water --radius 0.249
    python tools/measure-socket-parts.py <...> --direction west --radius 0.249 --no-flange
    python tools/measure-socket-parts.py <...> --direction west --radius 0.249 \
           --part "accent band" --window 203..206    # read one part through a window you name

A BENCH, NOT A CHECK, in this repository's own three words for a script (CONTEXT.md, Measurement
words). A check asserts an invariant and blocks on it; a probe asserts nothing; a BENCH measures a
quantity, reports it, and asserts only its own validity -- it refuses to return a number it cannot
stand behind. That last sentence is this whole file. It says nothing about whether a socket is
RIGHT, only what the sheet draws; scripts/load-check.ps1 does not run it and nothing fails because
of it. tools/check-socket-height.py is the check over the same sheets, and it asks a different
question -- the envelope, not the pieces. A verdict here would need a self-test of its own and this
is not that.

It is not named `bench-socket-parts.py` because that prefix is taken, by the `scripts/bench-*.ps1`
that load the game and measure what a factory costs to run. The shape is theirs; the subject is
pixels on a sheet that is already committed.

WHY IT IS A TOOL RATHER THAN A HABIT: THE COLUMN WINDOW. Each piece of a socket can only be read in
the columns where it is the widest thing present, and one column either way picks up its neighbour
and moves the answer by whole pixels. That leak published two wrong rows into models/house-style.md
and they shipped -- on rf-isotope-collector's west socket the stub reads +21.5/+19.5 over columns
198..202 where it is +20.5/+18.5 over 198..201, because column 202 is the first that draws any of
the accent band. So the guard lives in the instrument: every number carries the window it was read
through, and a number that MOVES when that window is narrowed by one column at either end is
reported unstable rather than returned.

BOTH OF THOSE READINGS REPRODUCE, and neither needs the game. The stub's needs a flange-free
control render, since on the shipped sheets no column shows bare tube at all -- and since #376 that
render is one command: scripts/probe-flange-free-render.ps1, which runs socket-variants.py's
`unflanged` treatment over the stored model and models/render.py over the result, into a directory
you name and which it refuses if it is inside a mod. Measure that sheet with --no-flange -- which
is the CALLER saying what kind of sheet it is, since every window here is worked out from the
constants the model was built from and never from the pixels -- and the stub reports +20.5/+18.5
through columns 198..201, which is models/house-style.md's row. Nothing in the repository is
touched and nothing is committed, so this file reports the stub as having NO WINDOW on the shipped
sheets rather than a number it cannot get to. The SAME boundary can be shown with no render at all: the
usage line above reads the accent band +24.5 above its axis where its own columns give +23.5,
because the flange rib ends at column 202.88 and column 203 starts a tenth of a pixel past that.

A NOTE ON HOW A WINDOW IS WRITTEN, since the two sets of numbers differ by one. Both ends here are
INCLUSIVE. models/house-style.md's windows were written as Python slice bounds until #365, which
are half-open, so its far end read one too high -- the readings never moved, only the notation.

WHERE THE WINDOWS COME FROM. Not from a list of columns typed here, which would be the same defect
one layer down. models/rf_blender.py carries where each piece sits along the tube -- RIM_BACK,
BAND_BACK, FLANGE_GAP and the rest, which models/rf_parts.py re-exports to the build scripts that
draw them -- and tools/socket_strip.py turns a span along the tube into the columns that draw
nothing else: whole width inside the span, and clear of every boundary by the width the renderer's
own filter smears an edge. Both halves of that are needed, and that module's header has the
measurement saying so.

WHAT IT MEASURES, AND AGAINST WHAT. For each piece: its radius; the extent an UNCUT cylinder of
that radius would draw either side of the socket's axis, which is r / sin(pitch) and nothing
fitted; what the sheet actually draws above and below that axis; and the difference each way. A
socket at SOCKET_Z reaches below models/rf_blender.build_rig's shadow-catching ground plane, so the
underside is cut and the two differences are not equal. #362 is where the cause is chased; this
tool is only the measurement it is chased with.

TWO NUMBERS IT CANNOT WORK OUT AND WILL NOT GUESS: the socket's radius and its height. Both are the
caller's business in models/rf_parts.py's `socket` too, and for the same reason -- a machine may
draw a socket of any width, and a CONTAINED connection (ADR 0018) is drawn at the machine's own
height rather than a pipe's. So `--radius` is required, and `--z` defaults to rf_blender.SOCKET_Z
only for a connection a player can plumb. Guessing either would move the axis every row is measured
about, silently.

Pure Python and no Factorio: it reads sheets and manifests that are already committed. Needs pillow
and numpy. Run from the repository root.
"""
import argparse
import json
import os
import sys

try:
    import numpy as np
    from PIL import Image
except ImportError as missing:
    sys.exit(f"measure-socket-parts: {missing}. This reads sprite pixels and needs both pillow and "
             f"numpy in the `python` on PATH -- `python -m pip install pillow numpy`.")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "models"))
import rf_blender as rf  # noqa: E402  (no bpy at module level)
import socket_strip  # noqa: E402


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


def read(s, axis, col0, col1):
    """(above, below) in pixels about the socket's axis, through columns `col0`..`col1` inclusive."""
    top, bottom = s.extent(col0, col1)
    return axis - top, bottom - axis


def measure(s, axis, col0, col1):
    """(above, below, unstable) through that window, `unstable` being why the reading may not be
    trusted or None when it may.

    NARROWED BY ONE COLUMN AT EACH END, SEPARATELY, and both must give the same answer. A window
    that has picked up a neighbour loses it when the end it came in at is dropped, and the reading
    moves by whole pixels -- which is the defect this tool exists for. A window under three columns
    cannot be narrowed both ways at all, so it is reported unstable too: a number that cannot be
    checked is not a number this returns as sound.
    """
    full = read(s, axis, col0, col1)
    if col1 - col0 + 1 < 3:
        return full + (f"a window of {col1 - col0 + 1} column(s) cannot be narrowed at both ends, "
                       f"so this reading could not be checked",)
    for lo, hi in ((col0 + 1, col1), (col0, col1 - 1)):
        try:
            narrowed = read(s, axis, lo, hi)
        except socket_strip.Unmeasurable as why:
            return full + (f"narrowed to columns {lo}..{hi} it could not be read at all: {why}",)
        if narrowed != full:
            return full + (f"narrowed to columns {lo}..{hi} it reads "
                           f"{narrowed[0]:+.1f}/{narrowed[1]:+.1f}, not "
                           f"{full[0]:+.1f}/{full[1]:+.1f}",)
    return full + (None,)


def load_sheet(directory, machine, suffix):
    path = os.path.join(directory, f"{machine}{suffix}.png")
    if not os.path.exists(path):
        raise socket_strip.Unmeasurable(f"{os.path.basename(path)} is not there")
    return np.asarray(Image.open(path).convert("RGBA"))[..., 3], os.path.basename(path)


def pick(manifest, direction, fluid):
    """The one connection a `--direction` and an optional `--fluid` name, or an exit with the list.

    Refuses an ambiguous pair rather than taking the first. rf-heat-exchanger puts water and reactor
    energy on the same short end, one plumbable and one not, drawn at different heights and
    different thicknesses -- so a tool that guessed between them would measure one socket about the
    other's axis and report the difference as a finding.
    """
    found = [c for c in manifest["geometry"]["connections"]
             if c["direction"] == direction and (fluid is None or c["fluid"] == fluid)]
    if not found:
        sys.exit(f"measure-socket-parts: {manifest['geometry']['name']} records no {direction} "
                 f"connection{'' if fluid is None else ' carrying ' + fluid}. It records: "
                 + ", ".join(f"{c['direction']} {c['fluid']}"
                             for c in manifest["geometry"]["connections"]))
    if len(found) > 1:
        sys.exit(f"measure-socket-parts: {manifest['geometry']['name']} records "
                 f"{len(found)} {direction} connections -- "
                 + ", ".join(c["fluid"] for c in found)
                 + ". Name one with --fluid; they are not drawn alike.")
    return found[0]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("manifest", help="graphics/rendered/<machine>/manifest.json")
    ap.add_argument("--direction", required=True, choices=("north", "east", "south", "west"),
                    help="which connection's socket to measure")
    ap.add_argument("--fluid", help="which one, when the machine has two on that side")
    ap.add_argument("--radius", required=True, type=float,
                    help="the tube's radius in tiles, as the build script drew it (0.249 for a "
                         "socket a player plumbs; models/house-style.md says where that came from)")
    ap.add_argument("--z", type=float,
                    help="the world height its axis was built at; defaults to rf_blender.SOCKET_Z "
                         "for a plumbable connection and is required for a contained one")
    ap.add_argument("--no-flange", action="store_true",
                    help="the sheet is a flange-free control render "
                         "(scripts/probe-flange-free-render.ps1), so the ribs' span is bare tube "
                         "and the stub is measured through it. Says so about the sheet; it is not "
                         "detected, and on a shipped sheet it would measure the ribs")
    ap.add_argument("--part", help="measure only this part")
    ap.add_argument("--window", metavar="LOW..HIGH",
                    help="read --part through these sheet columns instead of the ones its own "
                         "geometry gives, both ends inclusive. For showing what a leaking window "
                         "does to the answer")
    a = ap.parse_args(argv)
    if a.window and not a.part:
        sys.exit("measure-socket-parts: --window says which columns to read ONE part through, so "
                 "it needs --part as well.")
    forced = None
    if a.window:
        try:
            lo, hi = (int(t) for t in a.window.split(".."))
        except ValueError:
            sys.exit(f"measure-socket-parts: --window wants LOW..HIGH in sheet columns, not "
                     f"'{a.window}'.")
        forced = (lo, hi)

    manifest = json.load(open(a.manifest, encoding="utf-8"))
    connection = pick(manifest, a.direction, a.fluid)
    plumbable = socket_strip.plumbable(connection)
    if a.z is None and not plumbable:
        sys.exit(f"measure-socket-parts: {connection['direction']} {connection['fluid']} carries a "
                 f"connection_category, so it is CONTAINED (ADR 0018) and is drawn at the machine's "
                 f"own height rather than a pipe's. Its build script chooses that height; pass it "
                 f"with --z rather than have this default to rf_blender.SOCKET_Z and measure every "
                 f"part about the wrong axis.")
    z = rf.SOCKET_Z if a.z is None else a.z

    try:
        suffix, _, _ = socket_strip.sheet_frame(manifest, connection)
        alpha, sheet = load_sheet(os.path.dirname(a.manifest), manifest["machine"], suffix)
        s = socket_strip.strip(alpha, manifest, connection)
    except socket_strip.Unmeasurable as why:
        print(f"FAILED - measure-socket-parts: {why}.")
        return 1
    axis = s.axis_row(z)

    flanged = not a.no_flange
    if a.no_flange and not plumbable:
        sys.exit(f"measure-socket-parts: {connection['direction']} {connection['fluid']} is "
                 f"CONTAINED (ADR 0018) and wears no flange pair on any sheet, so --no-flange "
                 f"names nothing. Its bare tube already reads from the mouth to the band.")
    parts = parts_of(a.radius, plumbable, flanged)
    if a.part:
        parts = [p for p in parts if p[0] == a.part]
        if not parts:
            sys.exit(f"measure-socket-parts: this socket has no part called '{a.part}'. It has: "
                     + ", ".join(f"'{p[0]}'" for p in parts_of(a.radius, plumbable, flanged)))

    print(f"{manifest['geometry']['name']}  {connection['direction']} {connection['fluid']}  "
          f"({'plumbable' if plumbable else 'contained'}, tube radius {a.radius:g}, axis at z "
          f"{z:g} -- sheet row {axis:.3f} of {sheet}"
          + (", read as a FLANGE-FREE CONTROL render" if a.no_flange else "") + ")")
    print(f"  {'part':<12} {'radius':>6} {'uncut':>6} {'above':>7} {'below':>7} {'gains':>6} "
          f"{'loses':>6}  window")
    unstable = 0
    for name, radius, back_near, back_far in parts:
        uncut = radius * socket_strip.UNCUT_PER_RADIUS * s.px_per_tile   # the same each way: +/-
        if forced:
            col0, col1 = forced
        else:
            window = s.columns_of(back_near, back_far)
            if window is None:
                print(f"  {name:<12} {radius:>6.3f} {uncut:>6.1f} {'':>7} {'':>7} {'':>6} {'':>6}"
                      f"  NO WINDOW: this part occupies {back_far - back_near:.3f} tiles "
                      f"({(back_far - back_near) * s.px_per_tile:.2f} px) of the tube, and no "
                      f"column of this sheet draws that clear of what is either side of it")
                unstable += 1
                continue
            col0, col1 = window
        try:
            above, below, why = measure(s, axis, col0, col1)
        except socket_strip.Unmeasurable as cannot:
            print(f"  {name:<12} {radius:>6.3f} {uncut:>6.1f} {'':>7} {'':>7} {'':>6} {'':>6}"
                  f"  UNMEASURABLE: {cannot}")
            unstable += 1
            continue
        print(f"  {name:<12} {radius:>6.3f} {uncut:>6.1f} {above:>+7.1f} {below:>+7.1f} "
              f"{above - uncut:>+6.1f} {uncut - below:>+6.1f}  cols {col0}..{col1}"
              + ("" if why is None else f"  UNSTABLE: {why}"))
        if why is not None:
            unstable += 1
    print(f"  'uncut' is what a cylinder of that radius draws EITHER SIDE of its axis with nothing "
          f"cut off; 'gains' is how much more than that is drawn above, 'loses' how much less is "
          f"drawn below. Pixels, at {s.px_per_tile} to the tile.")
    if unstable:
        print(f"  {unstable} of {len(parts)} row(s) above carry no number this tool will stand "
              f"behind. Read the reason on each; none of them is a finding about the art.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

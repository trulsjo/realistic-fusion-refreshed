#!/usr/bin/env python3
"""Fail when a player-facing socket is drawn at a height a vanilla pipe would not meet.

    python tools/check-socket-height.py <manifest.json> [...]      # gate: exit 1 on a mismatch
    python tools/check-socket-height.py --self-test <manifest.json> [...]

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
above the ground line. A socket is a cylinder lying along a ground axis: its silhouette is
symmetric about that axis, the radius terms cancelling, so the MIDPOINT of its drawn extent is the
axis, wherever the accent band and the port rim put the extremes.

Isolating the socket is the other half. Outside the collision box there is nothing on either
machine but socket stubs -- the slab, the deck and the frame all stop at the footprint -- so the
strip between the collision edge and the selection edge holds the socket and nothing else. That
strip is a column range only when the socket runs left-to-right on screen, so each connection is
measured on the sheet where it does: direction sheet 0 for an east or west connection, sheet "-e"
for a north or south one, which is the same machine with the camera turned a quarter (models/
render.py turns the rig by +90 degrees per direction).

WHAT IT CANNOT SEE. Height, and only height. Our sockets are drawn a little fatter or thinner than
vanilla's pipe and this says nothing about that -- #345 is where the width is decided. It also says
nothing about whether a socket is on the right EDGE of the machine; load-check's rendered-art gate
holds the recorded geometry against the live prototype, and that is what covers it.

Needs pillow and numpy. Run from the repository root.
"""
import argparse
import json
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "models"))
import rf_blender as rf  # noqa: E402  (no bpy at module level)

# A world height of 1 tile draws this many tiles up the screen. One expression, shared with the
# build scripts through the camera it comes from rather than copied as a number.
SCREEN_PER_WORLD = 1.0 / math.tan(math.radians(rf.CAMERA_PITCH_DEG))

# WHERE A VANILLA PIPE DRAWS ITS BODY, in tiles above the ground line. Measured off
# base/graphics/entity/pipe/pipe-straight-horizontal.png, which the prototype draws at scale 0.5
# with no shift -- so 64 px to the tile, the same as ours, and directly comparable. The sheet has
# the pipe's shadow baked into it below the body; the body is rows 43..81 of 128, and its midpoint
# lands here. This is the number models/rf_parts.SOCKET_Z was solved from.
VANILLA_PIPE_CENTRE = 0.031

# HOW FAR OFF IS TOO FAR. Not equality: a socket is a lit, bevelled, anti-aliased cylinder with an
# accent band and a rimmed opening on it, and the collector measures about 0.024 tiles above
# vanilla's centre after #343 rather than on it. 0.08 tiles is five pixels on a sheet and two and a
# half at the game's own zoom -- it admits that bias with room to spare and still catches the defect
# this exists for by a factor of four, since a socket at z 0.55 draws 0.389 tiles up.
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


def report(rows):
    """Print one line per measured connection; return each one's verdict, in the same order."""
    verdicts = []
    for name, label, centre, why in rows:
        if why is not None:
            print(f"  {name:24s} {label:24s} UNMEASURABLE: {why}")
            verdicts.append("UNMEASURABLE")
            continue
        off = centre - VANILLA_PIPE_CENTRE
        verdict = "ok" if abs(off) <= TOLERANCE else "TOO HIGH" if off > 0 else "TOO LOW"
        print(f"  {name:24s} {label:24s} drawn {centre:+.3f} tiles up against the pipe's "
              f"{VANILLA_PIPE_CENTRE:+.3f} ({off:+.3f}, world z {centre / SCREEN_PER_WORLD:.3f} "
              f"against {VANILLA_PIPE_CENTRE / SCREEN_PER_WORLD:.3f}): {verdict}")
        verdicts.append(verdict)
    return verdicts


def self_test(manifests):
    """Prove the check can fail, in both directions, without a game or a render.

    HALF ONE: every plumbable socket on both machines as they stand must pass. HALF TWO: the same
    sheets lifted a quarter tile up the screen must be reported TOO HIGH on every one of them. A
    gate that only ever passes and a gate that only ever fails look the same from outside, so both
    halves are here.

    THE LIFT IS A QUARTER TILE RATHER THAN THE HALF THE REAL DEFECT WAS, and the reason is worth
    keeping: half a tile pushes a socket against the top of the search window, so the check reports
    it UNMEASURABLE -- a failure, and the right one, but it exercises the window guard instead of
    the comparison this gate is for. A quarter tile is three times the tolerance and still well
    inside the window, so the verdict comes from the measurement.
    """
    print("self-test 1/2: every plumbable socket on the shipped sheets must pass.")
    rows = []
    for path in manifests:
        check(path, load_sheet, rows)
    if not rows:
        print("FAILED - self-test: no plumbable connection was measured at all, so neither half "
              "proves anything.")
        return 1
    bad = [v for v in report(rows) if v != "ok"]
    if bad:
        print(f"FAILED - self-test: {len(bad)} socket(s) failed on the sheets as they stand, so "
              "half two cannot tell a working check from a broken one.")
        return 1

    shift = int(round(0.25 * rf.PX_PER_TILE))
    print(f"self-test 2/2: the same sheets lifted {shift} px must be reported TOO HIGH on every one.")
    lifted = []
    for path in manifests:
        check(path, rolled_sheet(shift), lifted)
    missed = [(row, verdict) for row, verdict in zip(lifted, report(lifted)) if verdict != "TOO HIGH"]
    if missed:
        print(f"FAILED - self-test: {len(missed)} socket(s) were lifted a quarter tile and this "
              "check did not report them as drawn too high:")
        for (name, label, _, _), verdict in missed:
            print(f"           {name}  {label}: {verdict}")
        return 1
    print("self-test: both halves pass.")
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("manifest", nargs="+", help="graphics/rendered/<machine>/manifest.json")
    ap.add_argument("--self-test", action="store_true",
                    help="prove the check can fail, on the sheets as they stand")
    a = ap.parse_args(argv)

    if a.self_test:
        return self_test(a.manifest)

    rows = []
    for path in a.manifest:
        check(path, load_sheet, rows)
    if not rows:
        print("FAILED - socket height: none of the manifests given records a connection a player "
              "can plumb, so this check found nothing to measure rather than finding nothing wrong.")
        return 1
    bad = [v for v in report(rows) if v != "ok"]
    if bad:
        print(f"FAILED - socket height: {len(bad)} socket(s) a player plumbs are not drawn where a "
              "vanilla pipe is.")
        print("         A pipe run into one of these meets the machine at a step. Build the socket "
              "at models/rf_parts.SOCKET_Z and re-render; a CONTAINED connection belongs at the "
              "machine's own height and should carry a connection_category instead.")
        return 1
    print(f"socket height: all {len(rows)} player-facing socket(s) meet a vanilla pipe "
          f"(within {TOLERANCE} tiles of its {VANILLA_PIPE_CENTRE:+.3f}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())

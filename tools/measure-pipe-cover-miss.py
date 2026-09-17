#!/usr/bin/env python3
"""Measure how far a pipe cover misses the socket it belongs to, off two runs of
scripts/probe-pipe-cover-miss.ps1.

    pwsh -File scripts/probe-pipe-cover-miss.ps1 -MapSeed 7                  -OutputDirectory covers
    pwsh -File scripts/probe-pipe-cover-miss.ps1 -MapSeed 7 -Strip contained -OutputDirectory bare
    pwsh -File scripts/probe-pipe-cover-miss.ps1 -MapSeed 7 -Strip all       -OutputDirectory bare-all
    python tools/measure-pipe-cover-miss.py covers bare --all bare-all

A BENCH, NOT A CHECK (CONTEXT.md, Measurement words): it measures, reports, and asserts only its own
validity. It draws no threshold and says nothing about what the miss ought to be -- #391 weighs the
remedies and that is Truls's.

THE COVER IS FOUND BY SUBTRACTION, NOT BY RECOGNITION (#390). The runs differ in one thing: which
fluid boxes still declare `pipe_covers`. So the pixels that differ between two frames of the same
machine on the same map seed ARE the cover, and nothing here has to know what one looks like, what
colour it is, or how big it should be. That matters more than it sounds: a cover on a Krastorio 2
sprite, a cover on a mockup plate and a cover on a rendered sheet are three different pictures, and
this finds all three the same way.

WHAT IT MEASURES, and why each half is a DIFFERENCE rather than a reading. #390 asks for the offset
between a contained socket's drawn axis and its pipe cover, measured rather than derived from the
projection -- and for a plumbable socket on the same machine beside it as a control. A control is
what turns one reading against a prediction into a difference between two readings:

  - the socket's DRAWN AXIS comes off the rendered sheet through tools/socket_strip.py -- its
    `strip()` places the socket and `Strip.axis_row` gives the row a cylinder's silhouette is
    symmetric about -- and tools/measure-frame-accents.py's `sheet_to_frame` maps that onto the
    frame. Both are CALLED, not repeated: socket_strip's header asks for one copy of the arithmetic
    that reads a socket off a sheet, and `sheet_to_frame` is the one copy of the separate
    world-to-screen mapping, which this file would otherwise need at zoom 8 beside its own at
    zoom 1.
  - the COVER comes off the subtraction, as the centroid and the bounding box of what stopped being
    drawn.

So the figure reported is (cover − axis) for a contained socket and (cover − axis) for a plumbable
one on the same machine, in the same frame, in the same light. Their difference is the miss, and it
rests on no prediction at all.

WHAT IT CANNOT MEASURE, and says so rather than guessing. A machine with no rendered sheet has no
`Strip` and therefore no drawn axis: rf-reactor wears Krastorio 2's art and rf-aneutronic-reactor and
rf-direct-energy-converter wear mockups. For those the cover's own extent is reported and the offset
is left blank. That is not a gap in this tool -- it is what "six contained boxes belong to machines
nobody has rendered yet" means, and the frames are there for a person to look at.

Needs pillow and numpy. Run from the repository root.
"""
import argparse
import importlib.util
import json
import os
import sys

try:
    import numpy as np
    from PIL import Image
except ImportError as missing:
    sys.exit(f"measure-pipe-cover-miss: {missing}. This reads frame pixels and needs both pillow "
             f"and numpy in the `python` on PATH -- `python -m pip install pillow numpy`.")

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "models"))
import rf_blender as rf  # noqa: E402  (no bpy at module level)
import socket_strip  # noqa: E402

_spec = importlib.util.spec_from_file_location(
    "measure_frame_accents", os.path.join(HERE, "measure-frame-accents.py"))
mfa = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(mfa)

MODELS_DIR = "models"
RENDERED_DIR = os.path.join("realistic-fusion-refreshed-assets", "graphics", "rendered")

# How far a pixel has to move between the two runs to count as part of the cover, out of 255. The
# two frames are the same machine on the same map seed, so anything that moves at all moved because
# the declaration went -- but rf-heat-exchanger's glow sheet jitters by a level or two between runs
# (docs/research/game-reproduces-the-sheet.md), so a floor of 4 keeps that out without being near
# anything a cover does.
MOVED = 4

# Rows searched either side of a connection's own ground line, in tiles. socket_strip's own window,
# for its own reason: one tile holds a socket drawn anywhere from the floor to z 0.55 whole, and
# stops short of the next connection on the same wall -- which on rf-heat-exchanger's short ends is
# two tiles away.
WINDOW_TILES = socket_strip.WINDOW_TILES

# A world height of 1 tile draws this many tiles up the screen, off the camera the sheets were
# rendered through. Used ONLY to print what the projection predicts beside what was measured; no
# figure this tool reports is derived from it.
SCREEN_PER_WORLD = socket_strip.SCREEN_PER_WORLD


def model_of(entity_name):
    """(model directory, geometry) for an entity with a committed geometry file, or (None, None)."""
    if not os.path.isdir(MODELS_DIR):
        return None, None
    for entry in sorted(os.listdir(MODELS_DIR)):
        path = os.path.join(MODELS_DIR, entry, "geometry.json")
        if os.path.exists(path):
            geometry = json.load(open(path, encoding="utf-8"))
            if geometry["name"] == entity_name:
                return entry, geometry
    return None, None


def cover_mask(with_covers, without):
    """Where the two frames differ, as a boolean array. That is the cover and nothing else."""
    if with_covers.shape != without.shape:
        raise socket_strip.Unmeasurable(
            f"the two runs' frames are {with_covers.shape} and {without.shape}; they have to be the "
            f"same frame of the same rig for the subtraction to mean anything")
    return np.abs(with_covers.astype(int) - without.astype(int)).max(axis=2) > MOVED


def box_of(mask, row0, row1, col0, col1):
    """(top, bottom, left, right, centre_row, centre_col, pixels) of the mask inside a box, or None
    when nothing there moved. Both ranges are inclusive; `centre_*` are the mask's centroid.

    A BOX AND NOT A ROW BAND, WHICH THE FIRST VERSION OF THIS USED AND WHICH MERGED NEIGHBOURS.
    rf-heat-exchanger's west and east energy connections share a row, fifteen tiles apart, so a row
    band caught both and reported one blob 506 px wide whose centroid sat between them -- a figure
    that looks like a measurement and is the average of two covers. Every window is now bounded on
    both axes around the connection's own tile.
    """
    row0, row1 = max(0, int(row0)), min(mask.shape[0] - 1, int(row1))
    col0, col1 = max(0, int(col0)), min(mask.shape[1] - 1, int(col1))
    if row1 < row0 or col1 < col0:
        return None
    window = mask[row0:row1 + 1, col0:col1 + 1]
    rows, cols = np.nonzero(window)
    if len(rows) == 0:
        return None
    return (row0 + int(rows.min()), row0 + int(rows.max()),
            col0 + int(cols.min()), col0 + int(cols.max()),
            row0 + float(rows.mean()), col0 + float(cols.mean()), int(len(rows)))


class Socket:
    """One connection in one frame: where its axis is drawn, and where its cover is."""

    def __init__(self, connection, plumbable, axis_row, mouth_col, cover, ppt):
        self.connection, self.plumbable = connection, plumbable
        self.axis_row, self.mouth_col, self.cover, self.ppt = axis_row, mouth_col, cover, ppt

    @property
    def label(self):
        kind = "plumbable" if self.plumbable else "CONTAINED"
        return f"{self.connection['direction']} {self.connection['fluid'] or '(any)'} [{kind}]"

    @property
    def drop(self):
        """How far below the socket's drawn axis the cover's centre sits, in frame pixels. Positive
        is DOWN the screen, which is what "below" means on a frame."""
        if self.cover is None or self.axis_row is None:
            return None
        return self.cover[4] - self.axis_row

    # Which way is OUTBOARD along the screen's horizontal axis, per direction. A west socket points
    # at the left of the screen, so outboard is a DECREASING column. North and south sockets do not
    # run left-to-right at all, so they get no horizontal reach rather than a meaningless one.
    OUTWARD = {"west": -1, "east": +1}

    @property
    def reach(self):
        """How far OUTBOARD of the socket's mouth the cover's centre sits, in frame pixels: positive
        away from the machine, negative inboard of the mouth. None when the socket does not run
        left-to-right on this frame, or when no mouth could be placed.

        SIGNED, AND IT WAS NOT. This returned abs() under a docstring that said signed, so a cover
        drawn INBOARD of the mouth read the same as one the same distance out -- on a probe whose
        whole observation is a cover sitting "below and outboard", which is the one direction the
        figure had to be able to contradict.
        """
        outward = self.OUTWARD.get(self.connection["direction"])
        if self.cover is None or self.mouth_col is None or outward is None:
            return None
        return outward * (self.cover[5] - self.mouth_col)


def sockets_in(frame_name, covers_dir, bare_dir, all_dir=None):
    """Every connection this frame holds, with its cover and its drawn axis. Raises Unmeasurable."""
    a_path, b_path = os.path.join(covers_dir, frame_name), os.path.join(bare_dir, frame_name)
    for p in (a_path, b_path):
        if not os.path.exists(p):
            raise socket_strip.Unmeasurable(f"{os.path.basename(p)} is not in both runs")
    sidecar = mfa.sidecar_of(a_path)
    bare_side = mfa.sidecar_of(b_path)
    for key in ("zoom", "centre", "resolution"):
        if sidecar[key] != bare_side[key]:
            raise socket_strip.Unmeasurable(
                f"the two runs framed this differently ({key}: {sidecar[key]} against "
                f"{bare_side[key]}), so subtracting them measures the framing")

    shipped = np.asarray(Image.open(a_path).convert("RGB"))
    mask = cover_mask(shipped, np.asarray(Image.open(b_path).convert("RGB")))
    # A PLUMBABLE SOCKET'S COVER SURVIVES THE `contained` RUN, so subtracting that run finds nothing
    # at it. The `all` run is the instrument that makes it visible -- see the probe's -Strip note --
    # and it is used for plumbable connections ONLY, so the contained figures stay a subtraction
    # against the remedy actually under consideration rather than against an instrument.
    all_mask = None
    all_path = os.path.join(all_dir, frame_name) if all_dir else None
    if all_path and os.path.exists(all_path):
        all_mask = cover_mask(shipped, np.asarray(Image.open(all_path).convert("RGB")))
    ppt, zoom = sidecar["pixels_per_tile"], sidecar["zoom"]
    W, H = sidecar["resolution"]["w"], sidecar["resolution"]["h"]

    found, unplaced = [], []
    for machine in sidecar["machines"]:
        model, geometry = model_of(machine["name"])
        if geometry is None:
            # NO GEOMETRY FILE MEANS NO CONNECTION LIST, NOT NOTHING TO SAY. rf-reactor wears
            # Krastorio 2's art and nobody has run tools/extract-geometry.py for it, so this cannot
            # name which socket a cover belongs to -- but it can still say that one appeared and how
            # big it is, which is most of what #390 asks about a machine nobody has rendered.
            unplaced.append(machine["name"])
            continue
        sheets_dir = os.path.join(RENDERED_DIR, model) if model else None
        manifest_path = os.path.join(sheets_dir, "manifest.json") if sheets_dir else None
        manifest = (json.load(open(manifest_path, encoding="utf-8"))
                    if manifest_path and os.path.exists(manifest_path) else None)
        for c in geometry["connections"]:
            # Where this connection's own ground line falls in the frame, off the world position of
            # the machine and the connection's offset from it -- no sheet needed, so it works for a
            # mockup and a Krastorio 2 sprite as much as for a rendered one.
            wx = machine["position"]["x"] + c["position"][0]
            wy = machine["position"]["y"] + c["position"][1]
            col = W / 2 + (wx - sidecar["centre"]["x"]) * ppt
            row = H / 2 + (wy - sidecar["centre"]["y"]) * ppt
            if not (0 <= col < W and 0 <= row < H):
                continue
            # OUTBOARD IS WHERE THE COVER IS, so the window reaches further that way than inboard.
            # Which way outboard is comes off the connection's own direction, and the two together
            # keep a west connection's window clear of an east one on the same machine.
            out = {"west": (-1, 0), "east": (1, 0), "north": (0, -1), "south": (0, 1)}[c["direction"]]
            here = all_mask if (socket_strip.plumbable(c) and all_mask is not None) else mask
            cover = box_of(here,
                           row - WINDOW_TILES * ppt + min(0, out[1]) * WINDOW_TILES * ppt,
                           row + WINDOW_TILES * ppt + max(0, out[1]) * WINDOW_TILES * ppt,
                           col - WINDOW_TILES * ppt + min(0, out[0]) * WINDOW_TILES * ppt,
                           col + WINDOW_TILES * ppt + max(0, out[0]) * WINDOW_TILES * ppt)

            axis_row, mouth_col = None, None
            if manifest is not None and machine["direction"] == mfa.NORTH:
                try:
                    axis_row, mouth_col = _drawn_axis(sidecar, machine, manifest, c, sheets_dir)
                except socket_strip.Unmeasurable:
                    axis_row, mouth_col = None, None
            found.append((machine["name"],
                          Socket(c, socket_strip.plumbable(c), axis_row, mouth_col, cover, ppt)))
    whole = box_of(mask, 0, mask.shape[0] - 1, 0, mask.shape[1] - 1) if unplaced else None
    return sidecar, found, (sorted(set(unplaced)), whole)


_ALPHA = {}


def sheet_alpha(sheets_dir, manifest, suffix):
    """The alpha channel of one direction's sheet, read once per file and kept.

    Cached because `_drawn_axis` is called per connection and a machine's sockets share a sheet;
    reading a 1344 x 704 PNG six times to ask it the same question would be silly.
    """
    path = os.path.join(sheets_dir, f"{manifest['machine']}{suffix}.png")
    if path not in _ALPHA:
        if not os.path.exists(path):
            raise socket_strip.Unmeasurable(f"{os.path.basename(path)} is not there")
        _ALPHA[path] = np.asarray(Image.open(path).convert("RGBA"))[..., 3]
    return _ALPHA[path]


def _drawn_axis(sidecar, machine, manifest, connection, sheets_dir):
    """(axis row, mouth column) of a socket as this frame draws it, in frame pixels.

    THE SHEET SAYS WHERE THE SOCKET IS AND THE SIDECAR SAYS WHERE THE SHEET IS, AND NEITHER ANSWER
    IS WORKED OUT HERE. `socket_strip.strip` builds the socket's own strip off the sheet -- which
    places its ground line and the selection edge its stub stops at -- `Strip.axis_row` lifts that
    ground line by the socket's world height through the render camera, and `sheet_to_frame` puts
    the result on the frame. Every step is somebody else's arithmetic and every one of them is
    CALLED rather than repeated.

    IT USED TO REPEAT THEM, AND THE DOCSTRING ABOVE THIS ONE ALREADY SAID IT DID NOT. The first
    version computed `ground_row`, the axis and the mouth by hand from `socket_edges` -- three
    formulas `strip()` and `axis_row()` already own, byte for byte -- while claiming in prose to
    borrow them. That is the second copy tools/socket_strip.py's header exists to refuse, and
    models/rf_parts.py's header records one drifting from its original inside a week (#340).
    Calling `strip()` also brings its validation: a sheet whose size disagrees with the manifest's
    frame, or a selection box no wider than the collision box on that side, is now an Unmeasurable
    rather than a number quietly read off the wrong pixels.

    Raises Unmeasurable for a connection whose socket this frame does not draw left-to-right --
    which is a north or south one, measured on the `-e` sheet the frame is not of.
    """
    suffix, _w_px, _h_px = socket_strip.sheet_frame(manifest, connection)
    if suffix != "":
        raise socket_strip.Unmeasurable(
            f"a {connection['direction']} socket is drawn on the '-e' sheet, which this frame is "
            f"not of")
    s = socket_strip.strip(sheet_alpha(sheets_dir, manifest, suffix), manifest, connection)
    z = rf.SOCKET_Z if socket_strip.plumbable(connection) else CONTAINED_Z

    # A halved-sheet coordinate is what `sheet_to_frame` maps, and `Strip` works in FULL sheet
    # pixels -- 64 to the tile against the halved sheet's 32 -- so each is halved on the way out.
    col0, row0, scale = mfa.sheet_to_frame(sidecar, machine, manifest)
    return row0 + (s.axis_row(z) / 2) * scale, col0 + (s.mouth_col / 2) * scale


# The world height a CONTAINED socket is built at, from models/heat-exchanger/build.py's own
# constant. It is INHERITED rather than chosen -- the height every socket had before #349 -- and
# models/house-style.md records that a look chosen for them would be a decision nobody has been
# asked for. Quoted here rather than imported because build.py needs bpy.
CONTAINED_Z = 0.55


def report(covers_dir, bare_dir, all_dir):
    frames = sorted(f for f in os.listdir(covers_dir) if f.endswith(".png"))
    print(f"Pipe covers measured by subtracting runs of scripts/probe-pipe-cover-miss.ps1:\n"
          f"  as it ships        : {covers_dir}\n"
          f"  contained stripped : {bare_dir}\n"
          f"  all stripped       : {all_dir or '(not given -- plumbable sockets read NO COVER)'}\n"
          f"Everything that differs between two runs is a cover. 'drop' is how far BELOW the "
          f"socket's drawn\naxis the cover's centre sits and 'reach' how far OUTBOARD of its mouth "
          f"-- both signed, both in\nframe pixels at the frame's own zoom.")
    total_frames = 0
    for frame in frames:
        try:
            sidecar, found, (unplaced, whole) = sockets_in(frame, covers_dir, bare_dir, all_dir)
        except socket_strip.Unmeasurable as why:
            print(f"\n{frame}\n  not measured: {why}")
            continue
        total_frames += 1
        zoom, ppt = sidecar["zoom"], sidecar["pixels_per_tile"]
        print(f"\n{frame} -- zoom {zoom:g}, {ppt:g} px to the tile")
        if not found and not unplaced:
            print("  no machine of ours is in this frame")
        if unplaced:
            who = ", ".join(unplaced)
            if whole is None:
                print(f"  {who}: nothing in this frame changed between the runs, so no cover is "
                      f"drawn here that the declaration controls")
            else:
                top, bottom, left, right, _, _, pixels = whole
                print(f"  {who}: cover(s) somewhere in {right - left + 1}x{bottom - top + 1} px, "
                      f"{pixels} drawn. No committed geometry file for these, so this cannot say "
                      f"which socket each belongs to -- look at the frame")
        for name, s in found:
            if s.cover is None:
                print(f"  {name:28} {s.label:36} NO COVER: nothing within "
                      f"{WINDOW_TILES:g} tile of this connection changed between the two runs")
                continue
            top, bottom, left, right, crow, ccol, pixels = s.cover
            size = f"{right - left + 1}x{bottom - top + 1} px, {pixels} drawn"
            if s.drop is None:
                print(f"  {name:28} {s.label:36} cover {size}; no rendered sheet, so this "
                      f"machine has no drawn axis to measure against")
            else:
                reach = f"{s.reach:+.1f} px" if s.reach is not None else "n/a on this axis"
                print(f"  {name:28} {s.label:36} cover {size}; "
                      f"drop {s.drop:+.1f} px ({s.drop / ppt:+.3f} tiles), reach {reach}")
    print(f"\n{total_frames} frame(s) measured. Nothing above says what the miss OUGHT to be; "
          f"#391 weighs the remedies.")
    print(f"For reference and NOT as a source of any figure above: a contained socket is built at "
          f"world height {CONTAINED_Z}, a plumbable one at {rf.SOCKET_Z}, and this camera draws one "
          f"tile of world height\n{SCREEN_PER_WORLD:.5f} tiles up the screen -- so the projection "
          f"predicts drops of {CONTAINED_Z * SCREEN_PER_WORLD:.3f} and "
          f"{rf.SOCKET_Z * SCREEN_PER_WORLD:.3f} tiles.")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="How far a pipe cover misses the socket it belongs to, by subtracting two runs.")
    parser.add_argument("covers", help="output directory of a run WITH pipe covers")
    parser.add_argument("bare", help="the same run with -Strip contained")
    parser.add_argument("--all", dest="all_dir",
                        help="the same run with -Strip all; without it a plumbable socket has no "
                             "cover to subtract and the contained figure has no control")
    args = parser.parse_args(argv)
    for d in [args.covers, args.bare] + ([args.all_dir] if args.all_dir else []):
        if not os.path.isdir(d):
            sys.exit(f"measure-pipe-cover-miss: {d} is not a directory")
    if not args.all_dir:
        print("NOTE: no --all directory, so every plumbable socket below reads NO COVER -- its own\n"
              "      cover survives the `contained` run. #390 asks for it as the control; pass one.\n")
    return report(args.covers, args.bare, args.all_dir)


if __name__ == "__main__":
    sys.exit(main())

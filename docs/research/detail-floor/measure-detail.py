#!/usr/bin/env python3
"""Measure how wide a sprite's detail features are, in ours and in vanilla's.

    python docs/research/detail-floor/measure-detail.py [--factorio-data DIR] [--json]

Written for #335, which had to choose a detail floor and found the house style's 0.125 tiles was
four times vanilla's median. It stays committed so a future Factorio can be asked the same question
by rerunning it rather than by re-deriving the method (CLAUDE.md's rule for a probe).

WHAT IT MEASURES, and the caveat that decides what the number means. Each sheet is high-passed
against a 9 px box blur, so a run is a feature against its LOCAL surround -- a rivet against the
panel it sits on, a groove against the plate it is cut into -- and not a whole part against the
background. Both signs are counted, because a raised feature is lighter than its surround and a cut
one darker. Only opaque pixels take part.

That catches SURFACE GRAIN as well as deliberate features, so the median is "typical
high-frequency feature", NOT "smallest intentional one". It is the same procedure on both sides, so
the comparison holds; do not quote the median as a design target. The clean figure for a deliberate
feature is the hand measurement `--rivets` prints, over vanilla's boiler hatch.

Vanilla's sheets are 64 px per tile drawn at scale 0.5, the same convention as ours, so one pixel
there is one pixel here and the two columns are directly comparable.
"""
import argparse
import glob
import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

# docs/research/detail-floor/ -> the repository root: four levels, not three. Three lands on
# docs/ and the glob below then finds none of our own sheets and reports vanilla alone.
REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))))
RENDERED = os.path.join(REPO, "realistic-fusion-refreshed-assets", "graphics", "rendered")
PX_PER_TILE = 64          # the sheet's own resolution; models/rf_blender.py fixes it
SHIP_SCALE = 0.5          # what pictures.lua draws at, so a tile is 32 px on the player's screen

BLUR_RADIUS = 4           # a 9 px box: wide enough to pass a panel, narrow enough to keep a rivet
CONTRAST = 14             # luminance a run must differ from its surround by, of 255
OPAQUE = 200              # alpha below this is an edge pixel, where a run length means nothing

# The five vanilla machines measured for #335, relative to the base mod's graphics/entity.
VANILLA = {
    "boiler": "boiler/boiler-N-idle.png",
    "heat exchanger": "heat-exchanger/heatex-N-idle.png",
    "storage tank": "storage-tank/storage-tank.png",
    "electric furnace": "electric-furnace/electric-furnace.png",
    "chemical plant": "chemical-plant/chemical-plant.png",
}

# Vanilla's boiler hatch, whose rivet rows are DELIBERATE features rather than grain: the frame
# around the front hatch, in sheet pixels on boiler-N-idle.png.
HATCH_ROWS = range(63, 74)
HATCH_COLS = (112, 165)


def find_factorio_data(given):
    """The base mod's graphics/entity directory. --factorio-data, then $FACTORIO_EXE's install,
    then the Steam libraries this machine has. Matches what scripts/check-*.ps1 do for the exe."""
    candidates = []
    if given:
        candidates.append(given)
    exe = os.environ.get("FACTORIO_EXE")
    if exe:
        # <install>/bin/x64/factorio.exe -> <install>/data
        candidates.append(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(exe))), "data"))
    for root in ("C:/Program Files (x86)/Steam", "C:/Program Files/Steam", "D:/SteamLibrary",
                 "C:/SteamLibrary", os.path.expanduser("~/.steam/steam")):
        candidates.append(os.path.join(root, "steamapps/common/Factorio/data"))
    candidates += sorted(glob.glob("?:/*/steamapps/common/Factorio/data"))
    for c in candidates:
        entity = os.path.join(c, "base", "graphics", "entity")
        if os.path.isdir(entity):
            return entity
    return None


def detail_widths(path):
    """Every high-frequency run inside the opaque area, as an array of widths in sheet pixels."""
    a = np.asarray(Image.open(path).convert("RGBA")).astype(float)
    lum, alpha = a[..., :3].mean(axis=2), a[..., 3]
    blur = np.asarray(Image.fromarray(lum.astype(np.uint8))
                      .filter(ImageFilter.BoxBlur(BLUR_RADIUS))).astype(float)
    high_pass = lum - blur
    widths = []
    for y in range(a.shape[0]):
        if (alpha[y] > OPAQUE).sum() < 20:          # a row with almost nothing on it
            continue
        for sign in (1, -1):
            run = 0
            for lit in (high_pass[y] * sign > CONTRAST) & (alpha[y] > OPAQUE):
                if lit:
                    run += 1
                elif run:
                    widths.append(run)
                    run = 0
            if run:
                widths.append(run)
    return np.array(widths)


def hatch_rivets(path):
    """Widths of the light runs across vanilla's boiler hatch rivet rows -- a hand-picked window
    over features that are certainly deliberate, as the cross-check on the automatic sweep."""
    a = np.asarray(Image.open(path).convert("RGBA")).astype(float)
    lum = a[..., :3].mean(axis=2)
    widths = []
    for y in HATCH_ROWS:
        segment = lum[y, HATCH_COLS[0]:HATCH_COLS[1]]
        above = segment - np.median(segment)
        run = 0
        for lit in above > 12:
            if lit:
                run += 1
            elif run:
                widths.append(run)
                run = 0
        if run:
            widths.append(run)
    return np.array(widths)


def row(label, widths):
    return {
        "sheet": label,
        "runs": int(len(widths)),
        "p10_px": float(np.percentile(widths, 10)),
        "median_px": float(np.median(widths)),
        "p90_px": float(np.percentile(widths, 90)),
        "median_tiles": float(np.median(widths) / PX_PER_TILE),
        "median_screen_px": float(np.median(widths) * SHIP_SCALE),
    }


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--factorio-data", help="base mod graphics/entity; found automatically if omitted")
    ap.add_argument("--rivets", action="store_true", help="also print the hand measurement")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)

    entity = find_factorio_data(a.factorio_data)
    rows = []
    if entity:
        for label, rel in VANILLA.items():
            path = os.path.join(entity, rel)
            if os.path.exists(path):
                rows.append(row(f"vanilla {label}", detail_widths(path)))
            else:
                print(f"  (missing: {path})", file=sys.stderr)
    else:
        print("no Factorio data directory found; measuring ours only. Pass --factorio-data.",
              file=sys.stderr)

    for manifest in sorted(glob.glob(os.path.join(RENDERED, "*", "manifest.json"))):
        machine = os.path.basename(os.path.dirname(manifest))
        sheet = os.path.join(os.path.dirname(manifest), f"{machine}.png")
        if os.path.exists(sheet):
            rows.append(row(f"ours {machine}", detail_widths(sheet)))

    if a.json:
        print(json.dumps(rows, indent=2))
        return

    print(f"{'sheet':30} {'runs':>7} {'p10':>5} {'median':>7} {'p90':>5}  {'tiles':>7} {'screen px':>10}")
    for r in rows:
        print(f"{r['sheet']:30} {r['runs']:7d} {r['p10_px']:5.0f} {r['median_px']:7.1f} "
              f"{r['p90_px']:5.0f}  {r['median_tiles']:7.3f} {r['median_screen_px']:10.1f}")
    print("\nThe median counts surface grain as well as deliberate features. Read it as 'typical "
          "high-frequency\nfeature', not as a design target.")

    if a.rivets and entity:
        path = os.path.join(entity, VANILLA["boiler"])
        if os.path.exists(path):
            w = hatch_rivets(path)
            print(f"\nvanilla boiler hatch rivets, {len(w)} runs over rows "
                  f"{HATCH_ROWS.start}-{HATCH_ROWS.stop - 1}:")
            print(f"  median {np.median(w):.1f} px = {np.median(w)/PX_PER_TILE:.3f} tiles "
                  f"= {np.median(w)*SHIP_SCALE:.1f} px on the player's screen")
            print(f"  range  {w.min():.0f}-{np.percentile(w, 90):.0f} px")


if __name__ == "__main__":
    main()

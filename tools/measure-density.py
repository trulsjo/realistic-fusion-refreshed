#!/usr/bin/env python3
"""Two density figures for rendered art: how much of a sheet is edge (#799).

    python tools/measure-density.py SHEET [SHEET ...]        pixel figure for any sheet
    python tools/measure-density.py --machine heat-exchanger  both figures for one of ours
    python tools/measure-density.py --self-test

THE PIXEL FIGURE is the share of a sheet's opaque pixels that are edge: a pixel whose luminance
differs from a 9 px box blur of its surround by more than the contrast threshold, either sign.
The blur, the threshold, the opacity cut and the luminance are
docs/research/detail-floor/measure-detail.py's, imported rather than copied. What is done with them
differs: that script measures the widths of runs along rows, and this one counts a share of an
area. A straight ramp has no edge, and a sharp step counts only above about 32 of 255, since
next to a step the 9 px blur already holds 5 of its pixels' side. It reads pixels only,
so it runs on ours, vanilla's, Krastorio 2's or anyone's sheet, and it cannot tell a valve from
grime, procedural noise or Cycles noise: all of them are edge to it.

THE NORMAL-PASS FIGURE is the same count on a normal pass of our own model, rendered by
models/render-normal.py with the north sheet's rig, frame and camera, so both figures describe the
same pixels. An edge there is a change of surface direction in any of the three channels. A
material cannot raise it -- grime, noise and texture do not bend a surface -- so a rise has to be
shape. It needs the model, so it exists for our machines only.

THE SILHOUETTE IS LEFT OUT OF BOTH. The blur reaches past a machine's outline into transparency,
which would count the outline itself as edge and favour small machines, whose outline is a larger
share of their area. Only pixels at least the blur's radius inside the opaque area are counted.

What neither sees is in docs/research/density-figures.md.
"""
import argparse
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
RENDERED = os.path.join(REPO, "realistic-fusion-refreshed-assets", "graphics", "rendered")

_spec = importlib.util.spec_from_file_location(
    "measure_detail", os.path.join(REPO, "docs", "research", "detail-floor", "measure-detail.py"))
_detail = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_detail)
BLUR_RADIUS, CONTRAST, OPAQUE = _detail.BLUR_RADIUS, _detail.CONTRAST, _detail.OPAQUE


def _blur(channel):
    return np.asarray(Image.fromarray(np.clip(channel, 0, 255).astype(np.uint8))
                      .filter(ImageFilter.BoxBlur(BLUR_RADIUS))).astype(float)


def edge_density(channels, alpha):
    """Share of the interior's pixels that are edge in any channel. `channels` is H x W x C in
    0..255, `alpha` H x W in 0..255. Returns (density, interior pixel count)."""
    opaque = alpha > OPAQUE
    # Inside by the blur's radius: a min filter over the mask drops every pixel the blur could
    # reach transparency from.
    side = 2 * BLUR_RADIUS + 1
    interior = np.asarray(Image.fromarray(opaque.astype(np.uint8) * 255)
                          .filter(ImageFilter.MinFilter(side))) > 0
    edge = np.zeros(alpha.shape, dtype=bool)
    for c in range(channels.shape[2]):
        edge |= np.abs(channels[..., c] - _blur(channels[..., c])) > CONTRAST
    n = int(interior.sum())
    return (float((edge & interior).sum()) / n if n else 0.0), n


def pixel_density(path):
    """The pixel figure for any RGBA sheet."""
    a = np.asarray(Image.open(path).convert("RGBA")).astype(float)
    return edge_density(a[..., :3].mean(axis=2, keepdims=True), a[..., 3])


def normal_density(path):
    """The normal-pass figure, on the PNG models/render-normal.py writes."""
    a = np.asarray(Image.open(path).convert("RGBA")).astype(float)
    return edge_density(a[..., :3], a[..., 3])


def render_normal(machine, blender, samples):
    """Render the normal pass into a new temporary directory and return the PNG's path. The caller
    removes the directory."""
    model = os.path.join(REPO, "models", machine, f"{machine}.blend")
    if not os.path.isfile(model):
        sys.exit(f"{machine}: no model at {model}")
    out = os.path.join(tempfile.mkdtemp(prefix="rf-normal-"), f"{machine}-normal.png")
    r = subprocess.run([blender, "-b", model, "--python-exit-code", "1", "--python",
                        os.path.join(REPO, "models", "render-normal.py"), "--", out,
                        "--samples", str(samples)], capture_output=True, text=True)
    if r.returncode or not os.path.isfile(out):
        sys.exit(f"render-normal.py failed for {machine}:\n{r.stdout[-2000:]}\n{r.stderr[-2000:]}")
    return out


def self_test():
    """Fails if the edge count breaks: a flat interior has none, a stripe has some, transparency,
    the outline and a step just under the smallest that counts are never counted, a step just over
    it is, and a fold in a normal map is."""
    size = 64
    alpha = np.zeros((size, size)); alpha[8:56, 8:56] = 255
    flat = np.full((size, size, 1), 120.0)
    d, n = edge_density(flat, alpha)
    assert d == 0.0 and n > 0, f"a flat square has no edge, got {d} over {n}"

    # The outline: the same square on black, as a sheet's transparent margin is. Without the
    # interior's erosion the blur reaches the black and the square's own edge counts.
    on_black = np.zeros((size, size, 1)); on_black[8:56, 8:56] = 120
    assert edge_density(on_black, alpha)[0] == 0.0, "the outline must not count"

    striped = flat.copy(); striped[:, 30:32] = 200
    d_stripe, _ = edge_density(striped, alpha)
    assert d_stripe > 0.0, "a bright stripe across the interior must count"

    outside = flat.copy(); outside[0:4, :] = 255          # in the transparent margin
    assert edge_density(outside, alpha)[0] == 0.0, "transparent pixels must not count"

    # A sharp step shows 4/9 of itself against the blur, so the smallest that counts is just over
    # CONTRAST * 9 / 4: 31 does not and 33 does. Pinning both sides catches a moved threshold.
    faint = flat.copy(); faint[:, 32:] = 120 + 31
    assert edge_density(faint, alpha)[0] == 0.0, "a step of 31 is under the smallest that counts"
    sharp = flat.copy(); sharp[:, 32:] = 120 + 33
    assert edge_density(sharp, alpha)[0] > 0.0, "a step of 33 must count"

    # A normal map: one flat face, then a fold down the middle, seen in channels other than the
    # first, so a count that read one channel only would miss it.
    up = np.zeros((size, size, 3)); up[...] = (128, 128, 255)
    folded = up.copy(); folded[:, 32:] = (128, 200, 200)
    assert edge_density(up, alpha)[0] == 0.0
    assert edge_density(folded, alpha)[0] > 0.0, "a fold in the normals must count"
    print("measure-density self-test: OK")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("sheets", nargs="*", help="RGBA sheets for the pixel figure")
    ap.add_argument("--machine", help="one of ours, e.g. heat-exchanger: both figures")
    ap.add_argument("--blender", help="path to blender.exe, found as render-machine.py finds it")
    ap.add_argument("--samples", type=int, default=16)
    ap.add_argument("--keep", action="store_true",
                    help="keep the normal pass and print its path; otherwise it is deleted")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args(argv)
    if a.self_test:
        return self_test()
    if not a.sheets and not a.machine:
        ap.error("give sheets, --machine, or --self-test")

    rows = []
    for sheet in a.sheets:
        d, n = pixel_density(sheet)
        rows.append({"sheet": sheet, "figure": "pixel", "density": d, "pixels": n})
    if a.machine:
        sheet = os.path.join(RENDERED, a.machine, f"{a.machine}.png")
        d, n = pixel_density(sheet)
        rows.append({"sheet": os.path.relpath(sheet, REPO).replace(os.sep, "/"),
                     "figure": "pixel", "density": d, "pixels": n})
        spec = importlib.util.spec_from_file_location("render_machine",
                                                      os.path.join(HERE, "render-machine.py"))
        rm = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(rm)
        normal = render_normal(a.machine, rm.find_blender(a.blender), a.samples)
        d, n = normal_density(normal)
        rows.append({"sheet": f"{a.machine} normal pass, {a.samples} samples"
                     + (f" ({normal})" if a.keep else ""), "figure": "normal", "density": d,
                     "pixels": n})
        if not a.keep:
            shutil.rmtree(os.path.dirname(normal), ignore_errors=True)

    if a.json:
        print(json.dumps(rows, indent=2))
        return
    print(f"{'figure':7} {'density':>8} {'pixels':>9}  sheet")
    for r in rows:
        print(f"{r['figure']:7} {r['density']:8.4f} {r['pixels']:9d}  {r['sheet']}")
    print(f"\nblur radius {BLUR_RADIUS} px, contrast {CONTRAST} of 255, opaque above {OPAQUE}; "
          "the outline is left out.")


if __name__ == "__main__":
    main()

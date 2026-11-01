#!/usr/bin/env python3
"""Put a machine's rendered sheets from several git refs side by side in one PNG (#853).

    python tools/compare-sheets.py rf-<machine> <ref> [<ref> ...] --out OUT.png [--direction north]
                                   [--crop NAME=X0,Y0,X1,Y1 ...] [--scale 3]
    python tools/compare-sheets.py --self-test

A change Truls judges by eye is put to him the same way every time: one picture of the sheet as each
ref has it, left to right in the order given, each under a label naming its ref. Until #853 every
art ticket wrote its own scratch script to do it, #847 three of them, once per rebuild round.

A ref is anything `git show` reads (`origin/main`, a branch, a commit), or `worktree` for the files
as they stand. Each ref's sheet is read from git, so nothing is checked out. The sheet is the
structure sheet of the direction asked for, `<machine>.png` for north and `-e`, `-s`, `-w` for the
others, laid over a dark ground so its edges show, as the game would lay it over a floor.

--crop names a box in tiles of the footprint: X0,Y0 its top-left and X1,Y1 its bottom-right
corner, the footprint's own top-left corner being 0,0 and its bottom-right the machine's width and
height in tiles as the sheet shows them. A coordinate may be negative, or past the footprint, to
take in the margin, which is where height and shadow are drawn. A tile is the manifest's
pixels_per_tile both ways, since the render squares the ground, and each ref's own manifest places
its box, so two refs with different margins crop the same ground. Each crop is written beside
OUT.png as OUT-<name>.png, across the same refs, magnified --scale times (nearest neighbour, so a
pixel stays a pixel).

--SELF-TEST builds a scratch repository whose sheet, a stand-in with one quarter marked, changes
across two commits and the working tree, and proves the layout: three panels in ref order, each its
ref's sheet at its own place with a gap between, each label drawn and each different, and a crop
of the marked quarter that is the mark and nothing else, magnified as asked. It needs Pillow, as
every tool here that reads a sheet does, and git. scripts/run-gates.ps1 runs it among its tools'
self-tests. The workflow in .github/workflows/gates.yml does not: its runner's Python has no Pillow.
"""
import argparse
import io
import json
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RENDERED = "realistic-fusion-refreshed-assets/graphics/rendered"
SUFFIX = {"north": "", "east": "-e", "south": "-s", "west": "-w"}
GROUND = (40, 44, 40, 255)
INK = (230, 230, 220, 255)
LABEL_H = 18                       # the strip above each panel its ref is written in
GAP = 8                            # between panels, of the ground
WORKTREE = "worktree"


def read_at(root, ref, rel):
    """The bytes of `rel` as `ref` holds it, or as the working tree does."""
    if ref == WORKTREE:
        with open(os.path.join(root, rel), "rb") as f:
            return f.read()
    r = subprocess.run(["git", "-C", root, "show", f"{ref}:{rel}"], capture_output=True)
    if r.returncode != 0:
        sys.exit(f"compare-sheets: {ref} has no {rel}: {r.stderr.decode(errors='replace').strip()}")
    return r.stdout


def sheet_at(root, machine, direction, ref):
    """(the sheet over the ground, the frame of the manifest beside it) as `ref` holds them."""
    base = f"{RENDERED}/{machine}"
    sheet = Image.open(io.BytesIO(read_at(root, ref, f"{base}/{machine}{SUFFIX[direction]}.png"))).convert("RGBA")
    frame = json.loads(read_at(root, ref, f"{base}/manifest.json"))["frame"]
    ground = Image.new("RGBA", sheet.size, GROUND)
    ground.alpha_composite(sheet)
    return ground, frame


def crop_box(frame, box):
    """The pixel box of a box in footprint tiles, on a sheet with this manifest frame."""
    ppt, margin = frame["pixels_per_tile"], frame["margin_tiles"]
    x0, y0, x1, y1 = box
    return tuple(int(round((margin + v) * ppt)) for v in (x0, y0, x1, y1))


def side_by_side(panels):
    """One image: each (label, picture) left to right under its label, GAP apart. A column is as
    wide as its picture, or its label where that is wider, so no label runs into the next."""
    measure = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    widths = [max(p.width, int(measure.textlength(label)) + 4) for label, p in panels]
    out = Image.new("RGBA", (sum(widths) + GAP * (len(panels) - 1), LABEL_H + max(p.height for _, p in panels)), GROUND)
    draw = ImageDraw.Draw(out)
    x = 0
    for (label, picture), width in zip(panels, widths):
        draw.text((x + 2, 3), label, fill=INK)
        out.alpha_composite(picture, (x, LABEL_H))
        x += width + GAP
    return out


def magnify(picture, scale):
    w, h = picture.size
    return picture.resize((max(1, round(w * scale)), max(1, round(h * scale))),
                          Image.NEAREST if scale >= 1 else Image.LANCZOS)


def compare(root, machine, direction, refs, out, crops=(), scale=3.0):
    """Write OUT and one OUT-<name>.png per crop; returns the paths written."""
    sheets = [(ref, *sheet_at(root, machine, direction, ref)) for ref in refs]
    side_by_side([(ref, sheet) for ref, sheet, _ in sheets]).save(out)
    written = [out]
    stem, ext = os.path.splitext(out)
    for name, box in crops:
        panels = [(f"{ref} {name}", magnify(sheet.crop(crop_box(frame, box)), scale))
                  for ref, sheet, frame in sheets]
        path = f"{stem}-{name}{ext}"
        side_by_side(panels).save(path)
        written.append(path)
    return written


def parse_crop(text):
    name, _, numbers = text.partition("=")
    values = [float(v) for v in numbers.split(",")]
    if not name or len(values) != 4 or values[0] >= values[2] or values[1] >= values[3]:
        raise argparse.ArgumentTypeError(f"{text!r}: a crop is NAME=X0,Y0,X1,Y1, top-left before bottom-right")
    return name, tuple(values)


# ---- the self-test --------------------------------------------------------------------------------

def self_test():
    wrong = []
    ppt, margin, tiles = 16, 1.0, (4, 2)
    size = (int((tiles[0] + 2 * margin) * ppt), int((tiles[1] + 2 * margin) * ppt))   # 96 by 64, wider than a label
    colours = [(200, 0, 0, 255), (0, 200, 0, 255), (0, 0, 200, 255)]
    mark = (255, 255, 0, 255)
    with tempfile.TemporaryDirectory(prefix="rf-compare-test-") as root:
        base = os.path.join(root, *RENDERED.split("/"), "m")
        os.makedirs(base)

        def git(*args):
            subprocess.run(["git", "-C", root, "-c", "user.name=t", "-c", "user.email=t@t", *args],
                           check=True, capture_output=True)

        def plant(colour):
            # The sheet one colour, with the footprint's top-left tile marked.
            sheet = Image.new("RGBA", size, colour)
            at = int(margin * ppt)
            sheet.paste(mark, (at, at, at + ppt, at + ppt))
            sheet.save(os.path.join(base, "m.png"))
            with open(os.path.join(base, "manifest.json"), "w", encoding="utf-8") as f:
                json.dump({"frame": {"pixels_per_tile": ppt, "margin_tiles": margin, "tiles": list(tiles)}}, f)

        git("init", "-q", "-b", "main")
        plant(colours[0])
        git("add", "-A")
        git("commit", "-q", "-m", "first")
        git("tag", "first")
        plant(colours[1])
        git("commit", "-q", "-am", "second")
        plant(colours[2])                                 # left in the working tree
        out = os.path.join(root, "out.png")
        written = compare(root, "m", "north", ["first", "HEAD", WORKTREE], out,
                          crops=[("corner", (0, 0, 1, 1))], scale=2)
        if written != [out, os.path.join(root, "out-corner.png")]:
            wrong.append(f"wrote {written!r}")
        img = Image.open(out).convert("RGBA")
        if img.size != (3 * size[0] + 2 * GAP, LABEL_H + size[1]):
            wrong.append(f"three {size} sheets were laid out as {img.size}")
        labels = []
        for k, colour in enumerate(colours):
            x = k * (size[0] + GAP)
            # Each panel is its ref's sheet: its colour away from the mark, in ref order.
            if img.getpixel((x + size[0] - 1, LABEL_H + size[1] - 1)) != colour:
                wrong.append(f"panel {k + 1} is not the sheet its ref holds")
            if k and img.getpixel((x - 1, LABEL_H + 1)) != GROUND:
                wrong.append(f"no gap of the ground before panel {k + 1}")
            strip = img.crop((x, 0, x + size[0], LABEL_H))
            if strip.getcolors() == [(strip.width * strip.height, GROUND)]:
                wrong.append(f"panel {k + 1} has no label drawn")
            labels.append(strip.tobytes())
        if len(set(labels)) != 3:
            wrong.append("two panels' labels are drawn the same, so a label does not name its ref")
        crop = Image.open(os.path.join(root, "out-corner.png")).convert("RGBA")
        if crop.height != LABEL_H + 2 * ppt:
            wrong.append(f"a one-tile crop at scale 2 was laid out {crop.height} px high")
        body = crop.crop((0, LABEL_H, 2 * ppt, LABEL_H + 2 * ppt))
        if [c for _, c in body.getcolors()] != [mark]:
            wrong.append("the crop of the footprint's top-left tile is not that tile alone")
    for w in wrong:
        print(f"WRONG: {w}", file=sys.stderr)
    print(f"compare-sheets: {'a result is wrong' if wrong else 'three refs laid out in order, each labelled, gapped and cropped to the tile asked for'}.")
    return 1 if wrong else 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("machine", nargs="?", help="rf-heat-exchanger or heat-exchanger")
    ap.add_argument("refs", nargs="*", help=f"git refs, or {WORKTREE} for the files as they stand")
    ap.add_argument("--out", help="the PNG to write")
    ap.add_argument("--direction", default="north", choices=sorted(SUFFIX))
    ap.add_argument("--crop", action="append", type=parse_crop, default=[], help="NAME=X0,Y0,X1,Y1 in footprint tiles")
    ap.add_argument("--scale", type=float, default=3.0, help="magnification of each crop")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args(argv)
    if a.self_test:
        return self_test()
    if not a.machine or not a.refs or not a.out:
        ap.error("name a machine, one or more refs and --out, or pass --self-test")
    machine = a.machine[3:] if a.machine.startswith("rf-") else a.machine
    for path in compare(REPO, machine, a.direction, a.refs, a.out, a.crop, a.scale):
        print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())

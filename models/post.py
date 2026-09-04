"""PROTOTYPE (#246): post-process renders with system Python + Pillow.

    python post.py stretch <dir>                  stretch every dir*_*.png by sqrt 2 in Y (construction A)
    python post.py icons <structure.png> <out>    three icon candidates as 120x64 mip strips
    python post.py compare <out.png> <label:png>...   paste PNGs side by side on a checker, for eyeballing
"""
import math
import os
import sys

from PIL import Image, ImageDraw

SQRT2 = math.sqrt(2)


def stretch(d):
    for f in sorted(os.listdir(d)):
        if f.startswith("dir") and f.endswith(".png") and "-A" not in f:
            im = Image.open(os.path.join(d, f)).convert("RGBA")
            w, h = im.size
            im.resize((w, int(round(h * SQRT2))), Image.LANCZOS).save(os.path.join(d, f[:-4] + "-A.png"))
    print("stretched", d)


def mip_strip(square64):
    strip = Image.new("RGBA", (120, 64), (0, 0, 0, 0))
    x = 0
    for s in (64, 32, 16, 8):
        strip.paste(square64.resize((s, s), Image.LANCZOS), (x, 0))
        x += s
    return strip


def fit_square(im, margin=3):
    bbox = im.getbbox()
    im = im.crop(bbox)
    side = max(im.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    return sq.resize((64 - 2 * margin,) * 2, Image.LANCZOS).crop((-margin, -margin, 64 - margin, 64 - margin))


def icons(structure_png, outdir):
    os.makedirs(outdir, exist_ok=True)
    im = Image.open(structure_png).convert("RGBA")
    # 1. whole building, letterboxed (vanilla's rule for oblong subjects)
    mip_strip(fit_square(im)).save(os.path.join(outdir, "icon-whole.png"))
    # 2. a section: the middle 5x5 tiles of the footprint, full frame width crop around centre
    w, h = im.size
    px = 64
    cx, cy = w // 2, int(h * 0.5)
    sec = im.crop((cx - 3 * px, cy - 3 * px, cx + 3 * px, cy + 3 * px))
    mip_strip(fit_square(sec)).save(os.path.join(outdir, "icon-section.png"))
    print("icons in", outdir)


def compare(out, *pairs, cell=None):
    items = []
    for p in pairs:
        label, path = p.split(":", 1)
        items.append((label, Image.open(path).convert("RGBA")))
    scale = 1
    cw = max(im.width for _, im in items) + 24
    ch = max(im.height for _, im in items) + 40
    sheet = Image.new("RGBA", (cw * len(items), ch), (0, 0, 0, 255))
    dr = ImageDraw.Draw(sheet)
    for x in range(0, sheet.width, 32):
        for y in range(0, sheet.height, 32):
            if (x // 32 + y // 32) % 2:
                dr.rectangle((x, y, x + 31, y + 31), fill=(92, 92, 92, 255))
            else:
                dr.rectangle((x, y, x + 31, y + 31), fill=(72, 72, 72, 255))
    for i, (label, im) in enumerate(items):
        x = i * cw + 12
        sheet.alpha_composite(im, (x, 28))
        dr.text((x, 8), label, fill=(255, 255, 255, 255))
    sheet.save(out)
    print("wrote", out)


if __name__ == "__main__" and sys.argv[1] != "vanilla":
    cmd, *rest = sys.argv[1:]
    {"stretch": stretch, "icons": icons, "compare": compare}[cmd](*rest)


def vanilla(out, ours_a, ours_b):
    """Our render (A stretched, B not) beside vanilla sprites at 64 px/tile on a tile grid.
    Vanilla sprite centre = footprint centre + shift; shifts are util.by_pixel (32 px/tile), so
    doubled here."""
    V = "D:/SteamLibrary/steamapps/common/Factorio/data/base/graphics/entity/"
    T = 64
    sheet = Image.new("RGBA", (T * 36, T * 22), (110, 120, 90, 255))
    dr = ImageDraw.Draw(sheet)
    for x in range(0, sheet.width, T):
        dr.line((x, 0, x, sheet.height), fill=(100, 110, 82, 255))
    for y in range(0, sheet.height, T):
        dr.line((0, y, sheet.width, y), fill=(100, 110, 82, 255))

    def place(img, centre_tile, shift_px32=(0, 0)):
        cx = centre_tile[0] * T + shift_px32[0] * 2
        cy = centre_tile[1] * T + shift_px32[1] * 2
        sheet.alpha_composite(img, (int(round(cx - img.width / 2)), int(round(cy - img.height / 2))))

    def ours(path, centre_tile):
        st = Image.open(path).convert("RGBA")
        sh = Image.open(path.replace("structure", "shadow")).convert("RGBA")
        r, g, b, a = sh.split()
        sh.putalpha(a.point(lambda v: v // 2))
        place(sh, centre_tile)
        place(st, centre_tile)

    hx = Image.open(V + "heat-exchanger/heatex-N-idle.png").convert("RGBA")   # 3x2, shift (-1.25, 5.25)
    hxs = Image.open(V + "heat-exchanger/heatex-N-idle-shadow.png").convert("RGBA") if os.path.exists(V + "heat-exchanger/heatex-N-idle-shadow.png") else None
    chest = Image.open(V + "steel-chest/steel-chest.png").convert("RGBA")   # 1x1, shift (0, -0.5)
    chest_sh = Image.open(V + "steel-chest/steel-chest-shadow.png").convert("RGBA")
    boiler = Image.open(V + "boiler/boiler-N-idle.png").convert("RGBA")   # 3x2, shift (-1.25, 5.25)

    ours(ours_a, (6, 11))
    ours(ours_b, (16, 11))
    dr.text((6 * T - 40, 20), "ours, A (stretched)", fill="white")
    dr.text((16 * T - 40, 20), "ours, B (no stretch)", fill="white")
    place(chest_sh, (24, 4), (5, 0.5)); place(chest, (24, 4), (0, -0.5))
    dr.text((23 * T, 2 * T), "steel chest 1x1", fill="white")
    place(hx, (25, 9), (-1.25, 5.25))
    dr.text((23 * T, 7 * T), "vanilla heat exchanger 3x2", fill="white")
    place(boiler, (25, 15), (-1.25, 5.25))
    dr.text((23 * T, 13 * T), "vanilla boiler 3x2", fill="white")
    # footprint outlines for the vanilla ones and ours
    for (cx, cy, w, h) in ((24, 4, 1, 1), (25, 9, 3, 2), (25, 15, 3, 2), (6, 11, 5, 15), (16, 11, 5, 15)):
        dr.rectangle(((cx - w / 2) * T, (cy - h / 2) * T, (cx + w / 2) * T, (cy + h / 2) * T), outline=(255, 230, 80, 160))
    sheet.save(out)
    print("wrote", out)


if __name__ == "__main__" and sys.argv[1] == "vanilla":
    vanilla(*sys.argv[2:])

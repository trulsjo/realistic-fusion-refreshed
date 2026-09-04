"""Report size, channels and alpha histogram of every PNG in a directory, using bpy.

    blender -b --python verify_pngs.py -- <dir>
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import rf_render  # noqa: E402

d = rf_render.script_args()[0]
for name in sorted(os.listdir(d)):
    if not name.endswith(".png"):
        continue
    img = bpy.data.images.load(os.path.join(d, name))
    w, h, c = img.size[0], img.size[1], img.channels
    px = img.pixels[:]
    alpha = px[3::c] if c == 4 else []
    n = len(alpha) or 1
    a0 = sum(1 for a in alpha if a < 0.01)
    a1 = sum(1 for a in alpha if a > 0.99)
    amid = n - a0 - a1

    def at(x, y):
        i = (y * w + x) * c
        return tuple(round(v, 3) for v in px[i:i + c])

    # Alpha-weighted centroid: moves with the rig direction if the scene is asymmetric.
    sx = sy = sa = 0.0
    x0, y0, x1, y1 = w, h, -1, -1
    for i, a in enumerate(alpha):
        if a > 0.05:
            x, y = i % w, i // w
            sx += a * x
            sy += a * y
            sa += a
            if a > 0.5:   # bounding box of the solid part, in pixels (row 0 is the bottom)
                x0, y0, x1, y1 = min(x0, x), min(y0, y), max(x1, x), max(y1, y)
    cen = (round(sx / sa, 1), round(sy / sa, 1)) if sa else None
    bbox = (x0, y0, x1, y1, x1 - x0 + 1, y1 - y0 + 1) if x1 >= 0 else None

    print(f"{name}: {w}x{h} channels={c} depth={img.depth} "
          f"alpha0={a0 / n:.1%} alpha1={a1 / n:.1%} alphaMid={amid / n:.1%} "
          f"corner={at(0, 0)} centre={at(w // 2, h // 2)} centroid={cen} bbox(x0,y0,x1,y1,w,h)={bbox}")
    bpy.data.images.remove(img)

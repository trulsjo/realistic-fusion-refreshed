#!/usr/bin/env python3
"""Recolour a Krastorio 2 icon, keeping its shading.

Every recoloured icon in this repository is made with this script, so the operation the NOTICE
files describe is one definition rather than a sentence someone has to reproduce by hand.

THE OPERATION

Each pixel keeps its alpha and its Rec. 601 luminance (0.299 R + 0.587 G + 0.114 B) and is
remultiplied by the target colour. Luminance is what carries the sphere's shading and highlight, so
the result reads as the same object in a different colour rather than as a flat silhouette.

TWO-TONE MODE

Some icons are two separate blobs -- K2's nitrogen is two spheres -- and a fuel *mixture* is
honestly drawn as one sphere of each component. With two colours given, opaque pixels are split
between them by k-means on position (k=2) and each blob is recoloured independently. The blob
whose centroid is further up-left takes the first colour, so the assignment does not depend on
which order k-means happens to converge in.

The output is a derivative work of the input and carries the input's licence. Say so in the NOTICE
beside it.

    python tools/recolour-icon.py IN.png OUT.png 0.40,0.92,1.00
    python tools/recolour-icon.py IN.png OUT.png 0.40,0.92,1.00 0.50,1.00,0.60
"""

import sys

from PIL import Image

# Below this, a pixel is background and is left alone rather than being clustered.
OPAQUE = 40


def colour(text):
    parts = [float(v) for v in text.split(",")]
    if len(parts) != 3:
        raise ValueError(f"expected r,g,b -- got {text!r}")
    return parts


def split(points):
    """Two blobs, by k-means on position. Returns the up-left one first."""
    width = max(x for x, _ in points) + 1
    height = max(y for _, y in points) + 1
    a, b = (width * 0.3, height * 0.7), (width * 0.7, height * 0.3)
    group_a, group_b = [], []
    for _ in range(64):
        group_a, group_b = [], []
        for p in points:
            da = (p[0] - a[0]) ** 2 + (p[1] - a[1]) ** 2
            db = (p[0] - b[0]) ** 2 + (p[1] - b[1]) ** 2
            (group_a if da < db else group_b).append(p)
        if not group_a or not group_b:
            raise SystemExit("the image is one blob; two-tone needs two")
        moved_a = (sum(p[0] for p in group_a) / len(group_a), sum(p[1] for p in group_a) / len(group_a))
        moved_b = (sum(p[0] for p in group_b) / len(group_b), sum(p[1] for p in group_b) / len(group_b))
        if (moved_a, moved_b) == (a, b):
            break
        a, b = moved_a, moved_b
    # Order by distance from the top-left corner, so the result does not depend on convergence.
    if (a[0] + a[1]) <= (b[0] + b[1]):
        return set(group_a), set(group_b)
    return set(group_b), set(group_a)


def main(argv):
    if not 4 <= len(argv) <= 5:
        raise SystemExit(__doc__)
    source, target = argv[1], argv[2]
    colours = [colour(c) for c in argv[3:]]

    image = Image.open(source).convert("RGBA")
    pixels = image.load()
    width, height = image.size

    opaque = [(x, y) for y in range(height) for x in range(width) if pixels[x, y][3] > OPAQUE]
    if not opaque:
        raise SystemExit(f"{source} has no opaque pixels")

    first = set(opaque) if len(colours) == 1 else None
    if first is None:
        first, _second = split(opaque)

    for x, y in opaque:
        r, g, b, alpha = pixels[x, y]
        luminance = 0.299 * r + 0.587 * g + 0.114 * b
        cr, cg, cb = colours[0] if (x, y) in first else colours[1]
        pixels[x, y] = (
            min(255, round(luminance * cr)),
            min(255, round(luminance * cg)),
            min(255, round(luminance * cb)),
            alpha,
        )

    image.save(target)
    print(f"{source} -> {target}  ({'/'.join(argv[3:])})")


if __name__ == "__main__":
    main(sys.argv)

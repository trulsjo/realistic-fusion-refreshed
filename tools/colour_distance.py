"""sRGB to CIE L*a*b*, and the CIEDE2000 difference between two Lab colours.

    import colour_distance as cd
    cd.srgb_to_lab((0.60, 0.69, 0.63))        # one colour, or an (N, 3) array of them
    cd.ciede2000(lab_a, lab_b)                # the perceptual distance between two

ITS OWN MODULE BECAUSE IT IS THE ONE PART THAT CAN BE CHECKED AGAINST SOMEBODY ELSE'S ANSWER.
Everything else tools/measure-accent-separation.py does is arithmetic about this repository's own
sheets, which only this repository can grade; CIEDE2000 has a published test set (Sharma, Wu and
Dalal, *Color Research and Application* 30(1), 2005), so tools/test_colour_distance.py grades this
file against thirty-four rows somebody else computed. A formula this fiddly -- seven terms, two
angular wrap-arounds and a hue mean that flips sign across the 0/360 seam -- is exactly the kind
that passes a plausibility read and is wrong in the sixth row.

WHY CIEDE2000 AND NOT dE76. dE76 is a plain Euclidean distance in Lab, and the eye is not Euclidean
in Lab: the same numeric gap in chroma looks smaller the more chroma both colours already carry.
CIEDE2000's SC and SH terms divide by 1 + 0.045 C and 1 + 0.015 C T, so the two formulas part
company most at HIGH chroma -- which is exactly where models/house-style.md's palette rows sit, and
not where the pixels they produce end up. Measured over the four accent pairs in
docs/research/accent-separation.md: dE76 is 1.78 to 2.14 times dE00 on the palette rows and 1.26 to
1.50 on the pixels they draw, every palette figure above every drawn one. A note that used dE76 for
both would report the palette and the sheet as further apart than they are, and the palette worse
than the sheet. The extra lines are the reason this file exists rather than a one-line subtraction.

D65, the sRGB white point, and the sRGB transfer function as IEC 61966-2-1 states it. Needs numpy.
"""
import numpy as np

# The sRGB white point, D65, normalised to Y = 1.
WHITE_D65 = np.array([0.95047, 1.0, 1.08883])

# Linear sRGB to CIE XYZ, D65 (IEC 61966-2-1).
RGB_TO_XYZ = np.array([[0.4124564, 0.3575761, 0.1804375],
                       [0.2126729, 0.7151522, 0.0721750],
                       [0.0193339, 0.1191920, 0.9503041]])


def srgb_to_linear(c):
    """The sRGB transfer function, undone. `c` is 0..1, scalar or array."""
    c = np.asarray(c, dtype=float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    """The sRGB transfer function, applied. The inverse of `srgb_to_linear`."""
    c = np.asarray(c, dtype=float)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.maximum(c, 0) ** (1 / 2.4) - 0.055)


def srgb_to_lab(rgb):
    """CIE L*a*b* of an sRGB colour given 0..1. Takes (3,) or (..., 3) and keeps the shape."""
    linear = srgb_to_linear(rgb)
    xyz = linear @ RGB_TO_XYZ.T / WHITE_D65
    eps = (6 / 29) ** 3
    f = np.where(xyz > eps, np.cbrt(np.maximum(xyz, 0)), xyz / (3 * (6 / 29) ** 2) + 4 / 29)
    fx, fy, fz = f[..., 0], f[..., 1], f[..., 2]
    return np.stack([116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)], axis=-1)


def ciede2000(lab1, lab2):
    """The CIEDE2000 difference between two Lab colours, as a float.

    CIE 142-2001, in Sharma, Wu and Dalal's notation. The two places an implementation goes wrong
    are both handled explicitly below and both are tested: the mean hue angle, which has to be
    pulled across the 0/360 seam when the two hues are more than 180 degrees apart, and a hue
    difference at zero chroma, which is not zero degrees but no angle at all.
    """
    l1, a1, b1 = (float(v) for v in lab1)
    l2, a2, b2 = (float(v) for v in lab2)
    c1, c2 = np.hypot(a1, b1), np.hypot(a2, b2)
    c_bar = (c1 + c2) / 2
    # The a* axis is stretched at low chroma, which is what makes near-neutrals compare sanely.
    g = 0.5 * (1 - np.sqrt(c_bar ** 7 / (c_bar ** 7 + 25.0 ** 7)))
    a1p, a2p = (1 + g) * a1, (1 + g) * a2
    c1p, c2p = np.hypot(a1p, b1), np.hypot(a2p, b2)
    h1p = 0.0 if (a1p == 0 and b1 == 0) else np.degrees(np.arctan2(b1, a1p)) % 360
    h2p = 0.0 if (a2p == 0 and b2 == 0) else np.degrees(np.arctan2(b2, a2p)) % 360

    dlp = l2 - l1
    dcp = c2p - c1p
    if c1p * c2p == 0:
        dhp = 0.0                       # no hue at zero chroma, so no hue difference either
    elif abs(h2p - h1p) <= 180:
        dhp = h2p - h1p
    else:
        dhp = h2p - h1p - 360 if h2p > h1p else h2p - h1p + 360
    dhp_big = 2 * np.sqrt(c1p * c2p) * np.sin(np.radians(dhp) / 2)

    l_bar_p = (l1 + l2) / 2
    c_bar_p = (c1p + c2p) / 2
    if c1p * c2p == 0:
        h_bar_p = h1p + h2p             # one of them is meaningless; the sum is the other one
    elif abs(h1p - h2p) <= 180:
        h_bar_p = (h1p + h2p) / 2
    elif h1p + h2p < 360:
        h_bar_p = (h1p + h2p + 360) / 2
    else:
        h_bar_p = (h1p + h2p - 360) / 2

    t = (1 - 0.17 * np.cos(np.radians(h_bar_p - 30))
           + 0.24 * np.cos(np.radians(2 * h_bar_p))
           + 0.32 * np.cos(np.radians(3 * h_bar_p + 6))
           - 0.20 * np.cos(np.radians(4 * h_bar_p - 63)))
    d_theta = 30 * np.exp(-(((h_bar_p - 275) / 25) ** 2))
    rc = 2 * np.sqrt(c_bar_p ** 7 / (c_bar_p ** 7 + 25.0 ** 7))
    sl = 1 + (0.015 * (l_bar_p - 50) ** 2) / np.sqrt(20 + (l_bar_p - 50) ** 2)
    sc = 1 + 0.045 * c_bar_p
    sh = 1 + 0.015 * c_bar_p * t
    rt = -np.sin(np.radians(2 * d_theta)) * rc

    return float(np.sqrt((dlp / sl) ** 2 + (dcp / sc) ** 2 + (dhp_big / sh) ** 2
                         + rt * (dcp / sc) * (dhp_big / sh)))


def de76(lab1, lab2):
    """The plain Euclidean distance in Lab. Here only so a note can quote both and show the gap."""
    return float(np.linalg.norm(np.asarray(lab1, dtype=float) - np.asarray(lab2, dtype=float)))

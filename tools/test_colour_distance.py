#!/usr/bin/env python3
"""Grade tools/colour_distance.py against somebody else's answers.

    python tools/test_colour_distance.py

THE WHOLE POINT IS THAT THESE NUMBERS ARE NOT OURS. Every other measurement in this repository is
graded against this repository, so a shared mistake passes twice. CIEDE2000 has a published test
set -- Sharma, Wu and Dalal, "The CIEDE2000 Color-Difference Formula: Implementation Notes,
Supplementary Test Data, and Mathematical Observations", Color Research and Application 30(1),
pp. 21-30, 2005, Table 1 -- written by the people who found the traps, and the thirty-four pairs
below are it. They are chosen to straddle the traps: rows 1 to 6 sit in the blue region where the
RT rotation term bites, rows 7 to 16 sit at chroma small enough that the hue mean wraps, and rows
33 and 34 sit near black where SL runs away.

Run it after touching the formula. It needs numpy only, no Factorio and no sheets.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import colour_distance as cd  # noqa: E402

# (L1, a1, b1), (L2, a2, b2), expected dE00 -- Sharma et al. 2005, Table 1, all thirty-four rows.
SHARMA = [
    ((50.0000, 2.6772, -79.7751), (50.0000, 0.0000, -82.7485), 2.0425),
    ((50.0000, 3.1571, -77.2803), (50.0000, 0.0000, -82.7485), 2.8615),
    ((50.0000, 2.8361, -74.0200), (50.0000, 0.0000, -82.7485), 3.4412),
    ((50.0000, -1.3802, -84.2814), (50.0000, 0.0000, -82.7485), 1.0000),
    ((50.0000, -1.1848, -84.8006), (50.0000, 0.0000, -82.7485), 1.0000),
    ((50.0000, -0.9009, -85.5211), (50.0000, 0.0000, -82.7485), 1.0000),
    ((50.0000, 0.0000, 0.0000), (50.0000, -1.0000, 2.0000), 2.3669),
    ((50.0000, -1.0000, 2.0000), (50.0000, 0.0000, 0.0000), 2.3669),
    ((50.0000, 2.4900, -0.0010), (50.0000, -2.4900, 0.0009), 7.1792),
    ((50.0000, 2.4900, -0.0010), (50.0000, -2.4900, 0.0010), 7.1792),
    ((50.0000, 2.4900, -0.0010), (50.0000, -2.4900, 0.0011), 7.2195),
    ((50.0000, 2.4900, -0.0010), (50.0000, -2.4900, 0.0012), 7.2195),
    ((50.0000, -0.0010, 2.4900), (50.0000, 0.0009, -2.4900), 4.8045),
    ((50.0000, -0.0010, 2.4900), (50.0000, 0.0010, -2.4900), 4.8045),
    ((50.0000, -0.0010, 2.4900), (50.0000, 0.0011, -2.4900), 4.7461),
    ((50.0000, 2.5000, 0.0000), (50.0000, 0.0000, -2.5000), 4.3065),
    ((50.0000, 2.5000, 0.0000), (73.0000, 25.0000, -18.0000), 27.1492),
    ((50.0000, 2.5000, 0.0000), (61.0000, -5.0000, 29.0000), 22.8977),
    ((50.0000, 2.5000, 0.0000), (56.0000, -27.0000, -3.0000), 31.9030),
    ((50.0000, 2.5000, 0.0000), (58.0000, 24.0000, 15.0000), 19.4535),
    ((50.0000, 2.5000, 0.0000), (50.0000, 3.1736, 0.5854), 1.0000),
    ((50.0000, 2.5000, 0.0000), (50.0000, 3.2972, 0.0000), 1.0000),
    ((50.0000, 2.5000, 0.0000), (50.0000, 1.8634, 0.5757), 1.0000),
    ((50.0000, 2.5000, 0.0000), (50.0000, 3.2592, 0.3350), 1.0000),
    ((60.2574, -34.0099, 36.2677), (60.4626, -34.1751, 39.4387), 1.2644),
    ((63.0109, -31.0961, -5.8663), (62.8187, -29.7946, -4.0864), 1.2630),
    ((61.2901, 3.7196, -5.3901), (61.4292, 2.2480, -4.9620), 1.8731),
    ((35.0831, -44.1164, 3.7933), (35.0232, -40.0716, 1.5901), 1.8645),
    ((22.7233, 20.0904, -46.6940), (23.0331, 14.9730, -42.5619), 2.0373),
    ((36.4612, 47.8580, 18.3852), (36.2715, 50.5065, 21.2231), 1.4146),
    ((90.8027, -2.0831, 1.4410), (91.1528, -1.6435, 0.0447), 1.4441),
    ((90.9257, -0.5406, -0.9208), (88.6381, -0.8985, -0.7239), 1.5381),
    ((6.7747, -0.2908, -2.4247), (5.8714, -0.0985, -2.2286), 0.6377),
    ((2.0776, 0.0795, -1.1350), (0.9033, -0.0636, -0.5514), 0.9082),
]


def test_sharma():
    """Every published pair, to the four decimals the table gives."""
    for i, (lab1, lab2, want) in enumerate(SHARMA, start=1):
        got = cd.ciede2000(lab1, lab2)
        assert abs(got - want) < 1e-4, f"Sharma row {i}: dE00 {got:.4f}, table says {want:.4f}"


def test_symmetric():
    """Swapping the two colours must not move the answer. Row 7 and row 8 of the table are that
    pair on purpose, and an implementation that gets the hue mean's seam wrong fails only one."""
    for lab1, lab2, _ in SHARMA:
        a, b = cd.ciede2000(lab1, lab2), cd.ciede2000(lab2, lab1)
        assert abs(a - b) < 1e-9, f"{lab1} vs {lab2}: {a:.6f} one way, {b:.6f} the other"


def test_identical_is_zero():
    for lab, _, _ in SHARMA:
        assert cd.ciede2000(lab, lab) == 0.0, lab


def test_srgb_to_lab():
    """Three sRGB colours whose Lab is published wherever the matrix and the white point are.
    They pin the transfer function, the matrix and the D65 white together: white must land at
    L 100 with no chroma, and pure red and blue at their standard places."""
    for rgb, want in (((1.0, 1.0, 1.0), (100.0, 0.0, 0.0)),
                      ((1.0, 0.0, 0.0), (53.2408, 80.0925, 67.2032)),
                      ((0.0, 0.0, 1.0), (32.2970, 79.1875, -107.8602))):
        got = cd.srgb_to_lab(rgb)
        for g, w, axis in zip(got, want, "Lab"):
            assert abs(g - w) < 0.01, f"sRGB {rgb}: {axis}* is {g:.4f}, should be {w:.4f}"


def test_transfer_round_trips():
    """srgb_to_linear and linear_to_srgb must undo each other, including across the 0.04045 knee
    where the curve changes formula -- a knee put in the wrong place passes a midtone test."""
    import numpy as np
    c = np.linspace(0.0, 1.0, 1001)
    back = cd.linear_to_srgb(cd.srgb_to_linear(c))
    assert np.max(np.abs(back - c)) < 1e-9, f"worst round trip error {np.max(np.abs(back - c)):.2e}"


def test_de76_over_reports_a_chroma_difference_more_as_chroma_rises():
    """The reason tools/measure-accent-separation.py pays for CIEDE2000 rather than subtracting.

    THREE PAIRS THAT ARE THE SAME DISTANCE APART BY dE76 AND NOT BY dE00. Each moves a* by ten at a
    fixed L*, so dE76 calls all three exactly 10; dE00 calls them 11.2, 3.9 and 2.5 as the chroma
    they sit at rises, because SC divides a chroma difference by 1 + 0.045 C. That is the whole
    reason this module is not a subtraction, isolated from lightness and from hue -- which is why it
    is built here rather than taken off a Sharma row, where a near-black pair produces a large ratio
    for the unrelated reason that SL runs away at low L*.

    The assertion is the ORDERING and the direction, not any one ratio, so swapping the formula for
    a subtraction fails a test instead of quietly changing every figure in a research note.
    """
    ratios = []
    for chroma in (0.0, 30.0, 60.0):
        a, b = (50.0, chroma, 0.0), (50.0, chroma + 10, 0.0)
        assert abs(cd.de76(a, b) - 10.0) < 1e-9, cd.de76(a, b)
        ratios.append(cd.de76(a, b) / cd.ciede2000(a, b))
    assert ratios[0] < 1 < ratios[1] < ratios[2], [round(r, 3) for r in ratios]
    assert ratios[2] > 3, f"dE76/dE00 at chroma 60 is {ratios[2]:.3f}; it was 3.925"


def main():
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_") and callable(v)]
    for t in tests:
        t()
        print(f"  ok  {t.__name__}")
    print(f"colour_distance: ok ({len(tests)} tests)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

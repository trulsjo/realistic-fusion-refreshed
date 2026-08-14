#!/usr/bin/env python3
"""Derive Maxwellian-averaged fusion reactivities from ENDF cross-sections.

    python tools/derive-reactivities.py <raw-endf-dir> [-o <output.lua>]

Reads ENDF/B-VIII.0 cross-section tables -- energy in eV (laboratory frame), cross-section in
barns -- and integrates each over a Maxwellian distribution to produce <sigma.v>(T), the quantity
the reactor simulation actually needs.

    <sigma.v>(T) = sqrt(8 / (pi * m_r)) * (kT)^-3/2 * INTEGRAL sigma(E) * E * exp(-E/kT) dE

with E and kT in joules, sigma in m^2 and the reduced mass m_r in kg. The integral is a trapezoid
over the tabulated cross-section points, which are dense enough that refining them changes the
result well below the accuracy of the underlying data.

WHY THIS EXISTS
---------------
The archived redesign shipped pre-computed reactivity tables, and they are wrong. Its generator
(`raw-ENDF/.raw-to-reactivity.py`, headed "I have no idea how any of this works, a friend of mine
wrote this") computes reactivity on a temperature grid and then writes those values against the
*cross-section energy* grid -- two arrays of equal length and unrelated meaning. The result peaks
at 2.81e-21 m^3/s around 11.7 keV where D-T should peak near 8.7e-22 m^3/s around 64 keV: about
three times too high, at about a fifth of the right temperature. The duplicated first x value in
those tables is the fingerprint of the raw energy grid it borrowed.

The cross-sections themselves are sound -- D-T peaks at 5.01 barns, as it should -- so this script
keeps the inputs and redoes the derivation.

Only stdlib is used, deliberately: no numpy, no scipy, nothing to install.

Attribution: the raw ENDF tables and the idea of this pipeline come from Romner_set's
`realistic-fusion-dev`, whose `.cross-section-data/` directory carries no licence file and is
therefore permissive under ADR 0001 (that repository's default licence is WTFPL). The underlying
nuclear data is ENDF/B-VIII.0, published by the IAEA: https://www-nds.iaea.org/exfor/endf.htm
"""

import argparse
import hashlib
import json
import math
import pathlib
import sys

BARN = 1.0e-28          # m^2
EV = 1.602176634e-19    # J
U = 1.66053906660e-27   # kg
K_B = 1.380649e-23      # J/K

# Nuclide masses in atomic mass units.
MASS = {"D": 2.014102, "T": 3.016049, "He3": 3.016029}

# channel -> (projectile, stationary target, source file)
# Named explicitly rather than parsed out of filenames: "D-D_T" does not split into a projectile
# and a target the way "D-T" does, and getting the pair wrong silently shifts the whole curve.
CHANNELS = {
    "D-D_T":   ("D", "D", "D-D_T_cross-section.json"),
    "D-D_He3": ("D", "D", "D-D_He3_cross-section.json"),
    "D-T":     ("D", "T", "D-T_cross-section.json"),
    "D-He3":   ("D", "He3", "D-He3_cross-section.json"),
    "He3-He3": ("He3", "He3", "He3-He3_cross-section.json"),
}

# v1's reactions (ADR 0010). D-D is the sum of its two branches, which occur together at roughly
# equal rates -- that is why it breeds both tritium and helium-3. The branches are emitted too,
# because the by-product split needs them.
SUMMED = {"D-D": ("D-D_T", "D-D_He3")}

KELVIN_PER_KEV = 1000.0 * EV / K_B  # ~1.16045e7


def read_cross_section(path, projectile, target):
    """Return [(E_cm in joules, sigma in m^2)], strictly increasing in energy."""
    pts = json.loads(path.read_text())["datasets"][0]["pts"]

    # ENDF tabulates laboratory-frame energy against a stationary target. Only the
    # centre-of-mass energy is available to the reaction.
    to_cm = MASS[target] / (MASS[target] + MASS[projectile])

    out, last_e = [], None
    for p in pts:
        e = p["E"] * EV * to_cm
        # The tables repeat their first energy; a duplicate would contribute a zero-width
        # trapezoid, which is harmless, but dropping it keeps the grid strictly increasing so
        # downstream interpolation is well defined.
        if last_e is not None and e <= last_e:
            continue
        out.append((e, p["Sig"] * BARN))
        last_e = e
    return out


def reactivity(cross_section, temperature_k, reduced_mass_kg):
    """Maxwellian-averaged <sigma.v> in m^3/s at the given temperature."""
    if temperature_k <= 0.0:
        return 0.0
    kt = K_B * temperature_k

    total = 0.0
    prev_e, prev_f = None, None
    for e, sigma in cross_section:
        x = e / kt
        # exp underflows to 0.0 far out in the tail, which is the correct contribution anyway.
        f = sigma * e * math.exp(-x) if x < 700.0 else 0.0
        if prev_e is not None:
            total += 0.5 * (f + prev_f) * (e - prev_e)
        prev_e, prev_f = e, f

    return math.sqrt(8.0 / (math.pi * reduced_mass_kg)) * kt ** -1.5 * total


def temperature_grid():
    """Log-spaced kelvin, 0.2 keV to 600 keV, with an explicit zero at the bottom.

    Log spacing because the interesting structure is the threshold rise over two decades, and a
    linear grid would either miss it or be enormous."""
    lo, hi, n = math.log(0.2), math.log(600.0), 160
    grid = [0.0]
    for i in range(n):
        kev = math.exp(lo + (hi - lo) * i / (n - 1))
        grid.append(kev * KELVIN_PER_KEV)
    return grid


def format_lua(tables, inputs):
    lines = [
        "-- GENERATED FILE -- do not edit by hand.",
        "--",
        "-- Maxwellian-averaged fusion reactivities <sigma.v>, in m^3/s, against plasma",
        "-- temperature in kelvin. Regenerate with:",
        "--",
        "--     python tools/derive-reactivities.py tools/endf",
        "--",
        "-- Built from these inputs (sha256, first 16), committed under tools/endf so that command",
        "-- can actually be run:",
    ]
    for name in sorted(inputs):
        lines.append("--     %-28s %s" % (name, inputs[name]))
    lines += [
        "--",
        "-- Derived from ENDF/B-VIII.0 cross-sections (https://www-nds.iaea.org/exfor/endf.htm).",
        "-- The raw tables come from Romner_set's realistic-fusion-dev, whose .cross-section-data/",
        "-- directory carries no licence file and is permissive under ADR 0001; that repository's",
        "-- default licence is WTFPL. The reactivities there were NOT reused: their generator",
        "-- paired the temperature grid with the cross-section energy grid, putting the D-T peak",
        "-- about 3x too high at about a fifth of the right temperature. See tools/",
        "-- derive-reactivities.py.",
        "--",
        "-- D-D is the sum of its two branches; both are kept separately for the by-product split.",
        "",
        "return {",
    ]
    for name in sorted(tables):
        pts = tables[name]
        lines.append('  ["%s"] = {' % name)
        chunk = []
        for t, v in pts:
            chunk.append("{%.6g,%.6g}" % (t, v))
        # Wrapped rather than one line per point: 160 points x 6 tables is a lot of lines, and
        # this file is read by machines far more often than by people.
        for i in range(0, len(chunk), 6):
            lines.append("    " + ",".join(chunk[i:i + 6]) + ",")
        lines.append("  },")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("raw_dir", type=pathlib.Path, help="directory of *_cross-section.json files")
    ap.add_argument("-o", "--output", type=pathlib.Path,
                    default=pathlib.Path("RealisticFusion/cross-section-data/reactivities.lua"))
    args = ap.parse_args()

    grid = temperature_grid()
    tables = {}
    inputs = {}

    for name, (projectile, target, filename) in CHANNELS.items():
        path = args.raw_dir / filename
        if not path.exists():
            sys.exit("missing cross-section file: %s" % path)
        # Hash the input so the generated file records exactly what produced it. Without this,
        # "regenerate with ..." is a claim rather than an instruction.
        inputs[filename] = hashlib.sha256(path.read_bytes()).hexdigest()[:16]
        xs = read_cross_section(path, projectile, target)
        m_r = MASS[projectile] * MASS[target] / (MASS[projectile] + MASS[target]) * U
        tables[name] = [(t, reactivity(xs, t, m_r)) for t in grid]
        peak = max(tables[name], key=lambda p: p[1])
        print("  %-9s %3d pts  peak %.3g m^3/s at %.1f keV"
              % (name, len(xs), peak[1], peak[0] / KELVIN_PER_KEV))

    for summed, parts in SUMMED.items():
        tables[summed] = [(t, sum(tables[p][i][1] for p in parts)) for i, t in enumerate(grid)]
        peak = max(tables[summed], key=lambda p: p[1])
        print("  %-9s (sum of %s)  peak %.3g m^3/s at %.1f keV"
              % (summed, " + ".join(parts), peak[1], peak[0] / KELVIN_PER_KEV))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(format_lua(tables, inputs), encoding="utf-8")
    print("wrote %s" % args.output)


if __name__ == "__main__":
    main()

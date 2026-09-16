#!/usr/bin/env python3
"""Fail when a piece of a socket is drawn lopsided about its axis, or at a width its model denies.

    python tools/check-socket-parts.py <manifest.json> [...]          # gate: exit 1 on a mismatch
    python tools/check-socket-parts.py --self-test <manifest.json> [...]

A GATE, and the second one here that reads pixels. tools/check-socket-height.py asks where a
socket's ENVELOPE is drawn -- one number per socket, against a vanilla pipe. This asks a different
question of the same strip, piece by piece: is each part of the socket drawn as far above its axis
as below it, and is it as wide as the model says it drew it.

WHY SYMMETRY IS THE TICKET'S CLAIM AND NOT A WEAKER ONE (#373). The rule Truls set is that a
plumbable socket's TUBE draws vanilla's barrel extent above AND below the axis the two share.
Vanilla's barrel is symmetric about that axis -- +19.5 px either way on
base/graphics/entity/pipe/pipe-straight-horizontal.png -- so "stands proud of the barrel by the
same amount above and below" and "draws the same extent either side of its own axis" are one
assertion. The second needs no vanilla sheet to make, which is why this gate opens none.

AND THE TUBE IS NOT WHAT IS MEASURED, because on a shipped plumbable sheet nothing draws it: the
flange ribs leave 1.15 px of bare tube between them and no whole column falls clear of both, so
tools/socket_strip.py reports NO WINDOW and is right to. What is measured is every piece that IS
visible -- the accent band, the flange ribs, the dark rim, and on a CONTAINED socket the bare tube
as well, since that one wears neither rim nor ribs. Each sits a fixed offset from the tube that
models/rf_blender.py holds, so a tube that misses shows up in all of them at once.

EVERY SOCKET, NOT ONLY THE PLUMBABLE ONES, which is where this parts company with
tools/check-socket-height.py on purpose. That gate is blind to a CONTAINED connection (ADR 0018),
because a contained socket meets a machine face and matching it to a pipe would be wrong. Symmetry
is a claim about the RENDERER rather than about meeting a pipe: the ground plane cut whatever
reached below it, so a contained socket drawn low enough was cut the same way. Truls, 2026-09-16.

WHAT THE TWO ASSERTIONS CATCH, AND WHY NEITHER ALONE IS ENOUGH. Symmetry catches the underside
being eaten -- the defect this file was written for -- but a socket built at the wrong RADIUS is
cut evenly and passes it. The width pin catches that, by holding each part's mean extent against
what a cylinder of its recorded radius must draw. Nothing gated the radius before this: a
manifest's `geometry` block is tools/extract-geometry.py's copy of the live prototype, and a
Factorio prototype records no radius and no height at all. The `sockets` block models/render.py
writes since #373 is the model's own statement of what it drew, and this pin is what checks it.

A MISSING RECORD IS A FAILURE, NOT A SKIP, and the two have separate verdicts so that they cannot
be confused again. A manifest written before #373 carries no `sockets` block, and a gate that passed
quietly on one would be the silent pass this repository has already paid for twice. Every connection
the geometry records must have a socket record, and that record's own `plumbable` must agree with
what the connection's `connection_category` says; a connection failing either is reported NOT
CHECKED and fails the run, where a part with no window of its own is reported UNMEASURABLE and does
not. `failing` below is the one place that difference is decided, and every half of the self-test
judges through it.
"""
import argparse
import json
import os
import sys

try:
    import numpy as np
    from PIL import Image
except ImportError as missing:
    sys.exit(f"check-socket-parts: {missing}. This reads sprite pixels and needs both pillow and "
             f"numpy in the `python` on PATH -- `python -m pip install pillow numpy`.")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                "models"))
import rf_blender as rf  # noqa: E402,F401  (no bpy at module level; imported for the header's sake)
import socket_strip  # noqa: E402

Unmeasurable = socket_strip.Unmeasurable

# THE TWO REASONS A ROW CARRIES NO NUMBER, AND THEY ARE NOT THE SAME KIND OF THING.
#
# A SKIP is expected and is not a finding: a plumbable socket's bare tube has no column of its own
# on any shipped sheet, because the flange ribs leave 1.15 px between them, so every plumbable
# socket reports one skipped part for ever and that is correct.
#
# NOT CHECKED is a FAILURE. It means this gate was asked about a socket and could not judge it at
# all -- no record in the manifest, a record the prototype contradicts, a sheet that cannot be
# opened, or every part of the socket skipped at once. The header's promise that "A MISSING RECORD
# IS A FAILURE, NOT A SKIP" is this distinction and nothing else, and the first version of this
# file did not have it: every unreadable row came back UNMEASURABLE, `failing` let UNMEASURABLE
# through, and a manifest with no `sockets` block at all printed "ok" and exited 0. That is the
# silent pass the header says this gate exists to refuse, and it shipped inside the gate that
# refuses it.
SKIP, NOT_CHECKED = "UNMEASURABLE", "NOT CHECKED"


def skip(why):
    return (SKIP, str(why))


def unchecked(why):
    return (NOT_CHECKED, str(why))


def failing(verdicts):
    """The verdicts that must fail a run. ONE DEFINITION, because `main` and every half of the
    self-test have to mean the same thing by "fails" -- self-test 4 used to assert the row LABEL
    instead, which is why it stayed green while `main` passed the very manifest it was named for."""
    return [v for v in verdicts if v not in ("ok", SKIP)]

# HOW FAR THE TWO EDGES OF ONE PART MAY DIFFER, in pixels of the sheet.
#
# MEASURED, NOT PICKED. docs/research/socket-underside-cut.md rendered thirty-six bare cylinders
# across six radii and six heights with the ground plane deleted, and the largest asymmetry over
# the whole grid was 0.9 px -- at radius 0.45 and height 0.10, an extreme neither machine is
# anywhere near. That 0.9 is half a pixel of row-edge quantisation at each end and nothing else, so
# 1.0 is the quantisation with no room for anything else to hide in.
#
# WHAT IT FAILS, which is the point of it: with the ground plane still cutting, rf-isotope-collector's
# dark rim read +30.5 above its axis and +26.5 below. Four pixels apart, four times this.
SYMMETRY_TOLERANCE_PX = 1.0

# HOW FAR A PART'S MEAN EXTENT MAY STAND PROUD OF THE CYLINDER THAT CAST IT, in pixels.
#
# ONE-SIDED, AND THE SIGN IS THE WHOLE OF IT. A drawn edge spreads OUTWARD past its geometry -- the
# bevel, and Cycles' 1.5 px reconstruction filter -- so a part always measures a little MORE than
# r / sin(pitch) and never less. The measured spread is +0.5 to +1.0 px on every part of both
# machines (models/house-style.md's socket table), so the window below holds it with the margin
# doubled.
#
# IT IS THE RADIUS THIS CATCHES, not the height: a socket built ten percent thick draws 2 px wide
# of its record, which is the far end of this window. Anything subtler is below what whole rows
# read at an alpha floor can see, and saying so here is better than a tolerance that pretends
# otherwise.
WIDTH_SPREAD_PX = (0.0, 2.0)


def socket_record(manifest, connection):
    """The `sockets` entry for one connection, found by POSITION.

    Position is the one field unique to a connection: a machine can carry two on the same side, and
    rf-heat-exchanger does -- water and reactor energy on the same short end, one plumbable and one
    not, drawn at different heights and different thicknesses.

    Raises Unmeasurable rather than returning None, so a manifest with no record reads as a failed
    row for that connection rather than as a socket quietly missing from the report.
    """
    want = list(connection["position"])
    for record in manifest.get("sockets", []):
        if list(record["position"]) == want:
            return record
    raise Unmeasurable(
        f"the manifest records no socket drawn at position {want}. Either the model predates the "
        f"`sockets` block (#373) and wants re-rendering, or models/rf_parts.socket was not what "
        f"drew this connection")


def check(manifest_path, sheets, rows, sockets=None, cut=None):
    """Measure every part of every socket one manifest records, appending a row per part.

    `sheets` loads a sheet, `sockets` returns the manifest's socket records, and `cut` may damage a
    socket's strip once it has been isolated. All three are passed rather than read here so the
    self-test can hand over a shaved socket or a lying record and watch this fail, which is the only
    way a gate can be shown still able to.

    `cut` ACTS ON THE STRIP AND NOT ON THE SHEET, and the difference is not cosmetic. A sheet-wide
    shave takes the lowest drawn pixel of each COLUMN, which on a machine 5 by 15 tiles is some
    other part of the machine further down the frame and not the socket at all -- three of
    rf-heat-exchanger's sockets survived exactly that, so the first version of this canary proved
    nothing about them. A strip's rows are a band about that connection's own ground line, and its
    measured columns lie outboard of the collision edge, so inside both there is nothing drawn but
    the socket.
    """
    manifest = json.load(open(manifest_path, encoding="utf-8"))
    machine, geometry = manifest["machine"], manifest["geometry"]
    manifest = dict(manifest, sockets=(sockets or (lambda m: m.get("sockets", [])))(manifest))
    for connection in geometry["connections"]:
        label = f"{connection['direction']} {connection['fluid']}"
        declared = socket_strip.plumbable(connection)
        try:
            record = socket_record(manifest, connection)
            if bool(record["plumbable"]) != declared:
                raise Unmeasurable(
                    f"the model says it drew this "
                    f"{'plumbable' if record['plumbable'] else 'contained'} and the prototype "
                    f"declares it {'plumbable' if declared else 'contained'} "
                    f"(connection_category {connection['connection_category']!r}, ADR 0018)")
            suffix, _, _ = socket_strip.sheet_frame(manifest, connection)
            strip = socket_strip.strip(sheets(os.path.dirname(manifest_path), machine, suffix),
                                       manifest, connection)
            if cut is not None:
                strip = cut(strip)
            axis = strip.axis_row(record["z"])
        except Unmeasurable as why:
            # NOT CHECKED rather than skipped: a socket whose record or whose sheet cannot be read
            # has not been judged, and saying so quietly would be the silent pass.
            rows.append((geometry["name"], label, "-", None, None, None, None, unchecked(why)))
            continue
        measured = 0
        for name, radius, back_near, back_far in socket_strip.parts_of(record["radius"], declared):
            uncut = radius * socket_strip.UNCUT_PER_RADIUS * strip.px_per_tile
            window = strip.columns_of(back_near, back_far)
            if window is None:
                rows.append((geometry["name"], label, name, radius, uncut, None, None,
                             skip("no column of this sheet draws it clear of its neighbours")))
                continue
            try:
                above, below, unstable = strip.measure(axis, *window)
            except Unmeasurable as cannot:
                rows.append((geometry["name"], label, name, radius, uncut, None, None,
                             skip(cannot)))
                continue
            if unstable is not None:
                rows.append((geometry["name"], label, name, radius, uncut, None, None,
                             skip(f"the reading moves with its column window: {unstable}")))
                continue
            rows.append((geometry["name"], label, name, radius, uncut, above, below, None))
            measured += 1
        if not measured:
            # NOT A PASS. A socket every part of which was skipped has been looked at and not
            # judged, and the rows above say why each part was skipped -- but the socket itself is
            # unchecked, and a gate that let that through would check nothing at all on the day
            # tools/socket_strip.py's window guard tightened by one column.
            rows.append((geometry["name"], label, "(all of it)", None, None, None, None,
                         unchecked("not one part of it could be measured; the rows above say why "
                                   "each. The socket has been looked at and not judged")))
    return rows


def report(rows):
    """Print one line per part; return each one's verdict, in the same order."""
    verdicts = []
    for name, label, part, radius, uncut, above, below, why in rows:
        if why is not None:
            verdict, text = why
            print(f"  {name:22s} {label:22s} {part:12s} {verdict}: {text}")
            verdicts.append(verdict)
            continue
        lopsided = above - below
        spread = (above + below) / 2 - uncut
        verdict = "ok"
        if abs(lopsided) > SYMMETRY_TOLERANCE_PX:
            verdict = "LOPSIDED"
        elif not WIDTH_SPREAD_PX[0] <= spread <= WIDTH_SPREAD_PX[1]:
            verdict = "TOO WIDE" if spread > WIDTH_SPREAD_PX[1] else "TOO NARROW"
        print(f"  {name:22s} {label:22s} {part:12s} r {radius:.3f}  "
              f"{above:+6.1f} above {below:+6.1f} below  ({lopsided:+.1f} apart, tolerance "
              f"{SYMMETRY_TOLERANCE_PX}; {spread:+.1f} proud of {uncut:.1f}, window "
              f"{WIDTH_SPREAD_PX[0]:+.1f}..{WIDTH_SPREAD_PX[1]:+.1f}): {verdict}")
        verdicts.append(verdict)
    return verdicts


def load_sheet(directory, machine, suffix):
    path = os.path.join(directory, f"{machine}{suffix}.png")
    if not os.path.exists(path):
        raise Unmeasurable(f"{os.path.basename(path)} is not there")
    return np.asarray(Image.open(path).convert("RGBA"))[..., 3]


def shaved_strip(rows):
    """Take `rows` pixels off the bottom of whatever is drawn inside a socket's own strip.

    THE CANARY FOR SYMMETRY, and it is the defect itself rather than an imitation of one: the ground
    plane ate the lowest drawn pixels of a socket and left its top edge untouched, which is exactly
    this. It works off the alpha and the strip's own bounds, and reads no part geometry and no
    constant of its own, so it cannot accidentally agree with the arithmetic it is meant to test.
    """
    def cut(strip):
        alpha = strip.alpha.copy()
        band = alpha[strip.row0:strip.row1]
        for _ in range(rows):
            opaque = band > socket_strip.ALPHA_FLOOR
            lowest = opaque.shape[0] - 1 - opaque[::-1].argmax(axis=0)
            drawn = np.nonzero(opaque.any(axis=0))[0]
            band[lowest[drawn], drawn] = 0
        strip.alpha = alpha
        return strip
    return cut


def scaled_records(factor):
    """Socket records whose radius is `factor` times what the model drew.

    THE CANARY FOR THE WIDTH PIN, and it lies in the RECORD rather than in the pixels -- which is
    the direction that matters, because the record is the one thing here nothing else can check.
    """
    def sockets(manifest):
        return [dict(record, radius=record["radius"] * factor)
                for record in manifest.get("sockets", [])]
    return sockets


def self_test(manifests):
    """Four halves: the shipped sheets pass; a shaved sheet is caught; a lying record is caught;
    and a manifest with no record at all fails rather than passing quietly.

    THE LAST TWO ARE NOT ONE HALF. A wrong radius is a record that disagrees with the pixels; an
    absent record is a manifest this gate cannot judge at all. The first must fail on the width pin
    and the second before a pixel is read, and a gate could get one right and the other wrong.
    """
    print("self-test 1/4: every socket on the shipped sheets must pass.")
    rows = []
    for manifest in manifests:
        check(manifest, load_sheet, rows)
    verdicts = report(rows)
    if not any(v == "ok" for v in verdicts):
        print("FAILED - self-test: not one part was measured at all, so the halves below would "
              "pass over an empty report.")
        return 1
    bad = failing(verdicts)
    if bad:
        print(f"FAILED - self-test: {len(bad)} part(s) fail on the sheets as they stand, so this "
              f"gate cannot tell a regression from the state it was handed.")
        return 1
    was_ok = [i for i, v in enumerate(verdicts) if v == "ok"]

    shave = int(SYMMETRY_TOLERANCE_PX) + 2
    print(f"self-test 2/4: every socket shaved {shave} px along its underside must be reported "
          f"LOPSIDED on every part that passed above.")
    rows = []
    for manifest in manifests:
        check(manifest, load_sheet, rows, cut=shaved_strip(shave))
    shaved = report(rows)
    missed = [i for i in was_ok if shaved[i] != "LOPSIDED"]
    if missed:
        print(f"FAILED - self-test: {len(missed)} part(s) had {shave} px taken off underneath and "
              f"this gate called none of them lopsided.")
        return 1

    print("self-test 3/4: the same sheets against a record claiming a socket 20 percent thicker "
          "must be reported TOO NARROW on every part that passed above.")
    rows = []
    for manifest in manifests:
        check(manifest, load_sheet, rows, sockets=scaled_records(1.2))
    lied = report(rows)
    missed = [i for i in was_ok if lied[i] != "TOO NARROW"]
    if missed:
        print(f"FAILED - self-test: {len(missed)} part(s) were judged against a radius 20 percent "
              f"wider than the model drew and this gate called none of them narrow.")
        return 1

    print("self-test 4/4: a manifest recording no socket at all must FAIL THE RUN, not merely be "
          "labelled.")
    rows = []
    for manifest in manifests:
        check(manifest, load_sheet, rows, sockets=lambda m: [])
    empty = report(rows)
    # THE ASSERTION IS `failing`, WHICH IS WHAT main() DECIDES ON. Asserting the row label instead
    # is what this half used to do, and it passed while `main` exited 0 on the very manifest this
    # half is named for: NOT CHECKED had not been separated from UNMEASURABLE, and UNMEASURABLE
    # does not fail a run. A half that tests a layer the gate does not decide on proves nothing.
    if not empty:
        print("FAILED - self-test: a manifest recording no socket produced no rows at all, so "
              "there was nothing to judge.")
        return 1
    if len(failing(empty)) != len(empty):
        print(f"FAILED - self-test: {len(empty) - len(failing(empty))} row(s) of a manifest "
              f"recording no socket did not fail the run, so this gate would report `ok` on a "
              f"machine whose sockets it never checked.")
        return 1
    if not all(v == NOT_CHECKED for v in empty):
        print("FAILED - self-test: those rows fail the run but are not reported as NOT CHECKED, "
              "so the reason a reader is given is the wrong one.")
        return 1

    print("self-test: all four halves pass.")
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("manifests", nargs="+", help="graphics/rendered/<machine>/manifest.json")
    ap.add_argument("--self-test", action="store_true",
                    help="prove this gate can still fail, then exit")
    a = ap.parse_args(argv)
    if a.self_test:
        return self_test(a.manifests)

    rows = []
    for manifest in a.manifests:
        check(manifest, load_sheet, rows)
    print(f"check-socket-parts: {len(rows)} part(s) of "
          f"{len({(r[0], r[1]) for r in rows})} socket(s) on {len(a.manifests)} machine(s)")
    verdicts = report(rows)
    bad = failing(verdicts)
    skipped = [v for v in verdicts if v == SKIP]
    if bad:
        print(f"FAILED - check-socket-parts: {len(bad)} row(s) failed. A part not drawn the same "
              f"distance either side of its axis, or not the width the model recorded, is the TUBE "
              f"missing vanilla's barrel -- every piece of a socket is coaxial with it (#373, "
              f"models/house-style.md), and the band is not the thing to move. A row reported "
              f"{NOT_CHECKED} is a socket this gate could not judge at all, which is a failure in "
              f"its own right: see the reason on the row.")
        return 1
    print(f"check-socket-parts: ok ({len(verdicts) - len(skipped)} part(s) measured, "
          f"{len(skipped)} not measurable -- a plumbable socket's bare tube is never one of the "
          f"measurable ones, and that is expected rather than a gap)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

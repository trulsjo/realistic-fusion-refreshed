#!/usr/bin/env python3
"""Measure what cuts a socket's underside: bare cylinders across radius and height, and one machine
rendered with the shadow-catching ground plane taken away.

    python scripts/probe-socket-underside.py cylinders --out <scratch>
    python scripts/probe-socket-underside.py machine   --out <scratch>
    python scripts/probe-socket-underside.py cylinders --out <scratch> --reuse   # skip Blender

A PROBE, NOT A CHECK AND NOT A BENCH. Exit 0 means the pictures were taken and the numbers read,
never that the answer was the hoped-for one. It asserts nothing about whether a socket is right, it
is not run by scripts/load-check.ps1, and nothing fails because of it. It stays committed so the
next engine version can be asked the same question. Findings belong in docs/research/ and on #362.

WHERE IT LIVES WAS #366'S AND #367'S TO SETTLE, AND THIS PARAGRAPH IS IT SETTLED. It is a probe, so
it goes in scripts/ with the other probes; it is Python rather than PowerShell, because what it
reads is a sprite sheet and that is not a thing this repository does from PowerShell.

NOTHING ABOUT IT IS NEW, WHICH IS THE POINT. scripts/probe-sprite-geometry.py is a Python probe in
this directory that reads sprite sheets and starts no game, and scripts/probe-flange-free-render.ps1
drives Blender and starts no game either -- so neither the language, nor the Blender dependency, nor
being gameless is a first. CLAUDE.md's paragraph on probes said a probe builds a real map; it was
already wrong about four of the twenty PowerShell ones and about probe-sprite-geometry.py, and it
now says what is actually true.

AN EARLIER DRAFT OF THIS PARAGRAPH SAID BLENDER WAS THE NEW PART, and counted nineteen PowerShell
probes. Both were taken before this branch was rebased onto the main that carries #376's
probe-flange-free-render.ps1, and neither was retaken afterwards. A count is a measurement; rebasing
is a change that supersedes one.

WHAT IT ANSWERS

  cylinders   #367. models/socket-cylinders.py's grid -- six radii by six heights of plain
              tube on the shipped rig -- rendered twice, once as built and once with the ground plane deleted,
              and every cylinder measured both ways. Six radii and six heights rather than four
              points off one machine, and bare tube rather than a socket with a rim, a band and two
              flange ribs crowding the thing being read.

  machine     #366. The shipped machine rendered four ways -- as it ships, with
              models/socket-variants.py's `groundless` treatment, with its `unflanged` one, and
              with both -- and tools/measure-socket-parts.py run over each. Two variables at two
              levels, because the ground plane is the subject and the flange ribs are what stop the
              STUB being measurable at all: they leave 1.15 px of tube between them, so a sheet
              wearing them reports the stub as having NO WINDOW. The bottom row is the only sheet
              that carries a machine's own stub with the plane gone. That tool is run as a
              subprocess, unchanged.

THE MODEL BEING TESTED, and it has NO FITTED PARAMETER. If the ground plane hides everything below
world z 0, then a cylinder of radius r whose axis is at height z draws, below that axis:

    sqrt(r^2 - z^2) + SCREEN_PER_WORLD * z        when z < r * cos(pitch), the plane biting
    UNCUT_PER_RADIUS * r                          otherwise, the whole tube standing clear

Both constants come from the camera in models/rf_blender.py by way of tools/socket_strip.py, and
nothing here is tuned to the data. So every row printed is a PREDICTION rather than a fit, which is
a stronger thing to hold a measurement against and the reason this file fits nothing.

AND THE COMPARISON IS EDGE AGAINST EDGE, which is the part worth reading slowly. A drawn edge
spreads past the geometry that cast it -- the bevel and the reconstruction filter -- so every part
of every socket measures about a pixel MORE than its prediction, at the bottom as well as the top.
So `loses` is not the residual. THE RESIDUAL IS THE BOTTOM'S EXCESS OVER ITS PREDICTION MINUS THE
TOP'S OWN EXCESS OVER ITS PREDICTION -- `below - gains - predicted`, where `gains` is the top's
excess because the top's prediction is the uncut extent. The two excesses cancel, so it is zero when
the model is right whatever the spread is. A comparison that forgets that reports a pixel of
anti-aliasing as a pixel of occlusion, which is how #362 came to hold a table nobody could fit.

WHERE THE NUMBERS ARE READ. tools/socket_strip.py, the same module and the same two cuts
tools/check-socket-height.py and tools/measure-socket-parts.py read through: the outboard column
strip, the rows a tile either side of a connection's ground line, the alpha floor, and the window
guard that refuses a reading which moves when its window is narrowed by one column at either end. A
number this prints as UNUSABLE is not a finding about the art.

NOTHING IT MAKES CAN SHIP. Both Blender scripts refuse to write into models/ or the Assets mod, and
--out is refused inside any of this repository's mods. The renders are throwaway and are not
committed; what is committed is the recipe.

Needs Blender, and pillow and numpy in the `python` on PATH. Run from the repository root.
"""
import argparse
import importlib.util
import json
import math
import os
import shutil
import subprocess
import sys

try:
    import numpy as np
    from PIL import Image
except ImportError as missing:
    sys.exit(f"probe-socket-underside: {missing}. This reads sprite pixels and needs both pillow "
             f"and numpy in the `python` on PATH -- `python -m pip install pillow numpy`.")

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
# tools/ IS WHERE THE SPRITE ARITHMETIC LIVES, and this file is in scripts/ with the other probes, so
# the two directories are named apart rather than both taken off this file's own. Three things come
# out of tools/: the module below, the Blender lookup, and the bench this runs as a subprocess.
TOOLS = os.path.join(REPO, "tools")
sys.path.insert(0, TOOLS)
sys.path.insert(0, os.path.join(REPO, "models"))
import rf_blender as rf  # noqa: E402  (no bpy at module level)
import socket_strip  # noqa: E402

# Where along the tube a bare cylinder is read, in tiles inboard from the footprint edge. Far enough
# in that the bevel on the tube's end cap is behind the window, and clear of the collision edge --
# tools/socket_strip.py's `reach` trims the far end to that anyway, so the number only has to be no
# smaller than the strip.
WINDOW_NEAR, WINDOW_FAR = 0.08, 0.25

# The machine, connection and tube radius the `machine` scene reads by default: the row
# models/house-style.md's socket table was measured on.
DEFAULT_MACHINE, DEFAULT_DIRECTION, DEFAULT_RADIUS = "isotope-collector", "west", 0.249


def find_blender(given):
    """tools/render-machine.py's own lookup, loaded rather than copied: --blender, $BLENDER_EXE, a
    running blender.exe, the portable unzip in Downloads, Program Files. A second copy of that
    search is how a probe and a render come to disagree about which Blender drew a sheet."""
    spec = importlib.util.spec_from_file_location("rm", os.path.join(TOOLS, "render-machine.py"))
    rm = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(rm)
    return rm.find_blender(given)


def run_blender(blender, script, args, blend=None,
                echo=("SOCKET-CYLINDERS", "SOCKET-VARIANTS")):
    """One headless Blender run, with the lines the script meant for a reader passed through."""
    cmd = [blender, "-b"]
    if blend:
        cmd.append(blend)
    cmd += ["--python-exit-code", "1", "--python", os.path.join(REPO, script), "--"] + list(args)
    done = subprocess.run(cmd, capture_output=True, text=True)
    for line in (done.stdout or "").splitlines():
        if any(line.startswith(tag) for tag in echo):
            print("  " + line)
    if done.returncode != 0:
        sys.exit(f"probe-socket-underside: {script} failed (exit {done.returncode}).\n"
                 + (done.stdout or "")[-4000:] + (done.stderr or "")[-4000:])


def guard(out_dir):
    """Refuse an --out inside any of this repository's mods, or inside models/.

    The same two roots both Blender scripts refuse on their own out paths, refused once more here
    because this is what chooses theirs -- and EARLIER than they can, which is why it is not
    redundant. `scene_machine` creates its working directory and copies geometry.json into it
    before Blender is started at all, so an --out under models/ would have written two files into
    a shipped directory before socket-variants.py got the chance to say no. A probe whose whole
    claim is that nothing it makes can ship should enforce that rather than state it.
    """
    full = os.path.normcase(os.path.abspath(out_dir))
    guarded = ["models"] + sorted(d for d in os.listdir(REPO)
                                  if d.startswith("realistic-fusion-refreshed")
                                  and os.path.isdir(os.path.join(REPO, d)))
    for mod in guarded:
        root = os.path.normcase(os.path.abspath(os.path.join(REPO, mod)))
        if full == root or full.startswith(root + os.sep):
            sys.exit(f"probe-socket-underside: --out {out_dir} is inside {mod}/, where shipped "
                     f"files live. Everything this writes is throwaway; give a directory outside "
                     f"models/ and outside every mod.")


def below_predicted(radius, z, plane=True):
    """What a cylinder of `radius` whose axis is at height `z` draws BELOW that axis, in tiles, and
    whether the ground plane reaches it at all.

    With `plane`, the model is "everything under world z 0 is hidden and nothing else is". Without
    it -- the render that has no plane in it -- the prediction is the uncut silhouette for every
    row, which is what makes the two tables comparable: the same residual column then measures the
    same thing in both, and the whole question is whether it is the same SIZE in both.

    The plane stops reaching a cylinder at z = r cos(pitch), which is how far under its own axis a
    silhouette's lowest point sits. Above that the tube stands clear and the two models agree.
    """
    lowest = radius * math.cos(math.radians(rf.CAMERA_PITCH_DEG))
    if not plane or z >= lowest:
        return radius * socket_strip.UNCUT_PER_RADIUS, False
    return math.sqrt(max(radius ** 2 - z ** 2, 0.0)) + z / math.tan(math.radians(rf.CAMERA_PITCH_DEG)), True


def sheet_alpha(directory, machine, suffix):
    path = os.path.join(directory, f"{machine}{suffix}.png")
    if not os.path.exists(path):
        sys.exit(f"probe-socket-underside: {path} is not there. Drop --reuse to render it.")
    return np.asarray(Image.open(path).convert("RGBA"))[..., 3]


# ---- the cylinder grid (#367) ------------------------------------------------------------------

def measure_scene(sheets, scene, plane):
    """One row per cylinder: radius, height, what is drawn either side of its axis, and what the
    no-fitted-parameter model above predicts underneath. Returns the rows; prints nothing."""
    manifest = json.load(open(os.path.join(sheets, "manifest.json"), encoding="utf-8"))
    px = manifest["frame"]["pixels_per_tile"]
    rows = []
    for item in scene["cylinders"]:
        connection = next(c for c in manifest["geometry"]["connections"]
                          if c["direction"] == item["direction"]
                          and list(c["position"]) == list(item["position"]))
        suffix, _, _ = socket_strip.sheet_frame(manifest, connection)
        row = dict(item, window=None, above=None, below=None, why=None, resid=None)
        try:
            s = socket_strip.strip(sheet_alpha(sheets, manifest["machine"], suffix),
                                   manifest, connection)
            window = s.columns_of(WINDOW_NEAR, WINDOW_FAR)
            if window is None:
                row["why"] = "no column of this sheet draws that stretch of tube clear of its ends"
            else:
                row["window"] = window
                row["above"], row["below"], row["why"] = s.measure(s.axis_row(item["z"]), *window)
        except socket_strip.Unmeasurable as cannot:
            row["why"] = str(cannot)
        row["uncut"] = item["radius"] * socket_strip.UNCUT_PER_RADIUS * px
        predicted, row["cut"] = below_predicted(item["radius"], item["z"], plane)
        row["predicted"] = predicted * px
        rows.append(row)
    return rows


def print_scene(title, rows, plane):
    print(f"\n{title}")
    print(f"  {'radius':>6} {'z':>6} {'uncut':>6} {'above':>7} {'below':>7} {'gains':>6} "
          f"{'loses':>6} {'pred':>6} {'resid':>6}  window")
    unstable = 0
    for r in rows:
        if r["above"] is None or r["why"] is not None:
            unstable += 1
            print(f"  {r['radius']:>6.3f} {r['z']:>6.3f} {r['uncut']:>6.1f} "
                  f"{'':>7} {'':>7} {'':>6} {'':>6} {r['predicted']:>6.1f} {'':>6}"
                  f"  UNUSABLE: {r['why']}")
            continue
        gains = r["above"] - r["uncut"]
        loses = r["uncut"] - r["below"]
        # THE BOTTOM'S EXCESS OVER ITS PREDICTION, MINUS THE TOP'S OWN EXCESS OVER ITS PREDICTION.
        # Both edges are drawn edges and both stand the same fraction of a pixel proud of the
        # geometry that cast them -- the bevel and the reconstruction filter -- so the two excesses
        # cancel and what is left is zero when the model is right, whatever the spread happens to
        # be. `gains` IS the top's excess, because the top's prediction is the uncut extent.
        #
        # IT ADDED `gains` UNTIL THE REVIEW OF THIS BRANCH, which cancelled nothing and left twice
        # the spread standing in the column -- about +1.5 px on every row, cut or uncut. The verdict
        # survived it, because the same formula ran on both groups and they still matched, but the
        # column did not mean what this comment said and the answer looked four times looser than it
        # is. Subtracting, the whole grid lands inside a pixel of zero.
        resid = r["below"] - gains - r["predicted"]
        r["gains"], r["loses"], r["resid"] = gains, loses, resid
        print(f"  {r['radius']:>6.3f} {r['z']:>6.3f} {r['uncut']:>6.1f} {r['above']:>+7.1f} "
              f"{r['below']:>+7.1f} {gains:>+6.1f} {loses:>+6.1f} {r['predicted']:>6.1f} "
              f"{resid:>+6.1f}  cols {r['window'][0]}..{r['window'][1]}"
              + ("" if r["cut"] or not plane else "   (plane does not reach this one)"))
    if unstable:
        print(f"  {unstable} of {len(rows)} row(s) carry no number this probe will stand behind.")
    # THE RESIDUAL IS THE WHOLE VERDICT, so it is summarised rather than left to be eyeballed over
    # thirty-six rows. On the render that HAS a plane it is split by whether the plane reaches the
    # cylinder: if the plane is the cause and the model of it is right, the two groups are the same
    # size, and what they measure is the edge spread rather than any occlusion. On the render that
    # has none there is no split to make -- every row is an uncut cylinder, and "the plane does not
    # reach this one" said of a scene with no plane in it is the opposite of informative.
    if plane:
        groups = ((True, "the plane reaches"), (False, "the plane does not reach"))
    else:
        groups = ((False, "measured with no plane in the scene"),)
    for reached, label in groups:
        got = [r["resid"] for r in rows if r.get("resid") is not None and r["cut"] is reached]
        if got:
            print(f"  residual over the {len(got)} row(s) {label}: "
                  f"{min(got):+.1f} to {max(got):+.1f} px, mean {sum(got) / len(got):+.1f}")
    return unstable


def scene_cylinders(a, blender):
    """Render the grid twice, with the ground plane and without, and measure both."""
    out = {}
    for tag, extra in (("ground", []), ("no-ground", ["--no-ground"])):
        model = os.path.join(a.out, tag, "cylinders.blend")
        sheets = os.path.join(a.out, tag, "sheets")
        if not a.reuse:
            print(f"\nbuilding and rendering the cylinders, {tag} ...")
            run_blender(blender, "models/socket-cylinders.py", [model] + extra)
            run_blender(blender, "models/render.py",
                        ["--samples", str(a.samples), "--directions", "1", "--out", sheets],
                        blend=model)
        scene = json.load(open(os.path.join(a.out, tag, "cylinders.json"), encoding="utf-8"))
        # THE SCENE SAYS WHICH WAY IT WAS BUILT, AND THAT IS READ RATHER THAN INFERRED FROM THE
        # DIRECTORY NAME. Under --reuse the directory is whatever was there last time, and
        # measuring a scene that still has its plane against the no-plane prediction would print a
        # whole table of plausible wrong residuals.
        if scene["ground"] != (tag == "ground"):
            sys.exit(f"probe-socket-underside: {os.path.join(a.out, tag)} holds a scene built with "
                     f"the ground plane {'present' if scene['ground'] else 'removed'}, which is not "
                     f"what this half of the comparison is. Drop --reuse, or point --out somewhere "
                     f"else.")
        if abs(scene["uncut_per_radius"] - socket_strip.UNCUT_PER_RADIUS) > 1e-9:
            sys.exit(f"probe-socket-underside: the scene was built through a camera drawing "
                     f"{scene['uncut_per_radius']:.6f} of silhouette per unit radius and this is "
                     f"reading it as {socket_strip.UNCUT_PER_RADIUS:.6f}. Re-render it.")
        out[tag] = measure_scene(sheets, scene, plane=(tag == "ground"))

    print_scene("WITH THE GROUND PLANE, as every shipped sheet is rendered:", out["ground"], True)
    print_scene("WITH THE GROUND PLANE DELETED:", out["no-ground"], False)

    # A ROW EITHER RENDER COULD NOT STAND BEHIND IS LEFT OUT OF THIS TABLE, not reprinted without
    # its warning. `print_scene` above has already said which and why; repeating the number here
    # with a `recovered` beside it and no marker is what the module header says this file does not
    # do.
    print("")
    print("WHAT THE TWO RENDERS SAY, one line per cylinder, with the ones the plane never reached")
    print("marked as such:")
    print(f"  {'radius':>6} {'z':>6} {'below (ground)':>15} {'below (none)':>13} "
          f"{'recovered':>10} {'lost to the plane':>18}")
    dropped = 0
    for g, n in zip(out["ground"], out["no-ground"]):
        if g["below"] is None or n["below"] is None or g["why"] or n["why"]:
            dropped += 1
            continue
        print(f"  {g['radius']:>6.3f} {g['z']:>6.3f} {g['below']:>+15.1f} {n['below']:>+13.1f} "
              f"{n['below'] - g['below']:>+10.1f} {g['uncut'] - g['below']:>18.1f}"
              + ("" if g["cut"] else "   (plane does not reach this one)"))
    if dropped:
        print(f"  {dropped} cylinder(s) left out: one render or the other carries no number this "
              f"probe will stand behind. The two tables above say which, and why.")
    print("  'recovered' is what deleting the plane put back; 'lost to the plane' is the shortfall")
    print("  against the uncut prediction while it was there. If the plane is the whole cause the")
    print("  two agree to within the edge spread, and the no-ground column loses nothing at all.")

    # THE ONE SENTENCE A READER NEEDS, and it is computed rather than written. With the plane gone
    # a cylinder should draw the same distance above its axis as below it, because nothing is left
    # to cut either edge -- so the largest asymmetry over the whole grid is the claim, and it is
    # printed whatever it comes to.
    # `why` AS WELL AS `above`, and that is the whole of this line. A row whose window moved when
    # it was narrowed still carries numbers; print_scene prints it as UNUSABLE and keeps it out of
    # the residual summary, and letting it become the one computed conclusion here would put a
    # reading the guard refused at the top of the finding.
    worst = max(((abs(r["above"] - r["below"]), r) for r in out["no-ground"]
                 if r["above"] is not None and r["why"] is None),
                key=lambda p: p[0], default=None)
    if worst:
        gap, r = worst
        print("")
        sound = sum(1 for x in out["no-ground"] if x["above"] is not None and x["why"] is None)
        print("WITH THE PLANE GONE the most lopsided cylinder of the "
              f"{sound} this probe stands behind is radius {r['radius']:g} at z {r['z']:g}, "
              f"drawing "
              f"{r['above']:+.1f} above its axis and {r['below']:+.1f} below: {gap:.1f} px apart.")
    return out


# ---- one machine, the plane taken away (#366) ---------------------------------------------------

# THE FOUR SHEETS THE `machine` SCENE READS, as (heading, treatments, is the tube bare).
#
# TWO VARIABLES, TWO LEVELS EACH, AND ALL FOUR CELLS RENDERED -- which is why it is a table rather
# than a pair. The ground plane answers #366, and it is measured on the band, the ribs and the rim.
# The flange ribs answer nothing here, but they are what stops the STUB being measurable at all: on
# a sheet that has them, they leave 1.15 px of tube between them and no whole column falls clear of
# both, so tools/measure-socket-parts.py reports the stub as having NO WINDOW. Deleting them gives
# the stub a window; deleting them AND the plane gives the stub with the plane gone, which is the
# row #366 asks for and the row no shipped sheet can carry.
#
# THE THIRD ROW IS #376'S SHEET AND IS RENDERED AGAIN HERE ON PURPOSE. scripts/probe-flange-free-
# render.ps1 already makes it, and a reader could run that and compare by hand -- but then the
# with-plane and without-plane stub readings would come from two commands with two scratch
# directories, and the whole point of a table is that every cell is rendered the same way in the
# same run. One extra Blender pair of runs is cheaper than a comparison nobody can reproduce.
MACHINE_SHEETS = (
    ("AS SHIPPED: the ground plane in place, the flange ribs on.", None, False),
    ("THE GROUND PLANE DELETED, the flange ribs still on.", "groundless", False),
    ("THE FLANGE RIBS DELETED, the ground plane still in place.", "unflanged", True),
    ("BOTH DELETED: no ground plane and no flange ribs.", "unflanged,groundless", True),
)


def scene_machine(a, blender):
    """Render a shipped machine four ways and measure its socket on each."""
    model = os.path.join(REPO, "models", a.machine, f"{a.machine}.blend")
    if not os.path.exists(model):
        sys.exit(f"probe-socket-underside: no stored model at {model}. "
                 f"Run /render-machine rf-{a.machine} --regenerate first.")
    # ONE DIRECTION FOR AN EAST-WEST SOCKET AND TWO FOR A NORTH-SOUTH ONE, because
    # tools/socket_strip.py measures a connection on the sheet where its tube runs across the
    # screen -- "" for east and west, "-e" for north and south, which is the second render.
    # Hard-wiring 1 made --direction north fail on the rendered halves alone, with the shipped half
    # succeeding beside them off a manifest that has all four.
    directions = "1" if a.direction in ("west", "east") else "2"

    manifests = []
    for title, treatments, bare in MACHINE_SHEETS:
        if treatments is None:
            manifests.append((title, os.path.join(
                REPO, "realistic-fusion-refreshed-assets", "graphics", "rendered", a.machine,
                "manifest.json"), bare))
            continue
        work = os.path.join(a.out, treatments.replace(",", "+"))
        sheets = os.path.join(work, "sheets")
        if not a.reuse:
            print(f"\nbuilding and rendering {treatments} ...")
            os.makedirs(work, exist_ok=True)
            # models/render.py reads geometry.json BESIDE the model it opens and refuses one whose
            # hash has moved, so the throwaway copy needs the same file beside it.
            shutil.copy2(os.path.join(REPO, "models", a.machine, "geometry.json"), work)
            run_blender(blender, "models/socket-variants.py",
                        [treatments, os.path.join(work, f"{a.machine}.blend")], blend=model)
            run_blender(blender, "models/render.py",
                        ["--samples", str(a.samples), "--directions", directions, "--out", sheets],
                        blend=os.path.join(work, f"{a.machine}.blend"))
        manifests.append((title, os.path.join(sheets, "manifest.json"), bare))

    failed = no_window = False
    for title, manifest, bare in manifests:
        print(f"\n{title}")
        cmd = [sys.executable, os.path.join(TOOLS, "measure-socket-parts.py"), manifest,
               "--direction", a.direction, "--radius", str(a.radius)]
        if a.fluid:
            cmd += ["--fluid", a.fluid]
        # --no-flange IS THE CALLER'S CLAIM ABOUT THE SHEET AND NEVER A READING OF IT (#376). Every
        # window that tool opens comes from the constants the model was built from, so on a sheet
        # that still has its ribs this flag would measure the ribs and label them the stub. It is
        # passed for exactly the two rows this file rendered with `unflanged` in them.
        if bare:
            cmd.append("--no-flange")
        # FLUSHED FIRST, because this script's own stdout is block-buffered when it is piped and the
        # subprocess's is not: without it the tables print before the headings that say which is
        # which, which is worse than no headings.
        sys.stdout.flush()
        done = subprocess.run(cmd, capture_output=True, text=True)
        print((done.stdout or "") + (done.stderr or ""), end="")
        if done.returncode != 0:
            failed = True
        elif "NO WINDOW" in (done.stdout or ""):
            no_window = True
    # WHAT IS SAID HERE IS READ OFF WHAT WAS PRINTED, NOT TYPED. This paragraph used to print
    # unconditionally, which made it a claim rather than a reading: it survived a bench that exited
    # non-zero, and it was wrong for a CONTAINED connection, where the socket wears neither rim nor
    # ribs and its stub runs from the mouth to the band with a window of its own.
    print("")
    if failed:
        print("One of the readings above failed. Nothing here is a finding until it does not.")
    elif no_window:
        print("A stub reported NO WINDOW above is the tool being right rather than a gap: on a")
        print("sheet that still wears its flange ribs they leave 1.15 px of tube between them and")
        print("no whole column falls clear of both. The two flange-free rows are where that stub")
        print("is read, and the difference between them is what the ground plane takes off it.")
    else:
        print("Every part named by this socket was read through a window of its own.")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("scene", choices=("cylinders", "machine"))
    ap.add_argument("--out", required=True, help="scratch directory for the models and the sheets")
    ap.add_argument("--blender", help="path to blender.exe; default is render-machine.py's lookup")
    ap.add_argument("--samples", type=int, default=64,
                    help="Cycles samples; 64 is what the shipped sheets use")
    ap.add_argument("--reuse", action="store_true",
                    help="measure what is already under --out instead of rendering it again")
    ap.add_argument("--machine", default=DEFAULT_MACHINE, help="the `machine` scene's subject")
    ap.add_argument("--direction", default=DEFAULT_DIRECTION, help="which connection to measure")
    ap.add_argument("--fluid", help="which one, when the machine has two on that side")
    ap.add_argument("--radius", type=float, default=DEFAULT_RADIUS,
                    help="the tube's radius in tiles, as the build script drew it")
    a = ap.parse_args(argv)

    guard(a.out)
    os.makedirs(a.out, exist_ok=True)
    blender = None if a.reuse else find_blender(a.blender)
    if blender:
        print(f"blender: {blender}")
    (scene_cylinders if a.scene == "cylinders" else scene_machine)(a, blender)
    print("")
    print("Probe finished. Exit 0 means it rendered and read, never that the answer was the")
    print(f"hoped-for one. Scratch: {os.path.abspath(a.out)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

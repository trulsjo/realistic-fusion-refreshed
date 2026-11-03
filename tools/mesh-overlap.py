#!/usr/bin/env python3
"""List every pair of objects whose evaluated meshes intersect in a machine's model (#850).

    python tools/mesh-overlap.py <model.blend | rf-<machine>> [--against <model.blend | git ref>]
                                 [--out FILE] [--blender EXE]
    python tools/mesh-overlap.py --self-test [--blender EXE]

THE MESH-OVERLAP TEST docs/research/density-figures.md reports, committed so a figure there can be
reproduced from the tree. Until #850 each ticket that measured one wrote its own into a session
scratchpad; this is the one that measured the head of #806, made a tool.

What it counts: every object in the scene that is a mesh or a curve, curves evaluated to the tube
their bevel draws, modifiers applied, in world space. A pair is two such objects whose triangles
intersect, found by mathutils' BVHTree.overlap after their bounding boxes are seen to meet. The
ground plane is an object like any other, so a socket standing on it is a pair. Nothing is left
out for being hidden from render: the scratch script that measured the note's figures for #806 left
nothing out, and a figure measured one way is reproduced the same way. The note's earlier figures
came from scripts of their own, and its section on this tool says how those counted. Each pair is
printed as `a | b`, the two names sorted, and the pairs sorted, one per line.

A machine is named as `rf-<machine>` or `<machine>`, meaning models/<machine>/<machine>.blend.

--against takes a second model, or a git ref, which means the same model's file as that ref holds
it (`--against origin/main`). Then it prints the pairs only one side has, each marked `<` for the
first model and `>` for the second, and last the count of pairs carrying the same two names in both,
which is how the density note matches two builds of one machine: a part made again under a new
name cannot be matched pair for pair.

--out writes the pairs, or the comparison, to a file instead of stdout.

Blender is found the way tools/render-machine.py finds it, by calling its find_blender.

--SELF-TEST NEEDS BLENDER, AND A MISSING BLENDER IS A FAILURE WITH A MESSAGE, NOT A SKIP. It builds
two models in a scratch directory: a cube, a curve whose tube runs through it, and a second cube
clear of both; then the same with the second cube moved onto the first. It holds the first to
exactly the one pair `CubeA | Tube`, curve included, and the comparison to one pair matched and one
only the second has. scripts/run-gates.ps1 runs it among its tools' self-tests. The workflow in
.github/workflows/gates.yml does not: its runner has no Blender.
"""
import argparse
import importlib.util
import os
import subprocess
import sys
import tempfile

try:
    import bpy  # noqa: F401  (only inside Blender)
    INSIDE = True
except ImportError:
    INSIDE = False

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HERE = os.path.abspath(__file__)


# ---- inside Blender ------------------------------------------------------------------------------

def pairs_in_scene():
    """Sorted `a | b` strings, one per pair of mesh or curve objects whose evaluated meshes meet."""
    import bpy
    import numpy as np
    from mathutils.bvhtree import BVHTree

    dg = bpy.context.evaluated_depsgraph_get()
    items = []
    for o in bpy.context.scene.objects:
        if o.type not in ("MESH", "CURVE"):
            continue
        e = o.evaluated_get(dg)
        try:
            m = e.to_mesh()
        except RuntimeError:
            continue
        if m is None or not m.polygons:
            e.to_mesh_clear()
            continue
        # mathutils' own single-precision product, not numpy's double: a bolt that sits exactly on
        # its cap is a pair or not by the last bit, and the note's figures were measured this way.
        world = [o.matrix_world @ v.co for v in m.vertices]
        polys = [tuple(p.vertices) for p in m.polygons]
        box = np.array(world)
        items.append((o.name, BVHTree.FromPolygons(world, polys), box.min(axis=0), box.max(axis=0)))
        e.to_mesh_clear()
    items.sort(key=lambda t: t[0])
    pairs = []
    for i, (a, ta, lo_a, hi_a) in enumerate(items):
        for b, tb, lo_b, hi_b in items[i + 1:]:
            if (hi_a < lo_b).any() or (hi_b < lo_a).any():
                continue
            if ta.overlap(tb):
                pairs.append(f"{a} | {b}")
    return sorted(pairs)


def build_self_test_scene(path, touching):
    """CubeA at the origin, a curve `Tube` through it, CubeB clear of both or, `touching`, on CubeA."""
    import bpy
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    for name, at in (("CubeA", (0, 0, 0)), ("CubeB", (0.5, 0.8, 0) if touching else (10, 0, 0))):
        bpy.ops.mesh.primitive_cube_add(size=1, location=at)
        bpy.context.object.name = name
    curve = bpy.data.curves.new("Tube", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = 0.1
    spline = curve.splines.new("POLY")
    spline.points.add(1)
    spline.points[0].co = (-2, 0, 0, 1)
    spline.points[1].co = (2, 0, 0, 1)
    scene.collection.objects.link(bpy.data.objects.new("Tube", curve))
    bpy.ops.wm.save_as_mainfile(filepath=path)


def inside(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--write")
    ap.add_argument("--build", help="build the self-test's scene into this path and stop")
    ap.add_argument("--touching", action="store_true")
    a = ap.parse_args(argv)
    if a.build:
        build_self_test_scene(a.build, a.touching)
        return
    pairs = pairs_in_scene()
    with open(a.write, "w", encoding="utf-8", newline="\n") as f:
        f.write("".join(p + "\n" for p in pairs))
    print("PAIRS", len(pairs))


# ---- outside Blender -----------------------------------------------------------------------------

def find_blender(given):
    """tools/render-machine.py's lookup, loaded from its file: its name has a hyphen in it."""
    spec = importlib.util.spec_from_file_location("render_machine", os.path.join(REPO, "tools", "render-machine.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.find_blender(given)


def model_path(given):
    if given.endswith(".blend"):
        return os.path.abspath(given)
    machine = given[3:] if given.startswith("rf-") else given
    return os.path.join(REPO, "models", machine, f"{machine}.blend")


def blender_run(blender, args, what):
    r = subprocess.run([blender, "-b", *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        sys.exit(f"mesh-overlap: Blender failed {what} (exit {r.returncode}):\n{r.stdout[-2000:]}{r.stderr[-2000:]}")


def measure(blender, blend):
    if not os.path.isfile(blend):
        sys.exit(f"mesh-overlap: no model at {blend}")
    with tempfile.TemporaryDirectory(prefix="rf-overlap-") as work:
        out = os.path.join(work, "pairs.txt")
        blender_run(blender, [blend, "--python-exit-code", "1", "--python", HERE, "--", "--write", out],
                    f"measuring {blend}")
        return open(out, encoding="utf-8").read().splitlines()


def at_ref(blend, ref, work):
    """The model's file as git ref `ref` holds it, written into `work`."""
    rel = os.path.relpath(blend, REPO).replace(os.sep, "/")
    r = subprocess.run(["git", "-C", REPO, "show", f"{ref}:{rel}"], capture_output=True)
    if r.returncode != 0:
        sys.exit(f"mesh-overlap: {ref} has no {rel}: {r.stderr.decode(errors='replace').strip()}")
    path = os.path.join(work, os.path.basename(blend))
    with open(path, "wb") as f:
        f.write(r.stdout)
    return path


def compare(first, second):
    """The lines of a comparison: `<` pairs only the first has, `>` only the second, then the count."""
    a, b = set(first), set(second)
    return ([f"< {p}" for p in sorted(a - b)] + [f"> {p}" for p in sorted(b - a)]
            + [f"{len(a)} pairs against {len(b)}; {len(a & b)} matched by name"])


def self_test(blender_given):
    blender = find_blender(blender_given)
    wrong = []
    with tempfile.TemporaryDirectory(prefix="rf-overlap-test-") as work:
        clear, touching = os.path.join(work, "clear.blend"), os.path.join(work, "touching.blend")
        blender_run(blender, ["--python-exit-code", "1", "--python", HERE, "--", "--build", clear], "building")
        blender_run(blender, ["--python-exit-code", "1", "--python", HERE, "--", "--build", touching, "--touching"],
                    "building")
        first, second = measure(blender, clear), measure(blender, touching)
        if first != ["CubeA | Tube"]:
            wrong.append(f"a cube, a tube through it and a cube clear of both gave {first!r}, wanted the one pair")
        if second != ["CubeA | CubeB", "CubeA | Tube"]:
            wrong.append(f"the second cube moved onto the first gave {second!r}")
        lines = compare(first, second)
        if lines != ["> CubeA | CubeB", "1 pairs against 2; 1 matched by name"]:
            wrong.append(f"the comparison was {lines!r}")
    for w in wrong:
        print(f"WRONG: {w}", file=sys.stderr)
    print(f"mesh-overlap: {'a result is wrong' if wrong else 'one pair found, a curve in it, and one pair new in the comparison'}.")
    return 1 if wrong else 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("model", nargs="?", help="a .blend, or a machine: rf-heat-exchanger or heat-exchanger")
    ap.add_argument("--against", help="a second .blend, or a git ref holding the same model")
    ap.add_argument("--out", help="write here instead of stdout")
    ap.add_argument("--blender", help="path to blender.exe")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args(argv)
    if a.self_test:
        return self_test(a.blender)
    if not a.model:
        ap.error("name a model, or pass --self-test")
    blender = find_blender(a.blender)
    blend = model_path(a.model)
    lines = measure(blender, blend)
    if a.against:
        with tempfile.TemporaryDirectory(prefix="rf-overlap-ref-") as work:
            other = a.against if a.against.endswith(".blend") else at_ref(blend, a.against, work)
            lines = compare(lines, measure(blender, os.path.abspath(other)))
    text = "".join(line + "\n" for line in lines)
    if a.out:
        with open(a.out, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    if INSIDE:
        inside(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    else:
        sys.exit(main())

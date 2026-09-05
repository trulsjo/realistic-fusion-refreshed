#!/usr/bin/env python3
"""Render a machine's sprite set from its stored model, or regenerate the model first.

    python tools/render-machine.py rf-<machine> [--regenerate] [--dump PATH] [--samples N]
                                                 [--directions N] [--blender EXE]
    python tools/render-machine.py rf-<machine> --look

The one command a session runs for a machine (#251). It strings together the two tools that
already exist and decides nothing about the picture:

  1. geometry   tools/extract-geometry.py rewrites models/<machine>/geometry.json from the game's
                own --dump-data (about a minute for the dump; --dump reuses one).
  2. model      by default the stored models/<machine>/<machine>.blend is rendered as it is, so a
                hand edit survives. With --regenerate, or when no model exists, the model is rebuilt
                by running models/<machine>/build.py headless, discarding the stored one; git is the
                only guard against that. When there is no build.py either, this stops and prints the
                machine's look note: writing build.py from it under models/house-style.md is the
                agent's work, not this script's (see .claude/skills/render-machine/SKILL.md).
  3. render     blender -b <model> --python models/render.py, into the Assets mod's
                graphics/rendered/<machine>/ with its manifest.

It writes PNGs, the manifest, geometry.json and, on regenerate, the .blend. Nothing in Lua:
switching a prototype over to the rendered files is a reviewed edit (#252).

Blender is not on PATH here: --blender, then $BLENDER_EXE, then a running blender.exe, then the
portable unzip in Downloads, then Program Files. The look note is the `--[[ look: <name> ... ]]`
block above the prototype in prototypes/*.lua (#246).
"""
import argparse
import glob
import os
import re
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "models"))
import rf_blender  # noqa: E402  (no bpy at module level)

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = os.path.join(REPO, "models")
LOOK_NOTE = re.compile(r"^--\[\[ look: (?P<name>\S+)[^\n]*\n(?P<prose>.*?)^\]\]", re.S | re.M)


def find_look_note(name):
    """(path, line, prose) of the one look note for `name`, or None. Two is an error."""
    hits = []
    for path in sorted(glob.glob(os.path.join(REPO, "realistic-fusion-refreshed*", "prototypes", "*.lua"))):
        text = open(path, encoding="utf-8").read()
        for m in LOOK_NOTE.finditer(text):
            if m.group("name") == name:
                hits.append((os.path.relpath(path, REPO).replace(os.sep, "/"), text.count("\n", 0, m.start()) + 1,
                             m.group("prose").strip()))
    if len(hits) > 1:
        sys.exit(f"{name}: {len(hits)} look notes, at " + ", ".join(f"{p}:{l}" for p, l, _ in hits))
    return hits[0] if hits else None


def find_blender(given):
    running = None
    if os.name == "nt":
        r = subprocess.run(["powershell", "-NoProfile", "-Command",
                            "(Get-Process blender -ErrorAction SilentlyContinue | Select-Object -First 1).Path"],
                           capture_output=True, text=True)
        running = r.stdout.strip() or None
    home = os.path.expanduser("~")
    candidates = [given, os.environ.get("BLENDER_EXE"), shutil.which("blender"), running,
                  *sorted(glob.glob(os.path.join(home, "Downloads", "blender-*-windows-x64", "blender.exe")), reverse=True),
                  *sorted(glob.glob(r"C:\Program Files\Blender Foundation\Blender *\blender.exe"), reverse=True)]
    for c in candidates:
        if c and os.path.isfile(c):
            return c
    sys.exit("blender.exe not found: pass --blender or set BLENDER_EXE")


def geometry_hash(path):
    return rf_blender.geometry_sha256(path) if os.path.exists(path) else None


def run(cmd, what):
    print(f"-> {what}: {' '.join(cmd)}", flush=True)
    r = subprocess.run(cmd)
    if r.returncode != 0:
        sys.exit(f"{what} failed (exit {r.returncode})")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("name", help="prototype name, e.g. rf-heat-exchanger")
    ap.add_argument("--regenerate", action="store_true", help="rebuild the model from build.py before rendering")
    ap.add_argument("--look", action="store_true", help="print the look note and stop")
    ap.add_argument("--dump", help="an existing data-raw-dump.json, instead of taking one")
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--directions", type=int, default=4, choices=(1, 2, 4))
    ap.add_argument("--blender", help="path to blender.exe")
    a = ap.parse_args(argv)

    name = a.name
    machine = name[3:] if name.startswith("rf-") else name
    model_dir = os.path.join(MODELS, machine)
    model, build = os.path.join(model_dir, f"{machine}.blend"), os.path.join(model_dir, "build.py")
    note = find_look_note(name)

    if a.look:
        if not note:
            sys.exit(f"{name}: no `--[[ look: {name}` block in any prototypes/*.lua")
        path, line, prose = note
        print(f"{path}:{line}\n\n{prose}")
        return

    blender = find_blender(a.blender)

    geometry = os.path.join(model_dir, "geometry.json")
    before = geometry_hash(geometry)
    run([sys.executable, os.path.join(REPO, "tools", "extract-geometry.py"), name,
         *(["--dump", a.dump] if a.dump else [])], "geometry")
    if before and geometry_hash(geometry) != before and os.path.exists(model) and not a.regenerate:
        sys.exit(f"{name}: geometry.json changed since the model was built, so the stored model's sockets "
                 f"are in the wrong place. Rerun with --regenerate (rebuilds from {os.path.relpath(build, REPO)}).")

    if a.regenerate or not os.path.exists(model):
        if not os.path.exists(build):
            print(f"{name}: no model and no {os.path.relpath(build, REPO)} to build one.", file=sys.stderr)
            if note:
                path, line, prose = note
                print(f"Write build.py from the look note at {path}:{line}, read under models/house-style.md:\n\n{prose}",
                      file=sys.stderr)
            else:
                print(f"There is no look note either: add a `--[[ look: {name} ... ]]` block above the prototype first.",
                      file=sys.stderr)
            sys.exit(2)
        why = "--regenerate" if a.regenerate else "no stored model"
        run([blender, "-b", "--python-exit-code", "1", "--python", build, "--", model], f"build ({why})")

    run([blender, "-b", model, "--python-exit-code", "1", "--python", os.path.join(MODELS, "render.py"), "--",
         "--samples", str(a.samples), "--directions", str(a.directions)], "render")
    out = os.path.join(REPO, "realistic-fusion-refreshed-assets", "graphics", "rendered", machine)
    print(f"{name}: rendered into {os.path.relpath(out, REPO)} ({len(os.listdir(out))} files). "
          "No Lua was changed; pointing the prototype at these files is a reviewed edit.")


if __name__ == "__main__":
    main()

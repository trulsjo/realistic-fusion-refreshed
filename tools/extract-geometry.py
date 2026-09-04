#!/usr/bin/env python3
"""Write a machine's geometry file from the game's own --dump-data.

    python tools/extract-geometry.py rf-heat-exchanger [rf-...]  [--dump PATH] [--out-dir models]

For each prototype named, finds it in the dump BY ENTITY TYPE (a name also exists under `item`
and `recipe`), and writes models/<name-without-rf->/geometry.json holding the footprint, the two
boxes and every pipe connection: which fluid box it belongs to, the fluid, the flow, the direction
and the position, exactly as the game resolved them after every deepcopy and helper in the data
stage. This is the fact the render trusts. It replaces the hand-copied connection list that
scripts/make-mockup-art.ps1 carried and could not check.

Without --dump, runs scripts/dump-data.ps1 to take one (needs the game; about a minute). With it,
reads the file given, so tests and repeated runs need no game.

Field semantics are pinned to Factorio 2.0.77 (types/FluidBox.html, types/PipeConnectionDefinition.html)
and to what docs/research/dump-data-geometry.md observed in a real dump: `position` never
`positions` on this repo's connections, `direction` as an integer 0/4/8/12, `flow_direction` present
but optional, `connection_type` absent meaning "normal". A `positions` field is an error here, not a
case: nothing of ours uses it, and silently taking the first would draw a socket in the wrong place.
"""
import argparse
import json
import math
import os
import subprocess
import sys

# Observed on 2.0.77 dumps, and checked against the edge each position lies on (see check_edge):
# the docs list the sixteen names of defines.direction without their numbers.
DIRECTIONS = {0: "north", 4: "east", 8: "south", 12: "west"}
UNIT = {"north": (0, -1), "east": (1, 0), "south": (0, 1), "west": (-1, 0)}
NOT_ENTITY_TYPES = {"item", "recipe", "technology", "item-group", "item-subgroup", "fluid"}


def find_entity(dump, name):
    """The one prototype called `name` that has a collision_box. Items and recipes share the name."""
    hits = [(t, p[name]) for t, p in dump.items()
            if t not in NOT_ENTITY_TYPES and isinstance(p, dict) and name in p
            and isinstance(p[name], dict) and "collision_box" in p[name]]
    if not hits:
        sys.exit(f"{name}: no entity prototype with a collision_box in the dump")
    if len(hits) > 1:
        sys.exit(f"{name}: found under several entity types: {[t for t, _ in hits]}")
    return hits[0]


def box(v):
    """[[x1,y1],[x2,y2]] as the dump writes it, or the long form with left_top/right_bottom."""
    if isinstance(v, dict):
        lt, rb = v["left_top"], v["right_bottom"]
        return [[lt.get("x", lt[0]), lt.get("y", lt[1])], [rb.get("x", rb[0]), rb.get("y", rb[1])]]
    return [[v[0][0], v[0][1]], [v[1][0], v[1][1]]]


def walk_fluid_boxes(node, path=()):
    """Every dict in the prototype that carries pipe_connections, with the path to it.
    Recursion rather than naming fluid_box / output_fluid_box / energy_source.fluid_box, the way
    factorio-lib.ps1's Add-Connections does, so a box under a new key is found rather than missed."""
    if isinstance(node, dict):
        if "pipe_connections" in node:
            yield ".".join(path), node
        for k, v in node.items():
            yield from walk_fluid_boxes(v, path + (k,))
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from walk_fluid_boxes(v, path + (str(i),))


def check_edge(name, pos, direction, sel):
    """A connection's tile must sit on the selection box edge its direction points out of."""
    (x1, y1), (x2, y2) = sel
    x, y = pos
    on = {"north": math.isclose(y, y1 + 0.5), "south": math.isclose(y, y2 - 0.5),
          "west": math.isclose(x, x1 + 0.5), "east": math.isclose(x, x2 - 0.5)}[direction]
    if not on:
        sys.exit(f"{name}: connection at {pos} faces {direction} but is not on that edge of {sel}")


def geometry(dump, name):
    etype, proto = find_entity(dump, name)
    coll, sel = box(proto["collision_box"]), box(proto["selection_box"])
    conns = []
    for path, fb in walk_fluid_boxes(proto):
        pcs = fb["pipe_connections"]
        if isinstance(pcs, dict):        # a one-element table can serialise as an object
            pcs = [pcs]
        for pc in pcs:
            if "positions" in pc:
                sys.exit(f"{name}: {path} uses `positions` (per-direction list); this tool reads `position` only")
            if "position" not in pc:
                continue                 # e.g. a linked or underground connection with no tile
            d = pc.get("direction", 0)
            if d not in DIRECTIONS:
                sys.exit(f"{name}: {path} has direction {d!r}; expected one of {sorted(DIRECTIONS)}")
            direction = DIRECTIONS[d]
            pos = [pc["position"][0], pc["position"][1]]
            check_edge(name, pos, direction, sel)
            conns.append({
                "box": path,
                "production_type": fb.get("production_type"),
                "fluid": fb.get("filter"),
                "flow": pc.get("flow_direction", "input-output"),
                "connection_type": pc.get("connection_type", "normal"),
                "connection_category": pc.get("connection_category"),
                "direction": direction,
                "position": pos,
            })
    conns.sort(key=lambda c: (c["box"], c["position"]))
    return {
        "name": name,
        "type": etype,
        "collision_box": coll,
        "selection_box": sel,
        "tiles": [round(sel[1][0] - sel[0][0]), round(sel[1][1] - sel[0][1])],
        "connections": conns,
        "source": "--dump-data, Factorio 2.0.77; written by tools/extract-geometry.py",
    }


def take_dump(repo_root, out_path):
    script = os.path.join(repo_root, "scripts", "dump-data.ps1")
    r = subprocess.run(["pwsh", "-NoProfile", "-File", script, "-Out", out_path],
                       capture_output=True, text=True, encoding="utf-8")
    if r.returncode != 0:
        sys.exit(f"dump-data.ps1 failed:\n{r.stdout}\n{r.stderr}")
    return r.stdout.strip().splitlines()[-1]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("names", nargs="+", help="prototype names, e.g. rf-heat-exchanger")
    ap.add_argument("--dump", help="an existing data-raw-dump.json; taken with scripts/dump-data.ps1 if omitted")
    ap.add_argument("--out-dir", default="models", help="root for <machine>/geometry.json (default: models)")
    ap.add_argument("--stdout", action="store_true", help="print the geometry instead of writing files")
    a = ap.parse_args(argv)

    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    dump_path = a.dump or take_dump(repo_root, os.path.join(repo_root, ".dump", "data-raw-dump.json"))
    with open(dump_path, encoding="utf-8") as f:
        dump = json.load(f)

    for name in a.names:
        g = geometry(dump, name)
        if a.stdout:
            print(json.dumps(g, indent=2))
            continue
        machine = name[3:] if name.startswith("rf-") else name
        out = os.path.join(a.out_dir, machine, "geometry.json")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "w", encoding="utf-8", newline="\n") as f:
            json.dump(g, f, indent=2)
            f.write("\n")
        print(f"{name}: {g['type']} {g['tiles'][0]}x{g['tiles'][1]}, {len(g['connections'])} connection(s) -> {out}")


if __name__ == "__main__":
    main()

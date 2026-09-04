"""The one check for tools/extract-geometry.py: run it on a hand-made dump and on the traps it
must refuse. No framework: `python tools/test_extract_geometry.py` exits 0 or raises.

The fixture mirrors what docs/research/dump-data-geometry.md observed on a real 2.0.77 dump:
the name present under item, recipe and boiler; pipe_connections always an array; direction as
0/4/8/12; connection_type absent; the energy source's fluid box nested one level down."""
import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("eg", os.path.join(HERE, "extract-geometry.py"))
eg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(eg)

DUMP = {
    "item": {"rf-x": {"name": "rf-x", "stack_size": 10}},
    "recipe": {"rf-x": {"name": "rf-x"}},
    "boiler": {"rf-x": {
        "name": "rf-x",
        "collision_box": [[-2.25, -7.25], [2.25, 7.25]],
        "selection_box": [[-2.5, -7.5], [2.5, 7.5]],
        "fluid_box": {"production_type": "input-output", "filter": "water", "volume": 200,
                      "pipe_connections": [
                          {"flow_direction": "input-output", "direction": 0, "position": [0, -7]},
                          {"flow_direction": "input-output", "direction": 8, "position": [0, 7]}]},
        "output_fluid_box": {"production_type": "output", "filter": "steam",
                             "pipe_connections": [{"flow_direction": "output", "direction": 4, "position": [2, 0]}]},
        "energy_source": {"type": "fluid", "fluid_box": {
            "production_type": "input", "filter": "rf-reactor-energy",
            "pipe_connections": [{"flow_direction": "input", "direction": 12, "position": [-2, 0],
                                  "connection_category": "rf-plasma"}]}},
    }},
}

g = eg.geometry(DUMP, "rf-x")
assert g["type"] == "boiler", g["type"]
assert g["tiles"] == [5, 15], g["tiles"]
assert g["collision_box"] == [[-2.25, -7.25], [2.25, 7.25]]
by_box = {c["box"]: c for c in g["connections"]}
assert len(g["connections"]) == 4, g["connections"]
e = by_box["energy_source.fluid_box"]
assert (e["fluid"], e["flow"], e["direction"], e["position"]) == ("rf-reactor-energy", "input", "west", [-2, 0]), e
assert e["connection_type"] == "normal" and e["connection_category"] == "rf-plasma"
assert by_box["output_fluid_box"]["direction"] == "east"
norths = [c for c in g["connections"] if c["direction"] == "north"]
assert norths and norths[0]["position"] == [0, -7]

# Traps: a `positions` list, a connection off its edge, a name that is only an item.
import copy


def refuses(mutate, why):
    d = copy.deepcopy(DUMP)
    mutate(d)
    try:
        eg.geometry(d, "rf-x")
    except SystemExit:
        return
    raise AssertionError(f"accepted a dump it must refuse: {why}")


refuses(lambda d: d["boiler"]["rf-x"]["output_fluid_box"]["pipe_connections"][0].update(positions=[[2, 0]] * 4),
        "positions")
refuses(lambda d: d["boiler"]["rf-x"]["output_fluid_box"]["pipe_connections"][0].update(position=[1, 0]),
        "east connection not on the east edge")
refuses(lambda d: d.pop("boiler"), "only item and recipe carry the name")
print("extract-geometry: ok")

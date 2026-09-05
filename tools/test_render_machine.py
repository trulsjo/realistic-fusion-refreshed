"""The one check for render-machine.py's look-note parser that needs no game and no Blender:
`python tools/test_render_machine.py` exits 0 or raises. Runs the script's --look path against the
real prototypes, since the marker syntax it reads was fixed by #246 in the Lua, not in a fixture."""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "render-machine.py")


def look(name):
    return subprocess.run([sys.executable, SCRIPT, name, "--look"], capture_output=True, text=True, encoding="utf-8")

# The heat exchanger's note is found, located, and its prose returned without the marker lines.
r = look("rf-heat-exchanger")
assert r.returncode == 0, r.stderr
assert r.stdout.startswith("realistic-fusion-refreshed/prototypes/entities.lua:"), r.stdout[:80]
assert "A long, low hall" in r.stdout and "]]" not in r.stdout and "look:" not in r.stdout, r.stdout[:200]

# A machine without a note is a clear refusal that names the marker to add.
r = look("rf-lithium-blanket")
assert r.returncode != 0 and "--[[ look: rf-lithium-blanket" in r.stderr, (r.returncode, r.stderr)

print("ok")

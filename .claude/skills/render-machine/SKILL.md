---
name: render-machine
description: Render a machine's sprite set, icon and manifest from its Blender model, regenerating the model from its look note when asked or when none exists.
disable-model-invocation: true
---

# /render-machine rf-<machine>

Produces **rendered art** for one machine: the sprite set, icon and `manifest.json` under
`realistic-fusion-refreshed-assets/graphics/rendered/<machine>/`. Vocabulary is `GLOSSARY.md`'s
**Art** section: mockup, rendered art, look note, house style, model, regenerate.

The skill writes PNGs, the manifest, `geometry.json` and, on regenerate, the model. It changes no
Lua: pointing the prototype at the rendered files is a separate, reviewed edit.

## Steps

1. Run the orchestrator. It extracts geometry from the game, renders the stored model, and stops
   with a message when a decision is yours:

   ```
   python tools/render-machine.py rf-<machine> [--regenerate] [--dump PATH]
   ```

   Done when it prints `rendered into ...` and `load-check.ps1` passes (its rendered-art gate holds
   the manifest against the live prototype). Otherwise take the branch it named:

   - **`geometry.json changed`**: the prototype's footprint or connections moved since the model
     was built. Rerun with `--regenerate` so the sockets move with them. The stored `.blend` is
     discarded; git is the only guard, so check it in first if it carries a hand edit.
   - **`no model and no build.py`**: go to step 2.
   - **`no look note either`**: ask Truls for one. A look note is prose about how *that* machine
     looks, and writing it is his call, not yours. Give him the marker to add above the prototype:
     `--[[ look: rf-<machine>` on its own line, free prose, closed by `]]`.

2. Write `models/<machine>/build.py` from the look note, read under `models/house-style.md`.
   `python tools/render-machine.py rf-<machine> --look` prints the note. The heat exchanger's
   `models/heat-exchanger/build.py` is the worked example: primitives and curves with procedural
   Principled materials, sockets placed from `geometry.json` by fluid, the geometry's sha256 stamped
   on the scene, headless, deterministic (a seed passed to `rf_parts.use`, and every imperfection
   drawn from `rf_parts.stream` under the part's own name, never from `random`). No mesh is
   imported. A CC0 image texture may be, kept in `models/<machine>/` with a record in its
   `textures.json` and loaded with `rf_parts.texture` (ADR 0043; `models/house-style.md`,
   Materials, has the record); nothing else from Poly Haven, Sketchfab or anywhere else.

   To see what you are building, Blender is reachable over MCP (`mcp__blender__*`): run the same
   code with `execute_blender_code`, look with `get_viewport_screenshot`, then put the result in
   `build.py`. The MCP scene is scratch; `build.py` is the model's source of truth.

   Done when `python tools/render-machine.py rf-<machine> --regenerate` renders and the sheets,
   laid beside vanilla with `python models/post.py vanilla <out.png> <structure.png>`, read as the
   look note under the house style. Acceptance by eye is Truls's: show him the composite.

   A render put to Truls against what came before goes through one command, so he sees it the
   same way every time (#853):

   ```
   python tools/compare-sheets.py rf-<machine> origin/main worktree --out <out.png> \
       [--direction north] [--crop NAME=X0,Y0,X1,Y1 ...] [--scale 3]
   ```

   It lays each ref's sheet side by side under its label, and each crop, a box in tiles of the
   footprint with 0,0 its top-left corner, across the same refs. Name a crop for each thing he
   is asked to check. `tools/mesh-overlap.py rf-<machine> --against origin/main` lists the pairs of
   parts that touch which only one side has, which is how a contact a rebuild lands is found (#850).

3. Hand off. Report the output directory, the manifest's `frame.north` / `frame.east` sizes
   (`pictures.lua` needs them, with `shift = {0, 0}`), and that no Lua changed.

## Where the numbers live

Camera, sun, margin, glow emission and the fluid-to-accent map are in `models/rf_blender.py`, once.
The manifest records the ones a render used. Change them there, not in a build script.

Three figures are measured off the model at render time rather than set: `frame.shadow_reach_tiles`,
how far the shadow falls past the footprint in each sheet, which `models/test_rf_blender.py` holds
under `frame.margin_tiles` (#851); and `model_vertices` and `model_bytes`, which
`scripts/ship-check.ps1` fails when either more than doubles against `origin/main` (#852). A branch
that means to grow a model says so with a `Model-Growth: <machine>` trailer in a commit's body.

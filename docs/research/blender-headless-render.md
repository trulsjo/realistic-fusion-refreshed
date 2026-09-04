# Headless Blender 5.2: structure, shadow, glow and icon from one scene

This answers [#243][243], part of [#238][238]: how to drive Blender 5.2 LTS from the command line
so that one `.blend` yields the four PNGs a Factorio entity needs — the structure on a transparent
background, its shadow alone, its emission alone, and an icon-sized crop — and what the 5.x Python
API does differently from the 4.x tutorials.

**Verdict: it works, in Cycles, in one render per direction, at about a second a frame for a small
test scene.** Everything below marked *verified* was run on this machine on 2026-09-04 against
Blender 5.2.0 LTS (hash `fbe6228777e7`, built 2026-07-14). Everything marked *inferred* comes from
the Blender manual or release notes and was not exercised. Nothing here is a balance or art decision;
the scene is a cube with a chimney.

The scripts are in [`blender-headless-render/`](blender-headless-render/) beside this file, and
[`run.ps1`](blender-headless-render/run.ps1) there runs the whole thing:

```
pwsh -File docs/research/blender-headless-render/run.ps1 -Directions 4 [-Denoise] [-Out <dir>]
```

It is a probe, not a gate: exit 0 means it ran and reported, and the report is the alpha histogram,
centroid and solid bounding box of every PNG, not a verdict.

## Where Blender is

| | |
|---|---|
| Binary | `C:\Users\TrulsJ\Downloads\blender-5.2.0-windows-x64\blender.exe` |
| How found | `Get-Process blender \| Select-Object Path` while the MCP-connected instance was running |
| What it is | The portable zip, unpacked in place. Not an installer, not on PATH, not in `Program Files`, no registry entry checked |
| Bundled Python | 3.13.13 (`5.2\python\bin\python.exe`; `python313.dll` in the root) — *verified* by `sys.version` inside Blender |

`run.ps1` looks for a running `blender` process first, then that Downloads path, then the
`Program Files` path an installer would use. Anything else needs `-Blender <path>`.

## The command line

`blender -b <file>.blend --python <script.py> -- <args>` — *verified*. Three rules from the manual's
[command-line arguments][cli] page, all of which bit or nearly bit here:

- **Arguments run in the order given.** `-b file.blend -o out -f 1` renders to `out`;
  `-b -o out file.blend -f 1` does not, because loading the file overwrites the output path. With
  `--python` doing all the work this only matters for `--python-exit-code`, which must come before
  `--python` to apply to it.
- **`--` ends Blender's option parsing** and the rest is left in `sys.argv` untouched. Blender does
  not strip its own arguments: `sys.argv` is the whole command line and the script splits at `"--"`
  itself ([`rf_render.script_args`](blender-headless-render/rf_render.py)). *Verified.*
- **`--python-exit-code 1`** makes a Python exception exit non-zero. Without it a failed script exits
  0 and the wrapper cannot tell. *Verified* — the first two runs failed this way and were caught.

The script's own directory is **not** on `sys.path`. The manual's Tips and Tricks page only says a
module "has to be in Python's module search path"; the 5.2 source (`BPY_run_filepath`) sets
`__file__` and nothing else. Every script here therefore begins with
`sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))` and then imports `rf_render`, a
module written outside Blender. *Verified*: it imports, so the answer to "can the bundled Python
import a script the outer Python 3.13 wrote" is yes for plain `.py` source, and would be yes for any
3.13 anyway — the manual's rule is that the `(major, minor)` version must match, and both are 3.13.
Blender writes a `__pycache__` beside the scripts when it does; that directory is now git-ignored.

## Engine: Cycles on CPU, not EEVEE

| | Cycles, CPU | EEVEE |
|---|---|---|
| Runs headless on this machine | yes | yes — but the manual says *"Headless rendering is not supported on headless Windows systems"*; this machine has a display and a GPU, so that was not tested |
| Shadow catcher | yes | **no** — the pass list puts Shadow Catcher under Cycles only, and the probe rendered the ground plane as solid grey |
| Emission pass | yes | yes |
| Shadow pass | no (Shadow Catcher instead) | yes, a plain lit/unlit mask |
| 320×320, 16 samples, 3 passes | **≈1.1 s** per frame after the first | 35.8 s cold, 4.3 s warm (combined pass only) |
| Denoise | +3.7 s per frame (OpenImageDenoise, CPU) | — |

*Verified* on the test scene; times are wall-clock from Blender's own log timestamps and a
`perf_counter` around `render()`, one run each, not a benchmark. EEVEE's 35.8 s was its first run
and is shader compilation; it does not recur. Even warm it is four times slower than Cycles here on
a scene this small, and it has no way to isolate the shadow. **Cycles is the answer for this
pipeline.** Whether EEVEE would win at real sprite sizes with a real GPU is an open point, and moot
until it has a shadow catcher.

Cycles' shading is not Factorio's out of the box: with the sun pitched to throw shadows down-right,
the face towards the camera receives no direct light and comes out near-black, because there is no
world light in the test scene. A world colour with a low strength would supply the ambient fill; it
lights the scene even with the film transparent. Not tried — the "Factorio-like" part of the question
is an art decision and belongs with the camera ticket.

## The four PNGs

One render produces the first three through the compositor's File Output node; the icon is a
second, smaller render. Both are in [`render_passes.py`](blender-headless-render/render_passes.py).

**Structure, transparent background.** `scene.render.film_transparent = True` — the world becomes
alpha 0. The ground plane is a *shadow catcher* (`obj.is_shadow_catcher = True`, a property on
`bpy.types.Object` itself in 5.x), so it is invisible in the combined pass. *Verified*: with the
Shadow Catcher pass enabled the combined pass's alpha is 0 over the whole ground **including where
the shadow falls** — the shadow lives only in its own pass. The manual says that with the pass
disabled "a simple approximation is used instead", which is the mode where the shadow darkens the
combined alpha. Not tried.

**Shadow only.** The Shadow Catcher pass is *"shadows and light which is to be multiplied into
backdrop"* — 1 where the catcher is lit, less where it is shadowed, and 1 where a non-catcher object
covers it. Factorio's `draw_as_shadow` sprite is black with the shadow in the alpha, so the tree is:
Invert → Set Alpha (Replace Alpha) onto a constant black. *Verified*: the resulting PNG is alpha 0
everywhere except the shadow, including over the structure itself (centre pixel `(0,0,0,0)`), and
the shadow centroid sits down-right of the structure centroid. At 16 samples the shadow is grainy;
`-Denoise` cleans it and the catcher pass is denoised along with the combined pass. The shadow's
edge along the structure's own silhouette shows a one-pixel stipple; whether that matters at real
sizes is an open point.

**Glow.** The Emission pass (`view_layer.use_pass_emit`) is RGB with no alpha. To get a transparent
PNG it is run through Set Alpha with the combined pass's alpha. *Verified*: with only the chimney
emissive the pass is the chimney's colour there and black everywhere else on the structure. Black
adds nothing under Factorio's additive blend, so the result is usable as-is, but its alpha is 1 over
the whole structure rather than over the glowing part. Using the emission's own luminance as the
alpha instead is a one-node change; not done because which is right depends on how the glow layer
is declared in the prototype.

**Icon crop.** `render.use_border = True`, `use_crop_to_border = True`, and the four
`border_min_x`…`border_max_y` fractions of the frame. *Verified*: a 0.4 × 0.4 region of the 320 px
frame yields exactly a 128 × 128 RGBA PNG. The compositor is switched off for this render because the
File Output node would otherwise write another set of passes. The Crop node exists in the compositor
too (`X`, `Y`, `Width`, `Height` in pixels) and would let the icon come out of the same render as the
passes; not tried.

**Files and names.** File Output writes `<directory>\<file_name><item name>.png`. In 5.x a
single-frame `render()` appends **no** frame number — *verified*, the files are `dir0_structure.png`
and so on — where 4.x appended `0001`. The release notes say `####` in the name restores the number.

## Four directions: turn one empty

Camera and sun are children of an empty called `Rig` at the origin. Rotating `Rig` about Z by 0°,
90°, 180°, 270° and rendering each time turns view and light together, so the shadow falls the same
way on screen in every direction. *Verified*: the structure's alpha-weighted centroid moves between
directions and the chimney disappears behind the cube in direction 1. The rotation is done by
setting `rig.rotation_euler[2]` between `render()` calls; no frame change or keyframe is needed.

## Resolution from a footprint in tiles

One Blender unit is one tile. An orthographic camera's `ortho_scale` is the world width of the
**longer** frame side, so setting `resolution_x/y = tiles × px_per_tile` and
`ortho_scale = max(tiles_w, tiles_h)` makes the ground plane's own axis pixel-exact at
`px_per_tile` (64 for high resolution). *Verified* for the square case: a 5 × 5 tile frame at 64 px
per tile is 320 × 320 and the 2-tile cube's solid bounding box is 128 px wide. The pitched axis
foreshortens by the camera pitch and is **not** corrected here — that, and the pitch itself, is the
camera ticket's question. `set_frame` in [`rf_render.py`](blender-headless-render/rf_render.py) is
the helper.

The margin is a separate number from the footprint, and the shadow sets it: at this sun angle the
shadow's bounding box runs to the frame's right edge (x = 319 of 320), so a 1.5-tile margin **clips
the shadow**. *Verified*, and not fixed here — the margin follows from the sun angle and the
structure height, both of which are open.

## What the 5.x API does differently

All *verified* by hitting them, except where noted. Every one of these breaks a 4.x tutorial.

| 4.x | 5.x | Where |
|---|---|---|
| `scene.node_tree`, `scene.use_nodes = True` | `scene.compositing_node_group = bpy.data.node_groups.new(name, "CompositorNodeTree")`; `use_nodes` is deprecated and always True; compositing is switched with `scene.render.use_compositing` | [5.0 Python API notes][rn50py] |
| Composite output node | gone — a `NodeGroupOutput` with a Color socket made through `tree.interface.new_socket(...)` | [5.0 compositor notes][rn50comp] |
| `CompositorNodeOutputFile.file_slots`, `.base_path` | `.file_output_items`, `.directory`, `.file_name`. Made from Python the item list is **empty**, so `items.new(socket_type="RGBA", name=...)` for each output — the release note's `items[0]` assumes a UI-made node | [5.0 Python API notes][rn50py] |
| `CompositorNodeSetAlpha.mode = "REPLACE_ALPHA"` | no `mode`; it is a menu **input socket**: `node.inputs["Type"].default_value = "Replace Alpha"`, the display string, not an identifier | introspection, not documented in the notes |
| `CompositorNodeInvert.inputs["Fac"]` | sockets are `Color`, `Factor`, `Invert Color`, `Invert Alpha` | introspection |
| `ShaderNodeInvert` in a compositor tree | refused: *"Cannot add node of type ShaderNodeInvert"*; the compositor node is still `CompositorNodeInvert` | run-time error |
| `image_settings.file_format = "PNG"` | set `image_settings.media_type = "IMAGE"` first | [5.0 Python API notes][rn50py] |
| `engine = "BLENDER_EEVEE_NEXT"` | `"BLENDER_EEVEE"`; `-E help` lists `BLENDER_EEVEE`, `BLENDER_WORKBENCH`, `CYCLES` | [5.0 notes][rn50py]; *verified* |
| pass sockets `Emit`, `Z` | `Emission`, `Depth`; the render-layer sockets seen were `Image`, `Alpha`, `Emission`, `Shadow Catcher` | [5.0 notes][rn50py]; *verified* |
| File Output names `name0001.png` on a still | no frame number on a still | [5.0 compositor notes][rn50comp]; *verified* |
| `view_layer.cycles.use_pass_shadow_catcher` | unchanged, but absent from the API reference — `CyclesRenderLayerSettings` is a 404; the property is in the Cycles add-on's `properties.py` | *inferred* from source; *verified* to work |
| Python 3.11 | 3.13, since 5.1 | [5.1 Python API notes][rn51py] |

Also in 5.2 and not needed here: `gpu.init()` to bring up the GPU back-end in `--background`,
which is presumably what EEVEE's headless path needs on a machine without a display. Not tried.

## What is verified and what is not

*Verified*, on this machine, 2026-09-04:

- Build a scene from nothing in background mode, save it, load it in a second process, import a
  sibling module, render, and read the PNGs back with `bpy`: 13 RGBA PNGs from a 4-direction run in
  15 s of wall clock across three Blender launches.
- Combined has alpha 0 over ground and shadow; shadow pass has alpha only in the shadow; glow pass
  has colour only on the emissive object; icon is 128 × 128 from a 320 × 320 frame.
- The rig rotation moves the structure and the shadow together.
- EEVEE renders headless here, has no shadow catcher, and is slower on this scene.

*Not verified*:

- Any real model, any real sprite size, any GPU device for Cycles, and every number above at scale.
- EEVEE on a machine without a display.
- The "simple approximation" shadow mode with the catcher pass off.
- Whether the camera pitch, `ortho_scale` and pixel-per-tile arithmetic match Factorio's projection
  once the pitched axis is accounted for. That is [#238][238]'s camera ticket.
- Workbench honouring `film_transparent` — no manual sentence says so.

## Open points for the map

1. **Ambient fill.** The face towards the camera is black without a world light. A low-strength
   world colour is the obvious lever; its strength is an art choice.
2. **Glow alpha.** Combined alpha or emission luminance — depends on how the layer is declared.
3. **Shadow softness.** The test sun has a 2° angle and gives a hard shadow; Factorio's are soft and
   half-transparent. `sun.angle` and a post-multiply on the alpha are the levers.
4. **Foreshortening.** `set_frame` is pixel-exact on one axis only.
5. **Silhouette stipple** on the shadow pass where the structure meets the ground; check at 64 px per
   tile with denoising before caring.
6. **Margin.** The frame must hold the shadow, not just the footprint; the test scene's 1.5 tiles
   does not. The margin is a function of sun angle and structure height.

## Sources

- [Command-line arguments][cli] and [command-line rendering][clirender], Blender 5.2 LTS manual.
- [Render passes][passes] (one page for Cycles and EEVEE), [Cycles film settings][film],
  [Cycles object settings: shadow catcher][shadowcatcher], [EEVEE limitations][eeveelim].
- [`RenderSettings`][rs], [`Object`][obj], [`ViewLayer`][vl], [`Scene`][scene],
  [`CompositorNodeOutputFile`][fo], [`Image`][image] in the 5.2 Python API reference;
  [Tips and Tricks][tips] for the Python version rule.
- Release notes: [5.0 Python API][rn50py], [5.0 compositor][rn50comp], [5.1 Python API][rn51py],
  [5.2 Python API][rn52py], [5.2 EEVEE][rn52eevee].
- `intern/cycles/blender/addon/properties.py` on the `blender-v5.2-release` branch, for
  `use_pass_shadow_catcher`.

[243]: https://github.com/trulsjo/realistic-fusion-refreshed/issues/243
[238]: https://github.com/trulsjo/realistic-fusion-refreshed/issues/238
[cli]: https://docs.blender.org/manual/en/latest/advanced/command_line/arguments.html
[clirender]: https://docs.blender.org/manual/en/latest/advanced/command_line/render.html
[passes]: https://docs.blender.org/manual/en/latest/render/layers/passes.html
[film]: https://docs.blender.org/manual/en/latest/render/cycles/render_settings/film.html
[shadowcatcher]: https://docs.blender.org/manual/en/latest/render/cycles/object_settings/object_data.html
[eeveelim]: https://docs.blender.org/manual/en/latest/render/eevee/limitations/limitations.html
[rs]: https://docs.blender.org/api/current/bpy.types.RenderSettings.html
[obj]: https://docs.blender.org/api/current/bpy.types.Object.html
[vl]: https://docs.blender.org/api/current/bpy.types.ViewLayer.html
[scene]: https://docs.blender.org/api/current/bpy.types.Scene.html
[fo]: https://docs.blender.org/api/current/bpy.types.CompositorNodeOutputFile.html
[image]: https://docs.blender.org/api/current/bpy.types.Image.html
[tips]: https://docs.blender.org/api/current/info_tips_and_tricks.html
[rn50py]: https://developer.blender.org/docs/release_notes/5.0/python_api/
[rn50comp]: https://developer.blender.org/docs/release_notes/5.0/compositor/
[rn51py]: https://developer.blender.org/docs/release_notes/5.1/python_api/
[rn52py]: https://developer.blender.org/docs/release_notes/5.2/python_api/
[rn52eevee]: https://developer.blender.org/docs/release_notes/5.2/eevee/

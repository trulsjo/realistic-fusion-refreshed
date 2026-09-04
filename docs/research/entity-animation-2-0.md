# What animates on a boiler, generator, container and assembling machine in 2.0.77

Research for [#241][241], part of [#238][238]. Question: for each of the four prototype types this
mod's machines are built on, which graphics fields move, which are still, and which move only while
the machine works; how a multi-frame sheet is laid out and how big a PNG may be; how the runtime
`rendering.draw_animation` route the two reactors already use differs from any of that; and how
Krastorio 2 defines the pulsing core this repo draws. The result is meant to be enough to write a
look-note grammar for *glows when working* and *moves when working* later, and to say exactly what a
**single-frame glow** needs today. Multi-frame animation is out of the proof by decision
(2026-09-04); nothing here builds it.

Every API fact below is read from the **2.0.77** documentation, pinned, not from `/latest/` and not
from memory. Vanilla figures are read from the 2.0.77 `base` data on this machine
(`D:\SteamLibrary\steamapps\common\Factorio\data\base\`, `info.json` says `2.0.77`). Krastorio 2
figures are read from the originals in `C:\src\factorio\_reference\Krastorio2\` and checked against
the PNGs in `realistic-fusion-refreshed-assets/`. Anything the documentation does not actually say
is marked **(inference)**.

## The short answer

| Prototype | Field | Type | Moves? | When |
|---|---|---|---|---|
| `boiler` | `pictures.<dir>.structure` | `Animation` | **No** — measured still in this repo, whatever `frame_count` says | always drawn |
| `boiler` | `pictures.<dir>.fire`, `fire_glow` | `Animation` | Yes, by type | only while the boiler is burning — driven by its energy source, not by "working" |
| `boiler` | `pictures.<dir>.patch` | `Sprite` | No | always drawn |
| `generator` | `horizontal_animation`, `vertical_animation` | `Animation` | Yes | speed follows output; stands still at zero output **(inference)** |
| `generator` | `*_frozen_patch` | `Sprite` | No | Space Age freezing only |
| `container` | `picture` | `Sprite` | **No — cannot** | always drawn |
| `assembling-machine` | `graphics_set.animation` | `Animation4Way` | Yes | plays while crafting; holds when idle unless `idle_animation` |
| `assembling-machine` | `graphics_set.idle_animation` | `Animation4Way` | Yes | plays while idle; `always_draw_idle_animation` keeps it under the working one |
| `assembling-machine` | `graphics_set.working_visualisations[]` | `WorkingVisualisation` | Yes | only while working, unless `always_draw`; per-layer `fadeout`, `light`, `draw_as_glow` |
| any entity, at runtime | `rendering.draw_animation{animation=…}` | `AnimationPrototype` name | Yes, always | whenever the script says so — this is the reactors' route |

So of the four, **only the assembling machine has a first-class "while working" layer** in the
prototype. The boiler's only moving parts are its burner's flame. The generator's animation is
tied to output rather than to a working flag. The container has no animation type anywhere.

## Boiler

`BoilerPrototype.pictures` is a `BoilerPictureSet` — `north`, `east`, `south`, `west`, each a
`BoilerPictures` with four fields ([BoilerPrototype][api-boiler], [BoilerPictures][api-boilerpics]):

- **`structure :: Animation`.** Mandatory. The documentation says nothing about it playing. Vanilla
  names the files `boiler-N-idle.png` and `heatex-N-idle.png` and gives them no `frame_count`. This
  repo measured the question directly for `rf-reactor` and the answer is **it does not play**: a
  twelve-frame core stacked into `structure` moved by at most 13 of 255 in any channel over six
  photographs four ticks apart — ambient light, not a reactor. The placement ghost *does* animate it,
  which is what made the attempt look right in review (`reactor-pictures.lua`, `reactor-animation.lua`,
  [ADR 0013][adr13]).
- **`fire :: Animation`, `fire_glow :: Animation`.** Optional. *"Animation that is drawn on top of the
  structure when burning_cooldown is larger than 1. The animation alpha can be controlled by the
  energy source light intensity, depending on fire_flicker_enabled"* — and `fire` draws above
  `fire_glow`. `burning_cooldown` is *"for how many ticks the boiler will show the fire and fire_glow
  after the energy source runs out of energy"*, with a note that for burners the light intensity
  *"will reach zero rather quickly after the boiler runs out of fuel"*. `fire_flicker_enabled` and
  `fire_glow_flicker_enabled` default to **false**, in which case *"alpha is always 1 instead of
  being controlled by the light intensity"*. Vanilla's boiler sets both true, `burning_cooldown = 20`,
  and gives `fire` 64 frames of 26×26 at `line_length = 8` (an 8×8 grid) with `draw_as_glow`, and
  `fire_glow` a **single** 200×173 frame with `draw_as_glow` and `blend_mode = "additive"`. Vanilla's
  heat exchanger keeps `burning_cooldown = 20` and declares **no `fire` and no `fire_glow` at all**.
  This repo tried them on `rf-reactor` — electric energy source, `energy_consumption = "1W"` — and
  they were never drawn while the entity reported `working`; with the still core out of `structure`
  the reactor photographed as a building with a hole in it. **(inference)** The engine's burning
  counter is fed by the energy source consuming, and a boiler neutered to 1 W never counts as
  burning; the documentation does not say what starts the counter for a non-burner source, so this
  stays an open point below. Either way the fields are the wrong shape for a fusion reactor: they
  belong to a firebox and are gated on fuel, not on the state the reactor's own status line reports.
- **`patch :: Sprite`.** Optional, drawn above the structure in `higher-object-under`, *"to correct
  problems with neighboring pipes overlapping the structure graphics"*. A still.

A boiler therefore has **no field that plays while it works**. The repo's answer is the runtime
overlay in the last-but-one section, and [ADR 0013][adr13] recorded the trade the first time round
(*"The reactor animates constantly … A boiler has no `working_visualisations`; it has `fire` and
`fire_glow`, driven by its own burning state"*). The consequence there — a reactor that hums when
cold — was later bought back by `scripts/reactor-animation.lua`, which draws only while fusing.

## Generator

`GeneratorPrototype` has `horizontal_animation :: Animation` and `vertical_animation :: Animation`,
both optional, plus `horizontal_frozen_patch` and `vertical_frozen_patch` as `Sprite`
([GeneratorPrototype][api-gen]). Two pictures, one per axis, not one per direction — the mockup
helper `M.generator` already records what that costs a machine whose connections differ end to end.

The page says nothing about *when* the animation plays. Three pieces of evidence, all from 2.0.77:

- `AnimationParameters.animation_speed`: *"The speed of playing can often vary depending on the usage
  (output of steam engine for example)"* ([AnimationParameters][api-animparams]).
- `GeneratorPrototype.perceived_performance :: PerceivedPerformance` — *"Affects animation speed and
  working sound"* — whose `minimum` defaults to **0** and `maximum` to max double
  ([PerceivedPerformance][api-pp]).
- Vanilla: the steam engine is 32 frames at `line_length = 8` per axis (352×257 horizontal, 225×391
  vertical), shadow sheets with the same 32 frames; the steam turbine is **8** frames at
  `line_length = 4` with `run_mode = "backward"` and a one-frame shadow held with `repeat_count = 8`.

**(inference)** Speed scales with output between `perceived_performance.minimum` and `maximum`; with
the default minimum of 0 a generator producing nothing stands still on whatever frame it reached.
That is *moves in proportion to load*, not *moves when working*, and there is no separate idle or
glow layer to hang a state on. Both generators in this mod (`rf-hc-turbine`,
`rf-direct-energy-converter`) are copies of the steam turbine and inherit exactly this.

## Container

`ContainerPrototype.picture :: Sprite` — *"The picture displayed for this entity"*
([ContainerPrototype][api-container]). A `Sprite`, not an `Animation`: `SpriteParameters` has no
`frame_count`, `line_length`, `repeat_count` or `run_mode`; those live on `AnimationParameters`
([SpriteParameters][api-spriteparams], [AnimationParameters][api-animparams]). A container **cannot
animate through its prototype at all**, and it has no working state to animate on — `default_status`
is the only status field it has. Vanilla's steel chest is a two-layer `picture`, 64×80 plus a 110×46
shadow. `rf-lithium-blanket` is a copy of it, so anything that is to move or glow on the blanket has
to be a runtime rendering.

## Assembling machine

`AssemblingMachinePrototype` inherits `graphics_set :: CraftingMachineGraphicsSet` and
`graphics_set_flipped` from `CraftingMachinePrototype` ([AssemblingMachinePrototype][api-am],
[CraftingMachinePrototype][api-cm]). `CraftingMachineGraphicsSet` is a `WorkingVisualisations`
([CraftingMachineGraphicsSet][api-cmgs], [WorkingVisualisations][api-wvs]) with:

- **`animation :: Animation4Way`** and **`idle_animation :: Animation4Way`**, where *"Idle animation
  must have the same frame count as animation"* and `always_draw_idle_animation` (default false) is
  *"only loaded if idle_animation is defined"*. The page does not say in words when each plays. The
  sibling `BurnerGeneratorPrototype`, which has the same three fields, does: `animation` *"Plays when
  the generator is active"*, `idle_animation` *"Plays when the generator is inactive"*,
  `always_draw_idle_animation` *"Whether the idle_animation should also play when the generator is
  active"* ([BurnerGeneratorPrototype][api-bg]). **(inference)** The crafting machine's pair behaves
  the same way; vanilla's assembling machine 2 is a 32-frame `animation` at `line_length = 8` with
  **no** `idle_animation` and no `working_visualisations`, and stops on its current frame when idle.
- **`working_visualisations :: array[WorkingVisualisation]`** — *"Used to display different animations
  when the machine is running"*, and the type page opens *"Used by crafting machines to display
  different graphics when the machine is running"* ([WorkingVisualisation][api-wv]). Each entry has
  its own `animation` (or `north_animation` … `west_animation`) and `north_position` … `west_position`
  shifts, plus the flags that make it a grammar in itself: `always_draw` (default false),
  `fadeout` and `synced_fadeout` (default false), `constant_speed` (*"always played at the same
  speed, not adjusted to the machine speed"*), `light :: LightDefinition`, `effect` (`"flicker"`,
  `"uranium-glow"`, `"none"`), `apply_recipe_tint` and `apply_tint` (`"status"` colours the layer by
  entity status via `status_colors`), `render_layer` (default `"object"`) and `secondary_draw_order`.
  `states :: array[VisualState]` (2 to 32) with `draw_in_states` lets a layer pick which named states
  it appears in.
- `match_animation_speed_to_activity` on the crafting machine — *"Whether the speed of the animation
  and working visualization should be based on the machine's speed"* — and `perceived_performance`
  (*"Affects animation speed"*). `CraftingMachineGraphicsSet` adds `animation_progress` (default 0.5,
  undocumented beyond the default), `reset_animation_when_frozen` and `frozen_patch`.

This is the only one of the four where *glows when working* and *moves when working* are both
**prototype-level** statements: a `working_visualisation` with a one-frame `draw_as_glow` sheet is
the first, one with `frame_count > 1` is the second, and Krastorio 2's fusion reactor is written
exactly that way (below). `rf-heater` is a copy of the chemical plant and could carry both today.

## How a sheet is laid out

All from `AnimationParameters` / `Animation` unless noted ([Animation][api-anim],
[AnimationParameters][api-animparams], [SpriteSource][api-spritesource], [Stripe][api-stripe],
[AnimationRunMode][api-runmode]).

- **`width` / `height` (or `size`) are the size of ONE frame**, *"from 0-4096"* each. That is the
  per-frame ceiling; a 4096-pixel frame is 64 tiles at `scale = 0.5`.
- **`frame_count`** (`uint32`, default 1, *"Can't be 0"*) frames are read left to right, and
  **`line_length`** (`uint32`, default 0 = *"all the pictures are in one horizontal line"*) says how
  many sit on each row before the loader wraps to the next. The stated reason is the file limit:
  *"the game engine's width limit of 8192px per input file … to be compatible with most graphics
  cards"*. So a sheet is `line_length × width` wide and `ceil(frame_count / line_length) × height`
  tall, and the width product has to stay under 8192. No height limit is stated on these pages;
  Krastorio 2 ships a 3530-pixel-tall sheet without trouble (below).
- **`repeat_count`** (`uint8`, default 1) — *"How many times to repeat the animation to complete an
  animation cycle. E.g. if one layer is 10 frames, a second layer of 1 frame would need
  repeat_count = 10 to match the complete cycle."* This is how a still body or shadow shares a layer
  stack with a moving core: every layer of an `Animation.layers` array has to agree on cycle
  length, so a still is declared once and held. Being `uint8` it tops out at 255.
- **`animation_speed`** (`float`, default 1 = *"one animation frame per tick (60 fps)"*, must be > 0).
  In a `layers` stack it only has to be defined on one layer; *"All layers will run at the same
  speed."* `max_advance` (first layer's value governs) caps frames per update.
- **`run_mode`**: `"forward"` (default), `"backward"`, `"forward-then-backward"` — the last *"does not
  repeat the first and last frame when running backwards"*. Vanilla's steam turbine is `"backward"`.
- **`frame_sequence :: AnimationFrameSequence`** — an explicit order of frame indices, so a pulse can
  ease in and out from a shorter sheet. Not used by anything this repo draws.
- **`layers :: array[Animation]`** — when present, *"all Animation definitions have to be placed as
  entries in the array"*; the per-layer flags `draw_as_shadow`, `draw_as_glow`, `draw_as_light`
  are mutually exclusive on a layer. `draw_as_glow` *"Draws first as a normal sprite, then again as
  a light layer"*; `draw_as_light` draws only the light pass. `blend_mode` defaults to `"normal"`;
  the glow layers everywhere in vanilla and Krastorio 2 use `"additive"`.
- **Splitting a long animation across files.** Three ways, and only one is loaded:
  `stripes :: array[Stripe]` (each `{filename, width_in_frames, height_in_frames, x, y}`, where
  `height_in_frames` is mandatory in an `Animation`) is *"an alternative way to specify animations"*;
  `filenames :: array[FileName]` with mandatory `lines_per_file` and optional `slice` (default
  `frame_count`) is loaded *"only if neither layers nor stripes are defined"*. Vanilla's 64-frame
  boiler flame fits one file and uses neither.
- `premul_alpha` defaults to **true** on every sprite source, and `allow_forced_downscale` (default
  false) lets the engine halve a sheet even at high sprite quality.

`AnimationPrototype` — `type = "animation"`, the thing `rendering.draw_animation` names — carries the
same parameters as a top-level prototype with a `name` ([AnimationPrototype][api-animproto]). It is
data-stage only: `prototypes.animation` is not a runtime key, which is why `reactor-animation.lua`
records that its load-time guard could not be written.

## The runtime route, and how it differs

`rendering.draw_animation{animation = <AnimationPrototype name>, target = …, surface = …, …}` returns a
`LuaRenderObject` ([LuaRendering][api-rendering]). Parameters that matter here: `render_layer`
(*"Defaults to `"arrow"`"* — well above every building, so the repo passes `"higher-object-above"`);
`animation_speed` (*"How many frames the animation goes forward per tick. Default is 1"*);
`animation_offset` (*"Offset of the animation in frames"*); `x_scale`, `y_scale`, `tint`,
`orientation`; `target` as a `ScriptRenderTarget` (an entity, so the drawing follows it and dies
with it); `time_to_live` (*"Defaults to living forever"*); `visible`; `forces` and `players`.

What is different from every prototype field above:

1. **The condition is the script's, not the engine's.** The engine has one notion per prototype —
   burning, load, crafting — and a boiler's is the wrong one. `reactor-animation.lua` creates the
   rendering when the simulation reports fusing and destroys it when it stops, so the building agrees
   with its status line and its signals rather than with `energy_consumption`.
2. **It always plays, at `animation_speed` frames a tick, from creation.** There is no `always_draw`,
   no idle counterpart, no fade; the only way to stop it is `destroy()` (*"a rendering object cannot
   be hidden, only destroyed"* — `reactor-animation.lua`'s reason for create-and-destroy). Whether it
   loops is not stated on the page; **(inference from use)** the repo's twelve-frame core, named by
   the rule [#31][31] set, runs in every rig and loops, so it does.
3. **Position is the animation's own.** `target = entity` centres it on the entity and nothing else
   is passed, so each `AnimationPrototype` carries its own `shift` — Krastorio 2's `{2.18, -2.358}`
   for `rf-reactor-core`, none for the centred mockup. A future look note has to bring its own.
4. **It costs a live-save crash if the prototype is missing.** `draw_animation` throws inside the
   call the first time a reactor without a `"<name>-core"` animation starts fusing; nothing at load
   catches it, the rigs do (`check-aneutronic.ps1`, `check-d-t.ps1`).
5. **A ghost does not draw it.** The prototype's own `structure` is what the placement ghost
   animates, which is the mirror image of the trap the repo fell into: the entity field looked alive
   in the ghost and was still on the ground; the runtime overlay is alive on the ground and absent
   from the ghost.
6. **It is per-entity state in `storage`**, keyed by `unit_number`, with `forget()` on removal and
   `reset()` on configuration change — bookkeeping no prototype field needs.

## Krastorio 2's pulsing cores

Two, and the ticket's "30-frame" is the second. Both are LGPLv3 and both live, geometry included, in
`realistic-fusion-refreshed-assets/graphics/krastorio-2/buildings/`.

**Fusion reactor** — `prototypes/buildings/fusion-reactor.lua`, an `assembling-machine`. The body is a
still: `graphics_set.animation.layers` = `fusion-reactor.png` 1100×1100 at `scale 0.5`, `shift
{1.01, 0}`, plus a shadow. Everything that moves is a `working_visualisations` entry:

| Layer | Sheet | Frames | `line_length` | Speed | Flags |
|---|---|---|---|---|---|
| core | `fusion-reactor-animation.png` 626×688 | 12 | 6 | 0.75 | — |
| core glow | `fusion-reactor-animation-glow.png` 626×688 | 12 | 6 | 0.75 | `draw_as_glow` |
| core light | `fusion-reactor-animation-light.png` 626×688 | 12 | 6 | 0.75 | `draw_as_light` |
| whole-building light | `fusion-reactor-light.png` 1100×1100 | 1, `repeat_count = 12` | 1 | — | `draw_as_light` |
| steam ×2 | `fusion-reactor-steam.png` 40×81 | 60 | 10 | 0.5 | `additive`, `flags = {"smoke"}`, `fadeout = true`, own `shift` each |
| point light | — | — | — | — | `light = {intensity 0.25, size 2, color {0.95, 0.75, 0.5}}` |

The shipped `reactor-animation.png` measures **3756×1376 = 6×626 by 2×688**: twelve frames, six per
row, two rows, exactly as `frame_count = 12, line_length = 6` says. At 0.75 frames a tick the cycle
is 16 ticks, about a quarter of a second. `rf-reactor-core` is these first four layers verbatim,
re-declared as one `AnimationPrototype`; the still `structure` under it is frame one of the core and
its glow, so an idle reactor is not a building with a hole in it (`reactor-pictures.lua`).

**Antimatter reactor** — `prototypes/buildings/antimatter-reactor.lua`, a **`burner-generator`**, not
an assembling machine, and written the other way round: `always_draw_idle_animation = true`,
`idle_animation` = the whole building `antimatter-reactor.png` 660×706 held with `repeat_count = 30`
plus a shadow 724×630 (`frame_count = 1, repeat_count = 30`), and `animation` = the moving overlay:

| Layer | Sheet | Frames | `line_length` | Speed | Flags |
|---|---|---|---|---|---|
| glow | `antimatter-reactor-glow.png` 660×706 | 30 | 6 | 0.5 | `draw_as_glow`, `additive` |
| core | `antimatter-reactor-anim.png` 660×706 | 30 | 6 | 0.5 | — |
| shadow | `antimatter-reactor-sh.png` 724×630 | 1, `repeat_count = 30` | — | 0.5 | `draw_as_shadow` |

The shipped `aneutronic-reactor-animation.png` measures **3960×3530 = 6×660 by 5×706**: thirty
frames, six per row, five rows. At 0.5 frames a tick the cycle is 60 ticks — one second — which is
the pulse. Here the body *is* frame one of the idle animation, so the overlay adds motion rather than
filling a gap; `aneutronic-reactor-pictures.lua` keeps the geometry but is **not in use** since
[ADR 0022][adr22] made the machine fifteen tiles against art drawn for ten. `rf-aneutronic-reactor`
wears the mockup and its `-core` is the mockup's single frame.

Two things worth taking from the pair: Krastorio 2 reaches for a **glow sheet and a light sheet as
separate layers** with identical geometry rather than one flagged layer, and it **holds every still
with `repeat_count`** equal to the moving layer's `frame_count`, which is the rule the repo's
`FRAMES` constants exist to obey.

## What a single-frame glow needs today

This is the case the proof is allowed to build, and the repo already has it in
`graphics/mockup/pictures.lua`'s `M.core_animation`:

```lua
{
  type = "animation", name = "<reactor>-core",          -- the name reactor-animation.lua derives
  filename = "…/<file>.png", width = W, height = H,     -- ONE frame; W, H each 0-4096
  scale = 0.5,                                          -- 64 px to the tile, like everything else here
  draw_as_glow = true, blend_mode = "additive",         -- drawn once normally, once as light
  -- frame_count defaults to 1, line_length to 0, repeat_count to 1: nothing to declare
  -- shift only if the sheet is not centred on the entity
}
```

and, for it to appear, a reactor whose prototype name plus `-core` is that name, so
`scripts/reactor-animation.lua` finds it when the simulation reports fusing. Nothing else: no
`animation_speed` (one frame has no speed), no `repeat_count` (nothing to match), and no shadow
(*"it is a glow over the building, not a solid"*). The one sheet per machine issue [#249][249]
asks the render step for — *"a single-frame glow sheet where the look note declares one"* — is
exactly this file. For an assembling machine the same sheet would instead go into
`graphics_set.working_visualisations[n].animation` with `draw_as_glow = true`, and the engine
would gate it on crafting with no script at all.

## Toward a look-note grammar (inference, for later)

Two verbs, four prototype types, and where each verb can be said:

| | `boiler` | `generator` | `container` | `assembling-machine` |
|---|---|---|---|---|
| **glows when working** | runtime `-core` overlay only | runtime overlay only | runtime overlay only | `working_visualisation` with a one-frame `draw_as_glow` sheet, or the overlay |
| **moves when working** | runtime overlay with `frame_count > 1` | `horizontal_/vertical_animation` frames — but speed follows load, and still at zero | runtime overlay only | `animation` frames, or a `working_visualisation` with frames |
| **engine gates it on** | burning (fuel) — wrong state | output | nothing | crafting |

Which suggests the grammar should name the **condition** as well as the verb — "glows while fusing",
"moves while generating" — because on three of the four types the condition is something the mod
has to assert itself, and on the fourth it is the engine's and free. A multi-frame declaration
needs, at minimum: frame size, `frame_count`, `line_length`, `animation_speed`, the sheet's total
size under 8192 wide, and a `repeat_count` on every still that shares the stack.

## Open points

- **What starts a boiler's fire counter for a non-burner energy source.** The page defines
  `burning_cooldown` in terms of *"the energy source runs out of energy"* and light intensity, both
  burner ideas. The repo's electric, 1 W `rf-reactor` never drew `fire`; whether a 40 MW
  `rf-heat-exchanger` — a `fluid` energy source burning reactor energy by `fuel_value`, which is
  the nearest thing here to a burner — would is unmeasured, and irrelevant unless someone wants a
  boiler to glow through its prototype.
- **Whether a generator animation truly halts at zero output**, or `perceived_performance.minimum`
  has to be raised to keep it turning. Inference above, from `minimum`'s default of 0; not measured.
- **Whether `draw_animation` loops** is not on the page; the repo's rigs show that it does.
- **PNG height limit.** Only the 8192-pixel width limit is documented. Krastorio 2's 3530-pixel-tall
  sheet loads; nothing here says where the ceiling is.
- **`CraftingMachineGraphicsSet.animation_progress`** (default 0.5) is undocumented past its default.
- **Space Age's `FusionReactorPrototype`** has its own graphics set and was not read: [ADR 0003][adr3]
  keeps Space Age tolerated, not targeted, and [#43][43]/[#44][44] — whether the reactor stays a
  boiler — are where a change of type would be decided.

## Sources

- **`BoilerPrototype`**, Factorio Lua API 2.0.77 — <https://lua-api.factorio.com/2.0.77/prototypes/BoilerPrototype.html>.
  `pictures`, `burning_cooldown`, `fire_flicker_enabled`, `fire_glow_flicker_enabled`.
- **`BoilerPictures`** — <https://lua-api.factorio.com/2.0.77/types/BoilerPictures.html>. `structure`,
  `patch`, `fire`, `fire_glow` and their draw conditions.
- **`GeneratorPrototype`** — <https://lua-api.factorio.com/2.0.77/prototypes/GeneratorPrototype.html>.
  `horizontal_animation`, `vertical_animation`, `*_frozen_patch`, `perceived_performance`.
- **`PerceivedPerformance`** — <https://lua-api.factorio.com/2.0.77/types/PerceivedPerformance.html>.
  `minimum` default 0, `maximum` default max double, *"Affects animation speed"*.
- **`ContainerPrototype`** — <https://lua-api.factorio.com/2.0.77/prototypes/ContainerPrototype.html>.
  `picture :: Sprite`.
- **`AssemblingMachinePrototype`** — <https://lua-api.factorio.com/2.0.77/prototypes/AssemblingMachinePrototype.html>
  and **`CraftingMachinePrototype`** — <https://lua-api.factorio.com/2.0.77/prototypes/CraftingMachinePrototype.html>.
  `graphics_set`, `match_animation_speed_to_activity`, `perceived_performance`.
- **`CraftingMachineGraphicsSet`** — <https://lua-api.factorio.com/2.0.77/types/CraftingMachineGraphicsSet.html>;
  **`WorkingVisualisations`** — <https://lua-api.factorio.com/2.0.77/types/WorkingVisualisations.html>;
  **`WorkingVisualisation`** — <https://lua-api.factorio.com/2.0.77/types/WorkingVisualisation.html>.
- **`BurnerGeneratorPrototype`** — <https://lua-api.factorio.com/2.0.77/prototypes/BurnerGeneratorPrototype.html>.
  The only page that says in words when `animation` and `idle_animation` play.
- **`Animation`** — <https://lua-api.factorio.com/2.0.77/types/Animation.html>; **`AnimationParameters`** —
  <https://lua-api.factorio.com/2.0.77/types/AnimationParameters.html>; **`AnimationRunMode`** —
  <https://lua-api.factorio.com/2.0.77/types/AnimationRunMode.html>; **`Stripe`** —
  <https://lua-api.factorio.com/2.0.77/types/Stripe.html>; **`SpriteParameters`** —
  <https://lua-api.factorio.com/2.0.77/types/SpriteParameters.html>; **`SpriteSource`** —
  <https://lua-api.factorio.com/2.0.77/types/SpriteSource.html>; **`AnimationPrototype`** —
  <https://lua-api.factorio.com/2.0.77/prototypes/AnimationPrototype.html>. Frame size 0-4096, the
  8192-pixel file width, `repeat_count` as `uint8`, `draw_as_glow`'s two passes.
- **`LuaRendering`** — <https://lua-api.factorio.com/2.0.77/classes/LuaRendering.html>, `draw_animation`.
- **Factorio 2.0.77 `base` data** on this machine, `prototypes/entity/entities.lua`: `boiler`,
  `heat-exchanger`, `steam-engine`, `steam-turbine`, `steel-chest`, `assembling-machine-2`.
- **Krastorio 2** originals, `C:\src\factorio\_reference\Krastorio2\prototypes\buildings\fusion-reactor.lua`
  and `antimatter-reactor.lua`, LGPLv3; sheet sizes measured from the PNGs in
  `realistic-fusion-refreshed-assets/graphics/krastorio-2/buildings/reactor/` and `aneutronic-reactor/`.
- **This repository**: `realistic-fusion-refreshed/scripts/reactor-animation.lua`,
  `realistic-fusion-refreshed/prototypes/entities.lua`,
  `realistic-fusion-refreshed-assets/graphics/krastorio-2/buildings/reactor-pictures.lua` and
  `aneutronic-reactor-pictures.lua`, `realistic-fusion-refreshed-assets/graphics/mockup/pictures.lua`,
  [ADR 0013][adr13], [ADR 0022][adr22].

[241]: https://github.com/trulsjo/realistic-fusion-refreshed/issues/241
[238]: https://github.com/trulsjo/realistic-fusion-refreshed/issues/238
[249]: https://github.com/trulsjo/realistic-fusion-refreshed/issues/249
[31]: https://github.com/trulsjo/realistic-fusion-refreshed/issues/31
[43]: https://github.com/trulsjo/realistic-fusion-refreshed/issues/43
[44]: https://github.com/trulsjo/realistic-fusion-refreshed/issues/44
[adr3]: ../adr/0003-space-age-tolerated-not-targeted.md
[adr13]: ../adr/0013-the-reactor-is-fifteen-tiles-square.md
[adr22]: ../adr/0022-footprints-follow-the-original-mod.md
[api-boiler]: https://lua-api.factorio.com/2.0.77/prototypes/BoilerPrototype.html
[api-boilerpics]: https://lua-api.factorio.com/2.0.77/types/BoilerPictures.html
[api-gen]: https://lua-api.factorio.com/2.0.77/prototypes/GeneratorPrototype.html
[api-pp]: https://lua-api.factorio.com/2.0.77/types/PerceivedPerformance.html
[api-container]: https://lua-api.factorio.com/2.0.77/prototypes/ContainerPrototype.html
[api-am]: https://lua-api.factorio.com/2.0.77/prototypes/AssemblingMachinePrototype.html
[api-cm]: https://lua-api.factorio.com/2.0.77/prototypes/CraftingMachinePrototype.html
[api-cmgs]: https://lua-api.factorio.com/2.0.77/types/CraftingMachineGraphicsSet.html
[api-wvs]: https://lua-api.factorio.com/2.0.77/types/WorkingVisualisations.html
[api-wv]: https://lua-api.factorio.com/2.0.77/types/WorkingVisualisation.html
[api-bg]: https://lua-api.factorio.com/2.0.77/prototypes/BurnerGeneratorPrototype.html
[api-anim]: https://lua-api.factorio.com/2.0.77/types/Animation.html
[api-animparams]: https://lua-api.factorio.com/2.0.77/types/AnimationParameters.html
[api-animproto]: https://lua-api.factorio.com/2.0.77/prototypes/AnimationPrototype.html
[api-runmode]: https://lua-api.factorio.com/2.0.77/types/AnimationRunMode.html
[api-stripe]: https://lua-api.factorio.com/2.0.77/types/Stripe.html
[api-spriteparams]: https://lua-api.factorio.com/2.0.77/types/SpriteParameters.html
[api-spritesource]: https://lua-api.factorio.com/2.0.77/types/SpriteSource.html
[api-rendering]: https://lua-api.factorio.com/2.0.77/classes/LuaRendering.html

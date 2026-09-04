# How vanilla draws a pipe connection that may or may not be joined

Read against **Factorio 2.0.77** — the API reference at `lua-api.factorio.com/2.0.77/`, the base
game's own prototype Lua under `data/base/prototypes/entity/`, its sprite files, and Space Age's
`data/space-age/prototypes/entity/` where base leaves a field unused — plus Krastorio 2's prototypes
and assets in `C:\src\factorio\_reference\Krastorio2{,Assets}`. 2026-09-04, for #240 (part of #238).
No game was run: everything here is read off prototypes, docs and PNGs, and two engine behaviours
are marked **inference** because no source states them.

**Short answer.** Two things can be drawn at a connection, and they come from two different fields.
The **joined** look is either baked into the structure sheet (boiler, heat exchanger, steam engine,
steam turbine, chemical plant, oil refinery — every vanilla machine but two) or supplied per direction
by `FluidBox.pipe_picture` (assembling machines 2 and 3, whose body sheet has no openings at all).
The **unjoined** look is always a separate sprite: `FluidBox.pipe_covers`, a `Sprite4Way` keyed by the
direction the connection faces, drawn on top when nothing is connected — and every vanilla and
Krastorio 2 machine uses the same `pipecoverspictures()` for it. Nothing else in `FluidBox` changes
what is drawn per connection in the base game: `hide_connection_info` only hides the blue arrows, the
`_frozen` variants are Aquilo-only, and `always_draw_covers` / `draw_only_when_connected` are
undocumented flags whose exact meaning is the open point below. A rendered machine therefore needs,
per fluid box, **a cover sprite for all four directions** (vanilla's will do) and **one of**: sockets
drawn into every structure sheet, or a `pipe_picture` stub per direction.

## The fields, as 2.0.77 documents them

From [`types/FluidBox.html`](https://lua-api.factorio.com/2.0.77/types/FluidBox.html) — quoted where
the page has text, and marked *no description* where it has none:

| Field | Type | What the page says |
|---|---|---|
| `pipe_covers` | `Sprite4Way`, optional | *"The pictures to show when no fluid box is connected to this one."* |
| `pipe_covers_frozen` | `Sprite4Way`, optional | *no description* |
| `pipe_picture` | `Sprite4Way`, optional | *no description* |
| `pipe_picture_frozen` | `Sprite4Way`, optional | *no description* |
| `mirrored_pipe_picture` | `Sprite4Way`, optional | *"Pipe picture variation used when owner machine is flipped."* |
| `mirrored_pipe_picture_frozen` | `Sprite4Way`, optional | *"Frozen pipe picture variation used when owner machine is flipped."* |
| `always_draw_covers` | `boolean`, optional | *"Defaults to true if `pipe_picture` is not defined, otherwise defaults to false."* — and nothing about what it does |
| `draw_only_when_connected` | `boolean`, optional, default `false` | *no description* |
| `hide_connection_info` | `boolean`, optional, default `false` | *"Hides the blue input/output arrows and icons at each connection point."* |
| `render_layer` | `RenderLayer`, optional, default `"object"` | *no description* |
| `secondary_draw_order` | `int8`, optional, default `1` | *"Set the secondary draw order for all orientations. Used to determine render order for sprites with the same `render_layer` in the same position. Sprites with a higher `secondary_draw_order` are drawn on top."* |
| `secondary_draw_orders` | `FluidBoxSecondaryDrawOrders`, optional | same text, *"for each orientation"* |
| `enable_working_visualisations` | `array[string]`, optional | *"Array of WorkingVisualisation names to enable when this fluidbox is present."* |

[`types/PipeConnectionDefinition.html`](https://lua-api.factorio.com/2.0.77/types/PipeConnectionDefinition.html)
adds one drawing-relevant field at the connection rather than the box: `enable_working_visualisations`,
*"Array of the WorkingVisualisation::name of working visualisations to enable when this pipe connection
is present."* Its `direction` is *"Primary direction this connection points to when entity direction is
north and the entity is not mirrored."*

[`types/Sprite4Way.html`](https://lua-api.factorio.com/2.0.77/types/Sprite4Way.html): *"Sprites for the
4 major directions of the entity. If this is loaded as a single Sprite, it applies to all directions."*
`east`, `south` and `west` are mandatory unless `sheet`/`sheets` is given.

The per-type pages add nothing about pipes. [`BoilerPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/BoilerPrototype.html)
has `fluid_box` and `output_fluid_box` (both required) and `pictures :: BoilerPictureSet` with one
`BoilerPictures` (`structure`, optional `patch`/`fire`/`fire_glow`) per direction; the pages say
nothing about covers. [`GeneratorPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/GeneratorPrototype.html)
has one `fluid_box` and only `horizontal_animation` / `vertical_animation` (plus `_frozen_patch`) for
art — two pictures, not four. [`AssemblingMachinePrototype`](https://lua-api.factorio.com/2.0.77/prototypes/AssemblingMachinePrototype.html)
inherits `fluid_boxes :: array[FluidBox]` and `graphics_set :: CraftingMachineGraphicsSet` from
`CraftingMachinePrototype`, and adds `fluid_boxes_off_when_no_fluid_recipe` (default `false`).
[`ContainerPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/ContainerPrototype.html) has no
fluid box of any kind, so for the blanket the question does not arise: nothing is drawn and nothing
is owed.

The engine changelog (`data/changelog.txt`) is the only other first-party text: 0.17.x *"Changed
pipe_covers to be drawn with secondary sprite draw order 64 resp. -64 to prevent 'z-fighting'
issues"* and *"Fixed that storage tank entities ignored pipe_picture property in their fluid box
definition"*; 1.1.x *"Added FluidBox::hide_connection_info. When true the blue fluid connection arrows
will not be drawn."* Neither `always_draw_covers` nor `draw_only_when_connected` appears in it.

## What vanilla actually does, per prototype type

Read off `data/base/prototypes/entity/entities.lua`, `pipecovers.lua` and `assemblerpipes.lua`, and
confirmed against the PNGs.

**Every fluid box on every vanilla machine sets `pipe_covers = pipecoverspictures()`** — boiler,
heat exchanger, steam engine, steam turbine, assembling machines 2/3, chemical plant, oil refinery,
pump, storage tank, even the plain pipe (*"in case a real pipe is connected to a ghost"*). That helper
(`pipecovers.lua`) is a `Sprite4Way` of four 128×128 sprites at scale 0.5 plus a `draw_as_shadow`
layer each: `pipe-cover-north.png` is a capped pipe mouth facing north, and so on. The direction key
is the direction the *connection* faces — inferred from the naming, from the fact that a rotated boiler
still gets the right cap, and from Space Age's `base-frozen-graphics.lua`, which identifies vanilla's
covers by checking `pipe_covers.north.layers[1].filename`.

| Type | Vanilla entity | Fluid boxes | Joined look comes from | `pipe_picture`? | Other |
|---|---|---|---|---|---|
| `boiler` | boiler, heat exchanger | `fluid_box` (W+E, input-output), `output_fluid_box` (N) | **Baked.** `boiler-N-idle.png` shows the water stubs on both short ends and the steam outlet on the north face; four structure sheets, one per direction | no | heat exchanger also has `energy_source.pipe_covers` / `heat_pipe_covers` for its heat connection — a separate mechanism on the energy source, not the fluid box |
| `generator` | steam engine, steam turbine | `fluid_box` (N+S, input-output) | **Baked.** `steam-turbine-V.png` shows the pipe ends top and bottom; two sheets (`vertical`, `horizontal`), which is all the type has | no | none |
| `assembling-machine` | chemical plant, oil refinery | 4 / 5 boxes, one connection each | **Baked** into the single structure sheet — neither sets `pipe_picture` | no | none |
| `assembling-machine` | assembling machine 2, 3 | 2 boxes, one N input, one S output | **`pipe_picture = assembler2pipepictures()`** — the body sheet has no openings at all | **yes** | `secondary_draw_orders = { north = -1 }` so the north stub draws behind the body; `fluid_boxes_off_when_no_fluid_recipe = true` |
| `container` | — | none | — | — | — |

`assemblerpipes.lua` is the model for the `pipe_picture` route: four sprites, each a pipe stub
entering the machine from that edge and shifted inward (`N` is 71×38 at `by_pixel(2.25, 13.5)` — i.e.
drawn 13.5 px *down* from the north edge, over the body; `S` is 88×61 shifted 31.25 px up; `E`/`W` are
tall and shifted sideways). The sheet `assembling-machine-2.png` has a plain wall on every side, so
with a fluid recipe the stub is drawn and without one nothing is.

Two Space Age fields, for completeness and because they show what the undocumented flags are for:

- **`pipe_picture = util.empty_sprite()` + `always_draw_covers = false` + `enable_working_visualisations`**
  (the foundry, `entities.lua` ~1195): the joined look is a named `WorkingVisualisation` per fluid box
  (`"input-pipe"`, `"output-pipe"`, `always_draw = true`, `enabled_by_name = true`, with a per-direction
  animation and `north_secondary_draw_order = -10 -- behind main animation`). So the foundry draws its
  pipes through the graphics set and switches the fluid-box pipe picture off explicitly.
- **`draw_only_when_connected = true` with `pipe_covers` commented out** (the thruster, ~825), each
  connection naming its own working visualisation `pipe-1`..`pipe-4` via
  `PipeConnectionDefinition.enable_working_visualisations`. The thruster has no unjoined look at all:
  no covers, and (by the field's name) nothing drawn until a pipe arrives.
- **`always_draw_covers = true -- fighting against FluidBoxPrototype::always_draw_covers crazy default`**
  (the cryogenic plant, ~2022): the two boxes that carry a `pipe_picture` force the flag back on so
  they behave like their four siblings that have none. Wube's own comment is the strongest evidence
  that the default flip matters; what it flips is the open point below.
- `pipe_covers_frozen` / `pipe_picture_frozen`: Space Age adds them to base entities in
  `base-frozen-graphics.lua`; base itself never sets either. Under ADR 0003 (Space Age tolerated, not
  integrated) they are out of scope for this repo — an entity without them simply does not change its
  pipes when frozen.

## What Krastorio 2 does

Read off `Krastorio2/prototypes/buildings/*.lua`; the sprites in `Krastorio2Assets/buildings/`.

- **Covers are vanilla's on every machine.** All 23 K2 building files that declare `pipe_covers` set
  it to `pipecoverspictures()`. K2's own `steel-pipe-covers.lua` (its recoloured cover over
  vanilla's shadow) is used **only** by `steel-pipe-to-ground.lua` and `steel-pump.lua` — pipe-line
  entities, not machines. So "steel-covered machines" is not something K2 draws: the steel cover
  belongs to the steel pipe network, and machines show vanilla's iron cap whatever pipe they sit in.
  This repo's `pump-pictures.lua` already records the same reading and keeps vanilla covers for the
  same reason.
- **Machines whose sprite bakes the sockets get only covers**: fuel refinery, advanced steam turbine,
  big/huge storage tank — `pipe_covers` and nothing else, exactly like vanilla's chemical plant.
- **Machines whose sprite has a plain wall get `pipe_picture`**, in one of two shapes:
  - `pipe-picture.lua`, shared by electrolysis plant, fusion reactor, gas power station, atmospheric
    condenser, filtration plant, flare stack, bio-lab, matter associator, matter plant, advanced chemical
    plant, greenhouse (eleven files): a `Sprite4Way` whose **south** entry is `pipe-patch/pipe-patch.png` (a round flange
    seen from above, 55×50 at scale 0.5, `shift = {0.01, -0.58}`, i.e. pulled 0.58 tile inward from the
    south edge) and whose north, east and west are `util.empty_sprite()`. Only a south-facing connection
    gets a drawn socket; the other three rely on the pipe end meeting the wall. Why south alone is not
    stated anywhere in K2 — **inference**: in Factorio's projection the south face is the one where a
    pipe end would visibly stop short of the drawn wall, so it is the only one that needs patching.
  - Per-machine `k-pipe-{N,E,S,W}.png` sets for the advanced assembling machine, advanced furnace,
    quantum computer and research server — K2 recolours of vanilla's assembler stubs, declared with the
    **identical** dimensions and `by_pixel` shifts as `assembler2pipepictures()` (71×38 at 2.25/13.5,
    and so on). The furnace has two variants (`a`/`b`) because its 7×7 body has two connections per face.
- No K2 building sets `always_draw_covers`, `draw_only_when_connected` or a `_frozen` field.
  `hide_connection_info = true` appears only on its steel pipe and steel pipe-to-ground — the same
  places vanilla sets it (pipe, pipe-to-ground and storage tank), each an entity whose connections
  *are* the entity, so the arrows would only clutter.

## What this repo does today

Every machine in `realistic-fusion-refreshed/prototypes/entities.lua` and
`realistic-fusion-refreshed-core/prototypes/entities.lua` deep-copies its `pipe_covers` from the
vanilla donor (so: `pipecoverspictures()` everywhere) and **none sets `pipe_picture`**. That is right
for the boiler- and generator-derived machines, whose donors bake the sockets, and for the mockup art,
which draws the connections into the sheet by design (`graphics/mockup/pictures.lua`). It is a gap
for the Core machines that took a Krastorio 2 building's `graphics_set` but kept the chemical plant's
boxes: K2 draws `pipe-patch` on the electrolysis plant's south-facing connections and `rf-electrolyser`
does not, so a rotated electrolyser shows a pipe stopping at a plain wall where K2's shows a flange.
Small, cosmetic, and only visible in one of four rotations — recorded here, not fixed.

## The list: what a rendered machine must supply per direction

For each fluid box, per direction the box's connection can end up facing (all four, unless the entity
cannot rotate):

1. **Unjoined — `pipe_covers`, always.** A `Sprite4Way`: cover + `draw_as_shadow` layer for
   north/east/south/west. Vanilla's `pipecoverspictures()` is what every vanilla and Krastorio 2
   machine uses, so supplying your own is a style choice, not a requirement. Omit it and an
   unconnected port shows a bare hole in whatever the structure drew.
2. **Joined — one of three routes, not a mix:**
   - **Baked**: draw the socket into the structure sheet for every direction the machine has a sheet
     for. Boiler needs four sheets, generator two, crafting machine one. Nothing else to supply; the
     cover simply sits on top when unjoined. This is the vanilla-majority and K2-majority route.
   - **`pipe_picture`**: plain wall on the sheet, plus a stub sprite per direction, shifted inward, with
     `secondary_draw_orders = { north = -1 }` (or `secondary_draw_order`) so the stub on the far side
     draws behind the body. Vanilla uses this only on `assembling-machine`; the 2016 forum thread
     [pipe_picture on more entities](https://forums.factorio.com/viewtopic.php?t=33875) and the 0.17
     storage-tank fix both say support was per-type once, and no 2.0.77 source says `boiler` or
     `generator` honour it. Treat it as **unverified on those two types**.
   - **Working visualisations** (crafting machines only): `pipe_picture = util.empty_sprite()`,
     `always_draw_covers = false`, and a named `WorkingVisualisation` per box or per connection via
     `enable_working_visualisations`. Space Age's foundry route; most control, most files.
3. **Nothing per direction for**: `hide_connection_info` (arrows only), the `_frozen` fields (ADR 0003),
   `render_layer` (one value per box), and `container` (no fluid box exists).

## Open points

- **What `always_draw_covers` and `draw_only_when_connected` actually do.** Both are undocumented at
  2.0.77 and absent from the changelog. The consistent reading of the base and Space Age usage is
  (**inference**): with a `pipe_picture` present the engine draws the fluid box's art only while the
  box is active — a crafting machine's recipe uses it — and `always_draw_covers = true` restores covers
  on inactive boxes; `draw_only_when_connected` suppresses the box's art until a pipe joins. Nothing
  here depends on either flag unless a machine takes the `pipe_picture` route, at which point a
  screenshot probe (`game.take_screenshot` from a non-headless run, the way `scripts/probe-*.ps1`
  build a map) would settle it in one sitting.
- **Whether `boiler` and `generator` honour `pipe_picture` at all.** Vanilla never sets it on either;
  the field is generic to `FluidBox`, but the storage-tank fix shows a type can ignore it. Same probe.
- **Why Krastorio 2 patches only the south face.** Its choice, unexplained in its sources; matters only
  if this repo copies the patch.

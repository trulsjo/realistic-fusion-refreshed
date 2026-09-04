# Icon conventions in Factorio 2.0.77: sizes, mipmaps, layering, framing

Evidence for [#242](https://github.com/trulsjo/realistic-fusion-refreshed/issues/242), part of the
render-pipeline map [#238](https://github.com/trulsjo/realistic-fusion-refreshed/issues/238), and
the input #249 (the headless render) needs for the icon it writes. **Nothing here chooses a look.**
Section 6 ends in an output spec and a camera preset; where the spec follows from a measured
convention it says so, and where it is a choice it names the options and stops.

Every API claim is against <https://lua-api.factorio.com/2.0.77/> (pinned; `/latest/` is the
experimental build). Every file measurement is against the local install's `data/base` (which reports
`2.0.77` in its `info.json`), the Krastorio 2 assets at `C:\src\factorio\_reference\Krastorio2Assets`,
and this repository's copies under `realistic-fusion-refreshed-assets/graphics/krastorio-2/`.
Measurements were taken with Python 3.13 and Pillow 12.3.0; the one-liners are in section 7 so the
numbers can be re-taken. Paragraphs marked **Inference** are mine and have no source beyond the
measurements above them.

## 1. What the prototypes accept

The three prototypes the ticket names share one icon block, and the type behind it is
[`IconData`](https://lua-api.factorio.com/2.0.77/types/IconData.html).

| Field | Type | Default | Source text (2.0.77) |
|---|---|---|---|
| `icon` | `FileName` | — | "Path to the icon file. Only loaded, and mandatory if `icons` is not defined." |
| `icon_size` | `SpriteSizeType` (int16) | **64** | "The size of the square icon, in pixels. E.g. `32` for a 32px by 32px icon. Must be larger than `0`. Only loaded if `icons` is not defined." |
| `icons` | `array[IconData]` | — | "Can't be an empty array." |

That block is identical on [`ItemPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/ItemPrototype.html)
and [`TechnologyPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/TechnologyPrototype.html).
[`EntityPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/EntityPrototype.html) adds to
`icons`: *"This will be used in the electric network statistics, editor building selection, and the
bonus gui"* — i.e. an entity's own icon is shown in fewer places than its item's; what a player sees
in hand, on belts and in recipes is the **item**'s icon. Entity-only icon fields: `icon_draw_specification`
(alt-mode icons on machines, below), `icons_positioning`, `alert_icon_shift`, `alert_icon_scale`.
Item-only: `dark_background_icon(s)` — *"If this is set, it is used to show items in alt-mode instead
of the normal item icon. This can be useful to increase the contrast of the icon with the dark
alt-mode icon outline"* — and `pictures` — *"Used to give the item multiple different icons so that
they look less uniform on belts. [...] Maximum number of variations is 16. When using sprites of size
`64` (same as base game icons), the `scale` should be set to 0.5."*

**Two 1.1-to-2.0 changes** (the game's own `data/changelog.txt`, version 2.0.0 section, local copy):

> Removed icon_mipmaps from various prototypes using icons. Mipmap count will be inferred from
> icon_size and actual dimensions of the source image.

> Changed icon_size default to be always 64, which is also defined by defines.default_icon_size,
> for the case we ever wanted to change this.

> Added IconData::draw_background.

`defines.default_icon_size` is present on the 2.0.77
[defines](https://lua-api.factorio.com/2.0.77/defines.html) page. So a 2.0 icon table never says
`icon_mipmaps`, and `icon_size = 64` is the default and may be omitted — the repository writes it
anyway (`claim` in `realistic-fusion-refreshed-core/prototypes/vanilla.lua`, `item()` in
`realistic-fusion-refreshed/prototypes/items.lua`), which is harmless.

### `IconData` layers

From the 2.0.77 `IconData` page, quoted:

- *"The rendering order of the individual icon layers follows the array order: Later added icon
  layers (higher index) are drawn on top of previously added icon layers (lower index)."*
- *"By default the first icon layer will draw an outline (or shadow in GUI), other layers will draw
  it only if they have `draw_background` explicitly set to `true`."* And on the field itself:
  *"Outline is drawn using signed distance field generated on load. One icon image will have only
  one SDF generated."*
- *"When the final icon is displayed with a shadow (e.g. an item on the ground or on a belt when
  item shadows are turned on), each icon layer will cast a shadow and the shadow is cast on the
  layer below it."*
- *"The final icon will always be resized and centered in GUI so that all its layers (except the
  `floating` ones) fit the target slot, but won't be resized when displayed on machines in alt-mode.
  For example: recipe first icon layer is size 128, scale 1, the icon group will be displayed at
  resolution /4 to fit the 32px GUI boxes, but will be displayed 4 times as large on buildings."*
- `tint` — *"The tint to apply to the icon."* Default `{r=1,g=1,b=1,a=1}`. Vanilla uses it for
  variants: `item.lua` line 2217 `icons = {{icon = ".../accumulator.png", tint = {1, 0.8, 1, 1}}}`,
  line 2438 the cargo wagon tinted `{r=0.5, g=0.5, b=1}`. Thirteen base icons are shipped as
  greyscale-plus-alpha (`LA` mode) precisely to be tinted: `atomic-bomb-light.png`, `solid-fuel.png`,
  `plastic-bar.png`, `science.png`, the `uranium-*-light.png` set and others.
- `shift` — *"Shift values are 'in pixels' where the overall icon is assumed to be
  `expected_icon_size / 2` pixels in width and height."* `scale` — *"Defaults to
  `(expected_icon_size / 2) / icon_size`."* For a 64 px icon that default is `32 / 64 = 0.5`: the
  icon is authored at twice the size of the 32 px GUI box it fills at 100 % scale.
- `floating` — *"When `true` the layer is not considered for calculating bounds of the icon, so it
  can go out of bounds of rectangle into which the icon is drawn in GUI."*

**What that means for a rendered icon.** The outline seen in alt-mode and the drop shadow seen in
the GUI are **generated by the engine from the alpha channel** at load, tuned by
`UtilityConstants` (`core/prototypes/utility-constants.lua`, local 2.0.77):
`icon_shadow_radius = 17.248`, `icon_shadow_inset = 9.888`, `icon_shadow_sharpness = 0`,
`icon_shadow_color = {a = 1}`; `item_outline_color = {0, 0, 0, 1}`, `item_outline_radius = 16`,
`item_outline_inset = 0`. The PNG should therefore carry **no baked outline** — section 4 checks that
Wube's own icons do not.

## 2. Mipmaps: the one-strip layout

From the 2.0.77 `IconData` page, quoted in full because it is the whole rule:

> The game automatically generates icon mipmaps for all icons. However, icons can have custom
> mipmaps defined. Custom mipmaps may help to achieve clearer icons at reduced size (e.g. when
> zooming out) than auto-generated mipmaps. If an icon file contains mipmaps then the game will
> automatically infer the icon's mipmap count. Icon files for custom mipmaps must contain half-size
> images with a geometric-ratio, for each mipmap level. Each next level is aligned to the upper-left
> corner, with no extra padding. Example sequence: `128x128@(0,0)`, `64x64@(128,0)`, `32x32@(192,0)`
> is three mipmaps.

Measured against that rule:

| Set | Files | Canvas | Levels found (by alpha bbox of each block) |
|---|---|---|---|
| `base/graphics/icons/*.png` | 339 of 341 | **120×64** | 64@(0,0) · 32@(64,0) · 16@(96,0) · 8@(112,0); nothing below any block |
| `base/graphics/icons/fluid/*.png` | 13 | 120×64 | same |
| `base/graphics/icons/signal/*.png` | 116 | 120×64 | same |
| `base/graphics/technology/*.png` | 132 | **480×256** | 256+128+64+32 = 480 |
| Krastorio2Assets `icons/entities/*.png` | 85 | **64×64** | one level, no mipmaps |
| Krastorio2Assets `icons/items`, `icons/fluids`, `icons/equipment` | 140, 20, 51 | 64×64 | one level |
| Krastorio2Assets `technologies/*.png` | 131 | **256×256** | one level |
| This repo `graphics/krastorio-2/{entities,items,fluids}` | 18, 1, 17 | 64×64 | one level |
| This repo `graphics/krastorio-2/technologies` | 11 | 256×256 | one level |

The two vanilla exceptions are `quality-normal.png` (64×64, one level) and `starmap-planet-nauvis.png`
(512×512). So **64 + 32 + 16 + 8 = 120 wide, top-aligned, is the vanilla convention**, exactly as the
forum question that prompted it described in 0.18 — Deadlock989, forum thread
[80619](https://forums.factorio.com/viewtopic.php?t=80619): *"a set of 64x64, 32x32, 16x16 and 8x8
versions of the icon staggered next to each other in a 120x64 canvas."* Posila's reply in that
thread is the only developer statement on whether to bother: *"The game will resample the icons to
create all mipmap levels it needs, so providing custom mipmaps is an optional override of this
mechanism. The game will use bilinear filtering, which usually produces worse results than
Lanczos."* and *"If you can't see difference between in-game generated and custom generated mipmaps,
than there is no benefit for defining custom ones."* That thread is 0.18-era; the 2.0.77 `IconData`
text above says the same thing about auto-generation and inference, so it still holds.

Whether Wube's shipped mip levels are plain downscales: for `heat-boiler.png` the 32 px level
differs from a Lanczos downscale of its own 64 px level by a mean absolute premultiplied difference
of 13.8/255 per channel (10.7 at 16 px, 7.8 at 8 px). **Inference:** they are not a mechanical
resample of the top level — consistent with Albert's account in
[FFF-291](https://factorio.com/blog/post/fff-291) that the four sizes were made deliberately
(*"having control over 4 different sizes is a big relief, especially the 16px and 8px versions"*),
but the FFF does not say whether by hand or by a different filter, and I cannot tell from the pixels.

## 3. How the game scales icons: GUI, world, alerts, map

- **GUI.** The IconData text above puts the target at *"the 32px GUI boxes"* at 100 % GUI scale.
  Albert, [FFF-290](https://factorio.com/blog/post/fff-290): *"the original icons must be 64px in
  order to have a correct visualization at 200% GUI scale."* That is why 64 is the size: the top mip
  level is only ever shown 1:1 at 200 % GUI scale, and at 100 % the 32 px level is what is on screen.
- **World.** FFF-290 again: *"we use the same set of icons in the GUI and in the world"*, and the
  world rescales them from *"maximum zoom level 3.053 = 76.325% icon size"* down to *"minimum zoom
  level 0.382 = 9.55% icon size"*. Those zoom limits are 1.1-era design numbers (the post is from
  2019) and I have not re-derived them for 2.0.77; the point that survives is that the 16 px and 8 px
  levels are what a zoomed-out player sees on belts and in alt-mode, which is why they get made.
- **Alt-mode on machines.** Per `IconData`, not resized to fit — drawn at `scale`. Per entity,
  [`IconDrawSpecification`](https://lua-api.factorio.com/2.0.77/types/IconDrawSpecification.html):
  `shift` (default `{0,0}`), `scale` (default `1.0`), `scale_for_many` (default `1.0`, *"Scale of the
  icon when there are many items"*), `render_layer` (`"entity-info-icon"` | `"entity-info-icon-above"`
  | `"air-entity-info-icon"`). Vanilla uses it to shrink icons on small machines: combinators
  `{scale = 0.5}`, inserter-class entities `{scale = 0.7}` (`entity/circuit-network.lua`,
  `entity/entities.lua`). A boiler-class entity like the heat exchanger draws no alt-mode icon of its
  own, so this does not touch #249's icon.
- **Alerts.** `UtilityConstants.default_alert_icon_scale = 0.5` (`core/prototypes/utility-constants.lua`,
  2.0.77), overridable per entity by `alert_icon_scale` and `alert_icon_shift` (vanilla shifts several
  turrets and the roboport by `util.by_pixel(0, -12)`), and per type by
  `default_alert_icon_scale_by_type` / `default_alert_icon_shift_by_type` (both empty in base). The
  alert icon is the entity's own `icons` — which is the one place the **entity** icon rather than the
  item icon is seen in the world.
- **Map.** I found no 2.0.77 field that draws an entity's icon on the map; the chart draws
  `map_color` / `friendly_map_color` / `enemy_map_color`. Icons on the map are alerts (above) and
  chart tags, which carry their own `SignalID`. Not pursued further.

## 4. How Wube frames a building's icon — measured

The heat exchanger's vanilla icon is `__base__/graphics/icons/heat-boiler.png` (`entity/entities.lua`
line 8994 and `item.lua` line 2359 both point there — the file is not named after the entity).

Alpha bounding box of the 64 px level, for the buildings closest to ours:

| Icon | bbox (l,t,r,b) | w×h | opaque px | semi-transparent px | edge mean RGB vs body mean RGB |
|---|---|---|---|---|---|
| `heat-boiler` | 0,0,64,64 | 64×64 | 2477 | 882 | (116,61,51) vs (121,60,45) |
| `boiler` | 0,0,64,64 | 64×64 | 2473 | 771 | (85,79,68) vs (93,89,73) |
| `steam-turbine` | 0,0,64,64 | 64×64 | 2912 | 577 | — |
| `nuclear-reactor` | 0,0,64,59 | 64×59 | 1889 | 1201 | — |
| `centrifuge` | 0,0,64,64 | 64×64 | 2641 | 721 | (103,107,95) vs (101,119,92) |
| `assembling-machine-2` | 1,2,63,60 | 62×58 | 3212 | 240 | (71,70,78) vs (76,74,86) |
| `storage-tank` | 1,0,63,64 | 62×64 | 2549 | 652 | — |
| `pump` | 0,8,64,60 | 64×52 | 1907 | 590 | — |
| `heat-pipe` | 0,9,64,54 | 64×45 | 876 | 1721 | — |
| `pipe` | 6,0,55,64 | 49×64 | 1935 | 532 | — |

Across the 340 files in `base/graphics/icons/` with content in their 64 px block: mean bbox **59.0 × 59.7 px**, 73 of them
bleeding to all four edges. Across Krastorio 2's 85 entity icons: mean **58.3 × 60.8 px**, 8
full-bleed. This repository's K2 copies: `heat-exchanger.png` 63×64 (bbox 1,0,64,64), `reactor.png`
64×64, `hc-exchanger.png` 59×64, `heater.png` 53×64, `hc-turbine.png` 58×64, `pump.png` 64×52.

Four conventions fall out of the numbers, and hold for both sets:

1. **Fill the square.** The subject reaches the canvas edge or within 2–3 px of it on its long axis;
   average margin is about 2.5 px a side. Icons are not padded.
2. **Oblong subjects keep their aspect and are centred**, not stretched to fill: `heat-pipe` is
   64×45, `pump` 64×52, `pipe` 49×64, and K2's `pump.png` is 64×52.
3. **Transparent background, anti-aliased alpha edge, no baked outline.** Semi-transparent pixels are
   a rim of 240–1200 px (5–30 % of the square). For vanilla the mean colour of that rim is the body
   colour, not black — `heat-boiler` (116,61,51) at the edge against (121,60,45) inside — so the
   dark outline seen in-game is the engine's SDF, not the file's. K2's rims are darker than their
   bodies (`gas-power-station` (64,50,42) vs (99,81,70); `matter-plant` (64,40,62) vs (77,58,76)).
   **Inference:** K2 rendered with shadowed lower edges or a faint baked shadow; it is not a hard
   black outline either, and the SDF is added on top of it in game.
4. **No mipmaps in K2, four levels in vanilla** (section 2). Beside K2's icons a rendered 64×64 with
   no strip is at home; a 120×64 strip is strictly better at small sizes and costs nothing in Lua.

### Framing against the in-world render

Side by side (scratch composites, not committed): the vanilla `heatex-N-idle.png` sheet (269×221,
the 3×2 heat exchanger facing north) next to `heat-boiler.png`, and the first 380×380 frame of
Krastorio 2's `buildings/gas-power-station/gas-power-station.png` (3040×1520, 8×4 frames) next to
its icon `icons/entities/gas-power-station.png`.

**Inference, from looking, not measured:**

- **Vanilla does not crop the world sprite.** The icon shows the same machine from a noticeably
  lower camera pitch — more of the front face, less of the roof — with the chimney kept as the
  silhouette cue, the heat-pipe stubs dropped, and the colour pushed (the exchanger glows red in the
  icon; the world sprite is grey-green with a copper pipe). This matches Albert's stated method in
  FFF-290: *"we design the icons in a very synthetic way. We simplify the shape to its purest
  meaning"*, and the rejected alternative, *"a very minimalistic flat icon"*, because the same
  icons must *"integrate as world objects"*. Nothing in FFF-290/291 says whether Wube's icons are
  re-rendered from the 3D model at a second camera or painted; the pixels are consistent with a
  re-render at a lower pitch plus paint-over, and I cannot separate the two.
- **Krastorio 2 keeps the world camera.** The gas-power-station icon is the same oblique top-down
  view as the building sheet, tightly recomposed: the central exchanger block, one of the two red
  tanks, two pipe runs — the building's parts rearranged to fill a square, not the whole 5×5
  footprint scaled down. That is why K2 building icons read as "a piece of the machine" where
  vanilla's read as "the machine".
- **The two styles differ in pitch, agree on everything else**: same yaw as the north-facing sheet,
  orthographic, filled square, transparent, no outline. The world camera's own pitch is
  `research-camera`'s question (#238), not this one; forum thread
  [80136](https://forums.factorio.com/viewtopic.php?t=80136) — community members, no Wube reply —
  measures vanilla sprites at roughly 38–53° from horizontal depending on the entity, which is only
  evidence that "45°" is not a fixed vanilla constant either.

## 5. What the repository does today

- Items: `realistic-fusion-refreshed/prototypes/items.lua` derives the item icon from the entity name
  under `graphics/krastorio-2/entities/` with `icon_size = 64`, and the entity takes the same file via
  `claim` (core `prototypes/vanilla.lua`): `e.icons = {{icon = path, icon_size = 64}}; e.icon = nil`.
  Correct for 2.0.77; `icon_size` is the default and the explicit value is redundant, not wrong.
- Technologies: `icon = ".../krastorio-2/technologies/<name>.png", icon_size = 256`, files 256×256.
  Correct; base uses 256 too (its files 480×256 add three mip levels; K2's do not).
- `rf-heat-exchanger`'s icon is K2's `icons/entities/gas-power-station.png` (NOTICE.txt line 392),
  wearing the repository's own 5×15 mockup sheets (`graphics/mockup/heat-exchanger*.png`, 320×960 and
  960×320 at 64 px/tile, `SCALE = 0.5`). The icon and the building do not depict the same object
  today, which is the ticket's stated reason for the rendered icon replacing it.

## 6. Output spec and camera preset for #249

**Output spec — follows from sections 1–4, no choice in it:**

| | Value | Why |
|---|---|---|
| File | RGBA PNG, `graphics/rendered/<machine>/icon.png` | ADR-free; path is #238's |
| Canvas | **120×64**: 64@(0,0), 32@(64,0), 16@(96,0), 8@(112,0), top-left aligned, nothing else on the canvas | vanilla convention; game infers 4 levels from 120 vs `icon_size = 64` |
| Mip levels | each level downscaled from the **render at full resolution**, not from the 64 px level, with Lanczos | posila: engine uses bilinear, Lanczos better; downscaling from the source keeps more than re-downscaling 64 |
| Background | fully transparent; alpha anti-aliased; **no outline, no drop shadow** | engine draws SDF outline and GUI shadow from alpha (`draw_background`, `icon_shadow_*`, `item_outline_*`) |
| Framing | orthographic; subject's bbox fills the 64 px square to a margin of 2–3 px on its long axis; short axis centred, aspect kept | measured 59.0×59.7 mean, oblong icons letterboxed |
| Lua | `icons = {{icon = path}}` (or `icon_size = 64` explicit, as `claim` does); **no `icon_mipmaps`** | 2.0.0 changelog; field gone |
| Tech icon, if ever rendered | 256×256, or 480×256 with 128/64/32 levels; `icon_size = 256` | base 480×256; K2 and repo 256×256 |
| Render size | render at ≥ 512 px on the long axis, downsample to 64/32/16/8 | so the 8 px level has something to average; the number 512 is mine |

**Camera preset — partly a choice. The parts that follow from the evidence:** orthographic; same
**yaw** as the north-facing structure sheet (both vanilla and K2 icons face the way the north sprite
faces, and the item icon is what sits beside K2's in the crafting menu); the light rig the world
render uses, so the icon's shading matches the building it places; framed to the model's bounding
box, not the footprint (vanilla's chimney and K2's pipes both overhang the tile grid).

**The two things that are a decision, with the options as measured — not chosen here:**

1. **Pitch.** *(a)* the world camera's pitch, as Krastorio 2 does — the icon is a small building and
   matches the 18 K2 entity icons it sits among; *(b)* a lower pitch, as vanilla does — more front face,
   reads as "the machine" at 16 px, but is a second camera to maintain and looks unlike its K2
   neighbours until the K2 set is replaced (which #238 says is a fresh effort).
2. **What a 5×15 machine shows in a square.** Its footprint is 1:3. *(a)* the whole building
   letterboxed at 64×~21 px plus overhang — vanilla's rule for oblong subjects (`heat-pipe`,
   `pump`), honest about the shape, but at 8 px it is a line; *(b)* a characteristic section
   recomposed to fill the square — K2's rule (`gas-power-station` shows one tank of two), reads at
   every size, but the icon is then not a picture of the entity; *(c)* the north-facing end-on view
   (the 5-wide face), which fills a square from a real camera without recomposition — nothing in
   either set does this, so it would be the repository's own convention.

Everything else in #249's icon step can proceed without those two answers, since the strip layout,
transparency, margins and Lua are fixed above and the camera is the world rig with two parameters
left open.

## 7. Re-taking the measurements

Pillow, from `data/` of the install (`Resolve-FactorioExe` in `scripts/factorio-lib.ps1` finds it):

```python
from PIL import Image
im = Image.open("base/graphics/icons/heat-boiler.png").convert("RGBA")   # (120, 64)
for x, s in ((0, 64), (64, 32), (96, 16), (112, 8)):
    print(s, im.crop((x, 0, x + s, s)).getchannel("A").getbbox())        # each level's content
a = im.crop((0, 0, 64, 64)).getchannel("A"); h = a.histogram()
print(a.getbbox(), h[255], sum(h[1:255]), h[0])                          # bbox, opaque, semi, clear
```

The aggregate (mean bbox over a directory, full-bleed count) is the same call in a loop over
`glob("base/graphics/icons/*.png")` and `glob("<Krastorio2Assets>/icons/entities/*.png")`; the mip
fidelity figure is `abs(premultiply(level) - premultiply(lanczos(top, level.size))).mean()`.

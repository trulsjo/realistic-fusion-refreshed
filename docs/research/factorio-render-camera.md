# How Factorio projects and lights a building

What camera, light and shadow setup reproduces the base game's building look when rendering in
Blender, and what the Krastorio 2 sheets already in the repo say about `shift`
([#239](https://github.com/trulsjo/realistic-fusion-refreshed/issues/239), part of #238).

Checked 2026-09-04 against **Factorio 2.0.77** — the prototype docs at
`https://lua-api.factorio.com/2.0.77/`, the `data/` directory of the Steam install of that build,
and the sheets under `realistic-fusion-refreshed-assets/graphics/krastorio-2/buildings/`. Pixel
measurements come from `scripts/probe-sprite-geometry.py`, committed so the next build can be asked
the same question. Every claim below is tagged **[source]** (a document says it), **[measured]** (a
sheet or the game data shows it) or **[inference]** (follows from the two, but nobody at Wube has
said it).

## The short version

| Question | Answer | Status |
|---|---|---|
| Projection | 45° camera pitch over **square** tiles — a non-physical projection Wube calls a "contradiction" | [source] FFF-269 |
| Orthographic? | Never stated by Wube; the only angle they give is the 45°. Every community Blender recipe uses an orthographic camera and nothing in the sprites contradicts that | [inference] |
| Vertical scale | **Open.** 45° + square tiles forces a stretch somewhere; no Wube source says whether height is drawn at 1.0 or 0.707 of ground scale | open |
| Light direction | From the screen's **left (west)**, shadows fall **east** with a small southward component; identical in all four rotation frames of the same entity, so the light is fixed to the screen, not the model | [measured] on vanilla sheets; matches community posts; no Wube statement |
| Shadow sheet | **100 % black, full alpha** — a hard mask | [measured], matches FFF-56 |
| Shadow compositing | All shadows drawn into one offscreen buffer, then blended at **50 % opacity**; overlaps do not darken twice; stored as **BC4** (alpha only) | [source] FFF-56, FFF-227, FFF-281, posila |
| Pixel scale | **64 px per tile at `scale = 0.5`**; `shift` is in tiles; `util.by_pixel` divides by 32, `util.by_pixel_hr` by 64 | [source] docs + `util.lua`, [measured] steel chest |
| What `shift` means on the K2 sheets | The sheet is cropped tight to the alpha; `shift` puts the crop's centre back where the model's origin was. It centres the footprint, not the image | [measured] |

## 1. Projection

**[source]** FFF-269, *Roadmap update & Transport belt perspective* (V453000):

> "Our 'camera angle' is 45 degrees, which in 'real projection' would result in rectangular
> tiles, but in Factorio this is contradicted by our tiles being square. This contradiction makes
> for a whole lot of challenges which we are addressing more and more over time."
> — <https://factorio.com/blog/post/fff-269>

**[source]** The engine agrees the angle is 45°. `RotatedSprite.apply_projection` (default `true`)
is "Used to fix the inconsistency of direction of the entity in 3d when rendered and direction on
the screen (where the 45 degree angle for projection is used)." —
<https://lua-api.factorio.com/2.0.77/types/RotatedSprite.html>, same text on
<https://lua-api.factorio.com/2.0.77/types/RotatedAnimation.html>. The same field exists on trigger
areas (`apply_projection = true` on the atomic bomb's 12-tile `set-tile` radius in
`base/prototypes/entity/atomic-bomb.lua`), where it turns a world circle into the screen ellipse.

**[source]** `core/prototypes/utility-constants.lua` in 2.0.77 carries
`train_on_elevated_rail_shadow_shift_multiplier = { 1.41421356237, 1 }` — √2 in x, 1 in y — so the
engine's own shadow-offset arithmetic for elevated objects contains the 45° factor.

**[source]** Wube renders everything from 3D (FFF-19: "All the objects in the game (including the
terrain) have actually been rendered from the 3D models" — <https://www.factorio.com/blog/post/fff-19>)
and organises Blender scenes as MODEL scenes plus a RENDER scene that composites RenderLayers
(FFF-146 <https://factorio.com/blog/post/fff-146>, FFF-218 <https://www.factorio.com/blog/post/fff-218>).
**Neither post gives a camera angle, ortho scale, light direction or pixels per tile**, and no other
FFF or wiki page found does either. "Orthographic" does not appear in any Wube statement.

### What the contradiction means for a Blender scene [inference]

A true orthographic camera pitched 45° projects a unit ground square to 1 wide × cos 45° = 0.707
tall. Factorio's tiles are 1 × 1 on screen. So one axis was stretched after (or before) the render,
and the two candidates differ in how tall a wall looks:

| Construction | Ground | A vertical of height *h* appears as | Horizontal circle appears as |
|---|---|---|---|
| **A.** Render at 45°, stretch the image ×√2 in screen-Y (or squash the model ×1/√2 in world-Y before rendering) | square | *h* (full height) | circle |
| **B.** Render at 45°, leave the image alone, and accept that the ground is 0.707 tall per tile | *not* square — rules itself out for buildings on the tile grid | 0.707 *h* | ellipse 1 : 0.707 |

Only A yields square tiles from a 45° camera, so if Wube's camera really is 45° and their tiles
really are square, **A (or something equivalent to it) is what happens**, and a building's wall is
drawn at its true height in tile units. That is a deduction from two Wube sentences, not something
Wube has said, and the forum thread where players measured vanilla sprites got "around 38°–38.4°"
for the burner drill and assembler and 53° for others (bhaktivedanta, darkfrei,
<https://forums.factorio.com/viewtopic.php?t=80136>, no developer reply) — which says the effective
angle is not cleanly measurable off finished sprites, or that individual models were adjusted.
**Calibrate rather than trust:** render a 1 × 1 × 1 tile cube with the chosen setup, and compare
its on-screen height and shadow against a vanilla 1 × 1 entity with the probe before rendering
anything real.

Community recipes, for what they are worth — all orthographic, all 45°, none from Wube:

- SkaceKachna, 2014: camera "Orthographics", rotation X 45 / Y 0 / Z 45, Sun lamp, shadow plane
  alpha "about 0.5" — <https://forums.factorio.com/viewtopic.php?t=5336>
- valerian: "Camera: orthographic, at an angle of 45°", rotation X 45 / Y 0 / Z 180, sun rotation
  X 0 / Y 39.3 / Z 5, shadow pass via a Shadow Catcher plane and a black material override —
  <https://forums.factorio.com/viewtopic.php?t=114275>
- AlveKatt: "The camera faces 45 degrees down", "Light comes in at a 45 degree angle from the
  left" — <https://forums.factorio.com/viewtopic.php?t=92537>

## 2. Light direction — measured, not sourced

No Wube post or doc found states where the sun is. What exists:

- ssilk (moderator, 2014): "the sprites are rendered with light coming from upper left" —
  <https://forums.factorio.com/viewtopic.php?t=1089>
- kirazy: "the shadows are cast from a light source to the west" —
  <https://forums.factorio.com/viewtopic.php?t=92473>; posila in the same thread: "Our art
  direction is to have sharp shadows", no direction given.

**[measured]** on the 2.0.77 sheets, tiles relative to the entity origin, +x east, +y south
(`Vector`: "Positive x goes east, positive y goes south" —
<https://lua-api.factorio.com/2.0.77/types/Vector.html>):

| Entity | Footprint | Shadow alpha bbox | Shadow beyond footprint |
|---|---|---|---|
| big-electric-pole, all 4 direction frames | 2×2, pole ~4.5 tiles tall on screen | x [−0.7, +4.8], y [−0.7, +0.7], centroid y ≈ 0 | **4.8 east, ~0 south** — lies flat along +x |
| steam-turbine H (5×3) | x ±2.5, y ±1.5 | x [−2.51, +4.27], y [−0.59, +1.72] | 1.77 east, 0.22 south |
| steam-turbine V (3×5) | x ±1.5, y ±2.5 | x [−1.11, +3.58], y [−1.27, +2.80] | 2.08 east, 0.30 south |
| boiler N / E / S / W | 3×2 or 2×3 | shadow centroid minus body centroid: N (+0.75, +0.52), E (+0.66, +0.47), S (+0.71, +0.53), W (+0.78, +0.47) | east and a little south, **every rotation** |
| steel-chest (1×1) | x ±0.5, y ±0.5 | x [−0.48, +1.23], y [−0.11, +0.55] | 0.73 east, 0.05 south |

Two things follow. The light is **west of the object, low enough that a tall pole's shadow is
longer than the pole is tall on screen** (4.8 tiles of shadow for ~4.4 tiles of screen height,
ratio ≈ 1.1; under construction A above that is an elevation of ≈ 42°, under B ≈ 52° — another
reason the vertical factor is the open point). And it is **fixed to the screen**: the pole is one
`RotatedSprite` with `direction_count = 4`, the boiler has four separate sheets, and every frame
casts east. That is Truls's expectation (2026-09-04) confirmed on the sheets: rotate the model for
each direction, leave the camera and the sun where they are.

The K2 sheets in the repo behave the same way — hc-turbine H shadow extends to +4.53 against a body
ending at +3.54, V to +3.21 against +2.49; reactor shadow to +8.63 against a 15-tile footprint
ending at +7.5 — so whoever rendered them used the same convention.

## 3. Shadows: what goes in the sheet and what the engine does with it

**[measured]** Every shadow sheet examined, vanilla and K2, is **RGB (0, 0, 0)** wherever it has
alpha, with alpha 255 across the body of the shadow (median 255, only the anti-aliased edge below
that). They are hard black masks, not 50 % grey.

**[source]** That is by design, and the softness is applied at composite time:

- FFF-42 (Tomas): the shadow used to be part of the entity sprite; that gave "'double shadow'
  glitches", shadows hidden by buildings drawn over them, and no flipping of symmetrical objects,
  "So we decided to make a mechanism when shadow will be rendered separately" —
  <https://factorio.com/blog/post/fff-42>
- FFF-56: "the shadows of some objects can be drawn separately into one picture as 100% black
  shapes ... Once the shadows are merged in the picture, they are drawn on the screen with 50%
  transparency" — <https://www.factorio.com/blog/post/fff-56>
- FFF-227 (Ernestas, posila): "the overlapping shadow sprites all being merged before being
  rendered. This means there will no longer be the deep black areas where the old tree shadows
  would layer on each other" — <https://factorio.com/blog/post/fff-227>
- posila, FFF-264 thread: "We have shadows as separate sprites from entities, and we draw them to
  offscreen buffer first, so they don't add up as they overlay each other; and then we blend the
  offscreen buffer with 50% opacity over the game view." —
  <https://forums.factorio.com/viewtopic.php?t=62921&start=60>
- FFF-281 (posila): "regardless of the texture compression option, shadow sprites will be always
  compressed using the BC4 format" — <https://www.factorio.com/blog/post/fff-281>. BC4 is a
  single-channel format, so **only the alpha of a shadow sheet survives**; its colour is supplied
  by the compositor [inference from the format].

**[source]** The prototype side says only which layer is the shadow, not what is done to it.
`SpriteParameters.draw_as_shadow`: "Only one of `draw_as_shadow`, `draw_as_glow` and
`draw_as_light` can be true. This takes precedence over `draw_as_glow` and `draw_as_light`." —
<https://lua-api.factorio.com/2.0.77/types/SpriteParameters.html>. `SpriteFlags` lists `"shadow"`
and `"group=shadow"` with no description — <https://lua-api.factorio.com/2.0.77/types/SpriteFlags.html>.
`UtilityConstants` has no entity-shadow colour or alpha; its only shadow entries are the icon
shadow, tree shadow roughness/speed and the elevated-rail multiplier quoted above —
<https://lua-api.factorio.com/2.0.77/prototypes/UtilityConstants.html>. (`default_shadow_color =
{0, 0, 0, 0.35}` in `core/prototypes/style.lua` is a **GUI** style constant and has nothing to do
with world shadows.)

**Consequence for a render [inference]:** output the shadow as a black silhouette on transparent at
full alpha, not pre-faded, and do not bake it into the body sheet. A 50 % grey shadow sheet would
be drawn at 25 %.

## 4. Pixel scale and `shift`

**[source]** `SpriteParameters.shift`: "The shift in tiles. `util.by_pixel()` can be used to divide
the shift by 32 which is the usual pixel height/width of 1 tile in normal resolution."
`SpriteParameters.scale`: "Values other than `1` specify the scale of the sprite on default zoom. A
scale of `2` means that the picture will be two times bigger on screen." —
<https://lua-api.factorio.com/2.0.77/types/SpriteParameters.html>.

**[source]** `core/lualib/util.lua`, 2.0.77:

```lua
function util.by_pixel(x,y)    return {x / 32, y / 32} end
function util.by_pixel_hr(x,y) return {x / 64, y / 64} end
```

So 1 tile = 32 px at `scale = 1` = **64 px at `scale = 0.5`**, which is how every 2.0 base sheet is
authored: the `Sprite` doc's own example is a wooden chest at `scale = 0.5` with a shadow layer at
`scale = 0.5, shift = util.by_pixel(10, 6.5)` — <https://lua-api.factorio.com/2.0.77/types/Sprite.html>.

**[measured]** `steel-chest.png` is 64 px wide at `scale = 0.5`, and its alpha bbox is x [−0.51,
+0.49] tiles — exactly one tile for a 1 × 1 entity. **Render at 64 px per tile** and ship at
`scale = 0.5`; in Blender that is `resolution_x = 64 × (tiles across the frame)` with
`ortho_scale = tiles across the frame`.

### What the Krastorio 2 sheets say about `shift` [measured]

The `shift` values in the repo's `*-pictures.lua` files are K2's own and are not recoverable from a
PNG (`realistic-fusion-refreshed-core/prototypes/entities.lua` says why they are copied rather than
measured). Running the probe over them shows what those numbers do:

| Sheet | Footprint | `shift` | Body alpha bbox after shift | Bottom edge vs. south footprint edge |
|---|---|---|---|---|
| reactor.png 1100×1100 | 15×15 | (1.01, 0) | x [−7.52, +7.57], y [−8.19, +7.66] | +0.16 |
| aneutronic-reactor.png 660×706 | 10×10 | (0, −0.5) | x [−5.16, +5.16], y [−6.00, +5.02] | +0.02 |
| brine-concentrator.png 460×520 | 7×7 | (0, −0.2) | x [−3.55, +3.55], y [−4.15, +3.69] | +0.19 |
| gas-mixer.png 451×535 | 7×7 | (0, −0.48) | x [−3.52, +3.52], y [−4.64, +3.68] | +0.18 |
| hc-exchanger.png 462×500 | 7×7 | (−0.1, −0.2) | x [−3.69, +3.49], y [−4.11, +3.71] | +0.21 |
| composite-tank.png 256×256 | 3×3 | (0, 0) | x [−1.53, +1.53], y [−1.86, +1.73] | +0.23 |
| deuterium-extractor.png 380×380 | 5×5 | (0, 0) | x [−2.53, +2.53], y [−2.86, +2.66] | +0.16 |

Three regularities:

1. **Sheets are cropped tight to the alpha.** The aneutronic body is 660 × 706 px = 10.31 × 11.03
   tiles at 64 px/tile; its alpha bbox is 10.32 × 11.02. K2 cropped the render to its content, which
   throws away where the model's origin was in the frame.
2. **`shift` puts it back.** After the shift, every body is centred on the footprint in x (to
   ±0.05 tiles) and its bottom edge sits on or just below the south footprint edge (+0.02 to
   +0.23 — a base plate or ground detail). The `−0.5` on the aneutronic reactor is not an artistic
   offset; it is half the difference between "11.03 tiles tall" and "10 tiles deep", i.e. the
   crop's centre is half a tile north of the model's origin because the roof adds a tile of height
   above the back edge. The reactor's `1.01` says K2's 1100 px canvas had the model a tile off
   centre, nothing more.
3. **Shadow sheets get their own shift for the same reason** — aneutronic shadow `(0.57, 0.27)` puts
   its west edge at −5.09 (the west footprint edge, where a shadow from the west begins) and its
   east edge at +6.23. The shadow is cropped and re-centred independently of the body.

So `shift` on a K2 sheet does not encode any convention about where the model's origin is relative
to the tile grid — the origin is the footprint centre, as in vanilla — it encodes the crop.

**Recipe for our own renders [inference]:** either render an uncropped frame centred on the model
origin and ship `shift = {0, 0}` (simplest, costs some transparent pixels — the reactor's 1100 px
square is exactly this), or crop tight and set
`shift = util.by_pixel_hr(crop_centre_x − origin_x, crop_centre_y − origin_y)` in 64 px/tile sheet
pixels. Doing it by eye is how a building ends up a fraction of a tile off its collision box.

## 5. A Blender setup that follows from the above

Everything in this section is **[inference]** assembled from the facts above; the two items marked
*calibrate* are the ones no source settles.

- **Camera:** orthographic, rotation X = 45°, Y = 0, Z = 0 with Blender +Y as Factorio north (the
  camera looks north and down). `ortho_scale` = tiles across the frame; `resolution` = 64 × tiles.
  Frame centred on the model origin (footprint centre) so `shift` is zero, or record the crop.
- **Vertical factor — *calibrate*:** either stretch the output ×√2 in Y (construction A) or leave
  it (B). Render a 1 × 1 × 1 cube, place it beside `steel-chest` in a test map, and pick the one
  whose wall height and shadow length match the neighbourhood. Record the choice in this file.
- **Sun:** one Sun lamp from world −X (screen left), azimuth exactly along −X (the pole's shadow has
  no north–south component), elevation ≈ 45° — *calibrate* together with the vertical factor using
  the pole ratio above (shadow length ≈ 1.1 × on-screen height). Hard shadows, no soft-size
  ("Our art direction is to have sharp shadows" — posila).
- **Rotations:** rotate the model about Z for N/E/S/W; camera and sun stay put.
- **Passes:** body (colour + alpha, premultiplied — `SpriteSource.premul_alpha` defaults to `true`,
  <https://lua-api.factorio.com/2.0.77/types/SpriteSource.html>), shadow (shadow-catcher ground
  plane, black override material, alpha only, full opacity, `draw_as_shadow = true`), and where
  wanted a glow/light layer (`draw_as_glow` / `draw_as_light`, additive) — the same split FFF-146
  and FFF-218 describe as RenderLayers into compositor nodes.
- **Ship** every layer at `scale = 0.5`.

## What this leaves open

1. **The vertical factor** (construction A vs. B) — the only item where Wube's two sentences admit
   two readings. Settled by a cube-and-steel-chest calibration render, not by more reading.
2. **Sun elevation** follows from 1; the measured constraint is shadow-length ≈ 1.1 × screen height
   for a vertical object.
3. **Whether Wube's camera is orthographic** is undocumented; nothing in the sprites argues against
   it and every community recipe assumes it.
4. Body sheets were not checked for a sky/ambient colour or a fill light; the left-third vs
   right-third luminance the probe prints (west side brighter on most bodies: boiler W 57 vs 24,
   big pole 87–105 vs 54–78) is consistent with a single key from the west but says nothing about
   fill.

## Corrections to the brief this note was written from

FFF-172 is posila on blend modes, premultiplied alpha and tint
(<https://factorio.com/blog/post/fff-172>), not shadows; the "offscreen buffer, 50 %" statement is
posila's forum post above. FFF-115 is about the power switch. `axially_symmetrical` does not exist
on `RotatedSprite` or `RotatedAnimation` in 2.0.77. The Krastorio2Assets README
(<https://codeberg.org/raiguard/Krastorio2Assets>) says only that assets are split out so the base
mod can hotfix; neither it nor the Krastorio2 README says anything about how the sprites were
rendered.

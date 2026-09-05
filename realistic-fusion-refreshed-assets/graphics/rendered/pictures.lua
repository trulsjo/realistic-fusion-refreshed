-- Rendered building sprites: the real art, drawn for this mod from a Blender model.
--
-- THIS IS THE REPOSITORY'S OWN WORK and carries the repository's own licence. Nothing here derives
-- from Krastorio 2 or from either predecessor: the models are built procedurally with no imported
-- texture or mesh, which is the licence rule the whole render route was written under (#238).
--
-- The PNGs are written by `/render-machine rf-<machine>` (tools/render-machine.py, #251), which
-- extracts the machine's footprint and connections from --dump-data and renders the stored model in
-- models/<machine>/. Never edit one by hand: re-render instead, and the manifest beside the sheets
-- says which model and which geometry produced them.
--
-- THIS REPLACES A MOCKUP, NOT A VANILLA SPRITE. ../mockup/pictures.lua stays for the machines whose
-- art is still to come; a machine moves over here when its model exists and Truls has accepted the
-- look in game. rf-heat-exchanger is the first (#252, closing #108).

local DIRECTORY = "__realistic-fusion-refreshed-assets__/graphics/rendered/"

-- 64 pixels to the tile at scale 0.5, the same as the mockups, vanilla and Krastorio 2.
local PIXELS_PER_TILE = 64
local SCALE = 0.5

-- THE SHEET IS THE FOOTPRINT PLUS A MARGIN ON EVERY SIDE, which is the one number the Lua has to
-- know that the prototype cannot tell it. models/rf_blender.py MARGIN_TILES fixes it at 3 -- the
-- machine's shadow reaches 2.83 tiles past its east edge and 2 clipped it (#249) -- and every
-- rendered manifest records the value it used as `frame.margin_tiles`. The data stage cannot read
-- JSON, so the number is retyped here; if it ever changes, both files change together. The margin
-- is symmetric on purpose, so `shift` is zero and nothing has to be re-centred.
local MARGIN_TILES = 3

local function frame_px(tiles) return (tiles + 2 * MARGIN_TILES) * PIXELS_PER_TILE end

--- One layered sprite -- structure over its shadow -- for a machine at a given footprint.
--
-- @param machine  directory name under graphics/rendered/, e.g. "heat-exchanger"
-- @param file     basename inside it, without .png
-- @param tiles_w  footprint width in tiles, as the sheet was rendered
-- @param tiles_h  footprint height in tiles
local function sheet(machine, file, tiles_w, tiles_h)
  local path = DIRECTORY .. machine .. "/" .. file
  return {
    layers = {
      {
        filename = path .. ".png",
        priority = "extra-high",
        width = frame_px(tiles_w),
        height = frame_px(tiles_h),
        scale = SCALE,
      },
      {
        -- Rendered unfaded, black at full opacity: the engine blends a shadow at 50 % itself
        -- (#239), so fading it here would fade it twice.
        filename = path .. "-shadow.png",
        priority = "extra-high",
        width = frame_px(tiles_w),
        height = frame_px(tiles_h),
        scale = SCALE,
        draw_as_shadow = true,
      },
    },
  }
end

--- The glow sheet as a single-frame animation, drawn additively over the structure.
--
-- Same frame as the structure, so it needs no shift of its own: the emissive parts are rendered in
-- place with everything else black.
local function glow(machine, file, tiles_w, tiles_h)
  return {
    filename = DIRECTORY .. machine .. "/" .. file .. "-glow.png",
    priority = "extra-high",
    width = frame_px(tiles_w),
    height = frame_px(tiles_h),
    scale = SCALE,
    draw_as_glow = true,
    blend_mode = "additive",
  }
end

local M = {}

--- A BoilerPictureSet, one structure and one glow per direction.
--
-- FOUR SHEETS, NOT TWO, for the reason ../mockup/pictures.lua sets out at length: the engine turns
-- the connections and not the picture, so every quarter turn puts the sockets somewhere else.
--
-- THE GLOW GOES IN `fire_glow`, WHICH IS THE ENGINE'S OWN WHILE-WORKING LAYER. A boiler's structure
-- never plays and only `fire` and `fire_glow` are state-driven (#241), and `fire_glow` is exactly
-- what the look note asks for: drawn while the machine is burning, held for `burning_cooldown`
-- ticks after it stops, and additive. `fire` is left unset -- there is no firebox on a machine that
-- burns reactor energy in a manifold. The caller must set `burning_cooldown` above 1 or the engine
-- draws neither.
--
-- @param machine  directory name under graphics/rendered/
-- @param tiles_w  footprint width in tiles
-- @param tiles_h  footprint height in tiles
function M.boiler(machine, tiles_w, tiles_h)
  local function side(file, w, h)
    return { structure = sheet(machine, file, w, h), fire_glow = glow(machine, file, w, h) }
  end
  return {
    north = side(machine,          tiles_w, tiles_h),
    east  = side(machine .. "-e",  tiles_h, tiles_w),
    south = side(machine .. "-s",  tiles_w, tiles_h),
    west  = side(machine .. "-w",  tiles_h, tiles_w),
  }
end

--- The machine's icon: the 120x64 mipmap strip render.py composes (#242).
--
-- `icon_size = 64` with a 120 px file is how the engine is told there are four levels; 2.0 removed
-- `icon_mipmaps` and infers the count from the width. Shaped for `claim`'s `icons` entry.
function M.icon(machine)
  return DIRECTORY .. machine .. "/" .. machine .. "-icon.png"
end

return M

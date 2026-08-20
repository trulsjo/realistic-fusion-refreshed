-- The plasma heater's in-world graphics, derived from Krastorio 2 and licensed LGPLv3.
--
-- THIS FILE IS NOT COVERED BY THE REPOSITORY'S LICENCE, for the same reason as reactor-pictures.lua
-- beside it: every dimension below is read off Krastorio 2's prototypes/buildings/fuel-refinery.lua,
-- which is LGPLv3, so this is a derivative of it and belongs where the LICENSE beside it applies.
--
-- Unlike the reactor, nothing had to move to make this fit. rf-heater is a copy of vanilla's
-- chemical plant and Krastorio 2's fuel refinery is modelled on the same machine, so the two agree
-- exactly: collision box {{-1.2, -1.2}, {1.2, 1.2}}, selection box {{-1.5, -1.5}, {1.5, 1.5}}, and
-- the same four pipe connections -- two in at north {-1, -1} and {1, -1}, two out at south {-1, 1}
-- and {1, 1}. This is a sprite swap and only a sprite swap: no footprint change, no pipe moves,
-- nothing to migrate.
--
-- Krastorio 2 builds this with make_4way_animation_from_spritesheet, a base helper that slices one
-- sheet into four directions. The slicing is written out here instead, because relying on a helper
-- from __base__'s internals is a dependency on something Wube never promised to keep.
--
-- ponytail: Krastorio 2's working_visualisations -- a boiling patch tinted by the recipe -- are not
-- taken. They are four per-direction pixel offsets and a recipe tint for a puddle, on a machine
-- whose whole job here is one recipe. Add them if the heater ever gains a second.

local DIRECTORY = "__realistic-fusion-refreshed__/graphics/krastorio-2/buildings/heater/"

-- North, east, south, west, in that order along each sheet -- the order the base helper uses and
-- the order the sheets are laid out in.
local DIRECTIONS = { "north", "east", "south", "west" }

local BODY   = { file = "heater.png",        width = 244, height = 268, shift = { -5, -4.5 } }
local SHADOW = { file = "heater-shadow.png", width = 350, height = 219, shift = { 31.5, 10.75 } }

--- One direction's layer, sliced out of the sheet by index.
local function layer(sheet, index, shadow)
  return {
    filename = DIRECTORY .. sheet.file,
    x = sheet.width * index,
    width = sheet.width,
    height = sheet.height,
    frame_count = 1,
    -- Krastorio 2 writes these with util.by_pixel; a pixel is 1/32 of a tile.
    shift = { sheet.shift[1] / 32, sheet.shift[2] / 32 },
    scale = 0.5,
    draw_as_shadow = shadow or nil,
  }
end

local animation = {}
for index, direction in ipairs(DIRECTIONS) do
  animation[direction] = {
    layers = { layer(BODY, index - 1), layer(SHADOW, index - 1, true) },
  }
end

return { animation = animation }

-- The plasma pump's in-world graphics, derived from Krastorio 2 and licensed LGPLv3.
--
-- THIS FILE IS NOT COVERED BY THE REPOSITORY'S LICENCE, for the same reason as reactor-pictures.lua
-- beside it: every width, height, frame count, line length and shift below is read off Krastorio 2's
-- prototypes/buildings/steel-pump.lua, which is LGPLv3, so this is a derivative of it and belongs
-- where the LICENSE beside it applies.
--
-- WHY IT NEEDED ART AT ALL (#45). rf-pump exists because a vanilla pump is a vanilla pipe connection,
-- so with containment in place it cannot join a plasma line -- see entities.lua. That makes it part
-- of the plasma-safe set, and the set's whole argument is that a player can SEE which equipment is
-- plasma-rated before #26's rule can feel fair. rf-pipe and rf-pipe-to-ground already carry
-- Krastorio 2's steel line; the pump wearing an ordinary pump's coat was the hole in it.
--
-- Nothing had to move. rf-pump is a copy of vanilla's pump and Krastorio 2's steel pump is the same
-- one-by-two: collision box {{-0.29, -0.9}, {0.29, 0.9}} against vanilla's {{-0.29, -0.79}, {0.29,
-- 0.79}}, selection box {{-0.5, -1}, {0.5, 1}} in both. A sprite swap and only a sprite swap.
--
-- FOUR DIRECTIONS, TWO SHAPES. North and south are taller than they are wide and carry a pipe cover
-- above them; east and west are wider than tall and carry none. That is Krastorio 2's arrangement and
-- its per-direction dimensions, which differ from each other -- so this is written out per direction
-- rather than sliced from one sheet the way heater-pictures.lua does.
--
-- ponytail: the pipe COVERS stay vanilla's. Krastorio 2 layers its own steel cover here, and that set
-- is not vendored -- rf-pipe does not take it either, so vanilla covers are already what a plasma line
-- shows at its open ends. Taking them for the pump alone would make the pump disagree with the pipe it
-- sits in. Vendor steel-pipe-covers/ and change both together, or leave both.
--
-- ponytail: the fluid animation and the wagon connector stay vanilla's. Both are recoloured at
-- runtime by the fluid rather than drawn per building, and Krastorio 2 keeps vanilla's for the same
-- reason.

local DIRECTORY = "__realistic-fusion-refreshed__/graphics/krastorio-2/buildings/pump/"

-- Krastorio 2's shifts are util.by_pixel(...); written out as tiles because util is a __base__
-- internal this file does not depend on. by_pixel divides by 32, so by_pixel(8, 3.5) is
-- {0.25, 0.109375}.
--
-- NOTE THAT KRASTORIO 2'S OWN INLINE COMMENTS DISAGREE with that arithmetic -- it writes
-- "-- {0.515625, 0.21875}" beside by_pixel(8, 3.5), which is exactly double, and the same doubling
-- beside the south shift. Those comments are stale, left over from before a scale change; the CALL
-- is what the game evaluates, and the call is what is written out here.
local BODY = {
  north = { width = 103, height = 164, shift = {  0.25,    0.109375 } },
  east  = { width = 130, height = 109, shift = { -0.015625, 0.0546875 } },
  south = { width = 114, height = 160, shift = {  0.390625, -0.25 } },
  west  = { width = 131, height = 111, shift = { -0.0078125, 0.0390625 } },
}

-- The cover a north- or south-facing pump draws above itself, and its shadow. Vanilla's, for the
-- reason in the ponytail note above. repeat_count matches the body's frame_count so the still cover
-- lasts as long as the animated body.
local FRAMES = 32

local function cover_layers()
  return {
    {
      filename = "__base__/graphics/entity/pipe-covers/pipe-cover-north.png",
      priority = "extra-high",
      width = 128,
      height = 128,
      scale = 0.5,
      shift = { 0, -1.5 },
      repeat_count = FRAMES,
      animation_speed = 0.5,
    },
    {
      filename = "__base__/graphics/entity/pipe-covers/pipe-cover-north-shadow.png",
      priority = "extra-high",
      width = 128,
      height = 128,
      scale = 0.5,
      draw_as_shadow = true,
      shift = { 0, -1.5 },
      repeat_count = FRAMES,
    },
  }
end

-- animated is false for north and south: Krastorio 2 puts animation_speed on their COVER layer and
-- not on their body, where east and west carry it on the body itself. Kept as it does it rather than
-- regularised, because a layer's speed is a layer's own and guessing at a tidier arrangement is the
-- kind of change this directory exists to avoid making silently.
local function body(direction, animated)
  local b = BODY[direction]
  return {
    filename = DIRECTORY .. "pump-" .. direction .. ".png",
    width = b.width,
    height = b.height,
    scale = 0.5,
    line_length = 8,
    frame_count = FRAMES,
    animation_speed = animated and 0.5 or nil,
    shift = b.shift,
  }
end

local function covered(direction)
  local layers = cover_layers()
  layers[#layers + 1] = body(direction, false)
  return { layers = layers }
end

local M = {}

M.animations = {
  north = covered("north"),
  east  = body("east", true),
  south = covered("south"),
  west  = body("west", true),
}

return M

-- The aneutronic composite tank's in-world graphics, derived from Krastorio 2 and licensed LGPLv3.
--
-- THIS FILE IS NOT COVERED BY THE REPOSITORY'S LICENCE, for the same reason as reactor-pictures.lua
-- beside it: every dimension below is read off Krastorio 2's prototypes/buildings/big-storage-tank.lua,
-- which is LGPLv3, so this is a derivative of it and belongs where the LICENSE beside it applies.
--
-- THIS CLOSES A MISMATCH RATHER THAN CHOOSING ANYTHING (#45). The tank has carried Krastorio 2's
-- big storage tank ICON since the icons landed, over vanilla's storage tank in-world -- so the thing
-- in the hand and the thing on the ground were different buildings. The building here is the one the
-- icon was already taken from.
--
-- Nothing had to move to make it fit. rf-aneutronic-composite-tank is a copy of vanilla's storage
-- tank and Krastorio 2's big storage tank is the same three tiles square: collision box
-- {{-1.25, -1.25}, {1.25, 1.25}} against vanilla's {{-1.3, -1.3}, {1.3, 1.3}}, selection box
-- {{-1.5, -1.5}, {1.5, 1.5}} in both, and the same four corner pipe connections. A sprite swap and
-- only a sprite swap: no footprint change, no pipe moves, nothing to migrate. That is why this one
-- did not need the footprint-follows-art decision ADR 0013 records for the reactor.
--
-- ponytail: the fluid window, its background, the flow animation and the gas sprite stay pointing at
-- __base__. Krastorio 2 leaves them there too -- it draws the same vanilla window over its own shell
-- -- so this is its arrangement kept rather than a gap. window_bounding_box below is Krastorio 2's,
-- because the window has to land on ITS shell rather than on vanilla's.

local DIRECTORY = "__realistic-fusion-refreshed__/graphics/krastorio-2/buildings/composite-tank/"

local M = {}

-- One picture for all four directions: a storage tank is rotationally symmetric and Krastorio 2
-- draws it from one angle, the same as vanilla does.
-- sheets with frames = 1, which is how Krastorio 2 writes it. layers would render the same for two
-- single-frame sprites, but this directory's rule is that nothing here guesses at a form upstream
-- did not use.
M.picture = {
  sheets = {
    {
      filename = DIRECTORY .. "composite-tank.png",
      priority = "extra-high",
      frames = 1,
      scale = 0.5,
      width = 256,
      height = 256,
    },
    {
      filename = DIRECTORY .. "composite-tank-shadow.png",
      priority = "extra-high",
      frames = 1,
      scale = 0.5,
      width = 256,
      height = 256,
      -- Krastorio 2's own offset, which is what makes the shadow sit under this shell rather than
      -- under vanilla's.
      shift = { 0.152, 0 },
      draw_as_shadow = true,
    },
  },
}

-- Where the fluid window sits on Krastorio 2's shell. Read off its prototype, not vanilla's.
M.window_bounding_box = { { -0.125, 0.6875 }, { 0.1875, 1.1875 } }

-- Krastorio 2's shift here is util.by_pixel(0, 40), written out as tiles because util is a __base__
-- internal and this file does not depend on one. 40 / 32 = 1.25.
M.water_reflection = {
  pictures = {
    filename = DIRECTORY .. "composite-tank-reflection.png",
    priority = "extra-high",
    width = 40,
    height = 35,
    shift = { 0, 1.25 },
    variation_count = 1,
    scale = 5,
  },
  rotate = false,
  orientation_to_variation = false,
}

return M

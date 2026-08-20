-- The brine concentrator's in-world graphics, derived from Krastorio 2 and licensed LGPLv3.
--
-- A derivative of Krastorio 2's prototypes/buildings/filtration-plant.lua -- every width, height,
-- frame count, line length, shift and scale is read off it. It stays here beside the LICENSE and the
-- NOTICE because that is what records where it came from, even now that the repository is LGPLv3
-- as well.
--
-- Concentrating brine out of water is filtration by another name, which is why this is the building
-- whose icon the machine already wore. It grows from 3x3 to 7x7 to carry it.
--
-- ponytail: Krastorio 2's dirty-water and clear-water masks are not taken. They are recipe-tinted
-- overlays for showing what is going through the filter, and choosing those two colours is a
-- decision about how the chain reads rather than part of putting the building on the ground. The
-- machinery still turns without them.

local DIRECTORY = "__realistic-fusion-refreshed-core__/graphics/krastorio-2/buildings/brine-concentrator/"

return {
  animation = {
    layers = {
      {
        filename = DIRECTORY .. "brine-concentrator.png",
        priority = "high",
        width = 460,
        height = 520,
        shift = { 0, -0.2 },
        frame_count = 1,
        scale = 0.5,
      },
      {
        filename = DIRECTORY .. "brine-concentrator-shadow.png",
        priority = "high",
        width = 498,
        height = 438,
        shift = { 0.33, 0.32 },
        frame_count = 1,
        scale = 0.5,
        draw_as_shadow = true,
      },
    },
  },
  working_visualisations = {
    {
      animation = {
        filename = DIRECTORY .. "brine-concentrator-working.png",
        priority = "high",
        width = 340,
        height = 370,
        shift = { 0.3, -0.59 },
        frame_count = 30,
        line_length = 6,
        animation_speed = 0.6,
        scale = 0.5,
      },
    },
  },
}

-- The electrolyser's in-world graphics, derived from Krastorio 2 and licensed LGPLv3.
--
-- THIS FILE IS NOT COVERED BY THE REPOSITORY'S LICENCE in the sense that matters: it is a derivative
-- of Krastorio 2's prototypes/buildings/electrolysis-plant.lua, and every width, height, frame count,
-- line length, shift and scale below is read off it. The repository is LGPLv3 too now, so the two
-- agree -- but this file stays here beside the LICENSE and the NOTICE because that is what records
-- where it came from and travels with the directory if anyone lifts it.
--
-- Unlike the heater and the deuterium extractor, this one is not a free swap: the machine grows from
-- 3x3 to 5x5, which is what Krastorio 2's electrolysis plant is. See the note in prototypes/.
--
-- ponytail: the work layers are taken with apply_recipe_tint, the way Krastorio 2 uses them, which
-- means a recipe with no crafting_machine_tint glows in whatever the default is rather than in the
-- fluid's colour. Left that way deliberately -- picking a colour per recipe is a design decision
-- about how the chain reads, not part of putting the right building on the ground.

local DIRECTORY = "__realistic-fusion-refreshed-core__/graphics/krastorio-2/buildings/electrolyser/"

local function still(file, extra)
  local layer = {
    filename = DIRECTORY .. file,
    width = 380,
    height = 380,
    scale = 0.5,
    frame_count = 1,
    shift = { 0, 0 },
  }
  for key, value in pairs(extra or {}) do layer[key] = value end
  return layer
end

local function working(file, extra)
  local layer = {
    filename = DIRECTORY .. file,
    width = 380,
    height = 380,
    scale = 0.5,
    frame_count = 12,
    line_length = 6,
    animation_speed = 0.4,
    shift = { 0, 0 },
  }
  for key, value in pairs(extra or {}) do layer[key] = value end
  return layer
end

return {
  animation = {
    layers = {
      still("electrolyser.png"),
      still("electrolyser-shadow.png", { draw_as_shadow = true }),
    },
  },
  working_visualisations = {
    {
      apply_recipe_tint = "primary",
      animation = working("electrolyser-work.png", { blend_mode = "additive", draw_as_glow = true }),
    },
    {
      apply_recipe_tint = "primary",
      animation = working("electrolyser-work-light.png", { draw_as_light = true }),
    },
  },
}

-- The gas mixer's in-world graphics, derived from Krastorio 2 and licensed LGPLv3.
--
-- A derivative of Krastorio 2's prototypes/buildings/advanced-chemical-plant.lua -- every width,
-- height, frame count, line length, shift and scale below is read off it, from the mod repository
-- at https://codeberg.org/raiguard/Krastorio2 rather than measured off the sprite sheets. The two
-- shifts are the reason that matters: neither {0, -0.48} nor {0.33, 0.32} is recoverable from a
-- PNG, and a building placed by eye sits a fraction of a tile out from its own collision box.
--
-- It stays here beside the LICENSE and the NOTICE because that is what records where it came from,
-- even now that the repository is LGPLv3 as well.
--
-- Blending two gases is chemistry, which is why this is the building the mixer's icon already
-- wore. The machine grows from 3x3 to 7x7 to carry it, taking Krastorio 2's own boxes and its own
-- pipe positions (ADR 0013).
--
-- ponytail: the still layer and the shadow are repeat_count rather than frame_count, which is
-- Krastorio 2's own arrangement -- one unchanging image held across the twenty frames the
-- machinery animates over. The water reflection is NOT taken, matching every other building here.

local DIRECTORY = "__realistic-fusion-refreshed-core__/graphics/krastorio-2/buildings/gas-mixer/"

local FRAMES = 20
local SPEED = 0.25

return {
  animation = {
    layers = {
      {
        filename = DIRECTORY .. "gas-mixer.png",
        priority = "high",
        width = 451,
        height = 535,
        shift = { 0, -0.48 },
        repeat_count = FRAMES,
        animation_speed = SPEED,
        scale = 0.5,
      },
      {
        filename = DIRECTORY .. "gas-mixer-anim.png",
        priority = "high",
        width = 451,
        height = 535,
        shift = { 0, -0.48 },
        frame_count = FRAMES,
        line_length = 5,
        animation_speed = SPEED,
        scale = 0.5,
      },
      {
        filename = DIRECTORY .. "gas-mixer-shadow.png",
        priority = "high",
        width = 516,
        height = 458,
        shift = { 0.33, 0.32 },
        frame_count = 1,
        repeat_count = FRAMES,
        animation_speed = SPEED,
        scale = 0.5,
        draw_as_shadow = true,
      },
    },
  },
}

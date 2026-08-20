-- The lithium extractor's in-world graphics, derived from Krastorio 2 and licensed LGPLv3.
--
-- A derivative of Krastorio 2's prototypes/buildings/crusher.lua -- every width, height, frame count,
-- line length and scale is read off it. It stays here beside the LICENSE and the NOTICE because that
-- is what records where it came from, even now that the repository is LGPLv3 as well.
--
-- The crusher is the building whose icon this machine already wore, and it grows from 3x3 to 7x7 to
-- carry it. Krastorio 2's crusher has no fluid boxes at all -- it crushes ore -- so unlike the other
-- machines here the pipe positions are this repository's own, not read off anything; see the note in
-- prototypes/entities.lua.
--
-- The whole building is one thirty-frame animation rather than a still with a working overlay, so
-- this machine turns while it crafts without anything further being taken.

local DIRECTORY = "__realistic-fusion-refreshed-core__/graphics/krastorio-2/buildings/lithium-extractor/"

local FRAMES = 30

return {
  animation = {
    layers = {
      {
        filename = DIRECTORY .. "lithium-extractor.png",
        priority = "high",
        width = 512,
        height = 512,
        frame_count = FRAMES,
        line_length = 6,
        animation_speed = 0.75,
        scale = 0.5,
      },
      {
        filename = DIRECTORY .. "lithium-extractor-shadow.png",
        priority = "high",
        width = 512,
        height = 512,
        repeat_count = FRAMES,
        draw_as_shadow = true,
        scale = 0.5,
      },
    },
  },
}

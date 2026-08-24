-- The deuterium extractor's in-world graphics, derived from Krastorio 2 and licensed LGPLv3.
--
-- THIS FILE IS NOT COVERED BY THE REPOSITORY'S LICENCE. Every dimension below is read off
-- Krastorio 2's prototypes/buildings/atmospheric-condenser.lua, which is LGPLv3 like its assets, so
-- this is a derivative of it and belongs where the LICENSE beside it applies -- not in prototypes/,
-- which the repository's own LICENSE governs. See legal-note.txt.
--
-- A sprite swap and nothing more. rf-deuterium-extractor is a copy of vanilla's oil refinery and is
-- already five tiles square, which is exactly what Krastorio 2's atmospheric condenser is, so
-- neither box nor any of the five pipe connections moves. Nothing to migrate.
--
-- The condenser is drawn from one angle and has no per-direction sheet, so unlike the heater there
-- is nothing to slice: rotating the machine moves its pipes and leaves the building alone.
--
-- ponytail: the water reflection is not taken. It is worth nothing to a machine nobody will place
-- on a shoreline, and taking it would mean another file in here to account for.

local DIRECTORY = "__realistic-fusion-refreshed-assets__/graphics/krastorio-2/buildings/deuterium-extractor/"

-- Five, because that is the frame count of the condenser's own animation. The still and the shadow
-- repeat to match it: an Animation's layers must agree on how many frames they have.
local FRAMES = 5

return {
  animation = {
    layers = {
      {
        filename = DIRECTORY .. "deuterium-extractor.png",
        width = 380,
        height = 380,
        scale = 0.5,
        shift = { 0, 0 },
        repeat_count = FRAMES,
      },
      {
        filename = DIRECTORY .. "deuterium-extractor-anim.png",
        width = 380,
        height = 380,
        scale = 0.5,
        shift = { 0, 0 },
        frame_count = FRAMES,
        line_length = FRAMES,
      },
      {
        filename = DIRECTORY .. "deuterium-extractor-shadow.png",
        width = 380,
        height = 380,
        scale = 0.5,
        shift = { 0, 0 },
        repeat_count = FRAMES,
        draw_as_shadow = true,
      },
    },
  },
}

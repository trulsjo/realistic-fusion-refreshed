-- The confinement ladder (#53): three technologies that make the D-D tier pay for itself.
--
-- ADR 0014 fixes what a fusion technology in this mod is allowed to do -- move a physical
-- parameter, never add megawatts -- and ADR 0005 makes the reaction rate a reading off
-- cross-section data rather than a number anyone picked, so there is nowhere for a flat power
-- bonus to live even if it were wanted. Confinement time is the lever, and raising it is what
-- fusion research actually is. The rungs, the arithmetic and why the line stops at three live on
-- M.reactor.confinement_ladder in scripts/reactor-logic.lua; this file is the prototypes.
--
-- THE FIGURES COME FROM THAT TABLE RATHER THAN FROM THE LOCALE, the same way rf-d-d-fusion's
-- "draws __1__ MW" comes from heating_power_w (#46). A rung and its tooltip cannot disagree
-- because there is only one place the seconds are written down.
--
-- WHAT THE DESCRIPTIONS DO NOT DO is quote a Q. Settling the model to four figures costs about
-- 40 ms per rung, which is not a price worth paying at every game start for a tooltip, and a
-- number copied into the locale by hand is exactly the drift #51 was opened about. So the strings
-- state the seconds -- which is what the research moves -- and make their break-even claim in
-- words. tests/test-reactor-logic.lua pins the claim each string makes, so the two cannot part
-- company without something failing.
--
-- AND THEY NAME THEIR SUPPLY ASSUMPTION, which ADR 0016 makes mandatory rather than tidy: a player
-- chooses their own plasma density, and at the middle rung a full reactor misses break-even while
-- one held near 85% clears it. A description that quoted either without saying which would send
-- half its readers looking for a bug.
--
-- ALL THREE HANG OFF rf-d-d-fusion, so level 1 is available the moment a player has a reactor --
-- which is exactly when they are bleeding power and want a lever. Gating any of it behind
-- rf-d-t-fusion would withhold the line from the tier it exists for.
--
-- The icon is rf-d-d-fusion's, deliberately: this is that tier's line, there is no confinement art
-- in the assets mod (ADR 0023), and inventing a placeholder is a separate job from this one.
--
-- Costs are provisional like every other balance number here. 400/800/1600 against the neutronic
-- branch's 300 to 1500, on the same three science packs, with the top rung dearest because it is
-- the largest single upgrade the tier gets.
local logic = require("scripts.reactor-logic")

local LADDER = logic.reactor.confinement_ladder

local COUNTS = { 400, 800, 1600 }
local TIMES  = { 45, 60, 60 }

-- Refuses to build rather than silently shipping a rung with no cost, which is what indexing past
-- the end of COUNTS would do: `unit.count = nil` is a data-stage error a long way from its cause,
-- and a ladder grown by one in reactor-logic is exactly how it would happen.
if #LADDER ~= #COUNTS or #LADDER ~= #TIMES then
  error(string.format(
    "prototypes/technology/confinement.lua: the ladder in scripts/reactor-logic.lua has %d rungs " ..
    "but this file has %d counts and %d times. Add both for the new rung.",
    #LADDER, #COUNTS, #TIMES))
end

local technologies = {}

for level, rung in ipairs(LADDER) do
  local previous = (level == 1) and logic.reactor.confinement_time_s
    or LADDER[level - 1].confinement_time_s

  technologies[#technologies + 1] = {
    type = "technology",
    name = rung.technology,
    localised_description = {
      "technology-description." .. rung.technology,
      string.format("%d", previous),
      string.format("%d", rung.confinement_time_s),
    },
    icon = "__realistic-fusion-refreshed-assets__/graphics/krastorio-2/technologies/d-d.png",
    icon_size = 256,
    prerequisites = { (level == 1) and "rf-d-d-fusion" or LADDER[level - 1].technology },
    -- No effects. Nothing is unlocked and no engine modifier is set: control.lua reads whether the
    -- force has this technology and hands the reactor a different confinement time. A technology
    -- with an empty effects list is valid, and the description is what tells a player what it did.
    effects = {},
    unit = {
      count = COUNTS[level],
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack",   1 },
        { "chemical-science-pack",   1 },
      },
      time = TIMES[level],
    },
  }
end

data:extend(technologies)

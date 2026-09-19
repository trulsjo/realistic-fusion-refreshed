-- The plasma-heating ladder (#425): five technologies that shorten the D-D fuel chain by paying
-- for it in megawatts.
--
-- ADR 0038 places this line and settles what it is for. The complaint it answers is a plumbing
-- one -- 94.7 settled D-D reactors feed one saturated D-T reactor at entry, which is a farm nobody
-- finishes -- and heating power is the lever that brings the figure down, chosen by measurement
-- over the intuitive alternatives rather than by taste. M.reactor.heating_ladder in
-- scripts/reactor-logic.lua holds the rungs, the arithmetic and why there are five of them; this
-- file is the prototypes, the same split prototypes/technology/confinement.lua and
-- prototypes/technology/efficiency.lua work under and for the same reason: the figures a tooltip
-- quotes and the figures the simulation runs have exactly one place to be written down.
--
-- ADR 0014 still governs what a fusion technology here may do -- move a physical parameter, never
-- add megawatts -- and this line moves one in the direction that COSTS a player power rather than
-- granting it. Heating is what a real machine spends to hold a plasma; spending more of it is the
-- honest way to buy a hotter one.
--
-- WHAT THE DESCRIPTIONS QUOTE, AND THE HALF ADR 0038 MAKES MANDATORY. Each rung states the heating
-- power in megawatts, __1__ to __2__, from the ladder. Each also says THE REACTOR'S DRAW RISES,
-- with the figure, because a research that quietly increases consumption is the kind of thing a
-- player discovers as a blackout: a D-D line goes from about 56 MW to about 81 MW across these
-- five rungs, and ADR 0015 records that a brownout cools a D-D plasma with a climb back measured
-- in minutes. That sentence is the whole reason the line is a decision rather than a free ratchet.
--
-- WHAT THEY DO NOT QUOTE is a supply ratio or a Q. Settling the model to four figures costs about
-- 40 ms per rung, which is not a price worth paying at every game start for a tooltip, and a
-- number copied into the locale by hand is exactly the drift #51 was opened about. The strings
-- state the megawatts -- which is what the research moves -- and make their claim in words.
-- tests/test-reactor-logic.lua pins the claims they make.
--
-- ALL FIVE HANG OFF rf-d-d-fusion, INDEPENDENT OF THE CONFINEMENT LADDER. Neither line is a
-- prerequisite of the other (ADR 0038 decision 2) and that is deliberate: the heating rungs are at
-- their strongest at entry confinement, worth -24% to -15% of the supply ratio there against -21%
-- to -8% at the top of the other ladder, and a player should be able to spend them where they are
-- worth most. Folding the two into one line was measured and rejected for exactly that reason.
--
-- The icon is rf-d-d-fusion's, which is what prototypes/technology/confinement.lua also reuses.
-- Three lines off one technology now share two pictures between them, which is not ideal and is
-- not this ticket's job: there is no heating art in the assets mod (ADR 0023) and inventing a
-- placeholder is a separate piece of work. ADR 0038 raises tech-tree legibility as its own item.
--
-- Costs are provisional like every other balance number here. 400 to 2000 across five rungs, on
-- the same three science packs the two ladders beside it use, priced alike because ADR 0038 means
-- these lines to be alternatives a player chooses between.
local logic = require("scripts.reactor-logic")

local LADDER = logic.reactor.heating_ladder

local COUNTS = { 400, 700, 1100, 1500, 2000 }
local TIMES  = { 45, 45, 60, 60, 60 }

-- Refuses to build rather than silently shipping a rung with no cost, which is what indexing past
-- the end of COUNTS would do: `unit.count = nil` is a data-stage error a long way from its cause,
-- and a ladder grown by one in reactor-logic is exactly how it would happen. Same guard, same
-- wording, as the two files beside it.
if #LADDER ~= #COUNTS or #LADDER ~= #TIMES then
  error(string.format(
    "prototypes/technology/heating.lua: the heating ladder in scripts/reactor-logic.lua has %d " ..
    "rungs but this file has %d counts and %d times. Add both for the new rung -- and read " ..
    "ADR 0038's table first, because a sixth rung is a balance decision and not a copy.",
    #LADDER, #COUNTS, #TIMES))
end

local technologies = {}

for level, rung in ipairs(LADDER) do
  local previous = (level == 1) and logic.reactor.heating_power_w
    or LADDER[level - 1].heating_power_w

  technologies[#technologies + 1] = {
    type = "technology",
    name = rung.technology,
    -- Megawatts formatted here rather than written into the locale, so a rung and its tooltip
    -- cannot disagree -- the same thing rf-d-d-fusion does with heating_power_w (#46).
    localised_description = {
      "technology-description." .. rung.technology,
      string.format("%d", previous / 1e6),
      string.format("%d", rung.heating_power_w / 1e6),
    },
    icon = "__realistic-fusion-refreshed-assets__/graphics/krastorio-2/technologies/d-d.png",
    icon_size = 256,
    prerequisites = { (level == 1) and "rf-d-d-fusion" or LADDER[level - 1].technology },
    -- No effects, for the reason the two ladders beside it have none: nothing is unlocked and no
    -- engine modifier is set. control.lua reads whether the force has the technology and hands the
    -- reactor a different heating power; the description is what tells a player what it did.
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

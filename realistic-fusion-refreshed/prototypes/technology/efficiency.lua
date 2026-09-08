-- The plant-efficiency line (#96): three technologies that let a player recover more of what
-- leaves a reactor's plasma, without ever recovering all of it.
--
-- ADR 0020 places this line and settles the one thing that made it look forbidden. Any technology
-- that raises capture_efficiency is a technology walking toward 1.0, and at 1.0 a reactor that
-- never fuses sells back exactly the heating it was given and pays for itself for ever -- Factorio's
-- steam turbines lose nothing, so there is no other term standing in the way. The answer is an
-- ASYMPTOTE: each rung halves the remaining gap to a ceiling of 0.95, and halving a gap never
-- closes it, so the guard holds structurally rather than by a clamp anyone has to maintain.
--
-- THE RUNGS AND THE CEILING LIVE ON M.reactor IN scripts/reactor-logic.lua, and this file is the
-- prototypes -- the same split prototypes/technology/confinement.lua works under, for the same
-- reason: the figures a tooltip quotes and the figures the simulation runs have exactly one place
-- to be written down. control.lua's check_plant_efficiency refuses to load a rung at or above the
-- ceiling, so the structural property is enforced rather than merely intended.
--
-- WHAT THE DESCRIPTIONS QUOTE is the efficiency itself, as a percentage, because that is what the
-- research moves and it is a number a player can act on -- more energy sold from the same fuel. It
-- is NOT a megawatt figure, and could not be: what a reactor sells depends on its plasma, and the
-- same rung is worth a different number of megawatts at every temperature and every density.
--
-- NEUTRONIC ONLY, which is decision 4 and is deliberate rather than an omission.
-- rf-aneutronic-reactor stays at 0.95 and gets no line. Applying it there would spend the tightest
-- margin in the design -- 190 MW back for 200 MW spent -- and would preserve a ten-point efficiency
-- gap that CONTEXT.md's entry on direct energy conversion denies exists. With the steam route
-- climbing to 0.9375 the gap closes to 1.25 points, and the only remaining benefit of the
-- aneutronic tier is the one that entry names: the whole steam stage disappears. (ADR 0020 says
-- "under a point" there, which is out by a quarter: 0.95 - 0.9375 is 0.0125, and it is that ADR's
-- own ten-point gap read in the same units. Corrected in place there, 2026-09-09.)
--
-- ALL THREE HANG OFF rf-d-d-fusion, so level 1 is available the moment a player has a reactor --
-- which is exactly when they are bleeding power and want a lever. Gating any of it behind
-- rf-d-t-fusion would withhold the line from the tier it helps most, and giving the top rung
-- production science would push a neutronic-only upgrade past the aneutronic gate, which reads
-- backwards.
--
-- Costs are provisional like every other balance number here. 400/800/1600 on logistic and chemical
-- science, in family with the neutronic branch's 300 to 1500 and with the confinement ladder beside
-- it -- these two lines are meant to be alternatives a player chooses between, so they are priced
-- alike.
--
-- The icon is its own rather than rf-d-d-fusion's, which is what the confinement ladder reuses:
-- both ladders hang off that technology, and one picture for three lines in one corner of the tree
-- would make them indistinguishable at a glance. See the assets mod's NOTICE.txt for what was
-- taken and what was rejected.
local logic = require("scripts.reactor-logic")

local LADDER = logic.reactor.capture_ladder

local COUNTS = { 400, 800, 1600 }
local TIMES  = { 45, 60, 60 }

-- Refuses to build rather than silently shipping a rung with no cost, which is what indexing past
-- the end of COUNTS would do: `unit.count = nil` is a data-stage error a long way from its cause,
-- and a ladder grown by one in reactor-logic is exactly how it would happen. Same guard, same
-- wording, as prototypes/technology/confinement.lua -- a fourth rung would be a decision (ADR 0020
-- caps the total prize at +11.8% by arithmetic), and this makes it one that cannot be taken by
-- accident.
if #LADDER ~= #COUNTS or #LADDER ~= #TIMES then
  error(string.format(
    "prototypes/technology/efficiency.lua: the plant-efficiency ladder in " ..
    "scripts/reactor-logic.lua has %d rungs but this file has %d counts and %d times. Add both " ..
    "for the new rung -- and read ADR 0020's arithmetic first.",
    #LADDER, #COUNTS, #TIMES))
end

local technologies = {}

for level, rung in ipairs(LADDER) do
  local previous = (level == 1) and logic.reactor.capture_efficiency
    or LADDER[level - 1].capture_efficiency

  technologies[#technologies + 1] = {
    type = "technology",
    name = rung.technology,
    -- Percentages formatted here rather than written into the locale, so a rung and its tooltip
    -- cannot disagree -- the same thing rf-d-d-fusion does with heating_power_w (#46).
    --
    -- %.4g RATHER THAN A FIXED NUMBER OF DECIMALS, because the four values need different numbers of
    -- them: 85 and 90 need none, 92.5 needs one and 93.75 needs two. Significant figures give each
    -- one exactly what it needs -- "85" rather than "85.00", and "93.75" rather than a "93.8" that
    -- rounds away an eighth of a point of the thing the technology is named for. Four is enough for
    -- every value the ceiling permits: nothing under 0.95 needs a fifth.
    localised_description = {
      "technology-description." .. rung.technology,
      string.format("%.4g", previous * 100),
      string.format("%.4g", rung.capture_efficiency * 100),
    },
    icon = "__realistic-fusion-refreshed-assets__/graphics/krastorio-2/technologies/plant-efficiency.png",
    icon_size = 256,
    prerequisites = { (level == 1) and "rf-d-d-fusion" or LADDER[level - 1].technology },
    -- No effects, for the reason the confinement ladder has none: nothing is unlocked and no engine
    -- modifier is set. control.lua reads whether the force has the technology and hands the reactor
    -- a different capture efficiency; the description is what tells a player what it did.
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

require("util") -- table.deepcopy

-- Core's two machines are built from vanilla ones rather than modelled from scratch.
--
-- ponytail: this ships no graphics, no sounds and no remnants of our own, so the art decision
-- ADR 0010 left open stays open, and the entities are fully working rather than invisible.
-- The base entity is chosen for its fluid box count, which is the part that actually matters:
--   chemical-plant  2 in / 2 out  -> electrolysis        (1 in, 1 out)
--   oil-refinery    2 in / 3 out  -> Girdler sulfide     (2 in, 3 out)
-- The enrichment step returns its catalyst, so it genuinely needs the third output.
local function from_vanilla(source_type, source_name, name, categories, mining_time)
  local e = table.deepcopy(data.raw[source_type][source_name])
  e.name = name
  e.minable = { mining_time = mining_time, result = name }
  e.crafting_categories = categories
  -- Vanilla's group would let a player fast-replace ours with the machine it was copied from.
  e.fast_replaceable_group = nil
  e.next_upgrade = nil
  return e
end

local electrolyser = from_vanilla("assembling-machine", "chemical-plant",
  "rf-electrolyser", { "rf-electrolysis" }, 0.2)

local extractor = from_vanilla("assembling-machine", "oil-refinery",
  "rf-deuterium-extractor", { "rf-enrichment" }, 0.2)

data:extend({ electrolyser, extractor })

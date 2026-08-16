require("util") -- table.deepcopy

local ENTITY = "__RealisticFusionCore__/graphics/krastorio-2/entities/"

-- Core's machines are built from vanilla ones rather than modelled from scratch.
--
-- Each one carries its Krastorio 2 building, and three of the four had to grow to do it (ADR 0013).
-- Krastorio 2 has exactly one 3x3 building and rf-heater has it, so leaving these at the chemical
-- plant's 3x3 would have meant four identical buildings on the map -- which is the problem having
-- distinct art is meant to solve. Truls's call, and he wanted the substantial sizes.
--
-- The base entity is chosen for its fluid box count, which is the part that actually matters:
--   chemical-plant  2 in / 2 out  -> electrolysis, concentration, lithium extraction
--   oil-refinery    2 in / 3 out  -> Girdler sulfide (2 in, 3 out)
-- The enrichment step returns its catalyst, so it genuinely needs the third output.
--
-- Every stat that affects balance is set explicitly rather than inherited. A deep copy taken in
-- data.lua picks up whatever another mod has already done to the source prototype, and mods
-- sorting before this one alphabetically -- Krastorio 2 among them, which ADR 0007 names as a
-- coexistence target -- would silently rewrite all four machines.
local function from_vanilla(source_name, name, categories, opts)
  local e = table.deepcopy(data.raw["assembling-machine"][source_name])
  e.name = name
  e.minable = { mining_time = 0.2, result = name }
  e.crafting_categories = categories
  e.crafting_speed = opts.crafting_speed
  e.energy_usage = opts.energy_usage
  e.module_slots = 3
  e.allowed_effects = { "consumption", "speed", "productivity", "pollution", "quality" }
  e.icons = { { icon = ENTITY .. opts.icon .. ".png", icon_size = 64 } }
  e.icon = nil
  -- LGPLv3, one file per machine, kept in the graphics directory the licence governs.
  e.graphics_set = require("graphics.krastorio-2.buildings." .. opts.pictures)

  -- A machine that grows has to say where its pipes went. Taken from the Krastorio 2 building where
  -- it has as many connections as this machine needs, and stated here where it does not -- see each
  -- call below. Left alone entirely when the size did not change.
  if opts.collision then
    -- Both half-extents are Krastorio 2's own for that building, not derived from the tile size:
    -- its 5x5 insets the collision box by 0.2 and its 7x7 by 0.25, and guessing a rule from two
    -- numbers is how a building ends up a fraction of a tile out from its own art.
    e.collision_box = { { -opts.collision, -opts.collision }, { opts.collision, opts.collision } }
    e.selection_box = { { -opts.selection, -opts.selection }, { opts.selection, opts.selection } }
    for index, box in ipairs(e.fluid_boxes) do
      local connection = opts.connections[index]
      box.pipe_connections = { {
        flow_direction = connection.flow,
        direction = defines.direction[connection.side],
        position = connection.at,
      } }
    end
  end

  -- Vanilla's group would let a player fast-replace ours with the machine it was copied from.
  e.fast_replaceable_group = nil
  e.next_upgrade = nil
  return e
end

-- The chemical plant's four boxes are two inputs then two outputs, and the refinery's five are two
-- inputs then three outputs. The lists below are in that order.
data:extend({
  -- 3x3 -> 5x5. Both pairs of connections are Krastorio 2's own: in on the west face, out on the
  -- east, which is what its electrolysis plant's art is drawn around.
  from_vanilla("chemical-plant", "rf-electrolyser", { "rf-electrolysis" }, {
    crafting_speed = 1, energy_usage = "200kW", icon = "electrolyser",
    pictures = "electrolyser-pictures",
    collision = 2.3, selection = 2.5,
    connections = {
      { flow = "input",  side = "west", at = { -2, -1 } },
      { flow = "input",  side = "west", at = { -2, 1 } },
      { flow = "output", side = "east", at = { 2, -1 } },
      { flow = "output", side = "east", at = { 2, 1 } },
    },
  }),

  -- Already 5x5, which is what Krastorio 2's atmospheric condenser is, so nothing moves.
  from_vanilla("oil-refinery", "rf-deuterium-extractor", { "rf-enrichment" }, {
    crafting_speed = 1, energy_usage = "400kW", icon = "deuterium-extractor",
    pictures = "deuterium-extractor-pictures",
  }),

  -- 3x3 -> 7x7. Krastorio 2's filtration plant carries one connection per face and this machine
  -- needs two, so the pairs straddle the middle of the face its single one sits on: in at the
  -- north, out at the south.
  from_vanilla("chemical-plant", "rf-brine-concentrator", { "rf-concentration" }, {
    crafting_speed = 1, energy_usage = "200kW", icon = "brine-concentrator",
    pictures = "brine-concentrator-pictures",
    collision = 3.25, selection = 3.5,
    connections = {
      { flow = "input",  side = "north", at = { -1, -3 } },
      { flow = "input",  side = "north", at = { 1, -3 } },
      { flow = "output", side = "south", at = { -1, 3 } },
      { flow = "output", side = "south", at = { 1, 3 } },
    },
  }),

  -- 3x3 -> 7x7. Krastorio 2's crusher has no fluid boxes at all -- it crushes ore -- so these four
  -- positions are ours, matched to the concentrator above so the two 7x7 machines plumb alike.
  from_vanilla("chemical-plant", "rf-lithium-extractor", { "rf-lithium-processing" }, {
    crafting_speed = 1, energy_usage = "300kW", icon = "lithium-extractor",
    pictures = "lithium-extractor-pictures",
    collision = 3.25, selection = 3.5,
    connections = {
      { flow = "input",  side = "north", at = { -1, -3 } },
      { flow = "input",  side = "north", at = { 1, -3 } },
      { flow = "output", side = "south", at = { -1, 3 } },
      { flow = "output", side = "south", at = { 1, 3 } },
    },
  }),
})

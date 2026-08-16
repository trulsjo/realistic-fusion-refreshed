require("util") -- table.deepcopy

-- What a reactor says about itself on the circuit network (#25, ADR 0010): two virtual signals and
-- the entity that carries them.
--
-- Loaded after prototypes/entities.lua because the combinator borrows rf-reactor's selection box.

local GRAPHICS = "__RealisticFusion__/graphics/krastorio-2/"

-- Two signals rather than a GUI. ADR 0010 chose that deliberately: GUI was 929 of the redesign's
-- ~1,736 runtime lines, and these carry the same two numbers through the engine's own idiom.
--
-- Icons are the fluids the numbers describe -- the plasma whose temperature this is, and the
-- energy the Q factor is a ratio of -- so nothing new is taken from Krastorio 2 for these. They
-- are still LGPLv3 and still live in graphics/krastorio-2/; see the NOTICE there.
data:extend({
  {
    type = "virtual-signal",
    name = "rf-signal-plasma-temperature",
    icon = GRAPHICS .. "fluids/d-d-plasma.png",
    icon_size = 64,
    subgroup = "virtual-signal",
    order = "rf-a[plasma-temperature]",
  },
  {
    type = "virtual-signal",
    name = "rf-signal-q-factor",
    icon = GRAPHICS .. "fluids/reactor-energy.png",
    icon_size = 64,
    subgroup = "virtual-signal",
    order = "rf-b[q-factor]",
  },
})

-- The entity that puts them on a wire.
--
-- A companion rather than the reactor itself, and not by preference: rf-reactor is a boiler,
-- because that is what gives it plasma in and energy out through separate pipes, and
-- BoilerPrototype has no circuit_connector and no circuit_wire_max_distance. Checked against the
-- 2.0.77 prototype documentation rather than remembered. So the reactor cannot carry a wire at
-- all, and something at its position has to.
local combinator = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
combinator.name = "rf-reactor-signals"

-- Invisible, weightless and immovable. It is not a thing the player owns; it is part of the
-- reactor that happens to need its own prototype.
combinator.minable = nil
combinator.sprites = nil
combinator.activity_led_sprites = nil
combinator.collision_mask = { layers = {} }
combinator.collision_box = { { 0, 0 }, { 0, 0 } }
combinator.flags = {
  "placeable-off-grid",   -- it sits at the reactor's centre, which is not on a tile boundary
  "not-on-map",
  "not-blueprintable",
  "not-deconstructable",
  "not-upgradable",
  "no-copy-paste",
  "hide-alt-info",
  "not-in-kill-statistics",
}

-- Selectable, with the reactor's own footprint and the lowest possible priority.
--
-- This is the one piece of this ticket decided by reasoning rather than measurement, so it is
-- worth stating plainly. A wire drag only offers entities that have a circuit connector, and the
-- reactor has none -- so during a drag this is the only candidate under the cursor and the wire
-- lands on it. An ordinary click is a different contest, one both entities are in, and
-- selection_priority is what settles it: 0 against the reactor's default 50 means the reactor
-- always wins and the player never opens a bare combinator by accident.
--
-- Borrowing the reactor's selection box rather than declaring one is what makes the whole
-- reactor the wire target, instead of a one-tile spot at its centre that the player has to find.
combinator.selectable_in_game = true
combinator.selection_priority = 0
combinator.selection_box = table.deepcopy(data.raw["boiler"]["rf-reactor"].selection_box)

-- No item places it and no recipe makes it; control.lua creates it with the reactor.
data:extend({ combinator })

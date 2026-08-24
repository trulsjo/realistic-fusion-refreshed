require("util") -- table.deepcopy

-- What a reactor says about itself on the circuit network (#25, ADR 0010): two virtual signals and
-- the entity that carries them.
--
-- Loaded after prototypes/entities.lua because each combinator borrows its reactor's selection box.

local GRAPHICS = "__realistic-fusion-refreshed-assets__/graphics/krastorio-2/"

-- Two signals rather than a GUI. ADR 0010 chose that deliberately: GUI was 929 of the redesign's
-- ~1,736 runtime lines, and these carry the same two numbers through the engine's own idiom.
--
-- The temperature signal wears the plasma's own icon, because that is what it is the temperature of.
--
-- The Q factor deliberately does NOT wear the reactor energy fluid's. It did, on the reasoning that
-- Q is a ratio of that energy, and Truls read the resulting signal as "reactor energy: 172" in game
-- -- which is exactly what the icon said, and it is neither reactor energy nor 172 of anything. A
-- ratio is not a fluid and must not look like one, so it takes a Krastorio 2 virtual-signal icon
-- instead: nothing in the game shows that bolt as a fluid in a pipe.
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
    icon = GRAPHICS .. "virtual-signals/q-factor.png",
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
--
-- ONE PER REACTOR, and that is #31's doing rather than symmetry for its own sake. The combinator
-- borrows its reactor's selection box so the whole building is the wire target, and the two
-- reactors are different sizes -- fifteen tiles against ten. A single prototype would give the
-- aneutronic reactor a selection area two and a half tiles larger than itself on every side, so a
-- wire would attach to it from outside the building and two of them side by side would have
-- overlapping, tied selection boxes with nothing to break the tie.
--
-- Named <reactor>-signals, which is the convention scripts/circuit-output.lua derives rather than
-- being told: a reactor's combinator is its own name plus the suffix, so a third reactor needs no
-- change there either.
local COMBINATOR_SUFFIX = "-signals"

local function signals_for(reactor_name)
  local combinator = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
  combinator.name = reactor_name .. COMBINATOR_SUFFIX

  -- Invisible, weightless and immovable. It is not a thing the player owns; it is part of the
  -- reactor that happens to need its own prototype.
  combinator.minable = nil
  -- Inherited from the vanilla combinator and meaningless here -- nothing can be fast-replaced with
  -- an entity that has no item -- but a stray group is the kind of thing that starts mattering the
  -- day this grows a collision box.
  combinator.fast_replaceable_group = nil
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
    "not-in-kill-statistics",
  }
  -- Deliberately NOT "hide-alt-info". Alt mode over a constant combinator draws the signals it is
  -- emitting, which here means the plasma temperature and Q float over every reactor on the map for
  -- free -- the readout a player is most likely to find without being told. Hiding it was the first
  -- version, on the reasoning that an internal entity should stay out of the way, and it suppressed
  -- the most useful half of this ticket.

  -- Selectable, with the reactor's own footprint and the lowest priority that actually is one.
  --
  -- A wire drag only offers entities that have a circuit connector, and the reactor has none -- so
  -- during a drag this is the only candidate under the cursor and the wire lands on it. An ordinary
  -- click is a different contest, one both entities are in, and selection_priority settles it.
  --
  -- 1, not 0. The 2.0.77 documentation is explicit that "the value 0 will be treated the same as
  -- nil", which would have left this at the default 50, tied with the reactor, and a click could
  -- have opened a bare combinator. Caught in review against the docs; the first version of this
  -- comment asserted the opposite.
  --
  -- Borrowing the reactor's selection box rather than declaring one is what makes the whole reactor
  -- the wire target, instead of a one-tile spot at its centre that the player has to find.
  combinator.selectable_in_game = true
  combinator.selection_priority = 1
  combinator.selection_box = table.deepcopy(data.raw["boiler"][reactor_name].selection_box)

  -- Reach measured from the wire's connection point, which is this entity's position -- the middle
  -- of the reactor. The vanilla combinator's 9 is short of the corner of a fifteen-tile one at 10.6
  -- tiles, so a player could wire a pole to the near edge and find the far edge out of range for no
  -- visible reason. Read off the reactor's own box rather than written down, which is what makes one
  -- expression right for both a fifteen-tile reactor and a ten-tile one.
  local half_diagonal = math.sqrt(
    combinator.selection_box[2][1] ^ 2 + combinator.selection_box[2][2] ^ 2)
  combinator.circuit_wire_max_distance = math.ceil(half_diagonal) + 9

  -- Out of Factoriopedia, since nothing can build it and reading about it would only raise a
  -- question the player cannot act on.
  combinator.hidden = true
  combinator.hidden_in_factoriopedia = true

  return combinator
end

-- No item places these and no recipe makes them; control.lua creates one with each reactor.
--
-- The list is repeated here rather than required from scripts/entity-management.lua, which owns it,
-- because that file installs runtime event handlers the moment it is loaded and this one runs at the
-- data stage. control.lua's check_reactor_companions refuses to load if a reactor entity-management
-- knows about has no combinator here, which is the seam that makes the repetition safe rather than a
-- second source of truth.
for _, reactor_name in ipairs({ "rf-reactor", "rf-aneutronic-reactor" }) do
  data:extend({ signals_for(reactor_name) })
end

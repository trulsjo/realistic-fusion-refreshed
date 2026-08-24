-- The aneutronic reactor's in-world graphics, derived from Krastorio 2 and licensed LGPLv3.
--
-- THIS FILE IS NOT COVERED BY THE REPOSITORY'S LICENCE, for the same reason reactor-pictures.lua
-- beside it is not: every width, height, frame count, line length, shift and scale below is read
-- off Krastorio 2's own prototypes/buildings/antimatter-reactor.lua, which is LGPLv3 like the
-- assets it names. That makes this a derivative of it, and the licence travels with this directory
-- rather than with the repository. Moving this file into prototypes/ would strip it; see
-- legal-note.txt.
--
-- WHY THE ANTIMATTER REACTOR AND NOT ANOTHER TINT OF THE FUSION ONE. rf-reactor already wears
-- Krastorio 2's fusion reactor, and ADR 0013 records what that art decided -- a fifteen-tile
-- building, because the sprite was drawn for one. A recoloured copy of it would put two reactors
-- on the map that a player cannot tell apart from across the factory, which is exactly the
-- complaint that separated rf-reactor from rf-heat-exchanger in the first place. Krastorio 2's
-- antimatter reactor is a different building at a different size -- ten tiles against fifteen --
-- so the two tiers read apart on the ground before anything is clicked.
--
-- NOT IN USE SINCE ADR 0022, and that sentence is why. rf-aneutronic-reactor is fifteen tiles square
-- now, following the original mod rather than this art, and these sheets are drawn for ten --
-- stretching them is the rescale ADR 0013 rejected. The machine wears a drawn mockup instead
-- (graphics/mockup/), which also means the argument above no longer does the work it describes:
-- what tells the two tiers apart is the drawing, not the footprint.
--
-- Kept because it is the best starting point anyone drawing the real thing will have, and because
-- deleting it would lose the provenance NOTICE.txt records. Its icon is still in use.
--
-- Nothing about antimatter is claimed by using it. It is the art of a reactor that is not the
-- fusion reactor, which is the whole of what was needed; this mod has no antimatter and the
-- locale never says the word.
--
-- THE SAME BOILER PROBLEM AS THE FIRST REACTOR, and the same answer. rf-aneutronic-reactor is a
-- boiler (ADR 0011 -- it is what gives plasma in and reactor energy out through separate pipes),
-- and a boiler's structure is an idle picture the engine does not play. That was measured for
-- rf-reactor and is not re-measured here; see reactor-pictures.lua for the photographs and what
-- both attempts looked like. So the core is a still here too, and scripts/reactor-animation.lua
-- draws the moving one over it while the reactor is fusing.
--
-- Krastorio 2 splits this building differently from its fusion reactor, and it is worth naming
-- because the field names below do not match the other file's: there, the body and the core are
-- separate sheets. Here the body IS the first frame of the animation sheet -- K2 draws
-- antimatter-reactor.png as a one-frame idle_animation with repeat_count, and overlays the moving
-- sheets on top for the working animation. So `BODY` below is a whole building rather than a
-- building with a hole in it, and the overlay adds motion rather than filling a gap.

local DIRECTORY = "__realistic-fusion-refreshed__/graphics/krastorio-2/buildings/aneutronic-reactor/"

-- Thirty, because that is the frame count of Krastorio 2's animation sheets. Anything still that
-- shares a layer stack with them repeats to match: an Animation's layers must agree on frame count.
local FRAMES = 30

-- The building at rest, and its shadow. K2 declares these with repeat_count rather than
-- frame_count -- one drawn frame held for the whole cycle.
local BODY = {
  filename = DIRECTORY .. "aneutronic-reactor.png",
  priority = "extra-high",
  width = 660,
  height = 706,
  shift = { 0, -0.5 },
  scale = 0.5,
}

local SHADOW = {
  filename = DIRECTORY .. "aneutronic-reactor-shadow.png",
  priority = "medium",
  width = 724,
  height = 630,
  shift = { 0.57, 0.27 },
  scale = 0.5,
  draw_as_shadow = true,
}

-- The two sheets that move, which share the body's geometry exactly.
local function moving(file, frames, extra)
  local layer = {
    filename = DIRECTORY .. file,
    priority = "high",
    width = 660,
    height = 706,
    shift = { 0, -0.5 },
    frame_count = frames,
    line_length = 6,
    animation_speed = 0.5,
    scale = 0.5,
  }
  for key, value in pairs(extra or {}) do layer[key] = value end
  return layer
end

local structure = {
  layers = {
    table.deepcopy(BODY),
    table.deepcopy(SHADOW),
  },
}

-- One set, four directions. The building is drawn from a single angle, so there is nothing to
-- rotate; what rotation moves is which side the pipes come out of.
local pictures = {}
for _, direction in ipairs({ "north", "east", "south", "west" }) do
  pictures[direction] = { structure = table.deepcopy(structure) }
end

local M = { pictures = pictures }

--- The moving core, as an animation prototype for scripts/reactor-animation.lua to draw.
--
-- Here rather than in prototypes/ so that all of the licensed geometry stays in one file, and named
-- by its caller so that prototype names stay together in the code that owns them.
--
-- The shadow is deliberately NOT repeated in this stack. It is already in `structure` above and
-- never moves, so drawing it again would double the shadow's opacity for exactly as long as the
-- reactor is running -- which is the sort of thing that reads as a rendering bug rather than as a
-- reactor.
function M.core_animation(name)
  return {
    type = "animation",
    name = name,
    layers = {
      moving("aneutronic-reactor-animation.png", FRAMES),
      moving("aneutronic-reactor-animation-glow.png", FRAMES,
        { draw_as_glow = true, blend_mode = "additive" }),
    },
  }
end

return M

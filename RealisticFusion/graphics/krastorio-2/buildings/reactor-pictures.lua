-- The fusion reactor's in-world graphics, derived from Krastorio 2 and licensed LGPLv3.
--
-- THIS FILE IS NOT COVERED BY THE REPOSITORY'S LICENCE. It lives inside graphics/krastorio-2/
-- because that is where the LICENSE beside it applies, and because it is a derivative of
-- Krastorio 2's own prototypes/buildings/fusion-reactor.lua -- which is LGPLv3, like the assets it
-- names. Every width, height, frame count, line length, shift and scale below is Krastorio 2's.
-- Moving this file out of this directory would strip the licence off it; see legal-note.txt.
--
-- WHAT WAS CHANGED, and it is not a small change:
--
-- Krastorio 2's fusion reactor is an assembling-machine, so its art is a graphics_set: one still
-- animation plus a list of working_visualisations the engine draws while it crafts. rf-reactor is a
-- boiler (ADR 0011 -- it is what gives plasma in and reactor energy out through separate pipes), and
-- a boiler has no graphics_set at all. It has pictures: one BoilerPictures per direction, each with
-- a structure, and optional fire and fire_glow.
--
-- A BOILER CANNOT ANIMATE, AND BOTH WAYS OF TRYING WERE MEASURED:
--
-- Its structure is an IDLE picture and the engine does not play it. Vanilla says so in its own
-- filenames -- boiler-N-idle.png, heatex-N-idle.png. The first version of this file stacked
-- Krastorio 2's twelve-frame core into structure with repeat_count on the stills, reasoning that
-- structure is an Animation and an Animation animates. It does not: photographing a running reactor
-- six times four ticks apart and differencing the images outside the game, the core moved by at
-- most 13 of 255 in any channel, which is ambient light and not a reactor. The placement ghost
-- animates, which is what made it look right in review and is what Truls caught in game.
--
-- fire and fire_glow are where vanilla's boiler keeps everything that moves, and they are not the
-- answer either: with the still core removed from structure the reactor photographed as a building
-- with a hole in the middle, while the engine reported its status as "working". Vanilla's heat
-- exchanger -- an electric-ish boiler like this one -- declares no fire at all. Those fields belong
-- to a burner's flame.
--
-- So the core is a still here, and scripts/reactor-animation.lua draws the moving one over it at
-- runtime, only while the reactor is actually fusing. The still is what an idle reactor shows, and
-- what stops the overlay leaving a hole when it is not there.
--
-- Two of Krastorio 2's layers are deliberately not taken. fusion-reactor-steam.png is a
-- working_visualisation with its own shift per plume and no boiler field to hang it on, and
-- fusion-reactor-reflection.png is a water_reflection, which is worth nothing to a building this
-- size that nobody will place on a shoreline.

local DIRECTORY = "__RealisticFusion__/graphics/krastorio-2/buildings/reactor/"

-- Twelve, because that is the frame count of Krastorio 2's core animation. Anything still that
-- shares a layer stack with it repeats to match: an Animation's layers must agree on frame count.
local FRAMES = 12

-- The building itself, and its shadow. One frame each, and they never move.
local BODY = {
  filename = DIRECTORY .. "reactor.png",
  priority = "extra-high",
  width = 1100,
  height = 1100,
  scale = 0.5,
  shift = { 1.01, 0 },
}

local SHADOW = {
  filename = DIRECTORY .. "reactor-shadow.png",
  priority = "medium",
  width = 1100,
  height = 1100,
  scale = 0.5,
  shift = { 1.01, 0 },
  draw_as_shadow = true,
}

-- The three sheets that share the core's geometry: the core itself, its glow, and its light.
local function core(file, frames, extra)
  local layer = {
    filename = DIRECTORY .. file,
    line_length = 6,
    width = 626,
    height = 688,
    frame_count = frames,
    animation_speed = 0.75,
    scale = 0.5,
    shift = { 2.18, -2.358 },
  }
  for key, value in pairs(extra or {}) do layer[key] = value end
  return layer
end

local structure = {
  layers = {
    table.deepcopy(BODY),
    table.deepcopy(SHADOW),
    -- Frame one of the core and of its glow, so an idle reactor is a whole building rather than one
    -- with a hole in the middle. The runtime overlay draws the same art in motion over this.
    core("reactor-animation.png", 1),
    core("reactor-animation-glow.png", 1, { draw_as_glow = true, blend_mode = "additive" }),
  },
}

-- One set, four directions. The building is round and Krastorio 2 draws it from a single angle, so
-- there is nothing to rotate; what rotation moves is which side the pipes come out of.
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
-- Returned beside the picture set rather than as a field of it: pictures goes straight onto the
-- prototype, and an unexpected key there is a load error rather than something ignored.
function M.core_animation(name)
  return {
    type = "animation",
    name = name,
    layers = {
      core("reactor-animation.png", FRAMES),
      core("reactor-animation-glow.png", FRAMES, { draw_as_glow = true, blend_mode = "additive" }),
      core("reactor-animation-light.png", FRAMES, { draw_as_light = true }),
      {
        filename = DIRECTORY .. "reactor-light.png",
        priority = "high",
        width = 1100,
        height = 1100,
        scale = 0.5,
        shift = { 1.01, 0 },
        repeat_count = FRAMES,
        draw_as_light = true,
        blend_mode = "additive-soft",
      },
    },
  }
end

return M

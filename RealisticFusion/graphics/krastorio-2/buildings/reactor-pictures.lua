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
-- Krastorio 2's fusion reactor is an assembling-machine, so its art is a graphics_set: one static
-- animation plus a list of working_visualisations that the engine draws while it crafts. rf-reactor
-- is a boiler (ADR 0011 -- it is what gives plasma in and reactor energy out through separate
-- pipes), and a boiler has no graphics_set at all. It has pictures: one BoilerPictures per
-- direction, each with a structure, and optional fire and fire_glow drawn while it burns.
--
-- So the set is flattened. Everything Krastorio 2 splits between animation and
-- working_visualisations is stacked into structure's layers, aligned to twelve frames with
-- repeat_count on the stills, and the same table is given to all four directions.
--
-- ponytail: the consequence is that the reactor always animates, where Krastorio 2's only animates
-- while it is working. The obvious fix is to move the glowing layers into fire and fire_glow, and it
-- is the wrong one: those are driven by the boiler's own burning state, and this boiler's
-- conversion is deliberately neutered down to 1 W so the simulation can own the physics. Tying the
-- one thing a player sees from across the map to a number chosen to be meaningless would be worse
-- than a reactor that hums when it is cold -- and what it is actually doing is on its status line
-- and its two signals, which are exact. Revisit if #43 or #44 stops it being a boiler.
--
-- Two of Krastorio 2's layers are deliberately not taken. fusion-reactor-steam.png is a
-- working_visualisation with its own shift per plume and no boiler field to hang it on, and
-- fusion-reactor-reflection.png is a water_reflection, which is worth nothing to a building this
-- size that nobody will place on a shoreline.

local DIRECTORY = "__RealisticFusion__/graphics/krastorio-2/buildings/reactor/"

-- Twelve, because that is the frame count of Krastorio 2's core animation. The stills repeat to
-- match it: an Animation's layers must agree on how many frames they have.
local FRAMES = 12

local structure = {
  layers = {
    {
      filename = DIRECTORY .. "reactor.png",
      priority = "extra-high",
      width = 1100,
      height = 1100,
      scale = 0.5,
      shift = { 1.01, 0 },
      repeat_count = FRAMES,
    },
    {
      filename = DIRECTORY .. "reactor-shadow.png",
      priority = "medium",
      width = 1100,
      height = 1100,
      scale = 0.5,
      shift = { 1.01, 0 },
      draw_as_shadow = true,
      repeat_count = FRAMES,
    },
    {
      filename = DIRECTORY .. "reactor-animation.png",
      line_length = 6,
      width = 626,
      height = 688,
      frame_count = FRAMES,
      animation_speed = 0.75,
      scale = 0.5,
      shift = { 2.18, -2.358 },
    },
    {
      filename = DIRECTORY .. "reactor-animation-glow.png",
      priority = "high",
      line_length = 6,
      width = 626,
      height = 688,
      frame_count = FRAMES,
      animation_speed = 0.75,
      scale = 0.5,
      shift = { 2.18, -2.358 },
      draw_as_glow = true,
      blend_mode = "additive",
    },
    {
      filename = DIRECTORY .. "reactor-animation-light.png",
      line_length = 6,
      width = 626,
      height = 688,
      frame_count = FRAMES,
      animation_speed = 0.75,
      scale = 0.5,
      shift = { 2.18, -2.358 },
      draw_as_light = true,
    },
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

-- One set, four directions. The building is round and Krastorio 2 draws it from a single angle, so
-- there is nothing to rotate; what rotation moves is which side the pipes come out of.
return {
  north = { structure = table.deepcopy(structure) },
  east  = { structure = table.deepcopy(structure) },
  south = { structure = table.deepcopy(structure) },
  west  = { structure = table.deepcopy(structure) },
}

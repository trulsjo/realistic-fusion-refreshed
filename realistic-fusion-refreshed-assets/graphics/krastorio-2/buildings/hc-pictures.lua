-- The high-capacity TURBINE's in-world graphics, derived from Krastorio 2 and licensed LGPLv3.
--
-- IT WAS THE PAIR'S UNTIL #276, and one half of the module is what is left. rf-hc-exchanger's sheets
-- are gone with its seven-tile footprint; the section at the foot of this file records where they
-- went and why. The file keeps its name because the prototype it serves keeps its own.
--
-- THIS FILE IS NOT COVERED BY THE REPOSITORY'S LICENCE, for the reason reactor-pictures.lua beside
-- it is not: every width, height, frame count, line length, shift and scale below is read off
-- Krastorio 2's own prototypes/buildings/advanced-steam-turbine.lua, so this is a derivative of it
-- and has to sit where the LICENSE beside it applies. Moving it into prototypes/ would strip the
-- licence; see legal-note.txt.
--
-- WHY REAL ART AND NOT A TINT (#32). The predecessor's high-capacity pair is its ordinary pair
-- deep-copied and tinted orange, which is the arrangement this repository has already rejected once:
-- rf-reactor and rf-heat-exchanger were the same sprite in two tints and could not be told apart on
-- the ground. A player laying out a steam farm has to see at a glance which turbines are the big
-- ones, because mixing them is the mistake that silently halves a build.
--
-- So the two turbines take different buildings at different sizes. Krastorio 2's advanced steam
-- turbine is literally what rf-hc-turbine is, at five by seven against the vanilla turbine's three
-- by five -- the size difference is the message.
--
-- THAT ARGUMENT NO LONGER COVERS THE EXCHANGERS, and #276 is where it stopped. The two exchangers
-- are now one machine at two scales, identical in footprint and plumbing, so art is the only thing
-- left to tell them apart -- and until this machine's model is rendered, the art is a labelled
-- mockup. entities.lua says so at rf-hc-exchanger's footprint, where the trade was made.

local DIRECTORY = "__realistic-fusion-refreshed-assets__/graphics/krastorio-2/buildings/"

local M = {}

-- ---------------------------------------------------------------- turbine

-- A generator takes one picture set with an animation per direction, and Krastorio 2 draws this
-- building from two angles rather than four: north and south share the vertical sheet, east and west
-- the horizontal one. That is its arrangement, kept.
local turbine_horizontal = {
  layers = {
    {
      filename = DIRECTORY .. "hc-turbine/hc-turbine-H.png",
      width = 469,
      height = 270,
      frame_count = 6,
      line_length = 2,
      shift = { 0, -0.2 },
      scale = 0.5,
    },
    {
      filename = DIRECTORY .. "hc-turbine/hc-turbine-shadow-H.png",
      width = 514,
      height = 225,
      frame_count = 6,
      line_length = 3,
      shift = { 0.575, 0.25 },
      scale = 0.5,
      draw_as_shadow = true,
    },
  },
}

local turbine_vertical = {
  layers = {
    {
      filename = DIRECTORY .. "hc-turbine/hc-turbine-V.png",
      width = 330,
      height = 500,
      frame_count = 6,
      line_length = 6,
      shift = { 0.26, 0 },
      scale = 0.5,
    },
    {
      filename = DIRECTORY .. "hc-turbine/hc-turbine-shadow-V.png",
      width = 350,
      height = 425,
      frame_count = 6,
      line_length = 6,
      shift = { 0.48, 0.36 },
      scale = 0.5,
      draw_as_shadow = true,
    },
  },
}

--- The turbine's two animations, in the fields vanilla's steam turbine declares them in.
--
-- Krastorio 2 puts the same two sheets in a `pictures` table keyed by direction; this returns them as
-- horizontal_animation and vertical_animation instead, because rf-hc-turbine is a deep copy of
-- VANILLA's steam turbine and those are the fields that copy carries. Setting the other shape would
-- mean leaving vanilla's fields populated beside it and trusting the engine to prefer the right one,
-- which is a guess where this is a fact.
--
-- THESE DO ANIMATE, unlike everything else this repository has taken from Krastorio 2, and the
-- difference is the prototype type rather than anything about the art. A generator's animations are
-- played by the engine while it runs; a boiler's structure is a still it does not play
-- (reactor-pictures.lua has the photographs). So the turbine spins, and it needs no runtime overlay
-- to do it.
M.turbine_horizontal = turbine_horizontal
M.turbine_vertical = turbine_vertical

-- ---------------------------------------------------------------- exchanger, and there is none
--
-- THE EXCHANGER'S SHEETS WERE HERE AND ARE GONE (#276). rf-hc-exchanger wore Krastorio 2's matter
-- plant -- matter-plant.png and matter-plant-sh.png, renamed only -- for as long as it was seven
-- tiles square. #276 gives it rf-heat-exchanger's fifteen-by-five footprint, and a sheet drawn for a
-- seven-tile square cannot be stretched over an oblong: ADR 0022 searched Krastorio 2's set
-- exhaustively and records that nothing in it sits at this shape. So the two PNGs are deleted rather
-- than distorted, their entry has left the NOTICE beside this directory, and the machine wears a
-- mockup from graphics/mockup/ until its own model is rendered.
--
-- matter-plant-working.png and its glow were never taken -- a boiler has nowhere to play a
-- thirty-frame working animation -- so nothing about that decision survives to be recorded here.
--
-- THE ICON IS UNAFFECTED. entities/hc-exchanger.png is still the matter plant's, and still in the
-- NOTICE: an icon is not drawn at a footprint, so a shape change reaches the building and not it.

return M

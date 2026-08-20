-- The high-capacity steam pair's in-world graphics, derived from Krastorio 2 and licensed LGPLv3.
--
-- THIS FILE IS NOT COVERED BY THE REPOSITORY'S LICENCE, for the reason reactor-pictures.lua beside
-- it is not: every width, height, frame count, line length, shift and scale below is read off
-- Krastorio 2's own prototypes/buildings/advanced-steam-turbine.lua and
-- prototypes/buildings/matter-plant.lua, so this is a derivative of both and has to sit where the
-- LICENSE beside it applies. Moving it into prototypes/ would strip the licence; see legal-note.txt.
--
-- WHY REAL ART AND NOT A TINT (#32). The predecessor's high-capacity pair is its ordinary pair
-- deep-copied and tinted orange, which is the arrangement this repository has already rejected once:
-- rf-reactor and rf-heat-exchanger were the same sprite in two tints and could not be told apart on
-- the ground. A player laying out a steam farm has to see at a glance which turbines are the big
-- ones, because mixing them is the mistake that silently halves a build.
--
-- So the two take different buildings at different sizes. Krastorio 2's advanced steam turbine is
-- literally what rf-hc-turbine is, and its matter plant is a seven-tile industrial vessel against
-- the three-by-two heat exchanger -- the size difference is the message.
--
-- Both files are shared by one module because the two prototypes are one tier and one ticket, and
-- because a reader comparing their geometry should not have to open two files to do it.

local DIRECTORY = "__realistic-fusion-refreshed__/graphics/krastorio-2/buildings/"

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
-- (reactor-pictures.lua has the photographs). So the turbine spins and the exchanger below does not,
-- and neither needs a runtime overlay.
M.turbine_horizontal = turbine_horizontal
M.turbine_vertical = turbine_vertical

-- ---------------------------------------------------------------- exchanger

local exchanger_structure = {
  layers = {
    {
      filename = DIRECTORY .. "hc-exchanger/hc-exchanger.png",
      priority = "extra-high",
      width = 462,
      height = 500,
      frame_count = 1,
      shift = { -0.1, -0.2 },
      scale = 0.5,
    },
    {
      filename = DIRECTORY .. "hc-exchanger/hc-exchanger-shadow.png",
      priority = "medium",
      width = 504,
      height = 444,
      frame_count = 1,
      shift = { 0.23, 0.24 },
      scale = 0.5,
      draw_as_shadow = true,
    },
  },
}

--- The exchanger's four directions.
--
-- One set repeated, because the building is drawn from a single angle and what rotation moves is
-- which side the pipes come out of -- the same arrangement rf-reactor uses.
--
-- Krastorio 2's matter-plant-working.png and its glow are NOT taken. They are a thirty-frame working
-- animation, and a boiler has nowhere to play one: `structure` is an idle picture the engine does not
-- animate, which was measured for rf-reactor rather than assumed here. Drawing them would need the
-- runtime overlay scripts/reactor-animation.lua does for reactors, and a heat exchanger that sits
-- still is not a defect -- vanilla's does too.
M.exchanger_pictures = {}
for _, direction in ipairs({ "north", "east", "south", "west" }) do
  M.exchanger_pictures[direction] = { structure = table.deepcopy(exchanger_structure) }
end

return M

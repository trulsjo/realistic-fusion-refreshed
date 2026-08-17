-- The moving core, drawn over the reactor while it is fusing.
--
-- WHY THIS IS A SCRIPT RENDERING AND NOT PART OF THE ENTITY
--
-- Because a boiler cannot animate, and both ways of making it were tried and measured.
--
-- Its `structure` is an idle picture the engine does not play: a running reactor photographed six
-- times four ticks apart moved by at most 13 of 255 in any channel, which is the ambient light and
-- not a reactor. And `fire` / `fire_glow`, where vanilla's boiler keeps everything that moves, are
-- never drawn here at all -- with the still core removed from `structure` the reactor photographed
-- as a building with a hole in the middle while the engine reported its status as "working".
-- Vanilla's own heat exchanger, which is the boiler this one is a copy of, declares no fire either.
-- Those fields belong to a burner's flame.
--
-- The placement ghost animates, because a ghost draws the prototype's animation generically. That
-- is what made the first version look right in review and is what Truls caught in game.
--
-- WHAT IT BUYS BACK
--
-- More than parity. Krastorio 2's reactor animates while it crafts, which for that mod means "is
-- consuming". This one animates while it is FUSING -- the same condition the status line and the
-- signals report -- so the building agrees with what it says about itself, and a reactor holding
-- cold plasma sits still.

local M = {}

-- A reactor's moving core is its own prototype name plus this (#31). Derived rather than listed,
-- for the same reason circuit-output derives its combinator name: the two reactors are different
-- buildings drawn from different Krastorio 2 art, so each declares its own animation in
-- prototypes/entities.lua, and a third reactor needs no change here.
--
-- control.lua's check_reactor_animations refuses to load if a reactor has no animation under this
-- name -- which is the failure this derivation makes possible and which would otherwise be an error
-- inside a running game the first time that reactor started fusing.
local ANIMATION_SUFFIX = "-core"

--- Show or hide one reactor's moving core.
--
-- @param entity   the reactor
-- @param running  whether it is fusing
--
-- Created and destroyed on the transition rather than kept and re-targeted, because there is no
-- cheaper handle: a rendering object cannot be hidden, only destroyed. Transitions are rare -- a
-- reactor that is fusing goes on fusing -- so this is a table lookup per report and nothing else.
function M.set(entity, running)
  storage.reactor_animations = storage.reactor_animations or {}
  local unit_number = entity.unit_number
  local drawn = storage.reactor_animations[unit_number]

  if running then
    if drawn and drawn.valid then return end
    storage.reactor_animations[unit_number] = rendering.draw_animation({
      animation = entity.name .. ANIMATION_SUFFIX,
      surface = entity.surface,
      target = entity,
      -- Above the building it covers. The animation carries Krastorio 2's own shift, so it lands on
      -- the core it replaces without anything being positioned here.
      render_layer = "higher-object-above",
    })
  elseif drawn then
    if drawn.valid then drawn.destroy() end
    storage.reactor_animations[unit_number] = nil
  end
end

--- Drop a reactor's animation when the reactor is gone.
--
-- Factorio destroys a rendering whose target entity is destroyed, so this is about the register
-- rather than the drawing: without it, storage grows a dead key per reactor ever built.
function M.forget(unit_number)
  local drawn = storage.reactor_animations and storage.reactor_animations[unit_number]
  if drawn and drawn.valid then drawn.destroy() end
  if storage.reactor_animations then storage.reactor_animations[unit_number] = nil end
end

--- Drop every animation, so the next report redraws the ones still wanted.
--
-- Unlike the signals combinator, throwing these away costs nothing a player can notice: a rendering
-- carries no state and nothing can be attached to it. So the cheap answer is the right one here
-- where it was the wrong one there -- see circuit-output.rescan().
function M.reset()
  for _, drawn in pairs(storage.reactor_animations or {}) do
    if drawn.valid then drawn.destroy() end
  end
  storage.reactor_animations = {}
end

return M

-- Which reactors exist, and every way one can come to exist.
--
-- Its own file per ADR 0010's layout for the Power module, and it earns the separation: this
-- changes when the game finds a new way to put an entity on a surface, which is not when the
-- simulation changes. control.lua owns the simulation and the cadence -- nothing here knows how
-- often a reactor steps (ADR 0005), and nothing here touches a fluid box.

local M = {}

local REACTOR = "rf-reactor"

--- The register: unit_number -> LuaEntity, in storage so it survives a save.
--
-- Handed out rather than walked here. The caller prunes as it goes, which is why forget() exists
-- below, and doing it during a walk the simulation already makes costs nothing where a second
-- pass would cost another walk.
--
-- The table is live and is this module's to own: read it, prune it through forget(), and do not
-- add to it -- register() is the only way in, because it is the only place that knows what
-- belongs here. Said out loud because circuit-output.lua (#25) will want to walk reactors too and
-- will be handed the same mutable table.
--
-- Deliberately a read, not a lazy initialiser: before the first register() there is nothing to
-- iterate, and answering with an empty throwaway leaves storage untouched rather than writing to
-- it ten times a second to say so.
function M.registry()
  return storage.reactors or {}
end

--- Drop a reactor that is no longer on the map.
--
-- There is deliberately no on_mined / on_died / on_destroyed handler to match the build events
-- below. See the call site in control.lua's update() for why.
--
-- The guard is not ceremony: registry() can hand back a throwaway, and a caller pruning what it
-- walked would then be niling a key on a table storage has never heard of.
function M.forget(unit_number)
  local reactors = storage.reactors
  if reactors then reactors[unit_number] = nil end
end

--- The only way into the register.
--
-- Local, not exported: every caller is in this file, and the seam control.lua uses is
-- registry / forget / rescan.
local function register(entity)
  if entity and entity.valid and entity.name == REACTOR then
    storage.reactors = storage.reactors or {}
    storage.reactors[entity.unit_number] = entity
  end
end

--- Rebuild the register from what is actually on the map.
--
-- Runs when the mod is added to a save and whenever the configuration changes, so a reactor is
-- never left unsimulated because an event was missed or an entity predates this code. control.lua
-- calls it, because it has to run alongside the prototype checks and those are its business.
function M.rescan()
  storage.reactors = {}
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered({ name = REACTOR })) do
      register(entity)
    end
  end
end

-- ---------------------------------------------------------------- how a reactor appears
--
-- Wired here rather than handed back to control.lua for it to install: the whole point of the
-- split is that a new way for an entity to appear is a change to this file alone.

local built_filter = { { filter = "name", name = REACTOR } }
for _, event in pairs({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  -- Defined only on a game that knows about platforms. Nothing guards it because nothing needs
  -- to: a nil here is simply a value the table constructor does not store, and pairs iterates
  -- what is there. ADR 0003 tolerates Space Age without targeting it, so it must not be assumed
  -- present -- and must be handled if it is.
  --
  -- pairs, not ipairs: ipairs stops at the hole and would silently drop every event after it.
  defines.events.on_space_platform_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
}) do
  script.on_event(event, function(e) register(e.entity) end, built_filter)
end

-- Cloning cannot ride that loop, for two reasons. It names its entity "destination" rather than
-- "entity", so the handler above would register nil; and it is the one way a reactor can appear
-- that raises neither a build event nor script_raised_built -- the map editor's clone tool, and
-- Space Age's platform cloning, which ADR 0003 says must work if present. Without this a cloned
-- reactor sits inert, accepting plasma and producing nothing, until some unrelated mod's version
-- bump triggers on_configuration_changed and the rescan picks it up.
--
-- Unfiltered on purpose: filter semantics on a two-entity event are not worth assuming when
-- register() already checks the name, and cloning is rare enough that the cost of looking is nil.
script.on_event(defines.events.on_entity_cloned, function(e) register(e.destination) end)

return M

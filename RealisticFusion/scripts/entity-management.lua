-- Which reactors exist, and every way one can come to exist.
--
-- Its own file per ADR 0010's layout for the Power module, and it earns the separation: this
-- changes when the game finds a new way to put an entity on a surface, which is not when the
-- simulation changes. control.lua owns the simulation and the cadence -- nothing here knows how
-- often a reactor steps (ADR 0005), and nothing here touches a fluid box.

local M = {}

local REACTOR = "rf-reactor"
local COLLECTOR = "rf-isotope-collector"

--- The reactor's prototype name, for the one other place that has to recognise one.
--
-- circuit-output.lua's selection redirect needs it and deliberately does not require this file --
-- doing so would install these build handlers from a test suite. control.lua hands it across, so
-- the name still has exactly one definition.
M.REACTOR = REACTOR

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
  -- The pairing goes with the reactor. Left behind it would be an entry keyed by a unit_number
  -- the game is free to hand to something else.
  local collectors = storage.collectors
  if collectors then collectors[unit_number] = nil end
end

-- ---------------------------------------------------------------- reactor -> collector
--
-- A reactor breeds tritium and helium-3 and has nowhere to put them, so a player bolts an
-- rf-isotope-collector to it (#27). Which collector belongs to which reactor is answered here,
-- because it is a question about what is on the map.
--
-- This is NOT the connectivity tracking ADR 0011 rules out. There is no graph, no traversal, no
-- merge and no split: one reactor has at most one collector, the pairing is a single lookup over
-- the tiles touching the reactor, and it is recomputed only when something is built or when the
-- paired collector goes away. The simulation never scans on a steady-state step, so a reactor
-- without a collector costs nothing per step rather than a search ten times a second.
--
-- Two properties of this that are chosen rather than fallen into:
--
-- A WHOLE TILE of margin, not a hair. Collision boxes are inset from the tile footprints they sit
-- in -- vanilla's boiler by about a fifth of a tile per side, the reactor by a quarter -- so two
-- entities a player has placed flush against each other still have nearly half a tile between
-- their boxes. A tight margin would fail to pair a correctly placed collector, which is the worse
-- failure by far. The cost is that a collector left one tile short, or touching only at a corner,
-- pairs as though it were flush.
--
-- MANY REACTORS MAY SHARE ONE COLLECTOR. Each reactor has at most one, but nothing stops two
-- reactors both pointing at a collector wedged between them, and deposit() then runs twice into
-- the same two boxes in one write pass. That is sound -- each call reads and writes in turn, so
-- nothing is lost -- and it is left available on purpose: sharing one collector between two
-- reactors is a real thing to build, and what it costs is that both reactors' output has to leave
-- through one collector's plumbing. It shows up as by-products backing up, which is the same way
-- every other throughput limit in this mod shows up.
local function touching(entity)
  local box = entity.bounding_box
  return {
    { box.left_top.x - 1, box.left_top.y - 1 },
    { box.right_bottom.x + 1, box.right_bottom.y + 1 },
  }
end

--- Point a reactor at the collector bolted to it, or at nothing.
--
-- Lowest unit_number wins when a reactor is flanked by two, so the answer does not depend on the
-- order find_entities_filtered happens to return them in -- which would otherwise be a desync
-- waiting for two players to build at once.
local function attach(reactor)
  if not (reactor and reactor.valid) then return end
  local best
  for _, found in pairs(reactor.surface.find_entities_filtered({
    area = touching(reactor), name = COLLECTOR,
  })) do
    if not best or found.unit_number < best.unit_number then best = found end
  end
  storage.collectors = storage.collectors or {}
  storage.collectors[reactor.unit_number] = best
end

--- The collector serving this reactor, or nil.
--
-- A collector that has stopped being valid -- mined, destroyed, blown up -- is looked up again
-- rather than merely forgotten, and that is not belt-and-braces. Nothing raises a build event when
-- an entity is removed, so a reactor flanked by two collectors that loses the one it was paired to
-- would otherwise breed into nothing for ever while the second sat against it doing nothing, until
-- some unrelated mod's version bump triggered a rescan.
--
-- The search happens on the one step the entity went invalid and never again: attach() writes back
-- whatever it finds, including nothing, and a nil entry returns above without looking.
function M.collector(reactor)
  local collectors = storage.collectors
  local found = collectors and collectors[reactor.unit_number]
  if not found then return nil end
  if found.valid then return found end
  attach(reactor)
  local repaired = collectors[reactor.unit_number]
  return repaired and repaired.valid and repaired or nil
end

--- The only way into the register.
--
-- Local, not exported: every caller is in this file, and the seam control.lua uses is
-- registry / forget / rescan.
local function register(entity)
  if not (entity and entity.valid) then return end
  if entity.name == REACTOR then
    storage.reactors = storage.reactors or {}
    storage.reactors[entity.unit_number] = entity
    attach(entity)
  elseif entity.name == COLLECTOR then
    -- Built the other way round: the collector arrives after the reactor it serves, which is the
    -- usual order a player does it in. Every reactor it touches re-pairs.
    for _, reactor in pairs(entity.surface.find_entities_filtered({
      area = touching(entity), name = REACTOR,
    })) do
      attach(reactor)
    end
  end
end

--- Rebuild the register from what is actually on the map.
--
-- Runs when the mod is added to a save and whenever the configuration changes, so a reactor is
-- never left unsimulated because an event was missed or an entity predates this code. control.lua
-- calls it, because it has to run alongside the prototype checks and those are its business.
function M.rescan()
  storage.reactors = {}
  storage.collectors = {}
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

-- Two names, and the collector is here for the pairing rather than for the register: register()
-- sends it to attach() the reactors it touches. Successive filter entries are OR'd -- `mode`
-- defaults to "or" -- so this is "either name", not "both", which nothing could ever be.
local built_filter = {
  { filter = "name", name = REACTOR },
  { filter = "name", name = COLLECTOR },
}
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

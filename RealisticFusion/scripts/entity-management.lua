-- Which reactors exist, and every way one can come to exist.
--
-- Its own file per ADR 0010's layout for the Power module, and it earns the separation: this
-- changes when the game finds a new way to put an entity on a surface, which is not when the
-- simulation changes. control.lua owns the simulation and the cadence -- nothing here knows how
-- often a reactor steps (ADR 0005), and nothing here touches a fluid box.

local M = {}

local REACTOR = "rf-reactor"
local COLLECTOR = "rf-isotope-collector"
local BLANKET = "rf-lithium-blanket"

-- The two fittings a reactor can have bolted to it, and the storage table each pairing lives in.
--
-- A list rather than two copies of everything below, because the pairing rule is identical for
-- both -- nearest by lowest unit_number, within a tile of the reactor's box -- and the way two
-- copies of a rule go wrong is that only one of them gets fixed. Adding a third fitting is a row
-- here.
local FITTINGS = {
  { name = COLLECTOR, key = "collectors" },
  { name = BLANKET,   key = "blankets" },
}

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
  -- Every pairing goes with the reactor. Left behind they would be entries keyed by a unit_number
  -- the game is free to hand to something else.
  for _, fitting in ipairs(FITTINGS) do
    local paired = storage[fitting.key]
    if paired then paired[unit_number] = nil end
  end
  -- The blanket's remaining lithium charge is keyed the same way and goes for the same reason. It
  -- is the reactor's entry rather than the blanket's (see control.lua), so a reactor leaving the
  -- map takes it with it.
  if storage.blanket_charge then storage.blanket_charge[unit_number] = nil end
end

-- ---------------------------------------------------------------- reactor -> fittings
--
-- A reactor breeds tritium and helium-3 and has nowhere to put them, so a player bolts an
-- rf-isotope-collector to it (#27); and a player who wants it to breed more bolts an
-- rf-lithium-blanket to it as well (#30). Which fitting belongs to which reactor is answered here,
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
--
-- The same holds for a shared BLANKET, and it needs one more sentence because the sharing is of a
-- consumable rather than of a pipe. Each reactor keeps its own lithium charge (control.lua,
-- storage.blanket_charge) and draws its own items out of the shared inventory when that charge
-- runs down, so two reactors on one blanket empty it twice as fast rather than breeding twice for
-- free. What it costs is the same thing: one inserter has to keep up with both.
local function touching(entity)
  local box = entity.bounding_box
  return {
    { box.left_top.x - 1, box.left_top.y - 1 },
    { box.right_bottom.x + 1, box.right_bottom.y + 1 },
  }
end

--- Point a reactor at each fitting bolted to it, or at nothing.
--
-- Lowest unit_number wins when a reactor is flanked by two, so the answer does not depend on the
-- order find_entities_filtered happens to return them in -- which would otherwise be a desync
-- waiting for two players to build at once.
local function attach(reactor)
  if not (reactor and reactor.valid) then return end
  local area = touching(reactor)
  for _, fitting in ipairs(FITTINGS) do
    local best
    for _, found in pairs(reactor.surface.find_entities_filtered({
      area = area, name = fitting.name,
    })) do
      if not best or found.unit_number < best.unit_number then best = found end
    end
    storage[fitting.key] = storage[fitting.key] or {}
    storage[fitting.key][reactor.unit_number] = best
  end
end

--- Whichever fitting of one kind is serving this reactor, or nil.
--
-- A fitting that has stopped being valid -- mined, destroyed, blown up -- is looked up again
-- rather than merely forgotten, and that is not belt-and-braces. Nothing raises a build event when
-- an entity is removed, so a reactor flanked by two collectors that loses the one it was paired to
-- would otherwise breed into nothing for ever while the second sat against it doing nothing, until
-- some unrelated mod's version bump triggered a rescan.
--
-- The search happens on the one step the entity went invalid and never again: attach() writes back
-- whatever it finds, including nothing, and a nil entry returns above without looking. It re-pairs
-- every fitting rather than only the one asked for, which costs a second search on that one step
-- and keeps the two tables from disagreeing about what is bolted to the reactor.
local function paired(reactor, key)
  local table_for_kind = storage[key]
  local found = table_for_kind and table_for_kind[reactor.unit_number]
  if not found then return nil end
  if found.valid then return found end
  attach(reactor)
  local repaired = table_for_kind[reactor.unit_number]
  return repaired and repaired.valid and repaired or nil
end

--- The collector serving this reactor, or nil.
function M.collector(reactor)
  return paired(reactor, "collectors")
end

--- The lithium blanket fitted to this reactor, or nil (#30).
function M.blanket(reactor)
  return paired(reactor, "blankets")
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
    return
  end
  for _, fitting in ipairs(FITTINGS) do
    if entity.name == fitting.name then
      -- Built the other way round: a fitting arrives after the reactor it serves, which is the
      -- usual order a player does it in. Every reactor it touches re-pairs.
      for _, reactor in pairs(entity.surface.find_entities_filtered({
        area = touching(entity), name = REACTOR,
      })) do
        attach(reactor)
      end
      return
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
  for _, fitting in ipairs(FITTINGS) do storage[fitting.key] = {} end
  -- Deliberately NOT cleared with them. A blanket's remaining lithium is fuel a player paid for,
  -- and a rescan happens on every configuration change -- so emptying it here would quietly bill
  -- every blanket in the game a partial item every time an unrelated mod bumped its version. The
  -- entries are keyed by reactor unit_number and are pruned by forget() when a reactor leaves.
  storage.blanket_charge = storage.blanket_charge or {}
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered({ name = REACTOR })) do
      register(entity)
    end
  end

  -- Charges belonging to reactors that are no longer on the map, dropped here because this is the
  -- only place that can see it. forget() is the usual pruning path and it only fires for reactors
  -- the register still holds when they go invalid -- so a reactor removed while this mod was
  -- disabled, or on a surface that has since been deleted, never reaches it: the wipe above simply
  -- loses the key. That is the same gap circuit.rescan() exists to close for combinators, and it
  -- matters for the same reason: Factorio reuses unit_numbers, so a later reactor could inherit up
  -- to an item's worth of lithium it never paid for, and the table would grow for the life of the
  -- save.
  --
  -- After the loop rather than before, because storage.reactors has to be the rebuilt one.
  for unit_number in pairs(storage.blanket_charge) do
    if not storage.reactors[unit_number] then storage.blanket_charge[unit_number] = nil end
  end
end

-- ---------------------------------------------------------------- how a reactor appears
--
-- Wired here rather than handed back to control.lua for it to install: the whole point of the
-- split is that a new way for an entity to appear is a change to this file alone.

-- The reactor and every fitting. The fittings are here for the pairing rather than for the
-- register: register() sends each one to attach() the reactors it touches. Successive filter
-- entries are OR'd -- `mode` defaults to "or" -- so this is "any of these names", not "all", which
-- nothing could ever be.
local built_filter = { { filter = "name", name = REACTOR } }
for _, fitting in ipairs(FITTINGS) do
  built_filter[#built_filter + 1] = { filter = "name", name = fitting.name }
end
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

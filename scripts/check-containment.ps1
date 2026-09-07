<#
.SYNOPSIS
    Checks that neither plasma nor reactor energy can enter a vanilla pipe, that the plasma-safe
    set carries plasma end to end, that no vanilla vessel can hold reactor energy, and that ordinary
    fluids are untouched. Discharges #26 and #86.

.DESCRIPTION
    CONTEXT.md's rule is that plasma must not travel through vanilla pipes. ADR 0010 says the 1.1
    original enforced that in control.lua -- 160 lines whose only job was hunting down
    plasma-carrying vanilla pipes and destroying them -- and that v1 does the same.

    v1 does not do the same, and this is the note explaining why.

    2.0 gives every pipe connection a connection_category, and two connections join only when theirs
    match. The plasma set names a category of its own, so a vanilla pipe laid beside a plasma line
    simply does not connect, the way it already refuses to join a heat pipe. That is better than the
    original's answer on every axis that matters: the plasma never enters rather than being noticed
    after it has, it costs nothing per tick, and nobody's pipe is destroyed under them. There is no
    runtime enforcement in this mod at all, and control.lua is untouched by #26.

    SINCE #86 THE SAME MECHANISM HOLDS REACTOR ENERGY, and this file's energy rows now assert the
    OPPOSITE of what they asserted until 2026-09-07. ADR 0018 gives rf-reactor-energy a category of
    its own and ships no pipe that carries it, so a vanilla pipe on a reactor's energy output does
    not join and stays empty -- where the two rows here used to require that it joined and carried.
    The inversion is the ticket's rather than a regression: ADR 0018's Consequences names these two
    assertions by file and says they invert.

    AND NO VANILLA VESSEL CAN HOLD IT. That is the capability ADR 0018 was partly decided on: at one
    megajoule a unit a vanilla storage tank held 25 GJ of reactor energy and a fluid wagon 50 GJ,
    against a vanilla accumulator's 5 MJ. Both routes are checked, and differently, because the
    engine gives them different shapes -- see WHAT IS BUILT.

    The cost is that "handled deliberately and visibly" becomes "made impossible", and impossible is
    harder to see than a destroyed pipe. The pipe not joining is the feedback, and for PLASMA the
    item descriptions say so in words -- rf-pipe and rf-pipe-to-ground both carry "Carries plasma.
    Ordinary pipes cannot." (locale/en/d-d.cfg).

    THE ENERGY HALF HAD NO SUCH TEXT UNTIL #86, and that is worth stating because this is a silent
    breaking change for saves and blueprints: a player whose exchanger row stops working needs
    something to read. rf-heat-exchanger, rf-hc-exchanger, rf-direct-energy-converter and both
    reactors now say in their descriptions that the energy face bolts and that no pipe carries the
    fluid. Nothing here asserts that text -- locale-check.ps1 requires a NAME and treats a
    description as optional -- so this paragraph is the record of where it lives.

    WHAT IS BUILT

      contained   A plasma line, with a vanilla pipe laid against it. The two must not join and the
                  vanilla pipe must stay empty.
      tunnel      A live plasma pipe-to-ground with a vanilla one facing it five tiles away, which
                  is well inside the range they would bridge if the categories matched. Laying the
                  vanilla one merely NEAR a plasma line would prove nothing -- entities two tiles
                  apart cannot join whatever their categories say, so that assertion would pass
                  with containment removed.
      chain       Feed -> plasma pipe -> plasma pump -> underground plasma pipe -> reactor. Plasma
                  has to arrive, which is one assertion covering the whole set: anything in that run
                  that failed to connect would leave the reactor starved.
      energy      A vanilla pipe on one of the reactor's two reactor-energy outputs, which must NOT
                  join and must stay empty, and the rigs' own categorised energy feed on the other,
                  which MUST join and MUST carry. The second row is what makes the first mean
                  anything: a refused connection and a mis-aligned one look identical from outside,
                  and ADR 0018's Consequences call that arithmetic a trap. So the same box, the same
                  helper and the same tile arithmetic are shown joining something that shares the
                  category.
      vessels     A vanilla storage tank and a vanilla pump, each laid against a live categorised
                  energy feed, which must not join it and must hold nothing -- and each laid against
                  a vanilla water pipe as its own control, where it must join and must fill. Without
                  the water row "the tank is empty" is a statement about the rig's placement rather
                  than about containment.

                  THE FLUID WAGON IS CLOSED BY THE PUMP AND IS ASSERTED THAT WAY, because it has no
                  plumbing of its own to refuse: `fluid-wagon` declares `capacity` and NO fluid box
                  at 2.0.77, so the only route into one is a pump and the row above is that pump
                  being refused. The rig asserts the premise rather than assuming it -- that the
                  wagon prototype really does declare no fluid box -- so a version that gave it one
                  fails here instead of leaving a gap nobody watches.
      crossed     The two energy categories against each other (#87). ADR 0018 item 3 gives each
                  energy fluid a category of ITS OWN rather than sharing one, so that a converter
                  cannot be bolted to a neutronic reactor and an exchanger cannot be bolted to an
                  aneutronic one -- the engine refuses the connection instead of joining two boxes
                  whose filters disagree and leaving a player to work out why nothing flows.

                  Five pairs, bolted by the same helper on the same arithmetic: the three matching
                  pairs must join and the two crossed pairs must not. The matching pairs are the
                  controls, and they are why the refusals are about categories rather than about a
                  machine placed one tile out.

                  THE THIRD MATCHING PAIR IS rf-hc-exchanger, and it is not decoration.
                  ADR 0031 rests on the finding that a plain `"input"` connection still ACCEPTS a
                  bolt -- which is why containment did not have to wait for #276's footprint -- and
                  until #86 that was measured only by `probe-energy-containment.ps1`, which asserts
                  nothing. This is the gate on it.
      ordinary    A vanilla infinity pipe feeding the heater its deuterium. Deuterium is an ordinary
                  fluid and must work exactly as before -- containment is per box, and this is what
                  says so.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/check-containment.ps1
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$rigName  = 'rf-containment-rig'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-cont-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

function Write-Rig {
    @{
        name = $rigName; version = '0.0.1'; title = 'Containment check'
        author = 'check-containment.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

    $feed       = Write-PlasmaFeed -RigDirectory $rigDir
    # The rigs' shared categorised energy feed (#84). An INSTRUMENT and not something a player has:
    # ADR 0018 ships no pipe carrying either energy fluid, so this is the only thing in the game that
    # can supply one, and it is what the refusals below are measured against.
    $energyFeed = Write-EnergyFeed -RigDirectory $rigDir

    $lua = @'
-- Generated by scripts/check-containment.ps1. Nothing here ships.

local PLASMA = "rf-d-d-plasma"
local ENERGY = "rf-reactor-energy"
local FEED   = "__PLASMAFEED__"
local ENERGY_FEED = "__ENERGYFEED__"

local lines = {}
local failures = 0

local function record(ok, name, detail)
  if not ok then failures = failures + 1 end
  lines[#lines + 1] = string.format("%s  %s%s", ok and "ok  " or "FAIL", name,
    detail and ("  -- " .. detail) or "")
end

local function must(entity, what)
  if not entity then error(what .. " refused") end
  return entity
end

local function amount_of(entity, index)
  local contents = entity.fluidbox[index]
  return contents and contents.amount or 0
end

local function box_of(entity, fluid)
  for index = 1, #entity.fluidbox do
    local filter = entity.fluidbox.get_filter(index)
    if filter and filter.name == fluid then return index end
  end
  return nil
end

--- The index of the box a reactor sells its energy from, by production_type rather than by fluid --
--- because which fluid that is depends on which reactor, and the crossed rows below build both.
---
--- THE PROTOTYPE'S BOX ORDER IS FOUND FIRST AND THEN RE-FOUND AT RUNTIME, rather than the prototype
--- index being handed straight to entity.fluidbox. The two orders are not the same thing: a boiler
--- with a fluid ENERGY SOURCE presents them differently, measured on rf-heat-exchanger and recorded
--- in check-pooling.ps1's box_of, where a prototype index returned the WATER box's connections and
--- cost that rig a run. Both reactors carry an electric energy source today, so the two orders
--- agree for them and this is a guard rather than a fix -- but a reactor that ever gained a fluid
--- one would otherwise read the wrong box in silence.
local function box_of_output(entity)
  for index, box in ipairs(prototypes.entity[entity.name].fluidbox_prototypes) do
    if box.production_type == "output" and box.filter then
      local runtime = box_of(entity, box.filter.name)
      if runtime then return runtime end
    end
  end
  error(entity.name .. " has no filtered output box this rig can find at runtime")
end

--- Does any connection on this box reach the given entity?
--
-- An index past the end is answered "no" rather than raised. Callers below ask about box 2 on
-- entities that may only have one -- a pump has a single fluid box holding both its connections --
-- and those reads are guarded by an `or` that short-circuits only while the FIRST term is true. So
-- an unguarded index would raise precisely when containment had regressed, killing the rig instead
-- of letting it print the FAIL line it exists to print.
local function joins(entity, index, other)
  if index > #entity.fluidbox then return false end
  for _, connection in pairs(entity.fluidbox.get_pipe_connections(index)) do
    if connection.target and connection.target.owner == other then return true end
  end
  return false
end

--- Which way a runtime connection faces, read off the tile it targets rather than remembered.
local function facing(connection)
  local dx = connection.target_position.x - connection.position.x
  local dy = connection.target_position.y - connection.position.y
  if dy < 0 then return "north" elseif dy > 0 then return "south" elseif dx < 0 then return "west" end
  return "east"
end

--- The connection of `entity`'s box on `fluid` that faces `side`, or nil.
local function connection_facing(entity, fluid, side)
  local index = box_of(entity, fluid)
  if not index then error(entity.name .. " has no box filtered to " .. fluid) end
  for _, c in pairs(entity.fluidbox.get_pipe_connections(index)) do
    if facing(c) == side then return c end
  end
  return nil
end

--- Place `name` so that its connection on the box filtered to `fluid`, facing `side`, STANDS ON
--- `tile` -- which is the other machine's target_position.
---
--- THAT IS THE BOLT ARITHMETIC AND NOT THE PIPE-RUN ONE, and ADR 0018's Consequences call the
--- difference a trap that cost #82's rig a false negative on the question deciding that ADR. A pipe
--- run aligns a connection's TARGET onto the tile the pipe occupies; a bolt aligns one machine's
--- connection TILE onto the other's target. Align target against target and the two machines sit
--- one tile clear of each other pointing at the same empty ground, which is indistinguishable from
--- a refused connection -- which is exactly what this section is trying to tell apart.
---
--- The machine is placed once as a probe, asked where that connection is relative to itself,
--- destroyed, and placed again by the difference. check-hc.ps1 carries the same helper for the same
--- reason (#49): a remembered offset is a hostage to the next prototype edit.
local function bolt(surface, force, name, fluid, side, tile, seed)
  local probe = must(surface.create_entity({ name = name, position = seed, force = force }),
    "probe " .. name)
  local index = box_of(probe, fluid)
  if not index then
    probe.destroy()
    error(name .. " has no box filtered to " .. fluid)
  end
  local found
  for _, c in pairs(probe.fluidbox.get_pipe_connections(index)) do
    if facing(c) == side then found = c end
  end
  if not found then
    probe.destroy()
    error(name .. " has no " .. side .. "-facing " .. fluid .. " connection")
  end
  local off = { x = found.position.x - probe.position.x, y = found.position.y - probe.position.y }
  probe.destroy()
  return must(surface.create_entity({
    name = name, position = { tile.x - off.x, tile.y - off.y }, force = force,
  }), string.format("%s bolted at (%g, %g)", name, tile.x - off.x, tile.y - off.y))
end

-- `at` is the substation's centre and must be a whole number: a 2x2 entity sits on a tile boundary,
-- where the 1x1 interface beside it sits on a tile centre. create_entity would snap a half-tile
-- position rather than refuse it, which is how the two would silently end up on different grids.
local function power(surface, force, at)
  if at[1] % 1 ~= 0 or at[2] % 1 ~= 0 then
    error(string.format("power() wants a whole-number position, got (%g, %g)", at[1], at[2]))
  end
  must(surface.create_entity({ name = "substation", position = at, force = force }), "substation")
  local eei = must(surface.create_entity({
    name = "electric-energy-interface", position = { at[1] + 2.5, at[2] + 0.5 }, force = force,
  }), "power source")
  eei.power_production = 4e6
end

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player
  force.research_all_technologies()

  -- EVERY ENTITY THIS RIG PLACES HAS TO BE INSIDE THIS BOX, and it is not a tidiness rule. Outside
  -- it the ground is raw terrain: one tree or rock on a tile makes create_entity answer nil, `must`
  -- raises inside on_init, no save is written, and the check reports NOTHING rather than a FAIL. The
  -- map has no fixed seed, so it would fail on some runs and not others. probe-converter-buffer.ps1
  -- was bitten by exactly that with a scratch entity at y = -400.
  --
  -- North to -70 for the crossed section's reactors at y -53..-38 and whatever bolts to a face of
  -- one: rf-hc-exchanger takes the NORTH face and reaches y -60, which was the old edge exactly.
  -- South to 45 for the vessel rows, whose water pair sits at y 31-34 with a substation and an
  -- interface behind it at y 37-39. East to 170 for the crossed row's five-cell pitch, whose last
  -- reactor spans x 153-168.
  local CLEAR = { { -40, -70 }, { 170, 45 } }
  surface.request_to_generate_chunks({ 0, 0 }, 6)
  surface.force_generate_chunk_requests()
  local tiles = {}
  for x = CLEAR[1][1], CLEAR[2][1] do
    for y = CLEAR[1][2], CLEAR[2][2] do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = CLEAR })) do
    if e.type ~= "character" then e.destroy() end
  end

  storage.rig = {}

  -- ------------------------------------------------------------------ the chain
  --
  -- Feed -> underground plasma pipe -> plasma pump -> plasma pipe -> reactor, laid west from the
  -- reactor's own connection. Plasma arriving at the far end is one assertion that covers the whole
  -- set: any component in the run that failed to join would leave the reactor starved.
  local reactor = must(surface.create_entity({
    name = "rf-reactor", position = { 0.5, 0.5 }, force = force, raise_built = true,
  }), "rf-reactor")
  power(surface, force, { 9, 5 })

  local west = reactor.fluidbox.get_pipe_connections(1)[1].target_position
  local pipe_near = must(surface.create_entity({
    name = "rf-pipe", position = { west.x, west.y }, force = force }), "rf-pipe (near)")
  local pipe_far = must(surface.create_entity({
    name = "rf-pipe", position = { west.x - 1, west.y }, force = force }), "rf-pipe (far)")

  -- A 1x2 entity turned east covers two tiles across, so its centre sits on a tile boundary.
  local pump = must(surface.create_entity({
    name = "rf-pump", position = { west.x - 2.5, west.y }, force = force,
    direction = defines.direction.east,
  }), "rf-pump")

  local under_near = must(surface.create_entity({
    name = "rf-pipe-to-ground", position = { west.x - 4, west.y }, force = force,
    direction = defines.direction.east,
  }), "rf-pipe-to-ground (near)")
  local under_far = must(surface.create_entity({
    name = "rf-pipe-to-ground", position = { west.x - 8, west.y }, force = force,
    direction = defines.direction.west,
  }), "rf-pipe-to-ground (far)")

  -- The pump needs its own supply. The reactor is fifteen tiles across and the pump sits ten tiles
  -- beyond its far edge, which is outside the reach of the substation covering the reactor -- and an
  -- unpowered pump moves nothing while every joint in the chain still reports as connected.
  power(surface, force, { math.floor(west.x) - 3, math.floor(west.y) + 6 })

  local feed = must(surface.create_entity({
    name = FEED, position = { west.x - 9, west.y }, force = force,
  }), "plasma feed")
  feed.set_infinity_pipe_filter({ name = PLASMA, percentage = 1, temperature = 6e8, mode = "at-least" })

  -- ------------------------------------------------------------------ the reactor's energy faces
  --
  -- ONE ORDINARY PIPE AND ONE CATEGORISED FEED, on the two faces of the same box (#86). Since ADR
  -- 0018 the ordinary one must be refused, and the categorised one must join and carry -- which is
  -- what makes the refusal a measurement rather than a mis-aligned pipe. ADR 0018's Consequences
  -- call that arithmetic a trap and #82's rig fell into it: align target against target and the two
  -- ends sit one tile clear of each other, indistinguishable from a refusal.
  --
  -- BOTH TILES COME OFF THE PROTOTYPE, by index into the connection list rather than by face. The
  -- reactor sells energy north and south since #275 and this rig does not care which is which; it
  -- cares that the two rows use the same helper on the same box.
  local energy_box = box_of(reactor, ENERGY)
  local energy_faces = reactor.fluidbox.get_pipe_connections(energy_box)
  if #energy_faces < 2 then
    error(string.format("rf-reactor's energy box has %d connection(s); this rig needs two, one for "
      .. "the refused pipe and one for the categorised feed", #energy_faces))
  end
  local energy_pipe = must(surface.create_entity({
    name = "pipe", position = energy_faces[1].target_position, force = force,
  }), "vanilla pipe on the energy output")
  -- NO INFINITY FILTER ON IT, deliberately: an unfiltered infinity pipe is an ordinary pipe that
  -- happens to carry the category, so what fills it is the reactor's own production. A feed set to
  -- "at-least" would make "it carries" a statement about the feed's filter instead of about the
  -- reactor's output box, which is the same mistake as insert_fluid on an unplumbed tank.
  local energy_feed = must(surface.create_entity({
    name = ENERGY_FEED, position = energy_faces[2].target_position, force = force,
  }), "categorised energy feed on the energy output")

  -- ------------------------------------------------------------------ the contained line
  --
  -- A plasma line of its own, with an ordinary pipe laid against its end.
  local island = must(surface.create_entity({
    name = FEED, position = { 40.5, 0.5 }, force = force,
  }), "island feed")
  island.set_infinity_pipe_filter({ name = PLASMA, percentage = 1, temperature = 6e8, mode = "at-least" })
  local plasma_pipe = must(surface.create_entity({
    name = "rf-pipe", position = { 41.5, 0.5 }, force = force,
  }), "island plasma pipe")
  local vanilla_pipe = must(surface.create_entity({
    name = "pipe", position = { 42.5, 0.5 }, force = force,
  }), "vanilla pipe beside the plasma line")
  -- ------------------------------------------------------------------ the tunnel
  --
  -- The underground case needs its own row, and the reason is the whole point of it. An underground
  -- pipe laid *beside* a plasma line is a test of nothing: two entities two tiles apart cannot join
  -- whatever their categories say, so the assertion would pass with containment removed. The claim
  -- worth checking is the one entities.lua actually makes -- that a vanilla pipe-to-ground cannot
  -- tunnel into a plasma line from out of sight -- and that needs the two undergrounds facing each
  -- other across open ground, at a range they would certainly bridge if the categories matched.
  --
  -- direction is the ABOVEGROUND connection's facing, so these point away from each other and their
  -- tunnel ends point in.
  local tunnel_feed = must(surface.create_entity({
    name = FEED, position = { 40.5, 8.5 }, force = force,
  }), "tunnel feed")
  tunnel_feed.set_infinity_pipe_filter({ name = PLASMA, percentage = 1, temperature = 6e8, mode = "at-least" })
  local plasma_underground = must(surface.create_entity({
    name = "rf-pipe-to-ground", position = { 41.5, 8.5 }, force = force,
    direction = defines.direction.west,
  }), "plasma pipe-to-ground on the tunnel row")
  local vanilla_underground = must(surface.create_entity({
    name = "pipe-to-ground", position = { 46.5, 8.5 }, force = force,
    direction = defines.direction.east,
  }), "vanilla pipe-to-ground facing the plasma line")

  -- ------------------------------------------------------------------ crossed categories
  --
  -- ONE CATEGORY PER FLUID, NOT ONE SHARED BETWEEN THEM (ADR 0018 item 3, #87). Sharing would have
  -- been cheaper by one string and the box filters would still stop the wrong fluid moving -- but it
  -- would let a converter bolt onto a neutronic reactor and then sit dry, which is the same shape of
  -- silent failure as the water-in-the-header footgun ADR 0018 closes. So the engine refuses the
  -- connection outright, and these four pairs are what says it does.
  --
  -- THE MATCHING PAIRS ARE THE CONTROLS. Two boxes one tile clear of each other look exactly like
  -- two boxes the engine refused to join, so a rig that only built the crossed pairs would pass with
  -- containment removed and the arithmetic wrong. Same helper, same faces, same seed for all four.
  --
  -- The reactors are unregistered -- raise_built = false, so realistic-fusion-refreshed never hears of
  -- them and control.lua never steps them. Nothing here is about fluid crossing a joint; it is
  -- about whether the joint forms, which is a question about geometry and categories only.
  --
  -- EACH ROW NAMES THE FACE IT BOLTS BY, because the three machines do not agree on one. The two
  -- 15x5 machines take energy on their NORTH long face and stand south of a reactor; rf-hc-exchanger
  -- is still 7x7 with its one energy connection on the SOUTH face (#276 gives it the others'
  -- footprint), so it stands north of a reactor instead. `face` is the reactor face the machine
  -- meets and `side` is the machine's own connection that meets it -- opposite by construction.
  local crossed = {}
  for i, pair in ipairs({
    { reactor = "rf-reactor",            machine = "rf-heat-exchanger",
      face = "south", side = "north", join = true },
    { reactor = "rf-aneutronic-reactor", machine = "rf-direct-energy-converter",
      face = "south", side = "north", join = true },
    -- THE HIGH-CAPACITY MACHINE BOLTS ON A PLAIN "input" CONNECTION, and that is the row nothing in
    -- the gate set asserted until now. probe-energy-containment.ps1's AC 5 measured it -- 473 units
    -- held, the reactor's box six and two thirds of a unit down every tick, which at 1 MJ a unit is
    -- that machine's whole 400 MW -- and a probe asserts nothing. ADR 0031 rests on it: it is why
    -- containment did not have to wait for #276.
    { reactor = "rf-reactor",            machine = "rf-hc-exchanger",
      face = "north", side = "south", join = true },
    { reactor = "rf-reactor",            machine = "rf-direct-energy-converter",
      face = "south", side = "north", join = false },
    { reactor = "rf-aneutronic-reactor", machine = "rf-heat-exchanger",
      face = "south", side = "north", join = false },
  }) do
    local at = { (i - 1) * 40 + 0.5, -45.5 }
    local reactor = must(surface.create_entity({
      name = pair.reactor, position = at, force = force, raise_built = false,
    }), pair.reactor .. " for the crossed row")
    -- The energy fluid is read off the reactor rather than named per row: which fluid a reactor
    -- sells is the prototype's business, and a row that wrote it down would be asserting a pairing
    -- it does not own.
    local fluid = reactor.fluidbox.get_filter(box_of_output(reactor)).name
    local out = connection_facing(reactor, fluid, pair.face)
    if not out then
      error(string.format("%s has no %s-facing energy output", pair.reactor, pair.face))
    end
    -- Bolted by the machine's OWN energy fluid, which for a crossed pair is not the reactor's. That
    -- is the point: the geometry lines up regardless, and only the category decides.
    local machine_fluid = (pair.machine == "rf-direct-energy-converter")
      and "rf-aneutronic-reactor-energy" or ENERGY
    -- The seed is well south of the row, on a tile centre in both axes so the engine does not snap
    -- an odd-sized machine off the position the offset was measured from.
    local machine = bolt(surface, force, pair.machine, machine_fluid, pair.side,
      out.target_position, { (i - 1) * 40 + 0.5, -20.5 })
    crossed[#crossed + 1] = {
      reactor = reactor, machine = machine, join = pair.join,
      label = string.format("%s bolted to %s's %s face", pair.machine, pair.reactor, pair.face),
      reactor_box = box_of(reactor, fluid), machine_box = box_of(machine, machine_fluid),
    }
  end

  -- ------------------------------------------------------------------ the vessels
  --
  -- WHAT ADR 0018 WAS PARTLY DECIDED ON (#86). At one megajoule a unit a vanilla storage tank held
  -- 25 000 units of reactor energy -- 25 GJ, about five thousand vanilla accumulators -- and a fluid
  -- wagon 50 GJ, haulable across the map. Nobody designed that; it is what a fluid with a fuel_value
  -- and no connection category gets for free. The category takes it away, and these rows say so.
  --
  -- EACH VESSEL IS BUILT TWICE, once against a live categorised energy feed and once against a
  -- vanilla water pipe. The water row is not decoration: without it "the tank holds nothing" is a
  -- statement about where this rig put the tank, and it would pass just as well with containment
  -- removed and the tank one tile out of reach.
  --
  -- The supply goes on the tile the VESSEL's own connection points at, read off the entity after it
  -- is built rather than written down. That is the pipe-run alignment and not the bolt one -- a pipe
  -- run aligns a connection's target onto the tile the pipe occupies (ADR 0018's Consequences).
  local function vessel_pair(name, at, index)
    local built = {}
    for i, supply in ipairs({ { ENERGY_FEED, ENERGY }, { "infinity-pipe", "water" } }) do
      local vessel = must(surface.create_entity({
        name = name, position = { at[1], at[2] + (i - 1) * 12 }, force = force,
      }), string.format("%s for the %s row", name, supply[2]))
      -- THE CONNECTION THAT WILL TAKE FLUID IN, chosen by flow_direction rather than by index, and
      -- the first version took index 1 and got it wrong. A vanilla pump declares its OUTPUT end
      -- first: with the supply on that tile the two boxes join perfectly and the pump's own box
      -- stays empty for ever, because a pump pulls from its input and will not pull backwards
      -- through an output connection. The water control failed with 0 and the refusal rows passed,
      -- which is exactly the shape of a control that is not controlling anything.
      local conn
      for _, c in pairs(vessel.fluidbox.get_pipe_connections(index)) do
        if c.flow_direction ~= "output" then conn = conn or c end
      end
      if not conn then
        error(name .. " has no inward connection on box " .. index .. ", so it cannot be filled")
      end
      local pipe = must(surface.create_entity({
        name = supply[1], position = conn.target_position, force = force,
      }), string.format("%s supply for the %s", supply[2], name))
      pipe.set_infinity_pipe_filter({ name = supply[2], percentage = 1, mode = "at-least" })
      built[#built + 1] = { vessel = vessel, supply = pipe }
    end
    return built[1], built[2]
  end

  -- Box 1 on a storage tank is its only one, and a pump has one box too, holding both of its
  -- connections -- the helper above picks the inward one off each.
  local tank_energy, tank_water = vessel_pair("storage-tank", { 40.5, 20.5 }, 1)
  local pump_energy, pump_water = vessel_pair("pump", { 60.5, 20 }, 1)
  -- The pumps are powered. An unpowered pump moves nothing while every joint it has still reports as
  -- connected, so the water control would read as a refusal for the wrong reason.
  power(surface, force, { 66, 26 })
  power(surface, force, { 66, 38 })

  -- ------------------------------------------------------------------ the heater
  --
  -- Fed deuterium through an ORDINARY infinity pipe, which is the point: only the plasma side is
  -- contained, so the machine's inputs are plumbed the way any other machine's are.
  local heater = must(surface.create_entity({
    name = "rf-heater", position = { 60.5, 0.5 }, force = force,
  }), "rf-heater")
  -- Named rather than discovered, and #28 is why: this took the first recipe in the heater's
  -- crafting category on the grounds that there was only one, and rf-d-t-plasma joined it there.
  -- pairs over a LuaCustomTable promises no order, so the rig could set the D-T recipe and then
  -- throw looking for the deuterium box that recipe does not have -- out of on_init, so the save is
  -- never made and this check reports nothing rather than a failure. Containment is about the pipe
  -- connection rather than the fluid, so D-D is as good a subject as either; it just has to be
  -- decided here instead of by iteration order.
  local recipe = prototypes.recipe["rf-d-d-plasma"]
  local categories = prototypes.entity["rf-heater"].crafting_categories
  if not (recipe and categories[recipe.category]) then
    error("rf-heater cannot craft rf-d-d-plasma; this rig is built around the D-D tier")
  end
  heater.set_recipe(recipe.name)
  power(surface, force, { 66, 6 })

  local deuterium_box = box_of(heater, "rf-deuterium")
  local deuterium_at = heater.fluidbox.get_pipe_connections(deuterium_box)[1].target_position
  local deuterium_feed = must(surface.create_entity({
    name = "infinity-pipe", position = { deuterium_at.x, deuterium_at.y }, force = force,
  }), "vanilla infinity pipe for deuterium")
  deuterium_feed.set_infinity_pipe_filter({
    name = "rf-deuterium", percentage = 1, mode = "at-least",
  })

  storage.rig = {
    reactor = reactor, pump = pump, feed = feed,
    pipe_near = pipe_near, pipe_far = pipe_far,
    under_near = under_near, under_far = under_far,
    energy_pipe = energy_pipe, energy_feed = energy_feed, energy_box = energy_box,
    crossed = crossed,
    tank_energy = tank_energy, tank_water = tank_water,
    pump_energy = pump_energy, pump_water = pump_water,
    plasma_pipe = plasma_pipe, vanilla_pipe = vanilla_pipe,
    plasma_underground = plasma_underground, vanilla_underground = vanilla_underground,
    heater = heater, deuterium_feed = deuterium_feed,
  }
  log("CONT-RIG built")
end)

script.on_nth_tick(600, function()
  if game.tick == 0 or storage.done then return end
  storage.done = true
  local r = storage.rig

  -- ------------------------------------------------------------ plasma cannot enter a vanilla pipe
  record(not joins(r.plasma_pipe, 1, r.vanilla_pipe),
    "an ordinary pipe laid against a plasma pipe does not join it")
  record(amount_of(r.vanilla_pipe, 1) == 0,
    "the ordinary pipe beside a live plasma line is still empty",
    string.format("%g", amount_of(r.vanilla_pipe, 1)))

  -- The tunnel row. The first of these is what makes the other two mean anything: an empty vanilla
  -- underground proves containment only if there was plasma on the far side to leak.
  record(amount_of(r.plasma_underground, 1) > 0,
    "the plasma underground pipe is live, so there is something for the tunnel to carry",
    string.format("%g", amount_of(r.plasma_underground, 1)))
  record(not joins(r.plasma_underground, 1, r.vanilla_underground),
    "an ordinary underground pipe cannot tunnel into a plasma line, facing it across open ground")
  record(amount_of(r.vanilla_underground, 1) == 0,
    "and so the ordinary underground pipe is still empty",
    string.format("%g", amount_of(r.vanilla_underground, 1)))

  -- ------------------------------------------------------------ the set carries plasma end to end
  -- Joint by joint, so a break names itself instead of showing up only as a starved reactor at the
  -- far end.
  record(joins(r.reactor, 1, r.pipe_near), "the reactor joins the plasma pipe")
  record(joins(r.pipe_near, 1, r.pipe_far), "plasma pipe joins plasma pipe")
  record(joins(r.pipe_far, 1, r.pump), "the plasma pipe joins the pump")
  record(joins(r.pump, 1, r.under_near) or joins(r.pump, 2, r.under_near),
    "the pump joins the underground plasma pipe")
  record(joins(r.under_near, 1, r.under_far), "the two underground plasma pipes join each other")
  record(joins(r.under_far, 1, r.feed), "the far underground pipe joins the feed")

  local plasma = r.reactor.fluidbox[1]
  record(plasma ~= nil and plasma.amount > 0,
    "plasma reaches the reactor through pipe, pump and underground pipe",
    plasma and string.format("%g units at %.4g C", plasma.amount, plasma.temperature) or "nothing")
  record(plasma ~= nil and plasma.temperature > 1e8,
    "it arrives at the temperature it was fed, so nothing was lost on the way",
    plasma and string.format("%.4g C", plasma.temperature) or "nothing")
  local status = "unknown"
  for name, value in pairs(defines.entity_status) do
    if value == r.pump.status then status = name end
  end
  record(r.pump.status == defines.entity_status.working,
    "the plasma pump is powered and working", status)

  -- ------------------------------------------------------------ reactor energy is contained too
  --
  -- THE TWO ORDINARY-PIPE ROWS BELOW ARE THE INVERSE OF WHAT THEY WERE (#86). They asserted that an
  -- ordinary pipe still joined the reactor's energy output and still carried the fluid, which was
  -- correct until ADR 0018's item 1 shipped and is the opposite of the target behaviour after it.
  -- ADR 0018's Consequences named this file and said they would invert.
  --
  -- The categorised row comes first because the two after it mean nothing without it: same box, same
  -- connection list, same tile arithmetic, joining something that shares the category. A refusal and
  -- a mis-aligned pipe are indistinguishable from outside.
  record(joins(r.reactor, r.energy_box, r.energy_feed),
    "the categorised energy feed joins the reactor's other energy face, so the box joins at all")
  record(amount_of(r.energy_feed, 1) > 0,
    "and carries reactor energy through it -- no pipe a player can build does",
    string.format("%g", amount_of(r.energy_feed, 1)))

  record(not joins(r.reactor, r.energy_box, r.energy_pipe),
    "an ordinary pipe does NOT join the reactor's reactor-energy output")
  record(amount_of(r.energy_pipe, 1) == 0,
    "and so it stays empty beside a reactor that is selling energy",
    string.format("%g", amount_of(r.energy_pipe, 1)))

  -- ------------------------------------------------------------ and no vanilla vessel can hold it
  for _, case in ipairs({
    { name = "storage tank", energy = r.tank_energy, water = r.tank_water,
      lost = "the 25 GJ of reactor energy ADR 0018 was partly decided on" },
    { name = "pump",         energy = r.pump_energy, water = r.pump_water,
      lost = "and a pump is the only route into a fluid wagon, so its 50 GJ goes with it" },
  }) do
    -- The control first, for the same reason the tunnel row asserts its plasma is live: a vessel
    -- this rig had put out of reach would pass the refusal rows by accident.
    record(joins(case.water.vessel, 1, case.water.supply),
      "a vanilla " .. case.name .. " joins an ordinary water pipe")
    record(amount_of(case.water.vessel, 1) > 0,
      "and fills with water, so the arrangement and the placement are sound",
      string.format("%g", amount_of(case.water.vessel, 1)))
    record(not joins(case.energy.vessel, 1, case.energy.supply),
      "the same vanilla " .. case.name .. " does NOT join a live reactor-energy line")
    record(amount_of(case.energy.vessel, 1) == 0,
      "and holds nothing -- " .. case.lost,
      string.format("%g", amount_of(case.energy.vessel, 1)))
  end

  -- THE FLUID WAGON, CLOSED BY THE PUMP ROWS ABOVE RATHER THAN BY A WAGON OF ITS OWN. At 2.0.77
  -- `fluid-wagon` declares `capacity` and no fluid box at all, so it has no plumbing to refuse and
  -- nothing to lay against a feed: the only route into one is a pump, and a pump is refused above.
  -- The premise is asserted rather than assumed, so a version that gave the wagon a fluid box fails
  -- here instead of leaving the wagon route unwatched.
  local wagon = prototypes.entity["fluid-wagon"]
  record(wagon ~= nil and #wagon.fluidbox_prototypes == 0,
    "a fluid wagon declares no fluid box, so the refused pump above is its only route in",
    wagon and string.format("%d fluid box(es), capacity %s",
      #wagon.fluidbox_prototypes, tostring(wagon.fluid_capacity)) or "no fluid-wagon prototype")

  -- ------------------------------------------------------------ the two energies do not mix
  --
  -- The matching pairs first, for the reason the tunnel row asserts its plasma is live: if a bolt
  -- does not form even between machines that agree, the two refusals below say nothing at all.
  for _, case in ipairs(r.crossed) do
    local joined = joins(case.reactor, case.reactor_box, case.machine)
    if case.join then
      record(joined, case.label .. " joins, so the bolt arithmetic is sound")
    else
      record(not joined,
        case.label .. " is REFUSED: the two energies carry separate categories")
    end
  end

  -- ------------------------------------------------------------ ordinary fluids are untouched
  record(joins(r.heater, 1, r.deuterium_feed) or joins(r.heater, 2, r.deuterium_feed),
    "an ordinary pipe still feeds the heater its deuterium")

  local produced = 0
  for index = 1, #r.heater.fluidbox do
    local contents = r.heater.fluidbox[index]
    if contents and contents.name == PLASMA then produced = produced + contents.amount end
  end
  record(produced > 0, "and the heater makes plasma from it", string.format("%g", produced))

  lines[#lines + 1] = string.format("%s: %d checks, %d failures",
    failures == 0 and "PASS" or "FAIL", #lines, failures)
  for _, line in ipairs(lines) do log("CONT-RIG " .. line) end
end)
'@
    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') `
        -Value $lua.Replace('__PLASMAFEED__', $feed).Replace('__ENERGYFEED__', $energyFeed)
}

$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled @() -Mods ($ourMods + $rigName)
    Write-Rig

    $save = Join-Path $temp 'containment.zip'
    Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create' | Out-Null
    $runOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', '1500', '--benchmark-runs', '1', '--disable-audio')

    $reported = @(Get-Content $runOut | Select-String -Pattern 'CONT-RIG (ok|FAIL|PASS)' |
        ForEach-Object { ($_ -split 'CONT-RIG ', 2)[1].TrimEnd() })
    if ($reported.Count -eq 0) { throw 'the rig reported nothing; it never reached its check tick.' }

    foreach ($line in $reported) { Write-Host "  $line" }

    $verdict = $reported | Where-Object { $_ -match '^(PASS|FAIL): ' } | Select-Object -Last 1
    if (-not $verdict)              { throw 'the rig produced no verdict line.' }
    if ($verdict -notmatch '^PASS') { throw "containment is broken: $verdict" }

    Write-Host ''
    Write-Host 'OK - plasma stays in the plasma set, reactor energy reaches no pipe, tank or wagon,'
    Write-Host '     the two energy fluids will not bolt to each other, and ordinary fluids are'
    Write-Host '     untouched.'
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'check-containment' }
}

#Requires -Version 7
<#
.SYNOPSIS
    Probes whether a reactor prototype can emit native heat and still pool plasma on a run of
    rf-pipe. Evidence for #43, which blocks the decision in #44.

.DESCRIPTION
    A PROBE, NOT A CHECK. Every line it prints is a measurement, and a negative answer is as much
    of a result as a positive one -- so exit 0 means the probe ran and every row reported, never
    that the answers were the ones anybody hoped for. Nothing here decides anything and nothing
    here ships: the design is #44's to choose.

    #43 exists because the data stage already said yes. Probing base 2.0.77 with each case a
    deepcopy of a valid vanilla prototype and one field changed, a `reactor` accepted an
    input-output fluid box, a `reactor` accepted an electric energy source, and a `boiler` accepted
    a heat_buffer. On paper rf-reactor could stay a shared-plasma entity (ADR 0011), keep drawing
    confinement heating from the network, and emit heat natively.

    On paper is exactly the problem. #23 chose a crafting machine for the reactor on the same kind
    of reasoning; it loaded perfectly and then moved no fluid at all -- pipes connected and nothing
    crossed -- which is why the reactor is a boiler today. So this builds the prototypes, runs them,
    and measures.

    WHAT IS BUILT

      pool      Two probe reactors joined by a run of rf-pipe, the WESTMOST one seeded with plasma
                and the other left empty. If a reactor's declared fluid box joins a segment the way
                the boiler's does, the two must end up sharing one amount at one temperature and
                report the same fluid segment id. If the field was accepted and ignored, the reactor
                has no fluid box at all and this row says so in its first line.

      deliver   A probe reactor pinned to its buffer's maximum by Lua every tick, a short run of
                vanilla heat pipe, and a heat-interface sink held at 0 C. Delivered power is
                measured AT THE SOURCE, as the joules the pin had to inject to hold the temperature
                -- specific_heat times the deficit it found. That needs no steam, no water and no
                tank, so nothing in the measurement can be a fluid throughput limit in disguise.

                It also carries the one real consumer in the rig: a vanilla heat exchanger on the
                same pipe, fed water and voiding its steam. The interface answers "how much
                arrives", the exchanger answers "does a machine that burns heat run off this".

      cadence   The same row written every 6 ticks instead of every tick -- control.lua's
                UPDATE_INTERVAL. If this mod ever emits heat it will emit it on that cadence, and a
                rate that only holds when written sixty times a second would be no use.

      run       The same row with twenty-four heat pipes between source and sink. Against `deliver`
                this is what a vanilla heat pipe carries over a distance a player would build, and
                the answer decides whether a pipe entity of our own is justified at all.

      tight     A probe reactor whose heat buffer declares max_transfer 50 MW instead of vanilla's
                10 GW, with a pipe run and a sink on EACH of two opposite connections. Two sinks
                rather than one because the number that matters is whether max_transfer is a
                per-connection limit or a whole-buffer one: 50 MW delivered says the buffer, 100 MW
                says the connection.

      self      Two probe reactors declaring consumption 133 MW -- what the shipped reactor makes at
                equilibrium (scripts/reactor-logic.lua) -- on a 1 GW network, WITH NO LUA WRITES AT
                ALL and nothing attached. One starts cold, so its temperature climb measures whether
                a reactor with an electric energy source turns electricity into heat by itself. The
                other is put at 990 C on the first tick, so it sits at its ceiling for the whole run
                and the electric statistics can say whether it keeps drawing there.

                This is the row that decides whether `consumption` has to be neutered the way the
                boiler's energy_consumption is today.

      boiler    The shipped rf-reactor's own shape -- a heat-exchanger copy with an electric source
                and energy_consumption at 1 W -- plus a heat_buffer, pinned and piped like
                `deliver`. #43's table has this loading; whether a boiler EMITS through a field the
                boiler prototype does not declare is the open half.

    HOW THE ROWS ARE INSTRUMENTED, AND WHAT THAT COSTS

    The sink is a heat-interface held at 0 C rather than a bank of heat exchangers. It absorbs
    everything the run can deliver instead of 10 MW a machine, and it keeps the far end of every run
    cold -- so the gradient is the largest one the engine can be shown and every throughput figure
    here is best case. A real bank of exchangers would read lower. Said out loud because a best-case
    number used as a design margin is how this kind of measurement misleads.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Warmup
    Ticks before the measurement window opens. A twenty-four pipe run holds tens of gigajoules and
    has to reach steady state before a rate means anything.

    The default is enough, and that is measured rather than assumed: the long run delivers 606.64 MW
    at 1800 ticks of warmup against 606.22 MW at 7200, a 0.07% difference. At 600 it reads 766 MW,
    which is the pipes still filling and would have been quoted as throughput.

.PARAMETER Window
    Ticks in the measurement window.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/probe-native-heat.ps1
#>
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [int]    $Warmup = 1800,
    [int]    $Window = 900,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = @('realistic-fusion-refreshed-core', 'realistic-fusion-refreshed')
$rigName  = 'rf-heat-probe-rig'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-heat-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

function Write-Rig {
    @{
        name = $rigName; version = '0.0.1'; title = 'Native heat probe'
        author = 'probe-native-heat.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

    $data = @'
-- Generated by scripts/probe-native-heat.ps1 (#43). Nothing here ships.
--
-- Every subject is a deepcopy of a valid vanilla prototype with the fields under test changed and
-- nothing else, which is how #43's data-stage table was built. The heat buffer is nuclear-reactor's
-- own, unchanged, everywhere except rf-probe-reactor-tight: the question is what vanilla's numbers
-- do, and tuning them before the design exists would only measure the tuning.

local plasma_pipe = data.raw["pipe"]["rf-pipe"]
if not plasma_pipe then
  error("rf-pipe is missing; the probe cannot work out the plasma connection category")
end
-- Read off the shipped pipe rather than named again here, so the rig follows the mod.
-- factorio-lib.ps1's Write-PlasmaFeed does the same, and for the same reason (#26).
local CATEGORY = plasma_pipe.fluid_box.pipe_connections[1].connection_category

local reactor = data.raw["reactor"]["nuclear-reactor"]

-- What #44 would build if the reactor became a heat source: a reactor prototype, because that is
-- the only vanilla type whose whole job is emitting heat, carrying the three things rf-reactor
-- cannot give up -- an electric energy source for confinement heating, a neutered consumption so
-- the draw follows the simulation rather than a declared constant, and the input-output plasma box
-- that lets one run of rf-pipe feed a row of reactors from one pool (ADR 0011).
local function probe_reactor(name, consumption, max_transfer)
  local e = table.deepcopy(reactor)
  e.name = name
  e.consumption = consumption
  e.energy_source = {
    type = "electric",
    usage_priority = "secondary-input",
    buffer_capacity = "10MJ",
    input_flow_limit = "600MW",
    drain = "0W",
  }
  -- A vanilla reactor multiplies its own output when it touches another one, and two of these sit
  -- on one pipe run below. Zeroed so a measured rate is one reactor's and not the pair's.
  e.neighbour_bonus = 0
  if max_transfer then e.heat_buffer.max_transfer = max_transfer end
  e.fluid_box = {
    production_type = "input-output",
    volume = 1000,
    pipe_connections = {
      { flow_direction = "input-output", direction = defines.direction.west,
        position = { -2, 0 }, connection_category = CATEGORY },
      { flow_direction = "input-output", direction = defines.direction.east,
        position = { 2, 0 }, connection_category = CATEGORY },
    },
  }
  -- Nothing places these but the rig, so they need no item, no recipe and no upgrade path.
  e.minable = nil
  e.fast_replaceable_group = nil
  e.next_upgrade = nil
  return e
end

-- The shipped rf-reactor's own shape with a heat buffer bolted on: heat-exchanger, electric source,
-- energy_consumption neutered to 1 W. The buffer's connections are the heat exchanger's own rather
-- than the nuclear reactor's, because this entity is 3x2 and the reactor's connections sit two
-- tiles out from a centre that does not exist here.
local boiler = table.deepcopy(data.raw["boiler"]["heat-exchanger"])
boiler.name = "rf-probe-boiler"
boiler.energy_consumption = "1W"
boiler.energy_source = {
  type = "electric",
  usage_priority = "secondary-input",
  buffer_capacity = "10MJ",
  input_flow_limit = "600MW",
  drain = "0W",
}
boiler.heat_buffer = {
  max_temperature = reactor.heat_buffer.max_temperature,
  specific_heat = reactor.heat_buffer.specific_heat,
  max_transfer = reactor.heat_buffer.max_transfer,
  connections = { { position = { 0, 0.5 }, direction = defines.direction.south } },
}
boiler.minable = nil
boiler.fast_replaceable_group = nil
boiler.next_upgrade = nil

-- The same subject with the box declared under the PLURAL key. A crafting machine takes
-- fluid_boxes; a boiler takes fluid_box. Nothing in the reactor prototype's documented fields takes
-- either, so if the singular is ignored the plural has to be ruled out before a negative result is
-- worth writing down -- #44 would be decided on it.
local plural = probe_reactor("rf-probe-reactor-boxes", "1W")
plural.fluid_boxes = { plural.fluid_box }
plural.fluid_box = nil

data:extend({
  probe_reactor("rf-probe-reactor", "1W"),
  plural,
  probe_reactor("rf-probe-reactor-tight", "1W", "50MW"),
  -- 133 MW is what the shipped reactor makes at equilibrium (scripts/reactor-logic.lua). Two
  -- prototypes rather than two entities of one, because the electric statistics are kept per
  -- prototype and the cold reactor's draw has to be readable apart from the saturated one's.
  probe_reactor("rf-probe-reactor-hungry", "133MW"),
  probe_reactor("rf-probe-reactor-warm", "133MW"),
  boiler,
})
'@
    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'data.lua') -Value $data

    $lua = @'
-- Generated by scripts/probe-native-heat.ps1 (#43). Nothing here ships.
--
-- Reports findings, never a verdict. Each line is a measurement; the script that reads them only
-- insists that every row reported something.

local SOURCE = "rf-probe-reactor"
local PLURAL = "rf-probe-reactor-boxes"
local TIGHT  = "rf-probe-reactor-tight"
local HUNGRY = "rf-probe-reactor-hungry"
local WARM   = "rf-probe-reactor-warm"
local BOILER = "rf-probe-boiler"
local PLASMA = "rf-d-d-plasma"

-- What the two self-heating prototypes declare, for the report. Named here rather than read back
-- because LuaEntityPrototype publishes no `consumption`.
local DECLARED_CONSUMPTION = "133MW"
-- Roughly where the shipped reactor settles, so the seeded plasma is the plasma the mod really has.
local SEED_C  = 6e8
-- control.lua's UPDATE_INTERVAL.
local CADENCE = 6
-- Three pipes rather than one on every short run, so a heat consumer can be attached to the middle
-- of it without overlapping the source -- and so `deliver` and `run` differ only in length.
local SHORT   = 3
local WARMUP  = __WARMUP__
local WINDOW  = __WINDOW__

-- Findings accumulate in `storage`, not in a file-scope table, and that is not tidiness. The rig is
-- built by --create in one process and measured by --benchmark in another, which LOADS the save: the
-- first version kept its lines in a local, so everything on_init found -- including the answer to
-- the first acceptance criterion -- was thrown away with the process that found it, and the report
-- said only "not built".
local function say(fmt, ...)
  storage.notes = storage.notes or {}
  storage.notes[#storage.notes + 1] = string.format(fmt, ...)
end

local function must(entity, what)
  if not entity then error(what .. " refused") end
  return entity
end

-- Directions as unit vectors. A heat connection gives the tile INSIDE the entity plus the face it
-- points out of, so the neighbour tile is one step that way -- unlike a fluid connection, which
-- hands over its target_position ready made.
local UNIT = {
  [defines.direction.north] = { x = 0,  y = -1 },
  [defines.direction.east]  = { x = 1,  y = 0 },
  [defines.direction.south] = { x = 0,  y = 1 },
  [defines.direction.west]  = { x = -1, y = 0 },
}

local function buffer_of(name)
  local p = prototypes.entity[name]
  return p and p.heat_buffer_prototype or nil
end

--- A position as two numbers, whichever of the two shapes it arrives in.
--
-- Not defensive: a heat connection read back off a loaded prototype hands over its position as the
-- ARRAY it was written as, {2, 0}, where a fluid connection's target_position comes back as
-- {x = 3.5, y = 0.5}. Assuming the second shape for both is how the first version of this rig died,
-- three lines into its first row.
local function xy(p)
  if p.x then return p.x, p.y end
  return p[1], p[2]
end

--- The tile a heat connection facing `direction` reaches, for an entity placed facing north.
--
-- North only, and asserted rather than assumed: rotating a connection is four more lines and one
-- more thing to get wrong, and nothing here needs a rotated source.
--
-- The MIDDLE connection on that face, not the first one found. A nuclear reactor declares three
-- connections per side and pairs iterates them in whatever order it likes, so picking the first
-- would put the pipe run on a corner on one run and on the centre on the next.
local function heat_tile(entity, direction)
  local buffer = buffer_of(entity.name)
  if not buffer then return nil end
  if entity.direction ~= defines.direction.north then
    error(entity.name .. " is not facing north; heat_tile does not rotate")
  end
  local u = UNIT[direction]
  local best
  for _, c in pairs(buffer.connections) do
    if c.direction == direction then
      local cx, cy = xy(c.position)
      -- Distance from the middle of the face: the offset along it, which is the coordinate the
      -- direction does not run in.
      local along = math.abs(u.x == 0 and cx or cy)
      if not best or along < best.along then best = { along = along, x = cx, y = cy } end
    end
  end
  if not best then return nil end
  return { x = entity.position.x + best.x + u.x, y = entity.position.y + best.y + u.y }
end

local function status_name(value)
  for name, v in pairs(defines.entity_status) do
    if v == value then return name end
  end
  return tostring(value)
end

-- A substation and an electric energy interface. `at` is the substation's centre and must be whole:
-- a 2x2 entity sits on a tile boundary where the interface beside it sits on a tile centre, and
-- create_entity would snap a half-tile position rather than refuse it.
--
-- The substation is handed back because the network's own statistics hang off a POLE and nothing
-- else: reading electric_network_statistics on the reactor throws "Entity is not electric-pole".
local function power(surface, force, at, watts)
  if at[1] % 1 ~= 0 or at[2] % 1 ~= 0 then
    error(string.format("power() wants a whole-number position, got (%g, %g)", at[1], at[2]))
  end
  local pole = must(surface.create_entity({ name = "substation", position = at, force = force }),
    "substation")
  local eei = must(surface.create_entity({
    name = "electric-energy-interface", position = { at[1] + 2.5, at[2] + 0.5 }, force = force,
  }), "power source")
  eei.power_production = watts
  return pole
end

--- Lay `length` vanilla heat pipes from `from` in `direction`. Returns every tile used and the
-- empty tile after the last, which is where the sink goes.
local function lay_heat_pipe(surface, force, from, direction, length)
  local u = UNIT[direction]
  local at = { x = from.x, y = from.y }
  local tiles = {}
  for i = 1, length do
    must(surface.create_entity({ name = "heat-pipe", position = at, force = force }),
      string.format("heat pipe %d of %d", i, length))
    tiles[#tiles + 1] = at
    at = { x = at.x + u.x, y = at.y + u.y }
  end
  return tiles, at
end

--- A heat-interface held at 0 C: everything the run can deliver is absorbed, and the far end of the
-- run stays cold. The largest gradient the engine can be shown, which is why every throughput
-- number this rig prints is best case and is labelled as one.
local function sink(surface, force, at)
  local s = must(surface.create_entity({ name = "heat-interface", position = at, force = force }),
    "heat sink")
  -- set_heat_setting rather than a heat_setting attribute: LuaEntity has the pair of getters in
  -- 2.0.77 and writing the field throws "LuaEntity doesn't contain key heat_setting". The same trap
  -- control.lua's check_steam_sinks hit with get_max_energy_production, found the same way.
  s.set_heat_setting({ temperature = 0, mode = "at-most" })
  return s
end

--- An infinity pipe against every connection of a fluid box: unbounded supply, or unbounded
-- disposal. bench-mod-links.ps1 does the same, so that nothing outside the thing under test can be
-- the limit.
local function unbound(surface, force, entity, index, filter)
  local attached = 0
  for _, connection in pairs(entity.fluidbox.get_pipe_connections(index)) do
    local pipe = surface.create_entity({
      name = "infinity-pipe", position = connection.target_position, force = force,
    })
    if pipe then
      pipe.set_infinity_pipe_filter(filter)
      attached = attached + 1
    end
  end
  if attached == 0 then
    error(string.format("could not attach any infinity pipe to %s box %d", entity.name, index))
  end
end

local function box_of(entity, fluid)
  for index = 1, #entity.fluidbox do
    local filter = entity.fluidbox.get_filter(index)
    if filter and filter.name == fluid then return index end
  end
  return nil
end

-- ---------------------------------------------------------------- the pooling row

--- Two probe reactors on a run of rf-pipe, and nothing else. Returns nil when the reactor turns out
-- to have no fluid box, which is itself the answer to the first acceptance criterion.
local function build_pool(surface, force, y)
  local west = must(surface.create_entity({
    name = SOURCE, position = { 0.5, y + 0.5 }, force = force,
  }), "pooling reactor (west)")

  -- Both spellings, because a negative here decides #44 and "I used the wrong key" is the one way a
  -- negative could be wrong. fluid_box is what a boiler takes and fluid_boxes what a crafting
  -- machine takes; the reactor prototype documents neither.
  local plural = must(surface.create_entity({
    name = PLURAL, position = { 20.5, y + 0.5 }, force = force,
  }), "pooling reactor (plural key)")
  say("pool: %s declares fluid_box and has %d fluid box(es) at runtime", SOURCE, #west.fluidbox)
  say("pool: %s declares fluid_boxes and has %d", PLURAL, #plural.fluidbox)
  plural.destroy()

  if #west.fluidbox == 0 then
    say("pool: so the declared box was accepted by the data stage and ignored by the engine --")
    say("pool: a reactor prototype cannot hold plasma, let alone share a pool of it")
    return nil
  end

  -- The east connection, found by asking rather than by arithmetic: where a connection sits belongs
  -- to the prototype, and a remembered offset is exactly what went stale in #49.
  local east_target
  for _, c in pairs(west.fluidbox.get_pipe_connections(1)) do
    if c.target_position.x > west.position.x then east_target = c.target_position end
  end
  if not east_target then
    say("pool: the reactor's box has no connection facing east; nothing to run a pipe along")
    return nil
  end

  local last
  local at = { x = east_target.x, y = east_target.y }
  for i = 1, SHORT do
    must(surface.create_entity({ name = "rf-pipe", position = at, force = force }),
      string.format("rf-pipe %d", i))
    last = at
    at = { x = at.x + 1, y = at.y }
  end

  -- Placed once, asked where its west connection actually points, then moved by the difference so
  -- that the connection lands on the last pipe of the run.
  local probe = must(surface.create_entity({
    name = SOURCE, position = { at.x + 4, y + 0.5 }, force = force,
  }), "pooling reactor (east, probe)")
  local west_connection
  for _, c in pairs(probe.fluidbox.get_pipe_connections(1)) do
    if c.target_position.x < probe.position.x then west_connection = c end
  end
  if not west_connection then error("the probe reactor has no connection facing west") end
  local position = {
    probe.position.x + (last.x - west_connection.target_position.x),
    probe.position.y,
  }
  probe.destroy()
  local east = must(surface.create_entity({ name = SOURCE, position = position, force = force }),
    "pooling reactor (east)")

  return { west = west, east = east, volume = prototypes.entity[SOURCE].fluidbox_prototypes[1].volume }
end

-- ---------------------------------------------------------------- the heat rows

--- A source, a run of heat pipe on each requested face, and a sink at the end of each. Every row in
-- this rig that involves heat is one call to this.
local function build_heat_row(surface, force, label, opts)
  local source = must(surface.create_entity({
    name = opts.source, position = opts.at, force = force,
  }), label .. " source")
  power(surface, force, opts.power_at, opts.watts or 4e6)

  local buffer = buffer_of(opts.source)
  if not buffer then
    say("%s: %s has NO heat buffer at runtime -- the heat_buffer field was accepted by the data " ..
      "stage and ignored by the engine, so this prototype cannot emit heat at all", label, opts.source)
    return nil
  end

  local row = {
    label = label, source = source, sinks = {}, pipes = opts.pipes, runs = {},
    specific_heat = buffer.specific_heat, pin_c = buffer.max_temperature,
    cadence = opts.cadence or 1, injected = 0, writes = 0, coldest = math.huge,
  }

  for _, direction in ipairs(opts.faces) do
    local from = heat_tile(source, direction)
    if not from then
      say("%s: the buffer declares no connection facing %d, so that face is not probed",
        label, direction)
    else
      local tiles, after = lay_heat_pipe(surface, force, from, direction, opts.pipes)
      row.runs[#row.runs + 1] = tiles
      -- No sink on the consumer row, and that is the whole point of having two rows. A
      -- heat-interface held at 0 C drains the run faster than it can fill, so the pipe beside the
      -- source sits near a hundred degrees -- measured -- and a vanilla heat exchanger will not run
      -- below five hundred. The greedy sink measures what a pipe CARRIES; it cannot also be present
      -- while measuring what a machine TAKES.
      if opts.sink ~= false then
        row.sinks[#row.sinks + 1] = sink(surface, force, after)
      end
    end
  end

  return row
end

--- The one real consumer in the rig: a vanilla heat exchanger on a pipe of an existing run, fed
-- water and voiding its steam. The sink answers how much arrives; this answers whether a machine
-- that burns heat runs off it.
--
-- Placed by subtracting its own heat connection from the pipe tile it has to reach, which is the
-- same place-and-ask rule the fluid rows use: where a connection sits belongs to the prototype.
local function attach_exchanger(surface, force, row, tile)
  local connection = prototypes.entity["heat-exchanger"].heat_energy_source_prototype.connections[1]
  local u = UNIT[connection.direction]
  local cx, cy = xy(connection.position)
  local exchanger = must(surface.create_entity({
    name = "heat-exchanger",
    position = { tile.x - cx - u.x, tile.y - cy - u.y },
    force = force,
  }), row.label .. " heat exchanger")
  unbound(surface, force, exchanger, box_of(exchanger, "water"),
    { name = "water", percentage = 1, mode = "at-least" })
  unbound(surface, force, exchanger, box_of(exchanger, "steam"),
    { name = "steam", percentage = 0, mode = "at-most" })
  row.exchanger = exchanger
  -- The pipe it was placed against, kept so the report can say what temperature was on offer.
  row.pipe_probe = surface.find_entity("heat-pipe", tile)
end

-- ---------------------------------------------------------------- build

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player
  force.research_all_technologies()

  surface.request_to_generate_chunks({ 20, 120 }, 12)
  surface.force_generate_chunk_requests()
  local tiles = {}
  for x = -30, 70 do
    for y = -12, 260 do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = { { -30, -12 }, { 70, 260 } } })) do
    if e.type ~= "character" then e.destroy() end
  end

  storage.pool = build_pool(surface, force, 0)

  local east, west, south = defines.direction.east, defines.direction.west, defines.direction.south
  storage.rows = {}
  local function add(row)
    if row then storage.rows[#storage.rows + 1] = row end
    return row
  end

  add(build_heat_row(surface, force, "deliver", {
    source = SOURCE, at = { 0.5, 40.5 }, power_at = { 0, 34 },
    faces = { east }, pipes = SHORT,
  }))
  -- The real consumer, on a run with no sink on the end of it. The exchanger goes on the middle
  -- pipe, which is clear of the source's own footprint.
  local consumer = add(build_heat_row(surface, force, "consumer", {
    source = SOURCE, at = { 40.5, 40.5 }, power_at = { 40, 34 },
    faces = { east }, pipes = SHORT, sink = false,
  }))
  if consumer and consumer.runs[1] then
    attach_exchanger(surface, force, consumer, consumer.runs[1][2])
  end

  add(build_heat_row(surface, force, "cadence", {
    source = SOURCE, at = { 0.5, 80.5 }, power_at = { 0, 74 },
    faces = { east }, pipes = SHORT, cadence = CADENCE,
  }))
  add(build_heat_row(surface, force, "run", {
    source = SOURCE, at = { 0.5, 120.5 }, power_at = { 0, 114 },
    faces = { east }, pipes = 24,
  }))
  add(build_heat_row(surface, force, "tight", {
    source = TIGHT, at = { 0.5, 160.5 }, power_at = { 0, 154 },
    faces = { east, west }, pipes = SHORT,
  }))
  add(build_heat_row(surface, force, "boiler", {
    source = BOILER, at = { 0.5, 240 }, power_at = { 0, 234 },
    faces = { south }, pipes = SHORT,
  }))

  -- The self-heating pair. No pipes, no sink and no Lua writes: what is being measured is whether a
  -- reactor with an electric energy source converts electricity into heat on its own.
  storage.self_cold = must(surface.create_entity({
    name = HUNGRY, position = { 0.5, 200.5 }, force = force }), "self-heating reactor (cold)")
  storage.self_warm = must(surface.create_entity({
    name = WARM, position = { 20.5, 200.5 }, force = force }), "self-heating reactor (warm)")
  -- One pole each, twenty tiles apart: a substation reaches eighteen, so these are two networks and
  -- each pole's statistics are its own reactor's alone.
  storage.cold_pole = power(surface, force, { 0, 194 }, 1e9)
  storage.warm_pole = power(surface, force, { 20, 194 }, 1e9)

  log(string.format("HEAT-PROBE-BUILT pool=%s rows=%d", tostring(storage.pool ~= nil), #storage.rows))
end)

-- ---------------------------------------------------------------- run

local function report()
  -- Everything already in the list was found while building, in the other process. Given a heading
  -- of its own so the report reads in the order the work happened.
  local built = storage.notes or {}
  storage.notes = { "== what building the rig found ==" }
  for _, line in ipairs(built) do storage.notes[#storage.notes + 1] = line end

  say("== prototype numbers, read from the loaded prototypes ==")
  say("%-24s %-18s %13s %13s %11s %8s %6s", "prototype", "kind", "specific_heat",
    "max_transfer", "x60 as MW", "max C", "conns")
  for _, name in ipairs({ "nuclear-reactor", "heat-pipe", "heat-exchanger", "heat-interface",
                          SOURCE, PLURAL, TIGHT, HUNGRY, BOILER }) do
    local p = prototypes.entity[name]
    if not p then
      say("%-24s missing", name)
    else
      -- The energy source is asked FIRST, and the order is the finding. A heat CONSUMER answers
      -- heat_buffer_prototype too -- vanilla heat-exchanger hands back its energy source's buffer --
      -- so asking that first labels the one machine in the game that burns heat as a machine that
      -- emits it, which is exactly backwards for a decision about what can be a heat source.
      local kind, b = "heat energy source", p.heat_energy_source_prototype
      if not b then
        kind, b = "heat buffer", p.heat_buffer_prototype
      end
      if not b then
        say("%-24s neither a heat buffer nor a heat energy source", name)
      else
        -- max_transfer is printed raw AND multiplied by 60. The runtime API publishes no unit for
        -- it; the prototype it came from said "1GW" for the heat pipe, so whichever of the two
        -- columns reads 1e9 is the one in watts and the other is joules per tick.
        say("%-24s %-18s %13.5g %13.5g %11.5g %8g %6d", name, kind,
          b.specific_heat, b.max_transfer, b.max_transfer * 60 / 1e6, b.max_temperature,
          #b.connections)
      end
    end
  end

  -- What can emit heat at all in the loaded set, by prototype type. Cheap, and it is the shape of
  -- the design space #44 has to choose inside: a type that carries no heat buffer is not a
  -- candidate however convenient its other fields are.
  say("== what can carry heat at all, across everything loaded ==")
  local emitters, consumers = {}, {}
  for name, p in pairs(prototypes.entity) do
    -- Consumer first, for the reason the table above states: a machine that burns heat also answers
    -- heat_buffer_prototype, so the two tests are not independent and the order decides the answer.
    if p.heat_energy_source_prototype then
      consumers[#consumers + 1] = string.format("%s (%s)", name, p.type)
    elseif p.heat_buffer_prototype then
      emitters[#emitters + 1] = string.format("%s (%s)", name, p.type)
    end
  end
  table.sort(emitters)
  table.sort(consumers)
  say("holds or emits heat: %s", #emitters > 0 and table.concat(emitters, ", ") or "nothing")
  say("burns heat:          %s", #consumers > 0 and table.concat(consumers, ", ") or "nothing")

  say("== pool: does a reactor's fluid box join a segment (AC 1) ==")
  local pool = storage.pool
  if not pool then
    say("pool: not built -- see the lines above")
  else
    local w, e = pool.west.fluidbox[1], pool.east.fluidbox[1]
    say("pool: box volume %g each, seeded WEST only for the first 60 ticks at %.3g C",
      pool.volume, SEED_C)
    say("pool: west holds %s",
      w and string.format("%.5g units at %.5g C", w.amount, w.temperature) or "nothing")
    say("pool: east holds %s",
      e and string.format("%.5g units at %.5g C", e.amount, e.temperature) or "nothing")
    local wid = pool.west.fluidbox.get_fluid_segment_id(1)
    local eid = pool.east.fluidbox.get_fluid_segment_id(1)
    say("pool: segment ids %s and %s -- %s", tostring(wid), tostring(eid),
      (wid and wid == eid) and "ONE SEGMENT" or "NOT the same segment")
    if w and e then
      say("pool: temperatures %.4g%% apart, amounts %.4g%% apart",
        math.abs(w.temperature - e.temperature) / math.max(w.temperature, e.temperature) * 100,
        math.abs(w.amount - e.amount) / math.max(w.amount, e.amount) * 100)
    end
  end

  say("== heat delivery, measured at the source over %d ticks (AC 2, AC 5) ==", WINDOW)
  say("%-9s %6s %6s %6s %7s %14s %11s %13s", "row", "pipes", "sinks", "every", "writes",
    "injected J", "coldest C", "delivered MW")
  for _, row in ipairs(storage.rows) do
    say("%-9s %6d %6d %6d %7d %14.5g %11.5g %13.5g", row.label, row.pipes, #row.sinks, row.cadence,
      row.writes, row.injected, row.coldest == math.huge and -1 or row.coldest,
      row.injected / WINDOW * 60 / 1e6)
  end
  -- A Lua write, read straight back. Everything above rests on a written temperature being the
  -- temperature the entity then has, and that is worth one line of evidence rather than an
  -- assumption: a write that were clamped by max_transfer, or applied on the next tick, would make
  -- every rate above a measurement of the clamp instead of the pipe.
  local first = storage.rows[1]
  if first then
    local before = first.source.temperature
    first.source.temperature = 500
    local readback = first.source.temperature
    first.source.temperature = before
    say("write: set 500 C on a buffer holding %.6g C and read back %.6g C, then restored to %.6g C",
      before, readback, first.source.temperature)
  end

  for _, row in ipairs(storage.rows) do
    if row.exchanger then
      say("%s: the vanilla heat exchanger on the pipe reports %s",
        row.label, status_name(row.exchanger.status))
      -- Enough to tell "the consumer will not run off this heat" from "the rig put it in the wrong
      -- place", which look identical in a status of low_temperature.
      local e = row.exchanger
      say("%s: it sits at (%g, %g) holding %.5g C, against the pipe beside it at %.5g C",
        row.label, e.position.x, e.position.y, e.temperature,
        row.pipe_probe and row.pipe_probe.valid and row.pipe_probe.temperature or -1)
      local held = {}
      for index = 1, #e.fluidbox do
        local contents = e.fluidbox[index]
        held[#held + 1] = contents
          and string.format("%s %.4g", contents.name, contents.amount) or "empty"
      end
      say("%s: its boxes hold %s", row.label, table.concat(held, ", "))
      -- Against its own declared draw rather than against a steam figure converted by hand. The
      -- first version of this line multiplied the fluid statistics by steam's heat capacity and
      -- reported 36 GW through a 10 MW machine, because get_flow_count's unit is not units per tick
      -- and the arithmetic never had to agree with anything to look plausible. This comparison
      -- cannot go wrong quietly: both numbers are in watts and one of them is the prototype's.
      say("%s: it declares a draw of %.5g MW, against the %.5g MW the source gave up",
        row.label, prototypes.entity["heat-exchanger"].get_max_energy_usage() * 60 / 1e6,
        row.injected / WINDOW * 60 / 1e6)
    end
  end

  say("== self-heating: is `consumption` spent with no Lua at all (AC 3) ==")
  for _, probe in ipairs({ { "cold", storage.self_cold, storage.cold_start, storage.cold_pole },
                           { "warm", storage.self_warm, storage.warm_start, storage.warm_pole } }) do
    local label, entity, started, pole = probe[1], probe[2], probe[3], probe[4]
    local buffer = buffer_of(entity.name)
    local now = entity.temperature
    say("self/%s: %s declares consumption %s and no Lua touched it",
      label, entity.name, DECLARED_CONSUMPTION)
    say("self/%s: %.5g C -> %.5g C across the window, which is %.5g MW into its own buffer",
      label, started, now, (now - started) * buffer.specific_heat / WINDOW * 60 / 1e6)
    local stats = pole and pole.valid and pole.electric_network_statistics
    if not stats then
      say("self/%s: no pole to read a network off, so nothing can be said about its draw", label)
    else
      local flow = function(name, category)
        return stats.get_flow_count({ name = name, category = category,
          precision_index = defines.flow_precision_index.five_seconds }) * 60 / 1e6
      end
      -- Both categories, for the reactor AND for the interface feeding it. The runtime API names
      -- them "input" and "output" without saying whose side of the wire it means, and the interface
      -- is the one entity here whose direction is not in doubt -- it can only produce -- so whichever
      -- column reads non-zero for it is the production column for both.
      --
      -- Five seconds, not a minute: the whole run is shorter than a minute, so the longer average
      -- divides the real draw by however much of the window had not happened yet.
      say("self/%s: network %s, MW over the last five seconds:",
        label, tostring(pole.electric_network_id))
      for _, name in ipairs({ entity.name, "electric-energy-interface" }) do
        say("self/%s:   %-28s input %9.5g   output %9.5g", label, name,
          flow(name, "input"), flow(name, "output"))
      end
      say("self/%s: status %s, holding %.5g J of a %.5g J electric buffer",
        label, status_name(entity.status), entity.energy, entity.electric_buffer_size)
    end
  end

  say("done: %d heat rows, pool %s", #storage.rows, storage.pool and "built" or "not built")
  for _, line in ipairs(storage.notes) do log("HEAT-PROBE " .. line) end
end

script.on_event(defines.events.on_tick, function(event)
  local tick = event.tick

  -- Seeded for sixty ticks rather than once. A segment seeded box by box in a single pass keeps
  -- only about 45% of what was written (scripts/check-pooling.ps1, #73), and this row asks whether
  -- plasma crosses at all -- not how much of a write survives.
  if storage.pool and tick <= 60 then
    storage.pool.west.fluidbox[1] = {
      name = PLASMA, amount = storage.pool.volume, temperature = SEED_C,
    }
  end

  -- The saturated half of the self-heating pair is put near its ceiling once and never touched
  -- again: 133 MW into a 10 MJ/C buffer climbs 8 C a second, so a reactor starting cold cannot
  -- reach its ceiling inside a run this length and what it does AT the ceiling would go unanswered.
  if tick == 1 then storage.self_warm.temperature = 990 end

  if tick == WARMUP then
    storage.cold_start = storage.self_cold.temperature
    storage.warm_start = storage.self_warm.temperature
  end

  local measuring = tick > WARMUP and tick <= WARMUP + WINDOW
  for _, row in ipairs(storage.rows or {}) do
    if tick % row.cadence == 0 then
      local seen = row.source.temperature
      if measuring then
        local deficit = row.pin_c - seen
        if deficit > 0 then row.injected = row.injected + deficit * row.specific_heat end
        row.writes = row.writes + 1
        if seen < row.coldest then row.coldest = seen end
      end
      row.source.temperature = row.pin_c
    end
  end

  if tick == WARMUP + WINDOW then report() end
end)
'@

    $lua = $lua.Replace('__WARMUP__', "$Warmup").Replace('__WINDOW__', "$Window")
    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') -Value $lua
}

$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled @() -Mods ($ourMods + $rigName)
    Write-Rig

    $save = Join-Path $temp 'heat-probe.zip'
    Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create' | Out-Null
    $runOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', "$($Warmup + $Window + 10)",
        '--benchmark-runs', '1', '--disable-audio')

    $reported = @(Get-Content $runOut | Select-String -Pattern 'HEAT-PROBE ' |
        ForEach-Object { ($_ -split 'HEAT-PROBE ', 2)[1].TrimEnd() })
    if ($reported.Count -eq 0) { throw 'the rig reported nothing; it never reached its report tick.' }

    foreach ($line in $reported) { Write-Host "  $line" }

    if (-not ($reported | Where-Object { $_ -match '^done: ' })) {
        throw 'the rig never reached its report tick; the findings above are incomplete.'
    }

    Write-Host ''
    Write-Host 'OK - the probe ran and every row reported. The answers are above, and they are'
    Write-Host '     evidence for #44 rather than a verdict, so nothing here passes or fails.'
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'probe-native-heat' }
}

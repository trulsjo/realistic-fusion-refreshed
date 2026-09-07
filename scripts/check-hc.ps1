<#
.SYNOPSIS
    Checks that the high-capacity steam pair delivers what it declares, and that it is ten times the
    ordinary pair measured rather than asserted. Discharges #32. Since #275 it also builds the
    neutronic plant the way a player does -- exchangers BOLTED to a reactor and CHAINED to each other,
    no pipe carrying reactor energy -- and asserts that energy, water and steam all arrive.

.DESCRIPTION
    THE FAILURE THIS RIG EXISTS FOR is silent and is one field wide.

    A generator's real output is fluid_usage_per_tick x 60 x (maximum_temperature -
    default_temperature) x heat_capacity x effectivity. `max_power_output` is a SEPARATE field.
    Multiply the fluid usage by ten and leave max_power_output alone and the machine eats ten times
    the steam for the same power -- for ever, with no error, no status change and a tooltip that
    reads correctly. Vanilla's steam turbine sidesteps it by declaring no max_power_output at all and
    letting the engine derive one; this repository pins every stat that affects balance, so it
    declares one and has to prove the two agree.

    So the arithmetic is checked against the prototypes AND the machines are measured running. The
    first would pass on a mod that never worked; the second would pass on a lucky cancellation.

    WHAT IS BUILT

      turbines    An rf-hc-turbine and a vanilla steam-turbine, each on its own infinity pipe of
                  500 C steam, on one electric network with a load large enough that neither is
                  throttled by demand. Production is read per prototype out of the network's own
                  statistics, so the two are separated without isolating them.
      exchangers  An rf-hc-exchanger and an rf-heat-exchanger, each fed water and reactor energy by
                  infinity pipes, with their steam drained and totalled every tick. Draining is what
                  makes the measurement mean anything: both fill their output box in under a second,
                  so reading the box at the end compares two saturated buffers.
      chain       An rf-hc-exchanger with an rf-hc-turbine directly on its steam outlet and nothing
                  between them, which is the pair as a player builds it. It must produce power from
                  real exchanger steam rather than from an infinity pipe.
      plant       The neutronic side as ADR 0031 says a player builds it (#275): an rf-reactor, an
                  rf-heat-exchanger BOLTED flush onto its south face with no pipe between them, a
                  second exchanger CHAINED off the first's short end, an rf-hc-turbine on each
                  exchanger's steam outlet, and ONE water feed at the row's free end. Energy has to
                  reach the second machine through two bolted joints and water through one. Every
                  position is computed from the prototypes' own connection geometry, so a moved
                  connection fails this rather than silently building a different plant. The
                  reactor is not lit -- its output box is refilled by script every tick, the way
                  probe-energy-containment.ps1's bolt rows do -- because this asks about the joints
                  and check-d-t.ps1 owns ignition. A control exchanger joined to nothing must hold
                  no energy.

    The technology gate and the prerequisite closure are checked off the force's own tables before
    anything is researched.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Ticks
    Ticks to run before checking.

.PARAMETER Quality
    Also enable Wube's bundled Quality mod and report what quality does to the pair. ADR 0003
    tolerates Space Age rather than targeting it, so the default run is base-only like every other
    rig here; this switch exists because the predecessor's author warned that "certain buildings in
    this mod get insanely overpowered with quality" without naming them, and rfp-hc-turbine is the
    obvious suspect. Reported rather than asserted -- see the note in the rig.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/check-hc.ps1
    pwsh -File scripts/check-hc.ps1 -Quality
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [ValidateRange(600, 200000)] [int] $Ticks = 3600,
    [switch] $Quality,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$rigName  = 'rf-hc-rig'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-hc-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

function Write-Rig {
    @{
        name = $rigName; version = '0.0.1'; title = 'High-capacity generation check'
        author = 'check-hc.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed', 'realistic-fusion-refreshed-core')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

    $lua = @'
-- Generated by scripts/check-hc.ps1. Nothing here ships.

local CHECK_AT = __TICKS__
local WITH_QUALITY = __QUALITY__

local HC_EXCHANGER = "rf-hc-exchanger"
local HC_TURBINE   = "rf-hc-turbine"
local EXCHANGER    = "rf-heat-exchanger"
local TURBINE      = "steam-turbine"
local ENERGY       = "rf-reactor-energy"
-- Write-EnergyFeed's prototype. It carries BOTH energy categories since #86 -- read off the two
-- shipped reactors' output boxes -- because a vanilla infinity pipe stopped being able to reach an
-- energy box the moment ADR 0018 landed. #84 routed every rig through that one function so this
-- would be an edit there rather than here.
local ENERGY_FEED  = "__ENERGYFEED__"

local function record(ok, name, detail)
  storage.report = storage.report or { lines = {}, failures = 0 }
  if not ok then storage.report.failures = storage.report.failures + 1 end
  storage.report.lines[#storage.report.lines + 1] = string.format("%s  %s%s",
    ok and "ok  " or "FAIL", name, detail and ("  -- " .. detail) or "")
end

--- Reported without a pass or fail, for facts that are worth having on the record but are not this
--- ticket's to bound -- see the quality section.
local function note(name, detail)
  storage.report = storage.report or { lines = {}, failures = 0 }
  storage.report.lines[#storage.report.lines + 1] = string.format("note  %s  -- %s", name, detail)
end

local function near(actual, expected, tolerance, name, unit)
  local ok = expected ~= 0 and math.abs(actual - expected) / math.abs(expected) <= tolerance
  record(ok, name, string.format("%.6g against %.6g %s (%.2f%%)",
    actual, expected, unit or "", expected ~= 0 and 100 * math.abs(actual - expected) / math.abs(expected) or 0))
end

local function must(entity, what)
  if not entity then error(what .. " refused") end
  return entity
end

local function box_of(entity, fluid)
  for index = 1, #entity.fluidbox do
    local filter = entity.fluidbox.get_filter(index)
    if filter and filter.name == fluid then return index end
  end
  return nil
end

--- Feed every connection of the box carrying `fluid` from an infinity pipe, so the machine is never
--- limited by what is upstream of it -- which is the whole point: this rig measures the machine.
local function feed(surface, force, entity, fluid, temperature)
  local index = box_of(entity, fluid)
  if not index then error(entity.name .. " has no box that takes " .. fluid) end
  for _, connection in pairs(entity.fluidbox.get_pipe_connections(index)) do
    local supply = must(surface.create_entity({
      -- Energy comes from the shared feed, water and steam from a vanilla pipe. They were the same
      -- entity until #86 contained reactor energy; a vanilla one cannot reach an energy box now.
      name = (fluid == ENERGY) and ENERGY_FEED or "infinity-pipe",
      position = connection.target_position, force = force,
    }), "supply of " .. fluid .. " for " .. entity.name)
    supply.set_infinity_pipe_filter({
      name = fluid, percentage = 1, temperature = temperature, mode = "at-least",
    })
  end
  return index
end

--- Every infinity pipe standing in `area`, WHATEVER PROTOTYPE IT IS.
---
--- BY TYPE AND NOT BY NAME, and the difference is whether the tally below can fail at all. Energy
--- is fed in this repository by Write-EnergyFeed's own prototype, `rf-rig-energy-infinity-pipe`
--- (factorio-lib.ps1), which is a deepcopy of the vanilla pipe under a name of its own -- so a
--- filter on the NAME `infinity-pipe` cannot see an energy feed, and "no pipe carries reactor
--- energy" would have been true by construction rather than measured. The plant section has no
--- self-test half of its own, so a check that cannot fail there is a check that says nothing.
local function surface_pipes(area)
  return game.surfaces[1].find_entities_filtered({ type = "infinity-pipe", area = area })
end

--- A substation and a load. The load matters: a generator with nothing drawing from it throttles
--- itself back, so measuring output against an idle network measures the network.
local function power(surface, force, at, draw)
  local pole = must(surface.create_entity({
    name = "substation", position = at, force = force,
  }), "substation")
  local eei = must(surface.create_entity({
    name = "electric-energy-interface", position = { at[1] + 2.5, at[2] + 0.5 }, force = force,
  }), "load")
  eei.power_production = 0
  eei.power_usage = draw
  return pole
end

--- Which way a runtime connection faces, read off the tile it targets rather than remembered.
local function facing(connection)
  local dx = connection.target_position.x - connection.position.x
  local dy = connection.target_position.y - connection.position.y
  if dy < 0 then return "north" elseif dy > 0 then return "south" elseif dx < 0 then return "west" end
  return "east"
end

--- Place `name` so that its connection on the box filtered to `fluid`, facing `side`, STANDS ON
--- `tile` -- which is the other machine's target_position. That is the bolt arithmetic ADR 0018's
--- Consequences call a trap: a pipe run aligns a connection's target onto the pipe's tile, a bolt
--- aligns one machine's connection TILE onto the other's target. Align target against target and
--- the two sit one tile clear pointing at the same empty ground, indistinguishable from a refusal.
---
--- The machine is placed once as a probe at `seed`, asked where that connection is relative to
--- itself, destroyed, and placed again by the difference -- bench-mod-links.ps1's place_facing,
--- for the same reason (#49): a remembered offset is a hostage to the next prototype edit.
local function bolt(surface, force, name, fluid, side, tile, seed)
  local probe = must(surface.create_entity({ name = name, position = seed, force = force }), "probe " .. name)
  local index = box_of(probe, fluid)
  if not index then error(name .. " has no box filtered to " .. fluid) end
  local found
  for _, c in pairs(probe.fluidbox.get_pipe_connections(index)) do
    if facing(c) == side then found = c end
  end
  if not found then error(name .. " has no " .. side .. "-facing " .. fluid .. " connection") end
  local off = { x = found.position.x - probe.position.x, y = found.position.y - probe.position.y }
  probe.destroy()
  return must(surface.create_entity({
    name = name, position = { tile.x - off.x, tile.y - off.y }, force = force,
  }), name .. " bolted at " .. (tile.x - off.x) .. "," .. (tile.y - off.y))
end

--- The connection of `entity`'s box on `fluid` that faces `side`, or nil.
local function connection_facing(entity, fluid, side)
  for _, c in pairs(entity.fluidbox.get_pipe_connections(box_of(entity, fluid))) do
    if facing(c) == side then return c end
  end
  return nil
end

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player

  -- ------------------------------------------------------------------ the technology gate
  local fusion = force.technologies["rf-d-t-fusion"]
  record(fusion ~= nil, "rf-d-t-fusion exists to unlock the pair")
  for _, recipe in ipairs({ HC_EXCHANGER, HC_TURBINE }) do
    record(not force.recipes[recipe].enabled, recipe .. " is locked until it is researched")
  end

  -- The prerequisite closure, the way scripts/check-blanket.ps1 enforces it for the blanket: every
  -- item these recipes consume has to be craftable inside rf-d-t-fusion's OWN prerequisites, or a
  -- player researches the tier and cannot build it.
  local function research_closure(name, seen)
    if seen[name] then return end
    seen[name] = true
    local tech = force.technologies[name]
    if not tech then return end
    for prerequisite in pairs(tech.prerequisites) do research_closure(prerequisite, seen) end
    tech.researched = true
  end
  research_closure("rf-d-t-fusion", {})

  local outside, checked = {}, 0
  for _, machine in ipairs({ HC_EXCHANGER, HC_TURBINE }) do
    for _, ingredient in pairs(prototypes.recipe[machine].ingredients) do
      local recipe = force.recipes[ingredient.name]
      if recipe then
        checked = checked + 1
        if not recipe.enabled then
          outside[#outside + 1] = machine .. " needs " .. ingredient.name
        end
      end
    end
  end
  record(#outside == 0, "both recipes are craftable inside rf-d-t-fusion's own prerequisites",
    #outside == 0 and string.format("%d ingredients checked", checked)
      or table.concat(outside, "; "))
  -- The count, because a closure check that matched nothing would pass in silence. Both recipes
  -- take four ingredients and every one of them is an item named after its own recipe.
  record(checked == 8, "and it looked at all eight ingredients", string.format("%d checked", checked))

  force.research_all_technologies()

  surface.request_to_generate_chunks({ 0, 0 }, 10)
  surface.force_generate_chunk_requests()
  local tiles = {}
  for x = -40, 150 do
    for y = -30, 70 do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = { { -40, -30 }, { 150, 70 } } })) do
    if e.type ~= "character" then e.destroy() end
  end

  -- ------------------------------------------------------------------ the two turbines
  --
  -- On ONE network on purpose. Production is attributed per prototype by the game's own statistics,
  -- so putting them together removes every difference between the two measurements except the
  -- machine -- and the load is far larger than both together, so neither is throttled.
  local hc_turbine = must(surface.create_entity({
    name = HC_TURBINE, position = { 0.5, 0.5 }, force = force,
  }), HC_TURBINE)
  feed(surface, force, hc_turbine, "steam", 500)

  local turbine = must(surface.create_entity({
    name = TURBINE, position = { 20.5, 0.5 }, force = force,
  }), TURBINE)
  feed(surface, force, turbine, "steam", 500)

  local pole = power(surface, force, { 8, 0 }, 500e6)
  power(surface, force, { 20, 8 }, 0)

  -- ------------------------------------------------------------------ the two exchangers
  --
  -- Fed water and reactor energy from infinity pipes, with the steam drained every tick and totalled
  -- (see on_tick). Both fill their output box in well under a second, so an end-of-run reading would
  -- compare two full buffers and report them equal whatever they actually make.
  local hc_exchanger = must(surface.create_entity({
    name = HC_EXCHANGER, position = { 0.5, 40.5 }, force = force,
  }), HC_EXCHANGER)
  feed(surface, force, hc_exchanger, "water", nil)
  feed(surface, force, hc_exchanger, ENERGY, nil)

  local exchanger = must(surface.create_entity({
    name = EXCHANGER, position = { 40.5, 40 }, force = force,
  }), EXCHANGER)
  feed(surface, force, exchanger, "water", nil)
  feed(surface, force, exchanger, ENERGY, nil)

  -- ------------------------------------------------------------------ the pair, coupled
  --
  -- An exchanger with a turbine directly on its steam outlet and nothing between them, which is how
  -- a player builds it. The positions are computed from the two prototypes' own connection geometry
  -- rather than written down -- if they are wrong the turbine simply gets no steam, and the check
  -- says so.
  local chain_exchanger = must(surface.create_entity({
    name = HC_EXCHANGER, position = { 70.5, 40.5 }, force = force,
  }), HC_EXCHANGER)
  feed(surface, force, chain_exchanger, "water", nil)
  feed(surface, force, chain_exchanger, ENERGY, nil)

  local steam_out = chain_exchanger.fluidbox.get_pipe_connections(box_of(chain_exchanger, "steam"))[1]
  local chain_turbine = must(surface.create_entity({
    name = HC_TURBINE,
    -- The turbine's connections are symmetric about its centre, three tiles either way, so its
    -- south connection lands on the exchanger's outlet when its centre is four tiles beyond it.
    position = { steam_out.target_position.x, steam_out.target_position.y - 3 },
    force = force,
  }), HC_TURBINE)
  local chain_pole = power(surface, force, { 78, 40 }, 500e6)

  -- ------------------------------------------------------------------ the plant, bolted and chained
  --
  -- THE SHAPE A PLAYER BUILDS ON THE NEUTRONIC SIDE (ADR 0031, #275). Reactor energy sells north and
  -- south; an rf-heat-exchanger stands south of the reactor with its north energy face flush against
  -- it, a second one chains off the first's east short end, and each vents steam south into a
  -- turbine. No pipe carries reactor energy anywhere in this section, and that is asserted by
  -- counting pipes rather than claimed. The row is fed water at ONE end only: the first machine's
  -- west water connection. Its east one is consumed by the joint with the second machine, whose own
  -- west water connection stands on the same tile, so water for the second machine has to cross the
  -- row the same way energy does. That is what "reachable" means in CONTEXT.md.
  --
  -- rf-hc-turbine rather than a vanilla one, so the exchanger is drained flat out: 40 MW of steam
  -- into a 58 MW turbine leaves the boiler `working`, where one 5.8 MW vanilla turbine would leave
  -- it `full_output` most ticks and the status assertion would flicker.
  --
  -- The reactor is a shipped rf-reactor, unlit. control.lua never hears of it (script-built, no
  -- event raised), so nothing drains or fills its boxes but the on_tick below, which refills the
  -- output box to its full 1000 every tick. That is the same instrument probe-energy-containment.ps1
  -- uses for its bolt rows, and it is deliberate: this section asks whether the JOINTS carry, not
  -- whether the reactor can be lit, which check-d-t.ps1 owns.
  local reactor = must(surface.create_entity({
    name = "rf-reactor", position = { 110.5, 20.5 }, force = force,
  }), "rf-reactor")
  local reactor_south = connection_facing(reactor, ENERGY, "south")
  if not reactor_south then error("rf-reactor has no south-facing energy output; ADR 0031 says it must") end

  local first = bolt(surface, force, EXCHANGER, ENERGY, "north", reactor_south.target_position, { 110.5, 60.5 })
  local first_east = connection_facing(first, ENERGY, "east")
  if not first_east then error(EXCHANGER .. " has no east-facing energy connection to chain through") end
  local second = bolt(surface, force, EXCHANGER, ENERGY, "west", first_east.target_position, { 110.5, 60.5 })

  -- One water feed, on the row's free west end. Nothing on the east end: the row has to serve it.
  local first_water = connection_facing(first, "water", "west")
  local water_feed = must(surface.create_entity({
    name = "infinity-pipe", position = first_water.target_position, force = force,
  }), "the row's one water feed")
  water_feed.set_infinity_pipe_filter({ name = "water", percentage = 1, mode = "at-least" })

  local first_turbine = bolt(surface, force, HC_TURBINE, "steam", "north",
    connection_facing(first, "steam", "south").target_position, { 110.5, 60.5 })
  local second_turbine = bolt(surface, force, HC_TURBINE, "steam", "north",
    connection_facing(second, "steam", "south").target_position, { 110.5, 60.5 })
  local plant_pole = power(surface, force, { 118, 40 }, 500e6)

  -- THE CONTROL, and the row is worth nothing without it (#111): the same prototype, fed water the
  -- same way, joined to no neighbour and given no energy. It must hold none and must not be working.
  local aloof = must(surface.create_entity({
    name = EXCHANGER, position = { 110.5, 60.5 }, force = force,
  }), "control " .. EXCHANGER)
  feed(surface, force, aloof, "water", nil)

  storage.plant = {
    reactor = reactor, first = first, second = second, aloof = aloof,
    first_turbine = first_turbine, second_turbine = second_turbine, pole = plant_pole,
    energy_box = box_of(reactor, ENERGY),
    area = { { 100, 10 }, { 140, 68 } },
  }

  storage.rig = {
    hc_turbine = hc_turbine, turbine = turbine,
    hc_exchanger = hc_exchanger, exchanger = exchanger,
    chain_exchanger = chain_exchanger, chain_turbine = chain_turbine,
    pole = pole, chain_pole = chain_pole,
  }
  storage.steam = { hc = 0, ordinary = 0 }
  log("HC-RIG built")
end)

-- Drain both measured exchangers and keep the running total, in fluid units.
script.on_event(defines.events.on_tick, function()
  local r = storage.rig
  if not r then return end
  -- The plant's reactor is unlit; its output box is the instrument. Full every tick, so what the
  -- row holds is bounded by the joints and never by the supply.
  local p = storage.plant
  if p and p.reactor.valid then
    p.reactor.fluidbox[p.energy_box] = { name = ENERGY, amount = 1000 }
  end
  for key, exchanger in pairs({ hc = r.hc_exchanger, ordinary = r.exchanger }) do
    local index = box_of(exchanger, "steam")
    local produced = index and exchanger.fluidbox[index]
    if produced then
      storage.steam[key] = storage.steam[key] + produced.amount
      exchanger.fluidbox[index] = nil
    end
  end
end)

script.on_nth_tick(CHECK_AT, function()
  if game.tick == 0 or storage.done then return end
  storage.done = true
  local r = storage.rig
  local seconds = CHECK_AT / 60

  -- ------------------------------------------------------------ the arithmetic, off the prototypes
  --
  -- The check the whole ticket is written around. Steam's own numbers are read from the fluid rather
  -- than written down, so this stays true if base ever changes them.
  local steam = prototypes.fluid["steam"]
  local joules_per_unit = (500 - steam.default_temperature) * steam.heat_capacity

  local function derived(name)
    local p = prototypes.entity[name]
    return p.fluid_usage_per_tick * 60
      * (p.maximum_temperature - steam.default_temperature) * steam.heat_capacity
      * (p.effectivity or 1)
  end

  -- Vanilla first, as the control on the formula itself. If this line is wrong then every figure
  -- below it is measuring the formula rather than the machine.
  near(derived(TURBINE), prototypes.entity[TURBINE].max_power_output * 60, 1e-6,
    "the output formula reproduces vanilla's steam turbine", "W")
  near(derived(HC_TURBINE), prototypes.entity[HC_TURBINE].max_power_output * 60, 1e-6,
    "and rf-hc-turbine's declared max_power_output matches the steam it drinks", "W")

  -- ------------------------------------------------------------ measured, running
  local statistics = r.pole.electric_network_statistics
  local function produced(name)
    return statistics and statistics.get_flow_count({
      name = name, category = "output",
      precision_index = defines.flow_precision_index.one_minute,
    }) or 0
  end
  local hc_power, ordinary_power = produced(HC_TURBINE), produced(TURBINE)

  record(hc_power > 0 and ordinary_power > 0, "both turbines are generating",
    string.format("hc %.4g, ordinary %.4g", hc_power, ordinary_power))
  -- THE ACCEPTANCE CRITERION. A turbine whose max_power_output had been left at vanilla's would sit
  -- at a ratio of one here while consuming ten times the steam, and nothing else in this rig would
  -- notice.
  near(hc_power / ordinary_power, 10, 0.02,
    "and the high-capacity one really is ten times the ordinary one", "x")

  -- ------------------------------------------------------------ the exchangers, measured
  --
  -- A boiler's energy_consumption is what it puts into the fluid, so the steam it can make is that
  -- divided by the joules a unit carries. Compared against the prototype rather than a constant.
  local function expected_steam(name)
    return prototypes.entity[name].get_max_energy_usage() * 60 / joules_per_unit
  end
  local hc_steam = storage.steam.hc / seconds
  local ordinary_steam = storage.steam.ordinary / seconds

  near(hc_steam, expected_steam(HC_EXCHANGER), 0.02,
    "rf-hc-exchanger makes the steam its energy consumption says it should", "units/s")
  near(ordinary_steam, expected_steam(EXCHANGER), 0.02,
    "and rf-heat-exchanger still makes its own", "units/s")
  near(hc_steam / ordinary_steam, 10, 0.02,
    "so the high-capacity exchanger is ten ordinary ones", "x")

  -- ------------------------------------------------------------ building count
  --
  -- The ticket's second criterion, stated as the arithmetic a player actually does: how many
  -- machines it takes to absorb one ignited D-T reactor, which sells on the order of 320 MW.
  local reactor_mw = 320
  -- Called with no arguments, not with the prototype as self: Factorio hands these out already
  -- bound, so passing the prototype makes it the quality argument and the engine answers "Invalid
  -- QualityID" rather than anything about the call.
  local function megawatts(name, getter)
    return prototypes.entity[name][getter]() * 60 / 1e6
  end
  local hc_pair = reactor_mw / megawatts(HC_EXCHANGER, "get_max_energy_usage")
    + reactor_mw / megawatts(HC_TURBINE, "get_max_power_output")
  local ordinary_pair = reactor_mw / megawatts(EXCHANGER, "get_max_energy_usage")
    + reactor_mw / megawatts(TURBINE, "get_max_power_output")
  record(hc_pair * 5 < ordinary_pair,
    "one ignited D-T reactor needs far fewer buildings on the high-capacity pair",
    string.format("%.1f buildings against %.1f", hc_pair, ordinary_pair))

  -- ------------------------------------------------------------ the pair, coupled
  local chain_statistics = r.chain_pole.electric_network_statistics
  local chained = chain_statistics and chain_statistics.get_flow_count({
    name = HC_TURBINE, category = "output",
    precision_index = defines.flow_precision_index.one_minute,
  }) or 0
  local status = "unknown"
  for name, value in pairs(defines.entity_status) do
    if value == r.chain_turbine.status then status = name end
  end
  record(chained > 0 and r.chain_turbine.status == defines.entity_status.working,
    "a turbine plumbed straight onto an exchanger runs on its steam",
    string.format("flow %.4g, status %s", chained, status))

  -- ------------------------------------------------------------ the plant, bolted and chained
  local p = storage.plant
  local function status_of(entity)
    for name, value in pairs(defines.entity_status) do
      if value == entity.status then return name end
    end
    return tostring(entity.status)
  end
  local function held(entity, fluid)
    local index = box_of(entity, fluid)
    local contents = index and entity.fluidbox[index]
    return contents and contents.amount or 0
  end

  -- BOLTED, in the runtime's own words: the reactor's south output connection has a target, and the
  -- target's owner is the first exchanger. Two adjacent machines whose boxes do not meet have no
  -- target at all, which is the false negative ADR 0018 warns about.
  local south = connection_facing(p.reactor, ENERGY, "south")
  local bolted = south and south.target and south.target.owner == p.first
  record(bolted or false, "bolted: the reactor's south output joins the first exchanger's energy box, no pipe",
    south and (south.target and ("target " .. south.target.owner.name) or "no target") or "no south connection")
  local east = connection_facing(p.first, ENERGY, "east")
  local chained = east and east.target and east.target.owner == p.second
  record(chained or false, "chained: the first exchanger's east energy connection joins the second's west",
    east and (east.target and ("target " .. east.target.owner.name) or "no target") or "no east connection")

  record(p.first.status == defines.entity_status.working and p.second.status == defines.entity_status.working,
    "both exchangers in the row are working",
    string.format("first %s, second %s", status_of(p.first), status_of(p.second)))
  record(held(p.second, ENERGY) > 0, "energy reaches the second exchanger through the joint",
    string.format("first holds %.1f, second holds %.1f", held(p.first, ENERGY), held(p.second, ENERGY)))
  record(held(p.second, "water") > 0, "and water reaches it from the row's one feed",
    string.format("first holds %.1f, second holds %.1f", held(p.first, "water"), held(p.second, "water")))

  -- Counted rather than reasoned, the way probe-exchanger-chaining.ps1 tallies its row: the plant's
  -- area holds exactly one water pipe (the feed), the control's water pipes, and no pipe of any kind
  -- carrying reactor energy.
  local tally = { water = 0, energy = 0, other = 0 }
  for _, pipe in pairs(surface_pipes(p.area)) do
    local f = pipe.get_infinity_pipe_filter()
    if f and f.name == "water" then tally.water = tally.water + 1
    elseif f and f.name == ENERGY then tally.energy = tally.energy + 1
    else tally.other = tally.other + 1 end
  end
  local control_water = #p.aloof.fluidbox.get_pipe_connections(box_of(p.aloof, "water"))
  record(tally.energy == 0 and tally.other == 0 and tally.water == 1 + control_water,
    "one water feed serves the row, and no pipe carries reactor energy",
    string.format("water %d (row 1 + control %d), energy %d, other %d", tally.water, control_water, tally.energy, tally.other))

  local plant_statistics = p.pole.electric_network_statistics
  local plant_power = plant_statistics and plant_statistics.get_flow_count({
    name = HC_TURBINE, category = "output",
    precision_index = defines.flow_precision_index.one_minute,
  }) or 0
  record(plant_power > 0
      and p.first_turbine.status == defines.entity_status.working
      and p.second_turbine.status == defines.entity_status.working,
    "a turbine on each exchanger runs on its steam",
    string.format("flow %.4g, first %s, second %s", plant_power, status_of(p.first_turbine), status_of(p.second_turbine)))

  record(held(p.aloof, ENERGY) == 0 and p.aloof.status ~= defines.entity_status.working,
    "control: an exchanger joined to nothing holds no energy and is not working",
    string.format("holds %.1f, status %s", held(p.aloof, ENERGY), status_of(p.aloof)))

  -- ------------------------------------------------------------ quality
  --
  -- The predecessor's author warned that "certain buildings in this mod get insanely overpowered
  -- with quality" and named none; rfp-hc-turbine is the obvious suspect, since quality is the one
  -- thing that scales a generator's output without scaling the steam it drinks.
  --
  -- REPORTED, NOT ASSERTED. What quality should do to this tier is a balance decision and ADR 0003
  -- tolerates Space Age rather than targeting it, so this rig's job is to put the number on the
  -- record rather than to bound it.
  if WITH_QUALITY then
    for _, quality in ipairs({ "normal", "uncommon", "rare", "epic", "legendary" }) do
      if prototypes.quality[quality] then
        local hc = prototypes.entity[HC_TURBINE].get_max_power_output(quality)
        local ordinary = prototypes.entity[TURBINE].get_max_power_output(quality)
        note("quality " .. quality, string.format(
          "rf-hc-turbine %.4g MW, steam-turbine %.4g MW, ratio %.3f",
          hc * 60 / 1e6, ordinary * 60 / 1e6, hc / ordinary))
      end
    end
  end

  local report = storage.report
  report.lines[#report.lines + 1] = string.format("%s: %d checks, %d failures",
    report.failures == 0 and "PASS" or "FAIL", #report.lines, report.failures)
  for _, line in ipairs(report.lines) do log("HC-RIG " .. line) end
end)
'@
    $energyFeed = Write-EnergyFeed -RigDirectory $rigDir
    $body = $lua.Replace('__TICKS__', "$Ticks").
        Replace('__QUALITY__', $(if ($Quality) { 'true' } else { 'false' })).
        Replace('__ENERGYFEED__', $energyFeed)
    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') `
        -Value $body
}

$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    $enabled = if ($Quality) { @('quality') } else { @() }
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabled -Mods ($ourMods + $rigName)
    Write-Rig

    $save = Join-Path $temp 'hc.zip'
    Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create' | Out-Null
    $runOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', "$($Ticks + 60)", '--benchmark-runs', '1', '--disable-audio')

    $reported = @(Get-Content $runOut | Select-String -Pattern 'HC-RIG (ok|FAIL|PASS|note)' |
        ForEach-Object { ($_ -split 'HC-RIG ', 2)[1].TrimEnd() })
    if ($reported.Count -eq 0) { throw 'the rig reported nothing; it never reached its check tick.' }

    foreach ($line in $reported) { Write-Host "  $line" }

    $verdict = $reported | Where-Object { $_ -match '^(PASS|FAIL): ' } | Select-Object -Last 1
    if (-not $verdict)              { throw 'the rig produced no verdict line.' }
    if ($verdict -notmatch '^PASS') { throw "the high-capacity pair or the bolted plant is broken: $verdict" }

    Write-Host ''
    Write-Host 'OK - both machines deliver what they declare, each is ten times its ordinary'
    Write-Host '     counterpart measured rather than asserted, and the neutronic plant bolts and'
    Write-Host '     chains with no pipe carrying reactor energy.'
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'check-hc' }
}

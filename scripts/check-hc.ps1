<#
.SYNOPSIS
    Checks that the high-capacity steam pair delivers what it declares, and that each half is the
    multiple of its ordinary counterpart that its own prototype declares, measured rather than
    asserted -- ten for the turbine, and since #227 took rf-heat-exchanger to 90 MW no longer ten
    for the exchanger. Discharges #32. Since #275 it also builds the
    neutronic plant the way a player does -- exchangers BOLTED to a reactor and CHAINED to each other,
    no pipe carrying reactor energy -- and asserts that energy, water and steam all arrive. Since
    #280 it carries a -SelfTest that proves the plant section can fail.

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

.PARAMETER SelfTest
    Prove this rig can fail, and the plant section especially (#280, #281, #282).

    THE PLANT SECTION IS WHY THIS SWITCH EXISTS. Its rows are about RUNTIME STATE rather than the
    data stage, and the only other self-test here that starts the game breaks a PROTOTYPE in every
    half that breaks anything: load-check.ps1's canary halves are all data-stage, and its other
    three break nothing at all -- repo-loads is its floor, and socket-height-gate and
    socket-parts-gate run no canary mod because the gates they prove need no game RUN. So a row
    like "energy reaches the second exchanger" cannot be reached from there, and a row like "no
    pipe carries reactor energy" passes by counting nothing, which is a check that says nothing
    until something has been counted.

    REFUSED WITH -Quality, the way load-check refuses -SelfTest -AlsoModDirectory: quality changes
    the mod set, and a half that reasons about what a broken prototype does to the plant would be
    reasoning about a different game.

    The halves, by name -- never by number, because a half inserted above one renumbers every half
    after it while a sentence pointing at a position still reads as true:

      repo-plant-passes      THE FLOOR. The tree as it stands must reach PASS, or a canary result
                             below proves nothing: the rig also fails when the tree is genuinely
                             broken, and the two look identical. load-check's repo-loads, and the
                             same reasoning.
      exchanger-input-only   A CANARY MOD declares ONE of rf-heat-exchanger's three energy
                             connections plain "input" -- the EAST one, the short end the row chains
                             out by -- and the run must report the energy-reaches row FAILED BY NAME.
                             #111 is why the field matters at all
                             (docs/research/exchanger-chaining.md): flow_direction governs
                             FORWARDING and not joining, so the boxes still meet, the machine still
                             burns what it is given, and only the pass-on stops. It is the edit a
                             later change makes by accident, and it is asserted by name because a
                             canary that broke something else would look identical.

                             THE EAST ONE RATHER THAN THE NORTH ONE, AND THAT WAS MEASURED HERE.
                             #280 specified the reactor-contact face on the strength of #111's
                             condition 2 -- "one connection declared plain 'input' stops fuel leaving
                             by the OTHERS". Run against this plant on 2026-09-18 it did not: the
                             canary loaded, took the north connection, and the second exchanger still
                             held a full box. That narrowing is recorded in
                             docs/research/exchanger-chaining.md; what this half needs is a canary
                             that breaks the chain, and the connection the chain leaves by is it.
      pipe-in-plant-area     RIG-SIDE, AND THE ONLY HALF HERE THAT IS. The others break a prototype;
                             this one breaks the WORLD THE RIG BUILDS, by standing an energy feed on
                             the second exchanger's spare east connection -- which is what someone
                             adds to get the plant "fed properly" without noticing they have voided
                             the claim the section makes. The data stage cannot express that, so no
                             canary mod could reach it. The tally row must fail by name AND report at
                             least one energy pipe, or a half that planted nothing would pass.
      reactor-sells-south    A CANARY MOD removes rf-reactor's south-facing energy output, leaving
                             its north one and both plasma connections alone, and the run must fail
                             BY THE RIG'S OWN MESSAGE about a missing south-facing energy output.
                             It is ADR 0031's precondition for the whole section and the one thing
                             on this leg nothing else in the tree asserts. By the message rather
                             than by the exit code, as load-check's starved-reactor is: every other
                             refusal here also aborts map creation.

    Each canary asserts the connection was there to change, so a canary that matched nothing cannot
    pass -- the guard load-check's canary halves carry. The canary mod is written into the temp
    directory and never into the repository.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/check-hc.ps1
    pwsh -File scripts/check-hc.ps1 -Quality
    pwsh -File scripts/check-hc.ps1 -SelfTest
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [ValidateRange(600, 200000)] [int] $Ticks = 3600,
    [switch] $Quality,
    [switch] $SelfTest,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

# Refused rather than combined, the way load-check.ps1 refuses -SelfTest -AlsoModDirectory and for
# the same reason: every half below reasons about what one broken prototype does to this plant, and
# a second mod set changes what the plant is before the canary touches anything.
if ($SelfTest -and $Quality) {
    throw '-SelfTest and -Quality cannot be combined: the self-test needs the plain mod set to prove anything.'
}

$repoRoot   = Split-Path $PSScriptRoot -Parent
$ourMods    = Get-RepoMods
$rigName    = 'rf-hc-rig'
$canaryName = 'rf-hc-canary'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp      = Join-Path ([IO.Path]::GetTempPath()) ('rf-hc-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir    = Join-Path $temp 'mods'
$rigDir    = Join-Path $modDir $rigName
$canaryDir = Join-Path $modDir $canaryName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

function Write-Rig {
    param([switch] $PlantPipe)

    @{
        name = $rigName; version = '0.0.1'; title = 'High-capacity generation check'
        author = 'check-hc.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed', 'realistic-fusion-refreshed-core')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

    $lua = @'
-- Generated by scripts/check-hc.ps1. Nothing here ships.

local CHECK_AT = __TICKS__
local WITH_QUALITY = __QUALITY__
-- -SelfTest's pipe-in-plant-area half, and false in every ordinary run. See the plant section.
local PLANT_PIPE = __PLANTPIPE__

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

  -- BOLTED BY THE SAME HELPER THE PLANT SECTION USES, rather than by an offset written down here
  -- (#276). This used to place the turbine three tiles north of the outlet's target, on the arithmetic
  -- that the turbine's connections are symmetric about its centre -- which was right, and silently
  -- became wrong the moment rf-hc-exchanger's steam outlet moved from its north face to its south.
  -- A rig that computes the offset from both prototypes cannot be broken that way again, and it is
  -- how the plant section below has placed everything since #275.
  local steam_out = connection_facing(chain_exchanger, "steam", "south")
  if not steam_out then error(HC_EXCHANGER .. " has no south-facing steam outlet to plumb a turbine onto") end
  local chain_turbine = bolt(surface, force, HC_TURBINE, "steam", "north",
    steam_out.target_position, { 70.5, 60.5 })
  -- SOUTH OF THE TURBINE, NOT EAST OF THE EXCHANGER (#276). At 7x7 the exchanger ended at x 74 and a
  -- substation at x 77-79 stood clear of it; at fifteen wide it reaches x 78 and the two would share
  -- tiles. create_entity collision-checks nothing (#215, and factorio-lib.ps1's rf_place_or_die
  -- carries the finding), so that overlap would be BUILT rather than refused and this rig would go
  -- on reporting a pass over a plant no player could place.
  local chain_pole = power(surface, force, { 70, 54 }, 500e6)

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
  -- rf-hc-turbine rather than a vanilla one, so the exchanger has a sink worth the name: 90 MW of
  -- steam into a 58.2 MW turbine, where one 5.8 MW vanilla turbine would leave the boiler
  -- `full_output` most ticks and the status assertion would flicker.
  --
  -- THE TURBINE IS NOW THE SMALLER HALF, AND #227 IS WHAT INVERTED IT. Until then the exchanger made
  -- 40 MW into a 58.2 MW sink and was drained flat out. At 90 MW it makes 15.46 steam units a tick
  -- into a turbine drinking 10, a 55% surplus, so the sink is no longer the larger half and the
  -- sentence above no longer describes this rig.
  --
  -- MEASURED RATHER THAN ARGUED, at 70 MW and again at 90 on 2026-09-10, both at the default -Ticks:
  -- both exchangers in the row report `working` and both turbines run. So the assertions below hold
  -- at the inverted ratio -- WHICH IS NOT THE SAME AS KNOWING WHY. `scale_fluid_usage` throttling
  -- the fuel draw to the steam actually being taken is the obvious candidate and is NOT a sufficient
  -- explanation on its own, because it was equally in effect when the vanilla turbine was observed
  -- to cause `full_output` at a far larger surplus. Where between a 55% surplus and a vanilla
  -- turbine's twelvefold one the status flips is unmeasured. If these assertions ever start
  -- reporting `full_output`, the fix is a second turbine on the row and not a weaker assertion.
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

  -- THE ONE THING IN THIS RIG THAT EXISTS ONLY UNDER -SelfTest, and the reason it is here rather
  -- than in a canary mod: the flaw it plants is in the WORLD THE RIG BUILDS, not in a prototype,
  -- and the data stage cannot express it. The section's tally row says no pipe in the plant's area
  -- carries reactor energy; it counted nothing until #281, because until ce0701e it filtered on the
  -- NAME `infinity-pipe` while every energy feed here is Write-EnergyFeed's own prototype, so the
  -- branch that trips the assertion was unreachable and `energy 0` was true by construction.
  --
  -- ON THE SECOND EXCHANGER'S SPARE EAST CONNECTION, because that is where a real regression puts
  -- one: it is the free end of the row, and feeding it is what someone does to get the plant
  -- "fed properly" without noticing the section's whole claim is that nothing needs feeding.
  if PLANT_PIPE then
    local spare = connection_facing(second, ENERGY, "east")
    if not spare then error(EXCHANGER .. " has no east-facing energy connection on the row's free end to plant a pipe on") end
    local planted = must(surface.create_entity({
      name = ENERGY_FEED, position = spare.target_position, force = force,
    }), "the self-test's planted energy pipe")
    planted.set_infinity_pipe_filter({ name = ENERGY, percentage = 1, mode = "at-least" })
  end

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
  -- DERIVED FROM THE TWO PROTOTYPES, NOT A LITERAL 10 (#227). This asserted a hardcoded ten until
  -- rf-heat-exchanger went to 90 MW and rf-hc-exchanger stayed at 400, which makes the real factor
  -- 4.44 -- and the gate failed on the balance change rather than on a defect. Reading the ratio off
  -- the same get_max_energy_usage() the two checks above use means it cannot fail that way again,
  -- and whether 400 should follow to 700 stays a decision rather than something a rig has pinned.
  --
  -- It is implied by the two absolute checks above and is kept anyway, for the reason expected_steam
  -- exists at all: this is the tier's headline arithmetic, and a gate that states it prints the
  -- factor where a reader will see it.
  local declared_factor = expected_steam(HC_EXCHANGER) / expected_steam(EXCHANGER)
  near(hc_steam / ordinary_steam, declared_factor, 0.02,
    "so the high-capacity exchanger is as many ordinary ones as its prototype says", "x")

  -- ------------------------------------------------------------ building count
  --
  -- The ticket's second criterion, stated as the arithmetic a player actually does: how many
  -- machines it takes to absorb one ignited D-T reactor.
  --
  -- ONE HEATER'S WORTH, WHICH IS WHAT A PLAYER HAS. docs/research/d-t-ignition.md's feed table puts
  -- a lit D-T reactor at 324 MW on the shipped 2.5 units/s, and check-brownout.ps1 measured its
  -- trailing-minute output reaching 322 MW at 1800 s and 324 at 2100. Four heaters would read 996
  -- to 1 195 MW instead (#89) and the counts below would quadruple; the switch is the feed, not the
  -- arithmetic.
  --
  -- THE CONSTANT BELOW IS 324 AND WAS 320 UNTIL #227. A round number was fine while nothing nearby
  -- was more precise, and stopped being fine when this comment started quoting the measurement to
  -- three figures. It changes the two counts that get PRINTED by about a percent and changes no
  -- verdict, for the reason below. What #227 really moved here is the exchanger's rating, and the
  -- ordinary-pair count moved with it.
  --
  -- The VERDICT does not depend on the figure at all: every term divides the same number by a
  -- machine's own rating, so it cancels out of the ratio record() asserts. What it sets is the two
  -- counts that get printed.
  local reactor_mw = 324
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
        Replace('__PLANTPIPE__', $(if ($PlantPipe) { 'true' } else { 'false' })).
        Replace('__ENERGYFEED__', $energyFeed)
    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') `
        -Value $body
}

$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

function Invoke-Rig {
    <#  Build the rig, create a map with it, run it, and return what it reported.

        ONE CALLABLE THING BECAUSE -SelfTest CALLS IT ONCE PER HALF. All of this was inline in the try
        block below and could therefore run exactly once, which is why the plant section had no
        self-test until #280.

        THE TWO STEPS USE DIFFERENT INSTRUMENTS, AND THAT IS THE POINT. A FAILED MAP CREATION IS A
        RESULT here rather than a throw, because reactor-sells-south's whole assertion is that the
        rig refuses to build -- so the create step calls Invoke-Factorio and hands the caller the
        exit code, the way load-check's Invoke-LoadCheck does. The run step wants the opposite and
        calls Invoke-FactorioStep, which throws and tails both streams: a rig that built its map and
        then died is a broken rig in every half, and nothing here should be re-writing that. Found
        in review, which caught this function claiming exactly that arrangement while inlining a
        third copy of Invoke-FactorioStep's body -- the copy its own docstring in factorio-lib.ps1
        exists to prevent.

        The canary is named in $Disabled whenever it is not wanted, never merely left out:
        Factorio AUTO-ENABLES a mod present on disk and absent from mod-list.json, so a half after
        exchanger-input-only would otherwise still be running under its canary.  #>
    param(
        [Parameter(Mandatory)] [string] $Tag,
        [switch] $WithCanary,
        [switch] $PlantPipe
    )

    $enabledBundled = if ($Quality) { @('quality') } else { @() }
    $mods     = $ourMods + $rigName + @(if ($WithCanary) { $canaryName })
    $disabled = @(if (-not $WithCanary -and (Test-Path $canaryDir)) { $canaryName })
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabledBundled `
        -Mods $mods -Disabled $disabled
    Write-Rig -PlantPipe:$PlantPipe

    $save   = Join-Path $temp "$Tag.zip"
    $create = Invoke-Factorio @step -Arguments @('--create', $save) -Tag "$Tag-create"
    if ($create.Code -ne 0) {
        return @{ Created = $false; Create = $create; Rows = @(); Verdict = $null }
    }

    $runOut = Invoke-FactorioStep @step -Tag "$Tag-run" -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', "$($Ticks + 60)", '--benchmark-runs', '1', '--disable-audio')

    $rows = @(Get-Content $runOut | Select-String -Pattern 'HC-RIG (ok|FAIL|PASS|note)' |
        ForEach-Object { ($_ -split 'HC-RIG ', 2)[1].TrimEnd() })
    return @{
        Created = $true; Create = $create; Rows = $rows
        Verdict = ($rows | Where-Object { $_ -match '^(PASS|FAIL): ' } | Select-Object -Last 1)
    }
}

function Get-RigRow {
    <#  The one reported row whose name is $Name, verdict prefix and detail included, or $null.

        BY NAME because that is what every half here asserts. A half that only required the run to
        fail would pass on a canary that broke something else entirely -- which is the fault
        load-check's starved-reactor half describes, one gate over.  #>
    param(
        [Parameter(Mandatory)] [hashtable] $Result,
        [Parameter(Mandatory)] [string]    $Name
    )
    return $Result.Rows |
        Where-Object { $_ -match ('^(ok|FAIL)\s+' + [regex]::Escape($Name)) } |
        Select-Object -First 1
}

function Write-Canary {
    <#  Write the self-test's canary mod, with $Lua as its data-final-fixes.

        IN THE TEMP DIRECTORY AND NEVER IN THE REPOSITORY, as load-check's canary is, and
        DUPLICATED FROM IT RATHER THAN SHARED -- decided 2026-09-07, because sharing means editing
        the repository's most load-bearing self-test to save about fifteen lines. Revisit if a third
        rig ever wants one.  #>
    param([Parameter(Mandatory)] [string] $Lua)

    New-Item -ItemType Directory -Path $canaryDir -Force | Out-Null
    @{
        name = $canaryName; version = '0.0.1'; title = 'High-capacity check canary'
        author = 'check-hc.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $canaryDir 'info.json') -Encoding utf8
    $Lua | Set-Content -Path (Join-Path $canaryDir 'data-final-fixes.lua') -Encoding utf8
}

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods

    if ($SelfTest) {
        # THE HALVES ARE DECLARED BY NAME and Invoke-SelfTestHalves numbers them as it runs them, so
        # the total is written nowhere and a half inserted in the middle renumbers nothing.
        #
        # NO HALF LEAVES STATE TO THE NEXT, unlike load-check's, and each therefore needs no
        # $script: anywhere. What one half does leave behind is the canary DIRECTORY, which is why
        # Invoke-Rig names it in $Disabled rather than merely leaving it out of $Mods.
        Invoke-SelfTestHalves -Halves @(
            @{ Name = 'repo-plant-passes'; Body = {
                # The floor. Without it a failure in any later half proves nothing, because this rig
                # also fails when the tree is genuinely broken and the two look identical.
                $clean = Invoke-Rig -Tag 'clean'
                if (-not $clean.Created) {
                    Write-Host ''
                    Write-Host 'FAILED - self-test: the rig could not even build its map on the tree as it'
                    Write-Host "         stands (exit $($clean.Create.Code)), so no canary result below would mean anything."
                    Write-FactorioTail $clean.Create
                    exit 1
                }
                if ($clean.Verdict -notmatch '^PASS') {
                    Write-Host ''
                    Write-Host 'FAILED - self-test: the rig does not pass on the tree as it stands, so a'
                    Write-Host '         canary result taken against it would be meaningless.'
                    foreach ($line in $clean.Rows) { Write-Host "           $line" }
                    exit 1
                }
                'the repo as it stands builds the plant and reaches PASS.'
            } }

            @{ Name = 'exchanger-input-only'; Body = {
                # ONE energy connection declared plain "input", which is the field #111 found the
                # chain turns on: flow_direction governs FORWARDING and not joining, so the boxes
                # still meet and the machine still burns what it is given
                # (docs/research/exchanger-chaining.md). The east one is the short end the row
                # chains out by.
                #
                # NOT THE NORTH ONE, THOUGH #280 ASKED FOR THE REACTOR CONTACT. That was written on
                # #111's condition 2 -- one "input" connection stopping fuel leaving by the OTHERS --
                # and against this plant on 2026-09-18 it did not hold: the canary loaded, took the
                # north connection (its own guard would have errored otherwise), and the second
                # exchanger still held 199.0. The note now records the narrowing. What this half
                # needs is a canary that breaks the chain; east is the connection the chain leaves by
                # and it does.
                #
                # The canary asserts it found a connection to change, or a canary that matched
                # nothing would pass -- load-check's canary halves carry the same guard.
                Write-Canary -Lua @'
-- Generated by scripts/check-hc.ps1 -SelfTest. Nothing here ships.
local box = data.raw["boiler"]["rf-heat-exchanger"].energy_source.fluid_box
local touched = false
for _, connection in pairs(box.pipe_connections) do
  if connection.direction == defines.direction.east then
    connection.flow_direction = "input"
    touched = true
  end
end
if not touched then
  error("check-hc canary: rf-heat-exchanger has no east-facing energy connection to declare \"input\", "
    .. "so the exchanger-input-only half would prove nothing")
end
'@
                $broken = Invoke-Rig -Tag 'input' -WithCanary
                if (-not $broken.Created) {
                    Write-Host ''
                    Write-Host 'FAILED - self-test: the exchanger-input-only canary stopped the map being built'
                    Write-Host "         at all (exit $($broken.Create.Code)), so the plant was never measured. A plain"
                    Write-Host '         "input" connection still JOINS; a canary that refuses to load is testing'
                    Write-Host '         something other than forwarding.'
                    Write-FactorioTail $broken.Create
                    exit 1
                }
                $row = Get-RigRow -Result $broken -Name 'energy reaches the second exchanger through the joint'
                if (-not $row) {
                    Write-Host ''
                    Write-Host 'FAILED - self-test: the run reported no row named "energy reaches the second'
                    Write-Host '         exchanger through the joint", so this half asserted nothing.'
                    foreach ($line in $broken.Rows) { Write-Host "           $line" }
                    exit 1
                }
                if ($row -notmatch '^FAIL') {
                    Write-Host ''
                    Write-Host 'FAILED - self-test: one of rf-heat-exchanger''s energy connections was declared'
                    Write-Host '         plain "input" and the row that says energy reaches the second exchanger'
                    Write-Host '         still passed. That edit stops a chained row being fed and nothing here'
                    Write-Host '         would catch it.'
                    Write-Host "           $row"
                    exit 1
                }
                'declaring one energy connection "input" stops the chain, and the row naming it fails.'
            } }

            @{ Name = 'pipe-in-plant-area'; Body = {
                # RIG-SIDE, AND THE FIRST HALF IN THIS REPOSITORY THAT IS. Every half in
                # load-check's self-test and both above break a PROTOTYPE; this one breaks the world
                # the rig builds, because "a pipe is standing where none should" is not something the
                # data stage can say. See the PLANT_PIPE block in the rig for where it goes and why.
                #
                # THE TALLY MUST READ AT LEAST ONE, not merely fail: a half that planted its pipe
                # outside the counted area, or planted nothing, would otherwise pass on some other
                # row of the same name being false.
                $planted = Invoke-Rig -Tag 'pipe' -PlantPipe
                if (-not $planted.Created) {
                    Write-Host ''
                    Write-Host "FAILED - self-test: the rig could not build its map with the planted pipe (exit $($planted.Create.Code))."
                    Write-FactorioTail $planted.Create
                    exit 1
                }
                $row = Get-RigRow -Result $planted -Name 'one water feed serves the row, and no pipe carries reactor energy'
                if (-not $row) {
                    Write-Host ''
                    Write-Host 'FAILED - self-test: the run reported no row named "one water feed serves the row,'
                    Write-Host '         and no pipe carries reactor energy", so this half asserted nothing.'
                    foreach ($line in $planted.Rows) { Write-Host "           $line" }
                    exit 1
                }
                $counted = if ($row -match 'energy (\d+)') { [int]$Matches[1] } else { -1 }
                if ($counted -lt 1) {
                    Write-Host ''
                    Write-Host 'FAILED - self-test: the planted pipe was not counted, so the tally was never'
                    Write-Host '         shown the thing this half is about -- it landed outside the plant''s area,'
                    Write-Host '         or the filter stopped seeing it.'
                    Write-Host "           $row"
                    exit 1
                }
                if ($row -notmatch '^FAIL') {
                    Write-Host ''
                    Write-Host 'FAILED - self-test: a pipe carrying reactor energy stood inside the plant''s own'
                    Write-Host '         area, the tally counted it, and the row still passed. The section''s claim'
                    Write-Host '         that the plant needs no pipe would be decoration.'
                    Write-Host "           $row"
                    exit 1
                }
                'a pipe carrying reactor energy in the plant''s area is counted and fails the tally.'
            } }

            @{ Name = 'reactor-sells-south'; Body = {
                # ADR 0031's precondition for the whole section: both reactors sell energy north AND
                # south. Nothing else in the tree asserts the south output exists, so an edit or a
                # coexisting mod takes it away and the plant section stops testing a bolt rather
                # than reporting one.
                #
                # BY THE RIG'S OWN MESSAGE rather than by the exit code, as load-check's
                # starved-reactor is: every other refusal here also aborts map creation, so "it
                # failed" alone would not say which check did it.
                Write-Canary -Lua @'
-- Generated by scripts/check-hc.ps1 -SelfTest. Nothing here ships.
-- The south connection only. North and both plasma connections are left alone, so the run fails on
-- the south output being gone rather than on the reactor having no energy output at all.
local box = data.raw["boiler"]["rf-reactor"].output_fluid_box
local kept, removed = {}, 0
for _, connection in pairs(box.pipe_connections) do
  if connection.direction == defines.direction.south then
    removed = removed + 1
  else
    kept[#kept + 1] = connection
  end
end
-- DELIBERATELY WORDED SO IT SHARES NO SENTENCE WITH THE RIG'S OWN REFUSAL. The half asserts that
-- the run failed AND that the output carries the rig's message about a missing south-facing energy
-- output; a guard that said the same thing would satisfy that search by failing, so a canary that
-- matched nothing would report a pass. Found in review.
if removed == 0 then
  error("check-hc canary: found no connection facing south on rf-reactor's output box, "
    .. "so the reactor-sells-south half would prove nothing")
end
box.pipe_connections = kept
'@
                $noSouth = Invoke-Rig -Tag 'south' -WithCanary
                if ($noSouth.Created) {
                    Write-Host ''
                    Write-Host 'FAILED - self-test: rf-reactor''s south-facing energy output was removed and the'
                    Write-Host '         rig built its plant anyway. ADR 0031 says the reactor sells north and'
                    Write-Host '         south, and the plant section rests on it.'
                    foreach ($line in $noSouth.Rows) { Write-Host "           $line" }
                    exit 1
                }
                $said = @($noSouth.Create.OutFile, $noSouth.Create.ErrFile) |
                    Where-Object { $_ -and (Test-Path $_) } |
                    Where-Object { Select-String -Path $_ -SimpleMatch 'has no south-facing energy output' -Quiet }
                if (-not $said) {
                    Write-Host ''
                    Write-Host "FAILED - self-test: the reactor-sells-south canary failed the run (exit $($noSouth.Create.Code)) but"
                    Write-Host '         the rig never said the south-facing energy output was missing, so this'
                    Write-Host '         half cannot tell its own check from any other refusal.'
                    Write-FactorioTail $noSouth.Create
                    exit 1
                }
                'a reactor that stops selling energy south is caught by the rig''s own message.'
            } }
        )

        Write-Host ''
        Write-Host 'OK - the plant section can fail: a chain that stopped carrying, a pipe that should'
        Write-Host '     not be there, and a reactor that stopped selling south are each caught by name.'
        exit 0
    }

    $result = Invoke-Rig -Tag 'hc'
    if (-not $result.Created) {
        Write-FactorioTail $result.Create
        throw "Factorio exited $($result.Create.Code) during 'hc-create'."
    }
    $reported = $result.Rows
    if ($reported.Count -eq 0) { throw 'the rig reported nothing; it never reached its check tick.' }

    foreach ($line in $reported) { Write-Host "  $line" }

    $verdict = $result.Verdict
    if (-not $verdict)              { throw 'the rig produced no verdict line.' }
    if ($verdict -notmatch '^PASS') { throw "the high-capacity pair or the bolted plant is broken: $verdict" }

    Write-Host ''
    Write-Host 'OK - both machines deliver what they declare, the turbine is ten times its ordinary'
    Write-Host '     counterpart and the exchanger the factor its own prototype declares, both'
    Write-Host '     measured rather than asserted, and the neutronic plant bolts and chains with no'
    Write-Host '     pipe carrying reactor energy.'
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'check-hc' }
}

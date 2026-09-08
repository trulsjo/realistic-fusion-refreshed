<#
.SYNOPSIS
    Checks that plant efficiency is researchable, per force, and that it never closes the free-energy
    loop: five forces on one map, same reactors, same plasma, different research. Discharges #96.

.DESCRIPTION
    #96's acceptance criteria are that a researched force's reactor sells more than an unresearched
    one from the same fuel, that an aneutronic reactor does not move at any level, and that the
    free-loop guard survives the top rung. The Lua tests own the arithmetic -- they can hand
    reactor-logic any capture efficiency they like -- and can say nothing about whether control.lua
    ever gives a reactor its OWNER'S number. This does.

    WHAT IS BUILT

    Five rf-reactors and rf-aneutronic-reactors, far enough apart that no two share a power network,
    one per force. Each force gets its own substation and power interface, because an electric
    network does not cross forces. Every reactor is held on an infinity plasma feed, so the
    experiment measures research and not supply.

      none       rf-reactor, D-D plasma, nothing researched            recovers 0.85
      full       rf-reactor, D-D plasma, the whole ladder              recovers 0.9375
      unfusing   rf-reactor, the whole ladder, one unit of plasma      the free-loop guard
                 pinned at the temperature clamp
      an-none    rf-aneutronic-reactor, D-He3 plasma, nothing          recovers 0.95
      an-full    rf-aneutronic-reactor, D-He3 plasma, the whole ladder recovers 0.95, unchanged

    `none` and `full` ARE BIT-IDENTICAL EXCEPT FOR CAPTURE, and that is what makes the comparison
    exact rather than approximate. Capture efficiency scales what a reactor SELLS and touches
    nothing the plasma does -- not its temperature, not its burn rate, not its Q -- so two forces
    with identical geometry and identical feeds evolve identical plasmas, and the ratio of what they
    sell is the ratio of their capture efficiencies to as many figures as the metering carries. A
    band would have been the safe thing to assert and would have proved much less.

    WHY THE FREE-LOOP CELL IS NOT LITERALLY COLD

    ADR 0020 states the guard as "a cold neutronic reactor draws 50 MW and at level 3 returns
    46.9 MW". The arithmetic behind that figure is a steady state rather than a temperature: over a
    step in which the plasma retains nothing, everything the heating put in leaves again and is sold
    across capture_efficiency. A literally cold reactor returns far LESS than that, because most of
    its heating goes into warming the plasma -- so it is the wrong place to site the guard, being
    the easy case rather than the hard one.

    The hard case is a plasma too THIN to fuse and already pinned at the simulation's temperature
    clamp, where nothing can be retained and the whole of the heating is sold. That is the most a
    non-fusing reactor can ever return, and it is 46.9 MW against 50 MW drawn. One unit of plasma is
    a millionth of a full box's density squared, so the ~515 W that does fuse there is five orders
    below the heating.

    WHAT IS ASSERTED

      * an unresearched force sells something at all, so the comparison has a denominator
      * a fully researched force sells more from the same fuel, in exactly the ratio of the two
        capture efficiencies
      * the two plasmas are still identical, which is what says the difference is capture and not
        a reactor that happened to run hotter
      * an aneutronic reactor's output does not move at any level -- to the last figure, not merely
        "not much"
      * the free-loop guard survives the top rung: the unfusing reactor returns less than the
        heating it draws, and the shortfall IS the capture efficiency
      * every rung the ladder names exists as a technology a force can actually research

    A FORCE PART WAY THROUGH THE LADDER IN AN EXISTING SAVE gets what its research says, and that is
    proven by the shape of the rig rather than by an assertion of its own: on_init builds and
    researches, the save is written, and a SECOND Factorio run loads that save and takes every
    reading. Nothing about a force's capture efficiency is stored -- control.lua derives it from
    force.technologies on demand -- so a reading taken after a reload is a reading taken from
    research the save carried.

    WHAT IT DOES NOT COVER, and deliberately. Research granted MID-SAVE reaching the simulation is
    check-confinement.ps1's, and is not re-gated here: both per-force caches are dropped by one call
    on one set of events -- control.lua's forget_force_cache -- so a rig that proves the confinement
    cache is invalidated proves this one is by the same call. The load guard against a rung reaching
    the ceiling is not covered either, for the reason the confinement ladder's guard is not: a guard
    that refuses to load cannot be exercised by a rig that loads, so it is negative-tested in
    tests/test-reactor-logic.lua.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Ticks
    Ticks to run before checking. The default gives every reactor time to reach a steady output and
    the metering time to average over it.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/check-efficiency.ps1
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [int]    $Ticks = 3600,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$rigName  = 'rf-efficiency-rig'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-eff-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

function Write-Rig {
    @{
        name = $rigName; version = '0.0.1'; title = 'Plant efficiency check'
        author = 'check-efficiency.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed', 'realistic-fusion-refreshed-core')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

    $feed = Write-PlasmaFeed -RigDirectory $rigDir

    $lua = @'
-- Generated by scripts/check-efficiency.ps1. Nothing here ships.

local CHECK_AT = __TICKS__

local DD     = "rf-d-d-plasma"
local DHE3   = "rf-d-he3-plasma"
local ENERGY     = "rf-reactor-energy"
local AN_ENERGY  = "rf-aneutronic-reactor-energy"
local NEUTRONIC  = "rf-reactor"
local ANEUTRONIC = "rf-aneutronic-reactor"
local FEED   = "__PLASMAFEED__"

-- EVERY FIGURE THIS RIG COMPARES AGAINST COMES OUT OF THE SHIPPED SPEC, so a balance pass moves the
-- assertions with the constants instead of leaving a rig asserting last month's numbers.
-- reactor-logic touches no Factorio API at all, which is what makes requiring it from a rig legal;
-- scripts/check-buffer.ps1 and scripts/check-pooling.ps1 do the same.
local logic      = require("__realistic-fusion-refreshed__/scripts/reactor-logic")
local SPEC       = logic.reactor
local AN_SPEC    = logic.aneutronic_reactor
local LADDER     = SPEC.capture_ladder
local TOP        = LADDER[#LADDER].capture_efficiency

-- Where an unresearched D-D reactor settles, so both neutronic cells start at their own equilibrium
-- rather than spending the run climbing to it. tests/test-reactor-logic.lua pins it.
local DD_AT   = 2.422e8
-- The aneutronic pair's seed, the same one scripts/check-aneutronic.ps1 uses.
local DHE3_AT = 6e8

local WEST, EAST = -40, 340
local CHUNK_RADIUS = math.ceil(math.max(-WEST, EAST) / 32) + 2

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

local function holds(entity, fluid)
  local total = 0
  for index = 1, #entity.fluidbox do
    local contents = entity.fluidbox[index]
    if contents and contents.name == fluid then total = total + contents.amount end
  end
  return total
end

-- The ladder, discovered from the prototypes rather than counted here, so a rung added to
-- scripts/reactor-logic.lua is picked up instead of silently ignored. The same shape
-- scripts/check-confinement.ps1 finds its own ladder with.
local function rungs()
  local found = {}
  for level = 1, 20 do
    local name = "rf-plant-efficiency-" .. level
    if not prototypes.technology[name] then break end
    found[#found + 1] = name
  end
  return found
end

--- One force, one reactor, one power network, on an infinity plasma feed.
--
-- Geometry is read off the prototypes rather than written down (#49): the two reactors are
-- different sizes and sit on different grid alignments -- fifteen tiles is odd and lands on tile
-- centres, ten is even and lands on corners -- so even the y coordinate comes from the prototype.
local function cell(surface, name, reactor_name, ox, plasma, seed_c, researched)
  local force = game.create_force(name)
  for level = 1, researched do force.technologies[storage.rungs[level]].researched = true end

  local box = prototypes.entity[reactor_name].selection_box
  local width = box.right_bottom.x - box.left_top.x
  local offset = (math.floor(width + 0.5) % 2 == 0) and 0 or 0.5
  local reactor = must(surface.create_entity({
    name = reactor_name, position = { ox + offset, offset }, force = force, raise_built = true,
  }), reactor_name .. " for " .. name)

  local west = reactor.fluidbox.get_pipe_connections(1)[1].target_position
  local pipe = must(surface.create_entity({
    name = FEED, position = { west.x, west.y }, force = force,
  }), "plasma feed for " .. name)
  pipe.set_infinity_pipe_filter({
    name = plasma, percentage = 1, temperature = seed_c, mode = "at-least",
  })

  -- `at` must be whole: a 2x2 substation sits on a tile boundary where the 1x1 interface beside it
  -- sits on a tile centre, and create_entity would snap a half-tile position rather than refuse it.
  --
  -- NINE TILES EAST, which is scripts/check-confinement.ps1's placement and is not slack. A
  -- substation supplies an 18x18 area centred on itself, so this is about as far as it can go and
  -- still reach a fifteen-tile reactor -- and a reactor out of supply does not fail, it runs
  -- unpowered: the plasma cools to the floor over about a minute and every cell here goes on
  -- selling a little, in the same ratio, so the research assertions PASS on reactors that are all
  -- switched off. That is what the first run of this rig did at twenty tiles.
  local at = { math.floor(ox) + 9, 5 }
  must(surface.create_entity({ name = "substation", position = at, force = force }), "substation")
  local eei = must(surface.create_entity({
    name = "electric-energy-interface", position = { at[1] + 2.5, at[2] + 0.5 }, force = force,
  }), "power source")
  -- Joules per TICK, not watts (scripts/check-brownout.ps1 measured that and says so). Sized off
  -- the aneutronic reactor's draw with a wide margin, so nothing here is ever short of power and
  -- one number covers both machines.
  eei.power_production = AN_SPEC.heating_power_w / 60 * 3

  return { force = force, reactor = reactor, feed = pipe, name = name }
end

script.on_init(function()
  local surface = game.surfaces[1]

  surface.request_to_generate_chunks({ 150, 0 }, CHUNK_RADIUS)
  surface.force_generate_chunk_requests()
  local tiles = {}
  for x = WEST, EAST do
    for y = -30, 30 do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = { { WEST, -30 }, { EAST, 30 } } })) do
    if e.type ~= "character" then e.destroy() end
  end

  storage.rungs = rungs()
  -- EVERY RUNG THE SIMULATION NAMES HAS TO EXIST AS SOMETHING A FORCE CAN RESEARCH. control.lua's
  -- check_plant_efficiency refuses to load over a missing one, so reaching this line at all is
  -- already half the answer -- what is added here is that the count agrees with the ladder, which
  -- catches a rung defined under a name the ladder does not use.
  if #storage.rungs ~= #LADDER then
    error(string.format(
      "the plant-efficiency ladder in scripts/reactor-logic.lua has %d rungs and %d rf-plant-" ..
      "efficiency technologies exist. The rig cannot say which is right; reconcile them.",
      #LADDER, #storage.rungs))
  end

  storage.cells = {
    none     = cell(surface, "rf-none",     NEUTRONIC,   0, DD,   DD_AT,   0),
    full     = cell(surface, "rf-full",     NEUTRONIC,  70, DD,   DD_AT,   #LADDER),
    unfusing = cell(surface, "rf-unfusing", NEUTRONIC, 140, DD,   DD_AT,   #LADDER),
    an_none  = cell(surface, "rf-an-none",  ANEUTRONIC, 210, DHE3, DHE3_AT, 0),
    an_full  = cell(surface, "rf-an-full",  ANEUTRONIC, 280, DHE3, DHE3_AT, #LADDER),
  }
  -- The unfusing cell's feed is taken away: its plasma is written directly every tick, and an
  -- infinity pipe would keep topping the box back up to full.
  storage.cells.unfusing.feed.destroy()

  storage.sold = { none = 0, full = 0, unfusing = 0, an_none = 0, an_full = 0 }
  log("EFF-RIG built")
end)

-- Which fluid each cell sells. The two reactors deliberately sell different, non-interchangeable
-- energy fluids (#31, ADR 0018), and metering the wrong one would read zero and look like a
-- reactor that had stopped.
local SELLS = {
  none = ENERGY, full = ENERGY, unfusing = ENERGY,
  an_none = AN_ENERGY, an_full = AN_ENERGY,
}

script.on_event(defines.events.on_tick, function()
  local cells = storage.cells
  if not cells then return end

  -- THE FREE-LOOP CELL, held where the guard is hardest. One unit of plasma at the simulation's own
  -- temperature clamp: too thin to fuse and already at the ceiling, so nothing can be retained and
  -- the whole of the heating leaves again to be sold. See the note at the top of this file for why
  -- that, rather than a literally cold reactor, is the operating point ADR 0020's figure describes.
  --
  -- The ceiling is read off the FLUID rather than off the spec, and the two are required to be equal
  -- by control.lua's check_plasma_bounds -- so this writes a temperature the engine will certainly
  -- accept, and a clamp raised without the fluid would have failed at load rather than here.
  local pinned = cells.unfusing.reactor
  if pinned.valid then
    pinned.fluidbox[1] = {
      name = DD, amount = 1, temperature = prototypes.fluid[DD].max_temperature,
    }
  end

  -- EMPTY THE ENERGY BOX AND KEEP THE RUNNING TOTAL, which is the only way to measure a production
  -- rather than a level: the box holds 1000 units and apply() discards what will not fit, so any
  -- reactor producing more than that per step reads the same 1000 as one producing twice as much.
  -- Every tick rather than on the simulation's cadence, because the rig does not know what
  -- UPDATE_INTERVAL is and does not need to: a tick with no write drains nothing and adds nothing.
  local sold = storage.sold
  for key, one in pairs(cells) do
    if one.reactor.valid then
      sold[key] = sold[key] + one.reactor.remove_fluid({ name = SELLS[key], amount = 1e9 })
    end
  end
end)

script.on_nth_tick(CHECK_AT, function()
  if game.tick == 0 or storage.done then return end
  storage.done = true
  local c = storage.cells
  local sold = storage.sold

  -- Whatever is still in each box at the end goes into its own total, so at worst one step's worth
  -- of energy moves between the two terms of one sum.
  for key, one in pairs(c) do sold[key] = sold[key] + holds(one.reactor, SELLS[key]) end

  -- ------------------------------------------------------------ the denominator
  record(sold.none > 0, "the unresearched reactor sold energy at all, so there is a denominator",
    string.format("%.6g units", sold.none))

  -- ------------------------------------------------------------ research reaches the simulation
  --
  -- THE TICKET'S FIRST CRITERION, and it is an EQUALITY rather than a floor. Capture efficiency
  -- scales what a reactor sells and touches nothing the plasma does, so two forces with identical
  -- geometry and identical feeds run identical plasmas and the ratio of what they sell is the ratio
  -- of their capture efficiencies. Anything else means the difference is coming from somewhere
  -- other than the research.
  local expected = TOP / SPEC.capture_efficiency
  local measured = sold.none > 0 and (sold.full / sold.none) or 0
  record(math.abs(measured - expected) <= 0.002 * expected,
    "a researched force sells more from the same fuel, in exactly the ratio of the two efficiencies",
    string.format("%.6f measured against %.6f expected (%.4g -> %.4g) -- %.6g against %.6g units",
      measured, expected, SPEC.capture_efficiency, TOP, sold.full, sold.none))

  -- THE CONTROL FOR THAT EQUALITY. If the two plasmas had drifted apart the ratio above would be
  -- measuring two things at once, and would still be somewhere near 1.1.
  local none_plasma, full_plasma = c.none.reactor.fluidbox[1], c.full.reactor.fluidbox[1]
  record(none_plasma ~= nil and full_plasma ~= nil
    and math.abs(full_plasma.temperature - none_plasma.temperature)
        <= 1e-6 * none_plasma.temperature,
    "and the two plasmas are still at the same temperature, so the difference is capture alone",
    string.format("%.9g C against %.9g C",
      full_plasma and full_plasma.temperature or 0, none_plasma and none_plasma.temperature or 0))
  -- AND THEY ARE HOT, which the line above cannot say on its own: two reactors that have both cooled
  -- to the floor also agree to the last figure, and go on selling a trickle in exactly the ratio of
  -- their capture efficiencies. That is the state an out-of-supply cell ends in, and it passed
  -- everything above it before the substations were moved.
  record(none_plasma ~= nil and none_plasma.temperature > 1e8,
    "and both are actually fusing rather than sitting at the floor unpowered",
    none_plasma and string.format("%.6g C", none_plasma.temperature) or "no plasma")

  -- ------------------------------------------------------------ the aneutronic tier does not move
  --
  -- ADR 0020 decision 4, negative-tested. The aneutronic reactor has no ladder, so no amount of
  -- rf-plant-efficiency may touch it -- and this is asserted to the last figure rather than as
  -- "not much", because these two cells are identical in every respect and a deterministic engine
  -- has nothing to make them differ by.
  record(sold.an_none > 0, "the aneutronic reactors sold energy at all",
    string.format("%.6g units", sold.an_none))
  record(sold.an_none > 0 and math.abs(sold.an_full - sold.an_none) <= 1e-9 * sold.an_none,
    "an aneutronic reactor's output does not move at any level of plant efficiency",
    string.format("%.9g against %.9g units -- %+.3g%%", sold.an_full, sold.an_none,
      sold.an_none > 0 and 100 * (sold.an_full / sold.an_none - 1) or 0))

  -- ------------------------------------------------------------ the free-loop guard at level 3
  --
  -- capture_efficiency is the only term standing between this mod and perpetual motion, and ADR
  -- 0020 permits a research line into it only because each rung halves the remaining gap to a
  -- ceiling below 1.0. This is that guard, measured on the tier that has the line, at the top of it.
  local seconds = game.tick / 60
  local returned_w = sold.unfusing * SPEC.energy_fluid_j_per_unit / seconds
  local drawn_w = SPEC.heating_power_w
  local pinned_plasma = c.unfusing.reactor.fluidbox[1]
  record(pinned_plasma ~= nil
    and pinned_plasma.temperature >= prototypes.fluid[DD].max_temperature * (1 - 1e-9)
    and pinned_plasma.amount <= 1 + 1e-6,
    "the free-loop cell is where it was put: one unit of plasma pinned at the temperature clamp",
    pinned_plasma and string.format("%.6g units at %.6g C",
      pinned_plasma.amount, pinned_plasma.temperature) or "no plasma")
  record(returned_w < drawn_w,
    "a fully researched reactor that is not fusing returns LESS than the heating it draws",
    string.format("%.6g MW returned against %.6g MW drawn", returned_w / 1e6, drawn_w / 1e6))
  record(math.abs(returned_w / drawn_w - TOP) <= 0.01 * TOP,
    "and the shortfall IS the capture efficiency, which is why the ceiling is the guard",
    string.format("%.6f of the heating returned, against a capture efficiency of %.6f",
      returned_w / drawn_w, TOP))
  record(TOP < SPEC.capture_ceiling and SPEC.capture_ceiling < 1,
    "with the top rung under a ceiling that is itself under 1.0, so no rung can ever close the loop",
    string.format("%.6g < %.6g < 1", TOP, SPEC.capture_ceiling))

  lines[#lines + 1] = string.format("%s: %d checks, %d failures",
    failures == 0 and "PASS" or "FAIL", #lines, failures)
  for _, line in ipairs(lines) do log("EFF-RIG " .. line) end
end)
'@
    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') `
        -Value $lua.Replace('__PLASMAFEED__', $feed).Replace('__TICKS__', "$Ticks")
}

$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled @() -Mods ($ourMods + $rigName)
    Write-Rig

    $save = Join-Path $temp 'efficiency.zip'
    Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create' | Out-Null
    # A margin past CHECK_AT so the check tick is certainly reached.
    $runOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', "$($Ticks + 120)", '--benchmark-runs', '1',
        '--disable-audio')

    $reported = @(Get-Content $runOut | Select-String -Pattern 'EFF-RIG (ok|FAIL|PASS)' |
        ForEach-Object { ($_ -split 'EFF-RIG ', 2)[1].TrimEnd() })
    if ($reported.Count -eq 0) { throw 'the rig reported nothing; it never reached its check tick.' }

    foreach ($line in $reported) { Write-Host "  $line" }

    $verdict = $reported | Where-Object { $_ -match '^(PASS|FAIL): ' } | Select-Object -Last 1
    if (-not $verdict)              { throw 'the rig produced no verdict line.' }
    if ($verdict -notmatch '^PASS') { throw "plant efficiency is not behaving as ADR 0020 says: $verdict" }

    Write-Host ''
    Write-Host 'OK - plant efficiency follows the force that owns the reactor, leaves the aneutronic'
    Write-Host '     tier alone, and never returns more than it draws.'
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'check-efficiency' }
}

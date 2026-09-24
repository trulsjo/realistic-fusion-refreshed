<#
.SYNOPSIS
    Checks that the plasma-heating ladder is per force and that a rung arrives as a bigger bill:
    four forces on one map, same reactor, same plasma -- and each one drawing exactly the megawatts
    its own research says, a hotter plasma for it, and more tritium bred. Discharges #425.

.DESCRIPTION
    ADR 0038 makes heating power the second researchable lever on rf-reactor. The Lua suite drives
    reactor-logic directly and can hand it any spec it likes, so it proves the arithmetic and says
    nothing about whether control.lua ever gives a reactor its owner's number -- or whether the
    number reaches entity.energy, which is the half a player feels first. This does both.

    WHY THE DRAW IS THE HEADLINE HERE, where scripts/check-confinement.ps1 measures a temperature.
    Confinement time changes only what the plasma does with the power it was given. Heating power
    changes what the reactor TAKES, and ADR 0038 accepts a bigger grid bill as the price of a
    shorter fuel chain -- so "a researched reactor really does draw more" is the claim that has to
    be measured in a running game rather than asserted in a model that has no electricity in it.

    WHAT IS BUILT

    Four rf-reactors, far enough apart that no two share a power network, one per force. Each is
    given a full box of D-D plasma at 2.422e8 C -- the temperature an UNRESEARCHED reactor settles
    at, so every cell starts from one state and separates only because of research. Each has an
    rf-isotope-collector bolted to its south face, unplumbed, so what it breeds simply accumulates
    in the collector's own 500-unit boxes.

      rf-none       nothing researched                 50 MW
      rf-mid        the first three rungs              65 MW
      rf-top        the whole ladder                   75 MW
      rf-upgraded   nothing, THEN the whole ladder     50 MW, then 75 MW from tick 1800

    HOW THE DRAW IS MEASURED. control.lua spends heating out of entity.energy every tick and the
    network refills it, so a supplied reactor's buffer sits full and says nothing at all. Once a
    phase each cell's supply is switched off for six ticks and its buffer seeded at 9 MJ; what
    leaves the buffer over those six ticks is exactly what control.lua spent, and nothing else can
    have taken it. Six ticks is as long as the window can be: the buffer is 10 MJ and the top rung
    is 1.25 MJ a tick, so eight ticks would empty it -- and an empty buffer clamps the payment,
    which reads as a smaller draw rather than as a fault. The rig asserts that no window emptied one.

    rf-upgraded is what makes the rest mean anything twice over. It is identical to rf-none for the
    first thirty seconds, so the only thing that can separate them by the end is the research
    granted in between -- which is control.lua's on_research_finished handler and the per-force
    cache it drops. spend() reads that cache now; before #425 it read the module table and no
    research could have moved it.

    The plasma is topped back up to a full box every second, temperature preserved. Without that
    the four reactors burn their fuel at four different rates, a thinner plasma runs hotter, and the
    experiment would be measuring two things at once.

    WHAT IS ASSERTED

      * each force's draw is the rung its research says, to a per cent, read off the ladder in
        scripts/reactor-logic.lua rather than written down here
      * the unresearched force draws exactly the shipped 50 MW, which is ADR 0038 decision 3: a
        researchable lever leaves the unresearched machine where it was
      * rf-upgraded and rf-none draw the same before the grant and differ after it
      * more heating is a hotter plasma and more tritium bred, in that order, across the cells
      * every cell is still holding plasma and still breeding, so nothing above is a reading taken
        off a stalled reactor

    WHAT IT DOES NOT COVER: the absolute breeding rate against the model's figure. That needs the
    plasma settled, which is twenty minutes of game time per cell, and it is pinned in
    tests/test-reactor-logic.lua and exercised in game by scripts/check-breeding.ps1. What is
    asserted here is the ORDERING, which is the part the ladder is responsible for.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/check-heating.ps1
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
$rigName  = 'rf-heating-rig'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-heat-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

function Write-Rig {
    @{
        name = $rigName; version = '0.0.1'; title = 'Plasma heating ladder check'
        author = 'check-heating.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

    $lua = @'
-- Generated by scripts/check-heating.ps1. Nothing here ships.

local PLASMA  = "rf-d-d-plasma"
local TRITIUM = "rf-tritium"
-- READ OFF THE LOADED PROTOTYPE, not written down (#295). rf-reactor's plasma box is box 1, and
-- prototypes/entities.lua writes it from reactor-logic's box_volume, which control.lua's
-- check_plasma_capacity() then refuses to load without (#296). So this is the capacity the
-- simulation is actually running -- a literal here would go on seeding 1000 units into a box that
-- had moved, and the rig would report a full reactor while filling a fraction of one.
local FULL    = prototypes.entity["rf-reactor"].fluidbox_prototypes[1].volume
-- Where an unresearched D-D reactor settles, so every cell starts from one state and separates
-- only because of research. tests/test-reactor-logic.lua pins it; if it moves, the control line
-- below reports the drift and names the number, which is the right way round.
local SEED_C = 2.422e8

-- Thirty seconds of game time per phase, at sixty ticks a second.
local PHASE_TICKS = 1800
-- Where in each phase the draw window opens. Ten seconds in, so spend()'s one-interval lag at the
-- start of a phase is long past and the reading is of a reactor in its steady state.
local SETTLE_TICKS = 600

-- HOW THE DRAW IS MEASURED, and why the window is six ticks long rather than thirty seconds.
-- control.lua spends heating out of entity.energy every tick and the network refills it, so a
-- supplied reactor's buffer sits full and says nothing at all. For the window the supply is
-- switched off and the buffer set to a known level; what leaves it is then exactly what control.lua
-- spent, and nothing else can have taken it.
--
-- SIX TICKS IS AS LONG AS THE WINDOW CAN BE. rf-reactor's buffer_capacity is 10 MJ and the top of
-- the ladder is 75 MW, which is 1.25 MJ a tick: eight ticks would empty it, and an empty buffer
-- clamps the payment and reads as a SMALLER draw rather than as a fault. Six ticks spends 7.5 MJ
-- at the worst rung, which leaves margin and is still 360 payments a second of resolution.
local WINDOW_TICKS = 6
-- Under the 10 MJ the prototype declares, so the engine certainly accepts it. It is read back
-- rather than assumed, because the engine holds 16/15 of a declared capacity and a write it
-- clamped would otherwise be measured as a payment nobody made.
local WINDOW_SEED_J = 9e6

-- Joules per TICK, not watts (scripts/check-brownout.ps1 measured that and says so). 3e6 is
-- 180 MW against the hungriest reactor's 75, so no cell is ever short outside its own window.
local SUPPLY_J_PER_TICK = 3e6

local lines = {}
local failures = 0

local function record(ok, name, detail)
  if not ok then failures = failures + 1 end
  lines[#lines + 1] = string.format("%s  %s%s", ok and "ok  " or "FAIL", name,
    detail and ("  -- " .. detail) or "")
end

__RIGBUILD__

-- The ladder, discovered from the prototypes rather than counted here, so a rung added to
-- scripts/reactor-logic.lua is picked up instead of silently ignored. The WATTS each rung means
-- cannot be discovered that way -- a technology with no effects carries none of its meaning in the
-- prototype -- so they are read straight off the shipped module below.
local LOGIC = require("__realistic-fusion-refreshed__/scripts/reactor-logic")
local LADDER = LOGIC.reactor.heating_ladder

--- The heating power a force holding the first `count` rungs runs at, in watts.
local function heating_at(count)
  if count <= 0 then return LOGIC.reactor.heating_power_w end
  return LADDER[count].heating_power_w
end

--- Research the first `count` rungs for a force.
local function grant(force, count)
  for level = 1, count do
    force.technologies[LADDER[level].technology].researched = true
  end
end

--- One force, one reactor, one collector, one dead power network.
--
-- `at` is the substation's centre and must be a whole number: a 2x2 entity sits on a tile boundary
-- where the 1x1 interface beside it sits on a tile centre, and create_entity would snap a
-- half-tile position rather than refuse it.
local function cell(surface, name, x, researched)
  local force = game.create_force(name)
  grant(force, researched)

  local reactor = rf_place_or_die(surface, {
    name = "rf-reactor", position = { x, 0.5 }, force = force, raise_built = true,
  }, "rf-reactor for " .. name)

  -- Its own network, with a supply this cell can switch off for the length of a draw window.
  local at = { math.floor(x) + 9, 5 }
  rf_place_or_die(surface,
    { name = "substation", position = at, force = force }, "substation")
  local eei = rf_place_or_die(surface, {
    name = "electric-energy-interface", position = { at[1] + 2.5, at[2] + 0.5 }, force = force,
  }, "power source")
  eei.power_production = SUPPLY_J_PER_TICK

  reactor.fluidbox[1] = { name = PLASMA, amount = FULL, temperature = SEED_C }

  -- Bolted flush to the south face, computed from both selection boxes rather than written down:
  -- the collector has to land inside the one-tile margin entity-management's attach() searches, and
  -- "nine tiles south" is exactly the remembered constant #49 was about. Nothing is plumbed to it,
  -- so its own 500-unit boxes simply fill -- ample for the ~24 units the hungriest cell breeds here.
  local rbox = prototypes.entity["rf-reactor"].selection_box
  local cbox = prototypes.entity["rf-isotope-collector"].selection_box
  local collector = rf_place_or_die(surface, {
    name = "rf-isotope-collector",
    position = {
      reactor.position.x,
      reactor.position.y + rbox.right_bottom.y + (cbox.right_bottom.y - cbox.left_top.y) / 2,
    },
    force = force, direction = defines.direction.south, raise_built = true,
  }, "rf-isotope-collector for " .. name)

  return { force = force, reactor = reactor, collector = collector, eei = eei, name = name,
           researched = researched }
end

script.on_init(function()
  local surface = game.surfaces[1]

  surface.request_to_generate_chunks({ 50, 0 }, 8)
  surface.force_generate_chunk_requests()
  local tiles = {}
  for x = -20, 120 do
    for y = -20, 30 do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = { { -20, -20 }, { 120, 30 } } })) do
    if e.type ~= "character" then e.destroy() end
  end

  if #LADDER < 3 then
    error(string.format(
      "this rig needs a heating ladder of at least three rungs and found %d. If the ladder in " ..
      "scripts/reactor-logic.lua was shortened, the experiment below needs rewriting rather than " ..
      "adjusting.", #LADDER))
  end

  storage.cells = {
    none     = cell(surface, "rf-none",     0.5,  0),
    mid      = cell(surface, "rf-mid",      30.5, 3),
    top      = cell(surface, "rf-top",      60.5, #LADDER),
    upgraded = cell(surface, "rf-upgraded", 90.5, 0),
  }
  log("HEAT-RIG built")
end)

--- This reactor's plasma temperature, or nil if it has none.
local function temperature(c)
  local plasma = c.reactor.fluidbox[1]
  return plasma and plasma.temperature or nil
end

--- Total tritium across every box of this cell's collector.
local function tritium(c)
  local total = 0
  for index = 1, #c.collector.fluidbox do
    local contents = c.collector.fluidbox[index]
    if contents and contents.name == TRITIUM then total = total + contents.amount end
  end
  return total
end

-- Held full, so the only difference between the four reactors is their research. A reactor left to
-- drain burns its fuel at a rate that depends on how hot it is, a thinner plasma settles hotter,
-- and the four curves would separate for two reasons instead of one.
script.on_nth_tick(60, function()
  for _, c in pairs(storage.cells) do
    local plasma = c.reactor.fluidbox[1]
    if plasma and plasma.amount < FULL then
      c.reactor.fluidbox[1] = { name = plasma.name, amount = FULL, temperature = plasma.temperature }
    end
  end
end)

-- THE DRAW WINDOW. Opens SETTLE_TICKS into each phase and closes WINDOW_TICKS later; the supply is
-- off for exactly that span and the buffer is seeded at its start.
--
-- THE ORDER WITHIN A TICK IS WHY THE SPAN IS THE SPAN. This rig depends on
-- realistic-fusion-refreshed, so control.lua's on_tick handler runs before this one: at the opening
-- tick spend() has already been paid and the seed is written after it, and at the closing tick
-- spend() has been paid again before the reading. So the window holds exactly WINDOW_TICKS
-- payments, one for each tick strictly after the opening one.
script.on_nth_tick(1, function()
  local into = game.tick % PHASE_TICKS
  if into == SETTLE_TICKS then
    storage.opened = {}
    for key, c in pairs(storage.cells) do
      -- BOTH, and the second one is not belt and braces. A vanilla electric-energy-interface
      -- carries a large buffer of its own, and it goes on pushing that into the network after it
      -- stops GENERATING -- which is what the first version of this rig measured: the reactor's
      -- buffer ENDED HIGHER than it was seeded at, and the six-tick window read as one tick's
      -- payment against five ticks of refill. Emptying the source is what actually isolates the
      -- reactor from its network.
      c.eei.power_production = 0
      c.eei.energy = 0
      c.reactor.energy = WINDOW_SEED_J
      -- Read back rather than assumed: the engine holds 16/15 of a declared capacity, so a write
      -- it clamped would otherwise be measured as a payment nobody made.
      storage.opened[key] = c.reactor.energy
    end
  elseif into == SETTLE_TICKS + WINDOW_TICKS then
    storage.drawn = {}
    storage.left = {}
    for key, c in pairs(storage.cells) do
      storage.drawn[key] = (storage.opened[key] - c.reactor.energy) / WINDOW_TICKS * 60 / 1e6
      storage.left[key] = c.reactor.energy
      c.eei.power_production = SUPPLY_J_PER_TICK
    end
  end
end)

--- One cell's draw against the rung its research says it is on.
local function record_draw(key, c, drawn, count)
  local want = heating_at(count) / 1e6
  record(math.abs(drawn[key] - want) / want < 0.01,
    string.format("%s draws the %g MW its research says", c.name, want),
    string.format("%.4g MW measured", drawn[key]))
end

script.on_nth_tick(PHASE_TICKS, function()
  if game.tick == 0 or storage.done then return end
  local c = storage.cells

  -- ---------------------------------------------------------------- phase one: research as built
  if not storage.phase_one then
    local drawn = storage.drawn
    storage.phase_one = { drawn = drawn, temperature = {}, tritium = {} }
    for key, one in pairs(c) do
      storage.phase_one.temperature[key] = temperature(one)
      storage.phase_one.tritium[key] = tritium(one)
    end

    for key, one in pairs(c) do
      record(storage.phase_one.temperature[key] ~= nil,
        string.format("%s still holds plasma", one.name))
      -- An empty buffer clamps the payment, so a window that emptied one reads as a SMALLER draw
      -- rather than as a fault. This is the line that says no reading above was clamped.
      record(storage.left[key] > 0,
        string.format("%s still had buffer left when its window closed", one.name),
        string.format("%.4g J left of the %.4g J it was seeded with",
          storage.left[key], storage.opened[key]))
    end

    -- ADR 0038 DECISION 3, MEASURED. An unresearched force draws exactly what the mod shipped
    -- before this ladder existed. If this line ever fails, the lever stopped being researchable
    -- and started being a retune.
    record_draw("none", c.none, drawn, 0)
    record_draw("mid", c.mid, drawn, 3)
    record_draw("top", c.top, drawn, #LADDER)
    record_draw("upgraded", c.upgraded, drawn, 0)

    -- The pair the second phase turns on. Identical research, so identical draw -- to the last
    -- digit, because Factorio is deterministic and nothing separates these two yet.
    record(math.abs(drawn.upgraded - drawn.none) < 1e-9,
      "the two forces holding the same research draw the same, to the digit",
      string.format("%.9g MW against %.9g MW", drawn.upgraded, drawn.none))

    -- ------------------------------------------------------------ and now research the ladder
    --
    -- On one of the pair only. Everything else about them stays equal, so whatever separates them
    -- from here is control.lua noticing that a force's research changed -- and spend() reading the
    -- cache it dropped, which is the line #425 actually added.
    grant(c.upgraded.force, #LADDER)
    log("HEAT-RIG granted the whole heating ladder to rf-upgraded")
    return
  end

  -- ---------------------------------------------------------------- phase two: research mid-save
  storage.done = true
  local drawn = storage.drawn
  local p = storage.phase_one

  for key, one in pairs(c) do
    record(storage.left[key] > 0,
      string.format("%s still had buffer left when its second window closed", one.name),
      string.format("%.4g J left of the %.4g J it was seeded with",
        storage.left[key], storage.opened[key]))
  end

  record_draw("none", c.none, drawn, 0)
  record_draw("upgraded", c.upgraded, drawn, #LADDER)
  record(drawn.upgraded > drawn.none * 1.4,
    "researching the ladder mid-save moves the bill for two forces that drew the same",
    string.format("%.4g MW against %.4g MW, having been equal thirty seconds ago",
      drawn.upgraded, drawn.none))
  record(math.abs(drawn.upgraded - drawn.top) / drawn.top < 0.01,
    "and it lands on the same figure as the force that held the ladder all along",
    string.format("%.4g MW against %.4g MW", drawn.upgraded, drawn.top))

  -- THE CONTROL. An unresearched reactor was seeded at its own equilibrium, so it should not have
  -- moved. If it has, every other line here is measuring something else as well as research.
  local none_t = temperature(c.none)
  record(none_t and math.abs(none_t - SEED_C) / SEED_C < 0.02,
    "the unresearched reactor sits where it was seeded, so it is a control and not a curve",
    none_t and string.format("%.5g C against %.5g C seeded", none_t, SEED_C) or "no plasma")

  -- AND WHAT THE BILL BOUGHT, in the order the model says it arrives: more heating is a hotter
  -- plasma, and a hotter plasma breeds faster. Measured as a total over the second phase alone,
  -- so rf-upgraded's first thirty seconds at 50 MW are not in it.
  local hot, bred = {}, {}
  for key, one in pairs(c) do
    hot[key] = temperature(one)
    bred[key] = tritium(one) - p.tritium[key]
  end
  record(hot.mid and hot.none and hot.mid > hot.none * 1.05,
    "a force part way up the ladder runs hotter than one with nothing researched",
    string.format("%.5g C against %.5g C", hot.mid or 0, hot.none or 0))
  record(hot.top and hot.mid and hot.top > hot.mid * 1.02,
    "and a force with the whole ladder runs hotter still",
    string.format("%.5g C against %.5g C", hot.top or 0, hot.mid or 0))
  record(bred.none > 0 and bred.mid > bred.none and bred.top > bred.mid,
    "and each of them breeds more tritium over the same thirty seconds",
    string.format("%.6g, %.6g, %.6g units", bred.none, bred.mid, bred.top))

  lines[#lines + 1] = string.format("%s: %d checks, %d failures",
    failures == 0 and "PASS" or "FAIL", #lines, failures)
  for _, line in ipairs(lines) do log("HEAT-RIG " .. line) end
end)
'@
    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') `
        -Value ($lua.Replace('__RIGBUILD__', (Get-RigBuildLua)))
}

$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    New-ModJunctions -ModDirectory $modDir -Links (Get-ModLinks -Root $repoRoot -Mods $ourMods)
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled @() -Mods ($ourMods + $rigName)
    Write-Rig

    $save = Join-Path $temp 'heating.zip'
    Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create' | Out-Null
    # Two phases of thirty seconds each, plus a margin so the second phase tick is certainly reached.
    $runOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', '3900', '--benchmark-runs', '1', '--disable-audio')

    $reported = @(Get-Content $runOut | Select-String -Pattern 'HEAT-RIG (ok|FAIL|PASS)' |
        ForEach-Object { ($_ -split 'HEAT-RIG ', 2)[1].TrimEnd() })
    if ($reported.Count -eq 0) { throw 'the rig reported nothing; it never reached its check tick.' }

    foreach ($line in $reported) { Write-Host "  $line" }

    $verdict = $reported | Where-Object { $_ -match '^(PASS|FAIL): ' } | Select-Object -Last 1
    if (-not $verdict)              { throw 'the rig produced no verdict line.' }
    if ($verdict -notmatch '^PASS') { throw "the heating ladder is not per force: $verdict" }

    Write-Host ''
    Write-Host 'OK - heating power follows the force that owns the reactor, across a save/load, it'
    Write-Host '     arrives as a bigger draw on entity.energy, and research finished mid-save'
    Write-Host '     reaches the bill as well as the plasma.'
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'check-heating' }
}

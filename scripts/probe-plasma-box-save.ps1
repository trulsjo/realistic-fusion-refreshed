<#
.SYNOPSIS
    Fills a fuel-line rig on rf-reactor as shipped, with an "input-output" plasma box, saves it, and
    loads that save twice: once with the input-box canary named disabled and once with it enabled.
    Reports what every box and segment holds before the save, at load, on the first tick after it
    and once settled, and every log line from the load that mentions the box (#550).

.DESCRIPTION
    A PROBE, NOT A CHECK. Every line it prints is a measurement, and exit 0 means the probe ran and
    every row reported, never that the answer was the one anybody hoped for. A load that fails is a
    reading too, and is reported rather than thrown. It must not be added to a check sweep or to
    load-check.ps1. docs/research/plasma-input-box.md is what its rows are read into.

    THE CANARY is probe-plasma-input-box.ps1's, copied rather than shared (the precedent is in
    scripts/CLAUDE.md): rf-reactor's own box set to "input" in data-final-fixes, refusing to load if
    there was nothing to change. Why it is rf-reactor itself and not a copy is in that probe's help.

    WHAT IS BUILT, ONCE, ON THE SHIPPED BOX

      solo     One rf-heater, -Pipes rf-pipe and one rf-reactor. The heater's feed is unbounded and
               reactor energy is drained as it arrives.
      pair     The same, then -Bridge more rf-pipe from the reactor's east face into a second one.
               ONLY THE FIRST IS ON AN ELECTRIC NETWORK (asserted): an unpowered reactor steps with
               its heating clamped to zero, so any heat it holds came along the pipe.

      both     With -Both only: the pair again with its second reactor powered too (asserted to be
               on an electric network), built last so no other cell's segment id moves (#561).

    NOTHING IS RESEARCHED, asserted rung by rung at build and again at each load.

    THE THREE RUNS

      save     The map is created and ticked to -SaveAt with the canary named DISABLED, then
               game.server_save writes it -- see the comment where it runs for why a server. The
               save lands a few ticks after the call; which tick it holds is read off the loads.
      control  That save loaded with the canary still named disabled. Any change here is the save
               and load itself, not the box.
      canary   The same save loaded with the canary named ENABLED.

    Each run names the canary either way, never leaves it out, because Factorio auto-enables a mod
    on disk that mod-list.json does not name, and --benchmark loads a save whose mods are missing
    without complaint. So each run also prints production_type off the runtime prototype on its
    first tick, which is the reading that says which box the run had.

    WHAT IS READ, per reactor: its box, the box's temperature, the segment beside it read through
    the first pipe, the box's segment id, and the heater's output box. Stages: "save" on tick
    -SaveAt; "after" on each of the ten ticks after it, because server_save lands a few ticks
    late and the save holds one of those; "loaded" in on_configuration_changed, before any tick
    and only where the mod set changed; "first" and "next" on the first two ticks of each run;
    and "row" every -Every ticks. on_tick runs before the tick's entity update, so "first" reads
    the state as saved and "next" the first tick the engine has moved fluid in.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER SaveAt
    The tick the save is made on. The default is past the 71 295 that probe-plasma-input-box.ps1
    read for a three-pipe shipped box to reach 99.9%.

.PARAMETER LoadTicks
    Ticks to run each load for.

.PARAMETER Pipes
    rf-pipe from each heater to its reactor, 3 to 12.

.PARAMETER Bridge
    rf-pipe between the pair's reactors. 11 is the fewest that keeps the second outside the first
    one's substation.

.PARAMETER Both
    Also build the pair with both reactors powered.

.PARAMETER Every
    Ticks between sampled rows.

.PARAMETER KeepTemp
    Keep the saves, the rig mods and the captured output.

.EXAMPLE
    pwsh -File scripts/probe-plasma-box-save.ps1
    pwsh -File scripts/probe-plasma-box-save.ps1 -SaveAt 2000 -LoadTicks 2000 -Every 500
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [ValidateRange(60, 2000000)]  [int] $SaveAt    = 80000,
    [ValidateRange(60, 2000000)]  [int] $LoadTicks = 40000,
    [ValidateRange(3, 12)]        [int] $Pipes     = 3,
    [ValidateRange(11, 40)]       [int] $Bridge    = 12,
    [ValidateRange(10, 100000)]   [int] $Every     = 2000,
    [switch] $Both,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot   = Split-Path $PSScriptRoot -Parent
$ourMods    = Get-RepoMods
$rigName    = 'rf-box-save-probe'
$canaryName = 'rf-input-box-canary'
$saveName   = 'rf-box-save'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp      = Join-Path ([IO.Path]::GetTempPath()) ('rf-bsave-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir    = Join-Path $temp 'mods'
$rigDir    = Join-Path $modDir $rigName
$canaryDir = Join-Path $modDir $canaryName
New-Item -ItemType Directory -Path $rigDir, $canaryDir -Force | Out-Null

@{
    name = $rigName; version = '0.0.1'; title = 'Plasma box save probe'
    author = 'probe-plasma-box-save.ps1'; factorio_version = '2.0'
    dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed')
} | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8
@{
    name = $canaryName; version = '0.0.1'; title = 'Plasma input-box canary'
    author = 'probe-plasma-box-save.ps1'; factorio_version = '2.0'
    dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed')
} | ConvertTo-Json | Set-Content -Path (Join-Path $canaryDir 'info.json') -Encoding utf8

# THE CANARY, as probe-plasma-input-box.ps1 writes it.
Set-Content -Encoding utf8 -Path (Join-Path $canaryDir 'data-final-fixes.lua') -Value @'
-- Generated by probe-plasma-box-save.ps1. Nothing here ships.
local box = data.raw.boiler["rf-reactor"].fluid_box
if box.production_type ~= "input-output" then
  error("input-box canary: rf-reactor's plasma box is '" .. tostring(box.production_type)
    .. "', not input-output, so there is nothing for the canary to change")
end
box.production_type = "input"
'@

$lua = @'
-- Generated by probe-plasma-box-save.ps1. Reports; asserts nothing about the answer.

local PIPES     = __PIPES__
local BRIDGE    = __BRIDGE__
local BOTH      = __BOTH__
local EVERY     = __EVERY__
local SAVE_AT   = __SAVEAT__
local SAVE_NAME = "__SAVENAME__"
local ENERGY_FEED = "__ENERGYFEED__"
local PLASMA  = "rf-d-d-plasma"
local REACTOR = "rf-reactor"

local logic  = require("__realistic-fusion-refreshed__/scripts/reactor-logic")
local ENERGY = logic.reactor.energy_fluid

local function say(fmt, ...) log("BSAVEPROBE " .. string.format(fmt, ...)) end

__RIGBUILD__

__QUIETMAP__

-- Not in storage, so 0 again on every load: the first ticks of each run are recognised.
local session_ticks = 0
-- The tick this session called server_save on. The save lands a few ticks later, so the state it
-- holds is read on each of the ticks after it; the load's "first" row says which one it was.
local saved_on

local function segment_of(entity)
  local total = 0
  for _, amount in pairs(entity.fluidbox.get_fluid_segment_contents(1) or {}) do total = total + amount end
  return total
end

local function production_type() return prototypes.entity[REACTOR].fluidbox_prototypes[1].production_type end

local function assert_research()
  rf_assert_research(function(ok, name, detail)
    if not ok then error(name .. " -- " .. detail) end
    say("research %s", name)
  end, game.forces.player, logic, logic.reactor, false)
end

local function reactor_at(surface, force, x)
  local reactor = rf_place_or_die(surface,
    { name = REACTOR, position = { x, 0.5 }, force = force, raise_built = true }, REACTOR)
  if rf_box_of(reactor, ENERGY) ~= 2 then error(REACTOR .. "'s boxes are not where they were") end
  local out = reactor.fluidbox.get_pipe_connections(2)[1]
  local drain = rf_place_or_die(surface,
    { name = ENERGY_FEED, position = out.target_position, force = force }, "the energy drain")
  drain.set_infinity_pipe_filter({ name = ENERGY, percentage = 0, mode = "at-most" })
  return reactor
end

local function first_pipe(surface, force, from, step, count)
  rf_pipe_run(surface, force, "rf-pipe", from, step, count)
  return surface.find_entity("rf-pipe", from) or error(string.format("no rf-pipe at (%g, %g)", from[1], from[2]))
end

--- One heater, PIPES pipes and a reactor; with `bridge`, a second reactor that many pipes east.
local function power(surface, force, x, dx)
  rf_place_or_die(surface, { name = "substation", position = { x + dx, 5 }, force = force },
    "a substation")
  local eei = rf_place_or_die(surface, { name = "electric-energy-interface",
    position = { x + dx + (dx > 0 and 2.5 or -2.5), 5.5 }, force = force }, "a power source")
  eei.power_production = 8e6
end

local function build(surface, force, ox, label, bridge, both)
  for _, dx in ipairs({ 9, -9 }) do power(surface, force, ox, dx) end
  local first = reactor_at(surface, force, ox + 0.5)
  -- rf-reactor's west plasma connection is 7 tiles out, so the first pipe is 8.
  local west = { ox + 0.5 - 8, 0.5 }
  local side = first_pipe(surface, force, west, { -1, 0 }, PIPES)
  local heater = rf_place_facing(surface, force, {
    name = "rf-heater", fluid = PLASMA,
    prepare = function(entity) entity.set_recipe(PLASMA) end,
    target = { west[1] - (PIPES - 1), west[2] }, seed = { ox - 24.5, 20.5 },
  })
  local feed = prototypes.recipe[PLASMA].ingredients[1].name
  rf_unbound(surface, force, heater, rf_box_of(heater, feed),
    { name = feed, percentage = 1, mode = "at-least" })
  if not (heater.electric_network_id and first.electric_network_id) then
    error("a machine in the " .. label .. " cell is on no electric network")
  end

  local cell = { label = label, heater = heater, out = rf_box_of(heater, PLASMA),
    reactors = { first }, sides = { side } }
  if bridge then
    local east = { ox + 0.5 + 8, 0.5 }
    local span = first_pipe(surface, force, east, { 1, 0 }, bridge)
    local second = reactor_at(surface, force, east[1] + (bridge - 1) + 8)
    if both then
      power(surface, force, second.position.x - 0.5, 9)
      if not second.electric_network_id then error("the " .. label .. " cell's second reactor is unpowered") end
    -- THE DISCRIMINATOR: what heats this one arrived along the pipe.
    elseif second.electric_network_id then
      error("the pair's second reactor is on an electric network, so its heat would not say pooling")
    end
    cell.reactors[2], cell.sides[2] = second, span
  end
  return cell
end

local function read(stage)
  for _, cell in ipairs(storage.cells) do
    local out = cell.heater.fluidbox[cell.out]
    for r, reactor in ipairs(cell.reactors) do
      local plasma = reactor.fluidbox[1]
      say("read stage=%s cell=%s r=%d tick=%d box=%.9g temp=%.9g cap=%g seg=%.9g segid=%s heater=%.9g",
        stage, cell.label, r, game.tick, plasma and plasma.amount or 0, plasma and plasma.temperature or 0,
        reactor.fluidbox.get_capacity(1), segment_of(cell.sides[r]),
        tostring(reactor.fluidbox.get_fluid_segment_id(1)), out and out.amount or 0)
    end
  end
end

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player

  force.research_all_technologies()
  rf_unresearch(force, logic, logic.reactor, nil)
  assert_research()

  surface.request_to_generate_chunks({ 100, 0 }, 8)
  surface.force_generate_chunk_requests()
  storage.quieted = __QUIETFN__(surface)
  local clear = { { -60, -40 }, { BOTH and 300 or 200, 40 } }
  local tiles = {}
  for x = clear[1][1], clear[2][1] do
    for y = clear[1][2], clear[2][2] do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = clear })) do
    if e.type ~= "character" then e.destroy() end
  end

  storage.cells = { build(surface, force, 0, "solo", nil), build(surface, force, 100, "pair", BRIDGE) }
  if BOTH then storage.cells[3] = build(surface, force, 200, "both", BRIDGE, true) end
  say("built production_type=%s", production_type())
end)

script.on_configuration_changed(function(changes)
  if not storage.cells then return end
  local added = {}
  for name, change in pairs(changes.mod_changes or {}) do
    if not change.old_version then added[#added + 1] = name end
  end
  say("changed tick=%d added=%s production_type=%s", game.tick, table.concat(added, ","), production_type())
  assert_research()
  read("loaded")
end)

script.on_event(defines.events.on_tick, function()
  if not storage.cells then return end
  local tick = game.tick
  for _, cell in ipairs(storage.cells) do
    for _, reactor in ipairs(cell.reactors) do
      if not reactor.valid then error("the " .. cell.label .. " cell lost a reactor") end
    end
  end
  session_ticks = session_ticks + 1
  -- on_tick runs before the tick's entity update, so "first" is the state as loaded and "next"
  -- is the first tick the engine has moved fluid under whatever box this run has.
  if session_ticks == 2 then read("next") end
  if session_ticks == 1 then
    say("session tick=%d production_type=%s", tick, production_type())
    read("first")
    -- The save run is a headless server, which ticks at 60 UPS unless told otherwise.
    if not storage.saved then game.speed = 1000 end
  end
  if tick % EVERY == 0 then read("row") end
  if saved_on and tick > saved_on and tick <= saved_on + 10 then read("after") end
  if tick == SAVE_AT and not storage.saved then
    storage.saved = tick
    read("save")
    game.speed = 1
    game.server_save(SAVE_NAME)
    saved_on = tick
    say("saved tick=%d", tick)
  end
end)
'@

$inv = [cultureinfo]::InvariantCulture
# Every figure prints with a point, whatever the machine's culture says, so a row can be quoted as is.
[cultureinfo]::CurrentCulture = $inv
$lua = $lua.
    Replace('__RIGBUILD__', (Get-RigBuildLua)).
    Replace('__QUIETMAP__', (Get-QuietMapLua)).
    Replace('__QUIETFN__', $script:QuietMapFunction).
    Replace('__PIPES__', "$Pipes").
    Replace('__BRIDGE__', "$Bridge").
    Replace('__BOTH__', $(if ($Both) { 'true' } else { 'false' })).
    Replace('__EVERY__', "$Every").
    Replace('__SAVEAT__', "$SaveAt").
    Replace('__SAVENAME__', $saveName).
    Replace('__ENERGYFEED__', (Write-EnergyFeed -RigDirectory $rigDir))
Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') -Value $lua

$invoke = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

function Set-Canary {
    param([switch] $Enabled)
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled @() `
        -Mods ($ourMods + $rigName + @(if ($Enabled) { $canaryName })) `
        -Disabled @(if (-not $Enabled) { $canaryName })
}

function Write-Run {
    <#  What one run printed: the game's own lines that mention the box or complain, then the
        probe's rows as the game logged them.  #>
    param([Parameter(Mandatory)] [string] $Tag, [Parameter(Mandatory)] [object] $Result)

    Write-Host ''
    Write-Host "##### $Tag -- Factorio exited $($Result.Code)"
    $lines = @(Get-Content $Result.OutFile) + @(Get-Content $Result.ErrFile)
    $said = @($lines | Where-Object {
        $_ -notmatch 'BSAVEPROBE' -and $_ -match '(?i)\b(warning|error)|fluid|rf-reactor|plasma|migrat|production' })
    Write-Host ("  {0} line(s) from the game naming a warning, an error, a fluid, the reactor, plasma, a migration or production" -f $said.Count)
    foreach ($s in $said) { Write-Host "    $s" }
    if ($Result.Code -ne 0) { Write-FactorioTail $Result; return }
    $research = @($lines | Where-Object { $_ -match 'BSAVEPROBE research ' })
    Write-Host "  research: $($research.Count) rung assertion(s) logged, every ladder OFF"
    foreach ($l in $lines) {
        if ($l -match 'BSAVEPROBE (?!research )(.*)$') { Write-Host "  $($Matches[1])" }
    }
}

try {
    New-ModJunctions -ModDirectory $modDir -Links (Get-ModLinks -Root $repoRoot -Mods $ourMods)

    Set-Canary
    $map = Join-Path $temp 'map.zip'
    $create = Invoke-Factorio @invoke -Arguments @('--create', $map) -Tag 'create'
    Write-Run -Tag 'create (canary named disabled)' -Result $create
    if ($create.Code -ne 0) { throw "the map was not created (exit $($create.Code)), so the rig is broken." }

    # --benchmark NEVER SAVES, and game.auto_save under it writes nothing (tried 2026-10-04 on
    # 2.0.77). So the fill runs as a headless server that saves itself with game.server_save, and
    # is killed once the game has logged the save finished. No player ever joins it.
    $settings = Join-Path $temp 'server-settings.json'
    @{ name = 'rf-box-save-probe'; description = ''; visibility = @{ public = $false; lan = $false }
       require_user_verification = $false; auto_pause = $false; autosave_interval = 0 } |
        ConvertTo-Json | Set-Content -Path $settings -Encoding utf8
    # server_save refuses outright when the directory it writes into does not exist yet.
    New-Item -ItemType Directory -Path (Join-Path $temp 'write-data/saves') -Force | Out-Null
    $fill = [pscustomobject]@{ Code = 0; OutFile = (Join-Path $temp 'save-stdout.txt'); ErrFile = (Join-Path $temp 'save-stderr.txt') }
    # The port stays under 49152: Windows reserves ranges of the dynamic ports above it, and a
    # server bound into one exits with error 10013 before it ticks (seen 2026-10-05, port 54883).
    $line = (@('--config', (Join-Path $temp 'factorio-config.ini'), '--mod-directory', $modDir,
               '--start-server', $map, '--server-settings', $settings, '--port', "$(Get-Random -Minimum 35000 -Maximum 49000)") |
        ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '
    $server = Start-Process -FilePath $FactorioExe -ArgumentList $line -PassThru -NoNewWindow `
        -RedirectStandardOutput $fill.OutFile -RedirectStandardError $fill.ErrFile
    try {
        $deadline = (Get-Date).AddMinutes(120)
        while (-not (Select-String -Path $fill.OutFile -Pattern 'Saving finished' -Quiet) -and (Get-Date) -lt $deadline) {
            if ($server.HasExited) { $fill.Code = $server.ExitCode; break }
            Start-Sleep -Seconds 1
        }
    }
    finally { Stop-LaunchedGame -Process $server -Label 'probe-plasma-box-save' }
    Write-Run -Tag "save (a headless server, canary named disabled, ticked to $SaveAt, then server_save)" -Result $fill
    $save = Get-ChildItem -Path (Join-Path $temp 'write-data') -Recurse -Filter "$saveName.zip" | Select-Object -First 1
    if (-not $save) { throw "game.server_save wrote no $saveName.zip under write-data, so there is nothing to load." }
    Write-Host "  the save: $($save.FullName.Substring($temp.Length + 1)), $($save.Length) bytes"

    foreach ($variant in @(@{ Tag = 'control'; Enabled = $false }, @{ Tag = 'canary'; Enabled = $true })) {
        Set-Canary -Enabled:$variant.Enabled
        $load = Invoke-Factorio @invoke -Tag $variant.Tag -Arguments @(
            '--benchmark', $save.FullName, '--benchmark-ticks', "$LoadTicks", '--benchmark-runs', '1', '--disable-audio')
        Write-Run -Tag "$($variant.Tag) (the save loaded, canary named $(if ($variant.Enabled) { 'enabled' } else { 'disabled' }))" -Result $load
    }

    $version = 'unknown'
    $hit = Get-Content $create.OutFile | Select-String -Pattern 'Factorio (\d+\.\d+\.\d+) \(build (\d+)' | Select-Object -First 1
    if ($hit) { $version = "$($hit.Matches[0].Groups[1].Value) (build $($hit.Matches[0].Groups[2].Value))" }
    Write-Host ''
    Write-Host "Factorio $version -- saved on tick $SaveAt, each load run for $LoadTicks ticks, rows every $Every"
    Write-Host "one heater per cell, rf-d-d-plasma; $Pipes pipe(s) to each first reactor, $Bridge between the pair's"
    Write-Host 'OK - the probe ran. The figures above are measurements, not a verdict.'
    Write-Host '     docs/research/plasma-input-box.md is what they are read into.'
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'probe-plasma-box-save' }
}

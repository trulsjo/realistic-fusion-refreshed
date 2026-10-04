<#
.SYNOPSIS
    Runs one fuel-line rig twice: once on rf-reactor as shipped, with an "input-output" plasma box,
    and once under a canary that makes that box "input". Reports the fill, the settled box, whether
    control.lua still writes the box, and whether two bridged reactors still share one pool (#542).

.DESCRIPTION
    A PROBE, NOT A CHECK. Every line it prints is a measurement, and exit 0 means the probe ran and
    every row reported, never that the answer was the one anybody hoped for. A canary that refuses
    to load is a reading too, and is reported rather than thrown. It must not be added to a check
    sweep or to load-check.ps1. docs/research/plasma-input-box.md is what its rows are read into.

    WHY THE CANARY IS rf-reactor ITSELF AND NOT A COPY BESIDE IT. control.lua recognises a reactor
    by prototype NAME, twice: entity-management.lua's REACTORS decides what is registered, and
    control.lua's SPECS what it is simulated with, and check_reactor_specs() refuses to load if the
    two disagree. A copy under another name is never registered and never stepped -- it would be a
    pipe-shaped tank, which is not what the issue asks about. So the canary mod edits rf-reactor's
    box in its own data-final-fixes and the two variants are two runs of the SAME rig, one with the
    canary enabled and one with it named disabled.

    WHAT IS BUILT, IN EACH RUN

      solo     One cell per entry of -Pipes: one rf-heater, that many rf-pipe, one rf-reactor, the
               layout probe-plasma-segment.ps1 builds. The heater's feed is unbounded and reactor
               energy is drained as it arrives.
      pair     One rf-heater and -Pipes' first count of rf-pipe into a reactor, and -Bridge more
               rf-pipe from its east face into a second. ONLY THE FIRST IS ON AN ELECTRIC NETWORK
               (asserted), check-pooling.ps1's discriminator: an unpowered reactor steps with its
               heating clamped to zero, so any heat it holds came along the pipe.

    NOTHING IS RESEARCHED, and that is asserted rung by rung (rf_assert_research).

    WHAT IS READ

      every -Every ticks  each reactor's box and temperature, and what the segment beside it holds
                          -- the heater-side run through its first pipe, the bridge through its
                          first pipe -- and the segment id of every box and run, so "one segment"
                          is read off the engine rather than assumed. The ids are printed at build
                          and at the last sample.
      every tick          the box before control.lua's handler and after it, by the same pair of rig
                          mods probe-plasma-segment.ps1 uses. A difference on a step tick is the mod
                          writing the box; one on any other tick fails the run, because then the two
                          readings do not bracket the step. The first tick each box reaches -FullAt
                          of its capacity is kept.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Ticks
    Ticks to run, from an empty line, per variant.

.PARAMETER Pipes
    Pipe counts, comma-separated, one solo cell each, 3 to 12. The pair uses the first.

.PARAMETER Bridge
    Pipes between the pair's two reactors. 11 is the fewest that keeps the second reactor outside
    the first one's substation.

.PARAMETER Every
    Ticks between sampled rows.

.PARAMETER FullAt
    The fraction of a box's capacity that counts as full.

.PARAMETER KeepTemp
    Keep the saves, the rig mods and the captured output.

.EXAMPLE
    pwsh -File scripts/probe-plasma-input-box.ps1
    pwsh -File scripts/probe-plasma-input-box.ps1 -Pipes 3 -Ticks 40000 -Every 1000
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [ValidateRange(600, 2000000)] [int] $Ticks = 100000,
    # Comma-separated strings, not [int[]]: pwsh -File hands "3,6" over as one string.
    [ValidatePattern('^\d+(,\d+)*$')] [string] $Pipes = '3,6',
    [ValidateRange(11, 40)]       [int]    $Bridge = 12,
    [ValidateRange(60, 100000)]   [int]    $Every  = 4000,
    [ValidateRange(0.5, 1.0)]     [double] $FullAt = 0.999,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot   = Split-Path $PSScriptRoot -Parent
$ourMods    = Get-RepoMods
$rigName    = 'rf-input-box-probe'
# No dependency on ours and a name that sorts ahead of it, so its on_tick runs before the mod's.
$preName    = 'a-rf-input-box-pre'
$canaryName = 'rf-input-box-canary'
$pipeCounts = @($Pipes -split ',' | ForEach-Object { [int] $_ })
if (@($pipeCounts | Sort-Object -Unique).Count -ne $pipeCounts.Count) { throw "-Pipes names a count twice: $Pipes" }
foreach ($count in $pipeCounts) {
    if ($count -lt 3 -or $count -gt 12) { throw "-Pipes $count is outside 3 to 12." }
}
if ($Every -ge $Ticks) { throw "-Every $Every is not less than -Ticks $Ticks, so no row would be sampled." }

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp      = Join-Path ([IO.Path]::GetTempPath()) ('rf-ibox-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir    = Join-Path $temp 'mods'
$rigDir    = Join-Path $modDir $rigName
$preDir    = Join-Path $modDir $preName
$canaryDir = Join-Path $modDir $canaryName
New-Item -ItemType Directory -Path $rigDir, $preDir, $canaryDir -Force | Out-Null

@{
    name = $rigName; version = '0.0.1'; title = 'Plasma input-box probe'
    author = 'probe-plasma-input-box.ps1'; factorio_version = '2.0'
    dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed', $preName)
} | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8
@{
    name = $preName; version = '0.0.1'; title = 'Plasma input-box probe, the reading before the step'
    author = 'probe-plasma-input-box.ps1'; factorio_version = '2.0'
    dependencies = @('base >= 2.0.77')
} | ConvertTo-Json | Set-Content -Path (Join-Path $preDir 'info.json') -Encoding utf8
@{
    name = $canaryName; version = '0.0.1'; title = 'Plasma input-box canary'
    author = 'probe-plasma-input-box.ps1'; factorio_version = '2.0'
    dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed')
} | ConvertTo-Json | Set-Content -Path (Join-Path $canaryDir 'info.json') -Encoding utf8

# THE CANARY: the one field the issue asks about, and nothing else. It asserts there was something
# to change, so a canary that matched nothing cannot read as "input changes nothing".
Set-Content -Encoding utf8 -Path (Join-Path $canaryDir 'data-final-fixes.lua') -Value @'
-- Generated by probe-plasma-input-box.ps1. Nothing here ships.
local box = data.raw.boiler["rf-reactor"].fluid_box
if box.production_type ~= "input-output" then
  error("input-box canary: rf-reactor's plasma box is '" .. tostring(box.production_type)
    .. "', not input-output, so there is nothing for the canary to change")
end
box.production_type = "input"
'@

Set-Content -Encoding utf8 -Path (Join-Path $preDir 'control.lua') -Value @'
-- Generated by probe-plasma-input-box.ps1. Nothing here ships.
-- Reads each watched reactor's plasma box BEFORE realistic-fusion-refreshed steps it this tick.
remote.add_interface("rf-input-box-pre", {
  watch = function(reactors) storage.watch = reactors end,
  read  = function() return storage.pre end,
})
script.on_event(defines.events.on_tick, function()
  if not storage.watch then return end
  local pre = {}
  for i, reactor in ipairs(storage.watch) do
    local plasma = reactor.fluidbox[1]
    pre[i] = plasma and plasma.amount or 0
  end
  storage.pre = pre
end)
'@

$lua = @'
-- Generated by probe-plasma-input-box.ps1. Reports; asserts nothing about the answer.

local PIPES   = { __PIPES__ }
local BRIDGE  = __BRIDGE__
local EVERY   = __EVERY__
local FULL_AT = __FULLAT__
local ENERGY_FEED = "__ENERGYFEED__"
local PLASMA  = "rf-d-d-plasma"
local REACTOR = "rf-reactor"
local PITCH   = 100
-- control.lua's UPDATE_INTERVAL; only the instrument's own check reads it.
local STEP_TICKS = 6

local logic  = require("__realistic-fusion-refreshed__/scripts/reactor-logic")
local ENERGY = logic.reactor.energy_fluid

local function say(fmt, ...) log("IBOXPROBE " .. string.format(fmt, ...)) end

__RIGBUILD__

__QUIETMAP__

local function segment_of(entity)
  local total = 0
  for _, amount in pairs(entity.fluidbox.get_fluid_segment_contents(1) or {}) do total = total + amount end
  return total
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

local function pipes_from(surface, force, from, step, count)
  rf_pipe_run(surface, force, "rf-pipe", from, step, count)
  local pipes = {}
  for i = 0, count - 1 do
    local at = { from[1] + step[1] * i, from[2] + step[2] * i }
    pipes[#pipes + 1] = surface.find_entity("rf-pipe", at)
      or error(string.format("no rf-pipe at (%g, %g)", at[1], at[2]))
  end
  return pipes
end

--- One heater, `pipe_count` pipes and a reactor; with `bridge`, a second reactor that many pipes east.
local function build(surface, force, ox, label, pipe_count, bridge)
  for _, dx in ipairs({ 9, -9 }) do
    rf_place_or_die(surface, { name = "substation", position = { ox + dx, 5 }, force = force },
      "a substation")
    local eei = rf_place_or_die(surface, { name = "electric-energy-interface",
      position = { ox + dx + (dx > 0 and 2.5 or -2.5), 5.5 }, force = force }, "a power source")
    eei.power_production = 8e6
  end
  local first = reactor_at(surface, force, ox + 0.5)
  -- rf-reactor's west plasma connection is 7 tiles out, so the first pipe is 8.
  local west = { ox + 0.5 - 8, 0.5 }
  local run = pipes_from(surface, force, west, { -1, 0 }, pipe_count)
  local heater = rf_place_facing(surface, force, {
    name = "rf-heater", fluid = PLASMA,
    prepare = function(entity) entity.set_recipe(PLASMA) end,
    target = { west[1] - (pipe_count - 1), west[2] }, seed = { ox - 24.5, 20.5 },
  })
  local feed = prototypes.recipe[PLASMA].ingredients[1].name
  rf_unbound(surface, force, heater, rf_box_of(heater, feed),
    { name = feed, percentage = 1, mode = "at-least" })
  if not (heater.electric_network_id and first.electric_network_id) then
    error("a machine in the " .. label .. " cell is on no electric network")
  end

  local cell = { label = label, reactors = { first }, sides = { run[1] }, run = run }
  if bridge then
    local east = { ox + 0.5 + 8, 0.5 }
    local span = pipes_from(surface, force, east, { 1, 0 }, bridge)
    local second = reactor_at(surface, force, east[1] + (bridge - 1) + 8)
    -- THE DISCRIMINATOR: what heats this one arrived along the pipe.
    if second.electric_network_id then
      error("the pair's second reactor is on an electric network, so its heat would not say pooling")
    end
    cell.reactors[2] = second
    cell.sides[2] = span[1]
    cell.span = span
  end
  return cell
end

local function ids(cell)
  local parts = {}
  for r, reactor in ipairs(cell.reactors) do
    parts[#parts + 1] = string.format("box%d=%s", r, tostring(reactor.fluidbox.get_fluid_segment_id(1)))
  end
  parts[#parts + 1] = "run=" .. tostring(cell.run[1].fluidbox.get_fluid_segment_id(1))
  if cell.span then parts[#parts + 1] = "bridge=" .. tostring(cell.span[1].fluidbox.get_fluid_segment_id(1)) end
  return table.concat(parts, " ")
end

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player

  force.research_all_technologies()
  rf_unresearch(force, logic, logic.reactor, nil)
  rf_assert_research(function(ok, name, detail)
    if not ok then error(name .. " -- " .. detail) end
    say("research %s", name)
  end, force, logic, logic.reactor, false)

  local east = (#PIPES + 1) * PITCH
  surface.request_to_generate_chunks({ east / 2, 0 }, math.ceil(east / 32) + 4)
  surface.force_generate_chunk_requests()
  storage.quieted = __QUIETFN__(surface)
  local clear = { { -60, -40 }, { east, 40 } }
  local tiles = {}
  for x = clear[1][1], clear[2][1] do
    for y = clear[1][2], clear[2][2] do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = clear })) do
    if e.type ~= "character" then e.destroy() end
  end

  local cells, watch, tracked = {}, {}, {}
  for i, pipe_count in ipairs(PIPES) do
    cells[#cells + 1] = build(surface, force, (i - 1) * PITCH, "solo" .. pipe_count, pipe_count, nil)
  end
  cells[#cells + 1] = build(surface, force, #PIPES * PITCH, "pair" .. PIPES[1], PIPES[1], BRIDGE)
  for _, cell in ipairs(cells) do
    for r, reactor in ipairs(cell.reactors) do
      watch[#watch + 1] = reactor
      tracked[#tracked + 1] = { cell = cell, r = r, reactor = reactor, side = cell.sides[r],
        cap = reactor.fluidbox.get_capacity(1), writes = 0, steps = 0 }
    end
  end
  remote.call("rf-input-box-pre", "watch", watch)
  storage.cells, storage.tracked = cells, tracked
  local production = prototypes.entity[REACTOR].fluidbox_prototypes[1].production_type
  say("built cells=%d quieted=%d production_type=%s", #cells, storage.quieted, production)
  for _, t in ipairs(tracked) do
    say("reactor cell=%s r=%d box_cap=%g side_cap=%g powered=%s", t.cell.label, t.r, t.cap,
      t.side.fluidbox.get_capacity(1), tostring(t.reactor.electric_network_id ~= nil))
  end
  for _, cell in ipairs(cells) do say("ids cell=%s tick=%d %s", cell.label, game.tick, ids(cell)) end
end)

script.on_event(defines.events.on_tick, function()
  local tick = game.tick
  local pre = remote.call("rf-input-box-pre", "read")
  if not pre then return end
  local sample = tick % EVERY == 0
  for i, t in ipairs(storage.tracked) do
    if not t.reactor.valid then error("the " .. t.cell.label .. " cell lost a reactor mid-run") end
    local plasma = t.reactor.fluidbox[1]
    local box = plasma and plasma.amount or 0
    if tick % STEP_TICKS == 0 then
      t.steps = t.steps + 1
      if pre[i] ~= box then t.writes = t.writes + 1 end
    elseif pre[i] ~= box then
      -- THE INSTRUMENT'S OWN CHECK: only the mod's step may come between the two readings.
      error(string.format("tick %d: the %s cell's box %d read %.9g before the mod and %.9g after "
        .. "it on a tick it does not step on", tick, t.cell.label, t.r, pre[i], box))
    end
    if not t.full and box >= FULL_AT * t.cap then t.full = tick end
    if sample then
      say("row cell=%s r=%d tick=%d box=%.9g temp=%.9g seg=%.9g writes=%d steps=%d full=%s",
        t.cell.label, t.r, tick, box, plasma and plasma.temperature or 0, segment_of(t.side),
        t.writes, t.steps, tostring(t.full or "never"))
    end
  end
  if sample then
    for _, cell in ipairs(storage.cells) do say("ids cell=%s tick=%d %s", cell.label, tick, ids(cell)) end
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
    Replace('__PIPES__', ($pipeCounts -join ', ')).
    Replace('__BRIDGE__', "$Bridge").
    Replace('__EVERY__', "$Every").
    Replace('__FULLAT__', $FullAt.ToString($inv)).
    Replace('__ENERGYFEED__', (Write-EnergyFeed -RigDirectory $rigDir))
Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') -Value $lua

$invoke = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

function Read-Records {
    param([string[]] $Lines, [string] $Kind)
    foreach ($line in $Lines) {
        if ($line -notmatch "IBOXPROBE $Kind ") { continue }
        $f = @{}
        foreach ($m in [regex]::Matches($line, '(\w+)=([^\s]+)')) { $f[$m.Groups[1].Value] = $m.Groups[2].Value }
        $f
    }
}
function Num { param($Value) [double]::Parse($Value, $inv) }

function Invoke-Variant {
    <#  One run of the rig, with the canary named enabled or named disabled -- never merely left
        out, because Factorio auto-enables a mod on disk that mod-list.json does not name.  #>
    param([Parameter(Mandatory)] [string] $Tag, [switch] $WithCanary)

    $mods = $ourMods + $rigName + $preName + @(if ($WithCanary) { $canaryName })
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled @() -Mods $mods `
        -Disabled @(if (-not $WithCanary) { $canaryName })
    $save   = Join-Path $temp "$Tag.zip"
    $create = Invoke-Factorio @invoke -Arguments @('--create', $save) -Tag "$Tag-create"
    if ($create.Code -ne 0) { return @{ Tag = $Tag; Code = $create.Code; Create = $create } }
    $runOut = Invoke-FactorioStep @invoke -Tag "$Tag-run" -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', "$Ticks", '--benchmark-runs', '1', '--disable-audio')
    return @{ Tag = $Tag; Code = 0; Create = $create; Created = @(Get-Content $create.OutFile); Ran = @(Get-Content $runOut) }
}

function Write-Variant {
    param([Parameter(Mandatory)] [hashtable] $Run)

    Write-Host ''
    Write-Host "##### $($Run.Tag)"
    if ($Run.Code -ne 0) {
        Write-Host "  the map was not created: Factorio exited $($Run.Code). The tail of its output:"
        Write-FactorioTail $Run.Create
        return
    }
    # WHAT THE GAME SAID. Every line naming a warning or an error outside the probe's own rows,
    # from both the create and the run.
    $complaints = @(($Run.Created + $Run.Ran) | Where-Object { $_ -match '(?i)\b(warning|error)' -and $_ -notmatch 'IBOXPROBE' })
    Write-Host ("  load: map created, exit 0; {0} line(s) naming a warning or an error" -f $complaints.Count)
    foreach ($c in $complaints) { Write-Host "    $c" }
    $built = @(Read-Records $Run.Created 'built')[0]
    Write-Host "  rf-reactor's box 1 production_type, as the runtime prototype reads: $($built['production_type'])"
    $research = @($Run.Created | Select-String -Pattern 'IBOXPROBE research ')
    Write-Host "  research: $($research.Count) rung(s) asserted, every ladder OFF"

    # The segment ids at build and at the last sample, per cell.
    $idRows = @(Read-Records $Run.Created 'ids') + @(Read-Records $Run.Ran 'ids')
    foreach ($cell in ($idRows | ForEach-Object { $_['cell'] } | Select-Object -Unique)) {
        $of = @($idRows | Where-Object { $_['cell'] -eq $cell })
        foreach ($id in @($of[0]) + @(if ($of.Count -gt 1) { $of[-1] })) {
            Write-Host ("  segment ids, {0} at tick {1}: {2}" -f $cell, $id['tick'],
                (($id.Keys | Where-Object { $_ -notin 'cell', 'tick' } | Sort-Object | ForEach-Object { "$_=$($id[$_])" }) -join ' '))
        }
    }

    $rows = @(Read-Records $Run.Ran 'row')
    foreach ($r in @(Read-Records $Run.Created 'reactor')) {
        $cell = $r['cell']; $n = $r['r']
        $mine = @($rows | Where-Object { $_['cell'] -eq $cell -and $_['r'] -eq $n })
        if ($mine.Count -eq 0) { throw "$($Run.Tag): $cell reactor $n reported no row." }
        $end = $mine[-1]
        Write-Host ''
        Write-Host ("  === {0}, reactor {1}: box {2}, the segment beside it reports {3}, powered {4}" -f
            $cell, $n, $r['box_cap'], $r['side_cap'], $r['powered'])
        Write-Host ("  the box first reached {0:P1} on tick {1}; to tick {2} control.lua changed it across its handler on {3} of {4} step ticks" -f
            $FullAt, $end['full'], $end['tick'], $end['writes'], $end['steps'])
        Write-Host ('  {0,8}{1,13}{2,13}{3,13}{4,11}' -f 'tick', 'box', 'segment', 'box degC', 'seg/1000')
        foreach ($row in $mine) {
            $box = Num $row['box']; $seg = Num $row['seg']
            Write-Host ('  {0,8}{1,13:F4}{2,13:F4}{3,13:E4}{4,11:F1}' -f [int]$row['tick'], $box, $seg,
                (Num $row['temp']), $(if ($box -gt 0) { 1000 * $seg / $box } else { 0 }))
        }
    }
}

try {
    New-ModJunctions -ModDirectory $modDir -Links (Get-ModLinks -Root $repoRoot -Mods $ourMods)
    $shipped = Invoke-Variant -Tag 'shipped'
    if ($shipped.Code -ne 0) {
        Write-FactorioTail $shipped.Create
        throw "the shipped variant did not create its map (exit $($shipped.Code)), so the rig is broken."
    }
    $canary = Invoke-Variant -Tag 'canary' -WithCanary

    $version = 'unknown'
    $hit = $shipped.Created | Select-String -Pattern 'Factorio (\d+\.\d+\.\d+) \(build (\d+)' | Select-Object -First 1
    if ($hit) { $version = "$($hit.Matches[0].Groups[1].Value) (build $($hit.Matches[0].Groups[2].Value))" }
    Write-Host ''
    Write-Host "Factorio $version -- $Ticks ticks per variant, one heater per cell, rf-d-d-plasma"
    Write-Host "solo cells at $Pipes pipe(s); the pair at $($pipeCounts[0]) pipe(s) to the first reactor and $Bridge between them"
    Write-Variant $shipped
    Write-Variant $canary

    Write-Host ''
    Write-Host 'OK - the probe ran and every row reported. The figures above are measurements, not a'
    Write-Host '     verdict. docs/research/plasma-input-box.md is what they are read into.'
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'probe-plasma-input-box' }
}

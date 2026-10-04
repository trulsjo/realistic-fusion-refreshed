<#
.SYNOPSIS
    Logs one heater's fuel line tick by tick -- the reactor's plasma box, every pipe, the segment
    they are in and the heater's output box -- and balances it over each heater cycle, so the
    reading that the box and the segment are two stores (#516) can be taken again (#520), on any
    of the four plasmas (#531, #532).

.DESCRIPTION
    A PROBE, NOT A CHECK. Every line it prints is a measurement, and exit 0 means the probe ran and
    every row reported, never that the answer was the one anybody hoped for. It must not be added to
    a check sweep or to load-check.ps1. docs/research/exchanger-coverage.md is what its rows are
    read into.

    WHAT IT CLOSES

    #516 found that three rf-pipe report a segment capacity of 1300, and that the segment holds that
    plasma BESIDE the 1000 rf-reactor's box reads. Two of the three readings behind that come from
    scripts/bench-mod-links.ps1. The third, a tick-by-tick balance over one heater cycle, came from a
    scratch copy of the bench that was thrown away. This is that reading, committed.

    WHAT IS BUILT. One cell per entry of -Pipes: one rf-heater, that many rf-pipe, and the reactor
    that burns -Plasma: rf-reactor, or rf-aneutronic-reactor and its 3000-unit box for the two
    helium-3 plasmas. The heater's feed is unbounded and reactor energy is removed as it arrives,
    so nothing but the fuel line limits the cell. NOTHING IS RESEARCHED unless -Rungs says otherwise, and either state is
    asserted rung by rung (rf_assert_research).

    WHAT IS LOGGED, EVERY TICK OF A SPAN. -From names where each span starts and -Span how long it
    is. Per tick: the box's amount and temperature, each pipe's, the segment's contents and
    capacity as LuaFluidBox answers them through a pipe, and the heater's output box.

    WHAT IS BALANCED, EVERY HEATER CYCLE OF THE RUN. A cycle runs from one finished craft to the
    next. Over each:

      fed      what the heater made, less what its own output box kept
      burned   what the reactor's step took, READ and not derived -- see below
      box      the growth of the reactor's box
      segment  the growth of the segment's contents
      pipes    the growth of the pipes' own amounts, summed

    and two residuals, fed - burned - box - segment and fed - burned - segment alone. The first
    closes if the box and the segment are two stores, the second if the segment's figure already
    counts the box. Both are printed and neither is asserted.

    HOW BURNED IS READ. control.lua writes the box on every sixth tick, and fluid moves after every
    script has run. So a script that runs BEFORE the mod's and one that runs AFTER it see the box
    on either side of the step, with no flow between. There are therefore two rig mods: one with no
    dependency on ours and a name that sorts ahead of it, which reads the box first, and the rig
    proper, which depends on ours and so reads it last. The difference on a step tick is the burn.
    On every other tick the two must agree, and the run fails if they do not; and a run in which
    they never differ at all fails too, because that is the first mod running after ours. Both are
    the instrument checking itself, not a claim about the answer.

    THE SPLIT. Each cycle also carries what the segment holds for every 1000 units in the box, and
    the pipes' temperature beside the box's. The report thins that to every -Every cycles through
    the whole run, so the split is seen from an empty line to a full one, and prints EVERY cycle
    ending inside -Dense (#530). It also names the cycle the box grew most in, and the first
    cycle to end at -FullAt of the box. On a fill that burns little of its feed the first of
    those is where the split steps from one branch to the other (#531). On one that burns most
    of it, a D-T cell or a researched D-D one, it is the first cycle to put plasma in the box.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Ticks
    Ticks to run, from an empty line. On D-D with nothing researched three pipes are full by
    about 72 000 and six by about 81 000. Helium-3 fills its 3000-unit box by about 152 000 and
    159 000, and a D-T line never fills: it has settled by about 108 000.

.PARAMETER Pipes
    Pipe counts, comma-separated, one cell each, 3 to 12. Three is the shortest line the bench
    builds, and so is it here.

.PARAMETER Plasma
    Which plasma the heater makes, and so which reactor burns it, as bench-mod-links.ps1's -Plasma
    picks a tier. rf-d-d-plasma, the default, and rf-d-t-plasma go to rf-reactor and its 1000-unit
    box; rf-d-he3-plasma and rf-he3-he3-plasma go to rf-aneutronic-reactor and its 3000. The
    heater's input is read off the recipe.

.PARAMETER From
    The first tick of each per-tick span, comma-separated. The defaults are early in the fill and
    near its end at three pipes, on D-D with nothing researched.

.PARAMETER Span
    Ticks in each span. A heater cycle is 120 ticks.

.PARAMETER Every
    Print the split at every this-many cycles through the run.

.PARAMETER Dense
    A tick range, from,to: every cycle ending inside it is printed as well, whatever -Every says.

.PARAMETER FullAt
    The fraction of the box the report looks for the first cycle to end at. 0.999 by default; a
    box that burns nearly all it is fed ends its cycles lower than that for a long time.

.PARAMETER Rungs
    Hold a chosen number of rungs per ladder instead of none, as bench-mod-links.ps1's -Rungs does:
    comma-separated <ladder>=<rungs> pairs. Asserted the same way.

.PARAMETER Heater
    Follow the heater's output box against the filling segment (#540). In each cell, from the
    first tick its output box gives under three quarters of what it held (tested as under 0.74), print every tick on
    which it holds anything, through the end of the first heater cycle in which the segment read
    full, within 0.005 units. Each row carries what the box held, what it gave, the segment's room and the reactor's
    box before the mod's step, so a rule for the delivery can be checked against it.

.PARAMETER KeepTemp
    Keep the save, the rig mods and the captured output.

.EXAMPLE
    pwsh -File scripts/probe-plasma-segment.ps1
    pwsh -File scripts/probe-plasma-segment.ps1 -Pipes 3,12 -Ticks 120000 -From 12000,96000
    pwsh -File scripts/probe-plasma-segment.ps1 -Pipes 3 -Plasma rf-d-t-plasma
    pwsh -File scripts/probe-plasma-segment.ps1 -Pipes 3,6 -Heater
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [ValidateRange(600, 2000000)] [int]   $Ticks = 100000,
    # Comma-separated strings, not [int[]]: pwsh -File hands "3,6" over as one string.
    [ValidatePattern('^\d+(,\d+)*$')] [string] $Pipes = '3,6',
    [ValidateSet('rf-d-d-plasma', 'rf-d-t-plasma', 'rf-d-he3-plasma', 'rf-he3-he3-plasma')]
    [string] $Plasma = 'rf-d-d-plasma',
    [ValidatePattern('^\d+(,\d+)*$')] [string] $From  = '12000,66000',
    [ValidateRange(1, 6000)]      [int]   $Span  = 360,
    [ValidateRange(1, 10000)]     [int]   $Every = 25,
    [ValidatePattern('^\d+,\d+$')] [string] $Dense,
    [ValidateRange(0.5, 1.0)]     [double] $FullAt = 0.999,
    # Case-sensitive: the names are Lua table keys.
    [ValidatePattern('^((confinement|heating|capture)_ladder=\d+)(,(confinement|heating|capture)_ladder=\d+)*$', Options = 'None')]
    [string] $Rungs,
    [switch] $Heater,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$rigName  = 'rf-segment-probe'
# No dependency on ours and a name that sorts ahead of it, so its on_tick runs before the mod's.
$preName  = 'a-rf-segment-pre'
$pipeCounts = @($Pipes -split ',' | ForEach-Object { [int] $_ })
$spans      = @($From -split ',' | ForEach-Object { [int] $_ })
if (@($pipeCounts | Sort-Object -Unique).Count -ne $pipeCounts.Count) { throw "-Pipes names a count twice: $Pipes" }
foreach ($count in $pipeCounts) {
    if ($count -lt 3 -or $count -gt 12) { throw "-Pipes $count is outside 3 to 12." }
}
foreach ($start in $spans) {
    if ($start -ge $Ticks) { throw "-From $start starts at or after -Ticks ($Ticks), so that span would print nothing." }
}
$denseFrom, $denseTo = if ($Dense) { $Dense -split ',' | ForEach-Object { [int] $_ } } else { 0, -1 }
if ($Dense -and $denseTo -lt $denseFrom) { throw "-Dense $Dense ends before it starts." }
$named = @($Rungs -split ',' | Where-Object { $_ } | ForEach-Object { ($_ -split '=')[0] })
if ($named.Count -ne @($named | Sort-Object -Unique).Count) { throw "-Rungs names a ladder twice: $Rungs" }
$rungsLua = if ($Rungs) { '{ ' + (($Rungs -split ',') -join ', ') + ' }' } else { 'nil' }

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-seg-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
$preDir = Join-Path $modDir $preName
New-Item -ItemType Directory -Path $rigDir, $preDir -Force | Out-Null

@{
    name = $rigName; version = '0.0.1'; title = 'Plasma segment probe'
    author = 'probe-plasma-segment.ps1'; factorio_version = '2.0'
    dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed', $preName)
} | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8
@{
    name = $preName; version = '0.0.1'; title = 'Plasma segment probe, the reading before the step'
    author = 'probe-plasma-segment.ps1'; factorio_version = '2.0'
    dependencies = @('base >= 2.0.77')
} | ConvertTo-Json | Set-Content -Path (Join-Path $preDir 'info.json') -Encoding utf8

Set-Content -Encoding utf8 -Path (Join-Path $preDir 'control.lua') -Value @'
-- Generated by probe-plasma-segment.ps1. Nothing here ships.
-- Reads each watched reactor's plasma box BEFORE realistic-fusion-refreshed steps it this tick.
remote.add_interface("rf-segment-pre", {
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
-- Generated by probe-plasma-segment.ps1. Reports; asserts nothing about the answer.

local PIPES = { __PIPES__ }
local FROM  = { __FROM__ }
local SPAN  = __SPAN__
local RUNGS = __RUNGS__
local HEATER = __HEATER__

local PLASMA = "__PLASMA__"
local ENERGY_FEED = "__ENERGYFEED__"
local PITCH = 100
-- control.lua's UPDATE_INTERVAL. Only the instrument's own check reads it: the box may differ
-- across the mod's handler on these ticks and on no others.
local STEP_TICKS = 6

local logic = require("__realistic-fusion-refreshed__/scripts/reactor-logic")

-- The reactor that burns PLASMA, and the spec its energy fluid is read off.
local ANEUTRONIC = { ["rf-d-he3-plasma"] = true, ["rf-he3-he3-plasma"] = true }
local REACTOR = ANEUTRONIC[PLASMA] and "rf-aneutronic-reactor" or "rf-reactor"
local ENERGY = (ANEUTRONIC[PLASMA] and logic.aneutronic_reactor or logic.reactor).energy_fluid

local function say(fmt, ...) log("SEGPROBE " .. string.format(fmt, ...)) end

__RIGBUILD__

__QUIETMAP__

local function amount_in(entity, index)
  local fluid = entity.fluidbox[index]
  return fluid and fluid.amount or 0
end

--- What the segment a cell's pipes are in holds, as the engine answers it through the first pipe.
local function in_segment(cell)
  local total = 0
  for _, amount in pairs(cell.pipes[1].fluidbox.get_fluid_segment_contents(1) or {}) do
    total = total + amount
  end
  return total
end

local function in_pipes(cell)
  local total = 0
  for _, pipe in ipairs(cell.pipes) do total = total + amount_in(pipe, 1) end
  return total
end

local function build(surface, force, ox, pipe_count)
  for _, dx in ipairs({ 9, -9 }) do
    rf_place_or_die(surface, { name = "substation", position = { ox + dx, 5 }, force = force },
      "a substation")
    local eei = rf_place_or_die(surface, { name = "electric-energy-interface",
      position = { ox + dx + (dx > 0 and 2.5 or -2.5), 5.5 }, force = force }, "a power source")
    eei.power_production = 8e6   -- J/tick, 480 MW a side against a reactor's 200 at most and a heater's 5
  end
  local reactor = rf_place_or_die(surface,
    { name = REACTOR, position = { ox + 0.5, 0.5 }, force = force, raise_built = true }, REACTOR)
  if rf_box_of(reactor, ENERGY) ~= 2 then error(REACTOR .. "'s boxes are not where they were") end

  -- The plasma run leaves the reactor's west connection, reactor end first, as the bench's does.
  -- Both reactors' west plasma connection is 7 tiles out, so the first pipe is 8.
  local west = { ox + 0.5 - 8, 0.5 }
  rf_pipe_run(surface, force, "rf-pipe", west, { -1, 0 }, pipe_count)
  local pipes = {}
  for i = 0, pipe_count - 1 do
    pipes[#pipes + 1] = surface.find_entity("rf-pipe", { west[1] - i, west[2] })
      or error(string.format("no rf-pipe at (%g, %g) on the plasma run", west[1] - i, west[2]))
  end
  local heater = rf_place_facing(surface, force, {
    name = "rf-heater", fluid = PLASMA,
    prepare = function(entity) entity.set_recipe(PLASMA) end,
    target = { west[1] - (pipe_count - 1), west[2] }, seed = { ox - 24.5, 20.5 },
  })
  local feed = prototypes.recipe[PLASMA].ingredients[1].name
  rf_unbound(surface, force, heater, rf_box_of(heater, feed),
    { name = feed, percentage = 1, mode = "at-least" })
  if not (heater.electric_network_id and reactor.electric_network_id) then
    error("a machine in the " .. pipe_count .. "-pipe cell is on no electric network")
  end

  -- Reactor energy leaves through the rigs' categorised feed, so nothing downstream throttles.
  local out = reactor.fluidbox.get_pipe_connections(2)[1]
  local drain = rf_place_or_die(surface,
    { name = ENERGY_FEED, position = out.target_position, force = force }, "the energy drain")
  drain.set_infinity_pipe_filter({ name = ENERGY, percentage = 0, mode = "at-most" })

  -- ONE SEGMENT, proven off the entities: every pipe and the reactor's box share one id.
  local id = reactor.fluidbox.get_fluid_segment_id(1)
  for i, pipe in ipairs(pipes) do
    if pipe.fluidbox.get_fluid_segment_id(1) ~= id then
      error(string.format("pipe %d of the %d-pipe cell is not in the reactor's segment", i, pipe_count))
    end
  end
  return { pipe_count = pipe_count, reactor = reactor, heater = heater, pipes = pipes,
    heater_box = rf_box_of(heater, PLASMA), segment_id = id }
end

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player

  -- Every recipe ships behind its technology, so the heater needs them researched; the ladders
  -- unlock nothing and are put back, then asserted rung by rung.
  force.research_all_technologies()
  rf_unresearch(force, logic, logic.reactor, RUNGS)
  rf_assert_research(function(ok, name, detail)
    if not ok then error(name .. " -- " .. detail) end
    say("research %s", name)
  end, force, logic, logic.reactor, RUNGS or false)

  local east = #PIPES * PITCH
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

  local cells, reactors = {}, {}
  for i, pipe_count in ipairs(PIPES) do
    cells[i] = build(surface, force, (i - 1) * PITCH, pipe_count)
    reactors[i] = cells[i].reactor
  end
  remote.call("rf-segment-pre", "watch", reactors)
  storage.cells = cells
  storage.per_craft = prototypes.recipe[PLASMA].products[1].amount
  say("built cells=%d quieted=%d per_craft=%g", #cells, storage.quieted, storage.per_craft)
  for _, cell in ipairs(cells) do
    say("cell pipes=%d capacity=%g box=%g heater_box=%g segment_id=%d", cell.pipe_count,
      cell.pipes[1].fluidbox.get_capacity(1), cell.reactor.fluidbox.get_capacity(1),
      cell.heater.fluidbox.get_capacity(cell.heater_box), cell.segment_id)
  end
end)

script.on_event(defines.events.on_tick, function()
  local tick = game.tick
  local pre = remote.call("rf-segment-pre", "read")
  if not pre then return end
  local spanned = false
  for _, from in ipairs(FROM) do
    if tick >= from and tick < from + SPAN then spanned = true end
  end

  for i, cell in ipairs(storage.cells) do
    if not (cell.reactor.valid and cell.heater.valid) then
      error("the " .. cell.pipe_count .. "-pipe cell lost a machine mid-run")
    end
    local plasma = cell.reactor.fluidbox[1]
    local box = plasma and plasma.amount or 0
    -- THE INSTRUMENT'S OWN CHECK: only the mod's step may come between the two readings.
    if tick % STEP_TICKS ~= 0 and pre[i] ~= box then
      error(string.format("tick %d: the box read %.9g before the mod and %.9g after it on a tick "
        .. "it does not step on, so the two readings do not bracket the step", tick, pre[i], box))
    end
    -- The burn on a cycle's last tick belongs to it, and the one on its first does not: the box
    -- reading a mark takes is already the one AFTER that tick's step.
    cell.burned = (cell.burned or 0) + (pre[i] - box)
    local crafts = cell.heater.products_finished
    local held, segment, pipes = amount_in(cell.heater, cell.heater_box), in_segment(cell), in_pipes(cell)

    if cell.mark and crafts > cell.mark.crafts then
      local m = cell.mark
      local piped = cell.pipes[1].fluidbox[1]
      say("cycle pipes=%d tick=%d ticks=%d fed=%.9g burned=%.9g dbox=%.9g dseg=%.9g dpipes=%.9g "
        .. "box=%.9g seg=%.9g temp=%.9g ptemp=%.9g", cell.pipe_count, tick, tick - m.tick,
        (crafts - m.crafts) * storage.per_craft - (held - m.held), cell.burned,
        box - m.box, segment - m.segment, pipes - m.pipes, box, segment,
        plasma and plasma.temperature or 0, piped and piped.temperature or 0)
      cell.mark = nil
    end
    if not cell.mark then
      cell.mark = { tick = tick, crafts = crafts, held = held, box = box, segment = segment, pipes = pipes }
      cell.burned = 0
    end

    -- THE HEATER'S OUTPUT BOX AGAINST THE SEGMENT (#540). `held` is after this tick's flow;
    -- what it had to give is last tick's plus any craft that landed since.
    if HEATER and cell.drip ~= "done" then
      local had = (cell.drip_held or 0) + (crafts - (cell.drip_crafts or crafts)) * storage.per_craft
      local gave = had - held
      -- `had > 0` keeps a box that held something on the probe's first tick, with nothing read
      -- before, from starting it.
      if not cell.drip and had > 0 and held > 0 and gave < 0.74 * had then cell.drip = "on" end
      if cell.drip == "on" then
        local capacity = cell.pipes[1].fluidbox.get_capacity(1)
        if cell.drip_full and crafts > cell.drip_crafts then
          cell.drip = "done"
        elseif had > 0 then
          local piped = cell.pipes[#cell.pipes].fluidbox[1]
          say("drip pipes=%d tick=%d had=%.9g gave=%.9g held=%.9g seg=%.9g cap=%g pre=%.9g ptemp=%.9g",
            cell.pipe_count, tick, had, gave, held, segment, capacity, pre[i],
            piped and piped.temperature or 0)
        end
        if segment >= capacity - 0.005 then cell.drip_full = true end
      end
      cell.drip_held, cell.drip_crafts = held, crafts
    end

    if spanned then
      local along = {}
      for p, pipe in ipairs(cell.pipes) do
        local fluid = pipe.fluidbox[1]
        along[p] = fluid and string.format("%.9g@%.6g", fluid.amount, fluid.temperature) or "0@-"
      end
      say("tick pipes=%d tick=%d pre=%.9g box=%.9g temp=%.6g along=%s seg=%.9g cap=%g heater_box=%.9g crafts=%d",
        cell.pipe_count, tick, pre[i], box, plasma and plasma.temperature or 0,
        table.concat(along, ","), segment, cell.pipes[1].fluidbox.get_capacity(1), held, crafts)
    end
  end
end)
'@

$inv = [cultureinfo]::InvariantCulture
$lua = $lua.
    Replace('__RIGBUILD__', (Get-RigBuildLua)).
    Replace('__QUIETMAP__', (Get-QuietMapLua)).
    Replace('__QUIETFN__', $script:QuietMapFunction).
    Replace('__PLASMA__', $Plasma).
    Replace('__PIPES__', ($pipeCounts -join ', ')).
    Replace('__FROM__', ($spans -join ', ')).
    Replace('__SPAN__', "$Span").
    Replace('__RUNGS__', $rungsLua).
    Replace('__HEATER__', $(if ($Heater) { 'true' } else { 'false' })).
    Replace('__ENERGYFEED__', (Write-EnergyFeed -RigDirectory $rigDir))
Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') -Value $lua

$invoke = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

function Read-Records {
    param([string[]] $Lines, [string] $Kind)
    foreach ($line in $Lines) {
        if ($line -notmatch "SEGPROBE $Kind ") { continue }
        $f = @{}
        foreach ($m in [regex]::Matches($line, '(\w+)=([^\s]+)')) { $f[$m.Groups[1].Value] = $m.Groups[2].Value }
        $f
    }
}
function Num { param($Value) [double]::Parse($Value, $inv) }

try {
    New-ModJunctions -ModDirectory $modDir -Links (Get-ModLinks -Root $repoRoot -Mods $ourMods)
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled @() -Mods ($ourMods + $rigName + $preName)

    $save = Join-Path $temp 'plasma-segment.zip'
    $createOut = Invoke-FactorioStep @invoke -Arguments @('--create', $save) -Tag 'create'
    $runOut = Invoke-FactorioStep @invoke -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', "$Ticks", '--benchmark-runs', '1', '--disable-audio')

    $created = @(Get-Content $createOut)
    $ran     = @(Get-Content $runOut)
    $version = 'unknown'
    $hit = $created | Select-String -Pattern 'Factorio (\d+\.\d+\.\d+) \(build (\d+)' | Select-Object -First 1
    if ($hit) { $version = "$($hit.Matches[0].Groups[1].Value) (build $($hit.Matches[0].Groups[2].Value))" }

    $cells = @(Read-Records $created 'cell')
    if ($cells.Count -ne $pipeCounts.Count) { throw "the rig built $($cells.Count) cell(s) of $($pipeCounts.Count)." }
    $cycles = @(Read-Records $ran 'cycle')
    $ticked = @(Read-Records $ran 'tick')
    $dripped = @(Read-Records $ran 'drip')
    if ($cycles.Count -eq 0) { throw 'the rig reported no heater cycle; the heater never crafted.' }
    # ONE CELL'S HEATER STANDING STILL BESIDE ANOTHER'S RUNNING (#536). The summary below indexes
    # each cell's last cycle, and on a cell with none that failed without saying which.
    $idle = @($pipeCounts | Where-Object { $n = "$_"; -not ($cycles | Where-Object { $_['pipes'] -eq $n }) })
    if ($idle.Count -gt 0) {
        throw "the $($idle -join '- and the ')-pipe cell recorded no heater cycle; its heater never crafted."
    }
    # The other half of the instrument's check. Had the first mod run AFTER ours, the two readings
    # would agree on every tick and every cycle would read a burn of zero.
    if (-not ($cycles | Where-Object { (Num $_['burned']) -gt 0 })) {
        throw 'no cycle read any burn: the reading before the step never differed from the one after, so the two mods are not in the order the probe needs.'
    }

    Write-Host ''
    Write-Host "Factorio $version -- $Ticks ticks, one heater per cell, $Plasma"
    $research = @($created | Select-String -Pattern 'SEGPROBE research ' | ForEach-Object { "$_" -replace '^.*SEGPROBE research ', '' })
    Write-Host ("research: {0} rung(s) asserted, {1}" -f $research.Count,
        $(if ($Rungs) { "-Rungs $Rungs, every other ladder OFF" } else { 'every ladder OFF' }))
    foreach ($r in $research) { Write-Host "  $r" }

    foreach ($cell in $cells) {
        $n = $cell['pipes']
        Write-Host ''
        Write-Host ("=== {0} pipes: the segment reports a capacity of {1}, the reactor's box {2}, the heater's output box {3}" -f
            $n, $cell['capacity'], $cell['box'], $cell['heater_box'])
        $mine = @($cycles | Where-Object { $_['pipes'] -eq $n })

        foreach ($start in $spans) {
            $rows = @($ticked | Where-Object { $_['pipes'] -eq $n -and [int]$_['tick'] -ge $start -and [int]$_['tick'] -lt $start + $Span })
            if ($rows.Count -eq 0) { continue }
            Write-Host ''
            Write-Host "  tick by tick from $start (box before the mod's step | after it, degC | each pipe units@degC, reactor end first | segment/capacity | heater box)"
            foreach ($r in $rows) {
                Write-Host ('  {0,8}  {1,11:F5} | {2,11:F5} {3:E4} | {4} | {5:F5}/{6} | {7:F4}' -f
                    [int]$r['tick'], (Num $r['pre']), (Num $r['box']), (Num $r['temp']),
                    ($r['along'] -replace ',', ' '), (Num $r['seg']), $r['cap'], (Num $r['heater_box']))
            }
            Write-Host ''
            Write-Host '  the heater cycles ending in that span, in plasma units'
            Write-Host ('  {0,8}{1,7}{2,10}{3,10}{4,10}{5,10}{6,10}{7,11}{8,13}{9,13}{10,11}' -f
                'ends', 'ticks', 'fed', 'burned', 'box', 'segment', 'pipes', 'box+seg',
                'two stores', 'one store', 'seg/1000')
            foreach ($c in ($mine | Where-Object { [int]$_['tick'] -ge $start -and [int]$_['tick'] -lt $start + $Span })) {
                $fed = Num $c['fed']; $burned = Num $c['burned']; $dbox = Num $c['dbox']; $dseg = Num $c['dseg']
                Write-Host ('  {0,8}{1,7}{2,10:F4}{3,10:F4}{4,10:F4}{5,10:F4}{6,10:F4}{7,11:F4}{8,13:F4}{9,13:F4}{10,11:F1}' -f
                    [int]$c['tick'], [int]$c['ticks'], $fed, $burned, $dbox, $dseg, (Num $c['dpipes']),
                    ($dbox + $dseg), ($fed - $burned - $dbox - $dseg), ($fed - $burned - $dseg),
                    $(if ((Num $c['box']) -gt 0) { 1000 * (Num $c['seg']) / (Num $c['box']) } else { 0 }))
            }
            Write-Host '  "two stores" is fed - burned - box - segment; "one store" is fed - burned - segment.'
        }

        $capacity = Num $cell['capacity']; $boxCap = Num $cell['box']
        $splitHead = '  {0,8}{1,11}{2,11}{3,11}{4,13}{5,13}{6,11}{7,11}' -f
            'tick', 'box', 'segment', 'seg/1000', 'box degC', 'pipes degC', 'box fill', 'seg fill'
        $splitRow = {
            param($c)
            $box = Num $c['box']; $seg = Num $c['seg']
            '  {0,8}{1,11:F2}{2,11:F2}{3,11:F1}{4,13:E4}{5,13:E4}{6,11:P2}{7,11:P2}' -f
                [int]$c['tick'], $box, $seg, $(if ($box -gt 0) { 1000 * $seg / $box } else { 0 }),
                (Num $c['temp']), (Num $c['ptemp']), ($box / $boxCap), ($seg / $capacity)
        }
        Write-Host ''
        Write-Host "  the split through the fill, every $Every cycles: what the segment holds for every 1000 in the box"
        Write-Host $splitHead
        for ($i = $Every - 1; $i -lt $mine.Count; $i += $Every) { Write-Host (& $splitRow $mine[$i]) }
        if ($Dense) {
            Write-Host ''
            Write-Host "  every cycle ending from tick $denseFrom to tick $denseTo"
            Write-Host $splitHead
            foreach ($c in ($mine | Where-Object { [int]$_['tick'] -ge $denseFrom -and [int]$_['tick'] -le $denseTo })) {
                Write-Host (& $splitRow $c)
            }
        }
        # WHERE THE SPLIT STEPS (#531), on a fill that burns little: the cycle the box grew most
        # in. Reported, not judged; a cell that burns most of its feed names the first cycle to
        # put plasma in the box.
        $step = 0
        for ($i = 1; $i -lt $mine.Count; $i++) { if ((Num $mine[$i]['dbox']) -gt (Num $mine[$step]['dbox'])) { $step = $i } }
        if ($step -gt 0) {
            $a = $mine[$step - 1]; $b = $mine[$step]
            Write-Host ("  the box grew most, by {0:F4}, in the cycle ending on tick {1}: box {2:F4} to {3:F4}, segment {4:F4} to {5:F4}" -f
                (Num $b['dbox']), [int]$b['tick'], (Num $a['box']), (Num $b['box']), (Num $a['seg']), (Num $b['seg']))
        }
        if ($Heater) {
            $drips = @($dripped | Where-Object { $_['pipes'] -eq $n })
            Write-Host ''
            if ($drips.Count -eq 0) {
                Write-Host '  the heater''s output box never gave under three quarters of what it held in this run'
            } else {
                Write-Host ("  the heater's output box, every tick it held anything, from tick {0} (it first gave under three quarters there) to tick {1}" -f
                    $drips[0]['tick'], $drips[-1]['tick'])
                Write-Host ('  {0,8}{1,11}{2,11}{3,9}{4,11}{5,13}{6,11}{7,13}{8,13}' -f
                    'tick', 'had', 'gave', 'share', 'held', 'segment', 'room', 'box before', 'heater pipe C')
                foreach ($d in $drips) {
                    $had = Num $d['had']; $gave = Num $d['gave']
                    Write-Host ('  {0,8}{1,11:F5}{2,11:F5}{3,9:F4}{4,11:F5}{5,13:F5}{6,11:F5}{7,13:F5}{8,13:E4}' -f
                        [int]$d['tick'], $had, $gave, $(if ($had -gt 0) { $gave / $had } else { 0 }), (Num $d['held']),
                        (Num $d['seg']), ((Num $d['cap']) - (Num $d['seg'])), (Num $d['pre']), (Num $d['ptemp']))
                }
                Write-Host '  "had" is what it held after the last tick plus any craft since; "gave" is what left it this tick.'
            }
        }
        $full = $mine | Where-Object { (Num $_['box']) -ge $FullAt * $boxCap } | Select-Object -First 1
        Write-Host $(if ($full) { "  the box first read {0:P1} of its capacity, {1:F2} units, at the cycle ending on tick {2}" -f $FullAt, (Num $full['box']), $full['tick'] }
                     else { "  the box never read {0:P1} of its capacity at a cycle's end in this run" -f $FullAt })
        $sum = @{ fed = 0.0; burned = 0.0 }
        foreach ($c in $mine) { $sum.fed += Num $c['fed']; $sum.burned += Num $c['burned'] }
        Write-Host ('  over all {0} cycles: fed {1:F2}, burned {2:F2}; the box ended at {3:F2} and the segment at {4:F2}' -f
            $mine.Count, $sum.fed, $sum.burned, (Num $mine[-1]['box']), (Num $mine[-1]['seg']))
    }

    Write-Host ''
    Write-Host 'OK - the probe ran and every row reported. The figures above are measurements, not a'
    Write-Host '     verdict. docs/research/exchanger-coverage.md is what they are read into.'
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'probe-plasma-segment' }
}

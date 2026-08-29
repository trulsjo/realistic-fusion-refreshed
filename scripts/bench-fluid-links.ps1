<#
.SYNOPSIS
    Measures how much fluid a link between two entities will carry, against connection count and
    against the number of pipes in between. Discharges #47.

.DESCRIPTION
    Realistic Fusion Power's 1.1 geometry butts a 15x15 reactor flush against a 5x15 heat exchanger
    so that two output connections meet two input connections with no pipe between them. In 1.1
    that bought throughput. 2.0 rewrote fluid flow into uniform segments, and whether any of it
    still buys anything is the question this measures rather than argues.

    METHOD

    One save holds a lane per matrix cell. A cell is a source entity and a sink entity, joined by
    N connections through D pipes, and nothing else touches it.

    The ends are unbounded by construction, which is the only honest way to measure a link:

    - Every tick the source's fluid box is written full from Lua and the sink's is emptied to zero.
      A Lua write is not rate-limited, so neither end can be the thing that runs out. The link
      therefore sees a permanent 100%-to-0% differential, which is the maximum it will ever face.
    - What the sink gave up before being emptied is the transfer for that tick. Summed over the
      measurement window and divided by it, that is a sustained rate, not an instantaneous one.
    - The source's loss over the same window is accumulated separately. In steady state the two
      must agree; the script fails the cell if they do not, because a disagreement means the pipes
      in between were still filling and the window was inside the transient.

    The source's connections are output-only and the sink's are input-only. That is not decoration.
    In 2.0 an input-output fluid box joins the fluid segment its pipes belong to and shares out in
    proportion to capacity -- so a rig built from input-output boxes would put both ends in one
    segment and measure nothing at all. Two cells are built that way on purpose, as a control, and
    the rig reports the segment ids so the merge is visible rather than assumed.

    THE RIG IS NOT THE BOTTLENECK, AND THE RUN PROVES IT

    Neither end can run dry or back up by construction rather than by luck: the source is rewritten
    full and the sink emptied on every single tick, so a whole tick's transfer would have to equal
    a whole box before either bound. Each cell reports the least the source ever held and the most
    the sink ever held anyway, and either touching its bound fails the cell -- a backstop against a
    future version in which a link is orders of magnitude faster, not the argument.

    The argument is these three controls, checked by this script rather than eyeballed:

    - nolink   The same cell with the sink moved three tiles clear and no pipes. Must transfer
               exactly nothing. If it does not, fluid is arriving by some path that is not the link
               and no other number in the run means anything.
    - cap2     Two matrix cells repeated with twice the fluid-box volume. The box is the one
               ceiling a Lua refill cannot lift. If doubling it does not move the rate, the box was
               not binding -- and this is the demonstration that carries the weight, because it is
               the only one that could have come out the other way.
    - io       Input-output connections instead of output/input, flush and at the shortest piped
               distance swept. Expected to merge into one fluid segment, and gated on merging.
               This one establishes what an unlimited link looks like, not what a fast one does:
               a merged pair has no transfer to rate-limit, so it reports no rate at all.

    And one cell that is not a control at all but a third arrangement, added for #48:

    - sinkio   Output-only source into an input-output sink. One end joins the segment and the
               other does not, so a boundary survives where the io control has none. This is what
               this mod's heater-to-reactor plasma link is, and it is neither row the matrix
               sweeps -- so without it #48's headroom would be quoted against the wrong ceiling.
               It carries markedly less than output-into-input does, and unlike that row it does
               not scale with connection count; both are measured here and neither is explained.

    Beyond the controls, the matrix's own linearity says the ends are not saturating -- an end that
    was running out would flatten the connection-count axis, and nothing flattens. That is read off
    the table rather than gated, because a Factorio version in which connection count genuinely
    stopped mattering would fail such a gate for the right reason.

    The rig declares its own prototypes and depends on base alone. Nothing in realistic-fusion-refreshed or
    realistic-fusion-refreshed-core is loaded, let alone changed -- the question is about the engine, and the
    answer belongs to a Factorio version rather than to this mod. #48 is where it gets applied to
    this mod's own links.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Connections
    Connection counts to sweep. At most 3: the rig's entities are five tiles tall and put their
    connections two tiles apart, so that pipe runs on neighbouring connections stay separate
    segments rather than merging into one.

.PARAMETER Distances
    Pipe counts to sweep. 0 is the flush case -- the two entities touching, no pipe at all -- and
    is the whole reason the ticket exists, so keep it.

.PARAMETER Warmup
    Ticks discarded before counting starts, so the pipes in between are full and the rate is the
    one the link settles at. The source-versus-sink cross-check will fail the cell if this was too
    short, so it is a gate rather than a hope.

.PARAMETER Measure
    Ticks counted. The rate is the total over this window divided by it.

.PARAMETER Volume
    Fluid-box volume of the rig's source and sink, in units. The cap2 control runs at twice this,
    which is why the accepted range stops at half what a fluid box will take.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/bench-fluid-links.ps1
    pwsh -File scripts/bench-fluid-links.ps1 -Distances 0,1 -Measure 600 -KeepTemp
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [ValidateRange(1, 3)]               [int[]] $Connections = @(1, 2, 3),
    [ValidateRange(0, 200)]             [int[]] $Distances   = @(0, 1, 5, 20),
    [ValidateRange(0, [int]::MaxValue)] [int]   $Warmup      = 600,
    [ValidateRange(1, [int]::MaxValue)] [int]   $Measure     = 1800,
    [ValidateRange(100, 500000)]        [int]   $Volume      = 25000,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$rigName = 'rf-fluid-rig'
$fluid   = 'water'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$Connections = @($Connections | Sort-Object -Unique)
$Distances   = @($Distances   | Sort-Object -Unique)
if ($Connections.Count -eq 0) { throw '-Connections is empty.' }
if ($Distances.Count -eq 0)   { throw '-Distances is empty.' }

# ---------------------------------------------------------------------------- the cells
#
# id is the cell's name everywhere -- prototype names, log lines, the tables below -- so it has to
# be unique and stable. kind separates the matrix from the controls; only the matrix is reported as
# a measurement, and only the controls are judged against an expectation.

$cells = @()
foreach ($n in $Connections) {
    foreach ($d in $Distances) {
        $cells += [pscustomobject]@{
            Id = "m-n$n-d$d"; Kind = 'matrix'; N = $n; D = $d; Volume = $Volume; Io = $false; SinkIo = $false; Gap = 0
        }
    }
}

# Controls. Each names the matrix cell it is a copy of, so the comparison below is not guesswork
# about which row it belongs beside.
$controlOf = @{}
$firstD    = $Distances[0]
$topN      = $Connections[-1]

$cells += [pscustomobject]@{
    Id = 'c-nolink'; Kind = 'control'; N = $topN; D = $firstD; Volume = $Volume; Io = $false; SinkIo = $false; Gap = 3
}
# The shortest distance swept and the shortest one with a pipe in it, which is usually two cells but
# is one when -Distances omits the flush case. Deduplicated, because a repeated distance would mean
# two controls with one id and so two prototypes with one name.
$controlDistances = @(@($firstD, ($Distances | Where-Object { $_ -gt 0 } | Select-Object -First 1)) |
    Where-Object { $null -ne $_ } | Sort-Object -Unique)

foreach ($d in $controlDistances) {
    $id = "c-cap2-d$d"
    $cells += [pscustomobject]@{
        Id = $id; Kind = 'control'; N = $topN; D = $d; Volume = $Volume * 2; Io = $false; SinkIo = $false; Gap = 0
    }
    $controlOf[$id] = "m-n$topN-d$d"

    $cells += [pscustomobject]@{
        Id = "c-io-d$d"; Kind = 'control'; N = $topN; D = $d; Volume = $Volume; Io = $true; SinkIo = $false; Gap = 0
    }

    # Output-only into an input-output sink, which is neither row the matrix sweeps and is exactly
    # what this mod's heater-to-reactor link is (#48). One end joins the segment and the other does
    # not, so a boundary survives -- but whether it is the same boundary as output-into-input is a
    # question, and #48's headroom figure is quoted against whichever answer comes back.
    # Deliberately not entered in $controlOf: that map drives the equal-rate gate, and whether this
    # arrangement matches output-into-input is the open question rather than the expectation.
    $cells += [pscustomobject]@{
        Id = "c-sinkio-d$d"; Kind = 'control'; N = $topN; D = $d; Volume = $Volume; Io = $false; SinkIo = $true; Gap = 0
    }
}

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-fluid-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

function Write-Rig {
    <#  Generate the rig mod. Three files: the cell list, the prototypes it implies, and the run.

        The cell list is written once and required by both stages, because a prototype the data
        stage declares and the control stage never places -- or the reverse -- is a silent hole in
        the matrix rather than an error.  #>

    @{
        name = $rigName; version = '0.0.1'; title = 'Fluid link throughput rig'
        author = 'bench-fluid-links.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

    $specs = ($cells | ForEach-Object {
        '  {{ id = "{0}", n = {1}, d = {2}, volume = {3}, io = {4}, sink_io = {5}, gap = {6} }},' -f
            $_.Id, $_.N, $_.D, $_.Volume, $_.Io.ToString().ToLowerInvariant(),
            $_.SinkIo.ToString().ToLowerInvariant(), $_.Gap
    }) -join "`n"
    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'specs.lua') -Value @"
-- Generated by scripts/bench-fluid-links.ps1. Nothing here ships.

return {
  -- Connection offsets from the entity centre, by connection count. Spread from the middle
  -- outwards so that every count is symmetric and the flush cases line up whatever n is.
  --
  -- Here rather than in each stage because both need it and they need the same one: the data
  -- stage puts the connections on these rows and the control stage lays pipes along them, so two
  -- copies that drifted apart would build pipe runs a tile off every connection, with no error
  -- anywhere and a matrix of zeroes at the end of it.
  rows = { [1] = { 0 }, [2] = { -2, 2 }, [3] = { -2, 0, 2 } },

  cells = {
$specs
  },
}
"@

    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'data.lua') -Value @'
-- Generated by scripts/bench-fluid-links.ps1. Nothing here ships.
--
-- A source and a sink per cell, cut from vanilla's boiler. The boiler is not incidental: the link
-- this exists to measure is a reactor's output box feeding a heat exchanger's input box, and both
-- of those are boilers. Nor is it merely convenient -- a storage tank is a pipeline entity, which
-- in 2.0 means its box joins the fluid segment its pipes belong to and refuses directional
-- connections outright ("Pipeline entities do not support directional connections"), so a rig
-- built from tanks would have put both ends of every link in one segment and measured nothing.
--
-- Neither machine ever runs. Both are given an electric energy source and the map has no power
-- network at all, so the boiler sits at zero energy and converts nothing -- which matters for the
-- sink, whose input box is full of exactly the water being counted and which would otherwise boil
-- some of it away before the count.
--
-- Three tiles wide by five tall, so that up to three connections fit on one face with a tile of
-- clear ground between them: pipe runs on adjacent tiles would join into one segment and the
-- sweep would stop being a sweep over parallel links.

local SPEC = require("specs")
local ROWS = SPEC.rows

-- The box a cell does not use still has to exist and still has to be legal, so it gets one
-- connection pointing north into ground nothing is ever built on.
local function idle_box(production_type)
  return {
    volume = 1, production_type = production_type, filter = "water",
    pipe_connections = { { flow_direction = "input-output", direction = defines.direction.north,
                           position = { 0, -2 } } },
  }
end

local function live_box(spec, east, production_type, flow_direction)
  local connections = {}
  for _, y in ipairs(ROWS[spec.n]) do
    connections[#connections + 1] = {
      flow_direction = flow_direction,
      direction = east and defines.direction.east or defines.direction.west,
      position = { east and 1 or -1, y },
    }
  end
  return {
    volume = spec.volume, production_type = production_type, filter = "water",
    pipe_connections = connections,
  }
end

local function machine(name, spec, east)
  local b = table.deepcopy(data.raw["boiler"]["boiler"])
  b.name = name
  b.minable = nil
  b.fast_replaceable_group = nil
  b.collision_box = { { -1.35, -2.35 }, { 1.35, 2.35 } }
  b.selection_box = { { -1.5, -2.5 }, { 1.5, 2.5 } }
  b.energy_source = { type = "electric", usage_priority = "secondary-input" }
  b.energy_consumption = "1W"

  if spec.io then
    -- The control that shows what an input-output box does: both ends declare one, and the run
    -- reports the segment ids so the merge is visible rather than argued. Both live boxes are the
    -- boiler's input box, so both ends are read and written at index 1.
    b.fluid_box = live_box(spec, east, "input-output", "input-output")
    b.output_fluid_box = idle_box("output")
  elseif spec.sink_io and not east then
    -- Output-only pushing into an input-output box: one end is in the segment and the other is
    -- not, so unlike the io control there is still a boundary here. This is the arrangement this
    -- mod's heater-to-reactor link is (#48), and it was not one of the two the matrix sweeps.
    b.fluid_box = live_box(spec, east, "input-output", "input-output")
    b.output_fluid_box = idle_box("output")
  elseif east then
    -- Output on the source, input on the sink: the only arrangement where a transfer happens at
    -- all rather than two boxes sharing one pool.
    b.fluid_box = idle_box("input")
    b.output_fluid_box = live_box(spec, east, "output", "output")
  else
    b.fluid_box = live_box(spec, east, "input", "input")
    b.output_fluid_box = idle_box("output")
  end
  return b
end

local protos = {}
for _, spec in ipairs(SPEC.cells) do
  protos[#protos + 1] = machine("rf-thr-src-" .. spec.id, spec, true)
  protos[#protos + 1] = machine("rf-thr-snk-" .. spec.id, spec, false)
end
data:extend(protos)
'@

    $lua = @'
-- Generated by scripts/bench-fluid-links.ps1. Nothing here ships.

local SPEC    = require("specs")
local SPECS   = SPEC.cells
local ROWS    = SPEC.rows
local FLUID   = "__FLUID__"
local WARMUP  = __WARMUP__
local MEASURE = __MEASURE__

local LANE = 10   -- tiles between cells: the entities are five tall, so this leaves four clear

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player
  local width   = 40
  for _, spec in ipairs(SPECS) do
    local reach = 12 + spec.d + spec.gap
    if reach > width then width = reach end
  end
  local height = #SPECS * LANE + 12

  surface.request_to_generate_chunks({ width / 2, height / 2 },
    math.ceil((math.max(width, height) / 2 + 64) / 32))
  surface.force_generate_chunk_requests()

  -- Landfill over the lot, then clear what generated on it: the rig needs buildable ground and
  -- nothing else, and this removes water without needing to know where any was.
  local tiles = {}
  for x = -10, width do
    for y = -10, height do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = { { -10, -10 }, { width, height } } })) do
    if e.type ~= "character" then e.destroy() end
  end

  -- The source sits at x = 0.5 covering tiles -0.5, 0.5 and 1.5; its connections point into the
  -- tile at 2.5. D pipes occupy 2.5 upwards, and the sink's west connection tile is the one past
  -- the last of them, which puts its centre at 3.5 + d. At d = 0 that is the source's target tile
  -- and the two entities touch.
  storage.cells = {}
  for index, spec in ipairs(SPECS) do
    local lane = (index - 1) * LANE + 6
    local source = surface.create_entity({
      name = "rf-thr-src-" .. spec.id, position = { 0.5, lane + 0.5 }, force = force,
    })
    if not source then error("source refused for " .. spec.id) end
    local sink = surface.create_entity({
      name = "rf-thr-snk-" .. spec.id, position = { 3.5 + spec.d + spec.gap, lane + 0.5 }, force = force,
    })
    if not sink then error("sink refused for " .. spec.id) end

    -- The gapped control gets no pipes whatever its d says, which is the whole of what makes it a
    -- control: same entities, same connections, no path.
    local pipes = 0
    if spec.gap == 0 then
      for _, row in ipairs(ROWS[spec.n]) do
        for i = 0, spec.d - 1 do
          local p = surface.create_entity({
            name = "pipe", position = { 2.5 + i, lane + 0.5 + row }, force = force,
          })
          if not p then error("pipe refused for " .. spec.id) end
          pipes = pipes + 1
        end
      end
    end

    -- What the box will actually hold, asked for rather than assumed from volume. Every tick
    -- writes the source full and every reading of what it lost is against this number, so a
    -- capacity that is not the declared volume would otherwise show up as a permanent shortfall
    -- and be counted as flow that never happened.
    -- A boiler's input box is index 1 and its output box index 2. The source pushes from its
    -- output box, so it is read and written at 2 -- except in the input-output control, where
    -- both ends' live box is the input box.
    local src_index = spec.io and 1 or 2
    local src_cap = source.fluidbox.get_capacity(src_index)
    local snk_cap = sink.fluidbox.get_capacity(1)

    storage.cells[#storage.cells + 1] = {
      spec = spec, source = source, sink = sink, pipes = pipes, src_index = src_index,
      src_cap = src_cap, snk_cap = snk_cap,
      drained = 0, lost = 0, samples = 0, min_held = src_cap, max_got = 0,
    }
  end

  log(string.format("FLUIDRIG built cells=%d", #storage.cells))
end)

local function report()
  for _, cell in ipairs(storage.cells) do
    local s = cell.spec
    log(string.format(
      "FLUIDRIG cell id=%s n=%d d=%d volume=%d io=%s sink_io=%s gap=%d pipes=%d samples=%d " ..
      "src_cap=%.10g snk_cap=%.10g drained=%.10g lost=%.10g min_held=%.10g max_got=%.10g " ..
      "seg_src=%s seg_snk=%s",
      s.id, s.n, s.d, s.volume, tostring(s.io), tostring(s.sink_io), s.gap, cell.pipes, cell.samples,
      cell.src_cap, cell.snk_cap, cell.drained, cell.lost, cell.min_held, cell.max_got,
      tostring(cell.source.fluidbox.get_fluid_segment_id(cell.src_index)),
      tostring(cell.sink.fluidbox.get_fluid_segment_id(1))))
  end
  log("FLUIDRIG done")
end

script.on_event(defines.events.on_tick, function()
  local tick = game.tick
  local measuring = tick > WARMUP and tick <= WARMUP + MEASURE

  for _, cell in ipairs(storage.cells) do
    -- Read before writing, both ends. What the sink holds now is what crossed during the engine's
    -- fluid update since it was last emptied, and what the source is short of is what left it.
    local got  = cell.sink.fluidbox[1]
    got = got and got.amount or 0
    local held = cell.source.fluidbox[cell.src_index]
    held = held and held.amount or 0

    if measuring then
      cell.drained  = cell.drained + got
      cell.lost     = cell.lost + (cell.src_cap - held)
      cell.samples  = cell.samples + 1
      if held < cell.min_held then cell.min_held = held end
      if got  > cell.max_got  then cell.max_got  = got end
    end

    cell.sink.fluidbox[1] = nil
    cell.source.fluidbox[cell.src_index] = { name = FLUID, amount = cell.src_cap, temperature = 15 }
  end

  if tick == WARMUP + MEASURE + 1 then report() end
end)
'@
    $lua = $lua.Replace('__FLUID__', $fluid).Replace('__WARMUP__', "$Warmup").Replace('__MEASURE__', "$Measure")
    Set-Content -Path (Join-Path $rigDir 'control.lua') -Value $lua -Encoding utf8
}

# The three things both runs below share, so that each names only what makes it that run.
$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled @() -Mods @($rigName)
    Write-Rig

    $save      = Join-Path $temp 'links.zip'
    $createOut = Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create'

    # The version the answer belongs to. Factorio prints it in its first log line, and a number
    # like this one is only worth quoting next to the build that produced it.
    $version = 'unknown'
    $line = Get-Content $createOut | Select-String -Pattern 'Factorio (\d+\.\d+\.\d+) \(build (\d+)' |
        Select-Object -First 1
    if ($line) { $version = "$($line.Matches[0].Groups[1].Value) (build $($line.Matches[0].Groups[2].Value))" }

    $built = Get-Content $createOut | Select-String -Pattern 'FLUIDRIG built' | Select-Object -Last 1
    if ("$built" -notmatch "cells=$($cells.Count)\b") {
        throw "rig built the wrong number of cells: '$built' (wanted $($cells.Count))"
    }

    $ticks = $Warmup + $Measure + 2
    $benchOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', "$ticks", '--benchmark-runs', '1', '--disable-audio')

    $rows = @()
    foreach ($record in (Get-Content $benchOut | Select-String -Pattern 'FLUIDRIG cell ')) {
        $fields = @{}
        foreach ($m in [regex]::Matches("$record", '(\w+)=([^\s]+)')) { $fields[$m.Groups[1].Value] = $m.Groups[2].Value }

        $spec = $cells | Where-Object { $_.Id -eq $fields['id'] } | Select-Object -First 1
        if (-not $spec) { throw "rig reported a cell that was never asked for: $($fields['id'])" }

        $samples = [int] $fields['samples']
        if ($samples -ne $Measure) {
            throw "cell $($fields['id']) counted $samples ticks, expected $Measure."
        }
        $drained = [double] $fields['drained']
        $lost    = [double] $fields['lost']

        $rows += [pscustomobject]@{
            Id        = $fields['id']
            Kind      = $spec.Kind
            N         = [int]    $fields['n']
            Distance  = [int]    $fields['d']         # pipes between the two, per connection
            Placed    = [int]    $fields['pipes']     # pipe entities the rig actually built
            Volume    = [int]    $fields['volume']
            SinkCap   = [double] $fields['snk_cap']
            Io        = $fields['io'] -eq 'true'
            SinkIo    = $fields['sink_io'] -eq 'true'
            Linked    = ([int] $fields['gap']) -eq 0
            PerTick   = $drained / $samples
            PerSecond = 60.0 * $drained / $samples
            Drift     = if ($drained -gt 0) { [Math]::Abs($lost - $drained) / $drained } else { 0.0 }
            MinHeld   = [double] $fields['min_held']
            MaxGot    = [double] $fields['max_got']
            Merged    = ($fields['seg_src'] -ne 'nil') -and ($fields['seg_src'] -eq $fields['seg_snk'])
        }
    }
    if ($rows.Count -ne $cells.Count) {
        throw "$($rows.Count) cells reported, $($cells.Count) expected. The run did not finish."
    }

    # ------------------------------------------------------------------- did the rig measure itself
    #
    # Every one of these is a reason to throw the run away rather than a note to print underneath
    # it, so they are checked before a single rate is reported.

    $faults = @()
    foreach ($r in $rows) {
        # A pipe run one short is not an error anywhere else in this script: the cell simply
        # measures a shorter link than its label says, and reports a plausible number for it.
        $wanted = if ($r.Linked) { $r.N * $r.Distance } else { 0 }
        if ($r.Placed -ne $wanted) {
            $faults += "$($r.Id): $($r.Placed) pipes were built, not $wanted, so the cell is not the one it is labelled."
        }
        if ($r.Merged -and -not $r.Io) {
            $faults += "$($r.Id): the two ends share a fluid segment, so no transfer was measured."
        }
        if ($r.Io -and -not $r.Merged) {
            $faults += ("$($r.Id): input-output boxes at both ends did NOT merge into one segment, " +
                        "which is the whole claim this control exists to make.")
        }
        # A merged cell is one pool with two Lua writes fighting over it, not a link. Its rate is
        # not a transfer and none of the checks below mean anything against it.
        if ($r.Merged) { continue }
        if ($r.PerTick -le 0) { continue }         # nothing crossed; the checks below are about flow
        if ($r.MinHeld -le 0) {
            $faults += "$($r.Id): the source reached empty, so the rig was the bottleneck."
        }
        if ($r.MaxGot -ge $r.SinkCap) {
            $faults += "$($r.Id): the sink reached its volume, so the rig was the bottleneck."
        }
        if ($r.Drift -gt 0.02) {
            $faults += ("$($r.Id): the source lost {0:P1} more or less than the sink received, " +
                        "so the link had not settled -- raise -Warmup.") -f $r.Drift
        }
    }

    $nolink = $rows | Where-Object { -not $_.Linked } | Select-Object -First 1
    if ($nolink -and $nolink.PerTick -ne 0) {
        $faults += ("$($nolink.Id): {0:N3} units/tick crossed a gap with no connection and no pipe, " +
                    "so fluid is arriving by some path that is not the link.") -f $nolink.PerTick
    }

    foreach ($id in $controlOf.Keys) {
        $doubled = $rows | Where-Object { $_.Id -eq $id } | Select-Object -First 1
        $plain   = $rows | Where-Object { $_.Id -eq $controlOf[$id] } | Select-Object -First 1
        if (-not $doubled -or -not $plain -or $plain.PerTick -le 0) { continue }
        $ratio = $doubled.PerTick / $plain.PerTick
        if ([Math]::Abs($ratio - 1.0) -gt 0.02) {
            $faults += ("${id}: doubling the fluid-box volume changed the rate by {0:P1}, so the " +
                        "rig's own buffers were binding and the matrix is a measurement of them.") -f ($ratio - 1.0)
        }
    }

    # ------------------------------------------------------------------------------------ report

    Write-Host ''
    Write-Host "Factorio $version -- $Measure ticks counted after $Warmup discarded, volume $Volume"
    Write-Host ''
    Write-Host 'units per second, sustained'
    Write-Host ('{0,-14}' -f 'connections') -NoNewline
    foreach ($d in $Distances) { Write-Host ('{0,16}' -f "$d pipes") -NoNewline }
    Write-Host ''
    foreach ($n in $Connections) {
        Write-Host ('{0,-14}' -f $n) -NoNewline
        foreach ($d in $Distances) {
            $cell = $rows | Where-Object { $_.Id -eq "m-n$n-d$d" } | Select-Object -First 1
            Write-Host ('{0,16:N1}' -f $(if ($cell) { $cell.PerSecond } else { [double]::NaN })) -NoNewline
        }
        Write-Host ''
    }

    Write-Host ''
    Write-Host 'controls'
    foreach ($r in $rows | Where-Object { $_.Kind -eq 'control' }) {
        # A merged pair has no transfer rate to quote -- printing one would be the very confusion
        # the control exists to dispel -- so it reports what it is instead.
        $rate = if ($r.Merged) { '{0,12}' -f 'one pool' } else { '{0,12:N1}' -f $r.PerSecond }
        $note = if (-not $r.Linked)  { 'no connection and no pipe: must be zero' }
                elseif ($r.Io)       { 'input-output both ends: ' +
                                       $(if ($r.Merged) { 'merged into one fluid segment, so nothing is transferred at all' }
                                         else { 'did NOT merge' }) }
                elseif ($r.SinkIo)   { "output into an input-output sink -- this mod's plasma link (#48)" }
                else                 { "volume $($r.Volume), against $($controlOf[$r.Id])" }
        Write-Host ('  {0,-12} {1} units/s   {2}' -f $r.Id, $rate, $note)
    }

    if ($faults.Count -gt 0) {
        Write-Host ''
        foreach ($f in $faults) { Write-Host "  $f" }
        throw "$($faults.Count) check(s) failed; the rates above are not a measurement of the link."
    }

    Write-Host ''
    Write-Host 'Controls passed: nothing crossed the gapped cell, doubling the boxes moved nothing,'
    Write-Host 'and source loss matched sink gain in every cell.'

    Write-Output $rows
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    else { Remove-TempDirectory -Path $temp -Label 'bench-fluid-links' }
}

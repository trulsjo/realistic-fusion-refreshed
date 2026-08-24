#Requires -Version 7
<#
.SYNOPSIS
    Measures what an electric buffer_capacity actually holds at runtime, against what the prototype
    declares. Reproduces the 10.67 MJ peak on a 10 MJ reactor buffer (#71).

.DESCRIPTION
    #37's trace of the reactor's power draw left one number nobody could explain: rf-reactor's
    electric buffer peaks at about 10.67 MJ against a declared buffer_capacity of "10MJ", 6.7% over.
    This repo has already been misled once by reading prototype data and never observing it
    (ADR 0011's mixing rule, corrected by #40), so the figure is measured here rather than reasoned
    about.

    WHAT IS ON THE MAP -- one reactor, eight clones of it, and four entities that are not ours

      driven        A real rf-reactor: plasma-fed, powered, and simulated by control.lua, which
                    spends confinement heating straight out of this buffer every sixth tick. This
                    is the entity #37 traced.
      same          A clone of the reactor prototype under a different name, so entity-management
                    never registers it and no Lua of ours ever writes its energy. Identical buffer
                    and flow limit. The difference between this and `driven` is exactly our writes.
      flow-6        10 MJ buffer, input_flow_limit dropped to 6MW.
      flow-600      10 MJ buffer, input_flow_limit raised to 600MW.
      no-limit      10 MJ buffer, no input_flow_limit at all, which means unlimited.
      buffer-1      1 MJ buffer at the shipped 60MW.
      buffer-7      7 MJ, so the ratio is read off a capacity that is not a round multiple.
      buffer-100    100 MJ buffer at the shipped 60MW.
      tertiary      10 MJ at 60MW, usage_priority "tertiary" instead of "secondary-input".
      accumulator   Vanilla's own, untouched: a different type, a different priority, and a
                    capacity Wube declared and the wiki quotes.
      accum-10      That accumulator with buffer_capacity forced to 10MJ, so the two controls
                    differ in their declared figure and nothing else.
      machine-10    Vanilla assembling-machine-2 with buffer_capacity forced to 10MJ. Idle, with no
                    recipe set.
      machine-2x    The same machine again at double the energy_usage, 300kW against 150kW, and
                    nothing else changed. It exists because one machine can only fit a formula to
                    one number.

    The variants exist to tell the candidate explanations apart rather than to pick between them.
    A ratio that is the same at 1, 7, 10 and 100 MJ is not a rounding; one that is the same at
    6 MW, 60 MW, 600 MW and unlimited is not the engine reserving a tick of inflow; one that shows
    on entities the mod never registers is not our own write; and one that a buffer nothing drains
    neither exceeds nor falls below once it has filled is not a transient read taken between two
    engine stages. The last of those is what `min` is for, and why it is only taken after the
    buffers have had time to fill -- a minimum that included the fill would be the starting zero.

    FOUR LINES PER CASE, AND THE TWO THAT MATTER ANSWER DIFFERENT QUESTIONS

    `proto` is what the runtime prototype says, so the declared figure sits beside the observed one.
    `tail` is the last forty per-tick samples, which is how the driven reactor's sawtooth is read
    rather than inferred -- it is evidence for a human, and nothing asserts against it.

    The two that are asserted against are `peak` and `clamp`. `peak` watches the buffer fill and
    reports the highest, lowest and last energy seen. `clamp` writes 1e15 J and reads back what
    stuck -- an over-large write is clamped rather than refused, so it asks the engine for its
    ceiling directly instead of inferring one from a fill. The clamp
    is taken last, after every other figure, so nothing above it is measured on a buffer it filled.
    Where a case charges, the two agree, and that agreement is most of why the figure can be
    trusted. Three cases do not charge on this rig -- both accumulators and the tertiary-priority
    probe, none of which the interface's surplus reaches -- so their `peak` rows are zeros, and a
    zero there is a fact about this rig's power rather than about those entities. Those three rest
    on the clamp alone, which is worth knowing when reading the `tertiary` row in particular: it is
    the only probe separating usage_priority from entity type.

    Each cell gets its own substation and interface, for the reason bench-reactors.ps1 gives: a
    substation reaches 18 tiles and a 15x15 reactor is wider than that, so one grid over all of them
    is not available at any spacing that fits. Islands also stop the 600MW probe from starving its
    neighbours.

    The prototype's parsed figures are reported beside the observed ones, because they are different
    questions: the first says what the engine made of "10MJ" at load, the second says what the
    entity holds while the game runs. They do not agree, and that is the finding -- written up in
    docs/research/reactor-runtime-cost.md.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/check-buffer.ps1
#>
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$rigName  = 'rf-buffer-rig'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-buf-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

function Write-Rig {
    @{
        name = $rigName; version = '0.0.1'; title = 'Reactor buffer capacity probe'
        author = 'check-buffer.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

    # Writes data.lua. The probe prototypes are appended to it below, so this call comes first.
    $feed = Write-PlasmaFeed -RigDirectory $rigDir

    Add-Content -Encoding utf8 -Path (Join-Path $rigDir 'data.lua') -Value @'

-- The probes: the shipped reactor under names entity-management does not know, so the simulation
-- never touches them. Nothing but the energy source differs between them and the shipped reactor:
-- the buffer, the inflow limit, and on one probe the usage priority.
local base = data.raw["boiler"]["rf-reactor"]
if not base then error("rf-reactor is missing; the rig cannot clone it") end

for _, probe in ipairs({
  { name = "rf-probe-same",       buffer = "10MJ",  flow = "60MW"  },
  { name = "rf-probe-flow-6",     buffer = "10MJ",  flow = "6MW"   },
  { name = "rf-probe-flow-600",   buffer = "10MJ",  flow = "600MW" },
  { name = "rf-probe-buffer-1",   buffer = "1MJ",   flow = "60MW"  },
  { name = "rf-probe-buffer-100", buffer = "100MJ", flow = "60MW"  },
  { name = "rf-probe-buffer-7",   buffer = "7MJ",   flow = "60MW"  },
  -- flow = nil is not a typo: an omitted input_flow_limit is unlimited, which is the one case a
  -- ratio-versus-reservation argument cannot be made about from the others.
  { name = "rf-probe-no-limit",   buffer = "10MJ"                  },
  -- Same boiler, a different usage_priority: the accumulator control differs from these probes in
  -- both its type and its priority, and one probe each separates the two.
  { name = "rf-probe-tertiary",   buffer = "10MJ",  flow = "60MW", priority = "tertiary" },
}) do
  local clone = table.deepcopy(base)
  clone.name = probe.name
  -- No item places or mines these; they are created by script and never picked up.
  clone.minable = nil
  clone.placeable_by = nil
  clone.energy_source.buffer_capacity = probe.buffer
  clone.energy_source.input_flow_limit = probe.flow
  if probe.priority then clone.energy_source.usage_priority = probe.priority end
  data:extend({ clone })
end

-- Three more entity types at the same declared capacity, so "which prototypes does this apply to"
-- is answered rather than assumed from one boiler. None is ours and none is a boiler.
--
-- The two machines differ only in energy_usage, and that pair is the point: one machine can only
-- ever fit a formula to a single number, and a second at twice the usage is what makes the reading
-- a measurement.
for _, other in ipairs({
  { source = data.raw["assembling-machine"]["assembling-machine-2"], name = "rf-probe-machine"     },
  { source = data.raw["assembling-machine"]["assembling-machine-2"], name = "rf-probe-machine-alt",
    usage = "300kW" },
  { source = data.raw["accumulator"]["accumulator"],                 name = "rf-probe-accum"       },
}) do
  if not other.source then error("missing vanilla prototype for " .. other.name) end
  local clone = table.deepcopy(other.source)
  clone.name = other.name
  clone.minable = nil
  clone.placeable_by = nil
  clone.next_upgrade = nil   -- an unminable entity may not name one
  clone.energy_source.buffer_capacity = "10MJ"
  if other.usage then clone.energy_usage = other.usage end
  data:extend({ clone })
end
'@

    $lua = @'
-- Generated by scripts/check-buffer.ps1. Nothing here ships.

-- driven is the shipped reactor, simulated. The rf-probe-* clones carry names the mod does not
-- register, so nothing of ours ever writes their energy; accumulator is vanilla's own, untouched.
-- What each one is for is in the script's .DESCRIPTION rather than repeated here.
local CASES = {
  { label = "driven",     name = "rf-reactor",          plasma = true },
  { label = "same",       name = "rf-probe-same",       plasma = true },
  { label = "flow-6",     name = "rf-probe-flow-6",     plasma = true },
  { label = "flow-600",   name = "rf-probe-flow-600",   plasma = true },
  { label = "buffer-1",   name = "rf-probe-buffer-1",   plasma = true },
  { label = "buffer-100", name = "rf-probe-buffer-100", plasma = true },
  { label = "buffer-7",   name = "rf-probe-buffer-7",   plasma = true },
  { label = "no-limit",   name = "rf-probe-no-limit",   plasma = true },
  { label = "tertiary",   name = "rf-probe-tertiary",   plasma = true },
  { label = "accumulator", name = "accumulator"                       },
  { label = "accum-10",   name = "rf-probe-accum"                     },
  { label = "machine-10", name = "rf-probe-machine"                   },
  { label = "machine-2x", name = "rf-probe-machine-alt"               },
}

-- Long enough for the slowest buffer here to fill several times over: flow-6 needs 100 ticks for
-- its 10 MJ and buffer-100 needs 100 for its 100 MJ, both from empty.
local REPORT_AT = 900
local SETTLED   = 300  -- after this the buffers are full, so a minimum means something
local SERIES    = 40   -- trailing per-tick samples, so a sawtooth can be read rather than inferred

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player

  surface.request_to_generate_chunks({ 150, 0 }, 14)
  surface.force_generate_chunk_requests()
  local tiles = {}
  for x = -25, 335 do
    for y = -20, 20 do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = { { -25, -20 }, { 335, 20 } } })) do
    if e.type ~= "character" then e.destroy() end
  end

  -- Twenty-five tiles between cells, written down rather than derived from the reactor's footprint
  -- the way bench-reactors.ps1 derives its pitch. That is safe here for a reason it was not there
  -- (#49): every way this rig can go wrong is loud. An entity that overlaps its neighbour, or a
  -- substation inside a reactor's collision box, makes create_entity return nil and the error below
  -- fires; a reactor outside its substation's reach fails the network check at the foot of the
  -- loop. There is no arrangement that quietly measures the wrong thing.
  storage.watch = {}
  for index, case in ipairs(CASES) do
    local ox = (index - 1) * 25
    local entity = surface.create_entity({
      name = case.name, position = { ox + 0.5, 0.5 }, force = force, raise_built = true,
    })
    if not entity then error(case.label .. ": " .. case.name .. " refused") end

    -- One island per cell. 2e7 J/tick is 1.2 GW, twice what the greediest probe here can pull.
    local sub = surface.create_entity({ name = "substation", position = { ox + 9, 5 }, force = force })
    if not sub then error(case.label .. ": substation refused") end
    local eei = surface.create_entity({
      name = "electric-energy-interface", position = { ox + 11.5, 5.5 }, force = force,
    })
    if not eei then error(case.label .. ": power source refused") end
    eei.power_production = 2e7

    -- Plasma, so every boiler here is a working one and none of them is idle for a reason the
    -- others are not. Placed where the entity says its connection points (#49).
    if case.plasma then
      local connections = entity.fluidbox.get_pipe_connections(1)
      if #connections == 0 then error(case.label .. ": no plasma connection") end
      local feed = surface.create_entity({
        name = "__PLASMAFEED__", position = connections[1].target_position, force = force,
      })
      if not feed then error(case.label .. ": infinity pipe refused") end
      feed.set_infinity_pipe_filter({
        name = "rf-d-d-plasma", percentage = 1, temperature = 6e8, mode = "at-least",
      })
      local joined = false
      for _, connection in pairs(entity.fluidbox.get_pipe_connections(1)) do
        if connection.target then joined = true end
      end
      if not joined then error(case.label .. ": the plasma feed reaches nothing") end
    end

    if not entity.is_connected_to_electric_network() then
      error(case.label .. ": the entity is on no electric network")
    end

    storage.watch[#storage.watch + 1] = {
      label = case.label, name = case.name, entity = entity,
      max = -1, min = math.huge, series = {},
    }
  end

  log("BUF-RIG built")
end)

script.on_event(defines.events.on_tick, function()
  if game.tick > REPORT_AT then return end
  for _, w in ipairs(storage.watch) do
    if not w.entity.valid then
      if not w.lost then
        w.lost = game.tick
        log(string.format("BUF-RIG lost  %-12s at tick %d", w.label, game.tick))
      end
    else
      local e = w.entity.energy
      w.samples = (w.samples or 0) + 1
      if e > w.max then w.max = e end
      -- The minimum is taken only once the buffers have filled, or every case reports the zero it
      -- started at and the figure says nothing.
      if game.tick > SETTLED and e < w.min then w.min = e end
      w.series[#w.series + 1] = e
      if #w.series > SERIES then table.remove(w.series, 1) end
    end
  end
end)

-- Tick 0 is a multiple of every interval, so this fires once during --create before anything has
-- happened -- and the `done` latch would then be saved into the map and skip the real report.
script.on_nth_tick(REPORT_AT, function()
  if game.tick == 0 or storage.done then return end
  storage.done = true

  for _, w in ipairs(storage.watch) do
    local source = prototypes.entity[w.name].electric_energy_source_prototype
    -- The flow limits are methods rather than attributes in 2.0 because quality scales them, and
    -- they are per tick, as the engine stores them; buffer_capacity is neither.
    -- usage is on the entity prototype rather than on its energy source, and it is what the two
    -- machines' ceilings turn out to be made of. Like the flow limits it is a method in 2.0,
    -- because quality scales it, and like them it is per tick.
    log(string.format("BUF-RIG proto %-12s declared=%.10g flow_per_tick=%.10g drain_per_tick=%.10g " ..
      "usage_per_tick=%.10g priority=%s",
      w.label, source.buffer_capacity, source.get_input_flow_limit(), source.drain,
      prototypes.entity[w.name].get_max_energy_usage(), source.usage_priority))
    log(string.format("BUF-RIG peak  %-12s max=%.10g min=%.10g final=%.10g over=%.6f%% samples=%d",
      w.label, w.max, w.min, w.entity.valid and w.entity.energy or -1,
      (w.max / source.buffer_capacity - 1) * 100, w.samples or 0))

    local parts = {}
    for _, sample in ipairs(w.series) do parts[#parts + 1] = string.format("%.10g", sample) end
    log(string.format("BUF-RIG tail  %-12s %s", w.label, table.concat(parts, " ")))

    -- The ceiling asked of the engine directly, and asked LAST so that nothing above it was
    -- measured on a buffer this had already filled. An over-large write is clamped rather than
    -- refused, so what comes back is the engine's own limit rather than anything inferred from
    -- watching a buffer fill -- which is the only way to get the figure out of an entity that
    -- never charged.
    w.entity.energy = 1e15
    -- Fourteen digits rather than ten, because the assertion on the far side of this line holds
    -- the ratio to 1e-9 and %.10g would leave it about that much rounding error to spend.
    log(string.format("BUF-RIG clamp %-12s wrote=1e15 held=%.10g ratio=%.14g",
      w.label, w.entity.energy, w.entity.energy / source.buffer_capacity))
  end
  log("BUF-RIG done")
end)
'@
    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') `
        -Value $lua.Replace('__PLASMAFEED__', $feed)
}

$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled @() -Mods ($ourMods + $rigName)
    Write-Rig

    $save = Join-Path $temp 'buffer.zip'
    Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create' | Out-Null
    $runOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', '1000', '--benchmark-runs', '1', '--disable-audio')

    $reported = @(Get-Content $runOut | Select-String -Pattern 'BUF-RIG ' |
        ForEach-Object { ($_ -split 'BUF-RIG ', 2)[1].TrimEnd() })
    if ($reported.Count -eq 0) { throw 'the rig reported nothing; it never reached its report tick.' }
    if ($reported -notcontains 'done') { throw 'the rig did not finish reporting.' }

    foreach ($line in $reported) { Write-Host "  $line" }

    # What the rig measured, turned back into numbers. The clamp line is the authority on the
    # ceiling -- see .DESCRIPTION -- so the assertions below are made against it rather than against
    # the highest figure a fill happened to reach.
    $held        = @{}
    $ratio       = @{}
    $peak        = @{}
    $consumption = @{}
    foreach ($line in $reported) {
        if ($line -match '^clamp\s+(?<label>\S+)\s+wrote=\S+\s+held=(?<held>\S+)\s+ratio=(?<ratio>\S+)$') {
            $held[$Matches.label]  = [double] $Matches.held
            $ratio[$Matches.label] = [double] $Matches.ratio
        }
        elseif ($line -match '^peak\s+(?<label>\S+)\s+max=(?<max>\S+)\s') {
            $peak[$Matches.label] = [double] $Matches.max
        }
        elseif ($line -match '^proto\s+(?<label>\S+)\s+.*\sdrain_per_tick=(?<drain>\S+)\s+usage_per_tick=(?<usage>\S+)\s') {
            $consumption[$Matches.label] = [double] $Matches.drain + [double] $Matches.usage
        }
    }

    # 16/15 to the ninth decimal, which is where the ratio was measured, rather than "about 6.7%".
    # A loose tolerance here would pass a Factorio version that had changed the rule to something
    # merely nearby, and noticing exactly that is what this script is for.
    $expected = 16 / 15
    $failures = @()
    foreach ($label in @('driven', 'same', 'flow-6', 'flow-600', 'no-limit',
                         'buffer-1', 'buffer-7', 'buffer-100', 'tertiary')) {
        if (-not $ratio.ContainsKey($label)) { $failures += "${label}: no clamp reading"; continue }
        if ([math]::Abs($ratio[$label] - $expected) -gt 1e-9) {
            $failures += ('{0}: holds {1} times its declared capacity, not 16/15' -f $label, $ratio[$label])
        }
    }
    foreach ($label in @('accumulator', 'accum-10')) {
        if (-not $ratio.ContainsKey($label)) { $failures += "${label}: no clamp reading"; continue }
        if ([math]::Abs($ratio[$label] - 1) -gt 1e-9) {
            $failures += ('{0}: holds {1} times its declared capacity, not exactly it' -f $label, $ratio[$label])
        }
    }
    # An assembling machine ignores the declared figure outright, which is a third behaviour again
    # and the reason this script claims no single rule for every electric energy source.
    foreach ($label in @('machine-10', 'machine-2x')) {
        if (-not $ratio.ContainsKey($label)) { $failures += "${label}: no clamp reading"; continue }
        if ($ratio[$label] -ge 1) {
            $failures += ('{0}: honoured its declared 10 MJ ({1} J); it did not before' -f $label, $held[$label])
        }
        # What it holds instead: its own energy usage plus its drain, per tick, times the same
        # 16/15. Asserted at both usages rather than fitted at one, which is the difference between
        # a formula that describes a number and one that predicts the next.
        $fromUsage = $consumption[$label] * $expected
        if ([math]::Abs($held[$label] - $fromUsage) -gt 1e-6 * $fromUsage) {
            $failures += ('{0}: holds {1} J, not the {2} J its usage plus drain would give' -f
                $label, $held[$label], $fromUsage)
        }
    }
    # The reactor the simulation drives and the clone it never touches reach the same ceiling. If
    # those two ever part company, the overshoot is ours after all.
    if ($peak.ContainsKey('driven') -and $peak.ContainsKey('same') -and $peak['driven'] -ne $peak['same']) {
        $failures += ('driven peaked at {0} J and the untouched clone at {1} J' -f $peak['driven'], $peak['same'])
    }

    Write-Host ''
    if ($failures) {
        foreach ($f in $failures) { Write-Host "  FAIL  $f" }
        throw ('buffer behaviour has moved since 2.0.77: {0} of the recorded facts no longer hold.' -f $failures.Count)
    }
    Write-Host ('OK - every non-accumulator buffer holds 16/15 of its declared capacity ' +
        '({0:N2} MJ against a declared 10 MJ), both accumulators hold exactly theirs, and an ' -f ($held['same'] / 1e6) +
        'assembling machine ignores the figure. See docs/research/reactor-runtime-cost.md.')
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'check-buffer' }
}

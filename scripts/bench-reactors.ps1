#Requires -Version 7
<#
.SYNOPSIS
    Measures what a simulated reactor costs per tick. Discharges the measurement half of #24.

.DESCRIPTION
    Builds a rig of N reactors in a headless save and benchmarks it, for several N, then reports
    the per-reactor cost as the slope. Written down as a script rather than as a procedure because
    ADR 0005's real obligation is the later measurement against the full reaction set (#34), and
    that one has to be the same measurement or the comparison means nothing.

    METHOD

    Three things make the number trustworthy, and all three are the reason this is not just
    "run --benchmark and look at avg":

    1. --benchmark-verbose reports per-tick timings by category, in nanoseconds. scriptUpdate is
       the control stage -- every mod's Lua, and nothing else. It isolates our cost from the
       engine's without needing a baseline at all. wholeUpdate is reported alongside it for
       context, and fluidFlowUpdate because the reactor is a boiler on a fluid segment, so some
       of what this mod costs is charged to the engine rather than to us.
    2. Every run builds the same map. The power, the flattened ground and the generated chunks are
       sized for the largest N and built identically at every N, including N = 0. Only the reactors
       differ, so a difference between runs is reactors.
    3. Mean and median are both reported, because they answer different questions and the mod
       does not update every tick. The mean is the cost -- averaged over thousands of ticks it is
       what UPS spends, and it is what the per-reactor figure is taken from. The median is what a
       tick feels like, and it is the more honest description of per-tick work: a run carries
       spikes an order of magnitude above the typical tick, and a mean over a thousand ticks is
       visibly moved by three of them. Under throttling the two separate by construction, which
       is why neither is dropped.

    The reactors are held full of plasma at a fusion temperature, because an empty reactor returns
    early from the simulation step and a rig that let its reactors run dry would measure the early
    return. They are also given real power through a real electric network -- not for that reason,
    since an unpowered reactor runs the whole step with its heating clamped to zero and costs the
    same, but because a reactor that cannot hold its temperature is not the thing worth measuring.
    The rig logs its own state during the run and the script refuses to report a number unless
    every reactor was present, hot and on an electric network when it did.

    The rig reads the reactor's footprint from its own prototype and derives every distance from
    it -- cell pitch, feed pipe, power. It used to hardcode them, which is issue #49: the numbers
    were right for the 3x2 reactor they were written against and silently wrong once the reactor
    became 15x15, and only the "every reactor hot" gate caught it. Nothing here is a remembered
    number.

    WHAT IT DOES NOT MEASURE

    Rig cost, chiefly the power, is present in every run including the baseline and so cancels out
    of the deltas -- but it does inflate wholeUpdate everywhere, and it is not small: a substation
    reaches 18 tiles and a cell is wider than that, so every cell needs its own substation and
    interface rather than sharing one grid. And a rig is not a factory: no belts, no trains, no
    biters, one surface. That is #34's job. This one exists to catch a disaster eleven tickets
    before #34 would.

    Nor does it resolve small differences. Four runs of the same binary on the same map gave a 42%
    spread (docs/research/reactor-runtime-cost.md); anything finer than a factor of about 1.5 needs
    interleaved repeats rather than one sweep.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Counts
    Reactor counts to measure, ascending. 0 is the baseline and should be kept.

.PARAMETER Ticks
    Ticks per benchmark run. 1000 is Factorio's default and gives ~1000 samples per run.

.PARAMETER Runs
    Benchmark runs per count; the map reloads between them, so this samples process-level
    variation rather than tick-level. Samples from every run are pooled.

.PARAMETER Pooled
    Connect each row of reactors with rf-pipe so they share one fluid segment, which is how they
    are meant to be built (ADR 0011) and the case where a superlinear engine cost would hide.
    Costs -Gap pipes per reactor, which are part of what gets measured.

.PARAMETER Gap
    Clear tiles between one reactor and the next, and so also the length of the pipe run -Pooled
    lays between them. The cell is the reactor's own footprint plus this, read from the prototype
    at run time -- see the rig for why nothing here is a remembered number. Five is the minimum
    that still fits a substation and an interface beside each reactor.

.PARAMETER ReportEvery
    How often the rig logs what the reactors are doing, and how often it therefore walks every
    reactor to gather that. That walk costs about as much per reactor as the simulation step does,
    it is charged to scriptUpdate, it scales with n, and the n = 0 baseline has no reactors to
    subtract it against -- so it inflates the per-reactor figure directly. At the default it runs
    on two or three ticks in a thousand, well under a percent of the throttled cost. Drop it to 1
    only when diagnosing the rig, and do not quote a cost figure from a run that did.

.PARAMETER KeepTemp
    Keep the saves, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/bench-reactors.ps1
    pwsh -File scripts/bench-reactors.ps1 -Pooled
    pwsh -File scripts/bench-reactors.ps1 -Counts 0,1,10 -Ticks 300 -Runs 1
#>
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [ValidateRange(0, 100000)]        [int[]] $Counts = @(0, 1, 10, 50, 200),
    [ValidateRange(1, [int]::MaxValue)] [int] $Ticks  = 1000,
    [ValidateRange(1, [int]::MaxValue)] [int] $Runs   = 3,
    [switch] $Pooled,
    [ValidateRange(5, 100)]             [int] $Gap = 5,
    [ValidateRange(1, [int]::MaxValue)] [int] $ReportEvery = 500,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = @('RealisticFusionCore', 'RealisticFusion')
$rigName  = 'rf-bench-rig'

# Columns worth printing. scriptUpdate is the answer; the rest are context, and are here because a
# cost pushed out of Lua and into the engine is still a cost this mod causes.
# luaGarbageIncremental is the one that would otherwise hide: the step allocates tables per reactor
# per tick, and collecting them is charged to its own stage rather than to the script.
$REPORT = @('wholeUpdate', 'scriptUpdate', 'luaGarbageIncremental', 'fluidFlowUpdate',
            'electricNetworkUpdate', 'entityUpdate')

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$Counts = @($Counts | Sort-Object -Unique)
# .Count, not -not: PowerShell unwraps a single-element array, so "-not @(0)" is true and a
# perfectly good "-Counts 0" would be rejected as empty.
if ($Counts.Count -eq 0) { throw '-Counts is empty.' }

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-bench-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

# A report interval at or past the run length leaves only the tick-0 report, which is taken before
# the rig has filled and would fail the "every reactor hot" gate on a perfectly good run. Halving
# the run length keeps two reports per run whatever -Ticks is, so the reporting overhead stays a
# fixed fraction rather than growing as runs get shorter.
if ($ReportEvery -ge $Ticks) { $ReportEvery = [Math]::Max(1, [int]($Ticks / 2)) }

# One grid geometry for every run, sized for the largest count, so the map is identical at every N.
$grid = [Math]::Max(1, [int][Math]::Ceiling([Math]::Sqrt(($Counts | Measure-Object -Maximum).Maximum)))

function Write-Rig {
    <#  Generate the rig mod for one reactor count. It is written fresh each time because the
        count is baked in: passing it another way would need a settings stage or a startup file,
        and neither is worth it for a throwaway.  #>
    param([int] $Count)

    @{
        name = $rigName; version = '0.0.1'; title = 'Reactor benchmark rig'
        author = 'bench-reactors.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'RealisticFusion')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

    $lua = @'
-- Generated by scripts/bench-reactors.ps1. Nothing here ships.

local COUNT  = __COUNT__
local GRID   = __GRID__      -- cells per side; the same at every count, so the map is too
local POOLED = __POOLED__
local GAP    = __GAP__       -- clear tiles between one reactor and the next

-- Every distance below is derived from the reactor's own prototype, and that is the whole reason
-- this section was rewritten: the rig used to hardcode a cell eight tiles wide with the feed pipe
-- two tiles left of centre, which was correct for the 3x2 reactor it was written against and
-- silently wrong the day the reactor became 15x15 (ADR 0013). Nothing errored. The cells simply
-- overlapped, the feed pipe sat six tiles clear of the connection it was meant to touch, and the
-- rig's own "every reactor hot" gate refused to report a number -- which is the gate working, but
-- it took issue #49 to notice why. Read the footprint, do not remember it.
local PROTO   = prototypes.entity["rf-reactor"]
local BOX     = PROTO.selection_box
local SIZE    = math.floor(BOX.right_bottom.x - BOX.left_top.x + 0.5)
local SPACING = SIZE + GAP
local SPAN    = GRID * SPACING
local EDGE    = SIZE + 8     -- landfill margin: a reactor's own width, plus room for the power

-- An odd-sized entity centres on a tile centre and an even-sized one on a tile boundary, so the
-- reactor's own parity decides where every position in this file starts from.
local ORIGIN = (SIZE % 2 == 1) and 0.5 or 0.0

-- Centre to the first tile *outside* the footprint: where a pipe has to sit to touch an edge
-- connection. entities.lua puts both plasma connections on the edge midline, so this is the only
-- offset the rig needs.
local REACH = (SIZE + 1) / 2

-- A 2x2 entity centres on a tile boundary and a 1x1 on a tile centre, whatever the reactor does.
local function even(v) return math.floor(v + 0.5) end
local function odd(v)  return math.floor(v) + 0.5 end

script.on_init(function()
  storage.reactors = {}

  local surface = game.surfaces[1]
  local force   = game.forces.player
  local area    = { { -EDGE, -EDGE }, { SPAN + EDGE, SPAN + EDGE } }

  surface.request_to_generate_chunks({ SPAN / 2, SPAN / 2 },
    math.ceil((SPAN / 2 + EDGE + 64) / 32))
  surface.force_generate_chunk_requests()

  -- Landfill over the lot: it removes the water without needing to know where any was, and it is
  -- buildable everywhere. Then clear what generated on top of it.
  local tiles = {}
  for x = -EDGE, SPAN + EDGE do
    for y = -EDGE, SPAN + EDGE do
      tiles[#tiles + 1] = { name = "landfill", position = { x, y } }
    end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = area })) do
    if e.type ~= "character" then e.destroy() end
  end

  -- Power, one island per cell rather than one grid over all of them. A substation reaches 18
  -- tiles and a cell is now wider than that, so a single connected network is no longer available
  -- at any spacing that fits the reactor; each cell instead gets a substation covering its
  -- reactor's centre and an interface inside that substation's own supply area.
  --
  -- Built for every cell of the grid at every count, including zero, so it is present in the
  -- baseline and cancels out of the deltas exactly as the shared grid used to.
  --
  -- Every placement is checked: a create_entity that quietly returns nil here leaves reactors
  -- unpowered, and an unpowered reactor still runs the whole step, so it would not show up as a
  -- cost anomaly -- only as a wrong claim about what was measured.
  for col = 0, GRID - 1 do
    for row = 0, GRID - 1 do
      local cx, cy = col * SPACING + ORIGIN, row * SPACING + ORIGIN
      -- In the gap east of the reactor, and pushed off the connection row so that -Pooled's pipe
      -- run has it to itself. Within nine tiles of the reactor's centre in both axes, which is
      -- what a substation's 18x18 supply area needs to cover it.
      local sub = surface.create_entity({
        name = "substation", position = { even(cx + REACH + 0.5), even(cy + 4.5) }, force = force,
      })
      if not sub then error(string.format("substation refused at cell %d,%d", col, row)) end

      local eei = surface.create_entity({
        name = "electric-energy-interface", position = { odd(cx + REACH + 3), odd(cy + 4.5) },
        force = force,
      })
      if not eei then error(string.format("power source refused at cell %d,%d", col, row)) end
      eei.power_production = 2e6   -- J/tick, ~120 MW against the 50 MW one reactor wants
    end
  end

  local placed = 0
  for i = 0, COUNT - 1 do
    local col, row = i % GRID, math.floor(i / GRID)
    local cx, cy = col * SPACING + ORIGIN, row * SPACING + ORIGIN
    local r = surface.create_entity({
      name     = "rf-reactor",
      position = { cx, cy },
      force    = force,
      -- Registers the reactor through the same event path a player builds it through, rather
      -- than through a rescan that only runs on init.
      raise_built = true,
    })
    if r then
      -- Loud here rather than subtle later. A reactor outside its substation's supply area still
      -- places, still fills, still runs its whole simulation step with the heating clamped to
      -- zero, and costs about what a powered one does -- so the benchmark would report a number
      -- and nothing would say it was taken on a rig that had quietly stopped being the rig
      -- described above. This is the check the old geometry did not have.
      if not r.electric_network_id then
        error(string.format("reactor at cell %d,%d is on no electric network: the substation " ..
          "at (%g, %g) does not reach it", col, row, even(cx + REACH + 0.5), even(cy + 4.5)))
      end
      -- Fed by an infinity pipe rather than seeded, and that is not laziness about the supply
      -- chain -- a seeded reactor does not stay full. An input-output box shares its contents
      -- with the fluid segment it belongs to in proportion to capacity, and a Lua write is
      -- clamped to the box, so writing the box's full 1000 leaves the box and the segment at
      -- 52.6% each within a second and the reactor simulates half the plasma it appears to hold.
      -- Overfilling does not help; the clamp happens first. Verified against a reactor no Lua
      -- ever touched, which splits identically -- this is the engine's model, not this mod's.
      --
      -- The pipe holds the segment at 100% at a fixed temperature, which is a reactor whose
      -- heater keeps up, and is the state worth measuring. It also pins the temperature rather
      -- than letting the simulation drive it: that is a deliberate trade, because a cost
      -- measurement wants the reactor held in one regime for the whole run, and the cost of a
      -- step does not depend on where in the table the lookup lands.
      if (not POOLED) or col == 0 then
        local feed = surface.create_entity({
          name = "__PLASMAFEED__", position = { cx - REACH, cy }, force = force,
        })
        if not feed then error(string.format("infinity-pipe refused at cell %d,%d", col, row)) end
        feed.set_infinity_pipe_filter({ name = "rf-d-d-plasma", percentage = 1, temperature = 6e8, mode = "at-least" })
      end
      storage.reactors[#storage.reactors + 1] = r
      placed = placed + 1

      if POOLED and col > 0 then
        -- GAP pipes bridge the gap between this reactor's west connection and its neighbour's
        -- east one, putting the whole row on one fluid segment. The count is the gap by
        -- construction: the run starts at the neighbour's first outside tile and ends at this
        -- reactor's, and SPACING is SIZE + GAP.
        for j = 1, GAP do
          local p = surface.create_entity({
            name = "rf-pipe", position = { cx - REACH - GAP + j, cy }, force = force,
          })
          if not p then error(string.format("rf-pipe refused at cell %d,%d segment %d", col, row, j)) end
        end
      end
    end
  end

  log(string.format("BENCH-RIG grid=%d size=%d spacing=%d requested=%d placed=%d pooled=%s",
    GRID, SIZE, SPACING, COUNT, placed, tostring(POOLED)))
end)

-- Proof that what was benchmarked was a running reactor and not a cold one. One tick in a hundred
-- carries a log write, and the median throws away far more of the distribution than that.
script.on_nth_tick(__REPORT__, function()
  local n, hot, powered, temp, plasma, output, energy = 0, 0, 0, 0, 0, 0, 0
  for _, r in pairs(storage.reactors) do
    if r.valid then
      n = n + 1
      energy = energy + r.energy
      if r.electric_network_id then powered = powered + 1 end
      local fb = r.fluidbox[1]
      if fb then
        plasma = plasma + fb.amount
        temp   = temp + fb.temperature
        if fb.temperature > 1e6 then hot = hot + 1 end
      end
      local out = r.fluidbox[2]
      if out then output = output + out.amount end
    end
  end
  local d = (n > 0) and n or 1
  log(string.format("BENCH-RIG tick=%d reactors=%d hot=%d powered=%d temp_c=%.4g plasma=%.4g output=%.4g buffer_j=%.4g",
    game.tick, n, hot, powered, temp / d, plasma / d, output / d, energy / d))
end)
'@
    # The shipped plasma set carries its own pipe connection category (#26), so a vanilla
    # infinity-pipe can no longer feed a reactor. The rig declares one that can.
    $lua = $lua.Replace('__COUNT__', "$Count").Replace('__GRID__', "$grid").
                Replace('__REPORT__', "$ReportEvery").Replace('__GAP__', "$Gap").
                Replace('__PLASMAFEED__', (Write-PlasmaFeed -RigDirectory $rigDir)).
                Replace('__POOLED__', $(if ($Pooled) { 'true' } else { 'false' }))
    Set-Content -Path (Join-Path $rigDir 'control.lua') -Value $lua -Encoding utf8
}

# The three things every run of this script shares, so that each call below names only what makes
# it that run. Running-or-throwing itself lives in factorio-lib.ps1.
$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

function Get-Timings {
    <#  Parse --benchmark-verbose output into per-category sample lists, in nanoseconds.

        The dump is a CSV header ("tick,timestamp,wholeUpdate,...") followed by one "t<n>,..." row
        per tick, repeated per run. Rows whose field count does not match the header are dropped
        rather than guessed at -- a truncated final row is the expected case if the process is
        killed, and a silently misaligned column would be worse than a missing sample.  #>
    param([string] $Path)

    $header = $null
    $cols   = [ordered]@{}
    foreach ($line in [IO.File]::ReadLines($Path)) {
        if ($line.StartsWith('tick,timestamp,')) {
            if (-not $header) {
                $header = $line.TrimEnd(',') -split ','
                foreach ($h in $header) { $cols[$h] = [System.Collections.Generic.List[double]]::new() }
            }
            continue
        }
        if ($line.Length -lt 2 -or $line[0] -ne 't' -or -not [char]::IsDigit($line[1])) { continue }
        if (-not $header) { continue }
        $f = $line.TrimEnd(',') -split ','
        if ($f.Count -ne $header.Count) { continue }
        for ($i = 2; $i -lt $header.Count; $i++) { $cols[$header[$i]].Add([double]$f[$i]) }
    }

    if (-not $header) { throw "no verbose benchmark output found in $Path (was --benchmark-verbose passed?)" }
    foreach ($c in $REPORT) {
        if (-not $cols.Contains($c)) { throw "benchmark output has no '$c' column; the timing names changed." }
    }
    if ($cols['scriptUpdate'].Count -eq 0) { throw "no tick rows parsed from $Path." }
    return $cols
}

function Get-Median {
    param([System.Collections.Generic.List[double]] $Values)
    if ($Values.Count -eq 0) { return [double]::NaN }
    $s = [double[]] $Values; [Array]::Sort($s)
    $n = $s.Count
    if ($n % 2) { return $s[($n - 1) / 2] }
    return ($s[$n / 2 - 1] + $s[$n / 2]) / 2
}

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled @() -Mods ($ourMods + $rigName)

    Write-Host "grid $grid x $grid cells, $Ticks ticks x $Runs run(s) per count, pooled: $([bool]$Pooled)"
    Write-Host ''

    $results = @()
    foreach ($count in $Counts) {
        Write-Rig -Count $count
        $save = Join-Path $temp "n$count.zip"

        $createOut = Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag "create-n$count"
        $rig = Get-Content $createOut | Select-String -Pattern 'BENCH-RIG' | Select-Object -Last 1
        if ($rig -notmatch "placed=$count\b") { throw "rig built the wrong number of reactors: $rig" }

        $benchOut = Invoke-FactorioStep @step -Tag "bench-n$count" -Arguments @(
            '--benchmark', $save, '--benchmark-ticks', "$Ticks", '--benchmark-runs', "$Runs",
            '--benchmark-verbose', 'all', '--disable-audio')

        # The rig's last word on what it was actually doing, and a hard gate rather than a note in
        # the output. Everything above this line would happily produce a confident per-reactor
        # figure from reactors that had run dry, never got power, or were never registered with
        # the mod at all -- none of which crashes anything. placed= only covers map creation, and
        # a benchmark loads the save rather than rebuilding it.
        $state = Get-Content $benchOut | Select-String -Pattern 'BENCH-RIG tick=' | Select-Object -Last 1
        if ("$state" -notmatch "reactors=$count\b" -or "$state" -notmatch "hot=$count\b") {
            throw "rig at n=$count was not $count hot reactors when it last reported: '$state'"
        }
        # Powered as well as present and hot. The rig errors at map creation if a reactor lands
        # outside its substation's reach, so this is the same fact checked on the far side of a
        # save-and-reload -- cheap, and the one property that would otherwise be taken on trust
        # for the whole benchmark.
        if ("$state" -notmatch "powered=$count\b") {
            throw "rig at n=$count had reactors on no electric network when it last reported: '$state'"
        }

        # And the only one of the three that proves the simulation ran. The two above cannot:
        # reactors= counts the rig's own table, which it fills itself whether or not
        # RealisticFusion ever registered the entity, and hot= reads a temperature the infinity
        # pipe pins at 6e8 regardless. So if registration silently stopped working -- an event
        # dropped from the list, a filter the game stops accepting -- every reactor would still be
        # present and hot, and this script would report a near-zero cost as a measurement instead
        # of as a bug. rf-reactor-energy exists only because control.lua's apply() put it there.
        if ($count -gt 0) {
            $produced = if ("$state" -match 'output=([0-9.eE+-]+)') { [double]$Matches[1] } else { 0 }
            if ($produced -le 0) {
                throw ("rig at n=$count produced no reactor energy, so the simulation did not run " +
                       "even though the reactors are present and hot: '$state'")
            }
        }

        $cols = Get-Timings -Path $benchOut
        $expected = $Ticks * $Runs
        if ($cols['scriptUpdate'].Count -ne $expected) {
            Write-Warning ("n={0}: {1} tick samples, expected {2}. The mean is over what was parsed." -f
                $count, $cols['scriptUpdate'].Count, $expected)
        }

        $row = [ordered]@{ Reactors = $count; Samples = $cols['scriptUpdate'].Count; State = "$state" }
        foreach ($c in $REPORT) {
            $row["$c.median"] = (Get-Median $cols[$c]) / 1000.0   # ns -> us
            $row["$c.mean"]   = (($cols[$c] | Measure-Object -Average).Average) / 1000.0
        }
        $results += [pscustomobject]$row

        Write-Host ("n={0,-5} scriptUpdate median {1,8:N2} us  mean {2,8:N2} us   whole median {3,8:N2} us   {4}" -f
            $count, $row['scriptUpdate.median'], $row['scriptUpdate.mean'], $row['wholeUpdate.median'],
            ("$state" -replace '^.*BENCH-RIG ', ''))
    }

    # ------------------------------------------------------------------ report
    #
    # Both statistics are printed and they answer different questions, which matters as soon as
    # the mod updates on anything but every tick. The mean is the cost: averaged over thousands of
    # ticks it is what UPS actually spends, and a throttled mod that does its work on one tick in
    # six costs exactly what it did before divided by six. The median is what a tick feels like,
    # and it is the honest one for per-tick work because a benchmark run carries spikes an order
    # of magnitude above the typical tick. Under throttling the median collapses towards the
    # baseline -- five ticks in six now do nothing -- so per-reactor cost is taken from the mean.

    $base = $results | Where-Object { $_.Reactors -eq 0 } | Select-Object -First 1

    foreach ($stat in @('median', 'mean')) {
        Write-Host ''
        Write-Host "$stat tick, microseconds"
        Write-Host ('{0,-9}' -f 'reactors') -NoNewline
        foreach ($c in $REPORT) { Write-Host ('{0,22}' -f $c) -NoNewline }
        Write-Host ''
        foreach ($r in $results) {
            Write-Host ('{0,-9}' -f $r.Reactors) -NoNewline
            foreach ($c in $REPORT) { Write-Host ('{0,22:N2}' -f $r."$c.$stat") -NoNewline }
            Write-Host ''
        }
    }

    if ($base) {
        # Both statistics again, so a per-reactor figure quoted anywhere can say which it came
        # from. The mean is the cost; the median is the only usable one where the signal is a
        # fraction of a microsecond and the mean is all spike.
        foreach ($stat in @('median', 'mean')) {
            Write-Host ''
            Write-Host "cost per reactor, microseconds -- ($stat at n minus $stat at 0) / n"
            Write-Host ('{0,-9}' -f 'reactors') -NoNewline
            foreach ($c in $REPORT) { Write-Host ('{0,22}' -f $c) -NoNewline }
            Write-Host ''
            foreach ($r in $results | Where-Object { $_.Reactors -gt 0 }) {
                Write-Host ('{0,-9}' -f $r.Reactors) -NoNewline
                foreach ($c in $REPORT) {
                    Write-Host ('{0,22:N4}' -f (($r."$c.$stat" - $base."$c.$stat") / $r.Reactors)) -NoNewline
                }
                Write-Host ''
            }
        }

        # The headline. A tick is 16.67 ms, so this is the share of one tick's budget the
        # simulation spends at the largest count measured.
        $top = $results | Sort-Object Reactors | Select-Object -Last 1
        if ($top.Reactors -gt 0) {
            $cost = $top.'scriptUpdate.mean' - $base.'scriptUpdate.mean'
            Write-Host ''
            Write-Host ("{0} reactors: {1:N2} us of Lua per tick on average, {2:N4} us per reactor, {3:N2}% of a 16.67 ms tick." -f
                $top.Reactors, $cost, ($cost / $top.Reactors), (100.0 * $cost / 16670.0))
        }
    }

    # The tables above are Write-Host, which "> file" does not capture. The rows go to the
    # pipeline as well so a caller can sort, export or diff them; writing a CSV into $temp would
    # have been worse than useless, since the finally block deletes it.
    Write-Output $results
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }

    # Junctions always go, even with -KeepTemp: leaving links to the repo in %TEMP% hands a
    # delete-through-the-link hazard to whatever cleans it up later.
    Remove-ModJunctions -ModDirectory $modDir

    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'bench-reactors' }
}

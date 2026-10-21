<#
.SYNOPSIS
    Checks that reactors on one run of rf-pipe share its feed and not its heat, as ADR 0040 says an
    "input" plasma box does, on a line that is filling and on one that is full. Discharges #40, and
    since #741 #574.

.DESCRIPTION
    ADR 0011 rests on the engine's fluid system coupling reactors on one run, so that no Lua in this
    mod tracks connectivity. ADR 0040 says what that coupling is since both reactors' plasma box
    became "input" (#740): the run carries plasma to every reactor on it, each box takes plasma and
    gives none back, and so heat does not travel. A reactor nothing heats sits at the plasma's 15 C
    floor beside a hot one, on any line, full or not. This rig asserts that, and asserts it in
    shapes the old input-output box fails, so a box that started sharing heat again would be caught.

    Nothing here uses an infinity pipe on the plasma. Every cell but two is seeded and then left
    alone; `feed` and `full` are fed by an rf-heater.

    UNTIL #741 THIS CHECK CHARACTERISED THE input-output BOX, which traded plasma with its run every
    tick: one pool at one mixed temperature, the engine's mixing destroying a fifth of a temperature
    difference, the run keeping 58% to 95% of what its reactors spent, and the write-shape, writer
    count and positional-ramp rows of #73 and #271 that ruled two of this mod's mechanisms out.
    Those findings are records, in the pooling section of docs/research/reactor-runtime-cost.md and
    in docs/research/plasma-input-box.md, and the rows that made them went with the box. Under
    "input" a reactor's write never leaves its box, so every one of them read 100% arrived and could
    no longer tell anything apart.

    WHAT IS BUILT

      pair      Two reactors bridged by rf-pipe, and ONLY THE WESTMOST IS ON AN ELECTRIC NETWORK.
      trio      Three, the same way.
      five      Five, the same way.

                One powered reactor per row is what makes these discriminating: an unpowered reactor
                runs its whole simulation step with heating clamped to zero, so any heat it holds
                arrived along the pipe. Seeded at 1e6 C and read at the floor.

      mix       Three reactors on one run, NOTHING POWERED and unregistered, seeded alike and then
                one end raised fifty times. The engine on its own, with no simulation driving it.
                Under input-output it flattened to a tenth of a percent inside two seconds; under
                "input" the ends stay apart.

      solo      ONE reactor and no pipe.
      solopipe  The same one reactor with a tail of rf-pipe.
      bare      Three reactors, all powered, bridged and nothing else.
      piped     The same three, plus a tail of rf-pipe.

                The four the bookkeeping is measured on: across ONE simulation step, the sum of
                amount x absolute temperature over every box on the run against what the shipped
                physics says the reactors spent. Under "input" each reactor keeps all of it, with a
                run beside it or not; the input-output box kept 95%, 75%, 58% and 67%.

      feed      One rf-heater, three rf-pipe into a powered reactor, and the bridge into an
                unpowered one. NOTHING SEEDED: every unit either box holds is one the heater made,
                so plasma in the far box crossed the run past the near reactor. That is the shared
                feed. The far reactor is read against the near one for the unshared heat.

      full      The same layout BUILT 2H1, the order #583 found the input-output box holding an
                unpowered reactor at 10^3 to 10^4 C on a full line where 1H2 let it fall to the
                floor. Seeded full like the rows above, and kept full by the heater. THIS IS THE
                CELL THAT REACHES A FULL LINE inside the run (#574): the line is not filled from
                empty, which takes 30 975 ticks on one heater, but seeded at 1e6 C like the rows
                above, its segment then topped up to its capacity with insert_fluid at tick 61,
                and asserted full when the check is read: the segment at 99.9% of what
                get_capacity reports for it, and both boxes at 99.9% of theirs.

      outlets   An rf-isotope-collector with its TRITIUM output box piped into a run of vanilla
                pipe and a tank, and -- since #86 -- an rf-reactor with an rf-heat-exchanger BOLTED
                to its energy face. Nothing is simulated here and nothing burns down: the row exists
                to ask get_capacity a question about an output box that has a neighbour.

                THE REACTOR HALF WAS A PIPE RUN AND IS A BOLT, because the arrangement it measured
                stopped existing. Reactor energy carried on vanilla pipe only while ADR 0018's
                containment had not shipped; #86 shipped it, and the run cannot be built at all now.
                The bolt is the shape that IS real, so the two "run bigger than the box" assertions
                go with the run and the get_capacity one stays.

    WHAT IS ASSERTED

      shared feed     `feed`: both reactors hold plasma the heater made. `full`: the line is full.
      unshared heat   `mix`'s ends stay apart. Every unpowered reactor on `pair`, `trio`, `five`
                      and `full` reads the plasma's floor (default_temperature, read off the
                      prototype) beside a powered one far above the seed. `feed`'s unpowered
                      reactor reads under a tenth of the powered one's temperature. And `solo`,
                      `solopipe`, `bare` and `piped` each keep at least 98% of what their reactors
                      spent across one step.
      get_capacity    A pipe reports its whole run; a reactor and a connected output box report
                      their own box. The 2.0 API documents neither, and this repo once wrote down
                      the opposite.

    A REACTOR'S get_capacity REPORTS ITS OWN BOX, NOT THE RUN. A pipe's reports the run. And that
    holds for an output box with a neighbour (#68), which is the shape all THREE call sites in
    control.lua that clamp against get_capacity actually have -- deposit() into a collector box,
    apply() into the reactor's energy box, and apply()'s blanket headroom off the collector again.
    The `outlets` row pipes an rf-isotope-collector's tritium box into twenty pipes and a tank, a
    27000-unit run against a 500-unit box, and the box still answers its own volume. Since #86 the
    reactor's energy box is asked the same question with an rf-heat-exchanger bolted to it: its
    1000-unit box must still report 1000 with a 200-unit exchanger box joined to it.

    WHAT IT DOES NOT COVER

    One surface, one plasma (D-D), one reactor (rf-reactor; rf-aneutronic-reactor's box is the same
    production type and was read by probe-plasma-input-box.ps1, not here), no pumps and no
    pipe-to-ground on the run. The full line is seeded full rather than filled from empty, and is
    built in one order. Nothing here says anything about a segment being split or merged while
    running: ADR 0011 has no code for that because the engine owns it.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Ticks
    Ticks to run before the final check. Forced off the simulation's beat -- see the adjustment
    below. The floor is the default: every unpowered reactor seeded at 1e6 C read the floor at tick
    1801 (2026-10-21, Factorio 2.0.77, nothing researched), and a shorter run was not measured.

.PARAMETER Tail
    How many rf-pipe to hang off the end of the `piped` and `solopipe` rows, so the bookkeeping is
    asked of a reactor with a run beside it as well as without.

.PARAMETER With
    Bundled mods to enable, e.g. -With space-age. Off by default, so the rig keeps checking base 2.0
    unless asked otherwise (ADR 0003, ADR 0008).

.PARAMETER AlsoModDirectory
    A directory of mod directories or mod zips to load alongside this repo's, read the way
    load-check.ps1's parameter of the same name reads it. Off by default, and the shipped run never
    uses it. It exists so a canary can be run through this rig: #549 loaded the plasma input-box
    canary here, recorded in docs/research/plasma-input-box.md.

.PARAMETER SelfTest
    Prove the rig can fail. Two halves, each a run of this script: `repo-passes`, the floor, and
    `shared-heat-refused` (#741), which loads a canary putting rf-reactor's plasma box back to
    "input-output" -- the box that shared heat -- and requires the rows that say heat is not shared
    to FAIL by name: `mix`'s, the floor rows of `pair`, `trio`, `five` and `full`, `feed`'s, and the
    four bookkeeping rows. Until #741 the second half was `all-arrives-refused`, which loaded the
    "input" box as a canary against the input-output one; #740 shipped that box. Refused with
    -AlsoModDirectory and -With. Since #578 it also fails when a file under our mod directories
    changed during the run, by load-check.ps1's check, which now lives in factorio-lib.ps1 as
    Test-ModTreeUnchanged.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/check-pooling.ps1
    pwsh -File scripts/check-pooling.ps1 -Tail 40 -KeepTemp
    pwsh -File scripts/check-pooling.ps1 -SelfTest
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [ValidateRange(1800, 200000)] [int] $Ticks = 1800,
    [ValidateRange(1, 500)]      [int] $Tail  = 20,
    [string[]] $With = @(),
    [string]   $AlsoModDirectory,
    [switch] $SelfTest,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

if ($SelfTest) {
    if ($AlsoModDirectory -or $With.Count) { throw '-SelfTest loads its own canary on the base game; it takes neither -AlsoModDirectory nor -With.' }
    $pwsh    = (Get-Process -Id $PID).Path
    $scratch = Join-Path ([IO.Path]::GetTempPath()) ('rf-pool-st-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $canary  = Join-Path $scratch 'rf-pooling-shares-heat'
    New-Item -ItemType Directory -Path $canary -Force | Out-Null
    @{
        name = 'rf-pooling-shares-heat'; version = '0.0.1'; title = 'Pooling check canary'
        author = 'check-pooling.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $canary 'info.json') -Encoding utf8
    Set-Content -Encoding utf8 -Path (Join-Path $canary 'data-final-fixes.lua') -Value @'
-- Generated by check-pooling.ps1 -SelfTest. Nothing here ships.
local box = data.raw.boiler["rf-reactor"].fluid_box
if box.production_type ~= "input" then
  error("pooling canary: rf-reactor's plasma box is '" .. tostring(box.production_type)
    .. "', not input, so there is nothing for the canary to change")
end
box.production_type = "input-output"
'@
    $common = @('-NoProfile', '-File', $PSCommandPath, '-Ticks', "$Ticks", '-Tail', "$Tail")
    if ($FactorioExe) { $common += @('-FactorioExe', $FactorioExe) }
    # The canary mutates rf-reactor in memory; this says so rather than assuming it (#578).
    $treeBefore  = Get-ModTreeFingerprint -Mods (Get-RepoMods)
    $treeChecked = $false
    try {
        Invoke-SelfTestHalves -Halves @(
            @{ Name = 'repo-passes'; Body = {
                $out = & $pwsh @common 2>&1
                if ($LASTEXITCODE -ne 0) { throw "the repository as it stands fails the pooling check:`n$($out | Select-Object -Last 8 | Out-String)" }
                'the repository as it stands passes.'
            } }
            @{ Name = 'shared-heat-refused'; Body = {
                $out = & $pwsh @common -AlsoModDirectory $scratch 2>&1
                if ($LASTEXITCODE -eq 0) { throw 'a run on the input-output box, which shares heat, passed the pooling check.' }
                # Every row that says heat is not shared, by the name each prints.
                $rows = @(
                    'mix: and with nothing driving it, the ends stay apart'
                    'pair: every unpowered reactor is at the floor'
                    'trio: every unpowered reactor is at the floor'
                    'five: every unpowered reactor is at the floor'
                    'feed: and the unpowered one holds none of the powered one''s heat'
                    'full: and the unpowered reactor on the full line is at the floor'
                )
                foreach ($cell in 'solo', 'solopipe', 'bare', 'piped') {
                    $rows += "${cell}: the reactors keep all of what they spent"
                }
                foreach ($row in $rows) {
                    if (-not ($out | Where-Object { "$_" -match "^\s*FAIL\s+$([regex]::Escape($row))" })) {
                        throw "under the input-output canary '$row' did not FAIL."
                    }
                }
                "a run on the box that shares heat is refused, by the $($rows.Count) rows that say heat is not shared."
            } }
        )
        $treeChecked = $true
        if (Test-ModTreeUnchanged -Before $treeBefore -Mods (Get-RepoMods)) { exit 1 }
    } finally {
        # After a half that threw, the tree still gets its answer; the exit code is already set.
        if (-not $treeChecked) { [void](Test-ModTreeUnchanged -Before $treeBefore -Mods (Get-RepoMods)) }
        if (-not $KeepTemp) { Remove-Item -Recurse -Force $scratch -ErrorAction SilentlyContinue }
    }
    Write-Host "-SelfTest: PASS, and $($treeBefore.Count) files under our mod directories untouched by the run." -ForegroundColor Green
    exit 0
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$rigName  = 'rf-pooling-rig'

# The shipped cadence, read rather than remembered. The bookkeeping window is one simulation step
# wide, and UPDATE_INTERVAL is a local in control.lua that nothing exports.
$controlLua = Join-Path $repoRoot 'realistic-fusion-refreshed/control.lua'
if ((Get-Content $controlLua -Raw) -match '(?m)^local UPDATE_INTERVAL = (\d+)') {
    $interval = [int]$Matches[1]
} else {
    throw "could not read UPDATE_INTERVAL from $controlLua; the one-step measurement needs it."
}

# Off the beat on purpose. A check landing on a simulation tick reads every driven box in the
# instant after it was written and before the engine has moved any fluid.
if ($Ticks % $interval -eq 0) { $Ticks++ }

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe
try {
    $enabledBundled = Resolve-BundledSelection -Requested $With -Bundled $bundled
}
catch { throw "-With $($_.Exception.Message)" }
$alsoMods = @()
if ($AlsoModDirectory) {
    try { $alsoMods = @(Get-HarnessMods -Path $AlsoModDirectory) }
    catch { throw "-AlsoModDirectory $($_.Exception.Message)" }
}

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-pool-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

function Write-Rig {
    @{
        name = $rigName; version = '0.0.1'; title = 'Fluid-segment sharing check'
        author = 'check-pooling.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed', 'realistic-fusion-refreshed-core')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

    $lua = @'
-- Generated by scripts/check-pooling.ps1. Nothing here ships.

local CHECK_AT = __TICKS__
local INTERVAL = __INTERVAL__   -- control.lua's UPDATE_INTERVAL, read out of the file
local TAIL     = __TAIL__

local PLASMA = "rf-d-d-plasma"

-- The shipped physics, required out of the mod rather than reimplemented, the same way the
-- ablation ladder in bench-reactors.ps1 does it. The bookkeeping check below asks this module what
-- a reactor's step should do and then asks the run whether it got it; a copy would only ever
-- confirm the copy.
local logic = require("__realistic-fusion-refreshed__/scripts/reactor-logic")
local SPEC  = logic.reactor

-- Seeded well below anything that fuses hard, so an unpowered reactor that ended up hot could only
-- have got there through the pipe, and well above the floor, so one that reads the floor cooled
-- there by its own step rather than starting there.
local SEED_C = 1e6

-- What `mix` raises one end to. Big enough that flattening would be unmistakable rather than a
-- rounding difference, and still well inside the plasma's declared range.
local HOT_C = SEED_C * 50

local GAP = 5      -- clear tiles between one reactor and the next, and so the bridge length

-- Every seeded cell is written for sixty ticks rather than once, which puts every row at the same
-- known fill before anything is read.
local SEED_UNTIL = 60

-- How long the runs are left before the bookkeeping step is measured, so the seeding has stopped
-- moving fluid.
local SETTLE_UNTIL = SEED_UNTIL + 240

-- The window the bookkeeping is measured across: one whole interval, opening ON a simulation tick.
--
-- THIS MOD'S HANDLERS RUN BEFORE realistic-fusion-refreshed'S, because the rig depends on it and so
-- loads after it. That was measured, not assumed: a window from tick 305 to 306, either side of a
-- step, once showed the run LOSING heat, which is what a window containing no step looks like. So a
-- reading taken on a step tick is the state that step is about to see, which is what the
-- prediction needs as its input, and a window of one whole interval from there holds one step.
local STEP_BEFORE = math.ceil(SETTLE_UNTIL / INTERVAL) * INTERVAL + INTERVAL
local STEP_AFTER  = STEP_BEFORE + INTERVAL

-- When `mix` is read: three seconds after it is left alone, against the two the input-output box
-- took to flatten it.
local MIX_AT = SEED_UNTIL + 180

-- What counts as full, the fraction probe-plasma-input-box.ps1's -FullAt defaults to.
local FULL_AT = 0.999

local function report_out()
  storage.report = storage.report or { lines = {}, failures = 0, checks = 0 }
  return storage.report
end

local function record(ok, name, detail)
  local r = report_out()
  r.checks = r.checks + 1
  if not ok then r.failures = r.failures + 1 end
  r.lines[#r.lines + 1] = string.format("%s  %s%s",
    ok and "ok  " or "FAIL", name, detail and ("  -- " .. detail) or "")
end

local function must(entity, what)
  if not entity then error(what .. " refused") end
  return entity
end

-- The shared rig helpers (#444): rf_assert_research and rf_unresearch, and rf_place_facing,
-- rf_box_of and rf_unbound for the heater (#741). Get-RigBuildLua in scripts/factorio-lib.ps1
-- defines them.
__RIGBUILD__

-- Relative difference, which is the shape every tolerance here is written in so none of them is an
-- absolute number that quietly stops meaning anything when a balance figure moves.
local function rel(a, b)
  local scale = math.max(math.abs(a), math.abs(b))
  if scale == 0 then return 0 end
  return math.abs(a - b) / scale
end

-- ---------------------------------------------------------------- reading a run

--- Sum of amount x absolute temperature over the run. Proportional to the 3NkT the simulation works
--- in, because every box holds the same fluid at the same particles-per-unit, so the constants
--- cancel out of every comparison made with it. Kelvin and not Celsius: a ratio of quantities
--- measured against an arbitrary zero is not a ratio of energies.
local function heat(cell)
  local total = 0
  for _, e in ipairs(cell.all) do
    local box = e.fluidbox[1]
    if box then total = total + box.amount * (box.temperature + 273.15) end
  end
  return total
end

local function box_volume(entity)
  return prototypes.entity[entity.name].fluidbox_prototypes[1].volume
end

--- What the run's capacity should be, from each entity's own declared volume. Read from the
--- prototypes rather than remembered, so a volume change moves the expectation with it.
local function declared_capacity(cell)
  local total = 0
  for _, e in ipairs(cell.all) do total = total + box_volume(e) end
  return total
end

local function temperature_of(entity)
  local box = entity.fluidbox[1]
  return box and box.temperature or nil
end

local function amount_of(entity)
  local box = entity.fluidbox[1]
  return box and box.amount or 0
end

--- What the segment a pipe is on holds. Under "input" the reactor boxes share the run's segment id
--- (#542) and get_capacity counts their volumes, but this does not count their contents; a full
--- line is this at get_capacity, as probe-plasma-input-box.ps1 reads one. One pipe's own fluidbox
--- reads a share and not the run.
local function segment_holds(pipe)
  local contents = pipe.fluidbox.get_fluid_segment_contents(1)
  return contents and contents[PLASMA] or 0
end

--- Hottest and coldest reactor over a range of the row, and the spread between them.
local function spread(reactors, from, to)
  local hot, cold
  for i = from or 1, to or #reactors do
    local t = temperature_of(reactors[i])
    if t then
      hot  = (hot  == nil or t > hot)  and t or hot
      cold = (cold == nil or t < cold) and t or cold
    end
  end
  if not hot then return nil end
  return hot, cold, rel(hot + 273.15, cold + 273.15)
end

-- ---------------------------------------------------------------- building
--
-- Nothing here computes where a pipe goes. Connection points are asked of the entity, which is #49:
-- the last rig that remembered a reactor's geometry went silently wrong the day the reactor changed
-- size, and only a gate that had nothing to do with geometry caught it.

local function reactor_footprint()
  local box  = prototypes.entity["rf-reactor"].selection_box
  local size = math.floor(box.right_bottom.x - box.left_top.x + 0.5)
  -- An odd-sized entity's centre sits on a tile centre and an even one's on a boundary. Getting it
  -- wrong places the reactor half a tile out and leaves every connection just clear of the pipe
  -- about to be laid at it -- without erroring.
  return size, (size % 2 == 1) and 0.5 or 0.0
end

--- The nearest centre a reactor's own parity allows, on either axis. bench-reactors.ps1 carries the
--- same function for the same reason: a y passed in already ending in .5 is right only while the
--- reactor is odd-sized.
local function centre(v, origin)
  if origin == 0.5 then return math.floor(v) + 0.5 else return math.floor(v + 0.5) end
end

--- The westmost or eastmost of an entity's plasma connections, in world coordinates.
local function edge_connection(entity, westward)
  local conns = entity.fluidbox.get_pipe_connections(1)
  if not conns or #conns == 0 then error(entity.name .. " has no plasma connections") end
  local best = conns[1].target_position
  for _, c in ipairs(conns) do
    if (westward and c.target_position.x < best.x) or (not westward and c.target_position.x > best.x) then
      best = c.target_position
    end
  end
  return best
end

--- A substation and a power source south of (x, y), asserted to be one network.
---
--- A 2x2 entity centres on a tile BOUNDARY and a 1x1 on a tile CENTRE, so the substation wants whole
--- numbers and the interface wants halves. Placing either off its own grid shifts it half a tile,
--- which moves an 18x18 supply area by half a tile -- and the failure is silent, because everything
--- still places. check-containment.ps1 carries the same note.
local function power(surface, force, x, y, down, label)
  local sx, sy = math.floor(x + 0.5), math.floor(y + 0.5) + down
  local sub = must(surface.create_entity({
    name = "substation", position = { sx, sy }, force = force,
  }), label .. ": substation")
  local eei = must(surface.create_entity({
    name = "electric-energy-interface", position = { sx + 2.5, sy + 0.5 }, force = force,
  }), label .. ": power source")
  eei.power_production = 8e6
  if not eei.electric_network_id or eei.electric_network_id ~= sub.electric_network_id then
    error(string.format("%s: the power source at (%g, %g) is not on the substation's network",
      label, sx + 2.5, sy + 0.5))
  end
end

--- One reactor at (cx, cy), and the bridge of rf-pipe west from it to `prev` when there is one.
local function place_reactor(surface, force, cell, cx, cy, bridge, unregistered)
  local reactor = must(surface.create_entity({
    -- Suppressing the build event is the only way one mod can keep another's per-tick handler
    -- off an entity: realistic-fusion-refreshed registers a reactor from that event and rescans
    -- only at on_init, which has already run. bench-reactors.ps1 -Ablate leans on the same seam.
    name = "rf-reactor", position = { cx, cy }, force = force, raise_built = not unregistered,
  }), cell.label .. ": rf-reactor")
  if bridge then
    local west = edge_connection(reactor, true)
    for j = 1, bridge do
      cell.all[#cell.all + 1] = must(surface.create_entity({
        name = "rf-pipe", position = { west.x - bridge + j, west.y }, force = force,
      }), cell.label .. ": bridge pipe")
    end
  end
  cell.all[#cell.all + 1] = reactor
  return reactor
end

--- One row of `count` reactors on a single run of rf-pipe, plus `tail` further pipes off the end.
---
--- `powered` is how many reactors get an electric network, counting from the west. A row that
--- passes fewer than all of them is one that can demonstrate sharing at all: an unpowered reactor
--- cannot heat its own plasma, so whatever heat it holds came along the pipe.
local function build_row(surface, force, oy, count, tail, powered, label, unregistered)
  local size, origin = reactor_footprint()
  local pitch  = size + GAP
  local cell = { label = label, reactors = {}, all = {}, powered = powered }
  local cy = centre(oy, origin)

  for i = 0, count - 1 do
    local cx = centre(origin + i * pitch, origin)
    cell.reactors[#cell.reactors + 1] =
      place_reactor(surface, force, cell, cx, cy, i > 0 and (pitch - size) or nil, unregistered)
    -- South of the row, so it neither collides with this reactor nor reaches the next: a
    -- substation covers eighteen tiles and the pitch is twenty, so the neighbour's near edge falls
    -- outside it. Asserted rather than trusted -- see the "on an electric network" checks.
    if i < powered then power(surface, force, cx, cy, 10, label) end
  end

  if tail > 0 then
    local east = edge_connection(cell.reactors[#cell.reactors], false)
    for j = 0, tail - 1 do
      cell.all[#cell.all + 1] = must(surface.create_entity({
        name = "rf-pipe", position = { east.x + j, east.y }, force = force,
      }), label .. ": tail pipe")
    end
  end

  return cell
end

-- How many rf-pipe run from the heater to the first reactor of `feed` and `full`, as
-- probe-plasma-input-box.ps1's -Pipes defaults to.
local HEATER_PIPES = 3

--- One rf-heater, HEATER_PIPES of rf-pipe into a powered reactor, and a bridge into an unpowered
--- one, placed in `order` (#583): 1 the first reactor, H the heater and its run, 2 the bridge and
--- the second reactor. The layout on the ground is the same in every order.
---
--- The first reactor's west connection is read off the second one, placed or probed, rather than
--- remembered: its offset from the reactor's centre is the same on both.
local function build_line(surface, force, oy, label, order)
  local size, origin = reactor_footprint()
  local pitch = size + GAP
  local cy = centre(oy, origin)
  local cx1, cx2 = centre(origin, origin), centre(origin + pitch, origin)
  local cell = { label = label, reactors = {}, all = {}, powered = 1, order = order }

  local probe = must(surface.create_entity({
    name = "rf-reactor", position = { cx1, cy + 40 }, force = force, raise_built = false,
  }), label .. ": probe reactor")
  local w = edge_connection(probe, true)
  local west = { x = cx1 + (w.x - probe.position.x), y = cy + (w.y - probe.position.y) }
  probe.destroy()

  local parts = {
    ["1"] = function()
      cell.reactors[1] = place_reactor(surface, force, cell, cx1, cy)
      power(surface, force, cx1, cy, 10, label)
    end,
    H = function()
      for j = 0, HEATER_PIPES - 1 do
        cell.all[#cell.all + 1] = must(surface.create_entity({
          name = "rf-pipe", position = { west.x - j, west.y }, force = force,
        }), label .. ": heater pipe")
        cell.pipe = cell.pipe or cell.all[#cell.all]
      end
      local feed = prototypes.recipe[PLASMA].ingredients[1].name
      local heater = rf_place_facing(surface, force, {
        name = "rf-heater", fluid = PLASMA,
        prepare = function(entity) entity.set_recipe(PLASMA) end,
        target = { west.x - (HEATER_PIPES - 1), west.y }, seed = { cx1 - 30, cy + 25 },
      })
      rf_unbound(surface, force, heater, rf_box_of(heater, feed),
        { name = feed, percentage = 1, mode = "at-least" })
      -- Its own island, west of the reactor's and short of the second reactor.
      power(surface, force, heater.position.x, heater.position.y, 6, label .. " heater")
      cell.heater = heater
    end,
    ["2"] = function()
      cell.reactors[2] = place_reactor(surface, force, cell, cx2, cy, pitch - size)
    end,
  }
  for who in order:gmatch(".") do parts[who]() end
  return cell
end

--- Fill every box on the run to its own volume.
local function top_up(cell, celsius)
  for _, e in ipairs(cell.all) do
    e.fluidbox[1] = { name = PLASMA, amount = box_volume(e), temperature = celsius }
  end
end

-- ---------------------------------------------------------------- output boxes that have a neighbour
--
-- WHY THIS EXISTS (#68). The capacity checks below used to ask their question of one shape only: a
-- reactor's plasma box on a run of rf-pipe, and an OUTPUT box that was plumbed into nothing. An
-- unconnected box reporting its own volume is not a measurement of the thing in doubt -- it is the
-- case where the box and the segment are the same object -- so the answer for a CONNECTED output
-- box was an extrapolation.
--
-- It matters because ALL THREE call sites in control.lua that clamp against get_capacity are output
-- boxes with a neighbour in ordinary play, and none of them is a reactor's plasma box: deposit()
-- writes into an rf-isotope-collector, apply() writes into the reactor's ENERGY box, and apply()
-- computes a lithium blanket's headroom off the collector again.
--
-- TWO SHAPES NOW, ONE PER FLUID, AND #86 IS WHY. The collector's tritium is ordinary by design
-- (#26) -- its by-products are cold gases, not plasma, and nothing plans to contain them -- so that
-- box goes on twenty vanilla pipes and a vanilla tank, and the run is what its capacity is compared
-- against. Reactor energy is CONTAINED since #86: ADR 0018 gives it a category of its own and ships
-- no pipe that carries it, so plumb() has nothing to lay for it and the run this row used to build
-- cannot exist. The reactor's energy box gets the neighbour a player can actually give it, an
-- rf-heat-exchanger bolted flat to its face, and build_energy_bolt() below is that row.
--
-- What the bolt cannot carry over is the pair of assertions about the run being materially larger
-- than the box: a bolt has no run. It keeps the one that decides whether apply()'s clamp is written
-- against the right number, which is the reason the row exists. #258 asks whether a contained energy
-- pipe should exist; while it does not, a bolt is the only neighbour that box can have.

-- 2000 units of pipe, so the run beats the collector's 500-unit box on pipe alone.
local RUN_PIPES = 20
local RUN_TANK  = "storage-tank"

--- The RUNTIME index of the box on `entity` filtered to `fluid`, or nil.
---
--- NOT box_index() BELOW, AND THE DIFFERENCE IS MEASURED. A boiler with a fluid ENERGY SOURCE does
--- not present its boxes in the same order twice: `prototypes.entity[...].fluidbox_prototypes` and
--- `entity.fluidbox` disagree for rf-heat-exchanger, so asking the prototype for the index of the
--- reactor-energy box and then handing that index to entity.fluidbox returns the WATER box's
--- connections. It cost this rig one run, failing with "rf-heat-exchanger has no north-facing energy
--- connection" on a machine that has one. box_index() is still right for rf-reactor and
--- rf-isotope-collector, which have no energy-source box and so cannot disagree with themselves.
local function box_of(entity, fluid)
  for index = 1, #entity.fluidbox do
    local filter = entity.fluidbox.get_filter(index)
    if filter and filter.name == fluid then return index end
  end
  return nil
end

--- The index of the box on `entity` that `pick` accepts, from the PROTOTYPE rather than remembered.
local function box_index(entity, pick)
  local boxes = prototypes.entity[entity.name].fluidbox_prototypes
  for i, box in ipairs(boxes) do
    if pick(box) then return i end
  end
  error(entity.name .. " has no box matching what was asked for")
end

local function indexed_volume(entity, index)
  return prototypes.entity[entity.name].fluidbox_prototypes[index].volume
end

--- Lay a run of vanilla pipe out of `entity`'s box `index`, and put a tank on the end of it.
---
--- The direction is read off the connection rather than written down, the same way check-blanket.ps1
--- does it, so a face moving does not silently leave the pipe one tile clear of the machine.
local function plumb(surface, force, entity, index)
  local conns = entity.fluidbox.get_pipe_connections(index)
  if not conns or #conns == 0 then error(entity.name .. " has no connections on box " .. index) end
  local at   = conns[1].target_position
  local step = { at.x - entity.position.x, at.y - entity.position.y }
  local span = math.max(math.abs(step[1]), math.abs(step[2]))
  step = { step[1] / span, step[2] / span }

  local pipes = {}
  for i = 0, RUN_PIPES - 1 do
    pipes[#pipes + 1] = must(surface.create_entity({
      name = "pipe", position = { at.x + step[1] * i, at.y + step[2] * i }, force = force,
    }), string.format("%s: pipe %d", entity.name, i))
  end

  -- A tank carries four connections at fixed offsets rather than one per edge tile, so where it has
  -- to stand is computed by probing one and reading where its connections landed -- the trick
  -- check-blanket.ps1 and check-breeding.ps1 use.
  --
  -- WHICH of the four is not a detail, and taking the first one is a bug this rig was caught by
  -- (#68). A tank's connections sit at asymmetric offsets from its centre -- the first is (-1,-2)
  -- and the one this ends up using on a northward run is (+2,+1) -- so aiming an ARBITRARY one at
  -- the last pipe can put the tank's body BACK ALONG the run, over pipes already laid. That
  -- placement is accepted and it splits the segment in two: nineteen pipes on one side, the last
  -- pipe and the tank on the other, which reads as a run barely larger than the box. So the
  -- connection is chosen for the candidate that lands the tank BEYOND the last pipe.
  local last  = { at.x + step[1] * (RUN_PIPES - 1), at.y + step[2] * (RUN_PIPES - 1) }
  local seed  = { last[1] + step[1] * 6, last[2] + step[2] * 6 }
  local probe = must(surface.create_entity({ name = RUN_TANK, position = seed, force = force }),
    "storage tank probe")
  local candidates = {}
  for _, c in ipairs(probe.fluidbox.get_pipe_connections(1)) do
    -- Where the tank would stand if THIS connection were the one meeting the last pipe.
    local px, py = seed[1] + (last[1] - c.target_position.x), seed[2] + (last[2] - c.target_position.y)
    -- Beyond the last pipe, measured along the run rather than by eye.
    if (px - last[1]) * step[1] + (py - last[2]) * step[2] > 0 then
      candidates[#candidates + 1] = { px, py }
    end
  end
  probe.destroy()
  if #candidates == 0 then
    error("no storage tank connection puts the tank beyond the end of the run")
  end
  local tank = must(surface.create_entity({
    name = RUN_TANK, position = candidates[1], force = force,
  }), "storage tank")

  return { pipes = pipes, tank = tank, first = pipes[1], index = index, entity = entity }
end

--- An rf-isotope-collector on its own, with its TRITIUM box piped into a real run.
---
--- No reactor and nothing driving it: the question is what the engine REPORTS for a box, and a
--- collector with a pipe on it is the arrangement check-blanket.ps1 already builds for real.
local function build_collector_outlet(surface, force, ox, oy)
  local collector = must(surface.create_entity({
    name = "rf-isotope-collector", position = { ox, oy }, force = force,
    direction = defines.direction.south, raise_built = false,
  }), "rf-isotope-collector")
  local index = box_index(collector, function(box)
    return box.filter and box.filter.name == "rf-tritium"
  end)
  local run = plumb(surface, force, collector, index)
  run.label = "collector tritium"
  return run
end

--- An rf-reactor with an rf-heat-exchanger BOLTED to its energy face, which is what apply()'s
--- clamp is actually written against since #86.
---
--- Unregistered, so control.lua never steps it: nothing here is about what a reactor DOES. The
--- exchanger is unpowered and unwatered for the same reason -- what is being asked is what
--- get_capacity reports, not whether anything burns.
---
--- The exchanger's own position comes off the two prototypes: it is placed once as a probe, asked
--- where its north energy connection sits relative to itself, and placed again so that connection
--- stands on the tile the reactor's south output points at. That is the BOLT alignment and not the
--- pipe-run one; ADR 0018's Consequences call the difference a trap, and aligning target against
--- target leaves the two machines a tile apart looking exactly like a refusal.
local function build_energy_bolt(surface, force, ox, oy)
  local reactor = must(surface.create_entity({
    name = "rf-reactor", position = { ox, oy }, force = force, raise_built = false,
  }), "rf-reactor for the energy bolt")
  local index = box_index(reactor, function(box) return box.production_type == "output" end)

  local south
  for _, c in pairs(reactor.fluidbox.get_pipe_connections(index)) do
    if c.target_position.y > c.position.y then south = c end
  end
  if not south then error("rf-reactor has no south-facing energy output; ADR 0031 says it must") end

  local probe = must(surface.create_entity({
    name = "rf-heat-exchanger", position = { ox, oy + 40 }, force = force,
  }), "probe rf-heat-exchanger")
  local fuel = box_of(probe, "rf-reactor-energy")
  if not fuel then
    probe.destroy()
    error("rf-heat-exchanger has no box filtered to rf-reactor-energy")
  end
  local intake
  for _, c in pairs(probe.fluidbox.get_pipe_connections(fuel)) do
    if c.target_position.y < c.position.y then intake = c end
  end
  if not intake then
    probe.destroy()
    error("rf-heat-exchanger has no north-facing energy connection")
  end
  local off = { intake.position.x - probe.position.x, intake.position.y - probe.position.y }
  probe.destroy()

  local exchanger = must(surface.create_entity({
    name = "rf-heat-exchanger",
    position = { south.target_position.x - off[1], south.target_position.y - off[2] },
    force = force,
  }), "rf-heat-exchanger bolted to the reactor's energy face")

  return { entity = reactor, index = index, neighbour = exchanger, label = "reactor energy" }
end

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player
  force.research_all_technologies()
  -- AND THEN PUT EVERY LADDER BACK (#53, #443). Every prediction below is computed with
  -- logic.reactor -- the module's own spec -- against a reactor the game is simulating, and each
  -- ladder makes a spec field a per-force number, so a researched force runs a reactor this rig
  -- would be predicting the wrong physics for. Held at the shipped values rather than followed,
  -- because no ladder's field is one of this rig's variables; what research does to a reactor is
  -- scripts/check-confinement.ps1's subject. READ OFF rf_ladders, and ASSERTED rather than arranged
  -- silently: a rung rf_unresearch missed fails rf_assert_research.
  rf_unresearch(force, logic, logic.reactor)
  rf_assert_research(record, force, logic, logic.reactor, false)

  local size = reactor_footprint()
  local span_x = 6 * (size + GAP) + TAIL + 40
  -- Thirteen rows at sixty apart. A row built on ungenerated ground is a row that silently is not
  -- there.
  local span_y = 13 * 60 + 40

  surface.request_to_generate_chunks({ span_x / 2, span_y / 2 },
    math.ceil((math.max(span_x, span_y) / 2 + 96) / 32))
  surface.force_generate_chunk_requests()

  local tiles = {}
  for x = -60, span_x do
    for y = -40, span_y do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = { { -60, -40 }, { span_x, span_y } } })) do
    if e.type ~= "character" then e.destroy() end
  end

  -- Rows sixty apart: fifteen tiles of reactor, ten more down to the substation below it, and clear
  -- ground between. Two rows that touched would be one run.
  storage.cells = {
    pair  = build_row(surface, force,   0.5, 2, 0,    1, "pair"),
    trio  = build_row(surface, force,  60.5, 3, 0,    1, "trio"),
    five  = build_row(surface, force, 120.5, 5, 0,    1, "five"),
    bare  = build_row(surface, force, 180.5, 3, 0,    3, "bare"),
    piped = build_row(surface, force, 240.5, 3, TAIL, 3, "piped"),
    -- Unregistered as well as unpowered, so no simulation steps it: what happens to it is the
    -- engine's alone.
    mix   = build_row(surface, force, 300.5, 3, 0,    0, "mix", true),
    -- ONE reactor and no pipe: the run is its own box.
    solo  = build_row(surface, force, 360.5, 1, 0,    1, "solo"),
    -- ONE reactor with a long tail: a run beside it to give heat to, if it gave any.
    solopipe = build_row(surface, force, 420.5, 1, TAIL, 1, "solopipe"),
    -- Seeded full; built 2H1, see the header.
    full  = build_line(surface, force, 540.5, "full", "2H1"),
  }
  -- Kept OUT of storage.cells, which is seeded wholesale: every unit in it is the heater's.
  storage.feed = build_line(surface, force, 480.5, "feed", "1H2")
  -- The OUTPUT box that is actually on a run (#68), and the one that has a bolted neighbour instead
  -- (#86). Kept out of storage.cells too: these carry tritium and reactor energy.
  storage.outlets = { build_collector_outlet(surface, force, 7.5, 660.5) }
  storage.energy_bolt = build_energy_bolt(surface, force, 60.5, 660.5)
  storage.order = { "mix", "pair", "trio", "five", "solo", "solopipe", "bare", "piped", "full" }
  log("POOL-RIG built")
end)

-- ---------------------------------------------------------------- seeding, then one step
script.on_event(defines.events.on_tick, function()
  local tick, cells = game.tick, storage.cells
  if not cells then return end

  if tick <= SEED_UNTIL then
    for _, cell in pairs(cells) do top_up(cell, SEED_C) end
    if tick == SEED_UNTIL then
      -- The last thing done to `mix`, after which it is left alone: one end of the run fifty times
      -- hotter than the other, nothing powered, nothing driving it.
      local first = cells.mix.reactors[1]
      first.fluidbox[1] = { name = PLASMA, amount = box_volume(first), temperature = HOT_C }
      local hot, cold, s = spread(cells.mix.reactors)
      storage.mix_start = { hot = hot, cold = cold, spread = s }
    end
    return
  end

  -- `full`'s segment, filled once the seeding has stopped. Seeding writes every box sixty times and
  -- leaves both "input" boxes full and the segment nearly empty: without this it read 167.04 of the
  -- 2800 get_capacity reports for it, against 2799.98 with it (2026-10-21, Factorio 2.0.77). The
  -- segment's capacity counts the two boxes' volumes and its contents do not count theirs, the
  -- way probe-plasma-input-box.ps1 reads a full line. So the segment is topped up through one pipe
  -- with insert_fluid, which adds to it rather than replacing a box, and the heater keeps it full.
  if tick == SEED_UNTIL + 1 then
    local pipe = cells.full.pipe
    local room = pipe.fluidbox.get_capacity(1) - segment_holds(pipe)
    pipe.insert_fluid({ name = PLASMA, amount = room, temperature = SEED_C })
  end

  -- One step of the simulation, caught either side. The prediction is made from each row's OWN
  -- state, the amounts and temperatures its reactors actually hold, because the rows have burnt
  -- down at their own rates since the seeding stopped.
  if tick == STEP_BEFORE then
    storage.before = {}
    for name, cell in pairs(cells) do
      local inputs = {}
      for i, r in ipairs(cell.reactors) do
        local box = r.fluidbox[1]
        inputs[i] = {
          amount = box and box.amount or 0,
          celsius = box and box.temperature or 0,
          energy = r.energy,
        }
      end
      storage.before[name] = { heat = heat(cell), inputs = inputs }
    end
  elseif tick == STEP_AFTER then
    storage.after = {}
    for name, cell in pairs(cells) do storage.after[name] = { heat = heat(cell) } end
  elseif tick == MIX_AT then
    local hot, cold, s = spread(cells.mix.reactors)
    storage.mix_end = { hot = hot, cold = cold, spread = s }
  end
end)

-- ---------------------------------------------------------------- the report
script.on_nth_tick(CHECK_AT, function()
  if game.tick == 0 or storage.done then return end
  storage.done = true

  local cells = storage.cells
  -- The plasma's floor, read off the prototype: check_plasma_bounds() in control.lua requires the
  -- fluid's default_temperature and the simulation's min_temperature_c to be one number.
  local FLOOR_C = prototypes.fluid[PLASMA].default_temperature

  -- ------------------------------------------------------------ what get_capacity actually says
  --
  -- Not what this repo believed, which is why it is checked rather than assumed. A PIPE reports the
  -- whole run; a REACTOR's own box reports its own volume. The 2.0 API documents neither, and
  -- control.lua carried a comment asserting the second was the first.
  for _, name in ipairs(storage.order) do
    local cell = cells[name]
    local reactor = cell.reactors[1]
    local pipe
    for _, e in ipairs(cell.all) do
      if e.name == "rf-pipe" then pipe = e break end
    end
    local declared = declared_capacity(cell)
    local from_reactor = reactor.fluidbox.get_capacity(1)
    local from_pipe    = pipe and pipe.fluidbox.get_capacity(1) or -1

    -- `solo` is one reactor and no pipe, so there is nothing to ask. Skipped rather than failed:
    -- the run having no pipe is the point of that cell.
    if pipe then
      record(rel(from_pipe, declared) < 1e-9,
        string.format("%s: a pipe's get_capacity reports the whole run", name),
        string.format("%.6g against %.6g declared across %d entities", from_pipe, declared, #cell.all))
    end
    record(rel(from_reactor, box_volume(reactor)) < 1e-9,
      string.format("%s: a reactor's get_capacity reports its own box, NOT the run", name),
      string.format("%.6g against a box of %.6g and a run of %.6g",
        from_reactor, box_volume(reactor), declared))
  end

  -- The same question of an OUTPUT box, asked while that box is ON A RUN (#68). That they were
  -- built AT ALL is asserted first: `ipairs(nil-or-empty)` is a loop that runs zero times and
  -- reports nothing, so an on_init edit that dropped this row would delete checks and still print
  -- PASS.
  record(storage.outlets ~= nil and #storage.outlets == 1,
    "the output-box run was built",
    storage.outlets and string.format("%d built", #storage.outlets)
      or "storage.outlets is nil -- nothing below this line ran")

  for _, run in ipairs(storage.outlets or {}) do
    local entity  = run.entity
    local own     = indexed_volume(entity, run.index)
    local report  = entity.fluidbox.get_capacity(run.index)
    local segment = run.first.fluidbox.get_capacity(1)

    -- Connected, established from the connection itself rather than from the pipes having been
    -- placed. A run laid one tile clear of the machine would place perfectly and measure nothing.
    local conn = entity.fluidbox.get_pipe_connections(run.index)[1]
    record(conn.target ~= nil,
      string.format("%s: the box is actually plumbed into the run", run.label),
      string.format("%d pipe(s) and a %s off %s box %d",
        #run.pipes, RUN_TANK, entity.name, run.index))

    -- And that the run is big enough for the two answers to be told apart.
    record(segment > own * 4,
      string.format("%s: the run is materially larger than the box", run.label),
      string.format("run %.6g against a box of %.6g -- %.1fx; last pipe %.6g, tank %.6g at (%g, %g)",
        segment, own, segment / own,
        run.pipes[#run.pipes].fluidbox.get_capacity(1),
        run.tank.fluidbox.get_capacity(1), run.tank.position.x, run.tank.position.y))

    -- The run is the PIPES AND THE TANK and nothing else, checked against their declared volumes.
    -- An engine that started folding a machine's output box into the segment it is piped to would
    -- move this number by exactly that box.
    local expected = RUN_PIPES * prototypes.entity["pipe"].fluidbox_prototypes[1].volume
      + prototypes.entity[RUN_TANK].fluidbox_prototypes[1].volume
    record(rel(segment, expected) < 1e-9,
      string.format("%s: the run is the pipe and the tank, and does NOT include the box", run.label),
      string.format("%.6g against %d pipe(s) plus a %s declaring %.6g -- the box's %.6g is not in it",
        segment, RUN_PIPES, RUN_TANK, expected, own))

    -- One segment, not several: a tank placed across the run leaves a big number on one side of the
    -- break and a small one on the other, and reading either alone is how a split run passes.
    local split
    for i, pipe in ipairs(run.pipes) do
      if rel(pipe.fluidbox.get_capacity(1), segment) > 1e-9 then split = i break end
    end
    local tank_says   = run.tank.fluidbox.get_capacity(1)
    local tank_agrees = rel(tank_says, segment) < 1e-9
    local detail
    if split then
      detail = string.format("pipe %d reports %.6g against the run's %.6g",
        split, run.pipes[split].fluidbox.get_capacity(1), segment)
    elseif not tank_agrees then
      detail = string.format("the tank reports %.6g against the run's %.6g", tank_says, segment)
    else
      detail = string.format("%d pipe(s) and the tank all report %.6g", #run.pipes, segment)
    end
    record(split == nil and tank_agrees,
      string.format("%s: every pipe and the tank are on ONE segment", run.label), detail)

    record(rel(report, own) < 1e-9,
      string.format("%s: get_capacity reports the box's own volume, NOT the run it is on", run.label),
      string.format("%.6g against a declared box of %.6g and a run of %.6g", report, own, segment))
  end

  -- ------------------------------------------------- and the same question of a BOLTED neighbour
  --
  -- apply() clamps what it writes into the reactor's energy box against get_capacity on that box,
  -- and since #86 that box's only possible neighbour is a machine bolted flat to it. If the engine
  -- folded a bolted neighbour's box into the reading, apply() would clamp against 1200 where the box
  -- takes 1000 and the surplus would be discarded with nothing saying so.
  local bolt = storage.energy_bolt
  record(bolt ~= nil, "the bolted energy row was built",
    bolt and string.format("%s and %s", bolt.entity.name, bolt.neighbour.name)
      or "storage.energy_bolt is nil -- nothing below this line ran")
  if bolt then
    local joined
    for _, c in pairs(bolt.entity.fluidbox.get_pipe_connections(bolt.index)) do
      if c.target and c.target.owner == bolt.neighbour then joined = c end
    end
    record(joined ~= nil,
      "reactor energy: the exchanger really is bolted to the reactor's energy face, with no pipe",
      joined and string.format("joined at (%g, %g)", joined.position.x, joined.position.y)
        or "no connection on the energy box reaches the exchanger")

    local own      = indexed_volume(bolt.entity, bolt.index)
    local report   = bolt.entity.fluidbox.get_capacity(bolt.index)
    local their    = bolt.neighbour.fluidbox.get_capacity(
      box_of(bolt.neighbour, "rf-reactor-energy"))
    record(rel(report, own) < 1e-9,
      "reactor energy: get_capacity reports the box's own volume, NOT the box plus what is bolted to it",
      string.format("%.6g against a declared box of %.6g, with a %.6g-unit exchanger box joined to it",
        report, own, their))
  end

  -- ------------------------------------------------------------ the engine alone: `mix`
  --
  -- Nothing powered, nothing simulated, one end fifty times hotter. Under input-output the run
  -- flattened to a tenth of a percent in two seconds; under "input" a box gives nothing back to the
  -- run, so nothing carries the hot end's heat to the others.
  local ms, me = storage.mix_start, storage.mix_end
  record(ms ~= nil and me ~= nil, "the passive run was sampled before and after it was left alone")
  if ms and me then
    record(ms.spread > 0.9, "mix: it really did start fifty times apart",
      string.format("%.4g C against %.4g C, spread %.1f%%", ms.hot, ms.cold, ms.spread * 100))
    record(me.spread > 0.9,
      "mix: and with nothing driving it, the ends stay apart, so heat does not cross the run",
      string.format("%.6g C against %.6g C after %d ticks, spread %.3g%%",
        me.hot, me.cold, MIX_AT - SEED_UNTIL, me.spread * 100))
  end

  -- ------------------------------------------------------------ the run's wiring
  --
  -- That every row is what it claims to be. If a substation reached further than intended, every
  -- floor row below would pass and mean nothing.
  for _, name in ipairs({ "pair", "trio", "five", "full" }) do
    local cell = cells[name]
    local wired = 0
    for _, r in ipairs(cell.reactors) do
      if r.electric_network_id then wired = wired + 1 end
    end
    record(wired == cell.powered,
      string.format("%s: exactly %d of %d reactors is on an electric network",
        name, cell.powered, #cell.reactors),
      string.format("%d wired", wired))
  end
  do
    local feed = storage.feed
    local wired = (feed.reactors[1].electric_network_id and 1 or 0)
      + (feed.reactors[2].electric_network_id and 1 or 0)
    record(wired == 1 and feed.reactors[1].electric_network_id ~= nil
      and feed.heater.electric_network_id ~= nil,
      "feed: the heater and the near reactor are on an electric network, and the far one is not",
      string.format("%d of 2 reactors wired, heater %s", wired,
        feed.heater.electric_network_id and "wired" or "NOT wired"))
  end

  -- ------------------------------------------------------------ unshared heat, three counts
  --
  -- The unpowered reactors never spent a joule of their own. Seeded at SEED_C, each reads the floor
  -- by the check: its own step cools it and nothing on the run warms it. The input-output box held
  -- them at 4.8e7 to 1.2e8 C, 48 to 119 times the seed.
  for _, name in ipairs({ "pair", "trio", "five" }) do
    local cell = cells[name]
    local hot, cold = spread(cell.reactors, 2, #cell.reactors)
    local driven = temperature_of(cell.reactors[1])
    record(hot and math.abs(hot - FLOOR_C) < 0.5 and math.abs(cold - FLOOR_C) < 0.5,
      string.format("%s: every unpowered reactor is at the floor, so no heat came along the pipe", name),
      hot and string.format("%.6g to %.6g C across %d of them, against a floor of %.6g C and a seed of %.6g",
        cold, hot, #cell.reactors - 1, FLOOR_C, SEED_C) or "no plasma")
    record(driven and driven > SEED_C * 5,
      string.format("%s: beside a powered reactor far above the seed, so the run is not simply dead", name),
      driven and string.format("%.6g C against a seed of %.6g C", driven, SEED_C) or "no plasma")
  end

  -- ------------------------------------------------------------ shared feed: `feed`
  --
  -- Nothing seeded, so every unit in either box is one the heater made, and the far box's crossed
  -- the run past the near reactor. And the far reactor, unpowered, is read against the near one:
  -- the input-output box held an unpowered reactor on a filling line within 3% of its powered
  -- neighbour (plasma-input-box.md, the pair at 96 000 ticks).
  do
    local feed = storage.feed
    local near, far = feed.reactors[1], feed.reactors[2]
    local a, b = amount_of(near), amount_of(far)
    record(a > 0 and b > 0,
      "feed: one heater fed both reactors on its run, the far one past the near one",
      string.format("%.6g and %.6g units, all of it made by a heater that finished %d crafts",
        a, b, feed.heater.products_finished))
    local tn, tf = temperature_of(near), temperature_of(far)
    record(tn and tf and tf < tn * 0.1,
      "feed: and the unpowered one holds none of the powered one's heat",
      (tn and tf) and string.format("%.6g C against %.6g C, %.3g of it", tf, tn, tf / tn) or "no plasma")
  end

  -- ------------------------------------------------------------ the full line: `full` (#574)
  --
  -- Seeded full, kept full by the heater, read full. Built 2H1, the order #583 found the
  -- input-output box holding its unpowered reactor at 1.083e3 to 1.303e4 C on a full line.
  do
    local cell = cells.full
    local held, capacity, worst_box = segment_holds(cell.pipe), cell.pipe.fluidbox.get_capacity(1), 1
    for _, r in ipairs(cell.reactors) do
      worst_box = math.min(worst_box, amount_of(r) / box_volume(r))
    end
    record(held / capacity >= FULL_AT and worst_box >= FULL_AT,
      "full: built 2H1, the line is full when it is read",
      string.format("the run holds %.6g of %.6g, the emptier box at %.4g%%; the heater finished %d crafts",
        held, capacity, worst_box * 100, cell.heater.products_finished))
    local tp, tu = temperature_of(cell.reactors[1]), temperature_of(cell.reactors[2])
    record(tu and math.abs(tu - FLOOR_C) < 0.5,
      "full: and the unpowered reactor on the full line is at the floor",
      tu and string.format("%.6g C against a floor of %.6g C and a seed of %.6g", tu, FLOOR_C, SEED_C)
        or "no plasma")
    record(tp and tp > SEED_C * 5,
      "full: beside a powered reactor far above the seed",
      tp and string.format("%.6g C against a seed of %.6g C", tp, SEED_C) or "no plasma")
  end

  -- ------------------------------------------------------------ the bookkeeping
  --
  -- What one step SHOULD add to a run, asked of the shipped physics, against what the run gained,
  -- as the sum of amount x absolute temperature over every box on it. A box that gives nothing back
  -- keeps the whole of its step whatever is plumbed beside it; the input-output box kept 94.6%
  -- alone, 75.4% beside twenty pipes, 57.6% three to a run and 67.0% with a tail (2026-10-05).
  local before, after = storage.before, storage.after
  record(before ~= nil and after ~= nil, "one simulation step was captured",
    before and after and string.format("across ticks %d to %d, one interval holding one step",
      STEP_BEFORE, STEP_AFTER) or "not captured")
  if before and after then
    local dt = INTERVAL / 60
    for _, name in ipairs({ "solo", "solopipe", "bare", "piped" }) do
      local cell = cells[name]
      local predicted, clamped = 0, false
      for _, input in ipairs(before[name].inputs) do
        local result = logic.step(SPEC, PLASMA, input.amount, input.celsius, input.energy, dt)
        if result then
          -- A reactor short of buffer would spend less than a full step's heating, and the
          -- prediction would still be right -- but about a different thing.
          if input.energy < SPEC.heating_power_w * dt then clamped = true end
          predicted = predicted
            + (input.amount - result.plasma_consumed) * (result.temperature_c + 273.15)
            - input.amount * (input.celsius + 273.15)
        end
      end
      record(not clamped,
        string.format("%s: every reactor had the buffer for a full step, so the prediction is of one", name))
      -- Bounded on both sides: under 0.98 is the input-output box's loss coming back, over 1.02 is
      -- energy appearing.
      local kept = (after[name].heat - before[name].heat) / predicted
      record(kept > 0.98 and kept < 1.02,
        string.format("%s: the reactors keep all of what they spent, so none of it leaves into the run", name),
        string.format("%.6g predicted against %.6g measured unit-K -- %.1f%% of it kept; run capacity %.6g",
          predicted, after[name].heat - before[name].heat, kept * 100, declared_capacity(cell)))
    end
  end

  local report = storage.report
  report.lines[#report.lines + 1] = string.format("%s: %d checks, %d failures",
    report.failures == 0 and "PASS" or "FAIL", report.checks, report.failures)
  for _, line in ipairs(report.lines) do log("POOL-RIG " .. line) end
end)
'@
    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') `
        -Value $lua.Replace('__RIGBUILD__', (Get-RigBuildLua)).Replace('__TICKS__', "$Ticks").Replace('__INTERVAL__', "$interval").Replace('__TAIL__', "$Tail")
}

$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    New-ModJunctions -ModDirectory $modDir -Links (Get-ModLinks -Root $repoRoot -Mods $ourMods)
    foreach ($m in $alsoMods) {
        if ($m.Kind -eq 'zip') { Copy-Item -LiteralPath $m.Path -Destination $modDir }
        else { New-ModJunctions -ModDirectory $modDir -Links @{ $m.Name = $m.Path } }
    }
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabledBundled -Mods ($ourMods + $rigName + @($alsoMods | ForEach-Object Name))
    if ($alsoMods) { Write-Host "also loading: $($alsoMods.Name -join ', ')" }
    $bundledOn = if ($enabledBundled) { $enabledBundled -join ', ' } else { 'none (base 2.0 only)' }
    Write-Host "bundled enabled: $bundledOn  |  interval $interval ticks, tail $Tail pipes, check at tick $Ticks"
    Write-Rig

    $save = Join-Path $temp 'pooling.zip'
    Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create' | Out-Null
    $runOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', "$($Ticks + 60)", '--benchmark-runs', '1', '--disable-audio')

    $reported = @(Get-Content $runOut | Select-String -Pattern 'POOL-RIG (ok|FAIL|PASS)' |
        ForEach-Object { ($_ -split 'POOL-RIG ', 2)[1].TrimEnd() })
    if ($reported.Count -eq 0) { throw 'the rig reported nothing; it never reached its check tick.' }

    foreach ($line in $reported) { Write-Host "  $line" }

    $verdict = $reported | Where-Object { $_ -match '^(PASS|FAIL): ' } | Select-Object -Last 1
    if (-not $verdict)              { throw 'the rig produced no verdict line.' }
    if ($verdict -notmatch '^PASS') {
        throw ("a pooling check failed: $verdict. A floor or bookkeeping row failing says heat is " +
               "travelling between reactors again, which ADR 0040 says it must not: read the " +
               "plasma box's production_type first.")
    }

    Write-Host ''
    Write-Host 'OK - reactors on one run share its feed and not its heat: an unpowered reactor sits at'
    Write-Host '     the floor beside a powered one, on a filling line and a full one, and each reactor'
    Write-Host '     keeps all of what it spends. See docs/adr/0040-the-plasma-box-is-input.md.'
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'check-pooling' }
}

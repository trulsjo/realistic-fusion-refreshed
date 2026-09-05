<#
.SYNOPSIS
    Checks that reactors on one run of rf-pipe really do work from a single pool, under supply that
    is allowed to run out. Discharges #40.

.DESCRIPTION
    ADR 0011 rests on the engine mixing plasma across a fluid segment so that no Lua in this mod
    tracks connectivity. Until now that claim rested on two things and neither was the right shape:
    a one-off headless smoke test during #23 that no longer exists, and bench-reactors.ps1 -Pooled,
    which CANNOT test it -- every segment there is pinned at 100% by an infinity pipe filter, so the
    box-versus-segment write semantics never come under strain. That measures the cost of sharing,
    not the correctness of it.

    So nothing here uses an infinity pipe. Every cell is seeded and then left alone to burn down.

    WHAT IS BUILT

      mix       Three reactors on one run, NOTHING POWERED, seeded fifty times apart end to end.
                The engine's mixing on its own, with no simulation driving it. If a run shares at
                all, this must flatten -- and it does, from fifty times to under a tenth of a
                percent, inside two seconds.

      pair      Two reactors bridged by rf-pipe, and ONLY THE WESTMOST IS ON AN ELECTRIC NETWORK.
      trio      Three, the same way.
      five      Five, the same way.

                One powered reactor per row is what makes these discriminating rather than
                decorative: an unpowered reactor runs its whole simulation step with heating clamped
                to zero, so any heat it holds arrived along the pipe. Three counts, because a
                two-reactor result is a coincidence waiting to be found out.

      solo      ONE reactor and no pipe: the run is its own box, so nothing can mix and no other
                reactor can write to it.
      solopipe  The same one reactor with a tail of rf-pipe. Still a single writer, but now there is
                a run to mix across.
      bare      Three reactors, all powered, bridged and nothing else.
      piped     The same three, plus a tail of rf-pipe.

      outlets   An rf-isotope-collector and an rf-reactor with their OUTPUT boxes piped into a run
                of vanilla pipe and a tank. Nothing is simulated here and nothing burns down: the
                row exists to ask get_capacity a question about a box that is on a segment.

                The four the bookkeeping is measured on, and the reason there are four is that a
                shortfall on a row of three has two candidate causes which predict the same
                ordering: the engine's mixing losing heat, and reactors overwriting each other
                inside one step. One reactor cannot overwrite anyone, so solo and solopipe separate
                them.

    WHAT IS ASSERTED, AND WHY NOT TEMPERATURE ALONE

    Temperature converging is necessary and nowhere near sufficient: reactors seeded alike and
    running alike converge without sharing anything. So the run also checks the semantics control.lua
    is written against, none of which the 2.0 API documents. See the pooling section of
    docs/research/reactor-runtime-cost.md, which this script is the source for.

    The check that decides whether apply() is right is the bookkeeping. A reactor computes a
    temperature rise against its own share and writes it back; the engine then dilutes that rise by
    exactly that share. apply()'s comment claims the two errors cancel, so the pool gains what the
    reactor spent whatever else is plumbed into the run. That is measured across ONE step against
    the sum of amount x absolute temperature over every box -- proportional to the 3NkT the
    simulation works in -- with the step predicted by requiring reactor-logic out of the shipped mod
    rather than by reimplementing it.

    IT DOES NOT BALANCE. A lone reactor with nothing plumbed to it keeps 95% of what it spent; the
    same reactor on a twenty-pipe run keeps 75%, which is the engine's mixing and nothing else; three
    reactors bridged together keep 58%, which is more than mixing accounts for.

    THE EXCESS IS NOT update()'S WRITE SHAPE, AND THIS SCRIPT USED TO SAY IT WAS. Measured under #73
    by the `probe` row and the three shape rows: a Lua write reaches no other box on the run in the
    same tick, and the shipped two-pass shape, a single-pass shape and a relative write all keep the
    same 72.18% on identical rows. What the excess IS remains open -- the two cells that would
    separate the remaining candidates differ in fill and temperature as well as in writer count.

    WHAT THIS FOUND THAT WAS NOT EXPECTED

    Three things, all recorded in the research note rather than only here.

    THE ENGINE'S FLUID MIXING DESTROYS HEAT. The `idle` cell is three reactors built with
    raise_built = false, so nothing this mod or this rig writes ever touches them again: no
    simulation runs on them at all. One box is raised fourfold, once, and the run is left to flatten.
    Its plasma AMOUNT does not move by a part in a hundred thousand -- nothing is consuming or
    supplying -- and yet 18% of the sum of amount x temperature is gone by the time it has flattened.
    Mixing is supposed to be a mass-weighted average, which conserves that sum exactly. The control
    is the same run undisturbed, which holds its heat to nine parts in a million over the same
    window, so these entities do not leak on their own.

    It is why several checks here are written as characterisations with a band rather than as
    equalities: a future version of Factorio that mixed conservatively would fail them, and should,
    because the note would then be wrong.

    A REACTOR'S get_capacity REPORTS ITS OWN BOX, NOT THE RUN. A pipe's reports the run. This repo
    believed and wrote down the opposite, in control.lua's apply() and in the research note.

    AND THAT HOLDS FOR AN OUTPUT BOX THAT IS ON A RUN (#68), which is the shape the two call sites
    in control.lua that clamp against get_capacity actually have. It used to be asked only of an
    output box plumbed into NOTHING -- the case where the box and the segment are the same object,
    which cannot tell the two answers apart. The `outlets` row builds an rf-isotope-collector and an
    rf-reactor with their output boxes piped into twenty pipes and a tank, a 27000-unit run against
    a 500-unit and a 1000-unit box, and both boxes still answer their own volume.

    A BOX THAT IS WRITTEN EVERY STEP SITS PERSISTENTLY HOTTER THAN THE REST OF ITS RUN. In `five`
    the four unpowered reactors agree with each other to two parts in ten thousand, and the powered
    one sits about a tenth above all of them -- steadily, not as a transient, and it does not close
    when the sample is taken off the simulation's beat. Heat enters at one box and leaves it no
    faster than the pipe carries it away, so "one pool at one mixed temperature" is an idealisation
    with a source-side gradient in it. Nothing in this mod depends on it being otherwise and the
    bookkeeping is unaffected, but it is the kind of thing otherwise discovered by a player
    wondering why one reactor of six reads differently from its neighbours.

    WHAT IT DOES NOT COVER

    One surface, one plasma, no pumps and no pipe-to-ground on the run. Nothing here says anything
    about a segment being split or merged while running: ADR 0011 has no code for that because the
    engine owns it, and observing it is a different ticket.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Ticks
    Ticks to run before the final check. Long enough that a pool fed by one reactor is visibly hot
    and visibly down on plasma. Forced off the simulation's beat -- see the adjustment below.

.PARAMETER Tail
    How many rf-pipe to hang off the end of the `piped` row. The bookkeeping check is only as strong
    as the gap between the two runs' capacities, so this wants to be enough pipe to matter: twenty
    doubles a bridged three-reactor row's pipe count and adds half again to its volume.

.PARAMETER With
    Bundled mods to enable, e.g. -With space-age. Off by default, so the rig keeps checking base 2.0
    unless asked otherwise (ADR 0003, ADR 0008).

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/check-pooling.ps1
    pwsh -File scripts/check-pooling.ps1 -Tail 40 -KeepTemp
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [ValidateRange(600, 200000)] [int] $Ticks = 1800,
    [ValidateRange(1, 500)]      [int] $Tail  = 20,
    [string[]] $With = @(),
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$rigName  = 'rf-pooling-rig'

# The shipped cadence, read rather than remembered. The rig samples on and around the simulation's
# own beat to catch a single step, and UPDATE_INTERVAL is a local in control.lua that nothing
# exports.
$controlLua = Join-Path $repoRoot 'realistic-fusion-refreshed/control.lua'
if ((Get-Content $controlLua -Raw) -match '(?m)^local UPDATE_INTERVAL = (\d+)') {
    $interval = [int]$Matches[1]
} else {
    throw "could not read UPDATE_INTERVAL from $controlLua; the one-step measurement needs it."
}

# Off the beat on purpose. A check landing on a simulation tick reads every driven box in the
# instant after it was written and before the engine has moved any of it, which makes a shared run
# look more like a set of islands than it is. That is not the whole of the gradient this rig found
# -- see the note above, the rest of it is real and does not close -- but it is a needless part, and
# one nobody would think to look for.
if ($Ticks % $interval -eq 0) { $Ticks++ }

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe
try {
    $enabledBundled = Resolve-BundledSelection -Requested $With -Bundled $bundled
}
catch { throw "-With $($_.Exception.Message)" }

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
-- a reactor's step should do and then asks the pool whether it got it; a copy would only ever
-- confirm the copy.
local logic = require("__realistic-fusion-refreshed__/scripts/reactor-logic")
local SPEC  = logic.reactor

-- Seeded well below anything that fuses hard, so an unpowered reactor that ends up hot can only
-- have got there through the pipe. Nothing below depends on the reaction being negligible -- every
-- claim here is about sharing rather than about physics -- but it makes that one result mean the
-- single thing it is meant to mean.
local SEED_C = 1e6

-- What `mix` starts fifty times hotter at. Big enough that flattening is unmistakable rather than a
-- rounding difference, and still well inside the plasma's declared range.
local HOT_C = SEED_C * 50

local GAP = 5      -- clear tiles between one reactor and the next, and so the bridge length

-- Seeding runs for a while rather than once. This used to be explained by saying that a Lua write
-- REPLACES a box and the engine re-splits the run between writes, so a single seeding pass throws
-- away most of what the earlier writes put in -- "measured, a three-reactor run seeded in one pass
-- settles at 45% of capacity rather than 100%".
--
-- THE 45% IS REAL AND THE EXPLANATION WAS WRONG (#73). The `seedonce` row below is seeded exactly
-- once and sits at 44.6% of declared capacity; `mix` is the same geometry seeded sixty times and
-- sits at 44.6% too. One pass leaves the run as full as sixty do, so the writes are not throwing
-- each other away. 44.6% is simply what a three-reactor bridged run holds against the SUM OF ITS
-- BOXES' DECLARED VOLUMES -- a fact about the segment, not about the write pattern.
--
-- Seeding for sixty ticks is kept anyway, and still earns its place: it is what puts every row at
-- the same known fill and gives the pool time to stop moving, which is the only reason the rows'
-- one-step gains are comparable.
local SEED_UNTIL = 60

-- How long the runs are left to settle before the bookkeeping step is measured. Seeding leaves the
-- pool moving -- a write replaces a box and the engine spends the next second or two re-splitting
-- the run -- and a "before" reading taken while that is still happening describes a state the step
-- was not computed against. Measured: the fill stops moving inside two seconds of the last write.
local SETTLE_UNTIL = SEED_UNTIL + 240

-- The window the bookkeeping is measured across: one whole interval, opening ON a simulation tick.
--
-- Both parts of that are load-bearing and both were arrived at by getting them wrong. THIS MOD'S
-- HANDLERS RUN BEFORE realistic-fusion-refreshed'S, because the rig depends on it and so loads after it. That
-- was not assumed -- it was measured: a window from tick 305 to 306, either side of a step, showed
-- the pool LOSING heat, which is what a window containing no step at all looks like. So a reading
-- taken on a step tick is the state that step is about to see, which is exactly what the prediction
-- needs as its input, and a window of one whole interval from there holds precisely one step.
--
-- If that order ever changed, this check fails loudly with a factor-sized discrepancy rather than
-- quietly: the prediction would be of a step the window does not contain.
--
-- The ticks of fluid movement inside the window cost nothing, because the quantity measured is
-- conserved by mixing: moving fluid about the run does not change the sum of amount x temperature.
local STEP_BEFORE = math.ceil(SETTLE_UNTIL / INTERVAL) * INTERVAL + INTERVAL
local STEP_AFTER  = STEP_BEFORE + INTERVAL

-- When `mix` is read. Three seconds after it is left alone, against a measured flattening time of
-- about two.
local MIX_AT = SEED_UNTIL + 180

-- The isolated mixing measurement: one box on the untouched run is raised fourfold, and the run is
-- read again once it has stopped moving. Two seconds, not the thirty ticks tried first -- at thirty
-- the run was still nine percent apart end to end, so the loss read then was a lower bound on the
-- loss rather than the figure. The reading now asserts that it flattened, so a window that was
-- still too short would say so instead of quietly understating the number.
-- Kept clear of MIX_AT and of the bookkeeping window: these all share one elseif chain, so two
-- landing on the same tick means the later one silently never runs. It did, and the check that
-- noticed was the one asking whether `mix` had been sampled at all.
local JOLT_AT  = SEED_UNTIL + 120
local JOLT_END = JOLT_AT + 120

local function record(ok, name, detail)
  storage.report = storage.report or { lines = {}, failures = 0 }
  if not ok then storage.report.failures = storage.report.failures + 1 end
  storage.report.lines[#storage.report.lines + 1] = string.format("%s  %s%s",
    ok and "ok  " or "FAIL", name, detail and ("  -- " .. detail) or "")
end

local function must(entity, what)
  if not entity then error(what .. " refused") end
  return entity
end

-- Relative difference, which is the shape every tolerance here is written in so none of them is an
-- absolute number that quietly stops meaning anything when a balance figure moves.
local function rel(a, b)
  local scale = math.max(math.abs(a), math.abs(b))
  if scale == 0 then return 0 end
  return math.abs(a - b) / scale
end

-- ---------------------------------------------------------------- reading a run
--
-- Every quantity below is taken over EVERY entity on the run rather than off one reactor, which is
-- the point: whether those are the same thing is exactly what is under test.

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

local function pooled(cell)
  local total = 0
  for _, e in ipairs(cell.all) do
    local box = e.fluidbox[1]
    if box then total = total + box.amount end
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

--- The nearest centre a reactor's own parity allows, on either axis.
---
--- bench-reactors.ps1 carries the same function for the same reason, and this script wanted it for
--- the same reason again: x was derived from the footprint here and y was passed in already ending
--- in .5 by every caller, which is correct only while the reactor is odd-sized. rf-reactor is
--- fifteen tiles and rf-aneutronic-reactor is ten, so pointing a row at the second one would have
--- put every reactor half a tile out in y, every connection half a tile from its bridge pipe, and
--- nothing would have errored -- which is #49 exactly.
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

--- One row of `count` reactors on a single run of rf-pipe, plus `tail` further pipes off the end.
---
--- `powered` is how many reactors get an electric network, counting from the west. A row that
--- passes fewer than all of them is one that can demonstrate sharing at all: an unpowered reactor
--- cannot heat its own plasma, so whatever it holds came along the pipe.
local function build_row(surface, force, oy, count, tail, powered, label, unregistered)
  local size, origin = reactor_footprint()
  local pitch  = size + GAP
  local bridge = pitch - size          -- GAP by construction, derived rather than assumed

  local cell = { label = label, reactors = {}, all = {}, powered = powered }

  -- Both axes snapped to the parity the reactor's own footprint demands, rather than x derived and
  -- y remembered.
  local cy = centre(oy, origin)

  for i = 0, count - 1 do
    local cx = centre(origin + i * pitch, origin)
    local reactor = must(surface.create_entity({
      -- Suppressing the build event is the only way one mod can keep another's per-tick handler
      -- off an entity: realistic-fusion-refreshed registers a reactor from that event and rescans only at
      -- on_init, which has already run. bench-reactors.ps1 -Ablate leans on the same seam.
      name = "rf-reactor", position = { cx, cy }, force = force, raise_built = not unregistered,
    }), label .. ": rf-reactor " .. i)
    cell.reactors[#cell.reactors + 1] = reactor
    cell.all[#cell.all + 1] = reactor

    if i > 0 then
      local west = edge_connection(reactor, true)
      for j = 1, bridge do
        cell.all[#cell.all + 1] = must(surface.create_entity({
          name = "rf-pipe", position = { west.x - bridge + j, west.y }, force = force,
        }), label .. ": bridge pipe")
      end
    end

    if i < powered then
      -- South of the row, so it neither collides with this reactor nor reaches the next: a
      -- substation covers eighteen tiles and the pitch is twenty, so the neighbour's near edge
      -- falls outside it. Asserted rather than trusted -- see the "on an electric network" check.
      -- A 2x2 entity centres on a tile BOUNDARY and a 1x1 on a tile CENTRE, so the substation
      -- wants whole numbers and the interface wants halves. Placing either off its own grid shifts
      -- it half a tile, which moves an 18x18 supply area by half a tile -- and the failure is
      -- silent, because everything still places. check-containment.ps1 carries the same note.
      local sx, sy = math.floor(cx + 0.5), math.floor(cy + 0.5) + 10
      local sub = must(surface.create_entity({
        name = "substation", position = { sx, sy }, force = force,
      }), label .. ": substation")
      local eei = must(surface.create_entity({
        name = "electric-energy-interface",
        position = { sx + 2.5, sy + 0.5 }, force = force,
      }), label .. ": power source")
      eei.power_production = 8e6
      -- And that the interface actually landed inside the substation's supply area, rather than
      -- being inferred from the reactor being powered later. Two entities on one network is the
      -- thing being built here; asserting it where it is built names the culprit if it breaks.
      if not eei.electric_network_id or eei.electric_network_id ~= sub.electric_network_id then
        error(string.format("%s: the power source at (%g, %g) is not on the substation's network",
          label, sx + 2.5, sy + 0.5))
      end
    end
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

--- Fill every box on the run to its own volume. Clamped to the box by the engine and then re-split
--- across the run, so one pass reaches nothing like capacity -- see SEED_UNTIL.
local function top_up(cell, celsius)
  for _, e in ipairs(cell.all) do
    e.fluidbox[1] = { name = PLASMA, amount = box_volume(e), temperature = celsius }
  end
end

-- ---------------------------------------------------------------- output boxes that are ON a run
--
-- WHY THIS EXISTS (#68). The capacity checks below used to ask their question of one shape only: an
-- input-output box on a run of rf-pipe, and an OUTPUT box that was plumbed into nothing. An
-- unconnected box reporting its own volume is not a measurement of the thing in doubt -- it is the
-- case where the box and the segment are the same object -- so the answer for a CONNECTED output
-- box was an extrapolation.
--
-- It matters because the two call sites in control.lua that clamp against get_capacity are both
-- output boxes with a pipe on them in ordinary play: deposit() writes into an rf-isotope-collector,
-- and apply() computes a lithium blanket's headroom from the same call. Neither is a reactor's
-- plasma box.
--
-- Vanilla pipes and a vanilla tank, because neither fluid here is contained: reactor energy and
-- tritium are ordinary fluids and a player plumbs them with ordinary pipes (ADR 0018, #26).

local RUN_PIPES = 20   -- 2000 units of pipe, so the run beats a 1000-unit box on pipe alone
local RUN_TANK  = "storage-tank"

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

--- An rf-reactor whose ENERGY box is on a run, which is the claim that used to rest on an
--- unconnected reading.
---
--- Unregistered, so control.lua never steps it: nothing here is about what a reactor DOES, and a
--- simulated reactor on this row would only add a writer to a measurement about geometry.
local function build_energy_outlet(surface, force, ox, oy)
  local reactor = must(surface.create_entity({
    name = "rf-reactor", position = { ox, oy }, force = force, raise_built = false,
  }), "rf-reactor for the energy outlet")
  local index = box_index(reactor, function(box) return box.production_type == "output" end)
  local run = plumb(surface, force, reactor, index)
  run.label = "reactor energy"
  return run
end

-- ---------------------------------------------------------------- the three candidate write shapes
--
-- WHY THESE EXIST (#73). The bookkeeping below establishes that three writers on a run lose more
-- than the engine's mixing accounts for, and #40 could not say WHICH part of update()'s shape did
-- it -- only that the excess was ours. These three rows answer that by running the candidate shapes
-- against each other on identical geometry from an identical state.
--
-- They are driven BY THIS RIG and built unregistered, so control.lua never touches them. That is
-- what makes them comparable in a way the cells above are not: an unregistered reactor is not
-- simulated at all, so three identically seeded rows sit in exactly the same state until this file
-- steps them, where `bare` and `piped` have been burning down at their own rates for four seconds.
--
-- The mechanism under test is stated once, here, because all three shapes are defined against it:
-- a Lua write REPLACES a box's contents, and the engine RE-SPLITS the run between writes. This rig
-- already depends on that second fact elsewhere -- it is why SEED_UNTIL seeds for sixty ticks
-- instead of once, a three-reactor run seeded in a single pass settling at 45% of capacity rather
-- than 100%. So any write of an absolute value computed from an earlier read discards whatever
-- arrived in that box since the read, including a neighbour's contribution.

--- The SHIPPED shape: read every reactor, then write every reactor.
--
-- Each write replaces a box using an amount and a temperature computed against the start-of-step
-- pool, so a reactor writing second overwrites the share of its neighbour's rise the engine handed
-- it between the two writes.
local function drive_two_pass(cell, dt, energy)
  local pending = {}
  for i, r in ipairs(cell.reactors) do
    local box = r.fluidbox[1]
    if box then
      local result = logic.step(SPEC, PLASMA, box.amount, box.temperature, energy(i), dt)
      if result then
        pending[#pending + 1] = { r = r, amount = box.amount, result = result }
      end
    end
  end
  for _, p in ipairs(pending) do
    local remaining = p.amount - p.result.plasma_consumed
    if remaining > 0 then
      p.r.fluidbox[1] = { name = PLASMA, amount = remaining, temperature = p.result.temperature_c }
    end
  end
end

--- Read and write in ONE iteration, so no box is ever written from a stale read.
--
-- Nothing is discarded, because a reactor only ever replaces its box with a value computed from
-- what that box held a moment earlier. The cost is that the pool a reactor computes against now
-- depends on iteration order: the second reactor works from a pool the first has already heated,
-- so reactors on a shared run stop being symmetric within a step.
local function drive_one_pass(cell, dt, energy)
  for i, r in ipairs(cell.reactors) do
    local box = r.fluidbox[1]
    if box then
      local result = logic.step(SPEC, PLASMA, box.amount, box.temperature, energy(i), dt)
      if result then
        local remaining = box.amount - result.plasma_consumed
        if remaining > 0 then
          r.fluidbox[1] = { name = PLASMA, amount = remaining, temperature = result.temperature_c }
        end
      end
    end
  end
end

--- Two passes, so the PHYSICS stays order-independent -- but a RELATIVE write.
--
-- Every reactor computes against the same start-of-step pool, exactly as the shipped shape does.
-- What changes is the write: the reactor's contribution is taken as a delta in amount x absolute
-- temperature and applied to whatever the box actually holds at the instant of writing, so a
-- neighbour's rise that has already arrived is added to rather than replaced.
--
-- The delta is in unit-K rather than joules because that is the quantity the engine's mixing
-- conserves and the quantity every measurement here is written in; particles-per-unit and k_B
-- cancel out of it. A real implementation in reactor-logic.lua would work in joules.
local function drive_rebased(cell, dt, energy)
  local pending = {}
  for i, r in ipairs(cell.reactors) do
    local box = r.fluidbox[1]
    if box then
      local result = logic.step(SPEC, PLASMA, box.amount, box.temperature, energy(i), dt)
      if result then
        pending[#pending + 1] = {
          r = r,
          consumed = result.plasma_consumed,
          delta = (box.amount - result.plasma_consumed) * (result.temperature_c + 273.15)
                - box.amount * (box.temperature + 273.15),
        }
      end
    end
  end
  for _, p in ipairs(pending) do
    local now = p.r.fluidbox[1]
    if now then
      local remaining = now.amount - p.consumed
      if remaining > 0 then
        local celsius = (now.amount * (now.temperature + 273.15) + p.delta) / remaining - 273.15
        -- Guarded rather than trusted: a write past the fluid's declared range is the engine's
        -- error to raise and would take the whole rig down with it. It cannot fire from the seeded
        -- state in one step, and if it ever does the check below says so instead of the run dying.
        if celsius > SPEC.max_temperature_c then
          celsius = SPEC.max_temperature_c
          storage.rebase_clamped = true
        end
        p.r.fluidbox[1] = { name = PLASMA, amount = remaining, temperature = celsius }
      end
    end
  end
end

-- ONLY THE FIRST REACTOR ON THE ROW IS GIVEN A BUFFER, and this is what makes the rows able to tell
-- the shapes apart at all.
--
-- With every reactor heating equally the row stays symmetric: identical reads, identical rises,
-- identical writes, and redistribution between writes has no difference to carry -- so all three
-- shapes came back at 71.6% to three figures, which says nothing about any of them. Heating one
-- reactor of three makes the writes differ while leaving the STARTING pool flat, so there is no
-- pre-existing gradient for the engine's mixing to charge against inside the window.
--
-- The other two still run a full step and still write: an unpowered reactor computes its confinement
-- loss and its (negligible) fusion against whatever its box holds. Those are precisely the writes
-- that can discard a neighbour's rise, which is the thing under test.
local function first_only(i)
  return i == 1 and math.huge or 0
end

local SHAPES = {
  { name = "twopass",  drive = drive_two_pass, label = "the shipped read-all-then-write-all" },
  { name = "onepass",  drive = drive_one_pass, label = "read and write in one iteration" },
  { name = "rebased",  drive = drive_rebased,  label = "two passes, relative write" },
}

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player
  force.research_all_technologies()
  -- AND THEN PUT THE CONFINEMENT LADDER BACK (#53), which is the one thing this rig must not have
  -- researched. Every prediction below is computed with logic.reactor -- the module's own spec --
  -- against a reactor the game is simulating, and #53 made confinement time a per-force number, so
  -- a researched force runs a reactor this rig would be predicting the wrong physics for. It shows
  -- up as the pool gaining MORE than the reactors were predicted to spend (102.5% of it, at the top
  -- rung), which reads exactly like energy appearing from nowhere and is not.
  --
  -- Held at the shipped value rather than followed, because this rig is a controlled experiment
  -- about what the ENGINE does to a fluid segment, and confinement time is not one of its variables.
  -- What research does to a reactor is scripts/check-confinement.ps1's subject.
  --
  -- The rungs unlock nothing, so nothing else here loses anything by their going.
  for _, rung in ipairs(logic.reactor.confinement_ladder or {}) do
    local technology = force.technologies[rung.technology]
    if technology then technology.researched = false end
  end

  local size = reactor_footprint()
  local span_x = 6 * (size + GAP) + TAIL + 40
  local span_y = 15 * 60 + 40

  surface.request_to_generate_chunks({ span_x / 2, span_y / 2 },
    math.ceil((math.max(span_x, span_y) / 2 + 96) / 32))
  surface.force_generate_chunk_requests()

  local tiles = {}
  for x = -40, span_x do
    for y = -40, span_y do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = { { -40, -40 }, { span_x, span_y } } })) do
    if e.type ~= "character" then e.destroy() end
  end

  -- Rows sixty apart: fifteen tiles of reactor, ten more down to the substation below it, and clear
  -- ground between. Two rows that touched would be one run, and every count here would be measuring
  -- the same pool.
  storage.cells = {
    pair  = build_row(surface, force,   0.5, 2, 0,    1, "pair"),
    trio  = build_row(surface, force,  60.5, 3, 0,    1, "trio"),
    five  = build_row(surface, force, 120.5, 5, 0,    1, "five"),
    bare  = build_row(surface, force, 180.5, 3, 0,    3, "bare"),
    piped = build_row(surface, force, 240.5, 3, TAIL, 3, "piped"),
    -- Unregistered as well as unpowered. It was only unpowered at first, which meant the
    -- simulation was still stepping it -- confinement loss, fusion, a box rewrite every six ticks
    -- -- while this file and the note both described its flattening as the engine's alone. It was
    -- not, until this argument was added.
    mix   = build_row(surface, force, 300.5, 3, 0,    0, "mix", true),
    -- ONE reactor and no pipe: the run is its own box, so no mixing is possible and no other
    -- reactor can write to it. If the bookkeeping does not balance here, nothing further along is
    -- about sharing.
    solo  = build_row(surface, force, 420.5, 1, 0,    1, "solo"),
    -- ONE reactor with a long tail: still a single writer, so still no reactor can overwrite
    -- another, but now there is a run to mix across. This is the cell that says whether mixing
    -- costs anything on its own.
    solopipe = build_row(surface, force, 480.5, 1, TAIL, 1, "solopipe"),
  }
  -- The cell that isolates the ENGINE, and the one that turned a puzzling shortfall in the
  -- bookkeeping into a finding. Three reactors on a bridged run built with raise_built = false, so
  -- realistic-fusion-refreshed never registers them and no simulation ever runs on them. Every other cell here
  -- has our Lua on it, and a loss seen there could always have been ours.
  storage.idle = build_row(surface, force, 540.5, 3, 0, 0, "idle", true)
  -- The three write shapes (#73), each on its own identical row: three reactors bridged, no tail,
  -- unregistered so control.lua never steps them. Kept OUT of storage.cells deliberately -- several
  -- loops below iterate that table wholesale, and a row driven by this file rather than by the mod
  -- would quietly join measurements it does not belong in.
  storage.shapes = {}
  for i, shape in ipairs(SHAPES) do
    storage.shapes[shape.name] = build_row(surface, force, 600.5 + (i - 1) * 60, 3, 0, 0, shape.name, true)
  end
  -- THE DECISIVE PROBE (#73). Everything above measures the CONSEQUENCE of a write shape. This row
  -- measures the premise directly: does a Lua write to one box on a run change any OTHER box on that
  -- run within the SAME tick? If it does not, no write can overwrite a neighbour's contribution and
  -- the mechanism #40 proposed cannot exist, whatever the arrived fractions say.
  storage.probe = build_row(surface, force, 780.5, 3, 0, 0, "probe", true)
  -- The cross-check that has to be run because it is the one piece of evidence AGAINST that: this
  -- file's own seeding note says a three-reactor run seeded box-by-box in a single pass settles at
  -- 45% of capacity rather than 100%, which only makes sense if writes interact. Seeded exactly
  -- once, and read later. If it comes back full, the note is describing something else.
  storage.onepass_seed = build_row(surface, force, 840.5, 3, 0, 0, "seedonce", true)
  -- The two OUTPUT boxes that are actually on a run (#68). Kept out of storage.cells for the same
  -- reason the shape rows are: every loop over that table is about plasma sharing, and these two
  -- carry tritium and reactor energy.
  storage.outlets = {
    build_collector_outlet(surface, force, 7.5, 900.5),
    build_energy_outlet(surface, force, 60.5, 900.5),
  }
  storage.order = { "mix", "pair", "trio", "five", "solo", "solopipe", "bare", "piped" }
  log("POOL-RIG built")
end)

-- ---------------------------------------------------------------- seeding, then one step
script.on_event(defines.events.on_tick, function()
  local tick, cells = game.tick, storage.cells
  if not cells then return end

  if tick <= SEED_UNTIL then
    for _, cell in pairs(cells) do top_up(cell, SEED_C) end
    if storage.idle then top_up(storage.idle, SEED_C) end
    -- Seeded the same way and for the same sixty ticks as everything else, which is what leaves all
    -- three shape rows in one identical state: nothing simulates them, so they do not diverge
    -- afterwards the way the powered cells do.
    -- Seeded FLAT, like everything else, and made asymmetric by HEATING instead -- see the driver
    -- comments. Seeding them uneven was tried first and is wrong twice over: an uneven row flattens
    -- during the settle window, which is exactly what `mix` demonstrates, and any gradient that did
    -- survive would bleed heat to the engine's lossy mixing inside the measurement window and swamp
    -- the difference being looked for.
    if storage.shapes then
      for _, cell in pairs(storage.shapes) do top_up(cell, SEED_C) end
    end
    if storage.probe then top_up(storage.probe, SEED_C) end
    -- Exactly one pass, on the first seeding tick only, and never touched again. This is the
    -- comparison the seeding note's 45% is a claim about.
    if storage.onepass_seed and tick == 1 then
      top_up(storage.onepass_seed, SEED_C)
      storage.seedonce_written = true
    end
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

  -- One step of the simulation, caught either side.
  --
  -- The rows are NOT in the same state when it is taken, and an earlier version of this comment
  -- claimed they were. Seeding stops at tick 60 and the measurement is at 306, so for four seconds
  -- each row burns at its own rate into a pool of its own size, and they diverge in fill and in
  -- temperature. That is why the check below is a prediction made from each row's OWN state rather
  -- than a comparison of the two gains: the model is asked what THIS row's reactors, at the amounts
  -- and temperatures they actually hold, should put into their pool. The rows' differing states are
  -- reported beside the answer rather than assumed away.
  if tick == STEP_BEFORE then
    storage.before = {}
    for name, cell in pairs(cells) do
      -- Every reactor's own inputs to its own step, because that is what the prediction is made
      -- from. Each reactor works from ITS box's share, and the whole claim under test is what the
      -- engine then does with the answer.
      local inputs = {}
      for i, r in ipairs(cell.reactors) do
        local box = r.fluidbox[1]
        inputs[i] = {
          amount = box and box.amount or 0,
          celsius = box and box.temperature or 0,
          energy = r.energy,
        }
      end
      storage.before[name] = { heat = heat(cell), plasma = pooled(cell), inputs = inputs }
    end
    -- The shape comparison (#73), in the same window and against the same prediction as above.
    --
    -- One step, driven here rather than by control.lua, with each row getting a different write
    -- shape. The prediction is made from each row's own start-of-step boxes exactly as the cells
    -- above are -- but because these rows are unsimulated and identically seeded, their predictions
    -- come out equal, so the measured gains are directly comparable to each other and not only to
    -- their own predictions.
    storage.shape_before = {}
    local dt = INTERVAL / 60
    for _, shape in ipairs(SHAPES) do
      local cell = storage.shapes[shape.name]
      local predicted = 0
      for i, r in ipairs(cell.reactors) do
        local box = r.fluidbox[1]
        if box then
          local result = logic.step(SPEC, PLASMA, box.amount, box.temperature, first_only(i), dt)
          if result then
            predicted = predicted
              + (box.amount - result.plasma_consumed) * (result.temperature_c + 273.15)
              - box.amount * (box.temperature + 273.15)
          end
        end
      end
      storage.shape_before[shape.name] = {
        heat = heat(cell), plasma = pooled(cell), predicted = predicted,
      }
      -- Driven AFTER the prediction is taken, so the prediction describes the state the step was
      -- computed against rather than the state it produced.
      shape.drive(cell, dt, first_only)
      -- Sampled in the SAME tick as the writes, before the engine has had a fluid update to flatten
      -- anything. Read at report time instead -- which is what this did first -- every row is long
      -- since flat and the evidence that the writes differed at all is gone.
      local hot, cold, sp = spread(cell.reactors)
      storage.shape_before[shape.name].after_write = { hot = hot, cold = cold, spread = sp }
    end

    -- THE PROBE. One write, and the whole run read either side of it inside one tick.
    do
      local probe = storage.probe
      local function snapshot()
        local out = {}
        for i, e in ipairs(probe.all) do
          local box = e.fluidbox[1]
          out[i] = { name = e.name, amount = box and box.amount or 0,
                     celsius = box and box.temperature or 0 }
        end
        return out
      end
      local pre = snapshot()
      local target = probe.reactors[1]
      local box = target.fluidbox[1]
      target.fluidbox[1] =
        { name = PLASMA, amount = box.amount, temperature = box.temperature * 4 }
      local post = snapshot()
      -- Which boxes moved, counted separately for the one that was written and for every other.
      local others_moved, target_moved = 0, false
      for i = 1, #pre do
        local moved = rel(pre[i].amount, post[i].amount) > 1e-9
                   or rel(pre[i].celsius, post[i].celsius) > 1e-9
        if probe.all[i] == target then
          target_moved = moved
        elseif moved then
          others_moved = others_moved + 1
        end
      end
      storage.probe_result = {
        target_moved = target_moved, others_moved = others_moved, boxes = #pre - 1,
        pre = pre,
      }
    end
  elseif tick == JOLT_AT - 60 then
    -- The control for the jolt below, and the one the note used to cite without the harness ever
    -- taking it: the same untouched run, an undisturbed second earlier. If these entities bled heat
    -- on their own -- a boiler quietly cooling its input, which was the first suspect -- it would
    -- show here, and the whole loss figure would be that instead of the mixing.
    storage.idle_flat = { heat = heat(storage.idle), plasma = pooled(storage.idle) }
  elseif tick == JOLT_AT then
    -- One box on the untouched run raised fourfold, once. Nothing goes near it after this: no
    -- simulation of ours, no rig, only the engine moving fluid about a run that is now uneven.
    local idle = storage.idle
    -- Read BEFORE the write, which is the whole point of it. The undisturbed control compares
    -- against this, and comparing it against a reading taken after the jolt -- which is what this
    -- did first -- makes a 43% difference out of the jolt itself and calls it a leak.
    local flat = heat(idle)
    local box = idle.reactors[1].fluidbox[1]
    idle.reactors[1].fluidbox[1] =
      { name = PLASMA, amount = box.amount, temperature = box.temperature * 4 }
    storage.jolt = { heat = heat(idle), plasma = pooled(idle), flat = flat }
  elseif tick == JOLT_END then
    local idle = storage.idle
    -- Extremes over EVERY box on the run, not two chosen reactors: a pipe left hotter or colder
    -- than both of them would not show up in the guard the loss figure depends on.
    local hot, cold
    for _, e in ipairs(idle.all) do
      local t = temperature_of(e)
      if t then
        hot  = (hot  == nil or t > hot)  and t or hot
        cold = (cold == nil or t < cold) and t or cold
      end
    end
    storage.jolt_end = { heat = heat(idle), plasma = pooled(idle), hot = hot, cold = cold }
  elseif tick == STEP_AFTER then
    -- THE POSITIVE CONTROL for the intra-tick probe. "No other box moved" is only evidence that the
    -- engine does not re-split between writes if this instrument can see it re-split at all. The
    -- same run, the same snapshot code, a few ticks later: by now the engine has had fluid updates
    -- and the jolt must have spread. If this does not move either, the probe measures nothing and
    -- its null result must be thrown away rather than believed.
    if storage.probe_result then
      local probe, pre = storage.probe, storage.probe_result.pre
      local moved = 0
      for i, e in ipairs(probe.all) do
        local box = e.fluidbox[1]
        local amount = box and box.amount or 0
        local celsius = box and box.temperature or 0
        if e ~= probe.reactors[1]
          and (rel(pre[i].amount, amount) > 1e-9 or rel(pre[i].celsius, celsius) > 1e-9) then
          moved = moved + 1
        end
      end
      storage.probe_result.later_moved = moved
    end
    storage.after = {}
    for name, cell in pairs(cells) do
      storage.after[name] = { heat = heat(cell), plasma = pooled(cell) }
    end
    storage.shape_after = {}
    for name, cell in pairs(storage.shapes) do
      storage.shape_after[name] = { heat = heat(cell), plasma = pooled(cell) }
    end
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

  -- The same question of an OUTPUT box, asked while that box is ON A RUN (#68).
  --
  -- It used to be asked of one reactor's energy box with nothing plumbed to it, which cannot
  -- separate the two answers: an unconnected box IS its own segment. Both call sites in control.lua
  -- that clamp against get_capacity are output boxes a player pipes -- deposit() into a collector,
  -- apply() for a blanket's headroom -- so this is the shape that decides whether those clamps are
  -- written against the right number.
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

    -- And that the run is big enough for the two answers to be told apart, which is the whole
    -- weakness of the unconnected reading this replaces.
    record(segment > own * 4,
      string.format("%s: the run is materially larger than the box", run.label),
      string.format("run %.6g against a box of %.6g -- %.1fx; last pipe %.6g, tank %.6g at (%g, %g)",
        segment, own, segment / own,
        run.pipes[#run.pipes].fluidbox.get_capacity(1),
        run.tank.fluidbox.get_capacity(1), run.tank.position.x, run.tank.position.y))

    -- One segment, not several. This is what the check above cannot see on its own: a tank placed
    -- across the run leaves a big number on one side of the break and a small one on the other, and
    -- reading either alone is how a split run passes for a long one.
    local split
    for i, pipe in ipairs(run.pipes) do
      if rel(pipe.fluidbox.get_capacity(1), segment) > 1e-9 then split = i break end
    end
    record(split == nil and rel(run.tank.fluidbox.get_capacity(1), segment) < 1e-9,
      string.format("%s: every pipe and the tank are on ONE segment", run.label),
      split and string.format("pipe %d reports %.6g against the run's %.6g",
          split, run.pipes[split].fluidbox.get_capacity(1), segment)
        or string.format("%d pipe(s) and the tank all report %.6g", #run.pipes, segment))

    record(rel(report, own) < 1e-9,
      string.format("%s: get_capacity reports the box's own volume, NOT the run it is on", run.label),
      string.format("%.6g against a declared box of %.6g and a run of %.6g", report, own, segment))
  end

  -- ------------------------------------------------------------ one pool, as a quantity
  --
  -- Every box holds the run's contents in proportion to its own volume -- approximately. The
  -- reactors settle a couple of percent fuller than the pipes do, which is a property of the
  -- engine's exchange rather than of anything here; the tolerance says so instead of hiding it.
  for _, name in ipairs(storage.order) do
    local cell = cells[name]
    local total, capacity = pooled(cell), declared_capacity(cell)
    local fill = total / capacity
    local worst, worst_at = 0, nil
    for _, e in ipairs(cell.all) do
      local box = e.fluidbox[1]
      local d = rel(box and box.amount or 0, fill * box_volume(e))
      if d > worst then worst, worst_at = d, e.name end
    end
    record(worst < 0.05,
      string.format("%s: every box holds its share of one pool, not its own contents", name),
      string.format("run %.1f%% full, worst box off its share by %.3g%% (%s)",
        fill * 100, worst * 100, worst_at))
  end

  -- ------------------------------------------------------------ the engine mixes: `mix`
  --
  -- Nothing powered, nothing driving it, seeded fifty times apart. This is the engine on its own,
  -- and it is the cell that answers "converge to a single temperature" without argument.
  local ms, me = storage.mix_start, storage.mix_end
  record(ms ~= nil and me ~= nil, "the passive run was sampled before and after it was left alone")
  if ms and me then
    record(ms.spread > 0.9, "mix: it really did start fifty times apart",
      string.format("%.4g C against %.4g C, spread %.1f%%", ms.hot, ms.cold, ms.spread * 100))
    record(me.spread < 0.005,
      "mix: and with nothing driving it, the run flattens to one temperature",
      string.format("%.6g C against %.6g C after %d ticks, spread %.3g%%",
        me.hot, me.cold, MIX_AT - SEED_UNTIL, me.spread * 100))
  end

  -- ------------------------------------------------------------ sharing under drive, three counts
  for _, name in ipairs({ "pair", "trio", "five" }) do
    local cell = cells[name]

    -- First, that the row is what it claims to be. If a substation reached further than intended,
    -- everything below would still pass and would mean nothing.
    local wired = 0
    for _, r in ipairs(cell.reactors) do
      if r.electric_network_id then wired = wired + 1 end
    end
    record(wired == cell.powered,
      string.format("%s: exactly %d of %d reactors is on an electric network",
        name, cell.powered, #cell.reactors),
      string.format("%d wired", wired))

    -- The unpowered ones, which never spent a joule of their own.
    local cold_t
    if #cell.reactors > 1 then
      local _, cold, s = spread(cell.reactors, 2, #cell.reactors)
      cold_t = cold
      -- Only where there is more than one unpowered reactor to compare. On `pair` there is exactly
      -- one, and a spread over a single reading is zero by construction -- which this recorded as a
      -- passing check reading "spread 0%", and the note then published as though it were evidence.
      if #cell.reactors > 2 then
        record(s < 0.005,
          string.format("%s: every unpowered reactor on the run is at one temperature", name),
          string.format("%.6g C across %d of them, spread %.3g%%", cold, #cell.reactors - 1, s * 100))
      end
      record(cold > SEED_C * 5,
        string.format("%s: and far above the seed, so the pool carried heat to them", name),
        string.format("%.6g C against a seed of %.6g C, a factor of %.1f", cold, SEED_C, cold / SEED_C))
    end

    -- The powered one sits above them, steadily. Bounded rather than asserted to be zero, because
    -- the gap is real: heat enters at that box and leaves it no faster than the pipe carries it
    -- away. The bound is what would fail if sharing stopped -- an island reactor would run orders
    -- above its neighbours within seconds rather than a fraction above them.
    local driven = temperature_of(cell.reactors[1])
    if driven and cold_t then
      record(driven / cold_t < 2,
        string.format("%s: the powered reactor runs a little above the run, not away from it", name),
        string.format("%.6g C against %.6g C, %.1f%% above", driven, cold_t,
          (driven / cold_t - 1) * 100))
    end

    -- Burnt down rather than held, which is the condition this whole rig exists to test under.
    local fill = pooled(cell) / declared_capacity(cell)
    record(fill < 0.999,
      string.format("%s: the pool ran down, so nothing was holding it up", name),
      string.format("%.4g%% of capacity left", fill * 100))
  end

  -- ------------------------------------------------------------ the bookkeeping
  local before, after = storage.before, storage.after
  record(before ~= nil and after ~= nil, "one simulation step was captured",
    before and after and string.format("across ticks %d to %d, one interval holding one step",
      STEP_BEFORE, STEP_AFTER) or "not captured")

  -- ------------------------------------------------------------ what mixing costs
  --
  -- The measurement that explains everything below it, and the one this rig was not built to make.
  -- A run nothing simulates, disturbed once, left alone. Amount cannot change -- no reaction, no
  -- consumer -- so anything that happens to the sum of amount x temperature is the engine's fluid
  -- mixing, and mixing is supposed to be a mass-weighted average, which conserves that sum exactly.
  --
  -- It does not. This is a CHARACTERISATION rather than a requirement: the bounds below say what
  -- 2.0.77 does, and a future version that conserved properly would fail them and should, because
  -- every figure in the note that cites this would then be wrong.
  local jf, j0, j1 = storage.idle_flat, storage.jolt, storage.jolt_end
  record(jf ~= nil and j0 ~= nil and j1 ~= nil,
    "the untouched run was sampled undisturbed, and then before and after its jolt")
  if jf and j0 then
    -- Compared against the pre-jolt reading, which is the same run one second later with nothing
    -- done to it. `heat` here is before the jolt write, so both are the flat run.
    record(rel(jf.heat, j0.flat) < 1e-4,
      "idle: left flat and alone, the run holds its heat, so these entities do not leak it",
      string.format("%.8g against %.8g unit-K over 60 undisturbed ticks, %.3g%% apart",
        jf.heat, j0.flat, rel(jf.heat, j0.flat) * 100))
  end
  if j0 and j1 then
    -- Loose only against float drift and the last of the seeding settling: a thousandth of a
    -- percent. What it is guarding against is fluid arriving or leaving, which would be percent
    -- sized and would make the heat figure below meaningless.
    record(rel(j0.plasma, j1.plasma) < 1e-4,
      "idle: no plasma entered or left the untouched run, so nothing below is fluid moving",
      string.format("%.8g units against %.8g", j0.plasma, j1.plasma))
    record(rel(j1.hot + 273.15, j1.cold + 273.15) < 0.02,
      "idle: and it flattened, so the mixing had finished when the loss was read",
      string.format("%.6g C against %.6g C end to end, %.3g%% apart",
        j1.hot, j1.cold, rel(j1.hot + 273.15, j1.cold + 273.15) * 100))

    local kept = j1.heat / j0.heat
    record(kept > 0.5 and kept < 0.999,
      "idle: BUT MIXING DOES NOT CONSERVE HEAT -- the run is cooler than the average it should reach",
      string.format("%.6g of the heat survived flattening, %.3g%% of it destroyed by the engine",
        kept, (1 - kept) * 100))
  end

  if before and after then
    -- What one step SHOULD add to a pool, asked of the shipped physics.
    --
    -- Each reactor reads its own share, computes against it and writes back a temperature for that
    -- share; the engine then dilutes the rise by the same share when it re-splits the run. The
    -- claim in apply()'s comment is that those two cancel, so the run gains exactly the energy the
    -- reactors put in and it does not matter how much else is plumbed into it.
    --
    -- Written as amount x absolute temperature, which the engine's mixing conserves: it averages
    -- temperature weighted by amount, so this total is unchanged by where the fluid ends up. That
    -- is what makes it comparable against a measurement taken after the mixing has run.
    local dt = INTERVAL / 60
    local results = {}
    for _, name in ipairs({ "solo", "solopipe", "bare", "piped" }) do
      local cell = cells[name]
      local predicted, clamped = 0, false
      for i, input in ipairs(before[name].inputs) do
        local result = logic.step(SPEC, PLASMA, input.amount, input.celsius, input.energy, dt)
        if result then
          -- A reactor short of buffer would spend less than a full step's heating, and the
          -- prediction would still be right -- but it would be right about a different thing than
          -- the one this rig means to check, so it is reported.
          if input.energy < SPEC.heating_power_w * dt then clamped = true end
          predicted = predicted
            + (input.amount - result.plasma_consumed) * (result.temperature_c + 273.15)
            - input.amount * (input.celsius + 273.15)
        end
      end

      local measured = after[name].heat - before[name].heat
      record(not clamped,
        string.format("%s: every reactor had the buffer for a full step, so the prediction is of one", name))

      -- The pool gains a large majority of what the reactors spent and NOT all of it, and the rest
      -- goes to the mixing loss above rather than anywhere in this mod. Bounded on both sides:
      -- above 1.02 would mean energy appearing, and below half would mean something worse than the
      -- loss already characterised. The measured fraction is the number to read.
      local kept = measured / predicted
      record(kept > 0.4 and kept < 1.02,
        string.format("%s: the run gains most of what its reactors spent, and not all of it", name),
        string.format("%.6g predicted against %.6g measured unit-K -- %.1f%% of it arrived; run capacity %.6g",
          predicted, measured, kept * 100, declared_capacity(cell)))
      results[name] = kept
    end

    -- ------------------------------------------------------------ which shape loses it (#73)
    --
    -- The cells above establish that the excess beyond mixing is ours. These rows say which part of
    -- update()'s shape it is, by running the candidates against each other from one identical
    -- state. Every row is three reactors bridged, unregistered, seeded alike and never simulated,
    -- so the ONLY difference between them is how the rig wrote their boxes back.
    record(storage.shape_before ~= nil and storage.shape_after ~= nil,
      "the three write shapes were driven and sampled")

    record(not storage.rebase_clamped,
      "rebased: no write hit the plasma's declared ceiling, so its delta was applied in full")

    local shape_kept = {}
    if storage.shape_before and storage.shape_after then
      -- The predictions must agree, or the rows were not in the same state and nothing below is a
      -- comparison of shapes. Asserted rather than assumed: it is the premise of the whole cell.
      local first_predicted
      for _, shape in ipairs(SHAPES) do
        local p = storage.shape_before[shape.name].predicted
        first_predicted = first_predicted or p
        record(rel(p, first_predicted) < 0.01,
          string.format("%s: started from the same state as the other shapes", shape.name),
          string.format("%.6g predicted against %.6g", p, first_predicted))
      end

      for _, shape in ipairs(SHAPES) do
        local before, after = storage.shape_before[shape.name], storage.shape_after[shape.name]
        local kept = (after.heat - before.heat) / before.predicted
        shape_kept[shape.name] = kept
        record(kept > 0.4 and kept < 1.02,
          string.format("%s: %s", shape.name, shape.label),
          string.format("%.1f%% of what its reactors spent arrived", kept * 100))
      end

      -- THE ISOLATION, AND IT IS A NULL ONE. The three shapes are indistinguishable: whatever
      -- costs the excess, it is not which order this mod reads and writes in. That is what the
      -- `probe` block below establishes the reason for -- a write reaches no other box on the run
      -- until the engine's own fluid update, so there is no window in which one reactor's write
      -- can discard another's.
      --
      -- An earlier version of this comment said the opposite, in this same position: that both
      -- relative-to-fresh-state shapes beat the shipped one and that the stale absolute write was
      -- therefore the defect. That was the hypothesis, written before the row had been run, and it
      -- is exactly what the measurement disproved. Left here as a marker rather than deleted
      -- silently, because a harness whose comments state the finding they were built to test is
      -- how #40's inference became this repo's belief for two days.
      --
      -- Reported rather than asserted, and deliberately so even now the answer is known: an
      -- equality between three floats is the wrong shape for a guard. What guards this finding is
      -- the probe below, which is binary and cheap to reason about. These two lines are here so a
      -- reader sees the numbers rather than taking the probe's word for the consequence.
      record(true, "onepass against the shipped shape",
        string.format("%.2f%% against %.2f%%, a difference of %.2f points",
          shape_kept.onepass * 100, shape_kept.twopass * 100,
          (shape_kept.onepass - shape_kept.twopass) * 100))
      record(true, "rebased against the shipped shape, passes intact",
        string.format("%.2f%% against %.2f%%, a difference of %.2f points",
          shape_kept.rebased * 100, shape_kept.twopass * 100,
          (shape_kept.rebased - shape_kept.twopass) * 100))

      -- The shipped shape's loss on this row, stated against the single-writer figure so the
      -- excess is readable as one number rather than derived from four.
      -- The spread the row actually had when it was stepped, so a reader can see the experiment was
      -- discriminating rather than take it on trust. A flat row reports ~0 here and means nothing.
      -- Evidence the experiment was discriminating, read in the tick the writes happened rather
      -- than at report time: with one reactor of three heating, the row must be uneven immediately
      -- after the writes, or every write carried the same value and the comparison is empty.
      local aw = storage.shape_before.twopass.after_write
      record(aw and aw.spread > 0.001,
        "the shape rows really were uneven the instant the writes landed, so an overwrite had something to destroy",
        aw and string.format("%.4g C against %.4g C end to end, spread %.2f%%",
          aw.hot, aw.cold, aw.spread * 100) or "not sampled")
    end

    -- ------------------------------------------------------------ does a write reach its neighbours?
    --
    -- The premise of the whole excess-loss story, measured directly instead of inferred from arrived
    -- fractions. One box on an untouched run is raised fourfold and the entire run is read again in
    -- the SAME tick.
    local probe = storage.probe_result
    record(probe ~= nil, "the intra-tick write probe ran")
    if probe then
      record(probe.target_moved,
        "probe: the written box really did change, so the write landed",
        "raised fourfold and read back inside one tick")
      -- THE FINDING. If no other box moved, the engine does not re-split a run between Lua writes:
      -- fluid moves in its own once-per-tick update, after every handler has run. A reactor writing
      -- second therefore CANNOT overwrite a share of its neighbour's rise, because that share has not
      -- arrived yet -- and update()'s read-then-write shape cannot be the source of the excess loss.
      record(probe.others_moved == 0,
        "probe: and NO other box on the run moved in that tick -- the engine re-splits between TICKS, not between WRITES",
        string.format("%d of %d other boxes changed", probe.others_moved, probe.boxes))
      -- Without this the line above is worthless: it would read the same if the snapshot were broken.
      record((probe.later_moved or 0) > 0,
        "probe: and the SAME instrument sees the run move once ticks have passed, so the null above is a finding and not a broken probe",
        string.format("%d of %d other boxes had changed %d ticks later",
          probe.later_moved or 0, probe.boxes, STEP_AFTER - STEP_BEFORE))
    end

    -- The cross-check, because this file's seeding note is the one thing that argued otherwise.
    record(storage.seedonce_written == true, "the one-pass seeded run was written exactly once")
    if storage.seedonce_written then
      local cell = storage.onepass_seed
      local fill = pooled(cell) / declared_capacity(cell)
      local many = pooled(cells.mix) / declared_capacity(cells.mix)
      -- THE CROSS-CHECK, and it is a comparison rather than a threshold because the absolute number
      -- is not the point. This file's seeding note explains SEED_UNTIL by saying a run seeded
      -- box-by-box in one pass "settles at 45% of capacity rather than 100%", i.e. that the writes
      -- threw each other away. But `mix` is the same geometry seeded SIXTY times and it sits at the
      -- same 44.6%. So 44.6% is what a three-reactor bridged run holds against the sum of its boxes'
      -- declared volumes, whatever the write pattern -- a fact about the segment, not about writes.
      --
      -- Seeding for sixty ticks is still harmless, and is still worth keeping for the settling it
      -- buys. What is wrong is the reason given for it.
      record(rel(fill, many) < 0.02,
        "seedonce: one seeding pass leaves the run as full as sixty do, so writes do not throw each other away",
        string.format("%.1f%% from one pass against %.1f%% from sixty", fill * 100, many * 100))
    end

    -- The "whatever else is plumbed into the run" half of the claim, and the answer is a qualified
    -- no: the shortfall is real on both runs and it is not the SAME shortfall, because how much
    -- mixing there is to do depends on how much else is on the run. Reported as one line rather
    -- than left for a reader to derive from the two above.
    -- THE CONTROL THAT SEPARATES TWO EXPLANATIONS, and the reason `solo` and `solopipe` exist.
    --
    -- A shortfall on a row of three reactors has two candidate causes and they predict the same
    -- ordering. One is the engine's mixing losing heat. The other is in THIS MOD: update() reads
    -- every reactor and then writes every reactor, and each write REPLACES its box using an amount
    -- and a temperature computed against the start-of-step pool -- so a reactor writing second can
    -- overwrite the share of its neighbour's rise that the engine had already given it.
    --
    -- One reactor cannot overwrite anyone. So `solo` (no pipe, no mixing possible either) and
    -- `solopipe` (the same single writer with a run to mix across) separate them: the step from one
    -- to the other is mixing alone, and anything the three-reactor rows lose beyond that is ours.
    if results.solo and results.solopipe then
      record(results.solo > 0.9,
        "solo: one reactor with no run to share into keeps nearly all of what it spent",
        string.format("%.1f%% arrived, which is the floor everything else is measured against",
          results.solo * 100))
      record(results.solopipe < results.solo - 0.05,
        "solopipe: the SAME single writer loses materially once there is a run to mix across",
        string.format("%.1f%% against %.1f%% -- mixing alone, with no second reactor to blame",
          results.solopipe * 100, results.solo * 100))
      record(results.bare < results.solopipe,
        "and three reactors on a run lose MORE than mixing alone accounts for",
        string.format("%.1f%% on three writers against %.1f%% on one -- the excess is this mod's, not the engine's",
          results.bare * 100, results.solopipe * 100))
    end

    record(results.bare ~= nil and results.piped ~= nil,
      "both bookkeeping runs were measured")
    if results.bare and results.piped then
      record(declared_capacity(cells.piped) > declared_capacity(cells.bare) * 1.2,
        "the two runs differ enough in capacity for the comparison to mean something",
        string.format("%.6g against %.6g units, a factor of %.3g",
          declared_capacity(cells.piped), declared_capacity(cells.bare),
          declared_capacity(cells.piped) / declared_capacity(cells.bare)))
      -- A real assertion rather than a printed remark: the two runs differ by more than the
      -- repeatability of the figure, which is what makes "it depends on the plumbing" a finding.
      record(math.abs(results.bare - results.piped) > 0.02,
        "and what reaches the pool DEPENDS on what else is plumbed into the run",
        string.format("%.1f%% arrived on the bare run against %.1f%% on the piped one",
          results.bare * 100, results.piped * 100))
    end
  end

  local report = storage.report
  report.lines[#report.lines + 1] = string.format("%s: %d checks, %d failures",
    report.failures == 0 and "PASS" or "FAIL", #report.lines, report.failures)
  for _, line in ipairs(report.lines) do log("POOL-RIG " .. line) end
end)
'@
    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') `
        -Value $lua.Replace('__TICKS__', "$Ticks").Replace('__INTERVAL__', "$interval").Replace('__TAIL__', "$Tail")
}

$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabledBundled -Mods ($ourMods + $rigName)
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
    # Deliberately does not blame ADR 0011. Several checks here CHARACTERISE the engine rather than
    # requiring anything of this mod -- a Factorio version that mixed conservatively would fail them,
    # and that would be an improvement rather than a regression. The message says where to look.
    if ($verdict -notmatch '^PASS') {
        throw ("a pooling check failed: $verdict. Read the failing lines before assuming a " +
               "regression here -- the mixing-loss checks describe what 2.0.77 does, and an engine " +
               "that stopped doing it would fail them and would make " +
               "docs/research/reactor-runtime-cost.md wrong rather than this mod.")
    }

    Write-Host ''
    Write-Host 'OK - reactors on one run share a single pool with nothing holding it there, and an idle'
    Write-Host '     run flattens to one temperature. The pool does NOT gain all of what they spent:'
    Write-Host '     the engine destroys heat when it mixes, and how much depends on what else is on'
    Write-Host '     the run. See docs/research/reactor-runtime-cost.md.'
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'check-pooling' }
}

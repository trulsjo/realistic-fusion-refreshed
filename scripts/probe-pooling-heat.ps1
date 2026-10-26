<#
.SYNOPSIS
    Asks why reactors sharing one run of rf-pipe keep only part of the heat a step adds on Factorio
    2.1 (#792): the engine's mixing, the order the mod writes in, or the sum that measures it.
    A probe: it asserts nothing, and exit 0 means it ran and reported.

.DESCRIPTION
    #791 measured the share of one simulation step's heat a run keeps, on 2.1.23 with nothing
    researched: 100.0% for one reactor, with twenty pipes or none, 77.1% for three bridged and
    84.3% for the same three with twenty more pipes. The gain is the sum of amount x absolute
    temperature over every box on the run, across one interval; the prediction is
    reactor-logic's M.step for each reactor the mod steps.

    Three readings fit those four figures, and each cell below is there to tell them apart:

      1. update() reads every reactor, steps each, and then apply() writes each result with
         set_fluid, an absolute state worked out from the box as it was before any reactor wrote.
         On 2.1 a write replaces the box's share of its segment and the segment mixes at once
         (docs/research/plasma-input-box.md, "What a write to the box reaches"), so a later write
         replaces the share of an earlier one's heat its box had just been handed.
      2. The engine loses heat when it mixes, as the input-output box did on 2.0.77.
      3. The sum: each box's get_fluid(1) reads a share, and nothing says the shares of three
         reactors add up to the segment.

    WHAT IS BUILT. Every cell is its own run, sixty tiles from the next, seeded full at 10^6 C for
    sixty ticks. Every reactor is placed with raise_built = false and registered afterwards, when
    it is, with script.raise_script_built, so the order the mod meets them in is the probe's.

      eng1      ONE reactor and a tail of rf-pipe, unregistered and unpowered: the engine alone.
      eng3      Three bridged, unregistered and unpowered.
      eng3x2    The same three.
                On one tick the probe writes the westmost reactor (eng1, eng3), or the westmost
                and the middle one one after the other (eng3x2), at its own amount and fifty times
                the seed's temperature, each write worked out from the run as it was before
                either. The run is then read at once and over the next sixty ticks. Reading 1
                predicts eng1 and eng3 keep all of it and eng3x2 does not; reading 2 predicts the
                run losing heat over the ticks after any write.
      solo      ONE reactor, powered and registered, no pipe: the control, which kept 100.0%.
      w1 w2 w3  Three bridged, all powered, with the westmost one, two and three registered. w3
                is #791's `bare`.
      five      Five bridged, all powered and registered.
      o-ab      Two bridged, the west one powered and the east one not, both registered: the
                west one's step heats and the east one's cools. Registered west first.
      o-ba      The same, registered east first.
      o-ba-built  The same, BUILT east first as well, so the east reactor has the lower
                unit_number. entity-management.lua keys its registry by unit_number and update()
                walks it with pairs, so the three o- cells together say which order the mod
                writes in, and whether the kept share depends on it.

    WHAT IS READ. For the stepped cells, one interval across one step, opening on a step tick, as
    #791's bookkeeping rows read it: each reactor's box before the step, the prediction M.step
    makes from it, and the run's gain as the box sum and as get_fluid_segment_fluid on the
    westmost reactor, which is the segment's own reading. Beside each, what reading 1 predicts:
    the writes replayed in Lua, each replacing its writer's share of the run, the run then shared
    out by volume at one temperature, as the write cell of plasma-input-box.md read it. It is
    replayed twice, in the order the reactors were registered and in ascending unit_number, since
    which of the two the mod writes in is what the o- cells read.

    Nothing researched: every ladder is put back and asserted off, as check-pooling.ps1 does.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Tail
    How many rf-pipe hang off eng1. 20 by default, as check-pooling.ps1's tail.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/probe-pooling-heat.ps1
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [ValidateRange(1, 500)] [int] $Tail = 20,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$rigName  = 'rf-pooling-heat-probe'

# The shipped cadence, read rather than remembered, as check-pooling.ps1 reads it.
$controlLua = Join-Path $repoRoot 'realistic-fusion-refreshed/control.lua'
if ((Get-Content $controlLua -Raw) -match '(?m)^local UPDATE_INTERVAL = (\d+)') {
    $interval = [int]$Matches[1]
} else {
    throw "could not read UPDATE_INTERVAL from $controlLua."
}

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-poolheat-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

@{
    name = $rigName; version = '0.0.1'; title = 'Pooled heat probe'
    author = 'probe-pooling-heat.ps1'; factorio_version = '2.1'
    dependencies = @('base >= 2.1.23', 'realistic-fusion-refreshed', 'realistic-fusion-refreshed-core')
} | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

$lua = @'
-- Generated by scripts/probe-pooling-heat.ps1. Nothing here ships.

local INTERVAL = __INTERVAL__
local TAIL     = __TAIL__
local PLASMA   = "rf-d-d-plasma"
local K0       = 273.15

local logic = require("__realistic-fusion-refreshed__/scripts/reactor-logic")
local SPEC  = logic.reactor

local SEED_C     = 1e6
local HOT_C      = SEED_C * 50
local GAP        = 5
local SEED_UNTIL = 60
local SETTLE     = SEED_UNTIL + 240
-- A step tick, read on: this mod's on_tick runs before realistic-fusion-refreshed's, as
-- check-pooling.ps1 measured on 2.0.77, so a reading here is the state the step is about to see.
-- `solo` is the control for that on 2.1.23: a window holding no step would not keep 100%.
local STEP_BEFORE = math.ceil(SETTLE / INTERVAL) * INTERVAL + INTERVAL
local STEP_AFTER  = STEP_BEFORE + INTERVAL
-- The engine cells are written on the step tick too; nothing steps them.
local WRITE_AT    = STEP_BEFORE
local OFFSETS     = { 1, 2, 5, 10, 30, 60 }
local DONE_AT     = WRITE_AT + 61

local lines = {}
local function say(fmt, ...) lines[#lines + 1] = string.format(fmt, ...) end
local function record(ok, name, detail)
  say("%s  %s%s", ok and "ok  " or "FAIL", name, detail and ("  -- " .. detail) or "")
end

__RIGBUILD__

local function volume(e) return prototypes.entity[e.name].fluidbox_prototypes[1].get_volume() end

--- The run's heat as the sum over every box on it, and as the segment's own reading.
local function box_sum(cell)
  local h, a = 0, 0
  for _, e in ipairs(cell.all) do
    local f = e.get_fluid(1)
    if f then h, a = h + f.amount * (f.temperature + K0), a + f.amount end
  end
  return h, a
end
local function segment(cell)
  local f = cell.reactors[1].get_fluid_segment_fluid(1)
  if not f then return 0, 0, 0 end
  return f.amount * (f.temperature + K0), f.amount, f.temperature
end
local function run_volume(cell)
  local v = 0
  for _, e in ipairs(cell.all) do v = v + volume(e) end
  return v
end

-- ---------------------------------------------------------------- building, as check-pooling.ps1

local function footprint()
  local box  = prototypes.entity["rf-reactor"].selection_box
  local size = math.floor(box.right_bottom.x - box.left_top.x + 0.5)
  return size, (size % 2 == 1) and 0.5 or 0.0
end
local function centre(v, origin)
  if origin == 0.5 then return math.floor(v) + 0.5 else return math.floor(v + 0.5) end
end
local function edge(entity, westward)
  local best
  for _, c in ipairs(entity.get_fluid_box_pipe_connections(1)) do
    local t = c.target_position
    if not best or (westward and t.x < best.x) or (not westward and t.x > best.x) then best = t end
  end
  return best
end
local function power(surface, force, x, y, label)
  local sx, sy = math.floor(x + 0.5), math.floor(y + 0.5) + 10
  local sub = rf_place_or_die(surface, { name = "substation", position = { sx, sy }, force = force }, label .. ": substation")
  local eei = rf_place_or_die(surface, {
    name = "electric-energy-interface", position = { sx + 2.5, sy + 0.5 }, force = force,
  }, label .. ": power source")
  eei.power_production = 8e6
  if eei.electric_network_id ~= sub.electric_network_id then error(label .. ": power source off the network") end
end

--- `count` reactors west to east on one run, `tail` pipes off the east end. `powered` and
--- `registered` are sets of positions, 1 being the westmost; `register` lists the registered
--- ones in the order they are registered; `build` the order the reactors are placed in.
local function build(surface, force, oy, label, count, opts)
  local size, origin = footprint()
  local pitch = size + GAP
  local cy = centre(oy, origin)
  local cell = { label = label, reactors = {}, all = {}, register = opts.register or {} }
  for _, i in ipairs(opts.build or {}) do
    cell.reactors[i] = rf_place_or_die(surface, {
      name = "rf-reactor", position = { centre(origin + (i - 1) * pitch, origin), cy }, force = force,
      raise_built = false,
    }, label .. ": rf-reactor " .. i)
  end
  for i = 1, count do
    if not cell.reactors[i] then
      cell.reactors[i] = rf_place_or_die(surface, {
        name = "rf-reactor", position = { centre(origin + (i - 1) * pitch, origin), cy }, force = force,
        raise_built = false,
      }, label .. ": rf-reactor " .. i)
    end
  end
  for i = 1, count do
    local r = cell.reactors[i]
    if i > 1 then
      local west = edge(r, true)
      for j = 1, pitch - size do
        cell.all[#cell.all + 1] = rf_place_or_die(surface, {
          name = "rf-pipe", position = { west.x - (pitch - size) + j, west.y }, force = force,
        }, label .. ": bridge pipe")
      end
    end
    cell.all[#cell.all + 1] = r
    if opts.powered and opts.powered[i] then power(surface, force, r.position.x, cy, label) end
  end
  if (opts.tail or 0) > 0 then
    local east = edge(cell.reactors[count], false)
    for j = 0, opts.tail - 1 do
      cell.all[#cell.all + 1] = rf_place_or_die(surface, {
        name = "rf-pipe", position = { east.x + j, east.y }, force = force,
      }, label .. ": tail pipe")
    end
  end
  return cell
end

local function set_of(...) local s = {} for _, i in ipairs({ ... }) do s[i] = true end return s end

-- ---------------------------------------------------------------- reading 1, replayed

--- The run's heat after `writes`, each { reactor = index, amount, kelvin }, replaces its writer's
--- share in turn, starting from heat H and amount A, the run being shared out by volume at one
--- temperature before and after each.
local function replay(cell, H, A, writes)
  local V = run_volume(cell)
  for _, w in ipairs(writes) do
    local share = volume(cell.reactors[w.reactor]) / V
    H = H - H * share + w.amount * w.kelvin
    A = A - A * share + w.amount
  end
  return H
end

-- ---------------------------------------------------------------- the map

script.on_init(function()
  local surface, force = game.surfaces[1], game.forces.player
  force.research_all_technologies()
  rf_unresearch(force, logic, logic.reactor)
  rf_assert_research(record, force, logic, logic.reactor, false)

  local size = footprint()
  local span_x = 5 * (size + GAP) + TAIL + 40
  local span_y = 12 * 60 + 40
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

  local all3 = set_of(1, 2, 3)
  storage.cells = {
    eng1   = build(surface, force,   0.5, "eng1",   1, { tail = TAIL }),
    eng3   = build(surface, force,  60.5, "eng3",   3, {}),
    eng3x2 = build(surface, force, 120.5, "eng3x2", 3, {}),
    solo   = build(surface, force, 180.5, "solo",   1, { powered = set_of(1), register = { 1 } }),
    w1     = build(surface, force, 240.5, "w1",     3, { powered = all3, register = { 1 } }),
    w2     = build(surface, force, 300.5, "w2",     3, { powered = all3, register = { 1, 2 } }),
    w3     = build(surface, force, 360.5, "w3",     3, { powered = all3, register = { 1, 2, 3 } }),
    five   = build(surface, force, 420.5, "five",   5, { powered = set_of(1, 2, 3, 4, 5), register = { 1, 2, 3, 4, 5 } }),
    ["o-ab"]       = build(surface, force, 480.5, "o-ab",       2, { powered = set_of(1), register = { 1, 2 } }),
    ["o-ba"]       = build(surface, force, 540.5, "o-ba",       2, { powered = set_of(1), register = { 2, 1 } }),
    ["o-ba-built"] = build(surface, force, 600.5, "o-ba-built", 2, { powered = set_of(1), register = { 2, 1 }, build = { 2, 1 } }),
  }
  storage.order = { "eng1", "eng3", "eng3x2", "solo", "w1", "w2", "w3", "five", "o-ab", "o-ba", "o-ba-built" }
  storage.writes = { eng1 = { 1 }, eng3 = { 1 }, eng3x2 = { 1, 2 } }
  for _, name in ipairs(storage.order) do
    for _, i in ipairs(storage.cells[name].register) do
      script.raise_script_built({ entity = storage.cells[name].reactors[i] })
    end
  end
  log("POOLHEAT built")
end)

-- ---------------------------------------------------------------- seeding, the step and the writes

local function seed(cell)
  for _, e in ipairs(cell.all) do
    e.set_fluid(1, { name = PLASMA, amount = volume(e), temperature = SEED_C })
  end
end

local report  -- below, once everything it reads is defined

script.on_event(defines.events.on_tick, function()
  local tick, cells = game.tick, storage.cells
  if not cells then return end
  if tick <= SEED_UNTIL then
    for _, cell in pairs(cells) do seed(cell) end
    return
  end

  if tick == STEP_BEFORE then
    -- The stepped cells: each reactor's box and buffer as the step is about to see them.
    storage.before = {}
    for name, cell in pairs(cells) do
      local boxes = {}
      for i, r in ipairs(cell.reactors) do
        local f = r.get_fluid(1)
        boxes[i] = { amount = f and f.amount or 0, celsius = f and f.temperature or 0, energy = r.energy,
          wired = r.electric_network_id ~= nil, share = (f and f.amount or 0) }
      end
      local bh, ba = box_sum(cell)
      local sh, sa, st = segment(cell)
      storage.before[name] = { boxes = boxes, box = bh, box_amount = ba, seg = sh, seg_amount = sa, seg_c = st }
    end

    -- The engine cells, written now, each write worked out before either lands.
    storage.eng = {}
    for name, which in pairs(storage.writes) do
      local cell, writes, added = cells[name], {}, 0
      for _, i in ipairs(which) do
        local f = cell.reactors[i].get_fluid(1)
        writes[#writes + 1] = { reactor = i, amount = f.amount, kelvin = HOT_C + K0 }
        added = added + f.amount * (HOT_C - f.temperature)
      end
      local h0 = box_sum(cell)
      local s0, sa0 = segment(cell)
      local model = replay(cell, s0, sa0, writes) - s0
      for _, w in ipairs(writes) do
        cell.reactors[w.reactor].set_fluid(1, { name = PLASMA, amount = w.amount, temperature = HOT_C })
      end
      local h1 = box_sum(cell)
      local s1 = segment(cell)
      storage.eng[name] = { added = added, model = model, h0 = h0, s0 = s0,
        at = { [0] = { box = h1 - h0, seg = s1 - s0 } } }
    end
  end

  if tick == STEP_AFTER then
    storage.after = {}
    for name, cell in pairs(cells) do
      local bh = box_sum(cell)
      local sh = segment(cell)
      storage.after[name] = { box = bh, seg = sh }
    end
  end

  if storage.eng and tick > WRITE_AT then
    for _, d in ipairs(OFFSETS) do
      if tick == WRITE_AT + d then
        for name, e in pairs(storage.eng) do
          e.at[d] = { box = box_sum(cells[name]) - e.h0, seg = segment(cells[name]) - e.s0 }
        end
      end
    end
  end

  if tick == DONE_AT then report() end
end)

-- ---------------------------------------------------------------- the report

report = function()
  local cells, before, after = storage.cells, storage.before, storage.after
  say("interval %d ticks; step read from tick %d to %d; engine cells written on tick %d",
    INTERVAL, STEP_BEFORE, STEP_AFTER, WRITE_AT)

  -- The engine alone.
  for _, name in ipairs({ "eng1", "eng3", "eng3x2" }) do
    local e = storage.eng[name]
    local parts = {}
    for _, d in ipairs({ 0, 1, 2, 5, 10, 30, 60 }) do
      local r = e.at[d]
      parts[#parts + 1] = string.format("+%d box %.4f%% seg %.4f%%", d, r.box / e.added * 100, r.seg / e.added * 100)
    end
    say("engine %-10s added %.6g unit-K; reading 1 predicts %.4f%% kept; %s",
      name, e.added, e.model / e.added * 100, table.concat(parts, ", "))
  end

  -- The shares against the volumes, on the run where the sum is in doubt.
  for _, name in ipairs({ "eng3", "w3", "five" }) do
    local cell, b = cells[name], before[name]
    local V = run_volume(cell)
    local parts = {}
    for i, r in ipairs(cell.reactors) do
      parts[#parts + 1] = string.format("%d: %.6g of %.6g (volume %.4f, share %.4f)", i,
        b.boxes[i].amount, b.seg_amount, volume(r) / V, b.boxes[i].amount / b.seg_amount)
    end
    say("shares %-10s box sum %.8g against the segment's %.8g unit-K; %s",
      name, b.box, b.seg, table.concat(parts, "; "))
  end

  -- One step.
  local dt = INTERVAL / 60
  local full = SPEC.heating_power_w * dt
  for _, name in ipairs({ "solo", "w1", "w2", "w3", "five", "o-ab", "o-ba", "o-ba-built" }) do
    local cell, b, a = cells[name], before[name], after[name]
    local predicted, writes, clamped = 0, {}, false
    for _, i in ipairs(cell.register) do
      local box = b.boxes[i]
      local paid = box.wired and full or 0
      if box.wired and box.energy < SPEC.heating_power_w / 60 then clamped = true end
      local result = logic.step(SPEC, PLASMA, box.amount, box.celsius, paid, dt)
      if result then
        local remaining = box.amount - result.plasma_consumed
        predicted = predicted + remaining * (result.temperature_c + K0) - box.amount * (box.celsius + K0)
        writes[#writes + 1] = { reactor = i, amount = remaining, kelvin = result.temperature_c + K0 }
      end
    end
    local model = replay(cell, b.seg, b.seg_amount, writes) - b.seg
    local by_unit = {}
    for k, w in ipairs(writes) do by_unit[k] = w end
    table.sort(by_unit, function(x, y)
      return cell.reactors[x.reactor].unit_number < cell.reactors[y.reactor].unit_number
    end)
    local model_unit = replay(cell, b.seg, b.seg_amount, by_unit) - b.seg
    local wired = {}
    for i, box in ipairs(b.boxes) do if box.wired then wired[#wired + 1] = i end end
    say("step   %-10s wired %s; %d registered in order %s; %.6g predicted unit-K; box sum %.6g (%.2f%%), segment %.6g (%.2f%%); reading 1 predicts %.2f%% in registration order and %.2f%% in unit_number order; run %.6g units at %.6g C, volume %.6g%s",
      name, table.concat(wired, ","), #cell.register, table.concat(cell.register, ","), predicted,
      a.box - b.box, (a.box - b.box) / predicted * 100, a.seg - b.seg, (a.seg - b.seg) / predicted * 100,
      model / predicted * 100, model_unit / predicted * 100, b.seg_amount, b.seg_c, run_volume(cell),
      clamped and "; A POWERED REACTOR'S BUFFER WAS SHORT" or "")
  end

  -- The order the o- cells were registered and built in, by unit_number.
  for _, name in ipairs({ "o-ab", "o-ba", "o-ba-built" }) do
    local r = cells[name].reactors
    say("units  %-10s west %d, east %d", name, r[1].unit_number, r[2].unit_number)
  end

  for _, line in ipairs(lines) do log("POOLHEAT " .. line) end
  log("POOLHEAT done")
end
'@

$lua = $lua.Replace('__RIGBUILD__', (Get-RigBuildLua)).Replace('__INTERVAL__', "$interval").Replace('__TAIL__', "$Tail")
Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') -Value $lua

$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }
try {
    New-ModJunctions -ModDirectory $modDir -Links (Get-ModLinks -Root $repoRoot -Mods $ourMods)
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled @() -Mods ($ourMods + $rigName)
    Write-Host "interval $interval ticks, tail $Tail pipes, base 2.1 only"

    $save = Join-Path $temp 'poolheat.zip'
    Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create' | Out-Null
    $runOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', '420', '--benchmark-runs', '1', '--disable-audio')

    $reported = @(Get-Content $runOut | Select-String -Pattern 'POOLHEAT ' |
        ForEach-Object { ($_ -split 'POOLHEAT ', 2)[1].TrimEnd() })
    if ($reported -notcontains 'done') { throw "the probe did not reach its report:`n$(Get-Content $runOut -Tail 30 | Out-String)" }
    foreach ($line in $reported) { Write-Host "  $line" }
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'probe-pooling-heat' }
}

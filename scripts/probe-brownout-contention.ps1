<#
.SYNOPSIS
    Measures how a short electric network is split between a reactor and a competing consumer on the
    same network, so the contention half of docs/research/quality.md's brownout sentence is observed
    rather than assumed. The rig #439 asks for.

.DESCRIPTION
    A PROBE, NOT A CHECK. Every line it prints is a measurement, and exit 0 means the probe ran and
    every row reported, never that the answer was the one anybody hoped for. It must not be added to
    a check sweep or to load-check.ps1. Whether the mod should GUARANTEE any of this is a scope
    decision and Truls's; docs/research/quality.md records why a gate would commit the mod to it.

    WHAT IT CLOSES

    scripts/probe-quality-brownout.ps1 puts every reactor alone on its own network, on purpose, and
    its own docstring says that makes it unable to ask how two consumers split a short supply. The
    whole brownout table rests on one assumption -- a shorted reactor asks for its whole
    input_flow_limit rather than for the heating it spends -- and #429 confirmed that for a lone
    reactor. What a player builds is several consumers on one network, and whether the engine
    divides a short supply in proportion to what each ASKS for is what this measures.

    WHAT IS BUILT. Three cells, each ONE electric network with exactly two consumers on it, and each
    alone: the report prints every network id, and the rig errors if a cell's two consumers are not on
    one network or if two cells share one.

      pair       A NORMAL and a LEGENDARY rf-reactor. Both secondary-input, the case a player meets.
                 Different qualities on purpose, for two reasons: they ASK differently (a 90 MW flow
                 limit against 225) while spending the same, which is what makes "a share of what
                 each asks for" distinguishable from "an equal share" at all -- and flow statistics
                 key on name AND quality, so two normal reactors on one network could not be told
                 apart by the instrument this rig reads.
      secondary  A normal rf-reactor against a LOAD the rig declares: an electric-energy-interface
                 carrying a copy of rf-reactor's own electric energy source -- same buffer, same
                 flow limit -- at the same secondary-input priority, consuming the reactor's shipped
                 heating power. Same ask, same spend, same priority: the control.
      primary    The same load at primary-input. The engine's priority classes are the mechanism
                 under test, and this is the cell where the class differs and nothing else does.

    THE LADDER. Each cell's supply is set to a fraction f of what its two consumers SPEND together,
    from 1.2 (both satisfied, with room) down to LOW in steps of STEP. Every rung is twenty seconds,
    the first half for the buffers to settle and the second measured, as in the sibling rig.

    WHAT IS PREDICTED, AND PRINTED BESIDE WHAT IS MEASURED. "A share of what it asks for": the supply
    is divided in proportion to each consumer's input_flow_limit, and a consumer handed more than it
    spends keeps only its spend -- its buffer is full, so it stops asking for more -- with the rest
    going to the other. That is the model the brownout table assumes. It is printed for the primary
    cell too, where it does not apply: that cell's deviation from it IS the finding, and the note
    reads the class rule -- primary-input served first -- off the measured columns.

    THE LESSONS THE SIBLING RIG PAID FOR, KEPT HERE

      * The supply interface delivers out of its own buffer, so the buffer is at once a reserve that
        hides the knee and a ceiling on what it can deliver. It is one tick of the ladder's TOP rung.
      * Flow statistics in 2.0 are keyed by name and quality; asked for the bare name, they answer
        zero for everything but normal.
      * Every reactor is topped back up to one fill and has its energy box emptied every second, so
        neither drops out of the simulation -- a reactor control.lua does not step is not charged,
        and that would read as a brownout and is not one.

    THE RESEARCH STATE IS ASSERTED: nothing held, on every ladder (rf_assert_research, #444). The
    spend is heating_power_w and the heating ladder moves it, so an unstated state is an unreadable
    table.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER RungSeconds
    Game seconds per rung; half settles and half is measured. EVEN, for the reason the sibling rig
    gives: the meter is marked at the half-way tick and the handler fires once a second.

.PARAMETER Low
    The bottom of the ladder, as a fraction of the two consumers' combined spend.

.PARAMETER Step
    The ladder's step, in the same units.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/probe-brownout-contention.ps1
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [ValidateRange(2, 600)] [ValidateScript({ $_ % 2 -eq 0 })] [int] $RungSeconds = 20,
    [ValidateRange(0.0, 0.99)]  [double] $Low  = 0.20,
    [ValidateRange(0.001, 0.5)] [double] $Step = 0.05,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$rigName  = 'rf-brownout-contention-probe'
$high     = 1.2

$rungs = [int][math]::Floor(($high - $Low) / $Step + 1e-9) + 1
Write-Host "ladder: $rungs rungs from f=$high down to f=$Low in steps of $Step, $RungSeconds s each"

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-bc-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

@{
    name = $rigName; version = '0.0.1'; title = 'Brownout contention probe'
    author = 'probe-brownout-contention.ps1'; factorio_version = '2.0'
    dependencies = @('base >= 2.0.77', 'quality', 'realistic-fusion-refreshed')
} | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

# The competing loads. rf-reactor's own electric energy source, copied, at a chosen priority -- so
# against the reactor they differ in the class and in nothing else -- consuming the reactor's shipped
# heating power, read off reactor-logic rather than written down.
Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'data.lua') -Value @'
-- Generated by probe-brownout-contention.ps1. Nothing here ships.
local logic   = require("__realistic-fusion-refreshed__/scripts/reactor-logic")
local reactor = data.raw["boiler"]["rf-reactor"]
for _, priority in ipairs({ "secondary-input", "primary-input" }) do
  local load = table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"])
  load.name = "rf-probe-load-" .. priority
  load.energy_source = table.deepcopy(reactor.energy_source)
  load.energy_source.usage_priority = priority
  load.energy_production = "0W"
  load.energy_usage = string.format("%.10gW", logic.reactor.heating_power_w)
  data:extend({ load })
end
'@

$lua = @'
-- Generated by probe-brownout-contention.ps1. Reports; asserts nothing about the answer.

local RUNG_TICKS = __RUNG_TICKS__
local HIGH       = __HIGH__
local LOW        = __LOW__
local STEP       = __STEP__

local REACTOR = "rf-reactor"
local PLASMA  = "rf-d-d-plasma"
local SPACING = 60

local logic = require("__realistic-fusion-refreshed__/scripts/reactor-logic")

local function say(fmt, ...) log("BCPROBE " .. string.format(fmt, ...)) end
local function per_tick(w) return w / 60 end

__RIGBUILD__

__QUIETMAP__

-- Two consumers per cell: a is always a normal rf-reactor, b is what it competes with.
local SHAPES = {
  { name = "pair",      b = { REACTOR, "legendary" } },
  { name = "secondary", b = { "rf-probe-load-secondary-input", "normal" } },
  { name = "primary",   b = { "rf-probe-load-primary-input", "normal" } },
}

--- What a member has drawn through its network, cumulatively, in joules. Keyed by name AND quality.
local function drawn(cell, m)
  return cell.substation.electric_network_statistics.get_input_count(
    { name = m.entity.name, quality = m.quality }) or 0
end

--- "A share of what it asks for": split S in proportion to each flow limit, cap each at its spend,
--- hand any excess to whoever is not capped. Two members, so one redistribution settles it.
local function by_ask(s, a, b)
  local ga = s * a.limit_w / (a.limit_w + b.limit_w)
  local gb = s - ga
  if ga > a.spend_w then ga, gb = a.spend_w, math.min(b.spend_w, s - a.spend_w)
  elseif gb > b.spend_w then gb, ga = b.spend_w, math.min(a.spend_w, s - b.spend_w) end
  return ga, gb
end

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player

  -- NOTHING RESEARCHED, asserted rather than assumed: the heating ladder moves the spend.
  rf_assert_research(function(ok, name, detail)
    if not ok then error(name .. " -- " .. detail) end
    say("research          %s", name)
  end, force, logic, logic.reactor, false)

  local span = #SHAPES * SPACING
  surface.request_to_generate_chunks({ span / 2, 10 }, math.ceil(span / 32) + 2)
  surface.force_generate_chunk_requests()
  storage.quieted = __QUIETFN__(surface)
  local tiles = {}
  for x = -20, span + 20 do
    for y = -20, 40 do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = { { -20, -20 }, { span + 20, 40 } } })) do
    if e.type ~= "character" then e.destroy() end
  end

  local cells = {}
  for index, shape in ipairs(SHAPES) do
    local ox = (index - 1) * SPACING
    local function member(name, quality, position, what)
      local entity = rf_place_or_die(surface,
        { name = name, position = position, force = force, quality = quality, raise_built = true },
        what .. " in " .. shape.name)
      local m = { entity = entity, quality = quality,
        limit_w = entity.prototype.electric_energy_source_prototype.get_input_flow_limit(quality) * 60 }
      if name == REACTOR then
        m.spend_w = logic.reactor.heating_power_w
        m.fill = entity.fluidbox.get_capacity(1)
      else
        m.spend_w = entity.power_usage * 60
      end
      return m
    end
    -- a north of the substation, b south of it; one substation reaches both and nothing else.
    local a = member(REACTOR, "normal", { ox + 0.5, 0.5 }, "reactor a")
    local b = member(shape.b[1], shape.b[2],
      shape.b[1] == REACTOR and { ox + 0.5, 20.5 } or { ox + 1, 19 }, "consumer b")
    local substation = rf_place_or_die(surface,
      { name = "substation", position = { ox + 9, 10 }, force = force }, "substation in " .. shape.name)
    local supply = rf_place_or_die(surface,
      { name = "electric-energy-interface", position = { ox + 12, 10 }, force = force },
      "supply in " .. shape.name)
    local spend = a.spend_w + b.spend_w
    -- One tick of the TOP rung's production: the sibling rig's lesson, both halves of it.
    supply.electric_buffer_size = per_tick(spend * HIGH)
    supply.energy = 0
    supply.power_production = per_tick(spend * HIGH)
    cells[#cells + 1] = { name = shape.name, a = a, b = b, substation = substation, supply = supply,
      spend_w = spend, rungs = {} }
  end

  -- ONE NETWORK PER CELL, AND ONLY ONE CELL PER NETWORK. Proven off the entities, not the layout.
  local seen = {}
  for _, c in ipairs(cells) do
    local ia, ib = c.a.entity.electric_network_id, c.b.entity.electric_network_id
    if not ia or ia ~= ib then
      error(string.format("%s: its two consumers are on networks %s and %s, so nothing here is "
        .. "contention", c.name, tostring(ia), tostring(ib)))
    end
    if c.supply.electric_network_id ~= ia then
      error(c.name .. ": its supply is not on its consumers' network")
    end
    if seen[ia] then error(c.name .. " shares network " .. ia .. " with " .. seen[ia]) end
    seen[ia] = c.name
    c.network = ia
  end

  storage.cells = cells
  storage.f = HIGH
  log("BCRIG built")
end)

--- Keep every reactor fed and drained so neither drops out of the simulation.
local function tend()
  for _, c in ipairs(storage.cells) do
    for _, m in ipairs({ c.a, c.b }) do
      if not m.entity.valid then error(c.name .. ": a consumer is gone mid-run") end
      if m.fill then
        local plasma = m.entity.fluidbox[1]
        if not plasma or plasma.amount < m.fill then
          m.entity.fluidbox[1] = { name = PLASMA, amount = m.fill,
            temperature = plasma and plasma.temperature or 15 }
        end
        m.entity.fluidbox[2] = nil
      end
    end
    if not (c.substation.valid and c.supply.valid) then error(c.name .. ": its supply is gone") end
  end
end

local function report()
  say("map               quieted: pollution and expansion off, peaceful, %d enemy entities removed",
    storage.quieted)
  say("ladder            f from %.10g down to %.10g in steps of %.10g of the two consumers' spend, "
    .. "%d ticks a rung, the second half measured", HIGH, LOW, STEP, RUNG_TICKS)
  for _, c in ipairs(storage.cells) do
    say("cell   %-10s network=%d  a=%s/%s limit %.6g MW spend %.6g MW  b=%s/%s limit %.6g MW spend %.6g MW",
      c.name, c.network,
      c.a.entity.name, c.a.quality, c.a.limit_w / 1e6, c.a.spend_w / 1e6,
      c.b.entity.name, c.b.quality, c.b.limit_w / 1e6, c.b.spend_w / 1e6)
  end
  for _, c in ipairs(storage.cells) do
    say("%s", c.name)
    say("  %7s %9s | %9s %9s | %9s %9s | %9s %9s", "f", "supply", "a drew", "b drew",
      "a by-ask", "b by-ask", "a dev", "b dev")
    local worst = 0
    for _, r in ipairs(c.rungs) do
      local pa, pb = by_ask(r.supply, c.a, c.b)
      local da, db = r.a - pa / 1e6, r.b - pb / 1e6
      worst = math.max(worst, math.abs(da), math.abs(db))
      say("  %7.4f %9.4g | %9.4g %9.4g | %9.4g %9.4g | %9.3g %9.3g", r.f, r.supply / 1e6,
        r.a, r.b, pa / 1e6, pb / 1e6, da, db)
    end
    say("  worst deviation from a share of what each asks for: %.4g MW", worst)
  end
  say("done")
end

script.on_nth_tick(60, function()
  local tick = game.tick
  if storage.reported then return end
  tend()
  local into = tick % RUNG_TICKS
  if into == RUNG_TICKS / 2 then
    for _, c in ipairs(storage.cells) do c.mark_a, c.mark_b = drawn(c, c.a), drawn(c, c.b) end
    return
  end
  if into == 0 and tick >= RUNG_TICKS then
    local seconds = (RUNG_TICKS / 2) / 60
    for _, c in ipairs(storage.cells) do
      if c.mark_a == nil then error(c.name .. ": the meter was never marked") end
      c.rungs[#c.rungs + 1] = {
        f = storage.f, supply = c.spend_w * storage.f,
        a = (drawn(c, c.a) - c.mark_a) / seconds / 1e6,
        b = (drawn(c, c.b) - c.mark_b) / seconds / 1e6,
      }
    end
    storage.f = storage.f - STEP
    if storage.f < LOW - 1e-9 then
      storage.reported = true
      report()
      return
    end
    for _, c in ipairs(storage.cells) do c.supply.power_production = per_tick(c.spend_w * storage.f) end
  end
end)
'@

$inv = [cultureinfo]::InvariantCulture
$lua = $lua.
    Replace('__RIGBUILD__', (Get-RigBuildLua)).
    Replace('__QUIETMAP__', (Get-QuietMapLua)).
    Replace('__QUIETFN__', $script:QuietMapFunction).
    Replace('__RUNG_TICKS__', "$($RungSeconds * 60)").
    Replace('__HIGH__', [string]::Format($inv, '{0}', $high)).
    Replace('__LOW__', [string]::Format($inv, '{0}', $Low)).
    Replace('__STEP__', [string]::Format($inv, '{0}', $Step))
Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') -Value $lua

$invoke = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    New-ModJunctions -ModDirectory $modDir -Links (Get-ModLinks -Root $repoRoot -Mods $ourMods)
    $enabled = Resolve-BundledSelection -Requested @('quality') -Bundled $bundled
    Write-Host "bundled enabled: $($enabled -join ', ')"
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabled -Mods ($ourMods + $rigName)

    $save = Join-Path $temp 'brownout-contention.zip'
    $createOut = Invoke-FactorioStep @invoke -Arguments @('--create', $save) -Tag 'create'
    $ticks = ($rungs + 2) * $RungSeconds * 60
    $runOut = Invoke-FactorioStep @invoke -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', "$ticks", '--benchmark-runs', '1', '--disable-audio')

    $reported = @(@($createOut, $runOut) | ForEach-Object { Get-Content $_ } |
        Select-String -Pattern 'BCPROBE ' | ForEach-Object { ($_ -split 'BCPROBE ', 2)[1].TrimEnd() })
    if ($reported.Count -eq 0) { throw 'the rig reported nothing; it never reached its report tick.' }
    foreach ($line in $reported) { Write-Host "  $line" }
    if (-not ($reported | Where-Object { $_ -eq 'done' })) {
        throw 'the rig stopped before the end of its report; the rows above are incomplete.'
    }

    Write-Host ''
    Write-Host 'OK - the probe ran and every row reported. The answers are above, and they are'
    Write-Host '     measurements rather than a verdict. docs/research/quality.md is what they are read into.'
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'probe-brownout-contention' }
}

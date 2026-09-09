<#
.SYNOPSIS
    Measures the supply fraction at which full confinement heating stops holding, at every quality
    level, so docs/research/quality.md's brownout table is observed rather than divided. The rig
    #146 asks for.

.DESCRIPTION
    A PROBE, NOT A CHECK. Every line it prints is a measurement, and a negative answer is as much
    of a result as a positive one -- so exit 0 means the probe ran and every row reported, never
    that the answer was the one anybody hoped for. Nothing here decides anything and nothing here
    ships. It must not be added to a check sweep, a bench sweep or to load-check.ps1.

    WHAT IT CLOSES

    docs/research/quality.md says a reactor keeps full heating down to a supply fraction of
    f = 0.833 at normal and f = 0.333 at legendary, by way of five measured input_flow_limit values
    against an unchanged 50 MW spend. Every one of those fractions is arithmetic, and the note says
    so: "The table is arithmetic off the measured flow limits, not an observed brownout."
    scripts/check-brownout.ps1 is the rig that measures the real thing and it runs at normal quality
    only, so a brownout has never been observed on anything but a normal reactor.

    WHY THIS IS A PROBE AND NOT A LANE ON check-brownout.ps1, which is the cheap route the note
    suggests: that script is a GATE. A gate asserting brownout behaviour at legendary commits the
    mod to guaranteeing it, and ADR 0003 tolerates Space Age rather than targeting it. Whether the
    mod should make that promise is a scope decision and therefore Truls's -- so this measures
    without asserting, and the gate question stays open rather than being answered by the shape of a
    test.

    WHAT `f` MEANS HERE, because the note's definition needs one thing said out loud

    The note's model is that "every consumer on the network is secondary-input, so in a brownout at
    supply fraction f a reactor receives f x 60 MW and spends 50". The denominator in that is the
    reactor's own input_flow_limit, not its 50 MW spend -- which is only the right denominator if a
    shorted reactor actually ASKS for its whole flow limit. That is the load-bearing assumption in
    the whole table, and it is what makes quality worth anything here: if a shorted reactor asked
    only for the 50 MW it spends, every level would brown out at the same place and the flow limit
    would buy nothing.

    So each cell is supplied at a set fraction of ITS OWN flow limit, and what the reactor actually
    draws is measured. Full heating holds while the draw stays at heating_power_w. The fraction at
    which it stops is the answer, and the note's table is right exactly if that fraction is
    50 MW / input_flow_limit at every level.

    HOW THE ANSWER IS FOUND: A FIXED DESCENDING LADDER, one hundredth of the flow limit per rung,
    from full supply down to a fifth of it. A ladder rather than a bisection because the whole curve
    is then printed and a reader can see WHERE the draw starts falling short instead of being handed
    a boundary -- and because a bisection assumes the answer is a single clean step, which is one of
    the things under test. THE RESOLUTION IS THEREFORE 0.01 IN f, and every reported fraction is
    bracketed by the last rung that held and the first that did not; both are printed.

    Each rung is twenty seconds: ten for the buffer to reach its new steady state, ten measured. The
    reactor's electric buffer is a few seconds of its spend, so ten is several time constants, and
    the report prints the draw over each rung so a rung that had not settled shows as a step that
    does not match its neighbours.

    WHAT THE DRAW IS READ FROM. The network's own flow statistics, per prototype name -- the same
    instrument check-brownout.ps1 calibrates and uses, for the same reason: it is cumulative and
    per-network, so a difference across a rung is exactly the energy that reactor took in it.

    THE THINGS THAT MAKE THE COMPARISON MEAN ANYTHING

      * EACH CELL HAS ITS OWN ELECTRIC NETWORK, and the report prints the ids rather than resting on
        the geometry. Five cells sharing a supply would let one draw at another's expense and the
        fractions would be measuring contention rather than quality. Same separation
        probe-quality-equilibrium.ps1 uses, and the same reporting of it.

      * EVERY CELL IS TOPPED BACK UP TO ONE FILL EVERY SECOND, temperature preserved, so the five
        burn at one density. What is measured here is the confinement PAYMENT, which
        heating_power_w makes a constant -- but a reactor that runs out of plasma stops being
        stepped and stops being charged at all, which would read as a brownout that is nothing of
        the kind.

      * THE OUTPUT BOX IS DRAINED, for the same reason: a reactor whose energy box has backed up is
        a reactor that has stopped, and a stopped reactor draws nothing at any supply.

      * NO SETTLE PHASE, and that is deliberate rather than an omission. control.lua pays
        heating_power_w per tick for every reactor it stepped, and heating_power_w is a constant --
        #37 recorded as much when it closed: "a supplied reactor draws the same 50 MW whether it is
        barely fusing or sitting at the clamp. Only the SHORTFALL follows anything." So the payment
        under test is the same on a cold plasma as on a settled one, and twenty minutes of settling
        would buy nothing. The plasma temperature is printed anyway, so a reader can see what state
        the reactors were in.

    THE MAP IS QUIETED, and every cell is checked intact at every rung, because the run is long
    enough to be attacked and a cell that has quietly lost its substation goes cold and reports a
    shortfall -- which is precisely the finding this rig exists to locate. See
    scripts/factorio-lib.ps1's Get-QuietMapLua and the note in probe-quality-equilibrium.ps1.

    WHAT IT DOES NOT COVER

    Only rf-reactor, only D-D plasma, only with nothing researched. The aneutronic tier gives the
    same fractions by arithmetic -- 240 MW against a 200 MW spend -- and is another lane.

    AND IT DOES NOT EXERCISE CONTENTION. Every cell here is one reactor alone on its supply, so what
    is measured is what a reactor gets when the supply itself is short, not how two secondary-input
    consumers split a short network between them. The note's sentence asserts both; this closes the
    first. The second wants a rig with a competing load of a known priority and is not what #146
    asks for.

    NOTHING HERE CHANGES input_flow_limit or any other balance number. The note lists the flow limit
    as the one place quality changes reactor behaviour and as "the only entry a balance decision
    might want to keep"; that decision is Truls's.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER RungSeconds
    Game seconds per rung of the supply ladder. Half is given to the buffer and half is measured.
    The default of 20 is several time constants of an rf-reactor's electric buffer against its own
    spend. It must be EVEN: the rig marks its meter at the half-way tick and only looks once a
    second, so an odd length would leave the mark unset and every rung would report the whole run's
    draw as its own.

.PARAMETER Low
    The bottom of the ladder, as a fraction of each reactor's own input_flow_limit. The default of
    0.2 is below every fraction the note's table predicts, the lowest being 0.333 at legendary.

.PARAMETER Step
    The ladder's step, and therefore the resolution of every fraction reported. The default of 0.01
    brackets each answer to a hundredth.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/probe-quality-brownout.ps1

.EXAMPLE
    pwsh -File scripts/probe-quality-brownout.ps1 -Step 0.05 -RungSeconds 40

    A coarser ladder with longer rungs. The two runs agreeing is the evidence that the default rung
    is long enough for the buffer to have settled.
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    # Even, because the rig marks its meter half way through a rung and only fires once a second:
    # an odd length puts the half-way tick between handler firings, the mark never happens, and
    # every rung reports the whole cumulative draw since the run began as if it were one rung's.
    [ValidateRange(2, 600)] [ValidateScript({ $_ % 2 -eq 0 })] [int] $RungSeconds = 20,
    [ValidateRange(0.0, 0.99)]   [double] $Low  = 0.20,
    [ValidateRange(0.001, 0.5)]  [double] $Step = 0.01,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$rigName  = 'rf-quality-brownout-probe'

$rungs = [int][math]::Floor((1.0 - $Low) / $Step) + 1
if ($rungs -lt 3) {
    throw "-Step ($Step) against -Low ($Low) gives $rungs rungs, which is not a ladder."
}
Write-Host "ladder: $rungs rungs from f=1 down to f=$Low in steps of $Step, $RungSeconds s each"

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-qb-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

@{
    name = $rigName; version = '0.0.1'; title = 'Quality brownout probe'
    author = 'probe-quality-brownout.ps1'; factorio_version = '2.0'
    dependencies = @('base >= 2.0.77', 'quality', 'realistic-fusion-refreshed')
} | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'data.lua') `
    -Value '-- nothing; this rig runs, it does not declare'

# ---------------------------------------------------------------------------- the measurement
$lua = @'
-- Generated by probe-quality-brownout.ps1. Reports; asserts nothing.

local RUNG_TICKS = __RUNG_TICKS__
local LOW        = __LOW__
local STEP       = __STEP__

local REACTOR = "rf-reactor"
local PLASMA  = "rf-d-d-plasma"

-- Where reactor-logic.settle() starts, and the reactor spec's min_temperature_c. The plasma's own
-- temperature does not enter the payment -- see the docstring on why there is no settle phase --
-- but starting at the floor keeps this rig's state comparable with the sibling ones.
local COLD_C = 15

-- Forty tiles between cells; a substation reaches eighteen, so no two of these can join a network
-- however the engine feels about it. The report prints the ids anyway.
local SPACING = 40

local function say(fmt, ...) log("QBPROBE " .. string.format(fmt, ...)) end

--- The quality levels a player can hold, in level order.
local function quality_levels()
  local levels = {}
  for name, q in pairs(prototypes.quality) do
    if name ~= "quality-unknown" and not q.hidden then
      levels[#levels + 1] = { name = name, level = q.level }
    end
  end
  table.sort(levels, function(a, b) return a.level < b.level end)
  return levels
end

local function must(entity, what)
  if not entity then error(what .. " refused") end
  return entity
end

--- Joules per tick, from watts. The engine's power fields are per tick and this rig's are watts.
local function watts(w) return w / 60 end

--- What a cell's network has drawn through its reactors, cumulatively, in joules.
--
-- KEYED BY NAME AND QUALITY, not by name. Flow statistics in 2.0 count a legendary rf-reactor under
-- a different key from a normal one, and asking for the bare name answers zero for every cell but
-- the normal one -- which reads exactly like four reactors that never drew a watt. This rig
-- reported that once, with four "(never fell)" rows and one real measurement beside them.
local function drawn(cell)
  return cell.substation.electric_network_statistics.get_input_count(
    { name = REACTOR, quality = cell.quality }) or 0
end

__QUIETMAP__
--- Every entity a cell is measured through, checked before it is measured through.
--
-- The supply path is in here as well as the reading path, and it is the half that matters most: a
-- reactor whose substation is gone stays perfectly valid and simply stops being paid, which is
-- exactly the reading this rig is hunting for. Damage would arrive looking like the finding.
local function assert_intact(cell)
  for _, part in ipairs({
    { "its reactor", cell.reactor }, { "its substation", cell.substation },
    { "its power source", cell.supply },
  }) do
    if not part[2].valid then
      error(string.format("%s: %s is gone -- something destroyed part of the rig mid-run, so this "
        .. "run measures damage rather than quality", cell.quality, part[1]))
    end
  end
end

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player

  local levels = quality_levels()
  if #levels < 2 then
    error(string.format(
      "this probe compares quality levels and found %d. The bundled quality mod is not enabled, so "
      .. "there is nothing here to measure.", #levels))
  end

  local span = #levels * SPACING
  surface.request_to_generate_chunks({ span / 2, 0 }, math.ceil(span / 32) + 2)
  surface.force_generate_chunk_requests()

  -- After the chunks exist, which is the shared guard's one precondition.
  storage.quieted = __QUIETFN__(surface)
  local tiles = {}
  for x = -20, span + 20 do
    for y = -20, 20 do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = { { -20, -20 }, { span + 20, 20 } } })) do
    if e.type ~= "character" then e.destroy() end
  end

  local cells = {}
  for index, q in ipairs(levels) do
    local ox = (index - 1) * SPACING

    local reactor = must(surface.create_entity({
      name = REACTOR, position = { ox + 0.5, 0.5 }, force = force,
      quality = q.name, raise_built = true,
    }), REACTOR .. " at " .. q.name)

    local substation = must(
      surface.create_entity({ name = "substation", position = { ox + 9, 5 }, force = force }),
      "substation at " .. q.name)

    local eei = must(surface.create_entity({
      name = "electric-energy-interface", position = { ox + 11.5, 5.5 }, force = force,
    }), "power source at " .. q.name)
    -- VANILLA'S INTERFACE SHIPS AN ENORMOUS BUFFER -- it is the editor's infinite battery -- so
    -- lowering power_production alone cuts nothing: the interface goes on discharging what it
    -- already holds. scripts/check-brownout.ps1 learned that and cut it to 10 MJ.
    --
    -- TEN MEGAJOULES IS STILL FAR TOO MUCH FOR A LADDER, and this rig learned that in turn. What
    -- matters here is not the reserve against the DRAW but the reserve against the SHORTFALL: one
    -- rung below the knee the normal cell is short by 0.6 MW, and 10 MJ covers that for sixteen
    -- seconds -- most of a rung. Three of the five cells read a rung optimistic that way, the normal
    -- one drawing a full 50 MW at a supply of 49.8. Only three, and the pattern is the giveaway: the
    -- shortfall one rung down is a hundredth of the cell's own flow limit, so the two highest limits
    -- drain 10 MJ inside the rung and the three lowest do not.
    --
    -- AND IT CANNOT SIMPLY BE MADE TINY, which is the other half of the lesson: an interface
    -- delivers out of its buffer, so the buffer is also its per-tick ceiling. Set to a kilojoule it
    -- supplied 60 kW and every cell in the ladder read 0.06 MW at every rung. One tick of the
    -- cell's own full production is therefore the size: enough that the interface can always
    -- deliver what it is set to, and no more, so at a 0.6 MW shortfall it is empty in a second and
    -- a half against a rung whose measured half starts ten seconds in.
    -- input_flow_limit is the denominator every fraction in this rig is taken against, so it is
    -- read off the placed entity at its own quality rather than computed from a multiplier here.
    local limit_w =
      reactor.prototype.electric_energy_source_prototype.get_input_flow_limit(q.name) * 60

    eei.electric_buffer_size = watts(limit_w)
    eei.energy = 0

    cells[#cells + 1] = {
      quality = q.name, level = q.level, reactor = reactor, substation = substation, supply = eei,
      limit_w = limit_w,
      spend_w = reactor.prototype.get_max_energy_usage(q.name) * 60,
      capacity = reactor.fluidbox.get_capacity(1),
      rungs = {},
    }
  end

  -- One fill for all five, the smallest of the five capacities, so density cannot differ between
  -- cells whatever capacity turns out to do. Same instrument as probe-quality-equilibrium.ps1.
  local fill = cells[1].capacity
  for _, c in ipairs(cells) do if c.capacity < fill then fill = c.capacity end end
  for _, c in ipairs(cells) do
    c.reactor.fluidbox[1] = { name = PLASMA, amount = fill, temperature = COLD_C }
    c.supply.power_production = watts(c.limit_w)    -- f = 1 to begin with
  end

  storage.cells = cells
  storage.fill  = fill
  storage.f     = 1.0
  log("QBRIG built")
end)

--- Hold every box at one fill and keep the energy box empty.
--
-- Both halves stop a reactor from dropping out of the simulation, which would read as a brownout
-- and is not one: control.lua charges only the reactors it stepped, and it steps only reactors with
-- plasma to burn.
local function tend()
  for _, c in ipairs(storage.cells) do
    assert_intact(c)
    local plasma = c.reactor.fluidbox[1]
    if plasma and plasma.amount < storage.fill then
      c.reactor.fluidbox[1] =
        { name = plasma.name, amount = storage.fill, temperature = plasma.temperature }
    end
    c.reactor.fluidbox[2] = nil
  end
end

local function report()
  local cells = storage.cells
  say("map               quieted before the run: pollution and expansion off, peaceful, %d enemy "
    .. "entities removed", storage.quieted)
  say("fill              every box held at %.10g units, the smallest capacity of the %d cells",
    storage.fill, #cells)
  say("ladder            f from 1 down to %.10g in steps of %.10g, %d ticks a rung, the second "
    .. "half of each measured", LOW, STEP, RUNG_TICKS)

  local ids, distinct = {}, {}
  for _, c in ipairs(cells) do
    ids[#ids + 1] = string.format("%s=%s", c.quality, tostring(c.reactor.electric_network_id))
    distinct[tostring(c.reactor.electric_network_id)] = true
    -- The positive control that the five entities really are at five different levels: the flow
    -- limit must differ across them, and the spend must not.
    say("cell   %-10s level=%d input_flow_limit=%.10g MW  declared spend=%.10g W  plasma=%.10g C",
      c.quality, c.level, c.limit_w / 1e6, c.spend_w,
      c.reactor.fluidbox[1] and c.reactor.fluidbox[1].temperature or -1)
  end
  local count = 0
  for _ in pairs(distinct) do count = count + 1 end
  say("networks          %d distinct electric networks over %d cells -- %s", count, #cells,
    table.concat(ids, " "))

  -- ------------------------------------------------------------ what a satisfied reactor draws
  --
  -- DERIVED, NOT ASSUMED, and every fraction below is taken against it. control.lua spends
  -- heating_power_w out of the reactor's buffer and a rig cannot see that constant, so the top rung
  -- of the ladder -- full supply, nothing short -- is what defines "full heating" here. If that
  -- figure differed between cells the whole table would be meaningless, so it is printed per cell.
  say("%-10s %13s %13s %13s", "quality", "full draw MW", "as % of limit", "rungs")
  for _, c in ipairs(cells) do
    local full = c.rungs[1]
    c.full_mw = full and full.mw or 0
    say("%-10s %13.6g %13.6g %13d", c.quality, c.full_mw,
      c.limit_w > 0 and (c.full_mw * 1e6 / c.limit_w * 100) or -1, #c.rungs)
  end

  -- ------------------------------------------------------------ the ladder itself
  --
  -- Printed in full rather than summarised, because "it stopped holding here" is the claim and a
  -- reader has to be able to watch the draw come off its ceiling instead of being told where it did.
  local head = { "      f" }
  for _, c in ipairs(cells) do head[#head + 1] = string.format("%12s", c.quality) end
  say("rung   %s   (draw MW)", table.concat(head, " "))
  for i = 1, #cells[1].rungs do
    local row = { string.format("%7.4f", cells[1].rungs[i].f) }
    for _, c in ipairs(cells) do
      row[#row + 1] = string.format("%12.6g", c.rungs[i] and c.rungs[i].mw or -1)
    end
    say("rung   %s", table.concat(row, " "))
  end

  -- ------------------------------------------------------------ and what is left in reserve
  --
  -- THE DRAW ALONE DOES NOT SAY THE HEATING WAS SHORT. A reactor holds about ten megajoules of
  -- stated reserve, so for a while after the supply drops it goes on paying its full spend out of
  -- that while drawing less than it spends. This column is what says the reserve is gone -- an
  -- empty buffer beside a draw below the full figure is a reactor that is being paid short, where
  -- the same draw against a full buffer is one still coasting.
  --
  -- The ladder descends and never returns, so the reserve does not refill once below the knee, and
  -- by the bottom of the table every short cell reads empty.
  say("res    %s   (reactor buffer MJ)", table.concat(head, " "))
  for i = 1, #cells[1].rungs do
    local row = { string.format("%7.4f", cells[1].rungs[i].f) }
    for _, c in ipairs(cells) do
      row[#row + 1] = string.format("%12.6g", c.rungs[i] and (c.rungs[i].buffer / 1e6) or -1)
    end
    say("res    %s", table.concat(row, " "))
  end

  -- ------------------------------------------------------------ and the answer
  --
  -- Bracketed rather than interpolated. The ladder's step is the resolution and saying so beats an
  -- exact-looking number the rig cannot support. HELD is defined against the top rung rather than
  -- against a constant written here: a rung counts as holding if it drew within a thousandth of
  -- what the same cell drew at full supply.
  say("%-10s %13s %13s %13s %13s", "quality", "held down to", "first short", "arithmetic", "note says")
  local ARITHMETIC = { normal = 0.833, uncommon = 0.641, rare = 0.521, epic = 0.439, legendary = 0.333 }
  for _, c in ipairs(cells) do
    local held, short = nil, nil
    for _, rung in ipairs(c.rungs) do
      if rung.mw >= c.full_mw * 0.999 then
        held = rung.f
      elseif short == nil then
        short = rung.f
      end
    end
    -- 50 MW / input_flow_limit: the note's own formula, evaluated on the draw this rig measured at
    -- full supply rather than on a constant retyped here.
    local predicted = c.limit_w > 0 and (c.full_mw * 1e6 / c.limit_w) or -1
    say("%-10s %13s %13s %13.4g %13s", c.quality,
      held and string.format("%.4f", held) or "(never held)",
      short and string.format("%.4f", short) or "(never fell)",
      predicted, tostring(ARITHMETIC[c.quality] or "-"))
  end

  say("done")
end

script.on_nth_tick(60, function()
  local tick = game.tick
  if storage.reported then return end
  tend()

  local cells = storage.cells
  local rung  = math.floor(tick / RUNG_TICKS)
  local into  = tick % RUNG_TICKS

  -- Half way through a rung: mark the meter. The first half is the buffer finding its new steady
  -- state at this supply, and only the second half is measured.
  if into == RUNG_TICKS / 2 then
    for _, c in ipairs(cells) do c.mark = drawn(c) end
    return
  end

  -- The end of a rung: read the meter, record the rung, and step the supply down.
  if into == 0 and rung >= 1 then
    local seconds = (RUNG_TICKS / 2) / 60
    for _, c in ipairs(cells) do
      -- A missing mark is a rig fault, not a zero draw. Without this the rung would report the
      -- whole cumulative draw since the run began, which is a large number that looks like a
      -- reactor drawing far more than its spend rather than like a meter that was never started.
      if c.mark == nil then
        error(string.format("%s: the meter was never marked for the rung ending at tick %d, so "
          .. "this rung would report the run's whole draw as its own", c.quality, tick))
      end
      c.rungs[#c.rungs + 1] = {
        f = storage.f, mw = (drawn(c) - c.mark) / seconds / 1e6,
        buffer = c.reactor.energy,
      }
    end

    storage.f = storage.f - STEP
    if storage.f < LOW - 1e-9 then
      storage.reported = true
      report()
      return
    end
    for _, c in ipairs(cells) do
      c.supply.power_production = watts(c.limit_w * storage.f)
    end
  end
end)
'@

$lua = $lua.
    Replace('__QUIETMAP__', (Get-QuietMapLua)).
    Replace('__QUIETFN__', $script:QuietMapFunction).
    Replace('__RUNG_TICKS__', "$($RungSeconds * 60)").
    Replace('__LOW__', ([string]::Format([cultureinfo]::InvariantCulture, '{0}', $Low))).
    Replace('__STEP__', ([string]::Format([cultureinfo]::InvariantCulture, '{0}', $Step)))
Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') -Value $lua

# Not $step: PowerShell variable names are case-insensitive and -Step is a [double].
$invoke = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    $enabled = Resolve-BundledSelection -Requested @('quality') -Bundled $bundled
    Write-Host "bundled enabled: $($enabled -join ', ')"
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabled -Mods ($ourMods + $rigName)

    $save = Join-Path $temp 'quality-brownout.zip'
    Invoke-FactorioStep @invoke -Arguments @('--create', $save) -Tag 'create' | Out-Null
    # One rung of slack past the ladder, so the report tick is inside the budget.
    $ticks = ($rungs + 2) * $RungSeconds * 60
    $runOut = Invoke-FactorioStep @invoke -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', "$ticks", '--benchmark-runs', '1', '--disable-audio')

    $reported = @(Get-Content $runOut | Select-String -Pattern 'QBPROBE ' |
        ForEach-Object { ($_ -split 'QBPROBE ', 2)[1].TrimEnd() })
    if ($reported.Count -eq 0) { throw 'the rig reported nothing; it never reached its report tick.' }

    foreach ($line in $reported) { Write-Host "  $line" }

    if (-not ($reported | Where-Object { $_ -eq 'done' })) {
        throw 'the rig stopped before the end of its report; the rows above are incomplete.'
    }

    Write-Host ''
    Write-Host 'OK - the probe ran and every row reported. The answers are above, and they are'
    Write-Host '     measurements rather than a verdict, so nothing here passes or fails.'
    Write-Host '     docs/research/quality.md is what they are read into.'
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'probe-quality-brownout' }
}

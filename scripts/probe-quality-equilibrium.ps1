<#
.SYNOPSIS
    Lights one rf-reactor per quality level and settles each to equilibrium, so the central claim of
    docs/research/quality.md is observed rather than deduced. The rig #145 asks for.

.DESCRIPTION
    A PROBE, NOT A CHECK. Every line it prints is a measurement, and a negative answer is as much
    of a result as a positive one -- so exit 0 means the probe ran and every row reported, never
    that the answers were the ones anybody hoped for. Nothing here decides anything and nothing
    here ships. It must not be added to a check sweep, a bench sweep or to load-check.ps1.

    WHAT IT CLOSES

    scripts/probe-quality.ps1 measured every input to a reactor's thermal equilibrium and found all
    of them quality-flat: fluid box capacity, the electric buffer, particles_per_unit and volume_m3
    as Lua constants, and both generator properties scaling by one factor. From that
    docs/research/quality.md concluded that a legendary reactor reaches the same equilibrium as a
    normal one -- and said plainly, at its head and in its "What is not verified" list, that the last
    step was a DEDUCTION. That rig places entities and reads what the engine reports; it never
    lights anything.

    This lights them. Five rf-reactors, one per quality level, cold-started at the plasma's own
    default temperature and driven to equilibrium by their own confinement heating, with temperature
    and Q read off the signal wire.

    THE TWO THINGS THAT MAKE THE COMPARISON MEAN ANYTHING

    Both were solved first by scripts/check-confinement.ps1, for the same reason: it settles four
    reactors that must differ in exactly one variable.

      * EACH CELL HAS ITS OWN ELECTRIC NETWORK. A legendary reactor's input_flow_limit is 2.5x a
        normal one's against an unchanged 50 MW spend, so five cells sharing a supply would let one
        draw at another's expense and the temperatures would be measuring network contention rather
        than quality. Here the separation is by distance -- forty tiles between cells, against a
        substation's eighteen -- and it is REPORTED rather than assumed: every cell prints the
        electric network id its reactor is actually on, and the report says how many distinct ids
        that came to. Five means five networks.

      * THE PLASMA IS TOPPED BACK UP TO A FIXED FILL EVERY SECOND, TEMPERATURE PRESERVED. Left to
        drain, the five cells would burn at five different rates, a thinner plasma runs hotter, and
        the rig would be measuring density and quality at once -- which is precisely the confounder
        the question is about, since "capacity is quality-flat" is the finding under test. The fill
        is the SMALLEST capacity of the five, read off the placed entities rather than remembered,
        and every capacity is printed. If one ever differs, the fill still holds the density equal
        and the printed capacities say what happened.

    READ OFF THE WIRE, NOT OUT OF LUA. Temperature and Q come from a constant combinator ten tiles
    from each reactor, wired to the reactor's own signals combinator -- the same arrangement
    scripts/check-observability.ps1 asserts the existence of. That is what a player sees, so
    measuring it measures the shipped path. The fluid box temperature is printed beside it as a
    second read of the same quantity; the wire carries kilodegrees and the box carries whole
    degrees, and the scale relating them is read off the mod rather than retyped.

    HOW IT KNOWS THE ANSWER IS SETTLED

    It reports the evidence instead of asserting it, three ways.

      * The whole approach curve is printed, one row per sample. A reader watches the five climb and
        flatten rather than taking "settled" on trust.
      * Every cell prints the drift over the last quarter of the run, as a percentage. A cell still
        climbing says so.
      * -Seconds is a parameter, so the same rig can be run twice at different lengths and the
        answers compared -- which is what tests/test-reactor-logic.lua does to justify its own
        SETTLE_S, and what probe-native-heat.ps1 does for its warmup.

    THE DEFAULT IS 1200 SECONDS, and that is tests/test-reactor-logic.lua's SETTLE_S rather than a
    guess. Its comment is the reason: the plasma's confinement time is thirty seconds, but fusion
    self-heating is positive feedback, so the effective time constant is minutes and the model is
    still climbing at six confinement times. A run of a couple of thousand ticks returns a point on
    the way up that reads exactly like an equilibrium.

    THE COLD START IS DELIBERATE. The plasma is seeded at 15 C -- the fluid's own default and the
    reactor spec's min_temperature_c -- which is where reactor-logic.settle() starts. Seeding at
    2.422e8, the answer tests/test-reactor-logic.lua pins, would have been quicker and would have
    measured almost nothing: a rig that starts at the answer can only report that it did not move.
    Starting cold, all five have to find the equilibrium themselves.

    THE MAP IS QUIETED, AND A DAMAGED RIG FAILS LOUDLY (#189)

    It runs twenty minutes by default and forty in the cross-check above, which is long enough to be
    attacked -- so it calls the shared guard, Get-QuietMapLua in scripts/factorio-lib.ps1, before it
    builds: pollution off, enemy expansion off, peaceful mode, and the nests already on the surface
    destroyed. The report says so and prints how many enemy entities went, so the quieting is visible
    rather than assumed.

    Every entity a cell is measured through -- the reading path AND the supply path -- is then checked
    valid every second, at the top-up, and again at every sample. A cell that has lost one errors with
    its quality level named. The supply path is in there because it is the half that fails QUIETLY: a
    reactor whose substation is gone stays perfectly valid and simply goes cold, and at the default
    cadence the once-a-second top-up is what catches it, sixty times more often than the sample does.

    THE PROBABILITY IS LOW AND THE GUARD IS CHEAP, and both halves are worth writing down.
    scripts/check-brownout.ps1, where this was learned, names "eight heaters and an exchanger" as the
    pollution that bought the attention; this rig has five reactors, no heater, no exchanger and no
    meaningful pollution. Enemy expansion does not need pollution, though, so the hazard is reduced
    rather than removed.

    WHAT MAKES IT WORTH DOING ANYWAY IS THE SHAPE OF THE FAILURE. A cell that quietly loses its
    substation stops heating and cools, and reports a temperature below its four neighbours -- and
    this probe's entire finding is that all five agree. Rig damage would arrive looking exactly like
    the discovery that quality changes the equilibrium after all, which is the one wrong answer the
    rig exists to rule out. The guard asserts nothing about the physics: it distinguishes "this run
    did not happen" from a number that reads like a measurement.

    WHAT IT DOES NOT COVER

    Only rf-reactor, only D-D plasma, only at full fill, only with nothing researched. The
    aneutronic tier, the D-T tier and the confinement ladder are each another lane and none of them
    is what #145 asks about.

    The brownout table and the residual boiler leak, which are the other two things
    docs/research/quality.md derives without observing. Both want a rig of this shape and neither
    wants it at full supply on a hot plasma, so they are #146 and #147.

    ONE CONFIGURATION, not two. probe-quality.ps1 runs with the bundled quality mod alone and again
    with space-age, and reported every number identical across the pair -- so the second
    configuration is already answered for the inputs this probe consumes, and a switch here would
    double the runtime to re-answer it.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Seconds
    Game seconds to run before the final reading. The default of 1200 is
    tests/test-reactor-logic.lua's SETTLE_S, for the reason quoted there.

    THE DEFAULT IS ENOUGH, AND THAT IS MEASURED RATHER THAN ASSUMED, the same way
    probe-native-heat.ps1's warmup is. Every cell reads 242258 kC at 1200 s against 242382 kC at
    2400 s, a 0.051% difference, and at 2400 s the last twelve samples are the same number to the
    digit -- flat from tick 104400 to tick 144000, which is eleven game minutes.

    A SHORT RUN WOULD NOT HAVE DONE. `-Seconds 60 -SampleSeconds 15` reads 195129 kC, which is the
    plasma still climbing and would have been quoted as an equilibrium. The second switch is not
    decoration: 60 seconds at the default cadence is one sample and the guard below refuses it.

    Vary it to check the answer has stopped moving; the report prints the drift over the last
    quarter of whatever length was asked for, so a short run says so about itself.

.PARAMETER SampleSeconds
    Game seconds between samples of the approach curve. Must divide the run, at least four times
    over, or there is no curve to read.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/probe-quality-equilibrium.ps1

.EXAMPLE
    pwsh -File scripts/probe-quality-equilibrium.ps1 -Seconds 2400

    Twice the length. The two runs agreeing is the evidence that 1200 s is enough.
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [ValidateRange(1, 100000)] [int] $Seconds = 1200,
    [ValidateRange(1, 100000)] [int] $SampleSeconds = 60,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

if ($Seconds % $SampleSeconds -ne 0) {
    throw "-SampleSeconds ($SampleSeconds) must divide -Seconds ($Seconds), or the last sample is not the final reading."
}
# Four samples is what the drift figure needs: it compares the final reading against the one a
# quarter of the run back, and with fewer than four that comparison reaches the first sample of a
# curve still climbing steeply, which reads as a huge drift whatever the run length.
if ($Seconds / $SampleSeconds -lt 4) {
    throw "-Seconds ($Seconds) must be at least four times -SampleSeconds ($SampleSeconds), or there is no approach curve to report."
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$rigName  = 'rf-quality-equilibrium-probe'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-qeq-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

function Write-Rig {
    @{
        name = $rigName; version = '0.0.1'; title = 'Quality equilibrium probe'
        author = 'probe-quality-equilibrium.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'quality', 'realistic-fusion-refreshed')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'data.lua') -Value '-- nothing; this rig runs, it does not declare'

    $lua = @'
-- Generated by probe-quality-equilibrium.ps1. Nothing here ships. Reports; asserts nothing.

local RUN_TICKS    = __RUN_TICKS__
local SAMPLE_TICKS = __SAMPLE_TICKS__

local PLASMA = "rf-d-d-plasma"
-- The fluid's own default_temperature and the reactor spec's min_temperature_c, which is where
-- reactor-logic.settle() starts. A cold start: every cell has to find the equilibrium itself.
local COLD_C = 15

-- Forty tiles between cells. A substation reaches eighteen, so no two of these can join an electric
-- network however the engine feels about it -- and the report prints the network ids anyway rather
-- than resting on that arithmetic.
local SPACING = 40

local RED = defines.wire_connector_id.circuit_red
local TEMPERATURE = { type = "virtual", name = "rf-signal-plasma-temperature", quality = "normal" }
local Q_FACTOR    = { type = "virtual", name = "rf-signal-q-factor", quality = "normal" }

-- READ OFF THE MOD, not retyped. A wire carries kilodegrees and a fluidbox reports whole ones, so a
-- rig holding its own copy of the scale would print two columns that disagreed by a thousand and
-- look like a defect in the mod. scripts/circuit-output.lua owns the number and explains it.
local circuit = require("__realistic-fusion-refreshed__/scripts/circuit-output")
local SCALE = circuit.TEMPERATURE_SCALE

local function say(fmt, ...) log("QEQ-PROBE " .. string.format(fmt, ...)) end

--- The quality levels a player can hold, in level order.
--
-- Discovered rather than listed, for the same reason check-confinement.ps1 discovers the confinement
-- ladder: a level added or renamed should change what this measures instead of being ignored.
-- quality-unknown is excluded -- it is the engine's placeholder for a quality a save names and the
-- mod set does not define, hidden, and no player can hold one.
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

__QUIETMAP__
--- Every entity a cell is measured through, checked before it is measured through.
--
-- A PROBE THAT LOSES PART OF ITS RIG MUST SAY SO RATHER THAN REPORT. A cell whose substation is
-- eaten stops heating, cools, and prints a temperature well below its four neighbours -- and this
-- probe's whole finding is that all five agree, so damage would arrive looking exactly like the
-- discovery that quality changes the equilibrium after all. That is the one wrong answer this rig
-- exists to rule out. Erroring with the level named asserts nothing about the physics; it is the
-- difference between "this run did not happen" and a number that reads like a measurement.
--
-- The supply path is in here as well as the reading path, because it is the supply path that fails
-- QUIETLY: a reactor with no substation stays perfectly valid and simply goes cold.
local function assert_intact(cell)
  local parts = {
    { "its reactor",            cell.reactor },
    { "its probe combinator",   cell.probe },
    { "its substation",         cell.substation },
    { "its power source",       cell.power },
    { "its signals combinator", cell.signals },
  }
  for _, part in ipairs(parts) do
    local what, entity = part[1], part[2]
    if entity and not entity.valid then
      error(string.format("%s: %s is gone -- something destroyed part of the rig mid-run, so this "
        .. "run measures damage rather than quality", cell.quality, what))
    end
  end
end

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player

  local levels = quality_levels()
  if #levels < 2 then
    error(string.format(
      "this probe compares quality levels and found %d. The bundled quality mod is not enabled, so " ..
      "there is nothing here to measure.", #levels))
  end

  local span = #levels * SPACING
  surface.request_to_generate_chunks({ span / 2, 0 }, math.ceil(span / 32) + 2)
  surface.force_generate_chunk_requests()

  -- AFTER the chunks exist, which is the shared guard's one precondition: it clears what it can see,
  -- and it can only see chunks that have been generated. The count goes into the report so a reader
  -- can tell the quieting happened rather than take it on trust.
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
      name = "rf-reactor", position = { ox + 0.5, 0.5 }, force = force,
      quality = q.name, raise_built = true,
    }), "rf-reactor at " .. q.name)

    -- One substation and one power source per cell. 4e6 joules per TICK is 240 MW, and joules per
    -- tick rather than watts because scripts/check-brownout.ps1 measured that and says so.
    --
    -- 240 MW RATHER THAN THE 120 MW THIS STARTED AT, and the difference is the whole reason to
    -- write the number down. What a reactor SPENDS is heating_power_w, 50 MW, flat at every level.
    -- What it may DRAW is input_flow_limit, which is 60 MW at normal and 150 MW at legendary -- so
    -- 120 MW covered every cell's spend and sat below one cell's draw ceiling. That is not a
    -- shortage today, because nothing here ever asks for more than 50 MW; it is a supply figure
    -- that stops being obviously sufficient the moment heating_power_w moves, and this rig exists
    -- precisely to keep supply out of the answer. Above every flow limit, it cannot come into it.
    --
    -- The report prints each reactor's buffer contents at the reading, which is what says a cell
    -- was actually powered rather than merely wired to something.
    local substation = must(
      surface.create_entity({ name = "substation", position = { ox + 9, 5 }, force = force }),
      "substation at " .. q.name)
    local eei = must(surface.create_entity({
      name = "electric-energy-interface", position = { ox + 11.5, 5.5 }, force = force,
    }), "power source at " .. q.name)
    eei.power_production = 4e6

    -- The far end of the wire: an ordinary constant combinator a player could have placed, ten tiles
    -- clear of the reactor's own edge. Same arrangement as scripts/check-observability.ps1.
    local probe = must(surface.create_entity({
      name = "constant-combinator", position = { ox + 10.5, 0.5 }, force = force,
    }), "probe combinator at " .. q.name)

    cells[#cells + 1] = {
      quality = q.name, level = q.level, reactor = reactor, probe = probe,
      -- Kept rather than discarded, so assert_intact() can see the supply path. Nothing reads them
      -- for a measurement: they are here because losing either would take a cell cold, and until
      -- the guard existed it would have done that without saying anything.
      substation = substation, power = eei,
      capacity = reactor.fluidbox.get_capacity(1),
      samples = {},
    }
  end

  -- THE FILL, and why it is the minimum rather than each cell's own capacity. Density is
  -- amount x particles_per_unit / volume_m3 and volume_m3 is a Lua constant, so equal amounts are
  -- equal densities. Filling each box to its own capacity would hold the BOXES equal and the
  -- densities unequal the moment capacity stopped being flat -- which is the very finding under
  -- test. One number for all five keeps density fixed whatever capacity turns out to do, and every
  -- capacity is printed so a reader can see what it did.
  local fill = cells[1].capacity
  for _, c in ipairs(cells) do if c.capacity < fill then fill = c.capacity end end
  for _, c in ipairs(cells) do
    c.reactor.fluidbox[1] = { name = PLASMA, amount = fill, temperature = COLD_C }
  end

  storage.cells = cells
  storage.fill  = fill
  log("QEQ-RIG built")
end)

--- Wire each reactor's signals combinator to its probe.
--
-- Not at on_init: the combinator does not exist until control.lua first reports, which is a handful
-- of ticks in. And reading is a separate tick again -- LuaCircuitNetwork reports the signals of the
-- PREVIOUS tick, so a wire connected and read in one handler carries nothing, which is
-- indistinguishable from a mod that never published.
local function wire_everything()
  local surface = game.surfaces[1]
  for _, c in ipairs(storage.cells) do
    local found = surface.find_entities_filtered({
      name = "rf-reactor-signals", position = c.reactor.position,
    })
    if #found ~= 1 then
      error(string.format("%s: expected one signals combinator at the reactor and found %d",
        c.quality, #found))
    end
    c.signals = found[1]
    local from = must(found[1].get_wire_connector(RED, true), c.quality .. ": combinator red connector")
    local to   = must(c.probe.get_wire_connector(RED, true), c.quality .. ": probe red connector")
    if not from.connect_to(to) then
      error(c.quality .. ": the wire does not reach the probe ten tiles away")
    end
  end
  storage.wired = true
end

--- Hold every box at the same fill, temperature preserved.
--
-- Without this the five cells burn at five different rates, a thinner plasma runs hotter, and the
-- probe would measure density and quality at once. Same instrument as check-confinement.ps1.
local function top_up()
  for _, c in ipairs(storage.cells) do
    assert_intact(c)
    local plasma = c.reactor.fluidbox[1]
    if plasma and plasma.amount < storage.fill then
      c.reactor.fluidbox[1] = { name = plasma.name, amount = storage.fill, temperature = plasma.temperature }
    end
  end
end

--- One reading of every cell, off the wire.
local function sample(tick)
  for _, c in ipairs(storage.cells) do
    assert_intact(c)
    local network = c.probe.get_circuit_network(RED)
    local plasma  = c.reactor.fluidbox[1]
    c.samples[#c.samples + 1] = {
      tick    = tick,
      wire_kc = network and network.get_signal(TEMPERATURE) or nil,
      wire_q  = network and network.get_signal(Q_FACTOR) or nil,
      box_c   = plasma and plasma.temperature or nil,
      amount  = plasma and plasma.amount or nil,
      -- The positive control that a cell is POWERED, not merely wired. Five unlit reactors would
      -- also print a spread of zero, and only the absolute temperature would separate that from the
      -- real answer -- so the buffer contents are printed beside it. A cell keeping up carries a
      -- buffer; a cell whose substation missed its reactor carries nothing.
      energy  = c.reactor.energy,
      network_id = c.reactor.electric_network_id,
    }
  end
end

local function last(c) return c.samples[#c.samples] end

local function report()
  local cells = storage.cells
  say("scale             a wire temperature is in kilodegrees; SCALE=%d C per kC, read off circuit-output.lua", SCALE)
  say("fill              every box held at %.10g units, the smallest capacity of the %d cells",
    storage.fill, #cells)
  say("run               %d ticks, sampled every %d", RUN_TICKS, SAMPLE_TICKS)
  say("map               quieted before the run: pollution and expansion off, peaceful, %d enemy "
    .. "entities removed", storage.quieted)

  -- ------------------------------------------------------------ the cells, and their separation
  local ids, distinct = {}, {}
  for _, c in ipairs(cells) do
    local s = last(c)
    ids[#ids + 1] = string.format("%s=%s", c.quality, tostring(s.network_id))
    distinct[tostring(s.network_id)] = true
    -- input_flow_limit and energy_usage are the positive control: both scale with quality, so five
    -- identical rows here would say the five entities are not actually at five different levels and
    -- every equal temperature below means nothing. Per second, from the per-tick getters.
    say("cell   %-10s level=%d capacity=%.10g input_flow_limit=%.10g W energy_usage=%.10g W buffer=%.10g J",
      c.quality, c.level, c.capacity,
      c.reactor.prototype.electric_energy_source_prototype.get_input_flow_limit(c.quality) * 60,
      c.reactor.prototype.get_max_energy_usage(c.quality) * 60,
      c.reactor.electric_buffer_size)
  end
  local count = 0
  for _ in pairs(distinct) do count = count + 1 end
  -- The criterion the ticket asks be shown rather than trusted. The ids themselves are printed so a
  -- reader can see the count is over five different numbers and not one repeated.
  say("networks          %d distinct electric networks over %d cells -- %s", count, #cells,
    table.concat(ids, " "))

  -- ------------------------------------------------------------ the approach curve
  --
  -- Printed in full rather than summarised, because "it settled" is the claim under test and a
  -- reader has to be able to watch it flatten instead of being told it did.
  local head = { "   tick" }
  for _, c in ipairs(cells) do head[#head + 1] = string.format("%12s", c.quality) end
  say("curve  %s   (wire kC)", table.concat(head, " "))
  for i = 1, #cells[1].samples do
    local row = { string.format("%7d", cells[1].samples[i].tick) }
    for _, c in ipairs(cells) do
      row[#row + 1] = string.format("%12s", tostring(c.samples[i].wire_kc))
    end
    say("curve  %s", table.concat(row, " "))
  end

  -- ------------------------------------------------------------ has it stopped moving?
  --
  -- Reported, not asserted. The comparison is the final reading against the one a quarter of the run
  -- earlier; a cell still climbing prints a drift that says so, and the answer to that is -Seconds
  -- rather than a smaller number here.
  local n = #cells[1].samples
  local back = math.max(1, math.floor(n * 3 / 4))
  for _, c in ipairs(cells) do
    local final, earlier = c.samples[n], c.samples[back]
    -- Both ends checked, not just the earlier one. A nil at either end means the probe's network was
    -- gone at that sample, and dividing into it would throw HALF WAY THROUGH the report -- after the
    -- curve had already printed, so the PowerShell side would say the rig stopped early and name
    -- nothing. -1 says "no answer" and lets the rest of the report reach the reader.
    local drift = (earlier.wire_kc and final.wire_kc and earlier.wire_kc ~= 0)
      and math.abs(final.wire_kc - earlier.wire_kc) / earlier.wire_kc or -1
    say("settle %-10s tick %d: %s kC   tick %d: %s kC   drift %.4f%%",
      c.quality, earlier.tick, tostring(earlier.wire_kc), final.tick, tostring(final.wire_kc),
      drift * 100)
  end

  -- ------------------------------------------------------------ the readings themselves
  for _, c in ipairs(cells) do
    local s = last(c)
    say("final  %-10s wire=%s kC  wire_q=%s %%  box=%.10g C (%.10g kC)  amount=%.10g units  buffer=%.10g J",
      c.quality, tostring(s.wire_kc), tostring(s.wire_q), s.box_c or -1,
      (s.box_c or 0) / SCALE, s.amount or -1, s.energy or -1)
  end

  -- ------------------------------------------------------------ and the answer
  --
  -- A spread, not a verdict. Zero says the five reached one equilibrium; anything else is the
  -- finding and belongs in docs/research/quality.md exactly as printed.
  local function spread(get)
    local lo, hi = nil, nil
    for _, c in ipairs(cells) do
      local v = get(last(c))
      if v then
        if lo == nil or v < lo then lo = v end
        if hi == nil or v > hi then hi = v end
      end
    end
    return lo, hi
  end
  local tlo, thi = spread(function(s) return s.wire_kc end)
  local qlo, qhi = spread(function(s) return s.wire_q end)
  local alo, ahi = spread(function(s) return s.amount end)
  say("spread temperature  min=%s kC  max=%s kC  range=%s kC (%.6f%% of min)",
    tostring(tlo), tostring(thi), tostring((thi or 0) - (tlo or 0)),
    (tlo and tlo ~= 0) and ((thi - tlo) / tlo * 100) or -1)
  say("spread q            min=%s %%  max=%s %%  range=%s", tostring(qlo), tostring(qhi),
    tostring((qhi or 0) - (qlo or 0)))
  say("spread amount       min=%.10g  max=%.10g  units at the moment of reading", alo or -1, ahi or -1)

  say("done")
end

script.on_nth_tick(60, function()
  local tick = game.tick
  if storage.reported then return end

  local just_wired = false
  if not storage.wired then
    if tick < 120 then return end
    wire_everything()
    just_wired = true
  end

  -- SAMPLED BEFORE THE TOP-UP, and the order is the whole worth of the amount column. Read after
  -- it, `amount` is storage.fill for every cell by construction -- a row that prints five equal
  -- numbers whatever the reactors did, which is a tautology dressed as evidence for the one thing
  -- it is meant to show. Read before it, the figure is what the cell had left after a second of
  -- burning, so a cell burning faster than its neighbours says so.
  --
  -- AND NEVER ON THE WIRING TICK. LuaCircuitNetwork reports the PREVIOUS tick's signals, so a read
  -- on the tick the wire was connected carries nothing -- a 0 at the head of the curve that looks
  -- exactly like a reactor holding no plasma. The wiring tick is 120, so this only bites at
  -- -SampleSeconds 1 and 2; at 1 the tick-60 sample is lost to the guard above as well, so a
  -- one-second cadence starts its curve two points in. Cosmetic -- the run's answer does not move,
  -- because sample() only reads -- but worth knowing before reading a curve that starts late.
  if not just_wired and tick % SAMPLE_TICKS == 0 then sample(tick) end

  top_up()

  if tick >= RUN_TICKS then
    storage.reported = true
    report()
  end
end)
'@

    $lua = $lua.
        Replace('__QUIETMAP__', (Get-QuietMapLua)).
        Replace('__QUIETFN__', $script:QuietMapFunction).
        Replace('__RUN_TICKS__', "$($Seconds * 60)").
        Replace('__SAMPLE_TICKS__', "$($SampleSeconds * 60)")
    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') -Value $lua
}

$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    $enabled = Resolve-BundledSelection -Requested @('quality') -Bundled $bundled
    Write-Host "bundled enabled: $($enabled -join ', ')"
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabled -Mods ($ourMods + $rigName)
    Write-Rig

    $save = Join-Path $temp 'quality-equilibrium.zip'
    Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create' | Out-Null
    # The wiring pass costs two seconds before the first sample, and the report fires on the first
    # multiple of 60 at or past the run length, so the budget carries a little over both.
    $ticks = $Seconds * 60 + 240
    $runOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', "$ticks", '--benchmark-runs', '1', '--disable-audio')

    $reported = @(Get-Content $runOut | Select-String -Pattern 'QEQ-PROBE ' |
        ForEach-Object { ($_ -split 'QEQ-PROBE ', 2)[1].TrimEnd() })
    if ($reported.Count -eq 0) { throw 'the rig reported nothing; it never reached its report tick.' }

    foreach ($line in $reported) { Write-Host "  $line" }

    # The sentinel, for the same reason probe-quality.ps1 checks for one: a rig that died part way
    # through its report prints rows that look exactly like a complete run.
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
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'probe-quality-equilibrium' }
}

#Requires -Version 7
<#
.SYNOPSIS
    Checks that a reactor actually reports itself -- status line, both signals, on a real wire.
    Discharges the half of #25 that unit tests cannot reach.

.DESCRIPTION
    tests/test-circuit-output.lua covers everything above publish(): what the two signal values
    should be, which of the three states a result means, that every status key is in the locale
    file. It is pure arithmetic and it runs outside Factorio, which is the whole reason
    circuit-output.lua is split where it is.

    Below publish() none of that is true, and none of it was checked. A reactor is a boiler, and
    BoilerPrototype carries no circuit connector at all, so the signals go out through a companion
    constant combinator created at the reactor's own position. Every part of that arrangement can
    fail without anything erroring: the combinator can go missing, its section can be empty, the
    values can be stale, the wire can be out of reach, or -- the one that actually happened -- the
    whole thing can work while being impossible to attach a wire to, because the reactor wins the
    cursor over the entity that carries the connector (ADR 0012).

    So this builds five reactors, wires each one's combinator to a second combinator ten tiles away,
    and reads the values back off the far end of that wire. Reading at the far end is the point: it
    is the difference between "the mod set some filters" and "a player can act on this".

    WHAT EACH REACTOR IS FOR

      running   Plasma pinned hot by an infinity pipe, and powered. Should fuse.
      idle      Plasma pinned at the temperature a heater injects at, and deliberately on no
                electric network, so it cannot climb. Holding plasma, not fusing.
      starved   No plasma line at all.

    Three states, one save -- which is also what makes the aggregate check possible: running and
    idle report different figures, so if either one's wire carried a value for "the reactors"
    rather than for itself, they could not both be right.

    THAT USED TO READ "three orders of magnitude apart", AND #57 BROKE THE ARITHMETIC BEHIND IT.
    Idle's plasma sits at the 15 C floor, which a kilodegree wire reports as 0, so the ratio the
    check rested on quietly became "running is greater than zero". The check was strengthened where
    it is made rather than being left to mean less than it says; see the comment there.

      ignited-full   D-T plasma, a full box, powered.
      ignited-thin   D-T plasma, 35% of a box, powered.

    THOSE TWO ARE NOT A FOURTH AND FIFTH STATE (#55). They are both "running", and they exist to be
    compared with EACH OTHER. Their real equilibria differ -- a thinner plasma settles hotter -- and
    ~~both are far above the simulation's 2e9 ceiling, so both are clamped to it and both report the
    same number.~~ **NOT SINCE #58**, and this is the rig that recorded it changing. The ceiling
    moved to 5e9, above where D-T settles, so the pair now report their own equilibria and differ --
    the `note` line at the end of a run says YES where it said no. That was #54's whole complaint.

    The two `note` lines measure rather than assert, which is why neither had to be edited to record
    the fix: a rig that had asserted the broken answer would have needed deleting as the first step
    of fixing it.

    They are seeded and topped up directly rather than fed by an infinity pipe, and that is not a
    shortcut: a feed replaces burnt plasma AT THE FEED TEMPERATURE, which on a reactor burning 34
    units a second is a large cooling flow. Fed that way the thin one sat at 6.28e8 for the whole
    run -- pinned by its feed rather than by the ceiling -- and the pair then differed for the one
    reason this measurement has to exclude.

    WHAT IT CANNOT CHECK

    That a wire drag lands on the combinator rather than on the reactor. That is a property of
    Factorio's mouse selection, it needs a LuaPlayer, and a headless run has none -- so it was
    measured in a client instead (ADR 0012 records both the wrong first answer and the measurement).
    Everything downstream of the wire existing is checked here.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/check-observability.ps1
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
$rigName  = 'rf-observability-rig'

# The rig verifies once, at SettleTicks, and the run has to outlast that. Kept here rather than in
# two languages: the settle tick is substituted into the rig's Lua below, so there is one number
# instead of a pair that can drift apart. Lowering the budget under the settle tick used to produce
# "the rig reported nothing", which points at the rig rather than at the budget.
$script:SettleTicks    = 2400
$script:BenchmarkTicks = 2600
if ($script:BenchmarkTicks -le $script:SettleTicks) {
    throw ("this script is misconfigured: the benchmark budget ($script:BenchmarkTicks ticks) must " +
           "exceed the tick the rig verifies at ($script:SettleTicks), or it never reports.")
}

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-obs-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

function Write-Rig {
    @{
        name = $rigName; version = '0.0.1'; title = 'Reactor observability check'
        author = 'check-observability.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

    # The shipped plasma set carries its own pipe connection category (#26), so a vanilla
    # infinity-pipe can no longer feed a reactor. The rig declares one that can.
    $feed = Write-PlasmaFeed -RigDirectory $rigDir

    $lua = @'
-- Generated by scripts/check-observability.ps1. Nothing here ships.

local COMBINATOR = "rf-reactor-signals"
local TEMPERATURE = { type = "virtual", name = "rf-signal-plasma-temperature", quality = "normal" }
local Q_FACTOR    = { type = "virtual", name = "rf-signal-q-factor", quality = "normal" }
local RED = defines.wire_connector_id.circuit_red

-- READ OFF THE MOD, not retyped (#57). A wire carries thousands of degrees while a fluidbox reports
-- whole ones, so every comparison below has to know the scale -- and a rig holding its own copy of
-- it would pass happily while the mod shipped something else, which is the one failure a rig must
-- not have. This mod is a dependency, so the number comes from the file that owns it, which is also
-- where the scale is explained: scripts/circuit-output.lua at TEMPERATURE_SCALE.
local circuit = require("__realistic-fusion-refreshed__/scripts/circuit-output")
local SCALE = circuit.TEMPERATURE_SCALE

-- Five reactors, twenty-five tiles apart so a fifteen-tile building and its wiring never touch the
-- next one. powered = false is how the idle case is held idle: with no network the reactor cannot
-- heat, so plasma injected at a heater's temperature stays there.
--
-- `status` is the status line the case should show and `distinct` marks the three whose lines have
-- to differ from each other. Both exist because #55 added two cases that are deliberately NOT a
-- fourth and fifth state: the ignited pair are both "running", and they are here to be compared
-- with each other rather than with anything else.
--
-- THE IGNITED PAIR (#55, for #54). Two D-T reactors, both powered, SEEDED RATHER THAN FED -- see
-- the note where they are built -- and differing only in how full they are held. Their real
-- equilibria differ, and since #58 raised the ceiling to 5e9 they report those equilibria rather
-- than a shared clamp. ~~Both are far above the ceiling, so both are clamped and report the same
-- number.~~ That was the defect #54 is
-- about, and this rig's job here is to MEASURE whether it is still true rather than to assert it
-- either way -- see the two notes at the end of verify().
local CASES = {
  { name = "running", plasma = 6e8, powered = true,  distinct = true },
  { name = "idle",    plasma = 1e6, powered = false, distinct = true },
  { name = "starved", plasma = nil, powered = true,  distinct = true },
  { name = "ignited-full", powered = true, status = "running",
    fuel = "rf-d-t-plasma", seed = 6e8, units = 1000 },
  { name = "ignited-thin", powered = true, status = "running",
    fuel = "rf-d-t-plasma", seed = 6e8, units = 350 },
}

local lines = {}
local failures = 0
-- Counted separately from `lines`, because note() writes into `lines` too and a note is not a
-- check. Reporting #lines as the check count inflated the verdict by one per note.
local checks = 0

local function record(ok, name, detail)
  checks = checks + 1
  if not ok then failures = failures + 1 end
  lines[#lines + 1] = string.format("%s  %s%s", ok and "ok  " or "FAIL", name,
    detail and ("  -- " .. detail) or "")
end

--- A measurement the rig reports and does not judge (#55).
--
-- Deliberately not a check. What the ignited pair does today is a defect #54 is open about, so
-- asserting the current behaviour would mean writing down "both reactors report the same number" as
-- a thing that must stay true -- and then deleting it as the first step of fixing it. Asserting the
-- FIXED behaviour would fail the rig today for a reason nobody is going to act on this ticket.
--
-- So it is neither. It prints, it never fails, and it is the line whoever lands #56 to #58 reads to
-- know they have finished. A note that never changes is a note nobody needed; this one changes.
local function note(name, detail)
  lines[#lines + 1] = string.format("note  %s%s", name, detail and ("  -- " .. detail) or "")
end

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player

  -- Five cases at 25 tiles apart since #55, not three: the far reactor sits at x=100 and its probe
  -- at 110, so the generated area and the landfill below both had to grow with them. A probe on
  -- ungenerated ground is a wire that reaches nothing, which reads exactly like a mod that never
  -- published.
  surface.request_to_generate_chunks({ 70, 0 }, 7)
  surface.force_generate_chunk_requests()
  local tiles = {}
  for x = -20, 170 do
    for y = -20, 20 do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = { { -20, -20 }, { 170, 20 } } })) do
    if e.type ~= "character" then e.destroy() end
  end

  storage.cases = {}
  for index, case in ipairs(CASES) do
    local ox = (index - 1) * 25
    local reactor = surface.create_entity({
      name = "rf-reactor", position = { ox + 0.5, 0.5 }, force = force, raise_built = true,
    })
    if not reactor then error("rf-reactor refused for " .. case.name) end

    if case.powered then
      local sub = surface.create_entity({ name = "substation", position = { ox + 9, 5 }, force = force })
      if not sub then error("substation refused for " .. case.name) end
      local eei = surface.create_entity({
        name = "electric-energy-interface", position = { ox + 11.5, 5.5 }, force = force,
      })
      if not eei then error("power source refused for " .. case.name) end
      eei.power_production = 2e6
    end

    if case.plasma then
      -- Placed where the reactor says its plasma connection points, not where arithmetic on the
      -- footprint says it should. The arithmetic is a remembered constant by another name, and it
      -- is what left the reactor benchmark quietly feeding empty ground after the 15x15 resize
      -- (#49).
      local connections = reactor.fluidbox.get_pipe_connections(1)
      if #connections == 0 then error("rf-reactor's plasma box has no connections") end
      local feed = surface.create_entity({
        name = "__PLASMAFEED__", position = connections[1].target_position, force = force,
      })
      if not feed then error("infinity-pipe refused for " .. case.name) end
      -- Always D-D and always full: the only cases that reach here are the original three, and the
      -- ignited pair are seeded rather than fed (see below). This briefly took the fuel and the
      -- fill off the case, which was dead the moment the pair stopped using a feed.
      feed.set_infinity_pipe_filter({
        name = "rf-d-d-plasma", percentage = 1, temperature = case.plasma, mode = "at-least",
      })
      -- A feed that lines up with nothing looks exactly like a reactor that is meant to be starved.
      local joined = false
      for _, connection in pairs(reactor.fluidbox.get_pipe_connections(1)) do
        if connection.target then joined = true end
      end
      if not joined then error("the plasma feed for " .. case.name .. " reaches nothing") end
    end

    -- THE IGNITED PAIR ARE NOT FED (#55). An infinity pipe holds a box at a fill by replacing what
    -- the reactor burns, and it replaces it AT THE FEED'S TEMPERATURE -- which on a reactor burning
    -- 34 units a second is a large cooling flow, not a top-up. Fed that way the thin one never left
    -- 6.28e8: it was pinned by its feed rather than by the ceiling, and the pair then differed for
    -- the one reason this measurement must exclude. So they get plasma written straight into the
    -- box and topped back up below, temperature preserved, which is the same instrument
    -- scripts/check-confinement.ps1 uses and for the same reason.
    if case.seed then
      reactor.fluidbox[1] = { name = case.fuel, amount = case.units, temperature = case.seed }
    end

    -- The far end of the wire: an ordinary constant combinator a player could have placed, ten
    -- tiles clear of the reactor's own edge.
    local probe = surface.create_entity({
      name = "constant-combinator", position = { ox + 10.5, 0.5 }, force = force,
    })
    if not probe then error("probe combinator refused for " .. case.name) end

    storage.cases[#storage.cases + 1] = { case = case, reactor = reactor, probe = probe, ox = ox }
  end

  log("OBS-RIG built")
end)

-- control.lua reports every REPORT_EVERY simulation steps, so the first wire values exist within a
-- couple of dozen ticks. Everything below runs once, well after that.
-- Wiring and reading are two passes a full tick apart, and that is not caution.
-- LuaCircuitNetwork reports the signals of the *previous* tick, so a wire connected and read in the
-- same handler carries nothing -- which is indistinguishable from a mod that never published.
local function wire_everything()
  local surface = game.surfaces[1]
  for _, entry in ipairs(storage.cases) do
    local name = entry.case.name
    local found = surface.find_entities_filtered({
      name = COMBINATOR, position = entry.reactor.position,
    })
    record(#found == 1, name .. ": exactly one signals combinator at the reactor",
      string.format("%d", #found))
    local combinator = found[1]
    if combinator then
      record(storage.seen_combinators[tostring(combinator.unit_number)] == nil,
        name .. ": the combinator is this reactor's own, not one shared between reactors")
      storage.seen_combinators[tostring(combinator.unit_number)] = true

      -- A wire a player could have dragged: reach checked rather than forced.
      local from = combinator.get_wire_connector(RED, true)
      local to   = entry.probe.get_wire_connector(RED, true)
      record(from ~= nil and to ~= nil, name .. ": both ends offer a red circuit connector")
      if from and to then
        record(from.connect_to(to), name .. ": the wire reaches the probe ten tiles away")
      end

      -- What the reactor publishes, asked of the combinator rather than of the network. The two
      -- are not the same question: Factorio leaves a zero-valued signal off the network entirely,
      -- so a starved reactor -- whose temperature and Q are both legitimately 0 -- puts nothing on
      -- the wire at all. Whether it *published* both is still answerable, and is the thing that
      -- would break if a signal were dropped.
      local behavior = combinator.get_control_behavior()
      local section = behavior and behavior.sections_count > 0 and behavior.get_section(1)
      local declared = {}
      for _, filter in pairs(section and section.filters or {}) do
        if filter.value then declared[filter.value.name] = true end
      end
      record(declared[TEMPERATURE.name] and declared[Q_FACTOR.name] or false,
        name .. ": the reactor publishes both signals, whatever their values")
    end
  end
end

local function verify()
  local seen_labels = {}
  local wire_kc_by_case = {}
  for _, entry in ipairs(storage.cases) do
    local name = entry.case.name
    local reactor = entry.reactor

    -- The status line, read back off the entity rather than recomputed.
    -- The expected line is the case's `status`, which is its own name for the original three and
    -- "running" for the ignited pair -- they are two reactors in one state, not two more states.
    local expected = entry.case.status or name
    local status = reactor.custom_status
    local label = status and status.label and status.label[1]
    record(label == "rf-reactor-status." .. expected,
      name .. ": the status line says " .. expected, tostring(label))
    -- Uniqueness binds only the three that are meant to be distinct. Asking it of all five would
    -- demand the ignited pair differ from each other, which is the opposite of what they are for.
    if label and entry.case.distinct then
      record(seen_labels[label] == nil, name .. ": the three states are three different lines", label)
      seen_labels[label] = true
    end

    -- And the values, read at the FAR end of the wire connected a pass ago.
    local network = entry.probe.get_circuit_network(RED)
    record(network ~= nil, name .. ": the probe is on a circuit network")
    if network then
      -- SUFFIXED BY UNIT (#57), because two of them live here and they are a thousand
      -- apart: the wire carries kilodegrees and a fluidbox reports whole degrees.
      -- Unsuffixed, the only thing saying which was which was the format string below.
      local wire_kc = network.get_signal(TEMPERATURE)
      local q = network.get_signal(Q_FACTOR)
      wire_kc_by_case[name] = wire_kc

      local plasma = reactor.fluidbox[1]
      local plasma_c = plasma and plasma.temperature or 0

      if name == "starved" then
        -- STILL TRUE, AND NO LONGER DISCRIMINATING (#57) -- the same erosion the idle drift check
        -- below records, and it reaches this one too. Idle reads 0 now, so "starved reports 0" no
        -- longer separates a reactor with no plasma from one holding cold plasma; only the status
        -- line does. Kept because the assertion is still true of a starved reactor and would still
        -- catch it reporting something, and because what it stopped covering is covered by the
        -- running and ignited cases, which are hot enough for the wire to resolve.
        record(wire_kc == 0, "starved: reports no temperature", tostring(wire_kc))
      else
        -- Within a few percent, not to the degree. The wire carries what the reactor published at
        -- its last report -- control.lua reports every fifth simulation step, not every tick -- so a
        -- reactor whose plasma is still moving reads slightly stale. Demanding equality here would be
        -- demanding that the reporting cadence be one tick, which is the thing it deliberately is
        -- not.
        --
        -- THE IDLE CASE'S WIDE BOUND WENT WHEN THE READ TICK MOVED (#55). What is below records
        -- why it existed; it is kept because the reasoning is still true of a reactor read while
        -- its plasma is falling, and this rig simply no longer reads one. At 2400 ticks the idle
        -- plasma has been at the floor for most of the run -- 15 C on the wire against 15 C in the
        -- box -- so it is as steady as the running one and is held to the same 5%.
        --
        -- IT HAD TO GO RATHER THAN MERELY BEING UNNECESSARY. Against an actual of 15 C, a wire
        -- reporting nothing at all gives a drift of 1.0, which sat comfortably inside the old bound
        -- of 4.0 -- so the check would have passed a signal that had stopped being published, which
        -- is precisely the failure it exists to catch.
        --
        -- THE ORIGINAL REASON, SINCE #52, and the reason is the point rather than the
        -- number. This block used to say "the idle one is slowly cooling" and hold both cases to 5%.
        -- It is not slowly cooling any more: with the radiation term carried, a plasma below fusion
        -- temperature radiates away far more than it holds -- around 350 kW against 200 kJ of
        -- thermal content at 5e4 C -- so it falls to the floor in well under a second and can more
        -- than halve between one report and the next. That is the term working, not the signal
        -- breaking: the running reactor is still held to 5%, and the same assertion catches a wire
        -- that has stopped tracking its own reactor in every case where the plasma is not in free
        -- fall.
        --
        -- COMPARED ON THE WIRE'S OWN TERMS SINCE #57. The signal is in kilodegrees and the fluidbox
        -- reports whole degrees, so the two are no longer the same quantity and subtracting them
        -- directly would fail every case by a factor of a thousand.
        --
        -- The slack is 5% OR half a scale-step, whichever is larger, and the second half is not
        -- padding: half a step is precisely what the encoding cannot resolve, so demanding better
        -- would be demanding the wire carry a number it has no room for.
        --
        -- WHAT THAT COSTS, STATED RATHER THAN HIDDEN: the idle case stops discriminating. Its plasma
        -- sits at the 15 C floor, which is 0.015 of a kilodegree, so a wire reporting 0 and a wire
        -- reporting nothing at all are the same reading and this check passes either. It is kept for
        -- the cases that ARE resolvable -- a dead wire on the running reactor is 368862 kilodegrees
        -- adrift and still caught -- and idle is covered instead by its status line, which is
        -- asserted separately, and by the aggregate check below. The alternative was to widen the
        -- bound until 0-against-15 passed as a drift, which is the bound #55 removed for exactly
        -- this reason: a check that passes an unpublished signal is worse than no check.
        local expected_kc = plasma_c / SCALE
        local slack_kc = math.max(0.05 * expected_kc, 0.5)
        record(math.abs(wire_kc - expected_kc) <= slack_kc,
          name .. ": the temperature on the wire is this reactor's own plasma, to within the report cadence",
          string.format("wire %d kC, plasma %.6g C (%.6g kC), slack %.6g kC",
            wire_kc, plasma_c, expected_kc, slack_kc))
      end

      if name == "running" then
        record(q > 0, "running: a Q factor reaches the wire", tostring(q))
      end
    end
  end

  -- The aggregate check. If one number described both reactors, these two would be equal.
  --
  -- IT NEEDED STRENGTHENING AT #57, because idle now reads 0 rather than 15 -- the floor is under
  -- what a kilodegree wire resolves. "Three orders of magnitude apart" silently became "running is
  -- greater than zero", which a single stuck signal could satisfy. So the ratio is kept AND running
  -- is required to be a genuine reading: 1000 kilodegrees is 1e6 C, far under any fusion temperature
  -- and far over anything a floor or an artefact produces.
  local running_kc, idle_kc = wire_kc_by_case["running"], wire_kc_by_case["idle"]
  record(running_kc and idle_kc and running_kc > 1000 and running_kc > idle_kc * 10,
    "each reactor reports itself, not an aggregate of both",
    string.format("running %s kC, idle %s kC", tostring(running_kc), tostring(idle_kc)))

  -- ------------------------------------------------------ can a player tell two reactors apart?
  --
  -- #55's measurement, and the reason it is two lines rather than one: the answer is yes on the
  -- neutronic tier and no on the ignited one, and #54 exists to make it yes on both. Reported per
  -- tier so that the second line changing is unambiguous when #56 to #58 land.
  --
  -- The neutronic pair are in different STATES; the ignited pair are in the same state at different
  -- densities. That difference is deliberate. Two ignited reactors one of which is idle would
  -- differ trivially -- an idle plasma is cold whatever tier it belongs to -- and would say nothing
  -- about the ceiling. Two that are both running and both fusing, at real equilibria that genuinely
  -- differ, are the case the clamp flattens.
  local function differ(a, b)
    if a == nil or b == nil then return "unreadable" end
    return (a ~= b) and "YES" or "no"
  end

  note("neutronic: two reactors in different states report different temperatures?",
    string.format("%s -- running %s, idle %s",
      differ(running_kc, idle_kc), tostring(running_kc), tostring(idle_kc)))

  local full_kc, thin_kc = wire_kc_by_case["ignited-full"], wire_kc_by_case["ignited-thin"]
  note("ignited: two reactors at different densities report different temperatures?",
    string.format("%s -- full %s, thin %s%s",
      differ(full_kc, thin_kc), tostring(full_kc), tostring(thin_kc),
      (full_kc ~= nil and full_kc == thin_kc)
        and string.format(" (both at the %d kC ceiling, so the wire cannot tell them apart -- #54)",
          full_kc) or ""))

  lines[#lines + 1] = string.format("%s: %d checks, %d failures",
    failures == 0 and "PASS" or "FAIL", checks, failures)
  for _, line in ipairs(lines) do log("OBS-RIG " .. line) end
end

-- Tick 0 fires every interval, and at tick 0 nothing has happened yet: the infinity pipes have not
-- filled and no reactor has ever been stepped, so every case would report "starved" and read
-- exactly like a broken mod. Then one pass to wire, and a much later one to read.
--
-- This describes the handler below it, not the top-up handler above: that one runs from the first
-- interval and has nothing to wait for.
-- Held at a fixed amount, temperature untouched, so the only thing separating the ignited pair is
-- how much plasma each holds. A reactor left to drain changes density as it burns, and density is
-- the variable under test.
script.on_nth_tick(60, function()
  for _, entry in ipairs(storage.cases or {}) do
    if entry.case.units then
      local plasma = entry.reactor.fluidbox[1]
      -- A box that has drained COMPLETELY is re-seeded rather than skipped. Reading the name and
      -- temperature off the plasma that is there only works while some is; with nothing there the
      -- old guard gave up for the rest of the run and the case quietly degraded into a fourth
      -- "starved" reactor, failing on its status line rather than saying what happened. Not
      -- reachable at the shipped burn -- measured drawdown between top-ups is 4.3% held full and
      -- 1.5% held thin -- but a hotter tier or a longer interval would reach it.
      if not plasma then
        entry.reactor.fluidbox[1] =
          { name = entry.case.fuel, amount = entry.case.units, temperature = entry.case.seed }
      elseif plasma.amount < entry.case.units then
        entry.reactor.fluidbox[1] =
          { name = plasma.name, amount = entry.case.units, temperature = plasma.temperature }
      end
    end
  end
end)

-- READ AFTER THE PLASMAS HAVE SETTLED, which #55 had to raise from 240 ticks and is a condition
-- rather than a cushion. The ignited pair are compared with each other, so both have to have
-- ARRIVED: a D-T reactor fed at 6e8 reached the then-2e9 ceiling after about 400 ticks held full
-- and about 1200 held at 35%, so a reading at 240 caught both mid-climb and found them different
-- because one was ahead of the other, which is not the question being asked. It also broke the
-- drift check on the full one -- a plasma climbing that fast moves more than 5% between one report
-- and the next, so the wire looked stale when it was merely behind a fast-moving reactor.
--
-- #58 RAISED THE TARGET AND 2400 STILL CLEARS IT. The pair no longer climb to a shared ceiling but
-- to their own equilibria, higher than the old clamp -- 2.89e9 full and 2.02e9 thin -- so arrival
-- takes longer than it did. The tick is not re-derived here because the rig proves it directly: the
-- drift check holds both cases to 5% of their own plasma at the moment of reading, and a reactor
-- still climbing fails it. That check passing at both fills IS the evidence that 2400 is enough,
-- which is a better guarantee than an arrival time quoted in a comment.
--
-- 2400 is twice the slower of the two. The three original cases are read at the same tick and are
-- indifferent to it: two are held at their feed temperature and the third has no plasma at all.
local SETTLE_TICKS = __SETTLETICKS__

script.on_nth_tick(120, function()
  if game.tick == 0 then return end
  if not storage.wired then
    storage.seen_combinators = {}
    storage.wired = true
    wire_everything()
    return
  end
  if storage.done or game.tick < SETTLE_TICKS then return end
  storage.done = true
  verify()
end)
'@
    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') `
        -Value $lua.Replace('__PLASMAFEED__', $feed).Replace('__SETTLETICKS__', "$script:SettleTicks")
}

$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled @() -Mods ($ourMods + $rigName)
    Write-Rig

    $save = Join-Path $temp 'obs.zip'
    Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create' | Out-Null
    $runOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', "$script:BenchmarkTicks", '--benchmark-runs', '1',
        '--disable-audio')

    # 'note' is in the pattern since #55: those lines are measurements the rig reports and does not
    # judge, and a measurement nobody prints is a measurement nobody takes.
    $reported = @(Get-Content $runOut | Select-String -Pattern 'OBS-RIG (ok|note|FAIL|PASS|FAIL:)' |
        ForEach-Object { ($_ -split 'OBS-RIG ', 2)[1].TrimEnd() })
    if ($reported.Count -eq 0) {
        throw ("the rig reported nothing; it never reached its check tick. It verifies at " +
               "$script:SettleTicks ticks and this run was given $script:BenchmarkTicks.")
    }

    foreach ($line in $reported) { Write-Host "  $line" }

    $verdict = $reported | Where-Object { $_ -match '^(PASS|FAIL): ' } | Select-Object -Last 1
    if (-not $verdict)          { throw 'the rig produced no verdict line.' }
    if ($verdict -notmatch '^PASS') { throw "reactor observability is broken: $verdict" }

    Write-Host ''
    Write-Host 'OK - status line, both signals, and a wire a player could have dragged.'
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'check-observability' }
}

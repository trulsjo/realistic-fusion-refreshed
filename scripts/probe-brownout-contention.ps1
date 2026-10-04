<#
.SYNOPSIS
    Measures how a short electric network is split among the consumers on it -- a reactor and what
    it competes with, up to four reactors to a network -- so the contention half of docs/research/quality.md's brownout sentence is observed
    rather than assumed. The rig #439 asks for, extended by #487 past pairs and to a tertiary load,
    by #490 to that load on a tertiary supply, by #491 to all three input classes at once, by
    #492 to an accumulator discharging into a short network, by #493 to the aneutronic reactor, by
    #494 to a researched heating rung, by #528 to a vanilla accumulator as load and as supply, by
    #534 to a prediction that carries each member's buffer, and by #538 to a discharge that caps
    one of two reactors and to accumulators feeding accumulators.

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

    WHAT IS BUILT. Ten ladder cells and seven discharge cells, each ONE electric network, and each alone: the report prints every
    network id, and the rig errors if a cell's consumers are not all on one network or if two cells
    share one. Every consumer in a cell has a name+quality key of its own, for the reason below,
    and since #536 the rig errors, naming the cell and the key, if two share one.

      pair       A NORMAL and a LEGENDARY rf-reactor. Both secondary-input, the case a player meets.
                 Different qualities on purpose, for two reasons: they ASK differently (a 90 MW flow
                 limit against 225) while spending the same, which is what makes "a share of what
                 each asks for" distinguishable from "an equal share" at all -- and flow statistics
                 key on name AND quality, so two normal reactors on one network could not be told
                 apart by the instrument this rig reads.
      secondary  A normal rf-reactor against a LOAD the rig declares: an electric-energy-interface
                 carrying a copy of rf-reactor's own electric energy source -- same buffer, same
                 flow limit -- at the same secondary-input priority, consuming what rf-reactor
                 spends at the run's heating rung. Same ask, same spend, same priority: the control.
      primary    The same load at primary-input. The engine's priority classes are the mechanism
                 under test, and this is the cell where the class differs and nothing else does.
      four       FOUR rf-reactors, normal, uncommon, rare and legendary (#487): asks of 90, 117, 144
                 and 225 MW, the same spend. A pair caps at most one member; this caps three, one
                 after another down the ladder, so the redistribution is exercised more than once.
      tertiary   A normal rf-reactor against the load at TERTIARY (#487). Its SUPPLY differs too, and
                 has to: vanilla's interface is itself tertiary, and the 2.0.77 docs for
                 ElectricUsagePriority describe tertiary input as collecting "the overproduction",
                 which a tertiary supply is not. So this cell's supply is a rig copy of it at
                 secondary-output, the class those docs give steam generators.
      tert-tert  The tertiary cell again on the rig's USUAL supply, vanilla's tertiary interface
                 (#490): the case those docs do not settle. The two cells differ in the supply's
                 class and in nothing else, and are predicted the same.
      three      ALL THREE INPUT CLASSES ON ONE NETWORK (#491): the load at primary-input, a normal
                 rf-reactor and the load at tertiary, on the tertiary cell's secondary-output
                 supply. Every other cell holds at most two classes.
      aneutronic A normal rf-reactor and a normal rf-aneutronic-reactor (#493), each holding its own
                 plasma at its own box's fill. Every other REACTOR here spends the same 50 MW
                 unresearched; these ask 90 and 240 MW and spend 50 and 200, so the water-fill's caps fall where
                 two different spends put them.
      acc-tert   A normal rf-reactor and eighteen vanilla accumulators AS A LOAD (#528), on the
                 rig's usual tertiary supply: tert-tert with a real accumulator where the rig's
                 copy of an interface was. The accumulators are emptied every second, so they go
                 on asking for their whole input_flow_limit and never fill; that limit is their
                 spend. The engine reports their class as managed-accumulator, which the
                 prediction serves last, after tertiary.
      acc-sec    The same members on the secondary-output supply: the tertiary cell likewise.

    AND SEVEN CELLS THAT ARE NOT ON THE LADDER, because a draining accumulator is not a steady state
    and a rung's settle-then-measure cannot read it (#492, #528, #538):

      discharge  A NORMAL and a LEGENDARY rf-reactor and eighteen vanilla accumulators -- one
                 name+quality key between them, so they are read as one member -- on a
                 secondary-output supply held at HALF of what the two reactors spend. Short enough
                 that neither reactor is capped, so "by ask" (90 : 225) and "even" predict different
                 things for what the accumulators add. The accumulators stand empty for one rung's
                 length, are charged to their full buffer on one tick, and every member is then
                 read EVERY SECOND for thirty: what each reactor drew, what the accumulators gave
                 and took, and what they still hold. The prediction beside each row is made
                 from the supply plus what the accumulators were measured giving.
      acc-supply A normal rf-reactor and the eighteen accumulators on a secondary-output supply held
                 at 0.9 of what the reactor spends (#528): charged accumulators as part of a supply
                 that is short without them.
      acc-supply-load  The same with the rig's tertiary load beside them.
      acc-spare  acc-supply with the supply at exactly what the reactor spends, so that once the
                 reactor's own buffer has stopped filling the accumulators have charge nobody
                 but a tertiary load could ask for.
      acc-spare-load  The same with the tertiary load: whether it draws what they have to spare.
      acc-acc    acc-spare-load with six LEGENDARY accumulators where the tertiary load was (#538),
                 emptied every second as a ladder cell's are: accumulator to accumulator. Another
                 quality because the charged eighteen already hold the normal key.
      discharge-cap  The discharge cell with its supply at 0.68 of what the two reactors spend
                 (#538). By ask that leaves the legendary reactor just under its spend, and the
                 accumulators' 5.4 MW takes it over, so the excess is re-shared.

    THE LADDER. Each cell's supply is set to a fraction f of what its consumers SPEND together,
    from 1.2 (every consumer satisfied, with room) down to LOW in steps of STEP. Every rung is twenty seconds,
    the first half for the buffers to settle and the second measured, as in the sibling rig. A
    discharge cell's supply does not move; its buffer is one tick of that one figure.

    WHAT IS PREDICTED, AND PRINTED BESIDE WHAT IS MEASURED. "A share of what it asks for", tick by
    tick (#534). Each tick a member asks for its input_flow_limit or for the room left in its
    buffer, whichever is less; the supply is divided in proportion to what each asks; and each
    member then spends out of its buffer. The buffers are read where each measured period starts,
    so the prediction carries what every member holds and how much room it has left.

    THE WATER-FILL IS THAT RULE'S STEADY STATE, and it was the whole prediction until #534: divide
    by flow limit, cap each member at its spend, re-share the excess. A member handed more than it
    spends fills its buffer until the room left asks for exactly its spend, and stays there. The
    steady rule could not say what a buffer with room in it does on the way, and #528 measured a
    reactor that had been short drawing past its spend to fill one.

    BETWEEN priority classes the prediction is #439's reading of the primary cell: primary-input,
    then secondary-input, then tertiary, each served in full from what the one before left. Since
    #528 a fourth class is served after those three: managed-accumulator, which is what the engine
    reports for a vanilla accumulator. The report prints, per member, what it drew and gave back,
    the prediction and the deviation, so a class rule that is wrong shows up as one, not as a pass.

    WHAT A STORE GIVES IS READ, NOT PREDICTED. A discharge cell's supply is its interface plus what
    its charged accumulators were measured giving in that second, handed over at their output
    limit until it is spent.

    THE LESSONS THE SIBLING RIG PAID FOR, KEPT HERE

      * The supply interface delivers out of its own buffer, so the buffer is at once a reserve that
        hides the knee and a ceiling on what it can deliver. It is one tick of the ladder's TOP rung.
      * Flow statistics in 2.0 are keyed by name and quality; asked for the bare name, they answer
        zero for everything but normal.
      * Every reactor is topped back up to one fill of its own plasma -- D-D for rf-reactor, D-He3
        for rf-aneutronic-reactor -- and has its energy box emptied every second, so
        none drops out of the simulation -- a reactor control.lua does not step is not charged,
        and that would read as a brownout and is not one.

    THE RESEARCH STATE IS ASSERTED: nothing held, on every ladder, or the first -HeatingRungs rungs
    of the heating ladder and nothing else (rf_assert_research, #444). The spend is heating_power_w
    and the heating ladder moves it, so an unstated state is an unreadable table.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER HeatingRungs
    How many rungs of rf-reactor's heating ladder the rig's force holds (#494); 0, the default, is
    nothing researched. The top is the length of the ladder on reactor-logic's spec, read by the
    rig, and a count past it is refused there by name (#536). Every rf-reactor in every cell then spends that rung's heating_power_w, read
    off reactor-logic through the force's technologies, against the flow limit the prototype
    declares, which no rung moves. The loads spend the same. Research is per force and the rig has
    one, so a run is the WHOLE probe at one rung: researched and unresearched reactors cannot share
    a network here. rf-aneutronic-reactor has no ladder and spends what it ships with at any rung.

    pwsh -File scripts/probe-brownout-contention.ps1 -HeatingRungs 5

.PARAMETER RungSeconds
    Game seconds per rung; half settles and half is measured. EVEN, for the reason the sibling rig
    gives: the meter is marked at the half-way tick and the handler fires once a second.

.PARAMETER Low
    The bottom of the ladder, as a fraction of a cell's combined spend.

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
    [ValidateRange(0, [int]::MaxValue)] [int] $HeatingRungs = 0,
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
# The report fires when the ladder ends, and the discharge series runs for 30 s after one rung's
# length. A ladder shorter than that would print a series cut short, with nothing saying so.
if (($rungs - 1) * $RungSeconds -lt 32) {
    throw "the ladder is $rungs rung(s) of $RungSeconds s, which ends before the discharge series' 30 s; lower -Low or raise -RungSeconds."
}
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
# against the reactor they differ in the class and in nothing else. energy_usage here is the
# reactor's shipped heating power; the rig overwrites it with the run's own rung once it is built.
Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'data.lua') -Value @'
-- Generated by probe-brownout-contention.ps1. Nothing here ships.
local logic   = require("__realistic-fusion-refreshed__/scripts/reactor-logic")
local reactor = data.raw["boiler"]["rf-reactor"]
for _, priority in ipairs({ "secondary-input", "primary-input", "tertiary" }) do
  local load = table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"])
  load.name = "rf-probe-load-" .. priority
  load.energy_source = table.deepcopy(reactor.energy_source)
  load.energy_source.usage_priority = priority
  load.energy_production = "0W"
  load.energy_usage = string.format("%.10gW", logic.reactor.heating_power_w)
  data:extend({ load })
end
-- The tertiary cell's supply. Vanilla's interface is itself tertiary, and the 2.0.77 docs give
-- tertiary input only "the overproduction", which a tertiary supply is not; secondary-output is
-- the class they give steam generators.
local supply = table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"])
supply.name = "rf-probe-supply-secondary-output"
supply.energy_source.usage_priority = "secondary-output"
data:extend({ supply })
'@

$lua = @'
-- Generated by probe-brownout-contention.ps1. Reports; asserts nothing about the answer.

local RUNG_TICKS = __RUNG_TICKS__
local HIGH       = __HIGH__
local LOW        = __LOW__
local STEP       = __STEP__
local HEATING_RUNGS = __HEATING_RUNGS__

local REACTOR = "rf-reactor"
local ANEUTRONIC = "rf-aneutronic-reactor"
local SPACING = 60
local ACCUMULATOR = "accumulator"

local logic = require("__realistic-fusion-refreshed__/scripts/reactor-logic")

local function say(fmt, ...) log("BCPROBE " .. string.format(fmt, ...)) end
local function per_tick(w) return w / 60 end

__RIGBUILD__

__QUIETMAP__

-- Every reactor the rig can place: the spec its spend is read off, and the plasma it is kept in.
local REACTORS = {
  [REACTOR]    = { spec = logic.reactor,            plasma = "rf-d-d-plasma" },
  [ANEUTRONIC] = { spec = logic.aneutronic_reactor, plasma = "rf-d-he3-plasma" },
}

-- The first member of every cell is a normal rf-reactor; the rest are what it competes with. Every
-- member of a cell has a distinct name+quality key, because that is what the statistics read;
-- on_init refuses a cell where two share one (#536).
local SHAPES = {
  { name = "pair",      m = { { REACTOR, "normal" }, { REACTOR, "legendary" } } },
  { name = "secondary", m = { { REACTOR, "normal" }, { "rf-probe-load-secondary-input", "normal" } } },
  { name = "primary",   m = { { REACTOR, "normal" }, { "rf-probe-load-primary-input", "normal" } } },
  { name = "four",      m = { { REACTOR, "normal" }, { REACTOR, "legendary" },
                              { REACTOR, "rare" },   { REACTOR, "uncommon" } } },
  { name = "tertiary",  m = { { REACTOR, "normal" }, { "rf-probe-load-tertiary", "normal" } },
    supply = "rf-probe-supply-secondary-output" },
  { name = "tert-tert", m = { { REACTOR, "normal" }, { "rf-probe-load-tertiary", "normal" } } },
  { name = "three",     m = { { REACTOR, "normal" }, { "rf-probe-load-primary-input", "normal" },
                              { "rf-probe-load-tertiary", "normal" } },
    supply = "rf-probe-supply-secondary-output" },
  { name = "aneutronic", m = { { REACTOR, "normal" }, { ANEUTRONIC, "normal" } } },
  -- NOT ON THE LADDER: `discharge` is the fixed fraction of the reactors' spend its supply is held
  -- at. A third field on a member is how many of it there are, read as one member; a fourth,
  -- "load", makes an accumulator in a discharge cell a load, emptied every second, not a store.
  { name = "discharge", m = { { REACTOR, "normal" }, { REACTOR, "legendary" },
                              { ACCUMULATOR, "normal", 18 } },
    supply = "rf-probe-supply-secondary-output", discharge = 0.5 },
  -- A VANILLA ACCUMULATOR AS THE LOAD (#528), on each supply class; on the ladder.
  { name = "acc-tert", m = { { REACTOR, "normal" }, { ACCUMULATOR, "normal", 18 } } },
  { name = "acc-sec",  m = { { REACTOR, "normal" }, { ACCUMULATOR, "normal", 18 } },
    supply = "rf-probe-supply-secondary-output" },
  -- AND AS PART OF THE SUPPLY (#528), without the tertiary load and with it.
  { name = "acc-supply", m = { { REACTOR, "normal" }, { ACCUMULATOR, "normal", 18 } },
    supply = "rf-probe-supply-secondary-output", discharge = 0.9 },
  { name = "acc-supply-load", m = { { REACTOR, "normal" }, { "rf-probe-load-tertiary", "normal" },
                                    { ACCUMULATOR, "normal", 18 } },
    supply = "rf-probe-supply-secondary-output", discharge = 0.9 },
  { name = "acc-spare", m = { { REACTOR, "normal" }, { ACCUMULATOR, "normal", 18 } },
    supply = "rf-probe-supply-secondary-output", discharge = 1 },
  { name = "acc-spare-load", m = { { REACTOR, "normal" }, { "rf-probe-load-tertiary", "normal" },
                                   { ACCUMULATOR, "normal", 18 } },
    supply = "rf-probe-supply-secondary-output", discharge = 1 },
  -- ACCUMULATOR TO ACCUMULATOR (#538): acc-spare-load with real accumulators as the load.
  { name = "acc-acc", m = { { REACTOR, "normal" }, { ACCUMULATOR, "legendary", 6, "load" },
                            { ACCUMULATOR, "normal", 18 } },
    supply = "rf-probe-supply-secondary-output", discharge = 1 },
  -- A DISCHARGE THAT CAPS ONE OF TWO REACTORS (#538). By ask the legendary reactor is full from
  -- 0.70 of the pair's spend at any heating rung; 0.68 is under that, and 5.4 MW more is over it.
  { name = "discharge-cap", m = { { REACTOR, "normal" }, { REACTOR, "legendary" },
                                  { ACCUMULATOR, "normal", 18 } },
    supply = "rf-probe-supply-secondary-output", discharge = 0.68 },
}
-- The discharge cells' clock: empty for one rung's length, then read every second for SERIES_S.
local CHARGE_TICK = RUNG_TICKS
local SERIES_S    = 30
local BEFORE_S    = 3
-- Where member i sits relative to the cell's substation: the four corners of its supply area.
local SLOTS = { { 0.5, 0.5 }, { 0.5, 20.5 }, { 20.5, 0.5 }, { 20.5, 20.5 } }

--- What a member has drawn through its network, cumulatively, in joules. Keyed by name AND quality.
local function drawn(cell, m)
  return cell.substation.electric_network_statistics.get_input_count(
    { name = m.entity.name, quality = m.quality }) or 0
end

--- What a member has GIVEN to its network, the same way. Only a tertiary member or an
--- accumulator can.
local function given(cell, m)
  return cell.substation.electric_network_statistics.get_output_count(
    { name = m.entity.name, quality = m.quality }) or 0
end

--- What a member's buffer holds, in joules, over every entity of it.
local function stored(m)
  local j = 0
  for _, entity in ipairs(m.entities) do j = j + entity.energy end
  return j
end

--- The room in each member's buffer, in joules, read where a measured period starts (#534).
local function rooms(c)
  local room = {}
  for i, m in ipairs(c.members) do room[i] = m.buffer_j - stored(m) end
  return room
end

--- The prediction, tick by tick (#534): "a share of what it asks for", where a member asks for
--- its flow limit or the room in its buffer, whichever is less. The classes are served in order,
--- each in proportion to what its members ask, from what the one before left; within one class
--- that is the by-ask rule and between classes "the earlier one first, in full".
---
--- The water-fill this replaces -- share by flow limit, cap at the spend, re-share -- is this
--- rule's steady state: a member handed more than it spends fills its buffer until the room left
--- asks for exactly its spend.
---
--- @param supply_w  the supply interface's production
--- @param members   the cell's
--- @param room      rooms()' reading where the period starts
--- @param ticks     the period's length
--- @param extra_j   what the cell's stores were measured giving over the period, handed over at
---                  OUT_W, their output limit, until it is spent; nil on the ladder
--- @return what each member draws, in watts over the period, keyed by member
-- managed-accumulator is what the engine reports for a vanilla accumulator, whose prototype says
-- tertiary. It is served last here: the docs give accumulators "the overproduction".
local CLASSES = { "primary-input", "secondary-input", "tertiary", "managed-accumulator" }
local function predict(supply_w, members, room, ticks, extra_j, out_w)
  local got, held = {}, {}
  for i, m in ipairs(members) do got[m], held[m] = 0, m.buffer_j - math.max(room[i], 0) end
  extra_j = extra_j or 0
  -- WHEN A MEMBER SPENDS. control.lua charges a reactor in on_tick, ahead of the rig's reading,
  -- so the reading already has this tick's spend out of it. A load is an interface the engine
  -- charges, and its reading does not. Taken the same way for both, a 600-tick rung is one
  -- tick's spend out on whichever is wrong.
  local function spend(reactors)
    for _, m in ipairs(members) do
      if not (m.store or m.drain) and (m.fill ~= nil) == reactors then
        held[m] = held[m] - math.min(m.spend_w / 60, held[m])
      end
    end
  end
  for tick = 1, ticks do
    spend(false)
    local give = math.min(extra_j, (out_w or 0) / 60)
    local left = supply_w / 60 + give
    extra_j = extra_j - give
    for _, class in ipairs(CLASSES) do
      local asks, ask = 0, {}
      for _, m in ipairs(members) do
        if m.priority == class and not m.store then
          ask[m] = math.min(m.limit_w / 60, m.buffer_j - held[m])
          asks = asks + ask[m]
        end
      end
      local share = asks > 0 and math.min(1, left / asks) or 0
      for _, m in ipairs(members) do
        if ask[m] then got[m], held[m] = got[m] + ask[m] * share, held[m] + ask[m] * share end
      end
      left = left - asks * share
    end
    spend(true)
    -- A load accumulator is emptied by the rig once a second.
    if tick % 60 == 0 then
      for _, m in ipairs(members) do if m.drain then held[m] = 0 end end
    end
  end
  for _, m in ipairs(members) do got[m] = got[m] * 60 / ticks end
  return got
end

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player

  -- THE RESEARCH STATE, arranged and then asserted rather than assumed: the heating ladder moves
  -- the spend. Nothing held, or the first HEATING_RUNGS rungs of that ladder and nothing else (#494).
  local top = #logic.reactor.heating_ladder
  if HEATING_RUNGS > top then
    error(string.format("-HeatingRungs %d is past the top of rf-reactor's heating_ladder, which has "
      .. "%d rungs", HEATING_RUNGS, top))
  end
  local held = HEATING_RUNGS > 0 and { heating_ladder = HEATING_RUNGS } or false
  if held then rf_unresearch(force, logic, logic.reactor, held) end
  rf_assert_research(function(ok, name, detail)
    if not ok then error(name .. " -- " .. detail) end
    say("research          %s", name)
  end, force, logic, logic.reactor, held)
  -- What a reactor spends at that state. A spec with no heating ladder answers its shipped figure.
  local function heating_w(spec)
    return logic.resolve_ladder(spec, "heating_ladder", "heating_power_w",
      function(technology) return force.technologies[technology].researched end)
  end

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
    local function member(name, quality, position, what, role)
      local entity = rf_place_or_die(surface,
        { name = name, position = position, force = force, quality = quality, raise_built = true },
        what .. " in " .. shape.name)
      local source = entity.prototype.electric_energy_source_prototype
      local m = { entity = entity, entities = { entity }, quality = quality,
        priority = source.usage_priority, limit_w = source.get_input_flow_limit(quality) * 60,
        buffer_j = entity.electric_buffer_size }
      if REACTORS[name] then
        m.spend_w = heating_w(REACTORS[name].spec)
        m.fill, m.plasma = entity.fluidbox.get_capacity(1), REACTORS[name].plasma
      elseif name == ACCUMULATOR then
        m.out_w = source.get_output_flow_limit(quality) * 60
        if shape.discharge and role ~= "load" then
          -- A store, not a consumer: it spends nothing, and is charged once by the discharge clock.
          m.spend_w, m.store = 0, true
        else
          -- A load: emptied every second, so it asks for its whole flow limit for ever.
          m.spend_w, m.drain = m.limit_w, true
        end
      else
        -- A load spends what rf-reactor does at this run's rung, not what its prototype was given.
        entity.power_usage = per_tick(heating_w(logic.reactor))
        m.spend_w = entity.power_usage * 60
      end
      return m
    end
    -- COUNT of one thing as ONE member: two columns down the east edge of the supply area, or,
    -- for a load, south of the substation, where a second reactor would stand. They share a
    -- name+quality key, so the statistics could not tell them apart anyway.
    local function group(name, quality, count, what, role)
      local m
      local x, y = role == "load" and 10 or 15, role == "load" and 14 or 2
      for k = 0, count - 1 do
        local one = member(name, quality, { ox + x + 2 * (k % 2), y + 2 * math.floor(k / 2) }, what, role)
        if m then
          m.entities[#m.entities + 1] = one.entity
          m.limit_w, m.out_w = m.limit_w + one.limit_w, m.out_w + one.out_w
          m.spend_w, m.buffer_j = m.spend_w + one.spend_w, m.buffer_j + one.buffer_j
        else m = one end
      end
      return m
    end
    -- One substation reaches every member and nothing else. A load sits in the strip between the
    -- first two reactor slots, because the corner slots past the first two only touch the supply
    -- area with a reactor's footprint.
    -- `burn` is what the cell's REACTORS spend, which is what a discharge cell's supply is a
    -- fraction of; `spend` is every member's, which is what the ladder is a fraction of.
    local members, spend, burn = {}, 0, 0
    for i, spec in ipairs(shape.m) do
      local at = REACTORS[spec[1]] and SLOTS[i] or { 3 * i - 5, 10 }
      local m = spec[3] and group(spec[1], spec[2], spec[3], "consumer " .. i, spec[4])
        or member(spec[1], spec[2], { ox + at[1], at[2] }, "consumer " .. i)
      members[i], spend = m, spend + m.spend_w
      if REACTORS[spec[1]] then burn = burn + m.spend_w end
    end
    -- ONE KEY PER MEMBER (#536). The statistics answer by name and quality, so two members under
    -- one key would each be read as drawing what both drew.
    local keys = {}
    for i, m in ipairs(members) do
      local key = m.entity.name .. "/" .. m.quality
      if keys[key] then
        error(string.format("%s: consumers %d and %d share the name+quality key %s, so the "
          .. "statistics would count each one's draw for both", shape.name, keys[key], i, key))
      end
      keys[key] = i
    end
    local substation = rf_place_or_die(surface,
      { name = "substation", position = { ox + 9, 10 }, force = force }, "substation in " .. shape.name)
    local supply = rf_place_or_die(surface,
      { name = shape.supply or "electric-energy-interface", position = { ox + 12, 10 }, force = force },
      "supply in " .. shape.name)
    -- One tick of the TOP rung's production: the sibling rig's lesson, both halves of it. A
    -- discharge cell has one rung, its own.
    local top = shape.discharge and burn * shape.discharge or spend * HIGH
    supply.electric_buffer_size = per_tick(top)
    supply.energy = 0
    supply.power_production = per_tick(top)
    cells[#cells + 1] = { name = shape.name, members = members, substation = substation,
      supply = supply, spend_w = spend, rungs = {}, discharge = shape.discharge }
  end

  -- ONE NETWORK PER CELL, AND ONLY ONE CELL PER NETWORK. Proven off the entities, not the layout.
  local seen = {}
  for _, c in ipairs(cells) do
    local ia = c.members[1].entity.electric_network_id
    for i, m in ipairs(c.members) do
      for _, entity in ipairs(m.entities) do
        local ib = entity.electric_network_id
        if not ia or ia ~= ib then
          error(string.format("%s: consumers 1 and %d are on networks %s and %s, so nothing here is "
            .. "contention", c.name, i, tostring(ia), tostring(ib)))
        end
      end
    end
    if c.supply.electric_network_id ~= ia then
      error(c.name .. ": its supply is not on its consumers' network")
    end
    if seen[ia] then error(c.name .. " shares network " .. ia .. " with " .. seen[ia]) end
    seen[ia] = c.name
    c.network = ia
  end

  -- The ladder's cells and the discharge clock's, apart: neither loop reads the other's.
  storage.cells, storage.series = {}, {}
  for _, c in ipairs(cells) do
    local into = c.discharge and storage.series or storage.cells
    into[#into + 1] = c
  end
  storage.f = HIGH
  log("BCRIG built")
end)

--- Keep every reactor fed and drained so none drops out of the simulation.
local function tend_cells(cells)
  for _, c in ipairs(cells) do
    for _, m in ipairs(c.members) do
      for _, entity in ipairs(m.entities) do
        if not entity.valid then error(c.name .. ": a consumer is gone mid-run") end
      end
      if m.fill then
        local plasma = m.entity.fluidbox[1]
        if not plasma or plasma.amount < m.fill then
          m.entity.fluidbox[1] = { name = m.plasma, amount = m.fill,
            temperature = plasma and plasma.temperature or 15 }
        end
        m.entity.fluidbox[2] = nil
      end
      if m.drain then
        for _, entity in ipairs(m.entities) do entity.energy = 0 end
      end
    end
    if not (c.substation.valid and c.supply.valid) then error(c.name .. ": its supply is gone") end
  end
end
local function tend() tend_cells(storage.cells) tend_cells(storage.series) end

--- The discharge clock (#492), once a second: empty until CHARGE_TICK, charged on it, and every
--- member read each second from BEFORE_S before to SERIES_S after.
local function discharge(tick)
  local t = (tick - CHARGE_TICK) / 60
  if t < -BEFORE_S or t > SERIES_S then return end
  for _, c in ipairs(storage.series) do
    if c.mark_in then
      local r = { t = t, supply = c.supply.power_production * 60, drew = {}, gave = {}, held = {},
        room = c.mark_room }
      for i, m in ipairs(c.members) do
        r.drew[i] = (drawn(c, m) - c.mark_in[i]) / 1e6
        r.gave[i] = (given(c, m) - c.mark_out[i]) / 1e6
        r.held[i] = m.store and stored(m) / 1e6
      end
      c.rungs[#c.rungs + 1] = r
    end
    c.mark_in, c.mark_out, c.mark_room = {}, {}, rooms(c)
    for i, m in ipairs(c.members) do
      c.mark_in[i], c.mark_out[i] = drawn(c, m), given(c, m)
      if m.store and t == 0 then
        for _, entity in ipairs(m.entities) do entity.energy = entity.electric_buffer_size end
      end
    end
  end
end

local function report()
  say("map               quieted: pollution and expansion off, peaceful, %d enemy entities removed",
    storage.quieted)
  say("ladder            f from %.10g down to %.10g in steps of %.10g of each cell's combined spend, "
    .. "%d ticks a rung, the second half measured", HIGH, LOW, STEP, RUNG_TICKS)
  for _, c in ipairs(storage.cells) do
    say("cell   %-10s network=%d  supply %s (%s)", c.name, c.network, c.supply.name,
      c.supply.prototype.electric_energy_source_prototype.usage_priority)
    for i, m in ipairs(c.members) do
      say("         %d  %s%s/%s %s  limit %.6g MW  spend %.6g MW  buffer %.6g MJ", i,
        #m.entities > 1 and (#m.entities .. " x ") or "", m.entity.name, m.quality,
        m.priority, m.limit_w / 1e6, m.spend_w / 1e6, m.buffer_j / 1e6)
    end
  end
  for _, c in ipairs(storage.series) do
    say("cell   %-10s network=%d  supply %s (%s), held at %.10g of the reactors' spend", c.name,
      c.network, c.supply.name, c.supply.prototype.electric_energy_source_prototype.usage_priority,
      c.discharge)
    for i, m in ipairs(c.members) do
      if m.store then
        say("         %d  %d x %s/%s %s  takes up to %.6g MW  gives up to %.6g MW  holds %.6g MJ", i,
          #m.entities, m.entity.name, m.quality, m.priority, m.limit_w / 1e6, m.out_w / 1e6,
          m.buffer_j / 1e6)
      else
        say("         %d  %s%s/%s %s  limit %.6g MW  spend %.6g MW  buffer %.6g MJ", i,
          #m.entities > 1 and (#m.entities .. " x ") or "", m.entity.name, m.quality,
          m.priority, m.limit_w / 1e6, m.spend_w / 1e6, m.buffer_j / 1e6)
      end
    end
  end
  for _, c in ipairs(storage.cells) do
    say("%s    (per member: drew | predicted | deviation, MW)", c.name)
    local worst, worst_out, most_room = 0, 0, 0
    for _, r in ipairs(c.rungs) do
      local got = predict(r.supply, c.members, r.room, RUNG_TICKS / 2)
      local cols = {}
      for i, m in ipairs(c.members) do
        local d = r.drew[i] - got[m] / 1e6
        worst = math.max(worst, math.abs(d))
        worst_out = math.max(worst_out, r.gave[i])
        -- A drained accumulator is empty by construction; its room says nothing.
        if not m.drain then most_room = math.max(most_room, r.room[i]) end
        cols[#cols + 1] = string.format("%8.4g %8.4g %9.3g", r.drew[i], got[m] / 1e6, d)
      end
      say("  f=%6.4f supply %8.4g | %s", r.f, r.supply / 1e6, table.concat(cols, " | "))
    end
    say("  worst deviation from the prediction: %.4g MW; most any member gave back: %.4g MW; "
      .. "most room in any buffer where a measured half began: %.4g MJ", worst, worst_out,
      most_room / 1e6)
  end
  -- THE DISCHARGE, second by second. t is the END of the second read, counted from the tick the
  -- stores were charged on; the prediction is made from the supply plus what the stores
  -- were measured giving in that second, from the room each buffer had when the second began (#534).
  for _, c in ipairs(storage.series) do
    say("%s    (per consumer: drew | predicted | deviation, MW, room in its buffer when the second "
      .. "began, MJ; per store: gave, drew, MW | holds, MJ)", c.name)
    local worst = 0
    for _, r in ipairs(c.rungs) do
      local extra, out_w = 0, 0
      for i, m in ipairs(c.members) do
        if m.store then extra, out_w = extra + r.gave[i], out_w + m.out_w end
      end
      local got = predict(r.supply, c.members, r.room, 60, extra * 1e6, out_w)
      local cols = {}
      for i, m in ipairs(c.members) do
        if m.store then
          cols[#cols + 1] = string.format("%8.4g %8.4g | %8.4g", r.gave[i], r.drew[i], r.held[i])
        else
          local d = r.drew[i] - got[m] / 1e6
          worst = math.max(worst, math.abs(d))
          cols[#cols + 1] = string.format("%8.4g %8.4g %9.3g %7.4g", r.drew[i], got[m] / 1e6, d,
            r.room[i] / 1e6)
        end
      end
      say("  t=%+4d s supply %8.4g | %s", r.t, r.supply / 1e6, table.concat(cols, " | "))
    end
    say("  worst deviation from the prediction: %.4g MW", worst)
  end
  say("done")
end

script.on_nth_tick(60, function()
  local tick = game.tick
  if storage.reported then return end
  tend()
  discharge(tick)
  local into = tick % RUNG_TICKS
  if into == RUNG_TICKS / 2 then
    for _, c in ipairs(storage.cells) do
      c.mark_in, c.mark_out, c.mark_room = {}, {}, rooms(c)
      for i, m in ipairs(c.members) do c.mark_in[i], c.mark_out[i] = drawn(c, m), given(c, m) end
    end
    return
  end
  if into == 0 and tick >= RUNG_TICKS then
    local seconds = (RUNG_TICKS / 2) / 60
    for _, c in ipairs(storage.cells) do
      if c.mark_in == nil then error(c.name .. ": the meter was never marked") end
      local r = { f = storage.f, supply = c.spend_w * storage.f, drew = {}, gave = {},
        room = c.mark_room }
      for i, m in ipairs(c.members) do
        r.drew[i] = (drawn(c, m) - c.mark_in[i]) / seconds / 1e6
        r.gave[i] = (given(c, m) - c.mark_out[i]) / seconds / 1e6
      end
      c.rungs[#c.rungs + 1] = r
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
    Replace('__STEP__', [string]::Format($inv, '{0}', $Step)).
    Replace('__HEATING_RUNGS__', "$HeatingRungs")
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

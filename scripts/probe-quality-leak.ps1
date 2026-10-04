<#
.SYNOPSIS
    Measures the residual boiler leak on a COLD reactor at every quality level, so the figure
    docs/research/quality.md quotes stops being arithmetic off declared fields. The rig #147 asks
    for.

.DESCRIPTION
    A PROBE, NOT A CHECK. Every line it prints is a measurement, and a negative answer -- including
    "this cannot be measured at this resolution" -- is as much of a result as a positive one. Exit 0
    means the probe ran and every row reported, never that the answer was the one anybody hoped for.
    Nothing here decides anything and nothing here ships. It must not be added to a check sweep, a
    bench sweep or to load-check.ps1.

    WHAT IT CLOSES

    rf-reactor is a boiler with energy_consumption = 1 W and target_temperature = 550. The plasmas
    declare no heat_capacity, so they take FluidPrototype.heat_capacity's default of 1 kJ per unit
    per degree, and 15 C to 550 C is 535 kJ per unit -- one unit per 535 000 s at 1 W. Quality
    multiplies energy_consumption by 2.5, so docs/research/quality.md puts a legendary reactor's
    engine-side conversion at one unit per 214 000 s: 1 MJ per 59.4 h, or 4.7 W, against 50 MW of
    heating. One part in ten million.

    The note is explicit that none of that was run: "the rig places entities and reads prototypes,
    it does not run a reactor, so this is arithmetic off declared fields plus the repository's own
    normal-quality measurement."

    WHY IT IS NOT A ROW ON probe-quality-equilibrium.ps1. #101 established that the conversion is
    exactly zero whenever the plasma is at or above target_temperature, so a FUSING reactor leaks
    nothing at any quality. That rig's cells are settled hot and would read zero by construction.
    This wants the opposite: plasma parked at min_temperature_c, which is what every reactor is for
    its first few seconds and what one with a dead heater is for ever.

    THE ISOLATION, and it is the same one probe-target-temperature.ps1 uses for the same reason. The
    subjects are copies of rf-reactor under a rig-only name, so scripts/entity-management.lua never
    registers them and control.lua's SPECS never sees them. Nothing but the engine touches their
    plasma -- which matters more here than anywhere, because a registered reactor cannot BE cold: it
    is stepped, it is paid its confinement heating, and it climbs away from the floor in seconds.
    The figure under test is an engine-side one, so an engine-side rig is what measures it.

    THE ENERGY SOURCE IS KEPT ELECTRIC, and that is the one place this rig differs from
    probe-target-temperature.ps1, which voids it. Quality is the variable here, and what quality
    does to a machine's declared consumption is exactly what is being measured -- so the shipped
    energy source stays, with a substation and a supply per cell, and each subject's buffer and
    status are printed to say it was actually powered rather than merely wired.

    TWO KINDS OF PRECISION, AND ONLY ONE OF THEM IS A PROBLEM

    #147 was written around the worry that the depletion is too small to read: at 2.5 W the leak
    removes 1 MJ per 214 000 s, which over a thousand game seconds is about 4.7e-3 of a unit out of
    a box holding a thousand. That worry is answered and it is not the one that bites.

      * THE READING IS FINE, and the rig measures that rather than assuming it. It writes an amount,
        writes it again a little smaller, and halves the difference until the box stops reporting
        one; what comes back is the smallest change the engine will report at that magnitude. It is
        about 1.1e-13 at a thousand units -- a double's precision, not a float's -- so the depletion
        is ten orders clear of the reading and no row here is a rounding artefact.

      * THE TRANSFER IS NOT FINE, and that is the finding. The engine moves fluid per tick in whole
        multiples of a float32 ULP at 1.0, 5.96e-8 units, and at every level below legendary the
        rate law asks for less than one of those -- epic by 0.7% -- so the transfer floors to
        nothing. Legendary asks for 1.307 and gets exactly one. The report prints what the law wants
        per tick and what the engine moved, side by side in those units, so the reader can see the
        flooring happen rather than take it on trust.

      * THE ANSWER IS TAKEN OFF THE OUTPUT BOX, which starts at zero, and the input box's depletion
        is printed beside it. The two do not agree unit for unit -- the ratio is reported per cell --
        and the output box is the one the rate is taken from, because it starts from nothing and its
        reading lands on an exact multiple of the transfer quantum. Since #541 each box's segment
        is read beside it: the input box trades with the segment it is in, and box plus segment on
        the input side is what the output box gains. Since #553 two cold cells, normal and
        legendary, are also traced every tick and run beside two models of the box/segment trade
        from the seed: the rule docs/research/exchanger-coverage.md states, and a fixed-point
        variant fitted to that trace. The `model` rows say where the game leaves each.

    AND #101 IS RE-CONFIRMED AT QUALITY. Every level runs twice: one cell cold at
    min_temperature_c, one hot at the shipped D-D equilibrium. The hot row must read zero -- and it
    is measured at each level rather than carried over from the normal-quality measurement, because
    "the conversion is zero above the target" and "the conversion is zero above the target at every
    quality" are different claims and only the first was ever run.

    THE MAP IS QUIETED AND A DAMAGED RIG FAILS LOUDLY, and here that guard matters more than in the
    sibling rigs rather than less. This probe's headline result is a ZERO, and an unpowered boiler
    converts nothing -- so a cell that quietly loses its substation reports exactly the answer the
    rig is looking for, at the one level where a non-zero answer was expected. Four of the five
    levels read zero legitimately, so nothing in the numbers would look wrong either. It calls the
    shared guard, Get-QuietMapLua in scripts/factorio-lib.ps1, before it builds, and checks every
    cell's boiler, substation and supply valid once a second for the whole run.

    WHAT IT DOES NOT DO. It does not remove the leak. That is a fuel leak rather than an energy
    exploit -- the boiler spends a unit of plasma, 10^20 nuclei, to make 1 MJ where fusing the same
    nuclei releases about 58 MJ -- and whether to do anything about it is a design question
    docs/research/quality.md raises under its option space and Truls's to answer.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Seconds
    Game seconds the subjects are left converting before the reading. The default of 1000 is chosen
    against the rate rather than guessed: it is 3.6e-3 of a unit at legendary, against a reading
    whose measured resolution is about 1.1e-13, so the answer is ten orders clear of the noise.

    THE FOUR LEVELS BELOW LEGENDARY REPORT ZERO AT ANY LENGTH, and that is the finding rather than a
    short run. Run it at -Seconds 10000 and they still do, to the same ten digits -- which is the
    evidence that the flooring is real and not a rate too small to have shown yet.

.PARAMETER TraceTicks
    The last tick the trace prints (#553). Every tick from 1 to this, the normal and the legendary
    cold cell's input box, its segment and the output box, to seventeen digits. The default of 600
    covers the seeded box's relaxation and the first five seconds of the drain; -TraceTicks 60300
    covers the whole default run, about 120 000 lines.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/probe-quality-leak.ps1

.EXAMPLE
    pwsh -File scripts/probe-quality-leak.ps1 -Seconds 10000

    Ten times the length. The measured rate should not move; that it does not is the evidence that
    the shorter run is long enough.
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [ValidateRange(1, 1000000)] [int] $Seconds = 1000,
    [ValidateRange(0, 60000000)] [int] $TraceTicks = 600,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$rigName  = 'rf-quality-leak-probe'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-ql-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

@{
    name = $rigName; version = '0.0.1'; title = 'Quality boiler-leak probe'
    author = 'probe-quality-leak.ps1'; factorio_version = '2.0'
    dependencies = @('base >= 2.0.77', 'quality', 'realistic-fusion-refreshed')
} | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

# ---------------------------------------------------------------------------- the rig's prototype
Add-RigData -RigDirectory $rigDir -Lua @'
-- Generated by probe-quality-leak.ps1. Nothing here ships.
--
-- ONE COPY OF rf-reactor UNDER A RIG-ONLY NAME. control.lua's SPECS is keyed by entity name and
-- scripts/entity-management.lua registers by name, so this is invisible to the simulation: its
-- plasma is moved by the engine and by nothing else. That is the whole instrument. A registered
-- reactor cannot be cold -- it is stepped and paid its confinement heating from the same buffer the
-- boiler draws on, and it climbs off the floor within seconds -- so the cold case has no other way
-- of being held still.
--
-- EVERY FIELD THE MEASUREMENT DEPENDS ON IS THE SHIPPED ONE, and none is restated here:
-- energy_consumption, target_temperature, both fluid boxes and the electric energy source are
-- whatever prototypes/entities.lua last set them to. A copy that pinned its own 1 W would go on
-- measuring 1 W after the shipped value moved.
local subject = table.deepcopy(data.raw["boiler"]["rf-reactor"])
subject.name = "rfql-boiler"
subject.minable = nil
subject.placeable_by = nil
-- No item and no recipe: the rig places these with create_entity, never a player.
subject.flags = { "not-blueprintable", "not-deconstructable", "hide-alt-info" }

data:extend({ subject })
'@

# ---------------------------------------------------------------------------- the measurement
$lua = @'
-- Generated by probe-quality-leak.ps1. Reports; asserts nothing.

local RUN_TICKS = __RUN_TICKS__
local TRACE_TICKS = __TRACE_TICKS__

-- Five seconds between seeding the boxes and taking the baseline they are measured against.
--
-- A BOX SEEDED TO ITS OWN DECLARED VOLUME DOES NOT STAY THERE. Written to 1000 -- fluid_box.volume,
-- and what get_capacity() reports -- an rf-reactor's input box relaxes to 526.3158 over about two
-- seconds and then holds that figure to the digit, at every quality and in both temperature
-- regimes. It is a property of the seeding rather than of the conversion under test, and the first
-- run of this rig charged all 473.68 units of it to the leak. The baseline is therefore taken after
-- the relaxation has finished, and the settled level is REPORTED beside the declared volume, since
-- a box that holds a little over half what its prototype says is worth knowing on its own account.
-- The trace below is what says the relaxation is over by then.
local BASELINE_TICKS = 300

local SUBJECT = "rfql-boiler"
local PLASMA  = "rf-d-d-plasma"
local ENERGY  = "rf-reactor-energy"

-- The fluid's own default_temperature and the reactor spec's min_temperature_c, which is where
-- reactor-logic clamps an idle plasma and therefore the only temperature the leak has in play.
local COLD_C = 15

-- The shipped D-D equilibrium, so the hot row is #101's finding re-asked where a real reactor
-- actually sits rather than at a round number above the target.
local HOT_C = 2.42e8

-- Thirty tiles between cells. rf-reactor is fifteen square, so a fifteen-tile pitch would have them
-- touching and a substation's eighteen-tile supply area reaching the neighbour.
local SPACING = 30

local function say(fmt, ...) log("QLPROBE " .. string.format(fmt, ...)) end

--- The quality levels a player can hold, in level order.
--
-- Discovered rather than listed, so a level added or renamed changes what this measures instead of
-- being ignored. quality-unknown is the engine's placeholder for a quality a save names and the mod
-- set does not define; it is hidden and no player can hold one.
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

--- What the fluid segment a box is in holds, as get_fluid_segment_contents answers it, and that
-- segment's get_capacity. A box with no pipe on it is still in a segment of its own (#531,
-- docs/research/exchanger-coverage.md, "The rule behind the split"), and the two trade every tick,
-- so a box's own amount is only part of what a conversion moves (#541).
local function segment_of(entity, index)
  local total = 0
  for _, amount in pairs(entity.fluidbox.get_fluid_segment_contents(index) or {}) do
    total = total + amount
  end
  return total, entity.fluidbox.get_capacity(index)
end

local function must(entity, what)
  if not entity then error(what .. " refused") end
  return entity
end

--- defines.entity_status by name, so a status prints as a word rather than as a number.
local STATUS = {}
for name, value in pairs(defines.entity_status) do STATUS[value] = name end

__QUIETMAP__
--- Every entity a cell is measured through, checked before it is measured through.
--
-- THIS RIG'S HEADLINE RESULT IS A ZERO, WHICH IS ALSO WHAT A BROKEN CELL REPORTS. An unpowered
-- boiler converts nothing, so a cell whose substation has been eaten reads exactly "measured 0" at
-- the one level where a non-zero answer was expected -- and at four of the five levels the true
-- answer is zero anyway, so nothing in the numbers would look wrong. The run is a thousand game
-- seconds by default and ten thousand in this script's own example, which is long enough to be
-- attacked; Get-QuietMapLua's docstring records a fifty-minute rig that lost a substation that way.
-- Erroring with the level and regime named asserts nothing about the physics. It is the difference
-- between "this run did not happen" and a zero that reads like a measurement.
local function assert_intact(cell)
  for _, part in ipairs({
    { "its boiler", cell.entity }, { "its substation", cell.substation },
    { "its power source", cell.supply },
  }) do
    if not part[2].valid then
      error(string.format("%s %s: %s is gone -- something destroyed part of the rig mid-run, so "
        .. "this run measures damage rather than the conversion", cell.quality, cell.regime,
        part[1]))
    end
  end
end

--- The smallest change in a fluid amount the engine will report back, measured at `base`.
--
-- THE READING'S RESOLUTION IS THE HALF OF THIS PROBE THAT DECIDES WHETHER THE OTHER HALF MEANS
-- ANYTHING, so it is measured rather than deduced from what a float ought to do. Write an amount,
-- write it again a little smaller, halve the difference until the box stops reporting one, and the
-- last difference that showed is the answer.
--
-- It is destructive to the box it runs on, so it runs on a throwaway subject before the real ones
-- are seeded, and the temperature it writes is irrelevant -- only the amount is read.
--
-- IT SUBTRACTS RATHER THAN ADDS, and that is not a style choice. The first version added, and at
-- the box's own capacity every difference it tried was clamped away -- so it reported "no
-- resolution at all" for the magnitude the input-side reading is taken at, which is the one figure
-- this function exists to supply.
local function resolution_at(entity, base)
  local function write_read(amount)
    entity.fluidbox[1] = { name = PLASMA, amount = amount, temperature = COLD_C }
    local box = entity.fluidbox[1]
    return box and box.amount or 0
  end
  local reference = write_read(base)
  local delta, last = base / 2, nil
  for _ = 1, 80 do
    if write_read(base - delta) >= reference then return last end
    last = delta
    delta = delta / 2
  end
  return last
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

  local span = (#levels + 1) * SPACING
  surface.request_to_generate_chunks({ span / 2, 20 }, math.ceil(span / 32) + 3)
  surface.force_generate_chunk_requests()

  -- AFTER the chunks exist, which is the shared guard's one precondition: it clears what it can see,
  -- and it can only see chunks that have been generated. The count goes into the report so a reader
  -- can tell the quieting happened rather than take it on trust.
  storage.quieted = __QUIETFN__(surface)

  local tiles = {}
  for x = -30, span + 30 do
    for y = -30, 70 do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = { { -30, -30 }, { span + 30, 70 } } })) do
    if e.type ~= "character" then e.destroy() end
  end

  --- One powered subject: the boiler, a substation and a supply of its own.
  --
  -- The substation and the supply are HANDED BACK rather than discarded. Nothing reads them for a
  -- measurement; they are here so assert_intact() above can see the supply path, which is the half
  -- that fails silently.
  local function cell(x, y, quality)
    local e = must(surface.create_entity({
      name = SUBJECT, position = { x, y }, force = force, quality = quality, raise_built = false,
    }), SUBJECT .. " at " .. quality)
    local substation = must(
      surface.create_entity({ name = "substation", position = { x + 9, y }, force = force }),
      "substation at " .. quality)
    local eei = must(surface.create_entity({
      name = "electric-energy-interface", position = { x + 12.5, y + 0.5 }, force = force,
    }), "power source at " .. quality)
    -- Joules per TICK, so this is 240 MW -- seven orders above anything here draws. The subjects
    -- spend single-figure watts; the supply is set far above that so "was it powered" can never be
    -- an explanation for a rate that came out low. See scripts/check-brownout.ps1 for the unit.
    eei.power_production = 4e6
    return e, substation, eei
  end

  -- The throwaway the resolution is measured on, before anything the report depends on is seeded.
  local scratch = cell(0, 60, "normal")

  local cells = {}
  for index, q in ipairs(levels) do
    local x = index * SPACING
    for _, regime in ipairs({ { "cold", COLD_C, 0 }, { "hot", HOT_C, 30 } }) do
      local label, temperature, y = regime[1], regime[2], regime[3]
      local entity, substation, supply = cell(x, y, q.name)
      cells[#cells + 1] = {
        quality = q.name, level = q.level, regime = label, seeded_c = temperature,
        entity = entity, substation = substation, supply = supply,
      }
    end
  end

  -- THE FILL IS THE BOX'S OWN DECLARED CAPACITY, so the cold cells start where a real idle reactor
  -- sits -- as full as the prototype says it can be, at the floor. What the box actually settles to
  -- is read back at BASELINE_TICKS rather than assumed to be this.
  local fill = cells[1].entity.fluidbox.get_capacity(1)
  for _, c in ipairs(cells) do
    c.entity.fluidbox[1] = { name = PLASMA, amount = fill, temperature = c.seeded_c }
    -- The two models the tick handler runs beside the traced cells (#553), started from the seed.
    local seg, cap = segment_of(c.entity, 1)
    c.rule  = { box = fill, seg = seg }
    c.fixed = { box = fill * 2 ^ 24, seg = seg * 2 ^ 24 }
    c.seg_capacity, c.model_tick, c.model_out = cap, 0, 0
    c.rule_worst, c.fixed_misses = { diff = 0, tick = 0 }, 0
  end

  storage.cells = cells
  storage.fill  = fill
  storage.resolution = {
    fill = resolution_at(scratch, fill),
    -- And near zero, which is where the output box's reading is taken. One unit is the magnitude a
    -- reading of "a few thousandths of a unit" has to be resolved against.
    unit = resolution_at(scratch, 1),
  }
  scratch.destroy()
  log("QLRIG built")
end)

local function report()
  local cells = storage.cells
  local joules = prototypes.fluid[ENERGY].fuel_value   -- one unit, one megajoule. Read, not retyped.
  local seconds = RUN_TICKS / 60

  say("run               %d ticks (%.10g s), measured from tick %d", RUN_TICKS, seconds, BASELINE_TICKS)
  say("map               quieted before the run: pollution and expansion off, peaceful, %d enemy "
    .. "entities removed", storage.quieted)
  say("fill              every box seeded to %.10g units, fluid_box.volume as get_capacity reports "
    .. "it; the settled level each box actually held is the `seeded` column below", storage.fill)
  say("energy fluid      %s carries fuel_value %.10g J per unit", ENERGY, joules)
  -- The rate law's own terms, so the note can evaluate it rather than quote it. The documented model
  -- is energy_consumption / (heat_capacity * (target - input)), and every term in it except the
  -- consumption is here.
  for _, name in ipairs({ PLASMA, ENERGY }) do
    local f = prototypes.fluid[name]
    say("fluid  %-22s heat_capacity=%.10g default_temperature=%.10g max_temperature=%.10g",
      name, f.heat_capacity or 0, f.default_temperature or 0, f.max_temperature or 0)
  end
  say("target            rf-reactor's target_temperature is %s C",
    tostring(prototypes.entity[SUBJECT].target_temperature))
  -- Measured, not asserted, and it is the number every row below is judged against. Both magnitudes
  -- come back at a double's precision rather than a float's, which is the answer to the resolution
  -- worry #147 was written around: the depletion being measured is ten orders above the smallest
  -- difference the engine will report, so nothing here is a rounding artefact.
  say("resolution        at %.10g units: %s   at 1 unit: %s   (smallest change the box reports back)",
    storage.fill, tostring(storage.resolution.fill), tostring(storage.resolution.unit))

  -- THE ARITHMETIC IS PRINTED BESIDE THE MEASUREMENT, so agreement or disagreement is something a
  -- reader sees rather than divides for. The documented rate law is
  -- energy_consumption / (heat_capacity * (target - input)), and every term but the consumption is
  -- read off the prototypes above rather than restated here.
  local capacity = prototypes.fluid[PLASMA].heat_capacity
  local target   = prototypes.entity[SUBJECT].target_temperature

  -- One float32 ULP at 1.0. Named because the measured rates land on it exactly, and a reader
  -- comparing a rate against it should not have to recognise the number.
  local ULP32 = 2 ^ -24

  say("%-10s %-5s %-10s %13s %13s %13s %13s %13s %13s %13s %10s",
    "quality", "regime", "declared W", "made units", "taken units", "units/second",
    "watts", "predicted W", "want ULP/tick", "got ULP/tick", "status")
  for _, c in ipairs(cells) do
    local e = c.entity
    local input  = e.fluidbox[1]
    local output = e.fluidbox[2]
    local left  = input and input.amount or 0
    local made  = (output and output.amount or 0) - c.made_at_baseline
    local taken = c.seeded - left
    -- get_max_energy_usage(quality) rather than a multiplier applied here: what quality does to the
    -- declared consumption is the thing under test, so it is read off the prototype per level.
    local declared = e.prototype.get_max_energy_usage(c.quality) * 60
    local rate = made / seconds
    -- The rate law's own answer, in the same watts the measurement is reported in. Zero delta means
    -- the plasma is at or above the target and the law does not apply -- #101's regime.
    local delta = target - (c.seeded_c or 0)
    local predicted = delta > 0 and (declared / (capacity * delta)) * joules or 0
    -- The pair of ULP columns is where the answer is. What the rate law asks the engine to move per
    -- tick, and what it moved.
    say("%-10s %-5s %-10.10g %13.10g %13.10g %13.10g %13.10g %13.10g %13.10g %13.10g %10s",
      c.quality, c.regime, declared, made, taken, rate, rate * joules, predicted,
      predicted / joules / 60 / ULP32, rate / 60 / ULP32,
      STATUS[e.status] or tostring(e.status))
  end

  say("ulp               one float32 ULP at 1.0 is %.17g units. `want ULP/tick` is what the rate "
    .. "law asks the engine to move each tick in those; `got ULP/tick` is what it moved", ULP32)
  say("boxes             the input and output readings do not agree unit for unit; their ratio is "
    .. "printed per cell below, close to but not equal to the factor the seeded box relaxed by")
  for _, c in ipairs(cells) do
    local output = c.entity.fluidbox[2]
    local made  = (output and output.amount or 0) - c.made_at_baseline
    local taken = c.seeded - (c.entity.fluidbox[1] and c.entity.fluidbox[1].amount or 0)
    if made > 0 and taken > 0 then
      say("boxes  %-10s %-5s made/taken = %.10g", c.quality, c.regime, made / taken)
    end
  end

  -- EACH BOX'S SEGMENT, READ BESIDE THE BOX (#541). `made` and `taken` above are box amounts, and a
  -- box trades with its segment every tick, so either box shows only its share of what moved.
  -- Printed for every cell: the segment's contents and capacity at the baseline and now, each
  -- side's box-plus-segment change, and that change over the box's alone.
  say("segment           per cell: input box, its segment and capacity at the baseline and now; "
    .. "then the same for the output; `in total` and `out total` are box plus segment")
  for _, c in ipairs(cells) do
    local e = c.entity
    local in_seg, in_cap = segment_of(e, 1)
    local out_seg, out_cap = segment_of(e, 2)
    local in_box  = e.fluidbox[1] and e.fluidbox[1].amount or 0
    local out_box = e.fluidbox[2] and e.fluidbox[2].amount or 0
    say("seg    %-10s %-5s in: box %.10g -> %.10g, segment %.10g -> %.10g of %.10g   "
      .. "out: box %.10g -> %.10g, segment %.10g -> %.10g of %.10g",
      c.quality, c.regime, c.seeded, in_box, c.in_seg_at_baseline, in_seg, in_cap,
      c.made_at_baseline, out_box, c.out_seg_at_baseline, out_seg, out_cap)
    local taken_total = (c.seeded + c.in_seg_at_baseline) - (in_box + in_seg)
    local made_total  = (out_box + out_seg) - (c.made_at_baseline + c.out_seg_at_baseline)
    local taken_box   = c.seeded - in_box
    local made_box    = out_box - c.made_at_baseline
    say("seg    %-10s %-5s in total taken %.10g (x%.10g of the box's)   out total made %.10g "
      .. "(x%.10g of the box's)   made/taken, totals = %.10g",
      c.quality, c.regime, taken_total, taken_box ~= 0 and taken_total / taken_box or 0,
      made_total, made_box ~= 0 and made_total / made_box or 0,
      taken_total ~= 0 and made_total / taken_total or 0)
  end

  -- THE TWO MODELS AGAINST THE GAME, every tick from the seed (#553). `rule` is #531's rule in
  -- doubles, and the row says where the game first leaves it and by how much. `fixed` is the
  -- variant fitted to this trace, and the row says how many ticks it missed and what it says the
  -- box gave over the run, in 2^-24 units, beside what the game's box gave.
  for _, c in ipairs(cells) do
    if c.model_tick > 0 then
      local f = c.rule_first
      say("model  %-10s %-5s rule: %s; largest box difference %.10g at tick %d",
        c.quality, c.regime,
        f and string.format("first leaves the game at tick %d, box %.17g in the game and %.17g in "
          .. "the rule, %.10g apart", f.tick, f.game, f.model, f.model - f.game) or "never leaves the game",
        c.rule_worst.diff, c.rule_worst.tick)
      local g = c.fixed_first
      say("model  %-10s %-5s fixed: missed %d of %d ticks%s; box gave %.10g units of 2^-24 from tick "
        .. "%d, the game's box %.10g", c.quality, c.regime, c.fixed_misses, c.model_tick,
        g and string.format(", first at tick %d (box %.17g in the game, %.17g in the model)",
          g.tick, g.game, g.model) or "",
        c.fixed_at_baseline - c.fixed.box, BASELINE_TICKS,
        (c.seeded - (c.entity.fluidbox[1] and c.entity.fluidbox[1].amount or 0)) / ULP32)
    end
  end

  -- The powered control. A subject that never ran would report a leak of zero, which is exactly
  -- what the hot rows are supposed to report -- so the two are told apart here rather than by hope.
  for _, c in ipairs(cells) do
    local input = c.entity.fluidbox[1]
    say("cell   %-10s %-5s buffer=%.10g J  plasma=%.10g C  network=%s",
      c.quality, c.regime, c.entity.energy, input and input.temperature or -1,
      tostring(c.entity.electric_network_id))
  end

  say("done")
end

-- The first few seconds of one cell's input box, printed as a curve.
--
-- IT EXISTS BECAUSE THE FIRST RUN LOST HALF THE BOX AND COULD NOT SAY WHEN. Every cell was seeded
-- to the box's declared volume of 1000 and read back 526.3158 at the end -- the same figure at every
-- quality and in both temperature regimes, so not the conversion under test. A rig that cannot say
-- whether that went in one tick or over the run cannot tell a seeding artefact from a leak.
--
-- SINCE #553 IT READS EVERY TICK, TO SEVENTEEN DIGITS, for the normal and the legendary cold cell:
-- the input box, its segment and the output box. The normal one is the lone box nothing drains, the
-- legendary one the only cell that converts, so the pair is where a tick-by-tick rule is checked
-- against the game -- each row is enough to predict the next.
--
-- AND IT RUNS TWO MODELS OF THE BOX AND ITS SEGMENT BESIDE THE GAME, from the seed, every tick of
-- the run. `rule` is docs/research/exchanger-coverage.md's box/segment rule (#531) in doubles. `fixed`
-- is a variant FITTED to this trace (#553): every amount an integer count of 2^-24 units, a fill that
-- count over the volume FLOORED to a whole one, a transfer 100 times the smaller of the source's fill
-- and one minus the destination's, and the boiler's draw taken off the box before the push. Neither
-- model is told what the game holds after the seed; the only game reading either takes is the draw,
-- which is the output box's gain that tick. Neither carries the rule's 0.1-unit floor or its bounds on
-- source and room, since no transfer here comes near them.
local ONE = 2 ^ -24
local UNITS = 2 ^ 24

local function traced(c)
  return c.regime == "cold" and (c.quality == "normal" or c.quality == "legendary")
end

local function rule_flow(a, av, b, bv) return 100 * math.min(a / av, 1 - b / bv) end
local function fixed_flow(a, av, b, bv)
  return 100 * math.min(math.floor(a / av), UNITS - math.floor(b / bv))
end

--- One tick of a model: the draw off the box, the box's push, then its pull on the fills the push left.
local function model_step(m, flow, V, C, draw)
  m.box = m.box - draw
  local push = flow(m.box, V, m.seg, C)
  m.box, m.seg = m.box - push, m.seg + push
  local pull = flow(m.seg, C, m.box, V)
  m.box, m.seg = m.box + pull, m.seg - pull
end

--- Brings a traced cell's two models up to the current tick and compares them with the game.
-- Called from the tick handler and from report(), whichever runs first on the report tick.
local function advance(c)
  local tick = game.tick
  if c.model_tick >= tick then return end
  c.model_tick = tick
  local out = c.entity.fluidbox[2]
  local out_amount = out and out.amount or 0
  local draw = out_amount - c.model_out
  c.model_out = out_amount
  local box = c.entity.fluidbox[1]
  local game_box, game_seg = box and box.amount or 0, (segment_of(c.entity, 1))
  local V, C = storage.fill, c.seg_capacity
  model_step(c.rule, rule_flow, V, C, draw)
  model_step(c.fixed, fixed_flow, V, C, draw * UNITS)
  local rd = c.rule.box - game_box
  if rd ~= 0 or c.rule.seg ~= game_seg then
    c.rule_first = c.rule_first or { tick = tick, game = game_box, model = c.rule.box }
  end
  if math.abs(rd) > c.rule_worst.diff then c.rule_worst = { diff = math.abs(rd), tick = tick } end
  if c.fixed.box ~= game_box * UNITS or c.fixed.seg ~= game_seg * UNITS then
    c.fixed_misses = c.fixed_misses + 1
    c.fixed_first = c.fixed_first or { tick = tick, game = game_box, model = c.fixed.box * ONE }
  end
  if tick == BASELINE_TICKS then c.fixed_at_baseline = c.fixed.box end
end

script.on_nth_tick(1, function()
  local tick = game.tick
  if not storage.cells then return end
  for _, c in ipairs(storage.cells) do
    if traced(c) then
      advance(c)
      if tick <= TRACE_TICKS then
        local box, out = c.entity.fluidbox[1], c.entity.fluidbox[2]
        say("trace  tick %-6d %-10s %-5s box=%.17g segment=%.17g out=%.17g temperature=%.10g",
          tick, c.quality, c.regime, box and box.amount or -1, (segment_of(c.entity, 1)),
          out and out.amount or 0, box and box.temperature or -1)
      end
    end
  end
end)

script.on_nth_tick(60, function()
  local tick = game.tick

  -- Once a second, for the whole run. A cell that loses its substation stops converting from that
  -- moment, and the sooner the run stops the less time there is for the reading to look plausible.
  for _, c in ipairs(storage.cells) do assert_intact(c) end

  -- The baseline, once the seeding has relaxed. Everything the report calls "taken" or "made" is
  -- measured from here, not from what was written at tick zero.
  if not storage.based then
    if tick < BASELINE_TICKS then return end
    storage.based = true
    for _, c in ipairs(storage.cells) do
      local input, output = c.entity.fluidbox[1], c.entity.fluidbox[2]
      c.seeded = input and input.amount or 0
      c.made_at_baseline = output and output.amount or 0
      c.in_seg_at_baseline  = segment_of(c.entity, 1)
      c.out_seg_at_baseline = segment_of(c.entity, 2)
    end
    return
  end

  if storage.reported or tick < BASELINE_TICKS + RUN_TICKS then return end
  storage.reported = true
  for _, c in ipairs(storage.cells) do
    if traced(c) then advance(c) end
  end
  report()
end)
'@
$lua = $lua.
    Replace('__QUIETMAP__', (Get-QuietMapLua)).
    Replace('__QUIETFN__', $script:QuietMapFunction).
    Replace('__RUN_TICKS__', "$($Seconds * 60)").
    Replace('__TRACE_TICKS__', "$TraceTicks")
Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') -Value $lua

$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    New-ModJunctions -ModDirectory $modDir -Links (Get-ModLinks -Root $repoRoot -Mods $ourMods)
    $enabled = Resolve-BundledSelection -Requested @('quality') -Bundled $bundled
    Write-Host "bundled enabled: $($enabled -join ', ')"
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabled -Mods ($ourMods + $rigName)

    $save = Join-Path $temp 'quality-leak.zip'
    Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create' | Out-Null
    $runOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        # The run length, plus the rig's own five-second baseline pass, plus two seconds of slack
        # for the report tick landing on the next multiple of sixty.
        '--benchmark', $save, '--benchmark-ticks', "$($Seconds * 60 + 300 + 120)",
        '--benchmark-runs', '1', '--disable-audio')

    $reported = @(Get-Content $runOut | Select-String -Pattern 'QLPROBE ' |
        ForEach-Object { ($_ -split 'QLPROBE ', 2)[1].TrimEnd() })
    if ($reported.Count -eq 0) { throw 'the rig reported nothing; it never reached its report tick.' }

    foreach ($line in $reported) { Write-Host "  $line" }

    # The sentinel, for the same reason every rig here checks for one: a rig that died part way
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
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'probe-quality-leak' }
}

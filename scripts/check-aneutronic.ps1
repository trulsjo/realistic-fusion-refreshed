#Requires -Version 7
<#
.SYNOPSIS
    Checks that the aneutronic tier works end to end: a second reactor burns D-He3 and He3-He3, and
    a direct energy converter turns what it sells into electricity with no steam anywhere on the
    map. Discharges #31.

.DESCRIPTION
    tests/test-reactor-logic.lua asserts the physics outside Factorio. This asserts that the physics
    reaches a reactor and the electricity reaches a network -- which for this tier is a larger claim
    than for the last one, because #31 adds a second reactor prototype and everything that used to
    know one reactor's name now has to know two.

    THE THINGS MOST LIKELY TO BE WRONG

    A second reactor means control.lua looks up which constants to simulate an entity with, and
    apply() writes whichever energy fluid that spec names. Get either wrong and the mod loads
    perfectly: a reactor simulated with the wrong spec looks like a balance problem, and a reactor
    writing the wrong fluid into a filtered box produces nothing at all while reporting itself
    healthy. Neither is visible without running one of each side by side, which is what this does.

    And the tier's whole claim is that electricity arrives without a steam loop. That is asserted
    negatively as well as positively -- the rig builds no boiler, no heat exchanger and no turbine,
    and checks that none exists and that not a unit of steam is on the map.

    WHAT IS BUILT

      dhe3      An rf-aneutronic-reactor fed rf-d-he3-plasma. It must fuse, ignite to the top of
                the plasma's range, and sell rf-aneutronic-reactor-energy -- not the neutronic
                fluid.
      converter An rf-direct-energy-converter plumbed to that reactor's output box, with nothing
                between them. It must consume the fluid and put power on the network, measured as
                its own contribution rather than the network's total, because the reactor's heating
                is supplied by an energy interface on the same network.
                A SECOND converter sits behind the first, because a row is how a player lays these
                and the prototype could not do it until it was probed in game: its fluid box
                declared flow_direction = "input" where vanilla's steam turbine declares
                "input-output", so two of them back to back did not connect at all and every one
                after the first sat dry with nothing on screen to say why.
      he3he3    The same reactor prototype on rf-he3-he3-plasma. It must fuse and sell. HOW MUCH
                weaker it is than D-He3 is deliberately not bounded here: this rig runs two minutes
                and He3-He3 takes about twenty to reach its equilibrium, so every figure it could
                compare would be a point on the way up. That comparison belongs in
                tests/test-reactor-logic.lua, which settles both and finds Q 1.31 against 82.8.
      dd, dt    An rf-reactor on each of the neutronic plasmas, so all four of ADR 0010's reactions
                are burning in one save. The pair is also the control on the two-reactor split: the
                neutronic reactor must still sell rf-reactor-energy, which is what a spec lookup
                gone wrong would break.
      collector An rf-isotope-collector bolted to the aneutronic reactor. It must stay EMPTY: both
                aneutronic reactions breed nothing and release no neutrons, which is the property
                the tier is named for.
      heaters   An rf-heater on each aneutronic plasma -- one from Core's rf-d-he3-mix, one from
                bare rf-helium-3, which is the only plasma in the mod made without a mixing step.
      tank      An rf-aneutronic-composite-tank, which must accept the tier's energy fluid.

    The technology gate is checked without building anything, off the force's own technology and
    recipe tables, before research_all_technologies is called.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Ticks
    Ticks to run before checking. Kept in step with check-d-t.ps1 so the two are comparable.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/check-aneutronic.ps1
#>
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [ValidateRange(600, 200000)] [int] $Ticks = 7200,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$rigName  = 'rf-aneutronic-rig'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-an-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

function Write-Rig {
    @{
        name = $rigName; version = '0.0.1'; title = 'Aneutronic tier check'
        author = 'check-aneutronic.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed', 'realistic-fusion-refreshed-core')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

    $feed = Write-PlasmaFeed -RigDirectory $rigDir

    $lua = @'
-- Generated by scripts/check-aneutronic.ps1. Nothing here ships.

local CHECK_AT = __TICKS__

local DD     = "rf-d-d-plasma"
local DT     = "rf-d-t-plasma"
local DHE3   = "rf-d-he3-plasma"
local HE3    = "rf-he3-he3-plasma"
local FEED   = "__PLASMAFEED__"

local NEUTRONIC_ENERGY  = "rf-reactor-energy"
local ANEUTRONIC_ENERGY = "rf-aneutronic-reactor-energy"

local REACTOR    = "rf-reactor"
local ANEUTRONIC = "rf-aneutronic-reactor"
local CONVERTER  = "rf-direct-energy-converter"

-- The temperature every cell is fed at. Roughly where the neutronic reactor settles on D-D, so the
-- comparison across four reactions starts them all from a place D-D can actually reach.
local BOTH_AT = 6e8

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

local function holds(entity, fluid)
  local total = 0
  for index = 1, #entity.fluidbox do
    local contents = entity.fluidbox[index]
    if contents and contents.name == fluid then total = total + contents.amount end
  end
  return total
end

local function box_of(entity, fluid)
  for index = 1, #entity.fluidbox do
    local filter = entity.fluidbox.get_filter(index)
    if filter and filter.name == fluid then return index end
  end
  return nil
end

--- Power, sized for whichever reactor it is feeding. The aneutronic one wants 200 MW of confinement
--- heating against the neutronic one's 50, so a single figure would either starve it or say nothing.
--- Returns the substation, because flow statistics are read off a POLE and nothing else. That is
--- not obvious from the name -- electric_network_statistics is on LuaEntity, so asking a generator
--- for its own network's statistics looks reasonable and answers "Entity is not electric-pole."
local function power(surface, force, at, watts)
  local pole = must(surface.create_entity({
    name = "substation", position = at, force = force,
  }), "substation")
  local eei = must(surface.create_entity({
    name = "electric-energy-interface", position = { at[1] + 2.5, at[2] + 0.5 }, force = force,
  }), "power source")
  eei.power_production = watts
  return pole
end

--- A reactor of either kind on a plasma feed, at `ox`.
---
--- Geometry is read off the prototypes rather than written down: #49 is what happens when a rig
--- remembers a machine's size and the machine changes. The two reactors are different sizes and sit
--- on different grid alignments -- fifteen tiles is odd and lands on tile centres, ten is even and
--- lands on corners -- so even the y coordinate has to come from the prototype rather than a
--- constant.
local function reactor_at(surface, force, name, ox, plasma)
  local box = prototypes.entity[name].selection_box
  -- An even-sized entity sits on a tile corner and an odd-sized one on a tile centre. The width in
  -- tiles is what decides which, and it is right here on the prototype.
  local width = box.right_bottom.x - box.left_top.x
  local offset = (math.floor(width + 0.5) % 2 == 0) and 0 or 0.5
  local reactor = must(surface.create_entity({
    name = name, position = { ox + offset, offset }, force = force, raise_built = true,
  }), name)
  local west = reactor.fluidbox.get_pipe_connections(1)[1].target_position
  local feed = must(surface.create_entity({
    name = FEED, position = { west.x, west.y }, force = force,
  }), "plasma feed")
  feed.set_infinity_pipe_filter({
    name = plasma, percentage = 1, temperature = BOTH_AT, mode = "at-least",
  })
  return reactor
end

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player

  -- ------------------------------------------------------------------ the technology gate
  --
  -- Read before research_all_technologies, which is the only moment the locked state exists.
  local breeding  = force.technologies["rf-helium-3-breeding"]
  local direct    = force.technologies["rf-direct-energy-conversion"]
  local aneutronic = force.technologies["rf-aneutronic-fusion"]
  record(breeding ~= nil and direct ~= nil and aneutronic ~= nil,
    "all three gating technologies exist")
  if breeding and direct and aneutronic then
    record(direct.prerequisites["rf-helium-3-breeding"] ~= nil,
      "direct energy conversion follows helium-3 breeding")
    record(aneutronic.prerequisites["rf-direct-energy-conversion"] ~= nil,
      "and aneutronic fusion follows the converter that drinks its output")
    record(aneutronic.prerequisites["rf-d-t-fusion"] ~= nil,
      "and the tier before it, so the progression is a line rather than a branch")
    -- Core's, and the direction ADR 0010 allows: Power may depend on Core, never the reverse.
    record(aneutronic.prerequisites["rf-gas-mixing"] ~= nil,
      "and the mixer that makes half its fuel")
    record(breeding.prerequisites["rf-tritium-breeding"] ~= nil,
      "and helium-3 breeding follows the collector that produces the helium-3")
  end
  for _, recipe in ipairs({ "rf-d-he3-plasma", "rf-he3-he3-plasma", ANEUTRONIC, CONVERTER,
                            "rf-aneutronic-composite-tank" }) do
    record(not force.recipes[recipe].enabled, recipe .. " is locked until it is researched")
  end

  -- THE PREREQUISITE CLOSURE, which #30 broke and scripts/check-blanket.ps1 started enforcing.
  -- Every item a technology's recipes consume, and every science pack its own research asks for,
  -- has to be reachable inside that technology's OWN prerequisites -- or a player researches it
  -- and cannot build what it unlocks, or cannot finish the research at all.
  --
  -- PER TECHNOLOGY, NOT PER TIER, and the difference is the whole check rather than a refinement.
  -- The first version researched rf-aneutronic-fusion's closure once -- which marks all three of
  -- the tier's technologies researched, since they are each other's prerequisites -- and then asked
  -- its questions against that combined state. So a pack or an ingredient supplied by a SIBLING
  -- technology passed: move production-science-pack off rf-direct-energy-conversion and onto
  -- rf-aneutronic-fusion and a player can reach the first with no way to craft its packs, while the
  -- rig still reports every closure holding. That is the exact bug this check was added for, and it
  -- could not have caught it.
  --
  -- So each technology is asked in isolation: every technology unresearched, then only ITS
  -- prerequisites researched, then its own recipes and its own unit examined. The technology under
  -- test is deliberately NOT researched -- what is being asked is what a player has in hand when it
  -- becomes available, and researching it would let its own unlocks answer for themselves.
  local function research_closure(name, seen)
    if seen[name] then return end
    seen[name] = true
    local tech = force.technologies[name]
    if not tech then return end
    for prerequisite in pairs(tech.prerequisites) do research_closure(prerequisite, seen) end
    tech.researched = true
  end

  local function isolate(name)
    for _, tech in pairs(force.technologies) do tech.researched = false end
    local tech = force.technologies[name]
    if not tech then return end
    local seen = {}
    for prerequisite in pairs(tech.prerequisites) do research_closure(prerequisite, seen) end
  end

  -- BARRELS ARE NOT A SOURCE, and leaving them in made an earlier version of this vacuous in a way
  -- that hid completely. Core's fluids barrel by default, so every one of them has an enabled
  -- empty-<fluid>-barrel recipe listing it as a product: ask "does an enabled recipe produce this"
  -- without excluding them and the answer is yes for every fluid in the game, whatever the
  -- technology tree says.
  --
  -- Found by negative-testing rather than by reading: with rf-gas-mixing removed the check still
  -- reported "closure holds", and reported that NOTHING was unproduced -- which is what gave it
  -- away, since rf-helium-3 has no recipe at all and should have been counted.
  --
  -- Excluded by subgroup rather than by name, because the name pattern is a convention and the
  -- subgroup is what the engine actually files them under.
  local BARRELLING = { ["fill-barrel"] = true, ["empty-barrel"] = true }

  local function producers(name)
    local found = {}
    for _, recipe in pairs(force.recipes) do
      local subgroup = recipe.subgroup and recipe.subgroup.name
      if not (subgroup and BARRELLING[subgroup]) then
        for _, product in pairs(recipe.products or {}) do
          if product.name == name then found[#found + 1] = recipe end
        end
      end
    end
    return found
  end

  -- Which recipes each technology unlocks, read off the technology rather than written down, so a
  -- recipe moved between technologies is checked against wherever it actually ended up.
  -- Off the PROTOTYPE, not off the force's LuaTechnology, which has no effects key at all -- the
  -- force's object is the researched state and the prototype is what the technology does.
  local function unlocked_by(tech)
    local recipes = {}
    for _, effect in pairs(tech.prototype.effects or {}) do
      if effect.type == "unlock-recipe" then recipes[#recipes + 1] = effect.recipe end
    end
    return recipes
  end

  local outside, checked, unproduced = {}, 0, 0
  for _, name in ipairs({ "rf-helium-3-breeding", "rf-direct-energy-conversion",
                          "rf-aneutronic-fusion" }) do
    local tech = force.technologies[name]
    if tech then
      isolate(name)
      for _, recipe_name in ipairs(unlocked_by(tech)) do
        for _, ingredient in pairs(prototypes.recipe[recipe_name].ingredients) do
          local made_by = producers(ingredient.name)
          if #made_by == 0 then
            -- Nothing produces it at all. rf-helium-3 is the case: it comes out of the simulation
            -- rather than out of a recipe, so there is no closure question to answer. Counted
            -- rather than passed, because a check that answered nothing would look like one that
            -- answered everything.
            unproduced = unproduced + 1
          else
            checked = checked + 1
            local reachable = false
            for _, recipe in ipairs(made_by) do
              if recipe.enabled then reachable = true break end
            end
            if not reachable then
              outside[#outside + 1] = name .. "'s " .. recipe_name .. " needs " .. ingredient.name
            end
          end
        end
      end

      -- THE SAME RULE ONE LAYER OUT: the science packs the technology's own unit asks for.
      --
      -- A technology becomes available when its prerequisites are researched, and Factorio does not
      -- care whether the player can MAKE its packs. So a technology asking for a pack outside its
      -- own closure shows up as available, gets queued, and never completes -- with no edge
      -- anywhere in the tree to explain it. That is worse than an unbuildable machine, because
      -- there is nothing to look at. The first version of this tier did exactly that with
      -- production science.
      for _, ingredient in pairs(tech.research_unit_ingredients) do
        local made_by = producers(ingredient.name)
        if #made_by > 0 then
          checked = checked + 1
          local reachable = false
          for _, recipe in ipairs(made_by) do
            if recipe.enabled then reachable = true break end
          end
          if not reachable then
            outside[#outside + 1] = name .. " asks for " .. ingredient.name
          end
        end
      end
    end
  end

  record(#outside == 0,
    "every technology's ingredients and science packs are reachable inside its own prerequisites",
    #outside == 0
      and string.format("%d reachable, %d have no recipe at all (bred, not crafted)",
        checked, unproduced)
      or table.concat(outside, "; "))
  -- A closure check that looked at nothing would pass. This is what says it did not.
  record(checked >= 20, "and the closure check actually looked at all three technologies",
    string.format("%d checked", checked))

  force.research_all_technologies()

  surface.request_to_generate_chunks({ 0, 0 }, 10)
  surface.force_generate_chunk_requests()
  local tiles = {}
  for x = -200, 160 do
    for y = -40, 40 do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = { { -200, -40 }, { 160, 40 } } })) do
    if e.type ~= "character" then e.destroy() end
  end

  -- ------------------------------------------------------------------ the aneutronic reactor
  local dhe3 = reactor_at(surface, force, ANEUTRONIC, 0, DHE3)
  local dhe3_pole = power(surface, force, { 10, 0 }, 3e8)

  -- ------------------------------------------------------------------ the converter
  --
  -- Plumbed straight onto the reactor's output box with nothing between them, which is the whole
  -- claim of the tier: reactor to electricity, one machine, no steam. The position is computed from
  -- the two prototypes' own connection geometry rather than written down -- if it is wrong the
  -- converter simply gets no fluid, and the check below says so.
  local out_connection = dhe3.fluidbox.get_pipe_connections(2)[1]

  -- ROTATED, AND THAT IS THE POINT OF THE SHAPE. #45 moved this machine's connections onto its long
  -- faces, so that butted against a reactor it touches along its whole fifteen tiles instead of at
  -- one tile. The reactor sells its energy through its NORTH face, so the converter has to lie
  -- sideways for a long face to meet it -- which is the arrangement the original mod had, with a
  -- 5x15 exchanger flush along its reactor.
  --
  -- Turned west rather than east: a quarter turn anticlockwise sends the west-facing connection to
  -- (0, +reach) pointing south, which is the one that can meet a north-facing output. Turning it the
  -- other way puts that connection on the far side and it meets nothing.
  --
  -- Both offsets come off the prototype rather than being written down, because they were written
  -- down once and the machine outgrew them twice: three by five when this rig was built, then five
  -- by fifteen, and a hardcoded number failed loudly each time.
  local converter_box = prototypes.entity[CONVERTER].selection_box
  local converter_short = converter_box.right_bottom.x - converter_box.left_top.x
  local converter_reach = converter_short / 2 - 0.5

  local converter = must(surface.create_entity({
    name = CONVERTER,
    direction = defines.direction.west,
    -- Its south-facing connection has to land on the tile the reactor's output points at.
    position = { out_connection.target_position.x, out_connection.target_position.y - converter_reach },
    force = force, raise_built = true,
  }), CONVERTER)

  -- A SECOND CONVERTER BEHIND THE FIRST, which is how a player lays a row of them because it is how
  -- steam turbines have always been laid. It exists because the first version of this prototype
  -- could not do it: the fluid box declared flow_direction = "input" where vanilla's steam turbine
  -- declares "input-output", so two converters back to back did not connect at all and every one
  -- after the first sat dry with nothing on screen to say why. Found on review by probing it in
  -- game, which is the only way it could have been found.
  --
  -- One machine-depth further out, in the same rotation, so the second one's south connection lands
  -- exactly on the first one's north. A row of these stacks away from the reactor, which is how a
  -- row of steam turbines has always been laid. Read off the prototype for the reason above.
  local second_converter = must(surface.create_entity({
    name = CONVERTER,
    direction = defines.direction.west,
    position = { converter.position.x, converter.position.y - converter_short },
    force = force, raise_built = true,
  }), "second " .. CONVERTER)
  -- Its own supply area. Without it the machine sits full of fluid reporting
  -- "not_plugged_in_electric_network", which proves the plumbing and nothing about the machine.
  power(surface, force, { 6, -12 }, 3e8)

  -- ------------------------------------------------------------------ he3-he3
  local he3 = reactor_at(surface, force, ANEUTRONIC, -60, HE3)
  power(surface, force, { -50, 0 }, 3e8)

  -- ------------------------------------------------------------------ the neutronic control
  --
  -- All four of ADR 0010's reactions burning in one save, and the check that the two-reactor split
  -- did not break the tier that already worked.
  local dd = reactor_at(surface, force, REACTOR, -120, DD)
  power(surface, force, { -106, 0 }, 8e6)
  local dt = reactor_at(surface, force, REACTOR, -170, DT)
  power(surface, force, { -156, 0 }, 8e6)

  -- ------------------------------------------------------------------ collector on the aneutronic
  --
  -- Flush against its south face. It must stay empty: both aneutronic reactions breed nothing.
  local rbox = prototypes.entity[ANEUTRONIC].selection_box
  local cbox = prototypes.entity["rf-isotope-collector"].selection_box
  local collector = must(surface.create_entity({
    name = "rf-isotope-collector",
    position = {
      dhe3.position.x,
      dhe3.position.y + rbox.right_bottom.y + (cbox.right_bottom.y - cbox.left_top.y) / 2,
    },
    force = force, direction = defines.direction.south, raise_built = true,
  }), "rf-isotope-collector")

  -- ------------------------------------------------------------------ the two heaters
  local heaters = {}
  for index, pair in ipairs({ { "rf-d-he3-plasma", "rf-d-he3-mix" },
                              { "rf-he3-he3-plasma", "rf-helium-3" } }) do
    local heater = must(surface.create_entity({
      name = "rf-heater", position = { 80.5 + index * 12, 0.5 }, force = force,
    }), "rf-heater")
    heater.set_recipe(pair[1])
    -- Beside the heater, not above it. A substation supplies an 18x18 area centred on itself, so
    -- one twelve tiles north of a three-tile machine powers nothing at all -- which the rig
    -- reported as "status no_power" rather than as a placement mistake, because from the heater's
    -- point of view those are the same thing.
    power(surface, force, { 80 + index * 12, 6 }, 8e6)
    local box = box_of(heater, pair[2])
    if not box then error("the heater has no box that will take " .. pair[2]) end
    for _, connection in pairs(heater.fluidbox.get_pipe_connections(box)) do
      local supply = must(surface.create_entity({
        name = "infinity-pipe", position = connection.target_position, force = force,
      }), "supply for " .. pair[2])
      supply.set_infinity_pipe_filter({ name = pair[2], percentage = 1, mode = "at-least" })
    end
    heaters[pair[1]] = heater
  end

  -- ------------------------------------------------------------------ the tank
  local tank = must(surface.create_entity({
    name = "rf-aneutronic-composite-tank", position = { 130.5, 0.5 }, force = force,
  }), "rf-aneutronic-composite-tank")
  tank.insert_fluid({ name = ANEUTRONIC_ENERGY, amount = 100 })

  storage.rig = {
    dhe3 = dhe3, he3 = he3, dd = dd, dt = dt,
    converter = converter, second_converter = second_converter,
    collector = collector, tank = tank, heaters = heaters,
    pole = dhe3_pole,
  }
  storage.sold = { dhe3 = 0, he3 = 0, dd = 0, dt = 0 }
  storage.wrong_fluid = { dhe3 = 0, he3 = 0, dd = 0, dt = 0 }
  -- The most the converter has ever held at once. A running total of what it consumed cannot be
  -- taken by watching the box -- the reactor refills it in the same tick the converter drains it,
  -- so the two are indistinguishable from outside. What this does establish is that the reactor's
  -- fluid actually reached the converter, which is the half the electricity figure cannot prove on
  -- its own: a converter with an empty box generates nothing, so power on the network plus fluid in
  -- the box is the pair that says the plumbing works.
  storage.converter_held = 0
  log("AN-RIG built")
end)

-- Drain the reactors that have no converter on them, and keep the running total.
--
-- The D-He3 reactor is deliberately NOT drained: its output box feeds the converter, and draining it
-- would take away the very fluid the converter is meant to be burning. Its energy is accounted for
-- through the converter instead.
--
-- Every reactor is also watched for the WRONG energy fluid, which is the failure a spec lookup or an
-- energy_fluid typo would produce: apply() writing rf-reactor-energy into a box filtered to the
-- aneutronic one is a rejected write, so the box stays empty and the reactor looks merely idle.
script.on_event(defines.events.on_tick, function()
  local r = storage.rig
  if not r then return end
  local expected = {
    dhe3 = ANEUTRONIC_ENERGY, he3 = ANEUTRONIC_ENERGY,
    dd = NEUTRONIC_ENERGY, dt = NEUTRONIC_ENERGY,
  }
  for key, reactor in pairs({ dhe3 = r.dhe3, he3 = r.he3, dd = r.dd, dt = r.dt }) do
    local produced = reactor.fluidbox[2]
    if produced then
      if produced.name ~= expected[key] then
        storage.wrong_fluid[key] = storage.wrong_fluid[key] + produced.amount
      end
      if key ~= "dhe3" then
        storage.sold[key] = storage.sold[key] + produced.amount
        reactor.fluidbox[2] = nil
      end
    end
  end
  local held = r.converter.fluidbox[1]
  if held and held.amount > storage.converter_held then
    storage.converter_held = held.amount
  end
end)

script.on_nth_tick(CHECK_AT, function()
  if game.tick == 0 or storage.done then return end
  storage.done = true
  local r = storage.rig

  -- ------------------------------------------------------------ the aneutronic reactor burns
  local plasma = r.dhe3.fluidbox[1]
  record(plasma ~= nil and plasma.name == DHE3, "the aneutronic reactor accepts D-He3 plasma",
    plasma and plasma.name or "nothing in the box")

  local ceiling = prototypes.fluid[DHE3].max_temperature
  record(plasma ~= nil and plasma.temperature >= ceiling * 0.999,
    "and ignites: the plasma runs up to the top of its range and parks there",
    plasma and string.format("%.4g C against a ceiling of %.4g", plasma.temperature, ceiling) or "no plasma")

  -- ------------------------------------------------------------ each reactor sells its own fluid
  --
  -- The failure a second spec makes available, and the one that would otherwise be silent: a
  -- reactor writing the other tier's energy fluid into its own filtered box produces nothing at all
  -- while reporting itself perfectly healthy.
  local crossed = 0
  for _, amount in pairs(storage.wrong_fluid) do crossed = crossed + amount end
  record(crossed == 0, "no reactor ever wrote the other tier's energy fluid into its box",
    string.format("%.6g units of the wrong fluid seen across four reactors", crossed))

  local an_out = r.dhe3.fluidbox[2]
  record(an_out ~= nil and an_out.name == ANEUTRONIC_ENERGY,
    "the aneutronic reactor sells aneutronic reactor energy",
    an_out and an_out.name or "nothing in its output box")

  -- ------------------------------------------------------------ electricity, with no steam
  --
  -- Measured as the converter's OWN contribution rather than the network's total, because the
  -- reactor's confinement heating is supplied by an energy interface on the same network and would
  -- otherwise be counted as generation.
  -- The flow figure is a smoothed RATE out of Factorio's own production statistics, not a total
  -- joule count, and it is reported without units for that reason -- the useful content is that it
  -- is attributed to this prototype and is not zero. The converter's status is asserted beside it
  -- because a generator with no fuel also reports zero, and the two together say which it is.
  local produced = 0
  local statistics = r.pole.electric_network_statistics
  if statistics then
    produced = statistics.get_flow_count({
      name = CONVERTER, category = "output",
      precision_index = defines.flow_precision_index.one_minute,
    }) or 0
  end
  local converter_status = "unknown"
  for name, value in pairs(defines.entity_status) do
    if value == r.converter.status then converter_status = name end
  end
  record(produced > 0 and r.converter.status == defines.entity_status.working,
    "the direct energy converter puts power on the network",
    string.format("flow attributed to it %.4g, status %s", produced, converter_status))
  record(storage.converter_held > 0, "and it does so on the reactor's output, plumbed straight in",
    string.format("%.6g units of %s reached its box", storage.converter_held, ANEUTRONIC_ENERGY))

  -- CONVERTERS CHAIN, which is the layout every player will reach for and which this prototype
  -- silently could not do until it was probed in game. Asked of the engine's own connection state
  -- rather than inferred from the second machine running: a converter that happened to be fed some
  -- other way would hide exactly the failure being tested for.
  -- get_connections, which hands back the fluid boxes actually joined to this one. Two other ways
  -- of asking were tried first and both lied: connection.target.owner answers nil, and
  -- connection.connected answers false on every connection of a machine that is visibly passing
  -- fluid to its neighbour. Neither is a statement about whether the pipes meet.
  --
  -- This converter has exactly two chances to have a neighbour: the reactor below it and the second
  -- converter above.
  local joined = 0
  for index = 1, #r.converter.fluidbox do
    joined = joined + #r.converter.fluidbox.get_connections(index)
  end
  record(joined >= 2, "two converters laid back to back join, the way a row of turbines does",
    string.format("%d of the first converter's connections are joined -- reactor below, " ..
      "converter above", joined))

  local second_status = "unknown"
  for name, value in pairs(defines.entity_status) do
    if value == r.second_converter.status then second_status = name end
  end
  -- And it is fed, which is the half that matters: its only possible source is the machine in front
  -- of it, so fluid in this box is fluid that crossed the join.
  local passed = holds(r.second_converter, ANEUTRONIC_ENERGY)
  record(passed > 0 and r.second_converter.status == defines.entity_status.working,
    "and the second one runs on fluid passed through the first",
    string.format("status %s, holding %.6g", second_status, passed))

  -- The negative half, and the reason the tier is mechanically different rather than numerically
  -- bigger: nothing anywhere on this map boils anything.
  local steam_machines = game.surfaces[1].count_entities_filtered({
    name = { "rf-heat-exchanger", "steam-turbine", "boiler", "steam-engine" },
  })
  record(steam_machines == 0, "and there is no steam machinery anywhere on the map",
    string.format("%d boilers, exchangers or turbines", steam_machines))

  -- ------------------------------------------------------------ He3-He3 burns, and is weaker
  local he3_plasma = r.he3.fluidbox[1]
  record(he3_plasma ~= nil and he3_plasma.name == HE3,
    "the same reactor prototype accepts He3-He3 plasma",
    he3_plasma and he3_plasma.name or "nothing in the box")
  record(storage.sold.he3 > 0, "and sells real energy on it",
    string.format("%.4g MJ over the run", storage.sold.he3))

  -- Reported rather than bounded, and the distinction is deliberate: how much weaker He3-He3 is
  -- than D-He3 is physics, and tests/test-reactor-logic.lua asserts it against the dataset where it
  -- can be checked against the cross-section it comes from. What this rig is for is that the tier
  -- reaches a reactor at all. The number is logged so a rebalance shows up as a number moving.
  --
  -- Worth knowing while reading it: He3-He3's cross-section peaks past 600 keV and
  -- max_temperature_c stops the plasma at 172, so this reaction runs at about a hundredth of its
  -- peak reactivity and is marginal for that reason rather than through any balance choice.
  -- Its OWN ceiling, not the one bound for D-He3 above. Both plasmas declare 2e9 today, so the
  -- printed number would be accidentally right either way -- and this is the one line a reader
  -- consults to decide whether He3-He3's clamp is where its fuel row says it is, which is exactly
  -- the number that stops being shared the day a tier wants a hotter range.
  local he3_ceiling = prototypes.fluid[HE3].max_temperature
  -- "Climbing", not "settled", and the distinction is measured rather than pedantic: at this rig's
  -- horizon He3-He3 is still on its way up -- it needs about twenty minutes of game time to reach
  -- the clamp, where tests/test-reactor-logic.lua runs it and finds Q 1.31. Calling a transient an
  -- equilibrium is exactly the mistake that block had to have corrected, and it is not going to be
  -- made twice in the same tier.
  record(he3_plasma ~= nil,
    "He3-He3 is climbing toward the clamp, which is far below its cross-section peak",
    he3_plasma and string.format("%.4g C, ceiling %.4g", he3_plasma.temperature, he3_ceiling)
      or "no plasma")

  -- ------------------------------------------------------------ all four reactions in one save
  local burning = {}
  for key, reactor in pairs({ dd = r.dd, dt = r.dt, dhe3 = r.dhe3, he3 = r.he3 }) do
    local held = reactor.fluidbox[1]
    burning[#burning + 1] = string.format("%s=%s", key, held and held.name or "none")
  end
  table.sort(burning)
  local all_four = (r.dd.fluidbox[1] ~= nil) and (r.dt.fluidbox[1] ~= nil)
    and (r.dhe3.fluidbox[1] ~= nil) and (r.he3.fluidbox[1] ~= nil)
  record(all_four, "all four of ADR 0010's reactions are burning in one save",
    table.concat(burning, ", "))
  record(storage.sold.dd > 0 and storage.sold.dt > 0,
    "and the neutronic tier still sells its own fluid, unchanged by the split",
    string.format("D-D %.4g MJ, D-T %.4g MJ", storage.sold.dd, storage.sold.dt))

  -- ------------------------------------------------------------ aneutronic means aneutronic
  local bred = holds(r.collector, "rf-tritium") + holds(r.collector, "rf-helium-3")
  record(bred == 0, "an aneutronic reactor breeds nothing, so its collector stays empty",
    string.format("%.6g units in the collector bolted to it", bred))

  -- ------------------------------------------------------------ the heaters make the fuel
  for plasma_name, heater in pairs(r.heaters) do
    local made = holds(heater, plasma_name)
    local status = "unknown"
    for name, value in pairs(defines.entity_status) do
      if value == heater.status then status = name end
    end
    record(made > 0, "a plasma heater makes " .. plasma_name,
      string.format("%.6g units, status %s", made, status))
  end

  -- ------------------------------------------------------------ the tank holds the tier's fluid
  record(holds(r.tank, ANEUTRONIC_ENERGY) > 0, "the composite tank buffers the tier's energy fluid",
    string.format("%.6g units", holds(r.tank, ANEUTRONIC_ENERGY)))

  local report = storage.report
  report.lines[#report.lines + 1] = string.format("%s: %d checks, %d failures",
    report.failures == 0 and "PASS" or "FAIL", #report.lines, report.failures)
  for _, line in ipairs(report.lines) do log("AN-RIG " .. line) end
end)
'@
    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') `
        -Value $lua.Replace('__PLASMAFEED__', $feed).Replace('__TICKS__', "$Ticks")
}

$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled @() -Mods ($ourMods + $rigName)
    Write-Rig

    $save = Join-Path $temp 'aneutronic.zip'
    Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create' | Out-Null
    $runOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', "$($Ticks + 60)", '--benchmark-runs', '1', '--disable-audio')

    $reported = @(Get-Content $runOut | Select-String -Pattern 'AN-RIG (ok|FAIL|PASS)' |
        ForEach-Object { ($_ -split 'AN-RIG ', 2)[1].TrimEnd() })
    if ($reported.Count -eq 0) { throw 'the rig reported nothing; it never reached its check tick.' }

    foreach ($line in $reported) { Write-Host "  $line" }

    $verdict = $reported | Where-Object { $_ -match '^(PASS|FAIL): ' } | Select-Object -Last 1
    if (-not $verdict)              { throw 'the rig produced no verdict line.' }
    if ($verdict -notmatch '^PASS') { throw "the aneutronic tier is broken: $verdict" }

    Write-Host ''
    Write-Host 'OK - both aneutronic reactions burn, the converter makes electricity, and no steam'
    Write-Host '     machine exists anywhere on the map.'
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'check-aneutronic' }
}

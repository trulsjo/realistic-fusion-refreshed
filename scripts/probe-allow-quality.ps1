<#
.SYNOPSIS
    Probe: what does RecipePrototype.allow_quality = false actually do? The rig #148 asks for.

.DESCRIPTION
    A PROBE, NOT A CHECK. Every line it prints is an observation, and a negative answer is as much
    of a result as a positive one -- so exit 0 means the probe ran and every row reported, never
    that the answer was the one anybody hoped for. Nothing here decides anything and nothing here
    ships. It must not be added to a check sweep, a bench sweep or to load-check.ps1.

    WHAT IT CLOSES

    docs/research/quality.md's option E -- deny quality on the reactors entirely -- rests on one
    sentence about a flag the 2.0.77 docs do not describe. RecipePrototype.allow_quality is declared
    there with a type and a default of `true` and NO description sentence at all. The note's reading
    is assembled from three secondary things: the companion allow_quality_message defaulting to a
    locale key that reads "Quality modules cannot be used on this recipe."; four base-game uses, one
    of them commented "catalyst would be also bumped on quality"; and the property's presence on
    RecipePrototype. Nothing was run.

    This runs it. A design option whose mechanism is inferred from a locale string cannot be chosen
    responsibly, and the note itself says option E would want a check that no quality-module route
    produces an rf-reactor -- which nobody can write until somebody knows what the flag does.

    THE RIG DECLARES ITS OWN RECIPES AND TOUCHES NOTHING THIS MOD SHIPS. Two of them, identical in
    every field except the flag: rfaq-control without it and rfaq-flagged with allow_quality = false.
    A pair rather than one, because "the flagged machine made no legendary chest" means nothing
    unless an otherwise identical machine beside it made some. Modifying a shipped recipe would be
    exercising option E rather than measuring its mechanism, and that choice is Truls's.

    THE FOUR QUESTIONS, in the order option E would need them answered.

      1. IS THE FLAG READABLE AT RUNTIME, AND UNDER WHAT NAME? Asked by trying candidate keys under
         pcall on both LuaRecipePrototype and LuaRecipe rather than by reading the docs, since the
         docs are what is missing. A key the engine does not know raises rather than returning nil,
         so the pcall is the measurement.

      2. IS THE MODULE REFUSED, OR ACCEPTED AND IGNORED? Those are different guarantees and the
         locale string only describes the first. Asked three ways on each machine -- can_insert,
         then insert, then what the module inventory actually holds afterwards -- because an engine
         that accepts and silently drops would answer the first two the same way as one that keeps.

      3. WHAT HAPPENS TO A MACHINE THAT ALREADY HOLDS ONE? A machine of its own is loaded with
         modules against the control recipe and then switched to the flagged one. A player reaches
         this by hand and no base-game use exercises it, so nothing but a run can say whether the
         engine refuses the switch, ejects the modules, or leaves a machine in a state its own rules
         forbid.

         THE SWITCH IS LuaEntity.set_recipe AND NOT A PLAYER'S GUI, which is the limit of what this
         answers. A headless rig has no GUI to drive, and whether the two paths agree about a
         machine's modules is not something this run can say.

      4. DOES IT ACTUALLY STOP THE QUALITY OUTPUT? The machines are fed and left to run, and every
         item they produce is counted BY QUALITY, twice over -- once out of the slots and once out
         of the force's production statistics, which see a craft whether or not the item survived
         to a slot. This is the question the first three only circle: a flag that refuses the module
         and a flag that accepts it and produces normal output are indistinguishable until something
         is crafted.

    A THIRD MACHINE RUNS AN UNTOUCHED VANILLA RECIPE with the same modules, and it is not padding.
    It is the control on the control: an all-normal tally on the flagged machine means nothing
    unless something in the same run promoted. It caught the one thing that would have made this
    whole probe report a confident wrong answer -- see the research line in the rig's on_init.

    AND ONE THE NOTE ALREADY STATES BUT HAS NOT SHOWN: the flag is not absolute. A legendary chest
    is created with create_entity{quality = ...} at the end, so the report says in one line that the
    script route is still open whatever the recipe says.

    QUALITY-MODULE-3 AND FOUR SLOTS, so the effect is large enough to count. Tier 1 would need
    several times the run to separate its rate from zero, and the question here is whether the
    engine produces ANY non-normal output, not what the rate is.

    IT DECIDES NOTHING. Whether this mod should apply the flag is option E and Truls's; CLAUDE.md
    forbids settling it as a side effect of measuring it. The findings go into
    docs/research/quality.md.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Seconds
    Game seconds the three machines are left crafting before the tally. The default of 120 is about
    300 crafts each, at an assembling-machine-3's 1.25x on a half-second recipe.

    THAT IS ENOUGH BECAUSE THE MODULES ARE LOUD, not because 300 is a large sample. The rig's own
    quality module puts the control machines at the engine's `quality=100`, which promotes almost
    every craft -- so the control column comes out overwhelmingly non-normal and the flagged column
    entirely normal, and no arithmetic about rare events stands between the reader and the answer.
    A shipped quality-module-3 at a tenth of that would want thousands of crafts to say the same
    thing as firmly.

.PARAMETER SpaceAge
    Run with space-age enabled instead of the bundled quality mod alone.

    The default is `quality` alone, which is what ADR 0003's target mod set can hold, and it is
    where the answers in docs/research/quality.md were taken. The switch is here because the same
    rig under the expansion is the cheapest control on any answer that looks like a property of the
    mod set rather than of the flag.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/probe-allow-quality.ps1
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [ValidateRange(1, 100000)] [int] $Seconds = 120,
    [switch] $SpaceAge,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$rigName  = 'rf-allow-quality-probe'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-aq-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

@{
    name = $rigName; version = '0.0.1'; title = 'allow_quality probe'
    author = 'probe-allow-quality.ps1'; factorio_version = '2.0'
    dependencies = @('base >= 2.0.77', 'quality', 'realistic-fusion-refreshed')
} | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

# ---------------------------------------------------------------------------- the rig's recipes
Add-RigData -RigDirectory $rigDir -Lua @'
-- Generated by probe-allow-quality.ps1. Nothing here ships, and nothing here modifies a shipped
-- recipe: both of these are new, and the two shipped mods are loaded only so the answer is measured
-- in the mod set the question is about.
--
-- IDENTICAL IN EVERY FIELD BUT ONE. The pair is the instrument: whatever the flagged machine does,
-- the reading is what the control machine did differently. Built from one table so a field cannot
-- drift between them by an edit to one copy.
--
-- iron-plate -> iron-chest, rather than a fluid or an intermediate, for two reasons. A chest is
-- placeable, so the report can end by creating a legendary one with create_entity and showing in
-- the same run that the script route the note calls out is still open. And it is one plate in and
-- one chest out, so a machine's throughput is the craft rate and nothing else.
local function twin(name)
  return {
    type = "recipe", name = name, enabled = true, category = "crafting",
    energy_required = 0.5,
    ingredients = { { type = "item", name = "iron-plate", amount = 1 } },
    results     = { { type = "item", name = "iron-chest", amount = 1 } },
  }
end

local flagged = twin("rfaq-flagged")
flagged.allow_quality = false

-- A QUALITY MODULE LOUD ENOUGH THAT ZERO MEANS SOMETHING. Four quality-module-3s put a machine at
-- the engine's `quality=1`, and at that rate a two-minute run promotes a handful of crafts or none
-- at all -- so an all-normal tally on the flagged machine beside it would prove nothing. At
-- `quality=100` the control machines promote nearly every craft, which turns question 4 from an
-- argument about sample size into a column a reader can look at.
--
-- A copy of quality-module-3 rather than a new prototype, so it stays in the same module category
-- and the refusal rule that question 2 is about applies to it identically -- and the report tests
-- can_insert with the SHIPPED module as well, so the refusal is shown against a module a player
-- actually has. The speed penalty is dropped: it would only slow the sample down.
local loud = table.deepcopy(data.raw["module"]["quality-module-3"])
loud.name = "rfaq-loud-quality-module"
loud.localised_name = { "", "Loud quality module (probe)" }
loud.effect = { quality = 25 }
loud.subgroup = nil
loud.order = "z"

data:extend({ twin("rfaq-control"), flagged, loud })
'@

# ---------------------------------------------------------------------------- the measurement
$lua = @'
-- Generated by probe-allow-quality.ps1. Reports; asserts nothing.

local RUN_TICKS = __RUN_TICKS__

local MACHINE = "assembling-machine-3"
local MODULE  = "rfaq-loud-quality-module"
local SHIPPED_MODULE = "quality-module-3"
local FEED    = "iron-plate"
local MADE    = "iron-chest"

local function say(fmt, ...) log("AQPROBE " .. string.format(fmt, ...)) end

--- Read a member off a Lua API object without knowing whether it exists.
--
-- THE PCALL IS THE MEASUREMENT, not defensive habit. A LuaObject raises on a member the engine does
-- not define rather than answering nil, so "did the read succeed" is exactly the question
-- "does this API carry that name" -- which is the thing the 2.0.77 docs do not say.
local function member(object, key)
  local ok, value = pcall(function() return object[key] end)
  if not ok then return false, nil end
  return true, value
end

--- What one inventory holds, by quality, as a printable string.
--
-- get_contents() in 2.0 returns a list of { name, count, quality }, so quality is a field on the
-- row rather than something to be inferred. Sorted by the printed form, because the engine's order
-- is not defined and a report that reshuffles between runs cannot be diffed.
--- Every stack in an inventory, keyed "<quality> <name>" -> count.
--
-- SLOT BY SLOT rather than get_contents(). The aggregate does carry a quality field and was not
-- the bug this rig spent three runs on -- both readings agreed throughout -- but quality is the
-- field under test here, and a LuaItemStack carries its own LuaQualityPrototype where the aggregate
-- carries a summary of one. When the summary IS the measurement, read the thing.
local function tally(inventory, into)
  local out = into or {}
  if not inventory or not inventory.valid then return out end
  for i = 1, #inventory do
    local stack = inventory[i]
    if stack.valid_for_read then
      local key = stack.quality.name .. " " .. stack.name
      out[key] = (out[key] or 0) + stack.count
    end
  end
  return out
end

--- The same, as one printable line.
local function contents(inventory)
  if not inventory or not inventory.valid then return "(no inventory)" end
  local rows = {}
  for key, count in pairs(tally(inventory)) do
    rows[#rows + 1] = string.format("%s x%d", key, count)
  end
  if #rows == 0 then return "(empty)" end
  table.sort(rows)
  return table.concat(rows, ", ")
end

--- defines.entity_status by name, so a status prints as a word rather than as 54.
local STATUS = {}
for name, value in pairs(defines.entity_status) do STATUS[value] = name end
local function status_name(status)
  return status and (STATUS[status] or ("status " .. tostring(status))) or "(none)"
end

local function must(entity, what)
  if not entity then error(what .. " refused") end
  return entity
end

--- One assembling machine set to one recipe, with a substation of its own.
--
-- A SUBSTATION EACH, rather than one covering the row. The first version put three machines in a
-- line and one substation beside them, and the machine at the far end was outside the eighteen-tile
-- supply area: it crafted nothing all run and reported an empty output inventory, which is exactly
-- what a flag that stopped production would look like. Nothing separated the two readings. Now
-- every machine carries its own supply and prints its own status, so "made nothing" cannot be an
-- unpowered machine in disguise.
local function machine_at(surface, force, x, recipe)
  must(surface.create_entity({ name = "substation", position = { x + 3, 4.5 }, force = force }),
    "substation for " .. recipe)
  local eei = must(surface.create_entity({
    name = "electric-energy-interface", position = { x + 5.5, 4.5 }, force = force,
  }), "power source for " .. recipe)
  eei.power_production = 4e6   -- joules per TICK, which is 240 MW. See scripts/check-brownout.ps1.
  return must(surface.create_entity({
    name = MACHINE, position = { x, 0.5 }, force = force, recipe = recipe,
  }), MACHINE .. " for " .. recipe)
end

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player

  surface.request_to_generate_chunks({ 40, 0 }, 6)
  surface.force_generate_chunk_requests()
  local tiles = {}
  for x = -20, 100 do
    for y = -20, 20 do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = { { -20, -20 }, { 100, 20 } } })) do
    if e.type ~= "character" then e.destroy() end
  end

  -- THE PROBE IS USELESS WITHOUT THE QUALITY MOD and says so rather than printing five rows of
  -- "normal". Checked on the module, not on the quality prototypes: the flag is about modules.
  if not prototypes.item[SHIPPED_MODULE] then
    error(SHIPPED_MODULE .. " does not exist, so the bundled quality mod is not enabled and there "
      .. "is nothing here to measure.")
  end

  -- THREE MACHINES, and the third is not about the flag at all. `vanilla` runs an untouched base
  -- recipe with the same modules, and it is the control on the CONTROL: if it makes nothing but
  -- normal output either, quality promotion is not happening in this rig for a reason that has
  -- nothing to do with allow_quality, and both other columns are unreadable. A rig whose negative
  -- result has two explanations measures neither of them.
  --
  -- IT HAS ALREADY EARNED ITS PLACE ONCE. Before the line below, every machine here -- this one
  -- included, at quality=100 -- produced nothing but normal output, and without this column that
  -- would have been written up as the flag working perfectly.
  -- QUALITY PROMOTION IS GATED BEHIND RESEARCH, and this one line is the whole finding it took
  -- five runs to reach. On an unresearched force a machine promotes NOTHING at any module strength:
  -- four shipped quality-module-3s (the engine's quality=1) over 1199 crafts of an untouched vanilla
  -- recipe, and the loud module below at quality=100 -- certainty on any reading of that number --
  -- over 299, under the quality mod and under space-age alike. The force's own production
  -- statistics agreed with the inventories that nothing else was ever made. Researched, the same
  -- machine promotes nearly every craft.
  --
  -- It is here rather than in the report because the flag is what this rig is asking about and a
  -- gate in front of the whole mechanic would answer every question with a false yes. It is worth
  -- knowing on its own account, though, and docs/research/quality.md records it: any check option E
  -- might want must not rest on an unresearched save, where quality does nothing whatever the
  -- recipes say.
  force.research_all_technologies()

  storage.subjects = {}
  for _, case in ipairs({
    { "control", "rfaq-control" }, { "flagged", "rfaq-flagged" }, { "vanilla", "iron-gear-wheel" },
  }) do
    local label, recipe = case[1], case[2]
    local m = machine_at(surface, force, #storage.subjects * 20 + 0.5, recipe)
    storage.subjects[#storage.subjects + 1] = {
      label = label, recipe = recipe, machine = m,
      -- The tally the output inventory cannot hold. An assembling machine stops when its output
      -- fills, and an iron-chest stacks fifty -- so the first run of this rig read exactly fifty on
      -- the machine that worked, which is the stack size and not a rate. Emptied every second into
      -- here instead, keyed by quality.
      made = {},
    }
  end

  -- The third machine, for question 3: set to the CONTROL recipe and loaded with modules, then
  -- switched to the flagged one below. It crafts nothing and is not part of the tally.
  storage.switcher = machine_at(surface, force, 60.5, "rfaq-control")

  log("AQRIG built")
end)

--- Question 1: is the flag readable at runtime, and under what name?
local function report_readability()
  -- Candidates rather than one name, because the point is that the docs do not say. The first two
  -- are what RecipePrototype declares in the 2.0.77 property list; the last two are the shapes the
  -- engine uses elsewhere for the same idea, tried so that "not readable" means tried and failed
  -- rather than tried once.
  local KEYS = { "allow_quality", "allow_quality_message", "allows_quality", "quality_allowed" }
  for _, recipe in ipairs({ "rfaq-control", "rfaq-flagged" }) do
    local proto = prototypes.recipe[recipe]
    for _, key in ipairs(KEYS) do
      local ok, value = member(proto, key)
      say("read   LuaRecipePrototype[%-14s] %-12s -> %-9s %s",
        '"' .. key .. '"', recipe, ok and "readable" or "RAISES", ok and tostring(value) or "")
    end
  end
  -- And on LuaRecipe, which is what a machine hands back and therefore what any check option E
  -- wanted would be written against.
  local recipe = storage.subjects[2].machine.get_recipe()   -- the flagged machine's own LuaRecipe
  for _, key in ipairs(KEYS) do
    local ok, value = member(recipe, key)
    say("read   LuaRecipe[%-24s] %-12s -> %-9s %s",
      '"' .. key .. '"', "rfaq-flagged", ok and "readable" or "RAISES", ok and tostring(value) or "")
  end
end

--- Question 2: is the module refused, or accepted and ignored?
local function report_modules()
  -- THE QUALITY LADDER ITSELF, before anything about the flag. A machine can hold every module in
  -- the game and still make nothing but normal output if `normal` has no next grade to be promoted
  -- to, and that would make the two tallies below agree for a reason that has nothing to do with
  -- allow_quality. Printed so a zero in the control column can be read.
  for name, q in pairs(prototypes.quality) do
    say("ladder %-16s level=%d hidden=%-5s next=%s", name, q.level, tostring(q.hidden),
      q.next and q.next.name or "(none)")
  end

  -- What the module itself claims to do, so a reader can judge the tally at the end of the run
  -- against a number rather than against an expectation. It is here because it is the figure the
  -- run length has to be chosen against, and getting that wrong is what the docstring records.
  for _, name in ipairs({ SHIPPED_MODULE, MODULE }) do
    local effects = prototypes.item[name].module_effects or {}
    local declared = {}
    for effect, value in pairs(effects) do
      declared[#declared + 1] = string.format("%s=%s", effect,
        (type(value) == "table") and tostring(value.bonus) or tostring(value))
    end
    table.sort(declared)
    say("module-proto %-26s declares %s, and a machine takes four", name,
      table.concat(declared, " "))
  end

  for _, s in ipairs(storage.subjects) do
    local inventory = s.machine.get_module_inventory()
    local slots = inventory and #inventory or 0
    -- The shipped module is asked first and separately: whatever the loud one does, the row a
    -- reader cares about is what happens to a quality-module-3 a player is holding.
    local can_shipped = inventory
      and inventory.can_insert({ name = SHIPPED_MODULE, count = 1 }) or false
    say("shipped %-8s recipe=%-13s can_insert(%s)=%s",
      s.label, s.recipe, SHIPPED_MODULE, tostring(can_shipped))
    local can   = inventory and inventory.can_insert({ name = MODULE, count = 1 }) or false
    local put   = inventory and inventory.insert({ name = MODULE, count = slots }) or 0
    say("module %-8s recipe=%-13s slots=%d can_insert=%-5s inserted=%d holds: %s",
      s.label, s.recipe, slots, tostring(can), put, contents(inventory))
    -- The effects the machine ends up with, which is the only place "accepted and does nothing"
    -- and "accepted and works" can differ before anything is crafted.
    local effects = s.machine.effects or {}
    local parts = {}
    for name, value in pairs(effects) do
      -- Either shape printed, because which one LuaEntity.effects carries is itself undocumented
      -- enough to have caught this rig once: 2.0.77 hands back a plain number per effect, and the
      -- { bonus = n } table is the shape the prototype side uses.
      local shown = (type(value) == "table") and tostring(value.bonus) or tostring(value)
      parts[#parts + 1] = string.format("%s=%s", name, shown)
    end
    table.sort(parts)
    say("effect %-8s %s", s.label, #parts > 0 and table.concat(parts, " ") or "(none)")
  end
end

--- Question 3: a machine that already holds a module, switched onto the flagged recipe.
local function report_switch()
  local m = storage.switcher
  local inventory = m.get_module_inventory()
  local put = inventory.insert({ name = MODULE, count = #inventory })
  say("switch before  recipe=%s modules=%d holds: %s",
    m.get_recipe().name, put, contents(inventory))

  -- pcall, because "the engine refuses the switch" is one of the answers this is asking for and it
  -- would arrive as a raise rather than as a return value.
  local ok, err = pcall(function() m.set_recipe("rfaq-flagged") end)
  local recipe = m.get_recipe()
  say("switch set_recipe -> %s%s", ok and "accepted" or "RAISED", ok and "" or (": " .. tostring(err)))
  say("switch after   recipe=%s status=%s holds: %s",
    recipe and recipe.name or "(none)", status_name(m.status), contents(inventory))

  -- AND WHERE THE MODULES WENT, which is the half of question 3 that decides whether the engine's
  -- answer is safe. "The inventory is empty" is compatible with the engine having destroyed four
  -- quality-module-3s, and a mod that quietly eats a player's modules when they change a recipe is
  -- a different thing from one that hands them back. Both places they could have landed are looked
  -- at: the machine's own output inventory, and the ground around it.
  say("switch output  %s", contents(m.get_output_inventory()))
  local spilled = {}
  -- The whole rig area rather than a radius around the machine, because "the engine dropped them
  -- somewhere" is one of the answers and a scan that misses would read as "the engine ate them".
  for _, e in pairs(m.surface.find_entities_filtered({
    type = "item-entity", area = { { -20, -20 }, { 100, 20 } } }))
  do
    local stack = e.stack
    if stack and stack.valid_for_read then
      spilled[#spilled + 1] = string.format("%s %s x%d", stack.quality.name, stack.name, stack.count)
    end
  end
  table.sort(spilled)
  say("switch ground  %s", #spilled > 0 and table.concat(spilled, ", ") or "(nothing on the ground)")
end

--- Empty every machine's output into its tally and top its input back up.
--
-- Both halves are the same guard against a stalled machine reading as a stopped one. An assembling
-- machine halts when its output fills, and an iron-chest stacks fifty; it halts again when its
-- input runs out, and an assembling machine's ingredient slot holds far less than a run's worth.
-- Either would put a small number in the tally that a reader could mistake for the flag working.
--
-- IT DOES NOT MAKE THE THREE TOTALS COMPARABLE, and they are not meant to be. An assembling
-- machine's output inventory is one slot, and two qualities of the same item will not share a
-- stack -- so a machine that is promoting stalls between top-ups where one making nothing but
-- normal output does not, and comes out with a lower total. The columns answer WHAT quality was
-- made, not how fast; nothing here reads a rate.
local function tend()
  for _, s in ipairs(storage.subjects) do
    tally(s.machine.get_output_inventory(), s.made)
    s.machine.get_output_inventory().clear()
    -- iron-plate feeds all three: it is the rig recipes' only ingredient and iron-gear-wheel's too.
    s.machine.get_inventory(defines.inventory.assembling_machine_input)
      .insert({ name = FEED, count = 1000 })
  end
end

--- Question 4: with the machines fed and run, what quality did each one actually make?
local function report_output()
  tend()
  -- A SECOND CHANNEL ON THE SAME QUESTION, because "the inventory held nothing but normal" and
  -- "nothing but normal was ever made" are different statements and this rig has already been wrong
  -- about which one it was measuring. The force's own production statistics are keyed by quality in
  -- 2.0, so they see every item the machines finished whether or not it survived to a slot.
  local stats = game.forces.player.get_item_production_statistics(game.surfaces[1])
  for _, item in ipairs({ MADE, "iron-gear-wheel" }) do
    for name in pairs(prototypes.quality) do
      local made = stats.get_input_count({ name = item, quality = name })
      if made > 0 then say("stats  %-16s %-10s produced %d", item, name, made) end
    end
  end
  for _, s in ipairs(storage.subjects) do
    local rows = {}
    for key, count in pairs(s.made) do rows[#rows + 1] = string.format("%s x%d", key, count) end
    table.sort(rows)
    -- The status is printed beside the tally for the reason the substations exist: a machine that
    -- made nothing because it was starved, unpowered or blocked must not read as a machine the flag
    -- stopped.
    say("output %-8s recipe=%-13s status=%s made: %s",
      s.label, s.recipe, status_name(s.machine.status),
      #rows > 0 and table.concat(rows, ", ") or "(nothing)")
  end
end

--- And the line the note already states: the flag is not absolute.
local function report_script_route()
  local surface = game.surfaces[1]
  local chest = surface.create_entity({
    name = MADE, position = { 85.5, 0.5 }, force = game.forces.player, quality = "legendary",
  })
  say("script create_entity{quality=\"legendary\"} on %s -> %s", MADE,
    chest and ("placed, and reads back " .. chest.quality.name) or "refused")
end

script.on_nth_tick(60, function()
  local tick = game.tick

  -- The set-up pass, once the machines exist and the engine has had a tick to settle them.
  if not storage.armed then
    storage.armed = true
    report_readability()
    report_modules()
    report_switch()
    -- Fed AFTER the modules, so a machine that took them crafts with them from its first craft,
    -- and topped up every second by tend() below for the rest of the run.
    tend()
    say("fed    %s to each machine, topped up every second; crafting for %d ticks", FEED, RUN_TICKS)
    return
  end

  tend()

  if storage.reported or tick < RUN_TICKS then return end
  storage.reported = true
  report_output()
  report_script_route()
  say("done")
end)
'@
$lua = $lua.Replace('__RUN_TICKS__', "$($Seconds * 60)")
Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') -Value $lua

$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    $enabled = Resolve-BundledSelection -Requested @($(if ($SpaceAge) { 'space-age' } else { 'quality' })) -Bundled $bundled
    Write-Host "bundled enabled: $($enabled -join ', ')"
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabled -Mods ($ourMods + $rigName)

    $save = Join-Path $temp 'allow-quality.zip'
    Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create' | Out-Null
    $runOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', "$($Seconds * 60 + 240)",
        '--benchmark-runs', '1', '--disable-audio')

    $reported = @(Get-Content $runOut | Select-String -Pattern 'AQPROBE ' |
        ForEach-Object { ($_ -split 'AQPROBE ', 2)[1].TrimEnd() })
    if ($reported.Count -eq 0) { throw 'the rig reported nothing; it never reached its report tick.' }

    foreach ($line in $reported) { Write-Host "  $line" }

    # The sentinel, for the same reason every rig here checks for one: a rig that died part way
    # through its report prints rows that look exactly like a complete run.
    if (-not ($reported | Where-Object { $_ -eq 'done' })) {
        throw 'the rig stopped before the end of its report; the rows above are incomplete.'
    }

    Write-Host ''
    Write-Host 'OK - the probe ran and every row reported. The answers are above, and they are'
    Write-Host '     observations rather than a verdict, so nothing here passes or fails.'
    Write-Host '     docs/research/quality.md is what they are read into, and whether this mod'
    Write-Host '     should use the flag is option E there and Truls''s.'
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'probe-allow-quality' }
}

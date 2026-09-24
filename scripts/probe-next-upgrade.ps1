<#
.SYNOPSIS
    Probes what an upgrade-planner swap does to a chained row of heat exchangers -- whether the swap
    happens at all between two machines differing only in energy_consumption, and what it does to
    the bolted joints, the fluid, the blueprint and the neighbours either side.

.DESCRIPTION
    A PROBE, NOT A CHECK. Every line it prints is a measurement, and a negative answer is as much of
    a result as a positive one -- exit 0 means it ran and reported, never that the answer was the
    hoped-for one. Nothing here ships and nothing here decides: #315's route is Truls's to choose.

    THE QUESTION AND WHY IT IS OPEN (#396). #315 chose route 1 during triage on 2026-09-17 -- a
    second exchanger tier unlocked by research and chained by `next_upgrade`, so an upgrade planner
    swaps it in place. That route rests on a claim nobody here has measured: that the swap
    "preserves the footprint, the bolted joints and the blueprint". Those are three separate claims
    about a 15x5 machine whose energy face bolts to a reactor (ADR 0031) and which carries three
    fluid families, each with a connection_category of its own (ADR 0018).

    NOTHING IN THIS MOD IS ON ANY UPGRADE PATH TODAY, so no swap has ever been observed here.
    `claim()` in realistic-fusion-refreshed-core/prototypes/vanilla.lua clears `next_upgrade` and
    `fast_replaceable_group` on every machine both modules copy out of vanilla, on purpose: its
    upgrade target belongs to the vanilla upgrade path, which ours is not on, and left in place an
    upgrade planner would quietly convert our machine into a vanilla one. This probe does not touch
    that. It stands up its OWN pair, outside the rf- set, and puts the two fields on the scratch
    pair rather than taking them off the shipped machines.

    THE 2.0.77 DOCS CONSTRAIN NOTHING, WHICH IS WHY THIS IS A RUNTIME QUESTION. EntityPrototype's
    `next_upgrade` is defined as "Name of the entity that will be automatically selected as the
    upgrade of this entity when using the upgrade planner without configuration" and states no
    requirement about collision box, fluid boxes, fast_replaceable_group or connection categories
    (checked against 2.0.77, not recalled). A prototype the engine accepts is not a prototype the
    engine swaps cleanly -- probe-native-heat.ps1's header records a reactor-as-crafting-machine
    that loaded perfectly and then moved no fluid at all.

    WHAT IT MEASURES, one section each, matching #396's six questions:

      1. DOES THE SWAP HAPPEN between two entities differing only in energy_consumption, driven by
         an upgrade planner over an area the way a player drives one.
      2. DO THE BOLTED JOINTS SURVIVE -- the face bolted to rf-reactor, and both chained short ends.
         Measured as fluid-system identity before and after, which is the same discriminator
         probe-exchanger-chaining.ps1 uses: two boxes in one system is the structural claim.
      3. WHAT HAPPENS TO THE FLUID each of the three boxes held.
      4. WHETHER A BLUEPRINT of the old row still places, and whether an upgrade planner applied
         over a blueprint works.
      5. WHETHER `fast_replaceable_group` IS NEEDED as well, or `next_upgrade` is enough alone.
         Two scratch pairs, one with the group and one without, so the answer is a difference
         between two readings rather than one reading against an expectation.
      6. WHETHER A SWAP MID-ROW breaks the chain for the neighbours either side, which is the one
         that cannot be asked of a single machine.

    THE SCRATCH TIER IS SCRATCH. #315 owns the shipped second tier and its capacity is not decided
    here, so the pair this stands up differs from rf-heat-exchanger in energy_consumption and in
    nothing else. Anything this probe found that depended on a second difference would be a finding
    about that difference instead.

    THE GEOMETRY COMES FROM THE LIVE PROTOTYPE, not from a copy. rf-heat-exchanger's footprint has
    moved twice (#275, #276) and its three connection categories are what make this question
    non-obvious, so the rig reads them off the loaded prototype at runtime and prints what it read.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Ticks
    Ticks to run past the build. The planner is applied on a scheduled tick and the report follows
    it, so this only needs to be long enough to contain both.

.PARAMETER KeepTemp
    Keep the scratch mod directory and the save, for reading the rig's Lua or re-running by hand.

.EXAMPLE
    pwsh -File scripts/probe-next-upgrade.ps1
#>
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [int]    $Ticks = 600,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
. "$repoRoot/scripts/factorio-lib.ps1"

$ourMods = Get-RepoMods
$rigName = 'rf-next-upgrade-probe'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-upg-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

@{
    name = $rigName; version = '0.0.1'; title = 'next_upgrade probe'
    author = 'probe-next-upgrade.ps1'; factorio_version = '2.0'
    dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed', 'realistic-fusion-refreshed-core')
} | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

# ---------------------------------------------------------------------------- the rig's prototypes
#
# TWO SCRATCH PAIRS, and the difference between them is the whole of section 5. Each pair is
# rf-heat-exchanger deepcopied twice, tier 1 pointing at tier 2 through next_upgrade. One pair also
# carries fast_replaceable_group on both halves; the other carries none. Asking with and without is
# what turns "does it need the group" into a difference between two readings.
#
# NAMED OUTSIDE THE rf- SET on purpose: control.lua keys its reactor table by entity name, so these
# are invisible to the simulation, exactly as probe-exchanger-chaining.ps1's variants are.
#
# energy_consumption IS THE ONLY FIELD THAT DIFFERS between a pair's two halves. #315 owns what a
# real second tier would change; a probe that changed more would be measuring that instead.
function Get-ProbeData {
    <#  The rig's data.lua for ONE pair. `Grouped` decides whether both halves carry a shared
        fast_replaceable_group, which is section 5's whole question and -- as it turns out -- is
        answered at the DATA stage rather than at runtime, so the two cases cannot be loaded
        together: the ungrouped one refuses to load at all and would take the grouped one with it. #>
    param([Parameter(Mandatory)] [bool] $Grouped)

    $suffix = if ($Grouped) { 'grouped' } else { 'ungrouped' }
    $group  = if ($Grouped) { '"upgprobe-grouped"' } else { 'nil' }

    return @"
-- Generated by probe-next-upgrade.ps1. Nothing here ships.

local base = data.raw["boiler"]["rf-heat-exchanger"]
if not base then error("probe-next-upgrade: rf-heat-exchanger is not a boiler in data.raw") end

local PAIRS = {
  { suffix = "$suffix", group = $group },
}

for _, p in ipairs(PAIRS) do
  local t1 = table.deepcopy(base)
  local t2 = table.deepcopy(base)

  t1.name = "upgprobe-" .. p.suffix .. "-t1"
  t2.name = "upgprobe-" .. p.suffix .. "-t2"
  t1.minable = { mining_time = 0.5, result = t1.name }
  t2.minable = { mining_time = 0.5, result = t2.name }

  -- THE ONE DIFFERENCE. Doubling it is arbitrary and is not a proposal: what matters is that the
  -- two prototypes are not identical, so a swap that happened can be told from one that did not.
  t2.energy_consumption = "180MW"

  t1.next_upgrade = t2.name
  t1.fast_replaceable_group = p.group
  t2.fast_replaceable_group = p.group
  -- Tier 2 points at nothing: a planner run twice must not walk further up a ladder that is not
  -- being asked about.
  t2.next_upgrade = nil

  local i1 = table.deepcopy(data.raw["item"]["rf-heat-exchanger"])
  local i2 = table.deepcopy(data.raw["item"]["rf-heat-exchanger"])
  i1.name, i1.place_result, i1.order = t1.name, t1.name, "z-upg-1"
  i2.name, i2.place_result, i2.order = t2.name, t2.name, "z-upg-2"

  data:extend({ t1, t2, i1, i2 })
end
"@
}

# ---------------------------------------------------------------------------- the rig's control.lua
#
# The row it builds, per pair: a reactor, then three chained exchangers off one of its energy faces.
# Three rather than two because section 6 asks what a swap MID-ROW does, and a row of two has no
# middle. The middle one is the one the planner is pointed at for that section.
$control = @'
-- Generated by probe-next-upgrade.ps1. Nothing here ships.

local function say(s) log("UPGPROBE " .. s) end

local function box_of(name)
  local p = prototypes.entity[name]
  local b = p.collision_box
  return b.left_top.x, b.left_top.y, b.right_bottom.x, b.right_bottom.y
end

-- WHO EACH BOX IS ACTUALLY JOINED TO, asked through the connections themselves rather than through
-- a system id: get_fluid_system_id is NOT a 2.0.77 method (probe-exchanger-chaining.ps1 established
-- that, and indexing it raises rather than returning nil), and get_pipe_connections is what the
-- shipped rigs already use. A connection whose target's owner is another entity is the engine
-- saying it plumbed the two together, which is the structural claim a swap either preserves or does
-- not. Reported as a sorted list of the unit numbers each box reaches.
local function joins(e)
  if not (e and e.valid) then return "gone" end
  local per = {}
  for i = 1, #e.fluidbox do
    local hit = {}
    for _, c in ipairs(e.fluidbox.get_pipe_connections(i)) do
      if c.target and c.target.owner and c.target.owner.valid then
        hit[#hit + 1] = tostring(c.target.owner.unit_number)
      end
    end
    table.sort(hit)
    per[#per + 1] = (#hit > 0 and table.concat(hit, "+") or "-")
  end
  return table.concat(per, "/")
end

-- What each box holds, so section 3 reports the fluid rather than inferring it.
local function contents(e)
  if not (e and e.valid) then return "gone" end
  local out = {}
  for i = 1, #e.fluidbox do
    local f = e.fluidbox[i]
    out[#out + 1] = f and string.format("%s=%.1f", f.name, f.amount) or "empty"
  end
  return table.concat(out, ",")
end

local function place(surface, force, name, x, y, dir)
  local e = surface.create_entity{ name = name, position = { x, y }, force = force,
                                   direction = dir, raise_built = true }
  if not e then error("probe-next-upgrade: could not place " .. name .. " at " .. x .. "," .. y) end
  return e
end

script.on_nth_tick(60, function(event)
  if storage.done then return end
  storage.done = true

  local surface = game.surfaces[1]
  local force = game.forces.player
  surface.always_day = true

  -- The live geometry, read rather than remembered (#275, #276 both moved it).
  local x1, y1, x2, y2 = box_of("rf-heat-exchanger")
  say(string.format("geometry: rf-heat-exchanger collision_box %.1f,%.1f .. %.1f,%.1f", x1, y1, x2, y2))
  local proto = prototypes.entity["rf-heat-exchanger"]
  local cats = {}
  for _, b in ipairs(proto.fluidbox_prototypes) do
    for _, c in ipairs(b.pipe_connections or {}) do
      cats[#cats + 1] = tostring(c.connection_category and c.connection_category[1] or "default")
    end
  end
  say("geometry: connection categories " .. table.concat(cats, ","))

  -- THE LONG AXIS IS X, so a row chains along X and the pitch is the machine's own width. Read off
  -- the live box rather than typed: #275 and #276 both moved this footprint, and
  -- probe-exchanger-chaining.ps1 steps in Y because it pins a PRE-#275 frame, which is a trap for
  -- anyone borrowing its geometry rather than its idiom.
  local PITCH = math.floor(x2 - x1 + 0.5)

  -- Whichever pair actually loaded. The ungrouped one is refused at the DATA stage (section 5), so
  -- it never reaches here; asking the prototype table rather than assuming is what lets one
  -- control.lua serve both loads without knowing which it is in.
  local present = {}
  for _, suffix in ipairs({ "grouped", "ungrouped" }) do
    if prototypes.entity["upgprobe-" .. suffix .. "-t1"] then present[#present + 1] = suffix end
  end
  if #present == 0 then say("no upgprobe pair loaded; nothing to measure"); say("done"); return end

  for _, suffix in ipairs(present) do
    local t1 = "upgprobe-" .. suffix .. "-t1"
    local t2 = "upgprobe-" .. suffix .. "-t2"
    local ox = (suffix == "grouped") and 0 or 120

    say("")
    say("=== pair " .. suffix .. " (fast_replaceable_group " ..
        (suffix == "grouped" and "SET" or "ABSENT") .. ") ===")

    -- A reactor, and a row of three chained short end to short end along its energy face.
    local reactor = place(surface, force, "rf-reactor", ox, 0, defines.direction.north)
    local row = {}
    for i = 1, 3 do
      -- East of the reactor, short end to short end. The reactor is 15 square, so the first sits
      -- one half-width of each clear of its centre and the rest follow at one machine width.
      row[i] = place(surface, force, t1, ox + 15 + (i - 1) * PITCH, 0, defines.direction.north)
    end

    -- 1 + 2. What the joints look like BEFORE anything is swapped, so the after-reading is a
    -- difference rather than a lone observation.
    for i = 1, 3 do
      say(string.format("before: row[%d] %s joins=%s contents=%s", i, row[i].name,
                        joins(row[i]), contents(row[i])))
    end
    say("before: reactor joins=" .. joins(reactor))

    -- THE CONTROL, AND IT COMES BEFORE THE SWAP. Every "after" line below is a DIFFERENCE, so a row
    -- that was never joined in the first place would report a swap that broke nothing -- the same
    -- confident wrong answer a rig gives whenever nothing in it had to succeed. If this line says
    -- NOT JOINED, sections 2 and 6 are unanswered and the layout is what needs fixing, not the
    -- conclusion.
    local chained = 0
    for i = 1, 2 do
      for _, c in ipairs(row[i].fluidbox.get_pipe_connections(1)) do
        if c.target and c.target.owner and c.target.owner.valid
           and c.target.owner.unit_number == row[i + 1].unit_number then
          chained = chained + 1
        end
      end
    end
    say("control: neighbouring pairs actually joined = " .. chained .. " of 2 -- " ..
        (chained == 2 and "ROW IS CHAINED, the after-readings below are differences"
                       or "ROW IS NOT CHAINED, so sections 2 and 6 are UNANSWERED"))

    -- 1. THE SWAP, driven the way a player drives it: an upgrade planner over an area, with no
    -- configuration, which is exactly the case next_upgrade's own documentation describes.
    local planner = surface.create_entity{ name = "item-on-ground", position = { ox, -60 },
                                           stack = { name = "upgrade-planner" } }
    local ok = false
    if planner and planner.stack and planner.stack.valid_for_read then
      -- 6. MID-ROW FIRST. row[2] alone is ordered, so the neighbours either side are untouched and
      -- whatever happens to their joints is the swap's doing rather than their own.
      ok = pcall(function()
        surface.upgrade_area{ area = row[2].bounding_box, item = planner.stack,
                              force = force, skip_fog_of_war = false }
      end)
      say("swap: upgrade_area over row[2] called ok=" .. tostring(ok))
    else
      say("swap: NO upgrade-planner stack could be made; sections 1, 4 and 6 are unanswered")
    end

    -- The order is a construction-robot job in a real game; with no roboport the engine leaves a
    -- ghost-like order rather than performing it, so ask the surface what is actually there now.
    local at = surface.find_entities_filtered{ area = row[2].bounding_box,
                                               name = { t1, t2 } }
    local names = {}
    for _, e in ipairs(at) do names[#names + 1] = e.name end
    say("after: row[2] tile holds " .. (#names > 0 and table.concat(names, ",") or "nothing") ..
        "; upgrade order = " .. tostring(row[2].valid and row[2].to_be_upgraded and
                                         row[2].to_be_upgraded() or "n/a"))

    -- 5. Whether the group mattered is this line read against the other pair's.
    say("after: row[2] still valid=" .. tostring(row[2].valid) ..
        " name=" .. (row[2].valid and row[2].name or "-"))

    -- 2 + 3 + 6. The joints and the fluid, after.
    for i = 1, 3 do
      say(string.format("after: row[%d] %s joins=%s contents=%s", i,
                        row[i].valid and row[i].name or "gone", joins(row[i]), contents(row[i])))
    end
    say("after: reactor joins=" .. joins(reactor))

    -- AND THEN PERFORM IT, because the planner only ORDERS the swap. upgrade_area marks the entity
    -- and a construction robot does the work; a benchmark map has no roboport, so the row above is
    -- a row of ORDERS and sections 1, 2, 3 and 6 would be unanswered if this stopped there. A robot
    -- carries the order out as a FAST REPLACE, so that is what this does directly -- the same
    -- operation, without needing a logistic network in a rig whose subject is not logistics.
    -- 3. FILL THE BOXES FIRST, or "what happens to the fluid" is answered about nothing. Every box
    -- gets whatever its own filter says it takes, found rather than assumed: the three families
    -- here are two contained energies and water/steam, and a hard-coded fluid name would silently
    -- fill none of them the day a filter changes.
    for i = 1, #row[2].fluidbox do
      local filter = row[2].fluidbox.get_filter(i)
      local want = filter and filter.name
      if not want then
        local protos = row[2].fluidbox.get_prototype(i)
        protos = protos.filter and protos.filter.name or nil
        want = protos
      end
      if want then
        local ok_fill = pcall(function() row[2].fluidbox[i] = { name = want, amount = 100 } end)
        say(string.format("fill: row[2] box %d filter=%s written=%s", i, want, tostring(ok_fill)))
      else
        say(string.format("fill: row[2] box %d has no filter; left empty", i))
      end
    end
    say("fill: row[2] contents now " .. contents(row[2]))

    local before2 = joins(row[2])
    local swapped = surface.create_entity{ name = t2, position = row[2].position,
                                           direction = row[2].direction, force = force,
                                           fast_replace = true, spill = false, raise_built = true }
    say("perform: fast_replace produced " .. (swapped and swapped.name or "NOTHING"))
    if swapped then
      say("perform: row[2] joins before=" .. before2 .. " after=" .. joins(swapped))
      say("perform: row[2] contents after=" .. contents(swapped))
      say("perform: neighbours row[1] joins=" .. joins(row[1]) .. " row[3] joins=" .. joins(row[3]))
      local still = 0
      for _, c in ipairs(swapped.fluidbox.get_pipe_connections(1)) do
        if c.target and c.target.owner and c.target.owner.valid then still = still + 1 end
      end
      say("perform: row[2] box 1 still reaches " .. still .. " neighbour(s) -- was 2 before")
    end

    -- 4. THE BLUEPRINT, both ways round: does a blueprint of the old row still place, and does a
    -- planner applied over a blueprint rewrite what it will build.
    local bp = surface.create_entity{ name = "item-on-ground", position = { ox, -64 },
                                      stack = { name = "blueprint" } }
    if bp and bp.stack and bp.stack.valid_for_read then
      local n = bp.stack.create_blueprint{ surface = surface, force = force,
                                           area = { { ox + 4, -40 }, { ox + 20, 40 } } }
      -- table_size, not table.size: the helper is a GLOBAL in 2.0 and the dotted spelling is nil.
      say("blueprint: captured " .. tostring(n and table_size(n) or 0) .. " entity/entities")
      local ents = bp.stack.get_blueprint_entities()
      local seen = {}
      for _, e in ipairs(ents or {}) do seen[#seen + 1] = e.name end
      say("blueprint: holds " .. (#seen > 0 and table.concat(seen, ",") or "nothing"))
      local placed = pcall(function()
        bp.stack.build_blueprint{ surface = surface, force = force,
                                  position = { ox, 80 }, force_build = true }
      end)
      say("blueprint: re-place ok=" .. tostring(placed))
    else
      say("blueprint: NO blueprint stack could be made; section 4 is unanswered")
    end
  end

  say("")
  say("done")
end)
'@
Set-Content -Path (Join-Path $rigDir 'control.lua') -Value $control -Encoding utf8

# ---------------------------------------------------------------------------- run it
$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }
try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    $enabled = Resolve-BundledSelection -Requested @() -Bundled $bundled
    Write-Host "bundled enabled: $(if ($enabled) { $enabled -join ', ' } else { 'none (base 2.0 only)' })"
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabled -Mods ($ourMods + $rigName)

    # ------------------------------------------------------------------ 5. does it need the group?
    #
    # ASKED FIRST AND ASKED BY LOADING, because the answer turned out to be a DATA-stage one: an
    # ungrouped pair does not merely swap badly, it refuses to load, and loading it alongside the
    # grouped pair would take that one down with it. So this is its own --create, its failure is
    # caught rather than thrown, and the engine's own words are the finding.
    Write-Host ''
    Write-Host '=== 5. next_upgrade WITHOUT a shared fast_replaceable_group ==='
    Add-RigData -RigDirectory $rigDir -Lua (Get-ProbeData -Grouped $false)
    $ungroupedSave = Join-Path $temp 'ungrouped.zip'
    # THREE OUTCOMES AND NOT TWO, which is the whole care of this block. Invoke-FactorioStep throws
    # on ANY non-zero exit, so "it threw" does not mean "the prototype was refused" -- the run may
    # simply have failed. The shared harness's Invoke-Factorio header (load-harness-lib.ps1) records what that
    # costs: the text is "Is another instance already running?" buried in the captured stdout, and
    # it "cost two wrong conclusions in a row before anyone noticed the game was simply running".
    #
    # Collapsing the third case into the first is how a probe reports that an ungrouped pair LOADED
    # when nothing loaded at all -- a confident wrong answer, which is the one thing a probe must
    # never produce. So: no exception is `loaded`, the pattern is `refused`, and an exception
    # WITHOUT the pattern is `unknown` and says so.
    $verdict = 'loaded'
    $refusal = $null
    $failure = $null
    try {
        Invoke-FactorioStep @step -Arguments @('--create', $ungroupedSave) -Tag 'create-ungrouped' | Out-Null
    } catch {
        $failure = $_.Exception.Message
        $verdict = 'unknown'
        $log = Join-Path $temp 'create-ungrouped-stdout.txt'
        if (Test-Path $log) {
            $refusal = (Get-Content $log | Select-String -Pattern 'next_upgrade target' |
                        Select-Object -First 1)
            if ($refusal) { $verdict = 'refused' }
        }
    }
    switch ($verdict) {
        'refused' {
            Write-Host "  REFUSED AT THE DATA STAGE: $($refusal.ToString().Trim())"
            Write-Host '  So next_upgrade is NOT enough on its own. The 2.0.77 EntityPrototype docs state'
            Write-Host '  no such constraint; the engine enforces it anyway. With the field absent each'
            Write-Host '  prototype defaults fast_replaceable_group to its own name, so the two differ.'
        }
        'loaded' {
            Write-Host '  NOT refused: an ungrouped pair loaded. next_upgrade alone is enough at the data'
            Write-Host '  stage, and whether it SWAPS is then a runtime question this run did not ask.'
        }
        default {
            Write-Host "  UNANSWERED: the run failed and not with a next_upgrade refusal -- $failure"
            Write-Host '  This section reports NOTHING about fast_replaceable_group. The log is'
            Write-Host "  $(Join-Path $temp 'create-ungrouped-stdout.txt') -- read it before re-running;"
            Write-Host '  a Factorio already running is the usual cause and looks nothing like a refusal.'
        }
    }

    # ------------------------------------------------------------- 1, 2, 3, 4, 6 on the grouped pair
    Write-Host ''
    Write-Host '=== 1, 2, 3, 4, 6. the grouped pair, at runtime ==='
    Remove-Item -LiteralPath (Join-Path $rigDir 'data.lua') -Force
    Add-RigData -RigDirectory $rigDir -Lua (Get-ProbeData -Grouped $true)

    $save = Join-Path $temp 'upgrade.zip'
    Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create' | Out-Null
    $runOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', [string]($Ticks + 120),
        '--benchmark-runs', '1', '--disable-audio')

    $reported = @(Get-Content $runOut | Select-String -Pattern 'UPGPROBE ' |
        ForEach-Object { ($_ -split 'UPGPROBE ', 2)[1].TrimEnd() })
    if ($reported.Count -eq 0) { throw 'the probe reported nothing.' }
    $reported | ForEach-Object { Write-Host $_ }
    if ($reported[-1] -ne 'done') {
        Write-Host ''
        Write-Host 'NOTE: the run ended before the report. Raise -Ticks or the benchmark budget.'
    }
}
finally {
    if (-not $KeepTemp) {
        Remove-ModJunctions -ModDirectory $modDir
        Remove-TempDirectory -Path $temp -Label 'probe-next-upgrade'
    } else { Write-Host "kept: $temp" }
}

Write-Host ''
Write-Host 'Probe finished. Exit 0 means it ran and reported, not that the answer was yes.'

#Requires -Version 7
<#
.SYNOPSIS
    Probes what Factorio's Quality mechanic actually scales on this mod's entities. The rig behind
    docs/research/quality.md.

.DESCRIPTION
    A PROBE, NOT A CHECK. Every line it prints is a measurement, and a negative answer is as much
    of a result as a positive one -- so exit 0 means the probe ran and every row reported, never
    that the answers were the ones anybody hoped for. Nothing here decides anything and nothing
    here ships. It must not be added to a check sweep, a bench sweep or to load-check.ps1.

    WHY MEASURING IS THE ONLY WAY TO ASK

    Which properties the engine multiplies by quality is not declared in any prototype and cannot
    be read out of the files. QualityPrototype's named multipliers cover assemblers, labs,
    inserters, beacons, drills, accumulators, containers, poles and robots, and say nothing at all
    about boilers, generators, pumps or storage tanks -- which are what this mod is almost entirely
    made of. Those types scale anyway, by default_multiplier, with no field naming them. Neither
    BoilerPrototype nor GeneratorPrototype has a single quality property at 2.0.77.

    There is a reliable TELL in the runtime API: a property quality scales is exposed as a method
    taking an optional QualityID, and one it does not scale stays a plain attribute. That is how
    control.lua came to call get_max_energy_production() rather than read the field, and it is what
    check-buffer.ps1 and check-brownout.ps1 both record. But the tell is NECESSARY AND NOT
    SUFFICIENT: get_fluid_capacity takes a quality and returns the same number at all five levels
    on every entity here. So the tell narrows the question and the answer still has to be measured,
    which is this file.

    THE ONE ANSWER THE WHOLE RESEARCH NOTE RESTS ON is that fluid box capacity does not scale.
    Had it scaled, a legendary rf-reactor would hold 2500 units of plasma in a volume_m3 that is a
    Lua constant at 1000 -- 2.5x the density, and because the reaction rate goes as n^2 at fixed
    volume, 6.25x the fusion power, while reactor-logic.lua went on reporting a Q computed from a
    density it had assumed. That is the failure the note went looking for. It does not happen, and
    nothing in the prototype files says it does not happen.

    WHAT IT REPORTS

      quality   The quality set the loaded mods define, with each level. The levels are 0, 1, 2, 3
                and 5 -- legendary JUMPS to 5, which is where +150% comes from rather than +120%,
                and anyone writing 1 + 0.3 * index gets it wrong.

                quality-unknown is excluded from every measurement below. It is the engine's
                placeholder for a quality a save refers to and the current mod set does not define
                (core/prototypes/unknown.lua, level 0, hidden), not a level a player can hold.

      proto     The quality_affects_* booleans and the *_quality_multiplier dictionaries, which are
                the only per-property levers a mod author has -- and they exist on crafting
                machines and containers only.

      get       Every quality-taking getter, at every level, labelled SCALES or flat by comparing
                the five answers. This is the section that answers the capacity question.

      src       The electric energy source: buffer_capacity and drain as plain attributes, the two
                flow limits through their getters. The asymmetry is the tell doing its work --
                the buffer has no quality form and the flow limits do.

      placed    The same questions asked of REAL ENTITIES on a surface, at each level, through
                fluidbox.get_capacity, electric_buffer_size and the container inventory. The
                prototype getters and the placed entities are both reported because they are two
                different reads and only the second is what the simulation actually sees.

      GEN       The generator ratio, which is the thing that would or would not be free energy: the
                fluid a generator burns per tick against the power cap it declares, per level. If
                the cap scaled faster than the usage, a legendary machine would convert more
                cheaply than a normal one and the mod's energy ledger would have a hole in it.

      BOILER    Every boiler's target_temperature, and the fluid energy source effectivity of the
                two that have one -- a plain attribute with no quality form, and the other place an
                efficiency could have hidden. The reactors and the collector report no effectivity,
                which is the row saying their energy source is electric or void rather than a gap in
                the reading. rf-reactor's target_temperature is the number the research note's
                residual-leak arithmetic is built on, which is why the row asks every boiler rather
                than the two exchangers it started with.

    VANILLA CONTROLS

    boiler, heat-exchanger, steam-turbine, storage-tank and steel-chest are measured alongside
    ours, and they are not padding. They are entities whose quality behaviour is Wube's rather than
    this repository's, so a flat reading on ours means something only if a vanilla entity of the
    same prototype type reads the same way. steam-turbine additionally carries a GEN row, because
    the ratio being exactly 1 on a machine nobody here wrote is what says the ratio is the engine's
    property and not an accident of our numbers.

    WHAT IT DOES NOT DO

    It places entities and reads what the engine reports. It does not step the simulation, light a
    reactor or watch a power network -- so the note's central conclusion, that a legendary reactor
    reaches the same equilibrium as a normal one because every input to that equilibrium is
    quality-flat, is a DEDUCTION from measured prototype values rather than an observation of two
    reactors side by side. Closing that means a probe that lights a legendary reactor next to a
    normal one and compares temperature and Q. This is not that probe.

    A NOTE FOR ANYONE TEMPTED TO ASSERT AGAINST THESE NUMBERS

    The multiplied values round-trip through float32 and three of the five come back short:
    fluid_usage_per_tick on steam-turbine reads 1, 1.2999999523163, 1.6000000238419,
    1.8999999761581, 2.5. Normal and legendary are exact; uncommon, rare and epic are not. Any
    check built on this would need a tolerance, the same way check-hc.ps1 does.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER SpaceAge
    Enable space-age instead of quality alone.

    THE SWITCH IS THE POINT, and both runs have to stay possible. QualityPrototype.level at 2.0.77
    carries the note "Requires Space Age to use level greater than 0", which read literally would
    mean quality does nothing under base + quality. Measured, it does not mean that: with
    space-age explicitly disabled the four higher levels still report 1, 2, 3, 5 and every
    multiplier is unchanged. That finding is what ADR 0003 needs -- it tolerates Space Age rather
    than targeting it, and a player may well run quality on its own -- and it is only checkable
    while both configurations can still be run and compared.

    Without the switch, the bundled quality mod alone. With it, space-age, which pulls in quality
    and elevated-rails through Resolve-BundledSelection.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/probe-quality.ps1

.EXAMPLE
    pwsh -File scripts/probe-quality.ps1 -SpaceAge

    The second configuration. Every number the research note quotes was identical across the two,
    which is the claim these two runs together support.
#>
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [switch] $SpaceAge,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$rigName  = 'rf-quality-probe'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-quality-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

function Write-Rig {
    @{
        name = $rigName; version = '0.0.1'; title = 'Quality probe'
        author = 'probe-quality.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'data.lua') -Value '-- nothing; this rig reads, it does not declare'

    $lua = @'
-- Generated by probe-quality.ps1. Nothing here ships. Reports; asserts nothing.

local function say(fmt, ...) log("QPROBE " .. string.format(fmt, ...)) end

-- Every entity this mod ships, plus the vanilla controls. The controls are not padding: a flat
-- reading on ours means something only against an entity of the same prototype type whose quality
-- behaviour is Wube's rather than this repository's.
local OURS = {
  "rf-reactor", "rf-aneutronic-reactor", "rf-lithium-blanket", "rf-heater",
  "rf-heat-exchanger", "rf-hc-exchanger", "rf-hc-turbine", "rf-direct-energy-converter",
  "rf-isotope-collector", "rf-aneutronic-composite-tank", "rf-pipe", "rf-pipe-to-ground",
  "rf-pump", "rf-electrolyser", "rf-deuterium-extractor", "rf-brine-concentrator",
  "rf-gas-mixer", "rf-lithium-extractor",
  "steam-turbine", "heat-exchanger", "storage-tank", "steel-chest", "boiler",
}

script.on_nth_tick(60, function()
  if storage.done then return end
  storage.done = true

  -- ------------------------------------------------------------ the quality set
  local levels = {}
  for name, q in pairs(prototypes.quality) do
    levels[#levels + 1] = { name = name, level = q.level, hidden = q.hidden }
  end
  table.sort(levels, function(a, b)
    if a.level ~= b.level then return a.level < b.level end
    return a.name < b.name
  end)
  for _, q in ipairs(levels) do
    say("quality %-16s level=%d hidden=%s", q.name, q.level, tostring(q.hidden))
  end

  -- quality-unknown is the engine's placeholder for a quality a save names and the mod set does
  -- not define. It is hidden and no player can hold one, so measuring at it would add a sixth
  -- column that means nothing and would make a "flat" verdict harder to read, not easier.
  local order = {}
  for _, q in ipairs(levels) do
    if q.name ~= "quality-unknown" then order[#order + 1] = q.name end
  end

  -- ------------------------------------------------------------ prototype-side flags
  for _, name in ipairs(OURS) do
    local p = prototypes.entity[name]
    if not p then
      -- Reported rather than skipped. A renamed prototype would otherwise drop silently out of
      -- every table below and read as a clean run over a shorter list.
      say("MISSING prototype %s", name)
    else
      say("proto %-30s type=%-20s q_energy=%s q_inv=%s q_slots=%s q_supply=%s q_mining=%s",
        name, p.type,
        tostring(p.quality_affects_energy_usage), tostring(p.quality_affects_inventory_size),
        tostring(p.quality_affects_module_slots), tostring(p.quality_affects_supply_area_distance),
        tostring(p.quality_affects_mining_radius))
      local eum, csm = {}, {}
      for k, v in pairs(p.energy_usage_quality_multiplier or {}) do eum[#eum + 1] = k .. "=" .. tostring(v) end
      for k, v in pairs(p.crafting_speed_quality_multiplier or {}) do csm[#csm + 1] = k .. "=" .. tostring(v) end
      table.sort(eum) table.sort(csm)
      if #eum > 0 then say("proto %-30s energy_usage_quality_multiplier %s", name, table.concat(eum, " ")) end
      if #csm > 0 then say("proto %-30s crafting_speed_quality_multiplier %s", name, table.concat(csm, " ")) end
    end
  end

  -- ------------------------------------------------------------ prototype getters per quality
  -- SCALES or flat is decided by comparing the five answers rather than against the multiplier
  -- table, because the whole question is whether the engine applies the multiplier here at all.
  local function getter(name, fn)
    local p = prototypes.entity[name]
    if not p or type(p[fn]) ~= "function" then return end
    local parts, differs, first = {}, false, nil
    for _, q in ipairs(order) do
      local ok, v = pcall(function() return p[fn](q) end)
      local shown = ok and tostring(v) or ("ERR:" .. tostring(v))
      if first == nil then first = shown elseif shown ~= first then differs = true end
      parts[#parts + 1] = string.format("%s=%s", q, shown)
    end
    say("get %-28s %-28s %-6s %s", name, fn, differs and "SCALES" or "flat", table.concat(parts, " "))
  end

  for _, name in ipairs(OURS) do
    if prototypes.entity[name] then
      getter(name, "get_fluid_capacity")
      getter(name, "get_max_energy_usage")
      getter(name, "get_max_energy_production")
      getter(name, "get_max_power_output")
      getter(name, "get_fluid_usage_per_tick")
      getter(name, "get_crafting_speed")
      getter(name, "get_pumping_speed")
    end
  end

  for _, name in ipairs({ "rf-lithium-blanket", "steel-chest" }) do
    local p = prototypes.entity[name]
    if p then
      local parts = {}
      for _, q in ipairs(order) do
        local ok, v = pcall(function() return p.get_inventory_size(defines.inventory.chest, q) end)
        parts[#parts + 1] = string.format("%s=%s", q, ok and tostring(v) or ("ERR:" .. tostring(v)))
      end
      say("get %-28s %-28s        %s", name, "get_inventory_size(chest)", table.concat(parts, " "))
    end
  end

  -- The electric energy source, where the tell is visible in one place: buffer_capacity and drain
  -- are plain attributes with no quality form, and the two flow limits are methods that take one.
  for _, name in ipairs({ "rf-reactor", "rf-aneutronic-reactor", "rf-heater", "rf-electrolyser" }) do
    local p = prototypes.entity[name]
    local s = p and p.electric_energy_source_prototype
    if s then
      local inp, outp = {}, {}
      for _, q in ipairs(order) do
        local ok, v = pcall(function() return s.get_input_flow_limit(q) end)
        inp[#inp + 1] = string.format("%s=%s", q, ok and tostring(v) or "ERR")
        local ok2, v2 = pcall(function() return s.get_output_flow_limit(q) end)
        outp[#outp + 1] = string.format("%s=%s", q, ok2 and tostring(v2) or "ERR")
      end
      say("src %-28s buffer_capacity=%.10g drain=%.10g", name, s.buffer_capacity, s.drain)
      say("src %-28s get_input_flow_limit   %s", name, table.concat(inp, " "))
      say("src %-28s get_output_flow_limit  %s", name, table.concat(outp, " "))
    end
  end

  -- ------------------------------------------------------------ placed entities
  -- The prototype getters above and the placed reads below are two different questions. Only the
  -- second is what the simulation actually sees: control.lua reads box.get_capacity off a live
  -- entity, not off the prototype.
  local surface = game.create_surface("qprobe", {
    water = 0,
    starting_area = 0,
    autoplace_controls = {},
    default_enable_all_autoplace_controls = false,
    cliff_settings = { name = "cliff", cliff_elevation_0 = 1e9, cliff_elevation_interval = 1e9 },
    autoplace_settings = {
      entity = { treat_missing_as_default = false, settings = {} },
      decorative = { treat_missing_as_default = false, settings = {} },
      tile = { treat_missing_as_default = true, settings = {} },
    },
  })
  surface.request_to_generate_chunks({ 300, 0 }, 25)
  surface.force_generate_chunk_requests()
  local force = game.forces.player

  -- Name, and how many fluid boxes to read on it. The count is written down rather than discovered
  -- because get_capacity on an index the entity does not have is an error, not a nil.
  local placed = {
    { "rf-reactor", 2 }, { "rf-aneutronic-reactor", 2 }, { "rf-lithium-blanket", 0 },
    { "rf-heat-exchanger", 2 }, { "rf-hc-exchanger", 2 }, { "rf-hc-turbine", 1 },
    -- The collector is TWO: prototypes/entities.lua gives it fluid_box (rf-tritium) and
    -- output_fluid_box (rf-helium-3) and nothing else. It said four until #97 ran the thing and read
    -- the row it printed -- ten ERR cells, five levels by two boxes that were never there.
    { "rf-direct-energy-converter", 1 }, { "rf-isotope-collector", 2 },
    { "rf-aneutronic-composite-tank", 1 }, { "rf-heater", 4 }, { "steam-turbine", 1 },
    { "rf-pipe", 1 },
  }
  local x = 0
  for _, row in ipairs(placed) do
    local name, boxes = row[1], row[2]
    -- Sixty tiles apart in both axes: far enough that no two of these ever join a fluid segment or
    -- share an electric network, so a capacity read is the entity's own and not a segment's.
    local y = -200
    local caps, buffers, invs = {}, {}, {}
    for _, q in ipairs(order) do
      local ok, e = pcall(function()
        return surface.create_entity({
          name = name, position = { x, y }, force = force, quality = q, raise_built = false })
      end)
      if not ok or not e then
        caps[#caps + 1] = q .. "=PLACE-FAIL(" .. tostring(e) .. ")"
      else
        local parts = {}
        for i = 1, boxes do
          local ok2, c = pcall(function() return e.fluidbox.get_capacity(i) end)
          parts[#parts + 1] = ok2 and string.format("%.10g", c) or "ERR"
        end
        caps[#caps + 1] = string.format("%s=[%s]", q, table.concat(parts, ","))
        local ok3, buf = pcall(function() return e.electric_buffer_size end)
        if ok3 and buf then buffers[#buffers + 1] = string.format("%s=%.10g", q, buf) end
        local inv = e.get_inventory(defines.inventory.chest)
        if inv then invs[#invs + 1] = string.format("%s=%d", q, #inv) end
      end
      y = y + 60
    end
    say("placed %-28s fluidbox capacities  %s", name, table.concat(caps, " "))
    if #buffers > 0 then say("placed %-28s electric_buffer_size %s", name, table.concat(buffers, " ")) end
    if #invs > 0 then say("placed %-28s inventory size       %s", name, table.concat(invs, " ")) end
    x = x + 60
  end

  -- ------------------------------------------------------------ the ratio that would be free energy
  for _, fname in ipairs({ "rf-reactor-energy", "rf-aneutronic-reactor-energy", "steam" }) do
    local f = prototypes.fluid[fname]
    if f then
      say("fluid %-30s fuel_value=%.10g heat_capacity=%.10g default_temperature=%.10g max_temperature=%.10g",
        fname, f.fuel_value or 0, f.heat_capacity or 0, f.default_temperature or 0, f.max_temperature or 0)
    end
  end

  -- out/in is the whole perpetual-motion question in one number. The generator's declared power cap
  -- against the energy content of the fluid it is allowed to draw per tick: if the cap ever scaled
  -- faster than the usage, a legendary machine would convert more cheaply than a normal one.
  --
  -- Derived two ways because generators are two kinds. One burns its fluid and takes fuel_value per
  -- unit; the other takes the heat between the fluid's default temperature and the generator's
  -- maximum, which is heat_capacity's business.
  local function generator_ratio(ename, fname)
    local g, f = prototypes.entity[ename], prototypes.fluid[fname]
    if not g or not f then return end
    for _, q in ipairs(order) do
      local usage = g.get_fluid_usage_per_tick(q) or 0
      local cap   = (g.get_max_power_output(q) or 0) * 60
      local burns = g.burns_fluid
      local input_w
      if burns then
        input_w = usage * 60 * (f.fuel_value or 0)
      else
        input_w = usage * 60 * ((g.maximum_temperature or 0) - (f.default_temperature or 0)) * (f.heat_capacity or 0)
      end
      local eff = g.effectivity or 1
      say("GEN %-28s %-10s burns=%-5s usage/tick=%.10g input=%.6g W declared_cap=%.6g W eff=%.4g out/in=%.6f",
        ename, q, tostring(burns), usage, input_w, cap,
        eff, input_w > 0 and (math.min(cap, input_w * eff) / input_w) or -1)
    end
  end
  generator_ratio("rf-direct-energy-converter", "rf-aneutronic-reactor-energy")
  generator_ratio("rf-hc-turbine", "steam")
  generator_ratio("steam-turbine", "steam")

  -- The other place an efficiency could have hidden. A fluid energy source's effectivity is a plain
  -- attribute, so by the tell it does not scale -- reported rather than reasoned.
  --
  -- EVERY BOILER, not just the two with a fluid energy source, because target_temperature is the
  -- other number this row carries and the research note's residual-leak arithmetic is built on
  -- rf-reactor's. The reactors report no effectivity at all, which is the row saying their energy
  -- source is electric -- a nil here is a reading, not a hole.
  for _, ename in ipairs({ "rf-reactor", "rf-aneutronic-reactor", "rf-heat-exchanger",
                           "rf-hc-exchanger", "rf-isotope-collector" }) do
    local ex = prototypes.entity[ename]
    if ex then
      local fs = ex.fluid_energy_source_prototype
      say("BOILER %-24s target_temperature=%s fluid_source_effectivity=%s burns_fluid=%s",
        ename, tostring(ex.target_temperature),
        tostring(fs and fs.effectivity), tostring(fs and fs.burns_fluid))
    end
  end

  say("done")
end)
'@
    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') -Value $lua
}

$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    $want = if ($SpaceAge) { @('space-age') } else { @('quality') }
    $enabled = Resolve-BundledSelection -Requested $want -Bundled $bundled
    Write-Host "bundled enabled: $($enabled -join ', ')"
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabled -Mods ($ourMods + $rigName)
    Write-Rig

    $save = Join-Path $temp 'quality-probe.zip'
    Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create' | Out-Null
    # 240 ticks against a report on the first multiple of 60: generous, and nothing here measures a
    # rate, so the only requirement is that the surface has generated by the time the rig reports.
    $runOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', '240', '--benchmark-runs', '1', '--disable-audio')

    $reported = @(Get-Content $runOut | Select-String -Pattern 'QPROBE ' |
        ForEach-Object { ($_ -split 'QPROBE ', 2)[1].TrimEnd() })
    if ($reported.Count -eq 0) { throw 'the rig reported nothing; it never reached its report tick.' }

    foreach ($line in $reported) { Write-Host "  $line" }

    # The sentinel, for the same reason probe-energy-containment checks for one: a rig that died
    # part way through its report prints rows that look exactly like a complete run.
    if (-not ($reported | Where-Object { $_ -eq 'done' })) {
        throw 'the rig stopped before the end of its report; the rows above are incomplete.'
    }

    Write-Host ''
    Write-Host 'OK - the probe ran and every row reported. The answers are above, and they are'
    Write-Host '     measurements rather than a verdict, so nothing here passes or fails.'
    Write-Host '     docs/research/quality.md is what they were read into.'
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'probe-quality' }
}

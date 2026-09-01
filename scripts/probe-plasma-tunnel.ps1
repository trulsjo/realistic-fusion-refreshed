<#
.SYNOPSIS
    Probe: does plasma actually cross a pipe-to-ground tunnel on the seablock lane, with and
    without the npt opt-out?

.DESCRIPTION
    A PROBE, NOT A GATE. It asserts nothing and exits 0 whatever it finds. Every row is a
    measurement, and a row that reports the hole open is as much of a result as one reporting it
    shut.

    WHY THIS EXISTS, AND WHY IT IS NOT THE CATEGORY PROBE

    scripts/probe-connection-categories.ps1 reads PROTOTYPES. It established that on the seablock
    lane `no-pipe-touching` 1.1.28 writes the literal "pipe-to-ground" over rf-pipe-to-ground's
    underground connection and appends twelve categories to its surface one. That is a measurement
    about a DECLARATION.

    "The declaration is gone" and "the plasma moves" are two claims, and only the first was
    measured. #208 chose to take the mod's opt-out on the strength of the first, and required this
    one before the answer ships -- because the argument that the hole matters rests on a reading of
    somebody else's Lua that nobody had run: that the mod gives VANILLA's pipe-to-ground the
    category "pipe-to-ground" too (its own name, data-final-fixes.lua:160), so after the rewrite the
    two match exactly and a player's vanilla tunnel pairs with ours. This probe runs it.

    WHAT IS BUILT, and why it is five subjects rather than one

    Every subject is placed on a real map with the whole 46-mod seablock set loaded, fed plasma, and
    read after the fluid has had time to cross.

      hole-under   A deepcopy of the SHIPPED rf-pipe-to-ground with npt_compat REMOVED, so the mod
                   rewrites it exactly as it rewrote the shipped one before #208. Paired underground
                   with a VANILLA pipe-to-ground. If plasma crosses, the tunnel is real and the
                   decision rested on something true.

      hole-surface The same unprotected copy, with a bob pipe laid against its SURFACE connection.
                   #208 scoped the response to both connections, so both halves of the breach are
                   measured rather than the louder one only.

      fix-under    The SHIPPED rf-pipe-to-ground, which carries the opt-out, paired underground with
                   a vanilla pipe-to-ground. Must refuse.

      fix-surface  The shipped one with a bob pipe against its surface connection. Must refuse.

      control      The shipped one against an rf-pipe, which shares rf-plasma. MUST JOIN and MUST
                   carry plasma. This is the instrument's calibration and it is not optional: a
                   fault in the placement arithmetic, the fluid name or the feed reads exactly like
                   containment working, and every refusal above would be unfalsifiable without it.
                   probe-energy-containment.ps1 says the same thing about its own control and it is
                   the reason that probe's negatives are worth anything.

    WHY A DEEPCOPY FOR THE HOLE ROWS rather than reverting the shipped prototype: the hole and the
    fix are then measured in ONE run, on ONE map, against ONE loaded copy of the set. Two runs would
    be two mod configurations and two chances for something other than the opt-out to differ.

    THE COPY DIFFERS IN FOUR FIELDS, NOT ONE, and saying otherwise would be the overclaim this
    repository keeps catching. `npt_compat` is the one under test. `name` must differ or it is not a
    second prototype. `minable`, `fast_replaceable_group` and `next_upgrade` are nilled because they
    name an item and prototypes that belong to the ORIGINAL -- a copy keeping them mines into the
    shipped item and offers an upgrade path to itself, which is the same reason
    probe-energy-containment.ps1's bare() helper nils them. None of the three is read by the pass
    under test: its guard consults `npt_compat`, `solved_by_npt` and whether any connection holds a
    default category, and nothing else. So the difference that matters is still one field -- but the
    diff is four, and the reader should be told which.

    WHAT THIS CANNOT SHOW. It measures fluid crossing between two entities a player can place. It
    says nothing about the other thirteen lanes (probe-connection-categories.ps1 covers those at the
    declaration level), nothing about a later release of that mod, and nothing about any mod nobody
    has fetched.

    Findings are written up in docs/research/plasma-tunnel.md.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER AlsoModDirectory
    The lane's unpacked mods. Defaults to .mod-cache/seablock, which is the lane this exists for;
    a parameter so a future lane can be asked the same question without editing the script.

.PARAMETER With
    Bundled mods to enable. Defaults to quality, which is what ADR 0007's seablock lane runs.

.PARAMETER Settle
    Ticks before the report. Only has to be long enough for fluid to cross a joined segment.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/fetch-mods.ps1 -Set seablock
    pwsh -File scripts/probe-plasma-tunnel.ps1
#>

#Requires -Version 7

[CmdletBinding()]
param(
    [string]   $FactorioExe,
    [string]   $AlsoModDirectory,
    [string[]] $With = @('quality'),
    [ValidateRange(60, [int]::MaxValue)] [int] $Settle = 600,
    [switch]   $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$rigName  = 'rf-tunnel-probe-rig'

if (-not $AlsoModDirectory) { $AlsoModDirectory = Join-Path $repoRoot '.mod-cache/seablock' }
if (-not (Test-Path $AlsoModDirectory)) {
    throw ("-AlsoModDirectory not found: $AlsoModDirectory. Fetch the lane first: " +
           'pwsh -File scripts/fetch-mods.ps1 -Set seablock')
}
$AlsoModDirectory = (Resolve-Path -LiteralPath $AlsoModDirectory).Path
$alsoMods = @(Get-ChildItem -Path $AlsoModDirectory -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName 'info.json') } |
    ForEach-Object { $_.Name } | Sort-Object)
if (-not $alsoMods) { throw "-AlsoModDirectory holds no mod directories: $AlsoModDirectory" }

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe
try   { $enabledBundled = Resolve-BundledSelection -Requested $With -Bundled $bundled }
catch { throw "-With $($_.Exception.Message)" }

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-tunnel-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

@{
    name = $rigName; version = '0.0.1'; title = 'Plasma tunnel probe'
    author = 'probe-plasma-tunnel.ps1'; factorio_version = '2.0'
    # After the mod under study, so the unprotected copy it rewrites is the one this rig placed.
    # Declared rather than assumed: data-final-fixes order is dependency depth first, then name.
    dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed', '? no-pipe-touching')
} | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

# ------------------------------------------------------------------------------ the rig's data
#
# Write-PlasmaFeed OWNS data.lua -- it writes the file rather than appending to it -- so the feed is
# created first and the one subject prototype is appended after. Written the other way round, the
# subject silently vanished and every row read as "partner prototype is not in this game".

# The plasma feed: an infinity pipe carrying the plasma category, because a vanilla one cannot join a
# contained line at all. Shared with every other rig here so they cannot drift.
$feedName = Write-PlasmaFeed -RigDirectory $rigDir
# Write-PlasmaFeed owns data.lua, so the subject above has to be appended rather than overwritten.
$feedLua = Get-Content -LiteralPath (Join-Path $rigDir 'data.lua') -Raw
$subject = @'

-- Appended by probe-plasma-tunnel.ps1: the unprotected copy, after Write-PlasmaFeed's own data.lua.
local shipped = data.raw["pipe-to-ground"]["rf-pipe-to-ground"]
if not shipped then error("the probe needs rf-pipe-to-ground and it is missing") end
if not shipped.npt_compat then
  error("rf-pipe-to-ground carries no npt_compat -- this probe exists to measure that field, and " ..
        "without it the fix rows and the hole rows would be the same subject")
end
local bare = table.deepcopy(shipped)
bare.name = "rf-probe-tunnel-bare"
bare.npt_compat = nil
bare.minable = nil
bare.fast_replaceable_group = nil
bare.next_upgrade = nil
data:extend({ bare })
'@
Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'data.lua') -Value ($feedLua + $subject)

# ------------------------------------------------------------------------------ the rig's control
$control = @'
-- Generated by scripts/probe-plasma-tunnel.ps1 (#208). Nothing here ships.

local FEED   = "__FEED__"
local SETTLE = __SETTLE__
local PLASMA = "rf-d-d-plasma"
local BARE   = "rf-probe-tunnel-bare"    -- the shipped pipe-to-ground minus npt_compat
local SHIP   = "rf-pipe-to-ground"       -- the shipped one, carrying the opt-out

local function say(fmt, ...) log("TUNNEL " .. string.format(fmt, ...)) end

-- GEOMETRY IS COPIED FROM scripts/check-containment.ps1's tunnel row, which is a GATE that passes
-- today, and every part of it is load-bearing:
--
--   * positions sit on half-tile centres. A 1x1 entity centred on an integer is snapped somewhere
--     else, and the first version of this probe put every entity one half-tile off and read five
--     zeroes -- including the control, which is how the mistake was caught rather than published.
--   * `direction` on a pipe-to-ground is the ABOVEGROUND connection's facing, so a west-facing one
--     takes its feed from the west and sends its tunnel east.
--   * the infinity filter needs `temperature` and `mode`. Plasma runs at 6e8 K and a filter without
--     a temperature does not fill.
--   * feed and subject must be ADJACENT. The first version left a two-tile gap, which no category
--     can bridge, so every row would have read "contained" no matter what.
--
-- Each row is the same five-tile chain and they differ only in two prototypes:
--
--   feed(x0) -> A(x0+1, facing west) ......tunnel...... B(x0+6, facing east) -> partner(x0+7)
--
-- A and B are both the subject prototype. Plasma is pushed into A's surface connection, crosses the
-- tunnel to B, and leaves through B's surface connection into the partner. Reporting A, B and the
-- partner separately is what tells a refused TUNNEL apart from a refused SURFACE.
--
-- The under-rows replace B with the partner itself: a VANILLA pipe-to-ground facing A across open
-- ground, which is exactly the claim entities.lua makes -- that one cannot tunnel in from out of
-- sight.
local X0, GAP = 40.5, 6

local ROWS = {
  { key = "hole-under",   y =  0.5, subject = BARE, partner = "pipe-to-ground",  mode = "under",
    expect = "partner CROSSES if the tunnel is real" },
  { key = "fix-under",    y = 10.5, subject = SHIP, partner = "pipe-to-ground",  mode = "under",
    expect = "partner must stay 0" },
  { key = "hole-surface", y = 20.5, subject = BARE, partner = "bob-copper-pipe", mode = "surface",
    expect = "partner CROSSES if the widening is real" },
  { key = "fix-surface",  y = 30.5, subject = SHIP, partner = "bob-copper-pipe", mode = "surface",
    expect = "partner must stay 0" },
  { key = "control",      y = 40.5, subject = SHIP, partner = "rf-pipe",         mode = "surface",
    expect = "partner MUST cross -- the calibration" },
}

local function place(surface, name, x, y, dir)
  local force = game.forces.player
  if not prototypes.entity[name] then return nil, name .. " is not a prototype in this game" end
  local e = surface.create_entity{ name = name, position = { x, y }, force = force, direction = dir }
  if not e then return nil, name .. " refused to build at " .. x .. "," .. y end
  return e, nil
end

local function build(surface, r)
  local out = { key = r.key, expect = r.expect }

  local feed, err = place(surface, FEED, X0, r.y, nil)
  if not feed then out.note = err; return out end
  feed.set_infinity_pipe_filter{ name = PLASMA, percentage = 1, temperature = 6e8, mode = "at-least" }

  out.a, err = place(surface, r.subject, X0 + 1, r.y, defines.direction.west)
  if not out.a then out.note = err; return out end

  if r.mode == "under" then
    -- The partner IS the far tunnel end: a vanilla pipe-to-ground facing back at ours.
    out.partner, err = place(surface, r.partner, X0 + GAP, r.y, defines.direction.east)
  else
    -- A second one of the SAME prototype completes the tunnel, and the partner hangs off its
    -- aboveground face -- the connection the widening opens.
    out.b, err = place(surface, r.subject, X0 + GAP, r.y, defines.direction.east)
    if not out.b then out.note = err; return out end
    out.partner, err = place(surface, r.partner, X0 + GAP + 1, r.y, nil)
  end
  if not out.partner then out.note = err; return out end
  return out
end

script.on_init(function()
  local surface = game.surfaces[1]
  surface.always_day = true
  storage.rows = {}
  for _, r in ipairs(ROWS) do storage.rows[#storage.rows + 1] = build(surface, r) end
end)

local function held(entity)
  if not (entity and entity.valid) then return -1 end
  local total = 0
  for i = 1, #entity.fluidbox do
    local box = entity.fluidbox[i]
    if box and box.name == PLASMA then total = total + box.amount end
  end
  return total
end

local function show(v) if v < 0 then return "-" else return string.format("%.3f", v) end end

script.on_event(defines.events.on_tick, function(event)
  if storage.reported or event.tick < SETTLE then return end
  storage.reported = true

  say("--- plasma held after %d ticks -------------------------------------------------", SETTLE)
  say("%-13s %-22s %-18s %9s %9s %9s  %s",
      "row", "subject", "partner", "near", "far", "partner", "expected")
  for _, r in ipairs(storage.rows) do
    if r.note then
      say("%-13s %-22s %-18s %9s %9s %9s  %s", r.key, "-", "-", "NOT BUILT", "-", "-", r.note)
    else
      say("%-13s %-22s %-18s %9s %9s %9s  %s", r.key, r.a.name, r.partner.name,
          show(held(r.a)), show(r.b and held(r.b) or -1), show(held(r.partner)), r.expect)
    end
  end
  say("done")
end)
'@
$control = $control.Replace('__FEED__', $feedName).Replace('__SETTLE__', [string]$Settle)
Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') -Value $control

# ------------------------------------------------------------------------------------------- run
$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }
try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    New-ModJunctions -ModDirectory $modDir -RepoRoot $AlsoModDirectory -Mods $alsoMods
    Write-Host "set: $($alsoMods.Count) mod(s) at $AlsoModDirectory"
    Write-Host "bundled enabled: $(if ($enabledBundled) { $enabledBundled -join ', ' } else { 'none (base 2.0 only)' })"
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabledBundled `
        -Mods ($ourMods + $alsoMods + $rigName)

    $save = Join-Path $temp 'tunnel.zip'
    Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create' | Out-Null
    $runOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', [string]($Settle + 120),
        '--benchmark-runs', '1', '--disable-audio')

    $reported = @(Get-Content $runOut | Select-String -Pattern 'TUNNEL ' |
        ForEach-Object { ($_ -split 'TUNNEL ', 2)[1].TrimEnd() })
    if ($reported.Count -eq 0) { throw 'the probe reported nothing.' }
    $reported | ForEach-Object { Write-Host $_ }
    if ($reported[-1] -ne 'done') {
        Write-Host ''
        Write-Host 'NOTE: the run ended before the report. Raise -Settle or the benchmark budget.'
    }

    Write-Host ''
    Write-Host 'This is a probe. Exit 0 means it ran and reported, not that the answer was the'
    Write-Host 'hoped-for one. Findings go in docs/research/plasma-tunnel.md.'
}
finally {
    # Unconditionally, and before any removal: the junctions point at the repository and at the
    # cache, and anything deleting this directory recursively follows them.
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'probe-plasma-tunnel' }
    else { Write-Host "kept: $temp (mod junctions removed)" }
}

#Requires -Version 7
<#
    Shared helpers for the scripts in this directory. Dot-source it:

        . "$PSScriptRoot/factorio-lib.ps1"

    The bundled-mod handling lives here rather than in each script because the same
    case-folding fault was introduced twice in two places: PowerShell's -in, -notin and its
    hashtables are case-insensitive, while HashSet[string] is ordinal, so an uncanonicalised
    name validates, then silently fails to match, then gets written disabled while the caller
    reports it as enabled. One implementation, fixed once.

    THE RUNNING OF FACTORIO IS THE SHARED HARNESS'S (#458). Resolve-FactorioExe,
    Get-FactorioDataDirectory, ConvertTo-NativeArgument, Invoke-Factorio, Write-FactorioTail,
    Remove-TempDirectory, Get-BundledMods, Resolve-BundledSelection, Write-ModList,
    Remove-ModJunctions and New-ModJunctions come from
    vendor/grado-factorio-tools/scripts/load-harness-lib.ps1, which this file dot-sources, so
    every script here gets them without naming the submodule. They moved there from this file
    (grado-factorio-tools#16); the case-folding note above is now Resolve-BundledSelection's there.
#>

$harnessLib = Join-Path $PSScriptRoot '../vendor/grado-factorio-tools/scripts/load-harness-lib.ps1'
if (-not (Test-Path -LiteralPath $harnessLib)) {
    throw "The load harness is not at $harnessLib. Run: git submodule update --init"
}
. $harnessLib

function Stop-LaunchedGame {
    <#  Kill a game client a probe launched with Start-Process, and wait until it has really gone.
        For the finally block of every probe that opens a game window, BEFORE Remove-ModJunctions
        and Remove-TempDirectory: the order is kill, junctions, then the directory.  #>
    param(
        [System.Diagnostics.Process] $Process,
        [Parameter(Mandatory)] [string] $Label
    )

    # A KILLED GAME IS NOT GONE WHEN Kill() RETURNS (#467), and until it has gone it holds
    # write-data/.lock, the log and run-stdout.txt, so Remove-TempDirectory's second of retries
    # loses and the run directory stays in %TEMP%. It happens on the timeout path with a second
    # probe's game window open, which is also what makes the wait time out. Measured on 2.0.77
    # on 2026-09-28: one such run on the old ten-second wait left exactly the ticket's launch,
    # run-stdout.txt and write-data behind. In the seven that were timed the game took between
    # 0.3 and 13.0 s to exit after the kill, and the 13-second one, on this wait, cleaned up.
    #
    # ponytail: a fixed two-minute bound, after which the directory is left and warned about
    # as before. Raise it if a timed-out probe is ever seen to leave one again.
    if (-not $Process -or $Process.HasExited) { return }
    $Process.Kill()
    if (-not $Process.WaitForExit(120000)) {
        Write-Warning "${Label}: Factorio (pid $($Process.Id)) had not exited two minutes after it was killed."
    }
}

function Get-RepoMods {
    <#  The mods this repository publishes, in dependency order.

        Here rather than in each caller because it was a literal in twenty-two scripts until a
        third mod arrived (ADR 0023), and twenty-two copies of a list is the same fault this
        file's header describes: one of them gets missed. Callers want it as $ourMods.

        Assets first. It holds every sprite the other two reference and declares no dependency
        of its own, so nothing it needs can load after it.  #>

    return @(
        'realistic-fusion-refreshed-assets',
        'realistic-fusion-refreshed-core',
        'realistic-fusion-refreshed'
    )
}

function Get-ModTreeFingerprint {
    <#  Every file under each of our mod directories, as path, size and last write time.

        A self-test's one hazard is that its canaries break OUR prototypes to prove OUR checks
        fire. They do it in `data-final-fixes`, in memory, so nothing on disk should move -- and
        #125 asked for that to be ASSERTED rather than reasoned about, because a self-test in
        load-check.ps1 once deleted the repository's own sprite. Here rather than there since #578,
        so the self-tests of check-pooling.ps1 and check-hc.ps1, which load canaries too, assert it.

        Path, size and write time rather than a hash of the contents: it walks the assets mod, so
        reading every sprite would cost more than the loads it is guarding, and a canary that
        rewrote a file in place without changing its length is not a failure mode this has.  #>
    param([Parameter(Mandatory)] [string[]] $Mods)

    $repoRoot = Split-Path $PSScriptRoot -Parent
    $rows = foreach ($mod in $Mods) {
        $root = Join-Path $repoRoot $mod
        foreach ($file in (Get-ChildItem -LiteralPath $root -Recurse -File -Force)) {
            $rel = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
            "$mod/$rel|$($file.Length)|$($file.LastWriteTimeUtc.Ticks)"
        }
    }
    return @($rows | Sort-Object)
}

function Test-ModTreeUnchanged {
    <#  Whether our mod directories are still exactly where they were, REPORTED rather than thrown.

        Called twice by each self-test that uses it, and the second call is why it reports: once on
        the pass path, where a moved file is a failure of its own, and once from the finally block,
        so a half that exited early still says whether it left anything behind on the way out. By
        the time the finally runs the exit code is already committed, so exiting again there would
        only replace one wrong answer with another.

        FILES, NOT ROWS. Compare-Object emits one object per side, so a single modified file
        arrives as two -- reporting that as "2 file(s) changed" was a defect found in review of
        this very guard. The rows are still printed, because both sides are what places the change;
        the COUNT is of distinct paths.  #>
    param([Parameter(Mandatory)] [string[]] $Before, [Parameter(Mandatory)] [string[]] $Mods)

    $moved = @(Compare-Object -ReferenceObject $Before -DifferenceObject (Get-ModTreeFingerprint -Mods $Mods))
    if (-not $moved) { return $false }

    $paths = @($moved | ForEach-Object { ($_.InputObject -split '\|')[0] } | Sort-Object -Unique)
    Write-Host ''
    Write-Host "FAILED - self-test: $($paths.Count) file(s) under our mod directories changed during"
    Write-Host '         the run. Every half must break our prototypes in memory only.'
    foreach ($m in $moved) {
        $side = if ($m.SideIndicator -eq '=>') { 'now' } else { 'was' }
        Write-Host "           $side  $($m.InputObject)"
    }
    return $true
}

function Find-MissingAssets {
    <#  Every __mod__/... file the loaded prototypes name, that is not on disk.

        This exists because Factorio will not tell you. A headless run loads no sprites, so
        --create validates the prototype that names an icon without ever opening the file, and
        exits 0. The player's game opens it, fails, and refuses to start -- "Failed to load mods:
        File __base__/graphics/icons/heat-exchanger.png not found", which is how this was found,
        by hand, after every automated check had passed.

        Reads the --dump-data JSON rather than the Lua source. The first version of this scanned
        source text for literal "__base__/..." strings, which worked only while every path was a
        literal. It is not: the prototypes build icon paths by concatenation
        (ENTITY .. name .. ".png"), and a regex over source sees none of those -- so it would
        have reported a clean pass over the graphics this repo actually ships. The dump holds the
        paths as the game resolved them, so concatenation, loops and helper functions are all
        covered, and vanilla's paths come along for free because they are in the same dump.

        Every mod loaded is in the dump, so this walks far more than this repo -- but it only
        reports what it can resolve, which is base, core, and whatever the caller maps.

        $ModDirectories maps a mod name to where its files live on disk. Anything not in it and
        not base/core -- another mod's assets, reachable only when that mod is installed -- is
        skipped rather than reported.  #>
    param(
        [Parameter(Mandatory)] [string]    $DumpPath,
        [Parameter(Mandatory)] [string]    $DataDir,
        [Parameter(Mandatory)] [hashtable] $ModDirectories
    )

    if (-not (Test-Path -LiteralPath $DumpPath)) { throw "no data dump at '$DumpPath'." }

    $pattern = [regex] '^__(?<mod>[A-Za-z0-9_ .-]+)__/(?<rel>.+\.(?:png|ogg))$'
    $seen    = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $missing = @()

    # Walked as an object graph rather than scanned as text, for one reason: a sprite that
    # declares `stripes` keeps a `filename` beside them that the engine never opens. Vanilla has
    # such a sprite -- big-artillery-explosion names hr-bigass-explosion-36f.png, which does not
    # exist, while its two stripes name the files that do -- so a text scan reports the game's own
    # data as broken. Nothing else in the dump needed structure; this one thing did.
    $stack = [System.Collections.Generic.Stack[object]]::new()
    $stack.Push((Get-Content -LiteralPath $DumpPath -Raw | ConvertFrom-Json))

    while ($stack.Count -gt 0) {
        $node = $stack.Pop()

        if ($node -is [System.Management.Automation.PSCustomObject]) {
            $properties = $node.PSObject.Properties
            $striped = $null -ne $properties['stripes']
            foreach ($property in $properties) {
                if ($striped -and $property.Name -eq 'filename') { continue }
                if ($null -ne $property.Value) { $stack.Push($property.Value) }
            }
        }
        elseif ($node -is [System.Object[]]) {
            foreach ($item in $node) { if ($null -ne $item) { $stack.Push($item) } }
        }
        elseif ($node -is [string]) {
            $match = $pattern.Match($node)
            if (-not $match.Success -or -not $seen.Add($node)) { continue }

            $mod = $match.Groups['mod'].Value
            $root = if ($mod -in @('base', 'core')) { Join-Path $DataDir $mod }
                    elseif ($ModDirectories.ContainsKey($mod)) { $ModDirectories[$mod] }
                    else { $null }   # another mod's assets: not ours to resolve

            if ($null -eq $root) { continue }
            if (-not (Test-Path -LiteralPath (Join-Path $root $match.Groups['rel'].Value))) {
                $missing += [pscustomobject]@{ Reference = $node; Mod = $mod }
            }
        }
    }

    return @($missing | Sort-Object Reference)
}

# The name every rig in this directory uses for its plasma feed. Public so a rig's control.lua and
# Write-PlasmaFeed cannot drift apart.
$script:PlasmaFeedName = 'rf-rig-plasma-infinity-pipe'

# The rf-pump on a void energy source between that pipe and the box it feeds (#777); see
# rf_plasma_feed.
$script:PlasmaFeedPumpName = 'rf-rig-plasma-feed-pump'

# The same, for the two energy fluids. One prototype for both tiers -- see Write-EnergyFeed below.
$script:EnergyFeedName = 'rf-rig-energy-infinity-pipe'

function Add-RigData {
    <#  Append a fragment to a rig mod's data.lua, creating the file if it does not exist yet.

        WHY APPEND RATHER THAN WRITE. Write-PlasmaFeed used to OWN data.lua -- Set-Content, whole
        file -- and two rigs already worked around that by reading the file back or by
        Add-Content-ing after it, each with a comment explaining the order they had to call things
        in. A second feed (#84) makes that a collision rather than a wart: a rig needing both plasma
        and energy would silently keep whichever was written last.

        So the file is shared, and the order rigs call the writers in stops mattering.  #>
    param(
        [Parameter(Mandatory)] [string] $RigDirectory,
        [Parameter(Mandatory)] [string] $Lua
    )
    $path = Join-Path $RigDirectory 'data.lua'
    if (-not (Test-Path -LiteralPath $path)) {
        Set-Content -Encoding utf8 -Path $path `
            -Value "-- Generated by scripts/factorio-lib.ps1. Nothing here ships.`n"
    }
    Add-Content -Encoding utf8 -Path $path -Value $Lua
}

function Write-EnergyFeed {
    <#  Write a rig mod's data.lua declaring an infinity pipe that feeds or drains either energy fluid.

        IT CARRIES BOTH ENERGY CATEGORIES, AND THAT IS WHY IT EXISTS (#84, #86, #87). ADR 0018 gives
        rf-reactor-energy and rf-aneutronic-reactor-energy a connection_category each and ships no
        pipe that carries either, so a vanilla infinity-pipe is a vanilla pipe: it stopped being able
        to reach an energy box the instant containment landed, and every rig here fed or drained
        energy with one. The symptom would have been a reactor reporting itself starved, or an
        exchanger at no_input_fluid, on a perfectly good rig -- the same failure Write-PlasmaFeed
        already absorbed for plasma.

        #84 routed the rigs through this function first so that #86 was an edit HERE and not an edit
        to the two places that named a pipe for energy: check-hc.ps1's feed(), which its three ENERGY
        callers share, and bench-mod-links.ps1's drain. That is what "make the change easy, then make
        the easy change" bought, and it is what happened.

        ONE PROTOTYPE FOR BOTH TIERS. A connection_category may be a list, which is what Wube do to
        their own infinity pipe for exactly this reason -- space-age/base-data-updates.lua gives it
        {"default", "fusion-plasma"} so that an instrument can feed what nothing buildable carries.
        Two feed prototypes would be two names for rigs to choose between with nothing gained.

        `default` is deliberately NOT in the list. This pipe is an instrument for the contained
        fluids and nothing else, and a feed that also joined ordinary plumbing would quietly bridge a
        rig's water or steam run into its energy run.

        THE CATEGORIES ARE READ OFF THE SHIPPED PROTOTYPES rather than named again here, the way
        Write-PlasmaFeed reads rf-pipe's, so a rename follows the mod instead of leaving the rigs
        pointing at a category nothing declares. Read from the two REACTORS' output boxes, which is
        the one box on each tier whose category cannot be moved without the tier stopping working.

        A CATEGORISED FEED IS AN INSTRUMENT AND NOT SOMETHING A PLAYER HAS -- there is no pipe for
        either fluid. So a rig that merely needs to SUPPLY energy may use one, while a rig whose
        subject IS the reactor-to-exchanger link has to bolt the real machines together or be
        retired. check-hc.ps1 holds both shapes: its measured rows are fed, and its plant section
        bolts.

        probe-energy-containment.ps1 is deliberately NOT one of the callers. It places an ordinary
        pipe against a categorised one and measures which the machine accepts: there, the pipe's name
        is the experiment rather than incidental supply, and routing it through here would delete the
        thing it measures.

        Returns the prototype name to place.  #>
    param([Parameter(Mandatory)] [string] $RigDirectory)

    Add-RigData -RigDirectory $RigDirectory -Lua @"
-- Appended by scripts/factorio-lib.ps1 (Write-EnergyFeed).
--
-- An infinity pipe carrying BOTH energy categories under a name of our own, so one instrument feeds
-- or drains either tier. Nothing a player can build carries either (ADR 0018 item 2).

local categories = {}
for _, source in ipairs({ "rf-reactor", "rf-aneutronic-reactor" }) do
  local reactor = data.raw["boiler"][source]
  if not reactor then error(source .. " is missing; the rig cannot work out the energy connection category") end
  local category = reactor.output_fluid_box.pipe_connections[1].connection_category
  if not category then error(source .. "'s energy output carries no connection category; see ADR 0018") end
  categories[#categories + 1] = category
end

local feed = table.deepcopy(data.raw["infinity-pipe"]["infinity-pipe"])
feed.name = "$script:EnergyFeedName"
feed.minable = nil
feed.fast_replaceable_group = nil
for _, connection in ipairs(feed.fluid_box.pipe_connections) do
  connection.connection_category = categories
end
data:extend({ feed })
"@
    return $script:EnergyFeedName
}

function Write-PlasmaFeed {
    <#  Write a rig mod's data.lua declaring an infinity pipe that can feed plasma.

        Needed because the shipped plasma set carries its own pipe connection category (#26), so
        that a vanilla pipe beside a plasma line simply does not connect. A vanilla infinity-pipe is
        a vanilla pipe: it stopped being able to feed a reactor the moment containment landed, and
        every rig here fed plasma with one. The symptom is a reactor that reports "starved" on a
        perfectly good rig, which reads exactly like a broken mod.

        The category is read from the shipped rf-pipe rather than named again here, so the rigs
        follow the mod if it is ever renamed.

        SINCE #777 IT ALSO DECLARES THE PUMP rf_plasma_feed puts between the pipe and the box: a
        copy of the shipped rf-pump on a void energy source. On 2.1.23 an infinity pipe on the
        reactor's segment undoes every step, so the feed reaches the box through a pump, and void
        so that no rig has to power it.

        Returns the prototype name to place.  #>
    param([Parameter(Mandatory)] [string] $RigDirectory)

    Add-RigData -RigDirectory $RigDirectory -Lua @"
-- Appended by scripts/factorio-lib.ps1 (Write-PlasmaFeed).

local source = data.raw["pipe"]["rf-pipe"]
if not source then error("rf-pipe is missing; the rig cannot work out the plasma connection category") end
local category = source.fluid_box.pipe_connections[1].connection_category

local feed = table.deepcopy(data.raw["infinity-pipe"]["infinity-pipe"])
feed.name = "$script:PlasmaFeedName"
feed.minable = nil
feed.fast_replaceable_group = nil
for _, connection in ipairs(feed.fluid_box.pipe_connections) do
  connection.connection_category = category
end

if not data.raw["pump"]["rf-pump"] then error("rf-pump is missing; the rig's plasma feed has no pump to copy") end
local pump = table.deepcopy(data.raw["pump"]["rf-pump"])
pump.name = "$script:PlasmaFeedPumpName"
pump.minable = nil
pump.fast_replaceable_group = nil
pump.energy_source = { type = "void" }
data:extend({ feed, pump })
"@
    return $script:PlasmaFeedName
}

# The name of the Lua function Get-QuietMapLua defines. Public so a rig's control.lua and the
# fragment it calls cannot drift apart -- the same reason $script:PlasmaFeedName is public.
$script:QuietMapFunction = 'rf_quiet_map'

function Get-QuietMapLua {
    <#  Lua defining rf_quiet_map(surface): stop the map fighting back for the length of a rig run.

        LONG RUNS GET ATTACKED, and finding that out cost a fifty-minute probe run of
        check-brownout.ps1: it died with "LuaEntity API call when LuaEntity was invalid" because a
        cell's substation had been eaten. Eight heaters and an exchanger produce the pollution that
        buys that attention.

        Turned off at the source rather than defended against: a rig measuring a power balance has
        no business also being a defence exercise, and a cell that loses a substation mid-run
        produces a reading that looks like physics.

        Shared BEFORE it is copied, because check-brownout.ps1 is no longer the only rig long
        enough to be attacked: probe-quality-equilibrium.ps1 runs twenty minutes by default and
        bench-mod-links.ps1 thirty-five. Both now call this -- #189 and #190 -- so all three long
        rigs quiet the map the same way, which is the point of it being here rather than in a rig:
        three copies is where a safety guard starts to drift silently.

        The emitted function returns how many enemy entities it FOUND on the surface, all of which
        it destroys, so an adopting rig can report the figure. Found rather than destroyed because
        that is what the number counts: a destroy() that failed would raise rather than be missed.

        CALL IT AFTER THE RIG HAS GENERATED ITS CHUNKS, or the count is short and so is the clearing:
        find_entities_filtered only sees entities in chunks that already exist, so nests in an area
        generated afterwards survive. check-brownout.ps1 calls it before its own
        request_to_generate_chunks and is unharmed -- with expansion off and the surface peaceful,
        what it leaves behind never attacks -- but a rig that wants the surface actually cleared has
        to order the two calls the other way round.

        The per-rig validity guard is deliberately NOT here: knowing which entities a rig owns is
        rig-specific by nature and belongs in the rig.

        Returns the Lua to place at the top level of a rig's control.lua.  #>

    return @"
-- Generated by scripts/factorio-lib.ps1 (Get-QuietMapLua). Nothing here ships.
--
-- LONG RUNS GET ATTACKED: a fifty-minute probe run died with "LuaEntity API call when LuaEntity was
-- invalid" because a cell's substation had been eaten. A rig measuring a power balance has no
-- business also being a defence exercise, and a cell that loses a substation mid-run produces a
-- reading that looks like physics. Returns how many enemy entities it found and destroyed; call it
-- after the rig has generated its chunks, or it can see neither.
local function $script:QuietMapFunction(surface)
  game.map_settings.pollution.enabled        = false
  game.map_settings.enemy_expansion.enabled  = false
  surface.peaceful_mode = true
  local nests = surface.find_entities_filtered({ force = "enemy" })
  for _, nest in pairs(nests) do nest.destroy() end
  return #nests
end
"@
}

function Get-FixedRuleLua {
    <#  Lua defining rf_fixed_units and rf_fixed_flow: one transfer of the fixed-point rule
        docs/research/quality.md fitted to a lone box, in whole 2^-24 units (#564).

        ONE COPY FOR THE TWO PLASMA PROBES (#588). probe-plasma-segment.ps1 runs it on one reactor
        and probe-plasma-input-box.ps1 on two, and each carried its own, held together by a comment
        asking a reader to change one and change the other. The segment probe still runs all three
        roundings of the destination's fill, so the rounding is an argument; the input-box probe
        passes math.floor, the one #564 settled. The order of the transfers is each probe's own,
        because that is what the input-box probe reads.

        Returns the Lua to place at the top level of a rig's control.lua.  #>

    return @'
-- Generated by scripts/factorio-lib.ps1 (Get-FixedRuleLua). Nothing here ships.
--
-- THE FITTED FIXED-POINT RULE'S TRANSFER (#564, #588). Every amount a whole count of 2^-24 units, a
-- source's fill that count over its volume FLOORED, a transfer 100 times the smaller of the
-- source's fill and one minus the destination's, rounded by `round`. The 0.1-unit floor is
-- M.settle_segment's, 0.1 x 2^24 floored.
local rf_fixed_units = 2 ^ 24
local rf_fixed_floor = math.floor(0.1 * rf_fixed_units)
local function rf_fixed_flow(round, from, from_volume, to, to_volume)
  local rate = math.max(rf_fixed_floor,
    100 * math.min(math.floor(from / from_volume), rf_fixed_units - round(to / to_volume)))
  return math.max(0, math.min(rate, from, to_volume * rf_fixed_units - to))
end
'@
}

# The names Get-RigBuildLua defines, public for the same reason $script:QuietMapFunction is: a rig's
# control.lua and the fragment it calls must not be able to drift apart over a spelling.
$script:RigBuildFunctions = @{
    PlaceOrDie     = 'rf_place_or_die'
    BoxOf          = 'rf_box_of'
    Unbound        = 'rf_unbound'
    PlaceFacing    = 'rf_place_facing'
    PipeRun        = 'rf_pipe_run'
    AssertSegments = 'rf_assert_segments'
    AssertResearch = 'rf_assert_research'
    Ladders        = 'rf_ladders'
    Unresearch     = 'rf_unresearch'
    FluidBox       = 'rf_fluidbox'
    PlasmaFeed     = 'rf_plasma_feed'
}

function Get-RigBuildLua {
    <#  Lua defining the helpers the five rigs #226 names build their maps with.

        WHY IT IS HERE RATHER THAN IN EACH RIG. Five scripts carried private `local function` copies
        of the same five helpers, and the copies had drifted: three `unbound`s with three different
        behaviours, three `place_facing`s with three different signatures, and a `target` argument
        that was indexed as target[1]/target[2] in two of them and read as target.x/target.y in the
        third. #215 then established that the rigs were not merely duplicated but WRONG -- a rig laid
        out for a superseded footprint reads as a machine producing nothing rather than as a plumbing
        mistake -- and added two guards that landed in one rig's copies and reached none of the
        others. Two of the three rigs they did not reach are GATES, run to decide whether a change is
        safe. One implementation, so a guard added once is a guard all five of them have.

        WHAT `must` BECAME. Four rigs wrapped every create_entity in `must(entity, what)`, which
        raises when the engine returns nil. It is absorbed by rf_place_or_die rather than kept:
        place_or_die does everything must did and asks can_place_entity first, so keeping both would
        leave the weaker one available to be reached for. Rigs outside the five named in #226 keep
        their own `must` -- consolidating those is out of that ticket's scope.

        `say` IS NOT HERE. Its two copies look alike and are not one helper: each writes a rig's own
        prefix into that rig's own store, and the rigs that do not have one use `record` or `log`
        instead. rf_unbound therefore takes the note function as an option rather than calling a
        `say` it cannot know exists.

        Returns the Lua to place at the top level of a rig's control.lua.  #>

    $placeOrDie     = $script:RigBuildFunctions.PlaceOrDie
    $boxOf          = $script:RigBuildFunctions.BoxOf
    $unbound        = $script:RigBuildFunctions.Unbound
    $placeFacing    = $script:RigBuildFunctions.PlaceFacing
    $pipeRun        = $script:RigBuildFunctions.PipeRun
    $assertSegments = $script:RigBuildFunctions.AssertSegments
    $assertResearch = $script:RigBuildFunctions.AssertResearch
    $ladders        = $script:RigBuildFunctions.Ladders
    $unresearch     = $script:RigBuildFunctions.Unresearch
    $fluidBox       = $script:RigBuildFunctions.FluidBox
    $plasmaFeed     = $script:RigBuildFunctions.PlasmaFeed

    return @"
-- Generated by scripts/factorio-lib.ps1 (Get-RigBuildLua). Nothing here ships.
--
-- The helpers the five rigs of #226 build their maps with. They were copied five ways; the drift
-- between the copies is documented in that function's docstring, and the two guards below are #215's.

-- create_entity collision-checks NOTHING, so every silent overlap a rig builds gets built rather
-- than refused (#215). can_place_entity is the check, and WHICH check matters: at 2.0.77 its
-- build_check_type defaults to ghost_revive
-- (https://lua-api.factorio.com/2.0.77/classes/LuaSurface.html#can_place_entity), which is not what
-- a player placing by hand gets. Named here so the weaker default cannot creep back in, and
-- asserted because an unknown key would read as nil and quietly restore it.
local rf_build_check = defines.build_check_type.manual
if not rf_build_check then
  error("defines.build_check_type.manual is gone; this placement guard would silently "
    .. "fall back to ghost_revive")
end

-- A position arrives here two ways: written as { x, y } by a rig, or read off a connection as a
-- MapPosition. Only the callers below and their error messages care, and they would rather not care
-- separately -- the three private place_facing copies this replaces disagreed about exactly this,
-- so merging them without settling it would have yielded silent nils rather than an error.
local function rf_xy(position)
  if position.x then return position.x, position.y end
  return position[1], position[2]
end

--- create_entity, refused rather than overlapped, and never nil.
---
--- EVERY entity a rig builds goes through here, which is the point: guarding only the functions
--- that place machines leaves pipe runs, infinity pipes and power islands still building silently
--- into whatever is already there.
---
--- It is also what `must` used to be. A create_entity that returns nil still raises, with the same
--- wording, so no rig needs both.
local function $placeOrDie(surface, spec, what)
  local x, y = rf_xy(spec.position)
  if not surface.can_place_entity({
    name = spec.name, position = spec.position, force = spec.force,
    direction = spec.direction, build_check_type = rf_build_check,
  }) then
    -- WHAT IS IN THE WAY, NAMED. can_place_entity answers yes or no and nothing else, and "something
    -- is already there" over a rig hundreds of tiles wide is a fault nobody can place without
    -- instrumenting the rig again. So the footprint this entity would have occupied is swept and
    -- whatever stands in it is listed. Swept from the PROTOTYPE's collision box rather than from a
    -- written-down size, for the reason every offset in these rigs is derived: the size is exactly
    -- what changed underneath the layout.
    -- ROTATED WITH THE ENTITY, because a collision_box is declared for north and this rig's whole
    -- subject is non-square machines. Placed east or west, an unrotated sweep reads the wrong
    -- rectangle and can answer "nothing this sweep could see" with the blocker plainly there --
    -- which would make the one branch that exists to name it useless exactly when it is needed.
    local box = prototypes.entity[spec.name].collision_box
    local lx, ly, rx, ry = box.left_top.x, box.left_top.y, box.right_bottom.x, box.right_bottom.y
    local d = spec.direction
    if d == defines.direction.east or d == defines.direction.west then
      lx, ly, rx, ry = ly, lx, ry, rx
    end
    local found, names = surface.find_entities_filtered({
      area = { { x + lx, y + ly }, { x + rx, y + ry } },
    }), {}
    for _, e in pairs(found) do
      if e.type ~= "character" then
        names[#names + 1] = string.format("%s at (%g, %g)", e.name, e.position.x, e.position.y)
      end
    end
    error(string.format("%s will not fit at (%g, %g): this rig's layout is stale against that "
      .. "prototype's footprint. In the way: %s", what, x, y,
      #names > 0 and table.concat(names, ", ") or "nothing this sweep could see"))
  end
  local entity = surface.create_entity(spec)
  if not entity then error(string.format("%s refused at (%g, %g)", what, x, y)) end
  return entity
end

--- The index of the box filtered to `fluid`, or nil.
---
--- Boxes are found by the fluid they are filtered to rather than by index. The reactor's are
--- declared in a known order, but a heat exchanger's third box belongs to its energy source rather
--- than to the boiler, and an assembling machine's come from whatever recipe is set -- so an index
--- would be a guess in two of the three cases and a hostage to prototype edits in all of them.
local function $boxOf(entity, fluid)
  for index = 1, entity.fluids_count do
    local filter = entity.get_fluid_filter(index)
    if filter and filter.name == fluid then return index end
  end
  return nil
end

--- 2.0's LuaFluidBox, on 2.1's index methods (#768).
---
--- 2.1 removed LuaEntity.fluidbox and gave the entity an index method for each read and write it
--- carried, so a rig written against 2.0 swaps x.fluidbox for $fluidBox(x) and keeps every
--- other word. Each 2.0 read maps to its 2.1.23 method
--- (https://lua-api.factorio.com/2.1.23/classes/LuaEntity.html):
---
---   box[i]                         get_fluid(i)
---   box[i] = fluid                 set_fluid(i, fluid); nil, or an amount of 0, is clear_fluid(i)
---   #box                           fluids_count, which the 2.1.23 API says also counts storages
---                                  that are not fluid boxes, a fluid turret's or a fluid wagon's;
---                                  2.0's #fluidbox did not. No rig reads either
---   box.owner, box.valid           the entity, and whether it is valid
---   get_capacity(i)                get_fluid_segment_capacity(i) on a pipe, tank or infinity pipe,
---                                  get_fluid_capacity(i) on anything else: on 2.0 a pipe or tank
---                                  read its segment's and a machine's box its own, as
---                                  check-blanket.ps1's flooded cell reads them
---   get_filter(i)                  get_fluid_filter(i), as 2.0's { name = ... }
---   get_pipe_connections(i)        get_fluid_box_pipe_connections(i), each target wrapped again,
---                                  because 2.0's target was a fluid box and 2.1's is the entity
---   get_connections(i)             get_fluid_box_neighbours(i), each entity wrapped
---   get_fluid_segment_id(i)        the same, nil where has_fluid_segment(i) is false
---   get_fluid_segment_contents(i)  get_fluid_segment_fluid(i), as 2.0's { [name] = amount }
---   get_prototype(i)               get_fluid_box_prototype(i)
---
--- Any other read raises and names itself, so a use the rigs turn out to have is added here once
--- rather than ported by hand at each site.
local $fluidBox
local rf_fluidbox_segmented = {
  ["pipe"] = true, ["pipe-to-ground"] = true, ["storage-tank"] = true, ["infinity-pipe"] = true,
}
local rf_fluidbox_reads = {
  get_capacity = function(e, i)
    if rf_fluidbox_segmented[e.type] and e.has_fluid_segment(i) then return e.get_fluid_segment_capacity(i) end
    return e.get_fluid_capacity(i)
  end,
  get_filter = function(e, i)
    local filter = e.get_fluid_filter(i)
    return filter and { name = filter.name }
  end,
  get_pipe_connections = function(e, i)
    local out = {}
    for k, c in pairs(e.get_fluid_box_pipe_connections(i) or {}) do
      out[k] = {
        flow_direction = c.flow_direction, connection_type = c.connection_type,
        position = c.position, target_position = c.target_position,
        target = c.target and $fluidBox(c.target), target_fluidbox_index = c.target_fluidbox_index,
        target_pipe_connection_index = c.target_pipe_connection_index,
      }
    end
    return out
  end,
  get_connections = function(e, i)
    local out = {}
    for k, record in pairs(e.get_fluid_box_neighbours(i) or {}) do out[k] = $fluidBox(record.entity) end
    return out
  end,
  get_fluid_segment_id = function(e, i)
    return e.has_fluid_segment(i) and e.get_fluid_segment_id(i) or nil
  end,
  get_fluid_segment_contents = function(e, i)
    local fluid = e.has_fluid_segment(i) and e.get_fluid_segment_fluid(i)
    return fluid and { [fluid.name] = fluid.amount } or {}
  end,
  get_prototype = function(e, i) return e.get_fluid_box_prototype(i) end,
}
function $fluidBox(entity)
  return setmetatable({}, {
    __index = function(_, key)
      if type(key) == "number" then return entity.get_fluid(key) end
      if key == "owner" then return entity end
      if key == "valid" then return entity.valid end
      local read = rf_fluidbox_reads[key]
      if not read then
        error("$fluidBox has no " .. tostring(key) .. ": add its 2.1 method to rf_fluidbox_reads")
      end
      return function(index) return read(entity, index) end
    end,
    __newindex = function(_, index, fluid)
      if fluid == nil or fluid.amount <= 0 then entity.clear_fluid(index)
      else entity.set_fluid(index, fluid) end
    end,
    __len = function() return entity.fluids_count end,
  })
end

--- Plasma for a box, through a pump, because an infinity pipe cannot share its segment (#777).
---
--- On 2.1.23 an infinity pipe resets the segment it is on to its filter whenever the segment's
--- temperature is not the filter's, in at-least mode and in add mode alike, and the reactor's input
--- box shares the segment of whatever is on its face (docs/research/plasma-input-box.md, "On
--- Factorio 2.1.23"). So an infinity pipe bolted to the box undoes every step the reactor takes. A
--- pump is a segment boundary: the infinity pipe keeps a segment of its own at its filter, and the
--- pump carries plasma across at the filter's temperature, mixed into the box by amount, which is
--- what a heater does. The pump is the rig's own copy of rf-pump on a void energy source
--- (Write-PlasmaFeed), so no rig wires power to it.
---
--- Placed on connection n of box index (the first by default), outward from the face: the pump
--- on the two tiles beyond it and the infinity pipe on the next. filter is the infinity pipe's.
--- Returns the infinity pipe and the pump.
local function $plasmaFeed(surface, force, entity, index, filter, n)
  local c = (entity.get_fluid_box_pipe_connections(index) or {})[n or 1]
  if not c then error(string.format("%s's box %d has no connection %d to feed", entity.name, index, n or 1)) end
  local dx, dy = c.target_position.x - c.position.x, c.target_position.y - c.position.y
  local length = math.max(math.abs(dx), math.abs(dy))
  dx, dy = dx / length, dy / length
  -- A pump's direction is the way it pushes, so it faces back at the box.
  local toward = ({
    ["0,-1"] = defines.direction.south, ["0,1"] = defines.direction.north,
    ["1,0"] = defines.direction.west, ["-1,0"] = defines.direction.east,
  })[string.format("%d,%d", dx, dy)]
  if not toward then error(string.format("%s's box %d faces no cardinal direction", entity.name, index)) end
  local at = c.target_position
  local pump = $placeOrDie(surface, {
    name = "$script:PlasmaFeedPumpName", position = { at.x + dx / 2, at.y + dy / 2 },
    direction = toward, force = force,
  }, "the plasma feed's pump")
  local pipe = $placeOrDie(surface, {
    name = "$script:PlasmaFeedName", position = { at.x + 2 * dx, at.y + 2 * dy }, force = force,
  }, "the plasma feed")
  pipe.set_infinity_pipe_filter(filter)
  -- ASSERTED, because a pump turned the wrong way is a feed that never feeds and reads as a
  -- starved reactor.
  local reaches
  for _, p in pairs(pump.get_fluid_box_pipe_connections(1) or {}) do
    if p.flow_direction == "output" and p.target == entity then reaches = true end
  end
  if not reaches then
    error(string.format("the plasma feed's pump at (%g, %g) does not push into %s", pump.position.x,
      pump.position.y, entity.name))
  end
  return pipe, pump
end

--- An infinity pipe against every free connection of a box: unbounded supply, or unbounded disposal.
---
--- Everything that is not the thing under test is made unbounded this way, so the thing under test
--- is the only limit in the rig.
---
--- `opts` carries what the three private copies disagreed about, and all three behaviours survive:
---
---   pipe        the pipe prototype, because the categorised energy feeds are not "infinity-pipe".
---               Defaults to "infinity-pipe".
---   skip_taken  a connection whose target tile something already stands on is SKIPPED rather than
---               refused. Off by default, and the default is the load-bearing half -- see below.
---   allow_none  every face already taken is legitimate for ONE box in probe-energy-containment's
---               chained pair -- the lower exchanger has the reactor on one short end and its
---               neighbour on the other, and is fed along the column instead -- and a broken layout
---               everywhere else. So it is a per-caller opt-in and not a blanket warning: making it
---               a note for every caller once hid a control machine placed a tile too close, which
---               covered the column's last free water face and dropped both exchangers to
---               no_input_fluid while the rig reported on two machines that were not running.
---   note        function(fmt, ...) a rig passes so the allow_none case is recorded in that rig's
---               own store. Optional; without one the case is silent.
---
--- WHY skip_taken IS OPT-IN, AND WHY GETTING THIS WRONG UNDOES #215. The two behaviours the private
--- copies had are NOT the same test and one is not a safe default for the other. Skipping is right
--- in probe-energy-containment, where two exchangers fifteen tiles apart join through their water
--- boxes and the column is fed from whichever end is free -- a neighbour on a target tile is the
--- arrangement, not a fault. Everywhere else an occupied target tile IS the fault, and it is exactly
--- the #215 one: when the exchanger's water connections moved to its short ends, bench-mod-links'
--- pipes landed eight tiles out, inside the reactor's own footprint, and placed anyway.
---
--- A shared version that always skips would have turned that abort into a quiet half-plumbed rig
--- reporting a lower, entirely plausible megawatt figure -- the same shape of silence #215 exists to
--- remove. So skipping happens only where a caller says the neighbour is legitimate, and every other
--- caller still routes the tile through $placeOrDie and stops.
local function $unbound(surface, force, entity, index, filter, opts)
  opts = opts or {}
  local name = opts.pipe or "infinity-pipe"
  local attached, total = 0, 0
  for _, connection in pairs(entity.get_fluid_box_pipe_connections(index) or {}) do
    total = total + 1
    local taken = #surface.find_entities_filtered({ position = connection.target_position }) > 0
    if not (taken and opts.skip_taken) then
      local pipe = $placeOrDie(surface,
        { name = name, position = connection.target_position, force = force },
        entity.name .. "'s " .. filter.name .. " infinity pipe")
      pipe.set_infinity_pipe_filter(filter)
      attached = attached + 1
    end
  end
  if attached == 0 then
    if not opts.allow_none then
      error(string.format("no free connection to attach an infinity pipe to on %s box %d (%s)",
        entity.name, index, filter.name))
    end
    if opts.note then
      opts.note("plumbing: %s box %d (%s) has all %d of its faces taken by neighbours, so it is "
        .. "fed along the column rather than from a pipe of its own",
        entity.name, index, filter.name, total)
    end
  end
end

--- Place an entity so that one of its fluid connections POINTS AT a chosen tile.
---
--- The alternative is to write down where a chemical plant keeps its output and where a heat
--- exchanger keeps its heat input, and those are vanilla's numbers rather than this repository's --
--- exactly the class of remembered constant that broke the reactor benchmark (#49). So the entity is
--- placed once, asked where its connection actually points, and moved by the difference.
---
--- NOT A BOLT. This aligns a connection's TARGET onto a chosen tile, which is what a pipe run wants:
--- the pipe occupies that tile. A bolt aligns one machine's connection TILE onto the other's target,
--- and bench-mod-links.ps1 keeps its own bolt() for that -- one caller, and ADR 0018's Consequences
--- explain why confusing the two produces a false negative rather than a visible fault.
---
--- `spec` fields:
---   name        the prototype to place
---   fluid       the box's filter. nil means box 1, for a caller with no filter to name -- a
---               storage tank's four connections carry no filter at all.
---   connection  which connection to align. "first" takes connections[1]; "only" requires the box to
---               have exactly one and errors otherwise, which is how a caller says it is not
---               guessing; a side name ("north"/"south"/"east"/"west") picks the one facing that
---               way. Defaults to "first".
---   target      the tile to point at, as { x, y } or { x = , y = }
---   seed        anywhere clear to place the throwaway probe
---   prepare     optional function(entity) run on the probe AND on the placed entity, for a machine
---               whose boxes do not exist until a recipe is set
---
--- WHICH WAY A CONNECTION FACES is its dominant axis. It used to require dx == 0 for north and
--- south, which is only true of a connection in the middle of a short end -- and on the 15x5
--- exchanger the middle of both short ends is water, so the chain variant's energy connections sit
--- one tile off centre and matched nothing.
---
--- A RIG THAT NAMES A FACE IS ASSERTING A LAYOUT IT DOES NOT OWN, which is why "only" exists and is
--- worth preferring: both shipped exchangers took their energy on the south face when the first
--- version of this was written, #45 moved rf-heat-exchanger's onto a long face, and the probe
--- stopped running. A caller that names a face anyway fails loudly rather than measuring the wrong
--- tile in silence.
local function $placeFacing(surface, force, spec)
  local seed, name = spec.seed, spec.name
  -- Not ${placeOrDie}: this one is thrown away, and it exists to be asked where its connections point.
  -- That answer is relative to itself, so an overlap here changes nothing it is asked for.
  local probe = surface.create_entity({ name = name, position = seed, force = force })
  if not probe then error("could not place a probe " .. name) end
  if spec.prepare then spec.prepare(probe) end

  local index = 1
  if spec.fluid then
    index = $boxOf(probe, spec.fluid)
    if not index then
      probe.destroy()
      error(name .. " has no box filtered to " .. spec.fluid)
    end
  end
  local label = spec.fluid or ("box " .. index)
  local connections = probe.get_fluid_box_pipe_connections(index) or {}
  if #connections == 0 then
    probe.destroy()
    error(name .. "'s " .. label .. " box has no connections")
  end

  local want, chosen = spec.connection or "first", nil
  if want == "first" then
    chosen = connections[1].target_position
  elseif want == "only" then
    if #connections ~= 1 then
      probe.destroy()
      error(string.format(
        "%s's %s box has %d connections, so the caller has to say which face to align",
        name, label, #connections))
    end
    chosen = connections[1].target_position
  else
    for _, c in pairs(connections) do
      local dx = c.target_position.x - probe.position.x
      local dy = c.target_position.y - probe.position.y
      local matches =
        (want == "south" and dy > 0 and math.abs(dy) > math.abs(dx)) or
        (want == "north" and dy < 0 and math.abs(dy) > math.abs(dx)) or
        (want == "west"  and dx < 0 and math.abs(dx) > math.abs(dy)) or
        (want == "east"  and dx > 0 and math.abs(dx) > math.abs(dy))
      if matches then chosen = c.target_position end
    end
  end
  if not chosen then
    probe.destroy()
    error(string.format("%s's %s box has no connection on its %s face", name, label, want))
  end

  local tx, ty = rf_xy(spec.target)
  local position = { seed[1] + (tx - chosen.x), seed[2] + (ty - chosen.y) }
  probe.destroy()

  local entity = $placeOrDie(surface, { name = name, position = position, force = force, quality = spec.quality },
    string.format("%s at (%g, %g)", name, position[1], position[2]))
  if spec.prepare then spec.prepare(entity) end
  return entity
end

--- A run of `count` pipes from `from`, stepping by `step`.
---
--- The pipe is named by the caller: #26 gives the plasma set a connection_category of its own, so
--- rf-pipe joins the reactor's plasma box and nothing else, while an ordinary vanilla pipe is what
--- every water and steam line wants. Getting it wrong does not misreport, it fails to connect.
---
--- Idempotent, because a caller that walks two runs into the same tile would otherwise get two pipes
--- in it -- and until $placeOrDie existed, silently.
local function $pipeRun(surface, force, name, from, step, count)
  for i = 0, count - 1 do
    local at = { from[1] + step[1] * i, from[2] + step[2] * i }
    if not surface.find_entity(name, at) then
      $placeOrDie(surface, { name = name, position = at, force = force },
        string.format("%s at (%g, %g)", name, at[1], at[2]))
    end
  end
end

--- No two DIFFERENT fluids share one fluid segment. #215's second guard.
---
--- assert_joined-style checks prove a box is connected to SOMETHING, not to the right thing, and the
--- difference is what #215 turned on. Every fluid in these rigs has its own plumbing, and the engine
--- merges any two segments whose tiles touch. A steam pipe landing on the energy line breaks no
--- connection -- every box still reports a target -- it merely makes a segment that cannot accept
--- reactor energy. The reactor then reads as a machine that produces nothing rather than as a
--- plumbing mistake, which is exactly how one exchanger bank sat broken for ten days with every
--- check green.
---
--- Same fluid sharing is NOT an error: the whole point of the energy line is that a reactor and
--- every exchanger on it sit in one segment, and adjacent exchangers' water pipes may touch harmless.
---
--- `claims` is a list of { entity = , fluid = , what = , index = }. `index` is optional and resolved
--- through $boxOf when absent; `what` names the box in the error.
local function $assertSegments(label, claims)
  local owner = {}
  for _, claim in ipairs(claims) do
    local entity, fluid, what = claim.entity, claim.fluid, claim.what
    local index = claim.index or $boxOf(entity, fluid)
    if not index then
      error(label .. ": " .. what .. ": no box carries " .. fluid)
    end
    -- WHOSE segment id, and it is not the machine's own. get_fluid_segment_id on a machine's box
    -- returns nil far more often than not: MEASURED AGAINST FACTORIO 2.0.77 (build 84539), it
    -- answered for the reactor's plasma box and for every exchanger's water box, and returned nil
    -- for the reactor's energy box, every heater box and every steam box. The version is named
    -- because the API publishes per version and this is a fact about one of them. The manual does
    -- not contradict it and does not predict it either:
    -- https://lua-api.factorio.com/2.0.77/classes/LuaFluidBox.html#get_fluid_segment_id gives "does
    -- not belong to a fluid segment" as one of its nil cases without saying which boxes fall into
    -- it. The pipe on the other side of the connection always has one, so the segment is read
    -- through the connection's target.
    local ids = {}
    for _, connection in pairs(entity.get_fluid_box_pipe_connections(index) or {}) do
      if connection.target then
        local id = connection.target.has_fluid_segment(connection.target_fluidbox_index)
          and connection.target.get_fluid_segment_id(connection.target_fluidbox_index)
        if id then ids[#ids + 1] = id end
      end
    end
    -- Flush against another machine there is no pipe to ask, and then the box's own id is the only
    -- one there is. Neither being available means nothing can be judged, which is not a pass.
    if #ids == 0 then
      local own = entity.has_fluid_segment(index) and entity.get_fluid_segment_id(index)
      if not own then
        error(label .. ": " .. what .. ": in no fluid segment, and neither is anything it connects "
          .. "to -- this box cannot be judged")
      end
      ids[1] = own
    end
    for _, id in ipairs(ids) do
      local held = owner[id]
      if held and held.fluid ~= fluid then
        error(string.format(
          "%s: %s carries %s, but shares fluid segment %d with %s, which carries %s. Two fluids in "
          .. "one segment: neither line can carry what it is for, and nothing else in this rig says "
          .. "so", label, what, fluid, id, held.what, held.fluid))
      end
      owner[id] = { fluid = fluid, what = what }
    end
  end
end

--- Every research ladder on a reactor spec: { rungs = , field = } per row (#444).
---
--- logic.spec_ladders, AND THEN capture_ladder BY NAME, because reactor-logic deliberately keeps
--- plant efficiency out of that table (ADR 0020 decision 5: it reaches step() as an argument, never
--- as a spec field). control.lua's check_ladder_prototypes walks the same two the same way. A rig
--- that wants "every ladder" wants all three, so it reads them here rather than from a list of its
--- own -- the lesson of #424 and #443, where a loop written for one ladder walked past the next.
local function $ladders(logic)
  local rows = {}
  for _, row in ipairs(logic.spec_ladders) do rows[#rows + 1] = row end
  rows[#rows + 1] = { rungs = "capture_ladder", field = "capture_efficiency" }
  return rows
end

--- Turn every rung of every ladder on a spec OFF, or keep a chosen few ON (#443, #440, #485).
---
--- The arranging half of the "none held" shape; ${assertResearch} below is the asserting half, and a
--- rig calls both. A rung naming no technology is skipped here and refused there.
---
--- KEEP, when given, is the same per-ladder table ${assertResearch} takes: the first KEEP[rungs]
--- rungs of each ladder are put ON rather than off, so one call arranges a chosen state (#485).
local function $unresearch(force, logic, spec, keep)
  for _, row in ipairs($ladders(logic)) do
    for level, rung in ipairs(spec[row.rungs] or {}) do
      local technology = force.technologies[rung.technology]
      if technology then technology.researched = keep ~= nil and level <= (keep[row.rungs] or 0) end
    end
  end
end

--- The research state a rig runs at, asserted rung by rung rather than described (#444).
---
--- research_all_technologies() puts a rig at the top of every ladder and says so nowhere, so the
--- state got described backwards: #293's audit recorded three rigs as running "at base heating"
--- when all three research everything. A rig states its state here instead, and the claim has
--- something to contradict it.
---
--- HELD is true for "this force holds every rung" and false for "it holds none" -- the second is
--- check-pooling's shape (#443), which needs its ladders OFF. Both directions in one helper, so the
--- rig that wants the rungs off calls ${unresearch} rather than writing its own loop again. The
--- ladders are ${ladders}'s.
---
--- A RUNG NAMING A TECHNOLOGY NO LOADED MOD DEFINES IS AN error(), NOT A FAILED record. In the
--- "none held" direction a missing technology would otherwise read exactly like an unresearched one.
---
--- HELD MAY ALSO BE A TABLE of rungs held per ladder, keyed by the ladder's rungs name -- e.g.
--- { heating_ladder = 3 } -- for a state between the two corners (#485). A ladder it does not name
--- holds none; a key naming no ladder, or a count above the ladder's length, is an error() rather
--- than a quiet zero or a quiet top rung.
---
--- RECORD is the rig's own function(ok, name, detail); this one has no store of its own.
local function $assertResearch(record, force, logic, spec, held)
  if type(held) == "table" then
    local known = {}
    for _, row in ipairs($ladders(logic)) do known[row.rungs] = true end
    for key in pairs(held) do
      if not known[key] then error(string.format("%s names no ladder on this spec", key)) end
    end
  end
  for _, row in ipairs($ladders(logic)) do
    local rungs = spec[row.rungs] or {}
    local count = type(held) == "table" and (held[row.rungs] or 0) or nil
    if count and count > #rungs then
      error(string.format("%d rungs of %s asked for, and it has %d", count, row.rungs, #rungs))
    end
    for level, rung in ipairs(rungs) do
      local tech = force.technologies[rung.technology]
      if not tech then
        error(string.format("rung %d of %s names %s, which no loaded mod defines", level,
          row.field, rung.technology))
      end
      local want = held
      if count then want = level <= count end
      record(tech.researched == want,
        string.format("this rig's force %s %s, rung %d of %s", want and "holds" or "does not hold",
          rung.technology, level, row.field),
        "researched = " .. tostring(tech.researched))
    end
  end
end
"@
}

function Format-Category {
    <#  One connection's category as the report prints it.

        The three forms are kept distinguishable on purpose. A bare string and a one-element list are
        the same thing to the engine and NOT the same evidence: `no-pipe-touching` writes a bare
        string over an underground connection and a list onto a surface one, and telling which
        happened is most of what identifies the pass that did it. Absent is a third case again -- the
        engine reads it as "default", which is the category every vanilla pipe carries, so an absent
        field is containment gone rather than containment unset.  #>
    param([object] $Value)

    if ($null -eq $Value) { return 'default (no field)' }
    if ($Value -is [string]) { return $Value }
    $items = @($Value)
    if ($items.Count -eq 0) { return 'default (empty list)' }
    return '{' + ($items -join ', ') + '}'
}

function Expand-Category {
    <#  One connection's category as a SET of names, for comparing rather than for printing.

        Absent and empty both become "default", because that is what the engine reads them as -- and
        the whole comparison below turns on it. Without this, a connection whose category the set
        DELETED would compare as "absent versus absent" against one we never categorised, and the
        two are opposite findings.  #>
    param([object] $Value)

    if ($null -eq $Value) { return @('default') }
    if ($Value -is [string]) { return @($Value) }
    $items = @($Value | ForEach-Object { [string]$_ })
    if ($items.Count -eq 0) { return @('default') }
    return $items
}

function Add-Connections {
    <#  Every pipe connection under $Node, as "path" -> its category and connection type.

        Recursive over the whole prototype rather than over a list of known field names: see the
        header. The path is the connection's identity across the two dumps, so it has to be built the
        same way on both sides, and it is, by this one function running on both.  #>
    param([object] $Node, [string] $Path, [Parameter(Mandatory)] [hashtable] $Into)

    if ($Node -is [System.Management.Automation.PSCustomObject]) {
        foreach ($property in $Node.PSObject.Properties) {
            if ($null -eq $property.Value) { continue }
            if ($property.Name -ne 'pipe_connections') {
                Add-Connections -Node $property.Value -Path "$Path.$($property.Name)" -Into $Into
                continue
            }
            $index = 0
            foreach ($connection in @($property.Value)) {
                $index++
                $fields = $connection.PSObject.Properties
                # A PLAIN ASSIGNMENT, NOT `$category = if (...) { $connection.connection_category }`.
                # An `if` used as an expression writes its block's output to the pipeline, and a
                # ONE-ELEMENT array sent to the pipeline arrives as its element -- so the array
                # ["rf-plasma"] was read as the string "rf-plasma" and this probe could not tell the
                # two apart at all. It mattered: `no-pipe-touching` rewrites the field in place as a
                # one-element list on twelve contained connections of ours, and the instrument was
                # blind to the rewrite by accident rather than by decision. The set comparison below
                # is what decides such a rewrite is a no-op; this line is what lets it see one.
                $category = $null
                if ($fields['connection_category']) { $category = $connection.connection_category }
                $Into["$Path.pipe_connections[$index]"] = [pscustomobject]@{
                    Category = Format-Category $category
                    # @() because a PowerShell function returning a one-element array returns the
                    # ELEMENT: `Set` was then the string "default", whose .Count is 1 and whose [0]
                    # is the character "d", so every uncategorised connection classified as one we
                    # had categorised. The wrap is what makes it a collection on both sides.
                    Set = @(Expand-Category $category)
                    # Default per the 2.0.77 prototype docs. Reported rather than used: which
                    # connection is underground is exactly what decides the branch taken by the pass
                    # under suspicion, so a reader needs it beside the value.
                    Type = if ($fields['connection_type']) { [string]$connection.connection_type } else { 'normal' }
                }
            }
        }
    }
    elseif ($Node -is [System.Object[]]) {
        for ($i = 0; $i -lt $Node.Count; $i++) {
            Add-Connections -Node $Node[$i] -Path "$Path[$($i + 1)]" -Into $Into
        }
    }
}

function Get-ConnectionsFromDump {
    <#  Our prototypes' pipe connections, out of a --dump-data written earlier, as
        "type/name" -> (path -> connection).

        SHARED BY THE PROBE AND THE GATE (#209), which is why it is here rather than in either.
        scripts/probe-connection-categories.ps1 measures a lane and asserts nothing;
        scripts/load-check.ps1 asserts that containment survived the load. They must read a
        connection the same way or the gate would fail on shapes the probe calls no-ops -- and the
        two traps this walk exists to avoid are recorded above Add-Connections and Expand-Category.
        One implementation, one set of traps.

        OURS BY PREFIX, WHICH IS EXACT BECAUSE ANOTHER CHECK MAKES IT SO. scripts/name-check.ps1
        derives this repository's prototypes by difference between two dumps and asserts every one
        carries `rf-`, with one declared exception -- base Factorio's generated
        `empty-rf-<fluid>-barrel` recipes, which have no fluid box and so cannot appear here.  #>
    param([Parameter(Mandatory)] [string] $DumpPath, [string] $Prefix = 'rf-')

    if (-not (Test-Path -LiteralPath $DumpPath)) { throw "no data-raw-dump.json at $DumpPath." }

    $found = @{}
    $parsed = Get-Content -LiteralPath $DumpPath -Raw | ConvertFrom-Json
    foreach ($type in $parsed.PSObject.Properties) {
        foreach ($prototype in $type.Value.PSObject.Properties) {
            if (-not $prototype.Name.StartsWith($Prefix, [StringComparison]::Ordinal)) { continue }
            $connections = @{}
            Add-Connections -Node $prototype.Value -Path '' -Into $connections
            # Kept even when EMPTY, so that "the prototype is gone" and "its fluid box was emptied"
            # stay different findings. Dropping the empty ones made the second read as the first, and
            # a reader chasing a deleted rf-reactor would have been looking for the wrong accident.
            $found["$($type.Name)/$($prototype.Name)"] = $connections
        }
    }
    return $found
}

function Get-MissingCategories {
    <#  The categories in $Declared that $Loaded does not hold, compared ORDINALLY as sets.

        BOTH HALVES OF THAT SENTENCE ARE LOAD-BEARING. As sets, because `contain()` writes the bare
        string "rf-plasma" while a set that merely INSPECTS a connection can write it back as the
        one-element list ["rf-plasma"] -- the same category to the engine, and twelve such rewrites
        were measured on the seablock lane. Comparing rendered text would call every one of them a
        difference. Ordinally, because a category is a name the engine matches exactly and
        PowerShell's -contains is not: a set writing "RF-Plasma" would compare equal and is a real
        breach.

        A FILTER, NOT A TEST, is the other trap: `$set -ceq @('default')` with an array on the left
        returns matching elements rather than $true or $false, so every comparison of that shape
        classifies the same way. Callers wanting "was this only `default`" must test the count and
        the element separately, as the probe's $wasDefault does.  #>
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $Declared,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $Loaded
    )

    return @($Declared | Where-Object {
        $name = $_
        -not @($Loaded | Where-Object { $_ -ceq $name })
    })
}

function Get-ProbeReportName {
    <# The file a probe's report is kept in: the probe's name and the arguments it was given, so
       two runs with different arguments keep a report each and a rerun replaces its own.
       -FactorioExe is left out of the name, being a path on one machine; the report's command
       line still has it. #>
    param([Parameter(Mandatory)] [string] $Script, [Collections.IDictionary] $Bound = @{}, [object[]] $Unbound = @())
    $words = @([IO.Path]::GetFileNameWithoutExtension($Script))
    foreach ($key in ($Bound.Keys | Where-Object { $_ -ne 'FactorioExe' } | Sort-Object)) {
        $words += "-$key"
        if ($Bound[$key] -isnot [switch]) { $words += (@($Bound[$key]) -join ',') }
    }
    $name = ((@($words) + @($Unbound)) -join '_') -replace '[^A-Za-z0-9._,=-]', '_'
    # ponytail: cut at 150 characters, so two long argument lists that agree that far share a file.
    return $name.Substring(0, [Math]::Min(150, $name.Length)) + '.txt'
}

function Start-ProbeReport {
    <# Keeps what a probe prints in .probe-reports/ at the repository's root (#589), so a figure in
       a research note can be checked against the run it came from without starting the game again.

       A probe printed its report and deleted its temp directory, and every figure was then copied
       by hand from output that was nowhere afterwards. This starts a transcript, which holds what
       the probe writes from here on, whether it ends, throws or exits. Under the transcript's own
       four opening lines the file has the command line, the date and the game's version, to match
       the sentence in a note that names them. The directory is git-ignored and inside no mod, so
       nothing of it reaches a zip.

       WHAT IT HOLDS THAT THE PROBE DID NOT PRINT. The five lines this function writes, which go to
       the console as well. And PowerShell's own: four lines at the head of a transcript, four at
       its foot, `PS>$global:?` and its answer before the foot of a run that finished, and a
       `PS>TerminatingError()` line above the error of one that threw.

       IT IS CALLED AT THE FOOT OF THIS FILE, for a script named probe-*.ps1 that dot-sources it.
       No probe calls it, so a new probe has it without being told.

       WHAT IT DOES NOT HOLD. A line written before this file is dot-sourced. What a native program
       writes straight to the console and not through the pipeline; the probes pipe or capture what
       they start. And nothing at all when the transcript cannot start, which is a warning and not
       a failure. A probe dot-sourced into a session that stays open keeps writing to its report
       until that session ends; run one with `pwsh -File`, as each probe's help has it. #>
    param([Parameter(Mandatory)] [Management.Automation.InvocationInfo] $Invocation)
    $script  = $Invocation.MyCommand.Path
    $bound   = $Invocation.BoundParameters
    $unbound = @($Invocation.UnboundArguments)
    $root    = Split-Path -Parent $PSScriptRoot
    $path    = Join-Path $root ".probe-reports/$(Get-ProbeReportName -Script $script -Bound $bound -Unbound $unbound)"
    $given   = @(foreach ($key in $bound.Keys) { "-$key"; if ($bound[$key] -isnot [switch]) { @($bound[$key]) -join ',' } }) + $unbound
    $version = try { "$(& (Resolve-FactorioExe -Path $bound['FactorioExe']) --version 2>$null | Select-Object -First 1)" }
               catch { "not read: $($_.Exception.Message)" }
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
        Start-Transcript -LiteralPath $path -UseMinimalHeader -Force | Out-Null
    } catch { Write-Warning "This run's report is not kept: $($_.Exception.Message)"; return }
    Write-Host "probe report  $([IO.Path]::GetRelativePath($root, $path).Replace([IO.Path]::DirectorySeparatorChar, '/'))"
    Write-Host "  command     pwsh -File scripts/$(Split-Path -Leaf $script) $($given -join ' ')".TrimEnd()
    Write-Host "  date        $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz', [cultureinfo]::InvariantCulture))"
    Write-Host "  game        $version"
    Write-Host ''
}

$rfSourcedBy = @(Get-PSCallStack)[1]
if ($rfSourcedBy -and $rfSourcedBy.ScriptName -and (Split-Path -Leaf $rfSourcedBy.ScriptName) -like 'probe-*.ps1') {
    # Every figure a probe prints carries a point, whatever the machine's culture says, so a row can
    # be quoted as is (#577). Until then two probes set it themselves, and the segment probe printed
    # its tables with decimal commas and its raw rows with points.
    [cultureinfo]::CurrentCulture = [cultureinfo]::InvariantCulture
    Start-ProbeReport -Invocation $rfSourcedBy.InvocationInfo
}
Remove-Variable rfSourcedBy

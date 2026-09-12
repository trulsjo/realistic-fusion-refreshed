#Requires -Version 7
<#
    Shared helpers for the scripts in this directory. Dot-source it:

        . "$PSScriptRoot/factorio-lib.ps1"

    The bundled-mod handling lives here rather than in each script because the same
    case-folding fault was introduced twice in two places: PowerShell's -in, -notin and its
    hashtables are case-insensitive, while HashSet[string] is ordinal, so an uncanonicalised
    name validates, then silently fails to match, then gets written disabled while the caller
    reports it as enabled. One implementation, fixed once.
#>

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

function Resolve-FactorioExe {
    <#  Preferred path, then $env:FACTORIO_EXE, then the Steam install on this machine. #>
    param([string] $Path)

    if (-not $Path) { $Path = $env:FACTORIO_EXE }
    if (-not $Path) { $Path = 'D:\SteamLibrary\steamapps\common\Factorio\bin\x64\Factorio.exe' }
    if (-not (Test-Path $Path)) {
        throw "Factorio.exe not found at '$Path'. Pass -FactorioExe or set `$env:FACTORIO_EXE."
    }
    return (Resolve-Path $Path).Path
}

function Get-FactorioDataDirectory {
    <#  <install>\bin\x64\Factorio.exe -> <install>\data, where base and core live.  #>
    param([Parameter(Mandatory)] [string] $FactorioExe)

    $dataDir = Join-Path (Split-Path (Split-Path (Split-Path $FactorioExe -Parent) -Parent) -Parent) 'data'
    if (-not (Test-Path $dataDir)) { throw "Factorio data directory not found at '$dataDir'." }
    return $dataDir
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

function ConvertTo-NativeArgument {
    <#  Quote one argument for a native Windows command line.

        Start-Process -ArgumentList joins an array with spaces and quotes nothing, so a path
        containing a space arrives as several arguments. "C:\Users\Jo Smith\mods" reaches the exe
        as "C:\Users\Jo" plus a stray "Smith\mods" -- which on this repo's scripts means Factorio
        running against a mod directory that has none of the junctions in it. It does not go
        silently wrong (load-check finds no save, bench-reactors finds no rig and throws), but
        both scripts are unusable for anyone whose profile or install path contains a space, which
        on Windows is most people.

        Windows parses backslashes literally except where they precede a quote, so a run of them
        at the end of the value has to be doubled before the closing quote or it escapes it.  #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Value)

    $escaped = $Value -replace '(\\+)$', '$1$1'
    $escaped = $escaped -replace '"', '\"'
    return '"' + $escaped + '"'
}

function Invoke-Factorio {
    <#  Run Factorio headless against a mod directory, capturing both streams to files.

        Returns the exit code and the two capture paths; it deliberately decides nothing about
        what a failure means, because the callers disagree -- load-check treats a non-zero exit as
        the answer it went looking for, bench-reactors treats it as the run being over.

        Runs in its own write-data directory, so it works while the game is open -- see below.

        Factorio.exe is a GUI-subsystem binary: the call operator does not wait for it and leaves
        $LASTEXITCODE unset, so the exit code has to come from the process object. That rules out
        native invocation, and so requires the quoting that ConvertTo-NativeArgument does.  #>
    param(
        [Parameter(Mandatory)] [string]   $FactorioExe,
        [Parameter(Mandatory)] [string]   $ModDirectory,
        [Parameter(Mandatory)] [string[]] $Arguments,
        [Parameter(Mandatory)] [string]   $OutputDirectory,
        [Parameter(Mandatory)] [string]   $Tag
    )

    $outFile = Join-Path $OutputDirectory "$Tag-stdout.txt"
    $errFile = Join-Path $OutputDirectory "$Tag-stderr.txt"

    # Factorio takes an exclusive lock on its write-data directory, so any headless run fails
    # outright while the game is open. That matters more than it sounds: the failure text is
    # "Is another instance already running?" buried in the captured stdout, and to a caller
    # checking only the exit code it is indistinguishable from a rejected prototype. It cost two
    # wrong conclusions in a row before anyone noticed the game was simply running.
    #
    # So every run gets a write-data directory of its own, inside the caller's temp directory and
    # thrown away with it. --mod-directory still wins for mods; this only moves the lock, the
    # player-data and the log.
    $configPath = Join-Path $OutputDirectory 'factorio-config.ini'
    if (-not (Test-Path $configPath)) {
        $writeData = Join-Path $OutputDirectory 'write-data'
        New-Item -ItemType Directory -Path $writeData -Force | Out-Null
        # read-data is the stock default; only write-data moves.
        @"
[path]
read-data=__PATH__executable__/../../data
write-data=$writeData
"@ | Set-Content -Path $configPath -Encoding utf8
    }

    $line = (@('--config', $configPath, '--mod-directory', $ModDirectory) + $Arguments |
        ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '

    $proc = Start-Process -FilePath $FactorioExe -ArgumentList $line `
        -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $outFile -RedirectStandardError $errFile

    [pscustomobject]@{ Code = $proc.ExitCode; OutFile = $outFile; ErrFile = $errFile }
}

# The name every rig in this directory uses for its plasma feed. Public so a rig's control.lua and
# Write-PlasmaFeed cannot drift apart.
$script:PlasmaFeedName = 'rf-rig-plasma-infinity-pipe'

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
data:extend({ feed })
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

# The names Get-RigBuildLua defines, public for the same reason $script:QuietMapFunction is: a rig's
# control.lua and the fragment it calls must not be able to drift apart over a spelling.
$script:RigBuildFunctions = @{
    PlaceOrDie     = 'rf_place_or_die'
    BoxOf          = 'rf_box_of'
    Unbound        = 'rf_unbound'
    PlaceFacing    = 'rf_place_facing'
    PipeRun        = 'rf_pipe_run'
    AssertSegments = 'rf_assert_segments'
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
  for index = 1, #entity.fluidbox do
    local filter = entity.fluidbox.get_filter(index)
    if filter and filter.name == fluid then return index end
  end
  return nil
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
  for _, connection in pairs(entity.fluidbox.get_pipe_connections(index)) do
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
  local connections = probe.fluidbox.get_pipe_connections(index)
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

  local entity = $placeOrDie(surface, { name = name, position = position, force = force },
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
    for _, connection in pairs(entity.fluidbox.get_pipe_connections(index)) do
      if connection.target then
        local id = connection.target.get_fluid_segment_id(connection.target_fluidbox_index)
        if id then ids[#ids + 1] = id end
      end
    end
    -- Flush against another machine there is no pipe to ask, and then the box's own id is the only
    -- one there is. Neither being available means nothing can be judged, which is not a pass.
    if #ids == 0 then
      local own = entity.fluidbox.get_fluid_segment_id(index)
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
"@
}

# Text --dump-prototype-locale writes where a name a player can read ought to be. Public so
# locale-check.ps1 and tree-viewer.ps1 cannot drift apart on what the strings are.
#
# TWO LISTS, because the callers are asking different questions and #169 conflated them:
#
#   ENGINE ERRORS are the engine failing to resolve part of a string it did resolve -- a rich-text
#   reference or a control code naming nothing. They arrive INSIDE the value, surrounded by
#   whatever did resolve, so they are found by substring and not by equality. Whoever wrote that
#   locale entry has a bug, so a gate over its OWN prototypes can fail on them.
#
#   A FOREIGN PLACEHOLDER is a string another mod ships on purpose. "Something went wrong" is not
#   an engine string at all: it is the literal value Angels' own locale gives [item-name]
#   angels-void, and the 334 recipes carrying it in that lane at 2.0.77 point their localised_name
#   at that key deliberately, to mark a recipe a missing dependency stranded. A viewer is right to
#   refuse it as a LABEL. A gate must not fail on it -- locale-check.ps1 loads this repo's mods
#   and Wube's bundled ones and nothing else, so Angels can never be in its scope, and the only
#   thing the string could catch there is one of our own descriptions using those four words.
#
# What the engine does NOT do is dump a name it could not work out. Measured on 2.0.77: a
# prototype with no locale entry, one whose localised_name names a missing key, and one whose
# nested parameter names a missing key are all simply ABSENT from the dump; a localised string
# that is too deep or has too many parameters stops the data stage outright and the game never
# starts. So every failure visible in a dumped value is one that resolved to text.
#
# Pinned to 2.0.77. Matching engine wording literally is fragile, and a later engine phrasing it
# differently puts the text back on the labels -- where it is at least visible to a human.
$script:LocaleEngineErrors = @(
    'Unknown key:',
    'Unknown control sequence:'
)
$script:LocaleForeignPlaceholders = @(
    'Something went wrong'
)

function Get-LocaleFailure {
    <#  The marker that makes a dumped locale value unusable, or $null if it reads fine.

        -EngineOnly narrows it to the engine's own errors, which is what a gate over this repo's
        prototypes wants: a foreign placeholder is a true finding about a label and a false one
        about a locale entry. Without the switch both lists apply, which is the viewer's question.  #>
    param(
        [AllowEmptyString()] [AllowNull()] [string] $Value,
        [switch] $EngineOnly
    )

    if (-not $Value) { return $null }
    $markers = if ($EngineOnly) { $script:LocaleEngineErrors }
               else { $script:LocaleEngineErrors + $script:LocaleForeignPlaceholders }
    foreach ($marker in $markers) {
        if ($Value.Contains($marker, [StringComparison]::Ordinal)) { return $marker }
    }
    return $null
}

function Invoke-FactorioStep {
    <#  One Factorio run the caller cannot continue without: a non-zero exit is fatal rather than a
        result, and the end of both captured streams is printed before it throws.

        Invoke-Factorio deliberately decides nothing about what a failure means, because
        load-check treats a non-zero exit as the answer it went looking for. Every other caller
        wants exactly this, and wrote it out separately until there were two copies.

        Returns the path to the captured stdout.  #>
    param(
        [Parameter(Mandatory)] [string]   $FactorioExe,
        [Parameter(Mandatory)] [string]   $ModDirectory,
        [Parameter(Mandatory)] [string[]] $Arguments,
        [Parameter(Mandatory)] [string]   $OutputDirectory,
        [Parameter(Mandatory)] [string]   $Tag
    )

    $result = Invoke-Factorio -FactorioExe $FactorioExe -ModDirectory $ModDirectory `
        -Arguments $Arguments -OutputDirectory $OutputDirectory -Tag $Tag
    if ($result.Code -ne 0) {
        Write-FactorioTail $result
        throw "Factorio exited $($result.Code) during '$Tag'."
    }
    return $result.OutFile
}

function Write-FactorioTail {
    <#  Print the end of each captured stream from an Invoke-Factorio result.

        Tailed separately rather than interleaved: Factorio's stdout runs to hundreds of lines and
        would otherwise push every stderr line out of a shared window.  #>
    param(
        [Parameter(Mandatory)] [object] $Result,
        [int] $Lines = 20
    )

    foreach ($f in @($Result.ErrFile, $Result.OutFile)) {
        if (-not (Test-Path $f)) { continue }
        $captured = Get-Content $f -ErrorAction SilentlyContinue | Where-Object { $_ -match '\S' }
        if (-not $captured) { continue }
        Write-Host "  --- $(Split-Path $f -Leaf) (last $Lines of $($captured.Count)) ---"
        $captured | Select-Object -Last $Lines | ForEach-Object { Write-Host "    $_" }
    }
}

function Remove-TempDirectory {
    <#  Delete a temporary directory, retrying briefly.

        Factorio can hold a save open for a moment after exiting, so a single Remove-Item loses
        the race often enough to leak the directory silently. Always call Remove-ModJunctions
        first: this follows junctions rather than skipping them.  #>
    param(
        [Parameter(Mandatory)] [string] $Path,
        [string] $Label = 'cleanup'
    )

    if (-not (Test-Path $Path)) { return }
    foreach ($attempt in 1..5) {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path $Path)) { return }
        Start-Sleep -Milliseconds 200
    }
    Write-Warning "${Label}: could not remove temp directory $Path"
}

function Get-BundledMods {
    <#  Mods shipped inside the game's data/ directory -- space-age, elevated-rails, quality and
        anything a future version adds. They are present whatever --mod-directory points at, so
        they load unless explicitly disabled. Discovered rather than hardcoded, so the list
        cannot go stale. base and core are not optional and are excluded.

        Returns a hashtable of mod name -> parsed info.json.  #>
    param([Parameter(Mandatory)] [string] $FactorioExe)

    $dataDir = Get-FactorioDataDirectory -FactorioExe $FactorioExe

    $bundled = @{}
    Get-ChildItem -Path $dataDir -Directory |
        Where-Object { $_.Name -notin @('base', 'core') -and (Test-Path (Join-Path $_.FullName 'info.json')) } |
        ForEach-Object { $bundled[$_.Name] = (Get-Content (Join-Path $_.FullName 'info.json') -Raw | ConvertFrom-Json) }
    return $bundled
}

function Resolve-BundledSelection {
    <#  Canonicalise the requested names and close over their hard dependencies.

        Both halves matter. space-age hard-depends on elevated-rails and quality, so enabling it
        alone writes a mod-list whose dependencies are explicitly disabled -- Factorio then fails
        on the missing dependency and it reads as this repo's mods being broken. And an unknown
        name must be rejected rather than ignored, or a typo produces a base-only run that gets
        reported as an expansion pass.

        Returns canonical names as a string array (empty when nothing was requested).  #>
    param(
        [string[]]   $Requested,
        [Parameter(Mandatory)] [hashtable] $Bundled
    )

    $requested = @($Requested | Where-Object { $_ })
    if (-not $requested) { return @() }

    $unknown = $requested | Where-Object { $_ -notin $Bundled.Keys }
    if ($unknown) {
        throw ("names no bundled mod: {0}. Available: {1}." -f
            ($unknown -join ', '), (($Bundled.Keys | Sort-Object) -join ', '))
    }

    $canonical = { param($n) $Bundled.Keys | Where-Object { $_ -eq $n } | Select-Object -First 1 }

    $enabled = [System.Collections.Generic.HashSet[string]]::new()
    $queue = [System.Collections.Queue]::new()
    foreach ($r in $requested) { $queue.Enqueue((& $canonical $r)) }

    while ($queue.Count -gt 0) {
        $m = $queue.Dequeue()
        if (-not $m -or -not $enabled.Add($m)) { continue }
        foreach ($dep in @($Bundled[$m].dependencies)) {
            # Skip optional ("?"), hidden-optional ("(?)") and incompatible ("!") only. "~" is a
            # REQUIRED dependency that merely does not affect load order, so it must be followed.
            if ($dep -match '^\s*[?!(]') { continue }
            $name = (($dep -replace '^\s*~?\s*', '') -split '\s+' | Select-Object -First 1)
            $c = & $canonical $name
            if ($c) { $queue.Enqueue($c) }
        }
    }
    return @($enabled | Sort-Object)
}

function Write-ModList {
    <#  Write mod-list.json enabling base, the given mods, and exactly the bundled mods in
        $EnabledBundled -- every other bundled mod is written explicitly disabled.

        OMITTING A MOD DOES NOT KEEP IT OUT, and that is the whole reason $Disabled exists.
        Factorio AUTO-ENABLES a mod present in the mod directory but absent from mod-list.json, so
        a list naming only some of what is on disk loads all of it. load-check.ps1's header has said
        so for a while -- it is why -SelfTest and -AlsoModDirectory are refused together -- and #209
        met it again from the other side: the containment gate takes a second dump with only our
        mods enabled, and with the set junctioned in beside them that dump silently loaded the set
        too. Both dumps were then the same dump, every category compared equal, and the gate reported
        containment surviving whatever the set had done. Name what must stay out; do not merely leave
        it unnamed.  #>
    param(
        [Parameter(Mandatory)] [string]    $ModDirectory,
        [Parameter(Mandatory)] [hashtable] $Bundled,
        [string[]] $EnabledBundled = @(),
        [string[]] $Mods = @(),
        [string[]] $Disabled = @()
    )

    # A name in both lists is a caller fault rather than a precedence question: Factorio reads the
    # last entry for a name and nothing here should depend on knowing that.
    $both = @($Mods | Where-Object { $Disabled -contains $_ })
    if ($both) {
        throw "Write-ModList: $($both -join ', ') given as both enabled and disabled."
    }

    $entries = @(@{ name = 'base'; enabled = $true })
    foreach ($m in ($Bundled.Keys | Sort-Object)) {
        $entries += @{ name = $m; enabled = [bool]($EnabledBundled -contains $m) }
    }
    foreach ($m in $Mods) { $entries += @{ name = $m; enabled = $true } }
    foreach ($m in $Disabled) { $entries += @{ name = $m; enabled = $false } }

    @{ mods = $entries } | ConvertTo-Json -Depth 4 |
        Set-Content -Path (Join-Path $ModDirectory 'mod-list.json') -Encoding utf8
}

function New-ModJunctions {
    <#  Link the repo's mod directories into a mod directory. Junctions rather than copies: no
        admin rights needed, nothing duplicated, and edits in the repo are picked up live.  #>
    param(
        [Parameter(Mandatory)] [string]   $ModDirectory,
        [Parameter(Mandatory)] [string]   $RepoRoot,
        [Parameter(Mandatory)] [string[]] $Mods
    )

    foreach ($m in $Mods) {
        $src = Join-Path $RepoRoot $m
        if (-not (Test-Path $src)) { throw "Mod directory not found in repo: $src" }
        $link = Join-Path $ModDirectory $m
        if (Test-Path $link) {
            # Only ever delete a junction here. A real directory of the same name -- an unzipped
            # release, a leftover copy -- would otherwise hit a non-recursive Directory.Delete and
            # either throw an opaque "directory is not empty" or, if empty, vanish silently.
            $existing = Get-Item -LiteralPath $link -Force
            if ($existing.LinkType -ne 'Junction') {
                throw "Refusing to replace '$link': it is a real directory, not a junction. Move or delete it yourself."
            }
            [IO.Directory]::Delete($link)
        }
        New-Item -ItemType Junction -Path $link -Target $src | Out-Null
    }
}

function Remove-ModJunctions {
    <#  Delete the junction entries themselves. Always call this before removing a directory that
        contains them: PowerShell 5.1's Remove-Item -Recurse follows junctions rather than
        skipping them, and would delete the repo's source through the link.  #>
    param([Parameter(Mandatory)] [string] $ModDirectory)

    Get-ChildItem -Path $ModDirectory -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.LinkType -eq 'Junction' } |
        ForEach-Object { [IO.Directory]::Delete($_.FullName) }
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

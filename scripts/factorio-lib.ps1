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

    Set-Content -Encoding utf8 -Path (Join-Path $RigDirectory 'data.lua') -Value @"
-- Generated by scripts/factorio-lib.ps1 (Write-PlasmaFeed). Nothing here ships.

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
        bench-mod-links.ps1 thirty-five. NEITHER OF THEM CALLS THIS YET -- check-brownout.ps1 is the
        only caller today, and it is here rather than in the rig so that the second and third rig to
        need it adopt one tested version instead of writing their own, which is where a copied
        safety guard starts to drift silently.

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
        $EnabledBundled -- every other bundled mod is written explicitly disabled.  #>
    param(
        [Parameter(Mandatory)] [string]    $ModDirectory,
        [Parameter(Mandatory)] [hashtable] $Bundled,
        [string[]] $EnabledBundled = @(),
        [string[]] $Mods = @()
    )

    $entries = @(@{ name = 'base'; enabled = $true })
    foreach ($m in ($Bundled.Keys | Sort-Object)) {
        $entries += @{ name = $m; enabled = [bool]($EnabledBundled -contains $m) }
    }
    foreach ($m in $Mods) { $entries += @{ name = $m; enabled = $true } }

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

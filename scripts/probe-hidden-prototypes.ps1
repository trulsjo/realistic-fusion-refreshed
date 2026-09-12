<#
.SYNOPSIS
    Probe: does a mod set hide prototypes of OURS from the player?

.DESCRIPTION
    A PROBE, NOT A GATE. It asserts nothing about what it finds and exits 0 whatever it reports, so a
    lane hiding nine of our fluids is a measurement and not a failure. Nothing here decides anything
    and nothing here ships. Whether this repository should work around another mod's pass is a
    coexistence decision and is deliberately not this script's to take
    (#219).

    IT RUNS NO MAP, which puts it with the minority of probes here rather than the majority: thirteen
    of the sixteen build one, and `probe-connection-categories.ps1` and `probe-dumped-reference.ps1`
    are the two that already did not. It only dumps prototypes, the way `name-check.ps1` and
    `locale-check.ps1` do, because `hidden` is a data-stage field and a running game would add nothing
    to the answer. Read that as "cheap", not as "weaker": there is no runtime behaviour here for a map
    to reveal.

    WHY THIS EXISTS

    `hidden` on a fluid takes it out of the crafting UI and out of the tooltips a player reads. On the
    `seablock` lane, nine of this repository's seventeen fluids come out hidden -- both reactor
    energies and every plasma except D-D, plus tritium, helium-3 and the two mix fluids -- so the
    fuels those reactors burn and the energy they sell are invisible to a player who installed that
    set. Nothing in this repository sets `hidden` on a fluid: the only assignment is
    `combinator.hidden` in realistic-fusion-refreshed/prototypes/signals.lua, which is ADR 0012's
    companion entity.

    AND NEITHER GATE CAN SEE IT, which is ADR 0007's finding 4 exactly. `name-check` compares content
    only for prototypes present in BOTH dumps and a prototype of ours is by construction in one;
    `load-check` asserts validity, assets, the simulation's invariants and containment, and a hidden
    fluid breaks none of them. So the finding had no repeatable instrument until this one, the same
    gap `probe-connection-categories.ps1` was written to fill for categories.

    WHICH MOD DOES IT IS NOT ANSWERED HERE, and cannot be. A dump records what a prototype ENDED UP
    as, never who wrote it. Two leads, from reading the cached set by hand rather than from any run:
    `angelsmods.functions.modify_barreling_recipes()` in angelsrefining loops over every fluid in
    data.raw and hides both barrel recipes, which explains the hidden BARREL RECIPES and not the
    hidden fluids; and no `hidden = true` assignment onto a fluid appears anywhere in the set's Lua
    on a plain grep, so whatever sets it is indirect.

    HOW IT MEASURES

    One `declared` dump and one `loaded` dump per lane:

      declared   Our three mods and nothing else. What our data stage sets, taken from the game
                 rather than from the Lua, so a field written by a helper reads the same as a
                 literal. Dumped ONCE and reused across every lane, because it does not depend on
                 which set is junctioned in beside it.

      loaded     The same mods with one lane's set junctioned in. Load order is the game's, and a
                 set's data-final-fixes runs after everything ours does.

    A prototype visible in `declared` and hidden in `loaded` is the finding. The reverse -- hidden by
    us and shown by them -- is reported too, under its own verdict, because it is the same class of
    edit and nobody has looked for it.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER AlsoModDirectory
    One lane's mod directory, e.g. .mod-cache/seablock. Omit it to walk EVERY lane cached under
    -ModCache, which is what the cross-lane question needs and is the default for that reason.

    This script downloads nothing. `scripts/fetch-mods.ps1 -Set <name>` is what fills the cache.

.PARAMETER ModCache
    Where the lanes live. Defaults to .mod-cache at the repository root. Every subdirectory holding
    at least one mod directory is a lane; anything else is skipped with a line saying so.

.PARAMETER With
    Bundled mods to enable, e.g. -With quality. None by default, which is the v1 target (ADR 0003).
    The seablock reading this probe was written against was taken with -With quality, so reproducing
    it needs the same switch.

.PARAMETER KeepTemp
    Keep the dumps for inspection. Junctions are always removed.

.EXAMPLE
    pwsh -File scripts/probe-hidden-prototypes.ps1
    pwsh -File scripts/probe-hidden-prototypes.ps1 -AlsoModDirectory .mod-cache/seablock -With quality
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string]   $FactorioExe,
    [string]   $AlsoModDirectory,
    [string]   $ModCache,
    [string[]] $With = @(),
    [switch]   $KeepTemp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'factorio-lib.ps1')

$repoRoot = Split-Path -Parent $PSScriptRoot
$ourMods  = Get-RepoMods -RepoRoot $repoRoot

# THE TYPES WORTH ASKING ABOUT, and the reason it is three rather than every type in the dump. A
# hidden FLUID is the finding #219 opened on; a hidden ITEM is the same accident one step along, and
# a hidden RECIPE is how BOTH barrel halves of it show up -- see $DERIVED below for why the
# `empty-` half needs its own pattern to be seen at all. Everything else this repository defines --
# technologies, entities, signals -- either has no `hidden` the player reads or is covered by one of
# these three through the item it places.
$TYPES = @('fluid', 'item', 'recipe')

$PREFIX = 'rf-'

# OURS BY PREFIX, AND ONE SHAPE THAT IS OURS BY CONSEQUENCE. Base Factorio generates
# `empty-rf-<fluid>-barrel` for each of our barrelled fluids, and that name does NOT start with the
# prefix -- it is ours because the fluid is, not because anyone chose it. name-check.ps1 carries the
# same pattern under the same name and says so in the same words.
#
# THIS PROBE HAS TO CARRY IT WHERE probe-connection-categories.ps1 DOES NOT, and the difference is
# the type list. That probe reads pipe connections, and a barrel recipe has no fluid box, so the
# derived names cannot reach its report at all; it says so and stops. This one reads recipes, where
# they appear and where they are hidden: on `seablock` four of them are, and a first version of this
# script filtered on the prefix alone and reported 22 where the answer is 26.
$DERIVED = "^empty-$PREFIX.+-barrel$"

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe
try   { $enabledBundled = Resolve-BundledSelection -Requested $With -Bundled $bundled }
catch { throw "-With $($_.Exception.Message)" }

if (-not $ModCache) { $ModCache = Join-Path $repoRoot '.mod-cache' }

# WHICH LANES TO WALK. One named, or every one cached. A directory holding no mod directory is not a
# lane and is named rather than skipped silently -- an empty .mod-cache would otherwise report
# "no set hides anything of ours", which is the shape of pass-by-finding-nothing this file's
# floor below exists to refuse.
$lanes = @()
if ($AlsoModDirectory) {
    if (-not (Test-Path $AlsoModDirectory)) { throw "-AlsoModDirectory not found: $AlsoModDirectory" }
    $lanes = @((Resolve-Path -LiteralPath $AlsoModDirectory).Path)
} else {
    if (-not (Test-Path $ModCache)) {
        throw ("no mod cache at $ModCache. Run scripts/fetch-mods.ps1 -Set <name> first, or pass " +
               '-AlsoModDirectory to probe one lane.')
    }
    $lanes = @(Get-ChildItem -Path $ModCache -Directory | Sort-Object Name | ForEach-Object { $_.FullName })
}

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-hidden-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
New-Item -ItemType Directory -Path $modDir -Force | Out-Null

function Get-OurVisibility {
    <#  Dump the game as currently junctioned, and return "type/name" -> $true when the prototype is
        hidden, for every prototype of ours in $TYPES.

        ABSENT IS NOT THE SAME AS VISIBLE, so a prototype the loaded dump does not hold at all is
        left out of the map rather than recorded as $false. A set that REMOVES one of our prototypes
        is a different accident from one that hides it, and the report below tells them apart.  #>
    param([Parameter(Mandatory)] [string[]] $Mods, [Parameter(Mandatory)] [string] $Tag)

    $rawPath = Join-Path $temp 'write-data/script-output/data-raw-dump.json'

    # DELETED BEFORE THE RUN, NOT MERELY OVERWRITTEN BY IT, for the reason
    # probe-connection-categories.ps1 gives: a run that exits 0 without writing would leave the
    # PREVIOUS lane's dump here, and every prototype would compare equal against it. That is this
    # instrument's last way of passing by finding nothing, and with one declared dump reused across
    # eleven lanes it is a real risk rather than a theoretical one.
    Remove-Item -LiteralPath $rawPath -Force -ErrorAction SilentlyContinue

    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabledBundled -Mods $Mods
    Invoke-FactorioStep -FactorioExe $FactorioExe -ModDirectory $modDir `
        -Arguments @('--dump-data') -OutputDirectory $temp -Tag $Tag | Out-Null

    if (-not (Test-Path $rawPath)) { throw "no data-raw-dump.json at $rawPath." }
    if ($KeepTemp) { Copy-Item -LiteralPath $rawPath -Destination (Join-Path $temp "$Tag-data-raw.json") -Force }

    $dump = Get-Content -LiteralPath $rawPath -Raw | ConvertFrom-Json -AsHashtable
    $map  = @{}
    foreach ($type in $TYPES) {
        if (-not $dump.ContainsKey($type)) { continue }
        foreach ($name in $dump[$type].Keys) {
            if (-not ($name.StartsWith($PREFIX, [StringComparison]::Ordinal) -or $name -match $DERIVED)) { continue }
            $p = $dump[$type][$name]
            $map["$type/$name"] = [bool] ($p.ContainsKey('hidden') -and $p['hidden'])
        }
    }
    return $map
}

$laneHidden = [ordered] @{}   # lane -> (key -> $true) for keys THIS lane hides and we do not
$laneShown  = [ordered] @{}   # lane -> (key -> $true) for keys THIS lane shows and we hide
$laneGone   = [ordered] @{}   # lane -> (key -> $true) for keys the lane's dump does not hold at all
$declared   = $null

try {
    Write-Host "bundled enabled: $(if ($enabledBundled) { $enabledBundled -join ', ' } else { 'none (base 2.0 only)' })"

    Write-Host 'dumping with our mods alone (declared)...'
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    $declared = Get-OurVisibility -Mods $ourMods -Tag 'declared'
    Remove-ModJunctions -ModDirectory $modDir

    # THE FLOOR. Everything below reports by finding a DIFFERENCE, so a walk that harvested nothing
    # would print "no lane hides anything of ours" and exit 0 -- the instrument failing and the
    # report reading like a clean result. This is the one non-zero exit that comes from what was
    # measured rather than from a run refusing to happen.
    if ($declared.Count -eq 0) {
        throw ("the declared dump holds no $($TYPES -join '/') prototype of ours at all. Either the " +
               'prefix has changed or this probe has stopped reading the dump -- and both would ' +
               'otherwise report a clean pass against every lane.')
    }
    # "ALREADY HIDDEN" RATHER THAN "HIDDEN BY US", because the declared dump is our mods plus
    # whatever -With enables, and the difference matters. Measured with -With quality: all 30 are
    # `rf-*-recycling` recipes the recycler generates from our machines and hides itself. Not one is
    # a fluid, and this repository's only `hidden` assignment is still the signals combinator. The
    # comparison below subtracts these, so a prototype hidden on both sides is never reported.
    $declaredHidden = @($declared.Keys | Where-Object { $declared[$_] })
    Write-Host ("declared: $($declared.Count) prototype(s) of ours across $($TYPES -join ', '), " +
                "$($declaredHidden.Count) already hidden before any set is loaded")

    foreach ($lane in $lanes) {
        $laneName = Split-Path -Leaf $lane
        $mods = @(Get-ChildItem -Path $lane -Directory |
            Where-Object { Test-Path (Join-Path $_.FullName 'info.json') } | ForEach-Object { $_.Name })
        if (-not $mods) {
            Write-Host "  $laneName -- holds no mod directory, skipped"
            continue
        }

        Write-Host "dumping lane '$laneName' ($($mods.Count) mod(s))..."
        New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
        New-ModJunctions -ModDirectory $modDir -RepoRoot $lane -Mods $mods
        $loaded = Get-OurVisibility -Mods ($ourMods + $mods) -Tag $laneName
        Remove-ModJunctions -ModDirectory $modDir

        $hid = @{}; $shown = @{}; $gone = @{}
        foreach ($key in $declared.Keys) {
            if (-not $loaded.ContainsKey($key)) { $gone[$key] = $true; continue }
            if ($loaded[$key] -and -not $declared[$key]) { $hid[$key]   = $true }
            if ($declared[$key] -and -not $loaded[$key]) { $shown[$key] = $true }
        }
        $laneHidden[$laneName] = $hid
        $laneShown[$laneName]  = $shown
        $laneGone[$laneName]   = $gone
        Write-Host ("  $laneName -- $($hid.Count) hidden by the set, $($shown.Count) un-hidden, " +
                    "$($gone.Count) absent from its dump")
    }
} finally {
    Remove-ModJunctions -ModDirectory $modDir -ErrorAction SilentlyContinue
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp }
    else { Write-Host "temp kept at: $temp" }
}

# ----------------------------------------------------------------------------------------- report
#
# ONE ROW PER PROTOTYPE, ONE COLUMN PER LANE, which is the shape the cross-lane question actually
# has: "does any other lane do this" is answered by reading across a row, and "what does this lane
# do" by reading down a column. A per-lane list would answer only the second and is what the
# seablock reading in #219 already was.
$reported = @($laneHidden.Keys)
if (-not $reported) {
    Write-Host ''
    Write-Host 'no lane was probed.'
    exit 0
}

$touched = @{}
foreach ($lane in $reported) {
    foreach ($k in $laneHidden[$lane].Keys) { $touched[$k] = $true }
    foreach ($k in $laneShown[$lane].Keys)  { $touched[$k] = $true }
}

Write-Host ''
if (-not $touched.Count) {
    Write-Host "no lane changes the visibility of any prototype of ours ($($reported.Count) lane(s) probed)."
} else {
    $width = (@($touched.Keys | ForEach-Object { $_.Length }) | Measure-Object -Maximum).Maximum
    # THE COLUMN IS AS WIDE AS THE WIDEST LANE NAME, not a fixed 12. `angels-bobs-madclowns` is 21
    # characters and ran into its neighbour, which put a cell under the wrong heading -- the one
    # error a table like this must not make, since reading across a row is the whole point of it.
    $col = [Math]::Max(12, (@($reported | ForEach-Object { $_.Length }) | Measure-Object -Maximum).Maximum + 2)
    Write-Host ("visibility of our prototypes, per lane -- H = the set hides it, U = the set un-hides " +
                "it, . = unchanged, - = absent from that lane's dump")
    Write-Host ''
    Write-Host ((' ' * $width) + '  ' + (($reported | ForEach-Object { $_.PadRight($col) }) -join ''))
    foreach ($k in ($touched.Keys | Sort-Object)) {
        $cells = foreach ($lane in $reported) {
            $c = if ($laneHidden[$lane].ContainsKey($k))     { 'H' }
                 elseif ($laneShown[$lane].ContainsKey($k))  { 'U' }
                 elseif ($laneGone[$lane].ContainsKey($k))   { '-' }
                 else                                        { '.' }
            $c.PadRight($col)
        }
        Write-Host ($k.PadRight($width) + '  ' + ($cells -join ''))
    }
}

Write-Host ''
foreach ($lane in $reported) {
    $absent = $laneGone[$lane].Count
    if ($absent) {
        Write-Host ("  $lane -- $absent prototype(s) of ours are absent from its dump entirely, which " +
                    'is removal rather than hiding and is a different question.')
    }
}

Write-Host ''
Write-Host ('A PROBE ASSERTS NOTHING. Exit 0 means it ran and reported, never that the answer was ' +
            'the hoped-for one. What to do about a lane that hides our fluids is a coexistence ' +
            'decision (#219); findings belong in docs/research/.')
exit 0

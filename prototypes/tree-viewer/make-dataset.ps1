#Requires -Version 7
<#
    PROTOTYPE (#161) — throwaway. Dumps the Krastorio 2 lane (base + 5 lane mods + this repo's 3)
    with --dump-data / --dump-prototype-locale, extracts what the viewer needs, and writes
    dataset.json next to this script. Probe rules: asserts nothing, exit 0 = ran and reported.

    Attribution here is PREFIX-BASED (kr-/rf-/else base) — deliberately crude; #158 records the
    real mechanisms and none is chosen yet. Overlap scoring is a rough cut of #160's tiers 1-2.
#>
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [string] $DumpDir,      # reuse an existing dump instead of running the game
    [string] $FocusMod = 'realistic-fusion-refreshed',   # whose things form the left side of every overlap pair
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. "$repoRoot/scripts/factorio-lib.ps1"

$laneDir  = Join-Path $repoRoot '.mod-cache/krastorio2'
$laneMods = @(Get-ChildItem -Path $laneDir -Directory | ForEach-Object Name)
$ourMods  = Get-RepoMods

if (-not $DumpDir) {
    $FactorioExe = Resolve-FactorioExe -Path $FactorioExe
    $bundled     = Get-BundledMods -FactorioExe $FactorioExe

    $temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-treeproto-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $modDir = Join-Path $temp 'mods'
    New-Item -ItemType Directory -Path $modDir -Force | Out-Null

    try {
        New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
        foreach ($m in $laneMods) {
            New-Item -ItemType Junction -Path (Join-Path $modDir $m) -Target (Join-Path $laneDir $m) | Out-Null
        }
        Write-ModList -ModDirectory $modDir -Bundled $bundled -Mods ($ourMods + $laneMods)

        foreach ($dump in @('--dump-data', '--dump-prototype-locale')) {
            $result = Invoke-Factorio -FactorioExe $FactorioExe -ModDirectory $modDir `
                -Arguments @($dump) -OutputDirectory $temp -Tag "treeproto$dump"
            if ($result.Code -ne 0) { Write-FactorioTail $result; throw "Factorio exited $($result.Code) on $dump." }
        }
        $DumpDir = Join-Path $temp 'write-data/script-output'
    }
    finally {
        Remove-ModJunctions -ModDirectory $modDir
    }
}

Write-Host "reading dumps from $DumpDir"
$raw = Get-Content -LiteralPath (Join-Path $DumpDir 'data-raw-dump.json') -Raw | ConvertFrom-Json -AsHashtable

function Read-LocaleNames([string] $File) {
    $p = Join-Path $DumpDir $File
    if (-not (Test-Path $p)) { return @{} }
    $parsed = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json -AsHashtable
    if ($parsed.names) { return $parsed.names } else { return @{} }
}
$techLocale   = Read-LocaleNames 'technology-locale.json'
$itemLocale   = Read-LocaleNames 'item-locale.json'
$fluidLocale  = Read-LocaleNames 'fluid-locale.json'
$entityLocale = Read-LocaleNames 'entity-locale.json'
$recipeLocale = Read-LocaleNames 'recipe-locale.json'

function Get-Mod([string] $Name) {
    if ($Name.StartsWith('rf-'))  { return 'realistic-fusion-refreshed' }
    if ($Name.StartsWith('kr-'))  { return 'Krastorio2' }
    return 'base'
}

# ---- overlap candidates: #160 tiers 1-2, cross-mod only, items+fluids+entities ----
$STOP = @('the','and','with','from','advanced','basic','improved','empty','used','mk1','mk2','mk3')
function Get-Tokens([string] $s) {
    @(($s.ToLowerInvariant() -split '[^a-z0-9]+') | Where-Object { $_.Length -ge 4 -and $_ -notin $STOP })
}
$catalogues = @(
    @{ cat = 'item';   names = $itemLocale },
    @{ cat = 'fluid';  names = $fluidLocale },
    @{ cat = 'entity'; names = $entityLocale }
)
$things = foreach ($c in $catalogues) {
    foreach ($kv in $c.names.GetEnumerator()) {
        [pscustomobject]@{ Name = $kv.Key; Label = $kv.Value; Cat = $c.cat; Mod = Get-Mod $kv.Key }
    }
}
$focusThings = @($things | Where-Object Mod -eq $FocusMod)
$otherThings = @($things | Where-Object { $_.Mod -ne $FocusMod })   # base included; pairs carry a flag

$overlaps = [System.Collections.Generic.List[object]]::new()
foreach ($a in $focusThings) {
    $ta = Get-Tokens $a.Label
    foreach ($b in $otherThings) {
        $score = 0; $tier = 0
        if ($a.Label -and ($a.Label -ieq $b.Label)) { $score = 4; $tier = 1 }
        else {
            $shared = @($ta | Where-Object { $_ -in (Get-Tokens $b.Label) })
            if ($shared.Count -ge 1) { $score = $shared.Count; $tier = 2 }
        }
        if ($tier -eq 0) { continue }
        if ($a.Cat -eq $b.Cat) { $score++ }   # same-class boost (#160)
        $overlaps.Add([pscustomobject]@{
            a = $a.Name; aLabel = $a.Label; aCat = $a.Cat; aMod = $a.Mod
            b = $b.Name; bLabel = $b.Label; bCat = $b.Cat; bMod = $b.Mod
            score = $score; tier = $tier; base = ($b.Mod -eq 'base')
        })
    }
}
# base pairs are computed but viewer-filtered (#160): keep them distinct so the viewer's
# "include base-game overlaps" toggle has something to reveal without drowning the mod pairs
$overlaps = @(
    @($overlaps | Where-Object { -not $_.base } | Sort-Object score -Descending | Select-Object -First 120) +
    @($overlaps | Where-Object base            | Sort-Object score -Descending | Select-Object -First 80)
)
$overlapNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($o in ($overlaps | Where-Object { -not $_.base })) { [void]$overlapNames.Add($o.a); [void]$overlapNames.Add($o.b) }

# ---- recipe products, for unlock labels and overlap badging ----
function Get-RecipeResults($recipe) {
    if (-not $recipe.results) { return @() }
    @($recipe.results | ForEach-Object { $_.name } | Where-Object { $_ })
}

# ---- technologies ----
$techs = [System.Collections.Generic.List[object]]::new()
foreach ($kv in $raw['technology'].GetEnumerator()) {
    $name = $kv.Key; $t = $kv.Value
    $packs = @(); $count = $null; $formula = $null; $trigger = $null; $time = $null
    if ($t.unit) {
        $count   = $t.unit.count
        $formula = $t.unit.count_formula
        $time    = $t.unit.time
        $packs   = @($t.unit.ingredients | ForEach-Object { ,@($_[0], $_[1]) })
    }
    elseif ($t.research_trigger) {
        $rt = $t.research_trigger
        $trigger = (@($rt.type, $rt.item, $rt.entity, $rt.count) | Where-Object { $_ }) -join ' '
    }
    $unlocks = [System.Collections.Generic.List[object]]::new()
    $bonuses = [System.Collections.Generic.List[string]]::new()
    $hasOverlap = $false
    foreach ($e in @($t.effects)) {
        if (-not $e) { continue }
        if ($e.type -eq 'unlock-recipe') {
            $r = $raw['recipe'][$e.recipe]
            $results = if ($r) { Get-RecipeResults $r } else { @() }
            $label = if ($recipeLocale[$e.recipe]) { $recipeLocale[$e.recipe] }
                     elseif ($results.Count -and $itemLocale[$results[0]]) { $itemLocale[$results[0]] }
                     elseif ($results.Count -and $fluidLocale[$results[0]]) { $fluidLocale[$results[0]] }
                     else { $e.recipe }
            foreach ($res in $results) { if ($overlapNames.Contains($res)) { $hasOverlap = $true } }
            $unlocks.Add(@{ name = $e.recipe; label = $label; results = @($results) })
        }
        else {
            $desc = $e.type
            if ($null -ne $e.modifier -and $e.modifier -isnot [bool]) { $desc += " $($e.modifier)" }
            $bonuses.Add($desc)
        }
    }
    $techs.Add([ordered]@{
        id      = $name
        label   = if ($techLocale[$name]) { $techLocale[$name] } else { $name }
        mod     = Get-Mod $name
        prereqs = @($t.prerequisites)
        count   = $count; formula = $formula; trigger = $trigger; time = $time
        packs   = $packs
        unlocks = @($unlocks)
        bonuses = @($bonuses)
        overlap = $hasOverlap
        upgrade = [bool]$t.upgrade
        hidden  = [bool]$t.hidden
    })
}

$packOrder = [System.Collections.Generic.List[string]]::new()
foreach ($t in $techs) { foreach ($p in $t.packs) { if ($packOrder -notcontains $p[0]) { $packOrder.Add($p[0]) } } }

$dataset = [ordered]@{
    meta = [ordered]@{
        generated = (Get-Date -Format 'yyyy-MM-dd HH:mm')
        factorio  = '2.0.77'
        lane      = 'krastorio2'
        mods      = ($ourMods + $laneMods)
        techCount = $techs.Count
        focusMod  = $FocusMod
        note      = 'PROTOTYPE dataset (#161). Attribution is prefix-based; overlap scoring is a rough cut of #160.'
    }
    packs    = @($packOrder)
    packLabels = @{}
    techs    = @($techs)
    overlaps = @($overlaps)
}
foreach ($p in $packOrder) { $dataset.packLabels[$p] = if ($itemLocale[$p]) { $itemLocale[$p] } else { $p } }

$outPath = Join-Path $PSScriptRoot 'dataset.json'
$dataset | ConvertTo-Json -Depth 8 -Compress | Set-Content -Path $outPath -Encoding utf8
Write-Host "wrote $outPath  ($($techs.Count) techs, $($overlaps.Count) overlap candidates)"

if ($temp) {
    if ($KeepTemp) { Write-Host "temp kept at: $temp" }
    else { Remove-TempDirectory -Path $temp -Label 'tree-proto' }
}
exit 0

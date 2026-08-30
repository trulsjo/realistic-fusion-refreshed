<#
.SYNOPSIS
    Renders a mod set's technology tree as a self-contained zoomable HTML viewer, with per-prototype
    mod attribution and heuristic overlap candidates. The lane analysis instrument of #157.

.DESCRIPTION
    A PROBE-FAMILY TOOL, NOT A CHECK. It asserts nothing about the tree it draws: exit 0 means it
    ran and reported, never that the tree looked right or the overlaps were welcome. It must not be
    added to a check sweep or to load-check.ps1. Its purpose (ADR 0007/0026/0027) is to let a human
    see how a coexistence lane's tech tree and this repo's interleave, and judge conceptual
    overlaps no green/red check can see.

    THREE FACTORIO RUNS, ONE OUTPUT

      --dump-data                data.raw as JSON: technologies, recipes, costs, effects
                                 (field semantics: docs/research/tech-tree-dump-fields.md, #159)
      --dump-prototype-locale    resolved localized names per category
      --create                   fires on_init in a generated exporter mod, which walks
                                 prototypes.get_history() for every technology, recipe, item,
                                 fluid and entity and writes the histories to script-output

    Attribution is the engine's own PrototypeHistory (#164): a node is coloured by `created`, the
    `changed` chain rides in its detail panel, and a tick marks prototypes changed by a mod other
    than their creator. Measured semantics (#165, docs/research/get-history-semantics.md): the
    original mod stays `created` under wholesale redefinition, and `changed` records value changes
    only. If the set cannot reach the runtime stage the run FAILS LOUDLY and emits nothing --
    a lane that cannot create a map is a red lane, and the crash log is the finding.

    Overlap candidates follow #160's three-tier heuristic -- localized-name equality, then token
    overlap after stopwords, then prototype-name stems after prefix stripping -- computed for
    things (items, fluids, entities) between the focus mod and everything else. False positives
    are expected and fine: the viewer surfaces candidates, a human judges. Base-game pairs are
    computed, shipped flagged, and hidden behind a viewer toggle.

    Read "localized-name" there with one caveat (#169, corrected by #179). Some dumped names are
    not names: an engine "Unknown key" or "Unknown control sequence" left inside the resolved text,
    or a placeholder another mod ships deliberately -- Angels gives [item-name] angels-void the
    literal value "Something went wrong" and points 334 of its recipes at it. Get-LocaleFailure in
    factorio-lib.ps1 holds the list and the measurements behind it. A thing in that state is
    labelled by its PROTOTYPE name instead, so the first two tiers then compare that name rather
    than a localized one. The run reports how many the set failed to localize; the number is the
    mods' own localisation, not this tool's, and nothing here tries to fix it. What is fixed is
    that no label is ever one of those strings.

    Researchability rides along the same way (#168): each technology carries its `enabled`,
    `hidden` and `visible_when_disabled` state, and the ones no player can research are kept off
    the canvas until a toggle reveals them, dashed and dimmed. They are flagged, never dropped --
    a dead base tech another mod left standing is a finding about how the lane interleaves.

    The viewer itself is the design settled on #161 (scripts/tree-viewer.template.html): dagre
    layered cards, top-down, d3 pan/zoom, detail on the card near and counter-scaled badges far,
    click for a side panel with prerequisite/dependent links highlighted. The libraries load from a
    CDN -- the accepted trade-off; the output needs network to render. Two CDNs, since #182: d3 from
    cdnjs as #161 settled, dagre from jsdelivr, because cdnjs's dagre stops at 0.8.5 and the
    maintained package is not on cdnjs at any version. The template's own comment carries the rest.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER AlsoModDirectory
    Directories of unpacked third-party mods to load, e.g. .mod-cache/krastorio2 as populated by
    scripts/fetch-mods.ps1. Every immediate subdirectory holding an info.json is loaded.

.PARAMETER NoRepoMods
    Leave this repo's own mods out. The destination allows an arbitrary set; by default ours ride
    along because the point is usually to see the interleaving.

.PARAMETER With
    Bundled mods to enable, e.g. -With space-age. Same semantics as the checks.

.PARAMETER FocusMod
    The mod(s) whose things form the LEFT side of every overlap pair (#160/#161). Defaults to all
    of this repo's mods in the set — a list, not one name, because engine attribution splits this
    project into its real creators (core defines the fluids the main mod's techs unlock). With no
    focus mod in the set, overlap analysis is off and the viewer says so.

.PARAMETER OutName
    Basename of the emitted HTML, and the title the viewer shows. Default: tech-tree.
    Output lands in tree-viewer-out\<OutName>.html (git-ignored).

.PARAMETER KeepTemp
    Keep the dumps, the exporter mod and the captured output for inspection.

.EXAMPLE
    pwsh -File scripts/tree-viewer.ps1 -AlsoModDirectory .mod-cache/krastorio2 -OutName krastorio2-lane

.EXAMPLE
    pwsh -File scripts/tree-viewer.ps1 -NoRepoMods -AlsoModDirectory .mod-cache/angels -OutName angels-alone
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string]   $FactorioExe,
    [string[]] $AlsoModDirectory = @(),
    [switch]   $NoRepoMods,
    [string[]] $With = @(),
    [string[]] $FocusMod = @(),
    [string]   $OutName = 'tech-tree',
    [switch]   $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$rigName  = 'rf-treeview-history'
$outDir   = Join-Path $repoRoot 'tree-viewer-out'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe
try { $enabledBundled = Resolve-BundledSelection -Requested $With -Bundled $bundled }
catch { throw "-With $($_.Exception.Message)" }

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-treeview-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
New-Item -ItemType Directory -Path $modDir -Force | Out-Null

# ---------------------------------------------------------------------------------------------
# Assemble the set: repo mods by junction, every info.json-bearing subdirectory of each
# -AlsoModDirectory by junction, plus the generated history exporter. Mod titles are read here so
# the viewer's legend can print names rather than internal ids.
# ---------------------------------------------------------------------------------------------
$modTitles = @{ base = 'Base'; core = 'Factorio core' }
$setMods   = [System.Collections.Generic.List[string]]::new()

$ourMods = @(); $repoModNames = @()
if (-not $NoRepoMods) {
    $ourMods = Get-RepoMods
    foreach ($m in $ourMods) {
        $info = Get-Content (Join-Path $repoRoot (Join-Path $m 'info.json')) -Raw | ConvertFrom-Json
        $modTitles[$info.name] = $info.title
        $setMods.Add($info.name)
        $repoModNames += $info.name
    }
}
# Enumerated here, junctioned inside the try below: a junction left behind by an early throw is
# the delete-through-the-link hazard factorio-lib's Remove-ModJunctions exists to prevent.
$alsoSubs = [System.Collections.Generic.List[object]]::new()
foreach ($dir in $AlsoModDirectory) {
    $resolved = Resolve-Path -LiteralPath $dir   # junctions refuse relative targets
    foreach ($sub in Get-ChildItem -Path $resolved -Directory) {
        $infoPath = Join-Path $sub.FullName 'info.json'
        if (-not (Test-Path $infoPath)) { continue }
        $info = Get-Content $infoPath -Raw | ConvertFrom-Json
        $alsoSubs.Add($sub)
        $modTitles[$info.name] = $info.title
        $setMods.Add($info.name)
    }
}
if ($setMods.Count -eq 0 -and $NoRepoMods) { throw 'nothing to load: -NoRepoMods and no -AlsoModDirectory.' }

# The exporter: an empty data stage and an on_init that asks the engine for every prototype's
# history. It defines nothing, so its presence changes nothing about the tree it measures.
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null
@{
    name = $rigName; version = '0.0.1'; title = 'Tree-viewer history exporter'
    author = 'tree-viewer.ps1'; factorio_version = '2.0'; dependencies = @('base >= 2.0.77')
} | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8
Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') -Value @'
-- Generated by tree-viewer.ps1. Reports; asserts nothing; defines nothing.
script.on_init(function()
  local classes = {
    technology = prototypes.technology, recipe = prototypes.recipe,
    item = prototypes.item, fluid = prototypes.fluid, entity = prototypes.entity,
  }
  local out = {}
  for class, tbl in pairs(classes) do
    local rows = {}
    for name, p in pairs(tbl) do
      -- get_history takes the concrete type ("boiler", "tool"), which is what p.type reports.
      local ok, h = pcall(prototypes.get_history, p.type, name)
      if ok and h then rows[name] = { c = h.created, ch = h.changed }
      else rows[name] = { c = "?", err = tostring(h) } end
    end
    out[class] = rows
  end
  helpers.write_file("rf-treeview-history.json", helpers.table_to_json(out))
  log("TREEVIEW done")
end)
'@

try {
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabledBundled `
        -Mods (@($setMods) + $rigName)
    if (-not $NoRepoMods) { New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods }
    foreach ($sub in $alsoSubs) {
        New-Item -ItemType Junction -Path (Join-Path $modDir $sub.Name) -Target $sub.FullName | Out-Null
    }

    $bundledOn = if ($enabledBundled) { $enabledBundled -join ', ' } else { 'none (base 2.0 only)' }
    Write-Host "tree-viewer: $($setMods -join ', ')  |  bundled enabled: $bundledOn"

    $step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }
    Invoke-FactorioStep @step -Tag 'dump-data'   -Arguments @('--dump-data') | Out-Null
    Invoke-FactorioStep @step -Tag 'dump-locale' -Arguments @('--dump-prototype-locale') | Out-Null
    # The attribution run. A set that cannot create a map fails HERE, loudly, by design (#164):
    # Invoke-FactorioStep prints both stream tails and throws, and no viewer is emitted.
    $createOut = Invoke-FactorioStep @step -Tag 'create' -Arguments @('--create', (Join-Path $temp 'treeview.zip'))

    $factorioVersion = 'unknown'
    $m = Select-String -Path $createOut -Pattern 'Factorio (\d+\.\d+\.\d+)' | Select-Object -First 1
    if ($m) { $factorioVersion = $m.Matches[0].Groups[1].Value }

    # ------------------------------------------------------------------------- read the three outputs
    $scriptOutput = Join-Path $temp 'write-data/script-output'
    $rawPath  = Join-Path $scriptOutput 'data-raw-dump.json'
    $histPath = Join-Path $scriptOutput 'rf-treeview-history.json'
    if (-not (Test-Path $rawPath))  { throw "no data-raw-dump.json in $scriptOutput." }
    if (-not (Test-Path $histPath)) { throw "no rf-treeview-history.json in $scriptOutput; the exporter never ran." }

    Write-Host 'parsing dumps...'
    $raw     = Get-Content -LiteralPath $rawPath  -Raw | ConvertFrom-Json -AsHashtable
    $history = Get-Content -LiteralPath $histPath -Raw | ConvertFrom-Json -AsHashtable
    # EVERY read of a key from these two dumps uses INDEX access, never dot (#167). On a hashtable,
    # dot-access falls back to .NET members when the key is absent, so a missing key yields metadata
    # instead of $null: `.item` renders the Item indexer's signature, `.count` the entry count. Both
    # shipped. Dot-access on the tables THIS script builds ($h.c, $t.packs) is safe and stays.

    function Read-LocaleNames([string] $File) {
        $p = Join-Path $scriptOutput $File
        if (-not (Test-Path $p)) { return @{} }
        $parsed = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json -AsHashtable
        # -AsHashtable gives a CASE-INSENSITIVE map, where locale-check.ps1 builds an ordinal one
        # over the same files. Left as it is on purpose: prototype names are lowercase by
        # convention, and if one ever is not, the gate is the lane that must not guess. Here a
        # case-folded hit returns a plausible label instead of none, which for a tool that asserts
        # nothing is the better of the two wrong answers.
        if ($parsed['names']) { return $parsed['names'] } else { return @{} }
    }
    # Absent key OR a value that is not a name -> $null, so a caller's existing fall-through runs.
    # Nothing else here changes: the chain behind an unlock label already knew where to look next,
    # and was only ever stopped by an unusable value arriving as a truthy one -- which is how
    # "Something went wrong" reached the Sulphur processing card (#169). Every locale read goes
    # through this, and what counts as unusable lives in factorio-lib.ps1 (#179) -- which keeps
    # two lists, not one. This reads BOTH, engine errors and the placeholders other mods ship,
    # because the question here is whether a string makes a usable label. locale-check.ps1 asks
    # the narrower question of whether it resolved, so it reads only the engine half.
    function Get-LocaleName($Map, [string] $Key) {
        $v = $Map[$Key]
        if (-not $v -or (Get-LocaleFailure $v)) { return $null }
        return $v
    }

    $techLocale   = Read-LocaleNames 'technology-locale.json'
    $itemLocale   = Read-LocaleNames 'item-locale.json'
    $fluidLocale  = Read-LocaleNames 'fluid-locale.json'
    $entityLocale = Read-LocaleNames 'entity-locale.json'
    $recipeLocale = Read-LocaleNames 'recipe-locale.json'

    # Both dumps write an empty Lua table as {}, so a key that should be a list arrives as an empty
    # OBJECT -- and an absent key arrives as $null, which @() turns into a one-element array holding
    # $null. Either ships junk the template silently filters. Every list-valued dump key comes
    # through here (#167); the comma keeps the empty array from unrolling to $null on return.
    function Get-DumpList($Value) {
        if ($Value -is [System.Collections.IList]) { return ,@($Value) }
        return ,@()
    }

    # A boolean the dump OMITS when it holds its default -- which is how all three of a
    # technology's researchability flags arrive when nothing switched them (#168): `enabled`
    # defaults to true, `hidden` and `visible_when_disabled` to false.
    # <https://lua-api.factorio.com/2.0.77/prototypes/TechnologyPrototype.html>
    function Get-DumpFlag($Value, [bool] $Default) {
        if ($null -eq $Value) { return $Default }
        return [bool]$Value
    }

    # Two of a trigger's six ID-bearing fields are FILTER unions at 2.0.77 -- a bare ID *or* a
    # {name, quality, comparator} table: craft-item's `item` (ItemIDFilter) and build-entity's
    # `entity` (EntityIDFilter). The rest are plain IDs: mine-entity's and capture-spawner's
    # `entity` are EntityID, send-item-to-orbit's `item` is ItemID, craft-fluid's `fluid` is
    # FluidID. Joining a table form into the label would print "System.Collections.Hashtable" --
    # the same leak of .NET metadata into node text this fixes -- so the two filter fields go
    # through here. A bare ID passes straight back, which is why the caller can apply it to both
    # `item` and `entity` without caring which variant it holds.
    # <https://lua-api.factorio.com/2.0.77/types/ItemIDFilter.html>
    # <https://lua-api.factorio.com/2.0.77/types/EntityIDFilter.html>
    function Get-FilterName($Value) {
        if ($Value -is [System.Collections.IDictionary]) { return $Value['name'] }
        return $Value
    }

    function Get-History([string] $Class, [string] $Name) {
        $row = $history[$Class][$Name]
        if (-not $row) { return @{ c = 'base'; ch = @() } }
        return @{ c = $row['c']; ch = (Get-DumpList $row['ch']) }
    }

    # ------------------------------------------------------------------------- overlap candidates (#160)
    if (-not $FocusMod) { $FocusMod = @($repoModNames) }
    $focusSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$FocusMod, [StringComparer]::Ordinal)

    $STOP = @('the','and','with','from','advanced','basic','improved','empty','used','mk1','mk2','mk3')
    function Get-Tokens([string] $s) {
        @(($s.ToLowerInvariant() -split '[^a-z0-9]+') | Where-Object { $_.Length -ge 4 -and $_ -notin $STOP })
    }
    # Tier 3 works on the prototype NAME with its mod prefix stripped: kr-fusion-reactor and
    # rf-dd-reactor share the stem token "reactor" even when the localized labels do not line up.
    function Get-StemTokens([string] $name) {
        @(( ($name -replace '^[a-z0-9]{1,8}-', '') -split '[-_]' ) |
            Where-Object { $_.Length -ge 4 -and $_ -notin $STOP })
    }

    $things = [System.Collections.Generic.List[object]]::new()
    foreach ($cat in @(@('item', $itemLocale), @('fluid', $fluidLocale), @('entity', $entityLocale))) {
        $catName, $locale = $cat
        foreach ($kv in $locale.GetEnumerator()) {
            $h = Get-History $catName $kv.Key
            # A thing whose dumped name is not usable as one stays in the analysis under its
            # prototype name rather than dropping out of it (#169). Tier 3 reads the prototype name
            # anyway, so it can still pair; and a thing silently missing from the pool is a worse
            # answer than one labelled plainly. Its tokens then come from that name, not from the
            # unusable text -- and that text carries real tokens if you let it. "wrong" and
            # "something" from Angels' placeholder, "unknown" and "sequence" from an engine error:
            # four letters or more, straight through the stopword filter, and feeding tier 2
            # overlap between two things that have nothing whatever in common.
            $label = Get-LocaleName $locale $kv.Key
            if (-not $label) { $label = $kv.Key }
            $things.Add([pscustomobject]@{
                Name = $kv.Key; Label = $label; Cat = $catName; Mod = $h.c
                Tokens = Get-Tokens $label; Stems = Get-StemTokens $kv.Key
            })
        }
    }

    $overlaps = [System.Collections.Generic.List[object]]::new()
    if ($focusSet.Count) {
        Write-Host "scoring overlaps (focus: $($FocusMod -join ', '))..."
        $focusThings = @($things | Where-Object { $focusSet.Contains($_.Mod) })
        $otherThings = @($things | Where-Object { -not $focusSet.Contains($_.Mod) })
        $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($a in $focusThings) {
            foreach ($b in $otherThings) {
                $score = 0; $tier = 0
                if ($a.Label -and ($a.Label -ieq $b.Label)) { $score = 4; $tier = 1 }
                elseif ($a.Tokens.Count) {
                    $shared = @($a.Tokens | Where-Object { $_ -in $b.Tokens })
                    if ($shared.Count -ge 1) { $score = $shared.Count; $tier = 2 }
                }
                if ($tier -eq 0 -and $a.Stems.Count) {
                    $shared = @($a.Stems | Where-Object { $_ -in $b.Stems })
                    if ($shared.Count -ge 1) { $score = $shared.Count; $tier = 3 }
                }
                if ($tier -eq 0) { continue }
                if (-not $seen.Add("$($a.Name)|$($b.Name)")) { continue }
                if ($a.Cat -eq $b.Cat) { $score++ }   # same-class boost
                $overlaps.Add([pscustomobject]@{
                    a = $a.Name; aLabel = $a.Label; aCat = $a.Cat; aMod = $a.Mod
                    b = $b.Name; bLabel = $b.Label; bCat = $b.Cat; bMod = $b.Mod
                    score = $score; tier = $tier; base = ($b.Mod -in @('base', 'core'))
                })
            }
        }
    }
    # Base pairs are computed but viewer-filtered (#160): shipped flagged and capped separately so
    # the toggle has something to reveal without drowning the mod pairs.
    $overlaps = @(
        @($overlaps | Where-Object { -not $_.base } | Sort-Object score -Descending | Select-Object -First 150) +
        @($overlaps | Where-Object base            | Sort-Object score -Descending | Select-Object -First 100)
    )

    # ------------------------------------------------------------------------- technologies (#159)
    # The comma is load-bearing, exactly as in Get-DumpList: PowerShell UNROLLS a one-element
    # array on return, so a single-result recipe came back as the bare string and $results[0] then
    # indexed that STRING -- yielding 's' for sulfuric-acid, never the name. Silent since #159,
    # because the label chain only reaches $results[0] when the recipe's own locale entry misses,
    # which before #169 also meant it had stopped on the sentinel. Nineteen of the Angels lane's
    # twenty-eight failed labels are this bug, not the sentinel.
    function Get-RecipeResults($recipe) {
        if (-not $recipe['results']) { return ,@() }
        ,@($recipe['results'] | ForEach-Object { $_['name'] } | Where-Object { $_ })
    }

    $techs = [System.Collections.Generic.List[object]]::new()
    foreach ($kv in $raw['technology'].GetEnumerator()) {
        $name = $kv.Key; $t = $kv.Value
        $h = Get-History 'technology' $name
        $packs = @(); $count = $null; $formula = $null; $trigger = $null; $time = $null
        if ($t['unit']) {
            $u = $t['unit']
            $count = $u['count']; $formula = $u['count_formula']; $time = $u['time']
            $packs = @($u['ingredients'] | ForEach-Object { ,@($_[0], $_[1]) })
        }
        elseif ($t['research_trigger']) {
            # The data-bearing field of every TechnologyTrigger variant at 2.0.77: craft-item
            # (item, count, default 1), craft-fluid (fluid, amount, default 0), mine-entity and
            # build-entity (entity), send-item-to-orbit (item), capture-spawner (entity,
            # optional), create-space-platform (type alone). Absent keys -- which is how the dump
            # writes a field left at its default -- just drop out of the join.
            # Not rendered: scripted's trigger_description and icon fields, which describe how the
            # trigger PRESENTS itself rather than what satisfies it, and so say nothing about the
            # tree. Read the variant pages, not the union page: it lists the variants without
            # their fields. <https://lua-api.factorio.com/2.0.77/types/TechnologyTrigger.html>
            $rt = $t['research_trigger']
            $trigger = (@($rt['type'], (Get-FilterName $rt['item']), (Get-FilterName $rt['entity']),
                          $rt['fluid'], $rt['count'], $rt['amount']) | Where-Object { $_ }) -join ' '
        }
        $unlocks = [System.Collections.Generic.List[object]]::new()
        $bonuses = [System.Collections.Generic.List[string]]::new()
        # `effects = {}` dumps as an empty OBJECT, which survives the per-effect guard as one truthy
        # element and adds a blank bonus -- 66 techs here, rf-plasma-confinement-1 among them.
        foreach ($e in (Get-DumpList $t['effects'])) {
            if (-not $e) { continue }
            if ($e['type'] -eq 'unlock-recipe') {
                $recipeName = $e['recipe']
                $r = $raw['recipe'][$recipeName]
                $results = if ($r) { Get-RecipeResults $r } else { @() }
                # Recipe name, then the first result's item and fluid names, then the prototype
                # name. Same order as before; it just no longer halts on the sentinel, so
                # sulfuric-acid falls through the failed recipe entry to the fluid's "Sulfuric
                # acid". The last step is the prototype name and never the sentinel (#169).
                $first = if ($results.Count) { $results[0] } else { $null }
                $label = Get-LocaleName $recipeLocale $recipeName
                if (-not $label -and $first) { $label = Get-LocaleName $itemLocale  $first }
                if (-not $label -and $first) { $label = Get-LocaleName $fluidLocale $first }
                if (-not $label) { $label = $recipeName }
                $unlocks.Add(@{ name = $recipeName; label = $label; results = @($results) })
            }
            else {
                $desc = $e['type']
                $modifier = $e['modifier']
                if ($null -ne $modifier -and $modifier -isnot [bool]) { $desc += " $modifier" }
                $bonuses.Add($desc)
            }
        }
        # The changed chain, order kept, deduplicated, without the creator's own later edits (#164).
        $changedBy = [System.Collections.Generic.List[string]]::new()
        foreach ($c in $h.ch) { if ($c -ne $h.c -and $changedBy -notcontains $c) { $changedBy.Add($c) } }
        # No technology carries the sentinel on the Angels lane, but the path has the same shape
        # and no lane is proof of every lane (#169).
        $techLabel = Get-LocaleName $techLocale $name
        if (-not $techLabel) { $techLabel = $name }
        $techs.Add([ordered]@{
            id = $name; label = $techLabel
            mod = $h.c; changedBy = @($changedBy)
            # Absent when a tech has none, so @() alone shipped [null] -- steam-power and
            # electronics here, filtered by the template and wrong in the dataset all the same.
            prereqs = (Get-DumpList $t['prerequisites'])
            count = $count; formula = $formula; trigger = $trigger; time = $time
            packs = $packs; unlocks = @($unlocks); bonuses = @($bonuses)
            # Researchability, shipped rather than dropped (#168): a tech another mod switched off
            # is a finding about how the lane interleaves, so the viewer flags and hides it behind
            # a toggle instead of the dataset losing it. Angels leaves 72 of these on the canvas,
            # sulfur-processing among them -- an orphan card with no edges, which is what a reader
            # notices first.
            enabled = (Get-DumpFlag $t['enabled'] $true)
            hidden = (Get-DumpFlag $t['hidden'] $false)
            visibleWhenDisabled = (Get-DumpFlag $t['visible_when_disabled'] $false)
        })
    }

    $packOrder = [System.Collections.Generic.List[string]]::new()
    foreach ($t in $techs) { foreach ($p in $t.packs) { if ($packOrder -notcontains $p[0]) { $packOrder.Add($p[0]) } } }
    $packLabels = @{}
    foreach ($p in $packOrder) {
        $n = Get-LocaleName $itemLocale $p
        $packLabels[$p] = if ($n) { $n } else { $p }
    }

    # ------------------------------------------------------------------------- mod legend and colours
    # Every mod the viewer will name: creators of techs, their modifiers, and both sides of every
    # pair. Focus first, base and core last, the rest in load-list order.
    $named = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($t in $techs) { [void]$named.Add($t.mod); foreach ($c in $t.changedBy) { [void]$named.Add($c) } }
    foreach ($o in $overlaps) { [void]$named.Add($o.aMod); [void]$named.Add($o.bMod) }
    $ordered = @()
    $ordered += @($FocusMod | Where-Object { $named.Contains($_) })
    $ordered += @($setMods | Where-Object { $named.Contains($_) -and $_ -notin $ordered })
    $ordered += @($named | Where-Object { $_ -notin $ordered -and $_ -notin @('base', 'core') } | Sort-Object)
    foreach ($b in @('base', 'core')) { if ($named.Contains($b)) { $ordered += $b } }

    # Focus mods share a cyan family so the project reads as one thing at a glance while its real
    # creators stay tellable apart -- the engine splits what the prefix heuristic used to blur.
    $FOCUS_COLORS = @('#2bb3c0', '#4fd0a7', '#3f8fd0')
    $PALETTE = @('#e0762b', '#57ab5a', '#986ee2', '#c69026', '#d94fd0', '#539bf5',
                 '#e5534b', '#5cc9a7', '#8250df', '#b55cd9', '#c0562b', '#7fa8d9')
    $FIXED = @{ base = '#8a8f98'; core = '#6a6f76' }
    $mods = [System.Collections.Generic.List[object]]::new()
    $pi = 0; $fi = 0
    foreach ($m in $ordered) {
        $color = if ($focusSet.Contains($m)) { $FOCUS_COLORS[$fi++ % $FOCUS_COLORS.Count] }
                 elseif ($FIXED[$m])         { $FIXED[$m] }
                 else                        { $PALETTE[$pi++ % $PALETTE.Count] }
        $label = if ($modTitles[$m]) { $modTitles[$m] } else { $m }
        $mods.Add([ordered]@{ name = $m; label = $label; color = $color })
    }

    # ------------------------------------------------------------------------- emit
    $dataset = [ordered]@{
        meta = [ordered]@{
            name = $OutName; generated = (Get-Date -Format 'yyyy-MM-dd HH:mm')
            factorio = $factorioVersion; modList = @($setMods); focusMods = @($FocusMod)
            focusLabels = @($FocusMod | ForEach-Object { if ($modTitles[$_]) { $modTitles[$_] } else { $_ } })
            techCount = $techs.Count
        }
        mods = @($mods); packs = @($packOrder); packLabels = $packLabels
        techs = @($techs); overlaps = @($overlaps)
    }

    $template = Get-Content "$PSScriptRoot/tree-viewer.template.html" -Raw
    if (-not $template.Contains('"__DATASET__"')) { throw 'placeholder "__DATASET__" not found in the template.' }
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    $outPath = Join-Path $outDir "$OutName.html"
    $template.Replace('"__DATASET__"', ($dataset | ConvertTo-Json -Depth 8 -Compress)) |
        Set-Content -Path $outPath -Encoding utf8

    # Surfaced, not silenced: the count is the mods own localisation failing, which is
    # none of this repo's business to fix but every bit of it worth reporting (#169).
    $failedLocale = @(@($recipeLocale.Values) + @($itemLocale.Values) + @($fluidLocale.Values) +
                      @($entityLocale.Values) + @($techLocale.Values) |
                      Where-Object { Get-LocaleFailure $_ }).Count
    $ticked = @($techs | Where-Object { $_.changedBy.Count -gt 0 }).Count
    $dead   = @($techs | Where-Object { -not $_.enabled -or $_.hidden }).Count
    Write-Host ''
    Write-Host ("reported: {0} techs ({1} changed by another mod, {2} unresearchable), {3} overlap candidates ({4} base-flagged), {5} mods named" -f
        $techs.Count, $ticked, $dead, $overlaps.Count, @($overlaps | Where-Object base).Count, $mods.Count)
    if ($failedLocale) {
        Write-Host ("          {0} prototypes have no usable localised name in this set -- an 'Unknown key' left in the text, or a placeholder the mod ships on purpose -- and every label naming one falls through to what the recipe produces, or last of all to the prototype name" -f
            $failedLocale)
    }
    Write-Host "viewer:   $outPath"
    Write-Host ''
    Write-Host 'OK - the tool ran and reported. It asserts nothing: the tree and its overlap'
    Write-Host '     candidates are measurements for a human to judge, not a verdict.'
}
finally {
    Remove-ModJunctions -ModDirectory $modDir
    if ($KeepTemp) { Write-Host "temp kept at: $temp" }
    else { Remove-TempDirectory -Path $temp -Label 'tree-viewer' }
}
exit 0

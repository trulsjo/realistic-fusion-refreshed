<#
.SYNOPSIS
    Fails if any prototype this repo defines would show a player something other than its name.

.DESCRIPTION
    scripts/load-check.ps1 deliberately does not do this: Factorio's data stage loads a prototype
    with no locale entry without complaint, and the omission surfaces only in front of a player as
    "Unknown key: item-name.rf-whatever". ADR 0010 singles that failure out, which is why it gets
    its own check rather than being left to someone's eyes.

    METHOD

    Two dumps, diffed.

    --dump-prototype-locale writes one JSON file per category listing every prototype whose name
    resolves -- "if they have a valid value", in the game's own words. A prototype with no locale
    entry is simply absent. So the dump is the *resolved* set and cannot, on its own, tell you what
    is missing.

    --dump-data supplies the other half: data.raw as JSON, which is the *expected* set. Everything
    named rf- in it has to turn up in the locale dump.

    Turning up is not enough, though, which is the second half of the check (#179). A dumped name
    is a resolved *value*, and the engine resolves a string containing something it cannot look up
    -- a rich-text reference to a renamed item, a control code that names nothing -- by writing
    "Unknown key" or "Unknown control sequence" into the text and carrying on. That value is
    present, so membership alone reports it clean, and the player reads the error on the tooltip.
    Get-LocaleFailure in factorio-lib.ps1 holds what those strings are, and its comment records
    what the engine does and does not do here. This check passes it -EngineOnly, so it fails on
    the engine's own errors and not on a placeholder another mod ships deliberately -- which no
    run of this check can see anyway, since it loads this repo's mods and Wube's bundled ones and
    nothing else. The viewer, whose question is whether a string makes a usable LABEL rather than
    whether it resolved, reads both lists.

    The two failures are reported apart, because the fixes are not the same: an absent name wants a
    locale entry written, and an unresolved one wants an entry that is already there corrected.

    Which categories need a name is not hardcoded, because a hardcoded list goes stale the moment a
    tier adds a prototype type nobody thought about. Instead it is derived from vanilla: for each
    type this repo defines something in, look at where the game's own prototypes of that type
    appear in the locale dump, and require ours in the same file. Types whose vanilla members
    appear nowhere -- recipe categories, fuel categories, anything with no player-visible name --
    are skipped on that evidence rather than by assumption.

    A type with no vanilla members at all is an error, not a skip. That is the case where this
    check would otherwise go quiet exactly when something new arrives.

    Descriptions are reported but not required, and since #179 actually are: the count of ours
    carrying one is printed, and any that fails to resolve fails the run. Factorio treats a
    description as optional, so an absent one is still not a finding -- but every parameterised
    localised string this repo writes lives in a description, and a parameter is the ordinary way
    to name something that has since been renamed. Not looking there left the likeliest failure
    unwatched.

    Expect the count to jump under -With space-age: 126 prototypes becomes 156, because the
    expansion generates a recycling recipe for every item and thirty of this repo's items qualify.
    Those are ours to get right too -- they inherit their names from the items -- so the higher
    number is the check doing more work, not counting differently. Measured 2026-08-30 on 2.0.77;
    it moves whenever a tier lands, and the shape of the claim is what matters, not the figures.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER With
    Bundled mods to enable, e.g. -With space-age. Locale can differ under an expansion, so this is
    worth running both ways before a release.

.PARAMETER SelfTest
    Verify the check can fail. Runs twice: once as normal, which must pass, and once with a mod
    carrying three planted prototypes -- one with no locale entry, one whose name resolves to an
    engine error, and one whose description does -- every one of which must be caught, and caught
    as the right kind. Both halves are required: a check that never fires proves nothing, and one
    that reported an unresolved name as a missing one would send the fix to the wrong place. Run
    this whenever the script changes.

.PARAMETER KeepTemp
    Keep the dumps for inspection. Junctions are always removed.

.EXAMPLE
    pwsh -File scripts/locale-check.ps1
    pwsh -File scripts/locale-check.ps1 -With space-age
    pwsh -File scripts/locale-check.ps1 -SelfTest
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string]   $FactorioExe,
    [string[]] $With = @(),
    [switch]   $SelfTest,
    [switch]   $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$PREFIX   = 'rf-'   # ADR 0009: everything this project defines carries it

# Prototype types with no player-visible name at all, where an absent locale entry is correct rather
# than a gap.
#
# This exists because the check below refuses to guess: it decides whether a type needs names by
# looking at how many of the GAME'S OWN prototypes of that type have them, and a type the game
# defines none of leaves it nothing to look at. Rather than let it assume either way, it throws and
# asks to be taught. This is where the teaching goes, and every line is a judgement someone made
# once, deliberately, in writing.
$NAMELESS_TYPES = @{
    'animation' = 'a named sprite sheet for rendering.draw_animation; nothing ever shows its name'
}

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe
try {
    $enabledBundled = Resolve-BundledSelection -Requested $With -Bundled $bundled
}
catch { throw "-With $($_.Exception.Message)" }

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-localecheck-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
New-Item -ItemType Directory -Path $modDir -Force | Out-Null

function Invoke-Dumps {
    <#  Run both dumps and return the parsed results.

        Each dump exits after writing, so they are two runs. They land in the isolated write-data
        directory factorio-lib gives every run, which is also why this works with the game open. #>
    param([string[]] $Mods, [string] $Tag)

    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabledBundled -Mods $Mods

    foreach ($dump in @('--dump-data', '--dump-prototype-locale')) {
        $result = Invoke-Factorio -FactorioExe $FactorioExe -ModDirectory $modDir `
            -Arguments @($dump) -OutputDirectory $temp -Tag "$Tag$dump"
        if ($result.Code -ne 0) {
            Write-FactorioTail $result
            throw "Factorio exited $($result.Code) on $dump."
        }
    }

    $scriptOutput = Join-Path $temp 'write-data/script-output'
    $rawPath = Join-Path $scriptOutput 'data-raw-dump.json'
    if (-not (Test-Path $rawPath)) { throw "no data-raw-dump.json in $scriptOutput." }

    $raw = Get-Content -LiteralPath $rawPath -Raw | ConvertFrom-Json

    # The value is kept, not only the key: membership answers "is there a name", the value answers
    # "is it one". Ordinal, because these are compared against a dump the engine wrote and
    # PowerShell's own hashtables are case-insensitive -- the fault factorio-lib's header describes.
    function ConvertTo-LocaleMap($Section) {
        $map = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
        if ($Section) {
            foreach ($entry in $Section.PSObject.Properties) { $map[$entry.Name] = [string] $entry.Value }
        }
        return , $map   # comma, or PowerShell unrolls the dictionary into its pairs on the way out
    }

    $locale = [ordered]@{}
    foreach ($file in Get-ChildItem -Path $scriptOutput -Filter '*-locale.json') {
        $parsed = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        $locale[$file.Name] = @{
            Names        = ConvertTo-LocaleMap $parsed.names
            Descriptions = ConvertTo-LocaleMap $parsed.descriptions
        }
    }
    if ($locale.Count -eq 0) { throw "no *-locale.json in $scriptOutput; did --dump-prototype-locale run?" }

    # Dumps are overwritten rather than appended, but a stale file from a previous invocation would
    # be read as current. Clearing between runs keeps -SelfTest's two halves independent.
    Remove-Item -Path $scriptOutput -Recurse -Force

    return @{ Raw = $raw; Locale = $locale }
}

function Test-Locale {
    <#  Compare the expected set against the resolved set. Returns findings; empty means clean.  #>
    param([Parameter(Mandatory)] [hashtable] $Dumps)

    $missing    = @()
    $unresolved = @()
    $skipped    = @()
    $mapping    = @()
    $checked    = 0
    $described  = 0

    foreach ($type in $Dumps.Raw.PSObject.Properties) {
        $names   = @($type.Value.PSObject.Properties.Name)
        $ours    = @($names | Where-Object { $_.StartsWith($PREFIX, [StringComparison]::Ordinal) })
        if ($ours.Count -eq 0) { continue }

        if ($NAMELESS_TYPES.ContainsKey($type.Name)) {
            $skipped += "{0} ({1}, declared nameless: {2})" -f $type.Name, $ours.Count, $NAMELESS_TYPES[$type.Name]
            continue
        }

        $vanilla = @($names | Where-Object { -not $_.StartsWith($PREFIX, [StringComparison]::Ordinal) })
        if ($vanilla.Count -eq 0) {
            # Parenthesised as one string before -f, which binds tighter than +: without them the
            # format applies to the second half only and the message prints its own placeholders.
            throw (("prototype type '{0}' has {1} of ours and none of the game's, so there is no way to tell " +
                    "whether it needs a locale entry. Add it to `$NAMELESS_TYPES at the top of this script if " +
                    "it has no visible name, rather than letting the check guess.") -f $type.Name, $ours.Count)
        }

        # Where do the game's own prototypes of this type get their names from? Judged by the share
        # of them a file accounts for, not by the raw count: prototype names are only unique within
        # a type, so a handful of coincidental collisions across types is normal. "oil-processing"
        # is both a recipe category and a technology, and matching on count alone was enough for
        # that one collision to declare every recipe category a technology and demand names for
        # things that have never had one.
        $source = $null; $bestShare = 0.0
        foreach ($entry in $Dumps.Locale.GetEnumerator()) {
            $share = @($vanilla | Where-Object { $entry.Value.Names.ContainsKey($_) }).Count / $vanilla.Count
            if ($share -gt $bestShare) { $bestShare = $share; $source = $entry }
        }

        # Half is a wide margin either way: a type that is named runs near 1.0, and a type that is
        # not runs near 0 with only collisions to its name.
        if ($bestShare -lt 0.5) {
            $skipped += "{0} ({1}, best match {2:P0})" -f $type.Name, $ours.Count, $bestShare
            $source = $null
            continue
        }
        $mapping += "{0} -> {1} ({2:P0} of the game's own)" -f $type.Name, $source.Key, $bestShare

        foreach ($name in $ours) {
            $checked++
            if (-not $source.Value.Names.ContainsKey($name)) {
                $missing += [pscustomobject]@{ Type = $type.Name; Name = $name; Expected = $source.Key }
                continue
            }

            # A description stays optional -- an absent one is not a finding -- but a present one is
            # held to the same standard as a name.
            $fields = [ordered]@{ name = $source.Value.Names[$name] }
            if ($source.Value.Descriptions.ContainsKey($name)) {
                $described++
                $fields['description'] = $source.Value.Descriptions[$name]
            }

            foreach ($field in $fields.Keys) {
                $marker = Get-LocaleFailure $fields[$field] -EngineOnly
                if ($marker) {
                    $unresolved += [pscustomobject]@{
                        Type = $type.Name; Name = $name; Field = $field; Value = $fields[$field]
                    }
                }
            }
        }
    }

    return @{
        Missing = @($missing); Unresolved = @($unresolved); Skipped = $skipped
        Mapping = $mapping; Checked = $checked; Described = $described
    }
}

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods

    $bundledOn = if ($enabledBundled) { $enabledBundled -join ', ' } else { 'none (base 2.0 only)' }
    Write-Host "locale-check: $($ourMods -join ', ')  |  bundled enabled: $bundledOn"

    $report = Test-Locale -Dumps (Invoke-Dumps -Mods $ourMods -Tag 'run')

    if ($SelfTest) {
        if ($report.Missing.Count -gt 0 -or $report.Unresolved.Count -gt 0) {
            Write-Host ''
            Write-Host 'FAILED - self-test: the repo as it stands already has a locale finding, so the'
            Write-Host '         canary result would prove nothing. Fix the repo first.'
            exit 1
        }
        Write-Host "self-test 1/2: the repo as it stands resolves ($($report.Checked) prototypes)."

        # Three planted prototypes, one per failure this check claims to see. They live in the temp
        # directory, never the repo.
        #
        # The two unresolved ones lean on __ITEM__...__ naming an item that does not exist, because
        # that is the shape the engine answers with text rather than by refusing: a localised string
        # that is structurally wrong -- too deep, too many parameters -- stops the data stage and
        # never reaches a dump, and a localised_name pointing straight at a missing key is dropped
        # from the dump entirely, which is the FIRST canary's case, not this one. Measured on 2.0.77.
        $canary = Join-Path $modDir 'rf-localecheck-canary'
        New-Item -ItemType Directory -Path (Join-Path $canary 'locale/en') -Force | Out-Null
        @{
            name = 'rf-localecheck-canary'; version = '0.0.1'; title = 'Locale-check canary'
            author = 'locale-check.ps1'; factorio_version = '2.0'; dependencies = @('base >= 2.0.77')
        } | ConvertTo-Json | Set-Content -Path (Join-Path $canary 'info.json') -Encoding utf8

        @'
[item-name]
rf-localecheck-canary-unresolved-name=Canary __ITEM__rf-localecheck-canary-no-such-item__
rf-localecheck-canary-unresolved-desc=Canary
[item-description]
rf-localecheck-canary-unresolved-desc=Canary __ITEM__rf-localecheck-canary-no-such-item__
'@ | Set-Content -Path (Join-Path $canary 'locale/en/canary.cfg') -Encoding utf8

        @'
local function canary(name)
  return { type = "item", name = name, stack_size = 1,
           icon = "__base__/graphics/icons/pipe.png", icon_size = 64 }
end
data:extend({
  canary("rf-localecheck-canary-item"),
  canary("rf-localecheck-canary-unresolved-name"),
  canary("rf-localecheck-canary-unresolved-desc"),
})
'@ | Set-Content -Path (Join-Path $canary 'data.lua') -Encoding utf8

        $canaryReport = Test-Locale -Dumps (Invoke-Dumps -Mods ($ourMods + 'rf-localecheck-canary') -Tag 'canary')

        # Caught is not enough: caught as the right kind. A run that reported the unresolved pair as
        # missing would send someone to write a locale entry that is already there.
        $wanted = @(
            @{ Name = 'rf-localecheck-canary-item';             In = 'Missing';    Field = $null
               What = 'a prototype with no locale entry' }
            @{ Name = 'rf-localecheck-canary-unresolved-name';  In = 'Unresolved'; Field = 'name'
               What = 'a name that does not resolve' }
            @{ Name = 'rf-localecheck-canary-unresolved-desc';  In = 'Unresolved'; Field = 'description'
               What = 'a description that does not resolve' }
        )
        $failed = $false
        foreach ($w in $wanted) {
            $caught = @($canaryReport[$w.In] | Where-Object {
                $_.Name -eq $w.Name -and (-not $w.Field -or $_.Field -eq $w.Field) })
            if ($caught.Count -eq 0) {
                Write-Host ''
                Write-Host ("FAILED - self-test: {0} was NOT caught as {1}." -f $w.What, $w.In.ToLower())
                $failed = $true
            }
        }
        if ($failed) {
            Write-Host '         This check is not proving anything; fix it before trusting a pass.'
            exit 1
        }

        Write-Host 'self-test 2/2: all three planted prototypes were caught, each as its own kind.'
        Write-Host ''
        Write-Host 'OK - self-test passed.'
        exit 0
    }

    foreach ($m in $report.Mapping) { Write-Host "  $m" }
    if ($report.Skipped) {
        Write-Host "  no visible name, so not checked: $($report.Skipped -join ', ')"
    }

    # Against the named count, not the checked one: a prototype with no name at all was never
    # looked at for a description, so counting it in the denominator would read as descriptions
    # going missing when it is nothing of the kind.
    Write-Host "  $($report.Described) of $($report.Checked - $report.Missing.Count) named prototypes also carry a description"

    if ($report.Missing.Count -gt 0) {
        Write-Host ''
        Write-Host "FAILED - $($report.Missing.Count) prototype(s) have no locale entry and would show as 'Unknown key' in game:"
        foreach ($m in $report.Missing | Sort-Object Type, Name) {
            Write-Host ("    {0,-22} {1}   (expected a name in {2})" -f $m.Type, $m.Name, $m.Expected)
        }
    }

    if ($report.Unresolved.Count -gt 0) {
        Write-Host ''
        Write-Host "FAILED - $($report.Unresolved.Count) locale entry(s) exist but do not resolve; the player reads this text:"
        foreach ($u in $report.Unresolved | Sort-Object Type, Name, Field) {
            Write-Host ("    {0,-22} {1} ({2})" -f $u.Type, $u.Name, $u.Field)
            Write-Host ("        {0}" -f $u.Value)
        }
    }

    if ($report.Missing.Count -gt 0 -or $report.Unresolved.Count -gt 0) { exit 1 }

    Write-Host "OK - all $($report.Checked) prototypes resolve to a name."
    exit 0
}
finally {
    # Junctions always go, even with -KeepTemp: leaving links to the repo in %TEMP% hands a
    # delete-through-the-link hazard to whatever cleans it up later.
    Remove-ModJunctions -ModDirectory $modDir

    if ($KeepTemp) { Write-Host "temp kept at: $temp" }
    else { Remove-TempDirectory -Path $temp -Label 'locale-check' }
}

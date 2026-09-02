<#
.SYNOPSIS
    Probes whether a `__mod__/...` asset path a loaded mod names actually reaches --dump-data, and
    which prototypes carry the field it was written into. The rig behind
    docs/research/dumped-reference-survival.md.

.DESCRIPTION
    A PROBE, NOT A CHECK. Every line it prints is a measurement, and a negative answer is as much of
    a result as a positive one -- exit 0 means the probe ran and reported, never that the answer was
    the one anybody hoped for. It must not be added to a check sweep or to load-check.ps1.

    WHY THE QUESTION EXISTS

    load-check.ps1's asset half reports every `__base__/...` path the DUMPED prototypes name that is
    not on disk, whoever names it -- so a lane loading a third-party mod that references a file 2.0
    removed goes red. What it cannot report is a reference the engine discarded before writing the
    dump, and the two are indistinguishable from the outside: both look like silence.

    That is not hypothetical. At Factorio 2.0.77, RITEG 1.3.11 and underground-pipe-pack 2.0.6 write
    the identical line --

        vehicle_impact_sound = { filename = '__base__/sound/car-metal-impact.ogg', volume = 0.65 }

    -- against a file 2.0 does not ship. The `riteg` lane fails on it and the `fluid` lane is silent,
    because 2.0 migrated `vehicle_impact_sound` to `impact_category` for the `pump` prototype type
    and not for `electric-energy-interface`. One reference is dropped at load; the other survives
    into the dump. `Find-MissingAssets` has no defect in either lane (#196, #197).

    THE ANSWER IS ABOUT ONE ENGINE VERSION, WHICH IS WHY THE INSTRUMENT IS COMMITTED. A later
    Factorio migrating `electric-energy-interface` too would turn the `riteg` lane green and make
    ADR 0007, ADR 0026 and the note above wrong again, silently and for the same reason. Re-run this
    rather than reconstructing the archaeology.

    WHAT IT REPORTS

      - the mods loaded, and the size of the dump in characters
      - how many times $Path occurs in the raw dump text, and -- walked as an object graph -- which
        prototype each occurrence sits in and under which property
      - how many prototypes declare $Field, and how many declare $ReplacedBy, with the names when
        the list is short enough to print
      - for each -Prototype given as `type/name`: whether it is in the dump at all, and what it
        holds for each of the two fields

    The field census looks at each prototype's OWN top-level properties, which is where both fields
    in the recorded case sit. A field nested inside a sub-table is not counted; the occurrence walk
    below it is what covers nesting.

    THE DEFAULTS ARE THE RECORDED QUESTION, not a general one. $Path, $Field and $ReplacedBy default
    to the 2.0.77 case above so that asking it again is one command. Give a $Path of your own and
    the two field names stop being related to it -- the probe will still print the census, and it
    will be about whatever you named. It asserts nothing either way.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER AlsoModDirectory
    A directory of mod directories to load beside this repo's three, the same way load-check.ps1
    takes one. scripts/fetch-mods.ps1 fills one per lane at the ADR 0026 pins:

        pwsh -File scripts/fetch-mods.ps1 -Set riteg
        pwsh -File scripts/probe-dumped-reference.ps1 -AlsoModDirectory .mod-cache/riteg

    Omit it and the probe loads this repo's mods alone, which answers the same question about our
    own paths and nobody else's.

.PARAMETER Path
    The `__mod__/relative/file.ext` reference to look for, exactly as a prototype would name it.

.PARAMETER Field
    The prototype property the reference was written into -- the one a migration may have taken
    away. Reported as a census over the whole dump, because "no prototype declares it" is the
    finding that explains a silent lane.

.PARAMETER ReplacedBy
    The property the engine migrated $Field to. Its census is the other half of the explanation:
    a type that carries this and not $Field was migrated, and its author's line was discarded.

.PARAMETER Prototype
    Zero or more `type/name` prototypes to report on individually -- the mod's own entity, when you
    know which one names the path. This is what turns the census into a row you can quote: the
    prototype either holds the reference or holds the field that replaced it.

.PARAMETER With
    Bundled mods to enable (space-age, quality, elevated-rails), with hard dependencies followed.
    The `seablock` lane needs `-With quality`; the two lanes this was written for need nothing.

.PARAMETER SelfTest
    Verify the object-graph walk can find anything, over a hand-built dump. Starts no game.

    A probe does not usually need one. This one does, because its headline finding is a ZERO --
    "the reference is not in the dump" -- and a walk that silently visits nothing reports the same
    zero. That is not hypothetical: the first version of this used [Tuple]::Create, which converts a
    homogeneous Object[] to a typed array on the way in, so every `layers`, `icons` and `filenames`
    array was dropped without an error.

.PARAMETER KeepTemp
    Keep the dump and the captured output. The dump is ~15 MB of JSON and is worth keeping when a
    reported count needs looking at by hand.

.EXAMPLE
    pwsh -File scripts/probe-dumped-reference.ps1 -AlsoModDirectory .mod-cache/riteg -Prototype electric-energy-interface/RITEG-1

.EXAMPLE
    pwsh -File scripts/probe-dumped-reference.ps1 -AlsoModDirectory .mod-cache/fluid -Prototype pump/underground-mini-pump

.EXAMPLE
    pwsh -File scripts/probe-dumped-reference.ps1 -SelfTest
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string]   $FactorioExe,
    [string]   $AlsoModDirectory,
    [string]   $Path = '__base__/sound/car-metal-impact.ogg',
    [string]   $Field = 'vehicle_impact_sound',
    [string]   $ReplacedBy = 'impact_category',
    [string[]] $Prototype = @(),
    [string[]] $With = @(),
    [switch]   $SelfTest,
    [switch]   $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods

$alsoMods = @()
if ($AlsoModDirectory) {
    if (-not (Test-Path $AlsoModDirectory)) { throw "-AlsoModDirectory not found: $AlsoModDirectory" }
    # Absolute, because a junction target must be -- the same trap load-check.ps1 records: the
    # obvious thing to type after fetch-mods.ps1 is a relative path, and New-Item refuses one.
    $AlsoModDirectory = (Resolve-Path -LiteralPath $AlsoModDirectory).Path
    $alsoMods = @(Get-ChildItem -Path $AlsoModDirectory -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName 'info.json') } |
        ForEach-Object { $_.Name } | Sort-Object)
    if (-not $alsoMods) {
        throw "-AlsoModDirectory holds no mod directories (a directory with an info.json in it): $AlsoModDirectory"
    }
}

foreach ($p in $Prototype) {
    if ($p -notmatch '^[^/]+/.+$') { throw "-Prototype takes `type/name`, not '$p'." }
}

if (-not $SelfTest) {
    $FactorioExe = Resolve-FactorioExe -Path $FactorioExe
    $bundled     = Get-BundledMods -FactorioExe $FactorioExe
    try { $enabledBundled = Resolve-BundledSelection -Requested $With -Bundled $bundled }
    catch { throw "-With $($_.Exception.Message)" }
}

function Measure-TextOccurrence {
    <#  How many times $Needle appears in $Text, ordinal and overlapping-free.

        Ordinal on purpose: PowerShell's own string operators are case-insensitive, and an asset
        path is not. This is the number that makes the graph walk below falsifiable -- the two are
        arrived at differently, so a disagreement is itself a finding.  #>
    param([Parameter(Mandatory)] [string] $Text, [Parameter(Mandatory)] [string] $Needle)

    $count = 0
    $at = $Text.IndexOf($Needle, [StringComparison]::Ordinal)
    while ($at -ge 0) {
        $count++
        $at = $Text.IndexOf($Needle, $at + $Needle.Length, [StringComparison]::Ordinal)
    }
    return $count
}

function Find-ReferenceSite {
    <#  Every prototype holding $Needle as a string value, and the property path it sits under.

        Walked as an object graph rather than scanned as text, for the reason the report needs: the
        text count says how many times the string is in the file and nothing about whose prototype
        it is. Iterative, because the dump nests deeply enough to be worth not recursing through.  #>
    # IDictionary rather than [hashtable]: ConvertFrom-Json -AsHashtable returns an ordered
    # dictionary, and the narrower type would silently copy the top level to convert it.
    param(
        [Parameter(Mandatory)] [System.Collections.IDictionary] $Dump,
        [Parameter(Mandatory)] [string] $Needle
    )

    $sites = [System.Collections.Generic.List[object]]::new()
    foreach ($type in $Dump.Keys) {
        $byName = $Dump[$type]
        if ($byName -isnot [System.Collections.IDictionary]) { continue }

        foreach ($name in $byName.Keys) {
            $stack = [System.Collections.Generic.Stack[object]]::new()
            # Tuples rather than an array pair: @($node, $at) flattens when $node is itself an
            # array, which is most of a prototype.
            #
            # [Tuple[object,string]]::new AND NOT [Tuple]::Create, which is where the first version
            # of this walked past most of the dump in silence. Create infers its type arguments from
            # the runtime value, and PowerShell converts a homogeneous Object[] on the way in: an
            # array of sub-tables arrives back as OrderedHashtable[], an array of strings as
            # String[]. Neither is [Object[]], so the array test below was false and every `layers`,
            # `icons` and `filenames` in the dump was dropped without an error -- reported as "not
            # in the dump", which is the one answer this probe exists to be trusted on. Create also
            # throws outright on a $null, which a dump does contain. -SelfTest holds both down.
            $stack.Push([Tuple[object, string]]::new($byName[$name], ''))

            while ($stack.Count -gt 0) {
                $frame = $stack.Pop()
                $node  = $frame.Item1
                $at    = $frame.Item2

                if ($node -is [System.Collections.IDictionary]) {
                    foreach ($key in $node.Keys) {
                        $under = if ($at) { "$at.$key" } else { [string] $key }
                        $stack.Push([Tuple[object, string]]::new($node[$key], $under))
                    }
                }
                # IList rather than Object[], for the same reason: it holds however the array
                # arrives, so this cannot go quiet again if the JSON reader changes its mind.
                elseif ($node -is [System.Collections.IList]) {
                    for ($i = 0; $i -lt $node.Count; $i++) {
                        $stack.Push([Tuple[object, string]]::new($node[$i], "$at[$i]"))
                    }
                }
                elseif ($node -is [string] -and [string]::Equals($node, $Needle, [StringComparison]::Ordinal)) {
                    $sites.Add([pscustomobject]@{ Prototype = "$type/$name"; At = $at })
                }
            }
        }
    }
    return @($sites | Sort-Object Prototype, At)
}

function Format-FieldValue {
    <#  One prototype field rendered for the report: scalars verbatim, tables as compact JSON.

        A table is what makes "present, verbatim" quotable -- the whole point of the recorded case
        is that the discarded and the surviving reference are the same literal.  #>
    param($Value)

    if ($null -eq $Value) { return 'absent' }
    if ($Value -is [System.Collections.IDictionary] -or $Value -is [System.Object[]]) {
        $json = $Value | ConvertTo-Json -Depth 6 -Compress
        if ($json.Length -gt 300) { $json = $json.Substring(0, 297) + '...' }
        return $json
    }
    return [string] $Value
}

function Write-Census {
    <#  One field's census line, with the names when there are few enough to be worth reading.  #>
    param([string] $Name, [string[]] $Carriers)

    Write-Host "  prototypes declaring $Name`: $($Carriers.Count)"
    if ($Carriers.Count -eq 0) { return }
    $shown = @($Carriers | Select-Object -First 25)
    foreach ($c in $shown) { Write-Host "      $c" }
    if ($Carriers.Count -gt $shown.Count) {
        Write-Host "      (+$($Carriers.Count - $shown.Count) more; -KeepTemp and read the dump for the rest)"
    }
}

if ($SelfTest) {
    # WHY A PROBE HAS ONE AT ALL, when none of its neighbours does. Every other probe here reports
    # what it found; this one's headline finding is a ZERO -- "the reference is not in the dump" --
    # and a walker that silently visits nothing produces exactly that zero. It is the same shape as
    # load-check.ps1's asset self-test, and the fault it exists for was real: see the comment in
    # Find-ReferenceSite. Needs no Factorio; the dump shapes below are hand-built.
    $fixture = @'
{
  "pump": {
    "p1": {
      "top": "WANTED",
      "nested": { "filename": "WANTED" },
      "layers": [ { "filename": "WANTED" }, { "filename": "other" } ],
      "names": [ "WANTED" ],
      "nothing": null,
      "numbers": [ 1, 2 ]
    }
  }
}
'@ | ConvertFrom-Json -AsHashtable

    $expected = @('layers[0].filename', 'names[0]', 'nested.filename', 'top')
    $found    = @((Find-ReferenceSite -Dump $fixture -Needle 'WANTED').At | Sort-Object)

    Write-Host 'self-test: the walk must reach a value at the top level, inside a sub-table, inside'
    Write-Host '           an array of sub-tables and inside an array of strings, and must survive a'
    Write-Host '           null and an array of numbers.'
    Write-Host "  expected: $($expected -join ', ')"
    Write-Host "  found:    $(if ($found) { $found -join ', ' } else { '(nothing)' })"

    if (Compare-Object -ReferenceObject $expected -DifferenceObject $found) {
        Write-Host ''
        Write-Host 'FAILED - the walk does not reach every shape a prototype is made of, so a report of'
        Write-Host '         "not in the dump" from this probe would not be trustworthy.'
        exit 1
    }
    Write-Host ''
    Write-Host 'OK - the walk reaches every shape. This says nothing about any lane; run the probe.'
    exit 0
}

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-dumpref-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
New-Item -ItemType Directory -Path $modDir -Force | Out-Null

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    if ($alsoMods) { New-ModJunctions -ModDirectory $modDir -RepoRoot $AlsoModDirectory -Mods $alsoMods }
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabledBundled `
        -Mods ($ourMods + $alsoMods)

    $bundledOn = if ($enabledBundled) { $enabledBundled -join ', ' } else { 'none (base 2.0 only)' }
    Write-Host "mods: $((@($ourMods) + $alsoMods) -join ', ')"
    Write-Host "bundled enabled: $bundledOn"

    $result = Invoke-Factorio -FactorioExe $FactorioExe -ModDirectory $modDir `
        -Arguments @('--dump-data') -OutputDirectory $temp -Tag 'dump'
    if ($result.Code -ne 0) {
        # Not a finding. The probe did not run, so it has nothing to report either way.
        Write-FactorioTail $result
        throw "Factorio exited $($result.Code) on --dump-data; there is no dump to read."
    }

    $dumpPath = Join-Path $temp 'write-data/script-output/data-raw-dump.json'
    if (-not (Test-Path -LiteralPath $dumpPath)) { throw "no data-raw-dump.json in script-output at '$dumpPath'." }

    $text = Get-Content -LiteralPath $dumpPath -Raw
    $dump = $text | ConvertFrom-Json -AsHashtable

    $textCount = Measure-TextOccurrence -Text $text -Needle $Path
    $sites     = Find-ReferenceSite -Dump $dump -Needle $Path

    $withField      = [System.Collections.Generic.List[string]]::new()
    $withReplaced   = [System.Collections.Generic.List[string]]::new()
    foreach ($type in $dump.Keys) {
        $byName = $dump[$type]
        if ($byName -isnot [System.Collections.IDictionary]) { continue }
        foreach ($name in $byName.Keys) {
            $proto = $byName[$name]
            if ($proto -isnot [System.Collections.IDictionary]) { continue }
            if ($proto.Contains($Field))      { $withField.Add("$type/$name") }
            if ($proto.Contains($ReplacedBy)) { $withReplaced.Add("$type/$name") }
        }
    }

    Write-Host ''
    Write-Host "dump: $($text.Length) chars"
    Write-Host "reference: $Path"
    Write-Host "  occurrences in the raw JSON: $textCount"
    Write-Host "  prototypes holding it as a value: $($sites.Count)"
    foreach ($site in $sites) { Write-Host "      $($site.Prototype)  at  $($site.At)" }
    if ($textCount -ne $sites.Count) {
        Write-Host "  NOTE - the two counts differ. A text occurrence with no site is the string"
        Write-Host "         inside a longer value, or under a key rather than a value."
    }

    Write-Host ''
    Write-Host 'field census (each prototype''s own top-level properties):'
    Write-Census -Name $Field -Carriers @($withField | Sort-Object)
    Write-Census -Name $ReplacedBy -Carriers @($withReplaced | Sort-Object)

    if ($Prototype) {
        Write-Host ''
        Write-Host 'named prototypes:'
        foreach ($p in $Prototype) {
            $type, $name = $p -split '/', 2
            $proto = if ($dump.Contains($type) -and $dump[$type].Contains($name)) { $dump[$type][$name] } else { $null }
            if ($null -eq $proto) {
                Write-Host "  $p`: NOT IN THE DUMP (no such type, or no such name under it)"
                continue
            }
            Write-Host "  $p"
            Write-Host "      $Field = $(Format-FieldValue $proto[$Field])"
            Write-Host "      $ReplacedBy = $(Format-FieldValue $proto[$ReplacedBy])"
        }
    }

    Write-Host ''
    Write-Host 'OK - the probe ran and reported. Every line above is a measurement about this engine'
    Write-Host '     version and this mod set; docs/research/dumped-reference-survival.md is what they'
    Write-Host '     are read into.'
}
finally {
    Remove-ModJunctions -ModDirectory $modDir
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    else { Remove-TempDirectory -Path $temp -Label 'probe-dumped-reference' }
}
exit 0

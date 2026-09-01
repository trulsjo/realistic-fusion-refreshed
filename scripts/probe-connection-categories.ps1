<#
.SYNOPSIS
    Probe: does a mod set reassign a pipe connection category on a prototype of OURS?

.DESCRIPTION
    A PROBE, NOT A GATE. It asserts nothing about what it finds and exits 0 whatever it reports, so a
    row saying containment was overwritten is a measurement and not a failure. #209 is the gate; this
    is the instrument that tells whoever writes it what there is to catch. Nothing here decides
    anything and nothing here ships.

    WHY THIS EXISTS

    Plasma containment is enforced in the data stage and nowhere else: contain() in
    realistic-fusion-refreshed/prototypes/entities.lua gives every plasma-carrying pipe connection
    the category `rf-plasma`, and 2.0 joins two connections only when their categories match. A
    vanilla pipe beside a plasma line therefore does not connect -- the plasma never enters, which is
    a stronger statement than noticing that it did (ADR 0011, #26).

    That guarantee lasts exactly as long as nobody rewrites the field. `no-pipe-touching` 1.1.28, in
    the `seablock` set, has a final `data-final-fixes` pass over `data.raw["pipe-to-ground"]` whose
    guard fires for a prototype that is not `solved_by_npt`, carries no `npt_compat`, and holds no
    default category on any connection. That is the shape containment itself gives
    `rf-pipe-to-ground` -- it qualifies BECAUSE it is contained -- and the body then writes the
    literal "pipe-to-ground" over every underground connection and appends every pipe name it
    collected to the surface ones.

    All of that is READ FROM SOURCE. Verification in this repository is by running the game, and the
    two checks that load a set are both blind here: `load-check` asks whether the game starts and
    `name-check` asks what we do to THEIR prototypes, not what they do to ours (ADR 0007, finding 4).
    A dump-and-diff of this shape has been done by hand before -- #131 and #132 measured Angel's
    editing 41 of our 145 prototype objects that way, and #153 records it -- but nothing committed
    did it, so the containment guarantee had no repeatable instrument until this one.

    HOW IT MEASURES

    Two --dump-data runs and a difference between them:

      declared   Our three mods and nothing else. This is what our data stage sets, taken from the
                 game rather than from the Lua, so a category assembled by a helper or a loop is
                 read the same as a literal.

      loaded     The same mods with the set junctioned in beside them. Load order is the game's, and
                 a set's data-final-fixes runs after everything ours does.

    A category present in `declared` and different in `loaded` is the finding. Both values are
    printed per connection, so a row explains itself instead of being a bare yes or no -- which
    matters more here than usual, because "pipe-to-ground" and {"rf-plasma", "pipe", ...} are
    different accidents with different fixes, and one of them is not obviously an accident at all.

    COMPARED AS CATEGORY SETS, NOT AS PRINTED TEXT, and that is load-bearing rather than tidy.
    `contain()` writes the BARE STRING "rf-plasma"; `no-pipe-touching` assigns `unify(...)` back to
    the field on every connection it merely INSPECTS (has_default_category, data-final-fixes.lua:14),
    so twelve contained connections of ours come back as the one-element list ["rf-plasma"]. That is
    the same category to the engine and changes nothing about what connects. Compared as text it
    would be twelve rows filed under WIDENED -- a box reported as opened with nothing added to it.
    Measured on the seablock lane, not assumed: all twelve are rewritten and all twelve are
    set-identical.

    EVERY REAL DIFFERENCE IS REPORTED AND THEY ARE NOT ONE FINDING, so each row carries a verdict and
    the verdicts sort before the rows. A category WE WROTE that is gone is containment removed. One
    that survives beside additions is containment WIDENED, which is a breach as well -- a connection
    category is a whitelist, and adding to one we wrote opens the box to whatever was added.
    Additions to a connection we left `default` are neither: that is an ordinary box of ours being
    treated like every other ordinary box in the game, and against `seablock` it is 44 of the 46
    rows. Sorting them last is what makes the other two readable. A `default` that is REPLACED rather
    than added to gets its own verdict, because it is not a containment finding and must not claim to
    be one -- Expand-Category synthesises `default` for an absent field, and a synthesised value is
    not a declaration of ours.

    WALKED AS AN OBJECT GRAPH, NOT BY KNOWN FIELD NAME. A pipe connection is not only at
    `fluid_box.pipe_connections`: the heat exchanger's is nested inside its energy source
    (`energy_source.fluid_box`), a position whose handling by the engine was worth a probe of its own
    (#82), and a crafting machine's are in a `fluid_boxes` list. Anything that walked a list of field
    names would silently not look at the boxes most likely to be missed. Every object holding a
    `pipe_connections` array is read wherever it sits, and the path it sits at is the connection's
    identity in the report.

    OURS BY PREFIX, WHICH IS EXACT HERE BECAUSE ANOTHER CHECK MAKES IT SO. `scripts/name-check.ps1`
    derives this repository's prototypes by difference between two dumps and then asserts that every
    one of them carries `rf-`, with a single declared exception -- base Factorio's generated
    `empty-rf-<fluid>-barrel` recipes, which have no fluid box and so cannot appear here. Leaning on
    that gate costs a third dump less than re-deriving it, and if the gate ever stops holding, the
    probe is the wrong place to find out.

    ITS OWN FLOOR, BECAUSE EVERYTHING BELOW PASSES BY FINDING NOTHING. A walk that stopped matching,
    a prefix that changed, a dump written somewhere else: each of those reports zero differences,
    which reads exactly like containment surviving. So the `declared` side must hold at least one
    connection carrying `rf-plasma` or the run throws. That is an instrument fault rather than a
    finding, and it is the only non-zero exit that comes from anything this probe MEASURED. The
    others are the run refusing to happen at all rather than reporting on it: a missing or empty
    -AlsoModDirectory, an unknown -With name, a Factorio run that exits non-zero (Invoke-FactorioStep
    throws), or a dump that is not where it should be (Get-OurConnections throws, on either run).
    None of those is a finding either, and none of them can be mistaken for one -- which is the
    property that matters, and is a narrower claim than this paragraph used to make.

    A PROTOTYPE OF OURS THAT IS GONE from the loaded side is reported as a row rather than skipped.
    It is not a category change and the probe does not pretend it is one, but a set that removes or
    renames the prototype out from under containment is the same class of accident, and silently
    comparing nothing is how an instrument lies. It is kept DISTINCT from a prototype that survives
    with its fluid box emptied, which reports a row per lost connection instead: the two are
    different accidents and a reader chasing the wrong one would be looking in the wrong place.

    Findings are written up in docs/research/connection-category-reassignment.md.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER AlsoModDirectory
    A directory of unpacked mods to load beside ours -- a lane's cache from `scripts/fetch-mods.ps1`,
    read the same way `load-check.ps1` and `name-check.ps1` read it. Mandatory: with no set loaded
    the two dumps are the same dump, and there is no question to answer.

.PARAMETER With
    Bundled mods to enable, closed over their hard dependencies. The `seablock` lane runs
    `-With quality` in ADR 0007.

.PARAMETER KeepTemp
    Keep the temp directory, which holds both dumps under their tags.

.EXAMPLE
    pwsh -File scripts/fetch-mods.ps1 -Set seablock
    pwsh -File scripts/probe-connection-categories.ps1 -AlsoModDirectory .mod-cache/seablock -With quality
#>

#Requires -Version 7

[CmdletBinding()]
param(
    [string]   $FactorioExe,
    [Parameter(Mandatory)] [string] $AlsoModDirectory,
    [string[]] $With = @(),
    [switch]   $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$PREFIX   = 'rf-'          # ADR 0009, gated by scripts/name-check.ps1

# The category contain() writes, which the floor below looks for.
#
# Named PLASMA_CATEGORY and not CONTAINED, because PowerShell variable names are case-INSENSITIVE:
# `$contained` for the connections holding it is the SAME VARIABLE, so the constant was gone by the
# time the throw message quoted it and the message named no category at all. name-check.ps1's
# $REFERENCE_MODS carries the same warning for the same reason; this is the second time.
$PLASMA_CATEGORY = 'rf-plasma'

if (-not (Test-Path $AlsoModDirectory)) { throw "-AlsoModDirectory not found: $AlsoModDirectory" }
# ABSOLUTE, BECAUSE A JUNCTION TARGET MUST BE -- the trap #60 hit in load-check.ps1.
$AlsoModDirectory = (Resolve-Path -LiteralPath $AlsoModDirectory).Path
$alsoMods = @(Get-ChildItem -Path $AlsoModDirectory -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName 'info.json') } |
    ForEach-Object { $_.Name } | Sort-Object)
if (-not $alsoMods) {
    throw "-AlsoModDirectory holds no mod directories (a directory with an info.json in it): $AlsoModDirectory"
}

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe
try   { $enabledBundled = Resolve-BundledSelection -Requested $With -Bundled $bundled }
catch { throw "-With $($_.Exception.Message)" }

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-category-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
New-Item -ItemType Directory -Path $modDir -Force | Out-Null

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

function Get-OurConnections {
    <#  Dump the game as currently junctioned, and return our prototypes' pipe connections as
        "type/name" -> (path -> connection). Prototypes with no pipe connection are left out.  #>
    param([Parameter(Mandatory)] [string[]] $Mods, [Parameter(Mandatory)] [string] $Tag)

    $rawPath = Join-Path $temp 'write-data/script-output/data-raw-dump.json'

    # DELETED BEFORE THE RUN, NOT MERELY OVERWRITTEN BY IT. Both runs write this one path, so a
    # second run that exits 0 without writing -- and Invoke-FactorioStep only throws on a non-zero
    # exit -- leaves the FIRST run's dump sitting here for Test-Path to find. `loaded` would then be
    # a copy of `declared`, every connection would compare equal, and the report would read "no
    # difference: every connection of ours holds the category our data stage set." That is the last
    # way this instrument could pass by finding nothing, and the floor below cannot catch it: the
    # floor only inspects the declared side, which would be genuinely fine.
    Remove-Item -LiteralPath $rawPath -Force -ErrorAction SilentlyContinue

    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabledBundled -Mods $Mods
    Invoke-FactorioStep -FactorioExe $FactorioExe -ModDirectory $modDir `
        -Arguments @('--dump-data') -OutputDirectory $temp -Tag $Tag | Out-Null

    if (-not (Test-Path $rawPath)) { throw "no data-raw-dump.json at $rawPath." }
    # Kept aside under the tag so -KeepTemp leaves both dumps to compare by hand.
    Copy-Item -LiteralPath $rawPath -Destination (Join-Path $temp "$Tag-data-raw.json") -Force

    $found = @{}
    $parsed = Get-Content -LiteralPath $rawPath -Raw | ConvertFrom-Json
    foreach ($type in $parsed.PSObject.Properties) {
        foreach ($prototype in $type.Value.PSObject.Properties) {
            if (-not $prototype.Name.StartsWith($PREFIX, [StringComparison]::Ordinal)) { continue }
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

try {
    Write-Host "set: $($alsoMods.Count) mod(s) at $AlsoModDirectory"
    Write-Host "bundled enabled: $(if ($enabledBundled) { $enabledBundled -join ', ' } else { 'none (base 2.0 only)' })"

    Write-Host 'dumping with our mods alone (declared)...'
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    $declared = Get-OurConnections -Mods $ourMods -Tag 'declared'

    # Every rf- prototype is in $declared, most of them with no connections at all -- items, recipes,
    # technologies. Only the ones that HAVE a pipe connection are subjects; the rest are in the map
    # solely so that a prototype's ABSENCE from the loaded dump can be told from its fluid box being
    # emptied, which are different accidents.
    $subjects = @($declared.Keys | Where-Object { $declared[$_].Count } | Sort-Object)

    # THE FLOOR. Everything below reports by finding nothing, so a broken walk reads as containment
    # surviving. An instrument fault, not a finding -- and the only non-zero exit that comes from
    # what was measured rather than from the run refusing to happen. See the header for the others.
    $carrying = @($declared.Values | ForEach-Object { $_.Values } |
        Where-Object { $_.Set -ccontains $PLASMA_CATEGORY })
    if (-not $carrying) {
        throw ("the declared dump holds no connection carrying '$PLASMA_CATEGORY' across " +
               "$($subjects.Count) prototype(s) of ours. Either containment has been removed from " +
               'the data stage or this probe has stopped reading it -- and both would otherwise ' +
               'report a clean pass against any set at all.')
    }
    Write-Host ("declared: $($subjects.Count) prototype(s) of ours with pipe connections, " +
                "$($carrying.Count) connection(s) carrying $PLASMA_CATEGORY")

    Write-Host 'dumping with the set loaded beside them (loaded)...'
    New-ModJunctions -ModDirectory $modDir -RepoRoot $AlsoModDirectory -Mods $alsoMods
    $loaded = Get-OurConnections -Mods ($ourMods + $alsoMods) -Tag 'loaded'

    # ------------------------------------------------------------------------------------- report
    #
    # EVERY DIFFERENCE IS REPORTED, AND THEY ARE NOT ALL THE SAME FINDING. Measured against
    # `seablock`, 44 of 46 differences are `no-pipe-touching` appending its collected pipe names to
    # connections we left DEFAULT -- which is that mod doing exactly what it exists to do, on boxes
    # this repo never contained. Printing those in one undifferentiated list buries the two rows that
    # answer the question. So each row carries a verdict, and the verdicts sort before the rows.
    #
    # The three are distinct in consequence, not merely in wording:
    #
    #   LOST                  A category we DECLARED is not in the loaded value. Containment is
    #                         simply gone from that connection, and whatever the set put there is
    #                         what a player's pipes now match against.
    #
    #   WIDENED (categorised) Everything we declared survives and MORE was added, on a connection we
    #                         categorised on purpose. This is a breach too, and stating otherwise
    #                         would be the mistake this probe exists to prevent: a connection
    #                         category is a whitelist, so adding to one we wrote opens the box to
    #                         whatever was added, even though `rf-plasma` is still in the list.
    #
    #   widened (default)     The same append on a connection we left default. Not containment at
    #                         all -- an ordinary box of ours, treated like every other ordinary box
    #                         in the game. Counted and printed, last.
    $compared = 0
    $rows     = [System.Collections.Generic.List[object]]::new()

    # Sorted, not merely labelled: the answer has to be at the top of the output.
    #
    # LOST says "a category WE WROTE is gone" and it must not say it about a category we never wrote.
    # Expand-Category synthesises `default` for an absent field, because that is what the engine
    # reads an absent field as and the comparison turns on it -- but that synthesised value is not a
    # declaration of ours. Without $REPLACED below, a set that OVERWRITES an ordinary box of ours
    # would land in LOST, sorted above the real findings, claiming we declared something we did not.
    # `no-pipe-touching` writes exactly such a literal at :225, so this is a shape that exists.
    $LOST       = 'LOST -- a category we wrote is gone'
    $WIDE       = 'WIDENED -- added to a connection we categorised'
    $REPLACED   = 'REPLACED -- an ordinary box of ours no longer holds the default category'
    $STRUCTURAL = 'STRUCTURAL -- the connection or the prototype is not there to compare'
    $OPEN       = 'widened -- added to a connection we left default'
    $ORDER = @{ $LOST = 0; $WIDE = 1; $REPLACED = 2; $STRUCTURAL = 3; $OPEN = 4 }

    function Add-Row {
        param($Verdict, $Prototype, $Connection, $Type, $Declared, $Loaded)
        $rows.Add([pscustomobject]@{
            Verdict = $Verdict; Prototype = $Prototype; Connection = $Connection
            Type = $Type; Declared = $Declared; Loaded = $Loaded })
    }

    foreach ($key in $subjects) {
        if (-not $loaded.ContainsKey($key)) {
            Add-Row $STRUCTURAL $key '(the whole prototype)' '-' 'present' 'the prototype is gone from the dump'
            continue
        }
        $mine  = $declared[$key]
        $their = $loaded[$key]
        foreach ($path in ($mine.Keys | Sort-Object)) {
            if (-not $their.ContainsKey($path)) {
                Add-Row $STRUCTURAL $key $path $mine[$path].Type $mine[$path].Category 'the connection is gone'
                continue
            }
            $compared++
            $mineSet  = $mine[$path].Set
            $theirSet = $their[$path].Set

            # COMPARED AS SETS, NOT AS RENDERED TEXT, and that is not a refinement -- comparing the
            # printed form reports a difference where the engine sees none. `contain()` writes the
            # BARE STRING "rf-plasma", while `no-pipe-touching` rewrites the field in place as a
            # one-element list on every connection it merely INSPECTS
            # (has_default_category, data-final-fixes.lua:14, called for its side effect on
            # prototypes it then leaves alone). "rf-plasma" and {"rf-plasma"} are the same category
            # to the engine, so a row for that pair would be a false positive -- and it would land
            # in WIDENED, claiming a box was opened with nothing added to it.
            #
            # Ordinal, because a category is a name the engine matches exactly and PowerShell's
            # -contains is not: a set writing "RF-Plasma" would compare equal and be a real breach.
            $gone = @($mineSet | Where-Object {
                $name = $_
                -not @($theirSet | Where-Object { $_ -ceq $name }) })
            $added = @($theirSet | Where-Object {
                $name = $_
                -not @($mineSet | Where-Object { $_ -ceq $name }) })
            if (-not $gone -and -not $added) { continue }

            # Scalar comparisons, not array ones: PowerShell's -ceq with an ARRAY on the left is a
            # filter and not a test, so `$set -ceq @('default')` returns elements rather than $true
            # or $false and every row would classify the same way.
            $wasDefault = $mineSet.Count -eq 1 -and $mineSet[0] -ceq 'default'
            $verdict = if ($wasDefault) { if ($gone) { $REPLACED } else { $OPEN } }
                       elseif ($gone) { $LOST }
                       else { $WIDE }
            Add-Row $verdict $key $path $mine[$path].Type $mine[$path].Category $their[$path].Category
        }
        # A connection the set ADDED. Not a reassignment, but it is a box of ours the set has been
        # inside, and finding that out from a count alone would be worse than a row.
        foreach ($path in ($their.Keys | Sort-Object)) {
            if ($mine.ContainsKey($path)) { continue }
            Add-Row $STRUCTURAL $key $path $their[$path].Type 'no such connection' $their[$path].Category
        }
    }

    Write-Host ''
    Write-Host "compared $compared connection(s) across $($subjects.Count) prototype(s) of ours"
    if (-not $rows) {
        Write-Host 'no difference: every connection of ours holds the category our data stage set.'
    }
    else {
        Write-Host "$($rows.Count) difference(s):"
        $labels = @($rows | ForEach-Object { $_.Verdict } | Select-Object -Unique | Sort-Object { $ORDER[$_] })
        foreach ($label in $labels) {
            $inVerdict = @($rows | Where-Object { $_.Verdict -eq $label })
            Write-Host ''
            Write-Host "  $label  ($($inVerdict.Count))"
            foreach ($group in ($inVerdict | Group-Object Prototype)) {
                foreach ($row in $group.Group) {
                    Write-Host "    $($group.Name)  $($row.Connection)  [$($row.Type)]"
                    Write-Host "      declared: $($row.Declared)"
                    Write-Host "      loaded:   $($row.Loaded)"
                }
            }
        }
    }

    Write-Host ''
    Write-Host 'This is a probe. Exit 0 means it ran and reported, not that the answer was the'
    Write-Host 'hoped-for one. Findings go in docs/research/connection-category-reassignment.md.'
}
finally {
    # UNCONDITIONALLY, AND NOT INSIDE THE -KeepTemp BRANCH. The junctions point at the repository's
    # own mod directories and at the cache; anything that later deletes this temp directory
    # recursively follows them and deletes the source through the link. Remove-TempDirectory's own
    # header says it follows junctions rather than skipping them, and Storage Sense, Disk Cleanup or
    # a hand Remove-Item -Recurse all do the same. load-check.ps1 and every probe here remove them
    # unconditionally for exactly this reason. -KeepTemp is for reading the two dumps, which do not
    # need the links to still be there.
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'probe-connection-categories' }
    else { Write-Host "kept: $temp (mod junctions removed; the two dumps are *-data-raw.json)" }
}

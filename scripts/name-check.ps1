#Requires -Version 7
<#
.SYNOPSIS
    Fails if this repo defines a prototype name that is not its own, or one another mod already
    uses. Discharges #33's collision criterion.

.DESCRIPTION
    ADR 0007 commits to coexistence with other mods, Krastorio 2 most of all. Coexistence means
    loading and running without colliding, and the way two Factorio mods collide by accident is a
    shared prototype name: the second definition silently replaces the first, so the mod that loads
    later wins and the player gets one of the two entities at random depending on load order.

    ADR 0009 is what makes that avoidable rather than a matter of luck: everything this project
    defines carries the rf- prefix. This check enforces it, and then checks the prefix is actually
    worth something by looking at what the neighbours use.

    METHOD

    Two dumps, diffed, then a scan.

    --dump-data with this repo's mods gives every prototype in the game. --dump-data with none of
    them gives the same thing without us. What is in the first and not the second is ours -- by
    construction, not by trusting the prefix we are trying to verify. Deriving it from the prefix
    would be circular: a prototype named `fusion-reactor` is exactly the failure this exists to
    catch, and a prefix-based scan would not see it, because it is looking for rf-.

    A set difference alone is not enough, though, and the gap is the important one. A prototype we
    define under a name the game ALREADY uses appears in both dumps, so it cancels out and would never
    be checked -- and that is the silent-overwrite case, where our definition simply replaces vanilla's
    and the game loads without a word. So both dumps are keyed by type AND name and carry the
    serialised prototype as their value: added names come from the difference, replaced ones from
    comparing content across what the two dumps share.

    Then every name that is ours must start with rf-. That is the ADR 0009 half, and it is the one
    that does the real work: a prefix nothing else uses makes collision with EVERY mod impossible,
    not just the two read below.

    One shape is exempt, and only one: base Factorio generates `empty-rf-<fluid>-barrel` for each of
    our barrelled fluids, which no discipline here can rename. It still embeds the prefix, so it is
    still collision-proof. The count is printed rather than passed over, because a jump in it means
    the game has started generating something new from our prototypes.

    The scan is the second half. The reference mods are read off disk and their prototype names
    harvested, and no name of theirs may be one of ours. This is a weaker instrument than the dump
    and is honest about it -- see WHAT THIS DOES NOT PROVE.

    WHY THE REFERENCE MODS ARE READ RATHER THAN LOADED

    Loading is the better instrument and it is available for Krastorio 2 -- `load-check.ps1
    -AlsoModDirectory` runs the game with K2 2.0.19 and its four dependencies enabled, which is what
    actually discharges ADR 0007. This check is the complement, not a substitute for it, and it earns
    its place three ways.

    It covers what cannot be loaded. K2's CURRENT release is 2.1.3 (factorio_version 2.1,
    base >= 2.1.7) and this repo declares 2.0, so the two cannot be enabled together at all: Factorio
    treats 2.0 and 2.1 as different major versions a mod cannot span. Only the 2.0 line loads here.
    Reading names off disk is version-blind, so it says something about the release players actually
    run while the load-check necessarily says something about an older one. Both predecessors are
    1.1-era and can never be loaded beside this mod at all, so for them the scan is the ONLY
    instrument there is.

    And it names the failure. A collision does not stop the game loading -- the second definition
    silently replaces the first -- so a passing load-check is not evidence of collision-freedom. That
    is the whole reason this script exists separately.

    So it answers "would these names collide", and does not answer "do these mods load together",
    which is load-check.ps1's job.

    WHAT THIS DOES NOT PROVE

    - **Not that the mods load together.** Nothing here runs Factorio with another mod present. A
      set can be free of name collisions and still fail on a recipe pointing at an item the other
      mod removed, or an icon path that moved.
    - **The harvest is a regex over Lua, so it over-collects.** It matches `name = "..."` anywhere,
      which picks up field values that are not prototype names at all. That direction is safe: a
      name we do not define cannot become a false pass, only a false alarm. It under-collects too,
      wherever a name is built by concatenation or in a loop -- and THAT direction is not safe, so
      a clean scan is evidence and not proof.
    - **It compares names across types, which is stricter than Factorio.** Prototype names are
      unique within a type, so `kr-fluid` the item and `kr-fluid` the recipe are two different
      prototypes and colliding with one is not colliding with the other. Comparing name-only can
      therefore report a collision that is not one. Stricter is the right way to be wrong here, and
      any hit is printed with our type so it can be judged rather than guessed at.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER ReferenceDirectory
    Where the mods to scan against live. Defaults to $env:RF_REFERENCE_DIR, then the survey's own
    location. These are not this repo's to ship -- see docs/adr/0001-liftable-predecessor-material.md
    -- so they are read where they already are rather than vendored in.

.PARAMETER With
    Bundled mods to enable, e.g. -With space-age. Worth running both ways: the expansion generates a
    recycling recipe per item, so it adds prototypes that inherit our names and must carry the
    prefix too.

.PARAMETER SelfTest
    Verify the check can fail. Four halves: the repo as it stands must pass; an unprefixed name must
    be caught; a name a reference mod already uses must be caught; and -- through a real canary mod
    and a third dump -- a prototype added without the prefix AND a vanilla prototype replaced must
    both be derived from the dumps rather than merely judged once handed over. The first half is
    required or the rest prove nothing; the last is the only one that tests the derivation itself.

.PARAMETER KeepTemp
    Keep the dumps for inspection. Junctions are always removed.

.EXAMPLE
    pwsh -File scripts/name-check.ps1
    pwsh -File scripts/name-check.ps1 -With space-age
    pwsh -File scripts/name-check.ps1 -SelfTest
#>
[CmdletBinding()]
param(
    [string]   $FactorioExe,
    [string]   $ReferenceDirectory,
    [string[]] $With = @(),
    [switch]   $SelfTest,
    [switch]   $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$PREFIX   = 'rf-'   # ADR 0009: everything this project defines carries it

# The one shape of name that is ours without starting with the prefix.
#
# Base Factorio generates a recipe to EMPTY each barrelled fluid, named empty-<fluid>-barrel, so a
# fluid of ours arrives as `empty-rf-brine-barrel`. That name is ours by consequence, not by choice,
# and no amount of discipline here would change it short of turning barrels off. The recipe that
# FILLS the barrel needs no exception: 2.0 names it after the barrel item, which is `rf-brine-barrel`
# and prefixed already. Checked against a base-only --dump-data on 2.0.77 -- 217 recipes, `empty-`
# among them and no `fill-` at all -- rather than assumed from the 1.1 naming.
#
# It still embeds the prefix, so it cannot collide with another mod either; what it cannot do is
# start with it. Barrels have already caused one wrong result in this repo (d2a8a30).
$DERIVED = "^empty-$PREFIX.+-barrel$"

# Vanilla prototypes this repo is allowed to CHANGE rather than merely add beside.
#
# Modifying a vanilla prototype is legitimate integration, not a collision, but it has to be declared
# so that the day an unintended one appears it stands out. Exactly one is expected, and it is not even
# written by hand: base Factorio's barrel generation appends an unlock-recipe effect per barrelled
# fluid to `fluid-handling`, so our fluids land in vanilla's own technology. Only the `effects` field
# differs -- checked, not assumed.
$ALLOWED_EDITS = @('technology/fluid-handling')

# The mods to scan, and the smallest harvest that is credible for each. The floor is the point:
# without it a directory that moved, or a regex that stopped matching, reads as a clean pass. A
# check that can quietly not run is worse than one that is not there.
#
# Named REFERENCE_MODS, not REFERENCES, because PowerShell variable names are case-INSENSITIVE: a
# later `$references = @{}` for the results would silently be the same variable, and this list would
# be gone by the time the loop below read it. It was, and the loop then iterated the empty hashtable
# as a single object rather than not at all -- so every field came back $null and the scan read the
# whole reference directory at once.
$REFERENCE_MODS = @(
    @{ Directory = 'Krastorio2';                    Label = 'Krastorio 2';            Floor = 500 }
    @{ Directory = 'RealisticFusionPowerPort_1.9.2'; Label = "Durikkan's 2.0 port";    Floor = 50 }
    @{ Directory = 'RealisticFusionPower_1.8.18';    Label = 'Realistic Fusion Power'; Floor = 50 }
)

if (-not $ReferenceDirectory) {
    $ReferenceDirectory = if ($env:RF_REFERENCE_DIR) { $env:RF_REFERENCE_DIR } else { 'C:\src\factorio\_reference' }
}

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe
try {
    $enabledBundled = Resolve-BundledSelection -Requested $With -Bundled $bundled
}
catch { throw "-With $($_.Exception.Message)" }

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-namecheck-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
New-Item -ItemType Directory -Path $modDir -Force | Out-Null

function Get-PrototypeNames {
    <#  Every prototype in data.raw as "type/name" -> a signature of its content.

        Keyed by type AND name because that is how Factorio identifies a prototype: names are unique
        within a type, so `kr-fluid` the item and `kr-fluid` the recipe are two different things.
        Keying by name alone would also hide the case where we add a prototype of a NEW type reusing
        an existing name.

        The value is the serialised prototype rather than just its presence, so the caller can tell
        an ADDED prototype from a REPLACED one. That distinction is the whole point: replacing a
        prototype the game already defines is silent, and it is the exact accident this check exists
        to catch.  #>
    param([string[]] $Mods, [string] $Tag)

    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabledBundled -Mods $Mods

    $result = Invoke-Factorio -FactorioExe $FactorioExe -ModDirectory $modDir `
        -Arguments @('--dump-data') -OutputDirectory $temp -Tag $Tag
    if ($result.Code -ne 0) {
        Write-FactorioTail $result
        throw "Factorio exited $($result.Code) on --dump-data with mods: $($Mods -join ', ')."
    }

    $rawPath = Join-Path $temp 'write-data/script-output/data-raw-dump.json'
    if (-not (Test-Path $rawPath)) { throw "no data-raw-dump.json at $rawPath." }

    # Both runs write to the same path, so the second overwrites the first. Kept aside under the run's
    # tag so -KeepTemp leaves both dumps to compare rather than only the baseline.
    Copy-Item -LiteralPath $rawPath -Destination (Join-Path $temp "$Tag-data-raw.json") -Force

    $found = @{}
    $parsed = Get-Content -LiteralPath $rawPath -Raw | ConvertFrom-Json
    foreach ($type in $parsed.PSObject.Properties) {
        foreach ($p in $type.Value.PSObject.Properties) {
            # Serialised so two dumps can be compared for CONTENT, not just for presence. Depth 100
            # is the maximum ConvertTo-Json accepts; anything deeper truncates, but it truncates
            # identically on both sides, so a comparison stays valid even where a sprite is deeper
            # than that.
            $found["$($type.Name)/$($p.Name)"] =
                ($p.Value | ConvertTo-Json -Depth 100 -Compress -WarningAction SilentlyContinue)
        }
    }
    return $found
}

function Get-OurNames {
    <#  The prototypes present with this repo loaded and absent without it, as name -> its types.

        Derived by difference rather than by prefix. Deriving them from the prefix would assume the
        thing being checked: a prototype named `fusion-reactor` is exactly the failure this exists to
        catch, and a prefix-based scan is looking for rf- and would not see it.  #>
    param([hashtable] $WithUs, [hashtable] $Baseline)

    $names = @{}
    foreach ($key in $WithUs.Keys) {
        if ($Baseline.ContainsKey($key)) { continue }
        $type, $name = $key -split '/', 2
        if (-not $names.ContainsKey($name)) { $names[$name] = @() }
        $names[$name] += $type
    }
    return $names
}

function Get-Replaced {
    <#  Prototypes the game already defines whose content this repo CHANGES.

        The other half of the derivation, and the half a set difference cannot see: a prototype we
        redefine under a name that already exists is present in both dumps, so it cancels out of
        Get-OurNames entirely and would never be checked. That is the silent-overwrite case -- the
        second definition replaces the first and the game loads without complaint -- so it has to be
        found by comparing content, not presence.

        Measured on 2026-08-18 against base 2.0.77: of 2,840 shared prototypes exactly one differs,
        and it is in $ALLOWED_EDITS below. So this is a near-silent instrument rather than a noisy
        one, which is what makes it worth having.  #>
    param([hashtable] $WithUs, [hashtable] $Baseline)

    return @($WithUs.Keys |
        Where-Object { $Baseline.ContainsKey($_) -and $Baseline[$_] -ne $WithUs[$_] -and $_ -notin $ALLOWED_EDITS } |
        Sort-Object)
}

function Get-ReferenceNames {
    <#  Harvest prototype names from a mod's Lua by regex.

        Over-collects on purpose: `name = "..."` matches plenty of fields that are not prototype
        names. A name we never define cannot cause a false pass, so the safe direction is to collect
        too much. It also under-collects, wherever a name is concatenated or built in a loop, which
        is why the docstring above calls a clean scan evidence rather than proof.  #>
    param([string] $Path)

    $found = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($file in Get-ChildItem -Path $Path -Filter '*.lua' -Recurse -File) {
        foreach ($m in [regex]::Matches((Get-Content -LiteralPath $file.FullName -Raw), '\bname\s*=\s*"([^"]+)"')) {
            [void] $found.Add($m.Groups[1].Value)
        }
    }
    # Comma: PowerShell unrolls a collection on return, which would hand back a plain string[] and
    # cost the set semantics .Contains() below relies on.
    return ,$found
}

function Test-Names {
    <#  The check itself, over a given set of our prototypes. Returns the failures as strings so the
        self-test can assert on them instead of on an exit code it would have to trust.  #>
    param([hashtable] $Ours, [hashtable] $References, [string[]] $Replaced = @())

    $failures = @()

    foreach ($k in $Replaced) {
        $failures += ("replaces: '$k' already exists in the game and this repo changes it. Adding a " +
                      "prototype beside the game's is coexistence; redefining one silently replaces it.")
    }

    $unprefixed = @($Ours.Keys |
        Where-Object { -not $_.StartsWith($PREFIX, [StringComparison]::Ordinal) -and $_ -notmatch $DERIVED } |
        Sort-Object)
    foreach ($n in $unprefixed) {
        $failures += "unprefixed: '$n' ($($Ours[$n] -join ', ')) does not start with '$PREFIX' -- ADR 0009"
    }

    foreach ($ref in $References.Keys | Sort-Object) {
        $shared = @($Ours.Keys | Where-Object { $References[$ref].Contains($_) } | Sort-Object)
        foreach ($n in $shared) {
            $failures += "collision: '$n' ($($Ours[$n] -join ', ')) is also defined by $ref"
        }
    }
    return $failures
}

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods

    # Read the neighbours first: it needs no Factorio and a missing directory should be reported
    # before spending two dumps on it.
    if (-not (Test-Path $ReferenceDirectory)) {
        throw ("reference directory not found: $ReferenceDirectory. This check reads Krastorio 2 and the " +
               "predecessors from disk rather than shipping them; point -ReferenceDirectory or " +
               "`$env:RF_REFERENCE_DIR at where they are.")
    }

    $scanned = @{}
    foreach ($r in $REFERENCE_MODS) {
        $path = Join-Path $ReferenceDirectory $r.Directory
        if (-not (Test-Path $path)) {
            throw "reference mod not found: $path. Expected $($r.Label) there; the scan cannot be skipped silently."
        }
        $harvested = Get-ReferenceNames -Path $path
        if ($harvested.Count -lt $r.Floor) {
            throw ("harvested only $($harvested.Count) names from $($r.Label) at $path, below the floor of " +
                   "$($r.Floor). Either the directory is not what it was, or the harvest regex has stopped " +
                   "matching -- both of which would otherwise read as a clean pass.")
        }
        $scanned[$r.Label] = $harvested
        Write-Host "scanned $($r.Label): $($harvested.Count) candidate names"
    }

    # Ours by difference, not by prefix. See METHOD: deriving them from the prefix would assume the
    # thing being checked.
    Write-Host 'dumping with this repo, then without it...'
    $withUs = Get-PrototypeNames -Mods $ourMods -Tag 'with-us'

    # The junctions have to GO for the baseline, not merely be left out of the mod list. Factorio
    # enables any mod it finds in the mod directory that the list does not mention, so a list that
    # simply omits ours produces a second dump identical to the first -- which then reads as "this
    # repo defines nothing" rather than as a broken baseline. It did.
    Remove-ModJunctions -ModDirectory $modDir
    $withoutUs = Get-PrototypeNames -Mods @() -Tag 'without-us'

    $ours = Get-OurNames -WithUs $withUs -Baseline $withoutUs
    if ($ours.Count -eq 0) {
        throw 'the two dumps differ by nothing, so this repo appears to define no prototypes at all. That is not a pass.'
    }
    $replaced = Get-Replaced -WithUs $withUs -Baseline $withoutUs
    # The derived count is printed rather than quietly excused: it is an exception to ADR 0009 and a
    # jump in it means the game started generating something new from our prototypes.
    # Not $derived: that is $DERIVED to PowerShell, and assigning the list here would overwrite the
    # pattern before Test-Names below ever reads it. Same trap as $REFERENCE_MODS above, and it bit
    # here too.
    $derivedNames = @($ours.Keys | Where-Object { $_ -match $DERIVED })
    Write-Host ("this repo defines {0} prototype name(s) the game does not; {1} of them are barrel recipes base Factorio named." -f
        $ours.Count, $derivedNames.Count)
    Write-Host ("it changes {0} prototype(s) the game already defines, beyond the {1} declared in `$ALLOWED_EDITS." -f
        $replaced.Count, $ALLOWED_EDITS.Count)

    $failures = Test-Names -Ours $ours -References $scanned -Replaced $replaced

    if ($SelfTest) {
        # Half one: the repo as it stands must pass, or halves two and three prove nothing.
        if ($failures) {
            Write-Host 'FAILED - self-test: the repo as it stands does not pass, so a caught canary would prove nothing.'
            foreach ($f in $failures) { Write-Host "    $f" }
            exit 1
        }
        Write-Host 'self-test 1/4: the repo as it stands passes.'

        # Half two: an unprefixed name must be caught. Injected into the parsed set rather than into
        # a canary mod, because what is being tested is this script's judgement, not Factorio's --
        # and a real mod would cost two more dumps to say the same thing.
        $canaryOurs = @{} + $ours
        $canaryOurs['fusion-reactor'] = @('reactor')
        $caught = Test-Names -Ours $canaryOurs -References $scanned
        if (-not ($caught | Where-Object { $_ -like "unprefixed: 'fusion-reactor'*" })) {
            Write-Host 'FAILED - self-test: an unprefixed prototype name was NOT caught.'
            exit 1
        }
        Write-Host 'self-test 2/4: an unprefixed name is caught.'

        # Half three: a name a reference mod already uses must be caught, even when it is prefixed
        # correctly. Takes a name from the harvest rather than inventing one, so the test breaks if
        # the harvest ever comes back empty.
        $borrowed = @($scanned.Values)[0] | Select-Object -First 1
        if (-not $borrowed) { Write-Host 'FAILED - self-test: nothing harvested to borrow a name from.'; exit 1 }
        $canaryOurs = @{} + $ours
        $canaryOurs[$borrowed] = @('item')
        $caught = Test-Names -Ours $canaryOurs -References $scanned
        if (-not ($caught | Where-Object { $_ -like "collision: '$borrowed'*" })) {
            Write-Host "FAILED - self-test: a name already used by a reference mod ('$borrowed') was NOT caught."
            exit 1
        }
        Write-Host 'self-test 3/4: a name a reference mod already uses is caught.'

        # Half four: the DERIVATION itself, through a real mod and a real dump.
        #
        # Halves two and three inject into the parsed set, so they prove Test-Names judges a set it is
        # handed -- and nothing about how that set is built. That is not good enough for the case this
        # script exists to catch: a prototype we define under a name the game already uses is present
        # in BOTH dumps and cancels out of the difference, so an injected canary would sail past a
        # derivation that never sees it. This half builds the canary as a mod, dumps the game with it,
        # and derives from scratch.
        $canary = Join-Path $modDir 'rf-namecheck-canary'
        New-Item -ItemType Directory -Path $canary -Force | Out-Null
        @{
            name = 'rf-namecheck-canary'; version = '0.0.1'; title = 'Name-check canary'
            author = 'name-check.ps1'; factorio_version = '2.0'; dependencies = @('base >= 2.0.77')
        } | ConvertTo-Json | Set-Content -Path (Join-Path $canary 'info.json') -Encoding utf8
        # One of each failure: a NEW prototype with no prefix, and a REPLACED vanilla one. iron-plate
        # is chosen because nothing in this repo touches it, so a hit is unambiguous.
        'data:extend({{ type = "item", name = "fusion-canary-item", stack_size = 1,
  icon = "__base__/graphics/icons/iron-plate.png", icon_size = 64 }})
data.raw.item["iron-plate"].stack_size = 123' |
            Set-Content -Path (Join-Path $canary 'data.lua') -Encoding utf8

        New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
        $withCanary = Get-PrototypeNames -Mods ($ourMods + 'rf-namecheck-canary') -Tag 'canary'

        $canaryNames    = Get-OurNames -WithUs $withCanary -Baseline $withoutUs
        $canaryReplaced = Get-Replaced -WithUs $withCanary -Baseline $withoutUs

        if (-not $canaryNames.ContainsKey('fusion-canary-item')) {
            Write-Host 'FAILED - self-test: an unprefixed prototype added by a real mod was not derived at all,'
            Write-Host '         so the difference this check rests on is not finding what it should.'
            exit 1
        }
        if ($canaryReplaced -notcontains 'item/iron-plate') {
            Write-Host 'FAILED - self-test: a REPLACED vanilla prototype was not detected. This is the silent'
            Write-Host '         overwrite case -- present in both dumps, so a set difference alone cannot see'
            Write-Host "         it -- and it is the one this check most needs to catch. Found: $($canaryReplaced -join ', ')"
            exit 1
        }
        $caught = Test-Names -Ours $canaryNames -References $scanned -Replaced $canaryReplaced
        if (-not ($caught | Where-Object { $_ -like "replaces: 'item/iron-plate'*" })) {
            Write-Host 'FAILED - self-test: the replaced prototype was derived but not reported as a failure.'
            exit 1
        }
        Write-Host 'self-test 4/4: a real mod adding an unprefixed name and replacing a vanilla prototype is caught.'

        Write-Host ''
        Write-Host 'OK - self-test passed: clean repo passes; unprefixed name, borrowed name and a real'
        Write-Host '     mod that adds and replaces are all caught.'
        exit 0
    }

    if ($failures) {
        Write-Host ''
        Write-Host "FAILED - $($failures.Count) name problem(s):"
        foreach ($f in $failures) { Write-Host "    $f" }
        exit 1
    }

    $bundledOn = if ($enabledBundled) { $enabledBundled -join ', ' } else { 'none (base 2.0 only)' }
    Write-Host ''
    Write-Host "OK - all $($ours.Count) prototype names this repo defines carry '$PREFIX', and none is used by"
    Write-Host "     Krastorio 2 or either predecessor. Bundled enabled: $bundledOn."
    exit 0
}
finally {
    Remove-ModJunctions -ModDirectory $modDir
    if ($KeepTemp) { Write-Host "temp kept at: $temp" }
    else { Remove-TempDirectory -Path $temp -Label 'name-check' }
}

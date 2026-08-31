<#
.SYNOPSIS
    Fails if this repo defines a prototype name that is not its own, or one another mod already
    uses. Discharges #33's collision criterion, and -AlsoModDirectory extends it per set for #61.

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

    SINCE #61 IT CAN DO BOTH FOR A SET IT IS GIVEN. -AlsoModDirectory loads a coexistence lane's
    mods into both dumps, which turns the second half from a regex scan into a measurement: what
    this repo replaces in that set is derived from the game rather than harvested from its Lua. The
    scan stays for the direction the dumps cannot see, and for the mods that can never be loaded
    here at all. See that parameter.

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

.PARAMETER AlsoModDirectory
    A directory of third-party mod directories to LOAD as well as scan, e.g. what
    scripts/fetch-mods.ps1 wrote for one of #61's coexistence lanes. Same shape load-check.ps1 takes
    it in, and for the same reason: this script downloads nothing.

        pwsh -File scripts/fetch-mods.ps1 -Set angels
        pwsh -File scripts/name-check.ps1 -AlsoModDirectory .mod-cache/angels

    THIS IS THE PER-SET COLLISION CHECK, and it is a stronger instrument than the scan. The set is
    junctioned in and enabled in BOTH dumps, so the baseline becomes "the game with that set and
    without us". The difference is therefore still exactly what this repo adds -- and $replaced
    becomes what this repo CHANGES in the set as well as in vanilla, which is the silent overwrite
    ADR 0007 calls the most likely way coexistence fails. Without a set loaded the check can only
    say our names carry the prefix; with one it can say what actually happened when both loaded.

    The set is harvested by regex as well, and that half is not redundant. The dumps see a
    collision where WE replace THEM. They cannot see it running the other way: a set that loads
    after us and redefines one of our names unconditionally puts its version in both dumps, so the
    name cancels out of the difference and the accident would be invisible -- our entity gone from
    the game and nothing saying so. The harvest reads what their Lua NAMES rather than what the game
    ended up with, so it catches that direction. Two instruments, two blind spots.

    That only works because the scan is given every prefixed name present in the loaded game and not
    merely the difference -- the name it needs to test is precisely the one the difference lost. The
    two lists are identical when no set is loaded, so nothing about the base check changes.

    A FAILURE HERE NEEDS TRIAGE AND IS NOT AUTOMATICALLY OURS. An overhaul that walks data.raw --
    which Angel's and Bob's both do -- reacts to prototypes this repo adds, so it can generate
    prototypes of its own from ours or touch vanilla ones it would otherwise leave alone. Those land
    in the difference attributed to this repo, because the difference is defined by our presence and
    cannot tell "we defined it" from "they defined it BECAUSE of us". Both are worth knowing and
    only the first is a defect here. ADR 0026 predicted this shape of triage for the coexistence
    lanes and it applies to names as much as to loading: read what the check found before reading it
    as a bug.

    It does not guard against the set failing to load, because Factorio does that itself and does it
    by exiting: a mod declaring factorio_version 2.1 and a directory whose name disagrees with its
    info.json both stop --dump-data with an error naming the mod. The run reports how many of the
    set's mods put prototypes in the dump instead, which is the same reassurance without a gate that
    could only ever fire on a set of pure asset mods.

    Cannot be combined with -SelfTest: the canary half derives from a clean baseline, and an
    overhaul in the same two dumps makes what it finds ambiguous.

.PARAMETER With
    Bundled mods to enable, e.g. -With space-age. Worth running both ways: the expansion generates a
    recycling recipe per item, so it adds prototypes that inherit our names and must carry the
    prefix too.

.PARAMETER SelfTest
    Verify the check can fail. Five halves: the repo as it stands must pass; an unprefixed name must
    be caught; a name a reference mod already uses must be caught; and -- through a real canary mod
    and a third dump -- a prototype added without the prefix AND a vanilla prototype replaced must
    both be derived from the dumps rather than merely judged once handed over. The first half is
    required or the rest prove nothing; the fourth is the only one that tests the derivation itself.

    The fifth pins the two classifiers -AlsoModDirectory brought with it, and it is there because
    they are the only code here that SUPPRESSES a finding: an over-broad rule turns a real collision
    into a counted line and the run still exits 0. It asserts the negatives as hard as the
    positives, across both wiring shapes Get-DerivedWiring knows and all three stories they carry --
    an unprefixed name of ours, an unlock naming a recipe that is not ours, a barrel unlock built
    from no fluid of ours, our barrel unlocks landing on a technology that carried none, a tooltip
    row naming nothing of ours, a row of theirs reworded in the same diff as one of ours, a field
    outside the shape's own changing, and any entry being removed must all still be reported. It
    also asserts each exemption is granted under the RIGHT label -- `unlock`, `rehomed`,
    `unlock+rehomed` or `tooltip` -- since one loop dispatches every one of them and a prototype
    excused for the wrong reason prints a sentence that is not true.

.PARAMETER KeepTemp
    Keep the dumps for inspection. Junctions are always removed.

.EXAMPLE
    pwsh -File scripts/name-check.ps1
    pwsh -File scripts/name-check.ps1 -With space-age
    pwsh -File scripts/name-check.ps1 -AlsoModDirectory .mod-cache/angels
    pwsh -File scripts/name-check.ps1 -SelfTest
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string]   $FactorioExe,
    [string]   $ReferenceDirectory,
    [string]   $AlsoModDirectory,
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

# The set to check against, if one was named. Read in the same shape load-check.ps1 reads it,
# deliberately: both take a DIRECTORY of unpacked mods rather than a mod name, because neither
# downloads anything -- scripts/fetch-mods.ps1 owns that half.
$alsoMods = @()
if ($AlsoModDirectory) {
    if ($SelfTest) {
        throw ('-SelfTest and -AlsoModDirectory cannot be combined: the canary half derives from a ' +
               'clean baseline, and a third-party overhaul in the same two dumps makes what it finds ' +
               'ambiguous. Run them separately.')
    }
    if (-not (Test-Path $AlsoModDirectory)) { throw "-AlsoModDirectory not found: $AlsoModDirectory" }
    # ABSOLUTE, BECAUSE A JUNCTION TARGET MUST BE -- the same trap #60 hit in load-check.ps1.
    $AlsoModDirectory = (Resolve-Path -LiteralPath $AlsoModDirectory).Path
    $alsoMods = @(Get-ChildItem -Path $AlsoModDirectory -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName 'info.json') } |
        ForEach-Object { $_.Name } | Sort-Object)
    # Empty is an error rather than an empty run: it would otherwise report a collision-free pass
    # against a set that was never loaded, which is the exact failure this check is shaped to avoid.
    if (-not $alsoMods) {
        throw "-AlsoModDirectory holds no mod directories (a directory with an info.json in it): $AlsoModDirectory"
    }
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

function Get-FiredEdits {
    <#  Which of the DECLARED edits actually happened on this run.

        $ALLOWED_EDITS names the vanilla prototypes this repo may change, and Get-Replaced above
        excludes them unconditionally so they are never reported as collisions. That exclusion makes
        the declared list say what is PERMITTED and never what OCCURRED -- and the summary line used
        to print the list's LENGTH beside a live count, so it read as though the permitted edit had
        happened. It said "the 1 declared" on every lane, whether or not anything was excused.

        THE BOB'S LANE IS WHERE THAT MISLEADS (#133). bobplates walks data.raw and moves every
        -barrel recipe's unlock off technology/fluid-handling onto a technology of its own, so the
        unlocks base Factorio generated for our fluids go across with vanilla's: the declared edit
        does NOT fire, and with that set loaded this repo changes no vanilla prototype at all. The
        old wording said the opposite to the one reader who most needed the truth -- the one chasing
        that lane's replaces: finding and deciding whether it was ours.

        ITS OWN FUNCTION RATHER THAN AN EXPRESSION AT THE CALL SITE, for the reason Get-DerivedWiring
        is one: this file's rule is that a judgement printed to a human must be breakable in the
        self-test, and an inline Where-Object cannot be. Half six poses it four questions a real run
        does not -- a declared edit that differs, one that does not, one absent from the baseline,
        and an undeclared name that differs -- and then checks the live answer as well.

        NOT SHARED WITH Get-Replaced, though the comparison inside is the same one. That function
        walks every shared key and EXCLUDES the declared list; this one walks the declared list and
        keeps what differs. They are complementary halves, so folding them together would mean
        giving Get-Replaced a mode switch to serve a reporting line.  #>
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $Declared,
        [Parameter(Mandatory)] [hashtable] $WithUs,
        [Parameter(Mandatory)] [hashtable] $Baseline
    )

    return @($Declared |
        Where-Object { $WithUs.ContainsKey($_) -and $Baseline.ContainsKey($_) -and $WithUs[$_] -ne $Baseline[$_] } |
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
        # ?? '' BECAUSE AN EMPTY .lua FILE READS AS $null, and [regex]::Matches($null, ...) throws
        # "Value cannot be null. (Parameter 'input')" rather than matching nothing. Latent here for
        # as long as this only read Krastorio 2 and the two predecessors, none of which ships a
        # zero-byte Lua file. It became reachable the moment -AlsoModDirectory started feeding
        # arbitrary third-party sets through the same harvest, and the first one tried it:
        # underground-pipe-pack 2.0.6 ships an empty init.lua, which killed the `fluid` lane.
        $text = (Get-Content -LiteralPath $file.FullName -Raw) ?? ''
        foreach ($m in [regex]::Matches($text, '\bname\s*=\s*"([^"]+)"')) {
            [void] $found.Add($m.Groups[1].Value)
        }
    }
    # Comma: PowerShell unrolls a collection on return, which would hand back a plain string[] and
    # cost the set semantics .Contains() below relies on.
    return ,$found
}

function Get-SetDerived {
    <#  Names in the difference that the LOADED SET built out of ours: name -> the name of ours it
        was built from.

        The third shape of "ours by consequence, not by choice", after `$DERIVED`'s barrels and Space
        Age's recycling recipes -- and the first one that does not carry the prefix. An overhaul that
        walks data.raw makes a prototype per thing it finds, and Krastorio 2 makes two: measured
        against K2 2.0.19 on 2026-08-27, it generates `kr-burn-<fluid>` for each of our seventeen
        fluids -- eleven ordinary ones, four plasmas and two energy fluids -- and `kr-crush-<item>`
        for each of our entities and barrels: 30 plus 17, the 47 below, every one named `kr-` first
        and `rf-` second. The plasmas are NOT exempt, which this said they were until the arithmetic
        was checked against the 17 quoted further down. K2's flare_stack_lib.auto_generate() loops
        the whole of data.raw.fluid and skips only a name blacklist, `hidden` and `parameter`; the
        plasmas set `auto_barrel = false`, which is a different mechanism entirely. They are K2's prototypes in K2's
        namespace; ADR 0009 has nothing to say about how another mod names its own, and reporting
        them as this repo's unprefixed names is simply wrong.

        WHAT KEEPS THIS FROM EXCUSING A REAL COLLISION. The name must EMBED one of ours that carries
        the prefix, which means it could not have existed before this repo did -- `kr-burn-rf-brine`
        is not a name Krastorio 2 could have chosen independently, because `rf-brine` is ours. A
        prototype of ours genuinely named without the prefix embeds no such name and is still caught.

        ONLY WITH A SET LOADED. Without -AlsoModDirectory this never runs and nothing about the check
        changes, which is what keeps ADR 0007's existing discharge exactly as measured.  #>
    param([Parameter(Mandatory)] [hashtable] $Ours)

    # Longest match wins, so `kr-crush-rf-brine-barrel` is attributed to `rf-brine-barrel` and not to
    # `rf-brine`. Only cosmetic -- both are ours -- but the report should name the right parent.
    $mine = @($Ours.Keys |
        Where-Object { $_.StartsWith($PREFIX, [StringComparison]::Ordinal) } |
        Sort-Object { $_.Length } -Descending)

    # NOT $derived, WHICH IS $DERIVED. PowerShell variable names are case-insensitive, so a local
    # named $derived here IS the barrel pattern at script scope -- and it would be a hashtable by the
    # time the loop below tried to match against it, so every barrel recipe would sail through as one
    # of the set's derivations. It did, and reported 58 where 47 was right. This file has been bitten
    # by the same trap twice before ($REFERENCE_MODS, $derivedNames); the comments there say so.
    $fromSet = @{}
    foreach ($n in @($Ours.Keys)) {
        if ($n.StartsWith($PREFIX, [StringComparison]::Ordinal) -or $n -match $DERIVED) { continue }
        $from = $mine | Where-Object { $n.Contains($_) } | Select-Object -First 1
        if ($from) { $fromSet[$n] = $from }
    }

    # A GENERATOR GENERATES MORE THAN ONE, and requiring that is what keeps this from excusing our
    # own mistakes. "Embeds one of our names" alone does not say who DEFINED the prototype: a name
    # this repo added as `fill-rf-brine-barrel` -- ours, unprefixed, outside $DERIVED's shape --
    # embeds `rf-brine-barrel` exactly as `kr-crush-rf-brine-barrel` does, so it would be excused
    # whenever a set happened to be loaded and reported whenever one was not. The same repo passing
    # or failing on an unrelated flag is not a check.
    #
    # A mod that walks data.raw emits one prototype per thing it finds, so its marker appears many
    # times over: 30 `kr-crush-` and 17 `kr-burn-` against Krastorio 2. A one-off does not.
    #
    # ponytail: two is the threshold, and it is a heuristic with a known ceiling -- a set that
    # derives exactly ONE prototype from us fails and wants reading. That is the right way round:
    # it fails loudly and a human looks, rather than passing quietly and nobody does.
    $singletons = @($fromSet.Keys |
        Group-Object { ($_ -split [regex]::Escape($fromSet[$_]), 2)[0] } |
        Where-Object { $_.Count -lt 2 } |
        ForEach-Object { $_.Group })
    foreach ($n in $singletons) { $fromSet.Remove($n) }

    return $fromSet
}

function Get-DerivedWiring {
    <#  Replaced prototypes whose entire difference is the set wiring its own derivations in.

        The other half of the same mechanism, and it arrives on the same run. TWO shapes are
        recognised, and both were found on a real lane rather than imagined:

        `effects` -- having generated `kr-burn-rf-<fluid>` per fluid of ours, Krastorio 2 appends an
        unlock-recipe effect for each into `technology/kr-fluid-excess-handling` -- its own
        technology, gaining its own recipes. Exactly the shape base Factorio's barrel generation has
        against `technology/fluid-handling`, which is the one entry `$ALLOWED_EDITS` declares.

        `custom_tooltip_fields` -- Space Exploration's `prototypes/phase-3/custom-tooltips.lua`
        walks `data.raw.fluid` and appends a consumption row per non-hidden fuel fluid to
        `generator/se-fluid-burner-generator`, and to `kr-gas-power-station` as well when Krastorio 2
        is there. So its generator's tooltip grows a row per fuel fluid of ours while the entity
        itself is untouched. Added on Truls's call after the spaceex lane reported it (#129); the
        measurement that lane made is the specification: only `custom_tooltip_fields` differed, it
        went from 2 rows to 4, nothing was removed, and the two new rows named this repo's only two
        fluids carrying a `fuel_value`.

        NARROW ON PURPOSE, and the narrowness is the safety. Both shapes require: the ONLY field
        that differs is that shape's own field; the diff is additions only, counted as a MULTISET, so
        nothing the set had was removed, altered or de-duplicated; and every added entry is one the
        set can be shown to have generated. A prototype of theirs that this repo genuinely overwrites
        fails these and is still reported.

        THE TWO SHAPES DO NOT PROVE AUTHORSHIP EQUALLY WELL, and pretending otherwise is how a
        suppression rule goes bad. An added `unlock-recipe` names a prototype of THEIRS that
        Get-SetDerived already attributed to the set, which is real evidence. A tooltip row names a
        prototype of OURS, which is equally consistent with the set describing our fluid and with
        this repo appending a row to their entity -- the two are byte-identical in a dump. The
        tooltip predicate carries what that costs, and its own ceiling; read it before widening it.

        WHY THE TOOLTIP TEST NAMES OUR PROTOTYPES RATHER THAN MATCHING THE PREFIX. A prefix test
        would be the circular reasoning this whole file exists to avoid, and it would fail in the
        worst direction: a row about a prototype of ours that was MISNAMED carries no `rf-`, so a
        prefix test would stop excusing it and report it as a replacement -- burying an ADR 0009
        breach under a finding about somebody else's generator. Testing against the difference
        excuses the row and still reports the unprefixed name, which is the right way round.

        ponytail: two fields, listed rather than generalised. A set that wires its derivations
        through a third (a prerequisite, an item's subgroup) surfaces as a plain `replaces:` and
        wants reading -- which is exactly how both of these were found.  #>
    param(
        # ALLOWEMPTYCOLLECTION, BECAUSE EMPTY IS THE HEALTHY CASE. A Mandatory [string[]] REFUSES an
        # empty array -- "Cannot bind argument to parameter 'Replaced' because it is null" -- and
        # $replaced is empty on every lane where this repo changes nothing of the set's, which is
        # what a good result looks like. Krastorio 2 hid it: K2's flare-stack generation replaces
        # exactly one technology, so the only lane ever run had a one-element array. RITEG replaces
        # nothing and crashed the check outright. An empty HASHTABLE binds to a Mandatory parameter
        # without complaint, which is why the other three need nothing.
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $Replaced,
        [Parameter(Mandatory)] [hashtable] $WithUs,
        [Parameter(Mandatory)] [hashtable] $Baseline,
        [Parameter(Mandatory)] [hashtable] $SetDerived,
        # The names this repo defines -- $ours.Keys at the call site. Empty is legitimate: the
        # unlock shape never reads it, so a caller testing only that half has nothing to pass.
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $OurNames,
        # The FLUIDS this repo defines, which is a narrower thing than $OurNames and cannot be
        # derived from it: the caller's map is name -> its types, and by the time it is flattened to
        # names the type is gone. The re-homed predicate builds barrel recipe names out of these and
        # has to know that `rf-brine` is a fluid while `rf-brine-barrel` is not. Empty is legitimate
        # for the same reason $OurNames' is -- a caller testing only the tooltip half passes none.
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $OurFluids
    )

    # The fields a wiring is allowed to touch, and the shape each one is. Adding a third means
    # adding its predicate below and its self-test cases -- not editing a regex. The predicate switch
    # THROWS on a shape it does not know, so a half-done addition stops the run instead of borrowing
    # another shape's test.
    #
    # KEYED BY FIELD AND NOT BY PROTOTYPE TYPE, deliberately (#191). Both shapes have only ever been
    # seen on one type each, but a type test would guard against something nobody has observed while
    # making the rule harder to read.
    #
    # A SHAPE IS NOT A LABEL. The `effects` shape carries two stories -- the set wiring in its own
    # derivations, and the set re-homing an unlock base Factorio generated from a fluid of ours --
    # and a prototype can hold both at once. The shape selects the predicate; the predicate says
    # which story or stories actually fired, and that is what gets recorded and printed.
    $SHAPES = @{ 'effects' = 'unlock'; 'custom_tooltip_fields' = 'tooltip' }

    $exempt = @{}
    foreach ($key in $Replaced) {
        $a = $WithUs[$key]   | ConvertFrom-Json
        $b = $Baseline[$key] | ConvertFrom-Json

        $fields = @($a.PSObject.Properties.Name) + @($b.PSObject.Properties.Name) | Sort-Object -Unique
        $differing = @()
        foreach ($f in $fields) {
            $va = $a.$f | ConvertTo-Json -Depth 100 -Compress -WarningAction SilentlyContinue
            $vb = $b.$f | ConvertTo-Json -Depth 100 -Compress -WarningAction SilentlyContinue
            if ($va -ne $vb) { $differing += $f }
        }
        if ($differing.Count -ne 1 -or -not $SHAPES.ContainsKey($differing[0])) { continue }
        $field = $differing[0]

        # AN ABSENT FIELD IS AN EMPTY LIST, NOT A LIST HOLDING 'null'. PowerShell pipes $null as one
        # item, so `@($null | ForEach-Object {...})` is @('null') -- a phantom entry that is then
        # missing from $after, which the additions-only test below reads as a REMOVAL. A prototype
        # that gains the field from nothing would be reported for a reason that has nothing to do
        # with what it gained. Measured, not assumed: `$null | ForEach-Object` iterates once.
        $rowsBefore = if ($null -eq $b.$field) { @() } else { @($b.$field) }
        $rowsAfter  = if ($null -eq $a.$field) { @() } else { @($a.$field) }
        $tally = {
            param($rows)
            $m = @{}
            foreach ($r in $rows) {
                $k = $r | ConvertTo-Json -Depth 20 -Compress
                if ($m.ContainsKey($k)) { $m[$k]++ } else { $m[$k] = 1 }
            }
            return $m
        }
        $mBefore = & $tally $rowsBefore
        $mAfter  = & $tally $rowsAfter

        # ADDITIONS ONLY, AND AS A MULTISET RATHER THAN A SET. Presence alone was not enough: two
        # identical entries in the baseline and one of them deleted leaves the string still present
        # in the run, so the deletion was invisible and the prototype was excused. Counting closes
        # that for both shapes at once. It catches an EDIT for free -- a reworded entry is a
        # disappearance and a reappearance -- so a set quietly rewriting one of its own rows while
        # appending one of ours fails here rather than riding in on the legitimate addition.
        $lost = @($mBefore.Keys | Where-Object {
            -not $mAfter.ContainsKey($_) -or $mAfter[$_] -lt $mBefore[$_]
        })
        if ($lost) { continue }

        # The SURPLUS occurrences, as objects rather than strings, because the predicates below read
        # their fields. An entry duplicated by the run counts as added on its second occurrence.
        $seen  = @{}
        $added = @()
        foreach ($row in $rowsAfter) {
            $k = $row | ConvertTo-Json -Depth 20 -Compress
            if ($seen.ContainsKey($k)) { $seen[$k]++ } else { $seen[$k] = 1 }
            $allowed = if ($mBefore.ContainsKey($k)) { $mBefore[$k] } else { 0 }
            if ($seen[$k] -gt $allowed) { $added += $row }
        }
        if (-not $added) { continue }

        # ONE PREDICATE PER SHAPE, SELECTED BY THE SHAPE AND NOT BY THE FIELD, so the shape recorded
        # against the key and the test that granted it come from the same place. `default` throws
        # rather than falling through: an `else` here meant a third $SHAPES entry added without its
        # own predicate would silently be judged by another shape's test and printed with a null
        # reason. A missing predicate should stop the run, not quietly borrow one.
        #
        # THE LABEL, which starts as the shape's own name and only a predicate that can tell two
        # stories apart ever refines it. `tooltip` has one story and never touches this.
        $label = $SHAPES[$field]
        $foreign = switch ($SHAPES[$field]) {
            'unlock' {
                # TWO STORIES SHARE THIS SHAPE, and telling them apart is the whole of #191.
                #
                # `unlock` -- the added effect names a recipe Get-SetDerived already attributed to
                # the SET. That is real evidence of authorship: `kr-burn-rf-brine` could not exist
                # unless Krastorio 2 made it.
                #
                # `rehomed` -- the added effect names a barrel recipe BASE FACTORIO generated from a
                # fluid of ours, and the set has moved it onto a technology of its own. bobplates
                # walks data.raw and re-homes every barrel unlock off vanilla `fluid-handling`, so
                # ours go across with vanilla's and every other mod's; the pass names nothing of
                # ours and tests for no prefix of ours.
                #
                # WHY OUR NAME IS NOT THE EVIDENCE HERE, and this is the trap #191 rejected an
                # earlier rule for. A technology of theirs gaining `unlock-recipe rf-brine-barrel` is
                # EQUALLY consistent with the set sweeping our recipe in and with this repo wiring
                # our recipe into their technology. The dump records what a prototype ended up as,
                # never who wrote it, so the two are byte-identical. Testing "the recipe is one of
                # ours" would therefore excuse our own edit to a third party's technology -- and it
                # would also undo Get-SetDerived's deliberate skip of any name carrying the prefix.
                #
                # So the evidence is the SET'S OWN VISIBLE BEHAVIOUR, and both halves are required:
                #
                #   1. the recipe is one base Factorio generates from a fluid of ours -- CONSTRUCTED
                #      as `<fluid>-barrel` and `empty-<fluid>-barrel` from the fluids this repo
                #      defines, rather than matched by pattern. $DERIVED covers only the `empty-`
                #      half, and this file's rule is that a new shape brings a predicate, not a
                #      wider regex. CONSTRUCTING THE NAME IS NOT ENOUGH ON ITS OWN, and the first
                #      version of this made that mistake: it built the pair for all seventeen of
                #      our fluids, but SIX set `auto_barrel = false` and the game generates nothing
                #      for them. That excused twelve names base Factorio never makes -- so a recipe
                #      this repo hand-wrote as `rf-d-d-plasma-barrel`, wired into any third party's
                #      barrelling technology, would have had its `replaces:` suppressed under a
                #      sentence saying base Factorio generated it. Both halves below close it.
                #   2. the destination technology ALREADY CARRIED base-generated barrel unlocks in
                #      the baseline -- judged by the unlocked recipe's declared `category` being
                #      `barrelling` in the baseline dump, not by its name. That is what shows a pass
                #      of theirs was visibly already running before we arrived. A technology with no
                #      such unlock that gains only ours is not a re-homing and is still reported.
                #
                # ponytail: `barrelling` only, which is the narrowest rule covering what has been
                # observed. A set that re-homes WITHOUT recategorising surfaces as a plain
                # `replaces:`, gets read, and earns its own widening then -- which is how both of
                # the stories above were found in the first place.
                $barrels = @{}
                foreach ($f in $OurFluids) {
                    # BASE FACTORIO'S OWN SWITCH, READ FROM THE DUMP rather than re-derived. A fluid
                    # carrying `auto_barrel = false` is one the generation skips, so no barrel recipe
                    # of that name can be the game's. Absent means true, which is the engine's
                    # default and why the test is against $false specifically rather than for $true.
                    $fluid = if ($WithUs.ContainsKey("fluid/$f")) { $WithUs["fluid/$f"] | ConvertFrom-Json }
                             else { $null }
                    if ($null -eq $fluid -or $false -eq $fluid.auto_barrel) { continue }

                    # AND THE EVIDENCE THAT IT ACTUALLY DID, which is stronger than re-implementing
                    # the engine's conditions: the `empty-` half must be a recipe present WITH us and
                    # absent WITHOUT us. That is the one name in the pair `$DERIVED` already
                    # recognises as the game's doing, and it appeared because our fluid did. A
                    # hand-written fill recipe alone cannot satisfy it.
                    if (-not $WithUs.ContainsKey("recipe/empty-$f-barrel"))  { continue }
                    if ($Baseline.ContainsKey("recipe/empty-$f-barrel"))     { continue }

                    $barrels["$f-barrel"]       = $true
                    $barrels["empty-$f-barrel"] = $true
                }
                $barrelHost = 0 -lt @($rowsBefore | Where-Object {
                    $_.type -eq 'unlock-recipe' -and
                    $Baseline.ContainsKey("recipe/$($_.recipe)") -and
                    ($Baseline["recipe/$($_.recipe)"] | ConvertFrom-Json).category -eq 'barrelling'
                }).Count

                # PER ENTRY, NOT ALL-OR-NOTHING (#191). A technology that both re-homes our barrel
                # unlocks and wires in a recipe the set derived from us is fully explained, and
                # rejecting it because two explanations met in one prototype would be wrong. What is
                # all-or-nothing is the verdict: one unexplained addition and the whole key reports.
                $told     = [ordered] @{ 'unlock' = $false; 'rehomed' = $false }
                $rejected = @()
                foreach ($row in $added) {
                    if ($row.type -ne 'unlock-recipe')          { $rejected += $row; continue }
                    if ($SetDerived.ContainsKey($row.recipe))   { $told['unlock']  = $true; continue }
                    if ($barrelHost -and $barrels.ContainsKey($row.recipe)) { $told['rehomed'] = $true; continue }
                    $rejected += $row
                }
                # `unlock+rehomed` when both fired, and the order is fixed by $told rather than by
                # which row happened to come first, so one prototype cannot print two spellings.
                if (-not $rejected) { $label = @($told.Keys | Where-Object { $told[$_] }) -join '+' }
                $rejected
            }
            'tooltip' {
                # WHAT THIS CAN AND CANNOT SEE, because it is a suppression rule and the limit is the
                # point. A row the set generated ABOUT a fluid of ours and a row THIS REPO appended to
                # the set's prototype are byte-identical in the dump: the data records what the
                # prototype ended up as, never who wrote it. So authorship cannot be proved here the
                # way the unlock shape proves it -- an unlock names a prototype of THEIRS that
                # Get-SetDerived already attributed to the set, whereas a tooltip row names a
                # prototype of OURS, which is equally consistent with either author.
                #
                # Two conditions together are the closest available, and both are required:
                #
                #   1. the row NAMES a prototype this repo defines -- embedded in a localised string
                #      the set built, `[fluid=rf-reactor-energy]` in SE's case, rather than sitting in
                #      a field of its own, hence a substring test over the serialised row. Ordinal
                #      and case-sensitive, which is what prototype names are.
                #   2. the row is of a KIND the set already emits on that same prototype -- its
                #      localised key already appears there in the baseline. That is what makes it
                #      another row from an existing generator rather than a row invented on their
                #      entity, and it is the half that keeps a hand-written addition of ours out.
                #
                # ponytail: evidence, not proof, and the ceiling is condition 2. A repo change that
                # appended a row using the set's OWN localised key would still be excused. Nothing in
                # the dump can separate that case; separating it needs a source-level instrument --
                # who called add_custom_tooltip_field -- which does not exist here. If this ever needs
                # to be airtight, that is the upgrade, not a cleverer diff.
                $kinds = @($rowsBefore | ForEach-Object { $_.name } | Sort-Object -Unique)
                @($added | Where-Object {
                    $row = $_ | ConvertTo-Json -Depth 20 -Compress
                    (-not @($OurNames | Where-Object { $row.Contains($_) })) -or ($_.name -notin $kinds)
                })
            }
            default {
                throw ("Get-DerivedWiring: shape '$_' has no predicate, so it would be judged by " +
                       "another shape's test. Add one beside its `$SHAPES entry.")
            }
        }
        if (-not $foreign) { $exempt[$key] = $label }
    }
    # A HASHTABLE, and it disarms two traps an array return carried. `return ,$exempt` would have
    # handed back an array WRAPPING the array, and the caller's @() does not flatten it -- so the one
    # key printed correctly and then failed to match `-notin`, reporting a finding the run had just
    # explained away. An empty array also unrolls to $null on return, which is the trap $Replaced
    # above carries its own note about. A hashtable does neither, and it carries WHICH shape excused
    # each key, which the caller needs in order to say what it found rather than only how many.
    return $exempt
}

function Test-Names {
    <#  The check itself, over a given set of our prototypes. Returns the failures as strings so the
        self-test can assert on them instead of on an exit code it would have to trust.  #>
    param(
        [hashtable] $Ours,
        [hashtable] $References,
        [string[]]  $Replaced = @(),
        [string[]]  $Exempt = @(),
        [string[]]  $AlsoClaimed = @()
    )

    $failures = @()

    foreach ($k in $Replaced) {
        $failures += ("replaces: '$k' already exists in the game and this repo changes it. Adding a " +
                      "prototype beside the game's is coexistence; redefining one silently replaces it.")
    }

    $unprefixed = @($Ours.Keys |
        Where-Object { -not $_.StartsWith($PREFIX, [StringComparison]::Ordinal) -and $_ -notmatch $DERIVED -and $_ -notin $Exempt } |
        Sort-Object)
    foreach ($n in $unprefixed) {
        $failures += "unprefixed: '$n' ($($Ours[$n] -join ', ')) does not start with '$PREFIX' -- ADR 0009"
    }

    # $AlsoClaimed IS NOT COSMETIC, and leaving it out was a hole this file's own comments claimed
    # was covered. The scan used to test $Ours.Keys alone -- the DIFFERENCE between the two dumps.
    # A set that loads after us and redefines one of our names unconditionally puts its version in
    # BOTH dumps, so the name cancels out of the difference and is not in $Ours at all: the harvest
    # finds `rf-brine` in their Lua, and nothing compares it against anything. Our fluid is gone
    # from the game and the run exits 0 saying no name of ours is used by the set.
    #
    # So the caller also passes every prefixed name present in the loaded game, which is the same
    # list as $Ours in a run with no set and therefore changes nothing about the base check.
    $claimed = @{}
    foreach ($n in @($Ours.Keys)) { $claimed[$n] = $Ours[$n] -join ', ' }
    foreach ($n in $AlsoClaimed) { if (-not $claimed.ContainsKey($n)) { $claimed[$n] = 'present in the loaded game' } }

    foreach ($ref in $References.Keys | Sort-Object) {
        $shared = @($claimed.Keys | Where-Object { $References[$ref].Contains($_) } | Sort-Object)
        foreach ($n in $shared) {
            $failures += "collision: '$n' ($($claimed[$n])) is also defined by $ref"
        }
    }
    return $failures
}

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    if ($alsoMods) {
        New-ModJunctions -ModDirectory $modDir -RepoRoot $AlsoModDirectory -Mods $alsoMods
        Write-Host "also loading: $($alsoMods.Count) mod(s) -- $($alsoMods -join ', ')"
    }

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

    # The set gets harvested too, and it is not redundant with loading it.
    #
    # The dumps below catch a name of ours that REPLACES one of theirs, because our definition
    # changes a prototype the baseline already had. They cannot catch the collision running the
    # other way: if the set loads AFTER us and redefines one of our names, its version is what both
    # dumps hold, the name cancels out of the difference, and the whole accident is invisible --
    # our entity is simply gone from the game and nothing says so. The harvest sees that one,
    # because it reads what their Lua NAMES rather than what the game ended up with. Weaker
    # instrument, different blind spot; the two are worth having together.
    foreach ($m in $alsoMods) {
        $path = Join-Path $AlsoModDirectory $m
        $harvested = Get-ReferenceNames -Path $path
        # No per-mod floor here: a set holds mods of every size and RITEG is one small mod, so a
        # floor that suited Krastorio 2 would fail honestly-empty ones. The SET's total is guarded
        # instead, below -- an empty harvest across every mod in it means the scan did not run.
        $scanned["$m (set)"] = $harvested
    }
    if ($alsoMods) {
        $setNames = ($alsoMods | ForEach-Object { $scanned["$_ (set)"].Count } | Measure-Object -Sum).Sum
        if (-not $setNames) {
            throw ("harvested no prototype names at all from the $($alsoMods.Count) mod(s) in " +
                   "$AlsoModDirectory. Either they are not Lua mods or the harvest regex has stopped " +
                   "matching -- both of which would otherwise read as a collision-free pass against them.")
        }
        Write-Host "scanned the set: $setNames candidate names across $($alsoMods.Count) mod(s)"
    }

    # Ours by difference, not by prefix. See METHOD: deriving them from the prefix would assume the
    # thing being checked.
    Write-Host 'dumping with this repo, then without it...'
    $withUs = Get-PrototypeNames -Mods ($ourMods + $alsoMods) -Tag 'with-us'

    # The junctions have to GO for the baseline, not merely be left out of the mod list. Factorio
    # enables any mod it finds in the mod directory that the list does not mention, so a list that
    # simply omits ours produces a second dump identical to the first -- which then reads as "this
    # repo defines nothing" rather than as a broken baseline. It did.
    Remove-ModJunctions -ModDirectory $modDir
    # THE SET STAYS FOR THE BASELINE, and re-linking it is not optional: Remove-ModJunctions deletes
    # every junction in the directory, ours and theirs alike. Without this the baseline is a plain
    # vanilla dump, so every prototype the set defines lands in the difference as one of OURS --
    # which fails loudly rather than quietly, but for entirely the wrong reason.
    #
    # The baseline is the game WITH the set and WITHOUT us, so the difference is still exactly what
    # this repo adds, and $replaced becomes what this repo changes in the set as well as in vanilla.
    # That second half is the per-set collision check #61 asks for.
    if ($alsoMods) { New-ModJunctions -ModDirectory $modDir -RepoRoot $AlsoModDirectory -Mods $alsoMods }
    $withoutUs = Get-PrototypeNames -Mods $alsoMods -Tag 'without-us'

    # EVIDENCE THAT THE SET LOADED, WHICH IS NOT THE SAME AS A GUARD -- and it is worth saying why
    # there is no guard, because the obvious one is dead code.
    #
    # The worry is real in shape: $alsoMods is a list of DIRECTORY names, and a set that is skipped
    # is skipped in BOTH dumps, so the difference is identical to a run with no set at all and the
    # closing line would still claim "none is used by the 46-mod set". A check that can quietly not
    # run is worse than no check, which is why every other scan here carries a floor.
    #
    # But Factorio already refuses both ways a mod can fail to load, and it refuses by EXITING,
    # which Get-PrototypeNames turns into a throw before any of this is reached. Measured on 2.0.77
    # rather than assumed -- a mod declaring factorio_version 2.1 gives *"Incompatible Factorio
    # version (current: 2.0, required: 2.1)"*, and a directory whose name disagrees with its
    # info.json gives *"Directory name of mod ... doesn't match the expected <name> (case
    # sensitive!)"*. Both exit 1 with a better message than anything written here would produce.
    # A guard on top of that could only fire when every mod in the set defines no prototypes, which
    # is a set with nothing to check.
    #
    # So this reports instead. The number is the honest form of the reassurance: a mod with no .lua
    # at all is an assets mod -- Krastorio2Assets is 376 MB of sprites and not one Lua file, and
    # every family ships graphics mods of that shape -- while a mod with a full harvest and nothing
    # in the dump is not, and is worth a look. Failing on the first would have failed the Krastorio 2
    # lane immediately and most of the others on their graphics mods.
    if ($alsoMods) {
        $baselineNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($k in $withoutUs.Keys) { [void] $baselineNames.Add(($k -split '/', 2)[1]) }

        $visible = @()
        $silent  = @()
        foreach ($m in $alsoMods) {
            if (@($scanned["$m (set)"] | Where-Object { $baselineNames.Contains($_) })) { $visible += $m }
            else { $silent += "$m ($($scanned["$m (set)"].Count) name(s) harvested)" }
        }
        Write-Host "the set loaded: $($visible.Count) of $($alsoMods.Count) mod(s) put prototypes in the baseline dump"
        if ($silent) { Write-Host "  contributed none the dump can see: $($silent -join ', ')" }
    }

    $ours = Get-OurNames -WithUs $withUs -Baseline $withoutUs
    if ($ours.Count -eq 0) {
        throw 'the two dumps differ by nothing, so this repo appears to define no prototypes at all. That is not a pass.'
    }
    # @() BECAUSE AN EMPTY ARRAY UNROLLS TO $null ON RETURN -- the third instance of this trap in
    # this change, and the one with teeth. Get-Replaced returning nothing is the HEALTHY result: it
    # means this repo changes no prototype of the set's. But $replaced was then $null rather than
    # @(), and Get-DerivedWiring's Mandatory [string[]] refuses null, so every lane where nothing is
    # replaced died with "Cannot bind argument to parameter 'Replaced' because it is null".
    # Krastorio 2 hid it completely: its flare-stack generation replaces exactly one technology, so
    # the only lane ever run had a one-element array. riteg and fluid both replace nothing and both
    # crashed. AllowEmptyCollection on the parameter is not enough on its own -- it permits an empty
    # COLLECTION, not $null -- so the array is made real here, at the source.
    $replaced = @(Get-Replaced -WithUs $withUs -Baseline $withoutUs)
    # The derived count is printed rather than quietly excused: it is an exception to ADR 0009 and a
    # jump in it means the game started generating something new from our prototypes.
    # Not $derived: that is $DERIVED to PowerShell, and assigning the list here would overwrite the
    # pattern before Test-Names below ever reads it. Same trap as $REFERENCE_MODS above, and it bit
    # here too.
    $derivedNames = @($ours.Keys | Where-Object { $_ -match $DERIVED })
    Write-Host ("the difference is {0} prototype name(s) the game does not have; {1} of them are barrel recipes base Factorio named." -f
        $ours.Count, $derivedNames.Count)
    # WHICH DECLARED EDITS FIRED, rather than how many are declared -- see Get-FiredEdits above for
    # what the old wording got wrong and which lane found it.
    #
    # @() FOR THE REASON $replaced HAS IT, twelve lines up: a bare return of an empty array unrolls
    # to $null, and the healthy case here is zero. Without it .Count below is $null rather than 0.
    #
    # Named as well as counted, because "1 fired" and "which one" are different questions and the
    # list is one entry long.
    $firedEdits = @(Get-FiredEdits -Declared $ALLOWED_EDITS -WithUs $withUs -Baseline $withoutUs)
    Write-Host ("it changes {0} prototype(s) the game already defines, beyond what `$ALLOWED_EDITS declares." -f
        $replaced.Count)
    Write-Host ("of the {0} declared edit(s), {1} fired{2}." -f
        $ALLOWED_EDITS.Count, $firedEdits.Count,
        $(if ($firedEdits.Count) { ' -- ' + ($firedEdits -join ', ') } else { '' }))

    # What the SET made out of us, told apart from what we made. Counted and named rather than
    # waived: a jump here means the set started generating something new from this repo's
    # prototypes, which is worth seeing even though it is not a failure.
    $setDerived    = @{}
    $derivedWiring = @{}
    if ($alsoMods) {
        $setDerived = Get-SetDerived -Ours $ours
        if ($setDerived.Count) {
            $byPrefix = $setDerived.Keys |
                Group-Object { ($_ -split [regex]::Escape($setDerived[$_]), 2)[0] } |
                Sort-Object Count -Descending
            Write-Host ("of those, {0} are the SET's own prototypes generated from ours -- {1}" -f
                $setDerived.Count, (($byPrefix | ForEach-Object { "$($_.Count)x '$($_.Name)<ours>'" }) -join ', '))
        }
        # THE FLUIDS SEPARATELY FROM THE NAMES, because the re-homed predicate builds barrel recipe
        # names out of them and $ours.Keys has already thrown the type away. `fluid` is the type
        # Factorio dumps them under, and $ours maps each name to every type it appears as.
        $ourFluids = @($ours.GetEnumerator() |
            Where-Object { $_.Value -contains 'fluid' } |
            ForEach-Object { $_.Key })
        $derivedWiring = Get-DerivedWiring -Replaced $replaced -WithUs $withUs -Baseline $withoutUs `
                            -SetDerived $setDerived -OurNames @($ours.Keys) -OurFluids $ourFluids
        foreach ($k in @($derivedWiring.Keys | Sort-Object)) {
            # ONE SENTENCE PER LABEL, ENDING INCLUDED. The tail used to be shared -- "so it is the
            # set wiring its own derivations in" -- and that sentence is FALSE of a re-homing: the
            # recipe was generated by base Factorio, not by the set. Printing the wrong story on the
            # one line a reader sees would undo the distinction the label exists to draw (#191).
            $what = switch ($derivedWiring[$k]) {
                'unlock' {
                    'gains only unlock-recipe effects for recipes the set derived from ours, so it ' +
                    'is the set wiring its own derivations in'
                }
                'rehomed' {
                    'gains only barrel unlocks base Factorio generated from our fluids, onto a ' +
                    'technology that already carried such unlocks, so it is the set re-homing them'
                }
                'unlock+rehomed' {
                    'gains only recipes the set derived from ours and barrel unlocks base Factorio ' +
                    'generated from our fluids, so it is the set both wiring and re-homing'
                }
                'tooltip' {
                    'gains only tooltip rows of a kind it already had, naming ours, so it is the ' +
                    'set describing our prototypes'
                }
                default { "gains only wiring classified '$_'" }
            }
            Write-Host ("  '$k' $what rather than this repo replacing it.")
        }
        $replaced = @($replaced | Where-Object { -not $derivedWiring.ContainsKey($_) })
    }

    # Every prefixed name the game ended up with, not only the ones in the difference -- see
    # Test-Names' $AlsoClaimed. Identical to $ours' prefixed half when no set is loaded.
    $inGame = @($withUs.Keys |
        ForEach-Object { ($_ -split '/', 2)[1] } |
        Where-Object { $_.StartsWith($PREFIX, [StringComparison]::Ordinal) } |
        Sort-Object -Unique)

    $failures = Test-Names -Ours $ours -References $scanned -Replaced $replaced `
        -Exempt @($setDerived.Keys) -AlsoClaimed $inGame

    if ($SelfTest) {
        # Half one: the repo as it stands must pass, or halves two and three prove nothing.
        if ($failures) {
            Write-Host 'FAILED - self-test: the repo as it stands does not pass, so a caught canary would prove nothing.'
            foreach ($f in $failures) { Write-Host "    $f" }
            exit 1
        }
        Write-Host 'self-test 1/6: the repo as it stands passes.'

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
        Write-Host 'self-test 2/6: an unprefixed name is caught.'

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
        Write-Host 'self-test 3/6: a name a reference mod already uses is caught.'

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
        Write-Host 'self-test 4/6: a real mod adding an unprefixed name and replacing a vanilla prototype is caught.'

        # Half five: the two classifiers -AlsoModDirectory relies on, and specifically the LIMITS of
        # what they excuse.
        #
        # These are the only code here that SUPPRESSES a finding, which makes them the code most
        # worth pinning: an over-broad rule turns a real collision into a counted line and the run
        # still exits 0. They are pure functions over parsed sets, so this half needs no third-party
        # mod and no further dump -- the same reason halves two and three inject rather than build.
        #
        # The positive cases are taken from a REAL measurement rather than invented: Krastorio 2
        # 2.0.19 generates kr-burn-<fluid> and kr-crush-<item> from this repo's prototypes and
        # appends the unlocks into its own technology/kr-fluid-excess-handling. Four negatives sit
        # beside them, one per way the rule could be too generous.
        $ourName    = 'rf-brine'
        $setName    = 'kr-burn-rf-brine'
        # TWO of the set's, sharing a marker, because one is not a generator -- see Get-SetDerived.
        # `fill-rf-brine-barrel` is the singleton that must NOT be excused: it is the shape one of
        # OUR unprefixed names would have, and it embeds a name of ours exactly as the set's do.
        $fake = @{
            $ourName                = @('fluid')
            'rf-deuterium'          = @('fluid')
            $setName                = @('recipe')
            'kr-burn-rf-deuterium'  = @('recipe')
            'fill-rf-brine-barrel'  = @('recipe')
            'fusion-reactor'        = @('reactor')
        }
        $classified = Get-SetDerived -Ours $fake

        if (-not $classified.ContainsKey($setName)) {
            Write-Host "FAILED - self-test: '$setName' was not recognised as the set's own prototype built from ours."
            exit 1
        }
        if ($classified[$setName] -ne $ourName) {
            Write-Host "FAILED - self-test: '$setName' was attributed to '$($classified[$setName])', not '$ourName'."
            exit 1
        }
        # THE NEGATIVE THAT MATTERS MOST. An unprefixed name of ours embeds no name of ours, so it
        # must survive the classifier -- otherwise the ADR 0009 check has a hole exactly the width
        # of this feature.
        if ($classified.ContainsKey('fusion-reactor')) {
            Write-Host 'FAILED - self-test: an unprefixed name of ours was excused as the set''s derivation,'
            Write-Host '         which would hide the one failure this whole check exists to catch.'
            exit 1
        }
        # THE NEGATIVE THE FIRST ONE DOES NOT REACH. `fusion-reactor` embeds no name of ours, so it
        # would survive a classifier keyed on embedding alone. A singleton that DOES embed one is
        # the case that separates "the set generated it" from "we misnamed it".
        if ($classified.ContainsKey('fill-rf-brine-barrel')) {
            Write-Host 'FAILED - self-test: a lone unprefixed name embedding one of ours was excused as the'
            Write-Host '         set''s derivation. A generator generates more than one; this is the shape'
            Write-Host '         one of OUR unprefixed names would have.'
            exit 1
        }
        if (Test-Names -Ours $fake -References @{} -Exempt @($classified.Keys) |
                Where-Object { $_ -like "unprefixed: '$setName'*" }) {
            Write-Host "FAILED - self-test: '$setName' was classified but still reported as unprefixed."
            exit 1
        }
        if (-not (Test-Names -Ours $fake -References @{} -Exempt @($classified.Keys) |
                Where-Object { $_ -like "unprefixed: 'fill-rf-brine-barrel'*" })) {
            Write-Host "FAILED - self-test: the lone 'fill-rf-brine-barrel' was not reported as unprefixed."
            exit 1
        }

        # AND THE COLLISION THE DIFFERENCE LOSES. A set that redefines one of our names
        # unconditionally holds it in both dumps, so it is absent from $Ours -- passing it in
        # $AlsoClaimed is the only reason the scan can still see it.
        $harvest = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        [void] $harvest.Add('rf-eaten-by-the-set')
        $swallowed = Test-Names -Ours @{} -References @{ 'the set' = $harvest } -AlsoClaimed @('rf-eaten-by-the-set')
        if (-not ($swallowed | Where-Object { $_ -like "collision: 'rf-eaten-by-the-set'*" })) {
            Write-Host 'FAILED - self-test: a name of ours that the set redefines in BOTH dumps -- so it never'
            Write-Host '         reaches the difference -- was not caught by the scan. That is the direction'
            Write-Host '         the dumps cannot see, and the only one the harvest is there for.'
            exit 1
        }
        if (Test-Names -Ours @{} -References @{ 'the set' = $harvest }) {
            Write-Host 'FAILED - self-test: a reference harvest with nothing claimed against it still reported.'
            exit 1
        }

        # And the two wiring shapes, each with its negatives. The unlock half first.
        $tech    = 'technology/kr-fluid-excess-handling'
        $before  = @{ name = 'kr-fluid-excess-handling'; effects = @(@{ type = 'unlock-recipe'; recipe = 'kr-burn-water' }) }
        $wired   = @{ name = 'kr-fluid-excess-handling'; effects = @(
                        @{ type = 'unlock-recipe'; recipe = 'kr-burn-water' }
                        @{ type = 'unlock-recipe'; recipe = $setName }) }
        $foreign = @{ name = 'kr-fluid-excess-handling'; effects = @(
                        @{ type = 'unlock-recipe'; recipe = 'kr-burn-water' }
                        @{ type = 'unlock-recipe'; recipe = 'kr-something-of-theirs' }) }
        $renamed = @{ name = 'ours-now'; effects = @(@{ type = 'unlock-recipe'; recipe = 'kr-burn-water' }) }
        $dropped = @{ name = 'kr-fluid-excess-handling'; effects = @() }

        # THE TOOLTIP HALF (#129), and the fixtures are the shape SE really produced: a row per
        # non-hidden fuel fluid, the name embedded in a localised string rather than in a field.
        # $tipOurs is the measured case -- one row of theirs kept untouched, one row of ours appended.
        $ourFluid   = 'rf-reactor-energy'
        $gen        = 'generator/se-fluid-burner-generator'
        $theirRow   = @{ name = 'description.fluid-consumption'; value = @('', '[fluid=se-antimatter-stream]', ' ', '60', 'per-second-suffix') }
        $ourRow     = @{ name = 'description.fluid-consumption'; value = @('', "[fluid=$ourFluid]", ' ', '30', 'per-second-suffix') }
        $tipBefore  = @{ name = 'se-fluid-burner-generator'; efficiency = 1; custom_tooltip_fields = @($theirRow) }
        $tipOurs    = @{ name = 'se-fluid-burner-generator'; efficiency = 1; custom_tooltip_fields = @($theirRow, $ourRow) }
        # A row naming a fluid of THEIRS that the baseline did not have. Nothing to do with us, so
        # it must not be excused just because the field is the right one.
        $tipTheirs  = @{ name = 'se-fluid-burner-generator'; efficiency = 1; custom_tooltip_fields = @(
                        $theirRow
                        @{ name = 'description.fluid-consumption'; value = @('', '[fluid=se-something-of-theirs]', ' ', '30', 'per-second-suffix') }) }
        $tipDropped = @{ name = 'se-fluid-burner-generator'; efficiency = 1; custom_tooltip_fields = @($ourRow) }
        # THE ONE THAT MATTERS MOST: our row appended AND a row of theirs reworded in the same diff.
        # An additions-only test that compared counts, or that stopped at "one of the added rows is
        # ours", would wave this through -- and it is a real edit to a prototype of theirs.
        $tipEdited  = @{ name = 'se-fluid-burner-generator'; efficiency = 1; custom_tooltip_fields = @(
                        @{ name = 'description.fluid-consumption'; value = @('', '[fluid=se-antimatter-stream]', ' ', '99', 'per-second-suffix') }
                        $ourRow) }
        # And the field allow-list, from the tooltip side: rows identical, something else changed.
        $tipOther   = @{ name = 'se-fluid-burner-generator'; efficiency = 0.5; custom_tooltip_fields = @($theirRow) }
        # THE DE-DUPLICATION CASE (#129 review). Two identical rows of theirs, one deleted, one of
        # ours appended. A presence test sees their row still there and excuses the lot; only a
        # multiset sees the loss. The fixture is the whole reason the counting exists.
        $tipDupBase = @{ name = 'se-fluid-burner-generator'; efficiency = 1; custom_tooltip_fields = @($theirRow, $theirRow) }
        $tipDeduped = @{ name = 'se-fluid-burner-generator'; efficiency = 1; custom_tooltip_fields = @($theirRow, $ourRow) }
        # A row of a KIND the prototype did not have. It names a fluid of ours, so condition 1 passes
        # and condition 2 must reject it: an invented row on their entity is what this repo appending
        # to a third-party prototype looks like, and it must not be excused as their generator.
        $tipNewKind = @{ name = 'se-fluid-burner-generator'; efficiency = 1; custom_tooltip_fields = @(
                        $theirRow
                        @{ name = 'description.rf-something-of-ours'; value = @('', "[fluid=$ourFluid]") }) }
        # No tooltip field at all in the baseline, so there is no kind to match and no generator of
        # theirs demonstrably at work. Reported, and the run must reach that verdict on condition 2
        # rather than on the phantom 'null' entry an absent field used to serialise to.
        $tipNoBase  = @{ name = 'se-fluid-burner-generator'; efficiency = 1 }
        # The same absent-field shape on the UNLOCK side, where it IS a wiring: a technology of
        # theirs that had no effects at all gains one, for a recipe the set derived from us. This is
        # the case the phantom entry silently reported, and it must be excused.
        $techNoBase = @{ name = 'kr-fluid-excess-handling' }
        $techGained = @{ name = 'kr-fluid-excess-handling'; effects = @(@{ type = 'unlock-recipe'; recipe = $setName }) }

        # THE RE-HOMED HALF (#192, decided on #191), and the fixtures are the shape bobplates really
        # produces: a technology of the SET's that already carries base Factorio's barrel unlocks,
        # gaining the ones base Factorio generated from OUR fluids. Nothing here is named by us and
        # nothing here is generated by the set -- which is exactly why the unlock predicate alone
        # declines it, and why our own names cannot be the evidence that excuses it.
        $bobTech    = 'technology/bob-fluid-barrel-processing'
        # The category lives on the RECIPE, not on the effect, so the baseline dump has to be
        # consulted for it. Two vanilla barrel recipes and one non-barrel recipe of theirs, so a
        # test that merely found SOME recipe in the baseline would not pass by accident.
        $barrelBase = @{
            'recipe/water-barrel'       = '{"name":"water-barrel","category":"barrelling"}'
            'recipe/empty-water-barrel' = '{"name":"empty-water-barrel","category":"barrelling"}'
            'recipe/bob-alloy'          = '{"name":"bob-alloy","category":"crafting"}'
        }
        # CONDITION 1'S OWN EVIDENCE, and it has to live in the WITH-US dump rather than the
        # baseline: the fluid, so its `auto_barrel` can be read, and the `empty-` recipe, whose
        # appearance is what shows base Factorio actually barrelled it. Three fluids, because the
        # rule has three answers -- one barrelled, one the game skips, and one that claims to be
        # barrelled but whose recipe never appeared.
        $ourFluidB    = 'rf-brine'
        $ourPlasma    = 'rf-d-d-plasma'      # auto_barrel = false, so the game generates nothing
        $ourUnbottled = 'rf-nothing-barrels' # no `empty-` recipe in the dump at all
        $barrelWith = @{
            "fluid/$ourFluidB"                 = '{"name":"rf-brine"}'
            "recipe/empty-$ourFluidB-barrel"   = '{"name":"empty-rf-brine-barrel","category":"barrelling"}'
            "recipe/$ourFluidB-barrel"         = '{"name":"rf-brine-barrel","category":"barrelling"}'
            "fluid/$ourPlasma"                 = '{"name":"rf-d-d-plasma","auto_barrel":false}'
            # PRESENT ON PURPOSE. The pair exists under the plasma's name -- which is what this repo
            # hand-writing one would look like -- so only `auto_barrel` can decline it, and the case
            # below proves that it does rather than the presence test doing the work.
            "recipe/empty-$ourPlasma-barrel"   = '{"name":"empty-rf-d-d-plasma-barrel","category":"barrelling"}'
            "recipe/$ourPlasma-barrel"         = '{"name":"rf-d-d-plasma-barrel","category":"barrelling"}'
            "fluid/$ourUnbottled"              = '{"name":"rf-nothing-barrels"}'
            "recipe/$ourUnbottled-barrel"      = '{"name":"rf-nothing-barrels-barrel","category":"barrelling"}'
        }
        $vanillaFill  = @{ type = 'unlock-recipe'; recipe = 'water-barrel' }
        $vanillaEmpty = @{ type = 'unlock-recipe'; recipe = 'empty-water-barrel' }
        $oursFill     = @{ type = 'unlock-recipe'; recipe = "$ourFluidB-barrel" }
        $oursEmpty    = @{ type = 'unlock-recipe'; recipe = "empty-$ourFluidB-barrel" }
        $bobBefore  = @{ name = 'bob-fluid-barrel-processing'; effects = @($vanillaFill, $vanillaEmpty) }
        $bobRehomed = @{ name = 'bob-fluid-barrel-processing'; effects = @($vanillaFill, $vanillaEmpty, $oursFill, $oursEmpty) }
        # MIXED, and it must pass reporting BOTH stories. A technology that both re-homes our barrel
        # unlocks and wires in a recipe the set derived from us is fully explained; rejecting it
        # because two explanations met in one prototype would be wrong, and printing only one of them
        # would tell the reader half the truth on the single line they see.
        $bobMixed   = @{ name = 'bob-fluid-barrel-processing'; effects = @(
                        $vanillaFill, $vanillaEmpty, $oursFill
                        @{ type = 'unlock-recipe'; recipe = $setName }) }
        # A BARREL UNLOCK THAT IS NOT BUILT FROM A FLUID OF OURS. `bob-lubricant` is not in
        # $OurFluids, so nothing here constructed that name and the row is a plain replacement.
        $bobNotOurs = @{ name = 'bob-fluid-barrel-processing'; effects = @(
                        $vanillaFill, $vanillaEmpty
                        @{ type = 'unlock-recipe'; recipe = 'bob-lubricant-barrel' }) }
        # CONDITION 2 SAYING NO. The same added unlocks, onto a technology whose baseline carried no
        # barrelling unlock at all -- so no pass of theirs is visibly already running, and the only
        # thing left pointing at an author is our name, which #191 rejected as evidence.
        $plainTech   = 'technology/bob-something-else'
        $plainBefore = @{ name = 'bob-something-else'; effects = @(@{ type = 'unlock-recipe'; recipe = 'bob-alloy' }) }
        $plainGained = @{ name = 'bob-something-else'; effects = @(
                        @{ type = 'unlock-recipe'; recipe = 'bob-alloy' }
                        $oursFill, $oursEmpty) }
        # A DIFF THAT IS NOT ONLY ADDED UNLOCKS, on the re-homed shape rather than the wiring one:
        # the barrel unlocks arrive AND a second field moves. The field allow-list must still bite.
        $bobOther   = @{ name = 'bob-fluid-barrel-processing'; unit = 42; effects = @($vanillaFill, $vanillaEmpty, $oursFill, $oursEmpty) }
        # AN EFFECT REMOVED beside the re-homed additions. Their own unlock disappears while ours
        # arrive, which is an edit to their technology however well-explained the additions are.
        $bobDropped = @{ name = 'bob-fluid-barrel-processing'; effects = @($vanillaFill, $oursFill, $oursEmpty) }
        # A FLUID THE GAME DOES NOT BARREL. `auto_barrel = false`, so nothing named
        # `rf-d-d-plasma-barrel` can be base Factorio's however plausible the name looks -- and the
        # fixture puts BOTH halves of the pair in the dump, so the presence test passes and only the
        # engine's own switch is left to decline it. This is the case the first version of the rule
        # got wrong for all six of our unbarrelled fluids.
        $bobPlasma  = @{ name = 'bob-fluid-barrel-processing'; effects = @(
                        $vanillaFill, $vanillaEmpty
                        @{ type = 'unlock-recipe'; recipe = "$ourPlasma-barrel" }
                        @{ type = 'unlock-recipe'; recipe = "empty-$ourPlasma-barrel" }) }
        # AND THE OTHER HALF OF CONDITION 1: a fluid with no `empty-` recipe anywhere in the dump, so
        # there is no evidence the game barrelled it, whatever its `auto_barrel` says. A lone fill
        # recipe under a constructed name is what a hand-written one looks like.
        $bobUnbot   = @{ name = 'bob-fluid-barrel-processing'; effects = @(
                        $vanillaFill, $vanillaEmpty
                        @{ type = 'unlock-recipe'; recipe = "$ourUnbottled-barrel" }) }

        $j = { param($o) $o | ConvertTo-Json -Depth 100 -Compress }

        $cases = @(
            @{ Label = 'the set wiring its own derivation in';       Key = $tech; Before = $before; After = $wired;   Exempt = $true; Shape = 'unlock' }
            @{ Label = 'an unlock for a recipe that is NOT ours';    Key = $tech; Before = $before; After = $foreign; Exempt = $false }
            @{ Label = 'a field other than effects changing';        Key = $tech; Before = $before; After = $renamed; Exempt = $false }
            @{ Label = 'an effect being REMOVED';                    Key = $tech; Before = $before; After = $dropped; Exempt = $false }
            @{ Label = 'a tooltip row naming a fluid of ours';       Key = $gen;  Before = $tipBefore; After = $tipOurs;    Exempt = $true; Shape = 'tooltip' }
            @{ Label = 'a tooltip row naming nothing of ours';       Key = $gen;  Before = $tipBefore; After = $tipTheirs;  Exempt = $false }
            @{ Label = 'a tooltip row being REMOVED';                Key = $gen;  Before = $tipBefore; After = $tipDropped; Exempt = $false }
            @{ Label = 'a row of theirs REWORDED beside ours';       Key = $gen;  Before = $tipBefore; After = $tipEdited;  Exempt = $false }
            @{ Label = 'a field other than the tooltips changing';   Key = $gen;  Before = $tipBefore; After = $tipOther;   Exempt = $false }
            @{ Label = 'a DUPLICATE row of theirs de-duplicated';    Key = $gen;  Before = $tipDupBase; After = $tipDeduped; Exempt = $false }
            @{ Label = 'a row of a kind the prototype did not have'; Key = $gen;  Before = $tipBefore;  After = $tipNewKind; Exempt = $false }
            @{ Label = 'a tooltip field appearing from nothing';     Key = $gen;  Before = $tipNoBase;  After = $tipOurs;    Exempt = $false }
            @{ Label = 'an effects field appearing from nothing';    Key = $tech; Before = $techNoBase; After = $techGained; Exempt = $true; Shape = 'unlock' }
            @{ Label = 'our barrel unlocks re-homed onto their tech'; Key = $bobTech; Before = $bobBefore; After = $bobRehomed; Exempt = $true; Shape = 'rehomed' }
            @{ Label = 'a re-homing AND a wiring in one technology';  Key = $bobTech; Before = $bobBefore; After = $bobMixed;   Exempt = $true; Shape = 'unlock+rehomed' }
            @{ Label = 'a barrel unlock built from no fluid of ours'; Key = $bobTech;   Before = $bobBefore;   After = $bobNotOurs;  Exempt = $false }
            @{ Label = 'our barrel unlocks onto a NON-barrel tech';   Key = $plainTech; Before = $plainBefore; After = $plainGained; Exempt = $false }
            @{ Label = 'a re-homing with another field changed';      Key = $bobTech;   Before = $bobBefore;   After = $bobOther;    Exempt = $false }
            @{ Label = 'a re-homing with an effect REMOVED';          Key = $bobTech;   Before = $bobBefore;   After = $bobDropped;  Exempt = $false }
            @{ Label = 'barrels named for a fluid the game skips';   Key = $bobTech;   Before = $bobBefore;   After = $bobPlasma;   Exempt = $false }
            @{ Label = 'a barrel whose empty- half never appeared';  Key = $bobTech;   Before = $bobBefore;   After = $bobUnbot;    Exempt = $false }
        )
        # THE EMPTY CASE FIRST, because it is the one a real lane hits most and the one the K2 lane
        # could never reach. Nothing replaced is what a clean coexistence result looks like.
        $none = Get-DerivedWiring -Replaced @() -WithUs @{} -Baseline @{} -SetDerived @{} -OurNames @() -OurFluids @()
        if ($none.Count -ne 0) {
            Write-Host "FAILED - self-test: an empty `$Replaced returned $($none.Count) exemption(s)."
            exit 1
        }
        # AND THE SHAPE THAT ACTUALLY BIT: Get-Replaced's empty result unrolls to $null on return,
        # so the caller must hand this an array it made real itself. Proving the parameter tolerates
        # @() while the real call site could still pass $null is how this was missed the first time.
        $rawEmpty = Get-Replaced -WithUs @{} -Baseline @{}
        if ($null -ne $rawEmpty) {
            Write-Host 'FAILED - self-test: Get-Replaced no longer unrolls an empty result to $null,'
            Write-Host '         so the @() at its call site may have been dropped as redundant. It is not.'
            exit 1
        }
        if ((@($rawEmpty)).Count -ne 0) {
            Write-Host 'FAILED - self-test: @() around an empty Get-Replaced result is not an empty array.'
            exit 1
        }

        foreach ($c in $cases) {
            $k   = $c.Key
            # THE BASELINE IS THE WHOLE DUMP, not just the prototype under test. The re-homed
            # predicate reads each baseline unlock's RECIPE out of it to find the category, so a
            # fixture holding only the technology would make condition 2 unsatisfiable and every
            # re-homing would report -- a green proving the opposite of what it claimed.
            $base = @{ $k = (& $j $c.Before) }
            foreach ($r in $barrelBase.GetEnumerator()) { $base[$r.Key] = $r.Value }
            # THE WITH-US DUMP CARRIES CONDITION 1'S EVIDENCE, so it needs the same treatment the
            # baseline got: the fluids and their generated recipes, not just the prototype under
            # test. A fixture holding only the technology would make condition 1 unsatisfiable and
            # every re-homing would report -- green for the opposite of the stated reason.
            #
            # NOT $with: THAT IS THE SCRIPT'S OWN `-With` PARAMETER, and it is declared `[string[]]`.
            # PowerShell keeps a parameter's type constraint on the variable, so assigning a
            # hashtable to it does not shadow it -- it COERCES, and the dump silently became a string
            # array. The next line then indexed an array with a prototype key and died with "Cannot
            # convert value 'recipe/rf-d-d-plasma-barrel' to type System.Int32". Fourth time this
            # file has been bitten by a name already taken at script scope; see $REFERENCE_MODS,
            # $derivedNames and $derived above.
            $withDump = @{ $k = (& $j $c.After) }
            foreach ($r in $barrelWith.GetEnumerator()) { $withDump[$r.Key] = $r.Value }
            $got = Get-DerivedWiring -Replaced @($k) -WithUs $withDump `
                        -Baseline $base -SetDerived $classified -OurNames @($ourFluid) `
                        -OurFluids @($ourFluidB, $ourPlasma, $ourUnbottled)
            $was = [bool] $got.ContainsKey($k)
            if ($was -ne $c.Exempt) {
                Write-Host "FAILED - self-test: $($c.Label) was $(if ($was) { 'excused' } else { 'reported' }), expected the opposite."
                exit 1
            }
            # The SHAPE is asserted too, not just the verdict. Both shapes are excused by the same
            # loop, so a dispatch that fell through to the wrong predicate could excuse the right
            # key for the wrong reason -- and the per-key line the caller prints would then say
            # something untrue about what the set did.
            # DECLARED PER CASE rather than inferred from the key, since #192: one key now carries
            # three different right answers -- `rehomed`, `unlock+rehomed`, and reported -- so a
            # rule keyed on the prototype would assert the same thing for all three.
            if ($was -and $got[$k] -ne $c.Shape) {
                Write-Host "FAILED - self-test: $($c.Label) was excused as '$($got[$k])', expected '$($c.Shape)'."
                exit 1
            }
        }
        Write-Host 'self-test 5/6: an empty replacement list binds, and the set-derivation classifiers'
        Write-Host '               excuse what the set built from us and what base Factorio built from'
        Write-Host '               us that the set re-homed, and nothing else -- an unprefixed name of'
        Write-Host '               ours, a LONE one embedding one of ours, an unlock for a recipe that'
        Write-Host '               is not ours, a barrel unlock built from no fluid of ours, one named'
        Write-Host '               for a fluid the game does not barrel, one whose empty- half never'
        Write-Host '               appeared, our barrel unlocks onto a technology that carried none,'
        Write-Host '               a tooltip row naming nothing of ours, a row of theirs reworded'
        Write-Host '               beside ours, a duplicate row of theirs de-duplicated, a row of a'
        Write-Host '               kind the prototype did not have, a changed field and a removed'
        Write-Host '               entry all survive; an effects field appearing from nothing is'
        Write-Host '               still a wiring; a technology that both wires and re-homes passes'
        Write-Host '               and says so; each exemption is checked under the RIGHT label; and'
        Write-Host '               a name the set redefines in both dumps is still caught by the scan.'

        # ---------------------------------------------------------------- half six
        #
        # THE DECLARED-EDIT LINE SAYS WHAT HAPPENED, NOT WHAT IS PERMITTED (#133). The number beside
        # "declared" used to be $ALLOWED_EDITS.Count, so it was the same on every lane and true on
        # none of them in particular. Get-FiredEdits replaced it, and a claim printed to a human is
        # only worth what breaks when it is wrong.
        #
        # SYNTHETIC DUMPS FOR THE FOUR JUDGEMENT CASES, for the reason halves two and three inject
        # into the parsed set rather than building a canary mod: what is under test is this script's
        # judgement, and a controlled pair of hashtables can pose questions a real run does not. Only
        # one of the four -- "differs, so it fired" -- occurs on a clean run at all.
        $fakeWith = @{
            'technology/differs'   = '{"effects":[1,2]}'   # declared, and changed: fired
            'technology/unchanged' = '{"effects":[1]}'     # declared, identical: the Bob's shape
            'technology/ours-only' = '{"effects":[1]}'     # declared, absent from the baseline
            'technology/undeclared' = '{"effects":[9]}'    # changed, but nobody declared it
        }
        $fakeBase = @{
            'technology/differs'   = '{"effects":[1]}'
            'technology/unchanged' = '{"effects":[1]}'
            'technology/undeclared' = '{"effects":[8]}'
        }
        $fakeDeclared = @('technology/differs', 'technology/unchanged', 'technology/ours-only')
        $fired = @(Get-FiredEdits -Declared $fakeDeclared -WithUs $fakeWith -Baseline $fakeBase)

        # Each case named, so a failure says WHICH judgement went wrong rather than that a count
        # moved. A predicate comparing the wrong way round fails the first two together; one reading
        # the wrong dump fails the third; one that forgot to restrict itself to the declared list
        # fails the fourth.
        $wantFired = @(
            @{ Key = 'technology/differs';    Want = $true;
               Why = 'a declared edit whose content changed really did fire' }
            @{ Key = 'technology/unchanged';  Want = $false;
               Why = 'a declared edit identical in both dumps did NOT fire -- the shape the Bob''s lane found' }
            @{ Key = 'technology/ours-only';  Want = $false;
               Why = 'a declared name the baseline does not have is not an edit to it' }
            @{ Key = 'technology/undeclared'; Want = $false;
               Why = 'a changed name nobody declared is Get-Replaced''s business, not this line''s' }
        )
        foreach ($case in $wantFired) {
            $got = $fired -contains $case.Key
            if ($got -ne $case.Want) {
                Write-Host ("FAILED - self-test: Get-FiredEdits {0} '{1}'. Expected: {2}." -f
                    $(if ($got) { 'reported' } else { 'did not report' }), $case.Key, $case.Why)
                exit 1
            }
        }

        # The empty case binds and counts, which is the trap this file has been caught by three
        # times: a bare return of an empty array unrolls to $null, and $null.Count is not 0.
        $noneFired = @(Get-FiredEdits -Declared @() -WithUs $fakeWith -Baseline $fakeBase)
        if ($noneFired.Count -ne 0) {
            Write-Host 'FAILED - self-test: Get-FiredEdits with nothing declared did not come back as an empty array.'
            exit 1
        }

        # AND THE LIVE ANSWER, which is the half the synthetic cases cannot give: it is the only one
        # that would catch the call site being wired to the wrong variables, since a self-test run
        # loads no set and $ALLOWED_EDITS' own comment says exactly one edit is expected there.
        if ($firedEdits.Count -ne 1 -or $firedEdits[0] -ne 'technology/fluid-handling') {
            Write-Host ("FAILED - self-test: on a run with no set loaded, exactly one declared edit " +
                        "should fire and it should be technology/fluid-handling -- base Factorio's " +
                        "barrel generation appending our fluids to it. Got {0}: {1}." -f
                        $firedEdits.Count, ($firedEdits -join ', '))
            exit 1
        }
        Write-Host 'self-test 6/6: the declared-edit line reports what fired rather than what is'
        Write-Host '               permitted -- a declared edit that changed fires, one identical in'
        Write-Host '               both dumps does not, one the baseline lacks does not, an undeclared'
        Write-Host '               change is left to Get-Replaced, nothing declared binds as empty,'
        Write-Host '               and the live run names technology/fluid-handling and only it.'

        Write-Host ''
        Write-Host 'OK - self-test passed: clean repo passes; unprefixed name, borrowed name and a real'
        Write-Host '     mod that adds and replaces are all caught; the set-derivation classifiers'
        Write-Host '     excuse only what the set built from us and the barrel unlocks it re-homed of'
        Write-Host '     ours; and the declared-edit line reports what fired rather than what is'
        Write-Host '     permitted.'
        exit 0
    }

    if ($failures) {
        Write-Host ''
        Write-Host "FAILED - $($failures.Count) name problem(s):"
        foreach ($f in $failures) { Write-Host "    $f" }
        exit 1
    }

    $bundledOn = if ($enabledBundled) { $enabledBundled -join ', ' } else { 'none (base 2.0 only)' }
    $against   = if ($alsoMods) { "Krastorio 2, either predecessor, or the $($alsoMods.Count)-mod set at $AlsoModDirectory" }
                 else           { 'Krastorio 2 or either predecessor' }
    Write-Host ''
    # OURS, not the difference: with a set loaded the difference also holds what the SET generated
    # from us, and calling 47 of Krastorio 2's recipes "names this repo defines" would be wrong in
    # the sentence that is meant to be the answer.
    $mineCount = $ours.Count - $setDerived.Count
    Write-Host "OK - all $mineCount prototype names this repo defines carry '$PREFIX', and none is used by"
    Write-Host "     $against. Bundled enabled: $bundledOn."
    # TWO SENTENCES, EACH PRINTED ONLY IF IT IS TRUE (#192). This was one sentence -- "N names are
    # the set's own prototypes built from ours, and M prototypes of theirs gained only the wiring for
    # THEM" -- which ties the second count to the first. The Bob's lane broke that: it derives
    # NOTHING from us and still has one prototype excused, so the line read "a further 0 name(s) ...
    # and 1 prototype(s) of theirs gained only the wiring for them", where "them" is nothing at all.
    # A re-homing is not wiring for a set-derived name and must not be reported as though it were.
    if ($setDerived.Count -or $derivedWiring.Count) {
        if ($setDerived.Count) {
            Write-Host ("     A further $($setDerived.Count) name(s) in the difference are the SET's own " +
                        'prototypes built from ours.')
        }
        if ($derivedWiring.Count) {
            # BROKEN DOWN BY LABEL, because the counts answer different questions: `unlock` is the
            # set wiring in what it derived, `rehomed` is the set moving what base Factorio derived,
            # and a reader chasing a jump needs to know which one moved.
            $byLabel = @($derivedWiring.Values | Group-Object | Sort-Object Name |
                ForEach-Object { "$($_.Count) $($_.Name)" })
            Write-Host ("     $($derivedWiring.Count) prototype(s) of theirs changed only in ways the set " +
                        "explains: $($byLabel -join ', ').")
        }
    }
    exit 0
}
finally {
    Remove-ModJunctions -ModDirectory $modDir
    if ($KeepTemp) { Write-Host "temp kept at: $temp" }
    else { Remove-TempDirectory -Path $temp -Label 'name-check' }
}

#Requires -Version 7
<#
.SYNOPSIS
    Loads the Realistic Fusion Refreshed mods, creates a map, and enforces the invariants that tie the
    simulation to the prototypes. Exit 0 means they load AND those invariants hold.

.DESCRIPTION
    Creates a throwaway map in an isolated mod directory containing only the game's bundled
    mods plus this repository's three. Exit 0 means every prototype is valid, every dependency
    resolves, and nothing references a prototype that does not exist -- broader coverage than a
    test suite, for the cost of this script.

    IT CAN LOAD THE MODS TWO WAYS, and -FromZips is the one a player is on. By default the
    repository's directories are junctioned in, so the game reads the working tree in place; that is
    fast and it is what every other check here does, but it cannot see a file that resolves through
    a junction and never reaches a zip. -FromZips builds the zips and loads those instead. Which one
    ran is printed, and appears again in the closing line, because a green run of the wrong one is
    worse than no run.

    IT DOES MORE THAN THE DATA STAGE, and the difference matters to anyone editing the
    simulation. Creating a map runs `on_init`, which is where control.lua's check_prototypes()
    fires -- so this script enforces twelve invariants that no amount of prototype validation
    would catch:

      check_fuel_rows()           Every row of reactor-logic's fuel table declares the fields
                                  step() indexes without asking. M.fuels is the documented place
                                  to add a tier, so a row gets written from its neighbours rather
                                  than from the function that reads it -- and a missing field
                                  throws inside on_nth_tick, on a live save, the moment a reactor
                                  of that tier first holds plasma.
      check_reactor_specs()       Every prototype entity-management registers as a reactor has
                                  constants in control.lua's SPECS and an entity prototype to
                                  match. The two lists are written separately on purpose -- one
                                  file decides what a reactor IS, the other what one DOES -- and
                                  a missing spec is a nil index inside on_nth_tick rather than a
                                  refusal to load.
      check_cadence()             UPDATE_INTERVAL against each reactor's electric buffer. A step
                                  spends the whole interval's heating at once, so past twelve
                                  ticks at the shipped 50 MW and 10 MJ the reactor is starved
                                  every step -- silently, since underpowered is a legitimate
                                  state it is meant to have. Over both reactors since #31: the
                                  aneutronic one draws four times as much against four times the
                                  buffer, and nothing else would notice one moving without the
                                  other.
      check_confinement_ladder()  The confinement ladder against the simulation's own temperature
                                  clamp, and against the technology prototypes it names. Research
                                  raises confinement time (#53), and a rung raised far enough
                                  leaves D-D settled AT the clamp -- where its thermometer stops
                                  moving and further research does nothing a player can see. It
                                  settles a full reactor at the top rung to find out, which is why
                                  it costs about 40 ms and why it is here rather than at the data
                                  stage.
      check_plasma_bounds()       The simulation's temperature clamps against every plasma
                                  fluid's declared range. Widen one without the other and the
                                  mod loads perfectly, then throws on a live save the first
                                  time a reactor gets hot.
      check_signal_ceiling()      The simulation's temperature ceiling against what a circuit
                                  signal can carry. check_plasma_bounds above ties the ceiling to
                                  what the FLUID holds; this ties it to what the WIRE reports, and
                                  a ceiling can pass the first and fail the second. It fails
                                  quietly: a signal is a 32-bit integer, so a ceiling past what a
                                  wire carries leaves every reactor reporting one number for ever
                                  while running perfectly. ~~The ceiling is 2e9 BECAUSE of that
                                  integer.~~ Not since #57 rescaled the signal to kilodegrees and
                                  #58 moved the ceiling to 5e9 on physics grounds; the guard is
                                  kept but can no longer fire (ADR 0025).
      check_every_plasma_burns()  Every fluid an rf-plasma-heating recipe produces has a row in
                                  reactor-logic's fuel table. Reachable since #28 removed the
                                  reactor's input filter; without it a plasma no reactor can
                                  burn sits in the box for ever while the reactor reports
                                  itself starved.
      check_collector_boxes()     Which by-product control.lua deposits into which of the
                                  collector's boxes, against the prototype's filters. Swap the
                                  declarations and nothing complains -- the mod loads, the
                                  collector fills, and a player's tritium pipe carries helium-3.
      check_blanket_feed()        That the item a lithium blanket eats exists, that the blanket
                                  has an inventory to be fed into, and that the collector still
                                  carries the tritium box a blanket breeds through. The first
                                  crosses the module seam -- rf-lithium is Core's -- and a rename
                                  there would leave a blanket silently never breeding.
      check_energy_outlets()      Each reactor's energy_fluid against the filter on the box
                                  apply() writes it into, that the fluid carries a fuel_value,
                                  and that something in the game has a box that will accept it.
                                  There are two energy fluids since #31 and they are deliberately
                                  not interchangeable, so writing the wrong one is a rejected
                                  write rather than a crash: every reactor of that kind silently
                                  produces nothing at all.
      check_reactor_companions()  Each reactor has the signals combinator circuit-output derives
                                  from its name. Derived rather than listed so a third reactor
                                  needs no change there -- which is exactly what makes a missing
                                  one a create_entity throw inside the reporting pass.
      check_steam_sinks()         That every tier of ours which makes steam has something inside
                                  its own prerequisite closure that drinks it for electricity. The
                                  other half of the closure rule the rigs enforce: they check a
                                  technology is BUILDABLE, this checks the chain is USABLE at the
                                  far end. rf-heat-exchanger emits 500 C steam and vanilla gates
                                  the only turbine that drinks it behind nuclear-power, so #36's
                                  answer -- rf-d-d-fusion unlocks the turbine itself -- is what
                                  this holds in place. Indifferent to which answer: it wants a
                                  reachable sink, not a particular one.

    The Lua tests cannot see any of these: they know the physics but not the prototypes, and the
    physics is happily insensitive to cadence well past the point the reactor's buffer gives out.
    So editing UPDATE_INTERVAL, buffer_capacity, a plasma's max_temperature, reactor-logic's fuel
    table, the collector's box order or the blanket's inventory is guarded by running the game,
    not by the suite.

    The check-* rigs create maps too, so they run these as a side effect -- and each takes minutes.
    locale-check.ps1 does NOT: it only dumps, never creates, so a pass there says nothing about any
    of this. This is the script that exists to run them, and the one to reach for after touching any
    of the above.

    It then checks that every file the loaded prototypes name is actually on disk, which
    Factorio does not: a headless run loads no sprites, so a prototype naming a missing icon
    validates and exits 0, and the player's game refuses to start on it. That is not
    hypothetical -- it happened, and it is why this half exists. It covers vanilla's own paths
    as well as this repository's, which is the case that actually bit: an icon this repo pointed
    at had been RENAMED in base Factorio, so nothing here was missing and the game still refused
    to start (20f325c).

    It does NOT check locale coverage. Factorio's data stage loads a prototype with no locale
    entry without complaint; the omission only shows in game as "Unknown key". ADR 0010 singles
    that failure out, so it has its own check: scripts/locale-check.ps1. A pass here says nothing
    about it.

    The player's own mod directory is never touched: the repo's mods are junctioned into a
    temporary directory and a mod-list.json is written there.

    Bundled mods (space-age, elevated-rails, quality) live in the game's data/ directory, so they
    load unless explicitly disabled. Disabled by default to get a genuine base-2.0 check
    (ADR 0003, ADR 0008); -With re-enables them.

    PowerShell 7 is required: 5.1's Remove-Item -Recurse follows junctions instead of skipping
    them, which would delete the repo's own source through the links this script creates.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER With
    Bundled mods to enable, e.g. -With space-age. Dependencies are pulled in automatically --
    space-age requires elevated-rails and quality, so naming it alone is enough. Unknown names
    are rejected rather than silently ignored, because a typo would otherwise produce a base-only
    run reported as an expansion pass. Used to discharge ADR 0003's obligation.

.PARAMETER AlsoModDirectory
    A directory of third-party mod directories to load alongside this repo's, e.g. an unpacked
    Krastorio 2 and its dependencies. Every subdirectory holding an info.json is junctioned in and
    enabled; anything else in there is ignored.

    This is ADR 0007's obligation -- coexistence with other mods, Krastorio 2 most of all -- and it
    takes a directory rather than a mod name because there is nothing here that downloads: the mods
    have to be put there first, by git or by hand. Enabling them is the part this script owns.

    Note the version trap. A mod's factorio_version must match the game's major version exactly, so
    Krastorio 2 2.1.x will NOT load next to this repo on 2.0.77 however the mod list is written --
    the 2.0 line (2.0.19) is the one that loads. See docs/research/mod-set-coexistence-targets.md.

    The asset check does not cover the extra mods: Find-MissingAssets only resolves paths for mods
    it is given a directory for, and a third-party mod's graphics are not this repo's to police.

.PARAMETER FromZips
    Build the distributable zips with pack-mods.ps1 and load those, instead of junctioning the
    repository's directories in. This is the packaging path a player installs, and until it is
    exercised nothing here has ever opened one of these zips.

    The zips are built into the run's own temporary directory rather than taken from dist/, so the
    check always tests what the working tree currently makes. A dist/ zip can be older than the code
    beside it, and a stale artefact reported as a pass is the failure this mode exists to prevent.

    The asset check follows the mods. Find-MissingAssets resolves against the UNPACKED zips, not
    against the repository, so a sprite that is referenced but absent from the archive is caught --
    which is the whole point, and is not something junction mode can tell you. Since ADR 0023 those
    references cross a mod boundary, so there is now a seam for one to fall through.

.PARAMETER SelfTest
    Verify the check can fail. Three halves: the repo as it stands must pass; a mod carrying an
    invalid prototype must fail; and a mod naming an icon file that does not exist must be
    caught. The first is required or the others prove nothing, since Factorio also exits non-zero
    when the repo is genuinely broken. The third is the one Factorio itself exits 0 on. Run this
    whenever the script changes.

    WITH -FromZips it runs a different self-test, because zip mode has a different way of passing
    while proving nothing. Wire the asset check's directory map back at the repository and every
    sprite resolves against the working tree, so the run reports a clean pass over an archive it
    never opened -- and it would keep doing so for as long as the repo and the zip agreed, which is
    almost always. That half packs, then deletes one PNG from the UNPACKED archive and requires it
    to be reported: invisible if the check is looking at the repository, caught if it is looking at
    the zip. The two self-tests do not overlap and both are worth running.

.PARAMETER KeepTemp
    Keep the temporary save and captured output for debugging. Junctions are always removed.

.EXAMPLE
    pwsh -File scripts/load-check.ps1
    pwsh -File scripts/load-check.ps1 -With space-age
    pwsh -File scripts/load-check.ps1 -AlsoModDirectory C:\somewhere\k2-2.0
    pwsh -File scripts/load-check.ps1 -FromZips
    pwsh -File scripts/load-check.ps1 -SelfTest
    pwsh -File scripts/load-check.ps1 -SelfTest -FromZips
#>
[CmdletBinding()]
param(
    [string]   $FactorioExe,
    [string[]] $With = @(),
    [string]   $AlsoModDirectory,
    [switch]   $FromZips,
    [switch]   $SelfTest,
    [switch]   $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
# Refused rather than combined. The self-test's canary halves reason about what a broken mod does to
# a clean load, and a third-party overhaul in the same run makes a failure ambiguous -- worse, mods
# present in the directory but absent from mod-list.json are auto-enabled by Factorio, so "not
# mentioning them" would not keep them out either.
if ($SelfTest -and $AlsoModDirectory) {
    throw '-SelfTest and -AlsoModDirectory cannot be combined: the self-test needs a clean mod set to prove anything.'
}
# -SelfTest -FromZips is a DIFFERENT self-test, not the canary one. The canary halves junction
# deliberately broken mod directories in, and those are not tracked, so pack-mods.ps1 cannot ship
# them. What zip mode needs proving is its own thing anyway -- see Test-ZipModeSelfTest below.

$alsoMods = @()
if ($AlsoModDirectory) {
    if (-not (Test-Path $AlsoModDirectory)) { throw "-AlsoModDirectory not found: $AlsoModDirectory" }
    # ABSOLUTE, BECAUSE A JUNCTION TARGET MUST BE. New-ModJunctions hands the path to New-Item,
    # which refuses a relative target -- so `-AlsoModDirectory .mod-cache`, the obvious thing to
    # type after scripts/fetch-mods.ps1, failed inside the library rather than here (#60).
    $AlsoModDirectory = (Resolve-Path -LiteralPath $AlsoModDirectory).Path
    $alsoMods = @(Get-ChildItem -Path $AlsoModDirectory -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName 'info.json') } |
        ForEach-Object { $_.Name } | Sort-Object)
    # Empty is an error, not an empty run: it would otherwise report a coexistence pass for a set
    # that was never loaded.
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

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-loadcheck-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
New-Item -ItemType Directory -Path $modDir -Force | Out-Null

function Invoke-LoadCheck {
    <#  One check: write the mod list, create a map, and report whether a save came out.

        The running of Factorio itself lives in factorio-lib.ps1; what is here is the part that is
        this script's own -- which mods to enable, and that "exit 0 but no save" is a failure.  #>
    param([string] $Label, [string[]] $Enabled, [string] $Tag)

    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabledBundled -Mods $Enabled

    $bundledOn = if ($enabledBundled) { $enabledBundled -join ', ' } else { 'none (base 2.0 only)' }
    Write-Host "$Label`: $($Enabled -join ', ')  |  bundled enabled: $bundledOn"

    $save   = Join-Path $temp "$Tag.zip"
    $result = Invoke-Factorio -FactorioExe $FactorioExe -ModDirectory $modDir `
        -Arguments @('--create', $save) -OutputDirectory $temp -Tag $Tag

    [pscustomobject]@{
        Code       = $result.Code
        SaveExists = Test-Path $save
        OutFile    = $result.OutFile
        ErrFile    = $result.ErrFile
    }
}

function Test-Assets {
    <#  Every asset path the loaded prototypes name must exist on disk.

        Factorio will not catch this. A headless run loads no sprites, so a prototype naming an
        icon that does not exist validates and exits 0 -- and the player's game then refuses to
        start on it. That happened: a heat-exchanger icon whose file had been renamed in vanilla
        passed every check here and broke the game on first launch.

        Runs off --dump-data, so it sees the paths the game resolved rather than the strings in
        the source. The mods build most of their icon paths by concatenation; a scan of the Lua
        would report a clean pass over every graphic this repo ships.  #>
    param([string] $Tag)

    # $ourDirectories is set by the caller below, and points at the repository or at the unpacked
    # zips depending on how the mods were mounted. -SelfTest -FromZips is what proves it really
    # follows the mods rather than always pointing at the repository.
    $result = Invoke-Factorio -FactorioExe $FactorioExe -ModDirectory $modDir `
        -Arguments @('--dump-data') -OutputDirectory $temp -Tag "$Tag-dump"
    if ($result.Code -ne 0) {
        Write-Host "FAILED - Factorio exited $($result.Code) on --dump-data."
        Write-FactorioTail $result
        exit $result.Code
    }

    $missing = Find-MissingAssets `
        -DumpPath (Join-Path $temp 'write-data/script-output/data-raw-dump.json') `
        -DataDir (Get-FactorioDataDirectory -FactorioExe $FactorioExe) `
        -ModDirectories $ourDirectories
    if ($missing) {
        Write-Host "FAILED - $($missing.Count) asset(s) referenced but not present:"
        foreach ($m in $missing) { Write-Host "    $($m.Reference)" }
        exit 1
    }
    Write-Host 'assets: every referenced file is present.'
}

try {
    # Where Find-MissingAssets should look for each of our mods' files. In junction mode that is the
    # repository; in zip mode it must be the unpacked archive, or the check would resolve every
    # sprite against the working tree and certify a zip it never opened.
    $ourDirectories = @{}

    if ($FromZips) {
        $zipDir    = Join-Path $temp 'zips'
        $unpackDir = Join-Path $temp 'unpacked'
        Write-Host 'mods: from zips built by pack-mods.ps1 (the path a player installs)'

        & (Join-Path $PSScriptRoot 'pack-mods.ps1') -OutputDirectory $zipDir | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "pack-mods.ps1 exited $LASTEXITCODE; nothing to load." }

        foreach ($mod in $ourMods) {
            $version = (Get-Content (Join-Path $repoRoot "$mod/info.json") -Raw | ConvertFrom-Json).version
            $zip     = Join-Path $zipDir "${mod}_${version}.zip"
            if (-not (Test-Path -LiteralPath $zip)) { throw "pack-mods.ps1 produced no zip for $mod at $zip" }

            Copy-Item -LiteralPath $zip -Destination $modDir
            $target = Join-Path $unpackDir $mod
            [IO.Compression.ZipFile]::ExtractToDirectory($zip, $unpackDir)
            if (-not (Test-Path -LiteralPath $target)) {
                throw "$mod's zip did not unpack to a single top-level folder named after the mod."
            }
            $ourDirectories[$mod] = $target
        }
    }
    else {
        Write-Host 'mods: junctioned from the repository (the dev loop, not the shipped zip)'
        New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
        foreach ($mod in $ourMods) { $ourDirectories[$mod] = Join-Path $repoRoot $mod }
    }

    if ($alsoMods) {
        New-ModJunctions -ModDirectory $modDir -RepoRoot $AlsoModDirectory -Mods $alsoMods
        Write-Host "also loading: $($alsoMods -join ', ')"
    }

    if ($SelfTest -and $FromZips) {
        # Zip mode can pass by finding nothing, which is the same reason the canary halves exist.
        # The specific regression it guards: wire $ourDirectories back to $repoRoot and every sprite
        # resolves against the working tree, so the check reports a clean pass over a zip it never
        # opened. Deleting a file from the UNPACKED archive is what tells the two apart -- against
        # the repository that deletion is invisible, against the archive it must be reported.
        Write-Host 'self-test 1/2: the built zips must load and resolve every asset.'
        $dump = Invoke-Factorio -FactorioExe $FactorioExe -ModDirectory $modDir `
            -Arguments @('--dump-data') -OutputDirectory $temp -Tag 'zip-selftest-dump'
        if ($dump.Code -ne 0) { Write-FactorioTail $dump; exit $dump.Code }

        $dumpPath = Join-Path $temp 'write-data/script-output/data-raw-dump.json'
        $dataDir  = Get-FactorioDataDirectory -FactorioExe $FactorioExe
        $before = Find-MissingAssets -DumpPath $dumpPath -DataDir $dataDir -ModDirectories $ourDirectories
        if ($before) {
            Write-Host ''
            Write-Host "FAILED - self-test: the built zips are already missing $($before.Count) asset(s),"
            Write-Host '         so removing one would prove nothing.'
            foreach ($m in $before) { Write-Host "    $($m.Reference)" }
            exit 1
        }

        # Taken from the unpacked archive only. The repository keeps its copy, so a check that
        # resolved against the repo would not notice and would report a pass here.
        #
        # The victim has to be a file the PROTOTYPES NAME, not merely one the zip contains. The
        # first version of this took the first .png it found and drew
        # aneutronic-reactor-animation-glow.png, which graphics/krastorio-2/NOTICE.txt records as
        # currently unused -- kept deliberately, referenced by nothing. Deleting an unreferenced
        # file is correctly not reported, so the self-test failed the check rather than the other
        # way round. Candidates therefore come from the dump.
        Write-Host 'self-test 2/2: a file removed from the unpacked zip must be reported missing.'
        $dumpText = Get-Content -LiteralPath $dumpPath -Raw
        $referenced = [regex]::Matches($dumpText, '__(?<mod>[A-Za-z0-9_ .-]+)__/(?<rel>[^"]+?\.png)') |
            ForEach-Object { [pscustomobject]@{ Mod = $_.Groups['mod'].Value; Rel = $_.Groups['rel'].Value } } |
            Where-Object { $ourDirectories.ContainsKey($_.Mod) } |
            Sort-Object Mod, Rel -Unique

        # More than one candidate on purpose. A sprite that declares `stripes` keeps a `filename`
        # beside them that the engine never opens, and Find-MissingAssets skips those by design --
        # picking one would fail this test for a reason that is not a fault. Trying a handful means
        # a single such pick cannot decide the result.
        $caught = $null
        $tried  = @()
        foreach ($candidate in ($referenced | Select-Object -First 5)) {
            $path = Join-Path $ourDirectories[$candidate.Mod] $candidate.Rel

            # This self-test deletes files, so it refuses to delete one outside the scratch
            # directory. Found the hard way: wiring $ourDirectories back at the repository -- the
            # exact regression this test exists to catch -- made it delete the repository's own
            # sprite while proving the point. A test that damages the working tree when it fails is
            # not a test anyone will run twice.
            $resolved = [IO.Path]::GetFullPath($path)
            if (-not $resolved.StartsWith([IO.Path]::GetFullPath($unpackDir), [StringComparison]::OrdinalIgnoreCase)) {
                Write-Host ''
                Write-Host 'FAILED - self-test: the asset map does not point inside the unpacked archive.'
                Write-Host "         $($candidate.Mod) resolves to $resolved"
                Write-Host "         but the archive was unpacked to $unpackDir."
                Write-Host '         Refusing to delete anything outside it; nothing was touched.'
                exit 1
            }
            if (-not (Test-Path -LiteralPath $path)) { continue }
            $tried += $candidate.Rel
            $bytes = [IO.File]::ReadAllBytes($path)
            Remove-Item -LiteralPath $path -Force

            $after = Find-MissingAssets -DumpPath $dumpPath -DataDir $dataDir -ModDirectories $ourDirectories
            if ($after | Where-Object { $_.Reference -like "*/$($candidate.Rel)" }) {
                $caught = $candidate
                break
            }
            # Not reported: put it back before trying the next, so a run that ends up failing does
            # not also leave the unpacked archive shredded behind it.
            [IO.File]::WriteAllBytes($path, $bytes)
        }

        if (-not $caught) {
            Write-Host ''
            Write-Host 'FAILED - self-test: removing a referenced file from the unpacked zip was NOT'
            Write-Host '         reported missing. The asset check is resolving against something other'
            Write-Host '         than the archive -- most likely the repository -- so a zip-mode pass'
            Write-Host '         says nothing about what is in the zip.'
            Write-Host "         Tried: $($tried -join ', ')"
            exit 1
        }
        $victimRepoCopy = Join-Path $repoRoot (Join-Path $caught.Mod $caught.Rel)
        # Asserted rather than mentioned: if the repository's copy were gone too, the deletion
        # would have been caught by either resolution and this would prove nothing about which one
        # the check used.
        if (-not (Test-Path -LiteralPath $victimRepoCopy)) {
            Write-Host ''
            Write-Host "FAILED - self-test: the repository's copy of $($caught.Rel) is missing, so"
            Write-Host '         catching the deletion does not show the check read the archive.'
            exit 1
        }

        Write-Host ''
        Write-Host 'OK - self-test passed: the built zips load and resolve every asset, and a file'
        Write-Host "     removed from the unpacked archive was caught ($($caught.Rel))"
        Write-Host "     while the repository's own copy of it stayed put -- so the asset check"
        Write-Host '     follows the mods rather than always reading the working tree.'
        exit 0
    }

    if ($SelfTest) {
        # Half one: the repo as it stands must pass, or a non-zero exit in half two proves nothing.
        Write-Host 'self-test 1/3: the repo as it stands must load.'
        $clean = Invoke-LoadCheck -Label 'load-check' -Enabled $ourMods -Tag 'clean'
        # Same pass criterion as a real run: exit 0 without a save is a failure there, so it must
        # be a failure here too, or -SelfTest could certify a check a plain run would reject.
        if ($clean.Code -ne 0 -or -not $clean.SaveExists) {
            Write-Host ''
            Write-Host "FAILED - self-test: the repo does not load cleanly (exit $($clean.Code), save produced: $($clean.SaveExists)),"
            Write-Host '         so the canary result would be meaningless.'
            Write-FactorioTail $clean
            exit 1
        }

        # Half two: an invalid prototype must be rejected. The canary lives in the temp directory,
        # never in the repo.
        $canary = Join-Path $modDir 'rf-loadcheck-canary'
        New-Item -ItemType Directory -Path $canary -Force | Out-Null
        @{
            name = 'rf-loadcheck-canary'; version = '0.0.1'; title = 'Load-check canary'
            author = 'load-check.ps1'; factorio_version = '2.0'; dependencies = @('base >= 2.0.77')
        } | ConvertTo-Json | Set-Content -Path (Join-Path $canary 'info.json') -Encoding utf8
        # Valid Lua, invalid prototype: "stack_size" is mandatory on an item.
        'data:extend({{ type = "item", name = "rf-loadcheck-canary-item" }})' |
            Set-Content -Path (Join-Path $canary 'data.lua') -Encoding utf8

        Write-Host 'self-test 2/3: an invalid prototype must be rejected.'
        $broken = Invoke-LoadCheck -Label 'load-check' -Enabled ($ourMods + 'rf-loadcheck-canary') -Tag 'canary'
        if ($broken.Code -eq 0) {
            Write-Host ''
            Write-Host 'FAILED - self-test: an invalid prototype did NOT fail the check.'
            Write-Host '         The load-check is not proving anything; fix it before trusting a pass.'
            exit 1
        }

        # Half three: a prototype naming a file that is not there must be caught. This is the one
        # Factorio itself exits 0 on, so it is the half that matters most -- and it is checked by
        # calling Find-MissingAssets directly rather than by running Test-Assets, which exits.
        # The canary names its icon by concatenation, because that is the shape the source-text
        # scan this replaced could not see.
        'local D = "__rf-loadcheck-canary__/graphics/"
data:extend({{ type = "item", name = "rf-loadcheck-canary-item", stack_size = 1,
  icon = D .. "no-such-icon" .. ".png", icon_size = 64 }})' |
            Set-Content -Path (Join-Path $canary 'data.lua') -Encoding utf8

        Write-Host 'self-test 3/3: a prototype naming a file that is not there must be caught.'
        $withCanary = Invoke-LoadCheck -Label 'load-check' -Enabled ($ourMods + 'rf-loadcheck-canary') -Tag 'assets'
        if ($withCanary.Code -ne 0) {
            Write-Host ''
            Write-Host 'FAILED - self-test: the missing-asset canary did not even load, so the'
            Write-Host "         asset check was never reached (exit $($withCanary.Code))."
            Write-FactorioTail $withCanary
            exit 1
        }

        $dump = Invoke-Factorio -FactorioExe $FactorioExe -ModDirectory $modDir `
            -Arguments @('--dump-data') -OutputDirectory $temp -Tag 'assets-dump'
        if ($dump.Code -ne 0) { Write-FactorioTail $dump; exit $dump.Code }

        $directories = @{ 'rf-loadcheck-canary' = $canary }
        foreach ($mod in $ourMods) { $directories[$mod] = Join-Path $repoRoot $mod }
        $found = Find-MissingAssets `
            -DumpPath (Join-Path $temp 'write-data/script-output/data-raw-dump.json') `
            -DataDir (Get-FactorioDataDirectory -FactorioExe $FactorioExe) `
            -ModDirectories $directories
        if (-not ($found | Where-Object { $_.Reference -like '*no-such-icon.png' })) {
            Write-Host ''
            Write-Host 'FAILED - self-test: a prototype naming a file that does not exist was NOT caught.'
            Write-Host '         Factorio exits 0 on this and the player''s game does not; fix it before'
            Write-Host '         trusting a pass.'
            exit 1
        }

        Write-Host ''
        Write-Host 'OK - self-test passed: clean repo loads, invalid prototype rejected'
        Write-Host "     (exit $($broken.Code)), missing asset caught."
        exit 0
    }

    $result = Invoke-LoadCheck -Label 'load-check' -Enabled ($ourMods + $alsoMods) -Tag 'run'

    # After the load, not before: Test-Assets reads a --dump-data written under the mod list
    # Invoke-LoadCheck just put in place, and a repo that does not load has nothing to dump.
    #
    # A missing capture file is a failure rather than a skip. It used to be one half of an `and`,
    # so if the redirection had failed or the temp directory had been reaped mid-run the asset
    # check would simply not happen -- and the success line below would still claim every
    # referenced asset was present. A check that can quietly not run is worse than one that is
    # not there, because only one of the two is claimed to have passed.
    if ($result.Code -eq 0) {
        if (-not (Test-Path $result.OutFile)) {
            Write-Host "FAILED - Factorio exited 0 but its output was not captured at $($result.OutFile),"
            Write-Host '         so the asset check could not run. Treating as a failure rather than'
            Write-Host '         reporting a pass it did not earn.'
            exit 1
        }
        Test-Assets -Tag 'run'
    }

    if ($result.Code -ne 0) {
        Write-Host ''
        Write-Host "FAILED - Factorio exited with code $($result.Code)"
        Write-FactorioTail $result
        exit $result.Code
    }
    if (-not $result.SaveExists) {
        Write-Host 'FAILED - Factorio exited 0 but produced no save; treating as a failure.'
        exit 1
    }

    # Says what actually passed rather than "data stage valid", which was the same undersell the
    # docstring above used to make: creating the map ran control.lua's check_prototypes() too.
    $how = if ($FromZips) { 'built zips' } else { 'junctioned repo directories' }
    Write-Host "OK - prototypes valid, every referenced asset present, map created and the"
    Write-Host "     simulation's twelve load-time invariants hold, loading from $how."
    exit 0
}
finally {
    # Junctions always go, even with -KeepTemp: leaving links to the repo in %TEMP% hands a
    # delete-through-the-link hazard to whatever cleans it up later.
    Remove-ModJunctions -ModDirectory $modDir

    if ($KeepTemp) {
        Write-Host "temp kept at: $temp"
    }
    else {
        Remove-TempDirectory -Path $temp -Label 'load-check'
    }
}

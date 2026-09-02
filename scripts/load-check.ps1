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

    IT THEN CHECKS THAT CONTAINMENT SURVIVED THE LOAD, which is the one rule this mod enforces by
    declaration rather than by code (#209). contain() gives every plasma-carrying pipe connection the
    category `rf-plasma`, and 2.0 joins two connections only when their categories match -- so a
    vanilla pipe beside a plasma line does not connect, and nothing has to watch it at runtime. That
    argument holds exactly as long as the declaration survives, and a third-party mod's
    `data-final-fixes` can overwrite it silently: `name-check` compares only prototypes present in
    BOTH dumps and ours are in one, and nothing else here fails on a reassigned category. So this
    script dumps the game twice when a set is loaded -- once with our mods alone for what our data
    stage declared, once with the set for what survived -- and fails if a category we wrote is gone.
    Removal and replacement fail; an addition to a connection we categorised is counted into the
    pass line and does not, which is #195's shape and reports through
    scripts/probe-connection-categories.ps1 instead. See
    Get-ContainmentBreaches for what it can and cannot see, and ADR 0007's finding 4 for the rest of
    the blind spot this closes one slice of.

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
    takes a directory rather than a mod name because this script downloads nothing: enabling mods is
    the part it owns, and getting them onto disk is somebody else's job. Since #60 that somebody is
    scripts/fetch-mods.ps1, which fills a directory at pinned versions -- by git where a source
    exists, by the mod portal otherwise. Run it, then point this at what it wrote:

        pwsh -File scripts/fetch-mods.ps1 -Set krastorio2
        pwsh -File scripts/load-check.ps1 -AlsoModDirectory .mod-cache/krastorio2

    Putting the mods there by hand still works and always did.

    THIS IS HALF THE COEXISTENCE QUESTION AND NOT THE HALF THAT FAILS SILENTLY. A prototype-name
    collision does not stop the game loading -- the second definition replaces the first and the
    map is created without a word -- so a pass here is no evidence at all about it.
    `scripts/name-check.ps1 -AlsoModDirectory <same dir>` is the other half, and #61's lanes run
    both against every set.

    Note the version trap. A mod's factorio_version must match the game's major version exactly, so
    Krastorio 2 2.1.x will NOT load next to this repo on 2.0.77 however the mod list is written --
    the 2.0 line (2.0.19) is the one that loads. See docs/research/mod-set-coexistence-targets.md.

    The asset check half-covers the extra mods, and the distinction matters. Find-MissingAssets is
    given a directory only for this repo's mods, so a third-party mod's OWN assets are skipped --
    not this repo's to police. But `__base__/...` paths are always resolvable, whoever names them,
    so a third-party mod referencing a base file that 2.0 removed is reported -- PROVIDED THE
    REFERENCE REACHES THE DUMP, which is not the same as the mod writing it. Read the next paragraph
    before treating a silent lane as proof that no such reference is there. Found the first time a
    pinned set was loaded (#59): RITEG 1.3.11 names `__base__/sound/car-metal-impact.ogg`, which
    does not exist in 2.0.77. That is upstream's bug and it fails this check, which is worth
    knowing before reading such a failure as ours.

    IT REPORTS WHAT THE ENGINE RECORDS, not what a mod writes, and the two can differ.
    underground-pipe-pack 2.0.6 names that same path in the same field, in a file its data.lua
    requires unconditionally, and this check stays silent: Factorio 2.0 migrated
    `vehicle_impact_sound` to `impact_category` for the `pump` prototype type and not for
    `electric-energy-interface`, so the string never reaches the dumped prototypes that
    Find-MissingAssets walks. Measured on 2026-08-31 against 2.0.77 (#196) -- this parameter said
    both mods fail until then. A property a later version stops recording goes quiet the same way.

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
    Verify the check can fail. FOUR halves, and the run prints each one numbered as it passes, so a
    reader can count them against this list: the repo as it stands must pass; a mod carrying an
    invalid prototype must fail; a mod naming an icon file that does not exist must be caught; and a
    mod that reassigns one of our containment categories must be caught. The first is required or
    the others prove nothing, since Factorio also exits non-zero when the repo is genuinely broken.
    The third and the fourth are the two Factorio itself exits 0 on. Run this whenever the script
    changes.

    The fourth is #209's, and it is the same shape the real breach had: a canary whose
    `data-final-fixes` writes a literal over the first connection of ours carrying `rf-plasma` --
    whatever that connection is, since a hard-coded victim would fail on the day a pipe is renamed.
    The canary records which prototype it broke in its own item's `order` field, and the assertion
    compares the reported breach against that name: "caught" has to mean "named correctly" here,
    because the report is the whole value of the check.

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

#Requires -Version 7
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

# The category contain() writes, which the containment floor below looks for.
#
# Named PLASMA_CATEGORY and not CONTAINED, because PowerShell variable names are case-INSENSITIVE:
# `$contained` for the connections holding it would be the SAME VARIABLE, and the constant would be
# gone by the time a message quoted it. probe-connection-categories.ps1 carries the same note for
# the same reason, and name-check.ps1's $REFERENCE_MODS is where this file's family first met it.
$PLASMA_CATEGORY = 'rf-plasma'
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
    # which refuses a relative target -- so `-AlsoModDirectory .mod-cache/krastorio2`, the obvious
    # thing to type after scripts/fetch-mods.ps1, failed inside the library rather than here (#60).
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
        would report a clean pass over every graphic this repo ships.

        HANDED THE DUMP RATHER THAN TAKING ONE (#209). The containment gate reads the same loaded
        dump and then takes a second one of its own under a different mod list, so the dumping moved
        out to Invoke-DataDump and both gates read the copy it keeps aside. One --dump-data per mod
        list, and neither gate can be looking at the other's.  #>
    param([Parameter(Mandatory)] [string] $DumpPath)

    # $ourDirectories is set by the caller below, and points at the repository or at the unpacked
    # zips depending on how the mods were mounted. -SelfTest -FromZips is what proves it really
    # follows the mods rather than always pointing at the repository.
    $missing = Find-MissingAssets `
        -DumpPath $DumpPath `
        -DataDir (Get-FactorioDataDirectory -FactorioExe $FactorioExe) `
        -ModDirectories $ourDirectories
    if ($missing) {
        Write-Host "FAILED - $($missing.Count) asset(s) referenced but not present:"
        foreach ($m in $missing) { Write-Host "    $($m.Reference)" }
        exit 1
    }
    Write-Host 'assets: every referenced file is present.'
}

function Invoke-DataDump {
    <#  Dump the game with exactly $Mods enabled, and return the path of the dump kept aside for it.

        The walk and the category semantics are factorio-lib.ps1's, shared with
        scripts/probe-connection-categories.ps1 (#209); what is here is running the game the way the
        rest of this script runs it -- Invoke-Factorio, and an explicit failure rather than a throw.

        THE DUMP PATH IS DELETED FIRST, NOT MERELY OVERWRITTEN. Every dump in this run writes the one
        path, so a Factorio run that exits 0 without writing would leave the PREVIOUS dump there for
        the parse to find -- and the declared side would then be a copy of the loaded side, every
        connection would compare equal, and the gate would report containment surviving. That is the
        one way this check could pass by finding nothing that the floor cannot catch, because the
        floor only inspects the declared side, which would be genuinely fine.  #>
    param(
        [Parameter(Mandatory)] [string[]] $Mods,
        [Parameter(Mandatory)] [string] $Tag,
        # WHAT MUST STAY OUT, NAMED. Leaving a mod unlisted does not disable it -- Factorio
        # auto-enables anything in the mod directory that mod-list.json does not mention, and by the
        # time this runs the set (or the self-test's canary) is junctioned in beside our mods. The
        # first version of this omitted them and got a declared dump with the set loaded in it: both
        # dumps identical, every category equal, containment reported as surviving. Write-ModList's
        # own header carries the note now.
        [string[]] $Disabled = @()
    )

    $rawPath = Join-Path $temp 'write-data/script-output/data-raw-dump.json'
    Remove-Item -LiteralPath $rawPath -Force -ErrorAction SilentlyContinue

    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabledBundled `
        -Mods $Mods -Disabled $Disabled
    $result = Invoke-Factorio -FactorioExe $FactorioExe -ModDirectory $modDir `
        -Arguments @('--dump-data') -OutputDirectory $temp -Tag $Tag
    if ($result.Code -ne 0) {
        Write-Host "FAILED - Factorio exited $($result.Code) on --dump-data for the $Tag dump."
        Write-FactorioTail $result
        exit $result.Code
    }
    if (-not (Test-Path -LiteralPath $rawPath)) {
        Write-Host "FAILED - Factorio exited 0 but wrote no data-raw-dump.json for the $Tag dump,"
        Write-Host '         so containment could not be compared. Treating as a failure rather than'
        Write-Host '         reporting a pass it did not earn.'
        exit 1
    }
    # KEPT ASIDE UNDER THE TAG, and the copy is what every caller reads. All the dumps in a run
    # write the one path, so a caller holding on to that path would be reading the NEXT dump by the
    # time it looked. -KeepTemp leaves each of them to compare by hand.
    $kept = Join-Path $temp "$Tag-data-raw.json"
    Copy-Item -LiteralPath $rawPath -Destination $kept -Force
    return $kept
}

function Get-ContainmentBreaches {
    <#  Connections our data stage contained that no longer hold what it declared, once the whole
        set is loaded. Returns a row per breach; empty means containment survived.

        WHY THIS IS A GATE AND NOT A PROBE (#209). Containment is the only rule this mod enforces by
        declaration rather than by code: contain() gives every plasma-carrying connection the
        category `rf-plasma`, 2.0 joins two connections only when their categories match, and so a
        vanilla pipe beside a plasma line does not connect at all. The argument for that design is
        that nothing has to watch it at runtime -- which holds exactly as long as the declaration
        survives the load. Nothing checked that it did. `name-check` compares only prototypes present
        in BOTH dumps and ours are in one; the rest of this script asserts validity, assets and the
        simulation's invariants, none of which a reassigned category fails. ADR 0007's finding 4 said
        so for a while before this closed the containment slice of it.

        TWO DUMPS, AND THE DECLARED ONE IS OUR MODS ALONE. Our data stage's own output is not visible
        in a loaded dump -- that dump is what the set left behind. So the declared side is a second
        --dump-data with only our mods enabled, which is what the probe does and for the same reason:
        a category assembled by a helper or a loop is then read exactly as a literal is.

        WHAT FAILS, AND WHAT DELIBERATELY DOES NOT.

          fails    A category we declared is not in the loaded value -- whether the field was
                   emptied, deleted, or overwritten with something else. Containment is gone from
                   that connection and a player's pipes now match against whatever is there.

          passes   Everything we declared is still there and MORE was added. A connection category
                   is a whitelist, so an addition does open the box -- but #209 scopes this gate to
                   removal and replacement, and the collecting shape reports through
                   scripts/probe-connection-categories.ps1 and #195 instead. Additions are not
                   breaches, so they are not rows: this function returns none for them, and
                   Test-Containment COUNTS them into its pass line so a reader sees that some
                   happened without the gate claiming they are what it caught. Which connections
                   they landed on is the probe's report, not this one's.

          passes   Anything on a connection we left `default`. That is an ordinary box of ours being
                   treated like every other ordinary box in the game; against the seablock lane it is
                   44 of 46 differences, and failing on it would bury the two rows that matter.

        WHAT IT CANNOT SEE, because both dumps enable the same bundled selection: a bundled mod
        reassigning one of our categories cancels out. `-With space-age` is on both sides by
        construction, so this says nothing about the expansion -- the same limitation ADR 0007
        records for every `-With` lane.

        THE WALK IS SHARED WITH THE PROBE, in factorio-lib.ps1, and that is not tidiness. Two traps
        live in it -- a one-element category list read as a string, and comparing rendered text
        rather than category sets -- and a second implementation would have been free to fall into
        either. The probe's header records both.

        A CONNECTION'S IDENTITY IS ITS POSITION, and that is the sharpest edge on this gate. The path
        ends in `pipe_connections[N]`, so a set that INSERTS a connection ahead of a contained one
        shifts ours down the list: the declaration at [1] is compared against the set's new
        connection at [1], which reports `rf-plasma` lost on a connection that never carried it,
        while ours -- now at [2] -- is never examined. The failure is real either way, since a set
        rewriting our fluid box is worth a red run, but the ROW would name the wrong connection and
        the reason. Nothing in a dump distinguishes an insertion from a replacement: the engine
        records what the box ended up as, in order, and no field survives to say which entry used to
        be where. Tolerable while it only produced a row in the probe's report; worth knowing now
        that it decides an exit code. Read the two values in the row before believing the index.  #>
    param(
        [Parameter(Mandatory)] [hashtable] $Declared,
        [Parameter(Mandatory)] [hashtable] $Loaded
    )

    # ONE PREDICATE FOR "WE CONTAINED THIS", used by both branches below. Expand-Category synthesises
    # `default` for an absent field, because that is what the engine reads one as -- but a synthesised
    # value is not a declaration of ours, and treating it as one would make this gate fire on every
    # ordinary box of ours that a set touches.
    #
    # Scalar comparisons, not array ones: PowerShell's -ceq with an ARRAY on the left is a filter and
    # not a test, so `$set -ceq @('default')` returns elements rather than $true or $false.
    $contained = {
        param($Connection)
        $set = $Connection.Set
        -not ($set.Count -eq 1 -and $set[0] -ceq 'default')
    }

    $breaches = [System.Collections.Generic.List[object]]::new()
    foreach ($key in ($Declared.Keys | Sort-Object)) {
        $mine = $Declared[$key]
        # WHAT WE CONTAINED ON IT, not how many connections it has. Counting all of them made a
        # prototype of ours with nothing but `default` boxes a subject of the whole-prototype branch
        # below -- so a set that removed or renamed such a prototype failed the gate under a row
        # saying "present, with contained connections", which was not true of it. Caught in review of
        # #209 before it shipped; the probe classifies that shape as STRUCTURAL rather than LOST for
        # the same reason.
        $mineContained = @($mine.Values | Where-Object { & $contained $_ })
        if (-not $mineContained) { continue }

        # A PROTOTYPE OF OURS THAT IS GONE is a breach of this invariant rather than a skip, now that
        # we know it carried containment. A set that removes or renames the prototype out from under
        # the declaration has taken the declaration with it, and comparing nothing is how a check
        # reports a pass it did not earn.
        if (-not $Loaded.ContainsKey($key)) {
            $breaches.Add([pscustomobject]@{
                Prototype = $key; Connection = '(the whole prototype)'
                Declared = "$($mineContained.Count) contained connection(s)"
                Loaded = 'gone from the dump' })
            continue
        }
        $their = $Loaded[$key]
        foreach ($path in ($mine.Keys | Sort-Object)) {
            $mineSet = $mine[$path].Set
            if (-not (& $contained $mine[$path])) { continue }

            if (-not $their.ContainsKey($path)) {
                $breaches.Add([pscustomobject]@{
                    Prototype = $key; Connection = $path
                    Declared = $mine[$path].Category; Loaded = 'the connection is gone' })
                continue
            }
            $missing = @(Get-MissingCategories -Declared $mineSet -Loaded $their[$path].Set)
            if (-not $missing) { continue }
            $breaches.Add([pscustomobject]@{
                Prototype = $key; Connection = $path
                Declared = $mine[$path].Category; Loaded = $their[$path].Category
                Missing = $missing })
        }
    }
    return $breaches
}

function Test-Containment {
    <#  The gate half of Get-ContainmentBreaches: report, and exit non-zero on a breach.

        Separate from the comparison for the reason Test-Assets is separate from Find-MissingAssets:
        the self-test has to ask the question without the answer ending the run.  #>
    param(
        [Parameter(Mandatory)] [hashtable] $Declared,
        [Parameter(Mandatory)] [hashtable] $Loaded,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $Against
    )

    # THE FLOOR, BECAUSE EVERYTHING BELOW PASSES BY FINDING NOTHING. A walk that stopped matching, a
    # prefix that changed, a dump written somewhere else: each reports zero breaches, which reads
    # exactly like containment surviving. So the declared side must hold at least one connection
    # carrying the category before any comparison is believed. An instrument fault, not a finding.
    $carrying = @($Declared.Values | ForEach-Object { $_.Values } |
        Where-Object { $_.Set -ccontains $PLASMA_CATEGORY })
    if (-not $carrying) {
        Write-Host ''
        Write-Host "FAILED - containment: the declared dump holds no connection carrying '$PLASMA_CATEGORY'."
        Write-Host '         Either contain() has stopped writing it or this check has stopped'
        Write-Host '         reading it -- and both would otherwise report a clean pass against any'
        Write-Host '         set at all.'
        exit 1
    }

    $breaches = @(Get-ContainmentBreaches -Declared $Declared -Loaded $Loaded)
    if ($breaches) {
        Write-Host ''
        Write-Host "FAILED - containment: $($breaches.Count) contained connection(s) no longer hold what"
        Write-Host '         our data stage declared. A connection category is what keeps plasma out of'
        Write-Host '         an ordinary pipe, and nothing watches it at runtime.'
        foreach ($b in $breaches) {
            Write-Host "    $($b.Prototype)  $($b.Connection)"
            Write-Host "      declared: $($b.Declared)"
            Write-Host "      loaded:   $($b.Loaded)"
            if ($b.Missing) { Write-Host "      lost:     $($b.Missing -join ', ')" }
        }
        exit 1
    }

    # Additions are not failures, and they are not silence either -- see Get-ContainmentBreaches.
    $added = 0
    foreach ($key in $Declared.Keys) {
        if (-not $Loaded.ContainsKey($key)) { continue }
        foreach ($path in $Declared[$key].Keys) {
            if (-not $Loaded[$key].ContainsKey($path)) { continue }
            $mineSet = $Declared[$key][$path].Set
            if ($mineSet.Count -eq 1 -and $mineSet[0] -ceq 'default') { continue }
            if (@(Get-MissingCategories -Declared $Loaded[$key][$path].Set -Loaded $mineSet)) { $added++ }
        }
    }
    $note = if ($added) { " ($added widened by additions, which this gate does not fail on -- see #195)" } else { '' }
    Write-Host ("containment: all $($carrying.Count) contained connection(s) still hold what our data " +
                "stage declared$note.")
    if (-not $Against) {
        Write-Host '             No set was loaded, so this compared our mods against themselves: the'
        Write-Host '             floor above is what the run proved, not that any set left them alone.'
    }
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
        Write-Host 'self-test 1/4: the repo as it stands must load.'
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

        Write-Host 'self-test 2/4: an invalid prototype must be rejected.'
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

        Write-Host 'self-test 3/4: a prototype naming a file that is not there must be caught.'
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

        # Half four: a set that reassigns one of our containment categories must be caught (#209).
        # This is the half that proves the newest invariant, and it is the same shape the real breach
        # had: `no-pipe-touching`'s data-final-fixes writes a literal over a connection of ours that
        # qualifies BECAUSE it is contained. The canary does exactly that, in as few lines.
        #
        # IT RECORDS WHAT IT BROKE, in its own item's `order` field, and the assertion below compares
        # the reported breach against that name. Without it this half could only assert that SOME
        # breach was reported, and a check that reported the wrong prototype would pass -- the report
        # is the whole value of this gate, so "caught" has to mean "named correctly".
        #
        # THE VICTIM IS WHATEVER IS CONTAINED, not a prototype named here. A hard-coded victim would
        # make this half fail on the day a pipe is renamed, which is the day it is least welcome.
        'local function break_one(node, seen)
  if type(node) ~= "table" or seen[node] then return nil end
  seen[node] = true
  if node.pipe_connections then
    for _, c in pairs(node.pipe_connections) do
      local cat = c.connection_category
      if cat == "rf-plasma" or (type(cat) == "table" and cat[1] == "rf-plasma") then
        c.connection_category = "pipe-to-ground"
        return true
      end
    end
  end
  for _, v in pairs(node) do
    if break_one(v, seen) then return true end
  end
  return nil
end

local function first_contained()
  for type_name, protos in pairs(data.raw) do
    for name, proto in pairs(protos) do
      if name:sub(1, 3) == "rf-" and break_one(proto, {}) then
        return type_name .. "/" .. name
      end
    end
  end
  return nil
end

local victim = first_contained()
if not victim then
  error("load-check canary: no connection carrying rf-plasma to reassign, so half four would prove nothing")
end
data.raw.item["rf-loadcheck-canary-item"].order = victim' |
            Set-Content -Path (Join-Path $canary 'data-final-fixes.lua') -Encoding utf8
        # Valid, and with an icon that exists this time: half three's missing icon would fail the
        # asset check rather than reaching this one.
        'data:extend({{ type = "item", name = "rf-loadcheck-canary-item", stack_size = 1,
  icon = "__base__/graphics/icons/iron-plate.png", icon_size = 64 }})' |
            Set-Content -Path (Join-Path $canary 'data.lua') -Encoding utf8

        Write-Host 'self-test 4/4: a set reassigning one of our containment categories must be caught.'
        $reassigned = Invoke-LoadCheck -Label 'load-check' -Enabled ($ourMods + 'rf-loadcheck-canary') -Tag 'contain'
        if ($reassigned.Code -ne 0) {
            Write-Host ''
            Write-Host 'FAILED - self-test: the containment canary did not load, so the containment'
            Write-Host "         check was never reached (exit $($reassigned.Code)). A canary that cannot"
            Write-Host '         load proves nothing about a gate that runs after the load.'
            Write-FactorioTail $reassigned
            exit 1
        }

        $loadedDumpPath    = Invoke-DataDump -Mods ($ourMods + 'rf-loadcheck-canary') -Tag 'contain-loaded'
        $loadedContainment = Get-ConnectionsFromDump -DumpPath $loadedDumpPath
        $declaredContainment = Get-ConnectionsFromDump -DumpPath (
            Invoke-DataDump -Mods $ourMods -Tag 'contain-declared' -Disabled @('rf-loadcheck-canary'))

        $victim = (Get-Content -LiteralPath $loadedDumpPath -Raw |
            ConvertFrom-Json).item.'rf-loadcheck-canary-item'.order
        if (-not $victim) {
            Write-Host ''
            Write-Host 'FAILED - self-test: the containment canary recorded no victim, so it never found'
            Write-Host '         a contained connection to reassign and this half proves nothing.'
            exit 1
        }

        $breaches = @(Get-ContainmentBreaches -Declared $declaredContainment -Loaded $loadedContainment)
        $named    = @($breaches | Where-Object { $_.Prototype -eq $victim })
        if (-not $named) {
            Write-Host ''
            Write-Host "FAILED - self-test: the canary reassigned a contained connection on $victim and the"
            Write-Host '         containment check did NOT report it. Nothing else in this repo notices a'
            Write-Host '         category being overwritten -- name-check compares only prototypes present'
            Write-Host '         in both dumps, and ours is in one.'
            if ($breaches) {
                Write-Host "         It reported $($breaches.Count) other breach(es):"
                foreach ($b in $breaches) { Write-Host "           $($b.Prototype)  $($b.Connection)" }
            }
            exit 1
        }
        if (-not @($named | Where-Object { $_.Missing -ccontains $PLASMA_CATEGORY })) {
            Write-Host ''
            Write-Host "FAILED - self-test: the breach reported on $victim does not name $PLASMA_CATEGORY as"
            Write-Host '         the category lost, so the row would not tell a reader what was taken.'
            foreach ($b in $named) { Write-Host "           $($b.Connection): lost $($b.Missing -join ', ')" }
            exit 1
        }

        Write-Host ''
        Write-Host 'OK - self-test passed: clean repo loads, invalid prototype rejected'
        Write-Host "     (exit $($broken.Code)), missing asset caught, and a reassigned"
        Write-Host "     containment category caught by name on $victim."
        exit 0
    }

    $result = Invoke-LoadCheck -Label 'load-check' -Enabled ($ourMods + $alsoMods) -Tag 'run'

    # After the load, not before: both gates below read a --dump-data written under the mod list
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
        # 'run-dump' AND NOT 'run': Invoke-Factorio names its captures after the tag, so dumping
        # under the load's own tag overwrote run-stdout.txt with the dump's -- and -KeepTemp, which
        # is how a red lane gets investigated, would then hand a reader the wrong log. Caught in
        # review of #209.
        $loadedDump = Invoke-DataDump -Mods ($ourMods + $alsoMods) -Tag 'run-dump'

        # CONTAINMENT BEFORE THE ASSET CHECK, DELIBERATELY, and the reason is which lanes each one
        # can reach. Both exit on failure, so the order decides only which failure a reader sees
        # first -- but four lanes are permanently red on a 1.1-era `__base__` path their own mods
        # name, which is upstream's and cannot be pinned away. With the asset check first,
        # containment would never run on any of them -- `seablock` included, the one lane that has
        # ever actually reassigned a category of ours (#195, #207, #208). A gate that cannot run on
        # the lane it was built for closes nothing, so containment goes first and the upstream asset
        # reds are reported after it.
        #
        # The loaded side is the dump above, parsed rather than dumped again. The declared side needs
        # a run of its own and only when a set is loaded: without one the two dumps would be the same
        # dump, and the floor inside Test-Containment is the whole of what there is to prove.
        $loadedConnections   = Get-ConnectionsFromDump -DumpPath $loadedDump
        $declaredConnections = if ($alsoMods) {
            Get-ConnectionsFromDump -DumpPath (
                Invoke-DataDump -Mods $ourMods -Tag 'declared' -Disabled $alsoMods)
        } else { $loadedConnections }
        Test-Containment -Declared $declaredConnections -Loaded $loadedConnections -Against $alsoMods

        Test-Assets -DumpPath $loadedDump
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
    Write-Host "OK - prototypes valid, every referenced asset present, map created, the"
    Write-Host "     simulation's twelve load-time invariants hold and containment survived the"
    Write-Host "     load, loading from $how."
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

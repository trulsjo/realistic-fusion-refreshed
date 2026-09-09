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
    fires -- so this script enforces thirteen invariants that no amount of prototype validation
    would catch:

      check_fuel_rows()           Every row of reactor-logic's fuel table declares the fields
                                  step() indexes without asking. M.fuels is the documented place
                                  to add a tier, so a row gets written from its neighbours rather
                                  than from the function that reads it -- and a missing field
                                  throws inside the tick loop, on a live save, the moment a
                                  reactor of that tier first holds plasma.
      check_reactor_specs()       Every prototype entity-management registers as a reactor has
                                  constants in control.lua's SPECS and an entity prototype to
                                  match. The two lists are written separately on purpose -- one
                                  file decides what a reactor IS, the other what one DOES -- and
                                  a missing spec is a nil index inside the tick loop rather than
                                  a refusal to load.
      check_input_flow()          Each reactor's input_flow_limit against the confinement heating
                                  control.lua spends per tick. A network that cannot deliver
                                  heating_power_w continuously starves the reactor for ever --
                                  silently, since underpowered is a legitimate state it is meant
                                  to have. Over both reactors since #31: the aneutronic one draws
                                  four times as much against four times the limit, and nothing
                                  else would notice one moving without the other. It replaced
                                  check_cadence() in #72, when per-tick spending dissolved the
                                  coupling between UPDATE_INTERVAL and buffer_capacity.
      check_confinement_ladder()  The confinement ladder against the simulation's own temperature
                                  clamp, and against the technology prototypes it names. Research
                                  raises confinement time (#53), and a rung raised far enough
                                  leaves D-D settled AT the clamp -- where its thermometer stops
                                  moving and further research does nothing a player can see. It
                                  settles a full reactor at the top rung to find out, which is why
                                  it costs about 40 ms and why it is here rather than at the data
                                  stage.
      check_plant_efficiency()    The plant-efficiency ladder against its own ceiling, and against
                                  the technology prototypes it names. capture_efficiency is the
                                  only term standing between this mod and perpetual motion (#96,
                                  ADR 0020), and a research line into it is permitted only because
                                  each rung halves the remaining gap to a ceiling below 1.0 -- so
                                  a rung that reaches the ceiling is not a number that is too big,
                                  it is the guard being switched off. Four comparisons, where
                                  check_confinement_ladder above has to settle a plasma.
      check_plasma_bounds()       The simulation's temperature clamps against every plasma
                                  fluid's declared range, in BOTH directions. Widen the ceiling
                                  without the fluid and the mod loads perfectly, then throws on a
                                  live save the first time a reactor gets hot. Raise the FLOOR
                                  without the fluid and it never throws at all: a fluid cannot be
                                  colder than its default_temperature, so the engine hands the
                                  simulation a below-floor temperature on every cold reactor and
                                  each step creates energy from nothing (#107, ADR 0021). The two
                                  ends together require the floors to be equal.
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

    The Lua tests cannot see any of these: they know the physics but not the prototypes. So
    editing input_flow_limit, a plasma's max_temperature, reactor-logic's fuel table, the
    collector's box order or the blanket's inventory is guarded by running the game, not by the
    suite.

    TWO NUMBERS DROPPED OFF THAT LIST IN #72 AND NOTHING GUARDS THEM NOW -- said here rather than
    left to be discovered, because this paragraph is where the next editor looks. While a
    simulation step spent a whole update interval's confinement heating in one go, check_cadence()
    tied UPDATE_INTERVAL to buffer_capacity and caught either one moving without the other. Heating
    is spent per tick now, so that coupling does not exist and the check went with it.
    check_input_flow() reads neither number.

    What that leaves: buffer_capacity is stated reserve, coupled to nothing, and lowering it to a
    joule would pass every gate here. UPDATE_INTERVAL is bounded only by
    tests/test-reactor-logic.lua, which asserts the physics is insensitive to it from one tick to
    thirty -- so raising it past thirty is unguarded in both places at once. Neither is a
    correctness trap any more, which is why no new check was written for them; both are still edits
    to make deliberately.

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

    IT THEN CHECKS THAT EVERY PIECE OF RENDERED ART STILL AGREES WITH ITS MACHINE (#250). A render
    is drawn from the machine's footprint and pipe connections as `--dump-data` resolved them on the
    day it was rendered, and models/render.py records that geometry in the `manifest.json` beside
    the sprites. Nothing else ties the two together afterwards: move a connection in the Lua and the
    mod loads, the sprite still shows a socket where the pipe used to be, and the game says nothing.
    So for every `graphics/rendered/<machine>/manifest.json` in the Assets mod this script asks
    tools/extract-geometry.py -- the same code that wrote the geometry the render used -- for that
    machine's geometry out of the loaded dump, and fails if the two disagree on anything but the
    `source` line. The subject is the manifest, not the prototype's sprite paths: a stale render in
    the shipped Assets mod is wrong whether or not a prototype wears it yet, and "every machine
    wearing rendered art" was an empty set until #252, which is a pass by finding nothing. It reads
    the LOADED dump, so a third-party mod that moves one of our connections fails it too -- that is
    what a player would see. Python 3 on PATH is a requirement of this gate; a missing interpreter
    is a failure, not a skip.

    AND THE SAME FOR EVERY MOCKUP (#275). The four machines that wear a mockup take sheets drawn by
    scripts/make-mockup-art.ps1 from a table of footprints and connection tiles in
    scripts/mockup-machines.psd1, hand-copied from entities.lua. Every row of that table is held
    against the loaded dump the same way: footprint in tiles, and the set of tiles its connections
    stand on. Kind and label are not geometry and are not compared.

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
    Verify the check can fail. ELEVEN halves, and the run prints each one numbered as it passes, so
    a reader can count them against this list: the repo as it stands must pass; a mod carrying an
    invalid prototype must fail; a mod naming an icon file that does not exist must be caught; a
    mod that reassigns one of our containment categories must be caught; a mod that moves a
    pipe connection on a machine with rendered art must be caught; a mod that merely ADDS a
    connection category to one must NOT be; a mod that REPLACES one must be; a reactor whose
    input_flow_limit cannot cover its confinement heating must be refused; a mod that moves a
    pipe connection on a machine wearing a MOCKUP must be caught; a mod that puts a plasma of its
    own through our heating category must be refused; and the isotope collector's two box filters
    swapped must be refused. The first is
    required or the others prove nothing, since Factorio also exits non-zero when the repo is
    genuinely broken. Halves three through seven and nine are the ones Factorio exits 0 on, where
    the check has to decide alone. Run this whenever the script changes.

    TEN AND ELEVEN ARE #125's, and they are the first two halves about check_prototypes() -- the
    invariants that tie the simulation to the prototypes, and the reason this script is the gate
    that matters in this repository. Every one of them used to be asserted only positively: they
    pass on a good tree, and nothing would have noticed one that had quietly stopped firing. Two of
    them have now had their negative test done BY HAND and recorded only in a commit message (#55
    and #119, both by temporarily editing the value under test), which is the shape this half of
    the self-test exists to replace.

    Ten breaks its invariant by pure ADDITION -- the canary defines a fluid and a recipe of its own
    in rf-plasma-heating and mutates nothing of ours -- and eleven by MUTATION, swapping
    rf-isotope-collector's two box filters in `data-final-fixes`. Both must fail BY THE CHECK'S OWN
    MESSAGE, as half eight does and for the same reason: a canary that fails to load for an
    unrelated reason exits non-zero too, and would otherwise be recorded as the invariant firing.

    AND THE WORKING TREE IS ASSERTED UNTOUCHED after eleven, against a fingerprint taken before
    half one. Eight, ten and eleven break our own prototypes to prove our own checks fire; they do
    it in memory, and this is what says so rather than assuming it. A self-test in this file once
    deleted the repository's own sprite.

    THE NINTH IS #275's, and it is the fifth again for the other kind of art. make-mockup-art.ps1
    draws every mockup from a hand-copied table of footprints and connection tiles that, by its
    own header, nothing checked against entities.lua. The table now lives in mockup-machines.psd1
    and Test-MockupArt holds every row against the loaded dump; the canary slides the first
    connection of the first machine in that table one tile along its edge and requires the row.

    THE EIGHTH IS #72's, and it is the odd one out: every other half is about another mod breaking
    our prototypes, where this is about a developer edit to our own. check_input_flow() replaced
    check_cadence() when per-tick confinement spending dissolved the coupling between
    UPDATE_INTERVAL and buffer_capacity, and what became load-bearing in its place is
    input_flow_limit >= heating_power_w. The canary cuts rf-reactor's limit to 1 W from outside,
    because that is the only way to make the edit without editing the repo, and the assertion
    requires the run to fail BY check_input_flow's own message -- every other refusal in
    control.lua also fires from on_init while --create builds the map, so "it failed" alone would
    not say which check did it.

    SIX AND SEVEN ARE ONE PAIR and neither is worth much without the other. Krastorio 2 writes
    `kr-steel-pipe` onto the fluid boxes of machines it never heard of, which is ADR 0007's
    coexistence working, not our art coming loose -- and until the categories were held out of the
    geometry comparison the gate reported it as the latter, so `-AlsoModDirectory
    .mod-cache/krastorio2` failed on rf-heat-exchanger with four connections whose position,
    direction, flow and fluid all agreed.
    Six requires that tolerance. Seven requires the gate to still catch a category being REPLACED
    rather than added -- dropping `default` cuts a machine off from every ordinary pipe in the game
    -- because a gate that tolerated everything would pass six just as happily.

    NO OTHER GATE WATCHES THOSE CONNECTIONS, which is why the pair is here rather than left to the
    containment floor. Get-ContainmentBreaches skips any connection we left `default`, by design and
    by its own predicate, and all four of rf-heat-exchanger's are that shape. A gate, not a watcher:
    probe-connection-categories.ps1 reports on exactly this shape -- its REPLACED verdict is for it --
    but a probe asserts nothing and exits 0 either way.

    Half six is the only half that asserts a check STAYS QUIET, and there are two ways to pass it
    dishonestly. It rules out the first itself, by asking the extractor whether the added category
    reached the live geometry at all -- a canary that missed and a gate that tolerated look identical
    otherwise. The second, a gutted Get-RenderDisagreements, is ruled out by HALF FIVE, which runs
    the same function first and requires a row. Do not delete five believing six covers it.

    The fifth is #250's. Its canary's `data-final-fixes` slides the first connection the first
    manifest records one tile along its own edge -- along, so the prototype stays valid and the
    extractor's edge check still passes, and the only thing that changed is where the socket is.
    The assertion requires the disagreement to be reported against that prototype and on
    `connections`, for the same reason the fourth half compares names: the report is the value.

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

# The categories contain() writes, which the containment floor below looks for.
#
# THREE OF THEM SINCE #86 AND #87, one per contained fluid family: plasma, and ADR 0018's two
# reactor energies. The floor requires EACH of them to be present in the declared dump rather than
# merely one, because "at least one connection carries a category" was satisfiable by plasma alone --
# so contain() could have stopped writing either energy category and this gate would have reported a
# clean pass over it. Every one is listed rather than derived from a prefix: what the floor exists to
# catch is a category disappearing, and a prefix scan finds nothing to miss.
#
# Named PLASMA_CATEGORY and not CONTAINED, because PowerShell variable names are case-INSENSITIVE:
# `$contained` for the connections holding it would be the SAME VARIABLE, and the constant would be
# gone by the time a message quoted it. probe-connection-categories.ps1 carries the same note for
# the same reason, and name-check.ps1's $REFERENCE_MODS is where this file's family first met it.
$PLASMA_CATEGORY = 'rf-plasma'
$ENERGY_CATEGORIES = @('rf-reactor-energy', 'rf-aneutronic-reactor-energy')
$DECLARED_CATEGORIES = @($PLASMA_CATEGORY) + $ENERGY_CATEGORIES
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

# The mod that holds every sprite, and so every graphics/rendered/<machine>/manifest.json (ADR 0023).
$ASSETS_MOD = 'realistic-fusion-refreshed-assets'

function Get-ModTreeFingerprint {
    <#  Every file under each of our mod directories, as path, size and last write time.

        The canary self-test's one hazard is that three of its halves break OUR prototypes to prove
        OUR checks fire. They do it in `data-final-fixes`, in memory, so nothing on disk should
        move -- and #125 asked for that to be ASSERTED rather than reasoned about, because a
        self-test in this file once deleted the repository's own sprite.

        Path, size and write time rather than a hash of the contents: it walks the assets mod, so
        reading every sprite would cost more than the loads it is guarding, and a canary that
        rewrote a file in place without changing its length is not a failure mode this has.  #>
    param([Parameter(Mandatory)] [string[]] $Mods)

    $rows = foreach ($mod in $Mods) {
        $root = Join-Path $repoRoot $mod
        foreach ($file in (Get-ChildItem -LiteralPath $root -Recurse -File -Force)) {
            $rel = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
            "$mod/$rel|$($file.Length)|$($file.LastWriteTimeUtc.Ticks)"
        }
    }
    return @($rows | Sort-Object)
}

function ConvertTo-CanonicalTree {
    <#  The same value with every object's keys sorted, so two JSON documents that differ only in
        key order serialise to the same text. The manifest's geometry was written with sorted keys
        and the extractor's --stdout in insertion order; compared as text they would never agree.  #>
    param($Node)
    if ($Node -is [System.Management.Automation.PSCustomObject]) {
        $sorted = [ordered]@{}
        foreach ($p in ($Node.PSObject.Properties | Sort-Object Name)) {
            $sorted[$p.Name] = ConvertTo-CanonicalTree $p.Value
        }
        return $sorted
    }
    if ($Node -is [array]) {
        $list = [System.Collections.Generic.List[object]]::new()
        foreach ($e in $Node) { $list.Add((ConvertTo-CanonicalTree $e)) }
        return , $list.ToArray()
    }
    return $Node
}

function Get-RenderManifests {
    <#  Every manifest.json the render pipeline has written into the Assets mod, in path order.
        Each is the subject of one agreement check; the self-test picks its victim from the same
        list, so the two cannot disagree about what counts as rendered art.  #>
    param([Parameter(Mandatory)] [string] $AssetsDirectory)
    return @(Get-ChildItem -Path (Join-Path $AssetsDirectory 'graphics/rendered/*/manifest.json') -File |
        Sort-Object FullName)
}

function Get-RenderDisagreements {
    <#  Where a manifest's recorded geometry and the live prototype disagree. One row per field per
        manifest; empty means every render still fits its machine.

        THE LIVE SIDE IS THE EXTRACTOR'S, NOT A SECOND WALK. tools/extract-geometry.py wrote the
        geometry the render was built from, so asking it again against the loaded dump compares like
        with like: the same normalisation of directions, defaults and connection order, and no second
        implementation to drift from the first (#209 learned that lesson on the containment walk).
        `source` is left out of the comparison: it names the engine version the geometry was taken
        on, and a render does not go stale because the game was patched.

        An extractor that exits non-zero is a row, not an exception: a prototype it cannot read is a
        prototype no render can be shown to agree with.  #>
    param(
        [Parameter(Mandatory)] [string] $DumpPath,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [System.IO.FileInfo[]] $Manifests
    )

    $extractor = Join-Path $repoRoot 'tools/extract-geometry.py'
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($file in $Manifests) {
        $recorded = (Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json).geometry
        $name     = $recorded.name

        # 2>&1 so a Python traceback lands in the row rather than on the console; "$_" turns the
        # error records native stderr arrives as back into lines.
        $lines = @(& python $extractor $name --dump $DumpPath --stdout 2>&1 | ForEach-Object { "$_" })
        if ($LASTEXITCODE -ne 0) {
            $rows.Add([pscustomobject]@{
                Prototype = $name; Manifest = $file.FullName; Field = '(the live prototype)'
                Recorded = 'a geometry the extractor wrote'
                Live     = "extract-geometry.py exited $LASTEXITCODE`: $(($lines | Select-Object -Last 1))" })
            continue
        }
        $live = ($lines -join "`n") | ConvertFrom-Json

        $canon = { param($v) ConvertTo-Json -InputObject (ConvertTo-CanonicalTree $v) -Compress -Depth 20 }
        foreach ($field in @('name', 'type', 'tiles', 'collision_box', 'selection_box')) {
            $mine   = & $canon $recorded.$field
            $theirs = & $canon $live.$field
            if ($mine -ceq $theirs) { continue }
            $rows.Add([pscustomobject]@{
                Prototype = $name; Manifest = $file.FullName; Field = $field
                Recorded = $mine; Live = $theirs })
        }
        # Connections as two sets, reported by their difference: the whole list side by side was a
        # wall of JSON in which the one moved socket had to be found by eye. Order is not geometry.
        #
        # connection_category is held out of THIS comparison and checked separately below, because it
        # is the one field here that is not geometry: a category says what may connect to a socket,
        # never where the socket is, so no change to one can put a drawn pipe stub in the wrong place.
        # Compared as part of the whole object it made a coexisting mod look like art coming loose --
        # Krastorio 2 puts `kr-steel-pipe` on the fluid boxes of machines it never heard of, which had
        # this gate failing on rf-heat-exchanger with four connections agreeing on position,
        # direction, flow and fluid. That is ADR 0007's coexistence reported as ADR 0030's art being
        # wrong. Half six is the canary for the tolerance.
        $geometryOnly = { param($c) & $canon ($c | Select-Object -Property * -ExcludeProperty connection_category) }
        $mineSet   = @($recorded.connections | ForEach-Object { & $geometryOnly $_ })
        $theirSet  = @($live.connections     | ForEach-Object { & $geometryOnly $_ })
        $onlyMine  = @($mineSet  | Where-Object { $_ -cnotin $theirSet })
        $onlyTheirs = @($theirSet | Where-Object { $_ -cnotin $mineSet })
        if ($onlyMine -or $onlyTheirs) {
            $rows.Add([pscustomobject]@{
                Prototype = $name; Manifest = $file.FullName; Field = 'connections'
                Recorded = if ($onlyMine)   { $onlyMine   -join "`n                " } else { '(nothing the live prototype lacks)' }
                Live     = if ($onlyTheirs) { $onlyTheirs -join "`n                " } else { '(nothing the manifest lacks)' } })
        }

        # The categories, as a SUBSET rather than as equality, and this is the only GATE that checks
        # them on a connection like these. Get-ContainmentBreaches deliberately skips anything
        # we left `default` -- its own $contained predicate is false for exactly that set -- and all
        # four of rf-heat-exchanger's connections are that shape, so "the containment floor covers it"
        # is not available here and the field cannot simply be dropped. What a coexisting mod does is
        # ADD; what would break the machine is REPLACE, dropping `default` and cutting it off from
        # every ordinary pipe in the game. Subset admits the first and reports the second.
        #
        # Get-MissingCategories rather than a comparison written here, for the reason its own header
        # gives at length: ordinally, and as sets, because `contain()` writes a bare string where a
        # set that merely inspects a connection writes the same category back as a one-element list.
        # Matched by box AND position, because a position alone is not a key -- two boxes may put a
        # connection on the same tile. A recorded connection with NO live match is the geometry
        # difference above, already reported, so it is passed over rather than counted twice. Where
        # the match is AMBIGUOUS -- two live connections on the same box and tile -- it is passed over
        # and nothing reports it: the geometry comparison is a set difference, so a duplicated live
        # connection is not "only theirs" and is silent there too. Knowingly unwatched, and the
        # narrower of the two claims this comment used to make.
        foreach ($mineConn in $recorded.connections) {
            $theirConn = @($live.connections | Where-Object {
                $_.box -ceq $mineConn.box -and
                $_.position[0] -eq $mineConn.position[0] -and $_.position[1] -eq $mineConn.position[1] })
            if ($theirConn.Count -ne 1) { continue }
            $lost = @(Get-MissingCategories `
                -Declared (Expand-Category $mineConn.connection_category) `
                -Loaded   (Expand-Category $theirConn[0].connection_category))
            if (-not $lost) { continue }
            $rows.Add([pscustomobject]@{
                Prototype = $name; Manifest = $file.FullName; Field = 'connection categories'
                Recorded = "$($mineConn.box) at ($($mineConn.position[0]), $($mineConn.position[1])): $((Expand-Category $mineConn.connection_category) -join ', ')"
                Live     = "$((Expand-Category $theirConn[0].connection_category) -join ', ') -- lost $($lost -join ', ')" })
        }
    }
    return $rows
}

function Test-RenderedArt {
    <#  The gate half of Get-RenderDisagreements: report, and exit non-zero on a disagreement.
        Separate for the reason Test-Assets is separate from Find-MissingAssets: the self-test has to
        ask the question without the answer ending the run.  #>
    param([Parameter(Mandatory)] [string] $DumpPath)

    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Write-Host ''
        Write-Host 'FAILED - rendered art: no `python` on PATH, so the agreement gate could not run.'
        Write-Host '         Treating as a failure rather than reporting a pass it did not earn.'
        exit 1
    }
    # THE FLOOR, because everything below passes by finding nothing. A renamed directory or a
    # manifest the pipeline stopped writing would each report zero disagreements, which reads
    # exactly like every render agreeing. An instrument fault, not a finding.
    $manifests = Get-RenderManifests -AssetsDirectory $ourDirectories[$ASSETS_MOD]
    if (-not $manifests) {
        Write-Host ''
        Write-Host "FAILED - rendered art: no graphics/rendered/*/manifest.json found under $ASSETS_MOD."
        Write-Host '         The heat exchanger has had one since #249; either the pipeline stopped'
        Write-Host '         writing it or this check has stopped finding it, and both would otherwise'
        Write-Host '         report a clean pass over no render at all.'
        exit 1
    }

    $rows = @(Get-RenderDisagreements -DumpPath $DumpPath -Manifests $manifests)
    if ($rows) {
        # TWO KINDS OF ROW AND TWO REMEDIES, and giving the geometry one for a lost category would be
        # worse than saying nothing: re-rendering is the fix when a socket moved, and it is exactly
        # wrong when another mod took a category away, since it would bake that mod's change into our
        # manifest and call it ours.
        $geometry   = @($rows | Where-Object { $_.Field -ne 'connection categories' })
        $categories = @($rows | Where-Object { $_.Field -eq 'connection categories' })
        Write-Host ''
        Write-Host "FAILED - rendered art: $($rows.Count) disagreement(s) between a manifest and the live"
        Write-Host '         prototype.'
        if ($geometry) {
            Write-Host '         The sprite was rendered from the recorded geometry, so a socket'
            Write-Host '         or the footprint is now drawn where the machine no longer has it. Re-run'
            Write-Host '         the extractor and the render, or put the prototype back.'
        }
        if ($categories) {
            Write-Host '         A connection has LOST a category it was recorded with. Nothing moved and'
            Write-Host '         re-rendering would fix nothing -- it would write the loss into the'
            Write-Host '         manifest as ours. A machine that no longer holds `default` accepts no'
            Write-Host '         ordinary pipe in the game. Find the mod that took it.'
        }
        foreach ($r in $rows) {
            Write-Host "    $($r.Prototype)  $($r.Field)"
            Write-Host "      recorded: $($r.Recorded)"
            Write-Host "      live:     $($r.Live)"
        }
        exit 1
    }
    Write-Host "rendered art: all $($manifests.Count) manifest(s) agree with the live footprint, connections and recorded categories."
}

# The hand-copied table every mockup is drawn from, shared with make-mockup-art.ps1 (#275).
$MOCKUP_TABLE = Join-Path $PSScriptRoot 'mockup-machines.psd1'

function Get-MockupMachines {
    <#  Every row of mockup-machines.psd1, in file order. The same list make-mockup-art.ps1 draws
        from, read from the same file, so the gate and the picture cannot disagree about what a
        mockup claims.  #>
    return @((Import-PowerShellDataFile -Path $MOCKUP_TABLE).Machines)
}

function Get-MockupDisagreements {
    <#  Where a mockup's row in the table and the live prototype disagree on the footprint or on the
        tiles its connections stand on. One row per field per machine; empty means every mockup is
        drawn where its pipes are.

        THE SAME SHAPE AS Get-RenderDisagreements, AND THE SAME LIVE SIDE: the extractor, asked
        against the loaded dump, so there is no second walk of the prototype to drift from the first.
        What differs is the recorded side. A manifest records the geometry a render was built from, in
        the extractor's own words; the mockup table is a hand-written list of X, Y, Width and Height
        that the mockup script draws from and that nothing checked until #275 -- its own header said
        so. Kind and Text are colour and lettering, not geometry, and are not compared.

        Compared as tile SETS, not as lists: a mockup marks a square on a tile, so what it claims is
        "a pipe goes here", and two connections on one tile would be one mark.  #>
    param(
        [Parameter(Mandatory)] [string] $DumpPath,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [array] $Machines
    )

    $extractor = Join-Path $repoRoot 'tools/extract-geometry.py'
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($m in $Machines) {
        $name = "rf-$($m.Name)"
        $lines = @(& python $extractor $name --dump $DumpPath --stdout 2>&1 | ForEach-Object { "$_" })
        if ($LASTEXITCODE -ne 0) {
            $rows.Add([pscustomobject]@{
                Prototype = $name; Field = '(the live prototype)'
                Recorded = "a row in $(Split-Path $MOCKUP_TABLE -Leaf)"
                Live     = "extract-geometry.py exited $LASTEXITCODE`: $(($lines | Select-Object -Last 1))" })
            continue
        }
        $live = ($lines -join "`n") | ConvertFrom-Json

        $mineTiles  = "$($m.Width) x $($m.Height)"
        $theirTiles = "$($live.tiles[0]) x $($live.tiles[1])"
        if ($mineTiles -cne $theirTiles) {
            $rows.Add([pscustomobject]@{
                Prototype = $name; Field = 'tiles'; Recorded = $mineTiles; Live = $theirTiles })
        }

        $mineSet    = @($m.Connections    | ForEach-Object { "($($_.X), $($_.Y))" } | Sort-Object -Unique)
        $theirSet   = @($live.connections | ForEach-Object { "($($_.position[0]), $($_.position[1]))" } | Sort-Object -Unique)
        $onlyMine   = @($mineSet  | Where-Object { $_ -cnotin $theirSet })
        $onlyTheirs = @($theirSet | Where-Object { $_ -cnotin $mineSet })
        if ($onlyMine -or $onlyTheirs) {
            $rows.Add([pscustomobject]@{
                Prototype = $name; Field = 'connections'
                Recorded = if ($onlyMine)   { $onlyMine   -join ', ' } else { '(nothing the live prototype lacks)' }
                Live     = if ($onlyTheirs) { $onlyTheirs -join ', ' } else { '(nothing the mockup lacks)' } })
        }
    }
    return $rows
}

function Test-MockupArt {
    <#  The gate half of Get-MockupDisagreements: report, and exit non-zero on a disagreement.  #>
    param([Parameter(Mandatory)] [string] $DumpPath)

    # THE FLOOR, for the reason Test-RenderedArt has one: everything below passes by finding nothing,
    # and a table that failed to import or lost its rows would read exactly like every mockup
    # agreeing. Four machines wear one today; zero is an instrument fault, not a finding.
    $machines = Get-MockupMachines
    if (-not $machines) {
        Write-Host ''
        Write-Host "FAILED - mockup art: no machines in $MOCKUP_TABLE."
        Write-Host '         Four machines wear one, and the heat exchanger wore one until #252, so'
        Write-Host '         either the table moved or this check has stopped reading it -- and both'
        Write-Host '         would otherwise report a clean pass over no mockup at all.'
        exit 1
    }

    $rows = @(Get-MockupDisagreements -DumpPath $DumpPath -Machines $machines)
    if ($rows) {
        Write-Host ''
        Write-Host "FAILED - mockup art: $($rows.Count) disagreement(s) between $(Split-Path $MOCKUP_TABLE -Leaf)"
        Write-Host '         and the live prototype. The mockup is drawn from that table, so a socket or'
        Write-Host '         the footprint is marked where the machine no longer has it and a player is'
        Write-Host '         told a pipe goes somewhere it does not. Fix the table and rerun'
        Write-Host '         scripts/make-mockup-art.ps1, or put the prototype back.'
        foreach ($r in $rows) {
            Write-Host "    $($r.Prototype)  $($r.Field)"
            Write-Host "      table: $($r.Recorded)"
            Write-Host "      live:  $($r.Live)"
        }
        exit 1
    }
    Write-Host "mockup art: all $($machines.Count) mockup(s) agree with the live footprint and connection tiles."
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
    # exactly like containment surviving. So the declared side must hold a connection carrying EVERY
    # category contain() writes before any comparison is believed. An instrument fault, not a finding.
    #
    # EVERY category and not merely one, which is what #86 and #87 changed here. While plasma was the
    # only contained family the two were the same test; with three, "at least one" is satisfied by
    # plasma alone, and contain() dropping an energy category would have come out as a clean pass.
    $declaredConnections = @($Declared.Values | ForEach-Object { $_.Values })
    $absent = @($DECLARED_CATEGORIES | Where-Object {
        $category = $_
        -not @($declaredConnections | Where-Object { $_.Set -ccontains $category })
    })
    if ($absent) {
        Write-Host ''
        Write-Host "FAILED - containment: the declared dump holds no connection carrying $($absent -join ', ')."
        Write-Host '         Either contain() has stopped writing it or this check has stopped'
        Write-Host '         reading it -- and both would otherwise report a clean pass against any'
        Write-Host '         set at all.'
        exit 1
    }
    $carrying = @($declaredConnections | Where-Object {
        $set = $_.Set
        @($DECLARED_CATEGORIES | Where-Object { $set -ccontains $_ })
    })

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
        # Before anything: what the working tree looks like, for the assertion after half eleven.
        # Taken here rather than after the first canary is written, so a half that reached into the
        # repo at any point in the run is caught rather than only one that reached in late.
        $treeBefore = Get-ModTreeFingerprint -Mods $ourMods

        # Half one: the repo as it stands must pass, or a non-zero exit in half two proves nothing.
        Write-Host 'self-test 1/11: the repo as it stands must load.'
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

        Write-Host 'self-test 2/11: an invalid prototype must be rejected.'
        $broken = Invoke-LoadCheck -Label 'load-check' -Enabled ($ourMods + 'rf-loadcheck-canary') -Tag 'canary'
        if ($broken.Code -eq 0) {
            Write-Host ''
            Write-Host 'FAILED - self-test: an invalid prototype did NOT fail the check.'
            Write-Host '         The load-check is not proving anything; fix it before trusting a pass.'
            exit 1
        }

        # Half three: a prototype naming a file that is not there must be caught. The first of the
        # halves Factorio exits 0 on, where this check has to decide alone -- and it is checked by
        # calling Find-MissingAssets directly rather than by running Test-Assets, which exits.
        # The canary names its icon by concatenation, because that is the shape the source-text
        # scan this replaced could not see.
        'local D = "__rf-loadcheck-canary__/graphics/"
data:extend({{ type = "item", name = "rf-loadcheck-canary-item", stack_size = 1,
  icon = D .. "no-such-icon" .. ".png", icon_size = 64 }})' |
            Set-Content -Path (Join-Path $canary 'data.lua') -Encoding utf8

        Write-Host 'self-test 3/11: a prototype naming a file that is not there must be caught.'
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
        #
        # AND IT IS ANY OF THE THREE CATEGORIES, not rf-plasma alone (#86, #87). While plasma was the
        # only contained family the two were the same thing; with three, a canary that hunts for
        # rf-plasma proves the gate catches a lost plasma category and says nothing about the two
        # energy ones -- and the sentence above would have been quietly false. The list is written in
        # from $DECLARED_CATEGORIES so it cannot drift from what the floor requires, and the canary
        # records WHICH category it took as well as from which prototype, because the assertion below
        # compares both.
        (@'
local CATEGORIES = { __CATEGORIES__ }

local function contained_as(cat)
  for _, wanted in ipairs(CATEGORIES) do
    if cat == wanted then return wanted end
    if type(cat) == "table" then
      for _, one in pairs(cat) do
        if one == wanted then return wanted end
      end
    end
  end
  return nil
end

local taken = nil

local function break_one(node, seen)
  if type(node) ~= "table" or seen[node] then return nil end
  seen[node] = true
  if node.pipe_connections then
    for _, c in pairs(node.pipe_connections) do
      local was = contained_as(c.connection_category)
      if was then
        c.connection_category = "pipe-to-ground"
        taken = was
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
  error("load-check canary: no connection carrying any of " .. table.concat(CATEGORIES, ", ")
    .. " to reassign, so half four would prove nothing")
end
-- Both halves of what it did, in one field, because an item has no second free string field and a
-- second prototype would be a second thing for half three's asset walk to trip over.
data.raw.item["rf-loadcheck-canary-item"].order = victim .. "|" .. taken
'@).Replace('__CATEGORIES__',
                (($DECLARED_CATEGORIES | ForEach-Object { "'$_'" }) -join ', ')) |
            Set-Content -Path (Join-Path $canary 'data-final-fixes.lua') -Encoding utf8
        # Valid, and with an icon that exists this time: half three's missing icon would fail the
        # asset check rather than reaching this one.
        'data:extend({{ type = "item", name = "rf-loadcheck-canary-item", stack_size = 1,
  icon = "__base__/graphics/icons/iron-plate.png", icon_size = 64 }})' |
            Set-Content -Path (Join-Path $canary 'data.lua') -Encoding utf8

        Write-Host 'self-test 4/11: a set reassigning one of our containment categories must be caught.'
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

        $recorded = (Get-Content -LiteralPath $loadedDumpPath -Raw |
            ConvertFrom-Json).item.'rf-loadcheck-canary-item'.order
        if (-not $recorded -or $recorded -notmatch '^(.+)\|(.+)$') {
            Write-Host ''
            Write-Host 'FAILED - self-test: the containment canary recorded no victim, so it never found'
            Write-Host '         a contained connection to reassign and this half proves nothing.'
            exit 1
        }
        $victim, $takenCategory = $Matches[1], $Matches[2]

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
        if (-not @($named | Where-Object { $_.Missing -ccontains $takenCategory })) {
            Write-Host ''
            Write-Host "FAILED - self-test: the breach reported on $victim does not name $takenCategory as"
            Write-Host '         the category lost, so the row would not tell a reader what was taken.'
            foreach ($b in $named) { Write-Host "           $($b.Connection): lost $($b.Missing -join ', ')" }
            exit 1
        }

        # Half five: a machine whose rendered art no longer fits it must be caught (#250). The victim
        # is whatever the first manifest records -- a hard-coded machine would fail this half the day
        # it was re-rendered under another name -- and the canary slides that machine's first
        # connection one tile ALONG its edge, towards the centre. Along, because a connection off its
        # edge is a prototype Factorio refuses, and a canary that cannot load proves nothing about a
        # gate that runs after the load. Towards the centre, so it stays on the footprint whatever the
        # machine's size.
        $renderManifests = Get-RenderManifests -AssetsDirectory (Join-Path $repoRoot $ASSETS_MOD)
        if (-not $renderManifests) {
            Write-Host ''
            Write-Host "FAILED - self-test: no graphics/rendered/*/manifest.json under $ASSETS_MOD, so"
            Write-Host '         half five has no render to disagree with.'
            exit 1
        }
        $renderVictim = (Get-Content -LiteralPath $renderManifests[0].FullName -Raw | ConvertFrom-Json).geometry
        $slid = $renderVictim.connections[0]
        if (-not $slid) {
            Write-Host ''
            Write-Host "FAILED - self-test: $($renderVictim.name)'s manifest records no connection to slide."
            exit 1
        }
        # The manifest's box path is dotted with zero-based indices; Lua wants brackets and one-based.
        $boxLua = ($slid.box -split '\.' | ForEach-Object {
            if ($_ -match '^\d+$') { "[$([int]$_ + 1)]" } else { "[`"$_`"]" } }) -join ''
        $axis  = if ($slid.direction -in @('north', 'south')) { 1 } else { 2 }
        $named = if ($axis -eq 1) { 'x' } else { 'y' }
        $delta = if ($slid.position[$axis - 1] -le 0) { 1 } else { -1 }
        @"
local proto = data.raw["$($renderVictim.type)"]["$($renderVictim.name)"]
local slid = false
for _, c in pairs(proto$boxLua.pipe_connections) do
  local p = c.position
  if p and (p[1] or p.x) == $($slid.position[0]) and (p[2] or p.y) == $($slid.position[1]) then
    if p[$axis] then p[$axis] = p[$axis] + ($delta) else p.$named = p.$named + ($delta) end
    slid = true
  end
end
if not slid then
  error("load-check canary: no connection at ($($slid.position[0]), $($slid.position[1])) on $($renderVictim.name) to slide, so half five would prove nothing")
end
"@ | Set-Content -Path (Join-Path $canary 'data-final-fixes.lua') -Encoding utf8

        Write-Host "self-test 5/11: a machine whose rendered art no longer fits it must be caught."
        $renderDump = Invoke-DataDump -Mods ($ourMods + 'rf-loadcheck-canary') -Tag 'render-loaded'
        $disagreements = @(Get-RenderDisagreements -DumpPath $renderDump -Manifests $renderManifests)
        $onVictim = @($disagreements | Where-Object { $_.Prototype -eq $renderVictim.name -and $_.Field -eq 'connections' })
        if (-not $onVictim) {
            Write-Host ''
            Write-Host "FAILED - self-test: the canary slid a connection on $($renderVictim.name) and the"
            Write-Host '         rendered-art check did NOT report a disagreement on its connections.'
            Write-Host '         The sprite would keep showing a socket where the pipe no longer is.'
            if ($disagreements) {
                Write-Host "         It reported $($disagreements.Count) other row(s):"
                foreach ($d in $disagreements) { Write-Host "           $($d.Prototype)  $($d.Field)" }
            }
            exit 1
        }
        # Only the connections may disagree: the canary touched nothing else, so a footprint row here
        # would mean the comparison is reading something other than the slide it was shown.
        $stray = @($disagreements | Where-Object { -not ($_.Prototype -eq $renderVictim.name -and $_.Field -eq 'connections') })
        if ($stray) {
            Write-Host ''
            Write-Host "FAILED - self-test: the canary slid one connection but the check also reported:"
            foreach ($d in $stray) { Write-Host "           $($d.Prototype)  $($d.Field)" }
            exit 1
        }

        # Half six: another mod ADDING a connection category must NOT be reported as the art having
        # come loose. This is the coexistence half, and it is the inverse of half five: five requires
        # a moved socket to be caught, six requires an untouched one to stay quiet while a third-party
        # mod writes on it. Krastorio 2 does exactly this -- it puts `kr-steel-pipe` on the fluid
        # boxes of machines it never heard of -- so before this half existed, `load-check.ps1
        # -AlsoModDirectory .mod-cache/krastorio2` failed on rf-heat-exchanger with four connections
        # whose position, direction, flow and fluid all matched and whose category did not. That is
        # ADR 0007's coexistence reported as ADR 0030's art being wrong, and it made #18's story 35 --
        # the same load-check runnable with Krastorio 2 present -- false.
        #
        # THE VICTIM IS AN UNCONTAINED CONNECTION, chosen rather than taken, and for a sharper reason
        # than "that is what Krastorio 2 writes on". Uncontained is exactly the class
        # Get-ContainmentBreaches does not cover -- its $contained predicate is false for a set that
        # is only `default` -- so this is precisely where the rendered-art gate is the only one
        # asserting anything, and precisely where a tolerance has to be demonstrated rather than
        # assumed.
        #
        # It self-heals as the repo changes: $addable filters on the RECORDED category, so when
        # ADR 0018's containment reaches this box (#86, #258) the half moves itself to a water
        # connection, and bails loudly only when every recorded connection is contained. Do not
        # replace the filter with a hard-coded box.
        $addable = @($renderVictim.connections | Where-Object { -not $_.connection_category })
        if (-not $addable) {
            Write-Host ''
            Write-Host "FAILED - self-test: every connection $($renderVictim.name)'s manifest records is"
            Write-Host '         already contained, so half six has no uncontained one to write a'
            Write-Host '         category onto and would prove nothing.'
            exit 1
        }
        $added    = $addable[0]
        $addedCat = 'rf-loadcheck-coexist'
        $addBoxLua = ($added.box -split '\.' | ForEach-Object {
            if ($_ -match '^\d+$') { "[$([int]$_ + 1)]" } else { "[`"$_`"]" } }) -join ''
        @"
local proto = data.raw["$($renderVictim.type)"]["$($renderVictim.name)"]
local touched = false
for _, c in pairs(proto$addBoxLua.pipe_connections) do
  local p = c.position
  if p and (p[1] or p.x) == $($added.position[0]) and (p[2] or p.y) == $($added.position[1]) then
    c.connection_category = { "default", "$addedCat" }
    touched = true
  end
end
if not touched then
  error("load-check canary: no connection at ($($added.position[0]), $($added.position[1])) on $($renderVictim.name) to add a category to, so half six would prove nothing")
end
"@ | Set-Content -Path (Join-Path $canary 'data-final-fixes.lua') -Encoding utf8

        Write-Host "self-test 6/11: another mod adding a connection category must NOT be reported."
        $coexistDump = Invoke-DataDump -Mods ($ourMods + 'rf-loadcheck-canary') -Tag 'render-coexist'

        # The canary reaching the GEOMETRY, proved rather than assumed. This half passes by finding
        # nothing, and there are two ways to pass it dishonestly. This pre-check rules out the first:
        # a canary that missed, leaving nothing for the gate to report. It does NOT rule out the
        # second -- it calls the extractor directly and never touches Get-RenderDisagreements, so
        # gutting that function to `return @()` would sail through here. **Half five is what stops
        # that**, because it runs the same function first and requires a row. The two halves are load
        # bearing for each other: do not delete five believing six covers a dead gate.
        $coexistLines = @(& python (Join-Path $repoRoot 'tools/extract-geometry.py') $renderVictim.name `
            --dump $coexistDump --stdout 2>&1 | ForEach-Object { "$_" })
        if ($LASTEXITCODE -ne 0) {
            Write-Host ''
            Write-Host "FAILED - self-test: the extractor exited $LASTEXITCODE on $($renderVictim.name) under the"
            Write-Host '         coexistence canary, so half six never saw the geometry it is about.'
            Write-Host "         $($coexistLines | Select-Object -Last 1)"
            exit 1
        }
        $coexistLive = ($coexistLines -join "`n") | ConvertFrom-Json
        $carrying = @($coexistLive.connections | Where-Object {
            $_.box -ceq $added.box -and
            $_.position[0] -eq $added.position[0] -and $_.position[1] -eq $added.position[1] -and
            $_.connection_category -ccontains $addedCat })
        if (-not $carrying) {
            Write-Host ''
            Write-Host "FAILED - self-test: the canary's category '$addedCat' is not on the live"
            Write-Host "         geometry of $($renderVictim.name) at ($($added.position[0]), $($added.position[1])), so a quiet"
            Write-Host '         gate below would mean the canary missed rather than that the gate tolerated it.'
            exit 1
        }

        $coexistRows = @(Get-RenderDisagreements -DumpPath $coexistDump -Manifests $renderManifests)
        if ($coexistRows) {
            Write-Host ''
            Write-Host "FAILED - self-test: a third-party mod added a connection category to"
            Write-Host "         $($renderVictim.name) and the rendered-art check reported it as a"
            Write-Host '         disagreement. Nothing moved: a category says what may connect, not where'
            Write-Host '         the socket is, so an addition is a coexisting mod working as intended.'
            foreach ($d in $coexistRows) {
                Write-Host "           $($d.Prototype)  $($d.Field)"
                Write-Host "             recorded: $($d.Recorded)"
                Write-Host "             live:     $($d.Live)"
            }
            exit 1
        }

        # Half seven: another mod REPLACING a connection category must be caught. Six and seven are
        # one pair and neither is worth much alone -- six alone is a gate that could tolerate
        # everything, including a category being taken away, which is the change that would cut a
        # machine off from every ordinary pipe in the game. Seven is what makes the subset semantics
        # a check rather than a decoration, and it is their only canary: the containment floor does
        # not reach these connections at all, and probe-connection-categories.ps1 reports on them
        # without asserting anything.
        #
        # The same victim as half six, and deliberately so. `default` is what the engine reads an
        # absent category as, so a set that writes a category of its own and drops `default` has
        # removed something that was there without the manifest ever having recorded a word.
        @"
local proto = data.raw["$($renderVictim.type)"]["$($renderVictim.name)"]
local touched = false
for _, c in pairs(proto$addBoxLua.pipe_connections) do
  local p = c.position
  if p and (p[1] or p.x) == $($added.position[0]) and (p[2] or p.y) == $($added.position[1]) then
    c.connection_category = { "$addedCat" }
    touched = true
  end
end
if not touched then
  error("load-check canary: no connection at ($($added.position[0]), $($added.position[1])) on $($renderVictim.name) to replace the category of, so half seven would prove nothing")
end
"@ | Set-Content -Path (Join-Path $canary 'data-final-fixes.lua') -Encoding utf8

        Write-Host "self-test 7/11: another mod replacing a connection category must be caught."
        $replacedDump = Invoke-DataDump -Mods ($ourMods + 'rf-loadcheck-canary') -Tag 'render-replaced'
        $replacedRows = @(Get-RenderDisagreements -DumpPath $replacedDump -Manifests $renderManifests)
        $onCategories = @($replacedRows | Where-Object {
            $_.Prototype -eq $renderVictim.name -and $_.Field -eq 'connection categories' })
        if (-not $onCategories) {
            Write-Host ''
            Write-Host "FAILED - self-test: the canary took 'default' off a connection of"
            Write-Host "         $($renderVictim.name) and the rendered-art check did NOT report it. Nothing"
            Write-Host '         else GATES that connection -- the containment floor skips anything we'
            Write-Host '         left `default` -- so the machine would quietly stop accepting every'
            Write-Host '         ordinary pipe in the game.'
            if ($replacedRows) {
                Write-Host "         It reported $($replacedRows.Count) other row(s):"
                foreach ($d in $replacedRows) { Write-Host "           $($d.Prototype)  $($d.Field)" }
            }
            exit 1
        }
        # Named, not merely counted, for the reason half four compares names: the row is the value.
        if (-not @($onCategories | Where-Object { $_.Live -match 'lost .*\bdefault\b' })) {
            Write-Host ''
            Write-Host "FAILED - self-test: the row reported on $($renderVictim.name) does not name 'default'"
            Write-Host '         as the category lost, so it would not tell a reader what was taken.'
            foreach ($d in $onCategories) { Write-Host "           $($d.Recorded) -> $($d.Live)" }
            exit 1
        }

        # Half eight: a reactor whose network can never pay for its heating must be refused (#72).
        #
        # UNLIKE EVERY HALF ABOVE IT, this one is not about a mod breaking our prototypes from
        # outside -- it is about a developer edit to our own. check_input_flow() replaced
        # check_cadence() when per-tick spending dissolved the coupling between UPDATE_INTERVAL and
        # buffer_capacity, and the invariant that became load-bearing is
        # input_flow_limit >= heating_power_w. Break that and the reactor is starved for ever,
        # silently, because underpowered is a legitimate state a reactor is meant to have. The
        # canary makes the edit from outside because that is the only way to make it without
        # editing the repo.
        #
        # IT MUST FAIL BY THE CHECK'S OWN WORDS, not merely fail. check_input_flow() runs from
        # on_init, so it fires while --create builds the map -- but so does every other refusal in
        # control.lua, and a canary that happened to break something else would look identical.
        # The assertion therefore reads the captured output for the message this check alone emits.
        '(function()
  local source = data.raw.boiler["rf-reactor"].energy_source
  if not source.input_flow_limit then
    error("load-check canary: rf-reactor declares no input_flow_limit, so half eight would prove nothing")
  end
  source.input_flow_limit = "1W"
end)()' | Set-Content -Path (Join-Path $canary 'data-final-fixes.lua') -Encoding utf8

        Write-Host 'self-test 8/11: a reactor that can never be paid its heating must be refused.'
        $starved = Invoke-LoadCheck -Label 'load-check' -Enabled ($ourMods + 'rf-loadcheck-canary') -Tag 'flow'
        if ($starved.Code -eq 0) {
            Write-Host ''
            Write-Host "FAILED - self-test: rf-reactor's input_flow_limit was cut to 1 W and the mod loaded"
            Write-Host '         anyway. check_input_flow() is not proving anything, so a reactor that can'
            Write-Host '         never be paid its confinement heating would ship as a balance problem.'
            exit 1
        }
        $starvedSaid = (Test-Path $starved.OutFile) -and
            (Select-String -Path $starved.OutFile -SimpleMatch 'input_flow_limit admits only' -Quiet)
        if (-not $starvedSaid) {
            Write-Host ''
            Write-Host "FAILED - self-test: the starved-reactor canary failed the load (exit $($starved.Code)) but"
            Write-Host '         check_input_flow() did not say so, so the failure was something else and'
            Write-Host '         this half proves nothing about the invariant it is named for.'
            Write-FactorioTail $starved
            exit 1
        }

        # Half nine: a machine whose MOCKUP no longer fits it must be caught (#275). The render gate's
        # twin for the other kind of art. The victim is the first machine in mockup-machines.psd1
        # that has a connection -- read from the table, so it follows whatever wears a mockup -- and
        # the canary slides that connection one tile along its edge towards the centre, for the same
        # two reasons half five does: along keeps the prototype loadable, towards the centre keeps it
        # on the footprint.
        #
        # The table records neither the box a connection belongs to nor its direction, so the canary
        # walks every pipe_connections list in the prototype for the tile, and the edge is read off
        # the table: a connection at x = +-(Width - 1) / 2 stands on a west or east edge and slides in
        # y, anything else stands north or south and slides in x.
        $mockupMachines = Get-MockupMachines
        $mockupVictim = $mockupMachines | Where-Object { $_.Connections.Count -gt 0 } | Select-Object -First 1
        if (-not $mockupVictim) {
            Write-Host ''
            Write-Host "FAILED - self-test: no machine in $MOCKUP_TABLE has a connection to slide, so"
            Write-Host '         half nine has no mockup to disagree with.'
            exit 1
        }
        $mockupSlid = $mockupVictim.Connections[0]
        $mockupName = "rf-$($mockupVictim.Name)"
        $onSide     = [Math]::Abs($mockupSlid.X) -eq ($mockupVictim.Width - 1) / 2
        $mAxis      = if ($onSide) { 2 } else { 1 }
        $mNamed     = if ($mAxis -eq 1) { 'x' } else { 'y' }
        $mCoord     = if ($mAxis -eq 1) { $mockupSlid.X } else { $mockupSlid.Y }
        $mDelta     = if ($mCoord -le 0) { 1 } else { -1 }
        @"
local proto = data.raw["$($mockupVictim.Prototype)"]["$mockupName"]
local function walk(node, seen)
  if type(node) ~= "table" or seen[node] then return false end
  seen[node] = true
  local slid = false
  if node.pipe_connections then
    for _, c in pairs(node.pipe_connections) do
      local p = c.position
      if p and (p[1] or p.x) == $($mockupSlid.X) and (p[2] or p.y) == $($mockupSlid.Y) then
        if p[$mAxis] then p[$mAxis] = p[$mAxis] + ($mDelta) else p.$mNamed = p.$mNamed + ($mDelta) end
        slid = true
      end
    end
  end
  for _, v in pairs(node) do slid = walk(v, seen) or slid end
  return slid
end
if not walk(proto, {}) then
  error("load-check canary: no connection at ($($mockupSlid.X), $($mockupSlid.Y)) on $mockupName to slide, so half nine would prove nothing")
end
"@ | Set-Content -Path (Join-Path $canary 'data-final-fixes.lua') -Encoding utf8

        Write-Host 'self-test 9/11: a machine whose mockup no longer fits it must be caught.'
        $mockupDump = Invoke-DataDump -Mods ($ourMods + 'rf-loadcheck-canary') -Tag 'mockup-loaded'
        $mockupRows = @(Get-MockupDisagreements -DumpPath $mockupDump -Machines $mockupMachines)
        $onMockup = @($mockupRows | Where-Object { $_.Prototype -eq $mockupName -and $_.Field -eq 'connections' })
        if (-not $onMockup) {
            Write-Host ''
            Write-Host "FAILED - self-test: the canary slid a connection on $mockupName and the mockup"
            Write-Host '         check did NOT report a disagreement on its connections. The mockup would'
            Write-Host '         keep marking a pipe on a tile the machine no longer has one on.'
            if ($mockupRows) {
                Write-Host "         It reported $($mockupRows.Count) other row(s):"
                foreach ($d in $mockupRows) { Write-Host "           $($d.Prototype)  $($d.Field)" }
            }
            exit 1
        }
        # Only that machine's connections may disagree: the canary touched nothing else.
        $mockupStray = @($mockupRows | Where-Object { -not ($_.Prototype -eq $mockupName -and $_.Field -eq 'connections') })
        if ($mockupStray) {
            Write-Host ''
            Write-Host "FAILED - self-test: the canary slid one connection but the mockup check also reported:"
            foreach ($d in $mockupStray) { Write-Host "           $($d.Prototype)  $($d.Field)" }
            exit 1
        }

        # Half ten: a plasma no reactor can burn must be refused (#125). The first half to prove one
        # of check_prototypes()'s invariants -- the checks that tie the simulation to the prototypes
        # and are the reason load-check is the gate that matters here. Until #125 every one of them
        # was asserted only positively: they pass on a good tree, and nothing here would have
        # noticed one that had quietly stopped firing.
        #
        # WHY THIS INVARIANT, and it is not "whichever was easiest to break". It is the only one a
        # canary can trip by pure ADDITION -- the canary defines a fluid and a recipe of its OWN in
        # our heating category and mutates nothing of ours -- so it is the cheapest negative test in
        # the set. And it is not a contrived break: check_every_plasma_burns's own docstring says a
        # fluid another mod produces through our category "is genuinely a plasma a reactor cannot
        # burn, which is worth refusing to load over whoever wrote it". This half is that sentence
        # run rather than read.
        #
        # THE CATEGORY IS NAMED HERE AND GUARDED HERE. control.lua's HEATING_CATEGORY is the other
        # copy of the string; a rename there would leave this canary adding a recipe to a category
        # nothing reads, which is a half that passes by proving nothing. The guard makes that a loud
        # failure instead -- the same shape as every other canary's "would prove nothing" bail.
        @'
if not data.raw["recipe-category"]["rf-plasma-heating"] then
  error("load-check canary: no rf-plasma-heating recipe category to add a plasma to, so half ten "
    .. "would prove nothing -- control.lua's HEATING_CATEGORY has been renamed")
end
data:extend({
  { type = "fluid", name = "rf-loadcheck-canary-plasma",
    icon = "__base__/graphics/icons/fluid/steam.png", icon_size = 64,
    default_temperature = 15, max_temperature = 1e9,
    base_color = { r = 1, g = 0, b = 1 }, flow_color = { r = 1, g = 0, b = 1 } },
  { type = "recipe", name = "rf-loadcheck-canary-plasma",
    category = "rf-plasma-heating", energy_required = 1,
    ingredients = { { type = "fluid", name = "water", amount = 1 } },
    results = { { type = "fluid", name = "rf-loadcheck-canary-plasma", amount = 1 } } },
})
'@ | Set-Content -Path (Join-Path $canary 'data-final-fixes.lua') -Encoding utf8

        Write-Host 'self-test 10/11: a plasma no reactor knows how to burn must be refused.'
        $unburnable = Invoke-LoadCheck -Label 'load-check' -Enabled ($ourMods + 'rf-loadcheck-canary') -Tag 'plasma'
        if ($unburnable.Code -eq 0) {
            Write-Host ''
            Write-Host 'FAILED - self-test: a canary put a fluid of its own through rf-plasma-heating and the'
            Write-Host '         mod loaded anyway. check_every_plasma_burns() is not proving anything, so a'
            Write-Host '         plasma with no fuel row would sit in a reactor for ever while the reactor'
            Write-Host '         reported itself starved -- indistinguishable from an empty pipe.'
            exit 1
        }
        # BY THE CHECK'S OWN WORDS, not merely non-zero, for the reason half eight matches: a canary
        # that failed to load for an unrelated reason -- a typo, a prototype the engine rejects --
        # exits non-zero too, and would be recorded here as the invariant firing.
        $unburnableSaid = (Test-Path $unburnable.OutFile) -and
            (Select-String -Path $unburnable.OutFile -SimpleMatch 'has no fuel entry for' -Quiet)
        if (-not $unburnableSaid) {
            Write-Host ''
            Write-Host "FAILED - self-test: the unburnable-plasma canary failed the load (exit $($unburnable.Code)) but"
            Write-Host '         check_every_plasma_burns() did not say so, so the failure was something else'
            Write-Host '         and this half proves nothing about the invariant it is named for.'
            Write-FactorioTail $unburnable
            exit 1
        }

        # Half eleven: a collector whose boxes are not what deposit() writes to must be refused
        # (#125). Ten proves an invariant fires over a prototype the canary ADDED; this one proves
        # one fires over a prototype the canary MOVED, which is the route the remaining invariants
        # need. Half eight already mutates one of ours from outside, so the mechanism is not new
        # here -- what is new is that the break is a swap of two declarations rather than a number,
        # so there is no value to get wrong and the diagnostic names the box index.
        #
        # WHY THIS INVARIANT: control.lua calls it "the third trap of the same shape, and the one
        # most likely to fire". deposit() writes tritium to box 1 and helium-3 to box 2 by index,
        # because asking a fluidbox its filter ten times a second buys an answer that cannot change
        # while the game runs -- so swapping the two declarations in prototypes/entities.lua loads
        # clean, fills the collector, and carries helium-3 down a player's tritium pipe.
        @'
local collector = data.raw.boiler["rf-isotope-collector"]
local first  = collector.fluid_box and collector.fluid_box.filter
local second = collector.output_fluid_box and collector.output_fluid_box.filter
if not first or not second or first == second then
  error("load-check canary: rf-isotope-collector does not declare two distinctly filtered boxes ("
    .. tostring(first) .. ", " .. tostring(second) .. "), so half eleven would prove nothing")
end
collector.fluid_box.filter, collector.output_fluid_box.filter = second, first
'@ | Set-Content -Path (Join-Path $canary 'data-final-fixes.lua') -Encoding utf8

        Write-Host 'self-test 11/11: a collector whose two boxes are swapped must be refused.'
        $swapped = Invoke-LoadCheck -Label 'load-check' -Enabled ($ourMods + 'rf-loadcheck-canary') -Tag 'boxes'
        if ($swapped.Code -eq 0) {
            Write-Host ''
            Write-Host "FAILED - self-test: rf-isotope-collector's two box filters were swapped and the mod"
            Write-Host '         loaded anyway. check_collector_boxes() is not proving anything, so a'
            Write-Host "         player's tritium pipe would quietly carry helium-3."
            exit 1
        }
        $swappedSaid = (Test-Path $swapped.OutFile) -and
            (Select-String -Path $swapped.OutFile -SimpleMatch 'would leave through the wrong pipe' -Quiet)
        if (-not $swappedSaid) {
            Write-Host ''
            Write-Host "FAILED - self-test: the swapped-boxes canary failed the load (exit $($swapped.Code)) but"
            Write-Host '         check_collector_boxes() did not say so, so the failure was something else'
            Write-Host '         and this half proves nothing about the invariant it is named for.'
            Write-FactorioTail $swapped
            exit 1
        }

        # THE WORKING TREE, ASSERTED RATHER THAN REASONED ABOUT (#125). Halves eight, ten and eleven
        # break our own prototypes to prove our own checks fire, and they do it in data-final-fixes
        # -- in memory, at load, with nothing on disk touched. That is the design; this is the
        # assertion. It is here because a self-test in this file once deleted the repository's own
        # sprite, so "the mutation is in memory" is a claim to check rather than one to trust.
        $treeAfter = Get-ModTreeFingerprint -Mods $ourMods
        $moved = @(Compare-Object -ReferenceObject $treeBefore -DifferenceObject $treeAfter)
        if ($moved) {
            Write-Host ''
            Write-Host "FAILED - self-test: $($moved.Count) file(s) under our mod directories changed during"
            Write-Host '         the run. The canary halves must break our prototypes in memory only.'
            foreach ($m in $moved) {
                $side = if ($m.SideIndicator -eq '=>') { 'now' } else { 'was' }
                Write-Host "           $side  $($m.InputObject)"
            }
            exit 1
        }

        Write-Host ''
        Write-Host 'OK - self-test passed: clean repo loads, invalid prototype rejected'
        Write-Host "     (exit $($broken.Code)), missing asset caught, a reassigned containment"
        Write-Host "     category caught by name on $victim, a slid connection caught on"
        Write-Host "     $($renderVictim.name)'s rendered art, an added category tolerated on it,"
        Write-Host '     a replaced one caught by name, a reactor whose input_flow_limit'
        Write-Host '     cannot cover its heating refused by check_input_flow(), a slid'
        Write-Host "     connection caught on $mockupName's mockup, an unburnable plasma"
        Write-Host '     refused by check_every_plasma_burns() and a swapped collector box'
        Write-Host '     refused by check_collector_boxes() -- both by their own words -- and'
        Write-Host "     $($treeBefore.Count) files under our mod directories untouched by the run."
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

        # Before the asset check for the same reason containment is: the upstream asset reds must
        # not hide it. Reads the loaded dump, so a set moving our connection fails it (#250).
        Test-RenderedArt -DumpPath $loadedDump

        # The mockups' hand-copied table, held against the same dump (#275). Beside the render gate
        # because it is the same question asked of the other kind of art: is the picture drawn where
        # the pipes are.
        Test-MockupArt -DumpPath $loadedDump

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
    Write-Host "     simulation's thirteen load-time invariants hold, containment survived the"
    Write-Host "     load and every render and mockup agrees with its machine, loading from $how."
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

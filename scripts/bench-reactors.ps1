<#
.SYNOPSIS
    Measures what a simulated reactor costs per tick. Discharges the measurement half of #24.

.DESCRIPTION
    Builds a rig of N reactors in a headless save and benchmarks it, for several N, then reports
    the per-reactor cost as the slope. Written down as a script rather than as a procedure because
    ADR 0005's real obligation is the later measurement against the full reaction set (#34), and
    that one has to be the same measurement or the comparison means nothing.

    METHOD

    Three things make the number trustworthy, and all three are the reason this is not just
    "run --benchmark and look at avg":

    1. --benchmark-verbose reports per-tick timings by category, in nanoseconds. scriptUpdate is
       the control stage -- every mod's Lua, and nothing else. It isolates our cost from the
       engine's without needing a baseline at all. wholeUpdate is reported alongside it for
       context, and fluidFlowUpdate because the reactor is a boiler on a fluid segment, so some
       of what this mod costs is charged to the engine rather than to us.
    2. Every run builds the same map. The power, the flattened ground and the generated chunks are
       sized for the largest N and built identically at every N, including N = 0. Only the reactors
       differ, so a difference between runs is reactors.
    3. Mean and median are both reported, because they answer different questions and the mod
       does not update every tick. The mean is the cost -- averaged over thousands of ticks it is
       what UPS spends, and it is what the per-reactor figure is taken from. The median is what a
       tick feels like, and it is the more honest description of per-tick work: a run carries
       spikes an order of magnitude above the typical tick, and a mean over a thousand ticks is
       visibly moved by three of them. Under throttling the two separate by construction, which
       is why neither is dropped.

    The reactors are held full of plasma at a fusion temperature, because an empty reactor returns
    early from the simulation step and a rig that let its reactors run dry would measure the early
    return. They are also given real power through a real electric network -- not for that reason,
    since an unpowered reactor runs the whole step with its heating clamped to zero and costs the
    same, but because a reactor that cannot hold its temperature is not the thing worth measuring.
    The rig logs its own state during the run and the script refuses to report a number unless
    every reactor was present, hot and on an electric network when it did.

    The rig reads the reactor's footprint from its own prototype and derives every distance from
    it -- cell pitch, feed pipe, power. It used to hardcode them, which is issue #49: the numbers
    were right for the 3x2 reactor they were written against and silently wrong once the reactor
    became 15x15, and only the "every reactor hot" gate caught it. Nothing here is a remembered
    number.

    WHAT IT DOES NOT MEASURE

    Rig cost, chiefly the power, is present in every run including the baseline and so cancels out
    of the deltas -- but it does inflate wholeUpdate everywhere, and it is not small: a substation
    reaches 18 tiles and a cell is wider than that, so every cell needs its own substation and
    interface rather than sharing one grid. And a rig is not a factory: no belts, no trains, no
    biters, one surface. #34 did not close that half either -- it is #67's job, behind #64 and #65.
    This one exists to catch a disaster eleven tickets before #34 would.

    -Save IS THE ANSWER TO "A RIG IS NOT A FACTORY", AND IT COSTS THE SLOPE (#64). Pointed at a save
    this script did not build, it reports the same categories over the same tick counts with the same
    statistics -- and it can report no per-reactor figure at all, because there is no n = 0 baseline
    for somebody else's factory and every per-reactor number here is a subtraction against one. What
    it delivers instead is the absolute cost of that map and the reactor census behind it. See
    .PARAMETER Save.

    -PlantInto BUYS THE SLOPE BACK (#65), by not asking anyone to un-build a factory. It builds the
    rig on a surface of ITS OWN inside somebody else's save, so those reactors were never in that
    save and the same save with this mod switched off is the n = 0 baseline -- the identical map,
    the identical factory, no reactors. That is a real subtraction on a tick the rig cannot produce,
    and it is what ADR 0005 has been waiting for since #34. See .PARAMETER PlantInto.

    Nor does it resolve small differences. Ten invocations of the same binary on the same map, none
    of them flagged BUSY, spanned 1.34x (docs/research/reactor-runtime-cost.md, #39); treat anything
    finer than about 1.4x as unmeasured. That one applies to -Save as much as to the rig.

    AND IT CANNOT SUBTRACT THE REST OF THE MACHINE. Every figure it reports is a difference between
    two Factorio processes minutes apart, so work that starts between the baseline and the
    measurement lands on the difference rather than cancelling with the rig's power. That is what
    produced the figures #39 was opened to explain. -BusyPercent below is the instrument; a run that
    prints BUSY is not one to quote from.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Save
    Benchmark this save instead of building a rig (#64). Every rig switch is refused alongside it
    rather than ignored, because a report that named a mix or a fitting the save may not contain
    would be a claim about the wrong map.

    TWO THINGS DO NOT SURVIVE THE MOVE, and the output says both rather than leaving them to be
    assumed.

    There is NO n = 0 BASELINE, so no subtraction and no per-reactor figure. The rig can build the
    same map twice and vary only the reactors; an existing factory cannot be un-built. What comes
    out is the absolute cost of that map, which is the figure ADR 0005 actually needs and the one
    the rig can never produce.

    WHAT DOES SURVIVE IS THE OBLIGATION TO PROVE THE SIMULATION RAN, and it is met by a different
    instrument. The rig gates on reactor energy produced, which works because nothing drains a
    rig's output box; a factory drains it, so an amount in the box says nothing about who put it
    there. Instead the census plants a signal of its own in each reactor's companion combinator and
    looks for it again at the end of the run -- circuit-output.lua assigns that combinator's whole
    filter list on every reporting tick, so a sentinel that survived means nothing stepped that
    reactor. Counting reactors proves they exist; this is what proves they are being simulated, and
    the run refuses rather than reporting the cost of entities nobody is stepping. Both failure
    branches are poison-tested -- see the survey mod for the figures.

    And A SAVE CARRIES ITS OWN MOD SET, so scriptUpdate is every enabled mod's Lua rather than this
    repo's. The script knows which mods it enabled and says which of the two the column means: on a
    save that enables nothing but this repo, scriptUpdate is this repo's Lua and the scenario script
    the map was started from, which runs as __level__ and is never absent. On any other save it is
    that plus every other mod, and nothing here can separate them -- Factorio's per-mod time usage is
    a debug view in the client, not a --benchmark column.

    HOW THE MOD SET IS ESTABLISHED, and why it is read out of the save rather than left to the game.
    Factorio does not refuse a save whose mods are absent. Measured on 2.0.77, `--benchmark` over a
    twenty-five-mod Bob's-and-Space-Age save with base alone enabled loaded it, ran, exited 0 and
    printed no warning of any kind -- so a run that silently measured a map with every mod's entities
    stripped out of it would look exactly like a good one. The save's own mod list is therefore parsed
    out of its level-init.dat header and each name resolved against -SaveModDirectory and the game's
    bundled mods; anything unresolved is named and the run refuses to start. That is acceptance
    criterion five of #64, and it is a check this script has to do because the engine will not.

    `--sync-mods` is the obvious alternative and is deliberately not used: it downloads from the mod
    portal, so it needs credentials, reaches the network from a benchmark, and can install a mod
    nobody asked for. Resolving against what is already on disk cannot do any of the three.

    Version differences are a warning rather than a refusal -- Factorio migrates a save across a mod
    version, and measuring the WORKING TREE against a save built by an older build of the same mod is
    a thing somebody will legitimately want to do. This repo's own mods are always junctioned from the
    working tree and win over any installed copy of the same name, because measuring a released zip
    while editing the repo is the one outcome nobody wants. The bundled mods -- space-age, quality,
    elevated-rails -- are matched by name only and never by version: they ship inside the game, so
    the installed build is the only one there is and a warning on every save older than the current
    patch would be noise. The header line prints what the save asked for, so the difference is on
    the record either way.

.PARAMETER PlantInto
    Build the rig on a surface of its own inside this save, and sweep -Counts against it (#65). The
    BORROWED BASE: somebody else's factory, loading the engine the way a rig by construction cannot,
    with our reactors beside it rather than in it.

    A THIRD MODE, not a modifier on -Save, and that is deliberate. -Save benchmarks a map exactly as
    it is and refuses every switch describing a rig, because a report naming a mix the save may not
    contain would be a claim about the wrong map. Here the switches are HONOURED, because this mode
    is what built the configuration -- and -Save's contract is untouched.

    All eight of them, enumerated rather than gestured at, since seven behave and one does not:
    -Counts, -Pooled, -Mixed, -Collectors, -Blankets, -Gap and -ReportEvery mean exactly what they
    mean in a rig. -Ablate is REFUSED, and the reason is below.

    WHY THIS GETS A PER-REACTOR FIGURE AND -Save CANNOT. Every per-reactor number here is
    (cost at n minus cost at 0) / n, and -Save has no n = 0 because a factory cannot be un-built.
    These reactors were never in the borrowed base: they are created by on_init as this mod is added
    to it, on a surface this mod also creates. So n = 0 is the same save with COUNT set to zero --
    the same factory, the same tick, the same mod loaded, the same surface generated and powered --
    and the difference between that and n = 200 is reactors and nothing else. The rig's whole method
    survives the move; only the ground under it changes.

    MEASURED ON 2.0.77 BEFORE ANY OF THIS WAS WRITTEN, because the mode rests on it: a mod newly
    added to an existing save DOES run its on_init under --benchmark, and the surface and entities
    it creates there are present for the ticked run. Factorio's own --help offers no save-writing
    mode but --create and --start-server, so the alternative was a multiplayer server run plus
    game.server_save; planting at load needs neither, writes no save, and is the reason this mode
    hands back a baseline instead of an absolute number.

    IT WRITES NOTHING. --benchmark never saves, so the borrowed base is opened read-only in effect
    and every planted surface dies with the process. Nothing is redistributed either, which for this
    project's borrowed base is not a nicety -- see docs/research/borrowed-base.md and
    docs/adr/0029-the-factory-measurement-rests-on-a-borrowed-base.md.

    THE SURFACE IS REFUSED RATHER THAN REUSED if the save already has one by that name. Building
    over a surface somebody else made would destroy their work in a run they thought was read-only,
    and the landfill-and-clear pass below would do it silently.

    FOUR THINGS IT DOES NOT DO, none of them a defect and all of them easy to assume away.

    It does not put the reactors ON the base's power. 200 rf-reactors draw about 10 GW of heating
    and this adds no generation, so wiring them into the borrowed base's grid would brown out the
    whole factory -- every consumer is secondary-input and takes the same fraction, so the base
    would simply stop, and the report would look fine. Each cell keeps its own substation and
    interface exactly as the rig builds them, on an island connected to nothing.

    It does not make scriptUpdate this repo's Lua. A borrowed base carries its own mod set and every
    one of them is enabled; what cancels out of the SUBTRACTION is everything that is the same at
    every count, which is all of it except the reactors. So the per-reactor figure is attributable
    and the absolute one is not, which is the reverse of -Save.

    It does not measure a reactor plumbed into a factory. Nothing consumes the energy or the
    by-products, exactly as in the rig, and for the same reason: this measures what the simulation
    costs, not what a fusion plant is worth. The steam route is absent on purpose -- control.lua
    clamps the energy write to the box and discards the overflow, and the whole step runs anyway.

    And it does not clear the whole planted surface, only the build area. That is enough at
    benchmark length and would not be over a long run: enemy expansion is a global map setting and
    is deliberately left alone, since changing it would change the borrowed base's own behaviour.

.PARAMETER SaveModDirectory
    Where the save's third-party mods are found, for -Save and -PlantInto. Defaults to your own
    Factorio mod directory, which is where the saves next to it were built.

    READ-ONLY, which is why this is allowed to default to it where scripts/dev-launch.ps1 refuses the
    same directory outright: that one rewrites mod-list.json in place and would lose which mods you
    have enabled, and nothing here writes to it at all. The mods the save names are copied (zips) or
    junctioned (unpacked directories) into this run's throwaway mod directory, and only the ones the
    save names -- so a mod directory holding several overhauls contributes whichever the save asked
    for and none of the rest.

    Where the exact version is not there and another version of the same mod is, the other one is
    loaded and named in a warning. Which one, when there are several, is not a choice worth making
    here: install the version the save wants, or read the warning.

    mod-settings.dat is copied across when present, because startup settings change prototypes and
    a benchmark of a map with different prototypes is a benchmark of a different map.

.PARAMETER SelfTest
    Prove the four pieces of -Save's machinery that can fail quietly, and exit. Needs no Factorio
    and no save. It parses a synthesised save header, including the wide encoding a version
    component only reaches at 255 and no real mod on hand has; it requires an unresolvable mod to
    be named rather than skipped; it requires a zip whose name merely BEGINS with the wanted name
    plus an underscore to be refused rather than taken for it; and it requires a mod differing only
    in CASE to be refused too, planting one decoy in each of the two forms a mod can take on disk.

    Those four and no more, because every one of them produces a confident wrong answer rather than
    an error, and all three of the last three produce the SAME wrong answer by different routes: a
    run that loads the save without the mod the save names, reports a clean pass, and is believed. A
    mis-parsed header names the wrong mods. A mod list one entry short measures a map with a mod's
    entities stripped out of it. LTN_Combinator resolving as LTN is that with a bonus mod loaded to
    disguise it. And Wide resolving as wide is that again, from a mod directory that looks right to
    anyone reading it, because the only difference is one the file system will not show you.

.PARAMETER Counts
    Reactor counts to measure, ascending. 0 is the baseline and should be kept.

.PARAMETER Ticks
    Ticks per benchmark run. 1000 is Factorio's default and gives ~1000 samples per run.

.PARAMETER Runs
    Benchmark runs per count; the map reloads between them, so this samples process-level
    variation rather than tick-level. Samples from every run are pooled.

.PARAMETER Pooled
    Connect each row of reactors with rf-pipe so they share one fluid segment, which is how they
    are meant to be built (ADR 0011) and the case where a superlinear engine cost would hide.
    Costs -Gap pipes per reactor, which are part of what gets measured.

.PARAMETER Mixed
    Run all four of ADR 0010's reactions rather than D-D alone: D-D and D-T in rf-reactor, D-He3 and
    He3-He3 in rf-aneutronic-reactor, one reaction per row of the grid. This is what #34 asks for and
    what #24 could not do, because only D-D existed then.

    Off by default, and that is deliberate: an unmixed run is the rig #24 measured, down to the power
    it supplies, so the two readings stay comparable. A mixed run changes three things and says so --
    four plasmas instead of one and four times the power per cell so the aneutronic reactors are not
    clamped. It used to change the footprints too, when rf-aneutronic-reactor was ten tiles against
    rf-reactor's fifteen; ADR 0022 made both fifteen.

    Reactions are assigned by ROW rather than round-robin by index, because a pooled row is a single
    fluid segment and a segment carries one fluid. The consequence is that small counts are not
    mixed at all -- at n below GRID every reactor is in row 0 and burns D-D. Only the larger counts
    carry the full set, which is where the slope is taken from anyway: all four reactions are present
    once n passes 3 * GRID, and the run refuses to report a mixed figure above that if they are not.

    THE MIX AT A GIVEN n DEPENDS ON THE GRID, AND THE GRID ON THE LARGEST COUNT REQUESTED. Rows are
    GRID wide, so -Mixed -Counts 0,50 splits n = 50 as 16/16/10/8 while -Mixed -Counts 0,50,200
    splits the same n = 50 as 15/15/15/5 -- the same n, a different population, decided by an
    argument that has nothing to do with it. Two runs are comparable at a given n only if the whole
    -Counts list matches. The rig logs the actual split on every report -- burning=... -- so any
    figure taken from a run can be attributed rather than assumed; read it before comparing.

    This used to warn that it mattered a great deal, on the strength of D-D costing about 2.3x what
    the other three reactions do. #39 withdrew that figure: measured on a machine checked to be
    quiet, every reaction costs about the same, so a shifted split moves the number by little or
    nothing. The rule stands anyway, because "little or nothing" is a measurement rather than a
    guarantee and the next reaction added need not be as cheap.

.PARAMETER Ablate
    Replace the shipped simulation with a cut-down one, to say where the per-reactor cost actually
    goes (#39). The rungs are cumulative, and each names what it adds to the one before:

        loop     walk the register and check validity. The loop itself, no API calls per reactor.
        read     + entity.fluidbox[1] and entity.energy. Two boundary crossings, one of which
                 allocates a table.
        physics  + reactor-logic.step(). The arithmetic, and nothing else -- the module is required
                 straight out of __realistic-fusion-refreshed__, so this is the shipped physics rather than a
                 copy of it.
        write    + the per-reactor pending table, then entity.energy, box[1], get_capacity(2) and
                 box[2]. The rest of the crossings, and one allocation bundled in with them.

    A rung is measured the same way everything else here is -- as a slope against the n = 0 baseline
    -- so `write` minus `physics` is what the write crossings cost, and `physics` minus `read` is
    what the arithmetic costs. The first of those two is an upper bound rather than a figure: the
    write rung also carries the pending table control.lua's two-pass update builds, and nothing here
    separates the allocation from the writes. That difference is the whole point: the claim on record was that
    crossings dominate, and it was inferred from the arithmetic being too cheap to explain the
    figure rather than measured.

    Ablated runs place their reactors with raise_built = false, so realistic-fusion-refreshed never registers
    them and its own update() walks an empty register. The rig owns the whole step, at the shipped
    cadence, read from control.lua rather than remembered. What the rungs therefore do NOT include
    is the collector lookup and the circuit publish -- both per reactor, both in the shipped path --
    so `write` is a floor on the shipped cost, not a reproduction of it.

.PARAMETER Collectors
    Bolt an rf-isotope-collector to every reactor, so the by-product path actually runs (#62).

    Off by default, and the default is the older rig -- but the default is NOT the configuration a
    player builds. control.lua computes result.products every step whether or not a collector
    exists, and only touches a collector's fluidboxes when one is attached. This rig had never
    built one, so deposit() had not executed in a single measurement this project has taken: #24's,
    #27's and #34's figures are all the cost of a reactor that VENTS. That matters most for exactly
    the reaction the project quotes its cheapest tier from, because D-D is the only one that breeds.

    What it adds to the measured cost is two fluidbox writes per breeding reactor per step, plus the
    collector entity's own engine time. That second part does NOT cancel the way the rig's power
    does: power is built for every cell at every count including n = 0, and a collector exists only
    where a reactor does, so its entityUpdate and fluidFlowUpdate land on the per-reactor delta.
    That is the right answer to "what does a reactor with a collector cost", and the wrong answer to
    "what does deposit() cost" -- the two are not separated here.

    Nothing drains the collectors. A box holds 500 units and a run is a few hundred ticks, so they
    fill rather than saturate; the rig reports how full the WORST tritium box got -- full_pct= --
    because a saturated tritium box takes a blanket's headroom to zero and stops it. Read it before
    quoting a blanketed figure.

    NEEDS -Gap ABOVE THE FITTING'S OWN SIZE, which is six for a five-tile fitting and so above
    the default. Both fittings sit in the GAP-deep band south of the reactor, and entity-management
    pairs by the tiles touching the reactor with a WHOLE TILE of margin -- so at a tight gap a
    flush fitting reaches past its own cell and the next row's reactor pairs with it instead, since
    attach() takes the lowest unit_number and fittings are built in row order. The cost barely
    moves, which is what makes it dangerous: every reactor still has a collector and deposit()
    still runs, while one row's fittings serve two reactors and the last row's serve none. The rig
    checks the pairing against the real bounding boxes at map creation and refuses rather than
    reasoning about insets.

    Its own report costs something, and unlike the power it does not cancel. Reading the fittings
    back is a handful of API calls per reactor on a report tick, charged to scriptUpdate, scaling
    with n and absent from the n = 0 baseline -- the same argument .PARAMETER ReportEvery makes
    about the reactor walk. At the defaults it is under a hundredth of a microsecond per reactor;
    at -ReportEvery 1 it would be the same order as the cost being measured.

.PARAMETER Blankets
    Bolt an rf-lithium-blanket to every reactor as well, loaded with lithium, so blanket_breed()
    runs too (#62). Requires -Collectors: a blanket on a reactor with no collector is idle by
    design (control.lua's apply()), so it would measure nothing and the rig would have no way to
    say so.

    Separate from -Collectors rather than bundled with it, because the two are different questions
    and #62 asks for the blanket to be decided rather than omitted. A collector is what any D-D
    player builds; a blanket is a later tier's fitting, and it adds an inventory read, a lithium
    withdrawal and a second breed() call on top.

    The rig predicts how many blankets OUGHT to breed and requires exactly that many -- expect= in
    its log, counted as the map is built from reactor-logic's own fuel table, since a blanket
    breeds from neutrons and D-He3 and He3-He3 release none. On a mixed rig that is the neutronic
    rows only; on an unmixed one it is every blanket. The gate is exact rather than a lower bound,
    which matters because "at least one bred" is satisfied by a rig with a hundred and nine idle
    blankets.

    Both fittings go in the clear ground SOUTH of the reactor, side by side -- not one north and
    one south the way scripts/check-blanket.ps1 places them. A rig is a grid, and a reactor's north
    band is its neighbour's south band.

.PARAMETER Gap
    Clear tiles between one reactor and the next, and so also the length of the pipe run -Pooled
    lays between them. The cell is the reactor's own footprint plus this, read from the prototype
    at run time -- see the rig for why nothing here is a remembered number. Five is the minimum
    that still fits a substation and an interface beside each reactor.

.PARAMETER ReportEvery
    How often the rig logs what the reactors are doing, and how often it therefore walks every
    reactor to gather that. That walk costs about as much per reactor as the simulation step does,
    it is charged to scriptUpdate, it scales with n, and the n = 0 baseline has no reactors to
    subtract it against -- so it inflates the per-reactor figure directly. At the default it runs
    on two or three ticks in a thousand, well under a percent of the throttled cost. Drop it to 1
    only when diagnosing the rig, and do not quote a cost figure from a run that did.

.PARAMETER BusyPercent
    How much of the whole part may be in use before a count is reported with a BUSY warning.

Compared against a reading taken just BEFORE
    each count's Factorio is launched, so it is other people's work and not ours -- see
    Get-ForeignLoad for why measuring during the run does not work, and for the case it cannot see.

    The default is calibrated rather than round. `% Processor Utility` is normalised to the part's
    BASE clock, so a single saturated thread on this twelve-thread part reads about a twelfth times
    whatever turbo multiplier is in force -- around 13% at the 155% clock this machine idles at.
    Measured with nothing else asked of it, the machine sits near 33%; with a benchmark running,
    near 45%. Sixty therefore leaves an idle machine clear and still catches the thing worth
    catching, which is a multi-core compile: those take the part past 100% and hold it there.

    It warns rather than refusing, because there is no calibrated threshold here -- and because the
    figure is still worth having with the caveat attached. What makes other work uniquely dangerous
    on this rig is that it does NOT cancel: every per-reactor figure is a difference against an
    n = 0 baseline measured in a different process minutes earlier, so a compile that starts in
    between lands entirely on the difference. See docs/research/reactor-runtime-cost.md.

.PARAMETER KeepTemp
    Keep the saves, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/bench-reactors.ps1
    pwsh -File scripts/bench-reactors.ps1 -Pooled
    pwsh -File scripts/bench-reactors.ps1 -Mixed
    pwsh -File scripts/bench-reactors.ps1 -Collectors -Gap 6
    pwsh -File scripts/bench-reactors.ps1 -Mixed -Collectors -Blankets -Gap 6
    pwsh -File scripts/bench-reactors.ps1 -Save "$env:APPDATA\Factorio\saves\my-factory.zip"
    pwsh -File scripts/bench-reactors.ps1 -SelfTest

    The borrowed base (#65), which needs -Counts and so needs -Command -- see the note below:

    pwsh -Command "& ./scripts/bench-reactors.ps1 -PlantInto 'C:/src/factorio/_reference/Megabase in 2.0.zip' -Counts 0,50,200 -Collectors -Blankets -Gap 6"

    A LIST ARGUMENT NEEDS -Command, NOT -File, and this is not a style preference. -File hands each
    argument to the script as a string, and converting a string to [int[]] is culture-aware: where
    the decimal separator is a comma -- which it is on the machine this was written on --
    "0,1,10" converts to the single number 110, and "0,16" to 16. The run then has no n = 0
    baseline, and every per-reactor figure is a subtraction against it. It used to omit them
    silently; it now throws.

    pwsh -Command "& ./scripts/bench-reactors.ps1 -Counts 0,1,10 -Ticks 300 -Runs 1"
    pwsh -Command "& ./scripts/bench-reactors.ps1 -Mixed -Counts 0,16,64,256"
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [string] $Save,
    [string] $PlantInto,
    [string] $SaveModDirectory,
    [switch] $SelfTest,
    [ValidateRange(0, 100000)]        [int[]] $Counts = @(0, 1, 10, 50, 200),
    [ValidateRange(1, [int]::MaxValue)] [int] $Ticks  = 1000,
    [ValidateRange(1, [int]::MaxValue)] [int] $Runs   = 3,
    [switch] $Pooled,
    [switch] $Mixed,
    [switch] $Collectors,
    [switch] $Blankets,
    [ValidateSet('none', 'loop', 'read', 'physics', 'write')] [string] $Ablate = 'none',
    [ValidateRange(5, 100)]             [int] $Gap = 5,
    [ValidateRange(1, [int]::MaxValue)] [int] $ReportEvery = 500,
    [ValidateRange(0, 100)]           [double] $BusyPercent = 60,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$rigName  = 'rf-bench-rig'

# The surface -PlantInto builds on inside a borrowed base (#65). Prefixed like everything else this
# repo names, so a collision with a surface the save already has is implausible -- and refused by
# the rig rather than built over if it happens anyway.
$plantSurface = 'rf-bench-plant'

# Lithium per blanket, in items, and one place for it: the rig loads this much and the gate below
# requires the total to have fallen without reaching zero, so a second copy of the number would let
# a passing run mean nothing. See the rig's own note for why it is comfortably large.
$lithiumPerBlanket = 5000

# Columns worth printing. scriptUpdate is the answer; the rest are context, and are here because a
# cost pushed out of Lua and into the engine is still a cost this mod causes.
# luaGarbageIncremental is the one that would otherwise hide: the step allocates tables per reactor
# per tick, and collecting them is charged to its own stage rather than to the script.
$REPORT = @('wholeUpdate', 'scriptUpdate', 'luaGarbageIncremental', 'fluidFlowUpdate',
            'electricNetworkUpdate', 'entityUpdate')

# The name of the mod -Save adds to take its reactor census. Separate from the rig, and never
# present in the run that produces the numbers -- see Write-Survey.
$surveyName = 'rf-bench-survey'

# ------------------------------------------------------------------ the save's own mod set (#64)
#
# Parsed out of the save rather than left to the game, for the reason .PARAMETER Save gives at
# length: Factorio loads a save whose mods are absent, runs it, and exits 0 without a warning.

function Read-OptimizedNumber {
    <#  One of Factorio's space-optimized integers: a single byte, unless that byte is 0xFF, in
        which case the real value follows it in $WideBytes little-endian bytes.

        It matters here rather than being a curiosity. A mod at version 1.2.300 encodes its third
        component wide, so an entry is NOT a fixed number of bytes and a parser that assumed one
        would walk off the end of the first such mod and mis-name every mod after it. $null on
        running out of buffer, so a caller scanning for the block treats a truncated read as a
        failed match rather than as data.  #>
    param(
        [Parameter(Mandatory)] [byte[]] $Buffer,
        [Parameter(Mandatory)] [int]    $Length,
        [Parameter(Mandatory)] [ref]    $Offset,
        [Parameter(Mandatory)] [int]    $WideBytes
    )

    if ($Offset.Value -ge $Length) { return $null }
    $b = $Buffer[$Offset.Value]; $Offset.Value++
    if ($b -ne 0xFF) { return [int]$b }
    if ($Offset.Value + $WideBytes -gt $Length) { return $null }
    $value = 0
    for ($i = 0; $i -lt $WideBytes; $i++) {
        $value = $value -bor ([int]$Buffer[$Offset.Value + $i] -shl (8 * $i))
    }
    $Offset.Value += $WideBytes
    return $value
}

function Read-ModBlock {
    <#  Try to read a save header's mod list starting at $Start: a count, then that many entries of
        a length-prefixed name, three optimized version components and a four-byte checksum.

        Returns $null on anything that does not parse, and that is what makes the scan below safe
        rather than a guess. The bytes between the map version and the mod list are variable-length
        -- scenario name, map settings -- so the block's offset cannot be computed, only found.

        A candidate offset is accepted only when its count parses, every one of its entries reads
        as a plausible mod name, the block ends inside the buffer, and the first name is exactly
        base. The scan runs forward from the start of the header and takes the first offset that
        satisfies all four, so a save listing base and one mod has two names that must agree at
        their exact lengths -- and every save worth benchmarking lists more than that.  #>
    param(
        [Parameter(Mandatory)] [byte[]] $Buffer,
        [Parameter(Mandatory)] [int]    $Length,
        [Parameter(Mandatory)] [int]    $Start
    )

    $offset = $Start
    # The count is optimized as a uint32; a version component as a uint16. Different widths, so
    # they cannot share one reader call.
    $count = Read-OptimizedNumber -Buffer $Buffer -Length $Length -Offset ([ref]$offset) -WideBytes 4
    if ($null -eq $count -or $count -lt 1 -or $count -gt 1000) { return $null }

    $mods = @()
    for ($i = 0; $i -lt $count; $i++) {
        if ($offset -ge $Length) { return $null }
        $len = [int]$Buffer[$offset]; $offset++
        # A mod name is at most 100 characters on the portal, and never zero.
        if ($len -lt 1 -or $len -gt 100 -or $offset + $len -gt $Length) { return $null }
        $name = [Text.Encoding]::ASCII.GetString($Buffer, $offset, $len)
        if ($name -notmatch '^[A-Za-z0-9 _\-\.\+]+$') { return $null }
        $offset += $len

        $version = @()
        foreach ($component in 1..3) {
            $n = Read-OptimizedNumber -Buffer $Buffer -Length $Length -Offset ([ref]$offset) -WideBytes 2
            if ($null -eq $n) { return $null }
            $version += $n
        }
        if ($offset + 4 -gt $Length) { return $null }   # the entry's checksum
        $offset += 4

        $mods += [pscustomobject]@{ Name = $name; Version = ($version -join '.') }
    }
    return $mods
}

function Get-SaveModList {
    <#  Every mod a save was written with, in the order its header lists them, base first.

        The header is at the front of level-init.dat and is NOT compressed, so only the first
        block of it has to be read -- the level data proper runs to tens of megabytes and none of
        it is wanted here.  #>
    param([Parameter(Mandatory)] [string] $Path)

    # Opened in a try of its own, because OpenRead on something that is not a zip throws a raw .NET
    # exception -- and Factorio accepts an UNCOMPRESSED save, which is a directory, so pointing
    # -Save at one is an ordinary mistake rather than an exotic one. Without this it arrives as
    # "Access to the path is denied" and reads like a permissions fault.
    try { $zip = [IO.Compression.ZipFile]::OpenRead($Path) }
    catch {
        throw ("'$Path' could not be read as a Factorio save zip: $($_.Exception.Message). An " +
               'uncompressed save is a directory and cannot be read here; zip it, or point -Save ' +
               'at the .zip the game writes.')
    }
    try {
        # By leaf name: the entries are under a directory named after the save, which is not
        # required to match the file name.
        $entry = $zip.Entries | Where-Object { $_.Name -eq 'level-init.dat' } | Select-Object -First 1
        if (-not $entry) {
            throw ("'$Path' has no level-init.dat in it, so it is not a Factorio save. A scenario " +
                   'directory and a blueprint string are both the wrong thing to pass here.')
        }
        $buffer = [byte[]]::new(65536)
        $stream = $entry.Open()
        try {
            # Read in a loop: a decompressing stream is free to return less than was asked for
            # long before it reaches the end, and a single Read can leave the mod list half
            # outside the buffer.
            $read = 0
            while ($read -lt $buffer.Length) {
                $n = $stream.Read($buffer, $read, $buffer.Length - $read)
                if ($n -le 0) { break }
                $read += $n
            }
        } finally { $stream.Dispose() }
    } finally { $zip.Dispose() }

    # base is always the first mod in the list, which is what anchors the scan. Bounded at 4 KB
    # because every save measured put the block inside the first 60 bytes; a header that somehow
    # pushed it past 4 KB should be a clear refusal rather than a slow one.
    $limit = [Math]::Min($read, 4096)
    for ($p = 0; $p -lt $limit; $p++) {
        $mods = Read-ModBlock -Buffer $buffer -Length $read -Start $p
        if ($mods -and $mods[0].Name -ceq 'base') { return $mods }
    }
    throw ("could not find the mod list in '$Path'. The save header's layout is not part of " +
           "Factorio's public API, so a game update can move it -- run -SelfTest to tell a broken " +
           'parser from an unusual save.')
}

function Resolve-SaveMods {
    <#  Decide where every mod a save names is going to come from, or refuse and say which is not
        anywhere.

        Pure: it touches the file system to look, and changes nothing. That is what lets -SelfTest
        exercise the refusal without a game or a save.

        Returns Bundled (canonical names to enable), Foreign (descriptors with a Source path and an
        IsZip flag) and Ours (this repo's mods the save asked for, which the junctions supply).  #>
    param(
        [Parameter(Mandatory)] [object[]]  $Wanted,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $SourceDirectory,
        [Parameter(Mandatory)] [hashtable] $Bundled,
        [Parameter(Mandatory)] [string[]]  $Ours
    )

    $resolvedBundled = @()
    $foreign         = @()
    $ourNames        = @()
    $missing         = @()
    $mismatched      = @()

    foreach ($mod in $Wanted) {
        # base and core are not optional and are not in a mod directory.
        if ($mod.Name -ceq 'base' -or $mod.Name -ceq 'core') { continue }

        # -ccontains, not -contains: mod names are case-sensitive to Factorio and PowerShell's
        # -contains is not, so a foreign mod whose name differs from one of ours only in case would
        # be taken for ours and quietly never loaded. Folding the other way is the safe error --
        # a differently-cased reference to one of ours falls through and gets NAMED as missing.
        if ($Ours -ccontains $mod.Name) { $ourNames += $mod.Name; continue }

        # Canonicalised through the hashtable's own key rather than trusted as typed, for the
        # reason factorio-lib.ps1's header gives: -contains folds case and HashSet[string] does
        # not, so an uncanonicalised name validates here and fails to match where it is written.
        $bundledName = $Bundled.Keys | Where-Object { $_ -eq $mod.Name } | Select-Object -First 1
        if ($bundledName) { $resolvedBundled += $bundledName; continue }

        if (-not $SourceDirectory -or -not (Test-Path -LiteralPath $SourceDirectory)) {
            $missing += $mod; continue
        }

        # An unpacked directory first, then a zip, and the save's own version ahead of any other.
        # Both forms are legal to Factorio and a mod directory can hold either.
        #
        # BOTH LOOK BY ENUMERATING AND COMPARING CASE-SENSITIVELY, and never by asking the file
        # system whether a path exists. That is the whole shape of what follows, and it is not a
        # style preference: NTFS folds case, so `Test-Path .../wide_1.2.300.zip` answers yes for a
        # file called Wide_1.2.300.zip. Factorio does not fold case -- it reads a mod's name out of
        # its own info.json -- so resolving `wide` to Wide's file writes a mod-list.json enabling a
        # `wide` that is nowhere, leaves the save's actual mod absent, and loads anyway with exit 0.
        # That is the silent wrong-mod-set failure this whole function exists to refuse, arriving by
        # the one route the function was not checking.
        #
        # The -ccontains above is the same rule on the same grounds. Found in review, in the zip
        # branch; the directory branch had it too, because Test-Path folds case for a directory
        # exactly as it does for a file. -SelfTest 4/4 holds both shut with one decoy each.
        $found = $null
        $wantedDir = "$($mod.Name)_$($mod.Version)"
        # -LiteralPath because a mod directory's own path may contain brackets, which -Path would
        # read as a character class.
        foreach ($dir in @(Get-ChildItem -LiteralPath $SourceDirectory -Directory |
                           Where-Object { $_.Name -ceq $wantedDir -or $_.Name -ceq $mod.Name } |
                           Sort-Object { $_.Name -cne $mod.Name })) {
            $info = Join-Path $dir.FullName 'info.json'
            if (Test-Path -LiteralPath $info) {
                # From info.json rather than from the directory name. An unpacked mod is not
                # required to carry its version in its directory name -- a junction to a working
                # tree never does -- so inferring one from the name would report a version
                # mismatch on every such mod, including this repo's own.
                $onDisk = (Get-Content $info -Raw | ConvertFrom-Json).version
                $found = [pscustomobject]@{
                    Name = $mod.Name; Version = $mod.Version; Source = $dir.FullName; IsZip = $false
                    OnDisk = "$onDisk"; Exact = ("$onDisk" -ceq $mod.Version)
                }
                break
            }
        }
        if (-not $found) {
            # THE TAIL AFTER THE UNDERSCORE MUST BE A VERSION, which is why the glob is filtered
            # rather than trusted. `-Filter "LTN_*.zip"` matches LTN_Combinator_2.0.1.zip, so a save
            # wanting LTN on a machine that has only the Combinator would resolve LTN to the
            # Combinator's zip and be reported RESOLVED -- the same silent failure the case rule
            # above describes, by a third route. Found in review; -SelfTest 3/4.
            #
            # -Filter is the file system's own glob and folds case like the rest of NTFS, so it can
            # only ever return a superset here. The -cmatch is what narrows it back.
            $versioned  = "^$([regex]::Escape($mod.Name))_\d+\.\d+\.\d+$"
            $wantedName = "$($mod.Name)_$($mod.Version)"
            $zips = @(Get-ChildItem -LiteralPath $SourceDirectory -File -Filter "$($mod.Name)_*.zip" |
                      Where-Object { $_.BaseName -cmatch $versioned } | Sort-Object Name)
            # The save's own version ahead of any other, matched case-sensitively like the name.
            # Which of several WRONG versions gets taken is not a decision this can make well, so
            # it takes the first by name and warns which it took.
            $pick = @($zips | Where-Object { $_.BaseName -ceq $wantedName })[0]
            if (-not $pick) { $pick = $zips[0] }
            if ($pick) {
                # A zip's version is in its file name -- Factorio requires name_version.zip -- so
                # there is nothing to read out of it.
                $found = [pscustomobject]@{
                    Name = $mod.Name; Version = $mod.Version; Source = $pick.FullName; IsZip = $true
                    OnDisk = ($pick.BaseName -creplace "^$([regex]::Escape($mod.Name))_", '')
                    Exact = ($pick.BaseName -ceq $wantedName)
                }
            }
        }

        if (-not $found) { $missing += $mod; continue }
        if (-not $found.Exact) { $mismatched += $found }
        $foreign += $found
    }

    if ($missing.Count -gt 0) {
        # EVERY missing name in the message, and on one flowing line rather than one per line:
        # PowerShell's error view reflows an exception message and swallows the newlines in it, so a
        # list laid out vertically arrives as a run-on with double spaces where the breaks were.
        #
        # Naming them is the whole point. "Resolve the mods" is not an instruction anybody can act
        # on, and this refusal exists precisely because Factorio's own silence is not either.
        throw (("the save needs {0} mod(s) that are not installed, and Factorio would load it " +
                "anyway WITHOUT complaining -- measuring a map with their entities stripped out of " +
                "it. Missing: {1}. Looked in: {2}. Install them, or pass -SaveModDirectory at a " +
                'directory that has them.') -f
               $missing.Count,
               (($missing | ForEach-Object { "$($_.Name) $($_.Version)" }) -join ', '),
               ($SourceDirectory ? $SourceDirectory : '(nowhere -- no mod directory given)'))
    }

    foreach ($m in $mismatched) {
        Write-Warning ("the save was written with $($m.Name) $($m.Version) and this run will load " +
                       "$($m.OnDisk) from $($m.Source) instead. Factorio migrates a save across a " +
                       'mod version, so the map measured is not quite the map saved.')
    }

    return [pscustomobject]@{
        Bundled = @($resolvedBundled | Sort-Object -Unique)
        Foreign = @($foreign)
        Ours    = @($ourNames)
    }
}

# ------------------------------------------------------------------ which mode this run is
#
# Before anything is resolved or created, because an argument that cannot be honoured has to be
# refused rather than discarded. -Save builds nothing, so every switch that describes a rig is a
# refusal: ignoring them would print a report about a save while the caller believed they had asked
# for a mixed, collectored or ablated one, and nothing in the output would contradict them. Read off
# $PSBoundParameters so a default is not mistaken for a request.
$rigOnly = @('Counts', 'Pooled', 'Mixed', 'Collectors', 'Blankets', 'Ablate', 'Gap', 'ReportEvery')
# The same rule applied to -SelfTest itself, and it has to come first: -SelfTest returns below,
# before the rest of the script runs at all, so anything passed with it would be discarded in
# silence -- which is the fault the paragraph above refuses.
if ($SelfTest) {
    # Against the real common-parameter list, not against 'Verbose' alone. [CmdletBinding()] adds
    # eleven of them and every one arrives in $PSBoundParameters like any other argument, so
    # `-SelfTest -ErrorAction Continue` refused to run the self-test at all while this named one.
    $common    = [Management.Automation.PSCmdlet]::CommonParameters
    $alsoGiven = @($PSBoundParameters.Keys | Where-Object { $_ -ne 'SelfTest' -and $_ -notin $common })
    if ($alsoGiven.Count -gt 0) {
        throw ("-SelfTest runs no game and reads no save, so it can honour none of: " +
               "$($alsoGiven -join ', '). Pass -SelfTest alone.")
    }
}
if ($Save -and $PlantInto) {
    throw ('-Save and -PlantInto are two different questions about a save: -Save measures it as it ' +
           'is, -PlantInto builds a rig inside it and sweeps -Counts. Pick one.')
}
if ($Save) {
    $given = @($rigOnly | Where-Object { $PSBoundParameters.ContainsKey($_) })
    if ($given.Count -gt 0) {
        throw ("-Save benchmarks a map this script did not build, so it can honour none of: " +
               "$($given -join ', '). Drop them, or drop -Save to measure a rig.")
    }
} elseif ($PlantInto) {
    # -PlantInto honours every rig switch except this one, and the exception is not arbitrary. An
    # ablated rung suppresses raise_built so the shipped mod registers nothing and the rig owns the
    # step -- which is a way of asking where a per-reactor microsecond goes, on a map built to make
    # that answerable. The borrowed base exists to answer a different question, its load dominates
    # the run, and no rung has ever been measured against one. Refused rather than allowed
    # untested.
    if ($Ablate -ne 'none') {
        throw ("-Ablate $Ablate is a rig diagnostic and has never been measured on a borrowed " +
               'base; see .PARAMETER PlantInto. Drop it, or drop -PlantInto.')
    }
} elseif ($SaveModDirectory) {
    throw '-SaveModDirectory has nothing to resolve without -Save or -PlantInto.'
}
# Shared by both save-reading modes, and defaulted here rather than inside either so the two
# cannot drift on where a save's mods live.
if ($Save -or $PlantInto) {
    if (-not $SaveModDirectory) { $SaveModDirectory = Join-Path $env:APPDATA 'Factorio\mods' }
    if (-not (Test-Path -LiteralPath $SaveModDirectory)) {
        throw ("-SaveModDirectory not found: $SaveModDirectory. That is where the save's own mods " +
               'are looked for; pass one explicitly if they live elsewhere.')
    }
    # New-ModJunctions refuses a relative target, and a mod directory given relative to the
    # repository is the obvious thing to type.
    $SaveModDirectory = (Resolve-Path -LiteralPath $SaveModDirectory).Path
}
if ($PlantInto) {
    if (-not (Test-Path -LiteralPath $PlantInto)) { throw "-PlantInto not found: $PlantInto" }
    $PlantInto = (Resolve-Path -LiteralPath $PlantInto).Path
}

if ($SelfTest) {
    # Four assertions, all pure, all on machinery that would otherwise fail by giving a
    # confident wrong answer rather than an error. See .PARAMETER SelfTest.
    Write-Host '-SelfTest: the save-header parser and three ways a wrong mod could resolve.'

    # A synthesised header: the leading bytes a real save has before its mod list -- whose contents
    # do not matter, only that the scan has to get past them -- then three mods. The third is
    # version 1.2.300, whose last component does not fit in a byte, so the wide encoding is
    # exercised here rather than waiting for a mod to reach 255.
    $bytes = [Collections.Generic.List[byte]]::new()
    foreach ($b in @(2, 0, 0, 0, 77, 0, 0, 0, 0)) { $bytes.Add([byte]$b) }
    $bytes.Add([byte]8); $bytes.AddRange([Text.Encoding]::ASCII.GetBytes('freeplay'))
    $bytes.Add([byte]3)                                       # three mods follow
    $expected = @(
        @{ Name = 'base';        Version = @(2, 0, 77) }
        @{ Name = 'a-third-mod'; Version = @(0, 16, 5) }
        @{ Name = 'wide';        Version = @(1, 2, 300) }
    )
    foreach ($m in $expected) {
        $bytes.Add([byte]$m.Name.Length); $bytes.AddRange([Text.Encoding]::ASCII.GetBytes($m.Name))
        foreach ($component in $m.Version) {
            if ($component -lt 255) { $bytes.Add([byte]$component) }
            else {
                $bytes.Add([byte]0xFF)
                $bytes.AddRange([BitConverter]::GetBytes([uint16]$component))
            }
        }
        $bytes.AddRange([byte[]]@(0xDE, 0xAD, 0xBE, 0xEF))    # the entry's checksum
    }

    $buffer = $bytes.ToArray()
    $parsed = $null
    for ($p = 0; $p -lt $buffer.Length; $p++) {
        $try = Read-ModBlock -Buffer $buffer -Length $buffer.Length -Start $p
        if ($try -and $try[0].Name -ceq 'base') { $parsed = $try; break }
    }
    if (-not $parsed) { throw '-SelfTest 1/4 FAILED: the parser found no mod list in a synthesised header.' }
    $got  = ($parsed | ForEach-Object { "$($_.Name) $($_.Version)" }) -join '; '
    $want = ($expected | ForEach-Object { "$($_.Name) $($_.Version -join '.')" }) -join '; '
    if ($got -cne $want) { throw "-SelfTest 1/4 FAILED: parsed '$got', expected '$want'." }
    Write-Host "  1/4 ok: parsed '$got', wide-encoded version included."

    # And the refusal. An empty directory resolves nothing, so every name in the list must come
    # back named -- a resolver that skipped what it could not find would hand the benchmark a map
    # with a mod's entities missing and report a clean run over it.
    $emptyDir = Join-Path ([IO.Path]::GetTempPath()) ('rf-bench-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
    try {
        $refused = $null
        try {
            Resolve-SaveMods -Wanted $parsed -SourceDirectory $emptyDir -Bundled @{} -Ours (Get-RepoMods) |
                Out-Null
        } catch { $refused = "$($_.Exception.Message)" }
        if (-not $refused) { throw '-SelfTest 2/4 FAILED: two unresolvable mods were accepted rather than refused.' }
        foreach ($name in @('a-third-mod', 'wide')) {
            if (-not $refused.Contains($name)) {
                throw "-SelfTest 2/4 FAILED: the refusal does not name '$name': $refused"
            }
        }
        # base is the engine's and is deliberately not a mod anybody installs, so naming it would
        # send the reader looking for something that cannot be found.
        if ($refused.Contains('base ')) {
            throw "-SelfTest 2/4 FAILED: the refusal names base, which is not an installable mod: $refused"
        }
        Write-Host '  2/4 ok: both unresolved mods named, base not among them.'

        # And the refusal again, against the near miss rather than the empty directory. A zip
        # whose name merely STARTS with the wanted name plus an underscore is a different mod:
        # LTN_Combinator is not LTN. Resolving it would report the save's mod set complete, load
        # the map with the real mod's entities stripped out, and exit 0 -- so the near miss has to
        # be refused exactly as loudly as nothing at all.
        $decoyDir = Join-Path ([IO.Path]::GetTempPath()) ('rf-bench-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $decoyDir -Force | Out-Null
        try {
            Set-Content -Path (Join-Path $decoyDir 'wide_Combinator_2.0.1.zip') -Value 'not a mod' -Encoding utf8
            $wanted = @([pscustomobject]@{ Name = 'wide'; Version = '1.2.300' })
            $refused = $null
            try {
                Resolve-SaveMods -Wanted $wanted -SourceDirectory $decoyDir -Bundled @{} -Ours (Get-RepoMods) |
                    Out-Null
            } catch { $refused = "$($_.Exception.Message)" }
            if (-not $refused) {
                throw ('-SelfTest 3/4 FAILED: wide_Combinator_2.0.1.zip was accepted as the mod ' +
                       '"wide", so a save could be benchmarked with the wrong mod loaded and ' +
                       'nothing would say so.')
            }
            if (-not $refused.Contains('wide 1.2.300')) {
                throw "-SelfTest 3/4 FAILED: the refusal does not name 'wide 1.2.300': $refused"
            }
            Write-Host '  3/4 ok: a name_suffix_version.zip is not accepted as name.'
        } finally { Remove-TempDirectory -Path $decoyDir -Label 'bench-reactors -SelfTest' }

        # And the near miss that is only a difference of CASE, which NTFS does not distinguish and
        # Factorio does. Both decoys are planted at once deliberately: resolution reaching either
        # one is a failure, so a single assertion catches a regression in the directory branch or
        # in the zip branch without needing two.
        $caseDir = Join-Path ([IO.Path]::GetTempPath()) ('rf-bench-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path (Join-Path $caseDir 'Wide') -Force | Out-Null
        try {
            Set-Content -Path (Join-Path $caseDir 'Wide_1.2.300.zip') -Value 'not a mod' -Encoding utf8
            '{ "name": "Wide", "version": "1.2.300" }' |
                Set-Content -Path (Join-Path $caseDir 'Wide/info.json') -Encoding utf8
            $wanted = @([pscustomobject]@{ Name = 'wide'; Version = '1.2.300' })
            $refused = $null
            try {
                Resolve-SaveMods -Wanted $wanted -SourceDirectory $caseDir -Bundled @{} -Ours (Get-RepoMods) |
                    Out-Null
            } catch { $refused = "$($_.Exception.Message)" }
            if (-not $refused) {
                throw ('-SelfTest 4/4 FAILED: a mod called "Wide" was accepted as the mod "wide". ' +
                       'Factorio reads a mod name from its own info.json and does not fold case, so ' +
                       "the save's real mod would have been absent from a run reported as clean.")
            }
            if (-not $refused.Contains('wide 1.2.300')) {
                throw "-SelfTest 4/4 FAILED: the refusal does not name 'wide 1.2.300': $refused"
            }
            Write-Host '  4/4 ok: neither Wide/ nor Wide_1.2.300.zip is accepted as wide.'
        } finally { Remove-TempDirectory -Path $caseDir -Label 'bench-reactors -SelfTest' }
    } finally { Remove-TempDirectory -Path $emptyDir -Label 'bench-reactors -SelfTest' }

    Write-Host '-SelfTest: PASS'
    return
}

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

# A blanket with nowhere to put what it breeds does not merely vent it -- control.lua's apply()
# never calls blanket_breed() at all, because spending a real item for nothing is a trap rather
# than a mechanic. So -Blankets alone would place a hundred idle containers and measure the cost of
# owning them, and the lithium gate below would fail with no way to say which of the two it meant.
if ($Blankets -and -not $Collectors) {
    throw ('-Blankets requires -Collectors: a blanket on a reactor with no collector is idle by ' +
           'design (control.lua apply()), so there would be nothing to measure.')
}
# The ablation ladder replaces the shipped step with a cut-down one that never looks a collector up
# -- .PARAMETER Ablate says so, and that omission is the point of the rungs. Fittings under -Ablate
# would therefore add engine cost to the delta and no Lua at all, which is a number nothing can be
# concluded from.
if ($Ablate -ne 'none' -and ($Collectors -or $Blankets)) {
    throw ("-Ablate $Ablate does not run the collector path (see .PARAMETER Ablate), so fittings " +
           'would add engine cost and no Lua. Drop -Collectors/-Blankets or drop -Ablate.')
}

$Counts = @($Counts | Sort-Object -Unique)
# .Count, not -not: PowerShell unwraps a single-element array, so "-not @(0)" is true and a
# perfectly good "-Counts 0" would be rejected as empty.
if ($Counts.Count -eq 0) { throw '-Counts is empty.' }

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-bench-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
# Only the directory the run actually needs. A directory in a mod directory with no info.json in it
# is a mod Factorio refuses to load, so creating the rig's under -Save would break the very runs
# that have no rig -- and creating the survey's under a rig run would put a mod in the sweep that
# #24's reading did not have.
New-Item -ItemType Directory -Force -Path ($Save ? (Join-Path $modDir $surveyName) : $rigDir) | Out-Null

# A report interval at or past the run length leaves only the tick-0 report, which is taken before
# the rig has filled and would fail the "every reactor hot" gate on a perfectly good run. Halving
# the run length keeps two reports per run whatever -Ticks is, so the reporting overhead stays a
# fixed fraction rather than growing as runs get shorter.
if ($ReportEvery -ge $Ticks) { $ReportEvery = [Math]::Max(1, [int]($Ticks / 2)) }


# The shipped cadence, read rather than remembered -- an ablated rung has to step as often as the
# mod it replaces or its per-reactor figure is off by whatever the two intervals differ by. This is
# the one number the rig cannot ask the game for: UPDATE_INTERVAL is a local in control.lua.
$controlLua = Join-Path $repoRoot 'realistic-fusion-refreshed/control.lua'
if ((Get-Content $controlLua -Raw) -match '(?m)^local UPDATE_INTERVAL = (\d+)') {
    $interval = [int]$Matches[1]
} else {
    throw "could not read UPDATE_INTERVAL from $controlLua; the ablation rungs would step at the wrong cadence."
}

# And the REPORTING cadence, in simulation steps, read the same way and for the same reason. It is
# what -Save's simulation gate waits for: circuit.publish() runs on this cadence rather than on
# every step, so the census's window has to be long enough to contain one. Remembering either
# number would give a gate that passes because it looked too early.
if ((Get-Content $controlLua -Raw) -match '(?m)^local REPORT_EVERY = (\d+)') {
    $reportEvery = [int]$Matches[1]
} else {
    throw ("could not read REPORT_EVERY from $controlLua; -Save's simulation gate would not know " +
           'how long to wait for a publish.')
}
# Ticks between one circuit publish and the next, which is the two cadences multiplied.
$publishEvery = $interval * $reportEvery

# on_nth_tick handlers are keyed by PERIOD, so registering the rig's report at the same interval the
# ablation ladder steps at would not add a handler -- it would silently replace one, and the rig
# would measure nothing while looking like it had measured a rung. The steps= gate catches it, but
# it says "nothing was measured", which points at the require rather than at the collision.
#
# Reachable without touching -ReportEvery at all: the rewrite further up lands it on Ticks / 2, so
# -Ticks 12 puts it exactly on the shipped six-tick cadence. It sits BELOW the UPDATE_INTERVAL read
# rather than beside that rewrite, because $interval does not exist yet up there and the comparison
# would silently never match -- which is how this guard failed the first time it was written.
if ($Ablate -ne 'none' -and $ReportEvery -eq $interval) { $ReportEvery = $interval + 1 }

# One grid geometry for every run, sized for the largest count, so the map is identical at every N.
$grid = [Math]::Max(1, [int][Math]::Ceiling([Math]::Sqrt(($Counts | Measure-Object -Maximum).Maximum)))

function Write-Rig {
    <#  Generate the rig mod for one reactor count. It is written fresh each time because the
        count is baked in: passing it another way would need a settings stage or a startup file,
        and neither is worth it for a throwaway.  #>
    param([int] $Count)

    @{
        name = $rigName; version = '0.0.1'; title = 'Reactor benchmark rig'
        author = 'bench-reactors.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

    $lua = @'
-- Generated by scripts/bench-reactors.ps1. Nothing here ships.

local COUNT  = __COUNT__
local GRID   = __GRID__      -- cells per side; the same at every count, so the map is too
local POOLED = __POOLED__
local GAP    = __GAP__       -- clear tiles between one reactor and the next
local MIXED  = __MIXED__
-- Fittings (#62). Off, the rig measures a reactor that vents -- which is every figure this project
-- had on record before #62, and not what a player builds. See .PARAMETER Collectors.
local COLLECTORS = __COLLECTORS__
local BLANKETS   = __BLANKETS__
-- Lithium per blanket, in items. Comfortably more than a run can burn, for the reason
-- check-blanket.ps1 gives at greater length: an ignited D-T reactor eats about 19 items a second,
-- so a blanket that runs dry mid-run turns the measurement into the cost of an empty container and
-- nothing says so. A thousand ticks is under seventeen seconds.
local LITHIUM_LOADED = __LITHIUM__
-- Which rung of the ablation ladder to run, and the shipped cadence to run it at. "none" is the
-- shipped mod doing the whole step; anything else is this rig doing a cut-down one instead. See
-- the .PARAMETER Ablate block.
local ABLATE   = "__ABLATE__"
local INTERVAL = __INTERVAL__

-- WHERE the rig is built (#65). Empty is the map this script made with --create and owns outright,
-- so it builds on surface 1. A NAME is -PlantInto: the rig goes on a surface of its own inside
-- somebody else's save -- the borrowed base -- so nothing of theirs is touched and the same run
-- with COUNT = 0 is a real n = 0 baseline. See .PARAMETER PlantInto.
local SURFACE = "__SURFACE__"

-- What each reactor burns. ADR 0010's four reactions run in two different entities, and #34 is the
-- measurement with all four present -- the early reading (#24) had only the first, because it was
-- the only one that existed.
--
-- Assigned BY ROW, not by index, for a reason that only shows under -Pooled: a pooled row is one
-- fluid segment, and a segment carries one fluid. Cycling by index would put D-D and D-T in the
-- same segment and the rig would silently measure something that cannot be built.
local CASES = MIXED and {
  { entity = "rf-reactor",            plasma = "rf-d-d-plasma"     },
  { entity = "rf-reactor",            plasma = "rf-d-t-plasma"     },
  { entity = "rf-aneutronic-reactor", plasma = "rf-d-he3-plasma"   },
  { entity = "rf-aneutronic-reactor", plasma = "rf-he3-he3-plasma" },
} or {
  { entity = "rf-reactor",            plasma = "rf-d-d-plasma"     },
}

-- Every distance below is derived from the reactor's own prototype, and that is the whole reason
-- this section was rewritten: the rig used to hardcode a cell eight tiles wide with the feed pipe
-- two tiles left of centre, which was correct for the 3x2 reactor it was written against and
-- silently wrong the day the reactor became 15x15 (ADR 0013). Nothing errored. The cells simply
-- overlapped, the feed pipe sat six tiles clear of the connection it was meant to touch, and the
-- rig's own "every reactor hot" gate refused to report a number -- which is the gate working, but
-- it took issue #49 to notice why. Read the footprint, do not remember it.
-- Read per CASE, not once, because nothing here may assume the two reactors are the same shape.
-- They are, as of ADR 0022: both fifteen tiles square, where rf-aneutronic-reactor used to be ten.
-- Reading it anyway is the point -- an odd-sized entity centres on a tile CENTRE and an even-sized
-- one on a tile BOUNDARY, so a rig that remembers a size cannot survive one changing, and getting
-- that wrong is #49 again: reactors placed, feed pipes not quite touching them, no error.
--
-- The parity arithmetic below is therefore currently exercised by only one case. It stays because
-- the day a tier arrives at an even size is the day it is needed, and that day will not announce
-- itself.
local function footprint(name)
  local proto = prototypes.entity[name]
  if not proto then error("no such entity prototype: " .. name) end
  local box  = proto.selection_box
  local size = math.floor(box.right_bottom.x - box.left_top.x + 0.5)
  return {
    size = size,
    -- Parity of the entity decides where its centre may sit.
    origin = (size % 2 == 1) and 0.5 or 0.0,
  }
end

for _, case in ipairs(CASES) do case.foot = footprint(case.entity) end

-- One pitch for every cell, taken from the widest reactor in play, so the grid stays square and
-- the baseline map is identical whatever mix is running. A smaller reactor simply has more clear
-- ground around it; the cell is the same size either way.
local SIZE = 0
for _, case in ipairs(CASES) do SIZE = math.max(SIZE, case.foot.size) end
local SPACING = SIZE + GAP
local SPAN    = GRID * SPACING
local EDGE    = SIZE + 8     -- landfill margin: a reactor's own width, plus room for the power

-- The cell's own anchor, in the widest reactor's parity. Each reactor is then placed at the centre
-- ITS parity demands, nearest this point.
local ORIGIN = (SIZE % 2 == 1) and 0.5 or 0.0

-- Cell reach, from the widest reactor. The power islands are laid out against THIS rather than
-- against whichever reactor lands in the cell, so the rig's power is identical at every count and
-- every mix -- which is what lets it cancel out of the deltas.
local CELL_REACH = (SIZE + 1) / 2

-- A 2x2 entity centres on a tile boundary and a 1x1 on a tile centre, whatever the reactor does.
local function even(v) return math.floor(v + 0.5) end
local function odd(v)  return math.floor(v) + 0.5 end

-- The nearest centre this entity's parity allows. An even-sized entity dropped on an odd-sized one's
-- centre is off by half a tile in both axes, which places without error and puts every edge
-- connection half a tile from where the feed pipe is about to go. Both reactors are odd-sized today
-- (ADR 0022); this exists so that stops being something the rig relies on.
local function centre(v, foot)
  if foot.origin == 0.5 then return math.floor(v) + 0.5 else return math.floor(v + 0.5) end
end

-- The fittings the rig bolted on, so the report below can read them back. Kept as the rig's own
-- lists rather than asked of realistic-fusion-refreshed: `storage` is per mod, so requiring
-- entity-management here would get a second copy of the module bound to THIS mod's storage and
-- every pairing table would read empty. What proves the pairing is collected= in the report.
local FITTINGS = {
  { name = "rf-isotope-collector", key = "collectors", wanted = COLLECTORS },
  { name = "rf-lithium-blanket",   key = "blankets",   wanted = BLANKETS   },
}
-- Which of the collector's boxes carries tritium, read from the prototype rather than written
-- down -- control.lua's own check_collector_boxes() exists because that mapping is load-bearing and
-- silent when wrong, and a rig that remembered the index would be the same bug one file over.
--
-- Only this box can saturate, which is why it is singled out. D-D breeds tritium and helium-3 one
-- for one, and the blanket adds tritium on top, so the tritium box fills first and it is the only
-- one whose fill stops anything: blanket_breed() reads ITS headroom.
local TRITIUM_BOX
if COLLECTORS then
  for index, box in ipairs(prototypes.entity["rf-isotope-collector"].fluidbox_prototypes) do
    if box.filter and box.filter.name == "rf-tritium" then TRITIUM_BOX = index end
  end
  if not TRITIUM_BOX then
    error("rf-isotope-collector has no box filtered to rf-tritium; the fill report would measure " ..
      "the wrong box and the saturation warning would never fire.")
  end
end

-- Which plasmas release a neutron, read from the shipped physics rather than written down. A
-- blanket breeds from neutrons, so this is exactly which blankets in a mixed rig are EXPECTED to
-- spend lithium and which are correctly idle -- and predicting it here is what lets the gate below
-- demand every one of them rather than settling for "at least one bred".
--
-- Required from __realistic-fusion-refreshed__ the same way the ablation ladder requires it: this
-- is the shipped table, not a copy, so a fuel that stops making neutrons moves this gate with it.
local NEUTRONIC
if BLANKETS then
  local fuels = require("__realistic-fusion-refreshed__/scripts/reactor-logic").fuels
  NEUTRONIC = {}
  for _, case in ipairs(CASES) do
    local fuel = fuels[case.plasma]
    if not fuel then
      error("reactor-logic declares no fuel row for " .. case.plasma ..
        ", so the rig cannot say whether a blanket on it should breed.")
    end
    NEUTRONIC[case.plasma] = (fuel.neutrons_per_reaction or 0) > 0
  end
end

for _, fitting in ipairs(FITTINGS) do
  if fitting.wanted then
    fitting.foot = footprint(fitting.name)
    -- A NECESSARY CONDITION, not the authority, and the distinction matters because the first
    -- version of this line got it wrong. Both fittings sit in the GAP-deep band south of the
    -- reactor, so a gap no wider than a fitting leaves it flush against the NEXT row's reactor and
    -- inside the whole tile of margin entity-management's attach() searches -- and `>` let the
    -- equal case through, which is the default -Gap 5 against a five-tile fitting, which is the
    -- exact configuration this rig shipped a wrong measurement from.
    --
    -- `>=` is therefore the operator, but it is still arithmetic over remembered collision insets.
    -- What actually decides the question is the one-to-one pairing check at the end of on_init,
    -- which asks the real bounding boxes. This one exists only to fail earlier and say why.
    if fitting.foot.size >= GAP then
      error(string.format("%s is %d tiles and -Gap is %d: it would sit flush against the next " ..
        "row's reactor and pair with that instead. Raise -Gap to at least %d.",
        fitting.name, fitting.foot.size, GAP, fitting.foot.size + 1))
    end
  end
end

--- Bolt the requested fittings to one reactor, in the clear ground south of it.
--
-- SOUTH FOR BOTH, side by side, where scripts/check-blanket.ps1 puts the collector south and the
-- blanket north. That rig has one reactor and all four bands free; this one is a grid, and a
-- reactor's north band is the band the row above already put its fittings in.
--
-- Flush against the reactor's own south face, computed from the two footprints rather than written
-- down, so the fittings land inside the one-tile margin entity-management's attach() searches
-- whatever either size becomes. Read the footprint, do not remember it -- see #49.
--
-- raise_built, and after the reactor: pairing happens on the build event, and a fitting bolted on
-- afterwards is the order a player does it in. Placing it silently would exercise a path nobody
-- can take.
local function bolt_on(surface, force, reactor, case, col, row)
  local foot = case.foot
  for _, fitting in ipairs(FITTINGS) do
    if fitting.wanted then
      local ffoot = fitting.foot
      -- Offset so the two fittings sit either side of the reactor's centre line with a tile
      -- between them. Both fit: the reactor is fifteen tiles and two fives plus a gap is eleven.
      local dx = (ffoot.size / 2 + 0.5) * ((fitting.key == "collectors") and -1 or 1)
      local at = {
        centre(reactor.position.x + dx, ffoot),
        centre(reactor.position.y + (foot.size + ffoot.size) / 2, ffoot),
      }
      local e = surface.create_entity({
        name = fitting.name, position = at, force = force, raise_built = true,
      })
      if not e then
        error(string.format("%s refused at cell %d,%d (%g, %g)", fitting.name, col, row, at[1], at[2]))
      end
      if fitting.key == "blankets" then
        local put = e.insert({ name = "rf-lithium", count = LITHIUM_LOADED })
        if put < LITHIUM_LOADED then
          error(string.format("blanket at cell %d,%d took only %d of %d lithium: the inventory is " ..
            "smaller than this rig assumes", col, row, put, LITHIUM_LOADED))
        end
        -- Counted as the run is built, from the fuel this reactor is actually being fed, so the
        -- gate can require every blanket that OUGHT to breed rather than one of them. An
        -- aneutronic row contributes nothing here and is correctly expected to stay idle.
        if NEUTRONIC[case.plasma] then
          storage.neutronic_blankets = (storage.neutronic_blankets or 0) + 1
        end
      end
      storage[fitting.key][#storage[fitting.key] + 1] = e
    end
  end
end

script.on_init(function()
  storage.reactors   = {}
  storage.collectors = {}
  storage.blankets   = {}
  storage.neutronic_blankets = 0

  -- On surface 1 for a map this script created, on a surface of our own for a borrowed base.
  --
  -- on_init RUNS WHEN A MOD IS ADDED TO AN EXISTING SAVE, which is the whole mechanism -PlantInto
  -- rests on and was measured on 2.0.77 before it was written: the surface and the entities created
  -- here are present for the ticked run, and --benchmark never saves, so none of it survives the
  -- process.
  --
  -- REFUSED RATHER THAN REUSED if the name is taken. The landfill-and-clear pass below destroys
  -- every entity in its area, so building over a surface somebody else made would wreck their work
  -- in a run they had every reason to think was read-only -- and it would do it in silence.
  local surface
  if SURFACE == "" then
    surface = game.surfaces[1]
  elseif game.surfaces[SURFACE] then
    error(string.format("this save already has a surface called '%s'; the rig will not build over " ..
      "one it did not create, because it landfills and clears everything in its area", SURFACE))
  else
    surface = game.create_surface(SURFACE)
  end
  local force   = game.forces.player
  local area    = { { -EDGE, -EDGE }, { SPAN + EDGE, SPAN + EDGE } }

  surface.request_to_generate_chunks({ SPAN / 2, SPAN / 2 },
    math.ceil((SPAN / 2 + EDGE + 64) / 32))
  surface.force_generate_chunk_requests()

  -- Landfill over the lot: it removes the water without needing to know where any was, and it is
  -- buildable everywhere. Then clear what generated on top of it.
  local tiles = {}
  for x = -EDGE, SPAN + EDGE do
    for y = -EDGE, SPAN + EDGE do
      tiles[#tiles + 1] = { name = "landfill", position = { x, y } }
    end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = area })) do
    if e.type ~= "character" then e.destroy() end
  end

  -- Power, one island per cell rather than one grid over all of them. A substation reaches 18
  -- tiles and a cell is now wider than that, so a single connected network is no longer available
  -- at any spacing that fits the reactor; each cell instead gets a substation covering its
  -- reactor's centre and an interface inside that substation's own supply area.
  --
  -- Built for every cell of the grid at every count, including zero, so it is present in the
  -- baseline and cancels out of the deltas exactly as the shared grid used to.
  --
  -- Every placement is checked: a create_entity that quietly returns nil here leaves reactors
  -- unpowered, and an unpowered reactor still runs the whole step, so it would not show up as a
  -- cost anomaly -- only as a wrong claim about what was measured.
  for col = 0, GRID - 1 do
    for row = 0, GRID - 1 do
      local cx, cy = col * SPACING + ORIGIN, row * SPACING + ORIGIN
      -- In the gap east of the reactor, and pushed off the connection row so that -Pooled's pipe
      -- run has it to itself. Within nine tiles of the reactor's centre in both axes, which is
      -- what a substation's 18x18 supply area needs to cover it.
      local sub = surface.create_entity({
        name = "substation", position = { even(cx + CELL_REACH + 0.5), even(cy + 4.5) }, force = force,
      })
      if not sub then error(string.format("substation refused at cell %d,%d", col, row)) end

      local eei = surface.create_entity({
        name = "electric-energy-interface", position = { odd(cx + CELL_REACH + 3), odd(cy + 4.5) },
        force = force,
      })
      if not eei then error(string.format("power source refused at cell %d,%d", col, row)) end
      -- J/tick. 2e6 is ~120 MW, ample for rf-reactor's 50 MW; the aneutronic reactor draws four
      -- times that, so a mixed rig needs headroom or half its reactors sit clamped. Raised only
      -- when MIXED, so an unmixed run is byte-for-byte the rig #24 measured.
      eei.power_production = MIXED and 8e6 or 2e6
    end
  end

  local placed = 0
  for i = 0, COUNT - 1 do
    local col, row = i % GRID, math.floor(i / GRID)
    local cx, cy = col * SPACING + ORIGIN, row * SPACING + ORIGIN
    -- By row, so a pooled row stays one fluid. See CASES.
    local case  = CASES[(row % #CASES) + 1]
    local foot  = case.foot
    local rx, ry = centre(cx, foot), centre(cy, foot)
    local r = surface.create_entity({
      name     = case.entity,
      position = { rx, ry },
      force    = force,
      -- Registers the reactor through the same event path a player builds it through, rather
      -- than through a rescan that only runs on init.
      --
      -- And the seam the ablation ladder hangs on. Suppressing it is the only way one mod can stop
      -- another's per-tick handler from doing anything: realistic-fusion-refreshed registers a reactor from
      -- the build event, and its rescan runs on on_init only -- which happens before this rig's,
      -- since the rig depends on it. So an unraised reactor is one the shipped update() never sees,
      -- leaving it walking an empty register while the rig does the step itself.
      raise_built = (ABLATE == "none"),
    })
    if r then
      -- Loud here rather than subtle later. A reactor outside its substation's supply area still
      -- places, still fills, still runs its whole simulation step with the heating clamped to
      -- zero, and costs about what a powered one does -- so the benchmark would report a number
      -- and nothing would say it was taken on a rig that had quietly stopped being the rig
      -- described above. This is the check the old geometry did not have.
      if not r.electric_network_id then
        error(string.format("reactor at cell %d,%d is on no electric network: the substation " ..
          "at (%g, %g) does not reach it", col, row, even(cx + CELL_REACH + 0.5), even(cy + 4.5)))
      end
      -- Fed by an infinity pipe rather than seeded, and that is not laziness about the supply
      -- chain -- a seeded reactor does not stay full. An input-output box shares its contents
      -- with the fluid segment it belongs to in proportion to capacity, and a Lua write is
      -- clamped to the box, so writing the box's full 1000 leaves the box and the segment at
      -- 52.6% each within a second and the reactor simulates half the plasma it appears to hold.
      -- Overfilling does not help; the clamp happens first. Verified against a reactor no Lua
      -- ever touched, which splits identically -- this is the engine's model, not this mod's.
      --
      -- The pipe holds the segment at 100% at a fixed temperature, which is a reactor whose
      -- heater keeps up, and is the state worth measuring. It also pins the temperature rather
      -- than letting the simulation drive it: that is a deliberate trade, because a cost
      -- measurement wants the reactor held in one regime for the whole run, and the cost of a
      -- step does not depend on where in the table the lookup lands.
      -- WHERE the pipe goes is asked of the entity, never derived. The two reactors do not put
      -- their plasma connections in the same place: rf-reactor's sit on the edge midline, and
      -- rf-aneutronic-reactor's are offset half a tile (entities.lua declares them at y = 0.5), so
      -- a rig that computed "centre minus half the width" would place every aneutronic feed pipe
      -- one tile from the connection it is meant to touch. Nothing errors; the reactors simply
      -- never fill, and the hot= gate reports a broken rig without saying why. That is #49 twice.
      -- scripts/check-aneutronic.ps1 already reads target_position for exactly this reason.
      local conns = r.fluidbox.get_pipe_connections(1)
      if not conns or #conns == 0 then
        error(string.format("%s at cell %d,%d has no plasma pipe connections", case.entity, col, row))
      end
      local west = conns[1].target_position
      for _, c in ipairs(conns) do
        if c.target_position.x < west.x then west = c.target_position end
      end

      if (not POOLED) or col == 0 then
        local feed = surface.create_entity({
          name = "__PLASMAFEED__", position = { west.x, west.y }, force = force,
        })
        if not feed then error(string.format("infinity-pipe refused at cell %d,%d", col, row)) end
        -- 6e8 C for every reaction: all four plasmas declare the same max_temperature -- 5e9 since
        -- #58 -- and holding the whole rig at one temperature keeps the mix the only thing that
        -- differs from #24.
        feed.set_infinity_pipe_filter({ name = case.plasma, percentage = 1, temperature = 6e8, mode = "at-least" })
      end
      storage.reactors[#storage.reactors + 1] = r
      placed = placed + 1

      -- After the feed and before the pipe run, so a fitting that lands somewhere it should not
      -- errors before the row it would have broken is built.
      bolt_on(surface, force, r, case, col, row)

      if POOLED and col > 0 then
        -- GAP pipes bridge the gap between this reactor's west connection and its neighbour's
        -- east one, putting the whole row on one fluid segment. The count is the gap by
        -- construction: the run starts at the neighbour's first outside tile and ends at this
        -- reactor's, and SPACING is SIZE + GAP.
        -- SPACING - size, not GAP: with two reactor shapes in play the clear run between one
        -- reactor and its neighbour is only GAP for the widest of them. The narrower one sits in
        -- the same cell with more ground either side, and needs a longer bridge.
        local bridge = SPACING - foot.size
        for j = 1, bridge do
          local p = surface.create_entity({
            name = "rf-pipe", position = { west.x - bridge + j, west.y }, force = force,
          })
          if not p then error(string.format("rf-pipe refused at cell %d,%d segment %d", col, row, j)) end
        end
      end
    end
  end

  -- EVERY REACTOR MUST SEE EXACTLY ONE OF EACH FITTING, and this is a gate rather than a comment.
  --
  -- entity-management pairs by the tiles touching the reactor with a WHOLE TILE of margin, and the
  -- band a fitting sits in is only GAP deep. At a tight gap a flush fitting therefore reaches past
  -- its own cell into the next row's reactor, which pairs with it instead: attach() takes the
  -- lowest unit_number, and fittings are created in row order. Nothing errors and the cost barely
  -- moves -- every reactor still has a collector and deposit() still runs -- but the rig stops
  -- being the thing it says it is. One row's fittings serve two reactors while the last row's serve
  -- none, and the blanket draining at twice the rate runs dry first behind a gate that reads only
  -- the total. At -Gap 5 with a five-tile fitting the overlap is half a tile, which is why this is
  -- checked against the real bounding boxes rather than derived from remembered collision insets.
  for _, fitting in ipairs(FITTINGS) do
    if fitting.wanted then
      for _, r in pairs(storage.reactors) do
        local box = r.bounding_box
        local seen = r.surface.find_entities_filtered({
          area = { { box.left_top.x - 1, box.left_top.y - 1 },
                   { box.right_bottom.x + 1, box.right_bottom.y + 1 } },
          name = fitting.name,
        })
        if #seen ~= 1 then
          error(string.format("the reactor at (%g, %g) touches %d %s, not 1: at -Gap %d a fitting " ..
            "reaches into the neighbouring cell, so reactors and fittings do not pair one to one. " ..
            "Raise -Gap to at least %d.", r.position.x, r.position.y, #seen, fitting.name, GAP,
            fitting.foot.size + 1))
        end
      end
    end
  end

  log(string.format("BENCH-RIG grid=%d size=%d spacing=%d requested=%d placed=%d pooled=%s mixed=%s cases=%d collectors=%d blankets=%d",
    GRID, SIZE, SPACING, COUNT, placed, tostring(POOLED), tostring(MIXED), #CASES,
    #storage.collectors, #storage.blankets))
end)

-- ---------------------------------------------------------------- the ablation ladder (#39)
--
-- Only when -Ablate names a rung. The shipped mod is then registering nothing (see raise_built
-- above), so this is the entire per-reactor cost of the run, and the rungs differ from each other
-- by exactly one group of operations. The physics is REQUIRED from the shipped mod rather than
-- reimplemented -- a copy would measure the copy.
--
-- steps/touched are logged and gated on, because a rung below `write` writes nothing to the world
-- and so leaves no trace the output= gate could check. A handler that silently failed to register
-- would report a per-reactor cost of nothing at all, which is indistinguishable from the finding.
local ablate_steps, ablate_touched = 0, 0
if ABLATE ~= "none" then
  local logic = require("__realistic-fusion-refreshed__/scripts/reactor-logic")
  local SPECS = {
    ["rf-reactor"]            = logic.reactor,
    ["rf-aneutronic-reactor"] = logic.aneutronic_reactor,
  }
  local RUNG = ({ loop = 1, read = 2, physics = 3, write = 4 })[ABLATE]
  if not RUNG then error("unknown ablation rung: " .. ABLATE) end
  local DT = INTERVAL / 60
  -- Mirrors control.lua's MIN_FLUID. Below it the engine rejects the write outright, so the guard
  -- is part of the write rung rather than a nicety.
  local MIN_FLUID = 1e-6

  script.on_nth_tick(INTERVAL, function()
    local pending = (RUNG >= 4) and {} or nil
    local n = 0
    for _, entity in pairs(storage.reactors) do
      if entity.valid then
        n = n + 1
        if RUNG >= 2 then
          local plasma = entity.fluidbox[1]
          local energy = entity.energy
          if RUNG >= 3 then
            local spec = SPECS[entity.name]
            local result = logic.step(spec, plasma and plasma.name, plasma and plasma.amount,
              plasma and plasma.temperature, energy, DT)
            if pending and result then
              pending[#pending + 1] = { entity = entity, spec = spec, plasma = plasma, result = result }
            end
          end
        end
      end
    end
    ablate_steps   = ablate_steps + 1
    ablate_touched = ablate_touched + n

    -- The write half of control.lua's apply(), minus the collector lookup and the circuit publish:
    -- both are per reactor and both are in the shipped path, so this rung is a floor on the shipped
    -- cost rather than a reproduction of it.
    if pending then
      for _, s in ipairs(pending) do
        local entity, result = s.entity, s.result
        entity.energy = entity.energy - result.heating_used_j
        local box = entity.fluidbox
        local remaining = s.plasma.amount - result.plasma_consumed
        if remaining > 0 then
          box[1] = { name = s.plasma.name, amount = remaining, temperature = result.temperature_c }
        else
          box[1] = nil
        end
        if result.energy_units >= MIN_FLUID then
          local produced = box[2]
          local amount = result.energy_units + (produced and produced.amount or 0)
          local capacity = box.get_capacity(2)
          if amount > capacity then amount = capacity end
          box[2] = { name = s.spec.energy_fluid, amount = amount, temperature = 15 }
        end
      end
    end
  end)
end

-- Proof that what was benchmarked was a running reactor and not a cold one. One tick in a hundred
-- carries a log write, and the median throws away far more of the distribution than that.
script.on_nth_tick(__REPORT__, function()
  local n, hot, powered, temp, plasma, output, energy = 0, 0, 0, 0, 0, 0, 0
  -- Tallied by the fluid each reactor is actually burning, because that -- not the entity, and not
  -- what the rig meant to build -- is what "all four reactions running" means. Two of the four
  -- share an entity, so counting entities cannot tell D-D from D-T. #34 rests on this line.
  local burning = {}
  for _, r in pairs(storage.reactors) do
    if r.valid then
      n = n + 1
      energy = energy + r.energy
      if r.electric_network_id then powered = powered + 1 end
      local fb = r.fluidbox[1]
      if fb then
        plasma = plasma + fb.amount
        temp   = temp + fb.temperature
        if fb.temperature > 1e6 then hot = hot + 1 end
        burning[fb.name] = (burning[fb.name] or 0) + 1
      end
      local out = r.fluidbox[2]
      if out then output = output + out.amount end
    end
  end
  local d = (n > 0) and n or 1

  -- Sorted, so the string is stable between runs and can be compared rather than merely read.
  local names = {}
  for name in pairs(burning) do names[#names + 1] = name end
  table.sort(names)
  local mix = {}
  for _, name in ipairs(names) do mix[#mix + 1] = string.format("%s:%d", name, burning[name]) end

  -- The fittings, and the two numbers that prove they were PAIRED rather than merely placed
  -- (#62). Placement is logged at map creation and says nothing: entity-management pairs by the
  -- tiles touching the reactor, so a fitting half a tile out of reach still places, still shows up
  -- in the count, and is never looked at again.
  --
  -- collected= is the collector's equivalent of output= above. deposit() is the only thing in the
  -- game that writes these boxes, so a non-zero total is proof the reactor found its collector.
  --
  -- tritium= and full_pct= are separate from it, and the separation is the point. full_pct is the
  -- WORST tritium box, not an average over every box of every collector: only the tritium box can
  -- saturate, and only its fill stops anything, so a figure pooled across both boxes and two
  -- hundred collectors could never reach a threshold set for the box that matters. It also makes
  -- the blanket's contribution readable -- the blanket adds tritium and nothing else, so tritium=
  -- is the number to compare between a collected run and a blanketed one, where collected= mixes in
  -- an unchanged helium-3 half and understates it.
  --
  -- bred= and lithium_min= are the blanket's, and they are counted PER BLANKET for the same reason.
  -- Nothing but blanket_breed() takes items out of these containers, so a blanket whose stock has
  -- fallen is one that ran -- but a sum over two hundred of them is satisfied by a single one
  -- running, and cannot see the one that ran dry. bred= is how many actually moved; lithium_min= is
  -- the least any of those has left, so zero means one ran dry and the rest of that run measured an
  -- empty container.
  --
  -- expect= is what bred= is checked against, and it is predicted from the shipped fuel table as
  -- the rig is built rather than assumed. A blanket breeds from neutrons, so a mixed rig's
  -- aneutronic rows are correctly idle and its neutronic rows must every one of them have run. The
  -- gate used to accept "at least one bred" on a mixed run, which is a hundred and nine silently
  -- idle blankets away from what it reads as.
  local collected, tritium, full_pct = 0, 0, 0
  for _, c in pairs(storage.collectors) do
    if c.valid then
      for index = 1, #c.fluidbox do
        local held = c.fluidbox[index]
        if held then collected = collected + held.amount end
      end
      local held = c.fluidbox[TRITIUM_BOX]
      local amount = held and held.amount or 0
      tritium = tritium + amount
      local pct = 100 * amount / c.fluidbox.get_capacity(TRITIUM_BOX)
      if pct > full_pct then full_pct = pct end
    end
  end
  local lithium, bred, lithium_min = 0, 0, -1
  for _, b in pairs(storage.blankets) do
    if b.valid then
      local left = b.get_inventory(defines.inventory.chest).get_item_count("rf-lithium")
      lithium = lithium + left
      if left < LITHIUM_LOADED then
        bred = bred + 1
        if lithium_min < 0 or left < lithium_min then lithium_min = left end
      end
    end
  end

  log(string.format("BENCH-RIG tick=%d reactors=%d hot=%d powered=%d temp_c=%.4g plasma=%.4g output=%.4g buffer_j=%.4g burning=%s ablate=%s steps=%d touched=%d collectors=%d collected=%.4g tritium=%.4g full_pct=%.3g blankets=%d bred=%d expect=%d lithium=%d lithium_min=%d",
    game.tick, n, hot, powered, temp / d, plasma / d, output / d, energy / d,
    (#mix > 0) and table.concat(mix, ",") or "none", ABLATE, ablate_steps, ablate_touched,
    #storage.collectors, collected, tritium, full_pct,
    #storage.blankets, bred, storage.neutronic_blankets or 0, lithium, lithium_min))
end)
'@
    # The shipped plasma set carries its own pipe connection category (#26), so a vanilla
    # infinity-pipe can no longer feed a reactor. The rig declares one that can.
    $lua = $lua.Replace('__COUNT__', "$Count").Replace('__GRID__', "$grid").
                Replace('__REPORT__', "$ReportEvery").Replace('__GAP__', "$Gap").
                Replace('__PLASMAFEED__', (Write-PlasmaFeed -RigDirectory $rigDir)).
                Replace('__POOLED__', $(if ($Pooled) { 'true' } else { 'false' })).
                Replace('__MIXED__', $(if ($Mixed) { 'true' } else { 'false' })).
                Replace('__COLLECTORS__', $(if ($Collectors) { 'true' } else { 'false' })).
                Replace('__BLANKETS__', $(if ($Blankets) { 'true' } else { 'false' })).
                Replace('__LITHIUM__', "$lithiumPerBlanket").
                Replace('__ABLATE__', $Ablate).Replace('__INTERVAL__', "$interval").
                Replace('__SURFACE__', ($PlantInto ? $plantSurface : ''))
    Set-Content -Path (Join-Path $rigDir 'control.lua') -Value $lua -Encoding utf8
}

# The three things every run of this script shares, so that each call below names only what makes
# it that run. Running-or-throwing itself lives in factorio-lib.ps1.
$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

function Get-Timings {
    <#  Parse --benchmark-verbose output into per-category sample lists, in nanoseconds.

        The dump is a CSV header ("tick,timestamp,wholeUpdate,...") followed by one "t<n>,..." row
        per tick, repeated per run. Rows whose field count does not match the header are dropped
        rather than guessed at -- a truncated final row is the expected case if the process is
        killed, and a silently misaligned column would be worse than a missing sample.  #>
    param([string] $Path)

    $header = $null
    $cols   = [ordered]@{}
    foreach ($line in [IO.File]::ReadLines($Path)) {
        if ($line.StartsWith('tick,timestamp,')) {
            if (-not $header) {
                $header = $line.TrimEnd(',') -split ','
                foreach ($h in $header) { $cols[$h] = [System.Collections.Generic.List[double]]::new() }
            }
            continue
        }
        if ($line.Length -lt 2 -or $line[0] -ne 't' -or -not [char]::IsDigit($line[1])) { continue }
        if (-not $header) { continue }
        $f = $line.TrimEnd(',') -split ','
        if ($f.Count -ne $header.Count) { continue }
        for ($i = 2; $i -lt $header.Count; $i++) { $cols[$header[$i]].Add([double]$f[$i]) }
    }

    if (-not $header) { throw "no verbose benchmark output found in $Path (was --benchmark-verbose passed?)" }
    foreach ($c in $REPORT) {
        if (-not $cols.Contains($c)) { throw "benchmark output has no '$c' column; the timing names changed." }
    }
    if ($cols['scriptUpdate'].Count -eq 0) { throw "no tick rows parsed from $Path." }
    return $cols
}

function Split-Runs {
    <#  Cut a pooled sample list back into one list per benchmark run.

        --benchmark-runs concatenates its runs into one verbose dump in order, so the split is
        positional: run r is samples [r*Ticks, (r+1)*Ticks). Returns nothing if the sample count
        does not match, rather than guessing at a boundary.

        This was built to test the standing explanation for this rig's run-to-run spread -- thermal
        throttling on a laptop part -- and disposed of it: #39 found the part never drops below its
        base clock, and that the spread is other work on the machine. What the split is worth
        keeping for is what it found on the way. A single benchmark run of the identical map spans
        1.86x, where the invocation that pools five of them spans 1.34x, so an outlier run is the
        unit of noise here. Printing the runs separately is what makes one visible instead of
        leaving it buried in the mean it moved.  #>
    param([System.Collections.Generic.List[double]] $Values, [int] $Ticks, [int] $Runs)
    if ($Values.Count -ne $Ticks * $Runs) { return @() }
    $out = @()
    for ($r = 0; $r -lt $Runs; $r++) {
        $out += , ([System.Collections.Generic.List[double]] $Values.GetRange($r * $Ticks, $Ticks))
    }
    return $out
}

# The counters the machine is watched through, and the one place their names live.
#
# `% Processor Performance` is the effective clock as a percentage of the part's BASE frequency --
# the same counter Task Manager's "Speed" is derived from. A thermally throttled part sits BELOW 100
# and stays there; one that is merely busy sits above it on turbo. That distinction is what ruled
# thermal throttling out under #39.
#
# `% Processor Utility` is how much of the machine is in use. Ours is one Factorio and its benchmark
# is single-threaded, so on a twelve-thread part this run's own contribution is under a tenth.
# Anything much above that is somebody else's work -- the one confound this rig cannot subtract,
# because every figure it reports is a difference between two Factorio processes minutes apart, and
# work that arrives between them lands on the difference rather than cancelling.
#
# THE NAMES ARE LOCALISED ON NON-ENGLISH WINDOWS, so Get-Counter throws rather than answering. That
# is handled as "not known to have been quiet" and never as "quiet" -- see the NaN branch below. A
# guard that cannot run has not passed.
$PERF_COUNTER = '\Processor Information(_Total)\% Processor Performance'
$LOAD_COUNTER = '\Processor Information(_Total)\% Processor Utility'

function Get-ForeignLoad {
    <#  How much of the machine somebody else is using, as a percentage of the whole part.

        Taken BEFORE Factorio is launched, and that timing is the whole design. Sampled during the
        run it would be measuring us: Factorio starts up and loads a save multi-threaded, and on an
        invocation this short that burst is most of what there is to see -- which is how a during-run
        version of this guard came to warn on every run, including runs on an idle machine. Before
        the launch there is no Factorio of ours, so whatever the counter reports is somebody else's.

        WHAT IT CANNOT SEE is work that begins after the launch and ends before the process exits.
        Over a sweep that gap is small and self-closing: each count takes its own reading, so a
        compile long enough to matter is caught by the next one. A compile that fits entirely inside
        a five-second invocation is not, and no reading taken from outside the process would separate
        it from Factorio's own threads anyway. Read the warning as "this count was launched onto a
        busy machine", which is the claim it can actually support.  #>
    try {
        [math]::Round((Get-Counter $LOAD_COUNTER -ErrorAction Stop).CounterSamples[0].CookedValue, 1)
    } catch { [double]::NaN }
}

function Get-ClockPercent {
    <#  One sample of the effective clock, for the record rather than for a decision -- nothing is
        gated on it, because #39 settled the question it answers. NaN when the counter refuses.  #>
    try {
        [math]::Round((Get-Counter $PERF_COUNTER -ErrorAction Stop).CounterSamples[0].CookedValue, 1)
    } catch { [double]::NaN }
}

function Get-Median {
    param([System.Collections.Generic.List[double]] $Values)
    if ($Values.Count -eq 0) { return [double]::NaN }
    $s = [double[]] $Values; [Array]::Sort($s)
    $n = $s.Count
    if ($n % 2) { return $s[($n - 1) / 2] }
    return ($s[$n / 2 - 1] + $s[$n / 2]) / 2
}

function New-TimingRow {
    <#  One result row from a parsed benchmark dump. Shared by the rig sweep and -Save, which is
        the whole of acceptance criterion one of #64: the two paths do not merely report the same
        column NAMES, they compute them with the same code.  #>
    param(
        [Parameter(Mandatory)] $Columns,
        [Parameter(Mandatory)] [int] $Reactors,
        [AllowEmptyString()] [string] $State = '',
        [double] $Cpu = [double]::NaN,
        [double] $Load = [double]::NaN
    )

    $row = [ordered]@{
        Reactors = $Reactors; Samples = $Columns['scriptUpdate'].Count; State = $State
        CpuPerf = $Cpu; CpuLoad = $Load
        # Per run rather than pooled, because that is the axis drift lives on. The median for
        # wholeUpdate -- the machine's own indicator, and the one a load spike would otherwise
        # dominate -- and the mean for scriptUpdate, which is the statistic every figure this
        # script reports is taken from.
        WholeByRun  = @(Split-Runs $Columns['wholeUpdate']  $Ticks $Runs | ForEach-Object { Get-Median $_ })
        ScriptByRun = @(Split-Runs $Columns['scriptUpdate'] $Ticks $Runs |
                        ForEach-Object { ($_ | Measure-Object -Average).Average })
    }
    foreach ($c in $REPORT) {
        $row["$c.median"] = (Get-Median $Columns[$c]) / 1000.0   # ns -> us
        $row["$c.mean"]   = (($Columns[$c] | Measure-Object -Average).Average) / 1000.0
    }
    return [pscustomobject]$row
}

function Write-StatTables {
    <#  The absolute per-category tables, in both statistics.

        Both are printed and they answer different questions, which matters as soon as the mod
        updates on anything but every tick. The mean is the cost: averaged over thousands of ticks
        it is what UPS actually spends, and a throttled mod that does its work on one tick in six
        costs exactly what it did before divided by six. The median is what a tick feels like, and
        it is the honest one for per-tick work because a benchmark run carries spikes an order of
        magnitude above the typical tick. Under throttling the median collapses towards the
        baseline -- five ticks in six now do nothing -- so per-reactor cost is taken from the mean.  #>
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Results)

    foreach ($stat in @('median', 'mean')) {
        Write-Host ''
        Write-Host "$stat tick, microseconds"
        Write-Host ('{0,-9}' -f 'reactors') -NoNewline
        foreach ($c in $REPORT) { Write-Host ('{0,22}' -f $c) -NoNewline }
        Write-Host ''
        foreach ($r in $Results) {
            Write-Host ('{0,-9}' -f $r.Reactors) -NoNewline
            foreach ($c in $REPORT) { Write-Host ('{0,22:N2}' -f $r."$c.$stat") -NoNewline }
            Write-Host ''
        }
    }
}

function Write-MachineNote {
    <#  What the machine was doing when a measurement was launched, and a warning when that was
        somebody else's work. $Why is the one sentence that differs between the two callers: the
        rig's figures are differences against a baseline measured minutes earlier, and -Save's are
        not differences at all, so the reason other work is dangerous is not the same reason.  #>
    param(
        [Parameter(Mandatory)] [string] $Label,
        [Parameter(Mandatory)] [double] $Cpu,
        [Parameter(Mandatory)] [double] $Load,
        [Parameter(Mandatory)] [string] $Why
    )

    Write-Host ("        machine: clock {0:N0}% of base, {1:N0}% of the part in other hands at launch" -f $Cpu, $Load)
    # An unreadable counter is its own warning and is NOT a quiet machine. `NaN -gt $BusyPercent`
    # is false in PowerShell, so without this branch a localised Windows -- where these counter
    # paths are translated and Get-Counter simply throws -- would run a fully contended sweep and
    # print no BUSY at all, which is the one outcome this guard must never produce.
    if ([double]::IsNaN($Load)) {
        Write-Warning ((("{0}: the machine's load counter did not answer, so this run is NOT " +
            "known to have been quiet. Treat it as unguarded rather than as clean -- the check " +
            "did not run, which is not the same as passing. The counter names are localised on " +
            "non-English Windows; 'lodctr /R' repairs a corrupt counter cache.") -f $Label))
    }
    # Otherwise a warning rather than a throw, because there is no calibrated threshold here and
    # refusing to report would be worse than reporting with the caveat attached. BUSY is the word
    # to grep for before quoting a figure from a run.
    elseif ($Load -gt $BusyPercent) {
        # Parenthesised as one string before -f, for the reason the n = 0 guard below spells out:
        # -f binds tighter than +, so without them the format applies to the last fragment only
        # and the message prints a literal {0}.
        Write-Warning ((("{0}: BUSY -- {1:N0}% of the part was already in other hands when this " +
            "was launched. {2} Re-run on a quiet machine before quoting it.") -f $Label, $Load, $Why))
    }
}

function Complete-Run {
    <#  Tear down what this run built, from either path's finally block. #>
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }

    # Junctions always go, even with -KeepTemp: leaving links to the repo in %TEMP% hands a
    # delete-through-the-link hazard to whatever cleans it up later.
    Remove-ModJunctions -ModDirectory $modDir

    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'bench-reactors' }
}

function Write-Survey {
    <#  Generate the mod that takes -Save's reactor census.

        A SEPARATE FACTORIO RUN FROM THE ONE THAT PRODUCES THE NUMBERS, and that is the point of
        it being its own mod rather than a report tick bolted onto the measurement. Adding a mod to
        a save adds its Lua to scriptUpdate, and -Save has no baseline to subtract that back out of
        -- the rig can charge its own report walk to a delta, this cannot. So the census gets a run
        of its own with this mod enabled, the measurement runs with it explicitly disabled, and the
        cost it adds to the reported figures is none.

        What it costs instead is one more load of the save and one more run of it, which is why the
        walk happens twice in that run rather than every tick. See the census run's own note for
        why it is a full-length run and not a single tick.

        It also WRITES to the map, which only a discarded run may do -- the sentinel that proves
        the shipped simulation is stepping these reactors. That is the second reason the census is
        its own process rather than a tick of the measurement, and the stronger one.

        The reactor names come out of the shipped module rather than from here, for the reason the
        rig reads its footprints: a third reactor would otherwise be counted by nothing and the
        census would report a confident short total. It is READ from the file rather than required
        into the mod, because requiring entity-management installs its build handlers -- which is
        why circuit-output.lua does not require it either.  #>

    $surveyDir = Join-Path $modDir $surveyName
    New-Item -ItemType Directory -Path $surveyDir -Force | Out-Null

    $source = Join-Path $repoRoot 'realistic-fusion-refreshed/scripts/entity-management.lua'
    if ((Get-Content $source -Raw) -notmatch '(?m)^local REACTORS = \{([^}]*)\}') {
        throw ("could not read REACTORS from $source, so the census would have to guess which " +
               'prototypes are reactors.')
    }
    $names = @([regex]::Matches($Matches[1], '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    if ($names.Count -eq 0) { throw "read an empty REACTORS list from $source." }

    @{
        name = $surveyName; version = '0.0.1'; title = 'Reactor census'
        author = 'bench-reactors.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $surveyDir 'info.json') -Encoding utf8

    $lua = @'
-- Generated by scripts/bench-reactors.ps1. Nothing here ships.

local REACTORS = { __REACTORS__ }

-- How long the run this census describes is, so the last report lands at the end of a window the
-- same length as one measured run.
local TICKS = __TICKS__

-- Ticks between one circuit publish and the next, read out of control.lua by the caller. What the
-- gate below waits for.
local PUBLISH_EVERY = __PUBLISH_EVERY__

-- ------------------------------------------------------------------ is anything SIMULATING these?
--
-- Counting reactors proves they EXIST. It does not prove realistic-fusion-refreshed has any of them in its
-- register, and that distinction is the whole of this block. find_entities_filtered reads the map;
-- entity.fluidbox reads fluid the engine moves. Both answer identically for a reactor the mod has
-- never heard of -- so a save whose registration silently broke would report a full, convincing
-- census, and the cost figure beside it would be the cost of dead entities nobody is stepping.
--
-- The rig path has gated on this since 5ce645e, using reactor energy produced. That does not
-- transfer: a rig accumulates its output because nothing drains it, and a factory drains it, so an
-- amount in the box at one instant says nothing about who put it there.
--
-- WHAT DOES TRANSFER IS A SENTINEL. Every reactor has a companion constant combinator named after
-- it, created on demand by circuit-output.lua, and publish() assigns that combinator's whole filter
-- list every reporting tick -- deliberately, so that what is on the wire is the reactor's own
-- account of itself and not something a player typed. So: plant a signal of our own in there on the
-- first tick, and look for it again at the end. Gone means publish() ran for that reactor, which
-- only the register can cause. Still there means nothing is stepping it.
--
-- It tests REGISTRATION rather than health, which is what makes it usable on somebody else's
-- factory: control.lua publishes for every registered reactor on a report tick including a starved
-- one, so a cold, empty, unpowered reactor still clears this gate. That is correct. "Nobody is
-- simulating it" and "it has no fuel" are different findings and the census reports the second one
-- separately, under burning=.
--
-- IT WRITES TO THE MAP, AND THAT IS SAFE HERE FOR ONE REASON ONLY: this is the census run, whose
-- numbers are thrown away. --benchmark never saves, and the run that produces the reported figures
-- is a SEPARATE process opening the untouched file. If this ever moves into the measurement run,
-- the sentinel has to go.
--
-- MEASURED, NOT ASSUMED. Both failure branches were poisoned on a ten-reactor save and both were
-- caught, with the shipped mod loaded and its reactors present, hot and burning D-D throughout:
--
--   registration removed (control.lua's script.on_nth_tick call deleted)   simulated=0 nocomb=10
--   registration stopped after tick 45, so every combinator exists and
--     one publish has already happened before the sentinels go in         simulated=0 stale=10
--   shipped, unmodified                                                   simulated=10 erased=10
--
-- The middle row is the one that needed the planting tick moved off tick 1; see PLANT_AT below.
-- The poison lived in a copy of the mod under %TEMP%, never in the repository.
local SENTINEL = { type = "virtual", name = "signal-0", quality = "normal" }

local function combinator_of(entity)
  local name = entity.name .. "-signals"
  -- Guarded rather than assumed: find_entities_filtered THROWS on a name no loaded prototype has,
  -- which would kill the census over a mod version that predates the companion combinator.
  if not prototypes.entity[name] then return nil end
  -- At the reactor's own position, which is where circuit-output.lua creates it. Filtered by name
  -- as well, because the reactor's own box contains that point too.
  return entity.surface.find_entities_filtered({ name = name, position = entity.position })[1]
end

local function section_of(entity)
  local combinator = combinator_of(entity)
  if not combinator then return nil end
  local behavior = combinator.get_control_behavior()
  if not behavior or behavior.sections_count < 1 then return nil end
  return behavior.get_section(1)
end

local function has_sentinel(section)
  for _, filter in pairs(section.filters or {}) do
    if filter.value and filter.value.name == SENTINEL.name then return true end
  end
  return false
end

-- Appended to what is already there rather than replacing it, so the reactor's own two signals are
-- still on the wire while the sentinel sits beside them. publish() drops the lot on its next run,
-- which is exactly what is being detected.
local function plant(entity)
  local section = section_of(entity)
  if not section then return "nocomb" end
  if not has_sentinel(section) then
    local filters = {}
    for _, filter in pairs(section.filters or {}) do filters[#filters + 1] = filter end
    filters[#filters + 1] = { value = SENTINEL, min = 1 }
    section.filters = filters
  end
  return "planted"
end

-- What each reactor looked like when the sentinels went in, keyed by unit_number. The verdict is a
-- COMPARISON, not a snapshot, and this table is why.
--
-- Without it, "combinator present and no sentinel of ours in it" would be the whole test -- which
-- a save whose combinators were built in an earlier life passes while nothing steps it, because
-- nobody checked that a sentinel was ever planted there. Every ok below therefore names its
-- evidence: a mark that publish() erased, or an absence that publish() filled.
local before = {}

-- Four outcomes. Both failures are counted apart because they say different things, and both ways
-- of succeeding are too.
--
--   erased  a sentinel went in and is gone. publish() assigns the whole list, so only it can do
--           that, and only for a reactor in the register.
--   grew    there was no combinator to mark and there is one now. circuit-output.lua creates them
--           on demand from publish(), so its existence is the same proof by the other route --
--           this is the ordinary case on a save written seconds after its reactors were placed.
--   stale   marked, and the mark survived. It has a combinator from some earlier life and nothing
--           stepping it now.
--   nocomb  nothing to mark then, nothing there now. Never published for at all.
local function verdict(entity)
  local was = before[entity.unit_number]
  local section = section_of(entity)
  if was == "planted" then
    if not section then return "stale" end          -- the combinator went away; not a publish
    return has_sentinel(section) and "stale" or "erased"
  end
  if was == "nocomb" then
    return section and "grew" or "nocomb"
  end
  -- A reactor nobody saw on the first tick. Impossible in a benchmark -- nothing builds -- so it is
  -- reported rather than guessed at.
  return "unseen"
end

-- TWICE PER RUN -- not once at the start and not every tick -- and every part of that is
-- deliberate.
--
-- Not every tick, because this walks every entity on every surface. On a factory worth measuring
-- that is the most expensive thing in the run, and a thousand of them would cost more than the
-- measurement it exists to describe.
--
-- Not once, because the verdict below is a COMPARISON between two walks, and because what a
-- reactor is BURNING on the first tick of a reloaded save is not what it burns over the window
-- that gets measured: a save written moments after its reactors were placed has empty plasma boxes
-- until the fluid reaches them, and reporting "(empty)" for a rig that spends the whole benchmark
-- hot would be true of the instant and wrong about the run.
--
-- And the first walk is NOT the first tick. It waits for two publish cycles, so that every
-- registered reactor already has the companion combinator publish() creates on demand and the
-- sentinel has somewhere to go. Planting at tick 1 worked, but it left the case that actually
-- catches a fault -- a mark that gets erased -- unexercised on any save this project can build,
-- because a freshly created save has no combinators yet and every reactor came back "grew one".
-- A gate whose interesting branch never runs is a gate nobody has tested.
--
-- Counted rather than read off game.tick: a save resumes at whatever tick it was written at, so
-- there is no arithmetic on game.tick that gives "the last tick of this run" without knowing that.
local PLANT_AT = 2 * PUBLISH_EVERY
local seen = 0

script.on_event(defines.events.on_tick, function()
  seen = seen + 1
  if seen ~= PLANT_AT and seen < TICKS then return end

  -- Which half of the census this tick is. The first plants the sentinels; the last reads them.
  -- Ordered this way round so that a run too short to hold both -- where seen reaches TICKS at or
  -- before PLANT_AT -- takes the verdict half and reports nothing simulated rather than planting
  -- and never looking. The caller refuses such a run outright; this makes the refusal say so
  -- instead of the survey reporting a confident zero.
  local planting = (seen == PLANT_AT) and (seen < TICKS)

  local kinds, burning, total = {}, {}, 0
  for _, name in ipairs(REACTORS) do kinds[name] = 0 end
  local counts = { erased = 0, grew = 0, stale = 0, nocomb = 0, unseen = 0 }

  -- Counted here rather than with table_size(game.surfaces): game.surfaces is a LuaCustomTable,
  -- which is userdata, and table_size rejects it outright ("table expected, got userdata").
  local surfaces = 0

  -- Every surface. A rig has one; a factory worth measuring may have a dozen, and a reactor on
  -- Vulcanus costs exactly what a reactor on Nauvis does.
  for _, surface in pairs(game.surfaces) do
    surfaces = surfaces + 1
    for _, entity in pairs(surface.find_entities_filtered({ name = REACTORS })) do
      kinds[entity.name] = (kinds[entity.name] or 0) + 1
      total = total + 1
      -- Box 1 is the plasma inlet, which is what a reactor burns. An empty one is reported as
      -- such rather than skipped: a factory whose reactors are all idle is a real finding about
      -- the number this run is about to print, not a rounding error.
      --
      -- The length check is not paranoia about an empty box -- fluidbox[1] on an entity with NO
      -- fluidbox raises "Index out of range" and would kill the census run outright. Latent while
      -- both reactors have one, and the point of reading REACTORS out of the shipped module is
      -- that a third reactor arrives here without anyone editing this script.
      local box = (#entity.fluidbox > 0) and entity.fluidbox[1] or nil
      local fluid = (box and box.name) or "(empty)"
      burning[fluid] = (burning[fluid] or 0) + 1

      if planting then
        -- Recorded, not counted: this walk's counts never reach the log, because the line is
        -- written on the VERDICT walk where the table is fresh. How many were planted is read
        -- back out of erased + stale instead.
        before[entity.unit_number] = plant(entity)
      else
        local v = verdict(entity)
        counts[v] = (counts[v] or 0) + 1
      end
    end
  end

  local byKind = {}
  for _, name in ipairs(REACTORS) do byKind[#byKind + 1] = string.format("%s:%d", name, kinds[name]) end

  -- Sorted, so two runs over the same save produce the same line and a diff between them means
  -- something.
  local fluids = {}
  for fluid in pairs(burning) do fluids[#fluids + 1] = fluid end
  table.sort(fluids)
  local byFluid = {}
  for _, fluid in ipairs(fluids) do byFluid[#byFluid + 1] = string.format("%s:%d", fluid, burning[fluid]) end

  -- simulated= is erased + grew, because those are the two ways publish() can have proved itself
  -- and the caller's gate is about the total. The parts stay on the line so a failure can be read
  -- rather than guessed at, and publish_every= is there so a reader can tell a gate that passed
  -- from one that was never given long enough to run. See the caller.
  log(string.format(
    "BENCH-SURVEY tick=%d surfaces=%d reactors=%d kinds=%s burning=%s simulated=%d erased=%d grew=%d stale=%d nocomb=%d unseen=%d publish_every=%d",
    seen, surfaces, total,
    table.concat(byKind, ","), (#byFluid > 0) and table.concat(byFluid, ",") or "none",
    counts.erased + counts.grew, counts.erased, counts.grew, counts.stale, counts.nocomb,
    counts.unseen, PUBLISH_EVERY))
end)
'@
    $lua = $lua.Replace('__REACTORS__', (($names | ForEach-Object { '"' + $_ + '"' }) -join ', '))
    $lua = $lua.Replace('__TICKS__', "$Ticks")
    $lua = $lua.Replace('__PUBLISH_EVERY__', "$publishEvery")
    Set-Content -Path (Join-Path $surveyDir 'control.lua') -Value $lua -Encoding utf8
}

# ------------------------------------------------------------------ -Save: a map we did not build
#
# Its own block rather than a branch inside the sweep below, because the two share the measurement
# and share nothing else: there is no map to create, no rig whose construction can be gated, no
# baseline to subtract and so no per-reactor table. What it does share is the obligation behind the
# rig's gates -- refuse a figure the run cannot support -- and it meets that with its own
# instruments, the mod-set refusal and the simulation gate below. The sweep is left exactly as it
# was (acceptance criterion four of #64) and the statistics both paths report come from the same
# New-TimingRow and Write-StatTables.
if ($Save) {
    if (-not (Test-Path -LiteralPath $Save)) { throw "-Save not found: $Save" }
    $Save = (Resolve-Path -LiteralPath $Save).Path

    # -SaveModDirectory is defaulted, checked and resolved with the mode guards above, which both
    # save-reading modes share.

    # Inside the try, not before it: the temp directory exists by this point, and reading the
    # save's header or refusing an unresolved mod is exactly where this path fails. Left outside,
    # the refusal this was written for -- which is the one users will actually hit -- would leak
    # the directory every time.
    try {
        $wanted   = Get-SaveModList -Path $Save
        $resolved = Resolve-SaveMods -Wanted $wanted -SourceDirectory $SaveModDirectory `
            -Bundled $bundled -Ours $ourMods

        Write-Host "save     : $Save"
        Write-Host ("mod set  : {0} from the save's own header -- {1}" -f $wanted.Count,
            (($wanted | ForEach-Object { "$($_.Name) $($_.Version)" }) -join ', '))
        Write-Host ("resolved : {0} bundled, {1} from $SaveModDirectory, {2} junctioned from this working tree" -f
            $resolved.Bundled.Count, $resolved.Foreign.Count, $ourMods.Count)
        if ($resolved.Ours.Count -eq 0) {
            Write-Warning ("the save was not written with any of this repo's mods, so its reactors " +
                           'were built by something else or there are none. The census below says which.')
        }
        Write-Host "$Ticks ticks x $Runs run(s)"

        # The save's own mods, in whichever form the mod directory holds them. Zips are COPIED
        # rather than linked -- only the ones the save names, so the cost is that save's mod set
        # and not the whole directory -- and unpacked directories are junctioned the way the
        # repo's own are.
        $toJunction = @()
        foreach ($mod in $resolved.Foreign) {
            if ($mod.IsZip) { Copy-Item -LiteralPath $mod.Source -Destination $modDir }
            else { $toJunction += (Split-Path $mod.Source -Leaf) }
        }
        if ($toJunction.Count -gt 0) {
            New-ModJunctions -ModDirectory $modDir -RepoRoot $SaveModDirectory -Mods $toJunction
        }
        # Startup settings change prototypes, and a benchmark of a map with different prototypes is
        # a benchmark of a different map.
        $modSettings = Join-Path $SaveModDirectory 'mod-settings.dat'
        if (Test-Path -LiteralPath $modSettings) { Copy-Item -LiteralPath $modSettings -Destination $modDir }

        # Ours last and from the repository, so the working tree wins over any installed copy of
        # the same name -- measuring a released zip while editing the repo is the one outcome
        # nobody wants.
        New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
        Write-Survey

        $foreignNames = @($resolved.Foreign | ForEach-Object { $_.Name })

        # ---- the census, with the survey mod enabled
        #
        # One run of the measured length, so the reading the report quotes describes the end of a
        # window as long as one measured run rather than the instant the save was loaded. See
        # Write-Survey for why that distinction is not academic. It costs one extra load of the
        # save and two walks of it, not one walk per tick.
        Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $resolved.Bundled `
            -Mods ($foreignNames + $ourMods + $surveyName)
        $surveyOut = Invoke-FactorioStep @step -Tag 'survey' -Arguments @(
            '--benchmark', $Save, '--benchmark-ticks', "$Ticks", '--benchmark-runs', '1', '--disable-audio')
        $census = Get-Content $surveyOut | Select-String -Pattern 'BENCH-SURVEY' | Select-Object -Last 1
        if (-not $census) {
            throw ("the census never reported over '$Save', so nothing is known about what is in " +
                   "it. $surveyName was enabled and should have logged on its first tick.")
        }
        $census = "$census" -replace '^.*BENCH-SURVEY ', ''
        $reactorCount = if ($census -match 'reactors=(\d+)') { [int]$Matches[1] } else { -1 }
        if ($reactorCount -lt 0) { throw "could not read a reactor count from the census: '$census'" }

        # WHICH of the survey's two reports this is, gated rather than assumed. It logs on its
        # first tick and on tick $Ticks, and the tick-1 line is the reading Write-Survey's own note
        # calls true of the instant and wrong about the run -- a save whose reactors are hot for
        # the whole benchmark reads "(empty)" there. Taking the last line is only the end-of-window
        # reading if the run reached the end of the window, and nothing above proves it did.
        #
        # The reactor count survives either way, since no reactor is built or destroyed in a
        # benchmark. The fuel breakdown does not, and a census run that stopped short means the
        # measurement run has no reason to be trusted either -- so this refuses rather than
        # caveats. Only above -Ticks 1, where the two reports coincide by construction.
        if ($Ticks -gt 1 -and $census -notmatch "tick=$Ticks\b") {
            throw ("the census ran short: its last report is '$census', not tick=$Ticks. The " +
                   'first-tick reading describes the instant the save was loaded rather than the ' +
                   'window that gets measured, so what the reactors are burning cannot be read ' +
                   'off it.')
        }

        Write-Host "census   : $census"

        # THE GATE THAT PROVES SOMETHING IS SIMULATING THEM, which is not what counting them
        # proves. The survey plants a sentinel signal in each reactor's companion combinator on its
        # first tick and looks for it again at the end; circuit.publish() assigns that filter list
        # wholesale, so a sentinel that survived means nothing stepped that reactor. See the survey
        # for the whole argument, and for why it is safe to write to the map in this run only.
        #
        # A GUARD THAT CANNOT RUN HAS NOT PASSED, so the window is checked before the verdict is.
        # publish() runs every $publishEvery ticks, and a save resumes with control.lua's own
        # counter part way through its cycle -- so the first publish can be a whole cycle away and
        # the window has to hold two. Below that the gate says it did not run, rather than passing.
        if ($reactorCount -gt 0) {
            $simulated = if ($census -match 'simulated=(\d+)') { [int]$Matches[1] } else { -1 }
            $erased    = if ($census -match 'erased=(\d+)')    { [int]$Matches[1] } else { -1 }
            $grew      = if ($census -match 'grew=(\d+)')      { [int]$Matches[1] } else { -1 }
            $stale     = if ($census -match 'stale=(\d+)')     { [int]$Matches[1] } else { -1 }
            $nocomb    = if ($census -match 'nocomb=(\d+)')    { [int]$Matches[1] } else { -1 }
            $unseen    = if ($census -match 'unseen=(\d+)')    { [int]$Matches[1] } else { -1 }
            if ($simulated -lt 0) {
                throw ("the census reported no simulation verdict, so nothing establishes that " +
                       "these reactors are being stepped: '$census'")
            }

            # Three publish cycles: two before the sentinels go in, so every registered reactor has
            # a combinator to plant one in, and at least one more after, so publish() has a chance
            # to erase it. A save resumes with control.lua's own report counter part way through its
            # cycle, which is why the first wait is two and not one.
            if ($Ticks -lt 3 * $publishEvery) {
                # Parenthesised as one string before -f. This is the third time in this change that
                # -f binding tighter than + printed a literal {0} instead of a number, and every
                # one of them was caught by reading the output rather than by any gate.
                Write-Warning ((("this run is {0} ticks and the mod publishes every {1}, so the " +
                    "simulation gate DID NOT RUN. Nothing below establishes that the {2} reactor(s) " +
                    "are being stepped rather than merely present -- use -Ticks {3} or more if that " +
                    'matters.') -f $Ticks, $publishEvery, $reactorCount, (3 * $publishEvery)))
            }
            elseif ($simulated -ne $reactorCount) {
                throw ((("the save holds {0} reactor(s) and only {1} of them is being simulated. " +
                    "{2} still carried the sentinel this run planted, {3} had no companion " +
                    "combinator either before or after, and {4} were not seen on the first tick. " +
                    "realistic-fusion-refreshed has those reactors on the map and not in its register, so every " +
                    "figure would be the cost of entities nothing is stepping. Census: '{5}'") -f
                    $reactorCount, $simulated, $stale, $nocomb, $unseen, $census))
            }
            else {
                Write-Host ((("           simulated: {0}/{1} -- {2} had a planted sentinel erased, " +
                    '{3} grew a combinator during the run. Both are publishes.') -f
                    $simulated, $reactorCount, $erased, $grew))
            }
        }

        if ($reactorCount -eq 0) {
            # Not a refusal. The absolute cost of a map with no reactors in it is a real answer to
            # a real question -- it is just not an answer about reactors, and saying so is the
            # difference between a measurement and a misunderstanding.
            Write-Warning ("this save holds no reactors, so the figures below are the cost of the " +
                           'map with no reactor being simulated in it. control.lua still steps -- ' +
                           'over an empty register.')
        }

        # ---- the measurement, with the survey mod explicitly disabled
        #
        # Named disabled rather than left out: Factorio AUTO-ENABLES a mod present in the mod
        # directory but absent from mod-list.json, so omitting it would load it (see Write-ModList),
        # and the census walk would land on every tick of the run being reported.
        Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $resolved.Bundled `
            -Mods ($foreignNames + $ourMods) -Disabled @($surveyName)

        # Read before the launch, while the machine is free of us. See Get-ForeignLoad.
        $load = Get-ForeignLoad
        $cpu  = Get-ClockPercent
        $benchOut = Invoke-FactorioStep @step -Tag 'bench-save' -Arguments @(
            '--benchmark', $Save, '--benchmark-ticks', "$Ticks", '--benchmark-runs', "$Runs",
            '--benchmark-verbose', 'all', '--disable-audio')

        $cols     = Get-Timings -Path $benchOut
        $expected = $Ticks * $Runs
        if ($cols['scriptUpdate'].Count -ne $expected) {
            Write-Warning ("{0} tick samples, expected {1}. The mean is over what was parsed." -f
                $cols['scriptUpdate'].Count, $expected)
        }

        $row = New-TimingRow -Columns $cols -Reactors $reactorCount -State $census -Cpu $cpu -Load $load
        Write-Host ''
        Write-Host ("scriptUpdate median {0,8:N2} us  mean {1,8:N2} us   whole median {2,8:N2} us" -f
            $row.'scriptUpdate.median', $row.'scriptUpdate.mean', $row.'wholeUpdate.median')
        if ($row.WholeByRun.Count -gt 1) {
            Write-Host ("        by run: whole median [{0}] us   script mean [{1}] us" -f
                (($row.WholeByRun  | ForEach-Object { '{0:N1}' -f ($_ / 1000.0) }) -join ' '),
                (($row.ScriptByRun | ForEach-Object { '{0:N1}' -f ($_ / 1000.0) }) -join ' '))
        }
        Write-MachineNote -Label 'save' -Cpu $cpu -Load $load -Why (
            'Nothing here is a difference against a baseline, so there is no subtraction that ' +
            'could have cancelled it out -- it is simply added to every figure below.')

        Write-StatTables -Results @($row)

        # ---- what the run cannot say, said rather than left to be inferred
        Write-Host ''
        Write-Host 'no per-reactor cost is reported, and none can be from a save:'
        Write-Host '  Every per-reactor figure this script produces is (cost at n minus cost at n = 0) / n,'
        Write-Host '  and a factory cannot be un-built. The rig path exists for that number; -Counts 0,...'
        Write-Host '  builds the same map with and without reactors and subtracts. This measures the map.'

        # And whose Lua scriptUpdate actually is. base ships no control.lua, but the scenario the
        # save was started from does and it runs as __level__, so even the narrow case is not this
        # repo alone -- claiming otherwise would be the same overreach as reporting a per-reactor
        # figure without a baseline.
        $others = $resolved.Bundled.Count + $resolved.Foreign.Count
        Write-Host ''
        if ($others -eq 0) {
            Write-Host ("  scriptUpdate is this repo's Lua and the save's scenario script; the save " +
                        'enables no other mod.')
        } else {
            # Parenthesised as one string before -f, for the reason the missing-baseline guard in
            # the sweep spells out: -f binds tighter than +, so without them the format applies to
            # the last fragment only -- which has no placeholder -- and a literal {0} is printed.
            # It happened here first, and was caught by reading the output rather than by any gate.
            # Every mod THIS RUN enables ON TOP OF base, which is neither the count in the save's
            # header nor the count of enabled mods. This repo's three are added whether the save
            # had them or not, so the header's count would be short; and base is enabled too but
            # is not in this figure, because base ships no control.lua and contributes no Lua of
            # its own -- what it contributes is the scenario script, which the sentence names
            # separately. Saying "enables" without the qualifier made the number one too low for
            # its own claim.
            Write-Host ((("  scriptUpdate is the Lua of the {0} mods this run enables on top of " +
                        "base, plus the save's scenario script, and not this repo's alone. Nothing " +
                        "here can separate them -- Factorio's per-mod time usage is a debug view " +
                        'in the client, not a --benchmark column.') -f ($others + $ourMods.Count)))
        }
        if ($row.'wholeUpdate.mean' -gt 0) {
            Write-Host ((("  Lua is {0:N1}% of the average tick here, and the whole tick is {1:N2}% " +
                        'of a 16.67 ms budget.') -f
                        (100.0 * $row.'scriptUpdate.mean' / $row.'wholeUpdate.mean'),
                        (100.0 * $row.'wholeUpdate.mean' / 16670.0)))
        }

        Write-Output $row
    }
    finally { Complete-Run }

    return
}

try {
    # ---- the borrowed base's own mod set (#65)
    #
    # The same argument -Save makes, for the same reason, and it applies here even though this mode
    # builds the thing being measured: Factorio loads a save whose mods are absent, runs it, and
    # exits 0 without a warning of any kind. A planted run over a map with every mod's entities
    # stripped out of it would look exactly like a good one -- and worse than under -Save, because
    # the subtraction would still produce a confident per-reactor figure from a factory that was not
    # there. Resolved out of the save's own header; anything unresolved is named and refused.
    $plantBundled = @()
    $plantForeign = @()
    if ($PlantInto) {
        $wanted   = Get-SaveModList -Path $PlantInto
        $resolved = Resolve-SaveMods -Wanted $wanted -SourceDirectory $SaveModDirectory `
            -Bundled $bundled -Ours $ourMods
        $plantBundled = $resolved.Bundled
        $plantForeign = @($resolved.Foreign | ForEach-Object { $_.Name })

        Write-Host "borrowed : $PlantInto"
        Write-Host ("mod set  : {0} from the save's own header -- {1}" -f $wanted.Count,
            (($wanted | ForEach-Object { "$($_.Name) $($_.Version)" }) -join ', '))
        Write-Host ("resolved : {0} bundled, {1} from $SaveModDirectory, {2} junctioned from this working tree" -f
            $resolved.Bundled.Count, $resolved.Foreign.Count, $ourMods.Count)

        # Copied for zips and junctioned for unpacked directories, exactly as -Save does it, and
        # only the mods the save names -- so a mod directory holding several overhauls contributes
        # whichever this save asked for and none of the rest.
        $toJunction = @()
        foreach ($mod in $resolved.Foreign) {
            if ($mod.IsZip) { Copy-Item -LiteralPath $mod.Source -Destination $modDir }
            else { $toJunction += (Split-Path $mod.Source -Leaf) }
        }
        if ($toJunction.Count -gt 0) {
            New-ModJunctions -ModDirectory $modDir -RepoRoot $SaveModDirectory -Mods $toJunction
        }
        # Startup settings change prototypes, and a benchmark of a map with different prototypes is
        # a benchmark of a different map. Identical at every count, so it cancels out of the
        # subtraction either way -- but it decides which map the whole sweep describes.
        $modSettings = Join-Path $SaveModDirectory 'mod-settings.dat'
        if (Test-Path -LiteralPath $modSettings) { Copy-Item -LiteralPath $modSettings -Destination $modDir }
    }

    # Ours last and from the repository, so the working tree wins over any installed copy of the
    # same name -- measuring a released zip while editing the repo is the one outcome nobody wants.
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $plantBundled `
        -Mods ($plantForeign + $ourMods + $rigName)

    if ($PlantInto) {
        Write-Host ("planting : surface '$plantSurface', $grid x $grid cells, $Ticks ticks x $Runs run(s) per count, " +
                    "pooled: $([bool]$Pooled), collectors: $([bool]$Collectors), blankets: $([bool]$Blankets)")
    } else {
        Write-Host "grid $grid x $grid cells, $Ticks ticks x $Runs run(s) per count, pooled: $([bool]$Pooled), collectors: $([bool]$Collectors), blankets: $([bool]$Blankets), ablate: $Ablate (interval $interval)"
    }
    Write-Host ''

    $results = @()
    foreach ($count in $Counts) {
        Write-Rig -Count $count
        # $rigSave, not $save: PowerShell variable names are case-insensitive, so $save IS the
        # -Save parameter and this loop was silently overwriting it with a rig map path. Harmless
        # only because the loop cannot run when -Save was given, which is not a property to leave
        # a live assignment leaning on.
        $rigSave = Join-Path $temp "n$count.zip"

        # TWO INVOCATIONS FOR A RIG, ONE FOR A BORROWED BASE. A rig is created and then loaded, so
        # placed= comes out of the --create; planting happens as the mod is added to the save being
        # benchmarked, so the run that measures is also the run that builds and placed= is read out
        # of it below. The gate is the same gate either way, and it is not optional: a short build
        # makes every figure a claim about a count that was never on the map.
        # Pattern on 'grid=' rather than on 'BENCH-RIG' alone, because a planted run's output also
        # carries the report ticks and -Last 1 would take one of those instead.
        if (-not $PlantInto) {
            $createOut = Invoke-FactorioStep @step -Arguments @('--create', $rigSave) -Tag "create-n$count"
            $rig = Get-Content $createOut | Select-String -Pattern 'BENCH-RIG grid=' | Select-Object -Last 1
            if ($rig -notmatch "placed=$count\b") { throw "rig built the wrong number of reactors: $rig" }
        }

        # Read before the launch, while the machine is free of us. See Get-ForeignLoad.
        $load = Get-ForeignLoad
        $cpu  = Get-ClockPercent
        $benchOut = Invoke-FactorioStep @step -Tag "bench-n$count" -Arguments @(
            '--benchmark', ($PlantInto ? $PlantInto : $rigSave), '--benchmark-ticks', "$Ticks",
            '--benchmark-runs', "$Runs", '--benchmark-verbose', 'all', '--disable-audio')

        if ($PlantInto) {
            $rig = Get-Content $benchOut | Select-String -Pattern 'BENCH-RIG grid=' | Select-Object -Last 1
            if (-not $rig) {
                # ${count}, not $count: a colon straight after a variable name is a SCOPE
                # qualifier, so "$count:" parses as a variable called nothing in a scope called
                # "count" and the whole file stops parsing. The elseif branch below sidesteps the
                # same trap with a backtick, which is the form the rest of this script uses.
                throw ("nothing was planted into '$PlantInto' at n=${count}: $rigName never logged its " +
                       'build line, so on_init did not run and the figures would be the borrowed ' +
                       "base's own cost with our name on them.")
            }
            if ($rig -notmatch "placed=$count\b") {
                throw "planting built the wrong number of reactors at n=$count`: $rig"
            }
        }

        # The rig's last word on what it was actually doing, and a hard gate rather than a note in
        # the output. Everything above this line would happily produce a confident per-reactor
        # figure from reactors that had run dry, never got power, or were never registered with
        # the mod at all -- none of which crashes anything. placed= only covers map creation, and
        # a benchmark loads the save rather than rebuilding it.
        $state = Get-Content $benchOut | Select-String -Pattern 'BENCH-RIG tick=' | Select-Object -Last 1
        if ("$state" -notmatch "reactors=$count\b" -or "$state" -notmatch "hot=$count\b") {
            throw "rig at n=$count was not $count hot reactors when it last reported: '$state'"
        }
        # Powered as well as present and hot. The rig errors at map creation if a reactor lands
        # outside its substation's reach, so this is the same fact checked on the far side of a
        # save-and-reload -- cheap, and the one property that would otherwise be taken on trust
        # for the whole benchmark.
        if ("$state" -notmatch "powered=$count\b") {
            throw "rig at n=$count had reactors on no electric network when it last reported: '$state'"
        }

        # And the only one of the three that proves the simulation ran. The two above cannot:
        # reactors= counts the rig's own table, which it fills itself whether or not
        # realistic-fusion-refreshed ever registered the entity, and hot= reads a temperature the infinity
        # pipe pins at 6e8 regardless. So if registration silently stopped working -- an event
        # dropped from the list, a filter the game stops accepting -- every reactor would still be
        # present and hot, and this script would report a near-zero cost as a measurement instead
        # of as a bug. rf-reactor-energy exists only because control.lua's apply() put it there.
        # Skipped below the `write` rung, which is the only ablation that writes anything to the
        # world at all -- the steps=/touched= gate below is what proves those ran.
        if ($count -gt 0 -and ($Ablate -eq 'none' -or $Ablate -eq 'write')) {
            $produced = if ("$state" -match 'output=([0-9.eE+-]+)') { [double]$Matches[1] } else { 0 }
            if ($produced -le 0) {
                throw ("rig at n=$count produced no reactor energy, so the simulation did not run " +
                       "even though the reactors are present and hot: '$state'")
            }
        }

        # The ablated rungs' equivalent, and the one gate that cannot be skipped for them. A rung
        # below `write` leaves no mark on the world, so a handler that never registered -- a
        # require that resolved to nothing, an interval of zero -- would return a per-reactor cost
        # of nothing, which reads exactly like the finding this is trying to establish.
        if ($Ablate -ne 'none') {
            $steps   = if ("$state" -match 'steps=(\d+)')   { [int]$Matches[1] } else { -1 }
            $touched = if ("$state" -match 'touched=(\d+)') { [int]$Matches[1] } else { -1 }
            if ($steps -le 0) {
                throw "rig at n=$count ran the -Ablate $Ablate step $steps times, so nothing was measured: '$state'"
            }
            if ($count -gt 0 -and $touched -ne $steps * $count) {
                throw ("rig at n=$count touched $touched reactors over $steps steps of -Ablate $Ablate, " +
                       "expected $($steps * $count): '$state'")
            }
        }

        # The fittings, and the same distinction the output= gate above draws: placed is not
        # attached (#62). entity-management pairs a collector to a reactor by the tiles touching it,
        # so one placed half a tile out of reach still exists, still counts, and is never written
        # to -- which would leave this script reporting the cost of a vented reactor while claiming
        # it measured a collected one. deposit() is the only thing that writes those boxes.
        if ($Collectors -and $count -gt 0) {
            $attached = if ("$state" -match 'collectors=(\d+)') { [int]$Matches[1] } else { -1 }
            if ($attached -ne $count) {
                throw "rig at n=$count had $attached collectors, not $count`: '$state'"
            }
            $collected = if ("$state" -match 'collected=([0-9.eE+-]+)') { [double]$Matches[1] } else { 0 }
            if ($collected -le 0) {
                throw ("rig at n=$count collected nothing, so no reactor found the collector bolted " +
                       "to it and deposit() never ran: '$state'")
            }
            # Not a gate: a saturated tritium box is a legitimate state to measure, and it is also
            # the state in which a blanket stops (control.lua treats a full collector as a missing
            # one). Say so rather than refuse. full_pct is the WORST tritium box, so the threshold
            # means what it reads as -- see the rig for why a pooled figure could never reach it.
            $full = if ("$state" -match 'full_pct=([0-9.eE+-]+)') { [double]$Matches[1] } else { 0 }
            if ($full -ge 95) {
                # The blanket clause only when there are blankets: on a -Collectors run it would be
                # a claim about a switch that is off.
                # Parenthesised as one string before -f, for the reason the n = 0 guard below
                # spells out: -f binds tighter than +.
                $starved = if ($Blankets) {
                    ' The blanket path was starved of headroom for part of the run.'
                } else { '' }
                Write-Warning ((("n={0}: the fullest tritium box was {1:N0}% full when the rig " +
                    "last reported, so its by-product writes were being clamped.{2}") -f
                    $count, $full, $starved))
            }
        }
        if ($Blankets -and $count -gt 0) {
            $fitted = if ("$state" -match 'blankets=(\d+)') { [int]$Matches[1] } else { -1 }
            if ($fitted -ne $count) {
                throw "rig at n=$count had $fitted blankets, not $count`: '$state'"
            }
            # PER BLANKET, not the total. Nothing but blanket_breed() takes items out of these
            # containers, so a blanket whose stock has fallen is one that ran -- but a sum is
            # satisfied by a single one running, and the run this gate exists to catch is the one
            # where most of them sat idle. It cannot be read off the collector either: blanket
            # tritium and D-D by-product tritium arrive in the same box.
            $bred = if ("$state" -match 'bred=(\d+)') { [int]$Matches[1] } else { -1 }
            # EXACT, and the expectation comes from the rig rather than from this script. expect=
            # is how many blankets sit on a reactor whose fuel releases neutrons, predicted at map
            # creation from reactor-logic's own fuel table -- so an aneutronic row is correctly
            # excluded and every neutronic one is required.
            #
            # This used to read "at least 1" on a mixed run, on the reasoning that only some rows
            # breed. That is true and it made the gate useless: at n = 200 about 110 blankets ought
            # to breed, so a regression that idled 109 of them passed as a valid measurement.
            # Knowing WHICH rows breed is the whole difference, and the rig can compute it.
            $expect = if ("$state" -match 'expect=(\d+)') { [int]$Matches[1] } else { -1 }
            if ($expect -le 0) {
                throw ("rig at n=$count expected no blanket to breed, so -Blankets measured " +
                       "nothing: '$state'")
            }
            if ($bred -ne $expect) {
                throw ("rig at n=$count had $bred of $count blankets breed, expected exactly " +
                       "$expect (the reactors on a neutron-releasing fuel), so blankets were idle " +
                       "and the figure is not a blanketed reactor's cost: '$state'")
            }
            $lithiumMin = if ("$state" -match 'lithium_min=(-?\d+)') { [int]$Matches[1] } else { -1 }
            if ($lithiumMin -le 0) {
                throw ("rig at n=$count ran a blanket dry ($lithiumMin lithium left in the " +
                       "emptiest one that bred), so part of the run measured an empty container: '$state'")
            }
        }

        # And, when the whole point of the run is that four reactions are present, that four
        # reactions were present. Everything above counts reactors; none of it can tell D-D from
        # D-T, because they are the same entity burning a different fluid. Without this the headline
        # claim of #34 would rest on the rig having intended the mix rather than on it having
        # happened -- and a row assignment that silently degenerated to one case would still report
        # the right reactor count, hot, powered and producing.
        # Four occupied ROWS, not four reactors: the fourth case first appears in row 3, which is
        # empty until the count passes 3 * grid. `-ge 4` was wrong and would have thrown on the
        # default sweep at n = 10 -- where every reactor is legitimately in row 0 and burning D-D,
        # which .PARAMETER Mixed documents and the research note uses as its cross-check.
        if ($Mixed -and $count -gt 3 * $grid) {
            $burning = if ("$state" -match 'burning=(\S+)') { $Matches[1] } else { '' }
            $distinct = @($burning -split ',' | Where-Object { $_ } | ForEach-Object { ($_ -split ':')[0] } | Sort-Object -Unique)
            if ($distinct.Count -ne 4) {
                throw ("rig at n=$count was -Mixed but burned $($distinct.Count) plasma(s), not 4: " +
                       "'$burning'. The four-reaction measurement cannot be taken from this run.")
            }
        }

        $cols = Get-Timings -Path $benchOut
        $expected = $Ticks * $Runs
        if ($cols['scriptUpdate'].Count -ne $expected) {
            Write-Warning ("n={0}: {1} tick samples, expected {2}. The mean is over what was parsed." -f
                $count, $cols['scriptUpdate'].Count, $expected)
        }

        $row = New-TimingRow -Columns $cols -Reactors $count -State "$state" -Cpu $cpu -Load $load
        $results += $row

        Write-Host ("n={0,-5} scriptUpdate median {1,8:N2} us  mean {2,8:N2} us   whole median {3,8:N2} us   {4}" -f
            # Dot-and-quote, not [], because New-TimingRow hands back a pscustomobject: the [] form
            # worked while the row was still an ordered hashtable here and silently yields nothing
            # on an object, which printed this line with the numbers blank and no error at all.
            $count, $row.'scriptUpdate.median', $row.'scriptUpdate.mean', $row.'wholeUpdate.median',
            ("$state" -replace '^.*BENCH-RIG ', ''))
        # Each benchmark run on its own, and the effective clock beside them, so a count that came
        # out slow can be attributed to the machine or cleared of it on the spot. See Split-Runs.
        if ($row.WholeByRun.Count -gt 1) {
            Write-Host ("        by run: whole median [{0}] us   script mean [{1}] us" -f
                (($row.WholeByRun  | ForEach-Object { '{0:N1}' -f ($_ / 1000.0) }) -join ' '),
                (($row.ScriptByRun | ForEach-Object { '{0:N1}' -f ($_ / 1000.0) }) -join ' '))
        }
        Write-MachineNote -Label "n=$count" -Cpu $cpu -Load $load -Why (
            'Every figure from it is a difference against an n = 0 baseline measured at a ' +
            'different moment, so other work does not cancel out of it.')
    }

    # ------------------------------------------------------------------ report
    #
    # Why both statistics are printed lives in Write-StatTables, which -Save shares.

    $base = $results | Where-Object { $_.Reactors -eq 0 } | Select-Object -First 1

    # Loud, because the whole method is a subtraction. Without n = 0 there is nothing to subtract
    # against, and this used to print the per-count tables and simply omit every per-reactor figure
    # -- a run that looks like it worked and answers a different question than the one asked.
    #
    # It is not a hypothetical. `-Counts 0,1,10` under `pwsh -File` does not arrive as three
    # numbers: -File passes each argument as a string and the [int[]] conversion is culture-aware,
    # so on a machine whose decimal separator is a comma "0,1,10" converts to the single value 110.
    # The baseline vanishes and nothing says so. See .EXAMPLE for the form that binds.
    #
    # RAISED AFTER the tables below rather than before them, and that ordering is the whole point of
    # this note. Throwing first cost the caller everything: a sweep can run for tens of minutes, and
    # a bare throw took the per-count tables, the pipeline rows and -- through the finally block --
    # the captured Factorio logs with it, for a fault that costs one flag to fix. The absolute
    # figures are worth having even when no per-reactor figure can be computed from them.
    $missingBaseline = -not $base

    Write-StatTables -Results $results

    if ($base) {
        # Both statistics again, so a per-reactor figure quoted anywhere can say which it came
        # from. The mean is the cost; the median is the only usable one where the signal is a
        # fraction of a microsecond and the mean is all spike.
        foreach ($stat in @('median', 'mean')) {
            Write-Host ''
            Write-Host "cost per reactor, microseconds -- ($stat at n minus $stat at 0) / n"
            Write-Host ('{0,-9}' -f 'reactors') -NoNewline
            foreach ($c in $REPORT) { Write-Host ('{0,22}' -f $c) -NoNewline }
            Write-Host ''
            foreach ($r in $results | Where-Object { $_.Reactors -gt 0 }) {
                Write-Host ('{0,-9}' -f $r.Reactors) -NoNewline
                foreach ($c in $REPORT) {
                    Write-Host ('{0,22:N4}' -f (($r."$c.$stat" - $base."$c.$stat") / $r.Reactors)) -NoNewline
                }
                Write-Host ''
            }
        }

        # The headline. A tick is 16.67 ms, so this is the share of one tick's budget the
        # simulation spends at the largest count measured.
        $top = $results | Sort-Object Reactors | Select-Object -Last 1
        if ($top.Reactors -gt 0) {
            $cost = $top.'scriptUpdate.mean' - $base.'scriptUpdate.mean'
            Write-Host ''
            Write-Host ("{0} reactors: {1:N2} us of Lua per tick on average, {2:N4} us per reactor, {3:N2}% of a 16.67 ms tick." -f
                $top.Reactors, $cost, ($cost / $top.Reactors), (100.0 * $cost / 16670.0))
        }
    }

    # ---- what a borrowed base's figures do and do not say, said rather than left to be inferred
    #
    # The mirror of the block -Save prints. There, the absolute cost is the answer and no
    # per-reactor figure exists; here the per-reactor figure is the answer and the absolute cost is
    # somebody else's factory. Printing one without the other is how a number gets quoted for the
    # wrong claim.
    if ($PlantInto) {
        Write-Host ''
        Write-Host 'this sweep ran on a borrowed base, so read the two kinds of figure differently:'
        Write-Host '  The PER-REACTOR figures are attributable. Every count loads the same save with the same'
        Write-Host '  mods and generates the same planted surface with the same power; only the reactors differ,'
        Write-Host "  so everything else -- the factory's own engine and Lua cost included -- cancels."
        Write-Host '  The ABSOLUTE figures are not ours. wholeUpdate and scriptUpdate here are mostly the'
        Write-Host '  borrowed base doing what it does, which is the point of measuring on one and is not a'
        Write-Host '  cost this mod causes.'
        $others = $plantBundled.Count + $plantForeign.Count
        if ($others -gt 0) {
            Write-Host ("  The save enables {0} mod(s) on top of base besides ours; none of it is separable" -f $others)
            Write-Host '  from scriptUpdate, and none of it needs to be, because it is identical at every count.'
        }
        Write-Host '  Nothing was written. --benchmark never saves, so the planted surface died with each run.'
    }

    # The tables above are Write-Host, which "> file" does not capture. The rows go to the
    # pipeline as well so a caller can sort, export or diff them; writing a CSV into $temp would
    # have been worse than useless, since the finally block deletes it.
    Write-Output $results

    # And only now the fault, with everything the run did manage to measure already in hand.
    if ($missingBaseline) {
        # Parenthesised as one string before -f: -f binds tighter than +, so without them the
        # format applies to the last fragment only, which has no placeholder -- and the message
        # prints a literal {0} where the counts should be. locale-check.ps1 carries the same note.
        throw (("no n = 0 baseline among the counts measured ({0}), so no per-reactor cost could be " +
                "computed -- every such figure is a difference against it. The absolute tables above " +
                "are still good. If you passed -Counts through 'pwsh -File', check it arrived as " +
                "separate numbers: use pwsh -Command followed by a quoted " +
                "'& ./scripts/bench-reactors.ps1 -Counts 0,1,10' instead.") -f
               (($results | ForEach-Object { $_.Reactors }) -join ', '))
    }

}
finally { Complete-Run }

<#
.SYNOPSIS
    Runs one fuel-line rig twice: once on the reactor as shipped, with an "input-output" plasma box,
    and once under a canary that makes that box "input". rf-reactor unless -Plasma says otherwise. Reports the fill, the settled box, whether
    control.lua still writes the box, whether two bridged reactors still share one pool (#542), and
    where a lone box with no pipes relaxes to (#548).

    SINCE #740 THE SHIPPED BOX IS "input" (ADR 0040), so the canary refuses to load, which it
    reports, and a run with -NoCanary reads the shipped input box. The runtime production_type the
    report prints says which box a run read; "shipped" in its labels means input-output only for
    runs before #740.

.DESCRIPTION
    A PROBE, NOT A CHECK. Every line it prints is a measurement, and exit 0 means the probe ran and
    every row reported, never that the answer was the one anybody hoped for. A canary that refuses
    to load, or loads and then fails its run, is a reading too, and is reported rather than thrown;
    the shipped variant doing either is a broken rig and throws. It must not be added to a check
    sweep or to load-check.ps1. docs/research/plasma-input-box.md is what its rows are read into.

    WHY THE CANARY IS THE REACTOR ITSELF AND NOT A COPY BESIDE IT. control.lua recognises a reactor
    by prototype NAME, twice: entity-management.lua's REACTORS decides what is registered, and
    control.lua's SPECS what it is simulated with, and check_reactor_specs() refuses to load if the
    two disagree. A copy under another name is never registered and never stepped -- it would be a
    pipe-shaped tank, which is not what the issue asks about. So the canary mod edits the box of
    the reactor -Plasma selects, rf-reactor by default, in its own data-final-fixes, and the two
    variants are two runs of the SAME rig, one with the canary enabled and one with it named
    disabled.

    WHAT IS BUILT, IN EACH RUN

      solo     One cell per entry of -Pipes: one rf-heater, that many rf-pipe, one reactor, the
               layout probe-plasma-segment.ps1 builds. -Heaters adds heaters and pipes west. The heater's feed is unbounded and reactor
               energy is drained as it arrives.
      pair     One rf-heater and -Pipes' first count of rf-pipe into a reactor, and -Bridge more
               rf-pipe from its east face into a second. ONLY THE FIRST IS ON AN ELECTRIC NETWORK
               (asserted), check-pooling.ps1's discriminator: an unpowered reactor steps with its
               heating clamped to zero, so any heat it holds came along the pipe.
      both     The pair again, with the second reactor powered too (asserted to be on an electric network).
      lone     No heater, no pipe, no power: an unregistered copy of the reactor, rf-input-box-lone,
               seeded to its box's capacity at 15 degC. Copied after the canary, so it carries this
               run's box. Unregistered because a stepped reactor is heated and burns its plasma;
               this is the instrument quality.md read the lone box's 526.3158 on.

      trio     With -Trio only, and built last so no other cell's segment id moves: the pair with
               a third reactor another -Bridge pipes east. Only the first is powered (asserted).

    NOTHING IS RESEARCHED unless -Rungs says otherwise, and either state is asserted rung by rung
    (rf_assert_research).

    WHAT IS READ

      every -Every ticks  each reactor's box and temperature, and what the segment beside it holds
                          -- the heater-side run through its first pipe, the bridge through its
                          first pipe -- and the segment id of every box and run, so "one segment"
                          is read off the engine rather than assumed. The ids are printed at build
                          and at the last sample.
      every tick          the box before control.lua's handler and after it, by the same pair of rig
                          mods probe-plasma-segment.ps1 uses. A difference on a step tick is the mod
                          writing the box; one on any other tick fails the run, because then the two
                          readings do not bracket the step. The first tick each box reaches -FullAt
                          of its capacity is kept, and the first tick from that one on which it
                          reads the floor's temperature (#571), or "never".
      with -Trace         every tick of the window, for the pair (or -TraceCell): each box's amount and temperature
                          before control.lua's handler and after it, and the segment's amount and
                          temperature through the bridge's first pipe (#558). What a box changed by
                          from one tick's second reading to the next tick's first is the engine
                          moving fluid; the rest is the mod's step. The report splits each box's
                          heat (amount x degC) between the two, and checks every engine move
                          against #531's rule. For an unpowered box with nothing researched it
                          also runs the mod's own M.step beside every step tick of the window,
                          with no heating, and says what each of the step's terms took and how
                          far the prediction is from the reading (#570); and, from that box's
                          temperature on the window's first tick, how many steps a box held full
                          and unheated takes to reach the floor.
      with -Fixed         every tick, for each solo cell, the pair and both: the fitted
                          fixed-point rule run from the game's reading of one tick to the next,
                          with the boxes and the heater bank taken in every order (#572), and a
                          bank of more than one heater taken in four ways (#587). A tick is a
                          miss when any predicted figure differs at all.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Ticks
    Ticks to run, from an empty line, per variant.

.PARAMETER Pipes
    Pipe counts, comma-separated, one solo cell each, 3 to 12. The pair uses the first.

.PARAMETER Bridge
    Pipes between the pair's two reactors. 11 is the fewest that keeps the second reactor outside
    the first one's substation.

.PARAMETER Every
    Ticks between sampled rows.

.PARAMETER FullAt
    The fraction of a box's capacity that counts as full.

.PARAMETER Settle
    The settle test (#576): rows are compared only with rows a whole number of lags away, the lag
    being the fewest ticks that are a whole multiple of both -Every and the heater's cycle, read
    off the recipe and the heater's crafting speed, so both rows are at the same point of that
    cycle. The box has settled from the first row after which every two such rows read within
    this fraction of each other, relative, and the report gives that tick. Every pair and not only
    neighbours: a drift under this fraction a lag passes a test of steps, and such a box has not
    stopped. A box whose last row and the row a lag before it are further apart than this is "NOT
    settled", with the two temperatures. Until #576 every row was compared with the run's last,
    which passed a box still drifting slower than this over the run's tail (#560).

.PARAMETER Plasma
    The plasma the heaters make, and so which reactor is read (#562): rf-d-d-plasma and
    rf-d-t-plasma go to rf-reactor and its 1000-unit box, rf-d-he3-plasma and rf-he3-he3-plasma to
    rf-aneutronic-reactor and its 3000. The canary and the lone copy follow the reactor.

.PARAMETER Trio
    Also build a run of three reactors with only the first powered (#559).

.PARAMETER Heaters
    rf-heater per cell, every one after the first three pipes further west along the run, as
    bench-mod-links.ps1 lays a bank (#586). The line then has -Pipes plus three per added heater.
    -Fixed follows every heater (#587).

.PARAMETER Quality
    Place the reactors, the heaters or both, as -QualityOn says, at this quality, with the bundled
    quality mod enabled, as probe-plasma-segment.ps1 -Quality does (#726). Asserted on each
    machine. Normal, with no quality mod, unless given. The lone box is always normal.

.PARAMETER QualityOn
    Which machines -Quality is for: both, the default, reactor or heaters (#726). The others are
    placed at normal quality, and that is asserted too.

.PARAMETER BuildOrder
    The order a two-reactor cell's three parts are placed in (#583): 1 the first reactor, H the
    heater bank and the pipes from it to the first reactor, 2 the bridge and the second reactor.
    The layout on the ground is the same in every order. 1H2, the default, is the order every run
    before #583 built; the trio and the solo cells are always built 1H2.

.PARAMETER Rungs
    Hold a chosen number of rungs per ladder instead of none, as probe-plasma-segment.ps1's -Rungs
    does: comma-separated <ladder>=<rungs> pairs. Asserted the same way.

.PARAMETER Trace
    A tick window, <from>,<to>: read the pair every tick inside it. Off unless given.

.PARAMETER TraceCell
    Which two-reactor cell -Trace reads: pair, the default, or both (#560).

.PARAMETER Fixed
    Run the fitted fixed-point rule beside each heated cell, one tick at a time, in every order of
    its boxes and the heater bank (#572), and with more than one heater in four orders of the bank
    (#587). probe-plasma-segment.ps1 -Fixed is the same rule
    on one reactor. It is the input-output box's rule, so under the canary its misses are a reading.

.PARAMETER Reach
    Also build nine unregistered copies of the reactor, built last so no other cell's segment id
    moves, and write each box once with set_fluid (#776): one alone, one beside a single rf-pipe,
    one bolted to an unpowered rf-heater, and four beside a plasma infinity pipe in at-least mode
    at 1e6 degC: at 0%, 50% and 100%, written at 5e6 degC, and at 50% written at the pipe's own
    1e6 (inf-50-same). Since #777, two more beside the same pipe in add mode at 1%: one written
    half full and one written full, both at 5e6 degC (add-1, add-1-full). The pipe and the heater are seeded full at 1e6 degC first. The box is read,
    and so are the neighbour and the box's segment, before the write, right after it and on each of
    the next five ticks. Needs -Ticks of at least 700.

.PARAMETER NoCanary
    Run the shipped variant alone. For a reading that is about the shipped box only, at half the
    time; the canary's rows are then not printed at all.

.PARAMETER KeepTemp
    Keep the saves, the rig mods and the captured output.

.EXAMPLE
    pwsh -File scripts/probe-plasma-input-box.ps1
    pwsh -File scripts/probe-plasma-input-box.ps1 -Pipes 3 -Ticks 40000 -Every 1000
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [ValidateRange(600, 2000000)] [int] $Ticks = 100000,
    # Comma-separated strings, not [int[]]: pwsh -File hands "3,6" over as one string.
    [ValidatePattern('^\d+(,\d+)*$')] [string] $Pipes = '3,6',
    [ValidateRange(11, 40)]       [int]    $Bridge = 12,
    [ValidateRange(60, 100000)]   [int]    $Every  = 4000,
    [ValidateRange(0.5, 1.0)]     [double] $FullAt = 0.999,
    [ValidateRange(0.0, 0.1)]     [double] $Settle = 1e-4,
    [ValidatePattern('^\d+,\d+$')] [string] $Trace,
    [ValidateSet('pair', 'both')] [string] $TraceCell = 'pair',
    [ValidateSet('rf-d-d-plasma', 'rf-d-t-plasma', 'rf-d-he3-plasma', 'rf-he3-he3-plasma')]
    [string] $Plasma = 'rf-d-d-plasma',
    [switch] $Trio,
    [ValidateRange(1, 60)] [int] $Heaters = 1,
    [ValidateSet('1H2', '12H', '21H', '2H1', 'H12', 'H21', IgnoreCase = $false)] [string] $BuildOrder = '1H2',
    [switch] $Fixed,
    [ValidateSet('uncommon', 'rare', 'epic', 'legendary', IgnoreCase = $false)] [string] $Quality,
    [ValidateSet('both', 'reactor', 'heaters')] [string] $QualityOn = 'both',
    # Case-sensitive: the names are Lua table keys.
    [ValidatePattern('^((confinement|heating|capture)_ladder=\d+)(,(confinement|heating|capture)_ladder=\d+)*$', Options = 'None')]
    [string] $Rungs,
    [switch] $Reach,
    [switch] $NoCanary,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot   = Split-Path $PSScriptRoot -Parent
$ourMods    = Get-RepoMods
$rigName    = 'rf-input-box-probe'
# No dependency on ours and a name that sorts ahead of it, so its on_tick runs before the mod's.
$preName    = 'a-rf-input-box-pre'
$canaryName = 'rf-input-box-canary'
$reactorName = if ($Plasma -in 'rf-d-he3-plasma', 'rf-he3-he3-plasma') { 'rf-aneutronic-reactor' } else { 'rf-reactor' }
$pipeCounts = @($Pipes -split ',' | ForEach-Object { [int] $_ })
if (@($pipeCounts | Sort-Object -Unique).Count -ne $pipeCounts.Count) { throw "-Pipes names a count twice: $Pipes" }
foreach ($count in $pipeCounts) {
    if ($count -lt 3 -or $count -gt 12) { throw "-Pipes $count is outside 3 to 12." }
}
$traceFrom, $traceTo = if ($Trace) { $Trace -split ',' | ForEach-Object { [int] $_ } } else { 0, -1 }
if ($Trace -and ($traceTo -lt $traceFrom -or $traceTo -ge $Ticks)) { throw "-Trace $Trace is not a window inside -Ticks $Ticks." }
$named = @($Rungs -split ',' | Where-Object { $_ } | ForEach-Object { ($_ -split '=')[0] })
if ($named.Count -ne @($named | Sort-Object -Unique).Count) { throw "-Rungs names a ladder twice: $Rungs" }
$rungsLua = if ($Rungs) { '{ ' + (($Rungs -split ',') -join ', ') + ' }' } else { 'nil' }
if ($PSBoundParameters.ContainsKey('QualityOn') -and -not $Quality) { throw '-QualityOn needs -Quality.' }
$reactorQuality = if ($Quality -and $QualityOn -ne 'heaters') { "`"$Quality`"" } else { 'nil' }
$heaterQuality  = if ($Quality -and $QualityOn -ne 'reactor') { "`"$Quality`"" } else { 'nil' }
if ($Reach -and $Ticks -lt 700) { throw "-Reach writes on tick 600 and reads five more, so it needs -Ticks of at least 700." }
if ($Every -ge $Ticks) { throw "-Every $Every is not less than -Ticks $Ticks, so no row would be sampled." }

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp      = Join-Path ([IO.Path]::GetTempPath()) ('rf-ibox-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir    = Join-Path $temp 'mods'
$rigDir    = Join-Path $modDir $rigName
$preDir    = Join-Path $modDir $preName
$canaryDir = Join-Path $modDir $canaryName
New-Item -ItemType Directory -Path $rigDir, $preDir, $canaryDir -Force | Out-Null

@{
    name = $rigName; version = '0.0.1'; title = 'Plasma input-box probe'
    author = 'probe-plasma-input-box.ps1'; factorio_version = '2.1'
    # The canary is optional, so the rig's data-final-fixes runs after it and copies its box.
    dependencies = @('base >= 2.1.23', 'realistic-fusion-refreshed', $preName, "? $canaryName")
} | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8
@{
    name = $preName; version = '0.0.1'; title = 'Plasma input-box probe, the reading before the step'
    author = 'probe-plasma-input-box.ps1'; factorio_version = '2.1'
    dependencies = @('base >= 2.1.23')
} | ConvertTo-Json | Set-Content -Path (Join-Path $preDir 'info.json') -Encoding utf8
@{
    name = $canaryName; version = '0.0.1'; title = 'Plasma input-box canary'
    author = 'probe-plasma-input-box.ps1'; factorio_version = '2.1'
    dependencies = @('base >= 2.1.23', 'realistic-fusion-refreshed')
} | ConvertTo-Json | Set-Content -Path (Join-Path $canaryDir 'info.json') -Encoding utf8

# THE CANARY: the one field the issue asks about, and nothing else. It asserts there was something
# to change, so a canary that matched nothing cannot read as "input changes nothing".
Set-Content -Encoding utf8 -Path (Join-Path $canaryDir 'data-final-fixes.lua') -Value (@'
-- Generated by probe-plasma-input-box.ps1. Nothing here ships.
local box = data.raw.boiler["__REACTOR__"].fluid_box
if box.production_type ~= "input-output" then
  error("input-box canary: __REACTOR__'s plasma box is '" .. tostring(box.production_type)
    .. "', not input-output, so there is nothing for the canary to change")
end
box.production_type = "input"
'@).Replace('__REACTOR__', $reactorName)

# THE LONE BOX'S INSTRUMENT: the reactor under a rig-only name, so control.lua never registers or
# steps it and its plasma moves by the engine alone -- the instrument quality.md's 526.3158 was read
# on (probe-quality-leak.ps1's rfql-boiler). Copied in data-final-fixes, after the canary, so it
# carries whichever box this variant's reactor has.
Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'data-final-fixes.lua') -Value (@'
-- Generated by probe-plasma-input-box.ps1. Nothing here ships.
local lone = table.deepcopy(data.raw.boiler["__REACTOR__"])
lone.name = "rf-input-box-lone"
lone.minable = nil
lone.placeable_by = nil
lone.flags = { "not-blueprintable", "not-deconstructable", "hide-alt-info" }
data:extend({ lone })
'@).Replace('__REACTOR__', $reactorName)

Set-Content -Encoding utf8 -Path (Join-Path $preDir 'control.lua') -Value @'
-- Generated by probe-plasma-input-box.ps1. Nothing here ships.
-- Reads each watched reactor's plasma box BEFORE realistic-fusion-refreshed steps it this tick.
remote.add_interface("rf-input-box-pre", {
  watch = function(reactors) storage.watch = reactors end,
  read  = function() return storage.pre end,
  read_temp = function() return storage.pre_c end,
})
script.on_event(defines.events.on_tick, function()
  if not storage.watch then return end
  local pre, pre_c = {}, {}
  for i, reactor in ipairs(storage.watch) do
    local plasma = reactor.get_fluid(1)
    pre[i] = plasma and plasma.amount or 0
    pre_c[i] = plasma and plasma.temperature or 0
  end
  storage.pre, storage.pre_c = pre, pre_c
end)
'@

$lua = @'
-- Generated by probe-plasma-input-box.ps1. Reports; asserts nothing about the answer.

local PIPES   = { __PIPES__ }
local BRIDGE  = __BRIDGE__
local EVERY   = __EVERY__
local FULL_AT = __FULLAT__
local TRACE_FROM, TRACE_TO = __TRACEFROM__, __TRACETO__
local TRACE_CELL = "__TRACECELL__"
local TRIO  = __TRIO__
local HEATERS = __HEATERS__
local BUILD_ORDER = "__BUILDORDER__"
local RUNGS = __RUNGS__
local FIXED = __FIXED__
local ENERGY_FEED = "__ENERGYFEED__"
-- #776's cells: seeded on REACH_SEED, written on REACH_AT, read for five ticks more.
local REACH, PLASMA_FEED = __REACH__, "__PLASMAFEED__"
local REACH_SEED, REACH_AT, REACH_C, SEED_C = 300, 600, 5e6, 1e6
-- "same" writes at the feed's own temperature, so a reset shows whether it is the amount or the heat.
local REACH_KINDS = { "none", "pipe", "heater", "inf-0", "inf-50", "inf-100", "inf-50-same", "add-1", "add-1-full" }
local PLASMA  = "__PLASMA__"
local REACTOR = "__REACTOR__"
-- nil places those machines at normal quality (#726); either way the quality is asserted.
local REACTOR_QUALITY, HEATER_QUALITY = __REACTORQUALITY__, __HEATERQUALITY__
local LONE    = "rf-input-box-lone"
-- The fluid's default_temperature and the spec's min_temperature_c: quality.md's cold seed.
local LONE_C  = 15
-- A bank of heaters runs west three tiles a heater, so the cells move apart by as much.
local PITCH   = 100 + 3 * (HEATERS - 1)
-- control.lua's UPDATE_INTERVAL; only the instrument's own check reads it.
local STEP_TICKS = 6

local logic  = require("__realistic-fusion-refreshed__/scripts/reactor-logic")
local SPEC   = REACTOR == "rf-aneutronic-reactor" and logic.aneutronic_reactor or logic.reactor
local ENERGY = SPEC.energy_fluid
-- control.lua's dt, by the same division.
local DT = STEP_TICKS / 60

local function say(fmt, ...) log("IBOXPROBE " .. string.format(fmt, ...)) end

-- WHICH OF THE STEP'S LOSSES TAKES THE HEAT (#570). M.step returns a temperature and a burn, not
-- its terms, and working them out here would be a second implementation of it. So each is read
-- off the step itself, in units x degC, the trace's own measure:
--
--   ash          what was burnt, at the temperature it was burnt at: burnt fuel leaves with its
--                share of the heat, so it lowers the amount and not the temperature
--   confinement  what the same step keeps when its spec has no confinement loss
--   charged      the charged share of the fusion power, which heats the plasma: a gain
--   radiation    whatever else the no-confinement step lost: bremsstrahlung
--
-- so a step removes ash + confinement + radiation - charged, by construction. Joules become
-- unit-degC by the step's own heating: what a joule paid raises a unit by.
local NO_CONFINEMENT_LOSS = setmetatable({ confinement_time_s = math.huge }, { __index = SPEC })
local TERMS = { "ash", "confinement", "radiation", "charged" }
local J_PER_UNIT_C
do
  local unlit, lit = logic.step(SPEC, PLASMA, 1000, 1e6, 0, DT), logic.step(SPEC, PLASMA, 1000, 1e6, 1e3, DT)
  J_PER_UNIT_C = 1e3 / ((1000 - unlit.plasma_consumed) * (lit.temperature_c - unlit.temperature_c))
end

-- M.step's clamp lands on the floor to a double's rounding, not exactly, so "at the floor" is
-- tested to single precision, which is all the engine keeps of a temperature.
local function at_floor(c)
  return c - SPEC.min_temperature_c <= SPEC.min_temperature_c * 2 ^ -23
end

--- One unheated step of `amount` at `c` degC: where it ends and what each term took.
local function unheated(amount, c)
  local real = logic.step(SPEC, PLASMA, amount, c, 0, DT)
  if not real then return nil end
  local open = logic.step(NO_CONFINEMENT_LOSS, PLASMA, amount, c, 0, DT)
  local left = amount - real.plasma_consumed
  local charged = real.fusion_power_w * DT * logic.fuels[PLASMA].charged_fraction / J_PER_UNIT_C
  return {
    amount = left, temperature = real.temperature_c, removed = amount * c - left * real.temperature_c,
    ash = real.plasma_consumed * c, charged = charged,
    confinement = left * (open.temperature_c - real.temperature_c),
    radiation = left * (c - open.temperature_c) + charged,
    -- THE STEP THAT LANDS ON THE FLOOR. M.step scales its two losses to what the plasma has left
    -- above the floor, and the no-confinement step is scaled differently, so the difference
    -- between them no longer says which term took what. Counted apart, not split.
    landed = not at_floor(c) and at_floor(real.temperature_c),
  }
end

local function new_tally()
  return { steps = 0, landings = 0, landed = 0, ash = 0, confinement = 0, radiation = 0, charged = 0,
    worst_c = 0, worst_c_tick = 0, worst_box = 0, close = 0 }
end

local function tally(sum, s)
  sum.steps = sum.steps + 1
  if s.landed then
    sum.landings, sum.landed = sum.landings + 1, sum.landed + s.removed
  else
    for _, term in ipairs(TERMS) do sum[term] = sum[term] + s[term] end
  end
end

local function say_tally(kind, sum, rest)
  say("%s steps=%d ash=%.9g confinement=%.9g radiation=%.9g charged=%.9g landed=%.9g landings=%d %s",
    kind, sum.steps, sum.ash, sum.confinement, sum.radiation, sum.charged, sum.landed, sum.landings, rest)
end

-- 10 000 s. A box that fuses enough to hold itself up never lands, and is reported as that.
local STEP_CAP = 1e5
--- Steps an unheated box held at `amount` takes from `c` to the floor, tallied when `sum` is given.
local function to_floor(spec, amount, c, sum)
  local steps = 0
  while not at_floor(c) and steps < STEP_CAP do
    if sum then tally(sum, unheated(amount, c)) end
    c = logic.step(spec, PLASMA, amount, c, 0, DT).temperature_c
    steps = steps + 1
  end
  return steps
end

-- THE FITTED FIXED-POINT RULE ON ONE BOX OR TWO (#572, #587). The transfer is Get-FixedRuleLua's,
-- which probe-plasma-segment.ps1 runs too (#588), with the destination's fill floored, the
-- rounding #564 settled. There one box pushes and pulls and then the heater pushes twice. Here the
-- order the engine takes the boxes and the heater bank in is what is being read, so every order
-- is run: two on a solo cell, six on a pair.
__FIXEDRULE__
local UNITS = rf_fixed_units
-- A solo cell has one box, so two orders; since #587 it is run too, for the D-He3 line that fills.
local ORDERS = { { "H1", "1H" }, { "H12", "H21", "1H2", "2H1", "12H", "21H" } }
-- HOW A BANK IS TAKEN (#587). One heater's output box pushes twice. With more, which heater comes
-- first, and whether each pushes twice before the next or the bank is gone through twice, is not
-- known, so four are run: heaters in build order (1 nearest the reactor) or reversed, each twice
-- in a row or the whole bank twice. With one heater they are one, and are not named.
local BANKS = {}
do
  local fwd, rev = {}, {}
  for j = 1, HEATERS do fwd[j], rev[HEATERS + 1 - j] = j, j end
  for _, bank in ipairs(HEATERS == 1 and { "" } or { "/fwd", "/rev", "/pass", "/revpass" }) do
    local list, seq = bank:find("rev") and rev or fwd, {}
    for _, j in ipairs(list) do
      seq[#seq + 1] = j
      if not bank:find("pass") then seq[#seq + 1] = j end
    end
    if bank:find("pass") then for j = 1, HEATERS do seq[#seq + 1] = list[j] end end
    BANKS[#BANKS + 1] = { name = bank, seq = seq }
  end
end
local function fixed_flow(from, from_volume, to, to_volume)
  return rf_fixed_flow(math.floor, from, from_volume, to, to_volume)
end
--- One engine tick from `fx` (2^-24 units), the heater bank (H, its heaters in `seq`) and the
--- boxes (1, 2) taken in `order`: the boxes, the segment and each heater where it ends, in that
--- order, and what each box pushed into the segment on the way.
local function fixed_step(order, seq, fx)
  local box, seg, heater, pushed = { table.unpack(fx.box) }, fx.segment, { table.unpack(fx.had) }, {}
  for who in order:gmatch(".") do
    if who == "H" then
      for _, j in ipairs(seq) do
        local give = fixed_flow(heater[j], fx.H, seg, fx.C); heater[j], seg = heater[j] - give, seg + give
      end
    else
      local k = tonumber(who)
      local push = fixed_flow(box[k], fx.V, seg, fx.C); box[k], seg = box[k] - push, seg + push
      pushed[k] = push
      local pull = fixed_flow(seg, fx.C, box[k], fx.V); box[k], seg = box[k] + pull, seg - pull
    end
  end
  local told = { table.unpack(box) }
  told[#told + 1] = seg
  for _, h in ipairs(heater) do told[#told + 1] = h end
  return told, pushed
end

__RIGBUILD__

__QUIETMAP__

-- 2.1 reads a segment off the entity (/2.1.23/ LuaEntity), and a box with none answers nil or its own.
local function segment_fluid(entity)
  return entity.has_fluid_segment(1) and entity.get_fluid_segment_fluid(1) or nil
end
local function segment_of(entity)
  local fluid = segment_fluid(entity)
  return fluid and fluid.amount or 0
end
local function segment_id(entity)
  return entity.has_fluid_segment(1) and entity.get_fluid_segment_id(1) or nil
end
-- What 2.0's get_capacity answered on a pipe: the segment's, which the fixed rule's C is.
local function segment_capacity(entity)
  return entity.has_fluid_segment(1) and entity.get_fluid_segment_capacity(1) or entity.get_fluid_capacity(1)
end

-- A machine the engine placed at another quality than asked would read as that quality's.
local function at_quality(machine, quality)
  if machine.quality.name ~= (quality or "normal") then
    error(string.format("%s was placed at %s, not %s", machine.name, machine.quality.name, quality or "normal"))
  end
  return machine
end

local function reactor_at(surface, force, x)
  local reactor = at_quality(rf_place_or_die(surface, { name = REACTOR, position = { x, 0.5 },
    force = force, raise_built = true, quality = REACTOR_QUALITY }, REACTOR), REACTOR_QUALITY)
  if rf_box_of(reactor, ENERGY) ~= 2 then error(REACTOR .. "'s boxes are not where they were") end
  local out = reactor.get_fluid_box_pipe_connections(2)[1]
  local drain = rf_place_or_die(surface,
    { name = ENERGY_FEED, position = out.target_position, force = force }, "the energy drain")
  drain.set_infinity_pipe_filter({ name = ENERGY, percentage = 0, mode = "at-most" })
  return reactor
end

local function pipes_from(surface, force, from, step, count)
  rf_pipe_run(surface, force, "rf-pipe", from, step, count)
  local pipes = {}
  for i = 0, count - 1 do
    local at = { from[1] + step[1] * i, from[2] + step[2] * i }
    pipes[#pipes + 1] = surface.find_entity("rf-pipe", at)
      or error(string.format("no rf-pipe at (%g, %g)", at[1], at[2]))
  end
  return pipes
end

local function power(surface, force, x, dx)
  rf_place_or_die(surface, { name = "substation", position = { x + dx, 5 }, force = force },
    "a substation")
  local eei = rf_place_or_die(surface, { name = "electric-energy-interface",
    position = { x + dx + (dx > 0 and 2.5 or -2.5), 5.5 }, force = force }, "a power source")
  eei.power_production = 8e6
end

--- One heater bank, `pipe_count` pipes and a reactor; with `bridge`, `chain` more reactors (one if
--- nil) each that many pipes east of the last, powered only when `both` is set. A cell of two
--- reactors places its three parts in BUILD_ORDER (#583); the layout on the ground is the same.
local function build(surface, force, ox, label, pipe_count, bridge, both, chain)
  -- A power island every 18 tiles west along the bank, one substation's supply area apiece.
  for k = -1, math.ceil(3 * (HEATERS - 1) / 18) do power(surface, force, ox, -9 - 18 * k) end
  -- Both reactors' west plasma connection is 7 tiles out, so the first pipe is 8.
  local west = { ox + 0.5 - 8, 0.5 }
  local cell = { label = label, sides = {}, at = {} }
  local first, run, heaters, seconds = nil, nil, {}, {}

  local parts = {
    ["1"] = function() first = reactor_at(surface, force, ox + 0.5) end,
    -- THE HEATER BANK, as bench-mod-links.ps1 lays it (#586): every heater past the first adds
    -- three pipes to the run and sits on the last three.
    H = function()
      run = pipes_from(surface, force, west, { -1, 0 }, pipe_count + 3 * (HEATERS - 1))
      local feed = prototypes.recipe[PLASMA].ingredients[1].name
      for i = 0, HEATERS - 1 do
        local heater = at_quality(rf_place_facing(surface, force, {
          name = "rf-heater", fluid = PLASMA,
          prepare = function(entity) entity.set_recipe(PLASMA) end,
          target = { west[1] - (pipe_count - 1) - 3 * i, west[2] }, seed = { ox - 24.5 - 4 * i, 20.5 },
          quality = HEATER_QUALITY,
        }), HEATER_QUALITY)
        rf_unbound(surface, force, heater, rf_box_of(heater, feed),
          { name = feed, percentage = 1, mode = "at-least" })
        heaters[#heaters + 1] = heater
      end
    end,
    ["2"] = function()
      local from = ox + 0.5
      for _ = 1, bridge and (chain or 1) or 0 do
        local east = { from + 8, 0.5 }
        local span = pipes_from(surface, force, east, { 1, 0 }, bridge)
        local x = east[1] + (bridge - 1) + 8
        if both then power(surface, force, x - 0.5, 9) end
        seconds[#seconds + 1] = { reactor = reactor_at(surface, force, x), span = span }
        from = x
      end
    end,
  }
  local order = (bridge and not chain) and BUILD_ORDER or "1H2"
  for who in order:gmatch(".") do parts[who]() end

  for _, heater in ipairs(heaters) do
    if not (heater.electric_network_id and first.electric_network_id) then
      error("a machine in the " .. label .. " cell is on no electric network")
    end
  end
  cell.reactors, cell.run, cell.sides[1] = { first }, run, run[1]
  -- Every heater shares one output box index and capacity, so the first's stand for the bank's.
  cell.heater, cell.heater_box, cell.heaters = heaters[1], rf_box_of(heaters[1], PLASMA), heaters
  for _, s in ipairs(seconds) do
    local second = s.reactor
    if both then
      if not second.electric_network_id then error("the " .. label .. " cell's second reactor is unpowered") end
    -- THE DISCRIMINATOR: what heats this one arrived along the pipe.
    elseif second.electric_network_id then
      error("the " .. label .. " cell's unpowered reactor is on an electric network, so its heat would not say pooling")
    end
    cell.reactors[#cell.reactors + 1] = second
    cell.sides[#cell.sides + 1] = s.span[1]
    cell.span = cell.span or s.span
  end
  return cell
end

local function ids(cell)
  local parts = {}
  for r, reactor in ipairs(cell.reactors) do
    parts[#parts + 1] = string.format("box%d=%s", r, tostring(segment_id(reactor)))
  end
  if cell.run then parts[#parts + 1] = "run=" .. tostring(segment_id(cell.run[1])) end
  if cell.span then parts[#parts + 1] = "bridge=" .. tostring(segment_id(cell.span[1])) end
  return table.concat(parts, " ")
end

--- One unregistered copy of the reactor with `kind`'s neighbour on its box's first connection.
local function reach_cell(surface, force, x, kind)
  local box = rf_place_or_die(surface, { name = LONE, position = { x + 0.5, -60.5 }, force = force }, LONE)
  local conn = box.get_fluid_box_pipe_connections(1)[1]
  local cell = { kind = kind, box = box, other_box = 1 }
  if kind == "pipe" then
    cell.other = rf_place_or_die(surface, { name = "rf-pipe", position = conn.target_position, force = force }, "rf-pipe")
  elseif kind == "heater" then
    -- Bolted: an output connection facing east points at the box's own connection tile, so the
    -- heater is turned until it has one. rf_place_facing does not turn. No power, no feed.
    for _, direction in ipairs({ defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west }) do
      local probe = surface.create_entity({ name = "rf-heater", position = { x + 0.5, -85.5 }, force = force, direction = direction })
      probe.set_recipe(PLASMA)
      local index = rf_box_of(probe, PLASMA)
      for _, c in ipairs(probe.get_fluid_box_pipe_connections(index) or {}) do
        if not cell.other and c.target_position.x - c.position.x > 0.5 then
          local at = { probe.position.x + conn.position.x - c.target_position.x, probe.position.y + conn.position.y - c.target_position.y }
          cell.other = rf_place_or_die(surface, { name = "rf-heater", position = at, force = force, direction = direction }, "rf-heater")
          cell.other.set_recipe(PLASMA)
          cell.other_box = index
        end
      end
      probe.destroy()
    end
    if not cell.other then error("rf-heater has no plasma connection that faces east in any direction") end
  elseif kind ~= "none" then
    cell.other = rf_place_or_die(surface, { name = PLASMA_FEED, position = conn.target_position, force = force },
      "the plasma feed")
    cell.other.set_infinity_pipe_filter({ name = PLASMA, percentage = tonumber(kind:match("%-(%d+)")) / 100,
      mode = kind:find("^add") and "add" or "at-least", temperature = SEED_C })
  end
  return cell
end

local function reach_read(c, tick, what)
  local b, s = c.box.get_fluid(1), segment_fluid(c.box)
  local o = c.other and c.other.get_fluid(c.other_box)
  local oseg = c.other and c.other.has_fluid_segment(c.other_box) and c.other.get_fluid_segment_id(c.other_box)
  say("reach cell=%s tick=%d what=%s box=%.17g boxc=%.17g other=%.17g otherc=%.17g seg=%.17g segc=%.17g segcap=%s boxseg=%s otherseg=%s",
    c.kind, tick, what, b and b.amount or 0, b and b.temperature or 0, o and o.amount or 0, o and o.temperature or 0,
    s and s.amount or 0, s and s.temperature or 0,
    tostring(c.box.has_fluid_segment(1) and c.box.get_fluid_segment_capacity(1)), tostring(segment_id(c.box)), tostring(oseg))
end

local function reach_tick(tick)
  for _, c in ipairs(storage.reach or {}) do
    if tick == REACH_SEED and (c.kind == "pipe" or c.kind == "heater") then
      local set = c.other.set_fluid(c.other_box,
        { name = PLASMA, amount = c.other.get_fluid_capacity(c.other_box), temperature = SEED_C })
      say("reach cell=%s tick=%d what=seed set=%.17g", c.kind, tick, set)
      reach_read(c, tick, "seeded")
    elseif tick == REACH_AT then
      reach_read(c, tick, "before")
      -- Half a box where nothing feeds it, so a write that spreads shows in the amount too; a
      -- full box against a feed that has filled it, so the feed's target is already met.
      local fed = (c.kind:find("^inf%-") and c.kind ~= "inf-0") or c.kind:find("full")
      local amount = c.box.get_fluid_capacity(1) * (fed and 1 or 0.5)
      local c_at = c.kind:find("same") and SEED_C or REACH_C
      local set = c.box.set_fluid(1, { name = PLASMA, amount = amount, temperature = c_at })
      say("reach cell=%s tick=%d what=write asked=%.17g at=%.17g set=%.17g", c.kind, tick, amount, c_at, set)
      reach_read(c, tick, "after")
    elseif tick > REACH_AT and tick <= REACH_AT + 5 then
      reach_read(c, tick, "later")
    end
  end
end

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player

  force.research_all_technologies()
  rf_unresearch(force, logic, logic.reactor, RUNGS)
  rf_assert_research(function(ok, name, detail)
    if not ok then error(name .. " -- " .. detail) end
    say("research %s", name)
  end, force, logic, logic.reactor, RUNGS or false)

  -- The trio is two bridges long, so it takes two pitches at the east end.
  local east = (#PIPES + (TRIO and 4 or 2)) * PITCH
  surface.request_to_generate_chunks({ east / 2, 0 }, math.ceil(east / 32) + 4)
  surface.force_generate_chunk_requests()
  storage.quieted = __QUIETFN__(surface)
  local clear = { { -60 - 3 * (HEATERS - 1), REACH and -100 or -40 }, { east, 40 } }
  local tiles = {}
  for x = clear[1][1], clear[2][1] do
    for y = clear[1][2], clear[2][2] do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = clear })) do
    if e.type ~= "character" then e.destroy() end
  end

  local cells, watch, tracked = {}, {}, {}
  for i, pipe_count in ipairs(PIPES) do
    cells[#cells + 1] = build(surface, force, (i - 1) * PITCH, "solo" .. pipe_count, pipe_count, nil)
  end
  cells[#cells + 1] = build(surface, force, #PIPES * PITCH, "pair" .. PIPES[1], PIPES[1], BRIDGE)
  cells[#cells + 1] = build(surface, force, (#PIPES + 1) * PITCH, "both" .. PIPES[1], PIPES[1], BRIDGE, true)
  -- THE LONE BOX: no pipe, no heater, no power, seeded to the box's own capacity at the floor.
  local lone = rf_place_or_die(surface, { name = LONE, position = { 0.5, -24.5 }, force = force }, LONE)
  lone.set_fluid(1, { name = PLASMA, amount = lone.get_fluid_capacity(1), temperature = LONE_C })
  cells[#cells + 1] = { label = "lone", reactors = { lone }, sides = { lone } }
  if TRIO then
    cells[#cells + 1] = build(surface, force, (#PIPES + 2) * PITCH, "trio" .. PIPES[1], PIPES[1], BRIDGE, false, 2)
  end
  for _, cell in ipairs(cells) do
    for r, reactor in ipairs(cell.reactors) do
      watch[#watch + 1] = reactor
      if cell.at then cell.at[r] = #watch end
      tracked[#tracked + 1] = { cell = cell, r = r, reactor = reactor, side = cell.sides[r],
        cap = reactor.get_fluid_capacity(1), writes = 0, steps = 0 }
    end
  end
  remote.call("rf-input-box-pre", "watch", watch)
  storage.cells, storage.tracked = cells, tracked
  storage.per_craft = prototypes.recipe[PLASMA].products[1].amount
  local production = prototypes.entity[REACTOR].fluidbox_prototypes[1].production_type
  -- The heater's cycle, the period the settle test compares rows across (#576).
  local heater_ticks = 60 * prototypes.recipe[PLASMA].energy
    / prototypes.entity["rf-heater"].get_crafting_speed(HEATER_QUALITY)
  say("built cells=%d quieted=%d production_type=%s lone_production_type=%s heater_ticks=%.17g", #cells,
    storage.quieted, production, prototypes.entity[LONE].fluidbox_prototypes[1].production_type, heater_ticks)
  for _, t in ipairs(tracked) do
    say("reactor cell=%s r=%d box_cap=%g side_cap=%g powered=%s", t.cell.label, t.r, t.cap,
      segment_capacity(t.side), tostring(t.reactor.electric_network_id ~= nil))
  end
  for _, cell in ipairs(cells) do say("ids cell=%s tick=%d %s", cell.label, game.tick, ids(cell)) end
  -- Last, so no cell above moves its segment id.
  if REACH then
    storage.reach = {}
    for k, kind in ipairs(REACH_KINDS) do storage.reach[k] = reach_cell(surface, force, 30 * (k - 1), kind) end
  end
end)

script.on_event(defines.events.on_tick, function()
  local tick = game.tick
  reach_tick(tick)
  local pre = remote.call("rf-input-box-pre", "read")
  if not pre then return end
  local sample = tick % EVERY == 0
  local pre_c = remote.call("rf-input-box-pre", "read_temp")
  local traced = tick >= TRACE_FROM and tick <= TRACE_TO and {}
  for i, t in ipairs(storage.tracked) do
    if not t.reactor.valid then error("the " .. t.cell.label .. " cell lost a reactor mid-run") end
    local plasma = t.reactor.get_fluid(1)
    local box = plasma and plasma.amount or 0
    if tick % STEP_TICKS == 0 then
      t.steps = t.steps + 1
      if pre[i] ~= box then t.writes = t.writes + 1 end
    elseif pre[i] ~= box then
      -- THE INSTRUMENT'S OWN CHECK: only the mod's step may come between the two readings.
      error(string.format("tick %d: the %s cell's box %d read %.9g before the mod and %.9g after "
        .. "it on a tick it does not step on", tick, t.cell.label, t.r, pre[i], box))
    end
    if not t.full and box >= FULL_AT * t.cap then t.full = tick end
    local temp = plasma and plasma.temperature or 0
    -- The first tick a FULL box reads the floor (#571): an empty line's cold box does not count.
    if t.full and not t.floor and temp == SPEC.min_temperature_c then t.floor = tick end
    if traced and t.cell.span and t.cell.label:sub(1, 4) == TRACE_CELL then
      traced[#traced + 1] = string.format("b%dpre=%.17g c%dpre=%.17g b%d=%.17g c%d=%.17g", t.r, pre[i],
        t.r, pre_c[i], t.r, box, t.r, plasma and plasma.temperature or 0)
      traced.cell = t.cell
      -- THE STEP'S TERMS, for a box nothing heats (#570). An unpowered reactor pays nothing, so
      -- the mod steps it with no heating; nothing researched, so SPEC is the spec it is stepped
      -- with. The window's last tick is left out, as Write-Trace leaves it out of the heat.
      if not RUNGS and not t.reactor.electric_network_id then
        if tick == TRACE_FROM then
          t.split = new_tally()
          local sum = new_tally()
          local steps = to_floor(SPEC, t.cap, temp, sum)
          say_tally("descent", sum, string.format("r=%d from=%.9g amount=%g radiation_only_steps=%d cap=%d step_ticks=%d",
            t.r, temp, t.cap, to_floor(NO_CONFINEMENT_LOSS, t.cap, temp), STEP_CAP, STEP_TICKS))
        end
        local s = tick % STEP_TICKS == 0 and tick < TRACE_TO and unheated(pre[i], pre_c[i])
        if s then
          local sum = t.split
          tally(sum, s)
          -- A box read empty after the step has no temperature to miss by a fraction of.
          local off = temp ~= 0 and math.abs(s.temperature - temp) / temp or math.huge
          if off > sum.worst_c then sum.worst_c, sum.worst_c_tick = off, tick end
          sum.worst_box = math.max(sum.worst_box, math.abs(s.amount - box))
          -- The engine keeps a temperature in single precision and an amount in whole 2^-24
          -- units, so that much of a miss is the write and not the arithmetic.
          if off <= 2 ^ -23 and math.abs(s.amount - box) <= 2 ^ -24 then sum.close = sum.close + 1 end
        end
        if tick == TRACE_TO then
          local sum = t.split
          say_tally("split", sum, string.format("r=%d worst_c=%.9g worst_c_tick=%d worst_box=%.9g close=%d",
            t.r, sum.worst_c, sum.worst_c_tick, sum.worst_box, sum.close))
        end
      end
    end
    if sample then
      say("row cell=%s r=%d tick=%d box=%.9g temp=%.9g seg=%.9g writes=%d steps=%d full=%s floor=%s",
        t.cell.label, t.r, tick, box, temp, segment_of(t.side),
        t.writes, t.steps, tostring(t.full or "never"), tostring(t.floor or "never"))
    end
  end
  if traced and traced.cell then
    local pipe = segment_fluid(traced.cell.span[1])
    say("trace tick=%d %s seg=%.17g segc=%.17g segcap=%.17g", tick, table.concat(traced, " "),
      segment_of(traced.cell.span[1]), pipe and pipe.temperature or 0,
      segment_capacity(traced.cell.span[1]))
  end
  if sample then
    for _, cell in ipairs(storage.cells) do say("ids cell=%s tick=%d %s", cell.label, tick, ids(cell)) end
  end

  for _, cell in ipairs(FIXED and storage.cells or {}) do
    -- Every heated cell of one reactor or two; the trio is not followed.
    if cell.heaters and #cell.reactors <= 2 then
      local fx = cell.fx
      local boxes = #cell.reactors
      local held, crafts = {}, {}
      for j, heater in ipairs(cell.heaters) do
        local out = heater.get_fluid(cell.heater_box)
        held[j], crafts[j] = (out and out.amount or 0) * UNITS, heater.products_finished
      end
      -- A solo cell has no bridge, so its segment is read through the heater's run.
      local segment = segment_of((cell.span or cell.run)[1]) * UNITS
      if fx then
        fx.had = {}
        for j = 1, HEATERS do fx.had[j] = fx.held[j] + (crafts[j] - fx.crafts[j]) * storage.per_craft * UNITS end
        local seen = {}
        for k = 1, boxes do seen[k] = pre[cell.at[k]] * UNITS end
        seen[#seen + 1] = segment
        for j = 1, HEATERS do seen[#seen + 1] = held[j] end
        for _, reading in ipairs(seen) do
          if reading ~= math.floor(reading) then fx.off_grid = fx.off_grid + 1 end
        end
        local phase = fx.brimmed and "full" or "filling"
        fx[phase] = fx[phase] + 1
        for _, order in ipairs(ORDERS[boxes]) do
          for _, bank in ipairs(BANKS) do
            local told, pushed = fixed_step(order, bank.seq, fx)
            local off, m = 0, fx[phase .. order .. bank.name]
            for n = 1, #seen do off = math.max(off, math.abs(told[n] - seen[n])) end
            -- What the order has each box push, whether or not it fits: an order that fits says
            -- which box gives its own plasma to the line.
            for k = 1, boxes do m.pushed[k] = m.pushed[k] + pushed[k] end
            if off > 0 then
              m.missed, m.first = m.missed + 1, m.first or tick
              if off > m.worst then m.worst = off end
            end
          end
        end
      else
        fx = { filling = 0, full = 0, off_grid = 0, V = cell.reactors[1].get_fluid_capacity(1),
          C = segment_capacity((cell.span or cell.run)[1]), H = cell.heater.get_fluid_capacity(cell.heater_box) }
        for _, phase in ipairs({ "filling", "full" }) do
          for _, order in ipairs(ORDERS[boxes]) do
            for _, bank in ipairs(BANKS) do fx[phase .. order .. bank.name] = { missed = 0, worst = 0, pushed = { 0, 0 } } end
          end
        end
        cell.fx = fx
      end
      -- The state the next tick is predicted from: each box AFTER the mod's step.
      fx.box, fx.brimmed = {}, true
      for k, reactor in ipairs(cell.reactors) do
        local plasma = reactor.get_fluid(1)
        fx.box[k] = (plasma and plasma.amount or 0) * UNITS
        fx.brimmed = fx.brimmed and storage.tracked[cell.at[k]].full ~= nil
      end
      fx.segment, fx.held, fx.crafts = segment, held, crafts
      if sample then
        for _, phase in ipairs({ "filling", "full" }) do
          for _, order in ipairs(ORDERS[boxes]) do
            for _, bank in ipairs(BANKS) do
              local m = fx[phase .. order .. bank.name]
              say("fixed cell=%s tick=%d phase=%s order=%s ticks=%d missed=%d first=%s worst=%.17g off_grid=%d boxes=%d push1=%.17g push2=%.17g",
                cell.label, tick, phase, order .. bank.name, fx[phase], m.missed, tostring(m.first or "never"),
                m.worst / UNITS, fx.off_grid, boxes, m.pushed[1] / UNITS, m.pushed[2] / UNITS)
            end
          end
        end
      end
    end
  end
end)
'@

$inv = [cultureinfo]::InvariantCulture
$lua = $lua.
    Replace('__RIGBUILD__', (Get-RigBuildLua)).
    Replace('__FIXEDRULE__', (Get-FixedRuleLua)).
    Replace('__QUIETMAP__', (Get-QuietMapLua)).
    Replace('__QUIETFN__', $script:QuietMapFunction).
    Replace('__PIPES__', ($pipeCounts -join ', ')).
    Replace('__BRIDGE__', "$Bridge").
    Replace('__EVERY__', "$Every").
    Replace('__FULLAT__', $FullAt.ToString($inv)).
    Replace('__TRACEFROM__', "$traceFrom").
    Replace('__TRACETO__', "$traceTo").
    Replace('__TRACECELL__', $TraceCell).
    Replace('__PLASMA__', $Plasma).
    Replace('__REACTOR__', $reactorName).
    Replace('__REACTORQUALITY__', $reactorQuality).
    Replace('__HEATERQUALITY__', $heaterQuality).
    Replace('__TRIO__', $(if ($Trio) { 'true' } else { 'false' })).
    Replace('__HEATERS__', "$Heaters").
    Replace('__BUILDORDER__', $BuildOrder).
    Replace('__RUNGS__', $rungsLua).
    Replace('__FIXED__', $(if ($Fixed) { 'true' } else { 'false' })).
    Replace('__REACH__', $(if ($Reach) { 'true' } else { 'false' })).
    Replace('__PLASMAFEED__', $(if ($Reach) { Write-PlasmaFeed -RigDirectory $rigDir } else { '' })).
    Replace('__ENERGYFEED__', (Write-EnergyFeed -RigDirectory $rigDir))
Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') -Value $lua

$invoke = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

function Read-Records {
    param([string[]] $Lines, [string] $Kind)
    foreach ($line in $Lines) {
        if ($line -notmatch "IBOXPROBE $Kind ") { continue }
        $f = @{}
        foreach ($m in [regex]::Matches($line, '(\w+)=([^\s]+)')) { $f[$m.Groups[1].Value] = $m.Groups[2].Value }
        $f
    }
}
function Num { param($Value) [double]::Parse($Value, $inv) }

function Invoke-Variant {
    <#  One run of the rig, with the canary named enabled or named disabled -- never merely left
        out, because Factorio auto-enables a mod on disk that mod-list.json does not name.  #>
    param([Parameter(Mandatory)] [string] $Tag, [switch] $WithCanary)

    $mods = $ourMods + $rigName + $preName + @(if ($WithCanary) { $canaryName })
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabled -Mods $mods `
        -Disabled @(if (-not $WithCanary) { $canaryName })
    $save   = Join-Path $temp "$Tag.zip"
    $create = Invoke-Factorio @invoke -Arguments @('--create', $save) -Tag "$Tag-create"
    if ($create.Code -ne 0) { return @{ Tag = $Tag; Code = $create.Code; Create = $create } }
    # Not Invoke-FactorioStep: a canary that loads and then fails its run is a reading as well,
    # and throwing here would take the shipped variant's rows down with it (#556).
    $run = Invoke-Factorio @invoke -Tag "$Tag-run" -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', "$Ticks", '--benchmark-runs', '1', '--disable-audio')
    return @{ Tag = $Tag; Code = 0; Create = $create; Created = @(Get-Content $create.OutFile)
        RunCode = $run.Code; Run = $run; Ran = @(Get-Content $run.OutFile) }
}

function Write-Variant {
    param([Parameter(Mandatory)] [hashtable] $Run)

    Write-Host ''
    Write-Host "##### $($Run.Tag)"
    if ($Run.Code -ne 0) {
        Write-Host "  the map was not created: Factorio exited $($Run.Code). The tail of its output:"
        Write-FactorioTail $Run.Create
        return
    }
    if ($Run.RunCode -ne 0) {
        Write-Host "  the map was created, then the run failed: Factorio exited $($Run.RunCode). The tail of its output:"
        Write-FactorioTail $Run.Run
        return
    }
    # WHAT THE GAME SAID. Every line naming a warning or an error outside the probe's own rows,
    # from both the create and the run.
    $complaints = @(($Run.Created + $Run.Ran) | Where-Object { $_ -match '(?i)\b(warning|error)' -and $_ -notmatch 'IBOXPROBE' })
    Write-Host ("  load: map created, exit 0; {0} line(s) naming a warning or an error" -f $complaints.Count)
    foreach ($c in $complaints) { Write-Host "    $c" }
    $built = @(Read-Records $Run.Created 'built')[0]
    Write-Host "  $reactorName's box 1 production_type, as the runtime prototype reads: $($built['production_type'])"
    Write-Host "  the lone copy's box 1 production_type: $($built['lone_production_type'])"
    # The settle test's lag: the fewest ticks that are whole multiples of both -Every and the
    # heater's cycle, so a row is compared with one at the same point of that cycle.
    $cycle = [math]::Round((Num $built['heater_ticks']))
    $gcd = [long]$Every; $b = [long]$cycle
    while ($b) { $gcd, $b = $b, ($gcd % $b) }
    $lag = [long]$Every / $gcd * $cycle
    Write-Host ("  the heater's cycle is {0:G9} ticks{1}; the settle test compares each row with the row {2} ticks before it" -f
        (Num $built['heater_ticks']), $(if ($cycle -ne (Num $built['heater_ticks'])) { ", taken as $cycle" } else { '' }), $lag)
    $research = @($Run.Created | Select-String -Pattern 'IBOXPROBE research ')
    Write-Host ("  research: $($research.Count) rung(s) asserted, " +
        $(if ($Rungs) { "-Rungs $Rungs, every other ladder OFF" } else { 'every ladder OFF' }))

    # The segment ids at build and at the last sample, per cell.
    $idRows = @(Read-Records $Run.Created 'ids') + @(Read-Records $Run.Ran 'ids')
    foreach ($cell in ($idRows | ForEach-Object { $_['cell'] } | Select-Object -Unique)) {
        $of = @($idRows | Where-Object { $_['cell'] -eq $cell })
        foreach ($id in @($of[0]) + @(if ($of.Count -gt 1) { $of[-1] })) {
            Write-Host ("  segment ids, {0} at tick {1}: {2}" -f $cell, $id['tick'],
                (($id.Keys | Where-Object { $_ -notin 'cell', 'tick' } | Sort-Object | ForEach-Object { "$_=$($id[$_])" }) -join ' '))
        }
    }

    $rows = @(Read-Records $Run.Ran 'row')
    foreach ($r in @(Read-Records $Run.Created 'reactor')) {
        $cell = $r['cell']; $n = $r['r']
        $mine = @($rows | Where-Object { $_['cell'] -eq $cell -and $_['r'] -eq $n })
        if ($mine.Count -eq 0) { throw "$($Run.Tag): $cell reactor $n reported no row." }
        $end = $mine[-1]
        Write-Host ''
        Write-Host ("  === {0}, reactor {1}: box {2}, the segment beside it reports {3}, powered {4}" -f
            $cell, $n, $r['box_cap'], $r['side_cap'], $r['powered'])
        Write-Host ("  the box first reached {0:P1} on tick {1}; to tick {2} control.lua changed it across its handler on {3} of {4} step ticks" -f
            $FullAt, $end['full'], $end['tick'], $end['writes'], $end['steps'])
        Write-Host "  full, it first read the floor's temperature on tick $($end['floor'])"
        Write-Host ('  {0,8}{1,13}{2,13}{3,15}{4,11}' -f 'tick', 'box', 'segment', 'box degC', 'seg/1000')
        # THE SETTLE TEST (#576): rows are compared only with rows a whole number of $lag ticks
        # away, the same point of the heater's cycle, so the cycle's own swing is not read as
        # drift. Settled from the first row after which every such pair is within $Settle,
        # relative -- every pair and not only neighbours, because a drift under $Settle a step
        # passes a test of steps and the box has not stopped. Until #576 every row was compared
        # with the run's LAST row, which passed #560's shipped box 360 000 ticks before it stopped.
        $k = [int]($lag / $Every)
        $rowCount = $mine.Count
        $lo = @{}; $hi = @{}; $from = $rowCount
        for ($i = $rowCount - 1; $i -ge 0; $i--) {
            $p = $i % $k; $t = Num $mine[$i]['temp']
            $l = if ($lo.ContainsKey($p)) { [math]::Min($lo[$p], $t) } else { $t }
            $h = if ($hi.ContainsKey($p)) { [math]::Max($hi[$p], $t) } else { $t }
            if ($h - $l -gt $Settle * [math]::Abs($h)) { break }
            $lo[$p] = $l; $hi[$p] = $h; $from = $i
        }
        if ($rowCount -le $k) {
            Write-Host ("  NOT settled by tick {0}: {1} row(s), too few to compare any with the row {2} ticks before it" -f $end['tick'], $rowCount, $lag)
        } elseif ($from -gt $rowCount - 1 - $k) {
            $before = $mine[$rowCount - 1 - $k]
            Write-Host ("  NOT settled by tick {0}: it reads {1:E9} degC against {2:E9} at {3}, {4:E3} apart, over {5:G3}" -f
                $end['tick'], (Num $end['temp']), (Num $before['temp']), $before['tick'],
                ([math]::Abs((Num $end['temp']) - (Num $before['temp'])) / [math]::Abs((Num $end['temp']))), $Settle)
        } else {
            Write-Host ("  settled from tick {0}: from it to {1}, every two rows a multiple of {2} ticks apart read within {3:G3} of each other; {4:E9} degC at {0} and {5:E9} at {1}; the box reads {6:F4} at {0} and {7:F4} at {1}" -f
                $mine[$from]['tick'], $end['tick'], $lag, $Settle, (Num $mine[$from]['temp']), (Num $end['temp']), (Num $mine[$from]['box']), (Num $end['box']))
        }
        foreach ($row in $mine) {
            $box = Num $row['box']; $seg = Num $row['seg']
            Write-Host ('  {0,8}{1,13:F4}{2,13:F4}{3,15:E7}{4,11:F1}' -f [int]$row['tick'], $box, $seg,
                (Num $row['temp']), $(if ($box -gt 0) { 1000 * $seg / $box } else { 0 }))
        }
    }
    if ($Fixed) { Write-Fixed -Rows @(Read-Records $Run.Ran 'fixed') }
    if ($Reach) { Write-Reach -Rows @(Read-Records $Run.Ran 'reach') }
    if ($Trace) {
        $pairBox = @(Read-Records $Run.Created 'reactor' | Where-Object { $_['cell'] -like "$TraceCell*" })[0]
        Write-Trace -Rows @(Read-Records $Run.Ran 'trace') -BoxVolume (Num $pairBox['box_cap'])
        Write-Split -Split @(Read-Records $Run.Ran 'split') -Descent @(Read-Records $Run.Ran 'descent')
    }
}

function Write-Reach {
    <#  WHAT A WRITE TO THE BOX REACHES (#776): each copy's box, its neighbour and the box's segment,
        seeded, before the write, after it and on the five ticks that follow.  #>
    param([object[]] $Rows)

    Write-Host ''
    Write-Host '  === the reach cells: each box written once with set_fluid on tick 600'
    foreach ($r in $Rows) {
        if ($r['what'] -in 'seed', 'write') {
            Write-Host ("  {0,-11} tick {1,4} {2}: asked {3}{5}, set_fluid returned {4}" -f $r['cell'], $r['tick'], $r['what'],
                $(if ($r['asked']) { $r['asked'] } else { 'its capacity' }), $r['set'], $(if ($r['at']) { " at $($r['at']) degC" } else { ' at 1e6 degC' }))
            continue
        }
        Write-Host ("  {0,-11} tick {1,4} {2,-7} box {3,14:F8} at {4,14:E7}  neighbour {5,12:F6} at {6,14:E7}  segment {7,14:F8} at {8,14:E7} of {9}; ids box {10} neighbour {11}" -f
            $r['cell'], $r['tick'], $r['what'], (Num $r['box']), (Num $r['boxc']), (Num $r['other']), (Num $r['otherc']),
            (Num $r['seg']), (Num $r['segc']), $r['segcap'], $r['boxseg'], $r['otherseg'])
    }
}

function Write-Fixed {
    <#  THE ORDER THE ENGINE TAKES THE BOXES AND THE HEATERS IN (#572, #587): per cell, the last
        sampled row of each order, and of each way of taking a bank, split into the ticks before
        every box in the cell had read -FullAt and the ticks from then on.  #>
    param([object[]] $Rows)

    Write-Host ''
    if ($Rows.Count -eq 0) { Write-Host '  the fitted fixed-point rule: no row; no tick was sampled.'; return }
    foreach ($cell in ($Rows | ForEach-Object { $_['cell'] } | Select-Object -Unique)) {
        $of = @($Rows | Where-Object { $_['cell'] -eq $cell })
        $at = $of[-1]['tick']
        Write-Host ("  === {0}: the fitted fixed-point rule, one tick at a time, to tick {1}; {2} reading(s) were not whole 2^-24 units" -f
            $cell, $at, $of[-1]['off_grid'])
        Write-Host '  an order names what the rule takes first: H the heater, 1 the first reactor, 2 the second'
        if ($Heaters -gt 1) {
            Write-Host '  and after the slash how H takes the bank: fwd and rev heater 1 (nearest the reactor) first or last, each pushing twice in a row; pass and revpass the same, the whole bank twice'
        }
        foreach ($f in ($of | Where-Object { $_['tick'] -eq $at })) {
            $second = if ($f['boxes'] -eq '2') { ' and box 2 {0:F4}' -f (Num $f['push2']) } else { '' }
            Write-Host ("    {0}, {1,-7}: missed {2} of {3} ticks, first on {4}, worst {5:E2} units; it has box 1 push {6:F4} units{7}" -f
                $f['order'], $f['phase'], $f['missed'], $f['ticks'], $f['first'], (Num $f['worst']), (Num $f['push1']), $second)
        }
    }
}

function Write-Split {
    <#  WHICH OF THE STEP'S TERMS TOOK THE HEAT (#570), in units x degC as Write-Trace counts it.
        "the window" is M.step run from each step tick's reading before the mod; "the descent" is
        M.step run on from the window's first reading with the box held full.  #>
    param([object[]] $Split, [object[]] $Descent)

    if ($Split.Count -eq 0) {
        Write-Host "  the step's terms: not run. They are read for an unpowered box with nothing researched."
        return
    }
    $terms = {
        param($r)
        $net = (Num $r['ash']) + (Num $r['confinement']) + (Num $r['radiation']) - (Num $r['charged']) + (Num $r['landed'])
        ('ash {0:E4}, confinement {1:E4}, radiation {2:E4}, less {3:E4} of charged fusion heating; {4} step(s) landed on the floor and took {5:E4} more; in all {6:E4}' -f
            (Num $r['ash']), (Num $r['confinement']), (Num $r['radiation']), (Num $r['charged']), $r['landings'], (Num $r['landed']), $net)
    }
    foreach ($s in $Split) {
        Write-Host ("  box {0}, M.step unheated beside {1} step ticks of the window, unit-degC removed:" -f $s['r'], $s['steps'])
        Write-Host ("         " + (& $terms $s))
        Write-Host ("         against the reading after the mod: {0} of {1} steps within 2^-23 of the temperature and 2^-24 units of the amount; worst temperature miss {2:E2} of the reading, on tick {3}; worst amount miss {4:E2} units" -f
            $s['close'], $s['steps'], (Num $s['worst_c']), $s['worst_c_tick'], (Num $s['worst_box']))
    }
    foreach ($d in $Descent) {
        # The rig's STEP_CAP and STEP_TICKS, from its own record: a descent that long did not land.
        $cap = [int]$d['cap']; $per = [int]$d['step_ticks']
        $ticks = { param($n) if ([int]$n -ge $cap) { "not in $cap steps" } else { "after $n steps, $($per * [int]$n) ticks" } }
        Write-Host ("  box {0}, held at {1} units and unheated from {2:E4} degC: at the floor {3}; with no confinement loss, {4}" -f
            $d['r'], $d['amount'], (Num $d['from']), (& $ticks $d['steps']), (& $ticks $d['radiation_only_steps']))
        Write-Host ("         " + (& $terms $d))
    }
}

function Write-Trace {
    <#  THE PAIR, TICK BY TICK (#558). Between one tick's reading after the mod and the next tick's
        reading before it, only the engine has moved fluid; between a tick's two readings, only the
        mod's step has. Heat is amount x degC, which is what the mixing conserves.

        THE RULE is #531's, applied to each box alone against the segment as it stood: push
        100 x min(box fill, 1 - segment fill), then pull 100 x min(segment fill, 1 - box fill).
        The other box and the heater move the same segment inside the same tick, so a miss on the
        ticks a craft lands is the instrument's and not the rule's.  #>
    param([object[]] $Rows, [double] $BoxVolume)

    Write-Host ''
    if ($Rows.Count -lt 2) { Write-Host '  trace: no pair row inside the window.'; return }
    $t = foreach ($r in $Rows) { $n = @{}; foreach ($k in $r.Keys) { $n[$k] = Num $r[$k] }; $n }
    Write-Host ("  === the {4} cell, every tick from {0} to {1}: {2} rows, segment capacity {3}" -f
        [int]$t[0]['tick'], [int]$t[-1]['tick'], $t.Count, $t[0]['segcap'], $TraceCell)
    Write-Host "  the rule below is the input-output box's; under the canary its misses are a reading, not a fault"
    $volume = $BoxVolume
    # #531's rule for one box against a segment: what the box gains, pull less push.
    $gain = {
        param($box, $seg, $cap)
        $push = 100 * [math]::Min($box / $volume, 1 - $seg / $cap)
        $pull = 100 * [math]::Min(($seg + $push) / $cap, 1 - ($box - $push) / $volume)
        $pull - $push
    }
    foreach ($k in 1, 2) {
        $worst = 0.0; $worstAt = 0; $small = 0; $engine = 0.0; $mod = 0.0; $engineHeat = 0.0; $modHeat = 0.0
        $lastMove = 'never'; $large = @()
        for ($i = 0; $i -lt $t.Count - 1; $i++) {
            $a = $t[$i]; $n = $t[$i + 1]
            $box = $a["b$k"]
            $moved = $n["b${k}pre"] - $box
            $miss = [math]::Abs($moved - (& $gain $box $a['seg'] $a['segcap']))
            if ($miss -gt $worst) { $worst = $miss; $worstAt = [int]$a['tick'] }
            if ($miss -lt 1e-3) { $small++ }
            if ($miss -gt 0.01) { $large += [int]$a['tick'] }
            if ($moved -ne 0 -or $n["c${k}pre"] -ne $a["c$k"]) { $lastMove = [int]$a['tick'] }
            $engine += $moved; $mod += $a["b$k"] - $a["b${k}pre"]
            $engineHeat += $n["b${k}pre"] * $n["c${k}pre"] - $box * $a["c$k"]
            $modHeat    += $box * $a["c$k"] - $a["b${k}pre"] * $a["c${k}pre"]
        }
        Write-Host ("  box {0}: the engine moved {1:F4} units in and the mod's step {2:F4}; in heat, the engine {3:E4} and the step {4:E4} unit-degC, from {5:E4} to {6:E4}" -f
            $k, $engine, $mod, $engineHeat, $modHeat, ($t[0]["b$k"] * $t[0]["c$k"]), ($t[-1]["b$k"] * $t[-1]["c$k"]))
        Write-Host ("         the rule misses the engine's move by under 0.001 units on {0} of {1} ticks, worst {2:G4} on tick {3}; the engine last moved the box on tick {4}" -f
            $small, ($t.Count - 1), $worst, $worstAt, $lastMove)
        # Where the large misses fall (#577): the gaps between one and the next, most common first.
        $gaps = for ($j = 1; $j -lt $large.Count; $j++) { $large[$j] - $large[$j - 1] }
        $spacing = @($gaps | Group-Object | Sort-Object Count -Descending | Select-Object -First 4 |
            ForEach-Object { "$($_.Name) ticks x$($_.Count)" }) -join ', '
        Write-Host ("         it misses by over 0.01 units on {0} tick(s){1}" -f $large.Count,
            $(if ($large.Count -gt 1) { "; the gaps between them, most common first: $spacing" } else { '' }))
    }
    # THE BOXES TAKEN IN TURN (#577): the rule run on one box, the segment moved by what it gave,
    # and then on the other, in each order. A worst miss that moves with the order would mean
    # applying the rule to each box alone against the segment as it stood is what misses.
    foreach ($order in @(1, 2), @(2, 1)) {
        $worstOf = @{ 1 = 0.0; 2 = 0.0 }; $atOf = @{ 1 = 0; 2 = 0 }
        for ($i = 0; $i -lt $t.Count - 1; $i++) {
            $a = $t[$i]; $n = $t[$i + 1]; $seg = $a['seg']
            foreach ($k in $order) {
                $g = & $gain $a["b$k"] $seg $a['segcap']
                $seg -= $g
                $miss = [math]::Abs(($n["b${k}pre"] - $a["b$k"]) - $g)
                if ($miss -gt $worstOf[$k]) { $worstOf[$k] = $miss; $atOf[$k] = [int]$a['tick'] }
            }
        }
        Write-Host ("  the rule run on box {0} and then box {1}, the segment moved between: worst miss box 1 {2:G4} on tick {3}, box 2 {4:G4} on tick {5}" -f
            $order[0], $order[1], $worstOf[1], $atOf[1], $worstOf[2], $atOf[2])
    }
    foreach ($under in 0.5, 0.1, 0.01) {
        $hit = $t | Where-Object { $_['c1'] -gt 0 -and $_['c2'] / $_['c1'] -lt $under } | Select-Object -First 1
        Write-Host ("  box 2 first reads under {0} of box 1's temperature on tick {1}" -f $under, $(if ($hit) { [int]$hit['tick'] } else { 'never, in the window' }))
    }
    $low = ($t | Measure-Object -Minimum { $_['c2'] }).Minimum
    $floor = $t | Where-Object { $_['c2'] -eq $low } | Select-Object -First 1
    Write-Host ("  box 2's lowest reading, {0:G9} degC, is first read on tick {1}" -f $low, [int]$floor['tick'])
    Write-Host ('  {0,8}{1,11}{2,13}{3,11}{4,13}{5,11}{6,13}{7,10}{8,10}' -f 'tick', 'box 1', 'degC', 'box 2', 'degC', 'segment', 'degC', 'push', 'pull')
    $stride = [math]::Max(1, [int](($t.Count - 1) / 12))
    for ($i = 0; $i -lt $t.Count; $i += $stride) {
        $a = $t[$i]
        $push = 100 * [math]::Min($a['b2'] / $volume, 1 - $a['seg'] / $a['segcap'])
        $pull = 100 * [math]::Min(($a['seg'] + $push) / $a['segcap'], 1 - ($a['b2'] - $push) / $volume)
        Write-Host ('  {0,8}{1,11:F4}{2,13:E4}{3,11:F4}{4,13:E4}{5,11:F4}{6,13:E4}{7,10:F5}{8,10:F5}' -f
            [int]$a['tick'], $a['b1'], $a['c1'], $a['b2'], $a['c2'], $a['seg'], $a['segc'], $push, $pull)
    }
}

try {
    New-ModJunctions -ModDirectory $modDir -Links (Get-ModLinks -Root $repoRoot -Mods $ourMods)
    $enabled = if ($Quality) { Resolve-BundledSelection -Requested @('quality') -Bundled $bundled } else { @() }
    $shipped = Invoke-Variant -Tag 'shipped'
    if ($shipped.Code -ne 0) {
        Write-FactorioTail $shipped.Create
        throw "the shipped variant did not create its map (exit $($shipped.Code)), so the rig is broken."
    }
    if ($shipped.RunCode -ne 0) {
        Write-FactorioTail $shipped.Run
        throw "the shipped variant's run failed (exit $($shipped.RunCode)), so the rig is broken."
    }
    $canary = if (-not $NoCanary) { Invoke-Variant -Tag 'canary' -WithCanary }

    $version = 'unknown'
    $hit = $shipped.Created | Select-String -Pattern 'Factorio (\d+\.\d+\.\d+) \(build (\d+)' | Select-Object -First 1
    if ($hit) { $version = "$($hit.Matches[0].Groups[1].Value) (build $($hit.Matches[0].Groups[2].Value))" }
    Write-Host ''
    $added = 3 * ($Heaters - 1)
    Write-Host "Factorio $version -- $Ticks ticks per variant, $Heaters heater(s) per cell, $Plasma into $reactorName"
    Write-Host $(if (-not $Quality) { 'reactor and heaters at normal quality, no quality mod' }
        else { "$(@{ both = 'reactor and heaters'; reactor = 'reactor'; heaters = 'heaters' }[$QualityOn]) at $Quality quality, the rest normal, the bundled quality mod enabled" })
    Write-Host ("solo cells at {0} pipe(s); the pair at {1} pipe(s) to the first reactor and $Bridge between them; two-reactor cells built in the order $BuildOrder" -f
        (($pipeCounts | ForEach-Object { $_ + $added }) -join ','), ($pipeCounts[0] + $added))
    Write-Variant $shipped
    if ($canary) { Write-Variant $canary }

    Write-Host ''
    if ($canary -and ($canary.Code -ne 0 -or $canary.RunCode -ne 0)) {
        Write-Host 'OK - the probe ran. The shipped variant reported every row; the canary did not run to the'
        Write-Host '     end, which is a reading, and its tail is printed above.'
    } else {
        Write-Host 'OK - the probe ran and every row reported. The figures above are measurements, not a'
        Write-Host '     verdict. docs/research/plasma-input-box.md is what they are read into.'
    }
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'probe-plasma-input-box' }
}

#Requires -Version 7
<#
.SYNOPSIS
    Checks what a brownout and a blackout actually do to a running reactor, at both neutronic tiers.
    Discharges #70.

.DESCRIPTION
    #70 was opened on a premise: that a D-T reactor is a major generator whose plasma cools when its
    power is cut, which cuts its output, which deepens the brownout that cooled it. tests/test-reactor-logic.lua
    measures that premise to be FALSE outside Factorio -- a D-T plasma at this reactor's density and
    confinement time is ignited, so cutting the heating raises its net contribution rather than
    lowering it. This rig is that measurement taken in the game instead of in Lua, because
    CLAUDE.md holds verification here to running the game and an ADR is about to be corrected on the
    strength of it.

    WHAT A BROWNOUT IS, AND WHY THE HEATER IS IN EVERY CELL

    rf-reactor's energy source is usage_priority = "secondary-input", which the 2.0.77 docs describe
    as "used for all other machines" -- the same bucket as rf-heater, the electrolysers and the
    extractor. So the reactor is not starved BEFORE its fuel line or AFTER it: the engine gives every
    consumer on the network the same fraction. A rig that cut only the reactor's supply would be
    testing the case the reactor looks best in.

    Every cell therefore carries its own rf-heater on its own network, and the shortfall is produced
    by UNDERSUPPLYING that network rather than by scripting a cut on one entity. The coupling between
    the fuel line and the confinement heating is then the engine's, in the engine's proportions, and
    is observed rather than staged.

    WHAT IS BUILT -- eight cells, each on its own electric network and its own plasma segment

      full      A D-T reactor and its heater, supplied throughout. The baseline every other cell's
                numbers are read against, and the cell that would catch a supply figure in the wrong
                units before it was mistaken for a starved reactor.

      half      The same, undersupplied from the cut tick to half of what the cell was measured to
                draw while it was satisfied. The partial case: a brownout proper.

      dark      The same, supply to zero from the cut tick and never restored. The total case: a
                blackout. This is the cell that decides whether losing the supply is losing the
                reactor. It is NOT run until the plasma reaches ambient, because no run length would:
                a reactor holding plasma sells that plasma's own loss, so its output decays towards
                nothing and never arrives. What is measured instead is the decay -- how much of its
                lit output the reactor still has after a quarter of an hour with no power at all.

      recover   dark, with the supply restored at the end of the cut. Nothing else happens -- no
                player action, no rebuild -- so what it measures is whether the reactor comes back on
                its own.

      boundary  A reactor with no heater and no feed line at all, given one thin cold charge at the
                cut tick and full power throughout. Below a certain density a D-T plasma cannot carry
                itself, and this is the only state in which the reactor is a net drain -- so the cell
                exists to put a number on that drain rather than leave it as a worry. It has to be
                SEEDED rather than piped: holding a segment thin with an infinity pipe means
                injecting cold fluid into it for ever, and the cell would be measuring the hosing.

      plant     THE VERDICT CELL, and the only one where the loop closes: reactor, heater,
                rf-hc-exchanger, two rf-hc-turbines and a load bank on one network, with the supply
                interface as a starter motor only. At the cut tick the starter is switched off and
                the plant runs on its own output -- paying for its own confinement heating out of
                what that heating produced. At the end of the cut the load bank is raised past what
                the plant can make, which is the spiral the ticket is about, made to happen on
                purpose. If a base can eat itself this is where it does it.

      dd        A D-D reactor and its heater, taking dark's cut on the same tick. ADR 0015 settled
                the D-D tier's answer by argument plus one line of tests/test-reactor-logic.lua; this
                is the same claim measured in the same rig as the D-T one, so the two tiers' answers
                can be stated together rather than assembled from two places.

      pooled    Two D-T reactors bridged by rf-pipe on one plasma pool, one heater between them,
                taking dark's cut. ADR 0011's fluid coupling means a row is not the same object as a
                reactor, and a row is what a player builds. Whether the pair shares the fall or one
                starves the other is not derivable from a single-reactor result.

    WHAT IS ASSERTED

    The claim, decided on #70 before this was written and stated here so a reader can see what the
    cells are for:

      1. While it is lit, the reactor is never a net drain on its network, at any supply fraction.
      2. It recovers to full unattended once the supply returns.
      3. While it is re-igniting it IS a drain, that drain is bounded, and the rig states the bound.

    The third came out stronger than it was written. On the trajectory a blackout actually produces,
    re-igniting is not a drain at all -- the reactor is still selling more than it draws the whole way
    back up, because it never gets thin enough to stop. A drain does exist and `boundary` measures it,
    but reaching it took seeding a charge by hand: fifteen minutes of total blackout does not.

    Every figure is reported as well as asserted, and the assertions are on directions and bounds
    rather than on megawatts -- balance in this repository is provisional everywhere, and a rig that
    pins it fails on a rebalance instead of on a regression.

    TWO CONVENTIONS THE 2.0 API DOES NOT DOCUMENT, DERIVED HERE RATHER THAN REMEMBERED

    power_production and power_usage on an electric-energy-interface are joules per TICK, not watts.
    Nothing says so. scripts/check-hc.ps1 multiplies get_max_power_output() by 60 to reach megawatts,
    which is the same family of value, so the units check below pins the convention against vanilla's
    own steam turbine. A rig silently running on a sixtieth of its intended supply looks exactly like
    a broken mod.

    Which category of LuaFlowStatistics holds an electric network's CONSUMPTION is likewise
    undocumented for "input" versus "output". It is not guessed: both are read, and the one in which
    a satisfied reactor's draw over the settle phase lands within a factor of three of its own
    declared input_flow_limit is taken as consumption. That calibration is asserted, so a wrong
    reading cannot quietly become a net figure.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Settle
    Seconds to run before anything is cut, and it has to be long, because every "kept X% of its lit
    output" figure this rig produces is a ratio against the `full` cell's last minute of it.

    THE FIRST VERSION OF THIS RIG GOT THIS WRONG. It settled for 300 s on the strength of an
    out-of-Factorio figure -- a reactor fed a continuous 2.5 units a second is within a few percent of
    its equilibrium by then -- and in the game it is nowhere near. Measured, one sample every ten
    seconds, `full`'s output over the trailing minute:

      300 s   86 MW      900 s  277 MW     1500 s  319 MW     2100 s  324 MW
      600 s  204 MW     1200 s  307 MW     1800 s  322 MW     3000 s  324 MW

    So 300 s caught the reactor at about a quarter of its output and still climbing 40% a minute, and
    every percentage quoted against it was a ratio to a number on the way up.

    THE REASON IT IS SLOW IS THE PIPE, NOT THE PLASMA. The equilibrium the game reaches -- 324 MW at
    270 units -- is the one the pure-Lua model predicts, to three figures. What the model has no
    concept of is the feed line: a cell's plasma segment is the reactor's 1000-unit box plus every
    rf-pipe between it and the heater, and the engine fills the whole segment, not the box. The
    reactor's own box therefore approaches its share of a much larger volume, which takes about half
    an hour rather than five minutes.

    The default is 1800 s, where the trailing minute is within 0.6% of the asymptote and drifting
    0.26% a minute. That is asserted rather than claimed -- see the "its output had stopped climbing"
    check -- so a settle too short to have converged fails the run instead of quietly rebasing every
    percentage in the report.

    One cell is deliberately NOT converged at the default and the report says so: `dd`. A D-D plasma
    never ignites, so it climbs on temperature as well as density and takes far longer. It is a
    contrast cell rather than a baseline, and an unconverged D-D baseline understates its own fade,
    so the tier gap the rig reports is if anything narrower than the truth.

.PARAMETER Cut
    Seconds the shortfall lasts. There is no length at which `dark` finishes -- see its entry above --
    so this is a question about how far down the decay is worth following. The default is fifteen
    minutes, which is long enough that "the reactor survived it" is a claim worth something and short
    enough to run.

.PARAMETER Restore
    Seconds after the cut ends. `recover` needs enough of these to re-ignite from cold, which it does
    in about five minutes on the plasma left in its box even with its fuel line still dead.

.PARAMETER Thin
    What fraction of its capacity `boundary`'s one charge fills. The default sits below the density at
    which a D-T plasma carries itself, which is the whole point of the cell; raising it past that turns
    the drain into a gain and the cell says so rather than passing quietly.

.PARAMETER Report
    Write a markdown report of this run, with graphs, to this path. The graphs are SVG files in a
    directory beside it named after the file, and both are OVERWRITTEN wholesale every run: the report
    is a rendering of one rig run and not a document to edit. It is drawn from the same trace the
    checks are computed from, so the graphs and the verdict cannot drift apart.

    Nothing is written unless this is passed, so the check stays a check by default.

.PARAMETER With
    Bundled mods to enable, e.g. -With space-age. Off by default, so the rig keeps measuring base 2.0
    unless asked otherwise (ADR 0003, ADR 0008).

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/check-brownout.ps1
    pwsh -File scripts/check-brownout.ps1 -Cut 1200 -KeepTemp
    pwsh -File scripts/check-brownout.ps1 -Report docs/research/brownout-rig.md
#>
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [ValidateRange(60, 3600)]  [int]    $Settle  = 1800,
    [ValidateRange(60, 3600)]  [int]    $Cut     = 900,
    [ValidateRange(60, 1800)]  [int]    $Restore = 300,
    [ValidateRange(0.005, 0.5)][double] $Thin    = 0.025,
    [string[]] $With = @(),
    [string] $Report,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = @('RealisticFusionCore', 'RealisticFusion')
$rigName  = 'rf-brownout-rig'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe
try {
    $enabledBundled = Resolve-BundledSelection -Requested $With -Bundled $bundled
}
catch { throw "-With $($_.Exception.Message)" }

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-brown-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

$settleTicks  = $Settle  * 60
$cutTicks     = $Cut     * 60
$restoreTicks = $Restore * 60
$totalTicks   = $settleTicks + $cutTicks + $restoreTicks

function Write-Rig {
    @{
        name = $rigName; version = '0.0.1'; title = 'Brownout and blackout check'
        author = 'check-brownout.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'RealisticFusion', 'RealisticFusionCore')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

    $feed = Write-PlasmaFeed -RigDirectory $rigDir

    $lua = @'
-- Generated by scripts/check-brownout.ps1. Nothing here ships.

local SETTLE  = __SETTLE__
local CUT     = __CUT__
local RESTORE = __RESTORE__
local THIN    = __THIN__
local FEED    = "__PLASMAFEED__"

local DD, DT     = "rf-d-d-plasma", "rf-d-t-plasma"
local MIX, DEUT  = "rf-d-t-mix", "rf-deuterium"
local ENERGY     = "rf-reactor-energy"
local EXCHANGER  = "rf-hc-exchanger"
local TURBINE    = "rf-hc-turbine"

-- Supply a satisfied cell runs on: about ten times what one can draw, so "full" means satisfied
-- rather than nearly satisfied and no cell's baseline is itself a mild brownout.
local FULL_W = 500e6

-- The plant cell's load bank, before and after the overload. 40 MW leaves headroom under two
-- rf-hc-turbines' 116.4 MW once the cell's own 55 MW is paid; 200 MW is comfortably past what the
-- plant can make, which is the point of it.
local LOAD_W, OVERLOAD_W = 40e6, 200e6

-- The phases. Sampled one tick AFTER the boundary rather than on it: control.lua steps the
-- simulation every six ticks, so a reading taken on the beat can land mid-step, and one taken just
-- after it is always the state a completed step left behind.
local LIT     = SETTLE + 1
-- A minute into the shortfall, or the end of it if the caller asked for a shorter one. Clamped
-- rather than assumed: with -Cut 60 an unclamped "early" would land after "deep", and the window
-- the first claim is measured over would silently be the wrong one.
local EARLY   = SETTLE + math.min(3600, CUT) + 1
local DEEP    = SETTLE + CUT + 1
local BACK    = SETTLE + CUT + RESTORE + 1
local PHASES  = { "lit", "early", "deep", "back" }
local AT      = { lit = LIT, early = EARLY, deep = DEEP, back = BACK }
-- The report runs a tick after the last sample rather than on it. on_tick and on_nth_tick are
-- separate schedulers and their order within one tick is not something to rest a rig on; a tick
-- later the sample has certainly been taken.
local REPORT  = BACK + 1
-- How often cumulative output is traced. Ten seconds is fine enough to see a decay and coarse
-- enough that eight cells of it stay small in storage.
local TRACE_EVERY = 600

-- Results live in storage rather than in upvalues: on_init runs under --create and the check tick
-- runs in a later load of that save, so anything held in a local is gone by the time it is read.
-- check-d-t.ps1 carries the same note, having found it out the same way.
local function record(ok, name, detail)
  storage.report = storage.report or { lines = {}, failures = 0, checks = 0 }
  storage.report.checks = storage.report.checks + 1
  if not ok then storage.report.failures = storage.report.failures + 1 end
  storage.report.lines[#storage.report.lines + 1] = string.format("%s  %s%s",
    ok and "ok  " or "FAIL", name, detail and ("  -- " .. detail) or "")
end

-- A measurement that is reported and not asserted. Every number this rig produces goes through here
-- or through record's detail, so a rebalance shows up as a figure moving rather than as a check that
-- still passes.
local function note(name, detail)
  storage.report = storage.report or { lines = {}, failures = 0, checks = 0 }
  storage.report.lines[#storage.report.lines + 1] = string.format("--    %s  %s", name, detail)
end

local function must(entity, what)
  if not entity then error(what .. " refused") end
  return entity
end

local STATUS = {}
for name, value in pairs(defines.entity_status) do STATUS[value] = name end
local function status_name(v) return STATUS[v] or ("?" .. tostring(v)) end

local function box_of(entity, fluid)
  for index = 1, #entity.fluidbox do
    local filter = entity.fluidbox.get_filter(index)
    if filter and filter.name == fluid then return index end
  end
  return nil
end

-- ---------------------------------------------------------------- units
--
-- Joules per tick, not watts. See the DESCRIPTION; the check that pins it is in on_init.
local function watts(w) return w / 60 end

-- ---------------------------------------------------------------- geometry
--
-- Carried from scripts/check-pooling.ps1, which carried it from bench-reactors.ps1, and for the
-- reason both give: an odd-sized entity centres on a tile centre and an even one on a boundary, and
-- placing either off its own parity puts it half a tile out with nothing erroring. #49 is what that
-- costs when it happens.
local function reactor_footprint()
  local box  = prototypes.entity["rf-reactor"].selection_box
  local size = math.floor(box.right_bottom.x - box.left_top.x + 0.5)
  return size, (size % 2 == 1) and 0.5 or 0.0
end

local function centre(v, origin)
  if origin == 0.5 then return math.floor(v) + 0.5 else return math.floor(v + 0.5) end
end

--- The extreme connection of an entity's fluid box `index`, along one axis.
local function edge_connection(entity, index, pick)
  local conns = entity.fluidbox.get_pipe_connections(index)
  if not conns or #conns == 0 then error(entity.name .. " has no connections on box " .. index) end
  local best = conns[1].target_position
  for _, c in ipairs(conns) do if pick(c.target_position, best) then best = c.target_position end end
  return best
end

local WESTMOST = function(a, b) return a.x < b.x end
local EASTMOST = function(a, b) return a.x > b.x end

--- A run of pipe along axis-aligned legs through `points`, laid inclusively.
---
--- Legs rather than a straight line because a heater's plasma outlet and a reactor's plasma inlet are
--- not on the same row, and an L guessed at from the two positions is exactly the invented geometry
--- the other rigs' notes refuse to do. The caller names the corridor; this only fills it.
local function route(surface, force, name, points, label)
  local laid = {}
  local function put(x, y)
    laid[#laid + 1] = must(surface.create_entity({
      name = name, position = { x, y }, force = force,
    }), string.format("%s: %s at (%g, %g)", label, name, x, y))
  end
  put(points[1].x, points[1].y)
  local x, y = points[1].x, points[1].y
  for i = 2, #points do
    local to = points[i]
    if to.x ~= x and to.y ~= y then
      error(string.format("%s: leg %d is not axis-aligned", label, i))
    end
    -- A leg walks one whole tile at a time, so its two ends have to sit on the same half of the
    -- grid or the walk steps straight past its target and runs for ever. Checked rather than
    -- assumed: everything here is placed off an entity's own connection geometry, and the parity
    -- that comes back depends on whether that entity's footprint is odd or even (#49).
    if (to.x - x) % 1 ~= 0 or (to.y - y) % 1 ~= 0 then
      error(string.format("%s: leg %d runs between tile halves -- (%g, %g) to (%g, %g)",
        label, i, x, y, to.x, to.y))
    end
    while x ~= to.x do x = x + (to.x > x and 1 or -1); put(x, y) end
    while y ~= to.y do y = y + (to.y > y and 1 or -1); put(x, y) end
  end
  return laid
end

--- Infinity pipes on every connection of one fluid box, the way check-hc.ps1 feeds its exchangers.
--- `index` may be given for a box that cannot be found by filter. A reactor's plasma box is the
--- case: #28 removed its filter so that one reactor burns whichever plasma is plumbed to it, which
--- is exactly what makes it unfindable by the fluid it takes.
local function feed(surface, force, entity, fluid, temperature, percentage, mode, label, index)
  index = index or box_of(entity, fluid)
  if not index then error(label .. ": " .. entity.name .. " has no box that takes " .. fluid) end
  local pipes = {}
  for _, connection in pairs(entity.fluidbox.get_pipe_connections(index)) do
    local pipe = must(surface.create_entity({
      -- The plasma set carries its own connection category (#26), so a vanilla infinity pipe cannot
      -- reach a plasma box at all. Write-PlasmaFeed exists for exactly that and FEED is its output.
      name = (fluid == DD or fluid == DT) and FEED or "infinity-pipe",
      position = connection.target_position, force = force,
    }), label .. ": supply of " .. fluid)
    pipe.set_infinity_pipe_filter({
      name = fluid, percentage = percentage or 1, temperature = temperature,
      mode = mode or "at-least",
    })
    pipes[#pipes + 1] = pipe
  end
  return index, pipes
end

--- Substations along a cell, every fourteen tiles, plus the interfaces on them.
---
--- Fourteen because a substation's wire reaches eighteen and its supply area is eighteen square, so
--- this both chains and covers without a gap. That they landed on ONE network is asserted here rather
--- than inferred later from an entity turning out to be powered: two entities on one network is the
--- thing being built, and asserting it where it is built names the culprit if it breaks.
local function grid(surface, force, label, xs, ys)
  local poles = {}
  for _, y in ipairs(ys) do
    for _, x in ipairs(xs) do
      poles[#poles + 1] = must(surface.create_entity({
        name = "substation", position = { x, y }, force = force,
      }), string.format("%s: substation at (%g, %g)", label, x, y))
    end
  end
  for i = 2, #poles do
    if poles[i].electric_network_id ~= poles[1].electric_network_id then
      error(string.format("%s: substation %d is on its own network, not the cell's", label, i))
    end
  end
  return poles
end

local function interface(surface, force, poles, at, production_w, usage_w, label)
  local eei = must(surface.create_entity({
    name = "electric-energy-interface", position = at, force = force,
  }), label .. ": interface")
  -- THE BUFFER HAS TO GO, and this is the single thing most likely to be got wrong in this rig.
  --
  -- Vanilla's electric-energy-interface ships an enormous electric buffer -- it is the editor's
  -- infinite power source, and the buffer is how it also works as an infinite sink. Setting
  -- power_production to zero therefore does not cut anything: the interface goes on discharging that
  -- buffer into the network as a tertiary source for minutes. The first run of this rig did exactly
  -- that, and every cut cell's readings came out identical to the uncut one, which looked like the
  -- physics being insensitive to power rather than like a battery nobody had noticed.
  --
  -- A fifth of a second of reserve at what a cell draws, so it cannot stand in for a supply. Production
  -- is added to the network each tick and does not come out of this, which the full cell's
  -- "not low_power" check confirms rather than assumes.
  eei.electric_buffer_size = 10e6
  eei.power_production     = watts(production_w or 0)
  eei.power_usage          = watts(usage_w or 0)
  if eei.electric_network_id ~= poles[1].electric_network_id then
    error(string.format("%s: the interface at (%g, %g) is not on the cell's network",
      label, at[1], at[2]))
  end
  return eei
end

-- ---------------------------------------------------------------- a cell
--
-- One reactor (or a bridged row of them), its heater, and the plasma pipe between them, on one
-- network. Everything is placed in the cell's own frame off `ox` and `oy` so the eight cells are the
-- same build in different places rather than eight builds.
--
--   ox+4    the corridor the plasma pipe runs north in, west of everything else
--   ox+10   the heater, south of the reactor row and clear of the substations
--   ox+14+  the substations, and the interfaces on them
--   ox+20+  the reactor row, pitched by its own footprint plus five
local function build_cell(surface, force, o)
  local size, origin = reactor_footprint()
  local cy    = centre(o.oy, origin)
  local label = o.label
  local cell  = { label = label, reactors = {}, sold = 0, drain = o.drain ~= false }

  for i = 0, (o.count or 1) - 1 do
    local cx = centre(o.ox + 20 + i * (size + 5), origin)
    local reactor = must(surface.create_entity({
      -- raise_built so RealisticFusion registers it: the mod picks reactors up from the build event
      -- and rescans only at its own on_init, which has already run by now.
      name = "rf-reactor", position = { cx, cy }, force = force, raise_built = true,
    }), label .. ": rf-reactor " .. i)
    cell.reactors[#cell.reactors + 1] = reactor
    if i > 0 then
      -- One plasma pool across the row, through the engine's own fluid system and nothing this rig
      -- computes -- which is ADR 0011's mechanism and the thing the pooled cell is for.
      route(surface, force, "rf-pipe", {
        edge_connection(cell.reactors[i], 1, EASTMOST),
        edge_connection(reactor, 1, WESTMOST),
      }, label .. ": bridge")
    end
  end

  local first = cell.reactors[1]
  local last  = cell.reactors[#cell.reactors]
  cell.energy_index = box_of(first, ENERGY)
  if not cell.energy_index then error(label .. ": the reactor has no reactor-energy box") end

  -- The substation columns: from ox+14 east far enough to cover the whole row, and for the plant
  -- cell also north far enough to cover its turbines. Fourteen apart on both axes.
  local xs, x = {}, math.floor(o.ox + 14)
  local east = last.position.x + size / 2 + 2
  while x <= east do xs[#xs + 1] = x; x = x + 14 end
  local ys = { math.floor(cy) + 11 }
  if o.tall then
    local y = ys[1] - 14
    while y > cy - 40 do ys[#ys + 1] = y; y = y - 14 end
  end
  cell.poles = grid(surface, force, label, xs, ys)

  if o.seed then
    -- boundary: no heater, no feed line, nothing upstream at all. Its charge arrives once, at the
    -- cut tick, from the on_tick handler -- see the note there for why it cannot be a pipe.
    cell.seed = o.seed
  else
    -- The heater, and the corridor from its plasma outlet to the reactor row's west face.
    --
    -- Its outlet is chosen as the westmost of the box's connections so that the first leg walks AWAY
    -- from the machine: a connection target already sits one tile outside the footprint, so walking
    -- west from the westmost one cannot re-enter it, whichever face it is on.
    local heater = must(surface.create_entity({
      name = "rf-heater", position = { centre(o.ox + 10, 0.5), cy + 16 }, force = force,
    }), label .. ": rf-heater")
    heater.set_recipe(o.plasma)
    cell.heater = heater
    feed(surface, force, heater, o.feedstock, nil, 1, "at-least", label)

    local outlet = edge_connection(heater, box_of(heater, o.plasma), WESTMOST)
    if outlet.x > heater.position.x then
      error(label .. ": the heater's only plasma outlet faces east, and the corridor is west")
    end
    local inlet = edge_connection(first, 1, WESTMOST)
    -- The corridor takes its half-tile from the outlet it starts at, so the first leg can reach it;
    -- route() asserts the rest of the path agrees.
    local corridor = math.floor(o.ox + 4) + (outlet.x % 1)
    local line = route(surface, force, "rf-pipe", {
      outlet,
      { x = corridor, y = outlet.y },
      { x = corridor, y = inlet.y },
      inlet,
    }, label .. ": feed line")

    -- That the feed line really did reach the reactor. Without this the rig's failure mode is a
    -- reactor reporting itself starved on a cell whose pipe run missed by a tile, which reads
    -- exactly like a broken mod -- and is the mistake check-d-t.ps1's own notes were written about.
    --
    -- Asked of the PIPE at the heater's outlet rather than of the heater's own box, because the
    -- heater's plasma box is declared "output" and only an input-output box joins the segment it is
    -- plumbed to -- so the heater has no segment to ask (#47, ADR 0011; check-breeding.ps1 carries
    -- the same finding about the collector's boxes). The heater's connection into that pipe is
    -- checked separately, since a pipe run reaching the reactor says nothing about its far end.
    local from = line[1].fluidbox.get_fluid_segment_id(1)
    local to   = first.fluidbox.get_fluid_segment_id(1)
    if from == nil or from ~= to then
      error(string.format("%s: the feed line and the reactor are on segments %s and %s",
        label, tostring(from), tostring(to)))
    end
    if #heater.fluidbox.get_connections(box_of(heater, o.plasma)) == 0 then
      error(label .. ": the heater's plasma outlet is not connected to the feed line")
    end
  end

  -- ------------------------------------------------------------------ the plant's steam route
  --
  -- Positions computed from each prototype's own connection geometry rather than written down, and
  -- they come out adjacent: the reactor's energy outlet, the exchanger's fuel inlet, its steam
  -- outlet and both turbines' inlets chain face to face with no pipe between them. If any of that is
  -- wrong the turbine simply gets no steam, and the check at the end says so.
  if o.plant then
    local ry = first.position.y
    local ex = must(surface.create_entity({
      name = EXCHANGER, position = { first.position.x, ry - 11 }, force = force,
    }), label .. ": " .. EXCHANGER)
    feed(surface, force, ex, "water", nil, 1, "at-least", label)
    cell.exchanger = ex
    cell.turbines = {}
    for i = 1, 2 do
      cell.turbines[i] = must(surface.create_entity({
        name = TURBINE, position = { first.position.x, ry - 18 - (i - 1) * 7 }, force = force,
      }), string.format("%s: %s %d", label, TURBINE, i))
    end
    for i, turbine in ipairs(cell.turbines) do
      if turbine.electric_network_id ~= cell.poles[1].electric_network_id then
        error(string.format("%s: turbine %d is not on the cell's network", label, i))
      end
    end
  end

  -- The supply, and for the plant cell a load bank beside it. Both on the westmost substation, which
  -- every cell has: a 1x1 entity centres on a tile centre where a 2x2 centres on a boundary, so the
  -- interface wants halves off the substation's whole numbers.
  cell.supply = interface(surface, force, cell.poles,
    { cell.poles[1].position.x + 2.5, cell.poles[1].position.y + 0.5 }, FULL_W, 0, label)
  if o.plant then
    cell.load = interface(surface, force, cell.poles,
      { cell.poles[1].position.x + 4.5, cell.poles[1].position.y + 0.5 }, 0, LOAD_W, label)
  end

  cell.cut = o.cut
  return cell
end

-- ---------------------------------------------------------------- sampling

local WATCH = { "rf-reactor", "rf-heater", TURBINE, "electric-energy-interface" }

-- Zero rather than nil for a prototype the cell does not contain: boundary has no heater and only
-- plant has turbines, and every caller here sums across cells.
local function flows(pole)
  local stats, out = pole.electric_network_statistics, {}
  for _, name in ipairs(WATCH) do
    out[name] = {
      input  = stats.get_input_count(name)  or 0,
      output = stats.get_output_count(name) or 0,
    }
  end
  return out
end

--- Every entity a cell is measured through, checked before it is measured through.
---
--- Without this the failure mode is a stack trace inside flows() naming a substation index, which
--- says nothing about the cause; with it the rig names the cell and says what happened. Cheap enough
--- to run every tick: a handful of validity reads against eight cells.
local function assert_intact(cell)
  if not cell.poles[1].valid then
    error(cell.label .. ": its substation is gone -- something destroyed part of the rig mid-run")
  end
  for i, reactor in ipairs(cell.reactors) do
    if not reactor.valid then
      error(string.format("%s: reactor %d is gone -- something destroyed part of the rig mid-run",
        cell.label, i))
    end
  end
  if cell.heater and not cell.heater.valid then
    error(cell.label .. ": its heater is gone -- something destroyed part of the rig mid-run")
  end
end

local function sample(cell)
  local s = { sold = cell.sold, flows = flows(cell.poles[1]), plasma = {}, buffer = {}, status = {} }
  for i, reactor in ipairs(cell.reactors) do
    local box = reactor.fluidbox[1]
    s.plasma[i]  = box and { amount = box.amount, temperature = box.temperature, name = box.name } or nil
    s.buffer[i]  = reactor.energy
    s.status[i]  = status_name(reactor.status)
  end
  if cell.heater  then s.heater  = status_name(cell.heater.status) end
  if cell.turbines then s.turbine = status_name(cell.turbines[1].status) end
  if cell.load    then s.load    = cell.load.power_usage * 60 end
  -- What the cell is actually being supplied at the moment of the reading. Sampled rather than
  -- assumed from the schedule: the first version of this rig scheduled cuts that never landed, and
  -- every cell's numbers came out identical to the uncut one with nothing to say why.
  s.supply = cell.supply.power_production * 60
  return s
end

-- ---------------------------------------------------------------- the map

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player

  -- Pins the joules-per-tick convention every supply figure in this rig rests on. Against vanilla's
  -- own turbine rather than against a number written here, and as a band rather than a value, so a
  -- vanilla rebalance moves the detail and not the verdict.
  local turbine_w = prototypes.entity["steam-turbine"].get_max_power_output() * 60
  record(turbine_w > 1e6 and turbine_w < 1e8,
    "engine power figures are joules per tick, so watts convert by sixty",
    string.format("vanilla steam-turbine reads %.4g MW that way", turbine_w / 1e6))

  -- LONG RUNS GET ATTACKED, and no other rig here is long enough to have found that out. The siblings
  -- run two minutes; this one runs half an hour, and a probe run at fifty minutes died with "LuaEntity
  -- API call when LuaEntity was invalid" inside flows() -- a cell's substation had been eaten. Eight
  -- heaters and an exchanger produce the pollution that buys that attention.
  --
  -- Turned off at the source rather than defended against: a rig measuring a power balance has no
  -- business also being a defence exercise, and a cell that loses a substation mid-run produces a
  -- reading that looks like physics.
  game.map_settings.pollution.enabled        = false
  game.map_settings.enemy_expansion.enabled  = false
  surface.peaceful_mode = true
  local nests = surface.find_entities_filtered({ force = "enemy" })
  for _, nest in pairs(nests) do nest.destroy() end
  record(true, "the map is stopped from fighting back, so a long run measures the reactor",
    string.format("pollution and expansion off, peaceful, %d enemy entities removed", #nests))

  force.research_all_technologies()

  surface.request_to_generate_chunks({ 175, 20 }, 9)
  surface.force_generate_chunk_requests()
  local tiles = {}
  for x = -25, 375 do
    for y = -45, 95 do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = { { -25, -45 }, { 375, 95 } } })) do
    if e.type ~= "character" then e.destroy() end
  end

  -- Four columns a hundred apart, two rows sixty apart. The pitch is what keeps the cells
  -- independent: a substation reaches eighteen tiles, so no cell's grid can see its neighbour's, and
  -- no cell's pipe run can touch another's. Both are asserted below rather than left to the layout.
  --
  -- plant is in the top row because it is the only cell that builds northward, and there is nothing
  -- above it to collide with.
  local plan = {
    { label = "plant",    ox =   0, oy =  0.5, plasma = DT, feedstock = MIX,  plant = true, tall = true,
      drain = false, cut = "starter" },
    { label = "full",     ox = 100, oy =  0.5, plasma = DT, feedstock = MIX,  cut = "none" },
    { label = "half",     ox = 200, oy =  0.5, plasma = DT, feedstock = MIX,  cut = "half" },
    { label = "dark",     ox = 300, oy =  0.5, plasma = DT, feedstock = MIX,  cut = "zero" },
    { label = "recover",  ox =   0, oy = 60.5, plasma = DT, feedstock = MIX,  cut = "zero", restore = true },
    { label = "boundary", ox = 100, oy = 60.5, plasma = DT, seed = DT, cut = "none" },
    { label = "dd",       ox = 200, oy = 60.5, plasma = DD, feedstock = DEUT, cut = "zero" },
    { label = "pooled",   ox = 300, oy = 60.5, plasma = DT, feedstock = MIX,  cut = "zero", count = 2 },
  }

  local cells, order = {}, {}
  for _, spec in ipairs(plan) do
    local cell = build_cell(surface, force, spec)
    cell.restore = spec.restore
    cells[spec.label] = cell
    order[#order + 1] = spec.label
  end

  -- Eight networks, not one. If two cells shared a network every cut in this rig would be applied to
  -- both, and the failures would look like physics.
  local seen = {}
  for _, label in ipairs(order) do
    local id = cells[label].poles[1].electric_network_id
    if seen[id] then error(label .. " shares an electric network with " .. seen[id]) end
    seen[id] = label
  end
  record(true, "the eight cells are on eight independent electric networks",
    string.format("%d distinct network ids", #order))

  storage.cells = cells
  storage.order = order
  storage.snaps = {}
  -- The scale the flow-statistics calibration is checked against, off the reactor's own prototype
  -- rather than off reactor-logic.lua's heating_power_w, which a rig cannot see.
  --
  -- get_input_flow_limit() and not an input_flow_limit attribute: the flow limits are the two
  -- MEMBERS of LuaElectricEnergySourcePrototype that are methods rather than fields, because they
  -- take a quality. control.lua reads buffer_capacity off the same class as a field, which is what
  -- made the wrong one look right.
  storage.appetite_w =
    prototypes.entity["rf-reactor"].electric_energy_source_prototype.get_input_flow_limit() * 60
  log("BROWNOUT-RIG built")
end)

-- ---------------------------------------------------------------- the run

script.on_event(defines.events.on_tick, function()
  local cells = storage.cells
  if not cells then return end
  local tick = game.tick

  -- Drain the reactors' energy boxes and keep the running total, which is what the open-loop cells
  -- are measured on: a box holds 1000 units and fills in under a second, so an end-of-run reading
  -- compares saturated buffers and reports every cell identical. One unit is one megajoule.
  --
  -- Draining is also what an exchanger does, so this measures the reactor rather than perturbing it
  -- -- which is why the plant cell, where a real exchanger is doing it, is exempt.
  for _, label in ipairs(storage.order) do
    local cell = cells[label]
    assert_intact(cell)
    if cell.drain then
      local moved = 0
      for _, reactor in ipairs(cell.reactors) do
        local produced = reactor.fluidbox[cell.energy_index]
        if produced then
          moved = moved + produced.amount
          reactor.fluidbox[cell.energy_index] = nil
        end
      end
      cell.sold = cell.sold + moved
    end
  end

  -- A coarse trace of cumulative output, because "when did it stop selling" turns out not to be a
  -- question with an answer: a reactor holding plasma sells the loss out of that plasma whether or
  -- not any fusion is happening, so the output decays towards nothing and never reaches it. The rig
  -- asked the binary question first and every cell answered "still selling", which was true and
  -- useless. A curve can be asked whether it is decaying and how fast, which is the real question.
  if tick % TRACE_EVERY == 0 then
    for _, label in ipairs(storage.order) do
      local cell = cells[label]
      local box  = cell.reactors[1].fluidbox[1]
      local f    = flows(cell.poles[1])
      cell.trace = cell.trace or {}
      -- Both flow categories, because which of them is consumption is not known until the report
      -- calibrates it -- and the trace is written long before that.
      cell.trace[#cell.trace + 1] = {
        tick = tick, sold = cell.sold,
        t = box and box.temperature or 0, u = box and box.amount or 0,
        din  = f["rf-reactor"].input  + f["rf-heater"].input,
        dout = f["rf-reactor"].output + f["rf-heater"].output,
        -- The turbines, for the plant cell only. Its reactor's output is drunk by a real exchanger
        -- rather than drained into a counter, so what it sells has to be read where it lands.
        gin  = f[TURBINE].input,
        gout = f[TURBINE].output,
      }
    end
  end

  if tick == SETTLE then
    for _, label in ipairs(storage.order) do
      local cell = cells[label]
      if cell.cut == "zero" then
        cell.supply.power_production = 0
        -- And what it had already stored, or the cut is only a cut once that has drained away.
        cell.supply.energy = 0
      elseif cell.cut == "half" then
        -- Half of what the cell was measured to draw while it was satisfied, rather than half of a
        -- figure written here. The draw is read out of the same statistics the report uses, so if
        -- the orientation check at the end fails this number is wrong too and says so.
        local f = flows(cell.poles[1])
        local drawn = math.max(f["rf-reactor"].input, f["rf-reactor"].output)
                    + math.max(f["rf-heater"].input,  f["rf-heater"].output)
        cell.half_w = drawn / (SETTLE / 60) / 2
        cell.supply.power_production = watts(cell.half_w)
      elseif cell.cut == "starter" then
        -- The plant loses its starter motor and nothing else. From here it pays for its own
        -- confinement heating out of what that heating produced.
        cell.supply.power_production = 0
        cell.supply.energy = 0
      end
      -- boundary is seeded here rather than fed, because there is no way to hold a plasma segment
      -- thin with an infinity pipe without also flushing it with cold fluid for ever: a pipe that
      -- pins a fill has to inject at some temperature, and the only ones available are the
      -- injection temperature or the fluid's default. Both are far below fusion, so the cell would
      -- measure a reactor being hosed with cold gas rather than one that is merely thin, and the
      -- drain it reported would be that hosing. Seeded and then left alone is what
      -- scripts/check-pooling.ps1 does, for the same reason.
      if cell.seed then
        local reactor = cell.reactors[1]
        reactor.fluidbox[1] = {
          name = cell.seed, temperature = 1e6,
          amount = reactor.fluidbox.get_capacity(1) * THIN,
        }
      end
    end
  end

  if tick == SETTLE + CUT then
    for _, label in ipairs(storage.order) do
      local cell = cells[label]
      if cell.restore then cell.supply.power_production = watts(FULL_W) end
      -- The spiral, made to happen on purpose: more load than the plant can carry, with no starter
      -- left to make up the difference.
      if cell.load then cell.load.power_usage = watts(OVERLOAD_W) end
    end
  end

  for _, phase in ipairs(PHASES) do
    if tick == AT[phase] then
      storage.snaps[phase] = {}
      for _, label in ipairs(storage.order) do
        storage.snaps[phase][label] = sample(cells[label])
      end
    end
  end
end)

-- ---------------------------------------------------------------- the report

script.on_nth_tick(REPORT, function()
  if game.tick == 0 or storage.done then return end
  storage.done = true
  local cells, snaps = storage.cells, storage.snaps

  for _, phase in ipairs(PHASES) do
    if not snaps[phase] then error("the run never reached the " .. phase .. " sample") end
  end

  -- ------------------------------------------------------------ which category is consumption
  --
  -- Derived, not assumed. Over the settle phase every cell is satisfied and every reactor spends its
  -- full confinement heating, so the reactor's consumption has to land within a factor of three of
  -- its own declared input_flow_limit. Whichever category does that is consumption; if neither does,
  -- every net figure below would be nonsense and the rig says so instead of printing them.
  local seconds = SETTLE / 60
  local base    = snaps.lit.full
  local expect  = storage.appetite_w * seconds
  local consume
  for _, category in ipairs({ "input", "output" }) do
    local drawn = base.flows["rf-reactor"][category]
    if drawn > expect / 3 and drawn < expect * 3 then consume = category end
  end
  record(consume ~= nil,
    "an electric network's consumption is readable, and which category holds it is derived",
    consume and string.format("%s; a satisfied reactor drew %.4g MJ in %ds against an appetite of %.4g MJ",
      consume, base.flows["rf-reactor"][consume] / 1e6, seconds, expect / 1e6)
      or string.format("neither category is within 3x of %.4g MJ", expect / 1e6))
  if not consume then
    local report = storage.report
    report.lines[#report.lines + 1] = "FAIL: the flow statistics could not be calibrated"
    for _, line in ipairs(report.lines) do log("BROWNOUT-RIG " .. line) end
    return
  end

  --- Megajoules a cell drew, and sold, between two phases.
  local function span(label, from, to)
    local a, b = snaps[from][label], snaps[to][label]
    local drawn = 0
    for _, name in ipairs({ "rf-reactor", "rf-heater" }) do
      drawn = drawn + (b.flows[name][consume] - a.flows[name][consume])
    end
    return (b.sold - a.sold), drawn / 1e6
  end

  local function mw(mj, ticks) return mj / (ticks / 60) end

  --- Output rate, in megawatts, between two ticks, off the trace.
  ---
  --- Bracketing rather than interpolating: the trace is every ten seconds and every window asked of
  --- it here is minutes long, so the error is a rounding one and stating it beats hiding it behind
  --- arithmetic that looks exact.
  local function rate_mw(cell, from_tick, to_tick)
    local a, b
    for _, e in ipairs(cell.trace or {}) do
      if e.tick <= from_tick then a = e end
      if e.tick <= to_tick   then b = e end
    end
    if not a or not b or b.tick <= a.tick then return nil end
    return mw(b.sold - a.sold, b.tick - a.tick)
  end

  --- What fraction of its lit output a cell was still making at the end of the shortfall.
  ---
  --- The reference is the last minute of the settle phase and not the whole of it, because the whole
  --- of it includes a cold start and would understate what the reactor had got to.
  local function faded_to(cell)
    local lit_mw  = rate_mw(cell, SETTLE - 3600, SETTLE)
    local end_mw  = rate_mw(cell, SETTLE + CUT - math.min(3600, CUT), SETTLE + CUT)
    if not lit_mw or not end_mw or lit_mw <= 0 then return nil, lit_mw, end_mw end
    return end_mw / lit_mw, lit_mw, end_mw
  end

  local function describe(label)
    local cell = cells[label]
    for _, phase in ipairs(PHASES) do
      local s = snaps[phase][label]
      local parts = {}
      for i, p in ipairs(s.plasma) do
        parts[#parts + 1] = string.format("%s %.4g u at %.4g C", p.name, p.amount, p.temperature)
        if i == 1 then parts[#parts] = parts[#parts] .. string.format(" (buffer %.3g MJ)", s.buffer[i] / 1e6) end
      end
      if #s.plasma == 0 then parts[#parts + 1] = "no plasma" end
      parts[#parts + 1] = string.format("supply %.4g MW", (s.supply or 0) / 1e6)
      parts[#parts + 1] = "reactor " .. table.concat(s.status, "/")
      if s.heater  then parts[#parts + 1] = "heater " .. s.heater end
      if s.turbine then parts[#parts + 1] = "turbine " .. s.turbine end
      if s.load    then parts[#parts + 1] = string.format("load %.4g MW", s.load / 1e6) end
      note(string.format("%-9s %-6s", label, phase), table.concat(parts, ", "))
    end
    if cell.drain then
      local sold, drawn = span(label, "lit", "deep")
      note(string.format("%-9s %-6s", label, "cut"), string.format(
        "sold %.4g MJ, drew %.4g MJ, net %+.4g MJ (%+.4g MW over %ds)",
        sold, drawn, sold - drawn, mw(sold - drawn, CUT), CUT / 60))
    end
    if cell.drain then
      local kept, was, now = faded_to(cell)
      if kept then
        -- The drift is what says whether `was` is a settled figure or a point on the way up. Reported
        -- per cell rather than only asserted on `full`, because `full` is the only cell the assertion
        -- covers and a reader comparing two cells should be able to see which of them had stopped
        -- moving.
        local before = rate_mw(cell, SETTLE - 7200, SETTLE - 3600)
        local drift  = (before and was and was > 0) and (100 * (was - before) / was) or nil
        note(string.format("%-9s %-6s", label, "rate"), string.format(
          "%.4g MW over the last minute lit%s, %.4g MW over the last minute of the shortfall (%.2f%%)",
          was, drift and string.format(" (drifting %+.2f%%/min)", drift) or "", now, 100 * kept))
      end
    end
  end
  for _, label in ipairs(storage.order) do describe(label) end

  local clamp = prototypes.fluid[DT].max_temperature

  -- ------------------------------------------------------------ full: the baseline
  local lit = snaps.lit.full.plasma[1]
  record(lit ~= nil and lit.temperature >= clamp * 0.999,
    "full: a heater-fed D-T reactor ignites and parks at the top of its range",
    lit and string.format("%.4g C against a ceiling of %.4g", lit.temperature, clamp) or "no plasma")
  local sold, drawn = span("full", "lit", "deep")
  record(sold > drawn, "full: and pays for its own confinement heating many times over",
    string.format("%.4g MJ sold against %.4g MJ drawn, %.2fx", sold, drawn, sold / math.max(drawn, 1)))
  -- That the shortfall reached the consumers at all, which is the one thing this rig cannot afford to
  -- get wrong and did get wrong once: a vanilla electric-energy-interface carries an enormous buffer,
  -- and until it was cut down every "cut" cell went on running off it and reported numbers identical
  -- to the uncut one. Three cells drawing three different amounts is the evidence that the supply
  -- figure is the thing deciding what they get.
  --
  -- Asked of the draw and not of entity_status on purpose: a reactor spends a whole interval's
  -- heating out of its buffer in one go, so its status flickers through low_power on a network with
  -- power to spare, and reading it at one instant says nothing about supply.
  -- THE BASELINE HAS TO HAVE STOPPED MOVING, and this is the check that says so rather than
  -- .PARAMETER Settle's prose claiming it. Every "kept X%" figure in this rig divides by the full
  -- cell's last minute of settle, so a settle that ended while the reactor was still climbing makes
  -- every one of those percentages a ratio to a number on the way up. It did, at the 300 s this rig
  -- first used: the full cell went on to more than treble that reading. One percent a minute is a
  -- loose bound on purpose -- it is here to catch a settle that is wrong by minutes, not to pin a
  -- convergence figure that moves with the balance.
  local before_mw = rate_mw(cells.full, SETTLE - 7200, SETTLE - 3600)
  local lit_mw    = rate_mw(cells.full, SETTLE - 3600, SETTLE)
  record(before_mw ~= nil and lit_mw ~= nil and lit_mw > 0
      and math.abs(lit_mw - before_mw) < lit_mw * 0.01,
    "full: and its output had stopped climbing before the shortfall, so the baseline is settled",
    (before_mw and lit_mw and lit_mw > 0) and string.format(
      "%.4g MW over the minute before last against %.4g MW over the last, %+.2f%% -- raise -Settle if this fails",
      before_mw, lit_mw, 100 * (lit_mw - before_mw) / lit_mw)
      or string.format("the %ds settle is too short to compare two minutes", SETTLE / 60))

  local half_sold, half_drawn = span("half", "lit", "deep")
  local dark_sold, dark_drawn = span("dark", "lit", "deep")
  record(drawn > half_drawn * 1.5 and half_drawn > dark_drawn,
    "full: and the shortfall is graded, so the supply figure is what decides what a cell gets",
    string.format("full drew %.4g MW, half %.4g MW, blackout %.4g MW",
      mw(drawn, CUT), mw(half_drawn, CUT), mw(dark_drawn, CUT)))

  -- ------------------------------------------------------------ 1. lit is never a drain
  --
  -- The first of the three claims #70 was decided on, and the one the ticket's premise denies. Read
  -- across the shortfall rather than at the end of it, because the premise is about what happens
  -- WHILE the supply is short.
  for _, label in ipairs({ "half", "dark", "pooled" }) do
    local s, d = span(label, "lit", "deep")
    record(s > d, label .. ": a lit reactor is a net contributor throughout the shortfall, not a drain",
      string.format("%+.4g MJ net (%+.4g MW), sold %.4g against %.4g drawn", s - d, mw(s - d, CUT), s, d))
  end
  local half = snaps.deep.half.plasma[1]
  record(half ~= nil and half.temperature > clamp * 0.5,
    "half: and at half supply it is still fusing at the end of the shortfall",
    half and string.format("%.4g C, %.4g u, heater %s", half.temperature, half.amount, snaps.deep.half.heater)
      or "no plasma")
  note("half      supply", cells.half.half_w
    and string.format("cut to %.4g MW, measured as half the satisfied cell's own draw", cells.half.half_w / 1e6)
    or "never applied")

  -- ------------------------------------------------------------ the blackout, and what it costs
  --
  -- dark is the cell that decides whether losing the supply is losing the reactor. It keeps selling
  -- for minutes on a plasma nothing is heating, so the loss is slow and the reactor spends the whole
  -- descent fighting the shortfall rather than deepening it.
  local early_sold, early_drawn = span("dark", "lit", "early")
  record(early_sold > early_drawn,
    "dark: a blacked-out reactor keeps selling energy it is no longer being paid to make",
    string.format("%+.4g MJ net over the first minute (%+.4g MW)",
      early_sold - early_drawn, mw(early_sold - early_drawn, EARLY - LIT)))
  -- IT IS DECAYING, AND IT IS NOT DEAD, and both halves of that are the answer to #70 rather than a
  -- limitation of the rig. The reactor is losing its plasma the whole way -- asserted, so a reactor
  -- that had somehow become self-sustaining without a fuel line would fail here -- and after fifteen
  -- minutes of total blackout it is still a substantial generator. There is no cut length at which it
  -- stops entirely, because the plasma's own loss is what it sells.
  local dead = snaps.deep.dark.plasma[1]
  local fade, dark_lit_mw, dark_end_mw = faded_to(cells.dark)
  record(fade ~= nil and fade < 1,
    "dark: and it is decaying the whole way, so nothing here is a reactor that stopped needing fuel",
    fade and string.format("%.4g MW lit, %.4g MW at the end of %ds of blackout (%.1f%%), %.4g C left",
      dark_lit_mw, dark_end_mw, CUT / 60, 100 * fade, dead and dead.temperature or 0)
      or "the trace is too short to measure a rate")
  note("dark      floor", string.format(
    "no cut length ends it: a reactor holding plasma sells that plasma's own loss, so the output " ..
    "decays towards nothing and never arrives. %.4g u still in the box.",
    dead and dead.amount or 0))

  -- ------------------------------------------------------------ 2. it recovers unattended
  local back = snaps.back.recover.plasma[1]
  record(back ~= nil and back.temperature >= clamp * 0.999,
    "recover: the supply comes back and the reactor re-ignites with no help of any kind",
    back and string.format("%.4g C, %.4g u, %.1fs after the supply returned",
      back.temperature, back.amount, RESTORE / 60) or "no plasma")
  -- The third claim, and the one the measurement improved on. It was written expecting a cost: a
  -- reactor climbing back from a blackout should be spending its confinement heating before it has
  -- any fusion to pay for it. On the trajectory a blackout actually leaves, it is not -- the plasma
  -- never got thin enough, and capture_efficiency sells what leaves it whether or not fusion put it
  -- there, so the reactor is ahead the whole way up. The bound is asserted anyway, because it is the
  -- thing that would catch a reactor that HAD become a 50 MW hole; the sign is reported, because it
  -- is the answer.
  local rs, rd = span("recover", "deep", "back")
  record(rd - rs < rd * 0.5,
    "recover: and coming back never costs more than a fraction of what it draws",
    string.format("%+.4g MJ net over the %ds it took (%+.4g MW) against %.4g MJ drawn -- %s",
      rs - rd, RESTORE / 60, mw(rs - rd, RESTORE), rd,
      rs > rd and "net positive throughout, so re-igniting cost nothing at all"
              or string.format("a cost of %.1f%% of the draw", 100 * (rd - rs) / math.max(rd, 1))))

  -- ------------------------------------------------------------ 3. the drain is bounded
  --
  -- boundary is the only cell in the rig where the reactor is genuinely a net drain, and it is held
  -- there deliberately: plasma present, full power, and a density too low for the reaction to carry
  -- itself. The bound matters more than the sign. capture_efficiency is what sets it -- the reactor
  -- sells most of what leaves the plasma whether or not any of it came from fusion -- so a thin
  -- reactor costs a fraction of its heating and not the whole of it.
  local seeded   = snaps.lit.boundary.plasma[1]
  local capacity = cells.boundary.reactors[1].fluidbox.get_capacity(1)
  record(seeded ~= nil and seeded.amount <= capacity * THIN * 1.1,
    "boundary: the charge really did land thin, so the cell is measuring what it was built to",
    seeded and string.format("%.4g u of %.4g (%.2f%%), seeded at %.2f%% and cold",
      seeded.amount, capacity, 100 * seeded.amount / capacity, 100 * THIN) or "no plasma")
  local bs, bd = span("boundary", "lit", "deep")
  record(bs < bd, "boundary: a reactor holding plasma too thin to carry itself is a net drain",
    string.format("%+.4g MJ net (%+.4g MW) -- the only cell in this rig where the sign is negative",
      bs - bd, mw(bs - bd, DEEP - LIT)))
  local ended = snaps.deep.boundary.plasma[1]
  note("boundary  end", ended
    and string.format("%.4g u left at %.4g C", ended.amount, ended.temperature)
    or "the charge burnt out, after which an empty reactor draws nothing at all")
  note("boundary  reach", string.format(
    "and no cell here got into this state by losing power: %ds of total blackout left the D-T " ..
    "reactor far above it, so the drain had to be seeded by hand to be measured at all", CUT / 60))

  -- ------------------------------------------------------------ the verdict
  --
  -- The only cell where the loop closes, so the only one in which a spiral is a thing that can
  -- happen rather than a thing inferred from numbers. It is asked twice: once with the starter gone,
  -- and once with more load than it can carry.
  local ps = snaps.deep.plant.plasma[1]
  record(ps ~= nil and ps.temperature >= clamp * 0.999
      and snaps.deep.plant.turbine == "working",
    "plant: with its starter switched off the plant carries its own confinement heating",
    ps and string.format("%.4g C, turbine %s, heater %s",
      ps.temperature, snaps.deep.plant.turbine, snaps.deep.plant.heater) or "no plasma")
  local pb = snaps.back.plant.plasma[1]
  record(pb ~= nil and pb.temperature >= clamp * 0.999,
    "plant: and overloading it past what it can make does not make it eat itself",
    pb and string.format("%.4g C at %.4g MW of load, turbine %s, heater %s",
      pb.temperature, (snaps.back.plant.load or 0) / 1e6, snaps.back.plant.turbine, snaps.back.plant.heater)
      or "no plasma")

  -- ------------------------------------------------------------ the other tier, same rig
  --
  -- ADR 0015 accepted the D-D tier's cooling on the strength of an argument and one line of
  -- tests/test-reactor-logic.lua. This is the same claim in the same rig as the D-T one, which is
  -- what lets the two answers be stated together: D-D goes cold because it was never ignited, D-T
  -- does not because it was.
  -- Measured on output and on endurance rather than on temperature, and that is a finding rather
  -- than a convenience: at the rate ONE HEATER feeds a reactor the plasma is thin, a thin plasma has
  -- little to heat, and both tiers therefore run up to the clamp. D-D's settling point of about
  -- 8.8e8 C is a FULL reactor's, and a heater-fed one is nowhere near full. So temperature does not
  -- separate the tiers here; what they sell for the same fuel does, and so does how long each goes on
  -- selling once the power stops.
  -- A modest ratio, and it is meant to be. scripts/check-d-t.ps1 sees five times, because it feeds
  -- both tiers plasma at a fixed 6e8 C from an infinity pipe. Here the fuel is a heater's, most of
  -- what either reactor sells at this density is its own heating coming back through
  -- capture_efficiency, and the fusion on top of that is the part that differs. So this check is
  -- that the ordering holds, not that it is dramatic; the endurance check below is where the tiers
  -- come apart.
  record(snaps.lit.dd.sold < snaps.lit.dark.sold,
    "dd: the same heater buys less from a D-D reactor than from a D-T one",
    string.format("%.4g MJ against %.4g MJ over the settle phase, %.2fx",
      snaps.lit.dd.sold, snaps.lit.dark.sold,
      snaps.lit.dark.sold / math.max(snaps.lit.dd.sold, 1)))
  -- The tier difference, and the sharpest number in the rig: through the SAME blackout, of the same
  -- length, the D-T reactor keeps a large fraction of its output and the D-D one keeps almost none.
  -- That is ignition, measured -- D-T's plasma is carrying itself and D-D's never was.
  local dd_fade, dd_lit_mw, dd_end_mw = faded_to(cells.dd)
  record(dd_fade ~= nil and fade ~= nil and dd_fade < fade,
    "dd: and it fades far further through the same blackout than the D-T reactor does",
    (dd_fade and fade) and string.format(
      "D-D keeps %.2f%% of its lit output (%.4g to %.4g MW), D-T keeps %.1f%%",
      100 * dd_fade, dd_lit_mw, dd_end_mw, 100 * fade)
      or "the trace is too short to measure a rate")
  local dd_deep = snaps.deep.dd.plasma[1]
  note("dd        end", string.format("%s against D-T's %s",
    dd_deep and string.format("%.4g C, %.4g u", dd_deep.temperature, dd_deep.amount) or "no plasma",
    dead and string.format("%.4g C, %.4g u", dead.temperature, dead.amount) or "no plasma"))

  -- ------------------------------------------------------------ a row is not a reactor
  local a, b = snaps.deep.pooled.plasma[1], snaps.deep.pooled.plasma[2]
  record(a ~= nil and b ~= nil,
    "pooled: both reactors on the shared pool still hold plasma at the end of the blackout",
    (a and b) and string.format("%.4g C and %.4g C", a.temperature, b.temperature) or "one is empty")
  if a and b then
    local hot  = math.max(a.temperature, b.temperature)
    local cold = math.min(a.temperature, b.temperature)
    record(cold > hot * 0.5, "pooled: and they share the fall rather than one starving the other",
      string.format("spread %.4g C, %.1f%% of the hotter", hot - cold, 100 * (hot - cold) / hot))
  end

  -- ------------------------------------------------------------ the measurements, as data
  --
  -- Emitted so that -Report can draw the same run rather than a re-run of it, and so that the graphs
  -- and the checks above can never disagree: both come from this one trace. Every quantity is in the
  -- unit the report uses -- megajoules and megawatts, celsius, fluid units -- so the renderer does no
  -- arithmetic that this file has not already done once.
  local produce = consume == "input" and "output" or "input"
  log(string.format(
    "BROWNOUT-RIG meta settle=%d cut=%d restore=%d trace=%d thin=%.6g clamp=%.6g consume=%s version=%s",
    SETTLE, CUT, RESTORE, TRACE_EVERY, THIN, clamp, consume, script.active_mods["base"]))
  for _, label in ipairs(storage.order) do
    local cell = cells[label]
    for _, e in ipairs(cell.trace or {}) do
      log(string.format("BROWNOUT-RIG data %s %d %.6g %.6g %.6g %.6g %.6g", label, e.tick,
        e.sold,                                                     -- MJ, cumulative
        (consume == "input" and e.din or e.dout) / 1e6,             -- MJ, cumulative
        e.t, e.u,
        (produce == "input" and e.gin or e.gout) / 1e6))            -- MJ, cumulative, turbines
    end
  end

  local report = storage.report
  report.lines[#report.lines + 1] = string.format("%s: %d checks, %d failures",
    report.failures == 0 and "PASS" or "FAIL", report.checks, report.failures)
  for _, line in ipairs(report.lines) do log("BROWNOUT-RIG " .. line) end
end)
'@
    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') -Value (
        $lua.Replace('__PLASMAFEED__', $feed).
             Replace('__SETTLE__',  "$settleTicks").
             Replace('__CUT__',     "$cutTicks").
             Replace('__RESTORE__', "$restoreTicks").
             Replace('__THIN__',    ([string]::Format([cultureinfo]::InvariantCulture, '{0}', $Thin))))
}

# ---------------------------------------------------------------- the report
#
# Drawing, kept together and kept here rather than in factorio-lib.ps1: nothing else in this
# repository draws anything, and a shared library with one caller is a worse thing to maintain than a
# fenced section with none.
#
# SVG by hand and no plotting dependency, for the reason every other rig here computes its own
# arithmetic: this repository's tooling is Factorio, PowerShell and two Python scripts, and a report
# that needs a package installed to regenerate is a report that stops being regenerable. The output is
# also plain text, so a change in the mod shows up as a diff rather than as a new binary.

# Eight distinguishable inks, in the plan's order. Not a theme: the charts paint their own light
# ground so they read the same whichever way a reader's viewer is set, which is the one thing an
# <img>-loaded SVG cannot inherit.
$script:Ink = [ordered]@{
    plant = '#1f77b4'; full = '#2ca02c'; half = '#ff7f0e'; dark = '#d62728'
    recover = '#9467bd'; boundary = '#8c564b'; dd = '#7f7f7f'; pooled = '#17becf'
}

function Get-NiceTicks {
    <#  Five or so round numbers spanning [min, max]. Round in the sense a reader wants -- 1, 2 or 5
        times a power of ten -- so an axis reads as measurements rather than as arithmetic.  #>
    param([double] $Min, [double] $Max, [int] $Want = 5)

    if ($Max -le $Min) { return @($Min, $Max) }
    $raw  = ($Max - $Min) / $Want
    $mag  = [math]::Pow(10, [math]::Floor([math]::Log10($raw)))
    $step = @(1, 2, 5, 10) | Where-Object { $_ * $mag -ge $raw } | Select-Object -First 1
    $step = $step * $mag
    $ticks = @()
    for ($t = [math]::Ceiling($Min / $step) * $step; $t -le $Max + $step * 1e-9; $t += $step) { $ticks += $t }
    return $ticks
}

function Format-Axis {
    param([double] $V)
    # Negative zero is a real double and .NET formats it "-0". A tick lands on one whenever the axis
    # starts just below zero, which is exactly the axis a chart with one negative bar has.
    if ($V -eq 0) { return '0' }
    # A log axis only ever asks for exact powers of ten, and "1e7" reads better on one than "10e6".
    if ($V -gt 0) {
        $e = [math]::Log10($V)
        if ([math]::Abs($e - [math]::Round($e)) -lt 1e-9 -and $e -ge 6) {
            return ('1e{0}' -f [int][math]::Round($e))
        }
    }
    if ([math]::Abs($V) -ge 1e9) { return ('{0:0.##}e9' -f ($V / 1e9)) }
    if ([math]::Abs($V) -ge 1e6) { return ('{0:0.##}e6' -f ($V / 1e6)) }
    if ([math]::Abs($V) -ge 1000) { return ('{0:0.##}k' -f ($V / 1000)) }
    if ([math]::Abs($V) -lt 1 -and $V -ne 0) { return ('{0:0.###}' -f $V) }
    return ('{0:0.##}' -f $V)
}

function New-LineChart {
    <#  One chart, many series, time along the bottom.

        `Series` is an ordered map of label -> array of @{ X; Y }. `Marks` are the phase boundaries,
        as @{ At; Text } -- drawn as rules rather than written in the caption, because every claim in
        the report is about which side of one of them a reading falls.  #>
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Series,
        [Parameter(Mandatory)] [string] $Title,
        [Parameter(Mandatory)] [string] $YLabel,
        [string] $XLabel = 'seconds',
        [switch] $Log,
        [array]  $Marks = @(),
        [double] $Floor = 1
    )
    if ($Log -and $Floor -le 0) { throw 'a log axis needs a positive floor.' }

    $w, $h = 900, 400
    $l, $r, $t, $b = 78, 148, 34, 52
    # Parenthesised because the comma binds tighter than the minus: without them PowerShell reads
    # `$r, $h` as an array and subtracts it from a number.
    $pw, $ph = ($w - $l - $r), ($h - $t - $b)

    $xs = @(); $ys = @()
    foreach ($points in $Series.Values) { foreach ($p in $points) { $xs += $p.X; $ys += $p.Y } }
    if ($xs.Count -eq 0) { return $null }

    $xMin, $xMax = ($xs | Measure-Object -Minimum).Minimum, ($xs | Measure-Object -Maximum).Maximum
    $yMin, $yMax = ($ys | Measure-Object -Minimum).Minimum, ($ys | Measure-Object -Maximum).Maximum

    if ($Log) {
        # A log axis has no room for zero, and both quantities plotted here reach it -- a reactor at
        # ambient, a reactor selling nothing. The floor is a parameter and is named in the caption
        # rather than applied silently, because where it sits changes what the chart appears to say.
        $yMin = [math]::Log10([math]::Max($yMin, $Floor))
        $yMax = [math]::Log10([math]::Max($yMax, $Floor * 10))
        $ticks = @()
        for ($e = [math]::Floor($yMin); $e -le [math]::Ceiling($yMax); $e++) { $ticks += $e }
    }
    else {
        if ($yMin -gt 0) { $yMin = 0 }
        $pad = ($yMax - $yMin) * 0.06
        $yMax += $pad
        if ($yMin -lt 0) { $yMin -= $pad }
        $ticks = Get-NiceTicks -Min $yMin -Max $yMax
    }

    $sx = { param($v) $l + ($v - $xMin) / [math]::Max($xMax - $xMin, 1e-9) * $pw }
    $sy = {
        param($v)
        $u = if ($Log) { [math]::Log10([math]::Max($v, $Floor)) } else { $v }
        $t + $ph - ($u - $yMin) / [math]::Max($yMax - $yMin, 1e-9) * $ph
    }

    $out = [System.Text.StringBuilder]::new()
    $null = $out.AppendLine("<svg xmlns='http://www.w3.org/2000/svg' width='$w' height='$h' viewBox='0 0 $w $h' font-family='ui-sans-serif, Segoe UI, Helvetica, Arial, sans-serif'>")
    $null = $out.AppendLine("<rect width='$w' height='$h' fill='#fbfbfa'/>")
    $null = $out.AppendLine("<text x='$l' y='20' font-size='14' font-weight='600' fill='#1a1a1a'>$Title</text>")

    foreach ($tick in $ticks) {
        $at = if ($Log) { [math]::Pow(10, $tick) } else { $tick }
        $y  = [math]::Round((& $sy $at), 2)
        $null = $out.AppendLine("<line x1='$l' y1='$y' x2='$($l + $pw)' y2='$y' stroke='#e3e3e0' stroke-width='1'/>")
        $text = if ($Log) { Format-Axis ([math]::Pow(10, $tick)) } else { Format-Axis $tick }
        $null = $out.AppendLine("<text x='$($l - 8)' y='$($y + 4)' font-size='11' text-anchor='end' fill='#5a5a55'>$text</text>")
    }
    if (-not $Log -and $yMin -lt 0) {
        $y = [math]::Round((& $sy 0), 2)
        $null = $out.AppendLine("<line x1='$l' y1='$y' x2='$($l + $pw)' y2='$y' stroke='#9a9a92' stroke-width='1.5'/>")
    }

    foreach ($mark in $Marks) {
        $x = [math]::Round((& $sx $mark.At), 2)
        $null = $out.AppendLine("<line x1='$x' y1='$t' x2='$x' y2='$($t + $ph)' stroke='#7a7a72' stroke-width='1' stroke-dasharray='4 3'/>")
        # Three quarters of the way down: the top is where a clamped plasma's curve lives and the
        # bottom is where a collapsed one's does, and a label in either place sits on a line.
        $null = $out.AppendLine("<text x='$($x + 4)' y='$($t + $ph * 0.75)' font-size='10.5' fill='#5a5a55'>$($mark.Text)</text>")
    }

    foreach ($tick in (Get-NiceTicks -Min $xMin -Max $xMax -Want 6)) {
        if ($tick -lt $xMin -or $tick -gt $xMax) { continue }
        $x = [math]::Round((& $sx $tick), 2)
        $null = $out.AppendLine("<text x='$x' y='$($t + $ph + 18)' font-size='11' text-anchor='middle' fill='#5a5a55'>$(Format-Axis $tick)</text>")
    }
    $null = $out.AppendLine("<line x1='$l' y1='$($t + $ph)' x2='$($l + $pw)' y2='$($t + $ph)' stroke='#9a9a92' stroke-width='1'/>")
    $null = $out.AppendLine("<line x1='$l' y1='$t' x2='$l' y2='$($t + $ph)' stroke='#9a9a92' stroke-width='1'/>")
    $null = $out.AppendLine("<text x='$($l + $pw / 2)' y='$($h - 12)' font-size='11.5' text-anchor='middle' fill='#3a3a36'>$XLabel</text>")
    $null = $out.AppendLine("<text x='14' y='$($t + $ph / 2)' font-size='11.5' text-anchor='middle' fill='#3a3a36' transform='rotate(-90 14 $($t + $ph / 2))'>$YLabel</text>")

    $row = 0
    foreach ($label in $Series.Keys) {
        $ink = if ($script:Ink[$label]) { $script:Ink[$label] } else { '#333333' }
        $pts = ($Series[$label] | ForEach-Object {
            '{0},{1}' -f [math]::Round((& $sx $_.X), 2), [math]::Round((& $sy $_.Y), 2)
        }) -join ' '
        $null = $out.AppendLine("<polyline points='$pts' fill='none' stroke='$ink' stroke-width='1.8' stroke-linejoin='round'/>")
        $ly = $t + 6 + $row * 17
        $null = $out.AppendLine("<line x1='$($l + $pw + 14)' y1='$ly' x2='$($l + $pw + 32)' y2='$ly' stroke='$ink' stroke-width='2.4'/>")
        $null = $out.AppendLine("<text x='$($l + $pw + 38)' y='$($ly + 4)' font-size='11.5' fill='#1a1a1a'>$label</text>")
        $row++
    }

    $null = $out.AppendLine('</svg>')
    return $out.ToString()
}

function New-BarChart {
    <#  Signed horizontal bars. Signed is the point: one cell in this rig is negative and seven are
        not, and a chart that could not show that would be the wrong chart.  #>
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Values,
        [Parameter(Mandatory)] [string] $Title,
        [Parameter(Mandatory)] [string] $XLabel
    )

    $rows = $Values.Count
    $w = 900
    $rowH = 30
    $l, $r, $t, $b = 96, 96, 34, 46
    $h = $t + $rows * $rowH + $b
    $pw = $w - $l - $r

    $vals = @($Values.Values)
    $lo = [math]::Min(0, ($vals | Measure-Object -Minimum).Minimum)
    $hi = [math]::Max(0, ($vals | Measure-Object -Maximum).Maximum)
    $span = [math]::Max($hi - $lo, 1e-9)
    $sx = { param($v) $l + ($v - $lo) / $span * $pw }
    $zero = [math]::Round((& $sx 0), 2)

    $out = [System.Text.StringBuilder]::new()
    $null = $out.AppendLine("<svg xmlns='http://www.w3.org/2000/svg' width='$w' height='$h' viewBox='0 0 $w $h' font-family='ui-sans-serif, Segoe UI, Helvetica, Arial, sans-serif'>")
    $null = $out.AppendLine("<rect width='$w' height='$h' fill='#fbfbfa'/>")
    $null = $out.AppendLine("<text x='$l' y='20' font-size='14' font-weight='600' fill='#1a1a1a'>$Title</text>")

    foreach ($tick in (Get-NiceTicks -Min $lo -Max $hi -Want 6)) {
        $x = [math]::Round((& $sx $tick), 2)
        $null = $out.AppendLine("<line x1='$x' y1='$t' x2='$x' y2='$($t + $rows * $rowH)' stroke='#e3e3e0' stroke-width='1'/>")
        $null = $out.AppendLine("<text x='$x' y='$($t + $rows * $rowH + 18)' font-size='11' text-anchor='middle' fill='#5a5a55'>$(Format-Axis $tick)</text>")
    }

    $i = 0
    foreach ($label in $Values.Keys) {
        $v = [double] $Values[$label]
        $y = $t + $i * $rowH + 5
        $x = [math]::Round((& $sx ([math]::Min(0, $v))), 2)
        $bw = [math]::Max([math]::Abs((& $sx $v) - $zero), 1)
        $ink = if ($v -lt 0) { '#c0392b' } else { $script:Ink[$label] }
        if (-not $ink) { $ink = '#2ca02c' }
        $null = $out.AppendLine("<rect x='$x' y='$y' width='$([math]::Round($bw, 2))' height='$($rowH - 12)' fill='$ink' opacity='0.85'/>")
        $null = $out.AppendLine("<text x='$($l - 10)' y='$($y + $rowH - 17)' font-size='11.5' text-anchor='end' fill='#1a1a1a'>$label</text>")
        # Both labels go to the RIGHT of where the bar ends up: a negative bar's outer end is next to
        # the row's own name, and a figure written there lands on top of it.
        $tx = if ($v -lt 0) { $zero + 6 } else { $x + $bw + 6 }
        $anchor = 'start'
        $null = $out.AppendLine("<text x='$([math]::Round($tx, 2))' y='$($y + $rowH - 17)' font-size='11' text-anchor='$anchor' fill='#3a3a36'>$('{0:+0.###;-0.###;0}' -f $v)</text>")
        $i++
    }

    $null = $out.AppendLine("<line x1='$zero' y1='$t' x2='$zero' y2='$($t + $rows * $rowH)' stroke='#5a5a55' stroke-width='1.5'/>")
    $null = $out.AppendLine("<text x='$($l + $pw / 2)' y='$($h - 10)' font-size='11.5' text-anchor='middle' fill='#3a3a36'>$XLabel</text>")
    $null = $out.AppendLine('</svg>')
    return $out.ToString()
}

function Get-SampleRate {
    <#  Megawatts between two trace samples. `plant`'s reactor output is drunk by a real exchanger
        rather than counted into a total, so what that cell makes is read at its turbines instead.  #>
    param($From, $To, [string] $Label)
    if (-not $From -or -not $To -or $To.Tick -le $From.Tick) { return $null }
    $made = if ($Label -eq 'plant') { $To.Gen - $From.Gen } else { $To.Sold - $From.Sold }
    return $made / (($To.Tick - $From.Tick) / 60)
}

function Write-BrownoutReport {
    <#  Render one rig run: a markdown note and the SVGs it points at.

        Everything drawn here comes from the `data` lines the rig emitted, which are the same trace its
        own checks were computed from -- so a graph disagreeing with the verdict above it is not a
        thing that can happen. The `ok`/`FAIL` lines are reproduced verbatim for the same reason.  #>
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string[]] $Output,
        [Parameter(Mandatory)] [string[]] $Checks,
        [Parameter(Mandatory)] [string] $Command
    )

    # INVARIANT CULTURE, AND IT IS NOT COSMETIC. -f and string interpolation both format to the
    # current culture, and this machine's is one that writes a decimal comma. That turns a table into
    # something a reader has to decode, and it turns an SVG into rubble: a polyline's points are
    # comma-separated, so "85,85 82,52" is four coordinates rather than two and the chart draws
    # nonsense without erroring. Set once around the whole render rather than at each format site,
    # because the one site that got forgotten would be the one that broke a graph.
    $was = [Threading.Thread]::CurrentThread.CurrentCulture
    [Threading.Thread]::CurrentThread.CurrentCulture = [cultureinfo]::InvariantCulture
    try {
    $meta = @{}
    foreach ($line in ($Output | Select-String -Pattern 'BROWNOUT-RIG meta ')) {
        foreach ($pair in (($line -split 'BROWNOUT-RIG meta ', 2)[1].Trim() -split '\s+')) {
            $k, $v = $pair -split '=', 2
            $meta[$k] = $v
        }
    }
    if (-not $meta.Count) { throw 'the rig emitted no meta line, so there is nothing to report.' }

    # label -> ordered samples. Ordered by arrival, which is the order the rig walked its cells and
    # then its trace, so no sorting is needed and none is done: a sort would hide a gap.
    $cells = [ordered]@{}
    foreach ($line in ($Output | Select-String -Pattern 'BROWNOUT-RIG data ')) {
        $f = (($line -split 'BROWNOUT-RIG data ', 2)[1].Trim() -split '\s+')
        if ($f.Count -lt 7) { continue }
        $label = $f[0]
        if (-not $cells.Contains($label)) { $cells[$label] = [System.Collections.ArrayList]::new() }
        $null = $cells[$label].Add([pscustomobject]@{
            Tick  = [int]    $f[1]
            Sold  = [double] $f[2]
            Drawn = [double] $f[3]
            T     = [double] $f[4]
            U     = [double] $f[5]
            Gen   = [double] $f[6]
        })
    }
    if (-not $cells.Count) { throw 'the rig emitted no data lines, so there is nothing to graph.' }

    $settle  = [int] $meta.settle
    $cut     = [int] $meta.cut
    $restore = [int] $meta.restore
    $marks = @(
        @{ At = $settle / 60;            Text = 'shortfall begins' }
        @{ At = ($settle + $cut) / 60;   Text = 'supply back / overload' }
    )

    # --- rates, differenced from the cumulative counters
    #
    # The trace is cumulative because a counter cannot lose a tick; a rate is what a reader wants. The
    # difference is taken here, once, and every figure in the report and its graphs comes from it.
    $rate = [ordered]@{}
    $temp = [ordered]@{}
    $net  = [ordered]@{}
    foreach ($label in $cells.Keys) {
        $s = $cells[$label]
        $rate[$label] = [System.Collections.ArrayList]::new()
        $temp[$label] = [System.Collections.ArrayList]::new()
        for ($i = 1; $i -lt $s.Count; $i++) {
            if ($s[$i].Tick -le $s[$i - 1].Tick) { continue }
            # plant's reactor output is drunk by a real exchanger rather than counted, so what it
            # makes is read at its turbines instead. Named in the chart's caption, not hidden here.
            $made = Get-SampleRate $s[$i - 1] $s[$i] $label
            $null = $rate[$label].Add([pscustomobject]@{ X = $s[$i].Tick / 60; Y = $made })
            $null = $temp[$label].Add([pscustomobject]@{ X = $s[$i].Tick / 60; Y = [math]::Max($s[$i].T, 15) })
        }
        $a = $s | Where-Object { $_.Tick -le $settle }          | Select-Object -Last 1
        $b = $s | Where-Object { $_.Tick -le $settle + $cut }    | Select-Object -Last 1
        if ($a -and $b -and $b.Tick -gt $a.Tick) {
            $secs = ($b.Tick - $a.Tick) / 60
            $net[$label] = (Get-SampleRate $a $b $label) - ($b.Drawn - $a.Drawn) / $secs
        }
        else { $net[$label] = 0 }
    }

    $dir  = Join-Path (Split-Path -Parent $Path) ([IO.Path]::GetFileNameWithoutExtension($Path))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $rel  = [IO.Path]::GetFileNameWithoutExtension($Path)

    # Log, because the story is four orders of magnitude wide: a lit reactor climbing past 300 MW and
    # a D-D one that has fallen to a tenth of one. A linear axis shows the first and hides the second.
    Set-Content -Encoding utf8 -Path (Join-Path $dir 'output.svg') -Value (New-LineChart `
        -Series $rate -Marks $marks -Log -Floor 0.1 `
        -Title 'What each cell was selling, megawatts (log scale, floor at 0.1 MW)' -YLabel 'MW')
    # Floored at the injection temperature rather than at ambient. Ambient is where an EMPTY box
    # reads, and flooring there spends six of the axis's ten decades on nothing at all -- which is
    # what it did, and the D-T and D-D curves were a single band at the top as a result.
    Set-Content -Encoding utf8 -Path (Join-Path $dir 'temperature.svg') -Value (New-LineChart `
        -Series $temp -Marks $marks -Log -Floor 1e6 `
        -Title 'Plasma temperature, degrees celsius (log scale, floor at the 1e6 C injection temperature)' `
        -YLabel 'degrees C')
    Set-Content -Encoding utf8 -Path (Join-Path $dir 'net.svg') -Value (New-BarChart `
        -Values $net -Title 'Net contribution to its own network through the shortfall' -XLabel 'MW')

    # --- the summary table, off the same samples
    $rows = foreach ($label in $cells.Keys) {
        $s = $cells[$label]
        $litFrom = $s | Where-Object { $_.Tick -le $settle - 3600 } | Select-Object -Last 1
        $litTo   = $s | Where-Object { $_.Tick -le $settle }        | Select-Object -Last 1
        $endFrom = $s | Where-Object { $_.Tick -le $settle + $cut - [math]::Min(3600, $cut) } | Select-Object -Last 1
        $endTo   = $s | Where-Object { $_.Tick -le $settle + $cut } | Select-Object -Last 1
        $last    = $s | Select-Object -Last 1
        $lit = Get-SampleRate $litFrom $litTo $label
        $end = Get-SampleRate $endFrom $endTo $label
        [pscustomobject]@{
            Cell = $label
            Lit  = $lit
            End  = $end
            Kept = if ($lit -and $lit -gt 0) { 100 * $end / $lit } else { $null }
            Net  = $net[$label]
            T    = $endTo.T
            U    = $endTo.U
            Final = $last.T
        }
    }

    $table = foreach ($row in $rows) {
        '| `{0}` | {1} | {2} | {3} | {4} | {5} | {6} |' -f $row.Cell,
            $(if ($null -ne $row.Lit)  { '{0:0.##}' -f $row.Lit }  else { '--' }),
            $(if ($null -ne $row.End)  { '{0:0.##}' -f $row.End }  else { '--' }),
            $(if ($null -ne $row.Kept) { '{0:0.#}%' -f $row.Kept } else { '--' }),
            ('{0:+0.##;-0.##;0}' -f $row.Net),
            ('{0:0.###e+0}' -f $row.T),
            ('{0:0.#}' -f $row.U)
    }

    $checkRows = foreach ($line in $Checks) {
        if ($line -match '^(ok|FAIL)\s+(.*?)(?:\s+--\s+(.*))?$') {
            '| {0} | {1} | {2} |' -f $(if ($Matches[1] -eq 'ok') { 'pass' } else { '**FAIL**' }),
                $Matches[2].Trim(), ($Matches[3] -replace '\|', '\|')
        }
    }

    $verdict = ($Checks | Where-Object { $_ -match '^(PASS|FAIL): ' } | Select-Object -Last 1)

    $md = @"
# The brownout and blackout measurements

**Generated by ``scripts/check-brownout.ps1 -Report``. Do not edit: every run overwrites it.**
Rendered $(Get-Date -Format 'yyyy-MM-dd') from one run against Factorio $($meta.version), base 2.0 only.
Verdict: **$verdict**

``````
$Command
``````

This is the rig half of [#70](https://github.com/trulsjo/realistic-fusion-refreshed/issues/70). The
question was whether losing a D-T reactor to a brownout should be survivable, on a premise that a
brownout cools the plasma, which cuts the output, which deepens the brownout. **The premise does not
hold.** A D-T reactor at the shipped numbers is ignited: it needs its confinement heating to get to a
fusing temperature and not to stay at one, so a shortfall costs it output slowly and costs its network
nothing at all.

Every number below is measured in a running game, on eight independent cells, and drawn from the same
trace the rig's own assertions are computed from. Balance in this repository is provisional, so the
figures move when the balance does -- which is the reason this file is generated rather than written.

## The phases

| | ticks | seconds | what happens |
|---|---:|---:|---|
| settle | $settle | $($settle / 60) | every cell supplied; reactors light and build density |
| shortfall | $cut | $($cut / 60) | each cell takes its own cut -- see the cells below |
| after | $restore | $($restore / 60) | ``recover`` gets its supply back; ``plant`` is overloaded |

## The cells

Eight, each on its own electric network and its own plasma segment, each a reactor with its own
``rf-heater`` feeding it -- so undersupplying a network throttles the fuel line and the confinement
heating together, in the engine's proportions rather than in ones the rig chose.

| cell | what it is | its cut |
|---|---|---|
| ``full`` | D-T reactor and heater | none -- the baseline |
| ``half`` | the same | supply to half of what the cell was measured to draw |
| ``dark`` | the same | supply to zero, never restored |
| ``recover`` | the same | supply to zero, then back at the end of the shortfall |
| ``boundary`` | a reactor with no heater and no feed | none; instead one thin cold charge, seeded by hand |
| ``plant`` | reactor, heater, ``rf-hc-exchanger``, two ``rf-hc-turbines``, load bank | starter switched off, then overloaded past what it can make |
| ``dd`` | D-D reactor and heater | supply to zero, on the same tick as ``dark`` |
| ``pooled`` | two D-T reactors bridged by ``rf-pipe``, one heater | supply to zero, on the same tick as ``dark`` |

## What each cell was selling

![output]($rel/output.svg)

Log scale, floored at a tenth of a megawatt, because the eight cells end up four orders of magnitude
apart. The two rules are the phase boundaries. ``full`` is the only cell that keeps its supply throughout, and
``dark``, ``dd`` and ``pooled`` lose theirs entirely at the first rule -- so the distance between
``full`` and ``dark`` after that rule is the whole of what a blackout costs. ``plant`` is read at its
turbines rather than at its reactor, because a real exchanger is drinking its output.

## Plasma temperature

![temperature]($rel/temperature.svg)

Log scale, floored at the temperature plasma is injected at -- below that there is nothing to draw, and
a box with no plasma in it reads on the floor. The D-T cells fall off the clamp when their power goes and then flatten:
that flattening is ignition, and it is the answer to the ticket. ``dd`` does not flatten -- a D-D plasma
at this density was never carrying itself, so it falls all the way.

## Net contribution through the shortfall

![net]($rel/net.svg)

What each cell gave its own network minus what it took from it, averaged over the shortfall. Seven of
eight are positive. The one that is not is ``boundary``, which had to be handed a thin cold charge by
hand: no amount of losing power got any other cell into that state.

## The readings

| cell | MW lit | MW at the end | ratio | net MW | C at the end | units |
|---|---:|---:|---:|---:|---:|---:|
$($table -join "`n")

"MW lit" is measured over the last minute of the settle phase and "MW at the end" over the last minute
of the shortfall, so the ratio is what the cell still had by the end of its cut. ``full`` and ``plant``
keep their supply throughout, so their ratios sit at about 100% and are the control: whatever the other
cells lost, they lost it to the shortfall and not to the clock. "net MW" is output minus draw, averaged
across the whole shortfall.

The rig asserts that ``full``'s output had stopped climbing before the shortfall began, because every
ratio in this column divides by it. ``dd`` is the one cell deliberately left unconverged -- a D-D plasma
never ignites, so it climbs on temperature as well as density and would need far longer; that makes its
own "kept" figure an understatement, so the tier gap below is narrower than the truth rather than wider.

## What the rig asserted

| | check | measured |
|---|---|---|
$($checkRows -join "`n")

## Reproducing it

``````
$Command
``````

Cells, instrument and the two undocumented engine conventions the measurements rest on are all
documented in ``scripts/check-brownout.ps1``'s own header. ``tests/test-reactor-logic.lua`` asserts the
same behaviour outside Factorio, in about a second, and is the cheap guard; this is the expensive one.
"@

    Set-Content -Encoding utf8 -Path $Path -Value $md
    Write-Host ''
    Write-Host "report written: $Path"
    Write-Host "graphs:         $dir"
    }
    finally { [Threading.Thread]::CurrentThread.CurrentCulture = $was }
}

$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled $enabledBundled -Mods ($ourMods + $rigName)
    $bundledOn = if ($enabledBundled) { $enabledBundled -join ', ' } else { 'none (base 2.0 only)' }
    Write-Host "bundled enabled: $bundledOn"
    Write-Host "phases: settle ${Settle}s, cut ${Cut}s, restore ${Restore}s  ($totalTicks ticks)"
    Write-Rig

    $save = Join-Path $temp 'brownout.zip'
    Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create' | Out-Null
    $runOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', "$($totalTicks + 60)", '--benchmark-runs', '1', '--disable-audio')

    $reported = @(Get-Content $runOut | Select-String -Pattern 'BROWNOUT-RIG (ok|FAIL|PASS|--)' |
        ForEach-Object { ($_ -split 'BROWNOUT-RIG ', 2)[1].TrimEnd() })
    if ($reported.Count -eq 0) { throw 'the rig reported nothing; it never reached its check tick.' }

    foreach ($line in $reported) { Write-Host "  $line" }

    $verdict = $reported | Where-Object { $_ -match '^(PASS|FAIL): ' } | Select-Object -Last 1
    if (-not $verdict)              { throw 'the rig produced no verdict line.' }
    if ($verdict -notmatch '^PASS') { throw "the brownout behaviour is not what #70 was decided on: $verdict" }

    if ($Report) {
        $parent = Split-Path -Parent $Report
        if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        $command = "pwsh -File scripts/check-brownout.ps1 -Settle $Settle -Cut $Cut -Restore $Restore -Thin $Thin"
        if ($With) { $command += " -With $($With -join ',')" }
        $command += " -Report $Report"
        Write-BrownoutReport -Path $Report -Output (Get-Content $runOut) -Checks $reported -Command $command
    }

    Write-Host ''
    Write-Host 'OK - a lit reactor rides out a shortfall as a contributor, recovers unattended, and the'
    Write-Host '     only drain is the bounded sub-ignition window.'
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'check-brownout' }
}

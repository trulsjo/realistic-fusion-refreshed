<#
.SYNOPSIS
    Measures whether a row of chained direct energy converters buffers an ignited aneutronic
    reactor's bursty output on its own, with no tank anywhere in the chain. The rig #85 asks for.

.DESCRIPTION
    A PROBE, NOT A CHECK. Every line it prints is a measurement, and a negative answer is as much
    of a result as a positive one -- so exit 0 means the probe ran and every row reported, never
    that the answers were the ones anybody hoped for. Nothing here decides anything and nothing
    here ships. It must not be added to a check sweep, a bench sweep or to load-check.ps1.

    WHAT IT CLOSES

    ADR 0018 item 5 takes rf-aneutronic-composite-tank's energy-buffering role away, and its
    Consequences call the resulting hole "the loose end": prototypes/entities.lua argued in as many
    words that an ignited reactor's output follows its fuel line rather than a set rate, so the
    tier's flows arrive in bursts against a converter drinking a fixed hundred units a second, and
    that a buffer between them is what turns that into a steady hundred megawatts rather than a
    converter that stalls and restarts. With no tank in the chain the buffering is whatever the
    boxes hold -- the reactor's 1000-unit output box plus 1000 in every chained converter, with
    scale_fluid_usage meaning partial fluid gives partial power rather than a stall. Whether that
    suffices had never been measured. This measures it.

    IT RUNS BEFORE #86 RATHER THAN AFTER, AND THAT IS THE ONLY WINDOW IT HAS. ADR 0018 item 1 gives
    the two energy fluids a connection_category each; on the day that lands, no tank can hold either
    fluid and both tanked cells below stop being buildable at all. The untanked cells survive #86
    unchanged -- it is bolted faces and nothing else -- so what expires is the control, not the
    answer.

    THE FUEL LINE IS A HEATER, NOT AN INFINITY PIPE, AND THAT IS THE WHOLE RIG

    scripts/check-aneutronic.ps1 feeds its reactor plasma from an infinity pipe held at a fixed
    temperature and fill. That is the right thing for a gate -- it removes the fuel line as a
    variable -- and it is exactly the wrong thing here, because the burstiness under test IS the
    fuel line. rf-d-he3-plasma is five units per two seconds out of one rf-heater, delivered in
    lumps as a craft completes, and a rig that smooths that away can only report that a smooth
    supply produces smooth power.

    So every cell carries its own rf-heater on its own network, its own feedstock supply and its own
    plasma manifold, and the reactor is fed the way a player feeds one.

    WHAT IS BUILT -- five cells, each on its own electric network and its own plasma segment

      long      An rf-aneutronic-reactor, heater-fed, with a row of -Converters
                rf-direct-energy-converters bolted onto its north energy face and chained to one
                another. NO TANK ANYWHERE.

      longtank  The same build with one rf-aneutronic-composite-tank bolted onto the far end of the
                row, so the tank's contribution is the difference between two measured cells rather
                than an argument. It is bolted rather than piped: a run of pipe would add its own
                hundred units a tile to the buffer being measured, which is the confounder that
                would make the comparison worthless at exactly the point it mattered.

      tight     The same, with -Tight converters instead. THE ROW LENGTH IS THE VARIABLE, AND BOTH
                ENDS OF IT ARE NEEDED, because the chain's buffer IS the row: a boxful per converter
                means -Converters 16 carries 16 000 units of buffer against the tank's 50 000, while
                a two-converter row carries 2 000. A probe that measured only the long row would
                answer the question with a buffer no player building for this reactor would ever
                have, and would answer it far too kindly.

      tighttank The tight row with the tank on it. This is the cell the tank's case is strongest in,
                and therefore the one that decides whether it has one.

      open      The same reactor and heater with NO converters at all, its output box emptied by the
                rig every tick. This is the denominator: what the reactor sells when nothing can
                back it up. Loss to a full box is measured against it rather than derived, because
                control.lua's apply() discards its overflow silently -- it clamps the write to
                box.get_capacity() and nothing anywhere reports the difference.

    NEITHER ROW IS SIZED TO THE REACTOR, AND THAT IS THE POINT OF HAVING TWO

    The reactor's output has a FLOOR that owes nothing to its fuel line, and an earlier draft of this
    note missed it by confusing plasma units with energy units. capture_efficiency is 0.95 against
    200 MW of confinement heating, so a COLD aneutronic reactor already sells 190 units a second --
    reactor-logic.lua says exactly that in the note on the constant -- which is 1.9 converters before
    it fuses at all. One rf-heater's 2.5 units of plasma a second is what carries it from there to
    the 485 units a second it settles at, which is 4.85 converters.

    So the reactor spans about two converters to about five, and the two rows sit either side of that:
    sixteen is demand-rich by three times over, and two is demand-POOR the moment it lights and
    saturates. Between them they bracket what a player builds. Where the shortfall lands along a row
    is printed per converter, because a demand-rich row does not starve evenly and a mean cannot show
    it.

    HOW POWER IS MEASURED, AND WHY NOT OFF THE NETWORK

    Per converter, per tick, from LuaEntity::energy_generated_last_tick -- exact joules, attributed
    to one entity, needing no decision about which category of LuaFlowStatistics holds an electric
    network's generation. check-brownout.ps1 records that that decision is undocumented and has to be
    calibrated; this rig sidesteps it. The network's own cumulative figure is read once at the end as
    an independent cross-check on the total, with both input and output counts printed, because the
    loss figure rests on the joule accounting being right.

    Effectivity is 1 and the fluid is 1 MJ a unit, so a megajoule generated is a unit consumed and
    the two sides of the loss figure are in the same currency with no conversion factor to get wrong.

    HOW IT KNOWS THE ANSWER IS SETTLED

    It reports the evidence instead of asserting it, three ways -- the same three
    probe-quality-equilibrium.ps1 uses, for the same reason.

      * The whole approach curve is printed, one row per sample interval, per cell.
      * The run is split into quarters and each quarter's mean row power printed, so a reader sees
        the windows flatten. The drift between the last two is printed as a percentage -- twice, and
        the second one is the load-bearing figure: `rowdrift` is the ROW's, which reads +0.00% the
        moment a row saturates whatever the reactor behind it is doing, while `solddrift` is the
        REACTOR's own sale rate off the `open` cell. A settled row in front of a still-igniting
        reactor is the one way this rig could report a converged answer to a question it had not
        finished asking, and solddrift is what closes it.
      * -Seconds is a parameter, so the same rig can be run twice at different lengths and the
        answers compared.

    STALL, CYCLE OR STEADY IS ANSWERED FROM PER-TICK STATE, NOT FROM THE MEAN

    A row averaging its full output can still be cycling underneath. Each sample interval therefore
    prints the lowest and highest single-tick row power inside it, how many of its ticks had every
    converter reporting `working`, and how many had none generating at all. The final report counts
    stall episodes -- transitions from every-converter-working to not -- because "stalls and
    restarts" is a count of events rather than an average.

    THE MAP IS QUIETED (#189)

    It runs half an hour by default, which is long enough to be attacked, so it calls the shared
    guard Get-QuietMapLua in scripts/factorio-lib.ps1 before it builds. The report prints how many
    enemy entities went, so the quieting is visible rather than assumed.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Seconds
    Seconds to run before the final report.

    THE DEFAULT IS 1800, AND IT WAS MEASURED RATHER THAN CHOSEN. A heater-fed aneutronic reactor
    cold-starts thin and lights slowly: at 900 seconds the `open` cell's quarters still read 149,
    259, 376 and 439 units a second, a drift of +16.75%, which is a point on the way up that reads
    exactly like an equilibrium if a single mean is all anybody prints. Half an hour is where the
    last two quarters stop moving. Run it at other lengths to cross-check that rather than taking
    the drift figure on trust.

.PARAMETER SampleSeconds
    Seconds between printed sample rows. Per-tick state is accumulated every tick whatever this is;
    this only decides how often it is summarised.

.PARAMETER Converters
    Converters in the `long` and `longtank` rows. Deliberately well past what one heater can keep
    busy -- see the DESCRIPTION.

.PARAMETER Tight
    Converters in the `tight` and `tighttank` rows. The other end of the bracket: the shape a player
    builds for a fuel-limited reactor, and the row whose own buffer is small enough for a tank to
    matter.

.PARAMETER Heaters
    rf-heaters feeding each reactor. More heaters is a bigger reactor output and a shorter effective
    row, so this and -Converters move together.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/probe-converter-buffer.ps1

.EXAMPLE
    pwsh -File scripts/probe-converter-buffer.ps1 -Seconds 3600
    The convergence cross-check: twice the window, and the answers should not move.
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [ValidateRange(120, 14400)] [int] $Seconds = 1800,
    [ValidateRange(1, 600)]    [int] $SampleSeconds = 20,
    [ValidateRange(1, 64)]     [int] $Converters = 16,
    [ValidateRange(1, 64)]     [int] $Tight = 2,
    [ValidateRange(1, 8)]      [int] $Heaters = 1,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$rigName  = 'rf-converter-buffer-rig'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-cbuf-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

function Write-Rig {
    @{
        name = $rigName; version = '0.0.1'; title = 'Converter buffering probe'
        author = 'probe-converter-buffer.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed', 'realistic-fusion-refreshed-core')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

    # NO Write-PlasmaFeed, DELIBERATELY. Every other rig here needs one, because a vanilla infinity
    # pipe cannot reach a plasma box (#26). This one plumbs plasma with the shipped rf-pipe from the
    # heater's own outlet, which is what a player does, and the only infinity pipes it places carry
    # rf-d-he3-mix -- a Core fluid with no connection category. Calling the helper anyway wrote an
    # unreferenced prototype into the rig and read as a live dependency; it was, and it is gone.

    $lua = @'
-- Generated by scripts/probe-converter-buffer.ps1. Nothing here ships.

local RUN_TICKS    = __RUN_TICKS__
local SAMPLE_TICKS = __SAMPLE_TICKS__
local CONVERTERS   = __CONVERTERS__
local TIGHT        = __TIGHT__
local HEATERS      = __HEATERS__

__QUIETMAP__

local ANEUTRONIC = "rf-aneutronic-reactor"
local CONVERTER  = "rf-direct-energy-converter"
local TANK       = "rf-aneutronic-composite-tank"
local HEATER     = "rf-heater"
local PLASMA     = "rf-d-he3-plasma"
local FEEDSTOCK  = "rf-d-he3-mix"
local ENERGY     = "rf-aneutronic-reactor-energy"

local function say(line) log("CBUF-PROBE " .. line) end
local function must(entity, what)
  if not entity then error(what .. " refused") end
  return entity
end

-- ---------------------------------------------------------------- units
--
-- power_production and power_usage on an electric-energy-interface are joules per TICK, not watts.
-- Nothing in the 2.0 docs says so; check-brownout.ps1 derived it and pins it against vanilla's own
-- steam turbine. A rig silently running on a sixtieth of its intended supply looks exactly like a
-- broken mod, so the conversion lives in one named place here too.
local function watts(w) return w / 60 end

-- ---------------------------------------------------------------- geometry
--
-- An odd-sized entity centres on a tile centre and an even one on a tile boundary, and placing
-- either off its own parity puts it half a tile out with nothing erroring (#49). Every footprint
-- here is read off its own prototype rather than remembered -- both machines in this rig have
-- already changed size twice.
local function footprint(name)
  local box = prototypes.entity[name].selection_box
  return math.floor(box.right_bottom.x - box.left_top.x + 0.5),
         math.floor(box.right_bottom.y - box.left_top.y + 0.5)
end

local function origin_of(name)
  local w = footprint(name)
  return (w % 2 == 1) and 0.5 or 0.0
end

local function centre(v, origin)
  if origin == 0.5 then return math.floor(v) + 0.5 else return math.floor(v + 0.5) end
end

local function box_of(entity, fluid)
  for index = 1, #entity.fluidbox do
    local filter = entity.fluidbox.get_filter(index)
    if filter and filter.name == fluid then return index end
  end
  return nil
end

local function holds(entity, fluid)
  local total = 0
  for index = 1, #entity.fluidbox do
    local contents = entity.fluidbox[index]
    if contents and contents.name == fluid then total = total + contents.amount end
  end
  return total
end

--- Energy fluid sitting still anywhere in a cell's chain: the reactor's output box, every
--- converter's box, and the tank if there is one.
---
--- It is not loss and must never be counted as such -- fluid in a box at the horizon is fluid the
--- chain BUFFERED, which is the very thing under measurement. It is also why the tank's cell reads
--- kindly while the tank is still filling, and why the report prints a last-quarter figure beside
--- the whole-run one.
local function stored_of(cell)
  local total = holds(cell.reactor, ENERGY)
  for _, converter in ipairs(cell.converters) do total = total + holds(converter, ENERGY) end
  if cell.tank then total = total + holds(cell.tank, ENERGY) end
  return total
end

local function status_name(status)
  for name, value in pairs(defines.entity_status) do
    if value == status then return name end
  end
  return "unknown"
end

--- The extreme connection of an entity's fluid box `index`, along one axis. Carried from
--- check-brownout.ps1 unchanged.
local function edge_connection(entity, index, pick)
  local conns = entity.fluidbox.get_pipe_connections(index)
  if not conns or #conns == 0 then error(entity.name .. " has no connections on box " .. index) end
  local best = conns[1].target_position
  for _, c in ipairs(conns) do if pick(c.target_position, best) then best = c.target_position end end
  return best
end

local NORTHMOST = function(a, b) return a.y < b.y end
local SOUTHMOST = function(a, b) return a.y > b.y end
local WESTMOST  = function(a, b) return a.x < b.x end

--- A run of pipe along axis-aligned legs through `points`, laid inclusively.
---
--- Carried from check-brownout.ps1, with ONE addition: a tile that already carries this pipe is
--- adopted rather than re-placed. Several heaters share one manifold here, so the legs overlap by
--- construction -- and create_entity answers nil on an occupied tile, which must() would report as
--- a refused placement rather than as the harmless collision it is.
local function route(surface, force, name, points, label)
  local laid = {}
  local function put(x, y)
    local existing = surface.find_entity(name, { x, y })
    if existing then laid[#laid + 1] = existing; return end
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
    -- grid or the walk steps straight past its target and runs for ever.
    if (to.x - x) % 1 ~= 0 or (to.y - y) % 1 ~= 0 then
      error(string.format("%s: leg %d runs between tile halves -- (%g, %g) to (%g, %g)",
        label, i, x, y, to.x, to.y))
    end
    while x ~= to.x do x = x + (to.x > x and 1 or -1); put(x, y) end
    while y ~= to.y do y = y + (to.y > y and 1 or -1); put(x, y) end
  end
  return laid
end

--- Infinity pipes on every connection of one fluid box.
local function feed(surface, force, entity, fluid, label)
  local index = box_of(entity, fluid)
  if not index then error(label .. ": " .. entity.name .. " has no box that takes " .. fluid) end
  for _, connection in pairs(entity.fluidbox.get_pipe_connections(index)) do
    local pipe = must(surface.create_entity({
      name = "infinity-pipe", position = connection.target_position, force = force,
    }), label .. ": supply of " .. fluid)
    pipe.set_infinity_pipe_filter({ name = fluid, percentage = 1, mode = "at-least" })
  end
  return index
end

--- Substations at every listed point, asserted onto ONE network.
---
--- Asserted where they are built rather than inferred later from an entity turning out to be
--- powered: one network per cell is the thing being built, and asserting it here names the culprit
--- if a chain breaks. Fourteen tiles apart both chains and covers, against a substation's eighteen
--- of wire and eighteen-square supply area.
local function grid(surface, force, label, points)
  local poles = {}
  for _, at in ipairs(points) do
    poles[#poles + 1] = must(surface.create_entity({
      name = "substation", position = at, force = force,
    }), string.format("%s: substation at (%g, %g)", label, at[1], at[2]))
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
  -- THE BUFFER HAS TO GO. Vanilla's electric-energy-interface ships an enormous electric buffer --
  -- it is the editor's infinite power source, and the buffer is how it also works as an infinite
  -- sink. check-brownout.ps1 lost a whole run to it, and every cut cell read identical to the uncut
  -- one. Ten megajoules here, which against this rig's cells is five to fifty MILLISECONDS of their
  -- draw: a cell draws the reactor's 200 MW of confinement heating plus the heater's 5 MW plus the
  -- load bank's load_w, so 10 MJ buys 4.7 ms in a sixteen-converter cell, 22.5 ms in a
  -- two-converter one and 48.8 ms in `open`, which has no load bank at all.
  --
  -- IT SAID "FOUR TO FOURTEEN" AND THAT WAS WRONG, caught in review on #284 after the merge. The
  -- upper bound had been divided into what the SOURCE interface produces -- load_w + 500e6 -- rather
  -- than into the draw the sentence names. Recorded rather than quietly corrected, because a figure
  -- beside a constant is the justification for the constant, and this repository has been bitten by
  -- exactly that before.
  --
  -- check-brownout.ps1 calls the same 10e6 a fifth of a second, correctly, because its cells are a
  -- fraction of the size; the figure does not carry across and the reason does -- a buffer this small
  -- cannot stand in for a supply.
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
-- Everything is placed in the cell's own frame off `ox`, so five cells are the same build in five
-- places rather than five builds.
--
--   ox              the reactor, and the converter row stacked north off its energy face
--   ox+11ish        the pole column, clear of the fifteen-wide machines' east edge
--   south and west  the plasma manifold and the heaters
local function build_cell(surface, force, o)
  local label  = o.label
  local origin = origin_of(ANEUTRONIC)
  local rx, ry = centre(o.ox, origin), centre(0, origin)
  local cell   = {
    label = label, drain = o.drain == true, converters = {},
    row_j = 0, sold = 0, full_ticks = 0, full_status_ticks = 0, ticks = 0, capacity = 0,
    all_working_ticks = 0, dead_ticks = 0, stalls = 0, was_all_working = false,
    win_j = 0, win_ticks = 0, windows = {},
    interval_j = 0, interval_ticks = 0, interval_min = nil, interval_max = nil,
    interval_working = 0, interval_dead = 0,
  }

  local reactor = must(surface.create_entity({
    -- raise_built so realistic-fusion-refreshed registers it: the mod picks reactors up from the
    -- build event and rescans only at its own on_init, which has already run by now.
    name = ANEUTRONIC, position = { rx, ry }, force = force, raise_built = true,
  }), label .. ": " .. ANEUTRONIC)
  cell.reactor = reactor

  -- The reactor's plasma box is index 1 and is deliberately unfiltered (#28), so it cannot be found
  -- by the fluid it takes. Its energy box is filtered and is found by name.
  cell.energy_index = box_of(reactor, ENERGY)
  if not cell.energy_index then error(label .. ": the reactor has no energy box") end

  -- ------------------------------------------------------------------ the converter row
  --
  -- ROTATED, AND THAT IS THE POINT OF THE SHAPE. #45 put this machine's connections on its long
  -- faces, so butted against a reactor it touches along its whole fifteen tiles. The reactor sells
  -- through its north face, so the converter has to lie sideways for a long face to meet it. Turned
  -- WEST: a quarter turn anticlockwise sends the west-facing connection to (0, +reach) pointing
  -- south, which is the one that can meet a north-facing output. Turning it the other way puts that
  -- connection on the far side and it meets nothing. check-aneutronic.ps1 carries the same note.
  --
  -- THE ALIGNMENT ARITHMETIC IS A TRAP AND ADR 0018 WROTE IT DOWN: a pipe run aligns a connection's
  -- target_position onto the tile the pipe occupies, but a DIRECT BOLT aligns one machine's
  -- connection tile onto the other's target_position. Align target against target and the two sit
  -- one tile clear of each other pointing at the same empty ground, which is indistinguishable from
  -- a refused connection. Every join in this cell is asserted below for exactly that reason.
  local out_target = reactor.fluidbox.get_pipe_connections(cell.energy_index)[1].target_position
  local short      = footprint(CONVERTER)
  local reach      = short / 2 - 0.5
  for i = 0, (o.converters or 0) - 1 do
    cell.converters[#cell.converters + 1] = must(surface.create_entity({
      name = CONVERTER, direction = defines.direction.west,
      position = { out_target.x, out_target.y - reach - i * short },
      force = force, raise_built = true,
    }), string.format("%s: %s %d", label, CONVERTER, i))
  end

  -- ------------------------------------------------------------------ the tank, bolted
  --
  -- Onto the far end of the row, with no pipe. The offset is measured off a scratch tank rather
  -- than written down: a storage tank's connections sit off its centre by a vector this rig has no
  -- business remembering, and the bolt arithmetic above needs the connection TILE, which is the
  -- target one tile back towards the machine.
  if o.tank and #cell.converters > 0 then
    local last  = cell.converters[#cell.converters]
    local north = edge_connection(last, 1, NORTHMOST)

    -- INSIDE THE CLEARED RECTANGLE, and this was a real bug rather than a tidy-up. The scratch
    -- used to go to y = -400, which is outside both the chunks on_init generates and the ground it
    -- landfills and clears -- so it landed on raw terrain, and one tree or rock on that tile makes
    -- create_entity answer nil and aborts the whole run. The map has no fixed seed, so it would have
    -- failed on some runs and not others. y + 34 is south of everything this cell builds -- the pole
    -- row is at y + 21 and the heaters' feedstock pipes at y + 18.5 -- and well inside the rectangle.
    local scratch = must(surface.create_entity({
      name = TANK, force = force,
      position = { centre(o.ox, origin_of(TANK)), centre(34, origin_of(TANK)) },
    }), label .. ": scratch " .. TANK)
    local south = edge_connection(scratch, 1, SOUTHMOST)
    local dx, dy = south.x - scratch.position.x, south.y - scratch.position.y
    scratch.destroy()
    if dy <= 0 then error(label .. ": the tank has no south-facing connection to bolt with") end

    cell.tank = must(surface.create_entity({
      name = TANK, position = { north.x - dx, north.y - (dy - 1) }, force = force,
    }), label .. ": " .. TANK)
    if #cell.tank.fluidbox.get_connections(1) == 0 then
      error(label .. ": the tank was placed but joined nothing -- the bolt arithmetic is wrong")
    end
  end

  -- ------------------------------------------------------------------ power
  --
  -- Two interfaces, and the split matters. The SOURCE covers everything the cell can possibly draw,
  -- so the reactor's confinement heating is never rationed -- this probe is about fluid, and a
  -- brownout would turn every reading into a power reading. The LOAD is what makes the converters
  -- run at all: a generator produces what the network demands, so a row with nothing to feed sits
  -- idle and a rig without a load bank measures an idle row. It is sized past the row's whole
  -- capacity so the converters are never demand-limited, and the vanilla interface's own
  -- usage_priority is printed at setup, because "tertiary" is what keeps the source from competing
  -- with the secondary-output converters for that load.
  local row_w  = (o.converters or 0) * 100e6
  local load_w = row_w * 1.2
  local rw, rh = footprint(ANEUTRONIC)
  local px     = math.floor(o.ox) + math.floor(rw / 2) + 4
  local top    = (#cell.converters > 0)
    and (cell.converters[#cell.converters].position.y - short) or (ry - rh)

  -- The column runs north from y+9 -- clear of the reactor's south edge at 7.75 and of the plasma
  -- manifold two rows further south -- and every gap is fourteen, which both chains and covers.
  local points = {}
  local y = math.floor(ry) + 9
  while y > top - 14 do points[#points + 1] = { px, y }; y = y - 14 end
  -- And a second row SOUTH of the heaters, chained off the column, so the heaters end up on the
  -- cell's network rather than on one of their own. South rather than between the heaters and the
  -- manifold, because a substation is two tiles wide and the heater row's own pitch would sooner or
  -- later put one inside a heater -- which is a refused placement at -Heaters 2, not at 1, and
  -- therefore exactly the kind of thing that hides.
  local hy = math.floor(ry) + 21
  points[#points + 1] = { px, hy }
  local hx = px - 14
  local west_limit = math.floor(o.ox) - 18 - HEATERS * 5
  while hx > west_limit do points[#points + 1] = { hx, hy }; hx = hx - 14 end
  cell.poles = grid(surface, force, label, points)

  cell.source = interface(surface, force, cell.poles, { px, math.floor(ry) - 2 },
    load_w + 500e6, 0, label .. " source")
  if load_w > 0 then
    cell.load = interface(surface, force, cell.poles, { px, math.floor(ry) + 2 },
      0, load_w, label .. " load")
  end

  -- ------------------------------------------------------------------ the fuel line
  --
  -- Heaters south of the reactor, each routed north onto one shared manifold, which runs east to the
  -- reactor's own westmost plasma inlet. The manifold's row is clear of both the reactor's south
  -- edge and the heaters' north edge, both read off their prototypes.
  --
  -- FACING SOUTH, so that its outlets face NORTH, and that rotation is load-bearing rather than
  -- tidy. rf-heater is a vanilla chemical plant, whose two output boxes are both on its south face;
  -- unrotated, a leg from an outlet towards a manifold to its north walks straight back through the
  -- machine. The first version of this rig assumed a north outlet and refused to build, which is the
  -- right way round for that mistake to happen.
  local inlet    = edge_connection(reactor, 1, WESTMOST)
  local hw, hh   = footprint(HEATER)
  local manifold = math.floor(ry) + math.floor(rh / 2) + 4 + (inlet.y % 1)
  local heater_y = manifold + math.ceil(hh / 2) + 2
  cell.heaters, cell.outlets = {}, {}
  for i = 1, HEATERS do
    local heater = must(surface.create_entity({
      name = HEATER, force = force, direction = defines.direction.south,
      position = { centre(o.ox - 12 - (i - 1) * (hw + 2), origin_of(HEATER)),
                   centre(heater_y, origin_of(HEATER)) },
    }), string.format("%s: %s %d", label, HEATER, i))
    heater.set_recipe(PLASMA)
    feed(surface, force, heater, FEEDSTOCK, label)
    cell.heaters[#cell.heaters + 1] = heater

    -- The northmost plasma outlet, so the leg walks AWAY from the machine towards the manifold: a
    -- connection target already sits one tile outside the footprint, so walking north from the
    -- northmost one cannot re-enter it, whichever face it is on.
    local outlet = edge_connection(heater, box_of(heater, PLASMA), NORTHMOST)
    if outlet.y > heater.position.y then
      error(label .. ": the heater's only plasma outlet faces south, and the manifold is north")
    end
    cell.outlets[#cell.outlets + 1] = outlet
  end

  local min_x, max_x = inlet.x, inlet.x
  for _, outlet in ipairs(cell.outlets) do
    if outlet.x < min_x then min_x = outlet.x end
    if outlet.x > max_x then max_x = outlet.x end
  end
  local line = route(surface, force, "rf-pipe", {
    { x = min_x, y = manifold }, { x = max_x, y = manifold },
  }, label .. ": manifold")
  route(surface, force, "rf-pipe", { { x = inlet.x, y = manifold }, inlet }, label .. ": inlet leg")
  for i, outlet in ipairs(cell.outlets) do
    route(surface, force, "rf-pipe", { outlet, { x = outlet.x, y = manifold } },
      string.format("%s: heater %d leg", label, i))
  end

  -- That the feed line really did reach the reactor. Without this the failure mode is a reactor
  -- reporting itself starved on a cell whose pipe run missed by a tile, which reads exactly like a
  -- broken mod. Asked of the PIPE rather than of the heater's own box: a heater's plasma box is
  -- declared "output" and only an input-output box joins the segment it is plumbed to, so the heater
  -- has no segment to ask (#47, ADR 0011).
  local from = line[1].fluidbox.get_fluid_segment_id(1)
  local to   = reactor.fluidbox.get_fluid_segment_id(1)
  if from == nil or from ~= to then
    error(string.format("%s: the feed line and the reactor are on segments %s and %s",
      label, tostring(from), tostring(to)))
  end
  for i, heater in ipairs(cell.heaters) do
    if #heater.fluidbox.get_connections(box_of(heater, PLASMA)) == 0 then
      error(string.format("%s: heater %d's plasma outlet is not connected to the manifold", label, i))
    end
  end
  cell.pipes = #line

  -- ------------------------------------------------------------------ every join, asserted
  --
  -- get_connections, which hands back the fluid boxes actually joined to this one. Two other ways
  -- of asking were tried in check-aneutronic.ps1 and both lied: connection.target.owner answers nil,
  -- and connection.connected answers false on every connection of a machine that is visibly passing
  -- fluid to its neighbour.
  if #cell.converters > 0 then
    if #reactor.fluidbox.get_connections(cell.energy_index) == 0 then
      error(label .. ": the first converter did not bolt to the reactor's energy face")
    end
    for i = 2, #cell.converters do
      if #cell.converters[i].fluidbox.get_connections(1) == 0 then
        error(string.format("%s: converter %d joined nothing -- the row is broken", label, i))
      end
    end
  end

  say(string.format(
    "build  cell=%-9s converters=%d tank=%s heaters=%d poles=%d manifold=%d rowMW=%.5g loadMW=%.5g",
    label, #cell.converters, cell.tank and "yes" or "no", #cell.heaters, #cell.poles, cell.pipes,
    row_w / 1e6, load_w / 1e6))
  return cell
end

-- ---------------------------------------------------------------- build

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player
  force.research_all_technologies()

  surface.request_to_generate_chunks({ 0, 0 }, 12)
  surface.force_generate_chunk_requests()
  -- After the chunks, not before: find_entities_filtered only sees entities in chunks that already
  -- exist, so a nest in ground generated afterwards survives the clearing.
  local quieted = __QUIETFN__(surface)

  -- A hundred and twenty apart, which is what keeps the five cells on five electric networks at
  -- every -Heaters this rig accepts: a cell reaches from its westmost heater pole to its own column,
  -- and at eight heaters that is still forty-six tiles clear of the next cell against a
  -- substation's eighteen of wire. Asserted below rather than left to the arithmetic.
  local PITCH = 120
  local x0, x1 = -70, PITCH * 4 + 30
  local y0, y1 = -40 - 6 * CONVERTERS, 40
  local tiles = {}
  for x = x0, x1 do
    for y = y0, y1 do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = { { x0, y0 }, { x1, y1 } } })) do
    if e.type ~= "character" then e.destroy() end
  end

  storage.cells = {
    build_cell(surface, force, { label = "long",     ox = 0,         converters = CONVERTERS }),
    build_cell(surface, force, { label = "longtank", ox = PITCH,     converters = CONVERTERS, tank = true }),
    build_cell(surface, force, { label = "tight",    ox = PITCH * 2, converters = TIGHT }),
    build_cell(surface, force, { label = "tighttank", ox = PITCH * 3, converters = TIGHT, tank = true }),
    -- No converters at all, and its output box emptied every tick by on_tick. The denominator.
    build_cell(surface, force, { label = "open",     ox = PITCH * 4, converters = 0, drain = true }),
  }

  -- FIVE NETWORKS, NOT ONE. grid() asserts that a cell's own substations chained; it cannot see
  -- two cells that chained to each other, which is the failure that would matter -- the load bank in
  -- one cell would then be drawing on another cell's converters and every megawatt figure would be a
  -- figure about the wrong row.
  local seen = {}
  for _, cell in ipairs(storage.cells) do
    local id = cell.poles[1].electric_network_id
    if seen[id] then
      error(string.format("%s shares an electric network with %s", cell.label, seen[id]))
    end
    seen[id] = cell.label
  end

  -- The field the whole burstiness answer rests on. Checked once, here, rather than discovered as a
  -- run of zeroes: an absent field would report a row that generated nothing, which is
  -- indistinguishable from a row that stalled for fifteen minutes.
  local sample = storage.cells[1].converters[1]
  local ok, value = pcall(function() return sample.energy_generated_last_tick end)
  if not (ok and type(value) == "number") then
    error("LuaEntity::energy_generated_last_tick is not readable on a generator in this engine " ..
      "version; this probe measures power through it and needs rewriting before it can answer")
  end

  local priority = prototypes.entity["electric-energy-interface"]
    .electric_energy_source_prototype.usage_priority
  say(string.format("setup  ticks=%d sample=%d quieted=%d interface_priority=%s",
    RUN_TICKS, SAMPLE_TICKS, quieted, tostring(priority)))
  -- The three buffers the answer is a comparison between, printed rather than left to a reader's
  -- arithmetic: a converter's box volume off the prototype, times the row, against the tank's.
  local box_u = prototypes.entity[CONVERTER].fluidbox_prototypes[1].volume or -1
  say(string.format("buffer converter_box=%.6gu long_row=%.6gu tight_row=%.6gu reactor_box=%.6gu tank=%.6gu",
    box_u, box_u * CONVERTERS, box_u * TIGHT,
    prototypes.entity[ANEUTRONIC].fluidbox_prototypes[2].volume or -1,
    prototypes.entity[TANK].fluidbox_prototypes[1].volume or -1))
end)

-- ---------------------------------------------------------------- per tick

script.on_event(defines.events.on_tick, function()
  local cells = storage.cells
  if not cells then return end
  local tick = game.tick

  for _, cell in ipairs(cells) do
    if not cell.reactor.valid then
      error(cell.label .. ": its reactor is gone -- something destroyed part of the rig mid-run")
    end

    -- The reactor's own output, and whether the box that carries it is pinned full. apply() clamps
    -- its write to the box's capacity and discards the rest in silence, so a full box is the only
    -- observable trace of loss inside a cell that has converters on it.
    --
    -- READ THIS BEFORE READING outbox_full, BECAUSE THE FIGURE IS NOT WHAT IT LOOKS LIKE. Its
    -- ceiling is one tick in six, not every tick: control.lua's UPDATE_INTERVAL is 6, so apply()
    -- tops this box up on one tick in six and the engine drains it on the other five. A reactor in
    -- permanent overflow therefore reports about 16.67% here and never 100%, and the measured 13.25%
    -- is a box that was full on every step tick from t = 480 s to the end of a 1800-second run.
    --
    -- Two consequences worth having in front of a reader. The SAMPLE LINE lands on multiples of
    -- SAMPLE_TICKS, which is a whole number of seconds and therefore always a multiple of six, so
    -- its outbox column is always read on a step tick and reads full whenever the reactor is
    -- overflowing at all -- which is why the trace shows 1000 throughout a run this figure calls
    -- 13.25%. And the two are not in conflict: what says when the overflow STARTED is the trace,
    -- and what says it never stopped is this number sitting at its own ceiling.
    --
    -- The tolerance is half a unit rather than an epsilon because the amount is a float near 1000
    -- and an exact comparison would depend on rounding. The ENGINE'S OWN ANSWER is counted beside
    -- it and needs no tolerance at all: a machine that cannot sell what it makes reports
    -- entity_status.full_output. The two agreed to the printed digit in every cell of every run so
    -- far, which is what makes the tolerance safe; they are printed together so a future
    -- disagreement is visible rather than settled by whichever line a reader happened to look at.
    local produced = cell.reactor.fluidbox[cell.energy_index]
    local capacity = cell.reactor.fluidbox.get_capacity(cell.energy_index)
    cell.capacity = capacity
    if produced and produced.amount >= capacity - 0.5 then
      cell.full_ticks = cell.full_ticks + 1
    end
    if cell.reactor.status == defines.entity_status.full_output then
      cell.full_status_ticks = cell.full_status_ticks + 1
    end
    if cell.drain and produced then
      cell.sold = cell.sold + produced.amount
      cell.reactor.fluidbox[cell.energy_index] = nil
    end

    local tick_j, working, generating = 0, 0, 0
    for _, converter in ipairs(cell.converters) do
      local j = converter.energy_generated_last_tick
      tick_j = tick_j + j
      if j > 0 then generating = generating + 1 end
      if converter.status == defines.entity_status.working then working = working + 1 end
    end
    cell.row_j          = cell.row_j + tick_j
    cell.win_j          = cell.win_j + tick_j
    cell.interval_j     = cell.interval_j + tick_j
    cell.ticks          = cell.ticks + 1
    cell.win_ticks      = cell.win_ticks + 1
    cell.interval_ticks = cell.interval_ticks + 1

    if #cell.converters > 0 then
      local all = (working == #cell.converters)
      if all then cell.all_working_ticks = cell.all_working_ticks + 1 end
      -- A stall is an EVENT, not an average: "stalls and restarts" is what the argument claims, and
      -- a mean that never moves can hide any number of them.
      if cell.was_all_working and not all then cell.stalls = cell.stalls + 1 end
      cell.was_all_working = all
      if generating == 0 then cell.dead_ticks = cell.dead_ticks + 1 end
      if cell.interval_min == nil or tick_j < cell.interval_min then cell.interval_min = tick_j end
      if cell.interval_max == nil or tick_j > cell.interval_max then cell.interval_max = tick_j end
      cell.interval_working = cell.interval_working + (all and 1 or 0)
      cell.interval_dead    = cell.interval_dead + (generating == 0 and 1 or 0)
    end
  end

  if tick > 0 and tick % SAMPLE_TICKS == 0 then
    for _, cell in ipairs(cells) do
      local plasma = cell.reactor.fluidbox[1]
      local out    = cell.reactor.fluidbox[cell.energy_index]
      local n      = math.max(cell.interval_ticks, 1)
      say(string.format(
        "sample cell=%-9s t=%d rowMW=%.5g tickMWmin=%.5g tickMWmax=%.5g allworking=%d/%d dead=%d " ..
        "plasma=%.4gC/%.5gu outbox=%.7gu/%.6gu tank=%.6gu reactor=%s soldu=%.6g",
        cell.label, tick,
        cell.interval_j / n * 60 / 1e6,
        (cell.interval_min or 0) * 60 / 1e6,
        (cell.interval_max or 0) * 60 / 1e6,
        cell.interval_working, n, cell.interval_dead,
        plasma and plasma.temperature or 0, plasma and plasma.amount or 0,
        out and out.amount or 0, cell.capacity,
        cell.tank and holds(cell.tank, ENERGY) or 0,
        status_name(cell.reactor.status), cell.sold))
      cell.interval_j, cell.interval_ticks = 0, 0
      cell.interval_min, cell.interval_max = nil, nil
      cell.interval_working, cell.interval_dead = 0, 0
    end
  end

  -- Quarters, for the convergence claim. Recorded as they close rather than reconstructed from the
  -- printed samples, so the figure a reader is asked to trust is not a re-average of rounded rows.
  local quarter = math.floor(RUN_TICKS / 4)
  if quarter > 0 and tick > 0 and tick <= RUN_TICKS and tick % quarter == 0 then
    for _, cell in ipairs(cells) do
      cell.windows[#cell.windows + 1] = {
        mw = cell.win_j / math.max(cell.win_ticks, 1) * 60 / 1e6,
        soldu = cell.sold,
        deliveredu = cell.row_j / 1e6,
        storedu = stored_of(cell),
      }
      cell.win_j, cell.win_ticks = 0, 0
    end
  end

  if tick >= RUN_TICKS and not storage.reported then
    storage.reported = true

    local open
    for _, cell in ipairs(cells) do if cell.drain then open = cell end end

    -- Seconds in one quarter, so a cumulative sold total can be printed as the rate it represents.
    local quarter_s = math.floor(RUN_TICKS / 4) / 60

    --- What the reactor sold during window `i` alone, in units a second. Differenced from the
    --- cumulative totals rather than tracked separately, so the rate and the total cannot disagree.
    local function sold_rate(w, i)
      if i == 1 then return w[1].soldu / quarter_s end
      return (w[i].soldu - w[i - 1].soldu) / quarter_s
    end

    for _, cell in ipairs(cells) do
      for i, w in ipairs(cell.windows) do
        -- Only the drained cell has a sale rate. Printed as n/a rather than 0 for the others,
        -- because a zero in that column is a measurement of nothing dressed as a measurement.
        say(string.format("window cell=%-9s quarter=%d rowMW=%.5g soldu=%.6g solduPerS=%s",
          cell.label, i, w.mw, w.soldu,
          cell.drain and string.format("%.5g", sold_rate(cell.windows, i)) or "n/a"))
      end
      local w, drift = cell.windows, "n/a"
      if #w >= 2 and w[#w - 1].mw > 0 then
        drift = string.format("%+.2f%%", (w[#w].mw - w[#w - 1].mw) / w[#w - 1].mw * 100)
      end

      -- THE REACTOR'S OWN CONVERGENCE, and the figure the whole run's validity rests on. `drift`
      -- above is the ROW's, and a row that has saturated reports +0.00% while the reactor behind it
      -- is still lighting -- which is the one way this probe could report a settled answer to a
      -- question it had not finished asking. Only the `open` cell drains, so only it has this.
      local solddrift = "n/a"
      if cell.drain and #w >= 2 then
        local previous = sold_rate(w, #w - 1)
        if previous > 0 then
          solddrift = string.format("%+.2f%%", (sold_rate(w, #w) - previous) / previous * 100)
        end
      end

      local delivered_u = cell.row_j / 1e6
      local stored_u    = stored_of(cell)

      -- The cross-check on the joule accounting. Both categories are printed because which one of
      -- input/output holds an electric network's generation is undocumented, and the loss figure
      -- rests on this total being right.
      local stats = cell.poles[1].electric_network_statistics
      local net_in  = stats and stats.get_input_count(CONVERTER) or 0
      local net_out = stats and stats.get_output_count(CONVERTER) or 0

      -- Delivered PLUS stored, because fluid sitting in a box at the horizon was not lost -- it was
      -- buffered, which is the very thing under measurement. Counting it as loss would charge the
      -- chain for doing its job.
      local loss = "n/a"
      if open and open.sold > 0 and #cell.converters > 0 then
        loss = string.format("%.2f%%", (1 - (delivered_u + stored_u) / open.sold) * 100)
      end

      -- AND THE SAME FIGURE OVER THE LAST QUARTER ALONE, which is the one the tank's case turns on.
      -- A tank absorbs its fifty thousand units ONCE, while it fills; a whole-run figure credits
      -- that one-off against a whole run's output and reads as a steady saving it is not. The last
      -- quarter is past the fill, so what it shows is what the vessel is worth for ever after.
      local steady = "n/a"
      if open and #cell.windows >= 2 and #cell.converters > 0 then
        local n = #cell.windows
        local sold_q = open.windows[n].soldu - open.windows[n - 1].soldu
        local got_q  = (cell.windows[n].deliveredu - cell.windows[n - 1].deliveredu)
                     + (cell.windows[n].storedu - cell.windows[n - 1].storedu)
        if sold_q > 0 then steady = string.format("%.2f%%", (1 - got_q / sold_q) * 100) end
      end

      say(string.format(
        "result cell=%-9s meanMW=%.5g rowdrift=%s solddrift=%s deliveredu=%.6g storedu=%.6g " ..
        "soldu=%.6g lost_run=%s lost_lastquarter=%s allworking=%.2f%% dead=%.2f%% stalls=%d " ..
        "outbox_full=%.2f%% full_output=%.2f%% netinMJ=%.6g netoutMJ=%.6g",
        cell.label, cell.row_j / math.max(cell.ticks, 1) * 60 / 1e6, drift, solddrift,
        delivered_u, stored_u, cell.sold, loss, steady,
        cell.all_working_ticks / math.max(cell.ticks, 1) * 100,
        cell.dead_ticks / math.max(cell.ticks, 1) * 100,
        cell.stalls,
        cell.full_ticks / math.max(cell.ticks, 1) * 100,
        cell.full_status_ticks / math.max(cell.ticks, 1) * 100,
        net_in / 1e6, net_out / 1e6))

      -- Where the shortfall lands along the row. A demand-rich row does not starve evenly, and this
      -- is the profile a mean cannot show: the front converters are fed off the reactor's face and
      -- the tail off whatever crossed every join to reach them.
      local profile = {}
      for i, converter in ipairs(cell.converters) do
        profile[#profile + 1] = string.format("%d:%.0fu/%s", i, holds(converter, ENERGY),
          status_name(converter.status):sub(1, 7))
      end
      if #profile > 0 then
        say(string.format("profile cell=%-9s %s", cell.label, table.concat(profile, " ")))
      end
    end
    say("done")
  end
end)
'@

    $lua = $lua.
        Replace('__QUIETMAP__',     (Get-QuietMapLua)).
        Replace('__QUIETFN__',      $script:QuietMapFunction).
        Replace('__RUN_TICKS__',    "$($Seconds * 60)").
        Replace('__SAMPLE_TICKS__', "$($SampleSeconds * 60)").
        Replace('__CONVERTERS__',   "$Converters").
        Replace('__TIGHT__',        "$Tight").
        Replace('__HEATERS__',      "$Heaters")
    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') -Value $lua
}

$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled @() -Mods ($ourMods + $rigName)
    Write-Rig

    $save = Join-Path $temp 'converter-buffer.zip'
    # BOTH STEPS ARE READ, and the create step is not incidental: on_init runs when the map is
    # MADE, so every build line -- the buffer volumes, the network setup, the interface priority --
    # is logged there and nowhere else. An earlier version piped this step to Out-Null and silently
    # dropped the whole of the rig's own description of what it had built.
    $createOut = Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create'
    $runOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', "$($Seconds * 60 + 120)",
        '--benchmark-runs', '1', '--disable-audio')

    # -Path, not a pipe: Get-Content binds a path from the pipeline only by property name, so
    # piping two plain strings into it fails at the END of a run that has already taken its half
    # hour. Named explicitly for that reason.
    $reported = @(Get-Content -Path @($createOut, $runOut) | Select-String -Pattern 'CBUF-PROBE ' |
        ForEach-Object { ($_ -split 'CBUF-PROBE ', 2)[1].TrimEnd() })
    if ($reported.Count -eq 0) { throw 'the rig reported nothing; it never reached its report tick.' }

    foreach ($line in $reported) { Write-Host "  $line" }

    # The sentinel, for the reason probe-quality-equilibrium.ps1 checks for one: a rig that died part
    # way through its report prints rows that look exactly like a complete run.
    if (-not ($reported | Where-Object { $_ -eq 'done' })) {
        throw 'the rig stopped before the end of its report; the rows above are incomplete.'
    }

    Write-Host ''
    Write-Host 'OK - the probe ran and every row reported. The answers are above, and they are'
    Write-Host '     measurements rather than a verdict, so nothing here passes or fails.'
    Write-Host '     docs/research/converter-buffering.md is what they are read into.'
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'probe-converter-buffer' }
}

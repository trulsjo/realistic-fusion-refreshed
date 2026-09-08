<#
.SYNOPSIS
    Measures how much fluid this mod's own links carry, at a running equilibrium. Discharges #48.

.DESCRIPTION
    #47 measured what the engine will pass through a fluid link: 100 units per tick per connection
    flush, falling to a floor of 50 through a long run of pipe. Those are ceilings. This measures
    the load, so the two can be read as a ratio.

    Two links are candidates, both because a predecessor built them flush and multi-connected:

      plasma   rf-heater's output box into the reactor's input-output plasma box, through pipe.
      energy   The reactor's rf-reactor-energy output box into rf-heat-exchanger's input, BOLTED
               face to face with no pipe at all -- since #86 there is no pipe in the game that
               carries the fluid.

    MEASURED, NOT DERIVED

    Both rates are derivable from fuel_value and the reactor's output, and #48 says plainly not to:
    the derivation rests on the same equilibrium assumptions #37 is still open about. So this reads
    the fluid out of the game.

    The meter is the source box itself. Every tick, what a source box holds is compared with what
    it held last tick; a decrease is fluid that crossed the link. An increase is production -- the
    reactor writes energy every UPDATE_INTERVAL ticks, the heater completes a craft every couple of
    seconds -- and those ticks are excluded rather than netted, because production and outflow in
    the same tick cannot be separated after the fact.

    The excluded fraction is the check on the method: it should come out at the production cadence
    and nothing more. If a link were idle, excluded ticks would climb far above that and the mean
    would be quietly taken over the busy ones only. Each meter reports its own -- the plasma one as
    plasma_skipped, the energy one as the complement of energy_ticks -- because the two links run at
    different cadences and one shared counter would hide a stall on either.

    EQUILIBRIUM, DEMONSTRATED RATHER THAN ASSUMED

    #37 established that a reactor climbs for about twenty minutes of game time before it settles,
    and that the 93 MW a player reads early is the same reactor mid-climb -- a headroom figure taken
    there understates by 40%.

    So the run is long and reports in windows, and the script refuses to quote a number unless the
    last two windows agree on both the rate and the plasma temperature. That is the demonstration:
    a reactor still climbing does not produce two consecutive windows that agree.

    WHAT IS BUILT

    Two independent cells, because the honest answer needs both.

      chain   A reactor fed by a heater and drained by heat exchangers -- what a player builds, and
              what the energy link actually carries. The first exchanger is BOLTED to the reactor's
              south energy face and each one after it CHAINS off its neighbour's east short end,
              which is the shape ADR 0031 settles and the only shape available: reactor energy
              carries a connection category of its own and no pipe joins it.

              A CHAINED ROW TAKES WATER AT ITS TWO ENDS ONLY, and that is a property of the shape
              rather than a shortcut here. Every interior water connection is consumed by a joint,
              so the row is fed at the first machine's west end and the last one's east end and has
              to serve the middle itself. ADR 0031 measured eight machines fed that way and none
              starved.
      drain   The same reactor with the exchangers replaced by the rigs' categorised energy feed,
              which removes reactor energy as fast as it arrives. Nothing throttles the link, so
              this is the most this mod will ever ask of it, whatever anyone builds downstream.

    Everything around the links is unbounded on purpose -- deuterium in, water in, steam out, all
    infinity pipes -- so that the only thing being measured is the two links themselves. The energy
    link is the exception and cannot be otherwise: nothing but another machine can be put on it.

    THE MAP IS QUIETED, AND A DAMAGED RIG FAILS LOUDLY (#190)

    The default run is 126 000 ticks -- thirty-five minutes -- with five crafting machines running
    the whole time, which is the pollution scripts/check-brownout.ps1 blames for the attack that ate
    a substation at fifty. So it calls the shared guard, Get-QuietMapLua in scripts/factorio-lib.ps1,
    before it builds: pollution off, enemy expansion off, peaceful mode, and the nests already on
    the surface destroyed. The report says so and prints how many enemy entities went, so the
    quieting is visible rather than assumed.

    Every entity a cell is metered through -- the reactor, the exchangers -- and everything that
    keeps it supplied -- the whole heater bank, not only the metered one, and the substations and
    power sources -- is then checked valid once a second. A cell that has lost one errors with the
    cell and the part named.

    WHAT MAKES THAT WORTH DOING IS THE SHAPE OF THE FAILURE, not its probability. This bench does not
    crash when it is damaged; it reports a quiet wrong number. A heater that loses power stops
    crafting, the link goes idle, the excluded fraction climbs, and the mean is taken over the busy
    ticks only -- exactly the way the meter above says this method misleads. The rates in
    docs/research/fluid-link-throughput.md are what would be wrong, and nothing else would say so.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Ticks
    Ticks to run. The default is a little over half an hour of game time, which is comfortably past
    the twenty minutes #37 measured the climb at -- and the equilibrium gate below is what actually
    decides whether it was enough.

.PARAMETER Window
    Ticks per reported window. The last two are what the equilibrium gate compares.

.PARAMETER Exchangers
    Heat exchangers on the chain cell's reactor. Four 40 MW exchangers is 160 MW of demand against
    the 94 MW this rig's D-D reactor settles at, so the link is not demand-limited. Fewer would
    measure the exchangers rather than the reactor.

    ~~the 133 MW #37 settles at~~ is a PRE-#52 figure, from before the radiation term shipped, and
    corrected here for the same reason #88 corrected two others (#89). The conclusion is unchanged
    at every number it has had: 160 MW of demand out-runs 133, 94 and 78.3 alike.

    EIGHT IS WHAT #89 ASKS FOR, and only on -Plasma rf-d-t-plasma. Eight is the number that ticket
    reasons to from the "on the order of 320 MW" that entities.lua's high-capacity steam pair block
    states for an ignited D-T reactor, and THAT FIGURE IS SUPERSEDED by what this script then
    measured: 996 to 1 195 MW, so eight 40 MW
    exchangers take about 26.8% of the reactor rather than matching it. Eight is kept as the number
    #89 asked about rather than raised to the thirty the new figure implies, because the question is
    whether the eighth machine down a chain off ONE bolted connection is fed at all -- and it is
    (docs/research/bolted-joint-throughput.md). The per-exchanger table below is what says so; a row
    whose far end idles reports it there and nowhere else. How many exchangers a reactor SHOULD have
    is #227's, not this switch's.

.PARAMETER Plasma
    Which plasma the heater bank makes, and so which tier the chain is driven by. The heater's own
    input fluid is read off that recipe rather than written down -- D-D eats rf-deuterium and D-T
    eats Core's rf-d-t-mix -- so nothing else in the rig has to know which tier is running.

    THE DEFAULT IS STILL D-D, which is the tier #48 measured and the one every figure in
    docs/research/fluid-link-throughput.md's mod-link section was taken on. rf-d-t-plasma is what
    #89 added it for: this rig's D-D reactor settles at 94 MW flowing -- 78.3 sustained -- and never
    asks much of a bolted joint, so a rig that can only run D-D cannot ask whether the joint is big
    enough for the tier that would strain it.

.PARAMETER Pipes
    Pipes between the heater bank and the reactor, on the PLASMA link only. It used to set the
    distance on both links; since #86 the energy link has no pipes to count, so a run's two rates
    are no longer taken at the same separation and the report says so. Reported beside the result,
    because #47's ceiling depends on it.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/bench-mod-links.ps1
    pwsh -File scripts/bench-mod-links.ps1 -Ticks 24000 -Window 4000 -KeepTemp
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $FactorioExe,
    [ValidateRange(600, 1000000)] [int] $Ticks      = 126000,
    [ValidateRange(300, 100000)]  [int] $Window     = 6000,
    [ValidateRange(1, 12)]        [int] $Exchangers = 4,
    [ValidateSet('rf-d-d-plasma', 'rf-d-t-plasma')] [string] $Plasma = 'rf-d-d-plasma',
    [ValidateRange(1, 20)]        [int] $Pipes      = 3,
    [ValidateRange(1, 8)]         [int] $Heaters    = 4,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = Get-RepoMods
$rigName  = 'rf-links-rig'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

if ($Window -ge $Ticks) { throw "-Window ($Window) must be shorter than -Ticks ($Ticks)." }
if ([int]($Ticks / $Window) -lt 3) {
    throw "-Ticks / -Window is $([int]($Ticks / $Window)); the equilibrium gate compares the last two windows and needs at least three."
}

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-links-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

function Write-Rig {
    @{
        name = $rigName; version = '0.0.1'; title = 'Mod fluid link rig'
        author = 'bench-mod-links.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

    $lua = @'
-- Generated by scripts/bench-mod-links.ps1. Nothing here ships.

local WINDOW     = __WINDOW__
local EXCHANGERS = __EXCHANGERS__
local PIPES      = __PIPES__
local HEATERS    = __HEATERS__

local PLASMA = "__PLASMA__"
local ENERGY = "rf-reactor-energy"
-- Write-EnergyFeed's prototype. It carries BOTH energy categories since #86 -- read off the two
-- shipped reactors' output boxes -- because a vanilla infinity pipe stopped being able to reach an
-- energy box the moment ADR 0018 landed. #84 routed every rig through that one function so this
-- would be an edit there rather than here.
local ENERGY_FEED = "__ENERGYFEED__"

-- create_entity collision-checks nothing, so every silent overlap in this rig got built rather
-- than refused (#215). can_place_entity is the check, and WHICH check matters: at 2.0.77 its
-- build_check_type defaults to ghost_revive
-- (https://lua-api.factorio.com/2.0.77/classes/LuaSurface.html#can_place_entity), which is not
-- what a player placing by hand gets. Named here so the weaker default cannot creep back in, and
-- asserted because an unknown key would read as nil and quietly restore that default.
local BUILD_CHECK = defines.build_check_type.manual
if not BUILD_CHECK then
  error("defines.build_check_type.manual is gone; this rig's placement guard would silently "
    .. "fall back to ghost_revive")
end

-- A position arrives here two ways: written as { x, y } by this script, or read off a connection
-- as a MapPosition. Only the error messages care, and they would rather not care twice.
local function xy(position)
  return position.x or position[1], position.y or position[2]
end

-- EVERY entity this rig builds goes through here, which is the point. Guarding only the two
-- functions that placed the exchangers would have left pipe_run, the drain's infinity pipe, the
-- reactor and the power islands still placing silently into whatever is already there -- and
-- pipe_run's own comment has said "create_entity does not collision-check" the whole time.
local function place_or_die(surface, spec, what)
  local x, y = xy(spec.position)
  if not surface.can_place_entity({
    name = spec.name, position = spec.position, force = spec.force,
    direction = spec.direction, build_check_type = BUILD_CHECK,
  }) then
    error(string.format("%s will not fit at (%g, %g): something is already there, so this rig's "
      .. "layout is stale against that prototype's footprint", what, x, y))
  end
  local entity = surface.create_entity(spec)
  if not entity then error(string.format("%s refused at (%g, %g)", what, x, y)) end
  return entity
end

-- The recipe that makes PLASMA, named rather than discovered.
--
-- It used to take the first recipe in the heater's crafting category, on the stated grounds that
-- there was exactly one. #28 put rf-d-t-plasma in the same category and made that false. pairs over
-- a LuaCustomTable promises no order, so the rig would either benchmark a tier it does not claim to
-- or -- since every box it looks for afterwards is D-D's -- abort halfway through building itself,
-- and which of those happened could change when any prototype is added.
--
-- This benchmark says which recipe it wants -- -Plasma picks it, and the default is still D-D. The
-- category test is what survives of asking: it still catches the recipe being moved out from under
-- the heater, which is the failure the lookup existed to catch.
local function plasma_recipe()
  local recipe = prototypes.recipe[PLASMA]
  local categories = prototypes.entity["rf-heater"].crafting_categories
  if not (recipe and categories[recipe.category]) then
    error("rf-heater cannot craft " .. PLASMA .. "; -Plasma named a tier this heater has no recipe for")
  end
  return PLASMA
end

--- What the heater bank eats to make PLASMA, read off the recipe rather than written down (#89).
--
-- It used to be the literal "rf-deuterium" in three places, which was true of the D-D tier and of
-- nothing else: rf-d-t-plasma is heated out of Core's rf-d-t-mix. Three literals is three places to
-- miss, and the miss would not have been an error -- box_of() would have found no rf-deuterium box
-- on a D-T heater and the rig would have aborted mid-build with a message about a box rather than
-- about the tier.
--
-- The first FLUID ingredient, not the first ingredient: nothing in the mod heats plasma out of an
-- item today, and if something ever does, this rig feeds its heaters through a pipe and would have
-- to grow an inserter before that recipe could run here at all.
local function feed_fluid()
  for _, ingredient in ipairs(prototypes.recipe[PLASMA].ingredients) do
    if ingredient.type == "fluid" then return ingredient.name end
  end
  error(PLASMA .. "'s recipe takes no fluid ingredient; this rig can only feed a heater by pipe")
end

-- ------------------------------------------------------------------ fluid box helpers
--
-- Boxes are found by the fluid they are filtered to rather than by index. The reactor's are
-- declared in a known order, but the heat exchanger's third box belongs to its energy source
-- rather than to the boiler, and an assembling machine's come from whatever recipe is set -- so
-- an index would be a guess in two of the three cases and a hostage to prototype edits in all of
-- them.
local function box_of(entity, fluid)
  for index = 1, #entity.fluidbox do
    local filter = entity.fluidbox.get_filter(index)
    if filter and filter.name == fluid then return index end
  end
  return nil
end

local function amount_in(entity, index)
  local contents = entity.fluidbox[index]
  return contents and contents.amount or 0
end

-- entity.status is an integer and the API docs publish no numeric values for defines.entity_status,
-- so a raw one in a log line is a number nobody can act on. Resolved back to its name here.
local function status_name(value)
  for name, v in pairs(defines.entity_status) do
    if v == value then return name end
  end
  return tostring(value)
end

-- An infinity pipe against every connection of a box: unbounded supply, or unbounded disposal.
-- Everything that is not one of the two links under test is made unbounded this way, so that the
-- links are the only thing in the rig that can be a limit.
local function unbound(surface, force, entity, index, filter)
  local attached = 0
  for _, connection in pairs(entity.fluidbox.get_pipe_connections(index)) do
    -- #215: when the exchanger's water connections moved to its short ends, these pipes landed
    -- eight tiles out -- inside the reactor's own footprint -- and placed anyway.
    local pipe = place_or_die(surface,
      { name = "infinity-pipe", position = connection.target_position, force = force },
      entity.name .. "'s " .. filter.name .. " infinity pipe")
    pipe.set_infinity_pipe_filter(filter)
    attached = attached + 1
  end
  if attached == 0 then
    error(string.format("could not attach any infinity pipe to %s box %d", entity.name, index))
  end
end

-- Place an entity so that one of its connections points at a chosen tile.
--
-- The alternative is to write down where a chemical plant keeps its output and where a heat
-- exchanger keeps its heat input, and those are vanilla's numbers rather than this repository's --
-- exactly the class of remembered constant that broke the reactor benchmark (#49). So the entity
-- is placed once, asked where its connection actually points, and moved by the difference.
local function place_facing(surface, force, name, fluid, target, seed)
  -- Not place_or_die: this one is thrown away, and it exists to be asked where its connections
  -- point. That answer is relative to itself, so an overlap here changes nothing it is asked for.
  local probe = surface.create_entity({ name = name, position = seed, force = force })
  if not probe then error("could not place a probe " .. name) end
  if probe.type == "assembling-machine" then probe.set_recipe(plasma_recipe()) end

  local index = box_of(probe, fluid)
  if not index then error(name .. " has no box filtered to " .. fluid) end
  local connections = probe.fluidbox.get_pipe_connections(index)
  if #connections == 0 then error(name .. "'s " .. fluid .. " box has no connections") end

  local at = connections[1].target_position
  local position = { seed[1] + (target[1] - at.x), seed[2] + (target[2] - at.y) }
  probe.destroy()

  local entity = place_or_die(surface, { name = name, position = position, force = force }, name)
  if entity.type == "assembling-machine" then entity.set_recipe(plasma_recipe()) end
  return entity
end

-- The pipe is named by the caller, and since #86 exactly one caller is left. #26 gives the plasma
-- set a connection_category of its own, so rf-pipe joins the reactor's plasma box and nothing else;
-- ADR 0018 then gave the energy boxes a category of their own too, and shipped NO pipe that carries
-- it. So the plasma line is rf-pipe and the energy line is no line at all -- machines bolted face to
-- face. Getting the plasma one wrong does not misreport, it fails to connect, and assert_joined
-- below says so.
--
-- Idempotent, which the energy line's corner needed while it had one. Kept because create_entity
-- does not collision-check and a caller that walks two runs into the same tile would otherwise get
-- two pipes in it silently.
local function pipe_run(surface, force, name, from, step, count)
  for i = 0, count - 1 do
    local at = { from[1] + step[1] * i, from[2] + step[2] * i }
    if not surface.find_entity(name, at) then
      place_or_die(surface, { name = name, position = at, force = force }, name)
    end
  end
end

-- Which way a runtime connection faces, read off the tile it targets rather than remembered.
local function facing(connection)
  local dx = connection.target_position.x - connection.position.x
  local dy = connection.target_position.y - connection.position.y
  if dy < 0 then return "north" elseif dy > 0 then return "south" elseif dx < 0 then return "west" end
  return "east"
end

-- The connection of `entity`'s box on `fluid` that faces `side`, or nil.
local function connection_facing(entity, fluid, side)
  local index = box_of(entity, fluid)
  if not index then error(entity.name .. " has no box filtered to " .. fluid) end
  for _, c in pairs(entity.fluidbox.get_pipe_connections(index)) do
    if facing(c) == side then return c end
  end
  return nil
end

-- Place `name` so that its `fluid` connection facing `side` STANDS ON `tile`, which is the other
-- machine's target_position.
--
-- NOT place_facing BELOW, AND THE DIFFERENCE IS THE WHOLE OF #86's ARITHMETIC. place_facing aligns
-- a connection's TARGET onto a chosen tile, which is what a pipe run wants: the pipe occupies that
-- tile. A BOLT aligns one machine's connection TILE onto the other machine's target. Align target
-- against target and the two machines sit one tile clear of each other, both pointing at the same
-- empty ground -- which is indistinguishable from a refused connection. ADR 0018's Consequences
-- call it a trap and #82's rig reported a false negative from it on the question deciding that ADR.
--
-- Which connection is chosen geometrically rather than by index, because rf-heat-exchanger's energy
-- box has three and pairs() promises no order -- so an index would bolt the row together by a
-- different face from one run to the next.
local function bolt(surface, force, name, fluid, side, tile, seed)
  -- Not place_or_die: this one is thrown away and only ever asked where its connections are,
  -- relative to itself, so an overlap here changes nothing it is asked for.
  local probe = surface.create_entity({ name = name, position = seed, force = force })
  if not probe then error("could not place a probe " .. name) end
  local found = connection_facing(probe, fluid, side)
  if not found then
    probe.destroy()
    error(name .. " has no " .. side .. "-facing " .. fluid .. " connection to bolt with")
  end
  local off = { found.position.x - probe.position.x, found.position.y - probe.position.y }
  probe.destroy()
  return place_or_die(surface, {
    name = name, position = { tile.x - off[1], tile.y - off[2] }, force = force,
  }, string.format("%s bolted onto (%g, %g)", name, tile.x, tile.y))
end

-- Every link in this rig has to actually be plumbed, and a fluid connection that lines up with
-- nothing looks exactly like one that does until no fluid arrives. Asked directly instead.
local function assert_joined(entity, index, what)
  for _, connection in pairs(entity.fluidbox.get_pipe_connections(index)) do
    if connection.target then return end
  end
  error(what .. ": no connection on this box reaches anything")
end

-- AND THAT IT REACHES THE RIGHT THING, which is a different question and the one #215 turned on.
--
-- Every fluid here has its own plumbing, and the engine merges any two segments whose tiles touch.
-- A steam pipe landing on the energy line breaks no connection -- assert_joined above passes on
-- every box in the rig -- it merely makes a segment that cannot accept reactor energy. The reactor
-- then reads as a machine that produces nothing rather than as a plumbing mistake, which is exactly
-- how the exchanger bank sat broken from 2026-08-23 to 2026-09-02 with every check green.
--
-- So each box is asked which segment it is in, and two DIFFERENT fluids sharing one is the error.
-- Same fluid sharing is not: the whole point of the energy line is that the reactor and every
-- exchanger sit in one segment, and adjacent exchangers' water pipes may touch without harm.
local function assert_segments(cell)
  local owner = {}
  -- WHOSE segment id, and it is not the machine's own. get_fluid_segment_id on a machine's box
  -- returns nil far more often than not: MEASURED ON THIS RIG AGAINST FACTORIO 2.0.77 (build
  -- 84539), it answered for the reactor's plasma box and for every exchanger's water box, and
  -- returned nil for the reactor's energy box, every heater box and every steam box. The version
  -- is named because the API publishes per version and this is a fact about one of them. The
  -- manual does not contradict it and does not predict it either:
  -- https://lua-api.factorio.com/2.0.77/classes/LuaFluidBox.html#get_fluid_segment_id gives
  -- "does not belong to a fluid segment" as one of its nil cases without saying which boxes fall
  -- into it, so WHICH ones is the rig's finding rather than the manual's.
  -- bench-fluid-links.ps1 only ever tostring()s the value into a log line, so nothing here had
  -- established it. The pipe on the other side of the connection always has one, so the segment
  -- is read through the connection's target.
  local function claim(entity, index, fluid, what)
    if not index then error(cell.name .. " cell: " .. what .. ": no box carries " .. fluid) end
    local ids = {}
    for _, connection in pairs(entity.fluidbox.get_pipe_connections(index)) do
      if connection.target then
        local id = connection.target.get_fluid_segment_id(connection.target_fluidbox_index)
        if id then ids[#ids + 1] = id end
      end
    end
    -- Flush against another machine there is no pipe to ask, and then the box's own id is the only
    -- one there is. Neither being available means nothing can be judged, which is not a pass.
    if #ids == 0 then
      local own = entity.fluidbox.get_fluid_segment_id(index)
      if not own then
        error(cell.name .. " cell: " .. what .. ": in no fluid segment, and neither is anything it "
          .. "connects to -- this box cannot be judged")
      end
      ids[1] = own
    end
    for _, id in ipairs(ids) do
      local held = owner[id]
      if held and held.fluid ~= fluid then
        error(string.format(
          "%s cell: %s carries %s, but shares fluid segment %d with %s, which carries %s. Two "
          .. "fluids in one segment: neither line can carry what it is for, and nothing else in "
          .. "this rig says so", cell.name, what, fluid, id, held.what, held.fluid))
      end
      owner[id] = { fluid = fluid, what = what }
    end
  end

  claim(cell.reactor, cell.plasma_box, PLASMA, "the reactor's plasma box")
  claim(cell.reactor, cell.energy_box, ENERGY, "the reactor's energy box")
  for i, heater in ipairs(cell.heaters) do
    claim(heater, box_of(heater, PLASMA), PLASMA, "heater " .. i .. "'s plasma output")
    claim(heater, box_of(heater, feed_fluid()), feed_fluid(),
      "heater " .. i .. "'s " .. feed_fluid() .. " input")
  end
  for i, exchanger in ipairs(cell.exchangers) do
    claim(exchanger, box_of(exchanger, ENERGY), ENERGY, "exchanger " .. i .. "'s energy input")
    claim(exchanger, box_of(exchanger, "water"), "water", "exchanger " .. i .. "'s water input")
    claim(exchanger, box_of(exchanger, "steam"), "steam", "exchanger " .. i .. "'s steam output")
  end
end

__QUIETMAP__
--- Every entity a cell is metered through, and the power that keeps it running, checked before the
--- numbers are believed.
--
-- THIS BENCH REPORTS A QUIET WRONG NUMBER RATHER THAN CRASHING. The meter is a source box compared
-- against what it held last tick, and it already drops ticks where production and outflow cannot be
-- separated. A heater that loses power stops crafting: the link goes idle, the dropped fraction
-- climbs, and the mean is quietly taken over the busy ticks only -- which the header above names as
-- the way this method misleads. The rates in docs/research/fluid-link-throughput.md are what would
-- be wrong, and nothing else here would say so.
--
-- The reading path is in here even though destroying a metered entity makes amount_in() raise on
-- its own: "LuaEntity API call when LuaEntity was invalid" does not say which cell or what went.
-- The supply path is in here because it raises NOTHING -- a heater whose substation is eaten stays
-- perfectly valid and simply stops crafting.
--
-- Called once a second rather than on every one of the 126 000 ticks, the same cadence as
-- probe-quality-equilibrium.ps1's: a run this length is ruined by damage whenever it arrives, so a
-- second's delay in noticing costs nothing and 60x the valid checks buys nothing.
local function assert_intact(cell)
  local function check(what, entity)
    if entity and not entity.valid then
      error(string.format("%s cell: %s is gone -- something destroyed part of the rig mid-run, so "
        .. "this run measures damage rather than throughput", cell.name, what))
    end
  end
  check("its reactor", cell.reactor)
  -- Every heater, not only the metered one. build() runs a bank on purpose -- a reactor a few
  -- percent short of plasma reads well under its own equilibrium and the headroom comes out
  -- flatteringly large -- so losing heater 2 of 4 never touches the meter and moves the answer.
  for i, heater in ipairs(cell.heaters) do
    check(i == 1 and "the metered heater" or ("heater " .. i), heater)
  end
  for i, exchanger in ipairs(cell.exchangers) do check("heat exchanger " .. i, exchanger) end
  for _, part in ipairs(cell.power) do check(part[1], part[2]) end
end

-- ------------------------------------------------------------------ one cell
--
-- ox is the cell's origin. The reactor sits there; the plasma line runs west out of its west
-- connection to a heater, and the energy leg leaves its SOUTH connection with no pipe on it at all
-- -- either a bolted, chained row of heat exchangers or the categorised feed that swallows whatever
-- arrives (#86).
--
-- power is this cell's substations and energy interfaces, already placed. The cell keeps them so
-- assert_intact() can see the supply path; nothing here reads them for a measurement.
local function build(surface, force, ox, drain, power)
  local reactor = place_or_die(surface,
    { name = "rf-reactor", position = { ox + 0.5, 0.5 }, force = force, raise_built = true },
    "rf-reactor")
  if not reactor.electric_network_id then error("rf-reactor is on no electric network") end

  -- The reactor's plasma box is box 1, by index and not by filter. It is the one place in this rig
  -- that cannot use box_of: #28 removed rf-reactor's input filter, because one reactor now burns
  -- either plasma and a filter takes exactly one fluid. get_filter reports the PROTOTYPE's filter,
  -- so asking for the plasma box by fluid returns nil and this rig aborts before it builds anything.
  --
  -- Index is safe here for the reason the helper's own note gives -- the reactor declares its two
  -- boxes in a known order -- and the contract is asserted rather than assumed: box 1 unfiltered,
  -- box 2 filtered to reactor energy. A prototype edit that swapped them still stops the run.
  local plasma_box = 1
  local energy_box = box_of(reactor, ENERGY)
  if reactor.fluidbox.get_filter(plasma_box) then
    error("rf-reactor's input box has regained a filter; see prototypes/entities.lua")
  end
  if energy_box ~= 2 then error("rf-reactor's boxes are not where they were") end

  -- Plasma: a bank of heaters -> a pipe run west -> the reactor's west connection.
  --
  -- More than one heater, and the count matters. A single heater makes 2.5 plasma a second against
  -- a reactor that burns about 0.6, which sounds like three times more than enough -- but it
  -- arrives in five-unit bursts every two seconds, and the reactor's box shares a segment with the
  -- pipes, so the pool sits a few percent short of full for ever. Density drives fusion power, so
  -- a reactor a few percent light on plasma reads well under its own equilibrium and the headroom
  -- figure comes out flatteringly large. Heaters are cheap here; supply-limiting the reactor is
  -- not.
  local west = { ox + 0.5 - 8, 0.5 }
  pipe_run(surface, force, "rf-pipe", west, { -1, 0 }, PIPES + 3 * (HEATERS - 1))
  local heater
  local heaters = {}
  for i = 0, HEATERS - 1 do
    local built = place_facing(surface, force, "rf-heater", PLASMA,
      { west[1] - (PIPES - 1) - 3 * i, west[2] }, { ox - 24.5 - 4 * i, 20.5 })
    unbound(surface, force, built, box_of(built, feed_fluid()),
      { name = feed_fluid(), percentage = 1, mode = "at-least" })
    -- The first is the one the meter watches. They all feed the same segment, so one is a fair
    -- sample of the link; what the others do is add supply -- which is why assert_intact() keeps
    -- the whole bank rather than only the metered one.
    heater = heater or built
    heaters[#heaters + 1] = built
  end

  -- Energy: the reactor's SOUTH connection, bolted, with NO PIPE ANYWHERE ON THIS LEG (#86).
  --
  -- IT WAS A PIPE RUN NORTH INTO A HEADER, AND THAT LAYOUT HAD BEEN STALE SINCE c3abb81 (#215). The
  -- header pitched the exchangers six tiles apart, which described rf-heat-exchanger when it was
  -- vanilla's 3x2; at 5x15 exchanger i's steam outlet targeted exchanger i+1's stub, so steam and
  -- reactor energy fought over the same tile and place_or_die() refused to build it at all.
  --
  -- #86 settles it by removing the choice. ADR 0018 gives the fluid a connection category of its
  -- own and ships no pipe that carries it, so there is no header to pitch: the first exchanger
  -- bolts flat to the reactor's south face and each one after it chains off its neighbour's east
  -- short end (ADR 0031 item 2). Every offset comes off the two prototypes through bolt(), so the
  -- pitch cannot go stale against a footprint again.
  local reactor_out = connection_facing(reactor, ENERGY, "south")
  if not reactor_out then
    error("rf-reactor has no south-facing energy output; ADR 0031 item 1 says it must")
  end

  local exchangers = {}
  if drain then
    -- Nothing downstream to throttle the link: whatever crosses is removed the same tick. The
    -- rigs' categorised feed rather than a vanilla infinity pipe, because a vanilla one cannot
    -- reach this box at all any more -- which is the whole of what Write-EnergyFeed exists for.
    local pipe = place_or_die(surface,
      { name = ENERGY_FEED, position = reactor_out.target_position, force = force },
      "the drain's energy feed")
    pipe.set_infinity_pipe_filter({ name = ENERGY, percentage = 0, mode = "at-most" })
  else
    local tile, side = reactor_out.target_position, "north"
    for i = 1, EXCHANGERS do
      local exchanger = bolt(surface, force, "rf-heat-exchanger", ENERGY, side, tile,
        { ox - 40.5, -30.5 })
      exchangers[i] = exchanger
      -- The next machine bolts onto this one's EAST short end with its own west one, so the row
      -- grows sideways along the reactor's face and both long faces stay free for energy and steam.
      local east = connection_facing(exchanger, ENERGY, "east")
      if not east then
        error("rf-heat-exchanger has no east-facing energy connection to chain through")
      end
      tile, side = east.target_position, "west"
    end

    -- WATER AT THE ROW'S TWO ENDS ONLY, which is not a shortcut but the shape's own constraint: a
    -- chained row consumes every interior water connection in a joint, so the middle of the row has
    -- to be served across the row the same way energy is. ADR 0031 measured eight machines fed this
    -- way and none starved; this rig runs four.
    for _, spec in ipairs({ { exchangers[1], "west" }, { exchangers[EXCHANGERS], "east" } }) do
      local water = connection_facing(spec[1], "water", spec[2])
      if not water then
        error("rf-heat-exchanger has no " .. spec[2] .. "-facing water connection")
      end
      local pipe = place_or_die(surface,
        { name = "infinity-pipe", position = water.target_position, force = force },
        "the row's " .. spec[2] .. " water feed")
      pipe.set_infinity_pipe_filter({ name = "water", percentage = 1, mode = "at-least" })
    end

    -- Steam out of every machine. Its one steam connection is on the free long face, so nothing
    -- here has to be skipped.
    for _, exchanger in ipairs(exchangers) do
      unbound(surface, force, exchanger, box_of(exchanger, "steam"),
        { name = "steam", percentage = 0, mode = "at-most" })
    end
  end

  -- Everything the run depends on and nothing errors about on its own: an unpowered heater crafts
  -- nothing, and a pipe run that lines up one tile out carries nothing. Both look like a quiet
  -- zero in the results rather than like a broken rig.
  if not heater.electric_network_id then error("rf-heater is on no electric network") end
  assert_joined(heater, box_of(heater, PLASMA), "heater plasma output")
  assert_joined(reactor, plasma_box, "reactor plasma box")
  assert_joined(reactor, energy_box, "reactor energy output")
  for _, exchanger in ipairs(exchangers) do
    assert_joined(exchanger, box_of(exchanger, ENERGY), "exchanger energy input")
    assert_joined(exchanger, box_of(exchanger, "water"), "exchanger water input")
    assert_joined(exchanger, box_of(exchanger, "steam"), "exchanger steam output")
  end

  local cell = {
    -- "drain", not "sink": the variable behind it has always been called drain, and
    -- docs/research/fluid-link-throughput.md spends its first half using "sink" for the RECEIVING
    -- END of a link. One word for two things in one document (#215).
    name = drain and "drain" or "chain",
    reactor = reactor, heater = heater, heaters = heaters, exchangers = exchangers, power = power,
    plasma_box = plasma_box, energy_box = energy_box,
    heater_box = box_of(heater, PLASMA),
    -- Meter state. last_* is what the source box held at the previous sample.
    last_plasma = 0, last_energy = 0,
    plasma_out = 0, energy_out = 0, plasma_ticks = 0, energy_ticks = 0, plasma_skipped = 0,
  }

  assert_segments(cell)
  return cell
end

script.on_init(function()
  local surface = game.surfaces[1]
  local force   = game.forces.player

  -- Every recipe in this mod ships enabled = false behind its technology, so a freshly created map
  -- has a heater that will not craft -- reported as recipe_not_researched, and otherwise visible
  -- only as a link that carries nothing. This is also the state the mod gets played in.
  force.research_all_technologies()

  -- Cell pitch, derived rather than written down (#89). It was a literal 100, which is the room a
  -- four-machine row needs and no more: at eight exchangers it put the last machine straight through
  -- the drain cell's energy feed. The failure was loud -- place_or_die() saw it -- and it is still
  -- better derived than remembered.
  --
  -- THE ARITHMETIC IS THE REACTOR'S HALF PLUS THE ROW PLUS 25, FLOORED AT 100, and it is written out
  -- because a rounder-looking story is wrong: 8 + 4x15 + 25 is 93 at the default, so what produces
  -- the historical 100 there is the FLOOR and not the sum. At eight the sum wins at 153, which is
  -- what the eight-exchanger measurement ran on. The floor is what keeps a default run identical to
  -- every figure taken before this line existed.
  --
  -- IT COVERS THE ROW AND NOT THE HEATER BANK, which is the limitation to know before trusting it.
  -- The row grows EAST of a cell's origin with EXCHANGERS; the plasma run and its heaters grow WEST
  -- of it with -Pipes and -Heaters, and this expression looks at neither.
  --
  -- What a long bank actually hits first is NOT the pitch, which is worth knowing because the
  -- opposite is the natural guess. Tried at -Pipes 20 -Heaters 8 -- both inside their ValidateRange
  -- -- the run dies at "rf-heater is on no electric network": the bank outruns the two substations
  -- placed per cell long before its western end reaches the neighbouring cell. So growing this
  -- expression westward would not buy those combinations; the power islands would have to grow with
  -- the bank first. Either way the failure is loud and names its part, which is why neither is
  -- fixed here.
  local CELL_PITCH = math.max(100,
    math.ceil(prototypes.entity["rf-reactor"].tile_width / 2)
      + EXCHANGERS * prototypes.entity["rf-heat-exchanger"].tile_width + 25)
  local EAST = CELL_PITCH + 100

  -- Radius in chunks, so a long row is not built on ungenerated ground. Eight chunks is 256 tiles
  -- and covered the old fixed layout with nothing to spare.
  surface.request_to_generate_chunks({ 0, 0 }, math.ceil(EAST / 32) + 2)
  surface.force_generate_chunk_requests()

  -- AFTER the chunks exist, which is the shared guard's one precondition: it clears what it can
  -- see, and it can only see chunks that have been generated. The count goes into the built line so
  -- a reader can tell the quieting happened rather than take it on trust. The clear-the-area loop
  -- below is not a substitute -- it removes what is in the build box and leaves pollution and enemy
  -- expansion switched on, which is what brings the attention over the next thirty-five minutes.
  storage.quieted = __QUIETFN__(surface)

  -- THE CLEARED BOX RUNS FURTHER EAST AND FURTHER SOUTH THAN IT DID, because the chain cell's row
  -- is now -EXCHANGERS fifteen-tile machines laid side by side along the reactor's south face rather
  -- than a bank hung off a header. CELL_PITCH above is the room one cell needs; the east edge is one
  -- more cell's worth beyond the second cell's origin, so the drain cell has the same clearance the
  -- chain cell does.
  local CLEAR = { { -120, -60 }, { EAST, 40 } }
  local tiles = {}
  for x = CLEAR[1][1], CLEAR[2][1] do
    for y = CLEAR[1][2], CLEAR[2][2] do tiles[#tiles + 1] = { name = "landfill", position = { x, y } } end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered({ area = CLEAR })) do
    if e.type ~= "character" then e.destroy() end
  end

  -- Power, placed before anything else so the electric-network checks below have something to
  -- find. Two islands per cell: the reactor is fifteen tiles across and its heater sits clear of
  -- the far side of it, which is further than one substation's supply area reaches. A single
  -- substation covering the reactor leaves the heater dark -- it places, it just never crafts, and
  -- the only symptom is a link that carries nothing.
  --
  -- Kept per cell, so assert_intact() can see the supply path: losing either half takes a cell's
  -- heater dark without invalidating anything the meter touches.
  local power = {}
  for _, ox in ipairs({ 0, CELL_PITCH }) do
    power[ox] = {}
    for _, dx in ipairs({ 9, -9 }) do
      local sub = place_or_die(surface,
        { name = "substation", position = { ox + dx, 5 }, force = force }, "a substation")
      local eei = place_or_die(surface, {
        name = "electric-energy-interface",
        position = { ox + dx + (dx > 0 and 2.5 or -2.5), 5.5 }, force = force,
      }, "a power source")
      eei.power_production = 4e6   -- J/tick, ~240 MW against a reactor's 50 and a heater's 5
      local side = dx > 0 and "east" or "west"
      power[ox][#power[ox] + 1] = { "its " .. side .. " substation", sub }
      power[ox][#power[ox] + 1] = { "its " .. side .. " power source", eei }
    end
  end

  storage.cells = {
    build(surface, force, 0, false, power[0]),
    build(surface, force, CELL_PITCH, true, power[CELL_PITCH]),
  }
  for _, cell in ipairs(storage.cells) do
    cell.last_plasma = amount_in(cell.heater, cell.heater_box)
    cell.last_energy = amount_in(cell.reactor, cell.energy_box)
  end

  -- pipes= is the PLASMA link's count. The energy leg has none and cannot have any (#86).
  log(string.format("LINKRIG built cells=%d plasma_pipes=%d exchangers=%d heaters=%d quieted=%d",
    #storage.cells, PIPES, EXCHANGERS, HEATERS, storage.quieted))
end)

local function report(cell, window)
  local reactor = cell.reactor
  local plasma  = reactor.fluidbox[cell.plasma_box]
  -- Totals rather than rates, because there are two honest rates and the caller should be the one
  -- to divide. Over the whole window is the sustained figure; over only the ticks fluid was seen
  -- moving is what the link carries while it carries anything, and for a link fed in bursts -- the
  -- heater completes a craft every couple of seconds -- those are far apart.
  log(string.format(
    "LINKRIG cell=%s window=%d plasma_total=%.6g plasma_ticks=%d energy_total=%.6g " ..
    "energy_ticks=%d plasma_skipped=%d temp_c=%.6g plasma_amount=%.6g energy_stored=%.6g " ..
    "heater_status=%s heater_held=%.6g heater_fed=%.6g",
    cell.name, window,
    cell.plasma_out, cell.plasma_ticks, cell.energy_out, cell.energy_ticks,
    cell.plasma_skipped, plasma and plasma.temperature or 0, plasma and plasma.amount or 0,
    amount_in(reactor, cell.energy_box),
    status_name(cell.heater.status), amount_in(cell.heater, cell.heater_box),
    amount_in(cell.heater, box_of(cell.heater, feed_fluid()))))

  -- EVERY exchanger in the row, which is #89's whole instrument. This used to report
  -- cell.exchangers[1] alone -- the one bolted straight to the reactor, and therefore the one that
  -- cannot starve however the chain behaves. A row fed through a single joint fails at its FAR end
  -- or not at all, so the only machine the old line could not see is the only one worth watching.
  for i, exchanger in ipairs(cell.exchangers) do
    log(string.format(
      "LINKRIG exch cell=%s window=%d index=%d status=%s fuel=%.6g water=%.6g steam=%.6g",
      cell.name, window, i, status_name(exchanger.status),
      amount_in(exchanger, box_of(exchanger, ENERGY)),
      amount_in(exchanger, box_of(exchanger, "water")),
      amount_in(exchanger, box_of(exchanger, "steam"))))
  end
  cell.plasma_out, cell.energy_out = 0, 0
  cell.plasma_ticks, cell.energy_ticks, cell.plasma_skipped = 0, 0, 0
end

script.on_event(defines.events.on_tick, function()
  local audit = game.tick % 60 == 0
  for _, cell in ipairs(storage.cells) do
    if audit then assert_intact(cell) end

    -- The meter. A fall in the source box is fluid that crossed; a rise is production, and that
    -- tick is dropped rather than netted, because the two cannot be separated afterwards.
    local plasma = amount_in(cell.heater, cell.heater_box)
    if plasma < cell.last_plasma then
      cell.plasma_out   = cell.plasma_out + (cell.last_plasma - plasma)
      cell.plasma_ticks = cell.plasma_ticks + 1
    else
      cell.plasma_skipped = cell.plasma_skipped + 1
    end
    cell.last_plasma = plasma

    local energy = amount_in(cell.reactor, cell.energy_box)
    if energy < cell.last_energy then
      cell.energy_out   = cell.energy_out + (cell.last_energy - energy)
      cell.energy_ticks = cell.energy_ticks + 1
    end
    cell.last_energy = energy
  end

  if game.tick > 0 and game.tick % WINDOW == 0 then
    for _, cell in ipairs(storage.cells) do report(cell, game.tick / WINDOW) end
  end
end)
'@
    $lua = $lua.
        Replace('__QUIETMAP__', (Get-QuietMapLua)).
        Replace('__QUIETFN__', $script:QuietMapFunction).
        Replace('__WINDOW__', "$Window").Replace('__EXCHANGERS__', "$Exchangers").
        Replace('__PIPES__', "$Pipes").Replace('__HEATERS__', "$Heaters").
        Replace('__PLASMA__', $Plasma).
        Replace('__ENERGYFEED__', (Write-EnergyFeed -RigDirectory $rigDir))
    Set-Content -Path (Join-Path $rigDir 'control.lua') -Value $lua -Encoding utf8
}

$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled @() -Mods ($ourMods + $rigName)
    Write-Rig

    $save      = Join-Path $temp 'links.zip'
    $createOut = Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create'

    $version = 'unknown'
    $line = Get-Content $createOut | Select-String -Pattern 'Factorio (\d+\.\d+\.\d+) \(build (\d+)' |
        Select-Object -First 1
    if ($line) { $version = "$($line.Matches[0].Groups[1].Value) (build $($line.Matches[0].Groups[2].Value))" }

    $built = Get-Content $createOut | Select-String -Pattern 'LINKRIG built' | Select-Object -Last 1
    if ("$built" -notmatch 'cells=2\b') { throw "rig did not build both cells: '$built'" }
    if ("$built" -notmatch 'quieted=(\d+)') { throw "the rig did not report quieting the map: '$built'" }
    $quieted = [int] $Matches[1]

    $runOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', "$Ticks", '--benchmark-runs', '1', '--disable-audio')

    $windows = @()
    foreach ($record in (Get-Content $runOut | Select-String -Pattern 'LINKRIG cell=')) {
        $f = @{}
        foreach ($m in [regex]::Matches("$record", '(\w+)=([^\s]+)')) { $f[$m.Groups[1].Value] = $m.Groups[2].Value }
        $plasmaTotal  = [double] $f['plasma_total']
        $energyTotal  = [double] $f['energy_total']
        $plasmaCount  = [int]    $f['plasma_ticks']
        $energyCount  = [int]    $f['energy_ticks']
        $windows += [pscustomobject]@{
            Cell        = $f['cell']
            Window      = [int]    $f['window']
            # Sustained: everything that crossed, over every tick of the window. A lower bound,
            # because the ticks dropped for production carried fluid too.
            PlasmaTick  = $plasmaTotal / $Window
            EnergyTick  = $energyTotal / $Window
            # Flowing: over only the ticks fluid was seen moving. An upper bound on the sustained
            # rate, and the honest description of a link fed in bursts.
            PlasmaFlow  = if ($plasmaCount -gt 0) { $plasmaTotal / $plasmaCount } else { 0.0 }
            EnergyFlow  = if ($energyCount -gt 0) { $energyTotal / $energyCount } else { 0.0 }
            PlasmaTicks = $plasmaCount
            EnergyTicks = $energyCount
            PlasmaSkip  = [int]    $f['plasma_skipped']
            TempC       = [double] $f['temp_c']
            PlasmaAmt   = [double] $f['plasma_amount']
            EnergyStore = [double] $f['energy_stored']
        }
    }
    if ($windows.Count -lt 6) { throw "only $($windows.Count) window reports; the run did not finish." }

    # The per-exchanger trace, which is what #89 reads. Logged every window for every machine in the
    # row; only the last window is reported, because the question is what a settled row does and the
    # equilibrium gate below is what decides the run was one.
    # NOT a variable named for the -Exchangers parameter: PowerShell variables are
    # case-insensitive, so that name IS the [int] parameter, and assigning an array to it fails
    # with a type-conversion error naming neither the parameter nor the line that built the array.
    $rowSamples = @()
    foreach ($record in (Get-Content $runOut | Select-String -Pattern 'LINKRIG exch ')) {
        $f = @{}
        foreach ($m in [regex]::Matches("$record", '(\w+)=([^\s]+)')) { $f[$m.Groups[1].Value] = $m.Groups[2].Value }
        $rowSamples += [pscustomobject]@{
            Cell   = $f['cell']
            Window = [int]    $f['window']
            Index  = [int]    $f['index']
            Status = $f['status']
            Fuel   = [double] $f['fuel']
            Water  = [double] $f['water']
            Steam  = [double] $f['steam']
        }
    }

    # ------------------------------------------------------- equilibrium, and the meter's own honesty
    $faults = @()
    $summary = @()
    foreach ($cell in @('chain', 'drain')) {
        $rows = @($windows | Where-Object { $_.Cell -eq $cell } | Sort-Object Window)
        $last = $rows[-1]; $prev = $rows[-2]

        $drift = if ($last.EnergyTick -gt 0) { [Math]::Abs($last.EnergyTick - $prev.EnergyTick) / $last.EnergyTick } else { 1.0 }
        $tempDrift = if ($last.TempC -gt 0) { [Math]::Abs($last.TempC - $prev.TempC) / $last.TempC } else { 1.0 }
        # Parenthesised as a whole before -f, because -f binds tighter than + and would otherwise
        # format only the last fragment and print the placeholders in the first verbatim.
        if ($drift -gt 0.02) {
            $faults += (("{0}: the energy rate moved {1:P1} between the last two windows, so the " +
                         "reactor was still climbing -- raise -Ticks.") -f $cell, $drift)
        }
        if ($tempDrift -gt 0.01) {
            $faults += (("{0}: the plasma temperature moved {1:P1} between the last two windows, so " +
                         "this is not an equilibrium -- raise -Ticks.") -f $cell, $tempDrift)
        }
        # The reactor's plasma inventory has to have settled too, and this is not belt-and-braces.
        # A reactor still filling pins its temperature at the clamp within seconds and holds a
        # steady rate while it does, so rate and temperature alone will happily call a reactor at
        # 2% of its plasma "settled" -- and its fusion power goes with density, so that reading
        # would be an order of magnitude light.
        $plasmaDrift = if ($last.PlasmaAmt -gt 0) { [Math]::Abs($last.PlasmaAmt - $prev.PlasmaAmt) / $last.PlasmaAmt } else { 1.0 }
        if ($plasmaDrift -gt 0.01) {
            $faults += (("{0}: the reactor's plasma moved {1:P1} between the last two windows, so it " +
                         "was still filling rather than running -- raise -Ticks.") -f $cell, $plasmaDrift)
        }
        if ($last.EnergyTick -le 0) { $faults += "${cell}: no reactor energy crossed the link at all." }
        if ($last.PlasmaAmt -le 0)  { $faults += "${cell}: the reactor was out of plasma, so it was starved rather than settled." }

        # The meter drops any tick where the source box rose, because production and outflow cannot
        # be separated after the fact. That is only sound while the dropped ticks are the
        # production ticks and nothing else, so the fraction is checked rather than trusted: the
        # reactor writes energy every sixth tick, which is 16.7% of them.
        $counted = $last.EnergyTicks / $Window
        if ($counted -lt 0.7) {
            $faults += (("{0}: the energy meter counted only {1:P0} of ticks, well below the 83% the " +
                         "reactor's update cadence accounts for, so the link was idle for some of the " +
                         "window and the mean is over the busy ticks only.") -f $cell, $counted)
        }

        $summary += [pscustomobject]@{
            Cell = $cell
            PlasmaPerTick = $last.PlasmaTick; PlasmaWhileFlowing = $last.PlasmaFlow
            EnergyPerTick = $last.EnergyTick; EnergyWhileFlowing = $last.EnergyFlow
            PlasmaPerSecond = 60 * $last.PlasmaTick; EnergyPerSecond = 60 * $last.EnergyTick
            MegawattsOut = 60 * $last.EnergyTick    # 1 unit of rf-reactor-energy is 1 MJ
            TempC = $last.TempC; PlasmaAmount = $last.PlasmaAmt
            EnergyCounted = $counted; EnergyStored = $last.EnergyStore
        }
    }

    Write-Host ''
    Write-Host ("Factorio $version -- $Ticks ticks, $Window per window, $Pipes pipes on the plasma " +
                "link and none on the energy leg, $Exchangers exchangers")
    Write-Host ("map quieted: pollution and enemy expansion off, peaceful mode, {0} enemy entities removed" -f $quieted)
    Write-Host ''
    Write-Host ('{0,-8}{1,16}{2,16}{3,14}{4,14}{5,16}{6,12}' -f
        'cell', 'plasma u/tick', 'energy u/tick', 'energy MW', 'plasma held', 'plasma degC', 'ticks met')
    foreach ($s in $summary) {
        # The temperature is printed in scientific notation rather than as a fixed-point number
        # with group separators. N4 was written against the D-D tier, whose 2.4e8 fits; a D-T
        # reactor runs an order higher and 1.470.790.000,0000 overran the column and ran into the
        # one beside it, so the row could not be read at all (#89).
        Write-Host ('{0,-8}{1,16:N4}{2,16:N3}{3,14:N1}{4,14:N1}{5,16:E3}{6,12:P0}' -f
            $s.Cell, $s.PlasmaPerTick, $s.EnergyPerTick, $s.MegawattsOut, $s.PlasmaAmount,
            $s.TempC, $s.EnergyCounted)
    }

    # ------------------------------------------------------------------------------- headroom
    #
    # Stated as a range rather than a single ratio, and that is not hedging. #47's ceiling depends
    # on how much pipe is in the segment -- 100 units/tick flush, falling to a floor of 50 through
    # a long run -- so the honest comparison against a link of any particular length is the band
    # its ends bound. When the answer is two orders of magnitude clear, which end applies does not
    # change what it means.
    # The two links are not the same arrangement and do not share a ceiling.
    #
    # energy is the reactor's output-only box into the exchanger's input-only one, which is the row
    # #47's matrix sweeps: 100 units/tick per connection flush, falling to a floor of 50 through a
    # long run of pipe.
    #
    # SINCE #86 THAT LEG IS ALWAYS FLUSH, so the band's lower end no longer describes anything this
    # rig can build -- there is no pipe for the fluid, and a bolted joint is the flush case. The
    # range is printed as it stands rather than narrowed, because #47's own numbers are what the
    # band is quoted from and re-deriving a single-ratio ceiling for a bolt is #227's question.
    #
    # plasma is the heater's output-only box into the reactor's *input-output* one, which is
    # neither row #47 published. Measured since, by this repo's own rig
    # (bench-fluid-links.ps1's sinkio control): 49.9 units/tick on one connection, and -- unlike
    # output-into-input -- it does not scale with connection count, 3 connections carrying 75
    # rather than 150. Quoted here as the single-connection figure, which is the geometry the mod
    # has, and as a band only because the pipe count moves it a little.
    $CEILING = @{
        energy = @{ Min = 50.0; Max = 100.0; What = 'output into input' }
        plasma = @{ Min = 45.0; Max = 50.0;  What = 'output into input-output' }
    }

    Write-Host ''
    Write-Host "against #47's ceilings, each link against the arrangement it actually is"
    foreach ($s in $summary) {
        # Taken against the flowing rate, not the sustained one: it is the larger of the two, so
        # the headroom it yields is the smaller. Quoting the flattering number would be the whole
        # failure mode this ticket exists to avoid.
        foreach ($link in @(
            @{ Name = 'plasma'; Rate = $s.PlasmaWhileFlowing },
            @{ Name = 'energy'; Rate = $s.EnergyWhileFlowing })) {
            if ($link.Rate -le 0) { continue }
            $c = $CEILING[$link.Name]
            Write-Host ('  {0,-7}{1,-8}{2,9:N4} u/tick flowing   {3,6:N0}x to {4,6:N0}x headroom   ({5})' -f
                $s.Cell, $link.Name, $link.Rate,
                ($c.Min / $link.Rate), ($c.Max / $link.Rate), $c.What)
        }
    }

    # ------------------------------------------------------------------ the row, machine by machine
    #
    # A chained row off ONE bolted connection either feeds its far end or does not, and nothing else
    # this script prints would say which: the link rate above is what crossed the FIRST joint, and a
    # row whose last machine sits idle crosses that joint just as briskly.
    $rowWindow = ($rowSamples | Where-Object { $_.Cell -eq 'chain' } |
        Measure-Object Window -Maximum).Maximum
    $row = @($rowSamples | Where-Object { $_.Cell -eq 'chain' -and $_.Window -eq $rowWindow } |
        Sort-Object Index)
    if ($row.Count -gt 0) {
        Write-Host ''
        Write-Host ("the chain cell's row at the last window -- $Plasma, $Exchangers exchanger(s) " +
                    'off one bolted connection')
        Write-Host ('{0,-10}{1,-22}{2,14}{3,12}{4,12}' -f
            'position', 'status', 'energy held', 'water', 'steam')
        foreach ($e in $row) {
            Write-Host ('{0,-10}{1,-22}{2,14:N1}{3,12:N0}{4,12:N0}' -f
                $e.Index, $e.Status, $e.Fuel, $e.Water, $e.Steam)
        }
        $idle = @($row | Where-Object { $_.Status -ne 'working' })
        Write-Host ''
        if ($idle.Count -eq 0) {
            Write-Host ("every machine in the row was working, so one connection fed all " +
                        "$($row.Count) of them.")
        } else {
            Write-Host ("$($idle.Count) of $($row.Count) machines were NOT working: positions " +
                        ((($idle | ForEach-Object { $_.Index }) -join ', ')) + '.')
            Write-Host ('That is a finding about the shape rather than a fault in this rig -- read it ' +
                        'beside the energy')
            Write-Host ('held in each box: a starved far end holds nothing, a demand-limited one holds ' +
                        'a full box.')
        }
    }

    Write-Host ''
    Write-Host 'window trace (energy units/tick, then plasma degC)'
    foreach ($cell in @('chain', 'drain')) {
        $rows = @($windows | Where-Object { $_.Cell -eq $cell } | Sort-Object Window)
        Write-Host ('  {0,-6} {1}' -f $cell, (($rows | ForEach-Object { '{0:N2}' -f $_.EnergyTick }) -join '  '))
        Write-Host ('  {0,-6} {1}' -f '', (($rows | ForEach-Object { '{0:N3}e8' -f ($_.TempC / 1e8) }) -join '  '))
    }

    if ($faults.Count -gt 0) {
        Write-Host ''
        foreach ($f in $faults) { Write-Host "  $f" }
        throw "$($faults.Count) check(s) failed; the rates above are not an equilibrium measurement."
    }

    Write-Host ''
    Write-Host 'Both cells settled: rate and temperature each moved less than their tolerance across'
    Write-Host 'the last two windows, and the meter counted the ticks the update cadence predicts.'

    Write-Output $summary
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'bench-mod-links' }
}

#Requires -Version 7
<#
.SYNOPSIS
    Probes whether a connection_category declared on a FLUID ENERGY SOURCE's nested fluid box
    reaches the engine. Evidence for #82, which blocks the decision in #44.

.DESCRIPTION
    A PROBE, NOT A CHECK. Every line it prints is a measurement, and a negative answer is as much
    of a result as a positive one -- so exit 0 means the probe ran and every row reported, never
    that the answers were the ones anybody hoped for. Nothing here decides anything and nothing
    here ships.

    WHY THIS EXISTS

    #44 chose to give the two energy fluids a connection_category of their own and to ship NO PIPE
    that carries either, so a heat exchanger bolts straight onto a reactor face and chains to its
    neighbour. That is the shape Factorio's own Space Age fusion uses: every fusion-plasma
    connection on both fusion-reactor and fusion-generator carries
    connection_category = {"fusion-plasma"}, and Space Age ships no pipe with that category.

    The aneutronic half of that design needs no probing. scripts/check-aneutronic.ps1 already builds
    a converter so that its own south connection lands on the tile the reactor's output points at,
    and a second converter five tiles behind it -- direct-bolt and chaining, shipped and gated, for
    a GENERATOR'S OWN fluid box.

    rf-heat-exchanger is not that. Its intake is a fluid energy source:

        energy_source = { type = "fluid", burns_fluid = true, fluid_box = { ... } }

    -- a fluid box nested inside an energy source rather than declared on the entity. contain() in
    prototypes/entities.lua sets connection_category on pipe_connections, and NOTHING establishes
    that the engine reads that field in this position. If it does not, #44 is void for the neutronic
    tier: the reactor's output would be categorised and the exchanger's intake left "default", so
    nothing would connect at all -- no pipe, no bolt, no build -- and a boiler's fuel cannot arrive
    any other way.

    The failure mode is specific and has happened twice. #23 chose a crafting machine for the
    reactor: it loaded perfectly and moved no fluid at all. #43 put a heat_buffer on a boiler:
    accepted by the data stage, dropped by the engine. A field the data stage takes and the engine
    ignores is this project's characteristic bug, and it is the only reason this probe exists rather
    than the implementation.

    WHAT IS BUILT

      control   The SHIPPED rf-heat-exchanger, untouched, with an ordinary infinity pipe on the tile
                its energy connection points at. It must join and reactor energy must cross. This is
                the instrument's own calibration and it is not optional: without it, a bug in the
                placement arithmetic or in the join test reads exactly like containment working, and
                every negative below would be unfalsifiable.

      str       The same exchanger with connection_category set as a BARE STRING, the form contain()
                already uses. Two of them: one offered an ordinary infinity pipe, which must refuse,
                and one offered a categorised infinity pipe, which must join and deliver.

      list      The same pair with the category declared as a ONE-ELEMENT LIST, which is the form
                Space Age writes. Both forms are built because a negative here decides #44, and
                "the field was spelled wrong" is the one way such a negative could be wrong. #43
                tried fluid_box against fluid_boxes for exactly this reason and it was the difference
                between a finding and a mistake.

      bolt      A categorised rf-reactor whose output_fluid_box carries the category, with a
                categorised exchanger placed so its own south energy connection lands face to face
                with it -- NO PIPE BETWEEN THEM. This is the arrangement #44 ships. The reactor's
                output box is filled by Lua rather than by running the simulation, because what is
                under test is whether the boxes join and fluid crosses, not what the reactor
                computes.

                MEASURED ON THE CHAIN VARIANT, not on the shipped one-connection shape, because
                bolt and chain are one rig -- two would mean two reactors to fill and two chances
                for the fill loop to differ. That costs nothing: the connection doing the bolting
                is south {0, 0.5}, which is the same tile, facing and flow the shipped exchanger
                already declares. The variant adds two sideways connections; it does not change
                the one under test here.

      chain     The bolt row with a second categorised exchanger three tiles east of the first,
                joined through energy connections on their west and east faces. Whether the SECOND
                one receives anything is the whole question: a generator's box chains (proven in
                check-aneutronic.ps1), an energy source's box is unproven, and the answer decides
                whether eight exchangers hang off one reactor connection in a row or have to ring
                the reactor's faces -- 5 fit per face against the 8 an ignited D-T reactor needs.

      hc        The refuse/accept pair again on rf-hc-exchanger's shape, which has the same energy
                source on a seven-tile footprint. Bolt and chain are not repeated: the mechanism is
                the same one, and #82 allows establishing that one answer covers both.

    WHERE THE CHAIN VARIANT'S CONNECTIONS HAD TO GO, AND WHY IT IS NOT A FREE CHOICE

    rf-heat-exchanger is vanilla's 3x2, so its tile centres are x in {-1, 0, 1} and y in {-0.5, 0.5}
    -- and four of those tiles are already spoken for: water input-output at west {-1, 0.5} and east
    {1, 0.5}, steam output at north {0, -0.5}, and the energy intake at south {0, 0.5}. Two
    connections on one tile will not load.

    So a variant that chains SIDEWAYS has exactly one pair of tiles available, west {-1, -0.5} and
    east {1, -0.5}, and it needs the south one as well to bolt onto a north-facing reactor output.
    Three energy connections, not two. That is a fact about the shape #44 would ship rather than a
    detail of the rig, which is why it is written down here.

    A consequence worth knowing: two exchangers three tiles apart also join through their WATER
    boxes, east {1, 0.5} against west {-1, 0.5}. One water feed serves the row.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER Settle
    Ticks before the report. Nothing here measures a rate, so this only has to be long enough for
    fluid to cross a joined segment and for a boiler to reach `working`. Generous rather than tuned.

.PARAMETER KeepTemp
    Keep the save, the rig mod and the captured output.

.EXAMPLE
    pwsh -File scripts/probe-energy-containment.ps1
#>
[CmdletBinding()]
param(
    [string] $FactorioExe,
    # A floor rather than taste: the rig fills the reactor's box on every tick and reports at
    # $Settle, so a zero would report before anything had been placed a fluid to cross.
    [ValidateRange(30, [int]::MaxValue)] [int] $Settle = 300,
    [switch] $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$ourMods  = @('realistic-fusion-refreshed-core', 'realistic-fusion-refreshed')
$rigName  = 'rf-energy-probe-rig'

$FactorioExe = Resolve-FactorioExe -Path $FactorioExe
$bundled     = Get-BundledMods -FactorioExe $FactorioExe

$temp   = Join-Path ([IO.Path]::GetTempPath()) ('rf-energy-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modDir = Join-Path $temp 'mods'
$rigDir = Join-Path $modDir $rigName
New-Item -ItemType Directory -Path $rigDir -Force | Out-Null

function Write-Rig {
    @{
        name = $rigName; version = '0.0.1'; title = 'Energy containment probe'
        author = 'probe-energy-containment.ps1'; factorio_version = '2.0'
        dependencies = @('base >= 2.0.77', 'realistic-fusion-refreshed')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8

    $data = @'
-- Generated by scripts/probe-energy-containment.ps1 (#82). Nothing here ships.
--
-- Every subject is a deepcopy of a SHIPPED prototype with the field under test added and nothing
-- else changed. Not of a vanilla one: the question is whether the category reaches the engine on
-- the boxes this mod actually declares, and a rig that rebuilt them from vanilla would be measuring
-- its own reconstruction.

local CATEGORY = "rf-probe-energy"

local exchanger = data.raw["boiler"]["rf-heat-exchanger"]
local hc        = data.raw["boiler"]["rf-hc-exchanger"]
local reactor   = data.raw["boiler"]["rf-reactor"]
local feed      = data.raw["infinity-pipe"]["infinity-pipe"]
for name, prototype in pairs({ ["rf-heat-exchanger"] = exchanger, ["rf-hc-exchanger"] = hc,
                               ["rf-reactor"] = reactor, ["infinity-pipe"] = feed }) do
  if not prototype then error("the probe needs " .. name .. " and it is missing") end
end

-- Nothing places these but the rig, so they need no item and no recipe. `minable` is the field that
-- does the work here: it names an item result that only exists for the prototype being copied.
--
-- fast_replaceable_group and next_upgrade are cleared for the vanilla infinity-pipe copy below and
-- are NO-OPS for the three shipped subjects, because Core's claim() already nils both
-- (realistic-fusion-refreshed-core/prototypes/vanilla.lua). Stated rather than left implied: the
-- two commits before this one existed to correct claims the sibling probe made about itself, and
-- "this line is load-bearing" is the same kind of claim.
local function bare(e, name)
  e.name = name
  e.minable = nil
  e.fast_replaceable_group = nil
  e.next_upgrade = nil
  return e
end

--- The subject of the whole probe: the shipped exchanger with its ENERGY SOURCE's nested fluid box
--- carrying a connection category, and nothing else touched.
---
--- `category` is passed in rather than fixed so the bare-string and one-element-list forms can be
--- built from one function. If the engine honours one form and not the other, that difference is
--- the finding, and a rig that hard-coded either would have reported the wrong negative.
local function categorised(name, category)
  local e = bare(table.deepcopy(exchanger), name)
  for _, c in ipairs(e.energy_source.fluid_box.pipe_connections) do
    c.connection_category = category
  end
  return e
end

local function categorised_hc(name, category)
  local e = bare(table.deepcopy(hc), name)
  for _, c in ipairs(e.energy_source.fluid_box.pipe_connections) do
    c.connection_category = category
  end
  return e
end

-- The chain variant. Three energy connections rather than two, and the .DESCRIPTION above says why:
-- on a 3x2 whose water, steam and energy tiles are already taken, west {-1,-0.5} and east
-- {1,-0.5} are the only free tiles facing sideways, and the south one is still needed to bolt onto
-- a reactor's north-facing output.
--
-- input-output on all three. production_type stays "input" -- what the machine DOES with the fluid
-- is unchanged; flow_direction is what decides whether a connection will join another machine's.
-- rf-direct-energy-converter's own box makes exactly that distinction and it is the reason a row of
-- converters connects at all.
local chain = categorised("rf-probe-exchanger-chain", CATEGORY)
chain.energy_source.fluid_box.pipe_connections = {
  { flow_direction = "input-output", direction = defines.direction.south,
    position = { 0, 0.5 }, connection_category = CATEGORY },
  { flow_direction = "input-output", direction = defines.direction.west,
    position = { -1, -0.5 }, connection_category = CATEGORY },
  { flow_direction = "input-output", direction = defines.direction.east,
    position = { 1, -0.5 }, connection_category = CATEGORY },
}

-- The source side of the bolt row: the shipped reactor with its OUTPUT box categorised. Its plasma
-- boxes are left exactly as they are, category and all -- nothing here asks about plasma, and
-- changing a box the probe does not measure is how a rig grows a confound.
local source = bare(table.deepcopy(reactor), "rf-probe-reactor")
for _, c in ipairs(source.output_fluid_box.pipe_connections) do
  c.connection_category = CATEGORY
end

-- The instrument for the "accept" half: an infinity pipe that carries the category. #44 ships no
-- pipe for these fluids, so this is a measuring tool and not a preview of anything. It is needed
-- because a row where an ordinary pipe refuses to join proves nothing on its own -- a box with a
-- MISDECLARED category also refuses everything, and the two look identical from outside.
local categorised_feed = bare(table.deepcopy(feed), "rf-probe-energy-feed")
for _, c in ipairs(categorised_feed.fluid_box.pipe_connections) do
  c.connection_category = CATEGORY
end

data:extend({
  categorised("rf-probe-exchanger-str", CATEGORY),
  categorised("rf-probe-exchanger-list", { CATEGORY }),
  chain,
  bare(table.deepcopy(chain), "rf-probe-exchanger-chain-b"),
  categorised_hc("rf-probe-hc-str", CATEGORY),
  source,
  categorised_feed,
})
'@
    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'data.lua') -Value $data

    $lua = @'
-- Generated by scripts/probe-energy-containment.ps1 (#82). Nothing here ships.
--
-- Reports findings, never a verdict. Each line is a measurement; the script that reads them only
-- insists that every row reported something.

local ENERGY = "rf-reactor-energy"
local SETTLE = __SETTLE__

local ORDINARY   = "infinity-pipe"
local CATEGORISED = "rf-probe-energy-feed"

-- Findings accumulate in `storage` rather than in a file-scope table. The rig is built by --create
-- in one process and measured by --benchmark in another, which LOADS the save, so anything on_init
-- kept in a local is thrown away with the process that found it. probe-native-heat.ps1 carries the
-- same note for the same reason.
local function say(fmt, ...)
  storage.notes = storage.notes or {}
  storage.notes[#storage.notes + 1] = string.format(fmt, ...)
end

local function must(entity, what)
  if not entity then error(what .. " refused") end
  return entity
end

local function yesno(b) return b and "YES" or "no" end

local function status_name(value)
  for name, v in pairs(defines.entity_status) do
    if v == value then return name end
  end
  return tostring(value)
end

--- The index of the box filtered to `fluid`, or nil.
--
-- A fluid energy source's box IS in entity.fluidbox and DOES carry its filter -- scripts/
-- bench-mod-links.ps1 already finds rf-heat-exchanger's energy intake this way. Worth stating,
-- because if it were not there the whole probe would report "no such box" and that would be a fact
-- about the API rather than about containment.
local function box_of(entity, fluid)
  for index = 1, #entity.fluidbox do
    local filter = entity.fluidbox.get_filter(index)
    if filter and filter.name == fluid then return index end
  end
  return nil
end

local function amount_of(entity, index)
  local contents = index and entity.fluidbox[index]
  return contents and contents.amount or 0
end

local function held(entity, fluid)
  return amount_of(entity, box_of(entity, fluid))
end

--- Does any connection on `index` reach `other`?
local function joins(entity, index, other)
  if not index or index > #entity.fluidbox then return false end
  for _, connection in pairs(entity.fluidbox.get_pipe_connections(index)) do
    if connection.target and connection.target.owner == other then return true end
  end
  return false
end

--- The tile a connection OCCUPIES, as against the tile it points at.
--
-- FluidBoxConnection.position is used when the API supplies it and derived otherwise: a connection
-- faces away from its entity, so its own tile is one step back from target_position towards that
-- entity's centre.
--
-- This exists because the two alignments in this rig are not the same one, and conflating them is
-- how the first run reported a bolt that would not take. A PIPE RUN aligns a connection's target
-- onto the tile the pipe sits in. A DIRECT BOLT aligns one machine's connection tile onto the
-- other's target -- align target against target and the two machines end up one tile clear of each
-- other, both pointing at the same empty ground, which reads exactly like a refused connection.
local function connection_tile(entity, c)
  if c.position then return c.position end
  local dx = c.target_position.x - entity.position.x
  local dy = c.target_position.y - entity.position.y
  if math.abs(dx) > math.abs(dy) then
    return { x = c.target_position.x - (dx > 0 and 1 or -1), y = c.target_position.y }
  end
  return { x = c.target_position.x, y = c.target_position.y - (dy > 0 and 1 or -1) }
end

--- Place `name` so that the connection on its `fluid` box pointing `side` lands on `target`.
--
-- The entity is placed once, asked where its connection actually points, and moved by the
-- difference. The alternative is writing down where a heat exchanger keeps its fuel intake, and
-- those are vanilla's numbers rather than this repository's -- exactly the class of remembered
-- constant that broke the reactor benchmark (#49). scripts/bench-mod-links.ps1 does the same.
--
-- `side` picks WHICH connection, geometrically rather than by index. The chain variant declares
-- three of them and pairs iterates in whatever order it likes, so taking the first would bolt the
-- exchanger on by a different face from one run to the next.
local function place_facing(surface, force, name, fluid, side, target, seed)
  local probe = must(surface.create_entity({ name = name, position = seed, force = force }),
    "a probe " .. name)
  local index = box_of(probe, fluid)
  if not index then
    probe.destroy()
    error(name .. " has no box filtered to " .. fluid)
  end
  local chosen
  for _, c in pairs(probe.fluidbox.get_pipe_connections(index)) do
    local dx = c.target_position.x - probe.position.x
    local dy = c.target_position.y - probe.position.y
    local matches =
      (side == "south" and dy > 0 and dx == 0) or
      (side == "north" and dy < 0 and dx == 0) or
      (side == "west"  and dx < 0) or
      (side == "east"  and dx > 0)
    if matches then chosen = c.target_position end
  end
  if not chosen then
    probe.destroy()
    error(string.format("%s's %s box has no connection on its %s face", name, fluid, side))
  end
  local position = {
    seed[1] + (target.x - chosen.x),
    seed[2] + (target.y - chosen.y),
  }
  probe.destroy()
  return must(surface.create_entity({ name = name, position = position, force = force }),
    string.format("%s at (%g, %g)", name, position[1], position[2]))
end

--- An infinity pipe on every connection of `index`, so the box under test is neither starved nor
--- backed up by something the probe is not asking about.
--- ... and never on a tile something already stands on.
--
-- create_entity does NOT collision-check, so without the occupancy test this happily buries a pipe
-- under a machine. It bit the chain row: the first exchanger's east water connection targets the
-- tile the SECOND exchanger then occupies, and its own west water target lands inside the first.
-- The energy reading survived it -- the strays are water-filtered and sit a row away from the energy
-- connections -- but a rig whose entire value is that its geometry is trustworthy cannot carry two
-- boilers overlapping two pipes.
--
-- Skipping is right rather than merely safe: two exchangers three tiles apart join through their
-- water boxes, so the row is fed along itself from whichever end is free.
local function unbound(surface, force, entity, index, filter)
  local attached = 0
  for _, connection in pairs(entity.fluidbox.get_pipe_connections(index)) do
    local occupied = surface.find_entities_filtered({ position = connection.target_position })
    if #occupied == 0 then
      local pipe = surface.create_entity({
        name = ORDINARY, position = connection.target_position, force = force,
      })
      if pipe then
        pipe.set_infinity_pipe_filter(filter)
        attached = attached + 1
      end
    end
  end
  -- Still an error rather than a note. Every box this is called on has at least one free face in
  -- this rig, so nothing attached means the layout moved -- and an exchanger with no water is a row
  -- that reports `no_input_fluid` for a reason that has nothing to do with the category.
  if attached == 0 then
    error(string.format("no free connection to attach an infinity pipe to on %s box %d",
      entity.name, index))
  end
end

--- Water in and steam out, so an exchanger that DOES get fuel can actually run.
--
-- Without both, a machine sitting at `working` versus `full_output` versus `no_fuel` says nothing
-- about whether fuel arrived -- which is the only thing this probe is measuring.
local function plumb_steam(surface, force, exchanger)
  local water = box_of(exchanger, "water")
  local steam = box_of(exchanger, "steam")
  if water then
    unbound(surface, force, exchanger, water, { name = "water", percentage = 1, mode = "at-least" })
  end
  if steam then
    unbound(surface, force, exchanger, steam, { name = "steam", percentage = 0, mode = "at-most" })
  end
end

-- A substation and an electric energy interface. `at` is the substation's centre and must be whole:
-- a 2x2 entity sits on a tile boundary where the 1x1 interface beside it sits on a tile centre, and
-- create_entity would snap a half-tile position rather than refuse it.
--
-- power_production is joules per TICK and nothing in the 2.0 API says so -- check-brownout.ps1
-- derives it against vanilla's own steam turbine. Nothing here measures power, but the reactor
-- carries an electric energy source and a boiler sitting at no_power is one more difference between
-- the rig and the mod than this probe needs.
--
-- A SUBSTATION REACHES 18 TILES, and the caller has to place this where that reach lands on the
-- reactor. The first version put it at (-40, 40) and powered nothing at all: every consumer was
-- outside the area in both axes, so the one electric machine in the rig ran the whole probe at
-- no_power while this function's own comment claimed otherwise. bench-reactors.ps1 errors out on
-- exactly that condition and probe-native-heat.ps1 comments on the 18-tile reach when it spaces its
-- poles; the assertion at the call site is this rig's version of the same guard.
local function power(surface, force, at)
  if at[1] % 1 ~= 0 or at[2] % 1 ~= 0 then
    error(string.format("power() wants a whole-number position, got (%g, %g)", at[1], at[2]))
  end
  must(surface.create_entity({ name = "substation", position = at, force = force }), "substation")
  local eei = must(surface.create_entity({
    name = "electric-energy-interface", position = { at[1] + 2.5, at[2] + 0.5 }, force = force,
  }), "power source")
  eei.power_production = 1e9 / 60
  eei.electric_buffer_size = 1e9 / 10
  return eei
end

--- One refuse-or-accept row: an exchanger with a single pipe on the tile its energy intake points
--- at, and nothing else touching that box.
local function offer(surface, force, label, exchanger_name, pipe_name, at)
  local e = place_facing(surface, force, exchanger_name, ENERGY, "south",
    { x = at[1], y = at[2] }, { at[1], at[2] - 20 })
  local pipe = must(surface.create_entity({ name = pipe_name, position = at, force = force }),
    pipe_name .. " for " .. label)
  pipe.set_infinity_pipe_filter({ name = ENERGY, percentage = 1, mode = "at-least" })
  plumb_steam(surface, force, e)
  return { label = label, exchanger = e, pipe = pipe, pipe_name = pipe_name }
end

script.on_init(function()
  local surface = game.surfaces[1]
  local force = game.forces.player
  surface.always_day = true
  -- The rig is built on generated chunks or create_entity refuses on unloaded ground.
  surface.request_to_generate_chunks({ 0, 0 }, 12)
  surface.force_generate_chunk_requests()

  -- Beside the bolt row rather than off in a corner. The reactor spans x [-7, 8] and y [53, 68], so
  -- a substation at (14, 60) supplies x [5, 23] and y [51, 69] -- overlapping the reactor's eastern
  -- columns without colliding with it. The offered rows need nothing: a boiler with a FLUID energy
  -- source draws no electricity at all.
  power(surface, force, { 14, 60 })

  storage.offers = {}
  local function add(label, exchanger_name, pipe_name, at)
    storage.offers[#storage.offers + 1] = offer(surface, force, label, exchanger_name, pipe_name, at)
  end

  -- The calibration row first, and deliberately so: it uses the SHIPPED exchanger and an ordinary
  -- pipe, which is what the mod does today, so it must read "joins" and "carries". Everything below
  -- is only meaningful relative to it.
  add("control",      "rf-heat-exchanger",        ORDINARY,    { 0.5, 0.5 })
  add("str/refuse",   "rf-probe-exchanger-str",   ORDINARY,    { 20.5, 0.5 })
  add("str/accept",   "rf-probe-exchanger-str",   CATEGORISED, { 40.5, 0.5 })
  add("list/refuse",  "rf-probe-exchanger-list",  ORDINARY,    { 60.5, 0.5 })
  add("list/accept",  "rf-probe-exchanger-list",  CATEGORISED, { 80.5, 0.5 })
  add("hc/refuse",    "rf-probe-hc-str",          ORDINARY,    { 100.5, 0.5 })
  add("hc/accept",    "rf-probe-hc-str",          CATEGORISED, { 120.5, 0.5 })

  -- ------------------------------------------------------------------ bolt and chain
  --
  -- One rig for both: the chain row IS the bolt row with a second exchanger on the end of it, and
  -- building two would mean two reactors to fill and two chances for the fill loop to differ.
  local reactor = must(surface.create_entity({
    name = "rf-probe-reactor", position = { 0.5, 60.5 }, force = force,
  }), "rf-probe-reactor")
  local out = box_of(reactor, ENERGY)
  if not out then error("rf-probe-reactor has no box filtered to " .. ENERGY) end
  -- The reactor's connection TILE, not the tile it points at -- see connection_tile above. The
  -- exchanger is then placed so that its own south connection points here, which puts its
  -- connection on the reactor's target and the two boxes face to face.
  local conn = reactor.fluidbox.get_pipe_connections(out)[1]
  local target = connection_tile(reactor, conn)
  storage.alignment = string.format(
    "the reactor's output sits on (%g, %g) and points at (%g, %g)",
    target.x, target.y, conn.target_position.x, conn.target_position.y)

  -- The reactor is the one electric machine in the rig, so it is the one worth asserting about.
  -- Silence here is what the first version shipped: a substation 40 tiles away, a reactor at
  -- no_power for the whole run, and a comment saying that had been taken care of.
  if not reactor.electric_network_id then
    error("rf-probe-reactor is on no electric network; move the substation to reach it")
  end

  local first = place_facing(surface, force, "rf-probe-exchanger-chain", ENERGY, "south",
    target, { 0.5, 40 })

  -- Three tiles east: the exchanger is three wide, so that is the next one along with no gap. Their
  -- energy connections at east {1,-0.5} and west {-1,-0.5} then point at each other's tile, and
  -- their water boxes join through east {1,0.5} against west {-1,0.5} at the same time.
  local second = must(surface.create_entity({
    name = "rf-probe-exchanger-chain-b",
    position = { first.position.x + 3, first.position.y }, force = force,
  }), "the second chained exchanger")

  -- BOTH exchangers exist before either is plumbed, and that ordering is the fix rather than a
  -- preference: unbound() skips a connection whose target tile is occupied, and it can only skip
  -- what has already been built. Plumbing `first` while `second` was still a gap buried an infinity
  -- pipe under it.
  plumb_steam(surface, force, first)
  plumb_steam(surface, force, second)

  storage.bolt = { reactor = reactor, out = out, first = first, second = second }

  say("built: %d offered rows, plus the bolt and chain pair", #storage.offers)
end)

local function report()
  say("== the instrument: does the rig's own join test work at all ==")
  say("The `control` row below is the SHIPPED exchanger with an ordinary pipe -- what the mod does")
  say("today. If it does not read joins=YES and carries>0, nothing else on this page means anything.")

  say("== AC 1: does connection_category reach the engine on a fluid energy source's box ==")
  for _, row in ipairs(storage.offers) do
    local index = box_of(row.exchanger, ENERGY)
    say("%-12s %-26s + %-22s joins=%-3s carries=%-10.6g status=%s",
      row.label, row.exchanger.name, row.pipe_name,
      yesno(joins(row.exchanger, index, row.pipe)),
      amount_of(row.exchanger, index),
      status_name(row.exchanger.status))
  end

  -- Corroboration only, and guarded, because the behavioural rows above are the ground truth: a
  -- category the API declines to publish can still be the one the engine enforces, and a category
  -- it publishes can still be ignored -- which is the entire premise of this probe.
  local ok, reading = pcall(function()
    local lines = {}
    for _, name in ipairs({ "rf-heat-exchanger", "rf-probe-exchanger-str",
                            "rf-probe-exchanger-list" }) do
      local seen = {}
      for _, box in pairs(prototypes.entity[name].fluidbox_prototypes) do
        if box.filter and box.filter.name == ENERGY then
          for _, c in pairs(box.pipe_connections) do
            seen[#seen + 1] = tostring(c.connection_category and
              (type(c.connection_category) == "table"
                and table.concat(c.connection_category, "+")
                or c.connection_category))
          end
        end
      end
      lines[#lines + 1] = string.format("%s -> %s", name,
        #seen > 0 and table.concat(seen, ", ") or "nothing on its energy box")
    end
    return table.concat(lines, " | ")
  end)
  if ok then
    say("prototype read: %s", reading)
  else
    say("prototype read: the API publishes no connection_category to read back (%s)",
      tostring(reading))
  end

  say("== AC 2: does a categorised energy-source box bolt straight to a reactor's output ==")
  local b = storage.bolt
  -- The alignment is printed rather than assumed, because the first run of this probe reported a
  -- refused bolt that was really an off-by-one in the rig. A reader can now see where the two
  -- machines actually are before believing anything below.
  say("bolt: %s, and the exchanger stands at (%g, %g)",
    storage.alignment, b.first.position.x, b.first.position.y)
  say("bolt: reactor output joins the exchanger directly, no pipe: %s",
    yesno(joins(b.reactor, b.out, b.first)))
  say("bolt: the exchanger holds %.6g units and reports %s",
    held(b.first, ENERGY), status_name(b.first.status))
  -- Read BEFORE the tick's refill, and that ordering is the whole value of the line. The first
  -- version read it after, inside the same handler that tops the box up, so it printed "1000 of a
  -- 1000" whatever had happened -- including in the failure case it was there to detect -- while
  -- the comment beside it claimed to tell a source that could not push from a bolt that would not
  -- take. It told them apart in prose only.
  --
  -- What it says now is narrow and true: how much the Lua fill was still holding after a tick of
  -- the exchanger drawing on it. The DISCRIMINATOR for AC 2 is the pair of lines above -- joins,
  -- and what the exchanger itself holds. This one only rules the source out as the constraint.
  say("bolt: the reactor's output box held %.6g units of a %.6g capacity going into this tick",
    storage.reactor_held or 0, b.reactor.fluidbox.get_capacity(b.out))
  say("bolt: and it is on an electric network, so it is not sitting at no_power: %s",
    status_name(b.reactor.status))

  say("== AC 3: does input-output chain on a fluid energy source's box ==")
  say("chain: the second exchanger joins the first: %s",
    yesno(joins(b.second, box_of(b.second, ENERGY), b.first)))
  say("chain: it holds %.6g units and reports %s",
    held(b.second, ENERGY), status_name(b.second.status))
  say("chain: against the first one's %.6g units and %s",
    held(b.first, ENERGY), status_name(b.first.status))
  -- Measured rather than reasoned. The write-up claimed this "incidentally", and nothing in the rig
  -- had ever asked it -- the geometry does work out, but an inference dressed as a measurement is
  -- exactly what a probe exists not to produce.
  say("chain: and their WATER boxes join as well, so one feed serves the row: %s",
    yesno(joins(b.second, box_of(b.second, "water"), b.first)))

  say("done: %d offered rows and the bolt pair, at tick %d", #storage.offers, SETTLE)
  for _, line in ipairs(storage.notes) do log("ENERGY-PROBE " .. line) end
end

script.on_event(defines.events.on_tick, function(event)
  -- Filled every tick rather than once: a bolted exchanger BURNS what arrives, so a single seed
  -- would be gone by the report and an empty box would read as a bolt that never took.
  local b = storage.bolt
  if b then
    -- Recorded BEFORE the refill on every tick, so the report tick has a reading the refill has not
    -- already overwritten. See the note beside the line that prints it.
    storage.reactor_held = amount_of(b.reactor, b.out)
    b.reactor.fluidbox[b.out] = {
      name = ENERGY,
      amount = b.reactor.fluidbox.get_capacity(b.out),
      temperature = 15,
    }
  end

  if event.tick == SETTLE then report() end
end)
'@

    $lua = $lua.Replace('__SETTLE__', "$Settle")
    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') -Value $lua
}

$step = @{ FactorioExe = $FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }

try {
    New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods $ourMods
    Write-ModList -ModDirectory $modDir -Bundled $bundled -EnabledBundled @() -Mods ($ourMods + $rigName)
    Write-Rig

    $save = Join-Path $temp 'energy-probe.zip'
    Invoke-FactorioStep @step -Arguments @('--create', $save) -Tag 'create' | Out-Null
    $runOut = Invoke-FactorioStep @step -Tag 'run' -Arguments @(
        '--benchmark', $save, '--benchmark-ticks', "$($Settle + 10)",
        '--benchmark-runs', '1', '--disable-audio')

    $reported = @(Get-Content $runOut | Select-String -Pattern 'ENERGY-PROBE ' |
        ForEach-Object { ($_ -split 'ENERGY-PROBE ', 2)[1].TrimEnd() })
    if ($reported.Count -eq 0) { throw 'the rig reported nothing; it never reached its report tick.' }

    foreach ($line in $reported) { Write-Host "  $line" }

    if (-not ($reported | Where-Object { $_ -match '^done: ' })) {
        throw 'the rig never reached its report tick; the findings above are incomplete.'
    }

    Write-Host ''
    Write-Host 'OK - the probe ran and every row reported. The answers are above, and they are'
    Write-Host '     evidence for #44 rather than a verdict, so nothing here passes or fails.'
}
finally {
    if ($KeepTemp) { Write-Host ''; Write-Host "temp kept at: $temp" }
    Remove-ModJunctions -ModDirectory $modDir
    if (-not $KeepTemp) { Remove-TempDirectory -Path $temp -Label 'probe-energy-containment' }
}

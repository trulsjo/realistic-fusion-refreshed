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
                for the fill loop to differ. The connection doing the bolting is south {-1, 7}, and
                it is NEITHER THE TILE NOR THE FACE the shipped machine declares: the shipped
                exchanger takes its energy on the west long face at {-2, 0}, which cannot meet a
                north-facing reactor output at all. This row is a claim about a shape that would
                chain, not about the one in the tree.

                Its FLOW IS NOT THE SAME either: the shipped exchanger declares flow_direction
                "input" on its one connection and this variant declares "input-output" on three.
                So what these rows establish is that a bolt and a chain work on the shape ADR 0018
                DECIDED -- item 4, whose own coordinates are the dead 3x2 ones -- and not that they
                would work on the one-connection shape as it stands today.

      chain     The bolt row with a second categorised exchanger fifteen tiles NORTH of the first,
                joined through energy connections on their south and north short ends. Whether the
                SECOND one receives anything is the whole question: a generator's box chains (proven
                in check-aneutronic.ps1), an energy source's box was not, and the answer decides
                whether eight exchangers hang off one reactor connection in a column or whether
                reactor energy has to reach each of them through a pipe. Ringing the reactor is not
                the alternative it was on the 3x2: rf-reactor declares ONE energy output, north
                {0, -7}, so exactly one machine can bolt to it however small that machine is.

      hc        The refuse/accept pair again on rf-hc-exchanger's shape, which has the same energy
                source on a seven-tile footprint. Chaining is not repeated for it: the mechanism is
                the same one, and #82 allows establishing that one answer covers both.

      input-    THE BOLT IS repeated for it, and that is #275's doing rather than #82's. Everything
      bolt      above bolts with an "input-output" connection, and rf-hc-exchanger declares ONE
                connection and declares it plain "input" -- south {0, 3} on its seven-tile face,
                which unlike the ordinary exchanger's west long face CAN meet a north-facing reactor
                output. So the one machine in the tree whose declaration could already bolt is the
                one whose bolt had never been measured, and exchanger-chaining.md establishes only
                that a plain "input" connection stops fuel LEAVING a box.

                It decides something concrete: whether #86 can contain that machine before #276
                changes its geometry, which is what would take a Blender model off #86's critical
                path. Its own reactor, because rf-reactor declares one energy output and the chain
                row has already taken the one on that machine.

    WHERE THE CHAIN VARIANT'S CONNECTIONS HAD TO GO, AND WHY IT IS NOT A FREE CHOICE

    THE SHAPE CHANGED UNDER THIS RIG AND THE RIG DID NOT NOTICE (#111). rf-heat-exchanger was
    vanilla's 3x2 when #82 ran, and #45 made it 5x15. Every coordinate in this section, in the chain
    variant below, and in ADR 0018's Decision item 4 was written for the 3x2 and is dead. A rig that
    keeps building the old shape is not measuring the current tree, so the AC 3 rows #82 recorded
    were taken on a machine this repository no longer ships.

    AND IT CHANGED AGAIN, SO EVERY COORDINATE BELOW IS A FRAME THIS RIG PINS RATHER THAN THE TREE'S
    (#275). ADR 0031 ships rf-heat-exchanger fifteen wide by five tall with energy `input-output` on
    north {0, -2} plus both short ends {-7, -1} and {7, -1}, water on {-7, 1} and {7, 1}, steam
    south {0, 2}; and rf-reactor now sells energy from TWO connections, north {0, -7} and south
    {0, 7}. The rows here are not rebuilt onto that -- ADR 0031 lists rebuilding them as a
    consequence, and scripts/check-hc.ps1's plant section is the gate on the shipped geometry -- so
    pre_275_frame() below pins the five-by-fifteen frame onto the copies this rig declares, and the
    paragraphs from here to the end of this section describe that pinned frame.

    THE PINNED FRAME. 5x15: tile centres x in {-2..2} and y in {-7..7}. Its own boxes take four of
    them -- energy in on the west LONG face at {-2, 0}, steam out on the east long face at {2, 0},
    water input-output on the two short ends at north {0, -7} and south {0, 7}. Two connections on
    one tile will not load.

    So a variant that chains has to chain along the COLUMN, north to south, and the free tiles on
    the short ends are {-1, -7} and {-1, 7}, beside the water. Those are the tiles
    probe-exchanger-chaining.ps1 uses for the same question, and the two rigs agree on purpose.
    The south one also does the bolting: the reactor's north energy output faces out from {0, -7}, so
    a machine bolting onto it stands above the reactor and meets it with a south-facing connection.
    The west long face cannot do that bolt at all -- it points west and the reactor's output does
    not.

    A consequence worth knowing: two exchangers fifteen tiles apart also join through their WATER
    boxes, south {0, 7} against north {0, -7}. One water feed serves the column -- which it has to,
    because the first exchanger's own water box ends up with both faces taken (the reactor below,
    the second exchanger above) and unbound() correctly attaches nothing to it.

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

#Requires -Version 7
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
$ourMods  = Get-RepoMods
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

-- THE FRAME EVERY COORDINATE IN THIS FILE IS DECLARED IN IS THE ONE #275 REPLACED. Every position
-- here is a five-wide-by-fifteen-tall tile centre with the energy face WEST, which is what the
-- shipped machine was when these rows were written and their findings recorded. ADR 0031 turned the
-- shipped rf-heat-exchanger fifteen wide by five tall with the energy face north, so a plain copy of
-- it no longer fits these coordinates -- a connection outside the collision box is a prototype the
-- engine refuses, and a probe that cannot load answers nothing. The frame is therefore pinned back
-- onto the copy here, boxes and all three fluid boxes, so the probe still measures the shape its
-- research note describes. IT MEASURES THAT SHAPE, NOT THE SHIPPED ONE: rebuilding the rows on the
-- shipped frame is a consequence ADR 0031 lists, and scripts/check-hc.ps1's plant section is the
-- gate on the shipped geometry. The rendered 15x5 sheets are left on it and draw wrong; a probe
-- does not look.
local function pre_275_frame(e)
  e.collision_box = { { -2.25, -7.25 }, { 2.25, 7.25 } }
  e.selection_box = { { -2.5, -7.5 }, { 2.5, 7.5 } }
  e.fluid_box = table.deepcopy(e.fluid_box)
  e.fluid_box.pipe_connections = {
    { flow_direction = "input-output", direction = defines.direction.north, position = { 0, -7 } },
    { flow_direction = "input-output", direction = defines.direction.south, position = { 0, 7 } },
  }
  e.output_fluid_box = table.deepcopy(e.output_fluid_box)
  e.output_fluid_box.pipe_connections = {
    { flow_direction = "output", direction = defines.direction.east, position = { 2, 0 } },
  }
  e.energy_source = table.deepcopy(e.energy_source)
  e.energy_source.fluid_box = table.deepcopy(e.energy_source.fluid_box)
  e.energy_source.fluid_box.pipe_connections = {
    { flow_direction = "input", direction = defines.direction.west, position = { -2, 0 } },
  }
  return e
end

local function categorised(name, category)
  local e = bare(pre_275_frame(table.deepcopy(exchanger)), name)
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
-- on today's 5x15 the west long face takes energy and the east one sells steam, so a column chains
-- through the short ends, and {-1,-7} and {-1,7} are the free tiles there. The south one also bolts
-- onto the reactor's north-facing output.
--
-- input-output on all three. production_type stays "input" -- what the machine DOES with the fluid
-- is unchanged; flow_direction is what decides whether a connection will join another machine's.
-- rf-direct-energy-converter's own box makes exactly that distinction and it is the reason a row of
-- converters connects at all.
--
-- These are the same three tiles probe-exchanger-chaining.ps1's categorised variant declares. Two
-- rigs asking one question have to build one shape, or a disagreement between them says nothing.
local chain = categorised("rf-probe-exchanger-chain", CATEGORY)
chain.energy_source.fluid_box.pipe_connections = {
  { flow_direction = "input-output", direction = defines.direction.west,
    position = { -2, 0 }, connection_category = CATEGORY },
  { flow_direction = "input-output", direction = defines.direction.north,
    position = { -1, -7 }, connection_category = CATEGORY },
  { flow_direction = "input-output", direction = defines.direction.south,
    position = { -1, 7 }, connection_category = CATEGORY },
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
-- `side` may be nil, meaning "the box's only connection, wherever it is".
--
-- IT USED TO BE MANDATORY AND THAT BROKE THIS PROBE. Both shipped exchangers took their energy on
-- the south face when this was written, so the two calls below said "south" and meant "the energy
-- inlet". #45 moved rf-heat-exchanger's onto its west long face -- five by fifteen exists so that a
-- long side lies along a reactor -- and the probe stopped running with "has no connection on its
-- south face". A rig that names a face is asserting a layout it does not own.
--
-- So a caller that just wants the one connection asks for it that way, and only a box with several
-- has to say which. TWO callers now say which, and only one of them declares the face it names:
-- the chain variant below is rig-defined, but the `control` row names "north" on the SHIPPED
-- exchanger, which since #275 has three energy connections and no single one to guess. That is the
-- layout-it-does-not-own case this comment warns about, taken knowingly: it fails loudly, with
-- "has no connection on its north face", rather than measuring the wrong tile in silence.
local function place_facing(surface, force, name, fluid, side, target, seed)
  local probe = must(surface.create_entity({ name = name, position = seed, force = force }),
    "a probe " .. name)
  local index = box_of(probe, fluid)
  if not index then
    probe.destroy()
    error(name .. " has no box filtered to " .. fluid)
  end
  local connections = probe.fluidbox.get_pipe_connections(index)
  local chosen
  if side == nil then
    if #connections ~= 1 then
      probe.destroy()
      error(string.format(
        "%s's %s box has %d connections, so the caller has to say which face to align",
        name, fluid, #connections))
    end
    chosen = connections[1].target_position
  else
    for _, c in pairs(connections) do
      local dx = c.target_position.x - probe.position.x
      local dy = c.target_position.y - probe.position.y
      -- WHICH WAY THE CONNECTION FACES, by its dominant axis. It used to require dx == 0 for north
      -- and south, which is only true of a connection in the middle of a short end -- and on the
      -- 5x15 the middle of both short ends is water, so the chain variant's energy connections sit
      -- one tile off centre at {-1, -7} and {-1, 7} and matched nothing. A connection points along
      -- whichever axis it is further out on; that is the test.
      local matches =
        (side == "south" and dy > 0 and math.abs(dy) > math.abs(dx)) or
        (side == "north" and dy < 0 and math.abs(dy) > math.abs(dx)) or
        (side == "west"  and dx < 0 and math.abs(dx) > math.abs(dy)) or
        (side == "east"  and dx > 0 and math.abs(dx) > math.abs(dy))
      if matches then chosen = c.target_position end
    end
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
--- ... and never on a tile something already stands on, and never silently on none of them.
--
-- create_entity does NOT collision-check, so without the occupancy test this happily buries a pipe
-- under a machine. It bit the chain row: the first exchanger's north water connection targets the
-- tile the SECOND exchanger then occupies, and its south one targets a tile inside the reactor.
-- The energy reading survived it -- the strays are water-filtered and sit clear of the energy
-- connections -- but a rig whose entire value is that its geometry is trustworthy cannot carry two
-- boilers overlapping two pipes.
--
-- (It bit it on the 3x2 machine, where the pair chained sideways and the clash was east against
-- west. The clash moved with the shape and did not go away, which is the point: this test is about
-- a neighbour standing on a target tile, not about which face that neighbour is on.)
--
-- Skipping is right rather than merely safe: two exchangers fifteen tiles apart join through their
-- water boxes, so the column is fed along itself from whichever end is free.
local function unbound(surface, force, entity, index, filter, allow_none)
  local attached = 0
  local total = 0
  for _, connection in pairs(entity.fluidbox.get_pipe_connections(index)) do
    total = total + 1
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
  -- STILL AN ERROR UNLESS THE CALLER SAID OTHERWISE, and the flag is the point (#111). This used
  -- to error unconditionally, on the stated grounds that "every box this is called on has at least
  -- one free face in this rig" -- which was never true of the chained pair: the first exchanger's
  -- water box has the reactor below it and the second exchanger above it, so both faces are taken
  -- and the probe died during map creation instead of reporting anything.
  --
  -- Making it a note for every caller was the wrong fix and is not what this does. All faces taken
  -- is legitimate for ONE box in this rig and a broken layout everywhere else, and the failure it
  -- would then hide is one this rig has already had: a control machine placed a tile too close
  -- covered the last free water face of the column, both chained exchangers dropped to
  -- no_input_fluid, and AC 3 reported on two machines that were not running. So only the caller
  -- that owns the legitimate case passes allow_none, and everything else still stops the run.
  if attached == 0 then
    if not allow_none then
      error(string.format("no free connection to attach an infinity pipe to on %s box %d (%s)",
        entity.name, index, filter.name))
    end
    say("plumbing: %s box %d (%s) has all %d of its faces taken by neighbours, so it is fed along " ..
      "the column rather than from a pipe of its own",
      entity.name, index, filter.name, total)
  end
end

--- Water in and steam out, so an exchanger that DOES get fuel can actually run.
--
-- Without both, a machine sitting at `working` versus `full_output` versus `no_fuel` says nothing
-- about whether fuel arrived -- which is the only thing this probe is measuring.
--- `boxed_in` permits the WATER box to have no free face, and nothing else does. It is true for
--- exactly one machine here -- the lower exchanger of the chained pair, with the reactor on one
--- short end and its neighbour on the other -- and that machine is fed along the column instead.
local function plumb_steam(surface, force, exchanger, boxed_in)
  local water = box_of(exchanger, "water")
  local steam = box_of(exchanger, "steam")
  if water then
    unbound(surface, force, exchanger, water, { name = "water", percentage = 1, mode = "at-least" },
      boxed_in)
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
local function offer(surface, force, label, exchanger_name, pipe_name, at, side)
  -- nil for the variants: whichever face the one-connection frame takes its energy on. See above.
  -- The SHIPPED rf-heat-exchanger has had three energy connections since #275, so its row has to
  -- name the face, or place_facing rightly refuses to guess.
  local e = place_facing(surface, force, exchanger_name, ENERGY, side,
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

  -- AND CLEAR WHAT STANDS ON THE GROUND, for the reason probe-exchanger-chaining.ps1's row section
  -- gives: a --create map is seeded afresh every run, and unbound() skips a target tile something
  -- stands on -- so a tree on one row's steam target reads as "all faces taken" and the rig dies
  -- during map creation, on a row that changed nothing. Seen twice in three runs on 2026-09-07,
  -- on the list/refuse row both times. The area covers every row this file places, with margin.
  for _, e in pairs(surface.find_entities_filtered({ area = { { -70, -50 }, { 160, 90 } } })) do
    if e.type ~= "character" then e.destroy() end
  end

  -- Beside the bolt row rather than off in a corner. The reactor spans x [-7, 8] and y [53, 68], so
  -- a substation at (14, 60) supplies x [5, 23] and y [51, 69] -- overlapping the reactor's eastern
  -- columns without colliding with it. The offered rows need nothing: a boiler with a FLUID energy
  -- source draws no electricity at all.
  power(surface, force, { 14, 60 })

  -- The one-connection bolt row has a reactor of its own, spanning x [53, 68] and y [53, 68], and a
  -- substation reaches eighteen tiles -- so the one above supplies nothing there. At (75, 60) this
  -- covers x [66, 84] and y [51, 69], overlapping that reactor's eastern columns without colliding
  -- with it. The row's exchanger needs nothing: a boiler with a FLUID energy source draws no
  -- electricity at all.
  power(surface, force, { 75, 60 })

  storage.offers = {}
  local function add(label, exchanger_name, pipe_name, at, side)
    storage.offers[#storage.offers + 1] = offer(surface, force, label, exchanger_name, pipe_name, at, side)
  end

  -- The calibration row first, and deliberately so: it uses the SHIPPED exchanger and an ordinary
  -- pipe, which is what the mod does today, so it must read "joins" and "carries". Everything below
  -- is only meaningful relative to it.
  -- "north": the shipped machine's reactor-facing energy connection (ADR 0031). Its two short-end
  -- connections would answer the same question; one face is enough for a pipe to be offered to.
  add("control",      "rf-heat-exchanger",        ORDINARY,    { 0.5, 0.5 }, "north")
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

  -- The seed is a scratch position, and place_facing offsets FROM IT rather than from where the
  -- engine put the scratch entity -- so it has to be a position the engine would not move. A 5x15
  -- has odd dimensions both ways, which means a tile centre in both axes: X.5, not X.
  local first = place_facing(surface, force, "rf-probe-exchanger-chain", ENERGY, "south",
    target, { 0.5, 40.5 })

  -- Fifteen tiles NORTH: the exchanger is fifteen tall, so that is the next one up the column with
  -- no gap. Their energy connections at north {-1,-7} and south {-1,7} then point at each other's
  -- tile, and their water boxes join through {0,-7} against {0,7} at the same time.
  --
  -- North rather than south because south is where the reactor is. It used to be three tiles east,
  -- which was right for the 3x2 machine #82 measured and buries a 5-wide one inside its neighbour.
  local second = must(surface.create_entity({
    name = "rf-probe-exchanger-chain-b",
    position = { first.position.x, first.position.y - 15 }, force = force,
  }), "the second chained exchanger")

  -- BOTH exchangers exist before either is plumbed, and that ordering is the fix rather than a
  -- preference: unbound() skips a connection whose target tile is occupied, and it can only skip
  -- what has already been built. Plumbing `first` while `second` was still a gap buried an infinity
  -- pipe under it.
  -- THE CHAIN ROW'S OWN CALIBRATION, and it was missing (#111). A third one, same prototype and
  -- same plumbing as the second, joined to nothing at all. If it holds fuel anyway, then "the
  -- second holds fuel" is the rig filling everything it can reach rather than a chain, and every
  -- AC 3 row is void.
  --
  -- The rest of this probe has such a row -- `control` is exactly this for the offered pairs -- and
  -- the chain row went without one, which is how a disagreement with probe-exchanger-chaining.ps1
  -- lasted from #82 to #111 with nothing able to break the tie.
  --
  -- WELL CLEAR OF THE COLUMN, and that is load-bearing rather than tidy. The first attempt put it
  -- one tile off the line where the second's neighbour would be: it read the right answer -- not
  -- joined, no fuel -- and its own footprint then covered the tile the second exchanger's last free
  -- water face pointed at, so unbound() skipped it, the column lost its only water feed and both
  -- chained machines dropped to no_input_fluid. A control that changes what it is calibrating is
  -- not a control.
  local aloof = must(surface.create_entity({
    name = "rf-probe-exchanger-chain-b",
    position = { -40.5, first.position.y }, force = force,
  }), "the unjoined third exchanger")

  -- `first` is the one box that is allowed to find no free water face: the reactor is on its south
  -- end and `second` on its north. Every other call still errors, which is what catches a machine
  -- standing where a pipe should go.
  plumb_steam(surface, force, first, true)
  plumb_steam(surface, force, second)
  plumb_steam(surface, force, aloof)

  storage.bolt = { reactor = reactor, out = out, first = first, second = second, aloof = aloof }

  -- ------------------------------------------------ the ONE-CONNECTION, plain-"input" bolt (#275)
  --
  -- rf-probe-hc-str is the shipped rf-hc-exchanger with its energy box categorised and nothing else
  -- touched, so what it declares is the real declaration: ONE connection, flow_direction "input",
  -- on the face that has to meet a reactor.
  --
  -- NOTHING HAS EVER MEASURED WHETHER THE ENGINE FORMS THAT BOLT. The bolt row above measures it on
  -- the chain variant, whose bolting connection is "input-output" -- CONTEXT.md says so out loud --
  -- and docs/research/exchanger-chaining.md establishes that a plain "input" connection stops fuel
  -- LEAVING a box. Whether it also stops fuel ARRIVING through a direct bolt is a different
  -- question and it has no answer on this page.
  --
  -- Which way it reads decides whether rf-hc-exchanger can be contained (#86) before its own
  -- geometry changes (#276), which is the one thing that could take a Blender model off #86's
  -- critical path.
  --
  -- ITS OWN REACTOR, because rf-reactor declares a single energy output and the chain row above has
  -- already taken the one on that machine.
  local hc_reactor = must(surface.create_entity({
    name = "rf-probe-reactor", position = { 60.5, 60.5 }, force = force,
  }), "the hc row's rf-probe-reactor")
  local hc_out = box_of(hc_reactor, ENERGY)
  if not hc_out then error("the hc row's rf-probe-reactor has no box filtered to " .. ENERGY) end
  if not hc_reactor.electric_network_id then
    error("the hc row's rf-probe-reactor is on no electric network; move or add a substation")
  end
  local hc_conn   = hc_reactor.fluidbox.get_pipe_connections(hc_out)[1]
  local hc_target = connection_tile(hc_reactor, hc_conn)

  -- side = nil on purpose: rf-hc-exchanger's energy box has exactly ONE connection, and asking for
  -- it that way makes place_facing error rather than guess if that ever stops being true. Naming a
  -- face here would assert a layout this rig does not own -- the mistake #45 already caused once.
  local hc_bolt = place_facing(surface, force, "rf-probe-hc-str", ENERGY, nil,
    hc_target, { 60.5, 40.5 })
  plumb_steam(surface, force, hc_bolt)

  -- Its calibration: a second one joined to nothing, plumbed the same way. Without it, "the bolted
  -- one holds fuel" cannot be told from the fill loop reaching everything, which is the exact
  -- failure #111 was opened for.
  local hc_aloof = must(surface.create_entity({
    name = "rf-probe-hc-str", position = { 100.5, hc_bolt.position.y }, force = force,
  }), "the unjoined hc exchanger")
  plumb_steam(surface, force, hc_aloof)

  storage.hc = { reactor = hc_reactor, out = hc_out, machine = hc_bolt, aloof = hc_aloof }

  say("built: %d offered rows, the bolt and chain pair, and the one-connection bolt row",
    #storage.offers)
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
    storage.first_held or 0, status_name(b.first.status))
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
    storage.second_held or 0, status_name(b.second.status))
  say("chain: against the first one's %.6g units and %s",
    storage.first_held or 0, status_name(b.first.status))
  -- Measured rather than reasoned. The write-up claimed this "incidentally", and nothing in the rig
  -- had ever asked it -- the geometry does work out, but an inference dressed as a measurement is
  -- exactly what a probe exists not to produce.
  say("chain: and their WATER boxes join as well, so one feed serves the row: %s",
    yesno(joins(b.second, box_of(b.second, "water"), b.first)))
  say("chain/control: an unjoined third one off to the side joins the second: %s, and holds %.6g "
    .. "units -- this row must read no and 0, or the two above mean nothing",
    yesno(joins(b.aloof, box_of(b.aloof, ENERGY), b.second)), storage.aloof_held or 0)

  -- AC 5 (#275). The chain rows above bolt with an "input-output" connection. rf-hc-exchanger
  -- declares ONE connection and declares it plain "input", and no row anywhere had asked whether
  -- that still bolts. If it does, containment (#86) does not have to wait for that machine's new
  -- geometry (#276) or for its art.
  local h = storage.hc
  if h then
    say("== AC 5: does a single plain-\"input\" connection accept a bolt from a reactor's output ==")
    say("input-bolt: the subject is rf-probe-hc-str -- the shipped rf-hc-exchanger, categorised,")
    say("input-bolt: one energy connection, flow_direction \"input\", nothing else changed")
    say("input-bolt: its box joins the reactor's output directly, no pipe: %s",
      yesno(joins(h.machine, box_of(h.machine, ENERGY), h.reactor)))
    say("input-bolt: it holds %.6g units and reports %s",
      storage.hc_held or 0, status_name(h.machine.status))
    say("input-bolt: the reactor's output box held %.6g of a %.6g capacity going into this tick",
      storage.hc_reactor_held or 0, h.reactor.fluidbox.get_capacity(h.out))
    say("input-bolt/control: an unjoined one off to the side holds %.6g units -- this must read 0, "
      .. "or the row above is the fill loop reaching everything", storage.hc_aloof_held or 0)
  end

  say("done: %d offered rows, the bolt pair and the one-connection bolt, at tick %d",
    #storage.offers, SETTLE)
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
    -- AND THE TWO EXCHANGERS, for the reason #111 exists. The reactor's output, the first exchanger
    -- and the second are all joined, so a reading taken after the refill cannot rule out the write
    -- having filled the whole run. Read before the write, these two say what the machines held on
    -- their own -- and the unjoined third machine below says what a box holds when nothing feeds
    -- it, which is the row that actually discriminates.
    storage.first_held  = held(b.first, ENERGY)
    storage.second_held = held(b.second, ENERGY)
    storage.aloof_held  = held(b.aloof, ENERGY)
    b.reactor.fluidbox[b.out] = {
      name = ENERGY,
      amount = b.reactor.fluidbox.get_capacity(b.out),
      temperature = 15,
    }
  end

  -- The one-connection bolt row, read before its own refill for the same reason as the block above:
  -- a reading taken after the write cannot rule out the write having filled the joined run.
  local h = storage.hc
  if h then
    storage.hc_reactor_held = amount_of(h.reactor, h.out)
    storage.hc_held         = held(h.machine, ENERGY)
    storage.hc_aloof_held   = held(h.aloof, ENERGY)
    h.reactor.fluidbox[h.out] = {
      name = ENERGY,
      amount = h.reactor.fluidbox.get_capacity(h.out),
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

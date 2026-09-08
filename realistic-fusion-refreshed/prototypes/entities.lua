require("util") -- table.deepcopy

-- Core owns the shared cleanup, because ADR 0010's dependency runs one way and this is the way it
-- runs: Power requires Core, never the reverse.
local claim = require("__realistic-fusion-refreshed-core__.prototypes.vanilla").claim

-- The simulation's own constants, at the PROTOTYPE stage. The only thing taken from here is the
-- confinement heating each reactor draws, and it is taken rather than retyped because that figure
-- is stated to the player in two locale strings and a third statement of it would be a third thing
-- to keep in step (#46). scripts/reactor-logic.lua is pure Lua and says so at its head -- it
-- touches no data, game, storage or settings -- which is what makes requiring it here legitimate
-- rather than a stage violation. This is the ONLY direction the dependency runs: nothing in
-- scripts/ requires anything in prototypes/.
local logic = require("scripts.reactor-logic")
-- Drawn placeholders for the machines with no art of their own (#45). Our own work and
-- our own licence, unlike graphics/krastorio-2/ -- see the module for why that matters.
local mockup = require("__realistic-fusion-refreshed-assets__.graphics.mockup.pictures")
-- The real thing, rendered from a Blender model (#238). Also our own work and our own licence. A
-- machine moves from mockup to rendered when its model exists and the look has been accepted in
-- game; rf-heat-exchanger is the first (#252).
local rendered = require("__realistic-fusion-refreshed-assets__.graphics.rendered.pictures")

-- What a reactor's tooltip cannot say for itself. Both reactors are boilers (ADR 0011), so the
-- engine reports the boiler's energy_consumption as "Max consumption" -- 1 W, seven orders below
-- the truth, because the real draw is spent out of buffer_capacity by control.lua and the engine
-- has no way to know. That figure is a HOST ARTEFACT in CONTEXT.md's sense: it belongs to the
-- prototype the reactor is built on and not to the simulation, and the rule there is to explain
-- one rather than correct it, because correcting this one hands the boiler a fluid conversion rate
-- proportional to it -- which is precisely what the 1 W is for.
--
-- The megawatt figure is interpolated from the spec rather than written into the locale file, so
-- the two reactors get 50 and 200 from one string each and neither can drift from heating_power_w.
local function heating_note(spec, key)
  return { key, string.format("%d", spec.heating_power_w / 1e6) }
end

-- Power's machines, built from vanilla ones: the base entity is chosen for its shape and fluid
-- box count, which is the part that decides behaviour.
--
-- Icons are derived from Krastorio 2 (LGPLv3) and live in graphics/krastorio-2/ with the licence
-- and a NOTICE naming every source file. Do not move one out of that directory -- the licence
-- travels with the directory, not with this file (legal-note.txt).
--
-- Every stat that affects balance is pinned rather than inherited, because a deep copy taken here
-- picks up whatever a mod sorting earlier has already done to the source prototype.

local ENTITY = "__realistic-fusion-refreshed-assets__/graphics/krastorio-2/entities/"

-- Plasma must not travel through vanilla pipes (CONTEXT.md, ADR 0010). This is what enforces it.
--
-- SINCE #86 AND #87 THE SAME SENTENCE IS TRUE OF THE TWO ENERGY FLUIDS, which ADR 0010 could not
-- have said: at the time they were meant to travel on ordinary pipes. ADR 0018 gives each of them a
-- category of its own and ships no pipe that carries either, so an exchanger or a converter bolts
-- onto a reactor face and chains to its neighbours, and there is no pipe, no tank and no wagon on
-- that leg at all. Everything below about what a coexisting set can do to a category applies to all
-- three families equally.
--
-- 2.0 gives a pipe connection a connection_category, and two connections join only when theirs
-- match. Naming a category of our own therefore makes a vanilla pipe beside a plasma line simply
-- not connect -- the same way it already refuses to join a heat pipe. The plasma never enters,
-- which is a stronger statement than noticing that it did.
--
-- WHAT THE GUARANTEE COVERS IS PLUMBING A PLAYER CAN BUILD, and the set of things sharing the
-- category is open. Wube give the editor's infinity pipe a SECOND category on purpose --
-- space-age/base-data-updates.lua sets it to {"default", "fusion-plasma"} -- so that an instrument
-- can feed what nothing buildable carries; ADR 0018 records it. And a mod that COLLECTS categories
-- will collect ours: SeaBlock's `no-pipe-touching` sweeps `rf-plasma` onto vanilla `infinity-pipe`,
-- along with the bare name of every pipe prototype it finds, naming nothing of ours and testing for
-- no prefix. That lane reports the infinity pipe as a replacement and stays red on purpose (#195,
-- ADR 0028).
--
-- A SET DOES ALSO TAKE A CATEGORY AWAY, AND ON ONE LANE THIS GUARANTEE IS HELD BY PERMISSION
-- RATHER THAN BY DECLARATION -- see the opt-out at the pipe-to-ground below, which is what closes
-- it. What follows is what the guarantee is worth without that field, and it is stated in full
-- because the field is one mod wide and the next mod gets none of it. MEASURED on
-- 2026-09-01 against 2.0.77 by scripts/probe-connection-categories.ps1 on the seablock lane, and
-- written up in docs/research/connection-category-reassignment.md -- it was a reading of somebody
-- else's Lua when #206 opened and it is a dump now. That mod's last pipe-to-ground pass fires for a
-- prototype that is not solved_by_npt, carries no npt_compat and holds no default category -- which
-- is the shape containment itself gives rf-pipe-to-ground -- and BOTH of that entity's connections
-- come out changed: the underground one reads the literal "pipe-to-ground" with rf-plasma gone, and
-- the surface one keeps rf-plasma with twelve more categories appended beside it. A category is a
-- whitelist, so the second is a breach as much as the first. Precisely the protection stated at
-- contain() on the pipe-to-ground below, removed twice over.
--
-- WHAT SURVIVED IS THE OTHER HALF OF THE FINDING, AND "SURVIVED" IS NOT "UNTOUCHED". Containment
-- holds on the other twelve of the fourteen contained connections, rf-pipe's four among them, so
-- this is one pass over one prototype type and not containment failing in general. But that mod
-- rewrites the field in place on ALL fourteen -- the bare string this function writes comes back as
-- a one-element list -- because its has_default_category assigns unify() back to every connection it
-- merely inspects. Same category to the engine, nothing changed about what connects, and worth
-- knowing anyway: it is not leaving our contained boxes alone, it is making twelve equivalent edits.
--
-- FOURTEEN WAS THE COUNT ON 2026-09-01 AND THE TREE HAS MOVED. Containment was plasma-only then;
-- #86 and #87 took it to twenty-four by categorising the ten energy connections. The finding does
-- not change -- the pass that breached is a pipe-to-ground pass and reaches no energy box -- but
-- twelve of fourteen is that day's dump rather than today's, and load-check counts today's.
--
-- load-check FAILS on it since #209 (2026-09-02): it dumps the game twice on every lane, once with
-- our mods alone for what this file declared and once with the set, and a category written here that
-- is gone from the second ends the run. What it does not fail on is an ADDITION to a connection we
-- categorised -- that is #195's shape, and the probe below reports it. name-check is still blind to
-- all of it, and so is everything else about what a set does to prototypes of OURS beyond connection
-- categories (ADR 0007's finding 4). #207 swept all fourteen and ONE of them does this -- only the seablock
-- lane, only no-pipe-touching, only rf-pipe-to-ground; three lanes add a category to boxes we left
-- default and remove nothing, and eleven change nothing at all
-- (docs/research/connection-categories-by-lane.md).
--
-- SO WHAT IS THE GUARANTEE WORTH UNDER A SET THAT REASSIGNS CATEGORIES? Exactly this much, and #208
-- decided to leave it here rather than build past it: THE DECLARATION ALONE DOES NOT SURVIVE A
-- data-final-fixes THAT REWRITES IT, AND NOTHING IN THIS REPO MAKES IT SURVIVE. What holds on the
-- one lane where that happens is a field naming that mod's own opt-out, which defends against that
-- mod and against nothing else. A second mod doing the same thing would open the same hole again and
-- #209's gate now sees it: load-check fails when a category written here is gone from the loaded
-- dump, which is the trigger for reopening #208 rather than a thing to be noticed by reading Lua.
-- Write nothing here that assumes containment survives an arbitrary set: it does not, and the fix
-- below is a permission rather than a defence.
--
-- The 1.1 original could not do this and spent 160 lines of control.lua hunting down plasma-carrying
-- vanilla pipes and destroying them. That is a tick cost, a surprise for whoever built the pipe, and
-- a race with whatever put the plasma there. None of it is needed against 2.0, so none of it is
-- here: this file is the whole of the enforcement and control.lua gains nothing.
--
-- Applied per box rather than per entity, because the reactor's plasma box and its energy box are
-- contained under DIFFERENT categories, and the heater is still fed deuterium through ordinary pipes.
local PLASMA_CATEGORY = "rf-plasma"

-- THREE CATEGORIES, ONE PER CONTAINED FLUID FAMILY (ADR 0018 items 1 and 3, #86 and #87). Named
-- after the fluid each carries, the way PLASMA_CATEGORY is named after the plasma family, and
-- SEPARATE ON PURPOSE: sharing one between the two energies would let a converter bolt onto a
-- neutronic reactor and then sit dry, which is the silent failure the separation exists to make
-- impossible. The engine refuses the connection instead.
--
-- Nothing a player can build carries either, and nothing is added -- item 2. An exchanger bolts to
-- a reactor face and chains to its neighbours; a converter does the same on its own tier. What that
-- removes is a capability nobody designed: a vanilla storage tank held 25 GJ of reactor energy and a
-- fluid wagon 50 GJ, against a vanilla accumulator's 5 MJ.
local REACTOR_ENERGY_CATEGORY    = "rf-reactor-energy"
local ANEUTRONIC_ENERGY_CATEGORY = "rf-aneutronic-reactor-energy"

-- THE CATEGORY IS AN ARGUMENT, not this function's own constant, and that is the whole of #84's
-- share of it. ADR 0018 gives rf-reactor-energy and rf-aneutronic-reactor-energy a category each,
-- so containment needs three rather than one; a helper that names plasma internally would have to
-- be rewritten by the ticket that can least afford a wide diff. Passing it costs one word per call
-- and left #86 changing call sites rather than this, which is what happened.
local function contain(box, category)
  if not category then error("contain() needs a connection category; see ADR 0018") end
  for _, connection in ipairs(box.pipe_connections or {}) do
    connection.connection_category = category
  end
  return box
end

-- Naming and mining, then Core's claim() for the rest: our icon on, vanilla's off, and the two
-- links back to the machine this was copied from cut. The icon path is derived from the name here
-- rather than in claim(), because Power's art is Power's and lives under Power's licence.
local function pin(e, name, opts)
  e.name = name
  e.minable = { mining_time = opts.mining_time or 1, result = name }
  return claim(e, ENTITY .. name:gsub("^rf%-", "") .. ".png")
end

-- ---------------------------------------------------------------- heater

-- Deuterium in, plasma out, on an ordinary recipe. The heater is the only ordinary machine on the
-- power side: it ionises and injects, and the confinement heating that takes the plasma from
-- there to fusion temperature is the reactor's job and the simulation's.
local heater = pin(table.deepcopy(data.raw["assembling-machine"]["chemical-plant"]), "rf-heater", {
  mining_time = 0.5,
})
heater.crafting_categories = { "rf-plasma-heating" }
heater.crafting_speed = 1
heater.energy_usage = "5MW"
heater.module_slots = 3
-- No productivity: a productivity bonus on this recipe would conjure plasma, and plasma is
-- energy. Speed and efficiency are fine.
heater.allowed_effects = { "consumption", "speed", "pollution", "quality" }
-- Krastorio 2's fuel refinery, which is the icon this machine already carries and is modelled on
-- the same vanilla chemical plant -- same boxes, same four pipe positions. So unlike the reactor
-- this is a sprite swap and nothing else. LGPLv3; see the file for why it lives over there.
heater.graphics_set = require("__realistic-fusion-refreshed-assets__.graphics.krastorio-2.buildings.heater-pictures")
-- Plasma leaves through the output boxes, so those are plasma-safe only; the input boxes stay
-- ordinary because deuterium arrives through ordinary pipes. Selected by production_type rather
-- than by index: which box a chemical plant puts a result in is the recipe's business, and the two
-- output boxes are interchangeable.
for _, box in ipairs(heater.fluid_boxes) do
  if box.production_type == "output" then contain(box, PLASMA_CATEGORY) end
end

-- ---------------------------------------------------------------- reactor

-- The simulated object (ADR 0011). Everything it does happens in control.lua; the prototype is
-- chosen for what the engine will do with fluid, not for what it nominally is.
--
-- It is a boiler, and that is not arbitrary. A crafting machine was the obvious choice and does
-- not work: with no recipe set it moves no fluid at all -- pipes connect to it and nothing ever
-- crosses, filter or no filter -- and a crafting machine's fluid boxes may only be "input" or
-- "output" types, which are one-way. A boiler fills its input box from whatever it is plumbed to
-- whether or not it is doing anything, and its input box may be "input-output": the storage-style
-- kind that joins the fluid segment it is connected to rather than being a one-way sink. That is
-- what makes every reactor on one run of rf-pipe work from a single pool at a single mixed
-- temperature, maintained by the engine, with no connectivity code anywhere in this mod.
--
-- The boiler's own conversion is neutered rather than used, and #101 measured how -- correcting
-- this comment, which had it backwards. It used to say "at 1 W the engine can move on the order of
-- one unit per fifty hours whatever the temperatures are" and that "target_temperature is NOT what
-- makes it safe [...] so reasoning from the temperature delta proves nothing". The delta is in
-- fact the entire mechanism.
--
-- What the engine does, measured by scripts/probe-target-temperature.ps1 on boilers the simulation
-- never touches, so the engine's conversion is separated from what control.lua burns:
--
--   * ABOVE the target it moves NOTHING. Not slowly -- exactly zero, at every target from 15 to
--     1e6 and every draw up to 50 MW, with plasma at the shipped 2.42e8 C equilibrium. A fusing
--     reactor would convert nothing even if energy_consumption were 50 MW.
--   * BELOW the target it follows the documented formula to two parts in a thousand:
--     energy_consumption / (heat_capacity * (target - input)), with heat_capacity 1000 J/unit/C.
--
-- So the 1 W is not what protects a running reactor -- being hotter than the target is. The 1 W is
-- what protects an IDLE one: reactor-logic clamps plasma to min_temperature_c = 15, which is below
-- this target, so a cold reactor sits in the converting regime and moves one unit per 41.7 hours.
-- That is the "fifty hours" the old wording half-remembered, and it applies at the floor only.
--
-- One consequence, derived rather than observed and written up in docs/research/target-temperature.md:
-- apply() SETS box 1 and ACCUMULATES box 2, so plasma the engine took is discarded while reactor
-- energy it made is kept. At the floor that is about 6.7 W of output nothing paid plasma for --
-- 1.3e-7 of the reactor's own draw, and negligible until energy_consumption is ever raised.
--
local reactor = pin(table.deepcopy(data.raw["boiler"]["heat-exchanger"]), "rf-reactor", {
  mining_time = 3,
})
reactor.mode = "output-to-separate-pipe"

-- It looks like Krastorio 2's fusion reactor, and it is therefore the size of one: fifteen tiles
-- square, against the three-by-two heat exchanger it is otherwise a copy of.
--
-- The footprint follows the art rather than the art being made to fit the footprint, and that is
-- the decision, not a side effect. K2's reactor is drawn for a 15x15 building; there is no K2
-- building shaped 3x2 to repoint to, and cropping a nine-tile reactor down to three reads as
-- exactly that. Both boxes are K2's own, so the sprite lands where it was drawn to land.
--
-- The heat exchanger below kept the vanilla 3x2 shape when this was written, and that was the
-- point: the two were the same sprite in two tints and could not be told apart on the ground. It is
-- fifteen by five on its own rendered art now (ADR 0022, ADR 0031), and the pair is told apart by
-- the drawing rather than by the size.
reactor.collision_box = { { -7.25, -7.25 }, { 7.25, 7.25 } }
reactor.selection_box = { { -7.5, -7.5 }, { 7.5, 7.5 } }
-- Derived from K2's own prototype and LGPLv3, which is why it lives in the graphics directory and
-- not here. See the note at the top of that file for what a boiler forced to change.
local reactor_graphics = require("__realistic-fusion-refreshed-assets__.graphics.krastorio-2.buildings.reactor-pictures")
reactor.pictures = reactor_graphics.pictures
-- The moving core, drawn over the still one by scripts/reactor-animation.lua while the reactor is
-- fusing. It is a script rendering and not part of the entity because a boiler cannot animate at
-- all -- neither structure nor fire will play, both measured; see the file above.
data:extend({ reactor_graphics.core_animation("rf-reactor-core") })
-- 550 C, and it is a real statement rather than boiler bookkeeping -- #46's third item, settled by
-- Truls on 2026-08-22 once #101 measured what this field does.
--
-- What it is: reactor energy is the primary coolant in all but name, and BOTH exchangers raise
-- steam to 500 C. A coolant cannot raise steam to its own temperature, so 165 was not merely
-- arbitrary, it was backwards, and 500 would have been exactly marginal. 550 leaves the approach
-- margin a real plant has.
--
-- Why it is free to move at all: #101 measured that the boiler's own conversion runs ONLY while the
-- input fluid is colder than this, and is exactly zero at or above it -- at every target from 15 to
-- 1e6 C and every draw to 50 MW. Plasma fuses six to eight orders above any of that, so a running
-- reactor converts nothing whatever this says. See docs/research/target-temperature.md.
--
-- And raising it SHRINKS the one case that is not zero. An idle plasma parks at min_temperature_c,
-- below this, where the rate is energy_consumption / (heat_capacity * dT): a bigger delta costs more
-- joules per unit, so going 165 -> 550 takes the unaccounted output from 6.7 W to 1.9 W.
--
-- NOT RAISED FURTHER, and not by oversight. Pushing this higher would shrink that further still, and
-- was rejected: above about 5000 C no number is a coolant temperature any more, and the point of
-- this one is that it means something. The floor was left alone for the same reason in reverse --
-- see min_temperature_c in scripts/reactor-logic.lua.
reactor.target_temperature = 550
-- 1 W, and the tooltip's "Max consumption: 1 W" is a consequence of it rather than a bug -- see
-- heating_note above, and localised_description below, which is where the player is told so.
reactor.energy_consumption = "1W"
reactor.localised_description = heating_note(logic.reactor, "entity-description.rf-reactor")
reactor.energy_source = {
  type = "electric",
  usage_priority = "secondary-input",
  -- Confinement heating is spent straight out of this buffer by control.lua rather than declared
  -- as a fixed consumption, so a brownout shows up as a plasma that cannot hold its temperature
  -- rather than as a machine the engine switches off.
  --
  -- BUFFER AND LIMIT NOW MEAN DIFFERENT THINGS, and #72 is what separated them.
  --
  -- buffer_capacity is STATED RESERVE and nothing else: a few seconds of it so one slow tick does
  -- not read as a brownout. It used to set a ceiling on control.lua's UPDATE_INTERVAL, because a
  -- step spent the whole interval's heating at once and 10 MJ covers 50 MW for twelve ticks.
  -- control.lua pays per tick now, so no interval has to fit in here and that coupling is gone.
  -- The value is kept, deliberately, because reserve is what it was always worth.
  --
  -- input_flow_limit is the one that is LOAD-BEARING. 60 MW against 50 MW of heating is the margin
  -- that lets the network refill the reserve after a shortfall instead of merely keeping up with
  -- it; drop it under 50 MW and the reactor can never be paid in full, which is starvation for
  -- ever and looks like a balance problem. control.lua's check_input_flow() refuses to load over
  -- that, for every reactor rather than for this one alone, so the two numbers cannot drift apart
  -- in silence.
  buffer_capacity = "10MJ",
  input_flow_limit = "60MW",
  drain = "0W",
}

local covers = table.deepcopy(reactor.fluid_box.pipe_covers)

-- Both boxes connect at the edge of the new footprint rather than the old one. Whole numbers
-- because fifteen is odd: the tile centres of a 15x15 entity sit on integers, where the 3x2 it
-- replaced had them on halves. West and east still both take plasma, which is what lets a run of
-- rf-pipe feed a row of reactors from one pool (ADR 0011), and the energy leaves north AND south.
reactor.fluid_box = {
  production_type = "input-output",
  volume = 1000,
  pipe_covers = covers,
  pipe_connections = {
    { flow_direction = "input-output", direction = defines.direction.west, position = { -7, 0 } },
    { flow_direction = "input-output", direction = defines.direction.east, position = { 7, 0 } },
  },
  -- Deliberately unfiltered (#28). It was pinned to rf-d-d-plasma while D-D was the only plasma,
  -- and a filter takes exactly one fluid -- so keeping it would have meant either setting the
  -- filter at runtime or a second reactor prototype, and ADR 0010 names one rf-reactor for both
  -- tiers. One reactor that burns whichever plasma it is plumbed to is what that list describes.
  --
  -- What the filter was guarding against is closed by containment (#26) rather than left open: this
  -- box's connections carry PLASMA_CATEGORY, so the only things that can reach it are the plasma
  -- set and rf-heater's output -- and the heater's only recipes are the plasmas themselves. A stray
  -- water pipe cannot connect, never mind fill it. Scoped the way the header of this file scopes it:
  -- true of everything a player can build, and a set that rewrites categories is #206.
  --
  -- What the filter did also do, and what replaces it: a plasma with no entry in reactor-logic's
  -- fuel table can now reach a reactor, and would sit there doing nothing while the reactor
  -- reported itself starved. control.lua's check_every_plasma_burns is the guard for that -- it
  -- refuses to load when a plasma-heating recipe makes a fluid the simulation has no row for.
  -- (check_plasma_bounds beside it is a different seam: temperature range, not fuel.)
}
-- Plasma in and plasma out of the shared pool, so both faces are plasma-safe only. The energy box
-- below is deliberately not: reactor energy is an ordinary fluid and a player plumbs it with
-- ordinary pipes.
contain(reactor.fluid_box, PLASMA_CATEGORY)
-- ENERGY SELLS NORTH AND SOUTH, ONE CONNECTION PER FACE (ADR 0031, #275). A heat exchanger bolts
-- its energy face flush onto one of these with no pipe between them, and a row chains off it
-- along the reactor's face -- which is what "no pipe carries reactor energy" (ADR 0018 item 2)
-- needs to be buildable at all. Two faces rather than one so a lit D-T reactor's eight exchangers
-- make two rows of four, sixty tiles each, instead of one row of eight at a hundred and twenty.
--
-- Not east or west: those are plasma, and freeing one would spend ADR 0011's shared pool. The
-- south socket is drawn by pipe_covers, the same as the north one has always been.
--
-- One connection per face on purpose. More inlets down a face is a throughput change -- #47
-- measured throughput as near linear in connection count -- and #227 still owns how much one
-- exchanger should drain. Deferred, not rejected (ADR 0031 item 6).
reactor.output_fluid_box = {
  production_type = "output",
  volume = 1000,
  pipe_covers = covers,
  pipe_connections = {
    { flow_direction = "output", direction = defines.direction.north, position = { 0, -7 } },
    { flow_direction = "output", direction = defines.direction.south, position = { 0, 7 } },
  },
  filter = "rf-reactor-energy",
}
-- CONTAINED, so nothing a player can build joins this box (ADR 0018 item 1, #86). An exchanger
-- bolts onto one of these two faces and the row chains off it; there is no pipe for this fluid, and
-- no tank and no wagon either.
contain(reactor.output_fluid_box, REACTOR_ENERGY_CATEGORY)

-- ---------------------------------------------------------------- heat exchanger

-- Vanilla's heat exchanger with its heat energy source replaced by a fluid one. Burning
-- rf-reactor-energy for its fuel_value is what converts the simulation's joules into steam:
-- energy_consumption sets the burn rate, and everything downstream is ordinary vanilla steam at
-- 500 C, which vanilla steam turbines already accept.
--
-- THE SHAPE IS THE ORIGINAL MOD'S, AND THE ART IS NOW THE REAL THING (ADR 0022, which reverses ADR
-- 0013's "the heat exchanger stays 3x2" for this machine and inverts its footprint-follows-art
-- ordering; #45). Truls's decision,
-- 2026-08-22: five by fifteen, butted flush along one face of the fifteen-tile reactor the way
-- Realistic Fusion Power laid it out, and Durikkan's 2.0 port still declares that footprint. The
-- shape is a look rather than a throughput argument -- #48 measured the link at 31-62x of headroom
-- and #47 found the flush contact buys nothing.
--
-- IT CANNOT COME FROM KRASTORIO 2, which has nothing at this shape. It is not that the set is all
-- square -- it has a 5x7 turbine that rf-hc-turbine already wears, a 5x3 research computer, a 3x5
-- vehicle, a 12x11 transceiver and a 22x3 logo. It is that nothing is five by fifteen or anywhere
-- near it: the pieces close in aspect are a third the size, and the large ones are close to square.
-- So the shape leaves Route B whichever way it is reached.
--
-- AND IT IS NOT TAKEN FROM THE PREDECESSOR, THOUGH THE EXACT ART EXISTS. Realistic Fusion Power's
-- graphics/entity/heat-exchanger.png is a 383x1088 sheet -- precisely this shape, needing no
-- derivation. It is also UNMARKED: no license.txt and no legal-note.txt in that directory, only in
-- graphics/particle-accelerator/. The port's root Unlicense covers it formally, but a public-domain
-- dedication disposes only of what its declarer owned, and the changelog credits YuokiTani, angel's
-- discarded thread and PreLeyZero for unmarked art without saying which files are whose. CLAUDE.md's
-- rule is to ask rather than assume, it was asked, and the answer was no.
--
-- SO IT IS ORIGINAL ART, DRAWN FOR THIS MOD (Route C), AND IT EXISTS. #108 closed on #252: the
-- machine wears the rendered set in graphics/rendered/heat-exchanger/, built from the Blender model
-- in models/heat-exchanger/ against the look note below and models/house-style.md. Its icon is
-- rendered from the same model, so the Krastorio 2 gas-power-station icon it borrowed is gone and
-- the NOTICE no longer names it. Nothing about this machine comes from Krastorio 2 or from either
-- predecessor any more.
--
-- The mockup it replaced is still in graphics/mockup/ for the four machines that have no model yet.
-- Do not swap in a Krastorio 2 building for any of them: the only two that ever fitted this
-- machine's footprint were a spaceship part and a tank, and a building that lies about what it does
-- is worse than a box that admits what it is.
--
-- Change the look by editing the note below and re-rendering (`/render-machine rf-heat-exchanger`),
-- never by editing a PNG. load-check fails if the manifest beside the sheets stops agreeing with
-- the footprint and connections this file declares (#250).
--
-- THE NOTE'S COMPASS IS THE FRAME IT WAS ACCEPTED IN. It was written when the machine stood five
-- wide by fifteen tall with its energy face WEST; ADR 0031 (#275) declares the same object fifteen
-- wide by five tall with the energy face NORTH, and the model turns with it (models/heat-exchanger/
-- build.py). So read the note's west as north, east as south, and its south end as the west end.
--
-- ONE THING IN THE NOTE FOLLOWS THE CAMERA RATHER THAN THAT MAPPING, and it is the dent. The note
-- puts it on a drum's "south flank" for a stated reason -- the camera stands south looking north,
-- so a hollow struck anywhere else hides behind the drum's own top -- and the reason is about the
-- camera, not the compass. Turning the body would carry note-south onto declared west and hide the
-- dent, so build.py strikes the flank the camera sees instead. The letter of that clause moves; its
-- reason is kept.
--
-- The prose below is the note as accepted in #252 except where a later round of Truls's changed
-- what the machine has: #275 added the short-end energy feeds and rebuilt the steam header, and
-- those sentences are his.
--
-- THE STEAM HEADER'S SHAPE WAS WRITTEN DOWN LATER, and not by him. Rings on a tube, the low
-- sagging drum-to-drum runs, the gooseneck off a cap and the landing inside a cap's ring of bolts
-- were decisions #275 took and left in build.py's comments alone. A model rebuilt from the note by
-- itself came back with three loops arching over the machine -- the exact shape build.py says it
-- was avoiding -- so those sentences are now in the note, describing the object that shipped.
--[[ look: rf-heat-exchanger   (read under models/house-style.md; accepted in #252, after #246)
A long, low hall, five wide and fifteen long, that turns reactor energy into steam. Along the
whole west face runs a closed, riveted manifold trough the full fifteen tiles, with an energy
channel let into its top under a grille: that face is what butts against the reactor, and it
should read as one continuous contact, not a socket. The manifold is the one part that has
CORRODED -- it is hot, wet and outdoors -- in patches and not evenly: rust where water has run,
a much darker brown pitting inside it, and a little verdigris. Painted access panels break its
run.

The rest of the body is an open frame of dark H-beams over a grating deck, so the internals show.
The beams are almost straight and not quite: a rolled beam bolted into a frame is out by a few
millimetres, and a grid of perfectly parallel ones reads as computer-drawn. Two bays are closed
with a painted panel and two more carry a diagonal brace, so the bays are not all the same; a
conduit runs down the east posts on clamps.

Down the centreline stand three tall vertical drums, bare metal with two rib bands and a weld
seam, each capped by a bolted flange with a ring of bolts and a pressure relief valve (a part
that could move later). The valve body is dark with a steam band, never a white body. ONE DRUM IS
DENTED, struck on its south flank between the rib bands, and the bands bend into the hollow with
it -- a straight band across a dent cancels it. At each drum's foot, clear of the drum on the
east side, a gauge cluster and a handwheel valve.

From the manifold, glowing feed lines run east under the grating to the foot of each drum. At each
short end a glowing feed runs from the socket into the manifold, so every energy connection has a
run behind it. The steam header is a corrugated hose, and the banding is rings on a tube rather
than a ripple in it: a ring about every tube-radius along the run, each standing about a quarter
of the radius proud, with bare tube showing between them -- a gap between rings is what tells a
corrugated hose from a spring. It is three runs rather than one pipe passing overhead: each end
drum sends its steam to the middle drum, and the middle drum sends the lot to the single steam
outlet at the middle of the east face. The two drum-to-drum runs stay LOW AND HANG -- a third of a
tile of rise off the cap, then a sag that falls below the caps between them -- so they read as
hoses slung between the drums and not as loops arching over the machine; the outlet run is the one
that climbs, because it has to cross the middle drum's own shoulder. Every run meets a drum by
bending down onto its cap -- the two between drums at both ends, the outlet run at its start -- so
the middle drum carries three, landing inside its ring of bolts and spread around the cap rather
than stacked on one line. Each leaves and lands vertically with half a tile of straight rise
before it turns, or the curve overshoots and the hose curls back over itself. The outlet run bends
around the drum and the frame rather than through them, and drops through an opening in the
grating. The water sockets sit low on both short ends, feeding a header along the base. The south
end is closed by a painted wall with a vent, and a control cabinet with a blue panel stands at the
south-east corner: those two are what break the symmetry.

The manifold channel and its feed lines glow with the energy accent while the machine is working,
and are DARK when it is not -- they carry the accent as emission, not as their own colour, or a
stopped machine looks lit. The drums are steam and never glow. Nothing on it moves yet.
]]
local exchanger = pin(table.deepcopy(data.raw["boiler"]["heat-exchanger"]), "rf-heat-exchanger", {
  mining_time = 0.5,
})
-- Rendered from the same model as the building, so icon and machine are the same object. This is
-- the one entity here that does NOT take pin's derived graphics/krastorio-2/entities/<name>.png,
-- and the file it used to take is deleted rather than left lying about (#252).
exchanger.icons = { { icon = rendered.icon("heat-exchanger"), icon_size = 64 } }
exchanger.energy_consumption = "40MW"
exchanger.energy_source = {
  type = "fluid",
  effectivity = 1,
  -- Burn by fuel_value rather than by temperature: reactor energy carries its joules in its
  -- amount, not in how hot it is.
  burns_fluid = true,
  -- Take only what the current output needs. Without this the exchanger drains its whole box
  -- every tick and throws away the excess.
  scale_fluid_usage = true,
  fluid_box = {
    production_type = "input",
    volume = 200,
    pipe_covers = table.deepcopy(exchanger.fluid_box.pipe_covers),
    -- THE LONG FACE BOLTS, THE SHORT ENDS CHAIN (ADR 0031, #275). North is the reactor contact:
    -- butted against a fifteen-tile reactor this face touches along its entire length, the way
    -- Realistic Fusion Power laid the pair out, and its one connection at {0, -2} lands on the
    -- reactor's south output. West and east at {-7, -1} and {7, -1} are what a row chains through
    -- -- the next exchanger's west energy tile lands on this one's east target -- so a row grows
    -- sideways along the reactor's face and the steam face stays free for the turbine hall.
    --
    -- ALL THREE ARE input-output, AND THAT IS LOAD-BEARING. Measured in #111 and recorded in
    -- docs/research/exchanger-chaining.md: one connection on this box declared plain "input" stops
    -- fuel leaving by the others, even though the boxes still join and this machine still burns
    -- what it is given. production_type stays "input" -- what the machine DOES with the fluid is
    -- unchanged; flow_direction is what decides whether a connection will join another machine's.
    --
    -- The default orientation puts the energy face north, so the machine stands SOUTH of a reactor.
    -- A row on the reactor's north face is the same machine rotated 180 degrees.
    pipe_connections = {
      { flow_direction = "input-output", direction = defines.direction.north, position = { 0, -2 } },
      { flow_direction = "input-output", direction = defines.direction.west, position = { -7, -1 } },
      { flow_direction = "input-output", direction = defines.direction.east, position = { 7, -1 } },
    },
    filter = "rf-reactor-energy",
  },
}
-- CONTAINED, and this is the box #82 existed to ask about: the field is set on a fluid box NESTED
-- INSIDE a fluid energy source, and nothing established that the engine reads it there. It does --
-- docs/research/energy-containment-probe.md. A negative would have voided ADR 0018 outright, because
-- the reactor's output categorised and this box left `default` means nothing connects at all.
contain(exchanger.energy_source.fluid_box, REACTOR_ENERGY_CATEGORY)

-- FIFTEEN WIDE BY FIVE TALL, ON RENDERED ART (#45, ADR 0022, #108; turned by ADR 0031, #275).
-- Truls's decision: this machine takes the original mod's five-by-fifteen area, which Durikkan's
-- 2.0 port still declares, with the long axis now east-west so the energy face is north. What it
-- wore before was vanilla's heat exchanger at 3x2 -- a sprite that looked finished while being the
-- wrong size -- and then a drawn mockup that admitted what it was until the model existed.
--
-- BOTH LONG FACES CARRY THE BIG FLOWS, which is what the shape is for. Reactor energy comes in along
-- the whole north face and steam leaves along the whole south one, so the machine stands between the
-- reactor and the turbine hall with a full-length contact on either side rather than a pipe stub at
-- a corner. That is the arrangement the original mod had and the reason it drew the machine this
-- shape.
--
-- EACH SHORT END READS `_ e _ w _` FROM NORTH TO SOUTH: energy at y = -1, water at y = 1. Both
-- long faces are spent, so the short ends are where a row chains, and each end has to carry an
-- energy tile at the same offset as the other or the row will not join. Water LEAVES the short-end
-- centre to make room for it -- Truls's layout (2026-09-07), not a derived one. A chained row's
-- interior water connections are consumed by the joints, so a row takes water at its two ends
-- only; probe-exchanger-chaining.ps1 measured eight machines fed that way and none starved.
exchanger.collision_box = { { -7.25, -2.25 }, { 7.25, 2.25 } }
exchanger.selection_box = { { -7.5, -2.5 }, { 7.5, 2.5 } }
exchanger.pictures = rendered.boiler("heat-exchanger", 15, 5)
-- WHAT MAKES THE GLOW APPEAR. The rendered set's -glow sheets go in `fire_glow`, which the engine
-- draws only while the boiler is burning -- and only while burning_cooldown is above 1.
--
-- Vanilla's heat exchanger already sets 20 and this copy inherits it, so the line below changes
-- nothing today. It is PINNED for the reason every other stat here is pinned: a deep copy taken
-- at this point picks up whatever a mod sorting earlier has done to the source, and a mod that
-- zeroes this field turns our glow off with no other symptom. Vanilla declares no fire and no
-- fire_glow to hold, which is why it can carry the field and never draw anything
-- (docs/research/entity-animation-2-0.md, measured on 2.0.77).
--
-- 20 ticks is a third of a second of afterglow when the reactor energy stops, which reads as a
-- machine coasting down rather than one switched off at the wall.
exchanger.burning_cooldown = 20
-- Flicker is the energy source's light intensity driving the glow's alpha. A fluid energy source
-- burning by fuel_value emits no light, so leaving this at its default false is what keeps the
-- manifold at a steady full-strength glow instead of an invisible one.
exchanger.fire_glow_flicker_enabled = false
exchanger.fluid_box.pipe_connections = {
  { flow_direction = "input-output", direction = defines.direction.west, position = { -7, 1 } },
  { flow_direction = "input-output", direction = defines.direction.east, position = { 7, 1 } },
}
exchanger.output_fluid_box.pipe_connections = {
  { flow_direction = "output", direction = defines.direction.south, position = { 0, 2 } },
}

-- ---------------------------------------------------------------- high-capacity steam pair

-- Generation that scales without a thousand buildings (#32).
--
-- The steam route's problem is arithmetic rather than design. One rf-heat-exchanger turns 40 MW of
-- reactor energy into 500 C steam, and a vanilla steam turbine drinks one unit of that a tick --
-- 5.82 MW -- so an exchanger feeds about seven turbines. An ignited D-T reactor sells on the order
-- of 320 MW, which is eight exchangers and fifty-five turbines PER REACTOR. That is not a
-- difficulty curve, it is a blueprint chore, and it is what this pair exists to remove.
--
-- Both are ten times their ordinary counterpart, which is the predecessor's factor and is kept
-- because it is a round number rather than because it was tuned. Balance is provisional.
--
-- THE ONE THING THAT MUST NOT GO WRONG HERE, and the acceptance criterion this tier is written
-- around: a generator's real output is fluid_usage_per_tick x 60 x (maximum_temperature -
-- default_temperature) x heat_capacity x effectivity, and max_power_output is a SEPARATE field. Set
-- one and not the other and the machine consumes ten times the steam for the same power, silently,
-- while every tooltip reads correctly. Vanilla's steam turbine avoids it by declaring no
-- max_power_output at all and letting the engine derive one. This declares it -- every stat that
-- affects balance is pinned here rather than inherited -- and scripts/check-hc.ps1 asserts the
-- engine agrees with the arithmetic, so the number cannot drift away from the fluid it is made of.
local hc_graphics = require("__realistic-fusion-refreshed-assets__.graphics.krastorio-2.buildings.hc-pictures")

-- Ten times rf-heat-exchanger's 40 MW. A boiler's energy_consumption is what it puts INTO the fluid,
-- so this is 400 MW of steam and there is no second figure to keep in step with it.
local hc_exchanger = pin(table.deepcopy(data.raw["boiler"]["heat-exchanger"]), "rf-hc-exchanger", {
  mining_time = 1,
})
hc_exchanger.mode = "output-to-separate-pipe"
hc_exchanger.energy_consumption = "400MW"
hc_exchanger.target_temperature = 500
-- Seven tiles square, following Krastorio 2's matter plant the way rf-reactor follows its fusion
-- reactor (ADR 0013). The size IS the message: a player looking at a steam farm has to see which
-- vessels are the big ones, and the predecessor's answer -- the ordinary exchanger tinted orange --
-- is the arrangement this repository already rejected between rf-reactor and rf-heat-exchanger.
hc_exchanger.collision_box = { { -3.25, -3.25 }, { 3.25, 3.25 } }
hc_exchanger.selection_box = { { -3.5, -3.5 }, { 3.5, 3.5 } }
hc_exchanger.pictures = hc_graphics.exchanger_pictures

local hc_covers = table.deepcopy(hc_exchanger.fluid_box.pipe_covers)

-- All three boxes are restated rather than inherited, because the footprint changed and vanilla's
-- connections are on a three-by-two building. Seven is odd, so the tile centres sit on integers and
-- the outermost either side is 3.
hc_exchanger.fluid_box = {
  production_type = "input-output",
  volume = 1000,
  pipe_covers = hc_covers,
  pipe_connections = {
    { flow_direction = "input-output", direction = defines.direction.west, position = { -3, 0 } },
    { flow_direction = "input-output", direction = defines.direction.east, position = { 3, 0 } },
  },
  filter = "water",
}
hc_exchanger.output_fluid_box = {
  production_type = "output",
  volume = 1000,
  pipe_covers = hc_covers,
  pipe_connections = {
    { flow_direction = "output", direction = defines.direction.north, position = { 0, -3 } },
  },
  filter = "steam",
}
hc_exchanger.energy_source = {
  type = "fluid",
  effectivity = 1,
  -- Burn by fuel_value rather than by temperature, the same as rf-heat-exchanger: reactor energy
  -- carries its joules in its amount, not in how hot it is.
  burns_fluid = true,
  -- Take only what the current output needs, or the exchanger drains its whole box every tick and
  -- throws away the excess.
  scale_fluid_usage = true,
  fluid_box = {
    production_type = "input",
    volume = 500,
    pipe_covers = hc_covers,
    pipe_connections = {
      { flow_direction = "input", direction = defines.direction.south, position = { 0, 3 } },
    },
    filter = "rf-reactor-energy",
  },
}
-- CONTAINED, on the declaration it already had, and that is a measurement rather than luck (#275,
-- ADR 0031). This machine's one energy connection is plain `"input"`, and exchanger-chaining.md had
-- established that such a connection stops fuel LEAVING a box -- whether it also stops fuel
-- ARRIVING through a bolt had no answer anywhere. It does not: probe-energy-containment.ps1's AC 5
-- row bolts this machine to a reactor's output and measures it drinking its full 400 MW.
-- flow_direction governs forwarding, not joining. So #276 gives it the ordinary exchanger's
-- footprint for consistency, not because containment waits on it.
contain(hc_exchanger.energy_source.fluid_box, REACTOR_ENERGY_CATEGORY)

-- Ten units of steam a tick against vanilla's one.
local hc_turbine = pin(table.deepcopy(data.raw["generator"]["steam-turbine"]), "rf-hc-turbine", {
  mining_time = 1,
})
hc_turbine.fluid_usage_per_tick = 10
hc_turbine.maximum_temperature = 500
hc_turbine.effectivity = 1
-- 10 units/tick x 60 ticks x (500 - 15) C x 0.2 kJ/C x 1 = 58.2 MW, off base 2.0.77's own steam
-- prototype rather than remembered. Declared so the number is visible next to the fluid it comes
-- from; scripts/check-hc.ps1 asserts the engine computes the same figure, which is what stops a
-- declaration and its arithmetic drifting apart.
hc_turbine.max_power_output = "58.2MW"
-- Five by seven, from Krastorio 2's advanced steam turbine -- which is what this machine is, so its
-- art is not a stand-in for anything.
hc_turbine.collision_box = { { -2.25, -3.25 }, { 2.25, 3.25 } }
hc_turbine.selection_box = { { -2.5, -3.5 }, { 2.5, 3.5 } }
hc_turbine.horizontal_animation = hc_graphics.turbine_horizontal
hc_turbine.vertical_animation = hc_graphics.turbine_vertical
-- Vanilla's smoke plumes are positioned for a three-by-five building and would hang in the air
-- beside a five-by-seven one. Dropped rather than repositioned: guessing at plume offsets is exactly
-- the kind of invented geometry the graphics notes here refuse to do.
hc_turbine.smoke = nil
-- Two hundred ticks at full draw, which is what vanilla's 200 units at one a tick also comes to --
-- so this is the same three and a bit seconds of buffer, scaled with the machine rather than left
-- at a tenth of it. Stated as the arithmetic rather than as a volume, because a box that empties
-- faster than the pipe refills it is exactly the throughput cap this ticket exists to avoid, and
-- 2000 on its own says nothing about whether that is true.
hc_turbine.fluid_box = {
  production_type = "input",
  volume = 2000,
  pipe_covers = table.deepcopy(hc_turbine.fluid_box.pipe_covers),
  pipe_connections = {
    { flow_direction = "input-output", direction = defines.direction.south, position = { 0, 3 } },
    { flow_direction = "input-output", direction = defines.direction.north, position = { 0, -3 } },
  },
  filter = "steam",
  -- Vanilla's own floor, kept: below 100 C the steam is not worth turning a turbine with.
  minimum_temperature = 100.0,
}
hc_turbine.energy_source = {
  type = "electric",
  -- Secondary, deliberately, and this is where the predecessor offered a startup setting instead.
  -- Primary output would make high-capacity turbines run before ordinary ones and leave a player's
  -- existing steam farm idling behind the new tier, which is a surprise rather than an upgrade. One
  -- behaviour, stated here, beats a setting that has to be explained.
  usage_priority = "secondary-output",
}

-- ---------------------------------------------------------------- isotope collector

-- Where the D-D by-products come out (#27). The reactors are the breeder (CONTEXT.md, ADR 0010),
-- and this is the fitting a player bolts to one to collect what it breeds.
--
-- It exists because the reactor has nowhere to put them. A boiler has exactly two fluid boxes and
-- rf-reactor spends both -- plasma in and out on the input-output box that ADR 0011's whole fluid
-- coupling rests on, reactor energy on the other. Tritium and helium-3 need a third and a fourth,
-- so they need another entity. Truls chose this over an extraction recipe on the plasma line,
-- because a recipe would breed at a fixed ratio while the reactor's actual reaction rate moves by
-- orders of magnitude with temperature -- which is the "physics implied through recipe ratios"
-- this mod exists to not be. control.lua fills these boxes from the same reaction count the energy
-- output is computed from, so a cold reactor breeds nothing and a hot one breeds in proportion.
--
-- A boiler again, for the same reason the reactor is one: it is the prototype that will hold and
-- move fluid without a recipe. Both boxes are declared "output" rather than the boiler's usual one
-- in and one out, and that is what kills the boiler machinery rather than merely starving it. With
-- no input box there is nothing for it to convert, so unlike rf-reactor -- which neuters the same
-- conversion down to a measured trickle with a 1 W energy_consumption -- there is no residual
-- conversion here at all, and no way for tritium to turn into helium-3 on its own.
--
-- Ordinary fluids, so ordinary pipes: nothing here is contained (#26). The by-products are cold
-- gases, not plasma.
local collector = pin(table.deepcopy(data.raw["boiler"]["boiler"]), "rf-isotope-collector", {
  mining_time = 0.5,
})
collector.mode = "output-to-separate-pipe"
-- Needs no power and asks for none. The collector does no work of its own -- control.lua writes
-- into it -- so an electric source would only give it a "no power" status while it went on working
-- perfectly, which is a lie told to the player every time they look at it.
collector.energy_source = { type = "void" }
collector.energy_consumption = "1W"
collector.target_temperature = 15

-- Vanilla's boiler is three by two with water in on the west and east faces and steam out of the
-- north one. Those positions are kept exactly as they are; only what the boxes carry changes. The
-- volumes are a buffer rather than storage: a reactor breeds about 0.137 units a second of each
-- by-product, so 500 is roughly an hour of production if nothing drains it, which is long enough
-- that a stalled pipe is a nuisance rather than an instant loss.
--
-- ~~about 0.6 units a second, so 500 is roughly fifteen minutes~~ was a PRE-#52 figure, taken when
-- the model carried no radiation term and a D-D reactor settled at 8.8e8 C selling 133 MW. It
-- settles at 2.42e8 C and 56.1 MW now, and the by-products came down with the reaction rate. The
-- volume is unchanged and the conclusion is unchanged; only the margin was overstated, in the
-- direction that would have made a stalled pipe look worse than it is.
local function emit(box, fluid)
  box.production_type = "output"
  box.volume = 500
  box.filter = fluid
  for _, connection in ipairs(box.pipe_connections or {}) do
    connection.flow_direction = "output"
  end
  return box
end

collector.fluid_box = emit(collector.fluid_box, "rf-tritium")
collector.output_fluid_box = emit(collector.output_fluid_box, "rf-helium-3")

-- FIVE BY FIVE, ON MOCKUP ART (#45, ADR 0022). It was vanilla's 3x2 boiler, both the wrong machine
-- and, Truls's judgement, too small for something that does work. There is no counterpart in the
-- original mod to take a size from -- the collector is ours, from #27 -- and Krastorio 2 has
-- nothing at 3x2 but a spaceship part, so this is a drawn placeholder at a size chosen rather than
-- inherited.
--
-- Square on purpose: it makes the machine its own rotation, so one sheet serves all four
-- directions and a player is not made to think about which way it faces to bolt it on.
--
-- Growing it does not change the pairing. entity-management pairs one collector to a reactor by
-- the tiles touching it, with a whole tile of margin, so a bigger collector still touches -- and a
-- reactor has at most one either way, so nothing about the economics moves.
collector.collision_box = { { -2.25, -2.25 }, { 2.25, 2.25 } }
collector.selection_box = { { -2.5, -2.5 }, { 2.5, 2.5 } }
collector.pictures = mockup.boiler("isotope-collector", 5, 5)
collector.fluid_box.pipe_connections = {
  { flow_direction = "output", direction = defines.direction.west, position = { -2, 0 } },
  { flow_direction = "output", direction = defines.direction.east, position = { 2, 0 } },
}
collector.output_fluid_box.pipe_connections = {
  { flow_direction = "output", direction = defines.direction.north, position = { 0, -2 } },
}

-- ---------------------------------------------------------------- lithium blanket

-- The second breeding route (#30, CONTEXT.md): a shell of lithium bolted to a reactor, catching
-- the neutrons the plasma cannot confine and turning them into tritium. ADR 0010 makes it the
-- later of the two routes and the one real D-T machines are designed around.
--
-- IT IS A CONTAINER, and that is the whole prototype. Everything it does happens in control.lua,
-- against scripts/reactor-logic.lua's breed().
--
-- A container because the only thing the engine has to do here is hold items: lithium is an item
-- (ADR 0010's Core set), so a blanket needs an inventory an inserter can fill, and nothing else.
-- The bred tritium leaves through the isotope collector already bolted to the same reactor rather
-- than through a pipe of the blanket's own, which is what makes a container enough.
--
-- That is a real design choice and not a shortcut, so here is the alternative it beat. Giving the
-- blanket its own tritium pipe means an entity with BOTH an item inventory and a fluid box, and
-- 2.0.77 has no prototype that is simply that: a container has no fluid box (ContainerPrototype),
-- and the types that have both -- crafting machines, burners -- come with machinery that would
-- have to be neutered. A crafting machine would need a recipe, and a recipe breeds at a fixed
-- ratio while the neutron flux moves by orders of magnitude with temperature, which is the
-- "physics implied through recipe ratios" this mod exists to not be (ADR 0005) and the same
-- argument that put the isotope collector here rather than on the plasma line. A burner would
-- need rf-lithium to carry a fuel_value, which is a Core item changed to suit Power and a lie in
-- every tooltip that shows it.
--
-- What routing through the collector costs, stated plainly because a player will meet it: a
-- blanket on a reactor with no collector does nothing at all. It does not merely vent what it
-- breeds the way the D-D by-products do -- it never runs, and keeps its lithium, because spending
-- a real item to produce nothing is a trap rather than a mechanic (control.lua's apply()). The
-- locale says so. control.lua's check_blanket_feed refuses to load if the collector ever stops
-- being able to take tritium, or if the item this eats stops existing.
local blanket = pin(table.deepcopy(data.raw["container"]["steel-chest"]), "rf-lithium-blanket", {
  mining_time = 0.5,
})
-- SLOTS, not items, and rf-lithium stacks to a hundred -- so this is ten thousand lithium, and the
-- arithmetic below has to be done in items or it is out by two orders of magnitude.
--
-- One lithium item per unit of tritium bred (reactor-logic's M.blanket), so what that buys depends
-- entirely on how hard the reactor is being fed, and the range is wide enough that no single
-- number is right. A D-T reactor on one heater eats about 1.4 items a second; one on a saturated
-- plasma line eats 17.6, measured by scripts/check-blanket.ps1. Ten thousand items is two hours of
-- the first and about nine minutes of the second -- deep enough not to be hand-fed, shallow enough
-- that it is still a supply line rather than a warehouse. Twice a vanilla steel chest, which is
-- about the right size for a fitting. Provisional like every other balance number here.
blanket.inventory_size = 100
-- FIVE BY FIVE, ON MOCKUP ART (#45, ADR 0022). It was a 1x1 steel chest, which Truls judged too small for
-- something that does work -- and it is a shell wrapped round a fifteen-tile reactor, so a single
-- tile was never the right reading of it. There is no counterpart in the original mod to take a
-- size from, the blanket being ours from #30, and Krastorio 2 has no 1x1 container at all: every
-- 1x1 building in that mod is a belt, a loader, an inserter or a remnant. So the size is chosen
-- rather than inherited, and the art is drawn rather than taken.
--
-- No connections to mark on it: lithium arrives by inserter and the tritium it breeds leaves
-- through the collector bolted to the same reactor, which is the design recorded at length above.
--
-- Growing it changes no economics. A reactor pairs with at most one blanket, by the tiles touching
-- it, so five tiles square still touches and still counts once.
blanket.collision_box = { { -2.25, -2.25 }, { 2.25, 2.25 } }
blanket.selection_box = { { -2.5, -2.5 }, { 2.5, 2.5 } }
blanket.picture = mockup.still("lithium-blanket", 5, 5)

-- ---------------------------------------------------------------- aneutronic reactor

-- The second reactor (#31, ADR 0010). Same simulation, same file, different constants -- see
-- M.aneutronic_reactor in scripts/reactor-logic.lua for what differs and why each difference is
-- there. This prototype is the parts of it the engine has to know about.
--
-- A boiler again, and for exactly the reasons rf-reactor is one: it is the prototype that will
-- hold and move fluid with no recipe, and its input box may be "input-output" so a row of them on
-- one run of rf-pipe works from a single pool at a single mixed temperature (ADR 0011). Nothing
-- about that argument is different on this tier, so nothing about the choice is.
local aneutronic = pin(table.deepcopy(data.raw["boiler"]["heat-exchanger"]), "rf-aneutronic-reactor", {
  mining_time = 4,
})
aneutronic.mode = "output-to-separate-pipe"

-- FIFTEEN TILES SQUARE, ON MOCKUP ART (ADR 0022; Truls, 2026-08-23). It was ten, following Krastorio 2's
-- antimatter reactor, which is drawn for a 10x10 building -- the last machine whose size came from
-- the art rather than from the mod. The original had both reactors at fifteen and this returns to
-- that, which also makes it the right partner for a 5x15 exchanger or converter laid along a face:
-- fifteen against fifteen touches all the way.
--
-- IT COSTS THE SIZE DIFFERENCE FROM rf-reactor, which was a real argument and is now answered a
-- different way. Two reactors a player cannot tell apart on the ground is the complaint that
-- separated rf-reactor from rf-heat-exchanger, and ten-beside-fifteen was the cheapest answer to
-- it. What separates them now is the art itself -- one is Krastorio 2's fusion reactor, the other a
-- labelled box saying ANEUTRONIC REACTOR -- and when real art replaces the box it will have to keep
-- doing that work, because the footprints no longer will.
--
-- Krastorio 2's antimatter reactor art is not merely unused here, it CANNOT be used: it is drawn
-- for ten tiles, and stretching a 10x10 sheet over a 15x15 building is the kind of guess this
-- repository does not make. graphics/krastorio-2/buildings/aneutronic-reactor-pictures.lua and its
-- PNGs stay in the tree for whoever draws the real thing, and the NOTICE says so.
aneutronic.collision_box = { { -7.25, -7.25 }, { 7.25, 7.25 } }
aneutronic.selection_box = { { -7.5, -7.5 }, { 7.5, 7.5 } }
aneutronic.pictures = mockup.boiler("aneutronic-reactor", 15, 15)
-- The moving core, drawn over the still one by scripts/reactor-animation.lua while the reactor is
-- fusing. Same arrangement as rf-reactor and for the same measured reason: a boiler cannot animate.
--
-- It has to exist even on a mockup. reactor-animation.lua records that a reactor whose
-- "<name>-core" animation is missing crashes rendering.draw_animation the first time it starts
-- fusing, on a live save -- so this is a drawn one rather than nothing.
data:extend({ mockup.core_animation("rf-aneutronic-reactor-core", "aneutronic-reactor-core", 15) })
-- LEFT AT 165 WHILE rf-reactor WENT TO 550, and the asymmetry is the decision rather than a
-- missed edit (Truls, 2026-08-22, #46). This tier has no thermal stage at all: a direct energy
-- converter decelerates charged particles against collector plates and takes current off them, and
-- rf-aneutronic-reactor-energy's own description tells the player "Not heat". 550 would assert a
-- coolant temperature the route does not have, which is the one thing ADR 0018 separates the two
-- routes to avoid saying.
--
-- Cold was considered and rejected: 15 C is the reading #46 was opened about, and the fluid would
-- have looked broken beside a description saying it is not heat. So 165 stays -- warm, claiming
-- nothing -- and a player comparing a 550 C line against a 165 C one learns the routes differ,
-- which is more than either number says alone. 165 is still under this reactor's own plasma floor,
-- so the engine converts nothing here either.
aneutronic.target_temperature = 165
-- 1 W for the reason rf-reactor's is, and the same tooltip consequence. This one draws 200 MW, so
-- the interpolated figure differs and a hand-written sentence would have been wrong here.
aneutronic.energy_consumption = "1W"
aneutronic.localised_description =
  heating_note(logic.aneutronic_reactor, "entity-description.rf-aneutronic-reactor")
aneutronic.energy_source = {
  type = "electric",
  usage_priority = "secondary-input",
  -- Four times rf-reactor's on both lines, because the confinement heating is four times as large,
  -- and both keep their meaning from there: 40 MJ is stated reserve, 240 MW is the limit that has
  -- to stay above the 200 MW this reactor actually draws. control.lua's check_input_flow() checks
  -- the second for every reactor rather than for rf-reactor alone -- so this number and
  -- heating_power_w cannot drift apart in silence. See rf-reactor's block above for why the two
  -- fields stopped meaning the same kind of thing (#72).
  buffer_capacity = "40MJ",
  input_flow_limit = "240MW",
  drain = "0W",
}

local aneutronic_covers = table.deepcopy(aneutronic.fluid_box.pipe_covers)

-- Half-tile positions where rf-reactor has whole ones, and that is arithmetic rather than a choice:
-- ten is even, so the tile centres of a 10x10 entity sit on halves where a 15x15's sit on integers.
-- The outermost tile centre either side is 4.5.
aneutronic.fluid_box = {
  production_type = "input-output",
  -- THREE THOUSAND, where rf-reactor holds one thousand, and this is the machine's whole physical
  -- difference. Density is what buys ignition -- the fusion rate goes as n^2 while the transport
  -- loss goes as n -- so a reactor that holds three times the plasma in the same confinement volume
  -- runs at three times the density and nine times the rate. reactor-logic keeps one
  -- particles_per_unit for the entire mod precisely so that this box is the lever and a fluid unit
  -- goes on meaning the same thing in every pipe.
  volume = 3000,
  pipe_covers = aneutronic_covers,
  -- The edge of the fifteen-tile footprint, on whole numbers because fifteen is odd -- the same
  -- arithmetic rf-reactor's connections use, and they were on halves at ten.
  pipe_connections = {
    { flow_direction = "input-output", direction = defines.direction.west, position = { -7, 0 } },
    { flow_direction = "input-output", direction = defines.direction.east, position = { 7, 0 } },
  },
  -- Unfiltered, like rf-reactor's and for the same reason (#28): one reactor burns whichever plasma
  -- it is plumbed to, and control.lua's check_every_plasma_burns is what guarantees every plasma a
  -- heater can make has somewhere to be burnt.
  --
  -- A consequence worth stating rather than discovering: nothing stops a player feeding D-D plasma
  -- to this reactor or D-He3 to the cheap one. Both work, both are simulated correctly, and both
  -- are usually a poor idea -- the constants are matched to the reactions in the tier. That is the
  -- same freedom the D-D and D-T tiers already share, one machine further along.
}
contain(aneutronic.fluid_box, PLASMA_CATEGORY)
-- NORTH AND SOUTH, one connection per face (ADR 0031 item 1, #87). The same addition rf-reactor
-- took in #275, and for the same reason: a converter hangs off either face, so one reactor drives
-- two stacks of them instead of one. West and east stay plasma, so ADR 0011's shared pool is
-- untouched here as well. The south socket is drawn by pipe_covers, the same as the north one.
--
-- One connection per face on purpose -- intake width is #227's and ADR 0031 item 6 defers it.
aneutronic.output_fluid_box = {
  production_type = "output",
  volume = 1000,
  pipe_covers = aneutronic_covers,
  pipe_connections = {
    { flow_direction = "output", direction = defines.direction.north, position = { 0, -7 } },
    { flow_direction = "output", direction = defines.direction.south, position = { 0, 7 } },
  },
  -- The tier's own energy fluid, which is what keeps the two conversion routes from being
  -- interchangeable. See prototypes/fluids.lua for why there are two.
  filter = "rf-aneutronic-reactor-energy",
}
-- CONTAINED under a category of ITS OWN, not the neutronic one (ADR 0018 items 1 and 3, #87). A
-- converter therefore cannot be bolted to an rf-reactor and an exchanger cannot be bolted to this
-- machine: the engine refuses the connection outright rather than joining two boxes whose filters
-- disagree and leaving a player to work out why nothing flows.
contain(aneutronic.output_fluid_box, ANEUTRONIC_ENERGY_CATEGORY)

-- ---------------------------------------------------------------- direct energy converter

-- Power without a steam loop (#31, ADR 0010's chain step 5), and the reason the aneutronic tier is
-- mechanically different rather than numerically bigger.
--
-- A GENERATOR, not a boiler, and that is the whole prototype choice: a generator burning a fluid
-- for its fuel_value produces electricity directly, with no intermediate steam and no turbine
-- behind it. Krastorio 2's gas power station is the same shape of thing and was the worked example
-- read for the field set.
--
-- What the neutronic side needs to turn a reactor into electricity is rf-heat-exchanger, a water
-- supply and a row of vanilla steam turbines. What this needs is this. That is the payoff of the
-- tier, and it is a building count rather than an efficiency: the conversion loss is already taken
-- at the reactor, where capture_efficiency stands for everything not recovered, so effectivity is
-- 1 here on purpose. A second factor would charge a player twice for one loss.
local converter = pin(table.deepcopy(data.raw["generator"]["steam-turbine"]), "rf-direct-energy-converter", {
  mining_time = 1,
})
-- Every stat pinned rather than inherited, the way the note at the top of this file requires.
converter.burns_fluid = true
-- Take only what the current output needs, so a converter running below capacity does not drain
-- its box and throw the rest away. The same field rf-heat-exchanger sets, for the same reason.
converter.scale_fluid_usage = true
-- Non-fuel fluid is not destroyed. It cannot arrive anyway -- the box below is filtered -- and a
-- prototype that would quietly eat a misrouted fluid is worse than one that refuses it.
converter.destroy_non_fuel_fluid = false
converter.effectivity = 1
-- A hundred units a second at one megajoule each. Sized against the route it replaces rather than
-- picked: rf-heat-exchanger burns 40 units a second into steam that feeds about seven vanilla
-- turbines, so one of these stands in for two and a half exchangers and seventeen turbines.
-- Provisional, like every other balance number here.
converter.fluid_usage_per_tick = 100 / 60
converter.max_power_output = "100MW"
-- Burned by fuel_value, so temperature is not the input. Stated rather than left at the steam
-- turbine's 500 because the fluid this drinks is declared up to 165 and a maximum above a fluid's
-- range is a claim about a temperature that cannot arrive.
converter.maximum_temperature = 165
converter.fluid_box = {
  production_type = "input",
  volume = 1000,
  pipe_covers = table.deepcopy(converter.fluid_box.pipe_covers),
  -- Both ends, where the steam turbine this is a copy of takes fluid in and passes it on.
  --
  -- input-output on an input box, which reads like a contradiction and is exactly what vanilla's
  -- steam turbine declares: production_type says what the machine DOES with the fluid, and
  -- flow_direction says whether a connection will join another machine's. Plain "input" was the
  -- first version and it is what makes a row of turbines impossible -- two converters laid back to
  -- back simply do not connect, so every one after the first sits dry with nothing to look at. The
  -- layout works for the whole neutronic tier and silently would not have here.
  --
  -- BOTH LONG FACES, at ±2 -- the outermost tile centres across the 5-tall axis. One butts the
  -- reactor along its whole length, which is what the 15x5 shape is for; the other passes fluid to
  -- the next converter in the stack, which is the chaining the comment above records as easy to lose.
  -- They were on the short ends and that put one tile against the reactor.
  --
  -- NORTH AND SOUTH SINCE ADR 0031 ITEM 4 (#87), where they were west and east. The machine is
  -- declared fifteen wide by five tall now, so the long faces are the horizontal ones: a converter
  -- placed unrotated below a reactor bolts on immediately, the way an exchanger does since #275.
  -- No connection is added or removed -- this is the same machine relabelled.
  pipe_connections = {
    { flow_direction = "input-output", direction = defines.direction.north, position = { 0, -2 } },
    { flow_direction = "input-output", direction = defines.direction.south, position = { 0, 2 } },
  },
  filter = "rf-aneutronic-reactor-energy",
}
-- CONTAINED under the aneutronic category, so this machine drinks from an aneutronic reactor and
-- from another converter and from nothing else (ADR 0018 items 1 and 3, #87).
--
-- The energy that used to be buffered here is not buffered anywhere now, and that is measured
-- rather than hoped: #85 ran a heater-fed reactor into a chained row of these with no tank in it
-- for an hour and got a smooth 485 MW with no stall and no cycle, every box in the row sitting at 0
-- or 1 unit of the 1000 it can hold. scale_fluid_usage is what makes that work; see the composite
-- tank below and docs/research/converter-buffering.md.
contain(converter.fluid_box, ANEUTRONIC_ENERGY_CATEGORY)
converter.energy_source = {
  type = "electric",
  usage_priority = "secondary-output",
}

-- FIFTEEN WIDE BY FIVE TALL, ON MOCKUP ART (#45, ADR 0022; turned by ADR 0031 item 4, #87). The
-- original mod's five-by-fifteen area for this machine, which Durikkan's 2.0 port still declares,
-- and the same area its heat exchanger takes -- the two are a pair in that layout, one per route.
-- It was vanilla's 3x5 steam turbine, which is the machine this tier exists to REMOVE: a direct
-- energy converter decelerates charged particles against collector plates and never raises steam at
-- all (ADR 0018), so wearing a turbine was the plainest lie in the mod.
--
-- THE LONG AXIS IS EAST-WEST NOW, so the energy faces are north and south and a converter placed
-- unrotated under a reactor bolts on. It was declared five wide by fifteen tall, which meant
-- check-aneutronic.ps1 had to rotate one to make a face meet the reactor at all.
--
-- Both connections sit on the long faces, so a stack of these joins face to face and grows OUTWARD
-- from the reactor -- where an exchanger chains through its short ends and grows sideways along the
-- reactor's face. Two rules rather than one, and deliberate: an exchanger spends both long faces on
-- energy in and steam out, and a converter has neither to spend. Truls, 2026-09-07: "the exchanger
-- and the converter are different beasts, exchanger needs its array of turbines, while the converter
-- needs nothing more."
converter.collision_box = { { -7.25, -2.25 }, { 7.25, 2.25 } }
converter.selection_box = { { -7.5, -2.5 }, { 7.5, 2.5 } }
-- FIFTEEN WIDE GOES IN `vertical_animation`, AND GETTING IT ROUND THE OTHER WAY LOADS CLEAN.
-- mockup.generator returns .vertical and .horizontal and the engine picks by direction, so the
-- sheet drawn for direction north has to be the one at the north footprint. Swap them and every
-- gate here still passes while the machine draws sideways.
local converter_art = mockup.generator("direct-energy-converter", 15, 5)
converter.vertical_animation = converter_art.vertical
converter.horizontal_animation = converter_art.horizontal

-- ---------------------------------------------------------------- aneutronic composite tank

-- Somewhere to put the tier's fluids (#31). A vanilla storage tank with a bigger vessel.
--
-- It earns its place on this tier rather than being storage for its own sake. Both aneutronic
-- reactions ignite, and an ignited reactor's output follows its fuel line rather than a set rate --
-- so the tier's flows arrive in bursts as heaters catch up and fall behind, against a converter
-- that drinks at a fixed hundred units a second. ~~A buffer between them is what turns that into a
-- steady hundred megawatts instead of a converter that stalls and restarts.~~
--
-- THAT LAST SENTENCE IS MEASURED FALSE, and it is left standing struck through because it is the
-- argument ADR 0018 item 5 took this role away over. #85 built a heater-fed aneutronic reactor
-- driving a chained row of converters with no tank anywhere, ran it for half an hour and again for
-- an hour, and got a smooth 485 MW with no stall and no cycle at either length -- while every
-- converter box in the row sat at 0 or 1 unit of the 1000 it can hold. The steadiness is
-- scale_fluid_usage doing what it says, not storage: nothing is ever buffered, so there is nothing
-- for a vessel to do. A tank on the end of that row delivered the same power and never filled.
--
-- What the tank measurably buys is ripple -- the row's single-tick band falls from 4.7% peak to peak
-- to 1.17% -- and what it does NOT buy is a short row's real failure, which is saturation rather
-- than stalling: two converters against this reactor pin at 200 MW and discard 58.8% of its output,
-- and a vessel delays that by its own volume and then stops helping. See
-- docs/research/converter-buffering.md.
--
-- This tank is a helium-3 vessel (ADR 0018 item 5), and the volume below is justified against
-- that fluid since #88.
--
-- "Composite" is what a vessel for a light gas is actually made of -- a metal liner overwrapped in
-- fibre, because helium leaks through steel joints and pressure is how you store useful amounts of
-- something that light. The tier's fluids are helium-3 and its blends.
--
-- Deliberately NOT plasma-safe, and this is the containment rule doing its job rather than an
-- omission (#26): its connections carry no plasma category, so no plasma line can join it, and a
-- player cannot tank fusion-temperature plasma at all. That is the same statement rf-pipe makes
-- about a vanilla pipe, made from the other end.
--
-- SINCE #86 AND #87 THE SAME SENTENCE CLOSES BOTH ENERGY FLUIDS, and that is what took this
-- entity's second job away. Its connections are `default`, and the two energy boxes now carry
-- categories of their own, so nothing that carries reactor energy or aneutronic reactor energy can
-- reach this vessel through plumbing -- no more than a vanilla tank or a fluid wagon can. A vanilla
-- tank held 25 GJ of it and a wagon 50 GJ, against a vanilla accumulator's 5 MJ; that was a
-- capability nobody designed, and it is gone.
--
-- Lua insertion still ignores categories, which is exactly why check-aneutronic.ps1 no longer
-- asserts this tank's energy role by calling insert_fluid on it: that assertion would have gone on
-- passing after the capability was gone, which is worse than failing.
local tank = pin(table.deepcopy(data.raw["storage-tank"]["storage-tank"]), "rf-aneutronic-composite-tank", {
  mining_time = 0.5,
})
-- Twice vanilla's. ~~A buffer rather than a warehouse: at the converter's hundred units a second it
-- is about eight minutes of supply, long enough to ride out a heater going down and short enough
-- that it is still a pipe network rather than a stockpile.~~
--
-- THAT BASIS WAS A CLAIM ABOUT A FLUID THIS VESSEL CANNOT HOLD, and #88 re-took it against the one
-- it does. ADR 0018 item 5 left the volume standing on the converter's 100 units a second of
-- rf-aneutronic-reactor-energy, which since #87 carries a category of its own and cannot enter here.
-- What enters is helium-3 and the D-He3 mix, and those move two orders of magnitude slower:
--
--   what                                              helium-3, units/s    50 000 units is
--   one rf-heater on rf-he3-he3-plasma                        2.5          5.6 hours
--   one rf-heater on rf-d-he3-plasma (the mix is 50/50)       1.25         11.1 hours
--   one shipped D-D reactor's helium-3 by-product             0.137        101 hours
--
-- The first two are the recipes: 5 units per 2 seconds at crafting_speed 1, and Core's
-- rf-d-he3-mixing blends 50 deuterium with 50 helium-3 into 100 mix. The third is the shipped
-- simulation driven to its D-D equilibrium -- 0.137 units a second at 2.42e8 C, alongside the
-- 56.1 MW that equilibrium is quoted at elsewhere.
--
-- SO THE FINDING IS THAT THE VALUE HOLDS AND ITS CHARACTER DOES NOT: 50 000 units is a warehouse by
-- the struck-through sentence's own standard, and it is kept as one on purpose. Helium-3 is the
-- scarcest fluid in the mod -- one heater on the mix eats what NINE D-D reactors breed, and one on
-- bare helium-3 what eighteen do -- so the vessel's job on this tier is to let a player accumulate a
-- trickle and burn it in bursts, which is a stockpile's job and not a buffer's. Sizing it to the old
-- eight minutes would put it at 1 200 units, a twentieth of a vanilla tank, and delete the entity's
-- reason to exist.
--
-- What the volume is therefore anchored to is the VESSEL rather than a play-time target: a metal
-- liner overwrapped in fibre holds a light gas at a pressure a welded steel tank of the same
-- footprint cannot, and twice vanilla's volume is what that buys. See the paragraph on "composite"
-- above.
--
-- THAT 9:1 SUPPLY RATIO IS A BALANCE QUESTION AND IS NOT SETTLED HERE. Whether the aneutronic tier
-- should need nine breeders per heater is a decision about the tier, not about a tank, and nothing
-- in this comment may be read as having taken it. Provisional, like every other balance number in
-- this repository.
tank.fluid_box.volume = 50000
-- In-world it is Krastorio 2's big storage tank, which is where the icon already came from, so the
-- thing in the hand and the thing on the ground are the same building (#45). It is a sprite swap and
-- nothing else: K2's is three tiles square like vanilla's, with the same four corner connections, so
-- no footprint moved and there is nothing to migrate. rf-isotope-collector and rf-lithium-blanket
-- still have the mismatch this used to have -- theirs are not swaps. See the NOTICE.
local tank_graphics = require("__realistic-fusion-refreshed-assets__.graphics.krastorio-2.buildings.composite-tank-pictures")
tank.pictures.picture = tank_graphics.picture
tank.window_bounding_box = tank_graphics.window_bounding_box
tank.water_reflection = tank_graphics.water_reflection

-- ---------------------------------------------------------------- plasma-safe fluid handling

-- Plasma must not travel through vanilla pipes (CONTEXT.md, ADR 0010). Enforcing that is #26;
-- these exist so there is something to enforce it in favour of.
--
-- These carry real art rather than a tint, so a plasma line is visibly not a water line -- which
-- is the point, since #26 is about stopping plasma reaching a vanilla pipe and a player has to be
-- able to see which is which before that rule can feel fair.
--
-- The sprites are Krastorio 2's steel pipe (LGPLv3, graphics/krastorio-2/). It is dimensionally
-- identical to the vanilla set file for file, so this repoints filenames and leaves every width,
-- height, shift, scale and frame count exactly as vanilla declares them. Nothing here guesses at
-- geometry.
local PIPE_SPRITES = {
  "pipe-corner-down-left", "pipe-corner-down-right", "pipe-corner-up-left", "pipe-corner-up-right",
  "pipe-cross", "pipe-ending-down", "pipe-ending-left", "pipe-ending-right", "pipe-ending-up",
  "pipe-horizontal-window-background", "pipe-straight-horizontal", "pipe-straight-horizontal-single",
  "pipe-straight-horizontal-window", "pipe-straight-vertical", "pipe-straight-vertical-single",
  "pipe-straight-vertical-window", "pipe-t-down", "pipe-t-left", "pipe-t-right", "pipe-t-up",
  "pipe-vertical-window-background",
}
local PIPE_TO_GROUND_SPRITES = {
  "pipe-to-ground-down", "pipe-to-ground-left", "pipe-to-ground-right", "pipe-to-ground-up",
}

-- Repoint by basename, walking the whole prototype rather than naming the fields. The pipe
-- prototype nests its sprites several layers down and the layout has changed between versions;
-- a walk keeps working when it changes again.
--
-- Only listed basenames are touched. The vanilla pipe directory also holds the fluid-flow
-- animations, the window background and both visualisation sprites, which K2 has no counterpart
-- for -- those stay pointing at __base__ deliberately, and the load-check's missing-asset
-- pre-flight is what would catch it if one were ever renamed there.
local function repoint(value, directory, names)
  local wanted = {}
  for _, n in ipairs(names) do wanted[n] = true end

  local function walk(node)
    if type(node) ~= "table" then return end
    for key, child in pairs(node) do
      if key == "filename" and type(child) == "string" then
        local base = child:match("([^/]+)%.png$")
        if base and wanted[base] then
          node[key] = directory .. base .. ".png"
        end
      else
        walk(child)
      end
    end
  end

  walk(value)
  return value
end

local GRAPHICS = "__realistic-fusion-refreshed-assets__/graphics/krastorio-2/"

local pipe = repoint(
  pin(table.deepcopy(data.raw["pipe"]["pipe"]), "rf-pipe", { mining_time = 0.1 }),
  GRAPHICS .. "pipe/", PIPE_SPRITES)
contain(pipe.fluid_box, PLASMA_CATEGORY)

local pipe_to_ground = repoint(
  pin(table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"]), "rf-pipe-to-ground", { mining_time = 0.1 }),
  GRAPHICS .. "pipe-to-ground/", PIPE_TO_GROUND_SPRITES)
-- Both of its connections, which is the point: the underground one carries the category too, so a
-- vanilla pipe-to-ground cannot tunnel into a plasma line from out of sight.
--
-- AND THIS IS THE ONE PROTOTYPE WHERE THAT WAS MEASURED TO FAIL, which is why it is also the only
-- one carrying the opt-out below. #206 dumped the seablock lane and found no-pipe-touching 1.1.28
-- rewriting BOTH of these connections; #207 ran all fourteen lanes and found no other mod doing it.
contain(pipe_to_ground.fluid_box, PLASMA_CATEGORY)

-- THE ONE PLACE THIS REPO TAKES A THIRD-PARTY MOD'S PRIVATE HOOK, and it is here because the
-- guarantee stated three lines above is false without it on one lane a player can install.
--
-- no-pipe-touching's last pass (data-final-fixes.lua:216-225) fires for a pipe-to-ground that is not
-- solved_by_npt, carries no npt_compat, and holds NO DEFAULT CATEGORY ON ANY CONNECTION -- which is
-- the shape contain() itself gives this entity, so containment is what qualifies it. The body then
-- writes the literal "pipe-to-ground" over the underground connection, discarding rf-plasma and
-- landing our tunnel in the same category as vanilla's, and appends twelve pipe names to the surface
-- one. A category is a whitelist, so both open the box.
--
-- `ignore` is the mod's own documented opt-out and it gates that guard completely, so this ONE FIELD
-- closes BOTH. The mod deletes the field afterwards (:230-232), so nothing of it survives into the
-- loaded prototype.
--
-- IT IS THE ONLY PASS THAT REACHES THIS PROTOTYPE, AND THAT TAKES TWO REASONS RATHER THAN ONE.
-- pipe-to-ground is not in the entity list at :47-68, so the entity pass never looks at it. But the
-- data.raw.pipe pass is NOT confined to pipes: it has a nested loop at :157-169 that walks
-- data.raw["pipe-to-ground"] and can write a category and solved_by_npt on an underground it matches
-- by name, stripping "-to-ground" and looking for the pipe. Ours IS that shape -- rf-pipe-to-ground
-- strips to rf-pipe, which exists. What keeps it out is the branch's own guard: it fires only if
-- rf-pipe holds a default category, and rf-pipe holds rf-plasma on all four connections. So this
-- entity is out of that pass's reach BECAUSE rf-pipe is contained, which is the same shape as the
-- breach itself -- containment deciding which branch claims us. Saying only "the other two passes
-- walk data.raw.pipe" would be true of the loop header and wrong about the loop.
--
-- WHY THIS AND NOT A data-final-fixes OF OUR OWN re-asserting the category: ours would run after
-- theirs and would work, but it is a general defence against a problem measured on one lane, and it
-- works by overriding whatever another mod did -- which is the opposite of ADR 0007's
-- coexistence-without-integration line. Truls's call on #208, 2026-09-01, to be reassessed if a
-- second mod ever does this. #209's gate is what notices, since 2026-09-02: load-check fails the
-- run rather than leaving it to whoever next reads another mod's data-final-fixes.
--
-- rf-pipe deliberately does NOT get this field. It needs no protection -- the pass that rewrites
-- data.raw.pipe entries is guarded on their holding a default category, and rf-pipe holds none -- and
-- setting it there would stop the mod collecting our prototype's bare NAME, which is half of a
-- finding #195 declined to suppress on the same day.
pipe_to_ground.npt_compat = { ignore = true }

-- The plasma set needs a pump of its own for the same reason it needs pipes of its own: a vanilla
-- pump is a vanilla pipe connection, so with containment in place it cannot join a plasma line at
-- all, and without this there would be no way to lift plasma over a distance or to force its
-- direction.
local pump = pin(table.deepcopy(data.raw["pump"]["pump"]), "rf-pump", { mining_time = 0.2 })
-- Krastorio 2's steel pump, icon and building both (#45). It used to wear vanilla's coat, which was
-- the hole in the plasma-safe set's own argument: the set exists so a player can SEE which equipment
-- is plasma-rated, and rf-pipe and rf-pipe-to-ground already carry K2's steel line. A swap and only a
-- swap -- K2's pump is the same one-by-two as vanilla's -- so pin()'s derived icon path now resolves
-- to graphics/krastorio-2/entities/pump.png and nothing else about the prototype moves.
pump.animations = require("__realistic-fusion-refreshed-assets__.graphics.krastorio-2.buildings.pump-pictures").animations
-- A pump is the one entity that moves fluid without a pipe connection at the far end: it also loads
-- and unloads fluid wagons, which would be a way around every rule above -- rf-pump into a vanilla
-- wagon, vanilla pump out of it, plasma anywhere. It is not. FluidWagonPrototype carries a
-- connection_category of its own, and 2.0.77 says "Pumps are only allowed to connect to this fluid
-- wagon if the pump's fluid box connection and this fluid wagon share a connection category", so
-- containing the fluid box below closes the wagon route with it. The consequence is deliberate and
-- worth stating: there is no wagon that can carry plasma, and shipping one would mean a fluid wagon
-- prototype of our own. Barrelling is shut off separately, on the fluids themselves (fluids.lua).
contain(pump.fluid_box, PLASMA_CATEGORY)

data:extend({ heater, reactor, exchanger, hc_exchanger, hc_turbine, collector, blanket,
              aneutronic, converter, tank,
              pipe, pipe_to_ground, pump })

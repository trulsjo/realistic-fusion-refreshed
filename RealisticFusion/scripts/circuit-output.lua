-- What a reactor reports: two circuit signals and a status line.
--
-- Its own file per ADR 0010's layout, which names this as the whole of the v1 interface. There is
-- no custom GUI, deliberately: GUI was 929 of the redesign's ~1,736 runtime lines, and the same
-- values go out through the engine's own idiom for a fraction of that.
--
-- Per reactor rather than per network, which is what ADR 0011 buys. A network has no position, no
-- tooltip and no circuit connection point; an aggregate would misdescribe the building the player
-- is looking at.
--
-- THE SPLIT
--
-- Everything deciding WHAT to report is pure arithmetic on a step result, and only publish()
-- touches the game. That is not tidiness: the int32 ceiling below is an error thrown in a player's
-- face when it is wrong, and the split is what lets tests/test-circuit-output.lua assert it
-- outside Factorio. Nothing above publish() may touch game, storage, defines or prototypes.
--
-- WHY A COMBINATOR AND NOT THE REACTOR
--
-- rf-reactor is a boiler, because boilers are what give it plasma-in / energy-out through separate
-- pipes. BoilerPrototype has no circuit_connector and no circuit_wire_max_distance -- checked
-- against the 2.0.77 prototype docs, not remembered -- so the reactor itself cannot carry a wire at
-- all. A companion entity is the only route, and rf-reactor-signals is that companion: a constant
-- combinator sitting at the reactor's own position, created on demand and destroyed with it.

local M = {}

-- Every runtime string this file shows a player. Public so the tests can assert the keys exist
-- rather than retyping them, and so the locale file has one place to be checked against.
M.LOCALE_PREFIX = "rf-reactor-status."

-- A circuit signal is an int32 and Factorio does not wrap: writing 3e9 to a slot throws "Given min
-- value (3e+09) is too big, allowed values are from -2147483648 to 2147483647". Probed against
-- 2.0.77 rather than assumed, because the difference between wrapping and throwing is the
-- difference between a wrong reading and a crash in front of a player.
--
-- rf-d-d-plasma tops out at 2e9 C, so the shipped range fits with about 7% to spare. A later tier
-- raising max_temperature past this starts losing the top of its range, which is why the test
-- asserts the headroom rather than trusting this comment.
local INT32_MAX = 2147483647
local INT32_MIN = -2147483648

--- Round to the nearest integer and clamp into int32.
local function to_signal(value)
  if value ~= value then return 0 end          -- NaN: report nothing rather than throw
  if value >= INT32_MAX then return INT32_MAX end
  if value <= INT32_MIN then return INT32_MIN end
  return math.floor(value + 0.5)
end

--- The two values a reactor puts on the wire.
--
-- @param result  what reactor-logic.step returned
-- @return { temperature = int32, q = int32 }
--
-- Temperature goes out in whole degrees: it is the only scale that both fits int32 across the
-- fluid's whole range and reads naturally on a combinator.
--
-- Q is dimensionless and fractional, and a signal is an integer, so it goes out as a percentage.
-- That is not just to avoid truncating to 2: it makes "Q > 100" the decider condition for "is this
-- reactor net positive", which is the question worth wiring.
function M.signals(result)
  return {
    temperature = to_signal(result and result.temperature_c or 0),
    q           = to_signal((result and result.q_factor or 0) * 100),
  }
end

--- Which of the three states a reactor is in.
--
-- @param result         what reactor-logic.step returned, or nil when it had nothing to simulate
-- @param plasma_amount  fluid units in the reactor's input box, or nil
-- @return { key = string, diode = "green"|"yellow"|"red" }
--
-- The diode is a name rather than a defines value so this function runs outside Factorio;
-- publish() maps it. Three states and no more, which is what the ticket asks for and what a player
-- can act on:
--
--   starved  nothing to work with. step() returns nil for this, so it is the absence of a result.
--   idle     holding plasma and not fusing usefully -- a cold start, or a reactor on the way down.
--   running  fusing.
--
-- The line between idle and running is fusion power against what the reactor is RATED to draw,
-- not against what it actually drew, and not the Q signal. Both of the wrong answers were tried:
--
--   "any fusion at all" -- fusion power is never exactly zero. The reactivity at 15 C is around
--   1e-70, and against 1e23 particles that is a tiny positive number rather than a zero, so a
--   stone-cold reactor reported "Fusing". The unit tests missed it because they fed status() a
--   clean 0, which never happens; a running game found it immediately.
--
--   "the Q signal is at least 1" -- which fixed that, and broke something worse.
--   reactivity.q_factor returns 0 when heating power is 0, deliberately, because a reactor that is
--   off is not infinitely efficient. So a hot reactor that loses electricity -- still fusing, still
--   filling its output pipe -- reported "Holding plasma, not fusing". That is exactly the moment a
--   player is trying to work out what went wrong, and it is the moment #37 is about.
--
-- Rated heating is the stable denominator: it does not move when the grid browns out, so the
-- threshold means the same thing in every state the reactor can be in. Half a percent of it is
-- where fusion stops being a rounding error.
--
-- The cost is that status and the Q signal can disagree in one case -- fusing with no power reads
-- "Fusing" beside a Q of 0 -- and that is the right way round. The status describes the plasma;
-- the Q describes a ratio that is genuinely undefined when the denominator is zero.
function M.status(result, plasma_amount, spec)
  if not result or not plasma_amount or plasma_amount <= 0 then
    return { key = "starved", diode = "red" }
  end
  local rated_w = spec and spec.heating_power_w or 0
  if rated_w > 0 and (result.fusion_power_w or 0) >= rated_w * 0.005 then
    return { key = "running", diode = "green" }
  end
  return { key = "idle", diode = "yellow" }
end

-- ---------------------------------------------------------------- the game half
--
-- Below this line the module touches Factorio. Above it, nothing does.

local COMBINATOR = "rf-reactor-signals"

local TEMPERATURE_SIGNAL = { type = "virtual", name = "rf-signal-plasma-temperature", quality = "normal" }
local Q_SIGNAL           = { type = "virtual", name = "rf-signal-q-factor", quality = "normal" }
-- quality is not decoration. Without it set_slot rejects the filter with "Can't specify non zero
-- request with non trivial item filter condition", because a SignalFilter that leaves quality open
-- is a condition rather than a single signal. Probed; the docs do not say so.

--- The section this reactor's signals live in, creating the combinator if it is not there yet.
--
-- Created on demand rather than wired into entity-management's build events, which keeps that file
-- about what it says it is about. The cost is one table lookup per reactor per step; the saving is
-- that a reactor that predates this code, or arrived by a route nobody enumerated, gets its
-- combinator the first time it is stepped rather than never.
local function section_for(entity)
  storage.reactor_signals = storage.reactor_signals or {}
  local combinator = storage.reactor_signals[entity.unit_number]

  if not (combinator and combinator.valid) then
    combinator = entity.surface.create_entity({
      name = COMBINATOR,
      position = entity.position,
      force = entity.force,
    })
    if not combinator then return nil end
    storage.reactor_signals[entity.unit_number] = combinator
  end

  local behavior = combinator.get_or_create_control_behavior()
  if not behavior then return nil end
  -- A fresh constant combinator already has one manual section; add_section only when it does not,
  -- so a save that has been through here does not grow a section per load.
  return behavior.sections_count > 0 and behavior.get_section(1) or behavior.add_section()
end

--- Put one reactor's state where a player can see it and wire it.
--
-- @param entity         the reactor
-- @param result         what reactor-logic.step returned, or nil
-- @param plasma_amount  fluid units in its input box, or nil
--
-- Called on the reporting cadence, not the simulation one. control.lua owns both; see the note on
-- REPORT_EVERY there for why they are different numbers.
function M.publish(entity, result, plasma_amount, spec)
  local status = M.status(result, plasma_amount, spec)
  entity.custom_status = {
    diode = defines.entity_status_diode[status.diode],
    label = { M.LOCALE_PREFIX .. status.key },
  }

  local section = section_for(entity)
  if not section then return end

  local signals = M.signals(result)
  -- Assigned wholesale rather than slot by slot: it is one API call instead of two, and it drops
  -- any slot a player has added by opening the combinator, which keeps what is on the wire the
  -- reactor's own account of itself.
  section.filters = {
    { value = TEMPERATURE_SIGNAL, min = signals.temperature },
    { value = Q_SIGNAL,           min = signals.q },
  }
end

--- Drop a reactor's combinator when the reactor is gone.
--
-- Called from the same place control.lua prunes the register, so one validity check covers every
-- way a reactor can leave -- mined, destroyed, scripted away, surface deleted. A combinator left
-- behind would be invisible, unminable and still on the wire, which is the worst of all outcomes.
function M.forget(unit_number)
  local registry = storage.reactor_signals
  if not registry then return end
  local combinator = registry[unit_number]
  if combinator and combinator.valid then combinator.destroy() end
  registry[unit_number] = nil
end

-- ---------------------------------------------------------------- putting it under the cursor
--
-- The combinator is only useful if a wire can reach it, and on its own it cannot be reached at all.
--
-- Two entities share the reactor's footprint and only one can be selected. The 2.0.77 docs are
-- explicit about who wins: "the entity with the higher number is selectable before the entity with
-- the lower number", and the combinator is deliberately down at 1 so an ordinary click, a mine and
-- a deconstruct all land on the reactor. Dragging a wire is not a special case to the engine -- it
-- offers whatever is selected, the reactor has no connector, and the drag has nothing to attach to.
--
-- ADR 0012 recorded the opposite as the one claim in #25 that was reasoned rather than measured:
-- that a drag only offers connectable entities, so the combinator would win by default. Playing it
-- settled it -- no wire would attach to a reactor at all.
--
-- So the contest is left alone and the selection is moved instead, for exactly as long as the
-- player is holding a wire. Everything else about the reactor stays pointed at the reactor.
local WIRE_ITEMS = { ["red-wire"] = true, ["green-wire"] = true }

-- The reactor's prototype name, handed in by install() rather than required from
-- entity-management.lua, which owns it. Requiring that file here would register its build handlers
-- the moment this one is loaded, and this one is loaded by a test suite that runs outside Factorio.
-- One argument is cheaper than either a second literal or a second way to break the tests.
local REACTOR

--- Point a wire-holding player at the reactor's combinator instead of the reactor.
local function redirect_selection(player)
  if not (player and player.valid) then return end

  local selected = player.selected
  if not (selected and selected.valid and selected.name == REACTOR) then return end

  -- Both vanilla wires are flagged only-in-cursor, so this is the whole of "is the player about to
  -- connect something": there is no other way to be holding one.
  local stack = player.cursor_stack
  if not (stack and stack.valid_for_read and WIRE_ITEMS[stack.name]) then return end

  local registry = storage.reactor_signals
  local combinator = registry and registry[selected.unit_number]
  -- Nil for the first few ticks of a reactor's life, before its first report created one. Nothing
  -- to do about that and nothing worth doing: the next mouse movement redirects.
  if combinator and combinator.valid then player.selected = combinator end
end

--- Wire up the redirect. Called from control.lua; see below for why it is not done at load.
--
-- Both halves of "a wire and a reactor met": the cursor moved onto a reactor with a wire already in
-- hand, and a wire was picked up while a reactor was already under the cursor. Only the first is
-- obvious, and only having the second is what makes the shortcut-bar wire buttons work.
--
-- The write re-raises on_selected_entity_changed. That terminates rather than looping: the second
-- pass sees rf-reactor-signals selected, not rf-reactor, and returns on the first test.
--
-- entity-management.lua registers its own handlers at load and this file deliberately does not,
-- which is the one place the two differ. script.on_event at load would run on require, and
-- tests/test-circuit-output.lua requires this file outside Factorio -- where there is no script,
-- no defines and no game. Keeping the registration behind a call is what keeps the pure half
-- testable, which is the whole reason for the split this file is built around.
function M.install(reactor_name)
  REACTOR = reactor_name
  script.on_event(defines.events.on_selected_entity_changed, function(event)
    redirect_selection(game.get_player(event.player_index))
  end)
  script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
    redirect_selection(game.get_player(event.player_index))
  end)
end

--- Re-pair every combinator on the map with the reactor it belongs to, and destroy the rest.
--
-- forget() covers reactors that leave while this mod is watching. It cannot cover a reactor that
-- leaves while the mod is disabled: on the next load its unit_number is simply not in the register
-- any more, so nothing ever prunes it, and its combinator sits on the map forever -- invisible,
-- unminable, and still putting a dead reactor's last reading on the wire. That is a leak with no
-- way for a player to clean it up, which is why this exists.
--
-- Deliberately NOT "destroy them all and let publish() rebuild them", which was the first version
-- and is much simpler. Rebuilding loses every wire attached to them. A player who has wired their
-- reactors into a control circuit would find all of it disconnected the next time any mod in their
-- save updated -- silently, and with no way to tell what had happened. A leaked entity is a far
-- smaller harm than that, so the pairing is worked out properly instead.
--
-- Paired by position, because that is the only link there is: the combinator carries no reference
-- back, and storage may be exactly what has gone stale. That is sound because publish() puts each
-- one at its reactor's own position and nothing ever moves either.
function M.rescan(registry)
  local by_unit = {}
  local reactors = {}
  for unit_number, reactor in pairs(registry) do
    if reactor.valid then reactors[#reactors + 1] = { unit_number = unit_number, entity = reactor } end
  end

  for _, surface in pairs(game.surfaces) do
    for _, combinator in pairs(surface.find_entities_filtered({ name = COMBINATOR })) do
      local owner = nil
      for _, reactor in ipairs(reactors) do
        if reactor.entity.surface == surface
          and reactor.entity.position.x == combinator.position.x
          and reactor.entity.position.y == combinator.position.y then
          owner = reactor
          break
        end
      end

      if owner and not by_unit[owner.unit_number] then
        by_unit[owner.unit_number] = combinator
      else
        -- No reactor here any more, or a second combinator on one that already has its. Either way
        -- nothing will ever write to this one again.
        combinator.destroy()
      end
    end
  end

  storage.reactor_signals = by_unit
end

return M

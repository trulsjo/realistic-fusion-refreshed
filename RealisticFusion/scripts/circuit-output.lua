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
-- The line between idle and running is drawn at the Q signal reading at least 1, and that is a
-- deliberate choice over "any fusion at all". Fusion power is never exactly zero: the reactivity
-- at 15 C is around 1e-70, and multiplied by 1e23 particles it is a tiny positive number rather
-- than a zero. Testing it against zero therefore called a stone-cold reactor "Fusing" -- caught in
-- a running game, not in the tests, because the tests fed it a clean 0.
--
-- Tying the threshold to the emitted signal rather than to an absolute wattage means status and
-- signal can never contradict each other: a player who sees "Fusing" always sees a Q above zero
-- on the wire, and one who sees Q = 0 is never told the reactor is working. It also puts the
-- boundary somewhere defensible -- Q of 0.5%, the point at which fusion stops being a rounding
-- error against the heating being paid for.
function M.status(result, plasma_amount)
  if not result or not plasma_amount or plasma_amount <= 0 then
    return { key = "starved", diode = "red" }
  end
  if M.signals(result).q >= 1 then
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

local DIODE = {
  green  = "green",
  yellow = "yellow",
  red    = "red",
}

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
function M.publish(entity, result, plasma_amount)
  local status = M.status(result, plasma_amount)
  entity.custom_status = {
    diode = defines.entity_status_diode[DIODE[status.diode]],
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

-- The reactor simulation: one step of the plasma power balance.
--
-- Pure Lua, like scripts/reactivity.lua and for the same reason (ADR 0005): the physics is
-- isolated from the tick cadence, so throttling to a coarser cadence is a change in control.lua
-- alone and never a rewrite of this file. Nothing here touches data, game, storage, settings, or
-- any of table_size / serpent / log / localised_print, which is what lets tests/test-reactor-logic.lua
-- run it outside Factorio.
--
-- Written to Lua 5.2.1 (what Factorio 2.0.77 runs) and verified on standalone 5.4.6.
--
-- THE MODEL
--
-- A zero-dimensional power balance, which is the standard first model of a confined plasma:
--
--     dE/dt = P_heating + P_charged - E / tau
--
-- Thermal energy accumulates from external heating and from the charged fusion products that stay
-- behind, and leaks away over a confinement time. Temperature is that energy divided by the heat
-- capacity of the particles present, and the reaction rate is read from cross-section data at that
-- temperature -- so temperature is a state variable the reactor drives, not a constant it is given.
--
-- Everything that leaves the plasma is what the reactor sells: neutrons, which are not confined at
-- all, plus the transport loss into the first wall. Charged products are not counted twice -- they
-- self-heat first and leave through the loss channel afterwards.
--
-- Balance numbers live in the prototype spec passed in, not here, and are provisional.

local reactivity = require("scripts.reactivity")

local M = {}

local K_B = 1.380649e-23  -- J/K
local CELSIUS_TO_KELVIN = 273.15

-- What each plasma is made of and what it releases, keyed by the fluid the reactor is holding.
-- Adding a tier (#28, #31) is a row here plus prototypes; the code below does not change.
--
-- D-D runs two branches at roughly equal rates:
--     D + D -> T (1.01 MeV) + p (3.02 MeV)   -- 4.03 MeV, entirely charged
--     D + D -> He3 (0.82 MeV) + n (2.45 MeV) -- 3.27 MeV, of which 0.82 is charged
-- so the mean release is 3.65 MeV and the charged share is 4.85/7.30.
M.fuels = {
  ["rf-d-d-plasma"] = {
    reaction = "D-D",
    energy_per_reaction_j = 3.65e6 * 1.602176634e-19,
    charged_fraction = 4.85 / 7.30,
    -- Nuclei consumed per reaction. Two, because both sides of D-D are deuterium.
    fuel_per_reaction = 2,
  },
}

-- What the shipped rf-reactor is made of. Kept here rather than in control.lua so the tests run
-- against the same numbers the game does, and passed into step() rather than read from it so a
-- later tier can be a different reactor without a second copy of the physics.
--
-- These settle at roughly 6e8 K, Q about 1.4, and around 90 MW of thermal output against 50 MW of
-- heating. Provisional, like every other balance number in this repository.
M.reactor = {
  -- Plasma volume. ITER is about 800 m^3.
  volume_m3 = 1000,
  -- Nuclei per unit of plasma fluid. With a 1000-unit fluid box that is 1e20 m^-3 in a full
  -- reactor, which is the density a real machine runs at.
  particles_per_unit = 1e20,
  -- Confinement heating. Spent out of the reactor's electric buffer by control.lua rather than
  -- declared on the prototype: the prototype's own energy_consumption is the boiler conversion
  -- this mod does not use, and is deliberately nearly zero.
  heating_power_w = 50e6,
  -- Energy confinement time: how long the plasma holds its heat. This is the reactor's defining
  -- statistic -- it decides the temperature the heating settles at, and therefore, through the
  -- cross-section data, everything else.
  confinement_time_s = 30,
  -- What is recovered of everything leaving the plasma. Below 1 because Factorio's steam turbines
  -- lose nothing, so at 1 a reactor that never fuses would pay for its own heating forever; it
  -- also stands in for the divertor, cryoplant and magnet power that v1 does not model.
  capture_efficiency = 0.85,
  -- rf-reactor-energy's fuel_value. One unit, one megajoule.
  energy_fluid_j_per_unit = 1e6,
  -- rf-d-d-plasma's default_temperature and max_temperature.
  min_temperature_c = 15,
  max_temperature_c = 2e9,
}

--- One simulation step for one reactor.
--
-- @param spec           reactor constants -- M.reactor holds the shipped ones
-- @param fluid_name     the plasma the reactor holds, or nil when it holds nothing
-- @param amount         plasma, in fluid units
-- @param temperature_c  plasma temperature in degrees celsius, as the fluidbox reports it
-- @param available_j    electrical energy the reactor may spend this step
-- @param dt             seconds since the last step
-- @return nil when there is nothing to simulate, otherwise a table of what happened
-- Returning nil leaves the reactor untouched, which for a fluid with no entry above means the
-- reactor holds it and does nothing with it forever. That is unreachable while the prototype
-- filters its input box to one plasma; it becomes reachable the moment a later tier sets the
-- filter at runtime, and whatever does that owes the player a way to get the wrong fluid out.
function M.step(spec, fluid_name, amount, temperature_c, available_j, dt)
  local fuel = fluid_name and M.fuels[fluid_name]
  if not fuel or not amount or amount <= 0 or not dt or dt <= 0 then return nil end

  local particles = amount * spec.particles_per_unit
  local density = particles / spec.volume_m3
  local t_k = (temperature_c or 0) + CELSIUS_TO_KELVIN
  if t_k < 0 then t_k = 0 end

  -- (3/2)NkT for the ions and as much again for the electrons that come with them.
  local thermal_j = 3 * particles * K_B * t_k

  -- Reactions this step, from the interpolated reactivity. Capped at the fuel actually present:
  -- without the cap a long step at a high rate burns more deuterium than the reactor holds and
  -- the particle count goes negative.
  local reactions = reactivity.rate(fuel.reaction, t_k, density, density) * spec.volume_m3 * dt
  local burnable = particles / fuel.fuel_per_reaction
  if reactions > burnable then reactions = burnable end

  local fusion_j = reactions * fuel.energy_per_reaction_j
  local charged_j = fusion_j * fuel.charged_fraction

  local heating_j = spec.heating_power_w * dt
  if available_j and available_j < heating_j then heating_j = available_j end
  if heating_j < 0 then heating_j = 0 end

  local burnt = reactions * fuel.fuel_per_reaction
  local remaining = particles - burnt
  -- Burnt fuel leaves with its share of the thermal energy. Without this, consuming fuel would
  -- heat the remainder for free. That share is not sold either -- it leaves with the ash rather
  -- than through the wall -- which is a real gap in the accounting and a rounding error in
  -- practice: about a fifth of a percent per second at the shipped settling point.
  local kept_j = (remaining > 0) and (thermal_j * remaining / particles) or 0

  -- The term the heating has to beat. It is why temperature settles at a value instead of
  -- climbing without limit, and why a reactor that loses power cools down rather than freezing
  -- in place.
  --
  -- Taken against the plasma that is still there rather than against the plasma the step started
  -- with. The difference is nothing at the shipped burn rate and stops being nothing if a later
  -- tier burns a large fraction in one step: charging loss on burnt fuel would over-cool, and
  -- would let captured_j below sell energy the plasma never had.
  local loss_j = kept_j * dt / spec.confinement_time_s
  if loss_j > kept_j then loss_j = kept_j end

  local new_thermal_j = kept_j + heating_j + charged_j - loss_j

  local new_temperature_c = spec.min_temperature_c
  if remaining > 0 then
    new_temperature_c = new_thermal_j / (3 * remaining * K_B) - CELSIUS_TO_KELVIN
    if new_temperature_c > spec.max_temperature_c then new_temperature_c = spec.max_temperature_c end
    if new_temperature_c < spec.min_temperature_c then new_temperature_c = spec.min_temperature_c end
  end

  -- capture_efficiency is what stops a reactor that never fuses from being a free 100% electric
  -- to thermal to electric loop: Factorio's steam turbines lose nothing, so without a loss here a
  -- cold reactor would exactly pay for its own heating forever. It also stands in for everything
  -- v1 does not model -- divertor, cryoplant, magnet power.
  local captured_j = ((fusion_j - charged_j) + loss_j) * spec.capture_efficiency

  return {
    temperature_c   = new_temperature_c,
    plasma_consumed = burnt / spec.particles_per_unit,
    energy_units    = captured_j / spec.energy_fluid_j_per_unit,
    heating_used_j  = heating_j,
    fusion_power_w  = fusion_j / dt,
    q_factor        = reactivity.q_factor(fusion_j, heating_j),
  }
end

return M

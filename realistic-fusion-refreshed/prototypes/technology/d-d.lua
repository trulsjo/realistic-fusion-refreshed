-- Power's technologies may depend on Core's; the reverse never happens (ADR 0010). This one takes
-- rf-deuterium-extraction because a reactor with no deuterium is scenery.
--
-- The vanilla prerequisites are named for their ingredients rather than their flavour: every item
-- the recipes above use has to be unlockable inside this technology's own prerequisite closure,
-- or a player can research fusion and be unable to build it.
--
-- That invariant has a second half, which this technology failed on review: the chain has to be
-- usable at the far end as well as buildable at the near one. rf-heat-exchanger emits 500 C steam
-- and vanilla unlocks the only thing that drinks it -- steam-turbine -- from nuclear-power, behind
-- uranium processing. So a player could research fusion, build the whole chain, and have nowhere
-- to put the steam. The turbine is therefore unlocked here.
--
-- Two consequences, both deliberate. Unlocking a recipe a vanilla technology also unlocks is
-- harmless -- researching nuclear-power later simply unlocks it again. But it does put the turbine
-- in a player's hands before nuclear power, where an ordinary boiler can drive it; that is a
-- change to vanilla progression, small and stated rather than smuggled.
--
-- ANSWERED BY TRULS ON 2026-08-19, asked directly rather than through the issue: #36 was opened to
-- decide exactly this and offered three answers -- keep the unlock, make nuclear-power a
-- prerequisite instead, or ship an rf-turbine of our own. **The unlock stays.** The issue itself is
-- the record of record; this comment is downstream of it, not a substitute for it. Fusion is not gated behind fission -- that would be a far bigger claim about what this
-- mod is than a recipe unlock is -- and there is no rf-turbine, which would have added an entity
-- ADR 0010's Power set does not name, plus a locale entry and more placeholder art, to avoid a
-- progression shift small enough to state in a sentence. #32's rf-hc-turbine inherits the answer:
-- it is ours, and it is unlocked by rf-d-t-fusion rather than replacing this line.
--
-- What holds it in place is check_steam_sinks() in control.lua, added by #36: for every technology
-- of ours it requires SOME reachable thing that drinks the steam for electricity, not this
-- particular one. So the decision could be revisited without touching the check -- what cannot
-- happen again is the tier having no answer at all, which is the state review caught by reading.
data:extend({
  {
    type = "technology",
    name = "rf-d-d-fusion",
    icon = "__realistic-fusion-refreshed__/graphics/krastorio-2/technologies/d-d.png",
    icon_size = 256,
    prerequisites = { "rf-deuterium-extraction", "advanced-circuit", "concrete" },
    effects = {
      { type = "unlock-recipe", recipe = "rf-pipe" },
      { type = "unlock-recipe", recipe = "rf-pipe-to-ground" },
      { type = "unlock-recipe", recipe = "rf-pump" },
      { type = "unlock-recipe", recipe = "rf-heater" },
      { type = "unlock-recipe", recipe = "rf-reactor" },
      { type = "unlock-recipe", recipe = "rf-heat-exchanger" },
      { type = "unlock-recipe", recipe = "rf-d-d-plasma" },
      -- rf-isotope-collector is NOT here. #27 put it here for want of anywhere better; #28 built
      -- rf-tritium-breeding, which is the technology it belongs to, and moved it. See the note
      -- there for why waiting costs a player nothing.
      -- Vanilla's, not ours: see above. #32's rf-hc-turbine replaces it at the high-capacity tier.
      { type = "unlock-recipe", recipe = "steam-turbine" },
    },
    unit = {
      count = 500,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack",   1 },
        { "chemical-science-pack",   1 },
      },
      time = 45,
    },
  },
})

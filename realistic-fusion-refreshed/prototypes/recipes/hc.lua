-- The high-capacity steam pair (#32). Two machine recipes and no new fluid, because the tier adds
-- throughput rather than chemistry: the same reactor energy, the same steam, the same electricity.
--
-- WHERE THEY UNLOCK, and why there is no technology of its own. ADR 0010's technology list names
-- seven and none of them is a high-capacity one, so adding an eighth would extend that list --
-- which is a decision about the shape of the tree rather than a consequence of building this, and
-- belongs to Truls. They are unlocked by rf-d-t-fusion instead, which is not a fallback but the
-- moment the need appears: a D-D reactor on one heater with nothing researched sells under 60 MW
-- and one exchanger absorbs it, while an ignited D-T reactor sells on the order of 320 MW and needs
-- four exchangers and fifty-five turbines. The tier that creates the problem is the tier that hands
-- over the answer.
--
-- BOTH REACTOR FIGURES ARE ONE-HEATER READINGS. #227 moved neither of them -- #440 has since
-- re-measured the D-D one, below -- and what #227 moved was the exchanger, 40 MW to 90, so this
-- said "eight exchangers" and now says four; the turbine count is untouched because it divides the
-- reactor's output by a TURBINE's appetite and an exchanger's rating cancels out. "Comfortably"
-- left the D-D half too, and then #227 went to 90 MW and ONE machine covers an unresearched
-- one-heater D-D reactor, so the D-D half names one exchanger rather than two. Researched, the same
-- reactor outruns it (107.5 to 129.0 MW at the top of every ladder).
--
-- The 320 comes from docs/research/d-t-ignition.md's feed table at the shipped 2.5 units/s -- one
-- heater, which is what a player has. Four heaters put the D-T reactor at 996 to 1 195 MW instead
-- (#89), so neither figure means anything without its heater count. The D-D half read 86 from the
-- same table until #440 measured one heater under current physics, nothing researched: 48.9 to 58.6
-- MW, on 2026-10-01 against Factorio 2.0.77. The D-T figure was suspected high for the same reason
-- and is not: #486 measured one heater, nothing researched, at 282.1 to 338.5 MW (2026-10-02,
-- Factorio 2.0.77), so four exchangers stands and the turbines are 49 to 59 rather than exactly
-- fifty-five. Fully researched it is 321.0 to 385.2 MW -- four or five exchangers, 56 to 67
-- turbines.
--
-- If a separate technology is wanted later, moving these two effects is the whole change.
--
-- Every ingredient is reachable inside rf-d-t-fusion's own prerequisite closure -- steel, advanced
-- circuits, concrete and pipe all arrive through rf-d-d-fusion. #30 shipped a recipe that broke that
-- rule and scripts/check-hc.ps1 checks it here the way scripts/check-blanket.ps1 does there.
--
-- Balance is provisional, as everywhere. The one relationship that is not free is the ratio between
-- them: an exchanger makes 400 MW of steam and a turbine drinks 58.2 MW of it, so roughly seven
-- turbines to an exchanger.
--
-- THAT USED TO BE "exactly the ratio the ordinary pair already has, because both halves of the tier
-- are the same factor of ten", AND IT NO LONGER IS. #227 took rf-heat-exchanger to 90 MW and left
-- rf-hc-exchanger at 400, so the ordinary pair now runs about fifteen vanilla turbines to an
-- exchanger against this pair's seven. The two pairs are internally consistent and no longer
-- consistent with each other; whether 400 should follow to 900 is not #227's and is not decided.
data:extend({
  {
    type = "recipe",
    name = "rf-hc-exchanger",
    enabled = false,
    energy_required = 20,
    ingredients = {
      { type = "item", name = "steel-plate",      amount = 200 },
      { type = "item", name = "advanced-circuit", amount = 80 },
      { type = "item", name = "concrete",         amount = 100 },
      { type = "item", name = "pipe",             amount = 100 },
    },
    results = { { type = "item", name = "rf-hc-exchanger", amount = 1 } },
  },
  {
    type = "recipe",
    name = "rf-hc-turbine",
    enabled = false,
    energy_required = 15,
    ingredients = {
      { type = "item", name = "steel-plate",      amount = 150 },
      { type = "item", name = "advanced-circuit", amount = 60 },
      { type = "item", name = "concrete",         amount = 50 },
      { type = "item", name = "pipe",             amount = 50 },
    },
    results = { { type = "item", name = "rf-hc-turbine", amount = 1 } },
  },
})

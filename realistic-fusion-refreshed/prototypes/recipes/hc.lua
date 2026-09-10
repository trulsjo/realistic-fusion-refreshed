-- The high-capacity steam pair (#32). Two machine recipes and no new fluid, because the tier adds
-- throughput rather than chemistry: the same reactor energy, the same steam, the same electricity.
--
-- WHERE THEY UNLOCK, and why there is no technology of its own. ADR 0010's technology list names
-- seven and none of them is a high-capacity one, so adding an eighth would extend that list -- which
-- is a decision about the shape of the tree rather than a consequence of building this, and belongs
-- to Truls. They are unlocked by rf-d-t-fusion instead, which is not a fallback but the moment the
-- need appears: a D-D reactor sells around 86 MW and two exchangers absorb it, while an ignited D-T
-- reactor sells on the order of 320 MW and needs five exchangers and fifty-five turbines. The tier
-- that creates the problem is the tier that hands over the answer.
--
-- BOTH REACTOR FIGURES ARE ONE-HEATER READINGS, and #227 moved neither of them. It moved the
-- exchanger, 40 MW to 70, so this said "eight exchangers" and now says five; the turbine count is
-- untouched because it divides the reactor's output by a TURBINE's appetite and an exchanger's
-- rating cancels out. "Comfortably" went from the D-D half for the same reason: two 70 MW machines
-- against 86 MW is a machine and a quarter of slack rather than three quarters.
--
-- The 86 and the 320 both come from docs/research/d-t-ignition.md's feed table at the shipped
-- 2.5 units/s -- one heater, which is what a player has. Four heaters put the D-T reactor at 996 to
-- 1 195 MW instead (#89), so neither figure means anything without its heater count.
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
-- are the same factor of ten", AND IT NO LONGER IS. #227 took rf-heat-exchanger to 70 MW and left
-- rf-hc-exchanger at 400, so the ordinary pair now runs about twelve vanilla turbines to an
-- exchanger against this pair's seven. The two pairs are internally consistent and no longer
-- consistent with each other; whether 400 should follow to 700 is not #227's and is not decided.
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

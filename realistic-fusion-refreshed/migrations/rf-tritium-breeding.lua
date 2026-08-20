-- #28 moved rf-isotope-collector's unlock from rf-d-d-fusion to the new rf-tritium-breeding.
--
-- On its own that takes the recipe away from a save that already had it. Factorio resets every
-- recipe to its prototype's enabled state on a configuration change and then re-applies the effects
-- of researched technologies, so a force that researched rf-d-d-fusion and has been building
-- collectors would load to find assemblers set to a recipe they no longer have, bot requests that
-- never fill, and blueprints that will not place -- until they research a technology that did not
-- exist when they saved.
--
-- Granting the recipe rather than the technology is deliberate. Forcing rf-tritium-breeding to
-- researched would hand a player science they never paid for and would fire its effects again on
-- every later migration pass; enabling the one recipe restores exactly what the save had and
-- nothing more, and the technology stays there to be researched normally.
--
-- This runs only for saves being brought forward. A new game has no researched rf-d-d-fusion at the
-- point it first loads, so nothing here fires.
for _, force in pairs(game.forces) do
  local unlocked = force.technologies["rf-d-d-fusion"]
  local recipe = force.recipes["rf-isotope-collector"]
  if unlocked and unlocked.researched and recipe and not recipe.enabled then
    recipe.enabled = true
  end
end

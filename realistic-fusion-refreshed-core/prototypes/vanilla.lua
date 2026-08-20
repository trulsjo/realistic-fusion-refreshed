-- Taking a vanilla prototype for our own (#42).
--
-- Both modules build their machines by deep-copying a vanilla one -- the base entity is chosen for
-- its shape and its fluid box count, which is the part that decides behaviour -- and both then had
-- to undo the same four things about the copy. Power called it `pin`, Core did it inline inside
-- `from_vanilla`, and neither name said what the four lines were for. One home, here, because
-- ADR 0010's dependency runs one way: Power may require Core, so Core is where anything shared
-- has to live.
--
-- Core requires this as `require("prototypes.vanilla")`; Power as
-- `require("__realistic-fusion-refreshed-core__.prototypes.vanilla")`.

-- `icon_path` is the caller's, not derived here: the two modules keep their art in their own
-- graphics directory under their own licence, and Power names its files after the entity while
-- Core names them in the call. The shape of an icons entry is the only part that is common.
local function claim(e, icon_path)
  e.icons = { { icon = icon_path, icon_size = 64 } }
  -- Both must be set: `icons` does not replace `icon`, and a prototype carrying the copied
  -- machine's single `icon` alongside our `icons` is the vanilla art winning in some places and
  -- ours in others.
  e.icon = nil
  -- Vanilla's group would let a player fast-replace ours with the machine it was copied from --
  -- a fusion reactor swapped out for a heat exchanger by holding the wrong thing over it.
  e.fast_replaceable_group = nil
  -- And its upgrade target belongs to the vanilla upgrade path, which ours is not on. Left in
  -- place, an upgrade planner would quietly convert our machine into a vanilla one.
  e.next_upgrade = nil
  return e
end

return { claim = claim }

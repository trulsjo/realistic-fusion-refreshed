require("prototypes.categories")
require("prototypes.fluids")
require("prototypes.items")
require("prototypes.entities")
-- After entities: the signals combinator borrows rf-reactor's selection box.
require("prototypes.signals")
require("prototypes.recipes.d-d")
require("prototypes.technology.d-d")
-- After technology.d-d, which every rung of the confinement ladder hangs off (#53).
require("prototypes.technology.confinement")
-- And of the plant-efficiency ladder beside it (#96, ADR 0020). Two lines off one technology, and
-- deliberately: both are levers on the D-D tier, which is where a player first wants one.
require("prototypes.technology.efficiency")
require("prototypes.recipes.d-t")
-- Before technology.d-t, which unlocks these two (#32).
require("prototypes.recipes.hc")
require("prototypes.technology.d-t")
require("prototypes.recipes.blanket")
require("prototypes.technology.blanket")
require("prototypes.recipes.aneutronic")
require("prototypes.technology.aneutronic")

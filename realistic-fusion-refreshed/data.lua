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
require("prototypes.recipes.d-t")
-- Before technology.d-t, which unlocks these two (#32).
require("prototypes.recipes.hc")
require("prototypes.technology.d-t")
require("prototypes.recipes.blanket")
require("prototypes.technology.blanket")
require("prototypes.recipes.aneutronic")
require("prototypes.technology.aneutronic")

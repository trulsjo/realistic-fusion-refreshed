-- Icons are derived from Krastorio 2 (LGPLv3) and live in graphics/krastorio-2/ with the licence
-- and a NOTICE naming every source file and every modification. Do not move one of these out of
-- that directory: the licence travels with the directory, not with this file (legal-note.txt).
--
-- Each fluid gets a distinct icon rather than one icon in seven colours, so `tint` is gone. The
-- colours below now only drive base_color/flow_color -- what the fluid looks like *in a pipe*,
-- which the icon cannot express.
local function icon(name)
  return { { icon = "__realistic-fusion-refreshed-core__/graphics/krastorio-2/fluids/" .. name .. ".png", icon_size = 64 } }
end

local function fluid(name, colour, order)
  return {
    type = "fluid",
    name = name,
    icons = icon(name:gsub("^rf%-", "")),
    subgroup = "fluid",
    order = order,
    default_temperature = 15,
    base_color = { r = colour.r, g = colour.g, b = colour.b },
    flow_color = { r = colour.r, g = colour.g, b = colour.b },
  }
end

data:extend({
  -- Electrolysis product, and the feedstock for hydrogen sulfide.
  fluid("rf-hydrogen", { r = 0.78, g = 0.86, b = 1.00 }, "rf-a[hydrogen]"),
  -- Recirculating catalyst for the Girdler sulfide process. Never consumed by it.
  fluid("rf-hydrogen-sulfide", { r = 0.92, g = 0.84, b = 0.35 }, "rf-b[hydrogen-sulfide]"),
  -- Deuterium oxide: the intermediate between water and deuterium.
  fluid("rf-heavy-water", { r = 0.30, g = 0.52, b = 0.88 }, "rf-c[heavy-water]"),
  -- The spent stream leaving enrichment. Not "waste water" (CONTEXT.md).
  fluid("rf-depleted-water", { r = 0.46, g = 0.46, b = 0.42 }, "rf-d[depleted-water]"),
  -- What the entire power side of the mod consumes. Its icon is hydrogen's, recoloured to this
  -- cyan -- deuterium is heavy hydrogen, so the shared shape is the point (see NOTICE).
  fluid("rf-deuterium", { r = 0.40, g = 0.92, b = 1.00 }, "rf-e[deuterium]"),

  -- The two D-D by-products, and this is the module seam in one line: they are defined here and
  -- produced by Power (#27, ADR 0010). A reactor running D-D leaves a triton behind half the time
  -- and a helium-3 the other half, so the reactors are the breeder. Core owns the prototypes
  -- because the fuel chain is Core's; nothing in this module knows a reactor exists.
  --
  -- Tritium keeps hydrogen's icon in a green of its own, for the same reason deuterium does: it is
  -- another hydrogen isotope, and the shared shape is the point. Helium-3 does not -- it is a
  -- different element, so it takes a different molecule entirely and reads as one at a glance.
  fluid("rf-tritium", { r = 0.50, g = 1.00, b = 0.60 }, "rf-f[tritium]"),
  fluid("rf-helium-3", { r = 0.80, g = 0.45, b = 1.00 }, "rf-g[helium-3]"),

  -- The fuel mixes rf-gas-mixer makes, for tiers this module does not otherwise touch: D-T (#28)
  -- and D-He3 (#29). Defined now because the mixer is Core's and a machine whose products do not
  -- exist is not buildable.
  --
  -- Their icons are one lobe per component in each component's own colour -- deuterium's cyan
  -- beside tritium's green, and beside helium-3's violet. A mixture drawn as a mixture.
  fluid("rf-d-t-mix", { r = 0.46, g = 0.97, b = 0.76 }, "rf-h[d-t-mix]"),
  fluid("rf-d-he3-mix", { r = 0.64, g = 0.64, b = 1.00 }, "rf-i[d-he3-mix]"),

  -- The lithium branch. Brine is *produced* from water, never mined (CONTEXT.md): the route
  -- deliberately involves no map resource, so the mod behaves identically on an existing save and
  -- a fresh one. A new ore or fluid deposit would only generate in unexplored chunks.
  fluid("rf-brine", { r = 0.62, g = 0.66, b = 0.45 }, "rf-j[brine]"),
  fluid("rf-lithium-solution", { r = 0.85, g = 0.74, b = 0.86 }, "rf-k[lithium-solution]"),
})

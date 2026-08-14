-- Placeholder icons: the vanilla water icon, tinted per fluid.
--
-- ponytail: ships no assets at all, so ADR 0001 has nothing to govern and ADR 0010's open art
-- question stays open. Replace when the art decision is taken; until then a tint is enough to
-- tell the fluids apart in a pipe, and looking obviously provisional is a feature.
local function placeholder(tint)
  return { { icon = "__base__/graphics/icons/fluid/water.png", icon_size = 64, tint = tint } }
end

local function fluid(name, tint, order)
  return {
    type = "fluid",
    name = name,
    icons = placeholder(tint),
    subgroup = "fluid",
    order = order,
    default_temperature = 15,
    base_color = { r = tint.r, g = tint.g, b = tint.b },
    flow_color = { r = tint.r, g = tint.g, b = tint.b },
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
  -- What the entire power side of the mod consumes.
  fluid("rf-deuterium", { r = 0.40, g = 0.92, b = 1.00 }, "rf-e[deuterium]"),
})

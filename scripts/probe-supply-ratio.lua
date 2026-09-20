--[[
Prices every input that moves the fuel-chain supply ratio, and says what each one costs (#291).

A PROBE, IN THIS REPOSITORY'S SENSE. It asserts nothing and exits 0 whatever it finds -- a lever
that turns out to make the ratio worse is a result, not a failure. CLAUDE.md's paragraph on probes
is the contract: findings belong in docs/research/, and the file stays committed so the next
rebalance can be asked the same question. docs/research/supply-ratio-levers.md is where this run's
answers were written down.

  lua scripts/probe-supply-ratio.lua

WHY IT IS LUA AND NOT POWERSHELL. Twenty-two of the twenty-six probes in this directory need a
running game -- eighteen of them build a map. This one needs the simulation and nothing else, and
the simulation runs outside Factorio by design (ADR 0005): a map here would be minutes spent asking
a question reactor-logic.lua answers in seconds. CLAUDE.md states the rule this rests on -- a probe
is a shape, not a language and not a map -- and this is the first probe here to take it up.

WHAT IT MEASURES. The supply ratio per saturated reactor -- settled D-D reactors per settled D-T
reactor -- and its per-heater reading, at the same operating point tests/test-reactor-logic.lua
pins in the block headed "the fuel chain, at the settled point (#117)". CONTEXT.md defines both
readings. The code below is deliberately the same arithmetic as that block's `chain`: the control
row exists to prove it, and a rig measuring something subtly else would price every lever against
the wrong baseline.

WHAT IT DOES NOT MEASURE. Anything that needs a prototype. A lever's effect on what a heater feeds,
on whether an exchanger keeps up, or on a plant's footprint is outside what this can see -- it
reads one Lua module. scripts/check-heating.ps1 is where the prototype side of the heating ladder
is measured in a running game.

THE LEVERS ARE READ OFF THE SHIPPED SPEC, NOT RESTATED. Every sweep point below is a multiplier on
whatever reactor-logic.lua currently declares, or a rung read out of a shipped ladder. That is
#291's second acceptance criterion and it is the difference between a rig and a transcript: a
rebalance re-prices the levers by re-running this, instead of leaving it describing a model that
has moved underneath it.
]]

package.path = "tests/?.lua;realistic-fusion-refreshed/?.lua;"
  .. package.path

local L = require("scripts.reactor-logic")

-- The operating point, matched to the suite's rather than chosen here. SETTLE_S is twenty minutes
-- of game time, which is where the suite settles both ends; TICK is the step the model was tuned
-- at. A shorter horizon moves every figure below and would not be comparable to anything published.
local SETTLE_S = 1200
local TICK     = 1 / 60

local SPEC       = L.reactor
local ANEUTRONIC = L.aneutronic_reactor

-- The published control, and the only number in this file that is allowed to be a literal. It is
-- the unresearched supply ratio per saturated reactor, pinned to 1% in tests/test-reactor-logic.lua
-- and published in docs/research/d-t-ignition.md. Reproducing it is what says the rig below
-- measures the same quantity the repository publishes; see the CONTROL row at the top of the run.
local PUBLISHED_BASELINE   = 94.6969
local PUBLISHED_PER_HEATER = 9.1233
local PUBLISHED_DD_Q       = 0.3204

-- --------------------------------------------------------------------------------- the measurement

--- Both ends of the fuel chain at one spec, and at one fill of each reactor.
--
-- THE SAME ARITHMETIC AS THE SUITE'S `chain`, on purpose. Half a D-T plasma unit is tritium
-- (`fractions`), a D-D reactor leaves tritium behind as a product, and the ratio is what one
-- reactor needs over what the other breeds.
--
-- TWO FILLS RATHER THAN ONE, because under-filling is the one lever on this list that is already a
-- player's to pull (ADR 0016) and it moves the two ends separately. Both default to full, which is
-- the reference point every published figure is quoted at.
local function chain(spec, dt_fill, dd_fill, dt_spec)
  dt_spec = dt_spec or spec
  local dt_amount = dt_spec.box_volume * (dt_fill or 1)
  local dd_amount = spec.box_volume * (dd_fill or 1)
  local _, dt = L.settle(dt_spec, "rf-d-t-plasma", dt_amount, SETTLE_S, math.huge, TICK)
  local _, dd = L.settle(spec, "rf-d-d-plasma", dd_amount, SETTLE_S, math.huge, TICK)
  if not dt or not dd then return nil end

  local t_fraction = L.fuels["rf-d-t-plasma"].fractions[2]
  local needed = dt.plasma_consumed / TICK * t_fraction
  local bred   = (dd.products["rf-tritium"] or 0) / TICK
  -- A dead breeder is the interesting case rather than an error: two of the levers below
  -- extinguish the D-D tier, and a ratio of infinity is the honest report of that.
  local ratio  = bred > 0 and needed / bred or math.huge
  -- One rf-heater's worth of tritium, read off M.heater rather than written as 1.25, so a retuned
  -- recipe re-prices this column instead of silently falsifying it.
  local heater_tritium = L.heater_plasma_rate() * t_fraction
  return {
    ratio      = ratio,
    per_heater = bred > 0 and heater_tritium / bred or math.huge,
    dd_q       = dd.q_factor,
    dt_q       = dt.q_factor,
    bred       = bred,
    needed     = needed,
    dd_t_c     = dd.temperature_c,
    dt_t_c     = dt.temperature_c,
    dd_mw      = dd.energy_units / TICK * spec.energy_fluid_j_per_unit / 1e6,
    dt_mw      = dt.energy_units / TICK * dt_spec.energy_fluid_j_per_unit / 1e6,
  }
end

--- A copy of a spec with some fields replaced. The sweeps never mutate the shipped table.
local function with(spec, overrides)
  local out = {}
  for k, v in pairs(spec) do out[k] = v end
  for k, v in pairs(overrides or {}) do out[k] = v end
  return out
end

-- --------------------------------------------------------------------------------- the reporting

local function fmt_ratio(x)
  if x == math.huge then return "dead" end
  if x >= 10000 then return string.format("%.3g", x) end
  return string.format("%.2f", x)
end

local ROW = "  %-26s %10s %10s %8s  %s\n"

local function header(title)
  io.write("\n", title, "\n", string.rep("-", #title), "\n")
  io.write(string.format(ROW, "point", "ratio", "per heater", "D-D Q", "note"))
end

local function row(label, m, note)
  if not m then
    io.write(string.format(ROW, label, "no run", "-", "-", note or ""))
    return
  end
  io.write(string.format(ROW, label, fmt_ratio(m.ratio), fmt_ratio(m.per_heater),
    string.format("%.3f", m.dd_q), note or ""))
end

--- One horizontal bar per point, on a log scale, so a figure spanning four decades still reads.
--
-- A BAR AND NOT A SCATTER. The question every sweep here asks is "which way, and by how much",
-- which a bar answers in a quarter of the code an axis-and-marker plot needs. The scale is log
-- because the ratio runs from about 4 to about 10 000 across this file and a linear axis would
-- render every interesting row as the same one character.
local BAR_WIDTH = 40
local function chart(title, points, floor_value, floor_label)
  local lo, hi = math.huge, 0
  for _, p in ipairs(points) do
    if p.value ~= math.huge and p.value > 0 then
      lo = math.min(lo, p.value)
      hi = math.max(hi, p.value)
    end
  end
  if floor_value then lo = math.min(lo, floor_value); hi = math.max(hi, floor_value) end
  if hi <= 0 or lo == math.huge then return end
  -- A decade of headroom either side keeps the shortest bar visible and the longest off the margin.
  local log_lo, log_hi = math.log(lo * 0.8), math.log(hi * 1.25)
  local function cells(v)
    if v == math.huge then return BAR_WIDTH end
    return math.max(1, math.floor(BAR_WIDTH * (math.log(v) - log_lo) / (log_hi - log_lo) + 0.5))
  end

  io.write("\n", title, "\n")
  for _, p in ipairs(points) do
    local n = cells(p.value)
    local fill = p.value == math.huge and string.rep("x", BAR_WIDTH) or string.rep("#", n)
    io.write(string.format("  %-22s |%-" .. BAR_WIDTH .. "s %s%s\n",
      p.label, fill, fmt_ratio(p.value),
      -- A row whose tier has gone out reports a SHORT bar for the wrong reason: nothing is bred,
      -- nothing is burnt, and the quotient of two collapsing numbers is noise. Marked here rather
      -- than left to the table, because a chart is the thing a reader skims.
      p.dead and "   <- both tiers out; this bar is noise" or ""))
  end
  if floor_value then
    local n = cells(floor_value)
    io.write(string.format("  %-22s |%s^ %s\n", "", string.rep(" ", n - 1), floor_label))
  end
  io.write(string.format("  %-22s  log scale, %s to %s\n", "",
    fmt_ratio(lo), fmt_ratio(hi)))
end

-- --------------------------------------------------------------------------------- the control

io.write("probe-supply-ratio -- pricing the levers that move the fuel-chain supply ratio (#291)\n")
io.write("Asserts nothing. Exits 0 whatever it finds. Findings: docs/research/supply-ratio-levers.md\n")

local BASE = chain(SPEC)

header("CONTROL -- the shipped reactor, against what the repository already publishes")
row("shipped", BASE, "baseline")
do
  -- The rig's own row that must come out right. A probe cannot fail, so this cannot exit non-zero
  -- -- but a rig measuring the wrong quantity would price every lever below against the wrong
  -- baseline and read exactly like a working one. The figures it is compared against are pinned in
  -- tests/test-reactor-logic.lua, which IS a gate; this line only says the two agree.
  local function agrees(got, want) return math.abs(got - want) / want < 0.01 end
  local ok = agrees(BASE.ratio, PUBLISHED_BASELINE)
    and agrees(BASE.per_heater, PUBLISHED_PER_HEATER)
    and agrees(BASE.dd_q, PUBLISHED_DD_Q)
  io.write(string.format("\n  %s  %.4g / %.4g / Q %.4f measured against %.4g / %.4g / Q %.4f published\n",
    ok and "CONTROL REPRODUCES the published baseline."
        or "CONTROL DIFFERS -- every row below is priced against a baseline the repository does not publish.",
    BASE.ratio, BASE.per_heater, BASE.dd_q,
    PUBLISHED_BASELINE, PUBLISHED_PER_HEATER, PUBLISHED_DD_Q))
end

-- --------------------------------------------------------------------------------- lever 1

-- THE SHIPPED LEVER, and the one ADR 0038 chose. Swept past the ladder deliberately: the rungs say
-- what a player can reach, and the points above them say whether the line keeps falling or turns
-- over. It does not turn over, which is the property ADR 0038 chose it for.
header("LEVER heating_power_w -- shared by both neutronic tiers, and the shipped research ladder")
local heating_points = {}
do
  local seen = {}
  local function measure(w, label)
    if seen[w] then return end
    seen[w] = true
    local m = chain(with(SPEC, { heating_power_w = w }))
    row(label, m, string.format("%.3g MW, Q(D-D) %.3f", w / 1e6, m.dd_q))
    heating_points[#heating_points + 1] = { label = label, value = m.ratio }
  end
  measure(SPEC.heating_power_w, "shipped")
  for i, rung in ipairs(SPEC.heating_ladder) do
    measure(rung.heating_power_w, string.format("rung %d  %s", i,
      (rung.technology:gsub("^rf%-plasma%-", ""))))
  end
  -- Past the ladder, as multiples of the shipped value rather than as round megawatts, so the
  -- points move when the shipped value does.
  for _, mult in ipairs({ 2, 4, 8 }) do
    measure(SPEC.heating_power_w * mult, string.format("shipped x%d", mult))
  end
end
chart("supply ratio against confinement heating", heating_points, 15, "#294's ceiling of 15")

-- --------------------------------------------------------------------------------- lever 2

header("LEVER confinement_time_s -- shared by both neutronic tiers, and the shipped research ladder")
local tau_points = {}
do
  local seen = {}
  local function measure(s, label)
    if seen[s] then return end
    seen[s] = true
    local m = chain(with(SPEC, { confinement_time_s = s }))
    row(label, m, string.format("%.3g s, Q(D-D) %.3f", s, m.dd_q))
    tau_points[#tau_points + 1] = { label = label, value = m.ratio }
  end
  measure(SPEC.confinement_time_s, "shipped")
  for i, rung in ipairs(SPEC.confinement_ladder) do
    measure(rung.confinement_time_s, string.format("rung %d  %s", i,
      (rung.technology:gsub("^rf%-plasma%-", ""))))
  end
  for _, mult in ipairs({ 2, 3 }) do
    measure(SPEC.confinement_time_s * mult, string.format("shipped x%d", mult))
  end
end
chart("supply ratio against confinement time", tau_points, 15, "#294's ceiling of 15")

-- --------------------------------------------------------------------------------- lever 3

-- NOT A SPEC FIELD, AND THAT IS THE POINT. ADR 0016 already makes operating density a player's
-- throttle, so a D-T reactor fed what a plant can actually breed IS an under-filled reactor. The
-- ratio falls because the burner burns less, not because the breeder breeds more -- so this row
-- shrinks the plant without shortening the chain per unit of tritium, and the megawatts fall with
-- it. Read the D-T MW column before reading this as a win.
header("LEVER the D-T reactor's fill -- a player's throttle (ADR 0016), not a spec field")
do
  for _, fill in ipairs({ 1, 0.75, 0.5, 0.25 }) do
    local m = chain(SPEC, fill)
    row(string.format("D-T at %d%% supply", fill * 100), m,
      string.format("D-T sells %.0f MW", m.dt_mw))
  end
  -- THE OTHER END OF THE SAME LEVER, AND IT IS THE SURPRISE HERE: under-filling the BREEDER
  -- shortens the chain too. A leaner D-D plasma is a less dense one, bremsstrahlung goes as n^2,
  -- so it settles hotter and breeds MORE per reactor -- which is ADR 0016's density optimum,
  -- reappearing on the fuel chain instead of on the power curve. It is not free: a D-D reactor at
  -- 50% supply sells slightly less than a full one, and half a box is half the buffer a brownout
  -- has to climb back out of.
  for _, fill in ipairs({ 0.75, 0.5 }) do
    local m = chain(SPEC, 1, fill)
    row(string.format("D-D at %d%% supply", fill * 100), m,
      string.format("D-D sells %.1f MW, breeds %.4g u/s", m.dd_mw, m.bred))
  end
end

-- --------------------------------------------------------------------------------- lever 4

-- THE DENSITY LEVER, and the one prototypes/entities.lua says in as many words the fluid box is
-- for: one particles_per_unit mod-wide "precisely so that this box is the lever". So a row here is
-- not a capacity tweak with a density side effect -- density is the whole of what it does.
header("LEVER box_volume -- the density lever by design; shared by both neutronic tiers")
local box_points = {}
do
  for _, mult in ipairs({ 0.25, 0.5, 1, 2, 3, 4 }) do
    local cap = SPEC.box_volume * mult
    local m = chain(with(SPEC, { box_volume = cap }))
    local n = cap * SPEC.particles_per_unit / SPEC.volume_m3
    local label = string.format("%d units", cap)
    -- A TIER THAT HAS GONE OUT REPORTS A SMALL RATIO FOR THE WRONG REASON, which is #291's first
    -- acceptance criterion and the one thing a reader of this table must not get wrong. Both ends
    -- are tested, and both have to be out before the row is marked: the ratio is a quotient, so a
    -- bred figure collapsing on its own makes it LARGER (the 2000-unit row) and only both
    -- collapsing together makes it small and meaningless. Measured against the shipped baseline's
    -- own demand rather than against a chosen threshold in units.
    local dead = m.dd_q < 0.01 and m.needed < 0.01 * BASE.needed
    row(label, m, string.format("n %.2g m^-3, D-D at %.3g C%s", n, m.dd_t_c,
      dead and ", BOTH TIERS OUT" or ""))
    box_points[#box_points + 1] = { label = label, value = m.ratio, dead = dead }
  end
end
chart("supply ratio against the plasma fluid box", box_points, 15, "#294's ceiling of 15")

-- --------------------------------------------------------------------------------- lever 5

-- CAPACITY AND HEATING ARE ONE LEVER. A bigger box at fixed heating is a fixed power spread over
-- more particles against a radiative loss that grew as n^2, which is why the rows above collapse.
-- Holding a temperature costs n^2, so the question is what heating rule keeps up -- and linear
-- does not.
header("GRID box_volume x heating rule -- what it takes to grow the box without collapsing")
do
  for _, mult in ipairs({ 2, 3, 4 }) do
    local cap = SPEC.box_volume * mult
    local linear = chain(with(SPEC, {
      box_volume = cap, heating_power_w = SPEC.heating_power_w * mult }))
    local quad = chain(with(SPEC, {
      box_volume = cap, heating_power_w = SPEC.heating_power_w * mult * mult }))
    row(string.format("%d units, heating x%d", cap, mult), linear,
      string.format("linear, %.0f MW", SPEC.heating_power_w * mult / 1e6))
    row(string.format("%d units, heating x%d", cap, mult * mult), quad,
      string.format("quadratic, %.0f MW, Q(D-D) %.3f",
        SPEC.heating_power_w * mult * mult / 1e6, quad.dd_q))
  end
end

-- --------------------------------------------------------------------------------- the three worse

-- THE NEGATIVE RESULTS, KEPT BECAUSE THEY ARE THE FINDING. Lowering the temperature clamp is the
-- first thing anyone reaches for and it is backwards; doubling the density and shrinking the
-- plasma volume are the next two. All three are measured here rather than described, so the next
-- person does not re-derive them -- #291's third acceptance criterion.
header("THE THREE THAT MAKE IT WORSE -- measured, not asserted")
do
  -- WHY THE CLAMP BACKFIRES. max_temperature_c is a ceiling on the simulation, not a setpoint. A
  -- D-T plasma held below its natural equilibrium sits NEARER the peak of its own cross-section --
  -- D-T's <sigma v> peaks around 70 keV and the shipped plasma settles far past it -- so a clamped
  -- D-T reactor fuses FASTER and eats more tritium. The breeder is untouched. The chain gets
  -- longer.
  local clamped = chain(with(SPEC, { max_temperature_c = SPEC.max_temperature_c * 0.4 }))
  row("clamp x0.4", clamped, string.format("D-T burns %.1f u/s, was %.1f", clamped.needed, BASE.needed))

  -- WHY DOUBLING THE DENSITY BACKFIRES. Fusion goes as n^2 and so does bremsstrahlung, but the
  -- radiation leaves the plasma while only the charged fraction of the fusion stays in it. At the
  -- D-D tier's temperature the radiation wins, so a denser D-D plasma is a colder one.
  local denser = chain(with(SPEC, { particles_per_unit = SPEC.particles_per_unit * 2 }))
  row("particles_per_unit x2", denser,
    string.format("D-D Q %.3f, was %.3f", denser.dd_q, BASE.dd_q))

  -- WHY A SMALLER PLASMA VOLUME BACKFIRES, AND WHY IT IS NOT AS BAD AS THE ROW ABOVE. volume_m3 is
  -- the denominator of the density, so halving it at a fixed box doubles the density -- but at the
  -- SAME particle count, where doubling particles_per_unit doubles both. So the radiated power
  -- doubles here against an unchanged thermal store, and quadruples there against twice the store.
  -- Both are worse than shipped and the two are an order of magnitude apart, which is the
  -- difference rather than noise.
  local smaller = chain(with(SPEC, { volume_m3 = SPEC.volume_m3 * 0.5 }))
  row("volume_m3 x0.5 (both)", smaller,
    string.format("D-D Q %.3f, was %.3f", smaller.dd_q, BASE.dd_q))
end

-- --------------------------------------------------------------------------------- per tier

-- WHICH LEVERS HAVE NOWHERE TO LIVE, which is #291's sixth acceptance criterion. Both neutronic
-- tiers are ONE spec -- M.reactor -- because a reactor is its constants and rf-reactor burns
-- whichever plasma it is fed (ADR 0005). So every row above moves both ends of the chain at once,
-- and a lever meant for the BURNER alone has no field to be written in. The rows below measure
-- what such a field would be worth if it existed, which is the argument for or against adding one.
header("PER-TIER -- levers with no home, measured on the D-T end alone")
do
  local burner_only = {
    { "volume_m3 x0.5 on D-T only", { volume_m3 = SPEC.volume_m3 * 0.5 } },
    { "volume_m3 x2 on D-T only",   { volume_m3 = SPEC.volume_m3 * 2 } },
    { "clamp x0.4 on D-T only",     { max_temperature_c = SPEC.max_temperature_c * 0.4 } },
  }
  for _, entry in ipairs(burner_only) do
    local m = chain(SPEC, 1, 1, with(SPEC, entry[2]))
    row(entry[1], m, string.format("D-T burns %.1f u/s, was %.1f", m.needed, BASE.needed))
  end
  io.write("\n  None of the three rows above is expressible in the shipped model: rf-reactor has one\n")
  io.write("  spec and burns both plasmas through it. Pulling any of them means a second spec, or a\n")
  io.write("  per-fuel override on the first -- which is a decision, not a retune.\n")
end

-- --------------------------------------------------------------------------------- non-levers

header("NON-LEVERS -- measured so nobody reaches for them as a cheap win")
do
  -- RESCALING particles_per_unit AGAINST THE BOX is invariant on the per-saturated-reactor reading
  -- and cosmetic on the other. Both sides of that ratio are counted in fluid units, so scaling what
  -- a unit MEANS cancels. The per-heater reading does move -- a heater's rate is a recipe in units
  -- while breeding is computed in nuclei -- but the plant produces identically and only the numbers
  -- on the pipes change. It also contradicts the one-nuclei-per-unit decision reactor-logic states
  -- twice, so it is recorded here as a non-lever rather than left for someone to rediscover.
  for _, mult in ipairs({ 2, 4 }) do
    local m = chain(with(SPEC, {
      box_volume = SPEC.box_volume * mult,
      particles_per_unit = SPEC.particles_per_unit / mult }))
    row(string.format("box x%d, nuclei/unit /%d", mult, mult), m,
      string.format("density unchanged at %.2g m^-3",
        SPEC.box_volume * SPEC.particles_per_unit / SPEC.volume_m3))
  end

  -- PLANT EFFICIENCY MOVES MEGAWATTS AND NOT THE CHAIN. capture_efficiency reaches step() as an
  -- argument rather than as a spec field (ADR 0020 decision 5), and it scales what a reactor SELLS.
  -- Neither end of the ratio is an energy figure, so the ratio cannot move -- measured rather than
  -- argued, because "it obviously does not" is how a lever gets left out of a sweep.
  local top = SPEC.capture_ladder[#SPEC.capture_ladder].capture_efficiency
  local _, dd_hi = L.settle(SPEC, "rf-d-d-plasma", SPEC.box_volume, SETTLE_S, math.huge, TICK, top)
  local _, dd_lo = L.settle(SPEC, "rf-d-d-plasma", SPEC.box_volume, SETTLE_S, math.huge, TICK)
  io.write(string.format(ROW, "capture_efficiency, top rung", "unchanged", "unchanged",
    string.format("%.3f", dd_hi.q_factor),
    string.format("sells %.1f MW against %.1f",
      dd_hi.energy_units / TICK * SPEC.energy_fluid_j_per_unit / 1e6,
      dd_lo.energy_units / TICK * SPEC.energy_fluid_j_per_unit / 1e6)))
  io.write(string.format("  breeds %.6g u/s either way -- the ratio counts nuclei, not joules\n",
    dd_hi.products["rf-tritium"] / TICK))
end

-- --------------------------------------------------------------------------------- aneutronic

-- THE SECOND TIER'S OWN SPEC, and the reason a neutronic lever cannot reach it. M.aneutronic_reactor
-- declares its own heating power, confinement time and box, and carries no ladder of any kind --
-- ADR 0038 decision 5 leaves it where #52 put it, and whether it moves is #422. Its ratio is the
-- per-heater reading of the same quantity (#290): how many D-D reactors' helium-3 one heater on the
-- D-He3 mix costs.
header("THE ANEUTRONIC TIER -- its own spec, out of reach of every lever above")
do
  local _, dd = L.settle(SPEC, "rf-d-d-plasma", SPEC.box_volume, SETTLE_S, math.huge, TICK)
  local he3_bred = dd.products["rf-helium-3"] / TICK
  local he3_fraction = L.fuels["rf-d-he3-plasma"].fractions[2]
  local per_heater = L.heater_plasma_rate() * he3_fraction / he3_bred
  io.write(string.format(ROW, "D-He3, one heater", "n/a", string.format("%.2f", per_heater), "n/a",
    "D-D reactors, on the shipped spec"))
  io.write(string.format("  heating %.0f MW, confinement %.0f s, box %d units -- none of which any " ..
    "technology moves\n",
    ANEUTRONIC.heating_power_w / 1e6, ANEUTRONIC.confinement_time_s, ANEUTRONIC.box_volume))
end

-- --------------------------------------------------------------------------------- one axis

-- EVERY LEVER SIDE BY SIDE, which is the figure the decision was actually taken from. The sections
-- above each answer "what does this one do"; this answers "which of them is worth anything", and
-- it is the only place the three that make it WORSE appear next to the ones that help. One
-- representative point per lever: the top of a shipped ladder where there is one, and otherwise a
-- round move a reader can hold in their head.
header("EVERY LEVER ON ONE AXIS -- one representative point each")
local summary = {}
do
  local function add(label, m, note)
    row(label, m, note)
    summary[#summary + 1] = { label = label, value = m.ratio,
      dead = m.dd_q < 0.01 and m.needed < 0.01 * BASE.needed }
  end
  add("shipped, unresearched", BASE, "the entry state")
  -- The shipped corner ADR 0038 states its target in, and the only cell #294 gates.
  local topped = with(SPEC, {
    heating_power_w    = SPEC.heating_ladder[#SPEC.heating_ladder].heating_power_w,
    confinement_time_s = SPEC.confinement_ladder[#SPEC.confinement_ladder].confinement_time_s })
  add("both ladders, topped", chain(topped), "the fully-researched state -- #294 gates this one")
  add("heating ladder alone",
    chain(with(SPEC, {
      heating_power_w = SPEC.heating_ladder[#SPEC.heating_ladder].heating_power_w })),
    "top rung, entry confinement")
  add("confinement alone",
    chain(with(SPEC, {
      confinement_time_s = SPEC.confinement_ladder[#SPEC.confinement_ladder].confinement_time_s })),
    "top rung, entry heating")
  add("box halved", chain(with(SPEC, { box_volume = SPEC.box_volume * 0.5 })), "the density lever")
  add("D-T fed at half", chain(SPEC, 0.5), "a player's throttle, already shipped")
  add("D-D fed at 75%", chain(SPEC, 1, 0.75), "the same throttle, on the breeder")
  add("clamp x0.4", chain(with(SPEC, { max_temperature_c = SPEC.max_temperature_c * 0.4 })),
    "WORSE")
  add("density x2", chain(with(SPEC, { particles_per_unit = SPEC.particles_per_unit * 2 })),
    "WORSE")
  add("volume_m3 halved", chain(with(SPEC, { volume_m3 = SPEC.volume_m3 * 0.5 })), "WORSE")
end
chart("every lever, against the shipped 94.70", summary, 15, "#294's ceiling of 15")

io.write("\nDone. Nothing here was asserted; read docs/research/supply-ratio-levers.md for what it means.\n")
os.exit(0)

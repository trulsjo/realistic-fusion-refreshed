# 20. Plant efficiency is researchable, asymptotically, and only on the neutronic route

Date: 2026-08-21

## Status

Accepted. Decided by Truls, 2026-08-21, in the same session as
[ADR 0019](0019-the-blanket-sells-its-capture-heat.md) and independent of it — either could ship
without the other, and the blanket work is sequenced first.

**Extends [ADR 0010](0010-v1-module-layout-and-prototype-set.md)'s technology set** by three
technologies, recorded here rather than drifted into.

Does not disturb [ADR 0015](0015-the-d-d-tier-is-a-breeder.md): see
[Consequences](#consequences). Distinct from
[#53](https://github.com/trulsjo/realistic-fusion-refreshed/issues/53), which raises **confinement
time** — a different lever with a different ceiling.

## Context

`capture_efficiency` is 0.85 on `rf-reactor` and 0.95 on `rf-aneutronic-reactor`. It is not a fudge
factor: `reactor-logic.lua:465-469` and `:312-318` both record that it is the **only** term standing
between this mod and perpetual motion, because Factorio's steam turbines lose nothing, so at 1.0 a
reactor that never fuses sells back exactly the heating it was given and pays for itself for ever.
The aneutronic tier already runs that margin at 190 MW returned for 200 MW spent.

That reading made a research path look forbidden — any tech that recovers more of the loss is a tech
that walks `capture_efficiency` toward 1.0, and the last step of that walk is a free energy loop.

**Truls's proposal answers that objection rather than arguing with it:** approach a theoretical
maximum *asymptotically*, so the constant can never arrive at 1.0. A curve that closes a fraction of
the remaining gap at each step never closes the gap, so the guard holds structurally rather than by a
clamp someone has to maintain. The objection applied to a linear path and does not apply to this one.

What remains is the dilemma Truls raised in the same breath, and it is arithmetic rather than balance.

### The ceiling is fixed and it is small

From 0.85 the entire space available to a technology tree is `1/0.85` = **+17.6%** relative output. An
asymptote at 0.95 caps it at **+11.8%**. Split over three technologies that is under 4% each, against
vanilla mining productivity's +10% per level.

No decomposition escapes it. Splitting the constant into a fixed conversion loss plus a
tech-reducible parasitic term was tried on paper; the product still cannot exceed 1.0, so the ceiling
is unchanged. There is no headroom to find — only headroom to manufacture by lowering the start, which
is the other horn: a lower floor makes every early reactor worse.

### Lowering the floor taxes the wrong tiers

D-D after #52 sits at Q 0.32; dropping capture to 0.70 puts it near 0.26, deepening a deficit #52 is
already deepening for principled reasons. Worse, it taxes **D-T** — the first tier that is supposed to
actually pay — so the payoff tier would arrive weaker in order to fund technologies that hand the
difference back. That reads as a worse progression, not a longer one.

### Carnot is the wrong ceiling, and was nearly adopted as the right one

A derived asymptote would have been more elegant than a chosen one, and Carnot looks like the obvious
candidate. It is not applicable. `capture_efficiency` governs heat **recovery** — what fraction of the
energy leaving the plasma reaches the fluid the exchanger burns — not heat-to-work. Factorio's turbine
performs the conversion and loses nothing. Carnot bounds the engine, not the recovery, so 500 °C steam
against a 15 °C sink (62.7%) is not a bound on this constant at all, and treating it as one would have
put the ceiling *below* the value already shipped. The asymptote is therefore an engineering judgement,
which [ADR 0014](0014-realistic-means-theoretically-possible.md) permits — it needs to be
theoretically possible, not derived from a named constant.

## Decision

**`capture_efficiency` becomes researchable on the neutronic route, in three finite steps that halve
the remaining gap to a ceiling of 0.95.**

1. **Three technologies, `rf-plant-efficiency-1/2/3`**, taking the constant
   0.85 → **0.90** → **0.925** → **0.9375**. Each step closes half the distance to 0.95, so the
   asymptote is structural: halving a gap never closes it, and no clamp needs maintaining.

2. **Finite, not an infinite research.** The two are identical for the first few levels, but the total
   prize is capped at +11.8% by arithmetic, and an infinite sink is calibrated for an unbounded reward.
   A player researching level 8 for +0.02% would be right to feel cheated. Three tooltips each naming a
   concrete efficiency is also more legible than a formula, and needs no cost-escalation machinery.

3. **A chain of three off `rf-d-d-fusion`**, logistic and chemical science throughout, counts about
   400 / 800 / 1600 — in family with the neutronic branch, which is uniformly logistic + chemical at
   300 to 1500. Level 1 becomes available the moment a player has a D-D reactor, which is exactly when
   they are bleeding power and want a lever. Gating any level behind `rf-d-t-fusion` would withhold the
   line from the tier it helps most; giving level 3 production science would push a neutronic-only
   upgrade past the aneutronic gate, which reads backwards.

4. **Neutronic only. `rf-aneutronic-reactor` stays at 0.95** and gets no research. See
   [Consequences](#consequences) for what this buys.

5. **The constant moves out of the shared spec.** `step(spec, ...)` currently reads
   `capture_efficiency` from `SPECS[entity.name]`, a module-level table every reactor of that name
   shares. Research is per force, so it becomes an argument to `step()` instead — which keeps
   `reactor-logic.lua` free of anything Factorio and allocates nothing per step, with
   [#63](https://github.com/trulsjo/realistic-fusion-refreshed/issues/63) and
   [#66](https://github.com/trulsjo/realistic-fusion-refreshed/issues/66) open on per-step cost. The
   level is cached per force and invalidated on `on_research_finished`, never read from
   `entity.force.technologies` inside the step loop.

6. **The technologies are named for what the constant does, not for half of it.** The constant covers
   both recovering heat that leaves the plasma *and* the divertor, cryoplant and magnet power the model
   does not simulate. `rf-heat-recovery` would name only the first. `rf-plant-efficiency` covers both in
   plain English; the industry's own term for the concept, "balance of plant", is exactly correct and
   opaque to a player.

## Consequences

- **The free-loop guard holds at every level, and can be checked.** A cold neutronic reactor draws
  50 MW of heating and at level 3 returns 46.9 MW — still a 3.1 MW loss. The asymptote at 0.95 means
  the drain never falls below 5% of heating, whatever is researched.
- **The physical story is real and worth stating**, because a reader who takes `capture_efficiency` for
  a fudge factor will not see it: the constant stands in for divertor, cryoplant and magnet power, and
  cutting recirculating power is exactly what real fusion engineering chases — high-temperature
  superconducting magnets being the headline case.
- **`CONTEXT.md`'s claim about direct energy conversion becomes literally true.** The glossary says DEC
  is "a different route, not a better one... The gain is that the whole steam stage disappears, not that
  the conversion is markedly more efficient". Today a 10-point efficiency gap quietly contradicts that.
  With the steam route climbing to 0.9375 against the aneutronic 0.95, the gap closes to under a point
  and the only remaining benefit is the one the glossary names. Applying the line to both reactors would
  have preserved the contradiction.
- **ADR 0015 is not threatened.** The line lifts D-D by at most 11.8%, which against Q 0.32 is about
  0.36. The tier stays a **breeder tier** by a wide margin, and the line gives a player a lever to make
  a deliberately unprofitable tier more bearable — the same shape
  [ADR 0016](0016-plasma-density-is-a-player-lever.md) gave density.
- **This is not the progression's engine, and should not be grown into one.** +11.8% total is a
  respectable side upgrade. The real lever is confinement time, where τ is unbounded and improves the
  plasma rather than the bookkeeping; that is #53's job. A future proposal for a fourth level should
  read the arithmetic above first.
- **Blanket share is invariant under this line.** Both the reactor's joules and the blanket's cross the
  same constant, so raising it moves both equally and ADR 0019's signal reads the same. The two
  features do not interact, which is why they are sequenced independently.
- **Q is unaffected.** Q is fusion power over heating power, both plasma-side; capture efficiency does
  not enter it. A player will see output rise with no movement in either signal.
- **It carries runtime state the rest of the simulation does not.** A per-force cache and an
  `on_research_finished` handler are both new, and both are things a save has to survive.
- **The work is larger than the reward.** Three technologies, locale, a force cache, an event handler, a
  `step()` signature change reaching every caller and test, plus a gate. Against ADR 0019's +27% for
  less code, which is why the blanket goes first.

## Alternatives considered

**No research path at all**, on the grounds that any capture technology walks toward perpetual motion.
This was the original recommendation and the asymptote defeats it: a curve that halves the remaining
gap never reaches the ceiling, so the guard is structural.

**Lowering the starting efficiency to make room** for a wider tree. Rejected: it deepens D-D's
deliberate deficit and taxes D-T, the tier that is meant to be the payoff.

**Carnot as the derived asymptote.** Rejected on physics, not on taste — it bounds heat-to-work, and
this constant governs heat recovery. Taking it seriously would put the ceiling below the value already
shipped.

**An infinite research** in the style of mining productivity. Structurally the same asymptote, and
mismatched to a reward capped at +11.8%.

**Applying the line to the aneutronic reactor too.** Keeps a 10-point efficiency gap that the glossary
denies exists, and spends the aneutronic tier's remaining margin — 190 MW back for 200 MW spent — which
is the tightest in the design.

**Splitting the constant into a fixed conversion loss and a tech-reducible parasitic term**, hoping to
create headroom. The product still cannot exceed 1.0; the ceiling is unchanged and the bookkeeping is
worse.

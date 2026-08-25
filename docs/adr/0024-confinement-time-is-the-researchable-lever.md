# 24. Confinement time is the researchable lever, in three rungs to 60 seconds

Date: 2026-08-24

## Status

Accepted. Decided by Truls, 2026-08-24, after
[#53](https://github.com/trulsjo/realistic-fusion-refreshed/issues/53) was built — the ticket set the
direction and this settles what was left open in it: how many rungs, where they land, which reactors
they reach, and where the guard against the temperature clamp sits.

**Applies [ADR 0014](0014-realistic-means-theoretically-possible.md).** That ADR sanctioned a
confinement ladder as *the* shape a route out of a sub-break-even tier may take — "research that moves
a physical parameter … never a flat addition to output" — and left the numbers open. This one places
them. It does not extend that ADR's reasoning; it spends it.

**Extends [ADR 0010](0010-v1-module-layout-and-prototype-set.md)'s technology set** by three, the way
[ADR 0019](0019-the-blanket-sells-its-capture-heat.md) and
[ADR 0020](0020-plant-efficiency-is-researchable.md) extended it — recorded rather than drifted into.
ADR 0010's technology list carries a dated note pointing here.

**Corrects one line of [ADR 0016](0016-plasma-density-is-a-player-lever.md).** Its consequence *"#53 is
not complicated by it … nothing under-supplied can exceed it"* is false as written, and the correction
is what decides where the guard is sited. See [Consequences](#consequences).

**Sharpens [ADR 0014](0014-realistic-means-theoretically-possible.md)'s clamp estimate** from "somewhere
past 100 s" to about 175 s, measured through the shipped `step()` rather than through the equilibrium
solver.

## Context

[ADR 0015](0015-the-d-d-tier-is-a-breeder.md) put the D-D tier below break-even on purpose: Q 0.320,
a breeder whose product is fuel rather than electricity, meant to be run at a loss until a player
researches out of it. ADR 0014 had already ruled on what "researches out of it" is allowed to mean.
Nothing had decided what it actually *is*.

Three things constrained the answer before anyone chose anything.

### The lever was not open

[ADR 0005](0005-real-time-fusion-simulation.md) makes the reaction rate a reading off cross-section
data rather than a number anyone picks, so a flat `+30 MW` has nowhere in the model to live and would
be exactly the implied physics that ADR exists to prevent. ADR 0014 names the parameters that *are*
ours: confinement time, density, plasma purity. Density is already spoken for — ADR 0016 made it a
lever the **player** tunes, and a technology that moved it would be taking that back. Purity is not
modelled. Confinement time is what is left, and raising nτT is what fusion research actually is, so the
faithful implementation and the flavourful one are the same one.

That is not a choice this ADR made. It is the choice ADR 0014 and ADR 0016 had already made between
them, arrived at again from the other end.

### The range was mapped and the top of it was not free

ADR 0014's full-supply sweep gave the shape: smooth, monotonic, break-even between 50 s and 55 s, and
Q 2.08 at 70 s. It proposed "a ladder from 30 s to about 70 s". What it also recorded is that a D-D
reactor taken far enough still ends against `max_temperature_c` and inherits the pinned temperature
reading the D-T tier has ([`d-t-ignition.md`](../research/d-t-ignition.md)) — a reactor whose
thermometer has stopped meaning anything and whose further research therefore stops doing anything a
player can see. That bounds the ladder from above, and the bound is a real number rather than a
gesture: **about 175 s**, measured here.

### And ADR 0016's mechanic is on the same axis

ADR 0016 accepted that an under-supplied D-D reactor out-performs a full one — 40% more fusion power
for 35% less fuel at the shipped 30 s — and made it a mechanic on the grounds that **the ladder closes
it**: the density optimum walks up the fill axis as confinement rises and leaves the range by 70 s. So
where the ladder stops decides how much of ADR 0016's mechanic survives it. A ladder to 70 s spends it
entirely.

## Decision

**1. Three technologies, `rf-plasma-confinement-1/2/3`, taking confinement time 30 s → 40 → 50 → 60.**
Full supply, which is a load-bearing qualifier and not a pedantic one:

| τ | technology | Q at full supply | Q at the optimum | optimum fill |
|---|---|---|---|---|
| 30 s | *(shipped, unresearched)* | 0.320 | 0.450 | ~65% |
| 40 s | `rf-plasma-confinement-1` | 0.578 | 0.734 | ~75% |
| 50 s | `rf-plasma-confinement-2` | 0.950 | 1.085 | ~85% |
| 60 s | `rf-plasma-confinement-3` | **1.467** | 1.531 | ~90% |

A player who tunes density crosses break-even at rung 2; a player who runs full crosses at rung 3.
**Both are intended and both have to be said out loud**, which is ADR 0016's standing requirement on
any figure this line publishes.

**2. The top rung is 60 s, not ADR 0014's "about 70 s", and the reason is not the clamp.** 60 s is the
confinement time `rf-aneutronic-reactor` already ships with, so the line has a story rather than a
stopping point: this is the first machine being brought up to what the later one already holds. It
also leaves ADR 0016's density mechanic alive — narrowed to +4% at the top rung rather than closed —
where 70 s would end it. The clamp is nowhere near either figure and does not enter this choice.

**3. Neutronic only. `rf-aneutronic-reactor` gets no ladder**, for the reason ADR 0020 gives plant
efficiency: #52 settled that tier's balance at 60 s, and a technology named for the machine below it
must not reopen the aneutronic pair's numbers as a side effect.

**4. The rungs unlock nothing and set no engine modifier.** `control.lua` reads which of them a force
holds and hands that force's reactors a different confinement time. The technology descriptions are
what tell a player what happened.

**5. It is per force, and derived rather than stored.** Two forces on one map run the same reactor
prototype at different confinement times. The answer is computed from `force.technologies`, cached per
force index, and dropped on the five events that can change what a force holds — `on_research_finished`,
`on_research_reversed`, `on_technology_effects_reset`, `on_force_reset`, `on_forces_merged`. **Nothing
goes in `storage`, and that is the whole of the migration this needs**: Factorio rebuilds the Lua state
on every load, so a save part way through the ladder gets exactly what its research says on the first
tick after loading, and a rung renamed in a later version cannot leave a stale number behind. A
migration script would have had to migrate precisely this and could only have got it wrong.

**6. The mod refuses to load a ladder whose top rung parks a normally supplied D-D reactor against
`max_temperature_c`.** `check_confinement_ladder()` joins `check_prototypes()` as the eleventh
load-time invariant; it settles a full reactor at the top rung — about 40 ms, once, at the game's own
six-tick cadence — and refuses over the result. It also refuses if a rung names a technology no loaded
mod defines, or if a spec carries a ladder but names no fuel to guard it with.

**7. The guard is sited at full supply as the *reference operating point*, not as the hottest one.**
See the correction below; this is the half of the decision that changed under measurement.

**8. Three rungs off `rf-d-d-fusion` at 400 / 800 / 1600**, logistic and chemical science throughout,
in family with the neutronic branch's 300 to 1500. Level 1 is available the moment a player has a
reactor, which is exactly when they are bleeding power and want a lever. Gating any of it behind
`rf-d-t-fusion` would withhold the line from the tier it exists for.

**9. The descriptions quote seconds, never a Q.** The seconds are passed from the constants, so a rung
and its tooltip cannot disagree; a Q would have to be either settled at data stage — about 40 ms per
rung at every game start, for a tooltip — or copied into the locale by hand, which is the drift
[#51](https://github.com/trulsjo/realistic-fusion-refreshed/issues/51) exists because of. The break-even
claims are made in words and each names its supply, and `tests/test-reactor-logic.lua` pins the claim
each string makes.

## Consequences

### ADR 0016's guard-siting consequence is wrong, and this is the correction

That ADR records:

> **#53 is not complicated by it.** At the top of the ladder full supply is optimal, so the guard
> against the clamp is still sited at full density and nothing under-supplied can exceed it.

**Both halves fail, and the second one matters.** The first is a near miss: at 60 s the optimum is at
about 90% fill rather than at full, worth +4%. The second is a category error. Thinning a plasma raises
its settled **temperature** *monotonically*, because the same 50 MW heats fewer particles:

| fill | τ 30 s | τ 60 s |
|---|---|---|
| 100% | 2.42×10⁸ | 6.48×10⁸ |
| 75% | 4.14×10⁸ | 1.01×10⁹ |
| 50% | 7.12×10⁸ | 1.50×10⁹ |
| 25% | 1.46×10⁹ | **2×10⁹ — the clamp** |
| 10% | **2×10⁹ — the clamp** | **2×10⁹ — the clamp** |

A reactor held at a tenth of a box is against the clamp **today, at the shipped 30 s, with nothing
researched**. So a guard over every fill would have failed on the day it was written and could never
have been made to pass.

> **The clamp in this table is 2×10⁹, and it moved to 5×10⁹ on 2026-08-25**
> ([#58](https://github.com/trulsjo/realistic-fusion-refreshed/issues/58),
> [ADR 0025](0025-a-plasma-temperature-ships-in-kilodegrees.md)). The reasoning above is unaffected —
> a thin plasma still rises without bound and still reaches whatever clamp exists, which is why the
> guard is still sited at full supply. What changed is the cells: at 30 s a tenth-full reactor now
> settles at 3.55×10⁹ rather than against the clamp, and at 60 s it is against the new one at
> 5×10⁹. The 25% cell at 60 s comes off the clamp entirely, to 2.76×10⁹.
>
> This is also the passage that caught #58 overclaiming: that ticket's work asserted "D-D is
> unchanged" from a full-fill measurement, which this table had already shown could not be true of
> every fill.

What ADR 0016 actually established is that the optimum in **Q** walks up the fill axis and leaves the
range by 70 s. That is correct, and it is a different curve: Q is fusion power over heating power and
has an interior maximum; temperature has none. The two were conflated, here and in #53's own comment,
and the conflation reached as far as a first draft of the guard.

**What follows for the guard**: full supply is the machine every published figure describes and the one
a player builds, so that is what the ladder is not allowed to pin. Running thin far enough to pin your
own thermometer stays a player's choice under ADR 0016 and is not a defect in the ladder.

### The rest

- **ADR 0016's mechanic closes without shutting.** Tuning density is worth +40% at 30 s, +27% at 40,
  +14% at 50 and +4% at 60. A player who never tunes is not left behind by the end of this line, and
  one who does is still slightly ahead — which is a better landing than either extreme, and it is the
  landing choosing 60 s over 70 s bought.
- **D-T is untouched, to the joule.** It is pinned at the clamp at every rung and at none of them, so
  the ladder moves neither its temperature nor its output. Nothing downstream of the D-T tier moves
  *because of the reactor*.
- **But the fuel chain between the tiers moves a long way.** D-D's by-products go from 0.137 to
  0.627 u/s across the ladder — **4.6×** — so a researched player needs far fewer D-D reactors to feed
  one D-T reactor. [`d-t-ignition.md`](../research/d-t-ignition.md)'s "about 1.4 D-D reactors feed one
  D-T reactor" is therefore now research-dependent as well as **already stale from #52**, whose own
  blast-radius list called for re-anchoring it and which re-anchored the equilibrium table above it and
  not the arithmetic below. Recorded there and opened as
  [#117](https://github.com/trulsjo/realistic-fusion-refreshed/issues/117) rather than re-picked here:
  the section quotes a heater-limited D-T reactor against a saturated D-D one, and deciding which
  operating point it means is a balance decision of its own, not a side effect of this one.
- **The technology tree gains its first upgrade line**, which is exactly what ADR 0014 predicted would
  happen and called "the sanctioned shape for one". Power goes from seven technologies to ten.
- **ADR 0014's "somewhere past 100 s" becomes about 175 s.** That estimate came from the equilibrium
  solver; this is the shipped `step()` run to convergence, and it is the number the guard has margin
  against. The top rung sits at roughly a third of it.
- **It carries runtime state the rest of the simulation does not** — a per-force cache and five event
  handlers. Both are new, and the cache is deliberately not something a save has to survive.
- **Two rigs measured D-D against a fixed assumption and both were right to complain.**
  `check-pooling.ps1` failed outright: it calls `research_all_technologies()` and then predicts each
  step with the *unresearched* spec, so the pool gained 102.5% of what it was predicted to spend, which
  reads exactly like energy appearing from nowhere. `check-blanket.ps1` kept passing but lost half its
  collector headroom — 70.6 units of helium-3 in the default run researched against 31.4 without, so
  saturation moved from about 115 000 ticks to 51 000. Both hold the ladder down now: a rig is a
  controlled experiment and confinement time is not one of their variables. **Any future rig that
  quantifies D-D output has the same choice to make**, and the two that made it say why.
- **A technology whose name ends in `-<number>` is a *level* to Factorio.** The locale name key is
  `technology-name.rf-plasma-confinement` with no number; numbering it leaves all three showing
  "Unknown key". Caught by `scripts/locale-check.ps1`, which is what that check is for.
- **The icon is `rf-d-d-fusion`'s.** There is no confinement art in the assets mod
  ([ADR 0023](0023-art-ships-in-its-own-mod.md)) and inventing a placeholder is a separate job; it
  joins the backlog [#108](https://github.com/trulsjo/realistic-fusion-refreshed/issues/108) carries.
- **Not playtested.** Whether three rungs at these costs reads as a progression or as a chore is a play
  question and nobody has played it. The rungs are provisional balance numbers like every other one in
  this repository; moving them is an edit to one table and a test re-pin, and the guard is what stops
  that edit going too far.

## Alternatives considered

**A ladder to 70 s, as ADR 0014 proposed.** Q 2.08 at the top and a more generous tier. Rejected on
what it costs elsewhere: 70 s is exactly where ADR 0016's density optimum leaves the range, so the top
rung would end that mechanic rather than narrow it, and the line would have no reason to stop where it
stopped. 60 s is a number the mod already contains.

**An infinite research**, in the style of mining productivity. Rejected on the guard: the invariant in
decision 6 needs a **known top rung** to settle, and an unbounded τ walks into the clamp by
construction — reaching it at about 175 s, where the reactor's thermometer stops moving and every
further level buys a player nothing they can see. Bounding an infinite research to stay short of that
is a clamp someone has to maintain, which is precisely the shape ADR 0020 rejected for capture
efficiency and rejected again here.

**One technology, or five.** One puts a 4.6× swing behind a single research and leaves nothing between
a reactor that loses money and one that pays; five needs a 6 s step to stay under 60 s, which is below
what a player can feel. Three is what fits between them, and it matches the shape ADR 0020 chose for
the same reasons.

**Applying the line to the aneutronic reactor as well.** It is the same physics and the flavour would
carry. Rejected because #52 settled that tier's balance at 60 s after finding that He3-He3's Q of 1.31
did not survive the radiation term, and reopening those numbers as a side effect of a technology named
for the machine below them is the kind of drift ADR 0010 asks to be amended rather than drifted into.
A ladder for that tier is available later, as its own decision.

**Guarding every fill rather than full supply.** The intuitive reading, and the one #53 and ADR 0016
between them imply. Rejected on measurement rather than on taste: it fails at the shipped 30 s with
nothing researched, so it is not a stricter guard, it is an impossible one.

**Guarding against every fuel rather than D-D.** Also impossible, and for a related reason: D-T settles
at the clamp at every rung and at none of them, so the check would fail on the day it was written. The
fuel to guard is stated on the reactor's own spec so that a second reactor given a ladder names its
own, rather than being silently settled on a plasma it cannot burn.

**Research that raises plasma purity instead.** ADR 0014 names it as an available parameter and it is
the other honest lever — real machines chase it, and the model's radiation term reads `Z_eff` off the
fuel row, so there is somewhere for it to act. Rejected for now on the grounds that the model has no
impurity to remove: purity is implicit at 1.0, so the technology would have to introduce a dirtier
starting state before it could clean it up, which taxes the tier to fund its own upgrade. That is the
horn ADR 0020 rejected for capture efficiency. Available later if an impurity fraction is ever modelled.

**Quoting Q in the technology descriptions**, computed from the model at data stage so it could not
drift. About 40 ms per rung at every game start, for a tooltip. Rejected on cost; the tests pin the
claims instead, and the descriptions quote the seconds — which is what the research actually moves.

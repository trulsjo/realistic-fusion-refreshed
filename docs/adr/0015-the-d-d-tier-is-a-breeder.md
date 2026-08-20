# 15. The D-D tier is a breeder, and its entry cost is the point

Date: 2026-08-19

## Status

Accepted. Settles items **1** and **4** of
[#37](https://github.com/trulsjo/realistic-fusion-refreshed/issues/37) — the numbers half that
[ADR 0014](0014-realistic-means-theoretically-possible.md) deliberately left open, together with the
entry cost and the brownout behaviour.

Applies ADR 0014 rather than extending it: that ADR decided a tier *may* arrive below break-even,
this one decides that the D-D tier *does*, and what it is for instead. Unblocks
[#52](https://github.com/trulsjo/realistic-fusion-refreshed/issues/52) and constrains
[#53](https://github.com/trulsjo/realistic-fusion-refreshed/issues/53).

Decided by Truls, 2026-08-19. Recorded here because it is a decision, not a consequence of one.

**Amended 2026-08-20 (#70).** Nothing in the Decision changes. One consequence's premise — that a D-T
reactor's loss deepens the brownout that caused it — was measured and is false, and is struck and
corrected in place rather than deleted. The two tiers' answers are stated together there, and the one
question the correction left — the sub-ignition drain — is accepted in the same place, by Truls.

## Context

ADR 0014 left two things open in as many words: *whether the term actually goes in, and what the D-D
tier's shipped numbers become.* [#51](https://github.com/trulsjo/realistic-fusion-refreshed/issues/51)
then removed the last reason to wait, by resolving the 20% disagreement between two bremsstrahlung
figures — they were one equation under two published fits — and leaving
`tests/test-bremsstrahlung.lua` checked in, so no number here rests on an unkept harness.

**The precedent and #52 did not agree, and that is the substance of the second decision below.**
#52's acceptance criteria say D-D settles *below* break-even. But the table ADR 0014 was built on has
the 1.1 original's unsuppressed D-D at **exactly Q 1.00** at base: `rfp-d-d-fusion` unlocks that
variant, and the sub-break-even Q 0.50 and Q 0.25 variants are gated behind *breeding* research — a
downgrade the player opts into.

**That balance is Romner_set's**, from Realistic Fusion Power 1.8.18, and the argument this ADR makes
against it rests on his design rather than replacing it: he chose break-even at the reactor and
net-negative variants a player opts into for fuel, which is the same mechanic reached here by a
different route. ADR 0014 quotes him directly and records the reading in full. Attribution stated
because it is derived work, per `CLAUDE.md` — a community norm rather than a licence obligation.

His Alt-F4 interview's *"cannot even sustain itself"* reconciles with Q 1.00 because
the **reactor** breaks even while the **plant** does not, on Girdler sulfide and electrolysis and
pumps. So the original's entry state was break-even at the reactor, and arriving below it is one rung
stricter than the mod this one descends from.

**What a single D-D line draws before any fusion power exists**, which is the other half of the
question:

| | |
|---|---:|
| `rf-reactor` confinement heating | 50 MW |
| `rf-heater` | 5 MW |
| `rf-electrolyser` × 2 | 400 kW |
| `rf-deuterium-extractor` | 400 kW |
| chemical plant (H₂S) | ~210 kW |
| **total** | **~56 MW** |

`rf-d-d-fusion` sits behind `advanced-circuit` and `concrete` — roughly blue science, where 56 MW is
about 62 vanilla steam engines. Vanilla nuclear, the comparable tier, needs no startup power at all.

**And the draw never stops.** Plasma leaves the heater at 10⁶ °C, which fuses essentially not at all;
confinement heating is what climbs it to a fusing temperature. `heating_j` is clamped to `available_j`
in `scripts/reactor-logic.lua`, so a brownout cools the plasma and the climb back is minutes. Nothing
in the mod arrests that.

> **True of this tier, and only of this tier.** Read as a statement about the reactor it is not: at
> D-T's density and confinement time the plasma is *ignited*, so confinement heating is what gets it
> to a fusing temperature rather than what keeps it at one, and a brownout does not cool it. Measured
> 2026-08-20 (#70); see the correction under Consequences.

## Decision

**The radiation loss term goes into the simulation.** A zero-dimensional power balance that omits the
loss channel larger than its own fusion power is implied physics with cross-section data bolted on,
which is the thing this project exists not to be. #52 carries it.

**Confinement time stays at 30 s, and D-D arrives below break-even.** Q 0.32 at full supply — 16 MW
of fusion power against 50 MW of heating. (Q 0.45 at its density optimum; see
[ADR 0016](0016-plasma-density-is-a-player-lever.md), which does not change the tier's character.)
The wider ladder this leaves #53 is part of the reason: from 0.32 to 2.08 is a progression, where a
tier entering at break-even has one rung of headroom before the clamp.

**The D-D tier's product is tritium and helium-3, not electricity.** This is the substantive claim,
and it is what makes the two numbers above a design rather than a shortfall. A player builds a D-D
reactor to breed the fuel the D-T tier burns. Power is what #53's research and the later tiers make
of it. `CONTEXT.md` fixes the term.

**The entry cost is accepted, and is stated where a player meets it.** The `rf-d-d-fusion` technology
description says the reactor consumes more than it produces and is built to breed — so the cost is
read before the chain is built, rather than discovered by building it and watching it sit cold.

**The plasma cooling on brownout is accepted.** There is no standby mode, no low-power idle, and the
reactor is given no way to arrest its own decline.
[#25](https://github.com/trulsjo/realistic-fusion-refreshed/issues/25) already emits plasma
temperature and Q per reactor, so a player who wants a reactor that survives inattention wires
accumulators or sheds load themselves. **The arrest exists; it is the player's to build.** That is
the answer, and it is recorded so that the absence of a safeguard is not read as an oversight.

**Rejected explicitly, because #37 lists it as an option: letting the plasma hold its heat when
unpowered.** The loss term *is* confinement. A plasma that keeps its temperature with no power going
into it is not a modelling simplification but a contradiction of the one thing ADR 0014 fixes as
physics rather than engineering. It is the cheapest code change available here and the most expensive
claim.

## Consequences

- **`CONTEXT.md` gains the term.** "Breeder tier" is now vocabulary, and "D-D by-products" stops
  reading as a side effect of a power reactor.
- **#52 proceeds as written**, including its blast radius: `tests/test-reactor-logic.lua`'s
  shipped-balance block asserts the *intended* sub-break-even state and says why it is intended;
  [`d-t-ignition.md`](../research/d-t-ignition.md)'s fuel-chain arithmetic re-derives from the new
  settling point; the README's status line and #30's blanket figures re-anchor.
- **#53 is the route out**, and its rung figures are **full-supply** figures — see ADR 0016.
- **The D-T tier's version of the brownout question is not settled here.** At Q 0.32 a D-D reactor is
  a 40 MW load, so losing it to a brownout makes the brownout *better*: the runaway #37 worried about
  has no teeth at this tier. ~~At D-T's Q 7 the reactor is a major generator and its loss deepens the
  brownout that caused it.~~ — **struck 2026-08-20: measured, and it does not. See the correction
  below.** That is a different question, it is foreseeable now, and it is tracked separately rather
  than left to be rediscovered in play.

  > **The premise of that question was measured and is false. Corrected 2026-08-20 (#70).** A D-T
  > reactor's loss does not deepen the brownout that caused it, because a brownout does not cost it
  > its plasma. At this reactor's density and confinement time a D-T plasma is **ignited**: its own
  > alpha heating outruns the confinement loss, so the 50 MW is what gets it to a fusing temperature
  > and not what keeps it at one.
  >
  > `scripts/check-brownout.ps1` builds eight cells, each a reactor with its own `rf-heater` on its
  > own network, and produces the shortfall by undersupplying that network — so the fuel line and the
  > confinement heating are throttled together in the engine's own proportions rather than in ones a
  > script chose. `rf-reactor` is `usage_priority = "secondary-input"`, the same bucket as every
  > other machine, so that is what a brownout actually does to it.
  >
  > Measured against a **settled** baseline, which took thirty minutes rather than the five the rig
  > first used: a cell's plasma segment is the reactor's box plus every pipe back to its heater, and
  > the engine fills the segment, so the reactor's own box takes about half an hour to reach its share.
  > The rig asserts the baseline has stopped climbing before it cuts anything.
  >
  > **At half supply** the cell stayed at 1.96×10⁹ °C and contributed **+178 MW net** — about half its
  > lit output for half its supply. **Through fifteen minutes with no power at all** it kept **15.3%**
  > of its lit output, ended at 9.48×10⁸ °C with 93.5 units still in the box, and was **+123.6 MW
  > net** — better than lit, because it is no longer paying for heating. **Supply restored and nothing
  > else done**, it was back at the clamp inside five minutes and net positive the whole way up.
  > **Overloaded past what it can make**, a closed plant — reactor, heater, exchanger, two turbines,
  > load bank — stayed at the clamp. The spiral was made to happen on purpose and did not.
  >
  > **What stands:** everything in the Decision above. The plasma cooling on brownout is accepted,
  > the arrest is the player's to build, and letting the plasma hold its heat unpowered stays
  > rejected — all of it decided for the D-D tier, all of it still true of the D-D tier, which the
  > same rig measures falling to **0.44%** of its lit output through the same blackout where the D-T
  > reactor keeps 15.3%, a factor of thirty-five.
  >
  > **What is void:** that D-T's loss is self-amplifying, and with it the reason #70 gave for treating
  > the tiers differently. Both tiers are safe under a shortfall. They are safe for opposite reasons,
  > and that is the thing worth stating together: a D-D reactor is harmless to lose because it is a
  > **load**, and a D-T reactor is harmless to lose because **ignition is its own arrest**. The mod
  > did not need the safeguard #70 was going to consider building, because the physics already
  > carries one.
  >
  > **What is now open: nothing.** The one thing the correction left was the sub-ignition drain, and
  > it is **accepted — Truls, 2026-08-20, closing #70.** A reactor holding plasma too thin to carry
  > itself runs at **−7.1 MW**: a seventh of its heating rather than the whole of it, because
  > `capture_efficiency` sells what leaves the plasma whether or not fusion put it there. It is
  > accepted on two grounds and not on its size alone. **It is self-clearing** — an empty reactor
  > draws nothing at all, so the state ends by itself rather than needing a player to notice it. And
  > **nothing a player does reaches it**: no cell in the rig got there by losing power, and fifteen
  > minutes of total blackout left the reactor far above it; the drain had to be seeded by hand to be
  > measured at all. So no mechanic is built for it, and the reason is recorded here rather than left
  > as an absence.
  >
  > `tests/test-reactor-logic.lua` carries the second-long version of the claim, and
  > [`d-t-ignition.md`](../research/d-t-ignition.md) the measurement.
  > [`brownout-rig.md`](../research/brownout-rig.md) is the rig's own output and is regenerated
  > rather than written. #70 was re-scoped around the corrected premise and carries the falsified one
  > in its history.
- **[#46](https://github.com/trulsjo/realistic-fusion-refreshed/issues/46) is untouched.** Its text
  hoped #37 might resolve its items 1 and 3. It does not: the draw's *shape* changes (#37's item 4b)
  but the declared `energy_consumption = "1W"` does not, so the seven-orders-out tooltip and the
  meaningless 165 °C both survive.
- **Nothing here is playtested.** Whether a tier that costs 40 MW to run reads as a satisfying
  investment or as a wall is exactly the sort of question CLAUDE.md holds behind playing the game.
  This ADR fixes the *shape*; the numbers inside it remain provisional.

## Alternatives considered

**Keep the model radiation-free.** Ship the Q 2.14 reactor and record the omission as knowing.
Rejected: it costs the project's central claim, and #52 and #53 would both close as wontfix.

**Arrive at break-even, τ ≈ 52 s.** Reproduces Romner_set's entry state exactly and makes his Alt-F4
sentence come out right for the right reason. Rejected on ladder headroom, and because D-D at 52 s
would be nearly as well confined as D-T at 60 s, leaving D-T's tier advantage resting entirely on
reactivity.

**Arrive shallower, τ ≈ 45 s**, Q around 0.6. Rejected: no precedent in the original for it as an
entry state, and it buys a narrower ladder for a softer landing.

**Cut `heating_power_w`.** Raises Q and shrinks the entry cost with one number. Rejected because it
moves Q off the landing this ADR chose, so it answers a different question.

**A low-power standby mode.** Real gameplay value, and the largest new-code answer available — a new
state, a rule for who flips it, and new locale. Rejected for v1 as scope; not refused for later.

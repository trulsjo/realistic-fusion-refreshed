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
  has no teeth at this tier. At D-T's Q 7 the reactor is a major generator and its loss deepens the
  brownout that caused it. That is a different question, it is foreseeable now, and it is tracked
  separately rather than left to be rediscovered in play.
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

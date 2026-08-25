# 25. A plasma temperature ships in kilodegrees, and the ceiling is where the reactions run free

Date: 2026-08-25

## Status

Accepted. Decided by Truls, 2026-08-25, settling
[#56](https://github.com/trulsjo/realistic-fusion-refreshed/issues/56) — both of the coupled decisions
it names, the wire encoding and the ceiling, on figures measured while deciding rather than on the
ones the ticket carried.

**Retires the reason written into three files.** `scripts/circuit-output.lua`, `control.lua` and —
most extensively — `scripts/reactor-logic.lua` all state that the ceiling is 2e9 *because* a circuit
signal is a 32-bit integer, which
[#55](https://github.com/trulsjo/realistic-fusion-refreshed/issues/55) built a load-time guard
around. That sentence stops being true here.

`reactor-logic.lua` carries it in five places and is the easiest to miss, because it is the file the
other two point *at* rather than the one they point from: lines 196-197 ("it stays for one reason
that holds: int32 stops at 2.147e9"), 204, 208, 227, and 576-578 ("2e9 is where a temperature stops
fitting in the int32 a circuit signal is"). All five are
[#57](https://github.com/trulsjo/realistic-fusion-refreshed/issues/57)'s to rewrite, and #57 is more
than a wording change — see [Consequences](#consequences).

**Spends [ADR 0014](0014-realistic-means-theoretically-possible.md)** the way
[ADR 0024](0024-confinement-time-is-the-researchable-lever.md) does. ADR 0014 fixed what "realistic"
means and left each tier's numbers open; the ceiling is one of those numbers, and this places it
without extending that ADR's reasoning.

**The ceiling counterpart to [ADR 0021](0021-the-floor-is-where-the-model-stops.md), and not by the
same argument.** The floor is where the model stops being trustworthy. The ceiling is not: it sits
well inside the range the cross-section data covers, and is placed by where the reactions settle
rather than by where the physics runs out. Do not read the two as a matched pair.

**Constrained by [ADR 0016](0016-plasma-density-is-a-player-lever.md).** Thinning a plasma raises its
settled temperature without bound, so no ceiling unpins every reaction at every fill. That is why
this one is placed against operating densities and not against all of them.

**Corrects [#56](https://github.com/trulsjo/realistic-fusion-refreshed/issues/56)'s own balance
table**, whose aneutronic rows and whole 6.9e9 column predate
[#52](https://github.com/trulsjo/realistic-fusion-refreshed/issues/52)'s radiation term. See
[Context](#the-table-this-was-to-be-decided-on-was-pre-52).

## Context

### What the signal is, and why the ceiling was 2e9

A reactor publishes two signals, both of them the mod's own: `rf-signal-plasma-temperature` and
`rf-signal-q-factor`. A Factorio circuit signal is a 32-bit integer and stops at 2 147 483 647; the
engine throws rather than wraps on a larger write, so `to_signal` clamps.

Temperature went out in whole degrees, which is exact and stops below the temperature a D-T plasma
actually reaches. The ceiling was set at 2e9 to stay under that limit. Nothing in the game said so,
which is the defect [#54](https://github.com/trulsjo/realistic-fusion-refreshed/issues/54) is open
about: three of the four reactions settled at the clamp and reported the identical number, so a wire
could not tell them apart.

Q was never in degrees. It ships as `q_factor * 100`, deliberately, so that `Q > 100` is the decider
condition worth wiring. The output already carried a scaled quantity chosen for what makes a good
condition rather than for raw SI, which is the precedent this decision follows rather than breaks.

### The compatibility cost the ticket weighed was not live

#56's table made "existing wiring" the decisive column, and concluded that only a two-signal
mantissa-and-exponent scheme "leaves an existing player's circuit conditions meaning what they
meant". The mod is not published on the mod portal — no tags, no releases, all three mods at 0.1.0,
no changelog. No player has wired a condition against the current meaning, so that column was scoring
a cost nobody pays, and the option it favoured is the one whose ergonomics are worst: `temperature >
X` stops being expressible as a single combinator condition.

### The table this was to be decided on was pre-#52

#56 quotes equilibria at 2e9 and 6.9e9 for all four reactions. Measured through the shipped `step()`
today, the aneutronic rows and the entire 6.9e9 column no longer hold:

| #56 says | measured 2026-08-25 |
|---|---|
| D-T at 6.9e9: 4.63e9, Q 58.9 | 3.27e9, Q 73.1 (tau 30 s, full) |
| D-He3 at 6.9e9: pinned, Q 56.3 | does not ignite at full (1.37e7); free at 4.41e9, Q 18.8 at half fill |
| He3-He3 at 6.9e9: pinned, Q 15.9 | free at 2.51e9, **Q 0.022** — never ignites at any fill |

`scripts/reactor-logic.lua` already records why, above the He3-He3 row: *"lifting `max_temperature_c`
does nothing for this reaction: Q saturates at 0.0224 and stops improving past 3e9, because radiation
now sets the equilibrium before the ceiling does. The same test gave Q 16 at a 7e9 ceiling before
#52."*

So #56's stated justification that "He3-He3 goes from marginal to a tier worth reaching" is gone. It
was true of a model that carried no radiation. **This ADR does not reopen that tier** — its fate was
decided by Truls on 2026-08-21 under #52's last criterion and is recorded at that same comment. It
notes only that the ceiling is not what rescues it, and nothing here may be tuned to imply otherwise.

### Where the reactions actually settle

Measured with the ceiling lifted to 1e12 so nothing clamps, through `step()` at 1/60 s for 4000 s.
The neutronic reactor's ladder is [ADR 0024](0024-confinement-time-is-the-researchable-lever.md)'s;
the aneutronic reactor deliberately has none.

| reaction | condition | settles at |
|---|---|---|
| D-D | tau 30 s full → tau 60 s at 35% fill | 2.42e8 → **2.05e9** |
| D-T | tau 30 s full → tau 60 s full | 3.27e9 → **3.92e9** |
| D-He3 | full (3000) — does not ignite | 1.37e7 |
| D-He3 | 1500 / 1000 / 600 | **4.41e9** / 4.39e9 / 4.51e9 |
| D-He3 | 300 / 150 | 5.53e9 / 1.19e10 |
| He3-He3 | 300 (its best) | **2.51e9** |
| He3-He3 | 150 | 6.43e9 |

Two things follow. The highest operating-density equilibrium is D-He3's 4.41e9, not the 6.9e9 the
ticket assumed. And thinning drives temperature up without bound — ADR 0016's mechanic — so there is
no ceiling that unpins every reaction at every fill, and placing one against the thinnest conceivable
supply would mean placing it past the data.

### Three bounds, and the physics one is nearer than the dataset

`cross-section-data/reactivities.lua` tops out at 6.96271e9 K and `M.interpolate` clamps flat above
its top row, so any ceiling past about 7e9 balances the plasma against a constant rather than against
physics.

**Nearer than the dataset, and the bound this ADR nearly missed: the radiation term goes out of
domain at 5.93e9 K.** `scripts/reactor-logic.lua` states it above `radiation_factor`, and states it
*for this decision specifically* — "ABOVE 511 keV THE FIT IS OUT OF DOMAIN and this holds it at its
edge value rather than extrapolating. That UNDERSTATES radiation above 5.93e9 K, stated because it is
a real limit and because #58 may raise `max_temperature_c`: no shipped reactor reaches it … but a
future one could, and **it should find this note rather than a silent extrapolation**." A comment left
to be found by exactly this work. **Two figures in the table above sit past it** — He3-He3 at 150
units (6.43e9) and D-He3 at 150 units (1.19e10) — so both understate radiation and neither may be
leant on. Every equilibrium the decision actually rests on is below 5.93e9.

Nearest of all: a prototype's `max_temperature` is returned at single precision, so a ceiling that
is not float32-exact reads back smaller than it was declared and
[#119](https://github.com/trulsjo/realistic-fusion-refreshed/issues/119) rejects it over two numbers
that print identically. Of the candidates, 2e9, 4e9, 5e9 and 6.8e9 are exact; 6.5e9 and **6.9e9 —
the ticket's own proposal** — are not.

## Decision

**A plasma temperature ships in kilodegrees Celsius.** The signal carries `temperature_c / 1000`.
Precision is 1000 °C, which is one part per million at fusion scale and enters no control decision.
Q is untouched.

**The ceiling is 5e9 °C**, on both reactor specs and every plasma fluid's `max_temperature`.

**The ceiling's reason is that every shipped reaction runs free beneath it, with margin.** It clears
the highest operating-density equilibrium, D-He3's 4.41e9, and it clears D-D and D-T at every rung of
the confinement ladder. It is float32-exact, so #119 does not gate it. It sits inside the dataset, so
no equilibrium is set against the clamped top row.

That reason is load-bearing for what may move it later. **A reaction added that settles higher obliges
revisiting the ceiling. Regenerating the cross-section dataset does not, by itself** — the ceiling is
placed by where the reactions land, not by where the data ends.

## Consequences

**The int32 justification is retired, and #57 must change the guard's ARITHMETIC, not just its
words.** This is the trap in implementing this ADR, so it is stated before the rest.

`check_signal_ceiling` passes the **raw Celsius** `spec.max_temperature_c` to
`circuit.unrepresentable`, which tests `temperature_c > INT32_MAX`. Neither knows the wire is scaled.
Raise the ceiling to 5e9 and change only `M.signals`, and the guard evaluates `5e9 > 2147483647`,
fires, **and the mod refuses to load.** The check must compare the *scaled* value — what the wire
would actually carry — before any of this is true.

Once it does, the guard goes slack rather than away: 5e9 ships as 5 000 000 against 2 147 483 647,
three orders of magnitude of headroom. **Keep it.** A guard that cannot fire today still names the
coupling, and the coupling is real — it is only the ceiling that has stopped being set by it. Its
message must stop claiming the ceiling exists because of the integer.

**Until #57 lands, all three files above state a reason this ADR has made false.**

**The wire disagrees with the engine's own tooltip by 1000x.** Plasma temperature lives on the fluid,
and Factorio renders fluid temperature in °C natively. That display is not ours to rescale, so a
player hovering a pipe sees a number a thousand times larger than the wire's. Accepted: the
alternative that avoids it costs two signals and a comparison no single combinator condition can
express.

**A cold reactor reads 0.** Anything below 500 °C rounds to nothing, so a reactor at the 15 °C floor
reports 0 on the temperature signal — the same as one with no plasma at all. The status signal already
separates starved from idle, and that is now the only thing that does.

**`scripts/check-observability.ps1` has an assertion that cannot survive this**, and no softer reading
of it is available. Its `idle` case reads at `SettleTicks = 2400`, by which point the plasma has been
at the floor for most of the run — the rig's own comment says "15 C on the wire against 15 C in the
box". In kilodegrees that wire reads 0 against an actual of 15, a drift of 1.0 against a bound of
0.05, so the check fails. It is measuring something real and must be re-sited rather than loosened:
a bound wide enough to pass 0-against-15 is the bound #120 already removed for not discriminating.
#57 owns it.

**Three of four reactions stop reporting the same number.** D-T unpins to 3.27–3.92e9 depending on
research, D-He3 to 4.41e9 at its operating density, He3-He3 to 2.51e9. #54's complaint is answered for
every reaction at its operating point, and not answered for extreme-thin fills, where D-He3 settles
past the data entirely.

**Two tiers are re-tuned, and not upward.** Unpinning is not a buff: D-T's Q falls from 96.1 to 73.1
as it finds its real equilibrium, and D-He3's from the pinned figure to 18.8. ADR 0014 makes that
legitimate — the number is what the model says, not what would be pleasant.

**#56's table needs correcting rather than citing.** Its aneutronic rows and 6.9e9 column are pre-#52
and should not be quoted in #57 or #58.

## Alternatives considered

**Keep whole degrees.** Exact, and agrees with the fluid tooltip. Forecloses the ceiling: to unpin
D-T at all requires exceeding 2 147 483 647 °C, so keeping degrees means keeping the ceiling at 2e9
and leaving #54 permanently unfixed. Rejected for that, not for precision.

**Degrees plus a scale signal.** Mantissa and exponent, exact at every magnitude, and the only option
whose degrees match the tooltip. Its entire case rested on preserving player wiring that does not
exist. Costs a second signal every player must learn and makes "temperature above X" a two-step
comparison. Rejected.

**Megadegrees.** The best combinator ergonomics by some distance — the whole interesting range is four
digits, and MK is a unit plasma physics actually uses. Collapses everything below 500 000 °C to zero,
taking the entire cold-start and idle range with it. Rejected for the bottom of the range, not the top.

**keV.** Physically the natural unit, and the one the cross-section data is indexed in. Unfamiliar to a
player, and it divorces the wire from every other temperature the game shows. Rejected.

**A 6.8e9 ceiling.** Float32-exact and at the dataset's edge. Buys one thing over 5e9: He3-He3 stays
free when thinned to 150 units. Costs the margin inside the data, so equilibria near the top are set
against the last interpolated rows. **Rejected on the radiation bound rather than on that margin**:
6.8e9 is past 5.93e9, where the bremsstrahlung fit is out of domain and understates the loss, so a
plasma settling up there settles against a term known to be wrong — and the 6.43e9 figure that is the
whole case for the ceiling is itself computed that way. Paying real margin for a fill nobody operates
at, in a tier that does not ignite, on a number that cannot be trusted at the temperature it names.

**A 4e9 ceiling.** Float32-exact and conservative. Leaves D-He3 pinned, since its equilibrium is
4.41e9 — so the aneutronic pair still could not be told apart, which is #54's complaint surviving in
the tier it most affects. Rejected.

**6.9e9, as the ticket proposed.** Not float32-exact, so it blocks on #119, and its supporting figures
were pre-#52. Rejected on both counts.

# 38. Heating power is the second researchable lever, in five rungs to 75 MW

Date: 2026-09-19

## Status

Accepted. Settles
[#292](https://github.com/trulsjo/realistic-fusion-refreshed/issues/292) — which lever brings the
**supply ratio** down, to what target, and what it is allowed to cost. Unblocks
[#293](https://github.com/trulsjo/realistic-fusion-refreshed/issues/293) and
[#294](https://github.com/trulsjo/realistic-fusion-refreshed/issues/294), and narrows
[#291](https://github.com/trulsjo/realistic-fusion-refreshed/issues/291).

**Decided by Truls, 2026-09-19**, over a grilling session that put every branch of the decision to
him one round at a time. Recorded here because it is a decision, not a consequence of one. The
figures below were measured during that session through the shipped `settle()`, in a scratch rig
that is **not committed**; #291 commits one that reproduces them.

**Extends [ADR 0024](0024-confinement-time-is-the-researchable-lever.md)** rather than replacing it.
That ADR made confinement time *a* researchable lever and argued it was the only one left. This adds
a second on the same reactor, independent of it, and ADR 0024's own figures are untouched — see
[Consequences](#consequences).

**Extends [ADR 0010](0010-v1-module-layout-and-prototype-set.md)'s technology set** by five, the way
ADR 0019, ADR 0020 and ADR 0024 extended it. ADR 0010's technology list carries a dated note
pointing here.

**Narrows [ADR 0015](0015-the-d-d-tier-is-a-breeder.md)** and **closes
[ADR 0016](0016-plasma-density-is-a-player-lever.md)'s mechanic at the top of the tree.** Both are
deliberate and both are argued below.

## Context

**The complaint, in Truls's words on 2026-09-09:** *"95 D-D reactors for each D-T reactor does not
seem to be acceptable game-play wise. we need to find a way to make this number (much) smaller."*
That settled the direction and nothing else.

[#290](https://github.com/trulsjo/realistic-fusion-refreshed/issues/290) then gave the quantity one
name — **supply ratio**, defined in `CONTEXT.md` — and published both its readings. This ADR argues
about one figure because of that.

### Three facts reshaped the question before any lever was chosen

**94.7 is the unresearched figure, and ADR 0024's ladder already cuts it five-fold.**
[`d-t-ignition.md`](../research/d-t-ignition.md) tabulates the ratio against the confinement rungs:
94.7 at the shipped 30 s, 49.9, 29.3, and **18.5** at the top rung. A player who finishes the ladder
today already sees 18.5, with nothing retuned.

**A blanketed D-T reactor needs no D-D reactors at all.** `M.blanket.tritium_per_neutron` is 1.1,
every D-T reaction makes one neutron, and `control.lua`'s `blanket_breed` hands one blanket the
reactor's whole neutron count — so it breeds 1.1 tritons for every 1 burnt
([#30](https://github.com/trulsjo/realistic-fusion-refreshed/issues/30)). The unblanketed ratio
therefore governs the **bootstrap only**: the farm a player builds to prime the loop and to cover
the phase before `rf-blanket-breeding`.

**D-T already runs, and pays, on a farm a player can build.** Ignition removes temperature as a
control input and hands the player the fuel line instead (ADR 0016), so an under-fed D-T reactor is
a working reactor. Nine D-D reactors feed one `rf-heater`, and one heater on an ignited D-T reactor
is worth roughly six D-D reactors' output on its own.

So the complaint is not that D-T gives no power at unlock. It is that the **saturated** figure
describes a farm nobody can finish, and that even the fully-researched 18.5 is 4 162 tiles of
reactor at 15×15 apiece.

### The lever was chosen by measurement, and the intuitive ones are backwards

Measured across both ends of ADR 0024's ladder:

| what moves | ratio at τ 30 | ratio at τ 60 | verdict |
|---|---|---|---|
| *(shipped)* | 94.70 | 18.50 | the baseline |
| `heating_power_w` up | falls monotonically, no turn-over | same | **the lever** |
| `volume_m3` 1000 → 2000 | 72.41 | 18.43 | already at its optimum |
| `volume_m3` 1000 → 4000 | 73.28 | 20.34 | turns back up |
| `volume_m3` 1000 → 500 | 300.17 | 78.03 | far worse |
| baseline `confinement_time_s` up | reaches the target | — | empties ADR 0024's ladder |
| `max_temperature_c` down | worse | — | the intuitive move, and backwards |
| density ×2 | far worse | — | bremsstrahlung goes as n² |

`volume_m3` is the density axis at a fixed fluid box, which is why it has an interior optimum and
why the shipped 1000 m³ is already on it. **Raising reactor capacity does not help**, and that is
worth writing down because it is the second thing anyone reaches for after the clamp.

## Decision

### 1. The target is about 9, stated per saturated reactor

**About 9 settled D-D reactors per saturated D-T reactor, at the fully-researched state.** The
stated target is **10**; the gate ceiling is **15**. The measured figure at the top of both ladders
is **8.93** — 2 009 tiles of reactor.

**The gap between 10 and 15 is deliberate.** Truls's words: 10 *"is not a hard limit, if the physics
demands more it will have to be more. It is more a matter of the pain for the player."* The target
is where the pain is comfortable; the ceiling is where it becomes unacceptable. A gate on 10 alone
would make #294 lie about how firm this is.

**Stated per saturated reactor**, which is the reading the whole footprint argument is built on and
the one a future `rf-hc-heater` cannot silently move. `CONTEXT.md`'s rule still applies: any figure
published here says which reading it is.

**Entry stays at 94.70, reported and ungated.** It is not a number a player is ever required to
meet, and a second ceiling would give #294 two gates for one decision.

### 2. The lever is `heating_power_w`, as `rf-plasma-heating-1..5`

**Five rungs at 5 MW, taking confinement heating 50 MW → 55 → 60 → 65 → 70 → 75.** Per force,
neutronic only, and **independent of ADR 0024's confinement ladder** — both root at `rf-d-d-fusion`
and neither is a prerequisite of the other.

The supply ratio across both ladders, measured:

| heating | τ 30 s | τ 40 s | τ 50 s | τ 60 s |
|---|---|---|---|---|
| **50 MW** *(shipped)* | **94.70** | 49.86 | 29.28 | 18.50 |
| 55 MW | 71.73 | 37.75 | 22.41 | 14.70 |
| 60 MW | 56.47 | 29.91 | 18.13 | 12.38 |
| 65 MW | 45.87 | 24.59 | 15.31 | 10.85 |
| 70 MW | 38.27 | 20.84 | 13.34 | 9.75 |
| **75 MW** | 32.63 | 18.09 | 11.90 | **8.93** |

The 50 MW row reproduces the figures already pinned in `tests/test-reactor-logic.lua`, which is how
the scratch rig was checked.

**Five rungs rather than three, and no null rung among them.** Per rung the ratio falls 24%, 21%,
19%, 17% and 15% at entry confinement, and 21%, 16%, 12%, 10% and 8% at the top rung. A long shallow
ladder is the right shape for a lever whose whole purpose is grinding a farm down.

**Named `rf-plasma-heating-1..5` rather than `rf-confinement-heating-*`.** The parameter is what
ADR 0015 calls *confinement heating*, but a technology by that name reads at a glance as
`rf-plasma-confinement-*`, and two separate ladders is exactly the situation where that confusion
costs something. `rf-plasma-heating` also matches the recipe family `rf-heater` already runs.

**Two ladders rather than one.** Folding heating into the existing `rf-plasma-confinement-1..3`
reaches 10.15 at the top rung with no new technologies and keeps `control.lua`'s density-curve cache
key valid. It was rejected for player choice: the heating rungs are at their strongest at entry
confinement, where they are worth −24% to −15%, and a player should be able to spend them there.

**Costs, science packs and icons are provisional**, like every other balance number in this
repository.

### 3. Entry is untouched, and that is the point

At the shipped 50 MW nothing moves: 94.70, Q(D-D) 0.320, 56.1 MW sold against a ~56 MW line draw.
Truls's requirement, 2026-09-19: *"first reactor should not give much surplus. Heating power could
perhaps be researchable."* The second sentence is where the two-ladder shape came from, and the
first is what it buys — a researchable lever leaves the unresearched machine exactly as ADR 0015
designed it.

### 4. What is refused, and why

Recorded so nobody re-derives them.

- **Raising the baseline `confinement_time_s`** reaches the same ratios, but 60 s is ADR 0024's top
  rung. Raising the baseline there empties the ladder of its meaning and takes D-D above break-even
  at entry, contradicting ADR 0015 directly.
- **Lowering `max_temperature_c`** is the first thing anyone reaches for and it is backwards: the
  plasma parks nearer the ⟨σv⟩ peak and burns more.
- **Doubling density** is far worse — bremsstrahlung goes as n² and D-D collapses.
- **Halving D-T `volume_m3`** is worse; raising it is at best flat and then worse. The shipped
  1000 m³ is already on the optimum.
- **The lithium blanket is not a lever.** It sets the ratio to zero and ends the question; it does
  not make it smaller. See Context.
- **Moving `rf-blanket-breeding` earlier in the tech tree** has no room. Its prerequisites are
  `rf-d-t-fusion`, `rf-tritium-breeding` and `rf-lithium-extraction`, so it already sits immediately
  behind the reactor it blankets and cannot precede it. Only its cost can move, which shortens the
  unblanketed phase without making the farm a player must build first any smaller.
- **Accepting 94.7 and quoting the tier supply-limited** was the honest non-answer on the table. It
  is refused because the objection was never that D-T gives no power — it is the size of the farm,
  and calling the farm optional does not shrink it.
- **Under-filling the D-T reactor** is not a model change and was never a lever. ADR 0016 already
  makes it the player's throttle.

### 5. The aneutronic tier does not move

`rf-aneutronic-reactor` records the same measurement in a different vocabulary — a heater on the
D-He3 mix costs the same 9.12, and one on bare helium-3 18.2 — and it has its own spec, already
shipping 200 MW of heating and 60 s of confinement. **It is left exactly where it is, deliberately.**
ADR 0020 and ADR 0024 both set the precedent that a decision named for one tier must not retune
another as a side effect. Whether its ratio should move is [#422](https://github.com/trulsjo/realistic-fusion-refreshed/issues/422).

### 6. Fission-sourced tritium is noted, not decided

Buying tritium from fission would make the supply ratio stop mattering rather than make it smaller.
[`fission.md`](../research/fission.md) already carries the physics — UKAEA CCFE-PR(17)67 on CANDU
tritium — and records that Krastorio 2 makes `kr-tritium` from reprocessing and centrifuging. Truls,
2026-09-19: it *"would be another sibling mod (like antimatter power) that is still only an idea."*
That is a scope decision about what the mod set contains, touching ADR 0002's module split, and it
is not taken here.

## Consequences

### ADR 0015 is narrowed, not broken

Q(D-D) at entry is unchanged at 0.320, because entry heating is unchanged. What a researched player
sees is different: at 75 MW and 30 s a D-D reactor runs at Q 0.613 and sells 102.9 MW against a
~81 MW line, so it turns a real profit. **It never crosses scientific break-even at any heating
power** — Q(D-D) peaks at **0.968, at about 180 MW**, and falls away on both sides of it; by 200 MW
it is back to 0.964 and by 400 MW to 0.807. Measured on a 2 MW sweep at τ 30 rather than
extrapolated. So ADR 0015's letter holds at every rung and its spirit is narrowed to where it was
aimed: the *unresearched* tier.

### A D-D line's draw rises by half, and research is what did it

ADR 0015's ~56 MW whole-line figure becomes ~81 MW at the top heating rung. ADR 0015 also records
that a brownout cools a D-D plasma and the climb back is minutes, so a player who researches heating
without growing their grid gets a deeper, slower brownout than before.

**This is recorded rather than solved.** It is the honest shape of the lever — a shorter fuel chain
bought with a bigger grid bill — and it gives the five rungs a decision instead of a free ratchet.
**Each technology's description must say the draw rises**, because a research that quietly increases
consumption is the kind of thing a player discovers as a blackout.

### ADR 0016's density mechanic closes at the first heating rung, at top confinement

At τ 60 and 50 MW the D-D optimum sits at 90% fill with a floor at 85% — a live, if narrow,
`lean`/`running`/`rich` choice. At τ 60 and **55 MW** the optimum is 100% and the floor is 0%: no
interior peak, nothing to tune, `circuit-output.status` collapses to `running`.

ADR 0024 chose 60 s over 70 s *specifically* to leave that +4% alive. The first heating rung spends
it. **Accepted**, on the grounds ADR 0016 itself gave — the mechanic was always expected to be
researched away, and a 90% optimum over an 85% floor is not something a player can feel.

At entry confinement the mechanic survives all five rungs, the optimum walking 65% → 90% and the
floor 35% → 80%.

### ADR 0024's own figures stand

This is the consequence most likely to be got wrong. Because the ladders are **independent**, a
player who researches confinement alone still runs at 50 MW, so ADR 0024's table — Q 0.320 / 0.578 /
0.950 / 1.467, and break-even arriving at rung 3 — is correct exactly as written. What it needs is a
note that a second ladder now shares its axis and that its break-even claim holds **at base heating**.

Had the ladders been combined, that column would have become 0.320 / 0.714 / 1.323 / 1.951 with
break-even at rung 2. They are not, and it does not.

### The clamp is not reached, and needs no guard

ADR 0024 bounded its own ladder partly to keep the plasma off `max_temperature_c`. That reasoning
does not transfer. D-T is ignited, so alpha heating and the cross-section roll-off set its
temperature rather than the heating power: at the top of both ladders it settles at 3.991×10⁹ °C,
**79.8% of the 5×10⁹ clamp**, against 78.4% today. D-D reaches 1.18×10⁹. No guard is needed for
this ladder.

### `control.lua`'s density-curve cache key must gain heating power

`reactor-logic.density_curve`'s answer is cached under the confinement time it was swept at. With a
second per-force lever on the same curve, that key no longer identifies the state, and a force that
researches heating would read a stale optimum. **This is real code work and it belongs to #293.**
It is also the one cost the combined-ladder option would not have carried.

### What #294 gates

**The fully-researched state — top of both ladders — against a ceiling of 15.** Intermediate states
are deliberately unbounded: top-confinement-only is 18.50 and is a legitimate build, so a gate
asserting the ceiling at any researched state would fail on it. The entry state stays reported and
ungated.

### Figures this falsifies, for #293 to re-anchor

**Nothing here is struck yet.** On the day this ADR is signed every figure below is still true —
nothing has been retuned. #293 strikes each as it re-anchors it, per this repository's habit.

**Worked 2026-09-19 by #425 and #426, and the word "falsifies" turned out to be too strong for
every one of them.** Not one figure on this list came out differently; what each needed was the
research state it was measured at, because the ladder starts where the reactor already was
(decision 3). So each is marked EXTENDED rather than struck, and the entry state is republished
unchanged beside the researched one.

- **ADR 0015** — the ~56 MW whole-line table. **Extended**: unchanged as the unresearched figure,
  with the other five rungs published beside it as one series, 61 / 66 / 71 / 76 / 81 MW. The Q
  0.613 / 102.9 MW / 0.968-at-180-MW predictions all reproduced.
- **ADR 0016** — the mechanic's survival at the top of the tree. **Confirmed, and it closes**, at
  the first heating rung, exactly as predicted; 90%/85% worth 76.53 MW against 73.37 at τ 60 and
  50 MW, full supply and no floor at 55 MW, and the 65% → 90% walk surviving at entry confinement.
- **ADR 0024** — the break-even-at-rung-3 claim. **Confirmed**: it holds at base heating exactly as
  written, and at 75 MW break-even arrives at rung 1 with Q 1.0495 tuned and full alike.
- **`docs/research/d-t-ignition.md`** — **extended**: the confinement table is now visibly the
  50 MW row of a 6×4 grid, and both supply-ratio readings carry their corners.
- **`CONTEXT.md`** — **extended**: the **supply ratio** entry publishes both corners, and the
  **operating point** entry gains the rule that a figure naming no research state is the
  unresearched one.
- **`realistic-fusion-refreshed/prototypes/entities.lua`** — the aneutronic 9:1 comment.
  **Qualified, not moved.** The tank is still sized on the entry ratio, deliberately, and the
  aneutronic tier is still untouched: what research moves is the D-D breeder feeding it.
- **`realistic-fusion-refreshed/prototypes/recipes/d-t.lua`** — **qualified**. The recipe's own
  rate is not what moved; a heater makes 2.5 u/s whatever a force has researched.
- **`tests/test-reactor-logic.lua`** — **extended**: the supply-ratio block pins all twenty-four
  cells, both monotonicities, and each row's megawatt label against the shipped ladder.

### Work this spawns

- **#291** narrows: commit a rig reproducing this ladder, keep the three backwards levers as rows,
  drop the rest to a paragraph.
- **#293** implements the ladder, re-anchors the list above, and fixes the cache key.
- **#294** gates the fully-researched state at a ceiling of 15.
- **`rf-hc-heater`** — a high-capacity heater, [#420](https://github.com/trulsjo/realistic-fusion-refreshed/issues/420). A settled D-T reactor eats 10.4
  heaters and Truls would prefer one. That is a machine-count problem, not a fuel-chain one: a
  bigger heater changes no fuel demand and would make the per-heater reading read 94.7 instead of
  9.1. Split off precisely so the two are not confused.
- **An over-supply mechanic** — [#421](https://github.com/trulsjo/realistic-fusion-refreshed/issues/421). A D-T reactor saturates at 34 u/s and simply stops
  taking more, so a second heater past saturation is wasted throughput rather than an interesting
  choice. Raised here and deferred.
- **The aneutronic tier's ratio** — [#422](https://github.com/trulsjo/realistic-fusion-refreshed/issues/422), per decision 5.
- **Tech-tree legibility** — eight research steps now sit on one reactor. Worth its own look, and
  not a reason to cut rungs.

# What a lithium blanket releases per neutron

Researched 2026-09-08 for [#91](https://github.com/trulsjo/realistic-fusion-refreshed/issues/91),
which gates [ADR 0019](../adr/0019-the-blanket-sells-its-capture-heat.md)'s implementation the way
[#51](https://github.com/trulsjo/realistic-fusion-refreshed/issues/51) gated
[#52](https://github.com/trulsjo/realistic-fusion-refreshed/issues/52). No code and no map: the
figure below is nuclear arithmetic against published masses, and nothing in the mod was changed to
produce it.

**The arithmetic is checked in as `tests/test-blanket-energy.lua`** and every number in this note is
asserted there. Run `lua tests/test-blanket-energy.lua` to reproduce them rather than taking them on
trust.

**Nothing runs it for you.** There is no CI in this repository and no `scripts/*.ps1` invokes the Lua
tests, so moving `M.blanket.tritium_per_neutron` invalidates this note silently unless whoever moves
it types that command. The check exists and is not wired; the same is true of
`tests/test-bremsstrahlung.lua`, which says so in the same words.

## The answer

**4.537 MeV per neutron entering the blanket**, net, at the shipped `tritium_per_neutron = 1.1` — or
**4.124 MeV per triton bred**, which is the form an implementation wants, because breeding is what
gets throttled and heat follows breeding (ADR 0019, decision 2).

**It excludes the neutron's kinetic energy**, all 14.06 MeV of it on the D-T tier. `step()` already
sells that: `captured_j = ((fusion_j - charged_j) + left_j) * capture_efficiency`, and
`fusion_j - charged_j` **is** the neutron. The figure here is the nuclear Q of the capture reactions
and nothing else. See [the trap](#the-trap-a-published-m-factor-is-not-this-number).

It is a **ceiling for a lithium-only blanket** rather than a plant figure, for the reason
[the cross-check](#cross-check-against-published-blankets) gives — and provisional, like every other
balance number in this repository.

## The two reactions, and their Q values

`reactor-logic.lua` already writes them down, at `M.blanket`:

    n + Li-6  -> T + He4        + 4.78 MeV   exothermic, and the reaction that does the work
    n + Li-7  -> T + He4 + n'   - 2.47 MeV   endothermic, and hands the neutron back on

Both Q values are differences of ground-state masses, so they can be computed rather than quoted.
From **AME2020** mass excesses, in keV:

| nuclide | mass excess Δ (keV) |
|---|---|
| n | 8071.31806 |
| ³H (T) | 14949.81090 |
| ⁴He | 2424.91587 |
| ⁶Li | 14086.88044 |
| ⁷Li | 14907.10463 |

`Q = Σ Δ(reactants) − Σ Δ(products)`:

    Q6 = (14086.88044 + 8071.31806) - (14949.81090 + 2424.91587)
       =  22158.19850 - 17374.72677  =  +4783.472 keV  =  +4.78347 MeV

    Q7 = (14907.10463 + 8071.31806) - (14949.81090 + 2424.91587 + 8071.31806)
       =  22978.42269 - 25446.04483  =  -2467.622 keV  =  -2.46762 MeV

**Atomic mass excesses are used directly and no electron correction is needed**, because the electron
count balances in both reactions: lithium's three electrons are exactly tritium's one plus helium's
two. That is worth stating rather than glossing, since it is the step that silently poisons this kind
of arithmetic when it does not hold.

**⁷Li's reaction has a threshold, and it is not 2.468 MeV.** A Q value is the energy released at rest;
a neutron hitting a stationary nucleus must also supply the recoil, so the lab-frame threshold is
`|Q| × (m_target + m_n) / m_target`:

    2.46762 x (7.016003 + 1.008665) / 7.016003  =  2.822 MeV

That number is what makes [question 2](#question-2-does-it-depend-on-the-neutrons-energy) have an
answer at all.

## Fixing the blend from the breeding ratio

`tritium_per_neutron = 1.1` is a single blended figure and the shipped model "does not know how many
of its captures ran on Li-6 and how many on Li-7". It does not have to be told. **The neutron balance
fixes the split**, given the ratio:

- A ⁶Li capture **destroys** the neutron. It is a sink.
- A ⁷Li reaction **hands the neutron back**. One in, one out: it makes a triton and consumes no
  neutron.

So in a blanket that leaks nothing and has nothing but lithium to absorb into, **every neutron ends
its life in a ⁶Li capture — exactly one, no more and no fewer.** Write x for ⁶Li captures per incident
neutron and y for ⁷Li reactions per incident neutron:

    x = 1                    every neutron is absorbed, and Li-6 is the only absorber
    x + y = 1.1              both reactions make one triton, and the ratio counts tritons
    => y = 0.1

Which is what "above one because a blanket multiplies neutrons before it captures them" means when
the multiplier is lithium itself: ⁷Li does not add neutrons, it adds a **free triton** to a neutron
that goes on to be captured anyway. The energy then follows:

    E_net = 1 x (+4.78347) + 0.1 x (-2.46762)  =  4.78347 - 0.24676  =  4.53671 MeV per neutron
    E_net / 1.1                                =  4.12428 MeV per triton bred

**4.78 MeV is the ceiling and 4.54 MeV is the answer** — the endothermic branch costs 5.2% of it, and
costs exactly that much because the ratio is 1.1 and for no other reason.

**The two constants therefore cannot be stored independently.** A later balance pass moving
`tritium_per_neutron` moves this figure with it:

    E_net(TBR) = Q6 - (TBR - 1) x |Q7|
               = 4.78347 - (TBR - 1) x 2.46762   MeV per neutron

| TBR | net MeV per neutron | net MeV per triton |
|---|---|---|
| 1.00 | 4.7835 | 4.7835 |
| **1.10** | **4.5367** | **4.1243** |
| 1.15 | 4.4133 | 3.8377 |
| 1.30 | 4.0432 | 3.1102 |

## The trap: a published M factor is not this number

Blanket literature quotes an **energy multiplication factor** M — total thermal power raised in the
blanket, divided by the fusion neutron power entering it — and commonly puts it at 1.1 to 1.3. **That
figure already contains the neutron's kinetic energy**, which this mod sells separately, at
`step()`'s `fusion_j - charged_j`. Two ways to get it wrong, and they fail differently:

| what gets added as blanket heat | per D-T neutron | wrong by |
|---|---|---|
| `M x E_n`, at M = 1.2 | 16.87 MeV | **3.7x too high** — the neutron is sold twice |
| `(M - 1) x E_n`, at M = 1.2 | 2.81 MeV | 38% too low, and for the reason below |

The first is the silent inflation #91 was opened about: it reads as a published number, it lands in
the same box the neutron's own energy lands in, and it more than doubles a D-T reactor's sold output.
The second is arithmetically the right way to strip the kinetic energy out of an M, and it still does
not give this model's figure, because a published M is measured on a blanket this model does not have
— see below.

**So neither is used here.** The figure is derived from the capture Q values and the shipped breeding
ratio, and it is not imported.

## Cross-check against published blankets

Turn the derived figure back into an M and compare, which is the honest direction to use the
literature in:

    M_implied = (14.06 + 4.5367) / 14.06 = 1.323

That sits **just above** the published 1.1–1.3 band, and the direction is a check rather than an
embarrassment. A real blanket loses neutrons this one does not:

- **Parasitic absorption and leakage.** Steel structure, coolant and manifolds capture neutrons that
  then breed nothing. Every such capture cuts ⁶Li captures below one per neutron, which is the term
  this derivation sets to exactly 1.
- **The multipliers that buy the ratio back cost energy.** Real designs reach TBR > 1 with beryllium
  or lead rather than with ⁷Li, and `⁹Be(n,2n)2⁴He` is endothermic at **−1.573 MeV** — computed from
  the same table, Δ(⁹Be) = 11348.451 keV. A ratio bought that way is bought out of the heat.
- The offsetting term runs the other way and is smaller: `(n,γ)` capture on structure releases several
  MeV of gammas, which a real plant's M includes and a lithium-only model has no material for.

So **4.54 MeV per neutron is the ceiling of an idealised lithium blanket**, and a real one lands
below it. The model has no structure, so the ceiling is the figure it should use; a later pass wanting
realism has a stated direction to move in and a reason.

## Question 1: blended constant, or a modelled Li-6/Li-7 split?

**A single blended constant, derived rather than stored.** #91 asks whether the split "must be
modelled to state a net figure honestly", and the answer is that stating it honestly is exactly what
the section above does — on paper, once, with the neutron balance shown. Nothing in `breed()` needs a
second path, because the split has no observable consequence the blend does not already carry: the
two branches differ in sign but produce the same product in the same place, and the ratio of them is
pinned by a number the model already stores.

**But it must not be a second independent field.** `E_net` and `tritium_per_neutron` are one fact
written two ways, and this file already argues the case in `M.electrons`: storing what can be derived
"would let them contradict it, and a plasma whose declared electron count disagrees with its declared
composition is a bug nothing would catch". The same applies here — a blanket declaring 4.537 MeV
beside a ratio of 1.3 is silently wrong in the direction that pays the player.

So the recommended shape for [#93](https://github.com/trulsjo/realistic-fusion-refreshed/issues/93):

- **`M.blanket` stores the two Q values**, `li6_capture_ev = 4.78347e6` and
  `li7_breeding_ev = -2.46762e6`, which are measured physical constants and not balance numbers.
- **The joules are computed from them and the ratio**, per triton actually bred, so a
  charge-limited or headroom-limited blanket sells heat in proportion to what it bred and no rule is
  needed to make that so.
- **`tritium_per_neutron` stays the one balance lever**, and moving it moves the heat correctly and
  by itself.

That is one function, not a field and not a branch.

## Question 2: does it depend on the neutron's energy?

**Yes, and it is worth recording rather than modelling — for now.** The ⁷Li branch has a 2.822 MeV
lab threshold, and the two tiers fall on opposite sides of it:

| tier | neutron energy | above the 2.822 MeV threshold? | physical TBR | net MeV per neutron |
|---|---|---|---|---|
| D-T | 14.06 MeV | yes | ~1.1 | 4.537 |
| D-D | 2.45 MeV | **no** | ~1.0 | 4.783 |

`reactor-logic.lua` already records the breeding half of this as an accepted omission: D-D's neutrons
"are not and do not" multiply, so "a D-D blanket should therefore breed nearer 0.9 than 1.1". #91 asks
whether the energy is an omission too. **It is, and it is a smaller one, and it runs the other way.**

- The shipped blend charges D-D **4.537** where physics says **4.783** — 5.2% low.
- The same blend credits D-D with a TBR of **1.1** where physics says about **1.0** — 10% high, and
  that error is already in the mod, already documented, and larger.

Two things follow. First, **the energy omission is dominated by the breeding omission it rides on**,
so fixing the energy alone would be picking the smaller of two errors while leaving the larger. When
a per-fuel ratio arrives — `reactor-logic.lua` says it is "a row in `M.fuels`, not a rewrite" — the
energy comes with it for free, because the formula above takes TBR as its argument. Second, and this
is the finding worth having: **the two errors partly cancel in the sold energy.** A D-D blanket at
TBR 1.1 sells 1.1 × 4.124 = 4.537 MeV per neutron where the physical one sells 1.0 × 4.783 = 4.783 —
5.2% low overall, not 15% out. The blend is a better approximation for heat than it is for tritium.

**Recommendation: not neutron-energy-dependent, stated as an inherited omission rather than an
accepted one.** It is inherited because it is one consequence of the single blended ratio, and it
stops being a separate question the moment that ratio becomes per-fuel.

## What is anchored to what

#91 asks that any figure resting on the pre-#52 equilibrium be labelled. Sorting them:

- **The per-neutron and per-triton figures are nuclear physics.** They rest on mass excesses and on
  `tritium_per_neutron`. Neither #52 nor any balance pass on the plasma side moves them, and the
  radiation term does not enter.
- **The per-reaction addition is also basis-free**, being the figure above times
  `neutrons_per_reaction`: **4.537 MeV** on D-T and **2.268 MeV** on D-D.
- **Every ratio against a reactor's output is anchored**, and those are the numbers to distrust.
  ADR 0019's table quotes +27% for D-T and +65% for D-D against each tier's own **total release**
  (17.59 and 3.65 MeV). Recomputed with 4.537 rather than the 4.78 ceiling that table used: **+25.8%
  and +62.1%**. Those correct the ceiling, and they still are not the number a player sees, because
  a reactor does not sell its total release — `captured_j` is `((fusion_j - charged_j) + left_j)`
  crossing `capture_efficiency`, and `left_j` is an equilibrium quantity. **The share a player reads
  off `rf-signal-blanket-share` has to be measured once #93 lands, not derived here.**

## The runnable check

`tests/test-blanket-energy.lua`, in the shape `tests/test-bremsstrahlung.lua` established: run
outside Factorio, Lua 5.2 semantics, no framework. It asserts

- both Q values, from the AME2020 mass excesses in the table above, to 1e-6 relative;
- the ⁷Li lab threshold, and that D-D's 2.45 MeV neutrons fall below it while D-T's 14.06 MeV ones do
  not;
- the neutron balance — one ⁶Li capture per incident neutron, `TBR - 1` ⁷Li reactions — and the net
  figures it gives, **read against `M.blanket.tritium_per_neutron` as the shipped module holds it**,
  so moving the ratio without revisiting this note fails the suite;
- the `E_net(TBR)` formula against the table above, including that it returns the 4.78347 ceiling at
  TBR = 1.0;
- the double-count trap as arithmetic: that `M x E_n` at M = 1.2 is 3.7x the derived figure, which is
  what a wrong import would cost.

It does **not** assert anything about `breed()`, which returns no joules yet. That is #93's, and this
suite is what #93's implementation gets checked against.

## Sources

- **AME2020 mass excesses** — M. Wang, W. J. Huang, F. G. Kondev, G. Audi, S. Naimi, "The AME 2020
  atomic mass evaluation (II). Tables, graphs and references", *Chinese Physics C* **45** (2021)
  030003. Values taken from the evaluation's own `mass_1.mas20.txt` (unrounded), IAEA Atomic Mass
  Data Center: <https://www-nds.iaea.org/amdc/ame2020/mass_1.mas20.txt>
- **The reaction pair and the breeding ratio band** — `realistic-fusion-refreshed/scripts/reactor-logic.lua`,
  `M.blanket`, which carries both reactions and the 1.05–1.15 design band this note's 1.1 sits in the
  middle of.
- **Where the neutron's kinetic energy is already sold** — the same file, `M.step()`, at
  `captured_j = ((fusion_j - charged_j) + left_j) * spec.capture_efficiency`.
- **The decision this figure is for** — [ADR 0019](../adr/0019-the-blanket-sells-its-capture-heat.md),
  which states the double-counting hazard and defers the figure to this note.

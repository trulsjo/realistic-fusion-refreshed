# 37. A benchmark figure is the pooled mean over surviving runs

Date: 2026-09-17

## Status

Accepted. Decided by Truls, 2026-09-17, settling
[#326](https://github.com/trulsjo/realistic-fusion-refreshed/issues/326) on the investigation
[#235](https://github.com/trulsjo/realistic-fusion-refreshed/issues/235) closed. Supersedes nothing
and reverses nothing: on a sitting where no run stalled, this decision and the behaviour it replaces
compute the identical number.

Unblocks [#327](https://github.com/trulsjo/realistic-fusion-refreshed/issues/327), which re-takes
the figures the census walk inflated and reports them in the statistic this ADR names. It does not
touch ADR 0005's numbers; #327 owns those.

`docs/research/borrowed-base.md` holds the argument and the measurements this rests on. This ADR
holds the choice.

## Context

Every per-reactor figure this project publishes comes out of `scripts/bench-reactors.ps1`, which
runs Factorio's own `--benchmark` several times per count and reports one **pooled mean** — every
tick of every run, averaged together.

#235 spent three sittings on what looked like a per-tick cost belonging to the borrowed base:
about **+500 µs a tick in roughly one run in four**, constant at *n* = 0, 50 and 200. It is not
that. It is a handful of multi-hundred-millisecond stalls on the harness's own `log()` write —
measured 2026-09-13, one run of twenty at `script mean` 662.6 µs against nineteen at 90.3–99.3,
whose excess was **six ticks of a thousand**, one of them **389.3 ms**. That run's median tick was
**11.60 µs against 11.70 µs** for the clean runs.

So a pooled mean divides four tenths of a second of file system across a thousand ticks and reports
it as +389 µs of per-tick cost, and no median can see it at all. Three sittings measured a real
thing and described it in the one unit that makes it unrecognisable.

#235's fourth acceptance criterion therefore asked for a recommendation on the statistic, and named
two candidates: keep the pooled mean and raise `-Runs`, or report a **median across runs**. Under
`CLAUDE.md` the choice between them is Truls's, which is what #326 exists for.

**Neither candidate is right, and the reason is the same for both.** The thing being averaged is
not a cost. A median across runs drops the poisoned run and gets the right number for the wrong
reason — it would still be wrong the moment two runs in five stall, and it would have *hidden*
what the investigation actually found, because the census walk cost 2.18 µs per reactor in **every**
run and a statistic chosen to drop outliers leaves that exactly where it is. A pooled mean over
everything reports the stall as cost.

What changed between #235's recommendation and this decision is that the run can now be **named**.
`Find-StalledRuns` flags a run carrying a tick that is both over 50 ms and at least 20× the same
tick index in every other run — reproducible work is not a stall however large it is, which is why
the rig's own 108 ms tick at `t = 30` of every run is correctly ignored. Once the bad run has a
name, discarding it stops being a statistic and becomes a fact about the sitting.

## Decision

**A figure `bench-reactors.ps1` reports is the pooled mean over surviving runs: every tick of every
run the machine did not block in.**

1. **The discard happens before the pool, not after it.** `Select-SurvivingSamples` removes a
   stalled run's ticks from the samples; `New-TimingRow` then computes both statistics, in every
   column, over what is left. The row is the sitting minus its stalled runs, rather than two
   different populations depending on which number a reader takes.
2. **"Pooled mean" keeps its name.** A figure is *the pooled mean over N surviving runs*, with N
   written out rather than left to be assumed from `-Runs`. **Stalled run** is the new term and is
   the thing removed; it is in `CONTEXT.md`. No second name for the statistic, because inventing
   one would make every figure already published ambiguous about which one it was.
3. **Per row, not per sweep.** A stall in run 3 at *n* = 200 does not remove run 3 at *n* = 0. The
   runs are separate processes with the map reloaded between them and share nothing but an index,
   so dropping a clean run buys a symmetry that means nothing and throws away good data. The
   surviving count is printed per row, so the footing of the subtraction is visible.
4. **It applies to every map this harness measures, rig and borrowed base alike.** A stall is a
   property of the machine, not of the map. Two statistics for two maps would mean
   `reactor-runtime-cost.md` comparing a rig control against a borrowed-base figure computed
   differently — the apples-to-apples problem that note has already been caught on once.
5. **Below two surviving runs a count refuses rather than reports.** A mean over one surviving run
   has no peer left to judge it against, and printing it is the quiet pass this whole mechanism
   exists to stop. `-Runs 1` is not that case: nothing was discarded, `Find-StalledRuns` cannot
   decide with no peer and reports nothing, so a single run asked for is left alone. Two surviving
   runs is the floor and warns.
6. **The refusal takes the count, not the sitting.** `Get-SurvivingRunsRefusal` returns the reason
   rather than throwing it. The refused count contributes no row — it is in no table and in no
   subtraction — the sweep carries on and measures the rest, the tables print, and only then is
   the fault raised. A sweep runs for tens of minutes, so a throw at the last count would destroy
   every count before it. This is not a new rule: it is the one the `$missingBaseline` note
   already states in `bench-reactors.ps1`, *"the absolute figures are worth having even when no
   per-reactor figure can be computed from them"*, applied to a second fault of the same shape.
7. **`-Runs` defaults to 5, raised from 3.** Three is too thin to lose one from, and two of three
   runs stalling at one index is the case the detector had to be rewritten for. Nothing invokes
   this script automatically — no gate, no CI — so the cost is minutes in a hand-run sitting.
8. **The evidence stays on the page.** The per-run line prints **every** run, discarded ones
   included, and the report names the excluded run, its tick, its cost, and what the row would have
   said had all runs been pooled. A figure that changes without its evidence changing is not
   checkable.

## Consequences

**No published figure changes meaning.** Where nothing stalled, this is arithmetically the same
pooled mean as before — which is the whole reason it was chosen over the median across runs, whose
adoption would have re-dated every number in `reactor-runtime-cost.md`. #235's own fourth sitting
measured what that would have cost: with a clean baseline the two agree to **0.3%** at *n* = 200,
6.99 µs median-across-runs against 7.01 pooled mean, so the change would have bought nothing and
invalidated the record.

**Figures taken before `Find-StalledRuns` existed (2026-09-13) are not re-audited, and the condition
for trusting one is stated rather than left to judgement.** A figure whose per-run spread was
recorded and tight has no room for a stall inside it, and a 389 ms tick cannot hide in that. The
spread to compare against is
[#235](https://github.com/trulsjo/realistic-fusion-refreshed/issues/235)'s own rig rows, five runs each, measured beside the
borrowed base in the same sitting: **1.08× at *n* = 0** (38.0 to 36.3 µs), **1.08× at *n* = 50**
(350.2 to 324.1), **1.09× at *n* = 200** (1,312.9 to 1,204.6). A figure quoted **without** its
per-run line is unverifiable, and is re-taken only if something turns on it. The 2026-09-06 sitting
is being re-taken anyway, under #327 and for a different reason.

**A count can now report nothing, and the sitting survives it.** A count that loses four of five
runs produces no row and says so. That is deliberate — it is the same shape as the rig refusing to
build over a surface it did not create, and as the refusal to report a mixed figure when the four
reactions are not all present. What it is **not** is a failed sitting: every other count still
reports, the tables still print, and the fault arrives after them.

**`-SelfTest` grows a seventh half**, covering four directions: a stalled run's ticks leave the
pool and the surviving mean is the clean one; a sitting with nothing to discard comes back
untouched; a row reduced to one surviving run is refused while two is allowed; and the refusal is
returned rather than thrown. The second is the load-bearing one — if the filter ever trimmed a
clean sitting, every figure in `reactor-runtime-cost.md` would silently stop meaning what it says.
The fourth exists because a regression to throwing would pass every other check in the file and
cost a caller a sweep.

**What is not fixed.** *Why* the file system blocks for 389 ms — antivirus, a flush, disk contention
— is outside this project and was not chased. And the write hypothesis predicts the stall rate
should be highest at `-ReportEvery 1`, where a run makes a thousand writes; a sitting there produced
no clean stall in seven usable runs. Seven runs of a one-in-twenty event settles nothing either way.
This decision does not depend on the cause being known: it depends on the run being identifiable,
which it is.

## Alternatives considered

**A median across runs**, #326's second option. Rejected on three grounds, in order of weight. It
would have hidden #235's actual finding, a fixed per-run cost present in every run. It changes what
every figure in `reactor-runtime-cost.md` means for a 0.3% difference where it was measured. And it
is a blunter instrument than naming the bad run: it drops the largest run whether or not that run
stalled, and stops working the moment two runs in five do.

**The pooled mean over all runs, unchanged**, #326's first option and the status quo. Rejected
because it reports a stall as cost. The recommendation that carried it — *run more repeats, read the
per-run line, discard by hand* — is a procedure a tired reader skips, and it leaves the printed
figure wrong in the meantime.

**Flagging without discarding**, which is what the harness did between 2026-09-13 and this decision:
`Find-StalledRuns` warned and the row still pooled the stalled run. Rejected as the #235 failure one
step later. The warning is right and the number beside it is wrong, and the number is what gets
quoted.

**Discarding the run index across the whole sweep** rather than per row. Rejected: it throws away
clean runs at every other count to keep the run counts equal, and equality of run counts is not
something any figure here depends on.

Note that the **median across ticks** is a different statistic from either candidate and is not
touched. It is already immune to a stall — run 6's was 11.60 µs — and it is not what a per-reactor
figure is taken from, because the simulation steps one tick in six and a median tick contains no
simulation work at all.

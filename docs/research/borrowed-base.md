# The borrowed base — what it is, where it came from, and what may be done with it

ADR 0005 obliges this project to measure UPS on a real factory at scale. Every measurement to date is
a rig: flat ground, power, reactors, no belts, no trains, no biters, one surface. [#65][65] is the
ticket for getting something to measure instead, and this note is its provenance record.

It is deliberately separate from [`reactor-runtime-cost.md`](reactor-runtime-cost.md), which carries
the numbers and the method. The two get read by different people for different reasons, and the
licensing position of a third-party save should not be a subsection of a performance document.

## What it is

**The borrowed base** is TimEv's *Modular 10k SPM Vanilla 2.0 Megabase*:

| | |
|---|---|
| Author | **TimEv** (Factorio forum user 181632) |
| Video | <https://www.youtube.com/watch?v=ilSdsVTW2u0> |
| Forum thread | <https://forums.factorio.com/viewtopic.php?t=129332> |
| Advertised as | "2.0.43 base game, no mods", 10k SPM at 60 UPS |
| Obtained | 2026-08-20, from the save link in the video's description |
| On this machine | `C:\src\factorio\_reference\Megabase in 2.0.zip`, 167,320,199 bytes |
| Stated licence or terms | **none, anywhere** |

The file's own header says **`base 2.0.7`**, not 2.0.43, and no other mod. Read with
`Get-SaveModList` out of `scripts/bench-reactors.ps1`, which reads `base 2.0.77` correctly from two
saves of known provenance on the same machine — so the parser is right and the file is an older-version
save than the thread advertises. Nothing turns on it for the measurement: Factorio migrates it, and the
sweep loads the identical file at every count. It does mean the download link cannot be relied on to
serve the same bytes twice, which is why the reproducibility position below is what it is.

**Measured, not assumed: it is genuinely loaded.** About **10.7 ms a tick, roughly 64% of the
16.67 ms budget** — median over 5,000 ticks on a quiet machine, with the benchmark's own power grid
present and no reactors. That is the premise #65 rests on, and it was an assumption until it was
checked. **Confirmed again 2026-09-06** by [#67][67]'s own sweep: 10.81 ms, median over 9,000 ticks
across nine quiet runs, against a rig control's 0.27 ms in the same sitting — an engine **40×**
busier. That is the same claim as the 51× below and not a second one: the borrowed base agrees to
1.01×, and the whole of the difference is the rig's own empty tick moving 0.21 ms to 0.27, which is
inside the 1.35× floor. **The ratio is not the figure to quote; the two tick lengths are.**

> **Corrected 2026-09-04. This said "about 14 ms a tick, roughly 84%", and that figure is
> withdrawn.** It came from the 20-tick probe quoted below, which established the mechanism and was
> never meant to be a measurement: 279.858 ms over 20 ticks, taken while the machine was at 60–70%
> in other hands. The tick was not that long; the machine was busy. The 10.7 ms above replaces it —
> 500× the samples, no `BUSY` at any launch, and the rig measured beside it in the same sitting as a
> control. The conclusion is unchanged and the premise holds — and the comparison that makes it
> concrete is the rig measured beside it at the same count: **10.73 ms against 0.21 ms, an engine
> 51× busier.** That is the gap #34 could not measure across and #65 exists to close.

## What may be done with it

**Nothing in the video, the description or the forum thread grants redistribution.** Checked
2026-09-03; the post states no licence, no permission and no terms of any kind.

- **Using it locally is not redistribution and needs no grant.** Benchmarking somebody's published
  save on your own machine is ordinary use of a published file.
- **It is never redistributed**, and neither is anything derived from it. A megabase with our reactors
  in it is a derivative of TimEv's work, so a *planted save* could not be shipped either — which is one
  of the reasons no planted save exists (see below).
- **It is not in this repository and cannot be.** 167 MB against GitHub's 100 MB per-file limit, for
  scale against a 20 MiB pack. Git LFS was rejected: it changes how everyone clones this repository,
  for one binary.
- **Attribute TimEv** wherever a figure taken on it is quoted. Not a licence obligation — the same
  community norm this repository applies to Romner_set, Durikkan and PreLeyZero.

This is the [ADR 0001][adr1] question asked of a save rather than of a sprite, and the answer has the
same shape as the predecessors' unmarked `graphics/`: **silence is not a permissive donation.** The
difference is that a benchmark input never ships, so local use is available where lifting a sprite
would not be.

## How it is measured

Not by writing a planted save. `Factorio.exe --help` on 2.0.77 offers no save-writing mode but
`--create` and `--start-server`, so a written save would have meant a multiplayer server run plus
`game.server_save`. Instead:

**`scripts/bench-reactors.ps1 -PlantInto <save>`** builds the rig on a surface of its own inside the
borrowed base, as `on_init` runs when the rig mod is added to it. Measured on 2.0.77 before the mode
was written: a newly added mod's `on_init` **does** run under `--benchmark`, and the surface and
entities it creates are present for the ticked run.

```
16.636 Loading map C:\src\factorio\_reference\Megabase in 2.0.zip: 167320199 bytes.
58.083 Script @__rf-oninit-probe__/control.lua:6: PROBE on_init RAN surfaces=2 entity=true tick=757640904
58.339 Script @__rf-oninit-probe__/control.lua:10: PROBE tick=757640905 surface=true subs=1
Performed 20 updates in 279.858 ms
```

That probe established the **mechanism** and nothing else. Its 20-tick timing is not a measurement of
anything — see the correction above — and it is quoted here only for the three lines before it.

Three consequences, and the first is the reason the mode exists.

**It buys back the slope.** `-Save` can report no per-reactor cost, because every per-reactor figure
here is `(cost at n − cost at 0) / n` and a factory cannot be un-built. These reactors were never in
the save, so `n = 0` is the same save swept at count zero — the same factory, the same tick, the
same mods, the same planted surface generated and powered — and the difference is reactors and nothing
else. That is [#67][67]'s second acceptance criterion satisfied by subtraction rather than by argument.

**It writes nothing.** `--benchmark` never saves, so the planted surface dies with each process and
the borrowed base is untouched on disk. No derivative exists to redistribute by accident.

**The reactors are not on the base's power.** 200 `rf-reactor`s draw about 10 GW of heating and the
planted fleet adds no generation, so wiring them into TimEv's grid would brown out the whole factory —
every consumer is `secondary-input` and takes the same fraction, so the base would stop and the report
would look fine. Each cell keeps its own substation and interface on an island connected to nothing,
exactly as the rig builds them.

### The objection, stated rather than left to be raised

The reactors sit on a surface of their own, so they are not *in* the factory. Someone will say that is
not what "measured on a real base" means.

The answer is that Factorio's update is global: the engine spends the same busy tick whichever surface
our entities are on, and what #67 asks is what the simulation costs when the engine is already busy —
not what a fusion plant is worth plumbed into a working factory. The alternative was a corner of
Nauvis, which needs a search for space no recipe can guarantee and risks bulldozing TimEv's work. A
dedicated surface is the option where a failure is loud instead of silent, and the guard that makes it
so is poison-tested: aimed at a surface the save already has, the rig refuses rather than building over
it.

```
__rf-bench-rig__/control.lua:242: this save already has a surface called 'nauvis'; the rig will not
build over one it did not create, because it landfills and clears everything in its area
```

### What it does not establish

> **Every figure below — the whole-tick range, and the median and mean pair — came off the BUSY
> proving run, and none of them is quotable.** Added 2026-09-04, after a code review caught that the
> commit which published them says
> in its own body that it does not: *"FIGURES ARE DELIBERATELY NOT PUBLISHED. The proving run was
> BUSY at 60–70% on both the baseline and the top count, so nothing from it is quotable."* They are
> left in place rather than replaced because they illustrate rules that hold independently of their
> values, and because this project keeps superseded readings on the record with a note rather than
> quietly restating them — ADR 0005 does the same for every figure #34 and #39 revised.
>
> **There is no single factor to divide them by**, and that is the second reason not to read a value
> off this section. Against the quiet re-take the whole tick moves by about 1.3× and the per-reactor
> `scriptUpdate` by about 1.5×, so the inflation is column-dependent. The mean pair does not move in
> that direction at all: its *baseline* is higher on the quiet machine, because the borrowed base's
> own Lua spikes in roughly one run in four whatever the load — which is [#235][235], and is why a
> busy reading here is not simply a quiet one scaled up. (**That spike is identified as of
> 2026-09-13** and it is not "the borrowed base's own Lua": it is an I/O stall on the harness's own
> `log()` write. The reason a busy reading is not a scaled quiet one stands; see the foot of this
> note.)
>
> What the caveat does reconcile is the contradiction a reader would otherwise hit: "between 12 and
> 16 ms" below against the **10.7 ms** this note's own premise records. Same map, same statistic; the
> first was taken while the part was in other hands. The quiet figures belong to [#67][67], which
> owns the verdict — **taken 2026-09-06 and recorded in
> [`reactor-runtime-cost.md`](reactor-runtime-cost.md)**, along with the verdict itself.

- **The absolute figures are not ours.** `wholeUpdate` and `scriptUpdate` on a borrowed base are mostly
  the borrowed base. Only the *difference* is attributable — the reverse of `-Save`, where the absolute
  cost is the answer and no per-reactor figure exists.
- **The engine columns will not resolve a small fleet.** The whole tick measured between 12 and 16 ms
  across five counts, and varies by a few percent between runs — so `wholeUpdate`, `entityUpdate` and
  `electricNetworkUpdate` can come out *lower* with reactors than without, and did.
  `scriptUpdate` is the column that isolates.
- **Read `scriptUpdate`'s MEAN, not its median, and that is a stronger rule here than on a rig.** The
  simulation steps one tick in six (`UPDATE_INTERVAL`), so a median tick contains no simulation work at
  all: measured on the borrowed base, the median went 4.40 µs at n = 0 to 4.90 µs at n = 50, which is
  the cadence and not the cost. The mean over the same pair moved 132 µs to 711 µs. On a rig both
  statistics are worth reporting and `bench-reactors.ps1` prints both; on a borrowed base the median is
  the *factory's* typical tick with our cadence hidden inside it, and quoting a per-reactor figure from
  it would understate the cost by roughly the interval. Treat anything finer than the 1.4× floor
  `reactor-runtime-cost.md` records as unmeasured either way.

  **The rule above is about the median of TICKS. A median across RUNS is a separate question** —
  and the pooled mean this note tells you to read is the statistic one bad run of five can move by
  20%. Until that is settled, **run more repeats rather than fewer**, and do not quote a figure
  from a count whose per-run spread is wide.

  > **Settled 2026-09-17 — [ADR 0037][adr37].** "Until that is settled" is over: a figure is the
  > pooled mean over surviving runs, and the stalled run is discarded rather than averaged in or
  > medianed away. "Run more repeats rather than fewer" survives as advice and is now the default,
  > `-Runs` having moved from 3 to 5.
  >
  > **Superseded in two ways, 2026-09-13.** The "+500 µs in roughly one run in four, at every count"
  > this bullet described is **not a per-tick cost and not the borrowed base's Lua** — it is a
  > handful of multi-hundred-millisecond I/O stalls on the harness's own `log()` write, diluted by
  > the pooled mean. And the decision is **[#326][326]**, not #235, which answered the mechanism
  > rather than choosing the statistic. Neither option this bullet weighs is the right answer:
  > `Find-StalledRuns` now names the poisoned run so it can be discarded. See the foot of this note.
- **Nothing consumes the energy or the by-products**, exactly as in the rig and for the same reason.
  The steam route is absent on purpose: `control.lua` clamps the energy write to the box and discards
  the overflow, and the whole simulation step runs anyway. A full *collector*, by contrast, idles the
  blanket by design — so a planted run must keep its collectors from saturating, which at benchmark
  length they do not.
- **Space Age is out of scope**, per [ADR 0003][adr3]. The borrowed base is vanilla, which is v1's
  target; a Space Age measurement is a separate, later question and deliberately not a prerequisite
  of #67.

## The +500 µs spike, and what looking for it found instead — #235

[#235][235] recorded that the borrowed base's own Lua costs about **+500 µs a tick in roughly one
benchmark run in four**, constant whatever *n* is, and named three candidates. Investigated
2026-09-12. **The spike itself did not reproduce on 2026-09-12**, and two of the three candidates are
eliminated — but the search found a fourth cause that was never on the list, and it was changing
every figure this harness has ever published. **It reproduced the next day, once that cause was
fixed, and the answer is at the foot of this section.**

### The scenario script is not it, and that is settled by reading

The save's `__level__` is **stock freeplay**: its `control.lua` is one line,
`require('__base__/script/freeplay/control.lua')`, which adds `freeplay` and — no Space Age —
`silo-script`. Between them those register **eight events and not one tick handler**: seven
player-and-cutscene events in `freeplay.events`, and `on_rocket_launched` in `silo_script.events`.
No `on_tick`, no `on_nth_tick`, anywhere.

Of the eight, only `on_rocket_launched` can fire during a benchmark, and on this save it does
nothing: it returns at once once `script_data.finished[force.name]` is set, which a megabase that has
already launched set long ago. **The scenario script does no per-tick work at all**, so it cannot be
the source of a per-tick cost. Candidate one is closed without an experiment.

### Garbage collection is not it either, and that took the instrument the ticket asked for

`bench-reactors.ps1` kept per-run figures for `wholeUpdate` and `scriptUpdate` only, which is why
#235 records the `luaGarbageIncremental` correlation as unreadable. It now keeps `GcByRun` too and
prints it on the same `by run:` line, so every future sitting carries the column.

Read at **tick** resolution rather than per run, over 4,000 ticks of the borrowed base at *n* = 0:

| | |
|---|---|
| per-tick correlation, `scriptUpdate` against `luaGarbageIncremental` | **0.073** |
| `luaGarbageIncremental` median on the expensive ticks | **27.9 µs** |
| the same, over all ticks | **25.8 µs** |

The expensive ticks are not the collecting ticks. Candidate two is closed.

### What the ticks actually were: our own instrumentation, a hundred times too often

`scriptUpdate` at *n* = 0 was **93.2 µs mean against a 13.1 µs median**, and the gap is one tick in
five: gaps between ticks over 200 µs were **5, in 795 of 800 cases**. Strictly periodic, which on its
own answers the ticket's periodic-versus-probabilistic question for the *baseline* cost. Split by
that period, the census tick cost **414 µs against 12.9 µs for every other tick.** Amortised over
the five, that tick is **89% of the whole `scriptUpdate` mean** gross, or **86%** counting only its
excess over an ordinary tick. (Both are quoted in this commit; they answer different questions and
the second is the one that would go away if the handler did.)

Period five is the rig's own census-and-`log()` handler. It was meant to run on `-ReportEvery`,
which defaults to **500**. It ran every **5**.

**The cause is that PowerShell variable names are case-insensitive.** `bench-reactors.ps1` reads the
shipped mod's `REPORT_EVERY` out of `control.lua` into `$reportEvery`, a few lines after the
`-ReportEvery` parameter has been set up — and those are the same variable. Reading the mod's value
overwrote the parameter. `-ReportEvery` was inert whatever it was passed, its `ValidateRange` and its
`.PARAMETER` block decorating a value nothing used, and the rig wrote a log line every fifth tick.
The comment above the handler said *"One tick in a hundred carries
a log write"*, which is what makes it invisible: the code and the prose disagreed and only the code
ran.

Nothing failed, and nothing could have. A rig that reports a hundred times too often still reports,
so every gate that reads the census line still passed.

### What it cost, measured before and after the rename

Same sitting, same machine, borrowed base, `-Collectors -Blankets -Gap 6 -Ticks 1000 -Runs 3`:

| | `scriptUpdate` mean, *n* = 0 | mean, *n* = 200 | per reactor |
|---|---|---|---|
| census every 5 ticks | 91.30 µs | 1,797.37 µs | **8.5304 µs** — 10.23% of a tick |
| census every 500 ticks | **16.20 µs** | **1,286.03 µs** | **6.3492 µs** — 7.62% of a tick |

**The rig's own census was 2.18 µs per reactor, 25.6% of the published figure.** The tick-level
decomposition, run before the fix was made, predicted **2.23 µs** — 2.3% above what the before/after
sitting then measured, which is the check that the two methods see the same thing. (Its own share came
out at 25.5% rather than 26.1% because the four-cell model totals 8.77 µs against the reported 8.53,
the cells not being perfectly additive. Compare the absolutes; the percentages carry that 3% with
them.)

**It does not cancel, and the script said it did.** Its note for `-Save` reads *"the rig can charge
its own report walk to a delta"* — true only of a walk that costs the same at every count, and this
one walks `storage.reactors`, `storage.collectors` and `storage.blankets`. At *n* = 0 the loops are
empty and the tick costs 414 µs; at *n* = 200 they are not and it costs 3,723 µs as a mean over three
runs of the pre-fix sitting. (Reconstructing that tick from the before/after table instead gives about
3,860 µs, a 4% disagreement between a directly-measured cell mean and one backed out of two run
means. The per-reactor figure quoted below is the measured before/after difference, not the reconstruction.) The difference lands
in the numerator of every per-reactor figure.

**The window is datable, and it is not the whole record.** `git log -S'reportEvery'` returns one
commit: **`0b43649`, 2026-09-03**, *"benchmark a save the script did not build"* — the `-Save`
feature, which introduced the `control.lua` read in the first place. The script itself dates from
`5444188`, 2026-08-15. So **`-ReportEvery` worked as documented for nineteen days, and every figure
taken before 2026-09-03 is clean** — which covers most of
[`reactor-runtime-cost.md`](reactor-runtime-cost.md), its 2026-08-17, -08-18 and -08-20 sections
included.

**What is affected is every per-reactor figure taken from 2026-09-03 on, and not only the borrowed
base's** — the rig runs the same handler. Two documents carry such figures, across **three**
sittings. **None has been re-taken and none is restated here:**

| Document | The figures | Does its conclusion turn on them? |
|---|---|---|
| [`reactor-runtime-cost.md`](reactor-runtime-cost.md) | the **#67** sitting of 2026-09-06 — 7.01 µs against a rig control's 6.33 | the absolutes move, and *these two* are inflated alike |
| the same | the **#72** confinement-heating sitting, also 2026-09-06 — 3.112 and 3.989 µs, *"the delta is +0.88 µs per reactor"* | unknown. The delta is between two counts in one sweep, so the census may cancel out of it; nobody has checked |
| [ADR 0005][adr5] | **7.01 µs** per reactor against the control's **6.33**, and **8.41%** of a tick at 200 blanketed D-D | **No.** Both absolutes are inflated by the census; the ratio moves 1.11 to about 1.16 and stays inside the 1.35× floor, so `UPDATE_INTERVAL` still stays at 6 |

**One comparison in `reactor-runtime-cost.md` is NOT between figures inflated alike, and it is the
one that licenses the rest.** Its *"The rig control reproduces the record"* paragraph sets the #67
sitting's 6.33 µs rig control against **#62's 5.44 µs** and calls the 1.16× between them proof that
*"the two columns above are apples to apples"*. But #62's figures landed in `2e4411f` at
**2026-09-03 14:05**, and the collision landed in `0b43649` at **19:56 the same day** — so **5.44 is
clean and 6.33 is not.** Corrected, the pair is nearer 5.44 against 4.15, a ratio of about **1.31**:
still under the 1.35× floor, but against it rather than comfortably inside it, and no longer a
reproduction of anything. That paragraph now carries a note saying so.

ADR 0005 is the one that matters most, because a superseded figure left standing in a permanent
decision record reads as deliberate — [#230][230]'s lesson, recorded in `docs/agents/code-review.md`.
Its verdict survives and its numbers do not. Re-taking any of these is [#327][327], and a decision
about a published record rather than a correction to a script.

### What the spike is — answered 2026-09-13

**It is not a per-tick cost and never was. It is a handful of multi-hundred-millisecond stalls,
diluted across a thousand ticks by the pooled mean.**

Fixing `-ReportEvery` is what made this findable: the parameter works now, so **`-ReportEvery 5`
reproduces the old behaviour exactly** and the effect can be summoned instead of waited for. Twenty
runs at the old cadence, `-Counts 0`, borrowed base, quiet machine:

| | |
|---|---|
| nineteen runs | `script mean` 90.3 – 99.3 µs |
| **run 6** | **662.6 µs** |
| run 6's `gc mean` | **37.6 µs** — mid-pack, against 37.0 – 40.0 for the rest |
| run 6's `whole median` | 10,397 µs — ordinary |

Split by tick, run 6's 570 µs of excess is **six ticks of a thousand**:

| tick | `scriptUpdate` | share of the excess |
|---|---|---|
| **t = 876** | **389.3 ms** | 68% |
| next five | 80.3, 47.0, 40.1, 2.4, 0.9 ms | 30% |
| **the other 994** | — | **2%** |

**Run 6's median tick is 11.60 µs against 11.70 for the clean runs.** That is the whole mystery: a
pooled mean divides one 389 ms stall across a thousand ticks and reports it as *+389 µs of cost per
tick*, and the median cannot see it at all. Three sittings measured a real thing and described it in
the one unit that makes it unrecognisable.

**It is the machine blocking, not work.** `wholeUpdate` on t = 876 is **400.5 ms**, so the engine
sat inside Lua for four tenths of a second; `luaGarbageIncremental` on that tick is 58 µs against a
24 µs median. The tick is a census tick — the one that calls `log()` — and the stalls in the other
sittings land on census ticks too. Nothing a reactor count can change makes a file system block, and
that is why #235 measured the same excess at *n* = 0, 50 and 200.

**Candidate three is dead with the other two.** #235 asked about something periodic *at a cadence
near the run length*, and there is nothing there: a period scan over 12,000 ticks of the residual
found nothing a shuffle control did not also find, its apparent peaks being the largest periods
tested — which is what noise looks like — and driven by these same few outliers.

**The stall ticks are not scattered, and that is better evidence than if they were.** t = 876 here;
t = 91, 551, 606 and 786 in an earlier sitting. **All five are ≡ 1 (mod 5)** — every one of them a
census tick, on the lattice the section above identified. They are confined rather than periodic in
#235's sense, and the confinement is to the tick that calls `log()`, which corroborates the
mechanism from numbers collected for a different purpose.

**The `-Ticks` question, answered: probabilistic, not periodic.** A stall is an external event, so
its chance in a run grows with how long the run is and how often it touches the file system — not
with any cadence in the map.

**What the rate is, and what it is not evidence for.** On 2026-09-13, at the OLD cadence of 5, the
spike appeared in **one run of twenty**. #235 records roughly one in four. Both are the same 200
writes per 1,000 ticks, so the difference between them is the machine on the day and not the
cadence. It is tempting to read the whole 2026-09-13 record as "fewer writes, fewer stalls", and the
record does not support it: **0 of 7 usable runs at `-ReportEvery 1`** (1,000 writes a run, where
the write hypothesis predicts the *most*), **1 of 20 at cadence 5** (200 writes), **0 of 8 at
cadence 500** (2 writes). Non-monotone, on populations far too small to separate. What can be said
is that a stall must land on a tick that does something slow, that every one observed landed on a
census tick, and that a run making two writes offers a hundredth of the opportunities of one making
two hundred.

**What is not established.** *Why* the file system blocks for 389 ms — antivirus, a flush, disk
contention — is outside this project and was not chased. And the write hypothesis predicts the rate
should be highest at `-ReportEvery 1`, where a run makes a thousand writes; a sitting there produced
no clean stall in seven usable runs. Seven runs of a one-in-twenty event settles nothing either way,
but it is recorded rather than left out.

### The harness now says so itself

`Find-StalledRuns` flags a run carrying a tick that is both **over 50 ms** and **at least 20× the
same tick index in every other run**, and both conditions are load-bearing. Size alone was the first
version and it was useless: a plain rig sweep spends about **108 ms at t = 30 of every run**, the
same index each time, and that is work rather than a stall. Reproducibility is what separates them,
which also means `-Runs 1` cannot decide and reports nothing.

`-SelfTest`'s `stall-detector` half holds all three directions — the 389 ms one-run stall is flagged, 5.5 ms of real
simulation is not, and a 108 ms spike repeating in every run is not. Run against the recorded
twenty-run dump it returns exactly `run 6, tick 876, 389.3 ms` and passes the other nineteen. The
tick it reports is the dump's own `t<n>` label, so it can be grepped straight out of the file; on a
truncated dump, where a malformed row has been dropped, it is a position rather than a label and the
sample-count warning says so.

### The statistic for a borrowed base

**Settled 2026-09-13 as a recommendation, decided 2026-09-17 by Truls: a figure is the pooled mean
over SURVIVING runs.** The choice is [ADR 0037][adr37]'s and [#326][326] is closed; what follows is
the argument that led there, kept because the reasoning is what a future reader needs and the ADR
carries only the outcome. The decision is not either option #326 offered — see the two notes at the
foot of this section, which are what moved it.

**What was recommended, and what it rests on: keep the pooled mean and raise `-Runs`.** Reasons, in
order:

- The case for a median across runs was that one bad run in five moves the pooled mean by 20%. With
  the census at its intended cadence the baseline is 16.2 µs rather than 91.3, so a fixed excess is a
  far larger *relative* outlier and far easier to see and discard by hand than to average away.
- Changing the statistic changes what every figure in `reactor-runtime-cost.md` means, and the
  ticket's own fourth sitting measured the cost of not changing it: with a clean baseline the two
  agree to **0.3%** at *n* = 200 (6.99 µs median-across-runs against 7.01 pooled mean).
- A median across runs would have *hidden* what this investigation found. The census cost was
  present in every run, not in one in four; a statistic chosen to drop outliers would have left it
  exactly where it was.

So the recommendation is procedural rather than statistical: **run more repeats, read the per-run
line, and discard a run whose `script mean` is out of family** — now easier, because `gc mean` sits
beside it and says whether collection explains it.

> **Strengthened 2026-09-13, once the spike was identified.** Neither statistic the ticket offered is
> the answer, because the thing being averaged is not a cost at all — it is a stall. A **median
> across runs** would drop the poisoned run and give the right number for the wrong reason, and it
> would still be wrong the moment two runs in five stall. A **pooled mean** reports the stall as
> cost. What actually fixes it is neither: **detect the stalled run and discard it**, which is what
> `Find-StalledRuns` now does, and which leaves the mean free to mean what the script's own
> `.DESCRIPTION` says it means. #326 remains the place that decision is made.
>
> Note what the per-tick **median** does here, since it is the same word used two different ways.
> The median across *ticks* is already immune — run 6's was 11.60 µs against 11.70 for clean runs.
> It is the median across *runs* that the ticket proposed, and that one is a blunter instrument than
> naming the bad run.

> **Decided 2026-09-17 — [ADR 0037][adr37].** A figure `bench-reactors.ps1` reports is **the pooled
> mean over surviving runs**: the stalled run's ticks leave the samples before anything is pooled.
> That is the note above turned into behaviour rather than either option the ticket named.
>
> Five things follow, and the ADR carries the reasons. The discard is **per row**, since run 3 at
> *n* = 0 and run 3 at *n* = 200 are separate processes sharing only an index. It applies to **every
> map this harness measures**, rig included, because a stall belongs to the machine and not to the
> map. Below **two surviving runs** a count refuses rather than reports, while `-Runs 1` — where
> nothing was discarded and the detector cannot decide — is left alone. `-Runs` now defaults to
> **5**, because three is too thin to lose one from. And the per-run line still prints **every** run,
> with the excluded one named and the figure the row would otherwise have carried printed beside it.
>
> **No figure already published changes meaning**, which is why this option and not the median across
> runs: where nothing stalled, the two are the same arithmetic.

**"Pooled mean" keeps its name and now means one thing.** A figure is *the pooled mean over N
surviving runs*, with N written out — four of five where one stalled, five of five where none did.
The new term is **stalled run**, which `CONTEXT.md` defines and which is the thing removed. Beware the one word still doing two jobs in this note: the median across *ticks* is printed
on every row and is immune to a stall, and the median across *runs* is the option that was declined.

## Reproducibility, and how it fails

**The recipe is the durable artefact, not the save.** `-PlantInto` is committed; the borrowed base is
not, and could not be. Someone else can obtain TimEv's save from the video themselves and rebuild an
*equivalent* measurement — not the same one, since the link's bytes already disagree with the thread's
stated version.

Accepted deliberately, and recorded in
[ADR 0029][adr29] rather than left as a paragraph here: this project accepts one figure whose input is
third-party and unshippable. **If the link rots, the figure becomes reproducible only by whoever still
has the file.** That is the failure mode, not the plan — and it is why the provenance above is written
down in this much detail rather than kept in someone's head.

A synthetic loaded base — belts, trains, biters, generated by a committed script — was considered and
rejected. It would be a *bigger rig*, not a factory, and #65 exists precisely because a rig cannot
answer the question. Nothing here forecloses building one later if the borrowed base becomes
unavailable.

[65]: https://github.com/trulsjo/realistic-fusion-refreshed/issues/65
[67]: https://github.com/trulsjo/realistic-fusion-refreshed/issues/67
[adr1]: ../adr/0001-liftable-predecessor-material.md
[adr3]: ../adr/0003-space-age-tolerated-not-targeted.md
[adr29]: ../adr/0029-the-factory-measurement-rests-on-a-borrowed-base.md

[235]: https://github.com/trulsjo/realistic-fusion-refreshed/issues/235
[230]: https://github.com/trulsjo/realistic-fusion-refreshed/pull/230
[adr5]: ../adr/0005-real-time-fusion-simulation.md
[adr37]: ../adr/0037-a-benchmark-figure-is-pooled-over-surviving-runs.md
[327]: https://github.com/trulsjo/realistic-fusion-refreshed/issues/327
[326]: https://github.com/trulsjo/realistic-fusion-refreshed/issues/326

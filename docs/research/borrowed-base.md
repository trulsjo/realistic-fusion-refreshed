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
> busy reading here is not simply a quiet one scaled up.
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

  **The rule above is about the median of TICKS. A median across RUNS is a separate question and is
  open** — [#235][235]. The borrowed base's own Lua costs about +500 µs in roughly one run in four,
  at every count including *n* = 0, on a quiet machine where the rig is tight to 1.09×. So the
  pooled mean this note tells you to read is the statistic one bad run of five can move by 20%,
  and whether a borrowed base should be reported as a median across runs instead is #235's to
  settle. Until it is, **run more repeats rather than fewer**, and do not quote a figure from a
  count whose per-run spread is wide.
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
2026-09-12. **The spike itself did not reproduce**, and two of the three candidates are eliminated —
but the search found a fourth cause that was never on the list, and it was changing every figure
this harness has ever published.

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
decomposition, run before the fix was made, predicted **2.23 µs** — within 2% of what the before/after
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
base's** — the rig runs the same handler. Two documents carry such figures. **Neither has been
re-taken and neither is restated here:**

| Document | The figures | Does its conclusion turn on them? |
|---|---|---|
| [`reactor-runtime-cost.md`](reactor-runtime-cost.md) | the #67 sitting of 2026-09-06 | the absolutes move; the rig-against-base comparison is between two figures inflated alike |
| [ADR 0005][adr5] | **7.01 µs** per reactor against the control's **6.33**, and **8.41%** of a tick at 200 blanketed D-D | **No.** Both absolutes are inflated by the census; the ratio moves 1.11 to about 1.16 and stays inside the 1.35× floor, so `UPDATE_INTERVAL` still stays at 6 |

ADR 0005 is the one that matters, because a superseded figure left standing in a permanent decision
record reads as deliberate — [#230][230]'s lesson, recorded in `docs/agents/code-review.md`. Its
verdict survives and its numbers do not. Re-taking them is a decision about a published record rather
than a correction to a script.

### Where that leaves #235's own question

**Unresolved, and the ticket stays open.** The +500 µs spike did not appear in any of the **15 runs**
taken across three sittings on 2026-09-12, and the ticket's own fourth sitting of 2026-09-06 did not
see it either. It cannot be reproduced on demand and it has not been explained. (One of the 15 was
mildly elevated — +4.7 µs on a 92 µs mean — which is two orders of magnitude below this ticket's
effect and is not it; see below.)

What the fix does is make the mechanism far less likely to matter, without proving it was the cause.
A run used to carry **200 `log()` writes per 1,000 ticks** and now carries two. An I/O stall on that
write would add a fixed cost per tick **independent of *n***, which is exactly the signature #235
records — so the surface area for it is cut a hundredfold. **That is a hypothesis, not a
measurement**: no spiking run was ever caught with the instrument attached. The one mildly elevated
run of 2026-09-12 — run 4 of the four-run `-KeepTemp` sitting, 96.8 µs against the other three's
92.0 — put most of its excess *outside* the census tick, which counts against the I/O story rather
than for it. It is a different and much smaller thing than the ticket's +500 µs, and so is the
elevated run the ticket's own fourth sitting records.

The `-Ticks` question is answered for the periodic baseline cost and **not** for the spike, which is
what it was asked about.

### The statistic for a borrowed base

**Keep the pooled mean and raise `-Runs`.** Reasons, in order:

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

[235]: https://github.com/trulsjo/realistic-fusion-refreshed/issues/235
[230]: https://github.com/trulsjo/realistic-fusion-refreshed/pull/230
[adr5]: ../adr/0005-real-time-fusion-simulation.md

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

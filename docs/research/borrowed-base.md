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
checked.

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

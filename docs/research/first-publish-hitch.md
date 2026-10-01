# The hitch on the first circuit publish (104 to 142 ms, re-measured 2026-10-01)

> **2026-10-01: NO COMMIT GREW IT. THE MACHINE DID.**
> ([#479](https://github.com/trulsjo/realistic-fusion-refreshed/issues/479), at `98cab4c`.)
>
> The 2026-09-17 figure was 122.5 ms and the 2026-09-30 ones 257 to 341 ms, at *n* = 1 with D-D.
> Taken again today, five runs per invocation with `-Runs 5` — each run reloads the save, so
> each pays its own sweep — and tick 30's `scriptUpdate` read per run:
>
> | code | tick 30 `scriptUpdate`, five runs |
> |---|---|
> | `98cab4c` (this work's base; its Lua differs from `433cc4b`, where the 2026-09-30 runs were taken, only in comments) | 109.9, 111.2, 119.2, 109.7, 103.8 — **103.8 to 119.2 ms** |
> | `ab3ac29` (the commit that recorded the 2026-09-17 figure; its tree extracted with `git archive` and HEAD's `scripts/` and `vendor/` laid over it, so the same bench loaded the old mods) | 109.0, 127.2, 118.5, 108.0, 110.0 — **108.0 to 127.2 ms** |
>
> **Spread on one commit is about 15 to 20 ms**, and the two commits overlap inside it. Both sit at
> the 2026-09-17 figure, not at 2026-09-30's.
>
> **The sweep itself was also timed outside the game**, at the commit that took the first figure
> and at each of the eleven after it that touch `realistic-fusion-refreshed/scripts/`, where
> `density_curve` and everything it calls live: `density_curve(L.reactor, "rf-d-d-plasma",
> L.reactor.box_volume)` under Lua 5.4.6, five calls each. Commits that touched only
> `control.lua`, prototypes or locale were not timed this way; the two in-game rows above cover
> the whole path, `control.lua` included, at both ends. Fastest call per commit: 54 to 68 ms, with no step anywhere — `ab3ac29`, `12eed76`, `33ba491`, `5d248ba` (the
> heating ladder, #425), `96f7776`, `227eb9d`, `5b46a0a`, `d47055d`, `c3758f7`, `035b5f7`,
> `1865815`, `98cab4c`. **The sweep is the same cost at every one.** It is fixed at 24 000
> `M.step` calls by `FILL_STEPS` × `CURVE_SECONDS` / `CURVE_DT`, none of which moved, and the
> heating ladder changed which spec it settles against but not how much work settling is.
>
> **What points at the machine** is this note's own cross-check: on 2026-09-30 the same
> out-of-game call took 190, 138 and 158 ms, and today on identical code it takes 54 to 68 ms —
> a factor of about 2 to 3.5, the same as the in-game figure moved by (about 2 to 3.3).
> **What made the machine slow on 2026-09-30 is not known**: those runs' `machine:` line was not
> recorded, and this one read `clock 147% of base`. So the growth was **not intended and not a
> change at all**, and the 257-to-341 figures below are most likely readings of a slow machine. The options
> further down should be weighed against ~110 ms, not ~300.

> **2026-10-01: AND A RUNG PAYS IT MID-GAME, ONCE PER NEW KEY.**
> ([#480](https://github.com/trulsjo/realistic-fusion-refreshed/issues/480), at `98cab4c`.)
>
> The second case "Today" below states from the code, now measured. A rig of two reactors
> (`bench-reactors.ps1 -Counts 2 -KeepTemp`), one moved to a second force at tick 5, with research
> finished on scheduled ticks by `researched = true` — see "Reproducing it". Five runs of 600
> ticks; the report after a tick-*t* event lands on the next multiple of 30. Run medians 13.4 to
> 14.5 µs.
>
> | tick | what finished | report tick | `scriptUpdate` there, five runs |
> |---:|---|---:|---|
> | — | nothing (the load sweep) | 30 | **108 to 141 ms** |
> | 101 | `rf-plasma-confinement-1`, player | 120 | **109 to 137 ms — a sweep** |
> | 201 | `automation`, player — moves no spec field | 210 | 98 to 116 µs — none |
> | 301 | `rf-plasma-heating-1`, player | 330 | **109 to 125 ms — a sweep** |
> | 401 | `rf-plasma-confinement-1`, **second force**, a key the player already swept at 120 | 420 | 98 to 145 µs — none |
> | 501 | `rf-plant-efficiency-1`, player — a ladder, but not on a spec field (ADR 0020 decision 5) | 510 | 103 to 129 µs — none |
> | 541 | `rf-plasma-confinement-2`, second force — a key nobody has swept | 570 | **116 to 142 ms — a sweep** |
>
> **So:** a confinement rung and a heating rung each cost one full sweep, on the next reporting
> tick, with no loading screen — the same size as the load hitch. **Neither technology tried that
> moves no spec field cost a sweep** — `automation`, and our own `rf-plant-efficiency-1` — which
> is what keying `curves` on spec fields rather than dropping it on `on_research_finished` predicts
> for every such technology; two were measured. **The second force reaching
> `rf-plasma-confinement-1`, which the first already had, did not pay again** — the cache is shared
> across forces, and one rung was measured. The tick-541 row is the control for that one: the second force's reactor sweeps as soon as it needs a key nobody
> has, so its quiet tick 420 is a cache hit and not a reactor that never reported.
>
> One reading beside it that is not a sweep and was not chased: **the tick a technology finishes
> on is sometimes about 2 ms** of `scriptUpdate` — 1.9 to 2.1 ms in four runs of five at tick 101,
> three at 201 and four at 401, a vanilla technology included, and 0.2 to 0.4 ms otherwise, which
> is every run at 301, 501 and 541. It is about a fiftieth of a sweep.

> **2026-09-30: NAMED, AND AN ORDINARY GAME PAYS IT, ON EVERY LOAD.**
> ([#400](https://github.com/trulsjo/realistic-fusion-refreshed/issues/400),
> [#399](https://github.com/trulsjo/realistic-fusion-refreshed/issues/399), at `433cc4b`.)
>
> **The work is the density-curve sweep, `logic.density_curve`, reached through `curve_for` in
> `realistic-fusion-refreshed/control.lua`**, the fifth argument at the `circuit.publish` call
> site. It is neither of the two candidates this note left: it sits beside them in the same
> argument list, is evaluated before `publish` is entered for the same reason, and was missed for
> the same reason. Disabled on its own, the spike goes: **341 340 µs → 301 µs**. Its cache,
> `curves`, is a module-local table and not `storage`, so it is empty in every fresh Lua state —
> **every time any save is loaded**, not only the first time the mod is added. See "Named" and
> "Does an ordinary game pay it" below. The measurements between here and there are left as
> they were taken on 2026-09-17; only the opening paragraph and the "What was left" heading are
> reworded, to mark them superseded.

Measured 2026-09-17 against Factorio 2.0.77, for
[#330](https://github.com/trulsjo/realistic-fusion-refreshed/issues/330), with
`scripts/bench-reactors.ps1 -KeepTemp` and the `--benchmark-verbose` per-tick dump read directly.

**As first written, this note did not name the work.** It established what the hitch IS with two
decisive experiments, eliminated four candidates by measurement, and left two. The banner above
and "Named" below are what came after.

## Reproduced

| | median `scriptUpdate` | worst tick | cost | multiple |
|---|---:|---:|---:|---:|
| rig, *n* = 10, 300 ticks | 26.1 µs | **30** | **123 341.8 µs** | **4 735×** |
| rig, *n* = 1, 200 ticks | 9.0 µs | **30** | **122 518.6 µs** | **13 613×** |
| rig, *n* = 0, 200 ticks | 5.7 µs | 100 | 405.6 µs | 71× |

Every other multiple of 30 is ordinary — 283 to 964 µs at *n* = 10. It happens once.

**The whole tick is our Lua.** At the spike, `scriptUpdate` is 116 898 µs and `wholeUpdate` is
117 135 µs; `gameUpdate` is 214 µs, against 225 µs on the tick before. No other column moves.

## It IS the first circuit publish, and that was the thing to settle first

#330 said tick 30 being `UPDATE_INTERVAL` × `REPORT_EVERY` (6 × 5) is "a hint and not a proof".
So the cadence was moved and the spike moved with it:

| `REPORT_EVERY` in `control.lua` | first publish at | spike at | cost |
|---|---:|---:|---:|
| 5 (shipped) | tick 30 | **tick 30** | 123 341.8 µs |
| 11 (temporary) | tick 66 | **tick 66** | 116 898.1 µs |

At `REPORT_EVERY` 11 the **second** publish, tick 132, costs 565.9 µs — ordinary. So it is the FIRST
publish and not the publish cadence.

## It needs a reactor, and then it does not care how many

**At *n* = 0 there is no spike at all.** No reactor means no publish, and the worst tick in the whole
run is 405.6 µs. At *n* = 1 the full cost is paid.

Put beside #330's own figures, the cost is flat across the whole range:

| *n* | cost of the first publish |
|---:|---:|
| 0 | **none** |
| 1 | 122 518.6 µs |
| 10 | 123 341.8 µs |
| 200 | ~116 000 µs (#330) |

**So it is a fixed, one-time cost, triggered by the first reactor and independent of reactor count.**
That is the signature of a first-use initialisation reached through the publish path, not of
per-reactor work. #330 asked for the dependency to be confirmed rather than left as "not reactors";
this is that, from the other end — 200× the reactors costs nothing extra, and 0 reactors costs
nothing at all.

## Four candidates eliminated, each by disabling it and re-running at *n* = 1

Every experiment was a temporary edit to `realistic-fusion-refreshed/scripts/circuit-output.lua`,
reverted immediately after its run. Nothing here is committed.

| what was disabled | spike still there? | cost |
|---|---|---:|
| `entity.custom_status` (the localised-string write) | **yes** | 114 723.0 µs |
| the `section.filters` wholesale write | **yes** | 123 914.1 µs |
| everything from `section_for` onward (so no combinator is created, and no signals) | **yes** | 117 234.2 µs |
| `animation.set` | **yes** | 108 699.5 µs |

None of the four is the cause. Note what the third one rules out: **the combinator is never created
in that run and the hitch is unchanged**, so it is not the first `create_entity`, not the first
constant-combinator, and not the first logistic section.

## What was left, and it was two things — and a third nobody listed

**Superseded by "Named" below**; kept as the reasoning the next experiment was built from.

`circuit.publish` is the ONLY thing `control.lua` gates on the reporting tick — `reporting` guards
that call and nothing else — so the cost is inside that statement. After the four eliminations, two
parts of it have not been tested:

1. **`M.status(...)`**, the first call to it, including the `storage.reactor_status` table's first
   use.
2. **The argument expression at the call site**, `plasma_capacity(entity.name)`. This one is easy to
   miss and is why it is written down: it is evaluated in `control.lua` BEFORE `publish` is entered,
   so every experiment above — all of which edited the body of `publish` — left it running.
   `plasma_capacity` memoises into `PLASMA_CAPACITY` and its first call reaches
   `prototypes.entity[name].fluidbox_prototypes[1].volume`.

A memoised first prototype access fits the measured shape exactly — paid once, needs one reactor,
flat in reactor count — but **fitting the shape is not evidence**, and neither candidate has been
tested. That is the next experiment, and it should disable them one at a time the way the four above
were.

## Named: the density-curve sweep (2026-09-30, #400)

Each candidate disabled on its own, at *n* = 1, 200 ticks, one run, with
`scripts/bench-reactors.ps1 -Counts 1 -Ticks 200 -Runs 1 -KeepTemp`, and the edit reverted with
`git checkout` straight after its run:

| what was disabled | edit | tick 30 `scriptUpdate` |
|---|---|---:|
| nothing (the reproduction) | — | **341 340.1 µs** |
| candidate 1, `M.status(...)` | in `M.publish` of `realistic-fusion-refreshed/scripts/circuit-output.lua`, `local status = M.status(...)` → `local status = { key = "running", diode = "green" }` | **271 793.7 µs** — still there |
| candidate 2, `plasma_capacity(entity.name)` at the call site | in `realistic-fusion-refreshed/control.lua`, `plasma.amount / plasma_capacity(entity.name)` → `plasma.amount / 1000` | **291 295.2 µs** — still there |
| **`curve_for(entity, spec, plasma and plasma.name)` at the call site** | same statement, that argument → `nil` | **300.9 µs — gone** |

**So the work is one `logic.density_curve` sweep**, which settles the reactor at twenty fills
(`FILL_STEPS`) for `CURVE_SECONDS` each. At *n* = 1 with D-D there is exactly one key in the cache,
so exactly one sweep, and that is the whole shape this note found: once, needs a reactor, flat in
reactor count — every reactor of one prototype on one plasma at one spec shares the key.
Neither ticket candidate was it. Candidate 2's memoised prototype lookup is also reached inside
`curve_for`, but it cannot be the cost: with the call-site one disabled the spike stays.

**Timed outside the game as a cross-check**, `density_curve(L.reactor, "rf-d-d-plasma",
L.reactor.box_volume)` under plain Lua 5.4.6 took 190, 138 and 158 ms on three calls — the same
order as the in-game figure.

**It is bigger than it was.** The reproduction here is 341 ms against 122.5 ms on 2026-09-17, and
the #399 runs below read 257 to 286 ms on the same commit, so run-to-run spread is itself tens of
milliseconds. What grew it since 2026-09-17 was not measured. *(2026-10-01, #479: nothing in the
code grew it — see the banner at the top.)* The comment on `curves` in
`realistic-fusion-refreshed/control.lua` put one sweep at "about fifty milliseconds"; that figure is
corrected alongside this note.

**Whether to remove it is not settled here** — #400 asks for it to be weighed, not done in
passing. What the code does today, and the options:

- **Today.** `curves` is keyed on prototype, confinement time, heating power and plasma, and never
  invalidated, so a sweep happens once per key per Lua state: at the first reporting tick after
  every load, and again the first time a force reaches a new confinement or heating rung. Both
  are measured (#399, #480); see the banners at the top. The
  comment on `curves` records why it is keyed that way: it used to be dropped on every
  `on_research_finished`, and put the resulting rebuild at "four sweeps and about two hundred
  milliseconds". At the 2026-09-30 figures one sweep alone was past that; at the 2026-10-01 ones,
  104 to 142 ms, four sweeps are about half a second.
- **Keep it in `storage`.** Survives a load, so the load hitch goes; the research-rung case stays.
  The cost is that it becomes save state: a physics change in a mod update would leave stale
  optima, so it wants dropping in `on_configuration_changed`, which puts one hitch back after
  every mod update.
- **Sweep eagerly at load.** `on_load` can fill a module-local table, so the cost moves under the
  loading screen instead of into the first reporting tick. It has to know which keys are in use,
  and it does not help the research-rung case.
- **Spread the sweep over ticks.** Twenty fills is twenty independent settles, so one per tick
  would put roughly a twentieth of the cost on each of twenty ticks. The status line would have
  no curve for that long, which `M.status` already handles (*"WITHOUT A CURVE the three density
  states collapse back to "running""*). The cost is a small state machine in `control.lua`.
- **Make the sweep cheaper** — fewer fills, a coarser `CURVE_DT`, a shorter `CURVE_SECONDS` —
  which trades away the optimum's resolution, and `M.status` uses that resolution as its band width.

## Does an ordinary game pay it (2026-09-30, #399)

**Yes. Every load pays it.** Three first runs, each loaded with `--benchmark` at *n* = 1, 200
ticks, `--benchmark-verbose all`, against the same mods. **All three still carry the bench rig**,
because a reactor has to exist and be fed for a publish to happen at all; what separates them is
the save's history, which is the question #399 asks. The load itself is the same `on_load` path a
player's load takes, and that is where the cost comes from — see the next paragraph.

| save | how it was made | worst tick | `scriptUpdate` there |
|---|---|---:|---:|
| created with the mod, never run | `--create` with the mod and rig enabled | 30 | **257 238.1 µs** |
| **already RUN with the mod, then started again** | that save served headless (`--start-server`, `auto_pause` off) for 1207 ticks, saved from inside with `game.server_save`, process killed, the saved file loaded | 22 after load | **285 807.7 µs** |
| **never had the mod** | `--create` with only `base` enabled, then loaded with the mod and rig enabled, so `on_init` ran in an existing save | 30 | **268 539.1 µs** |

The run-again save is the one that decides it. By tick 1207 it had published about forty times
and had built its curve in that session; the curve did not survive the save, and the first
reporting tick after load paid the full sweep again. That is what `curves` living outside
`storage` predicts. **So it is not "only a freshly-added mod pays it": an ordinary game pays it
on every load**. The cost is real and not a benchmark artefact; whether it is a defect a player
perceives is the half that is still open, below.

**What this does not establish is whether a player FEELS it.** It lands on the first reporting
tick after a load, about half a second in. At 60 UPS the 2026-10-01 figures, 104 to 142 ms across
both rigs, are 6 to 9 frames; the 2026-09-30 ones, 257 to 341 ms, were 15 to 20. Nobody has
played it to find out: every figure here is a dump. #399 asks for that once, by playing, and it
is left for a human.

## What this does NOT answer

- **Whether a player notices the load hitch** — see the section above. Measured, not played.
- **Whether it scales with force count, technology state, surface count or map size.** Reactor count
  is now settled at both ends; the other four #330 lists are untouched.

## Reproducing it

**The #400 experiments** are the three edits in the "Named" table, one at a time, each followed by
the command below and a `git checkout` of the file it touched. **The #399 runs** reuse a directory
kept by that command: junction the three mods back into its `mods/`, and for the run-again case
append a handler to the rig's `control.lua` that, on `on_nth_tick(1207)` past tick 0 and only
once, sets a `storage` flag and calls `game.server_save("ran")`. Serve a freshly created save with
`--start-server <save> --bind 127.0.0.1 --server-settings <file>`, where the file is
`data/server-settings.example.json` with `auto_pause` false — with no player connected the server
otherwise pauses and never reaches the tick. Create `write-data/saves` first; the save fails
without it. Kill the server once `write-data/saves/ran.zip` appears. Start every Factorio call
with `Start-Process -Wait`: a bare `&` returns before the GUI binary exits, and the next call
then hits the lock file.

**The #480 runs** reuse a directory kept by `pwsh -Command "& ./scripts/bench-reactors.ps1
-Counts 2 -Ticks 600 -Runs 1 -KeepTemp"`. Append this to the kept `mods/rf-bench-rig/control.lua`,
junction the three mods back into `mods/`, and run `--benchmark` on the kept `n2.zip` with
`--benchmark-ticks 600 --benchmark-runs 5 --benchmark-verbose all`. The events are keyed on
absolute `game.tick`, which holds only because the kept save was written at tick 0:

```lua
local function finish(force, name) force.technologies[name].researched = true end
local EVENTS = {
  [5] = function()
    local second = game.forces["rf-second"] or game.create_force("rf-second")
    for _, r in pairs(storage.reactors) do if r.valid then r.force = second; break end end
  end,
  [101] = function() finish(game.forces.player, "rf-plasma-confinement-1") end,
  [201] = function() finish(game.forces.player, "automation") end,
  [301] = function() finish(game.forces.player, "rf-plasma-heating-1") end,
  [401] = function() finish(game.forces["rf-second"], "rf-plasma-confinement-1") end,
  [501] = function() finish(game.forces.player, "rf-plant-efficiency-1") end,
  [541] = function() finish(game.forces["rf-second"], "rf-plasma-confinement-2") end,
}
script.on_nth_tick(1, function(e) local f = EVENTS[e.tick]; if f then f() end end)
```

The runs that produced the table also logged each event with its tick and whether the technology
was already researched — none was.

The original reproduction:

```
pwsh -Command "& ./scripts/bench-reactors.ps1 -Counts 0,1 -Ticks 200 -Runs 1 -KeepTemp"
```

Then read `bench-n1-stdout.txt` in the kept directory: the `tick,timestamp,...` header names the
columns, and the data rows are prefixed `t` — `t30,...` is the spike. **`scriptUpdate` is the last
column**, and the values are nanoseconds.

The cadence experiment is `local REPORT_EVERY` in `realistic-fusion-refreshed/control.lua`; the four
eliminations are single-call edits in `realistic-fusion-refreshed/scripts/circuit-output.lua`. All
of them are temporary by nature and none should ever be committed.

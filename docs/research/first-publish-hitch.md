# The ~110 ms hitch on the first circuit publish

Measured 2026-09-17 against Factorio 2.0.77, for
[#330](https://github.com/trulsjo/realistic-fusion-refreshed/issues/330), with
`scripts/bench-reactors.ps1 -KeepTemp` and the `--benchmark-verbose` per-tick dump read directly.

**This note does not name the work.** It establishes what the hitch IS with two decisive
experiments, eliminates four candidates by measurement, and leaves two. #330's first acceptance
criterion allows either outcome; this is the second one, and what was tried is recorded so the next
person does not repeat it.

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

## What is left, and it is two things

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

## What this does NOT answer

- **Whether an ordinary game start pays it.** Every reading here is `--benchmark` with the rig mod
  newly added. #330 is explicit that a player-visible hitch and a benchmark artefact are different
  findings needing different responses, and this note does not distinguish them. **Until that is
  answered, nothing here says there is a defect.**
- **What the work actually is.** Two candidates, neither tested.
- **Whether it scales with force count, technology state, surface count or map size.** Reactor count
  is now settled at both ends; the other four #330 lists are untouched.

## Reproducing it

```
pwsh -Command "& ./scripts/bench-reactors.ps1 -Counts 0,1 -Ticks 200 -Runs 1 -KeepTemp"
```

Then read `bench-n1-stdout.txt` in the kept directory: the `tick,timestamp,...` header names the
columns, and the data rows are prefixed `t` — `t30,...` is the spike. **`scriptUpdate` is the last
column**, and the values are nanoseconds.

The cadence experiment is `local REPORT_EVERY` in `realistic-fusion-refreshed/control.lua`; the four
eliminations are single-call edits in `realistic-fusion-refreshed/scripts/circuit-output.lua`. All
of them are temporary by nature and none should ever be committed.

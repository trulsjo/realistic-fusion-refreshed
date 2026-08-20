# Can a reactor prototype emit heat and still pool plasma?

Evidence for [#43](https://github.com/trulsjo/realistic-fusion-refreshed/issues/43), which blocks
the decision in #44. **Nothing here chooses a design.** Every line is a measurement, the negative
results are stated as plainly as the positive ones, and what to do about them is #44's to settle.

Measured against **Factorio 2.0.77** by `scripts/probe-native-heat.ps1`. The script is committed
rather than the numbers alone, because these are facts about a version of the engine and the next
version is entitled to different ones. Re-run it before quoting any figure here against a newer
build.

## The answer in one line

**No — not as one entity.** A `reactor` prototype gets no fluid box at all, so the thing that emits
heat cannot also be the thing that holds plasma. Everything else #43 asked about works, and works
with a great deal of room to spare: a Lua write to `temperature` delivers energy exactly, a vanilla
heat pipe carries about seven times the reactor's output, and no pipe entity of our own is justified.

## Why the question exists

The data stage already said yes. Probing base 2.0.77 with each case a deepcopy of a valid vanilla
prototype and one field changed, a `reactor` accepted an input-output fluid box, a `reactor` accepted
an electric energy source, and a `boiler` accepted a `heat_buffer`. On paper `rf-reactor` could stay
a shared-plasma entity ([ADR 0011](../adr/0011-per-reactor-simulation-fluid-coupled.md)), keep
drawing confinement heating from the network, and emit heat natively.

On paper is exactly the problem. #23 chose a crafting machine for the reactor on the same kind of
reasoning; it loaded perfectly and then moved no fluid at all — pipes connected and nothing crossed —
which is why the reactor is a boiler today. **Data-stage acceptance has already misled this project
once**, and both of the "accepted" fields above turn out to be the same trap.

## What was built

`scripts/probe-native-heat.ps1` builds eight rows on one headless map and measures each. The
`.DESCRIPTION` in the script is the full account; in brief:

| row | what it is |
|---|---|
| `pool` | Two probe reactors joined by a run of `rf-pipe`, the westmost seeded with plasma |
| `deliver` | A probe reactor pinned to 1000 °C by Lua every tick → 3 heat pipes → a sink |
| `consumer` | The same, with a real vanilla heat exchanger and **no** sink |
| `cadence` | `deliver`, written every 6 ticks — control.lua's `UPDATE_INTERVAL` |
| `run` | `deliver` with twenty-four heat pipes between source and sink |
| `tight` | A probe reactor declaring `max_transfer` 50 MW, with a pipe and a sink on each of two faces |
| `boiler` | The shipped `rf-reactor`'s own shape plus a `heat_buffer`, pinned and piped like `deliver` |
| `self` | Two probe reactors declaring `consumption` 133 MW with nothing attached — one never written by Lua at all, one put at 990 °C on the first tick and then left alone |

Delivered power is measured **at the source**, as the joules the Lua pin had to inject to hold the
temperature: `specific_heat` times the deficit it found. That needs no steam, no water and no tank,
so nothing in the measurement can be a fluid throughput limit in disguise.

## The prototype numbers, read from the loaded prototypes

| prototype | kind | specific_heat | max_transfer | ×60 as MW | max °C | connections |
|---|---|---|---|---|---|---|
| `nuclear-reactor` | heat buffer | 10 MJ/°C | 1.667e8 | 10 000 | 1000 | 12 |
| `heat-pipe` | heat buffer | 1 MJ/°C | 1.667e7 | 1 000 | 1000 | 4 |
| `heat-exchanger` | heat energy source | 1 MJ/°C | 3.333e7 | 2 000 | 1000 | 1 |
| `heat-interface` | heat buffer | 10 MJ/°C | 1.667e8 | 10 000 | 1000 | 4 |

**`max_transfer` comes back in joules per tick, not watts.** The heat pipe's prototype declares
`"1GW"` and the runtime reports 1.667e7, which is that divided by sixty. Every rate below is stated
in watts, multiplied out.

Two things about that table are worth having in words, because both are easy to get backwards:

- **A machine that *burns* heat also answers `heat_buffer_prototype`.** Vanilla `heat-exchanger`
  hands back its energy source's buffer, so asking `heat_buffer_prototype` first labels the one
  machine in the game that consumes heat as one that emits it. Ask
  `heat_energy_source_prototype` first.
- **`max_transfer` is per connection, not per buffer.** See `tight` below.

## AC 1 — does a reactor's fluid box join a segment?

**It has no fluid box.** Under either spelling:

```
pool: rf-probe-reactor declares fluid_box and has 0 fluid box(es) at runtime
pool: rf-probe-reactor-boxes declares fluid_boxes and has 0
```

Both keys were tried because a negative here decides #44 and "I used the wrong key" is the one way
such a negative could be wrong. `fluid_box` is what a boiler takes and `fluid_boxes` what a crafting
machine takes; `ReactorPrototype` documents neither, and the engine ignores both. The data stage
accepts the field and drops it on the floor — the same shape of failure as #23.

So the pooling half of the question never arises: a reactor prototype cannot hold plasma, let alone
share a pool of it across a segment.

Widening that: across everything loaded, **the only prototypes that hold or emit heat are of type
`reactor`, `heat-pipe` and `heat-interface`**, and the only one that burns it is `heat-exchanger`, a
`boiler`. None of the three emitters can carry a fluid box.

## AC 2 — does a Lua write to `temperature` deliver energy, and at what rate?

**Yes, and the write is exact and immediate:**

```
write: set 500 C on a buffer holding 1000 C and read back 500 C, then restored to 1000 C
```

Neither clamped by `max_transfer` nor deferred to the next tick, which matters: a write that were
either would make every rate below a measurement of the clamp rather than of the pipe.

| row | pipes | sinks | written every | delivered |
|---|---|---|---|---|
| `deliver` | 3 | 1 | tick | **1 000 MW** |
| `cadence` | 3 | 1 | 6 ticks | **1 000 MW** |
| `run` | 24 | 1 | tick | **606 MW** |
| `tight` | 3 | 2 | tick | **100 MW** (50 MW declared) |
| `consumer` | 3 | — | tick | **10 MW**, the exchanger's own rating |

**Write cadence costs nothing.** Writing every sixth tick delivers exactly what writing every tick
does, which is what a heat buffer being a bank rather than a pipe implies: between writes it cools
into the network instead of losing anything. The mod's `UPDATE_INTERVAL` is not a constraint on this.

**A real consumer runs off it.** On the row with no sink, the vanilla heat exchanger reports
`working`, sits at 995 °C against 997 °C in the pipe beside it, holds steam, and takes exactly the
10 MW it declares — measured independently at the source. That is the whole hop the mod would need:
Lua joules in, steam out, no fluid of ours in between.

## AC 3 — does `consumption` have to be neutered?

**Yes, and for a second reason beyond the first.** The first of the two probes is never written by
Lua at all. Declaring `consumption = "133MW"` on an electric energy source, with nothing attached:

```
self/cold: 413.78 C -> 613.28 C across the window, which is 133 MW into its own buffer
self/cold:   rf-probe-reactor-hungry      input       133 MW   output         0
```

So the engine converts electricity into heat by itself, at exactly the declared rate. That alone
would double-spend: `control.lua` already spends confinement heating out of the buffer, and this
would spend it again as a declared constant, which is precisely why the boiler's `energy_consumption`
is pinned at 1 W today.

The second reason is worse. The other half of that row starts at 990 °C and reaches its ceiling:

```
self/warm: 1000 C -> 1000 C across the window, which is 0 MW into its own buffer
self/warm:   rf-probe-reactor-warm        input       133 MW   output         0
```

**At `max_temperature` it still draws its full 133 MW and banks none of it.** `scale_energy_usage`
defaults to `false` and this is what that means: a saturated reactor burns the network for nothing.
Either the field is neutered the way the boiler's is, or that flag has to be part of the design.

Driving it entirely from Lua works: every row above ran with `consumption` at 1 W.

## AC 4 — the `boiler` + `heat_buffer` case

**Resolved, negative.**

```
boiler: rf-probe-boiler has NO heat buffer at runtime -- the heat_buffer field was accepted by the
        data stage and ignored by the engine, so this prototype cannot emit heat at all
```

The subject was the shipped `rf-reactor`'s own shape — a `heat-exchanger` copy with an electric
source and `energy_consumption` at 1 W — plus a `heat_buffer`. It loads, as #43's table said, and
the field does nothing. **The reactor cannot gain heat emission by keeping the prototype it already
has.**

## AC 5 — throughput against the reactor's real output

The shipped reactor makes **133 MW** of thermal output at equilibrium
(`realistic-fusion-refreshed/scripts/reactor-logic.lua`), where a vanilla nuclear reactor is 40 MW.

| what | carried | against 133 MW |
|---|---|---|
| Three vanilla heat pipes | 1 000 MW — exactly the pipe's declared `max_transfer` | 7.5× |
| Twenty-four vanilla heat pipes | 606 MW | 4.5× |

**No pipe entity of our own is justified by throughput.** A vanilla heat pipe carries the reactor's
whole output several times over at the length a player would actually build, and one pipe is enough:
`max_transfer` is per connection, which the `tight` row settles — a buffer declaring 50 MW delivered
100 MW through two connections at once. A reactor-shaped buffer has twelve of them.

**What `max_transfer` the source needs** is therefore ≥ 133 MW on the connection it emits through,
and vanilla's 10 GW is seventy-five times that. Nothing needs tuning for capacity — but note that
the source's ceiling is not what binds: the pipe's 1 GW is, and beyond a few tiles of pipe the
diffusion chain binds before either.

The 24-pipe figure is converged rather than still settling: 606.64 MW at 1800 ticks of warmup against
606.22 MW at 7200, a 0.07% difference, which is why the script's default warmup is 1800.

## What these numbers are not

**Every throughput figure here is best case, deliberately.** The sink is a `heat-interface` held at
0 °C rather than a bank of heat exchangers, so it absorbs everything the run can deliver instead of
10 MW a machine, and it keeps the far end of every run cold — the largest temperature gradient the
engine can be shown. A real bank of exchangers reads lower, and the `consumer` row is the honest
shape of a player's build.

It also cuts the other way, and that is worth knowing before anyone builds this: the greedy sink
holds the pipe beside the source at about 100 °C, and **a vanilla heat exchanger will not run below
500 °C** (`min_working_temperature`). A design that over-drains a heat network stops the machines on
it rather than slowing them.

Two things #43 did not ask and this did not measure:

- **UPS.** Nothing here is a performance measurement. A heat network is engine-side work this mod
  currently does not do at all, and ADR 0005's budget has not been asked about it.
- **What a player sees.** Heat has its own overlay, glow and connection graphics, and the reactor's
  own art (#45) and its status text (#46) are open tickets. None of that is in these numbers.

## What is left standing for #44

Stated as constraints rather than as a recommendation — the choice is #44's:

- **The emitter and the plasma pool cannot be one entity.** Native heat therefore costs at least one
  more entity, or a companion arrangement of the kind the reactor already has for collectors and
  blankets (`scripts/entity-management.lua`), with everything that implies for what a player builds
  and for ADR 0011's one-pool-per-segment claim.
- **Everything else about native heat works and is roomy.** Exact Lua writes, cadence-insensitive,
  real consumers run, and throughput is 4.5× to 7.5× what the reactor makes through stock pipes.
- **Two prototype fields have to be handled, not merely set:** `consumption` (or
  `scale_energy_usage`), and the buffer's ceiling.
- **A heat buffer banks far more than today's energy box does.** `(1000 − 15) °C × 10 MJ/°C` is
  9.85 GJ, about 74 seconds of a reactor's full output, where the shipped 1000-unit
  `rf-reactor-energy` box at 1 MJ a unit holds 1 GJ, about 7.5 seconds. Whether banking a minute and
  a quarter of output is desirable is a balance question, not a capability one — and
  today's policy of discarding the overflow (`control.lua`) has a direct analogue in a temperature
  that simply clamps at `max_temperature`.
- **At the mod's cadence the resolution is fine:** 133 MW for 6 ticks is 13.3 MJ, which is 1.33 °C
  on a 10 MJ/°C buffer — nowhere near the rounding trouble that `MIN_FLUID` exists for on the fluid
  side.

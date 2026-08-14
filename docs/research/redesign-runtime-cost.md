# The redesign's runtime cost — the "45 ms per reactor" claim

The only performance number that exists for the redesign's fusion simulation is a figure its author
posted in 2022: **~45 ms per reactor**. Taken at face value it means a single reactor cannot run at
60 UPS. It has been quoted at the mod ever since and was never resolved by the author.

This note establishes what that number was measured against and what it does and does not tell this
project. It bears on [ADR 0005](../adr/0005-real-time-fusion-simulation.md)'s standing obligation to
**measure UPS rather than assume it**, and on the prediction recorded in
[ADR 0011](../adr/0011-per-reactor-simulation-fluid-coupled.md) that per-reactor simulation is cheap
enough. **It discharges neither.**

**Facts only.** Where the evidence supports more than one reading, both are stated. Nothing is decided
here.

## Method and its limits

Two sources, read directly:

- The mod portal announcement thread *"About version 2.0."*, fetched 2026-08-14.
- The archived redesign as a **git clone**, so its history is available — which is what makes this
  answerable at all. Read at `%TEMP%\rfr-survey\realistic-fusion-dev`; the clone is temporary and may be
  garbage-collected, but every commit hash below is stable if it is re-cloned.

**Nothing was run and nothing was measured.** No attempt was made to reproduce the 45 ms, which would
require a 1.1 install, the mod loading, and a reactor operating. Every claim below is static analysis
plus commit history.

**Dating.** The portal shows relative dates only ("4 years ago"). The thread's identifier
`626322f706bc9f47b0984b15` encodes 2022-04-22, and the media repository linked from the first post was
pushed `2022-04-22T20:20:28Z`. The announcement is therefore dated **2022-04-22**, the same day as the
redesign repository's first commit.

## 1. The claim

From the announcement's feature list, on the reactors:

> Reactors will be using fully scripted actual simulations of fusion reactors, accounting for as many
> things as possible (within game balance limitations) **without significant performance loss (early
> tests show ~45ms per reactor on a Ryzen 5 2600)**

Note the unit: **per reactor**. This matters, and §3 explains why.

## 2. The contradiction the author never resolved

A player, Blackclaws, did the arithmetic immediately:

> if its 45ms per reactor that kind of already means its 22 UPS with just a _single_ of these reactors.
> […] we're already running at 30-40 UPS, so further slowdown seems like a no go.

The author's reply did not reconcile it:

> That 45ms value is what I get now, aka before I try to _properly_ optimize everything […] Either way,
> **45ms has absolutely no impact on the UPS at all** on my Ryzen 5 2600, so I have no idea what's
> happening there. **Maybe I'm just measuring it differently?**
>
> […] I'm running a few calculations every tick and that's somehow taking the CPU several milliseconds
> when it should actually take **barely a few _micro_seconds at most**.

So the author reported a number, observed behaviour inconsistent with it, could not explain the gap, and
left it there. A third player, Aquilo, then proposed the mitigation this project later adopted
independently as ADR 0005:

> Try lowering the reactor processing frequency. […] let it work in static mode as long as there is
> enough fuel

It was never implemented. The final archived code still runs `on_tick`.

## 3. What existed on the day it was measured

The measurement predates almost everything the survey describes. From `git log`:

| Commit | Date | Subject |
|---|---|---|
| `ccd87d8` | **2022-04-22** | first commit — *the announcement is the same day* |
| `9bb932b` | 2022-04-25 | reformat RFC & RFP |
| `00813da` | 2022-05-04 | **implement basics of reactor/heater networks** |
| `b458373` | 2022-05-15 | add additional network logic & improve performance |
| `67a26c1` | 2022-05-31 | add heater GUI |
| `4ec0f34` | 2022-06-01 | add functionality to heater override |
| `46f8397` | 2022-10-09 | **finish heater & reactor GUI** |
| `22fa69f` | 2022-11-20 | **Make reactor simulation work** |

Three consequences:

1. **The measured code was per reactor, not per network.** `reactor-logic.lua` at `ccd87d8` is
   `return function(reactor, current_tick)` and indexes `reactor.guis.bars` throughout. Networks arrive
   twelve days later. This is why the author wrote "per reactor" — at that moment it was literally true.
   The unit of simulation in the measured version is **the same unit
   [ADR 0011](../adr/0011-per-reactor-simulation-fluid-coupled.md) chose for v1.**
2. **The simulation was not finished.** "Make reactor simulation work" is nineteen months after the
   measurement. Whatever was timed in April 2022 is not the ~311-line reactor logic the survey read.
3. **The cross-section data was already complete** at the first commit — the processed reactivity JSON
   for all ten channels, the raw ENDF source, `.raw-to-reactivity.py`, and a Rust plotter. The data was
   never the unfinished part.

## 4. What the measured code did every tick

`reactor-logic.lua` at `ccd87d8` is 292 lines and calls `update_gui_bar` **ten times inside the per-tick
simulation path**, plus a further direct loop over `reactor.guis.bars`. The final archived version raises
this to eighteen calls. The function, verbatim at `ccd87d8:106-117`:

```lua
local function update_gui_bar(reactor, name, max, unit, value)
    if reactor.systems == "right" then
        value = value or reactor[name]
        for idx, v in pairs(reactor.guis.bars) do
            local new_name = name:gsub("_","-")
            if v[new_name] and v[new_name].valid then
                v[new_name].value = value/max
                v[new_name].parent["rf-"..new_name.."-value-frame"]["rf-"..new_name.."-value"].caption = string.sub(value, 1,6)..unit
            end
        end
    end
end
```

Per call, per GUI, per tick: a `gsub` allocating a new string; a `.valid` check; a `LuaGuiElement` write;
three string concatenations building element keys; two further element lookups through `.parent`; a
number-to-string coercion; and a `.caption` write. Each `LuaGuiElement` property access crosses the
Lua↔C++ boundary.

Against that, the physics in the same function is cross-section interpolation — which caches the last
table index, so the common case is a ±1 comparison rather than a binary search — plus float arithmetic
over four species.

**The guard is `reactor.systems == "right"`, which means "reactor switched on", not "a GUI is open".**
The calls therefore happen every tick regardless; the inner loop is empty when no player has the GUI
open, and does the full work above when one does.

## 5. Readings

**Reading A — the 45 ms was dominated by GUI element writes.** Supported by: ten GUI-updating calls in
the per-tick path against a few dozen float operations of physics; the known cost of `LuaGuiElement`
access; and the fact that the author measured while showcasing the GUI (the announcement embeds a video
of it) but played with it closed. Under this reading **both of the author's statements are true at
once** — 45 ms with the GUI open, no observable UPS impact with it closed — which is exactly the
contradiction he could not explain.

**Reading B — the measurement method was simply wrong or unstated.** The author's own suggestion
("Maybe I'm just measuring it differently?"). Nothing in the thread says what was timed, over how many
ticks, or with what tooling. A total across a run, or a figure including load time, would produce the
same mismatch. This reading cannot be excluded and cannot be tested — the measurement was never
described.

**Reading C — debug logging in the hot path — is eliminated.** The final code contains many
`print_log(serpent.block(...))` calls, and `print_log` does both `game.print` and `log`; serialisation
plus a disk write in a per-tick loop would dominate any other cost. **At `ccd87d8` there are zero live
`print_log`, `log` or `serpent` calls in `reactor-logic.lua`** — every one is commented out. This
reading is ruled out by the evidence rather than merely doubted.

A and B are not exclusive; the GUI could dominate *and* the figure be poorly derived.

## 6. What this means for v1 — and what it does not

**What transfers:**

- **The measured unit matches ours.** The number was taken against per-reactor simulation, which is what
  ADR 0011 chose. It is not made irrelevant by the network model that followed it.

**What does not transfer:**

- **v1 has no GUI.** [ADR 0010](../adr/0010-v1-module-layout-and-prototype-set.md) surfaces the
  simulation through entity status, tooltips and circuit signals. If Reading A is right, the dominant
  term in the only existing measurement is absent from v1 by construction.
- **v1 runs one reaction per reactor.** The redesign evaluated seven channels against a shared mixed
  plasma every tick; ADR 0010 gives each reaction its own plasma fluid, so a reactor interpolates once.
- **v1 may throttle.** ADR 0005 pre-authorises `on_nth_tick`; the redesign never used it, though a
  player proposed it in this very thread.
- **v1 is written fresh.** ADR 0004 — none of this code is inherited, so none of its costs are either.

**What is not established, and must still be measured:** the actual per-reactor cost of v1's simulation,
on a real factory, at scale. ADR 0005's obligation stands untouched. This note explains away the one
alarming prior datapoint; it does not replace it with a reassuring one, and no measurement of any version
of this simulation exists — the redesign's code was never observed running by anyone but its author, and
his figure is the one under examination.

## What this does not close

1. **The 45 ms was not reproduced.** Doing so needs a Factorio 1.1 install, the redesign loading, and a
   reactor operating. Whether the April 2022 tree even loads is untested.
2. **The measurement method remains unknown.** Reading B cannot be closed from the available evidence.
3. **`LuaGuiElement` access cost is asserted from general knowledge, not measured here**, and is not
   quantified against the physics in the same function. The claim is that it dominates; the ratio is not
   established.
4. **Nothing is known about the redesign's cost at scale** — the figure is for one reactor, and no
   statement exists about ten or a hundred.
5. **The `--TODO premultiply reactivities to reduce runtime cost` optimisation was never done**, so even
   the final code is unoptimised by its author's own reckoning.

### Sources

- <https://mods.factorio.com/mod/RealisticFusionPower/discussion/626322f706bc9f47b0984b15> — the
  announcement thread, fetched 2026-08-14. Quotes above are verbatim.
- Archived redesign, git clone at `%TEMP%\rfr-survey\realistic-fusion-dev`; commits `ccd87d8`,
  `00813da`, `46f8397`, `22fa69f`. Re-clone from the URL in `README.md` if absent.
- `RealisticFusionPower/scripts/reactor-logic.lua` at `ccd87d8` and at the final archived state.
- Prior surveys: [`predecessor-survey.md`](predecessor-survey.md),
  [`port-and-original-inspection.md`](port-and-original-inspection.md).
- Decisions this bears on: [ADR 0005](../adr/0005-real-time-fusion-simulation.md),
  [ADR 0010](../adr/0010-v1-module-layout-and-prototype-set.md),
  [ADR 0011](../adr/0011-per-reactor-simulation-fluid-coupled.md).

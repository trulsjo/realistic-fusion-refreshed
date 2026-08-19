# The reactor control GUI Romner built, and what it would cost here

Read 2026-08-19 against
[#37](https://github.com/trulsjo/realistic-fusion-refreshed/issues/37). Two sources: a 2:12 screen
recording Truls supplied at `C:\src\factorio\_reference\gui_prototype_showcase.mp4`, and the GUI's
source in the archived four-module redesign —
`RealisticFusionPower/scripts/gui.lua` (672 lines), `gui-events.lua` (370) and `reactor-logic.lua`
(355), at <https://github.com/4881e05257b099383da78c50269d2ceb/realistic-fusion-dev>.

The short version: **the GUI exists, it is liftable, and three of its four levers are nearly free
here while the fourth reaches into ADR 0011's state model.** The recording is not the archived HEAD —
it can be dated to a specific commit, four months before the last GUI work.

**It is Factorio 1.1 code.** The redesign's "2.0" is its own version number, the collision `CLAUDE.md`
warns about. None of this ever ran on Factorio 2.0.

**The layout is not a target, and was never offered as one.** Romner published the recording with the
caveat *"Fully interactive GUI, here's how the current prototype which doesn't represent the final
version at all looks like"* — quoted by Truls, 2026-08-19, who is likewise not committed to a GUI that
looks like this. So read everything below as an inventory of **which variables a player was given and
how they were wired**, not as a specification of windows, columns or widgets. The panel arrangement,
the slider-plus-notches idiom and the torus render are all incidental; the variable set and the
control model are the part worth keeping.

## What the recording shows

One window — `gui.lua` asks for `{1080, 490}`, and the recording is 1080 px wide, which is how the
two were matched. Titled **Fusion reactor control**, with a **Manual** button in the title bar. It is
a **per-network** dashboard, not per-entity: reactors and heaters joined by magnetic confinement pipe
are one machine, and when several exist the window first offers a picker (`Network #k` → `Open`).

| Group | Controls |
|---|---|
| Master switches | `Systems`, `Magnetic field`, `Heating` — each OFF/ON |
| Left sliders | `Plasma heating`, `Magnetic field strength`, `Plasma flow speed` — 0–100% |
| Right, per species | Deuterium, Tritium, Helium-3: an **input** slider *and* a **removal** slider each, plus an `in plasma` readout in m³ |
| Right, ash | `Helium-4 in plasma` — readout only, no input or removal |
| Left readouts | `Fusion rate`; `Energy input` MW; `Energy output` MW |
| Left readouts | `Total plasma`; `Plasma density`; `Plasma temperature` M°C |
| Centre | `INTERNAL REACTOR WALL INTEGRITY` bar over a rendered plasma torus whose brightness tracks state |

Behaviour visible across the frames:

- **Energy input has a floor.** ~120 MW at 0% heating, rising about 10 MW per percent — 13% → 249 MW,
  31% → 429 MW, 41% → 530 MW. The code says why:
  `energy_in = (heater_power/60 + max_field_strength/100*magnetic_field_strength + divertor_strength/5)*60/1e6`,
  plus `systems_consumption` whenever `Systems` is on. Compare #37's finding that our own reactor
  never stops paying a 50 MW heating bill: his had the same shape, and showed the player the number.
- **Peak 1398 MW output at 411 M°C**, with deuterium and tritium input both at 100.
- **Dilution is visible.** Cutting heating to 0% while pushing deuterium input walks the temperature
  down 411 → 128 → 94 → 39 → 8 M°C as cold gas enters a fixed heat budget.
- **The integrity bar goes red** near the end, then everything reads `OFF` when `Systems` is switched
  off.

## Dating the recording

Its left column reads `Fusion rate` **and** `Plasma density`. That pair exists at exactly one commit:

| Commit | Date | Change |
|---|---|---|
| `46f83971` finish heater & reactor GUI | 2022-10-09 | `Fusion rate` + `Plasma density` (`u/m³`) — **this is the recording** |
| `22fa69f5` Make reactor simulation work | 2022-11-20 | `Plasma density` → `Plasma volume` (`m³`) |
| `ad7ee3c9` Add He-4 control to & remove fusion rate from GUI | 2022-11-20 | `Fusion rate` dropped; He-4 gains input/removal |
| `3eb3f957` Update GUI & fix crashes | 2023-03-17 | last GUI work |
| `77043677` Add shortcut for remote reactor control | 2023-04-01 | last code commit in the repo |

Two dead readouts corroborate it: `Fusion rate` is 0 and `Plasma density` is 50 in **every** frame,
and the recording predates "Make reactor simulation work" by six weeks. The shell was finished before
the model behind it was. **The archive is therefore four months ahead of the recording** — the copy we
can read is the more complete artefact, not the less.

This also revises `predecessor-survey.md`, which recorded the redesign's simulation and GUI as
"entirely unverified" because nobody had run it. The recording is Romner running it. It does not
verify the archived HEAD, but it does establish that this GUI worked, at that commit, to the extent
shown.

## How his model differs from ours

**His keeps a composition vector; ours keeps a fluid prototype.** That single difference is the whole
of the difficulty.

`reactor-logic.lua` holds `network.deuterium`, `.tritium`, `.helium_3`, `.helium_4` as unit counts and
runs **all seven channels every tick** — `dd_t`, `dd_he3`, `dt`, `dhe3`, `tt`, `the3`, `he3he3` — with
mix-weighted heat capacity (`c.d_heat_capacity * network.deuterium + …`) and per-species consumption
bookkeeping written back each step. Species mix is state, and the sliders move it.

Ours encodes reaction identity in the plasma fluid: `scripts/reactor-logic.lua` reads
`fuel.fractions[1], fuel.fractions[2]` for the fluid in the box, so one fluid means one reaction at
fixed proportions, chosen by what the player piped in. Everything downstream — the recipes that make
`rf-d-d-plasma` and friends, [ADR 0011](../adr/0011-per-reactor-simulation-fluid-coupled.md)'s
per-reactor state, the signals in
[ADR 0012](../adr/0012-reactor-signals-need-a-companion-entity.md) — is built on that.

So the four levers do not cost the same:

| Lever | His implementation | What it needs here |
|---|---|---|
| **Magnetic field strength** | `plasma_volume = reactor_volume / (1 + magnetic_field_strength/9)` — a stronger field compresses the plasma, so density rises | `spec.volume_m3` is a constant (`1000`) used in two places: `density = particles / spec.volume_m3` and the reaction count. Make it a per-reactor runtime value. Cheap. |
| **Plasma heating** | `heater_power = Σ(override or plasma_heating) × heater_capacity/100`, with a per-heater override | `spec.heating_power_w` is a constant (`50e6`, `200e6` aneutronic), already read by `circuit-output.lua` as `rated_w`. Scale it. Cheap. |
| **Plasma flow speed** | writes `network.plasma_flow_speed` while the sim reads `network.divertor_strength` — **a half-finished rename, so at HEAD that slider does nothing** | fluid throughput is already a pipe property here. Cheap, and there is no working upstream implementation to copy. |
| **Isotope mix** | per-species input and removal sliders over the composition vector above | replaces "which fluid you piped in" with per-reactor species state, and reopens ADR 0011 plus the plasma-fluid recipes. **This is the hard one.** |

And one mechanic that is not a lever:

- **Wall integrity is a stub.** `network.wall_integrity -= network.plasma_temperature/5` every step
  whenever the plasma is hot, with no repair term and no dependence on magnetic field. It only
  decays, which is why the recording ends red. There is nothing here to lift; the bar is a UI element
  waiting for a model. We have no equivalent at all.

## What is already built here

- **Outputs as circuit signals exist.** ADR 0012's hidden `rf-reactor-signals` constant combinator
  sits at the reactor's position, borrows its selection box, and has runtime wire-drag redirection.
  Anything the GUI would display can already leave as a signal.
- **Control *inputs* from the network** would read the same entity's circuit network — the connection
  point is there; only the reading is missing.
- **Manual/auto already existed upstream**: `rf-manual-button` in `gui.lua`.
- **His access route was a shortcut**, `rf-reactor-control` — the very last commit in the repo, "Add
  shortcut for remote reactor control" — plus clicking `rf-m-reactor` or `rf-m-heater` directly. Not a
  building.

## Licensing

`RealisticFusionPower/scripts/` carries **no `license.txt` and no `legal-note.txt`**, so it falls under
the archive's root **WTFPL** — checked 2026-08-19 against the repo's file list. Under
[ADR 0001](../adr/0001-liftable-predecessor-material.md) the GUI Lua is liftable. It is 1.1-era code,
so a port is a port; and it is built around per-network state that ADR 0011 deliberately does not
have, so "liftable" is not the same as "droppable in".

Attribute **Romner_set** for anything derived from it, in the commit and in the file.

## What this does not settle

- **Whether any of it is wanted.** Scope is Truls's call. The GUI is not targeted for v1.
- **What the interface should look like.** Nothing here is a design: the author called his own version
  unrepresentative of the final one, and no final one exists. The dating work above establishes which
  build the recording came from, not that that build is the thing to aim at.
- **Whether wall integrity should exist**, and if so what drives it. Upstream has no answer to copy.
- **Whether the isotope-mix rewrite is worth its cost**, which is the ADR 0011 question and not a
  GUI question.
- **Whether the recording is the only artefact of that build.** The 2022-10-09 commit is the closest
  match found; no attempt was made to check out and run it.

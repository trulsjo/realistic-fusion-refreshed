# Does a `__base__` reference a mod names reach the dump?

Measured **2026-09-02** ([#197](https://github.com/trulsjo/realistic-fusion-refreshed/issues/197))
with `scripts/probe-dumped-reference.ps1` on **Factorio 2.0.77** (the Steam install
`factorio-lib.ps1` resolves by default), this repo's three mods plus one lane's mods, nothing else
enabled. **Facts only** — the documents these correct are
[#196](https://github.com/trulsjo/realistic-fusion-refreshed/issues/196), not this note.

## The question

`load-check.ps1`'s asset half reports every `__base__/...` path the **dumped** prototypes name that
is not on disk, whoever names it. So a lane loading a third-party mod that references a file
Factorio 2.0 removed goes red — which is how RITEG 1.3.11's
`__base__/sound/car-metal-impact.ogg` was found (#59).

`underground-pipe-pack` 2.0.6 writes the identical line, in a file its `data.lua` requires
unconditionally, and the `fluid` lane is silent:

```lua
vehicle_impact_sound = { filename = '__base__/sound/car-metal-impact.ogg', volume = 0.65 }
```

Two readings fit that. Either the check walks past the reference — a hole in `Find-MissingAssets` —
or the reference never reaches the dump the check reads. **From outside, the two are the same
silence.**

## Method

One `--dump-data` run per lane, with this repo's mods junctioned in beside the lane's, at the
ADR 0026 pins. The probe then reports three things off the one dump: how many times the path occurs
in the raw JSON text, which prototype holds it as a value and under which property, and how many
prototypes declare `vehicle_impact_sound` and how many declare `impact_category` as their own
top-level property.

The text count and the object-graph walk are arrived at differently on purpose. A text occurrence
with no prototype behind it would mean the string sits inside a longer value or under a key, and the
probe says so when the two disagree. They agreed in both lanes.

The Lua of both mods was read against the dumps rather than trusted from the ticket, because the
question is precisely where the two disagree.

## Results

| lane | dump | occurrences of `__base__/sound/car-metal-impact.ogg` | prototype | `vehicle_impact_sound` | `impact_category` |
|---|---|---|---|---|---|
| `fluid` | 15,557,569 chars | **0** | `pump/underground-mini-pump` | absent | `metal` |
| `riteg` | 13,893,996 chars | **1**, at `vehicle_impact_sound.filename` | `electric-energy-interface/RITEG-1` | **present, verbatim** | absent |

The census across each whole dump:

| lane | prototypes declaring `vehicle_impact_sound` | prototypes declaring `impact_category` |
|---|---|---|
| `fluid` | **0** | 219 |
| `riteg` | 1 — `electric-energy-interface/RITEG-1`, the only one | 133 |

Vanilla's own `pump/pump` carries `impact_category = metal` and no `vehicle_impact_sound`. The two
`impact_category` counts differ because the lanes load different third-party mods, not because the
engine behaves differently in them.

## What follows, stated as facts

- **The two prototype types treat `vehicle_impact_sound` differently, and that is measured on both
  sides.** The identical line is discarded on a `pump` and kept on an `electric-energy-interface`.
  The engine did not simply drop an unknown key, or RITEG's would have gone too.
- **`underground-mini-pump`'s `impact_category = metal` came from the engine, not from the mod.**
  The definition that wins is written from scratch — `prototypes/entities/underground-buildings.lua`
  line 256's `data:extend` replaces the earlier `deepcopy` of vanilla `pump` — and it names
  `vehicle_impact_sound` at line 324 and `impact_category` nowhere. So the field in the dump is the
  engine's substitution: **2.0.77 migrated `vehicle_impact_sound` to `impact_category` for the
  `pump` prototype type and not for `electric-energy-interface`.** The dump alone would not have
  settled that — reading the mod's Lua against it is what does.
- **`Find-MissingAssets` has no defect.** There is nothing in the `fluid` dump for it to miss: the
  string is not there, by either count. `fluid` is legitimately green and `riteg` legitimately red,
  from the same line of Lua.
- **A silent lane is not evidence that no such reference exists in its mods.** It is evidence that
  none reached the dump. Only reading the mod's Lua tells the two apart, and this probe is how the
  engine's half of the answer is taken.
- **The answer is about one engine version.** A later Factorio migrating `electric-energy-interface`
  too would turn the `riteg` lane green with no change in either mod, and every document repeating
  the table above would be wrong again, silently.

## Re-running it

```powershell
pwsh -File scripts/fetch-mods.ps1 -Set riteg
pwsh -File scripts/fetch-mods.ps1 -Set fluid
pwsh -File scripts/probe-dumped-reference.ps1 -AlsoModDirectory .mod-cache/riteg -Prototype electric-energy-interface/RITEG-1
pwsh -File scripts/probe-dumped-reference.ps1 -AlsoModDirectory .mod-cache/fluid -Prototype pump/underground-mini-pump
```

`-SelfTest` first if the probe itself has been edited. Its headline finding is a **zero**, and a
walk that visits nothing reports the same zero — that fault was in the first version of this script
and every array in the dump went unvisited. The self-test starts no game.

The path and the two field names default to the case above, so the recorded question is one command
per lane. `-Path`, `-Field` and `-ReplacedBy` ask a different one; the probe asserts nothing either
way and exits 0 whatever it finds.

## One number that moved, and why it is not a finding

The dump sizes are 61 characters larger in both lanes than the same measurement taken during triage
on 2026-08-31. The delta is identical in two lanes loading different mods, so it is this repo's
doing rather than the engine's: `2486990` added the `no-pipe-touching` opt-out to the pipe-to-ground
in between. Every counted quantity above is unchanged.

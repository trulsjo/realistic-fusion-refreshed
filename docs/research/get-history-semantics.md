# What PrototypeHistory reports in the cases the docs leave open

Measured 2026-08-29 ([#165](https://github.com/trulsjo/realistic-fusion-refreshed/issues/165)) with
`scripts/probe-get-history.ps1` on **Factorio 2.0.77** (the Steam install `factorio-lib.ps1`
resolves by default), base plus one generated canary mod, nothing else loaded. **Facts only** — the
attribution decision these feed is recorded on
[#164](https://github.com/trulsjo/realistic-fusion-refreshed/issues/164), not here.

## The question

[`LuaPrototypes::get_history(type, name)`](https://lua-api.factorio.com/2.0.77/classes/LuaPrototypes.html#get_history)
returns a [`PrototypeHistory`](https://lua-api.factorio.com/2.0.77/concepts/PrototypeHistory.html)
of exactly two fields — `created` (*"The mod that created this prototype"*) and `changed` (*"The
mods that changed this prototype in the order they changed it"*) — and
`docs/research/tech-tree-mod-attribution.md` (#158) records the two corners those one-liners leave
open: what `created` reports when a mod **redefines** an existing name via `data:extend`, and
whether a **same-value write** or a **mere read** lands the mod in `changed`.

## Method

One canary mod (`rf-history-probe`, generated into temp by the probe, never shipped) does six
things to six base items; `on_init` — fired by a `--create` run — reads `get_history("item", …)`
for each and reports via `log()` and `helpers.write_file`. The redefinition is a from-scratch
table under an existing base name (`stack_size = 543` as a marker), deliberately owing nothing to
base's definition, since silent replacement is exactly the case `name-check.ps1` exists to catch.

## Results

| Case | What the canary did | `created` | `changed` |
|---|---|---|---|
| fresh | `data:extend` a brand-new name | **rf-history-probe** | `[]` |
| redefined | `data:extend` a from-scratch table under `iron-gear-wheel` | **base** | `[rf-history-probe]` |
| modified | wrote `steel-plate.stack_size = 999` in data-updates | **base** | `[rf-history-probe]` |
| samevalue | wrote `copper-plate.stack_size` back to itself | base | `[]` |
| readonly | read `plastic-bar.stack_size`, wrote nothing | base | `[]` |
| untouched | never mentioned `iron-plate` | base | `[]` |

## What follows, stated as facts

- **The original mod stays `created` under wholesale redefinition; the replacer is recorded as a
  change.** A viewer that colours by `created` therefore always names the mod that first introduced
  the name, however completely a later mod replaced the definition.
- **`changed` records value changes, not writes and not reads.** A same-value write leaves no
  trace, so `changed` is free of the "touched but altered nothing" noise the research note worried
  about — a mod in `changed` altered at least one value.
- **A wholesale redefinition and a one-field tweak are indistinguishable in the history** — both
  read `created=base, changed=[canary]`. The history says *who* changed a prototype and in what
  order, never *how much*. Any display rule that wanted to promote a heavy modifier to owner would
  need evidence the API does not carry, which is the ground on which #164 chose to show creator as
  the attribution and the `changed` chain alongside, unranked.

## Limits

- Measured on items only, one canary, one engine version. Nothing suggests other prototype types
  differ, but that is inference, not measurement; the probe stays committed so any future engine
  version — 2.1 first among them — can be asked again.
- "Same-value write" was a scalar field. Whether replacing a *table* field with a structurally
  equal but distinct table also stays out of `changed` was not measured.

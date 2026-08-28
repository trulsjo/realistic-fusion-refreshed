# Attributing a dumped prototype to the mod that made it

`--dump-data` writes `data-raw-dump.json` — every prototype the loaded game ended up with — and not
one word about where any of them came from. A tool that wants to mark "this technology comes from
mod X" has to get that fact some other way. This note records the mechanisms that exist at
**Factorio 2.0.77**, what each returns, and what each costs. Raised by
[issue #158](https://github.com/trulsjo/realistic-fusion-refreshed/issues/158); the choice between
them is Truls's and is **not** made here.

**Facts only.** Every API claim is pinned to the 2.0.77 docs by URL, checked 2026-08-28 — not
`/latest/` (the experimental 2.1 branch) and not `/stable/`, both of which move. The one wall-time
figure was measured on this machine on the same date rather than estimated.

## 1. The engine already keeps the answer: `prototypes.get_history()`

The game records prototype provenance itself. The
[data lifecycle page](https://lua-api.factorio.com/2.0.77/auxiliary/data-lifecycle.html) says so in
as many words: *"Changes to prototypes during either stage are tracked and a history of which mod
has changed which prototype is recorded by the game."*

The access point at 2.0.77 is
[`LuaPrototypes::get_history(type, name)`](https://lua-api.factorio.com/2.0.77/classes/LuaPrototypes.html#get_history)
— *"Gets the prototype history for the given type and name"* — returning a
[`PrototypeHistory`](https://lua-api.factorio.com/2.0.77/concepts/PrototypeHistory.html) with
exactly two fields:

| Field | Type | Docs verbatim |
|---|---|---|
| `created` | `string` | *"The mod that created this prototype."* |
| `changed` | `array[string]` | *"The mods that changed this prototype in the order they changed it."* |

That is precisely the distinction a viewer wants: who added it, and who touched it afterwards, in
order. Two things the docs do **not** say:

- **What `created` reports when a mod redefines an existing name.** A second `data:extend` under a
  name the game already has silently replaces the first definition (the accident `name-check.ps1`
  exists to catch). Whether the engine reads that as the original mod still being the creator with
  the replacer in `changed`, or as the replacer becoming `created`, is not specified at
  [the concept page](https://lua-api.factorio.com/2.0.77/concepts/PrototypeHistory.html). Both
  readings are consistent with the one-line descriptions; a tool that cares would have to measure
  it.
- **How fine "changed" is.** Whether a mod that merely reads a prototype, or writes a field back
  with the same value, lands in `changed` is likewise unstated.

### What using it requires

`LuaPrototypes` is a **runtime-stage** class, reached through the global `prototypes`
([runtime index](https://lua-api.factorio.com/2.0.77/index-runtime.html): *"prototypes ::
LuaPrototypes: Allows read-only access to prototypes"*). Nothing at 2.0.77 exposes it to
`--dump-data`, which runs only the settings and prototype stages and exits —
[`LuaGameScript`](https://lua-api.factorio.com/2.0.77/classes/LuaGameScript.html) at 2.0.77 carries
no `get_prototype_history` either; the method lives on `LuaPrototypes` alone. So reading the
history means reaching the runtime stage: a map must exist and a control-stage script must run.

That is not a new kind of rig for this repo — it is the shape every gate here already has.
`scripts/load-check.ps1` creates a throwaway map with `--create` in an isolated mod directory,
which fires `on_init`, where its invariant checks run; the `scripts/check-*.ps1` rigs do the same
and then simulate. A history exporter is the same skeleton with a different `on_init` body: walk
the types of interest, call `prototypes.get_history(type, name)` per prototype, and write one JSON
file with
[`helpers.write_file`](https://lua-api.factorio.com/2.0.77/classes/LuaHelpers.html#write_file)
(*"Writes data to the `script-output` folder"*) plus
[`helpers.table_to_json`](https://lua-api.factorio.com/2.0.77/classes/LuaHelpers.html#table_to_json)
— the same `script-output` directory the dumps already land in, so the reading side is unchanged.

The cost is therefore **one `--create` run for the whole mod set, however many mods it holds** —
one launch, one prototype stage, one map creation. `load-check.ps1`'s header puts the check rigs at
minutes each, but those minutes are simulation; a bare create-and-exit is the cheap end of that
range. The result covers every prototype in one pass and names both creator and changers.

## 2. Differential dumps: what `name-check.ps1` already does, layered

`scripts/name-check.ps1` derives "which prototypes are this repo's" from two `--dump-data` runs —
with the repo's mods and without — keyed by **type and name** and carrying the serialised prototype
as the value, so an *added* prototype (in one dump only) is told apart from a *replaced* one
(in both, content differing). Its header is the reference for the method and for its limits.

Generalised to N mods the strategy is cumulative dumps in load order: dump with no mods, then with
mod 1, then mods 1–2, … — N+1 dumps. Load order is well-defined and dependency-sorted
([data lifecycle](https://lua-api.factorio.com/2.0.77/auxiliary/data-lifecycle.html): mods are
ordered by dependency chain depth, then natural sort of internal names), so every cumulative prefix
is a loadable set. A prototype is then attributed to the first layer whose dump contains it, and a
content change at layer k marks mod k as a modifier.

**Cost, measured:** one base-only `--dump-data` on this machine took **55.5 s** wall and wrote a
**26.5 MB** `data-raw-dump.json` (2026-08-28, 2.0.77, the Steam install `factorio-lib.ps1`
defaults to, isolated write-data as `Invoke-Factorio` sets up). Each dump is a full game launch
running the whole prototype stage, and large mods make that stage longer, so N mods cost roughly
N+1 launches of a minute or more each — against one launch for the runtime route.

**Attribution semantics, and the confound.** The clean story — first appearance names the creator,
content diff names the modifier — holds only if adding mod k changes nothing about what mods 1…k−1
emit. It does not hold in general, and `name-check.ps1`'s own header records why: *"An overhaul
that walks data.raw … reacts to prototypes this repo adds … Those land in the difference attributed
to this repo, because the difference is defined by our presence and cannot tell 'we defined it'
from 'they defined it BECAUSE of us'."* Concretely, measured in that script against K2 2.0.19
(2026-08-27): Krastorio 2's `flare_stack_lib.auto_generate()` loops the whole of `data.raw.fluid`
and generates `kr-burn-<fluid>` per fluid it finds — so K2's *own* prototypes appear or disappear
depending on which other mods are in the layer. Every mod's `data-updates.lua` and
`data-final-fixes.lua` re-run in **every** layer against a different set, so a later layer's diff
mixes three things: prototypes mod k defined, prototypes earlier mods generated because mod k is
present, and prototypes mod k generated from earlier mods' data. The dump records what a prototype
ended up as, never who wrote it (the same limit `name-check.ps1` states for its tooltip shape).

**When a later mod modifies an earlier mod's prototype**, layered diffing sees the name in both
layers with differing content, so name-first-appearance attributes it to the *creator* and the
content diff marks the *modifier's* layer. Which of those a viewer should print for "which mod adds
this tech" is a product question, not a fact: "adds" reads as the creator, but a mod that wholly
redefines a technology (new unit, new prerequisites, new effects) has arguably made it its own, and
the dump cannot rank the size of a change. `PrototypeHistory` draws the same line
(`created` vs `changed`) without deciding it either.

## 3. Scanning the mods' Lua for prototype names

Reading the set's source for `name = "..."` is the one mechanism needing no game at all, and the
repo already documents why it is evidence rather than proof. `name-check.ps1` uses exactly this as
its *secondary* instrument and states the failure modes in its header:

- **It under-collects wherever a name is built rather than written.** Concatenation and loops are
  normal Factorio style, not an edge case: K2 generates `kr-burn-<fluid>` and `kr-crush-<item>`
  names at data time from whatever `data.raw` holds (47 of them from this repo's 17 fluids and 30
  items, measured 2026-08-27) — none of those names appears anywhere in K2's source.
  `factorio-lib.ps1`'s `Find-MissingAssets` records the same lesson for icon paths: its first
  version scanned source for literals and *"would have reported a clean pass over the graphics this
  repo actually ships"* because paths are built by concatenation (`ENTITY .. name .. ".png"`).
- **It over-collects**, matching `name = "..."` in fields that are not prototype names — safe for a
  collision check (false alarm, not false pass) but wrong for attribution, where it invents
  prototypes a mod never defined.
- **It cannot see mutation.** `data-updates.lua`/`data-final-fixes.lua` edit *other* mods'
  prototypes without naming a new one: Space Exploration's `prototypes/phase-3/custom-tooltips.lua`
  walks `data.raw.fluid` appending tooltip rows to generators (recorded in `name-check.ps1` from
  the #129 lane); the RFP predecessor's `data-final-fixes.lua` is 281 lines of exactly this
  (`docs/research/port-and-original-inspection.md`), including definitions that exist only
  per-configuration — Durikkan's port defines `rfp-antimatter-fuel` only *"when Krastorio 2
  absent"*. A source scan attributes none of that, and which prototypes exist at all can depend on
  the rest of the set.

## 4. Nothing else at 2.0.77

- **The dump itself carries no provenance and cannot be asked for any.**
  [`PrototypeBase`](https://lua-api.factorio.com/2.0.77/prototypes/PrototypeBase.html) — the
  properties every prototype inherits — has no field recording the defining mod, so there is
  nothing for `--dump-data` to serialise. The
  [command-line parameters](https://wiki.factorio.com/Command_line_parameters) offer three dump
  flags — `--dump-data` (*"dumps data.raw as JSON"*), `--dump-icon-sprites`,
  `--dump-prototype-locale` — none with a provenance option.
- **`mod-list.json` and `info.json` dependencies** give the load order a layering strategy needs
  (section 2), and nothing more: they order mods, they attribute nothing.
- The history the engine keeps (section 1) is exposed **only** through the runtime
  `prototypes.get_history()`; no start-up-stage or command-line surface reaches it at 2.0.77.

## Sources

- `LuaPrototypes::get_history` — <https://lua-api.factorio.com/2.0.77/classes/LuaPrototypes.html>
- `PrototypeHistory` — <https://lua-api.factorio.com/2.0.77/concepts/PrototypeHistory.html>
- `LuaGameScript` (no history method at 2.0.77) — <https://lua-api.factorio.com/2.0.77/classes/LuaGameScript.html>
- Data lifecycle (stages, ordering, "history … is recorded by the game") — <https://lua-api.factorio.com/2.0.77/auxiliary/data-lifecycle.html>
- Runtime globals (`prototypes`) — <https://lua-api.factorio.com/2.0.77/index-runtime.html>
- `LuaHelpers` (`write_file`, `table_to_json`) — <https://lua-api.factorio.com/2.0.77/classes/LuaHelpers.html>
- `PrototypeBase` (no provenance field) — <https://lua-api.factorio.com/2.0.77/prototypes/PrototypeBase.html>
- Command-line dump flags — <https://wiki.factorio.com/Command_line_parameters>
- In-repo: `scripts/name-check.ps1` (differential method, its limits, the K2/SE measurements),
  `scripts/load-check.ps1` (the `--create` runtime rig shape), `scripts/factorio-lib.ps1`
  (`Invoke-Factorio`, the concatenated-path lesson),
  `docs/research/port-and-original-inspection.md` (predecessor `data-final-fixes` volumes).
- Dump timing: measured 2026-08-28 on this machine, base-only 2.0.77 `--dump-data`, 55.5 s / 26.5 MB.

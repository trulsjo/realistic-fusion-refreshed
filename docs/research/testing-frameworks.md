# In-game testing frameworks for Factorio mods

What exists for running tests **inside the Factorio client**, and which of it is alive, licensed usably,
and compatible with the 2.0.77 floor set by [ADR 0008](../adr/0008-factorio-version-floor-and-doc-pin.md).

The v1 spec ([issue #18](https://github.com/trulsjo/realistic-fusion-refreshed/issues/18)) **declined an
in-game harness for v1**, on the grounds that it would be a second framework standing up before there is
any code to test. This survey does not overturn that decision; it establishes what the option actually
costs, so that a later reconsideration starts from facts rather than from a guess.

**Facts only.** Version numbers, dates and licences are from the mod portal API, the GitHub and GitLab
APIs, and the projects' own READMEs, all checked 2026-08-14. Nothing was installed or run.

## Method and its limits

Candidates were found by searching GitHub and GitLab and by querying the mod portal API for named mods.

**The survey is not exhaustive, and one candidate was missed on the first pass.** FUnit — which this note
concludes is the strongest fit — did not appear in any GitHub search, because it is hosted on **GitLab**
and its mod portal category is `internal`. It surfaced only when its portal URL was supplied directly.
The mod portal API offers no text search over titles and summaries, so any framework whose name was not
guessed and whose code is not on GitHub can still be absent from this list.

**Nothing here was installed, and no test was run.** Every claim about how a framework behaves comes from
its documentation, not from observation.

## 1. FUnit — the strongest fit

[Portal](https://mods.factorio.com/mod/funit) · [GitLab](https://gitlab.com/jfletcher94/funit) · owner
`thremtopod` · **LGPL-3.0-or-later**

| | |
|---|---|
| Releases | 14, from 0.1.0 (2026-04-03) to 1.0.0 (2026-06-24) |
| Last 2.0 release | **0.5.3**, 2026-06-20, `factorio_version 2.0`, `base >= 2.0.76` |
| Current release | 1.0.0, 2026-06-24, `factorio_version 2.1`, `base >= 2.1.7` |
| Repo activity | last activity 2026-08-07 |
| Reach | 13 portal downloads; 0 stars, 0 forks |

### Tests live in a scenario, not in the mod under test

```lua
-- <mod>/scenarios/<test-scenario>/control.lua
local runner = require("__funit__.test_runner")
runner.register("realistic-fusion-refreshed")   -- validates the mod is active; does not modify it
runner.report("123")                 -- optional: funit-report-123.json in script-output
runner.test("name", function() ... end)
```

`register` only checks that the named mod is loaded. Tests run automatically when a game is created from
the scenario, or when a save of that scenario is loaded. **Nothing is added to the shipped mod's
`control.lua`.**

### API

- `register`, `test`, `report` — report is JSON, written to the
  [`script-output` directory](https://wiki.factorio.com/Application_directory#User_data_directory).
- `before_each`, `after_each`.
- `runner.assert` — **use it rather than Lua's built-in `assert`**, which FUnit reports as `ERROR`
  instead of `FAILED`.
- `runner.log` — FUnit's log format, to both the in-game console and `factorio-current.log`.
- **`after_n_ticks_do(n, fn)`** and **`on_event_do(...)`** — run assertions after a tick delay or on an
  event.

**The tick-waiting primitives are why this fits.** Under [ADR 0005](../adr/0005-real-time-fusion-simulation.md)
and [ADR 0011](../adr/0011-per-reactor-simulation-fluid-coupled.md) v1's runtime behaviour is *temporal*:
plasma heats over ticks, reaction rate follows temperature, Q-factor settles. "Place a reactor, feed
plasma, run 600 ticks, assert the temperature rose" is the shape of nearly every runtime test this
project would want, and `after_n_ticks_do` is that primitive directly. Nothing equivalent appears in
factorio-test's documentation.

### Built for CI

- **Headless Factorio server in Docker**, via [factorio-docker](https://github.com/factoriotools/factorio-docker).
- `entrypoint.sh` — configurable runner that syncs mods and mod settings and runs multiple suites.
- **JUnit-style XML** from the JSON reports, via a Ruby script (`scripts/parse_funit_json.rb`).
- `.gitlab-ci.yml` — the maintained pipeline template.
- `.github/workflows/funit.yml` — described by its own README as *"a WIP that is less actively
  maintained, and may not be up to date"*. **This repository is on GitHub, so the less-maintained half is
  the relevant half.**

### Licence, checked because ADR 0001 requires it

LGPL-3.0-or-later, with an explicit exception stated in the README: CI configuration files may be freely
copied with project-specific tweaks without triggering the copyleft obligation, so long as the changes
are project-specific rather than general improvements.

FUnit would be a portal dependency rather than vendored code, and test scenarios would link against it —
the case LGPL exists to permit — so [ADR 0001](../adr/0001-liftable-predecessor-material.md)'s rule that
copyleft material lives in its own directory with its licence file is not engaged by depending on it.
**This is a reading, not a legal opinion**, and it would need confirming before any FUnit code were
copied rather than required.

### Documentation

The author has written the approach up at The Foundry:
[Part 1: Creating Automated Tests](https://www.foundrygg.com/blog/automated-testing-1),
[Part 2: Running Tests in CI Pipelines](https://www.foundrygg.com/blog/automated-testing-2).

## 2. factorio-test — the established alternative

[Portal](https://mods.factorio.com/mod/factorio-test) · [GitHub](https://github.com/GlassBricks/FactorioTest)
· **MIT**

| | |
|---|---|
| Releases | 10 |
| Last 2.0 release | **3.0.1**, 2026-01-25, `factorio_version 2.0` |
| Current release | 3.1.0, 2026-06-24, `factorio_version 2.1` |
| Repo activity | last push 2026-06-24; 12 stars |
| Reach | 203 portal downloads |

Runs tests **inside the game, with no mocking**. Busted-inspired syntax with luassert:
`describe` / `it` / `test`. **Plain Lua is supported**; TypeScript and TypeScriptToLua are optional.

Two integration points — nothing in `info.json`:

```lua
-- control.lua, in the mod under test
if script.active_mods["factorio-test"] then
    require("__factorio-test__/init")({ "my-first-test" }, {})
end
```
```bash
npm install -D factorio-test-cli
npx factorio-test run -p ./path/to/your/mod
```

The CLI launches Factorio and runs the tests; the guarded `require` is a permanent line in the shipped
mod's `control.lua`, inert when the test mod is absent.

## 3. Dead, or unusable

| Project | Status |
|---|---|
| [Testorio](https://mods.factorio.com/mod/testorio) ([repo](https://github.com/GlassBricks/Testorio)) | Superseded by factorio-test, same author. Last release 1.6.0, 2022-12-16, Factorio 1.1; last push 2023-04-22. |
| [Faketorio](https://github.com/JonasJurczok/faketorio) ([LuaRocks](https://luarocks.org/modules/jasonmiles/faketorio)) | MIT, 23 stars — but **last push 2019-05-09**, Factorio 0.17 era. Seven years stale. |
| [factestio](https://github.com/cmtonkinson/factestio) | Active (pushed 2026-04-05), Lua, "hierarchical scenario-based test framework" — but **no licence file at all**, so all rights reserved. Unusable regardless of merit. |
| [factorio-unit-test](https://github.com/modded-factorio/factorio-unit-test) | MIT, pushed 2025-09-17, 1 star, minimal. |
| [testing-resources](https://mods.factorio.com/mod/testing-resources) | **Not a framework** — cheat recipes for raw resource duplication. Factorio 0.17, 2019. |
| [factorio-check](https://pypi.org/project/factorio-check/0.0.9/) | Python-side helper. Marginal. |

## 4. Adjacent tooling, not test frameworks

- **[factoriomod-debug](https://www.npmjs.com/package/factoriomod-debug)** (justarandomgeek) — 2.1.9,
  released 2026-08-13. Debug adapter, mod packaging, drives Factorio from the CLI. Not a test framework,
  but the tooling the ecosystem actually standardises on.
- **[khaosdata-extractor](https://github.com/QuingKhaos/khaosdata-extractor)** — GPL-3.0, pushed
  2026-08-03. Extracts prototype data out of Factorio for validation and mocking. Relevant to the spec's
  *borrowed* load-check seam: it could turn "exit code 0" into "the prototype set matches
  [ADR 0010](../adr/0010-v1-module-layout-and-prototype-set.md)".

## 5. Both live frameworks have moved past our floor

FUnit 1.0.0 and factorio-test 3.1.0 **both jumped to `factorio_version 2.1` on the same day,
2026-06-24**. Pinned to base 2.0.77 by ADR 0008, this project would use FUnit **0.5.3** or factorio-test
**3.0.1** — in both cases the frozen tip of an abandoned 2.0 line.

FUnit 0.5.3 declares `base >= 2.0.76`, which 2.0.77 satisfies. factorio-test 3.0.1 declares
`factorio_version 2.0`; its `base` floor was not checked.

Should current test tooling ever become a reason to move to 2.1, that is a **revisit of ADR 0008**, not a
silent bump. ADR 0008 already says moving to 2.1 is a later decision to be taken when 2.1 is stable.

## What this does not close

1. **Neither framework was installed or run.** Every behavioural claim is from documentation.
2. **The survey is not exhaustive** — see Method. FUnit itself was missed on the first pass.
3. **factorio-test's tick-waiting support is unestablished.** The claim above is that none appears in the
   documentation read, not that none exists.
4. **factorio-test 3.0.1's `base` version floor was not checked**, only its `factorio_version`.
5. **Bus factor is 1 on both**, and both are small — 13 and 203 downloads respectively. FUnit is three
   months old. That is a real dependency risk and no mitigation is proposed here.
6. **The LGPL reading in §1 is not a legal opinion**, and covers only depending on FUnit, not copying it.
7. **Nothing is decided.** The spec's rejection of an in-game harness for v1 stands until it is revisited
   deliberately.

### Sources

- Mod portal API: `/api/mods/funit/full`, `/api/mods/factorio-test`, `/api/mods/testorio`,
  `/api/mods/testing-resources` — fetched 2026-08-14.
- GitLab API and raw files: `jfletcher94/funit` — `README.md`, `funit/README.md`.
- GitHub API: `GlassBricks/FactorioTest`, `GlassBricks/Testorio`, `JonasJurczok/faketorio`,
  `cmtonkinson/factestio`, `modded-factorio/factorio-unit-test`, `QuingKhaos/khaosdata-extractor`.
- <https://github.com/GlassBricks/FactorioTest/wiki/Getting-Started>
- npm registry: `factoriomod-debug`.
- Decisions this bears on: [ADR 0005](../adr/0005-real-time-fusion-simulation.md),
  [ADR 0008](../adr/0008-factorio-version-floor-and-doc-pin.md),
  [ADR 0011](../adr/0011-per-reactor-simulation-fluid-coupled.md), and the testing decisions in
  [issue #18](https://github.com/trulsjo/realistic-fusion-refreshed/issues/18).

# 8. Factorio version floor and documentation pin

Date: 2026-08-14

## Status

Accepted. Resolves
[Which Factorio 2.0.x is the minimum supported version?](https://github.com/trulsjo/realistic-fusion-refreshed/issues/13).

**Note added 2026-08-26 (#59, [ADR 0026](0026-third-party-mods-are-pinned-to-their-2-0-line.md)).**
Nothing below is superseded — `factorio_version` is still `"2.0"`, the floor is still
`base >= 2.0.77`, and the trigger this ADR set is still unfired: stable was 2.0.77 on 2026-08-14 and
is 2.0.77 today, while experimental went 2.1.14 → 2.1.16. What changed is that every overhaul family
shipped a `factorio_version` 2.1 release anyway, so the ecosystem moved before the trigger did. ADR
0026 answers what to check against in the meantime: the last 2.0 release of each family, pinned as
data. When 2.1 does become stable, both decisions come back together.

## Context

Checked against <https://lua-api.factorio.com/> on 2026-08-14:

- **Latest stable: 2.0.77**
- **Latest experimental: 2.1.14**

The question arose because Krastorio 2's current release (2.1.2, June 2026) declares
`factorio_version 2.1`, which looked like the ecosystem moving past 2.0. It is not — 2.1 is the
experimental branch, and mod authors routinely track it ahead of stable.

The only Factorio installed on the development machine is **2.0.77** — which is the current stable, and
therefore the only version anything here can actually be tested against.

Three values are in play, and they are not the same field:

- `factorio_version` in `info.json` — which game series the mod is built for.
- The `base >=` dependency — the minimum patch version accepted.
- The version documentation and API claims are pinned to.

## Decision

**`factorio_version` is `"2.0"`.** The stable series, following
[ADR 0003](0003-space-age-tolerated-not-targeted.md)'s targeting of base 2.0. Moving to 2.1 is a later
decision to be taken when 2.1 is stable, not now.

**The dependency floor is `base >= 2.0.77`.** This claims exactly what can be verified: the current
stable, and the only version available to test on.

**Documentation and API claims pin to `/2.0.77/`.** `CLAUDE.md` already requires an explicit version and
forbids `/stable/` and `/latest/`; with `latest` currently resolving to the experimental 2.1.14, that
rule is doing real work rather than being a formality.

## Consequences

- **The claim matches the evidence.** This project has repeatedly declined to assert what it has not
  checked — Space Age support became an obligation to verify rather than an assumption
  ([ADR 0003](0003-space-age-tolerated-not-targeted.md)), and coexistence likewise
  ([ADR 0007](0007-coexistence-without-integration.md)). A floor of `2.0` would have claimed support for
  patch versions nobody will ever run the mod against.
- **Players on an older 2.0.x are excluded.** Accepted: stable auto-updates, so the affected group is
  small, and the alternative is a broader claim than the testing supports.
- **The floor does not need raising as stable advances.** When 2.0.78 or later becomes stable, `>= 2.0.77`
  keeps accepting it. This decision fixes a floor, not a target.
- **`/2.0.77/` will eventually go stale as a documentation pin.** That is the intended behaviour of
  pinning: a stale explicit version is visibly stale and can be rechecked, whereas `/latest/` silently
  changes meaning underneath a written claim.
- **A future move to 2.1** — raising `factorio_version`, re-pinning the docs, retesting — is its own
  decision for when 2.1 reaches stable. Nothing here forecloses it.

## Alternatives considered

**`base >= 2.0`.** The widest reach and what most mods declare. Rejected: it accepts patch versions that
will never be tested, and risks silently depending on API added after 2.0.0 without a guard. The claim
would have been broader than the evidence behind it.

**`base >= 2.0` with the tested-on version stated in the mod description.** Keeps reach while remaining
honest in prose. Rejected because the honesty then lives in text a player may not read, rather than in
the dependency the game itself enforces — the same reason
[ADR 0006](0006-clean-break-from-predecessor-saves.md) insists the save break be advertised rather than
buried.

# 28. A suppression rule reports on doubt

Date: 2026-08-31

## Status

Accepted. Decided by Truls on 2026-08-31, while grilling
[#194](https://github.com/trulsjo/realistic-fusion-refreshed/issues/194). Supersedes nothing; states a
rule [ADR 0007](0007-coexistence-without-integration.md)'s finding 3 had been leaving to
`scripts/name-check.ps1` to imply.

## Context

`scripts/name-check.ps1` reports a **replacement** when this repo changes the content of a prototype
the game or a set already defines. `Get-DerivedWiring` is the only code in that check which
*suppresses* such a finding, and it does so for differences a loaded set can be shown to have caused
rather than us.

**A replacement is a claim about authorship, not about difference** — settled on 2026-08-31 and now
in `CONTEXT.md`. That framing decides what a suppression rule is *for*: excusing what upstream did,
never merely quietening what a reader would rather not read.

It leaves one case unanswered, and the case is common. **The dump often cannot prove either party
wrote a difference.** It records what a prototype ended up as, never who wrote it. A technology of
theirs holding `unlock-recipe rf-brine-barrel` is equally consistent with the set sweeping our recipe
in and with this repo wiring our recipe into their technology; the two are byte-identical.

The file was already answering that question three times, and saying which answer was the rule in
none of them. The three are not three shapes: `Get-DerivedWiring` keys its `$SHAPES` on the field
that differs and recognises two, and the `effects` shape carries two stories under one predicate.
What follows counts **stories**, which is what the code records and prints.

- The **`unlock`** story suppresses on the strongest evidence available — the added effect names a
  prototype `Get-SetDerived` already attributed to the set, which could not exist unless the set
  made it.
- The **`rehomed`** story suppresses on weaker evidence that is still about the set — the added
  effect names a barrel recipe base Factorio generated from a fluid of ours, and the destination
  technology already carried base-generated barrel unlocks in the baseline. That second half is a
  pass of theirs visibly already running before we arrived.
- The **`tooltip`** story suppresses on evidence its own comment calls insufficient — *"authorship
  cannot be proved here the way the unlock shape proves it"* — using two weaker conditions and a
  written ceiling.

All three are defensible. What was missing was which is the rule and which is the exception, so
every new shape re-argued it from scratch.
[#191](https://github.com/trulsjo/realistic-fusion-refreshed/issues/191),
[#192](https://github.com/trulsjo/realistic-fusion-refreshed/issues/192),
[#194](https://github.com/trulsjo/realistic-fusion-refreshed/issues/194) and
[#195](https://github.com/trulsjo/realistic-fusion-refreshed/issues/195) each did.

## Decision

**When authorship cannot be shown either way, the check reports.**

Suppress only where the set's authorship is **positively shown**. A difference nobody can attribute
is a finding, and stays a finding. Implausibility of our authorship is not evidence of theirs.

**The `unlock` and `rehomed` stories both clear the bar**, on evidence of different strength. One
names a prototype only the set could have made; the other observes the set's own re-homing pass
already running on the destination technology. Both are positive observations about the set, and
neither excuses anything on the ground that our authorship seems unlikely — which is the move this
ADR rules out.

**The `tooltip` shape is the documented exception**, not a second policy. It suppresses on evidence
that does not meet this bar, it says so in its own comment, and it carries the upgrade path — a
source-level instrument that would record who called `add_custom_tooltip_field`. Any future shape
or story that cannot meet the bar must do the same three things or it does not ship: state that it
cannot, state what it therefore excuses, and state what would close the gap.

The bar is about **evidence**, not about volume. A rule may be narrow and still fail it, and a rule
may excuse many prototypes and still meet it.

## Consequences

**Standing red lanes are the price, and they are the cheaper mistake.** A lane red for a cause
recorded on its issue costs a reader a lookup. A suppressed finding that was really ours costs a
silent overwrite reaching a player, which is the exact failure `name-check` exists to prevent and
which no other gate can see.

**A new shape now has a bar to clear rather than a precedent to pick.** Before this, a shape author
could reach for the `unlock` story's rigour, the `rehomed` story's middle, or the `tooltip` story's
latitude, and cite any of them. Now only the last is an exception, and it must be argued for in the
terms above.

**It gives [#195](https://github.com/trulsjo/realistic-fusion-refreshed/issues/195) a default.**
That issue asks whether the check should learn a third shape — a set collecting a connection
category of **ours** into a vanilla prototype's list. A category of ours in their list is equally
consistent with either author, so under this ADR it reports unless someone finds evidence that is
about the set's own behaviour. The decision there is still Truls's; what changes is that the default
is now written down.

**It does not settle how a known-red lane is recorded.** Fourteen lanes have run and eight stand red.
That is the programme's problem across ADR 0007's table, and inventing a second suppression mechanism
inside a check that deliberately has one would be the wrong place to solve it — the same conclusion
#191 reached when it was two lanes.

**Where the rules live does not change.** ADR 0007's finding 3 says the conditions and their ceiling
belong in `scripts/name-check.ps1`, where they can be tested, not in an ADR. This ADR states the
principle that chooses between candidate conditions; it names no condition.

## Alternatives considered

**Suppress on doubt — excuse where our authorship is implausible.** Keeps the report short and would
have cleared five lanes without any of the work #194 produced. Rejected because "implausible" is a
judgement the dump cannot support and a human is not re-making each run: the rule would be excusing
prototypes on the strength of nobody having thought of a way we could have done it. That is an
argument from absence, and it fails in the one direction that matters — a real overwrite of ours
riding in behind a plausible upstream story, reported as a counted line, exit code 0.

**Say nothing and keep deciding per shape.** What the file did until now. Cheapest, and it produced
two coherent shapes. Rejected because the cost is paid every time: four issues have re-argued the
same question, and the answer drifted between them. A tie-break that lives only in precedent is one
a future author picks from rather than applies.

**Make the `tooltip` shape meet the bar instead of exempting it.** Consistent, and it would remove the
exception rather than bless it. Rejected as out of proportion: it needs a source-level instrument that
does not exist, to close a gap no lane has shown being exploited, on a shape whose worst case is a
tooltip row. The ceiling is written where the code is; that is enough until a lane says otherwise.

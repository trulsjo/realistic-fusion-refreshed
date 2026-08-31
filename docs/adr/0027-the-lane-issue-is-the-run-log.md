# 27. The lane issue is the run log

Date: 2026-08-28

## Status

Accepted. Decided by Truls on 2026-08-28. Supersedes nothing; refines how
[ADR 0007](0007-coexistence-without-integration.md) records the work
[#61](https://github.com/trulsjo/realistic-fusion-refreshed/issues/61) produces.

## Context

A coexistence **lane** produces two different things, and ADR 0007 had been storing them as one.

- A **verdict** — green or red per half, plus the cause triage: ours, upstream's, or a pin artefact.
  Durable, small, and exactly what ADR 0007's minimum commits to.
- A **run log** — candidate-name counts, prototype enumerations, which dumps were compared, what was
  and was not run. Evidence, and regenerable by re-running the lane.

The run log is what scales. Four lanes had put **309 lines into ADR 0007, 66% of the document**, while
its actual decision content sat at about 157 lines and static. Nine lanes remained. On that trajectory
the ADR reached roughly 1,140 lines at ~86% evidence, and the reasoning a reader comes for would be
the minority of the file.

The duplication was worse than the length suggested. **Each run log was being written three times** —
into the lane issue's comment, into ADR 0007, and into
`docs/research/mod-set-coexistence-targets.md` — with the issue comment consistently the fullest of
the three. That was not a side effect of the structure; it was the structure.

## Decision

**The lane's GitHub issue is the run log of record.** It is written once, there.

ADR 0007 keeps:

- a **verdict table**, one row per lane, with the cause triage stated *in* the row and a link to the
  lane issue;
- a **findings section** for what the lanes have established across the programme, which grows when a
  lane teaches something new rather than once per lane.

`docs/research/mod-set-coexistence-targets.md` keeps its short per-set note, which is a pointer and a
summary, not a second copy.

**Nothing is deleted from the ADR unless it is preserved in the new shape or verifiably present in the
lane's issue.** Anything in neither is posted to the issue first.

## Consequences

**The ADR grows by one table row per lane instead of ~75 lines.** It came down from 466 lines to under
200 in the migration, with decision content dominant again.

**The run detail sits outside the clone.** This is the real cost and it is accepted deliberately. Three
things make it tolerable:

- A lane is **re-runnable**, and the pins that make it reproducible — `scripts/fetch-mods.ps1`'s
  `$MOD_SETS` — are in the repo, as is every check it runs. The evidence is regenerable in a way a
  design decision is not.
- The repo already treats issues as citable record: ADR 0007, ADR 0026 and the research docs all link
  to them for context that has never been duplicated in-tree.
- What is durable about a lane — the verdict, and anything it taught — is in the ADR by construction,
  because that is what the two kept sections are for.

**If GitHub is lost, the run logs are lost.** The verdicts, the findings, the pins and the checks are
not. A reader who needs the evidence again re-runs the lane; a reader who needs to know what was
decided and why never leaves the repo.

**A lane that teaches nothing new adds one row.** That is the intended outcome, and it is why the
findings section is worded around lessons rather than lanes.

## Alternatives considered

**A new in-repo file, one section per lane.** Keeps everything in the clone and survives GitHub going
away. Rejected because it does not solve the actual problem: the same run log would still be written
twice, once in the issue and once in the file, and the duplication — not the location — is what made
the old shape expensive to maintain and prone to drifting out of sync.

**Fold the run logs into `docs/research/mod-set-coexistence-targets.md`.** One fewer file. Rejected:
that document is a derivation of which mods form which set, and is already 700+ lines. Run results are
a different subject, and it would inherit exactly the growth problem being solved.

**One file per lane under `docs/research/lanes/`.** Cleanest growth story, each file small. Rejected as
fourteen files holding what the issues already hold, and it fragments the cross-lane comparisons —
which have been the most valuable findings the programme produced.

**Keep lane records whole in ADR 0007 and accept the length.** The argument for it is real: a verdict
is only trustworthy because the measurement sat next to it, and a table row invites a reader to trust
a result whose evidence they cannot see. Rejected because the evidence is one link away rather than
absent, and because at fourteen lanes the ADR would document that lanes ran without making it possible
to find what they decided.

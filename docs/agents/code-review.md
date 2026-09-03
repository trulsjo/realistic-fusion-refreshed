# Code review — two rules this repository adds

Both are conventions layered on the `/code-review` plugin rather than changes to it; see *Why it is
written here rather than fixed at source* at the foot.

1. **[The threshold gates the comment, not the report](#the-threshold-gates-the-comment-not-the-report)** — decided by Truls, 2026-08-26, settling
   [#128](https://github.com/trulsjo/realistic-fusion-refreshed/issues/128).
2. **[Review the prose, not only the code](#review-the-prose-not-only-the-code)** — decided by Truls, 2026-09-03, after
   [#230](https://github.com/trulsjo/realistic-fusion-refreshed/pull/230).

## The threshold gates the comment, not the report

Decided by Truls, 2026-08-26, settling
[#128](https://github.com/trulsjo/realistic-fusion-refreshed/issues/128).

The `/code-review` workflow scores each candidate finding and drops anything below 80. **That filter
governs what gets posted to the pull request. It does not govern what gets told to the person who
ran the review.**

### The rule

**Report every finding that survived verification, whatever it scored.** Post to the PR only what
clears the threshold, exactly as the workflow says.

**A review that posts nothing must still say what it filtered.** Name each finding, its score, and
whether it was independently verified. A silent pass and a filtered pass must never look the same —
that is the whole point of this file.

**Do not re-score to get a finding published.** The threshold is deliberately conservative and stays
where it is. If a filtered finding matters, say so in the report and let a human decide; inflating a
score to route around the filter destroys the only signal the score carries.

### Why the threshold cannot be read as "these findings do not matter"

The rubric offers exactly five values — **0, 25, 50, 75, 100** — and the filter admits scores of 80
or more. So it admits exactly one of them. The effective rule is *score exactly 100*, and the 75
band, which the rubric itself defines as

> Highly confident. The agent double checked the issue, and verified that it is very likely it is a
> real issue that will be hit in practice … The issue is very important

is discarded by construction. A finding can be verified, important, and dropped.

**Measured, not assumed.** Across PRs #124, #126 and #127: ten findings, **zero posted, nine real
and subsequently fixed** — in `954338d`, `8fdbd24` and `971adef` respectively. Two were not nitpicks:
a mod-portal token surviving in PowerShell's `$Error` after the thrown message had been scrubbed
(scored 75), and an ADR justifying a scope decision with a fact true only of a mod version the same
ADR declines to target (scored 75, merged into a permanent decision record). Both were fixed only
because they were reported outside the workflow's own output.

## Review the prose, not only the code

Decided by Truls, 2026-09-03, after
[#230](https://github.com/trulsjo/realistic-fusion-refreshed/pull/230).

**Every gate in this repository checks machinery. None of them reads English.** `load-check.ps1`
proves the prototypes load and the invariants hold; `ship-check.ps1` proves the mods say what ADR
0003 and ADR 0006 oblige them to; `bench-reactors.ps1` refuses to report a figure from a rig it
cannot verify. Not one of them can tell whether the sentence beside a number says what the number
says. That gap is a review job, and it is where this repository's mistakes actually live.

### The rule

**Check every number in prose against a number in the diff, and do the arithmetic.** Not "does this
look plausible" — multiply it out. A percentage of a tick, a ratio between two measurements, a
share of a population: each is a claim with an arithmetic answer, and the answer is in the same
diff.

**Treat a quantifier as an instruction to enumerate.** "No run clears the floor", "every reactor
pairs", "the one sentence that did not need correcting" — a claim about *all* or *none* of a set is
checked by walking the set, never by agreeing with its tone.

**When a change supersedes a figure, grep the whole file for the old one.** A correction that lands
in three places and misses the fourth is worse than no correction, because the survivor now reads
as deliberate. If the change claims in its own body to have corrected a section, that claim is
itself reviewable.

**Review the fixed state, not just the original.** A second round on work that has already passed
review and verification is worth running, and this file exists because it found more than the first.

### Measured, not assumed

**#230 passed a first review, a full verification pass and a poison test of every gate it added,
and a second review then found four more defects — three of them wrong prose about correct
measurements.**

| finding | shape |
|---|---|
| "not one of the six ratios clears the 1.35× floor" | **falsified by a table two paragraphs below it in the same commit** — four of six do |
| #34's "20 to 50 reactors pays well under 1%" | 1.45% at fifty collected reactors, in the sentence that called itself the one needing no correction |
| the ADR's "at 2.5 µs neither lever is worth pulling" | a superseded figure left standing in a permanent decision record |
| the `-Mixed` blanket gate's threshold of literal `1` | a real code defect: a regression idling 109 of 110 blankets would have passed |

The first round of the same review had already caught the one that mattered most, and it was also
invisible to every gate: at the default `-Gap 5` a five-tile fitting reached half a tile into the
next row's pairing area, so **every reactor from row 1 on paired with the row above's fitting**. The
cost barely moved, so no figure looked wrong — and a complete set of measurements had to be thrown
away and re-taken. Nothing errored, and nothing could have.

**What that says about where to look.** Three of five defects across two rounds were claims rather
than code. This repository writes long prose deliberately — the reasoning is the deliverable, and
`CLAUDE.md` says verification here is by running the game rather than by reading. Both of those make
unchecked prose the most likely place for a wrong thing to survive, because running the game cannot
contradict it.

## Why it is written here rather than fixed at source

The workflow is a plugin, at `~/.claude/plugins/cache/claude-plugins-official/code-review/`. It is
not this repository's to edit, and editing a cache would be undone by the next plugin update. So
this is a convention, and `CLAUDE.md` points at it so a review session loads it before running.

Nothing about the scoring, the rubric or the 80 is changed, and neither rule asks the workflow to
do anything it does not already do. The first drops one assumption -- that a filtered finding is a
discarded one. The second adds one obligation the rubric never mentions, because a plugin that
reviews code cannot know that in this repository the prose is part of the deliverable.

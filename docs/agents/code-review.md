# Code review — the threshold gates the comment, not the report

Decided by Truls, 2026-08-26, settling
[#128](https://github.com/trulsjo/realistic-fusion-refreshed/issues/128).

The `/code-review` workflow scores each candidate finding and drops anything below 80. **That filter
governs what gets posted to the pull request. It does not govern what gets told to the person who
ran the review.**

## The rule

**Report every finding that survived verification, whatever it scored.** Post to the PR only what
clears the threshold, exactly as the workflow says.

**A review that posts nothing must still say what it filtered.** Name each finding, its score, and
whether it was independently verified. A silent pass and a filtered pass must never look the same —
that is the whole point of this file.

**Do not re-score to get a finding published.** The threshold is deliberately conservative and stays
where it is. If a filtered finding matters, say so in the report and let a human decide; inflating a
score to route around the filter destroys the only signal the score carries.

## Why the threshold cannot be read as "these findings do not matter"

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

## Why it is written here rather than fixed at source

The workflow is a plugin, at `~/.claude/plugins/cache/claude-plugins-official/code-review/`. It is
not this repository's to edit, and editing a cache would be undone by the next plugin update. So
this is a convention, and `CLAUDE.md` points at it so a review session loads it before running.

Nothing about the scoring, the rubric or the 80 is changed. Only the assumption that a filtered
finding is a discarded one.

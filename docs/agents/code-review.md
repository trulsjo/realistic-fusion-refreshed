# Code review — four rules this repository adds

All four are conventions this repository keeps around the `code-review:code-review` plugin rather
than changes to it; see *Why it is written here rather than fixed at source* at the foot.

**Three skills answered to `/code-review` in the session that wrote this, and this file means one of
them.** Which are installed is a fact about a machine and not about this repository.
`code-review:code-review` is the official plugin: five reviewers, then a scorer for each candidate
finding, and it needs a pull request. It is what this file calls **the plugin pass**, and what "the
workflow" and "the plugin" mean below.
`mattpocock-skills:code-review` and the built-in `code-review` both read a diff and need no pull
request, and neither is the plugin pass. Write the qualified name
when it matters which.

1. **[The threshold gates the comment, not the report](#the-threshold-gates-the-comment-not-the-report)** — decided by Truls, 2026-08-26, settling
   [#128](https://github.com/trulsjo/realistic-fusion-refreshed/issues/128); amended 2026-10-05 (#592).
2. **[Review the prose, not only the code](#review-the-prose-not-only-the-code)** — decided by Truls, 2026-09-03, after
   [#230](https://github.com/trulsjo/realistic-fusion-refreshed/pull/230); its third rule widened from
   the file to the repository on 2026-09-14, settling [#331](https://github.com/trulsjo/realistic-fusion-refreshed/issues/331);
   its last rule narrowed 2026-10-05 (#592); a rule for the notes' figure tables added 2026-10-06
   (#602).
3. **[A review that plants takes its own worktree](#a-review-that-plants-takes-its-own-worktree)** —
   [#311](https://github.com/trulsjo/realistic-fusion-refreshed/issues/311), after the review of
   [#309](https://github.com/trulsjo/realistic-fusion-refreshed/pull/309) on 2026-09-10.
4. **[One review before the pull request](#one-review-before-the-pull-request)** — decided by Truls,
   2026-10-05, settling [#592](https://github.com/trulsjo/realistic-fusion-refreshed/issues/592). It
   also changed wording in the first two, dated where it sits, and wrote the plugin's name out in
   full throughout. Since 2026-10-07 (#624) the table under it has a row for each branch and not
   for each pass on #579.

## The threshold gates the comment, not the report

Decided by Truls, 2026-08-26, settling
[#128](https://github.com/trulsjo/realistic-fusion-refreshed/issues/128). Where the findings under
the threshold are posted was changed on 2026-10-05, settling
[#592](https://github.com/trulsjo/realistic-fusion-refreshed/issues/592).

The `code-review:code-review` workflow scores each candidate finding and leaves anything
below 80 out of its comment. **That filter governs what the workflow's own comment carries. It does not govern what gets
told to the person who ran the review** — or, since 2026-10-05, what reaches the pull request.

### The rule

**Report every finding that survived verification, whatever it scored.** The workflow's own comment
carries only what clears the threshold, exactly as the workflow says. **Every other surviving
finding goes in a second comment on the same pull request, with its score** — so the pull request
holds the plugin pass's whole report, and not the transcript of the session that ran it. Until
2026-10-05 this said to post only what cleared the threshold. Sessions had been posting the rest
anyway — on #305, #309 and #361 in September, and on
[#579](https://github.com/trulsjo/realistic-fusion-refreshed/pull/579) as a comment of its own — and
#592 made that the rule.

**A review that posts nothing must still say what it filtered.** Name each finding, its score, and
whether it was independently verified. A silent pass and a filtered pass must never look the same —
that is the whole point of this file.

**Do not re-score to move a finding into the first comment.** The threshold is deliberately
conservative and stays where it is. If a filtered finding matters, say so in the report and let a
human decide; inflating a score to route around the filter destroys the only signal the score
carries. Until 2026-10-05 the rule kept a filtered finding off the pull request, and this was
written against re-scoring to get one published.

### Why the threshold cannot be read as "these findings do not matter"

The rubric offers exactly five values — **0, 25, 50, 75, 100** — and the filter admits scores of 80
or more. So it admits exactly one of them. The effective rule is *score exactly 100*, and the 75
band, which the rubric itself defines as

> Highly confident. The agent double checked the issue, and verified that it is very likely it is a
> real issue that will be hit in practice … The issue is very important

is discarded by construction. A finding can be verified, important, and dropped. Since 2026-10-05
(#592) read "discarded" and "dropped" as left out of the workflow's own comment: such a finding is
now posted in the second one.

**Measured, not assumed.** Across PRs #124, #126 and #127: ten findings, **zero posted, nine real
and subsequently fixed** — in `954338d`, `8fdbd24` and `971adef` respectively. Two were not nitpicks:
a mod-portal token surviving in PowerShell's `$Error` after the thrown message had been scrubbed
(scored 75), and an ADR justifying a scope decision with a fact true only of a mod version the same
ADR declines to target (scored 75, merged into a permanent decision record). Both were fixed only
because they were reported outside the workflow's own output.

## Review the prose, not only the code

Decided by Truls, 2026-09-03, after
[#230](https://github.com/trulsjo/realistic-fusion-refreshed/pull/230). Its third rule widened from the
file to the repository on 2026-09-14, settling
[#331](https://github.com/trulsjo/realistic-fusion-refreshed/issues/331). Its last rule, on the
fixed state, was narrowed on 2026-10-05, settling
[#592](https://github.com/trulsjo/realistic-fusion-refreshed/issues/592). The rule for a note's
`## Current figures` table was added on 2026-10-06 (#602).

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

**When a change supersedes a figure, grep the repository for the old one, and read every hit in a
file that records a measurement** — start in `docs/adr/` and `docs/research/`, where most of them
are, but the test is the kind of file and not the directory: `CLAUDE.md` records measurements, and
so does this one. A correction that lands in three places and misses the fourth is worse than no
correction, because the survivor now reads as deliberate, and a file the diff never opened is where
the survivor sits. If the change claims in its own body to have corrected a section, that
claim is itself reviewable.

**A hit inside a superseded block is not a defect; an unmarked old figure is.** The house style
keeps an old reading with a note saying what replaced it rather than restating it, so "find every
occurrence" and "change every occurrence" are not the same instruction. Read the hit, confirm the
block carries that note — a date, an issue number, or both — and move on. What the rule looks for
is an old figure still presented as current.

**This binds the reviewer.** All three escapes #331 records were reviewer misses on changes whose
own files were correct. An author who greps before opening the pull request saves a round, but the
obligation lives here, in the review.

**A change to a figure in a note changes its row in that note's table in the same commit.** Since
2026-10-06 (#602) seven notes under `docs/research/` open with a `## Current figures` table: the
headline figures the note stands behind, and a grid as a few of its cells or as counts, not the
note's every figure. A figure that moves in a section and not in its row leaves the old one at the
top of the note, presented as current. A figure a change supersedes loses its row.

**A gate holds part of this, and the review holds the rest** (#616). Section 10 of
`scripts/ship-check.ps1` fails a row whose Section link names no heading of its note, and a row
whose figure is written nowhere below the table. It cannot tell whether the row is the figure the
note currently stands behind: a superseded figure is still written in the note, marked, so it
passes. That is still read for.

**Review the fixed state, not just the original.** A second round on work that has already passed
review and verification is worth running, and this file exists because it found more than the first.
Since 2026-10-05 (#592) what is *required* of the fixed state is narrower than a round: the reviewer
that raised a finding confirms its fix. A full second round is the plugin pass, run when it is asked
for, and "the review" in this section's older sentences means whichever review is being run. **That
is a weaker check than the one this section measured.** Fresh eyes found #230's four, and a reviewer
confirming its own finding is not fresh eyes. It was chosen on what the plugin pass cost on one
branch, and the last rule of
[One review before the pull request](#one-review-before-the-pull-request) is how the difference is
meant to be made up.

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

**And the same shape again, one level up.** Three review rounds in one session on 2026-09-12 and
-13 each let a superseded claim through, and every one of them sat in a file the change never
opened while the change's own file was correct. Each was found by a reviewer reading a file outside
the diff — which the rule, as it then read, did not ask for. That is what widened it; see
[#331](https://github.com/trulsjo/realistic-fusion-refreshed/issues/331).

| round | what escaped | where it was |
|---|---|---|
| [#328](https://github.com/trulsjo/realistic-fusion-refreshed/pull/328), round 1 | 7.01 µs and 6.33 µs per reactor, and 8.41% of a tick, all inflated by the census walk | **ADR 0005** — the change edited `borrowed-base.md` and `bench-reactors.ps1` |
| [#328](https://github.com/trulsjo/realistic-fusion-refreshed/pull/328), round 2 | *"the rig control reproduces the record … 1.16×"*, a clean figure compared against a contaminated one | **`reactor-runtime-cost.md`** |
| [#329](https://github.com/trulsjo/realistic-fusion-refreshed/pull/329) | *"#235 is open … still that ticket's to settle"*, and the spike still called "the borrowed base's own Lua" | **`reactor-runtime-cost.md`** again |

The third scored 75 against the 80 posting gate partly *because* the rule said "file" — the scorer
noted the wording did not obviously reach across them.

**What that says about where to look.** Three of five defects across two rounds were claims rather
than code. This repository writes long prose deliberately — the reasoning is the deliverable, and
`CLAUDE.md` says verification here is by running the game rather than by reading. Both of those make
unchecked prose the most likely place for a wrong thing to survive, because running the game cannot
contradict it.

## A review that plants takes its own worktree

[#311](https://github.com/trulsjo/realistic-fusion-refreshed/issues/311), after five review agents
ran in parallel over [#309](https://github.com/trulsjo/realistic-fusion-refreshed/pull/309) in one
checkout on 2026-09-10.

### The rule

**Any review pass that modifies the working tree to test something does it in a worktree of its
own**, made first with `git worktree add --detach <dir> <head>` and removed afterwards. Planting a
violation to prove a gate fires is the usual case: the poison line goes into a tracked file, the
gate runs, the line comes out. In a shared checkout every other agent's gate run sees that line too.

**`git checkout -- <file>` on a shared checkout is unsafe while other agents are running.** It
reverts the file to the index, which removes every agent's uncommitted edit to it, not only yours —
a real fix in progress included. In your own worktree it is safe, which is the point of having one.

**Scratch files get the same treatment.** A probe script or captured output goes in a directory that
is yours alone — inside your worktree, or a temp directory with a unique name (`mktemp -d`, or the
session's scratchpad) — never a fixed path such as `/tmp/probe.lua` that a parallel agent may pick
too.

### The symptom, so the next reviewer recognises it

**A gate that fails once and then passes on every re-run, with nothing changed in between, is
another agent's plant, not a flaky gate.** Check `git status` and `git worktree list` before
investigating it. On #309 a third agent saw `1 of 178 checks failed` on its first run of
`ship-check.ps1` and `178 checks, 0 failures` on the next three, and reported a transient,
non-reproducible failure — it was a planted line-number citation of `ship-check.ps1` sitting
uncommitted in an ADR for one run. Another agent found that same plant in the file it was editing and
hand-reverted only its own two lines rather than `git checkout --` the file, so nothing was lost.
Two agents also wrote probe scripts to the same `/tmp` path in that run. The one agent that had made
its own worktree with `git worktree add --detach` saw none of it; that is the pattern.

### Whether `code-review:code-review` itself should carry it

**No, and nothing there can.** The plugin's own instructions launch five reviewers that read the
change, its blame, earlier pull requests and the comments on them, and the comments in the code it
touches; none of them is told to modify the tree,
so the plugin never plants. The plugin is also not this repository's to edit, for the reason the
next section gives. The rule binds whatever runs alongside it — a gate-poisoning pass, a review agent
asked to prove a finding — and that is why it lives here.

## One review before the pull request

Decided by Truls, 2026-10-05, settling
[#592](https://github.com/trulsjo/realistic-fusion-refreshed/issues/592).

### The rule

**Every branch gets one review, before its pull request exists.** This section and `CLAUDE.md` call
it **the pre-PR review**. One fresh subagent runs it, and it is defined by what the subagent
is handed and not by a skill's name:

- the diff against `main`;
- this file;
- on a branch that records measurements, the probes' raw output; on any other, the result of the
  gates that were run.

`/pre-pr-review` (`.claude/skills/pre-pr-review/SKILL.md`, #595) runs it: it holds the reviewer's
brief and the confirmation's as templates for the session to fill in. The list above is still the definition, and a review handed those
three things is the pre-PR review whatever started it.

**The reviewer that raised a finding confirms its fix.** Continue the same subagent and have it read
each fix against its own finding. That is a confirmation and not a second round. **A fix that adds a
sentence adds a claim, and the confirmation checks it like any other.** On
[#594](https://github.com/trulsjo/realistic-fusion-refreshed/pull/594), the change that wrote this
rule, one of the three findings the plugin pass posted was in a sentence a fix had added after the
pre-PR review, and the confirmation had passed it.

**Its findings go in the pull request's body, every one of them**, each with its score and whether
it was fixed. No pull request exists when they are made, so the body is the first place that can
hold them. [#579](https://github.com/trulsjo/realistic-fusion-refreshed/pull/579)'s body gave the
counts and the one finding left unfixed, and the eleven that were fixed are in no record. Decided by
Truls on 2026-10-05, after the plugin pass on #594 found the rule did not say.

**The plugin pass is run when it is asked for, and not otherwise.** It is the full second round.
When an implement skill says to close out with `/code-review`, in this repository that means the
pre-PR review, and no pull request is needed for it.

**The scoring step stays.** It is inside the plugin, so it runs whenever the plugin pass does. Every
surviving finding is reported whatever it scores, so the score decides only which comment a finding
is posted in — and it is still the step that verifies a candidate.

**A plugin-pass finding the pre-PR review missed gets its class named**, by the session that fixes it, in
the pull request. A class a script can detect becomes a section of `scripts/ship-check.ps1`. A class
that takes judgement becomes a line in this file. "One-off, no rule" is an answer, and it is written
down like the others. This is how the pre-PR review is meant to come to catch what today only the plugin
pass does.

### Measured, not assumed

[#579](https://github.com/trulsjo/realistic-fusion-refreshed/pull/579) was reviewed twice on
2026-10-05, and the rule was decided on that branch alone.
[#594](https://github.com/trulsjo/realistic-fusion-refreshed/pull/594), the change that wrote the
rule, had both kinds of pass later the same day, and
[#604](https://github.com/trulsjo/realistic-fusion-refreshed/pull/604),
[#605](https://github.com/trulsjo/realistic-fusion-refreshed/pull/605) and
[#607](https://github.com/trulsjo/realistic-fusion-refreshed/pull/607) had both on 2026-10-06. Each
is a row here, since 2026-10-07 (#624). Each count of findings is read from that pull request's
body and comments. The two rows with a cost have it from elsewhere: #579's is in #592's body, and
#594's is in the comment on #593 and in #595.

| branch | the pre-PR review found | the plugin pass found | plugin pass's cost: reviewers | plugin pass's cost: scorers |
|---|---|---|---|---|
| #579 | 12 findings: 11 fixed, one left unfixed at a score of 50 | eight candidates: seven fixed, one false positive | about ten minutes and about 400 000 subagent tokens for the whole pass, not split | not split: inside the figure to the left |
| #594 | nine findings: eight fixed, one left unfixed at a score of 50 | ten candidates: three posted at 100 and six more reported, so nine survived, of which eight fixed and one left unfixed and not scored; one false positive | not measured: the five reviewers ran as plain subagents, which report no usage | about 580 000 tokens |
| #604 | five findings: four fixed, one left unfixed at a score of 25 | three findings scored: two fixed, one left unfixed at a score of 25, its premise wrong; confirming the fixes raised a fourth point, fixed and not confirmed again | not recorded | not recorded |
| #605 | five findings: three fixed, two left unfixed at a score of 25 | two findings, at 100 and 75: both fixed | not recorded | not recorded |
| #607 | ten findings, one of them unscored: seven fixed, three left unfixed, one at 50 and two at 25 | four candidates: two fixed, two false positives | not recorded | not recorded |

The cost of the pre-PR review is recorded for none of the five. #604, #605 and #607 each say five
reviewers ran in the plugin pass, and none gives a time or a token count.

**Those five are every pull request from #560 on that had both kinds of pass**, counted 2026-10-07.
#568 and #582 had the plugin pass, and neither body carries a pre-PR review's findings.

**The session that runs the plugin pass on a branch adds that branch's row** (#624, 2026-10-07). A
figure that was not measured is written as not measured, one that covers the whole pass as not
split, and one the pull request does not give as not recorded. A figure with no record behind it is
not estimated.

**Once the table has five rows the rule is revisited, and the verdict is Truls's** (#624,
2026-10-07). It has five rows as of 2026-10-07, so that is due, and no verdict has been given.
[#593](https://github.com/trulsjo/realistic-fusion-refreshed/issues/593) is where the verdict will
be recorded.

**On #579 only the pre-PR review could check a figure against what a probe printed.** The plugin's
reviewers are given the change, its blame, earlier pull requests and the comments on them, and the
comments in the code it touches, and a probe's output is in none
of those.

**#579's seven were real, and all seven were small.** One commit fixed all of them and no figure moved.
The one that scored 100 was a temperature written without its exponent. The scorer gave the false
positive 0 — a claim that a table did not add up to its sum, which it does once rounded.

**#579's pre-PR review happened by accident.** The session read `/code-review` in the
`mattpocock-skills:implement` skill as the official plugin, which needs a pull request, and none
existed, so it improvised a reviewer. The `code-review` skill that ships beside `implement` needs no
pull request. That confusion is why the head of this file names all three.

## Why it is written here rather than fixed at source

The workflow is a plugin, installed in Claude Code's plugin cache on each machine and not in this
repository. It is not this repository's to edit, and editing a cache would be undone by the next
plugin update. So
this is a convention, and `CLAUDE.md` points at it so a review session loads it before running.

Nothing about the scoring, the rubric or the 80 is changed, and none of the four rules asks the
workflow to do anything it does not already do. The first drops one assumption -- that a filtered
finding is a discarded one. The second adds one obligation the rubric never mentions, because a
plugin that reviews code cannot know that in this repository the prose is part of the deliverable.
The third governs the passes that run beside the workflow rather than inside it. The fourth says
when the workflow is run at all, and what is run when it is not.

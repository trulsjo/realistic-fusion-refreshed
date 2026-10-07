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
   its last rule narrowed 2026-10-05 (#592), and what it says of the plugin pass changed 2026-10-07
   (#593); a rule for the notes' figure tables added 2026-10-06 (#602); a rule for the session
   that writes a fix added 2026-10-07 (#632), and widened on 2026-10-08 (#637) to a ticket's
   evidence and a retrospective's.
3. **[A review that plants takes its own worktree](#a-review-that-plants-takes-its-own-worktree)** —
   [#311](https://github.com/trulsjo/realistic-fusion-refreshed/issues/311), after the review of
   [#309](https://github.com/trulsjo/realistic-fusion-refreshed/pull/309) on 2026-09-10.
4. **[A review before the pull request, and the plugin pass after it](#a-review-before-the-pull-request-and-the-plugin-pass-after-it)** —
   decided by Truls, 2026-10-05, settling
   [#592](https://github.com/trulsjo/realistic-fusion-refreshed/issues/592), under the name "One
   review before the pull request". It also changed wording in the first two, dated where it sits,
   and wrote the plugin's name out in full throughout. Since 2026-10-07 (#624) the table under it
   has a row for each branch and not for each pass on #579, and two rules beside it say who adds a
   row and when the rule is revisited. Its rule on when the plugin pass runs was reversed by Truls
   on 2026-10-07, in his verdict on
   [#593](https://github.com/trulsjo/realistic-fusion-refreshed/issues/593), written here by #627:
   the pass runs on every pull request. The section's name changed with that, and the table gained a
   column for the findings that were serious. Since 2026-10-07 (#631) the table also has a column
   for what the pre-PR review cost, and the section says what a token figure in it measures.
   Since 2026-10-08 a second table gives what each pass used over all its requests (#634), and
   the section has two more rules for the session: what it does with the list of things the
   reviewer did not check (#636), and that a commit message is reworded when a review corrects
   what it says (#640).

**A rule is changed in this file** (2026-10-07, #630). `CLAUDE.md` and the intro of
`.claude/skills/pre-pr-review/SKILL.md` each stated parts of the four until then, so a rule that
changed had three files to change in: #627 edited all three to write one verdict. Both now name the
section to read and when to read it, and state no rule. The skill's steps are the pre-PR review's
procedure, and they still say what they carry out: what the reviewer is handed, that it confirms the
fixes of its own findings and reads a fix's added sentence as a new claim, that every finding goes
in the pull request's body, and that a planted change takes a worktree. A change to one of those is
made here first and then in the steps.

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
[#230](https://github.com/trulsjo/realistic-fusion-refreshed/pull/230). Its third rule widened from
the file to the repository on 2026-09-14, settling
[#331](https://github.com/trulsjo/realistic-fusion-refreshed/issues/331). Its last rule, on the
fixed state, was narrowed on 2026-10-05, settling
[#592](https://github.com/trulsjo/realistic-fusion-refreshed/issues/592). The rule for a note's
`## Current figures` table was added on 2026-10-06 (#602). What the last rule says of the plugin
pass was changed on 2026-10-07, when Truls's verdict on #593 had it run on every pull request. A
rule for the session that writes a fix was added on 2026-10-07 (#632), and widened on 2026-10-08
(#637) to the session that writes a ticket or a retrospective.

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
Since 2026-10-05 (#592) the reviewer that raised a finding confirms its fix, and from then until
2026-10-07 that was all that was *required* of the fixed state, which is narrower than a round. A
full second round is the plugin pass, and "the review" in this section's older sentences means
whichever review is being run. **That confirmation is a weaker check than the one this section
measured.** Fresh eyes found #230's four, and a reviewer confirming its own finding is not fresh
eyes. From 2026-10-05 the plugin pass ran only when it was asked for, a choice made on what it cost
on one branch. Since 2026-10-07 it runs on every pull request, so every branch gets the second round
as well as the confirmation; [A review before the pull request, and the plugin pass after
it](#a-review-before-the-pull-request-and-the-plugin-pass-after-it) has the verdict and what it
rests on.

**A fix is checked against its source before it is written, whoever supplied its words**
(2026-10-07, #632). An enumeration or a figure taken from a reviewer, from a finding or from an
earlier reply, is checked against its source before it goes into a fix, the same as one the author
worked out. This binds the session that writes the fix. On #625 the fix for the plugin pass's first
finding counted #601 among the pull requests that carry a pre-PR review's findings. The count was
copied from the pre-PR reviewer's own earlier enumeration, and #601's body says the review had not
been run. **A fix written after a review is the least-checked text on a branch**, and three more
pull requests show it. On #594 a fix added a false sentence and the confirmation passed it. On #607
a fix corrected one row of a group and not the others, and the confirmation passed that. On #628 two
of the plugin pass's five findings were what the fix for the pre-PR review's first finding had left
behind.

**A ticket's evidence and a retrospective's are read from their source the same way** (2026-10-08,
#637). Each is written after the work, from what the session remembers, and whoever acts on it
trusts it. A figure, or a claim about a past pull request, issue or commit, is read from that pull
request, issue or commit before the ticket is published or the retrospective's candidate is put
forward. That makes three kinds of text under one rule: a fix, a ticket and a retrospective.

- **A ticket: #632's own body.** It was written without opening the pull requests it cites and was
  wrong on two facts. It said a fix on #607 added a false sentence, where the fix corrected one row
  of a group and left the others. It said three of #628's five plugin findings came from one fix,
  where it was two. The session that implemented #632 opened the pull requests and wrote the right
  facts into the paragraph above, and the pre-PR reviewer on #633 checked them there. No rule asked
  for that: the ticket's evidence was read because the change restated it.
- **A retrospective: the one run on 2026-10-07 after #633.** It said the session "did nothing else
  with" the list of things the pre-PR reviewer had not checked. #633's body shows the session
  checked the three pull request bodies the reviewer named. The candidate's facts were read from
  the pull request before #636 was published from it, and #636 states what the body says.

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

## A review before the pull request, and the plugin pass after it

Decided by Truls, 2026-10-05, settling
[#592](https://github.com/trulsjo/realistic-fusion-refreshed/issues/592), under the name "One review
before the pull request". On 2026-10-07 he reversed the part of it that gave the section that name:
the plugin pass, which ran only when it was asked for, runs on every pull request. The verdict is in
[a comment on
#593](https://github.com/trulsjo/realistic-fusion-refreshed/issues/593#issuecomment-6037668590) and
was written here by #627.

### The rule

**Every branch gets a review before its pull request exists.** This section and `CLAUDE.md` call
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

**The session answers for each thing the reviewer says it did not check** (2026-10-08, #636). The
reviewer ends its report with that list. Before the findings table is written, and so before the
pull request is opened, the session takes each item and either checks it or sends it back to the
reviewer by name. **An item is checked as the sentence it concerns, and not only as the source the
reviewer named**: the sentence is read against that source, and against what it sits beside in the
file. The pull request's body says for each item which was done and what came of it. An item that
neither the session nor the reviewer can check is written there as left unchecked, with the reason.
On #633 the reviewer said it had not checked the bodies of #594, #604 and #605 for a pre-PR cost.
The session checked those three bodies, and the sentence the item was about, "none of the other six
pull requests records it", held against them. The plugin pass then raised that sentence at 100,
because it stood under a table in which the same change gave two of those six rows a figure.

**A commit message is reworded when a review corrects what it says** (Truls, 2026-10-07, #640).
When a finding corrects a figure or a claim, the session searches the branch's commit messages for
the old one, rewords each commit that carries it, and pushes with `git push --force-with-lease`.
That push is allowed on an unmerged branch only, and never on `main`: history already on `main` is
left alone. It is done before the pull request is opened where it can be, and before the merge
otherwise. A reword gives the commit and every commit after it a new hash and changes no file, so
the diff of the fixes is the same diff. **The session holds the reviewed commit by a local tag and
not by its hash.** The tag stays on the commit the reviewer read, which the reword leaves in the
repository beside its replacement, and the diff of the fixes is taken from the tag. On #633 the
measurement was first counted over 16 subagents, the pre-PR review showed there were 27, and this
file says 27. The body of commit `15b5b46` on `main` still says "on the 16 subagents of one
session".

**Every pull request gets the plugin pass, after it is opened** (Truls, 2026-10-07, #593). It is the
full second round. This holds for every pull request opened after the verdict was given on
2026-10-07, a documentation-only one included; #622 and #625 were opened earlier that day. From
2026-10-05 until then the rule was "the plugin pass is run when it is asked for, and not otherwise";
*Measured, not assumed* below has what ended it.

**The session sets aside the plugin's eligibility answer.** The plugin's first step can answer that
a change needs no review, and it did for #625 because that change was documentation only. The
session runs the pass anyway and says in the pull request that it did. No kind of change is exempt
(Truls, 2026-10-07, #593).

**The pre-PR reviewer confirms the plugin pass's fixes** (Truls, 2026-10-07, #593). Continue the
subagent that ran the pre-PR review and hand it the diff of the fixes, with no list of what was
done. If it is no longer running, a fresh reviewer confirms them and the pull request says so. On
#625 that reviewer found an error the fixes had added.

**When an implement skill says to close out with `/code-review`**, in this repository that still
means the pre-PR review, and no pull request is needed for it. The plugin pass follows once the pull
request is open.

**The scoring step stays.** It is inside the plugin, so it runs whenever the plugin pass does. Every
surviving finding is reported whatever it scores, so the score decides only which comment a finding
is posted in — and it is still the step that verifies a candidate. Whether it stays now that the
pass runs on every pull request is
[#626](https://github.com/trulsjo/realistic-fusion-refreshed/issues/626), which is open and Truls's.
The verdict of 2026-10-07 changed nothing about it.

**A plugin-pass finding the pre-PR review missed gets its class named**, by the session that fixes it, in
the pull request. A class a script can detect becomes a section of `scripts/ship-check.ps1`. A class
that takes judgement becomes a line in this file. "One-off, no rule" is an answer, and it is written
down like the others. This is how the pre-PR review is meant to come to catch what today only the plugin
pass does.

### Measured, not assumed

[#579](https://github.com/trulsjo/realistic-fusion-refreshed/pull/579) was reviewed twice on
2026-10-05, and the one-review rule was decided on that branch alone.
[#594](https://github.com/trulsjo/realistic-fusion-refreshed/pull/594), the change that wrote the
rule, had both kinds of pass later the same day, and
[#604](https://github.com/trulsjo/realistic-fusion-refreshed/pull/604),
[#605](https://github.com/trulsjo/realistic-fusion-refreshed/pull/605) and
[#607](https://github.com/trulsjo/realistic-fusion-refreshed/pull/607) had both on 2026-10-06.
[#625](https://github.com/trulsjo/realistic-fusion-refreshed/pull/625), the change that wrote this
table, had both on 2026-10-07, and so did
[#628](https://github.com/trulsjo/realistic-fusion-refreshed/pull/628), the change that wrote the
verdict below into this file, and
[#633](https://github.com/trulsjo/realistic-fusion-refreshed/pull/633), which gave the table its
column for the pre-PR review's cost. Each is a row here, since 2026-10-07 (#624). Each count of
findings is read from that pull request's body and comments. Two of the five rows with a cost for
the plugin pass have it from elsewhere: #579's is in #592's body, and #594's is in the comment on
#593 and in #595. The last column is a grade, made on 2026-10-07 for all eight rows, and the
paragraphs under the table say by what test.

| branch | the pre-PR review found | pre-PR review's cost | the plugin pass found | plugin pass's cost: reviewers | plugin pass's cost: scorers | of the plugin pass's fixed findings, serious |
|---|---|---|---|---|---|---|
| #579 | 12 findings: 11 fixed, one left unfixed at a score of 50 | not measured | eight candidates: seven fixed, one false positive | about ten minutes and about 400 000 subagent tokens for the whole pass, not split | not split: inside the figure to the left | one of seven: a temperature written without its exponent |
| #594 | nine findings: eight fixed, one left unfixed at a score of 50 | not recorded | ten candidates: three posted at 100 and six more reported, so nine survived, of which eight fixed and one left unfixed and not scored; one false positive | not measured: the five reviewers ran as plain subagents, which report no usage | about 580 000 tokens | four of eight: three false sentences that change wrote, and older wording it superseded and left standing |
| #604 | five findings: four fixed, one left unfixed at a score of 25 | not recorded | three findings scored: two fixed, one left unfixed at a score of 25, its premise wrong; confirming the fixes raised a fourth point, fixed and not confirmed again | not recorded | not recorded | one of two: a renamed heading that a tool finds its own section by |
| #605 | five findings: three fixed, two left unfixed at a score of 25 | not recorded | two findings, at 100 and 75: both fixed | not recorded | not recorded | one of two: "there is no CI" left standing in four places |
| #607 | ten findings, one of them unscored: seven fixed, three left unfixed, one at 50 and two at 25 | not recorded | four candidates: two fixed, two false positives | not recorded | not recorded | one of two: superseded figures in a research note left reading as current |
| #625 | 12 findings: ten fixed, two left unfixed at a score of 25 | 152 822 tokens, one reviewer | six candidates: five survived, four at 75 and one at 50, and all five fixed; one false positive | 325 398 tokens, five reviewers | 303 795 tokens, six scorers | none of five |
| #628 | ten findings: all ten fixed | 136 546 tokens, one reviewer | five candidates: two posted at 100, two more at 75 and one at 50, and all five fixed; no false positive | 375 765 tokens, five reviewers | 286 539 tokens, five scorers | two of five: the first routine row named by its ticket's number, and the cell beside #594 saying that change wrote wording it had left standing |
| #633 | 14 findings: 12 fixed, two left unfixed at a score of 25 | 162 435 tokens, one reviewer | two candidates: one posted at 100 and one more at 50, and both fixed; no false positive | 344 857 tokens, five reviewers | 119 402 tokens, two scorers | none of two |

The cost of the pre-PR review was not measured on #579, and none of the first seven pull requests
states one. Since 2026-10-07 (#631) `/pre-pr-review` has the session write it in the pull request's
body, and the table has a column for it. #633's row is the first written under that rule. #625's
and #628's rows were filled in on the same day from the transcripts of their reviewers, which the
session that ran both still had. Being filled in afterwards, those two were read after the
reviewer's last confirmation, where a row written by its own session is read before it, as the row
rule below says.
#604, #605 and #607 each say five reviewers ran in the plugin pass, and none gives a time or a token
count. #625's two figures are the usage its subagents reported; the three steps before its
reviewers, which check eligibility, list the `CLAUDE.md` files and summarise the change, used 133 423
more. #628's two figures are the same kind, and its three steps used 140 099. #633's are the same
kind again, and its three steps used 140 189.

**A reported figure is about the size of a subagent's last request, and not what the subagent used**
(measured 2026-10-07, #631). The plugin pass's subagents on #625 and #628 each sent a notice with a
token count when they finished, and every figure for those two passes is a sum of those counts. The
check was made on all 27 of them, whose counts sum to 1 565 019, which is the six figures given for
the two passes here. For each, the count was between 1.000 and 1.095 times the tokens of the agent's
last request and its response, and the sum over all the agent's requests was 1.7 to 6.4 times the
count. So a figure in the table says how large each subagent's context had grown, and it is a floor
on what the pass used. The pre-PR reviewer is reached by name, goes idle without finishing and sends
no notice, so its figure is its last request and response read from its transcript, the reading that
on the 27 was up to a tenth under the notice's count: 152 822 tokens on #625, where its 34 requests
sum to 3 979 750, and 136 546 on #628, where its 19 sum to 2 192 591. About nine tenths of each sum
is context read again from cache. The verdict's figure of about half a million tokens a pass rests
on #625's two in this unit and on two older ones. What #579's and #594's figures measure was not
checked, and the check does not explain why #594's reviewers reported no count.

**What each pass used over all its requests** (read 2026-10-08, #634). #625, #628 and #633 were
reviewed in one session, and its subagents' transcripts were still on its machine: 41 of them, 40
belonging to the three pull requests and one a probe of the usage notice. Each figure below sums,
over every request a subagent sent, the four token counts in that request's usage record: input,
output, cache write and cache read. They are read with the script in `/pre-pr-review`'s last step.
The five older rows of the table above have no transcript and
so no row here.

| branch | pre-PR review: its one reviewer | of that, cache reads | plugin pass: the three steps before the reviewers | plugin pass: reviewers | plugin pass: scorers | plugin pass: those three summed |
|---|---|---|---|---|---|---|
| #625 | 3 979 750 tokens in 34 requests | 89.7% | 293 110 tokens, three subagents | 1 022 849 tokens, five reviewers | 1 114 370 tokens, six scorers | 2 430 329 tokens |
| #628 | 2 192 591 tokens in 19 requests | 89.0% | 296 532 tokens, three subagents | 1 756 565 tokens, five reviewers | 877 709 tokens, five scorers | 2 930 806 tokens |
| #633 | 3 522 320 tokens in 26 requests | 90.2% | 301 140 tokens, three subagents | 1 198 669 tokens, five reviewers | 870 953 tokens, two scorers | 2 370 762 tokens |

Which subagents a cell sums is told by the description the session gave each when it spawned it,
which the transcript's `.meta.json` keeps. The pre-PR review's is the one named reviewer, over its
whole transcript, so its confirmations are in it, the one of the plugin pass's fixes included. The
three steps are the subagents that checked eligibility, listed the `CLAUDE.md` files and summarised
the change. The reviewers are the five numbered 1 to 5, and the scorers are one for each candidate.

**A total is a count of tokens and not a price.** A cache read is not priced as an input token, and
most of every total is cache reads: about nine tenths of each pre-PR review's, and 74.8%, 76.9% and
77.9% of the three plugin passes'. The passes also ran on different models. Each pre-PR reviewer
ran on Opus, the plugin's reviewers on Sonnet, and its scorers and three steps on Haiku, so a
scorer's token and a reviewer's are not the same spend either.

**The scorers' share of a plugin pass in this unit** is 45.9% on #625, 29.9% on #628 and 36.7% on
#633. In the reported counts of the table above, with the three steps counted in, it is 39.8%,
35.7% and 19.8%. #633's two scorers show how far the two units can part: their reported counts sum
to 119 402 and their requests to 870 953, because one of them sent 12 requests. On the ten
subagents of #633's plugin pass the sum over all requests was 1.9 to 9.9 times the last request, where the 27 above gave
1.7 to 6.4 against the notice's count.

**The first six rows are every pull request from #560 to #625 that had both kinds of pass**, counted
2026-10-07 over the 14 from #568 to #625. One counts when its body carries the findings of a review
made before it was opened and it has a comment headed `### Code review`. #568 and #582 have the
comment and no such findings; #603, #619, #621 and #622 have the findings and no such comment; #601
and #606 have neither.

**The session that runs the plugin pass on a branch adds that branch's row** (#624, 2026-10-07),
each time, whether or not a verdict is pending and including when the pass raises nothing. Since the
verdict below that is every pull request. A row gives each of its three cost columns as the token
count reported for that pass's subagents, where there is one, and the grade in the last column. The
pre-PR review's is its one reviewer's, read from its transcript as `/pre-pr-review` says when the
row is written; the reviewer confirms after that, and the pull request's body has the later figure.
**The session adds the branch's row to the all-requests table as well** (2026-10-08, #634), once
the reviewer has confirmed the plugin pass's fixes, so that the pre-PR review's cell is its whole
transcript. It reads the totals from the transcripts in its own `subagents` directory, the one
`/pre-pr-review`'s last step names. Each `agent-*.jsonl` there has an `agent-*.meta.json` beside it
whose `description` is what the session called that subagent when it spawned it. The session picks
the plugin pass's subagents by description, gives that step's script the three steps' transcripts
in one run, the reviewers' in a second and the scorers' in a third, and writes each run's total.
A figure that was not measured is written as not measured, one that covers the whole pass as not
split, and one the pull request does not give as not recorded. A figure with no record behind it is
not estimated.

**The verdict, 2026-10-07: the one-review rule fell** ([comment on
#593](https://github.com/trulsjo/realistic-fusion-refreshed/issues/593#issuecomment-6037668590),
written here by #627). #593 had the rule revisited once the table had five rows, with the verdict
Truls's. It had six, the first six above, and he gave it: the plugin pass runs on every pull
request, and the pre-PR review stays as it was.

**#604, #605 and #607 count towards the five** (Truls, 2026-10-07, #593). They were added on
2026-10-07 when he asked for them, and not by the sessions that ran their plugin passes, which #593
had not provided for. Their counts are read from their own pull requests by the same test as the
other three rows.

**The test was how serious a finding was, and not how many there were.** A finding the plugin pass
raised and that was then fixed is serious when it would have left a wrong figure, a false claim in a
tracked record, or broken code. A false sentence in this file or in `CLAUDE.md` counts, because
agents act on both. By that test **8 of the 26 fixed findings in those six rows were serious, on 5
of the 6 branches**. The 26 leaves out the point #604's confirmation raised, which none of the
pass's reviewers did. The pre-PR review's fixed findings on the same six number 43. The comment on
#593 names each of the eight.

**The grade is the session's, and Truls's to overrule** (Truls, 2026-10-07, #593). The session that
adds a row grades it by the test above. The first six were graded on 2026-10-07 by the session that
put the verdict to him, and he ruled on three it was unsure of: #579's missing exponent is serious,
a sentence on #607 saying a skill writes what it only holds templates for is not, and a false
sentence in this file or in `CLAUDE.md` is. #628's two were graded by that last ruling and he has
not seen them. A third of #628's five, `CLAUDE.md` dating the rule 2026-10-07 and not cutting it at
the verdict, was graded as not serious, because it is false only of pull requests that had merged
before the verdict, #622 the last of them. The same ruling could be read to cover it, and that is
his to say. #633's two were graded as not serious, and he has not seen those either. The sentence
its first finding quotes was true of the pull requests' own text and read as false beside the
table. Its second was a pair of sentences that did not say they spoke of different rows.

**What the verdict rests on, and its limits.** None of the eight was broken code: seven were prose,
and one was what a tool would do on a reinstall (#604). The six are branches where the pass was
asked for, two of them the changes that wrote this rule and this table, so they are not a sample of
branches. Three of the six had a cost for the plugin pass: about 400 000 tokens on #579, about
580 000 for #594's scorers alone, and 629 193 for #625's reviewers and scorers, or 762 616 with
the three steps before them. #594's is a floor. The verdict took the cost as about half a million
tokens a pass, from the first two figures and 629 193. Whether the scorers' share of it stays is
#626. Truls accepted on 2026-10-07 (#593) that the six are not a sample and that three cost figures
are enough.

**The rule is revisited at ten routine rows, which is sixteen in the table** (Truls, 2026-10-07,
#593). A routine row is one for a pull request opened after the verdict, when the pass stopped
waiting to be asked for: #628's is the first, the pull request that closed #627, and #625's is not
one. The comment on #593 words the cut as "opened from 2026-10-07 on", and #622 and #625 were opened
that day before the verdict. "After the verdict" is this file's reading of it. In the session that
put the verdict to him Truls confirmed that #625's row is not routine and that this change's is the
first, and the seventh point of #627 is the only written record of that. The wording of the cut is
his to correct. The test is the same, no pass mark is set in advance, and the verdict is his.

**On #579 only the pre-PR review could check a figure against what a probe printed.** The plugin's
reviewers are given the change, its blame, earlier pull requests and the comments on them, and the
comments in the code it touches, and a probe's output is in none
of those.

**#579's seven were real, and on 2026-10-05 all seven were read as small.** One commit fixed all of
them and no figure moved. The one that scored 100 was a temperature written without its exponent,
and on 2026-10-07 Truls ruled that one serious, as a wrong figure. The scorer gave the
false positive 0 — a claim that a table did not add up to its sum, which it does once rounded.

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
when the workflow is run, and what is run before it. Since 2026-10-07 it also has the session run
the workflow where the workflow's own first step would have stopped, so there the session goes
against an answer the workflow gives, as it does under the first rule when it posts what the
threshold filtered.

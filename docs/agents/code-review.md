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

1. **[The threshold gates the comment, not the
   report](#the-threshold-gates-the-comment-not-the-report)**: what a review reports and posts,
   whatever a finding scored.
2. **[Review the prose, not only the code](#review-the-prose-not-only-the-code)**: what a reviewer
   checks in prose, and what the session checks when it writes a fix, a ticket or a retrospective.
3. **[A review that plants takes its own worktree](#a-review-that-plants-takes-its-own-worktree)**:
   where a pass that modifies the working tree does it.
4. **[A review before the pull request, and the plugin pass after
   it](#a-review-before-the-pull-request-and-the-plugin-pass-after-it)**: the two passes every pull
   request gets, and what the session does around them.

**Two pages hold what this file carried beside its rules until 2026-10-10** (#672).
[`code-review-history.md`](code-review-history.md) has who decided each rule and each amendment
since, by date. Read it when a rule is being changed, and when the date or the origin of a sentence
here is in question. [`code-review-evidence.md`](code-review-evidence.md) has the measurements and
the cases the rules rest on. Read it when a rule is revisited or doubted, and when a sentence here
names a case by its pull request and the case is wanted in full. Reviewing a branch needs neither.
**A change to a rule adds its date and its ticket to the first page and its measurements to the
second**, in the commit that changes the rule here. This file gets the rule and a sentence of why.

**A rule is changed in this file** (2026-10-07, #630). `CLAUDE.md` and the intro of
`.claude/skills/pre-pr-review/SKILL.md` each name the section to read and when to read it, and state
no rule. The skill's steps are the pre-PR review's procedure, and they say what they carry out. A
change to what a step carries out is made here first and then in the step.

**This file, `docs/agents/review-figures.md`, `docs/agents/code-review-history.md`,
`docs/agents/code-review-evidence.md` and `.claude/skills/pre-pr-review/SKILL.md` are wrapped at 100
characters** (2026-10-09, #646; the two pages beside this file since 2026-10-10, #672). Section 12
of `scripts/ship-check.ps1` fails a longer line of prose in any of them. It leaves alone a table
row, a line inside a code fence, a heading, the skill's front matter, and a line with no space to
break it at, which is what a long link alone on its line is. A fence opened inside a blockquote it
does not see: it reads that fence's lines as prose, and fails a long one. **A figure grouped in
thousands stays on one line when a paragraph is rewrapped**, and since 2026-10-09 (#662) section 12
fails one that is split across a line end. `python tools/rewrap.py <file> <line>` rewraps the
paragraph that line sits in, at this width, and keeps such a figure together; section 12's failures
give the file and the line. The check cannot tell a split figure from two numbers, so it also fails
a line that ends in a number of one to three digits above a line that opens with an unrelated one of
exactly three, and the way out is to break the line a word earlier or later. #646 has the findings
that asked for a stated width.

## The threshold gates the comment, not the report

Decided by Truls, 2026-08-26, settling
[#128](https://github.com/trulsjo/realistic-fusion-refreshed/issues/128).

The `code-review:code-review` workflow scores each candidate finding and leaves anything below 80
out of its comment. **That filter governs what the workflow's own comment carries. It does not
govern what gets told to the person who ran the review** — or, since 2026-10-05, what reaches the
pull request.

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
and subsequently fixed** — in `954338d`, `8fdbd24` and `971adef` respectively. Two were not
nitpicks: a mod-portal token surviving in PowerShell's `$Error` after the thrown message had been
scrubbed (scored 75), and an ADR justifying a scope decision with a fact true only of a mod version
the same ADR declines to target (scored 75, merged into a permanent decision record). Both were
fixed only because they were reported outside the workflow's own output.

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

**What a fix leaves behind is read again after the last fix commit** (2026-10-09, #663). The rule
above is about a fix's own text. This one is about older text on the same branch, which a later
commit can make false without touching it: a count, a quoted output, a statement of what the change
does. After the last fix commit on the branch, the plugin pass's fixes included, and before the pull
request's body is last edited, the session reads each of these again against the branch's head:

- **quoted output in the body**, by running the command on the head and comparing what it prints;
- **a count in the body, and a count the branch added to tracked prose**, by counting the rows,
  cases, findings or files it counts;
- **the branch's own commit messages**, each statement of what the change does against the code at
  the head. A message that a later commit made false is reworded, as the fourth rule says of one a
  review corrects.

**The body then says what was read again, and on which commit.** A reading that names no commit
cannot be told from one made before the last fix. **What the reading turns up is fixed like any
finding raised in the last confirmation**: the fix gets a message of its own to the reviewer, what
that fix changed is read again, and the body names the head after it.

**A fix that only corrects a count is the exception, and goes unconfirmed** (2026-10-09, #665). It
is one whose every changed line differs from the line it replaces in digits alone, or in a number
written as a word, where the number counts rows, cases, findings, files or commits. The session
commits it, sends the reviewer no message for it, and says in the body's line for the reading that
this fix was not confirmed. No later message confirms it: unlike a fix held under #643, nothing
follows the reading. A fix that changes any other word is a new claim and keeps its message.

The reason is what a message costs. On #664, the first use of the reading, confirming one changed
cell cost 669 308 tokens over three requests, about what confirming a round of fixes does. The
evidence page has [the five
messages](code-review-evidence.md#what-a-message-to-the-reviewer-cost-on-664-665), with what this
rule would not have covered of that fix, and [the three findings on
#656](code-review-evidence.md#older-text-that-a-later-commit-made-false-on-656-663) that the reading
after the last fix commit is for.

**A ticket's evidence and a retrospective's are read from their source the same way** (2026-10-08,
#637). Each is written after the work, from what the session remembers, and whoever acts on it
trusts it. A figure, or a claim about a past pull request, issue or commit, is read from that pull
request, issue or commit before the ticket is published or the retrospective's candidate is put
forward. That makes three kinds of text under one rule: a fix, a ticket and a retrospective.

[The ticket and the retrospective that showed
it](code-review-evidence.md#a-ticket-and-a-retrospective-written-from-memory-637) are on the
evidence page.

**What this rule was measured on is on the evidence page**: [#230's second review, and three rounds
on 2026-09-12 and -13 that each let a superseded claim
through](code-review-evidence.md#measured-not-assumed-230-328-and-329). There, three of five defects
across two rounds were claims rather than code.

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
uncommitted in an ADR for one run. Another agent found that same plant in the file it was editing
and hand-reverted only its own two lines rather than `git checkout --` the file, so nothing was
lost. Two agents also wrote probe scripts to the same `/tmp` path in that run. The one agent that
had made its own worktree with `git worktree add --detach` saw none of it; that is the pattern.

### Whether `code-review:code-review` itself should carry it

**No, and nothing there can.** The plugin's own instructions launch five reviewers that read the
change, its blame, earlier pull requests and the comments on them, and the comments in the code it
touches; none of them is told to modify the tree, so the plugin never plants. The plugin is also not
this repository's to edit, for the reason the next section gives. The rule binds whatever runs
alongside it — a gate-poisoning pass, a review agent asked to prove a finding — and that is why it
lives here.

## A review before the pull request, and the plugin pass after it

Decided by Truls, 2026-10-05, settling
[#592](https://github.com/trulsjo/realistic-fusion-refreshed/issues/592), under the name "One review
before the pull request", and renamed on 2026-10-07 when he had the plugin pass run on every pull
request (#593).

### The rule

**Every branch gets a review before its pull request exists.** This section and `CLAUDE.md` call
it **the pre-PR review**. One fresh subagent runs it, and it is defined by what the subagent
is handed and not by a skill's name:

- the diff against `main`;
- this file;
- on a branch that records measurements, the probes' raw output; on any other, the result of the
  gates that were run.

`/pre-pr-review` (`.claude/skills/pre-pr-review/SKILL.md`, #595) runs it: it holds the reviewer's
brief and the confirmation's as templates for the session to fill in. The list above is still the
definition, and a review handed those three things is the pre-PR review whatever started it.

**The reviewer reads whole each agent-facing file the diff changes** (2026-10-08, #647): a skill
file, a page under `docs/agents/`, a `CLAUDE.md`. Its brief names them. A sentence that a change
made false and did not touch is in no hunk of the diff. **Where the diff changes a step of a skill,
the reviewer holds the step against the rule in this file that it carries out**: the step restates
none of the rule's reasons and leaves out nothing the rule requires. On #641 the plugin pass found
two things at 75 that the pre-PR review had not, and a rule for each was already in this file. One
was a sentence in step 6 of the skill that the new step 5 superseded; it was outside the diff. The
other was a passage of the skill that restated this file's reasons for the reword, and whose push
line left out "never `main`".

**The reviewer's report, and each confirmation, reach the session as a message once the session's
turn has ended** (2026-10-08, #648). The session ends its turn to receive one. **A question put to
the user does not end the turn** (#654). [What the session that reviewed #641 and #642
saw](code-review-evidence.md#when-a-reviewers-message-reaches-the-session-648-654) is on the
evidence page.

**The reviewer that raised a finding confirms its fix.** Continue the same subagent and have it read
each fix against its own finding. That is a confirmation and not a second round. **A fix that adds a
sentence adds a claim, and the confirmation checks it like any other.** On
[#594](https://github.com/trulsjo/realistic-fusion-refreshed/pull/594), the change that wrote this
rule, one of the three findings the plugin pass posted was in a sentence a fix had added after the
pre-PR review, and the confirmation had passed it.

**A finding under 75 that the reviewer raises while it confirms the fixes has its own fix confirmed
with the plugin pass's fixes** (2026-10-08, #643). The session fixes it and sends no message for
it. The pull request is opened with that fix marked `yes, not confirmed`, and the session changes
the mark when the reviewer answers for it after the plugin pass. **A finding at 75 or over is the
exception.** It is verified and important, so its fix gets a message of its own and is confirmed
before the pull request is opened. Where that message's diff holds a waiting fix as well, the
reviewer answers for both and nothing waits. Where the plugin pass leaves nothing to fix, no message
for its fixes is sent, and the waiting fix gets a message of its own then. A finding raised in the
confirmation of the plugin pass's fixes has no later message to wait for, and its fix is confirmed
as before. So is a defect that an item of the reviewer's unchecked list turns up, whoever finds it:
its fix gets a message of its own.

The reason is what a message costs: the reviewer's whole context again, for every request it makes
in answering. On #642 one such message, for a finding scored 25, cost 309 042 tokens; [the evidence
page](code-review-evidence.md#what-one-message-cost-on-641-and-642-643) has it beside #641's.

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
because it stood under a table, then in this file, in which the same change gave two of those six
rows a figure.

**A commit message is reworded when a review corrects what it says** (Truls, 2026-10-07, #640).
When a finding corrects a figure or a claim, the session searches the branch's commit messages for
the old one and rewords each commit that carries it. Where the branch has already been pushed, it
then pushes with `git push --force-with-lease`. That push is allowed on an unmerged branch only,
and never on `main`: history already on `main` is left alone. The reword is done before the pull
request is opened where it can be, and before the merge otherwise. It replays the branch from the
reworded commit's own parent and not onto `main`, which may have moved since the branch left it. So
it gives that commit and every commit after it a new hash and changes no file, and the diff of the
fixes is the same diff. **The session holds the reviewed commit by a local tag and
not by its hash.** The tag stays on the commit the reviewer read, which the reword leaves in the
repository beside its replacement, and the diff of the fixes is taken from the tag. On #633 the
measurement was first counted over 16 subagents, the pre-PR review showed there were 27, and this
file says 27. The body of commit `15b5b46` on `main` still says "on the 16 subagents of one
session".

**A commit body takes its reason from the ticket, and leaves what the change says to the diff**
(2026-10-10, #671). This binds every commit on a branch from the first, before a review has read it.
The body says why the change was made and cites the ticket, and names the file or the symbol the
commit changes. It neither quotes nor paraphrases a sentence the diff adds. A review does not change
the ticket, and it does change the diff: a body that restates a sentence of the diff is made false
when a finding corrects that sentence, and the reword above is then owed for words the body had no
need of. It rests on the first sentence of the shared commit convention's *Body* section,
`vendor/grado-factorio-tools/docs/commit-convention.md`, and holds a branch under review to it. Six
of #669's 16 pre-PR findings were about a commit message, 2, 6, 11, 14, 15 and 16, and three commits
were reworded five times in two rounds; [the evidence page has
each](code-review-evidence.md#commit-bodies-that-a-fix-made-false-on-669-671).

**Every pull request gets the plugin pass, after it is opened** (Truls, 2026-10-07, #593). It is the
full second round. This holds for every pull request opened after the verdict was given on
2026-10-07, a documentation-only one included; #622 and #625 were opened earlier that day. From
2026-10-05 until then the rule was "the plugin pass is run when it is asked for, and not otherwise";
*Measured, not assumed* below has what ended it.

**The session sets aside the plugin's eligibility answer.** The plugin's first step can answer that
a change needs no review, and it did for #625 because that change was documentation only. The
session runs the pass anyway and says in the pull request that it did. No kind of change is exempt
(Truls, 2026-10-07, #593).

**The session puts one of four words in each subagent's description** (2026-10-09, #661). The
description is what the Agent tool is given when a subagent is spawned, and it is all that says
afterwards which transcript was which. `tools/review-usage.py` sorts a session's subagents by it, in
upper case or lower: `Pre-PR` at its start for the pre-PR reviewer, and `step`, `reviewer` or
`scorer` as a whole word for the plugin pass's three steps before the reviewers, its reviewers and
its scorers. Where a description holds more than one of those three, the script takes the first, so
the word for what the subagent is comes before what it is about. The plugin pass's descriptions also
carry the pull request's number, as in `plugin pass #656: reviewer 2, shallow bug scan`, so that a
session which reviews two pull requests can give the script one of them. A subagent whose
description holds none of the four is printed as unsorted and is in no sum. Giving the script a
number leaves out the pre-PR reviewer, whose description has none, so the session gives its name as
well. On #656 the session had named its subagents with those words by its own choice, and a script
it wrote for the purpose sorted them; no tracked file asked for either.

**The pre-PR reviewer confirms the plugin pass's fixes** (Truls, 2026-10-07, #593). Continue the
subagent that ran the pre-PR review and hand it the diff of the fixes, with no list of what was
done. If it is no longer running, a fresh reviewer confirms them and the pull request says so. On
#625 that reviewer found an error the fixes had added. When it has confirmed them, or when the pass
left nothing to fix, the session reads again what *Review the prose, not only the code* names for
the last fix commit (#663), before it edits the body for the last time. Where a fix is waiting for
this message (#643), the diff starts at the parent of that fix's commit, `git diff
--output="<scratch>/plugin-fixes.diff" <that commit>~1..HEAD`, and the reviewer is told the
finding's number and that its fix is in the diff. The session then changes the fix's mark in the
pull request's body to what the reviewer answered.

**When an implement skill says to close out with `/code-review`**, in this repository that still
means the pre-PR review, and no pull request is needed for it. The plugin pass follows once the pull
request is open.

**The scoring step stays.** It is inside the plugin, so it runs whenever the plugin pass does. Every
surviving finding is reported whatever it scores, so the score decides only which comment a finding
is posted in — and it is still the step that verifies a candidate. Whether it stays now that the
pass runs on every pull request is
[#626](https://github.com/trulsjo/realistic-fusion-refreshed/issues/626), which is open and Truls's.
The verdict of 2026-10-07 changed nothing about it.

**A plugin-pass finding the pre-PR review missed gets its class named**, by the session that fixes
it, in the pull request. A class a script can detect becomes a section of `scripts/ship-check.ps1`.
A class that takes judgement becomes a line in this file. "One-off, no rule" is an answer, and it is
written down like the others. This is how the pre-PR review is meant to come to catch what today
only the plugin pass does.

### Measured, not assumed

**The figures are in [`review-figures.md`](review-figures.md)** (moved there on 2026-10-09, #644):
what each pull request's two passes found and cost, one row for a pull request in each of two
tables. The first table has the counts of findings, the token counts each pass's subagents reported
and the grade. The second has what each pass used over all its requests. Read that page to add a
pull request's rows, when this rule is revisited, and when a decision needs what a pass found or
cost, as #626 does. **Since the move, a pull request's figures go in its two rows and nowhere in
this file.** What this section keeps is the row rule, the verdict and its test, and what was
concluded across rows, each with its date and the number of rows it was drawn from. The figures the
verdict rested on are on the evidence page since 2026-10-10 (#672).

**A reported count is a floor on what a pass used** (measured 2026-10-07, #631, on the 27
subagents of two plugin passes). The count a subagent reports when it finishes was 1.000 to 1.095
times the tokens of its last request and its response, and the sum over all its requests was 1.7
to 6.4 times the count. The first table holds reported counts, and the second holds the sums. A
sum is a count of tokens and not a price: a cache read is not priced as an input token, and the
passes run on different models. That page has both measurements in full.

**Across the seven rows of the second table from #625 to #655, read 2026-10-09** (#644): cache reads
were 71.1% to 92.2% of a pre-PR review's total and 74.4% to 82.1% of a plugin pass's. The 71.1% is
#650's, as it was when its row was written; the other six rows are 87.7% or over. The scorers' share
of a plugin pass was 13.9% to 60.2% over all requests, and 10.8% to 47.7% in reported counts with
the three steps before the reviewers counted in. Whether the scoring step stays is #626.

**The session that runs the plugin pass on a branch adds that branch's row to each table of
`review-figures.md`, in one commit** (#624, 2026-10-07; the second table since 2026-10-08, #634),
each time, whether or not a verdict is pending and including when the pass raises nothing. Since
the verdict below that is every pull request. Both rows are then there when the reviewer confirms
the plugin pass's fixes.

**The two added lines are the whole edit** (2026-10-09, #644). What there is to say about one pull
request is a cell of its row, and no sentence here or on that page changes for it. A share that
can be worked out from the row's own cells is not written. #644 has what adding a pull request
took while its figures were also in the sentences around the tables.

**What a row holds.** In the first table: the day of the two passes; each count of findings, read
from the pull request's body and comments; four costs, each the token count reported for that pass's
subagents where there is one; and the grade, with the day it was made and its reason in the last
cell. The pre-PR review's cost is its one reviewer's, read from its transcript as `/pre-pr-review`
says when the row is written; the reviewer confirms after that, and the pull request's body has the
later figure. Anything else there is to say of the pull request goes in the last cell of its row in
the second table. In the second table: the totals over all requests, and for the pre-PR review its
count of requests and the share that is cache reads, read from the transcripts in the session's own
`subagents` directory, the one step 6 of `/pre-pr-review` names. Each `agent-*.jsonl` there has an
`agent-*.meta.json` beside it whose `description` is what the session called that subagent when it
spawned it. `python tools/review-usage.py <that directory>` sorts them by description and prints the
figures of both rows (#661): for the first table the counts the three groups of the plugin pass
reported, and for the second each group's total, the sum of the three, and the share of that sum
that is cache reads. Run on #656's directory on 2026-10-09 it printed each figure the two rows of
#656 have for the plugin pass, and one subagent as unsorted, described "PR 656 eligibility check".
The pre-PR review's cell is read when the row is written, as its cell in the other table is, and the
pull request's body has the later figure. A figure that was not measured is written as not measured,
one that covers the whole pass as not split, and one the pull request does not give as not recorded.
A figure with no record behind it is not estimated.

**The main session's own cost goes in the pull request's body, and in neither table** (2026-10-10,
#670). It is what the session that wrote the change and ran both passes used itself, and none of its
subagents is in it: its requests, their tokens summed as the second table sums them, the share that
is cache reads, and the context of its first request, which is what the session carried into the
work. `tools/review-usage.py` prints the four after the tables' figures. A session that did other
work before the branch gives the script the text the work began with, as its docstring says. The
figure runs from there to when it is read: the body's is read when the body is last edited, and
leaves out what the session does after. On #669 the main session used about five times what the two
passes did together, because it began the work with a context already large; [the evidence page has
the figures](code-review-evidence.md#what-the-main-session-used-on-669-670).

**The verdict, 2026-10-07: the one-review rule fell** ([comment on
#593](https://github.com/trulsjo/realistic-fusion-refreshed/issues/593#issuecomment-6037668590),
written here by #627). #593 had the rule revisited once the table had five rows, with the verdict
Truls's. It had six, the first six of the first table, and he gave it: the plugin pass runs on every
pull request, and the pre-PR review stays as it was.

[What the verdict rests on and its limits, and what #579's two passes
showed](code-review-evidence.md#what-the-verdict-of-2026-10-07-rested-on-593), are on the evidence
page, with the ruling that #604, #605 and #607 count towards the five.

**The test was how serious a finding was, and not how many there were.** A finding the plugin pass
raised and that was then fixed is serious when it would have left a wrong figure, a false claim in a
tracked record, or broken code. A false sentence in this file or in `CLAUDE.md` counts, because
agents act on both. By that test **8 of the 26 fixed findings in those six rows were serious, on 5
of the 6 branches**. The 26 leaves out the point #604's confirmation raised, which none of the
pass's reviewers did. The pre-PR review's fixed findings on the same six number 43. The comment on
#593 names each of the eight.

**The grade is the session's, and Truls's to overrule** (Truls, 2026-10-07, #593). The session that
adds a row grades it by the test above, and writes in the row's last cell the day, the reason, and
whether he has seen the grade. The cells of #642 and #655 were written before this asked for the
last of those, and do not say. The first six were graded on 2026-10-07 by the session that put the
verdict to him, and he ruled on three it was unsure of: #579's missing exponent is serious, a
sentence on #607 saying a skill writes what it only holds templates for is not, and a false sentence
in this file or in `CLAUDE.md` is. A later row is graded by the same test and those rulings, and its
last cell has what the session wrote of its grade.

**The rule is revisited at ten routine rows, which is sixteen in the first table** (Truls,
2026-10-07, #593). A routine row is one for a pull request opened after the verdict, when the pass
stopped waiting to be asked for: #628's is the first, the pull request that closed #627, and #625's
is not one. The comment on #593 words the cut as "opened from 2026-10-07 on", and #622 and #625 were
opened that day before the verdict. "After the verdict" is this file's reading of it. In the session
that put the verdict to him Truls confirmed that #625's row is not routine and that this change's is
the first, and the seventh point of #627 is the only written record of that. The wording of the cut
is his to correct. The test is the same, no pass mark is set in advance, and the verdict is his.

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

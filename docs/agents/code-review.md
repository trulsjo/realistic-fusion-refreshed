# Code review — four rules this repository adds

All four are conventions this repository keeps around the `code-review:code-review` plugin rather
than changes to it; see *Why it is written here rather than fixed at source* at the foot.

**Three skills answered to `/code-review` in the session that wrote this, and this file means one of
them.** Which are installed is a fact about a machine and not about this repository.
`code-review:code-review` is the official plugin: five reviewers, then a scorer for each candidate
finding, and it needs a pull request. It is what "the workflow" and "the plugin" mean below, and
**the plugin pass** is this repository's run of it. **Since 2026-10-11 the session runs the pass
from `/plugin-pass` (`.claude/skills/plugin-pass/SKILL.md`), and it departs from the plugin in two
things** (Truls, #626): the session does the plugin's three steps before the reviewers itself, and
one verifier that gives each candidate a verdict takes the place of the scorers and their numbers.
The five reviewers and their tasks, the pull request it needs and the name are the plugin's.
`mattpocock-skills:code-review` and the built-in `code-review` both read a diff and need no pull
request, and neither is the plugin pass. Write the qualified name when it matters which.

1. **[The verdict sorts the comment, not the
   report](#the-verdict-sorts-the-comment-not-the-report)**: what a review reports and posts,
   whatever was found of a candidate.
2. **[Review the prose, not only the code](#review-the-prose-not-only-the-code)**: what a reviewer
   checks in prose, and what the session checks when it writes a fix, a ticket or a retrospective,
   or implements a ticket.
3. **[A review that plants takes its own worktree](#a-review-that-plants-takes-its-own-worktree)**:
   where a pass that modifies the working tree does it.
4. **[A review before the pull request, and the plugin pass after
   it](#a-review-before-the-pull-request-and-the-plugin-pass-after-it)**: the two passes every pull
   request gets, and what the session does around them. The plugin pass's own half is on
   [`plugin-pass.md`](plugin-pass.md).

**Two pages hold what this file carried beside its rules until 2026-10-10** (#672).
[`code-review-history.md`](code-review-history.md) has who decided each rule and each amendment
since, by date. Read it when a rule is being changed, and when the date or the origin of a sentence
here is in question. [`code-review-evidence.md`](code-review-evidence.md) has the measurements and
the cases the rules rest on. Read it when a rule is revisited or doubted, and when a sentence here
names a case by its pull request and the case is wanted in full. Reviewing a branch needs neither.
**A change to a rule adds its date and its ticket to the first page and its measurements to the
second**, in the commit that changes the rule here. This file, or `plugin-pass.md`, gets the rule
and a sentence of why.

**A rule is changed in this file, or on `plugin-pass.md` where it is there** (2026-10-07, #630;
the page since 2026-10-14, #703). `CLAUDE.md` and the intro of each of the two
skills, `.claude/skills/pre-pr-review/SKILL.md` and since #626
`.claude/skills/plugin-pass/SKILL.md`, name the section to read and when to read it, and state no
rule. A skill's steps are its pass's procedure, and they say what they carry out. A change to what a
step carries out is made here or on `plugin-pass.md` first and then in the step.

**This file, `docs/agents/review-figures.md`, `docs/agents/code-review-history.md`,
`docs/agents/code-review-evidence.md`, `docs/agents/plugin-pass.md`,
`.claude/skills/pre-pr-review/SKILL.md`, `CLAUDE.md` and `scripts/CLAUDE.md` are wrapped at 100
characters** (2026-10-09, #646; the two pages beside this file since 2026-10-10, #672; the two
`CLAUDE.md` since 2026-10-11, #667; `plugin-pass.md` since 2026-10-14, #703). Section 12 of
`scripts/ship-check.ps1` fails a longer line of prose in any of them. It leaves alone a table row, a
line inside a code fence, a heading, the skill's front matter, and a line with no space to break it
at, which is what a long link alone on its line is. A fence opened inside a blockquote it does not
see: it reads that fence's lines as prose, and fails a long one. **A figure grouped in thousands
stays on one line when a paragraph is rewrapped**, and since 2026-10-09 (#662) section 12 fails one
that is split across a line end. `python tools/rewrap.py <file> <line>` rewraps the paragraph that
line sits in, at this width, and keeps such a figure together; section 12's failures give the file
and the line. With the file alone it lists the prose lines over the width that have a space to break
at, and writes nothing (#680). It counts a line in UTF-16 code units, as section 12 does, where
`awk` in Git Bash counts bytes. The check cannot tell a split figure from two numbers, so it also
fails a line that ends in a number of one to three digits above a line that opens with an unrelated
one of exactly three, and the way out is to break the line a word earlier or later. #646 has the
findings that asked for a stated width.

**A file that is not one of those eight has no width** (Truls, 2026-10-11, #667). A long line in
it is not a finding, and a reviewer does not report one. That covers the Python under `tools/`,
the PowerShell under `scripts/`, the Lua and every markdown page that sentence does not name.
Reviewers had raised a long line in a file with no stated width four times, three of them in
`CLAUDE.md`, and scored the same fault 0 and 50; [the evidence page has the
four](code-review-evidence.md#long-lines-in-files-with-no-stated-width-667).

## The verdict sorts the comment, not the report

Decided by Truls, 2026-08-26, settling
[#128](https://github.com/trulsjo/realistic-fusion-refreshed/issues/128), as "The threshold gates
the comment, not the report". Renamed on 2026-10-11, when he had one verifier replace the plugin's
scorers ([#626](https://github.com/trulsjo/realistic-fusion-refreshed/issues/626)).

### The rule

**Report every candidate a reviewer raised, whatever the verifier found of it.** The plugin pass's
verifier gives each candidate one of three verdicts: real, not real, or not verified. **The verdict
decides which of two comments on the pull request a candidate is listed in, and nothing else.** The
`### Code review` comment lists each candidate found real or not verified, and says which it is. A
second comment lists each one found not real, with the verifier's reason, and what a reviewer
mentioned without raising. So the pull request holds the pass's whole report, and not the transcript
of the session that ran it.

**A review that posts no issue must still say what it set aside.** Name each candidate, its verdict
and the evidence the verifier gave. A silent pass and a filtered pass must never look the same —
that is the whole point of this rule.

**The session does not change a verdict to move a candidate.** Where it reads the source differently
from the verifier, it says so beside the verdict, in the comment the verdict put the candidate in,
and a human decides.

**Until 2026-10-11 a score sorted the comments.** The plugin's scorers gave each candidate 0, 25,
50, 75 or 100, and the plugin's own comment took 80 or over, which of those five is 100 alone. A
candidate at 75, verified and important by the rubric's own words, was left out by construction.
From 2026-08-26 the rule was that such a finding is still reported, and from 2026-10-05 (#592) that
it is posted in the second comment. The evidence page has [what the threshold dropped on #124, #126
and #127](code-review-evidence.md#what-the-threshold-dropped-on-124-126-and-127-128), and [what the
scores decided on eleven
passes](code-review-evidence.md#what-the-scores-decided-on-eleven-passes-626).

**The pre-PR reviewer still scores its own findings**, 0, 25, 50, 75 or 100, and every one is
reported whatever it scores. Since #653 a score decides nothing in the fourth rule's procedure.

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

**A claim the diff narrows, retracts or deletes the subject of is searched for by its meaning**
(2026-10-14, #696). A figure has one spelling; a claim has many. For each such claim, every other
statement of it in the tracked files is found: the glossary entry, the generated report, the note,
the skill, the sentence that names a script the diff deletes. Searching for the diff's old wording
finds the copies that share it and misses the rest, so the search is by the claim's subject and its
synonyms, and each hit is read. **The search is done when the report lists each claim, the files
searched for it, and each hit, as a finding or as checked.** On #694 the plugin pass found two
statements the branch had made false in other words, `GLOSSARY.md`'s Sub-ignition entry and the
brownout report's quoted check, and the pre-PR review had passed both.

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
as well as the confirmation; [`plugin-pass.md`](plugin-pass.md#measured-not-assumed) has the verdict
of 2026-10-07 and what it rests on.

**A fix is checked against its source before it is written, whoever supplied its words**
(2026-10-07, #632). An enumeration or a figure taken from a reviewer, from a finding or from an
earlier reply, is checked against its source before it goes into a fix, the same as one the author
worked out. This binds the session that writes the fix. **A ticket is such a source too**
(2026-10-14, #701): a claim a ticket makes about an earlier pull request, issue or commit is read
from that source before the session that implements the ticket restates it in tracked prose or a
commit body. Where the source disagrees, the source wins, and the pull request says where the change
departs from the ticket. On #700 the session wrote #696's account of #690 into a rule, a history
line and a commit body unread, and the pre-PR review raised it as its first finding, at 75: #690's
own pre-PR review had raised the sentence #696 said it passed. On #625 the fix for the plugin pass's
first finding counted #601 among the pull requests that carry a pre-PR review's findings. The count
was copied from the pre-PR reviewer's own earlier enumeration, and #601's body says the review had
not been run. **A fix written after a review is the least-checked text on a branch**, and three more
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
this fix was not confirmed. No later message confirms it: unlike a fix held under #643 and #653,
nothing follows the reading. A fix that changes any other word is a new claim and keeps its message.

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
forward. That made three kinds of text under one rule: a fix, a ticket and a retrospective. Since
#701 there are four: the text that implements a ticket is held to its source by the paragraph on
a fix, above.

[The ticket and the retrospective that showed
it](code-review-evidence.md#a-ticket-and-a-retrospective-written-from-memory-637) are on the
evidence page.

**A statement that was not read is marked as an account** (Truls, 2026-10-09, #657). It says whose
account it is and that it was not read again. The tools repository's tracker page gives the form,
quoting its own #89: "by its #195's account and not re-read here". That is for a source the
session could not read when it wrote the ticket. A statement that can be read is still read, and
the mark does not stand in for the reading.

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

**A probe's raw output is its last report, in `.probe-reports/`** (2026-10-12, #589). A
`scripts/probe-*.ps1` that sources `scripts/factorio-lib.ps1` leaves what it printed there, in a
file named for the probe and its arguments. Under the four lines PowerShell opens a transcript
with, the file has the command line, the date and the game's version, and a run with the same
arguments replaces it. The directory is git-ignored, so a
report is on the machine that ran the probe and nowhere else. The session hands the reviewer the
report of each probe a figure came from, and **a figure is checked against that file**: the
reviewer does not start the game for it. A report whose arguments, date or game version are not the
ones the note gives is not that figure's evidence, and the probe is run again.

**The reviewer reads whole each agent-facing file the diff changes** (2026-10-08, #647): a skill
file, a page under `docs/agents/`, a `CLAUDE.md`. Its brief names them. A sentence that a change
made false and did not touch is in no hunk of the diff. **Where the diff changes a step of a skill,
the reviewer holds the step against the rule in this file, or on `plugin-pass.md`, that it
carries out**: the step restates
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

**A finding that the reviewer raises while it confirms the fixes has its own fix confirmed with the
plugin pass's fixes, whatever it scores** (2026-10-08, #643; decided by Truls on 2026-10-12,
settling #653). The session fixes it and sends no message for it. The pull request is opened with
that fix marked `yes, not confirmed`, and the session changes the mark when the reviewer answers for
it after the plugin pass. Until #653 a finding at 75 or over was the exception and had its fix
confirmed before the pull request opened. Holding it moves the confirmation and skips none of it,
and the plugin pass reads the held fix first: on #650 it raised a finding against one. Where a later
message's diff holds a waiting fix as well, the reviewer answers for both and nothing waits. Where
the plugin pass leaves nothing to fix, no message for its fixes is sent, and the waiting fix gets a
message of its own then. A finding raised in the confirmation of the plugin pass's fixes has no
later message to wait for, and its fix is confirmed as before. So is a defect that an item of the
reviewer's unchecked list turns up, whoever finds it: its fix gets a message of its own.

The reason is what a message costs: the reviewer's whole context again, for every request it makes
in answering. On #642 one such message, for a finding scored 25, cost 309 042 tokens; [the evidence
page](code-review-evidence.md#what-one-message-cost-on-641-and-642-643) has it beside #641's, and
[what holding every finding would have
cost](code-review-evidence.md#what-holding-every-finding-would-have-cost-653) on those two and on
#650.

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
full second round, and `/plugin-pass` runs it (#626). This holds for every pull request opened after
the verdict was given on 2026-10-07, a documentation-only one included; #622 and #625 were opened
earlier that day. From 2026-10-05 until then the rule was "the plugin pass is run when it is asked
for, and not otherwise"; *Measured, not assumed* on `plugin-pass.md` has what ended it.

**What only the session running the plugin pass acts on is on [`plugin-pass.md`](plugin-pass.md)**
(2026-10-14, #703): its check of eligibility, where its subagents work, the word in each one's
description, the one verifier, the rows it adds to `review-figures.md` and how they are graded,
the verdicts on this rule, and when the rule is next revisited, with *What the next revisit
decides* beside it. Read it when running the plugin pass, when adding a pull request's rows, and
when this rule is revisited or a verdict on it is wanted. A pre-PR reviewer needs none of it.

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

**When an implement skill says to close out with `/code-review`**, in this repository that still
means the pre-PR review, and no pull request is needed for it. The plugin pass follows once the pull
request is open.

**A candidate the plugin pass's verifier finds real or not verified is fixed, or left with its
reason written in the pull request's body.** The first rule says what a verdict decides.

**A plugin-pass finding the pre-PR review missed gets its class named**, by the session that fixes
it, in the pull request. A class a script can detect becomes a section of `scripts/ship-check.ps1`.
A class that takes judgement becomes a line in this file. "One-off, no rule" is an answer, and it is
written down like the others. This is how the pre-PR review is meant to come to catch what today
only the plugin pass does.

## Why it is written here rather than fixed at source

The workflow is a plugin, installed in Claude Code's plugin cache on each machine and not in this
repository. It is not this repository's to edit, and editing a cache would be undone by the next
plugin update. So this is a convention, and `CLAUDE.md` points at it so a review session loads it
before running.

Until 2026-10-11 nothing about the scoring, the rubric or the 80 was changed, and no rule asked the
workflow to do anything it did not already do. **Since then the session runs the pass from this
repository's own skill, `/plugin-pass`, and the plugin in the cache is still untouched** (#626). The
skill gives the five reviewers the plugin's five tasks in the plugin's words. It does not follow the
plugin when the plugin changes: a change there reaches this repository when someone edits the skill.

The first rule says what a verdict decides, and that nothing a reviewer raised goes unreported. The
second adds one obligation the plugin never mentions, because a plugin that reviews code cannot know
that in this repository the prose is part of the deliverable. The third governs the passes that run
beside the plugin pass rather than inside it. The fourth says when the pass is run, what is run
before it, and who checks what it raises.

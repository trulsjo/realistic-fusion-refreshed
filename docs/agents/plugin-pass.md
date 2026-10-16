# The plugin pass — what its session does, and when its rule is revisited

The plugin pass's half of the fourth rule of [`code-review.md`](code-review.md), *A review before
the pull request, and the plugin pass after it*, moved here on 2026-10-14 (#703). That section
keeps what binds a pre-PR reviewer: when each pass runs, what the pre-PR review is handed, the
commit-body rule, and who confirms the plugin pass's fixes. This page has what only the session
running the plugin pass acts on, and the rule's verdicts and when it is next revisited.
`/plugin-pass` carries it out. "This rule" and "the rule" on this page mean that fourth rule.

**Read this page** when running the plugin pass, when adding a pull request's rows to
[`review-figures.md`](review-figures.md), and when the fourth rule is revisited or a verdict on it
is wanted. Reviewing a branch does not need it. **A rule here is changed here**, with its date and
ticket on [`code-review-history.md`](code-review-history.md), as for one in `code-review.md`.

## What the session does

**The session checks eligibility itself, and no kind of change is exempt** (Truls, 2026-10-07, #593;
the session's own check since 2026-10-11, #626). The pass stops for a pull request that is closed,
is a draft, or already has its `### Code review` comment, and for nothing else. The plugin's first
step could also answer that a change needs no review, and did for #625 because that change was
documentation only. The session set that answer aside then, and since #626 the question is not
asked. The session also reads the `CLAUDE.md` paths from `git ls-files`, and takes the pull
request's body as the summary of the change.

**The plugin pass's subagents work in a worktree that is not the session's, where one can be had**
(2026-10-12, #651). The five reviewers and the verifier are told to change nothing, and on #650 one
reviewer detached the session's `HEAD` for eight minutes all the same; [the evidence page has what
that pass did](code-review-evidence.md#what-a-read-only-pass-did-to-the-sessions-tree-on-650-651).
So where they work does not rest on the brief alone. The third rule of `code-review.md` is for a
pass that means to edit the tree; this is for one told not to, and it adds only where such a pass
runs.

- **Where `HERDR_ENV` is set, the session makes one worktree for the pass with `herdr worktree
  create`, before it spawns anything, and spawns without isolation** (Truls, 2026-10-14, #699). A
  hook on the machine this was written on refuses the Agent tool's isolation inside herdr (#655),
  and the session's own `git worktree add`, and allows herdr's command. The worktree is at the
  pull request's head, in the sibling directory `../rf-plugin-pass-<n>`, on a throwaway branch
  `plugin-pass-<n>`, because herdr makes no detached worktree (#699). The session names that
  directory in each brief as the only place to run a command, and removes it with `herdr worktree
  remove`, and deletes the branch, when the verifier has answered or when the reviewers have and
  raised nothing. Until then the user made that worktree by hand (Truls, 2026-10-12, #651), and
  from #702 the session asked for it before it spawned anything: on #700 the hook had refused all
  five reviewers' spawns, as it was known to.
- **Where `HERDR_ENV` is not set, each of the six is spawned with the Agent tool's `isolation:
  "worktree"`**, which gives it a checkout of its own. That checkout need not start at the pull
  request's head, so the brief gives the head's full hash, from `gh pr view <n> --json headRefOid`,
  and the subagent's first command is `git checkout --detach <hash>`, there. The session checks
  before it spawns that the hash is its own `git rev-parse HEAD`.
- **Where herdr's command fails, or a hook refuses the isolated spawn, the session does not go
  round it.** The user makes one worktree for the pass: the session asks for `! git worktree add
  --detach <dir> <hash>`, in a directory outside the repository, names it in each brief as the
  first item says, and asks for its removal at the same point. With nobody there to make it, the
  pass runs in the session's checkout and the pull request says so. Both of those rest on the
  brief again, and the brief says so by naming what is not run: `git checkout`, `switch`,
  `stash`, `reset` and `worktree`.
- **Every brief also says: no gate, nothing left running in the background, and no message to
  another agent.** A verifier checks a candidate against its source and asks nobody.
- **A worktree made any of these ways has no submodule contents and no git-ignored file.** The
  shared commit convention is one such. A subagent reads those from the session's checkout by full
  path, and runs no command there.
- **The steps before the reviewers have no subagent to place**: the session does them (#626).

The session reads `git reflog` when the pass is over, and the pull request says whether it shows
a checkout during the pass.

**The session puts one of its words in each subagent's description** (2026-10-09, #661; `verifier`
since 2026-10-11, #626). The description is what the Agent tool is given when a subagent is spawned,
and it is all that says afterwards which transcript was which. `tools/review-usage.py` sorts a
session's subagents by it, in upper case or lower: `Pre-PR` at its start for the pre-PR reviewer,
and `reviewer` or `verifier` as a whole word for the plugin pass's reviewers and its verifier. It
sorts `step` and `scorer` the same way, for a pass run as the plugin has it, which each was up to
#678's: three subagents for the steps before the reviewers and a scorer for each candidate. Where a
description holds more than one of those four, the script takes the first, so the word for what the
subagent is comes before what it is about. The plugin pass's descriptions also carry the pull
request's number, as in `plugin pass #656: reviewer 2, shallow bug scan`, so that a session which
reviews two pull requests can give the script one of them. A subagent whose description holds none
of the five is printed as unsorted and is in no sum. Giving the script a number leaves out the
pre-PR reviewer, whose description has none, so the session gives its name as well. On #656 the
session had named its subagents with those words by its own choice, and a script it wrote for the
purpose sorted them; no tracked file asked for either.

**One verifier checks every candidate, and gives no score** (Truls, 2026-10-11, #626). The plugin
has a scorer for each candidate. This repository's pass has one verifier for all of a pass's
candidates, on Sonnet. It is handed, for each candidate, the quoted words and the one source to
check them against, and it returns real, not real or not verified, each with its evidence; not
verified is for a candidate it could not check from the tree. The session merges a candidate that
two reviewers raised before it hands them over, and a pass with no candidate has no verifier. The
first rule of `code-review.md` says what a verdict decides, and its fourth what becomes of a
candidate found real or not verified. The reason for the verifier is what the scores decided: over
the eleven passes from #628's to #674's a score placed 3 of 33 candidates in the posted comment, and
the scorers used 30.8% of the passes' tokens; [the evidence page has both
tables](code-review-evidence.md#what-the-scores-decided-on-eleven-passes-626). **The verifier
stays** (Truls, 2026-10-14, at this rule's second revisit, and again on 2026-10-16 at its third),
has no count of its own, and is on [what the next revisit decides](#what-the-next-revisit-decides).

## Measured, not assumed

**The figures are in [`review-figures.md`](review-figures.md)** (moved there on 2026-10-09, #644):
what each pull request's two passes found and cost, one row for a pull request in each of two
tables. The first table has the counts of findings, the token counts each pass's subagents reported
and the grade. The second has what each pass used over all its requests. Read that page to add a
pull request's rows, when this rule is revisited, and when a decision needs what a pass found or
cost. **Since the move, a pull request's figures go in its two rows and nowhere in `code-review.md`
or on this page.** What this section keeps is the row rule, the verdicts and their test, and what
was concluded across rows, each with its date and the number of rows it was drawn from. What the
pass cost on the branches the verdict of 2026-10-07 rested on, and that verdict's limits, are on the
evidence page since 2026-10-10 (#672).

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
the three steps before the reviewers counted in. Each of those passes had scorers; #626 has what
became of them.

**The session that runs the plugin pass on a branch adds that branch's row to each table of
`review-figures.md`, in one commit** (#624, 2026-10-07; the second table since 2026-10-08, #634),
each time, whether or not a verdict is pending and including when the pass raises nothing. Since the
verdict of 2026-10-07 that is every pull request. Both rows are then there when the reviewer
confirms the plugin pass's fixes.

**The two added lines are the whole edit** (2026-10-09, #644). What there is to say about one pull
request is a cell of its row, and no sentence here or on that page changes for it. A share that
can be worked out from the row's own cells is not written. #644 has what adding a pull request
took while its figures were also in the sentences around the tables.

**What a row holds.** In the first table: the day of the two passes; each count of findings, read
from the pull request's body and comments; four costs, each the token count reported for that pass's
subagents where there is one; and the grade, with the day it was made and its reason in the last
cell. The pre-PR review's cost is its one reviewer's, read from its transcript as `/pre-pr-review`
says when the row is written; the reviewer confirms after that, and the pull request's body has the
later figure. The pre-PR review's count of findings, and how many were fixed and confirmed, are
read again after the last fix commit, as `code-review.md` says under *Review the prose, not only the
code* (#715). Anything else there is to say of the pull request goes in the last cell of its row in
the second table. In the second table: the totals over all requests, and for the pre-PR review its
count of requests and the share that is cache reads, read from the transcripts in the session's own
`subagents` directory, the one step 6 of `/pre-pr-review` names. Each `agent-*.jsonl` there has an
`agent-*.meta.json` beside it whose `description` is what the session called that subagent when it
spawned it. `python tools/review-usage.py <that directory>` sorts them by description and prints the
figures of both rows (#661): for the first table the count each group of the plugin pass reported,
and for the second each group's total, the sum of them, and the share of that sum that is cache
reads. Run on #656's directory on 2026-10-09 it printed each figure the two rows of #656 have for
the plugin pass, and one subagent as unsorted, described "PR 656 eligibility check". The pre-PR
review's cell is read when the row is written, as its cell in the other table is, and the pull
request's body has the later figure. A figure that was not measured is written as not measured, one
that covers the whole pass as not split, and one the pull request does not give as not recorded. A
figure with no record behind it is not estimated. **From the first pass that `/plugin-pass` runs**
(#626), a row's two cells for the three steps before the reviewers say the session did them, and its
two scorers' cells hold the verifier's figures and say so. The columns keep their names.

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
tracked record, or broken code. A false sentence in `code-review.md`, this page included, or in
`CLAUDE.md` counts, because agents act on both. By that test **8 of the 26 fixed findings in those
six rows were serious, on 5 of the 6 branches**. The 26 leaves out the point #604's confirmation
raised, which none of the pass's reviewers did. The pre-PR review's fixed findings on the same six
number 43. The comment on #593 names each of the eight.

**The grade is the session's, and Truls's to overrule** (Truls, 2026-10-07, #593). The session that
adds a row grades it by the test above, and writes in the row's last cell the day, the reason, and
whether he has seen the grade. The first six were graded on 2026-10-07 by the session that put the
verdict to him, and he ruled on three it was unsure of: #579's missing exponent is serious, a
sentence on #607 saying a skill writes what it only holds templates for is not, and a false sentence
in `code-review.md`, of which this page was then part, or in `CLAUDE.md` is. A later row is graded
by the same test and those rulings, and its last cell has what the session wrote of its grade. On
2026-10-10 he saw the grades of the ten routine rows, #628's to #673's: he ruled the third finding
on #628 not serious and let the others stand, and each of those cells says so.

**The verdict of 2026-10-10: the rule stands.** The first revisit fell due at #673's row, the tenth
routine one, and Truls kept the plugin pass on every pull request. By the test above 4 of the 25
fixed findings in those ten rows were serious, on 3 of the 10 branches. [What the passes cost, and
the verdict's limits](code-review-evidence.md#what-the-verdict-of-2026-10-10-rested-on), are on the
evidence page.

**The verdict of 2026-10-14: the rule stands again.** The second revisit fell due at #690's row,
the tenth routine one after #673's, and Truls kept the plugin pass on every pull request. By the
test above 1 of the 2 fixed findings in those ten rows was serious, on 1 of the 10 branches. He was
shown the ten rows' figures summed and not each row's grade, so their cells still say he has not
seen it. [What the verdict
rested on](code-review-evidence.md#what-the-verdict-of-2026-10-14-rested-on) is on the evidence
page. The verifier was judged at the same revisit, and stays.

**The verdict of 2026-10-16: the rule stands a third time.** The third revisit fell due at #721's
row, the tenth routine one after #690's, and Truls kept the plugin pass on every pull request, and
the verifier. By the test above 5 of the 10 fixed findings in those ten rows were serious, on 5 of
the 10 branches. As at the second, he was shown the ten rows' figures summed and not each row's
grade, so nine of their cells still say he has not seen it; #712's, with nothing to grade, says
nothing of it. [What the verdict rested
on](code-review-evidence.md#what-the-verdict-of-2026-10-16-rested-on) is on the evidence page.

**The rule is next revisited at ten more routine rows, or at the first five that touch a mod,
whichever comes first** (Truls, 2026-10-16, the trigger he set on 2026-10-10). Both are counted from
the row after #721's. Ten more is the fortieth routine row, which is the forty-sixth of the first
table. A row touches a mod when its pull request changes a file under
`realistic-fusion-refreshed-assets/`, `realistic-fusion-refreshed-core/` or
`realistic-fusion-refreshed/`; that is this page's reading of "touch a mod", and the wording is his
to correct. Of the ten after #673's, only #690's does, and it was the tenth; of the ten after
#690's, only #711's does. The second revisit was set on 2026-10-10 by the same trigger, and the
third on 2026-10-14. The first was set at ten routine rows, which was sixteen in the first table
(Truls, 2026-10-07, #593). A routine row is one for a pull request opened after the verdict of
2026-10-07, when the pass stopped waiting to be asked for: #628's is the first, the pull request
that closed #627, and #625's is not one. The comment on #593 words the cut as "opened from
2026-10-07 on", and #622 and #625 were opened that day before the verdict. "After the verdict" is
this page's reading of it. In the session that put the verdict to him Truls confirmed that #625's
row is not routine and that this change's is the first, and the seventh point of #627 is the only
written record of that. The wording of the cut is his to correct. The test is the same, no pass mark
is set in advance, and the verdict is his.

## What the next revisit decides

Anything deferred to a revisit of this rule is added to this list where it is deferred, with the
ruling that put it here (2026-10-14, #698). At the second revisit the verifier was first left out of
the verdict, because #626 had deferred it in the verifier's own paragraph and in a history line.

- **This rule**: whether the plugin pass still runs on every pull request (Truls, 2026-10-14, #691,
  by the trigger he set on 2026-10-10, and again on 2026-10-16, #722).
- **The verifier**: whether one verifier with no score still checks the plugin pass's candidates
  (Truls, 2026-10-14, #691, as #626 set on 2026-10-11, and again on 2026-10-16, #722).

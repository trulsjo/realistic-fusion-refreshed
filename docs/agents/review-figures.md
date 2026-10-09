# Review figures — what each pull request's two passes found and cost

The record behind the fourth rule of [`code-review.md`](code-review.md), *A review before the pull
request, and the plugin pass after it*. That file has the rules, the row rule among them, and what
was concluded across these rows. This page has the rows. It was part of that file until 2026-10-09
(#644), and no figure changed in the move.

**Read this page** to add a pull request's rows, when the rule is revisited at ten routine rows,
and when a decision needs what a pass found or cost, as
[#626](https://github.com/trulsjo/realistic-fusion-refreshed/issues/626) does. Reviewing a branch
does not need it.

**A pull request has one row in each table, and what there is to say about it is a cell of that
row.** Adding a pull request is one added line in each table and no other edit, here or in
`code-review.md`. A share that can be worked out from a row's own cells is not written.

## What each pass found, and the counts its subagents reported

Each pull request here had both kinds of pass, and each is a row since 2026-10-07 (#624). Each
count of findings is read from that pull request's body and comments. Two rows have the plugin
pass's cost from elsewhere: #579's is in #592's body, and #594's is in the comment on #593 and in
#595. The three steps before the reviewers check eligibility, list the `CLAUDE.md` files and
summarise the change. The last two columns are the grade. `code-review.md` has its test, and the
last cell has the day the row was graded and what the session that graded it wrote of it.

| branch | had both passes on | the pre-PR review found | pre-PR review's cost | the plugin pass found | plugin pass's cost: the three steps before the reviewers | plugin pass's cost: reviewers | plugin pass's cost: scorers | of the plugin pass's fixed findings, serious | the grade: when it was made, and what the session wrote of it |
|---|---|---|---|---|---|---|---|---|---|
| #579 | 2026-10-05; the one-review rule was decided on this branch alone | 12 findings: 11 fixed, one left unfixed at a score of 50 | not measured | eight candidates: seven fixed, one false positive | not split, if it is counted at all: what the figure to the right covers was not checked | about ten minutes and about 400 000 subagent tokens for the whole pass, not split | not split: inside the figure to the left | one of seven: a temperature written without its exponent | 2026-10-07, by the session that put the verdict to Truls |
| #594 | 2026-10-05, later the same day; the change that wrote the rule | nine findings: eight fixed, one left unfixed at a score of 50 | not recorded | ten candidates: three posted at 100 and six more reported, so nine survived, of which eight fixed and one left unfixed and not scored; one false positive | not recorded | not measured: the five reviewers ran as plain subagents, which report no usage | about 580 000 tokens | four of eight: three false sentences that change wrote, and older wording it superseded and left standing | 2026-10-07, by the session that put the verdict to Truls |
| #604 | 2026-10-06 | five findings: four fixed, one left unfixed at a score of 25 | not recorded | three findings scored: two fixed, one left unfixed at a score of 25, its premise wrong; confirming the fixes raised a fourth point, fixed and not confirmed again | not recorded | not recorded | not recorded | one of two: a renamed heading that a tool finds its own section by | 2026-10-07, by the session that put the verdict to Truls |
| #605 | 2026-10-06 | five findings: three fixed, two left unfixed at a score of 25 | not recorded | two findings, at 100 and 75: both fixed | not recorded | not recorded | not recorded | one of two: "there is no CI" left standing in four places | 2026-10-07, by the session that put the verdict to Truls |
| #607 | 2026-10-06 | ten findings, one of them unscored: seven fixed, three left unfixed, one at 50 and two at 25 | not recorded | four candidates: two fixed, two false positives | not recorded | not recorded | not recorded | one of two: superseded figures in a research note left reading as current | 2026-10-07, by the session that put the verdict to Truls |
| #625 | 2026-10-07; the change that wrote this table | 12 findings: ten fixed, two left unfixed at a score of 25 | 152 822 tokens, one reviewer | six candidates: five survived, four at 75 and one at 50, and all five fixed; one false positive | 133 423 tokens | 325 398 tokens, five reviewers | 303 795 tokens, six scorers | none of five | 2026-10-07, by the session that put the verdict to Truls |
| #628 | 2026-10-07; the change that wrote the verdict into `code-review.md` | ten findings: all ten fixed | 136 546 tokens, one reviewer | five candidates: two posted at 100, two more at 75 and one at 50, and all five fixed; no false positive | 140 099 tokens | 375 765 tokens, five reviewers | 286 539 tokens, five scorers | two of five: the first routine row named by its ticket's number, and the cell beside #594 saying that change wrote wording it had left standing | 2026-10-07, by the ruling on a false sentence in `code-review.md` or in `CLAUDE.md`; Truls has not seen it. A third of the five, `CLAUDE.md` dating the rule 2026-10-07 and not cutting it at the verdict, was graded as not serious, because it is false only of pull requests that had merged before the verdict, #622 the last of them. The same ruling could be read to cover it, and that is his to say |
| #633 | 2026-10-07; gave the table its column for the pre-PR review's cost | 14 findings: 12 fixed, two left unfixed at a score of 25 | 162 435 tokens, one reviewer | two candidates: one posted at 100 and one more at 50, and both fixed; no false positive | 140 189 tokens | 344 857 tokens, five reviewers | 119 402 tokens, two scorers | none of two | 2026-10-07; Truls has not seen it. The sentence the first finding quotes was true of the pull requests' own text and read as false beside the table. The second was a pair of sentences that did not say they spoke of different rows |
| #641 | 2026-10-08; added the all-requests table | 16 findings, three of them raised while confirming the plugin pass's fixes: 15 fixed, one left unfixed at a score of 25 | 155 993 tokens, one reviewer | four candidates: none posted, all four at 75, and all four fixed; no false positive | 139 099 tokens | 368 386 tokens, five reviewers | 233 552 tokens, four scorers | none of four | 2026-10-08; Truls has not seen it. All four are in the skill's steps or the tracker page and none is a wrong figure. The nearest to serious is a sentence in the skill that a new step superseded and the change left standing |
| #642 | 2026-10-08; one line of the tracker page | six findings: all six fixed | 103 932 tokens, one reviewer | two candidates: none posted, one at 75 and fixed, one at 35 and left unfixed, its premise wording that #641 had replaced | 126 199 tokens | 307 442 tokens, five reviewers | 102 363 tokens, two scorers | none of one | 2026-10-08: the tracker page asked for a `Closes` line for each ticket, where a body may join them on one line or have none |
| #650 | 2026-10-08; gave `ship-check.ps1` its check of a table's shape | 16 findings, two of them raised while confirming the fixes and two while confirming the plugin pass's: 15 fixed, one left unfixed at a score of 25 | 152 515 tokens, one reviewer | seven candidates: none posted, four at 75 and two at 50, and all six fixed; one false positive | 138 729 tokens | 365 642 tokens, five reviewers | 459 174 tokens, seven scorers | one of six: `CLAUDE.md` saying the new check fails a row in any tracked markdown, where it then read no table inside a blockquote | 2026-10-08, by the ruling on a false sentence in `CLAUDE.md`; Truls has not seen it. The file said the new check fails a row "in any tracked markdown", and the check then read no table inside a blockquote (it has since #652). The other five are in the skill's steps, `code-review.md`'s new rules and a comment in the script: a rule written only in the skill, an "all" that left out one report, a comment that the change which wrote it made stale, a sentence that could be read two ways, and a case a new rule did not cover |
| #655 | 2026-10-08; had that check read a table inside a blockquote | ten findings, one of them raised while confirming the fixes and one while confirming the plugin pass's: all ten fixed | 157 078 tokens, one reviewer | one candidate: not posted, at 50, and fixed; no false positive | 137 182 tokens | 350 091 tokens, five reviewers | 59 112 tokens, one scorer | none of one | 2026-10-08: a failure message that speaks of a row outside its header's blockquote, where the check also fires on a row quoted one level deeper |
| #656 | 2026-10-09; moved these tables to this page | 22 findings, two of them raised while confirming the fixes and four while confirming the plugin pass's: 20 fixed, two left unfixed at a score of 25 | 193 757 tokens, one reviewer | six candidates: none posted, one at 75, one at 60, two at 50 and one at 25, and all five fixed; one false positive | 162 588 tokens | 415 956 tokens, five reviewers | 455 849 tokens, six scorers | one of five: `CLAUDE.md` and `code-review.md` saying section 12 leaves alone a line inside a code fence, where it reads the lines of a fence inside a blockquote as prose | 2026-10-09, by the ruling on a false sentence in `code-review.md` or in `CLAUDE.md`; Truls has not seen it. The other four are a docstring sentence that said more than the code does, a sentence the move left pointing at a table no longer in the file, a qualifier the move dropped, and the head list's entry not naming a rule that changed |
| #664 | 2026-10-09; tracked the scripts a review is read with | 15 findings, four of them raised while confirming the fixes: 14 fixed, one left at a score of 25, a workflow job that had not run and then passed on the pull request | 201 212 tokens, one reviewer | three candidates: none posted, all three scored 0, so none survived; one of them, an added line of 114 characters in `CLAUDE.md`, was rewrapped all the same | 210 728 tokens | 444 302 tokens, five reviewers | 188 384 tokens, three scorers | none: no finding survived | 2026-10-09; Truls has not seen it. Three of the five reviewers raised nothing, one of them leaving a note that was not scored. The three candidates were the long line, two dated rows of a help block that give the count of gates on their day, and a printed count that the scorer showed cannot be wrong |

**The first six rows are every pull request from #560 to #625 that had both kinds of pass**, counted
2026-10-07 over the 14 from #568 to #625. One counts when its body carries the findings of a review
made before it was opened and it has a comment headed `### Code review`. #568 and #582 have the
comment and no such findings; #603, #619, #621 and #622 have the findings and no such comment; #601
and #606 have neither.

The cost of the pre-PR review was not measured on #579, and none of the first seven pull requests
states one. Since 2026-10-07 (#631) `/pre-pr-review` has the session write it in the pull request's
body, and the table has a column for it. #633's row is the first written under that rule. #625's
and #628's rows were filled in on the same day from the transcripts of their reviewers, which the
session that ran both still had. Being filled in afterwards, those two were read after the
reviewer's last confirmation, where a row written by its own session is read before it, as the row
rule in `code-review.md` says. #604, #605 and #607 each say five reviewers ran in the plugin pass,
and none gives a time or a token count. From #625's row on, each of a row's three figures for the
plugin pass is the usage its subagents reported.

**A reported figure is about the size of a subagent's last request, and not what the subagent used**
(measured 2026-10-07, #631). The plugin pass's subagents on #625 and #628 each sent a notice with a
token count when they finished, and every figure for those two passes is a sum of those counts. The
check was made on all 27 of them, whose counts sum to 1 565 019, which is the six figures given for
the two passes here. For each, the count was between 1.000 and 1.095 times the tokens of the agent's
last request and its response, and the sum over all the agent's requests was 1.7 to 6.4 times the
count. So a figure in the table says how large each subagent's context had grown, and it is a floor
on what the pass used. The pre-PR reviewer is reached by name, goes idle without finishing and sends
no notice, so its figure is its last request and response read from its transcript, the reading that
on the 27 was up to a tenth under the notice's count. The table below has the sum over all its
requests. The verdict's figure of about half a million tokens a pass rests on #625's two in this
unit and on two older ones. What #579's and #594's figures measure was not checked, and the check
does not explain why #594's reviewers reported no count.

## What each pass used over all its requests

Read 2026-10-08 (#634) for the first three rows, and by the session that added it for each row
since. #625, #628 and #633 were reviewed in one session, and its subagents' transcripts were still
on its machine: 41 of them, 40 belonging to the three pull requests and one a probe of the usage
notice. Each figure below sums, over every request a subagent sent, the four token counts in that
request's usage record: input, output, cache write and cache read. Since 2026-10-09 (#661) they are
read with `tools/review-usage.py`, which step 6 of `/pre-pr-review` names. The eight rows from #625
to #656 were read before that, with the script that step then held as a fenced block, and the plugin
pass's cells of #656 with a script its session wrote. The five older rows of the table above have no
transcript and so no row here.

| branch | pre-PR review: its one reviewer | of that, cache reads | plugin pass: the three steps before the reviewers | plugin pass: reviewers | plugin pass: scorers | plugin pass: those three summed | plugin pass: of that sum, cache reads | what else the transcripts showed |
|---|---|---|---|---|---|---|---|---|
| #625 | 3 979 750 tokens in 34 requests | 89.7% | 293 110 tokens, three subagents | 1 022 849 tokens, five reviewers | 1 114 370 tokens, six scorers | 2 430 329 tokens | 74.8% |  |
| #628 | 2 192 591 tokens in 19 requests | 89.0% | 296 532 tokens, three subagents | 1 756 565 tokens, five reviewers | 877 709 tokens, five scorers | 2 930 806 tokens | 76.9% |  |
| #633 | 3 522 320 tokens in 26 requests | 90.2% | 301 140 tokens, three subagents | 1 198 669 tokens, five reviewers | 870 953 tokens, two scorers | 2 370 762 tokens | 77.9% | One of its two scorers sent 12 requests, which is why the scorers' cell here is so far above their reported count. On the ten subagents of its plugin pass the sum over all requests was 1.9 to 9.9 times the last request, where the 27 of #625 and #628 gave 1.7 to 6.4 against the notice's count |
| #641 | 2 240 302 tokens in 17 requests | 87.7% | 392 566 tokens, three subagents | 1 703 340 tokens, five reviewers | 999 890 tokens, four scorers | 3 095 796 tokens | 81.1% |  |
| #642 | 1 208 124 tokens in 13 requests | 90.9% | 322 107 tokens, three subagents | 1 144 328 tokens, five reviewers | 325 030 tokens, two scorers | 1 791 465 tokens | 74.4% |  |
| #650 | 1 403 724 tokens in 11 requests | 71.1% | 432 603 tokens, three subagents | 1 672 809 tokens, five reviewers | 3 189 387 tokens, seven scorers | 5 294 799 tokens | 82.1% | One of its seven scorers sent 18 requests that sum to 1 178 225 tokens, and scored its candidate 0: a figure another reviewer had said it could not verify, which the scorer then verified |
| #655 | 1 773 694 tokens in 14 requests | 92.2% | 303 349 tokens, three subagents | 1 594 636 tokens, five reviewers | 305 370 tokens, one scorer | 2 203 355 tokens | 78.8% |  |
| #656 | 2 120 501 tokens in 14 requests | 90.8% | 602 867 tokens, three subagents | 2 819 828 tokens, five reviewers | 3 793 176 tokens, six scorers | 7 215 871 tokens | 87.4% | Two of its six scorers sent 15 and 16 requests, 950 309 and 1 160 664 tokens, for candidates scored 50 and 25 |
| #664 | 2 406 801 tokens in 15 requests | 83.9% | 707 560 tokens, three subagents | 2 673 413 tokens, five reviewers | 466 702 tokens, three scorers | 3 847 675 tokens | 80.8% | The first pull request whose figures were read with `tools/review-usage.py`, its own |

Which subagents a cell sums is told by the description the session gave each when it spawned it,
which the transcript's `.meta.json` keeps. `code-review.md` says which word each description holds
(#661). The pre-PR review's is the one named reviewer, over its
whole transcript, so its confirmations are in it, the one of the plugin pass's fixes included.
That holds for the first three rows, which were filled in afterwards; a row written by its own
session is read before the reviewer's last confirmation, as the row rule in `code-review.md` says,
and #641's is the first of those. The three steps are the subagents that checked eligibility,
listed the `CLAUDE.md` files and summarised the change. The reviewers are the five numbered 1 to 5,
and the scorers are one for each candidate.

**A total is a count of tokens and not a price.** A cache read is not priced as an input token, and
most of every total is cache reads: the two columns of shares say how much. The passes also ran on
different models. Each pre-PR reviewer ran on Opus, the plugin's reviewers on Sonnet, and its
scorers and three steps on Haiku, so a scorer's token and a reviewer's are not the same spend
either.

**The scorers' share of a plugin pass is not written in a row.** In this unit it is the scorers'
cell over the summed cell. In the reported counts of the first table it is the scorers' cell over
the three cost cells of the plugin pass. `code-review.md` has the range of both across the rows.

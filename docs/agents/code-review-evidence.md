# Code review rules — what they were measured on

The measurements and the cases behind the rules of [`code-review.md`](code-review.md). Each section
but ten was part of that file and is as it stood there, so "this file" in one is `code-review.md`,
and "this rule", "this paragraph" and "the paragraph above" are that file's. All but one of those
were moved on 2026-10-10 (#672), and the one on what the threshold dropped on 2026-10-11 (#626). The
ten written for this page are the ones for #651, #653, #670, #671 and #720, the ones on the verdicts
of 2026-10-10, 2026-10-14 and 2026-10-16, the one on the wrap width and the one on what the scores
decided. What each pull request's two passes found and cost is on a third page,
[`review-figures.md`](review-figures.md).

**Read this page** when a rule is revisited or doubted, and when a sentence of `code-review.md`
names a case by its pull request and the case is wanted in full. Reviewing a branch does not need
it. **The rule is the one `code-review.md` or `plugin-pass.md` words**: where a passage here states
one, that page's wording is the rule and this is what it rested on. **A new measurement is added
here**, under the rule it is evidence for, in the commit that changes the rule.

## Review the prose, not only the code

### Measured, not assumed: #230, #328 and #329

The section *Measured, not assumed* of that rule, until 2026-10-10.

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

### A ticket and a retrospective written from memory (#637)

Under the rule that a ticket's evidence and a retrospective's are read from their source.

- **A ticket: #632's own body.** It was written without opening the pull requests it cites and was
  wrong on two facts. It said a fix on #607 added a false sentence, where the fix corrected one row
  of a group and left the others. It said three of #628's five plugin findings came from one fix,
  where it was two. The session that implemented #632 wrote the right
  facts into the paragraph above, and the pre-PR reviewer on #633 checked them there. No rule asked
  for that: the ticket's evidence was read because the change restated it.
- **A retrospective: the one run on 2026-10-07 after #633.** It said the session "did nothing else
  with" the list of things the pre-PR reviewer had not checked. #633's body shows the session
  checked the three pull request bodies the reviewer named. The candidate's facts were read from
  the pull request before #636 was published from it, and #636 states what the body says.

### What a message to the reviewer cost on #664 (#665)

Under the rule that a fix which only corrects a count goes unconfirmed.

The reason is what a message costs. On #664, the first use of the reading, it found one thing: a
row of `review-figures.md` that said 15 findings and 14 fixed, where the reviewer had by then
raised 17. The fix changed one cell, and confirming it cost about what confirming a round of fixes
does. Read from the reviewer's transcript on 2026-10-09, over the requests each message took:

| The session's message | Requests | Tokens |
|---|---|---|
| the first review | 11 | 1 623 969 |
| the fixes after the first review | 4 | 782 832 |
| the diff after the plugin pass | 4 | 846 067 |
| the fixes of findings 16 and 17 | 3 | 660 802 |
| the one changed cell | 3 | 669 308 |

That cell's fix also changed words beside its two numbers, so this rule would not have covered
it as it was written. Its two numbers alone would have gone unconfirmed.

### Older text that a later commit made false, on #656 (#663)

Under the rule that what a fix leaves behind is read again after the last fix commit. "This kind" is
older text on a branch that a later commit made false without touching it.

Three of #656's 22 pre-PR findings were of this kind, and the reviewer raised all three in its last
confirmation, the one of the plugin pass's fixes:

| Finding | What the text said | What had made it false |
|---|---|---|
| 19 | this file's "Across the seven rows of the second table, read 2026-10-09" | the table gained an eighth row that day, #656's own |
| 20 | a commit message's "A loop body is no longer judged" | the fix for the plugin pass's finding F, which corrected that claim |
| 22 | the body's "prints `32 of 32 cases judged as wanted.`" | later fixes added cases, and the last commit printed 34 of 34 |

Six of the 22 were raised in a confirmation and not in the first read: 17 and 18 while the fixes
were confirmed, and 19 to 22 while the plugin pass's were. #656's body has the table.

### Claims later corrected in ADRs and research notes (#720)

Truls took the claim grades for `docs/adr/` and `docs/research/` on 2026-10-16, in [#720's decision
comment](https://github.com/trulsjo/realistic-fusion-refreshed/issues/720#issuecomment-6210947744).
The test was whether this repository's own history showed a few real escapes, not one. The comment
counts about eight: seven in those two directories and one on the review pages. It names six, and
each one's correction is recorded in the file it was made in:

| File | Kind, as the comment names it | The correction, in its own words |
|---|---|---|
| `docs/research/energy-containment-probe.md` | an inference written as a measurement | "an inference dressed as a measurement" |
| `docs/adr/0012-reactor-signals-need-a-companion-entity.md` | an inference written as a measurement | "The one claim here that was reasoned rather than measured turned out to be false" |
| `docs/research/reactor-runtime-cost.md` | an inference written as a measurement | "so the output-box row was an extrapolation" |
| `docs/adr/0011-per-reactor-simulation-fluid-coupled.md` | a cause joined to a measured effect | "The premise of that decision was measured and is false. Corrected 2026-08-19 (#73)." |
| `docs/adr/0015-the-d-d-tier-is-a-breeder.md` | an untested premise | "The premise of that question was measured and is false. Corrected 2026-08-20 (#70)." |
| `docs/research/hidden-prototypes-by-lane.md` | a count drawn from a filtered search | "A first version of this note said four items and NINE recipes" |

The other two, one in those directories and one on the review pages, are counted by the comment's
account and not named there, and were not re-read here. The comment also says the other errors the
review pages record are out-of-date figures, which the grades do not catch.

## A review before the pull request, and the plugin pass after it

### When a reviewer's message reaches the session (#648, #654)

The paragraph of that rule and the correction under it, until 2026-10-10.

**The reviewer's report, and each confirmation, reach the session as a message once the session's
turn has ended** (2026-10-08, #648). The session ends its turn to receive one. The transcript of the
session that ran the reviews of #641 and #642 holds 18 messages from the two reviewers up to
#642's merge, nine replies and nine idle notices, and each of the 18 came directly after a turn of
the session ended. **A question put to the user does not end the turn.** The first report of #641's
reviewer was sent at 22:21:12 UTC on 2026-10-07, while the session waited on a question it had
asked at 22:15:18. The answer came at 04:11:05, and the turn ran on until 06:20:44. The report
arrived two seconds after that, 7 h 59 min after it was sent, with the reviewer's idle notice
beside it. In between, the session had read the report from the reviewer's transcript.

Until #654 this paragraph gave eight replies and ten idle notices, and said the first report was
not in the transcript. Both were a miscount by the session that wrote it: it classed a whole
transcript entry as an idle notice when any message in it was one, and the first report shares its
entry with its notice.

### What one message cost on #641 and #642 (#643)

Under the rule that a finding under 75 raised in a confirmation has its fix confirmed with the
plugin pass's fixes.

The reason is what a message costs: the reviewer's whole context again, for every request it makes
in answering. Read from the two reviewers' transcripts on 2026-10-08, over all their requests:

| Pull request | The review | Its confirmations | The one message this rule is about |
|---|---|---|---|
| #641 | 1 026 249 tokens, 9 requests | 2 969 221 tokens, 18 requests, 4 messages | 619 654 tokens, for finding 13, scored 75 |
| #642 | 605 802 tokens, 7 requests | 1 445 257 tokens, 13 requests, 3 messages | 309 042 tokens, for finding 6, scored 25 |

Each of those two messages carried one finding, raised in the confirmation before it, and the
message for the plugin pass's fixes was still to come. Under this rule #642's would not have been
sent. #641's would: its finding scored 75.

### What holding every finding would have cost (#653)

Written for this page with Truls's decision of 2026-10-12, that a finding raised in a confirmation
is held whatever it scores. Under it #641's message would not have been sent either. The table is
#653's, which put three options to him:

| Pull request | The message for one finding raised in a confirmation | Its score | Sent with the exception at 75 | Sent with every finding held |
|---|---|---|---|---|
| #641 | 619 654 tokens | 75 | yes | no |
| #642 | 309 042 tokens | 25 | no | no |
| #650 | not sent: findings 13 and 14 were held | 25 each | no | no |

The first two rows are the section above. On #650, the first use of the hold, both held fixes were
confirmed with the plugin pass's fixes, and the plugin pass raised its third finding against the fix
for finding 13. A held fix is read by the plugin pass before the reviewer confirms it.

### What a read-only pass did to the session's tree, on #650 (#651)

Under the rule that the plugin pass's subagents work in a worktree that is not the session's.
Written for this page on 2026-10-12. All but its last item is by #651's account, which read each
subagent's transcript on 2026-10-08, and by a comment on it from the session that ran #655's pass.
Neither was read again here: the transcripts are not in the repository.

- **On #650 every brief said to change nothing, and reviewer 3 moved `HEAD`.** It ran
  `git checkout -q --detach` at 17:25:01 UTC on 2026-10-08, ran `scripts/ship-check.ps1` with
  `HEAD` detached, and checked the branch out again at 17:33:14. The session committed nothing in
  those 8 min 13 s. The reviewer reported it itself.
- **The same pass, outside its brief:** a scorer sent a message to another pull request's pre-PR
  reviewer, and two reviewers ran `ship-check.ps1` in the session's tree while the others ran.
- **On #655 the Agent tool's worktree isolation was refused**, five times, by a `PreToolUse` hook
  that sends worktree work inside herdr to a herdr skill. The session did not go round it. It
  ran the pass in the shared checkout on a brief that named the commands not to run, and saw no
  checkout, no gate and no message; one reviewer left a `grep` running in the background. That
  is one pass.
- **On 2026-10-12 the same hook refused the session's own `git worktree add`**, tried once by
  the session that wrote the rule, inside herdr. This one is not an account: it is that
  session's own command. The hook's message says the user can run the command with `!`.

### Commit bodies that a fix made false, on #669 (#671)

Under the rule that a commit body takes its reason from the ticket. Written for this page on
2026-10-10.

Six of the 16 pre-PR findings on #669 were about a commit message: 2, 14, 15 and 16 about nothing
else, and 6 and 11 about a docstring and the message that repeated it. Each body had restated a
sentence of the change in its own words, and the restatement was wrong, or went stale when the
sentence was fixed. Read on 2026-10-10 from the reviewer's three reports in the session's
transcript, and from the commits the rewords replaced, which are in no branch:

| Finding | The commit body said | What the change said |
|---|---|---|
| 2 | "The step now asks only where a line names neither" | the step asks where a line "does not name the place and the fault" |
| 6 | "It refuses long heredocs that would have worked, and the log of refusals says how many" | the log holds what was refused, and not how a command would have ended |
| 11 | "sent nine heredocs all the same" | nine Bash commands holding a heredoc |
| 14 | "is now committed and held as not confirmed" | the fix for finding 12 had taken "held" out of the rule |
| 16 | "The rest is prose the change left behind or got wrong:", over a list of five | the commit fixed ten such things |

Finding 15 was a subject, "found on #665 to #668", read as including #667. Three commits were
reworded five times in two rounds, two of them and then all three, and 14 to 16 were raised against
messages written or left during the first. #656's finding 20 was the same kind: a message's "A loop
body is no longer judged", which a later fix made false.

### What the verdict of 2026-10-07 rested on (#593)

Five paragraphs of the section *Measured, not assumed* of that rule, until 2026-10-10. The verdict
itself, the test it used and when the rule is revisited are in `plugin-pass.md`, which held them
in `code-review.md` until 2026-10-14 (#703).

**#604, #605 and #607 count towards the five** (Truls, 2026-10-07, #593). They were added on
2026-10-07 when he asked for them, and not by the sessions that ran their plugin passes, which #593
had not provided for. Their counts are read from their own pull requests by the same test as the
other three rows.

**What the verdict rests on, and its limits.** None of the eight was broken code: seven were prose,
and one was what a tool would do on a reinstall (#604). The six are branches where the pass was
asked for, two of them the changes that wrote this rule and the first table, so they are not a
sample of branches. Three of the six had a cost for the plugin pass: about 400 000 tokens on #579,
about 580 000 for #594's scorers alone, and 629 193 for #625's reviewers and scorers, or 762 616
with the three steps before them. #594's is a floor. The verdict took the cost as about half a
million tokens a pass, from the first two figures and 629 193. Whether the scorers' share of it
stays is #626. Truls accepted on 2026-10-07 (#593) that the six are not a sample and that three cost
figures are enough.

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

### What the main session used on #669 (#670)

Under the rule that the main session's own cost goes in the pull request's body. Written for this
page on 2026-10-10.

Read on 2026-10-10 from the transcript of the session that wrote #669, between the command that
started the work and the user's words on the merge. A body is written before the merge, so a body's
own figure stops sooner than this one. `tools/review-usage.py` prints the first row when it is given
those two texts. The other two are #669's body and its row in `review-figures.md`:

| Who | Requests | Tokens over all requests |
|---|---|---|
| the main session | 48 | 21 101 666 |
| the pre-PR reviewer | 15 | 1 942 909 |
| the plugin pass, ten subagents | not counted | 1 962 484 |

20 973 380 of the main session's tokens were cache reads, 99.4%. The cause is the context it began
with. The session had already written #664, cleaned up after it and run its retrospective, so its
first request for #669 carried 396 207 tokens of context and its last 480 564. The first request of
the same session, that morning, carried 69 139. 18 of the 48 requests called no tool, for 8 118 007
tokens: each answered a notice or reported status, three of them an idle notice from the reviewer
and seven a subagent's hand-back while the plugin pass ran. Those 18 were counted by a scratch
script and are not a figure the tracked script prints.

### What the verdict of 2026-10-10 rested on

Under the rule that the plugin pass runs on every pull request, at its first revisit. Written for
this page on 2026-10-10, from the rows of [`review-figures.md`](review-figures.md) as they were that
day.

The ten routine rows are #628, #633, #641, #642, #650, #655, #656, #664, #669 and #673, which are
every pull request opened from the verdict of 2026-10-07 to 2026-10-10.

**4 of the 25 findings the plugin pass raised and that were fixed were serious, on 3 of the 10
branches**: two on #628, one on #650 and one on #656. The six rows of the first verdict had 8 of 26
on 5 of 6. Each of the four is serious by the ruling on a false sentence in `code-review.md` or in
`CLAUDE.md`. One of #628's two is a wrong number in such a sentence, the first routine row named by
its ticket's number, and none of the four is broken code. Truls ruled a third finding on #628 not
serious. Of the candidates the three passes after #656 raised, one was fixed, and it was not
serious. One on #669 that scored 20 was left as it was, and a long line that scored 0 on #664 was
rewrapped all the same. The 25 counts neither. The pre-PR review found 143 things on the same ten
and 134 were fixed.

| The plugin pass on the ten | Summed | A pass |
|---|---|---|
| the counts its subagents reported | 7 291 826 tokens | 729 183 |
| over all requests | 33 559 533 tokens | 3 355 953 |
| of that, the scorers | 11 148 320 tokens, 33.2% | |

The first verdict took a pass as about half a million tokens, in reported counts. A total is a count
of tokens and not a price, as that page says. What the main session used to run a pass is in neither
figure and was not split out.

**None of the ten touches a mod.** Each changes files under `docs/`, `.claude/`, `scripts/`,
`tools/` or `.github/`, or `CLAUDE.md`, and nothing else, read from each pull request's list of
files on 2026-10-10. So the ten say nothing of what the pass finds in Lua or in a prototype, which
is why the next revisit also falls due at five rows that touch one.

### What the verdict of 2026-10-14 rested on

Under the same rule, at its second revisit. Written for this page on 2026-10-14 (#691), from the
rows of [`review-figures.md`](review-figures.md) as they were that day.

The ten routine rows are #674, #678, #679, #683, #684, #685, #686, #688, #689 and #690, which are
every pull request opened after #673 up to #690, read from the repository's list of pull requests
the same day.

**1 of the 2 findings the plugin pass raised and that were fixed was serious, on 1 of the 10
branches**: #688's, an edit inside a passage of `docs/agents/state-detail.md` that the page says is
not edited. It is serious as a false claim in a file agents act on, and the edit was the fix a
pre-PR finding had asked for. The other, on #684, was a sentence of a callout that left no wrong
figure. The passes raised 14 candidates in all; on #674 and #685 a sentence a candidate quoted was
reworded, and on #679 a table one quoted was relabelled, although the candidate did not survive, and
the 2 counts none of them. The pre-PR review found 112 things on the same ten and 106 were fixed.

| The plugin pass on the ten | Summed | A pass |
|---|---|---|
| the counts its subagents reported, eight rows | 3 806 117 tokens | 475 765 |
| over all requests | 22 514 382 tokens | 2 251 438 |
| of that, the scorers or the verifier | 1 606 927 tokens, 7.1% | |

The reported counts leave out #684 and #689, whose reviewers were spawned with a name and sent no
count; they include the three subagents #674 and #678 ran before their reviewers. The pre-PR review
used 27 255 782 tokens over all requests on the same ten. What the main session used to run a pass
is in neither figure.

**The verifier, judged at the same revisit as #626 set.** Six of the ten passes had a candidate and
so a verifier: #679, #684, #685, #686, #688 and #690. It was handed 11 candidates and found 2 real,
both posted and fixed, 9 not real and none not verified; no row records that a candidate found not
real was later shown to be real. It used 1 193 813 tokens over all requests, 8.4% of those six
passes' 14 142 623, where the scorers used 30.8% of the eleven passes before it. Truls kept it, in
the same session, when the review of #691 found the branch silent on it: he was shown the counts
above and the 1 193 813 tokens as 7.3%, which is the verifier's share of all eight passes from
#679's, and the 8.4% was given him after.

**Truls was shown the summed figures, not each row's grade**, so the ten rows' last cells still say
he has not seen it. **One of the ten touches a mod**, #690, with seven files under
`realistic-fusion-refreshed/`, read from each pull request's list of files on 2026-10-14; its plugin
pass raised one candidate and it was found not real. So the ten still say almost nothing of what the
pass finds in Lua or in a prototype. **On #683 and #690 the reviewer asked to read earlier pull
requests said it read none.** The other eight rows do not say whether theirs did.

### What the verdict of 2026-10-16 rested on

Under the same rule, at its third revisit. Written for this page on 2026-10-16 (#722), from the
rows of [`review-figures.md`](review-figures.md) as they were that day.

The ten routine rows are #692, #694, #700, #706, #707, #711, #712, #713, #719 and #721, which are
every pull request opened after #690 up to #721, read from the repository's list of pull requests
the same day.

**5 of the 10 findings the plugin pass raised and that were fixed were serious, on 5 of the 10
branches**, each a sentence the branch would have merged that was false, or on #706 read as false:
on #694 `GLOSSARY.md`'s Sub-ignition entry, on #706 `CLAUDE.md` reading as if `code-review.md`
stated the half that moved to `plugin-pass.md`, on #707 a build-order note its own table
contradicted, on #711 a research note still placing a caveat in `CLAUDE.md`, and on #713 the new
rule's example reading as if a fix had touched both notes. The passes raised 22 candidates in all:
10 were found real, and all 10 were posted and fixed, and 12 not real. #692, #712, #719 and #721
posted nothing. The pre-PR review found 121 things on the same ten and 110 were fixed.

| The plugin pass on the ten | Summed | A pass |
|---|---|---|
| the counts its subagents reported, all ten rows | 4 104 835 tokens | 410 484 |
| over all requests | 21 417 370 tokens | 2 141 737 |
| of that, the verifier | 1 718 754 tokens, 8.0% | |

The pre-PR review used 33 720 799 tokens over all requests on the same ten, and that is a floor:
each of the ten rows keeps the figures read before that reviewer's last confirmation, as the row
rule in `plugin-pass.md` says. What the main session used to run a pass is in neither figure.

**The verifier, judged at the same revisit.** Nine of the ten passes had a candidate and so a
verifier, all but #692's. It was handed 22 candidates and found 10 real, 12 not real and none not
verified; no row records that a candidate found not real was later shown to be real, and the pull
requests were not read again for it. It used 1 718 754 tokens over all requests, 8.7% of those
nine passes' 19 843 640, where at the second revisit it used 8.4% of six.

**Truls was shown the summed figures, not each row's grade**, so nine of the ten rows' last cells
still say he has not seen it; #712's, with nothing to grade, says nothing of it. **One of the ten
touches a mod**, #711, with one file under `realistic-fusion-refreshed/`, a comment in
`realistic-fusion-refreshed/prototypes/entities.lua`, read from each pull request's list of files on
2026-10-16. So the ten still say almost nothing of what the pass finds in Lua or in a prototype.

## The wrap width

The sentence in the head of `code-review.md` that names the wrapped files, and the one under it for
every other file.

### Long lines in files with no stated width (#667)

Four times a reviewer raised a long line in a file that no sentence gave a width, and the same
fault was scored 0 once and 50 three times. The lengths are as each reviewer gave them.

| Pull request | Who raised it | What | Score |
|---|---|---|---|
| #656 | the pre-PR reviewer, finding 11 | a line added to `CLAUDE.md`, 103 characters | 50, fixed |
| #664 | the plugin pass, candidate A | a line added to `CLAUDE.md`, 114 characters | 0, rewrapped all the same |
| #664 | the pre-PR reviewer, finding 17 | the line under it, left at 119 by the fix for A | 50, fixed |
| #669 | the pre-PR reviewer, finding 3 | a docstring line of `tools/refuse-hanging-bash.py`, 145 characters | 50, fixed |

The scorer's reason for the 0, as #667 quotes it: "No rule is broken. No CLAUDE.md states a wrap
width for itself".

**What the two files held on `main` at `c48fadf`, counted on 2026-10-11** as section 12 counts a
line, in UTF-16 code units:

| File | Lines | Over 100 | Longest |
|---|---|---|---|
| `CLAUDE.md` | 444 | 45 | 133 |
| `scripts/CLAUDE.md` | 31 | 0 | 100 |

The rewrap left two lines of `CLAUDE.md` over 100, at 114 and 123, a link and the tail of one, with
no space to break either at, which section 12 leaves alone. **#667 and its comments give larger
figures, 54 lines over 100 with the longest 135 in the one file, 2 over 100 in the other and 116
lines for the Python, and those counted bytes**: an em dash is one character and three bytes. No
script read either file by the shape of its lines, checked the same day by searching `scripts/`,
`tools/` and the workflow for `CLAUDE.md`.

**The Python under `tools/` has no width** because holding it to one needed a check, and no linter
runs here: at the same commit 115 lines in 18 of the 22 files were over 100 characters.

## The verdict sorts the comment, not the report

### What the threshold dropped on #124, #126 and #127 (#128)

The first rule as it stood in `code-review.md` until 2026-10-11, when the plugin's scorers gave each
candidate a number: its opening, and under a bold line each its two sections, *The rule* and *Why
the threshold cannot be read as "these findings do not matter"*. None of it is the rule now.

The `code-review:code-review` workflow scores each candidate finding and leaves anything below 80
out of its comment. **That filter governs what the workflow's own comment carries. It does not
govern what gets told to the person who ran the review** — or, since 2026-10-05, what reaches the
pull request.

**The rule, until 2026-10-11.**

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

**Why the threshold cannot be read as "these findings do not matter".**

The rubric offers exactly five values — **0, 25, 50, 75, 100** — and the filter admits scores of 80
or more. So it admits exactly one of them. The effective rule is *score exactly 100*, and the 75
band, which the rubric itself defines as

> Highly confident. The agent double checked the issue, and verified that it is very likely it is a
> real issue that will be hit in practice … The issue is very important

is discarded by construction. A finding can be verified, important, and dropped. Since 2026-10-05
(#592) read "discarded" and "dropped" as left out of the workflow's own comment: such a finding is
now posted in the second one.

**Measured, not assumed.** Across PRs #124, #126 and #127: ten findings, **zero posted, nine real
and subsequently fixed** — in `954338d`, `87afc28` and `971adef` respectively. Two were not
nitpicks: a mod-portal token surviving in PowerShell's `$Error` after the thrown message had been
scrubbed (scored 75), and an ADR justifying a scope decision with a fact true only of a mod version
the same ADR declines to target (scored 75, merged into a permanent decision record). Both were
fixed only because they were reported outside the workflow's own output.

### What the scores decided on eleven passes (#626)

What Truls's decision of 2026-10-11 rested on. The token figures are sums over the rows of
[`review-figures.md`](review-figures.md) from #628's to #674's, the eleven routine rows on `main` at
`c48fadf`, and the counts of candidates are read from the same rows' cells. #678's row was added
later the same day; its pass had scorers too, and it is in none of these figures.

| Of 33 candidates, one scorer each | Count |
|---|---|
| fixed | 25 |
| scored 0 or marked a false positive (#650, #656, three on #664, #674) | 6 |
| left unfixed on the scorer's reasoning (#642 at 35, #669 at 20) | 2 |
| placed in the posted comment by scoring 80 or over (two on #628, one on #633) | 3 |

The first three rows are the 33, and the fourth counts three of the 25. Every candidate above 0
other than the two left unfixed was fixed whatever it scored, one at 25 included. Two of the six at
0 were changed all the same. Three scores were off the rubric: 35, 60 and 20.

| Over all requests, eleven plugin passes | Tokens | Share |
|---|---|---|
| the plugin passes, the pre-PR reviews left out | 36 636 565 | |
| the scorers | 11 269 237 | 30.8% |
| the three steps before the reviewers | 4 708 050 | 12.9% |

That is about 341 000 tokens a candidate for the scorers, on Haiku. A total is a count of tokens and
not a price. **What a scorer did that the number did not** was say why: each of the two candidates
left unfixed was left on its scorer's reasoning. That is the part the verifier keeps.

**The three steps before the reviewers had one answer each on every routine row.** The session set
the eligibility answer aside (#593), the `CLAUDE.md` paths did not change between pull requests, and
the pull request's body was already a summary.

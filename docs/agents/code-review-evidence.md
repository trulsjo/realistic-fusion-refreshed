# Code review rules — what they were measured on

The measurements and the cases behind the rules of [`code-review.md`](code-review.md). Each section
but two was part of that file until 2026-10-10 (#672) and is as it stood there, so "this file" in
one is `code-review.md`, and "this rule", "this paragraph" and "the paragraph above" are that
file's. The two written for this page are the ones for #670 and #671. What each pull request's two
passes found and cost is on a third page, [`review-figures.md`](review-figures.md).

**Read this page** when a rule is revisited or doubted, and when a sentence of `code-review.md`
names a case by its pull request and the case is wanted in full. Reviewing a branch does not need
it. **The rule is the one `code-review.md` words**: where a passage here states one, that file's
wording is the rule and this is what it rested on. **A new measurement is added here**, under the
rule it is evidence for, in the commit that changes the rule.

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
itself, the test it used and when the rule is revisited are still in `code-review.md`.

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

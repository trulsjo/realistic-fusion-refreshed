# Code review rules — who decided each, and each amendment since

The dated record behind [`code-review.md`](code-review.md): who decided each of its four rules, and
when and by which ticket each was amended. It was part of that file until 2026-10-10 (#672). Each
passage below is as it stood there, so "this file" and "here" in one mean `code-review.md`. The move
changed four links in the first passage, which pointed at headings of that file, and no other word.

**Read this page** when a rule is being changed, and when the date or the origin of a sentence in
`code-review.md` is in question. Reviewing a branch does not need it. **The rule is the one
`code-review.md` words.** A passage here says what a rule was when the passage was written, and that
file says what it is. **An amendment is added here**, as a dated line under *Amendments since
2026-10-10* at the foot, in the commit that changes the rule.

## The four rules, and what changed each

The head of `code-review.md` until 2026-10-10. Its list there now names the four and says in a line
what each is about.

1. **[The threshold gates the comment, not the
   report](code-review.md#the-verdict-sorts-the-comment-not-the-report)** — decided by Truls,
   2026-08-26, settling [#128](https://github.com/trulsjo/realistic-fusion-refreshed/issues/128);
   amended 2026-10-05 (#592).
2. **[Review the prose, not only the code](code-review.md#review-the-prose-not-only-the-code)** —
   decided by Truls, 2026-09-03, after
   [#230](https://github.com/trulsjo/realistic-fusion-refreshed/pull/230); its third rule widened
   from the file to the repository on 2026-09-14, settling
   [#331](https://github.com/trulsjo/realistic-fusion-refreshed/issues/331); its last rule narrowed
   2026-10-05 (#592), and what it says of the plugin pass changed 2026-10-07 (#593); a rule for the
   notes' figure tables added 2026-10-06 (#602); a rule for the session that writes a fix added
   2026-10-07 (#632), and widened on 2026-10-08 (#637) to a ticket's evidence and a retrospective's;
   a rule for the older text a fix leaves behind added 2026-10-09 (#663), and narrowed the same day
   for a fix that only corrects a count (#665).
3. **[A review that plants takes its own
   worktree](code-review.md#a-review-that-plants-takes-its-own-worktree)** —
   [#311](https://github.com/trulsjo/realistic-fusion-refreshed/issues/311), after the review of
   [#309](https://github.com/trulsjo/realistic-fusion-refreshed/pull/309) on 2026-09-10.
4. **[A review before the pull request, and the plugin pass after
   it](code-review.md#a-review-before-the-pull-request-and-the-plugin-pass-after-it)** — decided by
   Truls, 2026-10-05, settling
   [#592](https://github.com/trulsjo/realistic-fusion-refreshed/issues/592), under the name "One
   review before the pull request". It also changed wording in the first two, dated where it sits,
   and wrote the plugin's name out in full throughout. Since 2026-10-07 (#624) the table under it
   has a row for each branch and not for each pass on #579, and two rules beside it say who adds a
   row and when the rule is revisited. Its rule on when the plugin pass runs was reversed by Truls
   on 2026-10-07, in his verdict on
   [#593](https://github.com/trulsjo/realistic-fusion-refreshed/issues/593), written here by #627:
   the pass runs on every pull request. The section's name changed with that, and the table gained a
   column for the findings that were serious. Since 2026-10-07 (#631) the table also has a column
   for what the pre-PR review cost, and the section says what a token figure in it measures. Since
   2026-10-08 a second table gives what each pass used over all its requests (#634), and the section
   has two more rules for the session: what it does with the list of things the reviewer did not
   check (#636), and that a commit message is reworded when a review corrects what it says (#640).
   Three more from the same day: the reviewer reads whole each agent-facing file the diff changes
   (#647), a finding under 75 raised while the fixes are confirmed has its fix confirmed with the
   plugin pass's fixes (#643), and the session ends its turn to receive what the reviewer sends
   (#648). The evidence under that last one was corrected the same day (#654), which added that a
   question put to the user does not end the turn. Since 2026-10-09 (#644) the two tables are on a
   page of their own, [`review-figures.md`](review-figures.md), and what was said of one pull
   request in the sentences around them is a cell of its row. The row rule changed with that: the
   two added lines are the whole edit, and a pull request's figures go nowhere in this file. The
   same day (#661) one tracked script, `tools/review-usage.py`, took the place of the script in the
   skill's step and of the one #656's session wrote for the plugin pass's cells, and the section
   says which word the session puts in each subagent's description so that the script can sort it.

## Where a rule is changed

The paragraph of `code-review.md` under its list, until 2026-10-10. That file keeps a shorter one,
and what the steps of the skill carried out up to #665 is listed here. A later one is a line at the
foot.

**A rule is changed in this file** (2026-10-07, #630). `CLAUDE.md` and the intro of
`.claude/skills/pre-pr-review/SKILL.md` each stated parts of the four until then, so a rule that
changed had three files to change in: #627 edited all three to write one verdict. Both now name the
section to read and when to read it, and state no rule. The skill's steps are the pre-PR review's
procedure, and they still say what they carry out: what the reviewer is handed, that it confirms the
fixes of its own findings and reads a fix's added sentence as a new claim, that every finding goes
in the pull request's body, and that a planted change takes a worktree. Since 2026-10-08 they carry
out two more: the session answers for what the reviewer did not check (#636), and rewords a commit
message a review corrected (#640). Two of the earlier ones changed the same day: what the reviewer
is handed now names the files it reads whole (#647), and which of its confirmations answers for a
fix depends on the finding's score (#643). They carry out one more from that day: the session ends
its turn to receive what the reviewer sends (#648), which a question put to the user does not end
(#654). Since 2026-10-09 the step that spawns the reviewer gives it the description the usage
script sorts it by (#661), and they carry out one more: after the last fix commit the session reads
again what the branch and the body count and quote (#663), and sends no message for a fix from
that reading that only corrects a count (#665). A change to one of those is made here
first and then in the steps.

## The threshold gates the comment, not the report

The opening of that section until 2026-10-10.

Decided by Truls, 2026-08-26, settling
[#128](https://github.com/trulsjo/realistic-fusion-refreshed/issues/128). Where the findings under
the threshold are posted was changed on 2026-10-05, settling
[#592](https://github.com/trulsjo/realistic-fusion-refreshed/issues/592).

## Review the prose, not only the code

The opening of that section until 2026-10-10.

Decided by Truls, 2026-09-03, after
[#230](https://github.com/trulsjo/realistic-fusion-refreshed/pull/230). Its third rule widened from
the file to the repository on 2026-09-14, settling
[#331](https://github.com/trulsjo/realistic-fusion-refreshed/issues/331). Its last rule, on the
fixed state, was narrowed on 2026-10-05, settling
[#592](https://github.com/trulsjo/realistic-fusion-refreshed/issues/592). The rule for a note's
`## Current figures` table was added on 2026-10-06 (#602). What the last rule says of the plugin
pass was changed on 2026-10-07, when Truls's verdict on #593 had it run on every pull request. A
rule for the session that writes a fix was added on 2026-10-07 (#632), and widened on 2026-10-08
(#637) to the session that writes a ticket or a retrospective. A rule for the older text a fix
leaves behind was added on 2026-10-09 (#663), and narrowed the same day for a fix that only
corrects a count (#665).

## A review before the pull request, and the plugin pass after it

The opening of that section until 2026-10-10.

Decided by Truls, 2026-10-05, settling
[#592](https://github.com/trulsjo/realistic-fusion-refreshed/issues/592), under the name "One review
before the pull request". On 2026-10-07 he reversed the part of it that gave the section that name:
the plugin pass, which ran only when it was asked for, runs on every pull request. The verdict is in
[a comment on
#593](https://github.com/trulsjo/realistic-fusion-refreshed/issues/593#issuecomment-6037668590) and
was written here by #627.

## Amendments since 2026-10-10

One line for each, newest last. The passages above are not edited.

- **2026-10-10, #672.** This page and [`code-review-evidence.md`](code-review-evidence.md) were
  moved out of `code-review.md`, which keeps each rule and a sentence of why. Both pages are
  wrapped at 100 characters and are in section 12's list.
- **2026-10-10, #671.** The fourth rule gained a paragraph: a commit body on a branch takes its
  reason from the ticket and leaves what the change says to the diff. Step 1 of the pre-PR review
  skill carries it out.
- **2026-10-10, #670.** The fourth rule gained a paragraph: the main session's own cost goes in
  the pull request's body, read with `tools/review-usage.py`, and in neither table. Step 6 of the
  skill carries it out.
- **2026-10-10, no ticket: Truls's verdict on the fourth rule's first revisit.** The plugin pass
  stays on every pull request. The rule is next revisited at ten more routine rows or at the first
  five that touch a mod, whichever comes first. He saw the grades of the ten routine rows, ruled
  the third finding on #628 not serious and let the others stand.
- **2026-10-11, #667: Truls's decision on which files have a wrap width.** `CLAUDE.md` and
  `scripts/CLAUDE.md` are wrapped at 100 characters and are in section 12's list, which is now
  seven paths, each named. A file off that list has no width: a long line in it is not a finding
  and a reviewer does not report one. The Python under `tools/` is such a file.
- **2026-10-11, #626: Truls's decision on the plugin pass's scoring step.** One verifier for all of
  a pass's candidates replaced the scorer for each, and gives a verdict of real, not real or not
  verified, and no number. The session does the plugin's three steps before the reviewers itself.
  The first rule was renamed from "The threshold gates the comment, not the report" to "The verdict
  sorts the comment, not the report", and the link to it in the first passage above was changed to
  match, and no other word there. `/plugin-pass` holds the procedure. The pre-PR reviewer's own
  scores stay, and the verifier is judged at the fourth rule's next revisit. "Should the pass run as
  one workflow so its cost is reported" was closed as answered by `tools/review-usage.py` (#661).
  The fourth rule also gained a sentence that is not one of his ten decisions: a candidate found
  real or not verified is fixed, or left with its reason written in the pull request's body. It is
  the session's wording, and his to correct.
- **2026-10-12, #589.** The fourth rule gained a paragraph: a probe's raw output is its last
  report in `.probe-reports/`, and a figure is checked against that file. Step 2 of the pre-PR
  review skill carries it out. No one ruled on it; the ticket was `ready-for-agent`, and the
  wording is the session's.
- **2026-10-12, #653: Truls's decision on the exception #650 wrote.** A finding raised while the
  pre-PR reviewer confirms the fixes has its fix held and confirmed with the plugin pass's fixes,
  whatever it scores; one at 75 or over no longer gets a message of its own before the pull
  request opens. Holding moves the confirmation and skips none of it, and the plugin pass reads the
  held fix first. A defect from the reviewer's unchecked list still gets a message of its own. Step
  4 of the pre-PR review skill carries it out, and a score now decides nothing in that skill.
- **2026-10-12, #657: Truls's request of 2026-10-09.** The second rule's paragraph on a ticket's
  evidence gained the alternative: a statement that was not read from its source is marked as an
  account. Its own sentences were not changed, so there is no old wording to keep. The commit-body
  rule the same ticket names is the shared commit convention's and gained no second statement here;
  `CLAUDE.md`'s *What a body has to name* and its example were read against it and left.
- **2026-10-12, #651.** The fourth rule gained a paragraph and five items: the plugin pass's
  reviewers and its verifier work in a worktree that is not the session's, by the Agent tool's
  isolation, or where a hook refuses that in one the user makes. Steps 1, 2 and 4 of
  `/plugin-pass` carry it out. The ticket was `ready-for-agent` and the rule's wording is the
  session's. **Truls ruled on one thing, the same day:** inside herdr, where the hook refuses the
  session's own `git worktree add` too, the user makes the worktree; of the other three routes
  put to him, the shared checkout on a strict brief is what the pass falls back to.
- **2026-10-14, #691: Truls's verdict on the fourth rule's second revisit.** The plugin pass
  stays on every pull request, and the rule is next revisited by the same trigger, ten more routine
  rows or the first five that touch a mod, counted from the row after #690's. He was shown the ten
  rows' figures summed, not each row's grade. He also judged the verifier, as #626 set: it stays,
  and is judged again at the next revisit.
- **2026-10-14, #696.** The second rule gained a paragraph: a claim the diff narrows, retracts or
  deletes the subject of is searched for in the tracked files by its meaning and not only its
  wording, and the search is done when the report lists each claim, the files searched and each
  hit. It rests on #694, where the plugin pass found two statements the branch had made false in
  other words. The ticket also named #690, and that is not one: its pre-PR review had raised the
  sentence naming a deleted script, as finding 12, and the plugin pass's verifier found it not
  real. Step 3 of the pre-PR review skill carries it out. The ticket was `ready-for-agent`, and the
  wording is the session's.
- **2026-10-14, #698.** The fourth rule gained *What the next revisit decides*, a list beside the
  paragraph that says when the rule is next revisited, holding the rule and the verifier, and the
  instruction that anything deferred to a revisit is added to it where it is deferred. The
  verifier's paragraph points at the list instead of stating the deferral. The ticket was
  `ready-for-agent`, and the wording is the session's.
- **2026-10-14, #701.** The second rule's paragraph on a fix checked against its source gained a
  ticket among those sources: a claim a ticket makes about an earlier pull request, issue or commit
  is read from it before the implementing session restates it, and where they disagree the source
  wins and the pull request says so. It rests on #700's first pre-PR finding. The ticket was
  `ready-for-agent`, and the wording is the session's.
- **2026-10-14, #702.** The fourth rule's item on a hook that refuses the spawn gained the herdr
  case: where `HERDR_ENV` is set the session asks for the worktree before it spawns, and spawns
  without isolation. It rests on #700, where the hook refused all five reviewers' spawns.
  `/plugin-pass` carries it out. The ticket was `ready-for-agent`, and the wording is the
  session's.

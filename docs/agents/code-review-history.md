# Code review rules — who decided each, and each amendment since

The dated record behind [`code-review.md`](code-review.md): who decided each of its four rules, and
when and by which ticket each was amended. It was part of that file until 2026-10-10 (#672). Each
passage below is as it stood there, so "this file" and "here" in one mean `code-review.md`. The move
changed four links in the first passage, which pointed at headings of that file, and no other word.

**Read this page** when a rule is being changed, and when the date or the origin of a sentence in
`code-review.md` is in question. Reviewing a branch does not need it. **The rule is the one
`code-review.md` or `plugin-pass.md` words.** A passage here says what a rule was when the passage
was written, and that page says what it is. **An amendment is added here**, as a dated line under
*Amendments since 2026-10-10* at the foot, at the reading after the last fix commit on the branch
that changes the rule, from its final wording (#716).

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
  wins and the pull request says so. It rests on #700's first pre-PR finding. The rule's head and
  the #637 paragraph name the text that implements a ticket, and `CLAUDE.md`'s pointer to the rule
  names implementing a ticket. The ticket was
  `ready-for-agent`, and the wording is the session's.
- **2026-10-14, #702.** The fourth rule's first two items on where the plugin pass's subagents work
  gained the herdr case: where `HERDR_ENV` is set the session asks for the worktree before it
  spawns, and spawns without isolation. It rests on #700, where the hook refused all five reviewers'
  spawns. `/plugin-pass` carries it out. The ticket was `ready-for-agent`, and the wording is the
  session's.
- **2026-10-14, #699: Truls changed his 2026-10-12 ruling.** Inside herdr the session makes the
  plugin pass's worktree itself with `herdr worktree create`, which the hook allows, and removes it
  with `herdr worktree remove` after the verifier, instead of asking the user for both. The fourth
  rule's first item says so and keeps the earlier route as history; the user's worktree is now the
  fallback where herdr's command fails, as it already was where a hook refuses isolation. Run on
  2026-10-14 with herdr 0.9.4, the command made a branch it named itself, `worktree/<words>`, when
  given none, and has no option for a detached worktree, so the pass names a throwaway branch and
  deletes it after removing the worktree, which leaves the branch behind. `/plugin-pass` carries
  it out. The wording is the session's.
- **2026-10-14, #703.** The plugin pass's half of the fourth rule moved to
  [`plugin-pass.md`](plugin-pass.md), and the fourth rule points at it with when to read it. The
  test that sorted the paragraphs: a paragraph stayed when a pre-PR reviewer, or the session around
  the pre-PR review, acts on it, and moved when only the session running the plugin pass acts on it
  or it is read only when the rule is revisited. So the eligibility check, where the pass's
  subagents work, their descriptions, the verifier, *Measured, not assumed* and *What the next
  revisit decides* moved; when each pass runs, who confirms the plugin pass's fixes, the class of a
  missed finding and the commit-body rule stayed, and so did the verifier paragraph's sentence on a
  candidate found real or not verified, which step 7 of `/plugin-pass` reads there; the moved
  paragraph points at it rather than repeat it. The words moved unchanged but for the ones that
  named the file they now sit outside of: two of those now name `plugin-pass.md` beside
  `code-review.md`, so a pull request's figures go on neither, and Truls's ruling on a false
  sentence in `code-review.md` covers the part of it that moved. The paragraph on the main session's
  own cost stayed, since step 6 of `/pre-pr-review` acts on it. `code-review.md` was 49 656 bytes at
  #700's merge, over a read-budget hook's 45 000 on the machine this was written on, and the pre-PR
  brief has it read in full.
- **2026-10-15, #708.** The second rule's #696 paragraph names a heading, with each link that
  quotes it, among the places a narrowed claim is stated, since every link to a heading repeats its
  words. It rests on #707, where a heading kept stating for every build a claim the branch had
  narrowed to cells built 1H2, and neither pass raised it. The paragraph's own sentence on #707
  carries its figures, as its sentence on #694 does, so `code-review-evidence.md` gains nothing.
  Step 3 of the pre-PR review skill points at the rule and does not restate the list, so it is
  unchanged. The ticket was `ready-for-agent`, and the wording is the session's.
- **2026-10-15, #593.** The second rule reads a figure for a named quantity against every other
  statement of that quantity in the tracked files, and asks that the values agree or that each
  statement says what it measures and names the others as different measures. It is the one class of
  #579's seven plugin-pass findings that Truls gave a line; the other six are one-off, no rule, in
  [a comment on
  #593](https://github.com/trulsjo/realistic-fusion-refreshed/issues/593#issuecomment-6191194343).
  The paragraph carries #579's two figures, as #708's does its case, so `code-review-evidence.md`
  gains nothing. Step 3 of the pre-PR review skill has the reviewer read `code-review.md` whole and
  lists no checks, so it is unchanged. The wording is the session's.
- **2026-10-15, #714.** The second rule has a change that adds or rewords a review rule apply it
  to the case that prompted it, across the tracked files and by the rule's own search where it
  gives one, before its first commit, and the pull request's body list what it found. It sits
  beside the #632 paragraph, which binds a fix, and a rule's example is not one. It rests on #713,
  where three findings came from not doing so, and its paragraph carries them, as #708's does its
  case, so `code-review-evidence.md` gains nothing. Step 3 of the pre-PR review skill has the
  reviewer read `code-review.md` whole, so it is unchanged. The wording is the session's.
- **2026-10-15, #715.** The second rule's reading after the last fix commit names, among the counts
  it reads again, the pre-PR review's cell in the pull request's row of `review-figures.md`: its
  count of findings and how many were fixed and confirmed. The row is written before the last
  confirmation, which can raise more, and on #713 the count went stale twice. `plugin-pass.md`
  says so where it says what a row holds, and step 7 of `/pre-pr-review` lists the command that
  finds the row. The ticket preferred this to leaving the cell to step 7, and the wording is the
  session's.
- **2026-10-15, #716.** Truls decided three things on #716 on 2026-10-15, in [its
  comment](https://github.com/trulsjo/realistic-fusion-refreshed/issues/716#issuecomment-6200973092):
  this page keeps restating a rule, and a rule's line here is written at the reading after the last
  fix commit, from its final wording, and not in the commit that changes the rule; a comment that
  records his decisions on a ticket records what he decided, and leaves the session's wording to the
  pull request, which `issue-tracker.md` now says; and the pull request's body is left out, since
  that reading already rewrites it. The rest is the session's, from the pre-PR review of #719: the
  line is written first in that reading, committed, `scripts/ship-check.ps1` is run again, the line
  is sent to the pre-PR reviewer as a fix is, and the reading waits for the answer. The comment
  leaves `code-review-evidence.md`'s timing out of the decision, and it stays. The wording is the
  session's, and step 7 of `/pre-pr-review` carries the line out. These four lines are the first
  written that way.
- **2026-10-15, #717.** The paragraph on a file with no width says `tools/rewrap.py` refuses to
  rewrap one, reading the list from section 12. The tool reads section 12's `$WRAPPED`, so the two
  lists cannot differ, and its `--self-test` fails when a wrapped file is refused or another is
  not.
- **2026-10-16, #720.** Truls decided on #720 on 2026-10-16, in [its decision
  comment](https://github.com/trulsjo/realistic-fusion-refreshed/issues/720#issuecomment-6210947744),
  to take the modpack's three claim grades, *Measured*, *Read from source* and *Inferred*, with
  their rules of review, for `docs/adr/` and `docs/research/` only: new prose there, and any
  paragraph a change edits. Nothing is graded retroactively, review enforces it and no gate does,
  and the text lives on the tools repository's shared page rather than in `GLOSSARY.md`. In #720's
  later comments of the same day he settled details of the implementation, among them: the pin moves
  to `0125895`, the shared page's rules are five and not four, the paragraph links to them without
  restating or counting them, an edited paragraph is graded whole, and the pull request's body says
  the cases that prompted the rule are out of its scope. He then chose, in a correction, to put this
  line at the reading after the last fix commit (#716) and the measurements on
  `code-review-evidence.md`. The second rule's paragraph states the scope and links to the page at
  the pinned commit, and the evidence page lists the six escapes the decision names. The wording is
  the session's.
- **2026-10-16, #722: Truls's verdict on the fourth rule's third revisit.** The plugin pass
  stays on every pull request, and the rule is next revisited by the same trigger, ten more routine
  rows or the first five that touch a mod, counted from the row after #721's. He was shown the ten
  rows' figures summed, not each row's grade. He also judged the verifier: it stays, and both it and
  the rule are judged again at the next revisit, which [his comment on
  #722](https://github.com/trulsjo/realistic-fusion-refreshed/issues/722#issuecomment-6214875076)
  records.
- **2026-10-18, #629: Truls ruled on the wording of the cut.** A routine row is one for a pull
  request opened after the verdict of 2026-10-07, which `plugin-pass.md` had given as its own
  reading of the verdict's "opened from 2026-10-07 on". [His reply on
  #593](https://github.com/trulsjo/realistic-fusion-refreshed/issues/593#issuecomment-6249100930)
  records it, and the verdict's comment is left as written. The two grades #629 also asked about,
  #628's and #633's, he had seen on 2026-10-10.
- **2026-10-16, #610: Truls took all four differences of the modpack's review rules.** [His decision
  comment](https://github.com/trulsjo/realistic-fusion-refreshed/issues/610#issuecomment-6210061846)
  records them. The pre-PR reviewer gives its findings no score, for this repository's reason, that
  since #653 a score decided nothing, and `code-review.md` says beside the rule how that differs
  from the modpack's; its findings table loses its score column, an unfixed finding gives its
  reason, and a new row of `review-figures.md` says "left unfixed: <reason>". Under *Treat a
  quantifier as an instruction to enumerate*, a fix that adds a figure re-walks every quantifier
  covering the place it lands. A change that alters a rule has every sentence of that rule's section
  read against the new wording, as its own paragraph after the supersede rule, with #594 as the
  local case. The sentence on what the plugin's reviewers read gives its source, the installed
  plugin's `commands/code-review.md`, read 2026-10-16, and says why it carries no grade. The wording
  is the session's.
- **2026-10-16, #724: Truls added an item to what the fourth rule's next revisit decides**: whether
  the review's findings on its own records are counted apart from its findings on the change.
  `plugin-pass.md` says which findings count as on records, that the wording is his to correct, and
  that the split is not applied to rows already written. The wording is the session's.
- **2026-10-19, #730: Truls ruled how a pull request body carries the pr template's three
  headings here**, in a grill recorded on #730. The headings themselves he had ruled the same day
  in a grill recorded on trulsjo/grado-factorio-modpack#320, which reaches this repository. The
  fourth rule of `code-review.md` says that the body names a commit of the branch by its subject in
  quotes and not by its hash, that the body is checked with the shared `pr-body-check.ps1` before
  each time it is sent, and that the review sections stand below the three headings. Its second
  rule has the reading after the last fix commit name its head by its subject. The tracker page
  states the headings and the check. The wording is the session's.
- **2026-10-20, #738: the pr skill fills the body's three headings.** Truls asked for the ticket
  after #737's body, written by hand, passed the body check without the template's shape, and told
  the session that filed it to post its agent brief and move it to `ready-for-agent`, which it did.
  The fourth rule of `code-review.md` says the headings are filled by invoking
  `mattpocock-skills:pr` before the first `gh pr create`, and by hand to that template's shape where
  it is not installed, which it lists: a diagram, diff-sketch or tree, **Before:** and **After:**,
  and **Door:** and **Blast Radius:**. Step 6 of `/pre-pr-review` invokes it. No check reads that
  shape, and one that did would be a new rule. The wording is the session's.
- **2026-10-22, #752: a checked hit quotes the words it was checked on.** Truls had the ticket
  filed from #750's retrospective, choosing it and #751 from its candidates. On #750 the pre-PR
  reviewer's search by meaning listed `bench-fluid-links.ps1` as "(generic)", and the plugin pass
  found that file stale. The second rule's #696 paragraph says the search is done when each hit
  listed as checked quotes the words it was checked on, and that a hit listed by its file's name or
  its kind alone is not yet checked. The brief in step 3 of `/pre-pr-review` asks for the quote. No
  gate reads it. The wording is the session's.
- **2026-10-22, #755: both passes read against the merged `main`.** The ticket was filed from #754,
  where a reviewer read a diff against a local `main` nine commits behind. The fourth rule's list of
  what the pre-PR review is handed says the diff is against `main` with the local one first brought
  up to `origin/main`. `plugin-pass.md` says the session does the same before the plugin pass and
  every brief says to read the change with `gh pr diff`. Step 1 of each skill runs `git fetch origin
  main:main` and stops when it fails. On 2026-10-23 the plugin pass on #757 found that the fetch
  made step 1's "Nothing else stops the pass" false. The session amended the step and the
  eligibility rule's "for nothing else" alike: `plugin-pass.md` now says the pass stops for nothing
  else about the pull request. No gate reads it. The wording is the session's.
- **2026-10-23, #758: both passes read against `origin/main`.** Truls had the ticket filed after
  #757 merged, when `git fetch origin main:main` refused to fetch into a `main` checked out in the
  repository's folder. Step 1 of each skill now runs `git fetch origin main`, which moves
  `origin/main` and leaves the local `main` alone, and every diff and log `/pre-pr-review` runs,
  the markdown-only test in `CLAUDE.md` and `scripts/run-gates.ps1` included, reads
  `origin/main`. Each still stops when the fetch fails. No gate reads it. The wording is the
  session's.

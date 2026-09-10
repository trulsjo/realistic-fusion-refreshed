# 32. Prose cites our own code by symbol, never by line

Date: 2026-09-09

## Status

Accepted. Decided by Truls, 2026-09-09, while grilling
[#301](https://github.com/trulsjo/realistic-fusion-refreshed/issues/301). Supersedes nothing.

**It writes down a rule this repository has been enforcing since 2026-09-05 without stating it
anywhere a reader would look.** `44b1f3a` put the rule and its gate into `scripts/ship-check.ps1` as
a comment; `CLAUDE.md` never mentioned it, no ADR recorded it, and the class was flagged again on
[#287](https://github.com/trulsjo/realistic-fusion-refreshed/issues/287) and again while reviewing
[#300](https://github.com/trulsjo/realistic-fusion-refreshed/issues/300) — after the gate existed.

> **The `(#69)` in that comment reads as unrelated, and is not.**
> [#69](https://github.com/trulsjo/realistic-fusion-refreshed/issues/69) is *"Make the blanket's
> headroom right for what `get_capacity` actually reports"*, which has nothing to do with citations —
> but it is the ticket [PR #259](https://github.com/trulsjo/realistic-fusion-refreshed/pull/259)
> closes, and that PR carried the citation sweep and the gate alongside the blanket check. The rot
> surfaced *because* of #69's subject: two PRs running had moved `control.lua`'s `get_capacity` call
> sites and left the research note pointing at the old lines. Written here because the tag cannot be
> resolved from the issue title alone, and a reader who tries will conclude it is wrong.

Swept by [#302](https://github.com/trulsjo/realistic-fusion-refreshed/issues/302), gated by
[#303](https://github.com/trulsjo/realistic-fusion-refreshed/issues/303).

> **Swept 2026-09-10.** **Everything below describes a tree that no longer exists**, and the whole
> Context and Decision should be read as dated 2026-09-09. #302 converted **forty-six** own-tree code
> citations, not the forty-five counted below, and #304 converted decision item 6's two doc-to-doc
> references in the same pass — so ADR 0018 no longer cites ADR 0010 by line either, and item 6's
> *"cites ADR 0010 that way twice"* is now none.
>
> **Thirty-four of the forty-eight were pointing at something other than what the citing sentence
> claimed** — six known, twenty-eight not. The forty-sixth was a shape 3 nobody had counted:
> `fission-as-fusion-prerequisite.md`'s "lines 100, 192, 242, 301, 459, 548" for the six
> `table.deepcopy` sites, every one of them stale. Which is the floor paragraph below coming true on
> the first attempt to work from the table.
>
> **The `path:line` and `` `:NNN` `` tokens still written out in this ADR are its specimens of the
> banned form, not live citations** — the same standing Consequences gives *"verbatim game output"*.
> `CLAUDE.md`'s conventions section and `scripts/ship-check.ps1`'s own comment each carry one for the
> same reason. They survive the gate by two different mechanisms and neither is a decision: the
> shape-1 ones are bare paths and hit the ambiguity exemption, and the `` `:NNN` `` ones are not
> paths at all, so the regex never matches them — *"they are not exempted, they are unseen"*, below.
> Whether #303 should name this file instead of leaving both to chance is #303's to settle.

## Context

### A line number is a claim no gate reads

`docs/adr/0018`'s *"`auto_barrel = false` closes barrels on both energy fluids"* cites
`prototypes/fluids.lua:119` and `:155`. Both point at `fuel_value`; the six real `auto_barrel` lines
are two further down in each case. **Off by exactly two, so it reads as correct** — which is the
whole difficulty. The rot is proportional to how much the cited file has grown since, so a citation
degrades from right, to plausible, to absurd, and only the last state is visible to a reviewer.

A symbol has the opposite failure mode. A wrong name greps to nothing, and a reader notices
immediately.

### The rule already exists, and it is invisible

`scripts/ship-check.ps1`'s section headed *"our own files, by line"* carries it, its reasoning, its
exemptions and a floor. That is the right home for the *check*. It is the wrong home for the
*convention*: nobody writing an ADR reads a gate's comments first, and three reviews since have
proved it.

### A citation takes three shapes, and only one of them is greppable

This was learned by getting the count wrong twice on 2026-09-09. Each shape hides from the pattern
that finds the one before it:

1. **`prototypes/fluids.lua:119`** — a path and a colon. What the gate matches.
2. **`` `:155` ``** — a bare continuation, inheriting a path named earlier in the sentence.
   `docs/research/energy-containment-probe.md` points at `scripts/check-aneutronic.ps1` three times
   this way.
3. **"lines 196-197, 204, 208, 227, and 576-578"** — prose, no path, no colon.
   `docs/adr/0025` cites our own `reactor-logic.lua` five times in one sentence like this.

**Shapes 2 and 3 are invisible to the gate**, and were invisible to the audit that produced #302's
list of six.

### The gate passes over forty-five violations, and says why for two thirds of them

The check counts a citation as ours only when the path resolves to **exactly one** tracked file:

> a bare file name that several of our own files share — `entities.lua`, `d-d.lua` — because which
> one is meant cannot be decided here, and a gate that guesses would cry wolf on the predecessor
> citations that fill `port-and-original-inspection.md`.

Every shape-1 own-tree citation in the repository is written bare, and every one of them names a file
this repository has two of, one per code mod: `entities.lua`, `fluids.lua`, `d-d.lua`, `d-t.lua`,
`deuterium.lua`, `aneutronic.lua`, `blanket.lua`, `lithium.lua`, `mixing.lua`. All **thirty** slip
through on the exemption — the table's shape column is where that number comes from, and note that
ADR 0018's row is mixed: four of its five are shape 1 and the fifth is the `` `:155` `` above.

**The other fifteen never reach the exemption at all** — the regex does not match shapes 2 and 3, so
they are not exempted, they are unseen. `ship-check: 177 checks, 0 failures` on 2026-09-09 with all
forty-five in the tree.

The exemption is sound and stays. What was missing is the other half of it — a rule that makes the
ambiguity not arise.

### Which citations are ours

Swept 2026-09-09 across `docs/`, `CONTEXT.md`, `README.md`, `models/` and our own Lua and PowerShell.
Roughly 110 line citations point at the predecessor archives, the base game, Space Age or a
third-party mod. **Forty-five point into this repository:**

| File | Own-tree citations | Shape |
|---|---:|---|
| `docs/research/fission-as-fusion-prerequisite.md` | 24 | 1 |
| `docs/adr/0018-energy-is-contained-and-no-pipe-carries-it.md` | 5 | 1 and 2 |
| `docs/adr/0025-a-plasma-temperature-ships-in-kilodegrees.md` | 5 | 3 |
| `docs/research/mod-set-coexistence-targets.md` | 4 | 3 |
| `docs/research/energy-containment-probe.md` | 3 | 2 |
| `docs/research/bremsstrahlung.md` | 2 | 3 |
| `docs/adr/0019-the-blanket-sells-its-capture-heat.md` | 1 | 1 |
| `docs/research/quality.md` | 1 | 1 |

Six are wrong today, enumerated in #302. **The other thirty-nine have never been checked** — the
audit found the ones a reviewer happened to trip over.

**The count is a floor, not a total.** Shape 3 has no reliable pattern; it was found by reading, and
reading does not prove completeness. #302 sweeps rather than works from this table.

Our own Lua and the probe scripts cite lines only into a third-party mod's `data-final-fixes.lua`,
which is outside the rule. So no source file in this repository violates it.

## Decision

**Prose cites this repository's own code by symbol, with a repo-relative path. Never by line number.**

1. **Name the function, field, constant or prototype.** `` `realistic-fusion-refreshed/prototypes/entities.lua` — `contain()` ``.
   This is what every Lua comment here already does; no comment in our own Lua carries a line number
   into our own tree.

   **All three shapes are banned, not just the greppable one.** `fluids.lua:119`, a bare
   continuation `` `:155` ``, and "lines 196-197" written out in prose are one rule. Two of the three
   are what let forty-five citations sit under a passing gate.

2. **The path is repo-relative, always.** Never a bare `entities.lua` — there are two, and a reader
   cannot tell which is meant. This is not a readability preference: it is the condition that lets
   the gate in `ship-check.ps1` resolve a citation to exactly one tracked file and stop exempting it.

3. **A comment with no symbol is cited by a quoted fragment of its own text.** A distinctive phrase
   is itself a greppable handle, and it rots only when the comment is rewritten — at which point the
   citing sentence was probably wrong anyway. A comment with no phrase distinctive enough to grep is
   not worth citing.

4. **Predecessor, vanilla and third-party citations keep their line numbers.** `ORIG/`, `PORT/`,
   `_reference/`, `RealisticFusion*`, `base/`, `space-age/` and installed mods. We never edit those
   files, so they do not rot from our side, and ADR 0026's pins are what keep them true. A line
   number is often the only pointer those trees offer.

   **This list is the convention's, not the gate's.** `ship-check.ps1` skips five prefixes by name —
   `ORIG/`, `PORT/`, `_reference/`, `RealisticFusion` and `base/` — and everything else external is
   exempt by a different mechanism: the path never resolves to a tracked file. `space-age/` and an
   installed mod's path pass for that second reason, not the first.

5. **The rule binds our Lua and PowerShell comments as well as `docs/`.** One rule, one statement.
   **No Lua or PowerShell source file violates it today** — the forty-five below are all in `docs/` —
   so extending it there constrains only what gets written next.

6. **A bare `:126-131` into one of our own prose files is the same defect and is covered.**
   `docs/adr/0018` cites ADR 0010 that way twice. The existing gate cannot see it — there is no path
   to resolve — so a different pattern is needed. Tracked as
   [#304](https://github.com/trulsjo/realistic-fusion-refreshed/issues/304), not #302's.

## Consequences

- **At least forty-five citations are rewritten, not six.** Thirty-nine of them need *verifying* as
  well as converting. Twenty-four sit in one research note. And the sweep is part of #302's work,
  because shape 3 cannot be enumerated by pattern.
- **Closing the shape-1 hole needs no new gate.** Once every own-tree citation carries a
  repo-relative path it resolves to one tracked file, and the check that has been in
  `ship-check.ps1` since `44b1f3a` fires on its own.
- **Shapes 2 and 3 need a new pattern, and shape 3 may not be gateable at all.** A bare `` `:155` ``
  can be caught by carrying the last path seen on the line; "lines 196-197" in running prose has no
  handle a regex can trust, and a gate that guesses there would fire on every ADR quoting a
  predecessor. #303 states this as a limit rather than pretending to cover it.

  > **Done 2026-09-10 (#303).** Shape 2 is gated, by exactly the carry-the-last-path rule above,
  > with the backticks required as the discriminator. Shape 3 is not attempted and is stated as a
  > gap in the script's help. Two smaller gaps came with it: a continuation whose path sits on an
  > earlier line, and one written without backticks.
- **The gate reads `scripts/` and `docs/` only.** `$citing` is the files directly in `scripts/` plus
  `docs/**/*.md`. It does not read `CONTEXT.md`, `README.md`, `models/` or any `.lua`, so decision
  item 5 is a convention a reviewer keeps, not one a run enforces. Say so in the script rather than
  letting a green run imply otherwise.

  > **Superseded 2026-09-10 (#303).** The citation check now reads its own list — every tracked
  > `.md`, `.lua`, `.ps1`, `.py` and `.js` — so item 5 is enforced. `$citing` itself is unchanged,
  > because section 6 answers a different question. The new list narrows as well as widens: an
  > untracked or unstaged file is out of scope, where `$citing` read every file in `scripts/`.
- **`ship-check.ps1` has no `-SelfTest` and gains none.** Its own help says why, and draws a
  distinction worth keeping: sections 1 to 4 *"name every file and string they require, so a mistake
  in them fails rather than goes quiet"* and need nothing further. The **scanning** checks are the
  exception, because they pass by finding nothing, and what stands in for a self-test there is a
  **floor** — the check fails when it finds *too little*. This citation check already carries one, at
  fewer than ten citations found.
- **Verbatim game output is not a citation.** `docs/research/borrowed-base.md` quotes log lines
  reading `__rf-oninit-probe__/control.lua:6`. The path rule keeps them out without a special case:
  a `__mod-name__` path is not repo-relative and is not tracked.
- **A wrong symbol is still possible, and is meant to be cheap.** No gate here judges whether a name
  is the *right* name. The bet is that a name which greps to nothing is caught on sight, where a
  number that lands two lines off is not.

## Alternatives considered

**Keep line numbers and accept the rot**, on the grounds that a line number is more precise and that
a paragraph of prose inside a function has no symbol to name. Rejected. The precision is the
problem — a precise pointer at the wrong thing outranks a vague pointer at the right one in a
reader's trust, which is how the `auto_barrel` pair survived three reviews. And the gate would have
to open each cited file and judge whether the target still says what the citing sentence claims,
which is not mechanically decidable; the honest version could only assert that the line exists and
is not blank, which the six wrong citations would all have passed.

**Both, split by what is being cited** — a symbol where one exists, a line number where the target is
an unnamed comment, written differently so a checker can tell them apart. Rejected on the syntax it
drags in. A gate that must distinguish "symbol citation" from "deliberate line citation" needs a
grammar to parse and keep in step with, and it buys only the one case decision item 3 answers with a
quoted phrase and no new notation.

**Cite with the compact token `path:symbol`.** Visually parallel to what it replaces, and trivially
machine-readable. Rejected: it reads as a line citation at a glance, which is the exact confusion
this ADR exists to remove, and `:` already means a method call in Lua. The prose form also keeps the
gate **negative** — forbid `:` followed by digits — instead of parsing a positive grammar.

**Let the gate resolve bare filenames against the tree.** It would catch today's thirty shape-1
citations without any sweep. Rejected, and the script already argues it: a suffix match calls
fifty-six citations ours when thirty are, because `port-and-original-inspection.md` cites the
port's `entities.lua:58` and the base game's `entities.lua:9245` in the same shape as ours. A gate
that cries wolf on twenty-six predecessor citations gets switched off. It would also still miss all
fifteen of shapes 2 and 3, which have no filename to resolve.

**Exempt `docs/research/`** as dated findings that record what was true on a day. Rejected: it would
exempt thirty-four of the forty-five, including the one file holding twenty-four, and a research note
pointing at the wrong line misleads exactly as much as an ADR does.

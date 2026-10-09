# Issue tracker: GitHub

Issues and PRDs for this repo live as GitHub issues. Use the `gh` CLI for all operations.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Write a multi-line body to a file and pass `--body-file <path>`; the same goes for `gh issue comment` and `gh pr create`. Heredoc bodies passed through the Bash tool have failed here with `unexpected EOF while looking for matching '`. Every command that failed ran past 60 lines; the trigger is not pinned down. Write the file with the Write tool: a heredoc that writes the file is no safer. On 2026-10-06 one command of six such heredocs ended in `here-document at line 214 delimited by end-of-file`; of the six body files, two were never written and one was cut short. A heredoc is not what makes a command hang, though (#645, reproduced 2026-10-09). The Bash tool's stdin is a pipe that is never closed, so a `cat` or a `python -` with nothing fed to it waits on that pipe, and `python -` with stdin from `/dev/null` starts the interactive prompt and never ends. `tools/refuse-hanging-bash.py` is written as a PreToolUse hook that refuses those two shapes before they run, with a message that says to use the Write tool. It applies on a machine whose `.claude/settings.json` registers it for the Bash tool. That file is git-ignored, so a fresh clone has no hook, and there this line is the whole instruction. It was registered on Truls's machine on 2026-10-09, and refused its first live call the same day: `if false; then cat; fi; echo ran-through`, before it ran. Since #660 each refusal is appended to `.claude/refused-bash.log`, which is git-ignored, as one line of JSON with the time, the reason and the command. A refusal that looks false is read from that file, and the script's docstring lists the false refusals already known. Since #666 the hook also refuses a heredoc whose body is over 60 lines, with the same message; a shorter one is let through, and this line still says to write the file.
- **Blocking between issues**: when filing tickets, set each blocking edge as a native GitHub issue dependency as the tickets are created, with the `gh api` call under Wayfinding operations below. A ticket body that has a `## Blocked by` section keeps it; the edge is set as well.
- **Pull request body**: written with the `mattpocock-skills:pr` skill, where that plugin is installed. This repository adds to what it produces: above its template, a `Closes #<n>` for each ticket the branch resolves, where it resolves any; below it, the `## Pre-PR review` section the session writes in steps 5 to 7 of `/pre-pr-review` (`.claude/skills/pre-pr-review/SKILL.md`). `docs/agents/code-review.md` says what else the pull request records once the plugin pass has run.
- **Read an issue**: `gh issue view <number> --json title,body,labels,comments --jq '{title, body, labels: [.labels[].name], comments: [.comments[].body]}'`
- **Read a pull request**: `gh pr view <number> --json title,body,comments --jq '{title, body, comments: [.comments[].body]}'`, and `gh pr diff <number>` for the diff.
- **Not `--comments` without `--json`**: under the Bash tool here `gh issue view <number> --comments` prints the comments and no body, so nothing at all for an issue with no comments (gh 2.102.0, 2026-10-06).
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

Infer the repo from `git remote -v` — `gh` does this automatically when run inside a clone.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

When set to `yes`, PRs run through the same labels and states as issues, using the `gh pr` equivalents:

- **Read a PR**: the **Read a pull request** command under Conventions.
- **List external PRs for triage**: `gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments` then keep only `authorAssociation` of `CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR`, or `NONE` (drop `OWNER`/`MEMBER`/`COLLABORATOR`).
- **Comment / label / close**: `gh pr comment`, `gh pr edit --add-label`/`--remove-label`, `gh pr close`.

GitHub shares one number space across issues and PRs, so a bare `#42` may be either — resolve with `gh pr view 42` and fall back to `gh issue view 42`.

## When a skill says "publish to the issue tracker"

Create a GitHub issue. Two things come first:

- **The rule for a ticket's evidence** (#637). It is in `docs/agents/code-review.md`, under
  *Review the prose, not only the code*: the paragraph on a ticket's evidence and a
  retrospective's.
- **Search the open issues for the ticket's concept, not only for its wording** (a comment on
  #637, 2026-10-07). This one is stated here and nowhere else. Say in the pull request or in the
  session's report what was searched for. #639 was published on 2026-10-07 and closed as a
  duplicate of #591, open since 2026-10-05. Both asked for the gate history to move out of the
  State section of the root `CLAUDE.md`, under titles that share no noun but `CLAUDE.md`. The
  session that published #639 had not searched.

## When a skill says "fetch the relevant ticket"

Run the **Read an issue** command under Conventions.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body. `gh issue create --label wayfinder:map`.
- **Child ticket**: an issue linked to the map as a GitHub sub-issue (`gh api` on the sub-issues endpoint). Where sub-issues aren't enabled, add the child to a task list in the map body and put `Part of #<map>` at the top of the child body. Labels: `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Once claimed, the ticket is assigned to the driving dev.
- **Blocking**: GitHub's **native issue dependencies** — the canonical, UI-visible representation. Add an edge with `gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`, where `<blocker-db-id>` is the blocker's numeric **database id** (`gh api repos/<owner>/<repo>/issues/<n> --jq .id`, _not_ the `#number` or `node_id`). GitHub reports `issue_dependencies_summary.blocked_by` (open blockers only — the live gate). Where dependencies aren't available, fall back to a `Blocked by: #<n>, #<n>` line at the top of the child body. A ticket is unblocked when every blocker is closed.
- **Frontier query**: list the map's open children (`gh issue list --state open`, scoped to the map's sub-issues / task list), drop any with an open blocker (`issue_dependencies_summary.blocked_by > 0`, or an open issue in the `Blocked by` line) or an assignee; first in map order wins.
- **Claim**: `gh issue edit <n> --add-assignee @me` — the session's first write.
- **Resolve**: `gh issue comment <n> --body "<answer>"`, then `gh issue close <n>`, then append a context pointer (gist + link) to the map's Decisions-so-far.

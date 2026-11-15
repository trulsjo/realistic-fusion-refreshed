---
prefix: rf
---

# Review panel

The agents that review this repository's pull requests, through the `review-panel` skill: each in a
Herdr app space `rf-<agent>`, working in its own worktree beside the checkout,
`realistic-fusion-refreshed-panel/<agent>`, detached at `origin/main`. `panel.py up` starts what
is not running.

| Agent | Command | Clear |
|---|---|---|
| codex | `codex --no-daemon` | `/clear` |
| antigravity | `agy` | `/clear` |
| fable | `claude --model claude-fable-5-2` | `/clear` |

- **Agent**: the space's suffix and the answer file's name; `a-z`, `0-9`, `-` and `_`.
- **Command**: the bare command with its model; the app wraps it in `pwsh -NoExit -Command`.
  Codex needs `--no-daemon`, or its commands run outside hc.
- **Clear**: what `panel.py reset` sends to start a new conversation; empty means `/clear`. A clear
  keeps the program and its model: after editing a Command, run `panel.py up --restart`.

Why each agent and model: the same three, on the same models, as the panels of
grado-factorio-tools (`gft`) and true-nukes-refreshed (`tn`). Truls had this panel added on
2026-11-15 to review #881. The panel is a review beside the two that `docs/agents/code-review.md`
requires, the pre-PR review and the plugin pass, and replaces neither.

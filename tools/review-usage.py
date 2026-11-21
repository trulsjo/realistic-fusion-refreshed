"""Print the token figures a pull request's two rows in docs/agents/review-figures.md need (#661),
or one subagent's replies (#857).

    python tools/review-usage.py <subagents directory> [<text> ...]
                                 [--since=<text>] [--until=<text>]
    python tools/review-usage.py <subagents directory> --replies=<name>

The directory is the session's own, `projects/<project>/<session id>/subagents` under the Claude
configuration directory. Each `agent-*.jsonl` there is one subagent's transcript, and the
`agent-*.meta.json` beside it has the description the session gave that subagent when it spawned
it. Run it from anywhere; it reads those files and the session's transcript and writes nothing.

HOW A SUBAGENT IS SORTED: by its description, in upper case or lower.

    Pre-PR       the pre-PR reviewer         "Pre-PR review of <branch>"
    step         the three steps             "plugin pass #<n>: eligibility step"
    reviewer     the plugin's reviewers      "plugin pass #<n>: reviewer 2, shallow bug scan"
    scorer       its scorers                 "plugin pass #<n>: scorer C, <the candidate>"
    verifier     the one verifier (#626)     "plugin pass #<n>: verifier, 3 candidates"

A description that starts with `Pre-PR` is the pre-PR reviewer's. Any other is sorted by whichever
of `step`, `reviewer`, `scorer` and `verifier` comes first in it as a whole word, so a scorer whose
candidate is about a step or a reviewer is still a scorer: "scorer B, step 7 names only md". A
pass run since #626 has no step and no scorer: the session does the steps, and one verifier
takes every candidate. A subagent
whose description holds none of them is printed as UNSORTED and is in no sum, and so is a
transcript with no `.meta.json` beside it. docs/agents/plugin-pass.md tells the session that
spawns them to name them so.

WHAT THAT GETS WRONG: a step whose description names a reviewer or a scorer before the word
`step`, "reviewer eligibility step". The three steps' own names hold neither.

A SESSION THAT REVIEWED TWO PULL REQUESTS gives the texts that mark one of them: its number as
"#656", and the name of its pre-PR reviewer, whose description has no number. A subagent is then
counted only when its description or its name holds one of them, and the rest are printed as LEFT
OUT. A text is not found where a digit follows it: "#65" does not mark "#656".

WHAT IT PRINTS, in the units the two tables hold:

  - reported: the count a subagent sent in the notice when it finished, read from the session's
    transcript, `<session id>.jsonl` beside the `<session id>` directory. The first table's three
    cells for the plugin pass are sums of these, the verifier's going in the scorers' cell. A subagent with no notice there is said to have
    none, and its group's sum is then short.
  - last request: the tokens of a subagent's last request and its response. The first table's
    cell for the pre-PR reviewer, which is reached by name and sends no notice.
  - all requests, and the cache reads among them: the second table's cells.

A figure is the four token counts of a request's usage record summed: input, output, cache write
and cache read. A message streamed in several transcript lines is counted once, by its id, at the
usage of its last line.

THE MAIN SESSION (#670) is printed last, for the pull request's body and for neither table: the
requests of the session's own transcript, their tokens, the share that is cache reads, and the
context of the first of them, which is that request's tokens less its output. With no `--since`
that is the whole transcript, which is right for a session that wrote one pull request and did
nothing else. A session that did more bounds the part that wrote this one by what the user said:

    --since=<text>   start at the one turn of the user that holds the text
    --until=<text>   stop at the one turn after it that holds this one; without it, at the end

The arguments of the command that started the work are such a text, "#665 #666 #668", and so are
the user's words on the merge. A text is looked for in every turn the transcript gives the user,
and not in a tool's output. Run on the session that wrote #669 with those two texts, it prints
48 requests and 21 101 666 tokens, from a first context of 396 207. A pull request's body is
written before the merge, so it gives `--since` alone, and its figure runs to when it was read.

A slash command's turn is kept as tags, and is read as it was typed, `/<name> <args>`, so the whole
command is such a text too (#856). The summary a compaction leaves is not read, whether it is
flagged as one or is the copy a later turn carries, known by its first sentence: it quotes the
command that started the work, and a part started there is short. A `--since` that no turn holds,
or an `--until` that no turn after it holds, prints no figure for the main session and exits 1.
So does a text that more than one turn holds (#897), and it lists each of them with its time and
its first words: on the session that wrote #894, `--since=continue` was meant for a turn that said
only that, and began instead at the session's opening context a day earlier, as the blob of a
request copied it, measuring 399 requests from there when #894's body was written. Where one of
those turns says the text whole, it is the one, so a one-word turn can still be named. A turn
marked isMeta, as the skill's text a slash command loads and which ends with the command's
arguments, is not the user's, nor is the copy of a turn in the blob of the request after it.

THE REPLIES OF ONE SUBAGENT (#857), with `--replies=<name>` and nothing else: every message the
subagent whose `.meta.json` has that `name` sent with SendMessage, whole and in the order sent, each
under a line with its number, its recipient and its summary, and nothing else. It prints no
figure. It is how a session gets back the pre-PR reviewer's replies once a compaction has taken
them out of its context: they are read from the reviewer's own transcript, where each is a
SendMessage call held whole, not from the session's, where a reply can arrive cut off in an idle
notice and share a turn with another. A call the transcript repeats, in a streamed line or in the
blob of the request after it, is printed once. A message that is not text, a shutdown response,
is left out and counted on stderr. A name no subagent has, or that two have, and a subagent that
sent no text, each exit 1. This mode's output is in UTF-8 whatever the console's encoding, since a
reply can hold `→`, which cp1252 cannot; the figures are printed in the console's, as before.

WHAT IT CANNOT SEE: the text a subagent ends its turn with, which `--replies` does not print. It
reaches the session in the idle notice, cut off where it is long, and says again what the reply
said; a subagent that answered only there is one that sent no text. Nor when a figure was read.
The pre-PR reviewer goes on after its row is written, so a later run prints more than the row
holds; review-figures.md says which reading a row keeps. Nor which turn the user typed. A
subagent's hand-back, a message from another session and a task notice are each a turn of the
user's in the transcript where it is not marked isMeta, so a text that one of them holds can
start or end the part there: `--until=merge` stopped #669's part at a hand-back, 34 requests in.
Where the user's own turn holds it too, the two are listed and nothing is measured, unless one of
them says the text whole. Give a text
that the user's own turn holds and those do not.
Nor a compaction's summary whose copy opens with other words than the first sentence held in
`SUMMARY`: it is read as the user's, and can start the part.

`--self-test` builds a session of seven subagents and eight requests of its own in a temporary
directory, and beside it a second directory of four subagents for `--replies`: one whose replies it
prints through a console that is told it is cp1252, two that share a name, and one that sent no
text. It exits non-zero when a figure printed for either, an exit code or the replies' text, is not
the one worked out by hand below. It is run by scripts/run-gates.ps1 and
by .github/workflows/gates.yml.
"""
import contextlib
import glob
import io
import json
import os
import re
import subprocess
import sys
import tempfile

GROUPS = {"step": "steps", "reviewer": "reviewers", "scorer": "scorers", "verifier": "verifier"}
CELLS = (("steps", "the three steps"), ("reviewers", "reviewers"), ("scorers", "scorers"),
         ("verifier", "the verifier"))
SUMMARY = "This session is being continued from a previous conversation that ran out of context."
COMMAND = re.compile(r"<command-name>(.*?)</command-name>", re.S)
ARGS = re.compile(r"<command-args>(.*?)</command-args>", re.S)
NOTICE = re.compile(r"<tool-use-id>(\w+)</tool-use-id>.*?<subagent_tokens>(\d+)</subagent_tokens>",
                    re.S)


def total(usage):
    return sum(v for k, v in usage.items() if k.endswith("_tokens") and isinstance(v, int))


def read(path):
    """A transcript's last request, all its requests, the cache reads among them, their count."""
    order, use = [], {}
    for line in open(path, encoding="utf-8"):
        m = json.loads(line).get("message") or {}
        if m.get("role") == "assistant" and total(m.get("usage") or {}):
            if m["id"] not in use:
                order.append(m["id"])
            use[m["id"]] = m["usage"]
    if not order:
        return 0, 0, 0, 0
    return (total(use[order[-1]]), sum(map(total, use.values())),
            sum(u.get("cache_read_input_tokens", 0) for u in use.values()), len(order))


def notices(directory):
    """The count each finished subagent reported, by the id of the tool call that spawned it."""
    session = os.path.dirname(os.path.abspath(directory)) + ".jsonl"
    found = {}
    if os.path.exists(session):
        for line in open(session, encoding="utf-8"):
            entry = json.loads(line)
            # The three places a notice is kept: delivered as a turn, queued, or attached to one.
            for content in ((entry.get("message") or {}).get("content"), entry.get("content"),
                            (entry.get("attachment") or {}).get("prompt")):
                if isinstance(content, str) and content.lstrip().startswith("<task-notification>"):
                    for call, count in NOTICE.findall(content):
                        found[call] = int(count)        # a subagent that stopped twice: the last
    return found


def typed(entry):
    """What a user's turn says, a tool's output, a compaction's summary and a meta turn left out.

    A slash command's turn also says the command as typed, `/<name> <args>` (#856). A turn marked
    isMeta, as the skill's text a command loads, which ends with the command's arguments, is not
    the user's, nor is the copy of a turn in the blob of the request after it (#897)."""
    m = entry.get("message") or {}
    if m.get("role") != "user" or entry.get("isCompactSummary") or entry.get("isMeta") \
            or entry.get("type") == "api-request-blob":
        return ""
    content = m.get("content")
    if not isinstance(content, str):
        content = "\n".join(c.get("text", "") for c in content or []
                            if isinstance(c, dict) and c.get("type") == "text")
    if content.lstrip().startswith(SUMMARY):       # the copy a later turn carries, unflagged
        return ""
    name = COMMAND.search(content)
    if name:
        args = ARGS.search(content)
        content += "\n" + " ".join(filter(None, (name.group(1).strip(),
                                                 args.group(1).strip() if args else "")))
    return content


def main_session(directory, since=None, until=None):
    """The session's own requests, from the turn holding `since` to the one holding `until`.

    `since hits` and `until hits` list each turn that holds the text, the second counted after
    the first's turn, or only the one turn that says the text whole where there is one. A text
    more than one turn holds and none says whole bounds nothing, and nothing is measured (#897):
    the first of them is not taken to be the one meant."""
    session = os.path.dirname(os.path.abspath(directory)) + ".jsonl"
    if not os.path.exists(session):
        return None
    entries = [json.loads(line) for line in open(session, encoding="utf-8")]
    said = [typed(entry) for entry in entries]

    def hits(text, start):
        at = [i for i in range(start, len(entries)) if text in said[i]]
        whole = [i for i in at if said[i].strip() == text.strip()]
        return whole if len(whole) == 1 else at     # the one turn that says it whole bounds

    since_at = hits(since, 0) if since is not None else []
    start = since_at[0] if len(since_at) == 1 else 0
    bounded = since is None or len(since_at) == 1       # else `until` is not looked for
    until_at = hits(until, start + 1 if since_at else 0) if until and bounded else []
    end = until_at[0] if len(until_at) == 1 else len(entries)
    order, use = [], {}
    measured = bounded and len(until_at) < 2
    for entry in entries[start:end] if measured else ():
        m = entry.get("message") or {}
        if m.get("role") == "assistant" and total(m.get("usage") or {}):
            if m["id"] not in use:
                order.append(m["id"])
            use[m["id"]] = m["usage"]
    first = use[order[0]] if order else {}

    def turn(i):
        words = " ".join(said[i].split())
        return (entries[i].get("timestamp") or "no timestamp",
                words if len(words) <= 60 else words[:60] + "...")    # cp1252 has no ellipsis
    return {"requests": len(order), "all": sum(map(total, use.values())),
            "reads": sum(u.get("cache_read_input_tokens", 0) for u in use.values()),
            "first": total(first) - first.get("output_tokens", 0),
            "since found": since is None or bool(since_at),
            "until found": until is None or bool(until_at),
            "since hits": [turn(i) for i in since_at], "until hits": [turn(i) for i in until_at]}


def replies(directory, name):
    """Every text message the subagent called `name` sent, in order, and how many were not text.

    None when no subagent has that name, and the matching transcripts' paths when more than one
    does."""
    found = [p[:-len(".meta.json")] + ".jsonl"
             for p in sorted(glob.glob(os.path.join(directory, "agent-*.meta.json")))
             if json.load(open(p, encoding="utf-8")).get("name") == name]
    if len(found) != 1:
        return found or None
    sent, seen, other = [], set(), 0
    for line in open(found[0], encoding="utf-8"):
        content = (json.loads(line).get("message") or {}).get("content")
        for c in content if isinstance(content, list) else []:
            if not (isinstance(c, dict) and c.get("type") == "tool_use"
                    and c.get("name") == "SendMessage") or c.get("id") in seen:
                continue
            # A streamed line, and the blob of the request after it, repeat the call they hold.
            seen.add(c.get("id"))
            said = c.get("input") or {}
            if isinstance(said.get("message"), str):
                sent.append((said.get("to"), said.get("summary"), said["message"]))
            else:
                other += 1
    return sent, other


def report_replies(sent):
    return "\n\n".join(f"=== {i} of {len(sent)}, to {to}: {summary or '(no summary)'}\n{message}"
                       for i, (to, summary, message) in enumerate(sent, 1))


def collect(directory, texts=()):
    """One row for each subagent: its group, its figures and its description."""
    reported, rows = notices(directory), []
    for path in sorted(glob.glob(os.path.join(directory, "agent-*.jsonl"))):
        beside = path[:-len(".jsonl")] + ".meta.json"
        meta = json.load(open(beside, encoding="utf-8")) if os.path.exists(beside) else {}
        said = meta.get("description", "")
        named = said + " " + meta.get("name", "")
        word = re.search(r"\b(step|reviewer|scorer|verifier)\b", said, re.I)
        group = "pre-PR" if said.lower().startswith("pre-pr") else \
            GROUPS[word.group(1).lower()] if word else "UNSORTED"
        if texts and not any(re.search(re.escape(t) + r"(?!\d)", named, re.I) for t in texts):
            group = "LEFT OUT"
        last, every, reads, requests = read(path)
        rows.append({"group": group, "reported": reported.get(meta.get("toolUseId")), "last": last,
                     "all": every, "reads": reads, "requests": requests, "said": said})
    return rows


def summarise(rows):
    """Each group's sums, and the plugin pass's groups summed."""
    sums = {}
    for r in rows:
        s = sums.setdefault(r["group"], {"subagents": 0, "reported": 0, "unreported": 0, "last": 0,
                                         "all": 0, "reads": 0, "requests": 0})
        s["subagents"] += 1
        s["reported"] += r["reported"] or 0
        s["unreported"] += r["reported"] is None
        for k in ("last", "all", "reads", "requests"):
            s[k] += r[k]
    plugin = [sums[g] for g, _ in CELLS if g in sums]
    sums["plugin pass"] = {k: sum(s[k] for s in plugin) for k in ("all", "reads")}
    return sums


def n(count):
    return f"{count:,}".replace(",", " ")       # grouped as the tables write a figure


def share(part, whole):
    return f"{100 * part / whole:.1f}%" if whole else "nothing to take a share of"


def report_session(found, since, until):
    """The lines for the main session: what the pull request's body takes, and no table."""
    span = "the whole transcript" if since is None else \
        f'from the turn that says "{since}" to ' + (
            f'the one that says "{until}"' if until else "the end")
    out = ["", f"THE MAIN SESSION, for the pull request's body: {span}"]
    ambiguous = found and next(((text, found[key]) for text, key in
                                ((since, "since hits"), (until, "until hits"))
                                if len(found[key]) > 1), None)
    if found is None:
        out.append("  no transcript beside the directory, so not measured")
    elif ambiguous:
        text, turns = ambiguous
        out.append(f'  not measured: {len(turns)} turns of the user say "{text}"' +
                   (f' after the one that says "{since}"' if text == until and since else "") +
                   ", so give a text only the one meant holds:")
        out.extend(f'    {when}: "{words}"' for when, words in turns)
    elif not found["since found"]:
        out.append(f'  not measured: no turn of the user says "{since}"')
    elif not found["until found"]:
        out.append(f'  not measured: no turn of the user says "{until}"' +
                   (f' after the one that says "{since}"' if since else ""))
    elif not found["requests"]:
        out.append("  no request there" + (f': the turn that says "{since}" has none after it'
                                           if since else ": the transcript holds none"))
    else:
        out.append(f"  {found['requests']} requests, {n(found['all'])} tokens over all of them; of "
                   f"that, cache reads {share(found['reads'], found['all'])}; the context of the "
                   f"first request was {n(found['first'])} tokens")
    return "\n".join(out)


def report(rows):
    out = [f"{'group':10}{'reported':>11}{'last request':>14}{'all requests':>14}"
           f"{'cache reads':>13}{'requests':>10}  description"]
    for r in rows:
        told = "no notice" if r["reported"] is None else n(r["reported"])
        out.append(f"{r['group']:10}{told:>11}{n(r['last']):>14}{n(r['all']):>14}"
                   f"{n(r['reads']):>13}{r['requests']:>10}  {r['said']}")
    sums = summarise(rows)
    pre = sums.get("pre-PR")
    out += ["", "THE FIRST TABLE: what its subagents reported"]
    if pre:
        out.append(f"  pre-PR review's cost                {n(pre['last'])} tokens at its last "
                   f"request, {pre['subagents']} reviewer(s)")
    for g, cell in CELLS:
        s = sums.get(g)
        if s:
            short = f"; {s['unreported']} sent no notice, so this is short" if s["unreported"] else ""
            out.append(f"  plugin pass's cost: {cell:16}{n(s['reported'])} tokens, "
                       f"{s['subagents']} subagent(s){short}")
    out += ["", "THE SECOND TABLE: over all requests"]
    if pre:
        out.append(f"  pre-PR review                    {n(pre['all'])} tokens in "
                   f"{pre['requests']} requests; of that, cache reads {share(pre['reads'], pre['all'])}")
    for g, cell in CELLS:
        s = sums.get(g)
        if s:
            out.append(f"  plugin pass: {cell:20}{n(s['all'])} tokens, {s['subagents']} subagent(s)")
    plugin = sums["plugin pass"]
    if plugin["all"]:
        out.append(f"  plugin pass: those summed        {n(plugin['all'])} tokens; of that sum, "
                   f"cache reads {share(plugin['reads'], plugin['all'])}")
    for g in ("UNSORTED", "LEFT OUT"):
        if g in sums:
            out.append(f"\n{g}, in no sum above: {sums[g]['subagents']} subagent(s), "
                       f"{n(sums[g]['all'])} tokens over all requests. They are the rows marked "
                       f"{g} at the top.")
    return "\n".join(out)


REPLIES_WANTED = ("=== 1 of 2, to team-lead: two findings\n"
                  "1. a.py: the arrow → is wrong.\n2. b.md: so is the dash — here.\n\n"
                  "=== 2 of 2, to team-lead: both fixed\n"
                  "Both are fixed.\n")


def replies_test(directory):
    """What --replies prints for a subagent whose replies are kept the ways a real one's are."""
    def send(tool, to, summary, message):
        return {"type": "tool_use", "id": tool, "name": "SendMessage",
                "input": {"to": to, "summary": summary, "message": message,
                          "content": str(message)[:20] + "…"}}

    first = send("toolu_r1", "team-lead", "two findings",
                 "1. a.py: the arrow → is wrong.\n2. b.md: so is the dash — here.")
    second = send("toolu_r2", "team-lead", "both fixed", "Both are fixed.")
    lines = [
        {"type": "user", "message": {"role": "user", "content": "review this"}},
        {"type": "assistant", "message": {"role": "assistant", "id": "r1", "content": [
            {"type": "tool_use", "id": "toolu_b", "name": "Bash", "input": {"command": "ls"}}]}},
        {"type": "assistant", "message": {"role": "assistant", "id": "r2", "content": [first]}},
        # The request that follows carries the same call again, as a real transcript does.
        {"type": "api-request-blob", "message": {"role": "assistant", "content": [first]}},
        {"type": "assistant", "message": {"role": "assistant", "id": "r3", "content": [
            {"type": "text", "text": "I sent the team lead two findings."}]}},
        {"type": "assistant", "message": {"role": "assistant", "id": "r4", "content": [second]}},
        {"type": "assistant", "message": {"role": "assistant", "id": "r4", "content": [second]}},
        {"type": "assistant", "message": {"role": "assistant", "id": "r5", "content": [
            send("toolu_r3", "team-lead", None, {"type": "shutdown_response", "approve": True})]}},
    ]
    os.makedirs(directory)
    # The fourth answered only in the text it ended its turn with, which is not printed.
    for file, name, kept in (("agent-aprepr-9-1", "prepr-9", lines),
                             ("agent-atwin-1", "twin", lines), ("agent-atwin-2", "twin", lines),
                             ("agent-asilent-1", "silent", lines[:2] + lines[4:5])):
        with open(os.path.join(directory, file + ".meta.json"), "w", encoding="utf-8") as f:
            json.dump({"description": "Pre-PR review of a-branch", "name": name}, f)
        with open(os.path.join(directory, file + ".jsonl"), "w", encoding="utf-8") as f:
            f.write("".join(json.dumps(line) + "\n" for line in kept))
    # Printed through a console that cannot encode the arrow, as #854's could not.
    run = subprocess.run(
        [sys.executable, os.path.abspath(__file__), directory, "--replies=prepr-9"],
        capture_output=True, env={**os.environ, "PYTHONIOENCODING": "cp1252"})
    quiet = io.StringIO()
    with contextlib.redirect_stdout(quiet), contextlib.redirect_stderr(quiet):
        nobody = main([directory, "--replies=prepr-8"])
        twice = main([directory, "--replies=twin"])
        silent = main([directory, "--replies=silent"])
    return {"replies, exit for a subagent that sent no text": silent,
            "replies, exit with cp1252 output": run.returncode,
            "replies, printed in UTF-8":
                run.stdout.decode("utf-8", "replace").replace("\r\n", "\n"),
            "replies, exit for a name no subagent has": nobody,
            "replies, exit for a name two have": twice}


def self_test():
    """Seven subagents with small figures, and the sums of them worked out by hand."""
    def usage(i, o, w, r):
        return {"input_tokens": i, "output_tokens": o, "cache_creation_input_tokens": w,
                "cache_read_input_tokens": r, "service_tier": "standard"}

    def said(mid, u):
        return {"message": {"role": "assistant", "id": mid, "usage": u}}

    agents = {       # name: (description, tool call, transcript lines)
        "a1": ("plugin pass #9: eligibility step", "toolu_1",
               [said("m1", usage(1, 2, 3, 4)), {"message": {"role": "user", "content": "x"}}]),
        # m2 is streamed twice and counts once, at its last line: 100, not 40 + 100.
        "a2": ("plugin pass #9: reviewer 1, pre-PR findings in the body", "toolu_2",
               [said("m2", usage(10, 10, 10, 10)), said("m2", usage(10, 20, 30, 40)),
                said("m3", usage(1, 1, 1, 7))]),
        "a3": ("plugin pass #9: scorer A, the reviewer skipped a step", "toolu_3", [said("m4", usage(5, 5, 0, 90))]),
        "a4": ("Pre-PR review of a-branch", None,
               [said("m5", usage(100, 0, 0, 0)), said("m6", usage(0, 50, 0, 150))]),
        "a5": ("PR #95 eligibility check", "toolu_5", [said("m7", usage(1000, 0, 0, 0))]),
        "a6": (None, None, [said("m8", usage(7, 0, 0, 0))]),        # no .meta.json beside it
        # A verifier whose candidates are a reviewer's is still the verifier.
        "a7": ("plugin pass #9: verifier, two candidates of reviewer 1", "toolu_7",
               [said("m9", usage(2, 3, 5, 20))]),
    }
    with tempfile.TemporaryDirectory() as scratch:
        directory = os.path.join(scratch, "session", "subagents")
        os.makedirs(directory)
        for name, (description, call, lines) in agents.items():
            if description:
                with open(os.path.join(directory, f"agent-{name}.meta.json"), "w", encoding="utf-8") as f:
                    json.dump({"description": description, "toolUseId": call}, f)
            with open(os.path.join(directory, f"agent-{name}.jsonl"), "w", encoding="utf-8") as f:
                f.write("".join(json.dumps(line) + "\n" for line in lines))
        notice = ("<task-notification>\n<tool-use-id>{}</tool-use-id>\n<usage><subagent_tokens>{}"
                  "</subagent_tokens></usage>\n</task-notification>")
        with open(os.path.join(scratch, "session.jsonl"), "w", encoding="utf-8") as f:
            for call, count in (("toolu_2", 1), ("toolu_2", 105), ("toolu_7", 31)):
                f.write(json.dumps({"message": {"role": "user",
                                                "content": notice.format(call, count)}}) + "\n")
            f.write(json.dumps({"type": "queue-operation",
                                "content": notice.format("toolu_1", 11)}) + "\n")
            f.write(json.dumps({"attachment": {"type": "queued_command",
                                               "prompt": notice.format("toolu_5", 999)}}) + "\n")
            # A notice quoted in a tool's output is not a notice.
            f.write(json.dumps({"message": {"role": "user", "content": [
                {"type": "tool_result", "content": notice.format("toolu_3", 77777)}]}}) + "\n")
            # The main session's own requests. "write #9" starts the part for #9 where the user
            # says it, not where a tool's output holds it, and "merged #9" ends that part.
            for entry in (
                    {"message": {"role": "user", "content": "write #8"}},
                    said("s1", usage(1, 2, 3, 4)),
                    {"message": {"role": "user", "content": [
                        {"type": "tool_result", "content": "write #9"}]}},
                    said("s2", usage(2, 0, 0, 0)),
                    {"message": {"role": "user", "content": [
                        {"type": "text", "text": "write #9"}]}},
                    said("s3", usage(10, 1, 20, 100)), said("s3", usage(10, 5, 20, 100)),
                    said("s4", usage(0, 1, 0, 200)),
                    {"message": {"role": "user", "content": "merged #9"}},
                    # The blob of the request after it copies the turn, and is not a turn: else
                    # "merged #9" would be two turns that say it whole (#897).
                    {"type": "api-request-blob", "message": {"role": "user",
                                                             "content": "merged #9"}},
                    said("s5", usage(1000, 0, 0, 0)),
                    # A slash command is kept as tags, so "/implement #10 #11" is in no turn as
                    # typed (#856). The summary a compaction leaves quotes it, once with the flag
                    # and once in a later turn without; neither starts a part, and a text only
                    # they hold is not found. The flagged one opens with other words, so that the
                    # flag alone has to keep it out.
                    {"message": {"role": "user", "content":
                        "<command-message>implement</command-message>\n<command-name>/implement"
                        "</command-name>\n<command-args>#10 #11</command-args>"}},
                    # The skill's text the command loads ends with its arguments, and is marked
                    # isMeta: it is not the user's, so "#10 #11" is one turn's text (#897).
                    {"isMeta": True, "message": {"role": "user", "content": [{"type": "text",
                        "text": "Base directory for this skill: x\n\nARGUMENTS: #10 #11"}]}},
                    said("s6", usage(10000, 0, 0, 0)),
                    {"isCompactSummary": True, "message": {"role": "user", "content":
                        "The conversation so far: the user ran `/implement #10 #11`, then said "
                        "write #12."}},
                    said("s7", usage(20000, 0, 0, 0)),
                    {"message": {"role": "user", "content": [{"type": "text", "text":
                        SUMMARY + " The user ran `/implement #10 #11`, then said write #13."}]}},
                    said("s8", usage(40000, 0, 0, 0)),
                    # "write #9" is now in two turns, and only the first says it whole: that one
                    # still bounds the part, as a one-word "continue" has to (#897).
                    {"message": {"role": "user", "content": "write #9 again"}}):
                f.write(json.dumps(entry) + "\n")
        sums = summarise(collect(directory))
        only = summarise(collect(directory, ["#9"]))
        whole = main_session(directory)
        part = main_session(directory, "write #9", "merged #9")
        open_ended = main_session(directory, "write #9")
        never = main_session(directory, "write #7")
        slash = main_session(directory, "/implement #10 #11")
        flagged = main_session(directory, "write #12")
        unflagged = main_session(directory, "write #13")
        # A text several turns hold is a failure that names each, not the first of them (#897):
        # "#9" is in "write #9", "merged #9" and "write #9 again", and all three come after
        # "write #8"; none of them says "#9" whole.
        two = main_session(directory, "#9")
        two_after = main_session(directory, "write #8", "#9")
        named = report_session(two, "#9", None) + report_session(two_after, "write #8", "#9")
        args_only = main_session(directory, "#10 #11")
        no_since = main_session(directory, "write #7", "#9")     # --until is not looked for
        # A text no turn holds is a failure, not a figure of nothing (#856).
        quiet = io.StringIO()
        with contextlib.redirect_stdout(quiet), contextlib.redirect_stderr(quiet):
            exits = {"since": main([directory, "--since=write #7"]),
                     "until": main([directory, "--since=write #9", "--until=write #7"]),
                     "both": main([directory, "--since=write #9", "--until=merged #9"]),
                     "two since": main([directory, "--since=#9"]),
                     "two until": main([directory, "--since=write #8", "--until=#9"])}
        replied = replies_test(os.path.join(scratch, "replies", "subagents"))
    got = {
        "steps reported": sums["steps"]["reported"], "steps all": sums["steps"]["all"],
        "reviewers reported": sums["reviewers"]["reported"], "reviewers all": sums["reviewers"]["all"],
        "reviewers last": sums["reviewers"]["last"], "reviewers requests": sums["reviewers"]["requests"],
        "scorers reported": sums["scorers"]["reported"], "scorers unreported": sums["scorers"]["unreported"],
        "scorers all": sums["scorers"]["all"],
        "verifier reported": sums["verifier"]["reported"], "verifier all": sums["verifier"]["all"],
        "plugin all": sums["plugin pass"]["all"], "plugin reads": sums["plugin pass"]["reads"],
        "pre-PR last": sums["pre-PR"]["last"], "pre-PR all": sums["pre-PR"]["all"],
        "pre-PR reads": sums["pre-PR"]["reads"], "pre-PR requests": sums["pre-PR"]["requests"],
        "unsorted all": sums["UNSORTED"]["all"], "unsorted reported": sums["UNSORTED"]["reported"],
        "left out with #9 given": only["LEFT OUT"]["subagents"], "plugin all with #9 given": only["plugin pass"]["all"],
        "session requests": whole["requests"], "session all": whole["all"],
        "part requests": part["requests"], "part all": part["all"], "part reads": part["reads"],
        "part first context": part["first"], "part to the end, all": open_ended["all"],
        "part never started, requests": never["requests"],
        "slash command's part, requests": slash["requests"],
        "slash command's part, all": slash["all"],
        "only the flagged summary holds it, requests": flagged["requests"],
        "only the unflagged copy holds it, requests": unflagged["requests"],
        "exit, --since no turn holds": exits["since"],
        "exit, --until no turn holds": exits["until"], "exit, both found": exits["both"],
        "--since three turns hold, requests": two["requests"],
        "--since three turns hold, turns named": len(two["since hits"]),
        "--until three turns after it hold, requests": two_after["requests"],
        "--until three turns after it hold, turns named": len(two_after["until hits"]),
        "write #9 and merged #9 each named in both reports":
            (named.count('"write #9"'), named.count('"merged #9"')),
        "exit, --since three turns hold": exits["two since"],
        "exit, --until three turns after it hold": exits["two until"],
        "the command's arguments alone, requests": args_only["requests"],
        "--since no turn holds, --until's turns named": len(no_since["until hits"]),
        **replied,
    }
    want = {
        "steps reported": 11, "steps all": 10,
        "reviewers reported": 105, "reviewers all": 110, "reviewers last": 10, "reviewers requests": 2,
        "scorers reported": 0, "scorers unreported": 1, "scorers all": 100,
        "verifier reported": 31, "verifier all": 30,
        "plugin all": 250, "plugin reads": 161,        # 10 + 110 + 100 + 30, and 4 + 47 + 90 + 20
        "pre-PR last": 200, "pre-PR all": 300, "pre-PR reads": 150, "pre-PR requests": 2,
        "unsorted all": 1007, "unsorted reported": 999,     # the two with no word to sort by
        # The pre-PR reviewer, "PR #95 eligibility check" and the one with no description.
        "left out with #9 given": 3, "plugin all with #9 given": 250,
        # 10 + 2 + 135 + 201 + 1000, and s6 to s8's 10 000 + 20 000 + 40 000.
        "session requests": 8, "session all": 71348,
        # s3 and s4. s3 is streamed twice and counts once; its context is 10 + 20 + 100.
        "part requests": 2, "part all": 336, "part reads": 300, "part first context": 130,
        "part to the end, all": 71336, "part never started, requests": 0,
        # From the command's own turn: s6, s7 and s8. From the flagged summary it would be 2.
        "slash command's part, requests": 3, "slash command's part, all": 70000,
        "only the flagged summary holds it, requests": 0,
        "only the unflagged copy holds it, requests": 0,
        "exit, --since no turn holds": 1, "exit, --until no turn holds": 1, "exit, both found": 0,
        "--since three turns hold, requests": 0, "--since three turns hold, turns named": 3,
        "--until three turns after it hold, requests": 0,
        "--until three turns after it hold, turns named": 3,
        "write #9 and merged #9 each named in both reports": (2, 2),
        "exit, --since three turns hold": 1, "exit, --until three turns after it hold": 1,
        # The command's turn only, not the skill's text it loads: s6, s7 and s8.
        "the command's arguments alone, requests": 3,
        "--since no turn holds, --until's turns named": 0,
        # The two replies whole, in order, and nothing else: not the copy in the request blob,
        # not the second streamed line, not the shutdown response, not the closing text (#857).
        "replies, exit with cp1252 output": 0, "replies, printed in UTF-8": REPLIES_WANTED,
        "replies, exit for a name no subagent has": 1, "replies, exit for a name two have": 1,
        "replies, exit for a subagent that sent no text": 1,
    }
    wrong = [f"{k}: {got[k]}, wanted {want[k]}" for k in want if got[k] != want[k]]
    for w in wrong:
        print(f"WRONG: {w}", file=sys.stderr)
    print(f"{len(want) - len(wrong)} of {len(want)} figures summed as wanted.")
    return 1 if wrong else 0


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv == ["--self-test"]:
        return self_test()
    if not argv or not os.path.isdir(argv[0]):
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        print("Give the session's subagents directory.", file=sys.stderr)
        return 2
    bound = {"--since": None, "--until": None, "--replies": None}
    texts = []
    for arg in argv[1:]:
        key, _, value = arg.partition("=")
        if not arg.startswith("--"):
            texts.append(arg)
        elif key in bound and value:
            bound[key] = value
        else:       # a mistyped option would otherwise be a text no subagent holds
            print(f"{arg}: the options are --since=<text>, --until=<text> and --replies=<name>.",
                  file=sys.stderr)
            return 2
    if bound["--replies"]:
        if texts or bound["--since"] or bound["--until"]:
            print("--replies=<name> takes the directory and nothing else.", file=sys.stderr)
            return 2
        found = replies(argv[0], bound["--replies"])
        if not isinstance(found, tuple):
            print(f'No subagent in {argv[0]} is named "{bound["--replies"]}".' if found is None else
                  f'{len(found)} subagents are named "{bound["--replies"]}": '
                  + ", ".join(map(os.path.basename, found)), file=sys.stderr)
            return 1
        sent, other = found
        if not sent:        # an empty print would read as a reviewer that said nothing
            print(f'"{bound["--replies"]}" sent no text with SendMessage.', file=sys.stderr)
            return 1
        # A reply holds what the console's own encoding may not, `→` in cp1252 (#857).
        for stream in (sys.stdout, sys.stderr):
            if hasattr(stream, "reconfigure"):
                stream.reconfigure(encoding="utf-8")
        print(report_replies(sent))
        if other:
            print(f"Left out: {other} message(s) that are not text, such as a shutdown response.",
                  file=sys.stderr)
        return 0
    rows = collect(argv[0], texts)
    if not rows:
        print(f"No agent-*.meta.json in {argv[0]}.", file=sys.stderr)
        return 2
    print(report(rows))
    found = main_session(argv[0], bound["--since"], bound["--until"])
    print(report_session(found, bound["--since"], bound["--until"]))
    if found and (len(found["since hits"]) > 1 or len(found["until hits"]) > 1):
        many = bound["--since"] if len(found["since hits"]) > 1 else bound["--until"]
        print(f'More than one turn of the user says "{many}", so the main session is not '
              "measured.", file=sys.stderr)
        return 1
    if found and not (found["since found"] and found["until found"]):
        missed = bound["--since"] if not found["since found"] else bound["--until"]
        print(f'No turn of the user says "{missed}", so the main session is not measured.',
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

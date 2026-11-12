---
name: recap
description: Report where this session actually stands and whether it is safe to archive. Use when the user says "recap", "/recap", "where are we", "status", "what's the state of this", "can I close this", "is this done", or returns to a session after being away — including weeks later. Refreshes stale external state first (PR, CI, background jobs, linked threads), then reports goal / status+evidence / blockers / next steps / archive verdict. Starts no new work.
---

# Recap

You have been away from this session, or the user has. Assume everything you
remember about external state is stale.

## Rule zero: start nothing

A recap changes nothing. No edits, no commits, no pushes, no new tasks, no
"while I'm here let me just fix". Read-only commands only. If you spot work
that needs doing, it goes in **Next** as a proposal, not in the transcript as
a diff. The user will tell you to go.

## Step 1: refresh (a minute or two, not a research project)

Re-check anything with a real-world state that can move without you. Only what
this session actually touched — skip a line if it doesn't apply, don't go
hunting for things to check:

- **Branch/PR** — `git status -sb`, `git log --oneline -5`, and if there's a PR:
  `gh pr view --json number,title,state,isDraft,mergeable,statusCheckRollup,reviews,comments`
- **CI** — `gh pr checks` / `gh run list -b <branch> -L 3`. Failing? get the reason:
  `gh run view --log-failed`.
- **Jobs you started** — background Bash shells, running subagents, deploys,
  long test runs. Check them, don't assume they finished clean.
- **Linked threads / tickets** — any Slack thread, GitHub issue, or ticket
  referenced in this session. Someone may have replied.
- **Working tree** — uncommitted or stashed changes you forgot about.
- **Overtaken by events** — this session may be weeks old. Did the PR merge?
  Was the branch deleted? Has someone else fixed it on main
  (`git log origin/main --oneline -10 -- <paths>`)? Is the file you were
  editing gone or rewritten? Work can finish, or become moot, without you.

Run the independent checks in one batch.

## Step 2: report exactly four things

### 1. Goal — in the user's words
Quote or closely paraphrase what they originally asked for. Not your
restatement of it, not what it turned into. If the goal shifted mid-session,
say so: "started as X, you redirected to Y."

### 2. Status — and the evidence
For each workstream: what state it's in, and *what proves it*. Name the
artifact — PR number, check name, commit sha, log line, URL.

**Unit tests passing does not count as proven.** Nor does "the code looks
right", "it compiles", "I implemented it", or a green lint. Proof is: it ran
end to end, in something resembling the real environment, and someone observed
the outcome. Say which one you have:

- **Proven** — ran it, saw it work. Name where.
- **Implemented, unverified** — code exists, nothing exercised it for real.
- **In flight** — running now. Say what and where the result will appear.
- **Untouched** — in scope, not started.

Prefer "implemented, unverified" over rounding up. Rounding up is the failure
mode this whole skill exists to prevent.

### 3. Blocked on — person or machine
Split them, they need different responses:

- **Blocked on you (the user)** — a decision, an approval, a credential, a
  merge only they can do. State the question in one line, with your
  recommendation if you have one.
- **Blocked on technical** — failing test, missing dep, broken env, upstream
  outage, flake. State what's stuck and the leading hypothesis.

Nothing blocked? Say "nothing blocked."

### 4. Next — each marked mine or yours
Short list, ordered, nothing speculative. Mark every item **[me]** or
**[you]**. An item that needs the user is not on your list.

### 5. Disposition — safe to archive?
End with an explicit verdict. One of:

- **✅ Safe to archive** — goal met and proven, nothing unfinished, and nothing
  of value lives only in this transcript.
- **📦 Done — capture first** — the work is finished, but N follow-ups/decisions
  exist nowhere but here. List them. Offer to file them: "say the word and I'll
  open issues / write them to memory." Do not file them unprompted (rule zero).
- **🔀 Moot — superseded** — someone else shipped it, the branch merged, or the
  problem stopped existing. Say what overtook it and how you know.
- **🚧 Live — do not archive** — unfinished work, an open PR, a running job, or
  an unanswered question. One line on what keeps it open.

**The archive test is durability, not doneness.** A session is safe to close
when every surviving thing — an unmerged branch, a known bug you chose not to
fix, a decision and its reasoning, a "we should really…" — exists somewhere
you'd find it without this transcript: a merged commit, an issue, a memory
file, a doc, a message to someone. If it only exists in the scrollback, the
answer is **capture first**, however finished the code is.

Surface follow-ups the session *generated* even when they're out of scope —
the TODO you left, the flaky test you worked around, the ugly thing you noticed
in passing. Those are exactly what evaporates on archive.

## Shape

Terse. Sections, not prose. A recap is for orienting in fifteen seconds, so
lead with what changed since they last looked, and land the summary at the
bottom (below). If the session is one small
workstream, four short sections; if it's several, group by workstream and keep
each to a few lines.

If the session is genuinely old, lead with the verdict too — weeks later,
"this merged in July, nothing outstanding" is the whole answer and the five
sections can be two lines each.

## The last thing on screen

A recap prints to a terminal; the user's eyes land at the *bottom*. So the
summary goes last, after everything else — not at the top where it scrolls
away. Close every recap with exactly this block and nothing after it:

```
**TL;DR** — <verdict emoji + name> · <the one fact that matters>
<one line: what actually happened, in plain words>
Next: [me] <first action> · [you] <what needs them, or "nothing">
```

Three lines. Readable alone by someone who scrolled past the rest. Rules:

- Line 1 repeats the §5 verdict verbatim — that's the point of the block.
- If anything is unproven or unverified, it goes in line 1, not buried above.
  "✅ Safe to archive" on line 1 while line 2 admits the tests never ran is the
  one unforgivable recap bug.
- `[you]` is "nothing" or a real ask, never filler.
- Nothing follows the TL;DR. No sign-off, no offer, no question. The `[me]`
  line already says what happens if they say go, and don't frame it as a
  stopping point — the session is still running.

## Refusals

- Asked to recap and fix in the same breath? Recap first, in full, then act.
- Can't verify something (auth expired, no network, job vanished)? Say
  "unverified: <reason>" — never fill the gap with what you remember.
- Can't establish the archive verdict because a check failed? Default to
  **🚧 Live** and name the unverified check. Never guess "safe."
- Asked "is this done?" — that's a recap. Run the whole thing, not just §5.

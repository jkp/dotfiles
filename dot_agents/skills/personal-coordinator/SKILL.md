---
name: personal-coordinator
description: Coordinate an outcome across delegated threads in T3 Code, using Beads as the local context store between threads. Use when Jamie asks to coordinate, orchestrate, or work through a multi-part outcome, or when a thread is set up or adopted as a coordinator.
---

# Personal coordinator

You are the coordinator for one outcome. You delegate the work;
you do not do it yourself, and you do not become a megathread.

## 1. Mandate first

Record the mandate in your first reply, then proceed under it.
Do not wait for approval to delegate.

- the outcome and its done condition, in one sentence
- your authority: what you may merge, spend, or decide without
  asking. When it includes merging, load the `jamie-merge-gate`
  skill now, before delegating: its charter governs every PR this
  coordinator produces.
- the WIP ceiling: how many delegates may run at once
- the stop condition: when you report back instead of continuing

Delegation inside this mandate is pre-authorised; never ask
per delegate. Ask Jamie only when a missing or exceeded element
would change what you do next — one grouped question, with a
recommendation, while unaffected work continues. Where the
outcome was already given, infer the rest conservatively and
state what you inferred.

## 2. Read before you delegate

If this outcome has a Bead (epic or task), read it and its children,
comments, and linked PRs before spawning anything. If it has none
and the work will outlive this thread, create one Bead holding the
mandate. The Bead is the memory; this thread is disposable.
Use the `personal-beads` skill for tracker discovery and
local/shared publication boundaries. With no tracker for the
project, keep the mandate and handoff in this thread and say so.

## 3. Delegate small, linked, and bounded

- Use `delegate_task` for subtasks when T3 Code provides it;
  otherwise use your own subagent tool. Top-level threads only for
  work Jamie will drive himself as its own deliverable.
- Every brief is self-contained: goal, scope, done condition, and
  return format — 3-line summary, the one decision needed, PR link.
- Never exceed the WIP ceiling. Prefer fewer, larger delegates
  over many small ones when their change surfaces overlap.

## 4. While work runs

Do not poll. Delegate completions, PR watches, and questions wake
you. When a delegate finishes, reconcile before spawning more:
what landed, what it changes about the remaining plan, and capture
any discovery worth keeping as a Bead linked to this initiative —
or explicitly drop it. At merge-ready, apply `jamie-merge-gate`
to every PR under your merge authority; never merge around it.

## 5. Adopting work already in flight

This skill may be loaded into a thread that is already working.
Do not restart it. First inventory what exists: delegates and
top-level threads already spawned, open PRs, and the initiative
Bead. Record them in the Bead with their links. Existing top-level
threads cannot be retro-linked as children; track them as external
deliverables by PR link and let them finish under their own
lifecycle. The mandate applies from adoption onward.

## 6. Close from evidence

The outcome is done when the done condition holds, not when the
delegates stop. Verify PRs merged, checks passed, follow-ups
captured. Then write the handoff to the Bead: outcome, evidence,
PR links, exact next action if any. Settle this thread.

## Boundaries

- Beads is a local store, not a queue: capture there by default,
  promote to GitHub only when others need to see or decide.
- No authority beyond the mandate. A consequential choice outside
  it goes to Jamie as one grouped question, with a recommendation.

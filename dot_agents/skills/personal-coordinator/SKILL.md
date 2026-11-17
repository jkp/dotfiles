---
name: personal-coordinator
description: Coordinate an outcome across delegated threads in T3 Code, keeping a recoverable initiative record in an available store or the coordinator thread. Use when Jamie asks to coordinate, orchestrate, or work through a multi-part outcome, or when a thread is set up or adopted as a coordinator.
---

# Personal coordinator

You are the coordinator for one outcome. You delegate the work;
you do not do it yourself, and you do not become a megathread.

## 1. Mandate first

Read any existing initiative record before stating its mandate in
your first reply; establish a new mandate only for a new outcome.

- the outcome and its done condition, in one sentence
- your authority: what you may merge, spend, or decide without
  asking. When it includes merging, load the `jamie-merge-gate`
  skill now, before delegating: its charter governs every PR this
  coordinator produces.
- the WIP ceiling: how many delegates may run at once
- the stop condition: when you report back instead of continuing
- the model policy: default delegates and gate reviewers to Opus.
  Your own model is for you, for an investigation where the problem
  is not yet understood, and for a slice that has failed twice.
  Set the model explicitly on every delegation; never accidentally
  inherit the coordinator's model.

Delegation inside this mandate is pre-authorised; never ask
per delegate. Ask Jamie only when a missing or exceeded element
would change what you do next — one grouped question, with a
recommendation, while unaffected work continues. Where the
outcome was already given, infer the rest conservatively and
state what you inferred.

Jamie is not watching the thread. Anything that wants his eyes
goes through the question tool, self-contained, recommendation
first: a decision only he can make, something to try on
production, a draft to approve, or a completed outcome to acknowledge.
Ask for the actual decision or acknowledgement; plain prose does
not create T3's awaiting-input state. Progress stays in plain messages.

## 2. Establish the initiative record before you delegate

Keep one authoritative initiative record. Reuse this outcome's
existing accessible record; otherwise use an available private
store or this coordinator thread. State its location at startup.
Beads is an optional home, not a prerequisite. Do not install,
initialise, synchronise, or publish to a store just to use this skill.

The record holds the mandate, decisions, work and delegate states,
failed attempts, discoveries and follow-ups, evidence and deliverable
links, delegation log location, blockers, and exact next actions.
Keep meaningful checkpoints there so another coordinator can resume
without reconstructing the transcript. Linked records can hold detail;
do not maintain competing progress ledgers.

The coordinator owns updates to shared coordination records, the
delegation log, and brief templates. Delegates return evidence and
proposed updates through their reports; they do not concurrently
edit those shared records or add bookkeeping edits to every slice's
PR. One authoritative record does not require one file everyone writes.

Read the record, related work, comments, and linked PRs before
spawning anything. When using Beads, follow `personal-beads` for
verified tracker routing and store-specific operations. Otherwise
maintain the same information in the chosen home. Store choice
does not grant shared publication or external communication authority.

On a machine or coordinator change, verify access to the current
record and required linked evidence; paths and local databases are
not proof of availability elsewhere. If inaccessible, obtain an
explicit handoff containing the record's current state and necessary
evidence before resuming dependent work. State the new authoritative
home if it changes and retain provenance; do not silently start a
second initiative. Refresh live delegate and PR state before dispatch
to avoid duplicate work. Preserve a thread used as the record when
settling it; the thread is disposable only when its handoff is
recoverable elsewhere.

## 3. Delegate small, linked, and bounded

- Follow the environment's tool routing for the explicitly chosen model.
  Use `delegate_task` for a different model or provider, requested
  settings, or a separate checkout; use native agents when routing
  requires them and they support the chosen model and settings.
  If unavailable, report the limitation. Top-level threads only for work Jamie
  explicitly asks to drive himself as its own deliverable.
- Every brief is self-contained: goal, scope, done condition, and
  return format — 3-line summary, any decision needed, and the
  agreed deliverable: PR link, audit findings, or research evidence.
- Give each delegate a separate brief file built from the initiative's
  template, kept in or linked from the record; fold recurring review
  lessons into that template.
- State the environment as it is, checked now: what is running,
  what the delegate cannot do (attach images, reach a backend).
  A brief that is wrong about this costs every delegate a detour.
- Size a delegate by what one reviewer can hold: a family of
  parts, a screen, or a single flow. Review cost grows faster than
  size, and a large delegate fails late. If the reviewer's list of
  things to check would exceed a dozen items, it is too big.
- Split by seam, never by line count. Work that changes the same
  lines for the same reason stays in one delegate. Stage large flows
  into reviewable pieces, such as reads before writes. Start dependent
  work only when prerequisites are verified and available through a
  merged PR, named revision, or research deliverable as the mandate requires.
- Never exceed the WIP ceiling. Before parallelising, assess the
  complete write footprint, including test setup, routes, configuration,
  generated files, and bookkeeping. Name each slice's ownership and
  overlaps in its brief; assign shared edits one owner or sequence them.
- Put "search before writing a helper; extract on second use" in
  every brief, have the reviewer check for copies, and run a
  consolidation sweep when follow-ups name the same shape twice.
- When the work raises questions for someone outside the build,
  ask each delegate to end its report with them in plain words.

## 4. While work runs

A slice is one bounded unit of work; a delegate is one launch
against it. A failed attempt is a launch cancelled, abandoned, or
replaced without its agreed deliverable. Prompting the same delegate
again does not start another attempt; infrastructure or access blocks
do not count as failed delivery attempts. Group launches by slice in the record.

Delegate completions, PR watches, and questions are the normal
wake mechanism. Keep one fail-safe timer of about twenty minutes
whenever delegates are out: provider recovery and completion wakes
do not establish that stalled work always resumes. The timer is a
recovery safeguard, not a progress reporting loop. If environment
instructions prohibit it, report that the safeguard cannot be
armed and that unattended stall recovery remains uncovered; do not
silently remove it or claim completion wakes are equivalent.

On each permitted recovery wake, check each delegate's state, its
PR head and checks where relevant, and whether anything changed.
Prompt or restart one that finished without its agreed deliverable,
ended on a promise, or made no progress across two checks. Research
and audit results need no PR unless the brief requires one. Cancel
a still-running delegate before replacing it. If several stall
together, check the machine before the delegates.

Track failed delivery attempts against the slice; a new delegate or model does not reset
the history. After two failed attempts, use the coordinator's model
for one bounded recovery delegation with an explicit stop condition.
If that fails, or progress requires authority or a decision outside
the mandate, park the slice and escalate once with evidence, what
was tried, and the decision needed. Continue unaffected work.
An infrastructure or access block needs its cause resolved, not
repeated delegate replacement. Gate rework is a separate budget
owned by `jamie-merge-gate`; model changes, replacement delegates,
or replacement PRs for the same work must not bypass its verdict
or exhausted limits.

- End every rework message with the condition for stopping, such
  as "do not end your turn until the submit reports submitted".
- A completion report often arrives after its PR was reviewed or
  merged. Answer it in a line; do not act on it twice.
- Each merge can put the other open PRs in conflict. Re-run
  `jamie-merge-gate` on a rebased PR's new head; the gate owns
  the shortened rebase review.
  Repeated conflicts in the same files trigger replanning of
  ownership, sequencing, or concurrency before another rebase;
  account for the repeated CI and review cost, not just resolution time.
- After a deploy, look at the result yourself, and say plainly
  what has only been seen on mocked data.
- Keep turns short; read the relevant sections rather than repeatedly
  loading large files in full.

When a delegate finishes, reconcile before spawning more:
what landed, what it changes about the remaining plan, and capture
any discovery worth keeping in the initiative record or a linked
follow-up — or explicitly drop it. At merge-ready, apply `jamie-merge-gate`
to every PR under your merge authority; never merge around it.
When a delegate's PR merges or is dropped, or its non-PR deliverable
is accepted or dropped, the delegate is replaced, or its slice is
parked, add its row to the delegation log (below); in any case,
record every launch before closing. Update the same row for later outcomes.
Write it then, from the reports in front of you; it cannot be
rebuilt once the thread is gone.

## 5. Adopting work already in flight

This skill may be loaded into a thread that is already working.
Do not restart it. First inventory what exists: delegates and
top-level threads already spawned, open PRs, and the initiative
record, if any. Establish its home under section 2 and record the
inventory with its links there. Existing top-level
threads cannot be retro-linked as children; track them as external
deliverables by PR link and let them finish under their own
lifecycle. The mandate applies from adoption onward.

## 6. Close from evidence

Verify the agreed done condition; delegates stopping is not proof.
Require merged PRs only when merging is part of the mandate and
within your authority.

Assign a bounded verification task within the mandate to check the
combined deliverables against the initiative's acceptance criteria.
For implementation work, exercise the integrated flow and the seams
between delegates' changes on the intended combined revision.
Individual PR checks alone do not prove the combined outcome.
For research or audits, reconcile the findings into one answer to
the agreed question. Record the evidence and any acceptance still
blocked by unavailable environments or human decisions; do not
claim those conditions met.

Read this outcome's delegation log rows beside earlier ones. If they
bear on a rule in this skill, draft the claim, supporting and contrary
rows, and proposed change. State how many rows support it; task and
model differences limit conclusions. Include the draft in a grouped
question to Jamie; edit the skill only on his approval.

Update the initiative record (section 2) with acceptance evidence,
anything unmet and why, and the handoff. Present the outcome and evidence.
When Jamie needs to review or acknowledge completion, use the
question tool to ask for that acknowledgement and leave the thread
awaiting input. Settle after acknowledgement and any required
acceptance, provided no further work was requested. If neither
acknowledgement nor a decision is needed, report completion and
allow automatic settling. Never explicitly settle while an input
request is pending: explicit settlement can bypass T3's protection
against automatic settling of threads awaiting input.

## Delegation log

One row per delegate launch, grouped by slice, so section 3 can be checked
against more than one remembered run. Keep the log in the initiative
record or link to an existing accessible private project log from
there. Reuse earlier rows rather than starting a competing log.
An existing Beads-adjacent or machine-local log can stay where it is;
include relevant rows in a handoff when the destination cannot read it.

Create a log table whose header row is the Column entries below,
in order. Never keep it in the skill directory or publish it to a
shared repository without authority.

| Column | Value |
| --- | --- |
| Date, outcome | the day and the outcome's name or record reference |
| Delegate, PR | slice reference, delegate title, and PR link or "none" |
| Kind | parts, screen, flow, backend, audit, fix |
| Writes | whether it changes stored data, and staged or whole |
| Model, effort | as launched |
| Size | files changed, lines added and removed, new files |
| Rounds | local review rounds, gate rework rounds, final verdict |
| Findings | count by kind: PR text or claims, real bug, missing test, scope, duplication |
| Rebases | how many another merge forced |
| Stalls | ended on a promise, blocked by the machine, hit a limit; and how it was noticed |
| Cost | tokens and wall time for the delegate and its reviews, where known |
| Note | one line: what a different brief or size would have changed |

## Boundaries

- This skill owns the coordination mandate, initiative record,
  and delegate lifecycle. When Beads is used, `personal-beads` owns
  its discovery, routing, and store-specific workflow;
  `jamie-merge-gate` owns merge review, rework limits, and verdicts.
  Follow those canonical skills where applicable rather than
  maintaining competing policy here. Required personal or repository
  tracking workflows still apply; store independence does not waive them.
- A message to someone outside the team is a draft for Jamie.
  Write it for a reader who has not seen the build: one question
  each, no internal terms. Read what was already sent first, and
  hold back anything they can see for themselves in the result.
- Never `cd` into another repository from the session; use
  absolute paths. A stuck working directory can block every tool.
- Bounded, reversible local prerequisite repairs are in scope
  within the mandate. Verify the cause, preserve unrelated work,
  and repeat affected checks; report what changed. A repair being
  local does not authorise destructive changes, new access or
  spending, or changes affecting other work, shared credentials,
  configuration, or services. Escalate those unless the mandate
  explicitly covers them; follow configuration management policy
  where it applies.

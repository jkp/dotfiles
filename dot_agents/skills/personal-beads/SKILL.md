---
name: personal-beads
description: Manage Jamie's personal local-first work queue across projects. Use when starting or resuming project work, capturing discoveries or follow-ups, choosing next work, reconciling GitHub issues, or handing off between agents. Discover the project's tracker before writing; do not initialise Beads automatically.
---

# Personal Beads workflow

Capture locally by default. Publish when others need to know, decide, own or act.
Keep existing shared commitments accurate without requiring teammates to use Beads.

## Scope and authority

This skill is Jamie's personal workflow, not team policy. Keep its implementation
outside tracked team repositories. Read the repository's applicable
`AGENTS.md` and task-specific skills when doing repository work.

This workflow does not override repository requirements. If a required workflow
conflicts with local-only capture or Beads-owned execution state, identify the
specific conflict and ask Jamie before proceeding. Do not silently skip a
required claim, plan or review, or create a second progress ledger to satisfy both.

Questions and status requests remain read-only. Using this skill does not authorise
implementation, GitHub publication, dispatch, installation or merging. Within an
authorised work session, maintain the relevant local beads and handoff notes.

A reviewer subprocess does not own project tracking. Reading this skill because a
repository requires it does not authorise tracker discovery or any `bd` command.
Unless its initial prompt explicitly assigns tracker work, the reviewer must not read
or mutate Beads; it returns findings only through its assigned review result.

For an explicitly authorised end-to-end delivery, handle bounded, low-risk
prerequisite repairs needed to ship without asking Jamie to decide each one.
Verify the cause, keep the repair minimal, record the scope adjustment, and repeat
the affected verification. Missing input declarations are one example, not a
general licence to redesign the build graph. Escalate meaningful design or scope
expansion, new access or spending, destructive unrelated actions, or conflicting
repository requirements. Agent-written task boundaries should not manufacture
human approval requirements for these routine repairs.

## Durable homes

| Record | Authority |
| --- | --- |
| This skill | Agreed personal workflow and decision rules |
| Beads | Local work graph, evidence, execution state and handoffs |
| GitHub | Team-visible scope, acceptance, ownership, blockers and completion |
| Repository specifications | Lasting design and implementation contracts |
| Tutorial and cluster HTML | Human-facing explanations and dated views, not live task status |

## Project discovery

Identify the repository and its linked worktrees before selecting a database.
Resolve a worktree to its main checkout (`git worktree list --porcelain`, first
entry). A personal tracker lives beside that checkout as `<checkout-name>-beads`;
when that directory has a `TRACKER.md`, read it for the repository identity,
example commands and readiness rules. Otherwise inspect the project's declared
tracker; use `bd where` if Beads is installed. An inherited `BEADS_DIR` or a nearby
database is not proof that the database belongs to this project.

Confirm project ownership and the resolved database before mutation. Use explicit
`bd -C <verified-tracker-workspace>` routing for all subsequent commands. Never
send one project's work to another project's database or use one undifferentiated
global database merely because the skill is global.

If no mapping exists, continue the requested work under its repository workflow.
When durable capture is needed, ask Jamie whether to set up a private tracker;
do not initialise Beads, import issues or install hooks without authorisation.
Keep immediate steps in the current checklist and surface uncaptured follow-ups
in the handoff. After authorised setup, create the tracker as the sibling
`<checkout-name>-beads` workspace and record its mapping in that workspace's
`TRACKER.md`: repository identity, example commands and readiness rules. Keep
project specifics out of this skill.

Run embedded-Dolt commands serially.
Use explicit issue IDs for every mutation; inspect installed CLI help for syntax.

Read live beads for priorities instead of copying dated recommendations here.

## Capture and promotion

- A step within the current task stays in the agent's transient checklist.
- A discovery or follow-up worth retaining becomes a local bead. Record the
  observation, evidence, uncertainty, originating task and useful next action.
- Join every new bead to its originating outcome or workstream with the closest
  truthful parent or related relationship. Record whether it is merely captured,
  needs shaping, is a candidate inside an authorized pool, or is explicitly ready.
  An isolated bead with only a label or transcript reference is not reconciled work.
- Work completed within the authorised scope may need only its PR, not another issue.
- Promote a bead when the team needs visibility, a decision, ownership or coordination.
  Size alone does not decide publication. A consequential defect must not disappear
  into a private queue; flag the need for shared visibility promptly.

Search existing beads and GitHub records before duplicating work. Discovery tools,
including Stringer, produce candidates for triage, not automatic GitHub tickets.
Separate suspicions from reproduced defects. Use blocking dependencies only when
one task genuinely cannot proceed; recommendations and relatedness are not blockers.

Before promotion, establish scope, evidence and acceptance, then check publication
authority. If not authorised, propose the GitHub update and retain it locally as
pending publication. After publication, link the verified GitHub URL on the same
bead rather than creating a second local execution record.

## Working with existing GitHub issues

Refresh the issue, comments and related PRs before starting its linked bead.
Imported labels and descriptions are snapshots, not current approval or proof.
Use the project's reviewed readiness criteria alongside live source evidence.
Neither graph readiness nor an imported `agent-ready` label authorises implementation.

Preserve source provenance and local notes when reconciling records. Do not rerun
the one-time migration or dated audit application as a synchroniser. Read existing
metadata before merging changes; use JSON objects with `--metadata` for structured
values, not string-valued `--set-metadata` replacements.

Publish meaningful milestones within the authorised scope: changed acceptance,
ownership, an important blocker, a PR or verified completion. Keep investigation
chatter local. Record the published URL, verification time and any pending update
on the bead; inspect GitHub before retrying an uncertain write.

Finishing a local subtask does not close its GitHub parent. Reconcile duplicates
against their surviving issue. Close shared work only when its acceptance is met
and closure is authorised, not because a local queue is more convenient.

## Session recovery and handoff

At pickup, read the bead and its comments, verify external state, and identify one
bounded next action. Claim only work the user has authorised and check existing
ownership before doing so.

At a meaningful checkpoint or before handing off, append a concise bead note with:

- Agent provider and verified task/session ID or link; never invent a deep link.
- Checkout, branch and PR when relevant.
- Outcome, evidence and checks actually run.
- Remaining work, blockers and the exact next action.
- GitHub updates published or still pending.

Keep multiple session references when work crosses agents. Put the bead ID in the
handoff message so navigation works in both directions. A transcript link supports
the summary; the next agent must not need the whole transcript to resume.

## Integration and evolution

Native Beads skills and lifecycle hooks supply context; this skill supplies the
personal pilot boundary. Do not assume hooks capture handoffs or maintain GitHub.
Inspect installation with `bd setup codex --check` and `bd setup claude --check`
in the relevant checkout, and their `--global` variants, before describing it as active.

Installation is a separate scoped task. Keep it personal, workspace-gated and
untracked, preserve existing hooks, and verify database routing from worktrees.
Test startup, resume and compaction in the actual apps. Do not blindly run setup
commands that rewrite tracked instructions or enable duplicate hooks.

Remote sync and backup require an explicitly chosen private destination. Inspect
configured remotes before any push; local files alone are not off-machine recovery.

When Jamie agrees a process change, update this canonical skill rather than
accumulating rules in conversations. Keep work still to implement in Beads, not
in a skill TODO list. Update tutorial explanations when their workflow changes;
do not turn the tutorial into a competing execution ledger. Report what is
configured and what remains proposed separately.

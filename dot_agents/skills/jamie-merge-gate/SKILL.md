---
name: jamie-merge-gate
description: Jamie's personal auto-merge gate, invoked by a coordinating or reviewing agent whenever a PR under Jamie's merge authority reaches merge-ready, before any auto-merge is armed or merge is performed.
---

# Jamie Merge Gate

Jamie does not invoke this gate per PR. If he has to ask, the setup has
failed. Coordinators and reviewer delegates invoke it automatically.

Load this skill when any of these is true:

- You are setting up or acting as a coordinating thread that holds merge
  authority for its delegates' PRs. Load it at setup, before delegating,
  so the charter below governs every PR the coordinator produces.
- A PR created under Jamie's merge authority reaches merge-ready:
  review approved, required checks green, merge gate passed. Load it
  before arming auto-merge, before calling any merge tool, and before
  reporting the PR as "left unmerged for Jamie's review".
- You are the independent reviewer delegate for such a PR.
- Jamie catches something in a PR that existing review missed. Load it
  then for the learning-capture step only (see Self-improvement).

Jamie invokes it directly only in two cases: designing or amending the
merge charter for an initiative, and approving a drafted rule change.

This is Jamie's personal gate. It is not team policy, must not be copied
into a tracked team repository, and must not change team review
requirements.

## Coordinator setup

When Jamie starts a coordinating thread, paste (or point the agent at)
this charter clause. This clause, plus this skill, is the whole setup:

> Merge authority: you hold it for PRs this coordinator creates.
> Apply the jamie-merge-gate skill to every such PR when it reaches
> merge-ready. PASS arms auto-merge on the reviewed head without
> asking me. REWORK returns to the implementing delegate (max two
> rounds). ESCALATE posts one merge packet and parks; never re-ask.
> Tier: high never auto-merges. I process escalations in batches.

A coordinator set up this way must, for each delegate PR:

1. Track the PR from creation (linked to the delegate thread).
2. At merge-ready, spawn or act as an independent gate reviewer
   (never the implementing agent) and run this gate.
3. Act on the verdict itself. "Merge-ready, left for your review"
   is a charter violation for PASS-tier work, not a handoff.

## Starting point: the PR's own Risk profile

Use the repository's review-workflow report when one is provided. Read the
latest one for the PR's current head before applying the gate. It contains:

- `Risk profile` Tier: low, medium, or high
- Worst credible failure
- Detection / recovery
- Verification budget
- Scope-growth trigger
- Verdict (approve / findings) and the exact reviewed head SHA

Get it from the PR's review comments (the `github-actions[bot]`
claude-review-summary / review-workflow report), not from the PR body.
If that workflow exists but its assessment is missing, stale or failing,
do not substitute another assessment: obtain the required current evidence
or ESCALATE with reason "no current risk assessment".

**Local-evidence repos.** A repository that defines a `gate-evidence` mise
task reviews and verifies locally instead of on GitHub. There, run
`mise run gate-evidence -- <pr>` from a checkout of that repository: it
checks the PR's exact current head for an approving local review, a
clean-checkout build + test pass, and the Risk profile tier from the PR
body (the rest of the profile is in the body too). Its output replaces the
review comment and the required checks above; any MISSING or INVALID line is
a missing input. Such a repository may have no branch protection or
auto-merge: on PASS, merge with `gh pr merge <pr> --squash
--match-head-commit <reviewed head>` instead of arming auto-merge.

**Repositories without either assessment mechanism.** First verify that the
repository has neither a review-workflow Risk profile nor a `gate-evidence`
task. An independent reviewer (never the implementing agent) may then produce
the full Risk profile above and a review verdict against the exact current
head. Record the reviewer identity, head SHA, evidence, limitations and all
profile fields durably in the private per-repository gate log (see Sampling
in GATE.md), and reference that record from the gate result. The same independent
reviewer may assess risk and apply the gate. An author's assessment, green CI
alone or a bare "no findings" verdict is insufficient.

This fallback changes only the source of the assessment. It must not bypass
repository-required reviews or checks, lower an existing tier, waive findings,
or relax the never-auto classes. A changed head needs a current assessment.
If the reviewer cannot establish the required evidence, ESCALATE. On PASS,
use the repository's merge mechanism; if auto-merge is unavailable, merge
directly with an exact-head guard as above.

This gate consumes that assessment. It may upgrade risk, add rules, or
block auto-merge. It must never downgrade a tier, waive a finding, or
override a repo requirement.

## Flow

Follow [GATE.md](GATE.md) for the full procedure. In short:

1. Confirm exact head, required checks, review verdict, and Risk profile.
2. Apply every rule in [rules.md](rules.md), with evidence from the diff.
3. Return exactly one verdict:
   - PASS: arm auto-merge on the reviewed head.
   - REWORK: send fixable rule failures back to the implementing agent
     with the rule's rework pattern. Maximum two rework rounds, each
     re-running this gate on the new head.
   - ESCALATE: stop and give Jamie a merge packet. Never re-ask in
     later turns; park it.
4. If the PR is a sampled spot check, audit the gate's own answers
   (see Sampling in GATE.md) instead of re-reviewing the whole diff.

The reviewer applying this gate must not be the agent that implemented
the change. If you implemented it, delegate the gate review.

## Self-improvement

When Jamie catches something this gate missed — in an escalated PR, a
spot check, or after merge — do not just fix the PR. Also draft the rule
change using the capture format at the end of [rules.md](rules.md):
new rule or tightened wording, Jamie's example, and why the gate missed
it (no rule / rule answered dishonestly / wrong files in scope).
Show Jamie the draft; append it to rules.md only on his approval.

## Hard boundaries

- Never arm auto-merge on a head that differs from the reviewed head.
- Never auto-merge Tier: high. High always escalates.
- Never merge to satisfy a schedule, a goal continuation, or a request
  to "keep going". Missing approval is a parked state, not a prompt
  to ask again.
- Do not post this gate's verdict to GitHub as team review, and do not
  present it as team approval. It is Jamie's personal automation.

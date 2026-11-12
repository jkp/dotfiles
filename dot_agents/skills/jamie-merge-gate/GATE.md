# Gate procedure

Companion to [SKILL.md](SKILL.md). This file changes rarely.
The growing judgement lives in [rules.md](rules.md).

## 0. Trigger

Run this procedure automatically when a PR under Jamie's merge
authority reaches merge-ready (review approved, required checks
green, merge gate passed). The coordinator or its independent
reviewer delegate runs it; Jamie does not request it per PR.
Running it is a precondition for arming auto-merge, calling a merge
tool, or reporting a PR ready. Skipping it and leaving a PR
"unmerged for Jamie's review" is only correct when the verdict
below is ESCALATE.

## 1. Gather inputs

For the target PR, collect:

- Current head SHA and base SHA.
- Required check status for that exact head.
- Latest review-workflow report for that head: verdict, findings,
  and the full Risk profile (Tier, Worst credible failure,
  Detection / recovery, Verification budget, Scope-growth trigger).
- The PR brief / linked task scope, so scope growth can be judged.
- Any linked PR stack position; judge one layer at a time.

If any input is stale (report head != PR head, checks pending on the
reviewed head, findings unresolved), the verdict is ESCALATE with the
missing input named. Never guess.

## 2. Tier floor (from the Risk profile)

| Risk profile Tier | Gate floor |
| --- | --- |
| low | Eligible for PASS if all rules pass |
| medium | Eligible for PASS only if all rules pass and no rule needed rework on this head |
| high | ESCALATE always; prepare a merge packet |

Jamie's rules may raise a PR above its floor. They may never lower it.

## 3. Apply the rules

Run every rule in rules.md against the diff and the PR description.
For each rule record: pass, fail, or not-applicable, plus one line of
evidence (file/hunk or PR text). "Pass" without evidence is a fail.

Also check the Risk profile against reality:

- Does the diff stay inside the Verification budget claimed?
- Has a Scope-growth trigger been hit without the profile changing?
- Is Detection / recovery still true for what actually changed?

A stale or understated Risk profile is itself a REWORK (regenerate
the assessment) or ESCALATE if the tier would rise to high.

## 4. Verdicts

### PASS

All rules pass on the reviewed head, tier floor allows it, checks are
green, no unresolved findings. Arm auto-merge for that exact head
using the repo's normal mechanism. Then stop watching/asking: report
the PR, head SHA, tier, and any sampling selection (section 6), and
let the host merge when its requirements are met.

### REWORK

One or more rules fail in a way the rule's rework pattern can fix
without a product trade-off. Send the implementing agent: the failed
rules, the evidence, and the rework patterns. Do not send Jamie.

- Maximum two REWORK rounds per PR.
- Each new head re-runs sections 1–3 in full; a fix that changes the
  head invalidates the previous review and Risk profile.
- If the same rule fails twice, or the rework needs a trade-off the
  pattern does not cover, the verdict becomes ESCALATE.

### ESCALATE

Tier high, rework exhausted, a never-auto class (see rules.md), or a
genuine trade-off. Produce one merge packet and park it:

- PR link and exact head SHA
- Risk profile Tier and Worst credible failure
- Gate result per failed/flagged rule, with evidence
- What rework was tried, if any
- The single decision Jamie needs to make, in one sentence
- Rollback / revert path

Post the packet once, then stop. Do not repeat the ask in goal
continuations, scheduled wakes, or later turns.

## 5. Learning capture

When Jamie corrects a PR, catches an escape in a spot check, or finds
a problem after merge:

1. Classify the miss: no rule existed / rule existed but its answer
   was wrong / gate looked at the wrong scope / Risk profile wrong.
2. Draft the rules.md change in the capture format at the end of
   rules.md, describing Jamie's example without naming the repository
   or PR (rules.md is published).
3. Show Jamie the draft. Append only after his approval.
4. Record the escape, with the PR link, in the repository's sampling
   log (section 6), whether or not a new rule results.

Fixing the single PR without drafting the rule is a half-finished job.

## 6. Sampling (spot checks)

Purpose: audit the gate's honesty, not re-review every PR.

- Among PASS verdicts, select every 5th PR for post-merge audit
  until 20 consecutive PASS audits are clean; then every 10th;
  then every 15th. Any escape resets the count to 0 (back to 1 in 5).
- Always sample (in addition to the count) when a PASS is unusually
  large, introduces many new files, or touches a class named in a
  rule learned in the last 30 days.
- Sampled PRs merge normally. The audit task surfaces afterwards:
  Jamie gets the PR, the gate's per-rule answers, and the Risk
  profile. He checks the answers; he opens the diff only where an
  answer looks wrong.
- An audit that finds nothing still gets one line in the sampling
  log. An audit that finds something triggers section 5.

Each repository has its own sampling log, so counters and escapes never
cross repositories. Find it from the repository's main checkout
(first entry of `git worktree list --porcelain`):

1. `<checkout-name>-beads/merge-gate-log.md` beside the main checkout,
   when that private tracker workspace exists.
2. Otherwise `~/.local/state/jamie-merge-gate/<owner>-<repo>.md`.

Create the log on first use with the counter lines (PASS verdicts since
last sample, PASS audits since last escape, current sampling rate, last
escape) and the audit table. Never keep sampling state in the skill
directory: it is published and shared across machines.

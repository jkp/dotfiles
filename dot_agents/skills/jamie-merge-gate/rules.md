# Jamie's merge-gate rules

Growing judgement for the personal gate in [SKILL.md](SKILL.md).
The gate in [GATE.md](GATE.md) applies every rule here on every PR.
This file is Jamie's, not team policy. Edit only through the capture
process at the bottom.

## Never-auto classes

Regardless of tier or rule answers, these always ESCALATE:

- Secrets, auth, or credential handling changes, including anywhere
  resolved secrets are persisted, cached, or distributed more widely
- Irreversible data changes, destructive deletion, or workspace /
  file removal whose recovery is "restore from backup"
- Public API or contract changes consumed outside the repo
- Production configuration or rollout changes

## Rules

### R1: No unnecessary coupling

- **Question:** Does this change make two things depend on each other
  that did not before, and is that dependency necessary for the stated
  goal rather than merely convenient for this diff?
- **Fail signal:** A component now requires, imports, configures, or
  is lifecycle-bound to another as a side effect of an unrelated
  improvement; removing the second would break the first for no
  product reason.
- **Rework pattern:** Keep the improvement, drop the coupling. Use
  the existing seam/interface; if none exists, pass the needed value
  or event across the boundary instead of binding lifecycles. If the
  coupling is the point of the PR, say so in the PR description and
  name what it buys.
- **Escalate when:** Decoupling requires duplicating real behaviour
  or accepting a performance cost, and the trade-off is genuine.
- **Learned:** 2026-11-05 (Thu), Jamie spot check: a change improved
  a data split but coupled two previously independent things.

### R2: No obligatory migration by default

- **Question:** Does landing this force a migration, rewrite, or
  manual step on existing users, developers, worktrees, or data —
  and could it be opt-in, dual-path, or backward-compatible instead?
- **Fail signal:** Existing setups break, stop working, or must be
  converted before they work again; the PR treats the migration as
  a footnote rather than a cost imposed on people who did not ask.
- **Rework pattern:** Preserve the old path working; add the new
  path alongside; migrate lazily or on explicit opt-in. State in
  the PR when the old path can be removed and what triggers removal.
- **Escalate when:** Obligatory migration is genuinely required
  (for example the old path is unsafe). The packet must name who
  pays, how many, and why the compatible route was rejected.
- **Learned:** 2026-11-05 (Thu), Jamie spot check: an improvement
  made a migration obligatory for all existing worktrees and
  developers when it did not need to be.

### R3: Blast radius stays inside the brief

- **Question:** Is everything this changes inside the scope the brief
  or task authorised, including files, services, and behaviours that
  are only touched as side effects?
- **Fail signal:** The diff edits unrelated areas, reformats or
  refactors beyond the stated change, or the Risk profile's
  Scope-growth trigger has been hit without acknowledgement.
- **Rework pattern:** Split it. Land the authorised change; move the
  extra work to its own PR with its own Risk profile.
- **Escalate when:** The out-of-scope part is load-bearing for the
  in-scope part and cannot be separated without rework.
- **Learned:** Seeded from Jamie's existing practice: scope-growth
  triggers already named in PR Risk profiles must bind, not decorate.

### R4: No new persistence of secrets or resolved values

- **Question:** Does this write secrets, tokens, or values resolved
  from a secret store to disk, logs, caches, or another location
  where they outlive the process that needed them?
- **Fail signal:** Plaintext caches with no expiry, resolved values
  copied between worktrees, secrets appearing in generated files
  or command arguments. A 0600 file mode is not encryption and is
  not a justification.
- **Rework pattern:** Resolve at process start, hold in memory or
  process environment only, do not retain between launches. If a
  cache already exists in the touched code, do not extend its reach.
- **Escalate when:** Always. This is also a never-auto class;
  revocation limits must be stated: revoking access stops future
  retrieval, it does not invalidate values already handed out.
- **Learned:** 2026-10-26, Jamie spot check: resolved keys were
  lying on disk in cache files, so 1Password revocation no longer
  revoked anything.

### R5: Defaults preserve current behaviour

- **Question:** Does any new setting, flag, or config change what
  happens for someone who changes nothing?
- **Fail signal:** A new option whose default alters existing
  behaviour, output, or cost for current users/developers.
- **Rework pattern:** Default to today's behaviour; make the new
  behaviour the opt-in. Name the future change and its trigger if
  the default is intended to flip later.
- **Escalate when:** Flipping the default now is the actual product
  decision being proposed; Jamie decides, with the affected
  population named in the packet.
- **Learned:** Seeded alongside R2: obligatory change wearing a
  config flag is still obligatory.

## Capture format (for new or tightened rules)

When Jamie catches something, draft an entry in exactly this shape
and show it to him before appending above:

```markdown
### R<n>: <short name>

- **Question:** <the question that would have caught it>
- **Fail signal:** <what it looks like in a diff or PR text>
- **Rework pattern:** <the fix the implementing agent tries first>
- **Escalate when:** <the genuine trade-off that needs Jamie>
- **Learned:** <YYYY-MM-DD (Day)>, <Jamie spot check / audit / post-merge>,
  <one line: what slipped through and why the gate missed it:
  no rule / wrong answer / wrong scope / risk profile understated>
```

Keep repository names, PR links and client details out of rules: this
file is published. The PR link goes in that repository's sampling log.

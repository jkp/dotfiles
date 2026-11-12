---
name: review-council
description: Get external opinions on plans or code changes from multiple AI reviewers (Codex, Gemini, Claude). Use when you want a second opinion, design critique, or multi-agent review of a plan or branch.
---

# Review Council

Get independent opinions from multiple AI agents on plans or code changes.

## Invocation

```
/review-council                           # interactive — finds plan, asks questions
/review-council path/to/plan.md           # explicit plan file
```

## Interactive Setup

Use the `AskUserQuestion` tool to gather configuration step by step.

### Step 1: Locate the Plan

Search for candidate plan files in this order:
1. If a path was passed as an argument, use that
2. Most recent `.md` file in `~/.claude/plans/` (by mtime)
3. Files matching `*plan*` in `docs/003-plans/` or similar project plan directories

Read the first few lines of the candidate file to extract the title (first `# heading`).

Then use `AskUserQuestion`:
- **"I found a plan: '<title>' at `<path>`. Is this what you want reviewed?"** (header: "Plan")
  - "Yes, review that"
  - "No, let me specify" — user provides a different path via Other

### Step 2: Scope and Reviewers

Use `AskUserQuestion` with up to 4 questions:

1. **"What's the scope of the review?"** (header: "Scope")
   - "Full architectural" — all five dimensions (design optimality, assumptions, semantic clarity, correctness, phasing)
   - "Technical only" — correctness, race conditions, edge cases
   - "Design only" — optimality, assumptions, legacy debt

2. **"Single concern or split across domains?"** (header: "Structure")
   - "Single" — same full prompt to all reviewers
   - "Split" — each reviewer gets a focused mandate on different dimensions

3. **"Which reviewers?"** (header: "Reviewers")
   - "All three" — Codex, Gemini, and Claude in parallel
   - "Codex (GPT)" — OpenAI Codex CLI only
   - "Gemini" — Google Gemini CLI only
   - "Claude" — Claude subagent only

### Step 3: Confirm and Go

Summarize the review matrix and use `AskUserQuestion`:
- **"Ready to launch N parallel reviews?"** (header: "Launch")
  - "Go"
  - "Adjust" — go back and tweak

## Execution: Plan Review

### How each reviewer gets the plan

For plan reviews, all three reviewers receive the plan via stdin or inline prompt — 
no git commit needed. The plan file just needs to be readable on disk.

- **Codex**: `cat <plan_file> | codex exec --sandbox read-only -o ... -`
- **Gemini**: `cat <plan_file> | gemini --approval-mode plan -p "..."`
- **Claude**: plan content included in the Agent tool prompt

For future CODE REVIEW mode, `codex review --base` will need committed changes.
That commit machinery will be added when code review mode is implemented.

### Step 1: Setup output directory

1. Create output directory: `.reviews/YYYY-MM-DDTHH-MM/`
2. Write the review prompt to `.reviews/YYYY-MM-DDTHH-MM/prompt.md`

### Step 2: Dispatch reviewers (all in parallel)

**Codex** — run as background Bash:

For PLAN REVIEWS, use `codex exec` (not `codex review`). This allows:
- Full review prompt via stdin (`-`)
- Output file via `-o`
- Read-only sandbox prevents Codex from modifying files

Do NOT use `codex review` for plan reviews — it doesn't accept a custom prompt
alongside `--commit`/`--base`/`--uncommitted`, so Codex defaults to code review
behavior and ignores the design critique framing.

```bash
mkdir -p <output_dir>/codex
cat <plan_file> | codex exec --sandbox read-only \
  -o <output_dir>/codex/review.md \
  "<review_prompt>

Focus your review on the plan. You may reference the codebase for context,
but your output should be a critique of the plan's design, not a code review.

The plan follows on stdin." \
  2>&1 | tee <output_dir>/codex/raw.txt
```

IMPORTANT: Pass the prompt as a quoted string argument, NOT via heredoc.
Heredoc (`<<'EOF'`) and pipe (`cat ... |`) conflict — bash can only read
stdin from one source. Use the pipe for the plan content and a quoted
string for the prompt. Codex auto-appends piped stdin as a `<stdin>` block.

For CODE REVIEWS (future), use `codex review --base origin/main` instead.
That mode is purpose-built for diff review. Constraints for code review mode:
- `--base`, `--commit`, `--uncommitted` are mutually exclusive with `[PROMPT]`
- `--title` IS allowed alongside these flags
- `-o` is NOT supported by `codex review`

**Gemini** — run as background Bash:
```bash
mkdir -p <output_dir>/gemini
cat <plan_file> | gemini --approval-mode plan \
  -p "<review_prompt>

The plan follows on stdin." \
  2>&1 | tee <output_dir>/gemini/raw.txt
```
Then extract the review content from raw.txt into review.md (strip status lines).

**Claude** — run as background Agent:
Prompt the agent with the review prompt + plan content. Tell it to write its review to `<output_dir>/claude/review.md`.

### Review Prompt Template

```
You are a senior systems architect reviewing an implementation plan.

<CONTEXT — brief description of what the system does>

Review this plan across these dimensions:

1. DESIGN OPTIMALITY
   - Are we stuck in a local maximum? Is there a fundamentally better approach?
   - If designing from scratch with no legacy, would you arrive at the same architecture?
   - Are we solving the right problem, or reframing it to fit a solution we already had?

2. ASSUMPTIONS & LEGACY DEBT
   - What assumptions is this plan making? List them explicitly.
   - Which are load-bearing vs inherited from a previous design?
   - Are we coding around legacy instead of questioning it?
   - Is anything a workaround for something that should just be fixed?

3. SEMANTIC CLARITY
   - Does the model make conceptual sense? Would a new engineer understand WHY?
   - Are the abstractions at the right level? Too many layers? Too few?
   - Do the names and concepts map cleanly to the domain?

4. TECHNICAL CORRECTNESS
   - Race conditions, ordering assumptions, failure modes
   - Edge cases in state machine transitions
   - Are invariants enforced or just documented?

5. PHASING & RISK
   - Does the implementation order make sense?
   - Where are the highest-risk integration points?
   - What's the blast radius if a phase goes wrong?

Be direct. If the plan is good, say so briefly and focus your energy on what could
be better. If there's a fundamental issue, lead with that. We want honest critique,
not validation.
```

For narrower scopes, use only the relevant dimensions. For custom scopes, incorporate the user's language. For split-concern mode, each reviewer gets only their assigned dimensions.

## Result Synthesis

After all reviewers complete:

1. Read each reviewer's output
2. Create `summary.md` containing:
   - **Convergent findings**: flagged by 2+ reviewers (high confidence)
   - **Unique findings**: one reviewer only (worth investigating)
   - **Per-reviewer key points**
3. Present convergent findings to the user first

## Triage: Walk Through Findings

After presenting the summary, walk through each finding one by one using `AskUserQuestion`.

For each finding, present it briefly (one-line summary + which reviewers flagged it) and ask:

- **"How do you want to handle: '<finding summary>'?"** (header: "Finding N")
  - "Accept — update the plan" — incorporate the feedback into the plan
  - "Reject — not applicable" — dismiss with a reason (user can add notes via Other)
  - "Investigate — need more info" — flag for deeper analysis before deciding
  - "Defer — revisit later" — acknowledge but don't act now

AskUserQuestion supports up to 4 questions per call, so batch up to 4 findings
at a time to keep the flow moving. Don't ask all findings in one massive batch —
group them in rounds of 3-4 so the user can focus.

After triage, write the decisions to `<output_dir>/triage.md`:
```markdown
# Triage Results

## Accepted
- Finding: <summary> — will update plan to address this

## Rejected  
- Finding: <summary> — reason: <user's note>

## Investigate
- Finding: <summary> — needs deeper analysis

## Deferred
- Finding: <summary>
```

If any findings were accepted, offer to update the plan file with the agreed changes.

## Output Structure

```
.reviews/
  YYYY-MM-DDTHH-MM/
    prompt.md
    codex/
      raw.txt
      review.md
    gemini/
      raw.txt
      review.md
    claude/
      review.md
    summary.md
```

## Notes

- All reviewers run in parallel (background Bash + background Agent)
- Plan reviews need no git commits — all reviewers receive the plan via stdin or inline prompt
- `.reviews/` is ephemeral, not version controlled
- If a reviewer hits rate limits or capacity errors, note the failure in summary.md and proceed with available results

---
name: memory-staleness
description: Find auto-memories that tell you to use a path, moon task or command the repository no longer has, then correct or retire them. Use when the user says "check my memories", "are my memories stale", "validate memory", "/memory-staleness", or when running a memory consolidation pass. Reports first; edits only after reading each finding.
---

# Memory staleness

Memory rots silently. A memory that says "run `make -C tools ci`" keeps saying
it after `make` leaves the repository, and nothing surfaces it until an agent
follows the instruction. This skill finds that class of rot mechanically, then
hands the judgement back to you.

## Run the scan

```bash
uv run ~/.agents/skills/memory-staleness/scan.py          # the project you are in
uv run ~/.agents/skills/memory-staleness/scan.py --all    # every project memory on this machine
uv run ~/.agents/skills/memory-staleness/scan.py --json   # machine-readable
```

It is read-only. It checks memories against the upstream default branch
(`origin/HEAD`) where one exists, because a checkout can sit on any branch and
memory should match what ships. The report names the ref and its commit date:
if that date is old, `git fetch` first, or the scan measures a stale main.

## What it checks, and why so narrowly

Only **instructional** memories — `feedback_` and `reference_`. A `project_` or
`incident_` memory naming a deleted path is recording what was true at the time.
That is correct, not stale. Validating a real directory by hand, this one rule
removed 165 of 214 findings, none of them wrong.

Within those, three kinds of claim in backticks:

- **Paths** rooted in a directory the repository actually has, resolved against
  tracked files including subdirectory-relative mentions. Generated directories
  (`node_modules`, `.venv`, `.review`, `dist`, …) are skipped: git not tracking
  them proves nothing.
- **Moon tasks** as `project:task`, only when `project` is a real moon project.
  `status:ready` is a GitHub label and `twopane:w-80` a CSS class.
- **Commands** that cannot run without a file in the repo: `make` needs a
  Makefile, `overmind` a Procfile, `hk` an `hk.pkl`, `just` a justfile. Asking
  whether the binary is on PATH misses `make`, which is installed nearly
  everywhere and was the single most common stale instruction found.

## Act on each finding

The scan cannot decide what to do. For each finding, open the memory and ask
whether its **lesson** survived the change that broke its **reference**.

1. **Moved, lesson intact** — correct the path. The report may offer a
   `candidate`. It is a guess, made only when exactly one tracked file shares a
   distinctive name. Confirm the candidate is the same thing before using it:
   `git log --follow` or read both.
2. **Tool replaced, lesson still true** — rewrite the instruction for the tool
   that replaced it, and name the current command.
3. **Lesson void** — the thing the memory warned about no longer exists. Retire
   the file and remove its line from `MEMORY.md`.
4. **Two memories now disagree** — a newer memory describing the replacement is
   evidence the older one is wrong. Keep the newer; fold anything unique from the
   older into it; retire the older.
5. **The old path is the point** — a memory saying "X moved from `a/b.py` to
   `c/d.py`" names a dead path on purpose. That is correct history. Leave it.
6. **The memory describes another repository** — its paths are relative to that
   tree and every one reads as gone. Add `repo: <name>` under its `metadata:`,
   and the scan skips it from then on. Without the marking it is re-reported
   every run, which is how a recurring report learns to be ignored.

Record why a memory was retired in the commit, the memory it merged into, or the
report back to the user — never silently. After editing, re-run the scan: the
finding should be gone and nothing new should appear.

## How it decides

Filters that exist because a real run needed them, each pinned by a test:

- **Ignore rules come from the repository, not the clone.** A path the committed
  `.gitignore` covers is runtime state and never reported. `.git/info/exclude`
  and global excludes are deliberately *not* honoured: they are local, and
  honouring them makes one memory stale on one machine and fine on another.
- **Two-segment names with no extension are checked against history.** That
  shape spells identifiers (`actions/checkout`, `tools/call`) and also real
  files (`orchestra/op-secrets`). An identifier was never a file here; a deleted
  file was. Only the second is reported.
- **Task ids need a real project.** `status:ready` is a label.

## Known limits

- **A clean result is narrower than it looks.** Only references *inside* the
  repository are checked. Home and host paths (`~/.local/share/app/app.db`,
  `/srv/data`), URLs, API routes and `op://` URIs are not — and on the first
  machine-wide run they were most of what seven of eight projects' memories
  referenced. "No findings" there means nothing repo-relative is stale, not that
  the memory is fresh.
- **References, not claims.** It catches a dead path or command, not a false
  statement. A memory asserting "ty only checks `src`" names nothing checkable
  and will not be flagged even when the configuration changed. Consolidation
  passes still need a human read.
- **Command evidence is a short table.** A tool not in it is invisible.
- **Directory names are shared across contexts.** In a repository with a real
  `roles/` directory, an IAM role like `roles/billing.admin` looks like a path.
- **Memory directories with no repository** — the home directory, scratch and
  temp dirs, deleted worktrees — are listed as skipped under `--all`.

## Tests

```bash
cd ~/.agents/skills/memory-staleness && uv run --no-project --with pytest pytest -q tests
```

Each filter is pinned by a test and was mutation-checked: removing it makes a
test fail. Keep that true when changing a filter.

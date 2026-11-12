---
name: wrap-up
description: Use when the user says "wrap up", "/wrap-up", "clean up this tree", "tear it down", or asks to bring down the running environment and remove the worktree once a session's work is finished. Recaps first and stops if anything is unfinished; otherwise stops the local stack and removes every worktree the session used.
---

# Wrap Up

Finish a session: prove the work is done, then remove what it left running and on
disk. Destructive, so the proof comes first and a doubt stops the run.

## Step 1: recap

Follow the `recap` skill's refresh (Step 1) for this session, read-only. Then decide
**done** only if all of these hold for every worktree the session used:

- Its PR is merged or deliberately closed, or it never had one and holds nothing
  worth keeping.
- `git status --short` is empty, apart from generated artefacts such as
  `test-results/`, `.playwright-mcp/` and `.review/`.
- Every commit on its branch is either in a merged PR or was pushed. Squash merges
  leave the branch looking unmerged; judge it by the PR, not by `git branch --merged`.
- No background job the session started is still doing real work. A dev stack or a
  throwaway server the session started does not count; teardown stops those.

If anything fails, report it in recap form and stop. Do not fix it as part of the
wrap-up.

## Step 2: list what goes

Every worktree the session used: the one it runs in, plus any it created
(a project worktree task, `EnterWorktree`, `git worktree add`). Confirm each one
with `git worktree list` from the main checkout. Say the list and the branches in one
line before removing anything.

## Step 3: tear down

Run everything from the main checkout (the first entry of
`git worktree list --porcelain`), never from inside a tree being removed: deleting
the tree a session stands in strands its hooks mid-run.

Use the best teardown the repository offers, in this order:

1. **Documented teardown.** Look in the repo's `AGENTS.md`, `CLAUDE.md` and
   `README` for a worktree-removal command, and confirm it exists in the task runner
   (`mise tasks`, `moon`, `just --list`, `package.json` scripts). These usually also
   stop the tree's dev stack, containers and port reservations, so prefer them.
   Follow the documented flags; pass a force flag only when the branch delete is
   refused because a squash merge left it unmerged and the PR from Step 1 is merged.
2. **Plain git.** With no documented teardown, first stop anything this session
   started in the tree (dev servers, `docker compose` projects) using the same tool
   that started it, then:

   ```bash
   git worktree remove <path>     # refuses a dirty tree: stop and report if it does
   git branch -d <branch>         # -D only when Step 1 proved the PR merged
   ```

   Never add `--force` to `git worktree remove`; Step 1 already proved the tree clean.
3. **Can't tell.** If the repo documents a stack you can't identify how to stop,
   remove nothing: print the commands you would run and say what is unknown.

Order: sibling worktrees first, then the session's own tree as the **last tool call**.
Nothing can run after it, so write the closing summary from what you already know.

## Step 4: close

One short message: what was removed, anything left running elsewhere (other
sessions' tasks), and anything that failed with its error. Suggest archiving the
session.

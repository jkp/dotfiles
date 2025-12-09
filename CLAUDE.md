# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Overview

A **chezmoi** dotfiles repository. Uses **mise** for tools/tasks and **hk** for git hooks.

## Key Commands

```bash
chezmoi apply               # Apply source → home
chezmoi re-add <file>       # Sync home → source
mise run bootstrap          # Bootstrap core environment
mise run verify             # Check what's installed
```

## Syncing Changes (Agents: Start Here)

When asked to sync/commit changes from the system to this repo:

```bash
chezmoi-check -v            # ALWAYS run this first to see full picture
```

This shows three things:
1. **Drifted files** (`MM`) - files that differ between home and source
2. **Untracked dotfiles** - configs on the system not managed by chezmoi
3. **Uncommitted changes** - changes already staged in the chezmoi repo

### Reviewing changes

Two commands for viewing diffs - use the right one for your task:

```bash
chezmoi diff --reverse <file>  # What local changes would re-add pull in? (home → source)
chezmoi diff <file>            # What would apply do? (source → home)
```

**When syncing local changes to the repo, use `--reverse`** (aliased as `cmp` for "pending"). This shows the diff in the intuitive direction: `+` lines are additions you made locally, `-` lines are things you removed.

### Workflow for syncing changes

1. `chezmoi-check -v` to see what's drifted
2. `chezmoi diff --reverse <file>` (or `cmp`) to review local changes
3. `chezmoi re-add <file>` to pull local changes into source, OR
4. `chezmoi apply <file>` to discard local and restore from source
5. Group related changes into atomic commits

## Editing Managed Files (Agents)

1. Edit the deployed file (e.g., `~/.config/fish/functions/foo.fish`)
2. Run `chezmoi re-add <file>` immediately
3. Verify with `chezmoi status`

**Why:** Editing deployed files and re-adding keeps the running system and source in sync. Editing source directly risks drift.

## Writing Documentation

Keep docs minimal and evergreen:
- No lists of configs/tools (they change)
- No explanations of things the reader already knows
- Focus on workflows, not inventory
- If it can be discovered via `mise tasks` or `chezmoi managed`, don't document it

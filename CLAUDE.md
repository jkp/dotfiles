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

## Checking for Drift

```bash
chezmoi-check               # Runs on shell startup, or invoke manually
chezmoi-check -v            # Verbose: show files
```

When drift exists:
1. `chezmoi diff <file>` to inspect
2. `chezmoi re-add <file>` to keep local, or `chezmoi apply <file>` to restore source

## Editing Managed Files (Agents)

1. Edit the deployed file (e.g., `~/.config/fish/functions/foo.fish`)
2. Run `chezmoi re-add <file>` immediately
3. Verify with `chezmoi status`

**Why:** Editing deployed files and re-adding keeps the running system and source in sync. Editing source directly risks drift.

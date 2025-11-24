# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a **chezmoi** dotfiles repository.

## Managed Configurations

- **Neovim**: `dot_config/nvim/` - kickstart.nvim-based config with lazy.nvim for plugins
- **Fish Shell**: `dot_config/private_fish/` - uses fisher for plugin management, integrates mise/zoxide/1Password

## Development Tools

This repo uses **mise** to manage tools and **hk** to manage git hooks:

- `mise.toml` - Declares tools (gitleaks, hk) and runs postinstall hook
- `hk.pkl` - Defines git hooks (pre-commit runs gitleaks)
- `bootstrap.sh` - Sets up new machines, installs mise, runs `mise install` to activate hooks

After `mise install`, the pre-commit hook automatically scans for secrets using gitleaks.

## Key Commands

```bash
chezmoi apply               # Apply changes to home directory
chezmoi edit <target>       # Edit a managed file (applies on save)
chezmoi cd                  # Enter source directory for git operations
mise install                # Install tools and setup git hooks
mise trust                  # Trust mise.toml (required once)
```

## Editing Managed Files (Agents)

**IMPORTANT:** When modifying chezmoi-managed files, use this workflow:

1. Use the Edit/Write tool to modify the source file in `~/.local/share/chezmoi/dot_*`
2. **ALWAYS** run `chezmoi apply` immediately after editing the source file
3. Verify the changes with `chezmoi status` (should show clean state)

**DON'T:** Edit files in `~/.local/share/chezmoi/dot_*` without running `chezmoi apply` - this creates a confusing state where the source is updated but the deployed file in the home directory is not.

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
chezmoi edit <target>       # Edit a managed file
chezmoi cd                  # Enter source directory for git operations
mise install                # Install tools and setup git hooks
mise trust                  # Trust mise.toml (required once)
```

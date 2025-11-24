# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a **chezmoi** dotfiles repository.

## Managed Configurations

- **Neovim**: `dot_config/nvim/` - kickstart.nvim-based config with lazy.nvim for plugins
- **Fish Shell**: `dot_config/private_fish/` - uses fisher for plugin management, integrates mise/zoxide/1Password

## Key Commands

```bash
chezmoi apply               # Apply changes to home directory
chezmoi edit <target>       # Edit a managed file
chezmoi cd                  # Enter source directory for git operations
```

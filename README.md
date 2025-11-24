# Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## Bootstrap New Machine

Run this one-liner to set up a new machine:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/jkp/dotfiles/main/bootstrap.sh)"
```

This will:
1. Install chezmoi and fish shell
2. Apply dotfiles from this repository
3. Install mise and development tools
4. Set up git hooks for secret detection

## What's Included

- **Neovim**: kickstart.nvim-based configuration
- **Fish Shell**: with fisher, mise, zoxide, and 1Password integration
- **Git Hooks**: Pre-commit secret scanning with gitleaks

## Manual Setup

If you already have chezmoi installed:

```bash
chezmoi init --apply jkp
cd ~/.local/share/chezmoi
mise trust && mise install
```

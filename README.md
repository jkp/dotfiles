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

## Development

### Testing Bootstrap

Test the bootstrap script in a fresh Docker container:

```bash
mise run test-bootstrap
```

This tests with your local uncommitted changes, ensuring the bootstrap works before you commit.

### Pre-commit Hooks

This repository uses `hk` to manage git hooks:

- **Fast hooks** (always run): gitleaks scans for secrets
- **Slow hooks** (optional): Full bootstrap test in Docker

```bash
# Normal commit - only runs gitleaks (fast)
git commit

# Run with slow tests (includes Docker bootstrap test)
hk run pre-commit --slow
# or
hk run pre-commit -s
```

## Manual Setup

If you already have chezmoi installed:

```bash
chezmoi init --apply jkp
cd ~/.local/share/chezmoi
mise trust && mise install
```

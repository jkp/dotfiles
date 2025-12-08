# Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## Bootstrap

One-liner to set up a new machine (installs mise, chezmoi, fish, and applies dotfiles):

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/jkp/dotfiles/main/bootstrap.sh)"
```

For personal machines with full tooling (adds Homebrew packages, tmux, etc):

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/jkp/dotfiles/main/bootstrap.sh)" -- --full
```

## Testing

Test bootstrap in a fresh Docker container:

```bash
mise run test
```

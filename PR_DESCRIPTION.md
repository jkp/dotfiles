# PR: Use mise tasks for bootstrap orchestration

## Summary

Refactors the bootstrap process to use mise as the orchestrator instead of hand-rolled shell scripts. Adds tiered Brewfile support for core vs personal Mac setup.

## Changes

### New files
- **Brewfile.core** - Minimal Homebrew packages safe for any Mac (fish, git, coreutils, 1password-cli)
- **Brewfile.personal** - Full personal setup (aerospace, hammerspoon, wezterm, keymapp, borders)

### Modified files
- **mise.toml** - Added bootstrap tasks: `bootstrap`, `bootstrap-full`, `verify`, `doctor`
- **bootstrap.sh** - Slimmed down to Phase 0 (get mise/chezmoi in place) then delegates to `mise run bootstrap`
- **test.sh** - Expanded verification to check all mise tools and fish functions

## New workflow

```bash
./bootstrap.sh           # Core setup (safe for any Mac)
./bootstrap.sh --full    # Full personal setup

# After bootstrap, these are available:
mise run verify          # Check system state
mise run doctor          # Diagnose issues
```

## Current status: CI FAILING

The Linux Docker test is failing. Several fixes have been attempted:
1. ✅ Fixed `neovim` → `nvim` binary name in test.sh
2. ✅ Fixed `[ != *pattern* ]` → `[[ != *pattern* ]]` for bash pattern matching
3. ✅ Removed `platforms` constraints, moved OS checks inline
4. ❌ Still failing - inlined bootstrap task to avoid depends chain issues

### Debugging notes

The failure happens when `mise run bootstrap` is called from bootstrap.sh. Possible issues:
- mise task execution context (working directory, PATH)
- The `cd ~` in mise-tools task might not work as expected
- mise itself might not be fully activated when tasks run

### To debug locally

```bash
# Run the Docker test locally
mise run test

# Or manually:
docker run --rm -it -v "$PWD:/dotfiles:ro" ubuntu:latest bash
# Then inside container:
apt-get update && apt-get install -y curl git sudo
useradd -m -s /bin/bash testuser
echo 'testuser ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
su - testuser
DOTFILES_SOURCE=/dotfiles BOOTSTRAP_TEST=1 bash /dotfiles/bootstrap.sh
```

## TODO remaining

- [ ] Fix CI failure
- [ ] Add self-hosted Linux runner option for faster CI
- [ ] Test on actual macOS machine
- [ ] Consider adding `sources`/`outputs` to mise tasks for caching once stable

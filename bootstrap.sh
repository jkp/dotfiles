#!/bin/bash
# Minimal bootstrap - gets mise in place, then delegates to mise tasks
set -e

export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
export DEBIAN_FRONTEND=noninteractive

# Pass through flags to mise run bootstrap
BOOTSTRAP_FLAGS="$@"

echo "🚀 Bootstrapping dotfiles..."
echo

# =============================================================================
# Phase 0: Prerequisites (before mise tasks are available)
# =============================================================================

# Install Homebrew (macOS only - needed for everything else)
if [[ "$(uname)" == "Darwin" ]] && ! command -v brew &>/dev/null; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
fi

# Install fish (Linux only via apt - macOS gets it from Brewfile.core)
if [[ "$(uname)" != "Darwin" ]] && ! command -v fish &>/dev/null; then
    echo "🐚 Installing fish shell..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq fish >/dev/null
fi

# Install mise
if ! command -v mise &>/dev/null; then
    echo "🔧 Installing mise..."
    curl -fsSL https://mise.run | sh
fi
# Activate mise (use explicit path in case PATH not updated yet)
eval "$("$HOME/.local/bin/mise" activate bash)"

# Install chezmoi
if ! command -v chezmoi &>/dev/null; then
    echo "📦 Installing chezmoi..."
    curl -fsLS get.chezmoi.io | BINDIR="$HOME/.local/bin" sh
fi

# 1Password CLI (macOS only): run_before_00-fetch-age-key reads the age key
# with it, and chezmoi can't decrypt the encrypted dotfiles without that key.
# With the app integration, op signin needs no terminal: it asks for approval
# in the 1Password app, and the approval covers this process tree (so chezmoi's
# run_before script too). Without the integration it prints a session export to
# eval. Without a terminal, stdin is /dev/null so a password prompt can't hang.
if [[ "$(uname)" == "Darwin" ]] && [[ ! -s "$HOME/.config/chezmoi/key.txt" ]]; then
    if ! command -v op &>/dev/null; then
        echo "🔑 Installing 1Password CLI..."
        brew install --cask 1password-cli
    fi
    if ! op whoami &>/dev/null && [[ -z "$BOOTSTRAP_TEST" ]]; then
        echo "🔑 Signing in to 1Password (needed for the age key)..."
        if [[ -t 0 ]]; then
            eval "$(op signin)"
        else
            eval "$(op signin </dev/null)"
        fi
    fi
    if ! op whoami &>/dev/null; then
        echo "❌ The 1Password CLI isn't signed in, so the age key for encrypted dotfiles can't be fetched." >&2
        echo "   Unlock 1Password and approve the sign-in prompt (it may have been declined or timed out)," >&2
        echo "   check Settings → Developer → Integrate with 1Password CLI is on, then rerun." >&2
        exit 1
    fi
fi

# Get dotfiles (needed before mise tasks are available)
echo "📂 Getting dotfiles..."
CHEZMOI_EXCLUDE=""
if [[ "$(uname)" != "Darwin" ]]; then
    CHEZMOI_EXCLUDE="--exclude=encrypted"
fi

if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
    if [ -n "$DOTFILES_SOURCE" ]; then
        chezmoi apply --source "$DOTFILES_SOURCE" $CHEZMOI_EXCLUDE
    else
        chezmoi update $CHEZMOI_EXCLUDE
    fi
elif [ -n "$DOTFILES_SOURCE" ]; then
    echo "Copying dotfiles from $DOTFILES_SOURCE..."
    mkdir -p "$HOME/.local/share"
    cp -r "$DOTFILES_SOURCE" "$HOME/.local/share/chezmoi"
    chezmoi init --apply $CHEZMOI_EXCLUDE
else
    chezmoi init --apply jkp $CHEZMOI_EXCLUDE
fi

# Trust mise configs now that dotfiles exist
"$HOME/.local/bin/mise" trust ~/.local/share/chezmoi/mise.toml 2>/dev/null || true
"$HOME/.local/bin/mise" trust ~/.config/mise/config.toml 2>/dev/null || true

# =============================================================================
# Phase 1: Mise tasks (now that dotfiles/mise.toml exists)
# =============================================================================

echo
echo "⚙️  Running mise bootstrap tasks..."
cd ~/.local/share/chezmoi
mise run bootstrap $BOOTSTRAP_FLAGS

echo

# Launch fish (skip in test mode or non-interactive)
if [[ -z "$BOOTSTRAP_TEST" ]] && [[ -t 0 ]]; then
    exec fish
fi

#!/bin/bash
# Minimal bootstrap - gets mise in place, then delegates to mise tasks
set -e

export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
export DEBIAN_FRONTEND=noninteractive

FULL_BOOTSTRAP=false
if [[ "$1" == "--full" ]]; then
    FULL_BOOTSTRAP=true
fi

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
    curl -fsSL https://mise.run | sh 2>&1 | grep -E "(installed|error)" || true
fi
eval "$(~/.local/bin/mise activate bash 2>/dev/null || mise activate bash)"

# Install chezmoi
if ! command -v chezmoi &>/dev/null; then
    echo "📦 Installing chezmoi..."
    curl -fsLS get.chezmoi.io | sh 2>&1 | grep -E "(installed|error)"
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
    chezmoi apply $CHEZMOI_EXCLUDE
else
    chezmoi init --apply jkp $CHEZMOI_EXCLUDE
fi

# =============================================================================
# Phase 1: Mise tasks (now that dotfiles/mise.toml exists)
# =============================================================================

cd ~/.local/share/chezmoi
mise trust 2>&1 | grep -v "^mise" || true

echo
echo "⚙️  Running mise bootstrap tasks..."
if [[ "$FULL_BOOTSTRAP" == true ]]; then
    mise run bootstrap-full
else
    mise run bootstrap
fi

echo
echo "✅ Bootstrap complete!"
echo

# Launch fish (skip in test mode or non-interactive)
if [[ -z "$BOOTSTRAP_TEST" ]] && [[ -t 0 ]]; then
    exec fish
fi

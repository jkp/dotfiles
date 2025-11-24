#!/bin/bash

set -e

export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
export DEBIAN_FRONTEND=noninteractive

echo "🚀 Bootstrapping dotfiles..."
echo

# Install chezmoi
if ! command -v chezmoi &> /dev/null; then
    echo "📦 Installing chezmoi..."
    curl -fsLS get.chezmoi.io | sh 2>&1 | grep -E "(installed|error)" || true
fi

# Install fish (detect OS)
if ! command -v fish &> /dev/null; then
    echo "🐚 Installing fish shell..."
    if [[ "$(uname)" == "Darwin" ]]; then
        command -v brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        brew install fish
    else
        sudo apt-get update -qq
        sudo apt-get install -y -qq fish > /dev/null
    fi
fi

# Apply dotfiles
echo "📂 Applying dotfiles..."
if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
    chezmoi update
else
    chezmoi init --apply jkp
fi

# Install mise
if ! command -v mise &> /dev/null; then
    echo "🔧 Installing mise..."
    curl -fsSL https://mise.run | sh 2>&1 | grep -E "(installed|error)" || true
fi

# Install tools and setup git hooks
echo "⚙️  Installing development tools and git hooks..."
cd ~/.local/share/chezmoi
mise trust 2>&1 | grep -v "^mise" || true
mise install

echo
echo "✅ Bootstrap complete!"
echo

# Launch fish
exec fish

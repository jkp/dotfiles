#!/bin/bash

set -e

export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
export DEBIAN_FRONTEND=noninteractive

echo "🚀 Bootstrapping dotfiles..."
echo

# Install chezmoi
if ! command -v chezmoi &> /dev/null; then
    echo "📦 Installing chezmoi..."
    curl -fsLS get.chezmoi.io | sh 2>&1 | grep -E "(installed|error)"
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

# Set fish as default shell
if [[ "$SHELL" != *fish ]]; then
    echo "🐚 Setting fish as default shell..."
    fish_path=$(which fish)
    if ! grep -q "$fish_path" /etc/shells; then
        echo "$fish_path" | sudo tee -a /etc/shells > /dev/null
    fi
    sudo chsh -s "$fish_path" "$USER"
fi

# Apply dotfiles
echo "📂 Applying dotfiles..."
if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
    # Already initialized - update from wherever it was initialized from
    if [ -n "$DOTFILES_SOURCE" ]; then
        # Local source: use apply (update expects git remote)
        chezmoi apply --source "$DOTFILES_SOURCE"
    else
        # Normal case: pull from GitHub
        chezmoi update
    fi
elif [ -n "$DOTFILES_SOURCE" ]; then
    # First time with local source - copy to standard location
    echo "Copying dotfiles from $DOTFILES_SOURCE..."
    mkdir -p "$HOME/.local/share"
    cp -r "$DOTFILES_SOURCE" "$HOME/.local/share/chezmoi"
    chezmoi apply
else
    # First time from GitHub
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

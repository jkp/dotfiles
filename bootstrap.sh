#!/bin/bash

set -e

export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

# Install chezmoi

if ! command -v chezmoi &> /dev/null; then
    curl -fsLS get.chezmoi.io | sh
fi

# Install fish (detect OS)

if ! command -v fish &> /dev/null; then
    if [[ "$(uname)" == "Darwin" ]]; then
        command -v brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        brew install fish
    else
        sudo apt update && sudo apt install -y fish
    fi
fi

# Apply dotfiles

chezmoi init --apply jkp

# Install mise

if ! command -v mise &> /dev/null; then
    curl https://mise.run | sh
fi

# Install tools and setup git hooks

cd ~/.local/share/chezmoi
mise trust
mise install

# Launch fish

exec fish

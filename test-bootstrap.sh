#!/bin/bash
set -e

export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
export DEBIAN_FRONTEND=noninteractive
export DOTFILES_SOURCE=/dotfiles
export BOOTSTRAP_TEST=1

echo "🚀 Running bootstrap..."
bash /dotfiles/bootstrap.sh

echo
echo "🔄 Testing idempotency - running bootstrap again..."
bash /dotfiles/bootstrap.sh

echo
echo "✅ Bootstrap test completed successfully!"

# Future: Add config validation tests here
# e.g., nvim --headless +checkhealth +qa
# e.g., fish -c "echo 'Fish works'"

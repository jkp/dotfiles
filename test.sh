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
echo "🧪 Verifying mise global tools installed..."
# Run in fish shell where mise is activated via config
fish -c '
if not command -v bat &> /dev/null
    echo "❌ ERROR: bat not found - mise global tools failed to install"
    exit 1
end
if not command -v zoxide &> /dev/null
    echo "❌ ERROR: zoxide not found - mise global tools failed to install"
    exit 1
end
echo "✅ Global tools verified (bat, zoxide)"
'

echo
echo "✅ Bootstrap test completed successfully!"

# Future: Add more validation tests here
# e.g., nvim --headless +checkhealth +qa

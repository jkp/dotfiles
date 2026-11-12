#!/bin/bash
set -e

export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
export DEBIAN_FRONTEND=noninteractive
export DOTFILES_SOURCE=/dotfiles
export BOOTSTRAP_TEST=1

# Leftovers from configs main no longer manages; .chezmoiremove should delete them.
dropped=(aerospace wezterm karabiner)
for d in "${dropped[@]}"; do mkdir -p "$HOME/.config/$d" && touch "$HOME/.config/$d/leftover"; done

echo "🚀 Running bootstrap..."
bash /dotfiles/bootstrap.sh

echo
echo "🔄 Testing idempotency - running bootstrap again..."
bash /dotfiles/bootstrap.sh

echo
echo "🧪 Verifying mise global tools installed..."
# Run in fish shell where mise is activated via config
fish -c '
set -l failed 0
set -l tools bat zoxide fd rg jq nvim bd

for tool in $tools
    if command -q $tool
        echo "  ✓ $tool"
    else
        echo "  ✗ $tool - NOT FOUND"
        set failed 1
    end
end

if test $failed -eq 1
    echo "❌ ERROR: Some mise global tools failed to install"
    exit 1
end
echo "✅ All global tools verified"
'

echo
echo "🧪 Verifying fish functions loaded..."
fish -c '
set -l failed 0
set -l funcs chezmoi-check chezmoi-commit

for func in $funcs
    if functions -q $func
        echo "  ✓ $func"
    else
        echo "  ✗ $func - NOT FOUND"
        set failed 1
    end
end

if test $failed -eq 1
    echo "❌ ERROR: Some fish functions not loaded"
    exit 1
end
echo "✅ Fish functions verified"
'

echo
echo "🧪 Verifying dropped configs were removed..."
for d in "${dropped[@]}"; do
    if [ -e "$HOME/.config/$d" ]; then
        echo "❌ ERROR: ~/.config/$d survived bootstrap"
        exit 1
    fi
    echo "  ✓ ~/.config/$d removed"
done

echo
echo "✅ Bootstrap test completed successfully!"

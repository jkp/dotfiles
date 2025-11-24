if status is-interactive
    # Default EDITOR (override locally with: set -U EDITOR <path>)
    set -gx EDITOR nvim
    set -gx VISUAL $EDITOR
    set -gx PAGER less
    set -gx LESS '-F -g -i -M -R -S -w -X -z-4'
    set -gx CLICOLOR yes

    abbr --add c bat
    abbr --add cm chezmoi
    abbr --add gst git status
    abbr --add gl git log --oneline -n 20
    abbr --add gp git push
    abbr --add e $EDITOR
end

# Activate mise if available
command -v mise &>/dev/null && mise activate fish | source

# Initialize zoxide if available
command -v zoxide &>/dev/null && zoxide init fish --cmd n | source

# Source 1Password plugins if available (macOS)
test -f ~/.config/op/plugins.sh && source ~/.config/op/plugins.sh

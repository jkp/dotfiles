if status is-interactive
    set -gx EDITOR ~/.bin/edit
    set -gx VISUAL $EDITOR
    set -gx PAGER less
    set -gx LESS '-F -g -i -M -R -S -w -X -z-4'
    set -gx CLICOLOR yes

    abbr --add e $EDITOR
    abbr --add c bat

    abbr --add cm chezmoi
    abbr --add cmc chezmoi-check

    abbr --add gst git status
    abbr --add gl git log --oneline -n 20
    abbr --add gp git push
    abbr --add gc gib commit
end

# Activate mise if available
command -v mise &>/dev/null && mise activate fish | source

# Initialize zoxide if available
command -v zoxide &>/dev/null && zoxide init fish --cmd n | source

# Source 1Password plugins if available (macOS)
test -f ~/.config/op/plugins.sh && source ~/.config/op/plugins.sh

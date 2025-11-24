if status is-interactive
    set -gx EDITOR ~/.bin/edit
    set -gx VISUAL $EDITOR
    set -gx PAGER less
    set -gx LESS '-F -g -i -M -R -S -w -X -z-4'
    set -gx CLICOLOR yes

    abbr --add c bat
    abbr --add gst git status
    abbr --add gl git log --oneline -n 20
    abbr --add e $EDITOR
end

/Users/jkp/.local/bin/mise activate fish | source # added by https://mise.run/fish
zoxide init fish --cmd n | source
source ~/.config/op/plugins.sh

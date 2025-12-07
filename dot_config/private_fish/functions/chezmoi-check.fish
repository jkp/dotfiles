function chezmoi-check
    # Check for drift: managed files modified outside chezmoi
    set -l drift (chezmoi status 2>/dev/null)

    # Get unmanaged files/dirs in managed directories (excludes gitignored)
    set -l managed_dirs (chezmoi managed | grep -o '^\.[^/]*' | sort -u)
    set -l untracked
    for dir in $managed_dirs
        # Skip if it's a file not a directory
        test -d ~/$dir || continue
        for item in (chezmoi unmanaged ~/$dir 2>/dev/null)
            # Skip gitignored files
            git -C ~/.local/share/chezmoi check-ignore -q $item 2>/dev/null && continue
            # Mark directories so user knows to investigate
            if test -d ~/$item
                set -a untracked "$item/ [dir]"
            else
                set -a untracked $item
            end
        end
    end

    # Git status for modifications
    set -l git_status (git -C ~/.local/share/chezmoi status --porcelain 2>/dev/null)

    if test -n "$drift"
        echo "⚠️  drifted from chezmoi source:"
        printf '    %s\n' $drift
    end

    if test -n "$untracked"
        echo "⚠️  untracked dotfiles:"
        printf '    ~/%s\n' $untracked
    end

    if test -n "$git_status"
        echo "⚠️  uncommitted changes in chezmoi repo:"
        printf '    %s\n' $git_status
    end

    if test -n "$drift" -o -n "$untracked" -o -n "$git_status"
        echo "   run: chezmoi-commit"
    end
end

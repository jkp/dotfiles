function chezmoi-check
    # Check for drift: managed files modified outside chezmoi
    set -l drift (chezmoi status 2>/dev/null)

    # Get unmanaged files in managed directories (excludes ignored files and directories)
    set -l managed_dirs (chezmoi managed | grep -o '^\.config/[^/]*' | sort -u)
    set -l untracked
    for dir in $managed_dirs
        for item in (chezmoi unmanaged ~/$dir 2>/dev/null)
            test -f ~/$item && set -a untracked $item
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

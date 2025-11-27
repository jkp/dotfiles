function chezmoi-check
    # Get unmanaged files in managed directories (excludes ignored files and directories)
    set -l managed_dirs (chezmoi managed | grep -o '^\.config/[^/]*' | sort -u)
    set -l untracked
    for dir in $managed_dirs
        for item in (chezmoi unmanaged ~/$dir 2>/dev/null)
            test -f $item && set -a untracked (echo $item | sed "s|$HOME/||")
        end
    end

    # Git status for modifications
    set -l git_status (git -C ~/.local/share/chezmoi status --porcelain 2>/dev/null)

    if test -n "$untracked"
        echo "⚠️  untracked dotfiles:"
        printf '    ~/%s\n' $untracked
    end

    if test -n "$git_status"
        echo "⚠️  uncommitted changes in chezmoi repo"
    end

    if test -n "$untracked" -o -n "$git_status"
        echo "   run: chezmoi-commit"
    end
end

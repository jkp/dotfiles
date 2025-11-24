function chezmoi-status
    set -l managed_dirs (chezmoi managed | grep -o '^\.config/[^/]*' | sort -u)
    
    # Get files on disk
    set -l disk_files (for dir in $managed_dirs; find ~/$dir -type f 2>/dev/null; end | sed "s|$HOME/||" | sort)
    
    # Get managed files
    set -l managed_files (chezmoi managed | sort)
    
    # Find untracked (in disk but not managed)
    set -l untracked (comm -23 (printf '%s\n' $disk_files | psub) (printf '%s\n' $managed_files | psub))
    
    # Git status for modifications
    set -l git_status (git -C ~/.local/share/chezmoi status --porcelain 2>/dev/null)
    
    if test -n "$untracked"
        echo "⚠️  untracked dotfiles:"
        printf '    %s\n' $untracked
    end
    
    if test -n "$git_status"
        echo "⚠️  uncommitted changes in chezmoi repo"
    end
    
    if test -n "$untracked" -o -n "$git_status"
        echo "   run: chezmoi-commit"
    end
end

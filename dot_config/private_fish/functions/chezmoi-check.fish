function chezmoi-check
    set -l tmpdir (mktemp -d)

    # Run expensive commands in parallel
    chezmoi status 2>/dev/null > $tmpdir/drift &
    git -C ~/.local/share/chezmoi status --porcelain 2>/dev/null > $tmpdir/git &
    set -l managed_dirs (chezmoi managed | grep -o '^\.[^/]*' | sort -u)
    for dir in $managed_dirs
        test -d ~/$dir && chezmoi unmanaged ~/$dir 2>/dev/null >> $tmpdir/unmanaged &
    end
    wait

    set -l drift (cat $tmpdir/drift)
    set -l git_status (cat $tmpdir/git)
    set -l all_items (cat $tmpdir/unmanaged 2>/dev/null)
    rm -rf $tmpdir

    # Batch filter: remove gitignored files
    set -l not_ignored
    if test -n "$all_items"
        set -l ignored (printf '%s\n' $all_items | git -C ~/.local/share/chezmoi check-ignore --stdin 2>/dev/null)
        for item in $all_items
            contains -- $item $ignored || set -a not_ignored $item
        end
    end

    # Batch check file types and build final list
    set -l untracked
    set -l files_to_check
    for item in $not_ignored
        if test -d ~/$item
            set -a untracked "$item/ [dir]"
        else
            set -a files_to_check $item
        end
    end

    # Filter out Mach-O binaries in one batch
    if test -n "$files_to_check"
        set -l binaries (file (printf "$HOME/%s\n" $files_to_check) 2>/dev/null | grep "Mach-O" | cut -d: -f1 | sed "s|$HOME/||")
        for item in $files_to_check
            contains -- $item $binaries || set -a untracked $item
        end
    end

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

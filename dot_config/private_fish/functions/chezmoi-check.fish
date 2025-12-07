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

    # Filter out binaries and pipx-installed scripts in batch
    if test -n "$files_to_check"
        # Mach-O binaries (one file command)
        set -l binaries (file (printf "$HOME/%s\n" $files_to_check) 2>/dev/null | grep "Mach-O" | cut -d: -f1 | sed "s|$HOME/||")

        # Get non-binary files for shebang check
        set -l scripts
        for f in $files_to_check
            contains -- $f $binaries || set -a scripts $f
        end

        # Scripts with pipx/uv/venv/system shebangs (skip installed tools)
        set -l installed
        if test -n "$scripts"
            set installed (awk 'FNR==1 && /(pipx|uvenv|uv\/tools|venv|\/Applications\/)/ {print FILENAME}' (printf "$HOME/%s\n" $scripts) 2>/dev/null | sed "s|$HOME/||")
        end

        # Add non-skipped files to untracked
        for item in $files_to_check
            contains -- $item $binaries && continue
            contains -- $item $installed && continue
            set -a untracked $item
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

function chezmoi-check
    set -l verbose false
    for arg in $argv
        test "$arg" = "--verbose" -o "$arg" = "-v" && set verbose true
    end

    set -l tmpdir (mktemp -d)

    # Run expensive commands in parallel
    chezmoi status 2>/dev/null > $tmpdir/drift &
    git -C ~/.local/share/chezmoi status --porcelain 2>/dev/null > $tmpdir/git &
    set -l managed_dirs (chezmoi managed | grep -o '^\.[^/]*' | sort -u)
    for dir in $managed_dirs
        test -d ~/$dir && chezmoi-unmanaged --filter ~/$dir 2>/dev/null >> $tmpdir/unmanaged &
    end
    wait

    set -l drift (cat $tmpdir/drift)
    set -l git_status (cat $tmpdir/git)
    set -l unmanaged_items (cat $tmpdir/unmanaged 2>/dev/null)
    rm -rf $tmpdir

    # Batch check file types and build final list
    set -l untracked
    set -l files_to_check
    for item in $unmanaged_items
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
        if test "$verbose" = true
            printf '    ~/%s\n' $untracked
        else
            # Group by parent directory and collapse large groups
            set -l config_dirs
            set -l other_items
            set -l collapse_threshold 5

            for item in $untracked
                if string match -q '.config/*' (string replace -r ' \[dir\]$' '' $item)
                    set -a config_dirs $item
                else
                    set -a other_items $item
                end
            end

            # Show collapsed .config summary if many items
            set -l config_count (count $config_dirs)
            set -l collapsed false
            if test $config_count -gt $collapse_threshold
                echo "    ~/.config/ [$config_count app configs]"
                set collapsed true
            else if test $config_count -gt 0
                printf '    ~/%s\n' $config_dirs
            end

            # Show other items individually
            if test (count $other_items) -gt 0
                printf '    ~/%s\n' $other_items
            end

            # Hint about verbose if we collapsed
            if test "$collapsed" = true
                echo "    (use -v to see all)"
            end
        end
    end

    if test -n "$git_status"
        echo "⚠️  uncommitted changes in chezmoi repo:"
        printf '    %s\n' $git_status
    end

    if test -n "$drift" -o -n "$untracked" -o -n "$git_status"
        echo "   run: chezmoi-commit"
    end
end

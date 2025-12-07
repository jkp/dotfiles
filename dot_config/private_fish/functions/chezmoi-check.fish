function chezmoi-check
    set -l verbose false
    set -l quiet false
    for arg in $argv
        test "$arg" = "--verbose" -o "$arg" = "-v" && set verbose true
        test "$arg" = "--quiet" -o "$arg" = "-q" && set quiet true
    end

    set -l tmpdir (mktemp -d)

    # Run expensive commands in parallel
    chezmoi status 2>/dev/null | grep -v '^ R ' > $tmpdir/drift &
    git -C ~/.local/share/chezmoi status --porcelain 2>/dev/null > $tmpdir/git &
    # Build list of managed directories, then single call to chezmoi-unmanaged
    set -l managed_dirs (chezmoi managed | grep -o '^\.[^/]*' | sort -u)
    set -l dir_paths
    for dir in $managed_dirs
        test -d ~/$dir && set -a dir_paths ~/$dir
    end
    chezmoi-unmanaged --filter $dir_paths 2>/dev/null > $tmpdir/unmanaged &
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

    # Count issues
    set -l drift_count (count $drift)
    set -l untracked_count (count $untracked)
    set -l git_count (count $git_status)
    set -l has_issues (test -n "$drift" -o -n "$untracked" -o -n "$git_status" && echo true || echo false)

    # Quiet mode: single line summary or nothing
    if test "$quiet" = true
        if test "$has_issues" = true
            set -l parts
            test $drift_count -gt 0 && set -a parts (set_color yellow)"$drift_count drifted"(set_color normal)
            test $untracked_count -gt 0 && set -a parts (set_color cyan)"$untracked_count untracked"(set_color normal)
            test $git_count -gt 0 && set -a parts (set_color red)"$git_count uncommitted"(set_color normal)
            echo "📦 "(string join " · " $parts)" "(set_color brblack)"(cmc -v)"(set_color normal)
        end
        return
    end

    # Normal/verbose output
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

    if test "$has_issues" = true
        echo "   run: chezmoi-commit"
    end
end

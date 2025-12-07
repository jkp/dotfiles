function chezmoi-unmanaged
    set -l do_filter false
    set -l args

    for arg in $argv
        if test "$arg" = "--filter"
            set do_filter true
        else
            set -a args $arg
        end
    end

    set -l output (chezmoi unmanaged $args)
    set -l ignore_file ~/.local/share/chezmoi/.chezmoiunmanagedignore

    if test "$do_filter" = true
        # First filter: global gitignore (temp files, .DS_Store, etc.)
        set -l gitignored (printf '%s\n' $output | git -C ~/.local/share/chezmoi check-ignore --stdin 2>/dev/null)
        set -l filtered
        for item in $output
            contains -- $item $gitignored || set -a filtered $item
        end
        set output $filtered

        # Second filter: .chezmoiunmanagedignore patterns
        if not test -f $ignore_file
            printf '%s\n' $output
            return
        end

        # Read and convert gitignore patterns to fish globs
        set -l patterns
        for line in (grep -v '^#' $ignore_file | grep -v '^$')
            # Check for literal **/ prefix
            if test (string sub -l 3 -- $line) = '**/'
                # **/foo/ -> *foo* (match anywhere, with or without trailing content)
                set -l name (string sub -s 4 -- $line | string replace -r '/$' '')
                set -a patterns '*'$name'*'
            else if test (string sub -s -1 -- $line) = '/'
                # Directory pattern
                set -l base (string sub -e -1 -- $line)
                if string match -q -- '*/*' $base
                    # .config/foo/ -> match .config/foo and .config/foo/*
                    set -a patterns $base
                    set -a patterns $line'*'
                else
                    # foo/ -> *foo* (floating, match anywhere)
                    set -a patterns '*'$base'*'
                end
            else
                set -a patterns $line
            end
        end

        # Filter output
        for item in $output
            set -l skip false
            for pattern in $patterns
                if string match -q -- $pattern $item
                    set skip true
                    break
                end
            end
            test "$skip" = false && echo $item
        end
    else
        printf '%s\n' $output
    end
end

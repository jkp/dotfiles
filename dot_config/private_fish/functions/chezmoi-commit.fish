function chezmoi-commit
    set -l managed_dirs (chezmoi managed | grep -o '^\.config/[^/]*' | sort -u)
    set -l disk_files (for dir in $managed_dirs; find ~/$dir -type f 2>/dev/null; end | sed "s|$HOME/||" | sort)
    set -l managed_files (chezmoi managed | sort)
    set -l untracked (comm -23 (printf '%s\n' $disk_files | psub) (printf '%s\n' $managed_files | psub))
    
    # Handle untracked files one by one
    for file in $untracked
        echo "Untracked: $file"
        read -P "(a)dd / (i)gnore / (s)kip? " choice
        switch $choice
            case a
                chezmoi add ~/$file
            case i
                echo $file >> ~/.local/share/chezmoi/.chezmoiignore
                echo "Added to .chezmoiignore"
            case '*'
                echo "Skipped"
        end
    end
    
    # Handle modified files
    chezmoi re-add
    
    # Commit if there are changes
    if test -n "$(git -C ~/.local/share/chezmoi status --porcelain)"
        git -C ~/.local/share/chezmoi add -A
        if git -C ~/.local/share/chezmoi commit
            read -P "Push? (y/n) " push
            test "$push" = "y" && git -C ~/.local/share/chezmoi push
        else
            echo "Commit aborted"
        end
    else
        echo "Nothing to commit"
    end
end

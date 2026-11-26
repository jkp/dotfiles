if not status is-interactive && test "$CI" != true
    exit
end
if test "$CI" = true
    chezmoi-check -q
    exit
end

# Show the last summary now and refresh it in the background: the scan takes
# hundreds of ms, so it never blocks the prompt. The summary is one shell stale.
set -l cache_dir ~/.cache
set -q XDG_CACHE_HOME && set cache_dir $XDG_CACHE_HOME
set -l cache $cache_dir/chezmoi-check
test -f $cache && cat $cache
mkdir -p $cache_dir
set -l fish (status fish-path)
# Per-shell temp file + mv, so concurrent shells never show a half-written summary.
$fish -c 'chezmoi-check -q >$argv[1] 2>&1; mv -f $argv[1] $argv[2]' $cache.$fish_pid $cache </dev/null &>/dev/null &
disown

#!/bin/bash
# An interactive fish start shows the previous drift summary at once and
# refreshes it in the background, so startup never waits on the scan.
#
#   ./tests/chezmoi-drift.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
command -v fish >/dev/null || { echo "SKIP: needs fish"; exit 0; }

# A slow stand-in for the real scan, autoloaded by the background fish.
mkdir -p "$WORK/config/fish/functions" "$WORK/cache"
printf 'function chezmoi-check; sleep 2; echo "fresh $argv"; end\n' > "$WORK/config/fish/functions/chezmoi-check.fish"

start_shell() {
    XDG_CONFIG_HOME="$WORK/config" XDG_CACHE_HOME="$WORK/cache" fish --no-config -i -c \
        "source '$HERE/dot_config/fish/conf.d/chezmoi-drift.fish'" 2>&1
}
wait_for_cache() {
    for _ in $(seq 50); do
        [[ "$(cat "$WORK/cache/chezmoi-check" 2>/dev/null)" == "$1" ]] && return 0
        sleep 0.1
    done
    fail "cache never became '$1': $(cat "$WORK/cache/chezmoi-check" 2>/dev/null)"
}

start=$SECONDS
out="$(start_shell)" || fail "fish failed to start: $out"
(( SECONDS - start < 2 )) || fail "first start waited on the scan"
[[ -z "$out" ]] || fail "first start, with no previous result, printed: $out"
wait_for_cache "fresh -q"

echo 'previous summary' > "$WORK/cache/chezmoi-check"
start=$SECONDS
out="$(start_shell)" || fail "fish failed to start: $out"
(( SECONDS - start < 2 )) || fail "start waited on the scan"
[[ "$out" == 'previous summary' ]] || fail "start didn't show the previous summary: $out"
wait_for_cache "fresh -q"
! compgen -G "$WORK/cache/chezmoi-check.*" >/dev/null || fail "left temp files: $(ls "$WORK/cache")"

echo 'PASS: startup shows the last summary instantly and refreshes it in the background'

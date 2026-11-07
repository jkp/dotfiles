#!/bin/bash
# A fish shell starts silently: the pinned zoxide's init (from config.fish)
# must not warn on fish 4, which embeds its functions instead of shipping them.
#
#   ./tests/fish-startup.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FAIL: $*"; exit 1; }
command -v fish >/dev/null && command -v mise >/dev/null || { echo "SKIP: needs fish and mise"; exit 0; }

ZOXIDE="$(sed -n 's/^zoxide = "\(.*\)"/\1/p' "$HERE/dot_config/mise/config.toml")"
[[ -n "$ZOXIDE" ]] || fail "no zoxide pin in dot_config/mise/config.toml"
grep -qF 'zoxide init fish --cmd n | source' "$HERE/dot_config/fish/config.fish" ||
    fail "config.fish no longer runs zoxide's init the way this test does"

out="$(mise exec "zoxide@$ZOXIDE" -- fish --no-config -c 'zoxide init fish --cmd n | source; functions -q n; or echo "no n function"' 2>&1)"
[[ -z "$out" ]] || fail "zoxide $ZOXIDE's fish init isn't silent on fish $(fish --version | awk '{print $NF}'): $out"
echo "PASS: zoxide $ZOXIDE initialises silently on fish $(fish --version | awk '{print $NF}')"

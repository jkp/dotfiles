#!/bin/bash
# The Colima LaunchAgent only exists where colima is installed: machines used
# as a control surface (no containers) get neither the agent nor its loader.
#
#   ./tests/colima-agent.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
[[ "$(uname)" == Darwin ]] || { echo "SKIP: colima agent is macOS-only"; exit 0; }

CHEZMOI="$(command -v chezmoi)"
mkdir -p "$WORK/bin" "$WORK/home"
printf '#!/bin/sh\n' > "$WORK/bin/colima" && chmod +x "$WORK/bin/colima"
managed() {
    PATH="$1:/usr/bin:/bin" "$CHEZMOI" --source "$HERE" --destination "$WORK/home" \
        --config "$WORK/none.toml" managed --include=files,scripts --exclude=encrypted
}

with="$(managed "$WORK/bin")"
grep -qx 'Library/LaunchAgents/co.kirkconsulting.colima.plist' <<<"$with" || fail "colima installed, but no agent: $with"
grep -q 'load-colima.sh' <<<"$with" || fail "colima installed, but no loader script"
PATH="$WORK/bin:/usr/bin:/bin" "$CHEZMOI" --source "$HERE" --destination "$WORK/home" --config "$WORK/none.toml" \
    cat "$WORK/home/Library/LaunchAgents/co.kirkconsulting.colima.plist" | grep -q "<string>$WORK/bin/colima</string>" ||
    fail "agent doesn't run the installed colima"
echo "PASS: with colima installed, the agent runs that colima and is loaded"

without="$(managed "$WORK/empty")"
grep -E "co.kirkconsulting.colima|load-colima" <<<"$without" && fail "no colima, but its agent or loader is managed"
echo "PASS: without colima, no agent and no loader"

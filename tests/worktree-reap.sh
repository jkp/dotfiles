#!/bin/bash
# worktree-reap: fast-forwards the checkout to origin/main, then runs that
# checkout's own reaper. Refuses to reap with code it could not update.
#
#   ./tests/worktree-reap.sh
set -euo pipefail
# Run from a git hook, GIT_DIR and GIT_INDEX_FILE point at this repository;
# the fixtures below must never write there.
unset $(git rev-parse --local-env-vars)

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$HERE/dot_local/bin/executable_worktree-reap"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
g() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=main "$@"; }

# origin with a reaper that records which version ran and with what arguments.
g init -q --bare "$WORK/origin.git"
g clone -q "$WORK/origin.git" "$WORK/seed" 2>/dev/null
mkdir -p "$WORK/seed/scripts/worktree"
reaper() { printf '#!/bin/bash\necho "%s $*" >> "$REAP_CALLS"\n' "$1" > "$WORK/seed/scripts/worktree/reap.sh"; }
reaper old
g -C "$WORK/seed" add -A && g -C "$WORK/seed" commit -qm old && g -C "$WORK/seed" push -q origin main
g clone -q "$WORK/origin.git" "$WORK/checkout"
reaper new
g -C "$WORK/seed" commit -qam new && g -C "$WORK/seed" push -q origin main

export REAP_CALLS="$WORK/calls" WORKTREE_REAP_LOCK="$WORK/lock"
run() { "$BIN" "$WORK/checkout" >"$WORK/out" 2>&1; }

# A stale checkout is updated first, and the updated reaper runs.
run || fail "stale checkout: $(cat "$WORK/out")"
[ "$(cat "$REAP_CALLS")" = "new --execute --idle-days 3" ] || fail "expected the new reaper with --execute --idle-days 3, got: $(cat "$REAP_CALLS")"

# Off main: no reap.
: > "$REAP_CALLS"
g -C "$WORK/checkout" switch -qc topic
run && fail "reaped while off main"
[ ! -s "$REAP_CALLS" ] || fail "reaper ran while off main"
grep -q 'not on main' "$WORK/out" || fail "off-main reason missing: $(cat "$WORK/out")"
g -C "$WORK/checkout" switch -q main

# main diverged from origin/main: no reap with code it can't update.
g -C "$WORK/checkout" commit -q --allow-empty -m local
g -C "$WORK/seed" commit -q --allow-empty -m upstream && g -C "$WORK/seed" push -q origin main
run && fail "reaped with a diverged main"
[ ! -s "$REAP_CALLS" ] || fail "reaper ran with a diverged main"
g -C "$WORK/checkout" reset -q --hard origin/main

# An overlapping run is skipped, not doubled.
mkdir "$WORKTREE_REAP_LOCK"
run || fail "locked run should exit cleanly: $(cat "$WORK/out")"
[ ! -s "$REAP_CALLS" ] || fail "reaper ran while another run held the lock"
rmdir "$WORKTREE_REAP_LOCK"

# The lock is released after a run.
run || fail "normal run: $(cat "$WORK/out")"
[ ! -e "$WORKTREE_REAP_LOCK" ] || fail "lock left behind"

echo "OK: worktree-reap"

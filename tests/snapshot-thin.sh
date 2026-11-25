#!/bin/bash
# snapshot-thin: below the free-space floor, it asks macOS (tmutil, urgency 4)
# to reclaim enough snapshot space to reach the target; above it, it does
# nothing; still below after thinning, it fails so the job notifies.
#
#   ./tests/snapshot-thin.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$HERE/dot_local/bin/executable_snapshot-thin"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
GIB=$((1024 * 1024))   # KiB

mkdir "$WORK/bin"
# df -k stand-in: the data volume's free KiB comes from $WORK/free.
cat > "$WORK/bin/df" <<STUB
#!/bin/sh
[ "\$2" = /System/Volumes/Data ] || exit 1
echo "Filesystem 1024-blocks Used Available Capacity Mounted"
echo "/dev/disk3s5 970000000 1 \$(cat "$WORK/free") 93% /System/Volumes/Data"
STUB
# tmutil stand-in: records its arguments, then frees space to $WORK/after.
cat > "$WORK/bin/tmutil" <<STUB
#!/bin/sh
echo "\$*" >> "$WORK/tmutil.calls"
[ ! -f "$WORK/after" ] || cp "$WORK/after" "$WORK/free"
STUB
chmod +x "$WORK/bin/df" "$WORK/bin/tmutil"
run() { PATH="$WORK/bin:/usr/bin:/bin" "$BIN" "$@" > "$WORK/out" 2>&1; }

echo $((80 * GIB)) > "$WORK/free"
run || fail "plenty of space failed: $(cat "$WORK/out")"
[ ! -e "$WORK/tmutil.calls" ] || fail "thinned with 80 GiB free"
echo "PASS: above the floor, it leaves snapshots alone"

echo $((50 * GIB)) > "$WORK/free"; echo $((110 * GIB)) > "$WORK/after"
run || fail "a successful thin failed: $(cat "$WORK/out")"
[ "$(cat "$WORK/tmutil.calls")" = "thinlocalsnapshots / $((50 * GIB * 1024)) 4" ] ||
  fail "should ask for 50 GiB at urgency 4: $(cat "$WORK/tmutil.calls")"
grep -q '50 GiB free' "$WORK/out" && grep -q 'now 110 GiB free' "$WORK/out" || fail "log lacks before/after: $(cat "$WORK/out")"
echo "PASS: below the floor, it reclaims up to the target and logs before and after"

rm "$WORK/tmutil.calls"; echo $((20 * GIB)) > "$WORK/free"; echo $((30 * GIB)) > "$WORK/after"
run && fail "still low after thinning, but exited 0"
grep -q 'still' "$WORK/out" || fail "doesn't say the disk is still low: $(cat "$WORK/out")"
echo "PASS: still below the floor after thinning, it fails so the job notifies"

rm "$WORK/tmutil.calls" "$WORK/after"; echo $((90 * GIB)) > "$WORK/free"
run 100 150 && fail "90 GiB free is under a 100 GiB floor, but exited 0"
[ -e "$WORK/tmutil.calls" ] || fail "custom floor of 100 GiB ignored"
echo "PASS: floor and target can be set"

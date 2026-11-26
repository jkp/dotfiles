#!/bin/bash
# docker-prune: removes unused images and build cache, then trims Colima's
# disk so the space returns to macOS. Does nothing while Colima is stopped;
# fails (so the job notifies) when a step fails.
#
#   ./tests/docker-prune.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$HERE/dot_local/bin/executable_docker-prune"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

mkdir "$WORK/bin"
# Stand-ins record their arguments; $WORK/<tool>.fails makes "<tool> <first arg>" fail.
for tool in docker colima; do
  cat > "$WORK/bin/$tool" <<STUB
#!/bin/sh
echo "$tool \$*" >> "$WORK/calls"
! grep -qx "\$1" "$WORK/$tool.fails" 2>/dev/null
STUB
  chmod +x "$WORK/bin/$tool"
done
run() { : > "$WORK/calls"; PATH="$WORK/bin:/usr/bin:/bin" "$BIN" > "$WORK/out" 2>&1; }

run || fail "a normal run failed: $(cat "$WORK/out")"
want='colima status
docker image prune -a -f
docker builder prune -a -f
colima ssh -- sudo fstrim -av'
[ "$(cat "$WORK/calls")" = "$want" ] || fail "expected status, image prune, builder prune, trim; got: $(cat "$WORK/calls")"
echo "PASS: prunes unused images and build cache, then trims the disk"

echo status > "$WORK/colima.fails"
run || fail "stopped Colima should exit 0: $(cat "$WORK/out")"
[ "$(cat "$WORK/calls")" = "colima status" ] || fail "touched Docker while Colima was stopped: $(cat "$WORK/calls")"
grep -q 'not running' "$WORK/out" || fail "no skip reason: $(cat "$WORK/out")"
echo "PASS: leaves a stopped Colima alone"

rm "$WORK/colima.fails"; echo image > "$WORK/docker.fails"
run && fail "a failed prune exited 0"
grep -q 'colima ssh' "$WORK/calls" || fail "a failed image prune skipped the trim: $(cat "$WORK/calls")"
echo "PASS: a failed step fails the run, after the rest still ran"

echo "OK: docker-prune"

#!/bin/bash
# docker-image-use: records which image each container starts from, so we can
# learn which tagged images are actually used before pruning any of them.
#
#   ./tests/docker-image-use.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$HERE/dot_local/bin/executable_docker-image-use"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
# Run watch for $1 seconds; fails if it exits on its own instead of waiting to reconnect.
watch_for() {
  "$BIN" watch > "$WORK/out" 2>&1 & local pid=$!
  sleep "$1"; kill -0 "$pid" 2>/dev/null || return 1
  pkill -P "$pid" 2>/dev/null; kill "$pid"; wait "$pid" 2>/dev/null || true
}

mkdir "$WORK/bin"
# docker events emits two starts then drops (as when Colima stops); image ls lists three images.
cat > "$WORK/bin/docker" <<STUB
#!/bin/sh
echo "docker \$*" >> "$WORK/calls"
case "\$1 \$2" in
  "events --filter") printf '1764100000 ubuntu:24.04\n1764200000 ubuntu:24.04\n' ;;
  "image ls") printf 'ubuntu:24.04 139MB\npostgres:16-alpine 411MB\nmy/app:dev 2GB\n' ;;
esac
STUB
chmod +x "$WORK/bin/docker"
export PATH="$WORK/bin:/usr/bin:/bin" HOME="$WORK/home" XDG_STATE_HOME=
log="$WORK/home/.local/state/docker-image-use/starts.log"

watch_for 3 || fail "watch returned instead of waiting to reconnect"
grep -Eqx 'docker events --filter type=container --filter event=start --format \{\{\.Time}} \{\{\.Actor\.Attributes\.image}} --since [0-9]+' "$WORK/calls" ||
  fail "did not watch container starts: $(cat "$WORK/calls")"
since="$(sed -n 's/.*--since //p' "$WORK/calls")"
[ $(( $(date +%s) - since )) -ge 604700 ] || fail "first run should replay the past week, got --since $since"
echo 1764200000 ubuntu:24.04 > "$log"; : > "$WORK/calls"
watch_for 2 || fail "watch returned instead of waiting to reconnect"
grep -q -- '--since 1764200001$' "$WORK/calls" || fail "did not resume after the last logged start: $(cat "$WORK/calls")"
[ "$(cat "$log")" = $'1764200000 ubuntu:24.04\n1764100000 ubuntu:24.04\n1764200000 ubuntu:24.04' ] || fail "log not appended to: $(cat "$log")"
: > "$log"; : > "$WORK/calls"; watch_for 3 || fail "watch returned instead of waiting to reconnect"
[ "$(cat "$log")" = $'1764100000 ubuntu:24.04\n1764200000 ubuntu:24.04' ] || fail "starts not logged: $(cat "$log" 2>&1)"
[ "$(grep -c '^docker events' "$WORK/calls")" = 1 ] || fail "reconnected without a pause: $(cat "$WORK/calls")"
echo "PASS: logs each container start's image, and waits before reconnecting"

"$BIN" report > "$WORK/out" 2>&1 || fail "report failed: $(cat "$WORK/out")"
grep -q "^Since $(date -u -r 1764100000 +%F 2>/dev/null || date -u -d @1764100000 +%F)" "$WORK/out" || fail "no start of the record: $(cat "$WORK/out")"
grep -Eq '^ubuntu:24.04 +139MB +2 +2025-11-2' "$WORK/out" || fail "used image not reported with count and last use: $(cat "$WORK/out")"
grep -Eq '^postgres:16-alpine +411MB +0 +never' "$WORK/out" || fail "unused image not reported as never: $(cat "$WORK/out")"
[ "$(sed -n 2p "$WORK/out" | cut -d' ' -f1)" = IMAGE ] && [ "$(sed -n 3p "$WORK/out" | cut -d' ' -f1)" != ubuntu:24.04 ] ||
  fail "never-used images should list first: $(cat "$WORK/out")"
echo "PASS: report shows each image's size, starts and last start, unused first"

echo "OK: docker-image-use"

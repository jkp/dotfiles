#!/bin/bash
# kanata-active-user runs kanata only while the given user owns the console.
#
#   ./tests/kanata-active-user.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRAPPER="$HERE/dot_config/kanata/executable_kanata-active-user"
WORK="$(mktemp -d)"
trap 'kill $(jobs -p) 2>/dev/null || true; rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

# Fake stat answers the console owner from a file; fake kanata records its life.
mkdir "$WORK/bin"
printf '#!/bin/bash\ncat "%s/console"\n' "$WORK" > "$WORK/bin/stat"
printf '#!/bin/bash\necho "$*" > "%s/args"\ntrap "echo term > %s/killed; exit 0" TERM\nwhile :; do sleep 0.1; done\n' \
    "$WORK" "$WORK" > "$WORK/bin/kanata"
chmod +x "$WORK/bin/"*
export PATH="$WORK/bin:$PATH"
console() { echo "$1" > "$WORK/console"; }
wait_for() { for _ in $(seq 50); do eval "$1" && return 0; sleep 0.1; done; fail "timed out: $2"; }

console agatakrasicka
bash "$WRAPPER" jkp kanata -c cfg || fail "exited non-zero when another user owns the console"
[[ ! -e "$WORK/args" ]] || fail "started kanata for another user's session"
echo "PASS: does nothing while another user owns the console"

console jkp
bash "$WRAPPER" jkp kanata -c cfg & pid=$!
wait_for '[[ -e "$WORK/args" ]]' "kanata never started"
[[ "$(cat "$WORK/args")" == "-c cfg" ]] || fail "kanata got the wrong args: $(cat "$WORK/args")"
echo "PASS: runs kanata while the user owns the console"

console root
wait_for '! kill -0 $pid 2>/dev/null' "wrapper kept running after the console changed hands"
[[ -e "$WORK/killed" ]] || fail "kanata wasn't stopped when the console changed hands"
wait $pid || fail "exited non-zero after the console changed hands"
echo "PASS: stops kanata and exits when the console changes hands"

rm -f "$WORK/args" "$WORK/killed"; console jkp
bash "$WRAPPER" jkp kanata -c cfg & pid=$!
wait_for '[[ -e "$WORK/args" ]]' "kanata never started"
kill -TERM $pid
wait_for '! kill -0 $pid 2>/dev/null' "wrapper ignored SIGTERM"
[[ -e "$WORK/killed" ]] || fail "SIGTERM didn't stop kanata"
echo "PASS: SIGTERM stops kanata"

printf '#!/bin/bash\nexit 3\n' > "$WORK/bin/kanata"
rc=0; bash "$WRAPPER" jkp kanata || rc=$?
[[ $rc -eq 3 ]] || fail "expected kanata's exit status 3, got $rc"
echo "PASS: passes on kanata's exit status when it dies"

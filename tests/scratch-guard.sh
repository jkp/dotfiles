#!/bin/bash
# chezmoi replaces a real folder with a symlink by deleting it, so before the
# Scratch symlinks are applied, a real ~/.tart or ~/.colima stops the apply
# with the data intact. Runs a real chezmoi apply against a throwaway home.
#
#   ./tests/scratch-guard.sh
set -euo pipefail
unset $(git rev-parse --local-env-vars)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

# Just the Scratch parts of the source, so no other script touches this machine.
mkdir -p "$WORK/src" "$WORK/home"
cp "$HERE"/run_before_*scratch-guard* "$HERE"/symlink_dot_tart* "$HERE"/symlink_dot_colima* "$WORK/src/"
printf 'scratch:\n  testhost: [tart, colima]\n' > "$WORK/src/.chezmoidata.yaml"
apply() {
  chezmoi --source "$WORK/src" --destination "$WORK/home" --config "$WORK/c.toml" \
    --persistent-state "$WORK/s.db" --no-tty --force \
    --override-data '{"chezmoi":{"os":"darwin","hostname":"testhost"}}' apply </dev/null > "$WORK/out" 2>&1
}

mkdir "$WORK/home/.colima"; echo db > "$WORK/home/.colima/pgdata"
apply && fail "apply went ahead over a real ~/.colima"
[ "$(cat "$WORK/home/.colima/pgdata" 2>/dev/null)" = db ] || fail "~/.colima's data is gone"
grep -q 'move it to /Volumes/Scratch/colima first' "$WORK/out" || fail "no move-it-first message: $(cat "$WORK/out")"
[ ! -L "$WORK/home/.tart" ] || fail "applied a symlink although the apply was refused"
echo "PASS: a real ~/.colima stops the apply with its data intact"

rm -rf "$WORK/home/.colima"
apply || fail "apply with nothing in the way failed: $(cat "$WORK/out")"
[ "$(readlink "$WORK/home/.tart")" = /Volumes/Scratch/tart ] || fail "~/.tart isn't linked to Scratch"
[ "$(readlink "$WORK/home/.colima")" = /Volumes/Scratch/colima ] || fail "~/.colima isn't linked to Scratch"
apply || fail "apply over the symlinks themselves failed: $(cat "$WORK/out")"
echo "PASS: with nothing in the way, both are linked to Scratch, and reapplying is fine"

echo "OK: scratch-guard"

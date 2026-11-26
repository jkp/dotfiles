#!/bin/bash
# Machine-specific config is opt-in by hostname in .chezmoidata.yaml (jobs,
# scratch). Whatever tkol gets only because it is listed there must reach no
# other machine: not Linux, not an unlisted Mac.
#
#   ./tests/host-gating.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

printf '[warnings]\n    configFileTemplateHasChanged = false\n' >"$WORK/chezmoi.toml"
mkdir "$WORK/home"
# Targets chezmoi would manage for <os> <hostname> [extra data].
managed() {
    chezmoi --source "$HERE" --config "$WORK/chezmoi.toml" --persistent-state "$WORK/state.boltdb" \
        --destination "$WORK/home" --no-tty \
        --override-data "{\"chezmoi\":{\"os\":\"$1\",\"hostname\":\"$2\"}${3:-}}" \
        managed --include files,scripts,symlinks --exclude encrypted </dev/null | sort
}

# What tkol gets from its host lists: everything that goes when they're emptied.
gated="$(comm -23 <(managed darwin tkol) <(managed darwin tkol ',"jobs":{"tkol":[]},"scratch":{"tkol":[]}'))"
for anchor in Library/LaunchAgents/co.kirkconsulting.pitchfork.plist .config/pitchfork-jobs/config.toml .local/bin/scratch-volume .tart .colima; do
    grep -qx "$anchor" <<<"$gated" || fail "tkol's host lists don't bring $anchor: $gated"
done

for machine in "linux tkol" "linux some-box" "darwin agatas-mac"; do
    # shellcheck disable=SC2086 # two words: os hostname
    leaked="$(comm -12 <(managed $machine) <(printf '%s\n' "$gated"))"
    [ -z "$leaked" ] || fail "$machine gets tkol-only config: $leaked"
done

grep -q '^pitchfork' "$HERE/dot_config/mise/config.toml" && fail "pitchfork is pinned for every machine"

echo "PASS: tkol-only config reaches no other machine (linux, unlisted Mac)"

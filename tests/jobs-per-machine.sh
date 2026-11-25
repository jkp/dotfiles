#!/bin/bash
# Scheduled jobs are opt-in per machine: only a Mac whose hostname lists jobs in
# .chezmoidata.yaml gets the pitchfork supervisor, its pin and its jobs; Linux
# and unlisted Macs get none of it.
#
#   ./tests/jobs-per-machine.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

printf '[warnings]\n    configFileTemplateHasChanged = false\n' >"$WORK/chezmoi.toml"
mkdir "$WORK/home"
# Targets chezmoi would manage for a machine with this os and hostname.
managed() {
    chezmoi --source "$HERE" --config "$WORK/chezmoi.toml" --persistent-state "$WORK/state.boltdb" \
        --destination "$WORK/home" --no-tty \
        --override-data "{\"chezmoi\":{\"os\":\"$1\",\"hostname\":\"$2\"}}" \
        managed --include files,scripts --exclude encrypted </dev/null
}
jobs_parts='pitchfork|worktree-reap|job-failed'

for machine in "linux tkol" "linux some-box" "darwin agatas-mac"; do
    # shellcheck disable=SC2086 # two words: os hostname
    got="$(managed $machine | grep -E "$jobs_parts" || true)"
    [ -z "$got" ] || fail "$machine gets scheduled jobs: $got"
done

got="$(managed darwin tkol | grep -E "$jobs_parts" | sort)"
want="$(printf '%s\n' .config/mise/conf.d/pitchfork.toml .config/pitchfork-jobs/config.toml \
    .local/bin/job-failed .local/bin/worktree-reap Library/LaunchAgents/co.kirkconsulting.pitchfork.plist load-pitchfork.sh | sort)"
[ "$got" = "$want" ] || fail "tkol's jobs parts differ: got $got"

grep -q '^pitchfork' "$HERE/dot_config/mise/config.toml" && fail "pitchfork is pinned for every machine"

echo "PASS: scheduled jobs install only on Macs that list them (linux, unlisted Mac, tkol)"

#!/bin/bash
# pitchfork-jobs: the launch agent's own command starts a supervisor, in
# launchd's bare environment, that runs cron jobs from the jobs config only.
# macOS only (launchd plist, mise-installed pitchfork).
#
#   ./tests/pitchfork-jobs.sh
set -euo pipefail

[[ "$(uname)" == Darwin ]] || { echo "SKIP: macOS only"; exit 0; }
unset $(git rev-parse --local-env-vars)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The supervisor socket path must fit in 104 bytes.
WORK="$(mktemp -d /tmp/pfjXXXX)"
stop() {
  [ -n "${sup:-}" ] || return 0
  # mise runs pitchfork as a child, so stop the supervisor itself, not mise.
  pf env PITCHFORK_STATE_DIR="$WORK/s1" "${program[0]}" x -- pitchfork supervisor stop >/dev/null 2>&1 || true
  wait "$sup" 2>/dev/null || true
}
trap 'stop; rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
render() { chezmoi execute-template --source "$HERE" < "$HERE/$1"; }

render private_Library/private_LaunchAgents/co.kirkconsulting.pitchfork.plist.tmpl > "$WORK/agent.plist"
plutil -lint -s "$WORK/agent.plist" || fail "plist does not lint"
plist() { plutil -extract "$1" raw -o - "$WORK/agent.plist"; }
program=()
while IFS= read -r arg; do program+=("$arg"); done < <(plutil -extract ProgramArguments json -o - "$WORK/agent.plist" | python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin)))')
# CI installs mise elsewhere; there, run the agent's arguments with that mise.
[ -x "${program[0]}" ] || program[0]="$(command -v mise)" || fail "no mise to run the agent with"
jobs_dir="$(plist EnvironmentVariables.PITCHFORK_CONFIG_DIR)"
[ "$jobs_dir" = "$HOME/.config/pitchfork-jobs" ] || fail "supervisor reads $jobs_dir, not the jobs config"
[ "$(plist WorkingDirectory)" = / ] || fail "supervisor runs from a directory others can plant pitchfork.toml in"

# The shipped jobs config parses, and schedules the reaper on TKOL only.
render dot_config/pitchfork-jobs/config.toml.tmpl > "$WORK/shipped.toml"
mkdir "$WORK/shipped" && cp "$WORK/shipped.toml" "$WORK/shipped/config.toml"
pf() { (cd "$(plist WorkingDirectory)" && env -i HOME="$HOME" PATH="$(plist EnvironmentVariables.PATH)" MISE_GLOBAL_CONFIG_FILE="$WORK/mise.toml" "$@"); }
printf '[tools]\npitchfork = "%s"\n' "$(sed -n 's/^pitchfork = "\(.*\)".*/\1/p' "$HERE/dot_config/mise/config.toml")" > "$WORK/mise.toml"
grep -q '"[0-9]' "$WORK/mise.toml" || fail "pitchfork is not pinned in the global mise config"
daemons="$(pf env PITCHFORK_CONFIG_DIR="$WORK/shipped" PITCHFORK_STATE_DIR="$WORK/s0" "${program[0]}" x -- pitchfork daemons --json)" || fail "jobs config does not parse"
# Each job's schedule, as "<job> <cron>", from the rendered config.
schedules() { awk -F' = ' '/^\[daemons\./{job=substr($1,10,length($1)-10)} /^cron = /{gsub(/"/,"",$2); print job" "$2}' "$WORK/shipped.toml"; }
want=""
if [ "$(chezmoi execute-template '{{ .chezmoi.hostname }}')" = tkol ]; then
  want+="worktree-reap 0 0 4 * * *"$'\n'"backup-exclusions 0 */15 * * * *"$'\n'
fi
if [ -d "$HOME/accounts" ]; then
  want+="accounts-backup-run 0 30 12 * * *"$'\n'"accounts-backup-stale 0 0 18 * * *"$'\n'"accounts-backup-verify 0 0 13 1 * *"$'\n'
fi
want+="network-config-drift 0 30 9 * * *"
[ "$(schedules | sort)" = "$(printf '%s\n' "$want" | sort)" ] || fail "schedules differ: got $(schedules | sort) want $(printf '%s\n' "$want" | sort)"
for job in $(schedules | cut -d' ' -f1); do
  grep -q "\"global/$job\"" <<<"$daemons" || fail "$job is not a daemon pitchfork sees: $daemons"
done

# The agent's exact command, in launchd's environment, fires a job from the
# jobs config — and nothing else.
mkdir "$WORK/jobs"
cat > "$WORK/jobs/config.toml" <<EOF
[daemons.tick]
run = "date +%s >> $WORK/ticks"
cron = "*/2 * * * * *"
EOF
pf env PITCHFORK_CONFIG_DIR="$WORK/jobs" PITCHFORK_STATE_DIR="$WORK/s1" "${program[@]}" > "$WORK/sup.log" 2>&1 &
sup=$!
deadline=$((SECONDS + 40))
until [ -s "$WORK/ticks" ] || [ "$SECONDS" -ge "$deadline" ]; do sleep 0.5; done
[ -s "$WORK/ticks" ] || fail "no cron run within 40s: $(tail -5 "$WORK/sup.log")"
grep -q 'registered config-only cron daemon .*tick' "$WORK/sup.log" || fail "tick not registered: $(cat "$WORK/sup.log")"
! grep -q 'worktree-reap' "$WORK/sup.log" || fail "supervisor picked up jobs outside its config dir"
supervisor="$(pgrep -P "$sup")"
stop; sup=""
! kill -0 "$supervisor" 2>/dev/null || fail "supervisor $supervisor outlived stop"

echo "OK: pitchfork-jobs"

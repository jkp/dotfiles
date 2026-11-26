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
  [ -z "${stray:-}" ] || kill "$stray" 2>/dev/null || true
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
printf '[tools]\npitchfork = "%s"\n' "$(sed -n 's/^pitchfork = "\(.*\)".*/\1/p' "$HERE/dot_config/mise/conf.d/pitchfork.toml")" > "$WORK/mise.toml"
grep -q '"[0-9]' "$WORK/mise.toml" || fail "pitchfork is not pinned in the global mise config"
daemons="$(pf env PITCHFORK_CONFIG_DIR="$WORK/shipped" PITCHFORK_STATE_DIR="$WORK/s0" "${program[0]}" x -- pitchfork daemons --json)" || fail "jobs config does not parse"
# Each job's schedule, as "<job> <cron>", from the rendered config.
schedules() { awk -F' = ' '/^\[daemons\./{job=substr($1,10,length($1)-10)} /^cron = /{gsub(/"/,"",$2); print job" "$2}' "$WORK/shipped.toml"; }
want=""
if [ "$(chezmoi execute-template '{{ .chezmoi.hostname }}')" = tkol ]; then
  want+="worktree-reap 0 0 4 * * *"$'\n'"backup-exclusions 0 */15 * * * *"$'\n'"snapshot-thin 0 */15 * * * *"$'\n'"docker-prune 0 0 5 * * Sun"$'\n'"scratch-check 0 0 6 * * Sun"$'\n'
fi
if [ "$(chezmoi execute-template '{{ .chezmoi.hostname }}')" = tkol ]; then
  [ ! -d "$HOME/accounts" ] || want+="accounts-backup-run 0 30 12 * * *"$'\n'"accounts-backup-stale 0 0 18 * * *"$'\n'"accounts-backup-verify 0 0 13 1 * *"$'\n'
  want+="network-config-drift 0 0 5 * * *"
fi
[ "$(schedules | sort)" = "$(printf '%s' "$want" | sort)" ] || fail "schedules differ: got $(schedules | sort) want $(printf '%s\n' "$want" | sort)"
for job in $(schedules | cut -d' ' -f1); do
  grep -q "\"global/$job\"" <<<"$daemons" || fail "$job is not a daemon pitchfork sees: $daemons"
done
# Where the prune runs, the image-use watcher starts with the supervisor and stays up.
if grep -q '^\[daemons\.docker-prune\]' "$WORK/shipped.toml"; then
  grep -q '"global/docker-image-use"' <<<"$daemons" || fail "no docker-image-use daemon beside docker-prune: $daemons"
  awk '/^\[daemons\.docker-image-use\]/{f=1;next} /^\[/{f=0} f' "$WORK/shipped.toml" > "$WORK/watcher"
  grep -qx 'boot_start = true' "$WORK/watcher" && grep -qx 'retry = true' "$WORK/watcher" && ! grep -q '^cron' "$WORK/watcher" ||
    fail "docker-image-use is not a boot-started, always-retried daemon: $(cat "$WORK/watcher")"
fi
# Every job notifies when it fails.
[ "$(grep -c '^\[daemons\.' "$WORK/shipped.toml")" = "$(grep -c "^hooks = { on_fail = \"$HOME/.local/bin/job-failed\" }$" "$WORK/shipped.toml")" ] ||
  fail "a job has no failure notification: $(cat "$WORK/shipped.toml")"

# The agent's exact command, in launchd's environment, fires a job from the
# jobs config — and nothing else.
mkdir "$WORK/jobs"
cat > "$WORK/jobs/config.toml" <<EOF
[daemons.tick]
run = "date +%s >> $WORK/ticks"
cron = "*/2 * * * * *"

[daemons.broken]
run = "echo working; echo 'Could not remove: wt-a' >&2; exit 7"
cron = "*/2 * * * * *"
hooks = { on_fail = "$HERE/dot_local/bin/executable_job-failed" }
EOF
# Hammerspoon stand-in: records what the failure hook asks it to post.
mkdir "$WORK/stub"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/notified"\n' "$WORK" > "$WORK/stub/hs" && chmod +x "$WORK/stub/hs"
# A stray supervisor (any pitchfork command starts one if none is running, e.g.
# while the loader restarts the agent) must not keep the agent's out: the agent
# would exit 0 and launchd wouldn't restart it, leaving the stray on old config.
mkdir -p "$WORK/empty"; pf env PITCHFORK_CONFIG_DIR="$WORK/empty" PITCHFORK_STATE_DIR="$WORK/s1" "${program[0]}" x -- pitchfork supervisor run > "$WORK/stray.log" 2>&1 &
stray_wrapper=$!
deadline=$((SECONDS + 20))
until stray="$(pgrep -P "$stray_wrapper")" && [ -S "$WORK/s1/ipc/main.sock" ] || [ "$SECONDS" -ge "$deadline" ]; do sleep 0.3; done
[ -n "$stray" ] || fail "the stray supervisor didn't start: $(cat "$WORK/stray.log")"
pf env PATH="$WORK/stub:$(plist EnvironmentVariables.PATH)" PITCHFORK_CONFIG_DIR="$WORK/jobs" PITCHFORK_STATE_DIR="$WORK/s1" "${program[@]}" > "$WORK/sup.log" 2>&1 &
sup=$!
deadline=$((SECONDS + 40))
until [ -s "$WORK/ticks" ] || [ "$SECONDS" -ge "$deadline" ]; do sleep 0.5; done
[ -s "$WORK/ticks" ] || fail "no cron run within 40s: $(tail -5 "$WORK/sup.log")"
until [ -s "$WORK/notified" ] || [ "$SECONDS" -ge "$deadline" ]; do sleep 0.5; done
grep -qF 'Scheduled job failed: broken' "$WORK/notified" 2>/dev/null || fail "a failed run didn't notify: $(tail -5 "$WORK/sup.log")"
grep -qF 'exit 7: Could not remove: wt-a' "$WORK/notified" || fail "notification lacks the job's last line: $(cat "$WORK/notified")"
grep -q 'registered config-only cron daemon .*tick' "$WORK/sup.log" || fail "tick not registered: $(cat "$WORK/sup.log")"
! grep -q 'worktree-reap' "$WORK/sup.log" || fail "supervisor picked up jobs outside its config dir"
supervisor="$(pgrep -P "$sup")"
[ -n "$supervisor" ] || fail "the agent's supervisor gave way to a stray one: $(tail -3 "$WORK/sup.log")"
! kill -0 "$stray" 2>/dev/null || fail "the stray supervisor $stray outlived the agent's start"
stop; sup=""
! kill -0 "$supervisor" 2>/dev/null || fail "supervisor $supervisor outlived stop"

echo "OK: pitchfork-jobs"

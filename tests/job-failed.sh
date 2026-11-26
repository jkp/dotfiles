#!/bin/bash
# job-failed: a scheduled job's on_fail hook posts a notification that names
# the job, its exit code and where its logs are, through Hammerspoon, falling
# back to osascript when Hammerspoon can't post.
#
#   ./tests/job-failed.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$HERE/dot_local/bin/executable_job-failed"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

mkdir "$WORK/bin"
for tool in hs osascript pitchfork; do
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/%s.calls"\n[ ! -f "%s/%s.fails" ]\n' "$WORK" "$tool" "$WORK" "$tool" > "$WORK/bin/$tool"
  chmod +x "$WORK/bin/$tool"
done
hook() { env PATH="$WORK/bin:/usr/bin:/bin" PITCHFORK_DAEMON_ID="$1" PITCHFORK_EXIT_CODE="$2" "$BIN"; }

hook global/backup-exclusions 3 || fail "hook failed"
calls="$(cat "$WORK/hs.calls")"
for want in 'Scheduled job failed: backup-exclusions' 'exit 3' 'pitchfork logs backup-exclusions' 'withdrawAfter=0'; do
  grep -qF "$want" <<<"$calls" || fail "notification lacks '$want': $calls"
done
[ ! -e "$WORK/osascript.calls" ] || fail "fell back although Hammerspoon posted"
echo "PASS: names the job, exit code and logs, and stays until dismissed"

# A job name is config text, but it's spliced into Lua and AppleScript.
: > "$WORK/hs.calls"
hook 'global/x"); os.execute("touch /tmp/pwned' '1; rm' || fail "hook failed on an odd name"
grep -q '[");]' <<<"$(sed 's/hs.notify.new({title="//; s/", informativeText="/ /; s/", withdrawAfter=0}):send()$//' "$WORK/hs.calls")" &&
  fail "quote or code reached the notification: $(cat "$WORK/hs.calls")"
echo "PASS: a hostile job name or exit code can't break out of the notification"

touch "$WORK/hs.fails"
hook global/worktree-reap 1 || fail "hook failed when Hammerspoon couldn't post"
grep -qF 'Scheduled job failed: worktree-reap' "$WORK/osascript.calls" || fail "no osascript fallback: $(cat "$WORK/osascript.calls" 2>/dev/null)"
echo "PASS: falls back to osascript when Hammerspoon can't post"
rm "$WORK/hs.fails"

# The job's last log line says why it failed, in the notification itself.
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/pitchfork.calls"\nprintf "%%s\\n" "$LAST_LINE"\n' "$WORK" > "$WORK/bin/pitchfork"
: > "$WORK/hs.calls"
LAST_LINE='Could not remove: screen-prompt' hook global/worktree-reap 1 || fail "hook failed with a reason"
grep -qF 'logs global/worktree-reap -n 1 --raw --no-timestamp' "$WORK/pitchfork.calls" || fail "didn't read the job's last line: $(cat "$WORK/pitchfork.calls")"
grep -qF 'informativeText="exit 1: Could not remove: screen-prompt"' "$WORK/hs.calls" || fail "reason missing: $(cat "$WORK/hs.calls")"
echo "PASS: names why the job failed"

: > "$WORK/hs.calls"
LAST_LINE='⚠️ bad "quote") os.execute("x") \\' hook global/worktree-reap 1 || fail "hook failed on a hostile log line"
grep -q 'informativeText="[^"\\]*", withdrawAfter=0' "$WORK/hs.calls" || fail "quote or backslash from the log reached the notification: $(cat "$WORK/hs.calls")"
echo "PASS: a hostile log line can't break out of the notification"

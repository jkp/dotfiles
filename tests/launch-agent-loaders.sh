#!/bin/bash
# Launch-agent loaders reload a running agent: launchctl bootout returns before
# the old job has exited, and bootstrap fails (5: Input/output error) until it
# has. Each loader must wait it out rather than leave the agent unloaded.
#
#   ./tests/launch-agent-loaders.sh
set -euo pipefail

[[ "$(uname)" == Darwin ]] || { echo "SKIP: macOS only"; exit 0; }
unset $(git rev-parse --local-env-vars)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

mkdir -p "$WORK/bin" "$WORK/home/.local/bin"
# launchd stand-in: a job stays loaded for three more looks after bootout.
cat > "$WORK/bin/launchctl" <<'STUB'
#!/bin/bash
s="$LAUNCHD_STATE"
case "$1" in
  bootout) [ -e "$s/loaded" ] && echo 3 > "$s/exiting"; exit 0 ;;
  print)
    [ -e "$s/loaded" ] || exit 113
    if [ -e "$s/exiting" ]; then
      n=$(($(cat "$s/exiting") - 1))
      if [ "$n" -le 0 ]; then rm -f "$s/loaded" "$s/exiting"; else echo "$n" > "$s/exiting"; fi
    fi
    exit 0 ;;
  bootstrap)
    if [ -e "$s/loaded" ]; then echo "Bootstrap failed: 5: Input/output error" >&2; exit 5; fi
    touch "$s/loaded"; echo bootstrapped >> "$s/log" ;;
esac
STUB
printf '#!/bin/sh\nexit 0\n' > "$WORK/bin/brew"
printf '#!/bin/sh\nexit 0\n' > "$WORK/home/.local/bin/mise"
chmod +x "$WORK/bin/launchctl" "$WORK/bin/brew" "$WORK/home/.local/bin/mise"

for loader in run_onchange_after_load-colima.sh.tmpl run_onchange_after_load-pitchfork.sh.tmpl; do
  state="$WORK/state-$loader"; mkdir "$state"; touch "$state/loaded"
  chezmoi execute-template --source "$HERE" < "$HERE/$loader" > "$WORK/loader.sh"
  if ! HOME="$WORK/home" LAUNCHD_STATE="$state" PATH="$WORK/bin:/usr/bin:/bin" bash "$WORK/loader.sh" > "$WORK/out" 2>&1; then
    fail "$loader left the agent unloaded: $(cat "$WORK/out")"
  fi
  [ -e "$state/loaded" ] && grep -q bootstrapped "$state/log" || fail "$loader didn't reload the agent: $(cat "$WORK/out")"
done
echo "PASS: loaders wait for the old job to exit before reloading (colima, pitchfork)"

#!/bin/bash
# The macOS window/Spaces settings Codex.spoon relies on are applied on every
# Mac (tkol's values), and the Dock restarts so they take effect.
#
#   ./tests/macos-defaults.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
SCRIPT="$HERE/run_onchange_after_macos-defaults.sh.tmpl"
[[ -f "$SCRIPT" ]] || fail "no $SCRIPT"

render() { # render <os>
    chezmoi --source "$HERE" --config "$WORK/none.toml" execute-template \
        --override-data "{\"chezmoi\":{\"os\":\"$1\"}}" < "$SCRIPT"
}

[[ -z "$(render linux | tr -d '[:space:]')" ]] || fail "renders something on linux"
echo "PASS: nothing on linux"

mkdir -p "$WORK/bin"
printf '#!/bin/bash\necho "defaults $*" >> "%s/calls"\n' "$WORK" > "$WORK/bin/defaults"
printf '#!/bin/bash\necho "killall $*" >> "%s/calls"\n' "$WORK" > "$WORK/bin/killall"
chmod +x "$WORK/bin/"*
render darwin > "$WORK/run.sh"
PATH="$WORK/bin:$PATH" bash "$WORK/run.sh" || fail "script failed"

want=(
    "defaults write com.apple.dock mru-spaces -bool false"
    "defaults write com.apple.dock workspaces-auto-swoosh -bool false"
    "defaults write com.apple.dock expose-group-apps -bool false"
    "defaults write com.apple.spaces spans-displays -bool false"
    "defaults write com.apple.WindowManager GloballyEnabled -bool false"
    "defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false"
    "defaults write com.apple.WindowManager HideDesktop -bool true"
    "defaults write com.apple.WindowManager AutoHide -bool true"
    "defaults write com.apple.WindowManager AppWindowGroupingBehavior -int 0"
)
for w in "${want[@]}"; do grep -qxF "$w" "$WORK/calls" || fail "missing: $w"; done
[[ "$(tail -1 "$WORK/calls")" == "killall Dock" ]] || fail "Dock isn't restarted last: $(cat "$WORK/calls")"
echo "PASS: writes tkol's window and Spaces settings, then restarts the Dock"

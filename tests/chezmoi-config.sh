#!/bin/bash
# .chezmoi.toml.tmpl: macOS gets age encryption (spotify-ctl is encrypted);
# Linux gets none and applies with --exclude=encrypted.
#
#   ./tests/chezmoi-config.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

[[ -f "$HERE/.chezmoi.toml.tmpl" ]] || fail ".chezmoi.toml.tmpl is missing"
render() {
    chezmoi --source "$HERE" --config "$WORK/none.toml" execute-template --init \
        --override-data "{\"chezmoi\":{\"os\":\"$1\"}}" < "$HERE/.chezmoi.toml.tmpl"
}

darwin="$(render darwin)"
grep -qx 'encryption = "age"' <<<"$darwin" || fail "darwin config doesn't set age encryption: $darwin"
grep -qx '[[:space:]]*\[age\]' <<<"$darwin" || fail "darwin config has no [age] table: $darwin"
grep -qx '[[:space:]]*identity = "~/.config/chezmoi/key.txt"' <<<"$darwin" || fail "darwin config has the wrong identity: $darwin"
grep -qx '[[:space:]]*recipient = "age1d2vlx4j2n8lfg589vtacxltl2z5u8s0tg9xvrrcjmvxdsatuvsvqt0wjxq"' <<<"$darwin" ||
    fail "darwin config has the wrong recipient: $darwin"
echo "PASS: darwin config sets age encryption, identity and recipient"

linux="$(render linux)"
grep -qE 'encryption|age' <<<"$linux" && fail "linux config mentions encryption: $linux"
echo "PASS: linux config has no encryption"

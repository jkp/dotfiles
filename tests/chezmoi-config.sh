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

# kanata.mode: explicit KANATA_MODE wins, then stored data, then "always" for a
# machine that already has the always-on daemon (tkol), else prompt (TTY, default always) or,
# with no terminal to choose in, the safe "active-user".
# chezmoi 2.68 simulates stdinIsATTY from --stdinisatty while 2.73 reads the
# real stdin, so set both: script's pty or /dev/null, plus the matching flag.
mode() { # mode <expected> tty|notty [env...] -- [execute-template args...]
    local want="$1" how="$2" got; shift 2
    local envs=(); while [[ "$1" != -- ]]; do envs+=("$1"); shift; done; shift
    local cmd=(env ${envs[@]+"${envs[@]}"} chezmoi --source "$HERE" execute-template --init
        --override-data '{"chezmoi":{"os":"darwin"},"kanataPlist":"'"$WORK"'/no.plist"}' "$@"
        --stdinisatty="$([[ "$how" == tty ]] && echo true || echo false)" "$(cat "$HERE/.chezmoi.toml.tmpl")")
    [[ "$how" == tty ]] && cmd=(script -q /dev/null "${cmd[@]}")
    got="$("${cmd[@]}" < /dev/null | tr -d '\r')" || fail "render failed for $want: $got"
    grep -qx "[[:space:]]*mode = \"$want\"" <<<"$got" || fail "expected kanata mode $want ($how), got: $got"
}
mode active-user notty -- --config "$WORK/none.toml"
echo "PASS: kanata mode defaults to active-user without a TTY"
mode always tty -- --config "$WORK/none.toml"
echo "PASS: the kanata mode prompt defaults to always"
mode active-user tty -- --config "$WORK/none.toml" --promptChoice "Kanata mode=active-user"
echo "PASS: kanata mode is prompted for with a TTY"
mode active-user notty KANATA_MODE=active-user -- --config "$WORK/none.toml"
echo "PASS: KANATA_MODE sets the mode without a TTY"
printf '[data.kanata]\n    mode = "off"\n' > "$WORK/off.toml"
mode off tty -- --config "$WORK/off.toml"
printf '[data.kanata]\n    mode = "always"\n' > "$WORK/always.toml"
mode always notty -- --config "$WORK/always.toml"
echo "PASS: a stored kanata mode is kept without prompting"
mode active-user tty KANATA_MODE=active-user -- --config "$WORK/off.toml"
echo "PASS: KANATA_MODE overrides a stored mode"
touch "$WORK/no.plist"
mode always tty -- --config "$WORK/none.toml"
mode always notty -- --config "$WORK/none.toml"
echo "PASS: an existing always-on daemon means always, without prompting"
KANATA_MODE=bogus chezmoi --source "$HERE" --config "$WORK/none.toml" execute-template --init \
    --override-data '{"chezmoi":{"os":"darwin"}}' < "$HERE/.chezmoi.toml.tmpl" >/dev/null 2>&1 &&
    fail "an unknown kanata mode rendered"
echo "PASS: an unknown kanata mode fails"
grep -q kanata <<<"$linux" && fail "linux config sets a kanata mode: $linux"
echo "PASS: linux config has no kanata mode"

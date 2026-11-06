#!/bin/bash
# bootstrap.sh on macOS: installs the 1Password CLI and checks it's signed in
# before chezmoi init, so run_before_00-fetch-age-key can fetch the age key.
# Every external tool (uname, brew, op, mise, chezmoi, curl) is a stub.
#
#   ./tests/bootstrap-1password.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

stub() { printf '#!/bin/bash\n%s\n' "$2" > "$WORK/bin/$1"; chmod +x "$WORK/bin/$1"; }
# op stub: signed in when $WORK/signed-in exists.
OP_STUB='echo "op $*" >> "$LOG"; [[ "$1" == whoami ]] && { [[ -e "$SIGNED_IN" ]] || exit 1; }; exit 0'

# setup [op-signed-in|op-signed-out|no-op] [key]: fresh HOME and stubs
setup() {
    rm -rf "$WORK/bin" "$WORK/home" "$WORK/log" "$WORK/signed-in"
    mkdir -p "$WORK/bin" "$WORK/home/.local/bin"
    : > "$WORK/log"
    stub uname 'echo Darwin'
    stub curl 'echo "curl $*" >> "$LOG"; exit 1'
    stub chezmoi 'echo "chezmoi $*" >> "$LOG"; mkdir -p "$HOME/.local/share/chezmoi"'
    # A brew-installed op comes from 1Password's own installer: signed in via the app.
    stub brew "echo \"brew \$*\" >> \"\$LOG\"
[[ \"\$*\" == 'install --cask 1password-cli' ]] && { printf '#!/bin/bash\n%s\n' '$OP_STUB' > \"$WORK/bin/op\"; chmod +x \"$WORK/bin/op\"; touch \"\$SIGNED_IN\"; }
exit 0"
    printf '#!/bin/bash\necho "mise $*" >> "$LOG"\n' > "$WORK/home/.local/bin/mise"
    chmod +x "$WORK/home/.local/bin/mise"
    cp "$WORK/home/.local/bin/mise" "$WORK/bin/mise"
    case "$1" in
        op-signed-in) stub op "$OP_STUB"; touch "$WORK/signed-in" ;;
        op-signed-out) stub op "$OP_STUB" ;;
    esac
    if [[ "${2:-}" == key ]]; then
        mkdir -p "$WORK/home/.config/chezmoi"
        echo existing-identity > "$WORK/home/.config/chezmoi/key.txt"
    fi
}

# bootstrap: runs bootstrap.sh non-interactively; status in $rc, output in $WORK/out
bootstrap() {
    rc=0
    env -i HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" LOG="$WORK/log" \
        SIGNED_IN="$WORK/signed-in" BOOTSTRAP_TEST=1 \
        bash "$HERE/bootstrap.sh" --full < /dev/null > "$WORK/out" 2>&1 || rc=$?
}
logged() { grep -qx "$1" "$WORK/log"; }

setup no-op; bootstrap
[[ $rc -eq 0 ]] || fail "bootstrap failed with op missing: $(cat "$WORK/out")"
logged 'brew install --cask 1password-cli' || fail "didn't install 1password-cli: $(cat "$WORK/log")"
logged 'chezmoi init --apply jkp' || fail "didn't run chezmoi init: $(cat "$WORK/log")"
grep -n -x -e 'brew install --cask 1password-cli' -e 'chezmoi init --apply jkp' "$WORK/log" | head -1 |
    grep -q brew || fail "installed 1password-cli after chezmoi init"
echo "PASS: installs the 1Password CLI before chezmoi init"

setup op-signed-in; bootstrap
[[ $rc -eq 0 ]] || fail "bootstrap failed with op signed in: $(cat "$WORK/out")"
logged 'brew install --cask 1password-cli' && fail "reinstalled 1password-cli"
logged 'op whoami' || fail "didn't check op is signed in"
logged 'chezmoi init --apply jkp' || fail "didn't run chezmoi init: $(cat "$WORK/log")"
echo "PASS: a signed-in op goes straight to chezmoi init"

setup op-signed-out; bootstrap
[[ $rc -ne 0 ]] || fail "a signed-out op in non-interactive mode should fail"
grep -q 1Password "$WORK/out" || fail "the error doesn't mention 1Password: $(cat "$WORK/out")"
grep -q '^chezmoi' "$WORK/log" && fail "ran chezmoi anyway: $(cat "$WORK/log")"
grep -q '^op signin' "$WORK/log" && fail "prompted op signin without a terminal"
echo "PASS: a signed-out op fails before chezmoi, without prompting"

setup no-op key; bootstrap
[[ $rc -eq 0 ]] || fail "bootstrap failed with the key already present: $(cat "$WORK/out")"
logged 'brew install --cask 1password-cli' && fail "installed 1password-cli though the key exists"
echo "PASS: an existing age key needs no 1Password"

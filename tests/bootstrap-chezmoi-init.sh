#!/bin/bash
# A source repo left by an earlier failed run, but no chezmoi.toml: every
# apply path regenerates the config from .chezmoi.toml.tmpl, so age-encrypted
# files decrypt. Uses the real chezmoi and /usr/bin/git; uname, brew, mise, op
# are stubs.
#
#   ./tests/bootstrap-chezmoi-init.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

CHEZMOI="$(command -v chezmoi)" || fail "chezmoi isn't installed"
stub() { printf '#!/bin/bash\n%s\n' "$2" > "$WORK/bin/$1"; chmod +x "$WORK/bin/$1"; }
in_home() {
    env -i HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" GIT_CONFIG_GLOBAL=/dev/null \
        GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t "$@"
}

# setup: a pushed source repo with an age-encrypted ~/.secret, the age key in
# place, and no chezmoi.toml.
setup() {
    rm -rf "$WORK/bin" "$WORK/home" "$WORK/origin.git"
    mkdir -p "$WORK/bin" "$WORK/home/.local/bin" "$WORK/home/.config/chezmoi"
    ln -s "$CHEZMOI" "$WORK/bin/chezmoi"
    stub uname 'echo Darwin'
    stub brew 'exit 0'
    stub op 'exit 1'
    stub mise 'exit 0'
    cp "$WORK/bin/mise" "$WORK/home/.local/bin/mise"

    local key="$WORK/home/.config/chezmoi/key.txt" src="$WORK/home/.local/share/chezmoi"
    in_home chezmoi age-keygen --output "$key" 2>/dev/null
    local recipient; recipient="$(in_home chezmoi age-keygen --convert "$key")"
    in_home git init -q --bare "$WORK/origin.git"
    in_home git clone -q "$WORK/origin.git" "$src" 2>/dev/null
    printf 'encryption = "age"\n[age]\n    recipient = "%s"\n    identity = "~/.config/chezmoi/key.txt"\n' \
        "$recipient" > "$src/.chezmoi.toml.tmpl"
    printf 'encryption = "age"\n[age]\n    recipient = "%s"\n' "$recipient" > "$WORK/encrypt.toml"
    echo decrypted > "$WORK/plain"
    in_home chezmoi --config "$WORK/encrypt.toml" encrypt "$WORK/plain" > "$src/encrypted_dot_secret.age"
    in_home git -C "$src" add -A
    in_home git -C "$src" commit -q -m init
    in_home git -C "$src" push -q -u origin HEAD 2>/dev/null
}

# check <label>: the config was generated and ~/.secret decrypted
check() {
    [[ $rc -eq 0 ]] || fail "$1 failed: $(cat "$WORK/out")"
    grep -q 'encryption = "age"' "$WORK/home/.config/chezmoi/chezmoi.toml" 2>/dev/null ||
        fail "$1 didn't generate chezmoi.toml: $(cat "$WORK/out")"
    [[ "$(cat "$WORK/home/.secret" 2>/dev/null)" == decrypted ]] || fail "$1 didn't decrypt ~/.secret: $(cat "$WORK/out")"
    grep -q 'config file template has changed' "$WORK/out" && fail "$1 warned the config is stale: $(cat "$WORK/out")"
    echo "PASS: $1 generates the config and decrypts encrypted files"
}

setup; rc=0
in_home BOOTSTRAP_TEST=1 bash "$HERE/bootstrap.sh" < /dev/null > "$WORK/out" 2>&1 || rc=$?
check "bootstrap.sh with an existing source repo (chezmoi update)"

setup; rc=0
in_home BOOTSTRAP_TEST=1 DOTFILES_SOURCE="$WORK/home/.local/share/chezmoi" \
    bash "$HERE/bootstrap.sh" < /dev/null > "$WORK/out" 2>&1 || rc=$?
check "bootstrap.sh with an existing source repo and DOTFILES_SOURCE (chezmoi apply)"

setup; rc=0
task="$(cd "$HERE" && mise tasks info chezmoi-apply --json | jq -r '.run[0]')"
in_home bash -c "$task" < /dev/null > "$WORK/out" 2>&1 || rc=$?
check "the mise chezmoi-apply task"

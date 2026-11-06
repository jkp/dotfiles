#!/bin/bash
# bootstrap.sh hands mise a GitHub token (gh's, else 1Password's) so vfox
# plugins don't hit GitHub's unauthenticated rate limit, and warns without one.
# Every external tool (uname, brew, gh, op, mise, chezmoi, curl) is a stub.
#
#   ./tests/bootstrap-github-token.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

stub() { printf '#!/bin/bash\n%s\n' "$2" > "$WORK/bin/$1"; chmod +x "$WORK/bin/$1"; }

# setup [gh-in|gh-out|no-gh] [op-in|op-out]: fresh HOME (age key present) and stubs
setup() {
    rm -rf "$WORK/bin" "$WORK/home"
    mkdir -p "$WORK/bin" "$WORK/home/.local/bin" "$WORK/home/.config/chezmoi"
    echo existing-identity > "$WORK/home/.config/chezmoi/key.txt"
    : > "$WORK/log"
    stub uname 'echo Darwin'
    stub curl 'exit 1'
    stub brew 'echo "brew $*" >> "$LOG"'
    stub chezmoi 'mkdir -p "$HOME/.local/share/chezmoi"'
    stub mise 'echo "mise $* MISE_GITHUB_TOKEN=${MISE_GITHUB_TOKEN:-}" >> "$LOG"'
    cp "$WORK/bin/mise" "$WORK/home/.local/bin/mise"
    case "$1" in
        gh-in) stub gh 'echo "gh $*" >> "$LOG"; [[ "$*" == "auth token" ]] && echo gh-secret; exit 0' ;;
        gh-out) stub gh 'echo "gh $*" >> "$LOG"; exit 1' ;;
    esac
    case "$2" in
        op-in) stub op 'echo "op $*" >> "$LOG"; [[ "$*" == "read op://Private/github-token/credential" ]] && echo op-secret; exit 0' ;;
        op-out) stub op 'echo "op $*" >> "$LOG"; exit 1' ;;
    esac
}

# bootstrap [VAR=value...]: runs bootstrap.sh without a terminal; it must succeed
bootstrap() {
    rc=0
    env -i HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" LOG="$WORK/log" BOOTSTRAP_TEST=1 "$@" \
        bash "$HERE/bootstrap.sh" < /dev/null > "$WORK/out" 2>&1 || rc=$?
    [[ $rc -eq 0 ]] || fail "bootstrap failed: $(cat "$WORK/out")"
    grep -q secret "$WORK/out" && fail "printed the token: $(cat "$WORK/out")"
    return 0
}
mise_token() { grep -q "^mise run bootstrap MISE_GITHUB_TOKEN=$1\$" "$WORK/log" || fail "mise didn't get token '$1': $(cat "$WORK/log")"; }

setup gh-in op-in; bootstrap
mise_token gh-secret
grep -q '^op read' "$WORK/log" && fail "read 1Password though gh has a token"
echo "PASS: a logged-in gh's token goes to mise"

setup gh-out op-in; bootstrap
mise_token op-secret
grep -q '^gh auth login' "$WORK/log" && fail "ran gh auth login without a terminal"
echo "PASS: without a gh login, 1Password's token goes to mise"

setup no-gh op-out; bootstrap
grep -qx 'brew install gh' "$WORK/log" || fail "didn't install gh: $(cat "$WORK/log")"
mise_token ''
grep -q 'rate limit' "$WORK/out" || fail "no rate-limit warning: $(cat "$WORK/out")"
echo "PASS: with no token anywhere, warns about GitHub rate limits and carries on"

setup gh-in op-in; bootstrap GITHUB_TOKEN=env-secret
mise_token env-secret
grep -q '^gh auth token' "$WORK/log" && fail "asked gh though GITHUB_TOKEN is set"
echo "PASS: an existing GITHUB_TOKEN goes to mise as is"

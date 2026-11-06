#!/bin/bash
# run_before_00-fetch-age-key: fetches the age key from 1Password, and fails
# loudly when it can't, so the user never sees chezmoi's decrypt error.
# `op` is a stub; the real one is never called.
#
#   ./tests/fetch-age-key.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

chezmoi --source "$HERE" --config "$WORK/none.toml" execute-template \
    --override-data '{"chezmoi":{"os":"darwin"}}' \
    < "$HERE/run_before_00-fetch-age-key.sh.tmpl" > "$WORK/fetch.sh"

KEY="$WORK/home/.config/chezmoi/key.txt"
# op stub: `op read` prints $OP_KEY, or fails when it's unset.
mkdir -p "$WORK/op-bin"
cat > "$WORK/op-bin/op" <<'SH'
#!/bin/sh
[ "$1" = read ] && [ -n "${OP_KEY:-}" ] && { echo "$OP_KEY"; exit 0; }
echo "op stub: not signed in" >&2; exit 1
SH
chmod +x "$WORK/op-bin/op"

# run <with-op|without-op> [VAR=value...]: status in $rc, stderr in $WORK/err
run() {
    local path=/usr/bin:/bin
    [[ "$1" == with-op ]] && path="$WORK/op-bin:$path"
    shift
    rc=0
    env -i HOME="$WORK/home" PATH="$path" "$@" sh "$WORK/fetch.sh" 2>"$WORK/err" || rc=$?
}
reset() { rm -rf "$WORK/home"; }

reset; run without-op
[[ $rc -ne 0 ]] || fail "no key and no op should fail, not skip quietly"
grep -q 1Password "$WORK/err" || fail "the error doesn't mention 1Password: $(cat "$WORK/err")"
[[ ! -e "$KEY" ]] || fail "left a key file behind"
echo "PASS: no key and no op fails loudly"

reset; run with-op
[[ $rc -ne 0 ]] || fail "no key and a signed-out op should fail"
grep -q 1Password "$WORK/err" || fail "the error doesn't mention 1Password: $(cat "$WORK/err")"
[[ ! -e "$KEY" ]] || fail "left an empty key file behind"
echo "PASS: no key and a signed-out op fails loudly"

reset; run with-op OP_KEY=fake-age-identity
[[ $rc -eq 0 ]] || fail "op read worked but the script failed: $(cat "$WORK/err")"
[[ "$(cat "$KEY")" == fake-age-identity ]] || fail "key file doesn't hold what op read"
[[ "$(stat -f %Lp "$KEY" 2>/dev/null || stat -c %a "$KEY")" == 600 ]] || fail "key file isn't mode 600"
echo "PASS: fetches the key with op, mode 600"

reset; mkdir -p "$(dirname "$KEY")"; echo old-identity > "$KEY"; touch -t 202001010000 "$KEY"
run with-op
[[ $rc -eq 0 ]] || fail "a stale key with op signed out should still apply: $(cat "$WORK/err")"
[[ "$(cat "$KEY")" == old-identity ]] || fail "a failed refresh clobbered the existing key"
echo "PASS: a failed refresh keeps the existing key"

reset; run without-op CHEZMOI_ARGS="chezmoi init --apply jkp --exclude=encrypted"
[[ $rc -eq 0 ]] || fail "--exclude=encrypted needs no key, but the script failed: $(cat "$WORK/err")"
echo "PASS: --exclude=encrypted skips the fetch"

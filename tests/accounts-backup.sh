#!/bin/bash
# accounts-backup: restic backup of ~/accounts to R2, its secrets fetch and its
# LaunchAgents. restic, curl and op are stubs; nothing touches the network.
#
#   ./tests/accounts-backup.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
pass() { echo "PASS: $*"; }

SCRIPT="$HERE/dot_local/bin/executable_accounts-backup"
mkdir -p "$WORK/bin"

# restic stub: logs each call; FAKE_CONFIG = ok | missing | broken, FAKE_FAIL = a subcommand to fail.
cat > "$WORK/bin/restic" <<'EOF'
#!/bin/bash
echo "restic $*" >> "$FAKE_LOG"
case "$1" in
  cat)
    case "${FAKE_CONFIG:-ok}" in
      ok) exit 0 ;;
      missing) echo "Fatal: repository does not exist: unable to open config file: Stat: The specified key does not exist." >&2; exit 10 ;;
      broken) echo "Fatal: unable to open config file: Access Denied." >&2; exit 1 ;;
    esac ;;
  env) echo "pw=$RESTIC_PASSWORD_FILE key=$AWS_ACCESS_KEY_ID repo=$RESTIC_REPOSITORY" ;;
esac
[[ "$1" == "${FAKE_FAIL:-}" ]] && { echo "Fatal: $1 broke" >&2; exit 1; }
exit 0
EOF
# curl stub: records the alert body.
cat > "$WORK/bin/curl" <<'EOF'
#!/bin/bash
while (($#)); do [[ "$1" == -d ]] && { echo "$2" >> "$FAKE_ALERTS"; shift; }; shift; done
EOF
chmod +x "$WORK/bin/restic" "$WORK/bin/curl"

# A fresh world per case: source dir, state with secrets, empty logs.
setup() {
  T="$WORK/case.$1"; rm -rf "$T"; mkdir -p "$T/src" "$T/state"
  printf 'RESTIC_REPOSITORY=s3:https://acct.r2.cloudflarestorage.com/accounts-backup\nAWS_ACCESS_KEY_ID=kid\nAWS_SECRET_ACCESS_KEY=sk\n' > "$T/state/env"
  echo pw > "$T/state/password"
  : > "$T/log"; : > "$T/alerts"
}
backup() {
  PATH="$WORK/bin:/usr/bin:/bin" FAKE_LOG="$T/log" FAKE_ALERTS="$T/alerts" \
    ACCOUNTS_BACKUP_SRC="$T/src" ACCOUNTS_BACKUP_STATE="$T/state" ACCOUNTS_BACKUP_NTFY=https://ntfy.invalid/t \
    bash "$SCRIPT" "$@" > "$T/out" 2> "$T/err"
}
alerted() { grep -q "$1" "$T/alerts" || fail "expected an alert matching '$1', got: $(cat "$T/alerts")"; }
quiet() { [[ ! -s "$T/alerts" ]] || fail "unexpected alert: $(cat "$T/alerts")"; }

setup first; FAKE_CONFIG=missing backup run || fail "first run failed: $(cat "$T/err")"
grep -q '^restic init' "$T/log" || fail "empty repository not initialised"
grep -q "^restic backup .*--exclude .env .*--exclude xero-tokens.json .*$T/src\$" "$T/log" || fail "backup call wrong: $(cat "$T/log")"
grep -q -- '--retry-lock' "$T/log" || fail "backup doesn't wait out a lock"
grep -Eq '^restic (forget|prune)' "$T/log" && fail "snapshots must never be pruned"
[[ -e "$T/state/last-success" ]] || fail "success not recorded"
quiet; pass "an empty repository is initialised, then backed up with secrets excluded"

setup again; FAKE_CONFIG=ok backup run || fail "run failed"
grep -q '^restic init' "$T/log" && fail "existing repository re-initialised"
quiet; pass "an existing repository is backed up without re-init"

setup broken; FAKE_CONFIG=broken backup run && fail "a repository error should fail the run"
grep -q '^restic init' "$T/log" && fail "init attempted on an error that isn't 'missing'"
alerted "Access Denied"; pass "a repository error alerts and never triggers init"

setup failing; FAKE_FAIL=backup backup run && fail "a failed backup should fail the run"
[[ -e "$T/state/last-success" ]] && fail "failed backup recorded as success"
alerted "restic backup failed"; pass "a failed backup alerts and isn't recorded as a success"

setup nosrc; rmdir "$T/src"; backup run && fail "a missing source should fail"
grep -q '^restic backup' "$T/log" && fail "backed up despite a missing source (restic would skip it silently)"
alerted "backup path is missing"; pass "a missing ~/accounts alerts instead of backing up nothing"

setup nosecrets; rm "$T/state/password"; backup run && fail "missing secrets should fail"
[[ -s "$T/log" ]] && fail "restic called without secrets"
alerted "chezmoi apply"; pass "missing secrets alert with the fix"

setup nourl; rm "$T/state/password"
PATH="$WORK/bin:/usr/bin:/bin" FAKE_LOG="$T/log" FAKE_ALERTS="$T/alerts" HOME="$T" \
  ACCOUNTS_BACKUP_SRC="$T/src" ACCOUNTS_BACKUP_STATE="$T/state" bash "$SCRIPT" run 2> "$T/err" && fail "should fail"
grep -q "no alert URL configured" "$T/err" || fail "missing alert URL not reported: $(cat "$T/err")"
quiet; pass "without an alert URL, the failure is still logged"

setup stale; backup stale && fail "no recorded success should be stale"
alerted "no successful backup"
setup fresh; touch "$T/state/last-success"; backup stale || fail "a fresh backup reported stale"
quiet
setup old; touch -t 202001010000 "$T/state/last-success"; backup stale && fail "an old backup should be stale"
alerted "over 72h old"; pass "stale check: none and old alert, fresh is quiet"

setup verify; backup verify || fail "verify failed"
grep -q '^restic check .*--read-data' "$T/log" || fail "verify doesn't read the data"
quiet; pass "verify reads every pack"

setup passthrough; backup restic env || fail "passthrough failed"
grep -q "pw=$T/state/password key=kid repo=s3:" "$T/out" || fail "passthrough env wrong: $(cat "$T/out")"
pass "'accounts-backup restic …' runs restic with the backup's credentials"

# --- chezmoi: managed only where ~/accounts exists; secrets fetched from 1Password.
[[ "$(uname)" == Darwin ]] || { echo "SKIP: LaunchAgents are macOS-only"; exit 0; }
CHEZMOI="$(command -v chezmoi)"
cz() { "$CHEZMOI" --source "$HERE" --destination "$1" --config "$WORK/none.toml" "${@:2}"; }

mkdir -p "$WORK/with/accounts" "$WORK/without"
with="$(cz "$WORK/with" managed --include=files,scripts --exclude=encrypted)"
for f in .local/bin/accounts-backup Library/LaunchAgents/co.kirkconsulting.accounts-backup-{run,stale,verify}.plist; do
  grep -qx "$f" <<<"$with" || fail "with an accounts folder, $f isn't managed"
done
grep -q accounts-backup-secrets <<<"$with" || fail "no secrets script"
grep -q load-accounts-backup <<<"$with" || fail "no loader script"
cz "$WORK/with" cat "$WORK/with/Library/LaunchAgents/co.kirkconsulting.accounts-backup-run.plist" |
  grep -q "<string>$WORK/with/.local/bin/accounts-backup</string>" || fail "run agent doesn't run the script"
without="$(cz "$WORK/without" managed --include=files,scripts --exclude=encrypted)"
grep -q accounts-backup <<<"$without" && fail "no ~/accounts, but backup files are managed: $without"
pass "managed only where ~/accounts exists"

# op stub: answers op://Private/accounts-backup/<field>; FAKE_OP=fail makes it fail.
cat > "$WORK/bin/op" <<'EOF'
#!/bin/bash
echo "op $*" >> "$FAKE_LOG"
[[ "${FAKE_OP:-}" == fail ]] && { echo "not signed in" >&2; exit 1; }
case "${@: -1}" in
  op://Private/accounts-backup/password) printf '%s' 'p@ss $word"x' ;;
  op://Private/accounts-backup/r2_access_key_id) echo kid ;;
  op://Private/accounts-backup/r2_secret_access_key) echo sk ;;
  op://Private/accounts-backup/r2_endpoint) echo https://acct.r2.cloudflarestorage.com ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$WORK/bin/op"
SECRETS="$WORK/secrets.sh"
cz "$WORK/with" execute-template < "$HERE/run_after_accounts-backup-secrets.sh.tmpl" > "$SECRETS"
secrets() { HOME="$WORK/with" PATH="$WORK/bin:/usr/bin:/bin" FAKE_LOG="$WORK/oplog" bash "$SECRETS" > "$WORK/sout" 2> "$WORK/serr"; }
S="$WORK/with/.local/state/accounts-backup"

: > "$WORK/oplog"; FAKE_OP=fail secrets || fail "an op failure must not fail chezmoi apply"
grep -q "couldn't read" "$WORK/serr" || fail "op failure not explained: $(cat "$WORK/serr")"
[[ -e "$S/env" || -e "$S/password" ]] && fail "partial secrets left behind"
pass "if 1Password can't be read, apply warns and leaves nothing half-written"

secrets || fail "secrets fetch failed: $(cat "$WORK/serr")"
# shellcheck disable=SC2016  # a literal $ on purpose: the password must survive unexpanded
[[ "$(cat "$S/password")" == 'p@ss $word"x' ]] || fail "password not byte-exact"
grep -qx 'RESTIC_REPOSITORY=s3:https://acct.r2.cloudflarestorage.com/accounts-backup' "$S/env" || fail "repository wrong: $(cat "$S/env")"
grep -qx 'AWS_ACCESS_KEY_ID=kid' "$S/env" || fail "R2 key ID missing"
grep -qx 'AWS_SECRET_ACCESS_KEY=sk' "$S/env" || fail "R2 secret missing"
[[ "$(stat -f %Lp "$S/env") $(stat -f %Lp "$S/password") $(stat -f %Lp "$S")" == "600 600 700" ]] || fail "secrets not private"
pass "secrets land byte-exact, owner-only"

: > "$WORK/oplog"; secrets || fail "second fetch failed"
[[ -s "$WORK/oplog" ]] && fail "secrets re-fetched although present (Touch ID on every apply)"
pass "present secrets aren't fetched again"

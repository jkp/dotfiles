#!/bin/bash
# bootstrap.sh through the mise bootstrap tasks (real mise, this repo's
# mise.toml): a failing step fails the bootstrap, and fish-default runs after
# brew-core has installed fish, warning rather than hanging when it can't set
# it. uname, brew, chezmoi, uv, sudo, chsh and ~/.local/bin/mise are stubs.
#
#   ./tests/bootstrap-tasks.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; echo "--- output"; cat "$WORK/out"; echo "--- log"; cat "$WORK/log"; exit 1; }

MISE="$(command -v mise)" || { echo "FAIL: mise isn't installed"; exit 1; }
stub() { printf '#!/bin/bash\n%s\n' "$2" > "$WORK/bin/$1"; chmod +x "$WORK/bin/$1"; }

# setup [brew-core-fails|brew-personal-fails]: fresh HOME and stubs. brew
# installs fish (as Brewfile.core does), so fish exists only once brew-core
# has run.
setup() {
    rm -rf "$WORK/bin" "$WORK/home"
    mkdir -p "$WORK/bin" "$WORK/home/.local/bin" "$WORK/home/.local/share" "$WORK/home/.config/chezmoi"
    ln -s "$HERE" "$WORK/home/.local/share/chezmoi"
    echo existing-identity > "$WORK/home/.config/chezmoi/key.txt"
    : > "$WORK/log"
    ln -s "$MISE" "$WORK/bin/mise"
    stub uname 'echo Darwin'
    stub chezmoi 'echo "chezmoi $*" >> "$LOG"'
    stub uv 'echo "uv $*" >> "$LOG"'
    stub chsh 'echo "chsh $*" >> "$LOG"'
    # sudo -n true succeeds when $SUDO_CACHED is set; otherwise sudo runs the command.
    stub sudo 'echo "sudo $*" >> "$LOG"
if [[ "$1" == -n ]]; then [[ -n "${SUDO_CACHED:-}" ]]; exit; fi
exec "$@"'
    stub tee 'cat > /dev/null'
    local core=':' personal='exit 0'
    [[ "${1:-}" == brew-core-fails ]] && core='echo "Error: fish failed to build" >&2; exit 1'
    [[ "${1:-}" == brew-personal-fails ]] && personal='echo "Error: z3 failed to build" >&2; exit 1'
    stub brew "echo \"brew \$*\" >> \"\$LOG\"
case \"\$*\" in
    *Brewfile.core*) $core; sleep 1; printf '#!/bin/bash\n' > \"$WORK/bin/fish\"; chmod +x \"$WORK/bin/fish\" ;;
    *Brewfile.personal*) $personal ;;
esac"
    # bootstrap.sh puts ~/.local/bin first: only mise run reaches the real mise.
    printf '#!/bin/bash\necho "mise $*" >> "$LOG"\n[[ "$1" == run ]] && exec "%s" "$@"\nexit 0\n' \
        "$MISE" > "$WORK/home/.local/bin/mise"
    chmod +x "$WORK/home/.local/bin/mise"
}

# bootstrap [args...]: bootstrap.sh without a controlling terminal (setsid),
# so sudo can't prompt. Exit status in $status, output in $WORK/out.
bootstrap() {
    status=0
    env -i HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" USER=tester SHELL=/bin/bash \
        LOG="$WORK/log" SUDO_CACHED="${SUDO_CACHED:-}" BOOTSTRAP_TEST=1 \
        MISE_TRUSTED_CONFIG_PATHS="$HERE" MISE_CEILING_PATHS="$(dirname "$HERE")" \
        MISE_TASK_RUN_AUTO_INSTALL=false MISE_YES=1 \
        perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV or die' -- \
        bash "$HERE/bootstrap.sh" "$@" < /dev/null > "$WORK/out" 2>&1 || status=$?
}

# --- a failing brew-personal fails the bootstrap
setup brew-personal-fails
bootstrap --full
[[ "$status" -ne 0 ]] || fail "bootstrap --full exited 0 though brew-personal failed"
grep -q '❌' "$WORK/out" || fail "no clear failure message"
grep -q '✅ Bootstrap complete' "$WORK/out" && fail "reported success though brew-personal failed"

# --- a failing dependency of the bootstrap task fails the bootstrap
setup brew-core-fails
bootstrap
[[ "$status" -ne 0 ]] || fail "bootstrap exited 0 though brew-core failed"
grep -q '❌' "$WORK/out" || fail "no clear failure message"
grep -q '✅ Bootstrap complete' "$WORK/out" && fail "reported success though brew-core failed"

# --- --full installs personal packages and ansible
setup
bootstrap --full
[[ "$status" -eq 0 ]] || fail "bootstrap --full failed"
grep -q 'Brewfile.personal' "$WORK/log" || fail "brew-personal didn't run"
grep -q '^uv tool install.* ansible' "$WORK/log" || fail "ansible wasn't installed with uv"
grep -q '✅ Bootstrap complete' "$WORK/out" || fail "no success message"

# --- without --full: succeeds, skips personal packages and ansible
setup
bootstrap
[[ "$status" -eq 0 ]] || fail "bootstrap (no --full) failed"
grep -q 'Brewfile.personal' "$WORK/log" && fail "brew-personal ran without --full"
grep -q '^uv ' "$WORK/log" && fail "ansible was installed without --full"
grep -q '✅ Bootstrap complete' "$WORK/out" || fail "no success message"

# --- fish-default waits for brew-core's fish; no terminal but sudo cached: chsh
setup
SUDO_CACHED=1 bootstrap
[[ "$status" -eq 0 ]] || fail "bootstrap failed"
grep -q "^chsh -s $WORK/bin/fish tester" "$WORK/log" || fail "fish wasn't set as the default shell"

# --- no terminal and sudo needs a password: print the commands, don't run sudo
setup
bootstrap
[[ "$status" -eq 0 ]] || fail "bootstrap failed"
grep -q '^chsh' "$WORK/log" && fail "ran chsh with no way to prompt for a password"
grep -q "sudo chsh -s $WORK/bin/fish tester" "$WORK/out" || fail "didn't print the chsh command"
grep -q "sudo tee -a /etc/shells" "$WORK/out" || fail "didn't print the /etc/shells command"

# --- fish missing after brew-core: warn
setup
stub brew 'echo "brew $*" >> "$LOG"'
bootstrap
[[ "$status" -eq 0 ]] || fail "bootstrap failed"
grep -q '⚠️.*fish' "$WORK/out" || fail "no warning that fish is missing"

echo "PASS: bootstrap tasks"

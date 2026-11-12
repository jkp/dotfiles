#!/bin/bash
# .chezmoiremove: dropped configs are deleted on apply, nothing else is touched,
# a second apply is a no-op, and no entry is also a managed target.
#
# chezmoi itself only rejects a managed+removed path ("inconsistent state") on
# machines where it already exists, so the overlap check runs here for every OS.
#
#   ./tests/chezmoiremove.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

[[ -f "$HERE/.chezmoiremove" ]] || fail ".chezmoiremove is missing"

# The throwaway config skips .chezmoi.toml.tmpl, so silence its "template has changed" warning.
printf '[warnings]\n    configFileTemplateHasChanged = false\n' >"$WORK/chezmoi.toml"
cz() {
    chezmoi --source "$HERE" --config "$WORK/chezmoi.toml" --persistent-state "$WORK/state.boltdb" \
        --no-tty --override-data "{\"chezmoi\":{\"os\":\"$1\"}}" "${@:2}" </dev/null
}
# Rendered entries without comments, the way chezmoi parses them.
entries() { cz "$1" execute-template "$(cat "$HERE/.chezmoiremove")" | sed -E 's/(^|[[:space:]]+)#.*$//' | awk NF; }

for os in darwin linux; do
    got="$(entries "$os" | sort)"
    want="$(printf '%s\n' .claude/docs .claude/instructions .config/aerospace .config/karabiner .config/wezterm)"
    [[ "$got" == "$want" ]] || fail "$os entries are not the dropped configs: $got"

    managed="$(cz "$os" --destination "$WORK/empty" managed --include all)"
    while read -r entry; do
        while read -r target; do
            # shellcheck disable=SC2053 # entries are glob patterns
            if [[ "$target" == $entry || "$target" == $entry/* ]]; then
                fail "$os: $target is managed but matches .chezmoiremove entry '$entry'; delete the entry to manage it again"
            fi
        done <<<"$managed"
    done < <(entries "$os")
done
echo "PASS: entries are the dropped configs and none is managed (darwin, linux)"

# Apply the real source to a throwaway home, for this host's OS.
os="$(uname -s | tr '[:upper:]' '[:lower:]')"
home="$WORK/home"
for d in aerospace wezterm karabiner karabiner/automatic_backups aerospace.bak unrelated; do
    mkdir -p "$home/.config/$d" && echo x >"$home/.config/$d/file"
done
for d in docs instructions; do mkdir -p "$home/.claude/$d" && echo x >"$home/.claude/$d/file"; done
apply() { cz "$os" --destination "$home" apply --exclude=scripts,externals,encrypted "$@"; }
snapshot() { (cd "$home" && find . -print | sort); }

apply || fail "apply failed"
for d in aerospace wezterm karabiner; do
    [[ ! -e "$home/.config/$d" ]] || fail "~/.config/$d survived apply"
done
for d in docs instructions; do
    [[ ! -e "$home/.claude/$d" ]] || fail "~/.claude/$d survived apply"
done
[[ -L "$home/.claude/CLAUDE.md" && -L "$home/.codex/AGENTS.md" ]] || fail "agent instruction links missing"
{ grep -q J-Dog "$home/.claude/CLAUDE.md" && grep -q J-Dog "$home/.codex/AGENTS.md"; } || fail "agent instruction links don't resolve"
for d in aerospace.bak unrelated; do
    [[ -f "$home/.config/$d/file" ]] || fail "~/.config/$d was touched"
done
echo "PASS: apply removes the dropped configs and leaves their neighbours alone"

before="$(snapshot)"
pending="$(apply --dry-run --verbose)" || fail "second dry-run apply failed"
[[ -z "$pending" ]] || fail "second apply is not a no-op: $pending"
apply || fail "second apply failed"
[[ "$(snapshot)" == "$before" ]] || fail "second apply changed the home directory"
echo "PASS: second apply is a no-op"

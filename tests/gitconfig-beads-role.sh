#!/bin/bash
# bd reads beads.role from git config wherever it runs, and warns on every
# command when it's unset. Every tracker Jamie uses is his own, so the global
# git config names him maintainer on every machine.
#
#   ./tests/gitconfig-beads-role.sh
set -euo pipefail
unset $(git rev-parse --local-env-vars)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

printf '[warnings]\n    configFileTemplateHasChanged = false\n' > "$WORK/chezmoi.toml"
for os in darwin linux; do
  chezmoi --source "$HERE" --config "$WORK/chezmoi.toml" --no-tty \
    --override-data "{\"chezmoi\":{\"os\":\"$os\"}}" execute-template < "$HERE/dot_gitconfig.tmpl" > "$WORK/gitconfig-$os"
  role="$(git config -f "$WORK/gitconfig-$os" --get beads.role || true)"
  [ "$role" = maintainer ] || fail "$os: beads.role is '$role', not maintainer"
done
echo "PASS: the global git config makes Jamie maintainer of his Beads trackers (darwin, linux)"

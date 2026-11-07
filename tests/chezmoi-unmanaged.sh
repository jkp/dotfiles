#!/bin/bash
# chezmoi-unmanaged --filter hides app-owned state listed in
# .chezmoiunmanagedignore, so the fish greeting only flags real dotfiles.
#
#   ./tests/chezmoi-unmanaged.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
command -v fish >/dev/null || { echo "SKIP: needs fish"; exit 0; }

mkdir -p "$WORK/home/.local/share" "$WORK/bin"
ln -s "$HERE" "$WORK/home/.local/share/chezmoi"
# chezmoi unmanaged as it reports on a Mac with the 1Password CLI installed
printf '#!/bin/bash\nprintf "%%s\\n" .config/1Password .config/new-tool\n' > "$WORK/bin/chezmoi"
chmod +x "$WORK/bin/chezmoi"

out="$(HOME="$WORK/home" PATH="$WORK/bin:$PATH" fish --no-config -c \
    "source '$HERE/dot_config/fish/functions/chezmoi-unmanaged.fish'; chezmoi-unmanaged --filter")"
grep -qx '.config/new-tool' <<<"$out" || fail "filtered out a real untracked dotfile: $out"
! grep -q '1Password' <<<"$out" || fail "1Password CLI's state is reported as untracked: $out"
echo "PASS: 1Password CLI state is ignored, real untracked files still show"

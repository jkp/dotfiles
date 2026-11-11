#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/home/.local/share/chezmoi" "$WORK/home/.local/bin" "$WORK/bin"
ln -s /bin/ls "$WORK/home/.local/bin/installed-tool"
printf '#!/bin/sh\necho custom\n' > "$WORK/home/.local/bin/custom-tool"
cat > "$WORK/bin/chezmoi" <<'EOF'
#!/bin/bash
if [[ "${FAIL_CHECK:-}" == "$1" ]]; then
    echo "synthetic failure" >&2
    exit 1
fi
if [[ "$1" == status && "$(uname -s)" == Linux && " $* " != *' --exclude=encrypted '* ]]; then
    echo 'missing Linux encryption exclusion' >&2
    exit 1
fi
[[ "${EMPTY_CHECK:-}" == 1 ]] && exit 0
if [[ "$1" == unmanaged && " $* " == *' --exclude=encrypted '* ]]; then
    echo 'unmanaged does not support --exclude' >&2
    exit 1
fi
case "$1" in
status) printf ' M .config/real-drift\n R setup.sh\n';;
managed) echo '.local/bin';;
unmanaged) printf '.local/bin/installed-tool\n.local/bin/custom-tool\n';;
esac
EOF
printf '#!/bin/sh\nexit 0\n' > "$WORK/bin/git"
chmod +x "$WORK/bin/chezmoi" "$WORK/bin/git"
run_check() {
    HOME="$WORK/home" PATH="$WORK/bin:$PATH" fish --no-config -c \
        "source '$HERE/dot_config/fish/functions/chezmoi-unmanaged.fish'; source '$HERE/dot_config/fish/functions/chezmoi-check.fish'; chezmoi-check $*"
}
out="$(run_check -v)"
grep -q 'real-drift' <<<"$out"
grep -q 'custom-tool' <<<"$out"
! grep -q 'installed-tool\|setup.sh' <<<"$out"
for failure in status managed unmanaged; do
    if FAIL_CHECK="$failure" run_check -q >"$WORK/out" 2>&1; then
        echo "FAIL: $failure failure returned success"; exit 1
    fi
    grep -q 'synthetic failure' "$WORK/out"
done
EMPTY_CHECK=1 run_check -q
echo 'PASS: drift and custom scripts visible, installed binaries excluded, failures surfaced'

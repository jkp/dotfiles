#!/bin/bash
# scratch-volume create: makes the encrypted Scratch volume in the Data
# volume's container, keeps Time Machine and Spotlight off it, and does
# nothing when it already exists. A failed step stops it.
#
#   ./tests/scratch-volume.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$HERE/dot_local/bin/executable_scratch-volume"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

mkdir "$WORK/bin"
# Stand-ins record "<tool> <args>"; $WORK/fails lists "<tool> <first arg>" to fail.
for tool in diskutil tmutil mdutil; do
  cat > "$WORK/bin/$tool" <<STUB
#!/bin/sh
echo "$tool \$*" >> "$WORK/calls"
! grep -qx "$tool \$1" "$WORK/fails" 2>/dev/null || exit 1
case "\$1 \$2" in
  "info Scratch") [ -f "$WORK/exists" ] ;;
  "info -plist") printf '<plist><dict><key>APFSContainerReference</key><string>disk3</string></dict></plist>\n' ;;
esac
STUB
  chmod +x "$WORK/bin/$tool"
done
printf '#!/bin/sh\n"$@"\n' > "$WORK/bin/sudo"; chmod +x "$WORK/bin/sudo"
run() { : > "$WORK/calls"; echo secret | PATH="$WORK/bin:/usr/bin:/bin" "$BIN" create > "$WORK/out" 2>&1; }

run || fail "create failed: $(cat "$WORK/out")"
grep -qx 'diskutil apfs addVolume disk3 APFS Scratch -stdinpassphrase' "$WORK/calls" || fail "no encrypted Scratch in the Data container: $(cat "$WORK/calls")"
grep -qx 'tmutil addexclusion -v /Volumes/Scratch' "$WORK/calls" || fail "Time Machine not kept off: $(cat "$WORK/calls")"
grep -qx 'mdutil -i off /Volumes/Scratch' "$WORK/calls" || fail "Spotlight not kept off: $(cat "$WORK/calls")"
echo "PASS: creates an encrypted Scratch in the Data container, off Time Machine and Spotlight"

touch "$WORK/exists"
run || fail "create over an existing volume failed: $(cat "$WORK/out")"
! grep -q 'addVolume\|addexclusion\|mdutil' "$WORK/calls" || fail "touched an existing volume: $(cat "$WORK/calls")"
grep -q 'already exists' "$WORK/out" || fail "no already-exists message: $(cat "$WORK/out")"
echo "PASS: does nothing when Scratch already exists"

rm "$WORK/exists"; echo 'diskutil apfs' > "$WORK/fails"
run && fail "a failed addVolume exited 0"
! grep -q 'tmutil\|mdutil' "$WORK/calls" || fail "carried on after addVolume failed: $(cat "$WORK/calls")"
echo "PASS: stops when a step fails"

echo "OK: scratch-volume"

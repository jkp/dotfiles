#!/bin/bash
# setup-daemon.sh installs kanata's root parts for each kanata.mode. Runs it
# without sudo or a TTY, so it prints the commands, against a fake root.
#
#   ./tests/kanata-setup.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

R="$WORK/root"
VHID="$R/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"
PLIST="$R/Library/LaunchDaemons/com.kanata.plist"
VHID_PLIST="$R/Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist"
SUDOERS="$R/etc/sudoers.d/kanata-$(whoami)"
STAGE="$WORK/home/.cache/kanata-setup"
mkdir -p "$WORK/bin" "$WORK/home/.config/kanata" "$(dirname "$VHID")" "$R/Library/LaunchDaemons"
touch "$WORK/home/.config/kanata/colemak-dh-iso.kbd" "$VHID"
driver() { plutil -create xml1 "$1" 2>/dev/null || true; plutil -replace CFBundleShortVersionString -string "$2" "$1"; }
VHID_INFO="${VHID%/MacOS/*}/Info.plist"
driver "$VHID_INFO" 6.5.0
cp "$HERE/dot_config/kanata/executable_kanata-active-user" "$WORK/home/.config/kanata/kanata-active-user"
chmod +x "$VHID"
printf '#!/bin/bash\nexit 1\n' > "$WORK/bin/sudo"            # no cached sudo: print mode
printf '#!/bin/bash\n[[ -e "%s/loaded-${2#system/}" ]]\n' "$WORK" > "$WORK/bin/launchctl"  # print system/<label>
printf '#!/bin/bash\n' > "$WORK/bin/kanata"
chmod +x "$WORK/bin/"*
KANATA="$WORK/bin/kanata"

setup() { # setup <mode>: render with that mode and run it
    chezmoi --source "$HERE" --config "$WORK/none.toml" execute-template \
        --override-data "{\"kanata\":{\"mode\":\"$1\"}}" \
        < "$HERE/dot_config/kanata/setup-daemon.sh.tmpl" > "$WORK/setup.sh"
    HOME="$WORK/home" PATH="$WORK/bin:$PATH" KANATA_SETUP_ROOT="$R" bash "$WORK/setup.sh" < /dev/null 2>&1
}
has() { grep -qF -- "$2" <<<"$1" || fail "expected '$2' in: $1"; }
hasnt() { ! grep -qF -- "$2" <<<"$1" || fail "unexpected '$2' in: $1"; }
key() { plutil -extract "$2" raw -o - "$1" 2>/dev/null; }

out="$(setup always)"
has "$out" "sudo install -m 0644 -o root -g wheel $STAGE/com.kanata.plist $PLIST"
has "$out" "sudo launchctl bootstrap system $PLIST"
has "$out" "sudo install -m 0644 -o root -g wheel $STAGE/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist"
hasnt "$out" "sudoers"
plutil -lint -s "$STAGE/com.kanata.plist" || fail "always plist is invalid"
[[ "$(key "$STAGE/com.kanata.plist" RunAtLoad)" == true ]] || fail "always plist doesn't run at load"
[[ "$(key "$STAGE/com.kanata.plist" KeepAlive)" == true ]] || fail "always plist isn't kept alive"
[[ "$(key "$STAGE/com.kanata.plist" ProgramArguments.0)" == "$KANATA" ]] || fail "always plist runs the wrong binary"
echo "PASS: always installs a boot-time kept-alive daemon"

out="$(setup active-user)"
has "$out" "sudo install -m 0644 -o root -g wheel $STAGE/com.kanata.plist $PLIST"
has "$out" "sudo install -m 0755 -o root -g wheel $STAGE/kanata-active-user $R/usr/local/libexec/kanata-active-user"
has "$out" "sudo install -m 0440 -o root -g wheel $STAGE/sudoers $SUDOERS"
has "$out" "sudo launchctl bootstrap system $PLIST"
plutil -lint -s "$STAGE/com.kanata.plist" || fail "active-user plist is invalid"
key "$STAGE/com.kanata.plist" RunAtLoad >/dev/null && fail "active-user plist runs at load"
key "$STAGE/com.kanata.plist" KeepAlive >/dev/null && fail "active-user plist is kept alive"
[[ "$(key "$STAGE/com.kanata.plist" ProgramArguments.0)" == "$R/usr/local/libexec/kanata-active-user" ]] ||
    fail "active-user plist doesn't run the wrapper"
[[ "$(key "$STAGE/com.kanata.plist" ProgramArguments.1)" == "$(whoami)" ]] || fail "wrapper gets the wrong user"
[[ "$(key "$STAGE/com.kanata.plist" ProgramArguments.2)" == "$KANATA" ]] || fail "wrapper runs the wrong binary"
visudo -cf "$STAGE/sudoers" >/dev/null || fail "sudoers drop-in doesn't parse"
want="$(whoami) ALL=(root) NOPASSWD: /bin/launchctl kickstart system/com.kanata, /bin/launchctl kill TERM system/com.kanata"
[[ "$(grep -v '^#' "$STAGE/sudoers")" == "$want" ]] || fail "sudoers grants more than start/stop: $(cat "$STAGE/sudoers")"
echo "PASS: active-user installs an on-demand daemon, the wrapper and a start/stop-only sudoers rule"

cp "$STAGE/com.kanata.plist" "$PLIST"; cp "$STAGE/kanata-active-user" "$R/usr/local/libexec/" 2>/dev/null ||
    { mkdir -p "$R/usr/local/libexec"; cp "$STAGE/kanata-active-user" "$R/usr/local/libexec/"; }
mkdir -p "$(dirname "$SUDOERS")"; cp "$STAGE/sudoers" "$SUDOERS"
cp "$STAGE/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist" "$VHID_PLIST"
touch "$WORK/loaded-com.kanata"
out="$(setup active-user)"
hasnt "$out" "sudo"
echo "PASS: a second run changes nothing"

out="$(setup always)"
has "$out" "sudo rm -f $SUDOERS $R/usr/local/libexec/kanata-active-user"
has "$out" "sudo launchctl bootout system/com.kanata"
echo "PASS: switching to always removes the active-user parts and reloads"

out="$(setup off)"
has "$out" "sudo launchctl bootout system/com.kanata"
has "$out" "sudo rm -f $PLIST $SUDOERS $R/usr/local/libexec/kanata-active-user"
rm -f "$PLIST" "$SUDOERS" "$R/usr/local/libexec/kanata-active-user" "$WORK/loaded-com.kanata"
out="$(setup off)"
hasnt "$out" "sudo"
echo "PASS: off removes kanata's daemon and does nothing once it's gone"

rm -f "$VHID_PLIST"; mkdir -p "$R/Applications/Karabiner-Elements.app"
out="$(setup always)"
has "$out" "sudo launchctl bootstrap system $VHID_PLIST"
echo "PASS: an installed Karabiner-Elements whose driver daemon isn't running gets ours"
rm -f "$VHID_PLIST"; touch "$WORK/loaded-org.pqrs.service.daemon.Karabiner-VirtualHIDDevice-Daemon"
out="$(setup always)"
hasnt "$out" "org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist"
echo "PASS: Karabiner-Elements' own driver daemon is used while it's running"

driver "$VHID_INFO" 5.0.0
out="$(setup always)" && fail "succeeded with VirtualHIDDevice driver 5.0.0"
has "$out" "driver 5.0.0"
driver "$VHID_INFO" 6.5.0
echo "PASS: fails when the VirtualHIDDevice driver isn't v6"

rm -f "$VHID"
out="$(setup always)" && fail "succeeded without the VirtualHIDDevice driver"
has "$out" "VirtualHIDDevice driver not installed"
echo "PASS: fails when the VirtualHIDDevice driver is missing"

chezmoi --source "$HERE" --config "$WORK/none.toml" execute-template \
    < "$HERE/dot_config/kanata/setup-daemon.sh.tmpl" | grep -qF 'MODE="${1:-always}"' ||
    fail "without kanata.mode data (a config from before modes) the script doesn't default to always"
echo "PASS: no kanata.mode data means always"

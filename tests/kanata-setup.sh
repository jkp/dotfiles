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
printf '#!/bin/bash\necho "$@" >> "%s/opened"\n' "$WORK" > "$WORK/bin/open"
printf '#!/bin/bash\ncat > "%s/clipboard"\n' "$WORK" > "$WORK/bin/pbcopy"
printf '#!/bin/bash\n[[ -e "%s/hs-running" ]]\n' "$WORK" > "$WORK/bin/pgrep"  # pgrep -xq Hammerspoon
chmod +x "$WORK/bin/"*
touch "$WORK/console" "$WORK/hs-running"  # this user owns the console; Hammerspoon is up
KANATA="$WORK/bin/kanata"

setup() { # setup <mode>: render with that mode and run it
    chezmoi --source "$HERE" --config "$WORK/none.toml" execute-template \
        --override-data "{\"kanata\":{\"mode\":\"$1\"}}" \
        < "$HERE/dot_config/kanata/setup-daemon.sh.tmpl" > "$WORK/setup.sh"
    HOME="$WORK/home" PATH="$WORK/bin:$PATH" KANATA_SETUP_ROOT="$R" KANATA_CONSOLE="${CONSOLE:-$WORK/console}" \
        KANATA_VERIFY_WAIT=0 bash "$WORK/setup.sh" < /dev/null 2>&1
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

PKG_URL=https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases/download/v6.5.0/Karabiner-DriverKit-VirtualHIDDevice-6.5.0.pkg
PKG="$STAGE/Karabiner-DriverKit-VirtualHIDDevice-6.5.0.pkg"
MANAGER="$R/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"
driver "$VHID_INFO" 5.0.0
out="$(setup always)" && fail "succeeded with Karabiner-Elements' VirtualHIDDevice driver 5.0.0"
has "$out" "driver 5.0.0"
has "$out" "Uninstall Karabiner-Elements"
hasnt "$out" "installer"
echo "PASS: won't replace the driver Karabiner-Elements depends on"

rm -rf "$R/Applications/Karabiner-Elements.app"
out="$(setup always)" || fail "driver 5.0.0 without Karabiner-Elements: $out"
has "$out" "curl -fsSL -o $PKG $PKG_URL"
has "$out" "738893c0ff52d45990f8b1c6a9f984ef53e25140d1cf259cfad82a755b32db2f  $PKG"
has "$out" "sudo installer -pkg $PKG -target /"
has "$out" "sudo $MANAGER forceActivate"
echo "PASS: installs the pinned, checksummed v6 driver over an old one"

rm -f "$VHID"
out="$(setup always)" || fail "missing driver: $out"
has "$out" "sudo installer -pkg $PKG -target /"
has "$out" "sudo $MANAGER forceActivate"
touch "$VHID"; chmod +x "$VHID"; driver "$VHID_INFO" 6.5.0
echo "PASS: installs the driver when it's missing"

# Guided check: with sudo, setup restarts kanata and walks through what's missing.
rm -rf "$STAGE"; out="$(setup active-user)"
for f in com.kanata.plist; do cp "$STAGE/$f" "$PLIST"; done
cp "$STAGE/kanata-active-user" "$R/usr/local/libexec/kanata-active-user"; cp "$STAGE/sudoers" "$SUDOERS"
printf '#!/bin/bash\n[[ "$1" == -n ]] && shift\nexec "$@"\n' > "$WORK/bin/sudo"
cat > "$WORK/bin/launchctl" <<STUB
#!/bin/bash
case "\$1" in
print) [[ -e "$WORK/loaded-\${2#system/}" ]] || exit 1; [[ -e "$WORK/running" ]] && printf '\tstate = running\n'; exit 0 ;;
kickstart) echo "\$*" >> "$WORK/kickstarts"; cat "$WORK/kanata-says" >> "$R/tmp/kanata.err"; [[ -s "$WORK/kanata-says" ]] || touch "$WORK/running" ;;
esac
STUB
mkdir -p "$R/tmp"; touch "$WORK/loaded-com.kanata"
checked() { rm -f "$WORK/opened" "$WORK/clipboard" "$WORK/kickstarts" "$WORK/running"; printf '%s' "$1" > "$WORK/kanata-says"; }
REAL_KANATA="$(readlink -f "$KANATA")"

checked "[ERROR] failed to open keyboard device(s): kanata needs macOS Input Monitoring permission."
out="$(setup active-user)" && fail "succeeded without Input Monitoring: $out"
grep -qF "kickstart -k system/com.kanata" "$WORK/kickstarts" || fail "didn't restart kanata to check it"
has "$out" "Input Monitoring"
has "$out" "$REAL_KANATA"
grep -qF "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent" "$WORK/opened" ||
    fail "didn't open the Input Monitoring pane"
[[ "$(cat "$WORK/clipboard")" == "$REAL_KANATA" ]] || fail "didn't copy the kanata path"
echo "PASS: a missing Input Monitoring grant opens its pane with kanata's real path copied"

checked "[ERROR] failed to open keyboard device(s): kanata needs macOS Accessibility permission."
out="$(setup active-user)" && fail "succeeded without Accessibility: $out"
has "$out" "Allow assistive applications to control the computer"
grep -qF "?Privacy_Accessibility" "$WORK/opened" || fail "didn't open the Accessibility pane"
echo "PASS: a missing Accessibility grant opens its pane, named as macOS 27 shows it"

checked ""
out="$(setup active-user)" || fail "a running kanata failed the check: $out"
has "$out" "kanata is running"
[[ ! -e "$WORK/opened" ]] || fail "opened settings although kanata runs: $(cat "$WORK/opened")"
echo "PASS: says so when kanata runs"

checked ""
out="$(CONSOLE=/etc/hosts setup active-user)" || fail "check failed while someone else is at the console: $out"
[[ ! -e "$WORK/kickstarts" ]] || fail "started kanata in someone else's session"
has "$out" "next time you're the active user"
echo "PASS: doesn't start kanata in someone else's session"

checked ""; rm -f "$WORK/hs-running"
out="$(setup active-user)"
has "$out" "Hammerspoon isn't running"
grep -qF -- "-a Hammerspoon" "$WORK/opened" || fail "didn't open Hammerspoon"
printf '#!/bin/bash\nexit 1\n' > "$WORK/bin/sudo"; checked ""
out="$(setup always)"
hasnt "$out" "Hammerspoon"
touch "$WORK/hs-running"
echo "PASS: active-user opens Hammerspoon when it isn't running, always doesn't need it"

chezmoi --source "$HERE" --config "$WORK/none.toml" execute-template \
    < "$HERE/dot_config/kanata/setup-daemon.sh.tmpl" | grep -qF 'MODE="${1:-always}"' ||
    fail "without kanata.mode data (a config from before modes) the script doesn't default to always"
echo "PASS: no kanata.mode data means always"

# Kanata Keyboard Remapper

Kanata remaps the keyboard to Colemak-DH with home row mods and layer switching.

## Installation

```bash
brew install kanata
```

## Driver

Kanata needs the Karabiner VirtualHIDDevice driver plus its daemon running as root. kanata < 1.13 pairs with driver v6.x (`.pkg` from [Karabiner-DriverKit-VirtualHIDDevice releases](https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases)). `setup-daemon.sh` installs the daemon at `/Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist`, unless Karabiner-Elements is installed and runs its own. Karabiner-Elements bundles the driver at whatever version it shipped with, and uninstalling it removes the driver, so reinstall the `.pkg` afterwards.

## Modes

Kanata needs root to seize the keyboard, so it runs as the root LaunchDaemon `com.kanata`. `kanata.mode` in chezmoi data picks how:

- **always**: starts at boot and is kept alive.
- **active-user** (shared Macs): only remaps while you own the console. Hammerspoon starts it when your session loads or becomes active, and stops it on fast user switch, the login window or logout. The daemon runs kanata through `kanata-active-user`, which also exits within a second of anyone else owning the console. A sudoers drop-in lets only you start and stop that one label.
- **off**: no daemon.

`chezmoi init` asks once (default **always**, no prompt if the always-on daemon is already installed). To set or change it without a prompt, run `KANATA_MODE=active-user chezmoi init`. Then install the root parts for the mode:

```bash
bash ~/.config/kanata/setup-daemon.sh
```

It's idempotent, and without sudo or a terminal it prints the commands instead. Then grant Input Monitoring to the kanata binary it names (**System Settings → Privacy & Security → Input Monitoring**, **+**, **Cmd+Shift+G**) and restart the daemon.

### Managing the Service

```bash
# Restart (in active-user mode, start: sudo launchctl kickstart system/com.kanata)
sudo launchctl kickstart -k system/com.kanata

# Stop (always mode restarts it; bootout to keep it down)
sudo launchctl kill TERM system/com.kanata
sudo launchctl bootout system/com.kanata

# Start after bootout
sudo launchctl bootstrap system /Library/LaunchDaemons/com.kanata.plist

# Status and logs
sudo launchctl print system/com.kanata | grep state
tail -f /tmp/kanata.log /tmp/kanata.err
```

## Layers

| Layer | Activation |
|-------|------------|
| Colemak-DH | Default |
| QWERTY | F3 → 1 |
| Navigation | Hold S |
| Symbols | Hold E or tap Right Shift |
| Numbers | Hold Z or tap Left Shift |

## Updating Kanata

1. `brew upgrade kanata`
2. Re-grant Input Monitoring if macOS drops it for the new binary
3. Restart: `sudo launchctl kickstart -k system/com.kanata`

kanata 1.13+ needs a newer VirtualHIDDevice driver; check the kanata release notes before crossing that version.

## Troubleshooting

### Keyboard not remapping

Check the error log:
```bash
cat /tmp/kanata.err
```

Common issues:
- **"IOHIDDeviceOpen error: not permitted"**: Missing Input Monitoring permission
- **"failed to parse file"**: Syntax error in config
- **VirtualHIDDevice connection errors**: the driver daemon isn't running (`sudo launchctl list | grep VirtualHIDDevice`)
- **active-user mode never starts**: look for `[kanata] launchctl ... failed` in the Hammerspoon console; a missing sudoers drop-in means `setup-daemon.sh` hasn't been run for this mode

### Testing manually

Stop the daemon and run manually:
```bash
sudo launchctl bootout system/com.kanata
sudo kanata --cfg ~/.config/kanata/colemak-dh-iso.kbd
```

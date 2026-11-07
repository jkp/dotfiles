# Kanata Keyboard Remapper

Kanata remaps the keyboard to Colemak-DH with home row mods and layer switching.

## Installation

```bash
brew install kanata
```

## Driver

Kanata needs the Karabiner VirtualHIDDevice driver plus its daemon running as root. kanata < 1.13 pairs with driver v6.x. `setup-daemon.sh` installs the pinned v6 `.pkg` (checksummed) and activates it when the driver is missing or older. If macOS asks, approve the system extension in **System Settings → General → Login Items & Extensions** and rerun. It won't replace the driver while Karabiner-Elements is installed with an older one (15.3.0 ships 5.0.0), since that would break Karabiner-Elements: uninstall Karabiner-Elements first (Settings → Misc → Uninstall). It also installs the driver daemon at `/Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist`, unless Karabiner-Elements' own driver daemon is running. Rerun `setup-daemon.sh` after installing, removing or repairing Karabiner-Elements.

## Modes

Kanata needs root to seize the keyboard, so it runs as the root LaunchDaemon `com.kanata`. `kanata.mode` in chezmoi data picks how:

- **always**: starts at boot and is kept alive.
- **active-user** (shared Macs): only remaps while you own the console. Hammerspoon starts it when your session loads or becomes active, and stops it on fast user switch, the login window or logout. The daemon runs kanata through `kanata-active-user`, which also exits within a second of anyone else owning the console. A sudoers drop-in lets only you start and stop that one label.
- **off**: no daemon.

`chezmoi init` asks once (default **always**, no prompt if the always-on daemon is already installed). Without a terminal the mode can't be chosen, so it's **active-user**: on a single-user Mac that behaves like always, since you're always the console user, and on a shared Mac it's the only safe mode. To set or change it without a prompt, run `KANATA_MODE=active-user chezmoi init`. Then install the root parts for the mode:

```bash
bash ~/.config/kanata/setup-daemon.sh
```

It's idempotent. In a terminal it then restarts kanata and checks it runs. If kanata lacks a permission, it opens that Privacy pane with the kanata binary's real path (under `/opt/homebrew/Cellar`, which is what macOS pins) copied, and waits while you add it with **+**, **Cmd+Shift+G**, paste. kanata needs two:

- **Input Monitoring**
- **Accessibility**, which macOS 27 lists as **"Allow assistive applications to control the computer"**

In active-user mode it also opens Hammerspoon if it isn't running (allow it Accessibility when asked); Hammerspoon then sets itself to launch at login, since it's the only thing that starts kanata. Without sudo or a terminal it prints the commands instead.

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
2. `bash ~/.config/kanata/setup-daemon.sh`: the grants are pinned to the old Cellar path, so it walks you through both again (remove the stale entries with **−**)

kanata 1.13+ needs a newer VirtualHIDDevice driver; check the kanata release notes before crossing that version.

## Troubleshooting

### Keyboard not remapping

Check the error log:
```bash
cat /tmp/kanata.err
```

Common issues:
- **"needs macOS Input Monitoring permission"** or **"Accessibility permission"** / **"IOHIDDeviceOpen error: not permitted"**: rerun `setup-daemon.sh`, which opens the pane to fix it
- **"failed to parse file"**: Syntax error in config
- **VirtualHIDDevice connection errors**: the driver daemon isn't running (`sudo launchctl list | grep VirtualHIDDevice`)
- **active-user mode never starts**: look for `[kanata] launchctl ... failed` in the Hammerspoon console; a missing sudoers drop-in means `setup-daemon.sh` hasn't been run for this mode

### Testing manually

Stop the daemon and run manually:
```bash
sudo launchctl bootout system/com.kanata
sudo kanata --cfg ~/.config/kanata/colemak-dh-iso.kbd
```

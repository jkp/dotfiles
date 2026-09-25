# Kanata Keyboard Remapper

Kanata remaps the keyboard to Colemak-DH with home row mods and layer switching.

## Installation

```bash
brew install kanata
```

## Driver

Kanata needs the Karabiner VirtualHIDDevice driver (standalone `.pkg`, not Karabiner-Elements) plus its daemon running as root. kanata < 1.13 pairs with driver v6.x. `setup-daemon.sh` installs the daemon at `/Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist`.

## Running as a Daemon

Kanata needs root to intercept keyboard input. `setup-daemon.sh` writes `/Library/LaunchDaemons/com.kanata.plist` and loads it:

```bash
bash ~/.config/kanata/setup-daemon.sh
```

Then grant Input Monitoring to `/opt/homebrew/bin/kanata` (**System Settings → Privacy & Security → Input Monitoring**, **+**, **Cmd+Shift+G**) and restart the daemon.

### Managing the Service

```bash
# Restart
sudo launchctl kickstart -k system/com.kanata

# Stop
sudo launchctl bootout system/com.kanata

# Start
sudo launchctl bootstrap system /Library/LaunchDaemons/com.kanata.plist

# Check status
sudo launchctl list | grep kanata

# View logs
tail -f /tmp/kanata.log
tail -f /tmp/kanata.err
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

### Testing manually

Stop the daemon and run manually:
```bash
sudo launchctl bootout system/com.kanata
sudo kanata --cfg ~/.config/kanata/colemak-dh-iso.kbd
```

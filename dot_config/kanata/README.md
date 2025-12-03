# Kanata Keyboard Remapper

Kanata remaps the keyboard to Colemak-DH with home row mods and layer switching.

## Installation

Kanata is installed via mise using the `cmd_allowed` variant from GitHub releases:

```toml
# ~/.config/mise/config.toml
[tools."ubi:jtroo/kanata"]
version = "1.10.0"
matching = "macos-binaries-arm64"
exe = "kanata_macos_cmd_allowed_arm64"
rename_exe = "kanata"
```

The `cmd_allowed` variant is required for the layer indicator feature (runs shell commands on layer switch).

## Running as a Daemon

Kanata requires root privileges to intercept keyboard input. Create a launchd daemon:

### 1. Create the plist

```bash
sudo tee /Library/LaunchDaemons/com.kanata.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.kanata</string>

    <key>ProgramArguments</key>
    <array>
        <string>/Users/YOUR_USERNAME/.local/share/mise/installs/ubi-jtroo-kanata/1.10.0/kanata</string>
        <string>-c</string>
        <string>/Users/YOUR_USERNAME/.config/kanata/colemak-dh-iso.kbd</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/tmp/kanata.log</string>

    <key>StandardErrorPath</key>
    <string>/tmp/kanata.err</string>

    <key>UserName</key>
    <string>root</string>
</dict>
</plist>
EOF
```

Replace `YOUR_USERNAME` with your actual username.

### 2. Grant Input Monitoring Permission

The kanata binary needs Input Monitoring access:

1. Open **System Settings → Privacy & Security → Input Monitoring**
2. Click **+** and press **Cmd+Shift+G**
3. Navigate to: `~/.local/share/mise/installs/ubi-jtroo-kanata/1.10.0/`
4. Select `kanata` and add it
5. Ensure it's toggled **on**

### 3. Load the Daemon

```bash
sudo launchctl bootstrap system /Library/LaunchDaemons/com.kanata.plist
```

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

## Layer Indicator (Hammerspoon)

The config writes the current layer to `/tmp/kanata-layer` on every layer switch. Hammerspoon watches this file and displays the layer in the menu bar.

See `~/.hammerspoon/init.lua` for the Hammerspoon configuration.

### Layers

| Code | Layer | Activation |
|------|-------|------------|
| CDH | Colemak-DH | Default |
| QW | QWERTY | F3 → 1 |
| NAV | Navigation | Hold S |
| SYM | Symbols | Hold E or tap Right Shift |
| NUM | Numbers | Hold Z or tap Left Shift |

Non-default layers display with a white background in the menu bar for visibility.

## Updating Kanata

When updating the kanata version:

1. Update the version in `~/.config/mise/config.toml`
2. Run `mise install`
3. Update the path in `/Library/LaunchDaemons/com.kanata.plist`
4. Re-grant Input Monitoring permission for the new binary
5. Restart: `sudo launchctl kickstart -k system/com.kanata`

## Troubleshooting

### Keyboard not remapping

Check the error log:
```bash
cat /tmp/kanata.err
```

Common issues:
- **"cmd is not enabled"**: Using wrong binary variant (need `cmd_allowed`)
- **"IOHIDDeviceOpen error: not permitted"**: Missing Input Monitoring permission
- **"failed to parse file"**: Syntax error in config

### Testing manually

Stop the daemon and run manually:
```bash
sudo launchctl bootout system/com.kanata
sudo ~/.local/share/mise/installs/ubi-jtroo-kanata/1.10.0/kanata --cfg ~/.config/kanata/colemak-dh-iso.kbd
```

#!/bin/bash
# Setup Kanata as a launchd daemon
# Run with: bash ~/.config/kanata/setup-daemon.sh

set -euo pipefail

USERNAME=$(whoami)
KANATA_BIN="/opt/homebrew/bin/kanata"
KANATA_CFG="$HOME/.config/kanata/colemak-dh-iso.kbd"
PLIST_PATH="/Library/LaunchDaemons/com.kanata.plist"

echo "Setting up Kanata daemon for user: $USERNAME"

if [[ ! -x "$KANATA_BIN" ]]; then
    echo "Error: Kanata not found at $KANATA_BIN (brew install kanata)"
    exit 1
fi

# Check if config exists
if [[ ! -f "$KANATA_CFG" ]]; then
    echo "Error: Config not found at $KANATA_CFG"
    exit 1
fi

# Kanata needs the Karabiner VirtualHIDDevice driver + its daemon (no Karabiner-Elements).
# kanata < 1.13 pairs with driver v6.x: https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases
VHID_DAEMON="/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"
VHID_PLIST="/Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist"
if [[ ! -x "$VHID_DAEMON" ]]; then
    echo "Error: Karabiner VirtualHIDDevice driver not installed. Install the .pkg, then:"
    echo "  sudo /Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager forceActivate"
    exit 1
fi
if [[ ! -f "$VHID_PLIST" ]]; then
    echo "Installing VirtualHIDDevice daemon at $VHID_PLIST..."
    sudo tee "$VHID_PLIST" > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>org.pqrs.Karabiner-VirtualHIDDevice-Daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>$VHID_DAEMON</string>
    </array>
    <key>UserName</key>
    <string>root</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/karabiner-vhid-daemon.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/karabiner-vhid-daemon.log</string>
</dict>
</plist>
EOF
    sudo launchctl bootstrap system "$VHID_PLIST"
fi

# Create the plist
echo "Creating launchd plist at $PLIST_PATH..."
sudo tee "$PLIST_PATH" > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.kanata</string>

    <key>ProgramArguments</key>
    <array>
        <string>$KANATA_BIN</string>
        <string>-c</string>
        <string>$KANATA_CFG</string>
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

echo "Plist created."

# Stop existing service if running
if sudo launchctl list 2>/dev/null | grep -q com.kanata; then
    echo "Stopping existing kanata service..."
    sudo launchctl bootout system/com.kanata 2>/dev/null || true
fi

# Load the service
echo "Loading kanata service..."
sudo launchctl bootstrap system "$PLIST_PATH"

echo ""
echo "Kanata daemon installed and started."
echo ""
echo "IMPORTANT: Grant Input Monitoring permission:"
echo "  1. Open System Settings → Privacy & Security → Input Monitoring"
echo "  2. Click + and press Cmd+Shift+G"
echo "  3. Navigate to: $KANATA_BIN"
echo "  4. Add and enable it"
echo ""
echo "Then restart: sudo launchctl kickstart -k system/com.kanata"
echo ""
echo "Check logs:"
echo "  tail -f /tmp/kanata.log"
echo "  tail -f /tmp/kanata.err"

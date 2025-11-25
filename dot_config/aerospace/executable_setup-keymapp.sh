#!/bin/bash

# Launch keymapp if not already running
if ! pgrep -x "Keymapp" > /dev/null; then
    open -a "Keymapp"
    # Wait for the app to launch and window to appear
    sleep 2
fi

# Wait for keymapp window to be available
for i in {1..10}; do
    WINDOW_ID=$(aerospace list-windows --monitor all --app-bundle-id io.zsa.keymapp --format '%{window-id}')
    if [ -n "$WINDOW_ID" ]; then
        break
    fi
    sleep 0.5
done

# Set window to floating via aerospace
if [ -n "$WINDOW_ID" ]; then
    aerospace focus --window-id "$WINDOW_ID"
    aerospace layout floating
fi

# Position and resize the window using AppleScript
osascript <<EOF
tell application "System Events"
    tell process "Keymapp"
        set position of window 1 to {2, 39}
        set size of window 1 to {500, 380}
    end tell
end tell
EOF

#!/bin/bash

CONFIG="$HOME/.config/aerospace/aerospace.toml"

if pgrep -x "keymapp" > /dev/null; then
    # Keymapp is running - quit it and disable margin
    killall keymapp
    
    # Disable margin
    sed -i '' 's/outer.left = \[{ monitor."Studio Display" = 510 }, { monitor."Built-in Retina Display" = 5 }, 5\]/outer.left = 5/' "$CONFIG"
    aerospace reload-config
else
    # Keymapp not running - launch it and enable margin
    
    # Enable margin first
    if ! grep -q 'outer.left = \[{ monitor."Studio Display" = 510 }' "$CONFIG"; then
        sed -i '' 's/outer.left = 5/outer.left = [{ monitor."Studio Display" = 510 }, { monitor."Built-in Retina Display" = 5 }, 5]/' "$CONFIG"
        aerospace reload-config
        sleep 0.3
    fi
    
    # Call existing setup script
    ~/.config/aerospace/setup-keymapp.sh
fi

#!/bin/bash
WINDOW_ID=$(aerospace list-windows --monitor all --app-bundle-id io.zsa.keymapp --format '%{window-id}')
CURRENT_WORKSPACE=$(aerospace list-workspaces --focused)
echo $CURRENT_WORKSPACE
if [ -n "$WINDOW_ID" ] && [ -n "$CURRENT_WORKSPACE" ]; then
    aerospace move-node-to-workspace --window-id "$WINDOW_ID" "$CURRENT_WORKSPACE"
fi

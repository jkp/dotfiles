#!/bin/bash
# Auto-float any window that appears on the scratch workspace.
CURRENT=$(aerospace list-workspaces --focused)
[ "$CURRENT" != "5-scratch" ] && exit 0

for WID in $(aerospace list-windows --workspace 5-scratch --format '%{window-id}'); do
  aerospace layout floating --window-id "$WID" 2>/dev/null
done

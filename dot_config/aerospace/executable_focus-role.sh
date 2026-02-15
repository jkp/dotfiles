#!/bin/bash
# Focus the first matching app on the current workspace.
# Usage: focus-role.sh <app1> [app2] [app3] ...
for app in "$@"; do
  WID=$(aerospace list-windows --workspace focused --format '%{window-id} %{app-name}' | grep -i "$app" | head -1 | awk '{print $1}')
  if [ -n "$WID" ]; then
    aerospace focus --window-id "$WID"
    exit 0
  fi
done

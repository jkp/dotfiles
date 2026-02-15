#!/bin/bash
# Idempotently ensure a WezTerm instance for a given domain is on the right workspace.
# Usage: ensure-wezterm.sh <domain> <workspace>
# Example: ensure-wezterm.sh personal 1-personal

DOMAIN="${1:?Usage: ensure-wezterm.sh <domain> <workspace>}"
WORKSPACE="${2:?Usage: ensure-wezterm.sh <domain> <workspace>}"

# Check if a WezTerm window for this domain already exists
EXISTING=$(aerospace list-windows --all --format '%{window-id} %{window-title}' | grep "\\[${DOMAIN}\\]" | head -1 | awk '{print $1}')
if [ -n "$EXISTING" ]; then
  exit 0
fi

# Launch WezTerm connected to this domain
/Applications/WezTerm.app/Contents/MacOS/wezterm connect "$DOMAIN" &

# Wait for window to appear with the right title, then move it
for _ in $(seq 1 15); do
  sleep 1
  WID=$(aerospace list-windows --all --format '%{window-id} %{window-title}' | grep "\\[${DOMAIN}\\]" | head -1 | awk '{print $1}')
  if [ -n "$WID" ]; then
    aerospace move-node-to-workspace --window-id "$WID" "$WORKSPACE" 2>/dev/null
    exit 0
  fi
done

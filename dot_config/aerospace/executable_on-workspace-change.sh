#!/bin/bash
# Runs on every workspace change. Handles:
# 1. Sticky Keymapp (follows you to every workspace)
# 2. Self-healing WezTerm (ensures personal/work instances exist)

CURRENT=$(aerospace list-workspaces --focused)

# --- Sticky Keymapp ---
KEYMAPP_ID=$(aerospace list-windows --monitor all --app-bundle-id io.zsa.keymapp --format '%{window-id}')
if [ -n "$KEYMAPP_ID" ] && [ -n "$CURRENT" ]; then
  aerospace move-node-to-workspace --window-id "$KEYMAPP_ID" "$CURRENT"
fi

# --- Auto-float scratch workspace ---
if [ "$CURRENT" = "5-scratch" ]; then
  aerospace list-windows --workspace 5-scratch --format '%{window-id}' | while read -r WID; do
    [ -n "$WID" ] && aerospace layout floating --window-id "$WID" 2>/dev/null
  done
fi

# --- Self-healing WezTerm ---
case "$CURRENT" in
  1-personal)
    if ! aerospace list-windows --workspace 1-personal --format '%{window-title}' | grep -q '\\[personal\\]'; then
      ~/.config/aerospace/ensure-wezterm.sh personal 1-personal &
    fi
    ;;
  2-work)
    if ! aerospace list-windows --workspace 2-work --format '%{window-title}' | grep -q '\\[work\\]'; then
      ~/.config/aerospace/ensure-wezterm.sh work 2-work &
    fi
    ;;
esac

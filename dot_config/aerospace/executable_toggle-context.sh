#!/bin/bash
# Toggle between personal and work workspaces.
# From any other workspace, defaults to personal.

CURRENT=$(aerospace list-workspaces --focused)
case "$CURRENT" in
  1-personal) aerospace workspace 2-work ;;
  2-work)     aerospace workspace 1-personal ;;
  *)          aerospace workspace 1-personal ;;
esac

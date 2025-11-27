#!/usr/bin/env bash
# Cleanup phantom aerospace windows (those with empty titles)

set -euo pipefail

phantom_ids=$(aerospace list-windows --all --json | \
  jq -r '.[] | select(.["window-title"] == "") | .["window-id"]')

if [[ -z "$phantom_ids" ]]; then
  echo "No phantom windows found"
  exit 0
fi

count=$(echo "$phantom_ids" | wc -l | tr -d ' ')
echo "Found $count phantom window(s)"

for id in $phantom_ids; do
  app=$(aerospace list-windows --all --json | jq -r ".[] | select(.[\"window-id\"] == $id) | .[\"app-name\"]")
  echo "Closing window $id ($app)"
  aerospace close --window-id "$id"
done

echo "Done"

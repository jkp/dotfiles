#!/bin/bash
# safari-tabs-export: builds it, runs it on a fixture CloudTabs.db, checks the
# JSON Alfred reads. macOS only (swiftc, Safari's schema).
#
#   ./tests/safari-tabs-export.sh
set -euo pipefail

[[ "$(uname)" == Darwin ]] || { echo "SKIP: macOS only"; exit 0; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

swiftc -O -o "$WORK/export" "$HERE/dot_local/share/safari-tabs-export/main.swift"

# Safari's schema, trimmed to what the export reads. Times are seconds since
# 2001-01-01 (Core Data's reference date); 0 means never viewed.
sqlite3 "$WORK/CloudTabs.db" <<'SQL'
CREATE TABLE cloud_tab_devices (device_uuid TEXT PRIMARY KEY NOT NULL, system_fields BLOB NOT NULL, device_name TEXT, last_modified REAL NOT NULL);
CREATE TABLE cloud_tabs (tab_uuid TEXT PRIMARY KEY NOT NULL, system_fields BLOB NOT NULL, device_uuid TEXT NOT NULL, position BLOB NOT NULL, title TEXT, url TEXT NOT NULL, last_viewed_time REAL DEFAULT 0);
INSERT INTO cloud_tab_devices VALUES ('D1', x'', 'Jamies iPhone', 0), ('D2', x'', 'iPad Mini', 0);
INSERT INTO cloud_tabs VALUES
  ('T1', x'', 'D1', x'', 'Old "quoted" tab', 'https://a.example/1', 813402534.5),
  ('T2', x'', 'D1', x'', 'Newer tab', 'https://a.example/2', 813402600),
  ('T3', x'', 'D2', x'', NULL, 'https://b.example/', 0);
SQL

out="$WORK/out/tabs.json"
mkdir "$WORK/out"
"$WORK/export" "$out" "$WORK/CloudTabs.db" || fail "export exited non-zero"

python3 - "$out" <<'PY' || fail "tabs.json isn't what Alfred expects"
import json, sys
d = json.load(open(sys.argv[1]))
tabs = d["tabs"]
assert d["exported"].endswith("Z"), d["exported"]
assert [t["url"] for t in tabs] == ["https://a.example/2", "https://a.example/1", "https://b.example/"], tabs
assert tabs[0] == {"device": "Jamies iPhone", "title": "Newer tab", "url": "https://a.example/2",
                   "last_viewed": "2026-10-11T09:10:00Z"}, tabs[0]
assert tabs[1]["title"] == 'Old "quoted" tab', tabs[1]
assert tabs[2]["title"] == "" and tabs[2]["last_viewed"] is None, tabs[2]
PY
[[ -z "$(ls -A "$WORK/out" | grep -v '^tabs.json$')" ]] || fail "left temp files beside tabs.json (Syncthing would send them)"
echo "PASS: tabs.json lists every device's tabs, newest first per device"

"$WORK/export" "$out" "$WORK/missing.db" 2>"$WORK/err" && fail "a missing database must fail, not write an empty list"
grep -q "missing.db" "$WORK/err" || fail "the error doesn't name the database"
echo "PASS: an unreadable database fails loudly"

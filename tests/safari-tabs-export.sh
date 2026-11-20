#!/bin/bash
# safari-tabs-export: builds it, runs it on fixture Safari databases, checks
# what lands in the folder Alfred reads. macOS only (swiftc, Safari's schema).
#
#   ./tests/safari-tabs-export.sh
set -euo pipefail

[[ "$(uname)" == Darwin ]] || { echo "SKIP: macOS only"; exit 0; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

swiftc -O -o "$WORK/export" "$HERE/dot_local/share/safari-tabs-export/main.swift"

# Safari's schemas, trimmed to what the export reads. Times are seconds since
# 2001-01-01; 0 means never viewed. 813402600 = 2026-10-11T09:10:00Z.
mkdir "$WORK/safari"
sqlite3 "$WORK/safari/CloudTabs.db" <<'SQL'
CREATE TABLE cloud_tab_devices (device_uuid TEXT PRIMARY KEY NOT NULL, system_fields BLOB NOT NULL, device_name TEXT, last_modified REAL NOT NULL);
CREATE TABLE cloud_tabs (tab_uuid TEXT PRIMARY KEY NOT NULL, system_fields BLOB NOT NULL, device_uuid TEXT NOT NULL, position BLOB NOT NULL, title TEXT, url TEXT NOT NULL, last_viewed_time REAL DEFAULT 0);
INSERT INTO cloud_tab_devices VALUES ('D1', x'', 'Jamies iPhone', 0), ('D2', x'', 'iPad Mini', 0);
INSERT INTO cloud_tabs VALUES
  ('T1', x'', 'D1', x'', 'Old "quoted" tab', 'https://a.example/1', 813402534.5),
  ('T2', x'', 'D1', x'', 'Newer tab', 'https://a.example/2', 813402600),
  ('T3', x'', 'D2', x'', NULL, 'https://b.example/', 0),
  ('T4', x'', 'D1', x'', 'Inbox', 'https://mail.proton.me/u/13/inbox/abc', 813402600),
  ('T5', x'', 'D1', x'', 'Reset', 'https://shop.example/reset?token=s3cret', 813402600),
  ('T6', x'', 'D1', x'', 'Callback', 'https://app.example/cb#access_token=s3cret', 813402600),
  ('T7', x'', 'D1', x'', 'T3 Code', 'https://tkol.bicorn-sirius.ts.net/pair', 813402600);
SQL
# Named Tab Groups are top-level, visible folders (type 1, subtype 0); their
# tabs are type 0 children. Hidden roots (Local/Private windows), pinned tabs
# and profile folders are not groups.
sqlite3 "$WORK/safari/SafariTabs.db" <<'SQL'
CREATE TABLE bookmarks (id INTEGER PRIMARY KEY, special_id INTEGER DEFAULT 0, parent INTEGER, type INTEGER, title TEXT, url TEXT, hidden INTEGER DEFAULT 0, order_index INTEGER NOT NULL, deleted INTEGER DEFAULT 0, subtype INTEGER DEFAULT 0);
INSERT INTO bookmarks (id, special_id, parent, type, title, url, hidden, order_index, deleted, subtype) VALUES
  (0,    0, NULL, 1, 'Root',      NULL, 0, 0, 0, 0),
  (536,  0, NULL, 1, 'Local',     NULL, 1, 0, 0, 0),
  (537,  0, 536,  0, 'Local tab', 'https://local.example/', 0, 0, 0, 0),
  (1,    0, 0,    1, '',          NULL, 1, 0, 0, 0),
  (2,    0, 1,    0, 'Pinned',    'https://pinned.example/', 0, 0, 0, 0),
  (4814, 0, 0,    1, 'Vanagon',   NULL, 0, 1, 0, 0),
  (4815, 0, 4814, 1, 'TopScopedBookmarkList', NULL, 0, 0, 0, 1),
  (4816, 0, 4814, 0, 'Syncro 4WD', 'https://vanagon.example/syncro', 0, 2, 0, 0),
  (4817, 0, 4814, 0, 'Westy',      'https://vanagon.example/westy', 0, 1, 0, 0),
  (4818, 0, 4814, 0, 'Gone',       'https://vanagon.example/gone', 0, 3, 1, 0),
  (430,  0, 0,    1, 'Work',      NULL, 0, 2, 0, 2),
  (431,  0, 430,  0, 'Work tab',  'https://work.example/', 0, 0, 0, 0);
SQL
# History: origin 0 is this Mac, 1 synced from another device. A redirect's
# source visit (it has a redirect_destination) isn't a page Jamie read.
sqlite3 "$WORK/History.db" <<'SQL'
CREATE TABLE history_items (id INTEGER PRIMARY KEY, url TEXT NOT NULL UNIQUE);
CREATE TABLE history_visits (id INTEGER PRIMARY KEY, history_item INTEGER NOT NULL, visit_time REAL NOT NULL, title TEXT, load_successful BOOLEAN NOT NULL DEFAULT 1, synthesized BOOLEAN NOT NULL DEFAULT 0, redirect_source INTEGER, redirect_destination INTEGER, origin INTEGER NOT NULL DEFAULT 0);
INSERT INTO history_items VALUES
  (1, 'https://duckduckgo.com/?q=autumn+pubs+with+rooms'),
  (2, 'https://www.theguardian.com/travel/autumn-inns'),
  (3, 'https://t.co/xyz'),
  (4, 'https://www.corshamhouse.com/'),
  (5, 'https://mail.proton.me/u/13/inbox'),
  (6, 'https://old.example/');
INSERT INTO history_visits (id, history_item, visit_time, title, load_successful, synthesized, redirect_source, redirect_destination, origin) VALUES
  (10, 1, 813402600, 'autumn pubs with rooms at DuckDuckGo', 1, 0, NULL, NULL, 1),
  (11, 3, 813402660, NULL, 1, 0, NULL, 12, 1),
  (12, 2, 813402661, '15 great small hotels', 1, 0, 11, NULL, 1),
  (13, 4, 813402900, 'Corsham House', 1, 0, NULL, NULL, 0),
  (14, 5, 813402950, 'Inbox', 1, 0, NULL, NULL, 0),
  (15, 4, 813402960, 'Corsham House', 0, 0, NULL, NULL, 0),
  (16, 6, 810000000, 'Older than the window', 1, 0, NULL, NULL, 0);
SQL
cat > "$WORK/exclude" <<'TXT'
# never leaves the Mac
mail.proton.me
ts.net
TXT

out="$WORK/out/safari-tabs"
mkdir -p "$out/history" "$out/tabs"
echo stale > "$out/history/2026-09-01.json"
echo stale > "$out/tabs/2026-09-01.json"
echo keep > "$out/history/notes.txt"

run() {
  TZ=Europe/London SAFARI_CONTAINER_DIR="$WORK/safari" SAFARI_HISTORY_DB="$WORK/History.db" \
    SAFARI_TABS_EXCLUDE="$WORK/exclude" SAFARI_TABS_NOW=2026-10-11T12:00:00Z \
    "$WORK/export" "$out"
}
run || fail "export exited non-zero"

python3 - "$out" <<'PY' || fail "the export isn't what Alfred expects"
import json, os, sys
out = sys.argv[1]
tabs = json.load(open(f"{out}/tabs.json"))
assert tabs["exported"].endswith("Z"), tabs["exported"]
urls = [t["url"] for t in tabs["tabs"]]
assert urls == ["https://a.example/2", "https://a.example/1", "https://b.example/",
                "https://vanagon.example/westy", "https://vanagon.example/syncro"], urls
assert tabs["tabs"][0] == {"device": "Jamies iPhone", "group": None, "title": "Newer tab",
                           "url": "https://a.example/2", "last_viewed": "2026-10-11T09:10:00Z"}, tabs["tabs"][0]
assert tabs["tabs"][1]["title"] == 'Old "quoted" tab'
assert tabs["tabs"][2]["title"] == "" and tabs["tabs"][2]["last_viewed"] is None
assert tabs["tabs"][3] == {"device": None, "group": "Vanagon", "title": "Westy",
                           "url": "https://vanagon.example/westy", "last_viewed": None}, tabs["tabs"][3]
assert json.load(open(f"{out}/tabs/2026-10-11.json")) == tabs, "today's snapshot isn't the current tabs"

day = json.load(open(f"{out}/history/2026-10-11.json"))
assert day["date"] == "2026-10-11"
assert day["visits"] == [
    {"time": "2026-10-11T09:10:00Z", "device": "synced", "title": "autumn pubs with rooms at DuckDuckGo",
     "url": "https://duckduckgo.com/?q=autumn+pubs+with+rooms"},
    {"time": "2026-10-11T09:11:01Z", "device": "synced", "title": "15 great small hotels",
     "url": "https://www.theguardian.com/travel/autumn-inns"},
    {"time": "2026-10-11T09:15:00Z", "device": "mac", "title": "Corsham House",
     "url": "https://www.corshamhouse.com/"},
], day["visits"]

days = sorted(f for f in os.listdir(f"{out}/history") if f.endswith(".json"))
assert len(days) == 30 and days[0] == "2026-09-12.json" and days[-1] == "2026-10-11.json", days
assert json.load(open(f"{out}/history/2026-09-12.json")) == {"date": "2026-09-12", "visits": []}
assert not os.path.exists(f"{out}/tabs/2026-09-01.json"), "old tab snapshots must go"
assert os.path.exists(f"{out}/history/notes.txt"), "only the export's own files are pruned"
PY
echo "PASS: tabs (iCloud + Tab Groups), today's snapshot and 30 days of history, nothing excluded"

grep -rq -e s3cret -e proton -e ts.net -e local.example -e pinned.example -e work.example "$out" \
  && fail "an excluded, sensitive or non-group URL left the Mac"
echo "PASS: excluded hosts, secret-bearing URLs and non-group folders never leave the Mac"

out="$WORK/fresh/safari-tabs" run || fail "a first run must create the folder"
[[ -f "$WORK/fresh/safari-tabs/tabs.json" ]] || fail "a first run wrote no tabs.json"
echo "PASS: a first run creates the folder"

before=$(stat -f %m "$out/history/2026-10-11.json")
sleep 1.1
run
[[ "$(stat -f %m "$out/history/2026-10-11.json")" == "$before" ]] \
  || fail "an unchanged history day was rewritten (Syncthing would resend it)"
echo "PASS: unchanged days aren't rewritten"

SAFARI_CONTAINER_DIR="$WORK/safari" SAFARI_HISTORY_DB="$WORK/History.db" \
  SAFARI_TABS_EXCLUDE="$WORK/missing" "$WORK/export" "$out" 2>"$WORK/err" \
  && fail "a missing exclude list must fail, not export everything"
grep -q missing "$WORK/err" || fail "the error doesn't name the exclude list"
SAFARI_CONTAINER_DIR="$WORK/nowhere" SAFARI_HISTORY_DB="$WORK/History.db" \
  SAFARI_TABS_EXCLUDE="$WORK/exclude" "$WORK/export" "$out" 2>"$WORK/err" \
  && fail "an unreadable database must fail, not write an empty list"
grep -q nowhere "$WORK/err" || fail "the error doesn't name the database"
echo "PASS: a missing exclude list or unreadable database fails loudly"

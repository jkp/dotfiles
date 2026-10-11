// Every iCloud device's open Safari tabs, as JSON for Alfred:
//
//   safari-tabs-export <out.json> [CloudTabs.db]
//
// A compiled binary, not a script, so Full Disk Access (which Safari's
// container needs) is granted to this one program rather than to sqlite3 or
// a shell, which would open every protected database to anything that runs
// them under launchd.
import Foundation
import SQLite3

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: safari-tabs-export <out.json> [CloudTabs.db]\n".data(using: .utf8)!)
    exit(2)
}
let out = URL(fileURLWithPath: args[1])
let dbPath = args.count > 2 ? args[2]
    : NSHomeDirectory() + "/Library/Containers/com.apple.Safari/Data/Library/Safari/CloudTabs.db"

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("safari-tabs-export: \(dbPath): \(message)\n".data(using: .utf8)!)
    exit(1)
}

var db: OpaquePointer?
guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
    fail(String(cString: sqlite3_errmsg(db)))
}
let sql = """
    SELECT d.device_name, t.title, t.url, t.last_viewed_time
    FROM cloud_tabs t JOIN cloud_tab_devices d USING (device_uuid)
    ORDER BY d.device_name, t.last_viewed_time DESC
    """
var stmt: OpaquePointer?
guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
    fail(String(cString: sqlite3_errmsg(db)))
}

let iso = ISO8601DateFormatter()
func text(_ column: Int32) -> String {
    sqlite3_column_text(stmt, column).map { String(cString: $0) } ?? ""
}
var tabs: [[String: Any]] = []
while sqlite3_step(stmt) == SQLITE_ROW {
    // Seconds since 2001-01-01; 0 for a tab never viewed on that device.
    let viewed = sqlite3_column_double(stmt, 3)
    tabs.append([
        "device": text(0),
        "title": text(1),
        "url": text(2),
        "last_viewed": viewed > 0 ? iso.string(from: Date(timeIntervalSinceReferenceDate: viewed)) : NSNull(),
    ])
}

let json = try JSONSerialization.data(
    withJSONObject: ["exported": iso.string(from: Date()), "tabs": tabs],
    options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
// Atomic, so Syncthing never sends a half-written file.
try json.write(to: out, options: .atomic)

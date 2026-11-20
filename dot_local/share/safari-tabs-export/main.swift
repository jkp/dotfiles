// Jamie's Safari, as JSON for Alfred, into <out> (a send-only Syncthing folder):
//
//   tabs.json                 open tabs: every iCloud device's, and each Tab Group's
//   tabs/YYYY-MM-DD.json      the day's last tabs.json
//   history/YYYY-MM-DD.json   that day's visits, every device; [] on a quiet day
//
// Only the last 30 days are kept: older files are deleted here, and Syncthing
// deletes them on orchestra. Hosts in the exclude list, and URLs carrying a
// secret (token=, #access_token=, ...), never leave the Mac. Private Browsing
// isn't in any of these databases.
//
//   safari-tabs-export <out>
//
// A compiled binary, not a script, so Full Disk Access (which Safari's data
// needs) is granted to this one program rather than to sqlite3 or a shell,
// which would open every protected database to anything that runs them under
// launchd. Paths and "now" are overridable for the tests.
import Foundation
import SQLite3

let keepDays = 30
let env = ProcessInfo.processInfo.environment
let home = NSHomeDirectory()
let containerDir = env["SAFARI_CONTAINER_DIR"]
    ?? home + "/Library/Containers/com.apple.Safari/Data/Library/Safari"
let historyPath = env["SAFARI_HISTORY_DB"] ?? home + "/Library/Safari/History.db"
let excludePath = env["SAFARI_TABS_EXCLUDE"] ?? home + "/.config/safari-tabs-export/exclude"

let iso = ISO8601DateFormatter()
let now = env["SAFARI_TABS_NOW"].flatMap { iso.date(from: $0) } ?? Date()
let dayFormat = DateFormatter()
dayFormat.locale = Locale(identifier: "en_US_POSIX")
dayFormat.dateFormat = "yyyy-MM-dd"

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: safari-tabs-export <out-dir>\n".data(using: .utf8)!)
    exit(2)
}
let out = URL(fileURLWithPath: CommandLine.arguments[1])

func fail(_ path: String, _ message: String) -> Never {
    FileHandle.standardError.write("safari-tabs-export: \(path): \(message)\n".data(using: .utf8)!)
    exit(1)
}

// --- what never leaves the Mac ------------------------------------------------

guard let excludeText = try? String(contentsOfFile: excludePath, encoding: .utf8) else {
    fail(excludePath, "can't read the exclude list (refusing to export without one)")
}
let excludedHosts = excludeText.split(separator: "\n")
    .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
    .filter { !$0.isEmpty && !$0.hasPrefix("#") }
let secretParams: Set<String> = [
    "token", "access_token", "id_token", "refresh_token", "code", "key", "apikey", "api_key",
    "session", "sessionid", "sid", "auth", "sig", "signature", "password", "pass", "secret",
]

func allowed(_ url: String) -> Bool {
    guard let parts = URLComponents(string: url), let scheme = parts.scheme,
          scheme == "http" || scheme == "https" else { return false }
    let host = (parts.host ?? "").lowercased()
    if excludedHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return false }
    // Fragments too: OAuth's implicit flow puts the token after the #.
    let fragmentItems = parts.fragment.flatMap { URLComponents(string: "?" + $0)?.queryItems } ?? []
    return !((parts.queryItems ?? []) + fragmentItems).contains { secretParams.contains($0.name.lowercased()) }
}

// --- reading ------------------------------------------------------------------

func rows(_ path: String, _ sql: String, _ args: [Double] = [], _ each: (OpaquePointer) -> Void) {
    var db: OpaquePointer?
    guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        fail(path, String(cString: sqlite3_errmsg(db)))
    }
    defer { sqlite3_close(db) }
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
        fail(path, String(cString: sqlite3_errmsg(db)))
    }
    defer { sqlite3_finalize(stmt) }
    for (i, arg) in args.enumerated() { sqlite3_bind_double(stmt, Int32(i + 1), arg) }
    while sqlite3_step(stmt) == SQLITE_ROW { each(stmt!) }
}

func text(_ stmt: OpaquePointer, _ column: Int32) -> String {
    sqlite3_column_text(stmt, column).map { String(cString: $0) } ?? ""
}

// Safari's times are seconds since 2001-01-01; 0 is "never".
func time(_ stmt: OpaquePointer, _ column: Int32) -> Any {
    let t = sqlite3_column_double(stmt, column)
    return t > 0 ? iso.string(from: Date(timeIntervalSinceReferenceDate: t)) : NSNull()
}

var tabs: [[String: Any]] = []
rows(containerDir + "/CloudTabs.db", """
    SELECT d.device_name, t.title, t.url, t.last_viewed_time
    FROM cloud_tabs t JOIN cloud_tab_devices d USING (device_uuid)
    ORDER BY d.device_name, t.last_viewed_time DESC
    """) { s in
    tabs.append(["device": text(s, 0), "group": NSNull(), "title": text(s, 1),
                 "url": text(s, 2), "last_viewed": time(s, 3)])
}
// Named Tab Groups: visible top-level folders. Hidden roots are windows'
// local/private tabs, subtype 2 are profiles.
rows(containerDir + "/SafariTabs.db", """
    SELECT g.title, t.title, t.url
    FROM bookmarks t JOIN bookmarks g ON t.parent = g.id
    WHERE g.parent = 0 AND g.type = 1 AND g.subtype = 0 AND g.hidden = 0 AND g.special_id = 0
      AND t.type = 0 AND t.deleted = 0 AND t.hidden = 0
    ORDER BY g.title, t.order_index
    """) { s in
    tabs.append(["device": NSNull(), "group": text(s, 0), "title": text(s, 1),
                 "url": text(s, 2), "last_viewed": NSNull()])
}
tabs = tabs.filter { allowed($0["url"] as! String) }

let calendar = Calendar.current
let firstDay = calendar.date(byAdding: .day, value: -(keepDays - 1), to: calendar.startOfDay(for: now))!
var visitsByDay: [String: [[String: Any]]] = [:]
for offset in 0..<keepDays {
    visitsByDay[dayFormat.string(from: calendar.date(byAdding: .day, value: offset, to: firstDay)!)] = []
}
// A redirect's source visit (one with a destination) wasn't a page Jamie read.
rows(historyPath, """
    SELECT v.visit_time, v.title, i.url, v.origin
    FROM history_visits v JOIN history_items i ON i.id = v.history_item
    WHERE v.visit_time >= ? AND v.visit_time < ? AND v.load_successful = 1
      AND v.synthesized = 0 AND v.redirect_destination IS NULL
    ORDER BY v.visit_time
    """, [firstDay.timeIntervalSinceReferenceDate, now.timeIntervalSinceReferenceDate]) { s in
    let url = text(s, 2)
    guard allowed(url) else { return }
    let day = dayFormat.string(from: Date(timeIntervalSinceReferenceDate: sqlite3_column_double(s, 0)))
    visitsByDay[day]?.append(["time": time(s, 0), "device": sqlite3_column_int(s, 3) == 0 ? "mac" : "synced",
                              "title": text(s, 1), "url": url])
}

// --- writing ------------------------------------------------------------------

// Atomic, so Syncthing never sends a half-written file; skipped when nothing
// changed, so it doesn't resend 30 days of history every 10 minutes.
func write(_ object: Any, _ url: URL) throws {
    let data = try JSONSerialization.data(
        withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    if (try? Data(contentsOf: url)) == data { return }
    try data.write(to: url, options: .atomic)
}

let fm = FileManager.default
let today = dayFormat.string(from: now)
for dir in ["tabs", "history"] {
    try fm.createDirectory(at: out.appendingPathComponent(dir), withIntermediateDirectories: true)
}
let current: [String: Any] = ["exported": iso.string(from: now), "tabs": tabs]
try write(current, out.appendingPathComponent("tabs.json"))
try write(current, out.appendingPathComponent("tabs/\(today).json"))
for (day, visits) in visitsByDay {
    try write(["date": day, "visits": visits], out.appendingPathComponent("history/\(day).json"))
}

let oldest = dayFormat.string(from: firstDay)
for dir in ["tabs", "history"] {
    for name in try fm.contentsOfDirectory(atPath: out.appendingPathComponent(dir).path)
    where name.range(of: #"^\d{4}-\d{2}-\d{2}\.json$"#, options: .regularExpression) != nil
        && name < oldest + ".json" {
        try fm.removeItem(at: out.appendingPathComponent("\(dir)/\(name)"))
    }
}

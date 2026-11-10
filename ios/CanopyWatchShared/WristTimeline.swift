// Shared by the watch app and its widget extension (both targets compile this
// file). It mirrors lib/services/wrist/wrist_timeline.dart, which is the
// contract: Dart computes every state; Swift only picks the entry whose `at`
// has passed. NEVER add scheduling logic here (WATCH-RESEARCH pitfall 6).

import Foundation

let wristSchemaVersion = 1

/// App Group shared by the watch app (which receives the snapshot over
/// WatchConnectivity) and the widget extension (which renders complications).
let wristAppGroup = "group.com.danjjohnson.canopy"

enum WristStateKind: String, Codable {
  case noSchedule, preStart, active, overdue, gap, dayComplete
}

enum WristChunkKind: String, Codable {
  case work, commitment, shortBreak, longBreak, meal

  var isBreak: Bool { self == .shortBreak || self == .longBreak }

  /// SF Symbol for the circular/corner complications.
  var symbol: String {
    switch self {
    case .work: return "leaf.fill"
    case .commitment: return "person.2.fill"
    case .shortBreak: return "cup.and.saucer.fill"
    case .longBreak: return "figure.walk"
    case .meal: return "fork.knife"
    }
  }
}

private func date(_ ms: Double) -> Date { Date(timeIntervalSince1970: ms / 1000) }

struct WristChunk: Codable, Hashable {
  let id: String
  let kind: WristChunkKind
  let title: String
  let startAt: Double
  let endAt: Double
  let canComplete: Bool
  let canSkip: Bool

  var start: Date { date(startAt) }
  var end: Date { date(endAt) }
}

struct WristEntry: Codable, Hashable {
  let at: Double
  let state: WristStateKind
  let current: WristChunk?
  let next: WristChunk?

  var date: Date { Date(timeIntervalSince1970: at / 1000) }
}

struct WristTimeline: Codable, Hashable {
  let schemaVersion: Int
  let dateYmd: String
  let generatedAt: Double
  let utcOffsetMinutes: Int
  let entries: [WristEntry]

  var generated: Date { Date(timeIntervalSince1970: generatedAt / 1000) }

  /// The one rule the watch runs: the last entry whose instant has passed.
  /// Before the first entry (a snapshot from the future, e.g. after a clock
  /// change) there is nothing honest to show.
  func entry(at now: Date) -> WristEntry? {
    entries.last { $0.date <= now }
  }

  static func decode(_ json: String) -> WristTimeline? {
    guard let data = json.data(using: .utf8),
      let t = try? JSONDecoder().decode(WristTimeline.self, from: data),
      t.schemaVersion == wristSchemaVersion
    else { return nil }
    return t
  }
}

/// The watch's last snapshot, kept in the App Group so the complication can
/// render with the phone out of range (WRIST-06).
enum WristStore {
  private static var url: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: wristAppGroup)?
      .appendingPathComponent("wrist-timeline.json")
  }

  static func loadJSON() -> String? {
    guard let url, let data = try? Data(contentsOf: url) else { return nil }
    return String(data: data, encoding: .utf8)
  }

  static func load() -> WristTimeline? {
    loadJSON().flatMap(WristTimeline.decode)
  }

  /// Saves [json] if it decodes and is not older than what is stored.
  /// Returns the timeline if it was saved.
  @discardableResult
  static func save(_ json: String) -> WristTimeline? {
    guard let incoming = WristTimeline.decode(json), let url else { return nil }
    if let existing = load(), existing.generatedAt > incoming.generatedAt { return nil }
    do {
      try json.data(using: .utf8)?.write(to: url, options: .atomic)
      return incoming
    } catch {
      return nil
    }
  }
}

// MARK: - Display strings shared by the app screen and the complications

extension WristEntry {
  /// The headline: what you are doing, or what is coming.
  var headline: String {
    switch state {
    case .active, .overdue: return current?.title ?? "Canopy"
    case .preStart, .gap: return next?.title ?? "Canopy"
    case .dayComplete: return "Day complete"
    case .noSchedule: return "Check in on iPhone"
    }
  }

  /// A short kicker above the headline.
  var kicker: String {
    switch state {
    case .active: return (current?.kind.isBreak ?? false) ? "RESTING" : "NOW"
    case .overdue: return "RUNNING OVER"
    case .preStart: return "FIRST UP"
    case .gap: return "UP NEXT"
    case .dayComplete: return "DONE"
    case .noSchedule: return "CANOPY"
    }
  }
}

// MARK: - Wrist taps (Phase 40)

/// A Complete/Skip tapped on the watch. Same JSON as Dart's `WristAction`
/// (lib/services/wrist/wrist_outbox.dart), which parses it on the phone.
struct WristTap: Codable, Hashable {
  let id: String
  let chunkId: String
  let kind: String  // "complete" | "skip"
  let tappedAt: Double
  let dateYmd: String

  var json: String? {
    (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) }
  }
}

/// Taps the phone has not yet reflected. Shown as an overlay ("Sent ✓") on top
/// of the snapshot — the watch never edits the schedule itself (research
/// pitfall 7) — and dropped as soon as a snapshot no longer offers that chunk
/// an action (the phone applied it, or dropped it), or the day changes.
enum WristPending {
  private static var url: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: wristAppGroup)?
      .appendingPathComponent("wrist-pending.json")
  }

  static func load() -> [WristTap] {
    guard let url, let data = try? Data(contentsOf: url),
      let taps = try? JSONDecoder().decode([WristTap].self, from: data)
    else { return [] }
    return taps
  }

  static func save(_ taps: [WristTap]) {
    guard let url, let data = try? JSONEncoder().encode(taps) else { return }
    try? data.write(to: url, options: .atomic)
  }

  static func add(_ tap: WristTap) { save(load() + [tap]) }

  /// Keeps only taps whose chunk is still actionable in [timeline].
  static func reconcile(with timeline: WristTimeline) {
    let actionable = Set(
      timeline.entries.flatMap { [$0.current, $0.next] }.compactMap { $0 }
        .filter { $0.canSkip }.map(\.id))
    save(load().filter { $0.dateYmd == timeline.dateYmd && actionable.contains($0.chunkId) })
  }

  static func isPending(_ chunkId: String) -> Bool { load().contains { $0.chunkId == chunkId } }
}

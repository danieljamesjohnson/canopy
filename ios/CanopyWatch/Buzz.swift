import Foundation
import UserNotifications

/// Phase 41: an optional, opt-in buzz when a chunk starts.
///
/// Scheduled BY THE WATCH from the snapshot it already holds, so it needs no
/// phone, no push and no new Dart logic: every "active" entry in the future
/// gets one local notification at its instant. Rescheduled whenever a new
/// snapshot arrives (and when the toggle changes), so a moved chunk never
/// leaves an orphan behind. Off by default — the owner asked for a glance,
/// not a buzz ("a buzz alert won't be enough"); this is an add-on.
enum Buzz {
  private static let prefix = "canopy-chunk-"
  private static let key = "buzzAtChunkChanges"
  private static var defaults: UserDefaults { UserDefaults(suiteName: wristAppGroup) ?? .standard }

  static var enabled: Bool {
    get { defaults.bool(forKey: key) }
    set { defaults.set(newValue, forKey: key) }
  }

  /// Turns the buzz on or off; asks for permission the first time.
  static func setEnabled(_ on: Bool, timeline: WristTimeline?, completion: @escaping (Bool) -> Void) {
    guard on else {
      enabled = false
      reschedule(timeline)
      return completion(false)
    }
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
      enabled = granted
      reschedule(timeline)
      DispatchQueue.main.async { completion(granted) }
    }
  }

  static func reschedule(_ timeline: WristTimeline?, now: Date = Date()) {
    let center = UNUserNotificationCenter.current()
    center.getPendingNotificationRequests { requests in
      let ours = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
      center.removePendingNotificationRequests(withIdentifiers: ours)
      guard enabled, let timeline else { return }

      // watchOS keeps at most 64 pending; a Canopy day is well under that.
      let starts = timeline.entries.filter { $0.state == .active && $0.date > now }.prefix(60)
      for entry in starts {
        guard let c = entry.current else { continue }
        let content = UNMutableNotificationContent()
        content.title = c.title
        let until = c.end.formatted(date: .omitted, time: .shortened)
        if let n = entry.next {
          content.body = "Until \(until) · then \(n.title)"
        } else {
          content.body = "Until \(until)"
        }
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
          timeInterval: max(1, entry.date.timeIntervalSince(now)), repeats: false)
        center.add(
          UNNotificationRequest(identifier: prefix + c.id, content: content, trigger: trigger))
      }
    }
  }
}

import Flutter
import Foundation
import WatchConnectivity

/// The phone end of the watch link (v1.7 Phase 39).
///
/// Dart (`lib/services/wrist/wrist_sync.dart`) calls `sendTimeline` on the
/// `canopy/watch` channel with the JSON of today's wrist timeline whenever it
/// changes. This forwards it with:
/// - `updateApplicationContext`: latest-wins, delivered opportunistically
///   even while the watch is unreachable; and
/// - `transferCurrentComplicationUserInfo` when the complication is on the
///   active face, which wakes the watch app promptly to reload it (budgeted by
///   watchOS, about 50 a day).
///
/// Schedule logic never lives here: this is a pipe.
final class WatchBridge: NSObject, WCSessionDelegate {
  static let shared = WatchBridge()

  private var latest: String?
  private var channel: FlutterMethodChannel?

  func activate() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "canopy/watch", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      switch call.method {
      case "sendTimeline":
        guard let json = call.arguments as? String else {
          return result(FlutterError(code: "bad-args", message: "expected a JSON string", details: nil))
        }
        self.latest = json
        self.flush()
        result(nil)
      case "status":
        result(self.status())
      case "outboxPending":
        result(WristOutbox.pending())
      case "outboxRemove":
        if let id = call.arguments as? String { WristOutbox.remove(id) }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  private func status() -> [String: Any] {
    guard WCSession.isSupported() else { return ["supported": false] }
    let s = WCSession.default
    return [
      "supported": true,
      "activated": s.activationState == .activated,
      "paired": s.isPaired,
      "installed": s.isWatchAppInstalled,
      "complicationEnabled": s.isComplicationEnabled,
      "remainingComplicationTransfers": s.remainingComplicationUserInfoTransfers,
      "reachable": s.isReachable,
    ]
  }

  /// Sends [latest] if the session can carry it. Called on every Dart send,
  /// on activation and when the watch app is (re)installed, so a timeline
  /// produced before the session was ready is never lost.
  private func flush() {
    guard let json = latest, WCSession.isSupported() else { return }
    let s = WCSession.default
    guard s.activationState == .activated, s.isPaired, s.isWatchAppInstalled else { return }
    let payload: [String: Any] = ["timeline": json]
    do {
      try s.updateApplicationContext(payload)
    } catch {
      NSLog("canopy watch: updateApplicationContext failed: \(error)")
    }
    if s.isComplicationEnabled, s.remainingComplicationUserInfoTransfers > 0 {
      s.transferCurrentComplicationUserInfo(payload)
    }
  }

  // MARK: WCSessionDelegate

  func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    DispatchQueue.main.async { self.flush() }
  }

  func sessionWatchStateDidChange(_ session: WCSession) {
    DispatchQueue.main.async { self.flush() }
  }

  // MARK: Wrist taps (Phase 40)

  /// Reachable path: the watch's sendMessage. Apple wakes this app in the
  /// background to receive it. The tap is on disk before we reply, so the
  /// watch's "sent" means "the phone has it".
  func session(
    _ session: WCSession, didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    let ok = accept(message)
    replyHandler(["ok": ok])
  }

  /// Unreachable path: transferUserInfo, queued by watchOS and delivered
  /// even while this app is suspended.
  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    _ = accept(userInfo)
  }

  private func accept(_ payload: [String: Any]) -> Bool {
    guard let json = payload["action"] as? String, WristOutbox.add(json) else { return false }
    // If Dart is alive, have it replay now; otherwise it drains at its next
    // start or resume (WristOutboxCoordinator).
    DispatchQueue.main.async { self.channel?.invokeMethod("outboxChanged", arguments: nil) }
    return true
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    // The user switched watches; activate for the new one.
    session.activate()
  }
}

/// One JSON file per wrist tap, written atomically, never Hive: a Hive write
/// off Dart's main isolate risks corruption (WATCH-RESEARCH pitfall 1). Dart
/// reads these with `outboxPending` and deletes each once applied or dropped.
enum WristOutbox {
  private static var dir: URL? {
    guard
      let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first
    else { return nil }
    let d = base.appendingPathComponent("wrist-outbox", isDirectory: true)
    try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    return d
  }

  /// File-name-safe form of an action id (the watch sends a UUID).
  private static func file(_ id: String) -> URL? {
    let safe = id.filter { $0.isLetter || $0.isNumber || $0 == "-" }
    guard !safe.isEmpty else { return nil }
    return dir?.appendingPathComponent("\(safe).json")
  }

  static func add(_ json: String) -> Bool {
    guard let data = json.data(using: .utf8),
      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let id = obj["id"] as? String, let url = file(id)
    else { return false }
    do {
      try data.write(to: url, options: .atomic)
      return true
    } catch {
      NSLog("canopy watch: outbox write failed: \(error)")
      return false
    }
  }

  static func pending() -> [String] {
    guard let dir,
      let files = try? FileManager.default.contentsOfDirectory(
        at: dir, includingPropertiesForKeys: nil)
    else { return [] }
    return files.filter { $0.pathExtension == "json" }
      .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
  }

  static func remove(_ id: String) {
    guard let url = file(id) else { return }
    try? FileManager.default.removeItem(at: url)
  }
}

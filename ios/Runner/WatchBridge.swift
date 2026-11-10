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

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    // The user switched watches; activate for the new one.
    session.activate()
  }
}

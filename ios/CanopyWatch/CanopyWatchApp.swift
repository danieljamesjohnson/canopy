import SwiftUI
import WatchConnectivity
import WatchKit
import WidgetKit

@main
struct CanopyWatchApp: App {
  @WKApplicationDelegateAdaptor private var delegate: WatchAppDelegate

  var body: some Scene {
    WindowGroup {
      NowView(model: delegate.model)
    }
  }
}

/// Holds the latest snapshot for the app's own screen, plus taps not yet
/// reflected by the phone.
final class WristModel: ObservableObject {
  @Published var timeline: WristTimeline? = WristStore.load()
  @Published var pending: [WristTap] = WristPending.load()

  func isPending(_ chunkId: String) -> Bool { pending.contains { $0.chunkId == chunkId } }

  /// Complete/Skip from the wrist (Phase 40). sendMessage when the phone is
  /// reachable (it wakes the iPhone app, which writes the tap to its outbox
  /// before replying); otherwise, or if that fails, transferUserInfo, which
  /// watchOS queues and delivers later. Either way the phone replays the tap
  /// with ITS time, so a late delivery changes nothing.
  func tap(_ chunk: WristChunk, kind: String) {
    guard let timeline else { return }
    let tap = WristTap(
      id: UUID().uuidString, chunkId: chunk.id, kind: kind,
      tappedAt: Date().timeIntervalSince1970 * 1000, dateYmd: timeline.dateYmd)
    guard let json = tap.json else { return }
    WristPending.add(tap)
    pending = WristPending.load()
    WidgetCenter.shared.reloadAllTimelines()
    WKInterfaceDevice.current().play(.success)

    let payload: [String: Any] = ["action": json]
    let session = WCSession.default
    guard session.activationState == .activated else { return }
    if session.isReachable {
      // A reply handler is required: the phone implements only the
      // didReceiveMessage:replyHandler: variant, and replies once the tap is
      // safely on its disk.
      session.sendMessage(
        payload,
        replyHandler: { reply in
          if (reply["ok"] as? Bool) != true { session.transferUserInfo(payload) }
        },
        errorHandler: { _ in session.transferUserInfo(payload) })
    } else {
      session.transferUserInfo(payload)
    }
  }
}

/// Receives the phone's timeline over WatchConnectivity, in the foreground or
/// when watchOS wakes the app in the background for it
/// (WKWatchConnectivityRefreshBackgroundTask), stores it in the App Group and
/// reloads the complications so they flip without the phone (WRIST-04/06).
final class WatchAppDelegate: NSObject, WKApplicationDelegate, WCSessionDelegate {
  let model = WristModel()
  private var pendingTasks: [WKWatchConnectivityRefreshBackgroundTask] = []
  private var contentObservation: NSKeyValueObservation?

  func applicationDidFinishLaunching() {
    activate()
  }

  private func activate() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    if session.delegate == nil { session.delegate = self }
    if session.activationState != .activated { session.activate() }
    if contentObservation == nil {
      contentObservation = session.observe(\.hasContentPending) { [weak self] _, _ in
        DispatchQueue.main.async { self?.completeTasksIfDrained() }
      }
    }
  }

  func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
    for task in backgroundTasks {
      if let wc = task as? WKWatchConnectivityRefreshBackgroundTask {
        pendingTasks.append(wc)
        activate()
      } else {
        task.setTaskCompletedWithSnapshot(false)
      }
    }
    completeTasksIfDrained()
  }

  private func completeTasksIfDrained() {
    guard WCSession.default.activationState == .activated,
      !WCSession.default.hasContentPending
    else { return }
    pendingTasks.forEach { $0.setTaskCompletedWithSnapshot(false) }
    pendingTasks.removeAll()
  }

  // MARK: WCSessionDelegate

  func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    // A context that arrived while we were not running.
    ingest(session.receivedApplicationContext)
    DispatchQueue.main.async { self.completeTasksIfDrained() }
  }

  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    ingest(applicationContext)
  }

  /// transferCurrentComplicationUserInfo lands here.
  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    ingest(userInfo)
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    ingest(message)
  }

  private func ingest(_ payload: [String: Any]) {
    guard let json = payload["timeline"] as? String,
      let saved = WristStore.save(json)
    else { return }
    WristPending.reconcile(with: saved)
    WidgetCenter.shared.reloadAllTimelines()
    Buzz.reschedule(saved)
    DispatchQueue.main.async {
      self.model.timeline = saved
      self.model.pending = WristPending.load()
    }
  }
}

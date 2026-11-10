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

/// Holds the latest snapshot for the app's own screen.
final class WristModel: ObservableObject {
  @Published var timeline: WristTimeline? = WristStore.load()
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
    WidgetCenter.shared.reloadAllTimelines()
    DispatchQueue.main.async { self.model.timeline = saved }
  }
}

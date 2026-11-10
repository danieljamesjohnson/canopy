import SwiftUI
import WidgetKit

// The core deliverable (WRIST-04): a complication that says what you are
// doing right now, flips at every chunk boundary by itself (one WidgetKit
// timeline entry per Dart entry, no reloads needed), and counts down live
// with Text(timerInterval:).

struct CanopyWidgetEntry: TimelineEntry {
  let date: Date
  let entry: WristEntry?
  let relevance: TimelineEntryRelevance?
}

struct CanopyProvider: TimelineProvider {
  func placeholder(in context: Context) -> CanopyWidgetEntry {
    CanopyWidgetEntry(date: Date(), entry: Self.sample, relevance: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (CanopyWidgetEntry) -> Void) {
    let now = Date()
    let live = WristStore.load()?.entry(at: now)
    completion(CanopyWidgetEntry(date: now, entry: live ?? Self.sample, relevance: nil))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<CanopyWidgetEntry>) -> Void) {
    completion(Self.timeline(from: WristStore.load(), now: Date()))
  }

  /// One widget entry for "now" plus one per future Dart entry. The policy is
  /// .never: the timeline already runs to the next midnight (where it turns
  /// to "Check in on iPhone"), and the watch app reloads it whenever the
  /// phone sends a change.
  static func timeline(from t: WristTimeline?, now: Date) -> Timeline<CanopyWidgetEntry> {
    guard let t else {
      return Timeline(entries: [CanopyWidgetEntry(date: now, entry: nil, relevance: nil)], policy: .never)
    }
    var out: [CanopyWidgetEntry] = []
    let future = t.entries.filter { $0.date > now }
    if let current = t.entry(at: now) {
      out.append(make(current, from: now, until: future.first?.date))
    } else {
      out.append(CanopyWidgetEntry(date: now, entry: nil, relevance: nil))
    }
    for (i, e) in future.enumerated() {
      let until = i + 1 < future.count ? future[i + 1].date : nil
      out.append(make(e, from: e.date, until: until))
    }
    return Timeline(entries: out, policy: .never)
  }

  /// Smart Stack ordering: a running chunk is the most relevant thing on the
  /// wrist; an upcoming one less so; a finished day not at all.
  private static func make(_ e: WristEntry, from: Date, until: Date?) -> CanopyWidgetEntry {
    let score: Float
    switch e.state {
    case .active, .overdue: score = 1.0
    case .preStart, .gap: score = 0.5
    case .dayComplete, .noSchedule: score = 0
    }
    let duration = until.map { $0.timeIntervalSince(from) } ?? 0
    return CanopyWidgetEntry(
      date: from, entry: e,
      relevance: TimelineEntryRelevance(score: score, duration: max(0, duration)))
  }

  static let sample = WristEntry(
    at: Date().timeIntervalSince1970 * 1000,
    state: .active,
    current: WristChunk(
      id: "sample", kind: .work, title: "Deep work",
      startAt: Date().addingTimeInterval(-7 * 60).timeIntervalSince1970 * 1000,
      endAt: Date().addingTimeInterval(18 * 60).timeIntervalSince1970 * 1000,
      canComplete: true, canSkip: true),
    next: WristChunk(
      id: "sample-b", kind: .shortBreak, title: "Short break",
      startAt: Date().addingTimeInterval(18 * 60).timeIntervalSince1970 * 1000,
      endAt: Date().addingTimeInterval(23 * 60).timeIntervalSince1970 * 1000,
      canComplete: false, canSkip: true))
}

struct CanopyComplication: Widget {
  let kind = "CanopyNow"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: CanopyProvider()) { e in
      CanopyComplicationView(entry: e)
    }
    .configurationDisplayName("Canopy · Now")
    .description("What you're doing right now, and what's next.")
    .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline, .accessoryCorner])
  }
}

struct CanopyComplicationView: View {
  @Environment(\.widgetFamily) private var environmentFamily
  let entry: CanopyWidgetEntry
  /// Set only by the watch app's DEBUG gallery, which renders these views
  /// outside WidgetKit for Simulator screenshots.
  var familyOverride: WidgetFamily? = nil

  private var family: WidgetFamily { familyOverride ?? environmentFamily }

  var body: some View {
    Group {
      switch family {
      case .accessoryCircular: circular
      case .accessoryInline: inline
      case .accessoryCorner: corner
      default: rectangular
      }
    }
    .containerBackground(for: .widget) { Color.clear }
  }

  private var e: WristEntry? { entry.entry }

  /// The running chunk was completed/skipped on the wrist and the phone has
  /// not confirmed yet (Phase 40). An overlay only; the snapshot is untouched.
  private var sent: Bool {
    guard let c = e?.current else { return false }
    return WristPending.isPending(c.id)
  }

  /// The timed chunk this entry is about: the running one, or the next one.
  private var focus: WristChunk? {
    guard let e else { return nil }
    switch e.state {
    case .active, .overdue: return e.current
    case .preStart, .gap: return e.next
    default: return nil
    }
  }

  // "Deep work" / "17:52 left" / "then Short break"
  private var rectangular: some View {
    VStack(alignment: .leading, spacing: 1) {
      if let e {
        Text(sent ? "SENT ✓" : e.kicker)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.secondary)
          .widgetAccentable()
        Text(e.headline).font(.headline).lineLimit(1)
        switch e.state {
        case .active:
          if let c = e.current {
            HStack(spacing: 3) {
              Text(timerInterval: entry.date...max(entry.date, c.end), countsDown: true)
                .monospacedDigit()
              Text("left")
            }
            .font(.system(size: 14))
          }
        case .overdue:
          if let c = e.current {
            HStack(spacing: 3) { Text("ended"); Text(c.end, style: .time) }.font(.system(size: 14))
          }
        case .preStart, .gap:
          if let n = e.next {
            HStack(spacing: 3) { Text("at"); Text(n.start, style: .time) }.font(.system(size: 14))
          }
        case .dayComplete, .noSchedule:
          EmptyView()
        }
        if (e.state == .active || e.state == .overdue), let n = e.next {
          Text("then \(n.title)").font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
        }
      } else {
        Text("Canopy").font(.headline)
        Text("Open on iPhone").font(.system(size: 14)).foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var circular: some View {
    ZStack {
      if let e, e.state == .active, let c = e.current {
        ProgressView(timerInterval: c.start...c.end, countsDown: true) {
          Image(systemName: c.kind.symbol)
        }
        .progressViewStyle(.circular)
      } else {
        AccessoryWidgetBackground()
        Image(systemName: focus?.kind.symbol ?? "checkmark")
          .font(.title3)
      }
    }
    .widgetAccentable()
  }

  // One line: "Deep work · 17:52"
  private var inline: some View {
    Group {
      if let e, e.state == .active, let c = e.current {
        Text("\(c.title) · ") + Text(timerInterval: entry.date...max(entry.date, c.end), countsDown: true)
      } else if let e {
        Text(e.headline)
      } else {
        Text("Canopy")
      }
    }
  }

  private var corner: some View {
    Image(systemName: focus?.kind.symbol ?? "leaf.fill")
      .font(.title3)
      .widgetAccentable()
      .widgetLabel {
        if let e, e.state == .active, let c = e.current {
          Text(timerInterval: entry.date...max(entry.date, c.end), countsDown: true)
        } else if let e {
          Text(e.headline)
        } else {
          Text("Canopy")
        }
      }
  }
}


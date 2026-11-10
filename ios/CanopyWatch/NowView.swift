import SwiftUI

/// The watch app's one screen: what you are doing now, and what is next.
/// Re-evaluated every minute (entries only change on minute boundaries); the
/// countdown itself is a live `Text(timerInterval:)`.
struct NowView: View {
  @ObservedObject var model: WristModel

  var body: some View {
    TimelineView(.everyMinute) { context in
      content(at: context.date)
    }
  }

  @ViewBuilder
  private func content(at now: Date) -> some View {
    if let timeline = model.timeline, let entry = timeline.entry(at: now) {
      ScrollView {
        VStack(alignment: .leading, spacing: 6) {
          Text(entry.kicker)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint(entry))
          Text(entry.headline)
            .font(.title3.weight(.semibold))
            .lineLimit(3)
          detail(entry, now: now)
          actions(entry)
          if let next = upNext(entry) {
            Divider().padding(.vertical, 2)
            Text("THEN").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 4) {
              Text(next.title).font(.footnote).lineLimit(2)
              Spacer(minLength: 2)
              Text(next.start, style: .time).font(.footnote).foregroundStyle(.secondary)
            }
          }
          // Debug footer (WATCH-RESEARCH pitfall 4): proves which snapshot
          // the watch is showing after a Re-check-in on the phone.
          Text("Synced \(timeline.generated.formatted(date: .omitted, time: .shortened))")
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    } else {
      VStack(spacing: 8) {
        Image(systemName: "leaf.fill").font(.title2).foregroundStyle(.orange)
        Text("Open Canopy on your iPhone to send today's plan.")
          .font(.footnote)
          .multilineTextAlignment(.center)
      }
    }
  }

  @ViewBuilder
  private func detail(_ entry: WristEntry, now: Date) -> some View {
    switch entry.state {
    case .active:
      if let c = entry.current {
        HStack(spacing: 4) {
          Text(timerInterval: now...max(now, c.end), countsDown: true)
            .monospacedDigit()
          Text("left").foregroundStyle(.secondary)
        }
        .font(.body)
        ProgressView(timerInterval: c.start...c.end, countsDown: false) {
          EmptyView()
        } currentValueLabel: {
          EmptyView()
        }
        .tint(tint(entry))
      }
    case .overdue:
      if let c = entry.current {
        HStack(spacing: 4) {
          Text("Ended")
          Text(c.end, style: .time)
        }
        .font(.footnote).foregroundStyle(.secondary)
      }
    case .preStart, .gap:
      if let n = entry.next {
        HStack(spacing: 4) {
          Text("Starts")
          Text(n.start, style: .time)
          Text("·")
          Text(timerInterval: now...max(now, n.start), countsDown: true).monospacedDigit()
        }
        .font(.footnote).foregroundStyle(.secondary)
      }
    case .dayComplete:
      Text("Nothing else scheduled today.").font(.footnote).foregroundStyle(.secondary)
    case .noSchedule:
      Text("No plan for today yet.").font(.footnote).foregroundStyle(.secondary)
    }
  }

  /// Complete/Skip for the chunk the screen is about (Phase 40). Same gates
  /// as the phone's live row, carried in the snapshot: breaks are skip-only.
  /// Once tapped, the buttons give way to "Sent" until the phone's next
  /// snapshot reflects it.
  @ViewBuilder
  private func actions(_ entry: WristEntry) -> some View {
    if let c = entry.current, entry.state == .active || entry.state == .overdue {
      if model.isPending(c.id) {
        Label("Sent to iPhone", systemImage: "checkmark.circle")
          .font(.footnote)
          .foregroundStyle(.green)
      } else if c.canComplete || c.canSkip {
        HStack(spacing: 6) {
          if c.canComplete {
            Button {
              model.tap(c, kind: "complete")
            } label: {
              Label("Done", systemImage: "checkmark")
            }
            .tint(.green)
          }
          if c.canSkip {
            Button {
              model.tap(c, kind: "skip")
            } label: {
              Label("Skip", systemImage: "forward.end")
            }
          }
        }
        .font(.footnote)
        .labelStyle(.titleAndIcon)
        .buttonStyle(.bordered)
      }
    }
  }

  /// "Then" is the following chunk, only when the headline is the current one.
  private func upNext(_ entry: WristEntry) -> WristChunk? {
    switch entry.state {
    case .active, .overdue: return entry.next
    default: return nil
    }
  }

  private func tint(_ entry: WristEntry) -> Color {
    let kind = entry.current?.kind ?? entry.next?.kind
    switch kind {
    case .shortBreak?, .longBreak?: return .teal
    case .commitment?: return .purple
    default: return .orange
    }
  }
}

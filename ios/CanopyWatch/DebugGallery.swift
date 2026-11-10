#if DEBUG
import SwiftUI
import WidgetKit

/// DEBUG-only: renders the complication views for EVERY entry of the current
/// timeline, outside WidgetKit, so the Simulator can be screenshotted
/// (simctl cannot place a complication on a face). Launch with
///   -CanopyTimelineFile /path/to/timeline.json  [-CanopyGallery 1]
/// The file is real Dart output (buildWristTimeline), so this checks the
/// Dart→Swift JSON contract as well as the layout.
enum DebugLaunch {
  static var timelineFile: String? { UserDefaults.standard.string(forKey: "CanopyTimelineFile") }
  static var gallery: Bool { UserDefaults.standard.bool(forKey: "CanopyGallery") }
  static var galleryFamily: String? { UserDefaults.standard.string(forKey: "CanopyFamily") }
  static var galleryStart: Int { UserDefaults.standard.integer(forKey: "CanopyStart") }

  static func timeline() -> WristTimeline? {
    guard let path = timelineFile, let json = try? String(contentsOfFile: path, encoding: .utf8)
    else { return nil }
    return WristTimeline.decode(json)
  }
}

struct DebugGallery: View {
  let timeline: WristTimeline

  private var families: [(String, WidgetFamily, CGSize)] {
    let all: [(String, WidgetFamily, CGSize)] = [
      ("rectangular", .accessoryRectangular, CGSize(width: 180, height: 76)),
      ("circular", .accessoryCircular, CGSize(width: 50, height: 50)),
      ("inline", .accessoryInline, CGSize(width: 180, height: 20)),
      ("corner", .accessoryCorner, CGSize(width: 50, height: 50)),
    ]
    guard let only = DebugLaunch.galleryFamily else { return all }
    return all.filter { $0.0 == only }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        ForEach(Array(timeline.entries.enumerated()).dropFirst(DebugLaunch.galleryStart), id: \.offset) { _, e in
          Text(e.date.formatted(date: .omitted, time: .shortened) + " · " + e.state.rawValue)
            .font(.system(size: 10)).foregroundStyle(.secondary)
          ForEach(families, id: \.0) { name, family, size in
            CanopyComplicationView(
              entry: CanopyWidgetEntry(date: max(e.date, Date()), entry: e, relevance: nil),
              familyOverride: family
            )
            .frame(width: size.width, height: size.height, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.gray.opacity(0.4)))
          }
        }
      }
    }
  }
}
#endif

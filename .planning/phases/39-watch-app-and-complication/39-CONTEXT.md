# Phase 39: Watch App and Complication, Read-Only — Context

**Gathered:** 2026-11-10, autonomously (the owner is away). Source: `research/watch/OWNER-DECISIONS-2026-11-10.md`.
The owner's goal: *"look down at my watch and remind myself what im doing."* This phase is that feature.

## Decisions

- **D-39-01 Native SwiftUI, embedded in Runner.** Two new targets, added by a reviewable script
  (`tools/add-watch-targets.rb`) rather than Xcode clicks:
  - `CanopyWatch`: a single-target watchOS app, bundle `com.danjjohnson.canopy.watchkitapp`.
  - `CanopyWatchWidgets`: a WidgetKit extension, bundle `…watchkitapp.widgets`.

  Both target watchOS 10.0. The owner's Series 7 runs 26.3.
- **D-39-02 Our own channel, not the `watch_connectivity` plugin.** That plugin has no `transferUserInfo`, and it
  delivers into a Dart stream, which does not exist while the app is not running (research §1). The Swift
  `WatchBridge` is about 100 lines and is the only native code on the phone.
- **D-39-03 Transport.** `updateApplicationContext` (latest wins; it works while the watch is unreachable), plus
  `transferCurrentComplicationUserInfo` when the complication is on the active face and budget remains. The latter
  wakes the watch app to reload the complication promptly. The bridge caches the latest timeline and re-sends it on
  activation and on watch-app install.
- **D-39-04 When the phone sends.** `WristSync` listens to `ScheduleNotifier` and `GoalsNotifier`. Every schedule
  mutation already ends in `notifyListeners`: check-in, re-check-in, complete, skip, defer, calendar sync, meals and
  the day reset. A goal rename changes a title. The send is debounced (400 ms) and deduplicated on content, ignoring
  `generatedAt`.
- **D-39-05 The watch only picks entries.** `entries.last(where: at <= now)`. The widget timeline is one WidgetKit
  entry per Dart entry with policy `.never`. The Dart timeline already runs to the next midnight, so the complication
  flips at every chunk boundary with no phone and no reloads. The countdown is a live `Text(timerInterval:)`.
- **D-39-06 Families.**
  - `accessoryRectangular`: kicker, title, "17:52 left", "then Short break".
  - `accessoryCircular`: a progress ring with a kind symbol.
  - `accessoryInline`: "Deep work · 17:52".
  - `accessoryCorner`: a symbol plus a countdown label.
- **D-39-07 Smart Stack.** Every widget entry carries a `TimelineEntryRelevance`: 1.0 while a chunk runs, 0.5 before
  one, 0 once the day is done, with the duration set to the entry's span. This is the documented relevance path for
  watch widgets in the Smart Stack. A separate watchOS 26 `RelevanceConfiguration` widget was *not* added: one
  widget that is both the complication and the Smart Stack card is simpler, and the extra API buys nothing the
  scores do not already.
- **D-39-08 Offline.** The watch saves every snapshot to the App Group (`group.com.danjjohnson.canopy`) and renders
  from it, so the complication keeps flipping with the phone out of range (WRIST-06).
- **D-39-09 CI.** With a watch companion embedded, flutter_tools omits `-sdk` and refuses `flutter build ios
  --simulator` without a device id. CI's iOS job therefore moves to `flutter build ios --no-codesign` (a generic
  device build) and fetches the watchOS platform if the runner image lacks it.
- **D-39-10 Versions.** The watch Info.plists use `$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)` through
  `ios/Flutter/Watch.xcconfig`, which includes only `Generated.xcconfig`, never Pods. Xcode's ValidateEmbeddedBinary
  rejects an embedded watch app whose versions differ from the companion's.

## Owner-facing trap (carried from CLAUDE.md trap #4)

The watch shows **persisted** schedule output. Any watch UAT that judges schedule content must ⟳ Re-check-in on the
phone first, then confirm the watch's "Synced hh:mm" footer moved.

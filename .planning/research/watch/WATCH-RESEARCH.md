# Watch Research: Canopy on the wrist

**Researched:** 2026-11-09
**Mode:** Feasibility plus ecosystem
**Primary target:** **Apple Watch.** The owner's daily driver is an iPhone 15 Pro Max. Wear OS is secondary and is
practically irrelevant to him (see section 4).
**Overall confidence:** HIGH on platform facts (Apple docs and pub.dev, read on 2026-11-09). MEDIUM on how the
Flutter/Xcode build behaves with a watch target; that needs a spike on the Mac.

Legend: **[V]** means verified against a primary source cited at the end. **[A]** means an assumption or inference
that a spike should confirm.

---

## TL;DR

1. **Flutter cannot build the watch app.** Any watch UI is native SwiftUI in a watchOS target inside `ios/Runner.xcodeproj`.
   The Flutter iPhone app owns all state and talks to the watch over WatchConnectivity. [V]
2. **The cheapest real win is Tier 0, actionable chunk notifications.** iPhone notifications mirror to the watch for free,
   and their action buttons work there. On Series 9 / Ultra 2 or later, **Double Tap triggers the first nondestructive
   action**, so a pinch could mean Complete. [V] But Canopy **does not schedule any per-chunk notifications today**:
   only morning, mid-day and evening (IDs 0/1/2 in `notification_service.dart`). So Tier 0 is new work, not a toggle.
3. **The hardest problem is not the watch. It is writing a Complete/Skip that arrives while the Flutter UI is not
   running.** Canopy's state is Hive, in Dart, and its models extend `HiveObject`. hive_ce warns of **data corruption**
   when a box is used from a second isolate, and its `IsolatedHive` escape hatch **does not support `HiveObject`**. [V]
   Every tier that accepts a tap away from the open app (notification actions, watch app, Live Activity buttons)
   inherits this problem. Spike it first.
4. **Keep the engine single-sourced:** Dart precomputes a "wrist timeline", a list of `(instant, state)` entries built
   from `resolveNowState`, and ships it as JSON. Swift only picks the entry whose instant has passed. Swift never
   schedules anything.

---

## 0. What a watch actually needs (from the code)

- **Show:** the `NowState` from `resolveNowState` (`lib/screens/today/now_state.dart`): `PreStart`, `Active(current, next)`,
  `Overdue(overdue, next)`, `GapBeforeNext(next)` or `DayComplete`. For each chunk: kind (work / short break / long
  break / commitment or meeting), title (goal name or commitment name, resolved on the phone), start and end, and
  time left.
- **Do:** Complete and Skip, exactly as `live_row_card.dart` gates them. Work chunks and commitments get both. **Breaks
  get Skip only** (`showComplete: !isBreak`, `today_screen.dart:1044`). Defer is phone-only today, so leave it off the watch.
- **Hidden side effects of a tap** (`schedule_notifier.dart`). `markComplete` writes the schedule, appends a `CompletionLog`
  and recomputes habit streaks. **G-05** (`_absorbReclaimedTimeIntoNextBreak`) also moves the next break earlier, using
  the time from `_now()`. So a Complete that is replayed later, with a later clock, gives a different schedule. Any
  queued action must carry the moment it was tapped. **[V, from the code]**
- **Day boundary:** `_resetIfDayChanged` hides a schedule whose `dateYmd` is not today (local time). The watch must apply
  the same rule to its snapshot, or it will show yesterday's last chunk until the phone is opened.

---

## 1. Apple Watch: official position and real architecture

**Official position [V].** Flutter has no watchOS target. The tracking issue
[flutter/flutter#28901](https://github.com/flutter/flutter/issues/28901) ("Flutter support for Apple Watch") is
**open at P3**. Its pinned team comment (Jan 2023) says it would need a new embedder and buildroot work. The 2026
Flutter roadmap does not mention watches at all. The flutter.dev "Apple Watch" docs page now returns 404. A third-party
toolchain, `flutter-watchos` ([flutter_watchos](https://pub.dev/packages/flutter_watchos) 0.1.x, publisher
flutterwatch.dev, ~5 likes, "not affiliated with Google"), runs the engine on the watch. **Reject it.** It is an early,
single-vendor fork for a product with one user and a public work-sample repo. And it still wouldn't solve the hard
problem, which is keeping state on the phone.

**The architecture (standard, recommended):**

```
iPhone process                                   Watch (native, Swift)
┌───────────────────────────────┐                ┌──────────────────────────────┐
│ Dart: ScheduleNotifier (Hive) │                │ Watch app (SwiftUI)          │
│   └ WristSnapshotBuilder ─────┼─ MethodChannel │   reads snapshot, ticks clock│
│       (pure Dart, tested)     │   ▼            │   Complete/Skip → sendMessage│
│ Swift: WatchBridge (WCSession)├── WCSession ──►│ Watch widget ext (WidgetKit) │
│   updateApplicationContext    │◄── action ─────┤   complications/Smart Stack  │
│   didReceiveMessage/UserInfo  │                │   shares snapshot via        │
│     → outbox → Dart drains    │                │   watch-side App Group       │
└───────────────────────────────┘                └──────────────────────────────┘
```

- Create it in Xcode as a "Watch App for Existing iOS App" target. Its bundle ID must be a child of
  `com.danjjohnson.canopy`, e.g. `com.danjjohnson.canopy.watchkitapp`. It gets embedded in Runner. [A, standard Xcode
  behaviour; confirm in spike]
- **Plugin vs. our own channel. Recommendation: write our own small channel (~150 lines of Swift).**
  - [watch_connectivity](https://pub.dev/packages/watch_connectivity) **0.2.11** (rexios.dev, verified publisher, published
    ~2026-10-20, requires Flutter 3.44, SwiftPM support, 95 likes). It is actively maintained, but its API is
    `sendMessage`, `updateApplicationContext`, `isReachable`/`isPaired`, `messageStream` and `contextStream`.
    **It has no `transferUserInfo`**, which is the only guaranteed-delivery channel. [V]
  - [flutter_watch_os_connectivity](https://pub.dev/packages/flutter_watch_os_connectivity) **1.0.0**, published about
    3 years ago, iOS only. Its API is complete, but **treat it as unmaintained**. [V]
  - Both plugins deliver watch messages into a **Dart stream**. That only works while a Dart isolate is running, which
    is exactly what fails when the watch wakes a backgrounded iPhone app (below). A native `WCSessionDelegate` in
    `AppDelegate` can **persist the action before Dart exists**. That is the deciding reason. `watch_connectivity` is
    still a fine choice for a quick Phase-1 spike.
- **What crosses to the watch:** one JSON snapshot, sent with **`updateApplicationContext`**. It is
  "latest-wins", is delivered opportunistically when the watch next wakes, and works while unreachable. [V] Suggested shape:
  `{schemaVersion, dateYmd, generatedAt, tz, entries:[{at, state, chunk:{id,kind,title,startAt,endAt,canComplete,canSkip}, next:{…}}]}`.
  Use absolute instants (epoch ms), computed in Dart. Send it after **every** schedule mutation: generate, check-in,
  re-check-in, complete, skip, defer, calendar sync and day reset. A single hook on `ScheduleNotifier.notifyListeners`
  is the simplest. Debounce it.
- **How taps come back:**
  - **Reachable:** the watch calls `sendMessage`. Apple says a watch-side `sendMessage` "**wakes up the corresponding iOS
    app in the background and makes it reachable**". [V] The iPhone replies with a fresh snapshot.
  - **Unreachable:** for example, the phone is out of range, or the watch app is backgrounded. Fall back to
    `transferUserInfo`, which is queued, FIFO, and "continues even if the app is suspended". [V] The watch marks the chunk
    optimistically, so it shows "pending sync" until a snapshot confirms it.
  - The iPhone side **appends the action, with its tap timestamp, to a native outbox file**. Dart drains the outbox on
    launch, on resume (the `didChangeAppLifecycleState` hook already exists) and on a channel ping when the engine is live.
- **When the phone isn't reachable:** the watch keeps working from its last snapshot. The precomputed timeline still
  advances through chunk windows, because time is the only input. Taps queue. **Iron rule:** the watch never invents
  schedule changes such as the G-05 break move. It shows what the phone last said, plus local "pending" marks.

---

## 2. Complications, Smart Stack and Live Activities

**Watch complications and Smart Stack = WidgetKit [V].** `accessoryCircular`, `accessoryRectangular`, `accessoryInline` and
`accessoryCorner` widgets are complications on watchOS and Lock Screen widgets on iOS. The **watch** widget extension must
live inside a **watch app**: an iPhone-only app cannot put a complication on the watch. [A, consistent with the Apple
"creating accessory widgets" guide, which always pairs a watch widget extension with a watchOS app target.]

- **Timelines fit Canopy perfectly.** The day is known at check-in, so one timeline with an entry per chunk boundary covers
  the whole day, ending with a `DayComplete` entry. **`Text(timerInterval:)` and `ProgressView(timerInterval:)` count
  down live without reloads.** [V] That gives "Focus · 14:32 left" with zero budget spent.
- **Budget [V]:** "40 to 70 refreshes" a day for a frequently viewed widget. Reloads are **not counted** while the
  containing app is in the foreground or when the widget runs an app intent. A reload is only needed when the schedule
  *changes* (a tap or a sync), so a normal day uses a handful.
- **WCSession complication pushes [V]:** `transferCurrentComplicationUserInfo` gets **50/day**, and only if the complication
  is on the **active** face; otherwise the budget is 0. Use it only to push a changed snapshot from the phone.
- **Smart Stack relevance [V]:** `RelevanceConfiguration` / `relevance()` lets a watch widget surface itself in the
  Smart Stack, for example at chunk boundaries.
- **Interactive buttons in watch widgets:** buttons and toggles in widgets are App Intents. [V] Whether a *watch*
  complication button can reach the iPhone's Dart state is untested and **[A]**. Plan on "tap complication → opens watch
  app" instead.

**iPhone Live Activities: related, and possibly the best value-for-effort after Tier 0 [V].**
- "On Apple Watch, Live Activities **automatically appear in the Smart Stack** and as alerts using the compact
  presentation." Custom watch layout is opt-in via `supplementalActivityFamilies(.small)`. **No watch app needed.**
  The minimum OS is not stated in the text we read; it was announced as iOS 18 / watchOS 11. [A on version]
- Limits [V]: up to **8 hours** active, then ended (it stays on the Lock Screen for up to 4 more hours). A Canopy day is
  often longer than 8 hours, so start one activity per work block or restart it at check-in.
- Updating [V]: [live_activities](https://pub.dev/packages/live_activities) **2.6.0** (59 days old, 661 likes) needs a
  Swift widget extension plus an App Group, and states that a **killed or backgrounded app can't update the activity
  without APNs push**. Canopy has no server. Mitigation: render the countdown with `Text(timerInterval:)` so it needs no
  updates. Chunk-to-chunk transitions still need either an app-in-process update or a `LiveActivityIntent` (iOS 17+),
  which "the system runs in the app's process". That puts us back at the Dart-not-running problem.
- **Verdict:** a Live Activity is an *iPhone* feature that happens to show up on the watch. Scope it as its own tier.
  It also gives the owner a Lock Screen and Dynamic Island "now" display on the 15 Pro Max.

---

## 3. Tiered options (honest)

Effort is rough agent-days with the owner's MacBook available. Every tier at or above Tier 0b needs the
**action-ingestion spike** (section 6, pitfall 1).

| Tier | What the owner gets | New native code | Effort | Risk | Needs physical watch to verify |
|------|---------------------|-----------------|--------|------|------------------|
| **0a: Chunk notifications, tap-to-open** | Wrist buzz at each chunk start ("Focus: Write report, 25 min"); tapping opens the phone | None | 2–3 d | Low | Yes, but it can be judged on the phone |
| **0b: + Complete/Skip actions** | Complete/Skip buttons on the wrist; **Double Tap = Complete** on S9/Ultra 2+ | ~0 Swift. Dart background handler + outbox | +3–5 d | **Med-High** (background isolate vs Hive) | Yes |
| **1: Live Activity** | "Now · 14:32 left" in the watch Smart Stack, Lock Screen and Dynamic Island, with no watch app | Swift widget extension (iOS), App Group | 5–8 d | Med (8 h cap, no-push updates) | Watch: yes. Phone: no |
| **2: Watch app + complication** | Glanceable complication on the face, full "now" screen and buttons on the watch, works out of range | SwiftUI watch app + watch widget ext + WCSession bridge | 12–20 d | **High** (Xcode/CI/signing, sync, no simulator for `transferUserInfo`) | **Yes** |

Notes:
- **Tier 0 mirroring is free [A/V]:** an iPhone-only app's notifications appear on a worn, unlocked watch when the iPhone is
  locked. Actions run on the iPhone: "the system launches your app in the background and notifies the …
  UNUserNotificationCenter … delegate". [V] [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
  **23.0.0** (published 2026-11-06; we pin `^21.0.0`, so the bump is a separate step) supports this with
  `DarwinNotificationCategory`/`DarwinNotificationAction`. Non-`foreground` actions run
  `onDidReceiveBackgroundNotificationResponse` **in a spawned background isolate**. That requires
  `setPluginRegistrantCallback` in `didInitializeImplicitFlutterEngine`, which our `AppDelegate.swift` already implements. [V]
- **Do not use `foreground` actions for Complete.** A foreground action tries to open the phone app, which is in the
  owner's pocket.
- **64 pending notifications on iOS [V].** A ~25-chunk day plus 3 dailies fits. Rescheduling after each tap must cancel
  and recreate only today's chunk IDs (use a reserved ID range, e.g. 1000+).
- **Product fit.** Tier 0 is deterministic and adds no AI surface. It is the "dumb app" doing exactly what it says, at
  the time it said.

**Recommendation:** build **0a → 0b**, then let the owner live with it for a week before deciding on Tier 1 or 2. A large
share of the value of a scheduler on the wrist is "buzz me when the chunk changes and let me tick it off". Tier 2 mainly
adds glanceability (the complication) and out-of-range use.

---

## 4. Wear OS (secondary)

- **Flutter on Wear OS [V/MEDIUM]:** it works unofficially, because Wear OS is Android: the same `android/` embedding,
  with a manifest flag `com.google.android.wearable.standalone`. It is not an officially supported target. The VGV guide
  quotes smartwatches as a Flutter non-goal; the current roadmap is silent on them.
- **Packages [V]:** [wear_plus](https://pub.dev/packages/wear_plus) 1.2.5 (rexios.dev, ~5 months old, 19 likes):
  `WatchShape` and `AmbientMode` only. `wear` (fluttercommunity) is outdated. [wear_os_tiles](https://pub.dev/packages/wear_os_tiles)
  0.1.1 (unverified uploader, 0 likes, 95 downloads) is too immature to depend on. **Tiles and complications are
  realistically Kotlin** (ProtoLayout, `ComplicationDataSourceService`).
- **Phone sync:** the Wearable Data Layer (`DataClient`, `MessageClient`). `watch_connectivity` wraps the phone side and
  requires the same package name and signing key on phone and watch. [V]
- **Why it barely matters here [MEDIUM]:** Pixel Watch requires an Android phone, and Samsung's Wear OS 3+ watches dropped
  iPhone support. The owner cannot pair a Wear OS watch with his iPhone. Tier 0a/0b notifications already bridge to Wear
  OS for Android users at no extra cost. **Recommend: out of scope** beyond whatever Tier 0 gives for free.
- danserver *does* have the Android SDK and an emulator (CLAUDE.md, AVD `canopy_api35`), so a Wear OS AVD is testable
  here if that ever changes. Note that `ci.yml`'s header ("no Android SDK") is stale.

---

## 5. Build, signing and test constraints

- **`tools/build-ios.sh` / `flutter build ios` [V/A].** flutter_tools learned about watch companions in PR #51126 (it omits
  `-sdk`, because WatchKit "cannot be built using the iOS SDK") and PR #54959 (it skips `ARCHS` for device runs). So it is
  *supported in principle*. Community reports still show post-Xcode-15 breakage: embed-phase path mismatches
  (Debug-watchos vs watchsimulator), duplicate-output warnings, and build-phase ordering cycles. **[A] Spike first.**
  `build-ios.sh` itself only writes `GoogleOAuth.xcconfig` and calls flutter, so it should not need changes.
- **`tools/ios-build-agent.sh` (launchd, `devicectl` install) [A].** Installing the iPhone app normally carries the embedded
  watch app to the paired watch. Watch install is slow and flaky over `devicectl`. Expect to add a watch-specific
  verification step, and expect the "phone must be unlocked and connected" rule to apply to the watch as well.
- **CI (`macos-latest`, `flutter build ios --simulator --no-codesign`) [A].** The watch target is built too. Since Xcode 15,
  platform SDKs and runtimes are optional downloads. If the runner image lacks watchOS, add
  `xcodebuild -downloadPlatform watchOS` (slow, and macOS minutes are billed at 10x). The `apple` path filter already
  covers `ios/`.
- **Signing and capabilities [V/A].** Team `H637CCV562`, automatic signing. You need new App IDs for the watch app and the
  watch widget extension (plus the iOS widget extension for Tier 1). **App Groups are needed** between the watch app and
  its widget extension, and between Runner and the Live Activity extension. App Groups do *not* cross devices;
  WCSession does that. **Open question:** is H637CCV562 a **paid** Developer Program team? Xcode rejects App Groups on
  free "Personal Team" accounts ("Personal development teams … do not support the App Groups capability" [A, recalled
  error text]). Free provisioning also expires after 7 days.
- **Testing without a watch [V].** The Simulator **does not support `transferUserInfo`**, and Apple says "always test Watch
  Connectivity data transfers on paired devices". A paired iPhone+Watch simulator pair on the Mac covers UI, complications
  and `updateApplicationContext`/`sendMessage`. **Double Tap, haptics, real background wake and mirroring need the
  physical watch.** None of this runs on danserver. The Android-emulator path in CLAUDE.md does not help with the watch.
- **Unit-testable on danserver:** the Dart `WristSnapshotBuilder`, outbox drain/replay and notification-plan generation.
  That is where the logic should live anyway.

---

## 6. Pitfalls specific to this codebase

1. **Background writes vs Hive (CRITICAL).** Notification actions and WCSession wakes arrive when the UI isolate may be
   suspended or dead. Two bad options: (a) the background isolate writes Hive, which risks corruption, because hive_ce
   warns "HIVE MULTI-ISOLATE RISK… DATA CORRUPTION" and `IsolatedHive` "does not support `HiveObject`", which
   `DailySchedule` and `ScheduledChunk` are; (b) migrate to `IsolatedHive`, which is a rewrite of `lib/data/`.
   **Do (c):** append to an outbox (one file per action, atomic rename, *not* Hive), and replay it on the main isolate
   through the existing `markComplete`/`markSkipped` paths with the original tap time. Cost: until the app resumes, the
   phone's Hive and the scheduled notifications are stale. The spike must answer: if the app is merely *suspended*, does
   iOS deliver the action to the live engine or spawn a second one? [A]
2. **Replay needs an injectable "at" time.** `markComplete` reads `_now()` for G-05 break absorption. Replaying at 10:40
   a tap made at 10:18 would absorb nothing and leave the break where it was. Add an optional `at:` parameter, or a
   scoped clock override (Phase 25's `DevClock` seam is precedent). Also make replay idempotent: the guards
   `chunk.isCompleted` / `isSkipped` already make a duplicate a no-op. Mutation-test that a duplicate cannot double-log
   `CompletionLog`, per the CLAUDE.md "assertions that cannot fail" rule.
3. **Local wall-clock minutes vs instants.** `displayStartMinutes` is compared as *local* minutes-from-midnight, despite the
   model's "UTC" comment (`now_state.dart` FRAME-OF-REFERENCE note). The wrist payload must carry **absolute instants**
   computed once in Dart (`DateTime(y,m,d).add(minutes)` in local time, with a test on a DST-transition date). Swift must
   never re-derive times from minutes, or the phone and watch will disagree on travel and DST days. Also ship `tz` so the
   watch can detect a mismatch and say "open Canopy".
4. **Trap #4 on the wrist.** The watch shows *persisted* Hive output, so an engine change is invisible on the watch until
   ⟳ Re-check-in, exactly as on the phone. Any watch UAT that judges schedule content must Re-check-in **on the phone
   first**, and then confirm a new snapshot reached the watch (show `generatedAt` in a debug footer).
5. **Day rollover.** No regeneration happens without check-in. The watch must blank itself when `dateYmd ≠ today`, and the
   complication timeline must end in a "Day complete / check in on phone" entry. Do not hold yesterday's last chunk overnight.
6. **Don't reimplement the engine in Swift.** Swift gets precomputed entries and does `entries.last(where: {$0.at <= now})`.
   No `resolveNowState` port, no break absorption, no capacity logic. A golden test in Dart (snapshot JSON for fixture
   days) is the contract. If a Swift change needs schedule logic, that logic belongs in Dart.
7. **Precomputed timeline goes stale after a tap.** Entries assume no further taps. Any action, applied or queued, must
   produce a new snapshot. On the watch, an optimistic local mark must overlay, not replace, the snapshot.
8. **Notification text that lies.** Chunk notifications are scheduled with fixed times. G-05, calendar sync or
   `_yieldCommitmentsToMeetings` can move chunks. Reschedule today's chunk notifications on *every* mutation, and accept
   that queued wrist actions leave them stale until the next resume.
9. **Meeting titles on a wrist.** Calendar-sourced commitments may carry work-calendar titles (the owner's real use case is
   his Workspace calendar). These would show on a watch face or in a notification. That is an owner privacy decision
   (see below).
10. **Web/desktop builds.** Keep the bridge behind `Platform.isIOS` and a conditional import, the same pattern as
    `lib/platform/`. The web UAT build must not pull iOS-only channels.

---

## 7. Recommended milestone phases

| # | Phase | Goal (one line) | Riskiest assumption, spike first |
|---|-------|-----------------|---------------------------------|
| 1 | **Wrist snapshot and outbox (pure Dart)** | Dart builds a versioned, instant-based "wrist timeline" from `resolveNowState`, and replays queued Complete/Skip actions with their tap time, all unit-tested on danserver | Replaying a Complete with an injected `at` time reproduces G-05 exactly as a live tap would (mutation-tested) |
| 2 | **Chunk notifications (Tier 0a)** | A notification at each chunk start, rescheduled on every schedule change, mirrored to the watch | The reschedule-on-every-mutation hook stays under the 64-pending cap and never leaves an orphan for a moved chunk |
| 3 | **Actions from the wrist (Tier 0b)** | Complete/Skip buttons on chunk notifications (Complete first, so Double Tap completes), handled without a Hive write off the main isolate | **A background notification action on a suspended or killed app reliably lands in the outbox and is replayed on resume**. Spike on the real iPhone and watch before planning |
| 4 | *(gate: owner lives with Tier 0 for a week, then picks one)* | | |
| 4a | **Live Activity (Tier 1)** | A "Now, time left" Live Activity started at check-in, visible on the Lock Screen, Dynamic Island and watch Smart Stack | A chunk transition can update the activity without push, and the 8-hour cap is survivable |
| 4b | **Watch target skeleton (Tier 2 start)** | An empty SwiftUI watch app that builds via `build-ios.sh`, CI and `ios-build-agent.sh`, and installs on the owner's watch | **`flutter build ios` plus CI still go green with an embedded watch target**, and App Groups sign on team H637CCV562 |
| 5 | **Watch app and complication (Tier 2)** | The watch shows the current chunk and complication countdown from the phone's snapshot, with Complete/Skip that works out of range and syncs back | `sendMessage` reliably wakes the Flutter app and the outbox drains; `transferUserInfo` works on real devices (it cannot be simulated) |

Phases 1 to 3 have no Xcode-target risk and are mostly testable on danserver. Phase 3 alone requires a physical watch.

---

## 8. Decisions only the owner can make (and open questions)

1. **Do you own an Apple Watch, and which model?** Double Tap needs a Series 9 / Ultra 2 or later. Without a watch, Tier 2
   cannot be verified and Tiers 0b and 1 can only be half-verified.
2. **Scope ceiling:** stop at Tier 0, add Tier 1 (Live Activity), or go to Tier 2 (a full watch app)? Recommendation: Tier 0
   first, decide after a week of real use.
3. **Is team H637CCV562 a paid Apple Developer Program membership?** App Groups (Tiers 1 and 2) and non-expiring installs
   depend on it.
4. **Notification cadence:** buzz at every chunk start, only at work-chunk starts, and/or a "2 minutes left" warning? Should
   breaks buzz? This is a personal-tolerance call, and the 64-notification cap bounds it.
5. **Privacy on the wrist:** show real meeting and goal titles on the watch face and in notifications, or a generic "Meeting"
   / "Focus"?
6. **What Complete means on the wrist when the phone is far away:** is it OK for the phone to stay stale until the app is
   next opened (the outbox design), or must a wrist tap take effect immediately? Immediate effect forces a native Hive
   rewrite or an `IsolatedHive` migration, which is a much bigger milestone.
7. **Wear OS:** confirm it is out of scope beyond what Tier 0 gives Android for free.
8. **CI cost:** accept longer and more expensive macOS runs, possibly with a watchOS platform download, once a watch target exists?

---

## Sources

- flutter/flutter#28901, Apple Watch support (open, P3): https://github.com/flutter/flutter/issues/28901 [V]
- Flutter 2026 roadmap (no watch mention): https://github.com/flutter/flutter/blob/master/docs/roadmap/Roadmap.md [V]
- flutter_tools watch-companion PRs #51126 / #54959: https://flutter.googlesource.com/mirrors/flutter/+/56b7c93584970dda8a7711d60b68276d3e0efec5%5E%21/packages/flutter_tools [V]
- Apple Forums, Flutter + watchOS archive/embed problems: https://developer.apple.com/forums/thread/720933 [MEDIUM]
- watch_connectivity 0.2.11: https://pub.dev/packages/watch_connectivity ; API: https://pub.dev/documentation/watch_connectivity/latest/watch_connectivity/WatchConnectivity-class.html [V]
- flutter_watch_os_connectivity 1.0.0: https://pub.dev/packages/flutter_watch_os_connectivity [V]
- flutter_watchos (third-party toolchain): https://pub.dev/packages/flutter_watchos [V]
- WCSession `sendMessage` / `isReachable` / `transferUserInfo` / `updateApplicationContext` / `remainingComplicationUserInfoTransfers`: https://developer.apple.com/documentation/watchconnectivity/wcsession [V, via the Apple docs JSON]
- WidgetKit "Keeping a widget up to date" (budget): https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date [V]
- WidgetKit accessory widgets and watch complications: https://developer.apple.com/documentation/widgetkit/creating-accessory-widgets-and-watch-complications [V]
- `Text(timerInterval:)`: https://developer.apple.com/documentation/swiftui/text/init(timerinterval:pausetime:countsdown:showshours:) [V]
- RelevanceConfiguration (Smart Stack): https://developer.apple.com/documentation/widgetkit/relevanceconfiguration [V]
- Widget and Live Activity interactivity: https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities [V]
- Live Activities (watch Smart Stack, 8 h / 12 h limits): https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities and https://developer.apple.com/documentation/activitykit/creating-custom-views-for-live-activities [V]
- LiveActivityIntent: https://developer.apple.com/documentation/appintents/liveactivityintent [V]
- Actionable notifications and Double Tap: https://developer.apple.com/documentation/usernotifications/declaring-your-actionable-notification-types [V]
- watchOS notifications: https://developer.apple.com/documentation/watchos-apps/enabling-and-receiving-notifications [V]
- flutter_local_notifications 23.0.0: https://pub.dev/packages/flutter_local_notifications [V]
- live_activities 2.6.0: https://pub.dev/packages/live_activities ; home_widget 0.10.0 (no watchOS): https://pub.dev/packages/home_widget [V]
- hive_ce 2.23.2: https://pub.dev/packages/hive_ce ; isolate warnings read from local source `~/.pub-cache/hosted/pub.dev/hive_ce-2.19.3/lib/src/util/logger.dart` and `lib/hive.dart` [V]
- wear_plus 1.2.5: https://pub.dev/packages/wear_plus ; wear_os_tiles 0.1.1: https://pub.dev/packages/wear_os_tiles [V]
- VGV, Building Wear OS apps with Flutter: https://verygood.ventures/blog/building-wear-os-apps-with-flutter-a-very-good-guide [MEDIUM]
- Wear OS and iPhone compatibility: https://9to5google.com/2022/05/12/pixel-watch-android-support-iphone/ and https://www.androidcentral.com/wearables/wear-os/which-wear-os-3-watches-work-with-iphone [MEDIUM, secondary]

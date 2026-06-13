# Phase 4: Chunk Tracking and Notifications - Research

**Researched:** 2026-04-02
**Domain:** Flutter swipe gestures, local notifications (flutter_local_notifications), JSON export (share_plus), settings screen
**Confidence:** HIGH

## Summary

Phase 4 closes the daily loop with four distinct subsystems: (1) swipe-to-complete/skip gestures on chunk cards using Flutter's built-in `Dismissible` widget, (2) an append-only `CompletionLog` written on every interaction, (3) local notifications via `flutter_local_notifications ^21.0.0` with timezone support, and (4) JSON data export via `share_plus ^12.0.2`. The `CompletionLog` model and repository are already implemented and ready to use. The `SettingsScreen` is a stub waiting for full implementation.

The biggest risk is notification platform fragmentation. `flutter_local_notifications` has no Web support — the spec calls for an in-app banner fallback on Web, which is the correct mitigation. On Android 12+, exact-alarm permissions require explicit user approval; the plan must include a graceful degradation path (inexact alarms) when the user declines. On iOS, permission should be deferred until after the first mood check-in, which `flutter_local_notifications` v21 fully supports via `requestAlertPermission: false` in initialization.

**Primary recommendation:** Add `flutter_local_notifications: ^21.0.0`, `timezone: ^0.11.0`, `flutter_timezone: ^5.0.2`, and `share_plus: ^12.0.2` to `pubspec.yaml`. Wrap each `ChunkCard` in a `Dismissible` widget. Expose `markComplete` / `markSkipped` on `ScheduleNotifier`. Build `NotificationService` as a top-level singleton initialized in `main()` before `runApp()`.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** CompletionLog is strictly append-only — no mutation or deletion (Phase 1 architecture, enforced at repository interface level)
- **D-02:** Bottom sheet pattern for detail/edit views (Phase 2 established pattern)
- **D-03:** Weather metaphor + mood color palette (#4A6275 → #E8C547) for visual consistency (Phase 3)
- **D-04:** ChunkCard already renders done state: grey bar, 50% opacity, check_circle icon (Phase 3)
- **D-05:** Warm, direct tone — not instructional or corporate (Phase 2)

### Claude's Discretion
The following gray areas were identified but not yet discussed with the user (discussion was interrupted):
1. Swipe completion feel — reveal-behind pattern, slide-off, haptic feedback, undo affordance
2. End-of-day summary — trigger mechanism, data breakdown, tone/copy, dismiss UX
3. Notification experience — morning notification content/tone, iOS permission request timing, mid-day nudge opt-in UI, Web banner design
4. Settings & data export — settings screen layout, JSON export presentation (share sheet vs file save), export confirmation UX

### Deferred Ideas (OUT OF SCOPE)
None identified — discussion was interrupted before deferred scope was established.
</user_constraints>

## Project Constraints (from CLAUDE.md)

- State management: `StatefulWidget` with `setState()` + `Provider`/`ChangeNotifier` — no external state management library
- Routing: `go_router` (already in use, `^17.1.0`)
- Theme: Material 3 with `ColorScheme.fromSeed(Color(0xFF3D6B4F))`
- Linting: `package:flutter_lints` — run `flutter analyze` before completion
- Dart SDK `^3.10.3`, Flutter `>=3.18.0-18.0.pre.54`
- All app code goes in `lib/`; tests in `test/`

---

## Standard Stack

### Core (new packages to add)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_local_notifications | ^21.0.0 | Schedule Android/iOS daily push notifications | The ecosystem standard; 1.6M+ downloads, actively maintained |
| timezone | ^0.11.0 | TZDateTime for time-zone-aware notification scheduling | Required dependency of flutter_local_notifications |
| flutter_timezone | ^5.0.2 | Retrieve device's local IANA timezone string at runtime | Needed because `timezone` package cannot determine device timezone itself |
| share_plus | ^12.0.2 | Cross-platform file/text sharing (JSON export) | fluttercommunity/plus_plugins official plugin; Web download fallback built-in |

### Already Present
| Library | Version | Purpose |
|---------|---------|---------|
| path_provider | ^2.1.5 | Write temp files for export on mobile (already in pubspec.yaml) |
| provider | ^6.1.5+1 | ChangeNotifier state (already in use) |
| go_router | ^17.1.0 | Routing for new screens (already in use) |
| hive_ce | ^2.19.3 | CompletionLog persistence (already scaffolded) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| flutter_local_notifications | awesome_notifications | awesome_notifications has more features but heavier; fln is lighter and the project only needs daily scheduling |
| share_plus | flutter_file_saver | flutter_file_saver has no Web support; share_plus has built-in Web download fallback |

**Installation (additions only):**
```bash
flutter pub add flutter_local_notifications:'^21.0.0' timezone:'^0.11.0' flutter_timezone:'^5.0.2' share_plus:'^12.0.2'
flutter pub get
```

**Version verification:** All versions confirmed against pub.dev registry on 2026-04-02.
- flutter_local_notifications 21.0.0 — published 2026-03-05
- timezone 0.11.0 — published (required by flutter_local_notifications)
- flutter_timezone 5.0.2 — published 2026-03-15
- share_plus 12.0.2 — published 2026-03-30

---

## Architecture Patterns

### Recommended Project Structure (new additions)
```
lib/
├── services/
│   └── notification_service.dart     # New: flutter_local_notifications wrapper
├── screens/
│   ├── schedule/
│   │   ├── schedule_screen.dart      # Modify: add Dismissible, skipped section, Web banner
│   │   └── widgets/
│   │       ├── chunk_card.dart       # Modify: wrap in Dismissible (keep as StatelessWidget)
│   │       └── swipeable_chunk_card.dart  # New: Dismissible wrapper around ChunkCard
│   ├── settings/
│   │   └── settings_screen.dart      # Replace stub with full implementation
│   └── end_of_day/
│       └── end_of_day_summary_screen.dart  # New: full-screen summary
├── providers/
│   └── schedule_notifier.dart        # Modify: add markComplete, markSkipped, completionCount
```

### Pattern 1: Swipe Gesture with Dismissible (reveal-behind)

The `Dismissible` widget is the idiomatic Flutter approach. It supports directional swipes with background widgets for the reveal-behind affordance. Critically, `confirmDismiss` lets us **prevent actual dismissal** while still triggering the action — the chunk card stays in the list (just changes state), it is not removed.

**What:** Wrap each work `ChunkCard` in `Dismissible`. Swipe right = complete, swipe left = skip. Use `confirmDismiss` to call the notifier and return `false` so the card is not removed from the list.

**When to use:** Directional swipe actions that mutate state without removing the item from view.

```dart
// Source: Flutter Dismissible docs (api.flutter.dev/flutter/widgets/Dismissible-class.html)
Dismissible(
  key: ValueKey(chunk.id),
  direction: DismissDirection.horizontal,
  confirmDismiss: (direction) async {
    if (direction == DismissDirection.startToEnd) {
      await context.read<ScheduleNotifier>().markComplete(chunk);
    } else {
      await context.read<ScheduleNotifier>().markSkipped(chunk);
    }
    return false; // Never remove the card from the list
  },
  background: _CompleteBackground(),   // green check reveal on right swipe
  secondaryBackground: _SkipBackground(), // amber skip reveal on left swipe
  child: ChunkCard(chunk: chunk, goalColor: goalColor),
)
```

**Skipped section:** After swipe-left, `isSkipped = true` on the chunk. `ScheduleScreen` splits `schedule.chunks` into two lists: active and skipped. The skipped section uses an `ExpansionTile` at the bottom: collapsed by default, labelled "Skipped today (N)".

### Pattern 2: ScheduleNotifier — markComplete / markSkipped

Extend `ScheduleNotifier` to write both the `ScheduledChunk` flag (in Hive via `DailySchedule` save) and a `CompletionLog` entry. Both writes are atomic from the UI's perspective; a single `notifyListeners()` at the end triggers a rebuild.

```dart
// Extend ScheduleNotifier (lib/providers/schedule_notifier.dart)
Future<void> markComplete(ScheduledChunk chunk) async {
  if (chunk.isCompleted) return; // idempotent guard
  chunk.isCompleted = true;
  await _repo.save(_todaySchedule!); // Hive update via DailyScheduleRepository
  final log = CompletionLog(
    chunkId: chunk.id,
    goalId: chunk.goalId ?? '',
    dateYmd: _todaySchedule!.dateYmd,
    eventIndex: CompletionEvent.completed.index,
  );
  await _completionLogRepo.append(log);
  notifyListeners();
}

Future<void> markSkipped(ScheduledChunk chunk) async {
  if (chunk.isSkipped) return;
  chunk.isSkipped = true;
  await _repo.save(_todaySchedule!);
  final log = CompletionLog(
    chunkId: chunk.id,
    goalId: chunk.goalId ?? '',
    dateYmd: _todaySchedule!.dateYmd,
    eventIndex: CompletionEvent.skipped.index,
  );
  await _completionLogRepo.append(log);
  notifyListeners();
}
```

`ScheduleNotifier` must be injected with `CompletionLogRepository`. Follow the existing pattern: inject in constructor, use `HiveCompletionLogRepository()` as the default.

### Pattern 3: NotificationService — Initialization

`NotificationService` is initialized in `main()` before `runApp()`, following the `SettingsNotifier` pattern already established in Phase 3. It wraps `FlutterLocalNotificationsPlugin`.

```dart
// lib/services/notification_service.dart
// Source: flutter_local_notifications pub.dev/packages/flutter_local_notifications/example

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    if (kIsWeb) return; // Web: no-op, banner fallback used instead

    // Configure timezone
    tz.initializeTimeZones();
    if (!Platform.isLinux && !Platform.isWindows) {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false, // Defer until after first check-in
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }
}
```

**iOS permission request** (called after first successful mood check-in):
```dart
static Future<void> requestIOSPermissions() async {
  if (kIsWeb || !Platform.isIOS) return;
  await _plugin
      .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);
}
```

### Pattern 4: Daily Notification — zonedSchedule with matchDateTimeComponents

```dart
// Source: flutter_local_notifications pub.dev example
static Future<void> scheduleMorningNotification(int minutesFromMidnight) async {
  if (kIsWeb) return;
  await _plugin.cancel(0); // Cancel previous morning notification
  final hour = minutesFromMidnight ~/ 60;
  final minute = minutesFromMidnight % 60;

  final now = tz.TZDateTime.now(tz.local);
  var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
  if (scheduled.isBefore(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }

  await _plugin.zonedSchedule(
    id: 0, // Morning notification ID
    title: 'Good morning',
    body: 'Ready to plan your day?',
    scheduledDate: scheduled,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'morning_reminder',
        'Morning reminder',
        channelDescription: 'Daily morning schedule reminder',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, // See Pitfall 1
    matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at same time
  );
}
```

Mid-day nudge uses notification ID 1 and the same pattern with `midDayNudgeMinutes`.

### Pattern 5: JSON Export via share_plus

**Reliable cross-platform approach:** Write to a temp file first using `path_provider`, then share the file path. This avoids known issues with `XFile.fromData` on Windows (file name becomes UUID) and Web (reads path instead of bytes).

```dart
// Source: share_plus pub.dev + path_provider Flutter docs
static Future<void> exportCompletionLog(List<CompletionLog> logs) async {
  final data = logs.map((e) => {
    'id': e.id,
    'chunkId': e.chunkId,
    'goalId': e.goalId,
    'dateYmd': e.dateYmd,
    'event': e.event.name,
    'recordedAt': e.recordedAt.toIso8601String(),
  }).toList();

  final jsonString = const JsonEncoder.withIndent('  ').convert(data);
  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final fileName = 'canopy_export_$timestamp.json';

  if (kIsWeb) {
    // Web: share_plus uses Web Share API with download fallback
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(
        utf8.encode(jsonString),
        name: fileName,
        mimeType: 'application/json',
      )],
    ));
    return;
  }

  // Mobile/Desktop: write to temp file, share the path
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(jsonString);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path)],
  ));
}
```

### Pattern 6: Web Banner (no notification API)

The Web platform has no local notification API. The spec calls for a persistent in-app banner on `ScheduleScreen` when `!scheduleNotifier.hasScheduleToday`. This is the existing empty state check — add a prominent `MaterialBanner` or `Card` at the top of the list when `kIsWeb` is true.

```dart
// In ScheduleScreen — wrap existing empty state or add banner
if (kIsWeb && !scheduleNotifier.hasScheduleToday)
  MaterialBanner(
    content: const Text('Start your day — tap to check in'),
    actions: [
      TextButton(
        onPressed: () => context.push('/schedule/checkin'),
        child: const Text('Start'),
      ),
    ],
  ),
```

### Pattern 7: End-of-Day Summary Screen

Full-screen route outside `StatefulShellRoute` (no bottom nav, like `/review` and `/commitments`). Triggered either by a "view summary" action in the schedule or automatically when all chunks are completed/skipped. Route: `/summary`.

```dart
// router.dart — add outside StatefulShellRoute
GoRoute(
  path: '/summary',
  builder: (context, state) => const EndOfDaySummaryScreen(),
),
```

Data: `ScheduleNotifier` provides `todaySchedule` chunks; filter by `isCompleted` / `isSkipped`. Per-goal breakdown groups chunks by `goalId`, cross-references `GoalsNotifier`.

### Anti-Patterns to Avoid

- **Removing skipped chunks from the list:** The spec requires skipped chunks move to a collapsed section at the bottom, not disappear. Using `Dismissible` with `return true` would remove them from view entirely.
- **Mutating CompletionLog records:** The `CompletionLogRepository` interface has no `update` or `delete` method. Never add them.
- **Calling `NotificationService.initialize()` inside `runApp` / widget tree:** Initialize before `runApp()` in `main()`, matching the `SettingsNotifier` pattern.
- **Requesting iOS notification permission at app launch:** The spec explicitly defers this to after the first successful check-in. Don't call `requestIOSPermissions()` in `NotificationService.initialize()`.
- **Using exact alarms without permission check on Android 12+:** `AndroidScheduleMode.exactAllowWhileIdle` will throw if the user has not granted exact alarm permission on Android 12+. Use `inexactAllowWhileIdle` as the default (appropriate for a morning reminder) or add a permission gate.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Daily local notifications | Custom alarm timer / WorkManager bridge | `flutter_local_notifications` | Background execution limits, timezone shifts, OS-level scheduling complexity |
| Device timezone resolution | Manual UTC offset math | `flutter_timezone` | DST, historical zones, IANA lookup — untestable by hand |
| File sharing / download on Web | `dart:html` AnchorElement | `share_plus` (built-in Web download fallback) | share_plus handles both Web Share API and fallback in one call |
| Swipe gesture tracking | `GestureDetector` + `AnimationController` | `Dismissible` | Dismiss widget handles velocity thresholds, direction snapping, and background reveals |
| JSON serialization | Custom `toMap` logic | `dart:convert` `JsonEncoder` | Standard library; no extra dependency needed |

**Key insight:** The notification domain is where hand-rolling causes the most invisible failures — timezone shifts, battery optimization, background process killing, OS permission state machines. The single package `flutter_local_notifications` encapsulates years of bug fixes for all of these.

---

## Common Pitfalls

### Pitfall 1: Exact Alarm Permission on Android 12+ Denies Notification
**What goes wrong:** `AndroidScheduleMode.exactAllowWhileIdle` throws a `PlatformException` on Android 12+ when `SCHEDULE_EXACT_ALARM` permission is not granted. As of Android 14, this permission is denied by default for new installs.
**Why it happens:** Google tightened exact alarm restrictions to reduce battery drain.
**How to avoid:** Use `AndroidScheduleMode.inexactAllowWhileIdle` for morning reminders — acceptable ±15 minute window for a lifestyle app. Only escalate to exact if user explicitly requests alarm-precision timing. Add `<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>` to `AndroidManifest.xml` if exact is needed, and call `requestExactAlarmsPermission()` before scheduling.
**Warning signs:** `PlatformException(error, Exact alarms are not permitted...)` in Android 12+ device logs.

### Pitfall 2: AndroidManifest.xml Missing Receivers (Notification Survives Reboot)
**What goes wrong:** Notifications are lost after device restart because the Boot receiver is not declared.
**Why it happens:** `flutter_local_notifications` v16+ removed automatic manifest injection — the app must declare receivers itself.
**How to avoid:** Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<receiver android:exported="false"
  android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
<receiver android:exported="false"
  android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver"/>
<receiver android:exported="true"
  android:name="com.dexterous.flutterlocalnotifications.BootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
  </intent-filter>
</receiver>
```
**Warning signs:** Notifications stop appearing after reboot in physical device testing.

### Pitfall 3: Android Java Desugaring Not Enabled (Build Failure)
**What goes wrong:** Build fails with `Desugaring required` or `java.time API` errors.
**Why it happens:** `flutter_local_notifications` v21 requires Java desugaring for `java.time` APIs on Android API < 26.
**How to avoid:** In `android/app/build.gradle`:
```groovy
android {
  compileOptions {
    coreLibraryDesugaringEnabled true
  }
}
dependencies {
  coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
```
**Warning signs:** Build error mentioning desugaring or java.time.

### Pitfall 4: timezone Not Initialized Before Scheduling
**What goes wrong:** `tz.local` is `UTC` when scheduling, causing notifications to fire at the wrong wall-clock time in non-UTC timezones.
**Why it happens:** `tz.initializeTimeZones()` populates the timezone database; `tz.setLocalLocation()` sets the local zone. If either is skipped, `tz.local` defaults to UTC.
**How to avoid:** Always call `_configureLocalTimeZone()` at the top of `NotificationService.initialize()` before any scheduling. Verify with a log statement that `tz.local.name` matches the device timezone.
**Warning signs:** Notification fires at midnight UTC instead of 7:30am local time.

### Pitfall 5: Dismissible Removing Chunk from List Instead of Marking State
**What goes wrong:** The chunk card disappears from the UI after swipe.
**Why it happens:** If `confirmDismiss` returns `true` (or is omitted with a non-null `onDismissed`), `Dismissible` removes the child from the widget tree. Removing chunks from the list contradicts the spec (skipped chunks should appear in collapsed section).
**How to avoid:** Always use `confirmDismiss: (direction) async { /* update state */ return false; }`. Never use `onDismissed` for this use case.

### Pitfall 6: XFile.fromData File Name Becomes UUID on Windows / Android
**What goes wrong:** The shared file is named a random UUID string (e.g., `3b4f9a...json`) instead of `canopy_export_20260402_103000.json`.
**Why it happens:** Known `share_plus` issue — without explicit filename, the OS generates a UUID.
**How to avoid:** On mobile, write to `getTemporaryDirectory()` first and share via `XFile(file.path)`. On Web, use `XFile.fromData` with the `name` parameter and `fileNameOverrides` in `ShareParams`.
**Warning signs:** Shared file has UUID name or wrong extension.

### Pitfall 7: iOS Foreground Notification Not Showing
**What goes wrong:** Morning notification fires in background fine but never shows when app is open.
**Why it happens:** iOS suppresses foreground notifications by default.
**How to avoid:** Configure `DarwinInitializationSettings` with `defaultPresentAlert: true, defaultPresentBadge: true, defaultPresentSound: true` — or set per-notification in `DarwinNotificationDetails`.

---

## Code Examples

Verified patterns from official sources:

### Daily Notification at User-Configured Time (Next Occurrence)
```dart
// Source: flutter_local_notifications pub.dev/packages/flutter_local_notifications/example
tz.TZDateTime _nextInstanceOfTime(int minutesFromMidnight) {
  final now = tz.TZDateTime.now(tz.local);
  final hour = minutesFromMidnight ~/ 60;
  final minute = minutesFromMidnight % 60;
  var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
  if (scheduled.isBefore(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled;
}

await _plugin.zonedSchedule(
  id: 0,
  title: 'Good morning',
  body: 'Ready to plan your day?',
  scheduledDate: _nextInstanceOfTime(minutesFromMidnight),
  notificationDetails: const NotificationDetails(
    android: AndroidNotificationDetails('morning_reminder', 'Morning reminder',
        importance: Importance.high, priority: Priority.high),
    iOS: DarwinNotificationDetails(),
  ),
  androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  matchDateTimeComponents: DateTimeComponents.time,
);
```

### End-of-Day Summary Data Assembly
```dart
// In EndOfDaySummaryScreen — reads from ScheduleNotifier and GoalsNotifier
final schedule = context.watch<ScheduleNotifier>().todaySchedule!;
final goals = context.read<GoalsNotifier>().goals;
final workChunks = schedule.chunks.where((c) => c.chunkType == ChunkType.work).toList();
final completed = workChunks.where((c) => c.isCompleted).length;
final skipped = workChunks.where((c) => c.isSkipped).length;
final total = workChunks.length;

// Per-goal breakdown
final byGoal = <String, ({int done, int total})>{};
for (final chunk in workChunks) {
  final gid = chunk.goalId ?? 'unassigned';
  final entry = byGoal[gid] ?? (done: 0, total: 0);
  byGoal[gid] = (
    done: entry.done + (chunk.isCompleted ? 1 : 0),
    total: entry.total + 1,
  );
}
```

### Dismissible Chunk Card with Reveal-Behind Backgrounds
```dart
// Source: Flutter Dismissible docs api.flutter.dev/flutter/widgets/Dismissible-class.html
Dismissible(
  key: ValueKey(chunk.id),
  direction: chunk.isCompleted || chunk.isSkipped
      ? DismissDirection.none  // Already resolved — disable swipe
      : DismissDirection.horizontal,
  confirmDismiss: (direction) async {
    final notifier = context.read<ScheduleNotifier>();
    if (direction == DismissDirection.startToEnd) {
      await notifier.markComplete(chunk);
    } else {
      await notifier.markSkipped(chunk);
    }
    return false;
  },
  background: Container(
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.only(left: 20),
    color: Colors.green.shade400,
    child: const Icon(Icons.check_circle, color: Colors.white),
  ),
  secondaryBackground: Container(
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: 20),
    color: Colors.orange.shade300,
    child: const Icon(Icons.arrow_forward, color: Colors.white),
  ),
  child: ChunkCard(chunk: chunk, goalColor: goalColor),
)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `flutterLocalNotificationsPlugin.schedule()` | `zonedSchedule()` with `matchDateTimeComponents` | v4 (deprecated), v9 (removed) | TZ-aware scheduling required |
| `androidAllowWhileIdle` parameter | `androidScheduleMode` enum (required named param) | v18 (deprecated), v20 (removed) | Existing code using old param won't compile |
| Plugin auto-injected manifest entries | App must declare receivers in own manifest | v16 | Silent failures without manifest changes |
| `IOSFlutterLocalNotificationsPlugin.requestPermission()` | `requestNotificationsPermission()` | v16 | API rename |
| `Share.shareFiles()` (share_plus v6) | `SharePlus.instance.share(ShareParams(files: ...))` | share_plus v10 | API fully redesigned with named params |

**Deprecated/outdated:**
- `Share.shareXFiles()`: Replaced by `SharePlus.instance.share(ShareParams(files: ...))` in share_plus v10+. The old static API is removed in v12.

---

## Open Questions

1. **End-of-day summary trigger mechanism**
   - What we know: The spec says it exists; the CONTEXT.md lists trigger mechanism as a gray area not yet discussed
   - What's unclear: Auto-trigger when all chunks resolved vs. manual "View summary" button vs. notification tap at end of working day
   - Recommendation: Claude's discretion — implement as a "View your day" button in the schedule `AppBar` overflow menu that becomes active once 50%+ of chunks are resolved; no auto-push to avoid interrupting the user

2. **Android exact vs. inexact alarm**
   - What we know: Exact alarms require a user-facing permission grant on Android 12+; denied by default on Android 14+
   - What's unclear: User expectation for ±15 min tolerance vs. precise timing
   - Recommendation: Use `AndroidScheduleMode.inexactAllowWhileIdle` by default (appropriate for a lifestyle morning reminder). Add a note in settings: "Notification may appear up to 15 minutes early."

3. **Notification tap navigation target**
   - What we know: The spec says "on tap, app opens and schedule generation runs synchronously on launch" → navigates to mood check-in if no schedule, otherwise to schedule view
   - What's unclear: Cold-start vs. hot-start (app already open) behavior
   - Recommendation: In `onDidReceiveNotificationResponse`, check `ScheduleNotifier.hasScheduleToday`: if false, `context.push('/schedule/checkin')`; if true, `context.push('/schedule')`.

4. **GoalsNotifier initialization before ScheduleNotifier in markComplete**
   - What we know: `ScheduleNotifier.markComplete` needs `CompletionLogRepository` — currently not injected
   - What's unclear: Constructor injection or field injection
   - Recommendation: Add `CompletionLogRepository` as a constructor parameter with default `HiveCompletionLogRepository()` — consistent with how `ScheduleNotifier` already uses `HiveDailyScheduleRepository()` directly.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All | ✓ | >=3.18.0-18.0.pre.54 | — |
| Dart SDK | All | ✓ | ^3.10.3 | — |
| Android SDK (build tools) | flutter_local_notifications Android | ✓ | compileSdk 35+ required | — |
| path_provider | JSON export temp file | ✓ | 2.1.5 (already in pubspec) | — |

Note: `flutter_local_notifications` v21 requires `compileSdk 36`. The `android/app/build.gradle` may need updating from 35 to 36. Verify by checking `android/app/build.gradle` before implementing.

**Missing dependencies with no fallback:** None.

---

## Validation Architecture

`workflow.nyquist_validation` is absent from `.planning/config.json` — treated as enabled.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (bundled with Flutter SDK) |
| Config file | none — uses `flutter test` runner directly |
| Quick run command | `flutter test test/widget_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| (from spec) | markComplete appends CompletionLog entry | unit | `flutter test test/providers/schedule_notifier_test.dart -x` | ❌ Wave 0 |
| (from spec) | markSkipped sets isSkipped flag | unit | `flutter test test/providers/schedule_notifier_test.dart -x` | ❌ Wave 0 |
| (from spec) | CompletionLogRepository append is idempotent (no delete) | unit | `flutter test test/repositories/completion_log_repository_test.dart -x` | ❌ Wave 0 |
| (from spec) | Dismissible does not remove card from list | widget | `flutter test test/screens/schedule_screen_test.dart -x` | ❌ Wave 0 |
| (from spec) | JSON export produces valid JSON with all fields | unit | `flutter test test/services/export_test.dart -x` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test` (full suite, fast — < 10 seconds with current test count)
- **Per wave merge:** `flutter test && flutter analyze`
- **Phase gate:** Full suite green + `flutter analyze` clean before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/providers/schedule_notifier_test.dart` — covers markComplete/markSkipped unit behavior
- [ ] `test/repositories/completion_log_repository_test.dart` — covers append-only invariant
- [ ] `test/services/export_test.dart` — covers JSON serialization correctness
- [ ] `test/screens/schedule_screen_test.dart` — covers Dismissible widget behavior (cards stay visible after swipe)

---

## Sources

### Primary (HIGH confidence)
- pub.dev/packages/flutter_local_notifications (v21.0.0, 2026-03-05) — initialization, iOS permission deferral, zonedSchedule, AndroidScheduleMode, changelog
- pub.dev/packages/flutter_timezone (v5.0.2, 2026-03-15) — getLocalTimezone API
- pub.dev/packages/share_plus (v12.0.2, 2026-03-30) — ShareParams, XFile, Web fallback behavior
- api.flutter.dev/flutter/widgets/Dismissible-class.html — confirmDismiss, direction, background pattern
- Existing codebase: `lib/data/models/completion_log.dart`, `lib/data/repositories/completion_log_repository.dart`, `lib/providers/schedule_notifier.dart`, `lib/screens/schedule/widgets/chunk_card.dart`

### Secondary (MEDIUM confidence)
- github.com/MaikuB/flutter_local_notifications example/main.dart — timezone init pattern, deferred iOS permission example
- developer.android.com/about/versions/14/changes/schedule-exact-alarms — SCHEDULE_EXACT_ALARM denied by default on Android 14
- flutter_local_notifications changelog v16-v21 (pub.dev) — breaking change history

### Tertiary (LOW confidence)
- WebSearch: XFile.fromData known issues (UUID filename) — verified by GitHub issue links (github.com/fluttercommunity/plus_plugins/issues/1188, /1645)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all versions confirmed against pub.dev registry 2026-04-02
- Architecture: HIGH — patterns derived from existing codebase conventions + official docs
- Notification pitfalls: HIGH — verified against official Android developer docs + package changelog
- Export pitfalls: MEDIUM — known GitHub issues referenced; core API verified from official docs

**Research date:** 2026-04-02
**Valid until:** 2026-05-02 (stable libraries; flutter_local_notifications is actively maintained but changelogs can break setup)

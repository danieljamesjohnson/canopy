# Flutter Technical Patterns Research

**Project:** Canopy — Personal Time Budgeting App
**Researched:** 2026-02-24
**Overall Confidence:** MEDIUM
**Note:** External tool access was unavailable. All findings are from training data through ~August 2025. Confidence levels are marked per section. Verify package versions on pub.dev before adopting.

---

## 1. Local Data Persistence

### The Candidates

**SharedPreferences** — CONFIDENCE: HIGH

Stores key-value pairs using platform-native mechanisms (NSUserDefaults on iOS/macOS, SharedPreferences on Android, localStorage on Web, JSON file on Windows/Linux). Suitable only for scalars and simple settings. Cannot handle object graphs, queries, or indexes. Cross-platform: all six platforms. Use it for user settings (wake time, work window preferences, notification toggle). Not the primary store.

**sqflite** — CONFIDENCE: HIGH

Wraps SQLite on mobile and macOS. Mature and battle-tested, but has a critical gap: it does not support Web natively. `sqflite_common_ffi` covers Linux, Windows, and macOS via FFI, but Web requires a fully separate storage strategy. Canopy targets all six platforms, which makes sqflite painful as a primary store — you would maintain two persistence code paths.

**Verdict: Eliminated as primary store due to the web gap.**

**hive_ce** — CONFIDENCE: MEDIUM

The original `hive` package became unmaintained around 2023. `hive_ce` (Community Edition) is the active community fork, API-compatible with Hive 2.x, Dart 3 null-safety compliant. NoSQL box-based storage with typed adapters generated via `build_runner`. Supports all six platforms including Web (IndexedDB). No native query engine — filtering is done in Dart after loading data. For moderate data volumes (one user, one year of logs), this is acceptable. Migration tooling is manual — you write version-check logic at app startup. The migration pain is real but manageable with discipline.

**Verdict: Safe fallback for all-platform support. Weak on queries at scale.**

**Isar** — CONFIDENCE: MEDIUM (maintenance status is LOW — must verify)

Isar is a NoSQL embedded database designed as Hive's spiritual successor. Key advantages over hive_ce: native query engine (no need to load all data into Dart to filter), type-safe compile-time queries, ACID transactions, and an inspector tool for development. Cross-platform including Web. As of mid-2025, Isar 3.x was stable. However, the original author announced a 4.0 Rust rewrite that was in development but not released, creating community uncertainty about the maintenance trajectory.

**Before adopting Isar:** Verify on pub.dev that it has a high score, recent activity, and compatibility with Dart ^3.10.3. If 4.0 is released and stable, it is the strongest choice. If maintenance is uncertain, fall back to hive_ce.

**Verdict: Best feature set if healthy. Verify status before adopting.**

### Recommendation

- **Primary store:** Isar (if confirmed maintained) or hive_ce (safe fallback)
- **Settings store:** shared_preferences
- **Do not use:** Original Hive 2.x (unmaintained), sqflite as primary (web gap)

### Schema Design for Canopy

```
Goal
  id: String (UUID)
  name: String
  weeklyHoursTarget: double
  color: int (ARGB)
  isActive: bool
  createdAt: DateTime
  archivedAt: DateTime?

CommitmentBlock
  id: String (UUID)
  name: String
  recurrenceDays: List<int>     // 0=Mon..6=Sun
  startMinute: int              // minutes from midnight
  durationMinutes: int
  isActive: bool

DailySchedule
  id: String
  date: DateTime (normalized to midnight, UTC)
  generatedAt: DateTime
  moodScore: int (1–5)
  chunks: List<ScheduledChunk>  // embedded

ScheduledChunk
  id: String
  goalId: String?               // null for breaks
  commitmentBlockId: String?    // null for discretionary chunks
  chunkType: ChunkType (enum: work, shortBreak, longBreak)
  startMinute: int              // minutes from midnight
  durationMinutes: int          // 25 for work/longBreak, 5 for shortBreak
  label: String?
  status: ChunkStatus (enum: scheduled, completed, skipped, partial)
  completedDurationMinutes: int?

CompletionLog                   // append-only, never mutated
  id: String
  chunkId: String
  goalId: String?
  date: DateTime
  completedAt: DateTime
  scheduledMinutes: int
  actualMinutes: int
  note: String?

QuarterlySnapshot
  id: String
  quarter: int (1-4)
  year: int
  generatedAt: DateTime
  goalAllocations: Map<String, double>
  actualHours: Map<String, double>
  reflectionNote: String?
```

Key decisions:
- Embed chunks in DailySchedule (one read = full day)
- Break chunks (shortBreak, longBreak) stored in schedule with null goalId — enables full timeline reconstruction
- CommitmentBlock defines recurring windows; schedule generation chunks them up on the day
- CompletionLog is append-only (event sourcing lite — audit trail, reliable aggregation)
- Goals are soft-deleted (archived), never hard-deleted
- All times stored as UTC; schedule offsets as "minutes from midnight" integers (avoids DST complexity)

### Migration Strategy

Use a versioned migration runner pattern. On app startup, compare stored schema version to current version and run sequential migration functions. Never rename Isar/Hive fields without a migration. Always introduce new fields as nullable first. Test migrations with fixture databases. Back up the database file before running migrations.

---

## 2. State Management at Scale

### How Far Does setState Scale?

setState is appropriate for single-screen self-contained state — form inputs, loading spinners, expansion tiles. It becomes painful when:
- Two screens share the same data simultaneously
- An action in one widget needs to update a widget elsewhere in the tree
- The same data is passed through 4+ constructor levels (prop drilling)
- App-level state (goals list, today's schedule) needs to be accessible deep in the tree

For Canopy, setState becomes a liability at approximately the third screen. The daily schedule and a summary badge in a bottom nav bar will both need access to completion state. Goal edits propagate to schedule display. Background generation needs to notify the UI.

### When to Introduce Provider

InheritedWidget is Flutter's built-in sharing mechanism. Provider wraps it with ergonomics. Do not use raw InheritedWidget when Provider exists.

**Decision criteria:**

| Trigger | Action |
|---------|--------|
| State shared between 2+ unrelated screens | Introduce Provider |
| Passing same object through 3+ widget constructors | Introduce Provider |
| Need to notify UI of background task completion | Introduce Provider |
| Local single-screen state (form inputs, toggles) | Keep setState |

**Recommendation: Plan to introduce Provider when building the second screen. Do not try to avoid it.** Riverpod and Bloc are not appropriate for this project — they add learning curve and boilerplate that is not justified for a solo personal productivity app.

### App-Wide State Pattern

Three categories of state:

**Reference data (rare changes):** Active goals list, user settings, commitment blocks. Load once at startup in a ChangeNotifier. UI listens. Updates trigger re-fetch from database.

**Current day's schedule (frequent mutations):** A ScheduleNotifier holds today's DailySchedule and exposes mutation methods that persist back to the database synchronously.

**Ephemeral UI state:** Tab selection, dialog open/closed, scroll position. Keep in setState at the widget level. Do not lift into global notifiers.

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => GoalsNotifier()),
    ChangeNotifierProvider(create: (_) => CommitmentsNotifier()),
    ChangeNotifierProvider(create: (_) => ScheduleNotifier()),
    ChangeNotifierProvider(create: (_) => SettingsNotifier()),
  ],
  child: MaterialApp.router(routerConfig: router),
)
```

---

## 3. Flutter Architecture Patterns

### Screen Decomposition

**OnboardingScreen:** CommitmentBlockSetup (recurring time windows) + GoalForm + QuickSchedulePreview.

**GoalSetupScreen:** GoalForm (name, hours slider, color picker, active toggle) + GoalList with GoalCard items.

**DailyScheduleScreen:** ScheduleHeader (date, mood badge) + ChunkTimeline (interleaved work chunks and breaks) + DayCompletionSummary.

**Chunk tracking:** ChunkDetailSheet (modal bottom sheet) with CompletionControls (complete/skip/partial) and ChunkNoteField.

**QuarterlyReviewScreen:** QuarterSelector + GoalAllocationChart + GoalBreakdownList + ReflectionNoteField + ExportButton.

Widget decomposition principles:
- Screens own data fetching via Provider
- Sub-widgets receive data via constructors (keeps them testable and reusable)
- Bottom sheets are separate widget files, not anonymous builders
- Charts are isolated widgets with mock-data constructors

### Navigation: Use go_router

**CONFIDENCE: HIGH**

Three options exist: named routes in MaterialApp (simple, but broken on Web), Navigator 2.0 (full control, extremely verbose), and go_router (declarative, typed, Flutter team maintained).

Canopy targets Web. Named routes in MaterialApp do not handle web URL navigation correctly (back button, URL bar routing breaks). go_router is the correct choice. It handles all six target platforms, supports StatefulShellRoute for bottom navigation stacks, and the learning curve is minimal.

Use `StatefulShellRoute` for bottom navigation to preserve per-tab navigation stacks.

### Background Tasks: Notification-Triggered in v1

**CONFIDENCE: MEDIUM for the platform analysis; HIGH for the recommendation**

Reliable background execution across all six platforms is not achievable in v1:

| Platform | Background execution | Notes |
|----------|---------------------|-------|
| Android | Possible (WorkManager / workmanager package) | OS may defer; battery optimization |
| iOS | Very restricted | Background Fetch is inexact and quota-limited |
| Web | Not possible | No persistent background workers |
| Windows | Possible | Platform channels required |
| macOS | Restricted | Background App Refresh limits |
| Linux | Possible via system cron | No Flutter abstraction |

**v1 Recommendation: Notification-triggered, not background-executed.** Schedule a daily local notification at the user's configured morning time. When tapped, the app opens and runs schedule generation on launch. This is reliable on all platforms and ships.

Use `flutter_local_notifications` with `matchDateTimeComponents: DateTimeComponents.time` for daily repeating notification. Add the `timezone` package for correct local time scheduling.

---

## 4. Platform Considerations

### Storage Paths

Use `path_provider` for platform-appropriate directories. Never hardcode paths. On Web, path_provider returns dummy values — Isar and hive_ce handle web storage via their IndexedDB adapters automatically.

### Notifications Across Platforms

`flutter_local_notifications` supports Android, iOS, macOS, Windows, and Linux. Web is not supported. Android 12+ requires the `SCHEDULE_EXACT_ALARM` permission for exact-time alarms. iOS requires a user permission prompt that can be denied — design a graceful fallback (manual "generate schedule" button always visible).

### Cross-Platform Gotchas

1. **dart:io on Web crashes** — Use conditional imports to abstract file/platform access
2. **sqflite on Web** — Confirmed non-functional; another reason to avoid sqflite as primary
3. **Bottom navigation bar insets on Android** — Use SafeArea or MediaQuery padding
4. **Keyboard avoidance** — Use `resizeToAvoidBottomInset: true` consistently; test on Android and desktop
5. **Mouse/touch on desktop** — Add MouseRegion hover states and right-click context menus for desktop platforms
6. **Window sizing on desktop** — Flutter desktop windows are resizable; a mobile-width layout looks sparse at 1440px. Use `LayoutBuilder` for adaptive layouts. Consider `window_manager` package for minimum window size defaults
7. **Web URL routing** — go_router requires correct base-href configuration in `web/index.html`

---

## 5. Recommended Package List

Verify all versions on pub.dev against Dart ^3.10.3 before adopting:

| Package | Approx Version | Purpose | Phase |
|---------|---------------|---------|-------|
| `isar` + `isar_flutter_libs` | ^3.x or 4.x | Primary database | 1 — verify first |
| `hive_ce` + `hive_ce_generator` | ^2.x | DB fallback | 1 — if Isar uncertain |
| `shared_preferences` | ^2.x | Settings only | 1 |
| `path_provider` | ^2.x | Platform file paths | 1 |
| `uuid` | ^4.x | Entity ID generation | 1 |
| `intl` | ^0.19.x | Date/time formatting | 1 |
| `go_router` | ^14.x | Navigation | 2 |
| `provider` | ^6.x | State management | 2 |
| `flutter_local_notifications` | ^17.x | Morning reminders | 4 |
| `timezone` | ^0.9.x | Correct time zone scheduling | 4 |
| `build_runner` | ^2.x | Code gen (dev dep) | 1 |

Defer: Riverpod, Bloc, Firebase, charting libraries (add charting at Phase 5 only).

---

## 6. Roadmap Phase Implications

**Phase 1 — Foundation:** Isar or hive_ce setup, repository pattern with abstract interfaces, shared_preferences, uuid, intl, go_router stubs, GoalsNotifier scaffold.

**Phase 2 — Goal & Commitment Setup:** Goal CRUD, CommitmentBlock CRUD, GoalsNotifier + CommitmentsNotifier, Provider at MultiProvider level, migration framework established.

**Phase 3 — Daily Schedule:** DailySchedule + ScheduledChunk entities (including break chunks), ScheduleNotifier, schedule generation logic (pure Dart, triggered on app open), schedule UI with interleaved breaks.

**Phase 4 — Chunk Tracking:** CompletionLog entities, chunk status mutations, flutter_local_notifications morning reminder.

**Phase 5 — Quarterly Review:** CompletionLog aggregation, QuarterlySnapshot, add charting library (fl_chart recommended).

**Phase 6 — Desktop/Web Polish:** LayoutBuilder adaptive layouts, window_manager for desktop, hover states, go_router web URL verification.

---

## 7. Open Questions

1. **Isar 4.0 status** — Is the Rust rewrite released and stable? Determines primary database choice.
2. **flutter_local_notifications Web support** — Has web notification scheduling been added? Affects v1 web strategy.
3. **flutter_adaptive_scaffold maturity** — Was experimental in mid-2025; verify before using over manual LayoutBuilder.
4. **Quarterly review charting** — Defer fl_chart vs syncfusion vs CustomPainter decision to Phase 5.

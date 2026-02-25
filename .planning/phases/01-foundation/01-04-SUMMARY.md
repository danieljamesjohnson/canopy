---
phase: 01-foundation
plan: 04
subsystem: database
tags: [hive_ce, go_router, provider, shared_preferences, flutter, dart, repositories, migrations]

# Dependency graph
requires:
  - phase: 01-foundation/01-02
    provides: 7 Hive entity models with TypeAdapters (typeIds 0-6)
  - phase: 01-foundation/01-03
    provides: go_router StatefulShellRoute, SettingsNotifier, createRouter factory

provides:
  - 6 abstract repository interfaces (GoalRepository, CommitmentBlockRepository, DailyScheduleRepository, CompletionLogRepository, QuarterlySnapshotRepository, AppSettingsRepository)
  - 6 HiveRepository stub implementations
  - HiveDatabase initializer that registers all 7 adapters and opens all boxes
  - Migration runner with version-integer pattern (schemaVersion in SharedPreferences)
  - main.dart wiring: HiveDatabase.init -> MultiProvider -> MaterialApp.router
  - Unit tests for GoalRepository interface via InMemoryGoalRepository

affects:
  - Phase 2 feature development (all data access goes through repository interfaces)
  - Future migration additions (add to _migrations list in migrations.dart)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Repository pattern with abstract interfaces + Hive stub implementations
    - Migration runner using version-integer list (index 0 = v0->v1, index 1 = v1->v2, etc.)
    - SettingsNotifier constructed before Provider tree, passed to both MultiProvider and createRouter
    - ChangeNotifierProvider.value for pre-constructed notifier instances

key-files:
  created:
    - lib/data/repositories/goal_repository.dart
    - lib/data/repositories/hive_goal_repository.dart
    - lib/data/repositories/commitment_block_repository.dart
    - lib/data/repositories/hive_commitment_block_repository.dart
    - lib/data/repositories/daily_schedule_repository.dart
    - lib/data/repositories/hive_daily_schedule_repository.dart
    - lib/data/repositories/completion_log_repository.dart
    - lib/data/repositories/hive_completion_log_repository.dart
    - lib/data/repositories/quarterly_snapshot_repository.dart
    - lib/data/repositories/hive_quarterly_snapshot_repository.dart
    - lib/data/repositories/app_settings_repository.dart
    - lib/data/repositories/hive_app_settings_repository.dart
    - lib/data/database/hive_database.dart
    - lib/data/database/migrations.dart
    - test/repositories/goal_repository_test.dart
  modified:
    - lib/main.dart
    - test/widget_test.dart

key-decisions:
  - "SettingsNotifier constructed before MultiProvider so same instance is passed to createRouter and registered via ChangeNotifierProvider.value"
  - "Migration runner stores schemaVersion as int in SharedPreferences; index 0 in _migrations list = migration from v0 to v1"
  - "CompletionLog and QuarterlySnapshot repository interfaces have no delete/update methods (append-only constraint enforced at interface level)"
  - "AppSettingsRepository uses single-record box with key 'settings'"
  - "In-memory repository implementation used in tests to avoid Hive dependency in unit tests"

patterns-established:
  - "Repository pattern: abstract interface in goal_repository.dart, Hive implementation in hive_goal_repository.dart"
  - "Append-only enforcement via interface omission: no delete/update methods on CompletionLog and QuarterlySnapshot repositories"
  - "Migration list is additive-only: never modify existing entries, only append new migrations"

requirements-completed: [foundation-implicit]

# Metrics
duration: 10min
completed: 2026-02-25
---

# Phase 1 Plan 04: Repository Interfaces, Database Init, and App Wiring Summary

**6 abstract repository interfaces + Hive stubs, HiveDatabase initializer with 7-adapter registration and migration runner, and final main.dart wiring HiveDatabase.init -> MultiProvider -> MaterialApp.router into a running Flutter app**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-02-25T12:20:00Z
- **Completed:** 2026-02-25T12:30:06Z
- **Tasks:** 3 (2 auto + 1 human-verify)
- **Files modified:** 16

## Accomplishments

- Created 6 abstract repository interfaces with appropriate method signatures; CompletionLog and QuarterlySnapshot are append-only (no delete/update at interface level)
- Created 6 HiveRepository stub implementations returning empty/null values; registered all 7 TypeAdapters and opened all boxes in HiveDatabase.init
- Replaced main.dart with full wired entry point: WidgetsFlutterBinding.ensureInitialized -> HiveDatabase.init -> MultiProvider with 4 notifiers -> MaterialApp.router
- Migration runner with version-integer pattern: stores schemaVersion in SharedPreferences, runs v0->v1 on first launch
- 5 GoalRepository unit tests passing via InMemoryGoalRepository (no Hive required in tests)
- Human verified: app runs on Web and Android with routing, onboarding redirect, and no console errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Create repository interfaces, stub implementations, and database init** - `c1a1024` (feat)
2. **Task 2: Wire main.dart with MultiProvider and MaterialApp.router, add unit tests** - `97512ed` (feat)
3. **Task 3: Human verify** - Approved by user (no code commit required)

## Files Created/Modified

- `lib/data/repositories/goal_repository.dart` - Abstract GoalRepository interface (getAll, getById, save, delete, getActive)
- `lib/data/repositories/hive_goal_repository.dart` - Hive stub implementation
- `lib/data/repositories/commitment_block_repository.dart` - Abstract interface (getAll, getById, save, delete, getByDayOfWeek)
- `lib/data/repositories/hive_commitment_block_repository.dart` - Hive stub implementation
- `lib/data/repositories/daily_schedule_repository.dart` - Abstract interface (getAll, getById, save, delete, getByDate, getTodaysSchedule)
- `lib/data/repositories/hive_daily_schedule_repository.dart` - Hive stub implementation
- `lib/data/repositories/completion_log_repository.dart` - Append-only abstract interface (getAll, getById, append, getByDate, getByGoalId)
- `lib/data/repositories/hive_completion_log_repository.dart` - Hive stub implementation
- `lib/data/repositories/quarterly_snapshot_repository.dart` - Append-only abstract interface (getAll, getById, append, getLatest)
- `lib/data/repositories/hive_quarterly_snapshot_repository.dart` - Hive stub implementation
- `lib/data/repositories/app_settings_repository.dart` - Single-record abstract interface (getSettings, saveSettings)
- `lib/data/repositories/hive_app_settings_repository.dart` - Hive stub implementation
- `lib/data/database/hive_database.dart` - Registers 7 TypeAdapters (typeIds 0-6) and opens all boxes
- `lib/data/database/migrations.dart` - Migration runner with version-integer pattern
- `lib/main.dart` - Full wired entry point with MultiProvider and MaterialApp.router
- `test/widget_test.dart` - Replaced counter demo test with placeholder
- `test/repositories/goal_repository_test.dart` - 5 unit tests for GoalRepository via InMemoryGoalRepository

## Decisions Made

- **SettingsNotifier sharing pattern:** SettingsNotifier is constructed before MultiProvider so the same instance can be passed to both `createRouter(settingsNotifier)` and registered via `ChangeNotifierProvider.value`. This avoids a chicken-and-egg problem where GoRouter would need the notifier before the Provider tree exists.
- **Migration runner design:** Version stored as int in SharedPreferences under key `schemaVersion`. `_migrations` list is index-based (index 0 = v0->v1). On first launch: storedVersion=0, runs migration 0->1, sets schemaVersion=1. Future migrations are appended; existing entries never modified.
- **Append-only via interface omission:** CompletionLog and QuarterlySnapshot have no `delete` or `update` methods on their abstract interfaces. This enforces the append-only constraint at compile time rather than at runtime.
- **In-memory test repository:** Unit tests use `InMemoryGoalRepository implements GoalRepository` to avoid Hive initialization in tests. Tests cover all 5 interface methods including UUID format validation.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Human Verification Result

User approved. App verified running on:
- Web (flutter run -d chrome): loads in browser, redirects to /onboarding, no console errors
- Android: launches to Onboarding screen, bottom nav visible on /home with 4 tabs (Home, Goals, Schedule, Settings), tab navigation working

flutter analyze: zero issues
flutter test: all 5 GoalRepository tests pass

## Next Phase Readiness

- Complete Phase 1 foundation is in place: packages, models, routing, notifiers, repositories, database init, and app wiring
- Phase 2 feature development can now implement real business logic against the repository interfaces
- To add a new migration: append a new function to `_migrations` in migrations.dart and increment `currentSchemaVersion`
- Repository interfaces are ready for dependency injection into feature notifiers

---
*Phase: 01-foundation*
*Completed: 2026-02-25*

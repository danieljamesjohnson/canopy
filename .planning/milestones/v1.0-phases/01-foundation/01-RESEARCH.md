# Phase 1: Foundation - Research

**Researched:** 2026-02-24
**Domain:** Flutter persistence layer, routing scaffold, state management scaffold
**Confidence:** HIGH (database decision), HIGH (routing), HIGH (state management)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Database Package Selection**
- The phase researcher must check pub.dev at the start of Phase 1 to verify Isar's current maintenance status (pub.dev score, recent commits, Dart ^3.10.3 compatibility)
- Decision rule: Use Isar if pub.dev confirms it is actively maintained; fall back to hive_ce if maintenance is uncertain or the score is low
- If both are equally viable, Claude's discretion — no strong user preference between them
- sqflite is eliminated regardless (no native Web support)

**Repository Interface Scope**
- Define interfaces for all 6 entities from day one: Goal, CommitmentBlock, DailySchedule (with embedded ScheduledChunk list), CompletionLog, QuarterlySnapshot, AppSettings
- Implementations in Phase 1 are stubs only — no business logic, just the interface contracts
- This prevents rework when Phases 2–5 arrive and need these interfaces to already exist

**Migration Runner**
- Use simple version integer + sequential runner pattern: store a schema version number, and on every app launch run any un-run migrations in ascending order
- Established in Phase 1 so it's available for every schema change that follows
- No need to have actual migrations to run in Phase 1 — just the runner infrastructure

### Claude's Discretion

- If Isar and hive_ce are equally well-maintained, choose whichever the researcher considers the better long-term fit for a Flutter app targeting all 6 platforms
- App shell appearance (placeholder colors, typography) — use a sensible default for now, no strong preference expressed
- Navigation structure (bottom nav vs drawer) — Claude decides based on mobile-first productivity app conventions

### Deferred Ideas (OUT OF SCOPE)

- None — discussion stayed within phase scope
</user_constraints>

---

## Summary

The critical decision for Phase 1 is the database package selection. Research confirms that the **original Isar 3.x package does not support Flutter Web** — its stable release (3.1.0+1) was published two years ago, and the v4 dev branch has never shipped stable. More critically, Isar has a fundamental architectural blocker for Web: it relies on FFI and `dart:ffi` which cannot compile to WebAssembly. A community fork (`isar_plus`) claims to resolve this via SQLite/WASM but is a single-maintainer package with 29 likes and only 9 days between this research and its last release — not a safe foundation for a 6-platform production app.

**hive_ce** is the correct choice for this project. It has a pub.dev score of 160, was published 21 days ago (v2.19.3), explicitly supports all 6 Flutter platforms including Web with WASM (with one known int/double type coercion bug that was fixed in 2.17.0), and is actively maintained by a community of contributors rather than a single person. The decision rule from CONTEXT.md ("Isar if active; hive_ce if uncertain") resolves cleanly: Isar 3.x stable is stale, Isar 4.x is not stable, and the Web support gap is a hard blocker for this project's 6-platform requirement.

**go_router** (v17.1.0, published by flutter.dev) is the unambiguous standard for Flutter routing in 2026. `StatefulShellRoute.indexedStack` with `StatefulShellBranch` per tab is the current recommended pattern for bottom navigation with persistent tab state. **Provider** (v6.1.5+1) remains the standard ChangeNotifier wrapper. All other supporting packages (shared_preferences, uuid, intl, path_provider) are stable, actively maintained, and support all 6 platforms — with the documented exception that path_provider has no Web support (which is expected; Web uses the browser's storage APIs directly).

**Primary recommendation:** Use hive_ce + hive_ce_flutter + hive_ce_generator. Wire go_router with StatefulShellRoute for the bottom navigation shell. MultiProvider at root with three ChangeNotifiers. The foundation is straightforward; the main risk is the hive_ce code generation step and ensuring build_runner is configured correctly before the first run.

---

## Database Decision: hive_ce (CHOSEN)

### Decision Evidence

| Factor | Isar 3.x (stable) | Isar 4.x (dev) | isar_plus | hive_ce |
|--------|-------------------|----------------|-----------|---------|
| Latest stable | 3.1.0+1 | Never shipped | 1.2.2 | 2.19.3 |
| Published | 2 years ago | N/A | 9 days ago | 21 days ago |
| pub.dev score | 130 | N/A | 150 | 160 |
| Likes | 2,430 | — | 29 | 523 |
| Flutter Web support | No | No (FFI blocker) | Yes (SQLite/WASM) | Yes (IndexedDB) |
| Dart 3.10.3 compat | Unconfirmed | Unconfirmed | Unconfirmed | Yes |
| Maintainers | 2 (stalled) | 2 (stalled) | 1 (community fork) | Community team |
| WASM support | No | No | Yes | Yes (v2.17.0+ fixed) |

**Decision: hive_ce.** The CONTEXT.md decision rule is met: Isar's stable release is stale (2 years old), there is no stable v4, and Web support is architecturally blocked. hive_ce has a higher score, more recent activity, and all 6 platforms confirmed. The discretion clause ("choose the better long-term fit") also favors hive_ce given that isar_plus is a single-maintainer community fork with minimal adoption.

### Known hive_ce Web/WASM Issue

There is a known WASM type coercion issue tracked in the Flutter repo (flutter/flutter#159400): int and double? values stored in IndexedDB may be returned with incorrect types in WASM builds. **This was fixed in hive_ce 2.17.0** (`Fixes WASM int decoding`). Use `^2.19.3` to get the fix. This is a non-issue for Phase 1 stubs but must be kept in mind when writing entity adapters in Phase 2.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| hive_ce | ^2.19.3 | NoSQL key-value/box database, all 6 platforms | Community-maintained continuation of Hive v2; 160/160 pub score, active |
| hive_ce_flutter | ^2.3.4 | Flutter init + path_provider integration for hive_ce | Required companion for Flutter apps; handles app doc directory init |
| go_router | ^17.1.0 | Declarative URL-based routing | Published by flutter.dev; 150/150 score; 5.66k likes; Web URL support |
| provider | ^6.1.5+1 | ChangeNotifier wrapper + InheritedWidget | 150/150 score; 10.9k likes; flutter.dev-blessed |
| shared_preferences | ^2.5.4 | Primitive key-value persistence (settings, flags) | Flutter Favorite, flutter.dev publisher; 140/150; all 6 platforms |
| uuid | ^4.5.3 | UUID v4 generation for all entity IDs | All platforms, actively maintained (published 3 days ago) |
| intl | ^0.20.2 | Date formatting, locale support | dart.dev publisher; all platforms; needed for time display in later phases |
| path_provider | ^2.1.5 | Filesystem paths on mobile/desktop (not Web) | flutter.dev publisher; Flutter Favorite; used by hive_ce_flutter internally |

### Dev Dependencies

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| hive_ce_generator | ^1.11.1 | Auto-generates TypeAdapters from annotated classes | Required for code generation pattern; run via build_runner |
| build_runner | ^2.x | Dart code generation runner | Required to generate .g.dart files from hive_ce annotations |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| hive_ce | isar_plus | isar_plus has Web support but is single-maintainer, 29 likes, unverified Dart 3.10.3 compat |
| hive_ce | drift | drift is excellent but heavier (SQL layer, more setup); hive_ce is simpler for this document-style data |
| hive_ce | objectbox | objectbox has Web limitations and requires native libraries; more complex setup |
| go_router | auto_route | auto_route is solid but code-gen heavy; go_router is flutter.dev standard, no extra codegen needed |
| provider | riverpod | riverpod is more powerful but overkill for this app's scope; provider is sufficient and simpler |

**Installation:**
```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  hive_ce: ^2.19.3
  hive_ce_flutter: ^2.3.4
  go_router: ^17.1.0
  provider: ^6.1.5+1
  shared_preferences: ^2.5.4
  uuid: ^4.5.3
  intl: ^0.20.2
  path_provider: ^2.1.5

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  hive_ce_generator: ^1.11.1
  build_runner: ^2.4.13
```

---

## Architecture Patterns

### Recommended Project Structure

```
lib/
├── main.dart                    # App entry point, MultiProvider, router config
├── router.dart                  # GoRouter instance + route definitions
├── data/
│   ├── models/                  # Hive entity classes + generated adapters
│   │   ├── goal.dart
│   │   ├── goal.g.dart          # generated
│   │   ├── commitment_block.dart
│   │   ├── daily_schedule.dart
│   │   ├── scheduled_chunk.dart # embedded in DailySchedule
│   │   ├── completion_log.dart
│   │   ├── quarterly_snapshot.dart
│   │   └── app_settings.dart
│   ├── repositories/
│   │   ├── goal_repository.dart         # abstract interface
│   │   ├── commitment_block_repository.dart
│   │   ├── daily_schedule_repository.dart
│   │   ├── completion_log_repository.dart
│   │   ├── quarterly_snapshot_repository.dart
│   │   └── app_settings_repository.dart
│   └── database/
│       ├── hive_database.dart           # init, box access, migration runner
│       └── migrations.dart             # migration list
├── providers/
│   ├── goals_notifier.dart
│   ├── commitments_notifier.dart
│   ├── schedule_notifier.dart
│   └── settings_notifier.dart
└── screens/
    ├── home/
    │   └── home_screen.dart             # stub
    ├── onboarding/
    │   └── onboarding_screen.dart       # stub
    ├── goals/
    │   └── goals_screen.dart            # stub
    ├── schedule/
    │   └── schedule_screen.dart         # stub
    ├── quarterly_review/
    │   └── quarterly_review_screen.dart # stub
    └── settings/
        └── settings_screen.dart         # stub
```

### Pattern 1: hive_ce Entity + TypeAdapter

**What:** Annotate Dart classes with `@HiveType` and `@HiveField`. Run build_runner to generate `.g.dart` TypeAdapters. Each entity gets a unique `typeId` integer.

**When to use:** Every entity that will be stored in Hive.

**Example:**
```dart
// lib/data/models/goal.dart
import 'package:hive_ce/hive.dart';

part 'goal.g.dart';

@HiveType(typeId: 0)
class Goal extends HiveObject {
  @HiveField(0)
  late String id; // UUID v4 string

  @HiveField(1)
  late String name;

  @HiveField(2)
  late int goalType; // maps to GoalType enum

  @HiveField(3)
  late bool isArchived;

  // ... additional fields added in Phase 2
}
```

After defining models, generate adapters:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Pattern 2: Repository Interface (Abstract Class)

**What:** Define an abstract Dart class (interface) for each entity with CRUD method signatures. Phase 1 provides a stub/in-memory implementation. Later phases swap in the Hive implementation.

**When to use:** All 6 entities from day one — locks the contract before Phase 2 implements real logic.

**Example:**
```dart
// lib/data/repositories/goal_repository.dart
abstract class GoalRepository {
  Future<List<Goal>> getAll();
  Future<Goal?> getById(String id);
  Future<void> save(Goal goal);
  Future<void> delete(String id);
  Future<List<Goal>> getActive();
}

// lib/data/repositories/hive_goal_repository.dart (stub implementation)
class HiveGoalRepository implements GoalRepository {
  @override
  Future<List<Goal>> getAll() async => [];

  @override
  Future<Goal?> getById(String id) async => null;

  @override
  Future<void> save(Goal goal) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<Goal>> getActive() async => [];
}
```

### Pattern 3: Migration Runner

**What:** Store a schema version integer in shared_preferences. On app init, compare stored version to `currentSchemaVersion`. Run any pending migrations in ascending order. Update stored version after all migrations run.

**When to use:** Every app launch, before any database access.

**Example:**
```dart
// lib/data/database/migrations.dart
const int currentSchemaVersion = 1;

// Each migration is a function that takes box handles and transforms data
typedef MigrationFn = Future<void> Function();

final List<MigrationFn> migrations = [
  // index 0 = migration from version 0 → 1 (initial schema, no-op in Phase 1)
  _migration_0_to_1,
];

Future<void> _migration_0_to_1() async {
  // Phase 1: initial schema. No data transformation needed.
  // Future phases will add real migrations here.
}

// lib/data/database/hive_database.dart
Future<void> runMigrations(SharedPreferences prefs) async {
  final int storedVersion = prefs.getInt('schemaVersion') ?? 0;
  for (int i = storedVersion; i < currentSchemaVersion; i++) {
    await migrations[i]();
  }
  await prefs.setInt('schemaVersion', currentSchemaVersion);
}
```

### Pattern 4: go_router with StatefulShellRoute

**What:** `StatefulShellRoute.indexedStack` wraps branches (tabs). Each branch is a `StatefulShellBranch` with its own navigator key and initial route. Preserves tab state when switching between tabs.

**When to use:** The app's primary navigation — bottom nav bar on mobile (Claude's discretion: bottom nav is standard for mobile-first productivity apps; use `NavigationBar` widget from Material 3).

**Example:**
```dart
// lib/router.dart
final GoRouter router = GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/goals', builder: (_, __) => const GoalsScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/schedule', builder: (_, __) => const ScheduleScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/review', builder: (_, __) => const QuarterlyReviewScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
          ],
        ),
      ],
    ),
    // Onboarding is outside the shell (no bottom nav shown)
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
  ],
);
```

### Pattern 5: MultiProvider at Root with ChangeNotifiers

**What:** Wrap `MaterialApp.router` with `MultiProvider`. Register all notifiers as `ChangeNotifierProvider`. Notifiers start empty (no business logic in Phase 1).

**When to use:** App root in `main.dart`.

**Example:**
```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await HiveDatabase.init(prefs); // registers adapters, opens boxes, runs migrations
  runApp(const CanopyApp());
}

class CanopyApp extends StatelessWidget {
  const CanopyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GoalsNotifier()),
        ChangeNotifierProvider(create: (_) => CommitmentsNotifier()),
        ChangeNotifierProvider(create: (_) => ScheduleNotifier()),
        ChangeNotifierProvider(create: (_) => SettingsNotifier()),
      ],
      child: MaterialApp.router(
        title: 'Canopy',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrangeAccent),
          useMaterial3: true,
        ),
        routerConfig: router,
      ),
    );
  }
}
```

### Pattern 6: Hive Initialization

**What:** hive_ce must be initialized before any box is opened. On mobile/desktop, `Hive.initFlutter()` (from hive_ce_flutter) sets the storage path. On Web, Hive uses IndexedDB automatically — `Hive.initFlutter()` still works.

**When to use:** Before `runApp()` in `main()`.

**Example:**
```dart
// lib/data/database/hive_database.dart
import 'package:hive_ce_flutter/hive_flutter.dart';

class HiveDatabase {
  static Future<void> init(SharedPreferences prefs) async {
    await Hive.initFlutter(); // handles path_provider on mobile/desktop; IndexedDB on web

    // Register all TypeAdapters
    Hive.registerAdapter(GoalAdapter());
    Hive.registerAdapter(CommitmentBlockAdapter());
    Hive.registerAdapter(DailyScheduleAdapter());
    Hive.registerAdapter(ScheduledChunkAdapter());
    Hive.registerAdapter(CompletionLogAdapter());
    Hive.registerAdapter(QuarterlySnapshotAdapter());
    Hive.registerAdapter(AppSettingsAdapter());

    // Open boxes
    await Hive.openBox<Goal>('goals');
    await Hive.openBox<CommitmentBlock>('commitment_blocks');
    await Hive.openBox<DailySchedule>('daily_schedules');
    await Hive.openBox<CompletionLog>('completion_logs');
    await Hive.openBox<QuarterlySnapshot>('quarterly_snapshots');
    await Hive.openBox<AppSettings>('app_settings');

    // Run schema migrations
    await runMigrations(prefs);
  }
}
```

### Anti-Patterns to Avoid

- **Opening boxes before registering adapters:** Hive throws if you open a typed box before registering its adapter. Always register all adapters before opening any box.
- **Using auto-increment integers as entity IDs:** CONTEXT.md explicitly requires UUID v4 strings for all entity IDs. Use `const Uuid().v4()` from the `uuid` package.
- **Storing UTC times as DateTime objects:** All times are stored as UTC integers (minutes from midnight) per ROADMAP.md. Do not use `DateTime` fields in Hive entities — store `int` and convert at the service layer.
- **Accessing Provider inside GoRouter redirect without refreshListenable:** The router redirect function does not have access to a BuildContext. Use `refreshListenable` to wire a ChangeNotifier to the router, not `Provider.of()` inside redirect.
- **Using `MaterialApp` instead of `MaterialApp.router`:** Once go_router is added, the app must use `MaterialApp.router(routerConfig: router)`. Using `MaterialApp(home: ...)` alongside go_router causes routing conflicts.
- **Calling `build_runner` without `--delete-conflicting-outputs`:** Old generated files conflict with new ones. Always use `dart run build_runner build --delete-conflicting-outputs`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Entity persistence | Custom file serialization | hive_ce boxes | Handles transactions, type safety, platform differences |
| URL-based routing | Named routes in MaterialApp | go_router | Web URL support, deep linking, ShellRoute for persistent nav UI |
| Type adapter generation | Manual HiveObject serialization methods | hive_ce_generator + build_runner | Generated code is error-free and always in sync with model |
| UUID generation | Custom ID strings or timestamps | uuid package | RFC4122 compliance, no collision risk |
| Settings primitives | Custom file for preferences | shared_preferences | Platform-native (NSUserDefaults on iOS, SharedPreferences on Android, localStorage on Web) |
| Schema version tracking | Custom version file | shared_preferences int key | Already a dependency; dead simple; no extra package |

**Key insight:** The hive_ce code generation step (build_runner) is the one area most likely to trip up a first-time setup. Run it before writing any implementation code to verify the pipeline works. If build_runner fails, the most common cause is conflicting analyzer versions between packages.

---

## Common Pitfalls

### Pitfall 1: Isar on Web Fails at Runtime
**What goes wrong:** Adding `isar` and `isar_flutter_libs` and writing for iOS/Android only, then discovering Web fails entirely because Isar uses dart:ffi which cannot compile to WebAssembly.
**Why it happens:** Isar's Web limitations are not obvious from its pub.dev page; the stable version appears to list "web" in supported platforms but the implementation does not work.
**How to avoid:** Decision already made — use hive_ce. Do not use isar or isar_flutter_libs.
**Warning signs:** `dart:ffi` import errors or "not supported on the web" errors in browser console.

### Pitfall 2: hive_ce TypeAdapter typeId Collisions
**What goes wrong:** Two entity classes have the same `typeId` integer. Hive throws a `HiveError: TypeAdapter for typeId X already registered` at init.
**Why it happens:** typeIds must be unique across the entire app (not just per file). Easy to collide when copy-pasting class templates.
**How to avoid:** Maintain a master typeId registry in a comment block or table. Assign sequentially: Goal=0, CommitmentBlock=1, DailySchedule=2, ScheduledChunk=3, CompletionLog=4, QuarterlySnapshot=5, AppSettings=6.
**Warning signs:** `HiveError` exception on first app launch; always happens at `registerAdapter` call.

### Pitfall 3: go_router and Provider Initialization Order
**What goes wrong:** GoRouter is initialized before the Provider tree is built, so `redirect` functions that try to read Provider state during initial navigation fail.
**Why it happens:** GoRouter is typically declared as a top-level final variable, which means it initializes before the widget tree and therefore before any `BuildContext` exists.
**How to avoid:** Use `refreshListenable` in GoRouter constructor to pass a ChangeNotifier (e.g., SettingsNotifier) that GoRouter will listen to for re-evaluation. Do not call `Provider.of(context)` inside `redirect` — instead, hold a reference to the notifier directly.
**Warning signs:** `Error: No Provider found for type X` during route redirect evaluation.

### Pitfall 4: build_runner Not Run Before First Flutter Run
**What goes wrong:** The app fails to compile because `goal.g.dart` (and other `.g.dart` files) do not exist yet.
**Why it happens:** Generated files are not committed to source control (they shouldn't be), but must exist for compilation.
**How to avoid:** Always run `dart run build_runner build --delete-conflicting-outputs` after adding new `@HiveType` entities, and verify `.g.dart` files exist before `flutter run`.
**Warning signs:** `Target of URI hasn't been generated: 'goal.g.dart'` compilation error.

### Pitfall 5: path_provider on Web
**What goes wrong:** `getApplicationDocumentsDirectory()` throws on Web because path_provider has no Web implementation.
**Why it happens:** path_provider explicitly does not support Web. hive_ce_flutter handles this transparently by using IndexedDB on Web without calling path_provider.
**How to avoid:** Never call path_provider APIs directly in code paths that run on Web. Use hive_ce_flutter's `Hive.initFlutter()` which handles the platform difference internally.
**Warning signs:** MissingPluginException or PlatformException when running the app in browser.

### Pitfall 6: Hive Boxes Not Opened Before Access
**What goes wrong:** Code tries to call `Hive.box<Goal>('goals')` synchronously before `Hive.openBox<Goal>('goals')` has completed.
**Why it happens:** Box opening is async. If any code accesses a box before `main()` has awaited `HiveDatabase.init()`, it throws `HiveError: Box not found`.
**How to avoid:** All box opens happen in `HiveDatabase.init()`, which is awaited before `runApp()`. Repository classes should call `Hive.box<T>(name)` (synchronous getter, throws if not open) so errors are immediate and obvious rather than silent.
**Warning signs:** `HiveError: Box 'goals' not found. Did you forget to call Hive.openBox()?`

---

## Code Examples

### Hive Entity with UUID ID Pattern
```dart
// Source: hive_ce pub.dev + uuid pub.dev
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

part 'goal.g.dart';

const _uuid = Uuid();

@HiveType(typeId: 0)
class Goal extends HiveObject {
  Goal({
    String? id,
    required this.name,
    required this.goalTypeIndex,
  }) : id = id ?? _uuid.v4();

  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int goalTypeIndex; // GoalType.index — store enum as int

  @HiveField(3)
  bool isArchived = false;
}
```

### GoRouter MaterialApp.router Integration
```dart
// Source: go_router pub.dev documentation (v17.1.0)
import 'package:go_router/go_router.dart';

final GoRouter router = GoRouter(
  initialLocation: '/home',
  routes: [ /* ... */ ],
);

// In widget:
MaterialApp.router(
  routerConfig: router,
  theme: ThemeData(useMaterial3: true, /* ... */),
)
```

### ChangeNotifier Stub Pattern
```dart
// Standard provider pattern
import 'package:flutter/foundation.dart';

class GoalsNotifier extends ChangeNotifier {
  // Phase 1: empty stub — Phase 2 adds real state and methods
  List<Goal> _goals = [];
  List<Goal> get goals => List.unmodifiable(_goals);
}
```

### Shared Preferences Settings Init
```dart
// Source: shared_preferences pub.dev (v2.5.4)
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsRepository {
  AppSettingsRepository(this._prefs);
  final SharedPreferences _prefs;

  bool get onboardingComplete => _prefs.getBool('onboardingComplete') ?? false;
  Future<void> setOnboardingComplete(bool value) =>
      _prefs.setBool('onboardingComplete', value);

  // Morning notification time stored as minutes from midnight (e.g. 450 = 7:30am)
  int get morningNotificationTime => _prefs.getInt('morningNotificationTime') ?? 450;
  Future<void> setMorningNotificationTime(int minutesFromMidnight) =>
      _prefs.setInt('morningNotificationTime', minutesFromMidnight);
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `MaterialApp(home: ...)` + named routes | `MaterialApp.router(routerConfig: GoRouter(...))` | go_router became flutter.dev standard ~2022 | Web URL support, deep linking, shell routes |
| Hive original (`hive` + `hive_flutter`) | hive_ce + hive_ce_flutter | Original Hive abandoned ~2023, CE forked | WASM support, active maintenance, same API |
| `StatefulWidget.initState` for DB init | `WidgetsFlutterBinding.ensureInitialized()` + async `main()` | Flutter best practice | DB/prefs init before `runApp()` is required |
| ShellRoute (go_router) | StatefulShellRoute.indexedStack | go_router ~v6+ | Tab state preserved when switching between nav items |
| `GoRouter.redirect` reading BuildContext | `refreshListenable` + direct notifier reference | go_router architecture | Avoids missing Provider errors in redirect |

**Deprecated/outdated:**
- `hive` / `hive_flutter`: No updates in 2+ years. Do not use — use `hive_ce` / `hive_ce_flutter` instead.
- `isar` 3.x stable: Two years stale, no Web support. Do not use.
- `sqflite`: Already eliminated by project decision — no Web support.
- `MaterialApp` named routes (`.routes`, `.initialRoute`): Superseded by go_router for multi-platform apps requiring Web URL support.

---

## Open Questions

1. **hive_ce: LazyBox vs Box for large collections**
   - What we know: `Box<T>` loads all records into memory on open. `LazyBox<T>` loads only when accessed.
   - What's unclear: CompletionLog will grow unbounded over time (every chunk completion is appended). For Phase 1, a regular `Box` is fine (stubs only). For Phase 4 when CompletionLog has real data, a `LazyBox` may be preferable.
   - Recommendation: Use regular `Box` for all entities in Phase 1. Add a note in the CompletionLog repository stub to revisit box type in Phase 4.

2. **hive_ce: Embedded object support (ScheduledChunk inside DailySchedule)**
   - What we know: Hive supports lists of Hive objects as field values if the item type also has a registered adapter. ROADMAP.md specifies DailySchedule has an embedded ScheduledChunk list.
   - What's unclear: Whether storing a `List<ScheduledChunk>` as a field in a `DailySchedule` HiveObject works cleanly with typed boxes.
   - Recommendation: ScheduledChunk should be a `@HiveType` class (typeId: 3) with its own adapter. DailySchedule stores `List<ScheduledChunk>` as a `@HiveField`. This is standard hive_ce usage and should work. Verify in Phase 1 entity stubs before Phase 3.

3. **go_router redirect for onboarding gate**
   - What we know: The app needs to redirect to `/onboarding` on first launch if `onboardingComplete` is false. go_router supports `redirect` callbacks + `refreshListenable`.
   - What's unclear: The exact wiring of SettingsNotifier (which wraps SharedPreferences) into the router's `refreshListenable`.
   - Recommendation: Initialize `SettingsNotifier` before `GoRouter` creation; pass the notifier instance directly to `refreshListenable`. The router will re-evaluate redirect whenever `SettingsNotifier.notifyListeners()` is called (e.g., after onboarding completes).

---

## Validation Architecture

Nyquist validation is not configured (`workflow.nyquist_validation` absent from config.json). Skipping this section.

*Note: The project's config.json has `"workflow": { "research": true, "plan_check": true, "verifier": true }` but no `nyquist_validation` key. The standard test command is `flutter test` per CLAUDE.md.*

---

## Sources

### Primary (HIGH confidence)
- pub.dev/packages/hive_ce — version 2.19.3, score 160, published 21 days ago, changelog WASM fix in 2.17.0
- pub.dev/packages/hive_ce_flutter — version 2.3.4, all 6 platforms
- pub.dev/packages/hive_ce_generator — version 1.11.1
- pub.dev/packages/go_router — version 17.1.0, published by flutter.dev, 21 days ago
- pub.dev/packages/provider — version 6.1.5+1, flutter.dev ecosystem
- pub.dev/packages/shared_preferences — version 2.5.4, Flutter Favorite, flutter.dev
- pub.dev/packages/uuid — version 4.5.3, published 3 days ago
- pub.dev/packages/intl — version 0.20.2, dart.dev publisher
- pub.dev/packages/path_provider — version 2.1.5, no Web support confirmed
- github.com/isar/isar/commits/main — last commits June 2025; v4 still in dev; Web blocked by FFI

### Secondary (MEDIUM confidence)
- pub.dev/packages/isar — stable 3.1.0+1 published 2 years ago, confirmed stale
- WebSearch: "Isar database Flutter Web support 2025 WASM limitations" — confirmed FFI/WASM blocker, isar_plus community fork
- pub.dev/packages/isar_plus — version 1.2.2, 29 likes, single maintainer, WASM via SQLite
- github.com/flutter/flutter/issues/159400 — hive_ce WASM int/double bug tracked and fixed in hive_ce 2.17.0
- go_router documentation (pub.dev) — StatefulShellRoute.indexedStack pattern for bottom nav

### Tertiary (LOW confidence)
- WebSearch: "go_router Flutter ShellRoute bottom navigation bar setup example 2025" — StatefulShellRoute pattern confirmed by multiple community sources but not directly verified against go_router v17 changelog

---

## Metadata

**Confidence breakdown:**
- Database decision (hive_ce): HIGH — verified pub.dev scores, recent publish dates, changelog, known issues and fixes, confirmed Web blocker for Isar
- Standard stack versions: HIGH — all fetched directly from pub.dev at research time
- Architecture patterns: HIGH — standard Flutter patterns verified against official documentation
- Migration runner: HIGH — simple pattern, well-understood, no library dependency
- go_router ShellRoute: MEDIUM — documented in go_router pub.dev and multiple credible community sources; v17 API not directly verified against official changelog

**Research date:** 2026-02-24
**Valid until:** 2026-03-24 (stable packages; re-check isar_plus adoption in 30 days if reconsidering)

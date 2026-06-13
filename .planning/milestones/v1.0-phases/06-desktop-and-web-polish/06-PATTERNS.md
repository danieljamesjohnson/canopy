# Phase 6: Desktop and Web Polish - Pattern Map

**Mapped:** 2026-05-12
**Files analyzed:** 17 (10 create + 7 modify + 1 pubspec)
**Analogs found:** 16 / 17 (window_setup_stub has no codebase analog — Dart conditional-import idiom)

## File Classification

### Files to Create

| New File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/providers/theme_notifier.dart` | provider (ChangeNotifier) | event-driven + ticker | `lib/providers/settings_notifier.dart` | exact (same role, Hive-backed ChangeNotifier) |
| `lib/platform/window_setup.dart` | platform glue (conditional re-export) | n/a (compile-time switch) | (none — standard Dart idiom; closest existing kIsWeb gate: `lib/services/notification_service.dart:3,34`) | no analog (new pattern) |
| `lib/platform/window_setup_io.dart` | platform glue (real impl) | one-shot init | `lib/services/notification_service.dart:1-79` (kIsWeb early-return + `Platform.is*` gate + ensureInitialized) | role-match (init service) |
| `lib/platform/window_setup_stub.dart` | platform glue (web no-op) | n/a | `lib/services/notification_service.dart:34` (`if (kIsWeb) return;`) | partial (no-op convention) |
| `lib/widgets/responsive_shell.dart` | screen widget (layout) | request-response (rebuild on constraints) | `lib/screens/onboarding/onboarding_screen.dart:567-588` (`_ScreenLayout` — the only existing `LayoutBuilder`) + `lib/router.dart:117-143` (`_ScaffoldWithNavBar` — the body to wrap) | role-match (layout) + exact (nav shell to swap) |
| `test/test_helpers/mood_pump.dart` | test helper | n/a | `test/screens/quarterly_review_test.dart:31` (the `_wrap` helper this replaces) | exact (same purpose) |
| `test/test_helpers/viewport.dart` | test helper | n/a | (no existing analog — first use of `tester.view.physicalSize`); closest API consumer: `test/screens/quarterly_review_test.dart` `tester.pumpWidget` style | no analog (new helper) |
| `test/providers/theme_notifier_test.dart` | unit test | n/a | `test/repositories/goal_repository_test.dart:1-50` (in-memory fake + `setUp` + `test()` blocks) | role-match (unit test) |
| `test/screens/responsive_layout_test.dart` | widget test | n/a | `test/screens/quarterly_review_test.dart:38-95` (`testWidgets` with `_wrap` + `find.byType`) | role-match (widget test) |
| `test/screens/chunk_card_hover_test.dart` | widget test | n/a | `test/screens/quarterly_review_test.dart:38-95` | role-match |
| `test/screens/goal_card_hover_test.dart` | widget test | n/a | `test/screens/quarterly_review_test.dart:38-95` | role-match |
| `test/screens/goal_card_drag_handle_test.dart` | widget test | n/a | `test/screens/quarterly_review_test.dart:171-207` (`GoalAdjustmentTile` test using `ReorderableListView`) | role-match (drag widget) |
| `test/screens/home_screen_breathing_pulse_test.dart` | widget test | n/a | `test/screens/quarterly_review_test.dart:38-95` | role-match |
| `test/platform/window_setup_test.dart` | unit test | n/a | `test/services/notification_service_test.dart:6-39` (init that "completes without throwing" assertion) | exact (init smoke test) |
| `test/screens/router_redirect_test.dart` | widget test (routing) | n/a | (no existing router test — closest is `test/screens/quarterly_review_test.dart` for `MaterialApp` wrap pattern; consumer: `lib/router.dart:22-34` `createRouter(SettingsNotifier)`) | partial (uses createRouter factory) |

### Files to Modify

| Modified File | Role | Data Flow | Closest Analog (already itself) | Match Quality |
|---|---|---|---|---|
| `lib/main.dart` | app entry / Provider wiring | startup | `lib/main.dart:48-76` itself (existing `CanopyApp` + `MultiProvider` + `MaterialApp.router`) | self |
| `lib/router.dart` | router + shell scaffold | request-response | `lib/router.dart:117-143` itself (`_ScaffoldWithNavBar`) + `lib/screens/onboarding/onboarding_screen.dart:567-588` for `LayoutBuilder` | self + role-match |
| `lib/screens/schedule/widgets/chunk_card.dart` | card widget | hover reveal | `lib/screens/goals/widgets/goal_card.dart:51-138` (5dp bar + Stack + trailing slot — same structural pattern, has InkWell to model from) | role-match (sibling card) |
| `lib/screens/goals/widgets/goal_card.dart` | card widget | hover reveal | `lib/screens/goals/widgets/goal_card.dart:62-64` itself (existing InkWell — add `onHover` callback) | self |
| `lib/screens/commitments/commitments_screen.dart` | list row | hover reveal | `lib/screens/commitments/commitments_screen.dart:144-191` itself (existing InkWell-wrapped Card row with trailing IconButton — convert IconButton to hover-revealed AnimatedOpacity) | self |
| `lib/screens/home/home_screen.dart` | screen widget | animation | `lib/screens/home/home_screen.dart:167-210` itself (existing `_buildEmptyState` with `OutlinedButton`) + RESEARCH.md `_BreathingPulseButton` excerpt | self + research |
| `lib/screens/schedule/checkin_screen.dart` | screen widget | event-driven (mood tap) | `lib/screens/schedule/checkin_screen.dart:148-153` itself (existing `GestureDetector.onTap` writing `_selectedMood`) + `lib/screens/schedule/checkin_screen.dart:59-67` (`context.read<ScheduleNotifier>().generateToday(...)` — model for the new `context.read<ThemeNotifier>().setMoodSeed(...)` call) | self |
| `lib/screens/quarterly_review/quarterly_review_screen.dart` | screen widget | n/a (verify under pumpWithMood) | `test/screens/quarterly_review_test.dart` | self (verification only) |
| `pubspec.yaml` | config | n/a | `pubspec.yaml` itself (existing `flutter_local_notifications: ^19.3.0` line — same dependency-block pattern) | self |

---

## Pattern Assignments

### `lib/providers/theme_notifier.dart` (provider, event-driven + ticker)

**Analog:** `lib/providers/settings_notifier.dart` (lines 1-76)

**Imports pattern** (settings_notifier.dart:1-4):
```dart
import 'package:flutter/foundation.dart';
import '../data/models/app_settings.dart';
import '../data/repositories/app_settings_repository.dart';
import '../data/repositories/hive_app_settings_repository.dart';
```

**Repository injection + init** (settings_notifier.dart:6-34):
```dart
class SettingsNotifier extends ChangeNotifier {
  final AppSettingsRepository _repository = HiveAppSettingsRepository();

  bool _onboardingComplete = false;
  bool get onboardingComplete => _onboardingComplete;
  // ... other private fields with getters

  /// Reads persisted settings from Hive and caches the values.
  /// Call once at startup after HiveDatabase.init(), before runApp().
  Future<void> init() async {
    final settings = await _repository.getSettings();
    _onboardingComplete = settings?.onboardingComplete ?? false;
    // ... read other fields with ?? defaults
    notifyListeners();
  }
```

**Setter pattern** (settings_notifier.dart:37-43):
```dart
Future<void> setOnboardingComplete(bool value) async {
  _onboardingComplete = value;
  AppSettings settings = await _repository.getSettings() ?? AppSettings();
  settings.onboardingComplete = value;
  await _repository.saveSettings(settings);
  notifyListeners(); // triggers go_router redirect re-evaluation
}
```

**Hive schema-bump pattern** (apply when adding `moodSeedArgb:int?` to `AppSettings`):
- `lib/data/models/app_settings.dart` — add `@HiveField(5) int? moodSeedArgb;` (next free HiveField index after 0-4 in current file)
- `lib/data/database/migrations.dart:1-32`:
```dart
const int currentSchemaVersion = 2;  // bump to 3
final List<MigrationFn> _migrations = [
  _migration0to1,
  _migration1to2,
  // _migration2to3,                  // ADD
];

Future<void> _migration1to2() async {
  // Phase 2: Goal model expanded with nullable fields... 
  // No data transformation needed — Hive binary reader returns null for missing
  // nullable fields and 0 for missing int fields in existing records.
}
// ADD: _migration2to3 — same no-op shape since moodSeedArgb is a nullable additive field
```

**Conventions to preserve:**
- `extends ChangeNotifier` (not StateNotifier or any other lib)
- Private field with public getter for every state value
- Repository instantiated via direct `= HiveAppSettingsRepository()` (DI in constructor only when tests need it — research §Pattern 2 shows that exact constructor-injection pattern for tests)
- `init()` is `Future<void>` — called from `main.dart` **before `runApp`** and awaited (see `lib/main.dart:22-26`)
- Setters: write field, read+update Hive AppSettings record, `await repo.saveSettings()`, `notifyListeners()`
- No-op-migration pattern is the established way to bump Hive `schemaVersion` for additive fields

**ThemeNotifier-specific additions beyond the analog:**
- `with WidgetsBindingObserver` mixin (see RESEARCH.md §Pattern 2 — pause `Timer.periodic` on `AppLifecycleState.paused`, resume on `.resumed`)
- 20-min `Timer.periodic` that calls `notifyListeners()` (time-of-day modulation re-derives on each notify)
- Pure static helper `_modulateHsl(Color base, DateTime now)` using `HSLColor` (RESEARCH.md §Pattern 2 lines 353-360 has the exact 5-line cosine math)
- `curiousSeed = Color(0xFF7A8FA3)` and `moodSeeds` static const map (UI-SPEC locked hex values)
- `currentTheme` getter returning `ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: _effectiveSeed()))`
- `init()` adds the `WidgetsBinding.instance.addObserver(this)` line
- `dispose()` must `removeObserver` + `cancel` ticker (analog has no dispose because settings has no resources)

**Landmines:**
- Don't `Timer.periodic` without lifecycle pause — Pitfall 2 in RESEARCH.md (battery drain on mobile)
- Never persist the modulated seed — only persist user-tapped mood seed (RESEARCH.md anti-pattern)
- Mood reset at midnight: Open Question 1 in RESEARCH.md recommends putting the day-rollover check inside `ThemeNotifier` itself (compare persisted `lastMoodSetYmd` to today's local Ymd on `init()` + `.resumed`). **Surface to planner as a seam decision.**

---

### `lib/platform/window_setup.dart` (platform glue, conditional re-export)

**Analog:** No existing codebase analog — first use of `dart.library.io` conditional-import idiom. Closest related precedent: `lib/services/notification_service.dart:1-3` (which uses runtime `kIsWeb` checks instead — Phase 6 introduces compile-time gating for the first time).

**Body** (entire file — 2 lines):
```dart
export 'window_setup_stub.dart'
    if (dart.library.io) 'window_setup_io.dart';
```

**Conventions to preserve:**
- Stub file first in the `export` (default for non-`dart:io` targets — web)
- `_io.dart` suffix for the desktop/mobile real impl, `_stub.dart` for web no-op
- Both files must expose the **same top-level symbol name** so `main.dart` is identical across platforms

**Landmines:**
- The stub file MUST NOT import `package:window_manager/...` — that would defeat the conditional and break web builds
- The `if (dart.library.io)` key is the standard Dart idiom (RESEARCH.md Pattern 3 cited dart.dev + Flutter Community)

---

### `lib/platform/window_setup_io.dart` (platform glue, real impl)

**Analog:** `lib/services/notification_service.dart:1-46` (the kIsWeb early-return + Platform.is* gate before plugin init)

**Excerpt to copy** (notification_service.dart:1-46, condensed):
```dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
// ... plugin imports

class NotificationService {
  static Future<void> initialize() async {
    if (kIsWeb) return;
    // Configure timezone database.
    tz.initializeTimeZones();
    if (!Platform.isLinux && !Platform.isWindows) {
      try {
        final tzInfo = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
      } catch (_) { /* fallback */ }
    }
    // ... ensureInitialized() and platform-specific setup
  }
}
```

**ThemeNotifier-window_setup_io equivalent** (from RESEARCH.md Pattern 3):
```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Size;
import 'package:window_manager/window_manager.dart';

Future<void> setupDesktopWindow() async {
  if (kIsWeb) return;
  if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(const Size(480, 640));
}
```

**Conventions to preserve:**
- `kIsWeb` early-return BEFORE `Platform.is*` access (Platform.is* throws on Web — established pattern at notification_service.dart:34)
- `Platform.is*` runtime checks even inside the `_io` branch (because Android/iOS are also `dart:io` platforms but window_manager doesn't apply there)
- Top-level function (not a class method) — different from notification_service's static-method shape because window_setup has only one function and zero state
- `await windowManager.ensureInitialized()` before any other windowManager call — same shape as notification_service's `tz.initializeTimeZones()` setup

**Landmines:**
- macOS `MainFlutterWindow.swift` may need the snippet from window_manager's README — RESEARCH.md Pitfall 1 + Open Question 2. **Plan task: read `macos/Runner/MainFlutterWindow.swift` before installing.**

---

### `lib/platform/window_setup_stub.dart` (platform glue, web no-op)

**Analog:** `lib/services/notification_service.dart:34, 87, 129, 169, 175, 185` (the `if (kIsWeb) return;` no-op pattern)

**Body** (entire file — 3 lines):
```dart
Future<void> setupDesktopWindow() async {
  // No-op on web (no dart:io / window_manager available).
}
```

**Conventions to preserve:**
- Same function signature as `window_setup_io.dart` (so `main.dart` compiles identically)
- Zero imports of `dart:io` or `window_manager` (proven invariant for the conditional-export to work)

---

### `lib/widgets/responsive_shell.dart` (screen widget, layout)

**Analog:**
- `lib/screens/onboarding/onboarding_screen.dart:567-588` — the only existing `LayoutBuilder` in the codebase
- `lib/router.dart:117-143` — the `_ScaffoldWithNavBar` body that this widget wraps

**LayoutBuilder excerpt** (onboarding_screen.dart:567-588):
```dart
class _ScreenLayout extends StatelessWidget {
  const _ScreenLayout({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 32, // account for padding
            ),
            child: IntrinsicHeight(child: child),
          ),
        );
      },
    );
  }
}
```

**Existing `_ScaffoldWithNavBar`** to migrate (router.dart:117-143):
```dart
class _ScaffoldWithNavBar extends StatelessWidget {
  const _ScaffoldWithNavBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), label: 'Goals'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: 'Schedule'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
```

**Pattern to apply** (RESEARCH.md Pattern 4 — copy verbatim, adjust class name):
```dart
return LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth >= 720) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _goBranch,
            labelType: NavigationRailLabelType.all,
            destinations: [ /* same 4 destinations */ ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: navigationShell),
        ]),
      );
    }
    // Below 720dp: existing NavigationBar (unchanged from current router.dart:124-141)
    return Scaffold(/* current body */);
  },
);
```

**Conventions to preserve:**
- Reuse the existing 4 `(icon, label)` destination pairs verbatim — same `Icons.*_outlined` set (matches `lib/router.dart:135-138` and UI-SPEC §Design System icon library lock)
- `goBranch(index, initialLocation: index == navigationShell.currentIndex)` semantics preserved across both branches (existing router.dart:128-133)
- Material 3 defaults: `NavigationRail` default 80dp width, default selected indicator pill — do not override (UI-SPEC §Two-Column Adaptive Layout)

**Landmines:**
- The widget being public (`responsive_shell.dart`) but the existing `_ScaffoldWithNavBar` is private (`_` prefix). Phase 6 should either (a) make ResponsiveShell public for testability, or (b) keep `_ScaffoldWithNavBar` and inline LayoutBuilder. RESEARCH.md §Project Structure recommends a separate file — surface to planner.
- `StatefulNavigationShell` must be the same instance in both branches (preserves go_router state) — RESEARCH.md Pattern 4 explanation

---

### `lib/screens/schedule/widgets/chunk_card.dart` (card widget, hover reveal — MODIFY)

**Analog:** `lib/screens/goals/widgets/goal_card.dart:51-138` (sibling card with 5dp bar, Stack, trailing slot — has the structural patterns chunk_card already shares)

**Goal-card excerpt for InkWell structural pattern** (goal_card.dart:58-83):
```dart
return Card(
  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  clipBehavior: Clip.antiAlias,
  child: InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Stack(
      children: [
        // Colored left border — sized by Stack to match content height
        Positioned(
          left: 0, top: 0, bottom: 0, width: 5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: goalColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
        ),
```

**Chunk-card current `_buildWork`** (chunk_card.dart:91-185) — already has identical 5dp-bar + Stack + trailing-icon structure. The Phase 6 change is to **wrap the entire `_buildWork` return value in `MouseRegion`** and insert an `AnimatedOpacity` row of hover icons in the trailing slot.

**Hover-reveal pattern** (RESEARCH.md Code Examples §MouseRegion hover-reveal lines 820-863):
```dart
class _HoverableChunkCard extends StatefulWidget { /* ... */ }
class _HoverableChunkCardState extends State<_HoverableChunkCard> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(children: [
        /* existing chunk_card content */,
        Positioned(
          right: 0, top: 0, bottom: 0,
          child: AnimatedOpacity(
            opacity: _hovered ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                tooltip: 'Mark complete',
                onPressed: _hovered ? () => /* notifier.markComplete */ : null,
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_outlined),
                tooltip: 'Skip',
                onPressed: _hovered ? () => /* notifier.markSkipped */ : null,
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
```

**Conventions to preserve:**
- `hexToColor` helper stays at top of file (chunk_card.dart:5-7) — used by goal-card-color fallback. Note: this helper is **duplicated** in goal_card.dart:5-7 — Phase 6 may consolidate but is not required (CONTEXT.md lists "remove duplicate mood color map" as the consolidation target, not hexToColor).
- 5dp left bar (chunk_card.dart:105-119) — visual ID, do not change (UI-SPEC locked exception)
- `barColor` falls back to `theme.colorScheme.primary` when `goalColor == null` (chunk_card.dart:94-95) — this fallback now shifts with mood (intentional per UI-SPEC §Goal Per-Card Color)
- `Icons.check_circle` completion state with `Colors.green.shade600` stays (chunk_card.dart:171) — UI-SPEC §Contrast Floors locks this as intentionally outside mood scheme
- Tooltips: 'Mark complete', 'Skip' (UI-SPEC §Copywriting Contract)
- Animation: `Opacity 0→1`, `Duration: 120ms`, `Curve: Curves.easeOut` (UI-SPEC §Hover Reveals)

**Landmines:**
- `MouseRegion` MUST wrap the chunk card's content, not be wrapped by `Dismissible` — verified safe per RESEARCH.md Pitfall 5: `MouseRegion.onEnter`/`onExit` are pointer-only, never fire on touch, so the Dismissible's swipe gesture is unaffected
- Don't add `InkWell` to chunk_card to get onHover — would intercept Dismissible's drag gesture (RESEARCH.md anti-pattern, line 610). Use `MouseRegion` (UI-SPEC locked this choice)
- Verification test (RESEARCH.md Pitfall 5 + AC-2 row in §Validation): `tester.drag(find.byType(ChunkCard), const Offset(300, 0))` → assert hover icons stayed at opacity 0

---

### `lib/screens/goals/widgets/goal_card.dart` (card widget, hover reveal — MODIFY)

**Analog:** `lib/screens/goals/widgets/goal_card.dart:62-64` itself (existing `InkWell` — add `onHover` callback)

**Existing structure** (goal_card.dart:58-138):
```dart
child: InkWell(
  borderRadius: BorderRadius.circular(12),
  onTap: onTap,
  // NO onHover today — Phase 6 adds it
  child: Stack(children: [/* left bar + content + trailing slot */]),
),
```

**InkWell.onHover pattern** (UI-SPEC §Hover Reveals locked this):
```dart
// Convert StatelessWidget to StatefulWidget OR move InkWell into a small stateful child
child: InkWell(
  borderRadius: BorderRadius.circular(12),
  onTap: onTap,
  onHover: (hovered) => setState(() => _hovered = hovered),
  child: Stack(children: [
    /* existing content */,
    if (trailing == null) Positioned(
      right: 0, top: 0, bottom: 0,
      child: AnimatedOpacity(
        opacity: _hovered ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit goal',
            onPressed: _hovered ? widget.onEdit : null,
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Archive goal',
            onPressed: _hovered ? widget.onArchive : null,
          ),
        ]),
      ),
    ),
  ]),
),
```

**Conventions to preserve:**
- `goalColor` derivation (goal_card.dart:54-55) — `hexToColor(goal.color!)` when present, else `theme.colorScheme.primary` (now mood-derived)
- 5dp left bar at goal_card.dart:68-82 (UI-SPEC locked exception)
- Existing `trailing` parameter (goal_card.dart:20, 131) is used by GoalsScreen for the drag handle (goals_screen.dart:182-188). Hover-revealed edit/archive icons should appear **only when `trailing == null`** so drag-handle context still works — or refactor to a separate `trailing` vs `hoverActions` slot. Surface to planner.
- Tooltips: 'Edit goal', 'Archive goal' (UI-SPEC §Copywriting Contract)
- `defaultTargetPlatform` is NOT used to gate hover (UI-SPEC §Hover Reveals line: "Mobile (touchscreen): Hover callbacks do not fire on touch — these icons stay at opacity 0 on mobile, which preserves the swipe-to-complete / swipe-to-skip Phase 4 affordance"). Pointer presence is the gate.

**Drag handle always-on at 0.6 opacity desktop / hidden mobile** (RESEARCH.md Code Examples lines 866-897 — needs `defaultTargetPlatform` here, unlike hover icons):
```dart
final isMobileTouch = defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;
// ... in ReorderableListView.builder.itemBuilder, replace existing trailing:
trailing: isMobileTouch
    ? const SizedBox.shrink()
    : ReorderableDelayedDragStartListener(
        index: i,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: 0.6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.drag_handle, color: theme.colorScheme.outline),
          ),
        ),
      ),
```

**Landmines:**
- Goal-card has both `onTap` and `onHover` semantics — InkWell handles both natively (UI-SPEC explicitly chose this over MouseRegion to "avoid two overlapping hover detectors")
- The drag handle change is in `lib/screens/goals/goals_screen.dart:178-188` (where `GoalCard.trailing:` is built), NOT inside `goal_card.dart` itself

---

### `lib/screens/commitments/commitments_screen.dart` (list row, hover reveal — MODIFY)

**Analog:** `lib/screens/commitments/commitments_screen.dart:144-191` itself (existing list row already has Card+InkWell+trailing IconButton)

**Existing row structure** (commitments_screen.dart:144-191):
```dart
return Card(
  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  child: InkWell(
    onTap: () => _openAddSheet(context, block),
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(/* color swatch */),
          const SizedBox(width: 12),
          Expanded(child: Column(/* name + subtitle */)),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, block),
          ),
        ],
      ),
    ),
  ),
);
```

**Phase 6 change:** Add `onHover` to the existing InkWell. Wrap the trailing IconButton(s) in `AnimatedOpacity`. Add an edit icon next to delete.

**Conventions to preserve:**
- `_confirmDelete` already exists (commitments_screen.dart:44-65) — reuse for delete tooltip click
- `_openAddSheet(context, block)` already opens the edit sheet (commitments_screen.dart:24-42) — reuse for edit tooltip click
- Tooltips: 'Edit commitment', 'Delete commitment' (UI-SPEC §Copywriting Contract)
- Material 3 default elevation `1 → 2` on hover handled automatically (UI-SPEC §Hover Reveals)
- Existing delete confirmation dialog copy is locked (commitments_screen.dart:46-60) — UI-SPEC §Copywriting Contract reuses it

**Landmines:**
- The existing always-on delete IconButton becomes hover-only on desktop, but mobile still needs reach to delete. Since pointer-driven `onHover` keeps icons at opacity 0 on touch, **mobile users lose access to delete unless** the existing behaviour is preserved differently. UI-SPEC §Hover Reveals says "Wrap if not already" — implies the icons fade. Plan needs to decide: (a) keep delete IconButton always-visible on mobile (use `defaultTargetPlatform` gate at row level), or (b) make delete reachable via a different gesture on mobile (long-press → menu). **Surface to planner.**

---

### `lib/screens/home/home_screen.dart` (screen widget, animation — MODIFY)

**Analog:** `lib/screens/home/home_screen.dart:167-210` itself (existing `_buildEmptyState` with `OutlinedButton`)

**Existing CTA** (home_screen.dart:198-201):
```dart
OutlinedButton(
  onPressed: () => context.push('/schedule/checkin'),
  child: const Text('Start your day'),
),
```

**Breathing pulse wrapper** (RESEARCH.md Code Examples lines 754-817 — `_BreathingPulseButton`):
```dart
class _BreathingPulseButton extends StatefulWidget {
  const _BreathingPulseButton({required this.onPressed, required this.child});
  final VoidCallback onPressed;
  final Widget child;
  @override
  State<_BreathingPulseButton> createState() => _BreathingPulseButtonState();
}

class _BreathingPulseButtonState extends State<_BreathingPulseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    final disableAnimations = WidgetsBinding.instance.platformDispatcher
        .accessibilityFeatures.disableAnimations;
    if (!disableAnimations) _controller.repeat(reverse: true);
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      builder: (context, child) {
        final t = _controller.value;
        final blur = 8.0 + 8.0 * t; // 8 -> 16
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(
              color: primary.withValues(alpha: 0.25),
              blurRadius: blur,
              spreadRadius: 1,
            )],
          ),
          child: child,
        );
      },
      child: OutlinedButton(onPressed: widget.onPressed, child: widget.child),
    );
  }
}
```

**Conventions to preserve:**
- `static const Map<int, Color> _moodColors` at home_screen.dart:21-27 is **duplicate** of the same map in `checkin_screen.dart:19-25` — both become dead code once ThemeNotifier owns the palette. CONTEXT.md `<deferred>` action: remove duplicates after wiring. Keep `_moodEmojis` (home_screen.dart:29-35) and `_moodDescriptions` (home_screen.dart:37-43) — those are UI strings, not colors.
- `.withValues(alpha: 0.25)` (not deprecated `.withOpacity(0.25)`) — RESEARCH.md State of the Art §Deprecated section
- `WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations` — respects reduced-motion (UI-SPEC §Breathing Pulse "Reduced motion")
- Existing CTA text: 'Start your day' (UI-SPEC §Copywriting Contract)
- The pulse exists **only** in `_buildEmptyState` (when no schedule today → no mood set) — UI-SPEC: "Pulse stops the moment mood is tapped"
- `context.watch<ThemeNotifier>()` (new) reads `isPreCheckin` to drive the pulse on/off — see RESEARCH.md Pattern 2 `bool get isPreCheckin`

**Landmines:**
- `AnimationController` must be disposed (memory leak if not) — see `dispose()` in the analog
- Controller must NOT `.repeat()` when `disableAnimations` is true — UI-SPEC requires the static midpoint render (shadow blur = 12px), not a paused animation
- Pulse color uses `Theme.of(context).colorScheme.primary` — during pre-check-in this is the curious seed (`#7A8FA3`)-derived primary. The `withValues(alpha: 0.25)` value is locked per UI-SPEC

---

### `lib/screens/schedule/checkin_screen.dart` (screen widget, event-driven — MODIFY)

**Analog:** `lib/screens/schedule/checkin_screen.dart:59-67` itself (existing `_generate()` calling `context.read<ScheduleNotifier>().generateToday(...)`)

**Existing mood-tap handler** (checkin_screen.dart:148-153):
```dart
GestureDetector(
  onTap: () {
    setState(() {
      _selectedMood = mood;
    });
  },
  child: AnimatedContainer(/* ... */),
);
```

**Existing context.read pattern** (checkin_screen.dart:59-67):
```dart
await context.read<ScheduleNotifier>().generateToday(
      moodIndex: _selectedMood!,
      goals: context.read<GoalsNotifier>().goals,
      blocks: context.read<CommitmentsNotifier>().blocks,
    );
```

**Phase 6 change** — On mood tap, call `setMoodSeed`:
```dart
onTap: () {
  setState(() => _selectedMood = mood);
  // Phase 6: warm the app theme into this mood's palette via AnimatedTheme.
  final seed = ThemeNotifier.moodSeeds[mood]!;     // mood-seed map lives in ThemeNotifier
  context.read<ThemeNotifier>().setMoodSeed(seed);
},
```

**Conventions to preserve:**
- The existing `context.read<ScheduleNotifier>().generateToday(...)` write in `_generate()` (checkin_screen.dart:59-64) STAYS — `setMoodSeed` is an ADDITIONAL call on tap, not a replacement
- `static const Map<int, Color> _moodColors` at checkin_screen.dart:19-25 is the **duplicate** of home_screen.dart:21-27. Phase 6 removes both (call sites move to `ThemeNotifier.moodSeeds`). The `_moodEmojis` and `_moodPrefix` maps in checkin_screen stay (UI strings)
- `Colors.white` foreground when mood selected (checkin_screen.dart:160-162, 204) — locked Phase 3, do not change
- `NotificationService.requestIOSPermissions()` after first successful check-in (checkin_screen.dart:67) — Phase 4 contract, keep unchanged

**Landmines:**
- `setMoodSeed` triggers `notifyListeners()` → `MaterialApp.router` rebuild → `themeAnimationDuration: 500ms easeOutCubic` cross-fades the theme. The existing `AnimatedSwitcher(duration: 300ms, ...)` inside checkin_screen (checkin_screen.dart:116-117) is a SEPARATE animation for the body content swap — both run independently, no conflict expected
- `ThemeNotifier.moodSeeds` is a `static const Map` — referenced from checkin_screen via `ThemeNotifier.moodSeeds[mood]!`. This is the single source of truth for mood→seed mapping (replacing home_screen `_moodColors` and checkin_screen `_moodColors`)

---

### `lib/main.dart` (app entry / Provider wiring — MODIFY)

**Analog:** `lib/main.dart:48-76` itself (existing `CanopyApp` + `MultiProvider` + `MaterialApp.router`)

**Existing structure** (main.dart:14-46):
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await HiveDatabase.init(prefs);
  // SettingsNotifier is constructed before runApp so init() can load persisted
  // values. The same instance is passed to createRouter and registered via
  // ChangeNotifierProvider.value so no double-construction occurs.
  final settingsNotifier = SettingsNotifier();
  await settingsNotifier.init();
  final scheduleNotifier = ScheduleNotifier();
  await scheduleNotifier.init();
  await NotificationService.initialize();
  // ... callback wiring
  runApp(CanopyApp(settingsNotifier: settingsNotifier, scheduleNotifier: scheduleNotifier));
}
```

**Existing MultiProvider** (main.dart:56-65):
```dart
return MultiProvider(
  providers: [
    ChangeNotifierProvider<GoalsNotifier>(create: (_) => GoalsNotifier()),
    ChangeNotifierProvider<CommitmentsNotifier>(create: (_) => CommitmentsNotifier()),
    ChangeNotifierProvider<ScheduleNotifier>.value(value: scheduleNotifier),
    ChangeNotifierProvider<SettingsNotifier>.value(value: settingsNotifier),
  ],
  child: MaterialApp.router(/* ... */),
);
```

**Phase 6 changes** (RESEARCH.md Pattern 1 — apply verbatim):
```dart
// In main(): add ThemeNotifier construction + window setup BEFORE runApp
import 'platform/window_setup.dart';
import 'providers/theme_notifier.dart';
// ...
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDesktopWindow();                          // NEW — safe on every platform
  final prefs = await SharedPreferences.getInstance();
  await HiveDatabase.init(prefs);
  final settingsNotifier = SettingsNotifier();
  await settingsNotifier.init();
  final scheduleNotifier = ScheduleNotifier();
  await scheduleNotifier.init();
  final themeNotifier = ThemeNotifier();               // NEW
  await themeNotifier.init();                          // NEW
  await NotificationService.initialize();
  // ... callback wiring
  runApp(CanopyApp(
    settingsNotifier: settingsNotifier,
    scheduleNotifier: scheduleNotifier,
    themeNotifier: themeNotifier,                      // NEW
  ));
}

// In CanopyApp.build:
return MultiProvider(
  providers: [
    // ... existing providers
    ChangeNotifierProvider<ThemeNotifier>.value(value: themeNotifier),   // NEW
  ],
  child: Consumer<ThemeNotifier>(                       // NEW — narrows rebuild scope
    builder: (context, theme, _) => MaterialApp.router(
      title: 'Canopy',
      theme: theme.currentTheme,                        // CHANGED — was ColorScheme.fromSeed(Color(0xFF3D6B4F))
      themeAnimationDuration: const Duration(milliseconds: 500),     // NEW
      themeAnimationCurve: Curves.easeOutCubic,                       // NEW
      routerConfig: createRouter(settingsNotifier),
    ),
  ),
);
```

**Conventions to preserve:**
- `WidgetsFlutterBinding.ensureInitialized()` is the FIRST line of `main()` — never move it (notification_service.dart and now window_manager both require it before plugin init)
- `setupDesktopWindow()` is called AFTER `ensureInitialized()`, BEFORE `runApp` (RESEARCH.md Pattern 3 — matches the existing `await NotificationService.initialize();` placement at main.dart:30)
- `ChangeNotifierProvider<X>.value` (not `create:`) for notifiers constructed in `main()` — existing pattern at main.dart:63-64 lets `await init()` happen pre-runApp
- `useMaterial3: true` is in `theme` (currently main.dart:70) — preserved when `theme: themeNotifier.currentTheme` because `ThemeNotifier.currentTheme` itself sets `useMaterial3: true` (RESEARCH.md Pattern 2 line 323)

**Landmines:**
- Don't wrap `MaterialApp.router` in `AnimatedTheme` — RESEARCH.md anti-pattern lines 604-606. Use `themeAnimationDuration` + `themeAnimationCurve` on MaterialApp itself (Flutter 3.19+ API, available)
- `Consumer<ThemeNotifier>` is around `MaterialApp.router`, not around the whole `MultiProvider` — research lines 262-275 show the correct nesting

---

### `lib/router.dart` (router + shell scaffold — MODIFY)

**Analog:** `lib/router.dart:117-143` itself (`_ScaffoldWithNavBar`) — Phase 6 wraps this body in the LayoutBuilder from `lib/widgets/responsive_shell.dart`

**Phase 6 change:**
- Either (a) keep `_ScaffoldWithNavBar` private and inline the LayoutBuilder, OR (b) replace `_ScaffoldWithNavBar` body with `return ResponsiveShell(navigationShell: navigationShell);`
- The shell builder (router.dart:37-39) is unchanged: `(context, state, navigationShell) => _ScaffoldWithNavBar(navigationShell: navigationShell)`
- All 4 branches inherit the adaptive layout automatically (because `navigationShell` is reused per RESEARCH.md Pattern 4)

**Conventions to preserve:**
- `StatefulShellRoute.indexedStack` (router.dart:36) — keep
- Route table (router.dart:35-113) — UNCHANGED. AC-4 requires only that Web URLs already work (which they do — see RESEARCH.md AC-4 row: route table is complete)
- `refreshListenable: settingsNotifier` (router.dart:26) — keep (drives onboarding redirect)
- `redirect:` logic (router.dart:27-34) — keep

**Landmines:**
- The `_ScaffoldWithNavBar` underscore-prefixed name makes it untestable from outside the file. Plan must decide: rename to `ResponsiveShell` (public) and move to `lib/widgets/responsive_shell.dart`, OR add a `@visibleForTesting` test harness. RESEARCH.md §Project Structure recommends the public widget approach

---

### `lib/screens/quarterly_review/quarterly_review_screen.dart` (verify under pumpWithMood — VERIFY)

**Analog:** `test/screens/quarterly_review_test.dart` (existing tests using `_wrap`)

**Phase 6 task:** No source change. Test file gets migrated to `pumpWithMood`. Verify QuarterlyReviewScreen color assertions still pass under mood-3 theme.

**Existing `_wrap` to migrate** (quarterly_review_test.dart:31):
```dart
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));
```

**Replace with** (RESEARCH.md Pattern 5):
```dart
import '../test_helpers/mood_pump.dart';
// ... in each testWidgets:
await pumpWithMood(tester, /* the widget */);
```

**Conventions to preserve:**
- The existing tests have **no `colorScheme.primary` assertions** [VERIFIED: RESEARCH.md AC-5 row]. Migration is mechanical
- `ChangeNotifierProvider<GoalsNotifier>` wrap pattern at quarterly_review_test.dart:215-219 — extend pumpWithMood to accept extraProviders (RESEARCH.md Pattern 5 line 537 has this knob)

---

### `pubspec.yaml` (config — MODIFY)

**Analog:** Existing dependency block (each dependency line has the same shape: `package_name: ^version`)

**Add:**
```yaml
dependencies:
  # ... existing
  window_manager: ^0.5.1
```

**Conventions to preserve:**
- Caret syntax `^0.5.1` (RESEARCH.md Standard Stack)
- After edit: run `flutter pub get` (regenerates pubspec.lock + macOS Podfile.lock + Windows/Linux CMake plugin registrations per RESEARCH.md Runtime State Inventory)

---

## Test File Patterns

### `test/test_helpers/mood_pump.dart` (NEW)

**Analog:** `test/screens/quarterly_review_test.dart:31` (the `_wrap` helper this consolidates)

**Body** (RESEARCH.md Pattern 5 lines 522-553):
```dart
import 'package:canopy/providers/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<void> pumpWithMood(
  WidgetTester tester,
  Widget child, {
  int moodIndex = 3,           // mood 3 = #4A8C7A
  Iterable<ChangeNotifierProvider> extraProviders = const [],
}) async {
  final seed = ThemeNotifier.moodSeeds[moodIndex]!;
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: seed),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [...extraProviders],
      child: MaterialApp(theme: theme, home: Scaffold(body: child)),
    ),
  );
}
```

**Conventions to preserve:**
- Default `moodIndex: 3` (UI-SPEC locked — median weather, balanced contrast)
- `useMaterial3: true` — preserves project-wide theme setting
- Disable time-of-day modulation by reading `ThemeNotifier.moodSeeds[3]!` directly (no ticker, no `DateTime.now()` in the test path)
- Tests that need a real `ThemeNotifier` (e.g. `theme_notifier_test.dart`) construct it directly with `timeModulationEnabled: false` — not via this helper

---

### `test/test_helpers/viewport.dart` (NEW)

**Analog:** No existing usage of `tester.view.physicalSize` in the codebase. Pattern source: RESEARCH.md Pattern 6 lines 572-579.

**Body**:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Set the test viewport to [size] (logical pixels, DPR=1.0).
/// Pairs with addTearDown(tester.view.reset) — REQUIRED to prevent leakage
/// between tests (RESEARCH.md Pitfall 4).
void setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}
```

**Conventions to preserve:**
- `devicePixelRatio = 1.0` so `physicalSize` == logical pixels (matches `LayoutBuilder.constraints.maxWidth` semantics)
- `addTearDown(tester.view.reset)` — RESEARCH.md Pitfall 4 lock-in (test order flakiness)

---

### `test/providers/theme_notifier_test.dart` (NEW)

**Analog:** `test/repositories/goal_repository_test.dart:1-50` (in-memory fake + `setUp` + plain unit `test()` blocks)

**Repository-fake pattern** (goal_repository_test.dart:6-24):
```dart
class InMemoryGoalRepository implements GoalRepository {
  final Map<String, Goal> _store = {};
  @override
  Future<List<Goal>> getAll() async => _store.values.toList();
  // ...
}
void main() {
  late GoalRepository repo;
  setUp(() { repo = InMemoryGoalRepository(); });
  test('save and getById round-trip', () async { /* ... */ });
}
```

**ThemeNotifier tests to write** (RESEARCH.md §Validation, AC-6 rows):
- `_modulateHsl` peaks at noon (DateTime(2026, 5, 12, 12, 0)) — RESEARCH.md Code Examples lines 735-742
- `_modulateHsl` troughs at midnight — lines 744-751
- `setMoodSeed` triggers `notifyListeners`
- `didChangeAppLifecycleState(AppLifecycleState.paused)` cancels ticker; `.resumed` restarts + calls notifyListeners (research line 372-378)
- `isPreCheckin` true when `_moodSeed == null` (curious seed in use)

**Conventions to preserve:**
- Inject an `InMemoryAppSettingsRepository` (sibling of `InMemoryGoalRepository` from goal_repository_test.dart) — ThemeNotifier should accept `AppSettingsRepository? repository` via constructor (RESEARCH.md Pattern 2 line 292) for this exact reason
- Inject `DateTime Function() now` for deterministic time (RESEARCH.md Pattern 2 line 293)
- Pass `timeModulationEnabled: false` for tests that don't exercise the modulator

---

### `test/screens/responsive_layout_test.dart` (NEW)

**Analog:** RESEARCH.md Pattern 6 lines 562-598 (full verbatim test sketch)

**Body sketch** (already in RESEARCH.md — copy as-is, fill in the harness widget):
```dart
testWidgets('shows NavigationBar at 480dp', (tester) async {
  setViewport(tester, const Size(480, 800));
  await pumpWithMood(tester, /* ResponsiveShell test harness */);
  await tester.pumpAndSettle();
  expect(find.byType(NavigationBar), findsOneWidget);
  expect(find.byType(NavigationRail), findsNothing);
});
testWidgets('switches to NavigationRail at 720dp', (tester) async { /* ... */ });
testWidgets('shows NavigationRail at 1200dp', (tester) async { /* ... */ });
```

**Conventions to preserve:**
- 720 is the **inclusive** lower bound (UI-SPEC + RESEARCH.md note line 601)
- Test the harness widget needs a `StatefulNavigationShell` — easiest path is to construct via the actual go_router (`createRouter`) inside a `Builder`, OR build a minimal `MaterialApp(home: ResponsiveShell(...))` if ResponsiveShell accepts a `Widget child` instead of a shell
- The harness decision belongs to the planner

---

### `test/screens/chunk_card_hover_test.dart` + `test/screens/goal_card_hover_test.dart` (NEW)

**Analog:** `test/screens/quarterly_review_test.dart:38-95` (testWidgets pattern)

**Tests to write** (RESEARCH.md AC-2 rows):
```dart
testWidgets('MouseRegion.onEnter reveals checkbox + skip', (tester) async {
  await pumpWithMood(tester, /* ChunkCard work variant */);
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(find.byType(ChunkCard)));
  await tester.pumpAndSettle();
  expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  expect(find.byIcon(Icons.skip_next_outlined), findsOneWidget);
});

testWidgets('touch drag completes Dismissible without revealing hover icons', (tester) async {
  await pumpWithMood(tester, /* SwipeableChunkCard */);
  await tester.drag(find.byType(ChunkCard), const Offset(300, 0));
  await tester.pumpAndSettle();
  // hover icons should never have appeared (touch ≠ pointer-enter)
  expect(find.byIcon(Icons.check_circle_outline), findsNothing);
});
```

**Conventions to preserve:**
- `pumpWithMood` for the wrap
- `tester.createGesture(kind: PointerDeviceKind.mouse)` is the canonical way to simulate hover in `flutter_test` — pair with `addTearDown(gesture.removePointer)` (UI-SPEC AC-2 implicit)
- Test both the reveal (onEnter → opacity 1) and the hide (onExit → opacity 0)

---

### `test/screens/goal_card_drag_handle_test.dart` (NEW)

**Analog:** `test/screens/quarterly_review_test.dart:171-207` (GoalAdjustmentTile in ReorderableListView)

**Existing pattern excerpt** (quarterly_review_test.dart:171-207):
```dart
group('GoalAdjustmentTile', () {
  final goal = _stubGoal(id: 'g1', name: 'Exercise', color: '#4CAF50');
  testWidgets('renders goal name', (tester) async {
    await tester.pumpWidget(_wrap(ReorderableListView(
      onReorder: (oldIdx, newIdx) {},
      children: [
        GoalAdjustmentTile(
          key: const ValueKey('g1'),
          goal: goal,
          goalColor: const Color(0xFF4CAF50),
          index: 0,
        ),
      ],
    )));
    expect(find.text('Exercise'), findsOneWidget);
  });
});
```

**Phase 6 tests** (RESEARCH.md AC drag handle visibility rows):
```dart
testWidgets('drag handle hidden on android (mobile touch)', (tester) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  await pumpWithMood(tester, /* GoalCard with reorderable */);
  expect(find.byIcon(Icons.drag_handle), findsNothing);
});

testWidgets('drag handle visible at 0.6 opacity on macOS (desktop)', (tester) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  await pumpWithMood(tester, /* GoalCard with reorderable */);
  expect(find.byIcon(Icons.drag_handle), findsOneWidget);
  final opacityWidget = tester.widget<AnimatedOpacity>(
    find.ancestor(of: find.byIcon(Icons.drag_handle), matching: find.byType(AnimatedOpacity)).first,
  );
  expect(opacityWidget.opacity, 0.6);
});
```

**Conventions to preserve:**
- `debugDefaultTargetPlatformOverride` + `addTearDown(() => ... = null)` — RESEARCH.md AC drag-handle row
- `ValueKey('id')` on each item — required by ReorderableListView (analog quarterly_review_test.dart:179)

---

### `test/screens/home_screen_breathing_pulse_test.dart` (NEW)

**Analog:** `test/screens/quarterly_review_test.dart:38-95` (testWidgets pattern) + RESEARCH.md AC pulse rows

**Tests to write** (RESEARCH.md §Validation breathing-pulse rows):
- Pulse animates when no mood set (verify `AnimationController.isAnimating == true`)
- Pulse stops when mood is set (mock ThemeNotifier with `isPreCheckin == false`)
- Pulse respects `MediaQuery.disableAnimations` — wrap with `MediaQuery(data: MediaQueryData(disableAnimations: true), ...)`

**Conventions to preserve:**
- Use `pumpWithMood` extended with `ChangeNotifierProvider<ThemeNotifier>` (extraProviders knob from Pattern 5)
- Animation assertions check `BoxShadow.blurRadius` ranges (8.0–16.0 per UI-SPEC)

---

### `test/platform/window_setup_test.dart` (NEW)

**Analog:** `test/services/notification_service_test.dart:10-39` (init that "completes without throwing")

**Pattern excerpt** (notification_service_test.dart:6-39):
```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('NotificationService.initialize', () {
    test('does not throw the macOS-settings ArgumentError on the test host', () async {
      try {
        await NotificationService.initialize();
      } catch (e) {
        expect(e, isNot(isA<ArgumentError>().having(/* ... */)));
      }
    });
  });
}
```

**Phase 6 test:**
```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('setupDesktopWindow', () {
    test('completes without throwing on the test host', () async {
      await expectLater(setupDesktopWindow(), completes);
    });
    // On non-dart:io targets (web), the export resolves to the stub which is
    // tautologically a no-op. The completes assertion is the cheapest correctness
    // signal — RESEARCH.md AC-3 line "Conditional import compiles on web"
  });
}
```

**Conventions to preserve:**
- `TestWidgetsFlutterBinding.ensureInitialized()` at top of `main()` — required for plugin platform channels (notification_service_test.dart:8)
- `expectLater(future, completes)` — same shape as notification_service_test.dart:46-49

---

### `test/screens/router_redirect_test.dart` (NEW)

**Analog:** No existing router test. Closest: `test/screens/quarterly_review_test.dart` for `MaterialApp` wrap; consumer: `lib/router.dart:22-34` `createRouter(SettingsNotifier)` factory.

**Pattern to apply:**
```dart
testWidgets('direct URL /schedule loads ScheduleScreen on Web URL load', (tester) async {
  final settings = SettingsNotifier();
  // ... set onboardingComplete = true via a fake
  await tester.pumpWidget(
    MaterialApp.router(
      theme: /* mood-3 theme from pumpWithMood internals */,
      routerConfig: createRouter(settings)..go('/schedule'),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(ScheduleScreen), findsOneWidget);
});
```

**Conventions to preserve:**
- `createRouter` is already a factory accepting `SettingsNotifier` (router.dart:22) — testable as-is
- `pumpWithMood` doesn't fit here (need full MaterialApp.router, not just MaterialApp(home:)) — write the wrap inline OR extend pumpWithMood with a `routerConfig` option

**Landmines:**
- The router's `redirect:` (router.dart:27-34) depends on `settingsNotifier.onboardingComplete`. Tests must seed this correctly before invoking the route — use an in-memory `AppSettingsRepository` fake (sibling of `InMemoryGoalRepository`)

---

## Shared Patterns

### Pattern A: Hive-Backed ChangeNotifier
**Source:** `lib/providers/settings_notifier.dart` (entire file)
**Apply to:** `lib/providers/theme_notifier.dart`

Excerpt — the init/get/set triangle:
```dart
final AppSettingsRepository _repository = HiveAppSettingsRepository();
Future<void> init() async {
  final settings = await _repository.getSettings();
  _field = settings?.field ?? defaultValue;
  notifyListeners();
}
Future<void> setField(T value) async {
  _field = value;
  final s = await _repository.getSettings() ?? AppSettings();
  s.field = value;
  await _repository.saveSettings(s);
  notifyListeners();
}
```

### Pattern B: kIsWeb + Platform.is* Gating
**Source:** `lib/services/notification_service.dart:34, 38` (and 5 other call sites in the file)
**Apply to:** `lib/platform/window_setup_io.dart`

Excerpt:
```dart
if (kIsWeb) return;
if (!Platform.isLinux && !Platform.isWindows) {
  /* macOS / iOS / Android branch */
}
```

Phase 6 application:
```dart
if (kIsWeb) return;
if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
await windowManager.ensureInitialized();
```

### Pattern C: 5dp Left Color Bar Card
**Source:** `lib/screens/goals/widgets/goal_card.dart:65-82` and `lib/screens/schedule/widgets/chunk_card.dart:102-119`
**Apply to:** No new files — both existing card files already use this pattern; preserve verbatim through Phase 6 edits.

Excerpt:
```dart
Stack(children: [
  Positioned(
    left: 0, top: 0, bottom: 0, width: 5,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: goalColor,                          // hex from goal.color OR theme.colorScheme.primary
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
      ),
    ),
  ),
  Padding(padding: const EdgeInsets.only(left: 5), child: /* content */),
])
```

UI-SPEC §Color §Goal Per-Card Color locks the `goalColor` fallback to `theme.colorScheme.primary` (now mood-derived). Do not change.

### Pattern D: `hexToColor` Helper
**Source:** `lib/screens/schedule/widgets/chunk_card.dart:5-7` AND `lib/screens/goals/widgets/goal_card.dart:5-7` (duplicate)
**Apply to:** Both files preserve their copy. **Optionally** the planner can consolidate into `lib/utils/hex_color.dart` — not required by Phase 6 acceptance criteria.

Excerpt:
```dart
Color hexToColor(String hex) {
  return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
}
```

### Pattern E: `pumpWithMood` Test Migration
**Source:** RESEARCH.md Pattern 5 + `test/screens/quarterly_review_test.dart:31`
**Apply to:** All NEW widget tests + `test/screens/quarterly_review_test.dart` migration.

Convention: existing `Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));` calls in `quarterly_review_test.dart` (33 call sites) become `await pumpWithMood(tester, child);`. Mechanical migration — no `colorScheme.primary` assertions exist so behaviour is identical [VERIFIED: RESEARCH.md AC-5 row].

### Pattern F: `withValues(alpha: ...)` Over `withOpacity`
**Source:** `lib/screens/schedule/widgets/chunk_card.dart:51` and `lib/screens/schedule/checkin_screen.dart:282` (existing usages)
**Apply to:** All new color-alpha usages (breathing pulse `boxShadow.color`, hover icon group, etc.)

Excerpt:
```dart
color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
```

### Pattern G: AppSettings Hive Schema Bump
**Source:** `lib/data/database/migrations.dart:18-24` (`_migration1to2` — additive nullable fields, no-op transformation)
**Apply to:** Adding `moodSeedArgb:int?` to AppSettings

Excerpt:
```dart
Future<void> _migration1to2() async {
  // Phase 2: Goal model expanded with nullable fields ...
  // No data transformation needed — Hive binary reader returns null for missing
  // nullable fields and 0 for missing int fields in existing records.
}
```

Phase 6 adds `_migration2to3()` with the same no-op body + comment, bumps `currentSchemaVersion` to 3, registers in `_migrations` list.

---

## Cross-Cutting Landmines

| Landmine | Files | Mitigation Source |
|---|---|---|
| `Dismissible` + `MouseRegion`: any gesture conflict? | `lib/screens/schedule/widgets/chunk_card.dart`, `lib/screens/schedule/widgets/swipeable_chunk_card.dart` | RESEARCH.md Pitfall 5: MouseRegion pointer-only, doesn't fire on touch — verified safe. Belt-and-suspenders test in `test/screens/chunk_card_hover_test.dart` |
| `Timer.periodic` battery drain on mobile when backgrounded | `lib/providers/theme_notifier.dart` | RESEARCH.md Pitfall 2: pair with `WidgetsBindingObserver`, cancel on `.paused`, restart on `.resumed` |
| `tester.view.physicalSize` leaks between tests | All new widget tests using `setViewport` | RESEARCH.md Pitfall 4: always `addTearDown(tester.view.reset)` — encapsulated in `test/test_helpers/viewport.dart` |
| macOS `MainFlutterWindow.swift` incompatibility with `window_manager` | `macos/Runner/MainFlutterWindow.swift` | RESEARCH.md Pitfall 1 + Open Question 2: read the file before `flutter pub get`; apply window_manager README snippet if needed. Plan task 0 of window_manager work |
| Mood seed not reset at daily rollover | `lib/providers/theme_notifier.dart` (or `ScheduleNotifier.generateToday`) | RESEARCH.md Pitfall 6 + Open Question 1: persist `lastMoodSetYmd`; on `init()` and `.resumed` compare to today's local Ymd; if different, set `_moodSeed = null`. **Planner decides the seam** — RESEARCH.md recommends inside ThemeNotifier |
| Duplicate `_moodColors` constant maps in `home_screen.dart:21-27` and `checkin_screen.dart:19-25` | Both screens | CONTEXT.md `<deferred>` note + RESEARCH.md Summary line: become dead code after `ThemeNotifier.moodSeeds` (static const) consolidates. Both call sites switch to `ThemeNotifier.moodSeeds[i]!` |
| Hover-revealed icons on mobile = inaccessible delete on commitments | `lib/screens/commitments/commitments_screen.dart` | UI-SPEC §Hover Reveals: pointer-driven means mobile sees opacity 0. Plan must keep mobile-reachable delete affordance (existing always-on IconButton or new long-press menu) |
| `_ScaffoldWithNavBar` is private — untestable | `lib/router.dart:117` | Move to public `lib/widgets/responsive_shell.dart` OR add `@visibleForTesting` factory. RESEARCH.md project structure recommends the public widget file |

---

## No Analog Found

| File | Role | Reason |
|---|---|---|
| `lib/platform/window_setup.dart` | conditional re-export | First use of `dart.library.io` conditional-import idiom in this codebase. Pattern is a standard 2-line Dart idiom (RESEARCH.md Pattern 3 cited) |
| `lib/platform/window_setup_stub.dart` | web no-op | First "stub" pair-file in the codebase. 3-line file — pattern is the absence-of-imports plus matching signature |
| `test/test_helpers/viewport.dart` | test viewport helper | First use of `tester.view.physicalSize` in the codebase. Pattern from flutter_test API docs (RESEARCH.md Pattern 6) |

These three files have no existing codebase analog because Phase 6 is the first to need conditional imports + viewport-driven widget tests. The planner should reference RESEARCH.md Patterns 3 and 6 directly for implementation.

---

## Metadata

**Analog search scope:** `lib/**/*.dart`, `test/**/*.dart`, `.planning/phases/06-desktop-and-web-polish/06-*.md`
**Files scanned (Read):** 17 (main.dart, router.dart, settings_notifier.dart, schedule_notifier.dart, notification_service.dart, export_service.dart, home_screen.dart, checkin_screen.dart, chunk_card.dart, goal_card.dart, swipeable_chunk_card.dart, commitments_screen.dart, onboarding_screen.dart §LayoutBuilder, goals_screen.dart §ReorderableListView, adjustments_section.dart §ReorderableListView, quarterly_review_test.dart, notification_service_test.dart, goal_repository_test.dart, app_settings.dart, migrations.dart, hive_app_settings_repository.dart)
**Pattern extraction date:** 2026-05-12

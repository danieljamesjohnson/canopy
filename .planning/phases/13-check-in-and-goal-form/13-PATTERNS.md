# Phase 13: Check-in and Goal Form — Pattern Map

**Mapped:** 2026-06-13
**Files analyzed:** 6 (3 modified source files + 3 new test files)
**Analogs found:** 6 / 6

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/screens/schedule/checkin_screen.dart` | screen (StatefulWidget) | event-driven state machine | itself (existing) | self — targeted edit |
| `lib/screens/goals/goal_form_sheet.dart` | screen (StatefulWidget, bottom sheet) | CRUD | itself (existing) | self — targeted edit |
| `lib/screens/goals/widgets/goal_type_picker.dart` | widget (StatelessWidget) | request-response | itself (existing) | self — targeted edit |
| `test/screens/checkin_screen_test.dart` | test (unit) | — | `test/providers/theme_notifier_test.dart` | role-match (unit test, no widget pump) |
| `test/screens/checkin_screen_widget_test.dart` | test (widget) | — | `test/screens/cold_launch_morning_loop_test.dart` | exact (pumps CheckinScreen with full provider tree) |
| `test/widgets/goal_type_picker_test.dart` | test (widget, layout) | — | `test/screens/goal_form_priority_test.dart` | exact (pumps GoalFormSheet/GoalTypePicker, checks widget properties) |

---

## Pattern Assignments

### `lib/screens/schedule/checkin_screen.dart` (modified)

**Analog:** itself — `lib/screens/schedule/checkin_screen.dart`

This file is being surgically edited. The key existing patterns to preserve and the new patterns to introduce are extracted below.

**Existing state fields** (lines 40–43) — add alongside these:
```dart
int? _selectedMood;
bool _lighterDay = true;   // REMOVE this field
bool _scheduleGenerated = false;
bool _isGenerating = false;
```

**New state fields to add** (after `_isGenerating`):
```dart
bool _generationDone = false;                 // true after generateToday() completes
final Map<int, bool> _hoveredMoods = {};      // per-emoji hover state
final Map<int, bool> _pressedMoods = {};      // per-emoji pressed state
```

**Existing `_backgroundColor` getter** (lines 45–50) — unchanged, used by new `_onBgColor`:
```dart
Color get _backgroundColor {
  if (_selectedMood != null) {
    return ThemeNotifier.moodSeeds[_selectedMood!]!;
  }
  return Colors.transparent;
}
```

**New `_onBgColor` getter** — insert after `_backgroundColor`:
```dart
Color get _onBgColor {
  if (_selectedMood == null) return Theme.of(context).colorScheme.onSurface;
  final bg = _backgroundColor;
  final luminance = bg.computeLuminance();
  return luminance > 0.35 ? const Color(0xFF1A1A1A) : Colors.white;
}
```

**Existing `_generate()` method** (lines 52–80) — restructure; key change is `_generationDone = true` instead of `_scheduleGenerated = true` on success, and `lighterDay: false` (provisional):
```dart
Future<void> _generate() async {
  if (_selectedMood == null || _isGenerating) return;
  setState(() => _isGenerating = true);
  try {
    await context.read<ScheduleNotifier>().generateToday(
      moodIndex: _selectedMood!,
      goals: context.read<GoalsNotifier>().goals,
      blocks: context.read<CommitmentsNotifier>().blocks,
      lighterDay: false,  // provisional — decision screen may regenerate
    );
    await NotificationService.requestIOSPermissions();
    if (mounted) {
      setState(() {
        _generationDone = true;   // ← was _scheduleGenerated = true
        _isGenerating = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    }
  }
}
```

**New `_commitAndProceed()` method** — add after `_generate()`:
```dart
Future<void> _commitAndProceed({required bool lighterDay}) async {
  if (lighterDay) {
    await context.read<ScheduleNotifier>().generateToday(
      moodIndex: _selectedMood!,
      goals: context.read<GoalsNotifier>().goals,
      blocks: context.read<CommitmentsNotifier>().blocks,
      lighterDay: true,
    );
  }
  if (mounted) {
    setState(() => _scheduleGenerated = true);
  }
}
```

**Existing `AnimatedSwitcher`** (lines 140–145) — update to three-state:
```dart
// BEFORE (two-state):
body: AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: _scheduleGenerated
      ? _buildAcknowledgmentBody(context)
      : _buildCheckinBody(context),
),

// AFTER (three-state):
body: AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: _scheduleGenerated
      ? _buildAcknowledgmentBody(context)
      : _generationDone
          ? _buildDecisionBody(context)
          : _buildCheckinBody(context),
),
```

**Existing AppBar color references** (lines 129–138) — replace hardcoded `Colors.white` with `_onBgColor`:
```dart
// BEFORE:
color: _selectedMood != null ? Colors.white : Theme.of(context).colorScheme.onSurface,
// AFTER:
color: _selectedMood != null ? _onBgColor : Theme.of(context).colorScheme.onSurface,
// And iconTheme: same replacement.
```

**Existing emoji `GestureDetector` + `AnimatedContainer`** (lines 172–198) — wrap in `MouseRegion`, add `onTapDown`/`onTapUp`/`onTapCancel`:
```dart
// BEFORE (line 172):
GestureDetector(
  onTap: () { setState(() { _selectedMood = mood; }); ... },
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: isSelected ? Colors.white.withAlpha(51) : Colors.transparent,
    ),
    ...
  ),
)

// AFTER:
MouseRegion(
  onEnter: (_) => setState(() => _hoveredMoods[mood] = true),
  onExit: (_) => setState(() => _hoveredMoods[mood] = false),
  child: GestureDetector(
    onTap: () { setState(() { _selectedMood = mood; }); context.read<ThemeNotifier>().setMoodSeed(...); },
    onTapDown: (_) => setState(() => _pressedMoods[mood] = true),
    onTapUp: (_) => setState(() => _pressedMoods[mood] = false),
    onTapCancel: () => setState(() => _pressedMoods[mood] = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _resolveEmojiBackground(mood, isSelected),
      ),
      ...
    ),
  ),
)
```

**New `_resolveEmojiBackground()` helper** — add to `_CheckinScreenState`:
```dart
Color _resolveEmojiBackground(int mood, bool isSelected) {
  final isHovered = _hoveredMoods[mood] ?? false;
  final isPressed = _pressedMoods[mood] ?? false;
  final luminance = _selectedMood != null ? _backgroundColor.computeLuminance() : 0.0;
  final base = luminance > 0.35 ? const Color(0xFF1A1A1A) : Colors.white;
  if (isSelected) {
    return base.withAlpha(isPressed ? 77 : (isHovered ? 64 : 51));
  } else {
    return base.withAlpha(isHovered ? 26 : 0);
  }
}
```

**Existing "Let's go" `ElevatedButton`** (lines 225–253) — three changes: luminance-adaptive colors, `StadiumBorder`, non-null `onPressed` during generation:
```dart
// BEFORE:
ElevatedButton(
  onPressed: _isGenerating ? null : _generate,
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: bgColor,
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
  ),
  ...
)

// AFTER:
ElevatedButton(
  onPressed: _isGenerating ? () {} : _generate,  // never null → no disabled styling
  style: ElevatedButton.styleFrom(
    backgroundColor: _onBgColor,
    foregroundColor: _backgroundColor,
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: const StadiumBorder(),  // adapts to height; replaces BorderRadius.circular(30)
  ),
  ...
)
```

**Existing `_buildAcknowledgmentBody` `ValueKey`** (line 271) — shows the pattern for `_buildDecisionBody`:
```dart
// _buildAcknowledgmentBody already uses:
key: const ValueKey('acknowledgment'),

// _buildDecisionBody must use:
key: const ValueKey('decision'),

// _buildCheckinBody already uses (line 159):
key: const ValueKey('checkin'),
```

**New `_buildDecisionBody()` method** — see RESEARCH.md §`_buildDecisionBody()` Top-Level Structure (lines 464–510) for the full widget tree. Place after `_buildCheckinBody`. The `_LighterDayCard` private class goes at the bottom of the file after `_CheckinScreenState` closes. Key structural excerpt:
```dart
Widget _buildDecisionBody(BuildContext context) {
  final onBg = _onBgColor;
  return Container(
    key: const ValueKey('decision'),
    width: double.infinity,
    height: double.infinity,
    color: _backgroundColor,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // heading, subhead, two _LighterDayCard widgets, "Go back" TextButton
            TextButton(
              onPressed: () => setState(() => _generationDone = false),
              child: Text('Go back', style: TextStyle(color: onBg.withAlpha(179))),
            ),
          ],
        ),
      ),
    ),
  );
}
```

**`_LighterDayCard` private `StatefulWidget`** — analogous to `_TypeCard` in `goal_type_picker.dart` (a private stateful widget used only in one file). Pattern from RESEARCH.md Pattern 4 (lines 238–280):
```dart
class _LighterDayCard extends StatefulWidget {
  const _LighterDayCard({required this.icon, required this.title,
      required this.subtitle, required this.onBgColor, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Color onBgColor;
  final VoidCallback onTap;
  @override
  State<_LighterDayCard> createState() => _LighterDayCardState();
}

class _LighterDayCardState extends State<_LighterDayCard> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.onBgColor.withAlpha(_hovered ? 153 : 77),
                width: 1.5,
              ),
              color: widget.onBgColor.withAlpha(_hovered ? 38 : 26),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(/* leading Icon, title+subtitle Column */),
          ),
        ),
      ),
    );
  }
}
```

---

### `lib/screens/goals/goal_form_sheet.dart` (modified)

**Analog:** itself — three `SizedBox` height reductions only, no structural change.

**Three targeted line changes** (current → new):

```dart
// Line 153 — after title Text:
const SizedBox(height: 16),  →  const SizedBox(height: 12),

// Line 171 — after GoalTypePicker:
const SizedBox(height: 16),  →  const SizedBox(height: 12),

// Line 184 — after goal name TextField:
const SizedBox(height: 16),  →  const SizedBox(height: 12),

// Line 200 — after SegmentedButton: LEAVE UNCHANGED at 16.
```

No other changes. The `SingleChildScrollView(controller: widget.scrollController)` at line 121 is already correct — do NOT add a second scroll view.

---

### `lib/screens/goals/widgets/goal_type_picker.dart` (modified)

**Analog:** itself — `_TypeCard.build()` targeted edit.

**Current `_TypeCard.build()`** (lines 70–92) — the full before state:
```dart
// BEFORE (lines 75–92):
return Card(
  color: backgroundColor,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    side: BorderSide(color: borderColor, width: 2),
  ),
  child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: Icon(icon, color: isSelected ? colorScheme.primary : null),
      title: Text(title),
      subtitle: Text(subtitle),
    ),
  ),
);
```

**After** — four changes: `borderRadius` 12→10, `BorderSide` width 2→1.5, `ListTile` `contentPadding` all(16)→symmetric(h:12,v:6), add `minVerticalPadding: 0`, icon `size: 20` + explicit `onSurfaceVariant` color, title `fontWeight`:
```dart
// AFTER:
final theme = Theme.of(context);
return Card(
  color: backgroundColor,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),          // was 12
    side: BorderSide(color: borderColor, width: 1.5), // was width: 2
  ),
  child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),          // was 12
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // was all(16)
      minVerticalPadding: 0,                          // new — prevents Flutter's 8dp enforced min
      leading: Icon(icon, size: 20,                   // was no size (implicit 24)
          color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
      title: Text(title, style: theme.textTheme.bodyMedium?.copyWith(
        color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, // new
      )),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(
        color: isSelected
            ? colorScheme.onPrimaryContainer.withAlpha(179)
            : colorScheme.onSurfaceVariant,
      )),
    ),
  ),
);
```

Note: `theme` variable is already available via `Theme.of(context)` — add `final theme = Theme.of(context);` at the top of `build()` alongside the existing `final colorScheme = Theme.of(context).colorScheme;`. Or derive: `final theme = Theme.of(context); final colorScheme = theme.colorScheme;`.

---

### `test/screens/checkin_screen_test.dart` (new — unit test)

**Analog:** `test/providers/theme_notifier_test.dart` (pure unit test, no widget pump, tests a computed value)

**File structure pattern** (copy from `test/providers/theme_notifier_test.dart` structure):
```dart
// Unit test for _onBgColor luminance-threshold getter — Phase 13 CHECKIN-01.
//
// Tests Color.computeLuminance() behavior against the five mood seed colors
// to verify WCAG AA compliance: dark text on light backgrounds (luminance > 0.35).

import 'package:canopy/providers/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('_onBgColor luminance threshold (CHECKIN-01)', () {
    // Mood seeds from ThemeNotifier.moodSeeds — test the threshold logic directly
    // without needing to pump CheckinScreen (the getter is a pure Color computation).

    test('mood 1 (#4A6275) luminance is <= 0.35 → expects white foreground', () {
      final color = ThemeNotifier.moodSeeds[1]!;
      expect(color.computeLuminance(), lessThanOrEqualTo(0.35));
    });

    test('mood 5 (#E8C547) luminance is > 0.35 → expects dark foreground', () {
      final color = ThemeNotifier.moodSeeds[5]!;
      expect(color.computeLuminance(), greaterThan(0.35));
    });
    // ... moods 2, 3, 4
  });
}
```

**Key import:** `package:canopy/providers/theme_notifier.dart` — exposes `ThemeNotifier.moodSeeds` as a `static const Map<int, Color>`. Confirmed at lines 56–62 of `lib/providers/theme_notifier.dart`.

**No widget pump needed.** `Color.computeLuminance()` is a pure method — test it directly on the seed color values. Do NOT pump `CheckinScreen` in this file (that is the widget test file).

---

### `test/screens/checkin_screen_widget_test.dart` (new — widget test)

**Analog:** `test/screens/cold_launch_morning_loop_test.dart` — pumps `CheckinScreen` with a full fake provider tree.

**Fake notifier pattern** (copy `_InMemoryScheduleNotifier` from `cold_launch_morning_loop_test.dart`, lines 81–136):
```dart
class _FakeScheduleNotifier extends ScheduleNotifier {
  int generateTodayCallCount = 0;
  bool? lastLighterDay;

  @override
  Future<void> init() async {}

  @override
  Future<void> generateToday({
    required int moodIndex,
    required List<Goal> goals,
    required List<CommitmentBlock> blocks,
    bool lighterDay = true,
  }) async {
    generateTodayCallCount++;
    lastLighterDay = lighterDay;
    // Populate a minimal schedule so _buildAcknowledgmentBody doesn't crash
    _schedule = DailySchedule(dateYmd: '2026-06-13', moodIndex: moodIndex, chunks: []);
    notifyListeners();
  }

  DailySchedule? _schedule;

  @override
  DailySchedule? get todaySchedule => _schedule;

  @override
  bool get hasScheduleToday => _schedule != null;
}
```

**Pump helper** (copy provider tree setup from `cold_launch_morning_loop_test.dart` lines 191–205):
```dart
Future<_FakeScheduleNotifier> _pumpCheckin(WidgetTester tester) async {
  final scheduleNotifier = _FakeScheduleNotifier();
  final themeNotifier = ThemeNotifier(
    repository: InMemoryAppSettingsRepository(),
    timeModulationEnabled: false,
  );
  await themeNotifier.init();
  addTearDown(() { scheduleNotifier.dispose(); themeNotifier.dispose(); });

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<GoalsNotifier>.value(value: _emptyGoalsNotifier()),
        ChangeNotifierProvider<CommitmentsNotifier>.value(value: _emptyCommitmentsNotifier()),
        ChangeNotifierProvider<ScheduleNotifier>.value(value: scheduleNotifier),
        ChangeNotifierProvider<ThemeNotifier>.value(value: themeNotifier),
      ],
      child: const MaterialApp(home: CheckinScreen()),
    ),
  );
  await tester.pump();
  return scheduleNotifier;
}
```

**Test interaction pattern** (copy tap + pump sequence from `cold_launch_morning_loop_test.dart` lines 219–235):
```dart
// Tap mood → tap "Let's go" → pump twice for async
await tester.tap(find.text('⛅'));
await tester.pump();
await tester.tap(find.text("Let's go"));
await tester.pump();  // starts async _generate()
await tester.pump();  // drains microtasks → _generationDone = true
await tester.pumpAndSettle();  // AnimatedSwitcher 300ms transition
```

**Assertions for state machine tests:**
```dart
// Decision screen appeared (State D):
expect(find.text('Ready to start?'), findsOneWidget);
expect(find.text('Full day'), findsOneWidget);
expect(find.text('Lighter day'), findsOneWidget);
expect(find.text('Go back'), findsOneWidget);

// "Go back" resets to State B:
await tester.tap(find.text('Go back'));
await tester.pumpAndSettle();
expect(find.text("Let's go"), findsOneWidget);
expect(find.text('Ready to start?'), findsNothing);

// "Lighter day" triggers second generateToday call:
await tester.tap(find.text('Lighter day'));
await tester.pump();
await tester.pump();
expect(notifier.generateTodayCallCount, 2);
expect(notifier.lastLighterDay, true);
```

---

### `test/widgets/goal_type_picker_test.dart` (new — widget layout test)

**Analog:** `test/screens/goal_form_priority_test.dart` — pumps `GoalFormSheet`/`GoalTypePicker` inside a `pumpWithMood` scaffold, inspects widget properties directly.

**Pump pattern** (copy `_pumpForm` from `goal_form_priority_test.dart` lines 54–82):
```dart
import '../test_helpers/mood_pump.dart';

Future<void> _pumpPicker(WidgetTester tester, {GoalType? selected}) async {
  await pumpWithMood(
    tester,
    GoalTypePicker(
      selectedType: selected,
      onTypeSelected: (_) {},
    ),
  );
}
```

**Layout height assertion** — use `tester.getSize()` (the `goal_form_priority_test.dart` pattern uses `tester.widget<SegmentedButton>()` to inspect widget props; for layout use `tester.getSize()`):
```dart
testWidgets('_TypeCard renders at <= 64dp height', (tester) async {
  await pumpWithMood(
    tester,
    GoalTypePicker(selectedType: null, onTypeSelected: (_) {}),
  );
  // Find the first Card (first _TypeCard)
  final cardSize = tester.getSize(find.byType(Card).first);
  expect(
    cardSize.height,
    lessThanOrEqualTo(64.0),
    reason: 'GOALFORM-01: compact _TypeCard must fit within 64dp height',
  );
});
```

**`ListTile.minVerticalPadding` property assertion** (copy `tester.widget<T>()` pattern from `goal_form_priority_test.dart` line 107):
```dart
testWidgets('_TypeCard ListTile has minVerticalPadding == 0', (tester) async {
  await pumpWithMood(
    tester,
    GoalTypePicker(selectedType: null, onTypeSelected: (_) {}),
  );
  final tile = tester.widget<ListTile>(find.byType(ListTile).first);
  expect(tile.minVerticalPadding, 0.0);
});
```

**Viewport sizing for layout tests** (copy from `goal_form_priority_test.dart` line 122):
```dart
await tester.binding.setSurfaceSize(const Size(390, 844));  // iPhone 14 logical px
addTearDown(() => tester.binding.setSurfaceSize(null));
// OR use the viewport.dart helper:
import '../test_helpers/viewport.dart';
setViewport(tester, const Size(390, 844));
```

---

## Shared Patterns

### `pumpWithMood` — universal test pump helper

**Source:** `test/test_helpers/mood_pump.dart` (full file, 48 lines)
**Apply to:** All three new test files
```dart
// Import in every new test file:
import '../test_helpers/mood_pump.dart';

// Usage: wraps widget in MaterialApp with mood-seeded theme + optional providers
await pumpWithMood(tester, MyWidget(), extraProviders: [...]);
```

### `setViewport` — viewport sizing for layout tests

**Source:** `test/test_helpers/viewport.dart`
**Apply to:** `test/widgets/goal_type_picker_test.dart` (layout height assertions need a known viewport)
```dart
import '../test_helpers/viewport.dart';
setViewport(tester, const Size(390, 844));  // also registers addTearDown(tester.view.reset)
```

### In-memory fake repository pattern

**Source:** `test/screens/goal_form_priority_test.dart` lines 23–45 (`_InMemoryGoalRepository`)
**Apply to:** `test/screens/checkin_screen_widget_test.dart` when a `GoalsNotifier` is needed
```dart
class _InMemoryGoalRepository implements GoalRepository {
  final Map<String, Goal> _store = {};
  @override Future<List<Goal>> getAll() async => _store.values.toList();
  @override Future<Goal?> getById(String id) async => _store[id];
  @override Future<void> save(Goal goal) async => _store[goal.id] = goal;
  @override Future<void> delete(String id) async => _store.remove(id);
  @override Future<List<Goal>> getActive() async =>
      _store.values.where((g) => !g.isArchived).toList();
}
```

### `ChangeNotifierProvider.value` multi-provider pattern

**Source:** `test/screens/cold_launch_morning_loop_test.dart` lines 191–205
**Apply to:** `test/screens/checkin_screen_widget_test.dart`
```dart
await tester.pumpWidget(
  MultiProvider(
    providers: [
      ChangeNotifierProvider<GoalsNotifier>.value(value: goalsNotifier),
      ChangeNotifierProvider<CommitmentsNotifier>.value(value: commitmentsNotifier),
      ChangeNotifierProvider<ScheduleNotifier>.value(value: scheduleNotifier),
      ChangeNotifierProvider<ThemeNotifier>.value(value: themeNotifier),
    ],
    child: const MaterialApp(home: CheckinScreen()),
  ),
);
```

### `addTearDown(notifier.dispose)` — notifier lifecycle in tests

**Source:** `test/screens/cold_launch_morning_loop_test.dart` lines 182–186
**Apply to:** Any test that creates a real `ThemeNotifier` (which starts a ticker)
```dart
addTearDown(() {
  scheduleNotifier.dispose();
  themeNotifier.dispose();
});
```

---

## No Analog Found

None — all six files have clear analogs in the codebase.

---

## Metadata

**Analog search scope:** `lib/screens/`, `lib/providers/`, `test/screens/`, `test/providers/`, `test/test_helpers/`
**Files read:** 8 source files, 4 test files, 2 test helpers
**Pattern extraction date:** 2026-06-13

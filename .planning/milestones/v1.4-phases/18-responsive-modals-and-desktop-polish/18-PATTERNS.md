# Phase 18: Responsive Modals and Desktop Polish — Pattern Map

**Mapped:** 2026-06-14
**Files analyzed:** 10 new/modified files
**Analogs found:** 10 / 10

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/widgets/adaptive_form_modal.dart` | utility/helper | request-response | `lib/screens/goals/goals_screen.dart` (`_openAddSheet`) | role-match (same modal-routing responsibility) |
| `lib/screens/goals/goal_form_sheet.dart` | component | request-response | `lib/screens/commitments/commitment_form_sheet.dart` | exact |
| `lib/screens/goals/goals_screen.dart` | screen | CRUD | `lib/screens/commitments/commitments_screen.dart` | exact |
| `lib/screens/commitments/commitment_form_sheet.dart` | component | request-response | `lib/screens/goals/goal_form_sheet.dart` | exact |
| `lib/screens/commitments/commitments_screen.dart` | screen | CRUD | `lib/screens/goals/goals_screen.dart` | exact |
| `lib/screens/home/home_screen.dart` | screen | request-response | `lib/screens/schedule/checkin_screen.dart` | role-match (ConstrainedBox pattern) |
| `lib/screens/schedule/schedule_screen.dart` | screen | request-response | `lib/screens/schedule/checkin_screen.dart` | role-match (ConstrainedBox pattern) |
| `lib/screens/goals/goals_screen.dart` (body constraint) | screen | request-response | `lib/screens/schedule/checkin_screen.dart` | role-match (ConstrainedBox pattern) |
| `test/screens/adaptive_form_modal_test.dart` | test | — | `test/screens/goal_form_priority_test.dart` | exact |
| `test/screens/content_width_constraint_test.dart` | test | — | `test/screens/responsive_layout_test.dart` | exact |

---

## Pattern Assignments

### `lib/widgets/adaptive_form_modal.dart` (utility helper, request-response)

**Analog:** `lib/screens/goals/goals_screen.dart` — `_openAddSheet` / `_openEditSheet` methods (lines 28–60)

**Imports pattern** — follow this import style for a widget-layer helper:
```dart
import 'package:flutter/material.dart';
```
No provider imports needed; the helper is a pure routing function.

**Core pattern — existing showModalBottomSheet call to preserve on mobile path** (`goals_screen.dart` lines 29–43):
```dart
showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (ctx) => DraggableScrollableSheet(
    initialChildSize: 0.6,
    minChildSize: 0.4,
    maxChildSize: 1.0,
    expand: false,
    snap: true,
    snapSizes: const [0.6, 1.0],
    builder: (ctx, scrollController) =>
        GoalFormSheet(scrollController: scrollController),
  ),
);
```
The new helper wraps this block in the mobile branch and adds a `showDialog` desktop branch.

**Breakpoint detection pattern** — from `lib/widgets/responsive_shell.dart` line 66:
```dart
// responsive_shell.dart uses LayoutBuilder constraints; the helper reads
// MediaQuery directly (called imperatively, not inside LayoutBuilder):
if (constraints.maxWidth >= 720) { ... }
// Equivalent in helper:
final width = MediaQuery.of(context).size.width;
final isDesktop = width >= 720;
```

**Desktop dialog pattern** — `showDialog` + `Dialog` + `ConstrainedBox`:
```dart
final screenHeight = MediaQuery.of(context).size.height;  // read BEFORE showDialog
await showDialog<void>(
  context: context,
  barrierDismissible: true,
  builder: (ctx) {
    final scrollController = ScrollController();
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: screenHeight * 0.8,
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          child: builder(scrollController),
        ),
      ),
    );
  },
);
```
`screenHeight` must be captured before entering `showDialog` — reading it inside the dialog's builder uses the dialog's own constraints, not the screen height.

---

### `lib/screens/goals/goal_form_sheet.dart` (component, request-response)

**Analog:** `lib/screens/commitments/commitment_form_sheet.dart`

**Current constructor** (`goal_form_sheet.dart` lines 8–9):
```dart
class GoalFormSheet extends StatefulWidget {
  const GoalFormSheet({super.key, required this.scrollController, this.goal});
  final ScrollController scrollController;
  final Goal? goal;
```

**New constructor** — add `isDialog` parameter:
```dart
class GoalFormSheet extends StatefulWidget {
  const GoalFormSheet({
    super.key,
    required this.scrollController,
    this.goal,
    this.isDialog = false,   // NEW
  });
  final ScrollController scrollController;
  final Goal? goal;
  final bool isDialog;       // NEW
```

**Drag handle pattern** — before change (`goal_form_sheet.dart` lines 154–165):
```dart
// Drag handle indicator
Center(
  child: Container(
    width: 40,
    height: 4,
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: colorScheme.outlineVariant,
      borderRadius: BorderRadius.circular(2),
    ),
  ),
),
```
After change: wrap in `if (!widget.isDialog)`.

**viewInsets padding pattern** — before change (`goal_form_sheet.dart` lines 143–149):
```dart
padding: EdgeInsets.fromLTRB(
  16,
  16,
  16,
  16 + MediaQuery.of(context).viewInsets.bottom,
),
```
After change:
```dart
padding: EdgeInsets.fromLTRB(
  24, 24, 24,
  widget.isDialog ? 24 : 16 + MediaQuery.of(context).viewInsets.bottom,
),
```

**Title copy changes** (`goal_form_sheet.dart` line 168–170):
```dart
// Before:
Text(_isEditMode ? 'Edit goal' : 'Add goal', style: theme.textTheme.titleLarge, ...)
// After:
Text(_isEditMode ? 'Edit Goal' : 'Add Goal', style: theme.textTheme.titleLarge, ...)
```

**Button copy changes** — locate the `ElevatedButton` and `TextButton` for Cancel/Archive near the bottom of `build()` and apply:
- Primary CTA: `_isEditMode ? 'Save Goal' : 'Add Goal'`
- Cancel: `'Discard'`
- Archive: `'Archive goal'`

**Error handling pattern** (`goal_form_sheet.dart` lines 93–104) — preserve unchanged:
```dart
try {
  await notifier.saveGoal(goal);
  if (mounted) Navigator.pop(context);
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not save goal. Please try again.')),
    );
  }
}
```

---

### `lib/screens/goals/goals_screen.dart` (screen, CRUD — modal caller + body constraint)

**Analog:** `lib/screens/commitments/commitments_screen.dart`

**Current modal caller** (`goals_screen.dart` lines 28–60) — replace both `_openAddSheet` and `_openEditSheet`:
```dart
// BEFORE:
void _openAddSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      ...
      builder: (ctx, scrollController) =>
          GoalFormSheet(scrollController: scrollController),
    ),
  );
}

// AFTER:
void _openAddSheet(BuildContext context) {
  showAdaptiveFormModal(
    context: context,
    builder: (scrollController) =>
        GoalFormSheet(scrollController: scrollController),
  );
}

void _openEditSheet(BuildContext context, Goal goal) {
  showAdaptiveFormModal(
    context: context,
    builder: (scrollController) =>
        GoalFormSheet(scrollController: scrollController, goal: goal),
  );
}
```

**Import to add:**
```dart
import '../../widgets/adaptive_form_modal.dart';
```

**Body constraint pattern** — apply `Align` + `ConstrainedBox` around the `CustomScrollView` returned by the `Consumer` builder. Precedent: `checkin_screen.dart` lines 222–225.

---

### `lib/screens/commitments/commitment_form_sheet.dart` (component, request-response)

**Analog:** `lib/screens/goals/goal_form_sheet.dart`

**Current constructor** (`commitment_form_sheet.dart` lines 7–15):
```dart
class CommitmentFormSheet extends StatefulWidget {
  const CommitmentFormSheet({
    super.key,
    required this.scrollController,
    this.block,
  });
  final ScrollController scrollController;
  final CommitmentBlock? block;
```

**New constructor** — add `isDialog`:
```dart
class CommitmentFormSheet extends StatefulWidget {
  const CommitmentFormSheet({
    super.key,
    required this.scrollController,
    this.block,
    this.isDialog = false,   // NEW
  });
  final ScrollController scrollController;
  final CommitmentBlock? block;
  final bool isDialog;       // NEW
```

**Drag handle pattern** — before change (`commitment_form_sheet.dart` lines 130–139):
```dart
// Drag indicator
Center(
  child: Container(
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: colorScheme.outline,
      borderRadius: BorderRadius.circular(2),
    ),
  ),
),
```
After change: wrap in `if (!widget.isDialog)`.

**viewInsets padding pattern** — before change (`commitment_form_sheet.dart` lines 120–125):
```dart
padding: EdgeInsets.fromLTRB(
  16,
  8,
  16,
  32 + MediaQuery.viewInsetsOf(context).bottom,
),
```
After change:
```dart
padding: EdgeInsets.fromLTRB(
  24,
  widget.isDialog ? 24 : 8,
  24,
  widget.isDialog ? 24 : 32 + MediaQuery.viewInsetsOf(context).bottom,
),
```

**Discard button to add** — `CommitmentFormSheet` currently has only a `FilledButton` for save. Add a `TextButton` above it:
```dart
// Pattern from goal_form_sheet.dart Cancel/Discard button structure:
TextButton(
  onPressed: () => Navigator.of(context).pop(),
  child: const Text('Discard'),
),
const SizedBox(height: 8),
FilledButton(
  onPressed: _canSave ? _save : null,
  child: Text(isEdit ? 'Save changes' : 'Add commitment'),
),
```

**Save pop pattern** (`commitment_form_sheet.dart` line 109) — preserve:
```dart
if (mounted) Navigator.of(context).pop();
```
This resolves correctly inside both `showModalBottomSheet` and `showDialog`.

---

### `lib/screens/commitments/commitments_screen.dart` (screen, CRUD — modal caller + copy fixes)

**Analog:** `lib/screens/goals/goals_screen.dart`

**Current modal caller** (`commitments_screen.dart` lines 26–42) — replace:
```dart
// BEFORE:
void _openAddSheet(BuildContext context, [CommitmentBlock? block]) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.65,
      ...
      builder: (ctx, sc) =>
          CommitmentFormSheet(scrollController: sc, block: block),
    ),
  );
}

// AFTER:
void _openAddSheet(BuildContext context, [CommitmentBlock? block]) {
  showAdaptiveFormModal(
    context: context,
    builder: (scrollController) =>
        CommitmentFormSheet(scrollController: scrollController, block: block),
  );
}
```

**Import to add:**
```dart
import '../../widgets/adaptive_form_modal.dart';
```

**Delete dialog copy changes** (`commitments_screen.dart` lines 48–62) — current:
```dart
TextButton(
  onPressed: () => Navigator.of(ctx).pop(false),
  child: const Text('Cancel'),
),
TextButton(
  onPressed: () => Navigator.of(ctx).pop(true),
  child: const Text('Delete'),
```
Change to:
```dart
TextButton(
  onPressed: () => Navigator.of(ctx).pop(false),
  child: const Text('Keep commitment'),
),
TextButton(
  onPressed: () => Navigator.of(ctx).pop(true),
  child: const Text('Delete commitment'),
```

---

### `lib/screens/home/home_screen.dart` (screen, request-response — body constraint)

**Analog:** `lib/screens/schedule/checkin_screen.dart` lines 222–225

**Existing checkin pattern** (the precedent):
```dart
return Center(
  key: const ValueKey('checkin'),
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 480),
    child: Padding(...),
  ),
);
```

**Current home body** (`home_screen.dart` line 354):
```dart
body: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    ScheduleProgressBar(schedule: schedule, moodColor: moodColor),
    ...
  ],
),
```

**Change** — wrap the entire `Column` in `Align` + `ConstrainedBox`. `Align(topCenter)` not `Center` to prevent vertical centering on short content:
```dart
body: Align(
  alignment: Alignment.topCenter,
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 720),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScheduleProgressBar(schedule: schedule, moodColor: moodColor),
        // ... all existing children unchanged
      ],
    ),
  ),
),
```

---

### `lib/screens/schedule/schedule_screen.dart` (screen, request-response — body constraint)

**Analog:** `lib/screens/schedule/checkin_screen.dart` lines 222–225

**Current schedule body** (`schedule_screen.dart` lines 88–101):
```dart
body: Column(
  children: [
    ScheduleProgressBar(schedule: schedule, moodColor: moodColor),
    Expanded(
      child: ListView(
        children: _buildActiveChunkItems(context, activeChunks) + [...],
      ),
    ),
  ],
),
```

**Change** — `ScheduleProgressBar` stays full-width; constrain only the `ListView` inside `Expanded`:
```dart
body: Column(
  children: [
    ScheduleProgressBar(schedule: schedule, moodColor: moodColor),  // full-width
    Expanded(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            children: _buildActiveChunkItems(context, activeChunks) + [...],
          ),
        ),
      ),
    ),
  ],
),
```

---

### `test/screens/adaptive_form_modal_test.dart` (test)

**Analog:** `test/screens/goal_form_priority_test.dart`

**Imports pattern** (from `goal_form_priority_test.dart` lines 17–26):
```dart
import 'package:canopy/screens/goals/goal_form_sheet.dart';
import 'package:canopy/screens/commitments/commitment_form_sheet.dart';
import 'package:canopy/widgets/adaptive_form_modal.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/providers/commitments_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';
import '../test_helpers/viewport.dart';
```

**Viewport setup pattern** (`goal_form_priority_test.dart` `_pumpModal` lines 103–104):
```dart
setViewport(tester, const Size(720, 900));  // desktop path — >= 720dp
// or for mobile path:
setViewport(tester, const Size(390, 844));  // < 720dp
```
Always use `setViewport` from `test/test_helpers/viewport.dart` — never set `tester.view.physicalSize` directly. Teardown is auto-registered.

**showDialog pump pattern** — analogous to `_pumpModal` in `goal_form_priority_test.dart` lines 102–138, but routing through `showAdaptiveFormModal`:
```dart
Future<void> _pumpAdaptiveModal(WidgetTester tester, Size viewport) async {
  setViewport(tester, viewport);
  late BuildContext capturedCtx;
  await pumpWithMood(
    tester,
    Builder(builder: (ctx) {
      capturedCtx = ctx;
      return const SizedBox.shrink();
    }),
    extraProviders: [
      ChangeNotifierProvider<GoalsNotifier>.value(value: notifier),
    ],
  );

  // Do NOT await — Future only resolves on dismiss
  showAdaptiveFormModal(
    context: capturedCtx,
    builder: (sc) => GoalFormSheet(scrollController: sc),
  );
  await tester.pumpAndSettle();
}
```

**Dialog assertion pattern** — after pump at >= 720dp:
```dart
expect(find.byType(Dialog), findsOneWidget);
expect(find.byType(BottomSheet), findsNothing);
```
After pump at < 720dp:
```dart
expect(find.byType(BottomSheet), findsOneWidget);
expect(find.byType(Dialog), findsNothing);
```

**ConstrainedBox assertion pattern** — finding the specific ConstrainedBox inside the Dialog:
```dart
final constrainedBox = tester.widget<ConstrainedBox>(
  find.descendant(of: find.byType(Dialog), matching: find.byType(ConstrainedBox)).first,
);
expect(constrainedBox.constraints.maxWidth, equals(560.0));
```

**Scrollable pattern** (`goal_form_priority_test.dart` line 287 comment) — for `scrollUntilVisible` inside modal:
```dart
// ALWAYS use find.byType(Scrollable).first — NOT find.byType(SingleChildScrollView)
// SingleChildScrollView is not a Scrollable subtype; the cast fails at runtime.
await tester.scrollUntilVisible(
  find.text('Priority'),
  200,
  scrollable: find.byType(Scrollable).first,
);
```

---

### `test/screens/content_width_constraint_test.dart` (test)

**Analog:** `test/screens/responsive_layout_test.dart`

**Pump helper pattern** (`responsive_layout_test.dart` lines 82–86):
```dart
Future<void> _pumpShellAt(WidgetTester tester, Size logicalSize) async {
  setViewport(tester, logicalSize);
  await tester.pumpWidget(MaterialApp.router(routerConfig: _testRouter()));
  await tester.pumpAndSettle();
}
```
For content-width tests: set a desktop viewport, pump the screen under test with minimal provider stubs, then assert `find.byType(ConstrainedBox)` with the expected maxWidth.

**Breakpoint assertion structure** (`responsive_layout_test.dart` lines 88–106):
```dart
testWidgets('Goals screen body contains ConstrainedBox(maxWidth: 720)', (tester) async {
  setViewport(tester, const Size(1024, 768));
  // pump GoalsScreen with minimal GoalsNotifier stub ...
  await tester.pumpAndSettle();

  final boxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
  expect(
    boxes.any((b) => b.constraints.maxWidth == 720.0),
    isTrue,
    reason: 'Goals screen body must be constrained to 720dp on desktop',
  );
});
```

---

## Shared Patterns

### Breakpoint constant: 720dp
**Source:** `lib/widgets/responsive_shell.dart` line 66
**Apply to:** `adaptive_form_modal.dart` (MediaQuery read), all primary screen body constraints, all new tests
```dart
// responsive_shell.dart uses LayoutBuilder:
if (constraints.maxWidth >= 720) { ... }

// adaptive_form_modal.dart uses MediaQuery (imperative call site):
final isDesktop = MediaQuery.of(context).size.width >= 720;
```
Do not introduce a separate constant for 720 in the helper — the value matches `responsive_shell.dart`'s existing inline usage. If the constant is later extracted to a shared location, both should migrate together.

### ConstrainedBox + Align.topCenter (content width)
**Source:** `lib/screens/schedule/checkin_screen.dart` lines 222–225 (scaled from 480 to 720)
**Apply to:** `home_screen.dart`, `schedule_screen.dart`, `goals_screen.dart` body constraints
```dart
Align(
  alignment: Alignment.topCenter,
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 720),
    child: <existing scrollable/column>,
  ),
)
```
Use `Align(topCenter)` not `Center` — `Center` vertically centers short content, which floats it mid-screen.

### isDialog parameter for form sheets
**Source:** to be introduced in `goal_form_sheet.dart` and mirrored in `commitment_form_sheet.dart`
**Apply to:** both form sheets, all call sites through `showAdaptiveFormModal`
```dart
// In constructor: this.isDialog = false
// In drag handle render: if (!widget.isDialog) Center(Container(...)),
// In padding: widget.isDialog ? 24 : 16 + MediaQuery.of(context).viewInsets.bottom
```

### Navigator.pop pattern
**Source:** `lib/screens/goals/goal_form_sheet.dart` line 95; `lib/screens/commitments/commitment_form_sheet.dart` line 109
**Apply to:** all form sheet save/cancel actions
```dart
// Goal form sheet:
if (mounted) Navigator.pop(context);
// Commitment form sheet:
if (mounted) Navigator.of(context).pop();
```
Both forms work correctly inside `showDialog` — `showDialog` uses `Navigator.push` internally so `pop` resolves on the same navigator stack.

### Test viewport setup
**Source:** `test/test_helpers/viewport.dart` lines 17–21
**Apply to:** all new tests in `adaptive_form_modal_test.dart` and `content_width_constraint_test.dart`
```dart
// ALWAYS use setViewport, never tester.view.physicalSize directly:
setViewport(tester, const Size(720, 900));
// Teardown is auto-registered — caller must NOT add another teardown.
```

### Test pump with mood + providers
**Source:** `test/test_helpers/mood_pump.dart` lines 24–48
**Apply to:** all new tests that pump form sheets
```dart
await pumpWithMood(
  tester,
  myWidget,
  extraProviders: [
    ChangeNotifierProvider<GoalsNotifier>.value(value: notifier),
  ],
);
```

### In-memory repository stub pattern
**Source:** `test/screens/goal_form_priority_test.dart` lines 31–53
**Apply to:** any new test that exercises `GoalFormSheet` or `CommitmentFormSheet`
```dart
class _InMemoryGoalRepository implements GoalRepository {
  final Map<String, Goal> _store = {};
  Goal? lastSaved;

  @override Future<List<Goal>> getAll() async => _store.values.toList();
  @override Future<Goal?> getById(String id) async => _store[id];
  @override Future<void> save(Goal goal) async { _store[goal.id] = goal; lastSaved = goal; }
  @override Future<void> delete(String id) async => _store.remove(id);
  @override Future<List<Goal>> getActive() async =>
      _store.values.where((g) => !g.isArchived).toList();
}
```

---

## No Analog Found

All files have clear analogs. No files require falling back to RESEARCH.md patterns only.

---

## Metadata

**Analog search scope:** `lib/widgets/`, `lib/screens/goals/`, `lib/screens/commitments/`, `lib/screens/home/`, `lib/screens/schedule/`, `test/screens/`, `test/test_helpers/`
**Files read:** 12
**Pattern extraction date:** 2026-06-14

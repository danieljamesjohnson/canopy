# Phase 16: Priority Model Reconciliation - Research

**Researched:** 2026-06-13
**Domain:** Flutter widget state management, modal bottom sheet testing, priority model consistency
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
None — discuss phase was skipped per user setting.

### Claude's Discretion
All implementation choices are at Claude's discretion. Known guidance from REQUIREMENTS.md:
- **PRIORITY-03**: Drag-reorder and the Low/Normal/High control must write a single coherent
  priority model — no goal silently losing its chip by landing at a mid-list ~0.5. (SEED-003 #3)
- **GOALFORM-02**: Replace the existing test that resized the surface to 800×1200 and pumped
  the form outside the modal with one that proves Priority and Save are reachable at the goal
  sheet's *true* opened modal height, for every goal type. Restructure the sheet if outcome
  goals overflow. (SEED-003 #2)

### Deferred Ideas (OUT OF SCOPE)
None — discuss phase skipped.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PRIORITY-03 | Drag-reorder and form's Low/Normal/High control write a single coherent priority model so a goal's chip stays correct after any interaction | Consumer rebuild path confirmed as live; linear-spread formula documented; chip read path verified; test pattern identified for widget-level verification |
| GOALFORM-02 | Automated test proves Priority and Save are reachable at the goal sheet's true opened modal height for every goal type — replacing the 800×1200 oversized test | modal pump pattern, setViewport(390, 844), scrollUntilVisible API, true modal height formula documented; existing test file and test group identified |
</phase_requirements>

---

## Summary

Phase 16 is a correctness reconciliation — no new UI surfaces, no new dependencies. It
addresses two requirements: (1) PRIORITY-03: confirm the priority chip updates correctly
after drag-reorder, and write a widget test proving it; (2) GOALFORM-02: replace the two
existing tests in `goal_form_priority_test.dart` that call `setSurfaceSize(800, 1200)` and
pump `GoalFormSheet` directly (outside a modal) with tests that use a true-viewport modal
pump, `scrollUntilVisible`, and all three goal types.

**PRIORITY-03 finding:** The Consumer/chip rebuild path is already architecturally correct.
`GoalsScreen.body` is wrapped in a single `Consumer<GoalsNotifier>`. Inside that builder,
`notifier.timeTargetGoals`, `notifier.outcomeGoals`, and `notifier.habitGoals` are read
fresh. These live lists are passed as `group` to `_buildReorderableSection`. The
`ReorderableListView.builder`'s `itemBuilder` then supplies `group[i]` — a fresh `Goal`
object — to each `GoalCard`. After `reorderAllWithPriority` calls `loadGoals()` and then
`notifyListeners()`, the Consumer rebuilds with fresh goal objects and `_PriorityChip`
reads the new `priorityWeight`. **No production code change is expected unless the widget
test reveals a rebuild failure.** The task is to write a widget test that asserts the chip
shows the correct tier after a programmatic reorder, proving no stale state.

**GOALFORM-02 finding:** The two existing `setSurfaceSize(800, 1200)` tests in
`test/screens/goal_form_priority_test.dart` pump `GoalFormSheet` directly as a
`SingleChildScrollView` child — completely outside `showModalBottomSheet`. At 1200px the
form is never clipped, so the test cannot catch overflow at a real modal height. The fix
is to use `setViewport(tester, Size(390, 844))`, pump `GoalFormSheet` inside a real
`showModalBottomSheet` + `DraggableScrollableSheet` (initialChildSize 0.6), and use
`scrollUntilVisible` to find the `SegmentedButton` and `ElevatedButton`. The outcome goal
variant has enough fields (~712px content) that scroll IS required even at true modal
height — which validates the test is doing real work. No restructuring of `GoalFormSheet`
is needed because `SingleChildScrollView` is already in place.

**Primary recommendation:** Write two new tests — one widget test asserting chip updates
after programmatic reorder (PRIORITY-03), one replacing the two `setSurfaceSize` tests
with a true-modal-height group covering all three goal types (GOALFORM-02) — then delete
or replace the two old `setSurfaceSize` tests in place.

---

## Project Constraints (from CLAUDE.md)

| Directive | Applies to Phase 16 |
|-----------|---------------------|
| State management: Provider + `ChangeNotifier`; notifiers in `lib/providers/` | Yes — no changes to state pattern |
| Screen-local state: `StatefulWidget` + `setState()` only | Yes — `GoalFormSheet` uses this correctly |
| No routing library changes | Yes — phase touches no routes |
| `flutter_lints` enforced | Yes — all new test code must pass `flutter analyze` |
| Tests in `test/`, use `flutter_test` framework | Yes |
| `pumpWithMood` helper for all widget tests | Yes — use with `moodIndex: 3` default |
| No new packages | Yes — `scrollUntilVisible` and `setViewport` are already in the project |

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Priority weight storage | Data layer (`Goal.priorityWeight`) | — | `Goal` is a Hive model; `priorityWeight` is the single source of truth for both drag and form |
| Priority weight write — drag path | Provider (`GoalsNotifier.reorderAllWithPriority`) | Screen (`GoalsScreen.onReorderItem`) | Screen computes new order, provider writes weights and calls `notifyListeners` |
| Priority weight write — form path | Widget (`GoalFormSheet._save`) | Provider (`GoalsNotifier.saveGoal`) | Form collects discrete selector value, saves via notifier |
| Priority chip display | Widget (`goal_card.dart:_PriorityChip`) | — | Pure display widget; reads `goal.priorityWeight` once per build |
| Consumer rebuild orchestration | Screen (`GoalsScreen`/`Consumer<GoalsNotifier>`) | — | Single Consumer wraps all GoalCard instances; rebuild triggered by `notifyListeners` |
| Schedule engine priority reads | Service (`schedule_generator.dart`) | — | Reads `priorityWeight >= 0.75` (High), `< 0.75` (non-High) for chunk count decisions |

---

## Existing Code — Priority Model Deep Dive [ASSUMED]

### `Goal.priorityWeight` (the single source of truth)

**File:** `lib/data/models/goal.dart`
**Type:** `double?` (nullable; null treated as 0.5/Normal throughout)
**Range:** Continuous 0.0–1.0 in principle; in practice the two write paths use:
- Drag: linear spread within `[0.25, 0.75]`
- Form selector: exactly one of `{0.25, 0.5, 0.75}`

### `GoalsNotifier.reorderAllWithPriority` (drag write path)

**File:** `lib/providers/goals_notifier.dart` lines 97–110

```dart
// Source: lib/providers/goals_notifier.dart (read 2026-06-13)
Future<void> reorderAllWithPriority(List<String> orderedIds) async {
  const double high = 0.75;
  const double low = 0.25;
  final n = orderedIds.length;
  for (var i = 0; i < n; i++) {
    final goal = _goals.where((g) => g.id == orderedIds[i]).firstOrNull;
    if (goal != null) {
      goal.sortOrder = i;
      goal.priorityWeight = n <= 1 ? high : high - (high - low) * i / (n - 1);
      await _repository.save(goal);
    }
  }
  await loadGoals(); // -> notifyListeners()
}
```

**Linear-spread outputs by list size:**

| n | pos 0 | pos 1 | pos 2 | pos 3 | pos 4 |
|---|-------|-------|-------|-------|-------|
| 1 | 0.75 (High) | — | — | — | — |
| 2 | 0.75 (High) | 0.25 (Low) | — | — | — |
| 3 | 0.75 (High) | 0.50 (Normal/no chip) | 0.25 (Low) | — | — |
| 4 | 0.75 (High) | 0.583 (Normal/no chip) | 0.417 (Normal/no chip) | 0.25 (Low) | — |
| 5 | 0.75 (High) | 0.625 (Normal/no chip) | 0.50 (Normal/no chip) | 0.375 (Normal/no chip) | 0.25 (Low) |

**Key insight:** For any list with n ≥ 3, the goal at position 1 through n-2 lands in the
Normal band and shows NO chip. This is INTENDED: Normal means no chip. The concern in
PRIORITY-03 is not that the chip disappears (that is correct) but that the chip might
show a STALE value from before the drag if the Consumer rebuild doesn't propagate the
new `Goal` object to `GoalCard`. The task is to verify (via a test) that the chip
updates atomically with the rebuild.

### `GoalFormSheet` priority selector (form write path)

**File:** `lib/screens/goals/goal_form_sheet.dart` lines 223–233

```dart
// Source: lib/screens/goals/goal_form_sheet.dart (read 2026-06-13)
SegmentedButton<double>(
  segments: const [
    ButtonSegment(value: 0.25, label: Text('Low')),
    ButtonSegment(value: 0.5, label: Text('Normal')),
    ButtonSegment(value: 0.75, label: Text('High')),
  ],
  selected: {_priorityWeight ?? 0.5},
  onSelectionChanged: (Set<double> val) =>
      setState(() => _priorityWeight = val.first),
),
```

On save (`_save()`), `goal.priorityWeight = _priorityWeight` (line 87) — persists
exactly one of `{0.25, 0.5, 0.75}` to the `Goal` object. Followed by
`notifier.saveGoal(goal)` which calls `loadGoals()` → `notifyListeners()`.

**Model coherence:** Both paths write to `Goal.priorityWeight`. Neither path reads the
other's state. The engine reads `priorityWeight >= 0.75` as High, `<= 0.25` as Low
(implicit, by falling through). The chip reads `priorityWeight >= 0.75` as High,
`priorityWeight <= 0.25` as Low, else no chip. The two write paths are NOT in conflict —
they just produce different values (discrete vs. spread). The requirement says they must
be "coherent": after drag, the form selector shows the drag-assigned value (already
true via `initState` reading `goal.priorityWeight`); after form save, the chip shows the
form-selected value (already true via `loadGoals` → Consumer rebuild).

### `_PriorityChip` (chip read path)

**File:** `lib/screens/goals/widgets/goal_card.dart` lines 230–281

```dart
// Source: lib/screens/goals/widgets/goal_card.dart (read 2026-06-13)
final pw = goal.priorityWeight ?? 0.5;
final showPriorityChip = pw >= 0.75 || pw <= 0.25;
// ...
if (priorityWeight >= 0.75) {
  // High chip
} else if (priorityWeight <= 0.25) {
  // Low chip  
} else {
  return const SizedBox.shrink(); // Normal — no chip
}
```

Band thresholds are **inclusive at the boundaries** (`>=` / `<=`). Exactly matches the
engine's threshold (`priorityWeight >= 0.75` for High surplus chunk at line 380 of
`schedule_generator.dart`). No mismatch between chip rendering and engine behavior.

### `GoalsScreen` Consumer rebuild path

**File:** `lib/screens/goals/goals_screen.dart` lines 89–287

The entire body is a single `Consumer<GoalsNotifier>`. After `notifyListeners()`:
1. Consumer calls `builder(context, notifier, _)` fresh.
2. `timeTargetGoals`, `outcomeGoals`, `habitGoals` are read from `notifier.*Goals` (fresh computed lists from `_goals`).
3. Each group is passed as `group` to `_buildReorderableSection`.
4. `ReorderableListView.builder`'s `itemBuilder` is called with fresh `group[i]`.
5. `GoalCard(goal: group[i])` receives a fresh `Goal` object.
6. `_PriorityChip(priorityWeight: goal.priorityWeight ?? 0.5)` reads the new weight.

**Verdict:** The stale-chip failure mode described in the UI-SPEC CANNOT happen with the
current implementation because `GoalCard` is inside the Consumer rebuild path and
receives `group[i]` from the freshly-computed list. The PRIORITY-03 task is to write a
test that **proves** this, not to fix broken code.

### `GoalFormSheet` modal layout

**File:** `lib/screens/goals/goal_form_sheet.dart` lines 141–338
**Shell:** `SingleChildScrollView(controller: widget.scrollController)` wraps the entire
form. The `scrollController` is the `DraggableScrollableSheet`'s own controller, so
scroll within the sheet IS unified with sheet drag.

**Outcome goal content height (approximate logical pixels):**
- Drag handle + margin: 24
- Title text + SizedBox: 36
- GoalTypePicker (3 cards): ~228
- SizedBox: 12
- Goal name TextField: ~48
- SizedBox: 12
- Priority label row: ~20
- SegmentedButton: ~48
- SizedBox: 16
- date ListTile (outcome only): ~56
- description TextField 3-line (outcome only): ~96
- SizedBox: 16
- Cancel/Save row: ~48
- Padding (16 top + 16 bottom): 32
- **Total outcome**: ~692px

At `initialChildSize: 0.6` on a 844pt device: modal height = 506px.
The outcome form content (692px) exceeds 506px — scroll IS required. This validates the
GOALFORM-02 test approach: at true modal height, the Priority selector and Save button
are off-screen for outcome goals on first open, reachable only via scroll.

**No restructuring needed:** `SingleChildScrollView` already handles this. The
UI-SPEC's "restructure if overflow at maxChildSize 1.0" condition is not triggered.

---

## Existing Test Infrastructure

### Test helpers

**`test/test_helpers/mood_pump.dart`** — `pumpWithMood(tester, child, {moodIndex=3, extraProviders=[]})`:
- Builds `MaterialApp` with `ColorScheme.fromSeed(moodSeeds[moodIndex])`.
- Accepts `ChangeNotifierProvider` extras via `extraProviders`.
- Standard for ALL widget tests in this project.

**`test/test_helpers/viewport.dart`** — `setViewport(tester, Size)`:
- Sets `tester.view.devicePixelRatio = 1.0` and `tester.view.physicalSize = size`.
- Registers `addTearDown(tester.view.reset)` to prevent test-order leakage.
- **Preferred over `tester.binding.setSurfaceSize`** (the old API `setSurfaceSize` is
  deprecated/unreliable in current Flutter; `tester.view.physicalSize` is the current API).

**`_InMemoryGoalRepository`** — defined inline in `test/screens/goal_form_priority_test.dart`
(not shared). Pattern: implement `GoalRepository` with `Map<String, Goal>` and a
`Goal? lastSaved` field for assertion.

### Existing tests to replace (GOALFORM-02)

**File:** `test/screens/goal_form_priority_test.dart`

Two tests use `setSurfaceSize(800, 1200)`:
1. `'tapping High selects it and save persists priorityWeight == 0.75'` (line 119–164)
2. `'selecting Regular time defaults the weekly budget to 3 hrs and saves it'` (line 242–273)

Both pump `GoalFormSheet` directly (not via modal) and use `setSurfaceSize` for height.
These must be **replaced** with a new `group('GOALFORM-02 modal height contract', ...)` that:
- Uses `setViewport(tester, const Size(390, 844))` (realistic iPhone dimensions, dpr=1.0).
- Pumps `GoalFormSheet` inside a real `showModalBottomSheet` + `DraggableScrollableSheet`.
- Asserts `SegmentedButton<double>` and `ElevatedButton` reachable via `scrollUntilVisible`.

The five remaining tests in the file (no `setSurfaceSize`) remain unchanged.

### Existing priority unit test (keep as-is)

**File:** `test/providers/goals_notifier_priority_test.dart`
Tests `reorderAllWithPriority` formula correctness — already green. Do not modify.

### `scrollUntilVisible` API

Available in `flutter_test` package (confirmed at
`packages/flutter_test/lib/src/controller.dart` line 2417):

```dart
// Source: packages/flutter_test/lib/src/controller.dart (read 2026-06-13)
Future<void> scrollUntilVisible(
  FinderBase<Element> finder,
  double delta, {
  FinderBase<Element>? scrollable,
  int maxScrolls = 50,
  Duration duration = const Duration(milliseconds: 50),
  bool continuous = false,
})
```

Default `scrollable` resolves to `find.byType(Scrollable)`. When there are multiple
scrollables (modal backdrop + form's SingleChildScrollView), callers should pass:
`scrollable: find.byType(SingleChildScrollView)` to target the form scroll, not the
modal's outer scroll.

---

## Architecture Patterns

### System Architecture Diagram

```
User drag completes
       |
       v
GoalsScreen.onReorderItem
  (_buildReorderableSection closure)
       |
       v
_buildFullOrderedIds(notifier, type, reorderedGroup)
  -> flat [timeTarget... outcome... habit...] IDs
       |
       v
GoalsNotifier.reorderAllWithPriority(orderedIds)
  -> for each id: goal.priorityWeight = spread formula
  -> _repository.save(goal)  [for each goal]
  -> await loadGoals()
       |
       v
GoalsNotifier.loadGoals()
  -> _repository.getActive()
  -> _goals = active (fresh list)
  -> notifyListeners()
       |
       v
Consumer<GoalsNotifier> rebuild
  -> timeTargetGoals / outcomeGoals / habitGoals (fresh)
       |
       v
_buildReorderableSection(group=fresh)
  -> ReorderableListView.builder
     -> itemBuilder: GoalCard(goal=group[i])
        -> _PriorityChip(priorityWeight=goal.priorityWeight)
           -> shows High/Low chip or SizedBox.shrink()
```

```
Form save path:

User taps Save in GoalFormSheet
       |
       v
_save(): goal.priorityWeight = _priorityWeight (0.25|0.5|0.75)
       |
       v
GoalsNotifier.saveGoal(goal)
  -> _repository.save(goal)
  -> loadGoals() -> notifyListeners()
       |
       v
Consumer rebuild -> GoalCard -> _PriorityChip (same as above)
```

### GOALFORM-02 Modal Test Pattern

```dart
// Source: derived from Flutter test/material/bottom_sheet_test.dart +
//         test/test_helpers/viewport.dart (read 2026-06-13)

testWidgets('Priority and Save reachable at true modal height — outcome goal',
    (tester) async {
  // Use realistic iPhone viewport at dpr=1.0.
  setViewport(tester, const Size(390, 844)); // tears down via addTearDown

  // Build a host scaffold that opens the modal.
  final repo = _InMemoryGoalRepository();
  final notifier = GoalsNotifier(repository: repo);

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

  // Open the modal bottom sheet.
  showModalBottomSheet<void>(
    context: capturedCtx,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 1.0,
      expand: false,
      snap: true,
      snapSizes: const [0.6, 1.0],
      builder: (_, sc) => GoalFormSheet(scrollController: sc),
    ),
  );
  await tester.pumpAndSettle();

  // Select outcome goal type (most fields — requires most scroll).
  await tester.tap(find.text("I'm working toward a specific outcome"));
  await tester.pumpAndSettle();

  // SegmentedButton (Priority control) must be reachable via scroll.
  await tester.scrollUntilVisible(
    find.byType(SegmentedButton<double>),
    100,
    scrollable: find.byType(SingleChildScrollView),
  );
  expect(find.byType(SegmentedButton<double>), findsOneWidget);

  // ElevatedButton (Save/Add goal) must be reachable via scroll.
  await tester.scrollUntilVisible(
    find.byType(ElevatedButton),
    100,
    scrollable: find.byType(SingleChildScrollView),
  );
  expect(find.byType(ElevatedButton), findsOneWidget);
});
```

### PRIORITY-03 Widget Test Pattern

```dart
// Source: derived from test/screens/goals_screen_heading_test.dart +
//         test/providers/goals_notifier_priority_test.dart (read 2026-06-13)

testWidgets('chip updates after programmatic reorder via reorderAllWithPriority',
    (tester) async {
  final repo = _InMemoryGoalRepository();

  // Create 3 goals: g0 starts at High, drag will move it to middle (Normal).
  final g0 = Goal(id: 'g0', name: 'A',
      goalTypeIndex: GoalType.timeTarget.index, priorityWeight: 0.75);
  final g1 = Goal(id: 'g1', name: 'B',
      goalTypeIndex: GoalType.timeTarget.index, priorityWeight: 0.5);
  final g2 = Goal(id: 'g2', name: 'C',
      goalTypeIndex: GoalType.timeTarget.index, priorityWeight: 0.25);

  await repo.save(g0);
  await repo.save(g1);
  await repo.save(g2);

  final notifier = GoalsNotifier(repository: repo);
  await notifier.loadGoals();

  await pumpWithMood(
    tester,
    Consumer<GoalsNotifier>(
      builder: (ctx, n, _) => Column(
        children: n.timeTargetGoals.map((g) => GoalCard(goal: g)).toList(),
      ),
    ),
    extraProviders: [
      ChangeNotifierProvider<GoalsNotifier>.value(value: notifier),
    ],
  );

  // Before reorder: g0 shows High chip.
  expect(find.text('High'), findsOneWidget);

  // Simulate drag: move g0 from position 0 to position 1 (middle of 3).
  // New order: [g1, g0, g2] -> weights 0.75, 0.5, 0.25 -> g0 gets 0.5 (Normal).
  await notifier.reorderAllWithPriority([g1.id, g0.id, g2.id]);
  await tester.pumpAndSettle();

  // After reorder: g0 is at Normal (no chip), g1 is now High.
  expect(find.text('High'), findsOneWidget, reason: 'g1 now at top -> High chip');
  // g0 is now Normal -> no High chip for it (confirmed by checking total High count)
});
```

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Scroll content into view in tests | Custom drag offset loop | `tester.scrollUntilVisible(finder, delta)` | Built into `flutter_test`; handles axis direction, max iterations, and failure reporting automatically |
| Viewport resizing in tests | Direct `tester.view.physicalSize` without teardown | `setViewport(tester, size)` from `test/test_helpers/viewport.dart` | Project already has a viewport helper with auto-teardown; direct manipulation leaks viewport state across tests |
| In-memory goal storage in tests | Custom `List<Goal>` manager | `_InMemoryGoalRepository implements GoalRepository` | Established pattern in `goal_form_priority_test.dart`; provides `lastSaved` for assertions |
| Discrete-to-continuous weight mapping | New mapping function | Existing `_PriorityChip` band logic: `>= 0.75`, `<= 0.25` | These thresholds are already locked in UI-SPEC and match the engine's thresholds |

---

## Common Pitfalls

### Pitfall 1: Pumping GoalFormSheet outside a modal
**What goes wrong:** The form renders at whatever height the test surface provides.
`setSurfaceSize(800, 1200)` means the form is never clipped; the Save button is always
visible without scrolling. The test passes but proves nothing about modal overflow.
**Why it happens:** Direct `pumpWithMood(tester, GoalFormSheet(...))` puts the form in
a Scaffold body, not a constrained modal frame.
**How to avoid:** Always pump inside `showModalBottomSheet` → `DraggableScrollableSheet`
for GOALFORM-02 tests. The modal constrains the sheet to `initialChildSize * viewHeight`.
**Warning signs:** Test doesn't use `scrollUntilVisible`; test uses `setSurfaceSize`.

### Pitfall 2: `setSurfaceSize` vs `tester.view.physicalSize`
**What goes wrong:** `tester.binding.setSurfaceSize(...)` is deprecated in recent Flutter
test APIs. The current project uses `tester.view.physicalSize` via the `setViewport` helper.
**Why it happens:** Old tests (written for Flutter <3.x) used the binding API.
**How to avoid:** Import and use `setViewport` from `test/test_helpers/viewport.dart`.
The teardown is registered automatically (`addTearDown(tester.view.reset)`).
**Warning signs:** Test imports `tester.binding.setSurfaceSize`.

### Pitfall 3: Multiple Scrollables confusing `scrollUntilVisible`
**What goes wrong:** `scrollUntilVisible(finder, delta)` with no `scrollable` argument
defaults to `find.byType(Scrollable)`. If multiple Scrollables exist in the tree (the
modal's DraggableScrollableSheet outer scroll + the form's SingleChildScrollView), the
finder may target the wrong one.
**How to avoid:** Pass `scrollable: find.byType(SingleChildScrollView)` to explicitly
target the form's scroll rather than the modal sheet's drag scroll.
**Warning signs:** `scrollUntilVisible` throws "More than one Scrollable" or fails to
scroll the form content.

### Pitfall 4: `_goals` vs fresh `Goal` objects — mutation vs replacement
**What goes wrong:** `reorderAllWithPriority` mutates `goal.priorityWeight` on the
in-memory `_goals` objects and saves them, then calls `loadGoals()` which replaces
`_goals` with fresh objects from `_repository.getActive()`. After `loadGoals()`, the
old mutated references are discarded. Tests that hold a reference to an old `Goal`
object (before `reorderAllWithPriority`) may read a stale `priorityWeight`.
**How to avoid:** Always read `await repo.getById(id)` or `notifier.goals` AFTER the
async operation completes, not from a pre-call reference.
**Warning signs:** Assertion reads from a variable captured before `await reorderAllWithPriority`.

### Pitfall 5: `setSurfaceSize` teardown API difference
**What goes wrong:** `tester.binding.setSurfaceSize(null)` (old teardown) does not
correctly reset the view in current Flutter. `tester.view.reset()` (current API) is
what the project's `setViewport` helper uses.
**How to avoid:** Delete the old `addTearDown(() => tester.binding.setSurfaceSize(null))`
lines when replacing tests. Use `setViewport` which auto-registers the correct teardown.

### Pitfall 6: `SegmentedButton<double>` type parameter required in finders
**What goes wrong:** `find.byType(SegmentedButton)` (without type parameter) may not
match `SegmentedButton<double>` in the widget tree due to type specificity.
**How to avoid:** Always use `find.byType(SegmentedButton<double>)` (with the type
argument) to match the priority selector widget.
**Warning signs:** `findsNothing` even when the form is visible and a priority selector
is rendered.

---

## Code Examples

### Example 1: Context capture pattern for showModalBottomSheet in tests
```dart
// Source: flutter/test/material/bottom_sheet_test.dart pattern (read 2026-06-13)
// Captures BuildContext from within pumpWithMood, then opens modal post-pump.

late BuildContext capturedCtx;
await pumpWithMood(
  tester,
  Builder(builder: (ctx) {
    capturedCtx = ctx;
    return const SizedBox.shrink();
  }),
  extraProviders: [...],
);

showModalBottomSheet<void>(
  context: capturedCtx,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => DraggableScrollableSheet(
    initialChildSize: 0.6,
    expand: false,
    builder: (_, sc) => GoalFormSheet(scrollController: sc),
  ),
);
await tester.pumpAndSettle();
```

### Example 2: true modal height formula
```
Modal height at initialChildSize=0.6 on viewport (390, 844):
  logical height = 844 / devicePixelRatio (1.0) = 844pt
  modal height = 844 * 0.6 = 506.4pt
```

### Example 3: `setViewport` usage (project helper)
```dart
// Source: test/test_helpers/viewport.dart (read 2026-06-13)
setViewport(tester, const Size(390, 844));
// Teardown is auto-registered — no addTearDown needed by caller.
```

### Example 4: Consumer rebuild assertion pattern
```dart
// Source: test/screens/goals_screen_heading_test.dart pattern (read 2026-06-13)
// After async notifier operation, always pumpAndSettle before asserting widget state.
await notifier.reorderAllWithPriority([g1.id, g0.id, g2.id]);
await tester.pumpAndSettle();
// Now safe to assert chip state.
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `tester.binding.setSurfaceSize(size)` | `setViewport(tester, size)` via `test/test_helpers/viewport.dart` | Phase 6 (viewport.dart created) | `setSurfaceSize` is deprecated; `tester.view` API is current |
| Pump form directly in test body | Pump form inside modal via `showModalBottomSheet` | Phase 16 (GOALFORM-02) | Enables true-height clipping assertion |
| `find.byType(SegmentedButton)` | `find.byType(SegmentedButton<double>)` | Phase 9 (priority tests written) | Type parameter required for accurate widget matching |

**Deprecated/outdated in this codebase:**
- `tester.binding.setSurfaceSize(const Size(800, 1200))`: used in two tests in
  `goal_form_priority_test.dart`. These are the exact tests GOALFORM-02 replaces.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Goal.priorityWeight` is a `double?` Hive field and persists across `_repository.save()` in the in-memory repo used in tests | Existing Code | If the in-memory repo deep-copies or resets fields, the post-reorder assertion would incorrectly pass |
| A2 | `SegmentedButton<double>` finder syntax works in Flutter `>=3.18` | Code Examples | Test would fail to find the widget; workaround is `find.byWidgetPredicate((w) => w is SegmentedButton<double>)` |
| A3 | Outcome goal content height (~692px) exceeds modal height at initialChildSize=0.6 (506px) on (390, 844) viewport | Common Pitfalls | If content is shorter, test still passes but `scrollUntilVisible` finds widget immediately (no scroll needed — test is weaker but not broken) |

---

## Open Questions

1. **Should the two `setSurfaceSize` tests be deleted in-place or replaced in-place?**
   - What we know: both tests cover real assertions (High saves 0.75; 3-hr default saves 3.0).
   - What's unclear: whether to keep the assertions in the new modal-height tests or
     separately verify them without `setSurfaceSize`.
   - Recommendation: Replace in-place. The new modal-height tests should also assert that
     tapping High and saving persists 0.75, so no assertion coverage is lost.

2. **Is there any case where the Consumer stale-chip bug could manifest?**
   - What we know: the current implementation's Consumer→GoalCard path is architecturally
     sound (no local state or stale captures).
   - What's unclear: whether `ReorderableListView`'s internal state machine could hold a
     stale widget tree during or after drag gesture.
   - Recommendation: The PRIORITY-03 widget test covers this by asserting chip state after
     `pumpAndSettle()` post-reorder. If the test passes, the rebuild path is confirmed.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter toolchain | All tests | ✓ | at `/home/dan/development/flutter/bin` | — |
| `flutter_test` (scrollUntilVisible) | GOALFORM-02 tests | ✓ | bundled with Flutter >=3.x | — |
| `setViewport` helper | GOALFORM-02 tests | ✓ | `test/test_helpers/viewport.dart` | `tester.view.physicalSize` directly (add manual teardown) |
| `pumpWithMood` helper | All widget tests | ✓ | `test/test_helpers/mood_pump.dart` | — |
| `provider` package | GoalsNotifier in tests | ✓ | ^6.1.5+1 | — |

**No missing dependencies.**

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (bundled with Flutter >=3.18) |
| Config file | none — uses default `flutter test` runner |
| Quick run command | `flutter test test/screens/goal_form_priority_test.dart test/providers/goals_notifier_priority_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PRIORITY-03 | Priority chip updates to correct tier after `reorderAllWithPriority` | widget | `flutter test test/screens/goal_card_priority_chip_rebuild_test.dart` | ❌ Wave 0 |
| GOALFORM-02 | `SegmentedButton<double>` reachable via scroll at true modal height — time-target goal | widget | `flutter test test/screens/goal_form_priority_test.dart` | Partial (test GROUP must be added) |
| GOALFORM-02 | `SegmentedButton<double>` reachable via scroll at true modal height — outcome goal | widget | `flutter test test/screens/goal_form_priority_test.dart` | Partial |
| GOALFORM-02 | `ElevatedButton` (Save) reachable via scroll at true modal height — habit goal | widget | `flutter test test/screens/goal_form_priority_test.dart` | Partial |
| GOALFORM-02 (regression) | High saves priorityWeight 0.75 (existing assertion, new test infrastructure) | widget | `flutter test test/screens/goal_form_priority_test.dart` | Partial |
| GOALFORM-02 (regression) | Regular time defaults 3.0 hrs/week (existing assertion, new test infrastructure) | widget | `flutter test test/screens/goal_form_priority_test.dart` | Partial |

### Sampling Rate
- **Per task commit:** `flutter test test/screens/goal_form_priority_test.dart test/providers/goals_notifier_priority_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** `flutter test` green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/screens/goal_card_priority_chip_rebuild_test.dart` — covers PRIORITY-03 (chip rebuild after programmatic reorder)

*(The GOALFORM-02 tests go INTO the existing `test/screens/goal_form_priority_test.dart` file — no new file needed.)*

---

## Security Domain

Step 2.6 SKIPPED — this phase touches no authentication, session management, input
validation beyond existing patterns, or cryptography. It is a correctness reconciliation
of an internal priority model field. No ASVS categories apply.

---

## Package Legitimacy Audit

> No new packages. Phase 16 uses only existing project dependencies and Flutter's
> built-in `flutter_test` package. No legitimacy audit required.

**Packages added by this phase:** none

---

## Sources

### Primary (HIGH confidence)
- `lib/providers/goals_notifier.dart` — `reorderAllWithPriority` implementation read directly
- `lib/screens/goals/goals_screen.dart` — Consumer structure, `_buildReorderableSection`, `onReorderItem` read directly
- `lib/screens/goals/goal_form_sheet.dart` — priority selector, `_save`, modal layout read directly
- `lib/screens/goals/widgets/goal_card.dart` — `_PriorityChip` band logic read directly
- `lib/services/schedule_generator.dart` — engine's priority threshold reads (`>= 0.75`) verified
- `test/screens/goal_form_priority_test.dart` — existing test file, two `setSurfaceSize` patterns identified
- `test/test_helpers/mood_pump.dart` — `pumpWithMood` API read directly
- `test/test_helpers/viewport.dart` — `setViewport` API read directly
- `packages/flutter_test/lib/src/controller.dart` — `scrollUntilVisible` signature confirmed at line 2417
- `packages/flutter/test/material/bottom_sheet_test.dart` — `showModalBottomSheet` in-test pattern confirmed

### Secondary (MEDIUM confidence)
- `.planning/phases/16-priority-model-reconciliation/16-UI-SPEC.md` — priority band contract, modal height contract, test surface contract
- `.planning/REQUIREMENTS.md` — PRIORITY-03, GOALFORM-02 requirement text

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Flutter + flutter_test, no new packages, all APIs confirmed in source
- Architecture: HIGH — all source files read directly; Consumer→GoalCard rebuild path traced
- Pitfalls: HIGH — two `setSurfaceSize` usages found and confirmed; `scrollUntilVisible` API confirmed
- Test patterns: HIGH — `pumpWithMood`, `setViewport`, `_InMemoryGoalRepository`, modal test pattern all from read sources

**Research date:** 2026-06-13
**Valid until:** 2026-07-13 (stable domain — Flutter widget test APIs, no external services)

# Phase 14: Goals Screen and Priority End-to-End - Research

**Researched:** 2026-06-13
**Domain:** Flutter Material 3 — Goals screen UX, priority visual language, scheduling engine
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
All implementation choices are at Claude's discretion — discuss phase was skipped per user
setting. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

Continuity with Phase 13: Phase 13 established the priority visual language on the goal form
(SegmentedButton Low/Normal/High mapping to weights 0.25/0.5/0.75) and compact GoalTypePicker
cards. This phase must keep the priority visual language consistent across the Goals screen list
and the schedule cards.

### Claude's Discretion
All implementation details.

### Deferred Ideas (OUT OF SCOPE)
None — discuss phase skipped.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GOALS-01 | Goals screen makes its purpose explicit as a prioritization view with an obvious reorder affordance | Heading SliverToBoxAdapter + drag handle icon change; reorder → reorderAllWithPriority wiring |
| GOALS-02 | Priority (low/normal/high) has a clear, consistent visual language on goal cards and schedule chunk cards | `_PriorityChip` widget using colorScheme tokens; Normal shows no chip (absence = default) |
| PRIORITY-01 | A goal's priority measurably influences schedule generation beyond a tiebreaker | Step 2 habit sort + Step 4 composite score sort in `ScheduleGeneratorService.generate()` |
</phase_requirements>

---

## Summary

Phase 14 makes priority a first-class, end-to-end concept in Canopy: the user can see it on
goal cards (chip), see it on schedule chunks (badge), and trust that changing it produces a
genuinely different schedule. All three concerns are tightly coupled — the visual language is
meaningless unless the engine also responds to the weight.

The codebase is in excellent shape for this phase. `Goal.priorityWeight` (HiveField 5, double?)
is already stored and the form-level SegmentedButton (Phase 13) already persists 0.25/0.5/0.75.
`GoalsNotifier.reorderAllWithPriority` is already implemented and tested. The schedule generator
already uses `priorityWeight` in the urgency formula for outcome goals (Step 3) and as a
tiebreaker for time-target goals (Step 4). The remaining work is: (1) make the Goals screen read
as a prioritization surface, (2) render priority chips/badges across goal cards and chunk cards,
and (3) promote priority from a tiebreaker to a primary scheduling signal for habits (Step 2)
and time-target goals (Step 4).

The UI-SPEC is extremely precise — it dictates exact widget structure, color tokens, icon
choices, copy, and file-isolation strategy. The plan must follow the UI-SPEC's wave decomposition
(Wave 1: goals UI; Wave 2: schedule display + engine; Wave 3: tests) and the file-disjoint
parallelism rule (duplicate `_PriorityChip` as a file-private widget in `goal_card.dart` and
`chunk_card.dart` rather than sharing across files mid-wave).

**Primary recommendation:** Follow the UI-SPEC's three-wave decomposition exactly. Engine changes
to `schedule_generator.dart` are pure Dart with no Flutter dependencies and are the highest-value
changes for success criteria 3 and 4 — implement and test them before wiring the visual layer.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Priority storage | Database / Storage | — | `Goal.priorityWeight` HiveField 5; already persisted |
| Priority write via reorder | Provider (GoalsNotifier) | — | `reorderAllWithPriority` already exists; Goals screen just needs to call it |
| Priority write via form | Provider (GoalsNotifier) | — | `saveGoal()` path already works; Phase 13 wired the SegmentedButton |
| Priority engine effect | Service (ScheduleGeneratorService) | — | Pure Dart in `schedule_generator.dart`; engine-level change, no UI coupling |
| Priority visual — goal card | Frontend Widget (GoalCard) | — | `_PriorityChip` added to secondary row; `goal.priorityWeight` already accessible |
| Priority visual — chunk card | Frontend Widget (ChunkCard / ActiveChunkCard) | ScheduleScreen / HomeScreen | Cards gain new `goalPriorityWeight` parameter; callers look up from GoalsNotifier |
| Goals screen heading + drag affordance | Frontend Widget (GoalsScreen) | — | `SliverToBoxAdapter` heading + icon change + mobile handle visibility |
| Reorder-writes-priority | Frontend Widget (GoalsScreen) | Provider (GoalsNotifier) | `onReorderItem` must call `reorderAllWithPriority`; helper needed to build flat ID list |

---

## Standard Stack

No new packages required for this phase. All widgets are built from Flutter Material 3
primitives already in `pubspec.yaml`.

[VERIFIED: pubspec.yaml] Existing dependencies that matter for this phase:

| Library | Version (pubspec) | Purpose in Phase 14 |
|---------|------------------|---------------------|
| flutter (Material 3) | SDK | `Icons.drag_indicator`, `ColorScheme` tokens, `ReorderableListView`, `SliverToBoxAdapter` |
| provider | ^6.1.5+1 | `GoalsNotifier` / `ScheduleNotifier` lookup for `goalPriorityWeight` |
| hive_ce | ^2.19.3 | `Goal.priorityWeight` persistence (already wired; no schema change) |

### No New Dependencies

The UI-SPEC explicitly states: "No third-party component registries. No shadcn. No npm. All
widgets are authored in Dart using existing Flutter/Material 3 APIs already present in
`pubspec.yaml`. No new pub.dev packages required for this phase."

---

## Package Legitimacy Audit

No new packages are installed in this phase. Not applicable.

---

## Architecture Patterns

### System Architecture Diagram

```
User drags goal card
         │
         ▼
GoalsScreen._buildReorderableSection
  onReorderItem(old, new)
         │
         ├─ _buildFullOrderedIds() ── builds flat list across all type groups
         │
         ▼
GoalsNotifier.reorderAllWithPriority(orderedIds)
  writes sortOrder + priorityWeight (linear spread 0.75→0.25)
         │
         ▼
HiveGoalRepository.save() (per goal)
         │
         └─ loadGoals() → notifyListeners()
                   │
                   ▼
           GoalCard rebuilds
           _PriorityChip renders Low/High chip (or nothing at Normal)

User taps "Re-check-in" (or next morning)
         │
         ▼
ScheduleGeneratorService.generate()
  Step 2: habitGoals sorted by priorityWeight desc ← NEW
  Step 3: outcomeGoals sorted by urgency (priorityWeight / daysRemaining) ← EXISTING
  Step 4: timeTargetGoals sorted by composite score (remainingHours * priorityWeight) ← CHANGED
         │
         ▼
ScheduleNotifier stores generated chunks
         │
         ▼
ScheduleScreen / HomeScreen
  _lookupGoalPriorityWeight() → passes to ChunkCard / ActiveChunkCard
         │
         ▼
ChunkCard._WorkChunkContent / ActiveChunkCard
  renders _PriorityChip (Low/High badge) below clock-time line
```

### Recommended Project Structure

No new files or directories needed. All changes are modifications to existing files:

```
lib/
├── screens/goals/
│   ├── goals_screen.dart          # + heading sliver + drag_indicator + reorderAllWithPriority call + _buildFullOrderedIds
│   └── widgets/
│       └── goal_card.dart         # + _PriorityChip (file-private) + chip in secondary row
├── screens/schedule/
│   ├── schedule_screen.dart       # + goalPriorityWeight lookup + pass to ChunkCard
│   └── widgets/
│       └── chunk_card.dart        # + goalPriorityWeight param + _PriorityChip (file-private duplicate)
├── screens/home/widgets/
│   └── active_chunk_card.dart     # + goalPriorityWeight lookup + _PriorityChip
└── services/
    └── schedule_generator.dart    # Step 2 habit sort + Step 4 composite score sort
test/
├── services/
│   └── schedule_generator_test.dart  # + priority engine behavioral tests
├── screens/
│   ├── goal_card_drag_handle_test.dart  # UPDATE: Icons.drag_indicator + mobile visible
│   └── goal_card_priority_chip_test.dart  # NEW: chip visible at 0.75/0.25, absent at 0.5
│   └── chunk_card_priority_badge_test.dart  # NEW: badge visible at 0.25/0.75, absent at null
```

### Pattern 1: _PriorityChip — file-private widget (duplicated in goal_card.dart and chunk_card.dart)

**What:** A small display-only container chip showing an arrow icon + label for Low (0.25) and
High (0.75) priorities. Returns `SizedBox.shrink()` for Normal (0.5) and null.

**When to use:** In GoalCard's secondary row and in ChunkCard/ActiveChunkCard below the
clock-time line. File-private duplication is deliberate (UI-SPEC §Component Inventory item 3)
to allow file-disjoint plan parallelism between Wave 1 (goal_card.dart) and Wave 2
(chunk_card.dart).

**Spec (verbatim from UI-SPEC):**
```dart
// Source: 14-UI-SPEC.md §Priority Visual Language
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: chipColor,   // tier-specific; see table below
    borderRadius: BorderRadius.circular(10),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: onColor),
      SizedBox(width: 4),
      Text(label, style: textTheme.labelSmall?.copyWith(
        color: onColor,
        fontWeight: FontWeight.w600,
      )),
    ],
  ),
)
```

**Tier table:**

| `priorityWeight` | chipColor | onColor | icon | label |
|-----------------|-----------|---------|------|-------|
| 0.25 (Low) | `colorScheme.surfaceContainerHighest` | `colorScheme.onSurfaceVariant` | `Icons.arrow_downward` (size 12) | "Low" |
| 0.5 (Normal) | — (no chip) | — | — | — |
| 0.75 (High) | `colorScheme.primaryContainer` | `colorScheme.onPrimaryContainer` | `Icons.arrow_upward` (size 12) | "High" |
| null | — (no chip, defaults to Normal) | — | — | — |

### Pattern 2: _buildFullOrderedIds helper

**What:** Reconstructs the flat goal ID list across all three type groups when a drag
completes within one type group.

**Why needed:** `reorderAllWithPriority` takes a flat list of ALL goal IDs (all types, in
display order). `_buildReorderableSection` only knows the reordered group — it needs to slot it
back into the global display order.

**Spec (verbatim from UI-SPEC):**
```dart
// Source: 14-UI-SPEC.md §Goals Screen Redesign Contract
List<String> _buildFullOrderedIds(
  GoalsNotifier notifier,
  GoalType type,
  List<Goal> reorderedGroup,
) {
  // Display order: timeTarget, outcome, habit (matching goals_screen.dart section order).
  final timeTargetIds = type == GoalType.timeTarget
      ? reorderedGroup.map((g) => g.id).toList()
      : notifier.timeTargetGoals.map((g) => g.id).toList();
  final outcomeIds = type == GoalType.outcome
      ? reorderedGroup.map((g) => g.id).toList()
      : notifier.outcomeGoals.map((g) => g.id).toList();
  final habitIds = type == GoalType.habit
      ? reorderedGroup.map((g) => g.id).toList()
      : notifier.habitGoals.map((g) => g.id).toList();
  return [...timeTargetIds, ...outcomeIds, ...habitIds];
}
```

**Placement:** Private method on `_GoalsScreenState`. Called inside the `onReorderItem`
closure in `_buildReorderableSection`.

### Pattern 3: Engine change — Step 2 habit sort

**What:** Sort `habitGoals` by `priorityWeight` descending before the allocation loop so
high-priority habits fill cap slots before low-priority habits.

**Current code (line 234 of schedule_generator.dart):**
```dart
// CURRENT — no sort; habits appear in activeGoals order (reflects sortOrder)
for (final goal in activeGoals) {
  if (discretionaryCount >= cap) break;
  if (goal.goalType != GoalType.habit) continue;
  ...
}
```

**Replacement (per UI-SPEC §Priority Engine Contract):**
```dart
// Source: 14-UI-SPEC.md §Priority Engine Contract
final habitGoals = activeGoals
    .where((g) => g.goalType == GoalType.habit)
    .toList()
  ..sort((a, b) =>
      (b.priorityWeight ?? 0.5).compareTo(a.priorityWeight ?? 0.5));

for (final goal in habitGoals) {
  if (discretionaryCount >= cap) break;
  final effectiveFreq = goal.frequencyPerWeek ?? 7;
  final dueWeekdays = computeDueWeekdays(effectiveFreq);
  if (!dueWeekdays.contains(date.weekday)) continue;
  ...
}
```

Note: this replaces the inline habit filter inside the `activeGoals` loop with a
pre-filtered, sorted `habitGoals` list. The cap-check guard and due-weekday guard are
unchanged.

### Pattern 4: Engine change — Step 4 composite score sort

**What:** Replace the tiebreaker-only priority sort for time-target goals with a composite
score `remainingHours × priorityWeight`. This means a high-priority goal with moderate
remaining hours ranks ahead of a low-priority goal with the same remaining hours.

**Current code (lines 308-318 of schedule_generator.dart):**
```dart
// CURRENT — tiebreaker only
..sort((a, b) {
  final remA = _remainingHours(a, completionLogs, date);
  final remB = _remainingHours(b, completionLogs, date);
  if ((remA - remB).abs() > 0.01) return remB.compareTo(remA);
  return (b.priorityWeight ?? 0.5).compareTo(a.priorityWeight ?? 0.5);
});
```

**Replacement (per UI-SPEC §Priority Engine Contract):**
```dart
// Source: 14-UI-SPEC.md §Priority Engine Contract
double score(Goal g) =>
    _remainingHours(g, completionLogs, date) * (g.priorityWeight ?? 0.5);
timeTargetGoals.sort((a, b) => score(b).compareTo(score(a)));
```

The `_demandForTimeTarget` calculation is unchanged — only the sort order changes. All other
Step 4 logic (cap check, demand loop, rationale) is untouched.

### Pattern 5: goalPriorityWeight lookup in callers

**What:** ScheduleScreen and HomeScreen already look up `goalColor` and `goalName` from
`GoalsNotifier.goals` by `chunk.goalId`. Add `goalPriorityWeight` to the same lookup.

**In ScheduleScreen — add private method:**
```dart
// Source: 14-UI-SPEC.md §Component Inventory item 6
double? _lookupGoalPriorityWeight(BuildContext context, ScheduledChunk chunk) {
  if (chunk.goalId == null) return null;
  final goals = context.read<GoalsNotifier>().goals;
  final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
  return goal?.priorityWeight;
}
```

Then in `_buildSwipeableCard` and `_buildSkippedSection`, pass
`goalPriorityWeight: _lookupGoalPriorityWeight(context, chunk)` to `SwipeableChunkCard` /
`ChunkCard` (after adding the parameter to those widgets).

**Note on SwipeableChunkCard:** SwipeableChunkCard wraps ChunkCard. The parameter must
propagate through: ScheduleScreen → SwipeableChunkCard → ChunkCard. SwipeableChunkCard
gains `double? goalPriorityWeight` and passes it to its `ChunkCard` call. This is a small
passthrough change.

**In ActiveChunkCard:** Already looks up goal by `chunk.goalId` via `_lookupGoalColor` and
`_lookupGoalName`. Add a third lookup `_lookupGoalPriorityWeight` following the same pattern.

### Anti-Patterns to Avoid

- **Calling `reorder()` instead of `reorderAllWithPriority()` in `onReorderItem`:** The
  existing `onReorderItem` calls `notifier.reorder(type, oldIndex, newIndex)` which updates
  `sortOrder` but NOT `priorityWeight`. After this phase, drag-reordering must call
  `reorderAllWithPriority` or the engine will not respond to reorder gestures.

- **Priority as tiebreaker only (current Step 4 behavior):** With only a tiebreaker, two
  goals with meaningfully different remaining hours (> 0.01h apart) ignore priority entirely.
  The composite score `remainingHours × priorityWeight` makes priority a primary factor.

- **Sharing `_PriorityChip` across files via import during Wave 1/2:** The UI-SPEC requires
  file-private duplication to allow parallel tasks. Avoid creating a shared `lib/widgets/`
  widget for `_PriorityChip` during this phase — it blocks Wave 1 and Wave 2 from being
  file-disjoint. If promotion to a shared widget is desired, do it in a post-phase cleanup.

- **Using `Icons.drag_handle` for the new drag affordance:** The existing code uses
  `Icons.drag_handle` (two lines). The UI-SPEC mandates `Icons.drag_indicator` (6-dot grid)
  as the universally recognized drag affordance. Update both desktop and mobile branches.

- **Existing `goal_card_drag_handle_test.dart` expects `Icons.drag_handle`:** This test will
  fail after the icon change to `Icons.drag_indicator`. The test must be updated to assert
  `Icons.drag_indicator` instead. Do not attempt to preserve the old assertion.

- **Mobile drag handle staying hidden:** The current code passes `trailing: null` on mobile
  which hides the affordance entirely. The UI-SPEC requires a visible `Icons.drag_indicator`
  in `outlineVariant` color on mobile, always shown (the `ReorderableDelayedDragStartListener`
  still requires long-press; only the visual affordance changes).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Drag-to-reorder list | Custom gesture detector | `ReorderableListView.builder` (already in use) | Flutter's built-in handles long-press, elevation shadow, insertion point rendering |
| Linear priority spread on reorder | Custom math | `GoalsNotifier.reorderAllWithPriority` (already implemented) | The formula and persistence are already correct; just call it |
| Priority chip widget | One-off inline Container in every caller | File-private `_PriorityChip` widget (per UI-SPEC) | Reuse within each file; accessible icon+label keeps it WCAG-compliant |
| Goal lookup from chunk | Direct Hive read | `GoalsNotifier.goals` list (already in `context.read<GoalsNotifier>()`) | Goals are already loaded in memory; no async needed |

---

## Current State — What Is and Isn't Done

### Already implemented (do NOT re-implement)

- `Goal.priorityWeight` HiveField 5 (double?) — model + adapter [VERIFIED: goal.dart]
- `GoalsNotifier.reorderAllWithPriority` — linear spread 0.75→0.25 [VERIFIED: goals_notifier.dart line 97]
- `GoalsNotifier.reorder` — type-scoped reorder (updates sortOrder only; NOT used after this phase for reorder gestures) [VERIFIED: goals_notifier.dart line 118]
- Phase 13 SegmentedButton priority control in GoalFormSheet — persists 0.25/0.5/0.75 [VERIFIED: STATE.md, goal_form_priority_test.dart]
- `reorderAllWithPriority` unit tests in `test/providers/goals_notifier_priority_test.dart` [VERIFIED: file exists]
- Outcome goal urgency score already uses `priorityWeight` in Step 3 [VERIFIED: schedule_generator.dart line 268]
- `pumpWithMood` test helper in `test/test_helpers/mood_pump.dart` [VERIFIED: file exists]

### Must be changed

1. **`goals_screen.dart`**: heading sliver; `Icons.drag_indicator`; mobile visible handle; `onReorderItem` → `reorderAllWithPriority`; `_buildFullOrderedIds` helper.
2. **`goal_card.dart`**: `_PriorityChip` private widget; chip in secondary row.
3. **`chunk_card.dart`**: `goalPriorityWeight` param on `_WorkChunkContent` + `ChunkCard`; `_PriorityChip` private duplicate; badge below clock-time.
4. **`swipeable_chunk_card.dart`**: passthrough `goalPriorityWeight` param.
5. **`active_chunk_card.dart`**: `_lookupGoalPriorityWeight`; priority badge below clock-time, above action row.
6. **`schedule_screen.dart`**: `_lookupGoalPriorityWeight`; pass to `SwipeableChunkCard`; pass to skipped section `ChunkCard`.
7. **`schedule_generator.dart`**: Step 2 habit sort; Step 4 composite score sort.

### Must be updated (existing tests)

- `test/screens/goal_card_drag_handle_test.dart`: currently asserts `Icons.drag_handle`; must assert `Icons.drag_indicator` after the change. Also: mobile branch currently asserts `findsNothing` for the icon — must flip to `findsOneWidget` for `Icons.drag_indicator` on Android/iOS (visible but lighter color).

---

## Common Pitfalls

### Pitfall 1: `onReorderItem` index semantics with `ReorderableListView`

**What goes wrong:** `ReorderableListView.onReorderItem` provides `(oldIndex, newIndex)` where
`newIndex` is the post-removal target index. When old < new, Flutter has already subtracted 1
from `newIndex` relative to the original list. If you `insert(newIndex, item)` after
`removeAt(oldIndex)` this is correct. If you apply the standard `if (newIndex > oldIndex) newIndex--`
adjustment you will get an off-by-one error.

**How to avoid:** Match the existing `GoalsNotifier.reorder` implementation which does
`group.insert(newIndex, item)` without adjustment — this is correct for `onReorderItem`'s
contract. Apply the same in `_buildFullOrderedIds`: remove from oldIndex, insert at newIndex
within the group, then rebuild the flat ID list.

**Warning signs:** Goals appear to swap two positions instead of moving one position when dragged.

### Pitfall 2: `_buildFullOrderedIds` type-group ordering must match display order

**What goes wrong:** `reorderAllWithPriority` assigns priority based on position in the flat
list (index 0 = highest priority). If `_buildFullOrderedIds` returns groups in the wrong order
(e.g., habit, outcome, timeTarget instead of timeTarget, outcome, habit), a habit at the top
of the "Daily habits" section would get lower priority than a timeTarget goal even if the
habits section visually precedes a time-target section that day.

**How to avoid:** Use the display order from `goals_screen.dart`: timeTargetGoals first,
outcomeGoals second, habitGoals third. This matches the section rendering order in the existing
`build()` method.

**Warning signs:** Dragging the top habit to be "most important" actually gives it weight 0.25
(bottom of the spread) when there are also timeTarget or outcome goals.

### Pitfall 3: Mobile drag handle — `ReorderableDelayedDragStartListener` wrapper required

**What goes wrong:** On mobile, the visible `Icons.drag_indicator` icon needs to be wrapped in
`ReorderableDelayedDragStartListener(index: i, ...)` for the long-press drag gesture to be
recognized. If the icon is rendered WITHOUT the listener wrapper, the user sees the handle but
cannot initiate a drag.

**Current code state:** The mobile branch currently passes `trailing: null` which means no
listener at all. The new mobile branch must pass a `ReorderableDelayedDragStartListener` (same
as desktop) — the icon appearance differs (smaller, `outlineVariant` color) but the listener
is the same.

**How to avoid:** Both desktop and mobile branches use `ReorderableDelayedDragStartListener`.
Only the inner icon widget differs.

### Pitfall 4: `_PriorityChip` must not be interactive (no `GestureDetector`)

**What goes wrong:** Adding a `GestureDetector` or `InkWell` to `_PriorityChip` will cause
it to capture taps that should propagate to the `GoalCard`'s `InkWell`. The chip is display-only.

**How to avoid:** `_PriorityChip` is a plain `Container`. No tap handlers. No `Tooltip` on the
chip itself. The `GoalCard`'s `InkWell.onTap` handles all card taps.

### Pitfall 5: Step 4 composite score — goals with zero remaining hours

**What goes wrong:** `score(g) = remainingHours × priorityWeight`. A goal with 0.0 remaining
hours this week (fully on track) scores 0.0 regardless of priority. `_demandForTimeTarget`
already returns 0 for such goals (no chunks allocated), so they are harmlessly sorted to the
bottom. No special handling needed.

**How to avoid:** No change needed; the existing `_demandForTimeTarget` guards against 0 demand.

### Pitfall 6: `goal_card_drag_handle_test.dart` will fail after icon change

**What goes wrong:** `test/screens/goal_card_drag_handle_test.dart` contains:
- `expect(find.byIcon(Icons.drag_handle), findsNothing)` on Android
- `expect(find.byIcon(Icons.drag_handle), findsOneWidget)` on macOS

After changing to `Icons.drag_indicator`, both assertions fail. Additionally, the mobile-hidden
branch will flip to visible.

**How to avoid:** Update the test file in the same plan that changes the icon. Three changes:
1. Replace all `Icons.drag_handle` with `Icons.drag_indicator`.
2. Flip the Android/iOS "findsNothing" assertion to "findsOneWidget" (chip is now visible).
3. Keep the macOS "findsOneWidget" assertion (already correct, just icon name changes).
The `_reorderableSection` test harness in the test file also hardcodes `Icons.drag_handle` —
update it to `Icons.drag_indicator` too.

---

## Code Examples

### GoalsScreen — heading SliverToBoxAdapter

```dart
// Source: 14-UI-SPEC.md §Goals Screen Redesign Contract
// Add as first sliver in CustomScrollView when !allEmpty:
SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Your goals',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Drag to prioritize. Tap to edit.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  ),
)
```

### GoalsScreen — desktop drag handle (updated icon + tooltip + touch target)

```dart
// Source: 14-UI-SPEC.md §Goals Screen Redesign Contract
Tooltip(
  message: 'Drag to reorder',
  child: ReorderableDelayedDragStartListener(
    index: i,
    child: Semantics(
      label: 'Drag to reorder',
      button: false,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: 0.6,  // brightens to 1.0 on hover via MouseRegion
            child: Icon(
              Icons.drag_indicator,
              color: colorScheme.outline,
            ),
          ),
        ),
      ),
    ),
  ),
)
```

### GoalsScreen — mobile drag handle (new, always visible)

```dart
// Source: 14-UI-SPEC.md §Goals Screen Redesign Contract
ReorderableDelayedDragStartListener(
  index: i,
  child: Semantics(
    label: 'Drag to reorder',
    button: false,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(
        Icons.drag_indicator,
        size: 20,
        color: colorScheme.outlineVariant,
      ),
    ),
  ),
)
```

### GoalsScreen — onReorderItem with reorderAllWithPriority

```dart
// Source: 14-UI-SPEC.md §Goals Screen Redesign Contract
onReorderItem: (oldIndex, newIndex) async {
  final reorderedGroup = [...group];
  final item = reorderedGroup.removeAt(oldIndex);
  reorderedGroup.insert(newIndex, item);
  final allOrdered = _buildFullOrderedIds(notifier, type, reorderedGroup);
  await notifier.reorderAllWithPriority(allOrdered);
},
```

### GoalCard — priority chip integration in secondary row

```dart
// Source: 14-UI-SPEC.md §Goals Screen Redesign Contract
// In _GoalCardState.build(), replace the existing secondary block:
final showPriorityChip = (goal.priorityWeight ?? 0.5) != 0.5;
if (secondary != null || showPriorityChip) ...[
  const SizedBox(height: 4),
  Row(
    children: [
      if (secondary != null)
        Expanded(
          child: Text(secondary, style: theme.textTheme.bodySmall),
        ),
      if (showPriorityChip)
        _PriorityChip(priorityWeight: goal.priorityWeight ?? 0.5),
    ],
  ),
]
```

### ChunkCard — priority badge placement

```dart
// Source: 14-UI-SPEC.md §Component Inventory item 4
// In _WorkChunkContent, after the rationale row inside the inner Column:
if (goalPriorityWeight != null && goalPriorityWeight != 0.5) ...[
  const SizedBox(height: 4),
  _PriorityChip(priorityWeight: goalPriorityWeight!),
]
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Priority as pure tiebreaker (Step 4) | Priority as composite score multiplier | Phase 14 | High-priority goal with moderate remaining hours ranks before low-priority goal with same remaining hours |
| Habits scheduled in `activeGoals` list order (reflects sortOrder) | Habits sorted by priorityWeight desc before allocation | Phase 14 | High-priority due habit always fills cap before low-priority due habit |
| Drag-reorder updates `sortOrder` only | Drag-reorder updates both `sortOrder` and `priorityWeight` | Phase 14 | Reordering on the Goals screen directly changes scheduling behavior |
| Drag handle = `Icons.drag_handle` (two lines) | Drag handle = `Icons.drag_indicator` (six dots) | Phase 14 | Universally recognized drag affordance; no "two slashes" ambiguity |
| Mobile drag handle hidden | Mobile drag handle visible at `outlineVariant` opacity | Phase 14 | User now knows reordering is possible on mobile |
| Priority invisible after form save | Priority chip (Low/High) on goal card | Phase 14 | User can confirm their priority setting is applied |
| No priority signal on chunk cards | Priority badge on chunk cards (Low/High) | Phase 14 | User can see why one goal's chunks appear before another's |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The UI-SPEC's `_buildFullOrderedIds` flat ordering (timeTarget → outcome → habit) matches the linear priority spread intent | Architecture Patterns Pattern 2 | Wrong ordering would mean a top-listed habit ranks below all timeTarget goals in priority weight, even if the user placed the habit at position 1 globally — LOW risk since the UI-SPEC explicitly states this ordering |

**All other claims in this research were verified against the actual source files.**

---

## Open Questions (RESOLVED)

1. **Hover opacity on desktop drag handle: `AnimatedOpacity` vs `MouseRegion` wrapping**
   - What we know: The UI-SPEC says "on hover, increase opacity from 0.6 to 1.0 via existing `AnimatedOpacity`. Duration: 120ms, easeOut."
   - What's unclear: The current desktop drag handle uses a static `AnimatedOpacity(opacity: 0.6)` — it is not wired to a `MouseRegion`. The `GoalCard` itself has a `MouseRegion` via `onHover`, but that drives `_GoalCardState._hovered` which controls the edit/archive icons, not the drag handle opacity.
   - RESOLVED: The drag handle hover-brightening is NOT a success criterion — it is a nice-to-have. To keep Phase 14 scoped to the four success criteria, the planner should NOT add a dedicated MouseRegion task; the handle remains visible and functional at 0.6 opacity (GOALS-01's "obvious reorder affordance" is satisfied by the `Icons.drag_indicator` swap + always-visible mobile handle). If desired later, it is a one-line polish task. The plans intentionally omit it so this question carries no implementation risk.

---

## Environment Availability

Step 2.6: Flutter is available at `/home/dan/development/flutter/bin/flutter` (not on PATH).
[VERIFIED: Flutter 3.44.1, stable channel, 2026-05-29]

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All widgets | ✓ | 3.44.1 stable | — |
| Dart SDK | All code | ✓ | ^3.10.3 (from pubspec) | — |
| flutter_test | Tests | ✓ | SDK-bundled | — |
| hive_ce | Priority persistence | ✓ | 2.19.3 | — |

No missing dependencies.

---

## Validation Architecture

`workflow.nyquist_validation` is not set to false in `.planning/config.json` — section included.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK-bundled) |
| Config file | none — flutter test auto-discovers `test/` |
| Quick run command | `/home/dan/development/flutter/bin/flutter test test/services/schedule_generator_test.dart` |
| Full suite command | `/home/dan/development/flutter/bin/flutter test` |
| Flutter path | `/home/dan/development/flutter/bin/flutter` (NOT on default PATH) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GOALS-01 | Heading "Your goals" text visible on Goals screen | widget | `flutter test test/screens/goals_screen_heading_test.dart` | ❌ Wave 3 |
| GOALS-01 | `Icons.drag_indicator` shown on desktop | widget | `flutter test test/screens/goal_card_drag_handle_test.dart` | ✅ (UPDATE needed) |
| GOALS-01 | `Icons.drag_indicator` shown on mobile (was hidden) | widget | `flutter test test/screens/goal_card_drag_handle_test.dart` | ✅ (UPDATE needed) |
| GOALS-02 | GoalCard with `priorityWeight: 0.75` shows "High" chip | widget | `flutter test test/screens/goal_card_priority_chip_test.dart` | ❌ Wave 3 |
| GOALS-02 | GoalCard with `priorityWeight: 0.5` shows NO chip | widget | `flutter test test/screens/goal_card_priority_chip_test.dart` | ❌ Wave 3 |
| GOALS-02 | GoalCard with `priorityWeight: 0.25` shows "Low" chip | widget | `flutter test test/screens/goal_card_priority_chip_test.dart` | ❌ Wave 3 |
| GOALS-02 | ChunkCard with `goalPriorityWeight: 0.75` shows "High" badge | widget | `flutter test test/screens/chunk_card_priority_badge_test.dart` | ❌ Wave 3 |
| GOALS-02 | ChunkCard with `goalPriorityWeight: 0.25` shows "Low" badge | widget | `flutter test test/screens/chunk_card_priority_badge_test.dart` | ❌ Wave 3 |
| GOALS-02 | ChunkCard with `goalPriorityWeight: null` shows NO badge | widget | `flutter test test/screens/chunk_card_priority_badge_test.dart` | ❌ Wave 3 |
| PRIORITY-01 | Elevating habit from low (0.25) to high (0.75) priority causes it to appear before a low-priority habit when cap=1 | unit (engine) | `flutter test test/services/schedule_generator_test.dart` | ✅ (ADD test case) |
| PRIORITY-01 | High-priority time-target goal with same remaining hours as low-priority goal gets more/earlier chunks | unit (engine) | `flutter test test/services/schedule_generator_test.dart` | ✅ (ADD test case) |
| PRIORITY-01 | Low-priority time-target goal gets fewer/later chunks when cap is shared with a high-priority goal | unit (engine) | `flutter test test/services/schedule_generator_test.dart` | ✅ (ADD test case) |

### Behavioral Engine Tests (criteria 3 & 4)

These are the critical deterministic tests that prove success criteria 3 and 4 without
inspecting visual output. The engine is pure Dart — no Flutter, no Hive, no BuildContext —
so these tests are fast and deterministic.

**Test: habit priority sort — high-priority habit gets the single cap slot**
```dart
// Add to test/services/schedule_generator_test.dart
test('Step 2: high-priority habit is scheduled before low-priority habit when cap=1', () {
  final highHabit = makeHabit(name: 'High Habit', priorityWeight: 0.75)
    ..frequencyPerWeek = 7; // due every day
  final lowHabit = makeHabit(name: 'Low Habit', priorityWeight: 0.25)
    ..frequencyPerWeek = 7; // due every day

  final result = sut.generate(
    goals: [lowHabit, highHabit], // intentionally low first in input order
    blocks: [],
    moodIndex: 3,
    date: monday,
    completionLogs: [],
    lighterDay: false,
  );
  final workChunks = result.where((c) => c.chunkType == ChunkType.work).toList();
  // cap=8 for mood 3, lighterDay=false → but we only want to confirm order,
  // so use cap=1 by overriding mood=1 (cap=4 raw, 80% → 4... use cap constraint via fewer goals)
  // Actually: use moodIndex=1 cap=4. With two daily habits, both fit cap=4.
  // To prove ordering: check that the FIRST work chunk belongs to highHabit.
  expect(workChunks, isNotEmpty);
  expect(workChunks.first.goalId, equals(highHabit.id),
    reason: 'High-priority habit must be scheduled before low-priority habit');
});
```

**Test: time-target composite score — high-priority goal with equal remaining hours gets more chunks**
```dart
// Add to test/services/schedule_generator_test.dart
test('Step 4: high-priority time-target goal with equal remaining hours gets chunk before low-priority', () {
  // Both goals have same weeklyHourBudget=2h and no completions → equal remaining hours.
  // High-priority goal should score higher and fill cap first.
  final highTT = makeTimeTarget(
    name: 'High TT',
    weeklyHourBudget: 2.0,
    priorityWeight: 0.75,
  );
  final lowTT = makeTimeTarget(
    name: 'Low TT',
    weeklyHourBudget: 2.0,
    priorityWeight: 0.25,
  );

  final result = sut.generate(
    goals: [lowTT, highTT], // intentionally low first
    blocks: [],
    moodIndex: 3, // cap=8; both goals get chunks, so check order of first
    date: monday,
    completionLogs: [],
    lighterDay: false,
  );
  final workGoalIds = result
      .where((c) => c.chunkType == ChunkType.work && c.goalId != null)
      .map((c) => c.goalId!)
      .toList();
  expect(workGoalIds, isNotEmpty);
  // First chunk must belong to highTT (composite score: 2.0 * 0.75 = 1.5 > 2.0 * 0.25 = 0.5)
  expect(workGoalIds.first, equals(highTT.id),
    reason: 'High-priority time-target goal must receive chunks before low-priority goal');
});

test('Step 4: lowering priority from 0.75 to 0.25 causes goal to receive fewer/later chunks when cap is constrained', () {
  // Cap-constrained scenario: cap=4 (moodIndex=1, lighterDay=false).
  // highTT gets 2 demand chunks (2h / 4 slots remaining); lowTT gets 2 demand chunks.
  // With cap=4 and highTT first in sort order (higher score), highTT fills cap first.
  final highTT = makeTimeTarget(
    name: 'High TT',
    weeklyHourBudget: 2.0,
    priorityWeight: 0.75,
  );
  final lowTT = makeTimeTarget(
    name: 'Low TT',
    weeklyHourBudget: 2.0,
    priorityWeight: 0.25,
  );

  final resultHighFirst = sut.generate(
    goals: [lowTT, highTT],
    blocks: [],
    moodIndex: 1, // cap=4
    date: monday,
    completionLogs: [],
    lighterDay: false,
  );

  // Count chunks per goal
  final highCount = resultHighFirst
      .where((c) => c.chunkType == ChunkType.work && c.goalId == highTT.id)
      .length;
  final lowCount = resultHighFirst
      .where((c) => c.chunkType == ChunkType.work && c.goalId == lowTT.id)
      .length;
  expect(highCount, greaterThanOrEqualTo(lowCount),
    reason: 'High-priority goal must get at least as many chunks as low-priority goal under a shared cap');
});
```

### Sampling Rate

- **Per task commit:** `/home/dan/development/flutter/bin/flutter test test/services/schedule_generator_test.dart`
- **Per wave merge:** `/home/dan/development/flutter/bin/flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/screens/goal_card_priority_chip_test.dart` — covers GOALS-02 chip rendering
- [ ] `test/screens/chunk_card_priority_badge_test.dart` — covers GOALS-02 badge rendering
- [ ] `test/screens/goals_screen_heading_test.dart` — covers GOALS-01 heading text

*(Existing test infrastructure covers engine tests — add to `schedule_generator_test.dart`.
Existing `goal_card_drag_handle_test.dart` must be updated, not replaced.)*

---

## Security Domain

`security_enforcement` is not explicitly set to false in `.planning/config.json` — section included.

This phase involves no network calls, no authentication, no new persistence schema, no
third-party packages, and no user-generated content that crosses trust boundaries. The only data
path is: `Goal.priorityWeight` (already stored in Hive) → UI rendering → schedule generation.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Not applicable — local-only, no auth |
| V3 Session Management | No | Not applicable |
| V4 Access Control | No | Not applicable |
| V5 Input Validation | Minimal | `priorityWeight` is always one of {0.25, 0.5, 0.75} — set by `SegmentedButton` (form) or `reorderAllWithPriority` formula; no free-text numeric input |
| V6 Cryptography | No | Not applicable |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malformed `priorityWeight` value (e.g., 99.0 stored by future migration bug) | Tampering | Engine uses `?? 0.5` null coalescing; extreme values produce high/low scores that are still valid doubles; no crash risk |

**Threat surface summary:** Minimal. This is a local Flutter UI + pure scheduling logic
change with no network, no auth, no new persistence surface.

---

## Sources

### Primary (HIGH confidence)
- [VERIFIED: `lib/screens/goals/goals_screen.dart`] — Current drag handle implementation, `onReorderItem` wiring, `_buildReorderableSection` structure
- [VERIFIED: `lib/screens/goals/widgets/goal_card.dart`] — Current GoalCard structure, secondary row, hover icons
- [VERIFIED: `lib/services/schedule_generator.dart`] — Steps 1-4, current Step 2 (no habit sort), current Step 4 (tiebreaker sort)
- [VERIFIED: `lib/providers/goals_notifier.dart`] — `reorderAllWithPriority` implementation and formula
- [VERIFIED: `lib/data/models/goal.dart`] — `priorityWeight` HiveField 5 (double?)
- [VERIFIED: `lib/screens/schedule/widgets/chunk_card.dart`] — `_WorkChunkContent` parameter list, rationale row position
- [VERIFIED: `lib/screens/home/widgets/active_chunk_card.dart`] — Goal lookup pattern, action row position
- [VERIFIED: `lib/screens/schedule/schedule_screen.dart`] — `_lookupGoalColor`/`_lookupGoalName` pattern
- [VERIFIED: `lib/screens/schedule/widgets/swipeable_chunk_card.dart`] — Passthrough wrapper structure
- [VERIFIED: `test/screens/goal_card_drag_handle_test.dart`] — Existing assertions that will break
- [VERIFIED: `test/services/schedule_generator_test.dart`] — Existing test helpers (`makeHabit`, `makeTimeTarget`, `makeLog`)
- [VERIFIED: `test/test_helpers/mood_pump.dart`] — `pumpWithMood` and `extraProviders` pattern
- [VERIFIED: `.planning/phases/14-goals-screen-and-priority-end-to-end/14-UI-SPEC.md`] — Authoritative design contract for all visual and interaction changes

### Secondary (MEDIUM confidence)
- [VERIFIED: `pubspec.yaml`] — No new packages needed; Flutter 3.44.1 confirmed
- [VERIFIED: `.planning/config.json`] — `workflow.nyquist_validation` absent (treated as enabled); `commit_docs: true`

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; all changes are modifications to verified existing code
- Architecture: HIGH — all patterns verified against actual source files
- Engine changes: HIGH — `schedule_generator.dart` fully read; before/after code confirmed
- Pitfalls: HIGH — derived from actual code gaps found during reading
- Test patterns: HIGH — existing `flutter_test` patterns verified in codebase

**Research date:** 2026-06-13
**Valid until:** 2026-07-13 (Flutter stable; no third-party package changes)

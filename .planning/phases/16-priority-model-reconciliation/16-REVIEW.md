---
phase: 16-priority-model-reconciliation
reviewed: 2026-06-13T00:00:00Z
depth: standard
iteration: 2
files_reviewed: 2
files_reviewed_list:
  - test/screens/goal_card_priority_chip_rebuild_test.dart
  - test/screens/goal_form_priority_test.dart
findings:
  critical: 0
  warning: 0
  info: 1
  total: 1
status: clean
---

# Phase 16: Code Review Report (Iteration 2)

**Reviewed:** 2026-06-13
**Depth:** standard
**Files Reviewed:** 2
**Status:** clean

## Summary

Re-review after fixes to CR-01, WR-01, and WR-02. All three prior findings are genuinely resolved. No new Critical or Warning issues were introduced by the changes. One pre-existing Info item (IN-01) remains by design.

Supporting production files read to verify call chains: `lib/screens/goals/widgets/goal_card.dart`, `lib/providers/goals_notifier.dart`, `lib/screens/goals/goal_form_sheet.dart`, `test/test_helpers/mood_pump.dart`, `test/test_helpers/viewport.dart`.

---

## Prior Finding Verification

### CR-01 — RESOLVED

**Claim:** The `find.ancestor`/`find.descendant` IDENTITY assertions in PRIORITY-03 now genuinely fail in a stale-tree scenario.

**Verification:**

The fix applies two complementary assertions at lines 185–213:

```dart
// Assertion 2: Beta's Card must contain Text('High')
find.descendant(
  of: find.ancestor(of: find.text('Beta'), matching: find.byType(Card)),
  matching: find.text('High'),
) → findsOneWidget

// Assertion 3: Alpha's Card must NOT contain Text('High')
find.descendant(
  of: find.ancestor(of: find.text('Alpha'), matching: find.byType(Card)),
  matching: find.text('High'),
) → findsNothing
```

`GoalCard` renders exactly one `Card` as its root widget (confirmed: `goal_card.dart` line 81). `pumpWithMood` wraps in `Scaffold` only — no extra `Card` in the tree — so `find.byType(Card)` in each ancestor chain is unambiguous: one Card per goal name. `_PriorityChip` renders `Text('High')` only when `priorityWeight >= 0.75` (`goal_card.dart` line 249).

In a stale tree (Consumer rebuild broken), Alpha retains `priorityWeight = 0.75` and its Card still contains `Text('High')`. Assertion 3 (`findsNothing` in Alpha's Card) **fails**. Assertion 2 (`findsOneWidget` in Beta's Card) also **fails** because Beta's Card contains no `Text('High')` in the stale scenario. Both assertions must pass simultaneously for the stale case to go undetected — which is impossible given that exactly one `Text('High')` exists in the tree and it would still be in Alpha's Card, not Beta's.

CR-01 is genuinely resolved. The assertions are non-tautological and would detect a broken Consumer rebuild.

---

### WR-01 — RESOLVED

**Claim:** Lowering `initialChildSize` to 0.5 (422pt modal height on 390x844) forces all three goal-type variants to require real scrolling.

**Verification:**

The `GoalFormSheet` build content at initial state (no type selected) includes: drag handle (~20pt), "Add goal" title (~28pt), `GoalTypePicker` with 3 radio-style options (~150pt), goal name `TextField` (~56pt), priority label + `SegmentedButton<double>` (~88pt), and Cancel/Save row (~52pt). Estimated total height at initial state is ~394pt, which is at the boundary of the 422pt modal. After selecting a goal type, additional fields push the total clearly over:

- **time-target:** weekly-hours `TextField` adds ~56pt → ~450pt, exceeds 422pt
- **habit:** "Sessions per week" row + `Slider` adds ~80pt → ~474pt, exceeds 422pt
- **outcome:** date `ListTile` + multi-line `TextField` adds ~150pt → ~544pt, exceeds 422pt

With `snap: true` and `snapSizes: [0.5, 1.0]`, the first `scrollUntilVisible` call expands the sheet from 0.5 to 1.0 (full 844pt height) via the shared `DraggableScrollableSheet` scroll controller. This IS real scroll work: `scrollUntilVisible` drives the controller, the DBS intercepts to expand the sheet, and content becomes visible. If `SegmentedButton<double>` or `ElevatedButton` were absent from the scroll extent entirely, `scrollUntilVisible` would exhaust its scroll budget and throw `StateError`, causing test failure. The tests catch "widget missing from the tree" regressions for all three goal types.

WR-01 is genuinely resolved.

---

### WR-02 — RESOLVED

The comment at lines 281–286 of `goal_form_priority_test.dart` now correctly states: "DraggableScrollableSheet has no separate Scrollable of its own — it delegates to the content's ScrollController (sc), which is the controller for GoalFormSheet's SingleChildScrollView." This accurately describes the Flutter DBS + `SingleChildScrollView` shared-controller pattern and will not mislead future readers. WR-02 is resolved.

---

## Narrative Findings (AI reviewer — Iteration 2)

No new Critical or Warning issues were found.

The following cross-module checks were performed and found sound:

**`find.byType(Scrollable).first` selector correctness** (goal_form_priority_test.dart, multiple GOALFORM-02 call sites): `GoalFormSheet` passes the DraggableScrollableSheet's `sc` directly to `SingleChildScrollView` (`goal_form_sheet.dart` line 142). The DBS with `expand: false` does not create an independent `Scrollable` in the content tree; it uses a specialized `ScrollController` that the child `SingleChildScrollView` attaches to. `find.byType(Scrollable).first` therefore finds the `SingleChildScrollView`'s `Scrollable`, which is the correct target for scrolling form content.

**`GoalsNotifier` provider availability in modal context** (`_pumpModal` lines 107–135): The `MultiProvider` wraps `MaterialApp`, which provides the `Navigator`. `showModalBottomSheet` creates an overlay route that descends from the `Navigator` and therefore inherits all providers above it. `GoalFormSheet._save()` calls `context.read<GoalsNotifier>()` using its own `BuildContext` (from `State.build`), not the DBS builder's discarded `_` context. Provider lookup is correct.

**`find.text('Add goal').last` tap** (lines 408, 454): `GoalFormSheet` renders "Add goal" as a `Text` title first in the `Column` (line 169 of `goal_form_sheet.dart`) and as the `ElevatedButton` label last (line 331). Widget tree order matches declaration order in the `Column`. `.last` always refers to the button. The preceding `scrollUntilVisible(find.byType(ElevatedButton), ...)` confirms the button is in the scroll extent before the tap. Sound.

**`autoColor()` with unloaded `_goals`** (`_pumpModal` tests — `GoalsNotifier` constructed without `loadGoals()`): `_goals` is empty (`[]`), so `autoColor()` returns `_colorPalette[0 % 8]` = `'#4CAF50'`. `saveGoal` calls `_repository.save(goal)` then `loadGoals()`. `repo.lastSaved` is set correctly in `save()` before `loadGoals()` runs. Sound.

**`tester.tap(find.text('High'))` without `.first`** (line 384, GOALFORM-02 "tapping High" test): In the modal context, the only `Text('High')` in the tree comes from the `SegmentedButton<double>`'s segment label. No `GoalCard` with a High priority chip is in scope (the repo is empty). `find.text('High')` matches exactly one widget; `.first` is not required. Sound.

---

## Info

### IN-01: `_pumpForm` bypasses modal height contract (pre-existing, intentionally left)

**File:** `test/screens/goal_form_priority_test.dart:62–90`
**Issue:** `_pumpForm` pumps `GoalFormSheet` inside a plain `SingleChildScrollView` (no modal, no height constraint). The `ENGINE-06 UI half` group tests use `_pumpForm`, so those tests do not exercise scroll behavior. This is an intentional test-design separation: raw form API tests (`_pumpForm`) are distinct from modal height contract tests (`_pumpModal`).
**Fix:** No action required. Documenting for traceability.

---

_Reviewed: 2026-06-13_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

---
phase: 16-priority-model-reconciliation
reviewed: 2026-06-13T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - test/screens/goal_card_priority_chip_rebuild_test.dart
  - test/screens/goal_form_priority_test.dart
findings:
  critical: 1
  warning: 2
  info: 1
  total: 4
status: issues_found
---

# Phase 16: Code Review Report

**Reviewed:** 2026-06-13
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Two test files reviewed for Phase 16 (Priority Model Reconciliation). The phase is test-only by design (D-01 locked). No production code was changed.

`goal_card_priority_chip_rebuild_test.dart` (PRIORITY-03) contains a critical tautology: the post-reorder assertions cannot distinguish a stale widget tree from a correctly-rebuilt one, which means the test provides no real regression protection for the Consumer rebuild path it purports to verify.

`goal_form_priority_test.dart` (GOALFORM-02) correctly removes both `setSurfaceSize(800,1200)` tests, introduces a real `showModalBottomSheet` + `DraggableScrollableSheet` harness at 390x844 / `initialChildSize: 0.6`, covers all three goal types, and folds in both the High-saves-0.75 and 3-hr-default assertions. The `GoalsNotifier` provider is correctly available inside the modal via Flutter's inherited-widget capture. The `_save()` path writes `priorityWeight` and `weeklyHourBudget` correctly. The outcome-goal scroll test is the only one in GOALFORM-02 that exercises real scrolling; the time-target and habit scroll tests are weakened false passes.

---

## Critical Issues

### CR-01: PRIORITY-03 post-reorder assertions are tautological — the test cannot detect a broken Consumer rebuild

**File:** `test/screens/goal_card_priority_chip_rebuild_test.dart:163-183`

**Issue:** The test's stated purpose is to prove the `Consumer<GoalsNotifier>` rebuild path delivers a fresh `priorityWeight` to `GoalCard` after `reorderAllWithPriority`. But the post-reorder assertions (`findsOneWidget` for `'High'`, `'Low'`, and `Icons.arrow_upward`) are numerically identical whether or not the Consumer rebuilds:

- **Stale tree (broken rebuild):** `GoalCard(g0)` retains its last-built output (High chip, because `g0.priorityWeight` was `0.75` at build time). `GoalCard(g1)` retains its last-built output (no chip). `GoalCard(g2)` retains its last-built output (Low chip). Result: exactly 1 High, 1 Low, 1 `arrow_upward`. All three `findsOneWidget` assertions pass.
- **Fresh tree (correct rebuild):** Consumer replaces the column with `[GoalCard(g1=High), GoalCard(g0=Normal), GoalCard(g2=Low)]`. Result: exactly 1 High, 1 Low, 1 `arrow_upward`. All three `findsOneWidget` assertions pass.

The comment at line 169–171 incorrectly asserts that `findsOneWidget` for `High` proves `g0` did not retain a stale chip: "High chip count is exactly 1 → g0 did NOT retain a stale High chip." This is wrong — before the reorder, there was also exactly 1 High chip (on `g0`), and a stale tree after reorder also has exactly 1 High chip (still on `g0`). The count is invariant across both scenarios.

The test passes today because the Consumer rebuild **does** work, not because the assertions would catch it if it didn't.

**Fix:** Assert that the High chip belongs to **g1 (Beta)**, not g0 (Alpha). The `Column` layout means chip order is positional; verify using `find.descendant` or by checking the order of Text widgets relative to icon widgets:

```dart
// After pumpAndSettle, build a list of the rendered goal-card subtrees in order.
// The first card must be Beta (g1), not Alpha (g0), and must have the High chip.
// The second card must be Alpha (g0) with NO chip.

// Option A: Check relative order of name texts vs. chip texts in the widget tree.
// The Column renders: [g1-card, g0-card, g2-card] top-to-bottom after reorder.
// g1's name ('Beta') must appear BEFORE the High chip text in the element tree.
// g0's name ('Alpha') must NOT appear near a High chip.

final cardTexts = tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data)
    .toList();

// 'Beta' must appear somewhere before 'High' in tree order (or assert adjacency).
final betaIndex = cardTexts.indexOf('Beta');
final highIndex = cardTexts.indexOf('High');
final alphaIndex = cardTexts.indexOf('Alpha');
expect(betaIndex, lessThan(highIndex),
    reason: 'Beta (g1) must be the card that owns the High chip after reorder');
expect(alphaIndex, greaterThan(highIndex),
    reason: 'Alpha (g0) must appear after the High chip — it is now Normal');
```

Alternatively, use `find.ancestor` to verify no High-chip ancestor contains `Text('Alpha')`:

```dart
expect(
  find.ancestor(
    of: find.text('High'),
    matching: find.ancestor(
      of: find.text('Alpha'),
      matching: find.byType(Card),
    ),
  ),
  findsNothing,
  reason: 'g0 (Alpha) must NOT own the High chip after reorder',
);
```

---

## Warnings

### WR-01: time-target and habit GOALFORM-02 scroll tests are false passes — `scrollUntilVisible` does not require actual scrolling

**File:** `test/screens/goal_form_priority_test.dart:258-293` (time-target), `329-354` (habit)

**Issue:** `scrollUntilVisible` succeeds immediately if the target widget is already in the viewport — it is not equivalent to "this widget is only reachable via scroll." The phase comments (line 254) explicitly note that only the **outcome** variant has content height (~692px) exceeding modal height (~506px). Time-target and habit form content likely fits within the 506pt modal height, making `scrollUntilVisible` a no-op for those variants. Both tests would pass even if the `Priority` selector or `Save` button had been moved off-screen or conditionally hidden — the `expect(find.byType(SegmentedButton<double>), findsOneWidget)` assertion after `scrollUntilVisible` passes trivially because `scrollUntilVisible` only returns when the widget is visible (already is), and `findsOneWidget` confirms it. There is no assertion that scrolling was necessary.

This means the test provides no regression protection for the time-target and habit modal height contract it claims to validate.

**Fix:** For time-target and habit, assert that the `Priority` row or `Save` button is NOT visible before scrolling, then scroll to it:

```dart
// Before scrolling, confirm the target is off-screen (or explicitly set
// a smaller initialChildSize so content reliably overflows).
// Option A — reduce initialChildSize to 0.4 in _pumpModal for these two types
// so all variants require real scroll.
// Option B — after pumping, verify the widget is not yet visible:
expect(
  find.byType(SegmentedButton<double>),
  findsNothing,
  reason: 'Priority selector must be below the fold before scrolling',
);
await tester.scrollUntilVisible(...);
expect(find.byType(SegmentedButton<double>), findsOneWidget);
```

If content genuinely fits at initialChildSize 0.6 for time-target and habit, the tests should be renamed from "reachable via scroll" to "visible at modal height" and the scroll calls removed to avoid misleading intent.

### WR-02: Inaccurate comment about `find.byType(Scrollable).first` identity

**File:** `test/screens/goal_form_priority_test.dart:273-276`

**Issue:** The comment states: _"Use find.byType(Scrollable).first to target the DraggableScrollableSheet's scrollable, which is linked to the form's SingleChildScrollView via the shared scrollController."_ This is internally contradictory. `DraggableScrollableSheet` does not own a `Scrollable` independent of its content — it delegates entirely to the content scrollable via the `ScrollController` (`sc`) passed to its builder. The `Scrollable` found by `find.byType(Scrollable).first` is the one belonging to `GoalFormSheet`'s `SingleChildScrollView`, not a separate DraggableScrollableSheet scrollable. The comment will confuse future readers who investigate why `DraggableScrollableSheet`'s "own" scrollable is being targeted.

**Fix:** Correct the comment:

```dart
// find.byType(Scrollable).first finds the SingleChildScrollView's Scrollable
// inside GoalFormSheet. DraggableScrollableSheet has no separate Scrollable of
// its own — it delegates to the content's ScrollController (sc), which is
// the controller for GoalFormSheet's SingleChildScrollView.
```

---

## Info

### IN-01: Old test comment "`.first` handles internal duplication" is no longer accurate but left as context in the removed code — no action needed; surfaced for traceability

**File:** `test/screens/goal_form_priority_test.dart` (removed code block, formerly line ~175 of old version)

**Issue:** The deleted `setSurfaceSize` test had `tester.tap(find.text('High').first)` with the comment "`.first` handles internal duplication." The new `_pumpModal` test (line 375) uses `tester.tap(find.text('High'))` without `.first`. The existing `'Priority label and segment labels'` test already uses `find.text('High')` + `findsOneWidget` in the direct-pump path without `.first` and presumably passes, so the new modal test is not regressing on this. However, if `SegmentedButton` does produce internal text duplicates in certain rendering modes, dropping `.first` could produce a "Found multiple widgets" failure at line 375. This is low risk given the existing test evidence.

**Fix:** If the `'tapping High selects it...'` test flakes with "Found multiple widgets," add `.first` back to `tester.tap(find.text('High'))` at line 375.

---

_Reviewed: 2026-06-13_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

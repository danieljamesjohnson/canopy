---
phase: 16-priority-model-reconciliation
fixed_at: 2026-06-13T00:00:00Z
review_path: .planning/phases/16-priority-model-reconciliation/16-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 3
skipped: 1
status: partial
---

# Phase 16: Code Review Fix Report

**Fixed at:** 2026-06-13
**Source review:** .planning/phases/16-priority-model-reconciliation/16-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4
- Fixed: 3
- Skipped: 1

## Fixed Issues

### CR-01: PRIORITY-03 post-reorder assertions are tautological — the test cannot detect a broken Consumer rebuild

**Files modified:** `test/screens/goal_card_priority_chip_rebuild_test.dart`
**Commit:** 404dc86
**Applied fix:** Replaced count-based assertions (`findsOneWidget` for 'High' chip) with
identity-based assertions using `find.descendant`. After the reorder:
1. Assert `find.text('High')` still exists (sanity baseline).
2. Assert that the Card ancestor of `find.text('Beta')` contains `find.text('High')` as a
   descendant (Beta GoalCard OWNS the High chip).
3. Assert that the Card ancestor of `find.text('Alpha')` does NOT contain `find.text('High')`
   as a descendant (Alpha GoalCard must have NO High chip — the regression catch).
4. Kept the Low chip and arrow-downward assertions unchanged.
5. Updated the arrow-upward assertion with a clarifying reason.

These assertions cannot pass in the stale-tree scenario: if Consumer rebuild is broken,
Alpha retains its pre-reorder High chip and assertion 3 fails; Beta has no chip and
assertion 2 fails.

---

### WR-01: time-target and habit GOALFORM-02 scroll tests are false passes

**Files modified:** `test/screens/goal_form_priority_test.dart`
**Commit:** bba8080
**Applied fix:** Lowered `initialChildSize` in `_pumpModal` from `0.6` to `0.5`
(modal height = 844 * 0.5 = 422pt). At `0.6` (506pt), time-target and habit form
content fit within the viewport, making `scrollUntilVisible` a no-op. At `0.5`
(422pt) the form content overflows for ALL three goal types, so every
`scrollUntilVisible` call does genuine work.

Note: `0.4` (337.6pt) was tried first but caused the GoalTypePicker tap for the
time-target option to fail hit-testing — the tap coordinate fell outside the
modal's hittable region at that size. `0.5` provides the needed overflow while
keeping all three type-selection taps reliably hittable. Confirmed all 11 tests
in the file pass at `0.5`.

Also updated `minChildSize` from `0.4` to `0.3`, `snapSizes` from `[0.6, 1.0]`
to `[0.5, 1.0]`, the `_pumpModal` docstring, the GOALFORM-02 group comment, and
all test name strings to reflect `initialChildSize 0.5` / `422pt`.

---

### WR-02: Inaccurate comment about `find.byType(Scrollable).first` identity

**Files modified:** `test/screens/goal_form_priority_test.dart`
**Commit:** bba8080 (committed together with WR-01 — same file, same edit session)
**Applied fix:** Corrected the comment in the time-target test (the only test that
contained the long form of the inaccurate comment). Updated from:
> "Use find.byType(Scrollable).first to target the DraggableScrollableSheet's
> scrollable, which is linked to the form's SingleChildScrollView via the shared
> scrollController."

To:
> "find.byType(Scrollable).first finds the SingleChildScrollView's Scrollable
> inside GoalFormSheet. DraggableScrollableSheet has no separate Scrollable of
> its own — it delegates to the content's ScrollController (sc), which is the
> controller for GoalFormSheet's SingleChildScrollView."

---

## Skipped Issues

### IN-01: Old test comment ".first handles internal duplication" is no longer accurate

**File:** `test/screens/goal_form_priority_test.dart` (line 375)
**Reason:** Per reviewer guidance: "If the test passes cleanly, leave it." The test
using `tester.tap(find.text('High'))` without `.first` at line 375 passes cleanly
across all test runs, including the full 226-test suite. There is no multiple-match
failure. The reviewer explicitly said this is low risk and to leave it if it passes.
**Original issue:** Dropping `.first` from the modal High tap could produce "Found
multiple widgets" if `SegmentedButton` renders text duplicates internally. Test
evidence shows it does not in this context.

---

## Verification

**Full test suite:** 226/226 tests pass after all fixes.
**flutter analyze:** No issues found on both modified test files.

---

_Fixed: 2026-06-13_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_

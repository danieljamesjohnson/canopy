---
phase: 11-honest-long-loop
fixed_at: 2026-06-11T22:40:00Z
review_path: .planning/phases/11-honest-long-loop/11-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 11: Code Review Fix Report

**Fixed at:** 2026-06-11T22:40:00Z
**Source review:** .planning/phases/11-honest-long-loop/11-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 5
- Fixed: 5
- Skipped: 0

## Fixed Issues

### WR-01: Period boundary inclusive on both sides — boundary double-counting

**Files modified:** `lib/screens/quarterly_review/quarterly_review_screen.dart`
**Commit:** e36f62b
**Applied fix:** When `latestSnapshot != null`, parse `periodEndYmd` as a `DateTime`, add one day with `Duration(days: 1)`, and format back via `_toYmd()`. The no-snapshot branch (`allLogs.isNotEmpty`) is unchanged. This ensures logs on the previous review-completion day are not re-counted in the new period.

---

### WR-02: AdjustmentsSection._finish hardcodes HiveQuarterlySnapshotRepository

**Files modified:** `lib/screens/quarterly_review/sections/adjustments_section.dart`, `lib/screens/quarterly_review/quarterly_review_screen.dart`
**Commit:** 29fb2d2
**Applied fix:** Added optional `QuarterlySnapshotRepository? snapshotRepository` constructor parameter to `AdjustmentsSection`, stored as `_snapshotRepository` (defaulting to `HiveQuarterlySnapshotRepository()`). The `_finish()` method now calls `widget._snapshotRepository.append(...)` instead of directly instantiating the Hive repository. `QuarterlyReviewScreen` passes `widget._snapshotRepository` to `AdjustmentsSection`. The CR-02 `_pendingSnapshot` id-reuse/retry semantics are preserved unchanged.

---

### WR-03: Duplicate workCount/workChunksOf helpers in schedule generator test

**Files modified:** `test/services/schedule_generator_test.dart`
**Commit:** eee934d
**Applied fix:** Removed `workCount` (identical body to `workChunksOf`) and replaced all three call sites (Tests 5, 8, 9) with `workChunksOf`. No functional change — both had identical implementations.

---

### IN-01: archivedGoals.indexOf(goal) relies on reference identity

**Files modified:** `lib/screens/quarterly_review/widgets/donut_chart.dart`
**Commit:** b123c28
**Applied fix:** Replaced `archivedGoals.indexOf(goal)` with `archivedGoals.indexWhere((g) => g.id == entry.key)` and extracted to a local variable `archivedIndex`. Color index for archived goal slices is now stable regardless of whether the map construction copies or reconstructs goal objects.

---

### IN-02: GoalsNotifier() instantiated without injectable repository in AdjustmentsSection widget tests

**Files modified:** `test/screens/quarterly_review_test.dart`
**Commit:** fdae6c5
**Applied fix:** Replaced both bare `GoalsNotifier()` provider creates (at lines 445 and 463) with `GoalsNotifier(repository: _InMemoryGoalRepository())`, using the `_InMemoryGoalRepository` already defined at the top of the test file. Eliminates the risk of Hive "box not open" errors if the notifier's repository methods are ever triggered from these tests.

---

## Test Suite Result

**158 tests passed.** No regressions introduced.

`flutter analyze` reports 5 pre-existing `onReorder` deprecation info-level warnings — none introduced by these fixes.

---

_Fixed: 2026-06-11T22:40:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_

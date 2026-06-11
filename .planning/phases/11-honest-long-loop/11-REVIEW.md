---
phase: 11-honest-long-loop
reviewed: 2026-06-11T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - lib/providers/goals_notifier.dart
  - lib/screens/quarterly_review/quarterly_review_screen.dart
  - lib/screens/quarterly_review/sections/adjustments_section.dart
  - lib/screens/quarterly_review/sections/data_section.dart
  - lib/screens/quarterly_review/widgets/donut_chart.dart
  - test/providers/goals_notifier_priority_test.dart
  - test/screens/quarterly_review_test.dart
  - test/services/schedule_generator_test.dart
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 11: Code Review Report

**Reviewed:** 2026-06-11T00:00:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

The phase delivers three fixes: REVIEW-01 (donut chart counts commitment + archived chunks
with an "Other" catch-all), REVIEW-02 (drag-reorder writes `priorityWeight` via
`reorderAllWithPriority`), and REVIEW-03 (cold-launch loads archived goals + commitment
blocks; `allLogs.isEmpty` empty-state guard). The core logic for all three is correct.
The async-safety concern (context.read before any await) is handled properly in both
`_loadData` and `_finish`. Division-by-zero in the linear-spread formula when n==1 is
guarded correctly. Percentage denominators are consistently zero-guarded.

Two issues of note: a period-boundary double-counting bug that causes a small number of
logged chunks to be attributed to two consecutive quarterly periods, and a dependency
inversion violation in `AdjustmentsSection` that silently bypasses the injectable
snapshot repository during the write path.

---

## Warnings

### WR-01: Period boundary inclusive on both sides — chunks logged on review day counted in two quarters

**File:** `lib/screens/quarterly_review/quarterly_review_screen.dart:102`

**Issue:** When a previous snapshot exists, the new period's `startYmd` is set to
`latestSnapshot.periodEndYmd`. The aggregation service's `_inRange` filter is
`>= startYmd` (inclusive). The previous review's period ended at `periodEndYmd`
with the same inclusive upper bound. Any completion logs recorded on that exact date
were counted in the previous review and are counted again in the current review.

Concrete path:
1. User completes review on 2026-03-01 → snapshot saved with `periodEndYmd = "2026-03-01"`.
   Stats for that review include logs on 2026-03-01 (inclusive).
2. User opens next review → `startYmd = "2026-03-01"`. Aggregation includes logs
   on 2026-03-01 again.

Result: the hero stat and all donut/bar chart data overcount by however many chunks
were logged on the review completion day.

**Fix:** Advance `startYmd` by one calendar day so the new period starts the day
*after* the previous one ended:

```dart
// quarterly_review_screen.dart ~line 101
if (latestSnapshot != null) {
  final prevEnd = DateTime.parse(latestSnapshot.periodEndYmd);
  final nextDay = prevEnd.add(const Duration(days: 1));
  startYmd = _toYmd(nextDay);
}
```

---

### WR-02: `AdjustmentsSection._finish` hardcodes `HiveQuarterlySnapshotRepository` — injectable repository silently bypassed on the write path

**File:** `lib/screens/quarterly_review/sections/adjustments_section.dart:123`

**Issue:** `QuarterlyReviewScreen` accepts a `QuarterlySnapshotRepository?
snapshotRepository` constructor parameter specifically to enable test injection. That
parameter is forwarded only to the *read* call (`snapshotRepo.getLatest()`). The
*write* call in `AdjustmentsSection._finish` directly instantiates
`HiveQuarterlySnapshotRepository()`, completely bypassing the injected repository.

Consequences:
- Any future integration test that injects a fake snapshot repository and taps
  "Finish review" will still attempt a real Hive write and fail with an uninitialized
  box error.
- The half-injected seam is misleading: the screen looks testable end-to-end but
  isn't.

**Fix:** Add an optional `snapshotRepository` parameter to `AdjustmentsSection`
and wire it from the screen:

```dart
// adjustments_section.dart — constructor
const AdjustmentsSection({
  ...
  QuarterlySnapshotRepository? snapshotRepository,
}) : _snapshotRepository = snapshotRepository ?? HiveQuarterlySnapshotRepository();

final QuarterlySnapshotRepository _snapshotRepository;

// _finish — replace direct instantiation
await _snapshotRepository.append(_pendingSnapshot!);
```

```dart
// quarterly_review_screen.dart — pass through
AdjustmentsSection(
  ...
  snapshotRepository: widget._snapshotRepository,
),
```

---

### WR-03: Duplicate helper function `workCount`/`workChunksOf` in schedule generator test — silent divergence risk

**File:** `test/services/schedule_generator_test.dart:75-79`

**Issue:** Two helper functions with different names but identical bodies are defined:

```dart
int workCount(List<ScheduledChunk> chunks) =>
    chunks.where((c) => c.chunkType == ChunkType.work).length;

int workChunksOf(List<ScheduledChunk> result) =>
    chunks.where((c) => c.chunkType == ChunkType.work).length;
```

They are used interchangeably across tests (e.g. `workCount` in Tests 5, 8, 9;
`workChunksOf` in Tests 13, T-09-01, T-09-05). If the semantics diverge in a future
edit (one adds a filter, the other doesn't), tests using the old name silently test
different behavior.

**Fix:** Remove `workCount` and replace all call sites with `workChunksOf`, or vice
versa.

---

## Info

### IN-01: `archivedGoals.indexOf(goal)` relies on reference identity — subtly fragile

**File:** `lib/screens/quarterly_review/widgets/donut_chart.dart:93`

**Issue:** The color index for an archived goal is computed as:

```dart
goals.length + archivedGoals.indexOf(goal)
```

`archivedGoalMap` is built from `archivedGoals` by direct object reference, so
`indexOf` by identity works correctly today. However, if the map construction were
ever changed to copy or reconstruct goals (e.g. `goal.copyWith()`), `indexOf` would
return `-1`, causing the color index to be `goals.length - 1` and the wrong color to
be assigned to the archived goal's slice.

**Fix:** Use the map key to compute a stable index instead of relying on object
identity:

```dart
final archivedIndex = archivedGoals.indexWhere((g) => g.id == entry.key);
final color = _colorForGoal(goal, goals.length + archivedIndex);
```

---

### IN-02: `GoalsNotifier()` instantiated without injectable repository in `AdjustmentsSection` widget tests

**File:** `test/screens/quarterly_review_test.dart:445,463`

**Issue:** The `AdjustmentsSection` rendering tests provide a bare
`GoalsNotifier()` (no repository argument), which internally instantiates
`HiveGoalRepository()`. If any future test tap causes `context.read<GoalsNotifier>()`
to execute `loadGoals()`, `saveGoal()`, or `reorderAllWithPriority()`, the test will
crash with a Hive "box not open" error.

**Fix:** Pass a seeded `_InMemoryGoalRepository` (already defined in the same test
file) to `GoalsNotifier`:

```dart
ChangeNotifierProvider<GoalsNotifier>(
  create: (_) => GoalsNotifier(repository: _InMemoryGoalRepository()),
),
```

---

_Reviewed: 2026-06-11T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

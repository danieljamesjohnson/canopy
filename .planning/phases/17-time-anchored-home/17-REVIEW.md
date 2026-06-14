---
phase: 17-time-anchored-home
reviewed: 2026-06-13T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - lib/screens/home/home_screen.dart
  - test/screens/home_screen_now_state_test.dart
  - test/screens/active_chunk_card_test.dart
findings:
  critical: 3
  warning: 3
  info: 1
  total: 7
status: issues_found
---

# Phase 17: Code Review Report

**Reviewed:** 2026-06-13
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Phase 17 rewrites the Home "Now" zone from first-unresolved-chunk to a clock-window-based `resolveNowState`. The sealed `NowState` hierarchy, timer lifecycle plumbing, and most test coverage are structurally sound. However, three critical defects were found:

1. `resolveNowState` calls `now()` twice on line 93, opening a race-condition window where the minute rolls over between the two calls, silently using a stale hour against a fresh minute (or vice-versa).
2. The `anchoredStartMinutes` field (commitment chunks) is documented as "minutes from midnight **UTC**", while `resolveNowState` computes `currentMinutes` in local wall-clock time. For users outside UTC, commitment-anchored chunks will appear to be wrong-state (active when overdue, or overdue when active) by their UTC offset amount.
3. Both "all-resolved" tests in `active_chunk_card_test.dart` pump `HomeScreen` with `now: null`, causing `resolveNowState` to call `DateTime.now()` for real. Those chunks have `displayStartMinutes == null`, so `allWork` is empty and `DayComplete` is returned via the degenerate path — not the intended all-resolved path. The tests pass for the wrong structural reason and are non-tautological against the old first-unresolved logic.

Three warnings cover: a gap in the "between-chunks overdue" test that does not assert the specific chunk promoted to Now; the missing "6 pm, 8 am-only chunk, nothing done → DayComplete, NOT ActiveChunkCard" test called for in the prompt spec (it exists in `home_screen_now_state_test.dart` as a pure unit test but no widget test proves the UI rendering path); and the advance-loop in `resolveNowState` that can promote chunks whose window has not yet opened into "Active" or "Overdue" when an early chunk is resolved.

---

## Critical Issues

### CR-01: `now()` Called Twice — Race at Minute Boundary

**File:** `lib/screens/home/home_screen.dart:93`

**Issue:** `resolveNowState` captures `currentMinutes` by calling `now()` twice:

```dart
final currentMinutes = now().hour * 60 + now().minute;
```

If `now` is `DateTime.now` and the wall clock crosses a minute boundary between the two calls, `hour` and `minute` come from different `DateTime` instances. The worst case is a minute rollover at an hour boundary (e.g., 8:59:59.999 for `.hour` and 9:00:00.000 for `.minute`), yielding `currentMinutes = 8*60 + 0 = 480` instead of `9*60 + 0 = 540`. This is a silent logic error in a pure function that is designed to be deterministic given a stable `now` input.

In tests the injectable `now` always returns the same frozen value so the double-call is harmless there — the bug only manifests in production under `DateTime.now`.

**Fix:** Capture once, compute once:

```dart
final snap = now();
final currentMinutes = snap.hour * 60 + snap.minute;
```

---

### CR-02: `anchoredStartMinutes` Is UTC but `currentMinutes` Is Local — Time-Zone Mismatch in `resolveNowState`

**File:** `lib/screens/home/home_screen.dart:93-114`  
**Model:** `lib/data/models/scheduled_chunk.dart:38-40`

**Issue:** `resolveNowState` computes `currentMinutes` from local wall-clock time:

```dart
final snap = now();  // DateTime.now() — local time
final currentMinutes = snap.hour * 60 + snap.minute;  // LOCAL minutes
```

`displayStartMinutes` for commitment-anchored chunks is `anchoredStartMinutes`, which the model documentation explicitly states is "minutes from midnight **UTC**":

```dart
/// Set only when anchored to a CommitmentBlock. Minutes from midnight UTC.
int? anchoredStartMinutes;
```

`CommitmentBlock` itself repeats this contract:

```dart
/// Start time as minutes from midnight UTC (e.g. 540 = 9:00am)
int startMinutes;
```

For a user in UTC+5, a 9:00 AM commitment block is stored as `240` (4:00 AM UTC). `currentMinutes` at local 9:00 AM is `540`, so the comparison `540 >= 240 + duration` will evaluate as if the block has been overdue since 4:25 AM local. The window classification will be wrong for the entire day for every commitment-anchored chunk.

The comment in `home_screen.dart` line 88 notes "LOCAL time only — never `.toUtc()`", which is correct advice for `syntheticStartMinutes` but is **incompatible** with how `anchoredStartMinutes` is stored and with the `displayStartMinutes` getter that merges both.

**Fix (two options):**

Option A — normalize `displayStartMinutes` at comparison time by converting the UTC-stored value to local minutes-from-midnight before the sort and comparison. Requires knowing today's UTC offset.

Option B — store `anchoredStartMinutes` in local time (change the model contract and migrate existing data). The fact that the schedule generator uses `block.startMinutes` as `cursor` without a UTC→local conversion (see `schedule_generator.dart:230,238`) suggests the UTC label may already be wrong in practice and option B reflects what the code actually does. Either way: the model doc comment and the `resolveNowState` comment are contradictory and one of them is a bug.

**Whichever option is chosen,** the discrepancy must be explicitly resolved so `resolveNowState`'s window comparisons are internally consistent for commitment chunks.

---

### CR-03: "All-Resolved" Tests in `active_chunk_card_test.dart` Pass via the Degenerate Path, Not the Intended All-Resolved Path (Non-Tautological)

**File:** `test/screens/active_chunk_card_test.dart:337-358`

**Issue:** The two tests `'shows "That's a wrap" when all chunks resolved'` and `'shows no ActiveChunkCard when all chunks resolved'` both call `_pumpHomeScreen(tester, scheduleNotifier: sn)` — without injecting a `now` value, so `now` is `null` and `HomeScreen` falls back to `DateTime.now`.

The schedule used by these tests is `_scheduleAllResolved()`, which creates chunks with **no `syntheticStartMinutes`** (line 270-281). Therefore `displayStartMinutes == null` for both chunks. In `resolveNowState`, the `allWork` filter at line 97-103 excludes both chunks, leaving `allWork.isEmpty == true`, and `DayComplete()` is returned at line 106 — the **degenerate empty-list path**, not the "all chunks resolved within a live window" path.

These tests would also pass under the old first-unresolved logic (which also returns a resolved/empty result when there are no chunks with clock times), so they provide zero regression protection against the pre-Phase-17 bug. The tests are tautologically satisfied by the null-displayStartMinutes shortcut, not by the resolution-checking logic that Phase 17 actually adds.

The companion test in `home_screen_now_state_test.dart` at line 195-217 does supply `syntheticStartMinutes` values and a frozen `now`, so it correctly exercises the all-resolved path. The widget-level tests in `active_chunk_card_test.dart` do not.

**Fix:** Supply `syntheticStartMinutes` in `_scheduleAllResolved()` and inject a `now` that falls inside one of those windows:

```dart
DailySchedule _scheduleAllResolved() {
  final c1 = ScheduledChunk(
    id: 'c1',
    chunkTypeIndex: ChunkType.work.index,
    goalId: 'g1',
    durationMinutes: 25,
    rationale: 'First chunk',
    syntheticStartMinutes: 540,  // 9:00 AM
  )..isCompleted = true;
  final c2 = ScheduledChunk(
    id: 'c2',
    chunkTypeIndex: ChunkType.work.index,
    goalId: 'g2',
    durationMinutes: 30,
    rationale: 'Second chunk',
    syntheticStartMinutes: 600,  // 10:00 AM
  )..isSkipped = true;
  return DailySchedule(dateYmd: _todayYmd(), moodIndex: 3, chunks: [c1, c2]);
}
```

Then inject `now: () => DateTime(2026, 6, 13, 9, 5)` into both widget calls so `resolveNowState` enters the resolution-checking branch, advances past both resolved chunks, and reaches `DayComplete()` for the right reason.

---

## Warnings

### WR-01: Advance-Loop Can Promote a Future Chunk Into "Active" When Only One Window Has Started

**File:** `lib/screens/home/home_screen.dart:120-129`

**Issue:** After finding `active = candidates.last` (the chunk whose window has most recently started), the loop advances past resolved chunks by stepping forward through `allWork` by index:

```dart
while (active.isCompleted || active.isSkipped) {
  final idx = allWork.indexOf(active);
  if (idx + 1 >= allWork.length) return DayComplete();
  active = allWork[idx + 1];
}
```

This unconditionally picks `allWork[idx + 1]` regardless of whether that next chunk's window has started yet. Consider this schedule at 9:30 AM:

- c1: starts 9:00, duration 25 min → window 9:00–9:25 — **resolved (completed)**
- c2: starts 10:00, duration 25 min → window 10:00–10:25 — unresolved

`candidates` will contain only c1 (c2 hasn't started). `active` is set to c1 (completed), loop fires, promotes `active` to c2. `currentMinutes = 570`, `windowEnd = 625`. `570 < 625`, so `Active(c2, null)` is returned — but we are at 9:30, 30 minutes before c2's window opens at 10:00. The user would see c2 as their current "Now" task with an active badge while they are actually in the gap.

The correct result here is `Overdue(c1, c2)`: c1's window has passed and c1 is unresolved-in-spirit (it was completed, but another unresolved chunk should not be promoted early). Wait — c1 is resolved, so the correct result is arguably debatable. But consider: c1 resolved, c2 not yet started, time is in the gap — there is no active chunk and no overdue chunk to display. The algorithm should return `DayComplete` or a new "gap" sub-state, but it instead returns `Active(c2)` prematurely.

The symptom is that an unresolved chunk starts appearing in the "Now" slot before its scheduled window opens, as soon as the previous chunk is resolved.

**Fix:** After advancing `active` past a resolved chunk, check whether the new candidate's window has started:

```dart
while (active.isCompleted || active.isSkipped) {
  final idx = allWork.indexOf(active);
  if (idx + 1 >= allWork.length) return DayComplete();
  final candidate = allWork[idx + 1];
  // Only promote if the next window has already opened.
  if (candidate.displayStartMinutes! > currentMinutes) {
    // Gap between resolved chunk and next window — treat as a brief DayComplete
    // or, preferably, Overdue on the last resolved chunk so the UI
    // still has something meaningful to show.
    break;
  }
  active = candidate;
}
```

The exact desired behavior in the gap (show nothing, show the resolved chunk with a "done" state, or show the upcoming chunk) is a product decision, but the current code makes it silently wrong.

---

### WR-02: "Between-Chunks Overdue" Test Does Not Assert Which Chunk Is Promoted to "Now"

**File:** `test/screens/home_screen_now_state_test.dart:167-182` (unit test) and `test/screens/home_screen_now_state_test.dart:324-359` (widget test)

**Issue:** The unit test at line 167 correctly asserts `s.overdue.id == 'c1'` and `s.next?.id == 'c2'`. However, the widget-level "between-chunks (overdue)" test at line 324 only asserts:

```dart
expect(find.byType(ActiveChunkCard), findsOneWidget, ...);
expect(find.text('Next'), findsOneWidget, ...);
```

It does not assert that the `ActiveChunkCard` is displaying c1 (the overdue chunk), not c2. If the logic were accidentally reversed and c2 were promoted to "Now", both assertions would still pass because `ActiveChunkCard` would still be present and "Next" would still appear with some content. The widget test should pin the identity of the "Now" chunk, for example by asserting on a unique subtitle or ID exposed through the card.

**Fix:** Either assert that the chunk displayed in `ActiveChunkCard` corresponds to c1's rationale/title (`find.textContaining('First chunk')` or equivalent), or restructure the test to verify which `ScheduledChunk.id` was rendered.

---

### WR-03: Timer Lifecycle Test Does Not Verify "No Double-Timer" on Resume

**File:** `test/screens/home_screen_now_state_test.dart:429-475`

**Issue:** The timer/lifecycle test exercises `AppLifecycleState.paused` followed by `AppLifecycleState.resumed` and checks that no exception is thrown. It does not verify that resuming does not install a second timer alongside the first one (the "double-timer" leak scenario specifically called out in the phase brief).

`_startNowTimer()` is documented as idempotent — it cancels the prior timer before starting a new one. That implementation is correct. But the test would also pass if `_startNowTimer` on resume simply called `Timer.periodic` a second time without cancelling, leaving two timers firing in parallel and causing a double `setState` per minute. The idempotency contract is not under test.

**Fix:** Call `resumed` twice in the test (or `paused+resumed` twice) and then advance the clock by 1 minute. Assert that `setState` was called at most once per tick, for example by verifying `find.byType(ActiveChunkCard)` appears exactly `findsOneWidget` (not duplicated) after the tick. Alternatively, expose a test-only getter for the timer reference count and assert it equals 1 after resume.

---

## Info

### IN-01: `now()` Double-Call Documentation Gap (Now Fixed by CR-01)

**File:** `lib/screens/home/home_screen.dart:88-93`

**Issue:** The doc comment for `resolveNowState` notes "Injectable `[now]` enables unit testing at arbitrary wall-clock times without sleeping or mocking `DateTime.now`." This implies stability of the `now()` result across the function, but no comment warns callers that `now` must be a stable, referentially-transparent supplier. A non-idempotent `now` (e.g., a mock that returns different values on successive calls within one `resolveNowState` invocation) will silently produce inconsistent results. After CR-01 is applied and `now()` is called once, this concern disappears; a brief note in the doc comment would prevent future regression.

**Fix:** Add a single-sentence contract note:
```dart
/// [now] is called exactly once per invocation; callers may supply any stable
/// supplier (e.g., `() => DateTime.now()` or a test-frozen constant).
```

---

_Reviewed: 2026-06-13_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

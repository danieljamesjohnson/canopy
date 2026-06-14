---
phase: 17-time-anchored-home
reviewed: 2026-06-13T00:00:00Z
depth: standard
iteration: 2
files_reviewed: 3
files_reviewed_list:
  - lib/screens/home/home_screen.dart
  - test/screens/home_screen_now_state_test.dart
  - test/screens/active_chunk_card_test.dart
findings:
  critical: 1
  warning: 1
  info: 0
  total: 2
status: issues_found
---

# Phase 17: Code Review Report (Iteration 2)

**Reviewed:** 2026-06-13
**Depth:** standard
**Iteration:** 2 (re-review after WR-01 fix)
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Iteration 2 verifies prior findings and critically examines the WR-01 fix. Prior findings CR-01 (now() called twice), CR-02 (UTC/local — accepted as pre-existing tech debt, documented at lines 90–99), CR-03 (tautological all-resolved tests), WR-02 (test identity pinning), WR-03 (double-timer test), and IN-01 (doc comment) are all verified resolved.

The WR-01 fix (advance-loop gap guard) prevents the premature-Active bug for which it was written. However, it introduced a new, distinct honesty defect: it returns `DayComplete` in the gap-between-resolved-and-next-chunk case, even when unresolved future chunks remain. This directly contradicts the "An Honest Day" milestone — showing "That's a wrap / You've reached the end of today's schedule" to a user who still has a scheduled pending chunk coming up in minutes. The test suite then encodes this wrong behavior as expected, locking in the defect.

---

## Prior Findings — Disposition

| Finding | Disposition |
|---------|-------------|
| CR-01 (now() called twice) | **Resolved.** `now()` called exactly once at line 108; result stored in `nowDt`. The doc comment (line 72–75) explicitly documents the single-call contract. |
| CR-02 (UTC/local frame mismatch) | **Accepted as pre-existing tech debt.** Documented at lines 90–99 in `resolveNowState`. Frame-of-reference note is clear, the display layer and logic layer are now explicitly aligned. Out of scope for Phase 17. |
| CR-03 (tautological all-resolved widget tests) | **Resolved.** `active_chunk_card_test.dart` `_scheduleAllResolved()` (lines 274–299) now uses real `syntheticStartMinutes` (540 and 600). Tests inject `allResolvedNow = () => DateTime(2026, 6, 13, 10, 5)` (inside c2's window). `resolveNowState` enters the traversal loop, advances past completed c1 then skipped c2, exhausts candidates, and returns `DayComplete` for the correct structural reason. |
| WR-01 (future chunk wrongly Active) | **Partially resolved — gap guard introduced a new CR-level bug.** See CR-01 below. |
| WR-02 (overdue test identity pinning) | **Resolved.** Widget test at lines 396–413 of `home_screen_now_state_test.dart` asserts `find.descendant(of: find.byType(ActiveChunkCard), matching: find.textContaining('8:30 AM'))`, pinning the `ActiveChunkCard` to c1's start time. |
| WR-03 (double-timer idempotency test) | **Resolved.** Test at lines 539–573 of `home_screen_now_state_test.dart` counts `now()` calls across exactly one 1-minute pump after two paused→resumed cycles. Asserts `nowCallCount == 1`. |
| IN-01 (doc comment gap) | **Resolved.** Single-call contract documented at lines 72–75. |

---

## Critical Issues

### CR-01: `resolveNowState` returns `DayComplete` mid-morning when unresolved future chunks remain (dishonest gap state)

**File:** `lib/screens/home/home_screen.dart:148–156`

**Issue:** The gap guard inside the advance-loop returns `DayComplete()` whenever the currently-selected chunk is resolved and the next chunk's window has not yet opened — regardless of whether unresolved chunks remain later in the day. `DayComplete` is semantically "no work left today / you've reached the end of today's schedule." The gap case means "current work done early, next chunk not started yet, but future unresolved work does remain." These are different states and conflating them is a user-facing honesty failure.

**Exact trace of the failing scenario:**

Inputs: c1 = `syntheticStartMinutes=540` (9:00 AM), `durationMinutes=25`, `isCompleted=true`. c2 = `syntheticStartMinutes=565` (9:25 AM), `durationMinutes=25`, `isCompleted=false`. `now = () => DateTime(2026, 6, 13, 9, 10)` → `currentMinutes = 550`.

```
allWork = [c1(start=540,dur=25,done), c2(start=565,dur=25,pending)]

Step 1: currentMinutes(550) < allWork.first.displayStartMinutes(540)?  → NO
Step 2: currentMinutes(550) >= allWork.last end (565+25=590)?          → NO

candidates = allWork.where(c.displayStartMinutes! <= 550)
           = [c1]   ← c2 excluded: 565 > 550

active = c1

while (c1.isCompleted):                      ← true, enter loop
  idx = 0, idx+1 = 1 < 2                    ← continue
  candidate = allWork[1] = c2
  c2.displayStartMinutes!(565) > currentMinutes(550)  ← TRUE
  return DayComplete()                       ← BUG: c2 is unresolved and pending
```

At 9:10 AM the user sees "That's a wrap / You've reached the end of today's schedule." C2 is an unresolved pending chunk whose window opens in 15 minutes. The day is not complete. This violates NOW-02 ("day-complete should mean the day is actually over") and the "An Honest Day" milestone.

The same code path triggers any time a user completes a chunk before the next chunk's window opens — the common early-finish case.

**Why the test suite does not catch this:**

The regression test at `home_screen_now_state_test.dart:246–281` (labeled `'gap (WR-01 regression)'`) uses `now=9:30` with c2 opening at `10:00` (a 35-minute gap). It asserts `isA<DayComplete>()` in its `reason` string with the label "honest state." The test encodes the wrong behavior as expected. No test covers the near-gap scenario (c2 opens imminently, e.g. in 15 minutes). The test would pass with the buggy code and would break if the fix were applied — it is both non-detecting and actively misleading.

**Correct behavior:** When the advance-loop hits a gap (resolved chunk done, next window not yet open), the function must check whether any further unresolved chunks exist. If they do, the day is NOT complete — a gap/pre-next state should be returned. `DayComplete` is only correct when no further unresolved future work exists.

**Fix:**

Add a `GapBeforeNext` state to the sealed hierarchy:

```dart
/// Current chunk is resolved and the next chunk's window has not yet opened.
/// [next] is the upcoming unresolved chunk (guaranteed non-null; use
/// DayComplete when no unresolved future chunks remain).
class GapBeforeNext extends NowState {
  final ScheduledChunk next;
  GapBeforeNext(this.next);
}
```

Replace the gap guard (lines 153–155) with a check that only returns `DayComplete` when no further unresolved chunks remain:

```dart
if (candidate.displayStartMinutes! > currentMinutes) {
  // Gap: current resolved, next window not yet open.
  // Find the first unresolved chunk with a future window.
  final remaining = allWork
      .sublist(idx + 1)
      .where((c) => !c.isCompleted && !c.isSkipped)
      .firstOrNull;
  if (remaining != null) return GapBeforeNext(remaining);
  // Truly nothing left: all future chunks are also resolved.
  return DayComplete();
}
```

Add `GapBeforeNext` handling in `_buildNowContent` — show "Next up at {time}" (similar to `PreStart` but with mid-day copy) rather than "That's a wrap."

Update the gap regression test to assert `isA<GapBeforeNext>()` with the correct `.next.id`, and add a companion test for the near-gap case (c2 opens in 15 minutes).

---

## Warnings

### WR-01: Gap regression test asserts the wrong expected result and locks in CR-01

**File:** `test/screens/home_screen_now_state_test.dart:246–281`

**Issue:** The test at line 246, labeled `'gap (WR-01 regression)'`, explicitly asserts:

```dart
expect(state, isA<DayComplete>(),
    reason: 'WR-01: gap after resolved chunk → DayComplete (honest state)');
```

The `reason` string calls this "honest state," but returning `DayComplete` when c2 is unresolved and pending at 10:00 AM (now=9:30) is precisely the dishonest state identified in CR-01. The test:

1. Passes with the current buggy code.
2. Would fail when CR-01 is fixed to return `GapBeforeNext`.
3. Labels wrong behavior as correct in its own source.

Additionally, the test does not cover the near-gap scenario (e.g., now=9:10, c2 at 9:25) — the case where the next window is imminent. The large gap (35 min after c1 ends, 30 min until c2) may not expose edge cases near window boundaries.

**Fix:** After the CR-01 fix, update the test:

```dart
test(
    'gap: c1 resolved 9:00–9:25, c2 starts 10:00, now=9:30 → GapBeforeNext(c2)',
    () {
  // ...same chunk setup as before...
  final state = resolveNowState(chunks: chunks,
      now: () => DateTime(2026, 6, 13, 9, 30));
  expect(state, isA<GapBeforeNext>(),
      reason: 'Gap after resolved chunk with future unresolved work must '
          'surface the upcoming chunk, not DayComplete');
  expect((state as GapBeforeNext).next.id, 'c2');
});
```

Add a near-gap companion test: `now=9:10`, c1 done at 9:00–9:25, c2 pending at 9:25–9:50 → `GapBeforeNext(c2)`.

---

_Reviewed: 2026-06-13_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

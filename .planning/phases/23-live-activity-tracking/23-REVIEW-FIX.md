---
phase: 23-live-activity-tracking
fixed_at: 2026-08-07T23:16:42Z
review_path: .planning/phases/23-live-activity-tracking/23-REVIEW.md
iteration: 3
findings_in_scope: 1
fixed: 1
skipped: 0
status: all_fixed
---

# Phase 23: Code Review Fix Report

**Fixed at:** 2026-08-07T23:16:42Z
**Source review:** .planning/phases/23-live-activity-tracking/23-REVIEW.md
**Iteration:** 3

**Summary:**
- Findings in scope: 1
- Fixed: 1
- Skipped: 0

## Fixed Issues

### CR-01: WR-02's debug assert fires on a legitimate, reachable schedule shape — not just malformed input

**Files modified:** `lib/screens/today/now_state.dart`, `lib/providers/schedule_notifier.dart`,
`test/screens/today_screen_now_state_test.dart`, `test/providers/schedule_notifier_add_event_test.dart`
**Commit:** `47b9f5b`
**Applied fix:**

Applied both halves of the review's proposed fix, adapted after tracing actual runtime behavior:

1. **Write side (`schedule_notifier.dart`).** Added a private `_trimTrailingNonWork()` helper,
   called once right after the stale-chunk-removal in `addEventToday` (the point both downstream
   persist branches — the `!anchorsToday` early return and the `newChunks.isEmpty` guard — share).
   It sorts a copy of `_todaySchedule!.chunks` by `displayStartMinutes` (not guaranteed sorted at
   that point) and removes trailing non-work chunks by identity, mirroring
   `ScheduleGeneratorService.generate()`'s STEP E trim. This closes the actual data bug: editing a
   commitment off today can no longer leave a break as the persisted trailing chunk.

2. **Read side (`now_state.dart`).** Removed the WR-02 `assert` entirely, rather than adding the
   review's suggested defensive re-trim of `scheduled` at read time. Before implementing the
   suggested trim, I traced its effect against the existing test suite and found it would regress
   several already-passing, non-WR-02 LIVE-01 tests that rely on a break being resolvable as
   `Active` even when it is the sole/trailing item in `scheduled` (e.g. "active: a running short
   break is the current activity", a solo trailing break). A trim applied before the rest of the
   algorithm would strip that break out of consideration entirely and misclassify a live break as
   `DayComplete`. I then traced the `DayComplete` boundary check itself (`currentMinutes >=
   scheduled.last`'s window end) and confirmed it is correct regardless of `scheduled.last`'s
   `chunkType`: `scheduled` is exhaustive over every chunk with a clock position, sorted by start,
   so once `currentMinutes` passes the last one's window end, nothing else is scheduled today
   either way. The assert was verifying an invariant that, while true for a normally-generated day,
   was never actually load-bearing for this comparison's correctness — so removing it fixes the
   crash with zero change to any returned `NowState`, and does not reintroduce the "premature
   DayComplete" bug LIVE-01 already fixed (a running break still resolves to `Active`). Updated the
   doc comments at both the assert's former location and the function's algorithm-overview comment
   to describe this reasoning and retire the false "two independent generation paths guarantee
   this" claim, per the finding's instruction.

3. **Tests.** Replaced the WR-02 pinning test that asserted `throwsA(isA<AssertionError>())` with a
   CR-01 test asserting the same trailing-break fixture now resolves to a truthful `DayComplete`
   once past its own window, instead of throwing. Kept (and relabeled) the companion test proving a
   trailing break still resolves `Active` while its own window is current — unaffected by the assert
   removal, since that code path never depended on it. Added a new `ScheduleNotifier`-level
   regression test (`schedule_notifier_add_event_test.dart`, "CR-01: moving a commitment off today
   trims the now-trailing break") modeled on the review's verified reproduction: seeds a day whose
   last item is a commitment-anchored work chunk preceded by a break, moves the commitment off
   today via `addEventToday`, and asserts the persisted chunk list ends with the work chunk, not the
   break.

**Verification:** `flutter analyze` clean on all four touched files. Full `flutter test` suite:
459 tests passing (458-test baseline + 1 new regression test), zero failures. Manually confirmed
(before formatting) that the new CR-01 unit test in `today_screen_now_state_test.dart` reproduces
the review's exact repro shape and resolves without throwing.

Locked phase behavior was not touched: the minutes-≥60s / seconds-<60s granularity, the edge-state
copy, the unchanged gap banner, the single-clock-sample threading from `48af6bf`, and
`LiveRowCard` / `timeline.dart` all remain untouched in this diff (`git diff` scoped to the two
`lib/` files listed above).

---

_Fixed: 2026-08-07T23:16:42Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 3_

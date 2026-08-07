---
phase: 23-live-activity-tracking
reviewed: 2026-08-07T23:59:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - lib/screens/today/now_state.dart
  - lib/screens/today/today_screen.dart
  - test/screens/today_screen_now_state_test.dart
  - test/screens/today_screen_test.dart
  - test/screens/today_timeline_model_test.dart
findings:
  critical: 1
  warning: 0
  info: 0
  total: 1
status: issues_found
---

# Phase 23: Code Review Report (Iteration 2 — fix verification)

**Reviewed:** 2026-08-07
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Re-review of two fix commits (`48af6bf` WR-01, `ba3982c` WR-02) against iteration 1's findings,
covering the cumulative diff `0e4fcf0..HEAD`.

**WR-01 (clock-boundary race) is genuinely fixed, and the regression test genuinely discriminates.**
I did not take the fixer's claim on faith: I checked out the pre-fix version of
`today_screen.dart`, ran the new WR-01 test (`test/screens/today_screen_now_state_test.dart`, "the
countdown matches the sample that classified the state, not a later clock read") against it, and
confirmed it fails (`Found 0 widgets with text "45s left · until 8:30 AM"`) — then confirmed it
passes against the current tree. `build()` now samples `_nowFn()` exactly once into `nowDt` and
threads that single `DateTime` into both `resolveNowState` (via a closure) and
`_liveSecondsRemaining`; I checked every remaining `_nowFn()` call site in the file and the only
other one is the header's `DateFormat('EEE d MMM').format(_nowFn())`, which feeds the calendar-date
label, not the classification/countdown pipeline, so it doesn't reintroduce the hazard. This finding
is closed.

**WR-02 (debug assert) is not safe — it fires on a legitimate, reachable schedule shape, not just
malformed input.** The assert's invariant — "the chronologically-last scheduled chunk is always
work-typed" — is not actually guaranteed by the codebase. Its own doc comment cites two mechanisms
(`schedule_generator.dart` STEP E and `ScheduleNotifier._reflowDiscretionaryWork`), and both of
those genuinely hold up under tracing. But there is a **third**, pre-existing mutation path
(`ScheduleNotifier.addEventToday`'s stale-chunk-removal branch, unchanged by this diff, dated
2026-07-01) that the doc comment doesn't account for, and it can leave a break as the trailing
scheduled item with no re-trim. I built and ran a standalone reproduction (real `ScheduleNotifier` +
a fake in-memory repo, no widget pump) that starts from a wholly ordinary schedule and, via nothing
more exotic than editing a commitment's date from the Commitments screen, ends with
`resolveNowState` throwing `AssertionError`. Full detail below. Given this project explicitly hosts
the **debug** build (assertions on) for user acceptance testing per `CLAUDE.md`, this is a live
crash risk in the build the user actually exercises, not a hypothetical future regression the assert
is merely insuring against. See CR-01.

Timer discipline, single-detector discipline, and the "don't touch `LiveRowCard`/`timeline.dart`"
constraint all hold — see "Confirmed clean" below.

## Critical Issues

### CR-01: WR-02's debug assert fires on a legitimate, reachable schedule shape — not just malformed input

**File:** `lib/screens/today/now_state.dart:152-157`
**Also implicated:** `lib/providers/schedule_notifier.dart:217-247` (`addEventToday`, pre-existing,
unchanged by this diff)

**Issue:**

```dart
// lib/screens/today/now_state.dart:152
assert(
  scheduled.last.chunkType == ChunkType.work,
  'DayComplete invariant violated: trailing scheduled chunk must be '
  'work-typed (see resolveNowState doc comment) but was '
  '${scheduled.last.chunkType}',
);
```

The doc comment above this (`now_state.dart:73-83`) argues the invariant is guaranteed by two
mechanisms: `schedule_generator.dart`'s STEP E trim (full-day `generate()`) and
`ScheduleNotifier._reflowDiscretionaryWork`'s "break only emitted between two movable work chunks"
rule (mid-day `addEventToday` reflow). Both of those *are* sound in isolation — I traced them and
confirmed STEP E's `while (result.isNotEmpty && result.last.chunkType != ChunkType.work)
result.removeLast();` genuinely trims every degenerate case I could construct, and confirmed breaks
can never be marked completed/skipped through the UI (`chunk_card.dart`'s Complete/Skip row is
inside `_WorkChunkContent`, only built for `ChunkType.work`; break rows render via `_buildBreak`,
which has no action buttons) — so a break can never survive into `_reflowDiscretionaryWork`'s
`kept` list via the "resolved" branch, closing off the path I initially suspected.

But `addEventToday` has a **third**, earlier code path that mutates and persists
`_todaySchedule.chunks`, and it is covered by neither guarantee:

```dart
// lib/providers/schedule_notifier.dart:231-247
var removedStale = false;
if (hasScheduleToday && _todaySchedule != null) {
  final kept = _todaySchedule!.chunks
      .where((c) => c.commitmentId != block.id)
      .toList();
  removedStale = kept.length != _todaySchedule!.chunks.length;
  _todaySchedule!.chunks = kept;               // <-- persisted here
}

if (!anchorsToday) {
  // Block no longer belongs to today — persist any stale removal and stop.
  if (removedStale) {
    await _repo.save(_todaySchedule!);          // <-- no re-trim, no reflow
    notifyListeners();
  }
  return false;
}
```

When a user edits an existing commitment and moves it off today (changes its date, or removes today
from its `daysOfWeek`) — an entirely ordinary action from the Commitments screen
(`commitments_screen.dart:39`, `onSaved: (saved) => scheduleNotifier.addEventToday(saved)`, used for
both add *and* edit), or when `newChunks` ends up empty at the second, identical `removedStale`
guard (`schedule_notifier.dart:274-279`) — this branch strips that commitment's chunks from
`_todaySchedule.chunks` and saves immediately, with **no** STEP-E-style trailing-non-work trim and
no call into `_reflowDiscretionaryWork`. If that commitment happened to be the day's
chronologically-last item (e.g. an evening call) and a break chunk sat immediately before it, the
break becomes the trailing scheduled item — silently, in persisted state.

**Reproduction (verified, not hypothesized).** I wrote a standalone test using `ScheduleNotifier`
with a fake in-memory `DailyScheduleRepository` (no widget pump needed), ran it, confirmed the
result, then deleted the scratch file since it isn't part of the deliverable. Sequence:

1. Seed today's schedule with `[w1 (work, 8:00–8:25), b1 (shortBreak, 8:25–8:30), c1 (work, anchored
   to commitmentId "block-1", 7:30–8:00 PM)]` — a wholly ordinary, valid, `generate()`-shaped day
   (STEP E is satisfied: the true trailing item, `c1`, is work-typed).
2. Call `notifier.addEventToday(movedBlock)` where `movedBlock.id == 'block-1'` but `date` is now
   tomorrow (simulating the user rescheduling the evening call to a different day).
3. Inspect `notifier.todaySchedule!.chunks`: `[w1, b1]` — `c1` is correctly gone (it's no longer
   today's), but nothing re-trimmed the now-trailing `b1`. Printed:
   `final chunks: [w1:ChunkType.work@480, b1:ChunkType.shortBreak@505]`.
4. Feed that real, persisted chunk list into `resolveNowState` with `now` past `b1`'s window
   (e.g. 10:00 PM): **`AssertionError` thrown**, matching the `assert` above exactly.

This is not the WR-02 pinning test's deliberately-malformed direct chunk-list construction — it is
a schedule the app itself produces and persists through a documented, normal user flow. The
underlying gap in `addEventToday` is pre-existing (commit `b4491a24`, 2026-07-01, well before Phase
23 began) and was previously silent: before WR-02, this exact shape just made `resolveNowState`
return a quietly-wrong, premature `DayComplete`. WR-02 turns that silent wrongness into a hard
crash — and per `CLAUDE.md`, the **debug** build (assertions on) is what's hosted for UAT, so this
is a crash the user can actually hit, not a caught regression confined to CI.

**Fix:** Two complementary options; either is sufficient alone, but doing both is more robust.

1. Make the invariant actually hold after every mutator, not just the two the doc comment already
   covers. Add the same trailing-non-work trim STEP E already does, applied to
   `_todaySchedule!.chunks` right after the stale-removal in `addEventToday` (both call sites — the
   `!anchorsToday` early return and the `newChunks.isEmpty` guard share this exact gap):

   ```dart
   // after `_todaySchedule!.chunks = kept;` (schedule_notifier.dart:237)
   final sorted = List<ScheduledChunk>.from(_todaySchedule!.chunks)
     ..sort((a, b) {
       final aStart = a.displayStartMinutes ?? 9999;
       final bStart = b.displayStartMinutes ?? 9999;
       return aStart.compareTo(bStart);
     });
   while (sorted.isNotEmpty && sorted.last.chunkType != ChunkType.work) {
     _todaySchedule!.chunks.remove(sorted.removeLast());
   }
   ```

   (Sort before trimming — `_todaySchedule!.chunks` isn't guaranteed sorted by clock time at this
   point — so "trailing" means the same thing here as it does in `resolveNowState`.)

2. Defensively, make `resolveNowState` itself resilient instead of trusting an invariant enforced
   only at the write side: drop trailing non-work chunks from `scheduled` before evaluating the
   `DayComplete` boundary (mirroring STEP E at read time), and reserve the `assert` — if kept at all
   — for a case that's genuinely unreachable after that filtering. This removes the crash surface
   regardless of which future mutator introduces the next gap, at the cost of the assert's "fail
   loudly" diagnostic value; given this is a debug-hosted UAT app, correctness-by-construction on
   the read side should be weighted over "fail loudly and crash the user."

The current code should not ship as-is: the "two independent generation paths guarantee this" claim
in `now_state.dart:73-83` does not hold for the codebase's actual mutator surface, and the assert
converts that gap into a user-visible crash in the exact build configuration this project uses for
UAT.

## Confirmed clean (no regression found)

- **Timer discipline:** `_fastTimer` is created only in `_syncFastTimer` (idempotent, called once
  per `build()`), cancelled and nulled on `AppLifecycleState.paused`, cancelled on `dispose()`, and
  `_syncFastTimer(false)` is called explicitly on the empty-schedule early return in `build()` so it
  cannot outlive the schedule that justified it. All `LIVE-02 fast tick` widget tests pass,
  including pause/resume-doesn't-duplicate and dispose-leaves-nothing-pending.
- **Single-detector discipline:** `build()` calls `resolveNowState` exactly once (via the threaded
  `nowDt` closure) and `buildTimeline` consumes its result; nothing downstream re-derives "now".
- **`LiveRowCard` / `timeline.dart`:** both untouched in the cumulative diff — confirmed via
  `git diff 0e4fcf0..HEAD -- lib/` (only `now_state.dart` and `today_screen.dart` changed under
  `lib/`).
- `flutter analyze` on both changed `lib/` files: no issues.
- Full `test/screens/today_screen_now_state_test.dart` suite (47 tests, including the LIVE-01,
  LIVE-02, WR-01 and WR-02 groups): all pass against the current tree.

---

_Reviewed: 2026-08-07_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

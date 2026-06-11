---
phase: 08-a-schedule-you-can-read
reviewed: 2026-06-10T00:00:00Z
depth: standard
files_reviewed: 15
files_reviewed_list:
  - lib/data/database/migrations.dart
  - lib/data/models/scheduled_chunk.dart
  - lib/providers/schedule_notifier.dart
  - lib/router.dart
  - lib/screens/focus/focus_screen.dart
  - lib/screens/schedule/schedule_screen.dart
  - lib/screens/schedule/widgets/chunk_card.dart
  - lib/screens/schedule/widgets/chunk_detail_sheet.dart
  - lib/screens/schedule/widgets/swipeable_chunk_card.dart
  - lib/services/schedule_generator.dart
  - test/providers/schedule_notifier_defer_test.dart
  - test/screens/chunk_card_goal_name_test.dart
  - test/screens/chunk_detail_sheet_test.dart
  - test/screens/focus_screen_test.dart
  - test/services/schedule_generator_test.dart
findings:
  critical: 0
  warning: 6
  info: 5
  total: 11
status: issues_found
---

# Phase 8: Code Review Report

**Reviewed:** 2026-06-10
**Depth:** standard
**Files Reviewed:** 15
**Status:** issues_found

## Summary

Reviewed the Phase 8 "A Schedule You Can Read" implementation: the schedule generator, schedule/focus screens, chunk card/detail/swipe widgets, the `ScheduleNotifier` defer path, the `ScheduledChunk` Hive model, and the v4 migration. No security-relevant surface exists (local-only Hive app, no network/auth), and that scope was respected. No BLOCKER-class correctness or data-loss defects were found.

The substantive concerns are correctness edge cases in `schedule_generator.dart`: the break-pattern long-break counter is computed twice with two independent counters that can disagree, the commitment-window merge handles only adjacent (not overlapping) blocks and can produce a negative-width free slot, and the synthetic-time packing can interleave a discretionary chunk into a free slot that splits a commitment window in a way the final sort renders out of intended order. The focus screen has a post-frame-pop pattern that can enqueue a redundant `Navigator.pop` on rebuild. The remaining items are quality/robustness improvements.

Note on intentional scope (confirmed, not flagged): dynamic rationale strings are Phase 9; full defer carryover is Phase 10. `markDeferred` deliberately sets `isSkipped` to drive the existing partition.

## Warnings

### WR-01: Long-break counter computed twice with independent counters that can disagree

**File:** `lib/services/schedule_generator.dart:179-196` and `:252-267`
**Issue:** The long-break decision (`breakCount % longBreakEvery == 0`) is computed in two separate passes with two separate counters: `_assignSyntheticStartTimes` increments its own `breakCount` while packing slots (line 260) and uses it only to size the cursor advance, while STEP C in `generate` increments an independent `breakCounter` (line 179) to actually decide whether each emitted break is short vs long. These counters are reset/incremented independently and only stay in sync by coincidence. The packing pass also *skips* advancing the cursor for a break when `discIdx == discretionaryChunks.length` or the break doesn't fit the slot (line 264), but still increments `breakCount` (line 260) — and meanwhile the emit pass in STEP C inserts a break after *every* discretionary chunk unconditionally. The result is that the long-break cadence reflected in `durationMinutes`/`chunkType` (STEP C) can diverge from the spacing the packing pass reserved, so a "long break" card can be emitted where only 5 minutes of slot room was reserved (or vice versa), causing overlapping synthetic times after sorting.
**Fix:** Derive the break type once. Have `_assignSyntheticStartTimes` record, per discretionary chunk, the break duration it reserved (e.g. store it on the chunk or return a parallel list), and have STEP C consume that exact value instead of recomputing `breakCounter % longBreakEvery`. Single source of truth for the cadence.

### WR-02: Commitment-window merge only handles adjacent blocks; overlapping blocks yield a negative-width free slot

**File:** `lib/services/schedule_generator.dart:227-249`
**Issue:** Windows are merged only when `windows.last.end == s` (exact adjacency, line 232). If two commitment blocks overlap (e.g. block A 540–620, block B 600–660 on the same weekday), the sorted chunk stream produces windows that are not merged. The free-slot derivation then does `if (cursor < w.start) slots.add(...)` followed by `cursor = w.end` (lines 244-247). When a later window's `end` is *less than* the running `cursor` (because an earlier wider window already advanced past it), `cursor` moves backward, and a subsequent `slots.add((start: cursor, end: w.start))` can produce `start > end` — a negative-width slot. The packing loop `while (cursor + 25 <= slot.end ...)` will simply never enter for that slot, but the cursor bookkeeping is now wrong and discretionary chunks may be placed at times that overlap a commitment window. Two blocks on the same day that overlap is a reachable user configuration (the commitments editor does not appear to forbid it).
**Fix:** Replace the adjacency-only merge with a proper interval merge: sort windows by start, then merge when `w.start <= windows.last.end` (overlap or touch), taking `end = max(prev.end, w.end)`. Clamp `cursor = max(cursor, w.end)` when deriving slots so it never moves backward.

### WR-03: `_assignSyntheticStartTimes` packing can leave the cursor inside a commitment window, producing out-of-intent ordering

**File:** `lib/services/schedule_generator.dart:251-268`
**Issue:** Free slots are computed only *between/around* commitment windows, which is correct, but the per-slot packing advances the cursor for a break only when `discIdx < discretionaryChunks.length` (line 264). When the last discretionary chunk of a slot is placed, no break room is reserved after it — fine — but if more chunks remain and the next slot begins *before* the just-reserved break would have ended in real time (e.g. a tight gap before a commitment window), the synthetic times assigned in the next slot can numerically precede the unreserved break of the previous slot. STEP D sorts purely on the integer start key, so the emitted break (inserted in STEP C immediately after its work chunk) and the next slot's work chunk can sort into an order where a break visually appears between two commitment-adjacent discretionary chunks that were meant to be contiguous. This is a subtle ordering artifact rather than a crash, but it undermines the READ-02 "no break between consecutive commitment chunks" intent at slot boundaries.
**Fix:** After packing, assert/normalize that no discretionary synthetic time falls inside any commitment window, and reserve the trailing break's footprint when deciding slot capacity so cross-slot ordering is monotonic. Covering this with a test that places a discretionary chunk in a narrow pre-commitment gap would surface the artifact.

### WR-04: Focus screen can enqueue a redundant `Navigator.pop` on rebuild

**File:** `lib/screens/focus/focus_screen.dart:127-131`
**Issue:** `build` calls `context.watch<ScheduleNotifier>()` (line 117) and, whenever the target chunk is resolved, registers a post-frame callback that pops the route (lines 128-130). Because `markComplete` mutates the notifier and calls `notifyListeners`, the screen rebuilds at least once more while the chunk is still resolved (and before the route finishes popping), registering a *second* post-frame pop callback. The `if (mounted)` guard prevents a post-dispose pop, but two callbacks scheduled in the same frame window can both pass the `mounted` check and call `Navigator.of(context).pop()` twice, popping an extra route off the stack (e.g. dropping the user past `/schedule`). The "Mark complete" button path (`_markComplete`) intentionally does *not* pop, but the resolved-on-arrival guard does, and the two interact.
**Fix:** Track a `bool _popScheduled` instance flag; set it before `addPostFrameCallback` and short-circuit if already set, so at most one pop is ever enqueued. Alternatively, guard the pop with `if (mounted && ModalRoute.of(context)?.isCurrent == true)`.

### WR-05: `markComplete`/`markSkipped`/`markDeferred` persist before logging with no rollback on log failure

**File:** `lib/providers/schedule_notifier.dart:134-145`, `:159-170`, `:189-201`
**Issue:** Each mutator sets the chunk flag and `await _repo.save(...)` first, then `await _logRepo.append(...)`. If `append` throws (Hive box write failure), the schedule is already persisted as completed/skipped/deferred but no `CompletionLog` exists — the schedule state and the completion log diverge, and the exception propagates uncaught out of an unawaited UI callback (e.g. `confirmDismiss`, button `onPressed`), surfacing as an unhandled async error with no user feedback. `notifyListeners()` (lines 147/172/203) never runs in that case, so the UI also won't reflect the partially-applied state until the next rebuild.
**Fix:** Wrap the save+append pair in try/catch; on failure either revert the in-memory flag and re-throw a typed error the UI can show, or at minimum `notifyListeners()` in a `finally` so the UI reflects committed state. Given the local-only single-writer model the divergence is low-probability, but the silent-divergence + uncaught-async-error combination warrants handling.

### WR-06: `runMigrations` skips persisting `schemaVersion` on downgrade, defeating its own forward-migration guard

**File:** `lib/data/database/migrations.dart:60-64`
**Issue:** When `storedVersion > currentSchemaVersion` the function returns early (line 60) without persisting, which the comment frames as intentional. But the migration loop (line 61) is `for (i = storedVersion; i < currentSchemaVersion; i++)` — when `storedVersion > currentSchemaVersion` the loop body never executes anyway, so the early return only skips the `setInt` on line 64. That is the correct call, but note the `assert` on line 54 means in *debug* builds a rolled-back install hard-crashes at startup (assert throws), while *release* silently continues running against newer-schema Hive data that the current build's adapters may not fully understand (e.g. a future `HiveField(9)` the v4 reader ignores). The behavior is divergent between debug and release in a way that can mask a real data-compatibility problem. The bigger latent issue: the loop indexes `_migrations[i]` with no bounds check — if `currentSchemaVersion` is ever bumped without appending a matching migration entry, this throws `RangeError` at startup for every existing user.
**Fix:** Add an explicit invariant `assert(_migrations.length == currentSchemaVersion)` at top-of-function (or as a top-level test) so a version bump without a migration entry fails loudly in CI rather than at user startup. Consider logging (not just asserting) the downgrade case so release builds leave a diagnostic trail.

## Info

### IN-01: `_breakSuggestion` reads `next` chunk type but ignores that the next chunk is often the inserted break for the *current* chunk

**File:** `lib/screens/focus/focus_screen.dart:101-113`
**Issue:** `_breakSuggestion` looks at `chunks[idx + 1]`. Given the generator inserts a break immediately after each work chunk, `idx + 1` is almost always the break belonging to the current chunk — so the "Take a 5/25 min break" copy is correct by construction, but the logic reads as if it were inspecting the *next work* item. This is fragile if chunk ordering ever changes (e.g. Phase 9 dynamic ordering). Worth a clarifying comment or a `firstWhere(type==break)` lookahead.
**Fix:** Document the dependency on "break-follows-work" ordering, or search forward for the first break/work boundary explicitly rather than assuming `idx + 1`.

### IN-02: Magic numbers for timer duration duplicated across the focus screen

**File:** `lib/screens/focus/focus_screen.dart:36`, `:217`, `:256`, `:274`
**Issue:** `1500` (25*60) and the implicit `1500` denominator appear in four places (`_secondsRemaining` init, `CircularProgressIndicator value`, the `_secondsRemaining < 1500` paused-state check, and the "not started" branch). A future change to the timer length must touch all four; missing one silently breaks the progress ring or button-state logic.
**Fix:** Extract `static const _totalSeconds = 25 * 60;` and reference it everywhere.

### IN-03: `hexToColor` will throw on malformed goal color strings

**File:** `lib/screens/schedule/widgets/chunk_card.dart:7-9`
**Issue:** `int.parse('FF...', radix: 16)` throws `FormatException` if a goal's stored `color` is not a clean hex string (e.g. contains a stray character or is an unexpected length). Callers (`_lookupGoalColor`, focus screen line 140) only null-check `goal.color`, not its format. A corrupt/legacy color value would crash the schedule render. Low probability given colors are app-generated, but unguarded.
**Fix:** Wrap parsing in a try/catch returning a fallback color, or validate the hex length/charset before parsing.

### IN-04: `generatedAt` set via two different clock sources

**File:** `lib/providers/schedule_notifier.dart:97-99` and `:118`
**Issue:** `generateToday` derives `now`/`date`/`dateYmd` from the injectable `_now()` (good for testability) but sets `schedule.generatedAt = DateTime.now().toUtc()` (line 118) using the real wall clock, bypassing the injected clock. In a test that injects a fixed `_now`, `generatedAt` will not match the simulated date, which could mask day-boundary bugs in any logic that later compares `generatedAt`.
**Fix:** Use `_now().toUtc()` for `generatedAt` so the entire schedule shares one clock source.

### IN-05: Duplicate helper definitions and unused parameter pass-through in tests

**File:** `test/services/schedule_generator_test.dart:55-59`
**Issue:** `workCount` (line 55) and `workChunksOf` (line 58) are identical helpers with different names; only minor noise, but consolidating reduces drift. Separately, `makeHabit`'s `priorityWeight` param is accepted but habits are never sorted by it in the generator, so the parameter is dead in every call. Not a defect — flagged only for cleanup.
**Fix:** Collapse the two helpers into one; drop the unused `priorityWeight` on `makeHabit` or add a test that exercises it.

---

_Reviewed: 2026-06-10_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

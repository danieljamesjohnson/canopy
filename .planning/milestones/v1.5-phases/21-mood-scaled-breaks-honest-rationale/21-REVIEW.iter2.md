---
phase: 21-mood-scaled-breaks-honest-rationale
reviewed: 2026-08-07T19:19:52Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - lib/services/schedule_generator.dart
  - test/services/schedule_generator_test.dart
findings:
  critical: 0
  warning: 2
  info: 1
  total: 3
status: issues_found
---

# Phase 21: Code Review Report

**Reviewed:** 2026-08-07T19:19:52Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed the phase 21 diff (`git diff 0134924..HEAD -- lib/ test/`), which is exactly the two changes described: (1) `_moodBreakCadence` lookup table `{1:2, 2:3, 3:4, 4:4, 5:5}` replacing the `isLowMood ? 3 : 4` ternary, and (2) the `_timeTargetRationale` deficit-branch string change from `'${remaining}h behind this week'` to `'Working toward ${remaining}h this week'`, plus eight new tests.

Traced both changes line-by-line and re-derived the arithmetic behind every new test (habit ceiling, cap, break-count-modulo positions) by hand — all six BREAK-01 tests and both TONE-01 tests compute correct expected values against the actual algorithm; none of the new assertions are wrong.

`_moodBreakCadence[moodIndex] ?? 4` has a sensible, non-crashing fallback for an out-of-range/missing key, and it mirrors the pre-existing `_moodCap[moodIndex] ?? 8` idiom already in the file — not a new gap introduced by this phase. No nondeterminism was introduced (no `Random`, no wall-clock reads, no unordered-collection iteration driving output order); the change is a pure `Map` lookup with a constant fallback.

The one real gap: the phase's stated premise was that the *old* cadence tests "passed regardless of cadence and therefore proved nothing" — but two of the six new cadence tests (mood=2, mood=4) have exactly the same defect, undisclosed. Confirmed by hand-tracing the old formula (`isLowMood ? 3 : 4`, where `isLowMood = moodIndex <= 2`) against the new table: mood=2 was 3 under both old and new; mood=4 was 4 under both old and new. Only mood=1 (3→2) and mood=5 (4→5) actually changed, and only those two tests (plus the mood=3 "baseline unchanged" test, which is honestly labeled as non-discriminating) would fail against the pre-phase code. See WR-01 below.

Also confirmed no other file in the codebase pattern-matches on the rationale string (no UI logic parses `"behind"` out of `rationale`), so the TONE-01 copy change is a safe, contained edit with no reachable regression outside the two reviewed files.

## Warnings

### WR-01: Two of six new cadence tests do not discriminate old vs. new behavior, contrary to the phase's own premise

**File:** `test/services/schedule_generator_test.dart:1878-1900` (mood=2 test), `test/services/schedule_generator_test.dart:1959-1985` (mood=4 test)
**Issue:** The phase was explicitly motivated by "the previous tests passed regardless of cadence and therefore proved nothing" (see phase context / BREAK-01 rationale). The mood=1 and mood=5 tests correctly close that gap — hand-tracing confirms they assert a chunk-type sequence that the old `isLowMood ? 3 : 4` formula would get wrong (old mood=1 cadence was 3, not 2; old mood=5 cadence was 4, not 5).

However:
- The **mood=2** test (`'BREAK-01: mood=2 places a long break after every 3 work chunks'`) asserts a long break after the 3rd work chunk. Under the *old* formula, mood=2 is low-mood (`moodIndex <= 2`) so cadence was already 3 — identical to the new table's `_moodBreakCadence[2] = 3`. This test passes unchanged under both the buggy and fixed implementation.
- The **mood=4** test (`'BREAK-01: mood=4 places a long break after every 4 work chunks'`) asserts a long break after the 4th work chunk. Under the old formula, mood=4 is not low-mood, so cadence was already 4 — identical to `_moodBreakCadence[4] = 4`. Same non-discriminating result.

The mood=3 test is explicitly titled *"(baseline unchanged)"* and its comment discloses that it locks in pre-existing behavior rather than proving the fix — that test is honest about what it covers. The mood=2 and mood=4 tests carry no such disclosure; they read as if they're validating the new mood-scaled table (like the mood=1/5 tests) when in fact they'd pass identically against the old single-ternary code. This silently reintroduces the exact test-design failure the phase was created to fix, just for two of the five mood tiers instead of all of them.

**Fix:** Either add a comment analogous to the mood=3 test's ("(unchanged from old cadence — this locks in the plateau value, not a regression test for the table itself)"), or restructure the assertion to be explicit that it's a regression lock rather than proof of the new table, so a future reader doesn't mistake "6 cadence tests" for "6 tests that prove the cadence table was wired up correctly."

```dart
test(
  'BREAK-01: mood=2 places a long break after every 3 work chunks '
  '(also true under the pre-BREAK-01 formula — regression lock, not a table-wiring proof)',
  () { /* ... unchanged body ... */ },
);
```

### WR-02: `_moodBreakCadence` has no explicit range validation on `moodIndex`, relying entirely on Map.[] returning null for a silent fallback

**File:** `lib/services/schedule_generator.dart:231`
**Issue:** `moodIndex` originates from `DailySchedule.moodIndex` (`lib/data/models/daily_schedule.dart`), which is deserialized straight from Hive via `(fields[2] as num).toInt()` with no range check or migration guard. If a corrupted/legacy record ever stored a value outside 1-5 (e.g. `0` from an old default, or a value from a future mood-scale expansion), `_moodBreakCadence[moodIndex] ?? 4` silently falls back to `4` — not a crash, but also not obviously correct, and `isLowMood = moodIndex <= 2` would independently disagree with the fallback cadence for `moodIndex <= 0` (treated as low-mood for habit/outcome gating, but given the non-low-mood cadence of 4). This is a **pre-existing pattern** — `_effectiveCap`'s `_moodCap[moodIndex] ?? 8` has the identical shape and was not introduced by this phase — so it is not a regression, but the phase had an explicit opportunity to add a shared assertion/clamp when introducing the second copy of this idiom and didn't.
**Fix:** Not blocking, but worth doing once (covers both maps): add `assert(moodIndex >= 1 && moodIndex <= 5)` at the top of `generate()`, matching the existing `assert(freq >= 1 && freq <= 7)` pattern already used in `computeDueWeekdays`.

## Info

### IN-01: New single-line test definition exceeds the file's prevailing formatting style

**File:** `test/services/schedule_generator_test.dart:2104`
**Issue:** `test('TONE-01: under-pace time-target rationale reads as working toward, not behind', () {` is written as a single un-wrapped line (100+ columns), inconsistent with the `dart format`-style wrapping used by every other `test(...)` call in the file (name and callback split across lines). Cosmetic only — `dart format lib/` per CLAUDE.md commands would normalize it if run.
**Fix:** Run `dart format test/services/schedule_generator_test.dart`.

---

_Reviewed: 2026-08-07T19:19:52Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

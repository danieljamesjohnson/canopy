---
phase: 28-the-day-is-a-lattice
reviewed: 2026-08-19T13:01:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - lib/services/schedule_generator.dart
  - test/services/schedule_generator_test.dart
  - test/screens/lattice_break_pair_test.dart
findings:
  critical: 0
  warning: 2
  info: 1
  total: 3
status: issues_found
---

# Phase 28: Code Review Report

**Reviewed:** 2026-08-19T13:01:00Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Reviewed the `git diff 8fcfc08..HEAD -- lib/services/schedule_generator.dart` delta (+137/−43)
that introduces the 30-minute lattice, plus the two spec test files that pin the new behavior.
All 74 tests in the two test files pass against the current engine (`flutter test
test/services/schedule_generator_test.dart test/screens/lattice_break_pair_test.dart`), and
`flutter analyze` on the production file is clean.

I traced the packing loop (`_assignSyntheticStartTimes`) and the STEP C break-decoding logic by
hand against the four domain invariants called out in the review brief, with particular attention
to invariant 3 — whether the new "partial-reservation fallback" (`lib/services/
schedule_generator.dart:830-841`) is genuinely capacity-driven or a reincarnation of the original
`discIdx + 1 < discretionaryChunks.length` suppression bug:

- The fallback only fires when `cursor + breakFootprint > slot.end`, where `breakFootprint` is
  either 5 (ordinary chunk) or 35 (cadence-boundary chunk) and `slot.end` is bounded only by the
  day's 10:00 PM ceiling or the next commitment's real (unrounded) start minute. There is no
  remaining code path that suppresses a long break based on chunk position (e.g. "is this the last
  chunk"). The old guard is fully removed, not renamed. This satisfies invariant 3 — the fallback is
  capacity-driven only.
- Invariant 1 (lattice alignment) holds: every discretionary chunk is placed from a cursor that is
  always ≡0 (mod 30) at the top of the packing while-loop (slot starts are always either the
  lattice-rounded `dayStart` or the output of `_roundUpToLattice`; mid-slot cursors are re-aligned
  after every placement). Short breaks are always emitted at `chunk.start + 25` (≡25 mod 30), long
  breaks always at `chunk.start + 30` with duration exactly 30.
- Invariant 2 (commitments never rounded) holds: `_roundUpToLattice` is applied only to
  `dayStart`/free-slot cursors, never to `block.startMinutes`/`endMinutes` or the chunks derived
  from them (Step 1's commitment-chunking loop is untouched by this diff).
- Invariant 4 (`_moodCap`/`_moodBreakCadence` tables) are byte-identical to the values specified in
  the brief and unchanged by the diff.

No BLOCKER-level defect was found. Two WARNING-level quality issues and one INFO-level
observation are below; none affect correctness of the invariants above.

## Warnings

### WR-01: Top-of-class doc comment overstates break guarantees the code doesn't always keep

**File:** `lib/services/schedule_generator.dart:20-26`
**Issue:** The class-level doc says, unconditionally: "every discretionary work chunk closes its
own cell with a 5-minute short break, and every longBreakEvery-th chunk's cell is followed by a
separate 30-minute long break cell." That's the common case, but it's not what the code actually
guarantees. Two capacity-driven exceptions exist and are both real (not merely theoretical):

1. A non-boundary chunk placed in a slot whose *end* is not lattice-aligned (only possible when
   the slot is bounded by an unrounded commitment start — see invariant 2) can land with 25–29
   minutes of remaining room: enough for the work chunk itself but not its own 5-minute short
   break. `reservedBreakMinutes` stays `null` and no break is emitted at all for that chunk
   (`lib/services/schedule_generator.dart:810-844`, the "neither condition fires" fallthrough).
2. A cadence-boundary chunk in a narrow slot gets only its 5-minute short break, with the long
   break silently (by design) omitted — this is exactly the partial-reservation fallback exercised
   by `RED-PROOF 6` in `test/services/schedule_generator_test.dart:2562-2722`.

Both exceptions are documented accurately at the point of implementation (`lib/services/
schedule_generator.dart:806-841`), but a reader who only reads the class doc — the most likely
first (and sometimes only) thing a future maintainer reads before touching downstream consumers
like the timeline/row/geometry code — comes away believing every discretionary work chunk always
gets at least a short break, and every Nth chunk always gets a long break. That's the same shape of
assumption that produced the original defect this phase fixes (LATTICE-02/D-05), just relocated
one layer up into the doc comment instead of the guard clause.

**Fix:** Add one sentence acknowledging the capacity exception, e.g.:

```dart
/// After allocation, a break insertion pass interleaves shortBreak / longBreak
/// chunks between every work chunk on a 30-minute lattice: every discretionary
/// work chunk *tries to close* its own cell with a 5-minute short break, and
/// every longBreakEvery-th chunk's cell is *normally* followed by a separate
/// 30-minute long break cell — except when the enclosing free slot is too
/// narrow to hold that footprint (bounded by an off-lattice commitment start
/// or the 10:00 PM day end), in which case the break is genuinely omitted
/// rather than silently suppressed by a position-based guard. See
/// _assignSyntheticStartTimes for the exact fallback rules. longBreakEvery is
/// mood-scaled: 2 / 3 / 4 / 4 / 5 for moods 1 through 5 — see the
/// break-cadence table below.
```

### WR-02: Duplicated short-break chunk construction in STEP C

**File:** `lib/services/schedule_generator.dart:655-693`
**Issue:** The `if (reserved > _shortBreakMinutes)` branch and its `else` branch each build a
`shortBreak` `ScheduledChunk` with the same five fields, differing only in
`durationMinutes: _shortBreakMinutes` vs. `durationMinutes: reserved` (which, in the `else`
branch, is always `_shortBreakMinutes` anyway — see IN-01). This is ~12 lines of copy-pasted
construction logic that could drift out of sync (e.g. a future field added to one branch and
forgotten in the other) — the same category of risk the file's own `_roundUpToLattice` extraction
was written to avoid for round-up arithmetic.

**Fix:** Extract a small helper and call it from both branches:

```dart
ScheduledChunk _shortBreakChunk(ScheduledChunk afterChunk) {
  final b = ScheduledChunk(
    chunkTypeIndex: ChunkType.shortBreak.index,
    goalId: null,
    durationMinutes: _shortBreakMinutes,
    rationale: '',
  );
  if (afterChunk.syntheticStartMinutes != null) {
    b.syntheticStartMinutes =
        afterChunk.syntheticStartMinutes! + afterChunk.durationMinutes;
  }
  return b;
}
```

then in STEP C:

```dart
final shortBreak = _shortBreakChunk(chunk);
result.add(shortBreak);
if (reserved > _shortBreakMinutes) {
  final longBreak = ScheduledChunk(
    chunkTypeIndex: ChunkType.longBreak.index,
    goalId: null,
    durationMinutes: reserved - _shortBreakMinutes,
    rationale: '',
  );
  if (chunk.syntheticStartMinutes != null) {
    longBreak.syntheticStartMinutes =
        chunk.syntheticStartMinutes! + chunk.durationMinutes + _shortBreakMinutes;
  }
  result.add(longBreak);
}
```

## Info

### IN-01: Redundant condition in the partial-reservation fallback for non-boundary chunks

**File:** `lib/services/schedule_generator.dart:820-841`
**Issue:** `breakFootprint` is `_shortBreakMinutes + (isBoundary ? _longBreakMinutes : 0)`. For a
non-boundary chunk, `breakFootprint == _shortBreakMinutes`, so the `if (cursor + breakFootprint <=
slot.end)` check and the `else if (cursor + _shortBreakMinutes <= slot.end)` check test the exact
same condition — the `else if` branch is unreachable for non-boundary chunks and only ever fires
for boundary chunks whose full 35-minute footprint didn't fit. The code is correct (this is exactly
the intended behavior per RED-PROOF 6), but the duplication of the same comparison across two
branches for the non-boundary case is slightly misleading on a first read; a comment noting "for a
non-boundary chunk this elif is unreachable — breakFootprint already equals
_shortBreakMinutes" would save the next reader the trace.
**Fix:** Optional — add a one-line comment at the `else if` clarifying it only has effect for
`isBoundary == true`, or restructure as `if (isBoundary) { ... } else { ... }` for clarity. Not
worth a structural change on its own.

---

_Reviewed: 2026-08-19T13:01:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

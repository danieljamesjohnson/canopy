---
phase: 28-the-day-is-a-lattice
fixed_at: 2026-08-19T13:05:07Z
review_path: .planning/phases/28-the-day-is-a-lattice/28-REVIEW.md
iteration: 1
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
---

# Phase 28: Code Review Fix Report

**Fixed at:** 2026-08-19T13:05:07Z
**Source review:** .planning/phases/28-the-day-is-a-lattice/28-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope (Critical + Warning): 2
- Fixed: 2
- Skipped: 0

Scope was Critical + Warning (0 Critical, 2 Warning). IN-01 (Info) was out of required
scope but was a one-line, zero-risk clarification in code already being touched for
WR-01/WR-02, so it was applied too and is reported separately below as a bonus fix.

## Fixed Issues

### WR-01: Top-of-class doc comment overstates break guarantees the code doesn't always keep

**Files modified:** `lib/services/schedule_generator.dart`
**Commit:** 27465e6
**Applied fix:** Rewrote the class-level doc comment (lines 21-26 pre-fix) to state the
break guarantee as best-effort ("tries to close" / "normally followed by") rather than
absolute, and added a sentence explaining the narrow-slot capacity exception (bounded by
an off-lattice commitment start or the 10:00 PM day end) that genuinely omits a break
rather than suppressing it by position. Points readers to `_assignSyntheticStartTimes`
for the exact fallback rules. Comment-only change; no behavior affected.

### WR-02: Duplicated short-break chunk construction in STEP C

**Files modified:** `lib/services/schedule_generator.dart`
**Commit:** 99d7fe7
**Applied fix:** Extracted the repeated 5-field `ScheduledChunk` short-break construction
(present nearly identically in both the `if (reserved > _shortBreakMinutes)` branch and
its `else` branch) into a new private helper, `_shortBreakChunk(ScheduledChunk
afterChunk)`, placed immediately after `generate()`. Both STEP C branches now call the
helper. The helper always uses `_shortBreakMinutes` as the duration (matching IN-01's
observation that the `else` branch's `reserved` value is always equal to
`_shortBreakMinutes` there anyway), so this is a behavior-preserving refactor.

## Bonus Fix (outside required scope)

### IN-01: Redundant condition in the partial-reservation fallback for non-boundary chunks

**Files modified:** `lib/services/schedule_generator.dart`
**Commit:** a676b89
**Applied fix:** Added a one-line comment above the `else if (cursor + _shortBreakMinutes
<= slot.end)` clause in `_assignSyntheticStartTimes` noting that the branch is
unreachable for non-boundary chunks (`breakFootprint` already equals
`_shortBreakMinutes` there) and only has effect for cadence-boundary chunks whose full
35-minute footprint didn't fit. This was Info-severity and out of the required
Critical+Warning scope, but the reviewer's own note said it was "worth" a one-liner and
the surrounding code was already open for WR-02 — no structural change was made (the
optional `if (isBoundary) {...} else {...}` restructure was explicitly declined by the
reviewer as "not worth a structural change on its own").

## Skipped Issues

None — all in-scope findings (WR-01, WR-02) were fixed. The one Info finding (IN-01) was
out of scope but applied anyway as documented above.

## Verification

- `flutter test`: 579/579 passed after each of the three commits (baseline, +WR-01,
  +WR-02, +IN-01) — no test was edited.
- `flutter analyze lib/services/schedule_generator.dart`: clean after each commit.
- `_moodCap` and `_moodBreakCadence` (D-04) were not touched.
- No file other than `lib/services/schedule_generator.dart` was modified.

---

_Fixed: 2026-08-19T13:05:07Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_

---
phase: 22-unified-today-screen
plan: 01
subsystem: ui
tags: [flutter, sealed-classes, pattern-matching, tdd]

# Dependency graph
requires:
  - phase: 17-time-anchored-home
    provides: resolveNowState / NowState sealed hierarchy (originally in home_screen.dart)
provides:
  - "lib/screens/today/now_state.dart — NowState + resolveNowState with zero widget dependencies"
  - "lib/screens/today/timeline.dart — buildTimeline pure function + TimelineRow sealed hierarchy"
affects: [22-02, 22-03, 22-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Sealed-class row model consumed via exhaustive switch (TimelineRow: ChunkRow/LeadingFreeRow/GapFreeRow)"
    - "Single now-detector: only resolveNowState samples the clock; buildTimeline receives NowState as data and never reads DateTime"

key-files:
  created:
    - lib/screens/today/now_state.dart
    - lib/screens/today/timeline.dart
    - test/screens/today_timeline_model_test.dart
  modified:
    - lib/screens/home/home_screen.dart
    - test/screens/home_screen_now_state_test.dart
    - test/screens/active_chunk_card_test.dart

key-decisions:
  - "active_chunk_card_test.dart's new now_state.dart import is currently unused in executable code (only referenced in doc comments) — kept per plan for import-path symmetry with home_screen_now_state_test.dart, marked with `// ignore: unused_import` rather than dropped, to satisfy both the plan's verify grep and a clean `flutter analyze`"

requirements-completed: [UNIFY-01]

# Metrics
duration: 7min
completed: 2026-08-07
---

# Phase 22 Plan 01: Now-State and Timeline Model Summary

**Extracted `resolveNowState`/`NowState` into a standalone file and added `buildTimeline`, a pure function that turns chunks + an injected `NowState` into an ordered row list — closing the "two competing now-detectors" hazard flagged in 22-PATTERNS.md before any widget code exists.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-08-07T14:35:58-05:00
- **Completed:** 2026-08-07T14:42:22-05:00
- **Tasks:** 2 completed
- **Files modified:** 6 (2 created production files, 1 created test file, 3 modified)

## Accomplishments
- `NowState`/`resolveNowState` relocated verbatim (algorithm untouched) from `home_screen.dart` to `lib/screens/today/now_state.dart`, with zero widget dependencies — importable without pulling in a screen file
- `buildTimeline` implemented as a pure function: chunks + `NowState` in, an ordered `TimelineRow` list out, with named free-time rows (10-minute inclusive threshold) and exactly one `isLive` row derived solely from the injected `NowState`
- Phase 17 regression guard (5:30pm chunk must win over an unresolved 8am chunk at 6pm) is now a permanent unit test against the extracted model, not just the widget-level Phase 17 tests
- Full suite green at 362 tests (348 baseline + 14 new `today_timeline_model_test.dart` cases), `flutter analyze` clean throughout

## Task Commits

Each task was committed atomically:

1. **Task 1: Relocate NowState + resolveNowState to lib/screens/today/now_state.dart (P2)** - `ce921b1` (feat)
2. **Task 2: buildTimeline — the single-detector row model (D-05, P1)**
   - RED: `fe4164b` (test) — failing test added, confirmed compile failure
   - GREEN: `8bb1029` (feat) — implementation, all 14 cases pass

**Plan metadata:** pending (this commit)

## Files Created/Modified
- `lib/screens/today/now_state.dart` - `NowState` sealed hierarchy (PreStart/Active/Overdue/GapBeforeNext/DayComplete) + `resolveNowState`, moved verbatim from `home_screen.dart`
- `lib/screens/today/timeline.dart` - `TimelineRow` sealed hierarchy (ChunkRow/LeadingFreeRow/GapFreeRow), `kMinGapMinutes`, and `buildTimeline`
- `lib/screens/home/home_screen.dart` - now-state declarations removed, imports the new location instead; behavior unchanged
- `test/screens/home_screen_now_state_test.dart` - import repointed to `today/now_state.dart`
- `test/screens/active_chunk_card_test.dart` - import repointed to `today/now_state.dart` (unused in this file today, see Decisions)
- `test/screens/today_timeline_model_test.dart` - new unit suite for `buildTimeline`, including the Phase 17 regression guard

## Decisions Made
- Kept the `today/now_state.dart` import in `active_chunk_card_test.dart` per the plan's explicit two-file instruction and verify gate, even though the file only references `NowState`/`resolveNowState` in doc comments today (not executable code). Suppressed the resulting `unused_import` warning with an inline `// ignore` and an explanatory comment rather than dropping the import, since dropping it would fail the plan's automated verify (`grep -q 'screens/today/now_state.dart' test/screens/active_chunk_card_test.dart`) while keeping it unmarked would fail the "flutter analyze clean" requirement — both are explicit gates in the same task.
- `dart format lib/ test/` reformatted ~46 unrelated files across the repo (pre-existing formatter-version drift, unrelated to this plan's scope). Reverted those via individual `git checkout --` before staging, per the scope boundary rule — only files this task actually touched were committed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Suppressed unused-import warning from the plan-mandated active_chunk_card_test.dart import**
- **Found during:** Task 1 verification (`flutter analyze`)
- **Issue:** Adding the `today/now_state.dart` import to `active_chunk_card_test.dart` (as the plan's action explicitly requires) produced an `unused_import` warning because the file never references `NowState`/`resolveNowState` symbols outside comments, conflicting with the plan's "flutter analyze clean" done criterion.
- **Fix:** Added `// ignore: unused_import` with an explanatory comment on the import line, satisfying both the plan's verify grep (import present) and a clean `flutter analyze`.
- **Files modified:** `test/screens/active_chunk_card_test.dart`
- **Verification:** `flutter analyze` → "No issues found!"; task 1 verify command passed in full.
- **Committed in:** `ce921b1` (Task 1 commit)

**2. [Rule 1 - Bug] Reverted incidental repo-wide dart format drift**
- **Found during:** Task 1, after running `dart format lib/ test/` as instructed
- **Issue:** The project's installed `dart format` reformats files last touched by an older formatter version; running it tree-wide (as the plan's action literally says) modified ~46 files with no logical connection to this plan (whitespace/line-wrap only).
- **Fix:** Reverted all unrelated files individually with `git checkout -- <file>` before staging, keeping only the files this plan's tasks actually created or edited.
- **Files modified:** none (reverted, not committed)
- **Verification:** `git status --short` showed only the plan's own files after the revert; `flutter analyze` still clean.
- **Committed in:** N/A (reverted before commit, out of scope per SCOPE BOUNDARY)

---

**Total deviations:** 2 auto-fixed (2 Rule 1 — bug/scope hygiene)
**Impact on plan:** Both fixes keep the plan's explicit verify gates satisfiable simultaneously and keep the commit history scoped to this plan's actual work. No scope creep, no behavior change.

## Issues Encountered
None beyond the two deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `lib/screens/today/now_state.dart` and `lib/screens/today/timeline.dart` are ready for 22-02 (live row widget) and 22-03 (merged screen) to import directly.
- `home_screen.dart` still compiles and behaves identically — it is deleted in 22-04, not this plan.
- No blockers. The structural fix for 22-PATTERNS.md's highest-risk finding (two competing now-detectors) is in place: `buildTimeline` cannot read the clock, and the Phase 17 regression guard is now a permanent unit test.

---
*Phase: 22-unified-today-screen*
*Completed: 2026-08-07*

## Self-Check: PASSED

All created files and commit hashes verified present on disk / in git log.

---
phase: 29-breaks-you-can-see
plan: 02
subsystem: ui
tags: [flutter, chunk-card, timeline-geometry, density-tier, red-green-wiring]

# Dependency graph
requires:
  - phase: 29-breaks-you-can-see
    plan: 01
    provides: "ChunkCardDensity.subCompact enum value, kSubCompactBreakMinHeight placeholder constant, _SubCompactRow shared widget, and 8 tests (5 proven RED) pinning the sub-compact tier's behaviour"
provides:
  - "ChunkCard._buildBreak's subCompact early return, checked before compact — the reachable break call site now renders the hairline-with-label"
  - "today_screen.dart's three-band break density ternary (full / compact / subCompact), work branch byte-identical"
  - "29-GREEN-final.txt — full-suite expanded-reporter evidence, all 5 RED-PROOF test names verified green by name"
affects: [29-03 (measures and replaces kSubCompactBreakMinHeight's UNMEASURED PLACEHOLDER), 29-04 (real-browser pixel proof + human UAT checkpoint)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "RED→GREEN wave boundary proven with git, not asserted: git diff --stat <wave-1 commit>..HEAD -- test/ empty, same diff for lib/ lists exactly the two edited files (Phase 28 precedent, reproduced here for a UI change)"
    - "By-name RED→GREEN cross-check (not count-only) against a committed RED evidence file, using --concurrency=1 to avoid the expanded reporter's known per-test-name drop/duplicate bug at default concurrency (28-03 finding)"

key-files:
  created:
    - .planning/phases/29-breaks-you-can-see/29-GREEN-final.txt
  modified:
    - lib/screens/schedule/widgets/chunk_card.dart
    - lib/screens/today/today_screen.dart

key-decisions:
  - "Task 1's acceptance criterion `git diff lib/screens/today/today_screen.dart | grep -c \"kFullTierMinHeight\" returns 0` does not hold under default `git diff` (3 lines of context), because the work branch's `kFullTierMinHeight >= ...` line sits inside the same hunk as the edited break ternary and appears as unchanged context. Verified the actual invariant with `git diff -U0` (no context lines), which returns 0 — the work branch has zero added/removed lines. Documented rather than distorted, matching this phase's own precedent (29-01-SUMMARY.md's plan-authoring-inconsistency section)."

patterns-established: []

requirements-completed: [SEEBREAK-01, SEEBREAK-02]

# Metrics
duration: ~15min
completed: 2026-08-20
---

# Phase 29 Plan 02: Wire the sub-compact tier Summary

**Two edits in `lib/` — a `subCompact` early return in `ChunkCard._buildBreak` and a three-band break density ternary in `today_screen.dart` — turned wave 1's five RED tests green with zero test files touched, proven by git.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-08-20
- **Tasks:** 2/2
- **Files modified:** 2 (lib/), 1 file created (GREEN evidence)

## Accomplishments

- Added the `subCompact` early return to `ChunkCard._buildBreak` (`lib/screens/schedule/widgets/chunk_card.dart`), returning `_SubCompactRow(label: title, semanticsLabel: '$title, ${chunk.durationMinutes} min')`. Placed **above** the `compact` check — verified: `subCompact` at line 158, `compact` at line 168, inside `_buildBreak`.
- Replaced `today_screen.dart`'s two-band break density ternary (lines 789-792) with the three-band form: `full` at or above `kFullBreakMinHeight`, otherwise `compact` at or above `kSubCompactBreakMinHeight`, otherwise `subCompact`. The work branch (byte-identical, verified with `git diff -U0`) and the `Positioned`/`ClipRect`/`OverflowBox`/`TimelineRowTile` wrapper are both untouched.
- All 5 wave-1 RED-PROOF tests now pass; all 3 GUARDs stay green. Targeted suite (`today_row_widgets_test.dart`, `today_screen_test.dart`, `today_timeline_model_test.dart`) is green with `--concurrency=1 --reporter expanded`.
- Captured `.planning/phases/29-breaks-you-can-see/29-GREEN-final.txt`: full suite, `--concurrency=1 --reporter expanded`, **587 passed, 0 failed, 0 `[E]`**. Every one of the 5 RED-PROOF test names cross-checked by name (not count) against `29-RED-subcompact.txt` — all appear in the GREEN file with no `[E]` marker.
- `git diff --stat 6445b0e..HEAD -- test/` is empty; the same diff for `lib/` lists exactly `chunk_card.dart` and `today_screen.dart` — the wave boundary held, proven with git rather than asserted.
- `flutter analyze`: no issues found.
- `testWidgets(` counts unchanged: `today_row_widgets_test.dart` = 57, `today_screen_test.dart` = 64 — nothing deleted.
- `kPixelsPerMinute` and every other `timeline_geometry.dart` constant unchanged (`git diff --exit-code lib/screens/today/timeline_geometry.dart` passes) — D-03 honoured.
- `pubspec.yaml`/`pubspec.lock` unchanged (`git diff --exit-code` passes) — T-29-01 honoured, no package installed.

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire the two reachable call sites** — `9a6ae15` (feat)
2. **Task 2: Capture GREEN evidence, cross-check by name against RED** — `585b95c` (test)

## Files Created/Modified

- `lib/screens/schedule/widgets/chunk_card.dart` — `_buildBreak`'s `subCompact` early return, checked before `compact`, with a comment stating the ordering requirement
- `lib/screens/today/today_screen.dart` — three-band break density ternary; a comment names which tier the current lattice actually reaches (subCompact for every short break, full for every long break, compact a documented dead path)
- `.planning/phases/29-breaks-you-can-see/29-GREEN-final.txt` — created (full-suite GREEN evidence, `--concurrency=1 --reporter expanded`)

## The five RED-PROOF test names, confirmed GREEN by name

All five appear in `29-GREEN-final.txt` with no `[E]` marker (verified with `grep -n` for each exact test description, cross-referenced against no exception block following):

1. `SEEBREAK-01: sub-compact short break renders two Dividers and the label, no dashed border, no duration text` (`today_row_widgets_test.dart`, line 545 of GREEN file)
2. `SEEBREAK-01: sub-compact short break restates the duration in its semantics label` (`today_row_widgets_test.dart`, line 546)
3. `SEEBREAK-01: sub-compact renders shorter than compact for the same break` (`today_row_widgets_test.dart`, line 547)
4. `SEEBREAK-01: SwipeableChunkCard forwards subCompact on the break early-return path` (`today_row_widgets_test.dart`, line 550)
5. `SEEBREAK-01 tier boundary: a break slot below kSubCompactBreakMinHeight renders sub-compact; at the threshold it renders compact` (`today_screen_test.dart`, line 504)

## Git proof of the wave boundary (quoted verbatim)

```
$ git diff --stat 6445b0e..HEAD -- test/
(empty)

$ git diff --stat 6445b0e..HEAD -- lib/
 lib/screens/schedule/widgets/chunk_card.dart | 15 ++++++++++-----
 lib/screens/today/today_screen.dart          | 12 +++++++++++-
 2 files changed, 21 insertions(+), 6 deletions(-)
```

`6445b0e` is `29-01`'s final commit (`docs(29-01): complete every-test-that-defines-a-break-you-can-see plan`).

## Decisions Made

- **Task 1's `kFullTierMinHeight`-in-diff acceptance criterion needed correction, not the code.** The plan's stated check (`git diff lib/screens/today/today_screen.dart | grep -c "kFullTierMinHeight"` returns `0`) fails under default `git diff` because default unified-diff context (3 lines) pulls the unchanged work-branch line `: (slot >= kFullTierMinHeight ...)` into the same hunk as the edited break ternary immediately above it — it shows up as a context line (space-prefixed, not `+`/`-`), which `grep -c` still counts. Re-verified the actual invariant the criterion was trying to assert (the work branch line itself was not added or removed) with `git diff -U0 lib/screens/today/today_screen.dart | grep -c "kFullTierMinHeight"`, which correctly returns `0`. The work branch is confirmed byte-identical; only the check's own diff-context assumption was imprecise. Same class of plan-authoring imprecision `29-01-SUMMARY.md` documented for its own `grep -A6` acceptance criterion — recorded here rather than silently reinterpreted.

## Deviations from Plan

None — plan executed exactly as written, both edits landed as specified, no test file touched, no wave-1 test needed correction (all 5 RED-PROOF tests and 3 GUARDs behaved exactly as `29-01-SUMMARY.md` predicted once the two `lib/` edits landed).

## Issues Encountered

None. No wave-1 test looked wrong — every one of the five RED failures flipped to green on the first run after the two edits, with no iteration required.

## Verification Summary

- Targeted suite (`today_row_widgets_test.dart`, `today_screen_test.dart`, `today_timeline_model_test.dart`), `--concurrency=1 --reporter expanded`: all pass, 5 RED-PROOF + 3 GUARDs all green.
- Full suite, `--concurrency=1 --reporter expanded`: **587 passed**, 0 failed (579 baseline + 8 new, matching the plan's expected total exactly).
- `flutter analyze`: No issues found.
- `git status --porcelain test/`: empty for both tasks — no test file created, modified, or deleted.
- `git diff --exit-code lib/screens/today/timeline_geometry.dart`: passes (D-03, `kPixelsPerMinute` unchanged).
- `git diff --exit-code pubspec.yaml pubspec.lock`: passes (T-29-01).
- Branch order in `_buildBreak`: `subCompact` at line 158, `compact` at line 168 — `subCompact` checked first, as required.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Wave 3 (plan `29-03`) can now replace `kSubCompactBreakMinHeight`'s UNMEASURED PLACEHOLDER (`24.0`) with a real-browser measurement, per the recipe in `29-UI-SPEC.md` — the tier is wired and functionally correct today, so 29-03's job is purely the threshold constant's precision, not new wiring. Plan `29-04` still owns the phase-closing human UAT checkpoint (no automated pass substitutes for it, per `29-UI-SPEC.md`'s "Verification — pixels, and a human").

---
*Phase: 29-breaks-you-can-see*
*Completed: 2026-08-20*

## Self-Check: PASSED

- FOUND: `lib/screens/schedule/widgets/chunk_card.dart`
- FOUND: `lib/screens/today/today_screen.dart`
- FOUND: `.planning/phases/29-breaks-you-can-see/29-GREEN-final.txt`
- FOUND: `.planning/phases/29-breaks-you-can-see/29-02-SUMMARY.md`
- FOUND commit: `9a6ae15` (Task 1)
- FOUND commit: `585b95c` (Task 2)

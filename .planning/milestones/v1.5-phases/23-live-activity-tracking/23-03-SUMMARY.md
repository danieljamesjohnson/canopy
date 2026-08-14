---
phase: 23-live-activity-tracking
plan: 03
subsystem: ui
tags: [flutter, copywriting, today-screen, edge-states]

# Dependency graph
requires:
  - phase: 23-live-activity-tracking (plan 01)
    provides: break-aware _chunkTitle, so a break as GapBeforeNext.next names correctly
  - phase: 23-live-activity-tracking (plan 02)
    provides: the live countdown machinery this plan does not touch
provides:
  - Locked LIVE-03 pre-start copy — "Nothing until <time>" / "The day starts with <activity>. Until then the time is yours."
  - Locked LIVE-03 day-complete copy — "That's the day." / "Everything scheduled is behind you." (no total, no percentage, no score)
  - Decision P-1 recorded in code — the GapBeforeNext "Up next" banner is unchanged from Phase 22, comment-only diff verified
  - A gap targeting a break renders "Short break", not "Work block"
  - Distinctness and copywriting guard tests proving the three edge states cannot satisfy each other's assertions
affects: [23-04-validation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Locked-copy doc comments: PreStart/DayComplete strings carry an explicit 'do not reword without a new design decision' comment pointing at D-03/UI-SPEC, mirroring how P-1 is recorded on GapBeforeNext"
    - "Force-remount between states in a single testWidgets: TodayScreenState._nowFn is `late final`, captured once in initState, so pumping a second schedule/now via the same _pumpTodayScreen call in one test silently keeps the OLD clock. New multi-state tests insert `await tester.pumpWidget(const SizedBox.shrink())` between pumps to force a full teardown/remount."

key-files:
  created: []
  modified:
    - lib/screens/today/today_screen.dart
    - test/screens/today_screen_test.dart
    - test/screens/today_screen_now_state_test.dart

key-decisions:
  - "P-1 (GapBeforeNext ambiguity): the banner does NOT change. 23-CONTEXT.md decision 3 supplied verbatim replacement copy for PreStart/DayComplete but only a description for the gap ('named as free time inline'), which explains why no new gap copy exists rather than instructing its removal. GapFreeRow renders a duration, never a name, so deleting the banner would remove the only place the screen says what is coming next — making the gap read LESS truthfully. Recorded as a doc comment above the GapBeforeNext case; diff to that case is comment-only (verified via git diff)."
  - "Pre-start title source: the plan's own read_first cited a 'Morning routine' rationale fixture; the actual fixture at the cited test line uses `_workChunk`'s default rationale ('Deep work'). Followed the plan's own instruction to 'substitute whatever rationale the fixture under edit actually uses' rather than forcing 'Morning routine' into a fixture that doesn't set it."
  - "'Short break' scoping in the gap-targets-a-break test: the break also renders as its own upcoming ChunkRow further down the day list (chunk_card.dart's _buildBreak), so `find.text('Short break')` legitimately finds 2 widgets, not 1 as the plan's <behavior> literally stated. Scoped the assertion to the edge-state Padding ancestor of 'Up next' so it verifies the specific line under test, matching the plan's actual intent (that _chunkTitle names the break in the edge-state line) without asserting something false about the rest of the screen."

requirements-completed: [LIVE-03]

# Metrics
duration: 25min
completed: 2026-08-07
---

# Phase 23 Plan 03: Locked Edge-State Copy Summary

**Pre-start and day-complete now read the D-03 sketch-001 copy verbatim ("Nothing until 8:00 AM" / "That's the day.", no duration, no score), the GapBeforeNext banner's "leave it alone" decision is recorded in the code with a comment-only diff, and a gap targeting a break correctly reads "Short break" instead of "Work block".**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-08-07T22:02Z (approx.)
- **Completed:** 2026-08-07T22:27:28Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- `_buildEdgeStateLine`'s `PreStart` case now reads "Nothing until 8:00 AM" as the heading and "The day starts with <title>. Until then the time is yours." as the body — the duration fragment (`· N min`) is gone, and the doc comment above the function now states the strings are LOCKED by D-03 and forbids deficit language / score / total.
- The `DayComplete` case now reads "That's the day." / "Everything scheduled is behind you." — a finish line, not a scoreboard; no total, percentage, or count anywhere in the branch.
- Decision P-1 (the `GapBeforeNext` "Up next" banner stays exactly as Phase 22 left it) is recorded as a doc comment directly above the case, with the full reasoning chain from the plan's objective preserved in the code. `git diff` on that region shows comment-only additions — the rendering expressions are byte-identical.
- A new widget test proves the practical consequence of plan 23-01's break-aware `_chunkTitle`: a gap whose `next` chunk is a break renders "Short break" in the edge-state line, never "Work block".
- Two new guard tests (distinctness, copywriting) assert the three edge states cannot satisfy each other's copy and that "behind" appears nowhere except the locked "behind you" phrase in `DayComplete`.
- Full suite green at 455/455 (452 baseline + 3 new cases), `flutter analyze` clean.

## Task Commits

Each task was committed atomically:

1. **Task 1: The pre-start and day-complete copy (D-03, LIVE-03)** - `ddc0544` (feat)
2. **Task 2: Record and prove the gap-banner decision (P-1, D-03, LIVE-03)** - `0f0aad0` (docs)

**Plan metadata:** (this commit)

## Files Created/Modified
- `lib/screens/today/today_screen.dart` - Rewrote `_buildEdgeStateLine`'s doc comment (LOCKED-copy statement), `PreStart` heading/body, and `DayComplete` heading/body to the D-03 strings; added a doc comment above the `GapBeforeNext` case recording decision P-1 (comment-only diff to that case)
- `test/screens/today_screen_test.dart` - Updated the pre-start and day-complete assertions to the new copy; added a gap-targets-a-break case, a distinctness guard, and a copywriting guard to the `Task 3 — centre the live row on open + edge-state copy` group
- `test/screens/today_screen_now_state_test.dart` - Updated pre-start, active, day-complete, all-resolved, gap-state, and timer/lifecycle test names/assertions/reason strings to the new copy

## Decisions Made
- P-1 decided (not re-litigated): the `GapBeforeNext` banner is unchanged from Phase 22. See key-decisions above.
- Followed the plan's own escape hatch on the PreStart fixture's rationale ("substitute whatever the fixture under edit actually uses") rather than forcing a mismatch with `_workChunk`'s actual default.
- Scoped the "Short break" assertion in the new gap-targets-a-break test to the edge-state `Padding` ancestor of "Up next", since the break legitimately also appears as its own list row further down the day (an accurate reflection of the screen, not a bug).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Plan's literal `find.text('Short break') findsOneWidget` assertion was false given actual rendering**
- **Found during:** Task 2 (writing the gap-targets-a-break widget case)
- **Issue:** The plan's `<behavior>` section specified `find.text('Short break')` findsOneWidget for the new gap-targeting-a-break test. In the actual running screen, the break chunk (`b1`) is unresolved and upcoming, so it also renders as its own `ChunkRow` in the day list below the edge-state line (`chunk_card.dart`'s `_buildBreak` renders "Short break" there too) — the assertion as written finds 2 widgets and fails.
- **Fix:** Scoped the assertion to the `Padding` ancestor of the `'Up next'` text (the edge-state line itself), which is what the test is actually meant to verify — that `_chunkTitle(context, next)` names the break correctly in the gap banner, not that "Short break" appears exactly once anywhere on screen.
- **Files modified:** `test/screens/today_screen_test.dart`
- **Verification:** `flutter test test/screens/today_screen_test.dart` — case passes; the unscoped "findsNothing" check for `'Work block'` (the pre-23-01 fallback) still holds globally.
- **Committed in:** `0f0aad0` (Task 2)

**2. [Rule 1 - Bug] Multi-state assertions in a single `testWidgets` silently kept the first state's clock**
- **Found during:** Task 1 (writing the distinctness and copywriting guard tests)
- **Issue:** `TodayScreenState._nowFn` is `late final DateTime Function() _nowFn = widget.now ?? DateTime.now;`, assigned once in `initState`. Re-pumping a second `TodayScreen` widget via `_pumpTodayScreen` a second time within the same `testWidgets` block does not create a new `State` (Flutter reuses the existing `State` when the widget subtree structure is unchanged), so the second pump's `now` closure was silently discarded — the screen stayed on the first pump's clock, producing a false failure (e.g. "Nothing until" still present after pumping a DayComplete-time fixture).
- **Fix:** Inserted `await tester.pumpWidget(const SizedBox.shrink());` between pumps of different states in the same test, forcing a full unmount/remount so the next `_pumpTodayScreen` call gets a fresh `State` (and thus a fresh `_nowFn`).
- **Files modified:** `test/screens/today_screen_test.dart`
- **Verification:** Both multi-state tests (distinctness guard, copywriting guard) pass; `flutter test` full suite green.
- **Committed in:** `0f0aad0` (Task 2)

**3. [Rule 1 - Bug] The `'Up next'` doc-comment quote collided with the plan's own acceptance-criteria grep**
- **Found during:** Task 2, running the plan's own verification greps
- **Issue:** The plan's P-1 doc comment (added above `GapBeforeNext`) initially quoted `'Up next'` with single quotes, matching the exact grep pattern the plan's acceptance criteria uses (`grep -o "'Up next'" ... | wc -l` expected `1`), bumping the count to 2 (comment + code).
- **Fix:** Reworded the comment to use double quotes (`"Up next"`, `"Starts at …"`, `"Starting soon"`) so the comment's prose doesn't collide with the grep pattern used to verify the heading itself still exists exactly once in code.
- **Files modified:** `lib/screens/today/today_screen.dart`
- **Verification:** `grep -o "'Up next'" lib/screens/today/today_screen.dart | wc -l` outputs `1`.
- **Committed in:** `0f0aad0` (Task 2)

---

**Total deviations:** 3 auto-fixed (all Rule 1 — test/verification-gate bugs surfaced by running the plan's own acceptance criteria against the actual codebase, not scope creep). No behavior beyond the plan's own intent changed.

## Issues Encountered
None beyond the deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All three LIVE-03 edge states (pre-start, gap, day-complete) now read distinctly and truthfully, with the copy locked in code comments against future accidental rewording.
- Decision P-1 is settled and recorded; plan 23-04's human-verify checkpoint can present it for Dan's confirmation rather than re-deciding it.
- `now_state.dart`, `live_row_card.dart`, `timeline.dart`, and `time_format.dart` all received zero changes, as required — the countdown/timer machinery from plan 23-02 is untouched.
- No blockers.

---
*Phase: 23-live-activity-tracking*
*Completed: 2026-08-07*

## Self-Check: PASSED

All 3 modified files verified present on disk; both commit hashes (`ddc0544`, `0f0aad0`) verified present in `git log --oneline --all`.

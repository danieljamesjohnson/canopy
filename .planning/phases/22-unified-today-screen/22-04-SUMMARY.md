---
phase: 22-unified-today-screen
plan: 04
subsystem: ui
tags: [flutter, go_router, navigation, tdd]

# Dependency graph
requires:
  - phase: 22-unified-today-screen
    plan: 01
    provides: lib/screens/today/now_state.dart (resolveNowState/NowState), lib/screens/today/timeline.dart
  - phase: 22-unified-today-screen
    plan: 02
    provides: lib/screens/today/widgets/{timeline_row_tile,free_time_row,live_row_card}.dart
  - phase: 22-unified-today-screen
    plan: 03
    provides: lib/screens/today/today_screen.dart (TodayScreen, built but not yet wired into the router)
provides:
  - "lib/router.dart — three-branch router: /today canonical, /schedule kept only to parent /schedule/checkin plus a defensive TodayScreen fallback, exact-match redirect normalising /schedule -> /today after the onboarding gate"
  - "lib/widgets/responsive_shell.dart — three destinations (Today/Goals/Settings), the old four-destination UI-SPEC lock recorded as superseded rather than silently violated"
  - "The unified Today screen is now the app's only Home/Schedule surface — home_screen.dart, schedule_screen.dart, active_chunk_card.dart, now_marker.dart are gone"
affects: [23-live-activity-tracking]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Belt-and-braces dead-route prevention: redirect normalises /schedule -> /today AND the declared /schedule route builds TodayScreen directly, so neither a redirect regression nor a redirect miss can strand the notification-tap entry point"
    - "Per-tick call-count baseline (captured from a known-good single timer) replaces a hardcoded '1 call per tick' assumption in the WR-03 no-double-timer test, since the merged screen legitimately reads the clock from more than one call site per build"

key-files:
  created:
    - test/screens/breathing_pulse_cta_test.dart (renamed from test/screens/home_screen_breathing_pulse_test.dart)
    - test/screens/today_screen_now_state_test.dart (renamed from test/screens/home_screen_now_state_test.dart)
  modified:
    - lib/router.dart
    - lib/widgets/responsive_shell.dart
    - lib/screens/today/today_screen.dart
    - lib/screens/today/widgets/breathing_pulse_cta.dart
    - test/screens/router_redirect_test.dart
    - test/screens/responsive_layout_test.dart
    - test/screens/content_width_constraint_test.dart
    - test/screens/today_screen_test.dart
    - test/end_of_day_card_test.dart
  deleted:
    - lib/screens/home/home_screen.dart
    - lib/screens/home/widgets/active_chunk_card.dart
    - lib/screens/schedule/schedule_screen.dart
    - lib/screens/schedule/widgets/now_marker.dart
    - test/screens/active_chunk_card_test.dart
  moved:
    - lib/screens/home/widgets/end_of_day_card.dart -> lib/screens/today/widgets/end_of_day_card.dart
    - lib/screens/home/widgets/review_banner.dart -> lib/screens/today/widgets/review_banner.dart

key-decisions:
  - "Kept /schedule as a declared route (building TodayScreen) rather than deleting it outright — required so /schedule/checkin still has a parent, and doubles as a defensive fallback if the redirect ever regresses (T-22-14)"
  - "Generalized the WR-03 no-double-timer test from a hardcoded '1 now() call per tick' to a captured per-tick baseline, since TodayScreen reads the clock from 3 call sites per build (date header, resolveNowState, live-row remaining-time calc) versus HomeScreen's 1 — the actual invariant under test (no leaked duplicate timer) is unchanged"
  - "Rewrote historical comments naming the deleted classes (HomeScreen/ScheduleScreen/ActiveChunkCard/NowMarker) to describe them by role instead ('the old Home screen', 'the old plan-view screen') rather than deleting the historical context, per D-09's explicit instruction to update stale notes rather than silently violate them"

requirements-completed: [UNIFY-02]

# Metrics
duration: ~9min
completed: 2026-08-07
---

# Phase 22 Plan 04: Navigation Merge and Cleanup Summary

**Switched the router and shell over to the merged TodayScreen (three destinations, /today canonical, /schedule redirects through an onboarding-gated exact-match check), then deleted the four source files the merge replaced — closing out the second "now" detector (`_buildActiveChunkItems`) that 22-PATTERNS.md flagged as the phase's top risk.**

## Performance

- **Duration:** ~9 min (first commit 15:25:30 → last commit 15:34:50)
- **Started:** 2026-08-07T15:25:30-05:00
- **Completed:** 2026-08-07T15:34:50-05:00
- **Tasks:** 3 completed (Task 1 TDD: RED commit then GREEN commit, plus one Rule-1 fix commit; Tasks 2-3 straightforward)
- **Files modified:** 20 (2 created via rename, 9 modified, 5 deleted, 2 moved, plus 2 renames)

## Accomplishments

- `lib/router.dart`: `initialLocation` is `/today`; the merged branch declares both `/today` (canonical) and `/schedule` (kept solely so `/schedule/checkin` still has a parent, and as a defensive `TodayScreen` fallback builder). The redirect callback keeps the onboarding gate first, then exact-matches `matchedLocation == '/schedule'` to `/today` — never `startsWith`, so `/schedule/checkin` survives in both onboarding states (T-22-13/T-22-15). `lib/main.dart` is untouched; `router.go('/schedule')` on notification tap now resolves through the redirect (T-22-14).
- `lib/widgets/responsive_shell.dart`: `_destinations` collapses from four entries to three (Today/Goals/Settings, dropping Home and Schedule). The file-header comment records that the old UI-SPEC "four destinations" icon lock is superseded by 22-UI-SPEC.md's Navigation contract (D-09), rather than silently violating it.
- Deleted the four replaced source files: `home_screen.dart`, `active_chunk_card.dart`, `schedule_screen.dart`, `now_marker.dart`. Deleting `schedule_screen.dart` removes `_buildActiveChunkItems`, the old first-unresolved-chunk scanner 22-PATTERNS.md flagged as a second, competing "now" detector (P1) — `resolveNowState` is now the only now-detector left anywhere in the codebase (confirmed by grep).
- Migrated the now-state test coverage: `home_screen_now_state_test.dart` → `today_screen_now_state_test.dart`, with the `resolveNowState` unit-test group left byte-identical (the strongest existing asset in this phase) and the widget-pump half repointed at `TodayScreen`/`LiveRowCard`. `active_chunk_card_test.dart` was deleted after checking all 14 of its cases against a coverage map — every assertion already has a home in 22-02's `today_row_widgets_test.dart` LiveRowCard group, `chunk_card_goal_name_test.dart`, or this plan's own now-state suite.
- `content_width_constraint_test.dart` repointed at `TodayScreen`; the permanently-skipped `ScheduleScreen` case is gone (that screen no longer exists — `TodayScreen`'s case is now the single POLISH-01 guard).
- Retired `lib/screens/home/` entirely: `end_of_day_card.dart` and `review_banner.dart` moved to `lib/screens/today/widgets/` (their sole consumer), doc comments updated, empty directory (and its `.gitkeep`) removed. `home_screen_breathing_pulse_test.dart` renamed to `breathing_pulse_cta_test.dart` to match its subject (moved to `lib/screens/today/widgets/` back in plan 22-03).
- Final dead-reference sweep: zero occurrences of `HomeScreen`, `ScheduleScreen`, `ActiveChunkCard`, `NowMarker`, or the string `'/home'` anywhere in `lib/` or `test/` — including comments, which were reworded to describe the deleted screens by role rather than deleted outright (D-09).
- Full suite: 418 tests green (428 baseline + 5 new/changed router-redirect cases − 14 deleted `active_chunk_card_test.dart` cases − 1 now-moot `NowMarker` negative-assertion case in `today_screen_test.dart`), `flutter analyze` clean throughout.

## Task Commits

1. **Task 1: Router branches, /schedule redirect, shell 4-to-3 (D-08, D-09, G2, G3, P6, P7)**
   - RED: `9059689` (test) — 11 router_redirect_test.dart cases written/changed, confirmed 4 meaningfully failing against the pre-merge router
   - GREEN: `226b9d7` (feat) — router + shell implementation, all 11 cases pass
   - Fix: `eda224e` (fix) — repointed the WR-09 regression test's `find.text('Home')` tap to `find.text('Today')`, a direct consequence of the destination rename (Rule 1)
2. **Task 2: Delete the replaced screens and migrate their tests (P1, P5, P13, G4)** - `ea97862` (feat)
3. **Task 3: Tidy the orphaned directories and sweep for dead references (P8, D-09)** - `c84b51b` (chore)

**Plan metadata:** pending (this commit)

## Files Created/Modified

- `lib/router.dart` — three `StatefulShellBranch`es; `/today` canonical, `/schedule` kept as a parent-plus-fallback; exact-match redirect
- `lib/widgets/responsive_shell.dart` — three destinations (Today/Goals/Settings); superseded-lock comment
- `lib/screens/today/today_screen.dart` — imports repointed to the moved `end_of_day_card.dart`/`review_banner.dart`; doc comments no longer name the deleted classes
- `lib/screens/today/widgets/breathing_pulse_cta.dart` — doc comment reworded
- `lib/screens/today/widgets/end_of_day_card.dart`, `review_banner.dart` — moved from `lib/screens/home/widgets/`, doc comments updated
- `test/screens/router_redirect_test.dart` — 4 changed cases (now expect `/today`), 5 new UNIFY-02 cases (notification-tap resolution, checkin survival in both onboarding states, `/today` deep link, NavigationRail destination count/labels)
- `test/screens/responsive_layout_test.dart` — WR-09 tap target repointed to `'Today'`
- `test/screens/today_screen_now_state_test.dart` (renamed) — pumps `TodayScreen`/asserts `LiveRowCard`; WR-03 assertion generalized to a captured baseline
- `test/screens/content_width_constraint_test.dart` — repointed at `TodayScreen`; skipped `ScheduleScreen` case removed
- `test/screens/today_screen_test.dart` — removed the now-moot `NowMarker` negative-assertion case and its dangling import
- `test/end_of_day_card_test.dart` — import repointed to the moved file
- `test/screens/breathing_pulse_cta_test.dart` (renamed) — header comment updated
- Deleted: `lib/screens/home/home_screen.dart`, `lib/screens/home/widgets/active_chunk_card.dart`, `lib/screens/schedule/schedule_screen.dart`, `lib/screens/schedule/widgets/now_marker.dart`, `test/screens/active_chunk_card_test.dart`, `lib/screens/home/.gitkeep` (and the now-empty `lib/screens/home/` directory)

## Decisions Made

- Kept `/schedule` declared (building `TodayScreen`) instead of deleting it, exactly as the plan's `route_strategy` section specifies — required so `/schedule/checkin` keeps a parent route, and doubles as a defensive fallback if the redirect ever regresses.
- Generalized the WR-03 no-double-timer test's assertion from a hardcoded `1` to a captured per-tick baseline (see Deviations below) rather than weakening the invariant or leaving it broken.
- Rewrote historical comments that named the deleted screens/widgets to describe them by role ("the old Home screen", "the old plan-view screen") instead of deleting the historical context outright, per the plan's explicit instruction and D-09.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] WR-09 regression test's tap target broke after the destination rename**
- **Found during:** Task 1 verification (proactive full-suite run before starting Task 2)
- **Issue:** `test/screens/responsive_layout_test.dart`'s WR-09 regression guard taps the real `ResponsiveShell`'s first `NavigationBar` destination by its label text (`find.text('Home')`). Task 1 renamed that destination to "Today", so the tap finder matched zero widgets and threw.
- **Fix:** Repointed the tap to `find.text('Today')`; updated the surrounding comment.
- **Files modified:** `test/screens/responsive_layout_test.dart`
- **Verification:** `flutter test test/screens/responsive_layout_test.dart` → 5/5 green.
- **Committed in:** `eda224e`

**2. [Rule 3 - Blocking] today_screen_test.dart's NowMarker import broke compilation after deleting now_marker.dart**
- **Found during:** Task 2, `flutter analyze` after the file deletions
- **Issue:** `test/screens/today_screen_test.dart` (created in plan 22-03, not in this plan's file list) imports `NowMarker` for a negative assertion ("no NowMarker widget is in the tree"). Deleting `now_marker.dart` in Task 2 made the import unresolvable — a compile error, not a test failure.
- **Fix:** Removed the now-moot import and test case. The file's absence is a stronger guarantee than the runtime assertion ever was — `NowMarker` cannot render if the type doesn't exist.
- **Files modified:** `test/screens/today_screen_test.dart`
- **Verification:** `flutter analyze` → No issues found; full suite green.
- **Committed in:** `ea97862`

**3. [Rule 1 - Bug] WR-03 no-double-timer assertion's hardcoded "1 call per tick" didn't hold for TodayScreen**
- **Found during:** Task 2, first run of the relocated `today_screen_now_state_test.dart`
- **Issue:** The original test counted `now()` calls across one timer tick and asserted exactly `1`, reasoning "one timer = one setState = one resolveNowState call = one now() call." `TodayScreen` legitimately calls `_nowFn()` from three call sites per build (the date header, `resolveNowState`, and the live row's remaining-time calculation) versus `HomeScreen`'s one, so a single legitimate tick produced `3`, not `1` — this is a structural difference in the new screen, not a double-timer bug.
- **Fix:** Captured a per-tick call-count baseline from a known-good single-timer tick, then asserted the post-pause/resume tick count equals that baseline (rather than a hardcoded `1`). This preserves the actual invariant under test (no leaked duplicate `Timer.periodic`) while correctly generalizing to a screen that reads the clock from more than one place per build — a double-timer bug still doubles whatever the baseline is.
- **Files modified:** `test/screens/today_screen_now_state_test.dart`
- **Verification:** `flutter test test/screens/today_screen_now_state_test.dart` → 17/17 green, including the WR-03 case.
- **Committed in:** `ea97862`

---

**Total deviations:** 3 auto-fixed (1 Rule 1 — direct fallout from the destination rename; 1 Rule 3 — blocking compile error from a cross-plan file dependency; 1 Rule 1 — test invariant generalized to hold correctly against the new screen's structure). No scope creep — all three are direct, necessary consequences of this plan's own deletions and renames, not new features.

## Issues Encountered

None beyond the three deviations above, all resolved within the task they surfaced in.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 22 (Unified Today Screen) is complete: UNIFY-01 (plan 22-03) and UNIFY-02 (this plan) are both satisfied. The shell shows Today/Goals/Settings, every existing entry point (notification tap, `/schedule` deep link, `/schedule/checkin`) resolves to a working screen, and the app's only "now" detector is `resolveNowState`.
- Phase 23 (Live Activity Tracking) can now build directly against `TodayScreen`/`LiveRowCard` without any split-screen legacy to reconcile — the seams noted in 22-03's summary (work-only filter, 1-minute ticker, screen-injected `kicker`/`remainingLabel`) are all still in place and untouched by this plan.
- No blockers.

---
*Phase: 22-unified-today-screen*
*Completed: 2026-08-07*

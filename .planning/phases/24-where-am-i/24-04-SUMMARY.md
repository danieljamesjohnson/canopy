---
phase: 24-where-am-i
plan: 04
subsystem: ui
tags: [flutter, dart, scroll-position, uat-gap-closure]

# Dependency graph
requires:
  - phase: 24-where-am-i plan 03
    provides: "Root cause diagnosis: today_screen.dart's centre-on-open gates Scrollable.ensureVisible behind hasLiveRow, true only for Active/Overdue; Dan's DayComplete UAT report routing the fix to this gap-closure plan"
provides:
  - "A second, independent centre-on-open fallback (_nowMarkerKey / _didCentreMarker) that scrolls the now-marker into view for PreStart, GapBeforeNext, and DayComplete — the NowState values that render no live row"
  - "A DayComplete overflow test proving the day list lands scrolled to the bottom (position.pixels == maxScrollExtent) on open, closing Dan's reported gap"
  - "A two-flag regression test proving a PreStart-open marker centring never suppresses a later Active-transition live-row centring"
  - "A rebuilt, re-served debug bundle at http://danserver:8123/ for Dan to re-verify"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Separate one-shot GlobalKey/bool pairs per centre-on-open target (_liveRowKey/_didCentreLiveRow and _nowMarkerKey/_didCentreMarker), gated by mutually-exclusive hasLiveRow conditions, both reset on the same day-boundary condition — extends the existing D-02 centre-on-open idiom rather than replacing it"

key-files:
  created: []
  modified:
    - lib/screens/today/today_screen.dart
    - test/screens/today_screen_test.dart

key-decisions:
  - "Used a SEPARATE _didCentreMarker flag rather than reusing _didCentreLiveRow, per the plan's explicit constraint — verified via the new two-flag regression test, which fails under a single-shared-flag design and passes under this one"
  - "dart format reformatted one line inside Task 1's own DayComplete test (a wrapped expect() call collapsed to one line) while fixing the file's overall format-gate compliance in Task 2; net 0 deletions across the plan's two commits (git diff HEAD~2 --numstat: 83 insertions, 0 deletions) — not a weakening of any pre-existing test, since the touched line was written by this same plan one commit earlier"
  - "Left 3 pre-existing, plan-unrelated files with format drift (commitment_form_sheet.dart, onboarding_screen.dart, swipeable_chunk_card.dart) untouched — out of this plan's scope per the deviation rules' scope boundary; only lib/screens/today/today_screen.dart and test/screens/today_screen_test.dart were formatted, matching the plan's explicit 'do not reformat any file this plan did not touch' instruction"

patterns-established: []

requirements-completed: [NOW-01]

# Metrics
duration: ~35min
completed: 2026-08-08
---

# Phase 24 Plan 04: Marker Fallback Centre-on-Open Summary

**Extended `TodayScreen`'s D-02 centre-on-open with a second, independent `Scrollable.ensureVisible` fallback targeting the now-marker (via a new `_nowMarkerKey`/`_didCentreMarker` pair) for `PreStart`/`GapBeforeNext`/`DayComplete`, the `NowState` values that render no live row — closing Dan's reported `DayComplete` gap from 24-03's UAT.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-08-08T22:38:36Z (immediately following 24-03's completion)
- **Completed:** 2026-08-08T22:59:48Z
- **Tasks:** 2 (both `type="auto"`)
- **Files modified:** 2 (`lib/screens/today/today_screen.dart`, `test/screens/today_screen_test.dart`)

## Accomplishments

- Keyed the `NowMarkerRow`'s `TimelineRowTile` (`KeyedSubtree(key: _nowMarkerKey, ...)`), mirroring the existing `_liveRowKey` idiom for the live row
- Added a marker-fallback centre-on-open block in `build()`, gated by `!hasLiveRow && !_didCentreMarker && hasMarkerRow`, using the exact same `Scrollable.ensureVisible` alignment/duration/curve as the pre-existing live-row block so the two centrings feel identical to the user
- Used a genuinely separate `_didCentreMarker` one-shot flag (not a reuse of `_didCentreLiveRow`), reset alongside it on the same day-boundary condition in `didChangeDependencies`
- Proved the fix closes Dan's exact reported defect: a new `DayComplete` overflow test asserts the day list lands scrolled to the bottom (`position.pixels == maxScrollExtent`) on open — the literal encoding of "things in the past should have to be scrolled to"
- Proved the two-flag design is load-bearing: a new regression test opens `TodayScreen` in `PreStart` (marker-fallback fires, sets `_didCentreMarker`), advances the fake clock into `Active` on the same mounted instance without unmounting, and confirms the live row still centres — a design bug (one shared flag) would make this test fail
- Rebuilt and re-served the debug web bundle at `http://danserver:8123/` for Dan to re-verify

## Task Commits

1. **Task 1: Key the now-marker and add its centre-on-open fallback** — `8fd639e` (feat)
2. **Task 2: Prove the two-flag regression guard, then full-suite gate** — `dc1cb59` (test)

**Plan metadata:** (this commit) `docs(24-04): complete marker-fallback-centre-on-open plan`

## Files Created/Modified

- `lib/screens/today/today_screen.dart` — added `_nowMarkerKey` (`GlobalKey`) and `_didCentreMarker` (`bool`) fields with doc comments explaining why the flag is separate from `_didCentreLiveRow`; wrapped the `NowMarkerRow` case's `TimelineRowTile` in `KeyedSubtree(key: _nowMarkerKey, ...)`; reset `_didCentreMarker = false` in `didChangeDependencies` alongside `_didCentreLiveRow`; added the `hasMarkerRow` / marker-fallback centre-on-open block in `build()` immediately after the existing `hasLiveRow` block
- `test/screens/today_screen_test.dart` — added `'centres the now-marker on open when there is no live row to centre on instead (DayComplete overflow, 24-04)'` and `'opening in PreStart then transitioning to Active still centres the live row (two-flag regression, 24-04)'` to the `'Task 3 — centre the live row on open + edge-state copy'` group

## Decisions Made

See `key-decisions` in frontmatter above. Summary:

1. Separate one-shot flag per centring target — the entire point of the plan's design constraint, verified by a dedicated regression test rather than just asserted.
2. `dart format` was applied only to the two files this plan touched, per the plan's explicit instruction; 3 pre-existing files with unrelated format drift were left alone (out of scope, logged below as deferred).
3. The one line `dart format` reformatted from Task 1's own test (collapsing a wrapped `expect()` call) is not a "deletion of a pre-existing test" in the sense the plan's constraint means — it's this plan's own code being reformatted one commit later. The plan's own "cumulative check across both tasks" acceptance criterion (`git diff HEAD~2 --numstat` showing 0 total deletions) was written precisely to reconcile this, and it holds: 83 insertions, 0 deletions across the whole plan.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `dart format` failed on `test/screens/today_screen_test.dart` before Task 2's gate could pass**
- **Found during:** Task 2, step 4 of the action (the format-gate step)
- **Issue:** `dart format --output=none --set-exit-if-changed lib/` reported 3 changed files, none of which were plan-touched (pre-existing drift, correctly left alone per the plan's "do not reformat any file this plan did not touch" instruction). But the plan's format gate also implicitly covers the test file it modified, and `dart format --set-exit-if-changed test/screens/today_screen_test.dart` separately failed — the file needed reformatting.
- **Fix:** Ran `dart format test/screens/today_screen_test.dart`. The only line affected was `expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);` (Task 1's own DayComplete test), which `dart format` collapsed from a 3-line wrapped call to 1 line. Re-ran the full gate (quick command, full suite, analyze) — all green, unchanged pass counts.
- **Files modified:** `test/screens/today_screen_test.dart` (formatting only, folded into Task 2's commit `dc1cb59`)
- **Verification:** `dart format --output=none --set-exit-if-changed lib/screens/today/today_screen.dart test/screens/today_screen_test.dart` now exits 0; `flutter test` still 502/502; `flutter analyze` still `No issues found!`.
- **Committed in:** `dc1cb59` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 3 — blocking format-gate failure).
**Impact on plan:** Necessary to satisfy the plan's own format-gate verification step. No scope creep — only the two plan-scoped files were touched; the 3 pre-existing drifted files were explicitly left alone.

## Issues Encountered

None beyond the format-gate deviation above.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **Phase 24's own success criterion 1** ("where am I is answerable by looking at the timeline") is now true for `DayComplete`, `PreStart`, and `GapBeforeNext` as well as `Active`/`Overdue` — this was the one gap left open by 24-03.
- **Debug bundle rebuilt and re-served** at `http://danserver:8123/` (Dan's existing schedule data, same origin/build-type as before — no service-worker collision) so Dan can re-verify the `DayComplete` fix without a fresh onboarding flow. `flutter_service_worker.js` was again removed post-build (same documented Flutter 3.44.1 `--pwa-strategy=none` no-op as 24-03; registration never fires at runtime regardless).
- **Phase 24 is NOT marked complete by this plan** — per this plan's own scope, the orchestrator owns that decision after Dan re-verifies.
- **Out of scope, routed to a future phase** (per Dan's explicit routing decision in 24-03-SUMMARY.md, reaffirmed as out of bounds for this plan): a time-proportional calendar view with a moving "now" line, and any general "past items recede/dim/collapse" treatment. Neither was implemented, sketched, or scaffolded here.

---
*Phase: 24-where-am-i*
*Completed: 2026-08-08*

## Self-Check: PASSED

- FOUND: `lib/screens/today/today_screen.dart`
- FOUND: `test/screens/today_screen_test.dart`
- FOUND: commit `8fd639e` (Task 1)
- FOUND: commit `dc1cb59` (Task 2)
- `flutter test` 502/502 passing, `flutter analyze` clean, `dart format` clean on both plan-touched files
- `http://danserver:8123/` verified 200; `/flutter_service_worker.js` verified 404

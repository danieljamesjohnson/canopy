---
phase: 24-where-am-i
plan: 03
subsystem: ui
tags: [flutter, dart, web-build, uat, checkpoint]

# Dependency graph
requires:
  - phase: 24-where-am-i plan 02
    provides: "nowMinutes threaded from build()'s single clock sample; NowMarkerRow rendering end-to-end; 24-VALIDATION.md automated rows all green"
provides:
  - "A served debug web build (http://danserver:8123/, Dan's existing data) that Dan verified in a real browser"
  - "Dan's verbatim perceptual verdict on the now-marker: PARTIAL PASS"
  - "A diagnosed, gap-closure-ready defect (DayComplete never scrolls to the now-marker) routed to plan 24-04"
  - "Two forward feature ideas (auto-scroll past items, time-proportional calendar with a moving now-line) explicitly routed to a new phase, out of 24's scope"
affects: [24-04]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - .planning/phases/24-where-am-i/24-VALIDATION.md

key-decisions:
  - "Debug bundle moved from the executor's fresh build port (8840) to 8123 — the established Canopy debug-UAT origin used in phases 22 and 23-04 — so Dan could look at the marker against his real schedule data instead of being routed through onboarding + a morning check-in on a fresh IndexedDB origin. Same build type on that origin (debug, no service worker), so no service-worker collision per CLAUDE.md's rule against crossing build TYPES on one origin, not reusing a port for the same type. Port 8840 left running as a clean-slate fallback."
  - "--pwa-strategy=none is a deprecated no-op in Flutter 3.44.1 (flutter/flutter#156910) — flutter_service_worker.js is still generated. Verified via build/web/flutter_bootstrap.js that _flutter.loader.load() is called with no arguments, so serviceWorkerSettings is undefined and registration never fires at runtime; the dead file was deleted from the build output and /flutter_service_worker.js re-confirmed as a 404 over HTTP."
  - "The plan's `curl | grep main.dart.js` verify step returns 0 because index.html no longer references main.dart.js directly (flutter_bootstrap.js resolves it at runtime). Substituted verification: /main.dart.js returns 200, flutter_bootstrap.js greps 2 references to it, and a headless boot confirmed the app runs."
  - "Dan's verdict routed per his explicit AskUserQuestion answer: fix the DayComplete defect inside phase 24 via a small gap-closure plan (24-04); the calendar/red-line view becomes its own new phase, not folded into 24."
  - "DayComplete's fix copy left to the executor's judgement (Dan: 'You decide — pick what reads best') — deferred to 24-04, not decided here."

patterns-established: []

requirements-completed: []

# Metrics
duration: ~15min (checkpoint wait excluded)
completed: 2026-08-08
---

# Phase 24 Plan 03: Serve Debug Build and Get Dan's At-a-Glance Verdict — Summary

**Dan's real-browser verdict on the now-marker: mid-day/between-activities case confirmed working ("it did look a lot better"), but the DayComplete state hides the marker off-screen — a small gap-closure plan (24-04) will fix it; two bigger ideas (auto-scroll-past, calendar red-line) got routed to a future phase instead of being folded in here.**

## Performance

- **Duration:** ~15 min of active execution (build, serve, smoke-check, notify) + Dan's async checkpoint response
- **Started:** 2026-08-08 (Task 1)
- **Completed:** 2026-08-08T22:38:36Z
- **Tasks:** 2 (1 auto, 1 checkpoint:human-verify)
- **Files modified:** 1 (`24-VALIDATION.md`) — this plan is verification-only, no `lib/`/`test/` changes

## Accomplishments

- Built and served a single-bundle, source-mapped, debug web build of the post-24-02 tree over the tailnet, dead service-worker file removed
- Got Dan's real-browser perceptual verdict on the one thing no widget test could answer: whether the now-marker is findable at a glance
- Diagnosed the DayComplete defect to an exact file:line root cause and routed the fix to a scoped gap-closure plan (24-04) instead of re-opening this plan's tasks
- Kept Dan's two forward ideas (auto-scroll, calendar red-line) explicitly out of phase 24, per his own routing decision

## Task Commits

1. **Task 1: Build single-bundle debug web build and serve on a fresh port** — build output only (`/build/` is gitignored); no commit. `flutter_service_worker.js` deletion was a build-output cleanup, not a tracked-file change.
2. **Task 2: Dan confirms the marker answers "where am I" at a glance** — checkpoint, resolved via Dan's verbatim response (recorded below). No code changes; this SUMMARY and `24-VALIDATION.md` are the record.

**Plan metadata:** (this commit) `docs(24-03): complete serve-debug-build-and-get-verdict plan`

_Note: This plan produced no `lib/`/`test/` diffs — its output is a build artifact (gitignored) and this documentation._

## Dan's Verdict (verbatim)

> "it did look a lot better when i saw it. but now were 'done' and it's hard to tell. i think
> things int het past should have to be scrolle dto?" or something? could maek it like a calendar
> view as well where as time goes on theres a red line that scrolls downt he page to tell you where
> you are relatively to the time"

**Interpretation, confirmed with Dan via a follow-up question:**

- **PARTIAL PASS.** The mid-day / between-activities case (checkpoint step 2, the main question) is
  a clear improvement — "it did look a lot better."
- **ONE DEFECT:** the `DayComplete` state. When the day is done, it's hard to tell where "now" is.
- **Two forward ideas**, which Dan explicitly routed to a **separate, new phase** (not phase 24):
  past items scrolling out of view as the day progresses, and a time-proportional calendar view
  with a moving red "now" line.

**Dan's routing decision** (via AskUserQuestion): "Fix day-complete in 24, calendar as new phase" —
a small gap-closure plan closes the DayComplete defect inside phase 24; the calendar/red-line view
becomes its own new phase. On what the DayComplete copy/behavior should say: "You decide — pick
what reads best."

## Gaps

**Defect: DayComplete never scrolls the now-marker into view.**

- **Which checkpoint step failed:** step 5 (before day starts / after it ends) — specifically the
  "after it ends" half. Step 2 (the main mid-day question) passed.
- **Expected:** opening the app after the day is complete should put the `Now` row (the last row
  in the list per `timeline.dart:129-131`) somewhere visible, the same way the live row is
  auto-centred when one exists.
- **Observed:** the list opens scrolled to the TOP of the day — which, late in the day, is entirely
  in the past. The `NowMarkerRow` renders correctly and is positioned last, but Dan never sees it
  without manually scrolling to the bottom.
- **`NowState` affected:** `DayComplete` (confirmed by Dan's report). Also shares the same
  untriggered-scroll root cause: `PreStart` and `GapBeforeNext` — neither produces a live row
  either, so the same gate silently skips the same scroll-into-view behavior for those states too,
  though Dan did not report seeing a problem in those states in this UAT pass.
- **Root cause:** `lib/screens/today/today_screen.dart:971-972` gates the D-02 centre-on-open
  behavior behind `hasLiveRow`:
  ```
  final hasLiveRow = timelineRows.any((row) => row is ChunkRow && row.isLive);
  if (!_didCentreLiveRow && hasLiveRow) { ... Scrollable.ensureVisible(_liveRowKey...) }
  ```
  `hasLiveRow` is only true for `Active` and `Overdue`. In `DayComplete` (and `PreStart` /
  `GapBeforeNext`) there is no live row, so the centre-on-open scroll never fires and the list opens
  at its natural top. This is not a missing feature — it's the missing half of a centre-on-open
  behavior that already exists for the live row.
- **Routed to:** plan 24-04 (gap-closure plan), which will key the `NowMarkerRow` and fall back to
  centring on it when there is no live row.

**Out of scope for phase 24 (routed to a new, future phase per Dan's decision):**

- Auto-scrolling/collapsing past items as the day progresses.
- A time-proportional calendar view with a red line that moves down the page to show relative
  position in the day.

Neither idea is a fix to this phase's NOW-01/NOW-02 requirements — both are new visualization
concepts Dan raised in response to seeing the shipped feature, and he explicitly declined to fold
them into phase 24.

## Files Created/Modified

- `.planning/phases/24-where-am-i/24-VALIDATION.md` — Manual-Only Verifications row closed with the
  partial verdict (see below), not marked as a clean pass.
- `build/web/*` (gitignored, not tracked) — debug, source-mapped, single-bundle build served at
  `http://danserver:8123/` (Dan's data) and `http://danserver:8840/` (clean-slate fallback).

## Decisions Made

See `key-decisions` in frontmatter above. Summary:

1. Served on the established debug-UAT port 8123 (Dan's real data) instead of a brand-new port, so
   Dan wasn't forced through onboarding just to look at a marker; original build port 8840 kept
   running as a clean-slate fallback.
2. `--pwa-strategy=none` deletion of the dead `flutter_service_worker.js` file was necessary because
   the flag itself is a documented no-op in this Flutter version (upstream bug, not a project bug).
3. Dan's routing decision (DayComplete fix stays in phase 24 via 24-04; calendar/red-line view
   becomes a new phase) is authoritative and followed as given — not re-litigated here.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `--pwa-strategy=none` doesn't suppress `flutter_service_worker.js` generation**
- **Found during:** Task 1
- **Issue:** The plan's acceptance criterion `test ! -f build/web/flutter_service_worker.js` failed
  after the build — the flag is a documented no-op in Flutter 3.44.1
  ([flutter/flutter#156910](https://github.com/flutter/flutter/issues/156910)); the file is
  generated regardless of the flag.
- **Fix:** Verified from `build/web/flutter_bootstrap.js` that `_flutter.loader.load()` is called
  with no arguments, so `serviceWorkerSettings` is `undefined` and service-worker registration never
  fires at runtime regardless of the file's presence on disk. Deleted the dead file from the build
  output so the acceptance criterion and the "no SW collision" guarantee both hold in practice.
- **Files modified:** `build/web/flutter_service_worker.js` (deleted, gitignored build output — not
  a tracked-file change)
- **Verification:** `/flutter_service_worker.js` → 404 over HTTP, re-confirmed by the orchestrator.
- **Committed in:** N/A — build output only, not tracked by git.

**2. [Rule 1 - Bug] Plan's `main.dart.js` grep verify step returns 0 against a correctly-built app**
- **Found during:** Task 1
- **Issue:** The plan's automated verify (`curl ... | grep -c "main.dart.js"` against `/`) assumes
  `index.html` references `main.dart.js` directly. In this Flutter version `index.html` instead
  loads `flutter_bootstrap.js`, which resolves `main.dart.js` at runtime — so the literal string
  never appears in `/`'s HTML even on a working build.
- **Fix:** Substituted verification: `curl -sI http://danserver:8123/main.dart.js` → `200`,
  `grep -c "main.dart.js" build/web/flutter_bootstrap.js` → `2`, plus a single headless boot check
  confirming the app actually runs (not treated as the verification of record per the plan's own
  caution against relying on headless screenshots).
- **Files modified:** none (verification-only substitution, no source or build-output change)
- **Verification:** All three substitute checks passed; app confirmed reachable and booting.
- **Committed in:** N/A — verification step only.

---

**Total deviations:** 2 auto-fixed (both Rule 1 — build/verification tooling mismatches with the
installed Flutter version, not app bugs). **Impact on plan:** Both were necessary to actually
satisfy the plan's intent (a served, SW-free, verifiably-running debug build) given tooling drift
from the plan's assumptions. No scope creep — no `lib/`/`test/` files touched.

## Issues Encountered

None beyond the two deviations above, which were tooling/version mismatches, not implementation
problems.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **24-04 (gap-closure)** is ready to start: root cause is diagnosed to `today_screen.dart:971-972`,
  the fix shape is known (key the `NowMarkerRow`, fall back to centring on it when `hasLiveRow` is
  false), and the copy for `DayComplete` is left to the implementer's judgement per Dan's
  instruction.
- **Phase 24 is NOT complete.** This plan (24-03) is done, but the phase's own success criterion 1
  ("where am I is answerable by looking at the timeline") is not yet fully true for the
  `DayComplete` state — that's exactly what 24-04 closes.
- A **new phase** (not yet planned) is needed for the calendar/red-line visualization Dan proposed;
  it is out of phase 24's requirements (NOW-01/NOW-02) and should go through normal phase
  proposal/planning, not be tacked onto the gap-closure plan.
- The debug build stays live at `http://danserver:8123/` and `http://danserver:8840/` so Dan can
  re-verify 24-04's fix without a rebuild — 24-04's own checkpoint (if any) should reuse these
  origins rather than opening a third port.

---
*Phase: 24-where-am-i*
*Completed: 2026-08-08*

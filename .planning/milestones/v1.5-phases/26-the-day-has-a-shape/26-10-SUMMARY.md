---
phase: 26-the-day-has-a-shape
plan: 10
subsystem: ui
tags: [flutter, layout, timeline-geometry, gap-closure, hour-axis, now-line]

# Dependency graph
requires:
  - phase: 26-the-day-has-a-shape (plan 09)
    provides: G-01/G-03 now-line chip confinement, leaving G-04/G-05/G-06 (26-UI-REVIEW.md) as the only open gaps
provides:
  - kTimelineEdgePadding constant in TimelineGeometry, reserved at both ends of the rendered range so no Positioned box can ever be clipped by the Stack's default Clip.hardEdge
  - an 'a' AM suffix in formatMinutesCompact, closing the AM/PM asymmetry on the now-line chip
  - two rect-geometry regression tests (G-04, G-05) proven RED against the unfixed code before being accepted
  - a dated 26-UI-SPEC.md amendment (x3: hour axis, now-line, copywriting contract) recording the fix and why Clip.none was rejected
affects: [any future work touching lib/screens/today/timeline_geometry.dart, lib/screens/today/today_screen.dart's Positioned consumers, or lib/utils/time_format.dart]

tech-stack:
  added: []
  patterns:
    - "Edge-padding-inside-the-geometry: a single constant (kTimelineEdgePadding) folded into yFor()/totalHeight() so every consumer inherits a coordinate-system-wide offset automatically, rather than re-deriving it at each Positioned call site"
    - "RED-proof via git checkout HEAD~1 -- <files>: temporarily revert only the implementation files (not the new tests) to prove a new regression test fails against the pre-fix code, then restore"
    - "Real-browser confirmation via localStorage-injected DevClock offset (flutter.dev_clock_offset_micros) in a Playwright launchPersistentContext profile, onboarding once and reusing the profile across multiple simulated-time reloads"

key-files:
  created:
    - .planning/phases/26-the-day-has-a-shape/evidence-26-10/ (10 real-browser screenshots/crops)
  modified:
    - lib/screens/today/timeline_geometry.dart
    - lib/screens/today/today_screen.dart
    - lib/utils/time_format.dart
    - test/screens/today_screen_test.dart
    - test/screens/today_timeline_model_test.dart
    - test/utils/time_format_test.dart
    - .planning/phases/26-the-day-has-a-shape/26-UI-SPEC.md

key-decisions:
  - "Took the 'reserve padding inside TimelineGeometry' fix, not the one-line Clip.none alternative — Clip.none would let the top hour-axis label paint into the header block above the Stack, trading a sheared label for one colliding with body copy"
  - "kTimelineEdgePadding = max(kHourAxisHeight, kNowLineHeight) / 2 = 14.0 (kNowLineHeight, 28.0, is the larger of the two) — a single constant so a future change to either box height stays correct without hand-editing this value"
  - "Applied the padding in exactly one place (TimelineGeometry.yFor/totalHeight) — every consumer (rows, hour hairlines, now-line, centre-on-open scroll target) inherits it automatically; also fixed one pre-existing hard-coded 'top: 0' in today_screen.dart's LeadingFreeRow that only coincidentally equaled yFor(rangeStart) before this change"
  - "'a' suffix for AM in formatMinutesCompact, mirroring the existing 'p' for PM — a one-character addition, not a redesign of the compact format"

requirements-completed: [CAL-01, CAL-02]

# Metrics
duration: ~90min
completed: 2026-08-13
---

# Phase 26 Plan 10: Nothing at the edges gets sheared (G-04, G-05, G-06) Summary

**Reserved a `kTimelineEdgePadding` (14.0px) headroom at both ends of `TimelineGeometry`'s coordinate system — closing the unconditional hour-axis label shear (G-04), the now-line's identical clip at PreStart/DayComplete (G-05), and the AM/PM asymmetry on the now-line chip (G-06) — with the fix proven RED before GREEN and confirmed in a real browser.**

## Performance

- **Duration:** ~90 min
- **Completed:** 2026-08-13
- **Tasks:** 4/4
- **Files modified:** 6 code/test files + 1 doc (26-UI-SPEC.md) + 10 evidence images added

## Accomplishments

- Added `kTimelineEdgePadding = max(kHourAxisHeight, kNowLineHeight) / 2` (14.0) inside `TimelineGeometry`, folded into `yFor()` (every offset) and `totalHeight` (bottom padding added explicitly) — the single-source-of-truth fix from `26-UI-REVIEW.md`, not the rejected `Clip.none` one-liner.
- Fixed a pre-existing hard-coded `top: 0` in `today_screen.dart`'s `LeadingFreeRow` arm that only ever equaled `yFor(rangeStart)` by coincidence (before this change, `yFor(rangeStart)` really was `0`) — left as a literal it would have silently misaligned that row from every other consumer of the new padded geometry.
- Added two rect-geometry regression tests (G-04: first/last `HourAxisLine` rects inside the Stack's bounds; G-05: `NowLineOverlay` rect inside the Stack at the EXACT boundary minute, `nowMinutes == rangeStart`/`rangeEnd`) — both proven RED against the unfixed geometry (temporarily reverted via `git checkout HEAD~1`, both failed with real rect measurements: first label top `170.0 < 180.0`, now-line top `270.0 < 284.0`) before being accepted.
- Added an `'a'` AM suffix to `formatMinutesCompact`, mirroring the existing `'p'` for PM (`"8:10"` → `"8:10a"`), and reviewed every caller/assertion (`grep -rn "formatMinutesCompact" lib/ test/`).
- Rebuilt and served the debug web build on port 8134, confirmed the fix in a real GPU-backed headless browser across 3 independent fresh onboarding sessions plus DevClock-forced PreStart/DayComplete states, and appended 3 dated amendments to `26-UI-SPEC.md`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Reserve edge headroom in TimelineGeometry** - `f08fecd` (fix)
2. **Task 2: Assert painted rects against the Stack's bounds** - `ff79b09` (test)
3. **Task 3: Give AM a marker (G-06)** - `ac39417` (fix)
4. **Task 4: Confirm in a real browser, amend the spec** - `da7d644` (docs)

## Files Created/Modified

- `lib/screens/today/timeline_geometry.dart` - Added `kTimelineEdgePadding` constant and doc comment explaining the `Clip.hardEdge` root cause and the rejected `Clip.none` alternative; `yFor()` adds the padding to every offset; `totalHeight` adds it again at the bottom; `heightFor()`'s doc comment notes the padding cancels out of the difference (unaffected, as required by D-02)
- `lib/screens/today/today_screen.dart` - `LeadingFreeRow`'s `Positioned.top` changed from a hard-coded `0` to `geometry.yFor(geometry.rangeStart)`
- `lib/utils/time_format.dart` - `formatMinutesCompact`'s AM suffix changed from `''` to `'a'`; doc comment and worked examples updated
- `test/screens/today_screen_test.dart` - Updated the "timeline Stack's SizedBox height" test's expected formula (+ `2 * kTimelineEdgePadding`) and the "chip copy" test's expected string (`'9:30'` → `'9:30a'`); added the G-04 and G-05 rect-assertion tests
- `test/screens/today_timeline_model_test.dart` - Updated 3 geometry-unit-test expectations that are a direct function of the new padding (`yFor(rangeStart)`, `totalHeight`, the out-of-range clamp)
- `test/utils/time_format_test.dart` - Updated the 3 bare-AM `formatMinutesCompact` test cases (480, 645, 0) to expect the `'a'` suffix
- `.planning/phases/26-the-day-has-a-shape/26-UI-SPEC.md` - Appended 3 dated (2026-08-13) amendments: the hour-axis `Placement` row (cross-reference), the now-line section (full root cause + fix + why `Clip.none` was rejected), and the Copywriting Contract (`formatMinutesCompact`'s AM suffix)
- `.planning/phases/26-the-day-has-a-shape/evidence-26-10/` - 10 real-browser screenshots/crops: exact-boundary PreStart/DayComplete chips (`5:00a`, `11:00p`, full pills, zoomed crops), fresh-session confirmations of the topmost/bottommost hour-axis labels plus a non-round-minute AM chip (`8:18a`), and the one honest finding below

## Decisions Made

- **`kTimelineEdgePadding = max(kHourAxisHeight, kNowLineHeight) / 2`, not two separate constants.** `kNowLineHeight` (28.0) is currently the larger of the two, so this evaluates to `14.0` — but expressing it as a `max()` means a future change to either box height stays correct without hand-editing a hard-coded number.
- **Applied padding in exactly one place (`TimelineGeometry`).** Verified via `grep -c "kTimelineEdgePadding" lib/screens/today/today_screen.dart` returning `0` — no call site re-derives the offset.
- **Fixed the `LeadingFreeRow` hard-coded `top: 0` as a Rule 1 bug**, not left alone — it was never actually independent of the geometry; it just happened to equal `yFor(rangeStart)` under the old (unpadded) arithmetic, and would have silently drifted out of alignment with every other row now that `yFor(rangeStart)` carries a fixed offset.
- **`'a'` suffix for AM, not a full `" AM"` label.** Mirrors the existing single-character `'p'` for PM exactly — a one-character addition preserves the "compact" contract that motivated this formatter in the first place (D-04), rather than reopening the gutter-width math.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed `LeadingFreeRow`'s hard-coded `top: 0`**
- **Found during:** Task 1 (reading every `yFor`/`totalHeight` consumer per the plan's `<read_first>`)
- **Issue:** `today_screen.dart`'s `LeadingFreeRow` arm hard-coded `Positioned(top: 0, ...)` instead of calling `geometry.yFor(geometry.rangeStart)`. This literal only ever equaled `yFor(rangeStart)` because `yFor` used to return exactly `0` there — a coincidence, not an independent invariant. After Task 1's edge-padding fix, `yFor(rangeStart)` became `14.0` (the padding), so the hard-coded `0` would have silently misaligned this row from every other consumer of the same geometry.
- **Fix:** Changed `top: 0` to `top: geometry.yFor(geometry.rangeStart)`.
- **Files modified:** `lib/screens/today/today_screen.dart`
- **Verification:** `flutter test` — all 558 baseline tests plus the new tests remained green; no test specifically exercises `LeadingFreeRow`'s exact top-offset value, so this fix is verified by consistency with the rest of the geometry contract (heightFor's start argument is `geometry.rangeStart`, which must match this Positioned's own top for the row to render at the correct y) rather than a dedicated new assertion.
- **Committed in:** `f08fecd` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix, Rule 1)
**Impact on plan:** Necessary for correctness — without it, Task 1's own fix would have introduced a new, narrower misalignment bug (the leading free-time row rendering 14px above where it should). No scope creep; found while reading exactly the files the plan's `<read_first>` directed.

## RED/GREEN Observations (Task 2, both required by the plan)

Both new tests were proven RED against the unfixed geometry before being accepted:

1. Temporarily reverted `lib/screens/today/timeline_geometry.dart` and `lib/screens/today/today_screen.dart` to their pre-Task-1 (`HEAD~1`) state via `git checkout HEAD~1 -- <files>`, leaving the new test code (which does not reference `kTimelineEdgePadding` directly, so it stays compilable against either version of the implementation) unchanged.
2. Ran `flutter test test/screens/today_screen_test.dart --name "G-0[45]:"`:
   - **G-04 FAILED:** `Expected: a value greater than or equal to <180.0> Actual: <170.0>` — the first `HourAxisLine`'s top edge sat 10px above the Stack's own top, exactly the shear the finding described.
   - **G-05 FAILED:** `Expected: a value greater than or equal to <284.0> Actual: <270.0>` — the now-line's top edge at the PreStart exact-boundary minute sat 14px above the Stack's own top.
3. Restored `lib/screens/today/timeline_geometry.dart` and `lib/screens/today/today_screen.dart` via `git checkout HEAD -- <files>`, re-ran the same two tests: both **GREEN**.
4. Ran the full suite (560 tests, 558 baseline + 2 new) and `flutter analyze`: both clean.

## Real-Browser Confirmation (Task 4)

Rebuilt (`flutter build web --debug --source-maps --pwa-strategy=none`) and served on **port 8134** (8131/8132/8133 all serving earlier builds of this phase, per CLAUDE.md trap #1). Driven via headless Chromium (`--use-gl=swiftshader --enable-unsafe-swiftshader`, 430×930 viewport) through onboarding, using a `localStorage`-injected `flutter.dev_clock_offset_micros` DevClock offset (26-08-SUMMARY.md's technique) for precise simulated times, in a `launchPersistentContext` profile.

Confirmed all 5 required items, naming the simulated times used:

1. **Topmost/bottommost hour-axis labels render in FULL, not sheared.** `"8 AM"` (Active state, real time and 9:00 AM DevClock-forced) and `"11 PM"` (DayComplete, 11:00 PM / 11:30 PM DevClock-forced) both render completely — no half-cut glyphs.
2. **Neither label collides with the header above or the trailing block below.** Confirmed by direct visual inspection (`g04-*.png`, `g05-*.png` evidence): clear whitespace between the mood chip and the first hairline, and between the last hairline/chip and the bottom nav bar — the exact failure mode the rejected `Clip.none` approach would have caused.
3. **The now-line renders in full at the EXACT boundary.** PreStart: `5:00 AM` (DevClock-forced, `nowMinutes == rangeStart` exactly) and `8:18 AM` (real time, near-boundary) both show a complete, uncut chip pill. DayComplete: `11:00 PM` (DevClock-forced, `nowMinutes == rangeEnd` exactly) and `11:30 PM` (real time) both show the same.
4. **The chip reads with its new AM marker and fits the gutter without ellipsis.** `"5:00a"` and `"8:18a"` both render completely, no truncation.
5. **Mid-day still registers correctly.** The Active-state screenshot (`g04-active-fresh-8am-label-and-live-row.png`) shows the topmost `"8 AM"` hairline, the now-line rule crossing correctly, the live row, the `"9 AM"` hairline, and the following cards all correctly positioned relative to each other after the coordinate shift.

Evidence crops: `.planning/phases/26-the-day-has-a-shape/evidence-26-10/`.

### Honest finding: one degraded headless session, not a shipped defect

While confirming the mid-day (Active) state in a **long-lived, repeatedly-reloaded** headless browser profile (the same profile reused across ~5 sequential DevClock reload cycles), the topmost `"8 AM"` hour-axis label was **absent** from 4 consecutive screenshots (`honest-finding-degraded-session-missing-8am-label.png`), confirmed via a pixel-level scan of the region (`honest-finding-crop-blank-region-pixel-scan.png` — no non-background pixels in the expected label region across the full scanned width).

This was investigated rather than dismissed:

1. A throwaway widget-test probe (deleted after use, never committed) reproduced the exact same fixture shape (`firstStart=490`, `now=540`, live `520–545`) and confirmed `HourAxisLine(hourMinutes: 480)` genuinely exists in the tree with rect `(40.0, 50.0)–(760.0, 70.0)` — safely inside the Stack's bounds. The underlying geometry and widget tree are correct.
2. Three independent **fresh** `launchPersistentContext` profiles (never previously reloaded) were driven through onboarding and the same Active-state check, real time and DevClock-forced alike — all three rendered the topmost label correctly, including one that showed both the hour-axis label AND a non-coincident now-line chip (`8:18a`) simultaneously, fully legible.

Conclusion: this is the headless-Chromium repaint/GPU-context degradation CLAUDE.md documents as a known automation artifact ("Repeatedly launching headless Chromium... triggers WebGL context loss... this is an automation artifact, not a real browser bug"), surfacing here as an intermittent single-widget repaint miss after repeated reloads in one long-lived session rather than a full blank page. It is **not** treated as a finding against this fix — the geometry is independently verified correct by both the widget-test probe and 3 fresh real-browser sessions — but it is documented here rather than silently omitted, per this repo's own stated convention of keeping the `.planning/` trail honest.

## Known Stubs

None.

## Threat Flags

None — layout padding, a rendering bound, and a date-format suffix on locally-rendered data. No network, auth, persistence, input parsing, or new dependency (matches the plan's own threat model).

## Server for Dan to look at

Debug build served at **`http://danserver:8134/`** (fresh port — 8131/8132/8133 all serve earlier builds of this phase). Server process left running (`python3 tools/serve-uat.py 8134 --dir build/web`, background, `no-store` headers). To see the fix: open a fresh onboarding flow, generate a day, then use Settings → Debug → Time travel to reach `PreStart` (before the day starts) or `DayComplete` (well after the last chunk ends) and check the now-line chip renders in full at the top/bottom edge; scroll to the top/bottom of the day to check the hour-axis labels.

## Next Phase Readiness

`26-UI-REVIEW.md`'s three findings (G-04, G-05, G-06) are closed. `26-06-PLAN.md` remains the other `incomplete_plans` entry for this phase per `init.execute-phase` — not addressed by this plan (out of this plan's scope; see that plan file for its own status).

---
*Phase: 26-the-day-has-a-shape*
*Completed: 2026-08-13*

## Self-Check: PASSED

All 7 files referenced above (`lib/screens/today/timeline_geometry.dart`, `lib/screens/today/today_screen.dart`, `lib/utils/time_format.dart`, `test/screens/today_screen_test.dart`, `test/screens/today_timeline_model_test.dart`, `test/utils/time_format_test.dart`, `.planning/phases/26-the-day-has-a-shape/26-UI-SPEC.md`) confirmed present on disk. All 4 task commit hashes (`f08fecd`, `ff79b09`, `ac39417`, `da7d644`) confirmed present in `git log`. All 10 evidence files confirmed present in `evidence-26-10/`.

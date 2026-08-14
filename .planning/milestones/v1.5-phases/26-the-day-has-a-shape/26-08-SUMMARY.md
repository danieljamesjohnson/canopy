---
phase: 26-the-day-has-a-shape
plan: 08
subsystem: ui
tags: [flutter, layout, timeline-geometry, gap-closure]

# Dependency graph
requires:
  - phase: 26-the-day-has-a-shape (plan 01)
    provides: kLiveRowReservedHeight and the liveExtraPx reservation mechanism in TimelineGeometry
  - phase: 26-the-day-has-a-shape (plan 07)
    provides: closed G-01 (now-line chip confinement), leaving G-02 as the only open gap
provides:
  - kLiveRowReservedHeight corrected from a flutter-test-derived 240.0 to a real-browser-measured 232.0
  - a G-02 pinning unit test asserting the constant stays tight against the real-browser figure
  - a dated 26-UI-SPEC.md amendment recording the measurement, honestly noting the correction is smaller than the original ~80px estimate suggested
affects: [any future work touching lib/screens/today/timeline_geometry.dart or LiveRowCard's children/typography]

tech-stack:
  added: []
  patterns:
    - "Real-browser pixel measurement via headless Chromium + localStorage-injected DevClock offset (bypasses fiddly UI clicking for precise simulated-time control)"

key-files:
  created:
    - .planning/phases/26-the-day-has-a-shape/evidence-26-08/ (8 before/after screenshots)
  modified:
    - lib/screens/today/timeline_geometry.dart
    - test/screens/today_timeline_model_test.dart
    - .planning/phases/26-the-day-has-a-shape/26-UI-SPEC.md

key-decisions:
  - "kLiveRowReservedHeight = 232.0 (224px measured work-variant natural height + 8px explicit margin, the tight end of the plan's stated 8-16px range)"
  - "Measured via headless Chromium + a localStorage-injected DevClock offset (flutter.dev_clock_offset_micros) rather than clicking the +1h/-1h/absolute-time-picker UI controls — gives exact simulated-time control from a computed target instead of coarse 1-hour jumps"
  - "Documented the honest finding that the real-browser figure (224) is close to the old flutter-test figure (230) — only 6px apart — because LiveRowCard's height is dominated by fixed-size elements (padding, SizedBox gaps, button heights) rather than text-driven wrapping, unlike kGutterWidth's width/glyph-advance measurement which was heavily distorted"

requirements-completed: [CAL-01]

duration: ~45min
completed: 2026-08-11
---

# Phase 26 Plan 08: Tighten the live-row reservation (G-02) Summary

**Corrected `kLiveRowReservedHeight` from a flawed `flutter test` measurement (240.0) to a real-browser measurement (232.0) against the work-variant `LiveRowCard`, closing the last open gap (G-02) from `26-UAT.md`.**

## Performance

- **Duration:** ~45 min
- **Completed:** 2026-08-11
- **Tasks:** 3/3
- **Files modified:** 3 (`timeline_geometry.dart`, `today_timeline_model_test.dart`, `26-UI-SPEC.md`) + 8 evidence images added

## Accomplishments

- Measured `LiveRowCard` in a real GPU-backed browser (headless Chromium, `--use-gl=swiftshader`, 430px viewport, debug build served via `tools/serve-uat.py` on port 8132) for both the work variant (tallest, carries the Complete/Skip action row) and the break variant (shorter, no action row per Phase 23's LIVE-01)
- Set `kLiveRowReservedHeight = 232.0` (224px measured work-variant natural height + 8px explicit safety margin), sized against the tallest variant so it can never clip
- Added a pinning unit test (`G-02: live-row reservation is tight against the real-browser measurement`) that fails if the constant drifts either below the measured floor (clipping risk) or more than 16px above it (regression toward a loose estimate)
- Appended a dated, honest amendment to `26-UI-SPEC.md` recording both measurements and explicitly noting the correction (240→232, 8px) is smaller than the ~80px dead space originally described in `26-UAT.md`, because the real-browser and harness figures for this specific card were closer than expected
- Left the debug build served at `http://danserver:8132/` for Dan to inspect

## Task Commits

Each task was committed atomically:

1. **Task 1 (measurement) + Task 2 (set the constant and pin it)** - `1a8ff9e` (fix) — Task 1 was exploratory (browser measurement, no file changes of its own); its findings are recorded in Task 2's commit, which changes the constant and doc comment
2. **Task 3: Confirm in the browser, then amend the UI-SPEC** - `a87d0a9` (docs)

_No plan-metadata commit yet — see below; STATE.md/ROADMAP.md updates follow this SUMMARY and are committed together._

## Files Created/Modified

- `lib/screens/today/timeline_geometry.dart` - `kLiveRowReservedHeight` 240.0 → 232.0; doc comment rewritten to record the real-browser measurement (date, viewport, both variants, the 8px margin and its reasoning, the kGutterWidth precedent, and what would invalidate the value), with the superseded `flutter test`-derived PD-2 note kept below for history
- `test/screens/today_timeline_model_test.dart` - Two existing tests that hardcoded the `240.0` literal now reference `kLiveRowReservedHeight`; added a new `G-02` pinning test asserting the constant stays within `[measured, measured+16]` of the real-browser figure
- `.planning/phases/26-the-day-has-a-shape/26-UI-SPEC.md` - Appended a dated amendment (2026-08-11) to "The live row exception" section, per the repo's convention of visible dated amendments rather than rewriting original spec text
- `.planning/phases/26-the-day-has-a-shape/evidence-26-08/` - 8 screenshots: full-page and cropped before/after (240.0 vs 232.0) for both the work-live and break-live states

## Real-browser measurements (both variants, as required)

Captured via headless Chromium (`--use-gl=swiftshader --enable-unsafe-swiftshader`), viewport 430×930 (DPR 1, so screenshot px = logical px), debug build (`flutter build web --debug --source-maps --pwa-strategy=none`) served via `tools/serve-uat.py 8132 --dir build/web`.

Simulated time was set precisely by writing `localStorage['flutter.dev_clock_offset_micros']` directly (the key `DevClock` persists to, prefix confirmed from `shared_preferences_web`'s `_defaultPrefix = 'flutter.'`) and reloading, rather than clicking the coarse `+1h`/`-1h` UI buttons — this gives exact target times instead of 1-hour-granularity jumps.

Generated schedule for the profile used: work chunk "Exercise" 8:00–8:25 AM, followed by a 5-minute short break 8:25–8:30 AM.

| Variant | Simulated time used | What's showing | Screenshot-measured `primaryContainer` fill | + Card's own 24px vertical margin | Natural height |
|---|---|---|---|---|---|
| **Work** (tallest — has Complete/Skip action row) | 8:10 AM (10 min into the 25-min chunk) | "RIGHT NOW · 8:00 AM / Exercise / 15 min left..." with action row | 200px (y=218→417 at x=250/350, tested across 4 columns) | +24px | **224px** |
| **Break** (sanity-check — no action row per LIVE-01) | 8:27 AM (2 min into the 5-min break) | "RIGHT NOW — RESTING · 8:25 AM / Taking a break..." no action row | 158px (y=355→512) | +24px | **182px** |

This is real-browser evidence, **not** a `flutter test` measurement — `flutter test`'s placeholder font has no real Roboto metrics and is exactly the class of quantity `26-VALIDATION.md` routes to the manual-only gate (the same failure mode that took `kGutterWidth` 46→75→52).

`kLiveRowReservedHeight = 224 (work, measured) + 8 (explicit margin) = 232.0`.

## Browser confirmation (Task 3)

Re-verified against the rebuilt debug bundle at the same two simulated times:

1. **Dead space reduced:** the "Short break" divider and the following "Side project" card now sit 8px higher than under the 240.0 build (confirmed by re-measuring the gap between the live card's bottom edge and the next non-background content, in both the work-live and break-live states — the shift is exactly 8px in both, matching the arithmetic: `liveExtraPx = kLiveRowReservedHeight - liveDurationPx`, so any change to the constant shifts every subsequent row by exactly that amount regardless of which chunk type is live). Before/after crops: `evidence-26-08/g02-work-before-240.png` / `g02-work-after-232.png`, `g02-break-before-240.png` / `g02-break-after-232.png`.
2. **Not clipped:** re-measuring the green `primaryContainer` fill in the post-fix screenshots gives the identical 200px (work) / 158px (break) content heights as before the constant change — `LiveRowCard` itself is untouched, only the space reserved around it changed. Both fit comfortably under 232.0 (break) and exactly at the sized target (work, by construction). The work variant's Complete/Skip action row and "Next" line are both fully visible in `evidence-26-08/g02-work-full-after.png`.
3. **Downstream alignment intact:** the "Side project" card's displayed start time still reads "8:30 AM" in both before/after screenshots — its data-driven label is independent of layout position. Its on-screen Y position is `geometry.yFor(830)`, computed by the same formula as every other row, so it shifted up consistently with everything else; nothing desynchronized. Hour hairlines and the "9 AM" label below still line up with the corresponding row boundaries in `g02-work-full-after.png`.

## Honest finding — the correction is smaller than G-02's original estimate implied

`26-UAT.md` described "~80px of dead space" against a break live row. The corrected reservation (232.0) still leaves `232 - 182 = 50px` of dead space when a break is live — a real, visible gap, but not eliminated. This is not a shortfall in this plan's execution: the mechanism (unchanged per Dan's 2026-08-11 decision) reserves a single fixed height sized against the **tallest** variant (work, to avoid ever clipping it), so a shorter break live row will always leave some dead space beneath it. The **plan's actual target** — tightening the number that was wrong, not eliminating all dead space — is what was delivered. The old `240.0` and the real-browser `224` work-variant figure turned out to be close (6px apart) because `LiveRowCard`'s height is dominated by fixed-size elements (36px padding, `SizedBox` gaps, ~40px button row) rather than text-driven wrapping — unlike `kGutterWidth`, which measured glyph-advance *width*, the exact quantity the placeholder font distorts most. This is recorded in both the constant's doc comment and the UI-SPEC amendment so a future reader isn't surprised the number barely moved.

## Decisions Made

- **8px margin (the tight end of the plan's 8–16px range), not 16px.** Chosen to maximize the honest, measurable reduction in dead space rather than picking a number that would erase nearly all of the improvement (16px would have landed at 240 — literally unchanged from the value being fixed). Documented as absorbing only minor cross-renderer/DPI anti-aliasing variance, explicitly not a full second-line title wrap (~28–32px), which remains an accepted residual risk.
- **Measured via `localStorage` DevClock injection, not UI clicks.** `DevClock` persists its offset to `SharedPreferences`, which on web resolves to `localStorage['flutter.<key>']` (prefix confirmed from the `shared_preferences_web` package source). Writing this directly and reloading gives exact target times computed from the observed schedule ("Exercise 8:00–8:25 AM"), rather than the coarse 1-hour `+1h`/`-1h` buttons the plan's `<action>` text suggested — more precise and used a `launchPersistentContext` profile so onboarding only had to run once across both measurement passes.
- **Pinning test asserts a range, not an exact literal.** `[measured, measured + 16]` so a future `LiveRowCard` content change that legitimately shifts the real height doesn't require touching this test's constant by hand, while still catching both a clipping regression and a return to a loose, unmeasured estimate.

## Deviations from Plan

None — plan executed as written. Task 1's browser-driving approach (localStorage injection instead of UI-button clicks) is a technique substitution within the same task, not a scope deviation; it achieves the same "measure both variants in a real browser" requirement more precisely.

## Known Stubs

None.

## Threat Flags

None — this plan only changes a layout constant. No new network, auth, file-access, or schema surface.

## Server for Dan to look at

Debug build served at **`http://danserver:8132/`** (fresh port per CLAUDE.md trap #1 — 8131 was already serving a prior build of this phase). Server process left running (`python3 tools/serve-uat.py 8132 --dir build/web`, background, `no-store` headers via `tools/serve-uat.py`). To see the fix: open a fresh onboarding flow, generate a day, then use Settings → Debug → Time travel (or the `+1h`/`-1h`/absolute picker) to land inside a live work chunk or break and compare the space below the live card to the pre-fix evidence screenshots in `evidence-26-08/`.

## Self-Check: PASSED

All files and commit hashes referenced above were verified present on disk / in `git log` after writing this SUMMARY.

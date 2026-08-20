---
phase: 29-breaks-you-can-see
plan: 03
subsystem: ui
tags: [flutter, timeline-geometry, real-browser-measurement, pixel-count, port-8143]

# Dependency graph
requires:
  - phase: 29-breaks-you-can-see
    plan: 02
    provides: "The subCompact tier wired and functionally correct: ChunkCard._buildBreak's subCompact early return, today_screen.dart's three-band break density ternary, kSubCompactBreakMinHeight still at its 24.0 UNMEASURED PLACEHOLDER"
provides:
  - "kSubCompactBreakMinHeight replaced with a real-browser measurement (32.0 = 22px raw ink extent + 8.0px explicit margin, rounded up to the nearest 4dp), doc comment rewritten wholesale in house style"
  - "measure_card_extent.py, a new committed pixel-count script: derives background colour from a bounded scan window, flags ink rows, groups into bridge-tolerant bands, prints the overall extent -- reusable for the break card here and the work-chunk fit check in 29-04"
  - "compact-long-break-forced.png, evidence screenshot of the forced-compact Long break card"
  - "Port 8143 claimed permanently as this phase's debug-build-only port, proven served-bytes-identical-to-built-bytes via sha256 before any pixel was trusted"
  - "The throwaway kFullBreakMinHeight=999.0 forcing edit applied and fully reverted, both proven by grep and git diff --stat"
affects: ["29-04 (rebuilds with this measured constant, re-serves on 8143, proves the grid in pixels, and closes the phase with a human UAT checkpoint)"]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bounded-window ink-extent measurement (measure_card_extent.py): derive background colour from the scan window itself, flag any differing pixel as ink, group into bridge-tolerant bands, print the overall first-to-last-inked-row extent -- generalizes measure_hours.py's approach for a target with no solid fill colour (a dashed outline), reusable for any bounded card region"
    - "Forcing an unreachable density tier to render for measurement via a single labelled THROWAWAY constant edit, reverted at the top of the next task before the measured value is set -- cheaper than a --dart-define gate or a throwaway debug route for a one-off measurement"

key-files:
  created:
    - .planning/phases/29-breaks-you-can-see/tools/measure_card_extent.py
    - .planning/phases/29-breaks-you-can-see/shots/compact-long-break-forced.png
  modified:
    - lib/screens/today/timeline_geometry.dart

key-decisions:
  - "kSubCompactBreakMinHeight = 32.0 (22px raw measured ink extent + 8.0px explicit margin for the compact card's own vertical:4 margin = 30.0, rounded UP to the nearest 4dp per 29-UI-SPEC.md step 8's 'does it fit' rounding rule)"
  - "32.0 is 4dp from kNowLineHeight (28.0) -- within the Pitfall 3 'decide explicitly' trigger. Decided: kept separate, not collapsed. kNowLineHeight is the now-line overlay's own fixed box height (always-present UI chrome, unrelated to any chunk's content); kSubCompactBreakMinHeight is a break-card density-selection threshold compared against a chunk's slot height. No shared widget, no shared content, no reason to move together -- the 4dp gap is coincidence between two independently derived numbers."
  - "measure_card_extent.py adapts measure_hours.py's derive-background-then-flag-differing-pixels method, not measure_card_fill.py's saturated-fill-colour method -- the compact break card has no solid fill, only a dashed outlineVariant stroke, so there is no fill colour to derive"
  - "Scan window for the isolated measurement tightened from the plan's suggested 'centre +/- 80' (528..688, which pulled in the previous card's Skip button and the neighbouring 'Short break' divider) to 592..624, isolating just the Long break card's own band -- confirmed correct with a wider diagnostic window (580..650) showing the divider as a separate, non-merged band 7 rows above"

requirements-completed: [SEEBREAK-01]

# Metrics
duration: ~35min
completed: 2026-08-20
---

# Phase 29 Plan 03: Measure `kSubCompactBreakMinHeight` in a real browser Summary

**`kSubCompactBreakMinHeight` is now a real-browser pixel measurement (32.0, not the 24.0 estimate) — measured by forcing the unreachable `compact` break tier onto a 30-minute break's 120dp slot, pixel-counting its dashed-outline card with a newly committed `measure_card_extent.py`, and adding an explicit margin term before rounding up to the nearest 4dp.**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-08-20
- **Tasks:** 2/2
- **Files modified:** 1 (`lib/`)
- **Files created:** 2 (1 script, 1 screenshot)

## Accomplishments

- **Claimed port 8143.** `grep -rn "8143" . --exclude-dir=.git` returned hits only inside this phase's own plans/docs (no pre-existing use elsewhere); `ss -ltn`/`lsof -i :8143` showed nothing listening.
- **Applied and later fully reverted the throwaway forcing edit (PD-29-03).** `kFullBreakMinHeight` was temporarily raised `88.0` → `999.0`, labelled `// THROWAWAY — 29-03 measurement only, reverted in Task 2`, which pushed the 30-minute long break's 120dp slot into the unreachable `compact` tier (the only break with enough room to render `compact` unclipped). Reverted at the top of Task 2; both `grep -c "kFullBreakMinHeight = 88.0"` → `1` and `grep -c "THROWAWAY"` → `0` confirm the revert.
- **Built and served debug, proved served bytes were built bytes BEFORE trusting any pixel (PD-29-05).** `flutter build web --debug --source-maps --pwa-strategy=none`, served on `8143` via `tools/serve-uat.py`. `sha256sum` of the curl'd `main.dart.js` and `build/web/main.dart.js` matched exactly (`c701029a71b987e08227558fdbc2c3d3c6bf66633bb3fb89aa672044c49c8445`); secondary content check `grep -c 'Long break'` returned `2`.
- **Drove to the forced-compact Long break card with `drive.cjs`** on a fresh profile (`/tmp/canopy-p29-profile`; this origin had never onboarded). The generated day placed the long break after a 10:30–10:55 AM Exercise chunk. Used `--dump` first to locate the "Long break" semantics node, then `--scroll=550` to bring it into view, capturing `compact-long-break-forced.png`. Opened with the Read tool and confirmed by eye: a dashed-outline card reading "Long break" is fully visible, with clear background above (the "Short break" divider, then a gap) and below.
- **Wrote `measure_card_extent.py`** (PD-29-04): derives the background colour from the scan window via a `Counter` (survives a theme change), flags any pixel beyond a tolerance as ink, groups contiguous-or-near ink rows into bridge-tolerant bands (tuned for a dashed, non-contiguous outline), and prints each band plus the overall ink extent. Explicitly adapted from `measure_hours.py`'s derive-background approach, not `measure_card_fill.py`'s saturated-fill approach — the dashed break card has no solid fill to derive a colour from.
- **Measured the isolated Long break card:** `--x0=60 --x1=414 --top=592 --bottom=624 --bridge=3 --minband=1` → single band, rows `595..616`, height `22`. A wider diagnostic window (`580..650`) confirmed the "Short break" divider above is a separate, non-merged band (rows `580..587`) with a clear 7-row gap, and nothing appears below `616` through `650` — the 22px band is the card's own extent, not an artifact of the window's edges. At `--bridge=0` (no bridging at all) the overall extent is still `595..616` — the measurement is robust to the bridge tolerance, only the internal band grouping changes.
- **Set the constant (D-04):** `22px` raw extent `+ 8.0px` explicit margin (the compact card's own `margin: EdgeInsets.symmetric(vertical: 4)`, invisible to a pixel scan but real reserved vertical space) `= 30.0`, rounded **up** to the nearest 4dp `= 32.0`.
- **Rewrote the doc comment wholesale** in `kCompactLiveMinHeight`'s house style: date, viewport, method (Chromium flags, debug build, `serve-uat.py`, port `8143`), how the unreachable tier was forced to render and why that trick is valid, the raw-extent-to-final arithmetic, the numerically-close-sibling decision (`32.0` is 4dp from `kNowLineHeight`=`28.0` — kept separate, different role, coincidental proximity; 56dp from every `88.0` constant; 12dp from `kHourAxisHeight`=`20.0`), and an invalidation paragraph. `grep -c "UNMEASURED"` → `0` (including two historical references to prior constants' unmeasured-estimate history, reworded to avoid the literal string while keeping the information).
- **Suite green, analyze clean, no fixture touched.** `flutter analyze`: no issues. `flutter test --concurrency=1`: **587 passed, 0 failed** — identical total to 29-02's baseline. The Phase 29 tier-boundary test (`test/screens/today_screen_test.dart`, written against the `kSubCompactBreakMinHeight` symbol, not a literal) survived the constant moving `24.0` → `32.0` unchanged, confirming the derivation was value-independent as intended.
- `git diff --exit-code pubspec.yaml pubspec.lock` passes in both tasks — no dependency change.
- Stopped the port-8143 background server (T-29-06) once the measurement work was complete; 29-04 restarts it for the human UAT checkpoint.

## Task Commits

Each task was committed atomically:

1. **Task 1: Stand up port 8143, write the measurement script, and capture the forced-compact break screenshot** — `1c44c67` (feat)
2. **Task 2: Set `kSubCompactBreakMinHeight` from the measurement, rewrite its doc comment, and tear the forcing edit back out** — `354dd0c` (fix)

## Full `measure_card_extent.py` output (isolated window)

```
$ python3 .planning/phases/29-breaks-you-can-see/tools/measure_card_extent.py .planning/phases/29-breaks-you-can-see/shots/compact-long-break-forced.png --x0=60 --x1=414 --top=592 --bottom=624
.planning/phases/29-breaks-you-can-see/shots/compact-long-break-forced.png
  size=430x930 bg=(245, 251, 246) x0=60 x1=414 scan=592..624 bridge=3 minband=1 tol=40
  band rows 595..616  height=22
  OVERALL INK EXTENT: rows 595..616  height=22
```

**Wider diagnostic window** (confirms isolation — the neighbouring divider is a separate band, nothing else nearby):

```
$ python3 .planning/phases/29-breaks-you-can-see/tools/measure_card_extent.py .planning/phases/29-breaks-you-can-see/shots/compact-long-break-forced.png --x0=60 --x1=414 --top=580 --bottom=650
.planning/phases/29-breaks-you-can-see/shots/compact-long-break-forced.png
  size=430x930 bg=(245, 251, 246) x0=60 x1=414 scan=580..650 bridge=3 minband=1 tol=40
  band rows 580..587  height=8
  band rows 595..616  height=22
  OVERALL INK EXTENT: rows 580..616  height=37
```

**Verify (no window args, per the plan's own `<verify>`)** — confirms the script runs cleanly end to end and the target band (`595..616`, height `22`) is present among the full-page band list:

```
$ python3 .planning/phases/29-breaks-you-can-see/tools/measure_card_extent.py .planning/phases/29-breaks-you-can-see/shots/compact-long-break-forced.png
...
  band rows 578..587  height=10
  band rows 595..616  height=22
  band rows 835..836  height=2
  ...
  OVERALL INK EXTENT: rows 0..914  height=915
```

## Sha256 / content check (recorded exactly as required)

```
$ curl -s http://localhost:8143/main.dart.js | sha256sum
c701029a71b987e08227558fdbc2c3d3c6bf66633bb3fb89aa672044c49c8445  -
$ sha256sum build/web/main.dart.js
c701029a71b987e08227558fdbc2c3d3c6bf66633bb3fb89aa672044c49c8445  build/web/main.dart.js
$ curl -s http://localhost:8143/main.dart.js | grep -c 'Long break'
2
```

## Arithmetic (extent -> +8 -> round-up)

```
22 (raw measured ink extent, px)
+ 8.0 (explicit margin, the compact card's own vertical:4 EdgeInsets margin)
= 30.0
round UP to nearest 4dp
= 32.0
```

## Files Created/Modified

- `lib/screens/today/timeline_geometry.dart` — `kFullBreakMinHeight` forced to `999.0` then reverted to `88.0`; `kSubCompactBreakMinHeight` set to `32.0` with a wholly rewritten house-style doc comment
- `.planning/phases/29-breaks-you-can-see/tools/measure_card_extent.py` — new committed Pillow script, bounded-window ink-extent measurement
- `.planning/phases/29-breaks-you-can-see/shots/compact-long-break-forced.png` — evidence screenshot of the forced-compact Long break card

## Decisions Made

- **`32.0` kept separate from `kNowLineHeight` (`28.0`, 4dp apart)**, per Pitfall 3's "decide explicitly" rule — different semantic role (fixed overlay chrome height vs. a break-card density threshold), no shared widget or content, coincidental proximity between two independently derived numbers. Documented directly in the constant's doc comment, not just here.
- **Scan window narrowed from the plan's suggested "centre ± 80" to a tighter, empirically-verified 592..624** — the wider window pulled in unrelated content (the previous card's Skip button, the neighbouring "Short break" divider). Narrowed after inspecting the screenshot directly (cropped and read with the Read tool) and cross-checked with a wider diagnostic window to confirm nothing was cut off.
- **Two literal-string edits to the new doc comment's historical references** — the phrases describing `kCompactLiveMinHeight`'s own history originally used the words "THROWAWAY" and "UNMEASURED" to describe past states, which collided with this task's own acceptance-criteria greps for those exact strings on the whole file. Reworded ("a one-line labelled forcing edit", "its own initial unmeasured estimate") to preserve the same information without the literal match — the greps must count only the *current* file's own claims, not historical prose describing a *different* constant's past.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - measurement precision] Plan's suggested scan window pulled in unrelated content**
- **Found during:** Task 1, first run of `measure_card_extent.py` against the plan's suggested `centre ± 80` window (`528..688`).
- **Issue:** That window returned three bands totalling an "overall extent" of `528..616` (height 89) — it included the bottom of the previous Exercise card's Skip button and the "Short break" divider immediately above the Long break card, neither of which is part of the card being measured.
- **Fix:** Cropped and read the screenshot directly to see exactly where the card's own dashed border sat, then tightened the window to `592..624` — isolating only the Long break card's band (`595..616`, height 22). Verified with a wider diagnostic window (`580..650`) that the divider forms its own separate band 7 rows above with a clear gap, confirming nothing of the card itself was excluded by the tightened bounds.
- **Files modified:** none (measurement parameters only, not the script itself — the script's defaults are unbounded; the tight window was a command-line argument choice for this specific target).
- **Verification:** Cross-checked at `--bridge=0` (no gap-bridging at all): the overall extent is still exactly `595..616`, confirming the measurement is not an artifact of the bridge tolerance.
- **Committed in:** `1c44c67` (Task 1 commit).

**2. [Rule 1 - acceptance-criteria self-collision] Doc comment's own historical prose matched this task's literal-string greps**
- **Found during:** Task 2, after writing the full rewritten doc comment and running the required `grep -c "UNMEASURED"` / `grep -c "THROWAWAY"` checks.
- **Issue:** Both greps returned `1`, not the required `0` — not because the placeholder/forcing-edit state was still present, but because the new doc comment's own prose, describing *how* the measurement was taken and *citing* `kCompactLiveMinHeight`'s prior history, used the literal words "THROWAWAY" and "UNMEASURED" in describing past states.
- **Fix:** Reworded both passages to convey the identical information without the literal string ("a one-line labelled forcing edit" instead of quoting `` `THROWAWAY`-labelled``; "its own initial unmeasured estimate" instead of "UNMEASURED PLACEHOLDER").
- **Files modified:** `lib/screens/today/timeline_geometry.dart`.
- **Verification:** Re-ran both greps — `0` for each.
- **Committed in:** `354dd0c` (Task 2 commit).

---

**Total deviations:** 2 auto-fixed (1 measurement-precision correction, 1 acceptance-criteria self-collision), neither affecting the measured value itself.
**Impact on plan:** Both corrections happened before either task's commit — the measured number (32.0) and its rationale are unaffected. No scope creep.

## Issues Encountered

None beyond the two documented deviations above.

## Known Stubs

None — this plan changed a constant, its doc comment, and added a measurement script. No new UI surface was built, no data source stubbed.

## Threat Flags

None — matches the plan's own threat model (T-29-05 sha256 pre-flight done before any screenshot; T-29-06 server stopped after use; T-29-07 forcing edit labelled, reverted, and the revert proven by two greps plus `git diff --stat`; T-29-01 `pubspec` diff empty in both tasks).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Plan `29-04` can now rebuild the debug bundle with the measured `kSubCompactBreakMinHeight` (`32.0`) baked in, re-serve on port `8143` (re-running the same sha256 equality check before trusting any pixel), prove the grid stays `UNIFORM` in pixels with the sub-compact tier rendering, resolve the work-chunk 26dp-overflow question, and close the phase with the mandatory `checkpoint:human-verify` — no automated pass may substitute for it.

---
*Phase: 29-breaks-you-can-see*
*Completed: 2026-08-20*

## Self-Check: PASSED

- FOUND: `lib/screens/today/timeline_geometry.dart`
- FOUND: `.planning/phases/29-breaks-you-can-see/tools/measure_card_extent.py`
- FOUND: `.planning/phases/29-breaks-you-can-see/shots/compact-long-break-forced.png`
- FOUND: `.planning/phases/29-breaks-you-can-see/29-03-SUMMARY.md`
- FOUND commit: `1c44c67` (Task 1)
- FOUND commit: `354dd0c` (Task 2)
- FOUND commit: `52c3e2b` (Summary)

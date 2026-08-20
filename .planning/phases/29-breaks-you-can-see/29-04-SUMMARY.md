---
phase: 29-breaks-you-can-see
plan: 04
subsystem: ui
tags: [flutter, timeline-geometry, real-browser-measurement, pixel-count, port-8143, human-uat]

# Dependency graph
requires:
  - phase: 29-breaks-you-can-see
    plan: 03
    provides: "kSubCompactBreakMinHeight measured in a real browser (32.0), measure_card_extent.py committed, port 8143 claimed debug-only"
provides:
  - "uniform-subcompact-break.png + measure_hours.py VERDICT: UNIFORM (240.0/240.0px, spread 0.0) -- SEEBREAK-02 proven in painted pixels with the sub-compact tier rendering"
  - "The sub-compact break row's own ink extent measured at 10px inside its 20dp slot, isolated from neighbouring card borders"
  - "work-chunk-fit.png + a DISMISSED disposition for ROADMAP item 4 (25-min work chunk's 26dp overflow claim) -- 90px ink extent inside a 100px slot, bottom border 10-15px clear of the slot's last row; kPixelsPerMinute's doc comment gained a dated re-confirmation paragraph"
  - "29-UAT.md scaffolded with three headed items and pre-flight sha256 hashes -- awaiting the human's verbatim verdict (D-07); the phase does NOT close until this is recorded"
affects: ["Phase 29's own close -- the checkpoint continuation agent records the human verdict, finalizes this summary, and only then may the phase be marked complete"]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Cross-checking a screenshot's Stack-local-to-screenshot pixel offset via measure_hours.py's own hour-label band centres (three independent bands agreed to within 1px on offset=263), then using that offset plus TimelineGeometry.yFor() arithmetic to bound measure_card_extent.py's scan window to an exact row's slot -- reusable for any future real-browser fit check on this timeline without needing a new debug affordance"

key-files:
  created:
    - .planning/phases/29-breaks-you-can-see/shots/uniform-subcompact-break.png
    - .planning/phases/29-breaks-you-can-see/shots/work-chunk-fit.png
    - .planning/phases/29-breaks-you-can-see/29-UAT.md
  modified:
    - lib/screens/today/timeline_geometry.dart
    - .planning/phases/29-breaks-you-can-see/29-VALIDATION.md

key-decisions:
  - "measure_hours.py run with --top=260 (not the 200 default) -- the default caught the day's two-line intro paragraph ('The day starts with Side project...') bleeding into the gutter scan column as a false label band; --top is the script's own documented CLI knob, the script itself was left unmodified"
  - "ROADMAP item 4 disposition: DISMISSED (harness artifact), not REAL DEFECT -- measured 90px ink extent for a non-live 25-minute work chunk inside its 100px slot, bottom border 10-15px clear of the slot's last row, screenshot confirms no clipping by eye. No code change to chunk_card.dart's contentPadding; kPixelsPerMinute's doc comment gained a dated confirmation paragraph instead"
  - "Reused /tmp/canopy-p29-profile (29-03's persistent profile) rather than a fresh one, so the same generated day (2 goals, mood default, 8:50 AM simulated now) supplied evidence for both Task 1 and Task 2 without re-onboarding"

requirements-completed: []

# Metrics
duration: ~15min (Tasks 1-2 executed and committed; Task 3 checkpoint scaffolded and PAUSED, awaiting human verdict)
completed: 2026-08-20
---

# Phase 29 Plan 04: Prove the grid in pixels, dispose the work-card overflow, and pause for human UAT Summary

**SEEBREAK-02 is now proven in painted pixels (measure_hours.py: UNIFORM, 240.0/240.0px, spread 0.0) with a sub-compact break on screen; the work card's own 26dp-overflow question is closed DISMISSED on a 90px-in-100px real-browser measurement; and the phase is now paused at its mandatory human-verify checkpoint (Task 3) — NOT auto-approved, NOT self-answered.**

## Performance

- **Duration:** ~15 min (Tasks 1-2)
- **Completed:** 2026-08-20 (Tasks 1-2; Task 3 checkpoint reached and paused)
- **Tasks:** 2/3 complete, 1 paused at a blocking `checkpoint:human-verify`
- **Files modified:** 5 (2 screenshots created, 1 doc created, 1 lib/ file comment-only, 1 validation doc)

## Accomplishments

- **Rebuilt and re-served on port 8143, sha256-verified served == built before trusting any pixel** (PD-29-05). Hash `12ba918e2a3e0e4dd4533a5c76c2d2f8619ece375cb5e9285a96eea6f4b67d07` matched at three checkpoints: after Task 1's rebuild, after Task 2's doc-comment-only `lib/` edit (rebuilt to be certain rather than assume a comment can't affect dart2js output — it didn't, byte-identical hash), and again immediately before presenting the human checkpoint.
- **Proved SEEBREAK-02 in painted pixels.** Drove to the reused `/tmp/canopy-p29-profile` day (2 goals, "Steady day", simulated now 8:50 AM), captured `uniform-subcompact-break.png` showing a sub-compact "Short break" hairline row between two work cards, with three hour-axis labels (8/9/10 AM) in frame. `measure_hours.py --top=260` prints `VERDICT: UNIFORM`, hour-to-hour spacing `240.0`/`240.0`, spread `0.0` — exactly `60 * kPixelsPerMinute`. No `132.0` spread (Phase 27's defect signature) anywhere.
  - **Deviation:** the default `--top=200` produced a false `NOT UNIFORM` (spread 204.0) because this particular day's header includes a two-line intro paragraph ("The day starts with Side project...") that bleeds into the gutter scan column (x<40) below y=200, registering as a spurious "label band". Diagnosed by cropping and reading the region with the Read tool, then raised `--top` to 260 — a documented CLI flag on the script itself, not a script edit. Re-ran and got `UNIFORM` with a clean 3-band, 2-gap, zero-spread result.
- **Confirmed the sub-compact tier's own fit.** `measure_card_extent.py`, bounded to the break row's own band (screenshot rows 610-636, isolated from neighbouring card borders and cross-checked with a wider 600-650 diagnostic window per 29-03's own precedent), measures the row's ink extent at **10px** (band rows 620-629) — half its 20dp slot. Opened the screenshot with the Read tool: "Short break" is not cut off top or bottom, both hairline segments are visible either side, and it reads as a distinct row rather than a border of either neighbouring work card.
- **Disposed ROADMAP item 4 (D-06): DISMISSED.** Captured `work-chunk-fit.png` of the same day's non-live "Side project, 9:00 AM – 9:25 AM" `full`-tier work card (starts 10 minutes after the simulated 8:50 AM now, so genuinely non-live). Derived the card's own 100dp slot in screenshot pixel space by cross-checking `TimelineGeometry.yFor()` arithmetic against measure_hours.py's own three hour-label band centres (all three independently agreed the Stack-to-screenshot offset is 263px, +/-1px) — slot ≈ screenshot rows 517-617. `measure_card_extent.py` bounded there (and independently cross-checked against a semantics-derived window, `y=562 ± 50`) measures the card's own outline-border ink extent at **90px** (band rows 513-602), with the bottom border band ending at row 602 — 10-15px clear of the slot's last row, not clipped. Opened the screenshot with the Read tool: title, time range, and the Complete/Skip row are all fully visible with clear whitespace below the card before the next row's divider. **Verdict: DISMISSED (harness artifact)** — SEED-005's 126dp figure was `flutter test`'s placeholder-font bound, exactly as its own caveat said. No code change to `chunk_card.dart`'s `contentPadding` (the fix branch did not fire); `kPixelsPerMinute`'s doc comment gained a dated 2026-08-20 re-confirmation paragraph recording the number, method, and verdict, per the plan's "either way" instruction.
- **Suite green, analyze clean, no dependency touched.** `flutter analyze`: no issues. `flutter test --concurrency=1`: 587 passed, 0 failed — identical to the 29-03 baseline (only a doc comment changed in `lib/`). `git diff --exit-code pubspec.yaml pubspec.lock` passes.
- **29-VALIDATION.md's per-task table updated** for rows `29-04-01`/`29-04-02` with the measured verdicts (row `29-04-03` stays `⬜ pending` — it is the checkpoint this plan pauses at).
- **`29-UAT.md` scaffolded** with the three UAT items headed, empty `**Verdict:**` lines, and the pre-flight sha256 hashes recorded at the top. The server (PID `704702`) is left running on port 8143 per the plan's explicit instruction — a continuation agent (or the human directly) needs it live to judge Task 3.
- **PAUSED at Task 3, the mandatory `checkpoint:human-verify` (D-07, gate="blocking").** This executor did NOT open the screenshots and self-judge legibility as a substitute for the human's eye — Tasks 1-2's own screenshot inspections were for the fit/clipping questions those tasks are scoped to answer, not for "does this read as a break to a person," which is Task 3's entire, non-delegable subject. See "CHECKPOINT REACHED" in this executor's final response for the full structured handoff.

## Task Commits

1. **Task 1: Rebuild with the measured constant and prove SEEBREAK-02 in painted pixels** — `e391f61` (feat)
2. **Task 2: Answer the work card's 26dp overflow with a real-browser number, dispose DISMISSED (D-06)** — `8640cbe` (fix)
3. **Task 3 (in progress): scaffold `29-UAT.md`, pre-flight verified, awaiting human checkpoint** — `15441e7` (docs) — **NOT the task's completion commit.** The continuation agent commits the human's recorded verdict separately once received.

## Files Created/Modified

- `.planning/phases/29-breaks-you-can-see/shots/uniform-subcompact-break.png` — SEEBREAK-02 pixel-proof screenshot (Task 1)
- `.planning/phases/29-breaks-you-can-see/shots/work-chunk-fit.png` — ROADMAP item 4 / D-06 evidence screenshot (Task 2)
- `lib/screens/today/timeline_geometry.dart` — `kPixelsPerMinute`'s doc comment gained a dated 2026-08-20 re-confirmation paragraph; the constant's value is unchanged (comment-only diff)
- `.planning/phases/29-breaks-you-can-see/29-VALIDATION.md` — per-task verification table rows `29-04-01`/`29-04-02` updated from `⬜ pending` to their measured verdicts
- `.planning/phases/29-breaks-you-can-see/29-UAT.md` — new file, three headed items with empty `**Verdict:**` lines, pre-flight sha256 hashes recorded

## Decisions Made

- **`measure_hours.py --top=260`, not the default 200** — this day's header content (a two-line intro paragraph) pushed the real hour-axis labels lower than the Phase 27 baseline the default was tuned against; using the script's own documented `--top` flag rather than editing the script, per the plan's explicit "do not edit the script" instruction.
- **ROADMAP item 4: DISMISSED, not REAL DEFECT** — see "Accomplishments" above for the full measurement chain. This is a disposition made on a fresh, independently-derived measurement (cross-checked two ways: geometry arithmetic and semantics-box centring), not an assumption carried over from the UI-SPEC's stated default expectation.
- **Server left running, not stopped** — unlike 29-03 (which stopped its port-8143 server at task close, T-29-06), this plan's Task 3 hands the live URL to a human; stopping and restarting the server between measurement and human review would risk serving a different build than the one just proven (the same PD-29-05 concern the sha256 checks exist to catch). The continuation agent (or a manual follow-up) is responsible for stopping it once the human's verdict is recorded, per T-29-06's mitigation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - measurement calibration] `measure_hours.py`'s default `--top=200` produced a false `NOT UNIFORM`**
- **Found during:** Task 1, first run of `measure_hours.py` against `uniform-subcompact-break.png` with no `--top` override.
- **Issue:** Printed `NOT UNIFORM` (spread 204.0, an extra spurious "label band" at rows 236-246, centre 241.0, only 36px before the real "8 AM" label at centre 277.0). Cropping and reading the region with the Read tool showed the spurious band was the tail of the day's intro paragraph ("The day starts with Side project...") bleeding into the gutter scan column (x<40) — this day's header has more copy above the timeline than the baseline the script's `--top=200` default was tuned against.
- **Fix:** Re-ran with `--top=260` (a documented CLI flag the script already exposes) — script itself left unmodified. Result: clean 3-band, 0.0-spread `UNIFORM` verdict.
- **Files modified:** none (measurement parameter only, same class of correction as 29-03's scan-window tightening).
- **Verification:** Re-ran at `--top=260`; three label bands (8/9/10 AM), spacing `240.0`/`240.0`, spread `0.0`.
- **Committed in:** `e391f61` (Task 1 commit).

**2. [Rule 1 - plan-acceptance-criterion inconsistency] `grep -c "kPixelsPerMinute = 4.0"` returns 2, not the plan's expected 1**
- **Found during:** Task 2, after appending the dated re-confirmation paragraph to `kPixelsPerMinute`'s doc comment and running the acceptance-criteria grep.
- **Issue:** The plan's acceptance criteria state this grep "still returns `1`" (implying the constant's own declaration is the only match). It returns `2` — but the second match (`kFullTierMinHeight`'s own doc comment, "... threshold was derived from `kPixelsPerMinute = 4.0`; a minute-based threshold silently rots ...") is a **pre-existing** occurrence, confirmed via `git show HEAD` against the file before this task touched it. This task added zero new occurrences of that literal string (the new paragraph refers to "this constant" rather than repeating the literal `= 4.0` assignment).
- **Fix:** No code change — this is a plan-authoring inconsistency against the pre-existing tree (same class as 29-02's documented `kFullTierMinHeight`-in-diff correction), not a defect this task introduced. Documented here rather than silently reworded to force the grep to `1`, since doing so would require deleting or rephrasing a pre-existing, unrelated sentence in a different constant's own doc comment — out of this task's scope.
- **Files modified:** none beyond the intended `kPixelsPerMinute` doc-comment addition.
- **Verification:** `git show HEAD:lib/screens/today/timeline_geometry.dart | grep -n "kPixelsPerMinute = 4.0"` shows the second match existed before this task's diff.
- **Committed in:** `8640cbe` (Task 2 commit).

---

**Total deviations:** 2 auto-fixed (1 measurement-calibration correction, 1 plan-acceptance-criterion inconsistency), neither affecting the measured values or verdicts themselves.
**Impact on plan:** Both corrections happened before or within each task's own commit — the UNIFORM verdict and the DISMISSED disposition are unaffected. No scope creep, no code behavior change.

## Issues Encountered

None beyond the two documented deviations above.

## Known Stubs

None — Tasks 1-2 produced two evidence screenshots, one doc-comment addition, and one validation-doc update; no new UI surface, no stubbed data source. `29-UAT.md`'s empty `**Verdict:**` lines are the intended, documented pending state of a paused checkpoint (D-07) — not a stub; they are filled by the human's response, not by this executor.

## Threat Flags

None — matches the plan's own threat model. T-29-05 (sha256 pre-flight) checked three times, all matching. T-29-06 (server left running) is the plan's own explicit instruction for this specific task, with the mitigation (stop once the verdict is recorded) deferred to the continuation agent, not omitted. T-29-08 (human-verdict repudiation) is why `29-UAT.md` exists as a committed artifact rather than a conversational answer. T-29-01 (`pubspec` diff) confirmed empty.

## User Setup Required

**Human action required to close this phase.** A human needs to open `http://danserver:8143/` (server already running, PID `704702`) and answer `29-UAT.md`'s three items, per the checkpoint returned alongside this summary. No external service configuration is needed — this is the phase's own mandatory UAT gate (D-07), not a setup step.

## Next Phase Readiness

**This plan and this phase are NOT complete.** Tasks 1-2 are done, committed, and their evidence is solid: `UNIFORM` in painted pixels, the sub-compact tier's own fit confirmed, and ROADMAP item 4 closed DISMISSED with a real-browser number. But per `29-VALIDATION.md`'s phase gate and D-07, none of that — nor a green suite, nor `flutter analyze` clean — closes the phase without Task 3's recorded human verdict. STATE.md must NOT be advanced past "Plan 4 of 4, Task 3 pending" until a continuation agent records the human's verbatim answers in `29-UAT.md`, updates this summary's `requirements-completed` field, and only then runs the final state-update / metadata-commit steps this executor deliberately did not run.

---
*Phase: 29-breaks-you-can-see*
*Completed: 2026-08-20 (Tasks 1-2 only — Task 3 checkpoint pending)*

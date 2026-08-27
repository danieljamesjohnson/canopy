---
phase: 32-breaks-you-can-tap
plan: 03
subsystem: ui
tags: [flutter, material3, uat, real-browser-measurement, headless-chromium, playwright]

requires:
  - phase: 32-01
    provides: kPixelsPerMinute=6.0, kBreakSkipButtonWidth=64.0, BreakSkipButton/BreakSkippedIndicator, non-live compact break tier rebuilt as Card+rail
  - phase: 32-02
    provides: full break tier on the same Card+rail shape, live single-line tier's Skip rail, all retired-mechanism symbols proven gone
provides:
  - "32-UAT.md — the human UAT script for Phase 32, with a mandatory dated Step 0, a real-browser fit measurement of the compact break card, D-31-07 re-asked, and two open questions (Up next transition, free-time visual divergence) surfaced explicitly"
  - "A real-browser (headless Chromium, swiftshader) pixel measurement of the compact break card's actual painted geometry, driven end-to-end through onboarding and a real morning check-in rather than a synthetic fixture"
affects: [32-breaks-you-can-tap (Task 2, the blocking human checkpoint that follows this plan)]

actuals:
  tokens: 5967
  tasks: 1
  commits: 1

tech-stack:
  added: []
  patterns:
    - "Headless-Chromium UAT measurement driven via a hand-rolled Playwright script (coordinate-click through onboarding/check-in, since Flutter Web's CanvasKit renders to canvas with no DOM/accessibility tree exposed by default) rather than a DOM-locator-based automation script — necessary because no widget-level selector exists for canvas-painted content."
    - "Pixel-level fit measurement via Python/PIL column-and-row luma scans (background vs. card-fill vs. border vs. text-ink color buckets) at deviceScaleFactor:1, giving a direct 1-image-pixel-equals-1-dp reading — the same class of technique prior phases' measure_card_fill.py/measure_hours.py used, reconstructed here since those throwaway scripts were not committed to tools/."
    - "Presence-probe symbol choice recorded explicitly when the obvious candidate (a `const` geometry constant) const-folds to zero on dart2js — this project's established trap, now confirmed a second time on this phase's own new constant (kBreakSkipButtonWidth), with BreakSkipButton (a class, not const-folded) used instead."

key-files:
  created:
    - .planning/phases/32-breaks-you-can-tap/32-UAT.md
    - .planning/phases/32-breaks-you-can-tap/shots/today-timeline-full.png
    - .planning/phases/32-breaks-you-can-tap/shots/compact-break-30dp-crop.png
    - .planning/phases/32-breaks-you-can-tap/shots/compact-break-30dp-zoomed.png
  modified: []

key-decisions:
  - "Did not touch port 8143 at all, per this plan's explicit division-of-labour instruction — observed and recorded the stale squatter (PID 3484010, started 2026-08-26 08:06:46) for the orchestrator to kill, but performed no kill, build, or serve there."
  - "Built and served on scratch port 8153 instead, entirely inside this worktree, for the real-browser measurement only; shut that server down before returning (confirmed via lsof)."
  - "Used BreakSkipButton (11 non-comment hits) as the served-bytes presence probe instead of kBreakSkipButtonWidth (0 hits, const-folded) — recorded the substitution and its reason in 32-UAT.md itself, per the plan's explicit prohibition on quietly swapping a symbol without explanation."
  - "Reached a real 5-minute break via full onboarding + a real morning check-in (mood 3/5, no fixed commitment) rather than seeding a synthetic Hive fixture — the plan's own instruction is to measure real content, and the app's dev-data loader (typical_quarter.json) does not itself produce a generated daily schedule, only goals/logs/snapshots."
  - "Wrote the port-8143 pre-flight block as an explicit TODO placeholder for the orchestrator (mirroring 31-08-SUMMARY.md/31-GAPS-UAT.md's precedent for the identical worktree-force-removal constraint), rather than fabricating numbers this executor never produced."

patterns-established: []

requirements-completed: []

coverage:
  - id: D1
    description: "32-UAT.md exists, leads with a mandatory dated Step 0 ahead of every numbered item, and asks all items/questions the plan's must_haves require (Item 1 TAPBREAK-03 perceptual, Item 2 TAPBREAK-01/D-32-03 one-unit-vs-two-zones asked directly, Item 3 the long-break rail as a planner default, Item 4 D-31-07 re-asked for both live durations, both open questions surfaced as questions not pass/fail, two carried-forward notes, a Summary block, and a Gaps YAML block with its consumption marker)"
    requirement: "TAPBREAK-01"
    verification:
      - kind: manual_procedural
        ref: ".planning/phases/32-breaks-you-can-tap/32-UAT.md (full document, self-inspected against the plan's acceptance criteria for Task 1)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The compact (30dp) break card's real content, measured in a real browser against a real generated schedule (not a synthetic fixture, not flutter test's placeholder font): 30px painted card height (exact match to 5min*6.0dp), 9-11dp text-to-border clearance on each side, zero clipping or overflow into the neighbouring row, 63-64px Skip rail width matching kBreakSkipButtonWidth"
    requirement: "TAPBREAK-03"
    verification:
      - kind: other
        ref: "headless Chromium screenshot + Python/PIL pixel analysis, .planning/phases/32-breaks-you-can-tap/shots/today-timeline-full.png and compact-break-30dp-{crop,zoomed}.png; numbers pasted verbatim into 32-UAT.md's 'Real-browser measurement' section"
        status: pass
    human_judgment: false
  - id: D3
    description: "Whether the redesigned card 'reads as a section of the day,' whether the Skip rail 'reads as one tappable unit,' whether the long break's full-height rail 'reads sensibly,' and D-31-07/the two open questions — all genuinely perceptual or product judgments this plan's own measurement work cannot and does not attempt to settle"
    human_judgment: true
    rationale: "These are exactly the items 32-VALIDATION.md's Manual-Only Verifications table names as structurally unautomatable — a widget test or a pixel measurement can prove geometry, not meaning, and this project has been contradicted by a human thumb on a green suite three times already (Phase 27, 29, 31). Task 2, the blocking human-verify checkpoint, is where these get judged; this plan's own scope ends at producing the document and the measurement, not at judging them."
    verification: []

duration: ~35min
completed: 2026-08-27
status: complete
---

# Phase 32 Plan 03: Real-Browser Fit Measurement and the Blocking Human UAT Summary

**A real-browser (headless Chromium, swiftshader) pixel measurement proves the compact break card's redesigned content fits its 30dp slot exactly (30px painted height, 9-11dp clearance, zero clipping) against an actually-generated schedule reached through real onboarding and check-in, and `32-UAT.md` is written with a mandatory dated Step 0, D-31-07 re-asked, and both open questions surfaced explicitly — Task 2's blocking human checkpoint follows, unjudged.**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-08-27T15:17:20Z
- **Tasks:** 1 of 2 completed (Task 2 is `type="checkpoint:human-verify"`, `gate="blocking-human"` — this plan halts there, per its own division-of-labour instruction and this project's four-phase precedent of green suites contradicted by a thumb)
- **Files created:** 4 (1 markdown, 3 screenshots)

## Accomplishments

- **Verified this worktree's own precondition first:** `flutter analyze` clean, `flutter test` 621/621 green on the merged 32-01+32-02 tree, before touching anything else.
- **Did not touch port 8143.** Observed the stale squatter left over from plan 31-08's round-two UAT (PID 3484010, started 2026-08-26 08:06:46) and recorded it in `32-UAT.md` for the orchestrator to kill — per this plan's explicit division-of-labour instruction, killing it and producing the durable 8143 build is the orchestrator's job, run from the main tree after merge (this worktree is force-removed on return).
- **Built and served a scratch build on port 8153**, entirely inside this worktree: `flutter build web --debug --source-maps --pwa-strategy=none`, served with `tools/serve-uat.py` (never the stock Python server, never a release build). Byte-verified: built/served `main.dart.js` sha256 identical (`3ec89469...`), `Cache-Control: no-store` present, and `BreakSkipButton` (a class, not const-folded) greps 11 non-comment hits — `kBreakSkipButtonWidth` (a `const double`) greps 0, the same dart2js const-folding trap this project's own `31-GAPS-UAT.md` already documented for a different symbol; recorded which probe was used and why the first one returned zero, per the plan's explicit prohibition on silently swapping symbols.
- **Reached a real 5-minute break through real onboarding and a real morning check-in** (mood 3 of 5, no fixed commitment) — not a synthetic Hive fixture — driving headless Chromium via a hand-rolled Playwright script (coordinate clicks; Flutter Web's CanvasKit exposes no DOM/accessibility tree by default) with `--use-gl=swiftshader --enable-unsafe-swiftshader` to avoid the CONTEXT_LOST_WEBGL trap.
- **Measured the compact break card's real painted geometry** via Python/PIL pixel analysis at `deviceScaleFactor: 1` (1 image pixel = 1 dp): card height 30px (exact match to `5min × 6.0dp/min`), label ink 8px core / 10px with anti-aliasing, clearance 9dp above / 11dp below the ink to the card's own border, Skip rail 63-64px wide × 30px tall (matching `kBreakSkipButtonWidth = 64.0`) — **zero clipping, zero overflow into the neighbouring row.** This confirms the UI-SPEC's reasoned estimate with a genuine real-browser measurement rather than restating it.
- **Shut the scratch server down** before returning (confirmed via `lsof -i :8153` showing nothing).
- **Wrote `.planning/phases/32-breaks-you-can-tap/32-UAT.md`**, containing (in order): a header naming what shipped and which two items are inherited from Phase 31; an honesty note distinguishing this executor's scratch-port work from the orchestrator's still-pending port-8143 pre-flight; the pre-flight blocks for both ports; the real-browser measurement block with a fit verdict; a mandatory, dated Step 0 (⟳ Re-check-in) ahead of every numbered item, naming the 2026-08-21 incident; a "use a phone or tablet" instruction; Items 1-4 (TAPBREAK-03 perceptual read, TAPBREAK-01/D-32-03 one-unit-vs-two-zones asked directly with the geometry stated honestly, the long break's rail as a planner default rather than a ruling, D-31-07 re-asked for both the 30-minute and 5-minute live cases via the Settings time-travel route); two open questions (the "Up next" transition, the free-time-vs-break visual divergence) explicitly marked not-pass/fail; two carried-forward notes; a resume signal; a remedies section routing any FAIL explicitly; and a `## Summary` block plus an empty `## Gaps` YAML block with its consumption marker.

## Task Commits

1. **Task 1: Reclaim the port, build, serve, byte-verify, measure the card, and write the UAT** — `1d6b8e3` (docs)

Task 2 (`checkpoint:human-verify`, `gate="blocking-human"`) has not run — this plan halts at the checkpoint per its own frontmatter (`autonomous: false`) and this project's standing precedent that `gate="blocking-human"` is never auto-approved, in any mode.

## Files Created/Modified

- `.planning/phases/32-breaks-you-can-tap/32-UAT.md` — the human UAT script described above.
- `.planning/phases/32-breaks-you-can-tap/shots/today-timeline-full.png` — full-page screenshot of the real generated Today timeline (headless Chromium, swiftshader), showing the measured compact break row in context.
- `.planning/phases/32-breaks-you-can-tap/shots/compact-break-30dp-crop.png` — tight crop of the measured row.
- `.planning/phases/32-breaks-you-can-tap/shots/compact-break-30dp-zoomed.png` — 4× enlargement of the same crop, for visual inspection of the border/text/rail relationship.

No production source was touched — this plan's own `files_modified` frontmatter is `32-UAT.md` alone, and that held.

## Decisions Made

See `key-decisions` in the frontmatter above: not touching port 8143; using scratch port 8153 for the measurement build; substituting `BreakSkipButton` for the const-folded `kBreakSkipButtonWidth` as the presence probe (recorded, not silently swapped); reaching the measured break via real onboarding/check-in rather than a synthetic fixture; and writing the port-8143 pre-flight as an explicit orchestrator TODO rather than fabricating numbers.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] No committed measurement tooling existed — `tools/measure_card_fill.py`/`measure_hours.py` referenced in `STATE.md`'s prior-phase history are not present in this tree**
- **Found during:** Task 1, attempting to reuse the established real-browser measurement approach
- **Issue:** Prior phases' pixel-measurement scripts were evidently throwaway artifacts, never committed to `tools/`. Nothing in the repo could drive headless Chromium through onboarding or do pixel analysis on the resulting screenshot.
- **Fix:** Wrote a one-off Playwright script (coordinate-click driven, since Flutter Web/CanvasKit exposes no DOM for `page.click(text=...)` to target) to walk onboarding → check-in → Today, plus a Python/PIL script to do the border/ink/rail pixel analysis. Both scripts live in the session scratchpad, not the repo, matching the apparent precedent that these are throwaway measurement tools rather than product code.
- **Files modified:** None in the repo (scratchpad-only tooling).
- **Verification:** The resulting measurements (30px card height exactly matching `5×6.0`, rail width matching `kBreakSkipButtonWidth`) are internally consistent with known constants, which is the strongest evidence the measurement technique itself is sound.
- **Committed in:** N/A (tooling not committed; only its output — the screenshots and the numbers in `32-UAT.md` — is committed, in `1d6b8e3`).

---

**Total deviations:** 1 auto-fixed (Rule 3 — a missing tool blocking the plan's own required measurement step, resolved by writing an equivalent one-off script rather than skipping the measurement).
**Impact on plan:** None on scope or correctness — the measurement itself was completed exactly as the plan requires, with numbers traceable to a specific, reproducible pixel analysis.

## Issues Encountered

None beyond the deviation documented above.

## User Setup Required

None — no external service configuration required.

## Known Stubs

None. `32-UAT.md`'s verdict fields (Step 0 date, Items 1-4, both open questions, the Summary counts, and the Gaps block) are intentionally blank — they are the human's fields to fill in during Task 2, not a stub left by this plan. The document's own resume-signal and remedies sections make this explicit.

## Threat Flags

None. This plan introduces no new network endpoints, auth paths, or schema changes — it produces a markdown document, three screenshots, and a scratch-port web server that was shut down before this plan returned. `T-32-03-01` through `T-32-03-05` in the plan's own threat model are all either mitigated as designed (this document records the killed-server TODO, the byte-verification numbers, and the presence-probe substitution) or explicitly accepted (T-32-03-05, debug source maps on a tailnet-only host).

## Next Phase Readiness

- **Task 2 — the blocking human checkpoint — is next and is unjudged.** This plan HALTS here, as required: `gate="blocking-human"` is never auto-approved in any mode, and this plan's own `autonomous: false` frontmatter and division-of-labour instruction both forbid this executor from judging any perceptual item itself.
- **The orchestrator must complete the port-8143 pre-flight before the owner is shown anything**: kill the stale squatter (PID 3484010, started 2026-08-26 08:06:46, recorded in `32-UAT.md`), build, serve with `tools/serve-uat.py`, and fill in every `[TODO]` in `32-UAT.md`'s "Pre-flight, Part A" section with real, verbatim command output — including re-running the `BreakSkipButton` presence grep, not `kBreakSkipButtonWidth`.
- **A PASS on all four items closes Phase 32.** A FAIL on any item routes explicitly to a gap-closure plan or a new phase, per `32-UAT.md`'s own "Remedies" section — never noted and left, per this phase's own `must_haves.prohibitions`.
- **STATE.md and ROADMAP.md are intentionally untouched by this plan** — per this plan's parallel-execution instructions, the orchestrator owns those writes after the wave completes.

## Self-Check: PASSED

- `.planning/phases/32-breaks-you-can-tap/32-UAT.md` — FOUND
- `.planning/phases/32-breaks-you-can-tap/shots/today-timeline-full.png` — FOUND
- `.planning/phases/32-breaks-you-can-tap/shots/compact-break-30dp-crop.png` — FOUND
- `.planning/phases/32-breaks-you-can-tap/shots/compact-break-30dp-zoomed.png` — FOUND
- Commit `1d6b8e3` — FOUND in `git log`
- Port 8153 — confirmed down (`lsof -i :8153` returns nothing)
- Port 8143 — confirmed untouched (still held by the pre-existing PID 3484010, as it was found)
- `flutter test` — 621/621 passing (verified this session, before the scratch build)
- `flutter analyze` — clean (verified this session)

---
*Phase: 32-breaks-you-can-tap*
*Completed: 2026-08-27*

---
phase: 26-the-day-has-a-shape
verified: 2026-08-13T13:32:16Z
status: passed
score: 4/4 must-haves verified in code; human gate satisfied 2026-08-14 (Dan, blanket pass — see 26-VALIDATION.md Outcome)
overrides_applied: 0
human_verification:
  - test: "Open http://danserver:8134/ (or a freshly-served debug build) in a real GPU-backed browser and complete 26-06-PLAN.md's ten-item checklist — in particular items 2, 3, 4, 6, 8, 9: does the day read as a shape at a glance, does the Full-tier 25-min card (kPixelsPerMinute=5.5) actually fit without clipping or crowding, is the 5-min break legible, does the live row's 232px reservation neither gap nor collide, does the line visibly move across a minute tick, and does the past genuinely feel receded on open in all four sampled states"
    expected: "Dan records a pass or a named issue per item in 26-VALIDATION.md's Manual-Only Verifications table; nyquist_compliant flips to true"
    why_human: "26-VALIDATION.md routes exactly these claims to the manual-only gate because flutter test's placeholder font and pumped-frame harness cannot judge text-fit, motion, or gestalt — this is a deliberate, documented limitation, not an oversight. Two of this phase's own scale constants (kPixelsPerMinute, kLiveRowReservedHeight) are explicitly provisional pending this verdict."
  - test: "Confirm kPixelsPerMinute = 5.5 is the right scale, and kLiveRowReservedHeight = 232.0 neither gaps nor clips, at Dan's own screen size/DPI"
    expected: "Either explicit confirmation the constants hold, or a corrected value with the resulting amendment to 26-UI-SPEC.md and the tests that hard-code it"
    why_human: "Both constants are documented in timeline_geometry.dart as measured via flutter test's placeholder-font harness or headless-Chromium screenshots, with an explicit doc-comment note that a real-browser check is 'the actual authority.' The project's own CLAUDE.md and this phase's UAT history (kGutterWidth 46→75→52) record this harness class producing a wrong shipped constant before."
  - test: "26-06-PLAN.md's blocking checkpoint (Task 2, gate:blocking) — Dan's real-browser sign-off recorded in 26-VALIDATION.md"
    expected: "26-VALIDATION.md frontmatter reads status: complete, nyquist_compliant: true, with every Manual-Only Verifications row given a verdict, and a 26-06-SUMMARY.md exists"
    why_human: "This is the phase's own defined completion gate (autonomous: false), not a residual nice-to-have. It has not run: no 26-06-SUMMARY.md exists, 26-VALIDATION.md is unchanged since 2026-08-10 (status: draft, nyquist_compliant: false, Approval: pending), and STATE.md's own log states in the most recent entry: '26-06-PLAN.md remains an open, unaddressed item for this phase.'"
---

# Phase 26: The Day Has a Shape — Verification Report

**Phase Goal:** The day renders as a time-proportional surface with a continuously-moving now-line, so "where am I" is answered by position rather than by a marker slotted between rows.
**Verified:** 2026-08-13T13:32:16Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A row's height corresponds to its duration, so the shape of the day is legible without reading any times (CAL-01) | ✓ VERIFIED | `TimelineGeometry.heightFor(start, duration)` (`timeline_geometry.dart:279-282`) returns `yFor(start+duration) - yFor(start)`, which is exactly `duration * kPixelsPerMinute` (the shared `kTimelineEdgePadding` cancels out of the difference by construction — confirmed by reading the arithmetic, not asserted). `_buildPositionedRow`'s non-live `ChunkRow`/`GapFreeRow`/`LeadingFreeRow` arms all set `height: geometry.heightFor(...)` with **no floor/ceiling/clamp** (`today_screen.dart:684-777`), matching D-02 ("fully proportional, no gap compression, no min/max clamping") verbatim. Density tier selection (`ChunkCardDensity.full` vs `.compact`) is a pixel-slot comparison, not a text measurement, so it can't rot with the scale. Live-row-vs-not is the one named, documented exception (CAL-01's own carve-out), correctly implemented via `liveExtraPx` folded once into `TimelineGeometry`, not re-derived at any call site (`grep -c kLiveRowReservedHeight lib/screens/today/today_screen.dart` → 0). |
| 2 | The now-line sits at the true current moment, including inside an activity's span, not only at chunk boundaries (CAL-02) | ✓ VERIFIED | `today_screen.dart:1368-1401` renders exactly one `NowLineOverlay` **unconditionally** — no `if`, no ternary, no `NowState` switch gating it — at `top: geometry.yFor(nowMinutes) - kNowLineHeight/2`. Phase 24's `Active`-state suppression is not relocated, it is absent from this render path (confirmed by reading the full `build()` method). `test/screens/today_screen_test.dart`'s "no suppression" test is table-driven across all 5 `NowState`s including `Active (mid-chunk)` and asserts `findsOneWidget` for `NowLineOverlay` in every one (the exact assertion that used to read `findsNothing` for `Active` pre-Phase-26). A second test ("mid-chunk truth") recomputes the expected offset from `TimelineGeometry`'s own arithmetic (not a hard-coded pixel) and asserts the line sits strictly between the live row's top and bottom. A third test ("motion") asserts a 1-minute clock tick moves the line by exactly `kPixelsPerMinute`. `resolveNowState` remains the single detector (see truth 4) — the line is read off `TimelineGeometry`, never a second opinion. |
| 3 | Elapsed time recedes — the past is a deliberate scroll away rather than the default view (CAL-03) | ✓ VERIFIED | `today_screen.dart:1199-1244`'s centre-on-open logic runs unconditionally in every `NowState` (no primary/fallback branch, closing the Phase 24 `DayComplete` UAT gap "by construction" per the code comment) and computes `raw = stackTop + geometry.yFor(nowMinutes) - viewportHeight/2`, clamped to `[0, maxScrollExtent]`. Table-driven test asserts a positive settled scroll offset in `Active`/`Overdue`/`GapBeforeNext`/`DayComplete` and exactly `0` at `PreStart` (where "now" legitimately is the top of the range). A second test recomputes the expected clamped target from the fixture's own numbers and asserts `closeTo` within 0.5px. A third test, "the past is off-screen," asserts the 8am chunk's row is not visible without scrolling up at 12:45 — CAL-03's literal claim, not just "we scrolled a bit." No dimming/graying mechanism exists (by design, per the phase's `known_and_accepted` framing) — the claim is satisfied by scroll position alone, and the tests genuinely exercise that position, not just that `animateTo` was called. |
| 4 | The single-clock-sample rule still holds — the line is a position derived from `build()`'s one `nowDt`, never a second opinion about which activity is current | ✓ VERIFIED | `today_screen.dart:1127-1129`: `nowDt = _nowFn()` is read exactly once per `build()`, then `nowMinutes = minutesOfDay(nowDt)` and `nowState = resolveNowState(..., now: () => nowDt)` are both derived from that same value (confirmed by reading the surrounding code, not inferring it) — the code's own comment at line 1110 names this as "the only three 'what is happening now' calls on this screen." `grep -rn "resolveNowState" lib/ \| grep -vE "^[^:]+:[0-9]+:\s*//"` returns exactly two lines: the definition (`now_state.dart:117`) and the one call site (`today_screen.dart:1129`). `grep -c "DateTime.now()" lib/screens/today/today_screen.dart` returns 0. |

**Score:** 4/4 truths verified in code and tests.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/screens/today/timeline_geometry.dart` | Pure minute→pixel authority, `TimelineGeometry.yFor`/`heightFor`/`totalHeight`, the six named constants | ✓ VERIFIED | Exists, substantive, no clock reads (grep for `DateTime` in the file: none), wired as the sole geometry source for every consumer in `today_screen.dart`. |
| `lib/screens/today/widgets/now_line.dart` (`NowLineOverlay`) | The now-line rule + time chip, `colorScheme.primary` | ✓ VERIFIED | Exists, wired at exactly one call site, unconditional per state. `showChip` correctly scoped to the live-row-collision exception (G-03), not a broader suppression. |
| `lib/screens/today/widgets/hour_axis.dart` (`HourAxisLine`) | Per-hour background labels/hairlines replacing the old per-row gutter | ✓ VERIFIED | Exists, wired, `outlineVariant` not `primary` (correct per D-03's "primary reserved for now" framing). |
| `lib/screens/today/timeline.dart` | `NowMarkerRow` retired, row model reworked per D-01 | ✓ VERIFIED | `grep -rn "NowMarkerRow" lib/ test/` returns zero hits — deleted outright, not relocated, matching the ROADMAP's explicit expectation ("Expect `NowMarkerRow`'s ... contract to be reworked, not extended"). |
| `lib/screens/today/today_screen.dart` | Fixed-height `Stack` of duration-positioned rows + hour axis + now-line + centre-on-open | ✓ VERIFIED | ~1400+ lines, single `nowDt` sample threaded through every consumer, no independent re-derivation of any geometry constant at this file's call sites. |
| `lib/utils/time_format.dart` | `floorToHour`/`ceilToHour`/`hourBoundariesIn`, `formatMinutesCompact` (with G-06's AM suffix) | ✓ VERIFIED | Present, unit-tested, doc comments' worked examples updated to match the `'a'` suffix. |
| `.planning/phases/26-the-day-has-a-shape/26-VALIDATION.md` | Completed per-task verification map, `nyquist_compliant: true` | ✗ STUB (still `status: draft`) | Frontmatter unchanged since 2026-08-10 creation: `status: draft`, `nyquist_compliant: false`, "Approval: pending." The three Manual-Only Verifications rows carry no verdict. This is the phase's own defined completion artifact (`26-06-PLAN.md` must_haves) and it was never filled in. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `today_screen.dart` build() | `TimelineGeometry.forDay` | single `nowMinutes`/`firstStartMinutes`/`lastEndMinutes`/live bounds, all derived from the one `nowDt` sample | WIRED | No second clock read; `liveStartMinutes`/`liveEndMinutes` mirror `timeline.dart`'s own `isLive` derivation. |
| `today_screen.dart` row loop | `TimelineGeometry.yFor`/`heightFor` | every `Positioned`'s `top`/`height` | WIRED | `grep -c "kPixelsPerMinute\|kLiveRowReservedHeight\|kTimelineEdgePadding" lib/screens/today/today_screen.dart` → 0 — no parallel arithmetic; confirmed independently by `26-REVIEW.md`'s deep-review pass. |
| `NowLineOverlay` | `TimelineGeometry` (via `today_screen.dart`) | `showChip` boolean computed from `geometry.liveStartMinutes`/`liveEndMinutes`, not re-derived from `resolveNowState` or the chunk list | WIRED | Matches the doc comment's own stated discipline; matches 26-UI-REVIEW.md's confirmation. |
| Centre-on-open `animateTo` | `TimelineGeometry.yFor(nowMinutes)` | `RenderAbstractViewport.getOffsetToReveal` + one `_didCentreOnOpen` flag | WIRED | Runs in every `NowState`, re-arms only on a new `dateYmd` or a `DevClock.offset` change — verified by the table-driven scroll test across all 5 states. |

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| CAL-01 | Time-proportional row heights | ✓ SATISFIED | Truth 1 above. |
| CAL-02 | Continuously-positioned now-line, including mid-chunk, superseding Phase 24 suppression | ✓ SATISFIED | Truth 2 above. |
| CAL-03 | Elapsed time recedes via deliberate scroll | ✓ SATISFIED | Truth 3 above. |

Note: `.planning/REQUIREMENTS.md`'s per-requirement summary table (bottom of file, "Last updated: 2026-08-10") still lists CAL-01/02/03 as "Not started," while the same file's checkbox list above it marks all three `[x]`. This is a stale table, not a code gap — it predates plans 26-01 through 26-10 and was never refreshed. Flagged for hygiene, not scored as a failure.

### Anti-Patterns Found

None. `grep -n -E "TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER"` across every file this phase touched (`timeline.dart`, `timeline_geometry.dart`, `today_screen.dart`, `now_line.dart`, `hour_axis.dart`, `timeline_row_tile.dart`, `free_time_row.dart`, `live_row_card.dart`, `time_format.dart`, `chunk_card.dart`, `swipeable_chunk_card.dart`) returns only benign doc-comment references to the test harness's "placeholder font" (not a code stub). No empty handlers, no hardcoded-empty data flowing to render, no `return null`/`return <Widget>[]` stand-ins.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full suite green | `flutter test` (run once, in full) | `+560: All tests passed!` | ✓ PASS |
| Analyzer clean | `flutter analyze` | "No issues found! (ran in 0.8s)" | ✓ PASS |
| Single now-detector | `grep -rn "resolveNowState" lib/ \| grep -vE "^[^:]+:[0-9]+:\s*//"` | exactly 2 lines (1 def, 1 call site) | ✓ PASS |
| `NowMarkerRow` fully retired | `grep -rn "NowMarkerRow" lib/ test/` | 0 hits | ✓ PASS |
| No independent geometry re-derivation | `grep -c "kPixelsPerMinute\|kLiveRowReservedHeight\|kTimelineEdgePadding" lib/screens/today/today_screen.dart` | 0 | ✓ PASS |
| G-04/G-05 rect tests exist and target the right assertion class | Read `test/screens/today_screen_test.dart:1163-1256` | `tester.getRect(...)`/`getTopLeft`/`getBottomLeft` compared against the Stack's own painted rect, at the exact boundary minute — not widget counts or label text | ✓ PASS |
| CAL-01/02/03 focused tests green | `flutter test test/screens/today_screen_test.dart test/screens/today_timeline_model_test.dart test/screens/today_row_widgets_test.dart test/utils/time_format_test.dart` | 165 tests, all pass | ✓ PASS |

### Probe Execution

Not applicable — this is a Flutter UI phase with no `scripts/*/tests/probe-*.sh` convention in this repo; none declared in the phase's PLAN/SUMMARY files.

### Track-record spot-check (per this phase's history of tests that passed against live bugs)

This phase shipped two prior defects behind green tests (26-07's `ChunkCard`-scoped regression test that missed the `LiveRowCard` collision, and the original "hour axis coverage" test that asserted widget count/text but never a rect). I read — not just grepped for existence — the two tests that were supposed to close the third and fourth rounds of the same failure class (G-03's `LiveRowCard`-named assertion at `today_screen_test.dart:985`, and G-04/G-05's rect-vs-Stack-bounds assertions at `:1163-1256`). Both genuinely assert what their names claim: G-03 asserts `findsNothing` for a chip finder scoped to `LiveRowCard`'s own subtree (not `ChunkCard`), and G-04/G-05 assert `tester.getRect(...)` against the Stack's own bounds, not a widget count. The `26-10-SUMMARY.md`'s claimed RED-before-GREEN proof (`git checkout HEAD~1`, observed failures at `170.0 < 180.0` and `270.0 < 284.0`, restored, re-passed) is consistent with the current code: reverting `kTimelineEdgePadding`'s application would reproduce exactly that shortfall given the constant's stated value of 14.0.

### Human Verification Required

This phase's own success gate (`26-06-PLAN.md`, `autonomous: false`, a `checkpoint:human-verify` task marked `gate="blocking"`) has not run. No `26-06-SUMMARY.md` exists, `26-VALIDATION.md` is unchanged since its 2026-08-10 creation (`status: draft`, `nyquist_compliant: false`, "Approval: pending"), and `STATE.md`'s own most recent log entry states plainly: "26-06-PLAN.md remains an open, unaddressed item for this phase." All four ROADMAP-level success criteria are verified true in the code and covered by tests that assert the right things (see above), and gap-closure plans 26-07 through 26-10 did substantial real-browser confirmation via headless Chromium with DevClock offsets (evidence in `evidence-26-08/`, `evidence-26-09/`, `evidence-26-10/`) — but the phase's own plan explicitly distinguishes "flutter test's placeholder font/pumped-frame harness" claims from "Dan's own eyes in a real GPU-backed browser," and the latter has not happened for the finished state of the surface.

1. **Real-browser sign-off on 26-06-PLAN.md's ten-item checklist**
   **Test:** Open a freshly-served debug build in a real GPU-backed browser; walk items 1-10 in `26-06-PLAN.md`'s `<how-to-verify>` block (gestalt shape, Full-tier card fit at `kPixelsPerMinute=5.5`, 5-min break legibility, now-line chip fit, live-row 232px reservation, hour-axis alignment, motion, "past recedes" across all four sampled states, tap-through).
   **Expected:** A pass or a named issue per item, recorded in `26-VALIDATION.md`'s Manual-Only Verifications table; `nyquist_compliant: true`.
   **Why human:** This is a harness-routed claim by explicit design (`26-VALIDATION.md`'s own table) — the widget-test font has no real Roboto metrics and a pumped frame cannot judge motion or gestalt.

2. **`kPixelsPerMinute = 5.5` and `kLiveRowReservedHeight = 232.0` scale verdict**
   **Test:** At Dan's actual screen size/DPI, confirm the 25-minute work card fits its 137.5px slot without clipping/crowding, and the live row's swell neither leaves an oversized gap nor collides with the row below.
   **Expected:** Either explicit confirmation the values hold, or a corrected constant with the resulting `26-UI-SPEC.md` amendment and updated tests.
   **Why human:** Both values are documented in `timeline_geometry.dart` as provisional, measured only via `flutter test`'s placeholder-font harness or headless-Chromium screenshots — the doc comments themselves name a real-browser check as "the actual authority," not yet performed by Dan.

3. **"Does the day read as a shape" / "does the past recede" — the perceptual claims**
   **Test:** Scroll a full day top to bottom without reading any times; separately, open the screen cold at PreStart/Active/GapBeforeNext/DayComplete via DevClock and judge whether "now" feels centred and the morning feels genuinely behind you.
   **Expected:** A qualitative confirmation or a specific complaint (as happened at the first 26-06 gate attempt, which produced G-01/G-02/G-03).
   **Why human:** Gestalt and felt-experience claims — the exact class Dan's own origin quote for this phase asked for, and not something a rect assertion or a screenshot crop can settle definitively, even though the automated evidence in `evidence-26-10/` is suggestive and consistent with a pass.

### Gaps Summary

No code-level truth failed. All four ROADMAP success criteria (CAL-01, CAL-02, CAL-03, and the single-clock-sample rule) are implemented, wired, and covered by tests that assert the specific thing they claim to — including the two classes of test that previously went green against live bugs in this same phase (widget-count/text-only assertions, and card-type-scoped assertions that missed a sibling widget type). `flutter test` (560/560) and `flutter analyze` (clean) both pass when run directly, matching the SUMMARY claims.

The phase is not fully closed by its own definition, though: `26-06-PLAN.md` is a blocking, non-autonomous checkpoint requiring Dan's real-browser sign-off, and it has not executed — `26-VALIDATION.md` remains `status: draft` / `nyquist_compliant: false`, consistent with (and explicitly flagged by) this project's own carried-debt pattern for phases 15/16/17 and 23. Given that no code defect was found, this routes to `human_needed` rather than `gaps_found`: the work is technically sound and ready for Dan's look, not broken.

---

_Verified: 2026-08-13T13:32:16Z_
_Verifier: Claude (gsd-verifier)_

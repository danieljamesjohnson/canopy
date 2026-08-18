---
phase: 27-true-grid
verified: 2026-08-18T16:45:00Z
status: human_needed
score: 16/17 must-haves verified (1 pending human sign-off, not failed)
overrides_applied: 0
human_verification:
  - test: "36×36dp Complete/Skip icon-button tap targets, on an actual touch device (thumb, not mouse), including at a larger system text scale"
    expected: "Complete/Skip hit reliably; if fiddly, the recorded remedy is more slot height (revisit kPixelsPerMinute), never smaller text or a dropped action"
    why_human: "Declared WCAG exception (36dp < 44dp recommended). 27-UI-SPEC.md and 27-VALIDATION.md both explicitly forbid closing this on a code review or a headless screenshot — it requires a real thumb on a real touch device."
  - test: "The now-line's 2dp rule crossing the live card's text, watched early and late in the same live chunk, on both the compact and single-line tiers"
    expected: "Text stays legible on both sides of the stroke everywhere it lands"
    why_human: "Subjective legibility judgement (27-VALIDATION.md 'Manual-Only Verifications'). Static screenshots (reviewed below) look legible at two sampled instants, but the phase's own validation contract does not treat that as sufficient sign-off."
  - test: "The day reads as shorter and the grid reads as uniform, in the hand, while scrolling with a chunk live"
    expected: "Every hour bracket looks the same height; nothing overlaps; no card clips mid-glyph"
    why_human: "Perceptual/feel judgement distinct from the pixel-measured UNIFORM verdict already obtained programmatically."
---

# Phase 27: True Grid Verification Report

**Phase Goal:** Every hour on the Today timeline occupies the same vertical distance, always — an
hour is an hour, whatever is happening inside it. (GRID-01 uniform hour spacing, GRID-02 live-row
prominence without variable height.)

**Verified:** 2026-08-18
**Status:** human_needed
**Re-verification:** No — initial verification

## Verification Stance and What Was Actually Checked

This report does not accept the SUMMARY.md claims at face value. Every load-bearing claim below was
independently re-derived against the current codebase and, where the phase's own validation
contract required a real-browser artifact, against the committed screenshots — re-running the
committed measurement tools myself rather than trusting the numbers pasted into the summaries.

Independently re-run in this verification session (not merely re-read from summaries):
- `flutter test test/screens/today_timeline_model_test.dart --plain-name 'GRID-01'` → 2 tests passed.
- `flutter analyze` → No issues found.
- `flutter test` (full suite) → **567 tests, all passed.**
- `grep -rn "liveExtraPx\|kLiveRowReservedHeight" lib/ test/` → 1 hit, and it is a plain-text
  historical mention inside `kCompactLiveMinHeight`'s doc comment ("`kLiveRowReservedHeight`'s
  now-deleted precedent was..."), not a live symbol reference — confirmed by reading the line.
- `python3 .planning/spikes/001-live-row-in-a-true-grid/tools/measure_hours.py` against both
  committed evidence screenshots (`uniform-1000-work-live.png`, `uniform-1022-break-live.png`) →
  **both print `VERDICT: UNIFORM`**, spread `0.0`, spacing `240.0` px, no `132.0` anywhere.
- `python3 .planning/phases/27-true-grid/tools/measure_card_fill.py` against both tier screenshots
  → compact tier band height **76px**, single-line tier band height **16px** — matching the numbers
  recorded in `kCompactLiveMinHeight`'s doc comment (`84.0 = 76 + 8`) exactly.
- Read `lib/screens/today/timeline_geometry.dart`, `lib/screens/today/widgets/live_row_card.dart`,
  and the live-row arm of `today_screen.dart`'s `_buildPositionedRow` directly, line by line.
- Read all six committed evidence screenshots under `.planning/phases/27-true-grid/shots/` with the
  Read tool (not merely trusted the summary's prose description of them).
- Confirmed all 13 commit hashes cited across the four SUMMARY.md files and the REVIEW/REVIEW-FIX
  pair exist in `git log`.
- Confirmed the WR-01 code-review fix (restored `tester.tap(find.text('Reading'))`, replacing the
  bypass) is actually present in `test/screens/today_screen_test.dart` today, not just claimed in
  `27-REVIEW-FIX.md`.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Every hour boundary is the same pixel distance from the next, including the hour containing a live chunk's end (GRID-01) | ✓ VERIFIED | `timeline_geometry.dart:290-295` — `yFor()` is a single unconditional expression, no `if`. `measure_hours.py` independently re-run against both committed screenshots: `UNIFORM`, spread `0.0`, `240.0`px every boundary, no `132.0` (the defect's signature) anywhere. |
| 2 | A regression test exists that can fail if the live-row exception is reintroduced, proven RED first | ✓ VERIFIED | `test/screens/today_timeline_model_test.dart`, `'GRID-01: every hour boundary is equidistant...'`, asserts against the independent ground truth `60 * kPixelsPerMinute` (never re-derives `liveExtraPx`). `27-01-SUMMARY.md` captures the verbatim RED output (`372.0` actual vs `240.0` expected at the 540→600 boundary) before the fix; independently re-ran the same command against current `HEAD` and confirmed it passes now. |
| 3 | No symbol named `liveExtraPx` or `kLiveRowReservedHeight` exists anywhere in `lib/` or `test/` | ✓ VERIFIED | Repo-wide grep: 1 hit total, a plain-text historical mention inside a doc comment (`timeline_geometry.dart:102`), not a live symbol. Read the line directly to confirm. |
| 4 | The live row occupies exactly its duration-implied slot, like every other row (GRID-02) | ✓ VERIFIED | `today_screen.dart`'s live arm of `_buildPositionedRow`: `Positioned(height: slot)` where `slot = geometry.heightFor(...)`, through the same `ClipRect`/`OverflowBox` path the non-live arm uses. `test/screens/today_screen_test.dart`'s `'GRID-02: the live row's rendered slot is duration-exact...'` measures the `ClipRect` (not the card) at `5 * kPixelsPerMinute` and `25 * kPixelsPerMinute`. |
| 5 | A live 25-minute work chunk shows kicker, title, countdown and both Complete/Skip inside its 100dp slot, without clipping | ✓ VERIFIED | Code: `_buildCompact` in `live_row_card.dart` renders exactly these four elements, no fifth. Real-browser evidence: `compact-1000-work-live.png` (read directly) shows all four, no clipping; `measure_card_fill.py` independently re-run: 76px natural height inside a 100px slot (24px slack). |
| 6 | A live 5-minute break says what it is and how long is left, in one legible line inside its 20dp slot | ✓ VERIFIED | Code: `_buildSingleLine`. Real-browser evidence: `single-line-1022-break-live.png` (read directly) shows "Taking a break · 3 min left · until 10:25 AM" on one legible line. `measure_card_fill.py` independently re-run: 16px, under the required `20.0`. |
| 7 | A live work chunk rendering single-line can still be acted on, by tapping the row | ✓ VERIFIED | `live_row_card.dart`: `Semantics(..., button: onTap != null, onTap: onTap)` wraps an `InkWell` when `onTap != null`; `today_screen.dart` wires `onTap` per PD-27-06 (non-null only for an unresolved live work chunk) to open `ChunkDetailSheet`. |
| 8 | The live row carries no progress bar and no "Next ·" line in either tier | ✓ VERIFIED | `grep -c "LinearProgressIndicator\|nextLine" lib/screens/today/widgets/live_row_card.dart` → `0`. Confirmed by direct read of both tier builders — neither exists. |
| 9 | The prominence tradeoff (option a) was actually delivered — fill, square corners, elevation, now-line carry prominence, not height | ✓ VERIFIED | `_buildCompact`/`_buildSingleLine`: `color: colorScheme.primaryContainer`, `shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero)`, `elevation: 6`/`4`. Now-line crossing confirmed harmless by reading `nowline-early-1000-work-live.png` (crosses the kicker, legible both sides) and `nowline-late-1017-work-live.png` (crosses near the bottom edge, clear of text). |
| 10 | The whole suite is green, with no assertion weakened into vacuity | ✓ VERIFIED | Independently re-ran full `flutter test`: 567 tests, all passed. `flutter analyze`: clean. Code review (`27-REVIEW.md`) specifically checked for vacuous assertions and found/fixed one (`'live break shows no Complete/Skip (D-02)'` — its old `FilledButton`/`OutlinedButton` finders matched widget types the code can no longer produce); confirmed the strengthened tooltip/`IconButton`-absence assertions are present in the test file. |
| 11 | `kCompactLiveMinHeight` is a real-browser measurement with a doc comment stating method and invalidation conditions | ✓ VERIFIED | `timeline_geometry.dart:81-138`: `84.0`, doc comment states date, viewport (430×930, DPR 1), port 8137, method, raw measured number (76px), explicit safety margin (8px), the Pitfall-6 relationship to `kFullTierMinHeight` (kept separate, reasoned), and an explicit "what would invalidate this" paragraph. `grep -c "UNMEASURED"` → `0`. Independently re-ran `measure_card_fill.py` against the committed screenshots and got the identical 76px/16px the doc comment cites — not merely re-read the claim. |
| 12 | `measure_hours.py` prints `UNIFORM` against a screenshot taken while a chunk is live | ✓ VERIFIED | Independently re-ran (not just re-read the summary) against both `uniform-1000-work-live.png` (work chunk live) and `uniform-1022-break-live.png` (break live) — both print `VERDICT: UNIFORM`. |
| 13 | The 36×36dp Complete/Skip targets have been tried on an actual touch device | ⬜ PENDING (human-only) | `27-04-PLAN.md` Task 3 is a `checkpoint:human-verify gate="blocking"` task. `27-04-SUMMARY.md` states explicitly: "Task 3 is PENDING... this plan is NOT closed, and neither is Phase 27... Do not treat GRID-02's touch-target exception as closed on the strength of this summary alone." `STATE.md`/`ROADMAP.md` both currently and honestly reflect this as outstanding. This is not a code gap — it is a declared, correctly-unresolved human checkpoint. |

**Score:** 16/17 truths verified by code/pixel evidence; 1 requires a human on a touch device and is
honestly still open (not silently skipped, not falsely claimed passed anywhere in the phase's own
artifacts).

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/screens/today/timeline_geometry.dart` | Branch-free `yFor()`; `kCompactLiveMinHeight` measured | ✓ VERIFIED | Read directly. `yFor()` single expression, no `if`. `kCompactLiveMinHeight = 84.0` with full measurement doc comment. |
| `test/screens/today_timeline_model_test.dart` | GRID-01 equidistance test asserting against `60 * kPixelsPerMinute` | ✓ VERIFIED | Present, independently re-run, passes. |
| `lib/screens/today/widgets/live_row_card.dart` | Two slot-height-selected density tiers, no progress bar/next line | ✓ VERIFIED | Read directly. `build()` is `slotHeight >= kCompactLiveMinHeight ? _buildCompact(...) : _buildSingleLine(...)`. |
| `lib/screens/today/today_screen.dart` | Live row through the same `Positioned`+`ClipRect`+`OverflowBox` path as every other row | ✓ VERIFIED | Read directly, `_buildPositionedRow`'s live arm. |
| `test/screens/today_screen_test.dart` | GRID-02 duration-exact slot regression test | ✓ VERIFIED | Present (`'GRID-02: the live row's rendered slot is duration-exact, not swelled'`), measures `ClipRect` not the card. |
| `.planning/phases/27-true-grid/tools/measure_card_fill.py` | Reproducible pixel-count script, committed | ✓ VERIFIED | Exists, independently re-run against both committed screenshots, reproduces the exact numbers cited in the doc comment. |
| `.planning/phases/27-true-grid/shots/` | Evidence screenshots, live work chunk and live break | ✓ VERIFIED | 6 PNGs present, all opened and visually inspected in this session. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `test/screens/today_timeline_model_test.dart` | `TimelineGeometry.yFor` | equidistance loop asserting `60 * kPixelsPerMinute` | ✓ WIRED | Independently re-run, passes against current `yFor()`. |
| `today_screen.dart` (live arm) | `LiveRowCard.slotHeight` | `geometry.heightFor(start, chunk.durationMinutes)` threaded through `_buildLiveRow` | ✓ WIRED | Confirmed by direct read; `slot` computed once, passed to both the `Positioned.height` and `_buildLiveRow`'s `slotHeight` argument. |
| `live_row_card.dart` | `kCompactLiveMinHeight` | tier selection in `build()` | ✓ WIRED | `slotHeight >= kCompactLiveMinHeight` — confirmed by direct read, matches the widget test's boundary assertions exactly. |
| `LiveRowCard._buildCompact`'s icon buttons | `ScheduleNotifier.markComplete`/`markSkipped` | `onPressed` closures reading `context.read<ScheduleNotifier>()` | ✓ WIRED | Confirmed by direct read; scoped to the passed `chunkId` (T-22-04 invariant). |
| `live_row_card.dart`'s single-line `onTap` | `ChunkDetailSheet` | `today_screen.dart`'s PD-27-06 gate → `_openDetailSheet` | ✓ WIRED | Confirmed by direct read of `_buildLiveRow`. |

### Data-Flow Trace (Level 4)

Not applicable in the conventional sense — this phase is pure client-side layout arithmetic and
widget composition over already-loaded local schedule data (no network I/O, no persistence change).
The relevant "data flow" for this phase is geometric: slot height → tier selection → rendered
content, and start minute → `yFor()` → pixel offset. Both traced and confirmed above (Truths 1, 4,
5, 6; Key Links table).

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| GRID-01 equidistance test currently passes | `flutter test test/screens/today_timeline_model_test.dart --plain-name 'GRID-01'` | `+2: All tests passed!` | ✓ PASS |
| Full suite green | `flutter test` | `567 tests, all passed` | ✓ PASS |
| Static analysis clean | `flutter analyze` | `No issues found!` | ✓ PASS |
| Painted hour spacing uniform, work chunk live | `measure_hours.py uniform-1000-work-live.png` | `VERDICT: UNIFORM`, spread `0.0` | ✓ PASS |
| Painted hour spacing uniform, break live | `measure_hours.py uniform-1022-break-live.png` | `VERDICT: UNIFORM`, spread `0.0` | ✓ PASS |
| Compact tier natural height fits its slot | `measure_card_fill.py compact-1000-work-live.png` | `76 px` (< 100px slot) | ✓ PASS |
| Single-line tier natural height fits its slot | `measure_card_fill.py single-line-1022-break-live.png` | `16 px` (< 20px slot) | ✓ PASS |
| No dead reference to the deleted mechanism | `grep -rn "liveExtraPx\|kLiveRowReservedHeight" lib/ test/` | 1 hit, historical doc-comment prose only | ✓ PASS |
| No debt markers in phase-touched files | `grep -n -E "TBD\|FIXME\|XXX\|TODO\|HACK\|PLACEHOLDER"` across the 7 modified files | no hits | ✓ PASS |

### Probe Execution

No `scripts/*/tests/probe-*.sh` convention is used by this project; this phase's real-browser
verification step (`measure_hours.py`, `measure_card_fill.py`) functionally serves the same
role and was executed directly above under Behavioral Spot-Checks, independently in this session
rather than trusted from the summaries.

### Requirements Coverage

This is a standalone phase (no milestone, no `REQUIREMENTS.md` entry) — requirements are declared
directly in `ROADMAP.md`'s Phase 27 section and each plan's frontmatter.

| Requirement | Source Plan(s) | Description | Status | Evidence |
|---|---|---|---|---|
| GRID-01 | 27-01 | Uniform hour spacing | ✓ SATISFIED | `yFor()` branch-free; equidistance test; `measure_hours.py` UNIFORM independently re-confirmed. |
| GRID-02 | 27-02, 27-03, 27-04 | Live-row prominence without variable height | ✓ SATISFIED (code/pixel evidence complete) — **touch-target UAT item still open** | Duration-exact slot, two density tiers, prominence markers, Complete/Skip reachable on both tiers, all confirmed. The one declared exception (36×36dp targets) requires human sign-off per the UI-SPEC's own explicit terms and is not yet closed. |

### Anti-Patterns Found

None found in the 7 files this phase modified. No `TODO`/`FIXME`/`HACK`/`PLACEHOLDER`/`XXX`/`TBD`
markers. No empty implementations, no hardcoded-empty stub data. The one thing that would have been
an anti-pattern — a hit-test regression test weakened to bypass a real tap after the defect it
worked around was fixed (WR-01 in `27-REVIEW.md`) — was found by this phase's own code review and
confirmed fixed in the current source (`test/screens/today_screen_test.dart:497-534` now uses
`tester.tap(find.text('Reading'))`, not the earlier direct-callback bypass).

### Human Verification Required

### 1. 36×36dp Complete/Skip touch targets on a real device

**Test:** With a work chunk live, tap the Complete icon on the live card with a thumb, then Skip on
the next one, on an actual phone or tablet (not a mouse). Try once more at a larger system text
scale.
**Expected:** They hit reliably. If fiddly, the agreed remedy is more slot height (revisit
`kPixelsPerMinute`), never smaller text or a dropped action.
**Why human:** This is a declared WCAG exception (36dp is below the 44dp recommendation),
explicitly accepted as a stated trade rather than a settled decision by `27-UI-SPEC.md`, which
requires it be "confirmed on an actual touch device during UAT" before being treated as closed. No
amount of code review or headless-browser pixel measurement can substitute for a thumb.

### 2. Now-line crossing the live card, in the hand

**Test:** Watch the live card early in a chunk and again late in it (both tiers). The 2dp rule cuts
through different text at different points.
**Expected:** Text stays legible on both sides of the stroke everywhere it lands.
**Why human:** `27-VALIDATION.md` classifies this as subjective legibility judgement. The two
sampled screenshots reviewed in this verification (`nowline-early-1000-work-live.png`,
`nowline-late-1017-work-live.png`) both look legible by inspection, but the phase's own validation
contract does not treat two static samples as a substitute for the human check, and the checkpoint
in `27-04-PLAN.md` Task 3 asks for it explicitly.

### 3. The day reads as shorter, and the grid reads as uniform, in the hand

**Test:** Scroll the timeline with a chunk live.
**Expected:** Every hour bracket looks the same height; more of the day fits on screen than before;
nothing overlaps; no card clips mid-glyph.
**Why human:** Perceptual/feel judgement distinct from the pixel-measured `UNIFORM` verdict already
obtained programmatically (Truth 1/12 above) — `27-04-PLAN.md`'s checkpoint asks for this as a
separate, human "in the hand" confirmation.

**These three items are one unresolved gate, not three independent gaps** — `27-04-PLAN.md`'s
Task 3 is a single `checkpoint:human-verify gate="blocking"` task presenting all three together.
The phase's own artifacts (`27-04-SUMMARY.md`, `STATE.md`, `ROADMAP.md`) already and correctly
disclose this as pending; this verification confirms that disclosure is accurate and that
everything upstream of it (the code, the automated tests, the pixel evidence) is genuinely done —
not merely claimed done.

### Gaps Summary

No code-level gaps found. Every must-have that can be verified by code inspection, `flutter test`,
`flutter analyze`, or a real-browser pixel measurement is VERIFIED, and every such verification in
this report was independently re-executed rather than taken on the summaries' word — including
re-running `measure_hours.py` and `measure_card_fill.py` myself against the committed screenshots
and getting numbers that match the doc comments exactly.

The single outstanding item is the phase's own declared, blocking human-verify checkpoint
(`27-04-PLAN.md` Task 3): tapping the 36×36dp Complete/Skip targets on a real touch device, judging
the now-line's legibility in the hand, and confirming the grid reads as uniform while scrolling.
This is not a defect in the implementation — it is a verification step that by design cannot be
performed by an agent, and the phase's own artifacts already say so honestly. Routing this phase to
`human_needed` rather than `passed` reflects that the phase is not yet closeable, and routing it to
`human_needed` rather than `gaps_found` reflects that nothing found here is a code problem to send
back to a planner.

---

_Verified: 2026-08-18_
_Verifier: Claude (gsd-verifier)_

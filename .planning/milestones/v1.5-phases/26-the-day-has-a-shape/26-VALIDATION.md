---
phase: 26
slug: the-day-has-a-shape
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-10
---

# Phase 26 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `26-RESEARCH.md` § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (bundled with Flutter SDK 3.44.1) — already a dev dependency, no install needed |
| **Config file** | none dedicated — tests auto-discovered under `test/`; `analysis_options.yaml` governs lint only |
| **Quick run command** | `flutter test test/screens/today_timeline_model_test.dart test/screens/today_row_widgets_test.dart test/screens/today_screen_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~1–2s quick · ~13s full (515 tests, baseline confirmed green 2026-08-10) |

---

## Sampling Rate

- **After every task commit:** Run the quick command (the three files carrying this phase's blast radius)
- **After every plan wave:** Run `flutter test` — confirms `today_screen_now_state_test.dart`'s 50 `resolveNowState`/`LiveRowCard` tests, which this phase must NOT touch, stay green
- **Before `/gsd-verify-work`:** Full suite green, plus a served debug build for the harness-bound checks
- **Max feedback latency:** ~13 seconds

---

## Per-Task Verification Map

> Filled in during execution. Task IDs assigned by the planner.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| _pending_ | — | — | CAL-01 | — | N/A (no threat surface — pure local rendering) | widget | quick command | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

### Requirement → assertion map (from RESEARCH.md)

| Req | Behavior | Type | Why it is trustworthy in the harness |
|-----|----------|------|--------------------------------------|
| CAL-01 | A chunk/gap row's rendered height equals `durationMinutes * kPixelsPerMinute` | widget | **Geometric, not text-driven** — the placeholder-font metric distortion (Pitfall 7) does not affect a height computed from arithmetic |
| CAL-01 | Compact (<20min) vs Full (≥20min) content density switches at the threshold | widget | Tier selection is a duration comparison, not a measurement |
| CAL-02 | Now-line `Positioned(top:)` equals `(nowMinutes - rangeStart) * kPixelsPerMinute`, including mid-chunk `Active` | widget | Geometric |
| CAL-02 | Now-line renders in **every** `NowState` — no suppression (supersedes Phase 24's `Active`-suppression rule) | widget | State enumeration |
| CAL-03 | Post-open scroll offset equals the clamped centre-on-now target | widget | Follows the existing 24-04 offset-assertion pattern |
| CAL-03 | A 1-minute tick after open does NOT re-trigger the centre-on-open scroll | widget | Carries forward the existing "centres once" pattern |

---

## Wave 0 Requirements

- [ ] **No new test file needed.** The three existing files are the correct home for rewritten
      assertions, and their fixture helpers (`pumpDay` / `buildDayFixture`, per STATE.md's Phase
      24-02 note) are reusable as-is.
- [ ] Direct unit tests for the new pure functions as they are written — `floorToHour` /
      `ceilToHour`, `hourBoundariesIn`, and the rendered-range formula
      (`rangeStart`/`rangeEnd` from `nowMinutes`/`firstStart`/`lastEnd`). None of these exist in
      `lib/utils/time_format.dart` today (verified by file read).
- [ ] Framework install: **none** — `flutter_test` already in active use.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Text fits / ellipsizes correctly inside the 20px Compact-tier break row and the now-line time chip | CAL-01 | **Harness-bound (Pitfall 7).** `flutter test`'s placeholder font has no real Roboto metrics and inflates measured glyph width to a fontSize-wide box per character. This already produced a wrong `kGutterWidth` of 75 that had to be corrected to 52 after a real-browser check — a text-fit assertion here would repeat that mistake | `flutter build web --debug --source-maps --pwa-strategy=none`, serve with `python3 tools/serve-uat.py <fresh port> --dir build/web`, inspect a day containing a 5-minute break |
| The now-line visibly *moves* and the day's shape reads as a shape | CAL-01, CAL-02 | Motion and gestalt cannot be judged from a pumped frame | Use Phase 25's DevClock **offset** (not a frozen instant — time still flows) to sit at several moments; watch the line advance across a minute tick |
| "Elapsed time recedes" actually feels like the past is behind you | CAL-03 | Perceptual claim — the exact class of claim that failed the first widget-tests-green-but-Dan-still-confused round in Phase 24-03 | Open the served build cold at several times of day; confirm the past is off-screen without manual scrolling |

### Outcome — Dan, 2026-08-14

**Verdict: pass.** Given at the final gate against the build served on `http://danserver:8134/`,
after four rounds of gap closure (G-01..G-06 all closed or explicitly accepted) and having been
shown the outstanding caveat below.

**Recorded precisely, because the distinction matters:** this was a **blanket pass** on the surface
as a whole, not an item-by-item verdict on each row of this table. Per-row verdicts are not
back-filled here, because nobody gave them and inventing them would defeat the purpose of a
manual-only gate. What Dan saw before signing: the rendered PreStart surface with the corrected
hour label and AM-marked chip, the mid-chunk before/after crops from G-03, and the live-row
spacing evidence from G-02.

**One item is explicitly NOT confirmed by this sign-off:**

`kPixelsPerMinute = 5.5` remains **provisional**. It was set from a `flutter test` measurement
(a Full-tier work card at 126px overflowing the 100px slot that 4.0 would give a 25-min chunk),
which is the same harness class that produced the wrong `kGutterWidth` of 75. A 12-hour day is
~3960px at this scale. Dan was told this at the gate and elected to close the phase rather than
adjust; the constant's own doc comment carries the same warning. If the day ever reads as too tall
or too cramped, this is the dial — and changing it is contained (constant, geometry tests,
UI-SPEC amendment).

`kLiveRowReservedHeight = 232.0` is on firmer ground: it came from a real-browser measurement of
the tallest (work) variant, 224px + 8px margin.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references — no new test file was needed; the new pure functions
      (`floorToHour`, `ceilToHour`, `hourBoundariesIn`, the rendered-range formula) all have direct
      unit tests in `test/utils/time_format_test.dart` and `test/screens/today_timeline_model_test.dart`
- [x] No watch-mode flags
- [x] Feedback latency < 15s (full suite ~15s at 560 tests)
- [x] `nyquist_compliant: true` set in frontmatter

**Assertion-quality note (added at sign-off, and the honest lesson of this phase):** two defects
shipped behind green tests here — 26-07's regression test asserted against `ChunkCard` when the
defect lived in `LiveRowCard`, and the hour-axis test asserted widget counts and label text but
never a painted rect. Both were green against live bugs. From 26-09 onward every regression test in
this phase was required to be **observed RED against the unfixed code** before acceptance, which is
how G-04 and G-05 were closed properly. Recorded here rather than in a summary, because this table
is what a future phase reads when deciding what "verified" means.

**Approval:** approved 2026-08-14 (Dan, final gate)

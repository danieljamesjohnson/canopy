---
phase: 26
slug: the-day-has-a-shape
status: draft
nyquist_compliant: false
wave_0_complete: false
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

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

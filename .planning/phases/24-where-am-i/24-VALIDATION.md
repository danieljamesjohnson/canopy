---
phase: 24
slug: where-am-i
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-08
---

# Phase 24 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `24-RESEARCH.md` § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (bundled with the Flutter SDK, already in `pubspec.yaml` dev_dependencies) |
| **Config file** | none — standard `flutter test` runner, no custom config |
| **Quick run command** | `flutter test test/screens/today_timeline_model_test.dart test/screens/today_screen_test.dart test/screens/today_row_widgets_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~20s quick · ~90s full |

---

## Sampling Rate

- **After every task commit:** Run the quick command above
- **After every plan wave:** Run `flutter test` (full suite)
- **Before `/gsd-verify-work`:** Full suite green AND `flutter analyze` clean
- **Max feedback latency:** ~20 seconds

---

## Per-Task Verification Map

Task IDs are assigned by the planner; rows below are keyed by behavior and are the
contract each task must satisfy. The executor fills `Task ID` / `Plan` / `Wave` as
tasks land.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 24-01 / Task 2 | 24-01 | 1 | NOW-01 | — | N/A | unit | `flutter test test/screens/today_timeline_model_test.dart` | ✅ extend | ✅ green |
| 24-01 / Task 2 | 24-01 | 1 | NOW-02 | — | N/A | unit | `flutter test test/screens/today_timeline_model_test.dart` | ✅ extend | ✅ green |
| 24-01 / Task 3 | 24-01 | 1 | NOW-01 | — | N/A | widget | `flutter test test/screens/today_row_widgets_test.dart` | ✅ extend | ✅ green |
| 24-02 / Task 1 | 24-02 | 2 | NOW-01 | — | N/A | widget | `flutter test test/screens/today_screen_test.dart` | ✅ extend | ✅ green |
| 24-02 / Task 2 | 24-02 | 2 | NOW-02 | — | N/A | widget | `flutter test test/screens/today_screen_test.dart` | ✅ **edit** (stale assertion, see below) | ✅ green |

### Behavior contract (what the rows above must prove)

| Requirement | Behavior that must be proven |
|-------------|------------------------------|
| NOW-01 | `buildTimeline` inserts the now-marker row at the correct position for `PreStart`, `GapBeforeNext`, `Overdue` and `DayComplete` |
| NOW-01 | The marker's clock position is exactly the `nowDt` sample `resolveNowState` already receives — never a second clock read. Asserted via the injected `now:` closure pattern used throughout `today_screen_now_state_test.dart` |
| NOW-01 | The marker widget renders through `TimelineRowTile` and is visible in a rendered `TodayScreen` for each non-suppressed state |
| NOW-01 | INVARIANT 1 holds: `buildTimeline` still reads no clock — position arrives as a parameter |
| NOW-02 | The leading free row is suppressed once its window has closed |
| NOW-02 | `test/screens/today_screen_test.dart:364-370` — which currently asserts `"Free until 8:00 AM"` is present at a 10:47 AM clock, i.e. pins the bug — is **corrected**, not merely left green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

None. Existing infrastructure covers every test type this phase needs:

- `test/screens/today_timeline_model_test.dart` — pure `buildTimeline` unit tests
- `test/screens/today_row_widgets_test.dart` — widget-level row rendering
- `test/screens/today_screen_test.dart` — full-screen integration
- `test/screens/today_screen_now_state_test.dart` — `resolveNowState` / clock-injection patterns

No new test file, fixture helper, or framework install is required. Extend the four
existing files using their own established conventions (`_workChunk` / `_breakChunk`
factories, `pumpWithMood`, `_pumpTodayScreen`, injectable `now:` closures).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| The marker actually answers "where am I" at a glance | NOW-01 | Legibility is a perceptual judgement no widget test can make — this phase exists *because* an implementation that passed its tests still left Dan unable to locate himself | Build the debug web bundle per CLAUDE.md (`flutter build web --debug --source-maps --pwa-strategy=none`), serve on a fresh port, open on a real GPU-backed browser mid-day, and confirm "now" is findable without reading the header |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references *(N/A — no gaps)*
- [x] No watch-mode flags
- [x] Feedback latency < 20s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** automated tasks green; the perceptual "where am I" check further up this
document remains open for plan 24-03.

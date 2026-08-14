---
phase: 23
slug: live-activity-tracking
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-07
---

# Phase 23 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (bundled with Flutter SDK `>=3.18.0-18.0.pre.54`) |
| **Config file** | none — standard `flutter test` discovery over `test/` |
| **Quick run command** | `export PATH="$PATH:/home/dan/development/flutter/bin"; flutter test test/screens/today_screen_now_state_test.dart test/screens/today_timeline_model_test.dart test/screens/today_screen_test.dart` |
| **Full suite command** | `export PATH="$PATH:/home/dan/development/flutter/bin"; flutter test` |
| **Estimated runtime** | ~2s quick / ~11s full (420 tests at phase start) |

**No new framework or fixture infrastructure needed** — every test below extends an existing file
using a pattern already proven in this suite. `flutter_test`'s built-in fake clock
(`tester.pump(Duration)`) is sufficient for deterministic countdown testing; no `fake_async` package.

---

## Sampling Rate

- **After every task commit:** the quick command above
- **After every plan wave:** `flutter test` (full suite — cheap at ~11s)
- **Before `/gsd-verify-work`:** full suite green **and** `flutter analyze` clean
- **Max feedback latency:** ~11 seconds

---

## Per-Task Verification Map

| Req | Behavior | Test Type | Automated Command | File Exists | Status |
|-----|----------|-----------|-------------------|-------------|--------|
| LIVE-01 | Running break resolves as `Active`/`Overdue`, not `GapBeforeNext` | unit | quick cmd | ✅ extend | ⬜ pending |
| LIVE-01 | Live break row shows rest kicker + break title, **no Complete/Skip** | widget | quick cmd | ✅ extend | ⬜ pending |
| LIVE-01 | "Next · …" renders correctly when the upcoming activity is a break | widget | quick cmd | ✅ extend | ⬜ pending |
| LIVE-01 | **"Start focus" is disabled when `nowState` targets a break** | widget | quick cmd | ❌ W0 | ⬜ pending |
| LIVE-02 | ≥60s remaining shows whole minutes, rounded up (boundary: 61s → "2 min left") | unit/widget | quick cmd | ✅ extend | ⬜ pending |
| LIVE-02 | <60s remaining shows seconds, updating on `pump(Duration(seconds: 1))` | widget | quick cmd | ❌ W0 | ⬜ pending |
| LIVE-02 | Fast timer does not leak across pause/resume (no pending-timer failure) | widget | quick cmd | ❌ W0 | ⬜ pending |
| LIVE-03 | PreStart copy distinct and truthful | widget | quick cmd | ✅ edit in place | ⬜ pending |
| LIVE-03 | DayComplete copy distinct and truthful | widget | quick cmd | ✅ edit in place | ⬜ pending |
| LIVE-03 | Gap banner behavior confirmed (see Open Question below) | widget | quick cmd | ✅ if no-change | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Break-as-`Active`/`Overdue` and break-as-`next` unit cases — **extend**
      `test/screens/today_screen_now_state_test.dart`, do not create a new file (keeps the
      resolveNowState suite consolidated, matching the single-detector philosophy)
- [ ] Fast-timer (<60s) widget group in the same file, modeled on the existing timer/lifecycle test
- [ ] **Focus-target-excludes-breaks regression test** in `today_screen_test.dart`'s existing WR-01
      group — this is the highest-severity gap research found and currently has zero coverage
- [ ] Shared break-title helper unit test, if the planner extracts it as a standalone function rather
      than a private method

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| The countdown *visibly* moves and feels smooth, not janky | LIVE-02 | A widget test proves the string changes on a pumped tick; it cannot judge whether the real render updates smoothly or stutters on a ~900-line screen | Open the served debug build with a chunk in its final minute and watch the live row for ~90 seconds across the 60s boundary (seconds → minutes handover) |
| A running break genuinely *reads* as a break, not as dead time | LIVE-01 | Copy/tone judgment | Open the app during a scheduled break and read the live row |

---

## Known ambiguity to settle during planning

`23-UI-SPEC.md` gives new copy for PreStart and DayComplete but **not** for the `GapBeforeNext` state.
Research recommends the default of **no change** to the gap banner. The planner must state which it
chose so the LIVE-03 gap test asserts against a decided contract rather than a guess.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

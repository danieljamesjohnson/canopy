---
phase: 8
slug: a-schedule-you-can-read
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-10
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK built-in) |
| **Config file** | none — flutter test runs from project root |
| **Quick run command** | `flutter test test/services/schedule_generator_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds (full suite) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/services/schedule_generator_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 8-gen-01 | generator | 1 | READ-02 | — | N/A | unit | `flutter test test/services/schedule_generator_test.dart` | ✅ (extend) | ⬜ pending |
| 8-gen-02 | generator | 1 | READ-02 | — | N/A (no breaks inside commitment window; trailing break trimmed) | unit | `flutter test test/services/schedule_generator_test.dart` | ✅ (extend) | ⬜ pending |
| 8-card-01 | card | 2 | READ-01 | — | N/A | widget | `flutter test test/screens/chunk_card_goal_name_test.dart` | ❌ W0 | ⬜ pending |
| 8-sheet-01 | sheet | 2 | READ-03 | — | N/A | widget | `flutter test test/screens/chunk_detail_sheet_test.dart` | ❌ W0 | ⬜ pending |
| 8-defer-01 | sheet | 2 | READ-03 | — | markDeferred sets isDeferred=true + isSkipped=true, notifies | unit | `flutter test test/providers/schedule_notifier_defer_test.dart` | ❌ W0 | ⬜ pending |
| 8-focus-01 | focus | 3 | READ-04 | — | Timer.cancel() in dispose (no setState-after-dispose leak) | widget | `flutter test test/screens/focus_screen_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/screens/chunk_card_goal_name_test.dart` — stubs for READ-01 (goal name as primary title)
- [ ] `test/screens/chunk_detail_sheet_test.dart` — stubs for READ-03 (sheet content + 3 action buttons)
- [ ] `test/providers/schedule_notifier_defer_test.dart` — stubs for READ-03 (markDeferred behavior)
- [ ] `test/screens/focus_screen_test.dart` — stubs for READ-04 (timer render + dispose)
- [ ] Extend `test/services/schedule_generator_test.dart` — new ordering/break cases (Tests 10–13 from RESEARCH.md)

*flutter_test framework already installed — no framework install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Tap-vs-swipe gesture arena on a real touch device (tap opens sheet without triggering Dismissible) | READ-03 | Gesture arena resolution differs between widget tests and physical touch input | On iOS device: tap a work chunk → sheet opens; horizontal drag → swipe complete/skip fires, sheet does NOT open |
| Focus countdown visual smoothness + break suggestion copy reads naturally | READ-04 | Subjective visual/animation quality not assertable in widget tests | On iOS device: start focus, run timer to completion, confirm completion action fires and break suggestion appears |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

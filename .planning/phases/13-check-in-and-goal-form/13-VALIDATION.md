---
phase: 13
slug: check-in-and-goal-form
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-13
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Flutter built-in, dev dependency in pubspec.yaml) |
| **Config file** | none — default flutter test runner |
| **Quick run command** | `/home/dan/development/flutter/bin/flutter test test/widget_test.dart` |
| **Full suite command** | `/home/dan/development/flutter/bin/flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/widget_test.dart`
- **After every plan wave:** Run full suite + `flutter analyze`
- **Before `/gsd-verify-work`:** Full suite must be green + `flutter analyze` clean
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 1 | CHECKIN-01 | — | N/A | unit | `flutter test test/screens/checkin_screen_test.dart` | ❌ W0 | ⬜ pending |
| 13-01-02 | 01 | 1 | CHECKIN-01 | — | N/A | manual | hover highlight on MouseRegion enter (pointer event) | ❌ W0 | ⬜ pending |
| 13-02-01 | 02 | 2 | CHECKIN-02 | — | N/A | widget | `flutter test test/screens/checkin_screen_widget_test.dart` | ❌ W0 | ⬜ pending |
| 13-02-02 | 02 | 2 | CHECKIN-02 | — | N/A | widget | `flutter test test/screens/checkin_screen_widget_test.dart` | ❌ W0 | ⬜ pending |
| 13-03-01 | 03 | 3 | GOALFORM-01 | — | N/A | widget | `flutter test test/widgets/goal_type_picker_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/screens/checkin_screen_test.dart` — unit test for `_onBgColor` luminance threshold (CHECKIN-01)
- [ ] `test/screens/checkin_screen_widget_test.dart` — widget tests for state machine transitions B→C→D→E and "Go back" D→B (CHECKIN-02)
- [ ] `test/widgets/goal_type_picker_test.dart` — layout height assertion for compact `_TypeCard` ≤64dp (GOALFORM-01)

*flutter_test is already installed. test/widget_test.dart is a stub placeholder. The three files above are new; no conftest/fixtures needed — use `WidgetTester.pumpWidget` with a `MaterialApp` wrapper and in-memory provider fakes.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Emoji target hover highlight on desktop/web | CHECKIN-01 | Pointer enter/exit events; flutter_test PointerEventRecord approach is feasible but complex/brittle | Run app on web/desktop, hover each mood emoji — confirm visible highlight, then move off to confirm it clears |
| Pressed state on mood options + confirm button | CHECKIN-01 | Visual press feedback best confirmed live | Press-and-hold each interactive element, confirm visible pressed state |
| Goal sheet fits viewport (Priority + Save reachable) | GOALFORM-01 | Final above-the-fold check depends on real device viewport + keyboard | Open add/edit goal sheet on a standard phone height — confirm Priority selector and Save are visible/tappable without in-sheet scroll |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

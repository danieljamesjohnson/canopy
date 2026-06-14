---
phase: 16
slug: priority-model-reconciliation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-13
---

# Phase 16 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (widget tests) |
| **Config file** | none — built into Flutter SDK |
| **Quick run command** | `flutter test test/screens/goal_form_priority_test.dart test/screens/goal_card_priority_chip_rebuild_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run the quick command for the touched test file(s)
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| _to be filled by planner_ | | | | widget | | | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/screens/goal_card_priority_chip_rebuild_test.dart` — NEW file for PRIORITY-03 (chip reflects fresh priorityWeight after drag/reorder rebuild)
- [ ] GOALFORM-02 modal-height tests added into existing `test/screens/goal_form_priority_test.dart` (replace the two `setSurfaceSize(800, 1200)` tests with true-modal-height `scrollUntilVisible` tests for time-target, outcome, habit)

*Existing helpers (`pumpWithMood`, `setViewport`) cover infrastructure; no new framework install.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Chip updates live in running app after drag and after selector change | PRIORITY-03 | Visual confirmation of rebuild on a real device | Drag a goal mid-list → chip reflects new band; change selector → list chip updates without re-open |
| Priority + Save reachable in real opened sheet | GOALFORM-02 | Real device modal height / safe-area behavior | Open goal sheet for an outcome goal, scroll, confirm Priority selector and Save are reachable |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

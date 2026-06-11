---
phase: 9
slug: an-engine-that-budgets
status: planned
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-11
---

# Phase 9 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Dart) |
| **Config file** | none — built into Flutter SDK (3.44.1) |
| **Quick run command** | `flutter test test/services/schedule_generator_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30–60 seconds |

Note: invoke Flutter via `/home/dan/development/flutter/bin/flutter` (not on shell PATH — see MEMORY.md).

---

## Sampling Rate

- **After every task commit:** Run the relevant unit test file (`flutter test test/<area>`)
- **After every plan wave:** Run `flutter test` (full suite)
- **Before `/gsd-verify-work`:** Full suite must be green + `flutter analyze` clean
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| P01-T1 | 09-01 | 1 | ENGINE-01..06 (Wave 0 scaffold) | T-09-01/03 | Defensive arithmetic test fixtures (logs, budgets) | unit | `flutter analyze lib/data/repositories/in_memory_completion_log_repository.dart test/services/schedule_generator_test.dart` | ❌ W0 (creates) | ⬜ pending |
| P01-T2 | 09-01 | 1 | ENGINE-01,02,03(sched),04,05(cap) | T-09-01/02/03/04 | daysLeft clamp, max(1,daysRemaining), floor-div spread, empty-goalId filter | unit | `flutter test test/services/schedule_generator_test.dart` | ✅ (extends) | ⬜ pending |
| P02-T1 | 09-02 | 1 | ENGINE-06 (UI) | T-09-06B | null priorityWeight → Normal (non-empty selection) | widget | `flutter test test/screens/goal_form_priority_test.dart` | ❌ (creates) | ⬜ pending |
| P02-T2 | 09-02 | 1 | ENGINE-06 (UI) | T-09-06A | fixed 3-value segment space | manual (human-verify) | on-device goal form render/persist | — | ⬜ pending |
| P03-T1 | 09-03 | 2 | ENGINE-03(streak),05(plumb) | T-09-07/08/09 | revert invariant on failed save; non-empty UUID guard; getByGoalId not getAll | unit | `flutter test test/providers/schedule_notifier_engine_test.dart` | ❌ W0 (creates) | ⬜ pending |
| P03-T2 | 09-03 | 2 | ENGINE-05 (visibility/plumb) | — | toggle visible all moods; value reaches generator | unit (full suite) | `flutter test` | ✅ (regression) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

Every ENGINE-01..06 requirement has at least one automated `<automated>` verify. The single manual verification (P02-T2) is the on-device render of the priority SegmentedButton — its scheduling-influence half is covered automatically by P01-T2 and P03-T1. No 3 consecutive tasks lack an automated verify.

---

## Wave 0 Requirements

- [ ] Add `lib/data/repositories/in_memory_completion_log_repository.dart` (shared test seam) — Plan 09-01 Task 1.
- [ ] Update the existing `schedule_generator_test.dart` `sut.generate(...)` call sites (17 sites) to pass `completionLogs: []` — Plan 09-01 Task 1 (mechanical signature fix).
- [ ] Add fixtures/builders `makeTimeTarget(...)` and `makeLog(...)` for `CompletionLog` history used by the budget and streak tests — Plan 09-01 Task 1.
- [ ] Add `test/providers/schedule_notifier_engine_test.dart` with an in-memory GoalRepository fake — Plan 09-03 Task 1.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Priority SegmentedButton renders/edits in the goal form on-device | ENGINE-06 | Widget visual confirmation on a real device/simulator | Open goal form, confirm Low/Normal/High control appears under name/type, selecting persists priorityWeight; reopen edit confirms persistence; legacy null goal shows Normal |

*All algorithmic behaviors (ENGINE-01..05 and the scheduling half of ENGINE-06) have automated unit coverage.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** planner-populated; pending execution

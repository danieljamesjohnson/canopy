---
phase: 9
slug: an-engine-that-budgets
status: draft
nyquist_compliant: false
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
| (planner fills) | — | — | ENGINE-01..06 | — / — | N/A | unit | `flutter test` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

> The planner populates this map per task. Each of ENGINE-01..06 maps to at least
> one pure-Dart unit test in `test/services/schedule_generator_test.dart` (engine
> behavior) or a notifier/widget test (streak write-back, lighter-day plumbing,
> priority control).

---

## Wave 0 Requirements

- [ ] Update the 13 existing `schedule_generator_test.dart` calls to pass the new
      `completionLogs: []` (and `lighterDay`) parameters — mechanical signature fix.
- [ ] Add fixtures/builders for `CompletionLog` history (per-goal, dated) used by
      the time-target "behind budget" and habit streak tests.

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Priority SegmentedButton renders/edits in the goal form on-device | ENGINE-06 | Widget visual confirmation on a real device/simulator | Open goal form, confirm Low/Normal/High control appears under name/type, selecting persists priorityWeight |

*All algorithmic behaviors (ENGINE-01..05 and the scheduling half of ENGINE-06) have automated unit coverage.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

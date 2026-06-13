---
phase: 5
slug: quarterly-review
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-06
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) |
| **Config file** | `pubspec.yaml` (dev_dependencies: flutter_test) |
| **Quick run command** | `flutter test test/services/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/services/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | — | — | N/A | unit | `flutter test test/services/quarterly_aggregation_test.dart` | ❌ W0 | ⬜ pending |
| 05-02-01 | 02 | 2 | — | — | N/A | widget | `flutter test test/screens/quarterly_review_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/services/quarterly_aggregation_test.dart` — stubs for aggregation service
- [ ] `test/screens/quarterly_review_test.dart` — stubs for review screen widgets

*Existing flutter_test infrastructure covers framework needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Donut chart renders with real data | AC-2 | fl_chart widget rendering requires visual inspection | Run app, trigger review, verify chart shows goal proportions |
| Bar chart renders weekly data | AC-2 | fl_chart visual verification | Run app, verify bar chart shows per-week breakdown |
| Full flow completable in <5 minutes | AC-3 | Timed human walkthrough | Start review, answer all questions, confirm priorities |
| Review banner appears in 90-day window | AC-1 | Date-dependent trigger | Set device date to within 7 days of window, verify banner |
| Drag reorder persists to next schedule | AC-4 | End-to-end flow | Reorder goals, generate next schedule, verify priority order |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

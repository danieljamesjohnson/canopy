---
phase: 12
slug: home-as-landing-schedule-as-plan
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-12
---

# Phase 12 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) |
| **Config file** | none — Flutter project, tests under `test/` |
| **Quick run command** | `flutter test test/<file>` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30–60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test` for the affected test file
- **After every plan wave:** Run `flutter test` (full suite) + `flutter analyze`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 12-01-xx | 01 | 1 | NAV-01, NAV-02 | — | N/A | widget | `flutter test test/router_redirect_test.dart` | ✅ | ⬜ pending |
| 12-02-xx | 02 | 1 | SCHED-01 | — | N/A | unit | `flutter test test/` (schema/migration + time format) | ✅ / ❌ W0 | ⬜ pending |
| 12-03-xx | 03 | 2 | SCHED-02, SCHED-03 | — | N/A | widget | `flutter test test/chunk_card_test.dart` | ✅ / ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*The planner will assign final task IDs and may split waves differently; the verification map above is the validation-architecture intent the plan must satisfy.*

---

## Wave 0 Requirements

- [ ] Update `test/router_redirect_test.dart` — onboarding/cold-start lands on `/home` (NAV-01)
- [ ] Rewrite `test/chunk_card_hover_test.dart` — assert always-visible Complete/Skip buttons, not hover opacity (SCHED-03)
- [ ] Add migration test for schema 6→7 no-op + `syntheticStartMinutes` persistence (SCHED-01)

*Existing flutter_test infrastructure covers the framework; no install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| "Now"/"Next" marker visually anchors to current time across the day | SCHED-02 | Time-of-day visual rendering is hard to assert deterministically across clock states | Launch app at different times of day; confirm Now marker sits before the first unresolved chunk and Next indicator follows |
| Complete/Skip buttons visible without hover on touch AND mouse | SCHED-03 | Cross-input-surface rendering is device-dependent | Run on desktop (mouse) and a touch surface; confirm buttons render without hover |

*Most phase behaviors have automated verification; the above require human visual confirmation.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

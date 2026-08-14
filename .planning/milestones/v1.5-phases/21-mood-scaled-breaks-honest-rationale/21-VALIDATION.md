---
phase: 21
slug: mood-scaled-breaks-honest-rationale
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-07
---

# Phase 21 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (bundled with the Flutter SDK, already a dev dependency) |
| **Config file** | none — standard `flutter test` convention |
| **Quick run command** | `export PATH="$PATH:/home/dan/development/flutter/bin"; flutter test test/services/schedule_generator_test.dart` |
| **Full suite command** | `export PATH="$PATH:/home/dan/development/flutter/bin"; flutter test` |
| **Estimated runtime** | ~1s quick / ~30s full |

---

## Sampling Rate

- **After every task commit:** Run the quick command (single file, <1s)
- **After every plan wave:** Run the full suite
- **Before `/gsd-verify-work`:** Full suite must be green **and** `grep -rn "behind this week" lib/` must return zero matches
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 21-01-* | 01 | 1 | BREAK-01 | — | N/A | unit | `flutter test test/services/schedule_generator_test.dart` | ❌ W0 (new tests) | ⬜ pending |
| 21-01-* | 01 | 1 | BREAK-02 | — | N/A | unit | `flutter test test/services/schedule_generator_test.dart` | ❌ W0 (new test) | ⬜ pending |
| 21-02-* | 02 | 1 | TONE-01 | — | N/A | unit + grep | `flutter test test/services/schedule_generator_test.dart` + `grep -rn "behind this week" lib/` | ❌ W0 (new test) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**Plan/task IDs are indicative** — the planner assigns final IDs. What is fixed is the requirement→command mapping above.

---

## Wave 0 Requirements

Every phase requirement currently has **zero** discriminating coverage — research empirically confirmed
that patching the cadence constant leaves all 54 existing tests green, so the existing suite does not
constrain this phase's behavior at all. These tests are the phase's real deliverable alongside the code:

- [ ] `test/services/schedule_generator_test.dart` — mood=1 cadence assertion (long break after 2 chunks) — BREAK-01
- [ ] `test/services/schedule_generator_test.dart` — mood=5 cadence assertion (long break after 5 chunks) — BREAK-01
- [ ] `test/services/schedule_generator_test.dart` — mood=2, mood=3, mood=4 cadence assertions (full mapping, incl. the untested mood=2) — BREAK-01
- [ ] `test/services/schedule_generator_test.dart` — structure-preserved assertion: only 5-min short breaks and 25-min long breaks ever appear — BREAK-02
- [ ] `test/services/schedule_generator_test.dart` — `_timeTargetRationale` new-string assertion — TONE-01
- [ ] No framework install needed — `flutter_test` already present
- [ ] No fixture gaps — existing `makeHabit`/`makeTimeTarget`/`makeOutcome`/`makeBlock`/`makeLog` helpers cover every shape the new tests need

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Rationale copy reads as help, not as a deficit report | TONE-01 | Tone is a judgment call; a unit test can pin the exact string but cannot confirm it *reads* right | Generate a schedule for a time-target goal that is under its weekly pace and read the rationale on the schedule surface. It must not imply the user has failed. |

A repo-wide `grep -rn "behind this week" lib/` returning zero matches is **automated**, not manual — it belongs in the phase gate above.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

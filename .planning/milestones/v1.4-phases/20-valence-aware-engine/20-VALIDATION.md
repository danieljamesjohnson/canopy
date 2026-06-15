---
phase: 20
slug: valence-aware-engine
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-14
---

# Phase 20 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: 20-RESEARCH.md "## Validation Architecture" (has exact Dart assertions). Planner fills the Per-Task Verification Map with real task IDs.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Flutter SDK) |
| **Config file** | none — Flutter SDK built-in |
| **Quick run command** | `flutter test test/services/schedule_generator_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30–60 seconds (full suite) |

Harness already complete in `test/services/schedule_generator_test.dart`: helpers `makeTimeTarget`, `makeHabit`, `makeOutcome`, `makeLog`, `monday` fixture. Wave 0 adds new `test()` blocks + an `energyValenceIndex`/`valence` param on the existing helpers — no new files.

---

## Sampling Rate

- **After every task commit:** `flutter test test/services/schedule_generator_test.dart`
- **After every plan wave:** `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

> Planner populates with real task IDs. Derived from research Validation Architecture (deterministic unit tests):

| Req | Behavior to verify | Test Type | Automated Command | File Exists | Status |
|-----|--------------------|-----------|-------------------|-------------|--------|
| VSCHED-01 | Low/stormy day + gives-valence time-target → goal appears alongside required+habits | unit | `flutter test test/services/schedule_generator_test.dart` | ❌ W0 | ⬜ pending |
| VSCHED-01 | Low/stormy day + gives-valence outcome (no deadline) → goal appears | unit | `flutter test test/services/schedule_generator_test.dart` | ❌ W0 | ⬜ pending |
| VSCHED-02 | Low day discretionary chunk count < medium day count for identical inputs (bounded) | unit | `flutter test test/services/schedule_generator_test.dart` | ❌ W0 | ⬜ pending |
| VSCHED-02 | A neutral/costs time-target does NOT get a restorative floor slot on a low day | unit | `flutter test test/services/schedule_generator_test.dart` | ❌ W0 | ⬜ pending |
| VSCHED-03 | High/sunny day under heavy backlog still reserves ≥1 energy-giving/high-priority slot | unit | `flutter test test/services/schedule_generator_test.dart` | ❌ W0 | ⬜ pending |
| VSCHED-03 | High day with no gives-valence time-targets → high-priority goal gets the reservation | unit | `flutter test test/services/schedule_generator_test.dart` | ❌ W0 | ⬜ pending |
| Determinism | Same inputs produce same schedule across two identical calls (SC-4) | unit | `flutter test test/services/schedule_generator_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Append VSCHED-01/02/03 + determinism `test()` blocks to `test/services/schedule_generator_test.dart` (RED-first)
- [ ] Add `valence`/`energyValenceIndex` param to existing `makeTimeTarget` / `makeOutcome` helpers (default neutral) so tests can set valence
- [ ] No new framework install; reuse existing harness

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| (none) | — | All Phase 20 behavior is deterministic engine logic with full unit coverage (SC-4 explicitly requires deterministic unit tests) | — |

*All phase behaviors have automated verification — this is a logic-only phase.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

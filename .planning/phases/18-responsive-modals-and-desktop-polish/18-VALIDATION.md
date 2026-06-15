---
phase: 18
slug: responsive-modals-and-desktop-polish
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-14
---

# Phase 18 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: 18-RESEARCH.md "## Validation Architecture". Planner fills the Per-Task Verification Map with real task IDs during planning.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Flutter SDK) |
| **Config file** | none — Flutter SDK built-in |
| **Quick run command** | `flutter test test/screens/adaptive_form_modal_test.dart test/screens/content_width_constraint_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30–60 seconds (full suite) |

Helpers available: `test/test_helpers/viewport.dart` (`setViewport(tester, size)`), `test/test_helpers/mood_pump.dart` (`pumpWithMood`). Pattern references: `test/screens/responsive_layout_test.dart`, `test/screens/goal_form_priority_test.dart`.

---

## Sampling Rate

- **After every task commit:** Run quick command (adaptive modal + content width tests)
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

> Planner populates this with real task IDs. Derived from research Validation Architecture:

| Req | Behavior to verify | Test Type | Automated Command | File Exists | Status |
|-----|--------------------|-----------|-------------------|-------------|--------|
| RESP-01 | At 720dp width, `showAdaptiveFormModal` opens a `Dialog` (not bottom sheet) | widget | `flutter test test/screens/adaptive_form_modal_test.dart` | ❌ W0 | ⬜ pending |
| RESP-01 | At 719dp width, `showAdaptiveFormModal` opens `ModalBottomSheet` (not dialog) | widget | `flutter test test/screens/adaptive_form_modal_test.dart` | ❌ W0 | ⬜ pending |
| RESP-02 | At 720dp, goal form dialog: drag handle absent, type picker + Priority + Save visible, no scroll | widget | `flutter test test/screens/adaptive_form_modal_test.dart` | ❌ W0 | ⬜ pending |
| RESP-02 | Dialog contains `ConstrainedBox` maxWidth 560 | widget | `flutter test test/screens/adaptive_form_modal_test.dart` | ❌ W0 | ⬜ pending |
| RESP-03 | CommitmentFormSheet caller routes through helper — Dialog at 720dp | widget | `flutter test test/screens/adaptive_form_modal_test.dart` | ❌ W0 | ⬜ pending |
| POLISH-01 | Goals screen body contains `ConstrainedBox` maxWidth 720 | widget | `flutter test test/screens/content_width_constraint_test.dart` | ❌ W0 | ⬜ pending |
| POLISH-01 | Home screen body contains `ConstrainedBox` maxWidth 720 | widget | `flutter test test/screens/content_width_constraint_test.dart` | ❌ W0 | ⬜ pending |
| POLISH-02 | Goal form copy: "Add Goal", "Save Goal", "Discard", "Archive goal" | widget | `flutter test test/screens/goal_form_copy_test.dart` | ❌ W0 | ⬜ pending |
| POLISH-02 | Commitment delete copy: "Delete commitment", "Keep commitment" | widget | `flutter test test/screens/goal_form_copy_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/screens/adaptive_form_modal_test.dart` — stubs for RESP-01/02/03
- [ ] `test/screens/content_width_constraint_test.dart` — stubs for POLISH-01
- [ ] `test/screens/goal_form_copy_test.dart` — stubs for POLISH-02
- [ ] Reuse existing `test/test_helpers/viewport.dart` and `mood_pump.dart` (no new framework install)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Desktop walkthrough surfacing high-friction UI nits | POLISH-02 | Subjective visual triage; no automated proxy | Build single-bundle debug web build per CLAUDE.md, open at desktop width, walk home → schedule → goals → check-in + modals, note clipping/cramping/full-bleed nits |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

---
phase: 14
slug: goals-screen-and-priority-end-to-end
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-13
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK-bundled) |
| **Config file** | none — flutter test auto-discovers `test/` |
| **Quick run command** | `/home/dan/development/flutter/bin/flutter test test/services/schedule_generator_test.dart` |
| **Full suite command** | `/home/dan/development/flutter/bin/flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run the task's targeted test file
- **After every plan wave:** Run full suite + `flutter analyze`
- **Before `/gsd-verify-work`:** Full suite green + `flutter analyze` clean
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 14-goals-heading | goals UI | 1 | GOALS-01 | — | N/A | widget | `flutter test test/screens/goals_screen_heading_test.dart` | ❌ W0 | ⬜ pending |
| 14-drag-handle | goals UI | 1 | GOALS-01 | — | N/A | widget | `flutter test test/screens/goal_card_drag_handle_test.dart` | ✅ UPDATE | ⬜ pending |
| 14-goal-chip | goals UI | 1 | GOALS-02 | — | N/A | widget | `flutter test test/screens/goal_card_priority_chip_test.dart` | ❌ W0 | ⬜ pending |
| 14-chunk-badge | sched cards | 2 | GOALS-02 | — | N/A | widget | `flutter test test/screens/chunk_card_priority_badge_test.dart` | ❌ W0 | ⬜ pending |
| 14-engine-priority | engine | 2 | PRIORITY-01 | — | N/A | unit | `flutter test test/services/schedule_generator_test.dart` | ✅ ADD | ⬜ pending |

---

## Wave 0 Requirements

- [ ] `test/screens/goals_screen_heading_test.dart` — heading "Your goals" + subhead visible (GOALS-01)
- [ ] `test/screens/goal_card_priority_chip_test.dart` — High chip @0.75, no chip @0.5, Low chip @0.25 (GOALS-02)
- [ ] `test/screens/chunk_card_priority_badge_test.dart` — High/Low badge by goalPriorityWeight, none when null (GOALS-02)
- [ ] UPDATE `test/screens/goal_card_drag_handle_test.dart` — Icons.drag_indicator on desktop AND mobile (was hidden) (GOALS-01)
- [ ] ADD cases to `test/services/schedule_generator_test.dart` — habit priority sort; time-target composite score; elevate→more/earlier, lower→fewer/later (PRIORITY-01, criteria 3 & 4)

*flutter_test is installed. Existing test helpers (mood_pump, viewport, makeHabit/makeGoal factories in schedule_generator_test.dart) are reused.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Priority visual language reads as clearly distinct (High/Normal/Low) across Goals list AND schedule cards | GOALS-02 | Final "is it unambiguous at a glance" judgment is visual | Run app, set goals to Low/Normal/High, view Goals screen and Home schedule cards — confirm the three tiers are unmistakable and consistent between the two surfaces |
| Drag-to-reorder affordance is obvious | GOALS-01 | Affordance obviousness is a perception judgment | Run app on desktop and phone — confirm the drag handle reads as draggable (not an ambiguous two-slash) |
| End-to-end priority → schedule change is observable | PRIORITY-01 | User-facing observability of the regeneration effect | Run app: elevate a goal low→high, regenerate, confirm visibly more/earlier chunks; lower high→low, regenerate, confirm fewer/later |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

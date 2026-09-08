---
phase: 34
slug: adding-a-goal-feels-like-onboarding
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-08
---

# Phase 34 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (bundled with Flutter SDK) |
| **Config file** | none — `test/` directory convention; `analysis_options.yaml` for lints |
| **Quick run command** | `flutter test test/screens/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~60–90 seconds full suite (706 tests green as of Phase 33) |

**PATH note for agents:** `flutter` is at `/home/dan/development/flutter/bin` and is NOT on the
default non-login-shell PATH. Export it before running any command above.

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/screens/` plus `flutter analyze`
- **After every plan wave:** Run `flutter test` (full suite)
- **Before `/gsd-verify-work`:** Full suite green AND `flutter analyze` clean
- **Max feedback latency:** ~90 seconds

---

## Per-Task Verification Map

Task IDs are filled in by the planner; the rows below fix the *requirement→proof* mapping the plan
must satisfy, which is the part that must not drift.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 34-01-* | 01 | 1 | GOALADD-01 | — | N/A | widget | `flutter test test/screens/goals/` | ❌ W0 | ⬜ pending |
| 34-01-* | 01 | 1 | GOALADD-02 | — | N/A | widget | `flutter test test/screens/goals/` | ❌ W0 | ⬜ pending |
| 34-01-* | 01 | 1 | GOALADD-03 | — | N/A | widget | `flutter test test/screens/goals/` | ❌ W0 | ⬜ pending |
| 34-0*-* | * | * | regression (existing suites) | — | N/A | widget | `flutter test` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## The assertions that must discriminate — this project's specific failure mode

**Read CLAUDE.md's "Assertions that cannot fail" before writing any test for this phase.** Canopy's
green suites have been contradicted by the owner's own eyes six times (Phases 27, 29, 31, 32×2, 33).
The cause has never been a missing test; it has been a test that passes for a reason unrelated to
the defect. Three concrete traps bind here:

1. **GOALADD-03's test must assert on RENDERED TEXT, never on the constant.**
   `expect(goal.weeklyHourBudget, 3.0)` is symbolic — it is derived from the same constant the code
   sets, so it moves with the constant and **cannot fail**. The requirement is that the number is
   *visible*, so the assertion must be `find.text('3.0 hrs/week')` (or a `textContaining` on the
   rendered row). This is the single most important line in this document.

2. **`find.byType(X)` does not match subclasses.** It compares `runtimeType` exactly. Any assertion
   about the shared preset chip must use `find.byWidgetPredicate((w) => w is <Base>)` if "any chip
   subtype" is meant — a `FilterChip`/`ActionChip`/`InputChip` swap would otherwise silently pass.
   The research found the two source widgets use *different* chip families, so this is live, not
   theoretical.

3. **Mutation-test the load-bearing assertion.** For each of GOALADD-01/02/03, introduce the defect
   deliberately, watch the test go RED, then revert. A compile error is a weak form of red — it
   proves the API is missing, not that the assertion discriminates. Record in the SUMMARY that this
   was done and what the failing output was.

---

## Wave 0 Requirements

- [ ] `test/screens/goals/goal_preset_picker_test.dart` — new file; stubs for GOALADD-01/02/03
- [ ] Update `test/screens/goals_add_fork_test.dart` — lines 163–172 and 260–278 assert
      `GoalFormSheet` appears immediately after the goal door; they will fail by design once the
      door opens the preset sheet. **Update, do not delete** — the "exactly one add path, at the
      top" assertion in that file is load-bearing and must survive.
- [ ] Update `test/screens/onboarding_flow_test.dart` — lines 166 and 467 use
      `find.widgetWithText(ActionChip, 'Reading')` and break when onboarding adopts the shared chip.
      **Found by the researcher, not flagged in the UI-SPEC** — do not let it surface as a surprise
      red at execute time.
- [ ] No framework install needed — `flutter_test` is already the project's suite.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| "Adding a goal feels like onboarding" | GOALADD-01 | It is a judgment about *feel*, and feel is exactly what six green suites have failed to capture in this project. No widget test can answer it. | Serve the debug build on port 8143 (kill any stale server first and verify it died), open the Goals screen, tap **Add goal → Something to make time for**, and judge whether the sheet reads like onboarding's guided start. |
| Preset chips are hittable with a thumb | GOALADD-01 | Touch-target adequacy needs a real thumb on a real phone — Phase 31 met the platform minimum twice with an invisible target and failed a thumb both times. | On a phone, tap five different preset chips in a row. Report how many landed first try (n/5), not "it seems to work". |
| The budget on the created row is *noticed*, not merely present | GOALADD-03 | A widget test proves the string renders. It cannot prove a human reads it before the scheduler acts on it — which is the actual defect being guarded against. | After creating a goal from a chip, without prompting, ask: what weekly commitment did you just make? If the answer is "I don't know", the mitigation failed even though the test is green. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (including the two pre-existing test files above)
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] **Each of GOALADD-01/02/03's load-bearing assertion was mutation-tested and observed RED**
- [ ] `nyquist_compliant: true` set in frontmatter

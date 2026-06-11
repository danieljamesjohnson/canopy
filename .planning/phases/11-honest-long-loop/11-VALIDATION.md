---
phase: 11
slug: honest-long-loop
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-11
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Flutter SDK built-in) |
| **Config file** | none — provided by Flutter SDK |
| **Quick run command** | `flutter test test/services/quarterly_aggregation_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30–90 seconds (full suite) |

---

## Sampling Rate

- **After every task commit:** Run the targeted test file(s) for the changed unit (e.g. `flutter test test/services/...`)
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green + `flutter analyze` clean
- **Max feedback latency:** ~90 seconds

---

## Per-Task Verification Map

> Filled out concretely by the planner per PLAN task. Below is the required coverage skeleton — every REVIEW requirement must map to at least one automated test.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 11-XX-XX | XX | 1 | REVIEW-01 | — | Donut/totals count commitment + archived chunks; percentages sum to 100% with a catch-all "Other" — no invisible slice | unit | `flutter test test/services/quarterly_aggregation_test.dart` | ✅ | ⬜ pending |
| 11-XX-XX | XX | 1 | REVIEW-01 | — | DonutChart renders a slice for every aggregated category (active/archived/commitment/other) so drawn slice values sum to the same total used for percentages | widget | `flutter test test/screens/quarterly_review_test.dart` | ✅ | ⬜ pending |
| 11-XX-XX | XX | 2 | REVIEW-02 | — | Changing a goal's review priority writes priorityWeight (monotonic linear spread) so the next generated schedule orders that goal measurably differently | unit | `flutter test test/services/schedule_generator_test.dart` | ✅ | ⬜ pending |
| 11-XX-XX | XX | 2 | REVIEW-02 | — | reorderAllWithPriority on GoalsNotifier persists distinct, ordered priorityWeights to the repo | unit | `flutter test test/providers/` | ✅ | ⬜ pending |
| 11-XX-XX | XX | 1 | REVIEW-03 | — | Cold launch: review opened without visiting other tabs loads goal list + chart data (active + archived goals + commitments); empty-state guard keyed on logs/snapshots not provider goal list | widget | `flutter test test/screens/quarterly_review_test.dart` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- Existing infrastructure covers all phase requirements. `flutter_test` is provided by the SDK; the relevant test files already exist and provide templates:
  - `test/services/quarterly_aggregation_test.dart`
  - `test/screens/quarterly_review_test.dart`
  - `test/services/schedule_generator_test.dart`
  - `test/screens/cold_launch_morning_loop_test.dart`
  - `test/test_helpers/` (in-memory repos / pump helpers)
- No framework install needed. New tests are additions to the files above.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Donut visual: no invisible slice, legend percentages read 100% on a real device with mixed goal/commitment/archived history | REVIEW-01 | Visual gestalt (slice rendering, legend legibility) is not fully assertable in widget tests | Load dev data with archived goals + commitment blocks, open the review, confirm legend percentages sum to 100% and every counted category appears |
| Drag-to-reorder feel and that tomorrow's schedule visibly reflects the new order | REVIEW-02 | End-to-end day-boundary behavior crosses generation cycles | Reorder a low goal to top, finish review, regenerate next morning, confirm its chunks move earlier/increase |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

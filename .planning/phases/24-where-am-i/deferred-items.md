# Phase 24 — Deferred Items

Out-of-scope discoveries logged during execution, per the executor's Scope Boundary rule
(only auto-fix issues directly caused by the current task's changes).

## dart format debt in 3 unrelated files (found during 24-02 Task 3)

`dart format --output=none --set-exit-if-changed lib/` reports 3 files that would be
reformatted, none of which this phase (or 24-01) touched:

- `lib/screens/commitments/commitment_form_sheet.dart` (last touched `b6fbc54`, Phase
  "onboarding" fix, 2026-07-03)
- `lib/screens/onboarding/onboarding_screen.dart` (last touched `8b8a7e1`, Phase 23-08,
  2026-08-08)
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart` (last touched `7eb960d`,
  Phase 22, 2026-08-07)

This is pre-existing formatting drift from earlier phases (likely a `dart format` SDK
version mismatch between when those files were last edited and the toolchain used to
verify them now), not something introduced by Phase 24. Per 24-02-PLAN.md Task 3's own
instruction ("Do not reformat files this phase did not touch"), these were left
unformatted rather than swept into this phase's diff. `24-02-SUMMARY.md`'s Deviations
section documents this as an accepted gap against the plan's `dart format --output=none
--set-exit-if-changed lib/` exits-0 acceptance criterion.

**Not fixed here.** Revisit in a dedicated formatting-hygiene pass, not folded into a
feature phase's diff.

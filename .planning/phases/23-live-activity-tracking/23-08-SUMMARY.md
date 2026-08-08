---
phase: 23-live-activity-tracking
plan: 08
subsystem: ui
tags: [flutter, onboarding, goal-form, checkin, energy-valence, copy]

# Dependency graph
requires:
  - phase: 23-live-activity-tracking (23-04, 23-UAT.md sign-off gate)
    provides: G-01 and G-07 gap reports plus Dan's "flip both surfaces" decision
provides:
  - Both energy-valence segmented controls (onboarding beat 3, goal form) ordered Drains -> Neutral -> Lifts
  - Positional tests pinning that order on both surfaces (previously only find-by-text, order-blind)
  - A per-mood consequence line in check-in, shown before commit, stating real chunk-cap and long-break cadence numbers
  - Deletion of the unreferenced, already-drifted acknowledgment_screen.dart duplicate
affects: [onboarding, goals, checkin]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - lib/screens/onboarding/onboarding_screen.dart
    - lib/screens/goals/goal_form_sheet.dart
    - lib/screens/schedule/checkin_screen.dart
    - test/screens/onboarding_flow_test.dart
    - test/screens/goal_form_valence_test.dart
    - test/screens/checkin_screen_widget_test.dart
  deleted:
    - lib/screens/schedule/acknowledgment_screen.dart

key-decisions:
  - "G-01: flipped both onboarding_screen.dart's and goal_form_sheet.dart's segmented-button order (costs/neutral/gives), per Dan's explicit sign-off decision to keep the two surfaces agreeing on which end means drains"
  - "G-07: placed the mood consequence line in _buildCheckinBody (pre-commit, above 'Let's go'), not in the acknowledgment text as 23-GAP-ANALYSIS.md originally suggested — check-in is a two-step flow and Dan wants to compare moods before committing"
  - "Deleted acknowledgment_screen.dart as dead code after confirming zero references outside its own file (grep -rn before and after)"

requirements-completed: [G-01, G-07]

# Metrics
duration: ~10min
completed: 2026-08-08
---

# Phase 23 Plan 08: Gap Closure — Valence Order Flip & Day-Type Consequence Copy Summary

**Flipped both energy-valence segmented controls to Drains-left/Lifts-right and added a pre-commit,
generator-accurate consequence sentence to check-in, deleting the dead acknowledgment-screen duplicate
that risked drifting out of sync.**

## Performance

- **Duration:** ~10 min
- **Completed:** 2026-08-08
- **Tasks:** 2/2 completed
- **Files modified:** 5 (+1 deleted)

## Accomplishments

- G-01 closed: onboarding beat 3 and the goal form's `_EnergyRow` segmented controls both now read
  `Drains -> Neutral -> Lifts`, left to right, with a source comment naming G-01 so a future tidy-up
  doesn't "restore" positive-first ordering.
- Added the first order-sensitive tests on either control (`tester.getTopLeft(...).dx` comparisons) —
  previously every assertion found by text, which is blind to order.
- G-07 closed: check-in now states, before the user taps "Let's go," exactly how many discretionary
  goal chunks that mood has room for and how often a long break lands — sourced from and doc-bound to
  `ScheduleGeneratorService._moodCap` / `_moodBreakCadence`.
- Deleted `lib/screens/schedule/acknowledgment_screen.dart` — confirmed unreferenced before deleting,
  removing a duplicate that had already silently drifted from the live copy.

## Task Commits

1. **Task 1: Flip both energy-valence controls to Drains -> Neutral -> Lifts** - `8b8a7e1` (fix)
2. **Task 2: Say what a day type means, in the generator's real numbers, and delete the dead duplicate** - `f4ab870` (feat)

**Plan metadata:** pending (this commit)

## Files Created/Modified

- `lib/screens/onboarding/onboarding_screen.dart` - `_EnergyRow` segments reordered `costs, neutral, gives`; comment naming G-01 added
- `lib/screens/goals/goal_form_sheet.dart` - Same reorder in the goal-form's analogous control
- `lib/screens/schedule/checkin_screen.dart` - Added `_moodConsequence` table + doc comment; rendered in `_buildCheckinBody` above the "Let's go" button
- `test/screens/onboarding_flow_test.dart` - Added a positional (`dx`) assertion for Drains-left/Lifts-right in beat 3
- `test/screens/goal_form_valence_test.dart` - Added the analogous positional assertion for Costs energy/Gives energy
- `test/screens/checkin_screen_widget_test.dart` - New widget test: mood-3 consequence renders, then mood-1 replaces it (proves per-mood, not static)
- `lib/screens/schedule/acknowledgment_screen.dart` - Deleted (unreferenced dead code)

## `_moodConsequence` <-> generator table cross-check (verification requirement)

Read directly from `lib/services/schedule_generator.dart` at implementation time:

```
static const Map<int, int> _moodCap = {1: 4, 2: 6, 3: 8, 4: 9, 5: 11};
static const Map<int, int> _moodBreakCadence = {1: 2, 2: 3, 3: 4, 4: 4, 5: 5};
```

Paired against the five copy strings added to `checkin_screen.dart`:

| Mood | `_moodCap` | `_moodBreakCadence` | Copy string |
|---|---|---|---|
| 1 | 4 | 2 | "Room for 4 chunks from your goals, with a long break after every 2." |
| 2 | 6 | 3 | "Room for 6 chunks from your goals, with a long break after every 3." |
| 3 | 8 | 4 | "Room for 8 chunks from your goals, with a long break after every 4." |
| 4 | 9 | 4 | "Room for 9 chunks from your goals, with a long break after every 4." |
| 5 | 11 | 5 | "Room for 11 chunks from your goals, with a long break after every 5." |

All five pairs match exactly — the tables had not changed since the gap analysis. The generator's
packing pass (`_assignSyntheticStartTimes`, lines ~731-750) confirms the cap counts discretionary
chunks only (commitment-anchored chunks are placed separately and not counted against it), and
check-in always calls `generateToday(lighterDay: false)`, so the raw (non-reduced) cap is the number
shown.

## Placement Decision (deviates from 23-GAP-ANALYSIS.md)

23-GAP-ANALYSIS.md's initial suggestion was to append the explanation to `_buildAckText`, assuming
the acknowledgment moment is "right after picking a mood." The plan (23-08-PLAN.md) corrected this:
check-in is a two-step flow — tapping an emoji sets `_selectedMood` and reveals a "Let's go" button;
the acknowledgment only renders *after* generation completes. Dan's ask was that choosing a day type
tell him what it means, which is a pre-commit concern, not a post-hoc one — and putting it in
`_buildCheckinBody` lets him tap between moods and compare before committing to one. The line was
added inside the existing `if (_selectedMood != null)` block, above the "Let's go" button; `_buildAckText`
and `_moodPrefix` were left untouched (`git diff` on Task 2's commit shows only additive hunks — no
edits inside either).

## Decisions Made

- Flip both surfaces (G-01) — Dan's explicit sign-off decision, not a unilateral call.
- Pre-commit placement for the consequence line (G-07) — deviation from the gap analysis's suggested
  placement, justified above and flagged per plan instructions.
- Delete `acknowledgment_screen.dart` rather than update it in lockstep — it was unreferenced
  (`grep -rn "acknowledgment_screen\|AcknowledgmentScreen" lib/ test/` returned only the file's own
  definition, both before and after deletion), and a second copy of the same strings is exactly the
  kind of surface that drifts silently, which is what the plan explicitly wanted eliminated.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking / scope hygiene] Reverted unrelated `dart format` drift on files outside each task's scope**
- **Found during:** Task 2's verify step (the plan's own verify command runs `dart format` across
  all six touched files, including two files — `onboarding_screen.dart`,
  `test/screens/onboarding_flow_test.dart`, `test/screens/goal_form_valence_test.dart` — already
  committed in Task 1)
- **Issue:** The installed `dart format` produces different (but equally valid) line-wrapping than
  whatever formatted these files previously — exactly the "dart format has version drift" warning in
  this project's `CLAUDE.md`. Re-running it reformatted unrelated lines (e.g. a list-comprehension
  wrap in `onboarding_screen.dart`, several `testWidgets(...)` call-site wraps in the test files) with
  no functional change.
- **Fix:** `git checkout --` on the three files to discard the drift-only reformatting before staging
  Task 2's commit, keeping each commit's diff scoped to what that task actually changed.
- **Files affected:** `lib/screens/onboarding/onboarding_screen.dart`,
  `test/screens/onboarding_flow_test.dart`, `test/screens/goal_form_valence_test.dart` (none
  ultimately modified beyond Task 1's commit)
- **Verification:** `flutter test` (474 tests) and `flutter analyze` (clean) re-run after the
  revert — both still pass.

**Total deviations:** 1 auto-fixed (scope hygiene, no functional change).
**Impact on plan:** None — Task 2's commit ended up scoped to exactly `checkin_screen.dart`,
`checkin_screen_widget_test.dart`, and the deletion of `acknowledgment_screen.dart`, matching its
`<files>` declaration precisely.

## Flag for Dan (per plan's execution_notes, not fixed in this plan)

The two valence controls still use different wording even though their order now agrees: onboarding
says "Lifts"/"Drains", the goal form says "Gives energy"/"Costs energy". This mismatch pre-dates G-01
and is out of scope here — noted since this control family was just touched and Dan is looking at it.

## Issues Encountered

None beyond the format-drift deviation documented above.

## Verification

- `flutter test` — 474 tests, 0 failures (baseline was 473; +1 new test in
  `checkin_screen_widget_test.dart`).
- `flutter analyze` — "No issues found!"
- `grep -rn "acknowledgment_screen\|AcknowledgmentScreen" lib/ test/` — no output (file fully removed).
- `git diff --name-only` (Task 2's commit) — `lib/screens/schedule/checkin_screen.dart`,
  `test/screens/checkin_screen_widget_test.dart`, and the deletion of
  `lib/screens/schedule/acknowledgment_screen.dart` only; `pubspec.yaml`/`pubspec.lock` not touched.

## Next Phase Readiness

G-01 and G-07 are closed. Remaining open gaps from 23-UAT.md (G-02, G-03, G-04, G-05, G-06) are
tracked separately — G-05 was closed in 23-06; G-02/G-04/G-06 remain open per the gap analysis's
ranked list, not in scope for this plan.

## Self-Check: PASSED

- Files verified present: `lib/screens/onboarding/onboarding_screen.dart`,
  `lib/screens/goals/goal_form_sheet.dart`, `lib/screens/schedule/checkin_screen.dart`,
  `test/screens/onboarding_flow_test.dart`, `test/screens/goal_form_valence_test.dart`,
  `test/screens/checkin_screen_widget_test.dart`.
- File verified deleted: `lib/screens/schedule/acknowledgment_screen.dart`.
- Commits verified in `git log`: `8b8a7e1`, `f4ab870`.

---
*Phase: 23-live-activity-tracking*
*Plan: 08*
*Completed: 2026-08-08*

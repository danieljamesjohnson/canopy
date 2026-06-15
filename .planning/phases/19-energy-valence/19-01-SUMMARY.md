---
phase: 19-energy-valence
plan: "01"
subsystem: testing
tags: [flutter, hive, energy-valence, tdd, red-tests, migration]

# Dependency graph
requires:
  - phase: 18-responsive-modals-and-desktop-polish
    provides: GoalFormSheet adaptive modal, goal_card priority chip pattern, chunk_card priority badge pattern
provides:
  - Five RED test stubs for Phase 19 EnergyValence feature (behavioral contract locked before implementation)
  - migration_schema8_test: schema-version==8, neutral-default, round-trip incl. emoji (ENERGY-01a/b/c, ENERGY-03a)
  - goal_form_valence_test: Energy SegmentedButton picker contract (ENERGY-02)
  - goal_card_valence_test: _ValenceBadge (Gives/Costs/neutral) + emoji in title row (ENERGY-03b, ENERGY-04a)
  - chunk_card_valence_test: _ValenceChip + goalEmojiTag prefix on ChunkCard (ENERGY-04b)
  - onboarding_screen4_test: Screen 4 complete/skip contract (ONBOARD-01)
affects:
  - 19-02-wave1-model-migration (implements the symbols the RED tests reference)
  - 19-03-wave2-ui (implements GoalCard, ChunkCard, GoalFormSheet changes)
  - 19-04-wave3-onboarding (implements Screen 4)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "temp-dir Hive.init round-trip test pattern (from migration_schema7_test.dart)"
    - "_InMemoryGoalRepository inline stub in widget tests (from goal_form_priority_test.dart)"
    - "pumpWithMood + extraProviders pattern for all widget test scaffolding"

key-files:
  created:
    - test/data/migration_schema8_test.dart
    - test/screens/goal_form_valence_test.dart
    - test/screens/goal_card_valence_test.dart
    - test/screens/chunk_card_valence_test.dart
    - test/screens/onboarding_screen4_test.dart
  modified: []

key-decisions:
  - "All five test stubs fail RED due to missing energy_valence.dart import (no such file), not due to test-authoring bugs"
  - "onboarding_screen4_test.dart uses _InMemoryCommitmentBlockRepository + _FakeSettingsNotifier to avoid Hive I/O"
  - "migration_schema8_test.dart follows migration_schema7_test.dart temp-dir pattern exactly (GoalAdapter typeId 0)"

patterns-established:
  - "Wave 0 RED stubs: import energy_valence.dart (missing file) drives compile failure across all 5 files"
  - "Onboarding test: _FakeSettingsNotifier overrides setOnboardingComplete + init() to avoid Hive"

requirements-completed: [ENERGY-01, ENERGY-02, ENERGY-03, ENERGY-04, ONBOARD-01]

# Metrics
duration: 6min
completed: 2026-06-15
---

# Phase 19 Plan 01: Wave 0 Test Stubs Summary

**Five RED TDD test stubs locking the EnergyValence + emoji behavioral contract before any implementation begins: migration safety (neutral default), Hive round-trip (fields 12+13), goal form picker, goal card badge/emoji, chunk card chip/emoji, and onboarding Screen 4 completion**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-06-15T02:15:07Z
- **Completed:** 2026-06-15T02:20:34Z
- **Tasks:** 2
- **Files modified:** 5 (all new test files)

## Accomplishments

- Created `test/data/migration_schema8_test.dart` — 3 test cases (currentSchemaVersion==8, old-record neutral-default, round-trip incl. emoji). Fails RED because `lib/data/models/energy_valence.dart` does not exist yet and `Goal.energyValenceIndex`/`Goal.emojiTag`/`Goal.energyValence` are undefined.
- Created `test/screens/goal_form_valence_test.dart` — 5 tests asserting "Energy" label, SegmentedButton<EnergyValence> segments, Neutral default, gives-pre-selection on edit, and Save persists valence. Fails RED on the same undefined symbols.
- Created `test/screens/goal_card_valence_test.dart` — 7 tests asserting _ValenceBadge (Gives/bolt, Costs/hourglass, absent for neutral), emoji in title row, and combined emoji+badge. Fails RED on undefined EnergyValence + Goal fields.
- Created `test/screens/chunk_card_valence_test.dart` — 7 tests asserting `goalValence`/`goalEmojiTag` constructor params on ChunkCard. Fails RED because those params don't exist yet.
- Created `test/screens/onboarding_screen4_test.dart` — 3 tests asserting Screen 4 headline, marking a goal energizing + completing sets energyValence=gives, and skip leaves goals neutral. Fails RED on EnergyValence + Goal.energyValence + Screen 4 not existing.
- Confirmed 0 production `lib/` files modified by this plan.
- Confirmed pre-existing test suite remains 257 passing (the 5 new files fail RED as expected).

## Task Commits

1. **Task 1: Migration-safety + round-trip test** - `0b86d6d` (test)
2. **Task 2: Widget test stubs (goal form, goal card, chunk card, onboarding)** - `eec1fd9` (test)

**Plan metadata:** (see final commit below)

## Files Created/Modified

- `test/data/migration_schema8_test.dart` — Schema version==8 + old-record neutral-default + fields 12+13 round-trip
- `test/screens/goal_form_valence_test.dart` — Energy SegmentedButton picker in GoalFormSheet
- `test/screens/goal_card_valence_test.dart` — _ValenceBadge + emoji on GoalCard
- `test/screens/chunk_card_valence_test.dart` — _ValenceChip + emoji prefix on ChunkCard
- `test/screens/onboarding_screen4_test.dart` — Onboarding Screen 4 headline/marking/skip

## Decisions Made

- `_InMemoryCommitmentBlockRepository` implements all 5 `CommitmentBlockRepository` interface methods (getAll, getById, save, delete, getByDayOfWeek using `daysOfWeek.contains(day)`) to satisfy the Dart abstract class constraint — deviation Rule 3, discovered during compilation, fixed inline.
- All five test files import `package:canopy/data/models/energy_valence.dart` as the primary RED driver (missing file error). This is the cleanest single-import RED gate that cascades to all EnergyValence-related symbol errors in each file.
- `onboarding_screen4_test.dart` pumps `OnboardingScreen` (not `_Screen4` directly — file-private) and navigates through Screens 1-3 via Skip taps to reach Screen 4. This tests the full navigation path, not just Screen 4 in isolation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed missing interface methods in _InMemoryCommitmentBlockRepository**
- **Found during:** Task 2 (onboarding_screen4_test.dart)
- **Issue:** `CommitmentBlockRepository` abstract class has 5 methods; initial stub only implemented 3 (missing `getById` and `getByDayOfWeek`). Dart requires all abstract methods to be implemented.
- **Fix:** Added `getById` (returns firstOrNull by id) and `getByDayOfWeek` (filters by `daysOfWeek.contains(day)` — note: field is `daysOfWeek`, not `dayOfWeek` as I initially wrote).
- **Files modified:** test/screens/onboarding_screen4_test.dart
- **Verification:** File now fails only on missing EnergyValence symbols (correct RED), not on missing interface implementations.
- **Committed in:** `eec1fd9` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 3 - blocking interface implementation)
**Impact on plan:** Minor fix; no scope change. All five files now fail RED for exactly the right reasons.

## Issues Encountered

None beyond the Rule 3 auto-fix above.

## Known Stubs

None — this plan creates test stubs intentionally. The test files themselves are the stubs; they are not production code and are expected to remain RED until Plans 02-04 implement the production symbols.

## Threat Flags

None — this plan creates test-only files with no runtime trust boundaries.

## Next Phase Readiness

- All five RED test stubs are on disk with correct content
- Implementation plans (19-02 through 19-04) can now proceed knowing the behavioral contract is locked
- The highest-risk path (migration safety) is pinned first: `migration_schema8_test.dart` asserts neutral-default for old records before the migration is written

## Self-Check: PASSED

- FOUND: test/data/migration_schema8_test.dart
- FOUND: test/screens/goal_form_valence_test.dart
- FOUND: test/screens/goal_card_valence_test.dart
- FOUND: test/screens/chunk_card_valence_test.dart
- FOUND: test/screens/onboarding_screen4_test.dart
- FOUND: commit 0b86d6d (Task 1 — migration test)
- FOUND: commit eec1fd9 (Task 2 — widget test stubs)

---

*Phase: 19-energy-valence*
*Completed: 2026-06-15*

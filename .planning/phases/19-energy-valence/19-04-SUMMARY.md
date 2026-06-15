---
phase: 19-energy-valence
plan: 04
subsystem: ui-cards
tags: [flutter, widget, valence, emoji, goal-card, chunk-card, schedule]

# Dependency graph
requires:
  - phase: 19-02
    provides: EnergyValence enum, Goal.energyValence getter, Goal.emojiTag field
provides:
  - _ValenceBadge file-private widget in goal_card.dart (ENERGY-04a)
  - Emoji tag rendering in GoalCard title row (ENERGY-03b)
  - _ValenceChip file-private widget in chunk_card.dart (ENERGY-04b)
  - goalEmojiTag + goalValence params on ChunkCard and SwipeableChunkCard
  - _lookupGoalValence + _lookupGoalEmojiTag helpers in schedule_screen.dart
  - goal_card_valence_test.dart GREEN (7/7)
  - chunk_card_valence_test.dart GREEN (7/7)
affects: [19-05-onboarding, 19-06-integration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "File-private badge widget duplication: _ValenceBadge (goal_card) + _ValenceChip (chunk_card) are intentional visual duplicates; do NOT extract to shared widget"
    - "Emoji inline in title: string interpolation '$emoji $name' in a single Text widget (chunk card) vs separate Text widget after type icon (goal card)"
    - "Valence lookup helper: null-guard chunk.goalId first; goal?.energyValence / goal?.emojiTag for commitment-chunk safety"

key-files:
  modified:
    - lib/screens/goals/widgets/goal_card.dart
    - lib/screens/schedule/widgets/chunk_card.dart
    - lib/screens/schedule/widgets/swipeable_chunk_card.dart
    - lib/screens/schedule/schedule_screen.dart

key-decisions:
  - "_ValenceBadge and _ValenceChip are intentionally duplicated file-private classes (not shared) — consistent with existing _PriorityChip duplication pattern"
  - "tertiaryContainer/onTertiaryContainer for gives; secondaryContainer/onSecondaryContainer for costs — colorScheme.error intentionally excluded per UI-SPEC and threat model T-19-06"
  - "Emoji inline in chunk card title as string interpolation; separate Text widget in goal card title row — two different visual treatments justified by different layout contexts"
  - "_lookupGoalValence/_lookupGoalEmojiTag null-guard on chunk.goalId per threat T-19-05 (commitment chunks show no emoji/valence)"

# Metrics
duration: 4min
completed: 2026-06-15
---

# Phase 19 Plan 04: Card Rendering Summary

**_ValenceBadge on GoalCard title/secondary rows + _ValenceChip on ChunkCard with emoji prefix + two lookup helpers in ScheduleScreen — 14 valence tests GREEN (ENERGY-03b, ENERGY-04a, ENERGY-04b)**

## Performance

- **Duration:** 4 min
- **Started:** 2026-06-15T02:36:57Z
- **Completed:** 2026-06-15T02:41:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- `goal_card.dart`: Added `import energy_valence.dart`; inserted `Text(goal.emojiTag!)` between type icon and goal name when `emojiTag != null`; appended `_ValenceBadge` after `_PriorityChip` in secondary row when valence is non-neutral; added file-private `_ValenceBadge` class (gives=tertiaryContainer/bolt, costs=secondaryContainer/hourglass, neutral=SizedBox.shrink)
- `chunk_card.dart`: Added `import energy_valence.dart`; added `goalEmojiTag`/`goalValence` params to `ChunkCard` and `_WorkChunkContent`; emoji prefix via string interpolation in title Text; `_ValenceChip` insertion after `_PriorityChip` block; file-private `_ValenceChip` class (visual duplicate of `_ValenceBadge`)
- `swipeable_chunk_card.dart`: Added `import energy_valence.dart`; added `goalEmojiTag`/`goalValence` pass-through params; forwarded into `ChunkCard(...)` call
- `schedule_screen.dart`: Added `import energy_valence.dart`; added `_lookupGoalValence` + `_lookupGoalEmojiTag` helpers (verbatim structure from `_lookupGoalPriorityWeight`); wired both props into `_buildSwipeableCard` and `_buildSkippedSection` call sites

## Task Commits

Each task was committed atomically:

1. **Task 1: Goal card emoji + _ValenceBadge** - `16de8bc` (feat)
2. **Task 2: Chunk card _ValenceChip + emoji, swipeable pass-through, schedule lookups** - `cfb7430` (feat)

## Files Created/Modified

- `lib/screens/goals/widgets/goal_card.dart` — import + emoji in title row + _ValenceBadge class + secondary-row badge insertion
- `lib/screens/schedule/widgets/chunk_card.dart` — import + goalEmojiTag/goalValence params on ChunkCard/_WorkChunkContent + emoji prefix + _ValenceChip class + chip insertion
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart` — import + goalEmojiTag/goalValence params + ChunkCard pass-through
- `lib/screens/schedule/schedule_screen.dart` — import + _lookupGoalValence + _lookupGoalEmojiTag + both call sites wired

## Decisions Made

- `_ValenceBadge` (goal_card) and `_ValenceChip` (chunk_card) are intentional file-private duplicates. Not extracted to a shared widget — consistent with the existing `_PriorityChip` duplication pattern documented in PATTERNS.md and UI-SPEC.
- Valence colors: `tertiaryContainer`/`onTertiaryContainer` for gives; `secondaryContainer`/`onSecondaryContainer` for costs. `colorScheme.error` intentionally excluded per UI-SPEC and threat model T-19-06.
- Emoji rendering in goal card uses a separate `Text` widget (between type icon and goal name). Emoji rendering in chunk card uses string interpolation (`'$emoji $name'`) in the single title `Text` — different layout contexts call for different approaches.
- Lookup helpers null-guard `chunk.goalId == null` per threat T-19-05: commitment chunks (no goalId) render no emoji/valence rather than mis-resolving another goal's data.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — this plan renders live data from `Goal.energyValence` and `Goal.emojiTag` (set by Plan 19-03 goal form). No hardcoded values or placeholder data.

## Threat Surface Scan

No new network endpoints, auth paths, or trust-boundary changes. All rendering is display-only (read Goal fields set at write time in Plan 19-03). Threat mitigations T-19-05 and T-19-06 implemented as specified:
- T-19-05: Both lookup helpers null-guard `chunk.goalId == null` — commitment chunks render no emoji/valence
- T-19-06: Explicit `!= EnergyValence.neutral` guard at both render sites; `colorScheme.error` never used

## Self-Check: PASSED

- FOUND: lib/screens/goals/widgets/goal_card.dart (import + _ValenceBadge + emojiTag rendering)
- FOUND: lib/screens/schedule/widgets/chunk_card.dart (_ValenceChip + goalEmojiTag/goalValence params)
- FOUND: lib/screens/schedule/widgets/swipeable_chunk_card.dart (goalEmojiTag/goalValence pass-through)
- FOUND: lib/screens/schedule/schedule_screen.dart (_lookupGoalValence + _lookupGoalEmojiTag)
- FOUND commit: 16de8bc (Task 1)
- FOUND commit: cfb7430 (Task 2)
- Tests: goal_card_valence_test.dart 7/7 GREEN, chunk_card_valence_test.dart 7/7 GREEN

---
*Phase: 19-energy-valence*
*Completed: 2026-06-15*

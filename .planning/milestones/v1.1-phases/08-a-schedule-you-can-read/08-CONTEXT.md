# Phase 8: A Schedule You Can Read - Context

**Gathered:** 2026-06-10
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase makes the generated schedule **legible** without changing how many chunks are generated (that is Phase 9's job). It delivers four things:

1. **READ-01** — Every chunk card titles itself with the goal's real name (looked up by `goalId`), with a human-readable rationale as secondary text.
2. **READ-02** — The schedule reads in coherent day order: anchored commitment blocks sit at their clock times, discretionary chunks fill around them, breaks never appear inside a commitment window, and there is no dangling trailing break.
3. **READ-03** — Tapping a work chunk opens a detail bottom sheet showing goal name, why it was scheduled, and complete / skip / defer actions.
4. **READ-04** — A minimal companion focus mode highlights the current chunk with an optional 25-minute countdown that flows into a completion action and a break suggestion.

**Explicitly out of scope (deferred):** budget-/deadline-driven *dynamic* rationale strings and capacity-filling generation (Phase 9); full defer-to-tomorrow carryover and the closed focus→completion→advance loop (Phase 10, CLOSE-02/CLOSE-03). Phase 8 designs the focus mode and ships a present-but-minimal Defer.

</domain>

<decisions>
## Implementation Decisions

### Chunk Card & Rationale (READ-01)
- Card **title** is the goal's real name, looked up by `goalId` via `GoalsNotifier`. Commitment-anchored chunks (no `goalId`) show the block name. Break cards keep "X min break".
- **Secondary text** is a readable static rationale ("Daily habit", "Toward your deadline", "Weekly time goal", commitment name) — replacing the current generic `rationale` strings ("Habit"/"Outcome goal"/"Weekly goal"). These remain static in Phase 8; Phase 9 replaces them with budget-driven dynamic strings.
- Goal name is **resolved in the screen** (mirroring the existing `_lookupGoalColor` pattern in `schedule_screen.dart`) and passed into `ChunkCard` as a parameter — keeping `ChunkCard` a pure presentational widget.
- Break cards are visually unchanged.

### Ordering & Breaks (READ-02)
- Discretionary chunks are assigned synthetic clock times that **fill the gaps around anchored commitment windows**; the whole chunk list is then sorted by start time so the schedule reads top-to-bottom in day order.
- **No dangling trailing break** — trim any break that would follow the final work chunk.
- **No breaks inside a commitment window** — a commitment block chunked into contiguous 25-min pieces gets no short/long breaks injected between those pieces.
- All ordering/break logic lives in `ScheduleGeneratorService` (pure Dart, no Flutter imports) so it stays unit-testable, consistent with the existing architecture.

### Detail Sheet (READ-03)
- Presented via `showModalBottomSheet`, matching the Phase 2 goal-form sheet pattern.
- Shows goal name, the "why scheduled" rationale, and **Complete / Skip / Defer** action buttons.
- **Defer** is present and minimal: it removes the chunk from today's view (like skip) in Phase 8; next-day carryover wiring lands in Phase 10 (CLOSE-02).
- Only **work chunks** are tappable / open a sheet; break chunks are not tappable.
- The sheet **complements** existing input: swipe-to-complete/skip and hover icons remain; tap is the discoverable explicit path.

### Focus Mode (READ-04)
- Entry from a **"Start focus" button in the detail sheet**, plus a current-chunk entry affordance on the schedule screen.
- Presented as a **full-screen route `/focus`** outside the StatefulShell (immersive, no bottom nav — consistent with `/summary` and `/review`).
- **"Current chunk"** = the first unresolved (not completed, not skipped) work chunk in day order.
- Optional **25-minute countdown**: user can start or skip it; on finish (timer end or explicit "Done") it calls `markComplete` for the chunk and surfaces a break suggestion (the following break chunk's duration). Auto-advance to the next chunk and full logging integration are deferred to Phase 10.

### Claude's Discretion
- Exact rationale wording, focus-mode visual styling, timer controls layout, and how the synthetic discretionary start times are computed — at Claude's discretion within the decisions above. Follow the brand/UI conventions surfaced by the UI-SPEC.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/screens/schedule/schedule_screen.dart` — `_lookupGoalColor(context, chunk)` already resolves a goal from `chunk.goalId` via `GoalsNotifier`; the same pattern resolves the goal **name**. Partitions active vs skipped chunks and builds the ListView.
- `lib/screens/schedule/widgets/chunk_card.dart` — renders work / shortBreak / longBreak variants; currently uses `chunk.rationale` as the title (line ~188). `hexToColor()` and `_formatMinutes()` helpers live here.
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart` — Dismissible wrapper (swipe right=complete, left=skip) via `confirmDismiss` → `ScheduleNotifier.markComplete/markSkipped`.
- `lib/providers/schedule_notifier.dart` — `markComplete(id)` / `markSkipped(id)` (save + append CompletionLog); `todaySchedule`, `moodIndex`, `hasScheduleToday`. New defer action will need a notifier method here.
- `lib/services/schedule_generator.dart` — pure generator; allocation order commitments→habits→outcomes→time-target, then a break-insertion pass that currently appends a break after **every** work chunk (incl. the last). This is where ordering + break fixes go.
- `lib/data/models/scheduled_chunk.dart` — `ScheduledChunk` has `goalId`, `anchoredStartMinutes` (set only for commitments), `rationale`, `isCompleted`, `isSkipped`. A `isDeferred` flag may need adding (HiveField 8) for minimal defer.
- `lib/data/models/goal.dart` — `Goal.name`, `color`, `deadline`, `goalType`.

### Established Patterns
- State: Provider + `ChangeNotifier` (`ScheduleNotifier`, `GoalsNotifier`); screen-local state via `StatefulWidget`.
- Routing: `go_router` `StatefulShellRoute`; immersive screens (`/summary`, `/review`, `/commitments`, `/onboarding`) are declared **outside** the shell branches. `/focus` follows that pattern.
- Bottom sheets: `showModalBottomSheet` (goal form in Phase 2).
- Material 3, `ColorScheme.fromSeed(Colors.deepOrangeAccent)`.
- Time stored as minutes-from-midnight (int); `_formatMinutes` converts to 12-hour display.

### Integration Points
- `/focus` route added to `lib/router.dart` outside the shell (alongside `/summary` at line ~110).
- New detail sheet opened from `ChunkCard`/`SwipeableChunkCard` tap in `schedule_screen.dart`.
- New defer notifier method in `schedule_notifier.dart`; if a Hive field is added, update the migration list (additive-only, increment schemaVersion) and regenerate `.g.dart` via build_runner.

</code_context>

<specifics>
## Specific Ideas

- Goal-name-as-title is the headline fix: today the card shows "Habit"/"Outcome goal" which the milestone reality-check flagged as illegible.
- Ordering must keep commitment chunks at their real anchored times — discretionary chunks slot into the gaps, not jammed before/after the whole block list.
- Defer must be visible in Phase 8 even though its cross-day effect only fully lands in Phase 10 — READ-03 requires the action to exist.

</specifics>

<deferred>
## Deferred Ideas

- Budget-/deadline-/priority-driven dynamic rationale strings → Phase 9 (An Engine That Budgets).
- Full defer-to-tomorrow carryover into the next morning's generated schedule → Phase 10 (CLOSE-02).
- Closed focus loop (auto-advance to next chunk, evening reminders, completion logging beyond markComplete) → Phase 10.

</deferred>

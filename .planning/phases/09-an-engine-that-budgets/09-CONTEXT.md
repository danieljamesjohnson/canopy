# Phase 9: An Engine That Budgets - Context

**Gathered:** 2026-06-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Make `ScheduleGeneratorService` honor the goal model it already stores. Schedule
generation must fill mood capacity and allocate chunks from real goal data —
weekly hour budgets, habit frequency, deadline pressure, and user-set priority
all drive the output. Covers ENGINE-01 through ENGINE-06.

In scope:
- Fill mood capacity with multiple chunks per goal (ENGINE-01).
- Time-target allocation proportional to how far behind weekly budget, computed
  from CompletionLog, most-behind first (ENGINE-02).
- Habit frequency (`frequencyPerWeek`) honored; real `streakCount` from history
  (ENGINE-03).
- Outcome deadline-pressure scheduling; remove `chunksRemaining = 2.0`
  placeholder (ENGINE-04).
- Wire the dead "Want a lighter day?" toggle through to the generator (ENGINE-05).
- Add a visible/editable priority control to the goal form and make priority
  influence scheduling (ENGINE-06).

Out of scope (deferred): user-pinned specific habit days/times; "bonus" overflow
chunks when capacity exceeds demand (policy: leave unscheduled for a calmer day);
any LLM involvement. End-of-day/deferral (Phase 10) and quarterly-review wiring
(Phase 11) are separate phases. Phase 8 already implemented the ordering/break
synthetic-time interleave — this phase feeds it real allocation, it does not
redo the interleave.

</domain>

<decisions>
## Implementation Decisions

### Capacity fill & per-type allocation
- Fill mood capacity by computing per-goal demand, allocating most-behind /
  most-urgent first, then filling remaining slots by priority. **Leave capacity
  unfilled if total demand < cap** — the accepted "calmer day" policy, no bonus
  chunks (owner decision, binding).
- Time-target chunk count per goal: `ceil(remaining weekly hours ÷ days left this
  week ÷ 25min)`, **capped at 4/day** (owner-locked allocation policy).
- "Behind budget" is measured from this week's *completed* time-target chunks in
  CompletionLog (week start → today); most-behind first. Skips do not count as
  elapsed budget.
- Outcome ordering: **deadline-pressure only** — `urgency = priority ×
  1/daysRemaining`. The `chunksRemaining = 2.0` placeholder is removed. **No** new
  "estimated chunks" form field (owner-locked).

### Priority control (ENGINE-06)
- UI: a 3-segment **SegmentedButton** (Low / Normal / High), shown for all goal
  types, placed near the top of the goal form under name/type.
- Mapping: Low = 0.25, Normal = 0.5, High = 0.75. Keeps the existing
  null → 0.5 default semantics as "Normal".
- Influence: priority acts as a **weight** in allocation scoring **and** as the
  tiebreaker when goals compete for the same capacity slot (high beats low —
  success criterion 6). It is *not* a hard gate; low-priority goals are still
  scheduled when capacity remains.
- Default: **Normal** (0.5). Existing goals with null priority render as Normal;
  no data migration required.

### Habit frequency & streaks (ENGINE-03)
- For `frequencyPerWeek` < 7, schedule on a deterministic **even spread** of
  weekdays derived from the frequency (e.g. 3x → Mon/Wed/Fri, 5x → Mon–Fri).
  User-pinned specific days are deferred to a future milestone.
- Streak = consecutive **scheduled-and-due** days completed, **frequency-aware**:
  a day the habit was not due does not break the streak (proposal default).
- A due day that is **skipped or missed resets the streak to 0**.
- `streakCount` is recomputed from CompletionLog history at completion/generation
  time and cached into `Goal.streakCount`. The log is the source of truth;
  `streakCount` is a derived projection, not a naive increment.

### "Want a lighter day?" toggle (ENGINE-05)
- At mood 3–5 the toggle reduces the effective capacity by **one mood tier**
  (use the next-lower mood's cap) so the discretionary chunk count measurably
  drops.
- At mood 1–2 the day is already restricted to habits + deadline-critical work;
  lighter ON keeps that, lighter **OFF (heavier) adds back deadline-critical
  outcome work**.
- Default remains **ON** (`_lighterDay = true`); this phase actually plumbs the
  flag through `generateToday()` → `ScheduleGeneratorService.generate()` (it is
  currently dead state in `checkin_screen.dart`).
- The toggle reduces discretionary **work** chunks only; break cadence rules are
  unchanged.

### Claude's Discretion
- Exact method signatures, where the per-goal demand/streak computation lives
  (helper methods on the service vs. small pure helpers), the precise
  SegmentedButton styling, and how dynamic rationale strings are phrased — at
  implementation discretion, following existing codebase conventions and the
  Phase 8 rationale-string handoff.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/services/schedule_generator.dart` — `ScheduleGeneratorService.generate()`
  is pure Dart (no Flutter imports), already structured in allocation steps
  (commitments → habits → outcome → time-target) plus a Phase 8 synthetic-time
  ordering/break pass. This phase rewrites the allocation steps and adds a
  CompletionLog/priority/lighterDay-aware demand computation; it keeps the Phase 8
  ordering pass intact.
- `lib/data/models/goal.dart` — already has `priorityWeight`, `weeklyHourBudget`,
  `deadline`, `frequencyPerWeek`, `streakCount` fields. No schema change needed;
  the fields exist but are unread by the engine today.
- `lib/data/models/completion_log.dart` — append-only log with `goalId`,
  `dateYmd` (YYYY-MM-DD), `eventIndex` (completed/skipped/deferred). The data
  source for "behind budget" and streak computation.
- `lib/providers/schedule_notifier.dart` — `generateToday({moodIndex, ...})`
  already holds a `CompletionLogRepository` (`_logRepo`) and the
  `ScheduleGeneratorService` (`_generator`). It must now read completion history
  and pass it (plus `lighterDay`) into `generate()`.
- `lib/screens/goals/goal_form_sheet.dart` — already has `_priorityWeight` state
  wired to save (`..priorityWeight = _priorityWeight`) but renders **no control**.
  Add the SegmentedButton here. Existing Slider pattern for frequency is the model
  to follow.
- `lib/screens/schedule/checkin_screen.dart` — `_lighterDay` bool state (line 41)
  and the toggle UI (lines 198–204) exist but the value is never passed to
  `generateToday()`. Plumb it.
- `lib/utils/rationale_mapper.dart` — Phase 8 rationale strings; Phase 8 CONTEXT
  explicitly hands off dynamic budget-driven rationale to Phase 9.

### Established Patterns
- Engine logic is pure Dart in `services/` for unit-testability — keep all new
  allocation/streak math there, not in the notifier or widgets.
- Enums stored as int index (`goalTypeIndex`, `eventIndex`); never reorder.
- All time stored as UTC; dates compared on local-date boundary (see
  `ThemeNotifier._resetIfDayChanged` / `ScheduleNotifier.hasScheduleToday`).
- Repositories injected with in-memory fakes available for tests.

### Integration Points
- `ScheduleNotifier.generateToday` → `ScheduleGeneratorService.generate` is the
  one call site to thread completion history + lighterDay through.
- Goal form save path already persists `priorityWeight`; only the input control
  is missing.
- Streak write-back: completion handlers in `ScheduleNotifier` (markComplete /
  skip paths) recompute and persist `Goal.streakCount` via `GoalRepository`.

</code_context>

<specifics>
## Specific Ideas

- Allocation policy is a **binding owner decision** (from
  `.planning/NEXT-MILESTONE-PROPOSAL.md`): time-target =
  remaining-budget ÷ remaining-days capped 4/day; outcome = deadline-pressure;
  no bonus/overflow chunks. Do not re-derive or alter this.
- Success criterion 6 requires priority to be the decisive factor when two goals
  compete for the same slot — verify with a test where a high- and low-priority
  goal contend for one remaining capacity slot.
- Removing `chunksRemaining = 2.0` (schedule_generator.dart:101-102) is an
  explicit acceptance criterion — make sure no placeholder constant survives.

</specifics>

<deferred>
## Deferred Ideas

- User-pinned specific days/times for habits and commitments (future milestone).
- "Bonus" overflow chunks when capacity exceeds demand (current policy: leave
  unscheduled — owner accepted).
- LLM-assisted scheduling / conversational re-planning (v2).

</deferred>

# Phase 11: Honest Long Loop - Context

**Gathered:** 2026-06-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the quarterly review honest and consequential. This phase fixes the existing
quarterly-review feature (built in v1.0 Phase 5) so that: (1) its aggregation and donut
chart count **all** logged time — including commitment-block chunks and archived goals'
historical completions — with chart percentages that sum to 100% and no invisible slice;
(2) priority adjustments made in the review **demonstrably** change the next morning's
generated schedule; and (3) the review loads its own data correctly on a cold launch from
the Home screen, with no dependency on having visited another tab first.

In scope: aggregation logic, donut chart slice construction, the adjustments→generation
wiring, and the review screen's data-loading path. Out of scope: the reflection question
flow, chart styling beyond what's needed for honest slices, and any new review features.

Requirements: REVIEW-01, REVIEW-02, REVIEW-03.

</domain>

<decisions>
## Implementation Decisions

### Honest Aggregation (REVIEW-01)
- Commitment-block time is shown as **one dedicated "Commitments" slice** (neutral color),
  aggregating all commitment chunks — counted and labeled, distinct from goals.
- Archived goals' historical completions render as **their own slices** using each goal's
  stored name and color, with an "(archived)" suffix in the legend.
- **No invisible slice:** donut sections are built from the aggregated chunk totals (every
  counted id — active goal, archived goal, commitment, or fallback — gets a drawn slice).
  Any id that resolves to nothing falls into a catch-all "Other" slice. The percentage
  denominator is the sum of all drawn slices, so percentages add up to 100%.
- "Time not spent" (skipped + deferred) remains its own slice (existing D-02 honest
  behavior) and is included in the 100% total.

### Priority Adjustments Drive Schedule (REVIEW-02)
- Drag-to-reorder in the adjustments section maps the resulting order to each goal's
  **`priorityWeight`** — the field the schedule generator already reads (`schedule_generator.dart`
  orders outcome-goal urgency and habit tiebreakers by `priorityWeight`, and never reads
  `sortOrder`). `sortOrder` continues to be persisted for display ordering.
- Drag position maps to `priorityWeight` via a **linear spread** over the existing range
  (top of list = highest weight), so reordering always produces distinct, monotonic weights
  and a real change in generation input.
- The change takes effect in the **next morning's** schedule generation: priorities persist
  on "Finish review", and the next generate run picks them up (matches the success
  criterion "next day's schedule"). Today's already-generated schedule is not regenerated.
- "Demonstrably changes" is proven with a **test**: set a goal to top priority, regenerate,
  and assert its chunk ordering/position differs from the pre-change baseline.

### Independent Cold-Launch Loading (REVIEW-03)
- The review loads **all goals it needs, including archived**, so every logged goalId
  resolves regardless of which tabs were visited: active goals come from GoalsNotifier
  (already loaded at startup per Phase 7 / LOOP-01) and archived goals are loaded via the
  goals repository (`loadArchivedGoals` / repo `getAll`).
- Commitment labels for the "Commitments" slice load from CommitmentsNotifier / the
  commitment repository in `_loadData` (CommitmentsNotifier is also loaded at startup per
  Phase 7).
- The "has data" empty-state guard is based on the review's **own data (completion logs +
  snapshots)**, not on whether provider goal lists happen to be populated.
- A **cold-launch regression test** pumps the review without visiting other screens and
  asserts the chart and goal list are populated.

### Claude's Discretion
- Exact neutral color for the "Commitments" slice and the "Other" catch-all color.
- The precise linear-spread formula and weight bounds for drag→priorityWeight mapping,
  within the constraint that the mapping is monotonic and yields distinct weights.
- Legend ordering and any minor layout adjustments needed to fit added slices.
- Whether archived-goal resolution reuses an existing repository call or adds a thin
  combined lookup, as long as it stays append-only and read-only for archived data.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/services/quarterly_aggregation_service.dart` — pure-Dart aggregation
  (`completedByGoal`, `completedByWeek`, `notSpentCount`, `totalCompleted`,
  `completionRateByGoal`). Already keyed on `CompletionLog.goalId`; fully unit-testable.
- `lib/screens/quarterly_review/widgets/donut_chart.dart` — current donut; **iterates
  active `goals` only** (the source of the invisible-slice bug). Slice construction is the
  primary edit site for REVIEW-01.
- `lib/screens/quarterly_review/quarterly_review_screen.dart` — `_loadData()` reads logs +
  latest snapshot directly from repositories and goals from `GoalsNotifier`. Edit site for
  REVIEW-03 (also load archived goals + commitments here).
- `lib/screens/quarterly_review/sections/adjustments_section.dart` — `_finish()` calls
  `notifier.reorderAll(orderedIds)` (writes `sortOrder` only). Edit site for REVIEW-02.
- `lib/providers/goals_notifier.dart` — `reorderAll`, `archiveGoal`, `loadArchivedGoals`,
  `goals` getter (active only, sorted by `sortOrder`). Add/extend a path that also writes
  `priorityWeight` from order.
- `lib/services/schedule_generator.dart` — orders by `priorityWeight` (lines ~267-313);
  does **not** read `sortOrder`. This asymmetry is the REVIEW-02 root cause.

### Established Patterns
- Providers (Goals, Commitments, Schedule, Settings, Theme) are constructed in `main()` and
  their load/init awaited **before** `runApp` (Phase 7 / LOOP-01), registered via
  `ChangeNotifierProvider.value`.
- `CompletionLog` (`lib/data/models/completion_log.dart`) has no separate `commitmentId`
  field — commitment chunks were logged into `goalId` via `chunk.commitmentId ?? chunk.goalId ?? ''`
  (Phase 10-01). The review must resolve a logged id against goals **and** commitments to
  attribute commitment time.
- Hive completion logs and quarterly snapshots are append-only (enforced at interface level,
  Phase 01-04).
- `hexToColor()` and `GoalsNotifier.colorPalette` are the established color helpers used by
  the donut and tiles.

### Integration Points
- Donut slice construction ← aggregated totals + resolved labels (goals/archived/commitments).
- Adjustments "Finish review" ← writes `priorityWeight` so → next `ScheduleNotifier.generate`.
- Review `_loadData` ← repositories for archived goals + commitments; empty-state guard ←
  logs/snapshots.

</code_context>

<specifics>
## Specific Ideas

- Donut percentages must visibly sum to 100% with every counted chunk drawn — this is the
  acceptance bar for REVIEW-01, not just an internal aggregation correctness check.
- "Demonstrably change the schedule" should be backed by an executable test that compares
  generated ordering before/after a priority change (REVIEW-02 success criterion).
- Cold launch means opening `/review` from Home on first launch without touching other tabs
  (REVIEW-03 success criterion) — verify with a test that does not pump other screens first.

</specifics>

<deferred>
## Deferred Ideas

- Reworking the reflection question set or making questions configurable (v2, per Phase 5 D-08).
- Per-commitment breakdown slices (chose a single aggregated "Commitments" slice instead).
- Calendar-driven commitment data (v2, out of milestone scope).

</deferred>

# Phase 5: Quarterly Review - Context

**Gathered:** 2026-04-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Users gain visibility into how their time was actually spent over the past quarter and can update their goals and priorities for the next quarter through a data-first, guided reflection flow. The review is celebratory, not evaluative.

</domain>

<decisions>
## Implementation Decisions

### Data Presentation
- **D-01:** Both donut chart (time by goal proportions) and bar chart (completed chunks per week over the quarter) — as spec'd in ROADMAP
- **D-02:** Skipped chunks shown transparently as their own slice/category ("Time not spent") — honest, no hiding
- **D-03:** Hero stat at top: total chunks completed as a big number ("247 chunks completed this quarter")
- **D-04:** fl_chart used for both donut and bar chart (introduced this phase per ROADMAP)

### Reflection Flow
- **D-05:** One question per screen, swipe to advance — focused, no overwhelm
- **D-06:** Tap-to-pick answers: 2-3 suggested answers per question (e.g. goal names from user's data) plus an "Other" option for free text
- **D-07:** Celebratory/warm tone — "Which goal gave you the most energy?" not "What did you miss?"
- **D-08:** Fixed question set in v1 (per ROADMAP) — configurable questions deferred to v2

### Goal Adjustments
- **D-09:** Priority reordering via drag — goals shown in priority order, drag to reorder for next quarter
- **D-10:** Suggest archiving underused goals with a gentle one-tap "Archive this?" prompt for goals with very low completion rates
- **D-11:** Updated priorities persist to GoalsNotifier and affect next morning's schedule generation (per ROADMAP acceptance criteria)

### Review Trigger & Entry
- **D-12:** Home screen banner ("Your quarterly review is ready") when within 7 days of the 90-day review window
- **D-13:** Always dismissable — review is optional, accessible from Settings > Past Reviews anytime
- **D-14:** Review launches as full-screen route at `/review` (already wired in router, outside shell — no bottom nav)
- **D-15:** Past reviews accessible from Settings screen (per ROADMAP: "visible in a 'Past reviews' list accessible from settings")

### Claude's Discretion
- Exact wording of the 3-5 reflection questions (within celebratory/warm tone constraint)
- Chart color scheme and styling details (goal colors from GoalsNotifier used where possible)
- Animation between reflection question screens
- Layout spacing, typography, and card styling for the data section
- Archive suggestion threshold (what completion rate counts as "very low")

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Data models and repositories
- `lib/data/models/completion_log.dart` — CompletionLog entity with chunkId, goalId, dateYmd, eventIndex (completed/skipped/deferred)
- `lib/data/models/quarterly_snapshot.dart` — QuarterlySnapshot stub with goalChunkTotals map and reflectionAnswers list
- `lib/data/repositories/completion_log_repository.dart` — Append-only repo with getByGoalId, getByDate queries
- `lib/data/repositories/quarterly_snapshot_repository.dart` — Append-only repo with append, getAll, getLatest

### Existing screens and routing
- `lib/screens/quarterly_review/quarterly_review_screen.dart` — Placeholder screen to be replaced
- `lib/router.dart` — `/review` route already registered outside StatefulShellRoute (full-screen, no bottom nav)
- `lib/screens/home/home_screen.dart` — Home screen where review banner will be added
- `lib/screens/settings/settings_screen.dart` — Settings screen where "Past Reviews" entry point will be added

### Goal and schedule infrastructure
- `lib/providers/goals_notifier.dart` — GoalsNotifier that must be updated with new priorities after review
- `lib/data/models/goal.dart` — Goal entity with fields for priority ordering

No external specs — requirements fully captured in ROADMAP.md phase description and decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `QuarterlySnapshot` model: already has Hive fields for `goalChunkTotals` (Map<String, int>) and `reflectionAnswers` (List<String>) — ready to populate
- `CompletionLog` model: append-only events with `completed`, `skipped`, `deferred` enum — aggregation source
- `QuarterlySnapshotRepository`: append-only with `getLatest()` for determining when last review was done
- `CompletionLogRepository`: `getByGoalId()` and `getByDate()` queries available for aggregation
- Weather metaphor mood colors and emojis in `HomeScreen` — visual language to stay consistent with

### Established Patterns
- Provider/ChangeNotifier for state management (GoalsNotifier, ScheduleNotifier, SettingsNotifier)
- Hive for local persistence with repository interfaces
- Full-screen routes outside StatefulShellRoute for focused flows (onboarding, review, end-of-day summary)
- Bottom sheet pattern for forms/edit views
- Drag-to-reorder already implemented in GoalsScreen (ReorderableListView.builder)

### Integration Points
- Home screen: add review banner when within review window (check against `QuarterlySnapshotRepository.getLatest()`)
- Settings screen: add "Past Reviews" list entry
- GoalsNotifier: update goal priority ordering after review completion
- ScheduleGenerator: already reads goal priorities — updated priorities will flow through automatically

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches within the decisions above.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 05-quarterly-review*
*Context gathered: 2026-04-06*

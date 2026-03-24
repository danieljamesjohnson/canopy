# Phase 4: Chunk Tracking and Notifications - Context

**Gathered:** 2026-03-24
**Status:** In progress — gray area discussion not yet completed

<domain>
## Phase Boundary

The daily loop closes: users can mark chunks complete or skipped throughout the day via swipe gestures, receive a morning notification to start their day, and export their data as JSON. Includes end-of-day summary screen, notification configuration in settings, and Web fallback banner.

</domain>

<decisions>
## Implementation Decisions

### Prior Decisions Carried Forward
- **D-01:** CompletionLog is strictly append-only — no mutation or deletion (Phase 1 architecture, enforced at repository interface level)
- **D-02:** Bottom sheet pattern for detail/edit views (Phase 2 established pattern)
- **D-03:** Weather metaphor + mood color palette (#4A6275 → #E8C547) for visual consistency (Phase 3)
- **D-04:** ChunkCard already renders done state: grey bar, 50% opacity, check_circle icon (Phase 3)
- **D-05:** Warm, direct tone — not instructional or corporate (Phase 2)

### Pending Discussion Areas
The following gray areas were identified but not yet discussed with the user:

1. **Swipe completion feel** — How swipe-to-complete and swipe-to-skip should look/feel during the gesture (reveal-behind pattern, slide-off, haptic feedback, undo affordance)
2. **End-of-day summary** — Trigger mechanism, data breakdown, tone/copy, dismiss UX
3. **Notification experience** — Morning notification content/tone, iOS permission request timing, mid-day nudge opt-in UI, Web banner design
4. **Settings & data export** — Settings screen layout, JSON export presentation (share sheet vs file save), export confirmation UX

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Deliverables
- `.planning/ROADMAP.md` §Phase 4 — Full phase spec with acceptance criteria, deliverables, and key technical decisions

### Prior Phase Context
- `.planning/phases/01-foundation/01-CONTEXT.md` — Database, repository, migration decisions
- `.planning/phases/02-goals-and-commitments/02-CONTEXT.md` — Goal list, creation UX, onboarding, commitment block patterns
- `.planning/phases/03-schedule-generation-and-morning-check-in/03-CONTEXT.md` — Morning flow, mood check-in, chunk card visual states, weather metaphor

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `CompletionLog` model (`lib/data/models/completion_log.dart`): Already defined with id, chunkId, goalId, dateYmd, eventIndex (completed/skipped/deferred), recordedAt. Ready to use.
- `CompletionLogRepository` (`lib/data/repositories/completion_log_repository.dart`): Append-only interface with getAll, getByDate, getByGoalId. Implementation exists in `hive_completion_log_repository.dart`.
- `ChunkCard` (`lib/screens/schedule/widgets/chunk_card.dart`): Renders work/shortBreak/longBreak variants. Already handles isCompleted state (grey bar, 50% opacity, check_circle icon). Needs swipe gesture wrapping.
- `ScheduledChunk` model (`lib/data/models/scheduled_chunk.dart`): Has `isCompleted` and `isSkipped` boolean fields already defined.
- `hexToColor()` helper in `chunk_card.dart`: Converts hex strings to Flutter Colors.
- `ScheduleProgressBar` (`lib/screens/schedule/widgets/schedule_progress_bar.dart`): Existing progress indicator.

### Established Patterns
- Provider/ChangeNotifier: `GoalsNotifier`, `CommitmentsNotifier`, `ScheduleNotifier` — follow this pattern for any new notifiers
- Bottom sheet with `DraggableScrollableSheet`: Used in goal/commitment forms — reuse for chunk detail/edit sheet
- Enum stored as int index (`chunkTypeIndex`, `eventIndex`): Consistent pattern across models
- `hive_ce` persistence: All repositories follow the same Hive box pattern

### Integration Points
- `ScheduleNotifier` (`lib/providers/schedule_notifier.dart`): Needs completion tracking methods (markComplete, markSkipped) that update both ScheduledChunk flags and append CompletionLog entries
- `SettingsScreen` (`lib/screens/settings/settings_screen.dart`): Currently a stub ("coming in Phase 4") — needs full implementation with notification config and export
- `router.dart`: Needs routes for end-of-day summary screen
- `main.dart`: Notification initialization on app launch

</code_context>

<specifics>
## Specific Ideas

No specific requirements captured yet — discussion was interrupted before gray area selection.

</specifics>

<deferred>
## Deferred Ideas

None yet — discussion had not reached this stage.

</deferred>

---

*Phase: 04-chunk-tracking-and-notifications*
*Context gathered: 2026-03-24 (incomplete — resume with /gsd:discuss-phase 4)*

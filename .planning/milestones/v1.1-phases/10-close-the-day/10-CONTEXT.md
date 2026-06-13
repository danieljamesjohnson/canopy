# Phase 10: Close the Day - Context

**Gathered:** 2026-06-11
**Status:** Ready for planning

<domain>
## Phase Boundary

The daily loop gets a discoverable end. This phase delivers three user-observable
capabilities (CLOSE-01, CLOSE-02, CLOSE-03):

1. A time-aware **end-of-day card** on Home that surfaces after ~6pm or once ≥50%
   of work chunks are resolved, routing to the already-built end-of-day summary,
   plus an opt-in evening reminder notification.
2. **Defer-to-tomorrow** that actually carries an unresolved deferred chunk into
   the next morning's generated schedule with no manual action.
3. **Correct commitment-time attribution** — completing (or skipping/deferring) a
   commitment-block chunk logs a non-empty identifier so commitment time appears
   in aggregation instead of being silently dropped.

Rule-based only (no LLM), local Hive storage, additive-only migrations, iOS as the
primary daily driver. Full quarterly-chart treatment of commitment time is **out of
scope** here — it lands in Phase 11 (REVIEW-01); this phase only makes the log correct.

</domain>

<decisions>
## Implementation Decisions

### End-of-Day Card & Evening Reminder (CLOSE-01)
- **Trigger:** the Home end-of-day card appears once it is after ~6pm **OR** ≥50%
  of today's work chunks are resolved (completed + skipped + deferred). The "OR"
  matches the success criterion exactly.
- **Card behavior:** a dismissible card pinned at the top of Home's active-schedule
  view that taps through to the **existing** `EndOfDaySummaryScreen` at `/summary`.
  Reuse that screen — do not rebuild the summary. The card is the missing
  discoverability layer, not new summary content.
- **Evening reminder:** opt-in toggle in Settings, default **OFF**. Uses a new
  NotificationService method on **notification id 2** (morning=0, mid-day nudge=1),
  scheduled on app start when enabled and idempotently rescheduled — mirroring the
  existing `scheduleMorningNotification` pattern, including the desktop/web
  `zonedSchedule` guard.
- **Evening reminder time:** a fixed sensible default (8:00pm / 1200 minutes from
  midnight) persisted alongside the existing notification settings. **No new
  time-picker UI** this phase; configurability can come later.

### Defer-to-Tomorrow Carryover (CLOSE-02)
- **Carry-in source:** at generation, pull chunks where `isDeferred && !isCompleted`
  from the **most recent prior schedule only** (single-hop) and feed them into
  today's generation. No unbounded backlog scan.
- **Re-appearance:** a deferred chunk is **re-materialized as fresh demand for the
  same goal** through the normal generator, so it respects today's ordering, breaks,
  and capacity — rather than copying the stale chunk object onto today. Only
  **discretionary goal** chunks carry; **commitment** chunks (anchored to their day)
  do not defer-carry.
- **Repeat-defer:** single-hop semantics — a chunk deferred again the next day
  carries again, but there is no multi-day pile-up of stale deferrals. Only the
  immediately-preceding day's unresolved deferrals are considered.
- **Logging + streak:** `markDeferred` now logs `CompletionEvent.deferred` (the enum
  value already exists) instead of Phase 8's log-as-skipped. A **deferred** day does
  **not** reset a habit streak (it is a move, not a miss) — distinct from skip. This
  changes the Phase 8 behavior and interacts with ENGINE-03's `computeStreak`, which
  must treat `deferred` events as non-breaking.

### Commitment Time Attribution (CLOSE-03)
- **Identifier:** commitment-chunk completion logs the owning **`CommitmentBlock.id`**
  (per-block attribution, so "Job" time is distinct from "Gym" time), not a single
  sentinel. The success criterion's "non-empty goal identifier" is satisfied by a
  real block id.
- **Carrier field:** add a new `commitmentId` field to `ScheduledChunk`
  (**HiveField 9**, additive migration + `build_runner` regen). Do **not** overload
  `goalId` — preserving the `goalId == Goal-id` invariant keeps existing guards
  (e.g. `getByGoalId`, streak write-back) and the summary/aggregation `gid.isEmpty`
  filters correct.
- **Aggregation treatment:** commitment time is a **distinct "Commitment" category**,
  not a fake Goal. This phase guarantees the log is correct (non-empty id, attributable);
  surfacing it in the quarterly charts/donut is **Phase 11 (REVIEW-01)**.
- **All log paths:** complete **and** skip **and** defer write the `commitmentId` for
  commitment chunks, consistently — not just the complete path.

### Claude's Discretion
- Exact card copy/placement and dismissal persistence, the precise evening-reminder
  notification text, the generator method signature for threading carried-over
  deferrals, and where the carry-in lookup lives (notifier vs. generator helper) —
  at implementation discretion, following existing codebase conventions.
- Verification: automated gates are `flutter analyze` (clean) and `flutter test`
  (all pass) on the installed Flutter; add regression tests for (a) the 6pm/50%
  trigger, (b) a deferred chunk re-appearing next morning, (c) a streak surviving a
  deferral, and (d) a commitment completion logging a non-empty id. On-device iOS
  evening-notification firing is a **manual UAT item** (no iOS simulator on Linux).

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/screens/end_of_day/end_of_day_summary_screen.dart` — full summary screen
  already built; routed at `/summary` (outside the shell). The end-of-day card just
  needs to route here. It already skips empty-goalId chunks (`if (gid.isEmpty) continue`),
  which is exactly why CLOSE-03 attribution matters.
- `lib/screens/home/home_screen.dart` (393 lines) — `build()` watches `ScheduleNotifier`;
  active-schedule branch (line ~74) is where the end-of-day card is inserted.
- `lib/services/notification_service.dart` — `scheduleMorningNotification` (id 0) and
  `scheduleMidDayNudge` (id 1) establish the exact pattern (cancel→zonedSchedule, with
  Linux/Windows guards) to copy for an evening reminder on **id 2**.
- `lib/providers/settings_notifier.dart` — morning + mid-day notification prefs with
  `set*Enabled`/`set*Minutes` persistence pattern; add an evening-reminder toggle the
  same way. Backed by the `AppSettings` Hive box.
- `lib/data/models/scheduled_chunk.dart` — `isDeferred` (HiveField 8) **already exists**;
  add `commitmentId` (HiveField 9). `goalId`, `anchoredStartMinutes`, `rationale`
  (block name) present.
- `lib/data/models/commitment_block.dart` — has `id` (HiveField 0) — the identifier to log.
- `lib/data/models/completion_log.dart` — `CompletionEvent { completed, skipped, deferred }`
  already defined; `deferred` is currently unused and is now wired up.
- `lib/providers/schedule_notifier.dart` — `markComplete` / `markSkipped` / `markDeferred`
  all log `goalId: chunk.goalId ?? ''` (the empty-string bug sites). `generateToday`
  is the single call site to thread carried-over deferrals into `generate()`.
- `lib/services/schedule_generator.dart` — pure-Dart `generate()`; Step 1 builds
  commitment chunks with `goalId: null` (the attribution gap) and `rationale: block.name`.
  `computeStreak` / `computeDueWeekdays` are the streak helpers that must treat
  `deferred` as non-breaking.

### Established Patterns
- State: Provider + `ChangeNotifier`; screen-local via `StatefulWidget` + `setState`.
- Engine logic stays pure Dart in `services/` for unit-testability; notifier orchestrates.
- Routing: `go_router` `StatefulShellRoute`; immersive screens (`/summary`, `/focus`,
  `/review`) declared **outside** the shell.
- Hive migrations are additive-only; new field → bump schemaVersion, regen `.g.dart`
  via `build_runner`; nullable/defaulted fields degrade gracefully for old records.
- All time stored as minutes-from-midnight (int) / UTC timestamps; day boundary
  compared on local date (`ScheduleNotifier.hasScheduleToday`, `_resetIfDayChanged`).

### Integration Points
- Home active-schedule branch → insert end-of-day card (`home_screen.dart`).
- `NotificationService` → new evening method (id 2); call site on app start /
  settings toggle, alongside `scheduleMorningNotification` wiring in `main.dart`.
- `ScheduleNotifier.generateToday` → `ScheduleGeneratorService.generate` is the one
  seam to pass carried-over deferred chunks through.
- `markComplete`/`markSkipped`/`markDeferred` → write `commitmentId` for commitment
  chunks; `markDeferred` switches its logged event to `deferred`.
- `computeStreak` → treat `deferred` events as non-breaking.
- Migration list + `scheduled_chunk.g.dart` regen for the new `commitmentId` field.

</code_context>

<specifics>
## Specific Ideas

- The end-of-day **summary screen already exists** — CLOSE-01 is about
  *discoverability* (the time-aware Home card) and the opt-in reminder, not building
  a new summary.
- CLOSE-03 is the precondition for Phase 11's honest aggregation: the
  `goalId: chunk.goalId ?? ''` sites currently drop commitment time, and the summary
  screen explicitly `continue`s past empty goalIds. Logging a real `commitmentId`
  unblocks correct quarterly totals.
- The `deferred` `CompletionEvent` and the `isDeferred` chunk flag were both laid
  down in earlier phases specifically for this phase — wire them, don't re-invent.

</specifics>

<deferred>
## Deferred Ideas

- Quarterly review counting commitment time correctly in charts/donut totals →
  Phase 11 (REVIEW-01). This phase only makes the underlying log correct.
- A configurable evening-reminder time picker (this phase ships a fixed default).
- Multi-day deferral backlog / "snooze N times then drop" policy (this phase is
  single-hop carryover only).
- User-pinned specific days/times for commitments and habits → future milestone.

</deferred>

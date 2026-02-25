# Canopy — Roadmap

**Created:** 2026-02-24
**Milestone:** 1 (v1 — Core Product Loop)
**Depth:** Comprehensive

---

## Executive Summary

Canopy delivers a personal daily scheduler that closes the full loop from quarterly goal-setting through morning mood check-in and schedule generation to daily chunk execution and retrospective review. The core differentiator is a deterministic, rule-based scheduling engine that is auditable, offline-first, and free — positioned against AI schedulers that are opaque and cloud-dependent.

The loop that must work first: **morning mood tap → schedule generation → chunk completion tracking.** Every phase builds toward or extends that loop.

Six phases across one milestone. Phases 1 through 4 deliver the working product. Phase 5 adds the long-horizon value proposition (quarterly review). Phase 6 makes the experience genuinely good on desktop and Web, not merely functional.

Key non-negotiable constraints carried through all phases:
- No AI API calls — rule-based scheduling only
- Local storage only — no backend, no sync
- All six Flutter platforms (iOS, Android, Web, Windows, macOS, Linux)
- Provider introduced at Phase 2; setState-only in Phase 1

---

## Phases

- [x] **Phase 1: Foundation** — Database, routing, Provider scaffold, and migration runner — no user-visible features (completed 2026-02-25)
- [ ] **Phase 2: Goals and Commitments** — Three goal types CRUD, CommitmentBlock CRUD, three-screen onboarding
- [ ] **Phase 3: Schedule Generation and Morning Check-In** — Mood check-in, rule-based schedule generation, schedule display UI
- [ ] **Phase 4: Chunk Tracking and Notifications** — Swipe completion, CompletionLog, local notifications, data export
- [ ] **Phase 5: Quarterly Review** — Aggregation, fl_chart visualizations, guided reflection, QuarterlySnapshot
- [ ] **Phase 6: Desktop and Web Polish** — Adaptive layouts, hover states, window constraints, Web URL and notification fallbacks

---

## Phase Details

### Phase 1: Foundation

**Goal:** The project skeleton is in place — persistence, routing, and state management scaffolding are established so every subsequent phase builds on solid ground without revisiting architectural decisions.

**Depends on:** Nothing (first phase)

**Requirements covered:**
- Implicit foundation for all eight active requirements — no requirement can be implemented without this layer

**Plans:** 4/4 plans complete

Plans:
- [x] 01-01-PLAN.md — Add dependencies, create project directory scaffold, minimal main.dart
- [ ] 01-02-PLAN.md — Hive entity models (7 entities) + build_runner TypeAdapter generation
- [ ] 01-03-PLAN.md — go_router with StatefulShellRoute, 6 stub screens, 4 ChangeNotifier stubs
- [ ] 01-04-PLAN.md — Repository interfaces/stubs, database init, migration runner, main.dart wiring, unit tests

**Deliverables:**
- Database package selected (Isar if pub.dev score is high and commits are recent; hive_ce otherwise) and schema files created for all entities: Goal, CommitmentBlock, DailySchedule (with embedded ScheduledChunk list), CompletionLog, QuarterlySnapshot, AppSettings
- Repository interfaces written (abstract classes) with one concrete implementation per entity — all other phases depend on these interfaces, not implementations
- Migration runner in place so schema changes can be applied without data loss as the app evolves
- go_router installed and configured with stub routes for every screen that will exist (home, onboarding, goals, schedule, quarterly review, settings) — routes return placeholder widgets
- MultiProvider at app root with three empty ChangeNotifiers: GoalsNotifier, ScheduleNotifier, SettingsNotifier
- shared_preferences wired for primitive settings (morning notification time, onboarding complete flag)
- uuid and intl packages installed; all time stored as UTC integers (minutes from midnight) from the start

**Key technical decisions:**
- Isar vs hive_ce must be decided at the start of this phase by checking pub.dev. This is the one decision that cannot be deferred — it affects every schema file written in Phase 2 onward.
- sqflite is eliminated regardless of Isar status — no native Web support.
- All entity IDs use UUID v4 strings, not auto-increment integers — compatible with eventual sync in v2.
- go_router stubs must be added now even though only one screen exists. Retrofitting go_router after multiple screens exist using MaterialApp named routes is a painful migration, especially for Web URL support.

**Risk:** Choosing the wrong database. Mitigation: check Isar pub.dev at day one of Phase 1. A well-defined repository interface means the concrete implementation can be swapped with minimal blast radius if the initial choice is wrong.

**Acceptance criteria:**
1. `flutter run` on Android, iOS, Web, and Windows produces a blank screen with no errors and no deprecation warnings in the console
2. The database initializes on first launch and the migration runner runs without errors on subsequent launches
3. All repository interfaces have at least one method stub and a passing unit test that calls the stub against an in-memory implementation
4. go_router is routing between at least two placeholder screens — the stub route table is the source of truth for all screens that will exist
5. `flutter analyze` reports zero issues

---

### Phase 2: Goals and Commitments

**Goal:** Users can define the inputs the scheduling algorithm needs — their goals across all three types and any fixed commitment blocks — through a UI that does not expose internal taxonomic vocabulary.

**Depends on:** Phase 1

**Requirements covered:**
- User can define fixed commitment blocks that are always scheduled regardless of mood
- User can set up goals across three types: time-target, outcome-focused, and habits/routines

**Deliverables:**
- Goal model fully implemented: name, type (time-target / outcome / habit — internal enum, never shown in UI), color, priority weight, weekly hour budget (time-target), deadline and outcome description (outcome), frequency and streak count (habit); soft-delete (archive) only — no hard delete
- CommitmentBlock model: name, days of week, start time (minutes from midnight UTC), end time, color; commitment blocks are chunked automatically within their window at schedule generation time
- GoalsNotifier and SettingsNotifier wired end-to-end — UI reads from and writes to Provider; no setState in goal/commitment screens
- Goals list screen: shows all active goals grouped by type with visual type indicator; archive and reorder supported
- Add/Edit Goal bottom sheet: plain-language type picker ("I want to spend regular time on something" / "I'm working toward a specific outcome" / "I want to build a daily habit") — goal type taxonomy labels never appear
- CommitmentBlock list screen and Add/Edit CommitmentBlock sheet
- Three-screen onboarding flow that completes in under 90 seconds and seeds the first goal and optionally the first commitment block:
  - Screen 1: "What is the one thing you most want to make time for?" — creates first goal, plain-language type picker
  - Screen 2: "Do you have a regular job or fixed commitment?" — creates CommitmentBlock or skips
  - Screen 3: "Is there anything you do every morning we should protect?" — creates first habit or skips
- Onboarding is skippable; skipping sets sensible defaults and marks onboarding complete
- REQUIREMENTS.md traceability updated with phase mapping

**Key technical decisions:**
- Goal type mutual exclusivity enforced in UI (single-select picker). A goal cannot be both a habit and a time-target. This is the app's opinion; the picker enforces it.
- Onboarding must not mention "time-target", "outcome", or "habit" as labels. Plain-language descriptions only. The internal enum is a Dart implementation detail.
- Dormant goal handling (no activity 3+ weeks): silently deprioritized in scheduling. Not surfaced until Phase 5 quarterly review. No UI change needed in this phase.

**Risk:** Onboarding taking more than 90 seconds. Mitigation: time the flow manually before the phase closes. If Screen 3 is causing friction, make it skippable with a single tap (it already is — enforce that the skip affordance is prominent).

**Acceptance criteria:**
1. User can create a goal of each type (time-target, outcome, habit) through the plain-language picker and the goal appears in the goals list with a visual type indicator
2. User can create a CommitmentBlock with a name, days of week, and time window, and it persists across app restarts
3. User can edit and archive any goal; archived goals do not appear in the main list but are accessible in an "Archived" section
4. The three-screen onboarding flow can be completed start to finish, including skipping all optional fields, in under 90 seconds — tested on a physical or simulated device
5. Completing or skipping onboarding sets the onboarding-complete flag in shared_preferences so the flow does not re-appear on subsequent launches

---

### Phase 3: Schedule Generation and Morning Check-In

**Goal:** The core product loop is usable for the first time — the user taps their mood each morning and receives a deterministic, rule-based daily schedule that reflects their commitments, goals, and energy level.

**Depends on:** Phase 2

**Requirements covered:**
- App generates a daily schedule of Chunks (25-min focused sessions) each morning based on commitments, goals, and priorities
- Schedule includes automatic 5-min short breaks after each chunk and a 25-min long break after every 3 chunks (mood 1–2) or 4 chunks (mood 3–5); breaks shown explicitly in the schedule
- Morning check-in asks how the user is feeling; mood controls discretionary chunk count only; commitment blocks are always present; mood 1–2 triggers a reduced discretionary schedule
- Schedule generation is rule-based (no AI API dependency in v1)

**Deliverables:**
- Schedule generation algorithm — pure Dart, synchronous, no async, completes in under 1 second:
  - Allocation sequence (fixed): (1) commitment blocks, (2) habits, (3) outcome goals by urgency score (priority_weight × chunks_remaining / days_remaining), (4) time-target goals (most behind weekly budget first), (5) leave 20% of discretionary capacity unscheduled
  - Capacity table: Mood 1 = 5–6 chunks, Mood 2 = 7–8, Mood 3 = 9–10, Mood 4 = 11–12, Mood 5 = 13–14; hard cap 16, minimum 3; schedule only 80% of discretionary capacity
  - Mood 1–2 "just survive today" mode: discretionary reduces to habits only — outcome and time-target goals are excluded unless critical (deadline today)
  - Break insertion: 5-min short break after every work chunk; 25-min long break after every 3 work chunks (mood 1–2) or 4 work chunks (mood 3–5); both break types stored as ScheduledChunk with null goalId and explicit chunk type (shortBreak / longBreak)
  - Each ScheduledChunk has a one-line rationale string explaining why it was scheduled (e.g., "Streak active — 12 days", "Deadline in 3 days")
  - Commitment blocks chunked into 25-min ScheduledChunks within their time window, with times anchored to the block's start
- DailySchedule entity persisted via ScheduleNotifier after generation; regeneration replaces today's schedule
- Mood check-in screen: five emoji tap targets (no numbers), no pre-selection, single-screen, completes in under 30 seconds; mood 1–2 shows one follow-up toggle "Want a lighter day?" defaulting to Yes; after selection, one-line acknowledgment is shown before navigating to the schedule
- Schedule screen: vertical card list (not a timeline); each card shows goal name (large/bold), left-edge color bar (4–6dp, goal color), duration label, rationale text, status icon; no clock times shown unless the chunk is anchored to a commitment block; 3–4 chunks visible without scrolling on a standard phone
- Break cards visually lighter than work cards; short break cards compact (~48dp height); long break cards match work card height
- Progress bar at top of schedule: "X of Y Chunks" — always above the fold
- Completed chunks render in a desaturated "done" state; they stay in position (not removed)
- ScheduleNotifier wired end-to-end

**Key technical decisions:**
- Schedule display is a vertical card list, not a timeline. Clock times are shown only on commitment-anchored chunks. Showing clock times on discretionary chunks implies a false rigidity.
- Short breaks auto-advance only if the user taps "Done" on the preceding work chunk in v1. No timer. This eliminates the need for the app to remain active or use background execution.
- Long breaks are dismissible early with a single tap. No "complete" action required for either break type.
- The algorithm is deterministic — given the same inputs it produces the same output. This is the auditability guarantee. Randomness is not introduced.
- "Just survive today" mode is silent — the app does not label it. The acknowledgment text after check-in ("Lighter day — X Chunks") communicates it without clinical framing.

**Risk:** Algorithm calibration. The chunk count thresholds per mood are well-reasoned but not empirically validated. Mitigation: start using the app daily immediately after Phase 3 ships and adjust thresholds based on real experience before Phase 5.

**Acceptance criteria:**
1. Tapping a mood emoji on the check-in screen generates a daily schedule and navigates to the schedule screen within 1 second — measured on a mid-range Android device
2. The generated schedule contains commitment block chunks at the correct anchored times regardless of mood selected
3. Selecting mood 1 or 2 produces a schedule with habits only in the discretionary slots (no outcome or time-target goal chunks, except goals with a deadline of today)
4. Break chunks appear in the correct positions — a 5-min short break follows every work chunk; a 25-min long break appears after every 3 chunks on mood 1–2 or every 4 chunks on mood 3–5
5. The schedule persists across app restarts — relaunching the app on the same day shows the morning's generated schedule, not a blank screen

---

### Phase 4: Chunk Tracking and Notifications

**Goal:** The daily loop closes — users can mark chunks complete or skipped throughout the day, receive a morning notification to start their day, and export their data.

**Depends on:** Phase 3

**Requirements covered:**
- User can track which Chunks they complete throughout the day

**Deliverables:**
- Swipe gestures on schedule cards: swipe right to complete, swipe left to skip; tap opens a detail/edit bottom sheet
- CompletionLog: append-only event log (event sourcing pattern) — each entry records chunk ID, goal ID, date, event type (completed / skipped / deferred), timestamp; CompletionLog records are never mutated or deleted
- Skipped chunks move to a collapsed "Skipped today" section at the bottom of the schedule list (not removed from view)
- End-of-day summary screen: chunks completed vs. scheduled, per-goal breakdown, "See you tomorrow" close button
- Morning notification via flutter_local_notifications + timezone: one daily notification at user-configured time (default 7:30am); on tap, app opens and schedule generation runs synchronously on launch
- iOS notification permission requested after the user completes their first successful mood check-in — not at app launch
- Web notification fallback: persistent in-app banner shown when app is opened with no schedule for today (Web has no local notification support)
- Mid-day nudge notification: opt-in only (default off), configurable time in settings (default 12:00pm)
- Data export: JSON export of all CompletionLog records; accessible from settings screen; produces a timestamped JSON file with all historical data

**Key technical decisions:**
- CompletionLog is strictly append-only. Mutating historical records would corrupt the retrospective data that Phase 5 depends on.
- iOS notification permission is requested after the first check-in, not at launch. Requesting at launch before the user understands the app's value reduces grant rates.
- Mid-day notifications default to opt-in (not opt-out). Mid-day nudges correlate with both engagement and uninstall rates; opt-in is safer for a personal tool.
- Export format is JSON in v1. CSV can be added later; JSON is complete and reversible.
- Desktop/Web completion interaction: checkbox visible on hover; drag handle always visible for reorder. ReorderableListView handles long-press drag on mobile.

**Risk:** Notification cross-platform reliability. iOS restricts background execution; Web has no local notification API. Mitigation: the notification-triggered generation pattern (app opens on tap → generation runs synchronously) avoids background execution entirely. The Web banner fallback covers the Web gap.

**Acceptance criteria:**
1. Swiping right on a work chunk card marks it complete, renders it in a desaturated "done" state, and appends a CompletionLog entry — verified by reading the log from the database
2. Swiping left on a work chunk moves it to the "Skipped today" collapsed section at the bottom of the schedule
3. A local notification fires at the configured morning time on Android and iOS; tapping it opens the app to the mood check-in screen
4. The Web app shows a persistent in-app banner prompting the user to start their check-in when no schedule has been generated for the current day
5. Tapping "Export data" in settings produces a JSON file containing all CompletionLog entries and downloads or shares it without error on at least two platforms (Android and Web)

---

### Phase 5: Quarterly Review

**Goal:** Users gain visibility into how their time was actually spent over the past quarter and can update their goals and priorities for the next quarter through a data-first, guided reflection flow.

**Depends on:** Phase 4

**Requirements covered:**
- App performs a quarterly review: data summary + guided reflection to help user adjust goals and priorities

**Deliverables:**
- CompletionLog aggregation layer: functions to aggregate CompletionLog into per-goal totals, per-week chunk counts, completion rates, and streak records over a configurable date range
- QuarterlySnapshot entity: persisted record of each quarterly review — date, goal totals, reflection answers, next-quarter priority adjustments; append-only (no overwriting past snapshots)
- fl_chart integration:
  - Donut chart: time by goal (% of completed chunks per goal) — no interaction, data display only
  - Bar chart: completed chunks per week over the quarter
- Quarterly review flow (three sections, one continuous scroll or paged):
  - Section 1 (data): donut chart, bar chart, top 3 goals by time spent — no user interaction required, full value from viewing alone
  - Section 2 (reflection): 3–5 guided questions shown one per screen with tap-to-answer; questions are fixed in v1 (e.g., "Which goal gave you the most energy?", "Which goal felt like a chore?", "What would you change about how you spent your time?")
  - Section 3 (adjustments): confirm or change goal priorities for next quarter based on Section 2 answers — updates GoalsNotifier priorities
- Review trigger: prominent entry point in the home/schedule screen shown when the current date is within the last week of a 90-day period since onboarding or last review
- Tone: celebratory, not evaluative — language is "Here's what you built" not "Here's what you missed"
- Skipped chunks counted as "time not spent" in aggregation and surfaced explicitly in the review — the data is transparent

**Key technical decisions:**
- fl_chart is not introduced until this phase. Charts in earlier phases were not needed and would have added dependency weight during the phases where iteration is fastest.
- QuarterlySnapshot is append-only. Past reflections are historical records, not editable data.
- The guided question set is fixed in v1. Configurable questions are a v2 consideration (OQ-13). A fixed set ships faster and can be refined based on actual use.
- Skipped chunks are counted as not done in aggregation. Excluding them would make the data less honest.

**Risk:** Quarterly review UX needing iteration. The data-first pattern is clear, but the question set and chart layout will need refinement after first use. Mitigation: the entire flow is self-contained — the question set can be updated without schema changes.

**Acceptance criteria:**
1. The quarterly review entry point appears on the schedule/home screen when the current date is within 7 days of the 90-day review window
2. Section 1 displays a donut chart and bar chart populated with real CompletionLog data — not placeholder data
3. The full reflection flow (Sections 1, 2, and 3) can be completed in under 5 minutes, verified by a manual walkthrough
4. Completing Section 3 updates goal priorities in GoalsNotifier and those updated priorities are reflected in the next morning's schedule generation
5. A QuarterlySnapshot record is persisted after the review is completed and is visible in a "Past reviews" list accessible from settings

---

### Phase 6: Desktop and Web Polish

**Goal:** Canopy is genuinely good on Windows and Web — layouts adapt to large screens, mouse interactions work correctly, window constraints prevent layout breakage, and Web URLs navigate correctly.

**Depends on:** Phase 5

**Requirements covered:**
- Implicit: all active requirements apply to all six Flutter platforms; this phase ensures the desktop and Web experience meets the same standard as mobile

**Deliverables:**
- LayoutBuilder adaptive layouts: two-column layout on screens wider than 720dp (navigation rail + content); single-column on mobile; schedule card list fills available width correctly at all breakpoints
- Hover states on desktop: chunk cards show checkbox and drag handle on hover; goal list items show edit/archive actions on hover; no hover state exists on touch targets on mobile
- Drag handle always visible on desktop for ReorderableListView; long-press-only on mobile
- window_manager package: minimum window size set to 480×640 on Windows, macOS, and Linux — prevents layout collapse below usable width
- go_router Web URL verification: each screen has a correct, bookmarkable URL; navigating directly to a URL (e.g., `/schedule`, `/goals`, `/review`) loads the correct screen with correct state
- Web notification fallback: persistent in-app banner (already built in Phase 4) verified as the only notification mechanism on Web — no attempt to use the Web Push API in v1
- Mouse/touch interaction parity: all swipe actions on mobile have a non-swipe equivalent on desktop (checkbox for complete, context menu or button for skip)
- Widget tests for LayoutBuilder breakpoints verifying correct layout at 480dp, 720dp, and 1200dp widths

**Key technical decisions:**
- Two-column layout threshold is 720dp (logical pixels). Below this, single-column. This covers most tablet portrait orientations in the single-column bucket, which is intentional — the schedule card list reads better in single-column.
- window_manager is added only for desktop targets (Windows, macOS, Linux). It is not imported on mobile or Web — conditional imports or platform checks required.
- Web Push API is not used in v1. The in-app banner is sufficient and avoids the permission and service worker complexity.

**Risk:** Layout assumptions baked into Phase 1–5 widgets being hard to retrofit. Mitigation: Phase 6 is explicitly planned (not an afterthought) and LayoutBuilder wrapping is low-risk incremental work. The risk is time, not correctness.

**Acceptance criteria:**
1. On a 1280×800 desktop window (Windows or macOS), the app renders a two-column layout with a navigation rail on the left and content on the right — no overflow errors in the console
2. Hovering over a chunk card on desktop reveals a checkbox and drag handle without a click; removing the mouse restores the default card state
3. The minimum window size constraint prevents resizing below 480px width on Windows — the window snaps back or refuses to resize below the minimum
4. Navigating directly to `/schedule` and `/goals` in a Web browser loads the correct screen without a 404 or blank white screen
5. All existing widget tests pass; new LayoutBuilder breakpoint tests pass at 480dp, 720dp, and 1200dp

---

## Progress Table

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 4/4 | Complete   | 2026-02-25 |
| 2. Goals and Commitments | 0/0 | Not started | - |
| 3. Schedule Generation and Morning Check-In | 0/0 | Not started | - |
| 4. Chunk Tracking and Notifications | 0/0 | Not started | - |
| 5. Quarterly Review | 0/0 | Not started | - |
| 6. Desktop and Web Polish | 0/0 | Not started | - |

---

## Open Questions

These questions from research must be resolved before the phase they affect. They are recorded here so `/gsd:plan-phase` can surface them at the right time.

| ID | Question | Resolve Before | Recommendation |
|----|----------|----------------|----------------|
| OQ-1 | Isar vs hive_ce — check pub.dev maintenance status | Phase 1 | Isar if active; hive_ce otherwise |
| OQ-2 | Export format — JSON only or JSON + CSV | Phase 1 | JSON-first; CSV addable later without schema changes |
| OQ-3 | Goal type mutual exclusivity — enforce in UI? | Phase 2 | Yes — single-select type picker |
| OQ-4 | Dormant goal handling (3+ weeks no activity) | Phase 2 | Silent deprioritization in scheduling; surface in Phase 5 review |
| OQ-5 | Ordered vs. unordered daily chunk list | Phase 3 | Default priority order; full reorder always available |
| OQ-6 | Short break auto-advance mechanism | Phase 3 | Auto-advance only after user taps Done on preceding chunk; no timer |
| OQ-7 | "Just survive today" mode — named or silent | Phase 3 | Silent; acknowledgment text communicates it |
| OQ-8 | Recovery/wellness chunk sizing (10-min walks, etc.) | Phase 3 | Schedule as full 25-min chunk in v1; revisit post-launch |
| OQ-9 | Skipped chunks in quarterly review — count as not done? | Phase 4 | Yes — count as not done; surface explicitly |
| OQ-10 | Mid-day nudge opt-in vs opt-out default | Phase 4 | Opt-in (default off) |
| OQ-11 | Notification time defaults | Phase 4 | Morning 7:30am; end-of-day 9:00pm |

---

## Coverage Map

All eight active requirements from PROJECT.md are mapped to exactly one phase. No orphaned requirements.

| Requirement | Phase |
|-------------|-------|
| Fixed commitment blocks always scheduled regardless of mood | Phase 2 (defined), Phase 3 (scheduled) |
| Three goal types: time-target, outcome, habit | Phase 2 |
| Daily Chunk schedule generated each morning | Phase 3 |
| Break structure: 5-min short, 25-min long, mood-adaptive cadence | Phase 3 |
| Morning mood check-in controls discretionary chunk count; mood 1–2 triggers reduced schedule | Phase 3 |
| User can track which Chunks they complete | Phase 4 |
| Quarterly review: data summary + guided reflection | Phase 5 |
| Schedule generation is rule-based (no AI API) | Phase 3 |

Note: Commitment blocks are defined in Phase 2 and their scheduling logic is implemented in Phase 3. Both phases are required; the requirement is assigned to Phase 2 (definition) as the primary mapping since Phase 3 consumes what Phase 2 produces.

# Phase 3: Schedule Generation and Morning Check-In - Context

**Gathered:** 2026-03-23
**Status:** Ready for planning

<domain>
## Phase Boundary

The core product loop becomes usable for the first time: the user taps their mood each morning and receives a deterministic, rule-based daily schedule that reflects their commitments, goals, and energy level. Chunk tracking (swipe complete/skip), notifications, and data export are Phase 4. Desktop/Web polish is Phase 6.

</domain>

<decisions>
## Implementation Decisions

### Morning entry flow
- Schedule tab shows an empty state with a "Start your day" button when no schedule exists for today — check-in launches from there as a full-screen pushed route (bottom nav remains accessible but hidden during check-in)
- Check-in is a full-screen route pushed from the Schedule tab; after generation it pops back to the schedule
- Regenerating (tap check-in again on a day with an existing schedule): silent replace — no confirmation dialog
- Home tab shows today's summary after schedule is generated: progress bar, today's mood emoji, and the next upcoming chunk name + duration

### Mood check-in screen
- Weather/nature metaphor emojis for the 5 moods: 🌧️ (1, stormy) · 🌥️ (2, overcast) · ⛅ (3, partly cloudy) · 🌤️ (4, clearing) · ☀️ (5, sunny)
- Visual tone: playful and colorful, mood-adaptive — tapping an emoji immediately shifts the screen's background tint to that mood's palette color
- Color palette (also used for progress bar / AppBar accent on the schedule screen):
  - Mood 1: #4A6275 (steel blue-grey)
  - Mood 2: #5C7A8A (slate)
  - Mood 3: #4A8C7A (muted teal)
  - Mood 4: #7AAF6A (soft green)
  - Mood 5: #E8C547 (warm amber)
- Mood color kicks in on tap (not hover/browse); no animation needed in Phase 3

### Post-check-in acknowledgment
- Acknowledgment screen uses weather-themed copy matching the emoji set:
  - Mood 1: "Stormy day — keeping it light. X chunks."
  - Mood 2: "Overcast — gentle pace. X chunks."
  - Mood 3: "Partly cloudy — steady. X chunks."
  - Mood 4: "Clearing up — good flow. X chunks."
  - Mood 5: "Clear skies — let's go. X chunks."
- Acknowledgment shows chunk count + name of the first work chunk (e.g. "…starting with Writing")
- Mood 1–2 follow-up toggle "Want a lighter day?" (default Yes) shows before the acknowledgment — as spec'd in ROADMAP
- Dismiss: user swipes up to reveal the schedule (acknowledgment slides up, schedule peeks from below)

### Chunk card visual states
- **Done state:** color bar desaturates to grey, text fades to ~50% opacity, checkmark icon replaces the status icon; card stays in position (not removed or collapsed)
- **Short break card:** compact strip (~48dp), no color bar, soft background tint, pause icon ⏸, no rationale text
- **Long break card:** full work-card height, neutral/white surface, no color bar, coffee icon ☕, no rationale text
- **Mood color on schedule screen:** subtle accent only — progress bar and AppBar tint use today's mood color; chunk cards themselves stay neutral (white/surface) to avoid clashing with goal color bars

### Claude's Discretion
- Exact wording/punctuation of the empty-state copy on the Schedule tab ("Start your day" button label, subtitle)
- Home screen summary layout details (spacing, secondary stats shown)
- Exact opacity value for faded "done" text (aim for ~50% but adjust for legibility)
- Short break background tint color (can derive from mood color at low opacity, or use a neutral surface variant)
- Animation curve for the swipe-up reveal from acknowledgment to schedule

</decisions>

<specifics>
## Specific Ideas

- The weather metaphor should feel cohesive end-to-end: emojis on check-in → weather-themed acknowledgment text → mood color accent on schedule. The metaphor is the identity of the morning ritual.
- "The entire app reflecting the mood look as the day passes" — user explicitly wants this but is deferring to Phase 6. The palette defined here (#4A6275 → #E8C547) is the foundation for that future feature.
- Acknowledgment + swipe-up: this is a deliberate gesture-as-transition moment. Should feel satisfying, not mechanical. The schedule "peeks" from below as the acknowledgment lifts.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `GoalCard` (`lib/screens/goals/widgets/goal_card.dart`): Establishes the colored left bar (5dp, `Positioned`) + rounded card (12dp) pattern. Schedule chunk cards should follow the same structural pattern.
- `hexToColor()` helper in `goal_card.dart`: Already converts hex strings to Flutter Colors — reuse for mood palette and goal color bars on chunk cards.
- `ScheduledChunk` model: Already has `chunkTypeIndex`, `goalId`, `anchoredStartMinutes`, `rationale`, `isCompleted`, `isSkipped` — all fields Phase 3 needs are in place.
- `DailySchedule` model: `dateYmd`, `moodIndex`, `chunks` list, `generatedAt` — entity is complete.
- `ScheduleNotifier` (`lib/providers/schedule_notifier.dart`): Stub ready to fill out.
- `ScheduleScreen` (`lib/screens/schedule/schedule_screen.dart`): Stub ready to replace.

### Established Patterns
- Provider/ChangeNotifier: `GoalsNotifier` and `CommitmentsNotifier` are the reference implementations — `ScheduleNotifier` follows the same pattern
- Bottom sheet with `DraggableScrollableSheet`: used in goal/commitment forms — check-in is a pushed route (not a sheet), so this pattern doesn't apply here
- Enum stored as int index (`chunkTypeIndex`): already baked into `ScheduledChunk` — the algorithm uses `ChunkType.values[index]`
- `hive_ce` persistence: `DailyScheduleRepository` interface and `HiveDailyScheduleRepository` implementation are already scaffolded

### Integration Points
- `GoalsNotifier`: schedule algorithm reads active goals (non-archived) — needs `goals` getter
- `CommitmentsNotifier`: algorithm reads commitment blocks to anchor chunks — needs `blocks` getter
- `SettingsNotifier`: reads `moodIndex` stored in `AppSettings` (if persisted) and onboarding-complete flag
- `router.dart`: check-in screen needs a `/checkin` route pushed from within the Schedule tab branch; acknowledgment can be a sub-route or handled inline on the check-in screen

</code_context>

<deferred>
## Deferred Ideas

- Full app mood theming throughout the day — user wants the entire app's color scheme to reflect the morning mood and evolve as the day progresses. Explicitly deferred to Phase 6 polish. The mood palette defined here (#4A6275 → #E8C547) is the foundation.

</deferred>

---

*Phase: 03-schedule-generation-and-morning-check-in*
*Context gathered: 2026-03-23*

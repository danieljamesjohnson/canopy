---
phase: 22-unified-today-screen
plan: 03
type: execute
wave: 2
depends_on: ["22-01", "22-02"]
files_modified:
  - lib/screens/today/today_screen.dart
  - lib/screens/today/widgets/breathing_pulse_cta.dart
  - lib/screens/home/home_screen.dart
  - test/screens/home_screen_breathing_pulse_test.dart
  - test/screens/today_screen_test.dart
autonomous: true
requirements: [UNIFY-01]
must_haves:
  truths:
    - "One screen shows what is happening now AND the rest of the day, in a single scrollable list, without switching tabs"
    - "The current activity swells in place at its own clock position — there is no separate now card, hero, or sticky bar"
    - "On open, the list scrolls the current row to centre, and never yanks the list again while the user reads"
    - "Free time is named in the list; gaps under 10 minutes stay quiet"
    - "The pre-start, between-activities and day-complete copy that shipped on Home survives the merge word for word"
    - "The merged screen has no 'See full schedule' affordance — it would link to itself"
    - "The empty state keeps every affordance from BOTH old screens: the breathing-pulse Start-your-day CTA, Add an event, the web check-in banner, and the review banner"
  artifacts:
    - path: "lib/screens/today/today_screen.dart"
      provides: "TodayScreen — the merged destination: header, mood chip, edge-state line, day timeline, live row, empty state, AppBar actions"
      contains: "class TodayScreen"
      min_lines: 380
    - path: "lib/screens/today/widgets/breathing_pulse_cta.dart"
      provides: "BreathingPulseCta lifted out of home_screen.dart so it survives that file's deletion"
      contains: "class BreathingPulseCta"
      min_lines: 100
    - path: "test/screens/today_screen_test.dart"
      provides: "Widget coverage for the merged screen: single list, live row placement, free rows, edge states, empty state, 720dp, no self-link"
      contains: "TodayScreen"
  key_links:
    - from: "lib/screens/today/today_screen.dart"
      to: "lib/screens/today/timeline.dart"
      via: "buildTimeline(chunks, nowState) drives every row"
      pattern: "buildTimeline"
    - from: "lib/screens/today/today_screen.dart"
      to: "lib/screens/today/now_state.dart"
      via: "resolveNowState is the only clock read on the screen"
      pattern: "resolveNowState"
    - from: "lib/screens/today/today_screen.dart"
      to: "lib/screens/today/widgets/live_row_card.dart"
      via: "the isLive row renders LiveRowCard with screen-computed kicker/remaining/next strings"
      pattern: "LiveRowCard"
    - from: "lib/screens/today/today_screen.dart"
      to: "lib/widgets/adaptive_form_modal.dart"
      via: "Add-an-event keeps routing through showAdaptiveFormModal (RESP-01/02/03)"
      pattern: "showAdaptiveFormModal"
---

<objective>
Build `TodayScreen` — the single destination that replaces Home and Schedule. It composes plan
22-01's model and plan 22-02's rows into the layout locked by 22-UI-SPEC.md, and it is the
deliverable behind UNIFY-01.

Purpose: this is the merge itself. Every duplicated responsibility across the two old screens
(AppBar refresh action, ScheduleProgressBar, goal lookups, empty state) resolves here to exactly
one implementation, and the two old screens become dead code that plan 22-04 removes.

Output: `lib/screens/today/today_screen.dart`, `BreathingPulseCta` lifted into its own file so it
survives home_screen.dart's deletion, and a widget test file covering the merged surface. The
screen is fully built and independently testable in this plan but is NOT yet wired into the
router — that switch is plan 22-04, so this plan can land without breaking a single existing test.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/22-unified-today-screen/22-CONTEXT.md
@.planning/phases/22-unified-today-screen/22-UI-SPEC.md
@.planning/phases/22-unified-today-screen/22-PATTERNS.md

@lib/screens/home/home_screen.dart
@lib/screens/schedule/schedule_screen.dart
@lib/screens/today/now_state.dart
@lib/screens/today/timeline.dart
@lib/screens/today/widgets/timeline_row_tile.dart
@lib/screens/today/widgets/free_time_row.dart
@lib/screens/today/widgets/live_row_card.dart
@test/screens/home_screen_now_state_test.dart
@test/test_helpers/viewport.dart
</context>

<decision_ids>
Decision IDs D-01 through D-09 and the plan set's multi-source coverage audit live in
`22-01-now-state-and-timeline-model-PLAN.md`. This plan implements **D-01** (one scrollable list,
no hero), **D-02** (auto-scroll the current row to centre on open), **D-03** (no sticky recall
bar — an explicit negative gate below), **D-05** (free rows in the list), **D-07** (mood theming),
and the first half of **D-08** (the merged screen carries no "see full schedule" affordance).

**Destination naming, decided in plan 22-01:** label "Today", route `/today`, directory
`lib/screens/today/`. The AppBar title stays "Canopy" (app chrome, as HomeScreen had it) and the
in-body header carries "Today" plus the date, per 22-UI-SPEC.md "Structure" — the header is a body
element, not an AppBar title, and not a collapsing app bar.
</decision_ids>

<scope_boundary>
**Phase 23 lives next door. Do not build it, do not delete its inputs.**

- LIVE-01 (a running break reads as a break): `showActions` on LiveRowCard is already wired from
  the chunk type, and `resolveNowState` still filters to work chunks. Phase 23 widens the filter.
  Do NOT widen it here.
- LIVE-02 (visible countdown): this screen renders the remaining-time LINE at the granularity of
  the EXISTING one-minute ticker. Do not add a second, faster timer — that granularity choice is
  explicitly Phase 23's per ROADMAP.md's "Open design decision for phase planning".
- LIVE-03 (honest edge states survive the merge): the pre-start, gap and day-complete copy from
  home_screen.dart lines 542-667 is carried across **verbatim**. Rewording it is Phase 23's call,
  not this plan's. Deleting it would break LIVE-03 before Phase 23 starts.

**Not in this plan at all:** the router, the shell, and the deletion of the old screens. This plan
adds files and leaves `/home` and `/schedule` working exactly as they do today.
</scope_boundary>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Screen scaffold — state, lookups, AppBar, reconciled empty state (P3, P4, P11, P12, P13)</name>
  <files>lib/screens/today/today_screen.dart, lib/screens/today/widgets/breathing_pulse_cta.dart, lib/screens/home/home_screen.dart, test/screens/home_screen_breathing_pulse_test.dart, test/screens/today_screen_test.dart</files>
  <read_first>
    - home_screen.dart lines 202-330 — _HomeScreenState: the injectable _nowFn seam, the one-minute Timer.periodic + lifecycle pause/resume (T-17-01 mitigation), _checkReviewWindow, the _lastScheduleDateYmd reset in didChangeDependencies, and the two mood maps
    - home_screen.dart lines 669-725 — Home's empty state: ReviewBanner gate, 720dp Align/ConstrainedBox, "No schedule yet" copy, BreathingPulseCta around the CTA
    - home_screen.dart lines 728-848 — the BreathingPulseCta class to lift out whole, including the WR-01 accessibility-observer notes
    - schedule_screen.dart lines 51-98 — the fuller AppBar action set (add event, re-check-in, start focus, the ratio-gated "View your day" popup) and _resolvedWorkChunkRatio at 246-257
    - schedule_screen.dart lines 316-424 — the _resolveGoal family (five derived lookups), _toDisplayRationale, _openDetailSheet, _openAddEvent
    - schedule_screen.dart lines 426-494 — Schedule's empty state: the kIsWeb MaterialBanner, the sun icon, the "Plan your day in 30 seconds." copy, and the "Add an event" TextButton
    - 22-PATTERNS.md section 1 — the duplication table that says which of each pair survives
  </read_first>
  <behavior>
    - Pumping TodayScreen with a ScheduleNotifier whose hasScheduleToday is false renders the
      empty state and does NOT throw (no Hive needed — _checkReviewWindow already swallows a
      missing box).
    - The empty state renders ALL of: the "Start your day" CTA wrapped in a BreathingPulseCta,
      an "Add an event" affordance, and the "Plan your day in 30 seconds." headline.
    - Tapping "Add an event" from the empty state opens a modal (find.byType(CommitmentFormSheet)
      after a pump) — proving addEventToday is reachable without a check-in.
    - At a 1024x768 viewport, the widget tree contains a ConstrainedBox with maxWidth 720.0
      (POLISH-01).
    - The AppBar exposes an Add-event action, a Re-check-in action and a Start-focus action, and
      exposes exactly ONE refresh IconButton (the two old screens each had one).
    - The screen accepts an injectable `now` function, exactly like HomeScreen did, so
      clock-anchored widget tests need no sleeping.
  </behavior>
  <action>
    Create `lib/screens/today/widgets/breathing_pulse_cta.dart` and move the whole
    BreathingPulseCta class (home_screen.dart lines 728-848) into it VERBATIM, keeping its doc
    comments and the WR-01 accessibility notes; only the import block changes. In
    `lib/screens/home/home_screen.dart` delete the class and add an import of
    `../today/widgets/breathing_pulse_cta.dart` so that screen keeps compiling until plan 22-04
    deletes it. Update the single import line in
    `test/screens/home_screen_breathing_pulse_test.dart` to the new path and change nothing else
    in that file.

    Create `lib/screens/today/today_screen.dart` with a public
    `TodayScreen extends StatefulWidget` taking an optional
    `final DateTime Function()? now;` clock seam (same signature and doc comment as
    HomeScreen's), and a `_TodayScreenState with WidgetsBindingObserver` that carries across from
    _HomeScreenState, unchanged in behaviour: the `late final _nowFn`, the one-minute
    `Timer.periodic` with `_startNowTimer`, `didChangeAppLifecycleState` pause/resume, the
    `dispose` cancel plus observer removal, `_checkReviewWindow` with its silent catch, and the
    `didChangeDependencies` reset of `_eodCardDismissed` keyed on `_lastScheduleDateYmd`. Carry
    the `_bannerDismissed`, `_eodCardDismissed`, `_inReviewWindow` and `_lastScheduleDateYmd`
    fields and the `_moodEmojis` map over as-is.

    Port the goal-lookup layer from schedule_screen, NOT from home_screen: `_resolveGoal` plus
    `_lookupGoalColor`, `_lookupGoalName`, `_lookupGoalPriorityWeight`, `_lookupGoalValence`,
    `_lookupGoalEmojiTag`, and the static `_toDisplayRationale`. Home's three-lookup subset is
    dropped — schedule's is a strict superset and the rows need all five (P3).

    Port `_resolvedWorkChunkRatio`, `_openDetailSheet` and `_openAddEvent` from schedule_screen
    verbatim. `_openAddEvent` must keep going through `showAdaptiveFormModal` — that is the
    Phase 18 RESP-01/02/03 inherited contract (P12) and swapping it for a plain
    showModalBottomSheet would silently regress desktop.

    Build the AppBar as the union of the two old ones, de-duplicated: `title: const Text('Canopy')`,
    then actions in this order — Add an event (Icons.add), Re-check-in (Icons.refresh, pushing
    `/schedule/checkin`, ONE instance not two), Start focus
    (Icons.center_focus_strong_outlined, pushing `/focus` with the first unresolved work chunk's
    id), and the PopupMenuButton "View your day" gated on `_resolvedWorkChunkRatio(schedule) >= 0.5`.
    Do NOT carry over schedule_screen's `backgroundColor: moodColor` /
    `foregroundColor: Colors.white` — a raw `Colors.white` violates the UI-SPEC colour rule, and
    mood still reads through the seeded theme, the progress bar and the header mood chip. This is
    a deliberate reconciliation, recorded in plan 22-01's source audit.

    Build the empty state as the union of BOTH old empty states — nothing from either is dropped
    (P4): the ReviewBanner gate from Home, the kIsWeb MaterialBanner from Schedule, Schedule's
    icon-plus-headline block ("Plan your day in 30 seconds." / "Tell us how you're feeling and
    we'll build your schedule.") with `Icons.wb_sunny_outlined` recoloured from `Colors.amber` to
    `theme.colorScheme.tertiary`, the primary CTA wrapped in `BreathingPulseCta(enabled: isPreCheckin)`
    from Home, and Schedule's "Add an event" TextButton.icon underneath. Wrap the whole body in
    Home's `Align(topCenter)` + `ConstrainedBox(maxWidth: 720)` (P13 / POLISH-01).

    Write the empty-state, modal-reachability, 720dp and AppBar-action cases from the behavior
    block into `test/screens/today_screen_test.dart`, using `setViewport` from
    `test/test_helpers/viewport.dart` and per-file `_FakeScheduleNotifier` / `_FakeGoalsNotifier` /
    `_FakeThemeNotifier` / `_FakeRestorativesNotifier` subclasses modelled on
    `test/screens/home_screen_now_state_test.dart` lines 21-65 and
    `test/screens/content_width_constraint_test.dart` lines 54-75 (P9 — per-file fakes, no shared
    fakes file). Run `dart format lib/ test/` and `flutter analyze`.
  </action>
  <verify>
    <automated>flutter test test/screens/today_screen_test.dart test/screens/home_screen_breathing_pulse_test.dart && grep -q 'class TodayScreen' lib/screens/today/today_screen.dart && grep -q 'class BreathingPulseCta' lib/screens/today/widgets/breathing_pulse_cta.dart && ! grep -q 'class BreathingPulseCta' lib/screens/home/home_screen.dart && grep -q 'showAdaptiveFormModal' lib/screens/today/today_screen.dart && grep -q '_resolveGoal' lib/screens/today/today_screen.dart && grep -q 'maxWidth: 720' lib/screens/today/today_screen.dart && test "$(grep -c 'Icons.refresh' lib/screens/today/today_screen.dart)" = "1" && ! grep -vE '^\s*//' lib/screens/today/today_screen.dart | grep -q 'Colors.white' && flutter analyze</automated>
  </verify>
  <done>TodayScreen exists with the merged AppBar, the ticker/lifecycle state carried from HomeScreen, schedule_screen's full goal-lookup family, and an empty state that keeps every affordance from both old screens. BreathingPulseCta lives in its own file and its test passes against the new path. flutter analyze clean and the pre-existing suite untouched.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: The day — one list, live row in place, named free time (D-01, D-05, UNIFY-01)</name>
  <files>lib/screens/today/today_screen.dart, test/screens/today_screen_test.dart</files>
  <read_first>
    - lib/screens/today/timeline.dart — the TimelineRow subtypes to switch over and buildTimeline's signature
    - lib/screens/today/widgets/timeline_row_tile.dart and free_time_row.dart and live_row_card.dart — the exact constructor parameters to fill
    - schedule_screen.dart lines 99-128 — the current body: ScheduleProgressBar, the 720dp ConstrainedBox, and the three-part list concatenation to replace
    - schedule_screen.dart lines 130-201 — _buildRestorativeSuggestions (mood 1-2 only), which the merged screen inherits along with a new RestorativesNotifier dependency
    - schedule_screen.dart lines 203-244 — _buildActiveChunkItems, the OLD first-unresolved scan. Read it so you recognise it; do NOT port any of it
    - home_screen.dart lines 354-372 — ScheduleProgressBar with ThemeNotifier.moodSeeds, the ReviewBanner gate and the EndOfDayCard gate
    - 22-CONTEXT.md "Specific Ideas" — the reference render this list must produce
  </read_first>
  <behavior>
    Given a schedule fixture with a completed 8:00 chunk, a skipped 9:00 chunk, an in-window
    10:45 break, a 10:50 chunk and a 13:00 commitment chunk, and a frozen clock inside the 10:45
    window:
    - Exactly one LiveRowCard is in the tree, and it is for the 10:45 chunk.
    - The 8:00 and 9:00 chunks are still rendered as rows (skipped work is inline, not hidden in
      an ExpansionTile) and the text "Skipped today" appears nowhere.
    - A "Free until 8:00 AM" row precedes the first activity.
    - A "Free · " row appears for the gap between 11:15 and 13:00.
    - The gutter shows the compact start time for a timed row.
    - No NowMarker widget is in the tree.
    - The literal text "See full schedule" appears nowhere (D-08 / G4).
    Additional cases:
    - A mood-2 schedule renders the restoratives card; a mood-4 schedule does not.
    - A schedule whose work chunks are more than half resolved exposes the "View your day"
      popup; one below the threshold does not.
    - Tapping an unresolved non-live work row opens the ChunkDetailSheet.
  </behavior>
  <action>
    Write the behavior-block cases into `test/screens/today_screen_test.dart` first, building the
    DailySchedule fixture with the _FakeScheduleNotifierWithSchedule pattern from
    `test/screens/home_screen_now_state_test.dart` lines 52-65. Confirm RED, then implement.

    In TodayScreen's active-schedule build path, read `ScheduleNotifier`, take `todaySchedule`,
    derive `mood` and `moodColor` from `ThemeNotifier.moodSeeds` (home's source of truth — do NOT
    port schedule_screen's private `_moodColors` map of raw hex; it is a duplicate palette and
    violates D-07), then call `resolveNowState(chunks: schedule.chunks, now: _nowFn)` ONCE and
    `buildTimeline(chunks: schedule.chunks, nowState: nowState)` ONCE. These two calls are the
    only "what is happening now" logic on the screen. There must be no second scan of chunks
    against the clock anywhere in this file — that is the exact defect 22-PATTERNS.md section 5
    warns the merge will otherwise reintroduce.

    Body layout, top to bottom inside `Align(topCenter)` + `ConstrainedBox(maxWidth: 720)`:
    ScheduleProgressBar (schedule, moodColor) — one instance, replacing the identical copy in
    both old screens; the ReviewBanner when `_inReviewWindow && !_bannerDismissed`; the
    EndOfDayCard when `!_eodCardDismissed && shouldShowEodCard(schedule.chunks)` (import
    shouldShowEodCard and EndOfDayCard from `../home/widgets/end_of_day_card.dart` and ReviewBanner
    from `../home/widgets/review_banner.dart` — those files stay put this wave and relocate in plan
    22-04); then the header block; then the scrolling day.

    Header block per 22-UI-SPEC.md "Structure": a Row with "Today" in titleLarge weight w600 on
    the left and the date on the right in bodyMedium/onSurfaceVariant, formatted with
    `DateFormat('EEE d MMM')` from the already-declared `intl` dependency (do not hand-roll and do
    not add a package). Beneath it a mood chip — a small Container in surfaceContainerHighest with
    ~10dp radius holding `'$emoji $label · $n chunks'`, where emoji comes from the `_moodEmojis`
    map carried over from home_screen, `label` comes from a new `_moodLabels` const map
    `{1: 'Low day', 2: 'Cloudy day', 3: 'Steady day', 4: 'Bright day', 5: 'Sunny day'}` (1, 3 and
    5 are the sketch's own strings; 2 and 4 interpolate the same voice), and `n` is the count of
    ChunkType.work chunks with correct singular/plural. The header stays put — it is a body
    element, NOT a collapsing app bar.

    The day itself: a `SingleChildScrollView` holding a `Column` of rows, driven by an exhaustive
    switch over the TimelineRow list. Use SingleChildScrollView + Column rather than a ListView,
    and say why in a doc comment: Task 3's centre-on-open needs the live row to be laid out, and a
    lazy ListView may not have built a row that is far down the day. A day is bounded at a few
    dozen rows, so eager layout is the cheap correct answer and it avoids adding a
    scroll-positioning package. Prepend the restoratives card to the Column when `mood <= 2`,
    reading RestorativesNotifier via context.watch exactly as schedule_screen did (P11).

    Row dispatch:
    - LeadingFreeRow renders `TimelineRowTile(startMinutes: null, child: FreeTimeRow.until(...))`
      — the gutter stays empty before the day's first activity, per UI-SPEC.
    - GapFreeRow renders TimelineRowTile with the row's startMinutes wrapping FreeTimeRow.gap.
    - A ChunkRow with isLive false renders TimelineRowTile wrapping SwipeableChunkCard with
      `showStartTime: false` (the gutter has the time) and every goal lookup passed through
      exactly as schedule_screen's `_buildSwipeableCard` did, including the onTap that opens
      ChunkDetailSheet for unresolved chunks.
    - A ChunkRow with isLive true renders TimelineRowTile wrapping LiveRowCard with:
      chunkId from the chunk; kicker `'RIGHT NOW'` (Phase 23 / LIVE-01 owns the RESTING variant);
      title from `_lookupGoalName` falling back to a non-empty rationale and then to 'Work block';
      remainingLabel computed from the NowState — for Active, minutes left until the window end
      rendered as `'$n min left · until ${formatMinutes(end)}'` clamped at zero, and for Overdue,
      the plain `formatTimeRange(start, end)` the ActiveChunkCard shows today (do NOT invent
      overdue copy: the Copywriting Contract forbids telling the user they are behind, and the
      remaining-time wording is Phase 23 / LIVE-02's decision); progress as
      `((nowMinutes - start) / durationMinutes)` for Active and 1.0 for Overdue; nextLine as
      `'Next · $title at ${formatMinutes(next.displayStartMinutes!)}'` when the NowState carries a
      next chunk with a start, otherwise null; showActions as
      `chunk.chunkType == ChunkType.work`.

    Delete nothing else and add no "See full schedule" affordance — the merged screen would be
    linking to itself (D-08). Do not add a "Skipped today" ExpansionTile: skipped chunks are rows
    in the one list (D-01 plus D-06), as recorded in plan 22-01's source audit.

    Run `dart format lib/ test/` and `flutter analyze`.
  </action>
  <verify>
    <automated>flutter test test/screens/today_screen_test.dart && grep -q 'buildTimeline' lib/screens/today/today_screen.dart && grep -q 'LiveRowCard' lib/screens/today/today_screen.dart && grep -q 'FreeTimeRow' lib/screens/today/today_screen.dart && grep -q 'SwipeableChunkCard' lib/screens/today/today_screen.dart && grep -q 'showStartTime: false' lib/screens/today/today_screen.dart && grep -q 'RIGHT NOW' lib/screens/today/today_screen.dart && grep -q "DateFormat('EEE d MMM')" lib/screens/today/today_screen.dart && ! grep -q 'See full schedule' lib/screens/today/today_screen.dart && ! grep -q 'Skipped today' lib/screens/today/today_screen.dart && ! grep -q 'NowMarker' lib/screens/today/today_screen.dart && test "$(grep -c 'resolveNowState' lib/screens/today/today_screen.dart)" = "1" && flutter analyze</automated>
  </verify>
  <done>TodayScreen renders the whole day as one list with named free time, skipped rows inline, and exactly one LiveRowCard at the current activity's own clock position; resolveNowState is called once and is the only clock read; no NowMarker, no "See full schedule", no "Skipped today" section.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Centre the live row on open + preserve the edge-state copy (D-02, D-03, LIVE-03 input)</name>
  <files>lib/screens/today/today_screen.dart, test/screens/today_screen_test.dart</files>
  <read_first>
    - home_screen.dart lines 542-667 — _buildPreStartContent, _buildGapBeforeNextContent and _buildDayCompleteContent: the exact strings "Your day starts at ...", "Up next", "Starts at ...", "That's a wrap", "You've reached the end of today's schedule."
    - 22-UI-SPEC.md "The live row" final paragraph — "On open, the list scrolls the current row to centre. That is the entire mechanism for finding 'now'. No sticky bar, no floating pill, no jump button."
    - 22-CONTEXT.md LOCKED items 2 and 3 — why the recall bar was rejected and must not come back
    - test/screens/home_screen_now_state_test.dart lines 380-660 — the widget cases that assert each edge-state string today; the same strings must still be findable
  </read_first>
  <behavior>
    - With a frozen clock inside a mid-day chunk's window and a long day above it, after
      pumpAndSettle the live row's render box centre is nearer the viewport centre than it was on
      the first frame (assert the scroll controller's offset moved off zero).
    - The centring happens once: advancing the fake clock past a one-minute tick and pumping
      again does not move the scroll offset a second time (the user's scroll position is not
      yanked while they read).
    - Pre-start clock (before the first chunk window): the text "Your day starts at" is present,
      and no LiveRowCard is in the tree.
    - Gap-before-next clock (current chunk resolved, next window not open): "Up next" is present
      and no LiveRowCard is in the tree.
    - Day-complete clock (past the last window): "That's a wrap" is present and no LiveRowCard is
      in the tree.
    - In every edge state the day list is still rendered below — the screen never degrades to a
      bare message.
    - No widget in the tree is positioned outside the scroll view as a floating recall pill and
      the string "Jump to now" appears nowhere (D-03 negative gate).
  </behavior>
  <action>
    Write the behavior-block cases into `test/screens/today_screen_test.dart` first. Confirm RED,
    then implement.

    Centre-on-open (D-02): add `final GlobalKey _liveRowKey = GlobalKey();`, a
    `final ScrollController _dayScrollController = ScrollController();` disposed in dispose(), and
    a `bool _didCentreLiveRow = false;`. Attach `_liveRowKey` to the LiveRowCard's
    TimelineRowTile via a KeyedSubtree. In build, when `!_didCentreLiveRow` and a live row exists,
    set `_didCentreLiveRow = true` synchronously and schedule a single
    `WidgetsBinding.instance.addPostFrameCallback` that, guarded on `mounted` and a non-null
    `_liveRowKey.currentContext`, calls `Scrollable.ensureVisible` with `alignment: 0.5`, a ~250ms
    duration and `Curves.easeOut`. Reset `_didCentreLiveRow` to false in `didChangeDependencies`
    in the same branch that already resets `_eodCardDismissed` when the schedule's dateYmd
    changes, so a new day re-centres but a one-minute tick never does.

    Document on the flag why it is one-shot: the screen rebuilds every minute, and re-running
    ensureVisible on each tick would drag the list out from under a reading user (threat T-22-08).

    Do NOT add a sticky bar, floating pill, jump button, or scroll listener that shows one (D-03).
    Note that in a comment beside the centring code so the next agent does not "improve" it back
    into the rejected sketch variant B.

    Edge-state line (LIVE-03's input): directly beneath the mood chip, render a quiet block when
    the NowState is PreStart, GapBeforeNext or DayComplete, and nothing at all when it is Active
    or Overdue (the live row in the list speaks for those). Carry the copy across from
    home_screen.dart lines 542-667 WORD FOR WORD: pre-start shows "Your day starts at " plus
    formatMinutes of the first chunk's start, then the goal-name-or-rationale plus duration body
    line; gap-before-next shows "Up next", the next chunk's title, its display rationale when
    present, and "Starts at " plus formatMinutes; day-complete shows "That's a wrap" and "You've
    reached the end of today's schedule.". Style it quiet — bodyMedium and titleMedium on
    onSurfaceVariant, no Card, no elevation, no accent fill. It is a header line, NOT a hero card
    (D-01) and NOT sticky (D-03). Add a doc comment naming Phase 23 / LIVE-03 as the owner of any
    future wording change here.

    Run `dart format lib/ test/` and `flutter analyze`.
  </action>
  <verify>
    <automated>flutter test test/screens/today_screen_test.dart && grep -q 'Scrollable.ensureVisible' lib/screens/today/today_screen.dart && grep -q 'alignment: 0.5' lib/screens/today/today_screen.dart && grep -q '_didCentreLiveRow' lib/screens/today/today_screen.dart && grep -q 'Your day starts at' lib/screens/today/today_screen.dart && grep -q 'Up next' lib/screens/today/today_screen.dart && grep -q "That's a wrap" lib/screens/today/today_screen.dart && ! grep -q 'Jump to now' lib/screens/today/today_screen.dart && flutter analyze</automated>
  </verify>
  <done>The list centres the live row once on open and never again on a tick; all five NowState branches render truthfully with the shipped copy intact; no sticky bar, pill or jump button exists anywhere in the file.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Hive-backed ScheduleNotifier to the screen | todaySchedule, moodIndex and chunk resolution state are read for display and mutated only through the existing markComplete / markSkipped / addEventToday notifier methods. No new persistence path. |
| Hive completion-log and quarterly-snapshot repositories to the review banner | _checkReviewWindow reads two boxes directly at initState, exactly as HomeScreen did. |
| user-entered commitment to today's schedule | The Add-an-event modal writes a CommitmentBlock through addEventToday. Unchanged surface, moved screen. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-22-08 | Denial of Service (usability) | centre-on-open fighting the user on every one-minute tick | mitigate | _didCentreLiveRow is set synchronously before the post-frame callback is scheduled and is reset only when the schedule's dateYmd changes; a widget case asserts the scroll offset does not move on a second tick. |
| T-22-09 | Denial of Service (crash) | _checkReviewWindow touching Hive boxes that are not open in tests or on cold start | mitigate | The try/catch with a silent fallback is carried across verbatim from HomeScreen; _inReviewWindow simply stays false. Pinned by the empty-state widget case, which pumps with no Hive at all. |
| T-22-10 | Denial of Service (crash) | Scrollable.ensureVisible called against a disposed or unlaid-out context | mitigate | The post-frame callback is guarded on `mounted` and on a non-null currentContext, and the day uses SingleChildScrollView so the target is always laid out. |
| T-22-11 | Repudiation (display honesty) | edge-state copy silently dropped in the merge, pre-empting LIVE-03 | mitigate | All five NowState branches are rendered, the three edge-state strings are grep-gated in the verify block, and widget cases assert each one is findable. |
| T-22-12 | Information Disclosure (data leak across days) | stale _eodCardDismissed / _didCentreLiveRow / _inReviewWindow state surviving a date rollover | mitigate | The existing _lastScheduleDateYmd comparison in didChangeDependencies resets the dismissal and centring flags together whenever the schedule's dateYmd changes. |
| T-22-SC | Tampering | npm/pip/cargo installs | accept | No package installs. DateFormat comes from the already-declared intl dependency; the scroll centring uses framework Scrollable.ensureVisible rather than a positioned-list package. |
</threat_model>

<verification>
- `flutter test test/screens/today_screen_test.dart` — GREEN.
- `flutter test test/screens/home_screen_breathing_pulse_test.dart` — GREEN against the new import path.
- `flutter test` — full suite green; no existing test changes behaviour in this plan beyond that one import line.
- `flutter analyze` — clean.
- Grep confirms `resolveNowState` is called exactly once in today_screen.dart, and that
  "See full schedule", "Skipped today", "NowMarker" and "Jump to now" appear nowhere in it.
- `lib/router.dart` is untouched: `/home` and `/schedule` still resolve exactly as before.
</verification>

<success_criteria>
- UNIFY-01 met: one screen shows the current activity and the rest of the day in a single
  scrollable list, with named free time, and no tab switch is required to see either.
- D-01: the current activity is a swelled card at its own clock position, not a hero or a
  separate zone.
- D-02: the list centres that row on open, once.
- D-03: no sticky bar, pill, or jump button exists in the file.
- D-05: gaps of 10 minutes or more are named; shorter ones are quiet.
- G4 / D-08 (screen half): the merged screen carries no self-referencing "See full schedule" link.
- P3/P4/P11/P12/P13 closed: one refresh action, one progress bar, one goal-lookup family, an empty
  state that keeps every affordance from both old screens, the restoratives surface intact,
  showAdaptiveFormModal intact, and the 720dp constraint intact.
- LIVE-01/02/03 inputs preserved rather than pre-empted: work-only now-detection, one-minute
  ticker, and the three edge-state copies survive word for word.
</success_criteria>

<output>
Create `.planning/phases/22-unified-today-screen/22-03-SUMMARY.md` when done.
</output>

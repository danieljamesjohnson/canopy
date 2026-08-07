---
phase: 22-unified-today-screen
plan: 02
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/utils/time_format.dart
  - lib/screens/today/widgets/timeline_row_tile.dart
  - lib/screens/today/widgets/free_time_row.dart
  - lib/screens/today/widgets/live_row_card.dart
  - lib/screens/schedule/widgets/chunk_card.dart
  - lib/screens/schedule/widgets/swipeable_chunk_card.dart
  - test/utils/time_format_test.dart
  - test/screens/today_row_widgets_test.dart
autonomous: true
requirements: [UNIFY-01]
must_haves:
  truths:
    - "Every row in the day carries its start time in a fixed 46dp left column with column-aligned digits"
    - "Free time renders as a named quiet row, never as blank space"
    - "The current activity renders as a swelled primaryContainer card with a RIGHT NOW kicker, a progress bar, labelled Complete/Skip, and a Next line"
    - "Completed chunks read struck-through with a check, skipped chunks read 'skipped', breaks read dashed and lighter, commitments read tertiaryContainer"
    - "Every colour on these rows comes from the active ColorScheme — chunk_card.dart no longer hardcodes any Colors.* value"
  artifacts:
    - path: "lib/utils/time_format.dart"
      provides: "formatDurationShort (1h 40m) + formatMinutesCompact (8:00 / 1:00p) for the gutter"
      contains: "formatDurationShort"
    - path: "lib/screens/today/widgets/timeline_row_tile.dart"
      provides: "46dp tabular-figure time gutter + row content layout"
      contains: "kGutterWidth"
      min_lines: 40
    - path: "lib/screens/today/widgets/free_time_row.dart"
      provides: "FreeTimeRow — 'Free until 8:00 AM' and 'Free · 1h 40m' behind a dotted left rule"
      contains: "class FreeTimeRow"
      min_lines: 50
    - path: "lib/screens/today/widgets/live_row_card.dart"
      provides: "LiveRowCard — the swelled in-place current-activity card with the Phase 23 injection seam"
      contains: "class LiveRowCard"
      min_lines: 120
    - path: "lib/screens/schedule/widgets/chunk_card.dart"
      provides: "UI-SPEC row vocabulary: showStartTime flag, struck-through completed, 'skipped' label, dashed breaks, tertiaryContainer commitments"
      contains: "showStartTime"
    - path: "lib/screens/schedule/widgets/swipeable_chunk_card.dart"
      provides: "showStartTime pass-through so swipe-to-complete survives inside the gutter layout"
      contains: "showStartTime"
  key_links:
    - from: "lib/screens/today/widgets/timeline_row_tile.dart"
      to: "lib/utils/time_format.dart"
      via: "formatMinutesCompact for the gutter label"
      pattern: "formatMinutesCompact"
    - from: "lib/screens/today/widgets/live_row_card.dart"
      to: "lib/providers/schedule_notifier.dart"
      via: "Complete/Skip buttons call markComplete/markSkipped by chunkId"
      pattern: "markComplete"
    - from: "lib/screens/schedule/widgets/swipeable_chunk_card.dart"
      to: "lib/screens/schedule/widgets/chunk_card.dart"
      via: "showStartTime forwarded to the wrapped card"
      pattern: "showStartTime: showStartTime"
---

<objective>
Build the row vocabulary the unified Today screen renders: the time gutter, the named free-time
row, the swelled live row, and the extended chunk card. Pure widget work — nothing in this plan
knows what time it is or which row is live; the screen (plan 22-03) decides that and passes it in.

Purpose: 22-CONTEXT.md D-06 fixes the visual language of the merged list and 22-UI-SPEC.md
"Row types" turns it into a table. This plan implements that table exactly, so plan 22-03 assembles
finished parts instead of inventing treatments while it is also solving layout and state.

Output: three new widgets under `lib/screens/today/widgets/`, two new formatters in
`lib/utils/time_format.dart`, an extended `chunk_card.dart` plus its swipeable wrapper, and widget
tests that also pre-carry the assertions currently living in
`test/screens/active_chunk_card_test.dart` (which plan 22-04 deletes once its subject is gone).
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

@lib/screens/schedule/widgets/chunk_card.dart
@lib/screens/schedule/widgets/swipeable_chunk_card.dart
@lib/screens/home/widgets/active_chunk_card.dart
@lib/utils/time_format.dart
@test/screens/active_chunk_card_test.dart
@test/test_helpers/mood_pump.dart
</context>

<decision_ids>
Decision IDs D-01 through D-09 are defined in `22-01-now-state-and-timeline-model-PLAN.md`
section `decision_ids`, which also carries the whole plan set's multi-source coverage audit.
This plan implements **D-01** (current row swells in place, no hero), **D-04** (a 46dp *text*
gutter, explicitly NOT a vertical rail), **D-05** (free time named), **D-06** (row vocabulary),
**D-07** (mood theming, no new palette).

**Phase 23 seam — build it, do not fill it.** LiveRowCard accepts kicker and remainingLabel as
plain injected strings. Phase 22 passes "RIGHT NOW" and a minute-granularity remaining line.
LIVE-01 ("RIGHT NOW — RESTING" for a running break), LIVE-02 (countdown granularity) and LIVE-03
(edge-state copy) change what the screen computes and passes — they must not need to change this
widget's layout. Do not implement break-awareness or a sub-minute countdown here.
</decision_ids>

<no_new_packages>
This phase installs nothing. The dashed break outline and the dotted free-time rule are hand-rolled
CustomPainters (~30 lines each), not a `dotted_border` package. Adding a dependency for a 30-line
painter would trip the Package Legitimacy Gate for no benefit. If an executor believes a package
is required, stop and report rather than installing.
</no_new_packages>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Time gutter + named free time (D-04, D-05, D-06)</name>
  <files>lib/utils/time_format.dart, lib/screens/today/widgets/timeline_row_tile.dart, lib/screens/today/widgets/free_time_row.dart, test/utils/time_format_test.dart, test/screens/today_row_widgets_test.dart</files>
  <read_first>
    - lib/utils/time_format.dart — the whole file (24 lines); formatMinutes renders "9:25 AM", formatTimeRange joins two of them
    - 22-UI-SPEC.md "Row types" / "Time gutter" paragraph and "Free time (LOCKED)" — the 46dp width, the type ramp, and the two exact copy strings
    - .planning/sketches/001-unified-today/index.html lines 219-240 — the reference gutter rendering ("8:00", "10:45", "1:00p") and the "Free until" / "Free · " template literals
    - test/test_helpers/mood_pump.dart — pumpWithMood(tester, child, moodIndex, extraProviders)
  </read_first>
  <behavior>
    formatDurationShort(int minutes):
    - 5 gives "5m"; 45 gives "45m"; 60 gives "1h"; 100 gives "1h 40m"; 120 gives "2h";
      195 gives "3h 15m"; 0 gives "0m".
    formatMinutesCompact(int minutes):
    - 480 gives "8:00"; 645 gives "10:45"; 780 gives "1:00p"; 720 gives "12:00p"; 0 gives "12:00";
      1350 gives "10:30p". (12-hour clock, no space, single 'p' suffix for PM only — the AM
      suffix is dropped so the string fits the 46dp column. This is the sketch's rendering.)
    TimelineRowTile:
    - Given startMinutes 645, renders "10:45" and the supplied child.
    - Given startMinutes null, renders no time text but still lays out the child at the same
      horizontal offset (the gutter is reserved, not collapsed).
    - The gutter SizedBox is exactly kGutterWidth (46.0) wide.
    FreeTimeRow:
    - Leading form (untilMinutes 480) renders exactly "Free until 8:00 AM".
    - Gap form (durationMinutes 100) renders exactly "Free · 1h 40m".
    - Neither form renders a Card.
  </behavior>
  <action>
    Write the test cases in `test/utils/time_format_test.dart` (pure test() cases for both
    formatters) and the TimelineRowTile / FreeTimeRow groups in
    `test/screens/today_row_widgets_test.dart` (widget cases via pumpWithMood, no providers
    needed) BEFORE implementing. Confirm RED.

    Append formatDurationShort and formatMinutesCompact to `lib/utils/time_format.dart`,
    documented in the same style as the existing helpers. formatDurationShort returns hours and
    minutes with the minute part omitted when zero. formatMinutesCompact mirrors the 12-hour
    conversion already present in formatMinutes — extract nothing, just mirror it, keeping
    formatMinutes byte-identical so its existing call sites are untouched.

    Create `lib/screens/today/widgets/timeline_row_tile.dart` exporting
    `const double kGutterWidth = 46.0;` and a TimelineRowTile StatelessWidget with fields
    `final int? startMinutes;` and `final Widget child;`. It renders a Row with
    crossAxisAlignment start — a SizedBox of width kGutterWidth holding the gutter Text
    (formatMinutesCompact of startMinutes when non-null, otherwise an empty SizedBox.shrink
    inside the same reserved width), then Expanded wrapping child. Gutter text style:
    theme.textTheme.bodySmall with color onSurfaceVariant, fontFeatures containing
    FontFeature.tabularFigures(), and fontFamilyFallback of 'monospace', 'RobotoMono',
    'Courier New'. Note in a doc comment WHY: no monospace font asset ships with the app and
    adding one is a new dependency, so tabular figures deliver the column alignment the
    UI-SPEC's "monospace" is actually buying, with the platform monospace family used where it
    exists.

    Add a top-of-file doc comment stating that this is D-06's ~46px time column and explicitly
    NOT D-04's rejected vertical rail: no connector line, no dot, no continuous stroke down the
    gutter. Anyone adding one is re-opening a rejected sketch variant.

    Create `lib/screens/today/widgets/free_time_row.dart` with FreeTimeRow, constructed via two
    named constructors — FreeTimeRow.until taking untilMinutes, and FreeTimeRow.gap taking
    durationMinutes — so the call site cannot mix the forms up. It renders no Card: a Padding
    containing a Row of a ~2dp-wide CustomPaint dotted vertical rule (file-private
    _DottedRulePainter, ~16dp tall, onSurfaceVariant at ~0.4 alpha), an 8dp gap, then the label
    Text in theme.textTheme.bodyMedium coloured onSurfaceVariant. Label strings are exactly
    'Free until ' followed by formatMinutes(untilMinutes), and 'Free · ' followed by
    formatDurationShort(durationMinutes) — locked copy per D-05, do not reword them.

    Run `dart format lib/ test/` and `flutter analyze`.
  </action>
  <verify>
    <automated>flutter test test/utils/time_format_test.dart test/screens/today_row_widgets_test.dart && grep -q 'formatDurationShort' lib/utils/time_format.dart && grep -q 'formatMinutesCompact' lib/utils/time_format.dart && grep -q 'kGutterWidth = 46' lib/screens/today/widgets/timeline_row_tile.dart && grep -q 'tabularFigures' lib/screens/today/widgets/timeline_row_tile.dart && grep -q 'Free until' lib/screens/today/widgets/free_time_row.dart && flutter analyze</automated>
  </verify>
  <done>Both formatters pass their unit cases; TimelineRowTile reserves a 46dp tabular-figure gutter and renders the compact time or nothing; FreeTimeRow renders both locked strings behind a dotted rule with no Card; flutter analyze clean.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: chunk_card row vocabulary + swipe pass-through + ColorScheme debt (D-06, D-07, P10)</name>
  <files>lib/screens/schedule/widgets/chunk_card.dart, lib/screens/schedule/widgets/swipeable_chunk_card.dart, test/screens/today_row_widgets_test.dart</files>
  <read_first>
    - lib/screens/schedule/widgets/chunk_card.dart — the whole file (468 lines): _buildShortBreak (76-104), _buildLongBreak (106-124), _WorkChunkContent.build (156-348), the trailing status-icon ternary (282-295), the SCHED-03 action row (300-337)
    - lib/screens/schedule/widgets/swipeable_chunk_card.dart lines 16-60 — the existing pass-through param pattern (goalEmojiTag / goalValence) to clone for showStartTime
    - 22-UI-SPEC.md "Row types" table — all seven row treatments and their exact ColorScheme slots
    - test/screens/chunk_card_goal_name_test.dart lines 93-130 — the two assertions that pin the existing time-range and "25 min" strings; both must keep passing
    - .planning/STATE.md "Deferred Items" — the Colors.green.shade600 / Colors.grey.shade400 tech-debt row, flagged "worth revisiting if Phase 22/23 touch chunk_card.dart anyway"
  </read_first>
  <behavior>
    - ChunkCard with a completed work chunk: the title Text carries TextDecoration.lineThrough,
      and the trailing icon is Icons.check_circle tinted colorScheme.primary (not a raw green).
    - ChunkCard with a skipped work chunk: title struck through, and the trailing affordance is
      the literal text "skipped" in onSurfaceVariant (no Icons.arrow_forward).
    - ChunkCard with an unresolved work chunk: no strikethrough,
      Icons.radio_button_unchecked, and the labelled Complete/Skip buttons still present
      (SCHED-03 — unchanged).
    - ChunkCard with showStartTime false, on a chunk with displayStartMinutes set, renders
      "25 min" and does NOT render "9:25 AM – 9:50 AM" (the gutter carries the time).
    - ChunkCard with showStartTime omitted still renders "9:25 AM – 9:50 AM" — the existing
      chunk_card tests keep passing untouched.
    - SwipeableChunkCard with showStartTime false forwards it: the wrapped card renders "25 min",
      and the Dismissible swipe wrapper is still present for an unresolved work chunk.
    - ChunkCard on a ChunkType.shortBreak chunk renders "Short break", has no Card fill colour
      (transparent), and paints a dashed outline.
    - ChunkCard on a ChunkType.longBreak chunk renders "Long break" with the same dashed
      treatment.
    - ChunkCard on a completed break renders the check icon as well.
    - ChunkCard on a work chunk with commitmentId non-null uses colorScheme.tertiaryContainer as
      the card colour and draws no outline and no left goal-colour bar.
  </behavior>
  <action>
    Add a "ChunkCard row vocabulary" group to `test/screens/today_row_widgets_test.dart` covering
    every case in the behavior block, using pumpWithMood with ScheduleNotifier / GoalsNotifier
    fakes copied from `test/screens/active_chunk_card_test.dart` lines 25-54 (the established
    per-file _Fake*Notifier convention — do not create a shared fakes file). Confirm RED, then
    implement.

    Add `final bool showStartTime;` to ChunkCard, _WorkChunkContent and SwipeableChunkCard, all
    defaulting to true, and forward it down the chain (SwipeableChunkCard to ChunkCard, ChunkCard
    to _WorkChunkContent, and also on the break-card early-return path inside
    SwipeableChunkCard.build). Change the SCHED-01 conditional from checking only
    `chunk.displayStartMinutes != null` to also requiring showStartTime, so the existing
    else-branch (which already renders the duration as "N min") covers the gutter case. Do not
    invent a new duration string.

    In _WorkChunkContent.build: derive isCommitment from `chunk.commitmentId != null`. Apply
    TextDecoration.lineThrough to the title Text style when the chunk is completed or skipped.
    Replace the trailing ternary's skipped branch (Icons.arrow_forward) with a Text reading
    "skipped" in theme.textTheme.bodySmall coloured onSurfaceVariant. Replace
    Colors.green.shade600 with theme.colorScheme.primary and Colors.grey.shade400 with
    theme.colorScheme.outlineVariant — this closes the standing tech-debt item and is required by
    the UI-SPEC framework note ("hardcoded colour is a bug"). For the Card: when isCommitment,
    pass color tertiaryContainer and a RoundedRectangleBorder with BorderSide.none, and skip the
    left colour-bar Positioned entirely; otherwise pass color surfaceContainer and a BorderSide
    coloured outlineVariant.

    LEAVE THE SCHED-03 ACTION ROW EXACTLY AS IT IS. The always-visible labelled Complete/Skip on
    unresolved work chunks is shipped behaviour (SCHED-03, v1.2) and the UI-SPEC row table
    describes visual treatment, not an instruction to remove affordances. Removing it here would
    be an unplanned feature reduction.

    Replace _buildShortBreak and _buildLongBreak with a single _buildBreak used by both
    ChunkType.shortBreak and ChunkType.longBreak. It renders a CustomPaint with a file-private
    _DashedBorderPainter (12dp corner radius, ~1dp stroke, ~4dp dash / ~4dp gap, colour
    outlineVariant) wrapping a transparent-fill Padding/Row of: the title ("Short break" for
    shortBreak, "Long break" for longBreak) in theme.textTheme.bodyMedium coloured
    onSurfaceVariant at regular weight — breaks are not achievements, so no bold and no emoji —
    then a spacer, the duration as "N min" in bodySmall/onSurfaceVariant, then Icons.check_circle
    in colorScheme.primary when chunk.isCompleted. Keep the outer margins the old builders used
    (EdgeInsets.symmetric vertical 4, horizontal 16) so list rhythm is unchanged. Drop the coffee
    emoji and the surfaceContainerHighest fill — both are superseded by the dashed treatment in
    D-06.

    Run `dart format lib/ test/` and `flutter analyze`, then run the four existing chunk_card test
    files plus chunk_detail_sheet_test.dart to prove no regression.
  </action>
  <verify>
    <automated>flutter test test/screens/today_row_widgets_test.dart test/screens/chunk_card_goal_name_test.dart test/screens/chunk_card_priority_badge_test.dart test/screens/chunk_card_valence_test.dart test/screens/chunk_card_hover_test.dart test/screens/chunk_detail_sheet_test.dart && grep -q 'showStartTime' lib/screens/schedule/widgets/chunk_card.dart && grep -q 'showStartTime' lib/screens/schedule/widgets/swipeable_chunk_card.dart && grep -q '_DashedBorderPainter' lib/screens/schedule/widgets/chunk_card.dart && grep -q 'tertiaryContainer' lib/screens/schedule/widgets/chunk_card.dart && grep -q 'lineThrough' lib/screens/schedule/widgets/chunk_card.dart && ! grep -vE '^\s*//' lib/screens/schedule/widgets/chunk_card.dart | grep -qE 'Colors\.(green|grey|white|amber|black|red|blue)' && flutter analyze</automated>
  </verify>
  <done>chunk_card renders all six row treatments from the UI-SPEC table, honours showStartTime through the swipeable wrapper, contains no hardcoded Colors.* outside comments, keeps the SCHED-03 action row and the swipe gesture, and all five pre-existing card test files still pass.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: LiveRowCard — the swelled in-place current activity (D-01, Phase 23 seam)</name>
  <files>lib/screens/today/widgets/live_row_card.dart, test/screens/today_row_widgets_test.dart</files>
  <read_first>
    - lib/screens/home/widgets/active_chunk_card.dart — the whole file (247 lines). The Complete/Skip Tooltip + FilledButton/OutlinedButton block (147-179) transplants nearly verbatim; the Card/Stack/left-bar chrome does NOT (the UI-SPEC live row has no left bar)
    - 22-UI-SPEC.md "The live row" — the six elements in order and their type and opacity ramp
    - test/screens/active_chunk_card_test.dart lines 144-228 — every assertion this widget must satisfy so that file can be deleted in plan 22-04 without losing coverage
    - 22-CONTEXT.md "Specific Ideas" — the reference render of the live row, mid-morning, mood 3
  </read_first>
  <behavior>
    LiveRowCard takes: chunkId (String), kicker (String), title (String), remainingLabel
    (String), progress (double 0..1), nextLine (nullable String), showActions (bool, default
    true). It renders:
    - The kicker text, uppercase, labelSmall, at about 72% opacity of onPrimaryContainer.
    - The title, titleLarge, FontWeight.w600, onPrimaryContainer.
    - remainingLabel with tabular figures at about 82% opacity.
    - A LinearProgressIndicator whose value equals the passed progress, clamped to 0..1.
    - When showActions is true: a labelled "Complete" FilledButton.icon and a labelled "Skip"
      OutlinedButton.icon, both always visible (no hover gate, SCHED-03).
    - When showActions is false: neither button is in the tree.
    - nextLine when non-null; nothing when null.
    Test cases:
    - Renders the kicker "RIGHT NOW" when passed it.
    - Renders the title, remainingLabel and nextLine strings verbatim.
    - Renders no next-line text when nextLine is null.
    - The card's background colour equals colorScheme.primaryContainer under pumpWithMood.
    - find.byType(FilledButton) and find.byType(OutlinedButton) each find one with showActions
      true; both findsNothing with showActions false.
    - Tapping Complete calls ScheduleNotifier.markComplete with the given chunkId (assert on the
      fake's lastCompletedId).
    - Tapping Skip calls ScheduleNotifier.markSkipped with the given chunkId.
    - find.byType(LinearProgressIndicator) finds one and its value equals the passed progress.
    - A progress of 1.5 is clamped to 1.0 and a progress of -0.2 to 0.0 rather than asserting.
    - No Icons.arrow_forward and no "Now" pill badge — the kicker line replaced it.
  </behavior>
  <action>
    Write the LiveRowCard group in `test/screens/today_row_widgets_test.dart` first (reusing the
    _FakeScheduleNotifier from Task 2's group, which already records lastCompletedId and
    lastSkippedId). Confirm RED, then implement.

    Create `lib/screens/today/widgets/live_row_card.dart` with a public LiveRowCard
    StatelessWidget carrying exactly the fields listed in the behavior block. It renders a Card
    with color primaryContainer, a RoundedRectangleBorder of 16dp radius, a soft elevation of 2,
    the same horizontal 16 / vertical 4 margins the surrounding rows use, and a Padding of 16
    containing a Column with crossAxisAlignment start and mainAxisSize min: kicker, 4dp gap,
    title, 6dp gap, remainingLabel, 10dp gap, a ClipRRect-rounded LinearProgressIndicator
    (minHeight about 6, valueColor from colorScheme.primary, backgroundColor onPrimaryContainer
    at low alpha), then when showActions the Complete/Skip Row transplanted from
    active_chunk_card.dart lines 147-179 with the notifier calls rebound to the chunkId field,
    then when nextLine is non-null a 10dp gap and the nextLine Text in bodySmall at about 72%
    opacity.

    All colours derive from onPrimaryContainer / primaryContainer / primary via
    Theme.of(context).colorScheme — no Colors.* literals (D-07). Use withValues(alpha: ...) for
    the opacity ramp, matching the codebase's existing usage in now_marker.dart and
    home_screen.dart.

    Two doc-comment obligations on the class:
    (1) State that kicker and remainingLabel are INJECTED BY THE SCREEN and name Phase 23's
    LIVE-01 / LIVE-02 as the owners of what goes into them, so a future agent extends the caller
    rather than this widget.
    (2) State that this card deliberately sits at its own clock position inside the day list
    (D-01) and is never lifted into a hero region, a sticky bar (D-03) or a floating pill — if a
    future change wants one of those, it is re-opening a rejected sketch variant.

    Do NOT modify or delete `lib/screens/home/widgets/active_chunk_card.dart` in this plan. It is
    still wired into the live HomeScreen this wave and is deleted in plan 22-04 once nothing
    references it. Two similar widgets coexisting for one wave is intentional.

    Run `dart format lib/ test/` and `flutter analyze`.
  </action>
  <verify>
    <automated>flutter test test/screens/today_row_widgets_test.dart && grep -q 'class LiveRowCard' lib/screens/today/widgets/live_row_card.dart && grep -q 'primaryContainer' lib/screens/today/widgets/live_row_card.dart && grep -q 'LinearProgressIndicator' lib/screens/today/widgets/live_row_card.dart && grep -q 'showActions' lib/screens/today/widgets/live_row_card.dart && grep -q 'clamp' lib/screens/today/widgets/live_row_card.dart && ! grep -vE '^\s*//' lib/screens/today/widgets/live_row_card.dart | grep -qE 'Colors\.[a-z]' && test -f lib/screens/home/widgets/active_chunk_card.dart && flutter analyze</automated>
  </verify>
  <done>LiveRowCard renders all six UI-SPEC live-row elements from injected strings, wires Complete/Skip to the notifier by chunkId, hides actions when told to, clamps progress, uses only ColorScheme slots, and every assertion previously carried by active_chunk_card_test.dart's widget group now has a home. active_chunk_card.dart is untouched.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| screen-supplied display strings to LiveRowCard | kicker, title, remainingLabel and nextLine cross into the widget as already-resolved text. All originate in-app from the user's own goals and schedule; no external or network-sourced content reaches this surface. |
| user gesture to persistence | Complete and Skip write through ScheduleNotifier.markComplete / markSkipped — the only state-mutating path in this plan. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-22-04 | Tampering | LiveRowCard Complete/Skip acting on the wrong chunk | mitigate | The card holds a single required chunkId field and both handlers pass exactly that value; two widget tests assert the fake notifier received that id and no other. |
| T-22-05 | Denial of Service (render crash) | LinearProgressIndicator given a progress value outside 0..1 | mitigate | The card clamps the incoming progress to 0.0-1.0 before handing it to the indicator, so a clock or schedule edge (an overdue chunk, a zero-duration chunk) degrades to a full or empty bar rather than an assertion failure. Covered by an explicit widget case. |
| T-22-06 | Repudiation (display honesty) | struck-through or "skipped" treatment applied to the wrong chunk state | mitigate | Strikethrough and the trailing affordance are derived from chunk.isCompleted / chunk.isSkipped only, with a widget case pinning each of the three states. |
| T-22-07 | Information Disclosure (contrast and readability) | hardcoded colours surviving a mood change or a dark theme | mitigate | A grep gate fails the task if any Colors.* literal remains outside comments in chunk_card.dart or live_row_card.dart; this also closes the standing tech-debt item recorded in STATE.md. |
| T-22-SC | Tampering | npm/pip/cargo installs | accept | No package installs. The dashed border and dotted rule are hand-rolled CustomPainters; see the no_new_packages section. |
</threat_model>

<verification>
- `flutter test test/screens/today_row_widgets_test.dart test/utils/time_format_test.dart` — GREEN.
- `flutter test test/screens/chunk_card_goal_name_test.dart test/screens/chunk_card_priority_badge_test.dart test/screens/chunk_card_valence_test.dart test/screens/chunk_card_hover_test.dart test/screens/chunk_detail_sheet_test.dart` — GREEN (no regression from the chunk_card changes).
- `flutter test` — full suite green.
- `flutter analyze` — clean.
- Grep confirms no Colors.* literal outside comments in chunk_card.dart or the three new widget files.
- Grep confirms `lib/screens/home/widgets/active_chunk_card.dart` still exists (its deletion belongs to plan 22-04).
</verification>

<success_criteria>
- UNIFY-01 (row layer): every row type in the 22-UI-SPEC "Row types" table has a rendering, and
  free time is one of them.
- D-06 satisfied: completed reads struck-through with a check, skipped reads "skipped", breaks
  read dashed and lighter, commitments read tertiaryContainer, and the start time sits in a
  ~46px column.
- D-04 respected: the gutter carries text only. No rail, no connector line, no dot.
- D-07 satisfied and P10 closed: nothing on these rows is coloured outside the active ColorScheme.
- Shipped affordances survive: swipe-to-complete still wraps non-live rows, and the labelled
  Complete/Skip action row still appears on unresolved work chunks.
- The Phase 23 seam exists: LIVE-01/02/03 can land by changing what the screen passes to
  LiveRowCard, not by rewriting it.
</success_criteria>

<output>
Create `.planning/phases/22-unified-today-screen/22-02-SUMMARY.md` when done.
</output>

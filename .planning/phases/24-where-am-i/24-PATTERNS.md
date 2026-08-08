# Phase 24: Where Am I - Pattern Map

**Mapped:** 2026-08-08
**Files analyzed:** 1 new, 2 modified (source), 3 test files extended
**Analogs found:** 5 / 5 — this phase is small enough that every file's pattern source was
verified directly in the live checkout on 2026-08-08 (all line numbers below re-confirmed
against the current tree, not copied forward from 24-RESEARCH.md unchecked).

---

## Scope Note

This phase touches exactly two source files (`timeline.dart`, `today_screen.dart`) and creates
one new widget file (`now_marker.dart`). There is no controller/service/model layering question
here — everything is either "pure row-model function" (`timeline.dart`) or "screen controller"
(`today_screen.dart`) or "dumb row widget" (`now_marker.dart`), and each already has a near-exact
analog in the same file or an adjacent sibling file. Depth over breadth: this document goes deep
on the four files RESEARCH/UI-SPEC flagged as load-bearing, not wide across the codebase.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/screens/today/widgets/now_marker.dart` (NEW) | component (dumb, StatelessWidget) | request-response (render) | `lib/screens/today/widgets/free_time_row.dart` | exact — same tier: quiet, non-`Card` row rendered inside `TimelineRowTile` |
| `lib/screens/today/timeline.dart` (MODIFIED) | model / pure function (row-list builder) | transform | itself — extend the existing sealed hierarchy + forward-pass loop, in-file convention | exact — same file, same pattern |
| `lib/screens/today/today_screen.dart` (MODIFIED) | screen (StatefulWidget controller) | request-response (render dispatch) + event-driven (clock sample already threaded) | itself — extend the existing exhaustive switch + `build()`'s clock-threading block | exact — same file, same pattern |
| `lib/utils/time_format.dart` (MODIFIED, optional per RESEARCH Pitfall 5) | utility (pure formatting/arithmetic) | transform | itself — sibling function to `formatMinutes`/`formatMinutesCompact` | exact |
| `test/screens/today_timeline_model_test.dart` (MODIFIED) | test (unit) | transform | itself — extend "structural cases" and "isLive derivation" groups with the same factory/assertion shape | exact |
| `test/screens/today_screen_test.dart` (MODIFIED) | test (widget) | request-response | itself — extend/edit existing pre-start/gap-before-next/day-complete groups, and the flagged stale test at lines 364-370 | exact |
| `test/screens/today_row_widgets_test.dart` (MODIFIED) | test (widget) | request-response | itself — mirrors whatever row-widget test pattern already exists for `FreeTimeRow` | role-match (not yet read in full — see note below) |

---

## Pattern Assignments

### 1. `lib/screens/today/timeline.dart` — the sealed hierarchy + forward-pass loop (extend in place)

**Current full shape, verified line-for-line in the live checkout (92 lines total):**

**The sealed hierarchy** (lines 13-37):
```dart
/// A single row in the unified Today timeline.
///
/// Exactly three subtypes, so the render layer can use an exhaustive switch
/// with no default branch.
sealed class TimelineRow {}

class ChunkRow extends TimelineRow {
  final ScheduledChunk chunk;
  final bool isLive;
  ChunkRow(this.chunk, {this.isLive = false});
}

class LeadingFreeRow extends TimelineRow {
  final int untilMinutes;
  LeadingFreeRow(this.untilMinutes);
}

class GapFreeRow extends TimelineRow {
  final int startMinutes;
  final int durationMinutes;
  GapFreeRow(this.startMinutes, this.durationMinutes);
}
```
**New subtype must match this exact idiom** — a `TimelineRow` subclass with only final fields and
a positional constructor, no methods, doc comment above stating what it represents and what it is
NOT (a clock read). Also update the doc comment "Exactly three subtypes" → "exactly four
subtypes" (line 11) since it's an explicit, load-bearing promise the render layer relies on for
its exhaustive-switch-no-default guarantee.

**`buildTimeline`'s signature and INVARIANT doc comments** (lines 39-57):
```dart
/// Builds the unified Today timeline's row list from the day's [chunks] and
/// a [NowState].
///
/// INVARIANT 1: this function NEVER reads the clock — DateTime must not
/// appear anywhere in this file outside a doc comment. The only source of
/// "now" is the injected [nowState], which is the single now-detector
/// (22-PATTERNS.md section 5 / threat T-22-01): there is no code path by
/// which this row list can disagree with [resolveNowState] about which
/// chunk is current.
///
/// INVARIANT 2: the incoming [chunks] order is preserved and never
/// re-sorted...
List<TimelineRow> buildTimeline({
  required List<ScheduledChunk> chunks,
  required NowState nowState,
  int minGapMinutes = kMinGapMinutes,
}) {
```
Add `int? nowMinutes` as a new optional named parameter (default `null`) alongside `nowState` —
**not** a `DateTime`, matching INVARIANT 1's explicit ban on the `DateTime` symbol appearing
anywhere in this file outside a doc comment. Update INVARIANT 1's doc comment to state explicitly
that `nowMinutes` is an injected position, never derived from a clock read inside this file
(mirrors the existing wording style for `nowState`).

**The forward-pass loop to extend** (lines 66-91, exact live text):
```dart
  final rows = <TimelineRow>[];
  int? prevEnd;

  for (final chunk in chunks) {
    final start = chunk.displayStartMinutes;

    if (start != null) {
      if (prevEnd == null) {
        // First chunk with a clock position — leading free row if the day
        // doesn't start at minute 0.
        if (start > 0) {
          rows.add(LeadingFreeRow(start));
        }
      } else if (start - prevEnd >= minGapMinutes) {
        rows.add(GapFreeRow(prevEnd, start - prevEnd));
      }
      prevEnd = start + chunk.durationMinutes;
    }

    rows.add(ChunkRow(chunk, isLive: chunk.id == liveId));
  }

  return rows;
```
**UI-SPEC's locked insertion order** (supersedes RESEARCH's raw diff — read UI-SPEC's "Insertion
rule" section in full before implementing): the marker check goes **after** the leading/gap
free-row block and **immediately before** `rows.add(ChunkRow(...))`, not at the top of the loop
body — so free row (if any), then marker, then chunk, in that order for any iteration where both
apply. The `NOW-02` guard (`nowMinutes == null || nowMinutes < start`) wraps the existing `if
(start > 0)` check at line 76. Both changes stay inside this single forward pass — no second loop,
consistent with INVARIANT 2's "never re-scan" framing.

**The `liveId` computation just above the loop** (lines 60-64) is untouched — it already derives
suppression-relevant state (`Active`/`Overdue`) that the new `nowState is! Active` guard parallels
but does not reuse directly (that guard is a separate, simpler type check, not wired through
`liveId`).

---

### 2. `lib/screens/today/today_screen.dart` — the exhaustive switch + clock-threading (extend in place)

**The one exhaustive switch, verified at line 556** (`_buildTimelineRow`, lines 550-567+):
```dart
  // ── The day — row dispatch over buildTimeline's exhaustive TimelineRow ──
  //
  // The now-classifier and buildTimeline are called exactly once, in
  // build() (P1 / 22-PATTERNS.md section 5): this dispatch never reads the
  // clock or re-derives which chunk is "now" — it only renders what it is
  // handed.

  Widget _buildTimelineRow(
    BuildContext context,
    TimelineRow row,
    NowState nowState,
    int? secondsRemaining,
  ) {
    switch (row) {
      case LeadingFreeRow(:final untilMinutes):
        return TimelineRowTile(
          startMinutes: null,
          child: FreeTimeRow.until(untilMinutes: untilMinutes),
        );
      case GapFreeRow(:final startMinutes, :final durationMinutes):
        return TimelineRowTile(
          startMinutes: startMinutes,
          child: FreeTimeRow.gap(durationMinutes: durationMinutes),
        );
      case ChunkRow(:final chunk, :final isLive):
        ...
```
**New case, following the exact `TimelineRowTile`-wrapping convention** the two free-row cases
already use, plus the `Semantics` wrapper UI-SPEC locks:
```dart
      case NowMarkerRow(:final minutes):
        return TimelineRowTile(
          startMinutes: minutes,
          child: Semantics(
            label: 'Now — ${formatMinutes(minutes)}',
            excludeSemantics: true,
            child: const NowMarker(),
          ),
        );
```
`grep -rn "switch (row" lib/ test/` and `grep -rn "TimelineRow" lib/ test/` re-confirmed: this is
still the **only** exhaustive switch over `TimelineRow` in the tree — adding the fourth subtype
costs exactly one case here.

**The clock-threading block in `build()`, verified at lines 920-945 (comment + code, exact live
text):**
```dart
    // The only two "what is happening now" calls on this screen (P1 /
    // 22-PATTERNS.md section 5): this samples the clock exactly once,
    // buildTimeline turns that classification into a row list, and nothing
    // below this point re-derives which chunk is current.
    //
    // nowDt is sampled here and threaded into BOTH resolveNowState (via a
    // closure that always returns this same value) and _liveSecondsRemaining
    // directly — a single clock read per build, so the two consumers can
    // never straddle a second/minute boundary and disagree (WR-01).
    final nowDt = _nowFn();
    final nowState = resolveNowState(chunks: schedule.chunks, now: () => nowDt);
    final liveSecondsLeft = _liveSecondsRemaining(nowState, nowDt);
    _syncFastTimer(
      !_isBackgrounded && liveSecondsLeft != null && liveSecondsLeft < 60,
    );
    final timelineRows = buildTimeline(
      chunks: schedule.chunks,
      nowState: nowState,
    );
```
**The marker's `nowMinutes` must be a third consumer of this same `nowDt` local** — compute it
right after `nowDt` is sampled (e.g. `final nowMinutes = nowDt.hour * 60 + nowDt.minute;` or, if
the extraction in Pattern 4 below is taken, `minutesOfDay(nowDt)`), then pass it into
`buildTimeline(chunks: schedule.chunks, nowState: nowState, nowMinutes: nowMinutes)`. **Do not**
add a second `_nowFn()` call — this is the exact discipline the existing comment above already
documents and the WR-01 commit (`48af6bf`) established for `_liveSecondsRemaining`.

---

### 3. `lib/screens/today/widgets/free_time_row.dart` — the quiet-row widget analog (closest match for `NowMarker`)

**Full file, verified (86 lines) — extract substantially, this is the primary analog:**
```dart
class FreeTimeRow extends StatelessWidget {
  const FreeTimeRow.until({super.key, required int untilMinutes})
    : _untilMinutes = untilMinutes,
      _durationMinutes = null;

  const FreeTimeRow.gap({super.key, required int durationMinutes})
    : _untilMinutes = null,
      _durationMinutes = durationMinutes;

  final int? _untilMinutes;
  final int? _durationMinutes;

  String _resolveLabel() {
    if (_untilMinutes != null) {
      return 'Free until ${formatMinutes(_untilMinutes)}';
    }
    return 'Free · ${formatDurationShort(_durationMinutes!)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ruleColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 2,
            height: 16,
            child: CustomPaint(painter: _DottedRulePainter(color: ruleColor)),
          ),
          const SizedBox(width: 8),
          Text(
            _resolveLabel(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
```
**What to copy directly:** the `StatelessWidget` shape, `Padding(vertical: 8)` outer wrap, a `Row`
whose children are [rule, `SizedBox(width: 8)`, label `Text`], `theme.textTheme.*` + `colorScheme`
usage (no hardcoded colors), no `Card`/elevation/fill. **What UI-SPEC changes for the marker
specifically:** the rule shape (horizontal 24×2dp line, not `FreeTimeRow`'s vertical 2×16dp dotted
tick — see UI-SPEC "Why a horizontal rule, not a repeat of `FreeTimeRow`'s vertical tick"), an
added `Expanded` trailing rule at `alpha: 0.35`, and `colorScheme.primary` instead of
`onSurfaceVariant` (the marker is the one new `colorScheme.primary` usage this phase adds, per
UI-SPEC's Color section). `withValues(alpha:)` is the established API convention, confirmed at
line 34 of this same file — reuse it verbatim, do not use the deprecated `.withOpacity()`.

**Recommended `NowMarker` shape** (UI-SPEC-locked visual values layered onto this analog's
structure — starting point, not yet written to disk):
```dart
class NowMarker extends StatelessWidget {
  const NowMarker({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(width: 24, height: 2, color: color),
          const SizedBox(width: 8),
          Text(
            'Now',
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(height: 2, color: color.withValues(alpha: 0.35)),
          ),
        ],
      ),
    );
  }
}
```
Note: the `Semantics(label: 'Now — ...', excludeSemantics: true, ...)` wrapper is applied at the
**call site** in `today_screen.dart`'s switch (Pattern 2 above), not inside this widget — UI-SPEC
is explicit that this differs from the deleted pre-merge widget, which wrapped itself in
`ExcludeSemantics` (fully silencing screen readers, a regression UI-SPEC calls out and fixes).

---

### 4. `lib/screens/today/widgets/timeline_row_tile.dart` — the gutter/inset wrapper (reused as-is, zero changes)

**Full file, verified (88 lines) — no modification needed, cited so the executor understands what
wrapping `NowMarker` in it buys for free:**
```dart
const double kGutterWidth = 52.0;

class TimelineRowTile extends StatelessWidget {
  const TimelineRowTile({
    super.key,
    required this.startMinutes,
    required this.child,
  });

  final int? startMinutes;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gutterStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontFamilyFallback: const ['monospace', 'RobotoMono', 'Courier New'],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: kGutterWidth,
            child: startMinutes != null
                ? Text(formatMinutesCompact(startMinutes!), style: gutterStyle)
                : const SizedBox.shrink(),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
```
Passing `startMinutes: minutes` (the marker's own clock position, an `int`, not `null`) in
Pattern 2's new switch case means the gutter renders the current compact time (e.g. `"12:34p"`)
next to the marker automatically — no special-casing needed in `NowMarker` itself, and `NowMarker`
must carry **no horizontal inset of its own** (per this file's own doc comment at lines 36-44: the
16dp inset lives here exactly once; adding it to a child would double it).

---

### 5. `lib/utils/time_format.dart` — optional `minutesOfDay` extraction (RESEARCH Pitfall 5 / Open Question 2)

**Full file, verified (49 lines).** `formatMinutes` (lines 8-16) is the sibling function whose
doc-comment style and signature shape (`(int minutes) -> String` / here, `(DateTime) -> int`) the
new helper should match:
```dart
/// Formats minutes-from-midnight as a 12-hour time string.
/// Example: 565 → "9:25 AM"
String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final suffix = h < 12 ? 'AM' : 'PM';
  final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$hour:${m.toString().padLeft(2, '0')} $suffix';
}
```
If the planner takes RESEARCH's recommendation to extract the duplicated `nowDt.hour * 60 +
nowDt.minute` formula (currently computed once, inline, at `now_state.dart:125`), the new helper
belongs in this file, alongside `formatMinutes`:
```dart
/// Converts a [DateTime] to minutes-from-midnight in its own local
/// wall-clock time (never `.toUtc()`) — the same frame of reference
/// [formatMinutes] and [resolveNowState] already use, so a caller using
/// this helper can never silently disagree with either.
int minutesOfDay(DateTime dt) => dt.hour * 60 + dt.minute;
```
Then both `now_state.dart:125` (`final currentMinutes = nowDt.hour * 60 + nowDt.minute;`) and the
new `build()` call site in `today_screen.dart` (Pattern 2) call `minutesOfDay(nowDt)` instead of
each inlining the formula. This is a two-line de-duplication, not a new abstraction — see
RESEARCH's Pitfall 5 for the drift risk it closes.

---

### 6. Test patterns — extend, don't reinvent

**`test/screens/today_timeline_model_test.dart`** — verified structure (289 lines total):

Chunk factories at the top of the file (lines 16-49), reused verbatim by every group:
```dart
ScheduledChunk _workChunk({
  String id = 'chunk-1',
  int? syntheticStartMinutes,
  int durationMinutes = 25,
  bool isCompleted = false,
  bool isSkipped = false,
}) { ... }

ScheduledChunk _breakChunk({
  String id = 'break-1',
  int? syntheticStartMinutes,
  int durationMinutes = 5,
}) { ... }
```
"structural cases" group starts at line 52 — this is where the NOW-02 leading-row-suppression
tests belong (new cases alongside the existing "first chunk starts at minute 480" /  "first chunk
starts at minute 0" / "all chunks untimed" tests at lines 58-90):
```dart
group('buildTimeline — structural cases', () {
    test('empty chunks returns an empty list', () {
      final rows = buildTimeline(chunks: [], nowState: DayComplete());
      expect(rows, isEmpty);
    });

    test('first chunk starts at minute 480: LeadingFreeRow(480) then its '
        'ChunkRow', () {
      final chunk = _workChunk(syntheticStartMinutes: 480);
      final rows = buildTimeline(chunks: [chunk], nowState: PreStart(chunk));
      expect(rows, hasLength(2));
      expect(rows[0], isA<LeadingFreeRow>());
      expect((rows[0] as LeadingFreeRow).untilMinutes, 480);
      expect(rows[1], isA<ChunkRow>());
      expect((rows[1] as ChunkRow).chunk.id, chunk.id);
    });
    ...
```
"isLive derivation (single-detector guarantee)" group starts at line 172 — model NOW-01's marker
placement/suppression tests on this group's shape (parametrized-over-`NowState` pattern, e.g. the
"PreStart, GapBeforeNext, or DayComplete: no row has isLive true" test at lines 193-205 iterates a
`for (final nowState in [...])` loop — the equivalent "marker shows in all four non-Active states"
test should use the same loop-over-states shape):
```dart
    test('nowState PreStart, GapBeforeNext, or DayComplete: no row has '
        'isLive true', () {
      final c1 = _workChunk(id: 'c1', syntheticStartMinutes: 480);
      final c2 = _workChunk(id: 'c2', syntheticStartMinutes: 600);
      for (final nowState in [PreStart(c1), GapBeforeNext(c2), DayComplete()]) {
        final rows = buildTimeline(chunks: [c1, c2], nowState: nowState);
        expect(
          rows.whereType<ChunkRow>().where((r) => r.isLive),
          isEmpty,
          reason: '$nowState must not mark any row live',
        );
      }
    });
```
Since all 15 existing `buildTimeline(...)` call sites in this file omit `nowMinutes` (the new
parameter defaults to `null`), **none of the existing tests need to change** — only new tests are
added, each explicitly passing `nowMinutes:` to exercise NOW-01/NOW-02.

**`test/screens/today_screen_test.dart`** — verified structure (relevant groups):

`_pumpTodayScreen` helper, verified at lines 162-190ish, the shared widget-pump wrapper every
group calls — **new tests must call this helper, not hand-roll `pumpWidget`:**
```dart
Future<void> _pumpTodayScreen(
  WidgetTester tester, {
  required ScheduleNotifier scheduleNotifier,
  DateTime Function()? now,
  RestorativesNotifier? restorativesNotifier,
}) async {
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: ThemeNotifier.moodSeeds[3]!),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ScheduleNotifier>.value(value: scheduleNotifier),
        ChangeNotifierProvider<GoalsNotifier>.value(value: _FakeGoalsNotifier()),
        ChangeNotifierProvider<ThemeNotifier>.value(value: _FakeThemeNotifier()),
        ChangeNotifierProvider<RestorativesNotifier>.value(
          value: restorativesNotifier ?? _FakeRestorativesNotifier(),
        ),
      ],
      child: MaterialApp(theme: theme, home: TodayScreen(now: now), ...),
    ),
  );
  ...
```
The "pre-start" test, verified at lines 575-599, is the correctly-shaped template for the new
marker's `PreStart` widget test (clock genuinely before the day starts, not the buggy pattern the
landmine test below has):
```dart
    testWidgets('pre-start: "Nothing until" is present, no LiveRowCard', (
      tester,
    ) async {
      final schedule = DailySchedule(
        dateYmd: _todayYmd(),
        moodIndex: 3,
        chunks: [_workChunk(syntheticStartMinutes: 480, durationMinutes: 60)],
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
        now: () => DateTime(2026, 8, 7, 6, 0),
      );

      expect(find.text('Nothing until 8:00 AM'), findsOneWidget);
      expect(
        find.text(
          'The day starts with Deep work. Until then the time is yours.',
        ),
        findsOneWidget,
      );
      expect(find.byType(LiveRowCard), findsNothing);
      // The day list is still rendered below — never a bare message.
      expect(find.textContaining('Free until'), findsOneWidget);
    });
```

**THE LANDMINE — `test/screens/today_screen_test.dart:364-370`, verified exact live text, must be
edited not left green:**
```dart
    testWidgets('"Free until 8:00 AM" precedes the first activity', (
      tester,
    ) async {
      await pumpDay(tester);

      expect(find.textContaining('Free until 8:00 AM'), findsOneWidget);
    });
```
This calls the group's shared `pumpDay(tester)` helper (defined at lines 328-344 in the same
group, `"Task 2 — the day as one list, live row in place, named free time"`), which pumps at
**`now: () => DateTime(2026, 8, 7, 10, 47), // inside the 10:45 window`** (line 341) against a
fixture whose first chunk (`c1`) starts at `syntheticStartMinutes: 480` — 8:00 AM (lines 294-300).
10:47 is **2h47m after** the 8:00 AM window this text claims is still "free until." This is the
literal NOW-02 bug, currently pinned as expected/passing behavior. Once the `nowMinutes` guard
ships in `timeline.dart`, this exact assertion will start failing (`find.textContaining('Free
until 8:00 AM')` will find nothing, because `LeadingFreeRow` is now correctly suppressed at that
clock time) — **that failure is the fix's own proof**, not a regression to chase. The plan must
either (a) move this specific test's clock to a genuinely pre-8:00-AM time — matching the
pre-start test's pattern immediately above (`now: () => DateTime(2026, 8, 7, 6, 0)`) — reusing
`pumpDay`'s fixture but calling `_pumpTodayScreen` directly with an earlier `now:` instead of the
shared `pumpDay(tester)` wrapper (since `pumpDay` hardcodes 10:47), or (b) split it into two tests:
one proving the row shows before 8:00 AM, one proving it's absent by 10:47 (paired with the new
`NowMarker` assertion for the same clock time, since `GapBeforeNext` is exactly the state 10:47
resolves to for this fixture — confirmed by the "exactly one LiveRowCard, for the 10:45 chunk"
sibling test at lines 346-352, which shows `c3` at minute 645/10:45 is what's live at 10:47, i.e.
this same clock sample is `Active`, not `GapBeforeNext` — **note this affects the marker
suppression test choice**: 10:47 with this fixture is an `Active` state (c3's 10:45-10:50 window
is open), so a marker-visibility assertion at this exact clock/fixture pair should assert the
marker is **absent** (Active-suppression), not present — don't reuse this fixture/clock pair to
test marker presence, pick a genuinely `GapBeforeNext`/`PreStart`/`Overdue`/`DayComplete` fixture
instead, e.g. the pre-start test's fixture/clock, or the "gap-before-next" group at line 601+).

**`test/screens/today_screen_now_state_test.dart`** — verified the injectable `now:` closure
pattern used throughout (representative lines):
```dart
      );
      final state = resolveNowState(
        chunks: chunks,
        now: () => DateTime(2026, 6, 13, 9, 0), // 9:00 AM
      );
```
Every test in this file passes a `DateTime(...)` literal wrapped in a zero-arg closure to `now:` —
new tests verifying "the marker's position equals `resolveNowState`'s sample" should use this same
literal-closure shape, and (per RESEARCH's requirement) assert the marker's rendered/gutter time
matches the exact same `DateTime` used for `nowState`'s classification — proving the single-sample
threading, not just that a marker renders.

**`test/screens/today_row_widgets_test.dart`** — not read in full for this pattern map (RESEARCH
targeted lines 1-180 only); the planner should locate `FreeTimeRow`'s existing widget-test group in
this file (`grep -n "FreeTimeRow" test/screens/today_row_widgets_test.dart`) and mirror its
pump/assert shape for a new `NowMarker` widget-test group — flagged here as a residual gap rather
than guessed at, since guessing a test file's structure without reading it risks proposing a
pattern that doesn't match the file's actual conventions.

---

## Shared Patterns

### Single-now-detector / no-second-clock-read discipline
**Source:** `lib/screens/today/timeline.dart` INVARIANT 1 doc comment (lines 42-47) and
`lib/screens/today/today_screen.dart:920-931`'s clock-threading comment block, both verified live.
**Apply to:** every file this phase touches. `nowMinutes` must be computed once in `build()` from
the existing `nowDt` local and threaded as a plain `int` into `buildTimeline` — never a fourth
`_nowFn()`/`DateTime.now()` call, never re-derived inside `timeline.dart`.

### Exhaustive-switch-with-no-default over `TimelineRow`
**Source:** `lib/screens/today/today_screen.dart:556` (`_buildTimelineRow`), the sole site in the
codebase (re-confirmed by grep against the live tree).
**Apply to:** the new `NowMarkerRow` case — add it as a fourth arm here; do not add a second switch
or an `if (row is NowMarkerRow)` check anywhere else.

### `TimelineRowTile` wrapping — no widget carries its own horizontal inset
**Source:** `lib/screens/today/widgets/timeline_row_tile.dart:36-44` doc comment, verified live.
**Apply to:** `NowMarker` — it must have zero horizontal padding/margin of its own; the 16dp inset
and 52dp gutter both come from wrapping it in `TimelineRowTile` at the call site.

### `colorScheme.*` / `theme.textTheme.*` only — no hardcoded colors or px sizes
**Source:** `free_time_row.dart` and `timeline_row_tile.dart`, both verified live, project-wide
convention per 24-UI-SPEC.md's Color section.
**Apply to:** `NowMarker`'s new `colorScheme.primary` usage (the only new usage of that role this
phase adds, per UI-SPEC).

---

## No Analog Found

None. Every file this phase touches has a same-file or same-tier analog verified directly in the
live checkout — there is no file in this phase's scope that needs to fall back to RESEARCH's
generic code examples instead of a real, currently-existing pattern.

## Metadata

**Files read in full this pass:** `lib/screens/today/timeline.dart` (92 lines),
`lib/screens/today/widgets/free_time_row.dart` (86 lines),
`lib/screens/today/widgets/timeline_row_tile.dart` (88 lines), `lib/utils/time_format.dart` (49
lines), recovered `git show ea97862^:lib/screens/schedule/widgets/now_marker.dart` (46 lines).
**Files read targeted this pass:** `lib/screens/today/today_screen.dart` (540-590, 920-975),
`lib/screens/today/now_state.dart` (95-134), `test/screens/today_screen_test.dart` (280-380,
560-600), `test/screens/today_timeline_model_test.dart` (1-95, 172-246),
`test/screens/today_screen_now_state_test.dart` (grep for `group(`/`now:` occurrences).
**Line numbers:** all re-confirmed against the live tree on 2026-08-08, not copied forward from
24-RESEARCH.md unchecked (per this phase's explicit instruction) — in every case they matched
RESEARCH's cited numbers exactly, giving high confidence RESEARCH's other, non-reverified claims
(e.g. the 15-call-site count in `today_timeline_model_test.dart`) are also still accurate.
**Pattern extraction date:** 2026-08-08

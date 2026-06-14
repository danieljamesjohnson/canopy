# Phase 17: Time-Anchored Home - Pattern Map

**Mapped:** 2026-06-13
**Files analyzed:** 4 (2 modified, 1 updated test, 1 new test)
**Analogs found:** 4 / 4

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/screens/home/home_screen.dart` | screen / StatefulWidget | event-driven (timer + provider) | `lib/screens/focus/focus_screen.dart` (timer); `lib/providers/theme_notifier.dart` (lifecycle observer) | exact (timer + lifecycle split across two analogs) |
| `test/screens/home_screen_now_state_test.dart` | unit + widget test | — | `test/screens/active_chunk_card_test.dart` | exact |
| `test/screens/active_chunk_card_test.dart` | widget test update | — | self (line 322 assertion update only) | exact |

---

## Pattern Assignments

### `lib/screens/home/home_screen.dart` — all changes

---

#### 1. Sealed class + `resolveNowState` top-level pure function

**What to add:** A top-level sealed class hierarchy and a pure function at the top of `home_screen.dart`, below imports, above `HomeScreen`. This placement makes it importable in a unit test without pumping a widget.

**Analog:** No prior sealed class in codebase — this is a new pattern. Use RESEARCH.md pseudocode directly (Pattern 1, lines 151–196 of RESEARCH.md). The injectable-`now` field convention is lifted from `ScheduleNotifier` (see Shared Patterns below).

**Imports to add** — `dart:async` is needed for the timer; it is not currently imported in `home_screen.dart` (lines 1–17). All other imports are already present.

```dart
// ADD at top of home_screen.dart (after existing imports):
import 'dart:async';
```

**Sealed class skeleton** — place immediately below imports, above `class HomeScreen`:

```dart
// Discriminated result of resolveNowState().
// Top-level so unit tests can import without a widget pump.
sealed class _NowState {}

class _PreStart extends _NowState {
  final ScheduledChunk firstChunk;
  _PreStart(this.firstChunk);
}

class _Active extends _NowState {
  final ScheduledChunk current;
  final ScheduledChunk? next;
  _Active(this.current, this.next);
}

class _Overdue extends _NowState {
  final ScheduledChunk overdue;
  final ScheduledChunk? next;
  _Overdue(this.overdue, this.next);
}

class _DayComplete extends _NowState {}
```

**`resolveNowState` function** — pure, top-level, injectable clock. Replace the two-variable derivation at `home_screen.dart` lines 104–111 by calling this function instead. Full implementation per RESEARCH.md Pattern 1 (lines 157–196 of RESEARCH.md). Key points:
- Filter: `c.chunkType == ChunkType.work && c.displayStartMinutes != null`
- Sort by `displayStartMinutes` ascending
- `currentMinutes = now().hour * 60 + now().minute` — LOCAL time only, never `.toUtc()`
- Empty `allWork` → `_DayComplete()`
- Before first window → `_PreStart(allWork.first)`
- Past last window end → `_DayComplete()`
- Otherwise: `candidates = allWork.lastWhere(start <= currentMinutes)`, advance past resolved chunks, return `_Active` or `_Overdue` based on whether `currentMinutes >= windowEnd`

**Function signature:**
```dart
_NowState resolveNowState({
  required List<ScheduledChunk> chunks,
  required DateTime Function() now,
}) { ... }
```

---

#### 2. `WidgetsBindingObserver` mixin + 1-minute timer on `_HomeScreenState`

**What to change:** `_HomeScreenState` currently does NOT have `WidgetsBindingObserver`. Add the mixin and the timer lifecycle.

**Analog (mixin declaration):** `BreathingPulseCta` in `home_screen.dart` line 372:
```dart
// home_screen.dart line 372 — existing pattern in same file
class _BreathingPulseCtaState extends State<BreathingPulseCta>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
```

Apply the same `with WidgetsBindingObserver` to `_HomeScreenState`:
```dart
// CHANGE home_screen.dart line 26:
class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
```

**Analog (timer lifecycle):** `ThemeNotifier` lines 205–241 (`_startTicker`, `didChangeAppLifecycleState`, `dispose`).

```dart
// lib/providers/theme_notifier.dart lines 205–241 — timer lifecycle to mirror
void _startTicker() {
  _ticker?.cancel();
  if (!_timeModulationEnabled || !_isForeground) return;
  _ticker = Timer.periodic(const Duration(minutes: 20), (_) {
    _resetIfDayChanged();
    notifyListeners();
  });
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  _isForeground = state == AppLifecycleState.resumed;
  if (_isForeground) {
    _resetIfDayChanged();
    _startTicker();
    notifyListeners();
  } else {
    _ticker?.cancel();
  }
}

@override
void dispose() {
  _ticker?.cancel();
  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
}
```

**`_HomeScreenState` adaptation** — the interval is 1 minute, the callback calls `setState()` instead of `notifyListeners()`, and there is no `_isForeground` flag (use `_startNowTimer` idempotent helper per RESEARCH.md Pattern 2):

```dart
// ADD fields to _HomeScreenState:
Timer? _nowTimer;
DateTime Function() _nowFn = DateTime.now;  // injectable for tests

// REPLACE initState (currently home_screen.dart lines 52–55):
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  _startNowTimer();
  _checkReviewWindow();
}

void _startNowTimer() {
  _nowTimer?.cancel();
  _nowTimer = Timer.periodic(const Duration(minutes: 1), (_) {
    if (mounted) setState(() {});
  });
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    _startNowTimer();
  } else if (state == AppLifecycleState.paused) {
    _nowTimer?.cancel();
  }
}

// REPLACE dispose (currently no dispose on _HomeScreenState):
@override
void dispose() {
  _nowTimer?.cancel();
  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
}
```

**Analog (`mounted` guard in timer callback):** `FocusScreen` lines 60 and 68:
```dart
// lib/screens/focus/focus_screen.dart lines 57–71
_timer = Timer.periodic(const Duration(seconds: 1), (t) {
  if (_secondsRemaining <= 0) {
    t.cancel();
    if (mounted) {          // <-- mounted guard
      setState(() { ... });
    }
    return;
  }
  if (mounted) {            // <-- mounted guard
    setState(() => _secondsRemaining--);
  }
});
```

**`dispose` teardown analog:** `FocusScreen` line 51:
```dart
// lib/screens/focus/focus_screen.dart line 51
_timer?.cancel(); // CRITICAL: prevent setState-after-dispose
```

Also see `BreathingPulseCta` `dispose` at `home_screen.dart` line 424–428:
```dart
// home_screen.dart lines 424–428 — observer removal pattern in same file
@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _controller.dispose();
  super.dispose();
}
```

---

#### 3. Replace lines 104–111 (chunk selection) with `resolveNowState` call

**Current code to replace** (`home_screen.dart` lines 104–111):
```dart
final unresolvedWork = schedule.chunks
    .where(
      (c) =>
          c.chunkType == ChunkType.work && !c.isCompleted && !c.isSkipped,
    )
    .toList();
final currentChunk = unresolvedWork.isNotEmpty ? unresolvedWork.first : null;
final nextChunk = unresolvedWork.length > 1 ? unresolvedWork[1] : null;
```

**Replacement:**
```dart
final _nowState = resolveNowState(chunks: schedule.chunks, now: _nowFn);
```

The `build()` method then switches on `_nowState` for the "Now" zone content.

---

#### 4. Replace the `if (currentChunk == null)` inline fallback with a `switch` on `_nowState`

**Current code** (`home_screen.dart` lines 150–161):
```dart
// home_screen.dart lines 150–161 — pattern to replace
if (currentChunk == null)
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Text(
      'All done today!',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
  )
else
  ActiveChunkCard(chunk: currentChunk),
```

**Replacement pattern** — `switch` on sealed class, exhaustive at compile time:
```dart
switch (_nowState) {
  case _PreStart(:final firstChunk):
    // render _PreStartContent(firstChunk)
  case _Active(:final current, :final next):
    // render ActiveChunkCard(chunk: current); expose next for Next section
  case _Overdue(:final overdue, :final next):
    // render ActiveChunkCard(chunk: overdue); expose next for Next section
  case _DayComplete():
    // render _DayCompleteContent()
}
```

The `next` chunk for the "Next" section is extracted from `_Active.next` or `_Overdue.next`, replacing the current `nextChunk` variable.

---

#### 5. `_PreStartContent` private widget

**Pattern to mirror** — existing "All done today!" inline text (`home_screen.dart` lines 150–159) plus the "Next" compact row structure (lines 186–238):

```dart
// home_screen.dart lines 150–159 — structural template for inline state widgets
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: Text(
    'All done today!',
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    ),
  ),
)
```

**`_PreStartContent` structure** (two-line Column matching UI-SPEC):
```dart
// Implement as private StatelessWidget or inline Builder in build()
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Your day starts at ${formatMinutes(firstChunk.displayStartMinutes!)}',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '${goalNameOrFallback} · ${firstChunk.durationMinutes} min',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  ),
)
```

Goal name lookup: `_lookupGoalName(context, firstChunk)` — method already exists at `home_screen.dart` line 282.

---

#### 6. `_DayCompleteContent` private widget

**Same `Padding/Column/Text` structure** as `_PreStartContent` but with static copy:
```dart
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        "That's a wrap",
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        "You've reached the end of today's schedule.",
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  ),
)
```

---

### `test/screens/active_chunk_card_test.dart` — line 322 update

**What to change:** The `testWidgets('shows "All done today!" ...')` test at line 322 must be updated. The schedule it uses (`_scheduleAllResolved`) creates chunks with `syntheticStartMinutes: null` — under the new logic these are excluded from the `allWork` filter (`displayStartMinutes == null`), so `allWork.isEmpty` → `_DayComplete()` → "That's a wrap" is shown instead of "All done today!".

**Current assertion (line 327–331 of active_chunk_card_test.dart):**
```dart
expect(
  find.text('All done today!'),
  findsOneWidget,
  reason: 'NAV-02: "All done today!" must appear when all chunks are resolved',
);
```

**Replacement assertion:**
```dart
expect(
  find.text("That's a wrap"),
  findsOneWidget,
  reason: 'NOW-02: day-complete state shows "That\'s a wrap" when all chunks resolved',
);
```

The `_scheduleAllResolved()` factory (lines 256–279) does NOT need to change — its chunks already have null `syntheticStartMinutes`, which correctly triggers the `allWork.isEmpty` → day-complete path.

---

### `test/screens/home_screen_now_state_test.dart` — new file

**Role:** Unit tests for `resolveNowState` (no widget pump) + widget tests for HomeScreen at simulated times.

**Analog:** `test/screens/active_chunk_card_test.dart` — full file. Copy its structure verbatim: fake classes, pump helper, `main()` with `group()` blocks.

**Fake classes to copy/adapt from `active_chunk_card_test.dart`:**

```dart
// active_chunk_card_test.dart lines 25–69 — copy these fakes into new test file
class _FakeScheduleNotifier extends ScheduleNotifier {
  @override
  Future<void> init() async {}
}

class _FakeGoalsNotifier extends GoalsNotifier {
  @override
  Future<void> loadGoals() async {}
}

class _FakeThemeNotifier extends ThemeNotifier {
  @override
  Future<void> init() async {}
  @override
  bool get isPreCheckin => false;
}

class _FakeScheduleNotifierWithSchedule extends _FakeScheduleNotifier {
  _FakeScheduleNotifierWithSchedule(this._schedule);
  final DailySchedule _schedule;
  @override
  DailySchedule? get todaySchedule => _schedule;
  @override
  bool get hasScheduleToday => true;
  @override
  int? get moodIndex => _schedule.moodIndex;
}
```

**Pump helper to copy from `active_chunk_card_test.dart` lines 107–136:**

```dart
// active_chunk_card_test.dart lines 107–136 — _pumpHomeScreen helper
Future<void> _pumpHomeScreen(
  WidgetTester tester, {
  required ScheduleNotifier scheduleNotifier,
}) async {
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ThemeNotifier.moodSeeds[3]!,
    ),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ScheduleNotifier>.value(value: scheduleNotifier),
        ChangeNotifierProvider<GoalsNotifier>.value(value: _FakeGoalsNotifier()),
        ChangeNotifierProvider<ThemeNotifier>.value(value: _FakeThemeNotifier()),
      ],
      child: MaterialApp(theme: theme, home: const HomeScreen()),
    ),
  );
}
```

**Time-injectable `_workChunk` factory** — extend the existing factory to accept `syntheticStartMinutes` and `durationMinutes`:

```dart
// active_chunk_card_test.dart lines 73–83 — chunk factory to extend
ScheduledChunk _workChunk({
  String id = 'chunk-1',
  int? syntheticStartMinutes,
}) => ScheduledChunk(
  id: id,
  chunkTypeIndex: ChunkType.work.index,
  goalId: 'goal-1',
  durationMinutes: 25,
  rationale: 'Deep work',
  syntheticStartMinutes: syntheticStartMinutes,
);
```

New file needs `durationMinutes` as a parameter too. Add it:
```dart
ScheduledChunk _workChunk({
  String id = 'chunk-1',
  int? syntheticStartMinutes,
  int durationMinutes = 25,
  bool isCompleted = false,
  bool isSkipped = false,
}) {
  final c = ScheduledChunk(
    id: id,
    chunkTypeIndex: ChunkType.work.index,
    goalId: 'goal-1',
    durationMinutes: durationMinutes,
    rationale: 'Deep work',
    syntheticStartMinutes: syntheticStartMinutes,
  );
  if (isCompleted) c.isCompleted = true;
  if (isSkipped) c.isSkipped = true;
  return c;
}
```

**Unit tests for `resolveNowState` (no widget pump)** — call `resolveNowState` directly and assert on the result type + payload. These are `test()` not `testWidgets()`. Example:

```dart
group('resolveNowState unit tests (NOW-01/NOW-02)', () {
  test('pre-start: now before first chunk start', () {
    final chunks = [_workChunk(syntheticStartMinutes: 480, durationMinutes: 60)]; // 8am–9am
    final state = resolveNowState(
      chunks: chunks,
      now: () => DateTime(2026, 6, 13, 6, 0), // 6:00 AM
    );
    expect(state, isA<_PreStart>());
  });

  test('active: now within chunk window', () {
    final chunks = [_workChunk(syntheticStartMinutes: 510, durationMinutes: 60)]; // 8:30–9:30
    final state = resolveNowState(
      chunks: chunks,
      now: () => DateTime(2026, 6, 13, 9, 0), // 9:00 AM
    );
    expect(state, isA<_Active>());
  });

  test('overdue: now past chunk window end, next chunk not yet started', () {
    final chunks = [
      _workChunk(id: 'c1', syntheticStartMinutes: 510, durationMinutes: 60), // 8:30–9:30
      _workChunk(id: 'c2', syntheticStartMinutes: 630, durationMinutes: 60), // 10:30–11:30
    ];
    final state = resolveNowState(
      chunks: chunks,
      now: () => DateTime(2026, 6, 13, 10, 0), // 10:00 AM
    );
    expect(state, isA<_Overdue>());
    expect((state as _Overdue).overdue.id, 'c1');
  });

  test('day-complete: now past last chunk window', () {
    final chunks = [_workChunk(syntheticStartMinutes: 480, durationMinutes: 60)]; // 8am–9am
    final state = resolveNowState(
      chunks: chunks,
      now: () => DateTime(2026, 6, 13, 18, 0), // 6:00 PM
    );
    expect(state, isA<_DayComplete>());
  });
});
```

**Widget tests for HomeScreen** — inject `now` by overriding `_nowFn` on `_HomeScreenState`. Because `_nowFn` is a field on the private state class, the cleanest approach is to make `HomeScreen` accept an optional `now` parameter that is forwarded to the state (same pattern as `ScheduleNotifier`), OR to expose `_nowFn` via a `@visibleForTesting` setter. The planner must decide which approach to use — both are consistent with existing patterns.

Widget test scenarios per UI-SPEC §Widget Test Contract:
1. Pre-start: find `'Your day starts at'` text
2. Active: find `ActiveChunkCard`, no pre-start text
3. Overdue (between-chunks): find `ActiveChunkCard` for chunk 1, "Next" row for chunk 2
4. Day-complete (time-based): find `"That's a wrap"`, no `ActiveChunkCard`
5. Day-complete (all-resolved): find `"That's a wrap"`, no `ActiveChunkCard`
6. Timer tick: use `tester.pump(const Duration(minutes: 1))` after setting `_nowFn` to a time past the first chunk start — assert transition from pre-start heading to `ActiveChunkCard`

---

## Shared Patterns

### Injectable `now` — `DateTime Function()` field

**Source:** `lib/providers/schedule_notifier.dart` lines 24–34; `lib/providers/theme_notifier.dart` lines 43–49.

**Apply to:** `_HomeScreenState._nowFn` field; `resolveNowState` `now` parameter.

```dart
// schedule_notifier.dart lines 24–34 — canonical injectable now pattern
ScheduleNotifier({
  DateTime Function() now = DateTime.now,
  ...
}) : _now = now, ...;

final DateTime Function() _now;
```

The `resolveNowState` function receives `now` as a required named parameter (not a default). The state field `_nowFn` defaults to `DateTime.now` and is reassigned in tests.

---

### `WidgetsBindingObserver` mixin + `addObserver`/`removeObserver`

**Source:** `lib/screens/home/home_screen.dart` lines 372–428 (`BreathingPulseCta` — in the same file being modified).

**Apply to:** `_HomeScreenState` — add mixin, `addObserver` in `initState`, `removeObserver` in `dispose`.

```dart
// home_screen.dart line 372 — mixin declaration in same file
class _BreathingPulseCtaState extends State<BreathingPulseCta>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

// home_screen.dart line 389
WidgetsBinding.instance.addObserver(this);

// home_screen.dart line 424–428
@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _controller.dispose();
  super.dispose();
}
```

---

### Timer.periodic + `mounted` guard

**Source:** `lib/screens/focus/focus_screen.dart` lines 57–71 (`_start` method); line 51 (`dispose`).

**Apply to:** `_HomeScreenState._startNowTimer`.

```dart
// focus_screen.dart lines 57–71 — Timer.periodic + mounted guard pattern
_timer = Timer.periodic(const Duration(seconds: 1), (t) {
  if (_secondsRemaining <= 0) {
    t.cancel();
    if (mounted) { setState(() { ... }); }
    return;
  }
  if (mounted) { setState(() => _secondsRemaining--); }
});

// focus_screen.dart line 51
_timer?.cancel();
```

---

### `pumpWithMood` test helper

**Source:** `test/test_helpers/mood_pump.dart` lines 24–48.

**Apply to:** All new widget tests in `home_screen_now_state_test.dart` that pump `ActiveChunkCard` in isolation. For `HomeScreen` widget tests, use the `_pumpHomeScreen` helper (copied from `active_chunk_card_test.dart`) which constructs `ThemeData` directly.

```dart
// mood_pump.dart lines 24–48
Future<void> pumpWithMood(
  WidgetTester tester,
  Widget child, {
  int moodIndex = 3,
  Iterable<ChangeNotifierProvider> extraProviders = const [],
}) async { ... }
```

---

### `formatMinutes` / `formatTimeRange`

**Source:** `lib/utils/time_format.dart` (already imported at `home_screen.dart` line 13).

**Apply to:** `_PreStartContent` heading (`formatMinutes(firstChunk.displayStartMinutes!)`).

---

### `_lookupGoalName` method

**Source:** `home_screen.dart` lines 282–287.

**Apply to:** `_PreStartContent` body line — resolve first chunk's goal name for display.

```dart
// home_screen.dart lines 282–287
String? _lookupGoalName(BuildContext context, ScheduledChunk chunk) {
  if (chunk.goalId == null) return null;
  final goals = context.read<GoalsNotifier>().goals;
  final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
  return goal?.name;
}
```

---

## No Analog Found

None. All required patterns exist in the codebase. The `resolveNowState` sealed-class result is a new Dart pattern for this project, but its structure is fully specified in RESEARCH.md Pattern 1 (lines 151–196) and requires no external reference.

---

## Metadata

**Analog search scope:** `lib/screens/home/`, `lib/screens/focus/`, `lib/providers/`, `test/screens/`, `test/test_helpers/`
**Files read:** `home_screen.dart`, `focus_screen.dart`, `theme_notifier.dart` (lines 1–50, 195–242), `schedule_notifier.dart` (lines 1–50), `active_chunk_card_test.dart`, `mood_pump.dart`
**Pattern extraction date:** 2026-06-13

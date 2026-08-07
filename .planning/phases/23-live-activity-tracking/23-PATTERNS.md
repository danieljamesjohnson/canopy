# Phase 23: Live Activity Tracking - Pattern Map

**Mapped:** 2026-08-07
**Files analyzed:** 4 modified (no new files expected), 1 test file extended
**Analogs found:** N/A — this phase extends existing files in place; the pattern map below is
**in-file conventions to match**, not new-file-to-analog mappings.

---

## Scope Note

Phase 22 landed today and deleted `home_screen.dart`/`schedule_screen.dart`. All paths below are
the current live tree (`lib/screens/today/`). Phase 23 creates **no new source files** — it
extends `now_state.dart`, `today_screen.dart`, and the existing test file. If a shared
break-title helper is extracted (planner's discretion per RESEARCH Open Question 2), it should be
a **private method on `_TodayScreenState`**, colocated next to `_chunkTitle` — no other screen
renders a chunk title, so there is no cross-file reuse pressure yet.

## File Classification

| File | Role | Data Flow | Change Type |
|------|------|-----------|-------------|
| `lib/screens/today/now_state.dart` | model / pure function (state machine) | transform | extend filter (line 113), rename `allWork`→generic, update doc comments |
| `lib/screens/today/today_screen.dart` | screen (StatefulWidget controller) | event-driven (timer) + request-response (render) | extend `_chunkTitle`, `_buildLiveRow`, `_buildEdgeStateLine`, `_buildAppBar`, add `_fastTimer` |
| `lib/screens/today/widgets/live_row_card.dart` | component (dumb/injected-string) | request-response | **no changes** — contract must not be broken (see below) |
| `test/screens/today_screen_now_state_test.dart` | test | unit + widget | extend both groups |
| `test/screens/today_screen_test.dart` | test | widget | extend WR-01 focus-target group, edge-state assertions |
| `test/screens/today_timeline_model_test.dart` | test | unit | reuse `_breakChunk()` factory (already exists, lines 37-49) |

---

## Pattern Assignments

### 1. `now_state.dart` — the sealed `NowState` hierarchy + the one-line filter

**File:** `lib/screens/today/now_state.dart` (183 lines total — already read in full above)

The **entire LIVE-01 extension point** is this one clause at line 111-114:

```dart
  final allWork =
      chunks
          .where(
            (c) =>
                c.chunkType == ChunkType.work && c.displayStartMinutes != null,
          )
          .toList()
        ..sort(
          (a, b) => a.displayStartMinutes!.compareTo(b.displayStartMinutes!),
        );
```

Drop `c.chunkType == ChunkType.work &&`, keeping only `c.displayStartMinutes != null`. Every
other line in the function (the `while (active.isCompleted || active.isSkipped)` advance-loop at
lines 149-167, the `Active`/`Overdue` branch at 176-181) is chunk-type-agnostic — do not touch
them. Rename `allWork` to something generic (e.g. `scheduled`) throughout the function body and
update comments that say "work chunks"/"work-chunk windows" (lines 60, 68, 108, 120, 143) to say
"chunks"/"chunk windows" — stale comments here are exactly the kind of thing CLAUDE.md-style
hygiene flags.

**KEY INVARIANT doc comment (lines 83-85) must survive unedited in spirit:**
```dart
/// KEY INVARIANT: clock-window is found FIRST by time, THEN resolution is
/// checked. This prevents re-creating the "first unresolved" bug (RESEARCH
/// Anti-pattern / Pitfall 3).
```
Any executor edit must re-verify this ordering is unchanged — the loop structure itself needs no
change, only its input set.

**The sealed hierarchy itself (lines 13-56) needs NO structural change** — `Active`, `Overdue`,
`GapBeforeNext`, `PreStart`, `DayComplete` all already carry `ScheduledChunk` references generically
(no `chunkType` field access anywhere in this file). Breaks slot in for free once the filter drops.

**Do not touch:** the minute-only clock sampling at line 106 (`currentMinutes = nowDt.hour * 60 +
nowDt.minute`) — seconds precision belongs only in `today_screen.dart`'s `_buildLiveRow`, never
here (Pitfall 4 in RESEARCH).

---

### 2. `today_screen.dart` — the existing timer pattern (mirror exactly)

**File:** `lib/screens/today/today_screen.dart`

**Field + lifecycle (lines 68, 108-140):**
```dart
Timer? _nowTimer;
...
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  _startNowTimer();
  _checkReviewWindow();
}

/// Starts (or restarts) the 1-minute periodic timer that triggers a
/// rebuild so the current-moment classification is re-evaluated with
/// fresh [_nowFn] output. Idempotent: cancels any running timer first.
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

@override
void dispose() {
  _nowTimer?.cancel();
  _dayScrollController.dispose();
  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
}
```

**The new `_fastTimer` must mirror this shape exactly** — idempotent start, `if (mounted)
setState({})` guard, cancelled in `dispose()`, cancelled in the `paused` branch of
`didChangeAppLifecycleState`, and — per RESEARCH — only *conditionally* restarted on `resumed`
(re-checked against the fresh clock, not blindly restarted like `_nowTimer`). RESEARCH's
recommended concrete shape (already vetted against this exact pattern):

```dart
Timer? _fastTimer;  // new: 1-second cadence, only while <60s remain on the live chunk

// Called once per build(), after computing nowState + the live chunk's raw seconds-remaining.
// Idempotent — safe to call every build.
void _syncFastTimer(bool shouldBeRunning) {
  if (shouldBeRunning && _fastTimer == null) {
    _fastTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  } else if (!shouldBeRunning && _fastTimer != null) {
    _fastTimer!.cancel();
    _fastTimer = null;
  }
}
```
Call from `build()` (plain field mutation, not itself a `setState` — safe synchronously). Add
`_fastTimer?.cancel()` next to the existing `_nowTimer?.cancel()` in both `dispose()` and the
`paused` branch of `didChangeAppLifecycleState`.

**`_nowFn` clock seam (line 61) — read time only through this, never `DateTime.now()` directly:**
```dart
late final DateTime Function() _nowFn = widget.now ?? DateTime.now;
```
A prior code review already caught and fixed one drift from this discipline (STATE.md commit
`1035339`) — the new seconds-remaining calc must use `_nowFn().second` the same way `_buildLiveRow`
already uses `_nowFn().hour`/`.minute`.

---

### 3. The AppBar "Start focus" target switch — highest-severity fix

**File:** `lib/screens/today/today_screen.dart:658-677`

```dart
AppBar _buildAppBar(
  BuildContext context,
  DailySchedule? schedule,
  NowState? nowState,
) {
  // Focus target is derived from the SAME nowState the rest of the screen
  // renders from (P1 / 22-PATTERNS.md section 5) — not a fresh
  // first-unresolved-chunk scan. That old scan could disagree with what
  // the live row visually presents as "now" whenever an earlier chunk was
  // left unresolved (WR-01). DayComplete (and no schedule at all) has no
  // meaningful focus target, so the button is disabled rather than
  // guessing.
  final ScheduledChunk? focusTarget = switch (nowState) {
    Active(:final current) => current,
    Overdue(:final overdue) => overdue,
    GapBeforeNext(:final next) => next,
    PreStart(:final firstChunk) => firstChunk,
    DayComplete() => null,
    null => null,
  };
  return AppBar(
    ...
    IconButton(
      icon: const Icon(Icons.center_focus_strong_outlined),
      tooltip: 'Start focus',
      onPressed: focusTarget == null
          ? null
          : () => context.push('/focus', extra: focusTarget.id),
    ),
    ...
  );
}
```

Once `resolveNowState`'s filter broadens, every one of the four non-null arms (`Active.current`,
`Overdue.overdue`, `GapBeforeNext.next`, `PreStart.firstChunk`) can resolve to a break. The fix
must exclude break chunks explicitly, matching the existing `DayComplete()/null → null`
disabled-button precedent already in this same switch — e.g. wrap the resolved chunk and add a
`chunkType != ChunkType.work → null` check (exact shape left to the executor, but it must reuse
this switch's structure, not add a parallel check elsewhere — see Pitfall 1 below).

---

### 4. `LiveRowCard`'s injected-string contract — must not be broken

**File:** `lib/screens/today/widgets/live_row_card.dart:17-27`

```dart
class LiveRowCard extends StatelessWidget {
  const LiveRowCard({
    super.key,
    required this.chunkId,
    required this.kicker,
    required this.title,
    required this.remainingLabel,
    required this.progress,
    this.nextLine,
    this.showActions = true,
  });
```

Doc comment (lines 8-11) is explicit and load-bearing:
> `kicker` and `remainingLabel` are INJECTED BY THE SCREEN — Phase 23's LIVE-01 ("RIGHT NOW —
> RESTING" for a running break) and LIVE-02 (countdown granularity) own what goes into them. A
> future agent extends the caller that builds this widget, not this widget's layout.

**This file should receive zero changes in Phase 23.** All new logic — the break kicker/title
branch, the seconds-vs-minutes remaining label — belongs in `_buildLiveRow` in `today_screen.dart`
(lines 530-584), which is the sole caller (`showActions: chunk.chunkType == ChunkType.work` at
line 582 already correctly gates Complete/Skip for breaks — no change needed there).

`_buildLiveRow`'s current shape to extend (lines 530-584):
```dart
Widget _buildLiveRow(
  BuildContext context,
  ScheduledChunk chunk,
  NowState nowState,
) {
  final title = _chunkTitle(context, chunk);
  ...
  String remainingLabel;
  double progress;
  if (nowState is Active && start != null && end != null) {
    final nowDt = _nowFn();
    final nowMinutes = nowDt.hour * 60 + nowDt.minute;
    final rawMinLeft = end - nowMinutes;
    final minLeft = rawMinLeft.clamp(0, chunk.durationMinutes).toInt();
    remainingLabel = '$minLeft min left · until ${formatMinutes(end)}';
    progress = chunk.durationMinutes == 0
        ? 1.0
        : (nowMinutes - start) / chunk.durationMinutes;
  } else if (start != null && end != null) {
    remainingLabel = formatTimeRange(start, end);
    progress = 1.0;
  } else {
    remainingLabel = '${chunk.durationMinutes} min';
    progress = 0.0;
  }
  ...
  return LiveRowCard(
    chunkId: chunk.id,
    kicker: 'RIGHT NOW',
    title: title,
    remainingLabel: remainingLabel,
    progress: progress,
    nextLine: nextLine,
    showActions: chunk.chunkType == ChunkType.work,
  );
}
```
LIVE-01 needs `kicker: chunk.chunkType == ChunkType.work ? 'RIGHT NOW' : 'RIGHT NOW — RESTING'`
and `title` branching to `'Taking a break'`/`'Taking a long break'` when the chunk is a break
(these two literal strings are LOCKED, `23-CONTEXT.md` decision 2 — do not reuse them for the
"Next · …" line, see pattern 5 below). LIVE-02's seconds branch is additive inside the `if
(nowState is Active …)` arm only — RESEARCH's derivation confirms the existing whole-minute math
is already ceil-equivalent, so only the `<60s` branch and the `_syncFastTimer` call are new.

**`_chunkTitle` — shared title helper, currently work-only (line 518-524):**
```dart
/// Builds a single title string for a chunk: the goal name, or (for
/// commitment/unattached chunks) the rationale, or a plain fallback.
String _chunkTitle(BuildContext context, ScheduledChunk chunk) {
  final goalName = _lookupGoalName(context, chunk);
  if (goalName != null && goalName.isNotEmpty) return goalName;
  return chunk.rationale.isNotEmpty ? chunk.rationale : 'Work block';
}
```
This is called from `_buildLiveRow`'s "Next · …" line (568-573) and `_buildEdgeStateLine`'s
`PreStart`/`GapBeforeNext` bodies (306, 328) — all four call sites need break-awareness. Add a
`chunkType` branch here (or a new sibling helper) returning `'Short break'`/`'Long break'` for
breaks referenced as "Next" — matching the exact strings already used by the non-live break row
elsewhere on this screen, extracted below.

**Reference: existing "Short break"/"Long break" strings (non-live convention to reuse):**
`lib/screens/schedule/widgets/chunk_card.dart:90-94`
```dart
Widget _buildBreak(BuildContext context) {
  final theme = Theme.of(context);
  final title = chunk.chunkType == ChunkType.shortBreak
      ? 'Short break'
      : 'Long break';
```
Use these two strings (not "Taking a break…") anywhere a break is the **next** chunk, not the
**current** one — the "Taking a break"/"Taking a long break" pair is locked specifically for the
live row's own title (`23-CONTEXT.md` decision 2 scopes it to "the current activity").

**`_buildEdgeStateLine` — PreStart/GapBeforeNext/DayComplete copy to update (lines 295-381):**
```dart
Widget _buildEdgeStateLine(BuildContext context, NowState nowState) {
  ...
  switch (nowState) {
    case PreStart(:final firstChunk):
      final title = _chunkTitle(context, firstChunk);
      return Padding(
        ...
        child: Column(
          ...
          children: [
            Text(
              'Your day starts at '
              '${formatMinutes(firstChunk.displayStartMinutes!)}',
              style: headingStyle,
            ),
            const SizedBox(height: 24),
            Text(
              '$title · ${firstChunk.durationMinutes} min',
              style: bodyStyle,
            ),
          ],
        ),
      );
    case GapBeforeNext(:final next):
      ... // heading: 'Up next' — LOCKED unchanged per RESEARCH's recommended
          // reading of the ambiguous UI-SPEC sentence (Assumption A1) —
          // planner must state which reading it chose
    case DayComplete():
      return Padding(
        ...
        children: [
          Text("That's a wrap", style: headingStyle),
          const SizedBox(height: 24),
          Text(
            "You've reached the end of today's schedule.",
            style: bodyStyle,
          ),
        ],
      );
    case Active():
    case Overdue():
      return const SizedBox.shrink();
  }
}
```
LIVE-03's LOCKED replacements (verbatim from `23-CONTEXT.md`/`23-UI-SPEC.md`):
- `PreStart` heading: `'Your day starts at ${formatMinutes(...)}'` → **`'Nothing until
  ${formatMinutes(firstChunk.displayStartMinutes!)}'`** (e.g. "Nothing until 8:00am"); body:
  `'$title · $duration min'` → **`'The day starts with $title. Until then the time is yours.'`**
  (breaks never appear as `firstChunk` — confirmed by RESEARCH, `schedule_generator.dart` STEP C
  always orders a work chunk first — so no break-title handling needed in this one branch).
- `DayComplete` heading: `"That's a wrap"` → **`"That's the day."`**; body: `"You've reached the
  end of today's schedule."` → **`"Everything scheduled is behind you."`**
- `GapBeforeNext`: no new copy given — default to no structural change (keep `'Up next'` heading
  and existing body), but its `_chunkTitle(context, next)` call must go through the new
  break-aware helper since `next` can now be a break chunk.

---

### 5. Test patterns — templates to mirror

**File:** `test/screens/today_screen_now_state_test.dart`

**Chunk-fixture factories already present (lines 83-101, and the sibling file's break factory):**
```dart
// today_screen_now_state_test.dart:83-101 (work chunk factory)
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
```dart
// today_timeline_model_test.dart:37-49 (break chunk factory — reuse/port this,
// per RESEARCH, rather than inventing a new one)
ScheduledChunk _breakChunk({
  String id = 'break-1',
  int? syntheticStartMinutes,
  int durationMinutes = 5,
}) {
  return ScheduledChunk(
    id: id,
    chunkTypeIndex: ChunkType.shortBreak.index,
    durationMinutes: durationMinutes,
    rationale: '',
    syntheticStartMinutes: syntheticStartMinutes,
  );
}
```
Note `_breakChunk` has no `isCompleted`/`isSkipped` params — add them if a break-as-`Overdue` or
break-resolution test needs them (RESEARCH flags this as structurally near-impossible but worth a
defensive test).

**Complete `resolveNowState` unit test to mirror** (`today_screen_now_state_test.dart:167-177`,
the `Active` case — template for a new "active: break window" test):
```dart
test('active: now within chunk window (9am, chunk 8:30–9:30)', () {
  final chunks = [
    _workChunk(syntheticStartMinutes: 510, durationMinutes: 60),
  ]; // 8:30–9:30
  final state = resolveNowState(
    chunks: chunks,
    now: () => DateTime(2026, 6, 13, 9, 0), // 9:00 AM
  );
  expect(state, isA<Active>());
  expect((state as Active).current.displayStartMinutes, 510);
});
```
New break-aware equivalent: swap `_workChunk` for `_breakChunk`, assert `Active.current` is the
break; separately write a `Active.next`-is-a-break case using two chunks (work then contiguous
break) modeled on the `Overdue` test at lines 179-195 which already demonstrates the two-chunk
`next` assertion shape (`s.next?.id`).

**Complete timer/lifecycle widget test to mirror** (`today_screen_now_state_test.dart:635-746`,
full text already in context above) — key structural elements to replicate for the new fast-timer
test group:
- Mutable `DateTime injectedNow` closed over by the `now:` callback passed to `_pumpTodayScreen`.
- `await tester.pump(const Duration(minutes: 1))` to fire the existing timer — for the fast timer,
  the equivalent is `await tester.pump(const Duration(seconds: 1))` after setting `injectedNow` to
  a time within the final 60 seconds of an active chunk.
- The WR-03 no-double-timer pattern (lines 705-745): cycle `paused`→`resumed` twice via
  `tester.binding.handleAppLifecycleStateChanged(...)`, then assert a call-count baseline is
  stable, not doubled. Extend this same pattern to assert no leaked `_fastTimer` specifically
  (pause mid-final-minute, resume, confirm exactly one 1-second timer is running via the same
  call-counting technique).
- **Never use `Future.delayed`/real sleeps** — always `tester.pump(Duration)` against the injected
  clock (RESEARCH: a real-time-sleep test hangs the runner rather than failing cleanly).
- Any `Timer` left running when a test ends fails with *"A Timer is still pending even after the
  widget tree was disposed"* — the new `_fastTimer` must be cancelled in `dispose()` exactly like
  `_nowTimer` (see pattern 2 above) or every test exercising the <60s branch will fail this way.

**`_pumpTodayScreen` helper (lines 108-127ish)** — the provider-tree pump wrapper all widget tests
use; new tests should call this exact helper, not hand-roll a new `pumpWidget`.

---

## Shared Patterns

### Injectable clock discipline
**Source:** `today_screen.dart:61` (`_nowFn`), enforced codebase-wide per STATE.md commit
`1035339` (a prior review caught a `DateTime.now()` drift).
**Apply to:** any new code computing seconds-remaining or driving `_syncFastTimer`. Never call
`DateTime.now()` directly inside `_TodayScreenState`.

### Single now-detector invariant
**Source:** `now_state.dart:97` (`resolveNowState`, the app's only now-classifier — Phase 22
deleted two competing ones and a review killed a third) and `today_screen.dart:727-731` (the P1
comment: `resolveNowState` is called exactly once per `build()`).
**Apply to:** all new break-awareness logic. No new `if (chunk.chunkType == ChunkType.work)`
conditional should appear anywhere except: the shared title helper, the existing `showActions`
gate, `SwipeableChunkCard`'s dismiss gate, and the new focus-target exclusion. Any other new
chunkType check is a second computation path — a regression per RESEARCH Pitfall 1.

### Timer lifecycle mirror
**Source:** `today_screen.dart:108-140` (`_nowTimer` full lifecycle, reproduced under pattern 2
above).
**Apply to:** the new `_fastTimer` — same idempotent start, same `mounted` guard, same
dispose/pause cancellation, same resume re-evaluation (though resume must re-check remaining time,
not blindly restart).

---

## No Analog Found

Not applicable in the traditional sense — this phase creates no new files. Every change is an
in-place extension of an existing file, and the "analog" for each extension is the file's own
pre-existing convention (documented above), not an external file.

## Metadata

**Files read in full:** `now_state.dart` (183 lines), `live_row_card.dart` (158 lines),
`today_screen.dart` (targeted: 1-145, 290-385, 505-620, 655-735), `chunk_card.dart` (targeted:
80-100), `today_screen_now_state_test.dart` (targeted: 1-60, 83-101, 151-230, 635-748),
`today_timeline_model_test.dart` (targeted: 37-51).
**Pattern extraction date:** 2026-08-07

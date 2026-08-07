# Phase 23: Live Activity Tracking - Research

**Researched:** 2026-08-07
**Domain:** In-repo Flutter state machine + widget-tree extension (no new dependencies)
**Confidence:** HIGH

## Summary

This phase extends exactly two pure functions and one stateful widget that Phase 22 just
finished consolidating: `resolveNowState` (`lib/screens/today/now_state.dart:97`, the app's
**only** now-detector), `buildTimeline` (`lib/screens/today/timeline.dart`, which derives
`isLive` purely from `resolveNowState`'s output), and `_TodayScreenState` (`lib/screens/today/
today_screen.dart`, which owns the 1-minute `Timer.periodic`, the injectable `_nowFn` clock
seam, and the string-injection contract into `LiveRowCard`). All three of LIVE-01/02/03's
design questions are already answered by `23-CONTEXT.md` and `23-UI-SPEC.md` (both LOCKED by
Dan on 2026-08-07) — this research's job is to trace exactly where in the existing code each
locked decision lands, and to flag the places a naive implementation would regress something
Phase 22 just fixed.

The single biggest risk is **not** the tick-granularity math (that's a small, well-contained
change) — it's that broadening `resolveNowState`'s filter from work-chunks-only to
work-and-break chunks changes what `Active.next` / `Overdue.next` / `GapBeforeNext.next` can
point at. Because breaks are scheduled *immediately after* nearly every work chunk
(`schedule_generator.dart` STEP C), the very next unresolved chunk after an active work chunk
is now very often the break that follows it — not the next work chunk. This is not a rare edge
case; it is the **common case** any day the mood-scaled break cadence inserts a break (which is
most days). Any code path that renders a "next" chunk's title (`_chunkTitle`, the "Next · …"
line, the `GapBeforeNext` body, and — importantly — the AppBar's "Start focus" target) must be
made break-aware, or it will render `'Work block'` for what is actually the upcoming break, or
push a 25-minute Pomodoro focus timer onto what is meant to be rest.

**Primary recommendation:** Extend `resolveNowState`'s filter to include break chunks (drop the
`chunkType == ChunkType.work` clause entirely — filter only on `displayStartMinutes != null`,
since the algorithm itself is already chunk-type-agnostic). Add one small, shared,
break-aware title/kicker helper used everywhere a chunk (current OR next) is rendered as text.
Exclude break chunks from the AppBar's focus-target derivation. For the tick, add a second,
narrowly-scoped `Timer?` (`_fastTimer`) alongside the existing `_nowTimer`, started only while
the live chunk has <60s left and cancelled otherwise/on background/on dispose — both timers
drive the *same* whole-screen `setState(() {})`, preserving the single-rebuild-per-tick
invariant Phase 22 already established rather than introducing a second, independently-ticking
widget subtree.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Now-state classification (which chunk is "now") | Browser/Client (pure Dart fn) | — | `resolveNowState` is a pure function over in-memory `ScheduledChunk` list + injected clock; no persistence, no network |
| Countdown tick / timer lifecycle | Browser/Client (widget State) | — | `Timer.periodic` lives in `_TodayScreenState`, paused/resumed via `WidgetsBindingObserver` — this is Flutter client-side state, there is no server tier in this app |
| Break/edge-state copy | Browser/Client (widget build methods) | — | String templates live in `today_screen.dart`'s private `_build*` methods; no i18n layer, no backend-sourced copy |
| Persisted chunk resolution (isCompleted/isSkipped) | Database/Storage (Hive) | Browser/Client (ScheduleNotifier) | Unaffected by this phase — breaks already can't be marked resolved from any UI path (verified below) |

*(This phase has no CDN, no SSR, no API tier — Canopy is a single-tier local Flutter app with a
Hive-backed local database; two of the five standard tiers are structurally absent here.)*

## Project Constraints (from CLAUDE.md)

- **No LLM / no "smart" suggestions / no in-app AI surface** — irrelevant risk for this phase
  (pure deterministic clock arithmetic), stated for completeness per the mandatory directive.
- **Debug build hosting for UAT**: `flutter build web --debug --source-maps --pwa-strategy=none`,
  served statically — not `flutter run -d web-server`. Relevant if/when this phase is
  demonstrated live; not relevant to implementation or automated tests.
- Dart SDK `^3.10.3`, Flutter `>=3.18.0-18.0.pre.54` — both already satisfy every Dart/Flutter
  API surface this phase needs (`Timer.periodic`, `DateTime`, `Duration`, `WidgetsBindingObserver`
  — all long-stable core APIs, no version risk).

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LIVE-01 | A running break reads as a break, never as empty/idle time | §"Break-aware now-state" below: broaden `resolveNowState`'s filter, add break-aware title/kicker helper, exclude breaks from focus-target |
| LIVE-02 | Time remaining counts down while the screen is open; tick granularity decided and justified | §"Tick granularity" below: whole-minutes (ceil) ≥60s, seconds <60s — already LOCKED by Dan; this research documents the concrete dual-timer implementation shape and confirms the existing minute-truncation math already IS ceil-equivalent |
| LIVE-03 | Pre-start / gap / day-complete each read distinctly and truthfully | §"Edge states" below: exact current vs. locked-new copy diffed line by line; flags the one genuinely ambiguous case (gap banner) as an Open Question |
</phase_requirements>

## `resolveNowState` As It Stands Today

Full read of `lib/screens/today/now_state.dart` (183 lines). Five subtypes, all in one
`sealed class NowState` hierarchy (lines 13–56):

| Subtype | Fields | Meaning |
|---|---|---|
| `PreStart` | `firstChunk` | now < first chunk's window start |
| `Active` | `current`, `next` | now inside `current`'s window; `next` = first unresolved chunk after it |
| `Overdue` | `overdue`, `next` | now ≥ `current`'s window end but `current` still unresolved |
| `GapBeforeNext` | `next` | current chunk resolved (completed/skipped), `next`'s window hasn't opened, but `next` exists — day NOT over |
| `DayComplete` | (none) | all windows passed, or all resolved, or no chunks with a clock position |

**The work-chunks-only filter** is a single line: `now_state.dart:113` —
```dart
final allWork = chunks
    .where((c) => c.chunkType == ChunkType.work && c.displayStartMinutes != null)
    .toList()
  ..sort((a, b) => a.displayStartMinutes!.compareTo(b.displayStartMinutes!));
```
This is the entire extension point for LIVE-01. Every other line in the function operates on
`allWork` generically (by `displayStartMinutes`, `durationMinutes`, `isCompleted`, `isSkipped`)
— **the algorithm itself has no work-chunk-specific logic**. Dropping `c.chunkType ==
ChunkType.work &&` (filtering only on `displayStartMinutes != null`) is sufficient and requires
no other change inside this function body. [VERIFIED: full file read]

**Single now-detector confirmed live.** `grep -rn "resolveNowState" lib/` returns exactly one
definition (`now_state.dart:97`) and exactly one call site (`today_screen.dart:731`)
[VERIFIED: grep, 2026-08-07]. `23-CONTEXT.md`'s own carry-forward note about this is itself
stale in one respect — see "Correcting stale CONTEXT.md pointer" below — but the single-detector
claim is independently re-verified here and holds.

**KEY INVARIANT (must survive):** "clock-window is found FIRST by time, THEN resolution is
checked" (doc comment, `now_state.dart:83-85`). This is what the `while (active.isCompleted ||
active.isSkipped)` loop (lines 149-167) implements: it never promotes a chunk whose window
hasn't opened yet, regardless of resolution state of a chunk before it. Broadening the filter to
include breaks does not touch this loop's logic — it only changes what's *in* `allWork` before
the loop runs.

### Correcting a stale pointer in the upstream docs

`23-CONTEXT.md` line 66 says: *"Its unit tests live in `test/screens/active_chunk_card_test.dart`
… extend them rather than replacing the pattern."* **This file no longer exists** — Phase
22-04 deleted it (`22-04-SUMMARY.md` "Deleted" list) after confirming its 14 cases were all
covered elsewhere. The `resolveNowState` unit-test group now lives, byte-identical, in
`test/screens/today_screen_now_state_test.dart:151-391` (see 22-04-SUMMARY.md line 84: *"the
`resolveNowState` unit-test group left byte-identical … `active_chunk_card_test.dart` was
deleted"*). **STATE.md's "UI Constraints (carry-forward for Phase 23)" section (rewritten
2026-08-07, after CONTEXT.md was gathered) has the correct, current path** — trust STATE.md and
the code over this one stale line in CONTEXT.md. `REQUIREMENTS.md`'s pointer
(`home_screen.dart:115`) is also stale for the same reason (file deleted); its five-state
description of `resolveNowState` remains accurate, only the file path moved.

## Tick Granularity — Implementation Shape (decision already LOCKED)

**The decision itself is not open** — `23-CONTEXT.md` decision 1 and `23-UI-SPEC.md`
"Countdown granularity" both lock: whole minutes (rounded **up**) while ≥60s remain, seconds
while <60s remain. This section documents *how* to implement that against the current code,
which is the part actually left to plan.

### What needs to move

`23-UI-SPEC.md`'s table is explicit: `≥60s → "3 min left · until 10:50am"`, `<60s → "42s left ·
until 10:50am"`. So: **no**, the countdown never needs true per-second wall-clock movement for
the bulk of an activity — only mm:ss-style precision in the final 60 seconds, and even then it's
`Ns left` (seconds only, no minutes:seconds format) since the whole-minutes format never reaches
this branch.

### The existing minute math is already ceil-equivalent — do not rewrite it

`_buildLiveRow`'s current `Active` branch (`today_screen.dart:547-555`):
```dart
final nowDt = _nowFn();
final nowMinutes = nowDt.hour * 60 + nowDt.minute;
final rawMinLeft = end - nowMinutes;
final minLeft = rawMinLeft.clamp(0, chunk.durationMinutes).toInt();
remainingLabel = '$minLeft min left · until ${formatMinutes(end)}';
```
Because `nowMinutes` truncates seconds and `end` is always a whole minute (both
`displayStartMinutes` and `durationMinutes` are `int`), `end - nowMinutes` is algebraically
identical to `ceil(exact_seconds_remaining / 60)` for every value where `exact_seconds_remaining
> 0` [VERIFIED: derivation — for `secondsIntoMinute ∈ [0,59]`, `exact_remaining/60 = rawMinLeft
- secondsIntoMinute/60 ∈ (rawMinLeft - 1, rawMinLeft]`, whose ceiling is always `rawMinLeft`].
**This means the "3 min left" line already satisfies decision 1's "round up" requirement without
any change** — the only gap is that today it never switches to a seconds display in the final
minute; it just keeps showing `1 min left` (technically correct-but-coarse) all the way to `0
min left` at the exact instant the window ends, then the value hits the `.clamp(0, …)` floor.
The new work is purely: (a) get second-level precision from `_nowFn()`, (b) branch the label
format below 60s, (c) escalate the timer so the display actually refreshes at 1Hz during that
final minute (today the whole-minute display would just sit at "1 min left" for the full 60
seconds since the 1-minute timer wouldn't fire again until the boundary).

### Recommended timer shape: two timers, one shared rebuild — not a scoped sub-widget

**Recommendation: keep the existing whole-screen `setState(() {})` rebuild model. Add a second,
narrowly-scoped `Timer? _fastTimer` alongside the existing `_nowTimer` field
(`today_screen.dart:68`). Do not introduce a `ValueListenableBuilder`/`AnimatedBuilder` subtree
scoped to just the live row.**

Reasoning:

1. **Cost is bounded, not continuous.** The fast timer only exists while the live chunk (work
   *or* break) has <60s left — at most 60 wakeups per activity transition, not per day, not
   continuously. `today_screen.dart`'s own doc comment (lines 784-789) already establishes that
   this screen deliberately uses `SingleChildScrollView` + eager `Column` (not
   `ListView.builder`) because "a day is bounded at a few dozen rows, so eager layout is the
   cheap correct answer" — every row is already built on every 1-minute tick today, and none of
   those rows do expensive layout (`Text`, `Card`, one `CustomPainter` for the dashed break
   border in `chunk_card.dart`, which doesn't change per-tick). A full rebuild of ~dozens of
   simple, non-relayouting widgets once per second for at most 60 seconds is well inside a
   single frame budget on every target platform this app ships to (mobile/web/desktop) — this is
   the same order of magnitude of work the existing 1-minute timer already does every tick,
   just 60x more often for a bounded window.
2. **A scoped sub-widget would violate the contract Phase 22 just wrote.** `LiveRowCard`'s doc
   comment (`live_row_card.dart:8-11`) is explicit: *"`kicker` and `remainingLabel` are INJECTED
   BY THE SCREEN … A future agent extends the caller that builds this widget, not this widget's
   layout."* Making `LiveRowCard` self-tick (own `Timer`/`AnimationController`, recompute its
   own remaining-time string) would mean re-deriving remaining-time logic *inside* the widget —
   a second computation path parallel to `_buildLiveRow`'s, which is exactly the kind of
   duplicate-detector risk Phase 22 spent an entire plan eliminating (three competing
   now-detectors → one). Keep the computation in `_TodayScreenState`, where `resolveNowState` is
   already called exactly once per build (the P1 invariant, `today_screen.dart:727-730`).
3. **Precedent for scoped animation exists in this codebase but doesn't apply here.**
   `breathing_pulse_cta.dart` does use its own `AnimationController` +
   `SingleTickerProviderStateMixin` for a decorative glow — but that animation is entirely
   self-contained (no data flows in from the screen). The live-row countdown is the opposite: its
   value is derived from `chunk` + `nowState`, both computed in `_TodayScreenState.build()`. A
   self-ticking countdown widget would need those inputs re-plumbed in, which is more machinery
   than just widening the existing timer.
4. **Idempotency and lifecycle must mirror `_startNowTimer` exactly**, including the
   paused/resumed handling already in place (`didChangeAppLifecycleState`,
   `today_screen.dart:126-132`) — the fast timer must be cancelled on pause and only restarted
   on resume if the live chunk is *still* in its final minute after recomputing from the fresh
   clock (not blindly restarted, since the app could resume minutes later, past the chunk
   entirely).

**Concrete shape:**
```dart
Timer? _nowTimer;   // existing: 1-minute cadence, always running while resumed
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
Call `_syncFastTimer(...)` from `build()` (a plain field mutation + `Timer` start/cancel is not
a widget rebuild and is safe to run synchronously inside `build()` — it does not call `setState`
itself). Cancel `_fastTimer` in `dispose()` and in the `paused` branch of
`didChangeAppLifecycleState` alongside the existing `_nowTimer?.cancel()`.

**Seconds-remaining source:** needs `_nowFn().second`, not just `.hour`/`.minute` — a small,
localized addition to `_buildLiveRow`'s `Active` branch only (the resolution/gap/pre-start/
day-complete paths never show a countdown and don't need this). Compute
`rawSecondsLeft = (end * 60) - (nowDt.hour * 3600 + nowDt.minute * 60 + nowDt.second)`,
clamp to `[0, chunk.durationMinutes * 60]`, then branch: `>= 60 → '${(rawSecondsLeft / 60).ceil()}
min left · until …'`, `< 60 → '${rawSecondsLeft}s left · until …'`. This is purely additive to the
existing branch; the `Overdue`/pre-start/day-complete branches are untouched (they never show a
live countdown today and LIVE-02 doesn't ask them to).

**`resolveNowState`'s own minute-only comparison is untouched.** The "FRAME-OF-REFERENCE" doc
comment (`now_state.dart:87-96`) and the "sample now() exactly once" comment (lines 101-104) are
both about *which chunk is active*, a minute-granularity question by design (chunk windows are
defined in whole minutes) — LIVE-02's seconds precision is purely a **display** concern inside
`_buildLiveRow`, not a `resolveNowState` concern. Do not add seconds to `resolveNowState`.

## Break-Aware Now-State (LIVE-01)

### The filter change

As shown above: `now_state.dart:113`'s `c.chunkType == ChunkType.work &&` clause is the entire
fix at the `resolveNowState` level. After removing it, `allWork` (rename to something generic —
e.g. `scheduled` — since it's no longer work-only; every doc comment referencing "work-chunk
windows" in this file should be updated to say "chunk windows" for accuracy, per CLAUDE.md-style
hygiene of not leaving misleading comments).

### Why "next" is the actually dangerous part, not "current"

Breaks are inserted **immediately after** the work chunk they follow
(`schedule_generator.dart:636-641`):
```dart
if (chunk.syntheticStartMinutes != null) {
  breakChunk.syntheticStartMinutes = chunk.syntheticStartMinutes! + chunk.durationMinutes;
}
```
— contiguous, no gap. This means: once breaks participate in `allWork`/`scheduled`, for **any**
work chunk that has a reserved break (most work chunks, on a normal mood-scaled day —
BREAK-01/02), `Active(workChunk).next` and `Overdue(workChunk).next` will resolve to **the
break immediately following it**, not to the next work chunk further down the day. This is the
common case, not an edge case: any day with more than `longBreakEvery` work chunks has this
happen repeatedly.

Concretely, everywhere a `next`/`overdue`/`current` chunk's *title* is rendered, it must handle
`ChunkType.shortBreak`/`ChunkType.longBreak`:

| Call site | Current behavior on a break chunk | Fix needed |
|---|---|---|
| `_chunkTitle` (`today_screen.dart:520-524`) | `goalName` is `null` for breaks (`goalId` is always null) → falls to `chunk.rationale` (always `''` for breaks, `schedule_generator.dart:634`) → falls to hardcoded `'Work block'` — **wrong** | Add a `chunkType` branch before the goal-name fallback |
| `_buildLiveRow`'s "Next · …" line (`today_screen.dart:567-573`) | Calls `_chunkTitle(context, nextChunk)` — inherits the bug above whenever `nextChunk` is a break | Fixed automatically once `_chunkTitle` is fixed (shared helper) |
| `_buildEdgeStateLine`'s `GapBeforeNext` body (`today_screen.dart:326-358`) | Calls `_chunkTitle(context, next)` and `_lookupGoalName` — same bug if `next` is a break (see "GapBeforeNext can now target a break" below) | Same shared-helper fix |
| `_buildAppBar`'s `focusTarget` (`today_screen.dart:670-677`) | Currently can only ever be a work chunk (filter excluded breaks). After broadening, `Active`/`Overdue`/`GapBeforeNext`/`PreStart` can all resolve to a break, so `focusTarget` can become a break chunk id | **Must exclude breaks explicitly** — see below, this is the higher-severity fix |

**Recommended shape:** one small, shared helper (co-locate near `_chunkTitle` or promote to a
top-level function in `time_format.dart`/`now_state.dart` if the planner wants it reusable
outside this screen) that branches on `chunk.chunkType`:
- `ChunkType.work` → existing goal-name-then-rationale-then-`'Work block'` logic (unchanged).
- `ChunkType.shortBreak` → `'Short break'` (already the exact string `chunk_card.dart:92-94`
  uses for the non-live break row elsewhere on the same screen — reuse it for consistency when a
  break is referenced in a *non-live* context, e.g. a "Next · Short break at 9:25" line).
- `ChunkType.longBreak` → `'Long break'` (same source).

**Do not reuse `'Taking a break'`/`'Taking a long break'` for the "Next" line.** Those two
strings are LOCKED specifically for the live row's own title when the break *is* the current
activity (`23-CONTEXT.md` decision 2, `23-UI-SPEC.md` "Break as a current activity" table — both
scope this to the live row). "Next · Taking a break at 9:25" reads tense-mismatched (present
continuous for a future event); "Next · Short break at 9:25" matches the existing
`chunk_card.dart` convention already shipped and tested elsewhere on this same screen for the
non-live break row.

### `GapBeforeNext` can now target a break — confirm this is reachable, not just theoretical

This isn't hypothetical: the app already supports completing/skipping a work chunk **before**
its scheduled window naturally ends (`SwipeableChunkCard`, swipe-to-complete/skip — gated to
`chunk.chunkType == ChunkType.work` at `swipeable_chunk_card.dart:68`, so this is a normal,
everyday interaction for work chunks). If a user swipe-completes a work chunk 5 minutes into a
25-minute window, and that chunk had a reserved break immediately after it, `resolveNowState`'s
advance-loop (`now_state.dart:149-167`) will see the break's window hasn't opened yet
(`candidate.displayStartMinutes! > currentMinutes`) and return `GapBeforeNext(theBreak)` — a
completely normal, reachable state once breaks are included in the filter. This is exactly the
path the shared title helper above needs to cover; it is not a rare corner case gated behind
unusual timing.

### Breaks can never become "resolved" — confirmed, not a new risk

`isCompleted`/`isSkipped` on a break chunk can only ever be set via `ScheduleNotifier.markComplete
`/`markSkipped` (`schedule_notifier.dart:414-493`), and the only UI paths that call those are (a)
`LiveRowCard`'s Complete/Skip buttons, gated `showActions: chunk.chunkType == ChunkType.work`
(`today_screen.dart:582`, already correct, no change needed — confirmed matches `23-UI-SPEC.md`'s
"Complete/Skip: Absent" row for breaks), and (b) `SwipeableChunkCard`'s dismiss gesture, gated
`chunk.chunkType != ChunkType.work` returns un-dismissible (`swipeable_chunk_card.dart:68`, i.e.
breaks are excluded there too). **A break chunk's `isCompleted`/`isSkipped` are permanently
`false`** [VERIFIED: both gating call sites read] — so the `while (active.isCompleted ||
active.isSkipped)` advance-loop in `resolveNowState` will never try to "advance past" a break; a
break, once its window opens, is always eligible to be the active/overdue chunk. This means an
`Overdue` break state is structurally near-impossible in the normal contiguous-scheduling case
(the moment a break's window ends, the *next* work chunk's window opens at exactly that
boundary — `schedule_generator.dart:638-641` — so `candidates.last` becomes the next work chunk
before an overdue-break window can ever be observed). Existing `schedule_generator_test.dart`
(54 passing tests) already exercises the packer that produces this contiguity — this phase does
not need new generator-level tests for it, only a defensive check that the `_buildLiveRow`
`Overdue` display branch doesn't crash/mislabel if it's ever reached for a break (low priority,
covered by the shared title helper regardless).

### Focus-target exclusion — the highest-severity fix in this phase

`FocusScreen` (`lib/screens/focus/focus_screen.dart`) is a 25-minute Pomodoro companion timer
that calls `ScheduleNotifier.markComplete(widget.chunkId)` on completion and derives its "next"
break suggestion by literally indexing `chunks[idx + 1]` — it has **no concept of being opened
on a break chunk** and assumes its target is completable work. Today, the AppBar's "Start focus"
button (`today_screen.dart:686-696`) can only ever target a work chunk because
`resolveNowState`'s filter excludes breaks. **Once the filter is broadened, `focusTarget`
(`today_screen.dart:670-677`) can resolve to a break** whenever `nowState` is `Active`/`Overdue`/
`GapBeforeNext`/`PreStart` pointing at one — and tapping "Start focus" would push `/focus` with a
break's id, opening a 25:00 countdown UI and a markComplete action for something the product
position (`23-UI-SPEC.md`: "there is nothing to complete about a break") says explicitly has
nothing to complete. **Recommendation: explicitly exclude break chunks from `focusTarget`** —
when the resolved target chunk's `chunkType != ChunkType.work`, treat `focusTarget` as `null`
(button disabled), matching the existing `DayComplete()/null → null` disabled-button precedent
already in that switch. No existing test exercises this path today (all fixtures use only work
chunks) — this needs new coverage, not just a fix (see Validation Architecture below).

## Edge States (LIVE-03)

Diffed line-by-line, current vs. LOCKED-new (both from `_buildEdgeStateLine`,
`today_screen.dart:295-381`, and `23-CONTEXT.md` decision 3 / `23-UI-SPEC.md` "Edge states"):

| State | Current heading | Current body | LOCKED new heading | LOCKED new body |
|---|---|---|---|---|
| `PreStart` | `'Your day starts at ${formatMinutes(...)}'` | `'$title · $duration min'` | `'Nothing until 8:00am'` (time templated) | `'The day starts with Exercise. Until then the time is yours.'` (goal name templated) |
| `GapBeforeNext` | `'Up next'` heading + title/subtitle/start-time body | — (unchanged per CONTEXT/UI-SPEC — no new string given) | **no new copy specified** — see Open Question below | — |
| `DayComplete` | `"That's a wrap"` | `"You've reached the end of today's schedule."` | `"That's the day."` | `"Everything scheduled is behind you."` |

Both `PreStart` and `DayComplete` get **verbatim new sentences** in `23-CONTEXT.md` — these are
direct string replacements plus one new piece of interpolation for `PreStart` (the sentence
structure changes from "$title · $duration min" to a full sentence "The day starts with $title.
Until then the time is yours." — the `firstChunk` is always work-typed here, confirmed above
under "Why 'next' is the dangerous part" — breaks are never emitted before the first work chunk
in `schedule_generator.dart` STEP C's ordering, so no break-title handling is needed for
`PreStart`).

### Open Question: does the Gap banner change at all?

`23-UI-SPEC.md`'s "Edge states" table says gap is *"handled inline by Phase 22's named free-time
rows; the screen does not claim an activity is running when none is."* This sentence is
ambiguous between two readings:

1. **No change** — the existing `_buildEdgeStateLine` "Up next" banner (heading + title +
   subtitle + start-time body) already satisfies "distinct and truthful," and the sentence is
   just explaining *why* Dan didn't need to hand-write new gap copy (unlike PreStart/DayComplete)
   — because Phase 22's `GapFreeRow`/`LeadingFreeRow` inline rows already carry the "this is free
   time" signal in the list itself, so the banner doesn't need to duplicate it.
2. **Remove the banner** — `_buildEdgeStateLine`'s `GapBeforeNext` case should return
   `SizedBox.shrink()` (matching the `Active`/`Overdue` cases, which already render nothing
   because "the live row in the list speaks for those," `today_screen.dart:375-379`), relying
   entirely on the inline `GapFreeRow` to communicate the gap, with no separate "Up next" banner
   at all.

**Recommendation: reading 1 (no change) is the safer default** — `23-CONTEXT.md`'s decisions
section explicitly gives new strings for the two states it wants changed (PreStart,
DayComplete) and conspicuously does not give one for Gap; if Dan had wanted the banner removed,
the locked-decisions format used elsewhere in this same document (exact replacement string) would
most likely have been used here too. Reading 2 would also break five passing assertions today
(`find.text('Up next')` in `today_screen_now_state_test.dart:611` and
`today_screen_test.dart:566`, `find.text('Morning routine')` nearby, etc.) that are not flagged
anywhere as needing to change. **Still — flag this explicitly to the planner as a one-line
confirmation to seek (via `gsd-discuss-phase` follow-up or a `checkpoint:human-verify`) before
committing to "no change," since it is a genuine ambiguity in the locked source, not a research
judgment call this document can fully resolve.**

## Test Surface

### Existing coverage (420 tests, all green as of 2026-08-07 — [VERIFIED: `flutter test` run])

| File | Lines | Covers |
|---|---|---|
| `test/screens/today_screen_now_state_test.dart` | 748 | `resolveNowState` unit tests (pure, no pump) at lines 151-391; `TodayScreen` widget-pump tests (pre-start/active/overdue/day-complete/gap/timer-lifecycle) at lines 395-747 |
| `test/screens/today_timeline_model_test.dart` | 273 | `buildTimeline` pure unit tests — **already has a `_breakChunk()` factory** (lines 37-49) used today only for a "completed/skipped rows never filtered" structural check, not yet for `isLive`/now-state interaction — reuse this factory rather than inventing a new one |
| `test/screens/today_screen_test.dart` | 749 | Broader `TodayScreen` widget coverage: scaffold/AppBar, the day-as-one-list, centre-on-open, edge-state copy (Task 3, lines 450-614), the WR-01 focus-target regression group (line 616+) |

### The clock seam: `_nowFn` — use it, don't call `DateTime.now()`

`TodayScreen(now: ...)` (`today_screen.dart:47-49`) is the injectable clock; `_nowFn` (line 61)
is `late final`, assigned once in the field initializer from `widget.now ?? DateTime.now`. Every
existing test passes a `now:` closure. **A code review already caught and fixed one drift from
this discipline** (STATE.md: commit `1035339`) — any new countdown code must read time through
this same closure, never `DateTime.now()` directly, or it becomes untestable without real sleeps.

### How to test a countdown deterministically — no new package needed

**No `fake_async` package dependency exists or is needed.** `flutter_test`'s `testWidgets` binding
already runs inside a fake-clock zone; `tester.pump(Duration)` advances that fake clock and fires
any pending `Timer`/`Timer.periodic` callbacks scheduled within it — this is exactly the pattern
the existing "timer/lifecycle" test already uses successfully
(`today_screen_now_state_test.dart:635-746`, e.g. line 672: `await tester.pump(const
Duration(minutes: 1));` reliably fires the 1-minute `Timer.periodic` without any real elapsed
time). **The same pattern extends directly to the new 1-second fast timer**: mutate the injected
`now` closure's returned value, then `await tester.pump(const Duration(seconds: 1))`, and assert
the new label. No `FakeAsync` from `package:fake_async` is needed — `flutter_test`'s own binding
already provides equivalent fake-clock semantics for `testWidgets` bodies. [CITED:
flutter_test's `AutomatedTestWidgetsFlutterBinding` fake-clock `pump()` semantics, confirmed by
this codebase's own passing test at the line cited above]

**Pending-timer failures — explicit warning.** `flutter_test` fails a test with *"A Timer is
still pending even after the widget tree was disposed"* if any `Timer`/`Timer.periodic` created
during a test outlives that test's widget tree without being cancelled — this is thrown from
`_verifyInvariants` in `package:flutter_test/src/binding.dart` after every test completes.
[CITED: flutter/flutter GitHub issues #90861, #53296, #144472 — all describe this exact
assertion and its trigger condition] This is precisely why the new `_fastTimer` **must** be
cancelled in `dispose()` alongside the existing `_nowTimer?.cancel()` (`today_screen.dart:136`)
— a naive implementation that starts the fast timer but forgets to cancel it on dispose (or
forgets it in the `paused` lifecycle branch, since a test simulating backgrounding without
disposing would still trip this on the *next* test's setup if the zone leaked) will fail with
this exact message the first time a test exercises the <60s branch and then ends. A naive
real-time-sleep-based countdown test (`await Future.delayed(...)`) will also simply **hang** the
test runner for up to a minute per assertion rather than fail cleanly — always drive time via
`tester.pump(Duration)` against the injected clock, never real sleeps.

### New coverage needed (Wave 0 gaps)

- `resolveNowState` unit tests for a running break as `Active`/`Overdue` (using the existing
  `_breakChunk()`-style factory pattern from `today_timeline_model_test.dart`, ported into
  `today_screen_now_state_test.dart` or shared) — assert `Active.current` is the break, and
  separately assert `GapBeforeNext.next`/`Active.next`/`Overdue.next` can be a break (the
  "next-is-a-break" scenario described above).
- `buildTimeline` test: a break chunk marked `isLive: true` renders correctly through
  `ChunkRow` (the sealed-class plumbing already supports this — `ChunkRow` doesn't care about
  `chunkType` — this is likely a thin addition, not new logic).
- `LiveRowCard`/`_buildLiveRow` widget tests: kicker `'RIGHT NOW — RESTING'` + title `'Taking a
  break'`/`'Taking a long break'` for a live break, and **explicitly assert Complete/Skip buttons
  are absent** (`showActions` already wired correctly per Phase 22, but this phase should add a
  regression test locking it in, since no current fixture exercises a live break).
  the "Next · Short break at …" line rendering for a work chunk whose immediate next chunk is a
  break.
- Focus-target exclusion regression test: `nowState` resolves to a break (Active/Overdue/Gap/
  PreStart) → AppBar's "Start focus" `IconButton.onPressed` is `null` (disabled). This is new
  coverage, not an extension of an existing case — no current fixture uses a break as the "now"
  target anywhere in `today_screen_test.dart`'s WR-01 group.
- Fast-timer tests: (a) at 61s remaining, label reads `"2 min left"`; at 59s, `"59s left"` (the
  minute/second boundary); (b) the fast timer fires and updates the label via `tester.pump(const
  Duration(seconds: 1))` without a full minute pump; (c) fast timer is cancelled on
  pause/dispose — extend the existing WR-03-style no-double-timer pattern
  (`today_screen_now_state_test.dart:635-746`) to also assert no leaked `_fastTimer` after a
  paused→resumed cycle while inside the final minute.
- Edge-state copy tests: update/add assertions for the new PreStart (`'Nothing until 8:00am'`)
  and DayComplete (`"That's the day."`) strings — the existing tests asserting the *old* strings
  (`'Your day starts at'` at `today_screen_now_state_test.dart:414` and
  `today_screen_test.dart:532`; `"That's a wrap"` at multiple locations) will need updating to the
  new copy, not just additive coverage — **these are edits to existing assertions, flag as
  expected test churn, not regressions.**

## Common Pitfalls

### Pitfall 1: Breaking the single-now-detector invariant by computing break-awareness twice
**What goes wrong:** A shortcut implementation adds a second `chunkType` check somewhere in
`today_screen.dart` (e.g., directly in `_buildLiveRow` or `_buildAppBar`) to "patch around" a
break showing up, instead of fixing it at the `resolveNowState` filter + shared title-helper
level.
**Why it happens:** It's locally easier to special-case one call site than to trace every place
a `next`/`current` chunk's title is rendered.
**How to avoid:** Make exactly one change to `resolveNowState`'s filter, and exactly one shared
title-helper function used by every call site listed in the table above. Grep
`_chunkTitle\(` after implementation — every call site should route through the same function.
**Warning signs:** Any new `if (chunk.chunkType == ChunkType.work)` conditional appearing
somewhere other than the shared title helper or the two already-correct gates
(`showActions`, `SwipeableChunkCard`'s dismiss direction) or the new focus-target exclusion.

### Pitfall 2: Forgetting the focus-target exclusion
**What goes wrong:** Ship LIVE-01 without touching `_buildAppBar`'s `focusTarget` switch — no
existing test catches this because no existing fixture has a break as "now." "Start focus"
becomes tappable while a break is active/overdue/next, pushing `FocusScreen` with a break's
chunk id, where it silently behaves like a work-chunk Pomodoro timer (wrong 25-minute default,
wrong `markComplete` semantics, wrong break-suggestion-after-timer logic since it assumes its
own target was work).
**Why it happens:** `focusTarget`'s switch (`today_screen.dart:670-677`) currently "just works"
by construction (filter excluded breaks), so it's easy to assume it still does after broadening
the filter — it's a silent regression, not a compile error or an obviously-failing existing test.
**How to avoid:** Explicit `chunkType != ChunkType.work → null` branch, with a dedicated new
test (see Validation Architecture below).
**Warning signs:** Manually check in the running app: start a break, tap the focus icon in the
AppBar — if it's enabled, this pitfall has landed.

### Pitfall 3: Blanket-replacing the 1-minute timer with a 1-second timer
**What goes wrong:** The "lazy version" explicitly named and forbidden in `23-CONTEXT.md`
decision 1 — running a 1-second `Timer.periodic` all day, all the time, rather than only during
the final 60 seconds of the live activity.
**Why it happens:** It's the simplest code change (one `Duration` literal), and it technically
satisfies LIVE-02's "counts down" requirement.
**How to avoid:** Two timers, dual cadence, as described above — the fast one only runs when the
live chunk has <60s left.
**Warning signs:** `flutter analyze`/code review sees only one `Timer.periodic` call site
changed rather than a new second timer field added; a battery/CPU profile (or just eyeballing
`setState` call frequency in a debug print) shows constant 1Hz rebuilds all day rather than
bursts of ≤60 near activity boundaries.

### Pitfall 4: Seconds precision leaking into `resolveNowState`
**What goes wrong:** Someone "fixes" `resolveNowState` to compare seconds instead of minutes,
reasoning that LIVE-02 needs precision. This risks destabilizing the KEY INVARIANT tests (all of
which use minute-granularity fixtures) and the documented FRAME-OF-REFERENCE note about local
vs. UTC minutes.
**Why it happens:** Conflating "the countdown display needs seconds" with "the now-classifier
needs seconds" — they're different concerns operating on the same `DateTime`.
**How to avoid:** Seconds precision belongs only in `_buildLiveRow`'s remaining-time
calculation. `resolveNowState` keeps its existing `nowDt.hour * 60 + nowDt.minute` sampling
exactly as-is.
**Warning signs:** A diff touching `now_state.dart`'s `currentMinutes` calculation at all.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with Flutter SDK `>=3.18.0-18.0.pre.54`) |
| Config file | none — standard `flutter test` discovery over `test/` |
| Quick run command | `export PATH="$PATH:/home/dan/development/flutter/bin"; flutter test test/screens/today_screen_now_state_test.dart test/screens/today_timeline_model_test.dart` |
| Full suite command | `export PATH="$PATH:/home/dan/development/flutter/bin"; flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LIVE-01 | Running break resolves as `Active`/`Overdue`, not `GapBeforeNext` | unit | `flutter test test/screens/today_screen_now_state_test.dart -x` | ✅ (extend existing group) |
| LIVE-01 | Live break row shows `'RIGHT NOW — RESTING'` kicker, `'Taking a break'`/`'Taking a long break'` title, no Complete/Skip | widget | `flutter test test/screens/today_screen_now_state_test.dart -x` | ✅ (extend existing widget group) |
| LIVE-01 | "Next · Short break at …" renders correctly when the upcoming chunk is a break | widget | `flutter test test/screens/today_screen_test.dart -x` | ✅ (extend Task 3-adjacent group) |
| LIVE-01 | "Start focus" is disabled when `nowState` targets a break | widget | `flutter test test/screens/today_screen_test.dart -x` | ❌ Wave 0 — new case in the existing WR-01 focus-target group |
| LIVE-02 | ≥60s remaining shows whole minutes, rounded up | unit/widget | `flutter test test/screens/today_screen_now_state_test.dart -x` | ✅ (existing math already satisfies this — add an explicit boundary-value assertion, e.g. 61s → "2 min left") |
| LIVE-02 | <60s remaining shows seconds, updates every second via `tester.pump(Duration(seconds: 1))` | widget | `flutter test test/screens/today_screen_now_state_test.dart -x` | ❌ Wave 0 — new fast-timer test group |
| LIVE-02 | Fast timer does not leak across pause/resume (no pending-timer test failure) | widget | `flutter test test/screens/today_screen_now_state_test.dart -x` | ❌ Wave 0 — extend the existing WR-03 no-double-timer pattern to cover `_fastTimer` |
| LIVE-03 | PreStart shows `'Nothing until 8:00am'` / `'The day starts with … Until then the time is yours.'` | widget | `flutter test test/screens/today_screen_test.dart -x` | ✅ (edit existing assertion in place) |
| LIVE-03 | DayComplete shows `"That's the day."` / `"Everything scheduled is behind you."` | widget | `flutter test test/screens/today_screen_test.dart -x` | ✅ (edit existing assertion in place) |
| LIVE-03 | Gap banner behavior confirmed (no-change vs. removed — see Open Question) | widget | `flutter test test/screens/today_screen_test.dart -x` | ✅ if no-change; requires a plan decision first if removed |

### Sampling Rate
- **Per task commit:** `flutter test test/screens/today_screen_now_state_test.dart
  test/screens/today_timeline_model_test.dart test/screens/today_screen_test.dart` (~1-2s per
  file based on current suite timing — the full 420-test suite ran in ~11s total per the research
  run above, so even the full suite is cheap enough to run per task if preferred)
- **Per wave merge:** `flutter test` (full suite)
- **Phase gate:** Full suite green before `/gsd-verify-work`, plus `flutter analyze` clean (the
  codebase's established convention per every prior phase's SUMMARY.md)

### Wave 0 Gaps
- [ ] Break-as-`Active`/`Overdue`/`GapBeforeNext.next` unit test cases in
      `today_screen_now_state_test.dart` (extend, don't create a new file — keep the
      resolveNowState suite consolidated, matching the single-detector philosophy)
- [ ] Fast-timer (<60s) widget test group in `today_screen_now_state_test.dart`, modeled on the
      existing "timer/lifecycle" test at lines 635-746
- [ ] Focus-target-excludes-breaks regression test in `today_screen_test.dart`'s existing WR-01
      group
- [ ] Shared break-title-helper unit test (if extracted as a standalone function rather than a
      private method — planner's call on placement)

*(No new test framework or fixture infrastructure needed — everything above extends existing
files using patterns already proven in this suite.)*

## Security Domain

This phase is pure client-side clock arithmetic and string rendering over already-persisted,
already-trusted local Hive data (no new user input, no new persistence, no network calls, no
auth surface). Per the ASVS category sweep:

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | No | N/A — single-user local app, no auth anywhere in Canopy |
| V3 Session Management | No | N/A |
| V4 Access Control | No | N/A |
| V5 Input Validation | No | This phase adds no new user-facing input; all data consumed (`ScheduledChunk` fields) is already validated/typed by the Hive model and existing generator |
| V6 Cryptography | No | N/A |

No known STRIDE-relevant threat patterns apply to a local countdown timer touching no
network/auth/crypto surface.

## Package Legitimacy Audit

**Not applicable — this phase adds zero new dependencies.** `Timer`, `DateTime`, `Duration`, and
`WidgetsBindingObserver` are all `dart:async`/`dart:core`/`package:flutter` core APIs already in
use throughout this codebase. `pubspec.yaml`'s `dev_dependencies` were checked and confirm no
`fake_async` or similar testing-time-control package is present or needed (see Test Surface
above — `flutter_test`'s own `tester.pump(Duration)` already provides equivalent fake-clock
semantics for `testWidgets`). [VERIFIED: `pubspec.yaml` read in full]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The Gap-state banner ("Up next") should NOT change — reading 1 of the ambiguous UI-SPEC sentence is correct | Edge States / Open Question | If reading 2 was actually intended, the planner ships unchanged copy that later needs a follow-up phase; low cost either way since it's a clearly-flagged open question, not a silent guess |
| A2 | A break chunk's `Overdue` state is structurally near-impossible in normal contiguous scheduling (derived from reading `schedule_generator.dart` STEP C/`_assignSyntheticStartTimes`, not from running the packer against an adversarial fixture) | Break-Aware Now-State / "Breaks can never become resolved" | If some untested packer edge case produces a non-contiguous break window, an overdue break could render with generic (non-break-aware) copy briefly — low severity, and the shared title-helper fix already covers the display correctly regardless of reachability |
| A3 | "Short break"/"Long break" (not "Taking a break"/"Taking a long break") are the right strings for a break referenced as "Next," based on matching the existing `chunk_card.dart` non-live-break convention rather than any explicit lock in CONTEXT.md/UI-SPEC (which only lock copy for the LIVE row itself) | Break-Aware Now-State / "Do not reuse 'Taking a break'…" | If Dan actually wants "Taking a break" used even in "Next" context, this is a one-string copy fix, not a structural risk |

## Open Questions

1. **Does the `GapBeforeNext` edge-state banner change at all for LIVE-03?**
   - What we know: `PreStart` and `DayComplete` both get explicit, verbatim new copy in
     `23-CONTEXT.md`. `GapBeforeNext` gets only a descriptive sentence about it already being
     "handled inline."
   - What's unclear: whether "handled inline" means "no banner change needed" (current behavior
     already satisfies LIVE-03) or "the banner should be removed since the inline free-time row
     is sufficient."
   - Recommendation: default to no change (see Assumption A1); the planner should surface this
     as an explicit line item / `checkpoint:human-verify` before touching
     `GapBeforeNext`'s render path, rather than silently picking one reading.

2. **Where should the shared break-title helper live?**
   - What we know: it's needed by at least four call sites, all currently private methods inside
     `_TodayScreenState`.
   - What's unclear: whether the planner wants it promoted to a top-level function (e.g. in
     `now_state.dart` next to the sealed classes it operates on, or `time_format.dart` alongside
     the other display-formatting helpers) versus kept as a private `_TodayScreenState` method.
   - Recommendation: a private method is sufficient (no other screen currently renders a chunk
     title outside `today_screen.dart`/`chunk_card.dart`, and `chunk_card.dart`'s break strings
     are already independently hardcoded rather than shared) — promoting it is a nice-to-have,
     not a requirement. Leave as planner's discretion.

## Sources

### Primary (HIGH confidence — direct code reads, this session)
- `lib/screens/today/now_state.dart` (full file, 183 lines)
- `lib/screens/today/timeline.dart` (full file, 93 lines)
- `lib/screens/today/today_screen.dart` (full file, 902 lines)
- `lib/screens/today/widgets/live_row_card.dart` (full file, 158 lines)
- `lib/data/models/scheduled_chunk.dart` (full file, 81 lines)
- `lib/services/schedule_generator.dart` (STEP A-E, lines 590-746)
- `lib/providers/schedule_notifier.dart` (markComplete/markSkipped call sites)
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart`, `chunk_card.dart` (dismiss gating,
  break title strings)
- `lib/screens/focus/focus_screen.dart` (lines 1-140)
- `lib/utils/time_format.dart` (full file, 49 lines)
- `lib/screens/today/widgets/breathing_pulse_cta.dart` (AnimationController precedent check)
- `test/screens/today_screen_now_state_test.dart` (full file, 748 lines)
- `test/screens/today_timeline_model_test.dart` (full file, 273 lines)
- `test/screens/today_screen_test.dart` (lines 450-620)
- `pubspec.yaml` (dependency check — no `fake_async`)
- `.planning/phases/23-live-activity-tracking/23-CONTEXT.md`, `23-UI-SPEC.md`
- `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/phases/22-unified-today-screen/22-04-SUMMARY.md`
- `grep -rn "resolveNowState" lib/ test/` (single-definition/single-call-site verification, 2026-08-07)
- `flutter test` full-suite run, 2026-08-07: 420/420 passing

### Secondary (MEDIUM confidence)
- flutter/flutter GitHub issues #90861, #53296, #144472 — "A Timer is still pending" assertion
  mechanism (WebSearch, cross-referenced against this codebase's own passing pending-timer-safe
  test pattern)

### Tertiary (LOW confidence)
- None — this research is entirely in-repo; no training-data-only claims were needed given full
  file access to every relevant source.

## Metadata

**Confidence breakdown:**
- Standard stack: N/A — no new dependencies (HIGH confidence this is correctly out of scope)
- Architecture: HIGH — every claim traced to a specific file:line, cross-checked against passing
  tests and git history (Phase 22 SUMMARY docs)
- Pitfalls: HIGH for Pitfalls 1-4 (all directly derived from reading the actual call sites);
  MEDIUM for the exact reachability of an "Overdue break" (Assumption A2, reasoned from code
  rather than empirically triggered)

**Research date:** 2026-08-07
**Valid until:** Effectively indefinite for the architectural claims (this is a stable, local
in-repo codebase with no external version drift risk) — but invalidated immediately if Phase 23
implementation itself changes any of the cited file:line locations before this research is
consumed by planning.

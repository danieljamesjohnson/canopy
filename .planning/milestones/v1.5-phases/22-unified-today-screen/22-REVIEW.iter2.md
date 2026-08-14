---
phase: 22-unified-today-screen
reviewed: 2026-08-07T20:43:54Z
depth: standard
files_reviewed: 23
files_reviewed_list:
  - lib/router.dart
  - lib/screens/today/today_screen.dart
  - lib/screens/today/now_state.dart
  - lib/screens/today/timeline.dart
  - lib/screens/today/widgets/live_row_card.dart
  - lib/screens/today/widgets/timeline_row_tile.dart
  - lib/screens/today/widgets/free_time_row.dart
  - lib/screens/today/widgets/breathing_pulse_cta.dart
  - lib/screens/today/widgets/end_of_day_card.dart
  - lib/screens/today/widgets/review_banner.dart
  - lib/screens/schedule/widgets/chunk_card.dart
  - lib/screens/schedule/widgets/swipeable_chunk_card.dart
  - lib/widgets/responsive_shell.dart
  - lib/utils/time_format.dart
  - test/screens/today_screen_test.dart
  - test/screens/today_timeline_model_test.dart
  - test/screens/today_screen_now_state_test.dart
  - test/screens/today_row_widgets_test.dart
  - test/screens/router_redirect_test.dart
  - test/screens/content_width_constraint_test.dart
  - test/screens/responsive_layout_test.dart
  - test/screens/breathing_pulse_cta_test.dart
  - test/end_of_day_card_test.dart
  - test/utils/time_format_test.dart
findings:
  critical: 0
  warning: 2
  info: 1
  total: 3
status: issues_found
---

# Phase 22: Code Review Report

**Reviewed:** 2026-08-07T20:43:54Z
**Depth:** standard
**Files Reviewed:** 23
**Status:** issues_found

## Summary

Reviewed the Phase 22 Today-screen merge: the deletion of `home_screen.dart` /
`schedule_screen.dart`, the new `lib/screens/today/` tree (`now_state.dart`,
`timeline.dart`, `today_screen.dart`, five row widgets), the router collapse
to three destinations, and the accompanying/relocated tests.

The core claims of this phase hold up under inspection:

- **`resolveNowState` is a byte-for-byte identical relocation.** Diffed the
  deleted `home_screen.dart`'s copy against the new `now_state.dart` — only
  the surrounding doc-comment context changed (no longer "conceptually
  internal to the Home Now zone"); the algorithm, including the
  advance-past-resolved loop and the `GapBeforeNext`/`DayComplete`
  disambiguation, is untouched.
- **Single-detector discipline holds for rendering.** `timeline.dart`'s
  `buildTimeline` derives `isLive` exclusively from the injected `NowState`
  (`liveId` switch at `timeline.dart:60-64`); it never independently scans
  for "first incomplete chunk." `today_screen.dart` calls
  `resolveNowState`/`buildTimeline` exactly once per `build()` and threads
  the result through — no ad-hoc "now" re-derivation was found in the
  render path. The `_buildActiveChunkItems` anti-pattern is confirmed gone
  (only lives in `schedule_screen.dart`'s git history now).
- **Route reachability holds.** The `/schedule` → `/today` redirect is
  exact-match, runs after the onboarding gate, and does not swallow
  `/schedule/checkin`; `main.dart:86`'s `router.go('/schedule')` on
  notification tap resolves correctly per `router_redirect_test.dart`'s
  literal reproduction of that call. No route became unreachable in the
  four-to-three destination collapse (`responsive_layout_test.dart` and
  `router_redirect_test.dart` both assert the NavigationRail/Bar have
  exactly three destinations, none labelled Home/Schedule).
- **Lifecycle hygiene is intact** in the 893-line `today_screen.dart`: the
  1-minute timer is cancelled in `dispose()`, the `WidgetsBindingObserver`
  is removed, the `ScrollController` is disposed, and the only async gap
  (`_checkReviewWindow`) is `mounted`-guarded before `setState`. The
  one-shot centre-on-open flag is set synchronously before the
  post-frame callback is scheduled, so a same-frame rebuild cannot
  double-schedule it (verified against the "centres once" test).
- **No `unused_import` residue** — grepped the whole tree; the
  plan-mandated-but-unused import behind `// ignore: unused_import` that
  executor 22-01 reported does not survive in the final state.
- `flutter analyze` is clean across all reviewed `lib/` files.

Two warnings and one info item below are worth fixing, but none block
shipping: one is a genuine (if pre-existing) reintroduction of
"first-unresolved-chunk" logic outside the render path, the other is a
set of pre-existing tests that don't actually exercise the function they
claim to test.

## Warnings

### WR-01: AppBar "Start focus" still uses an ad-hoc first-unresolved-chunk scan, independent of `resolveNowState`

**File:** `lib/screens/today/today_screen.dart:672-689`
**Issue:** The AppBar's focus-mode affordance computes its target chunk via:
```dart
final firstChunk = schedule.chunks
    .where((c) =>
        c.chunkType == ChunkType.work &&
        !c.isCompleted &&
        !c.isSkipped)
    .firstOrNull;
```
This is precisely the "first unresolved chunk by list order" pattern the
phase's own `timeline.dart:44-47` doc comment and the
`today_timeline_model_test.dart` "Phase 17 regression guard" test warn
against — it disagrees with `resolveNowState` in the exact scenario the
regression guard describes: if an earlier work chunk is still unresolved
(user forgot to mark it complete/skipped) while a later chunk's window is
now the one `resolveNowState` calls `Active`/`Overdue` (and which the
`LiveRowCard` visually presents as "now"), tapping "Start focus" jumps to
the stale earlier chunk instead of the one the rest of the screen treats
as current. This behavior is carried over verbatim from
`schedule_screen.dart` (confirmed via `git show 9c57c9a`), so it is not a
new regression — but the merge is exactly the point where the single
now-detector invariant this phase establishes should have been extended to
every "what should I act on right now" call site, and no test exercises
which chunk id is actually passed to `/focus` (only that the icon exists:
`today_screen_test.dart:221-240`).
**Fix:** Derive the focus target from the already-computed `nowState`
instead of a fresh scan:
```dart
final ScheduledChunk? focusTarget = switch (nowState) {
  Active(:final current) => current,
  Overdue(:final overdue) => overdue,
  GapBeforeNext(:final next) => next,
  PreStart(:final firstChunk) => firstChunk,
  DayComplete() => null,
};
if (focusTarget != null) {
  context.push('/focus', extra: focusTarget.id);
}
```
Add a widget test asserting the `/focus` push receives `nowState`'s chunk
id specifically in the case where it diverges from list-order-first.

### WR-02: Three `shouldShowEodCard` "trigger logic" tests never call the function under test

**File:** `test/end_of_day_card_test.dart:125-140`, `:142-159`, `:189-201`
**Issue:** `shouldShowEodCard` accepts an injectable clock
(`DateTime Function() now = DateTime.now`, `lib/screens/today/widgets/end_of_day_card.dart:101`)
specifically so its time-dependent branch can be tested deterministically.
Despite that seam existing, three of the six tests in the "trigger logic"
group don't call `shouldShowEodCard` at all — they recompute the
resolved/total ratio inline and assert against their own recomputed value,
with comments claiming "we cannot control DateTime.now().hour" and "we
verify the helper directly" as if the seam didn't exist:
```dart
test('returns false when <50% resolved and hour < 18 (time-independent branch)', () {
  final chunks = [_makeWork(completed: true), _makeWork(), _makeWork()];
  // We cannot control DateTime.now().hour, so we test the math directly:
  final workChunks = chunks.where((c) => c.chunkType == ChunkType.work).toList();
  final resolved = workChunks.where((c) => c.isCompleted || c.isSkipped || c.isDeferred).length;
  final ratio = resolved / workChunks.length;
  expect(ratio, lessThan(0.5));   // <- never calls shouldShowEodCard
});
```
These three tests would keep passing unchanged even if `shouldShowEodCard`
were rewritten with an inverted comparison, an off-by-one in the ratio, or
a broken hour check — they assert facts about the test fixture, not about
the function. This predates Phase 22 (introduced in Phase 10, only
reformatted here), but it is in this review's file list and is exactly the
"tests that pass regardless of the behavior they claim to verify" pattern
flagged from Phase 21.
**Fix:** Use the existing `now` seam to make all six tests actually call
`shouldShowEodCard` deterministically, e.g.:
```dart
test('returns false when <50% resolved and hour < 18', () {
  final chunks = [_makeWork(completed: true), _makeWork(), _makeWork()];
  expect(
    shouldShowEodCard(chunks, now: () => DateTime(2026, 1, 1, 10, 0)),
    isFalse,
  );
});
```
and similarly inject an hour ≥ 18 clock to cover that branch directly
instead of leaving it as an untested "may be true or false depending on
wall clock" comment.

## Info

### IN-01: `_openAddEvent` bypasses the screen's injectable clock

**File:** `lib/screens/today/today_screen.dart:616-641`
**Issue:** `TodayScreen` accepts an injectable `now` specifically so tests
can freeze wall-clock time (`_nowFn`, used by the header date, the 1-minute
ticker, and the live-row remaining-time calc). `_openAddEvent`, however,
calls `DateTime.now()` directly (line 619) rather than `_nowFn()` when
computing "today" for the new commitment's `initialDate`. Carried over
verbatim from `schedule_screen.dart` (confirmed via `git show 9c57c9a`), so
not a new defect, and low-impact in practice (an "Add event" default date
one calendar day off from an injected test clock is unlikely to be
asserted on), but it is an inconsistency with the rest of the screen's
clock-injection discipline and a latent source of test flakiness if a
future test ever asserts on the pre-filled date near a real-clock day
boundary.
**Fix:** Use `_nowFn()` instead of `DateTime.now()` for consistency:
```dart
final now = _nowFn();
final today = DateTime(now.year, now.month, now.day);
```

---

_Reviewed: 2026-08-07T20:43:54Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

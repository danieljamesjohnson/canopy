---
phase: 17-time-anchored-home
reviewed: 2026-06-13T00:00:00Z
depth: standard
iteration: 3
files_reviewed: 3
files_reviewed_list:
  - lib/screens/home/home_screen.dart
  - test/screens/home_screen_now_state_test.dart
  - test/screens/active_chunk_card_test.dart
findings:
  critical: 0
  warning: 0
  info: 2
  total: 2
status: clean
---

# Phase 17: Code Review Report (Iteration 3 — Final)

**Reviewed:** 2026-06-13
**Depth:** standard
**Iteration:** 3 (re-review after GapBeforeNext fix)
**Files Reviewed:** 3
**Status:** clean

## Summary

Iteration 3 verifies the GapBeforeNext addition and re-confirms all prior findings. Every
mandated scenario traces correctly. No Critical or Warning issues remain. Two Info-level items
are noted (stale comment; dead null-branch in the gap widget). The implementation is ready to ship.

---

## Structural Findings (fallow)

None provided for this phase.

---

## Narrative Findings (AI reviewer)

### Prior Findings — Disposition

| Finding | Disposition |
|---------|-------------|
| CR-01 (now() called twice) | **Confirmed resolved.** `now()` called exactly once at line 123; result stored in `nowDt`. Single-call contract documented at lines 119-122. |
| CR-02 (UTC/local frame) | **Confirmed accepted.** Documented departure at lines 107-114. Out of scope for Phase 17. |
| CR-03 (tautological all-resolved tests) | **Confirmed resolved.** See per-scenario trace below. |
| iter-2 CR-01 (GapBeforeNext / DayComplete gap honesty) | **Confirmed resolved.** See per-scenario trace below. |
| WR-02 (overdue identity pin) | **Confirmed resolved.** Widget test pins c1 via `find.textContaining('8:30 AM')` inside `find.byType(ActiveChunkCard)`. |
| WR-03 (double-timer idempotency) | **Confirmed resolved.** `nowCallCount == 1` assertion after two paused→resumed cycles. |
| iter-2 WR-01 (gap test encodes wrong expected) | **Confirmed resolved.** Test now asserts `isA<GapBeforeNext>()` with `next.id == 'c2'`. |

---

### Mandated Scenario Traces

**Scenario 1: now=9:10, c1=9:00–9:25 completed, c2=9:25–9:50 pending → GapBeforeNext(c2)**

- `currentMinutes = 550`
- `allWork = [c1(start=540,dur=25,done), c2(start=565,dur=25,pending)]`
- Past-last-window guard: `550 >= 565+25=590`? No.
- `candidates = allWork.where(displayStartMinutes! <= 550)` → [c1] (c2 at 565 excluded)
- `active = c1`. Loop: c1.isCompleted → yes.
  - `candidate = c2`. `565 > 550`? Yes → gap branch.
  - `remaining = allWork.sublist(1).where(!resolved).firstOrNull` = c2 (unresolved).
  - Returns `GapBeforeNext(c2)`. ✓ NOT DayComplete.

Covered by the near-gap unit test at `home_screen_now_state_test.dart:299-331`, which asserts
`isA<GapBeforeNext>()` with `next.id == 'c2'`. Test correctly encodes the fix.

**Scenario 2: now=9:30, c1=9:00–9:25 completed, c2=10:00–10:25 pending → GapBeforeNext(c2)**

- `currentMinutes = 570`
- `candidates = [c1]` (c2 at 600 excluded). `active = c1`. Gap branch fires (600 > 570).
- `remaining = c2` (unresolved). Returns `GapBeforeNext(c2)`. ✓

Covered by the gap unit test at `home_screen_now_state_test.dart:247-296`, which asserts
`isA<GapBeforeNext>()` with `next.id == 'c2'` and explicitly asserts `isNot(isA<Active>())`
and `isNot(isA<DayComplete>())`.

**Scenario 3a: Genuinely done — now past last window (time-past shortcut)**

- `currentMinutes = 1080` (6pm), c1 end = 540+25 = 565. `1080 >= 565`? Yes → `DayComplete`. ✓

**Scenario 3b: Genuinely done — all-resolved future (gap branch with empty remaining)**

- now=9:30 (`currentMinutes=570`), c1 completed, c2 skipped (start=600).
- Gap branch fires. `remaining = allWork.sublist(1).where(!resolved)` → [] (c2 is skipped).
- `remaining == null` → `DayComplete`. ✓

Covered by `home_screen_now_state_test.dart:333-361` ("gap with all-resolved future").

**Scenario 3c: All-resolved — CR-03 traversal path (inside c2 window)**

- now=10:05 (`currentMinutes=605`), c1 completed(start=540), c2 skipped(start=600,dur=30,end=630).
- `605 >= 630`? No (no time shortcut).
- `candidates = [c1, c2]`. `active = c2`. Loop: c2.isSkipped → yes. `idx+1 = 2 >= 2` → `DayComplete`. ✓

Non-tautological: exercises the genuine traversal path, not the null-filter degenerate shortcut.

**Scenario 4: Active vs GapBeforeNext at exact window start**

- Gap condition: `candidate.displayStartMinutes! > currentMinutes` (strict `>`).
- At `currentMinutes == c2.displayStartMinutes`: condition is false → c2 promoted to `active`. Loop
  continues. If c2 is unresolved: loop exits, `windowEnd = c2.start + c2.dur`, `currentMinutes == c2.start`,
  `currentMinutes >= windowEnd` only if `durationMinutes == 0` (impossible). → `Active(c2)`. ✓
- Correct: at exactly c2's window start, the state is Active (not Gap).

**Scenario 5: Overdue reachable for unresolved past-window chunk**

- GapBeforeNext is only returned inside the while-loop (resolved chunk branch). Overdue is returned
  after the loop exits (unresolved chunk branch). These are mutually exclusive.
- Existing overdue unit test (`home_screen_now_state_test.dart:167-182`): c1(start=510,dur=60),
  c2(start=630). now=10:00 (`currentMinutes=600`). `candidates=[c1]`, active=c1 (unresolved), loop
  not entered. `windowEnd=570`. `600 >= 570` → `Overdue(c1, c2)`. ✓

**Scenario 6: build() switch exhaustiveness**

Sealed class `NowState` has five subtypes: `PreStart`, `Active`, `Overdue`, `GapBeforeNext`,
`DayComplete`. The switch at `home_screen.dart:512-523` covers all five arms. Dart's sealed-class
exhaustiveness analysis will not produce a warning; no default arm is needed. ✓

**Scenario 7: GapBeforeNext widget renders honest copy (no accent, no "That's a wrap")**

- `_buildGapBeforeNextContent` renders `Text('Up next', ...)` as heading and
  `'Next up at ${formatMinutes(next.displayStartMinutes!)}'` as body.
- No `BoxDecoration`, no accent color, no `ActiveChunkCard` — calm inline treatment mirrors PreStart.
- Widget test (`home_screen_now_state_test.dart:562-614`) asserts: `find.text('Up next')` findsOneWidget,
  `find.text("That's a wrap")` findsNothing, `find.byType(ActiveChunkCard)` findsNothing,
  `find.textContaining('10:00 AM')` findsOneWidget. All four assertions match the implementation. ✓

---

## Info

### IN-01: Stale comment contradicts current gap behavior

**File:** `lib/screens/home/home_screen.dart:160-162`

**Issue:** The block comment above the while-loop still reads:

```
// return DayComplete so the user sees an honest "wrapped up for now"
// rather than a future chunk prematurely shown as "Now".
```

This described the pre-fix behavior. The code now returns `GapBeforeNext` when unresolved future
chunks remain, and only returns `DayComplete` when they are all resolved. A developer reading the
comment would incorrectly believe the gap always returns `DayComplete`.

**Fix:** Replace lines 160-162 with the current behavior:

```dart
// If the next chunk's window hasn't started yet we are in a between-windows gap.
// If unresolved future work remains → GapBeforeNext (day not done).
// If all future chunks are also resolved → DayComplete (day genuinely complete).
```

---

### IN-02: Dead null-branch in `_buildGapBeforeNextContent`

**File:** `lib/screens/home/home_screen.dart:587-589`

**Issue:** The body text ternary checks `next.displayStartMinutes != null`, but `GapBeforeNext.next`
is always sourced from `allWork` (filtered at line 128-130 to `displayStartMinutes != null`). The
`'Coming up next'` fallback at line 589 is unreachable. This is not a bug, but it is dead code that
may mislead readers into thinking `next.displayStartMinutes` can be null here.

**Fix:** Remove the guard and render the time string unconditionally:

```dart
Text(
  'Next up at ${formatMinutes(next.displayStartMinutes!)}',
  style: theme.textTheme.bodyMedium?.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
  ),
),
```

Alternatively, retain the guard with a comment explaining the invariant if defensive coding is
preferred. Either approach is acceptable.

---

_Reviewed: 2026-06-13_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
_Iteration: 3 (final)_

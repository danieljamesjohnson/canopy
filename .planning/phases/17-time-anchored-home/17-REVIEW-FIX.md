---
phase: 17-time-anchored-home
fixed_at: 2026-06-13T00:00:00Z
review_path: .planning/phases/17-time-anchored-home/17-REVIEW.md
iteration: 1
findings_in_scope: 7
fixed: 7
skipped: 0
status: all_fixed
---

# Phase 17: Code Review Fix Report

**Fixed at:** 2026-06-13
**Source review:** `.planning/phases/17-time-anchored-home/17-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 7 (3 Critical, 3 Warning, 1 Info)
- Fixed: 7
- Skipped: 0

**Test suite:** 240 tests pass (was 239 — one new WR-01 regression test added).
`flutter analyze lib/screens/home/home_screen.dart` — no issues found.

---

## Fixed Issues

### CR-01: `now()` Called Twice — Race at Minute Boundary

**Files modified:** `lib/screens/home/home_screen.dart`
**Commit:** `bac8b2b`
**Applied fix:** Replaced `now().hour * 60 + now().minute` with a single snapshot:
`final nowDt = now(); final currentMinutes = nowDt.hour * 60 + nowDt.minute;`
A comment explains the race: a minute rollover at 8:59→9:00 between the two calls
would yield `hour=8, minute=0` producing 480 instead of 540. Covered by IN-01
doc note (see below).

---

### CR-02: UTC vs Local Frame-of-Reference Contradiction

**Files modified:** `lib/screens/home/home_screen.dart`
**Commit:** `bac8b2b`
**Applied fix (documentation + consistency, NOT logic change):** Added a
`FRAME-OF-REFERENCE NOTE` block in the `resolveNowState` doc comment explaining:

- `displayStartMinutes` is intentionally compared against LOCAL wall-clock
  minutes-from-midnight (no `.toUtc()`) to match how `formatMinutes` renders
  chunk times in the UI.
- Both the "Now" label and the visible start-time label derive from the same
  un-converted minutes value, so they always agree.
- The `anchoredStartMinutes` field doc comment ("UTC") is a pre-existing label
  inconsistency in the model layer — the display layer (`formatMinutes`,
  `chunk_card.dart`, "Your day starts at...") never converts, making the effective
  frame of reference LOCAL for all UI purposes.
- Fixing the UTC label is a pre-existing issue in the display layer, out of scope
  for Phase 17. `resolveNowState` is intentionally consistent with the existing UI.

**No logic change was made.** The investigation confirmed: changing to UTC
comparison would make "Now" DISAGREE with the visible start-time labels, which
is worse than the current consistent-but-mislabeled behavior.

---

### CR-03: "All-Resolved" Widget Tests Pass via Degenerate Path (Non-Tautological)

**Files modified:** `test/screens/active_chunk_card_test.dart`
**Commit:** `9d29d07`
**Applied fix:** `_scheduleAllResolved()` now gives both chunks real
`syntheticStartMinutes` (c1=540=9:00 AM, c2=600=10:00 AM). Both all-resolved
widget tests inject `now: allResolvedNow` = `() => DateTime(2026,6,13,10,5)`,
which places the clock inside c2's window (10:00–10:30). `resolveNowState` now:
(1) collects both c1 and c2 as candidates (both windows started by 10:05),
(2) selects c2 as `active` (last started),
(3) c2 is skipped → advance-loop: idx+1 >= allWork.length → `DayComplete`.
This exercises the genuine all-resolved-via-traversal path. The tests would now
fail if the resolution-checking logic regressed (previously they passed via the
null-filter degenerate shortcut `allWork.isEmpty → DayComplete`).

---

### IN-01: `now()` Double-Call Documentation Gap

**Files modified:** `lib/screens/home/home_screen.dart`
**Commit:** `bac8b2b`
**Applied fix:** Added a single-sentence contract note at the top of the
`resolveNowState` doc comment: "[now] is called exactly once per invocation;
callers may supply any stable supplier (e.g., `() => DateTime.now()` or a
test-frozen constant)." Covered by the same commit as CR-01.

---

### WR-01: Advance-Loop Can Promote a Future Chunk Into "Active"

**Files modified:** `lib/screens/home/home_screen.dart`, `test/screens/home_screen_now_state_test.dart`
**Commit:** `bac8b2b`
**Applied fix:** Inside the `while (active.isCompleted || active.isSkipped)` loop,
before promoting `allWork[idx+1]` to `active`, check
`candidate.displayStartMinutes! > currentMinutes`. If the next chunk's window
has not opened yet, return `DayComplete` instead of promoting it.

**Gap state choice:** When a resolved chunk's window has passed and the next
chunk's window hasn't opened yet, there is no active or overdue chunk to show.
The fix returns `DayComplete` ("That's a wrap" copy), which is honest — all
visible work is done for now. This is preferable to showing a future chunk
prematurely ("Active" at 9:30 for a 10:00 chunk) or showing the old resolved
chunk with misleading UI.

**Updated unit test:** The existing "active advances past resolved chunk" test
used c1=8:30 completed and c2=9:30 with now=9:00 — with the fix, this correctly
returns DayComplete (gap). The test was updated to use a scenario where both
windows have started (c1=8:30 completed, c2=9:00 with now=9:15) so it still
tests the "advance to c2" path correctly.

**Added regression test:** "gap (WR-01 regression): c1 resolved 9:00-9:25, c2
starts 10:00, now=9:30 → DayComplete (not Active(c2))" — asserts
`isNot(isA<Active>())` AND `isA<DayComplete>()` for the exact scenario from the
review.

---

### WR-02: "Between-Chunks Overdue" Widget Test Does Not Assert Which Chunk Is Now

**Files modified:** `test/screens/home_screen_now_state_test.dart`
**Commit:** `9d29d07`
**Applied fix:** Added a `find.descendant` assertion inside the between-chunks
overdue widget test:
```dart
find.descendant(
  of: find.byType(ActiveChunkCard),
  matching: find.textContaining('8:30 AM'),
)
```
`ActiveChunkCard` renders the time range from `displayStartMinutes`. c1's window
is 8:30–9:30 AM; c2's is 10:30–11:30 AM. If the logic were reversed and c2 were
promoted to Now, "10:30 AM" would appear instead and this assertion would fail.
The test now pins the identity of the displayed chunk without relying on a unique
rationale string.

---

### WR-03: Timer Lifecycle Test Does Not Verify "No Double-Timer" on Resume

**Files modified:** `test/screens/home_screen_now_state_test.dart`
**Commit:** `9d29d07`
**Applied fix:** Embedded a `nowCallCount` counter in the `now` lambda from the
very first `_pumpHomeScreen` call. (`_HomeScreenState` assigns `_nowFn` as
`late final` in its field initializer, so the counter must be inside the original
lambda — re-pumping with a new lambda doesn't replace `_nowFn` because Flutter
reuses the existing state object via `didUpdateWidget`.)

After verifying the pre-start→active transition at 8:01, the test runs two
`paused→resumed` lifecycle cycles to attempt double-timer installation. After
resetting `nowCallCount = 0`, `pump(Duration(minutes: 1))` fires the active
timer(s). If `_startNowTimer` leaked a second timer, `nowCallCount` would be 2+;
with correct idempotency it equals exactly 1. Also asserts `findsOneWidget` on
`ActiveChunkCard` as a structural sanity check.

---

## Skipped Issues

None — all findings were fixed.

---

_Fixed: 2026-06-13_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_

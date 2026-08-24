---
phase: 30-breaks-in-committed-time
reviewed: 2026-08-24T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - lib/services/schedule_generator.dart
  - lib/providers/schedule_notifier.dart
  - test/services/schedule_generator_test.dart
  - test/providers/schedule_notifier_add_event_test.dart
  - test/screens/lattice_break_pair_test.dart
findings:
  critical: 1
  warning: 3
  info: 1
  total: 5
status: issues_found
---

## Fix Dispositions (REVIEW-FIX)

Applied by the gsd-code-fixer agent. Full suite (598 tests, up from 597 — the
new WR-02 regression test) green, `flutter analyze` clean, both re-verified
after every commit below.

| ID | Disposition | Commit | Notes |
|---|---|---|---|
| CR-01 | FIXED | `4f6f673` | `_trimTrailingNonWork` narrowed to `chunkType == ChunkType.shortBreak && commitmentId == null`, mirroring STEP E's both guards. Doc comment rewritten to name both. |
| WR-02 | FIXED | `7c09a3d` | Added regression test seeding a trailing `[work, shortBreak, longBreak]` (all discretionary) and asserting all three survive `addEventToday` via the `!anchorsToday` early-return path. Proved RED first against the pre-CR-01-fix code (git `42116fc`) — collapsed to `{w1}`, confirming the cascading `while` deleted both breaks — then GREEN against the CR-01 fix. |
| WR-01 | FIXED | `89676f7` | `_reflowDiscretionaryWork` now takes `longBreakEvery` as a required parameter; `addEventToday` passes `ScheduleGeneratorService.breakCadenceForMood(cadenceMoodIndex)` — the same mood-derived value `buildCommitmentChunks` already used in the same call — instead of the hardcoded `4`. |
| WR-03 | FIXED | `89676f7` | The reflow's long-break duration changed from a hardcoded `25` to `ScheduleGeneratorService.longBreakMinutes` (30), matching every other code path. No existing test asserted the reflowed long break's duration (as the review noted), so no test needed updating; none was weakened. |
| IN-01 | FIXED | `89676f7` | Exposed `shortBreakMinutes`, `longBreakMinutes`, `workChunkMinutes`, `dayStartMinutes`, `dayEndMinutes` as public `static const` on `ScheduleGeneratorService` (public aliases of the existing private lattice constants, plus two new day-boundary/work-duration constants matching `_assignSyntheticStartTimes`'s own locals). `_reflowDiscretionaryWork` now reads all of its day-boundary and duration values from there instead of re-declaring literals — closing the exact duplication vector WR-03 drifted through. |

---

# Phase 30: Code Review Report

**Reviewed:** 2026-08-24T00:00:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

`buildCommitmentChunks` itself is sound: I traced the loop, the boundary/partial-footprint
fallback, and the tail-stretch logic by hand against several boundary cases (evenly-divisible
window, 10-min remainder, 27-min remainder, sub-25-min window, off-lattice start, the 160-min and
360-min ROADMAP fixtures) and every case the code can reach matches the documented and tested
behavior — `block.startMinutes`/`endMinutes` are never written anywhere in either file (confirmed
by grep), so D-01 holds on every path including the tail stretch. `generate()`'s own STEP E trim
(`result.last.chunkType == ChunkType.shortBreak && result.last.commitmentId == null`) is correctly
narrowed and cannot touch a trailing long break.

The defect is in the second half of the phase's own stated scope: `ScheduleNotifier
._trimTrailingNonWork`, the notifier's declared "mirror" of STEP E, was narrowed by adding
`commitmentId == null` but was **not** narrowed to `chunkType == ChunkType.shortBreak` — it still
matches `chunkType != ChunkType.work`, i.e. both break types. That single unmirrored condition
reintroduces, on the `addEventToday` path, the exact class of silent data-loss defect D-30-02 was
written to close, just for discretionary long breaks instead of commitment ones. See CR-01 below;
it is a BLOCKER because it destroys already-persisted user schedule state on a routine, frequently
hit path, contradicts the file's own doc comment claiming parity with STEP E, and is not caught by
any existing test.

`_reflowDiscretionaryWork` (reached from the same `addEventToday` method whenever a schedule
already exists) has two further, independent problems: it re-derives break cadence from a
hardcoded constant instead of the day's actual mood (WR-01), and its "long break" is the wrong
duration outright — 25 minutes instead of the 30 minutes every other code path uses (WR-03).

## Critical Issues

### CR-01: `_trimTrailingNonWork` deletes a legitimate trailing discretionary long break (and its short break) on every `addEventToday` call

**File:** `lib/providers/schedule_notifier.dart:368-372`

**Issue:**

```dart
while (sorted.isNotEmpty &&
    sorted.last.chunkType != ChunkType.work &&
    sorted.last.commitmentId == null) {
  schedule.chunks.remove(sorted.removeLast());
}
```

Compare `ScheduleGeneratorService.generate()`'s STEP E (`lib/services/schedule_generator.dart:822-826`),
which this method's own doc comment (lines 347-354) claims to mirror:

```dart
while (result.isNotEmpty &&
    result.last.chunkType == ChunkType.shortBreak &&
    result.last.commitmentId == null) {
  result.removeLast();
}
```

D-30-02 added the `commitmentId == null` guard to both trims so neither could delete a commitment
break. But STEP E has a *second* guard the notifier's trim never got: `chunkType ==
ChunkType.shortBreak`. STEP E therefore only ever removes a trailing **short** break; a trailing
**long** break is explicitly preserved (LATTICE-02: "never silently suppressed" — see
`schedule_generator.dart:807-821` and the `BREAK-02`/`D-05` tests, e.g. Test 6 in
`schedule_generator_test.dart`, which asserts a day can legitimately end `[..., work, shortBreak,
longBreak]`).

`_trimTrailingNonWork` uses `chunkType != ChunkType.work` instead, which matches **both**
`shortBreak` and `longBreak`. Three concrete consequences:

1. Any day generated by `generate()` that legitimately ends on a cadence-boundary long break
   (Test 6's exact shape, `[work, shortBreak, longBreak]`) will have that long break — and,
   because the `while` re-evaluates `sorted.last` after each removal, its preceding short break
   too (the same `while` iterates again once the long break is popped) — silently deleted the
   instant the user calls `addEventToday` for **any** commitment, including one that lands earlier
   in the day, or one for a completely different day (the `!anchorsToday` early-return branch
   still runs this trim before bailing out — this is exactly how `COMMITBREAK-01/ADD-EVENT-TRIM`
   reproduces the *commitment* half of D-30-02, but no equivalent test exists for the
   *discretionary* half).
2. The deletion is unconditional on whether the new event actually ends up after the old trailing
   chunk chronologically. The trim runs against the schedule's **pre-insertion** ordering, so even
   a commitment added far earlier in the day (which will not displace the existing evening long
   break once re-sorted) still wrongly deletes it.
3. `_repo.save(_todaySchedule!)` is called later in the same call (both the reflow-save branch and
   the minimal-schedule branch), so this is a durable Hive write, not a transient render glitch —
   the same "durable data loss" risk D-30-02's own threat model (`T-30-03` in the 30-02/30-04
   plans) was written to close, just for the discretionary case that was never covered.

This is not caught by any test in `schedule_notifier_add_event_test.dart`: every existing seed
fixture that exercises `_trimTrailingNonWork` ends its trailing run on a `shortBreak` (CR-01's own
regression test `w1,b1,c1`) or on a chunk carrying `commitmentId` (`COMMITBREAK-01/ADD-EVENT-TRIM`'s
`otherBreak`). None seeds a schedule whose trailing chunk is a **discretionary long break**, so the
current (buggy) `!= ChunkType.work` condition passes every test in the suite identically to the
correct `== ChunkType.shortBreak` condition would.

**Fix:**

```dart
while (sorted.isNotEmpty &&
    sorted.last.chunkType == ChunkType.shortBreak &&
    sorted.last.commitmentId == null) {
  schedule.chunks.remove(sorted.removeLast());
}
```

Also rewrite the doc comment (lines 347-354), which currently states "Mirrors the generator's own
STEP E narrowing" while describing only the `commitmentId` half of that mirror — the comment
should name both guards STEP E uses.

Add a regression test alongside `COMMITBREAK-01/ADD-EVENT-TRIM` that seeds today's schedule ending
`[work, shortBreak(commitmentId: null), longBreak(commitmentId: null)]`, calls `addEventToday` with
an unrelated block (either a different day, mirroring the existing repro, or an earlier same-day
slot), and asserts both the short break and long break survive.

## Warnings

### WR-01: `_reflowDiscretionaryWork`'s break cadence is a hardcoded constant, not the day's actual mood cadence

**File:** `lib/providers/schedule_notifier.dart:393` (`const longBreakEvery = 4;`), used at line 449

**Issue:** `addEventToday`'s commitment-chunk generation correctly derives cadence from the day's
real mood (`ScheduleGeneratorService.breakCadenceForMood(cadenceMoodIndex)`, lines 290-296), but
the very next thing `addEventToday` does when a schedule already exists — reflow the discretionary
work around the new event (line 310) — re-derives breaks using a hardcoded `longBreakEvery = 4`
regardless of mood. On a mood-1 day (cadence should be every 2 chunks) or mood-5 day (every 5),
reflowing after adding an event produces a different long-break density than `generate()` would
have produced for the same mood, and different from what the commitment chunks inserted moments
earlier in the same call used. This directly undermines the "a schedule the user can't predict is
one they won't trust" position (CLAUDE.md) the whole phase's cadence design (D-30-01) is built
around, and it means the reflowed portion of the day silently diverges from the cadence documented
at the top of `schedule_generator.dart` (mood-scaled 2/3/4/4/5).

**Fix:** Thread the mood-derived cadence into `_reflowDiscretionaryWork` the same way
`buildCommitmentChunks` already receives it:

```dart
final longBreakEvery = ScheduleGeneratorService.breakCadenceForMood(cadenceMoodIndex);
final reflowed = _reflowDiscretionaryWork(
  chunks,
  nowMinutes: nowMinutes,
  longBreakEvery: longBreakEvery,
)..sort(...);
```

and drop the local `const longBreakEvery = 4;` in favor of a required parameter.

### WR-02: No test proves a trailing discretionary long break survives `addEventToday`

**File:** `test/providers/schedule_notifier_add_event_test.dart`

**Issue:** As detailed in CR-01, every seed fixture that exercises the trailing-trim path in this
file ends on either a `shortBreak` or a `commitmentId`-carrying chunk. None seeds a trailing
*discretionary long break* — the exact shape `generate()` can legitimately produce (Test 6,
`BREAK-01` mood=1/mood=2 fixtures in `schedule_generator_test.dart`) and the exact shape CR-01
shows gets silently deleted. This is precisely the failure mode the phase's own review brief warns
about ("this repo shipped two defects behind green tests... would a plausible wrong implementation
still pass any of them?") — the current implementation is that plausible wrong implementation, and
it passes the whole suite.

**Fix:** Add the regression test described in CR-01's fix, and additionally assert the case where
the pre-existing trailing long break is preceded by its own short break (the D-06 pair), so the
test also pins that the fix stops the cascade after one removal rather than removing both.

### WR-03: `_reflowDiscretionaryWork` emits a 25-minute "long break", not the system's 30-minute long break

**File:** `lib/providers/schedule_notifier.dart:450`

**Issue:**

```dart
final dur = isLong ? 25 : 5;
```

Everywhere else in the codebase a long break is 30 minutes — `ScheduleGeneratorService
._longBreakMinutes` (`lib/services/schedule_generator.dart:71`), every long break
`buildCommitmentChunks` emits, every long break `generate()`'s packing pass reserves and STEP C
emits, and the `BREAK-02`/`LATTICE-01` tests that pin "long break must always be 30 minutes" at
every mood. `_reflowDiscretionaryWork` — reached whenever `addEventToday` inserts an event into an
existing schedule and reflows overlapping discretionary work around it — instead emits a
`longBreak`-typed chunk with `durationMinutes: 25`. This is a distinct value bug from WR-01's
cadence-source problem: even if the cadence were fixed to use the correct mood-derived
`longBreakEvery`, the break chunk it emits at the boundary would still be 5 minutes short of what
every other code path in the app produces for the same `ChunkType.longBreak`. No test in
`schedule_notifier_add_event_test.dart` asserts a reflowed long break's duration, so this has no
regression coverage.

**Fix:**

```dart
final dur = isLong ? 30 : 5;
```

Better: reuse `ScheduleGeneratorService`'s constants once they are exposed (see IN-01) so the two
call sites cannot independently drift again.

## Info

### IN-01: Break-duration magic numbers duplicated instead of reusing `ScheduleGeneratorService`'s named constants

**File:** `lib/providers/schedule_notifier.dart:391-393, 423, 450`

**Issue:** `_reflowDiscretionaryWork` hardcodes `480` (day start), `1320` (day end), `25` (work
duration), and `5`/`25` for the two break durations (see WR-03 for the fact that the "long break"
value is also wrong, not just duplicated). `schedule_generator.dart` already defines these as named
constants (`_latticeMinutes`, `_shortBreakMinutes`, `_longBreakMinutes`), just not publicly. The
duplication is exactly how WR-03's value drifted unnoticed, and a future change to the lattice
constants (e.g. a mood-tunable long-break length) would silently miss this file.

**Fix:** Expose the relevant constants as `static const` on `ScheduleGeneratorService` (or a small
shared constants class) and reference them from `_reflowDiscretionaryWork` instead of re-declaring
literal minute values.

---

_Reviewed: 2026-08-24T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

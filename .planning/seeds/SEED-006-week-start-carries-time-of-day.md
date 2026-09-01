# SEED-006 — A chunk completed on a Monday never counts toward that week's budget

**Raised:** 2026-09-01, by the agent, during Phase 33 plan 33-02 (`WeeklyProgressService`).
Not a user report — nobody has complained about this, which is part of why it matters.

**Status:** open. Found, characterised, and deliberately **not fixed** in Phase 33.

## Where it lives

`lib/services/schedule_generator.dart:313-330`.

```dart
/// Returns the Monday of the week containing [date].
DateTime _weekStart(DateTime date) =>
    date.subtract(Duration(days: date.weekday - 1));            // :314-315

int _completedChunksThisWeek(String goalId, List<CompletionLog> logs, DateTime today) {
  final weekStart = _weekStart(today);
  return logs.where((l) {
    if (l.goalId != goalId) return false;
    if (l.event != CompletionEvent.completed) return false;
    final logDate = DateTime.parse(l.dateYmd);                  // always midnight
    return !logDate.isBefore(weekStart) && !logDate.isAfter(today);
  }).length;
}
```

`_weekStart` never normalises the time of day, so it returns **Monday at today's clock time**.
A `CompletionLog` stores `dateYmd` as a `YYYY-MM-DD` string, so `DateTime.parse` always yields
**midnight**. Monday-00:00 `isBefore` Monday-14:30, so the Monday log is dropped.

## Blast radius — measured, not estimated

The first estimate written during planning was "drops Monday's chunks on any afternoon." **That
understates it.** Running the two expressions above verbatim against a fixed calendar
(Monday 2026-08-31 through Sunday 2026-09-06), for every `today` × `logDate` pair at five
different clock times, gives:

| `today` carries | Mon log | Tue–Sun logs |
|---|---|---|
| exactly `00:00:00` | counted | counted |
| `00:00:01` | **dropped** | counted |
| `09:00` | **dropped** | counted |
| `14:30` | **dropped** | counted |
| `23:59` | **dropped** | counted |

The correct statement is therefore:

> **A chunk completed on a Monday never counts toward that week's budget — on every day of the
> week, at every time of day except exactly `00:00:00`.** Tuesday through Sunday logs are
> unaffected.

It is not an afternoon problem and not a Monday-only-on-Monday problem. `weekStart` stays pinned to
Monday-at-today's-clock-time for the *whole week*, so Monday's completions are invisible on
Tuesday, Wednesday, and every day through Sunday as well. The `00:00:00` exemption is unreachable
in practice — `DateTime.now()` is never exactly midnight.

## What it costs

`_remainingHours` (`:333-341`) subtracts completed hours from `weeklyHourBudget`. With Monday's
chunks missing, **remaining reads high by exactly Monday's completed chunks** — 25 minutes each.
`_demandForTimeTarget` (`:345-349`) then divides that inflated remainder over the days left and
schedules to it, so **every time-target goal worked on a Monday is over-scheduled for the rest of
that week, every week.**

The user-visible shape is subtle and self-consistent, which is why it has never been reported: the
day looks fuller than it should, but nothing contradicts anything. Nobody sees "you did 0 hours" —
they just get handed more chunks than their budget actually calls for. A user who reliably works
Mondays absorbs this permanently.

Worst case is a Monday-heavy week: a goal whose whole 4-hour budget is spent on Monday reads as
4 hours remaining all week and keeps drawing its per-day cap.

## How it was found

Not by a bug report and not by reading the code for defects. It surfaced from **specifying a test**:
plan 33-02 called for a "Monday inclusive" boundary case on the new `WeeklyProgressService`, which
forced the question of what `weekStart` should return at the boundary. Answering that honestly meant
reading the generator's version, noticing it does not normalise, and then **reproducing its own
expressions against a fixed calendar** rather than trusting the reading.

The table above is that reproduction. It also corrected the planner's own first estimate, which had
the right defect but the wrong radius — worth noting as evidence that "run it" beats "reason about
it" even when the reasoning is basically right.

## Why Phase 33 did not fix it

The ROADMAP fences Phase 33 off from `schedule_generator.dart` — the phase is a Goals-screen
redesign, and the generator is the most heavily-tested, most load-bearing file in the app.
UI-SPEC item 20 states the fence explicitly ("`schedule_generator.dart` is not modified").

Phase 33's new `WeeklyProgressService.weekStart` **normalises to date-only and is therefore
correct.** It deliberately does *not* replicate the bug for consistency with the generator; the
divergence is recorded in that method's doc comment so the next reader does not "fix" the helper
into agreement with the defect.

The consequence is that, until this seed is closed, **the Goals screen's progress line and the
scheduler's own budget arithmetic will disagree about Monday.** The progress line is the correct
one. That disagreement is the strongest argument for fixing this soon.

## Fixing it

The change itself is one line:

```dart
DateTime _weekStart(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return d.subtract(Duration(days: d.weekday - 1));
}
```

The work is not the line, it is the blast test. This shifts real scheduling output — days that
previously over-scheduled will get fewer chunks — so it needs its own phase with:

1. A regression test at the Monday boundary, **observed red first** against the current generator.
2. A review of the generator's existing test suite for cases whose expected values silently encode
   the bug. Any such case is currently green *because* of the defect and will flip.
3. A check of whether `!logDate.isAfter(today)` wants the same normalisation for symmetry.
4. Consideration of collapsing `_weekStart` into `WeeklyProgressService.weekStart` so the two
   cannot drift again — the same "share the source of truth" move as D-30-03 and IN-01, and the
   reason `workChunkMinutes` was made public in the first place.

Item 2 is the real risk and the reason this is not a drive-by fix.

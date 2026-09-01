---
phase: 33-make-the-obvious-thing-obvious
plan: 02
subsystem: services
tags: [progress, completion-log, pure-service, tdd, seed]
status: complete

requires: []
provides:
  - "WeeklyProgressService — weekFractionFor(goal, logs, today) for the Goals screen progress line"
  - "WeeklyProgressService.weekStart — date-only Monday normalisation"
affects:
  - "33-03 (Goals screen) consumes weekFractionFor for the vertical progress line"

tech_stack:
  added: []
  patterns:
    - "Pure-Dart stateless service, no Flutter imports (QuarterlyAggregationService shape)"
    - "Shared constant over duplicated literal (IN-01 / D-30-03 lineage)"

key_files:
  created:
    - lib/services/weekly_progress_service.dart
    - test/services/weekly_progress_test.dart
    - .planning/seeds/SEED-006-week-start-carries-time-of-day.md
  modified: []

decisions:
  - "Chunk length is sourced from ScheduleGeneratorService.workChunkMinutes, never re-typed — the constant was already public with a live external consumer, so sharing it needed no generator change"
  - "weekStart normalises to date-only, deliberately diverging from the generator's un-normalised version rather than replicating its bug for consistency"
  - "Outcome goals return null, not 0.0 — null is 'no target' (grey track), 0.0 is 'just started' (red line)"
  - "Filter on goalId rather than attributionId so commitment logs fall out naturally (T-33-05)"

metrics:
  duration_minutes: 22
  completed: 2026-09-01

actuals:
  tokens: 21000
  tasks: 2
  commits: 2
---

# Phase 33 Plan 02: WeeklyProgressService Summary

`WeeklyProgressService` — a pure-Dart helper that turns `CompletionLog` rows into this week's
progress fraction for a goal, sourcing the 25-minute chunk length from the generator's existing
public constant so the codebase does not end up with a third copy of `× 25 / 60`.

## What was built

`lib/services/weekly_progress_service.dart`, five members, no Flutter imports:

| Member | Answers |
|---|---|
| `static weekStart(date)` | the **date-only** Monday of that week |
| `completedChunksThisWeek(goalId, logs, today)` | completed chunks, Monday..today inclusive |
| `completedDaysThisWeek(...)` | **distinct** days completed (habits are measured in days) |
| `completedHoursThisWeek(...)` | `chunks × workChunkMinutes / 60` — the only conversion in the file |
| `weekFractionFor(goal, logs, today)` | `0.0..1.0`, or `null` when the model has no target |

`weekFractionFor` by goal type: `timeTarget` → hours over `weeklyHourBudget` (null when that budget
is absent or non-positive); `habit` → distinct done-days over `frequencyPerWeek ?? 7`; `outcome` →
**always null**, because the model carries only `deadline` and `outcomeDescription` for outcomes and
any number would be invented state (UI-SPEC item 16).

The null-vs-0.0 distinction is load-bearing for plan 33-03: `0.0` is a real "just started" and paints
a red line, `null` is "no weekly target" and paints an empty grey track. Collapsing them would make
the screen assert something the data cannot support.

## RED was observed, not assumed

Task 1 wrote all 22 cases first and ran them. Captured failure:

```
Compilation failed for testPath=.../test/services/weekly_progress_test.dart:
test/services/weekly_progress_test.dart:15:8: Error: Error when reading
  'lib/services/weekly_progress_service.dart': No such file or directory
test/services/weekly_progress_test.dart:55:19: Error: Method not found: 'WeeklyProgressService'.
00:00 +0 -1: Some tests failed.
```

That only proves the file failed to compile, which is a weak form of red. Because this project has
shipped defects behind assertions that could not fail, I additionally **mutation-tested the two
assertions that carry the most weight**, reverting after each:

| Mutation | Result |
|---|---|
| `weekStart` un-normalised (i.e. reintroduce the generator's bug) | **10 tests fail**, including the Monday-boundary case |
| filter on `attributionId` instead of `goalId` | **exactly 1 test fails** — the commitment-log case, and only that one |

Both assertions can fail, and the commitment one fails with precision rather than by collateral.
No assertion was weakened at any point.

The hours expectation is expressed as `chunks * ScheduleGeneratorService.workChunkMinutes / 60.0`
rather than as a literal, so a re-typed 25 in the service could not satisfy it.

## SEED-006 — and a correction to the plan's own estimate

Specifying the Monday-boundary case surfaced a real defect in
`schedule_generator.dart:314-315`: `_weekStart` never normalises the time of day, so it returns
Monday **at today's clock time**, while a log parses from `YYYY-MM-DD` and is always midnight.

I did not take the plan's characterisation on trust. I reproduced the generator's own expressions
(`:314-328`) against a fixed calendar — Monday 2026-08-31 through Sunday 2026-09-06, every
`today` × `logDate` pair at five clock times. Result:

> **A chunk completed on a Monday never counts toward that week's budget — on every day of the
> week, at every time of day except exactly `00:00:00`.** Tuesday–Sunday logs are unaffected.

This confirms the measured radius and rules out the understated "on any afternoon" framing, which
had the right defect but the wrong blast radius. Cost: `_remainingHours` reads high by exactly
Monday's completions, so `_demandForTimeTarget` over-schedules that goal for the rest of the week,
every week. It has never been reported because the failure is self-consistent — the day just looks
fuller than the budget calls for.

**Not fixed here, by the ROADMAP fence.** `schedule_generator.dart` is untouched (`git diff
--name-only` empty). The new helper is correct and does **not** replicate the bug for consistency;
the divergence is stated in `weekStart`'s doc comment so a later reader does not "fix" the helper
into agreement with the defect. Captured in
`.planning/seeds/SEED-006-week-start-carries-time-of-day.md` with the fix sketch and, more
importantly, the reason it is not a drive-by: the generator's existing tests must be audited for
cases whose expected values silently encode the bug.

**Known consequence, worth stating plainly:** until SEED-006 is closed, the Goals screen's progress
line and the scheduler's own budget arithmetic disagree about Monday. The progress line is the
correct one.

## Deviations from Plan

None. The plan was executed as written.

One cosmetic adjustment, not a deviation from intent: the test file's header comment originally
named the forbidden literal `2.5` while explaining why it must not appear, which tripped the
plan's own mechanical `grep -c "2\.5"` acceptance check. The criterion carries no exemption clause
(unlike SEED-006's `afternoon` criterion, which does), so I reworded the comment to describe the
literal rather than spell it. Done before the RED commit.

## Verification

| Check | Result |
|---|---|
| `flutter test test/services/weekly_progress_test.dart` | **22/22 pass** |
| `flutter test` (full suite) | **643 pass** (621 baseline + 22 new) |
| `flutter analyze` | **No issues found** |
| `grep -c 'package:flutter'` on the service | `0` — pure Dart |
| `grep -c 'workChunkMinutes'` on the service | `2` |
| `grep -v '^\s*//' \| grep -cE '\b25\b'` on the service | `0` — no re-typed chunk length |
| `grep -v '^\s*//' \| grep -c 'attributionId'` on the service | `0` |
| `grep -c "2\.5"` on the test file | `0` |
| `test(` count in the test file | `22` (≥ 15 required) |
| `git diff --name-only` includes `schedule_generator.dart` | **no** — fence held |
| `grep -ci 'afternoon'` on SEED-006 | `2`, both inside explicit corrections of the earlier estimate (the criterion's stated exemption) |

## Known Stubs

None. The service is complete for its contract; no placeholder values, no unwired paths.

## Threat Flags

None. No new network, auth, file-access, or schema surface — the plan's existing register
(T-33-04/05/06) covers everything this code touches. T-33-05 is mitigated and pinned by a test
proven able to fail.

## Self-Check: PASSED

- `lib/services/weekly_progress_service.dart` — FOUND
- `test/services/weekly_progress_test.dart` — FOUND
- `.planning/seeds/SEED-006-week-start-carries-time-of-day.md` — FOUND
- commit `5af86f9` — FOUND
- commit `fd16f5d` — FOUND

---
phase: 38-wrist-timeline-and-outbox
plan: 01
subsystem: wrist
tags: [dart, watch, timeline, outbox, tdd, mutation-testing]
requires: []
provides:
  - "buildWristTimeline: DailySchedule → versioned (instant, now/next) entries; JSON for the watch"
  - "chunkReferenceTitle: one chunk-title function shared by the Today screen and the watch"
  - "ScheduleNotifier.markComplete(id, {at}): the tap-time seam for G-05"
  - "WristAction / WristOutboxStore / WristOutboxReplayer: queued wrist taps replayed on the main isolate"
affects: [39-watch-app-and-complication, 40-complete-skip-from-the-wrist]
---

# 38-01 Summary: Wrist timeline and outbox

## What shipped

- `lib/services/wrist/wrist_timeline.dart`, schema version 1. Entries start at local midnight, change only at chunk
  boundaries, reach `dayComplete` after the last chunk, and end in `noSchedule` at the next midnight. Each entry carries
  the `current` and `next` chunks, with id, kind (work/commitment/shortBreak/longBreak), title, start and end
  instants, and `canComplete`/`canSkip`.
- `lib/services/wrist/wrist_outbox.dart`: tolerant JSON parsing, oldest-first replay, explicit drop reasons
  (`wrongDay`, `chunkNotFound`, `alreadyResolved`, `notAllowed`), failed applies kept for retry, serialised drains.
- `markComplete(chunkId, {DateTime? at})`. A live tap is unchanged. Four test fakes were updated to the new signature.
- `_chunkTitle` in `today_screen.dart` now delegates to `lib/utils/chunk_title.dart`. Behaviour is unchanged, and
  the full suite is green.

## Tests

`test/services/wrist/`: 22 tests. Full suite: **1076 green**, `flutter analyze` clean. The wrist tests also pass under
`TZ=America/Chicago`, which is what makes the two DST tests discriminate.

The spike (the ROADMAP "spike first"): a Complete tapped at 10:18 and replayed at 10:40 leaves the break at
start 618 / 52 min, identical to a live 10:18 tap. Without the seam the result would be 640 / 30.

## Mutation testing

Each mutant was applied by script (`scratchpad/mut.py`), the wrist suite was run under `TZ=America/Chicago`, and the
file was restored. **13 of 13 killed.** Two mutants survived the first pass, and new tests were added to kill them.

| # | Mutant | Killed by |
|---|--------|-----------|
| M1 | `at ?? _now()` → `_now()` | SPIKE replay-vs-live |
| M2 | drop the alreadyResolved guard | duplicate delivery; Skip-after-Complete |
| M3 | no oldest-first sort | Skip-after-Complete |
| M4 | no dedupe of identical neighbours | **survived first pass**; added "boundaries where nothing visible changes collapse" |
| M5 | instants via `Duration` add | DST 9:00 test |
| M6 | trailing entry `dayComplete` instead of `noSchedule` | full sequence test |
| M7 | sample chunk starts only | full sequence; every-minute contract |
| M8 | breaks completable | titles/gates test |
| M9 | drains not serialised | racing drains (strengthened to assert the second drain sees an empty store; the notifier's own guard had made the first version pass either way) |
| M10 | wrong-day check removed | other-day / missing-chunk test |
| M11 | notAllowed check removed | break-skip-only test |
| M12 | failed apply removes the action | failure stays queued |
| M13 | judge state at the local instant, not wall-clock UTC | **survived first pass** (the mutant was too weak); added the DST-gap test |

## Deviations

- There is no `.planning/REQUIREMENTS.md` in this repo. The v1.7 requirement IDs live in
  `research/watch/V1.7-STATUS.md`.

# Phase 38: Wrist Timeline and Outbox (pure Dart) — Context

**Gathered:** 2026-11-10, autonomously. The owner is away; decisions come from
`research/watch/OWNER-DECISIONS-2026-11-10.md` and the parent session's brief. No interactive discussion was
held, so every decision below is the agent's, with its reason.

## Phase boundary

Dart only, testable on danserver. Two pieces:
1. **Wrist timeline:** from today's `DailySchedule`, a versioned list of `(instant, now/next state)` entries that the
   watch can display without running any scheduling logic.
2. **Outbox:** a queue of wrist Complete/Skip taps, each carrying its tap time, replayed on the main isolate through
   the existing `markComplete`/`markSkipped` paths.

No Swift, no channel, and no UI in this phase. The phone-to-watch transport is Phase 39. The native outbox store is
Phase 40.

## Decisions

- **D-38-01 One source of "now".** Every entry's state is computed by `resolveNowState`, the function the Today screen
  renders from. Swift picks `entries.last(where: at <= now)` and nothing else. The contract test checks this for all 1440
  minutes of a fixture day, on a plain day and on one with resolved chunks.
- **D-38-02 Sample at boundaries.** `resolveNowState`'s answer only changes when the clock crosses a chunk start or
  end, so the builder samples it at local midnight and at every boundary, then collapses neighbours that would display
  the same thing.
- **D-38-03 Absolute instants.** Times go to the watch as epoch milliseconds, built with
  `DateTime(y, m, d, 0, minutes)` (local wall clock, correct on DST days). State is judged with a UTC `DateTime`
  carrying the same wall-clock fields, so a minute inside a DST gap is not normalised into the next hour.
- **D-38-04 How the day ends.** After the last chunk the timeline reaches `dayComplete`. At the next local midnight it
  turns to `noSchedule` ("check in on your phone"), which is when the phone itself stops showing this schedule
  (`_resetIfDayChanged`). The watch never shows yesterday's last chunk overnight, and needs no date logic of its own.
- **D-38-05 Titles are shared code.** `today_screen.dart`'s `_chunkTitle` is now a one-line call to
  `chunkReferenceTitle` (`lib/utils/chunk_title.dart`), and the watch uses the same function. Real titles go to the
  wrist (owner decision 5).
- **D-38-06 Action gates match the live row.** Work and commitment chunks get Complete and Skip; breaks get Skip only;
  resolved chunks get nothing.
- **D-38-07 Replay uses the tap time.** `markComplete(chunkId, {DateTime? at})`: `at` replaces `_now()` in G-05's break
  absorption only. A live tap passes nothing and is unchanged.
- **D-38-08 Replay is idempotent and conservative.** Taps are applied oldest first. A tap is dropped, with a recorded
  reason, when it is for another day, its chunk no longer exists (a re-check-in regenerates ids), the chunk is already
  resolved, or it is a Complete on a break. A tap whose apply throws stays queued. Drains are serialised.
- **D-38-09 Store is an interface.** `WristOutboxStore` (pending/remove). Phase 40 supplies the native, file-backed
  one that Swift writes before Dart is running. Tests use `InMemoryWristOutboxStore`.

## Deferred

- Sending the timeline (Phase 39); the native store and the channel ping that triggers a drain (Phase 40).
- **Known edge:** on a spring-forward day, a chunk boundary inside the missing hour (e.g. 2:30am) gets an instant
  that sorts after the following one. No real Canopy day schedules work at 2:30am, so this is recorded, not handled.

---
phase: 05-quarterly-review
plan: 06
subsystem: dev-tooling
tags: [hive_ce, dart-convert, rootBundle, settings, dev-tooling, uat-fixtures]

requires:
  - phase: 01-foundation
    provides: Hive boxes goals/completion_logs/quarterly_snapshots and the matching repositories
  - phase: 02-goals-and-commitments
    provides: HiveGoalRepository.save and Goal HiveType
  - phase: 04-chunk-tracking-and-notifications
    provides: HiveCompletionLogRepository.append for reuse in ingest path
  - phase: 05-quarterly-review
    provides: QuarterlyReviewScreen reads CompletionLog directly without joining ScheduledChunk
provides:
  - Dev-only DevDataLoader (parser + ingest + clearAll) under lib/dev/
  - Bundled scenario asset dev_data/typical_quarter.json (3 goals, 108 logs, 0 snapshots)
  - kDebugMode-gated Settings tiles for ingest and clear (with confirmation dialog)
  - Parser unit tests covering happy/sad paths and a count assertion against the bundled asset
affects:
  - 05-quarterly-review (UAT)
  - any future debug-build seeding workflow

tech-stack:
  added: []
  patterns:
    - "Static-method dev utility with result types (DevIngestParseResult / DevIngestResult / DevClearResult) — never throws to UI"
    - "Bundled JSON fixture loaded via rootBundle.loadString for runtime ingest"
    - "kDebugMode-gated ListTiles co-located with existing dev shortcuts"

key-files:
  created:
    - lib/dev/dev_data_loader.dart
    - test/dev/dev_data_loader_test.dart
    - dev_data/typical_quarter.json
  modified:
    - pubspec.yaml
    - lib/screens/settings/settings_screen.dart

key-decisions:
  - "Stable string IDs (g-health/g-spanish/g-side, c-<slug>-<week>-<idx>) so re-ingest overwrites in place rather than duplicating"
  - "Repositories used for writes (save/append); raw Hive.box.clear() used for wipe because append-only repos deliberately omit a clear API"
  - "Three independent kDebugMode guards (one per tile) instead of converting to a list spread — matches the existing one-tile-per-if shape in this file"
  - "Parser tests only — no widget test for the Settings tiles (out of scope per plan); human-verify is the integration gate"

patterns-established:
  - "Pattern: dev fixtures shipped as JSON assets under dev_data/, declared in pubspec.yaml, loaded via rootBundle"
  - "Pattern: result types with success/data/error fields surface failures without throwing to the UI"

requirements-completed:
  - GAP-05-02-uat-blocked-no-data

duration: ~12min
completed: 2026-04-26
---

# Phase 05 Plan 06: Dev Data Ingest (UAT unblock) Summary

**Dev-only Hive seed/wipe via Settings — bundled 13-week scenario (3 goals + 108 completion logs) loaded through DevDataLoader.ingest() to unblock the remaining 7 UAT tests.**

## Performance

- **Duration:** ~12 min (Tasks 1–2 complete; checkpoint:human-verify pending)
- **Started:** 2026-04-26 (plan invocation)
- **Tasks:** 2 of 3 complete (Task 3 is checkpoint:human-verify — paused, awaiting human validation)
- **Files created/modified:** 5 (3 created, 2 modified)

## Accomplishments

- `DevDataLoader` (parser + ingest + clearAll) implemented in a new `lib/dev/` subsystem, never throws to the UI (try/catch wraps every entry point; failures surface via `DevIngestParseResult.failure` / `DevIngestResult.failure` / `DevClearResult.failure`).
- `dev_data/typical_quarter.json` committed: 3 goals (Health & fitness habit, Learn Spanish time-target, Ship side project outcome), 108 CompletionLog entries spanning Mon 2026-01-05 to Sun 2026-04-05 (13 weeks), 0 QuarterlySnapshots. Stable IDs make re-ingest overwrite in place rather than duplicate. Distribution: 52 health (8 skipped), 36 spanish (4 skipped + 2 deferred — week 5–7 dip simulates a slump), 20 side (1 skipped + 1 deferred — heavier early/late, lighter mid-quarter).
- `pubspec.yaml` declares the asset under `flutter > assets`.
- `lib/screens/settings/settings_screen.dart` gains two `kDebugMode`-gated `ListTile`s immediately after the existing "Open quarterly review (dev)" shortcut: "Ingest dev data" (calls `DevDataLoader.ingest()`, surfaces counts via SnackBar) and "Clear all dev data" (AlertDialog confirmation with red destructive action, then `DevDataLoader.clearAll()`, then SnackBar).
- 4 parser unit tests pass: happy path (inline JSON yields expected counts and field values), 2× sad path (malformed JSON / wrong-shape `goals` field), and a bundled-asset round-trip count assertion (`100 ≤ logs ≤ 120`).
- `flutter analyze`: 0 issues. `flutter test`: 54 passed (50 prior + 4 new). No regressions.

## Task Commits

1. **Task 1 (RED): Failing parser tests** — `59f51c0` (test) — adds `test/dev/dev_data_loader_test.dart` (4 tests). Confirms test compilation fails because `DevDataLoader` does not yet exist.
2. **Task 1 (GREEN): DevDataLoader implementation** — `dfded64` (feat) — adds `lib/dev/dev_data_loader.dart` (parseJson, ingest, clearAll, four result types). Tests 1–3 pass; Test 4 still failing because the asset file is created in Task 2 (expected per plan).
3. **Task 2: Bundled scenario, asset wiring, dev Settings tiles** — `821066d` (feat) — adds `dev_data/typical_quarter.json` (108 logs across 13 weeks, all four parser tests now pass), declares it as an asset in `pubspec.yaml`, adds two `kDebugMode`-gated tiles in `settings_screen.dart`. `dart format` applied; analyzer clean; full suite green.

_Plan metadata commit (this SUMMARY) follows after the human-verify checkpoint._

## Files Created/Modified

- `lib/dev/dev_data_loader.dart` (created) — `DevDataLoader` static utility with `parseJson`, `ingest`, `clearAll` plus four result types (`DevIngestData`, `DevIngestParseResult`, `DevIngestResult`, `DevClearResult`). Uses `HiveGoalRepository`, `HiveCompletionLogRepository`, `HiveQuarterlySnapshotRepository` for writes; raw `Hive.box<T>('name').clear()` for the wipe path.
- `test/dev/dev_data_loader_test.dart` (created) — 4 parser tests under group `DevDataLoader.parseJson`.
- `dev_data/typical_quarter.json` (created) — bundled scenario, 794 lines.
- `pubspec.yaml` (modified) — non-comment `assets:` entry referencing `dev_data/typical_quarter.json`.
- `lib/screens/settings/settings_screen.dart` (modified) — relative import `../../dev/dev_data_loader.dart` and two new `kDebugMode`-gated `ListTile`s (Ingest, Clear with `showDialog<bool>` confirmation). The pre-existing "Open quarterly review (dev)" tile is unchanged.

## JSON Shape (excerpt)

Top-level structure (one sample object per array — full file is 794 lines):

```json
{
  "goals": [
    {
      "id": "g-health",
      "name": "Health & fitness",
      "goalTypeIndex": 2,
      "color": "#4CAF50",
      "priorityWeight": 0.8,
      "sortOrder": 0,
      "frequencyPerWeek": 5,
      "streakCount": 0
    }
    /* + 2 more (g-spanish timeTarget, g-side outcome with deadline 2026-06-30Z) */
  ],
  "completion_logs": [
    {
      "id": "c-health-0-0",
      "chunkId": "dev-health-w0-0",
      "goalId": "g-health",
      "dateYmd": "2026-01-05",
      "eventIndex": 0
    }
    /* + 107 more, last entry dated 2026-04-04 (Sat) */
  ],
  "quarterly_snapshots": []
}
```

Counts (verified at parse time and asserted by Test 4 — `inInclusiveRange(100, 120)` for logs):

| Goal               | id        | type        | logs | skipped | deferred | completed |
| ------------------ | --------- | ----------- | ---: | ------: | -------: | --------: |
| Health & fitness   | g-health  | habit (2)   |   52 |       8 |        0 |        44 |
| Learn Spanish      | g-spanish | timeTarget (0) | 36 |    4 |        2 |        30 |
| Ship side project  | g-side    | outcome (1) |   20 |       1 |        1 |        18 |
| **Total**          |           |             | **108** | **13** | **3** | **92** |

Period: weeks 0–12, Mon 2026-01-05 → Sun 2026-04-05 inclusive. ~12% not-completed (within the 10–15% guidance).

## Verification Output

```
$ flutter analyze
Analyzing agent-ab70d771498bac2bc...
No issues found! (ran in 2.5s)

$ flutter test
00:00 +54: All tests passed!

$ flutter test test/dev/dev_data_loader_test.dart
00:00 +0: DevDataLoader.parseJson happy path — known JSON yields expected entity counts
00:00 +1: DevDataLoader.parseJson sad path — malformed JSON returns failure without throwing
00:00 +2: DevDataLoader.parseJson sad path — wrong shape (goals as string) returns failure
00:00 +3: DevDataLoader.parseJson bundled scenario file — counts match documented range
00:00 +4: All tests passed!
```

## Decisions Made

- **Stable IDs in the bundled JSON** — `g-health`/`g-spanish`/`g-side` for goals, `c-<slug>-<week>-<idx>` for logs. Re-ingest is therefore non-magnifying: `box.put(id, value)` overwrites in place. The recovery path for "I want a clean slate" is Clear → Ingest, not multiple Ingests.
- **Repositories for writes, raw Hive for wipes** — the append-only repositories (`HiveCompletionLogRepository`, `HiveQuarterlySnapshotRepository`) deliberately do not expose a clear/delete API. The dev wipe path is a debug-only escape hatch and uses `Hive.box<T>('name').clear()` directly.
- **Three independent `if (kDebugMode)` guards** — each new tile is wrapped in its own `if (kDebugMode)` rather than converting the existing block to a list spread. Matches the file's existing one-tile-per-if shape (Settings already had the "Open quarterly review (dev)" tile in this form).
- **No GoalsNotifier auto-refresh** — Hive writes do not fire ChangeNotifier events through this path. The human-verify steps instruct the tester to use the "Open quarterly review (dev)" tile after Ingest (which constructs a fresh QuarterlyReviewScreen reading from Hive on init). Adding a notifier-refresh hook risks side effects in screens not in scope and was filed as out-of-scope.
- **Parser tests only, no widget tests** — explicit scope per plan. Human-verify is the integration gate.

## Deviations from Plan

None - plan executed exactly as written.

The plan provided verbatim Dart for the loader, tests, and the two ListTiles; all were used essentially as-given (with one minor formatting reflow from `dart format` — no semantic changes). One small wording tweak in the `pubspec.yaml` comment ("To add additional assets" instead of "To add assets") was made to keep the comment accurate now that an `assets:` block is live above it.

## Issues Encountered

None. RED → GREEN → asset → tiles ran clean. The only friction was that `dart format` slightly reflowed initializer-list indentation on the `DevIngestResult.failure` / `DevClearResult.failure` constructors and tightened collection-element indentation in `settings_screen.dart`; both are formatter-equivalent and were preserved in the Task 2 commit.

## TDD Gate Compliance

Plan-level TDD gate sequence verified in git log:

- RED commit: `59f51c0 test(05-06): RED — dev data loader parser tests`
- GREEN commit: `dfded64 feat(05-06): GREEN — DevDataLoader parser + ingest + clearAll`
- (No REFACTOR commit — code did not require cleanup; plan did not require one.)

The RED commit was confirmed failing (compilation error: `DevDataLoader` undefined) before GREEN was authored, and tests 1–3 immediately passed on GREEN. Test 4 followed the documented exception path (asset file authored in Task 2) — the task acceptance criteria explicitly allow Test 4 to remain failing at the end of Task 1.

## Threat Flags

None. This plan introduces a debug-only ingest/wipe path; the gate is `kDebugMode` at the call site and the JSON asset is hand-curated and bundled with the app. No new network surface, no new auth path, no new file-access pattern reaching outside the app sandbox.

## Known Stubs

None. The `Open quarterly review (dev)` tile (which existed pre-plan) is the integration point used during human-verify; after Ingest it routes to the live `QuarterlyReviewScreen` which reads from Hive directly.

## Self-Check: PASSED

- File `lib/dev/dev_data_loader.dart`: FOUND
- File `test/dev/dev_data_loader_test.dart`: FOUND
- File `dev_data/typical_quarter.json`: FOUND (794 lines)
- File `pubspec.yaml`: contains non-comment `dev_data/typical_quarter.json` asset entry (1 match)
- File `lib/screens/settings/settings_screen.dart`: contains `Ingest dev data` (1) and `Clear all dev data` (2 — title + dialog title) and `DevDataLoader.ingest`/`DevDataLoader.clearAll` (1 each) and `showDialog<bool>` (1)
- Commit `59f51c0`: FOUND in git log
- Commit `dfded64`: FOUND in git log
- Commit `821066d`: FOUND in git log
- `flutter analyze`: clean (No issues found!)
- `flutter test`: 54/54 pass (50 prior + 4 new)

## Next Phase Readiness

Once the human-verify checkpoint is approved:

- UAT can resume via `/gsd-verify-work 5`. Tests 5, 6, 7, 8, 9, 10, and 12 (previously blocked by "Not enough data yet") become exercisable after a single tap on **Settings → Ingest dev data**.
- The Clear tile is the recovery path between UAT runs — wipes goals/logs/snapshots without touching settings, schedules, or commitment blocks.
- Release builds are unaffected: tile call sites are `kDebugMode`-gated, so the three dev tiles never appear in production. The bundled JSON ships in release bundles (small file, compression-friendly); stripping it via build flavors is a future hygiene task and not a blocker.

---
*Phase: 05-quarterly-review*
*Plan: 06*
*Completed: 2026-04-26 (Tasks 1–2; Task 3 checkpoint:human-verify pending)*

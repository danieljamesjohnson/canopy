---
phase: 36-connect-google-calendar-without-hunting-for-a-url
plan: 15
subsystem: calendar-sync
tags: [calendar, sync, prune, persistence, banner, windows-10, windows-11, CAL-02, CAL-04]
requires: [36-12, 36-13, 36-14]
provides:
  - "configuredCalendarIdsFor(settings): selectedCalendarIds U icsUrls, the one definition of 'configured'"
  - "runCalendarSync(commitments, settings, source): one sync for check-in and the Calendars screen"
  - "skipped-events banner reads SettingsNotifier.lastCalendarSyncSkipped (persisted)"
affects: [36-17]
tech-stack:
  added: []
  patterns: ["one function for two callers (WR-02 shape)", "success-only recording", "assertions by block id, never counts"]
key-files:
  created:
    - lib/providers/calendar_sync_runner.dart
    - test/providers/calendar_sync_runner_test.dart
  modified:
    - lib/screens/schedule/checkin_screen.dart
    - lib/screens/settings/calendar_settings_screen.dart
    - test/screens/settings/calendar_settings_screen_test.dart
key-decisions:
  - "The configured set is the union selectedCalendarIds U icsUrls: conservative, it can only keep more blocks."
  - "_lastSyncResult removed outright; nothing reads the last attempt in memory, so showFooter no longer depends on it."
  - "Mobile showFooter = _deviceGranted || googleConnected || lastCalendarSyncAt != null."
requirements-completed: [CAL-02, CAL-04]
duration: ~1h
completed: 2026-11-02
status: complete
commits: 2
plan_head_before: 9da843ead787944291a3a5147af8684c08fde02c
plan_head_after: 7e02db92c1ff133ea87a63ceb65f027f0761d98f
actuals:
  tokens: 30000
  tasks: 2
  commits: 2
---

# Phase 36 Plan 15: One sync, a persisted banner, a prune that runs Summary

Check-in and the Calendars screen now both sync through `runCalendarSync`, which hands the user's configured calendars to 36-12's selection prune and records the skipped list through 36-13's `recordCalendarSyncSuccess` (success only). The skipped-events banner reads that persisted list, so it survives leaving Settings -> Calendars and an app relaunch.

## Tasks

| # | Task | Commit |
|---|------|--------|
| 1 (tracer) | `calendar_sync_runner.dart` (`configuredCalendarIdsFor`, `runCalendarSync`), its 7 tests, check-in moved onto it | 028573f |
| 2 | Calendars screen on the runner; `_skippedBanner` reads persisted state; `_lastSyncResult` removed; `showFooter` rewritten; `_disconnectGoogle` doc corrected; 7 new screen tests | 7e02db9 |

Tracer gate: Task 1's `<verify>` (runner test + `checkin_screen_widget_test` + `cold_launch_morning_loop_test`) was green end to end, and its four mutations done, before Task 2 began. The existing check-in tests passed unedited.

## Final state

- `flutter test`: **999 passed, 0 failed.** Merged wave-1 baseline measured at the start on this tree: **985** (+14: 7 runner tests, 7 screen tests).
- `flutter analyze`: **No issues found!**
- `git diff 8f62a56 -- lib/services/schedule_generator.dart`: **empty** (0 bytes).
- `grep -rhE "setLastCalendarSyncAt\(" lib/screens | grep -vcE "^\s*//"`: **0** (baseline 2).
- Non-comment `runCalendarSync(` calls: check-in 1, Calendars screen 1 (baseline 0 each).
- 36-09's banner-position tests and 36-14's `requestPermissionCount == 0` tests pass unedited. The only edit to an existing test is making the base fake's `calendars` / `events` non-final (the plan's sanctioned change); `git diff` shows exactly those two lines removed.
- `pubspec.yaml` / `pubspec.lock` untouched.

## Mutation proofs (all RUNTIME failures; each reverted, `diff` against the pre-mutation copy printed `identical`)

**Task 1 (a) — `configuredCalendarIds: null` inside `runCalendarSync`.** Only the owner-scenario test failed:
```
Owner scenario: Home -> spunkl ... after unticking home and syncing again, home's block is gone, spunkl's and the hand-entered block remain [E]
  Expected: Set:['b89f3091-a561-4799-9bd1-c44c2e9707f3', 'hand-1']
    Actual: Set:[
     Which: larger than expected
```

**Task 1 (b) — skip the record call** (`if (!result.failed)` -> `if (false)`):
```
a sync that skips an all-day event persists it: this notifier AND a NEW notifier ... [E]
  Expected: ['Vacation']
    Actual: MappedListIterable<SkippedEvent, String>:[]
     Which: at location [0] is MappedListIterable<SkippedEvent, String>:[] which shorter than expected
a failed sync after a successful one leaves lastCalendarSyncAt and the skipped list exactly as the successful one left them ... [E]
  Expected: DateTime:<2026-11-02 09:35:27.404552>
    Actual: <null>
```

**Task 1 (c) — record on failure as well** (`if (!result.failed)` -> `if (true)`):
```
a failed sync after a successful one leaves lastCalendarSyncAt and the skipped list ... [E]
  Expected: DateTime:<2026-11-02 09:35:29.444596>
    Actual: DateTime:<2026-11-02 09:35:29.444726>
```
(The failed result's own `syncedAt` overwrote the last-known one.)

**Task 1 (d) — `configuredCalendarIdsFor` drops `icsUrls`.** The REAL `IcsCalendarSource` test failed independently of the unit test on the union (which also failed, a second witness). The past-dated ICS-imported block (`a2de730c-...`) is the one missing:
```
a past-dated block imported from feed u survives a sync whose settings hold u only in icsUrls [E]
  Expected: contains all of Set:[
              'a2de730c-9e21-40de-9817-6dfc25a4bb19',
              '524ca237-6e6c-4439-b406-640c92f48d90'
            ]
    Actual: Set:['524ca237-6e6c-4439-b406-640c92f48d90']
     Which: has too few elements (1 < 2)
```
`524ca237` is the block this sync itself imported; `a2de730c` was written by a `CalendarSyncService` with `now` three days back from an inline-ICS event two days back, so this sync neither rewrites it nor event-prunes it. Only the feed URL being in the configured set keeps it.

**Task 2 (a) — `_skippedBanner` reads an in-memory result again** (field + setState reinstated). Three tests failed; 36-09's position tests stayed green (the banner was present right after a sync on the same mounted screen, which is exactly the owner-photographed behaviour):
```
leave and re-enter Settings -> Calendars: the banner is still there ... [E]
  Expected: exactly one matching candidate
    Actual: _TextWidgetFinder:<Found 0 widgets with text "1 events not imported — tap for details":
     Which: means none were found but one was expected
relaunch: a NEW SettingsNotifier over the same repository, after init(), shows the banner before any sync has run [E]
  (same: Found 0 widgets with text "1 events not imported — tap for details")
a later sync whose source throws leaves the banner showing the last successful sync's count [E]
  (same)
```

**Task 2 (b) — `_syncAndReport` calls `commitments.syncFromCalendar(source: source)` directly.** The feed-removal test failed along with the recording-dependent tests (this mutation also removes recording, so it is broader than (a) of Task 1):
```
desktop branch, two feeds: removing feed a through the "Remove this calendar?" dialog deletes a's commitments ... [E]
  Expected: not contains '21dddabb-24ca-49e6-9912-c1e5414d8932'
    Actual: Set:[
```
Eight tests failed in all, including the 36-09 position tests and the 35-04 "2 skipped events" test, because nothing is recorded to the banner any more.

Task 2 red-first note: with the screen unmodified, the four target tests (re-enter, relaunch, failed-sync-keeps-banner, feed removal) failed for the stated reasons before any screen change. The other three new tests (banner cleared by a clean sync; desktop and mobile failed-first-sync footer) passed on the old code too: they pin behaviour that must survive the `showFooter` rewrite, and are not claimed as red-first.

## Deviations from Plan

**1. `_syncAndReport`'s `mounted` guard is gone because what it guarded is gone.** It protected only `setState(() => _lastSyncResult = result)`. With that field removed nothing in that method touches State, so there is no guard left to keep. The failure SnackBar still goes through the pre-captured `ScaffoldMessengerState`, as before.

**2. Task 1 tests were written after the runner, not before.** The runner is 20 lines and the discriminating evidence is the four mutations above, each of which turned the intended test red; I did not hand-roll a separate red phase for it. Task 2 did go red first (see above).

**3. Dead fields left in place.** `_MobileState.syncResult` and `_DesktopState.syncResult` are written but nothing reads them (36-14 already removed the last reader when `_footer` stopped taking a `syncResult`). Not caused by this plan's removal and not in its file list scope, so I left them rather than widen the diff; a later cleanup could drop them.

**4. Library doc comment form.** The runner's doc is a `library;`-attached comment (analyze flags a dangling one), not the bare `///` block the plan's wording implies.

**5. Environment hiccup, not a code issue.** One `flutter test` hung on `dart pub get --example` (network); I killed it and re-ran with `--no-pub`. `pubspec.*` unchanged.

Otherwise the plan executed as written. No Rule 1-3 fixes were needed in production code; no checkpoints; no notifications sent.

## Behaviour notes worth knowing

- **Nothing configured means everything imported is pruned.** `configuredCalendarIdsFor` returns an empty set when the user has ticked nothing and holds no feeds, and a non-null empty set switches the selection prune ON for every imported block not written by that sync. That is the intended "unticked it, it goes" semantics (and check-in with no calendar configured has no imported blocks to lose in any case), but it is the sharpest edge of this plan.
- **Post-Disconnect Google residual** is unchanged and now documented in `_disconnectGoogle`'s doc comment: the `google:` ids stay in the selection, so the selection prune keeps them, and the Google child fails without a token, so the event prune skips them. No in-app removal path until the user reconnects and unticks (36-17 logs it).
- The unused-in-production `setLastCalendarSyncAt` remains on `SettingsNotifier` (36-13 kept it); only the two screen call sites moved to the runner.

## Known Stubs

None.

## Threat Flags

None. T-36-54 (one configured-set definition, both callers through it, gated by grep), T-36-55 (banner reads persisted state, unmount/remount and new-notifier tests, mutation-proven) and T-36-56 (real dialog drives the removal, mutation-proven) are mitigated as the plan's register says.

## Self-Check: PASSED

- Files present: `lib/providers/calendar_sync_runner.dart`, `test/providers/calendar_sync_runner_test.dart`, this SUMMARY.
- Commits 028573f and 7e02db9 are ancestors of HEAD; base 9da843e is an ancestor of HEAD.
- STATE.md, ROADMAP.md and WINDOWS.md untouched, per dispatch instructions.

---
phase: 25
plan: 1
subsystem: dev-tooling
tags: [debug-only, clock, uat-infrastructure]
dependency-graph:
  requires: []
  provides: [dev-clock-override]
  affects: [today-screen, schedule-notifier, quarterly-review, settings-screen]
tech-stack:
  added: []
  patterns: ["offset-clock (not frozen-instant)", "kDebugMode-gated static utility, mirrors DevDataLoader"]
key-files:
  created:
    - lib/dev/dev_clock.dart
    - test/dev/dev_clock_test.dart
  modified:
    - lib/main.dart
    - lib/providers/schedule_notifier.dart
    - lib/screens/today/today_screen.dart
    - lib/data/repositories/hive_daily_schedule_repository.dart
    - lib/screens/quarterly_review/quarterly_review_screen.dart
    - lib/screens/settings/settings_screen.dart
decisions:
  - "ScheduleNotifier.reloadToday() added as a new method (not a reuse of init()) so a debug clock mutation never stacks a duplicate WidgetsBindingObserver registration."
  - "The Today screen's simulated-time indicator is shown in both the active-schedule and empty-state branches; the active branch reuses build()'s single nowDt sample (D-01), the empty-state branch reads DevClock fresh since it has no other clock consumer to disagree with."
metrics:
  duration: "~45m"
  completed: 2026-08-10
---

# Phase 25 Plan 1: Time Travel Summary

Debug-only offset-based clock override (`DevClock`) wired into every clock-gated seam so a
simulated moment (e.g. "9pm today") can be inspected without waiting for wall-clock time —
unblocks Phase 24's `DayComplete` UAT item and lays groundwork for Phase 26's now-line testing.

## What was built

**`lib/dev/dev_clock.dart`** — a static utility class, house-styled like `DevDataLoader`:
- Holds a `Duration _offset` (not a frozen `DateTime`) — `now()` is `DateTime.now().add(_offset)`,
  so time keeps flowing while overridden (DEV-02). This is what lets the Today screen's existing
  1-minute ticker keep advancing under simulated time.
- `isActive`, `setSimulatedNow(target)`, `shift(delta)`, `clear()`, `init()` — every mutator and
  `init()` no-ops unless `kDebugMode`, guarded *inside* the class (DEV-03) so no caller needs to
  remember the check. In a release build `_offset` can never become non-zero.
- Persisted via `SharedPreferences` (already a bootstrap dependency) under
  `dev_clock_offset_micros`, so the override survives a page reload (DEV-02, web UAT reloads
  constantly).
- `@visibleForTesting resetForTest()` — clears the in-memory offset without touching
  SharedPreferences or requiring a mock, so tests can simulate a "fresh app launch" cheaply.

**Wiring** — every place the plan identified as load-bearing now reads `DevClock.now()`:
- `main.dart`: `DevClock.init()` runs before any notifier is constructed; `ScheduleNotifier` is
  constructed with `now: DevClock.now`.
- `TodayScreen._nowFn` defaults to `DevClock.now` (was `DateTime.now`). The `TodayScreen.now`
  constructor parameter is untouched, so existing widget tests that inject a clock keep passing
  unchanged.
- `HiveDailyScheduleRepository.getTodaysSchedule()` now computes its `dateYmd` key from
  `DevClock.now()` instead of `DateTime.now()` — the one hard-coded real-time read the plan
  called out as the seam that actually matters (it decides which schedule loads).
- `QuarterlyReviewScreen._loadData()`'s `today` read routes through `DevClock.now()` for
  consistency (cheap, keeps the app self-consistent per the plan).
- Left alone, as instructed: model default timestamps (`generatedAt`, `recordedAt`,
  `completedAt`), `export_service.dart`'s filename timestamp, and the date-picker bounds in the
  goal/commitment form sheets.

**`ScheduleNotifier.reloadToday()`** (new method, not in the original design bullet list but
needed to satisfy it) — `init()`'s load step was extracted into a private `_loadToday()` helper;
`reloadToday()` calls it and `notifyListeners()` WITHOUT re-registering the
`WidgetsBindingObserver`. Calling `init()` itself repeatedly (the naive approach) would add a
duplicate lifecycle observer on every debug-clock mutation. This is the "cleaner path" the plan
invited if the naive approach had a problem — documented here per its own instruction.

**Debug settings UI** (`settings_screen.dart`, extends the existing `if (kDebugMode)` section,
matches its `ListTile` style):
- A status tile: "Simulated: `<date>, <time>`" or "Off — showing real time".
- Quick-action row: `-1h`, `+1h`, `Jump to 9pm today` (the exact `DayComplete` case this phase
  exists to unblock), `Reset to real time` (disabled when already off).
- "Set a specific time" tile → `showDatePicker` then `showTimePicker` → `DevClock.setSimulatedNow`.
- Every handler calls `ScheduleNotifier.reloadToday()` then `setState(() {})` after mutating
  `DevClock`, so the app reflects the change immediately without a manual reload — the existing
  1-minute ticker (Today screen) and this screen's own repaint do the rest, exactly as the plan
  asked for.

**Always-visible indicator** (`today_screen.dart`, DEV-02) — `_buildDevClockBanner` renders a
compact `errorContainer`-colored banner ("Simulated time — …") only when `kDebugMode &&
DevClock.isActive`; `SizedBox.shrink()` otherwise (including every release build). The
active-schedule render path passes it `build()`'s single `nowDt` sample, preserving the D-01
"sample the clock exactly once" discipline — it does NOT call `DevClock.now()` a second time.
The empty-state branch (which has no schedule and therefore no existing `nowDt` sample to reuse)
reads `DevClock.now()` fresh for display only; nothing in that branch derives day-state from it,
so this does not reintroduce the multi-read hazard the discipline guards against.

## Deviations from Plan

None requiring a checkpoint. One in-scope addition beyond the plan's explicit file list:

**1. [Rule 2 - missing critical functionality] Added `ScheduleNotifier.reloadToday()`**
- **Found during:** implementing the settings UI's "ask ScheduleNotifier to reload today's
  schedule" step.
- **Issue:** the only existing reload path was `ScheduleNotifier.init()`, which also calls
  `WidgetsBinding.instance.addObserver(this)`. Calling it again on every clock mutation would
  register a duplicate `WidgetsBindingObserver`, double-firing `didChangeAppLifecycleState` on
  future app-lifecycle transitions.
- **Fix:** extracted the load step into a private `_loadToday()` helper; added a public
  `reloadToday()` that calls it without touching the observer. `init()` now calls the same
  helper, so there is exactly one code path for "read today's schedule from disk."
- **Files modified:** `lib/providers/schedule_notifier.dart`
- **Commit:** `02baabe`

## Verification

- `flutter analyze`: **No issues found.**
- `flutter test`: **512 passed, 0 failed** (504 baseline + 8 new `test/dev/dev_clock_test.dart`
  tests). Full suite run, not a targeted subset.
- `dart format`: clean on all touched files.
- Manually traced (not UAT'd live by Dan, per this phase's scope — dev instrumentation, no
  user-facing UAT gate): the Settings → Time Travel → "Jump to 9pm today" path calls
  `DevClock.setSimulatedNow` → `ScheduleNotifier.reloadToday()` → `setState`; the Today screen's
  existing 1-minute ticker and `_syncFastTimer` logic are untouched, so once the schedule/now
  state updates, the rest of the render path (edge-state line, live row, marker) follows its
  existing, unmodified logic against the new `DevClock.now()` reads.

## Known Stubs

None — every seam listed in the design is wired; no placeholder data paths were introduced.

## Threat Flags

None — this phase adds no network surface, auth path, or schema change. It IS new file-access
surface (SharedPreferences write) but it's a debug-only utility that no-ops in release builds
(DEV-03), matching the existing risk profile of `DevDataLoader`'s Hive-box wipes.

## Self-Check: PASSED

- `lib/dev/dev_clock.dart` — FOUND
- `test/dev/dev_clock_test.dart` — FOUND
- `lib/main.dart` — FOUND (DevClock.init() + ScheduleNotifier(now: DevClock.now) present)
- `lib/providers/schedule_notifier.dart` — FOUND (reloadToday() present)
- `lib/screens/today/today_screen.dart` — FOUND (_buildDevClockBanner, _nowFn default present)
- `lib/data/repositories/hive_daily_schedule_repository.dart` — FOUND (DevClock.now() present)
- `lib/screens/quarterly_review/quarterly_review_screen.dart` — FOUND (DevClock.now() present)
- `lib/screens/settings/settings_screen.dart` — FOUND (Time travel section present)
- Commits `985f71b`, `c3b9784`, `b463661`, `02baabe`, `a5b1ab3`, `c779503` — all FOUND in
  `git log --oneline --all`

---

## Orchestrator addendum (2026-08-10)

Three things were added after the executor returned, all verified by mutation testing:

**1. Wiring coverage (`test/dev/dev_clock_wiring_test.dart`, commit `38544fc`).**
The executor's 8 tests covered DevClock's own arithmetic. Nothing covered the wiring, so DevClock
could have been perfectly correct while time travel did nothing observable — a failure that would
only have surfaced during a manual UAT, i.e. the exact loop this phase exists to close. Two tests
now assert that `getTodaysSchedule()` loads the *simulated* day's schedule (with a real-day schedule
also on disk, to rule out a false positive) and that an overridden clock still rolls 23:59 into the
next day. Reverting `getTodaysSchedule` to `DateTime.now()` fails both.

**2. A real integration defect between Phase 24 and Phase 25 (commit `513552a`).**
Phase 24's centre-on-open one-shots reset only on a `dateYmd` change. Jumping from morning to 9pm on
the same day does not change `dateYmd`, so the list would not re-scroll — meaning "jump to 9pm and
check DayComplete", the workflow this harness was built for, would have shown a stale scroll
position and reported a false negative against a fix that works. `build()` now re-arms both
one-shots when `DevClock.offset` changes. The accompanying test pins both halves: a plain minute
tick must NOT move the list (T-22-08), and the identical tick MUST move it once the clock jumped.

**3. `DevClock.setOffsetForTest`** — a synchronous test hook, since the real mutators are async and
persist.

### Known coverage gaps, stated rather than papered over

- **DEV-03 (release safety) is not covered by a test and cannot easily be.** `kDebugMode` is `true`
  under `flutter test`, so the release no-op path is unreachable from the suite. The guarantee rests
  on inspection: every mutator and `init()` early-returns on `!kDebugMode`, and `resetForTest` /
  `setOffsetForTest` can only ever set the offset to a value, never persist one. Believed correct,
  not proven by test.
- **The Settings debug UI has no widget test.** The handlers are thin wrappers over DevClock methods
  that are themselves covered, and the screen has no existing test file to extend. The controls'
  first real exercise is Dan's own use.
- A headless boot check confirmed the app starts cleanly with `await DevClock.init()` in `main()`
  (all 8 Hive boxes open, no JS errors) — that was the main bootstrap risk.

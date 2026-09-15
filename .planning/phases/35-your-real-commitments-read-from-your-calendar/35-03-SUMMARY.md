---
phase: 35-your-real-commitments-read-from-your-calendar
plan: 03
subsystem: calendar-import
tags: [hive, calendar, settings, migration, flutter]

requires:
  - phase: 35-01
    provides: "CalendarSource interface, NullCalendarSource, defaultCalendarSource platform switch, CalendarSyncService"
provides:
  - "NullCalendarSource's CAL-04 guarantee proven by test, not assumed — every method returns a safe empty answer, none throws, and a sync against it leaves hand-entered commitments untouched"
  - "AppSettings.selectedCalendarIds/icsUrls/lastCalendarSyncAt — CAL-02's persisted calendar configuration, schema 10->11"
  - "SettingsNotifier setSelectedCalendarIds/addIcsUrl/removeIcsUrl/setLastCalendarSyncAt, constructor-injectable repository"
affects: ["35-04", "35-05", "35-06"]

actuals:
  tokens: 6100
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "@HiveField(n, defaultValue: <T>[]) for a non-nullable List<T> field — without it, hive_ce's generated read() emits a straight (fields[n] as List).cast<T>() with no null-coalescing, which throws on a genuinely old record where the field is physically absent from the binary"
    - "SettingsNotifier(repository: ...) constructor injection, mirroring CommitmentsNotifier's repository-with-production-default idiom, added specifically to make it testable against InMemoryAppSettingsRepository"
    - "Hand-copy the pre-change generated adapter into a throwaway write-only TypeAdapter in the test file, write with it, then Hive.registerAdapter(newAdapter, override: true) and reopen — the only way to produce a truly old (field-physically-absent) binary record for an upgrade test without reimplementing Hive's box file format"

key-files:
  created:
    - test/data/calendar/null_calendar_source_test.dart
    - test/providers/settings_notifier_calendar_test.dart
  modified:
    - lib/data/models/app_settings.dart
    - lib/data/models/app_settings.g.dart
    - lib/data/database/migrations.dart
    - lib/providers/settings_notifier.dart
    - test/data/migration_schema8_test.dart

key-decisions:
  - "lib/data/calendar/calendar_source_factory.dart needed NO code change — 35-01 already implemented the exact per-platform branch structure this task specified (web/desktop -> Ics-or-Null by icsUrls emptiness, mobile -> Null with a comment naming 35-05). Only the proof (this task's test file) was missing."
  - "@HiveField(9, defaultValue: <String>[]) / @HiveField(10, defaultValue: <String>[]) added to selectedCalendarIds/icsUrls — required after a real old-record round-trip test proved the plan's plain declaration crashes on upgrade (see Deviations)."
  - "SettingsNotifier gained a constructor-injectable AppSettingsRepository (production default HiveAppSettingsRepository()) — not explicitly asked for in the plan's action text, but required to test against InMemoryAppSettingsRepository per the plan's own must_haves ('the persistence test round-trips through the repository'), and it mirrors CommitmentsNotifier's already-established idiom exactly."

patterns-established:
  - "A List<T> (or any non-nullable, non-primitive-with-obvious-Hive-default) HiveField added in an additive migration MUST carry an explicit @HiveField(n, defaultValue: ...) or the generated read() will crash on a genuinely old record — checked by an actual round-trip test with a hand-copied old adapter, not by trusting the migration comment's claim."

requirements-completed: [CAL-02, CAL-04]

coverage:
  - id: D1
    description: "Every NullCalendarSource method (isAvailable, requestPermission, listCalendars, listEvents) returns a safe empty/notApplicable answer and none throws"
    requirement: "CAL-04"
    verification:
      - kind: unit
        ref: "test/data/calendar/null_calendar_source_test.dart#NullCalendarSource — every call is a safe empty answer, never throws (CAL-04)"
        status: pass
    human_judgment: false
  - id: D2
    description: "A CalendarSyncService.sync() run against NullCalendarSource over two hand-entered blocks imports nothing, deletes nothing, reports no failure, and leaves both blocks' ids/fields unchanged"
    requirement: "CAL-04"
    verification:
      - kind: unit
        ref: "test/data/calendar/null_calendar_source_test.dart#A sync against NullCalendarSource leaves hand-entered commitments exactly as they were (CAL-04)"
        status: pass
    human_judgment: false
  - id: D3
    description: "defaultCalendarSource returns NullCalendarSource with no configured URLs and IcsCalendarSource on this desktop test platform with a URL configured (D-35-12) — code already correct from 35-01, now proven"
    requirement: "CAL-04"
    verification:
      - kind: unit
        ref: "test/data/calendar/null_calendar_source_test.dart#defaultCalendarSource — the platform switch (D-35-12)"
        status: pass
    human_judgment: false
  - id: D4
    description: "AppSettings.selectedCalendarIds/icsUrls/lastCalendarSyncAt round-trip through SettingsNotifier -> AppSettingsRepository and survive a restart (a fresh notifier instance reading the same repository)"
    requirement: "CAL-02"
    verification:
      - kind: unit
        ref: "test/providers/settings_notifier_calendar_test.dart#SettingsNotifier — calendar selection/feeds/last-sync persist across a restart (CAL-02)#setting a selection, adding two feed URLs and setting a last-sync time round-trips through the repository"
        status: pass
    human_judgment: false
  - id: D5
    description: "An old (schema 10, 9-field) AppSettings record reads back under the new (12-field) adapter with an empty selection, no feed URLs and a null last-sync time — no crash"
    requirement: "CAL-02"
    verification:
      - kind: unit
        ref: "test/providers/settings_notifier_calendar_test.dart#AppSettings schema 10→11 — an old record survives the upgrade (CAL-02)"
        status: pass
    human_judgment: false

duration: 55min
completed: 2026-09-15
status: complete
---

# Phase 35 Plan 03: The always-safe fallback and a home for the calendar choice Summary

**`NullCalendarSource`'s CAL-04 guarantee proven by a real test (not inspection), and `AppSettings` gains `selectedCalendarIds`/`icsUrls`/`lastCalendarSyncAt` on a schema-11 bump — with a genuine old-record crash bug found and fixed by the mandated mutation proof before the plan could be called done.**

## Performance

- **Duration:** ~55 min
- **Completed:** 2026-09-15
- **Tasks:** 2
- **Files modified:** 7 (2 created, 5 modified)

## Accomplishments

- `test/data/calendar/null_calendar_source_test.dart`: 8 tests proving CAL-04 directly — every `NullCalendarSource` interface method returns a safe empty answer and none throws; a real `CalendarSyncService.sync()` against `NullCalendarSource` over two seeded hand-entered blocks imports nothing, deletes nothing, reports `failed == false`, and leaves both blocks' ids/fields exactly as they were (compared by field, not by count); `defaultCalendarSource`'s platform switch verified directly rather than by re-reading the source.
- **`lib/data/calendar/calendar_source_factory.dart` needed zero code changes** — 35-01 had already implemented the exact per-platform branch structure this task's `<action>` specifies. The gap this task closed was the missing proof, not the missing code.
- `AppSettings` gains `selectedCalendarIds` (HiveField 9), `icsUrls` (HiveField 10), `lastCalendarSyncAt` (HiveField 11) — CAL-02's persisted state. Schema bumped 10→11 with an appended, comment-only no-op migration (`_migration10to11`), following the file's own append-only rules exactly (`git diff` on `migrations.dart` shows only the appended function, the version constant, and one added list line).
- `SettingsNotifier` gains a constructor-injectable `AppSettingsRepository` (mirrors `CommitmentsNotifier`'s idiom) plus `setSelectedCalendarIds`, `addIcsUrl` (deduping), `removeIcsUrl`, `setLastCalendarSyncAt` — each persists through the repository then notifies exactly once.
- No permission-state field and no "calendar enabled" boolean were added, per D-35-10 — the presence of a selection or feed URL IS the configured state.
- `test/providers/settings_notifier_calendar_test.dart`: 9 tests — a full round-trip through `InMemoryAppSettingsRepository` via two separate `SettingsNotifier` instances (never reading a value back off the same object that just set it), `addIcsUrl` dedup, `removeIcsUrl` scoping, default-construction shape, one "notifies exactly once" test per setter, and a real Hive binary round-trip proving an old (9-field) record survives the schema 10→11 upgrade.

## Task Commits

1. **Task 1: The app is fully usable with no calendar at all — proven, not assumed (CAL-04)** — `cedee3f` (test)
2. **Task 2: Somewhere for the calendar choice to live (CAL-02)** — `5c2dd27` (feat)

**Plan metadata:** this commit (`docs(35-03): complete plan` — see Final Commit below)

## Files Created/Modified

- `test/data/calendar/null_calendar_source_test.dart` - the 8-test CAL-04 proof (interface safety, real sync-against-Null, platform switch)
- `test/providers/settings_notifier_calendar_test.dart` - the 9-test CAL-02 proof (repository round-trip, dedup, notification count, real old-record Hive upgrade)
- `lib/data/models/app_settings.dart` - `selectedCalendarIds`/`icsUrls` (HiveField 9/10, with `defaultValue: <String>[]`), `lastCalendarSyncAt` (HiveField 11)
- `lib/data/models/app_settings.g.dart` - regenerated adapter (schema 11, 12 fields, null-coalescing read for the two list fields)
- `lib/data/database/migrations.dart` - `currentSchemaVersion` 10→11, `_migration10to11` (comment-only no-op, appended)
- `lib/providers/settings_notifier.dart` - constructor-injectable repository; `setSelectedCalendarIds`/`addIcsUrl`/`removeIcsUrl`/`setLastCalendarSyncAt`
- `test/data/migration_schema8_test.dart` - schema-version constant bumped 10→11 (see Deviations, same precedent as 35-01)

## Decisions Made

**`calendar_source_factory.dart` required no changes.** Read the file at the start of Task 1 expecting to fill in the platform branches per the plan's `<action>`; it was already exactly that shape from 35-01's tracer commit. Verified via `git log --oneline -- lib/data/calendar/calendar_source_factory.dart`, which shows only 35-01's commit. Confirmed the acceptance criteria's comment-count grep and the behavior list against the existing file rather than re-writing it.

**`SettingsNotifier(repository: ...)` constructor injection added.** The plan's action text for Task 2 doesn't explicitly ask for this, but its own `must_haves`/`behavior` require testing the persistence round-trip against an in-memory repository, and `SettingsNotifier` had no injection seam (`final AppSettingsRepository _repository = HiveAppSettingsRepository();`, hardcoded). Added the same `repository ?? HiveAppSettingsRepository()` idiom `CommitmentsNotifier` already uses — a minimal, analog-following change, not an architectural one.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `@HiveField(9)`/`@HiveField(10)` needed `defaultValue: <String>[]` — the plan's plain field declaration crashes on a genuinely old record**
- **Found during:** Task 2, writing the mandated old-record Hive round-trip test
- **Issue:** The plan's action text specifies `@HiveField(9) List<String> selectedCalendarIds` with no `defaultValue`. hive_ce's generated `read()` for a non-nullable `List<String>` with no `defaultValue` emits a straight `(fields[9] as List).cast<String>()`. For a genuinely old record — HiveField 9 physically absent from the binary (not merely present-but-null) — `fields[9]` is `null`, and `null as List` throws `type 'Null' is not a subtype of type 'List<dynamic>'`. This directly contradicts the plan's own must_have: *"Old records deserialize with an empty selection, no feed URLs and a null last-sync time — an existing user upgrading sees no calendar configured and nothing broken."* Confirmed empirically, not by inspection: wrote a real Hive box using a hand-copied pre-Phase-35 (9-field) `TypeAdapter`, closed it, re-registered the new 12-field adapter with `override: true`, reopened — and the read threw exactly that `TypeError`.
- **Fix:** Added `@HiveField(9, defaultValue: <String>[])` and `@HiveField(10, defaultValue: <String>[])`, regenerated the adapter. The generated `read()` now reads `fields[9] == null ? [] : (fields[9] as List).cast<String>()` — null-safe.
- **Files modified:** `lib/data/models/app_settings.dart`, `lib/data/models/app_settings.g.dart`
- **Verification:** Re-ran the same old-record round-trip test — passes; `readBack.selectedCalendarIds`/`icsUrls` read back as `[]`, `lastCalendarSyncAt` as `null`, `morningNotificationMinutes` (a pre-existing field) unchanged at 500.
- **Consequence for the plan's own acceptance criteria:** the literal grep `grep -cE '@HiveField\(9\)|@HiveField\(10\)|@HiveField\(11\)' lib/data/models/app_settings.dart` (with an immediate closing paren after the field number) now matches only **1**, not 3, because fields 9/10 carry a trailing `defaultValue` argument before their closing paren. The equivalent check without that assumption — `grep -cE '@HiveField\(9|@HiveField\(10|@HiveField\(11' lib/data/models/app_settings.dart` — correctly reads **3**. Recording this rather than silently satisfying the letter of the original grep at the cost of the actual must_have it exists to protect.
- **Committed in:** `5c2dd27` (Task 2 commit)

**2. [Rule 1 - Bug] Updated the pre-existing schema-version regression test in lockstep with the 10→11 bump**
- **Found during:** Task 2, running the full suite after the migration change
- **Issue:** `test/data/migration_schema8_test.dart` hardcodes `expect(currentSchemaVersion, equals(10))` in two tests — the same living-regression-test pattern 35-01 already updated once (9→10). Bumping `currentSchemaVersion` to 11 without updating it would leave the suite red.
- **Fix:** Updated both assertions to `equals(11)` and refreshed the comment to describe the 10→11 change, matching the file's own established pattern and 35-01's precedent exactly.
- **Files modified:** `test/data/migration_schema8_test.dart`
- **Verification:** `flutter test` — 763/763 green (754 pre-existing + 9 new)
- **Committed in:** `5c2dd27` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (Rule 1 — a genuine crash-on-upgrade bug caught by the mandated old-record proof, and a pre-existing test tracking a moving schema constant per 35-01's precedent)
**Impact on plan:** The first deviation is not scope creep — it's the exact category of defect CLAUDE.md's "Assertions that cannot fail" section warns about, caught here by actually writing the round-trip test the plan's must_haves demanded rather than trusting the migration comment's claim. The second is necessary bookkeeping with an established precedent.

## Mutation Proofs (required by acceptance criteria)

### Proof 1 — CAL-04: sync against NullCalendarSource actually discriminates

`sync()` in `lib/services/calendar_sync_service.dart` was temporarily changed to delete any existing block not touched by the current sync:

```dart
for (final block in existing) {
  if (!imported.any((b) => b.id == block.id)) {
    await _repository.delete(block.id);
  }
}
```

Running `flutter test test/data/calendar/null_calendar_source_test.dart` with this defect in place:

```
A sync against NullCalendarSource leaves hand-entered commitments exactly as they were (CAL-04)
imports nothing, deletes nothing, reports no failure, and the two pre-seeded blocks survive
with their original ids and fields unchanged [E]
  Expected: an object with length of <2>
    Actual: []
     Which: has length of <0>
```

The defect was then reverted (`git diff --stat -- lib/services/calendar_sync_service.dart` is empty); `flutter analyze` and the full suite are green on the reverted code.

### Proof 2 — CAL-02: the persistence round-trip test actually discriminates

`setSelectedCalendarIds` in `lib/providers/settings_notifier.dart` was temporarily changed to skip the repository write (comment out the save, keep only the local field assignment). Running `flutter test test/providers/settings_notifier_calendar_test.dart` with this defect in place:

```
setting a selection, adding two feed URLs and setting a last-sync time round-trips
through the repository [E]
  Expected: ['cal-1', 'cal-2']
    Actual: []
     Which: at location [0] is [] which shorter than expected
```

The defect was then reverted (`git diff --stat -- lib/providers/settings_notifier.dart` after revert matches the committed diff exactly, no leftover mutation); `flutter analyze` and the full suite are green on the reverted code.

### Proof 3 — CAL-02: the old-record crash was real, not hypothetical

Covered in full under Deviations above (Rule 1, item 1) — this is the proof that DROVE the fix, not a proof performed after the fact on already-correct code. Recorded here too because it is the plan's most consequential mutation proof: without it, the plan's shipped code would have silently crashed every real user's app on the schema 10→11 upgrade the first time `AppSettings` was read.

## Issues Encountered

**Pre-existing latent risk discovered, out of scope, logged rather than fixed.** While diagnosing Proof 3, the same defect class was found to already exist for `AppSettings.eveningReminderEnabled`/`eveningReminderMinutes` (HiveField 7/8, non-nullable, no `defaultValue`, generated as a straight cast with no null-coalescing) and for `ScheduledChunk.isDeferred` — both predate this plan and are not caused by anything in 35-03. Per the Scope Boundary rule (only auto-fix issues directly caused by the current task's changes), this was NOT fixed here. Logged to `.planning/WINDOWS.md` as entry 3 (`kind: deviation`) rather than silently left undiscovered:

> Pre-existing non-nullable bool/int HiveFields (eveningReminderEnabled/eveningReminderMinutes, fields 7/8) have no defaultValue and generate a straight cast with no null-coalescing — a genuinely old record missing those fields would throw on read, same defect class fixed in 35-03 for the new List<String> fields. Out of scope for 35-03 (pre-existing, not caused by this task); not fixed.

This is a real risk to an existing user upgrading across whichever historical version first shipped fields 7/8 (`_migration4to5`, per that migration's own comment) — worth a dedicated follow-up, not this plan's job.

## Known Stubs

None. Both tasks ship real, tested behavior — no hardcoded empty values flow to any UI in this plan (there is no UI yet; that's plan 35-04's job building on this data layer).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `NullCalendarSource`'s CAL-04 guarantee is now a passing, mutation-proofed test, not an assumption — plan 35-04's calendar settings screen can rely on the platform switch and the always-safe fallback without re-verifying either.
- `AppSettings.selectedCalendarIds`/`icsUrls`/`lastCalendarSyncAt` and their `SettingsNotifier` setters are ready for 35-04's calendar settings screen to read and write directly.
- `schedule_generator.dart` is untouched (`git diff --stat -- lib/services/schedule_generator.dart` is empty for both commits in this plan).
- The old-record upgrade path is now proven correct for `AppSettings` schema 10→11 specifically. The pre-existing risk at fields 7/8 (and `ScheduledChunk.isDeferred`) remains open in `.planning/WINDOWS.md` for a future phase.

## Self-Check: PASSED

All 6 created/modified files checked with `test -f` are present on disk (both new test files; `app_settings.dart`, `migrations.dart`, `settings_notifier.dart`, and `calendar_source_factory.dart` — the last confirmed unchanged, not newly created). Both commits (`cedee3f`, `5c2dd27`) confirmed present in `git log --oneline --all`. No missing items.

---
*Phase: 35-your-real-commitments-read-from-your-calendar*
*Completed: 2026-09-15*

---
phase: 36-connect-google-calendar-without-hunting-for-a-url
plan: 13
subsystem: persistence
tags: [hive, migration, calendar, settings, windows-entry-10]
requires: []
provides:
  - "AppSettings.lastCalendarSyncSkippedTitles / lastCalendarSyncSkippedReasons (HiveFields 16/17)"
  - "SettingsNotifier.lastCalendarSyncSkipped + recordCalendarSyncSuccess"
  - "currentSchemaVersion 14 with _migration13to14"
affects: [36-15]
tech-stack:
  added: []
  patterns: ["additive non-nullable List<String> HiveField with defaultValue (Q-02)"]
key-files:
  created:
    - test/data/migration_schema14_test.dart
  modified:
    - lib/data/models/app_settings.dart
    - lib/data/models/app_settings.g.dart
    - lib/providers/settings_notifier.dart
    - lib/data/database/migrations.dart
    - test/providers/settings_notifier_calendar_test.dart
    - test/data/migration_schema_test.dart
    - test/data/migration_schema13_test.dart
decisions:
  - "Two parallel List<String> fields (titles + SkipReason.name) instead of a new Hive type adapter"
  - "Reasons stored by enum NAME, not index; unknown names dropped on decode"
metrics:
  tasks: 2
  completed: 2026-11-02
status: complete
actuals:
  tokens: 0
  tasks: 2
  commits: 2
plan_head_before: 035cbf25fc0719bd8a9989c435589f95df4440f1
plan_head_after: ff85042d9b39352ddf0a638fbb52fdbb75df2f4b
---

# Phase 36 Plan 13: Durable skipped-events record Summary

The last successful calendar sync's skipped events are now persisted in two additive `defaultValue: <String>[]` AppSettings fields (schema 14), recorded with the sync time in one save, and restored defensively at `SettingsNotifier.init()`. This is the data half of WINDOWS entry 10; plan 36-15 wires callers and the banner.

## Commits

| Task | Commit | What |
|---|---|---|
| 1 (tracer) | 9ac90df | HiveFields 16/17, regenerated adapter, notifier getter + `recordCalendarSyncSuccess`, 8 new tests |
| 2 | ff85042 | schema 13->14, `_migration13to14`, `migration_schema14_test.dart`, version assertions updated |

## Mutation proofs (both runtime failures, both reverted)

**1. Record updates the in-memory cache only, skips the save.** Removed `await _repository.saveSettings(settings);` from `recordCalendarSyncSuccess`. The fresh-notifier test failed at runtime:

```
a NEW notifier over the same repository sees the same skipped list and time (app killed and relaunched) [E]
  Expected: ['Vacation', 'Standup']
    Actual: MappedListIterable<SkippedEvent, String>:[]
     Which: at location [0] is MappedListIterable<SkippedEvent, String>:[] which shorter than expected
  test/providers/settings_notifier_calendar_test.dart 407:11  main.<fn>.<fn>
```

Restored from a backup copy; suite back to 23/23 in that file.

**2. `defaultValue:` removed from HiveField 16.** Edited to `@HiveField(16)`, regenerated; the adapter then read `..lastCalendarSyncSkippedTitles = (fields[16] as List).cast<String>()` (unguarded). The old-record test failed at runtime:

```
an old (schema 13, 16-field) AppSettings record reads back under the new (18-field) adapter ... [E]
  type 'Null' is not a subtype of type 'List<dynamic>' in type cast
  package:canopy/data/models/app_settings.g.dart 38:53       AppSettingsAdapter.read
  package:hive_ce/src/binary/binary_reader_impl.dart 404:33  BinaryReaderImpl.read
```

Annotation restored, regenerated; `git diff HEAD -- lib/data/models/app_settings.g.dart lib/data/models/app_settings.dart` was empty (0 lines). The failure text is also recorded in the new test file's header. Note the real message names `List<dynamic>`, not `bool` as in the 36-01 crash.

## Verification

- `flutter test`: **944 passed, 0 failed** (baseline 934; +10: 8 notifier tests, 2 schema-14 tests).
- `flutter analyze`: No issues found.
- Gate `git diff 8f62a56 -- lib/services/schedule_generator.dart`: empty.
- Generated files: after regeneration only `app_settings.g.dart` changed (checked with `git status --short` and `git diff --stat df106fe -- lib/ | grep .g.dart`); writer's leading field count is 18, fields 16/17 read as `fields[N] == null ? [] : ...`.
- `_migration13to14` comment names `defaultValue` and does not use the phrase "reader returns"; the only deleted migration-file line is the old `currentSchemaVersion = 13`.

## Deviations from Plan

**1. [Rule 1 - Bug] Test-harness adapter registration.** The second schema-14 test initially failed with `HiveError: There is already a TypeAdapter for typeId 6` because the registry persists across tests. Fixed with `override: true` in the test. No production code affected.

**2. [Rule 3 - Blocking] `dart format` reflowed unrelated lines in `settings_notifier.dart`** (pre-existing long lines). Reverted those two hunks by hand so the diff contains only this plan's change.

Otherwise the plan executed as written. The `migration_schema13_test.dart` change touched only the four stored-version expectations (the test title still says "reads 13", left alone per "touch nothing else").

## Known Stubs

None. `recordCalendarSyncSuccess` has no caller yet by design; plan 36-15 moves the two sync callers onto it. `setLastCalendarSyncAt` is retained.

## Threat Flags

None. T-36-48 (old-record crash) and T-36-49 (disclosure lifetime) are mitigated and proven by the two mutations above.

## Self-Check: PASSED

- test/data/migration_schema14_test.dart present; commits 9ac90df and ff85042 are ancestors of HEAD.
- STATE.md, ROADMAP.md and WINDOWS.md untouched, per dispatch instructions.

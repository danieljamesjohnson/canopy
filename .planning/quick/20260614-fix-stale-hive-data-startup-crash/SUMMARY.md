---
slug: fix-stale-hive-data-startup-crash
type: quick
status: complete
completed: 2026-06-14
area: data/database
---

# Summary — Fix stale Hive data startup crash

## Outcome

Startup is now resilient to incompatible/corrupt persisted Hive data. Each box
opens through `openBoxResilient`, which on a deserialization failure discards
that box's on-disk data and reopens it empty instead of letting an uncaught
error blank the app. Acceptance met: a profile carrying older-version data boots
without an uncaught error (the bad box is reset) and never shows a blank screen.

## Changes

- **Added** `lib/data/database/resilient_box.dart` — `openBoxResilient<T>`:
  try-open → on failure log + best-effort `deleteFromDisk` → reopen. Open/delete
  injected for testability. Delete errors are swallowed (the `.hive` data file is
  removed before the `.lock` file, so the known VM-backend lock-file race must
  not abort recovery); the reopen is the recovery signal and rethrows only if the
  box is genuinely unrecoverable.
- **Modified** `lib/data/database/hive_database.dart` — all 7 `openBox` calls now
  go through a private `_openBox` wrapper over `openBoxResilient`.
- **Added** `test/data/resilient_box_test.dart` — 4 tests: success path,
  reset-and-retry, rethrow-when-unrecoverable, and a real-Hive integration test
  that reproduces the unknown-typeId crash and asserts clean recovery.

## Verification

- `flutter analyze` on changed files: no issues.
- `flutter test test/data/resilient_box_test.dart`: 4/4 pass (recovery confirmed;
  expected best-effort-delete debugPrint observed).
- Full suite: `flutter test` → 247/247 pass (no regressions). The 4 pre-existing
  analyze infos live in `test/screens/active_chunk_card_test.dart` (untouched).

## Scope note / follow-up

Fix is at the documented root-cause layer (Hive deserialization on open), which
matches the bug's hypothesis. If the captured stack later source-maps to a throw
in **app logic** (e.g. a Phase 17 Home/engine read of a valid-but-old record)
rather than Hive deserialization, the next step is an app-root guard
(`runZonedGuarded` / `ErrorWidget.builder`) presenting a "reset local data"
recovery affordance. Not built now to avoid speculative new UI surface.

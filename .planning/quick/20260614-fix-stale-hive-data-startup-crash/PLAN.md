---
slug: fix-stale-hive-data-startup-crash
type: quick
created: 2026-06-14
area: data/database
---

# Fix stale Hive data startup crash (blank screen on old IndexedDB)

## Problem

A browser/profile holding Canopy data from an **older app version** opens all 7
Hive boxes, then throws an **Uncaught Error** during startup → blank screen (no
onboarding, no Home). Fresh/incognito storage works. A non-lazy `Box` eagerly
deserializes every stored frame on open, so a single record whose binary shape
the current adapters cannot read (unknown typeId / removed field) blows up the
whole app instead of degrading gracefully.

Full investigation: `.planning/debug/stale-hive-data-startup-crash.md`.

## Approach

Targeted fix at the documented root-cause layer (Hive deserialization on open):
make each box open **resilient**. If `openBox` throws, discard that box's
on-disk data and reopen it empty. The user loses only the unreadable box's
contents (the engine regenerates schedules/snapshots); every other box and the
app itself survive. Chosen over a top-level recovery screen because the captured
hypothesis points squarely at per-record deserialization, and a per-box reset is
contained, automatic, and needs no new UI.

## Tasks

1. `lib/data/database/resilient_box.dart` — `openBoxResilient<T>(name, open,
   deleteFromDisk)`: try open → on failure log, best-effort delete from disk,
   reopen. Open/delete injected for testability. Delete is best-effort because
   the VM/desktop backend deletes the `.hive` data file before the `.lock` file
   and a trailing lock-file race must not abort recovery; the reopen is the real
   recovery signal and rethrows only if the box is genuinely unrecoverable.
2. `lib/data/database/hive_database.dart` — route all 7 `Hive.openBox` calls
   through a private `_openBox` wrapper over `openBoxResilient`.
3. `test/data/resilient_box_test.dart` — unit tests for the recovery control
   flow (success / reset-and-retry / rethrow) + a real-Hive integration test
   that persists a Goal with one adapter registry, reproduces the unknown-typeId
   crash on a registry without the adapter, and asserts the resilient open boots
   to a clean empty box.

## Acceptance

A profile with older-version data loads the app without an uncaught error — the
incompatible box is reset — and never shows a blank startup screen.

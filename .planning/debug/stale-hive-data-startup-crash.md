---
slug: stale-hive-data-startup-crash
status: resolved
resolution: .planning/quick/20260614-fix-stale-hive-data-startup-crash/SUMMARY.md
severity: high
created: 2026-06-14
surfaced_during: v1.3 milestone UAT (browser debug session)
component: app startup / Hive persistence
---

# Bug: stale Hive/IndexedDB data crashes app startup (blank screen)

## Symptom

On a browser that has **pre-existing Canopy data from an older app version**, the v1.3
web build opens all Hive boxes successfully, then throws an **Uncaught Error** during
startup and renders a **blank screen** (no onboarding, no Home). A fresh/incognito browser
(empty IndexedDB) loads normally.

Captured console (release build, user's Windows browser, feedback-drop 2026-06-14_14-45-30):

```
Got object store box in database goals.
Got object store box in database commitment_blocks.
Got object store box in database daily_schedules.
Got object store box in database scheduled_chunks.
Got object store box in database completion_logs.
Got object store box in database quarterly_snapshots.
Got object store box in database app_settings.
Uncaught Error                                   main.dart.js:6145
    at Object.hx (main.dart.js:4477:27)
    at Pu.fq (main.dart.js:49294:7)
    at aaz.jL (main.dart.js:111450:12)
    at HI.a3l (main.dart.js:111127:21)
    at tear_off.<anonymous> (main.dart.js:3872:65)
    at a0.d_ (main.dart.js:43799:23)
    at bU.v (main.dart.js:43780:16)
    at main.dart.js:111192:14
    at aQ3.a (main.dart.js:5050:63)
    at aQ3.$2 (main.dart.js:44820:14)
```

## Reproduction

1. In a browser, run an **older** Canopy web build and create data (goals/schedule) so
   IndexedDB is populated (the user dogfooded the web build on 2026-06-12).
2. Serve the current v1.3 release build and open it in that same browser (same origin).
3. Boxes open, then Uncaught Error → blank page.

Does NOT reproduce in incognito / fresh IndexedDB (confirmed: incognito works).
Does NOT reproduce in headless Linux Chromium with fresh storage (renders onboarding).

## Root cause hypothesis

The crash fires **after** all boxes open, during the first build / initial data read —
consistent with **reading old-schema persisted records** (a `goals`, `scheduled_chunks`,
`daily_schedules`, or `commitment_blocks` object whose shape/fields differ from the current
model) and throwing during deserialization or downstream processing, with no guard or
schema-version migration. The result is an uncaught error that blanks the whole app instead
of degrading gracefully.

Note: v1.3 itself did not add Hive fields (Phase 15 = engine logic, Phase 16 = tests,
Phase 17 = Home logic). The incompatible data is most likely from a **pre-v1.3** schema
(v1.1/v1.2-era records), so this is a general "old data on disk" robustness gap, not a
v1.3-specific migration miss — but it surfaced now.

## Fix direction (for /gsd-quick)

1. **Decode the exact throw:** rebuild with source maps
   (`/home/dan/development/flutter/bin/flutter build web --release --source-maps`) and map
   `main.dart.js:6145` / `:4477` to the Dart line. That pins which model/read throws.
2. **Make startup resilient to bad persisted data.** Options (pick per root cause):
   - Wrap per-record deserialization / box reads so a single corrupt/incompatible record
     is skipped or logged, not fatal.
   - Add a lightweight schema/version stamp in `app_settings`; on mismatch, migrate or
     clear the affected boxes and continue to a clean state (or onboarding).
   - Catch the startup error at the app root and show a recovery affordance ("reset local
     data") instead of a blank screen.
3. **Test:** seed a box with an old-shaped record in a widget/unit test and assert the app
   boots (onboarding or recovered state) without an uncaught error.

## Acceptance

A browser/profile holding older-version Canopy data loads the v1.3 app without an uncaught
error — either by migrating, skipping, or resetting the incompatible data — and never shows
a blank screen on startup.

## Workaround (for UAT now)

Use an incognito/private window (fresh IndexedDB), or DevTools → Application → Clear site
data, then hard-refresh.

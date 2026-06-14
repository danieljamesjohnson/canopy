---
created: 2026-06-14T14:54:18Z
title: Fix stale Hive data startup crash (blank screen on old IndexedDB)
area: database
files:
  - lib/main.dart
  - .planning/debug/stale-hive-data-startup-crash.md
---

## Problem

On a browser/profile that holds Canopy data from an **older app version**, the v1.3 web
build opens all 7 Hive boxes successfully and then throws an **Uncaught Error** during
startup → **blank screen** (no onboarding, no Home). Fresh/incognito storage works fine.

Captured in the user's browser console (release build, feedback-drop 2026-06-14_14-45-30):
all boxes open, then `Uncaught Error  main.dart.js:6145` (stack: `Object.hx` 4477:27 →
`Pu.fq` 49294:7 → … ). Does NOT repro in incognito or in headless Linux Chromium with
fresh storage. Surfaced during the v1.3 milestone UAT.

Likely a general "old persisted records on disk" robustness gap (pre-v1.3 schema), not a
v1.3-specific migration miss — v1.3 added no Hive fields.

Full investigation notes, exact stack, hypothesis, and acceptance criteria:
**`.planning/debug/stale-hive-data-startup-crash.md`**

## Solution

1. Rebuild with source maps (`flutter build web --release --source-maps`) and map
   `main.dart.js:6145` / `:4477` to the Dart line to pin which model read throws.
2. Make startup resilient: wrap per-record deserialization so one bad record is skipped/
   logged not fatal; OR add a schema version stamp in `app_settings` and migrate/clear on
   mismatch; OR catch at app root and offer a "reset local data" recovery instead of blank.
3. Test: seed a box with an old-shaped record and assert the app boots without an uncaught
   error.

Acceptance: a profile with older-version data loads v1.3 without an uncaught error (migrate,
skip, or reset) — never a blank startup screen.

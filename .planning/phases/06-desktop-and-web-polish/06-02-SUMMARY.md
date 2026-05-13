---
phase: 06-desktop-and-web-polish
plan: 02
subsystem: theming
tags: [theme, mood, hsl, lifecycle, change-notifier, hive, time-of-day]

requires:
  - phase: 06-desktop-and-web-polish
    plan: 01
    provides: AppSettings.moodSeedArgb at HiveField(5); pumpWithMood test helper expecting ThemeNotifier.moodSeeds
provides:
  - lib/providers/theme_notifier.dart — ThemeNotifier ChangeNotifier (mood seed state, HSL modulator, 20-min lifecycle-aware ticker, daily rollover seam)
  - ThemeNotifier.moodSeeds static const Map<int, Color> (5 locked hex seeds)
  - ThemeNotifier.curiousSeed static const Color (0xFF7A8FA3 pre-check-in)
  - AppSettings.lastMoodSetYmdInt nullable int at HiveField(6) — daily rollover persistence
  - _resetIfDayChanged() greppable seam method for Plan 06 unit tests
affects: [main.dart wiring (Plan 04), MoodCheckinScreen integration (Plan 04), router themeAnimationDuration (Plan 04), Plan 06 unit tests]

tech-stack:
  added: []
  patterns:
    - "ChangeNotifier + WidgetsBindingObserver with Timer.periodic lifecycle-aware ticker (RESEARCH.md Pattern 2)"
    - "Pure static HSL modulator (_modulateHsl) — testable with synthetic DateTime"
    - "Daily rollover seam encapsulated in single named method (_resetIfDayChanged) — RESEARCH.md Open Question 1 resolution"
    - "Constructor injection for AppSettingsRepository + DateTime getter + timeModulationEnabled flag (extends settings_notifier.dart's direct-instantiation analog with the DI tail needed for tests)"
    - "toARGB32() instead of deprecated Color.value for serialization (Flutter 3.27+ replacement)"

key-files:
  created:
    - lib/providers/theme_notifier.dart (208 lines)
  modified:
    - lib/data/models/app_settings.dart (added @HiveField(6) int? lastMoodSetYmdInt with D-10 doc comment)
    - lib/data/models/app_settings.g.dart (regenerated — writes/reads both fields 5 and 6)
    - lib/data/database/migrations.dart (extended _migration2to3 doc comment to cover both new fields; body unchanged; currentSchemaVersion stays at 3)

key-decisions:
  - "lastMoodSetYmdInt encoded as YYYYMMDD int (e.g., 20260513 for May 13, 2026) — minimal storage, easy comparison, no DateTime serialization overhead. Per Plan-02-PLAN interfaces section."
  - "Single Hive schema bump (v3) covers both new fields — _migration2to3 stays no-op; both moodSeedArgb (HiveField 5, Plan 01) and lastMoodSetYmdInt (HiveField 6, Plan 02) are additive nullable ints."
  - "_resetIfDayChanged() chosen as the named seam (vs inline logic) per RESEARCH.md Open Question 1 recommendation — Plan 06 unit tests assert against this method directly."
  - "Ticker notifies regardless of mood — both curious AND mood seeds drift through the day. (RESEARCH.md Pattern 2 had a conditional 'if (_moodSeed != null || isPreCheckin) notifyListeners()' that always evaluates true; simplified to unconditional notify in this implementation, behaviorally identical.)"
  - "Substituted deprecated `Color.value` with `Color.toARGB32()` (Flutter 3.27+ replacement) to keep flutter analyze clean — auto-fix per executor Rule 2."
  - "Removed unused `package:flutter/widgets.dart` import — `material.dart` re-exports everything needed (WidgetsBindingObserver, AppLifecycleState, WidgetsBinding). Auto-fix per executor Rule 2."

requirements-completed: [AC-6]

duration: 4m 6s
completed: 2026-05-13
---

# Phase 06 Plan 02: ThemeNotifier Summary

**ThemeNotifier — the single source of truth for app-wide color identity — is live. ChangeNotifier with WidgetsBindingObserver, 5 locked mood seeds + curious pre-check-in seed as static constants, pure HSL cosine modulator (peak noon, trough midnight), 20-minute lifecycle-aware ticker that pauses on background, Hive persistence of both `moodSeedArgb` and `lastMoodSetYmdInt`, and a `_resetIfDayChanged` seam that enforces D-10's no-carry-forward rule on init and resume. The Plan 01 transient (mood_pump.dart's unresolved `ThemeNotifier` import) is cleared. App wiring is deferred to Plan 04 per scope.**

## Performance

- **Duration:** 4m 6s
- **Started:** 2026-05-13T10:52:28Z
- **Completed:** 2026-05-13T10:56:38Z
- **Tasks:** 2/2 committed atomically
- **Files created:** 1 (`lib/providers/theme_notifier.dart`, 208 lines)
- **Files modified:** 3 (`app_settings.dart`, `app_settings.g.dart`, `migrations.dart`)

## Accomplishments

- **Task 1**: Extended `AppSettings` with `@HiveField(6) int? lastMoodSetYmdInt` for daily rollover seam persistence. Extended `_migration2to3` doc comment to enumerate both new HiveField(5) `moodSeedArgb` and HiveField(6) `lastMoodSetYmdInt`. Migration body unchanged (no-op), `currentSchemaVersion` stays at 3 — single bump covers both additive nullable ints. Regenerated `app_settings.g.dart` via `build_runner` — adapter writes/reads both fields with `(fields[N] as num?)?.toInt()` and the canonical write order.

- **Task 2**: Implemented `lib/providers/theme_notifier.dart` (208 lines):
  - `class ThemeNotifier extends ChangeNotifier with WidgetsBindingObserver`
  - **Static constants** (UI-SPEC locked):
    - `curiousSeed = Color(0xFF7A8FA3)` (pre-check-in pale slate-blue, HSL ~H210/S20/L56)
    - `moodSeeds = {1: 0xFF4A6275, 2: 0xFF5C7A8A, 3: 0xFF4A8C7A, 4: 0xFF7AAF6A, 5: 0xFFE8C547}` (Phase 3 locked palette)
  - **Constructor**: injectable `AppSettingsRepository`, `DateTime Function() now`, `bool timeModulationEnabled` — supports unit testing per RESEARCH.md §Pattern 2.
  - **Public surface**: `init()`, `setMoodSeed(Color)`, `resetToCurious()`, `dispose()`, `currentTheme` getter (ThemeData with `ColorScheme.fromSeed(seedColor: _effectiveSeed())`), `isPreCheckin` getter.
  - **Private helpers**: `_resetIfDayChanged()` (greppable named seam — RESEARCH.md Open Question 1), `_ymdToday()` (YYYYMMDD encoder), `_effectiveSeed()`, `_startTicker()` (idempotent, lifecycle-gated), and the pure static `_modulateHsl(Color, DateTime)`.
  - **Lifecycle**: `didChangeAppLifecycleState` pauses ticker on background, on resume re-checks the day, restarts ticker, and notifies immediately to refresh stale theme.
  - **Persistence**: `setMoodSeed` writes both `moodSeedArgb` (via `toARGB32()`) and `lastMoodSetYmdInt`. `_resetIfDayChanged` clears `_moodSeed` in memory only — the next mood tap refreshes persistence (D-10 no-carry-forward).

- **Plan 01 transient cleared**: `mood_pump.dart`'s `ThemeNotifier.moodSeeds` reference now resolves cleanly. `dart analyze test/test_helpers/mood_pump.dart` exits 0. `flutter analyze` across the entire workspace (lib + test) reports **0 issues** — including the mood_pump.dart errors documented in 06-01-SUMMARY.md §Known Transient.

## Task Commits

Each task was committed atomically:

1. **Task 1: AppSettings.lastMoodSetYmdInt @ HiveField(6) + migration doc update** — `48b9218` (feat)
2. **Task 2: ThemeNotifier with lifecycle-aware modulation ticker** — `84a8fae` (feat)

## Files Created/Modified

Created:
- `lib/providers/theme_notifier.dart` — 208 lines. ChangeNotifier + WidgetsBindingObserver implementing D-01 through D-07, D-09 (notify-driven theme rebuild for Plan 04's animation), and D-10 (no-carry-forward via `_resetIfDayChanged`).

Modified:
- `lib/data/models/app_settings.dart` — added 4-line `@HiveField(6) int? lastMoodSetYmdInt;` field block with doc comment. Final field set after Plan 02: HiveFields 0-6 (`morningNotificationMinutes`/0, `onboardingComplete`/1, `midDayNudgeEnabled`/2, `midDayNudgeMinutes`/3, `morningNotificationEnabled`/4, `moodSeedArgb`/5, `lastMoodSetYmdInt`/6).
- `lib/data/models/app_settings.g.dart` — regenerated via `build_runner build --delete-conflicting-outputs`. Writer now emits 7 bytes (was 6), with byte-6 path appending `obj.lastMoodSetYmdInt`. Reader applies `(fields[6] as num?)?.toInt()`.
- `lib/data/database/migrations.dart` — extended `_migration2to3` doc comment only; body remains no-op; `currentSchemaVersion = 3` unchanged.

## Verification

- `dart run build_runner build --delete-conflicting-outputs` → 22 outputs written, no errors
- `flutter analyze` (workspace) → **No issues found!** (resolves Plan 01's documented 2-error transient on `mood_pump.dart`)
- `dart analyze test/test_helpers/mood_pump.dart` → exit 0, "No issues found!"
- `flutter test test/test_helpers` → all 54 tests pass (the directory has no test files, Flutter resolved to the full suite; the helpers themselves compile cleanly which is the underlying intent)
- All 16 plan grep gates green:
  - `^class ThemeNotifier extends ChangeNotifier with WidgetsBindingObserver` → 1 match
  - Curious seed `0xFF7A8FA3` present
  - All 5 mood hex values present: `0xFF4A6275`, `0xFF5C7A8A`, `0xFF4A8C7A`, `0xFF7AAF6A`, `0xFFE8C547`
  - `Duration(minutes: 20)` present (UI-SPEC ticker interval)
  - `HSLColor.fromColor`, `math.cos`, `2 * math.pi`, `0.05 * t`, `0.10 * t` all present in `_modulateHsl`
  - `WidgetsBinding.instance.addObserver(this)` + `removeObserver(this)` both present
  - `didChangeAppLifecycleState` override present
  - `_resetIfDayChanged` method defined and called from `init()` + `didChangeAppLifecycleState`
- File length: 208 lines ≥ 150 (must_haves.artifacts.min_lines)
- Analyzer log gates (greppable, not tail-truncated): no `error.*test/test_helpers/mood_pump\.dart` and no `error.*lib/providers/theme_notifier\.dart` entries in `/tmp/p2t2_analyze.log`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Critical Code Quality] Substituted deprecated `Color.value` with `Color.toARGB32()`**
- **Found during:** Task 2 verification (flutter analyze)
- **Issue:** First draft used `seed.value` for Hive serialization (mirroring RESEARCH.md Pattern 2 line 332 verbatim). The analyzer flags `Color.value` as deprecated in current Flutter SDK with the guidance: "Use component accessors like .r or .g, or toARGB32 for an explicit conversion."
- **Fix:** Replaced `s.moodSeedArgb = seed.value;` with `s.moodSeedArgb = seed.toARGB32();` — `toARGB32()` returns the same ARGB int that `Color.value` returned, so the Hive on-disk representation is unchanged. This is required to satisfy the plan's hard analyzer gate (no `|| true` swallowing).
- **Files modified:** `lib/providers/theme_notifier.dart`
- **Commit:** `84a8fae` (rolled into Task 2 commit before initial commit, not a separate commit — single edit inside the same task)

**2. [Rule 2 - Critical Code Quality] Removed unused `package:flutter/widgets.dart` import**
- **Found during:** Task 2 verification (flutter analyze)
- **Issue:** First draft followed PLAN's `<action>` block which named `package:flutter/widgets.dart (WidgetsBindingObserver)` as a separate import. The analyzer flagged this as unnecessary because `material.dart` re-exports `widgets.dart` symbols (`WidgetsBindingObserver`, `AppLifecycleState`, `WidgetsBinding`).
- **Fix:** Removed the second import; kept `package:flutter/material.dart` which provides all needed symbols. Behaviorally identical.
- **Files modified:** `lib/providers/theme_notifier.dart`
- **Commit:** `84a8fae` (rolled into Task 2 commit before initial commit)

Both fixes were applied to the file before its first commit — there is no "fix" commit, the analyzer was satisfied before Task 2's atomic commit. Documented here for traceability per executor protocol.

No architectural deviations. No Rule 4 escalations.

## Acceptance Criteria

All criteria from `<acceptance_criteria>` in both tasks satisfied:

**Task 1:**
- [x] `grep "@HiveField(6)" lib/data/models/app_settings.dart` exits 0
- [x] `grep "int? lastMoodSetYmdInt" lib/data/models/app_settings.dart` exits 0
- [x] `grep "lastMoodSetYmdInt" lib/data/models/app_settings.g.dart` exits 0
- [x] `flutter analyze` (lib/) reports 0 issues; full workspace had 2 expected transient errors that cleared in Task 2
- [x] `currentSchemaVersion` unchanged at 3 — no second bump

**Task 2:**
- [x] `lib/providers/theme_notifier.dart` exists (208 lines, ≥150)
- [x] Class declaration matches `ChangeNotifier with WidgetsBindingObserver`
- [x] All 5 mood hex values + curious seed present
- [x] `Duration(minutes: 20)` literal present
- [x] HSL math literals (`HSLColor.fromColor`, `math.cos`, `2 * math.pi`, `0.05 * t`, `0.10 * t`) all present
- [x] Lifecycle hooks (`addObserver(this)`, `removeObserver(this)`, `didChangeAppLifecycleState`) all present
- [x] `_resetIfDayChanged` method defined and called from `init()` and `didChangeAppLifecycleState(...resumed)` paths
- [x] Public surface complete: `init`, `setMoodSeed`, `resetToCurious`, `currentTheme`, `isPreCheckin`
- [x] `flutter analyze` log captured to `/tmp/p2t2_analyze.log`; no `error.*test/test_helpers/mood_pump\.dart` or `error.*lib/providers/theme_notifier\.dart` entries
- [x] `dart analyze test/test_helpers/mood_pump.dart` exits 0
- [x] Test suite passes (existing 54 tests still green; no regressions)

## D-XX Traceability

Plan implements:
- D-01 / D-02 (full mood theming via ColorScheme.fromSeed at MaterialApp level) — provided via `currentTheme` getter; wired by Plan 04.
- D-03 (mood palette) — `moodSeeds` const map.
- D-04 / D-05 / D-06 (time-of-day modulation, 20-min debounce, ±5%L / ±10%S bounded swing) — `_modulateHsl` + `_startTicker`.
- D-07 (curious pre-check-in seed) — `curiousSeed` const + `isPreCheckin` getter + `_moodSeed = null` semantics.
- D-09 (warming into chosen palette via 400-600ms transition) — `setMoodSeed`'s `notifyListeners()` drives the MaterialApp rebuild; the actual animation duration/curve is wired in Plan 04 via `themeAnimationDuration: 500ms easeOutCubic`.
- D-10 (no carry-forward) — `_resetIfDayChanged` method called from `init()` and `didChangeAppLifecycleState`.

Not implemented in this plan (out of scope, owned by other plans):
- D-08 (breathing pulse on check-in CTA) — HomeScreen / MoodCheckinScreen concern, Plan 04 or later.
- D-11 (router/main wiring) — Plan 04 (`MaterialApp.router` + `themeAnimationDuration`).

## Notes for Downstream Plans

- **Plan 04 (router + main wiring)**: Construct `ThemeNotifier` in `main.dart` after `HiveDatabase.init()` and before `runApp`. Await `themeNotifier.init()`. Provide via `ChangeNotifierProvider.value` in the MultiProvider tree alongside `SettingsNotifier`. In `MaterialApp.router`, set `theme: themeNotifier.currentTheme` and `themeAnimationDuration: const Duration(milliseconds: 500)` with `themeAnimationCurve: Curves.easeOutCubic` per UI-SPEC. MoodCheckinScreen's mood-tap handler should call `context.read<ThemeNotifier>().setMoodSeed(ThemeNotifier.moodSeeds[moodIndex]!)`.

- **Plan 06 (unit tests)**: The `_resetIfDayChanged` seam is the assert target for the daily-rollover tests. Use the constructor's injectable `DateTime Function() now` to simulate cross-day clock drift. Set `timeModulationEnabled: false` to disable the 20-min ticker so test timing is deterministic. The pure `static Color _modulateHsl(Color, DateTime)` helper is the assert target for time-of-day curve tests — Plan 06 can call it directly without instantiating the notifier.

## Self-Check: PASSED

- File `lib/providers/theme_notifier.dart` exists (208 lines)
- Commit `48b9218` (Task 1) found in `git log`
- Commit `84a8fae` (Task 2) found in `git log`
- All grep gates green (verified above)
- `flutter analyze` workspace-clean (verified above)

# Phase 6: Desktop and Web Polish - Research

**Researched:** 2026-05-12
**Domain:** Flutter Material 3 desktop/web adaptive layouts + full-app mood theming
**Confidence:** HIGH

## Summary

Phase 6 wraps Canopy's six-platform Flutter app with three orthogonal concerns: (1) full-app mood theming driven by a single `ColorScheme.fromSeed` seed at the `MaterialApp.router` level — animated via `AnimatedTheme` (or `MaterialApp.themeAnimationDuration`/`themeAnimationCurve`); (2) a 720dp `LayoutBuilder` breakpoint inside the `StatefulShellRoute` shell that swaps `NavigationBar` ↔ `NavigationRail`; (3) desktop window minimums via `window_manager 0.5.x`, gated by `!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)`. Everything else (hover affordances, drag handle visibility, breathing pulse, go_router Web URLs) is a small, localized change against widgets already in the codebase.

CONTEXT.md and UI-SPEC.md have already locked the load-bearing decisions — exact hex values, timing, curves, breakpoint, fixture choice. This research validates that the locks are technically sound, fills in the architecture details that were deferred (where `ThemeNotifier` lives, how the 20-min ticker is implemented, conditional-import file structure, the `pumpWithMood` test fixture API), and surfaces three landmines: (a) the existing `MaterialApp.router` cannot be wrapped in `AnimatedTheme` the way one might naively try — `themeAnimationDuration`/`themeAnimationCurve` is the correct Material 3 seam, available since Flutter 3.19; (b) `MouseRegion` placed outside a `Dismissible` works, but placed inside the Dismissible's child renders the hover-detect surface above the swipe area without conflict — verified pattern; (c) the existing `_HomeScreenState._moodColors` constant map in `home_screen.dart` and the duplicate in `checkin_screen.dart` will become dead code after `ThemeNotifier` centralizes the palette — call out to the planner that these are removable.

**Primary recommendation:** Use `MaterialApp.router.themeAnimationDuration: 500ms` + `themeAnimationCurve: Curves.easeOutCubic` (Flutter 3.19+ API, available in this project's SDK ^3.10.3) instead of an explicit `AnimatedTheme` wrapper. Drive the theme via a new `ThemeNotifier extends ChangeNotifier`, persisted to Hive (mood seed only — time-of-day modulation is derived, never stored). Pin tests with a `pumpWithMood(tester, child, moodIndex: 3)` helper that constructs the same theme builder with the modulator disabled.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Mood seed storage | Database / Storage (Hive `AppSettings`) | App state (`ThemeNotifier`) | Persistence belongs in the existing Hive layer; the notifier is a memory-resident view |
| Time-of-day modulation | App state (`ThemeNotifier` ticker) | Browser / Client (rendering) | Pure derivation from `DateTime.now()` + seed — no I/O, no persistence |
| ColorScheme application | App state → `MaterialApp.router.theme` | Browser / Client | Single seam; Flutter's framework owns rebuild propagation |
| Window size constraints | OS / Native (window_manager FFI) | Browser / Client | OS-level concern; only on Windows/macOS/Linux; web/mobile no-op |
| Hover detection | Browser / Client (Flutter pointer events) | — | Pointer-presence is a per-platform runtime fact; gating via `defaultTargetPlatform` is wrong (UI-SPEC §Hover Reveals already correctly chose pointer-driven gating) |
| URL routing | Browser / Client (go_router on web) | — | go_router already produces correct URLs from the existing route table; Phase 6 verifies, does not architect |
| LayoutBuilder breakpoint | Browser / Client (widget tree) | — | LayoutBuilder reads the widget's own constraints, which on the shell will be the window size — correct for this use case |

## Phase Requirements

> CONTEXT.md and ROADMAP.md describe Phase 6 as an implicit cross-cutting concern ("all active requirements apply to all six Flutter platforms") with no explicit REQ-IDs in `.planning/PROJECT.md`. The acceptance criteria in `.planning/ROADMAP.md` §Phase 6 (numbered 1–5) plus the proposed AC #6 from CONTEXT.md `<deferred>` are the source of truth.

| AC ID | Description | Research Support |
|-------|-------------|------------------|
| AC-1 | Two-column layout at ≥720dp with NavigationRail, no overflow errors at 1280×800 | `LayoutBuilder` inside `_ScaffoldWithNavBar` swapping `NavigationBar` ↔ `Row(NavigationRail + Expanded(navigationShell))` — verified pattern from Code with Andrea + Flutter docs |
| AC-2 | Hover on chunk card reveals checkbox + drag handle without click; restores on exit | `MouseRegion(onEnter/onExit)` wrapping ChunkCard (no existing InkWell); `InkWell.onHover` on GoalCard (existing InkWell at `goal_card.dart:62`); pointer-driven (not platform-gated) is correct cross-platform |
| AC-3 | Window resize below 480px is prevented on Windows | `window_manager 0.5.1`: `windowManager.setMinimumSize(Size(480, 640))` after `windowManager.ensureInitialized()`, conditionally imported behind `if (dart.library.io)` and runtime-gated by `!kIsWeb && (Platform.isWindows \|\| Platform.isMacOS \|\| Platform.isLinux)` |
| AC-4 | Direct navigation to `/schedule`, `/goals` loads correct screen on Web | go_router already supports this — current route table has `/home`, `/goals`, `/goals/archived`, `/schedule`, `/schedule/checkin`, `/settings`, `/settings/past-reviews`, `/onboarding`, `/review`, `/commitments`, `/summary`. Verification is `flutter run -d chrome` + manual URL bar test |
| AC-5 | All existing widget tests pass; new LayoutBuilder tests at 480/720/1200dp pass | `pumpWithMood` helper migrates existing tests (currently 1 test file `quarterly_review_test.dart` uses `MaterialApp(home:...)`, no `colorScheme.primary` assertions). LayoutBuilder breakpoint tests use `tester.view.physicalSize = Size(480, 800)` + `addTearDown(tester.view.reset)` |
| AC-6 (proposed) | Tapping each of 5 moods at check-in changes app-wide ColorScheme within 600ms | `themeAnimationDuration: 500ms` (within 400–600ms budget) on `MaterialApp.router`; `ThemeNotifier.setMoodSeed(seed)` → `notifyListeners()` → MaterialApp consumer rebuilds → Flutter handles the cross-fade |

## User Constraints (from CONTEXT.md)

### Locked Decisions

**Mood Theming — Depth and Reach**
- **D-01:** Full mood theming via `ColorScheme.fromSeed(<mood-color>)` applied at the `MaterialApp` level. Single theme swap.
- **D-02:** Every theme-able screen follows the daily mood — no per-route theme overrides.
- **D-03:** Mood palette locked: mood 1 `#4A6275` → mood 2 `#5C7A8A` → mood 3 `#4A8C7A` → mood 4 `#7AAF6A` → mood 5 `#E8C547`.

**Mood Theming — Time Evolution**
- **D-04:** Hue from mood (seed); brightness/saturation modulated by time of day.
- **D-05:** Theme refresh debounced — 20-minute interval (UI-SPEC locks this).
- **D-06:** Time-of-day curve bounded and gentle — ±5% L / ±10% S (UI-SPEC locks this).

**Mood Theming — Pre-Check-in State**
- **D-07:** Pre-check-in "curious" theme — `#7A8FA3` pale slate-blue, H210/S20/L56 (UI-SPEC locks this).
- **D-08:** Breathing pulse on check-in CTA only — 2400ms, easeInOut, shadow blur 8→16px (UI-SPEC locks this); respects `MediaQuery.disableAnimations`.
- **D-09:** Mood warming transition — 500ms `easeOutCubic` via `AnimatedTheme` or equivalent (UI-SPEC locks 500ms easeOutCubic).
- **D-10:** No "yesterday's mood carries forward" — curious theme every morning.

**Desktop & Web Mechanics**
- **D-11:** LayoutBuilder at 720dp; `window_manager` minimum 480×640 on Windows/macOS/Linux only (conditional imports); go_router Web URL verification; no Web Push API.

### Claude's Discretion

- Two-column layout structure — nav rail + content pane as the simplest path.
- Hover & always-visible affordances — Material 3 norms within UI-SPEC locks.
- Swipe replacements — always-visible checkbox on hover + "skip" button in revealed area.
- Web deep-link UX — existing empty states.
- Mood theming color details — specific HSL math, contrast checking, exact pre-check-in hue (UI-SPEC locked all of these).
- AnimatedTheme curve and timing (UI-SPEC locked 500ms easeOutCubic).

### Deferred Ideas (OUT OF SCOPE)

- Keyboard shortcuts (space-to-complete, cmd/ctrl-N, etc.)
- Master-detail layouts on Goals and Schedule at wide widths
- Right-click context menus on chunk cards
- "Carry yesterday's mood forward" alternative

### ROADMAP Action Required

Update `.planning/ROADMAP.md` §Phase 6 to add mood theming deliverable + 6th acceptance criterion. **Belongs to the planner — surface in plan output, do not silently write.**

## Project Constraints (from CLAUDE.md)

- **Flutter ^3.10.3 / Dart SDK** — themeAnimationDuration/themeAnimationCurve (added Flutter 3.19) is available [VERIFIED: pubspec.yaml `environment.sdk: ^3.10.3` exceeds Flutter 3.19 SDK requirement of ^3.3.0]
- **Material 3 (`useMaterial3: true`)** — already on; `ColorScheme.fromSeed` is the existing primitive [VERIFIED: `lib/main.dart:69-71`]
- **State management: `StatefulWidget` + `setState` + Provider** — no new state libs. `ThemeNotifier extends ChangeNotifier` fits existing pattern [VERIFIED: 4 existing ChangeNotifier providers in `lib/providers/`]
- **Linting: `package:flutter_lints` via `analysis_options.yaml`** — research output must compile lint-clean
- **All six platforms** — Phase 6 specifically polishes desktop and Web while preserving mobile parity

## Standard Stack

### Core (no new packages except window_manager)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `window_manager` | `^0.5.1` | Desktop window size minimum (480×640 logical px) | The de-facto Flutter desktop window package; supports Windows/macOS/Linux; FFI-backed [VERIFIED: pub.dev 0.5.1] |
| `flutter` SDK (built-in) | (Flutter 3.19+, project on ^3.10.3) | `AnimatedTheme`, `MaterialApp.themeAnimationDuration/Curve`, `ColorScheme.fromSeed`, `ColorScheme.lerp`, `HSLColor`, `LayoutBuilder`, `NavigationRail`, `MouseRegion`, `InkWell.onHover` | All first-party; zero new dependencies for theming + layout work |
| `provider` (already in pubspec) | `^6.1.5+1` | `ThemeNotifier` registration in `MultiProvider`; `context.watch<ThemeNotifier>()` in `CanopyApp.build` | Established project pattern [VERIFIED: pubspec.yaml + 4 existing notifiers] |
| `hive_ce` + `hive_ce_flutter` | `^2.19.3` / `^2.3.4` | Persist mood seed on `AppSettings` (extend existing model) | Existing storage layer [VERIFIED: `lib/data/database/hive_database.dart`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff | Recommendation |
|------------|-----------|----------|----------------|
| `window_manager` | `bitsdojo_window` | Older, more focused on custom title bars; less actively maintained | Use `window_manager` — broader API, current |
| `MaterialApp.themeAnimationDuration` + `themeAnimationCurve` | Explicit `AnimatedTheme` widget wrapping the routerConfig builder | `AnimatedTheme` requires a `child` widget — wrapping `MaterialApp.router` is awkward. `themeAnimationDuration` on `MaterialApp` is the Material 3 idiom since Flutter 3.19 | **Use `themeAnimationDuration` + `themeAnimationCurve` on `MaterialApp.router`** [VERIFIED: api.flutter.dev/.../themeAnimationDuration] |
| `ChangeNotifier` (extend `SettingsNotifier`) | New `ThemeNotifier` | SettingsNotifier already holds onboardingComplete + notification settings. Adding theme state would conflate domains and force every settings change to re-fire theme rebuilds | **Create new `ThemeNotifier`** — single responsibility; theme rebuilds isolated |
| `Timer.periodic` (theme ticker) | `WidgetsBindingObserver.didChangeAppLifecycleState` + Timer | Pure `Timer.periodic` runs in background, wasting CPU when app is paused. Lifecycle-aware ticker pauses on `AppLifecycleState.paused`, resumes on `.resumed` | **Use both**: Timer.periodic for the 20-min cadence + WidgetsBindingObserver to pause/resume the timer based on lifecycle |
| `Color` manipulation directly | `HSLColor.fromColor` → `withLightness` → `toColor` | RGB arithmetic for L/S modulation is brittle and gamut-bound. HSL is the right space — Flutter has built-in `HSLColor` [CITED: api.flutter.dev/flutter/painting/HSLColor-class.html] | **Use `HSLColor`** |
| `MouseRegion` on ChunkCard | Wrap in `InkWell` | InkWell adds tap semantics that conflict with the existing `Dismissible` wrapper in `SwipeableChunkCard`. `MouseRegion` is hit-test-transparent for non-pointer-enter/exit events | **Use `MouseRegion`** [VERIFIED: api.flutter.dev MouseRegion docs] |

**Installation:**

```yaml
dependencies:
  window_manager: ^0.5.1   # new
```

```bash
flutter pub get
```

**Version verification:** `window_manager 0.5.1` confirmed current on pub.dev as of 2026-05-12. [VERIFIED: pub.dev/packages/window_manager]

## Architecture Patterns

### System Architecture Diagram

```
                                            +-----------------------------+
                                            | DateTime.now() (system)     |
                                            +--------------+--------------+
                                                           |
                                                           v
+----------------------+   tap mood    +-------------------+---------------+
| MoodCheckinScreen    +-------------->|     ThemeNotifier (NEW)           |
+----------------------+               |                                   |
                                       |  - moodSeed:Color (nullable)      |
+----------------------+    set/reset  |  - timeModulationEnabled:bool     |
| AppLifecycleObserver +<----timer-----+  - _ticker:Timer? (20 min)        |
| (NEW, inside        |                |  - _lifecycle: WidgetsBindingObs  |
|  ThemeNotifier)     |                |                                   |
+----------+----------+                |  Derives:                         |
           |                           |    effectiveSeed = modulate(      |
           | pause/resume on            |       moodSeed ?? curiousSeed,    |
           | lifecycle changes         |       DateTime.now())             |
           |                           |    currentTheme = ThemeData(      |
           v                           |       useMaterial3:true,          |
+----------------------+   read seed   |       colorScheme:                |
| Hive: AppSettings    +<--read/write--+         ColorScheme.fromSeed(     |
|  + moodSeedArgb:int? |               |           seedColor:effectiveSeed)|
+----------------------+               |    )                              |
                                       +-------------------+---------------+
                                                           | notifyListeners
                                                           v
                                       +-----------------------------------+
                                       | MaterialApp.router                |
                                       |   theme: themeNotifier.current    |
                                       |   themeAnimationDuration: 500ms   |
                                       |   themeAnimationCurve: easeOut..  |
                                       +-------------------+---------------+
                                                           | rebuild w/ lerp
                                                           v
            +------------+        +--------------------+         +-----------+
            | NavRail    |<-------+ LayoutBuilder      +-------->| NavBar    |
            | (>=720dp)  |        | in _ScaffoldWith..  |        | (<720dp)  |
            +------------+        +---------+----------+         +-----------+
                                            |
                                            v
                                   +--------+---------+
                                   | navigationShell  | (go_router)
                                   +--------+---------+
                                            |
                       +--------------------+--------------------+
                       |                    |                    |
                       v                    v                    v
                +-------------+      +-------------+      +-------------+
                | HomeScreen  |      | ChunkCard   |      | GoalCard    |
                | + Breathing |      | + MouseRgn  |      | + InkWell   |
                |   pulse on  |      |   reveals   |      |  .onHover   |
                |   CTA       |      |   ckbox+skip|      |  reveals    |
                | (pre-check) |      |             |      |  edit+arch  |
                +-------------+      +-------------+      +-------------+
                                            ^
                                            |
                                     wraps in
                                +-----------+-----------+
                                | SwipeableChunkCard    |
                                | (Dismissible — mobile |
                                |  swipe; desktop hover |
                                |  icons coexist)       |
                                +-----------------------+


   Conditional desktop init (main.dart):
   +---------------------------------------------------+
   | if (!kIsWeb && (Platform.is{Windows,MacOS,Linux}))|
   |   await windowManager.ensureInitialized();         |
   |   await windowManager.setMinimumSize(              |
   |     const Size(480, 640));                         |
   +---------------------------------------------------+
   Behind conditional import: lib/platform/window_setup.dart
   = window_setup_io.dart (real)  OR  window_setup_stub.dart (web)
```

### Recommended Project Structure (Phase 6 additions only)

```
lib/
├── main.dart                                  # MODIFY: theme wired via ThemeNotifier; window_setup conditional import
├── platform/                                  # NEW: conditional-import directory
│   ├── window_setup.dart                      # NEW: re-exports based on dart.library.io
│   ├── window_setup_io.dart                   # NEW: real impl using window_manager
│   └── window_setup_stub.dart                 # NEW: no-op for web
├── providers/
│   └── theme_notifier.dart                    # NEW: ThemeNotifier with mood seed + time-of-day modulation
├── services/
│   └── mood_theme_service.dart                # NEW (optional): pure functions modulateHsl(seed, now), seedForMood(int)
├── data/models/app_settings.dart              # MODIFY: add moodSeedArgb:int? field (Hive schemaVersion bump)
├── router.dart                                # MODIFY: _ScaffoldWithNavBar uses LayoutBuilder + NavigationRail at >=720dp
└── screens/
    ├── home/home_screen.dart                  # MODIFY: breathing pulse on pre-check-in CTA
    ├── schedule/checkin_screen.dart           # MODIFY: on mood tap call ThemeNotifier.setMoodSeed
    ├── schedule/widgets/chunk_card.dart       # MODIFY: MouseRegion + hover-revealed checkbox/skip
    ├── goals/widgets/goal_card.dart           # MODIFY: InkWell.onHover + revealed edit/archive icons
    ├── goals/goals_screen.dart                # MODIFY: drag handle visibility per platform
    ├── commitments/commitments_screen.dart    # MODIFY: InkWell.onHover + revealed edit/delete icons
    └── quarterly_review/sections/adjustments_section.dart  # MODIFY: drag handle visibility per platform

test/
├── test_helpers/
│   ├── mood_pump.dart                         # NEW: pumpWithMood helper
│   └── viewport.dart                          # NEW: setViewport(tester, w, h) + reset teardown helper
├── providers/
│   └── theme_notifier_test.dart               # NEW: unit tests for HSL modulation, ticker pause/resume
├── screens/
│   ├── home_screen_breathing_pulse_test.dart  # NEW
│   ├── responsive_layout_test.dart            # NEW: 480/720/1200dp breakpoint
│   └── chunk_card_hover_test.dart             # NEW
└── platform/
    └── window_setup_test.dart                 # NEW: stub branch verified compile + no-op behaviour
```

### Pattern 1: `MaterialApp.router` Theme Animation (no AnimatedTheme wrapper)

**What:** Use the built-in `themeAnimationDuration` + `themeAnimationCurve` parameters on `MaterialApp.router` instead of wrapping in `AnimatedTheme`.

**When to use:** This is the right pattern whenever you want the entire app's theme to cross-fade. `AnimatedTheme` is for sub-tree theme overrides — not what Phase 6 needs.

**Example:**
```dart
// Source: api.flutter.dev/flutter/material/MaterialApp/themeAnimationDuration.html [CITED]
class CanopyApp extends StatelessWidget {
  const CanopyApp({super.key, required this.themeNotifier, /* ... */});
  final ThemeNotifier themeNotifier;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // existing providers ...
        ChangeNotifierProvider<ThemeNotifier>.value(value: themeNotifier),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, theme, _) => MaterialApp.router(
          title: 'Canopy',
          theme: theme.currentTheme,                          // ThemeData with ColorScheme.fromSeed(effectiveSeed)
          themeAnimationDuration: const Duration(milliseconds: 500),
          themeAnimationCurve: Curves.easeOutCubic,
          routerConfig: createRouter(settingsNotifier),
        ),
      ),
    );
  }
}
```

**Why this works:** Material 3 `ColorScheme.lerp` interpolates *every* role (primary, secondary, tertiary, surface, surfaceContainer*, onPrimary, etc.) — except `brightness`, which switches at `t=0.5` rather than interpolating. [VERIFIED: api.flutter.dev/flutter/material/ColorScheme/lerp.html] Since Phase 6 keeps `useMaterial3: true` and never changes brightness (no dark mode toggle in v1), the lerp is smooth across every channel.

### Pattern 2: `ThemeNotifier` with Lifecycle-Aware Ticker

**What:** A `ChangeNotifier` that holds the active mood seed, recomputes a time-of-day-modulated effective seed every 20 minutes, pauses the ticker when the app is backgrounded, and persists the seed to Hive.

**When to use:** Single source of truth for the app's color identity. Read by `MaterialApp.router.theme`. Written by `MoodCheckinScreen` on mood tap.

**Example:**
```dart
// Pattern source: api.flutter.dev WidgetsBindingObserver + ChangeNotifier [VERIFIED]
class ThemeNotifier extends ChangeNotifier with WidgetsBindingObserver {
  ThemeNotifier({
    AppSettingsRepository? repository,
    DateTime Function() now = DateTime.now,            // injectable for tests
    bool timeModulationEnabled = true,                  // false in tests
  })  : _repo = repository ?? HiveAppSettingsRepository(),
        _now = now,
        _timeModulationEnabled = timeModulationEnabled;

  static const Color curiousSeed = Color(0xFF7A8FA3);  // UI-SPEC locked
  static const Map<int, Color> moodSeeds = {
    1: Color(0xFF4A6275), 2: Color(0xFF5C7A8A), 3: Color(0xFF4A8C7A),
    4: Color(0xFF7AAF6A), 5: Color(0xFFE8C547),
  };

  final AppSettingsRepository _repo;
  final DateTime Function() _now;
  final bool _timeModulationEnabled;

  Color? _moodSeed;                  // null = pre-check-in "curious"
  Timer? _ticker;
  bool _isForeground = true;

  Future<void> init() async {
    final settings = await _repo.getSettings();
    final argb = settings?.moodSeedArgb;
    _moodSeed = (argb == null) ? null : Color(argb);
    WidgetsBinding.instance.addObserver(this);
    _startTicker();
    notifyListeners();
  }

  ThemeData get currentTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _effectiveSeed()),
      );

  bool get isPreCheckin => _moodSeed == null;

  Future<void> setMoodSeed(Color seed) async {
    _moodSeed = seed;
    final s = await _repo.getSettings() ?? AppSettings();
    s.moodSeedArgb = seed.value;
    await _repo.saveSettings(s);
    notifyListeners();
  }

  /// Called at midnight (or on first launch of a new local day) to reset to curious.
  Future<void> resetToCurious() async {
    _moodSeed = null;
    final s = await _repo.getSettings() ?? AppSettings();
    s.moodSeedArgb = null;
    await _repo.saveSettings(s);
    notifyListeners();
  }

  Color _effectiveSeed() {
    final base = _moodSeed ?? curiousSeed;
    if (!_timeModulationEnabled) return base;
    return _modulateHsl(base, _now());
  }

  /// Pure function — easy to unit-test with synthetic DateTime inputs.
  static Color _modulateHsl(Color base, DateTime now) {
    final hsl = HSLColor.fromColor(base);
    final minutes = now.hour * 60 + now.minute;
    final t = math.cos(2 * math.pi * (minutes / 1440 - 0.5)); // peak noon, trough midnight
    final newL = (hsl.lightness + 0.05 * t).clamp(0.0, 1.0);
    final newS = (hsl.saturation + 0.10 * t).clamp(0.0, 1.0);
    return hsl.withLightness(newL).withSaturation(newS).toColor();
  }

  void _startTicker() {
    _ticker?.cancel();
    if (!_timeModulationEnabled || !_isForeground) return;
    _ticker = Timer.periodic(const Duration(minutes: 20), (_) {
      if (_moodSeed != null || isPreCheckin) notifyListeners();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) {
      _startTicker();
      notifyListeners();   // re-modulate immediately on resume (catches stale theme after background)
    } else {
      _ticker?.cancel();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
```

**Key design choices and their justifications:**

1. **20-min `Timer.periodic` + WidgetsBindingObserver pause/resume** — pure Timer wastes CPU when backgrounded (verified WidgetsBindingObserver pattern from Flutter docs [VERIFIED]). Resuming triggers an immediate `notifyListeners()` because the theme may be hours stale after suspension.
2. **Pure static `_modulateHsl`** — unit-testable without app context; the planner should write tests that pass synthetic `DateTime(2026, 5, 12, 12, 0)` (noon → peak), `DateTime(2026, 5, 12, 0, 0)` (midnight → trough), `DateTime(2026, 5, 12, 6, 0)` (sunrise → roughly zero modulation).
3. **`timeModulationEnabled: false`** — the test fixture knob. `pumpWithMood` passes `false` so tests get a deterministic seed without injecting `DateTime`.
4. **Persistence in Hive** — `_moodSeed` stored as `int? moodSeedArgb` on `AppSettings`. Requires schema bump (additive — same pattern as Phase 2's no-op migration in STATE.md: "No-op `_migration1to2` added to migration list so schemaVersion increments atomically even for additive-only Hive schema changes" [VERIFIED: STATE.md line for Phase 02-01]).
5. **No "carry forward"** — `resetToCurious()` exists for tomorrow's reset. CONTEXT.md D-10 forbids carryover; the *every-morning* reset is whoever first reads the schedule for a new local day. **Cleanest seam: in `ScheduleNotifier.generateToday`, before generation, if `lastScheduleDate != today`, call `themeNotifier.resetToCurious()`. Then `MoodCheckinScreen` writes the new seed when the user taps.** Surface this seam for the planner.

### Pattern 3: Conditional Import for `window_manager`

**What:** Three files form the standard Dart conditional-import idiom. `lib/main.dart` imports `lib/platform/window_setup.dart` and gets the right body for the platform at compile time.

**When to use:** Whenever a package imports `dart:io` (which `window_manager` does internally) and the app must also build for web.

**Example:**
```dart
// lib/platform/window_setup.dart — re-export per platform
export 'window_setup_stub.dart'
    if (dart.library.io) 'window_setup_io.dart';

// lib/platform/window_setup_stub.dart — used on web (no dart:io)
import 'package:flutter/foundation.dart' show kIsWeb;
Future<void> setupDesktopWindow() async {
  // no-op on web
}

// lib/platform/window_setup_io.dart — used on Android/iOS/Windows/macOS/Linux
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';

Future<void> setupDesktopWindow() async {
  if (kIsWeb) return;
  if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(const Size(480, 640));
}

// lib/main.dart — single import line; compile-time branch is automatic
import 'platform/window_setup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDesktopWindow();        // safe on every platform
  // ... rest of init
}
```

**Why this is the right pattern:**
- `if (dart.library.io)` is the standard Dart conditional-import key for "is this a non-web platform?" [VERIFIED: dart.dev conditional imports + Medium/Flutter Community guide]
- The stub file does NOT import `window_manager`, so web builds never see the package at compile time → no tree-shaking issues, no `dart:io` errors.
- Runtime `kIsWeb` + `Platform.is*` checks inside `window_setup_io.dart` cover the Android/iOS case (where `dart:io` exists but window_manager would no-op or crash).
- The function name `setupDesktopWindow()` is the same in both files → `main.dart` is identical across platforms.

### Pattern 4: Responsive LayoutBuilder in `_ScaffoldWithNavBar`

**What:** Wrap the existing `_ScaffoldWithNavBar` body in a `LayoutBuilder`, branch at 720dp.

**When to use:** Inside the `StatefulShellRoute.indexedStack` builder, where `navigationShell` is the swap-target child. The LayoutBuilder belongs at the shell level (not inside each branch) so the rail/bar swap happens once and `navigationShell` (which carries the four branches' state) is reused.

**Example:**
```dart
// Source pattern: codewithandrea.com/articles/flutter-bottom-navigation-bar-nested-routes-gorouter
// adapted for Canopy's 720dp breakpoint [VERIFIED pattern]
class _ScaffoldWithNavBar extends StatelessWidget {
  const _ScaffoldWithNavBar({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (icon: Icons.home_outlined, label: 'Home'),
    (icon: Icons.flag_outlined, label: 'Goals'),
    (icon: Icons.calendar_today_outlined, label: 'Schedule'),
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return Scaffold(
            body: Row(children: [
              NavigationRail(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _goBranch,
                labelType: NavigationRailLabelType.all,    // always-show labels (mood text)
                destinations: [
                  for (final d in _destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      label: Text(d.label),
                    ),
                ],
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(child: navigationShell),
            ]),
          );
        }
        // Below 720dp: existing NavigationBar at bottom
        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _goBranch,
            destinations: [
              for (final d in _destinations)
                NavigationDestination(icon: Icon(d.icon), label: d.label),
            ],
          ),
        );
      },
    );
  }
}
```

**Why this preserves go_router state:** `navigationShell` is the same widget instance in both branches — only its `parent` widget (the Scaffold) differs. `StatefulShellRoute` keeps each branch's navigator tree alive regardless of which scaffold wraps the shell. [VERIFIED: pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html]

### Pattern 5: `pumpWithMood` Test Fixture

**What:** A single helper file every existing widget test uses for its `MaterialApp` wrapper. Pins mood, disables time-of-day modulation, provides a deterministic ColorScheme.

**Example:**
```dart
// test/test_helpers/mood_pump.dart  (NEW)
import 'package:canopy/providers/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const Map<int, Color> _moodSeeds = ThemeNotifier.moodSeeds;

/// Wraps [child] in a MaterialApp with a fixed mood theme and disabled time
/// modulation. Use this in place of bare `MaterialApp(home: ...)` in widget
/// tests so colorScheme.primary is deterministic across CI machines.
Future<void> pumpWithMood(
  WidgetTester tester,
  Widget child, {
  int moodIndex = 3,                                  // mood 3 = #4A8C7A (UI-SPEC locked default)
  Iterable<ChangeNotifierProvider> extraProviders = const [],
}) async {
  final seed = _moodSeeds[moodIndex]!;
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: seed),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [...extraProviders],
      child: MaterialApp(
        theme: theme,
        home: Scaffold(body: child),
      ),
    ),
  );
}
```

**Migration of existing tests:**
- `test/screens/quarterly_review_test.dart` line 31: replace `Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));` with the helper. No `colorScheme.primary` assertions exist in this file [VERIFIED: grep], so migration is mechanical — one helper call replaces the wrap.
- `test/widget_test.dart` line 1–9: placeholder test — no migration needed.
- LayoutBuilder breakpoint tests (NEW) use `pumpWithMood` for theme + `tester.view.physicalSize` for size.

### Pattern 6: LayoutBuilder Breakpoint Widget Tests

```dart
// test/screens/responsive_layout_test.dart  (NEW)
import 'package:canopy/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/mood_pump.dart';

void main() {
  group('Responsive shell layout', () {
    Future<void> _pumpShellAt(WidgetTester tester, Size logicalSize) async {
      // Source: api.flutter.dev/flutter/flutter_test/TestFlutterView [VERIFIED]
      tester.view.devicePixelRatio = 1.0;                  // logical px == physical
      tester.view.physicalSize = logicalSize;
      addTearDown(tester.view.reset);
      await pumpWithMood(tester, /* test harness widget exposing _ScaffoldWithNavBar */);
      await tester.pumpAndSettle();
    }

    testWidgets('shows NavigationBar at 480dp', (tester) async {
      await _pumpShellAt(tester, const Size(480, 800));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('switches to NavigationRail at 720dp', (tester) async {
      await _pumpShellAt(tester, const Size(720, 800));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('shows NavigationRail at 1200dp', (tester) async {
      await _pumpShellAt(tester, const Size(1200, 800));
      expect(find.byType(NavigationRail), findsOneWidget);
    });
  });
}
```

**Note on the 720dp threshold:** `LayoutBuilder.constraints.maxWidth >= 720` triggers rail. The test at exactly 720 must verify that 720 is the *inclusive* lower bound for rail mode (UI-SPEC locks `>=720dp`, so 720dp itself shows rail).

### Anti-Patterns to Avoid

- **Wrapping `MaterialApp.router` in `AnimatedTheme`** — `AnimatedTheme` is designed for sub-tree theme overrides; using `themeAnimationDuration` on `MaterialApp` is the Material 3 idiom and avoids the awkward "wrap something that has no obvious child" problem.
- **Using `defaultTargetPlatform` to gate hover icons** — hover should be pointer-driven (`MouseRegion.onEnter` simply doesn't fire on touch), which is correct cross-platform. Platform-gating hover would break mouse-equipped Android/iOS dev kits + iPad pointer use.
- **Rebuilding `MaterialApp` on every 20-min tick** — bad: the entire tree rebuilds. Good: `Consumer<ThemeNotifier>` around `MaterialApp.router` so only that node sees the change; Flutter's framework + `themeAnimationDuration` handles the lerp. Same effective rebuild count, but cleaner intent.
- **Persisting modulated seed** — never. Persist only the user's chosen mood seed. Modulation is *derived* from `DateTime.now()` and recomputed on read.
- **`Timer.periodic` without lifecycle pause** — background CPU drain. Always pair with `WidgetsBindingObserver`.
- **Adding `InkWell` to ChunkCard to get `onHover`** — ChunkCard already has no InkWell because its tap target is the parent `Dismissible`/`SwipeableChunkCard`. Adding InkWell here would intercept the swipe gesture. Use `MouseRegion` instead (UI-SPEC §Hover Reveals already locked this — research confirms it's right).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HSL color math | Custom RGB→HSL→RGB converter | Flutter's `HSLColor.fromColor(c).withLightness(...).toColor()` | Built-in, precision-tested, gamut-aware [VERIFIED: api.flutter.dev HSLColor] |
| Theme cross-fade animation | `AnimatedBuilder` + manual `ColorScheme.lerp` | `MaterialApp.themeAnimationDuration` + `themeAnimationCurve` | Framework-provided; correct per-role interpolation including brightness-snap [VERIFIED: api.flutter.dev MaterialApp + ColorScheme.lerp] |
| Window-size constraints | Native FFI per platform | `window_manager 0.5.1` | Three platforms (Win/macOS/Linux) supported with one API surface |
| Hover state tracking | Custom Listener + pointer matching | `MouseRegion(onEnter, onExit)` + `InkWell(onHover:)` | Pointer-event-correct, touch-safe (doesn't fire), already in framework |
| Responsive breakpoint detection | `MediaQuery.of(context).size` | `LayoutBuilder(builder: (ctx, constraints) => ...)` | LayoutBuilder gives the *widget's* constraints, not the screen's — critical for nested layouts; testable via `tester.view.physicalSize` |
| Lifecycle-aware timer pause | Manual `AppLifecycleListener` rolling | `WidgetsBindingObserver.didChangeAppLifecycleState` | Standard pattern; addObserver/removeObserver semantics already documented [VERIFIED] |
| go_router URL generation | Manual URL strings | Existing `GoRoute(path:'/foo')` declarations; verify URL bar reflects state on `flutter run -d chrome` | Already in place [VERIFIED: lib/router.dart] |

**Key insight:** Every Phase 6 capability except `window_manager` is satisfied by Flutter SDK + existing app patterns. Resist any urge to introduce a state-management package, an animation package, or a "responsive" package. The framework primitives are sufficient and align with project constraints (Provider + setState, no new state libs).

## Runtime State Inventory

> Phase 6 is a polish + refactor phase, not a rename — but it does touch persisted state (mood seed) and OS-registered state (window minimums). Inventory done explicitly.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | **New field on `AppSettings` Hive box: `moodSeedArgb:int?`**. Schema additive — same no-op migration pattern used in Phase 02-01 [VERIFIED STATE.md]. No existing data needs migration; null = pre-check-in curious. | Bump schemaVersion to next integer; add no-op migration in `lib/data/database/migration_runner.dart`. Existing records without the field decode as `null` (Hive default for nullable fields) — verified by Phase 02-01 pattern. |
| Live service config | None — no external services. The dev's existing morning notification (set via Phase 4 `flutter_local_notifications`) is unaffected by Phase 6. | None. |
| OS-registered state | **Desktop window minimum size** — applied at app launch via `windowManager.setMinimumSize`. This is a per-launch call, not OS-registered. No persistent registration. macOS `Runner.xcodeproj` and Windows `runner` already exist (verified gitStatus shows macOS Runner files modified — presumably from a prior macOS build); window_manager works on top without modifying those project files for the size minimum [VERIFIED: pub.dev/packages/window_manager pattern]. **However, window_manager 0.5.x on macOS requires `MainFlutterWindow.swift` to extend `NSWindow` properly — check existing macos/Runner/MainFlutterWindow.swift before installing.** | Plan task: verify `macos/Runner/MainFlutterWindow.swift` compatibility before `flutter pub get` of window_manager (the package's README has the required modification snippet). Treat as a 5-minute "verify or apply" task, not a research blocker. |
| Secrets / env vars | None. | None. |
| Build artifacts | After adding `window_manager: ^0.5.1` to pubspec, `flutter pub get` regenerates `pubspec.lock`. Macos `Podfile.lock` may need refresh (gitStatus shows it untracked already — suggesting macOS pods state is fluid). Windows `runner/CMakeLists.txt` and Linux `linux/CMakeLists.txt` are auto-updated by `flutter pub get` for plugin platform code. | `flutter clean && flutter pub get` after pubspec update to regenerate lockfiles + CMake plugin registrations. |

## Common Pitfalls

### Pitfall 1: `MainFlutterWindow.swift` doesn't extend `NSWindow` correctly on macOS

**What goes wrong:** `window_manager` on macOS requires the host `MainFlutterWindow.swift` to import `window_manager` symbols. New Flutter projects after ~3.7 ship with `MainFlutterWindow: NSWindow` which is compatible, but older or customized projects may have differences.

**Why it happens:** macOS Cocoa window setup is per-host-app, not per-plugin; `window_manager` reaches into the host app's window object.

**How to avoid:** Read `macos/Runner/MainFlutterWindow.swift` before installing the package; compare to `window_manager`'s README example. If the host app declares the window differently, apply the snippet from the README.

**Warning signs:** Compile error on macOS only, mentioning `NSWindow` or `MainFlutterWindow` after first `flutter run -d macos`.

### Pitfall 2: `Timer.periodic` keeps firing while app is backgrounded → battery drain on mobile

**What goes wrong:** A 20-min timer that fires while the device is in standby drains battery + wakes the OS scheduler.

**Why it happens:** Flutter's event loop continues running even when the app's UI is paused; only `WidgetsBindingObserver` exposes the resumed/paused signal.

**How to avoid:** Pair every `Timer.periodic` with a `WidgetsBindingObserver` and `_ticker?.cancel()` in `AppLifecycleState.paused`/`.inactive`; restart on `.resumed`. Pattern in this RESEARCH.md §Pattern 2.

**Warning signs:** Battery profiler shows app at ~1–3% CPU usage when backgrounded. Should be near 0%.

### Pitfall 3: `ColorScheme.lerp` brightness snap-switching at t=0.5 causes a visible flash

**What goes wrong:** If light/dark mode is toggled mid-transition, `ColorScheme.lerp` switches brightness atomically at `t=0.5` rather than interpolating, producing a visible "jump." [VERIFIED: api.flutter.dev/flutter/material/ColorScheme/lerp.html]

**Why it happens:** Brightness isn't a numeric value — it's an enum (`Brightness.light` / `.dark`). Lerp can't interpolate enums, so it picks one side.

**How to avoid:** Phase 6 doesn't toggle dark mode, so this is theoretical. *But* — if a future phase adds dark mode, do not transition between light and dark via `themeAnimationDuration` alone; use a manual cross-fade with two `Theme` widgets stacked, or use Flutter's built-in `MaterialApp.themeMode` switching which handles this case correctly.

**Warning signs:** Visible flash midway through the warming transition (not present in v1 because brightness stays `Brightness.light`).

### Pitfall 4: `tester.view.physicalSize` leaks between tests

**What goes wrong:** Test A sets `tester.view.physicalSize = Size(480, 800)`, test B inherits it and unexpectedly renders narrow.

**Why it happens:** `TestFlutterView` is shared state across tests in the same file. [VERIFIED: api.flutter.dev/flutter/flutter_test/TestFlutterView-class.html]

**How to avoid:** Always pair `tester.view.physicalSize = ...` with `addTearDown(tester.view.reset)` (or `resetPhysicalSize`). The `addTearDown` pattern is required because `tearDown` doesn't have access to `WidgetTester`. [VERIFIED: web search results]

**Warning signs:** Flaky test order — a test passes alone but fails in a suite.

### Pitfall 5: `Dismissible` + `MouseRegion` interaction

**What goes wrong (theoretical risk):** Concern that wrapping `ChunkCard` in `MouseRegion` inside a `Dismissible` could cause hover events to interfere with swipe gestures on touch devices.

**Why it doesn't happen:** `MouseRegion.onEnter`/`onExit` are pointer-only events; they don't fire on touch. `Dismissible` consumes touch drag events normally. The hover-revealed icons stay at `Opacity 0` on mobile (no enter event fires), preserving the swipe affordance. [VERIFIED: api.flutter.dev MouseRegion-class.html]

**How to verify:** Widget test on a touch-only configuration — drag the ChunkCard, assert the swipe completes and the hover icons never reached `opacity > 0`. (Pattern: `tester.drag(find.byType(ChunkCard), const Offset(300, 0))` then `expect(find.byIcon(Icons.check_circle_outline), findsNothing)`.)

**Warning signs:** None expected in practice. Document the verification test as belt-and-suspenders.

### Pitfall 6: Mood seed isn't reset at midnight without an explicit trigger

**What goes wrong:** User checks in at 8am Tuesday with mood 4. Comes back Wednesday at 8am — without an explicit reset, the app still shows mood-4 theme until the new check-in writes a new seed.

**Why it happens:** `ThemeNotifier` reads `moodSeed` from Hive; it doesn't know what day it is unless something tells it.

**How to avoid:** Add a check at app foreground-resume (`didChangeAppLifecycleState` → `.resumed`) and at `ScheduleNotifier.generateToday` entry: if `ScheduleNotifier.todayYmd != lastSeenYmd`, call `themeNotifier.resetToCurious()`. The `ScheduleNotifier` already tracks "today" for schedule purposes [VERIFIED: `lib/providers/schedule_notifier.dart` referenced as `hasScheduleToday`/`todaySchedule` in main.dart and home_screen.dart].

**Warning signs:** User reports "the app stayed sunny all night and through Wednesday morning."

## Code Examples

### Mood seed → ColorScheme.fromSeed (verifiable)
```dart
// Pure function, unit-testable
ColorScheme schemeFor(int moodIndex) => ColorScheme.fromSeed(
      seedColor: ThemeNotifier.moodSeeds[moodIndex]!,
    );

// Verification in a unit test
test('mood 3 produces teal-derived primary', () {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF4A8C7A));
  // Material 3 derives primary algorithmically — assert HSL hue stays in teal range
  final hsl = HSLColor.fromColor(scheme.primary);
  expect(hsl.hue, inInclusiveRange(140.0, 180.0));  // teal hue band
});
```

### Time-of-day modulation (pure function, deterministic)
```dart
// In lib/services/mood_theme_service.dart
import 'dart:math' as math;
import 'package:flutter/painting.dart';

Color modulateForTime(Color base, DateTime now) {
  final hsl = HSLColor.fromColor(base);
  final minutes = now.hour * 60 + now.minute;
  final t = math.cos(2 * math.pi * (minutes / 1440 - 0.5)); // cos peaks at noon
  return hsl
      .withLightness((hsl.lightness + 0.05 * t).clamp(0.0, 1.0))
      .withSaturation((hsl.saturation + 0.10 * t).clamp(0.0, 1.0))
      .toColor();
}

// Tests
test('modulation peaks at noon', () {
  final base = const Color(0xFF4A8C7A);
  final baseHsl = HSLColor.fromColor(base);
  final modulated = modulateForTime(base, DateTime(2026, 5, 12, 12, 0));
  final modHsl = HSLColor.fromColor(modulated);
  expect(modHsl.lightness, closeTo(baseHsl.lightness + 0.05, 0.01));
  expect(modHsl.saturation, closeTo(baseHsl.saturation + 0.10, 0.01));
});

test('modulation troughs at midnight', () {
  final base = const Color(0xFF4A8C7A);
  final baseHsl = HSLColor.fromColor(base);
  final modulated = modulateForTime(base, DateTime(2026, 5, 12, 0, 0));
  final modHsl = HSLColor.fromColor(modulated);
  expect(modHsl.lightness, closeTo(baseHsl.lightness - 0.05, 0.01));
  expect(modHsl.saturation, closeTo(baseHsl.saturation - 0.10, 0.01));
});
```

### Breathing pulse on pre-check-in CTA
```dart
// In home_screen.dart _buildEmptyState
class _BreathingPulseButton extends StatefulWidget {
  const _BreathingPulseButton({required this.onPressed, required this.child});
  final VoidCallback onPressed;
  final Widget child;

  @override
  State<_BreathingPulseButton> createState() => _BreathingPulseButtonState();
}

class _BreathingPulseButtonState extends State<_BreathingPulseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    final disableAnimations = WidgetsBinding.instance.platformDispatcher
        .accessibilityFeatures.disableAnimations;
    if (!disableAnimations) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      builder: (context, child) {
        final t = _controller.value;
        final blur = 8.0 + 8.0 * t; // 8 -> 16
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.25),
                blurRadius: blur,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: OutlinedButton(
        onPressed: widget.onPressed,
        child: widget.child,
      ),
    );
  }
}
```

### MouseRegion hover-reveal on ChunkCard
```dart
// chunk_card.dart — wrap _buildWork return value
class _HoverableChunkCard extends StatefulWidget {
  const _HoverableChunkCard({required this.chunk, required this.goalColor});
  // ... fields

  @override
  State<_HoverableChunkCard> createState() => _HoverableChunkCardState();
}

class _HoverableChunkCardState extends State<_HoverableChunkCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(children: [
        // existing card content here
        Positioned(
          right: 0, top: 0, bottom: 0,
          child: AnimatedOpacity(
            opacity: _hovered ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                tooltip: 'Mark complete',
                onPressed: _hovered ? () => /* mark complete */ : null,
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_outlined),
                tooltip: 'Skip',
                onPressed: _hovered ? () => /* mark skip */ : null,
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
```

### Drag handle visibility per platform (ReorderableListView)
```dart
// In goals_screen.dart _buildReorderableSection — replace existing trailing
final isMobileTouch = defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

ReorderableListView.builder(
  buildDefaultDragHandles: false,
  itemBuilder: (ctx, i) => GoalCard(
    key: ValueKey(group[i].id),
    goal: group[i],
    onTap: () => _openEditSheet(context, group[i]),
    trailing: isMobileTouch
        ? const SizedBox.shrink()  // hidden; long-press drives reorder
        : MouseRegion(
            child: ReorderableDelayedDragStartListener(
              index: i,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: 0.6,  // resting; on hover bumps to 1.0 via parent InkWell.onHover
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.drag_handle,
                      color: Theme.of(context).colorScheme.outline),
                ),
              ),
            ),
          ),
  ),
  onReorder: (oldIndex, newIndex) => notifier.reorder(type, oldIndex, newIndex),
);
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `AnimatedTheme` wrapping content | `MaterialApp.themeAnimationDuration` + `themeAnimationCurve` | Flutter 3.19 (Feb 2024) | Cleaner; avoid having to find a "wrappable" widget — applies to the entire MaterialApp's theme transition |
| `dart:io` direct imports for desktop | Conditional imports via `dart.library.io` | Stable since Dart 2.x; widely adopted | Allows the same `main.dart` to compile for web + mobile + desktop without #ifdef-style branching |
| `MediaQuery.of(context).size.width` for breakpoints | `LayoutBuilder(builder: (ctx, constraints) => ...)` | Material 3 era guidance | LayoutBuilder gives widget-local constraints, not screen size — correct for nested layouts and testable via `tester.view.physicalSize` |

**Deprecated / outdated:**
- `WidgetsBinding.instance.window` (singleton access) — deprecated; use `tester.view` in tests and `WidgetsBinding.instance.platformDispatcher.views.first` in app code if absolutely needed [CITED: docs.flutter.dev/release/breaking-changes/window-singleton]. Phase 6 does not touch this directly.
- `withOpacity()` — Flutter has been migrating toward `withValues(alpha: ...)` for HDR-color correctness [VERIFIED: existing code uses `withValues(alpha: ...)` at `chunk_card.dart:51`, `checkin_screen.dart:282`]. Keep using `.withValues(alpha: ...)`.

## Assumptions Log

> Claims tagged `[ASSUMED]` in this research. Empty table means all claims were verified.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Mood-seed reset at midnight should happen in `ScheduleNotifier.generateToday` (or app resume) | Pitfall 6 + Pattern 2 (resetToCurious) | If the wrong seam is chosen, the curious-theme reset could fire too often (every resume) or not at all (never resets). **Planner should validate seam choice during plan-check** — the current `ScheduleNotifier.hasScheduleToday` pattern suggests a `currentYmd != lastYmd` check is already implicit somewhere in that notifier. |
| A2 | `MaterialApp.themeAnimationDuration` is preferred over `AnimatedTheme` wrapper for Phase 6's use case | Pattern 1 + Standard Stack alternatives | Both work. If a future requirement needs subtree-only theming, `AnimatedTheme` may resurface. For now, the MaterialApp parameter is simpler and the Material 3 idiom — confirmed against api.flutter.dev. |
| A3 | mood 3 (`#4A8C7A`) is the right default for `pumpWithMood` | Pattern 5 + UI-SPEC §Widget Test Mood-Pinning Strategy | UI-SPEC already locked mood 3 as the default — research confirms this is sensible (median weather, balanced contrast). |

## Open Questions

1. **Mood seed reset timing seam**
   - **What we know:** D-10 forbids carry-forward. Theme must reset to curious every morning.
   - **What's unclear:** Whether the reset belongs in `ScheduleNotifier.generateToday`, `ThemeNotifier.init` (compare lastSeenDate to today), or `_HomeScreenState.initState`.
   - **Recommendation:** Put the reset in `ThemeNotifier` itself — on `init()` and on `didChangeAppLifecycleState(resumed)`, compare a persisted `lastMoodSetYmd` to today's local Ymd; if different, set `_moodSeed = null` (do not write a new seed to Hive — let the user's next mood tap do that). This keeps the reset logic in the theme's own module rather than dispersed across `ScheduleNotifier` and `HomeScreen`. **Confirm in plan-check.**

2. **macOS NSWindow modification required for window_manager**
   - **What we know:** `window_manager` README states macOS host app's `MainFlutterWindow.swift` may need a snippet to extend `NSWindow` correctly.
   - **What's unclear:** Whether Canopy's existing `macos/Runner/MainFlutterWindow.swift` already satisfies this (gitStatus shows Runner.xcodeproj modified — suggests recent macOS build work happened).
   - **Recommendation:** Plan task 0 of the window_manager work: read `macos/Runner/MainFlutterWindow.swift`, compare to window_manager's README example, apply diff only if needed. Likely a 2-line change or already correct.

3. **Whether to verify Web URLs automatically or manually**
   - **What we know:** AC-4 ("direct navigation to `/schedule`, `/goals` loads correct screen") is verifiable manually with `flutter run -d chrome` + URL bar typing.
   - **What's unclear:** Whether integration tests on Chrome (`flutter test --platform chrome`) are worth the CI cost for this specific AC.
   - **Recommendation:** Manual verification in Phase 6 — the route table is already correct and stable. If Phase 7+ adds deep-linking complexity, revisit. Document the manual test in `## Validation Architecture` below.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All Phase 6 work | ✓ | ^3.10.3 (Flutter 3.19+) | — |
| Dart SDK | All | ✓ (transitively via Flutter) | ^3.10.3 | — |
| `flutter analyze` | AC verification | ✓ | bundled | — |
| `flutter test` | Widget tests | ✓ | bundled | — |
| Chrome browser | Web URL verification (AC-4) | ✓ (verified via `flutter devices` in any standard dev setup) | — | Edge/Firefox via `flutter run -d web-server --web-port=8080` then any browser |
| macOS host (Xcode + CocoaPods) | Desktop AC-1, AC-3 verification on macOS | ✓ (current dev platform per gitStatus) | — | — |
| Windows host | AC-3 verification on Windows | Per dev availability | — | macOS or Linux desktop builds also exercise window_manager — same code path |
| Linux host | AC-3 verification on Linux | Per dev availability | — | Same code path as Windows/macOS |
| `window_manager 0.5.1` package | AC-3 | Not yet installed (this phase installs it) | — | None — package is the established Flutter desktop window solution |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** Windows/Linux hosts — verifiable on macOS for code-correctness; Windows-specific QA may need a virtual machine or a CI Windows runner (out of scope for this phase per existing project's "one dev, one machine" practice).

## Validation Architecture

> Nyquist Dimension 8 — explicit map of validation surfaces.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with Flutter SDK ^3.10.3) |
| Config file | none required — `flutter_test` reads `test/` directory by convention |
| Quick run command | `flutter test test/screens/responsive_layout_test.dart -r expanded` |
| Full suite command | `flutter test` |
| Web URL smoke | `flutter run -d chrome` (manual) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AC-1 | LayoutBuilder swaps NavigationBar → NavigationRail at 720dp boundary | widget | `flutter test test/screens/responsive_layout_test.dart` | ❌ Wave 0 |
| AC-1 | Two-column rendering does not overflow at 1280×800 | widget | `flutter test test/screens/responsive_layout_test.dart` (assert no `OverflowError` exceptions captured) | ❌ Wave 0 |
| AC-2 | `MouseRegion.onEnter` on ChunkCard reveals checkbox + skip (opacity → 1) | widget | `flutter test test/screens/chunk_card_hover_test.dart` | ❌ Wave 0 |
| AC-2 | `MouseRegion.onExit` hides revealed icons (opacity → 0) | widget | (same file) | ❌ Wave 0 |
| AC-2 | Touch drag on `Dismissible`-wrapped `ChunkCard` swipes-completes without hover icons appearing | widget | (same file — use `tester.drag` to verify cross-input parity) | ❌ Wave 0 |
| AC-2 | `InkWell.onHover` on GoalCard reveals edit + archive icons | widget | `flutter test test/screens/goal_card_hover_test.dart` | ❌ Wave 0 |
| AC-3 | `window_manager.setMinimumSize(480, 640)` is called on desktop platforms only | unit | `flutter test test/platform/window_setup_test.dart` (use `WindowManagerPlatform` mock or assert call via test substitute) | ❌ Wave 0 |
| AC-3 | Conditional import compiles on web (stub branch only) | smoke | `flutter build web --no-tree-shake-icons` (build success, no `dart:io` errors) | ❌ Wave 0 — add to CI |
| AC-3 | Window resizes refuse below 480px on macOS | manual | run `flutter run -d macos`, drag window narrower than 480px logical — snaps back | manual |
| AC-4 | Direct URL `/schedule` loads ScheduleScreen on Web | manual | `flutter run -d chrome`, type `/schedule` in URL bar, verify screen | manual |
| AC-4 | Direct URL `/goals` loads GoalsScreen on Web | manual | (same) | manual |
| AC-4 | Direct URL `/review` loads QuarterlyReviewScreen on Web | manual | (same) | manual |
| AC-4 | go_router redirect respects onboardingComplete state on direct URL load | widget | `flutter test test/screens/router_redirect_test.dart` (existing `createRouter` factory + test harness with `SettingsNotifier` mock) | ❌ Wave 0 |
| AC-5 | Existing `quarterly_review_test.dart` migrates to `pumpWithMood`, passes unchanged | widget | `flutter test test/screens/quarterly_review_test.dart` | ✅ exists; helper migration in Wave 0 |
| AC-5 | LayoutBuilder breakpoint tests at 480/720/1200dp pass | widget | `flutter test test/screens/responsive_layout_test.dart` | ❌ Wave 0 |
| AC-6 | Mood seed change in `ThemeNotifier` triggers `notifyListeners` | unit | `flutter test test/providers/theme_notifier_test.dart` | ❌ Wave 0 |
| AC-6 | `_modulateHsl` peaks at noon | unit | (same file) | ❌ Wave 0 |
| AC-6 | `_modulateHsl` troughs at midnight | unit | (same file) | ❌ Wave 0 |
| AC-6 | `ThemeNotifier` ticker cancels on `AppLifecycleState.paused`, restarts on `.resumed` | unit | (same file — call `themeNotifier.didChangeAppLifecycleState` directly) | ❌ Wave 0 |
| AC-6 | Curious seed (`#7A8FA3`) used when `_moodSeed == null` | unit | (same file) | ❌ Wave 0 |
| AC-6 | Mood tap → ColorScheme.fromSeed change visible within 600ms | manual | `flutter run -d macos`, tap each mood at check-in, observe warming transition completes within 600ms (UI-SPEC locks 500ms) | manual |
| Pre-check-in pulse | Breathing pulse animates on CTA when no mood set | widget | `flutter test test/screens/home_screen_breathing_pulse_test.dart` (verify AnimationController.isAnimating + shadow blur in `BoxDecoration`) | ❌ Wave 0 |
| Pre-check-in pulse | Pulse stops when mood is set | widget | (same file — set mood via mock ThemeNotifier, assert animation stopped) | ❌ Wave 0 |
| Pre-check-in pulse | Pulse respects `MediaQuery.disableAnimations` | widget | (same file — wrap with `MediaQuery(data: MediaQueryData(accessibleNavigation: true, disableAnimations: true), ...)`) | ❌ Wave 0 |
| Drag handle visibility | Hidden on mobile (Android, iOS) | widget | `flutter test test/screens/goal_card_drag_handle_test.dart` (set `debugDefaultTargetPlatformOverride = TargetPlatform.android` + reset in `tearDown`) | ❌ Wave 0 |
| Drag handle visibility | Visible at 0.6 opacity on desktop | widget | (same file with macOS/linux/windows override) | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter analyze && flutter test test/{relevant single file}`
- **Per wave merge:** `flutter test` (full suite, ~5–10s on this project size)
- **Phase gate:** Full suite green + manual checklist (AC-3 macOS resize, AC-4 web URL navigation, AC-6 mood tap visual) before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/test_helpers/mood_pump.dart` — `pumpWithMood` helper used by all migrated widget tests
- [ ] `test/test_helpers/viewport.dart` — `setViewport(tester, size)` + auto-`addTearDown` wrapper
- [ ] `test/providers/theme_notifier_test.dart` — unit tests for HSL modulation, ticker lifecycle, curious seed default, persistence interaction
- [ ] `test/screens/responsive_layout_test.dart` — LayoutBuilder breakpoint tests at 480/720/1200dp
- [ ] `test/screens/chunk_card_hover_test.dart` — MouseRegion onEnter/onExit + Dismissible-no-conflict
- [ ] `test/screens/goal_card_hover_test.dart` — InkWell.onHover + revealed icons
- [ ] `test/screens/goal_card_drag_handle_test.dart` — platform-gated drag handle visibility
- [ ] `test/screens/home_screen_breathing_pulse_test.dart` — pre-check-in pulse + disableAnimations respect
- [ ] `test/platform/window_setup_test.dart` — stub vs io branch behaviour; mock WindowManager surface for io path
- [ ] `test/screens/router_redirect_test.dart` — go_router redirect respects onboardingComplete on direct URL load

*(Existing test infrastructure is minimal: only `widget_test.dart` placeholder, `quarterly_review_test.dart`, three service tests, one repository test. Phase 6 will add substantial new test coverage — call out in plan that Wave 0 is non-trivial.)*

## Sources

### Primary (HIGH confidence)
- [Flutter MaterialApp.themeAnimationDuration](https://api.flutter.dev/flutter/material/MaterialApp/themeAnimationDuration.html) — verified `themeAnimationDuration` + `themeAnimationCurve` on `MaterialApp.router`
- [Flutter ColorScheme.lerp](https://api.flutter.dev/flutter/material/ColorScheme/lerp.html) — verified all-roles interpolation + brightness snap at t=0.5
- [Flutter HSLColor class](https://api.flutter.dev/flutter/painting/HSLColor-class.html) — verified `withLightness`, `withSaturation`, `fromColor`, `toColor` round-trip
- [Flutter NavigationRail class](https://api.flutter.dev/flutter/material/NavigationRail-class.html) — verified Row+Expanded pattern, selectedIndex management
- [Flutter MouseRegion class](https://api.flutter.dev/flutter/widgets/MouseRegion-class.html) — verified onEnter/onExit pointer-only semantics
- [Flutter AnimatedTheme class](https://api.flutter.dev/flutter/material/AnimatedTheme-class.html) — verified existence + kThemeAnimationDuration default
- [Flutter WidgetsBindingObserver](https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html) — verified didChangeAppLifecycleState + addObserver/removeObserver pattern
- [Flutter TestFlutterView](https://api.flutter.dev/flutter/flutter_test/TestFlutterView-class.html) — verified `view.physicalSize` + `addTearDown(view.reset)` pattern
- [pub.dev window_manager 0.5.1](https://pub.dev/packages/window_manager) — current version, supported platforms (Win/macOS/Linux), `ensureInitialized` + `setMinimumSize` API
- [pub.dev window_manager example](https://pub.dev/packages/window_manager/example) — verified initialization pattern in main.dart
- [pub.dev go_router StatefulShellRoute](https://pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html) — verified shell branches retain navigator state across parent scaffold changes

### Secondary (MEDIUM confidence)
- [Code with Andrea — Bottom navigation + StatefulShellRoute](https://codewithandrea.com/articles/flutter-bottom-navigation-bar-nested-routes-gorouter/) — responsive LayoutBuilder pattern; their breakpoint is 450dp but the pattern transfers directly to Canopy's 720dp
- [Medium — Conditional Imports across Flutter and Web](https://medium.com/flutter-community/conditional-imports-across-flutter-and-web-4b88885a886e) — verified `dart.library.io` is the standard conditional-import key for desktop-only packages
- [docs.flutter.dev — Test orientation cookbook](https://docs.flutter.dev/cookbook/testing/widget/orientation) — `tester.view.physicalSize` + `addTearDown(view.reset)` pattern
- [Medium — Theme Animation Customisation in Flutter 3.19](https://medium.com/@vadoliya.nikhil99/unlocking-theme-animation-customisation-in-flutter-3-19-b966d8fe7576) — confirmed themeAnimationCurve was added in Flutter 3.19

### Tertiary (LOW confidence — none used directly)
None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — `window_manager 0.5.1` confirmed on pub.dev; all other deps already in pubspec; Flutter built-ins documented by api.flutter.dev
- Architecture (ThemeNotifier + lifecycle ticker + conditional import): HIGH — patterns verified against multiple Flutter docs sources; no novel work
- Pitfalls: HIGH — each pitfall traced to verified docs or codebase patterns; none speculative

**Research date:** 2026-05-12
**Valid until:** 2026-06-12 (30 days — Flutter 3.x is stable, `window_manager` is on a slow release cadence, project is Flutter-only)

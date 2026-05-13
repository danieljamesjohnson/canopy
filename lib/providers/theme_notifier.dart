// ThemeNotifier — single source of truth for the app's color identity.
//
// Implements Phase 6 Decisions:
//   - D-01: Full mood theming via ColorScheme.fromSeed at MaterialApp level.
//   - D-02: Every theme-able screen follows the daily mood (no per-route overrides).
//   - D-03: Mood palette locked (5 hex values below).
//   - D-04: Two-axis color — hue from mood, brightness/saturation from time of day.
//   - D-05: 20-minute debounced refresh (inside the D-05 15–30min budget).
//   - D-06: Bounded ±5% lightness / ±10% saturation HSL swing — gentle, not full inversion.
//   - D-07: Pre-check-in "curious" seed (0xFF7A8FA3) when no mood is set.
//   - D-09: setMoodSeed() persists + notifyListeners() — the call MoodCheckinScreen invokes;
//           the resulting MaterialApp rebuild is animated via themeAnimationDuration
//           (configured in Plan 04) to satisfy AC-6 (visible within 600ms).
//   - D-10: No-carry-forward via `_resetIfDayChanged()` — called from init() and on resume.
//
// Read by `MaterialApp.router.theme` (wired in Plan 04). Written by `MoodCheckinScreen`
// on mood tap (wired in Plan 04). Initialized in `main.dart` before `runApp` (Plan 04).
//
// Pattern source: RESEARCH.md §Pattern 2 (Lifecycle-Aware Ticker) + Pitfall 2 (lifecycle
// pause prevents Timer.periodic battery drain) + Pitfall 6 / Open Question 1 (daily
// rollover seam encapsulated as `_resetIfDayChanged`).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models/app_settings.dart';
import '../data/repositories/app_settings_repository.dart';
import '../data/repositories/hive_app_settings_repository.dart';

/// Drives the app-wide `ColorScheme.fromSeed` via the user's current mood
/// seed (or the "curious" pre-check-in seed when no mood has been set today).
///
/// Time-of-day modulation runs on a lifecycle-aware 20-minute ticker that
/// pauses on `AppLifecycleState.paused` and resumes on `.resumed`.
class ThemeNotifier extends ChangeNotifier with WidgetsBindingObserver {
  /// Construct a ThemeNotifier. [repository] defaults to
  /// `HiveAppSettingsRepository()` (production). [now] defaults to
  /// `DateTime.now` and is injectable for unit tests. Set
  /// [timeModulationEnabled] = false in widget tests to disable the
  /// modulation ticker entirely (UI-SPEC §Widget Test Mood-Pinning Strategy).
  ThemeNotifier({
    AppSettingsRepository? repository,
    DateTime Function() now = DateTime.now,
    bool timeModulationEnabled = true,
  })  : _repo = repository ?? HiveAppSettingsRepository(),
        _now = now,
        _timeModulationEnabled = timeModulationEnabled;

  /// Pre-check-in pale slate-blue per UI-SPEC §Pre-Check-in 'Curious' Seed.
  /// HSL approx H210/S20/L56.
  static const Color curiousSeed = Color(0xFF7A8FA3);

  /// Mood seeds (D-03, UI-SPEC §Mood Seed Palette). Locked Phase 3.
  static const Map<int, Color> moodSeeds = {
    1: Color(0xFF4A6275),
    2: Color(0xFF5C7A8A),
    3: Color(0xFF4A8C7A),
    4: Color(0xFF7AAF6A),
    5: Color(0xFFE8C547),
  };

  final AppSettingsRepository _repo;
  final DateTime Function() _now;
  final bool _timeModulationEnabled;

  Color? _moodSeed; // null = pre-check-in "curious"
  int? _lastMoodSetYmd;
  Timer? _ticker;
  bool _isForeground = true;

  /// True if the user has not yet set a mood today — the app is in the
  /// "curious / waiting" state (D-07).
  bool get isPreCheckin => _moodSeed == null;

  /// Material 3 ThemeData seeded from the current effective seed
  /// (mood seed or curious seed, with time-of-day HSL modulation when
  /// enabled).
  ThemeData get currentTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _effectiveSeed()),
      );

  /// Loads persisted mood seed + lastMoodSetYmd from Hive, registers the
  /// lifecycle observer, starts the 20-minute modulation ticker, and
  /// notifies listeners. Call once at startup after `HiveDatabase.init()`
  /// and before `runApp`.
  ///
  /// On load, if the persisted `lastMoodSetYmdInt` is from a previous local
  /// day, the in-memory mood seed is reset to null (curious) without
  /// writing to Hive — per D-10, no carry-forward; the next mood tap will
  /// refresh the persisted seed.
  Future<void> init() async {
    final settings = await _repo.getSettings();
    final argb = settings?.moodSeedArgb;
    _moodSeed = (argb == null) ? null : Color(argb);
    _lastMoodSetYmd = settings?.lastMoodSetYmdInt;
    _resetIfDayChanged();
    WidgetsBinding.instance.addObserver(this);
    _startTicker();
    notifyListeners();
  }

  /// Sets the user's mood seed, persists `moodSeedArgb` and
  /// `lastMoodSetYmdInt` to Hive, and notifies listeners. Called by
  /// `MoodCheckinScreen` on mood tap (wired in Plan 04). The resulting
  /// MaterialApp theme swap is animated by `themeAnimationDuration`
  /// (set in Plan 04 to 500ms easeOutCubic) to satisfy AC-6.
  Future<void> setMoodSeed(Color seed) async {
    _moodSeed = seed;
    _lastMoodSetYmd = _ymdToday();
    final s = await _repo.getSettings() ?? AppSettings();
    s.moodSeedArgb = seed.toARGB32();
    s.lastMoodSetYmdInt = _lastMoodSetYmd;
    await _repo.saveSettings(s);
    notifyListeners();
  }

  /// Clears the mood seed and persists `moodSeedArgb = null` to Hive,
  /// then notifies listeners. Used by the midnight rollover seam and by
  /// any explicit "reset mood" affordance.
  Future<void> resetToCurious() async {
    _moodSeed = null;
    final s = await _repo.getSettings() ?? AppSettings();
    s.moodSeedArgb = null;
    await _repo.saveSettings(s);
    notifyListeners();
  }

  /// Daily rollover seam (RESEARCH.md Open Question 1 + Pitfall 6).
  /// Called from `init()` and on `AppLifecycleState.resumed`. If the
  /// persisted last-set Ymd is from a previous local day, clears the
  /// in-memory mood seed without writing to Hive — the next `setMoodSeed`
  /// call will refresh the persisted seed. Per D-10: no carry-forward.
  void _resetIfDayChanged() {
    if (_lastMoodSetYmd != null && _lastMoodSetYmd != _ymdToday()) {
      _moodSeed = null;
    }
  }

  /// Encodes today's local date as a YYYYMMDD int (e.g., 20260513).
  int _ymdToday() {
    final n = _now();
    return n.year * 10000 + n.month * 100 + n.day;
  }

  /// Returns the seed to feed into `ColorScheme.fromSeed`. Combines the
  /// active mood seed (or `curiousSeed` if none) with HSL time-of-day
  /// modulation when enabled.
  Color _effectiveSeed() {
    final base = _moodSeed ?? curiousSeed;
    if (!_timeModulationEnabled) return base;
    return modulateHsl(base, _now());
  }

  /// Pure function — easy to unit-test with synthetic DateTime inputs
  /// (Plan 06 owns the assertion tests against this method).
  ///
  /// Marked `@visibleForTesting` so `test/providers/theme_notifier_test.dart`
  /// can assert the HSL math against synthetic DateTime inputs without
  /// constructing a full ThemeNotifier. Production callers use the private
  /// path through `_effectiveSeed()` / `currentTheme`.
  ///
  /// UI-SPEC §Time-of-Day Modulation (locked math):
  ///   t = cos(2π * (minutesSinceMidnight / 1440 - 0.5))  // peak noon, trough midnight
  ///   newL = (hsl.lightness + 0.05 * t).clamp(0.0, 1.0)  // ±5% absolute lightness
  ///   newS = (hsl.saturation + 0.10 * t).clamp(0.0, 1.0) // ±10% absolute saturation
  @visibleForTesting
  static Color modulateHsl(Color base, DateTime now) {
    final hsl = HSLColor.fromColor(base);
    final minutes = now.hour * 60 + now.minute;
    final t = math.cos(2 * math.pi * (minutes / 1440 - 0.5));
    final newL = (hsl.lightness + 0.05 * t).clamp(0.0, 1.0);
    final newS = (hsl.saturation + 0.10 * t).clamp(0.0, 1.0);
    return hsl.withLightness(newL).withSaturation(newS).toColor();
  }

  /// Starts the 20-minute modulation ticker. Cancels any existing ticker
  /// first (idempotent). Skips startup entirely if modulation is disabled
  /// or the app is currently backgrounded — per RESEARCH.md Pitfall 2,
  /// `Timer.periodic` must pause on `AppLifecycleState.paused` to avoid
  /// battery drain on mobile.
  void _startTicker() {
    _ticker?.cancel();
    if (!_timeModulationEnabled || !_isForeground) return;
    _ticker = Timer.periodic(const Duration(minutes: 20), (_) {
      // Notify regardless of mood — both modulated curious AND modulated
      // mood seeds drift through the day.
      notifyListeners();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) {
      // Re-check the day on resume (catches users who background overnight)
      // and re-modulate immediately to refresh stale theme.
      _resetIfDayChanged();
      _startTicker();
      notifyListeners();
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

import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 25 (Time Travel, DEV-01/02/03) — the app's single clock source.
///
/// This holds an OFFSET (a [Duration]), NOT a frozen instant (DEV-02). Time
/// must keep flowing while overridden so the Today screen's 1-minute ticker
/// still advances and a moving now-marker (Phase 26) can be watched. A
/// frozen clock would make that untestable.
///
/// Every mutator, plus [init], no-ops outside [kDebugMode] (DEV-03) — in a
/// release build [_offset] can never become non-zero, so [now] is exactly
/// `DateTime.now()`. This is guarded INSIDE the class so no caller needs to
/// remember to check kDebugMode itself.
///
/// Persisted via [SharedPreferences] (already a bootstrap dependency, same
/// as [SettingsNotifier]'s underlying store) so the override survives a
/// page reload — load-bearing for web UAT, which reloads constantly.
class DevClock {
  DevClock._();

  static const String _prefsKey = 'dev_clock_offset_micros';

  static Duration _offset = Duration.zero;

  /// The current simulated time: real wall-clock time plus the active
  /// offset. In a release build [_offset] is always [Duration.zero], so
  /// this is exactly `DateTime.now()`.
  static DateTime now() => DateTime.now().add(_offset);

  /// True when a non-zero offset is active — i.e. the app is NOT showing
  /// real time. Always false in release builds.
  static bool get isActive => _offset != Duration.zero;

  /// The current offset. Exposed (read-only) so debug UI can display how far
  /// from real time the simulated clock has drifted.
  static Duration get offset => _offset;

  /// Loads a persisted offset at startup. Call once, early in `main()`,
  /// before notifiers are constructed (so their first clock read already
  /// reflects any prior simulated time). No-op outside [kDebugMode].
  static Future<void> init() async {
    if (!kDebugMode) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final micros = prefs.getInt(_prefsKey);
      if (micros != null) {
        _offset = Duration(microseconds: micros);
      }
    } catch (_) {
      // Persistence unavailable (e.g. some test harnesses) — fall back to
      // real time rather than blocking startup.
    }
  }

  /// Sets the simulated "now" to [target] by computing and persisting the
  /// offset between [target] and real wall-clock time. No-op outside
  /// [kDebugMode].
  static Future<void> setSimulatedNow(DateTime target) async {
    if (!kDebugMode) return;
    _offset = target.difference(DateTime.now());
    await _persist();
  }

  /// Shifts the current offset by [delta] — for quick +1h / -1h style jumps.
  /// Composes with any existing offset. No-op outside [kDebugMode].
  static Future<void> shift(Duration delta) async {
    if (!kDebugMode) return;
    _offset += delta;
    await _persist();
  }

  /// Clears the override, returning [now] to real time. No-op outside
  /// [kDebugMode].
  static Future<void> clear() async {
    if (!kDebugMode) return;
    _offset = Duration.zero;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {
      // Best-effort: in-memory offset is already cleared regardless.
    }
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKey, _offset.inMicroseconds);
    } catch (_) {
      // Best-effort: in-memory offset still took effect for this session.
    }
  }

  /// Test-only reset hook: clears the in-memory offset WITHOUT touching
  /// SharedPreferences or requiring kDebugMode, so widget/unit tests that
  /// call [setSimulatedNow] can restore a clean starting state between runs
  /// without depending on debug-mode gating or persisted storage.
  @visibleForTesting
  static void resetForTest() {
    _offset = Duration.zero;
  }

  /// Test-only synchronous offset setter. [setSimulatedNow] and [shift] are
  /// async (they persist) and gated on [kDebugMode]; widget tests need to
  /// move the clock mid-pump without awaiting a SharedPreferences write, so
  /// this sets the in-memory offset directly and nothing else.
  @visibleForTesting
  static void setOffsetForTest(Duration offset) {
    _offset = offset;
  }
}

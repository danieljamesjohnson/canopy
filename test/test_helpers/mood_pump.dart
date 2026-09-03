// Pump helper that pins a known mood seed for widget tests, per Phase 6
// UI-SPEC §Color §Widget Test Mood-Pinning Strategy and RESEARCH.md Pattern 5.
//
// Widget tests cannot run the real ThemeNotifier because the 20-minute
// time-of-day ticker would make color assertions order-dependent
// (UI-SPEC: "Time-of-day modulation disabled under flutter test"). This
// helper bypasses ThemeNotifier entirely and constructs the same
// ColorScheme.fromSeed that the production code would yield at the chosen
// mood, with no ticker running.

// ThemeNotifier.moodSeeds will be defined in lib/providers/theme_notifier.dart (Plan 02).
import 'package:canopy/providers/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Pumps [child] inside a MaterialApp whose theme is seeded from
/// `ThemeNotifier.moodSeeds[moodIndex]`. Default [moodIndex] is 3
/// (#4A8C7A — the UI-SPEC locked test fixture seed).
///
/// [extraProviders] are inserted into a MultiProvider above the
/// MaterialApp so tests that need notifiers (goals, settings, etc.)
/// can supply them without rewriting the pump call.
Future<void> pumpWithMood(
  WidgetTester tester,
  Widget child, {
  int moodIndex = 3,
  Iterable<ChangeNotifierProvider> extraProviders = const [],
}) async {
  final seed = ThemeNotifier.moodSeeds[moodIndex]!;
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: seed),
  );
  final app = MaterialApp(
    theme: theme,
    home: Scaffold(body: child),
  );
  // `MultiProvider` asserts `children.isNotEmpty`; wrap only when callers
  // supplied at least one provider. Tests that don't need providers (hover,
  // drag handle visibility, breakpoint) pass `extraProviders: const []`.
  final providers = extraProviders.toList(growable: false);
  await tester.pumpWidget(
    providers.isEmpty ? app : MultiProvider(providers: providers, child: app),
  );
}

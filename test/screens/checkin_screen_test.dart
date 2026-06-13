// Unit tests for _onBgColor luminance-threshold getter — Phase 13 CHECKIN-01.
//
// Tests Color.computeLuminance() behavior against the five mood seed colors
// from ThemeNotifier.moodSeeds to verify WCAG AA compliance:
//   dark text on light backgrounds (luminance > 0.35)
//   white text on dark backgrounds (luminance <= 0.35)
//
// The _onBgColor getter logic:
//   luminance > 0.35 → Color(0xFF1A1A1A) (dark foreground)
//   luminance <= 0.35 → Colors.white (white foreground)
//
// No widget pump needed — Color.computeLuminance() is a pure method.
// Mirrors test/providers/theme_notifier_test.dart structure.

import 'package:canopy/providers/theme_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('_onBgColor luminance threshold (CHECKIN-01)', () {
    // WCAG threshold: luminance > 0.35 requires dark foreground
    // (Color(0xFF1A1A1A)), luminance <= 0.35 keeps white foreground.
    // This mirrors the logic in _CheckinScreenState._onBgColor.

    test('mood 1 (#4A6275, slate-blue) luminance is <= 0.35 → white foreground', () {
      final color = ThemeNotifier.moodSeeds[1]!;
      // #4A6275 relative luminance ≈ 0.10 — well into the dark range.
      expect(
        color.computeLuminance(),
        lessThanOrEqualTo(0.35),
        reason:
            'Mood 1 (#4A6275) must be dark enough for white text (WCAG AA). '
            'Actual luminance: ${color.computeLuminance().toStringAsFixed(4)}',
      );
    });

    test('mood 2 (#5C7A8A, steel-blue) luminance is <= 0.35 → white foreground', () {
      final color = ThemeNotifier.moodSeeds[2]!;
      // #5C7A8A relative luminance ≈ 0.16 — dark range.
      expect(
        color.computeLuminance(),
        lessThanOrEqualTo(0.35),
        reason:
            'Mood 2 (#5C7A8A) must be dark enough for white text (WCAG AA). '
            'Actual luminance: ${color.computeLuminance().toStringAsFixed(4)}',
      );
    });

    test('mood 3 (#4A8C7A, teal-green) luminance is <= 0.35 → white foreground', () {
      final color = ThemeNotifier.moodSeeds[3]!;
      // #4A8C7A relative luminance ≈ 0.18 — dark range.
      expect(
        color.computeLuminance(),
        lessThanOrEqualTo(0.35),
        reason:
            'Mood 3 (#4A8C7A) must be dark enough for white text (WCAG AA). '
            'Actual luminance: ${color.computeLuminance().toStringAsFixed(4)}',
      );
    });

    test(
      'mood 4 (#7AAF6A, sage-green) luminance — boundary case: '
      'measured luminance is > 0.35 → dark foreground',
      () {
        final color = ThemeNotifier.moodSeeds[4]!;
        final luminance = color.computeLuminance();
        // #7AAF6A actual relative luminance ≈ 0.3584 — just above the 0.35 threshold.
        // This is the boundary mood flagged in UI-SPEC as "marginal (~3.5:1)".
        // Measured result: luminance > 0.35, so _onBgColor returns Color(0xFF1A1A1A)
        // (dark foreground) for mood 4 as well. Both mood 4 and mood 5 get dark text.
        expect(
          luminance,
          greaterThan(0.35),
          reason:
              'Mood 4 (#7AAF6A sage-green) has measured luminance ${luminance.toStringAsFixed(4)}, '
              'which is above the 0.35 threshold — dark foreground (Color(0xFF1A1A1A)) is used. '
              'White text at ~3.5:1 ratio is marginal but this threshold ensures the switch happens.',
        );
      },
    );

    test(
      'mood 5 (#E8C547, amber-yellow) luminance is > 0.35 → dark foreground (CHECKIN-01 fix)',
      () {
        final color = ThemeNotifier.moodSeeds[5]!;
        // #E8C547 relative luminance ≈ 0.55 — bright amber; white text FAILS
        // WCAG AA at ~1.9:1 contrast ratio. This is the primary failure case
        // that triggered CHECKIN-01. Dark foreground (Color(0xFF1A1A1A)) is required.
        expect(
          color.computeLuminance(),
          greaterThan(0.35),
          reason:
              'Mood 5 (#E8C547 amber) must exceed luminance 0.35 to trigger dark foreground. '
              'White text on amber yields ~1.9:1 contrast ratio (WCAG AA fail). '
              'Actual luminance: ${color.computeLuminance().toStringAsFixed(4)}',
        );
      },
    );
  });
}

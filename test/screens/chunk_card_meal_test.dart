// Phase 37 (D-37-07): a meal's fill is FIXED (mood never colours the
// timeline, D-36-07) and visibly apart from every other card fill, including
// the calendar meeting's, in both brightnesses. Same measure and floor as
// `calendar meeting fill is visibly apart from every other card`.

import 'dart:math' as math;

import 'package:canopy/screens/schedule/widgets/chunk_card.dart';
import 'package:canopy/screens/today/schedule_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  double rgbDistance(Color a, Color b) => math.sqrt(
    math.pow((a.r - b.r) * 255, 2) +
        math.pow((a.g - b.g) * 255, 2) +
        math.pow((a.b - b.b) * 255, 2),
  );

  test('meal fill is visibly apart from every other card', () {
    const minDistance = 40.0;
    for (final brightness in Brightness.values) {
      final meal = mealFill(brightness);
      final scheme = scheduleColorScheme(brightness);
      final fills = {
        'meeting (calendarMeetingFill)': calendarMeetingFill(brightness),
        'commitment (tertiaryContainer)': scheme.tertiaryContainer,
        'work (surfaceContainerLowest)': scheme.surfaceContainerLowest,
        'break (secondaryContainer)': scheme.secondaryContainer,
        'primaryContainer': scheme.primaryContainer,
        'errorContainer': scheme.errorContainer,
        'surface': scheme.surface,
      };
      for (final f in fills.entries) {
        expect(
          rgbDistance(meal, f.value),
          greaterThanOrEqualTo(minDistance),
          reason: '$brightness: meal vs ${f.key}',
        );
      }
    }
  });

  test('text on the meal fill is readable (contrast >= 4.5)', () {
    double lum(Color c) => c.computeLuminance();
    for (final brightness in Brightness.values) {
      final a = lum(mealFill(brightness));
      final b = lum(onMealFill(brightness));
      final ratio = (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
      expect(ratio, greaterThanOrEqualTo(4.5), reason: '$brightness');
    }
  });
}

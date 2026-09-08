// Geometry pin for the restoratives quick-pick chip grid — Phase 34 Plan 02,
// Task 2.
//
// This test exists ONLY to catch a layout drift introduced by swapping
// `_QuickPickSection`'s private `Wrap`/`_buildChip` implementation for the
// shared `PresetChipGrid` (D-34-07/Decision 3). The tap-target geometry of
// this exact screen has been questioned five times across Phases 32-33 and
// closed UNMEASURED (34-CONTEXT.md, Deferred Ideas, Item 5) — a silent pixel
// drift here would reopen that question.
//
// The numbers below are BARE LITERALS, measured against the real,
// pre-refactor `RestorativesScreen` (the shipped `_QuickPickSection`, not the
// grid pumped alone inside a test-only `SizedBox` — CLAUDE.md, "Assertions
// that cannot fail", trap 2). They are deliberately NOT expressions over
// shared spacing constants: a symbolic bound moves with the code it's meant
// to catch drifting and therefore cannot fail. Measured 2026-09-08, before
// the `PresetChipGrid` refactor landed.
//
// If a future change moves any of these numbers, the fix belongs in the
// widget producing the new layout, not in this file's literals — bumping a
// literal to match a drifted rect defeats the entire reason this file exists.

import 'package:canopy/providers/restoratives_notifier.dart';
import 'package:canopy/data/repositories/in_memory_restorative_item_repository.dart';
import 'package:canopy/screens/restoratives/restoratives_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';
import '../test_helpers/viewport.dart';

Future<RestorativesNotifier> _pumpScreen(WidgetTester tester) async {
  final notifier = RestorativesNotifier(
    repository: InMemoryRestorativeItemRepository(),
  );
  await pumpWithMood(
    tester,
    const RestorativesScreen(),
    extraProviders: [
      ChangeNotifierProvider<RestorativesNotifier>.value(value: notifier),
    ],
  );
  await tester.pumpAndSettle();
  return notifier;
}

void main() {
  group('Restoratives quick-pick geometry pin (34-02 Task 2)', () {
    testWidgets(
      'the quick-pick grid geometry at 390x844 is pinned to pre-refactor '
      'measurements',
      (tester) async {
        setViewport(tester, const Size(390, 844));
        await _pumpScreen(tester);

        final firstChipRect = tester.getRect(
          find.widgetWithText(FilterChip, 'Walk outside'),
        );
        final lastChipRect = tester.getRect(
          find.widgetWithText(FilterChip, 'Sit in the sun'),
        );
        final wrapRect = tester.getRect(find.byType(Wrap).first);

        // Measured against the pre-refactor _QuickPickSection on 2026-09-08,
        // via a one-time debugPrint of tester.getRect(...) on the real
        // RestorativesScreen at 390x844 (removed once these literals were
        // recorded). Purpose: fail if the refactor to PresetChipGrid moves
        // anything.
        expect(firstChipRect.left, 16.0);
        expect(firstChipRect.top, 96.0);
        // .right values carry float rounding noise from text layout (e.g.
        // 239.1999969482422) — closeTo pins the pixel without being brittle
        // to that noise while still catching a real layout drift.
        expect(firstChipRect.right, closeTo(239.2, 0.01));
        expect(firstChipRect.bottom, 144.0);
        expect(lastChipRect.top, 376.0);
        expect(lastChipRect.bottom, 424.0);
        expect(wrapRect.left, 16.0);
        expect(wrapRect.top, 96.0);
        expect(wrapRect.right, closeTo(371.7, 0.01));
        expect(wrapRect.bottom, 424.0);
      },
    );
  });
}

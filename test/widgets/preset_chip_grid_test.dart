// Widget tests for the shared PresetChipGrid — Phase 34 Plan 02, Task 3.
//
// This is the widget three screens (Goals, onboarding's goals beat,
// onboarding's restoratives beat, and the restoratives screen) now render
// through, so its two modes and its one matching rule are tested directly
// here rather than only indirectly through each caller.
//
// Two finder rules from CLAUDE.md ("Assertions that cannot fail") and this
// repo's own history are followed throughout:
//   1. Never locate a SPECIFIC chip with a bare chip-type finder — scope by
//      label with `find.widgetWithText(FilterChip, name)`. A bare type finder
//      over-counts once more than one chip grid exists on a screen (e.g.
//      onboarding_screen.dart's unrelated day-of-week FilterChip row).
//   2. Where the assertion means "any chip subtype", use
//      `find.byWidgetPredicate((w) => w is FilterChip)` — a bare type finder
//      compares `runtimeType` exactly and would pass silently across a chip
//      family swap (the exact defect this phase's Decision 3 fixes).

import 'package:canopy/widgets/preset_chip_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/mood_pump.dart';

const _fixture = <(String, String)>[
  ('Reading', '📚'),
  ('Walk', '🚶'),
  ('Nap', '😴'),
];

void main() {
  group('PresetChipGrid (34-02 Task 3)', () {
    testWidgets(
      'createOnly: a claimed preset (trimmed, case-insensitive) does not '
      'render at all — not selected, not disabled',
      (tester) async {
        await pumpWithMood(
          tester,
          PresetChipGrid(
            presets: _fixture,
            existingNames: const ['  reading  '],
            mode: PresetChipMode.createOnly,
            onCreate: (_, _) {},
          ),
        );

        expect(find.widgetWithText(FilterChip, 'Reading'), findsNothing);
        expect(find.widgetWithText(FilterChip, 'Walk'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'Nap'), findsOneWidget);
      },
    );

    testWidgets(
      'createOnly: with every preset claimed, the widget renders nothing — '
      'no heading, no chips',
      (tester) async {
        await pumpWithMood(
          tester,
          PresetChipGrid(
            presets: _fixture,
            existingNames: _fixture.map((p) => p.$1),
            mode: PresetChipMode.createOnly,
            heading: 'Common',
            onCreate: (_, _) {},
          ),
        );

        expect(find.text('Common'), findsNothing);
        expect(find.byWidgetPredicate((w) => w is FilterChip), findsNothing);
      },
    );

    testWidgets(
      'createOnly: onRemove is never invoked — there is no gesture that can '
      'call it',
      (tester) async {
        var removeCalls = 0;
        await pumpWithMood(
          tester,
          PresetChipGrid(
            presets: _fixture,
            existingNames: const ['Reading'],
            mode: PresetChipMode.createOnly,
            onCreate: (_, _) {},
            onRemove: (_) => removeCalls++,
          ),
        );

        // Tap every remaining (unclaimed) chip — each is a create tap, never
        // a remove, because createOnly hides claimed presets outright.
        await tester.tap(find.widgetWithText(FilterChip, 'Walk'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilterChip, 'Nap'));
        await tester.pumpAndSettle();

        expect(removeCalls, 0);
      },
    );

    testWidgets(
      'toggle: a claimed preset still renders, selected == true, and '
      'tapping it invokes onRemove with that name',
      (tester) async {
        String? removedName;
        await pumpWithMood(
          tester,
          PresetChipGrid(
            presets: _fixture,
            existingNames: const ['Reading'],
            mode: PresetChipMode.toggle,
            onCreate: (_, _) {},
            onRemove: (name) => removedName = name,
          ),
        );

        final chip = find.widgetWithText(FilterChip, 'Reading');
        expect(chip, findsOneWidget);
        expect(tester.widget<FilterChip>(chip).selected, isTrue);

        await tester.tap(chip);
        await tester.pumpAndSettle();

        expect(removedName, 'Reading');
      },
    );

    testWidgets(
      'toggle: with every preset claimed, all chips still render (the grid '
      'never empties)',
      (tester) async {
        await pumpWithMood(
          tester,
          PresetChipGrid(
            presets: _fixture,
            existingNames: _fixture.map((p) => p.$1),
            mode: PresetChipMode.toggle,
            onCreate: (_, _) {},
            onRemove: (_) {},
          ),
        );

        expect(find.byWidgetPredicate((w) => w is FilterChip), findsNWidgets(3));
        for (final (name, _) in _fixture) {
          expect(
            tester.widget<FilterChip>(find.widgetWithText(FilterChip, name)).selected,
            isTrue,
          );
        }
      },
    );

    testWidgets(
      'createOnly: tapping an unclaimed chip invokes onCreate with the name '
      'AND the emoji',
      (tester) async {
        String? createdName;
        String? createdEmoji;
        await pumpWithMood(
          tester,
          PresetChipGrid(
            presets: _fixture,
            existingNames: const [],
            mode: PresetChipMode.createOnly,
            onCreate: (name, emoji) {
              createdName = name;
              createdEmoji = emoji;
            },
          ),
        );

        await tester.tap(find.widgetWithText(FilterChip, 'Reading'));
        await tester.pumpAndSettle();

        expect(createdName, 'Reading');
        expect(createdEmoji, '📚');
      },
    );

    testWidgets(
      'toggle: tapping an unclaimed chip invokes onCreate with the name AND '
      'the emoji',
      (tester) async {
        String? createdName;
        String? createdEmoji;
        await pumpWithMood(
          tester,
          PresetChipGrid(
            presets: _fixture,
            existingNames: const [],
            mode: PresetChipMode.toggle,
            onCreate: (name, emoji) {
              createdName = name;
              createdEmoji = emoji;
            },
            onRemove: (_) {},
          ),
        );

        await tester.tap(find.widgetWithText(FilterChip, 'Walk'));
        await tester.pumpAndSettle();

        expect(createdName, 'Walk');
        expect(createdEmoji, '🚶');
      },
    );

    testWidgets(
      'heading renders when given and is absent when null',
      (tester) async {
        await pumpWithMood(
          tester,
          PresetChipGrid(
            presets: _fixture,
            existingNames: const [],
            mode: PresetChipMode.createOnly,
            heading: 'Common',
            onCreate: (_, _) {},
          ),
        );
        expect(find.text('Common'), findsOneWidget);

        await pumpWithMood(
          tester,
          PresetChipGrid(
            presets: _fixture,
            existingNames: const [],
            mode: PresetChipMode.createOnly,
            onCreate: (_, _) {},
          ),
        );
        expect(find.text('Common'), findsNothing);
      },
    );

    testWidgets(
      'when the grid is empty in createOnly, the heading is absent too',
      (tester) async {
        await pumpWithMood(
          tester,
          PresetChipGrid(
            presets: _fixture,
            existingNames: _fixture.map((p) => p.$1),
            mode: PresetChipMode.createOnly,
            heading: 'Common',
            onCreate: (_, _) {},
          ),
        );

        expect(find.text('Common'), findsNothing);
      },
    );
  });
}

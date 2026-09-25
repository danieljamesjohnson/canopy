import 'package:canopy/data/calendar/calendar_event.dart';
import 'package:canopy/data/calendar/calendar_overlap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CalendarInfo google(
    String id, {
    required String name,
    String? accountName,
  }) => CalendarInfo(
    id: id,
    name: name,
    accountName: accountName,
    accountType: 'Google',
    isReadOnly: true,
    sourceLabel: 'Google',
  );

  CalendarInfo device(
    String id, {
    required String name,
    String? accountName,
  }) => CalendarInfo(
    id: id,
    name: name,
    accountName: accountName,
    isReadOnly: true,
    sourceLabel: 'This device',
  );

  group('detectSelectedCalendarOverlaps', () {
    test(
      'same account email, equal case-insensitive trimmed names, both '
      'ticked: reported',
      () {
        final g = google('google:a', name: 'Work', accountName: 'dan@gmail.com');
        final d = device('device-b', name: 'Work', accountName: 'dan@gmail.com');

        final result = detectSelectedCalendarOverlaps(
          calendars: [g, d],
          selectedIds: {g.id, d.id},
        );

        expect(result, hasLength(1));
        expect(result.single.google.name, 'Work');
        expect(result.single.google.accountName, 'dan@gmail.com');
        expect(result.single.device.name, 'Work');
        expect(result.single.device.accountName, 'dan@gmail.com');
      },
    );

    test('only one of the two ticked: not reported', () {
      final g = google('google:a', name: 'Work', accountName: 'dan@gmail.com');
      final d = device('device-b', name: 'Work', accountName: 'dan@gmail.com');

      final result = detectSelectedCalendarOverlaps(
        calendars: [g, d],
        selectedIds: {g.id}, // only the Google side ticked
      );

      expect(result, isEmpty);
    });

    test(
      'same account email, DIFFERENT display names, both ticked: not '
      'reported',
      () {
        final g = google('google:a', name: 'Work', accountName: 'dan@gmail.com');
        final d = device(
          'device-b',
          name: 'Personal',
          accountName: 'dan@gmail.com',
        );

        final result = detectSelectedCalendarOverlaps(
          calendars: [g, d],
          selectedIds: {g.id, d.id},
        );

        expect(result, isEmpty);
      },
    );

    test(
      'same display name, DIFFERENT account emails, both ticked: not '
      'reported',
      () {
        final g = google('google:a', name: 'Work', accountName: 'dan@gmail.com');
        final d = device(
          'device-b',
          name: 'Work',
          accountName: 'spouse@gmail.com',
        );

        final result = detectSelectedCalendarOverlaps(
          calendars: [g, d],
          selectedIds: {g.id, d.id},
        );

        expect(result, isEmpty);
      },
    );

    test(
      'two Google calendars ticked, no device calendar: not reported '
      '(overlap is a cross-source concept)',
      () {
        final g1 = google('google:a', name: 'Work', accountName: 'dan@gmail.com');
        final g2 = google('google:b', name: 'Work', accountName: 'dan@gmail.com');

        final result = detectSelectedCalendarOverlaps(
          calendars: [g1, g2],
          selectedIds: {g1.id, g2.id},
        );

        expect(result, isEmpty);
      },
    );

    test(
      'a device calendar with a null accountName ticked alongside a Google '
      'calendar: not reported, and never throws',
      () {
        final g = google('google:a', name: 'Work', accountName: 'dan@gmail.com');
        final d = device('device-b', name: 'Work', accountName: null);

        expect(
          () => detectSelectedCalendarOverlaps(
            calendars: [g, d],
            selectedIds: {g.id, d.id},
          ),
          returnsNormally,
        );
        final result = detectSelectedCalendarOverlaps(
          calendars: [g, d],
          selectedIds: {g.id, d.id},
        );
        expect(result, isEmpty);
      },
    );

    test(
      'names differing only by surrounding whitespace or case: reported '
      '(Work and work  are the same calendar to a human)',
      () {
        final g = google('google:a', name: 'Work', accountName: 'dan@gmail.com');
        final d = device(
          'device-b',
          name: '  work ',
          accountName: 'dan@gmail.com',
        );

        final result = detectSelectedCalendarOverlaps(
          calendars: [g, d],
          selectedIds: {g.id, d.id},
        );

        expect(result, hasLength(1));
      },
    );
  });

  group('hasCrossSourceSelection (the coarse fallback)', () {
    test(
      'true when at least one Google and one device calendar are both '
      'ticked, regardless of whether either pair actually matches',
      () {
        final g = google('google:a', name: 'Work', accountName: 'dan@gmail.com');
        final d = device(
          'device-b',
          name: 'Completely Unrelated',
          accountName: 'someone-else@gmail.com',
        );

        expect(
          hasCrossSourceSelection(calendars: [g, d], selectedIds: {g.id, d.id}),
          isTrue,
        );
      },
    );

    test('false when only the Google side is ticked', () {
      final g = google('google:a', name: 'Work', accountName: 'dan@gmail.com');
      final d = device('device-b', name: 'Work', accountName: 'dan@gmail.com');

      expect(
        hasCrossSourceSelection(calendars: [g, d], selectedIds: {g.id}),
        isFalse,
      );
    });

    test('false when only device calendars exist, none from Google', () {
      final d1 = device('device-a', name: 'Work', accountName: 'dan@gmail.com');
      final d2 = device(
        'device-b',
        name: 'Personal',
        accountName: 'dan@gmail.com',
      );

      expect(
        hasCrossSourceSelection(
          calendars: [d1, d2],
          selectedIds: {d1.id, d2.id},
        ),
        isFalse,
      );
    });
  });
}

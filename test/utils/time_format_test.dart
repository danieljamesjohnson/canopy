// Unit tests for the time-formatting helpers added in Phase 22 Plan 02:
// formatDurationShort (gutter/free-time duration copy) and
// formatMinutesCompact (46dp time-gutter label).

import 'package:canopy/utils/time_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatDurationShort', () {
    test('5 minutes gives "5m"', () {
      expect(formatDurationShort(5), '5m');
    });

    test('45 minutes gives "45m"', () {
      expect(formatDurationShort(45), '45m');
    });

    test('60 minutes gives "1h"', () {
      expect(formatDurationShort(60), '1h');
    });

    test('100 minutes gives "1h 40m"', () {
      expect(formatDurationShort(100), '1h 40m');
    });

    test('120 minutes gives "2h"', () {
      expect(formatDurationShort(120), '2h');
    });

    test('195 minutes gives "3h 15m"', () {
      expect(formatDurationShort(195), '3h 15m');
    });

    test('0 minutes gives "0m"', () {
      expect(formatDurationShort(0), '0m');
    });
  });

  group('formatMinutesCompact', () {
    test('480 gives "8:00"', () {
      expect(formatMinutesCompact(480), '8:00');
    });

    test('645 gives "10:45"', () {
      expect(formatMinutesCompact(645), '10:45');
    });

    test('780 gives "1:00p"', () {
      expect(formatMinutesCompact(780), '1:00p');
    });

    test('720 (noon) gives "12:00p"', () {
      expect(formatMinutesCompact(720), '12:00p');
    });

    test('0 (midnight) gives "12:00"', () {
      expect(formatMinutesCompact(0), '12:00');
    });

    test('1350 gives "10:30p"', () {
      expect(formatMinutesCompact(1350), '10:30p');
    });
  });

  group('floorToHour', () {
    // Note: 545 minutes = 9:05 AM, which floors to 9:00 AM (540), not 480
    // (8:00 AM) — the (minutes ~/ 60) * 60 formula this function implements
    // (26-PATTERNS.md's exact spec) is idempotent-and-monotonic by
    // construction, matching every other worked example in this file
    // (540 stays 540) and every downstream TimelineGeometry range assertion
    // in this plan's Task 2 (e.g. PreStart's floorToHour(390) == 360). The plan's
    // prose worked example ("545 → 480") is an isolated typo inconsistent
    // with its own formula; corrected here per Rule 1.
    test('545 rounds down to 540', () {
      expect(floorToHour(545), 540);
    });

    test('540 (already aligned) stays 540', () {
      expect(floorToHour(540), 540);
    });

    test('0 (midnight) stays 0', () {
      expect(floorToHour(0), 0);
    });

    test('1439 (end of day) rounds down to 1380', () {
      expect(floorToHour(1439), 1380);
    });
  });

  group('ceilToHour', () {
    test('545 rounds up to 600', () {
      expect(ceilToHour(545), 600);
    });

    test('540 (already aligned) stays 540', () {
      expect(ceilToHour(540), 540);
    });

    test('0 (midnight) stays 0', () {
      expect(ceilToHour(0), 0);
    });

    test('1439 (end of day) rounds up to 1440', () {
      expect(ceilToHour(1439), 1440);
    });
  });

  group('hourBoundariesIn', () {
    test('480 to 600 gives [480, 540, 600]', () {
      expect(hourBoundariesIn(480, 600), [480, 540, 600]);
    });

    test('non-hour-aligned start (495) gives [540, 600]', () {
      expect(hourBoundariesIn(495, 600), [540, 600]);
    });

    test('rangeEnd < rangeStart gives an empty list', () {
      expect(hourBoundariesIn(600, 480), isEmpty);
    });

    test('midnight range (0 to 60) gives [0, 60]', () {
      expect(hourBoundariesIn(0, 60), [0, 60]);
    });

    test('end-of-day range (1380 to 1439) gives [1380]', () {
      expect(hourBoundariesIn(1380, 1439), [1380]);
    });
  });

  group('formatHourLabel', () {
    test('540 gives "9 AM"', () {
      expect(formatHourLabel(540), '9 AM');
    });

    test('720 (noon) gives "12 PM"', () {
      expect(formatHourLabel(720), '12 PM');
    });

    test('0 (midnight) gives "12 AM"', () {
      expect(formatHourLabel(0), '12 AM');
    });

    test('1380 gives "11 PM"', () {
      expect(formatHourLabel(1380), '11 PM');
    });

    test('1439 (end of day, still within the 11 PM hour) gives "11 PM"', () {
      expect(formatHourLabel(1439), '11 PM');
    });
  });
}

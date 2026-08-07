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
}

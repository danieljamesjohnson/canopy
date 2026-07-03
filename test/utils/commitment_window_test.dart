import 'package:canopy/utils/commitment_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('commitmentWindowTooShort', () {
    test('normal daytime window is fine', () {
      expect(commitmentWindowTooShort(9 * 60, 17 * 60), isFalse);
    });

    test('exactly one chunk (25 min) is allowed', () {
      expect(commitmentWindowTooShort(600, 625), isFalse);
    });

    test('shorter than one chunk is rejected', () {
      expect(commitmentWindowTooShort(600, 624), isTrue);
    });

    test('zero-length window is rejected', () {
      expect(commitmentWindowTooShort(600, 600), isTrue);
    });

    test('inverted night-shift window (10pm–6am) is rejected', () {
      // 22:00 = 1320, 06:00 = 360 → negative span, would produce zero chunks.
      expect(commitmentWindowTooShort(22 * 60, 6 * 60), isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:canopy/dev/dev_clock.dart';

void main() {
  // Tests run in debug mode (kDebugMode is true under `flutter test`), so
  // DevClock's mutators are never gated off here — the release-mode no-op
  // guard is exercised implicitly by DEV-03 (there is no kReleaseMode test
  // harness available; the guard is a one-line `if (!kDebugMode) return`
  // reviewed by inspection).
  setUp(() {
    // Reset the in-memory offset before every test so tests don't leak state
    // into each other via DevClock's static fields.
    DevClock.resetForTest();
  });

  group('DevClock.now', () {
    test('equals real time (within tolerance) when no override is set', () {
      final before = DateTime.now();
      final now = DevClock.now();
      final after = DateTime.now();
      expect(DevClock.isActive, isFalse);
      expect(now.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(now.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });

  group('DevClock.setSimulatedNow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'makes now() return approximately target, and isActive is true',
      () async {
        final target = DateTime(2030, 1, 1, 9, 0, 0);
        await DevClock.setSimulatedNow(target);

        expect(DevClock.isActive, isTrue);
        final now = DevClock.now();
        expect(
          now.difference(target).inSeconds.abs() < 2,
          isTrue,
          reason: 'now() should read approximately target, got $now',
        );
      },
    );

    test('time still ADVANCES while overridden — two reads separated by a real '
        'delay differ by approximately that delay', () async {
      final target = DateTime(2030, 6, 15, 12, 0, 0);
      await DevClock.setSimulatedNow(target);

      final first = DevClock.now();
      // Real wall-clock delay — small but enough to observe advancement
      // without a flaky long sleep.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final second = DevClock.now();

      final elapsed = second.difference(first);
      expect(
        elapsed.inMilliseconds >= 200 && elapsed.inMilliseconds < 2000,
        isTrue,
        reason:
            'expected ~250ms of real elapsed time to be reflected in the '
            'offset clock, got ${elapsed.inMilliseconds}ms — a frozen '
            'clock would report 0ms here',
      );
    });
  });

  group('DevClock.clear', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('restores real time and isActive is false', () async {
      await DevClock.setSimulatedNow(DateTime(2030, 1, 1));
      expect(DevClock.isActive, isTrue);

      await DevClock.clear();

      expect(DevClock.isActive, isFalse);
      final before = DateTime.now();
      final now = DevClock.now();
      final after = DateTime.now();
      expect(now.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(now.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });

  group('DevClock.shift', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('composes with an existing offset', () async {
      final target = DateTime(2030, 3, 10, 8, 0, 0);
      await DevClock.setSimulatedNow(target);

      await DevClock.shift(const Duration(hours: 1));

      final now = DevClock.now();
      final expected = target.add(const Duration(hours: 1));
      expect(
        now.difference(expected).inSeconds.abs() < 2,
        isTrue,
        reason: 'shift() should compose with the existing offset, got $now',
      );
    });

    test('shift is cumulative across multiple calls', () async {
      final target = DateTime(2030, 3, 10, 8, 0, 0);
      await DevClock.setSimulatedNow(target);

      await DevClock.shift(const Duration(hours: -1));
      await DevClock.shift(const Duration(hours: -1));

      final now = DevClock.now();
      final expected = target.subtract(const Duration(hours: 2));
      expect(now.difference(expected).inSeconds.abs() < 2, isTrue);
    });
  });

  group('DevClock persistence', () {
    test('an offset set, then init() called again, restores it', () async {
      SharedPreferences.setMockInitialValues({});

      final target = DateTime(2030, 9, 20, 15, 30, 0);
      await DevClock.setSimulatedNow(target);
      expect(DevClock.isActive, isTrue);

      // Simulate a fresh app launch: reset the in-memory offset (as if the
      // static class were freshly loaded) WITHOUT touching the persisted
      // SharedPreferences value, then re-run init() to reload it.
      DevClock.resetForTest();
      expect(DevClock.isActive, isFalse);

      await DevClock.init();

      expect(DevClock.isActive, isTrue);
      final now = DevClock.now();
      expect(now.difference(target).inSeconds.abs() < 2, isTrue);
    });

    test('clear() removes the persisted offset so init() stays off', () async {
      SharedPreferences.setMockInitialValues({});

      await DevClock.setSimulatedNow(DateTime(2030, 1, 1));
      await DevClock.clear();
      DevClock.resetForTest();

      await DevClock.init();

      expect(DevClock.isActive, isFalse);
    });
  });
}

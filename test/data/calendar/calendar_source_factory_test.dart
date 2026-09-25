import 'package:canopy/data/calendar/calendar_source_factory.dart';
import 'package:canopy/data/calendar/composite_calendar_source.dart';
import 'package:canopy/data/calendar/device_calendar_source.dart';
import 'package:canopy/data/calendar/google_auth_client.dart';
import 'package:canopy/data/calendar/google_calendar_source.dart';
import 'package:canopy/data/calendar/ics_calendar_source.dart';
import 'package:canopy/data/calendar/null_calendar_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// Throwaway in-test [GoogleTokenStore] double — mirrors
/// `google_auth_client_test.dart`'s own in-memory fake. Never touches Hive.
class _FakeGoogleTokenStore implements GoogleTokenStore {
  GoogleTokens? _tokens;
  bool _reconnectNeeded = false;

  @override
  Future<GoogleTokens?> read() async => _tokens;

  @override
  Future<void> write(GoogleTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;

  @override
  Future<void> setReconnectNeeded(bool value) async =>
      _reconnectNeeded = value;

  @override
  bool get reconnectNeeded => _reconnectNeeded;
}

void main() {
  group(
    'iosCalendarSource — D-36-03\'s carve-out for iOS, factored out of the '
    'real Platform.isIOS check for testability (see the function\'s own '
    'doc comment)',
    () {
      test(
        'with a Google auth client supplied, returns a composite whose '
        'children are the Google source then the device source, in that '
        'order',
        () {
          final client = GoogleAuthClient(store: _FakeGoogleTokenStore());

          final source = iosCalendarSource(googleAuth: client);

          expect(source, isA<CompositeCalendarSource>());
          final composite = source as CompositeCalendarSource;
          expect(composite.children, hasLength(2));
          expect(composite.children[0], isA<GoogleCalendarSource>());
          expect(composite.children[1], isA<DeviceCalendarSource>());
        },
      );

      test(
        'with no client supplied — every test, and any caller that has not '
        'opted in — returns the device source alone',
        () {
          final source = iosCalendarSource();

          expect(source, isA<DeviceCalendarSource>());
        },
      );

      test(
        'accepts googleCalendarIds without changing the composite '
        'structure (WINDOWS.md entry 5) — the ids only affect what '
        'GoogleCalendarSource.listEvents queries internally, which '
        'google_calendar_source_test.dart already proves given this exact '
        'constructor parameter; this factory\'s only job is to pass the '
        'value through unchanged',
        () {
          final client = GoogleAuthClient(store: _FakeGoogleTokenStore());

          final source = iosCalendarSource(
            googleAuth: client,
            googleCalendarIds: const ['google:dan@example.com'],
          );

          expect(source, isA<CompositeCalendarSource>());
          final composite = source as CompositeCalendarSource;
          expect(composite.children[0], isA<GoogleCalendarSource>());
          expect(composite.children[1], isA<DeviceCalendarSource>());
        },
      );
    },
  );

  group(
    'defaultCalendarSource — non-iOS platforms are untouched by the new '
    'googleAuth parameter (D-36-03: every other platform keeps D-35-12\'s '
    'original rule)',
    () {
      test(
        'returns NullCalendarSource when no feed URLs are configured, even '
        'with a Google auth client supplied (Platform.isIOS is false on '
        'this test platform)',
        () {
          final client = GoogleAuthClient(store: _FakeGoogleTokenStore());

          final source = defaultCalendarSource(googleAuth: client);

          expect(source, isA<NullCalendarSource>());
        },
      );

      test(
        'still returns IcsCalendarSource on this (desktop) test platform '
        'when a feed URL is configured, regardless of googleAuth',
        () {
          final client = GoogleAuthClient(store: _FakeGoogleTokenStore());

          final source = defaultCalendarSource(
            icsUrls: const ['https://example.com/a.ics'],
            googleAuth: client,
          );

          expect(source, isA<IcsCalendarSource>());
        },
      );
    },
  );
}

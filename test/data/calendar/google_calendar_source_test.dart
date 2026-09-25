// The tracer's proof: drive the WHOLE Google path in one test — a fake
// consent launcher returns a token, the token lands in a fake
// GoogleTokenStore, and a fake http.Client returns Google's own
// `events.list` JSON shape, all the way through the EXISTING
// CalendarSyncService into one CommitmentBlock. No native sheet, no
// network, no device.
//
// Throwaway doubles live in this file, not lib/ — the house pattern stated
// in calendar_settings_screen_test.dart's own header.

import 'dart:convert';
import 'dart:io';

import 'package:canopy/data/calendar/google_auth_client.dart';
import 'package:canopy/data/calendar/google_calendar_source.dart';
import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/repositories/commitment_block_repository.dart';
import 'package:canopy/services/calendar_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as gauth;
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// In-memory GoogleTokenStore double — mirrors SettingsNotifier's shape
/// without touching Hive.
class _FakeGoogleTokenStore implements GoogleTokenStore {
  GoogleTokens? _tokens;
  bool _reconnectNeeded = false;

  @override
  Future<GoogleTokens?> read() async => _tokens;

  @override
  Future<void> write(GoogleTokens tokens) async {
    _tokens = tokens;
  }

  @override
  Future<void> clear() async {
    _tokens = null;
  }

  @override
  Future<void> setReconnectNeeded(bool value) async {
    _reconnectNeeded = value;
  }

  @override
  bool get reconnectNeeded => _reconnectNeeded;
}

/// In-memory CommitmentBlockRepository double — mirrors
/// test/services/calendar_sync_service_test.dart's own shape exactly.
class InMemoryCommitmentBlockRepository implements CommitmentBlockRepository {
  final Map<String, CommitmentBlock> _store = {};

  @override
  Future<List<CommitmentBlock>> getAll() async => _store.values.toList();

  @override
  Future<CommitmentBlock?> getById(String id) async => _store[id];

  @override
  Future<void> save(CommitmentBlock block) async => _store[block.id] = block;

  @override
  Future<void> delete(String id) async => _store.remove(id);

  @override
  Future<List<CommitmentBlock>> getByDayOfWeek(int day) async =>
      _store.values.where((b) => b.daysOfWeek.contains(day)).toList();
}

/// An http.Client double returning a fixed JSON body for every request —
/// enough to fake Google's `events.list` response with no network at all.
class _FixtureHttpClient extends http.BaseClient {
  _FixtureHttpClient(this._body);

  final String _body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(_body);
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

Future<String> _fixture(String name) =>
    File('test/fixtures/calendar/$name').readAsString();

void main() {
  tzdata.initializeTimeZones();

  tearDown(() {
    // Never leak a non-UTC tz.local override into later tests in the suite.
    tz.setLocalLocation(tz.UTC);
  });

  test(
    'a canned Google token persists to the store, and a canned events.list '
    'response becomes one CommitmentBlock through the unchanged '
    'CalendarSyncService (tracer, CALAUTH-01/02)',
    () async {
      tz.setLocalLocation(tz.UTC);

      final store = _FakeGoogleTokenStore();
      final authClient = GoogleAuthClient(
        store: store,
        // Synthetic — matches Google's real client-id shape only so
        // reverseGoogleClientId() (called internally by connect()) doesn't
        // throw. Never a real client id (see CLAUDE.md / plan 36-04's
        // CALAUTH-04 gate).
        clientId: '000000000000-synthtestidvalue.apps.googleusercontent.com',
        launcher:
            ({
              required String clientId,
              required String redirectUri,
              required List<String> scopes,
            }) async => GoogleTokens(
              accessToken: 'fake-access-token',
              refreshToken: 'fake-refresh-token',
              expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
            ),
      );

      // 1. The consent round trip, faked end to end.
      final cancelled = await authClient.connect();
      expect(cancelled, isFalse);

      // 2. The token landed in the store (survives-restart proxy — the
      // store IS the persistence boundary; SettingsNotifier is the
      // production implementation backed by Hive).
      final storedTokens = await store.read();
      expect(storedTokens, isNotNull);
      expect(storedTokens!.accessToken, equals('fake-access-token'));
      expect(storedTokens.refreshToken, equals('fake-refresh-token'));

      // 3. A canned Google events.list response, in Google's real shape.
      final fixtureJson = await _fixture('google_events_list_basic.json');
      final source = GoogleCalendarSource(
        authClient: authClient,
        calendarIds: const ['google:dan@example.com'],
        apiClientFactory: () async => _FixtureHttpClient(fixtureJson),
      );

      final repo = InMemoryCommitmentBlockRepository();
      final syncedAt = DateTime.utc(2026, 3, 1);
      final service = CalendarSyncService(
        source: source,
        repository: repo,
        now: () => syncedAt,
      );

      // 4. The whole path, through the EXISTING (unmodified) sync service.
      final result = await service.sync();

      expect(result.failed, isFalse);
      expect(result.imported, hasLength(1));
      final block = result.imported.single;
      expect(block.name, equals('Team standup'));
      expect(block.isFromCalendar, isTrue);
      expect(block.externalEventId, isNotEmpty);
      // Fixture event is 14:00-14:25 UTC; tz.local is UTC in this test, so
      // local wall-clock minutes equal the UTC clock reading.
      expect(block.startMinutes, equals(14 * 60));
      expect(block.endMinutes, equals(14 * 60 + 25));
    },
  );

  test(
    'authenticatedClient() refreshes an expired access token via the '
    'injected refresher and persists the result (Assumption A6)',
    () async {
      final store = _FakeGoogleTokenStore();
      await store.write(
        GoogleTokens(
          accessToken: 'stale-access-token',
          refreshToken: 'still-good-refresh-token',
          expiresAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 5),
          ),
        ),
      );

      var refresherCalled = false;
      final authClient = GoogleAuthClient(
        store: store,
        clientId: '000000000000-synthtestidvalue.apps.googleusercontent.com',
        refresher: (clientId, credentials, client) async {
          refresherCalled = true;
          // A null secret must reach here unchanged (Assumption A6 — Google
          // never requires one for an installed/iOS client).
          expect(clientId.secret, isNull);
          expect(credentials.refreshToken, equals('still-good-refresh-token'));
          return gauth.AccessCredentials(
            gauth.AccessToken(
              'Bearer',
              'refreshed-access-token',
              DateTime.now().toUtc().add(const Duration(hours: 1)),
            ),
            'still-good-refresh-token',
            const [],
          );
        },
      );

      final client = await authClient.authenticatedClient();
      client.close();

      expect(refresherCalled, isTrue);
      final persisted = await store.read();
      expect(persisted!.accessToken, equals('refreshed-access-token'));
      expect(persisted.refreshToken, equals('still-good-refresh-token'));
    },
  );
}

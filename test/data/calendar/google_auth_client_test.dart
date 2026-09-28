// CALAUTH-03's whole subject: telling apart three genuinely different
// failure shapes at the refresh boundary (a dead refresh token, a network
// hiccup, and a malformed-but-not-dead 400), plus the cancellation and
// lifecycle contracts around them. Every test here drives `GoogleAuthClient`
// through its injected `GoogleCredentialsRefresher`/`GoogleAuthLauncher`
// seams and a throwaway in-test `GoogleTokenStore` double — no network, no
// native sheet, no device (RESEARCH Pitfall 5).
//
// Throwaway doubles live in this file, not lib/ — the house pattern stated
// in calendar_settings_screen_test.dart's own header and already followed by
// google_calendar_source_test.dart.

import 'dart:convert';
import 'dart:io';

import 'package:canopy/data/calendar/google_auth_client.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as gauth;

/// In-memory GoogleTokenStore double — mirrors SettingsNotifier's shape
/// without touching Hive. Records every `setReconnectNeeded` call, in
/// order, so a test can assert not just the final flag value but that NO
/// write happened at all (the "untouched" behaviors this plan's whole
/// discrimination rests on).
class _FakeGoogleTokenStore implements GoogleTokenStore {
  _FakeGoogleTokenStore({
    GoogleTokens? initialTokens,
    bool initialReconnectNeeded = false,
  }) : _tokens = initialTokens,
       _reconnectNeeded = initialReconnectNeeded;

  GoogleTokens? _tokens;
  bool _reconnectNeeded;

  final List<bool> reconnectNeededWrites = [];

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
    reconnectNeededWrites.add(value);
  }

  @override
  bool get reconnectNeeded => _reconnectNeeded;
}

Future<String> _fixture(String name) =>
    File('test/fixtures/calendar/$name').readAsString();

/// Synthetic — matches Google's real client-id shape only so
/// reverseGoogleClientId() (called internally by connect()) doesn't throw.
/// Never a real client id (CLAUDE.md / plan 36-04's CALAUTH-04 gate).
const _testClientId = '000000000000-synthtestidvalue.apps.googleusercontent.com';

GoogleTokens _staleTokens({String refreshToken = 'still-good-refresh-token'}) =>
    GoogleTokens(
      accessToken: 'stale-access-token',
      refreshToken: refreshToken,
      expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
    );

GoogleTokens _validTokens() => GoogleTokens(
  accessToken: 'still-valid-access-token',
  refreshToken: 'irrelevant-refresh-token',
  expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
);

void main() {
  group('Task 1 — three failures, three different answers', () {
    test(
      'refresh succeeds: new tokens persisted, reconnect flag cleared, no exception',
      () async {
        // Starts TRUE to prove a success clears a pre-existing flag too
        // (also covered directly by Task 3, kept here for Task 1's own
        // "no exception" behavior).
        final store = _FakeGoogleTokenStore(
          initialTokens: _staleTokens(),
          initialReconnectNeeded: true,
        );
        final authClient = GoogleAuthClient(
          store: store,
          clientId: _testClientId,
          refresher: (clientId, credentials, client) async {
            final body =
                jsonDecode(await _fixture('google_token_refresh_ok.json'))
                    as Map<String, dynamic>;
            return gauth.AccessCredentials(
              gauth.AccessToken(
                'Bearer',
                body['access_token'] as String,
                DateTime.now().toUtc().add(
                  Duration(seconds: body['expires_in'] as int),
                ),
              ),
              credentials.refreshToken,
              const [],
            );
          },
        );

        final client = await authClient.authenticatedClient();
        client.close();

        expect(store.reconnectNeeded, isFalse);
        final persisted = await store.read();
        expect(
          persisted!.accessToken,
          equals('ya29.SYNTHETIC-test-only-refreshed-access-token'),
        );
      },
    );

    test(
      'refresh fails with 400 invalid_grant: reconnect flag set true, '
      'stored tokens left in place, GoogleAuthException thrown',
      () async {
        final store = _FakeGoogleTokenStore(initialTokens: _staleTokens());
        final authClient = GoogleAuthClient(
          store: store,
          clientId: _testClientId,
          refresher: (clientId, credentials, client) async {
            final body =
                jsonDecode(await _fixture('google_invalid_grant.json'))
                    as Map<String, dynamic>;
            throw gauth.ServerRequestFailedException(
              'Failed to obtain access credentials.',
              statusCode: 400,
              responseContent: body,
            );
          },
        );

        await expectLater(
          authClient.authenticatedClient(),
          throwsA(isA<GoogleAuthException>()),
        );

        expect(store.reconnectNeeded, isTrue);
        // Last-known calendars must keep rendering — the token is NOT wiped.
        final stillStored = await store.read();
        expect(stillStored!.accessToken, equals('stale-access-token'));
      },
    );

    test(
      'refresh fails with a socket/timeout error: GoogleAuthException '
      'thrown, reconnect flag NOT touched',
      () async {
        final store = _FakeGoogleTokenStore(initialTokens: _staleTokens());
        final authClient = GoogleAuthClient(
          store: store,
          clientId: _testClientId,
          refresher: (clientId, credentials, client) async {
            throw const SocketException('Network is unreachable');
          },
        );

        await expectLater(
          authClient.authenticatedClient(),
          throwsA(isA<GoogleAuthException>()),
        );

        expect(store.reconnectNeeded, isFalse);
        expect(store.reconnectNeededWrites, isEmpty);
      },
    );

    test(
      'refresh fails with statusCode 503: GoogleAuthException thrown, '
      'reconnect flag NOT touched',
      () async {
        final store = _FakeGoogleTokenStore(initialTokens: _staleTokens());
        final authClient = GoogleAuthClient(
          store: store,
          clientId: _testClientId,
          refresher: (clientId, credentials, client) async {
            throw gauth.ServerRequestFailedException(
              'Failed to obtain access credentials.',
              statusCode: 503,
              responseContent: {'error': 'internal_error'},
            );
          },
        );

        await expectLater(
          authClient.authenticatedClient(),
          throwsA(isA<GoogleAuthException>()),
        );

        expect(store.reconnectNeeded, isFalse);
        expect(store.reconnectNeededWrites, isEmpty);
      },
    );

    test(
      'refresh fails with statusCode 400 but a body that does NOT name '
      'invalid_grant: flag is NOT set (a bare status-code check is not the '
      'requirement)',
      () async {
        final store = _FakeGoogleTokenStore(initialTokens: _staleTokens());
        final authClient = GoogleAuthClient(
          store: store,
          clientId: _testClientId,
          refresher: (clientId, credentials, client) async {
            throw gauth.ServerRequestFailedException(
              'Failed to obtain access credentials.',
              statusCode: 400,
              responseContent: {
                'error': 'invalid_request',
                'error_description':
                    'Missing required parameter: refresh_token',
              },
            );
          },
        );

        await expectLater(
          authClient.authenticatedClient(),
          throwsA(isA<GoogleAuthException>()),
        );

        expect(store.reconnectNeeded, isFalse);
        expect(store.reconnectNeededWrites, isEmpty);
      },
    );

    test(
      'an access token that has not expired is used as-is: the refresher '
      'seam is never called at all',
      () async {
        var refresherCalled = false;
        final store = _FakeGoogleTokenStore(initialTokens: _validTokens());
        final authClient = GoogleAuthClient(
          store: store,
          clientId: _testClientId,
          refresher: (clientId, credentials, client) async {
            refresherCalled = true;
            throw StateError('should never be called');
          },
        );

        final client = await authClient.authenticatedClient();
        client.close();

        expect(refresherCalled, isFalse);
      },
    );

    test(
      'WR-04: an access token expiring in 15 seconds (inside the 30s '
      'safety margin) triggers a proactive refresh rather than being '
      'raced — the token is technically still valid right now, but must '
      "not be handed to the caller as though it'll stay valid long enough "
      'to actually reach Google',
      () async {
        var refresherCalled = false;
        final store = _FakeGoogleTokenStore(
          initialTokens: GoogleTokens(
            accessToken: 'about-to-expire-access-token',
            refreshToken: 'still-good-refresh-token',
            expiresAt: DateTime.now().toUtc().add(const Duration(seconds: 15)),
          ),
        );
        final authClient = GoogleAuthClient(
          store: store,
          clientId: _testClientId,
          refresher: (clientId, credentials, client) async {
            refresherCalled = true;
            return gauth.AccessCredentials(
              gauth.AccessToken(
                'Bearer',
                'refreshed-access-token',
                DateTime.now().toUtc().add(const Duration(hours: 1)),
              ),
              credentials.refreshToken,
              const [],
            );
          },
        );

        final client = await authClient.authenticatedClient();
        client.close();

        expect(refresherCalled, isTrue);
        final persisted = await store.read();
        expect(persisted!.accessToken, equals('refreshed-access-token'));
      },
    );
  });

  group('Task 2 — backing out of the consent sheet is a state, not an error', () {
    test(
      'launcher returns null: connect() reports cancelled, writes nothing, '
      'does not set the reconnect flag, does not throw',
      () async {
        final store = _FakeGoogleTokenStore();
        final authClient = GoogleAuthClient(
          store: store,
          clientId: _testClientId,
          launcher:
              ({
                required String clientId,
                required String redirectUri,
                required List<String> scopes,
              }) async => null,
        );

        final cancelled = await authClient.connect();

        expect(cancelled, isTrue);
        expect(await store.read(), isNull);
        expect(store.reconnectNeededWrites, isEmpty);
      },
    );

    test(
      'launcher returns null when a previous connection already exists: '
      'the existing tokens are still there afterwards, untouched',
      () async {
        final store = _FakeGoogleTokenStore(
          initialTokens: _validTokens(),
          initialReconnectNeeded: true,
        );
        final authClient = GoogleAuthClient(
          store: store,
          clientId: _testClientId,
          launcher:
              ({
                required String clientId,
                required String redirectUri,
                required List<String> scopes,
              }) async => null,
        );

        final cancelled = await authClient.connect();

        expect(cancelled, isTrue);
        final stillThere = await store.read();
        expect(
          stillThere!.accessToken,
          equals(_validTokens().accessToken),
        );
        // Cancelling a re-consent must not pretend the problem is fixed.
        expect(store.reconnectNeeded, isTrue);
        expect(store.reconnectNeededWrites, isEmpty);
      },
    );

    test(
      'launcher throws a genuine failure: connect() throws '
      'GoogleAuthException and still writes nothing',
      () async {
        final store = _FakeGoogleTokenStore();
        final authClient = GoogleAuthClient(
          store: store,
          clientId: _testClientId,
          launcher:
              ({
                required String clientId,
                required String redirectUri,
                required List<String> scopes,
              }) async {
                throw GoogleAuthException('Google sign-in failed');
              },
        );

        await expectLater(
          authClient.connect(),
          throwsA(isA<GoogleAuthException>()),
        );
        expect(await store.read(), isNull);
        expect(store.reconnectNeededWrites, isEmpty);
      },
    );

    test(
      'launcher returns tokens: they are persisted and the reconnect flag '
      'is cleared',
      () async {
        final store = _FakeGoogleTokenStore(initialReconnectNeeded: true);
        final authClient = GoogleAuthClient(
          store: store,
          clientId: _testClientId,
          launcher:
              ({
                required String clientId,
                required String redirectUri,
                required List<String> scopes,
              }) async => GoogleTokens(
                accessToken: 'new-access-token',
                refreshToken: 'new-refresh-token',
                expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
              ),
        );

        final cancelled = await authClient.connect();

        expect(cancelled, isFalse);
        expect(store.reconnectNeeded, isFalse);
        final persisted = await store.read();
        expect(persisted!.accessToken, equals('new-access-token'));
      },
    );
  });

  group('Task 2 — translateGoogleLauncherError (package boundary translation)', () {
    test(
      'a real FlutterAppAuthUserCancelledException translates to null '
      '(constructible in a host test — Assumption A7, translation proven '
      'here, not merely asserted)',
      () {
        final cancelled = FlutterAppAuthUserCancelledException(
          code: 'test-cancelled',
          platformErrorDetails: FlutterAppAuthPlatformErrorDetails(),
        );

        expect(translateGoogleLauncherError(cancelled), isNull);
      },
    );

    test(
      'a plain, unrelated exception translates to a GoogleAuthException '
      '(the catch stays narrow — this is NOT treated as a cancellation)',
      () {
        final translated = translateGoogleLauncherError(Exception('boom'));

        expect(translated, isA<GoogleAuthException>());
      },
    );
  });

  group('Task 3 — the reconnect state clears when the reconnect works', () {
    test(
      'flag set, then a successful connect(): flag is false afterwards, '
      'new tokens persisted',
      () async {
        final store = _FakeGoogleTokenStore(initialReconnectNeeded: true);
        final authClient = GoogleAuthClient(
          store: store,
          clientId: _testClientId,
          launcher:
              ({
                required String clientId,
                required String redirectUri,
                required List<String> scopes,
              }) async => GoogleTokens(
                accessToken: 'fresh-access-token',
                refreshToken: 'fresh-refresh-token',
                expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
              ),
        );

        await authClient.connect();

        expect(store.reconnectNeeded, isFalse);
        final persisted = await store.read();
        expect(persisted!.accessToken, equals('fresh-access-token'));
      },
    );

    test('flag set, then a successful refresh: flag is false afterwards', () async {
      final store = _FakeGoogleTokenStore(
        initialTokens: _staleTokens(),
        initialReconnectNeeded: true,
      );
      final authClient = GoogleAuthClient(
        store: store,
        clientId: _testClientId,
        refresher: (clientId, credentials, client) async => gauth.AccessCredentials(
          gauth.AccessToken(
            'Bearer',
            'refreshed-access-token',
            DateTime.now().toUtc().add(const Duration(hours: 1)),
          ),
          credentials.refreshToken,
          const [],
        ),
      );

      final client = await authClient.authenticatedClient();
      client.close();

      expect(store.reconnectNeeded, isFalse);
    });

    test(
      'flag set, then a refresh that fails on the network: flag is still '
      'TRUE afterwards',
      () async {
        final store = _FakeGoogleTokenStore(
          initialTokens: _staleTokens(),
          initialReconnectNeeded: true,
        );
        final authClient = GoogleAuthClient(
          store: store,
          clientId: _testClientId,
          refresher: (clientId, credentials, client) async {
            throw const SocketException('Network is unreachable');
          },
        );

        await expectLater(
          authClient.authenticatedClient(),
          throwsA(isA<GoogleAuthException>()),
        );

        expect(store.reconnectNeeded, isTrue);
        expect(store.reconnectNeededWrites, isEmpty);
      },
    );

    test(
      'flag set, then a cancelled connect(): flag is still TRUE afterwards '
      '(backing out does not pretend the problem is solved)',
      () async {
        final store = _FakeGoogleTokenStore(
          initialTokens: _validTokens(),
          initialReconnectNeeded: true,
        );
        final authClient = GoogleAuthClient(
          store: store,
          clientId: _testClientId,
          launcher:
              ({
                required String clientId,
                required String redirectUri,
                required List<String> scopes,
              }) async => null,
        );

        final cancelled = await authClient.connect();

        expect(cancelled, isTrue);
        expect(store.reconnectNeeded, isTrue);
      },
    );

    test(
      'flag set, then disconnect(): flag is false and tokens are gone',
      () async {
        final store = _FakeGoogleTokenStore(
          initialTokens: _validTokens(),
          initialReconnectNeeded: true,
        );
        final authClient = GoogleAuthClient(store: store, clientId: _testClientId);

        await authClient.disconnect();

        expect(store.reconnectNeeded, isFalse);
        expect(await store.read(), isNull);
      },
    );
  });
}

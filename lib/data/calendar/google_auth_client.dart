import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as gauth;
import 'package:http/http.dart' as http;

import 'google_oauth_config.dart';

/// A minimal, plain-Dart token bundle. [GoogleTokenStore] implementations
/// only ever see this shape, never `googleapis_auth`'s own
/// [gauth.AccessCredentials] — that conversion happens entirely inside
/// [GoogleAuthClient], so the Hive-backed store doesn't need to know
/// anything about the auth package's types.
class GoogleTokens {
  GoogleTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
}

/// Where [GoogleTokens] persist across app restarts (CALAUTH-01/02), and
/// where the "needs reconnect" flag (CALAUTH-03) lives. `SettingsNotifier`
/// is the production implementation (`AppSettings` HiveFields 12-15); tests
/// supply an in-memory throwaway double, keeping every test in this phase
/// off Hive.
abstract class GoogleTokenStore {
  Future<GoogleTokens?> read();
  Future<void> write(GoogleTokens tokens);
  Future<void> clear();
  Future<void> setReconnectNeeded(bool value);
  bool get reconnectNeeded;
}

/// Runs the interactive Google consent flow and returns the resulting
/// tokens, or `null` if the user cancelled — a cancellation is a real state
/// (RESEARCH Anti-Patterns), not an error to swallow. The production
/// implementation (below) is the only place in `lib/` that imports
/// `package:flutter_appauth`; a test supplies a fake that returns a canned
/// result with no native sheet involved — the single most load-bearing
/// pattern for keeping this phase's tests runnable on danserver.
typedef GoogleAuthLauncher =
    Future<GoogleTokens?> Function({
      required String clientId,
      required String redirectUri,
      required List<String> scopes,
    });

/// Seam over `googleapis_auth`'s `refreshCredentials` — same three
/// arguments that free function takes, so the production implementation is
/// a one-line forward and a test can supply a fake that never touches the
/// network.
typedef GoogleCredentialsRefresher =
    Future<gauth.AccessCredentials> Function(
      gauth.ClientId clientId,
      gauth.AccessCredentials credentials,
      http.Client client,
    );

/// Raised by [GoogleAuthClient] for any failure other than the user
/// cancelling the consent flow. Same one-field shape as `IcsSourceException`
/// — deliberately carries no token material in its message.
class GoogleAuthException implements Exception {
  GoogleAuthException(this.message);

  final String message;

  @override
  String toString() => 'GoogleAuthException: $message';
}

/// Production [GoogleAuthLauncher] — the only place in `lib/` that imports
/// `package:flutter_appauth`.
///
/// `access_type`/`prompt` are passed via `additionalParameters` (Assumption
/// A8, confirmed against the installed flutter_appauth 12.1.0 source:
/// `AuthorizationTokenRequest` accepts `additionalParameters` as a
/// `Map<String, String>?`, forwarded to the token endpoint) — this is what
/// makes Google issue a durable refresh token for an installed app rather
/// than an access-token-only grant.
Future<GoogleTokens?> _defaultLauncher({
  required String clientId,
  required String redirectUri,
  required List<String> scopes,
}) async {
  const appAuth = FlutterAppAuth();
  final AuthorizationTokenResponse result;
  try {
    result = await appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        clientId,
        redirectUri,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint:
              'https://accounts.google.com/o/oauth2/v2/auth',
          tokenEndpoint: 'https://oauth2.googleapis.com/token',
        ),
        scopes: scopes,
        additionalParameters: const {
          'access_type': 'offline',
          'prompt': 'consent',
        },
      ),
    );
  } on FlutterAppAuthUserCancelledException {
    return null; // a real state, not an error to swallow.
  } catch (_) {
    throw GoogleAuthException('Google sign-in failed');
  }
  final accessToken = result.accessToken;
  final expiresAt = result.accessTokenExpirationDateTime;
  if (accessToken == null || expiresAt == null) {
    throw GoogleAuthException('Google sign-in returned no access token');
  }
  return GoogleTokens(
    accessToken: accessToken,
    refreshToken: result.refreshToken,
    expiresAt: expiresAt,
  );
}

Future<gauth.AccessCredentials> _defaultRefresher(
  gauth.ClientId clientId,
  gauth.AccessCredentials credentials,
  http.Client client,
) => gauth.refreshCredentials(clientId, credentials, client);

/// Owns the Google token lifecycle: launching consent, persisting the
/// result, silently refreshing an expired access token, and handing back an
/// authenticated HTTP client for the Calendar API.
///
/// This task implements only the success and cancellation paths plus one
/// generic failure branch. The three-way failure classification CALAUTH-03
/// actually requires (distinguishing "reconnect needed" from an ordinary
/// network hiccup) is plan 36-02's whole subject.
class GoogleAuthClient {
  GoogleAuthClient({
    required GoogleTokenStore store,
    String? clientId,
    GoogleAuthLauncher? launcher,
    GoogleCredentialsRefresher? refresher,
  }) : _store = store,
       _clientId = clientId,
       _launcher = launcher ?? _defaultLauncher,
       _refresher = refresher ?? _defaultRefresher;

  final GoogleTokenStore _store;
  final String? _clientId;
  final GoogleAuthLauncher _launcher;
  final GoogleCredentialsRefresher _refresher;

  /// The client id to use, preferring an injected override (tests) over the
  /// compile-time value (production) — either way going through
  /// [requireGoogleClientId] in the production case so a missing build-time
  /// value fails loudly rather than launching a consent flow that can never
  /// succeed.
  String get _resolvedClientId => _clientId ?? requireGoogleClientId();

  /// Runs the interactive consent flow, persists the result on success, and
  /// clears the reconnect flag. Returns `true` when the user cancelled.
  Future<bool> connect() async {
    final clientId = _resolvedClientId;
    final redirectUri = googleRedirectUriFor(clientId);
    final tokens = await _launcher(
      clientId: clientId,
      redirectUri: redirectUri,
      scopes: const [kGoogleCalendarReadonlyScope],
    );
    if (tokens == null) return true; // cancelled
    await _store.write(tokens);
    await _store.setReconnectNeeded(false);
    return false;
  }

  Future<bool> hasCredentials() async => (await _store.read()) != null;

  /// Returns an `http.Client` carrying a valid bearer token, silently
  /// refreshing the stored access token first if it has expired. Throws
  /// [GoogleAuthException] if no tokens are stored at all.
  Future<http.Client> authenticatedClient() async {
    final tokens = await _store.read();
    if (tokens == null) {
      throw GoogleAuthException('not connected to Google');
    }
    if (tokens.expiresAt.toUtc().isAfter(DateTime.now().toUtc())) {
      return gauth.authenticatedClient(
        http.Client(),
        _toAccessCredentials(tokens),
      );
    }
    final gauth.AccessCredentials refreshed;
    try {
      refreshed = await _refresher(
        gauth.ClientId(_resolvedClientId),
        _toAccessCredentials(tokens),
        http.Client(),
      );
    } catch (_) {
      throw GoogleAuthException('Google token refresh failed');
    }
    await _store.write(
      GoogleTokens(
        accessToken: refreshed.accessToken.data,
        refreshToken: refreshed.refreshToken ?? tokens.refreshToken,
        expiresAt: refreshed.accessToken.expiry,
      ),
    );
    return gauth.authenticatedClient(http.Client(), refreshed);
  }

  gauth.AccessCredentials _toAccessCredentials(GoogleTokens tokens) =>
      gauth.AccessCredentials(
        gauth.AccessToken(
          'Bearer',
          tokens.accessToken,
          tokens.expiresAt.toUtc(),
        ),
        tokens.refreshToken,
        const [kGoogleCalendarReadonlyScope],
      );

  /// Clears stored tokens and the reconnect flag.
  Future<void> disconnect() async {
    await _store.clear();
    await _store.setReconnectNeeded(false);
  }
}

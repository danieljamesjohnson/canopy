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

  /// True when the stored Google credential has been found dead and the
  /// user must reconnect (CALAUTH-03). Documented here — not only on
  /// `AppSettings`'s own field — because this seam, not the Hive model, is
  /// what any future caller (plan 36-06's settings screen) actually reads.
  /// Exactly five things set or clear it (plan 36-02 Task 3), and nothing
  /// else does:
  /// 1. A successful interactive [GoogleAuthClient.connect] -> false.
  /// 2. A successful silent refresh, inside
  ///    [GoogleAuthClient.authenticatedClient] -> false.
  /// 3. A refresh that fails on the network, a timeout, or a non-matching
  ///    status/body (e.g. a transient 5xx) -> untouched, stays whatever it
  ///    was — a flaky connection must never masquerade as an expired login.
  /// 4. A cancelled [GoogleAuthClient.connect] -> untouched. Backing out of
  ///    the reconnect sheet does not pretend the problem is solved.
  /// 5. [GoogleAuthClient.disconnect] -> false. Disconnected is not
  ///    "expired" — the user ended it deliberately, so the screen must fall
  ///    back to the plain not-connected CTA rather than nagging about a
  ///    login they no longer have.
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

/// Translates a thrown object from `flutter_appauth`'s platform call into
/// either `null` (the user cancelled the consent sheet — a real state, not
/// an error, RESEARCH Anti-Patterns) or the [GoogleAuthException] the
/// launcher should throw for everything else.
///
/// Extracted from [_defaultLauncher] as its own top-level function (Task 2)
/// so this one boundary translation is directly unit-testable. A real
/// [FlutterAppAuthUserCancelledException] CAN be constructed in a host test
/// — it is a plain `PlatformException` subclass with no platform-channel
/// dependency (confirmed by reading `flutter_appauth_platform_interface`
/// 12.1.0's source this session), so the translation itself is proven by a
/// test here, not merely asserted by grep — Assumption A7 is narrowed by
/// this, though it does not confirm every native cancellation path actually
/// throws this exception on a real device (carried to plan 36-07).
///
/// Deliberately narrow: only this one exception type is treated as a
/// cancellation. A broader catch would risk swallowing a real failure,
/// which is the worse error (RESEARCH Anti-Patterns).
GoogleAuthException? translateGoogleLauncherError(Object thrown) {
  if (thrown is FlutterAppAuthUserCancelledException) return null;
  return GoogleAuthException('Google sign-in failed');
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
  } catch (e) {
    final translated = translateGoogleLauncherError(e);
    if (translated == null) return null; // cancelled — a real state.
    throw translated;
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

/// True only when [error] is exactly Google's documented "this refresh
/// token is dead" shape (CALAUTH-03): a [gauth.ServerRequestFailedException]
/// from `googleapis_auth`, with HTTP status 400, AND a body naming Google's
/// `invalid_grant` error code. All three conditions together, deliberately
/// narrow — RESEARCH Pitfall 3 warns explicitly against keying off the
/// status code alone, and this plan's own mutation proof (see SUMMARY)
/// demonstrates why: a status-code-only check would also fire for a plain
/// `400 invalid_request` (a malformed refresh call, not a dead token).
///
/// [gauth.ServerRequestFailedException.responseContent] is confirmed
/// (Assumption A3, resolved this plan by reading the installed
/// `googleapis_auth` 2.3.4 source directly — `lib/src/utils.dart`'s
/// `requestJson`, which throws with `responseContent: jsonMap`) to be the
/// PARSED JSON response body, a `Map<String, dynamic>`, not an
/// already-summarized message. Google's own error shape puts the code in
/// the `error` key, so this checks that key directly rather than
/// string-matching a `.toString()` of the body.
bool _isExpiredOrRevokedRefreshToken(Object error) {
  if (error is! gauth.ServerRequestFailedException) return false;
  if (error.statusCode != 400) return false;
  final content = error.responseContent;
  return content is Map && content['error'] == 'invalid_grant';
}

/// Owns the Google token lifecycle: launching consent, persisting the
/// result, silently refreshing an expired access token, classifying a
/// refresh failure into "reconnect needed" versus an ordinary hiccup
/// (CALAUTH-03), and handing back an authenticated HTTP client for the
/// Calendar API.
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

  /// Safety buffer subtracted from a token's `expiresAt` before deciding
  /// whether it's still usable (WR-04 code review) — see
  /// [authenticatedClient]'s own doc comment for why.
  static const Duration _expiryMargin = Duration(seconds: 30);

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
  /// refreshing the stored access token first if it has expired — or if it
  /// is within [_expiryMargin] of expiring (WR-04 code review). Without a
  /// margin, a token that expires in the next few hundred milliseconds is
  /// treated as valid and handed straight to the caller: by the time the
  /// resulting `http.Client` actually reaches Google (network latency, any
  /// queued work before the request fires), the token can have expired
  /// server-side, turning an avoidable race into a user-visible sync
  /// failure. Throws [GoogleAuthException] if no tokens are stored at all.
  Future<http.Client> authenticatedClient() async {
    final tokens = await _store.read();
    if (tokens == null) {
      throw GoogleAuthException('not connected to Google');
    }
    if (tokens.expiresAt.toUtc().isAfter(
      DateTime.now().toUtc().add(_expiryMargin),
    )) {
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
    } catch (e) {
      if (_isExpiredOrRevokedRefreshToken(e)) {
        // THIS, specifically, is CALAUTH-03's case — the 7-day (or
        // revoked) expiry. Stored tokens are left untouched (only the flag
        // changes) so the user's last-known calendars keep rendering.
        await _store.setReconnectNeeded(true);
      }
      // Anything else (network failure, timeout, a transient 5xx, a 400
      // that doesn't name Google's expired-or-revoked code) degrades
      // exactly like the existing ICS failure path already does: a thrown
      // exception, no reconnect nagging, flag left exactly as it was.
      throw GoogleAuthException('Google token refresh failed');
    }
    // A successful refresh proves the login is alive — clear any stale
    // reconnect flag before persisting the refreshed tokens (Task 3).
    await _store.setReconnectNeeded(false);
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

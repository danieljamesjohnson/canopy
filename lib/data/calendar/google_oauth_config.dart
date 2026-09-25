// Compile-time injection surface for the Google OAuth client id (CONTEXT
// decision 1) and the single read-only scope Canopy ever asks Google for
// (CALAUTH-02).
//
// The client id is supplied at build time via `--dart-define`
// (`tools/build-ios.sh`, plan 36-04) and is never checked in — see
// `.google-client-id` (gitignored, mode 600). `flutter test` never supplies
// a dart-define, so the empty-string default below is the NORMAL case for
// every test in this repo, not a rare edge case to special-case away.

/// The Google OAuth client id injected at build time, or the empty string
/// when no `--dart-define=GOOGLE_IOS_CLIENT_ID=...` was supplied — every
/// `flutter test` run, and any `flutter build`/`flutter run` invoked
/// directly rather than through `tools/build-ios.sh`.
const String googleIosClientId = String.fromEnvironment(
  'GOOGLE_IOS_CLIENT_ID',
);

/// The only Google Calendar scope Canopy ever requests (CALAUTH-02). This
/// constant must remain the single place this scope string exists anywhere
/// in `lib/` — enforced by this plan's own acceptance criteria and by plan
/// 36-04's CALAUTH-04 gate.
const String kGoogleCalendarReadonlyScope =
    'https://www.googleapis.com/auth/calendar.readonly';

/// Raised by [requireGoogleClientId] when no client id was injected at
/// build time. The message names the exact file and script an operator
/// needs, so a missing client id reads as "you did not run the build
/// wrapper" rather than a mysterious OAuth failure.
class GoogleOAuthNotConfiguredError implements Exception {
  GoogleOAuthNotConfiguredError()
    : message =
          'No Google OAuth client id was injected at build time. Run '
          'tools/build-ios.sh, which reads .google-client-id and passes it '
          'via --dart-define=GOOGLE_IOS_CLIENT_ID=... — building directly '
          'with `flutter build ios` / `flutter run` will not configure '
          'Google sign-in.';

  final String message;

  @override
  String toString() => 'GoogleOAuthNotConfiguredError: $message';
}

/// Returns the injected client id, or throws
/// [GoogleOAuthNotConfiguredError] when none was supplied. Callers that need
/// the client id to do anything (launch the consent flow, refresh a token)
/// should always go through this accessor rather than reading
/// [googleIosClientId] directly, so a missing value fails loudly and
/// immediately rather than producing a sign-in button that silently does
/// nothing. This is the in-code half of "a build with no client ID fails
/// clearly and early"; plan 36-04 adds the build-time half.
String requireGoogleClientId() {
  if (googleIosClientId.isEmpty) {
    throw GoogleOAuthNotConfiguredError();
  }
  return googleIosClientId;
}

/// Raised by [reverseGoogleClientId] when given a string that does not
/// match Google's documented client-id shape.
class GoogleClientIdFormatError implements Exception {
  GoogleClientIdFormatError();

  @override
  String toString() =>
      'GoogleClientIdFormatError: client id does not match the expected '
      'Google OAuth client id shape.';
}

/// Implements Google's documented reversed-client-id rule for the iOS OAuth
/// redirect scheme. A Google-issued client id always ends in the same
/// hosted-domain suffix; this strips that suffix and prepends it back in
/// reversed-domain order to produce the URL scheme AppAuth must match
/// against `CFBundleURLTypes` (plan 36-04).
///
/// Throws [GoogleClientIdFormatError] on any other shape, rather than
/// silently producing a redirect scheme that would never match what gets
/// registered — a mismatched scheme fails as a URL that never returns to
/// the app, a much harder defect to diagnose than a thrown error at the
/// point the id was read. Deliberately no concrete example client id
/// appears in this comment (plan 36-04's CALAUTH-04 gate greps source for
/// exactly that shape) — see google_oauth_config_test.dart for a synthetic
/// worked example.
String reverseGoogleClientId(String clientId) {
  const suffix = '.apps.googleusercontent.com';
  if (!clientId.endsWith(suffix) || clientId.length <= suffix.length) {
    throw GoogleClientIdFormatError();
  }
  final idPart = clientId.substring(0, clientId.length - suffix.length);
  if (idPart.isEmpty) {
    throw GoogleClientIdFormatError();
  }
  return 'com.googleusercontent.apps.$idPart';
}

/// The redirect URI AppAuth must match against `CFBundleURLTypes` — the
/// reversed client id plus Google's documented native-app callback path.
String googleRedirectUriFor(String clientId) =>
    '${reverseGoogleClientId(clientId)}:/oauth2redirect';

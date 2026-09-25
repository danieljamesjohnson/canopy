// Tests for google_oauth_config.dart's client-id injection surface.
//
// The expected reversed scheme below is a bare literal, not re-derived from
// reverseGoogleClientId's own output — an expectation derived from the code
// it checks cannot fail, this repo's single most-repeated testing lesson
// (CLAUDE.md "Assertions that cannot fail"). The client id values used here
// are entirely synthetic; the owner's real client id never appears in any
// source file (verified separately by this plan's grep-based acceptance
// criteria).

import 'package:canopy/data/calendar/google_oauth_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reverseGoogleClientId', () {
    test('turns a well-formed client id into the expected reversed scheme', () {
      // Synthetic input — a bare literal, not re-derived from the function
      // under test.
      const synthetic = '000000000000-synthtestidvalue.apps.googleusercontent.com';
      expect(
        reverseGoogleClientId(synthetic),
        equals(
          'com.googleusercontent.apps.000000000000-synthtestidvalue',
        ),
      );
    });

    test(
      'throws GoogleClientIdFormatError for a client id missing the '
      'expected hosted-domain suffix',
      () {
        expect(
          () => reverseGoogleClientId('not-a-google-client-id'),
          throwsA(isA<GoogleClientIdFormatError>()),
        );
      },
    );

    test(
      'throws GoogleClientIdFormatError for a client id that is only the '
      'suffix, with no id portion',
      () {
        expect(
          () => reverseGoogleClientId('.apps.googleusercontent.com'),
          throwsA(isA<GoogleClientIdFormatError>()),
        );
      },
    );
  });

  group('googleRedirectUriFor', () {
    test('appends the native-app callback path to the reversed scheme', () {
      const synthetic = '000000000000-synthtestidvalue.apps.googleusercontent.com';
      expect(
        googleRedirectUriFor(synthetic),
        equals(
          'com.googleusercontent.apps.000000000000-synthtestidvalue:/oauth2redirect',
        ),
      );
    });
  });

  group('requireGoogleClientId', () {
    test(
      'throws GoogleOAuthNotConfiguredError naming .google-client-id and '
      'tools/build-ios.sh, since flutter test never supplies a dart-define',
      () {
        expect(googleIosClientId, isEmpty);
        try {
          requireGoogleClientId();
          fail('expected GoogleOAuthNotConfiguredError');
        } on GoogleOAuthNotConfiguredError catch (e) {
          expect(e.toString(), contains('.google-client-id'));
          expect(e.toString(), contains('tools/build-ios.sh'));
        }
      },
    );
  });
}

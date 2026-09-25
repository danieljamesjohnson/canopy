// CALAUTH-04 / plan 36-04: two implementations of one rule — a Dart function
// (reverseGoogleClientId) and a shell script (tools/build-ios.sh) — must
// agree on how a Google OAuth client id becomes the reversed URL scheme iOS
// registers. Two implementations of one rule drift; this test is what stops
// them.
//
// This test shells out to the REAL tools/build-ios.sh against a synthetic
// client id in a scratch temp directory. It never touches the real
// .google-client-id and never reaches a `flutter build`/`flutter run`
// invocation — BUILD_IOS_WRAPPER_GENERATE_ONLY=1 tells the wrapper to stop
// right after writing the generated xcconfig, which `flutter test` must
// never shell past.

import 'dart:io';

import 'package:canopy/data/calendar/google_oauth_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String scriptPath;

  setUpAll(() {
    // `flutter test` runs with the package root as the working directory.
    scriptPath = '${Directory.current.path}/tools/build-ios.sh';
    expect(
      File(scriptPath).existsSync(),
      isTrue,
      reason: 'tools/build-ios.sh must exist for this test to mean anything',
    );
  });

  group('tools/build-ios.sh', () {
    test(
      'generates a GoogleOAuth.xcconfig whose reversed value matches '
      'reverseGoogleClientId for the same synthetic client id',
      () {
        // Synthetic input — never the owner's real client id, which is never
        // present in this repo checkout in the first place (gitignored).
        const syntheticClientId =
            '000000000000-synthtestidvalue.apps.googleusercontent.com';

        final tempDir = Directory.systemTemp.createTempSync(
          'build_ios_wrapper_test_',
        );
        addTearDown(() => tempDir.deleteSync(recursive: true));

        File(
          '${tempDir.path}/.google-client-id',
        ).writeAsStringSync(syntheticClientId);
        Directory('${tempDir.path}/ios/Flutter').createSync(recursive: true);

        // tools/build-ios.sh resolves its own repo root as
        // dirname($0)/.., so copying it one level under the temp dir makes
        // that resolve to tempDir — the synthetic client-id file and the
        // generated xcconfig both land there, nowhere near the real repo.
        final scriptCopyDir = Directory('${tempDir.path}/tools')
          ..createSync(recursive: true);
        File(scriptPath).copySync('${scriptCopyDir.path}/build-ios.sh');

        final result = Process.runSync(
          'bash',
          ['${scriptCopyDir.path}/build-ios.sh'],
          environment: {'BUILD_IOS_WRAPPER_GENERATE_ONLY': '1'},
        );

        expect(
          result.exitCode,
          0,
          reason:
              'generate-only run against a valid synthetic client id must '
              'succeed:\nstdout: ${result.stdout}\nstderr: ${result.stderr}',
        );

        final generated = File(
          '${tempDir.path}/ios/Flutter/GoogleOAuth.xcconfig',
        );
        expect(generated.existsSync(), isTrue);

        final expectedReversed = reverseGoogleClientId(syntheticClientId);
        final contents = generated.readAsStringSync();
        expect(
          contents,
          contains('GOOGLE_REVERSED_CLIENT_ID = $expectedReversed'),
          reason:
              'the shell script and reverseGoogleClientId() must derive the '
              'identical reversed value for the same input — this is the '
              'whole point of this test',
        );
      },
    );

    test(
      'exits non-zero and names .google-client-id when the file is missing',
      () {
        final tempDir = Directory.systemTemp.createTempSync(
          'build_ios_wrapper_test_missing_',
        );
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final scriptCopyDir = Directory('${tempDir.path}/tools')
          ..createSync(recursive: true);
        File(scriptPath).copySync('${scriptCopyDir.path}/build-ios.sh');

        // Deliberately no .google-client-id anywhere under tempDir.
        final result = Process.runSync('bash', [
          '${scriptCopyDir.path}/build-ios.sh',
        ]);

        expect(result.exitCode, isNot(0));
        final combinedOutput = '${result.stdout}${result.stderr}';
        expect(combinedOutput, contains('.google-client-id'));
        // The guard must fire before any flutter invocation is attempted —
        // proven directly in this plan's SUMMARY via `bash -x`, and
        // reinforced here: a missing client id must never produce a
        // generated xcconfig either.
        expect(
          File('${tempDir.path}/ios/Flutter/GoogleOAuth.xcconfig').existsSync(),
          isFalse,
        );
      },
    );
  });
}

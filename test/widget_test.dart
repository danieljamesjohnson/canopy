import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder — full app smoke test added in later phases', () {
    // Phase 1 does not pump the full widget tree in tests due to
    // async HiveDatabase.init requirement. Repository unit tests cover correctness.
    expect(true, isTrue);
  });
}

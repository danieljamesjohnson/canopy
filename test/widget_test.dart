import 'package:flutter_test/flutter_test.dart';

import 'package:canopy/main.dart';

void main() {
  testWidgets('CanopyApp renders placeholder text', (WidgetTester tester) async {
    await tester.pumpWidget(const CanopyApp());
    expect(find.text('Canopy'), findsWidgets);
  });
}

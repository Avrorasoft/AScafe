// Nombre del archivo: avrora_license_manager/test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:avrora_license_manager/main.dart';

void main() {
  testWidgets('LicenseGeneratorApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LicenseGeneratorApp());
    expect(find.byType(LicenseGeneratorApp), findsOneWidget);
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:driverwatch/main.dart';

void main() {
  testWidgets('DriverWatch app starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const DriverWatchApp());
    expect(find.text('DriverWatch - Segurança Inteligente'), findsOneWidget);
  });
}
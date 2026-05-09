import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:driverwatch/main.dart';

void main() {
  testWidgets('DriverWatch app starts without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DriverWatchApp());

    // Verifica se o texto "DriverWatch - Monitoramento" está presente no AppBar
    expect(find.text('DriverWatch - Monitoramento'), findsOneWidget);
  });
}
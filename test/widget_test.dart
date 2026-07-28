// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_inventory/main.dart';
import 'package:smart_inventory/screens/login_screen.dart';

void main() {
  testWidgets('Smart Inventory smoke test - Loading LoginScreen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the LoginScreen is loaded by checking for the application brand title.
    expect(find.text('ALSAKINA'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
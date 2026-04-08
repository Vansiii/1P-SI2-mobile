import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchanic_repair/main.dart';

void main() {
  testWidgets('App loads and shows auth checker', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: MerchanicRepairApp()));

    // Wait for async operations
    await tester.pumpAndSettle();

    // Verify that the app loads
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Login screen shows required fields', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: MerchanicRepairApp()));

    // Wait for async operations
    await tester.pumpAndSettle();

    // Verify that login fields are present
    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}

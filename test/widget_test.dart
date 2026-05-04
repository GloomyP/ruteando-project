import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruteando_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('muestra el flujo de registro en dos pasos', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: PantallaLogin()));
    await tester.pumpAndSettle();

    expect(find.text('Registrarme'), findsOneWidget);

    await tester.tap(find.text('Registrarme'));
    await tester.pumpAndSettle();

    expect(find.text('Registro de usuario'), findsOneWidget);
    expect(find.text('Información personal'), findsOneWidget);
    expect(find.text('Nombre completo'), findsOneWidget);
    expect(find.text('Siguiente'), findsOneWidget);
    expect(find.text('Dirección'), findsNothing);
    expect(find.byIcon(Icons.person_add_alt_1), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Fran Perez');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'fran@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), '123456');
    await tester.enterText(find.byType(TextFormField).at(3), '123456');
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('Dirección'), findsOneWidget);
    expect(find.text('Región'), findsOneWidget);
    expect(find.text('Comuna'), findsOneWidget);
    expect(find.text('Ciudad'), findsOneWidget);
    expect(find.text('Calle'), findsOneWidget);
    expect(find.text('Número'), findsOneWidget);
    expect(find.text('Detalles'), findsOneWidget);
    expect(find.text('Registrarse'), findsOneWidget);
  });
}

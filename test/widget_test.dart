import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruteando_app/main.dart';

void main() {
  testWidgets('muestra el boton de registro y abre la pantalla de registro', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RuteandoApp());

    expect(find.text('Registrarme'), findsOneWidget);

    await tester.tap(find.text('Registrarme'));
    await tester.pumpAndSettle();

    expect(find.text('Registro de usuario'), findsOneWidget);
    expect(find.text('Nombre completo'), findsOneWidget);
    expect(find.text('Registrarse'), findsOneWidget);
    expect(find.byIcon(Icons.person_add_alt_1), findsOneWidget);
  });
}

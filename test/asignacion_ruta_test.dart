import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ruteando_app/main.dart';
import 'package:ruteando_app/pantalla_asignacion_ruta.dart';
import 'package:ruteando_app/pantalla_ruta.dart';
import 'package:ruteando_app/persistencia_rutas.dart';

void main() {
  testWidgets('PantallaRuta muestra boton de Asignar ruta y valida la generacion', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'empresa_vinculada_usuario_local': jsonEncode({
        'nombre': 'Empresa Test SpA',
        'rut': '76.111.222-3',
      }),
      'conductores_empresa_vinculada_usuario_local': jsonEncode([
        {
          'nombre': 'Repartidor Uno',
          'rut': '11.111.111-1',
          'correo': 'repartidor1@test.cl',
          'telefono': '+56911111111',
          'empresa': '76.111.222-3',
          'rol': 'repartidor',
        }
      ]),
    });

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/asignacion-rutas': (context) => const PantallaAsignacionRuta(),
        },
        home: const PantallaRuta(),
      ),
    );
    await tester.pumpAndSettle();

    // El botón Asignar ruta debe estar deshabilitado al inicio porque no hay ruta generada
    final outlinedButtonFinder = find.widgetWithText(OutlinedButton, 'Asignar ruta');
    expect(outlinedButtonFinder, findsOneWidget);

    final OutlinedButton button = tester.widget(outlinedButtonFinder);
    expect(button.onPressed, isNull);
  });

  testWidgets('PantallaAsignacionRuta muestra estado vacio si no hay asignaciones', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: PantallaAsignacionRuta()));
    await tester.pumpAndSettle();

    expect(find.text('Sin rutas asignadas hoy'), findsOneWidget);
    expect(find.text('Planificar y Optimizar Ruta'), findsOneWidget);
  });

  testWidgets('PantallaRutaAsignada muestra estado vacio si no tiene ruta el repartidor', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: PantallaRutaAsignada()));
    await tester.pumpAndSettle();

    expect(find.text('No tienes rutas asignadas'), findsOneWidget);
    expect(find.text('Refrescar'), findsOneWidget);
  });
}

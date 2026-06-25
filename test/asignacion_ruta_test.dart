import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ruteando_app/main.dart';
import 'package:ruteando_app/pantalla_asignacion_ruta.dart';
import 'package:ruteando_app/pantalla_ruta.dart';

void main() {
  testWidgets(
    'PantallaRuta muestra boton de Asignar ruta y valida la generacion',
    (WidgetTester tester) async {
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
          },
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
      final outlinedButtonFinder = find.widgetWithText(
        OutlinedButton,
        'Asignar ruta',
      );
      expect(outlinedButtonFinder, findsOneWidget);

      final OutlinedButton button = tester.widget(outlinedButtonFinder);
      expect(button.onPressed, isNull);
      expect(find.text('Paradas por optimizar'), findsOneWidget);
      expect(
        find.text('Terminal Rodoviario Valparaiso, Chile'),
        findsOneWidget,
      );
    },
  );

  testWidgets('PantallaRuta no permite agregar mas de 25 paradas', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'rol_usuario_local': 'admin'});
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: PantallaRuta()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paradas (1)'));
    await tester.pumpAndSettle();

    final agregarParada = find.widgetWithText(OutlinedButton, 'Agregar parada');

    for (var i = 1; i < 25; i++) {
      await tester.ensureVisible(agregarParada);
      await tester.tap(agregarParada);
      await tester.pump();
    }

    await tester.ensureVisible(agregarParada);
    await tester.tap(agregarParada);
    await tester.pump();

    expect(
      find.text(
        'No se pueden agregar mas de 25 paradas por ruta. '
        'Elimina una parada existente antes de agregar otra.',
      ),
      findsWidgets,
    );
  });

  testWidgets('PantallaRuta oculta vista previa de paradas para repartidor', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'rol_usuario_local': 'repartidor'});

    await tester.pumpWidget(const MaterialApp(home: PantallaRuta()));
    await tester.pumpAndSettle();

    expect(find.text('Paradas por optimizar'), findsNothing);
    expect(find.text('Terminal Rodoviario Valparaiso, Chile'), findsNothing);
  });

  testWidgets(
    'PantallaAsignacionRuta muestra estado vacio si no hay asignaciones',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const MaterialApp(home: PantallaAsignacionRuta()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sin rutas asignadas hoy'), findsOneWidget);
      expect(find.text('Planificar y Optimizar Ruta'), findsOneWidget);
    },
  );

  testWidgets('PantallaAsignacionRuta muestra historial con hora de entrega', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'empresa_vinculada_usuario_local': jsonEncode([
        {
          'origen': 'Bodega central',
          'paradas': [
            {
              'texto': 'Cliente 1',
              'estado': 'Entregado',
              'fechaEntrega': '2026-06-09T14:35:00',
            },
          ],
          'distancia': '8.4 km',
          'tiempo': '18 min',
          'criterio': 'Menor distancia',
          'fechaAsignacion': '2026-06-09T12:00:00',
          'repartidorEmail': 'repartidor1@test.cl',
          'repartidorNombre': 'Repartidor Uno',
        },
      ]),
    });

    await tester.pumpWidget(const MaterialApp(home: PantallaAsignacionRuta()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver paradas intermedias'));
    await tester.pumpAndSettle();

    expect(find.text('Cliente 1'), findsOneWidget);
    expect(find.text('09/06/2026 14:35'), findsOneWidget);
  });

  testWidgets(
    'PantallaRutaAsignada muestra estado vacio si no tiene ruta el repartidor',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const MaterialApp(home: PantallaRutaAsignada()));
      await tester.pumpAndSettle();

      expect(find.text('No tienes rutas asignadas'), findsOneWidget);
      expect(find.text('Refrescar'), findsOneWidget);
    },
  );

  testWidgets(
    'PantallaRutaAsignada muestra notificacion y permite abrir la ruta',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'ruta_asignada_local': jsonEncode({
          'origen': 'Bodega central',
          'paradas': [
            {'texto': 'Cliente 1', 'estado': 'En camino'},
            {'texto': 'Cliente 2', 'estado': 'Pendiente'},
          ],
          'estadoRecorrido': 'En curso',
          'distancia': '8.4 km',
          'tiempo': '18 min',
          'criterio': 'Menor distancia',
          'fechaAsignacion': '2026-05-26T12:00:00',
          'repartidorEmail': 'local',
          'repartidorNombre': 'Repartidor local',
        }),
        'notificacion_ruta_local': jsonEncode({
          'titulo': 'Nueva ruta asignada',
          'mensaje': 'Tienes una ruta optimizada pendiente.',
          'origen': 'Bodega central',
          'paradas': 2,
          'distancia': '8.4 km',
          'tiempo': '18 min',
          'criterio': 'Menor distancia',
          'rutaDestino': '/mi-ruta',
          'leida': false,
        }),
      });

      await tester.pumpWidget(const MaterialApp(home: PantallaRutaAsignada()));
      await tester.pumpAndSettle();

      expect(find.text('Nueva ruta asignada'), findsOneWidget);
      expect(find.text('Paradas: 2'), findsOneWidget);
      expect(find.text('Distancia: 8.4 km'), findsWidgets);
      expect(find.text('Tiempo: 18 min'), findsWidgets);
      expect(find.text('Ver ruta'), findsOneWidget);

      await tester.tap(find.text('Ver ruta'));
      await tester.pumpAndSettle();

      expect(find.text('Nueva ruta asignada'), findsNothing);
      expect(find.text('Resumen del viaje'), findsOneWidget);
      expect(find.text('Cliente 1'), findsOneWidget);
      expect(find.text('Recorrido en curso'), findsOneWidget);
      expect(find.text('En camino'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Entregado'), findsOneWidget);

      final entregarButton = find.widgetWithText(FilledButton, 'Entregado');
      await tester.ensureVisible(entregarButton);
      await tester.tap(entregarButton);
      await tester.pumpAndSettle();

      expect(find.text('En camino'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Entregado'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      final rutaActualizada =
          jsonDecode(prefs.getString('ruta_asignada_local')!)
              as Map<String, dynamic>;
      final primeraParada =
          (rutaActualizada['paradas'] as List).first as Map<String, dynamic>;
      expect(primeraParada['estado'], 'Entregado');
      expect(primeraParada['fechaEntrega'], isNotNull);
      expect(
        DateTime.tryParse(primeraParada['fechaEntrega'] as String),
        isNotNull,
      );
      expect(find.widgetWithText(FilledButton, 'Entregado'), findsOneWidget);
    },
  );

  testWidgets(
    'PantallaRutaAsignada actualiza distancia y tiempo si cambia la ruta',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'ruta_asignada_local': jsonEncode({
          'origen': 'Bodega central',
          'paradas': [
            {'texto': 'Cliente 1', 'estado': 'Pendiente'},
          ],
          'distancia': '8.4 km',
          'tiempo': '18 min',
          'criterio': 'Menor distancia',
          'fechaAsignacion': '2026-05-26T12:00:00',
          'repartidorEmail': 'local',
          'repartidorNombre': 'Repartidor local',
        }),
      });

      await tester.pumpWidget(const MaterialApp(home: PantallaRutaAsignada()));
      await tester.pumpAndSettle();

      expect(find.text('Distancia: 8.4 km'), findsOneWidget);
      expect(find.text('Tiempo estimado: 18 min'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'ruta_asignada_local',
        jsonEncode({
          'origen': 'Bodega central',
          'paradas': [
            {'texto': 'Cliente 1', 'estado': 'Pendiente'},
            {'texto': 'Cliente 2', 'estado': 'Pendiente'},
          ],
          'distancia': '12.7 km',
          'tiempo': '26 min',
          'criterio': 'Tiempo mas rapido',
          'fechaAsignacion': '2026-05-26T13:00:00',
          'repartidorEmail': 'local',
          'repartidorNombre': 'Repartidor local',
        }),
      );

      await tester.tap(find.byTooltip('Recargar ruta'));
      await tester.pumpAndSettle();

      expect(find.text('Distancia: 12.7 km'), findsOneWidget);
      expect(find.text('Tiempo estimado: 26 min'), findsOneWidget);
      expect(find.text('Cliente 2'), findsOneWidget);
    },
  );
}

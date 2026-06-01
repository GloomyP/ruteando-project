import 'dart:convert';

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

  testWidgets('valida y registra una empresa con guardado simulado', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: PantallaRegistroEmpresa()));
    await tester.pumpAndSettle();

    expect(find.text('Registro de empresa'), findsOneWidget);
    expect(find.text('Nombre de empresa'), findsOneWidget);
    expect(find.text('RUT'), findsOneWidget);
    expect(find.text('Correo de contacto'), findsOneWidget);
    expect(find.text('Telefono de contacto'), findsOneWidget);

    await tester.tap(find.text('Registrar empresa'));
    await tester.pump();

    expect(
      find.text('Debe completar todos los campos obligatorios.'),
      findsOneWidget,
    );
    expect(find.text('Campo obligatorio'), findsNWidgets(4));

    await tester.enterText(find.byType(TextFormField).at(0), 'Ruteando SpA');
    await tester.enterText(find.byType(TextFormField).at(1), '761234567');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'contacto@ruteando@cl',
    );
    await tester.enterText(find.byType(TextFormField).at(3), '+56912345678');
    await tester.ensureVisible(find.text('Registrar empresa'));
    await tester.tap(find.text('Registrar empresa'));
    await tester.pump();

    expect(
      find.text('Ingresa un correo con un solo dominio valido'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byType(TextFormField).at(2),
      'contacto@ruteando.cl',
    );
    await tester.ensureVisible(find.text('Registrar empresa'));
    await tester.tap(find.text('Registrar empresa'));
    await tester.pumpAndSettle();

    expect(find.text('Empresa vinculada'), findsOneWidget);
    expect(find.text('Ruteando SpA'), findsOneWidget);
    expect(find.text('76.123.456-7'), findsOneWidget);
    expect(find.text('Editar informacion'), findsOneWidget);
    expect(find.text('Nombre de empresa'), findsNothing);
    expect(
      find.text('Debe completar todos los campos obligatorios.'),
      findsNothing,
    );
  });

  testWidgets('muestra una empresa vinculada existente', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'empresa_vinculada_usuario_local': jsonEncode({
        'nombre': 'Empresa Existente SpA',
        'rut': '77.777.777-7',
        'correo': 'contacto@existente.cl',
        'telefono': '+56977777777',
      }),
    });

    await tester.pumpWidget(const MaterialApp(home: PantallaRegistroEmpresa()));
    await tester.pumpAndSettle();

    expect(find.text('Empresa vinculada'), findsOneWidget);
    expect(find.text('Empresa Existente SpA'), findsOneWidget);
    expect(find.text('77.777.777-7'), findsOneWidget);
    expect(find.text('contacto@existente.cl'), findsOneWidget);
    expect(find.text('+56977777777'), findsOneWidget);
    expect(find.text('Editar informacion'), findsOneWidget);
    expect(find.text('Nombre de empresa'), findsNothing);
    expect(find.text('Registrar empresa'), findsNothing);

    await tester.tap(find.text('Editar informacion'));
    await tester.pumpAndSettle();

    expect(find.text('Editar empresa'), findsOneWidget);
    expect(find.text('Nombre de empresa'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Empresa Actualizada SpA',
    );
    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(find.text('Empresa vinculada'), findsOneWidget);
    expect(find.text('Empresa Actualizada SpA'), findsOneWidget);
    expect(find.text('Empresa Existente SpA'), findsNothing);
    expect(find.text('Editar informacion'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsNothing);
  });

  testWidgets('registra multiples repartidores asociados a la empresa', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'empresa_vinculada_usuario_local': jsonEncode({
        'nombre': 'Empresa Repartidores SpA',
        'rut': '76.111.222-3',
        'correo': 'contacto@repartidores.cl',
        'telefono': '+56911112222',
      }),
    });

    await tester.pumpWidget(const MaterialApp(home: PantallaConductores()));
    await tester.pumpAndSettle();

    expect(find.text('Registro de repartidores'), findsOneWidget);
    expect(find.text('Empresa: Empresa Repartidores SpA'), findsOneWidget);
    expect(find.text('No hay repartidores registrados.'), findsOneWidget);

    await tester.tap(find.text('Registrar repartidor'));
    await tester.pump();

    expect(
      find.text('Debe completar todos los campos obligatorios.'),
      findsOneWidget,
    );
    expect(find.text('Campo obligatorio'), findsNWidgets(4));

    await tester.enterText(find.byType(TextFormField).at(0), 'Juan Perez');
    await tester.enterText(find.byType(TextFormField).at(1), '111111111');
    await tester.enterText(find.byType(TextFormField).at(2), 'juan@test@cl');
    await tester.enterText(find.byType(TextFormField).at(3), '+56911111111');
    await tester.ensureVisible(find.text('Registrar repartidor'));
    await tester.tap(find.text('Registrar repartidor'));
    await tester.pump();

    expect(
      find.text('Ingresa un correo con un solo dominio valido'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField).at(2), 'juan@test.cl');
    await tester.ensureVisible(find.text('Registrar repartidor'));
    await tester.tap(find.text('Registrar repartidor'));
    await tester.pumpAndSettle();

    expect(
      find.text('¿Quieres agregar a esta persona a tu empresa?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Persona asociada correctamente a la empresa'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
    expect(
      find.text('Persona asociada correctamente a la empresa'),
      findsNothing,
    );
    expect(find.text('Juan Perez'), findsOneWidget);
    expect(find.textContaining('11.111.111-1'), findsOneWidget);
    expect(find.text('No hay repartidores registrados.'), findsNothing);

    await tester.enterText(find.byType(TextFormField).at(0), 'Juan Duplicado');
    await tester.enterText(find.byType(TextFormField).at(1), '111111111');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'duplicado@test.cl',
    );
    await tester.enterText(find.byType(TextFormField).at(3), '+56933333333');
    await tester.ensureVisible(find.text('Registrar repartidor'));
    await tester.tap(find.text('Registrar repartidor'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ya existe un repartidor registrado con ese RUT.'),
      findsOneWidget,
    );
    expect(find.text('Asociar persona'), findsNothing);

    await tester.ensureVisible(find.byTooltip('Editar repartidor'));
    await tester.tap(find.byTooltip('Editar repartidor'));
    await tester.pumpAndSettle();
    expect(find.text('Editar repartidor'), findsOneWidget);
    expect(find.text('Cambiar rol'), findsOneWidget);
    await tester.tap(find.text('Cambiar rol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(find.text('Repartidor actualizado correctamente.'), findsOneWidget);
    expect(find.textContaining('Rol: admin'), findsOneWidget);

    expect(find.text('Juan Perez'), findsOneWidget);
    expect(find.text('Repartidores registrados'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Eliminar repartidor').first);
    await tester.tap(find.byTooltip('Eliminar repartidor').first);
    await tester.pumpAndSettle();
    expect(find.text('Eliminar repartidor'), findsOneWidget);

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('Repartidor eliminado correctamente.'), findsOneWidget);
    expect(find.text('Juan Perez'), findsNothing);
    expect(find.text('No hay repartidores registrados.'), findsOneWidget);
  });
}

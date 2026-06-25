import 'package:flutter_test/flutter_test.dart';
import 'package:ruteando_app/roles.dart';

void main() {
  test('formatearNombreUsuario separa nombre y apellido de repartidor', () {
    expect(formatearNombreUsuario('johnnyrepartidor'), 'johnny repartidor');
  });

  test('formatearNombreUsuario conserva nombres ya separados', () {
    expect(formatearNombreUsuario('Johnny  Repartidor'), 'Johnny Repartidor');
  });
}
